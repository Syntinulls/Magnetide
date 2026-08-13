extends Node
class_name PlayerEquipment

## The hotbar-facing equipment host: owns the equipped item slots, creates one
## live HeldItemBehavior instance per slot (so every slot keeps its own runtime
## state across switches), routes the per-frame tick to the selected behavior,
## and applies the selected item's mounting visuals to the player rig.

## Equipment slots - indices match hotbar slots.
@export var slots: Array[HeldItemData] = []

var selected_index: int = 0

var _behaviors: Array[HeldItemBehavior] = []

@onready var _player: Player = owner as Player

var current_data: HeldItemData:
	get:
		if selected_index >= 0 and selected_index < slots.size():
			return slots[selected_index]
		return null

var current_behavior: HeldItemBehavior:
	get:
		if selected_index >= 0 and selected_index < _behaviors.size():
			return _behaviors[selected_index]
		return null


## Called by Player._ready once the rig nodes are available.
func initialize() -> void:
	if _behaviors.size() != slots.size():
		_create_behaviors()
	apply_current_visuals()
	# GameUI/hotbar may not have registered with Magnetide yet when the player
	# enters the tree, so UI wiring must be deferred.
	call_deferred("_connect_hotbar")
	call_deferred("_populate_hotbar")


func apply_loadout(equipment_list: Array[HeldItemData], selected: int, runtime_reconfigure: bool) -> void:
	if runtime_reconfigure:
		var behavior := current_behavior
		if behavior:
			behavior.unequipped()

	slots = equipment_list.duplicate()
	if slots.is_empty():
		selected_index = 0
	else:
		selected_index = clampi(selected, 0, slots.size() - 1)
	_create_behaviors()

	if runtime_reconfigure:
		apply_current_visuals()
		var behavior := current_behavior
		if behavior:
			behavior.equipped()
		call_deferred("_populate_hotbar")


func process_current(delta: float) -> void:
	var behavior := current_behavior
	if behavior:
		behavior.process_input(delta)


func process_blocked(delta: float) -> void:
	var behavior := current_behavior
	if behavior:
		behavior.process_blocked(delta)


func notify_facing_changed() -> void:
	var behavior := current_behavior
	if behavior:
		behavior.facing_changed()


func notify_looting_ended() -> void:
	for behavior in _behaviors:
		if behavior:
			behavior.on_looting_ended()


func get_held_item() -> SalvageItem:
	var behavior := current_behavior
	return behavior.get_held_item() if behavior else null


## Shut down the selected behavior's transient effects without switching away
## (departure cutscene). Slot state (ammo, reload progress) is preserved.
func deactivate_current() -> void:
	var behavior := current_behavior
	if behavior:
		behavior.unequipped()
	if _player.muzzle_effect:
		_player.muzzle_effect.stop_effect()


func stop_for_run_end() -> void:
	for behavior in _behaviors:
		if behavior:
			behavior.on_run_end()


func refill_all_ammo() -> void:
	for behavior in _behaviors:
		if behavior and behavior.has_method("refill_ammo"):
			behavior.call("refill_ammo")


## Weapon sprite, muzzle position and muzzle-effect placement for the selected
## item, mirrored for the current facing.
func apply_current_visuals() -> void:
	var weapon_sprite := _player.weapon_sprite
	if not weapon_sprite:
		return
	var data := current_data
	weapon_sprite.texture = data.weapon_sprite if data != null else null
	apply_facing(_player.facing_mult())


func apply_facing(offset_mult: float) -> void:
	var data := current_data
	if data != null:
		_player.weapon_sprite.offset = Vector2(data.weapon_offset.x * offset_mult, data.weapon_offset.y)
		_player.weapon_sprite.rotation = data.weapon_rotation * offset_mult
		_player.muzzle.position = Vector2(data.muzzle_position.x * offset_mult, data.muzzle_position.y)
	_apply_muzzle_effect_positioning()


func _apply_muzzle_effect_positioning() -> void:
	var muzzle_effect := _player.muzzle_effect
	if not muzzle_effect:
		return

	var data := current_data
	if data == null:
		muzzle_effect.offset = Vector2.ZERO
		return

	muzzle_effect.offset = data.get_muzzle_effect_offset(_player.facing_right)


func _create_behaviors() -> void:
	_behaviors.clear()
	for data in slots:
		var behavior: HeldItemBehavior = data.create_use_behavior() if data != null else null
		if behavior:
			behavior.setup(_player if _player else owner as Player, data)
		_behaviors.append(behavior)


func _connect_hotbar() -> void:
	var hotbar := Magnetide.hotbar
	if hotbar:
		if not hotbar.slot_selected.is_connected(_on_hotbar_slot_selected):
			hotbar.slot_selected.connect(_on_hotbar_slot_selected)
	else:
		push_warning("PlayerEquipment: Hotbar not found")


func _populate_hotbar() -> void:
	var hotbar := Magnetide.hotbar
	if not hotbar:
		return
	var items: Array = []
	for data in slots:
		if data:
			items.append({ "icon": data.hotbar_icon, "data": data })
		else:
			items.append({ "icon": null, "data": null })
	hotbar.set_all_slots(items)


func _on_hotbar_slot_selected(index: int) -> void:
	_switch_to(index)


func _switch_to(index: int) -> void:
	if index == selected_index:
		return
	if index < 0 or index >= slots.size():
		return

	var outgoing := current_behavior
	if outgoing:
		outgoing.unequipped()
	if _player.muzzle_effect:
		_player.muzzle_effect.stop_effect()

	selected_index = index
	apply_current_visuals()
	var incoming := current_behavior
	if incoming:
		incoming.equipped()

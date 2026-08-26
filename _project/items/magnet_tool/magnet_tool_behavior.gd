extends HeldItemBehavior
class_name MagnetToolBehavior

## The magnet gun's carry loop: hover-highlighting salvage under the cursor,
## grabbing items, holding them at the gun, repelling them, and routing place
## clicks through the player's generic interaction component (storage, research
## station, recycler — each owns its own acceptance rules and visuals).

const REPEL_BAR_COLOR: Color = Color(1.0, 0.3, 0.2, 0.9)
const LOOP_SFX := "ship/magnet_effect.ogg"
const LOOP_SFX_VOLUME_DB := -10.0
const LOOP_SFX_PITCH_SCALE := 1.35
const HOVER_TOOLTIP_OFFSET: Vector2 = Vector2(18.0, -28.0)

var _held_item: SalvageItem = null
var _hovered_item: SalvageItem = null
var _repel_hold_elapsed: float = 0.0
var _is_repel_holding: bool = false
var _hover_tooltip: Label = null

var tool: MagnetToolData:
	get:
		return data as MagnetToolData


func process_input(delta: float) -> void:
	var mouse_pos := player.get_global_mouse_position()

	# Hover highlight (white outline on the salvage item under the cursor) is
	# independent of whether we are carrying an item, so it always runs.
	_process_hover()

	if _held_item and is_instance_valid(_held_item):
		if player.muzzle_effect:
			player.muzzle_effect.play_effect(data.get_muzzle_effect_type())
		_clear_pickup_prompt()

		# Update held item position to follow gun
		_held_item.update_gun_hold_position(_get_hold_point())

		# Only allow repel/place once item has reached the anchor point
		if _held_item.has_reached_anchor:
			player.interaction.update_carry(_held_item, mouse_pos)
			_update_repel_prompt()

			# Right-click hold to repel
			if Input.is_action_pressed("shoot_alt"):
				_is_repel_holding = true
				_repel_hold_elapsed += delta
				_update_repel_bar()
				var repel_time := tool.repel_hold_time if tool else 0.8
				if _repel_hold_elapsed >= repel_time:
					_repel_held_item()
			elif _is_repel_holding:
				# Released too early - reset
				_is_repel_holding = false
				_repel_hold_elapsed = 0.0
				_update_repel_bar()

			# Left-click to place on the interactable under the cursor
			if Input.is_action_just_pressed("shoot"):
				var result := player.interaction.try_drop(_held_item, mouse_pos)
				if result.get("accepted", false):
					_finalize_held_item_release()
					var regrab := result.get("regrab") as SalvageItem
					if regrab and is_instance_valid(regrab):
						_grab_item(regrab)
		else:
			player.interaction.clear_carry()
			_clear_repel_prompt()
	else:
		player.interaction.clear_carry()
		_clear_repel_prompt()
		if _held_item != null:
			_held_item = null
		_stop_loop_sfx()
		# Not carrying: the hovered item can be picked up.
		_update_pickup_prompt()

		if Input.is_action_just_pressed("shoot"):
			if _hovered_item and is_instance_valid(_hovered_item):
				_grab_item(_hovered_item)

	_update_hover_tooltip()


func process_blocked(_delta: float) -> void:
	_hide_hover_tooltip()


func unequipped() -> void:
	_clear_state()


func facing_changed() -> void:
	if _held_item and is_instance_valid(_held_item):
		_held_item.flip_relative_to_anchor(player.global_position)


func get_held_item() -> SalvageItem:
	return _held_item if _held_item and is_instance_valid(_held_item) else null


## Called when looting ends to clean up hover state (but keep held item).
func on_looting_ended() -> void:
	_set_hovered_item(null)
	_clear_pickup_prompt()
	_hide_hover_tooltip()


func _get_hold_point() -> Vector2:
	var hold_dist := tool.hold_distance if tool else 30.0
	var local_x_offset := hold_dist if player.facing_right else -hold_dist
	return player.muzzle.to_global(Vector2(local_x_offset, 0.0))


func _process_hover() -> void:
	var mouse_pos := player.get_global_mouse_position()
	var space_state := player.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collision_mask = 1 << PhysicsLayers.SALVAGE_ITEMS
	query.collide_with_bodies = true
	var results := space_state.intersect_point(query, 8)

	var best_item: SalvageItem = null
	var best_dist := INF
	for result in results:
		var body: Object = result["collider"]
		if body is SalvageItem:
			var item := body as SalvageItem
			if item.can_be_grabbed:
				var dist := mouse_pos.distance_to(item.global_position)
				if dist < best_dist:
					best_dist = dist
					best_item = item

	_set_hovered_item(best_item)


func _grab_item(item: SalvageItem) -> void:
	if _held_item != null:
		return  # Already holding an item
	if not item.can_be_grabbed:
		return

	# Get contact chain before grabbing (items that need to re-settle)
	var grabbed_from_storage := item.is_in_storage
	var dependents := item.get_storage_contact_chain() if grabbed_from_storage else item.get_contact_chain()
	var ship_node := player.get_ship()

	if grabbed_from_storage and ship_node:
		ship_node.remove_from_storage(item)

	# Remove from magnet tracking
	var magnet := Magnetide.magnet
	if magnet:
		magnet.remove_item(item)

	# Grab the item
	_set_hovered_item(null)
	item.grab_for_magnet_gun(player)
	item.update_gun_hold_position(_get_hold_point())
	_held_item = item
	_play_loop_sfx()

	# Unfreeze dependent items so they can re-settle
	for dep in dependents:
		if is_instance_valid(dep) and dep != item:
			if grabbed_from_storage:
				dep.wake_for_storage_resettle()
			else:
				_unfreeze_item_for_resettle(dep)


func _unfreeze_item_for_resettle(item: SalvageItem) -> void:
	var magnet := Magnetide.magnet
	var scene_root := Magnetide.world_root
	if scene_root and item.get_parent() != scene_root:
		var pos := item.global_position
		item.reparent(scene_root)
		item.global_position = pos

	if magnet:
		item.restart_magnet_pull_for_resettle(magnet)
	else:
		item.unfreeze_for_resettle()


func _repel_held_item() -> void:
	if not _held_item or not is_instance_valid(_held_item):
		return

	player.interaction.clear_carry()

	# Calculate repel direction (away from gun, toward where gun is pointing)
	var repel_force := tool.repel_impulse_force if tool else 600.0
	var gun_dir := (player.muzzle.global_position - player.arm_sprite.global_position).normalized()
	var impulse := gun_dir * repel_force

	_held_item.repel_from_gun(impulse)
	_finalize_held_item_release()


## Shared cleanup after the held item leaves the gun (placed / stacked /
## swapped / repelled).
func _finalize_held_item_release() -> void:
	_held_item = null
	_stop_loop_sfx()
	_is_repel_holding = false
	_repel_hold_elapsed = 0.0
	_update_repel_bar()
	if player.muzzle_effect:
		player.muzzle_effect.stop_effect()


func _clear_state() -> void:
	_set_hovered_item(null)
	_clear_pickup_prompt()
	_clear_repel_prompt()
	player.interaction.clear_carry()
	_hide_hover_tooltip()
	if _hover_tooltip and is_instance_valid(_hover_tooltip):
		_hover_tooltip.queue_free()
	_hover_tooltip = null

	# Force-release held item
	if _held_item and is_instance_valid(_held_item):
		_held_item.force_release_from_gun()
	_held_item = null
	_stop_loop_sfx()

	_is_repel_holding = false
	_repel_hold_elapsed = 0.0
	_update_repel_bar()
	if player.muzzle_effect:
		player.muzzle_effect.stop_effect()


## Hover highlight only. This drives the white interact outline on the salvage
## item under the cursor and is independent of the held item's rarity outline
## and of any pickup prompt (those are handled based on carry context).
func _set_hovered_item(item: SalvageItem) -> void:
	if _hovered_item == item:
		return

	if _hovered_item and is_instance_valid(_hovered_item):
		_hovered_item.set_outlined(false)

	_hovered_item = item

	if _hovered_item and is_instance_valid(_hovered_item):
		_hovered_item.set_outlined(true)


## PICK UP prompt, shown only while not carrying and hovering a grabbable item.
func _update_pickup_prompt() -> void:
	var prompts := Magnetide.control_prompts
	if prompts == null:
		return
	if _hovered_item and is_instance_valid(_hovered_item):
		prompts.set_prompt(&"pickup", "LMB", "PICK UP", false, 1)
	else:
		prompts.clear_prompt(&"pickup")


func _clear_pickup_prompt() -> void:
	var prompts := Magnetide.control_prompts
	if prompts:
		prompts.clear_prompt(&"pickup")


func _update_repel_prompt() -> void:
	var prompts := Magnetide.control_prompts
	if prompts:
		prompts.set_prompt(&"repel", "RMB", "REPEL", true, 1)


func _clear_repel_prompt() -> void:
	var prompts := Magnetide.control_prompts
	if prompts:
		prompts.clear_prompt(&"repel")


func _update_repel_bar() -> void:
	if _is_repel_holding:
		var repel_time := tool.repel_hold_time if tool else 0.8
		var fill := clampf(_repel_hold_elapsed / repel_time, 0.0, 1.0)
		player.progress_bar.request(&"repel", fill, REPEL_BAR_COLOR, "Repel", PlayerProgressBarController.PRIORITY_REPEL)
	else:
		player.progress_bar.clear(&"repel")


func _update_hover_tooltip() -> void:
	var should_show := player.input_enabled \
		and (_held_item == null or not is_instance_valid(_held_item)) \
		and _hovered_item != null \
		and is_instance_valid(_hovered_item)

	if not should_show:
		_hide_hover_tooltip()
		return

	var tooltip := _ensure_hover_tooltip()
	if tooltip == null:
		return
	tooltip.visible = true
	tooltip.text = _hovered_item.get_display_name()
	tooltip.add_theme_color_override("font_color", _hovered_item.get_rarity_color())
	tooltip.position = player.get_viewport().get_mouse_position() + HOVER_TOOLTIP_OFFSET


func _hide_hover_tooltip() -> void:
	if _hover_tooltip and is_instance_valid(_hover_tooltip):
		_hover_tooltip.visible = false


func _ensure_hover_tooltip() -> Label:
	if _hover_tooltip and is_instance_valid(_hover_tooltip):
		return _hover_tooltip
	var game_ui := Magnetide.game_ui
	if not game_ui:
		return null

	_hover_tooltip = Label.new()
	_hover_tooltip.name = "SalvageHoverTooltip"
	_hover_tooltip.visible = false
	_hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Magnetide.apply_label_font(_hover_tooltip)
	_hover_tooltip.add_theme_font_size_override("font_size", 24)
	_hover_tooltip.add_theme_color_override("font_outline_color", Color.BLACK)
	_hover_tooltip.add_theme_constant_override("outline_size", 4)
	game_ui.add_child(_hover_tooltip)
	return _hover_tooltip


func _play_loop_sfx() -> void:
	if not Magnetide.sfx or LOOP_SFX.is_empty():
		return
	Magnetide.sfx.play_loop(LOOP_SFX, _get_loop_sfx_key(), LOOP_SFX_VOLUME_DB, LOOP_SFX_PITCH_SCALE)


func _stop_loop_sfx() -> void:
	if not Magnetide.sfx or LOOP_SFX.is_empty():
		return
	Magnetide.sfx.stop_loop(LOOP_SFX, _get_loop_sfx_key())


func _get_loop_sfx_key() -> String:
	return "player_magnet_gun:%s" % player.get_instance_id()

extends Control
class_name Hotbar

signal slot_selected(index: int)
signal scroll_started(from_index: int, to_index: int)
signal scroll_finished(index: int)

const MAX_SLOTS := 3
const SLOT_SIZE := Vector2(96.0, 48.0)
const SLOT_SPACING := 0.0
const SCROLL_DURATION := 0.2
const SLOT_SCALE_SELECTED := 1.0
const SLOT_SCALE_UNSELECTED := 0.85

var _selected_index: int = 0
var _previous_index: int = 0
var _slot_data: Array[Dictionary] = []
var _is_scrolling: bool = false
var _equipped_indices: Array[int] = []  # Indices of non-empty slots

@onready var _strip: HBoxContainer = $HotbarMask/SubViewport/HotbarStrip
@onready var _slots: Array[Control] = [
	$HotbarMask/SubViewport/HotbarStrip/Slot0,
	$HotbarMask/SubViewport/HotbarStrip/Slot1,
	$HotbarMask/SubViewport/HotbarStrip/Slot2,
	$HotbarMask/SubViewport/HotbarStrip/Slot3,
	$HotbarMask/SubViewport/HotbarStrip/Slot4,
]


const BUFFER_OFFSET := -SLOT_SIZE.x  # Offset to hide left buffer slot

func _ready() -> void:
	_slot_data.resize(MAX_SLOTS)
	for i in MAX_SLOTS:
		_slot_data[i] = { "icon": null, "data": null }
	# Ensure strip is positioned to hide left buffer
	_strip.position.x = BUFFER_OFFSET
	_update_visual_slots()
	# Wait for layout to be computed before applying scales
	await get_tree().process_frame
	_setup_slot_scaling()


func _input(event: InputEvent) -> void:
	if _is_scrolling:
		return
	
	if event.is_action_pressed("hotbar_slot_1"):
		select_slot(0)
	elif event.is_action_pressed("hotbar_slot_2"):
		select_slot(1)
	elif event.is_action_pressed("hotbar_slot_3"):
		select_slot(2)
	elif event.is_action_pressed("hotbar_scroll_up"):
		_cycle_slot(-1)
	elif event.is_action_pressed("hotbar_scroll_down"):
		_cycle_slot(1)


func _cycle_slot(direction: int) -> void:
	if _equipped_indices.is_empty():
		return
	# Find current position in equipped list
	var current_pos := _equipped_indices.find(_selected_index)
	if current_pos < 0:
		current_pos = 0
	# Cycle to next/previous equipped slot
	var new_pos := (current_pos + direction + _equipped_indices.size()) % _equipped_indices.size()
	select_slot(_equipped_indices[new_pos])


func set_slot(index: int, icon: Texture2D, item_data: Variant = null) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return
	_slot_data[index] = { "icon": icon, "data": item_data }
	_update_equipped_indices()
	_update_visual_slots()


func clear_slot(index: int) -> void:
	set_slot(index, null, null)


func set_all_slots(items: Array) -> void:
	for i in mini(items.size(), MAX_SLOTS):
		var item: Dictionary = items[i]
		_slot_data[i] = {
			"icon": item.get("icon", null),
			"data": item.get("data", null)
		}
	_update_equipped_indices()
	_update_visual_slots()


func _update_equipped_indices() -> void:
	_equipped_indices.clear()
	for i in MAX_SLOTS:
		if _slot_data[i].get("data") != null:
			_equipped_indices.append(i)


func select_slot(index: int) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return
	if index == _selected_index:
		return
	if _is_scrolling:
		return
	# Only allow selecting equipped slots
	if not _equipped_indices.has(index):
		return
	
	var from_index := _selected_index
	var to_index := index
	
	_previous_index = _selected_index
	_selected_index = index
	scroll_started.emit(from_index, to_index)
	slot_selected.emit(_selected_index)  # Emit immediately so player switches right away
	
	_scroll_to(from_index, to_index)


func get_selected_index() -> int:
	return _selected_index


func _scroll_to(from_index: int, to_index: int) -> void:
	var direction := _get_scroll_direction(from_index, to_index)
	
	# Only populate the buffer slot that will scroll into view
	_populate_buffer_slot(direction)
	
	_is_scrolling = true
	var scroll_distance := SLOT_SIZE.x + SLOT_SPACING
	var target_offset := -direction * scroll_distance
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	tween.tween_property(_strip, "position:x", _strip.position.x + target_offset, SCROLL_DURATION)
	_tween_slot_scales(tween, direction)
	tween.set_parallel(false)
	tween.tween_callback(_on_scroll_complete)


func _get_scroll_direction(from_index: int, to_index: int) -> int:
	var slot_count := _equipped_indices.size()
	if slot_count <= 1:
		return 1
	# Find positions in equipped list
	var from_pos := _equipped_indices.find(from_index)
	var to_pos := _equipped_indices.find(to_index)
	if from_pos < 0 or to_pos < 0:
		return signi(to_index - from_index)
	var direct_diff := to_pos - from_pos
	if absf(direct_diff) <= slot_count / 2.0:
		return signi(direct_diff)
	else:
		return -signi(direct_diff)


func _get_equipment_index_for_visual_slot(visual_slot: int, base_index: int = -1) -> int:
	# Returns the equipment index for a given visual slot position
	# Visual slots: 0=far left buffer, 1=left, 2=center, 3=right, 4=far right buffer
	if _equipped_indices.is_empty():
		return 0
	if base_index < 0:
		base_index = _selected_index
	var base_pos := _equipped_indices.find(base_index)
	if base_pos < 0:
		base_pos = 0
	var offset := visual_slot - 2  # -2, -1, 0, 1, 2
	var slot_count := _equipped_indices.size()
	var target_pos := (base_pos + offset + slot_count) % slot_count
	return _equipped_indices[target_pos]


func _populate_buffer_slot(direction: int) -> void:
	# Populate only the buffer slot that will scroll into view
	# direction > 0 means selected index increased, so strip tweens LEFT, right buffer scrolls in
	# direction < 0 means selected index decreased, so strip tweens RIGHT, left buffer scrolls in
	if direction > 0:
		# Strip tweens left: populate left buffer (slot 0) with what will become the new left slot
		var equip_index := _get_equipment_index_for_visual_slot(0, _selected_index)
		_set_slot_visual(_slots[0], _slot_data[equip_index], equip_index)
	else:
		# Strip tweens right: populate right buffer (slot 4) with what will become the new right slot
		var equip_index := _get_equipment_index_for_visual_slot(4, _selected_index)
		_set_slot_visual(_slots[4], _slot_data[equip_index], equip_index)


func _on_scroll_complete() -> void:
	_is_scrolling = false
	_strip.position.x = BUFFER_OFFSET
	_update_visual_slots()
	_apply_slot_scales_instant()
	scroll_finished.emit(_selected_index)


func _update_visual_slots() -> void:
	for i in 5:
		var equip_index := _get_equipment_index_for_visual_slot(i)
		_set_slot_visual(_slots[i], _slot_data[equip_index], equip_index)


func _set_slot_visual(slot: Control, data: Dictionary, equip_index: int = -1) -> void:
	var icon_rect: TextureRect = slot.get_node("ItemIcon")
	icon_rect.texture = data.get("icon", null)
	
	# Update slot number if it exists (now inside SlotNumberContainer)
	var slot_number: Label = slot.get_node_or_null("SlotNumberContainer/SlotNumber")
	if slot_number and equip_index >= 0:
		slot_number.text = str(equip_index + 1)


func _get_scale_for_visual_slot(visual_index: int) -> float:
	# Visual index 2 is center (selected), all others are unselected
	if visual_index == 2:
		return SLOT_SCALE_SELECTED
	else:
		return SLOT_SCALE_UNSELECTED


func _setup_slot_scaling() -> void:
	# Set pivot to center for scaling
	for slot in _slots:
		slot.pivot_offset = slot.size / 2.0
	_apply_slot_scales_instant()


func _apply_slot_scales_instant() -> void:
	for i in 5:
		var target_scale := _get_scale_for_visual_slot(i)
		_slots[i].scale = Vector2(target_scale, target_scale)


func _tween_slot_scales(tween: Tween, direction: int) -> void:
	# Only two slots change scale during a scroll:
	# 1. The current center slot (visual index 2) scales DOWN to adjacent size
	# 2. The incoming slot scales UP to selected size
	# direction > 0: strip moves left, incoming slot is at visual index 3
	# direction < 0: strip moves right, incoming slot is at visual index 1
	
	# Current center slot scales down
	var current_center_slot := _slots[2]
	tween.tween_property(current_center_slot, "scale", Vector2(SLOT_SCALE_UNSELECTED, SLOT_SCALE_UNSELECTED), SCROLL_DURATION)
	
	# Incoming slot scales up
	var incoming_visual_index := 3 if direction > 0 else 1
	var incoming_slot := _slots[incoming_visual_index]
	tween.tween_property(incoming_slot, "scale", Vector2(SLOT_SCALE_SELECTED, SLOT_SCALE_SELECTED), SCROLL_DURATION)

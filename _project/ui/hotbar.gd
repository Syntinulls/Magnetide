extends Control
class_name Hotbar

signal slot_selected(index: int)
signal scroll_started(from_index: int, to_index: int)
signal scroll_finished(index: int)

const SLOT_COUNT := 3
const SLOT_SIZE := Vector2(96.0, 48.0)
const SLOT_SPACING := 0.0
const SCROLL_DURATION := 0.2

var _selected_index: int = 0
var _slot_data: Array[Dictionary] = []
var _is_scrolling: bool = false

@onready var _strip: HBoxContainer = $HotbarMask/HotbarStrip
@onready var _slots: Array[Control] = [
	$HotbarMask/HotbarStrip/Slot0,
	$HotbarMask/HotbarStrip/Slot1,
	$HotbarMask/HotbarStrip/Slot2,
	$HotbarMask/HotbarStrip/Slot3,
	$HotbarMask/HotbarStrip/Slot4,
]


func _ready() -> void:
	_slot_data.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		_slot_data[i] = { "icon": null, "data": null }
	_update_visual_slots()


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
		select_slot((_selected_index - 1 + SLOT_COUNT) % SLOT_COUNT)
	elif event.is_action_pressed("hotbar_scroll_down"):
		select_slot((_selected_index + 1) % SLOT_COUNT)


func set_slot(index: int, icon: Texture2D, item_data: Variant = null) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	_slot_data[index] = { "icon": icon, "data": item_data }
	_update_visual_slots()


func clear_slot(index: int) -> void:
	set_slot(index, null, null)


func set_all_slots(items: Array) -> void:
	for i in mini(items.size(), SLOT_COUNT):
		var item: Dictionary = items[i]
		_slot_data[i] = {
			"icon": item.get("icon", null),
			"data": item.get("data", null)
		}
	_update_visual_slots()


func select_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	if index == _selected_index:
		return
	if _is_scrolling:
		return
	
	var from_index := _selected_index
	var to_index := index
	
	_selected_index = index
	scroll_started.emit(from_index, to_index)
	
	_scroll_to(from_index, to_index)


func get_selected_index() -> int:
	return _selected_index


func _scroll_to(from_index: int, to_index: int) -> void:
	var direction := _get_scroll_direction(from_index, to_index)
	
	_populate_buffer_slot(direction)
	_update_visual_slots()
	
	_is_scrolling = true
	var scroll_distance := SLOT_SIZE.x + SLOT_SPACING
	var target_offset := -direction * scroll_distance
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_strip, "position:x", _strip.position.x + target_offset, SCROLL_DURATION)
	tween.tween_callback(_on_scroll_complete)


func _get_scroll_direction(from_index: int, to_index: int) -> int:
	var direct_diff := to_index - from_index
	if absf(direct_diff) <= SLOT_COUNT / 2.0:
		return signi(direct_diff)
	else:
		return -signi(direct_diff)


func _populate_buffer_slot(direction: int) -> void:
	if direction > 0:
		var wrap_index := (_selected_index + 2) % SLOT_COUNT
		_set_slot_visual(_slots[4], _slot_data[wrap_index])
	else:
		var wrap_index := (_selected_index - 2 + SLOT_COUNT) % SLOT_COUNT
		_set_slot_visual(_slots[0], _slot_data[wrap_index])


func _on_scroll_complete() -> void:
	_is_scrolling = false
	_strip.position.x = 0.0
	_update_visual_slots()
	scroll_finished.emit(_selected_index)
	slot_selected.emit(_selected_index)


func _update_visual_slots() -> void:
	var left_index := (_selected_index - 1 + SLOT_COUNT) % SLOT_COUNT
	var center_index := _selected_index
	var right_index := (_selected_index + 1) % SLOT_COUNT
	
	_set_slot_visual(_slots[0], _slot_data[(_selected_index - 2 + SLOT_COUNT) % SLOT_COUNT])
	_set_slot_visual(_slots[1], _slot_data[left_index])
	_set_slot_visual(_slots[2], _slot_data[center_index])
	_set_slot_visual(_slots[3], _slot_data[right_index])
	_set_slot_visual(_slots[4], _slot_data[(_selected_index + 2) % SLOT_COUNT])


func _set_slot_visual(slot: Control, data: Dictionary) -> void:
	var icon_rect: TextureRect = slot.get_node("ItemIcon")
	icon_rect.texture = data.get("icon", null)

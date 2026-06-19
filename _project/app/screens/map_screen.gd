extends Control
class_name MapScreen

signal start_requested(level_definition: LevelDefinition)
signal station_requested

const MapLevelEntryScript := preload("res://_project/app/screens/map_level_entry.gd")
const ENABLED_ARROW_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const DISABLED_ARROW_MODULATE := Color(0.45, 0.5, 0.58, 0.55)
const LOCKED_BANNER_MODULATE := Color(0.62, 0.66, 0.72, 0.72)
const UNLOCKED_BANNER_MODULATE := Color.WHITE
const CURRENT_CARD_MODULATE := Color.WHITE
const SIDE_CARD_MODULATE := Color(0.38, 0.42, 0.5, 0.72)
const THREAT_1_COLOR := Color("f0d23c")
const THREAT_2_COLOR := Color("d75555")
const THREAT_3_COLOR := Color("785fbe")
const THREAT_EMPTY_COLOR := Color(1.0, 1.0, 1.0, 0.86)
const SIDE_CARD_SCALE := 0.78

@export var levels: Array[Resource] = []
@export var carousel_tween_duration: float = 0.28

var _selected_index: int = 0
var _is_cycling: bool = false
var _carousel_tween: Tween = null
var _banner_frames: Array[ColorRect] = []
var _slot_rects: Dictionary = {}

@onready var _carousel: Control = $Carousel
@onready var _back_button: Button = $TopBar/BackButton
@onready var _previous_button: Button = $Carousel/PreviousButton
@onready var _next_button: Button = $Carousel/NextButton
@onready var _deploy_button: Button = $DeployButton
@onready var _banner_frame: ColorRect = $Carousel/BannerFrame


func _ready() -> void:
	_setup_carousel_cards()
	_configure_mouse_filters(self)
	_apply_fonts(self)

	_back_button.pressed.connect(_on_back_pressed)
	_previous_button.pressed.connect(_on_previous_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_deploy_button.pressed.connect(_on_deploy_pressed)

	_selected_index = clampi(_selected_index, 0, maxi(levels.size() - 1, 0))
	_refresh()


func set_default_level(level_definition: LevelDefinition) -> void:
	if level_definition == null:
		return

	var entry: Resource = null
	if levels.is_empty():
		entry = MapLevelEntryScript.new()
		levels.append(entry)
	else:
		entry = levels[0]

	if entry != null:
		entry.set("level_definition", level_definition)

	if is_inside_tree():
		_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_layout_for_size()


func _layout_for_size() -> void:
	if _banner_frame == null or _previous_button == null or _next_button == null or _deploy_button == null:
		return

	var screen_size := size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return

	var banner_height := clampf(screen_size.y * 0.64, 620.0, 920.0)
	var banner_width := clampf(banner_height * 0.68, 420.0, 720.0)
	var banner_size := Vector2(banner_width, banner_height)
	var banner_position := Vector2(
		(screen_size.x - banner_width) * 0.5,
		maxf(150.0, (screen_size.y - banner_height) * 0.5 - 30.0)
	)
	var side_size := banner_size * SIDE_CARD_SCALE
	var preview_gap := clampf(screen_size.x * 0.05, 72.0, 118.0)
	var side_y := banner_position.y + ((banner_height - side_size.y) * 0.5)
	var left_position := Vector2(banner_position.x - preview_gap - side_size.x, side_y)
	var right_position := Vector2(banner_position.x + banner_width + preview_gap, side_y)

	_slot_rects = {
		-2: Rect2(Vector2(-side_size.x - 64.0, side_y), side_size),
		-1: Rect2(left_position, side_size),
		0: Rect2(banner_position, banner_size),
		1: Rect2(right_position, side_size),
		2: Rect2(Vector2(screen_size.x + 64.0, side_y), side_size),
	}

	if not _is_cycling:
		for slot_index in range(_banner_frames.size()):
			_apply_frame_rect(_banner_frames[slot_index], _get_slot_rect(slot_index - 1))

	var arrow_size := clampf(screen_size.y * 0.125, 128.0, 180.0)
	var arrow_y := banner_position.y + (banner_height - arrow_size) * 0.5
	var arrow_gap := clampf(screen_size.x * 0.055, 90.0, 150.0)

	_previous_button.position = Vector2(maxf(32.0, left_position.x - arrow_gap - arrow_size), arrow_y)
	_previous_button.size = Vector2(arrow_size, arrow_size)
	_next_button.position = Vector2(minf(screen_size.x - arrow_size - 32.0, right_position.x + side_size.x + arrow_gap), arrow_y)
	_next_button.size = Vector2(arrow_size, arrow_size)

	_deploy_button.position = Vector2((screen_size.x - _deploy_button.size.x) * 0.5, banner_position.y + banner_height + 62.0)


func _on_previous_pressed() -> void:
	if _selected_index <= 0:
		return
	await _cycle_to_index(_selected_index - 1)


func _on_next_pressed() -> void:
	if _selected_index >= levels.size() - 1:
		return
	await _cycle_to_index(_selected_index + 1)


func _on_deploy_pressed() -> void:
	var entry := _get_selected_entry()
	var level_definition := _entry_level_definition(entry)
	if entry == null or _entry_locked(entry) or level_definition == null:
		return
	start_requested.emit(level_definition)


func _on_back_pressed() -> void:
	station_requested.emit()


func _refresh() -> void:
	_layout_for_size()

	var entry := _get_selected_entry()
	var has_entry := entry != null
	var is_locked := has_entry and _entry_locked(entry)

	_previous_button.disabled = _selected_index <= 0
	_next_button.disabled = _selected_index >= levels.size() - 1
	_previous_button.modulate = DISABLED_ARROW_MODULATE if _previous_button.disabled else ENABLED_ARROW_MODULATE
	_next_button.modulate = DISABLED_ARROW_MODULATE if _next_button.disabled else ENABLED_ARROW_MODULATE

	_deploy_button.disabled = not has_entry or is_locked or _entry_level_definition(entry) == null
	_update_visible_cards()


func _setup_carousel_cards() -> void:
	if not _banner_frames.is_empty():
		return

	var left_frame := _banner_frame.duplicate() as ColorRect
	var right_frame := _banner_frame.duplicate() as ColorRect
	if left_frame == null or right_frame == null:
		_banner_frames = [_banner_frame]
		return

	left_frame.name = "PreviousBannerFrame"
	right_frame.name = "NextBannerFrame"
	_carousel.add_child(left_frame)
	_carousel.add_child(right_frame)
	_banner_frames = [left_frame, _banner_frame, right_frame]
	_update_card_z_indexes()
	_previous_button.z_index = 4
	_next_button.z_index = 4


func _cycle_to_index(target_index: int) -> void:
	if _is_cycling:
		return
	if target_index < 0 or target_index >= levels.size() or target_index == _selected_index:
		return
	if _banner_frames.size() != 3:
		_selected_index = target_index
		_refresh()
		return

	_is_cycling = true
	_previous_button.disabled = true
	_next_button.disabled = true
	_deploy_button.disabled = true

	if _carousel_tween != null:
		_carousel_tween.kill()

	var direction := signi(target_index - _selected_index)
	var old_frames := _banner_frames.duplicate()
	var target_slots: Array[int] = [-1, 0, 1]
	if direction > 0:
		target_slots = [-2, -1, 0]
		old_frames[2].z_index = 3
	else:
		target_slots = [0, 1, 2]
		old_frames[0].z_index = 3

	_carousel_tween = create_tween()
	_carousel_tween.set_parallel(true)
	_carousel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	for index in range(old_frames.size()):
		var frame := old_frames[index] as ColorRect
		var target_rect := _get_slot_rect(target_slots[index])
		_carousel_tween.tween_property(frame, "position", target_rect.position, carousel_tween_duration)
		_carousel_tween.parallel().tween_property(frame, "size", target_rect.size, carousel_tween_duration)
		var target_modulate := CURRENT_CARD_MODULATE if target_slots[index] == 0 else SIDE_CARD_MODULATE
		_carousel_tween.parallel().tween_property(frame, "modulate", target_modulate, carousel_tween_duration)

	await _carousel_tween.finished

	_selected_index = target_index
	if direction > 0:
		_banner_frames = [old_frames[1], old_frames[2], old_frames[0]]
	else:
		_banner_frames = [old_frames[2], old_frames[0], old_frames[1]]

	_is_cycling = false
	_refresh()


func _update_visible_cards() -> void:
	if _banner_frames.is_empty():
		return

	for slot_index in range(_banner_frames.size()):
		var frame := _banner_frames[slot_index]
		var slot_offset := slot_index - 1
		var level_index := _selected_index + slot_offset
		_apply_frame_rect(frame, _get_slot_rect(slot_offset))
		_update_frame_entry(frame, level_index, slot_offset == 0)

	_update_card_z_indexes()


func _update_frame_entry(frame: ColorRect, level_index: int, is_current: bool) -> void:
	if frame == null:
		return
	if level_index < 0 or level_index >= levels.size():
		frame.visible = false
		return

	var entry := levels[level_index]
	var is_locked := _entry_locked(entry)
	frame.visible = true
	frame.modulate = CURRENT_CARD_MODULATE if is_current else SIDE_CARD_MODULATE

	var texture_rect := frame.get_node_or_null("BannerTexture") as TextureRect
	if texture_rect:
		texture_rect.texture = _entry_banner_texture(entry)
		texture_rect.modulate = LOCKED_BANNER_MODULATE if is_locked else UNLOCKED_BANNER_MODULATE

	var name_label := frame.get_node_or_null("LevelNameLabel") as Label
	if name_label:
		name_label.text = _entry_display_name(entry)

	var locked_overlay := frame.get_node_or_null("LockedOverlay") as ColorRect
	if locked_overlay:
		locked_overlay.visible = is_locked

	var locked_label := frame.get_node_or_null("LockedOverlay/LockedLabel") as Label
	if locked_label:
		locked_label.text = _entry_locked_label(entry)

	var threat_icons := frame.get_node_or_null("ThreatBlock/ThreatIcons") as HBoxContainer
	if threat_icons:
		_set_threat_icons(threat_icons, _entry_threat_icons(entry))


func _update_card_z_indexes() -> void:
	if _banner_frames.size() != 3:
		return
	_banner_frames[0].z_index = 1
	_banner_frames[1].z_index = 2
	_banner_frames[2].z_index = 1


func _apply_frame_rect(frame: Control, rect: Rect2) -> void:
	if frame == null:
		return
	frame.position = rect.position
	frame.size = rect.size


func _get_slot_rect(slot_offset: int) -> Rect2:
	if _slot_rects.has(slot_offset):
		return _slot_rects[slot_offset] as Rect2
	return Rect2()


func _get_selected_entry() -> Resource:
	if levels.is_empty() or _selected_index < 0 or _selected_index >= levels.size():
		return null
	return levels[_selected_index]


func _entry_level_definition(entry: Resource) -> LevelDefinition:
	if entry == null:
		return null
	return entry.get("level_definition") as LevelDefinition


func _entry_display_name(entry: Resource) -> String:
	if entry == null:
		return "Unknown Level"
	if entry.has_method("get_display_name"):
		return String(entry.call("get_display_name"))

	var level_definition := _entry_level_definition(entry)
	if level_definition != null:
		return level_definition.display_name
	return "Unknown Level"


func _entry_banner_texture(entry: Resource) -> Texture2D:
	if entry == null:
		return null
	return entry.get("banner_texture") as Texture2D


func _entry_threat_icons(entry: Resource) -> int:
	if entry == null:
		return 0
	return clampi(int(entry.get("threat_icons")), 0, 3)


func _entry_locked(entry: Resource) -> bool:
	if entry == null:
		return false
	return bool(entry.get("locked"))


func _entry_locked_label(entry: Resource) -> String:
	if entry == null:
		return "LOCKED"
	var label := String(entry.get("locked_label"))
	return label if not label.is_empty() else "LOCKED"


func _set_threat_icons(threat_icons: HBoxContainer, active_count: int) -> void:
	active_count = clampi(active_count, 0, 3)

	var icon_index := 0
	for icon in threat_icons.get_children():
		icon_index += 1
		var color_icon := icon.get_node_or_null("Color") as TextureRect
		var shape_icon := icon.get_node_or_null("Shape") as TextureRect
		var is_active := icon_index <= active_count

		if color_icon:
			color_icon.visible = true
			if active_count == 1:
				color_icon.modulate = THREAT_1_COLOR if is_active else THREAT_EMPTY_COLOR
			elif active_count == 2:
				color_icon.modulate = THREAT_2_COLOR if is_active else THREAT_EMPTY_COLOR
			elif active_count == 3:
				color_icon.modulate = THREAT_3_COLOR if is_active else THREAT_EMPTY_COLOR
			else:
				color_icon.modulate = THREAT_EMPTY_COLOR
		if shape_icon:
			shape_icon.visible = is_active
			shape_icon.modulate = Color.WHITE


func _apply_fonts(node: Node) -> void:
	if node is Label or node is Button:
		Magnetide.apply_label_font(node as Control)
	for child in node.get_children():
		_apply_fonts(child)


func _configure_mouse_filters(node: Node) -> void:
	if node is Button:
		(node as Button).mouse_filter = Control.MOUSE_FILTER_STOP
	elif node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child in node.get_children():
		_configure_mouse_filters(child)

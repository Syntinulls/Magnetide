extends Control
class_name SalvageProcessScreen

signal start_requested
signal main_menu_requested
signal component_arrivals_completed

const SalvageComponentTokenScene := preload("res://_project/app/screens/salvage_component_token.tscn")
const RunSummaryPopupScene := preload("res://_project/app/screens/salvage_results_popup.tscn")

enum ScreenState {
	SETUP,
	ITEM_ENTER,
	WAITING_FOR_CLICKS,
	ITEM_POP,
	COMPONENTS_RESTING,
	COMPONENTS_FLYING,
	BETWEEN_ITEMS,
	RESULTS_POPUP,
	COMPLETE,
}

const LOOT_LABEL_SPACING: float = 28.0
const LOOT_LABEL_LIFETIME_SECONDS: float = 0.9
const LOOT_LABEL_FADE_SECONDS: float = 0.35

@export var active_item_display_size: Vector2 = Vector2(340.0, 340.0)
@export var component_token_display_size: Vector2 = Vector2(80.0, 80.0)
@export var item_enter_duration: float = 0.35
@export var item_pop_duration: float = 0.12
@export var component_burst_duration: float = 0.22
@export var component_rest_seconds: float = 1.0
@export var between_items_seconds: float = 1.0
@export var click_shrink_scale: float = 0.9
@export var click_rotation_degrees: float = 8.0
@export var component_burst_min_distance: float = 95.0
@export var component_burst_max_distance: float = 165.0
@export var component_launch_speed: float = 420.0
@export var component_flight_delay_max_seconds: float = 0.28
@export var storage_icon_pulse_scale: float = 1.1
@export var storage_icon_pulse_rotation_degrees: float = 8.0

var _run_result: RunResult = null
var _state: ScreenState = ScreenState.SETUP
var _salvage_queue: Array[SalvageItemData] = []
var _final_result_counts: Dictionary = {}
var _current_item_index: int = -1
var _current_required_clicks: int = 0
var _current_clicks: int = 0
var _active_item_button: TextureButton = null
var _active_tokens: Array[SalvageComponentToken] = []
var _active_loot_labels: Array[Label] = []
var _pending_token_arrivals: int = 0
var _run_summary_popup: SalvageResultsPopup = null
var _did_begin_processing: bool = false
var _storage_pulse_tween: Tween = null
var _item_feedback_tween: Tween = null

@onready var _progress_label: Label = $TopHUD/VBoxContainer/ProgressLabel
@onready var _item_name_label: Label = $TopHUD/VBoxContainer/ItemNameLabel
@onready var _instruction_label: Label = $TopHUD/VBoxContainer/InstructionLabel
@onready var _stage_layer: Control = $StageLayer
@onready var _storage_anchor: Control = $StorageAnchor
@onready var _storage_icon_pivot: Control = $StorageAnchor/StorageIconPivot
@onready var _storage_icon: TextureRect = $StorageAnchor/StorageIconPivot/StorageIcon
@onready var _loot_label_layer: Control = $StorageAnchor/LootLabelLayer
@onready var _results_layer: Control = $ResultsLayer


func _ready() -> void:
	_update_header_labels()
	if _run_result != null:
		call_deferred("_begin_processing")


func set_run_result(result: RunResult) -> void:
	_run_result = result
	if is_inside_tree():
		call_deferred("_begin_processing")


func _begin_processing() -> void:
	if _did_begin_processing:
		return
	if _run_result == null:
		return

	_did_begin_processing = true
	_state = ScreenState.SETUP
	_salvage_queue.clear()
	_final_result_counts.clear()
	_current_item_index = -1
	_current_clicks = 0
	_current_required_clicks = 0
	_clear_active_item()
	_clear_active_tokens()
	_clear_loot_labels()
	await get_tree().process_frame

	for item_data in _run_result.stored_loot:
		if item_data == null:
			continue
		if item_data.components.is_empty():
			_add_final_result(item_data, true, false)
		else:
			_salvage_queue.append(item_data)

	if _salvage_queue.is_empty():
		_show_results_popup()
		return

	await _advance_to_next_item()


func _on_active_item_pressed() -> void:
	if _state != ScreenState.WAITING_FOR_CLICKS:
		return
	if _active_item_button == null:
		return

	_current_clicks += 1
	var is_final_click := _current_clicks >= _current_required_clicks
	_update_instruction_label()
	_play_item_click_feedback(is_final_click)

	if is_final_click:
		_active_item_button.disabled = true
		_state = ScreenState.ITEM_POP
		await _resolve_current_item()


func _advance_to_next_item() -> void:
	_current_item_index += 1
	if _current_item_index >= _salvage_queue.size():
		_show_results_popup()
		return

	_current_clicks = 0
	_current_required_clicks = _get_required_clicks_for_item(_get_current_item_data())
	_update_header_labels()
	await _enter_active_item(_get_current_item_data())


func _enter_active_item(item_data: SalvageItemData) -> void:
	if item_data == null:
		return

	_state = ScreenState.ITEM_ENTER
	_clear_active_item()

	var button := _create_active_item_button(item_data)
	var center_position := _get_stage_center()
	var start_position := Vector2(_stage_layer.size.x + active_item_display_size.x * 0.6, center_position.y)
	_stage_layer.add_child(button)
	_active_item_button = button
	_active_item_button.disabled = true
	_active_item_button.pivot_offset = _active_item_button.size * 0.5
	_set_button_center(_active_item_button, start_position)
	_active_item_button.scale = Vector2.ONE
	_active_item_button.rotation = 0.0
	_active_item_button.modulate = Color.WHITE
	_active_item_button.pressed.connect(_on_active_item_pressed)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_active_item_button, "position", center_position - (_active_item_button.size * 0.5), item_enter_duration)
	await tween.finished

	if _active_item_button == null:
		return

	_active_item_button.disabled = false
	_state = ScreenState.WAITING_FOR_CLICKS
	_update_instruction_label()


func _resolve_current_item() -> void:
	var item_data := _get_current_item_data()
	if item_data == null:
		return

	var source_center := _get_stage_center()
	if _active_item_button != null:
		source_center = _get_button_center(_active_item_button)
		await _play_item_pop_animation()
		_clear_active_item()

	var spawned_tokens := _spawn_component_tokens(item_data.components, source_center)
	if spawned_tokens.is_empty():
		_state = ScreenState.BETWEEN_ITEMS
		await get_tree().create_timer(between_items_seconds).timeout
		await _advance_to_next_item()
		return

	_state = ScreenState.COMPONENTS_RESTING
	await _burst_tokens_to_rest_positions(spawned_tokens, source_center)
	await get_tree().create_timer(component_rest_seconds).timeout

	_state = ScreenState.COMPONENTS_FLYING
	await _fly_tokens_to_storage(spawned_tokens, source_center)

	_state = ScreenState.BETWEEN_ITEMS
	await get_tree().create_timer(between_items_seconds).timeout
	await _advance_to_next_item()


func _burst_tokens_to_rest_positions(tokens: Array[SalvageComponentToken], source_center: Vector2) -> void:
	if tokens.is_empty():
		return

	var burst_profiles := _get_component_burst_profiles(tokens.size(), source_center)
	var burst_tween := create_tween()
	burst_tween.set_parallel(true)
	burst_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for index in range(tokens.size()):
		var token := tokens[index]
		var burst_profile := burst_profiles[index]
		var rest_position := burst_profile.get("position", source_center) as Vector2
		var burst_direction := burst_profile.get("direction", Vector2.RIGHT) as Vector2
		token.visible = true
		token.scale = Vector2(0.5, 0.5)
		token.modulate = Color(1.0, 1.0, 1.0, 0.0)
		token.rotation = burst_direction.angle()
		burst_tween.tween_property(token, "position", rest_position - (token.size * 0.5), component_burst_duration)
		burst_tween.parallel().tween_property(token, "scale", Vector2.ONE, component_burst_duration)
		burst_tween.parallel().tween_property(token, "modulate:a", 1.0, component_burst_duration * 0.7)

	await burst_tween.finished


func _fly_tokens_to_storage(tokens: Array[SalvageComponentToken], source_center: Vector2) -> void:
	_pending_token_arrivals = tokens.size()
	if _pending_token_arrivals <= 0:
		return

	var target_center := _get_storage_target_stage_position()
	for token in tokens:
		var outward_direction := (token.get_center_position() - source_center).normalized()
		if outward_direction == Vector2.ZERO:
			outward_direction = Vector2.RIGHT
		var hesitation_delay := randf_range(0.0, component_flight_delay_max_seconds)
		_begin_token_flight_after_delay(token, target_center, outward_direction * component_launch_speed, hesitation_delay)

	await component_arrivals_completed


func _begin_token_flight_after_delay(
	token: SalvageComponentToken,
	target_center: Vector2,
	initial_velocity: Vector2,
	delay_seconds: float
) -> void:
	if token == null or not is_instance_valid(token):
		return
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout
	if token == null or not is_instance_valid(token):
		return
	token.begin_flight(target_center, initial_velocity)


func _spawn_component_tokens(components: Array[SalvageItemData], source_center: Vector2) -> Array[SalvageComponentToken]:
	_clear_active_tokens()

	var spawned: Array[SalvageComponentToken] = []
	for component_data in components:
		if component_data == null:
			continue
		var token := SalvageComponentTokenScene.instantiate() as SalvageComponentToken
		if token == null:
			continue
		token.setup(component_data, component_token_display_size)
		_stage_layer.add_child(token)
		token.set_center_position(source_center)
		token.visible = false
		token.arrived.connect(_on_component_token_arrived)
		_active_tokens.append(token)
		spawned.append(token)

	return spawned


func _on_component_token_arrived(token: SalvageComponentToken, item_data: SalvageItemData) -> void:
	if token != null:
		_active_tokens.erase(token)
		token.queue_free()

	if item_data != null:
		_add_final_result(item_data, false, true)
		_add_loot_label(item_data)
	_pulse_storage_icon()

	_pending_token_arrivals = maxi(_pending_token_arrivals - 1, 0)
	if _pending_token_arrivals == 0:
		component_arrivals_completed.emit()


func _add_final_result(
	item_data: SalvageItemData,
	from_collection: bool = false,
	from_salvage: bool = false
) -> void:
	if item_data == null:
		return

	var key := item_data.resource_path
	if key.is_empty():
		key = item_data.item_name

	var entry: Dictionary = _final_result_counts.get(key, {
		"item_data": item_data,
		"name": item_data.item_name if not item_data.item_name.is_empty() else "Unknown Material",
		"count": 0,
		"from_collection": false,
		"from_salvage": false,
	})
	entry["count"] = int(entry.get("count", 0)) + 1
	entry["from_collection"] = bool(entry.get("from_collection", false)) or from_collection
	entry["from_salvage"] = bool(entry.get("from_salvage", false)) or from_salvage
	_final_result_counts[key] = entry


func _build_result_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in _final_result_counts.values():
		entries.append(entry)

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var item_a := a.get("item_data", null) as SalvageItemData
		var item_b := b.get("item_data", null) as SalvageItemData
		var rarity_a := int(item_a.rarity) if item_a != null else SalvageItemData.ItemRarity.COMMON
		var rarity_b := int(item_b.rarity) if item_b != null else SalvageItemData.ItemRarity.COMMON
		if rarity_a != rarity_b:
			return rarity_a < rarity_b
		var name_a := str(a.get("name", ""))
		var name_b := str(b.get("name", ""))
		if name_a.to_lower() == name_b.to_lower():
			return int(a.get("count", 0)) > int(b.get("count", 0))
		return name_a.to_lower() < name_b.to_lower()
	)
	return entries


func _show_results_popup() -> void:
	if _run_summary_popup != null and is_instance_valid(_run_summary_popup):
		return

	_state = ScreenState.RESULTS_POPUP
	_update_header_labels()
	_instruction_label.text = "Run summary ready for review."

	_run_summary_popup = RunSummaryPopupScene.instantiate() as SalvageResultsPopup
	if _run_summary_popup == null:
		main_menu_requested.emit()
		return

	var run_stats := {
		"time_elapsed": _run_result.elapsed_seconds if _run_result != null else 0.0,
		"enemies_killed": _run_result.enemies_killed if _run_result != null else 0,
		"collected_items": _run_result.salvage_items_collected if _run_result != null else 0,
		"items_salvaged": _salvage_queue.size(),
	}

	_results_layer.add_child(_run_summary_popup)
	_run_summary_popup.setup(_run_result, _build_result_entries(), run_stats)
	_run_summary_popup.main_menu_requested.connect(_on_results_popup_main_menu_requested)


func _on_results_popup_main_menu_requested() -> void:
	_state = ScreenState.COMPLETE
	main_menu_requested.emit()


func _update_header_labels() -> void:
	if _progress_label == null:
		return

	if _state == ScreenState.RESULTS_POPUP or (_current_item_index >= _salvage_queue.size() and _did_begin_processing):
		_progress_label.text = "SALVAGE COMPLETE"
		_item_name_label.text = "Recovered Materials"
		return

	if _salvage_queue.is_empty() or _current_item_index < 0 or _current_item_index >= _salvage_queue.size():
		_progress_label.text = "SALVAGE"
		_item_name_label.text = "Awaiting Run Data"
		_instruction_label.text = "Preparing salvage manifest..."
		return

	var item_data := _salvage_queue[_current_item_index]
	_progress_label.text = "SALVAGE %d / %d" % [_current_item_index + 1, _salvage_queue.size()]
	_item_name_label.text = item_data.item_name.to_upper() if item_data != null else "UNKNOWN SALVAGE"
	_update_instruction_label()


func _update_instruction_label() -> void:
	if _instruction_label == null:
		return

	if _state != ScreenState.WAITING_FOR_CLICKS:
		match _state:
			ScreenState.ITEM_ENTER:
				_instruction_label.text = "Bringing the next item onto the table..."
			ScreenState.ITEM_POP:
				_instruction_label.text = "Breakdown in progress..."
			ScreenState.COMPONENTS_RESTING:
				_instruction_label.text = "Recovered components identified."
			ScreenState.COMPONENTS_FLYING:
				_instruction_label.text = "Transferring components into storage..."
			ScreenState.BETWEEN_ITEMS:
				_instruction_label.text = "Preparing the next salvage item..."
			ScreenState.RESULTS_POPUP:
				_instruction_label.text = "Recovered materials ready for review."
			_:
				_instruction_label.text = "Preparing salvage manifest..."
		return

	var clicks_remaining := maxi(_current_required_clicks - _current_clicks, 0)
	var click_word := "click" if clicks_remaining == 1 else "clicks"
	_instruction_label.text = "Break it down with %d more %s." % [clicks_remaining, click_word]


func _create_active_item_button(item_data: SalvageItemData) -> TextureButton:
	var button := TextureButton.new()
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = item_data.sprite if item_data != null else null
	if button.texture_normal == null:
		button.texture_normal = _create_placeholder_texture(item_data, active_item_display_size)
	button.size = active_item_display_size
	button.custom_minimum_size = active_item_display_size
	button.pivot_offset = active_item_display_size * 0.5
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return button


func _play_item_click_feedback(is_final_click: bool) -> void:
	if _active_item_button == null:
		return

	if _item_feedback_tween != null:
		_item_feedback_tween.kill()

	var rotation_direction := -1.0 if _current_clicks % 2 == 0 else 1.0
	var rotation_amount := deg_to_rad(click_rotation_degrees * rotation_direction * (1.4 if is_final_click else 1.0))
	var target_scale := Vector2.ONE * (click_shrink_scale * (0.95 if is_final_click else 1.0))

	_item_feedback_tween = create_tween()
	_item_feedback_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_item_feedback_tween.tween_property(_active_item_button, "scale", target_scale, 0.08)
	_item_feedback_tween.parallel().tween_property(_active_item_button, "rotation", rotation_amount, 0.08)
	_item_feedback_tween.tween_property(_active_item_button, "scale", Vector2.ONE, 0.14)
	_item_feedback_tween.parallel().tween_property(_active_item_button, "rotation", 0.0, 0.14)


func _play_item_pop_animation() -> void:
	if _active_item_button == null:
		return

	if _item_feedback_tween != null:
		_item_feedback_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_active_item_button, "scale", Vector2.ONE * 1.18, item_pop_duration)
	tween.parallel().tween_property(_active_item_button, "modulate:a", 0.0, item_pop_duration)
	await tween.finished


func _pulse_storage_icon() -> void:
	if _storage_icon_pivot == null:
		return

	if _storage_pulse_tween != null:
		_storage_pulse_tween.kill()

	_storage_icon_pivot.scale = Vector2.ONE
	_storage_icon_pivot.rotation = 0.0
	var rotation_direction := -1.0 if randf() < 0.5 else 1.0
	var rotation_amount := deg_to_rad(storage_icon_pulse_rotation_degrees * rotation_direction * randf_range(0.7, 1.15))
	_storage_pulse_tween = create_tween()
	_storage_pulse_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_storage_pulse_tween.tween_property(_storage_icon_pivot, "scale", Vector2.ONE * storage_icon_pulse_scale, 0.08)
	_storage_pulse_tween.parallel().tween_property(_storage_icon_pivot, "rotation", rotation_amount, 0.08)
	_storage_pulse_tween.tween_property(_storage_icon_pivot, "scale", Vector2.ONE, 0.12)
	_storage_pulse_tween.parallel().tween_property(_storage_icon_pivot, "rotation", 0.0, 0.12)


func _add_loot_label(item_data: SalvageItemData) -> void:
	if _loot_label_layer == null or item_data == null:
		return

	var label := Label.new()
	label.text = "+1 %s" % (item_data.item_name if not item_data.item_name.is_empty() else "Unknown Material")
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", item_data.get_rarity_color())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loot_label_layer.add_child(label)
	label.size = label.get_combined_minimum_size()
	label.modulate = Color.WHITE
	_active_loot_labels.append(label)
	_reposition_loot_labels()

	var fade_tween := create_tween()
	fade_tween.tween_interval(LOOT_LABEL_LIFETIME_SECONDS)
	fade_tween.tween_property(label, "modulate:a", 0.0, LOOT_LABEL_FADE_SECONDS)
	fade_tween.finished.connect(_on_loot_label_expired.bind(label))


func _reposition_loot_labels() -> void:
	var base_position := _get_loot_label_base_position()
	for index in range(_active_loot_labels.size()):
		var label := _active_loot_labels[index]
		if label == null or not is_instance_valid(label):
			continue

		label.size = label.get_combined_minimum_size()
		var reverse_index := (_active_loot_labels.size() - 1) - index
		var target_position := Vector2(
			base_position.x - (label.size.x * 0.5),
			base_position.y - (reverse_index * LOOT_LABEL_SPACING) - label.size.y
		)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "position", target_position, 0.12)


func _on_loot_label_expired(label: Label) -> void:
	_active_loot_labels.erase(label)
	if label != null and is_instance_valid(label):
		label.queue_free()
	_reposition_loot_labels()


func _get_loot_label_base_position() -> Vector2:
	var local_center := _storage_icon_pivot.position + (_storage_icon_pivot.size * 0.5)
	return Vector2(local_center.x, _storage_icon_pivot.position.y - 10.0)


func _get_current_item_data() -> SalvageItemData:
	if _current_item_index < 0 or _current_item_index >= _salvage_queue.size():
		return null
	return _salvage_queue[_current_item_index]


func _get_required_clicks_for_item(item_data: SalvageItemData) -> int:
	if item_data == null:
		return 2

	match int(item_data.rarity):
		SalvageItemData.ItemRarity.RARE:
			return 3
		SalvageItemData.ItemRarity.EPIC:
			return 4
		SalvageItemData.ItemRarity.LEGENDARY:
			return 5
		_:
			return 2


func _get_stage_center() -> Vector2:
	return _stage_layer.size * 0.5


func _get_storage_target_stage_position() -> Vector2:
	var storage_center_global := _storage_icon_pivot.get_global_rect().get_center()
	return storage_center_global - _stage_layer.get_global_rect().position


func _get_component_burst_profiles(count: int, source_center: Vector2) -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	if count <= 0:
		return profiles

	var sector_size := TAU / maxf(float(count), 1.0)
	var min_distance := minf(component_burst_min_distance, component_burst_max_distance)
	var max_distance := maxf(component_burst_min_distance, component_burst_max_distance)
	var angle_offset := randf_range(0.0, TAU)

	for index in range(count):
		var base_angle := angle_offset + (sector_size * index)
		var random_angle := base_angle + randf_range(-sector_size * 0.4, sector_size * 0.4)
		if count == 1:
			random_angle = randf_range(0.0, TAU)

		var burst_direction := Vector2.RIGHT.rotated(random_angle).normalized()
		if burst_direction == Vector2.ZERO:
			burst_direction = Vector2.RIGHT
		var burst_distance := randf_range(min_distance, max_distance)
		profiles.append({
			"position": source_center + (burst_direction * burst_distance),
			"direction": burst_direction,
		})

	return profiles


func _get_button_center(button: Control) -> Vector2:
	return button.position + (button.size * 0.5)


func _set_button_center(button: Control, center: Vector2) -> void:
	button.position = center - (button.size * 0.5)


func _create_placeholder_texture(item_data: SalvageItemData, display_size: Vector2) -> Texture2D:
	var image_size := Vector2i(maxi(int(display_size.x), 2), maxi(int(display_size.y), 2))
	var image := Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	var fill_color := Color.WHITE
	if item_data != null:
		fill_color = item_data.get_rarity_color()
	image.fill(fill_color)
	return ImageTexture.create_from_image(image)


func _clear_active_item() -> void:
	if _active_item_button != null and is_instance_valid(_active_item_button):
		_active_item_button.queue_free()
	_active_item_button = null


func _clear_active_tokens() -> void:
	for token in _active_tokens:
		if token != null and is_instance_valid(token):
			token.queue_free()
	_active_tokens.clear()
	_pending_token_arrivals = 0


func _clear_loot_labels() -> void:
	for label in _active_loot_labels:
		if label != null and is_instance_valid(label):
			label.queue_free()
	_active_loot_labels.clear()

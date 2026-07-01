extends InteractionHitbox
class_name ResearchStation

signal artifact_placed(item: SalvageItem)
signal research_started(item: SalvageItem)
signal research_completed(item_data: SalvageItemData)
signal research_failed(item_data: SalvageItemData, reason: StringName)
signal artifact_cleared(item_data: SalvageItemData)

@export var debug_research_duration: float = 5.0

const ResearchStationUIScene: PackedScene = preload("res://_project/ui/research/research_station_ui.tscn")

var _current_artifact: SalvageItem = null
var _is_researching: bool = false
var _research_timer: Timer = null
var _outline: CompositeOutline = null
var _research_ui: ResearchStationUI = null
var _saved_stage_state: Dictionary = {}

@onready var _station_sprite: AnimatedSprite2D = $AnimatedSprite2D as AnimatedSprite2D
@onready var _placement_shape: CollisionShape2D = $CollisionShape2D as CollisionShape2D
@onready var _artifact_anchor: Marker2D = $ArtifactAnchor as Marker2D
@onready var _researched_items_root: Node2D = $ResearchedItemsRoot as Node2D


func _ready() -> void:
	super._ready()
	_research_timer = Timer.new()
	_research_timer.one_shot = true
	_research_timer.timeout.connect(_on_research_timer_timeout)
	add_child(_research_timer)

	_setup_outline_material()
	if _researched_items_root:
		_researched_items_root.y_sort_enabled = true
		_researched_items_root.z_index = -3
	set_highlighted(false)


func is_point_in_placement_area(global_point: Vector2) -> bool:
	if _placement_shape == null or _placement_shape.shape == null:
		return false
	if _placement_shape.shape is RectangleShape2D:
		var rect_shape := _placement_shape.shape as RectangleShape2D
		var local_point := _placement_shape.to_local(global_point)
		var rect := Rect2(-rect_shape.size * 0.5, rect_shape.size)
		return rect.has_point(local_point)
	return false


func can_accept_item(item: SalvageItem) -> bool:
	return item != null \
		and is_instance_valid(item) \
		and item.is_artifact \
		and not item.is_locked_for_research \
		and _current_artifact == null \
		and not _is_researching


func set_highlighted(enabled: bool) -> void:
	if _outline:
		_outline.set_enabled(enabled)


func place_artifact(item: SalvageItem) -> bool:
	if not can_accept_item(item):
		return false

	_current_artifact = item
	item.lock_for_research(_artifact_anchor.global_position, _researched_items_root)
	set_highlighted(false)
	artifact_placed.emit(item)
	_start_research_session()
	return true


func has_artifact() -> bool:
	return _current_artifact != null and is_instance_valid(_current_artifact)


func get_current_artifact() -> SalvageItem:
	return _current_artifact if has_artifact() else null


func has_active_research() -> bool:
	return has_artifact() and _is_researching


func open_research_ui() -> void:
	if not has_active_research():
		return
	var ui := _ensure_research_ui()
	if ui == null:
		_start_debug_research()
		return
	ui.start_session(_current_artifact.item_data, _saved_stage_state)


func stop_for_run_end() -> void:
	if not has_artifact():
		return
	_fail_research(&"run_ended")


func _start_research_session() -> void:
	if not has_artifact():
		return
	_is_researching = true
	_saved_stage_state.clear()
	research_started.emit(_current_artifact)


func _start_debug_research() -> void:
	if not has_artifact():
		return
	_is_researching = true
	_research_timer.start(maxf(debug_research_duration, 0.01))


func _on_research_timer_timeout() -> void:
	if not has_artifact():
		_current_artifact = null
		_is_researching = false
		return

	var item_data := _current_artifact.item_data
	_complete_research_success(item_data)


func _setup_outline_material() -> void:
	if _station_sprite == null:
		return
	# Composite outline around the (animated) station sprite.
	_outline = CompositeOutline.new()
	add_child(_outline)
	_outline.configure([_station_sprite], true, Color.WHITE, 3.0, _station_sprite)


func _award_research_points(item_data: SalvageItemData) -> void:
	if item_data == null:
		return

	var reward := maxi(item_data.research_point_reward, 0)
	if reward <= 0:
		push_warning("ResearchStation: Researched artifact has no research point reward.")
		return

	var app_root := Magnetide.app_root
	if app_root == null or not app_root.has_method("get_save_data"):
		return

	var save_data := app_root.call("get_save_data") as AppSaveData
	if save_data == null:
		return
	save_data.add_research_points(reward)


func _ensure_research_ui() -> ResearchStationUI:
	if _research_ui and is_instance_valid(_research_ui):
		return _research_ui

	var game_ui := Magnetide.game_ui
	if game_ui == null:
		push_warning("ResearchStation: GameUI not found, falling back to debug research timer.")
		return null

	_research_ui = ResearchStationUIScene.instantiate() as ResearchStationUI
	_research_ui.name = "ResearchStationUI"
	game_ui.add_child(_research_ui)
	if not _research_ui.research_completed.is_connected(_on_research_ui_completed):
		_research_ui.research_completed.connect(_on_research_ui_completed)
	if not _research_ui.research_failed.is_connected(_on_research_ui_failed):
		_research_ui.research_failed.connect(_on_research_ui_failed)
	if not _research_ui.ui_closed.is_connected(_on_research_ui_closed):
		_research_ui.ui_closed.connect(_on_research_ui_closed)
	if not _research_ui.research_dismissed.is_connected(_on_research_ui_dismissed):
		_research_ui.research_dismissed.connect(_on_research_ui_dismissed)
	return _research_ui


## Fired the instant the final stage clears: award points and consume the
## artifact immediately, but keep the UI so its result screens can play out.
func _on_research_ui_completed(item_data: SalvageItemData) -> void:
	if _research_timer:
		_research_timer.stop()
	_award_research_points(item_data)
	research_completed.emit(item_data)
	_consume_artifact_keep_ui(item_data)


## Fired when the finalized session's result screens are dismissed. Rewards were
## already granted, so this only tears down the UI.
func _on_research_ui_dismissed() -> void:
	if _research_ui and is_instance_valid(_research_ui):
		_research_ui.queue_free()
		_research_ui = null
	Magnetide.research_ui_input_captured = false


func _on_research_ui_failed(_item_data: SalvageItemData, reason: StringName) -> void:
	_fail_research(reason)


func _on_research_ui_closed() -> void:
	if _research_ui and is_instance_valid(_research_ui):
		_saved_stage_state = _research_ui.get_saved_state()


func _complete_research_success(item_data: SalvageItemData) -> void:
	if _research_timer:
		_research_timer.stop()
	_award_research_points(item_data)
	research_completed.emit(item_data)
	_clear_current_artifact(item_data)


func _fail_research(reason: StringName) -> void:
	if _research_timer:
		_research_timer.stop()
	var item_data := _current_artifact.item_data if has_artifact() else null
	research_failed.emit(item_data, reason)
	_clear_current_artifact(item_data)


func _clear_current_artifact(item_data: SalvageItemData) -> void:
	if _research_ui and is_instance_valid(_research_ui):
		_research_ui.queue_free()
		_research_ui = null
	Magnetide.research_ui_input_captured = false
	if has_artifact():
		_current_artifact.queue_free()
	_current_artifact = null
	_is_researching = false
	_saved_stage_state.clear()
	artifact_cleared.emit(item_data)


## Consume the artifact and mark research finished, but leave the research UI
## alive (its result screens are still showing). The UI is freed later, when it
## emits research_dismissed.
func _consume_artifact_keep_ui(item_data: SalvageItemData) -> void:
	if has_artifact():
		_current_artifact.queue_free()
	_current_artifact = null
	_is_researching = false
	_saved_stage_state.clear()
	artifact_cleared.emit(item_data)

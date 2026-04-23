extends Control
class_name SalvageResultsPopup

signal main_menu_requested

const ENTRY_ICON_SIZE := Vector2(40.0, 40.0)
const SOURCE_ICON_SIZE := Vector2(24.0, 24.0)
const ENTRY_NAME_WIDTH := 220.0
const SALVAGED_ICON_TEXTURE: Texture2D = preload("res://_project/ui/sprites/summary_icon_salvaged.png")
const COLLECTED_ICON_TEXTURE: Texture2D = preload("res://_project/ui/sprites/summary_icon_collected.png")

var _run_result: RunResult = null
var _result_entries: Array[Dictionary] = []
var _run_stats: Dictionary = {}

@onready var _time_value: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyColumns/StatsColumn/StatsPanel/MarginContainer/StatsVBox/TimeRow/Value
@onready var _kills_value: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyColumns/StatsColumn/StatsPanel/MarginContainer/StatsVBox/KillsRow/Value
@onready var _collected_value: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyColumns/StatsColumn/StatsPanel/MarginContainer/StatsVBox/CollectedRow/Value
@onready var _salvaged_value: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyColumns/StatsColumn/StatsPanel/MarginContainer/StatsVBox/SalvagedRow/Value
@onready var _empty_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyColumns/ItemsColumn/EmptyLabel
@onready var _list_container: VBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodyColumns/ItemsColumn/ScrollContainer/ListContainer
@onready var _menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MenuButton


func _ready() -> void:
	_menu_button.pressed.connect(_on_menu_pressed)
	_apply_data()


func setup(run_result: RunResult, result_entries: Array[Dictionary], run_stats: Dictionary = {}) -> void:
	_run_result = run_result
	_result_entries = result_entries.duplicate(true)
	_run_stats = run_stats.duplicate(true)
	_apply_data()


func _apply_data() -> void:
	if _time_value == null:
		return

	_apply_stats()
	_rebuild_list()


func _apply_stats() -> void:
	if _time_value == null:
		return

	_time_value.text = _format_elapsed_time(float(_run_stats.get("time_elapsed", 0.0)))
	_kills_value.text = str(int(_run_stats.get("enemies_killed", 0)))
	_collected_value.text = str(int(_run_stats.get("collected_items", 0)))
	_salvaged_value.text = str(int(_run_stats.get("items_salvaged", 0)))


func _rebuild_list() -> void:
	if _list_container == null:
		return

	for child in _list_container.get_children():
		child.queue_free()

	var total_items := 0
	for entry in _result_entries:
		total_items += int(entry.get("count", 0))

	_empty_label.visible = _result_entries.is_empty()

	for entry in _result_entries:
		_list_container.add_child(_build_entry_row(entry))


func _build_entry_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 18)

	var item_data := entry.get("item_data", null) as SalvageItemData

	var was_collected := bool(entry.get("from_collection", false))
	var was_salvaged := bool(entry.get("from_salvage", false))
	row.add_child(_build_source_icon(was_collected, COLLECTED_ICON_TEXTURE))
	row.add_child(_build_source_icon(was_salvaged, SALVAGED_ICON_TEXTURE))

	var icon_holder := CenterContainer.new()
	icon_holder.custom_minimum_size = ENTRY_ICON_SIZE
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = ENTRY_ICON_SIZE
	icon_rect.size = ENTRY_ICON_SIZE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.texture = item_data.sprite if item_data != null else null
	if icon_rect.texture == null:
		icon_rect.texture = _create_placeholder_texture(item_data)
	icon_holder.add_child(icon_rect)
	row.add_child(icon_holder)

	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(ENTRY_NAME_WIDTH, 0.0)
	name_label.text = str(entry.get("name", "Unknown Material"))
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	if item_data != null:
		name_label.add_theme_color_override("font_color", item_data.get_rarity_color())
	row.add_child(name_label)

	var count_label := Label.new()
	count_label.custom_minimum_size = Vector2(56.0, 0.0)
	count_label.text = "x%d" % int(entry.get("count", 0))
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	count_label.add_theme_font_size_override("font_size", 18)
	row.add_child(count_label)

	return row


func _format_elapsed_time(total_seconds: float) -> String:
	var seconds := maxi(int(round(total_seconds)), 0)
	var minutes := seconds / 60
	var remainder := seconds % 60
	return "%d:%02d" % [minutes, remainder]


func _create_placeholder_texture(item_data: SalvageItemData) -> Texture2D:
	var image := Image.create(int(ENTRY_ICON_SIZE.x), int(ENTRY_ICON_SIZE.y), false, Image.FORMAT_RGBA8)
	var fill_color := Color.WHITE
	if item_data != null:
		fill_color = item_data.get_rarity_color()
	image.fill(fill_color)
	return ImageTexture.create_from_image(image)


func _build_source_icon(is_active: bool, tex: Texture2D) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = SOURCE_ICON_SIZE

	var icon := TextureRect.new()
	icon.custom_minimum_size = SOURCE_ICON_SIZE
	icon.size = SOURCE_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = tex
	icon.visible = is_active
	holder.add_child(icon)
	return holder


func _on_menu_pressed() -> void:
	main_menu_requested.emit()

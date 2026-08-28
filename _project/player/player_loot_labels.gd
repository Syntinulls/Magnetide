extends Node
class_name PlayerLootLabels

## Floating gain/loss labels stacked above the player's head, keyed by text:
## recording an amount whose text is already on screen folds it into that line's
## running total ("+6 Scrap Metal") and restarts its lifetime, while distinct
## texts stack as separate lines. The sign is derived from the running total, so
## losses render as "-N ...".

const LABEL_OFFSET_Y: float = -86.0
const LABEL_SPACING: float = 24.0
const LABEL_POP_DURATION: float = 0.14
const LABEL_LIFETIME_SECONDS: float = 0.75
const LABEL_FADE_SECONDS: float = 0.35
const LABEL_DRIFT_DISTANCE: float = 18.0

class Entry:
	var text: String
	var total: int = 0
	var label: Label
	var pop_tween: Tween
	var fade_tween: Tween

var _entries: Array[Entry] = []

@onready var _player: Player = owner as Player


## Records a signed amount under a label key; an already-visible label with the
## same text absorbs the amount into its displayed total, otherwise a new line
## joins the stack.
func record(text: String, amount: int) -> void:
	if _player == null or not _player.is_inside_tree():
		return
	var entry := _find_entry(text)
	if entry:
		entry.total += amount
		_update_entry_text(entry)
		entry.label.position = _label_target_position(entry.label, _reverse_index(entry))
		entry.label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_play_pop(entry)
		_restart_lifetime(entry)
		return
	var game_ui := Magnetide.game_ui
	if not game_ui:
		return
	entry = Entry.new()
	entry.text = text
	entry.total = amount
	entry.label = _make_label()
	game_ui.add_child(entry.label)
	_entries.append(entry)
	_update_entry_text(entry)
	entry.label.position = _label_target_position(entry.label, 0)
	entry.label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_reposition_labels()
	_play_pop(entry)
	entry.label.create_tween().tween_property(entry.label, "modulate:a", 1.0, LABEL_POP_DURATION * 0.8)
	_restart_lifetime(entry)


func _find_entry(text: String) -> Entry:
	for entry in _entries:
		if entry.text == text and entry.label and is_instance_valid(entry.label):
			return entry
	return null


func _reverse_index(entry: Entry) -> int:
	return (_entries.size() - 1) - _entries.find(entry)


func _make_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Magnetide.apply_label_font(label)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("d8d8d8"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _update_entry_text(entry: Entry) -> void:
	var sign_text := "+" if entry.total >= 0 else "-"
	entry.label.text = "%s%d %s" % [sign_text, absi(entry.total), entry.text]
	entry.label.size = entry.label.get_combined_minimum_size()


func _play_pop(entry: Entry) -> void:
	if entry.pop_tween and entry.pop_tween.is_valid():
		entry.pop_tween.kill()
	entry.label.scale = Vector2(0.82, 0.82)
	entry.pop_tween = entry.label.create_tween()
	entry.pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entry.pop_tween.tween_property(entry.label, "scale", Vector2.ONE, LABEL_POP_DURATION)


func _restart_lifetime(entry: Entry) -> void:
	if entry.fade_tween and entry.fade_tween.is_valid():
		entry.fade_tween.kill()
	entry.fade_tween = entry.label.create_tween()
	entry.fade_tween.tween_interval(LABEL_LIFETIME_SECONDS)
	entry.fade_tween.tween_property(entry.label, "position", Vector2(0.0, -LABEL_DRIFT_DISTANCE), LABEL_FADE_SECONDS) \
		.as_relative()
	entry.fade_tween.parallel().tween_property(entry.label, "modulate:a", 0.0, LABEL_FADE_SECONDS)
	entry.fade_tween.finished.connect(_on_entry_expired.bind(entry))


func _on_entry_expired(entry: Entry) -> void:
	_entries.erase(entry)
	if entry.label and is_instance_valid(entry.label):
		entry.label.queue_free()
	_reposition_labels()


func _reposition_labels() -> void:
	for index in range(_entries.size()):
		var entry := _entries[index]
		if entry.label == null or not is_instance_valid(entry.label):
			continue
		entry.label.size = entry.label.get_combined_minimum_size()
		var reverse_index := (_entries.size() - 1) - index
		var target_position := _label_target_position(entry.label, reverse_index)
		var tween := entry.label.create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(entry.label, "position", target_position, 0.12)


func _label_target_position(label: Label, stack_index_from_bottom: int) -> Vector2:
	var base_position := _player.get_viewport().get_canvas_transform() * (_player.global_position + Vector2(0.0, LABEL_OFFSET_Y))
	return Vector2(
		base_position.x - (label.size.x * 0.5),
		base_position.y - (stack_index_from_bottom * LABEL_SPACING) - label.size.y
	)

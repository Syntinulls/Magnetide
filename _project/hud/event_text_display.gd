extends Control
class_name EventTextDisplay

## Generic in-run event banner, shown top-center below the threat bar.
##
## Two lines: a headline naming what is currently happening ("STORM IMMINENT",
## "WAVE 2 / 4") and a smaller subtext carrying live detail ("REMAINING - 7").
##
## A shared, multi-writer surface. Entries are keyed by source, so any system can
## post without knowing about the others; the highest-priority live entry is shown.
## Writers own their source and must clear it when their event ends — nothing else
## cleans up after them.
##
## This is a pure view. It holds no timers and no state machine: each system owns
## its own clock and pushes formatted text, so run progression is never driven from
## the HUD.

enum Style { NORMAL, WARNING, CRITICAL }

const STYLE_COLORS: Dictionary = {
	Style.NORMAL: Color(1, 1, 1, 1),
	Style.WARNING: Color(1, 0.84, 0.3, 1),
	Style.CRITICAL: Color(1, 0.36, 0.3, 1),
}
## Subtext is dimmer than its headline so the two lines read as a hierarchy.
const SUBTEXT_ALPHA: float = 0.75

@onready var _label: Label = $Label
@onready var _subtext_label: Label = $SubtextLabel

# source (StringName) -> entry Dictionary
var _entries: Dictionary = {}


func _ready() -> void:
	if Magnetide and Magnetide.has_method("apply_label_font"):
		if _label:
			Magnetide.apply_label_font(_label)
		if _subtext_label:
			Magnetide.apply_label_font(_subtext_label)
	_refresh()


## Post or replace a source's entry. `subtext` is the optional second line.
func show_message(
	source: StringName,
	text: String,
	subtext: String = "",
	priority: int = 0,
	style: int = Style.NORMAL
) -> void:
	_entries[source] = {
		"text": text,
		"subtext": subtext,
		"priority": priority,
		"style": style,
	}
	_refresh()


## Replace just the second line of an existing entry. No-op if the source has none.
func set_subtext(source: StringName, subtext: String) -> void:
	if not _entries.has(source):
		return
	var entry: Dictionary = _entries[source]
	if String(entry.get("subtext", "")) == subtext:
		return
	entry["subtext"] = subtext
	_refresh()


## Remove a source's entry, if present.
func clear(source: StringName) -> void:
	if _entries.erase(source):
		_refresh()


func _refresh() -> void:
	if not _label:
		return
	var source := _highest_priority_source()
	if source == &"":
		visible = false
		_label.text = ""
		if _subtext_label:
			_subtext_label.text = ""
			_subtext_label.visible = false
		return

	var entry: Dictionary = _entries[source]
	visible = true
	_label.text = String(entry.get("text", ""))
	var color: Color = STYLE_COLORS.get(int(entry.get("style", Style.NORMAL)), Color.WHITE)
	_label.add_theme_color_override("font_color", color)

	if not _subtext_label:
		return
	var subtext := String(entry.get("subtext", ""))
	_subtext_label.text = subtext
	_subtext_label.visible = not subtext.is_empty()
	_subtext_label.add_theme_color_override(
		"font_color", Color(color.r, color.g, color.b, color.a * SUBTEXT_ALPHA)
	)


func _highest_priority_source() -> StringName:
	var best := &""
	var best_priority := -0x7FFFFFFF
	for source in _entries:
		var priority := int(_entries[source].get("priority", 0))
		if priority > best_priority:
			best_priority = priority
			best = source
	return best

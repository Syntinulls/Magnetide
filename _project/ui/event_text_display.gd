extends Control
class_name EventTextDisplay

## Generic in-run event text banner, shown top-center below the threat bar.
##
## Any system can post a styled announcement ("SALVAGE DETECTED") or a
## self-running countdown ("STORM IMMINENT IN 45s"). Entries are keyed by a
## source name; the highest-priority active entry is displayed. This replaces
## the bespoke run countdown / departure timer / warning icon presentations.

signal countdown_finished(source: StringName)

enum Style { NORMAL, WARNING, CRITICAL }

const STYLE_COLORS: Dictionary = {
	Style.NORMAL: Color(1, 1, 1, 1),
	Style.WARNING: Color(1, 0.84, 0.3, 1),
	Style.CRITICAL: Color(1, 0.36, 0.3, 1),
}

@onready var _label: Label = $Label

# source (StringName) -> entry Dictionary
var _entries: Dictionary = {}


func _ready() -> void:
	if _label and Magnetide and Magnetide.has_method("apply_label_font"):
		Magnetide.apply_label_font(_label)
	set_process(false)
	_refresh()


## Show static announcement text for a source (e.g. "SALVAGE DETECTED").
func show_message(source: StringName, text: String, priority: int = 0, style: int = Style.NORMAL) -> void:
	_entries[source] = {
		"countdown": false,
		"text": text,
		"priority": priority,
		"style": style,
	}
	_refresh()


## Start a self-running countdown displayed as "<prefix> <N><suffix>".
## Emits countdown_finished(source) and auto-clears the entry when it hits zero.
func start_countdown(
	source: StringName,
	prefix: String,
	duration: float,
	priority: int = 0,
	style: int = Style.CRITICAL,
	suffix: String = "s"
) -> void:
	_entries[source] = {
		"countdown": true,
		"prefix": prefix,
		"suffix": suffix,
		"remaining": maxf(duration, 0.0),
		"priority": priority,
		"style": style,
	}
	set_process(true)
	_refresh()


## Remove a source's entry, if present.
func clear(source: StringName) -> void:
	if _entries.erase(source):
		_refresh()


func clear_all() -> void:
	if _entries.is_empty():
		return
	_entries.clear()
	_refresh()


## True while a source has an active entry.
func is_active(source: StringName) -> bool:
	return _entries.has(source)


## Remaining seconds for a source's countdown (0.0 if absent or not a countdown).
func get_remaining(source: StringName) -> float:
	if _entries.has(source):
		var entry: Dictionary = _entries[source]
		if entry.get("countdown", false):
			return float(entry.get("remaining", 0.0))
	return 0.0


func _process(delta: float) -> void:
	var any_countdown := false
	var finished: Array[StringName] = []
	for source in _entries:
		var entry: Dictionary = _entries[source]
		if not entry.get("countdown", false):
			continue
		any_countdown = true
		entry["remaining"] = maxf(float(entry["remaining"]) - delta, 0.0)
		if entry["remaining"] <= 0.0:
			finished.append(source)

	for source in finished:
		_entries.erase(source)
		countdown_finished.emit(source)

	if not any_countdown or _entries.is_empty():
		set_process(false)
	_refresh()


func _refresh() -> void:
	if not _label:
		return
	var source := _highest_priority_source()
	if source == &"":
		_label.text = ""
		visible = false
		return
	var entry: Dictionary = _entries[source]
	visible = true
	_label.text = _format_entry(entry)
	var style: int = int(entry.get("style", Style.NORMAL))
	_label.add_theme_color_override("font_color", STYLE_COLORS.get(style, Color.WHITE))


func _highest_priority_source() -> StringName:
	var best := &""
	var best_priority := -0x7FFFFFFF
	for source in _entries:
		var priority := int(_entries[source].get("priority", 0))
		if priority > best_priority:
			best_priority = priority
			best = source
	return best


func _format_entry(entry: Dictionary) -> String:
	if entry.get("countdown", false):
		var seconds := int(ceil(float(entry.get("remaining", 0.0))))
		return "%s %d%s" % [entry.get("prefix", ""), seconds, entry.get("suffix", "s")]
	return String(entry.get("text", ""))

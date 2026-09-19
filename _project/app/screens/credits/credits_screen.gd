extends Control
class_name CreditsScreen

## Attribution screen, reachable from the main menu only. It lists every music track the
## game can play, each with the credit authored beside it as a MusicCredit resource, so a
## track that is dropped into a BGM category folder is credited by adding its `.credit.tres`
## next to it — no edit here.
##
## Entries are built at runtime because there is one row per track (spec §9); the shell,
## headers and back button are authored in the scene.

signal back_requested

const ENTRY_FONT_SIZE: int = 24
const MISSING_CREDIT_COLOR := Color(1.0, 0.45, 0.45)
const LINK_COLOR := Color(0.55, 0.82, 1.0)
## Shown in place of a name nobody has filled in yet, so the gap is visible on screen
## rather than silently rendering as an empty line.
const MISSING_FIELD_TEXT := "credit needed"

@onready var _music_list: VBoxContainer = $Margin/Layout/Scroll/Sections/MusicList
@onready var _back_button: Button = $Margin/Layout/Footer/BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_populate_music_credits()
	Magnetide.apply_label_fonts(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	back_requested.emit()
	var app_root := Magnetide.app_root
	if app_root != null and app_root.has_method("show_main_menu"):
		app_root.call("show_main_menu")


## One row per playable track, ordered the way the player lists them. A track with no
## credit file still gets a row: a missing attribution is a problem to see, not to hide.
func _populate_music_credits() -> void:
	for child in _music_list.get_children():
		child.queue_free()
	for track_path in _get_music_track_paths():
		_music_list.add_child(_build_credit_row(track_path))


## Every track the game can play. Asks the BGM player, so "what is in the game" has one
## definition — the folder scan playback itself uses.
func _get_music_track_paths() -> Array[String]:
	var bgm := Magnetide.bgm
	if bgm != null and bgm.has_method("get_all_track_paths"):
		return bgm.call("get_all_track_paths")
	return []


func _build_credit_row(track_path: String) -> RichTextLabel:
	var row := RichTextLabel.new()
	row.bbcode_enabled = true
	row.fit_content = true
	row.scroll_active = false
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_font_size_override("normal_font_size", ENTRY_FONT_SIZE)
	row.text = _build_credit_bbcode(track_path)
	row.meta_clicked.connect(_on_link_clicked)
	return row


## "Title by Artist — CC BY 3.0", with the title linking to the source and the license to
## its deed. Anything not filled in yet is called out in red instead of left blank.
func _build_credit_bbcode(track_path: String) -> String:
	var credit := _load_credit(track_path)
	if credit == null:
		return "[color=#%s]%s — no credit file (%s)[/color]" % [
			MISSING_CREDIT_COLOR.to_html(false),
			track_path.get_file(),
			MusicCredit.path_for_track(track_path).get_file(),
		]

	var title := _linked(_field(credit.title, "Untitled"), credit.source_url)
	var artist := _field(credit.artist, "")
	var line := "%s by %s" % [title, artist]
	if not credit.license.strip_edges().is_empty():
		line += " — %s" % _linked(credit.license, credit.license_url)
	if credit.modified:
		line += " (edited for this game)"
	return line


## A filled-in value, or a visible marker when it is still blank.
func _field(value: String, fallback: String) -> String:
	var text := value.strip_edges()
	if not text.is_empty():
		return text
	if not fallback.is_empty():
		return fallback
	return "[color=#%s]%s[/color]" % [MISSING_CREDIT_COLOR.to_html(false), MISSING_FIELD_TEXT]


## Wraps `text` in a link when there is a URL to point at; plain text otherwise, so a
## credit whose link has not been filled in yet still reads correctly.
func _linked(text: String, url: String) -> String:
	if url.strip_edges().is_empty():
		return text
	return "[url=%s][color=#%s]%s[/color][/url]" % [url, LINK_COLOR.to_html(false), text]


func _load_credit(track_path: String) -> MusicCredit:
	var credit_path := MusicCredit.path_for_track(track_path)
	if not ResourceLoader.exists(credit_path):
		return null
	return load(credit_path) as MusicCredit


func _on_link_clicked(meta: Variant) -> void:
	var url := str(meta)
	if url.begins_with("http://") or url.begins_with("https://"):
		OS.shell_open(url)

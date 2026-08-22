extends Control
class_name OptionsScreen

## Modal options panel opened over the main menu or the paused run
## (AppRoot.open_options_menu). Slider changes apply to the game immediately as
## a live preview; OK persists them to disk, while Cancel (or ESC) reverts to
## the on-disk values — asking first when there are unsaved changes. Values
## persist via AppOptions (user://options.ini).

const TAB_ACTIVE_COLOR := Color.WHITE
const TAB_INACTIVE_COLOR := Color(1.0, 1.0, 1.0, 0.55)

@onready var _tabs: TabContainer = %Tabs
@onready var _tab_buttons: HBoxContainer = %TabButtons
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value_label: Label = %MusicValueLabel
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value_label: Label = %SfxValueLabel
@onready var _bloom_check: CheckBox = %BloomCheckBox
@onready var _ok_button: Button = %OkButton
@onready var _cancel_button: Button = %CancelButton
@onready var _unsaved_confirm: Control = %UnsavedConfirm
@onready var _apply_button: Button = %ApplyButton
@onready var _discard_button: Button = %DiscardButton

var _saved: AppOptions = null


func _ready() -> void:
	_saved = AppOptions.load_from_disk()
	_music_slider.value = _saved.music_volume
	_sfx_slider.value = _saved.sfx_volume
	_bloom_check.button_pressed = _saved.bloom_enabled
	_hide_slider_grabbers()
	for index in _tab_buttons.get_child_count():
		var tab_button := _tab_buttons.get_child(index) as Button
		if tab_button:
			tab_button.pressed.connect(_on_tab_button_pressed.bind(index))
	_refresh_tab_buttons()
	_music_slider.value_changed.connect(_on_slider_changed)
	_sfx_slider.value_changed.connect(_on_slider_changed)
	_bloom_check.toggled.connect(_on_bloom_toggled)
	_ok_button.pressed.connect(_on_ok_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_apply_button.pressed.connect(_on_confirm_apply_pressed)
	_discard_button.pressed.connect(_on_confirm_discard_pressed)
	_refresh_value_labels()


# _input rather than _unhandled_input so ESC reaches us before the pause menu's
# own toggle while the tree is paused behind this panel.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if _unsaved_confirm.visible:
		_unsaved_confirm.visible = false
	else:
		_on_cancel_pressed()


func _on_tab_button_pressed(index: int) -> void:
	_tabs.current_tab = index
	_refresh_tab_buttons()


## The header buttons are flat labels, so the active tab is signalled by font
## color alone: full white for active, dimmed for the rest.
func _refresh_tab_buttons() -> void:
	for index in _tab_buttons.get_child_count():
		var tab_button := _tab_buttons.get_child(index) as Button
		if tab_button:
			var color := TAB_ACTIVE_COLOR if index == _tabs.current_tab else TAB_INACTIVE_COLOR
			tab_button.add_theme_color_override("font_color", color)


func _on_slider_changed(_value: float) -> void:
	_refresh_value_labels()
	_current_values().apply()


## Live-previewed like the sliders, so the player sees the glow appear and
## disappear behind the panel before committing to it.
func _on_bloom_toggled(_pressed: bool) -> void:
	_current_values().apply()


func _refresh_value_labels() -> void:
	_music_value_label.text = "%d%%" % roundi(_music_slider.value)
	_sfx_value_label.text = "%d%%" % roundi(_sfx_slider.value)


func _is_dirty() -> bool:
	return not _current_values().equals(_saved)


func _current_values() -> AppOptions:
	var options := AppOptions.new()
	options.music_volume = _music_slider.value
	options.sfx_volume = _sfx_slider.value
	options.bloom_enabled = _bloom_check.button_pressed
	return options


func _on_ok_pressed() -> void:
	_save_and_close()


func _on_cancel_pressed() -> void:
	if _is_dirty():
		_unsaved_confirm.visible = true
	else:
		_close()


func _on_confirm_apply_pressed() -> void:
	_save_and_close()


func _on_confirm_discard_pressed() -> void:
	_saved.apply()
	_close()


func _save_and_close() -> void:
	_saved = _current_values()
	_saved.apply()
	_saved.save_to_disk()
	_close()


func _close() -> void:
	queue_free()


## The sliders are styled as solid fill bars with the percentage centered in
## them; a visible grabber knob would break that read, so it gets a blank icon.
func _hide_slider_grabbers() -> void:
	var blank := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for slider: HSlider in [_music_slider, _sfx_slider]:
		slider.add_theme_icon_override("grabber", blank)
		slider.add_theme_icon_override("grabber_highlight", blank)
		slider.add_theme_icon_override("grabber_disabled", blank)

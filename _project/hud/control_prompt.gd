extends HBoxContainer
class_name ControlPrompt

## A single control-prompt row: an optional "HOLD" prefix, a keycap (e.g. [E] /
## [LMB]), and the action text (e.g. DEPART). Built programmatically so the stack
## can spawn/configure rows on demand.

const TEXT_COLOR := Color(1, 1, 1, 1)
const OUTLINE_COLOR := Color(0, 0, 0, 1)
const KEYCAP_BG := Color(0.12, 0.13, 0.16, 0.92)
const KEYCAP_BORDER := Color(0.92, 0.94, 1.0, 1.0)
const FONT_SIZE := 44
const OUTLINE_SIZE := 12


func configure(key: String, action: String, hold: bool) -> void:
	for child in get_children():
		child.queue_free()
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 16)

	if hold:
		add_child(_make_label("HOLD"))
	add_child(_make_keycap(key))
	add_child(_make_label(action))


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	if Magnetide and Magnetide.has_method("apply_label_font"):
		Magnetide.apply_label_font(label)
	return label


func _make_keycap(key: String) -> Control:
	var keycap := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = KEYCAP_BG
	style.border_color = KEYCAP_BORDER
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	keycap.add_theme_stylebox_override("panel", style)
	keycap.add_child(_make_label(key))
	return keycap

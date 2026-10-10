class_name UiKit
extends RefCounted

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/Silkscreen-Regular.ttf")
	return _font


static func panel_style(color: Color = Color("1c2230")) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("f0a020")
	box.set_border_width_all(2)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(14)
	return box


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = font()
	theme.default_font_size = 16
	var normal := _button(Color("262d3e"), Color("f0a020"))
	var hover := _button(Color("343c52"), Color("ffd060"))
	var pressed := _button(Color("1a2030"), Color("2ec4b6"))
	var disabled := _button(Color("1a1e28"), Color("4a5160"))
	var focus := normal.duplicate()
	focus.border_color = Color("2ec4b6")
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_color("font_color", "Button", Color("f4efe4"))
	theme.set_color("font_disabled_color", "Button", Color("8b93a3"))
	theme.set_color("font_hover_color", "Button", Color("fff6df"))
	theme.set_color("font_color", "Label", Color("f4efe4"))
	theme.set_stylebox("panel", "Panel", panel_style())
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	var line := _button(Color("12151e"), Color("8b93a3"))
	theme.set_stylebox("normal", "LineEdit", line)
	theme.set_color("font_color", "LineEdit", Color("f4efe4"))
	theme.set_color("font_placeholder_color", "LineEdit", Color("8b93a3"))
	theme.set_stylebox("panel", "OptionButton", normal)
	return theme


static func _button(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(10)
	return box

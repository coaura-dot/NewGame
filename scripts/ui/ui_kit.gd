class_name UIKit
extends RefCounted
## Tema e construtores de UI (feitos em código para ficar fácil de trocar a
## identidade visual num lugar só). Navegável por teclado/controle.

const FONT := preload("res://assets/fonts/kenney_pixel.ttf")
const FONT_TITLE := preload("res://assets/fonts/kenney_high.ttf")
const GOLD := Color(1.0, 0.82, 0.45)
const INK := Color(0.93, 0.9, 0.84)
const DIM := Color(0.62, 0.58, 0.7)
const BG := Color(0.05, 0.04, 0.09, 0.94)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 12
	var panel := _box(BG, Color(0.42, 0.34, 0.58), 1)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	var normal := _box(Color(0.11, 0.09, 0.17, 0.95), Color(0.3, 0.25, 0.42), 1)
	var hover := _box(Color(0.2, 0.15, 0.3, 0.98), GOLD, 1)
	var pressed := _box(Color(0.28, 0.2, 0.12, 1.0), GOLD, 1)
	var disabled := _box(Color(0.08, 0.07, 0.1, 0.8), Color(0.2, 0.2, 0.25), 1)
	for cls in ["Button", "OptionButton", "CheckBox", "CheckButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("focus", cls, _box(Color(0, 0, 0, 0), GOLD, 1))
		t.set_stylebox("disabled", cls, disabled)
		t.set_color("font_color", cls, INK)
		t.set_color("font_hover_color", cls, GOLD)
		t.set_color("font_focus_color", cls, GOLD)
		t.set_color("font_pressed_color", cls, Color(1, 1, 1))
		t.set_color("font_disabled_color", cls, Color(0.4, 0.4, 0.45))
		t.set_font_size("font_size", cls, 12)
	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", 12)
	t.set_stylebox("slider", "HSlider", _box(Color(0.15, 0.12, 0.22), Color(0.3, 0.25, 0.42), 1))
	t.set_stylebox("grabber_area", "HSlider", _box(Color(0.6, 0.45, 0.25), Color(0, 0, 0, 0), 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(GOLD, Color(0, 0, 0, 0), 0))
	t.set_stylebox("panel", "TabContainer", panel)
	t.set_stylebox("tab_selected", "TabContainer", _box(Color(0.2, 0.15, 0.3), GOLD, 1))
	t.set_stylebox("tab_unselected", "TabContainer", _box(Color(0.09, 0.07, 0.14), Color(0.3, 0.25, 0.42), 1))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color(0.16, 0.12, 0.24), GOLD, 1))
	t.set_color("font_selected_color", "TabContainer", GOLD)
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_stylebox("panel", "PopupMenu", panel)
	t.set_stylebox("normal", "LineEdit", normal)
	t.set_stylebox("focus", "LineEdit", hover)
	t.set_stylebox("panel", "ItemList", normal)
	t.set_stylebox("scroll", "VScrollBar", _box(Color(0.1, 0.08, 0.15), Color(0, 0, 0, 0), 0))
	t.set_stylebox("grabber", "VScrollBar", _box(Color(0.35, 0.28, 0.45), Color(0, 0, 0, 0), 0))
	_theme = t
	return t


static func _box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(2)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


static func label(text: String, size: int = 12, color: Color = INK, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	return l


static func title(text: String, size: int = 32) -> Label:
	var l := label(text, size, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", FONT_TITLE)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.02, 0.1))
	l.add_theme_constant_override("outline_size", 4)
	return l


static func button(text: String, callback: Callable, min_w: float = 140.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 18)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Audio.play("ui_confirm", 0.0, -8.0)
		callback.call())
	b.focus_entered.connect(func(): Audio.play("ui_move", 0.0, -14.0))
	return b


static func check(text: String, value: bool, on_change: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(v): on_change.call(v))
	return c


static func slider(text: String, value: float, min_v: float, max_v: float, step: float, on_change: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := label(text)
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(110, 14)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	var val := label("%.2f" % value, 12, DIM)
	val.custom_minimum_size = Vector2(34, 0)
	s.value_changed.connect(func(v):
		val.text = "%.2f" % v
		on_change.call(v))
	h.add_child(s)
	h.add_child(val)
	return h


static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


static func vbox(sep: int = 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(child)
	return c


static func focus_first(root: Node) -> void:
	for c in root.find_children("*", "BaseButton", true, false):
		if c.visible and not c.disabled:
			c.grab_focus.call_deferred()
			return

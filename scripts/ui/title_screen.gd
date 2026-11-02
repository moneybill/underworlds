class_name TitleScreen
extends Control
## The title screen shown at launch. It opens on "TAP TO CONTINUE"; a tap, click or key press
## brings in the menu (Venture Onwards, Options) while the title art stays on screen.

signal venture

const BG := Color("05060a")
const STONE := Color("191d29")
const LINE := Color("3a4159")
const INK := Color("eadfc4")
const DIM := Color("9c947f")
const TORCH := Color("e3a33f")

var display: Font
var mono: Font
var _state := "press"  # press, menu, options
var _time := 0.0
var _prompt: Label
var _menu: VBoxContainer
var _venture_btn: Button
var _options: CenterContainer
var _back_btn: Button


func _init(display_font: Font, mono_font: Font) -> void:
	display = display_font
	mono = mono_font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	_prompt = Label.new()
	_prompt.text = "TAP TO CONTINUE"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_override("font", mono)
	_prompt.add_theme_font_size_override("font_size", 30)
	_prompt.add_theme_color_override("font_color", INK)
	_prompt.custom_minimum_size = Vector2(0, 150)
	col.add_child(_prompt)

	var menu_center := CenterContainer.new()
	menu_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(menu_center)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	_menu.visible = false
	menu_center.add_child(_menu)
	_venture_btn = _make_button("Venture Onwards", func(): venture.emit())
	_menu.add_child(_venture_btn)
	_menu.add_child(_make_button("Options", _open_options))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	_menu.add_child(spacer)

	_options = CenterContainer.new()
	_options.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_options.visible = false
	var dim := ColorRect.new()
	dim.color = Color(BG, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.visible = false
	_options.set_meta("dim", dim)
	add_child(_options)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = STONE
	sb.border_color = LINE
	sb.set_border_width_all(1)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(420, 0)
	_options.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 22)
	panel.add_child(pv)
	var heading := Label.new()
	heading.text = "Options"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", display)
	heading.add_theme_font_size_override("font_size", 36)
	heading.add_theme_color_override("font_color", TORCH)
	pv.add_child(heading)
	_back_btn = _make_button("Back", _close_options)
	pv.add_child(_back_btn)


func _make_button(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 58)
	b.add_theme_font_override("font", display)
	b.add_theme_font_size_override("font_size", 28)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(STONE, 0.92)
	normal.border_color = LINE
	normal.set_border_width_all(1)
	normal.set_content_margin_all(10)
	var hover := normal.duplicate()
	hover.border_color = TORCH
	var pressed := normal.duplicate()
	pressed.bg_color = TORCH
	pressed.border_color = TORCH
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", TORCH)
	b.add_theme_color_override("font_focus_color", TORCH)
	b.add_theme_color_override("font_pressed_color", BG)
	b.pressed.connect(fn)
	return b


# ---------- state ----------
func show_menu() -> void:
	_state = "menu"
	_prompt.visible = false
	_menu.visible = true
	_menu.modulate.a = 0.0
	create_tween().tween_property(_menu, "modulate:a", 1.0, 0.35)
	_venture_btn.grab_focus()


func _open_options() -> void:
	_state = "options"
	_options.visible = true
	_options.get_meta("dim").visible = true
	_menu.visible = false
	_back_btn.grab_focus()


func _close_options() -> void:
	_state = "menu"
	_options.visible = false
	_options.get_meta("dim").visible = false
	_menu.visible = true
	_venture_btn.grab_focus()


func _gui_input(event: InputEvent) -> void:
	if _state == "press" and _is_tap(event):
		accept_event()
		show_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _state == "press" and _is_tap(event):
		get_viewport().set_input_as_handled()
		show_menu()
	elif _state == "options" and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_options()


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		return event.is_pressed()
	if event is InputEventKey:
		return event.is_pressed() and not event.is_echo()
	return false


# ---------- the picture ----------
func _process(delta: float) -> void:
	_time += delta
	if _state == "press":
		_prompt.modulate.a = 0.55 + 0.45 * sin(_time * 3.0)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var c := Vector2(w / 2.0, h * 0.5)
	# A corridor receding to a lit doorway.
	var depth := 7
	var prev := Rect2(Vector2.ZERO, size)
	for i in range(1, depth + 1):
		var s: float = pow(0.62, i)
		var r := Rect2(c.x - w * s / 2.0, c.y - h * s / 2.0, w * s, h * s)
		var shade: float = 0.07 + 0.02 * i
		var wall := Color(shade * 0.8, shade * 0.85, shade * 1.25)
		draw_colored_polygon(PackedVector2Array([prev.position, r.position, Vector2(r.position.x, r.end.y), Vector2(prev.position.x, prev.end.y)]), wall)
		draw_colored_polygon(PackedVector2Array([Vector2(prev.end.x, prev.position.y), Vector2(r.end.x, r.position.y), r.end, prev.end]), wall)
		var edge := Color(TORCH, 0.12 + 0.07 * i)
		draw_line(prev.position, r.position, edge, 1.5, true)
		draw_line(Vector2(prev.end.x, prev.position.y), Vector2(r.end.x, r.position.y), edge, 1.5, true)
		draw_line(Vector2(prev.position.x, prev.end.y), Vector2(r.position.x, r.end.y), edge, 1.5, true)
		draw_line(prev.end, r.end, edge, 1.5, true)
		draw_rect(r, edge, false, 1.0)
		prev = r
	# Torchlight at the far door.
	var flicker := 0.85 + 0.15 * sin(_time * 7.3) * sin(_time * 3.1)
	for i in 6:
		draw_circle(c, prev.size.x * (2.6 - i * 0.35), Color(TORCH, 0.035 * flicker))
	var door := Rect2(c.x - prev.size.x * 0.3, c.y - prev.size.y * 0.35, prev.size.x * 0.6, prev.size.y * 0.85)
	draw_rect(door, Color(TORCH, 0.55 * flicker))
	# Title.
	var title_size := int(clampf(w * 0.085, 48, 120))
	var ty := h * 0.24
	draw_string(display, Vector2(0, ty + 4), "Underworlds 2", HORIZONTAL_ALIGNMENT_CENTER, w, title_size, Color(BG, 0.85))
	draw_string(display, Vector2(0, ty), "Underworlds 2", HORIZONTAL_ALIGNMENT_CENTER, w, title_size, TORCH)
	var sub_size := int(clampf(w * 0.022, 18, 30))
	draw_string(mono, Vector2(0, ty + sub_size * 1.9), "PROVING GROUNDS OF THE MAD OVERLORD", HORIZONTAL_ALIGNMENT_CENTER, w, sub_size, INK)

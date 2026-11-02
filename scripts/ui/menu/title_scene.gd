extends Control
## The title painting. A tap brings up its buttons: Venture Onwards enters the game where the last
## save left it, and Options opens the options panel.

const GAME_SCENE := "res://scenes/main.tscn"
const ART := "res://assets/images/title.webp"
const BOTTOM_MARGIN := 36
const PANEL_WIDTH := 360.0
const BUTTON_ART := "res://assets/images/buttons/%s_%s.png"
const ART_SCALE := 800.0 / 1080.0  # shows the art pixel for pixel in the 1920x1080 window
const BUTTON_FONT := 30
const TEXT_LIFT := 8  # centres the text on the plate, which sits above the ornament hanging off it

var nav: VBoxContainer
var venture_button: Button
var options_button: Button
var options_panel: Control
var back_button: Button
var _tap: Label
var _t := 0.0
var _pressed := false
var _going := false


func _ready() -> void:
	theme = UiStyle.build_theme(UiStyle.mono_font())
	var art := TextureRect.new()
	art.name = "Art"
	art.texture = load(ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	_tap = Label.new()
	_tap.text = "TAP TO CONTINUE"
	_tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap.add_theme_font_size_override("font_size", 26)
	_tap.add_theme_constant_override("outline_size", 8)
	_tap.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_tap)
	_pin_bottom(_tap)
	nav = VBoxContainer.new()
	nav.add_theme_constant_override("separation", 0)
	nav.visible = false
	add_child(nav)
	venture_button = _button("Venture Onwards", "large", _venture, nav)
	options_button = _button("Options", "medium", _show_options.bind(true), nav)
	nav.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	nav.grow_horizontal = Control.GROW_DIRECTION_BOTH
	nav.grow_vertical = Control.GROW_DIRECTION_BOTH
	_build_options()


func _build_options() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.visible = false
	add_child(center)
	options_panel = center
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.custom_minimum_size.x = PANEL_WIDTH
	panel.add_child(v)
	var heading := Label.new()
	heading.text = "Options"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", UiStyle.display_font())
	heading.add_theme_font_size_override("font_size", 38)
	heading.add_theme_color_override("font_color", UiStyle.C_TORCH)
	v.add_child(heading)
	back_button = _button("Back", "medium", _show_options.bind(false), v)


func _button(text: String, art: String, handler: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var normal := _art_box(art, "normal")
	b.custom_minimum_size = Vector2(normal.texture.get_size()) * ART_SCALE
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, normal)
	b.add_theme_stylebox_override("pressed", _art_box(art, "pressed"))
	b.add_theme_font_override("font", UiStyle.display_font())
	b.add_theme_font_size_override("font_size", BUTTON_FONT)
	b.add_theme_color_override("font_hover_color", UiStyle.C_TORCH)
	b.add_theme_color_override("font_pressed_color", UiStyle.C_INK)
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


func _art_box(art: String, state: String) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(BUTTON_ART % [art, state])
	box.content_margin_bottom = TEXT_LIFT
	return box


## Bottom centre, growing up and out so it stays there whatever its size.
func _pin_bottom(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	c.offset_left = 0
	c.offset_right = 0
	c.offset_top = -BOTTOM_MARGIN
	c.offset_bottom = -BOTTOM_MARGIN
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _process(delta: float) -> void:
	_t += delta
	_tap.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 3.0))


## The buttons wait for a whole tap made on this screen. Showing them on the press would let that
## same tap land on a button, and the release of the click that skipped the company screen isn't one.
func _input(event: InputEvent) -> void:
	if not _tap.visible or not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if event.pressed:
		_pressed = true
	elif _pressed:
		_tap.visible = false
		nav.visible = true
		set_process(false)


func _show_options(on: bool) -> void:
	options_panel.visible = on
	nav.visible = not on


## The game scene loads the save, or starts at the castle when there isn't one.
func _venture() -> void:
	if _going:
		return
	_going = true
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)

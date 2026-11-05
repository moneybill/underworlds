extends Control
## The title painting. A tap brings up its buttons: Venture Onwards enters the game where the last
## save left it, and Options opens the options panel.

const GAME_SCENE := "res://scenes/main.tscn"
const ART := "res://assets/images/title.webp"
const BOTTOM_LINE := 54.0  # the tap message and Venture Onwards are centered this far above the bottom
const PANEL_WIDTH := 360.0
const HEADING_FONT := 28
const VENTURE_SIZE := Vector2(300, 48)
const OPTIONS_MARGIN := 24.0

var nav: Control
var venture_button: Button
var options_button: Button
var options_panel: Control
var back_button: Button
var fast_results_button: ToggleSwitch
var fast_results_label: Label
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
	nav = Control.new()
	nav.set_anchors_preset(Control.PRESET_FULL_RECT)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.visible = false
	add_child(nav)
	venture_button = _plain_button("Venture Onwards", _venture, nav)
	venture_button.custom_minimum_size = VENTURE_SIZE
	_pin_bottom(venture_button)
	options_button = _plain_button("Options", _show_options.bind(true), nav)
	UiStyle.make_small_button(options_button)
	options_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	options_button.offset_left = -OPTIONS_MARGIN
	options_button.offset_right = -OPTIONS_MARGIN
	options_button.offset_top = -OPTIONS_MARGIN
	options_button.offset_bottom = -OPTIONS_MARGIN
	options_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	options_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
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
	heading.add_theme_font_size_override("font_size", HEADING_FONT)
	heading.add_theme_color_override("font_color", UiStyle.C_TORCH)
	v.add_child(heading)
	var row := HBoxContainer.new()
	v.add_child(row)
	fast_results_label = Label.new()
	fast_results_label.text = "Fast Combat Results"
	fast_results_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fast_results_label)
	fast_results_button = ToggleSwitch.new()
	fast_results_button.pressed.connect(_toggle_fast_results)
	row.add_child(fast_results_button)
	_show_fast_results()
	back_button = _plain_button("Back", _show_options.bind(false), v)
	UiStyle.make_small_button(back_button)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _plain_button(text: String, handler: Callable, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


## Bottom centre, growing out from BOTTOM_LINE so it stays centered there whatever its size.
func _pin_bottom(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	c.offset_left = 0
	c.offset_right = 0
	c.offset_top = -BOTTOM_LINE
	c.offset_bottom = -BOTTOM_LINE
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH


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


func _toggle_fast_results() -> void:
	Game.set_fast_results(not Game.fast_results)
	_show_fast_results()


func _show_fast_results() -> void:
	fast_results_button.on = Game.fast_results


## The game scene loads the save, or starts at the castle when there isn't one.
func _venture() -> void:
	if _going:
		return
	_going = true
	get_tree().change_scene_to_file.call_deferred(GAME_SCENE)

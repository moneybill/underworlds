extends Control
## The company title: white text centered on black. Fades in, holds, fades out, then the game
## title. Any tap or click skips ahead.

const COMPANY_NAME := "company name goes here"
const NEXT_SCENE := "res://scenes/title.tscn"
const FADE_IN := 0.8
const HOLD := 1.6
const FADE_OUT := 0.8

var _label: Label
var _t := 0.0
var _going := false


func _ready() -> void:
	theme = UiStyle.build_theme(UiStyle.mono_font())
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_label = Label.new()
	_label.text = COMPANY_NAME
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", UiStyle.display_font())
	_label.add_theme_font_size_override("font_size", 40)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.modulate.a = 0.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _process(delta: float) -> void:
	_t += delta
	if _t < FADE_IN:
		_label.modulate.a = _t / FADE_IN
	elif _t < FADE_IN + HOLD:
		_label.modulate.a = 1.0
	elif _t < FADE_IN + HOLD + FADE_OUT:
		_label.modulate.a = 1.0 - (_t - FADE_IN - HOLD) / FADE_OUT
	else:
		_next()


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		_next()


func _next() -> void:
	if _going:
		return
	_going = true
	get_tree().change_scene_to_file.call_deferred(NEXT_SCENE)

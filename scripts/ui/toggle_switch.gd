class_name ToggleSwitch
extends Button
## An on/off switch: a pill with a round knob that slides across. It only shows `on`; whoever owns
## it decides what a press does and sets `on` to match.

const SWITCH_SIZE := Vector2(56, 28)
const ON_FILL := Color("4f9e5a")
const OFF_FILL := Color("6b6b70")
const KNOB := Color("eeeeee")
const KNOB_SHADOW := Color(0, 0, 0, 0.35)
const RIM := 2.0
const KNOB_INSET := 3.0
const SLIDE_TIME := 0.12

var on := false: set = set_on
var _slide := 0.0
var _tween: Tween


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = SWITCH_SIZE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func set_on(value: bool) -> void:
	on = value
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_slide, _slide, 1.0 if on else 0.0, SLIDE_TIME)


func _set_slide(value: float) -> void:
	_slide = value
	queue_redraw()


func _draw() -> void:
	var fill := OFF_FILL.lerp(ON_FILL, _slide)
	var whole := Rect2(Vector2.ZERO, size)
	_pill(whole, fill.darkened(0.3))
	_pill(whole.grow(-RIM), fill)
	var radius := size.y * 0.5
	var knob_at := Vector2(lerpf(radius, size.x - radius, _slide), radius)
	draw_circle(knob_at + Vector2(0, 1), radius - KNOB_INSET + 1.0, KNOB_SHADOW, true, -1.0, true)
	draw_circle(knob_at, radius - KNOB_INSET, KNOB, true, -1.0, true)


func _pill(r: Rect2, color: Color) -> void:
	var radius := r.size.y * 0.5
	draw_rect(Rect2(r.position + Vector2(radius, 0), r.size - Vector2(r.size.y, 0)), color)
	draw_circle(r.position + Vector2(radius, radius), radius, color, true, -1.0, true)
	draw_circle(r.end - Vector2(radius, radius), radius, color, true, -1.0, true)

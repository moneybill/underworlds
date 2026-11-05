class_name LockPins
extends Control
## A lock, as a bar with pins through it. Clicking above or below the bar sets that pin up or down, and
## the half it is set to turns green.

const PIN_WIDTH := 40.0
const PIN_GAP := 60.0
const PIN_REACH := 95.0  # how far a pin stands out from the bar
const BAR_HEIGHT := 28.0
const EDGE_WIDTH := 3.0
const METAL := Color("a67c3a")
const SET := Color("4ca52e")
const EDGE := Color("0f2a3a")

signal changed

var pins: Array[int] = []  # for each slot: UP, DOWN or NOT_SET
enum { NOT_SET = -1, UP = 0, DOWN = 1 }
var flashing := false  # showing a pattern, not the player's pins, and taking no clicks
var flash_tween: Tween
var _flash_lit: Array = []  # the pattern while it is lit, and empty between flashes


func _init(given: Array[int]) -> void:
	pins = given
	var across := pins.size() * PIN_WIDTH + (pins.size() - 1) * PIN_GAP
	custom_minimum_size = Vector2(across, PIN_REACH * 2.0 + BAR_HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func all_set() -> bool:
	return not pins.has(NOT_SET)


func set_pin(slot: int, way: int) -> void:
	pins[slot] = way
	queue_redraw()
	changed.emit()


## Flashes this pattern, then calls done.
func flash(pattern: Array, times: int, lit_for: float, dark_for: float, done: Callable) -> void:
	flashing = true
	flash_tween = create_tween()
	for i in times:
		flash_tween.tween_callback(_light.bind(pattern))
		flash_tween.tween_interval(lit_for)
		flash_tween.tween_callback(_light.bind([]))
		flash_tween.tween_interval(dark_for)
	flash_tween.tween_callback(done)


func _light(pattern: Array) -> void:
	_flash_lit = pattern
	queue_redraw()


func _pin_left(slot: int) -> float:
	return slot * (PIN_WIDTH + PIN_GAP)


func _gui_input(event: InputEvent) -> void:
	if flashing or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for slot in pins.size():
		if event.position.x >= _pin_left(slot) and event.position.x <= _pin_left(slot) + PIN_WIDTH:
			var middle := PIN_REACH + BAR_HEIGHT / 2.0
			if event.position.y < middle - BAR_HEIGHT / 2.0:
				set_pin(slot, UP)
			elif event.position.y > middle + BAR_HEIGHT / 2.0:
				set_pin(slot, DOWN)
			return


func _draw() -> void:
	for slot in pins.size():
		var x := _pin_left(slot)
		var way: int = pins[slot]
		if flashing:
			way = _flash_lit[slot] if not _flash_lit.is_empty() else NOT_SET
		_box(Rect2(x, 0.0, PIN_WIDTH, PIN_REACH), SET if way == UP else METAL)
		_box(Rect2(x, PIN_REACH + BAR_HEIGHT, PIN_WIDTH, PIN_REACH), SET if way == DOWN else METAL)
	_box(Rect2(0.0, PIN_REACH, size.x, BAR_HEIGHT), METAL)


func _box(r: Rect2, fill: Color) -> void:
	draw_rect(r, fill)
	draw_rect(r, EDGE, false, EDGE_WIDTH)

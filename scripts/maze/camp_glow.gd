class_name CampGlow
extends Control
## The campfire's light flickering over the camp painting: a hot glow at the fire and a wider, softer one
## on the walls and the party around it. Like ForgeGlow, it never touches the game's random numbers.

const AT := Vector2(237, 200)  # on the canvas, a little above the logs
const CORE := Vector2(190, 170)  # the size of the hot glow, on the canvas
const SPILL := Vector2(620, 470)  # and of the light on the walls
const COLOR := Color(1.0, 0.48, 0.14)
const CORE_STRENGTH := 0.4
const SPILL_STRENGTH := 0.22
const LOW := 0.55  # the dimmest a flicker gets, as a share of full

var _view: MazeView
var _glow: GradientTexture2D
var _t := 0.0


func _init(view: MazeView) -> void:
	_view = view
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	_glow = GradientTexture2D.new()
	_glow.gradient = fade
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	visible = false


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


## How bright the fire is at a moment, from LOW to 1. Quick uneven waves, so it never settles into a beat.
static func flicker(t: float) -> float:
	var wave := 0.5 + 0.22 * sin(t * 7.3) + 0.14 * sin(t * 13.1 + 1.3) + 0.09 * sin(t * 23.7 + 0.4) + 0.05 * sin(t * 41.0 + 2.2)
	return lerpf(LOW, 1.0, clampf(wave, 0.0, 1.0))


func _draw() -> void:
	var bright := flicker(_t)
	var scale_now: float = _view.view_point(Vector2.ONE).x - _view.view_point(Vector2.ZERO).x
	var at: Vector2 = _view.view_point(AT)
	for spec in [[SPILL, SPILL_STRENGTH], [CORE, CORE_STRENGTH]]:
		var box: Vector2 = spec[0] * scale_now
		draw_texture_rect(_glow, Rect2(at - box * 0.5, box), false, Color(COLOR, spec[1] * bright))

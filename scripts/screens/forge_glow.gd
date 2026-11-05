class_name ForgeGlow
extends Control
## The heat of the Broken Anvil's forges, drawn over the town map: the coals pulse, their light spills onto the
## ground around them, and embers drift up. It never touches the game's random numbers, because how
## long the map stays open must not change what the dice roll next.

## In the map's SPOTS coordinates. core is the size of the coals' glow, spill of the light around it.
const FORGES := [
	{"at": Vector2(1317, 917), "core": Vector2(76, 76), "spill": Vector2(248, 162), "phase": 0.0},
	{"at": Vector2(1415, 942), "core": Vector2(91, 67), "spill": Vector2(259, 162), "phase": 2.4},
]
const EMBERS := [
	{"at": Vector2(1317, 910), "count": 7, "spread": 17.3, "rise": 91.8, "life": 2.2, "phase": 0.3},
	{"at": Vector2(1415, 935), "count": 7, "spread": 25.9, "rise": 81.0, "life": 2.0, "phase": 1.7},
	{"at": Vector2(1339, 753), "count": 5, "spread": 8.6, "rise": 118.8, "life": 2.8, "phase": 3.1},
]
const CORE_COLOR := Color(1.0, 0.5, 0.12)
const SPILL_COLOR := Color(1.0, 0.36, 0.08)
const CORE_STRENGTH := 0.75
const SPILL_STRENGTH := 0.3
const EMBER_COLOR := Color(1.0, 0.62, 0.2)
const EMBER_SIZE := 1.7
const EMBER_SWAY := 7.0

var _map: Control
var _glow: GradientTexture2D
var _t := 0.0


func _init(map: Control) -> void:
	_map = map
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	_glow = GradientTexture2D.new()
	_glow.gradient = fade
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


## How hot a forge is at a moment, from 0 to 1. The sines never line up, so it never quite repeats.
static func heat(phase: float, t: float) -> float:
	return clampf(0.72 + 0.18 * sin(t * 2.3 + phase) + 0.1 * sin(t * 5.9 + phase * 2.1) + 0.05 * sin(t * 13.7 + phase * 3.3), 0.0, 1.0)


## A number from 0 to 1 that looks random but always comes out the same for the same input.
static func scatter(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)


## One ember at a moment: how far it is from its source, in map coordinates, and how bright it is.
static func ember(source: Dictionary, i: int, t: float) -> Dictionary:
	var run: float = t / source["life"] + float(i) / source["count"] + source["phase"]
	var round_of := floorf(run)
	var age := run - round_of
	var key := i * 13.7 + round_of * 7.3
	var across: float = (scatter(key) * 2.0 - 1.0) * source["spread"] + sin(age * 6.0 + i) * EMBER_SWAY * age
	var up: float = source["rise"] * age * (0.6 + 0.4 * scatter(key + 3.1))
	return {"offset": Vector2(across, -up), "bright": sin(age * PI)}


func _draw() -> void:
	var map_scale: float = _map.view_point(Vector2.ONE).x - _map.view_point(Vector2.ZERO).x
	for f in FORGES:
		var hot := heat(f["phase"], _t)
		_glow_at(f["at"], f["spill"] * map_scale, Color(SPILL_COLOR, SPILL_STRENGTH * (0.6 + 0.4 * hot)))
		_glow_at(f["at"], f["core"] * map_scale, Color(CORE_COLOR, CORE_STRENGTH * hot))
	for source in EMBERS:
		for i in source["count"]:
			var e := ember(source, i, _t)
			var at: Vector2 = _map.view_point(source["at"] + e["offset"])
			draw_circle(at, EMBER_SIZE * map_scale * (0.5 + 0.5 * e["bright"]), Color(EMBER_COLOR, e["bright"]), true, -1.0, true)


func _glow_at(at: Vector2, box: Vector2, color: Color) -> void:
	draw_texture_rect(_glow, Rect2(_map.view_point(at) - box * 0.5, box), false, color)

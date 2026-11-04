class_name MapSmoke
extends Control
## Smoke or mist on the town map, made of puffs that spread and fade as they travel. Like the forge
## glow, it never touches the game's random numbers.

## From the Vefects pack, which its licence keeps out of the public repository, so it may be missing.
## Without it the map simply has no smoke.
const TEXTURE := "res://Vefects/Free Fire VFX/Textures/T_VFX_Smoke_01.tga"

## Places are in the map's SPOTS coordinates. travel is where a puff ends up, bend how far it is blown
## off course by the end, and ease above 1 keeps it near its source for longer. thick multiplies the
## texture's brightness, squash flattens the puffs, and fade_in is a share of a puff's life.
const CHIMNEY := {"base": Vector2(1315, 746), "puffs": 28, "life": 9.0, "travel": Vector2(0, -330), "ease": 1.15, "bend": Vector2(-110, 0),
	"wander": Vector2(6, 34), "sway": 14.0, "sway_speed": 0.7, "size": Vector2(44, 210), "shade": Color(0.07, 0.065, 0.065), "lit": Color(0.22, 0.21, 0.2),
	"strength": 0.9, "thick": 1.55, "fade_in": 0.015, "fade_out": 1.1, "spin": 0.12, "squash": 1.0}
## Low white wisps, flowing out of the Maze's door, down its steps and along the path.
const MAZE_MIST := {"base": Vector2(1746, 229), "puffs": 18, "life": 32.0, "travel": Vector2(-78, 59), "ease": 1.0, "bend": Vector2(-10, 8),
	"wander": Vector2(6, 33), "sway": 12.0, "sway_speed": 0.35, "size": Vector2(45, 195), "shade": Color(0.72, 0.75, 0.78), "lit": Color(1, 1, 1),
	"strength": 0.3, "thick": 1.2, "fade_in": 0.12, "fade_out": 1.2, "spin": 0.025, "squash": 0.45}
## The pack's texture has no transparency: its brightness says how thick the smoke is.
const SHADER := """
shader_type canvas_item;
uniform vec3 shade;
uniform vec3 lit;
uniform float thick_by;
varying float strength;
void vertex() { strength = COLOR.a; }
void fragment() {
	float thick = clamp(texture(TEXTURE, UV).r * thick_by, 0.0, 1.0);
	COLOR = vec4(mix(shade, lit, thick), thick * strength);
}
"""

var _map: Control
var _kind: Dictionary
var _puff: Texture2D
var _t := 0.0


func _init(map: Control, kind: Dictionary) -> void:
	_map = map
	_kind = kind
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not ResourceLoader.exists(TEXTURE):
		set_process(false)
		return
	_puff = load(TEXTURE)
	var look := ShaderMaterial.new()
	look.shader = Shader.new()
	look.shader.code = SHADER
	look.set_shader_parameter("shade", kind["shade"])
	look.set_shader_parameter("lit", kind["lit"])
	look.set_shader_parameter("thick_by", kind["thick"])
	material = look


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


## One puff at a moment: its offset from the source in map coordinates, its width, its turn and
## its strength.
static func puff(kind: Dictionary, i: int, t: float) -> Dictionary:
	var run: float = t / kind["life"] + float(i) / kind["puffs"]
	var round_of := floorf(run)
	var age := run - round_of
	var key := i * 9.1 + round_of * 5.7
	var along: float = pow(age, kind["ease"])
	var across: Vector2 = Vector2(kind["travel"]).normalized().orthogonal()
	var wander: float = (ForgeGlow.scatter(key) * 2.0 - 1.0) * (kind["wander"].x + kind["wander"].y * age) + sin(t * kind["sway_speed"] + i) * kind["sway"] * age
	var offset: Vector2 = kind["travel"] * along + kind["bend"] * age * age + across * wander
	var width: float = lerpf(kind["size"].x, kind["size"].y, along) * (0.8 + 0.4 * ForgeGlow.scatter(key + 2.3))
	var spin: float = ForgeGlow.scatter(key + 5.9) * TAU + (ForgeGlow.scatter(key + 8.1) - 0.5) * 2.0 * kind["spin"] * age * kind["life"]
	var strength: float = minf(age / kind["fade_in"], 1.0) * pow(1.0 - age, kind["fade_out"]) * kind["strength"]
	return {"offset": offset, "width": width, "spin": spin, "strength": strength}


func _draw() -> void:
	if _puff == null:
		return
	var map_scale: float = _map.view_point(Vector2.ONE).x - _map.view_point(Vector2.ZERO).x
	var squash: float = _kind["squash"]
	for i in _kind["puffs"]:
		var p := puff(_kind, i, _t)
		var box: Vector2 = Vector2.ONE * float(p["width"]) * map_scale
		var turn: float = p["spin"]
		# Turned first and flattened after, so a flat puff still lies along the ground.
		draw_set_transform_matrix(Transform2D(Vector2(cos(turn), sin(turn) * squash), Vector2(-sin(turn), cos(turn) * squash), _map.view_point(_kind["base"] + p["offset"])))
		draw_texture_rect(_puff, Rect2(box * -0.5, box), false, Color(1, 1, 1, p["strength"]))
	draw_set_transform_matrix(Transform2D.IDENTITY)

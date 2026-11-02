class_name MazeWorld
extends SubViewport
## The Maze in real 3D: each level becomes a mesh of the painted walls, doors, floors and ceilings,
## lit only by the party's torch. MazeView draws the result into the picture window.

const WALL_ART: Array[Texture2D] = [
	preload("res://assets/images/maze/wall_1.webp"),
	preload("res://assets/images/maze/wall_2.webp"),
	preload("res://assets/images/maze/wall_3.webp"),
	preload("res://assets/images/maze/wall_4.webp"),
]
## Landmarks: too striking to repeat often, so they only turn up on one wall in RARE_EVERY.
const RARE_WALL_ART: Array[Texture2D] = [
	preload("res://assets/images/maze/wall_rubble.webp"),
	preload("res://assets/images/maze/wall_pentagram.webp"),
]
const RARE_EVERY := 12
const DOOR_ART: Array[Texture2D] = [preload("res://assets/images/maze/door_1.webp")]
const OPEN_DOOR_ART: Array[Texture2D] = [preload("res://assets/images/maze/door_open_1.webp")]
const FLOOR_ART: Array[Texture2D] = [preload("res://assets/images/maze/floor_1.webp")]
const CEILING_ART: Array[Texture2D] = [preload("res://assets/images/maze/ceiling_1.webp"), preload("res://assets/images/maze/ceiling_2.webp")]

const CELL := 2.0  # the width of a square
const HEIGHT := 1.5  # floor to ceiling, which keeps the 4:3 shape of the picture window
const THICKNESS := 0.2  # of a wall
const PILLAR_U := 0.095  # how much of the wall art's left side is its stone pillar
const DIRS: Array[Vector3] = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]  # N E S W
const CAMERA_BACK := 0.45  # squares behind the middle of the square, so doors beside the party show
const CAMERA_FOV := 95.0  # across the window, wide enough to see those doors
const CEILING_TINT := Color(0.75, 0.75, 0.75)  # the ceiling art is painted bright

const TORCH_COLOR := Color(1.0, 0.86, 0.68)
const TORCH_OFFSET := Vector3(0.35, 0.05, -0.15)  # held to the right, so the piers throw shadows
const TORCH_ENERGY := 1.25
const TORCH_REACH := 8.0
const SPELL_REACH := 13.0  # MILWA and LOMILWA light the Maze farther
const SPELL_ENERGY := 1.7
const FLICKER := 0.06
const AMBIENT := Color(0.05, 0.045, 0.05)
const STAIR_MARK := Color("e3a33f")

var _camera: Camera3D
var _torch: OmniLight3D
var _level: MeshInstance3D
var _key := ""
var _t := 0.0
var _energy := TORCH_ENERGY


func _ready() -> void:
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	_level = MeshInstance3D.new()
	add_child(_level)
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = CAMERA_FOV
	_camera.near = 0.05
	add_child(_camera)
	_torch = OmniLight3D.new()
	_torch.light_color = TORCH_COLOR
	_torch.shadow_enabled = true
	_torch.position = TORCH_OFFSET
	_camera.add_child(_torch)
	set_process(false)


## Only renders while the Maze is on show.
func set_active(on: bool) -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	set_process(on)


func _process(delta: float) -> void:
	_t += delta
	_torch.light_energy = _energy * (1.0 + FLICKER * (sin(_t * 7.3) + sin(_t * 13.1 + 1.7)) * 0.5)


## Puts the camera where the party is, rebuilding the level when it or what can be seen changes.
func sync_to_party() -> void:
	var lit: bool = Game.light > 0
	var key := "%d:%s:%d" % [Game.pos["z"], lit, Game.opened.size()]
	if key != _key:
		_key = key
		_level.mesh = _build(Game.level())
	var p: Dictionary = Game.pos
	_camera.position = camera_place(Vector2i(p["x"], p["y"]), p["d"])
	_camera.rotation.y = camera_yaw(p["d"])
	_torch.omni_range = SPELL_REACH if lit else TORCH_REACH
	_energy = SPELL_ENERGY if lit else TORCH_ENERGY
	_torch.light_energy = _energy


static func cell_centre(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.0, -(c.y + 0.5) * CELL)


static func camera_place(c: Vector2i, dir: int) -> Vector3:
	return cell_centre(c) - DIRS[dir] * CAMERA_BACK * CELL + Vector3.UP * HEIGHT / 2.0


static func camera_yaw(dir: int) -> float:
	return -dir * PI / 2.0


## A secret door looks like plain wall until the light reveals it.
static func seen_wall(code: int, lit: bool) -> int:
	return 1 if code == 3 and not lit else code


## Varied by square and side, but always the same piece for the same wall.
func _piece(art: Array[Texture2D], z: int, c: Vector2i, side: int) -> Texture2D:
	return art[posmod(hash([z, c.x, c.y, side]), art.size())]


func _wall_piece(z: int, c: Vector2i, side: int) -> Texture2D:
	if posmod(hash([z, c.x, c.y, side, "rare"]), RARE_EVERY) == 0:
		return RARE_WALL_ART[posmod(hash([z, c.x, c.y, side, "which"]), RARE_WALL_ART.size())]
	return _piece(WALL_ART, z, c, side)


func _build(lv: MazeLevel) -> ArrayMesh:
	var lit: bool = Game.light > 0
	var parts := {}
	for y in MazeLevel.N:
		for x in MazeLevel.N:
			if not lv.flag(x, y, "dark"):
				_add_square(parts, lv, Vector2i(x, y), lit)
	var mesh := ArrayMesh.new()
	for part in parts:
		parts[part].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(part))
	return mesh


func _add_square(parts: Dictionary, lv: MazeLevel, c: Vector2i, lit: bool) -> void:
	var mid := cell_centre(c)
	var h := CELL / 2.0
	var east := DIRS[1] * h
	var north := DIRS[0] * h
	var up := Vector3.UP * HEIGHT
	_quad(_part(parts, _piece(FLOOR_ART, lv.z, c, 4)), [mid - east + north, mid + east + north, mid + east - north, mid - east - north], Vector3.UP, Rect2(0, 0, 1, 1))
	_quad(_part(parts, _piece(CEILING_ART, lv.z, c, 5)), [mid - east - north + up, mid + east - north + up, mid + east + north + up, mid - east + north + up], Vector3.DOWN, Rect2(0, 0, 1, 1))
	if lv.flag(c.x, c.y, "up") or lv.flag(c.x, c.y, "down"):
		for i in [-1, 0, 1]:
			var z_off: Vector3 = north * (i * 0.5)
			var lift: Vector3 = Vector3.UP * 0.01
			_quad(_part(parts, "stairs"), [mid - east * 0.7 + z_off + north * 0.04 + lift, mid + east * 0.7 + z_off + north * 0.04 + lift, mid + east * 0.7 + z_off - north * 0.04 + lift, mid - east * 0.7 + z_off - north * 0.04 + lift], Vector3.UP, Rect2(0, 0, 1, 1))
	for d in 4:
		var is_open := Game.door_open(lv.z, c.x, c.y, d)
		var code := 2 if is_open else seen_wall(lv.wall(c.x, c.y, d), lit)
		var n := DIRS[d]
		var r := DIRS[(d + 1) % 4]
		if code == 0:
			var nb := c + Vector2i(MazeLevel.DX[d], MazeLevel.DY[d])
			if lv.in_bounds(nb.x, nb.y) and lv.flag(nb.x, nb.y, "dark"):
				_quad(_part(parts, "black"), [mid + n * h - r * h + up, mid + n * h + r * h + up, mid + n * h + r * h, mid + n * h - r * h], -n, Rect2(0, 0, 1, 1))
			continue
		var tex := _wall_piece(lv.z, c, d)
		if code >= 2:
			tex = _piece(OPEN_DOOR_ART if is_open else DOOR_ART, lv.z, c, d)
		var inset := n * (h - THICKNESS / 2.0)
		_quad(_part(parts, tex), [mid + inset - r * h + up, mid + inset + r * h + up, mid + inset + r * h, mid + inset - r * h], -n, Rect2(0, 0, 1, 1))
		# The ends of a wall, seen from a side passage.
		for side in [-1, 1]:
			var s: int = side
			var beside := (d + (1 if s > 0 else 3)) % 4
			if seen_wall(lv.wall(c.x, c.y, beside), lit) != 0:
				continue
			var nb2 := c + Vector2i(MazeLevel.DX[beside], MazeLevel.DY[beside])
			if not lv.in_bounds(nb2.x, nb2.y) or seen_wall(lv.wall(nb2.x, nb2.y, d), lit) != 0:
				continue
			var end := mid + r * h * s
			var a := end + inset
			var b := end + n * h
			var corners := [a + up, b + up, b, a] if s > 0 else [b + up, a + up, a, b]
			_quad(_part(parts, _wall_piece(lv.z, c, d)), corners, r * s, Rect2(0, 0, PILLAR_U, 1))


func _part(parts: Dictionary, key: Variant) -> SurfaceTool:
	if not parts.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		parts[key] = st
	return parts[key]


## Corners run top left, top right, bottom right, bottom left, clockwise as seen from the front.
func _quad(st: SurfaceTool, c: Array, normal: Vector3, uv: Rect2) -> void:
	var uvs := [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(c[i])


func _material(part: Variant) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic_specular = 0.0
	m.roughness = 1.0
	if part is Texture2D:
		m.albedo_texture = part
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if CEILING_ART.has(part):
			m.albedo_color = CEILING_TINT
	elif part == "black":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color.BLACK
	else:
		m.albedo_color = STAIR_MARK
	return m

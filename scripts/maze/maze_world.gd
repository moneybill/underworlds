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
## Landmarks: too striking to repeat often, so they only turn up on one wall or floor in RARE_EVERY.
const RARE_WALL_ART: Array[Texture2D] = [
	preload("res://assets/images/maze/wall_rubble.webp"),
	preload("res://assets/images/maze/wall_pentagram.webp"),
]
const RARE_EVERY := 12
const DOOR_ART: Array[Texture2D] = [preload("res://assets/images/maze/door_1.webp")]
const OPEN_DOOR_ART: Array[Texture2D] = [preload("res://assets/images/maze/door_open_1.webp")]
const FLOOR_ART: Array[Texture2D] = [preload("res://assets/images/maze/floor_1.webp"), preload("res://assets/images/maze/floor_2.webp")]
const RARE_FLOOR_ART: Array[Texture2D] = [
	preload("res://assets/images/maze/floor_crown.webp"),
	preload("res://assets/images/maze/floor_lion.webp"),
]
const LADDER_UP_ART: Texture2D = preload("res://assets/images/maze/wall_ladder_up.webp")
const LADDER_HATCH_ART: Texture2D = preload("res://assets/images/maze/ceiling_ladder_hatch.webp")  # its hatch is on its right edge
const LADDER_DOWN_ART: Texture2D = preload("res://assets/images/maze/floor_ladder_down.webp")
const CEILING_ART: Array[Texture2D] = [
	preload("res://assets/images/maze/ceiling_1.webp"),
	preload("res://assets/images/maze/ceiling_2.webp"),
	preload("res://assets/images/maze/ceiling_3.webp"),
	preload("res://assets/images/maze/ceiling_4.webp"),
	preload("res://assets/images/maze/ceiling_5.webp"),
	preload("res://assets/images/maze/ceiling_6.webp"),
	preload("res://assets/images/maze/ceiling_7.webp"),
	preload("res://assets/images/maze/ceiling_8.webp"),
	preload("res://assets/images/maze/ceiling_9.webp"),
]

const BRAZIER_SCENE: PackedScene = preload("res://assets/models/fantasy_props/Cauldron.gltf")
const TORCH_SCENE: PackedScene = preload("res://assets/models/fantasy_props/Torch_Metal.gltf")
const WEB_FULL: Array[Texture2D] = [
	preload("res://assets/images/maze/web_full.png"),
	preload("res://assets/images/maze/web_full_2.png"),
	preload("res://assets/images/maze/web_full_3.png"),
]
const WEB_LEFT: Texture2D = preload("res://assets/images/maze/web_left.png")  # its corner is at the top left
const WEB_RIGHT: Texture2D = preload("res://assets/images/maze/web_right.png")  # its corner is at the top right

const CELL := 2.0  # the width of a square
const HEIGHT := 1.5  # floor to ceiling, which keeps the 4:3 shape of the picture window
const THICKNESS := 0.2  # of a wall
const PILLAR_U := 0.095  # how much of the wall art's left side is its stone pillar
const DIRS: Array[Vector3] = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]  # N E S W
const GLIDE_SECONDS := 0.25  # a step or a quarter turn
const TURN_AROUND_SECONDS := 0.4
const JUMP_DISTANCE := CELL * 1.5  # further than a step: a teleport or the like, which doesn't glide
const TORCH_CLEAR := 0.45  # the camera stands near a wall, so anything on that wall this close is right behind it
const CHEST_CLEAR := 0.65  # and is hidden, or the camera would look out through it
const CAMERA_BACK := 0.45  # squares behind the middle of the square, so doors beside the party show
const CAMERA_FOV := 95.0  # across the window, wide enough to see those doors
const CEILING_TINT := Color(0.6, 0.6, 0.6)  # the ceiling art is painted bright

# The torchlight is deep orange and dies off fast, so the Maze beyond it goes black, like the camp painting.
const TORCH_COLOR := Color(1.0, 0.68, 0.42)
const TORCH_FALLOFF := 1.6  # the light's attenuation; above 1 it is bright close by and gone sooner
const TORCH_OFFSET := Vector3(0.35, 0.05, -0.15)  # held to the right, so the piers throw shadows
const TORCH_ENERGY := 0.3
const TORCH_REACH := 5.0
const SPELL_REACH := 13.0  # MILWA and LOMILWA light the Maze farther
const SPELL_ENERGY := 0.3
const FLICKER := 0.06
const AMBIENT := Color(0.006, 0.004, 0.003)
const CONTRAST := 1.15
const SATURATION := 1.0


var _camera: Camera3D
var _goal_place := Vector3.ZERO  # where the camera is gliding to
var _goal_yaw := 0.0
var _goal_level := -1
var _from_place := Vector3.ZERO  # and where it set off from
var _from_yaw := 0.0
var _glide_time := 0.0
var _glide_length := 0.0  # 0 when not gliding
var _torch: OmniLight3D
var _level: MeshInstance3D
# The ways up and down glow alike, so they can be found in the dark. Its colour matches the depths of the pit.
const LADDER_LIGHT_COLOR := Color(0.28, 0.8, 1.0)
const LADDER_LIGHT_ENERGY := 0.15
const LADDER_LIGHT_REACH := 4.0
const LADDER_LIGHT_HEIGHT := 0.5

# Cobwebs hang across the passage: the full one from wall to wall, the side ones from one wall and the ceiling.
const WEB_FULL_CHANCE := 16  # percent of squares between two plain walls
const WEB_SIDE_CHANCE := 14  # percent of squares beside a plain wall
const WEB_SIDE_WIDTH := 1.1
const WEB_SHIFT := 0.5  # how far from the middle of the square they can hang, along the passage

# Chests sit against plain walls here and there: the Fantasy Props pack's model, and only scenery for now.
const CHEST_SCENE: PackedScene = preload("res://assets/models/fantasy_props/Chest_Wood.gltf")
const CHEST_CHANCE := 3  # percent of squares
const CHEST_WIDTH := 0.7
const CHEST_DEPTH := 0.42
const CHEST_GAP := 0.03  # from the wall
const CHEST_FOUND_WIDTH := 0.62  # the chest a fight leaves behind, standing in front of the party
const CHEST_FOUND_AHEAD := 1.45  # from the camera, on the floor of the party's square

# Braziers stand around each level, mostly in corners. Only those near the party burn, to keep the frame rate up.
const BRAZIER_FIRE_SCENE := "res://Vefects/Free Fire VFX/Particles/VFX_Fire_01_Small_Simple.tscn"  # may be missing, like the campfire
const BRAZIER_CORNER_CHANCE := 14  # percent of squares with a corner
const BRAZIER_WALL_CHANCE := 2  # percent of squares with only a plain wall
const BRAZIER_SPACING := 3  # squares between braziers, at least
const BRAZIER_HEIGHT := 0.23
const BRAZIER_INSET := 0.42  # from the wall to its middle
const BRAZIER_BOWL := 0.2  # height of the coals, just inside the rim
const BRAZIER_FLAME_SIZE := 0.2
const BRAZIER_FLAME_SPREAD := 0.065  # how far from the middle of the cauldron its flames stand, to fill it
const BRAZIER_FLAMES := 4  # one in the middle, and the rest around it
const BRAZIER_LIGHT_FORWARD := 0.45  # out into the room, so the front of the cauldron is lit
const BRAZIER_NEAR := 6  # squares within which a brazier burns
const BRAZIER_LIGHT_COLOR := Color(1.0, 0.56, 0.3)
const BRAZIER_LIGHT_ENERGY := 0.7
const BRAZIER_LIGHT_REACH := 5.0
const BRAZIER_FLICKER := 0.1
const TORCH_LEVELS := [1]  # the levels with torches on their walls
const TORCH_SPACING := 5  # squares between torches, at least
const TORCH_FLAME_HEIGHT := 1.0  # the top of the torch, above the floor
const TORCH_MODEL_HEIGHT := 0.3
const TORCH_OFF_WALL := 0.09  # the middle of the torch out from the wall, which puts the back of its bracket against it
const TORCH_FLAME_SIZE := 0.19
const TORCH_FLAME_OUT := 0.048  # the model's cup stands out from its middle, away from the bracket
const TORCH_FLAME_DROP := 0.042  # down into the cup
const TORCH_LIGHT_FORWARD := 0.35  # out from the wall, so that it lights the room as well as the wall
const TORCH_NEAR := 5  # squares within which a torch burns
const TORCH_LIGHT_ENERGY := 0.4
const TORCH_LIGHT_REACH := 4.0

var _ladder_floor: MeshInstance3D
var _ladder_light: OmniLight3D
var _ladder_up_light: OmniLight3D
var _chest_holder: Node3D
var _chests: Array = []
var _found_chest: Node3D = null
var _brazier_holder: Node3D
var _braziers: Array = []
var _torches: Array = []
var _brazier_level := -1
var _brazier_cell := Vector2i(-99, -99)
var _key := ""
var _t := 0.0
var _energy := TORCH_ENERGY


func _ready() -> void:
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	audio_listener_enable_3d = true  # the braziers crackle
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.glow_enabled = true  # only the fire is bright enough to glow
	env.adjustment_enabled = true
	env.adjustment_contrast = CONTRAST
	env.adjustment_saturation = SATURATION
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	_level = MeshInstance3D.new()
	add_child(_level)
	_brazier_holder = Node3D.new()
	add_child(_brazier_holder)
	_chest_holder = Node3D.new()
	add_child(_chest_holder)
	_ladder_floor = MeshInstance3D.new()
	_ladder_floor.mesh = _ladder_mesh()
	add_child(_ladder_floor)
	_ladder_light = _new_ladder_light()
	_ladder_floor.add_child(_ladder_light)
	_ladder_up_light = _new_ladder_light()
	add_child(_ladder_up_light)
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = CAMERA_FOV
	_camera.near = 0.05
	add_child(_camera)
	_torch = OmniLight3D.new()
	_torch.light_color = TORCH_COLOR
	_torch.omni_attenuation = TORCH_FALLOFF
	_torch.shadow_enabled = true
	_torch.position = TORCH_OFFSET
	_camera.add_child(_torch)
	set_process(false)


## Only renders while the Maze is on show.
func set_active(on: bool) -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	set_process(on)
	if not on:
		finish_glide()


func _process(delta: float) -> void:
	_t += delta
	_glide(delta)
	_torch.light_energy = _energy * (1.0 + FLICKER * (sin(_t * 7.3) + sin(_t * 13.1 + 1.7)) * 0.5)
	for b in _braziers + _torches:
		if b["fire_on"]:
			b["light"].light_energy = b["energy"] * (1.0 + BRAZIER_FLICKER * (sin(_t * 5.7 + b["phase"]) + sin(_t * 9.3 + b["phase"] * 2.0)) * 0.5)


## Eases to a stop, so that pressing on before it stops keeps the party moving.
func _glide(delta: float) -> void:
	if _glide_length <= 0.0:
		return
	_glide_time += delta
	var t := minf(_glide_time / _glide_length, 1.0)
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	_show_camera(_from_place.lerp(_goal_place, eased), lerp_angle(_from_yaw, _goal_yaw, eased))
	if t >= 1.0:
		_glide_length = 0.0


func finish_glide() -> void:
	_glide_length = 0.0
	_show_camera(_goal_place, _goal_yaw)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


## The ladder tile keeps facing the camera, so that it reads upright all through a turn.
func _show_camera(place: Vector3, yaw: float) -> void:
	_camera.position = place
	_camera.rotation.y = yaw
	_ladder_floor.rotation.y = yaw
	for t in _torches:
		var clear: bool = _flat_distance(t["stand"].position, place) >= TORCH_CLEAR
		t["stand"].get_child(0).visible = clear
		if t["fire"] != null:
			t["fire"].visible = clear
	for chest in _chests:
		chest.visible = _flat_distance(chest.position, place) >= CHEST_CLEAR


## Puts the camera where the party is, rebuilding the level when it or what can be seen changes.
func sync_to_party() -> void:
	var lit: bool = Game.light > 0
	var key := "%d:%s:%d" % [Game.pos["z"], lit, Game.opened.size()]
	if key != _key:
		_key = key
		_level.mesh = _build(Game.level())
	var p: Dictionary = Game.pos
	if p["z"] != _brazier_level:
		_brazier_level = p["z"]
		_build_braziers(Game.level())
		_build_chests(Game.level())
		_build_torches(Game.level())
		_place_ladder(Game.level())
	_update_braziers(Vector2i(p["x"], p["y"]))
	_aim_camera(camera_place(Vector2i(p["x"], p["y"]), p["d"]), camera_yaw(p["d"]), p["z"])
	_torch.omni_range = SPELL_REACH if lit else TORCH_REACH
	_energy = SPELL_ENERGY if lit else TORCH_ENERGY
	_torch.light_energy = _energy
	if _found_chest != null:
		_place_found_chest()


## Glides to a new place on this level, or jumps there if it isn't a step or a turn away.
func _aim_camera(place: Vector3, yaw: float, level: int) -> void:
	if place.is_equal_approx(_goal_place) and is_equal_approx(yaw, _goal_yaw) and level == _goal_level:
		return
	var jump := level != _goal_level or place.distance_to(_goal_place) > JUMP_DISTANCE or not is_processing()
	var turn: float = absf(angle_difference(_goal_yaw, yaw))
	_goal_place = place
	_goal_yaw = yaw
	_goal_level = level
	if jump:
		finish_glide()
		return
	_from_place = _camera.position
	_from_yaw = _camera.rotation.y
	_glide_time = 0.0
	_glide_length = TURN_AROUND_SECONDS if turn > PI * 0.75 else GLIDE_SECONDS


## The ladder tile is apart from the level's mesh, as it turns to read upright whichever way the party faces.
func _ladder_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := CELL / 2.0
	var east := DIRS[1] * h
	var north := DIRS[0] * h
	_quad(st, [north - east, north + east, east - north, -east - north], Vector3.UP, Rect2(0, 0, 1, 1))
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, _material(LADDER_DOWN_ART))
	return mesh


## Stands the tile and its light on the level's way down, or hides them if it has none.
func _place_ladder(lv: MazeLevel) -> void:
	_ladder_floor.visible = lv.flag(lv.down.x, lv.down.y, "down") == true and not lv.flag(lv.down.x, lv.down.y, "dark")
	_ladder_floor.position = cell_centre(lv.down)
	_ladder_up_light.visible = false
	for y in MazeLevel.N:
		for x in MazeLevel.N:
			if ladder_up_side(lv, Vector2i(x, y)) >= 0:
				_ladder_up_light.visible = true
				_ladder_up_light.position = cell_centre(Vector2i(x, y)) + Vector3.UP * LADDER_LIGHT_HEIGHT


func _new_ladder_light() -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = LADDER_LIGHT_COLOR
	light.light_energy = LADDER_LIGHT_ENERGY
	light.omni_range = LADDER_LIGHT_REACH
	light.shadow_enabled = true  # or it would shine through the walls
	light.position = Vector3.UP * LADDER_LIGHT_HEIGHT
	return light


static func cell_centre(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0.0, -(c.y + 0.5) * CELL)


static func camera_place(c: Vector2i, dir: int) -> Vector3:
	return cell_centre(c) - DIRS[dir] * CAMERA_BACK * CELL + Vector3.UP * HEIGHT / 2.0


static func camera_yaw(dir: int) -> float:
	return -dir * PI / 2.0


## Where a level's braziers stand: always the same places, against plain walls only, so never in front of a door.
static func brazier_spots(lv: MazeLevel) -> Array:
	var spots := []
	var back: float = CELL / 2.0 - THICKNESS / 2.0 - BRAZIER_INSET
	for y in MazeLevel.N:
		for x in MazeLevel.N:
			if lv.flag(x, y, "dark") or lv.flag(x, y, "up") or lv.flag(x, y, "down"):
				continue
			var roll := posmod(hash([lv.z, x, y, "brazier"]), 100)
			var first := posmod(hash([lv.z, x, y, "brazier side"]), 4)
			var offset := Vector3.ZERO
			var corner := false
			if roll < BRAZIER_CORNER_CHANCE:
				for i in 4:
					var d := (first + i) % 4
					if lv.wall(x, y, d) == 1 and lv.wall(x, y, (d + 1) % 4) == 1:
						offset = (DIRS[d] + DIRS[(d + 1) % 4]) * back
						corner = true
						break
			if not corner and roll < BRAZIER_WALL_CHANCE:
				for i in 4:
					var d := (first + i) % 4
					if lv.wall(x, y, d) == 1:
						offset = DIRS[d] * back
						break
			if offset == Vector3.ZERO:
				continue
			var c := Vector2i(x, y)
			var crowded := false
			for s in spots:
				if absi(s["c"].x - x) + absi(s["c"].y - y) < BRAZIER_SPACING:
					crowded = true
					break
			if not crowded:
				spots.append({"c": c, "pos": cell_centre(c) + offset, "corner": corner})
	return spots


## Where a level's wall torches hang: always the same places, spread out, each on a plain wall of a square
## with nothing else in it. The order is scrambled so that they spread evenly, not along one edge.
static func torch_spots(lv: MazeLevel) -> Array:
	var spots := []
	if not TORCH_LEVELS.has(lv.z):
		return spots
	var taken := {}
	for spot in brazier_spots(lv) + chest_spots(lv):
		taken[spot["c"]] = true
	var squares := []
	for y in MazeLevel.N:
		for x in MazeLevel.N:
			squares.append(Vector2i(x, y))
	squares.sort_custom(func(a, b): return posmod(hash([lv.z, a, "torch"]), 100000) < posmod(hash([lv.z, b, "torch"]), 100000))
	for c: Vector2i in squares:
		if taken.has(c) or lv.flag(c.x, c.y, "dark") or lv.flag(c.x, c.y, "up") or lv.flag(c.x, c.y, "down"):
			continue
		if spots.any(func(s): return absi(s["c"].x - c.x) + absi(s["c"].y - c.y) < TORCH_SPACING):
			continue
		var first := posmod(hash([lv.z, c, "torch side"]), 4)
		for i in 4:
			var d := (first + i) % 4
			if lv.wall(c.x, c.y, d) == 1:
				spots.append({"c": c, "side": d, "pos": cell_centre(c) + DIRS[d] * (CELL / 2.0 - THICKNESS / 2.0)})
				break
	return spots


## Where a level's chests sit: always the same places, each against a plain wall, clear of braziers and ladders.
static func chest_spots(lv: MazeLevel) -> Array:
	var taken := {}
	for spot in brazier_spots(lv):
		taken[spot["c"]] = true
	var spots := []
	var back: float = CELL / 2.0 - THICKNESS / 2.0 - CHEST_DEPTH / 2.0 - CHEST_GAP
	for y in MazeLevel.N:
		for x in MazeLevel.N:
			var c := Vector2i(x, y)
			if taken.has(c) or lv.flag(x, y, "dark") or lv.flag(x, y, "up") or lv.flag(x, y, "down"):
				continue
			if posmod(hash([lv.z, x, y, "chest"]), 100) >= CHEST_CHANCE:
				continue
			var first := posmod(hash([lv.z, x, y, "chest side"]), 4)
			for i in 4:
				var d := (first + i) % 4
				if lv.wall(x, y, d) == 1:
					spots.append({"c": c, "side": d, "pos": cell_centre(c) + DIRS[d] * back})
					break
	return spots


## The front of the chest faces away from its wall.
static func chest_yaw(side: int) -> float:
	var front := -DIRS[side]
	return atan2(front.x, front.z)


func _build_chests(lv: MazeLevel) -> void:
	for child in _chest_holder.get_children():
		child.free()
	_chests = []
	for spot in chest_spots(lv):
		var chest := _chest_model(CHEST_WIDTH)
		chest.position = spot["pos"]
		chest.rotation.y = chest_yaw(spot["side"])
		_chest_holder.add_child(chest)
		_chests.append(chest)


## The model at this width, its front toward +Z, standing on the holder's origin.
func _chest_model(width: float) -> Node3D:
	var holder := Node3D.new()
	var model: Node3D = CHEST_SCENE.instantiate()
	var box := _model_box(model)
	var fit: float = width / box.size.x
	model.scale = Vector3.ONE * fit
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * fit
	holder.add_child(model)
	return holder


## The chest a fight leaves behind, in front of the party for as long as the chest screens are up.
func set_found_chest(on: bool) -> void:
	if on and _found_chest == null:
		_found_chest = _chest_model(CHEST_FOUND_WIDTH)
		add_child(_found_chest)
		_place_found_chest()
	elif not on and _found_chest != null:
		_found_chest.queue_free()
		_found_chest = null


func has_found_chest() -> bool:
	return _found_chest != null


func _place_found_chest() -> void:
	var p: Dictionary = Game.pos
	var at := camera_place(Vector2i(p["x"], p["y"]), p["d"]) + DIRS[p["d"]] * CHEST_FOUND_AHEAD
	_found_chest.position = Vector3(at.x, 0.0, at.z)
	_found_chest.rotation.y = chest_yaw(p["d"])


func _build_braziers(lv: MazeLevel) -> void:
	for child in _brazier_holder.get_children():
		child.free()
	_braziers = []
	_torches = []  # they stand in the same holder
	for spot in brazier_spots(lv):
		var stand := Node3D.new()
		stand.position = spot["pos"]
		_brazier_holder.add_child(stand)
		stand.add_child(_cauldron_model())
		var light := OmniLight3D.new()
		light.light_color = BRAZIER_LIGHT_COLOR
		light.light_energy = BRAZIER_LIGHT_ENERGY
		light.omni_range = BRAZIER_LIGHT_REACH
		light.shadow_enabled = true  # or it would shine through the walls
		var into_room: Vector3 = (cell_centre(spot["c"]) - spot["pos"]).normalized()
		light.position = Vector3.UP * (BRAZIER_BOWL + 0.25) + into_room * BRAZIER_LIGHT_FORWARD
		light.visible = false
		stand.add_child(light)
		_braziers.append({"c": spot["c"], "stand": stand, "light": light, "fire": null, "fire_on": false, "near": BRAZIER_NEAR, "energy": BRAZIER_LIGHT_ENERGY, "flames": _brazier_flames, "phase": float(posmod(hash(spot["c"]), 628)) / 100.0})
	_brazier_cell = Vector2i(-99, -99)


## The model at its height in the Maze, with the top of it at the holder's origin.
func _torch_model() -> Node3D:
	var holder := Node3D.new()
	var model: Node3D = TORCH_SCENE.instantiate()
	var box := _model_box(model)
	var fit: float = TORCH_MODEL_HEIGHT / box.size.y
	model.scale = Vector3.ONE * fit
	model.position = -Vector3(box.get_center().x, box.end.y, box.get_center().z) * fit
	holder.add_child(model)
	for piece in [model] + model.find_children("*", "MeshInstance3D", true, false):
		if piece is MeshInstance3D:
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # its own light is right beside it
	return holder


## The model at its height in the Maze, standing on the holder's origin.
func _cauldron_model() -> Node3D:
	var holder := Node3D.new()
	var model: Node3D = BRAZIER_SCENE.instantiate()
	var box := _model_box(model)
	var fit: float = BRAZIER_HEIGHT / box.size.y
	model.scale = Vector3.ONE * fit
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * fit
	holder.add_child(model)
	return holder


func _model_box(model: Node3D) -> AABB:
	var box := AABB()
	for piece in [model] + model.find_children("*", "MeshInstance3D", true, false):
		if piece is MeshInstance3D:
			box = box.merge(piece.get_aabb())
	return box


func _build_torches(lv: MazeLevel) -> void:
	for t in _torches:
		t["stand"].free()
	_torches = []
	for spot in torch_spots(lv):
		var into_room: Vector3 = -DIRS[spot["side"]]
		var stand := Node3D.new()
		stand.position = spot["pos"]
		_brazier_holder.add_child(stand)
		var torch := _torch_model()
		torch.position = into_room * TORCH_OFF_WALL + Vector3.UP * TORCH_FLAME_HEIGHT
		torch.rotation.y = atan2(into_room.x, into_room.z)
		stand.add_child(torch)
		var light := OmniLight3D.new()
		light.light_color = BRAZIER_LIGHT_COLOR
		light.light_energy = TORCH_LIGHT_ENERGY
		light.omni_range = TORCH_LIGHT_REACH
		light.shadow_enabled = true  # or it would shine through the walls
		light.position = Vector3.UP * TORCH_FLAME_HEIGHT + into_room * TORCH_LIGHT_FORWARD
		light.visible = false
		stand.add_child(light)
		_torches.append({"c": spot["c"], "stand": stand, "light": light, "fire": null, "fire_on": false, "near": TORCH_NEAR, "energy": TORCH_LIGHT_ENERGY,
			"flames": _torch_flames.bind(into_room), "phase": float(posmod(hash(spot["c"]), 628)) / 100.0})
	_brazier_cell = Vector2i(-99, -99)


## Burns the braziers and torches near the party, and lets the rest go out.
func _update_braziers(cell: Vector2i) -> void:
	if cell == _brazier_cell:
		return
	_brazier_cell = cell
	for b in _braziers + _torches:
		var near: bool = maxi(absi(b["c"].x - cell.x), absi(b["c"].y - cell.y)) <= b["near"]
		if near == b["fire_on"]:
			continue
		b["fire_on"] = near
		b["light"].visible = near
		if near:
			b["fire"] = b["flames"].call()
			if b["fire"] != null:
				b["stand"].add_child(b["fire"])
		elif b["fire"] != null:
			b["fire"].queue_free()
			b["fire"] = null


func _torch_flames(into_room: Vector3) -> Node3D:
	var fire := _flames()
	if fire != null:
		fire.scale = Vector3.ONE * TORCH_FLAME_SIZE
		fire.position = Vector3.UP * (TORCH_FLAME_HEIGHT - TORCH_FLAME_DROP) + into_room * (TORCH_OFF_WALL + TORCH_FLAME_OUT)
	return fire


## Several flames together, as one small one wouldn't fill the cauldron.
func _brazier_flames() -> Node3D:
	if not ResourceLoader.exists(BRAZIER_FIRE_SCENE):
		return null
	var fires := Node3D.new()
	fires.position = Vector3.UP * BRAZIER_BOWL
	for i in BRAZIER_FLAMES:
		var fire := _flames()
		fire.scale = Vector3.ONE * BRAZIER_FLAME_SIZE
		if i > 0:
			var turn := TAU * i / (BRAZIER_FLAMES - 1)
			fire.position = Vector3(cos(turn), 0.0, sin(turn)) * BRAZIER_FLAME_SPREAD
		fires.add_child(fire)
	return fires


## Just the flames: each fire has its own light, and a whole level of crackling would be too much.
func _flames() -> Node3D:
	if not ResourceLoader.exists(BRAZIER_FIRE_SCENE):
		return null
	var fire: Node3D = (load(BRAZIER_FIRE_SCENE) as PackedScene).instantiate()
	for part in fire.get_children():
		if part is AudioStreamPlayer3D or "intensity_multiplier" in part or "istortion" in String(part.name):
			part.free()
	return fire


## A secret door looks like plain wall until the light reveals it.
static func seen_wall(code: int, lit: bool) -> int:
	return 1 if code == 3 and not lit else code


## Varied by square and side, but always the same piece for the same wall.
func _piece(art: Array[Texture2D], z: int, c: Vector2i, side: int) -> Texture2D:
	return art[posmod(hash([z, c.x, c.y, side]), art.size())]


func _wall_piece(z: int, c: Vector2i, side: int) -> Texture2D:
	return _piece_or_landmark(WALL_ART, RARE_WALL_ART, z, c, side)


func _floor_piece(z: int, c: Vector2i) -> Texture2D:
	return _piece_or_landmark(FLOOR_ART, RARE_FLOOR_ART, z, c, 4)


func _piece_or_landmark(art: Array[Texture2D], rare: Array[Texture2D], z: int, c: Vector2i, side: int) -> Texture2D:
	if posmod(hash([z, c.x, c.y, side, "rare"]), RARE_EVERY) == 0:
		return rare[posmod(hash([z, c.x, c.y, side, "which"]), rare.size())]
	return _piece(art, z, c, side)


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
	if not lv.flag(c.x, c.y, "down"):
		_quad(_part(parts, _floor_piece(lv.z, c)), [mid - east + north, mid + east + north, mid + east - north, mid - east - north], Vector3.UP, Rect2(0, 0, 1, 1))
	var ladder_side := ladder_up_side(lv, c)
	if ladder_side >= 0:
		_quad(_part(parts, LADDER_HATCH_ART), ladder_hatch_corners(mid, ladder_side), Vector3.DOWN, Rect2(0, 0, 1, 1))
	else:
		_quad(_part(parts, _piece(CEILING_ART, lv.z, c, 5)), [mid - east - north + up, mid + east - north + up, mid + east + north + up, mid - east + north + up], Vector3.DOWN, Rect2(0, 0, 1, 1))
	for web in web_spots(lv, c):
		_hang(_part(parts, web["art"]), web["top"], web["width"], web["drop"], web["facing"])
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
		elif d == ladder_side:
			tex = LADDER_UP_ART
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


## Which wall of a square holds the ladder up, or -1: the plain wall facing the way in, if it can.
static func ladder_up_side(lv: MazeLevel, c: Vector2i) -> int:
	if not lv.flag(c.x, c.y, "up"):
		return -1
	var any := -1
	for d in 4:
		if lv.wall(c.x, c.y, d) == 1:
			if lv.wall(c.x, c.y, (d + 2) % 4) != 1:
				return d
			any = d
	return any


## The ceiling above a ladder up, turned so the hatch in its art is right above the ladder's wall.
static func ladder_hatch_corners(mid: Vector3, side: int) -> Array:
	var right := DIRS[side] * CELL / 2.0
	var down := DIRS[(side + 3) % 4] * CELL / 2.0
	var up := Vector3.UP * HEIGHT
	return [mid - right - down + up, mid + right - down + up, mid + right + down + up, mid - right + down + up]


## The cobweb of a square, if it has one: the middle of its top edge, its width and the way it faces.
## Always the same for the same square, and only on plain walls, so never across a door.
static func web_spots(lv: MazeLevel, c: Vector2i) -> Array:
	var roll := posmod(hash([lv.z, c.x, c.y, "web"]), 100)
	if roll >= WEB_FULL_CHANCE + WEB_SIDE_CHANCE:
		return []
	var first := posmod(hash([lv.z, c.x, c.y, "web way"]), 4)
	var span: float = CELL - THICKNESS
	var shift: float = (float(posmod(hash([lv.z, c.x, c.y, "web shift"]), 100)) / 50.0 - 1.0) * WEB_SHIFT
	var prefer_left := posmod(hash([lv.z, c.x, c.y, "web side"]), 2) == 0
	for i in 4:
		var facing := DIRS[(first + i) % 4]
		var right := web_right(facing)
		var right_d := DIRS.find(right)
		var right_wall := lv.wall(c.x, c.y, right_d) == 1
		var left_wall := lv.wall(c.x, c.y, (right_d + 2) % 4) == 1
		var top := cell_centre(c) + Vector3.UP * HEIGHT + facing * shift
		if roll < WEB_FULL_CHANCE:
			if left_wall and right_wall:
				var full: Texture2D = WEB_FULL[posmod(hash([lv.z, c.x, c.y, "web art"]), WEB_FULL.size())]
				return [{"art": full, "top": top, "width": span, "facing": facing, "drop": web_drop(full, span)}]
		elif left_wall and (not right_wall or prefer_left):
			var into := right * (WEB_SIDE_WIDTH - span) / 2.0
			return [{"art": WEB_LEFT, "top": top + into, "width": WEB_SIDE_WIDTH, "facing": facing, "drop": web_drop(WEB_LEFT, WEB_SIDE_WIDTH)}]
		elif right_wall:
			var into := -right * (WEB_SIDE_WIDTH - span) / 2.0
			return [{"art": WEB_RIGHT, "top": top + into, "width": WEB_SIDE_WIDTH, "facing": facing, "drop": web_drop(WEB_RIGHT, WEB_SIDE_WIDTH)}]
	return []


## Which way is right, for someone looking at the front of a web.
static func web_right(facing: Vector3) -> Vector3:
	return Vector3(facing.z, 0, -facing.x)


static func web_drop(art: Texture2D, width: float) -> float:
	return width * art.get_height() / art.get_width()


## A sheet hanging from its top edge, with a face on each side so the light falls properly on both.
func _hang(st: SurfaceTool, top: Vector3, width: float, drop: float, facing: Vector3) -> void:
	var right := web_right(facing) * width / 2.0
	var down := Vector3.DOWN * drop
	_quad(st, [top - right, top + right, top + right + down, top - right + down], facing, Rect2(0, 0, 1, 1))
	_quad(st, [top + right, top - right, top - right + down, top + right + down], -facing, Rect2(1, 0, -1, 1))


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
		if WEB_FULL.has(part) or part == WEB_LEFT or part == WEB_RIGHT:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_BACK
		if CEILING_ART.has(part) or part == LADDER_HATCH_ART:
			m.albedo_color = CEILING_TINT
	else:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color.BLACK
	return m

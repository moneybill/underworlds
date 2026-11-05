class_name FireWindow
extends SubViewportContainer
## One of the Vefects pack's 3D fires, burning in a small see-through window over a painting.
## The pack's licence keeps it out of the public repository, so make() returns null when it is missing,
## and the painting's own fire shows on its own.

const BASE_HEIGHT := 0.15  # where the fire stands, as a share of the window's height from its bottom edge

const SIDE_PARTS := ["Flames", "Flames Secondary"]  # all a side flame keeps of the pack's fire

var _base := Vector2.ZERO
var _box := Vector2.ZERO
var _scene := ""
var _speed := 1.0


## view_size is the window's height in the fire's 3D world: the larger, the smaller the fire looks.
## speed is a share of the pack's speed, which looks frantic when the fire is small. With sound, it crackles.
static func make(scene: String, view_size: float, speed: float, sound_db := NAN) -> FireWindow:
	if not ResourceLoader.exists(scene):
		return null
	var window := FireWindow.new()
	window._scene = scene
	window._speed = speed
	window.stretch = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	window.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = view_size
	camera.position = Vector3(0, view_size * (0.5 - BASE_HEIGHT), 5)
	view.add_child(camera)
	var fire: Node3D = (load(scene) as PackedScene).instantiate()
	for part in fire.get_children():
		if part is AudioStreamPlayer3D:
			if not is_nan(sound_db):
				var crackle := AudioStreamPlayer.new()  # the same wherever the window is
				crackle.name = "Crackle"
				crackle.stream = part.stream
				crackle.volume_db = sound_db
				crackle.autoplay = true
				window.add_child(crackle)
			part.free()
		elif "intensity_multiplier" in part:  # the pack's light; there is nothing here for it to light
			part.free()
	for flames in fire.find_children("*", "GPUParticles3D", true, false):
		flames.speed_scale = speed
	fire.name = "Fire"
	view.add_child(fire)
	return window


## The pack's fire, in its own 3D world.
func fire() -> Node3D:
	return get_child(0).get_node("Fire")


## Another, smaller fire beside the first, with only its flames: at offset across, sized as a share of the first.
func add_side_flames(offset: float, share: float) -> void:
	var side: Node3D = (load(_scene) as PackedScene).instantiate()
	for part in side.get_children():
		if not SIDE_PARTS.has(String(part.name)):
			part.free()
	for flames in side.find_children("*", "GPUParticles3D", true, false):
		flames.speed_scale = _speed
	side.position = Vector3(offset, 0, -0.1)  # behind the main fire
	side.scale = Vector3.ONE * share
	get_child(0).add_child(side)


## Sets how fast one of the fire's parts plays, as a multiple of the rest.
func speed_up(part: String, times: float) -> void:
	var node: Node = fire().get_node_or_null(part)
	if node is GPUParticles3D:
		node.speed_scale = _speed * times


## Stands the fire at base, in a window box big, both in its parent's pixels.
func place(base: Vector2, box: Vector2) -> void:
	_base = base
	_box = box
	size = box
	position = base - Vector2(box.x * 0.5, box.y * (1.0 - BASE_HEIGHT))


## Where the fire stands.
func foot() -> Vector2:
	return position + Vector2(size.x * 0.5, size.y * (1.0 - BASE_HEIGHT))

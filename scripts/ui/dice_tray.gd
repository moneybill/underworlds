class_name DiceTray
extends TextureRect
## Dice that tumble over whatever is behind them, drawn in a little 3D world of their own. It stays
## alive between screens, so the dice keep showing their last roll while the menus are redrawn.

const SIZE := Vector2(560, 420)
const RENDER_SCALE := 2  # the window is larger than the layout, so this keeps the dice sharp
const DEFINITION := "res://addons/dice_3d/demo/assets/number_die_definition.tres"
const CAMERA_DISTANCE := 4.6
const CAMERA_FOV := 42.0
const AMBIENT := 0.35

var roller: DiceCinematicRoller3D
var dice: Array[DiceDie3D] = []
var _world: SubViewport
var _done := Callable()


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world = SubViewport.new()
	_world.size = Vector2i(SIZE) * RENDER_SCALE
	_world.own_world_3d = true
	_world.transparent_bg = true
	_world.msaa_3d = Viewport.MSAA_4X
	_world.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(_world)
	var camera := Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -CAMERA_DISTANCE))
	camera.current = true
	_world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.transform = Transform3D(Basis.looking_at(Vector3(0.45, -0.6, 1.0)), Vector3.ZERO)
	light.light_energy = 0.9
	_world.add_child(light)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = AMBIENT
	var surroundings := WorldEnvironment.new()
	surroundings.environment = env
	_world.add_child(surroundings)


func _ready() -> void:
	roller = DiceCinematicRoller3D.new()
	roller.debug_visible = false
	roller.spawn_dice_from_definitions_on_ready = false
	roller.idle_spin_enabled = false
	roller.dice_spacing = 1.3
	roller.spin_clearance = 1.3
	roller.roll_duration = 2.05
	roller.bounce_height = 1.05
	roller.bounce_count = 4.0
	roller.spin_turns = 14.0
	roller.settle_start = 0.76
	roller.all_dice_finished.connect(_on_finished)
	_world.add_child(roller)
	var definition: DiceDieDefinition3D = load(DEFINITION)
	for i in CharScreens.ROLL_DICE:
		dice.append(roller.create_die(definition))
	rest()
	texture = _world.get_texture()


## Tumbles the dice to these faces, then calls done.
func roll(faces: Array, done: Callable) -> void:
	_done = done
	roller.roll_dice(dice, faces)


## Puts the dice back at rest.
func rest() -> void:
	roller.cancel_rolls()
	_done = Callable()
	for i in dice.size():
		roller.reset_die(dice[i], i, dice.size())


## Ends a roll at once, for the self-test.
func finish_now() -> void:
	roller.cancel_rolls()
	_on_finished({})


func _on_finished(_results: Dictionary) -> void:
	var done := _done
	_done = Callable()
	if done.is_valid():
		done.call()

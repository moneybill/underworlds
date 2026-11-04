class_name TownMap
extends Control
## The Castle screen: a painted map of the town where each building is a click target. The options
## come from the screen dictionary, so a building's action and greying match the menu system.

signal chosen(option: Dictionary)

const IMAGE := "res://assets/images/town_map.webp"
const ASPECT := 16.0 / 9.0
const CANVAS := Vector2(2000, 1116)  # the coordinate space of SPOTS, whatever the image's real size
const PLATE_FONT := 18
const PANEL_FONT := 16
const PANEL_MARGIN := 22.0  # keeps the corner panels inside the painted frame
const PARTY_PORTRAIT := 36.0
const INFO_SIZE := Vector2(370, 76)
## From the Vefects pack, which its licence keeps out of the public repository, so it may be missing.
## Without it the painted campfire shows on its own.
const FIRE_SCENE := "res://Vefects/Free Fire VFX/Particles/VFX_Fire_01_Small_Simple.tscn"
const FIRE_BASE := Vector2(1219, 380)  # the middle of the fire ring, in SPOTS coordinates
const FIRE_WINDOW := Vector2(160, 160)  # the size of the window the fire burns in, in SPOTS coordinates
const TORCH_BASE := Vector2(1731, 206)  # the torch in the Maze's doorway
const TORCH_WINDOW := Vector2(70, 70)  # the smaller the window, the smaller the fire
const FIRE_BASE_HEIGHT := 0.15  # of the window, from its bottom edge
const FIRE_VIEW_SIZE := 3.0  # the height of the window in the 3D world of the pack's fire
const FIRE_SPEED := 0.25  # of the pack's speed, which looks frantic at this scale

## Keyed by option id. poly outlines the building; plate is the center of its name plate.
const SPOTS := {
	"T": {"plate": Vector2(530, 556), "poly": [Vector2(322, 330), Vector2(350, 200), Vector2(365, 155), Vector2(385, 165), Vector2(448, 160), Vector2(462, 105), Vector2(480, 190), Vector2(640, 250), Vector2(672, 140), Vector2(710, 300), Vector2(722, 450), Vector2(640, 520), Vector2(560, 545), Vector2(440, 480), Vector2(335, 440)]},
	"A": {"plate": Vector2(885, 336), "poly": [Vector2(775, 200), Vector2(880, 130), Vector2(945, 82), Vector2(1003, 180), Vector2(1000, 240), Vector2(985, 290), Vector2(890, 322), Vector2(790, 290), Vector2(772, 250)]},
	"G": {"plate": Vector2(530, 932), "poly": [Vector2(358, 765), Vector2(415, 680), Vector2(412, 630), Vector2(455, 640), Vector2(460, 600), Vector2(495, 605), Vector2(590, 595), Vector2(650, 680), Vector2(690, 745), Vector2(725, 790), Vector2(690, 830), Vector2(660, 850), Vector2(560, 890), Vector2(470, 920), Vector2(375, 870)]},
	"B": {"plate": Vector2(1330, 1014), "poly": [Vector2(1150, 830), Vector2(1290, 760), Vector2(1300, 735), Vector2(1340, 730), Vector2(1350, 770), Vector2(1490, 850), Vector2(1530, 890), Vector2(1510, 950), Vector2(1390, 990), Vector2(1300, 1000), Vector2(1200, 990), Vector2(1150, 900)]},
	"R": {"plate": Vector2(1457, 672), "poly": [Vector2(1355, 620), Vector2(1370, 550), Vector2(1510, 430), Vector2(1700, 480), Vector2(1800, 470), Vector2(1920, 560), Vector2(1900, 640), Vector2(1830, 710), Vector2(1720, 760), Vector2(1570, 820), Vector2(1480, 770), Vector2(1380, 700)]},
	"M": {"plate": Vector2(1755, 305), "poly": [Vector2(1630, 190), Vector2(1690, 110), Vector2(1780, 50), Vector2(1830, 70), Vector2(1880, 190), Vector2(1840, 280), Vector2(1780, 290), Vector2(1700, 290), Vector2(1660, 240)]},
	"E": {"plate": Vector2(1000, 1062), "poly": [Vector2(865, 1010), Vector2(900, 965), Vector2(940, 1025), Vector2(1060, 1025), Vector2(1100, 965), Vector2(1135, 1010), Vector2(1130, 1095), Vector2(870, 1095)]},
}

var ui
var _texture: Texture2D
var _opts := {}  # option id -> option dictionary
var _hover := ""
var _body := ""
var _info: RichTextLabel
var _info_panel: PanelContainer
var _party: GridContainer
var _party_panel: PanelContainer
var _fire_window: SubViewportContainer
var _torch_window: SubViewportContainer
var _smoke: MapSmoke
var _mist: MapSmoke
var _forges: ForgeGlow


func _init(root) -> void:
	ui = root
	_texture = load(IMAGE)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_exited.connect(_set_hover.bind(""))
	resized.connect(queue_redraw)
	resized.connect(_place_panels)
	resized.connect(_place_fires)
	_fire_window = _add_fire_window()
	_torch_window = _add_fire_window()
	_mist = MapSmoke.new(self, MapSmoke.MAZE_MIST)
	add_child(_mist)
	_smoke = MapSmoke.new(self, MapSmoke.CHIMNEY)
	add_child(_smoke)
	_forges = ForgeGlow.new(self)
	add_child(_forges)
	_party_panel = _corner_panel()
	_party = GridContainer.new()
	_party.columns = 6  # portrait, name, class, level, health, status
	_party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party.add_theme_constant_override("h_separation", 12)
	_party.add_theme_constant_override("v_separation", 3)
	_party_panel.add_child(_party)
	_info_panel = _corner_panel()
	_info_panel.custom_minimum_size = INFO_SIZE
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.scroll_active = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_font_size_override("normal_font_size", PANEL_FONT)
	_info.add_theme_font_size_override("italics_font_size", PANEL_FONT)
	_info_panel.add_child(_info)


## The pack's fire is 3D, so each one burns in a small see-through window of its own over the painting.
func _add_fire_window() -> SubViewportContainer:
	if not ResourceLoader.exists(FIRE_SCENE):
		return null
	var window := SubViewportContainer.new()
	window.stretch = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(window)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	window.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = FIRE_VIEW_SIZE
	camera.position = Vector3(0, FIRE_VIEW_SIZE * (0.5 - FIRE_BASE_HEIGHT), 5)
	view.add_child(camera)
	var fire: Node3D = (load(FIRE_SCENE) as PackedScene).instantiate()
	for part in fire.get_children():
		if part is AudioStreamPlayer3D or "intensity_multiplier" in part:  # silent, and nothing here to light
			part.free()
	for flames in fire.find_children("*", "GPUParticles3D", true, false):
		flames.speed_scale = FIRE_SPEED
	view.add_child(fire)
	return window


func _place_fires() -> void:
	_place_fire(_fire_window, FIRE_BASE, FIRE_WINDOW)
	_place_fire(_torch_window, TORCH_BASE, TORCH_WINDOW)


func _place_fire(window: SubViewportContainer, base: Vector2, canvas_size: Vector2) -> void:
	if window == null:
		return
	var box := canvas_size * _map_rect().size / CANVAS
	window.size = box
	window.position = view_point(base) - Vector2(box.x * 0.5, box.y * (1.0 - FIRE_BASE_HEIGHT))


## A dark panel over the painting that lets clicks through to the buildings beneath.
func _corner_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.C_BG, 0.88), UiStyle.C_LINE, 6))
	add_child(p)
	return p


## The party sits on the open field at the top left, the text on the bottom left.
func _place_panels() -> void:
	var r := _map_rect()
	_party_panel.reset_size()
	_party_panel.position = r.position + Vector2.ONE * PANEL_MARGIN
	_info_panel.position = Vector2(r.position.x + PANEL_MARGIN, r.end.y - PANEL_MARGIN - INFO_SIZE.y)


## Called by the menu system each time a screen with `"map": true` is shown.
func show_options(s: Dictionary) -> void:
	_opts = {}
	for o in s.get("opts", []):
		_opts[String(o["k"]).to_upper()] = o
	_body = s.get("body", "")
	_hover = ""
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_refresh_info()
	_refresh_party()
	_place_panels.call_deferred()
	queue_redraw()


## Where the painting sits: the whole window at 16:9, centered at any other window shape.
func _map_rect() -> Rect2:
	var dsz := Vector2(size.x, size.x / ASPECT)
	if dsz.y > size.y:
		dsz = Vector2(size.y * ASPECT, size.y)
	return Rect2((size - dsz) * 0.5, dsz)


## A point in SPOTS coordinates, in this control's coordinates.
func view_point(p: Vector2) -> Vector2:
	var r := _map_rect()
	return r.position + p * r.size / CANVAS


func _spot_at(pos: Vector2) -> String:
	var r := _map_rect()
	var p := (pos - r.position) * CANVAS / r.size
	for k in SPOTS:
		if _opts.has(k) and Geometry2D.is_point_in_polygon(p, PackedVector2Array(SPOTS[k]["poly"])):
			return k
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(_spot_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var k := _spot_at(event.position)
		if k != "" and not _opts[k].get("dis", false):
			chosen.emit(_opts[k])


func _set_hover(k: String) -> void:
	if k == _hover:
		return
	_hover = k
	var usable: bool = k != "" and not _opts[k].get("dis", false)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if usable else Control.CURSOR_ARROW
	_refresh_info()
	queue_redraw()


func _refresh_info() -> void:
	if _hover == "":
		_info.text = _body
		return
	var o: Dictionary = _opts[_hover]
	_info.text = "[color=#e3a33f]%s[/color]" % ui.esc(ui._opt_text(o))
	if o.get("dis", false):
		_info.text += "\n[color=#d6563f]%s[/color]" % ui.esc(o.get("why", ""))


func _refresh_party() -> void:
	for n in _party.get_children():
		_party.remove_child(n)
		n.queue_free()
	var ps: Array = Game.party_chars()
	if ps.is_empty():
		var none := Label.new()
		none.text = "NO PARTY FORMED"
		none.add_theme_font_size_override("font_size", PANEL_FONT)
		none.add_theme_color_override("font_color", UiStyle.C_DIM)
		_party.add_child(none)
		return
	var corner := Control.new()  # no heading over the portraits
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party.add_child(corner)
	_party_label("NAME", UiStyle.C_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_party_label("CLASS", UiStyle.C_DIM)
	_party_label("LVL", UiStyle.C_DIM)
	_party_label("HEALTH", UiStyle.C_DIM)
	_party_label("STATUS", UiStyle.C_DIM)
	for i in ps.size():
		var c: Character = ps[i]
		var face := TextureRect.new()
		if c.portrait_path() != "":
			face.texture = load(c.portrait_path())
		face.custom_minimum_size = Vector2.ONE * PARTY_PORTRAIT
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_party.add_child(face)
		if not c.is_alive():
			UiStyle.add_tombstone(face)
		var row := Color(ui.party_row_color(i))
		_party_label(c.name + (" &" if c.honor else ""), row, HORIZONTAL_ALIGNMENT_LEFT)
		_party_label("%s-%s" % [c.align.substr(0, 1), c.cdata()["ab"]], row)
		_party_label(str(c.lvl), row)
		_party_label("%d/%d" % [c.hp, c.maxhp], row)
		_party_label(c.status, Color(ui.status_color(c.status, ui.party_row_color(i))))


func _party_label(text: String, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", PANEL_FONT)
	l.add_theme_color_override("font_color", color)
	_party.add_child(l)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.C_BG)
	var r := _map_rect()
	draw_texture_rect(_texture, r, false)
	if _hover != "":
		_draw_outline(_hover)
	for k in SPOTS:
		if _opts.has(k):
			_draw_plate(k)


func _draw_outline(k: String) -> void:
	var usable: bool = not _opts[k].get("dis", false)
	var col: Color = UiStyle.C_TORCH if usable else UiStyle.C_DIM
	var pts := PackedVector2Array()
	for p in SPOTS[k]["poly"]:
		pts.append(view_point(p))
	draw_colored_polygon(pts, Color(col, 0.18))
	pts.append(pts[0])
	draw_polyline(pts, col, 2.5, true)


func _draw_plate(k: String) -> void:
	var o: Dictionary = _opts[k]
	var usable: bool = not o.get("dis", false)
	var text: String = ui._opt_text(o)
	var tsz: Vector2 = ui.mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT)
	var c := view_point(SPOTS[k]["plate"])
	var box := Rect2(c - (tsz + Vector2(12, 4)) * 0.5, tsz + Vector2(12, 4))
	box.position.x = clampf(box.position.x, _map_rect().position.x, _map_rect().end.x - box.size.x)
	var hot := k == _hover and usable
	draw_rect(box, Color(UiStyle.C_BG, 0.88))
	draw_rect(box, UiStyle.C_TORCH if hot else UiStyle.C_LINE, false, 1.0)
	var ink: Color = UiStyle.C_TORCH if hot else (UiStyle.C_INK if usable else Color(UiStyle.C_INK, 0.45))
	draw_string(ui.mono, box.position + Vector2(6, 2 + ui.mono.get_ascent(PLATE_FONT)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, PLATE_FONT, ink)

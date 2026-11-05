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
const PANEL_MARGIN := 3.0  # between the corner panels and the window's edges
const PARTY_PORTRAIT := 36.0
const PARTY_CLOSE_ARROW := "res://assets/images/arrow_up.svg"
const PARTY_OPEN_ARROW := "res://assets/images/arrow_down.svg"
const PARTY_ARROW_SIZE := 14
const INFO_SIZE := Vector2(500, 85)  # five lines tall, so it doesn't jump between buildings; a longer text makes it taller
## From the Vefects pack, which its licence keeps out of the public repository, so it may be missing.
## Without it the painted campfire shows on its own.
const FIRE_SCENE := "res://Vefects/Free Fire VFX/Particles/VFX_Fire_01_Small_Simple.tscn"
const FIRE_BASE := Vector2(1235, 365)  # the middle of the fire ring, in SPOTS coordinates
const FIRE_WINDOW := Vector2(173, 173)  # the size of the window the fire burns in, in SPOTS coordinates
const TORCH_BASE := Vector2(1788, 177)  # the torch in the Maze's doorway
const TORCH_WINDOW := Vector2(76, 76)  # the smaller the window, the smaller the fire
const FIRE_VIEW_SIZE := 3.0  # the height of the window in the 3D world of the pack's fire
const FIRE_SPEED := 0.25  # of the pack's speed, which looks frantic at this scale

## Keyed by option id. poly outlines the building; plate is the center of its name plate.
const SPOTS := {
	"T": {"plate": Vector2(491, 555), "poly": [Vector2(266, 311), Vector2(296, 170), Vector2(313, 122), Vector2(334, 133), Vector2(402, 127), Vector2(417, 68), Vector2(437, 160), Vector2(610, 224), Vector2(644, 106), Vector2(685, 278), Vector2(698, 440), Vector2(610, 516), Vector2(523, 543), Vector2(394, 473), Vector2(280, 430)]},
	"A": {"plate": Vector2(916, 291), "poly": [Vector2(756, 170), Vector2(869, 95), Vector2(939, 43), Vector2(1002, 149), Vector2(999, 214), Vector2(982, 268), Vector2(880, 302), Vector2(772, 268), Vector2(752, 224)]},
	"G": {"plate": Vector2(491, 922), "poly": [Vector2(305, 781), Vector2(367, 689), Vector2(363, 635), Vector2(410, 646), Vector2(415, 602), Vector2(453, 608), Vector2(556, 597), Vector2(621, 689), Vector2(664, 759), Vector2(702, 808), Vector2(664, 851), Vector2(631, 872), Vector2(523, 916), Vector2(426, 948), Vector2(323, 894)]},
	"B": {"plate": Vector2(1355, 1050), "poly": [Vector2(1161, 851), Vector2(1312, 775), Vector2(1323, 748), Vector2(1366, 743), Vector2(1377, 786), Vector2(1528, 872), Vector2(1571, 916), Vector2(1550, 980), Vector2(1420, 1024), Vector2(1323, 1034), Vector2(1215, 1024), Vector2(1161, 926)]},
	"R": {"plate": Vector2(1492, 680), "poly": [Vector2(1382, 624), Vector2(1398, 548), Vector2(1550, 419), Vector2(1755, 473), Vector2(1863, 462), Vector2(1993, 559), Vector2(1971, 646), Vector2(1895, 721), Vector2(1777, 775), Vector2(1614, 840), Vector2(1517, 786), Vector2(1409, 710)]},
	"M": {"plate": Vector2(1814, 284), "poly": [Vector2(1679, 160), Vector2(1744, 73), Vector2(1841, 8), Vector2(1895, 30), Vector2(1949, 160), Vector2(1906, 257), Vector2(1841, 268), Vector2(1755, 268), Vector2(1712, 214)]},
	"E": {"plate": Vector2(999, 1092), "poly": [Vector2(853, 1045), Vector2(891, 997), Vector2(934, 1061), Vector2(1063, 1061), Vector2(1107, 997), Vector2(1145, 1045), Vector2(1139, 1116), Vector2(858, 1116)]},
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
var _party_toggle: Button
var _party_closed := false  # stays as the player left it while the game runs
var _fire_window: FireWindow
var _torch_window: FireWindow
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
	_fire_window = FireWindow.make(FIRE_SCENE, FIRE_VIEW_SIZE, FIRE_SPEED)
	_torch_window = FireWindow.make(FIRE_SCENE, FIRE_VIEW_SIZE, FIRE_SPEED)
	for window in [_fire_window, _torch_window]:
		if window != null:
			add_child(window)
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
	var party_col := VBoxContainer.new()
	party_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_col.add_theme_constant_override("separation", 8)
	_party_panel.add_child(party_col)
	party_col.add_child(_party)
	_party_toggle = Button.new()
	_party_toggle.add_theme_constant_override("icon_max_width", PARTY_ARROW_SIZE)
	_party_toggle.focus_mode = Control.FOCUS_NONE
	_party_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UiStyle.make_small_button(_party_toggle)
	_party_toggle.pressed.connect(_toggle_party_list)
	party_col.add_child(_party_toggle)
	_info_panel = _corner_panel()
	_info_panel.minimum_size_changed.connect(_place_panels, CONNECT_DEFERRED)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.scroll_active = false
	_info.fit_content = true
	_info.custom_minimum_size = INFO_SIZE
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_font_size_override("normal_font_size", PANEL_FONT)
	_info.add_theme_font_size_override("italics_font_size", PANEL_FONT)
	_info_panel.add_child(_info)


func _place_fires() -> void:
	_place_fire(_fire_window, FIRE_BASE, FIRE_WINDOW)
	_place_fire(_torch_window, TORCH_BASE, TORCH_WINDOW)


func _place_fire(window: FireWindow, base: Vector2, canvas_size: Vector2) -> void:
	if window != null:
		window.place(view_point(base), canvas_size * _map_rect().size / CANVAS)


## A dark panel over the painting that lets clicks through to the buildings beneath.
func _corner_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.C_BG, 0.88), UiStyle.C_LINE, 6))
	add_child(p)
	return p


## The party sits in the top left corner, the text in the bottom left.
func _place_panels() -> void:
	var r := _map_rect()
	_party_panel.reset_size()
	_party_panel.position = r.position + Vector2.ONE * PANEL_MARGIN
	_info_panel.reset_size()
	_info_panel.position = Vector2(r.position.x + PANEL_MARGIN, r.end.y - PANEL_MARGIN - _info_panel.size.y)


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
	if o.has("about"):
		_info.text += "\n" + ui.flav(ui.esc(o["about"]))
	if o.get("dis", false):
		_info.text += "\n[color=#d6563f]%s[/color]" % ui.esc(o.get("why", ""))


## Closes the party list down to its button, or opens it again.
func _toggle_party_list() -> void:
	_party_closed = not _party_closed
	_show_party_list()
	_place_panels.call_deferred()


## With no party there is nothing to close, so "no party formed" always shows, with no button.
func _show_party_list() -> void:
	var has_party := not Game.party_chars().is_empty()
	_party.visible = not (has_party and _party_closed)
	_party_toggle.visible = has_party
	_party_toggle.text = "OPEN PARTY LIST" if _party_closed else "CLOSE PARTY LIST"
	_party_toggle.icon = load(PARTY_OPEN_ARROW if _party_closed else PARTY_CLOSE_ARROW)


func _refresh_party() -> void:
	_show_party_list()
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

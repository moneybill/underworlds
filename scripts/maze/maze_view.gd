class_name MazeView
extends Control
## The picture window. Draws the Castle scenes, the first-person painted Maze, camp,
## monsters in combat, and treasure chests. Everything is drawn on a 480x360 canvas and scaled.

const W := 480.0
const H := 360.0
const INK := Color("eadfc4")
const TORCH := Color("e3a33f")
const BLOOD := Color("d6563f")
const MANA := Color("8bace6")
const MOSS := Color("93c07e")

## Painted monsters, by their id in Data.MONS. The rest are still drawn by _monster until they have art.
const MONSTER_ART := {
	"SLIME": preload("res://assets/images/monsters/slime.webp"),
	"KOBOLD": preload("res://assets/images/monsters/kobold.webp"),
	"ORC": preload("res://assets/images/monsters/orc.webp"),
	"SKEL": preload("res://assets/images/monsters/skeleton.webp"),
	"RAT": preload("res://assets/images/monsters/rat.webp"),
	"MIMIC": preload("res://assets/images/monsters/mimic.webp"),
	# One painting for each kind of caster, whatever their level.
	"MAGE1": preload("res://assets/images/monsters/mage.webp"),
	"MAGE3": preload("res://assets/images/monsters/mage.webp"),
	"MAGE7": preload("res://assets/images/monsters/mage.webp"),
	"PRIEST1": preload("res://assets/images/monsters/priest.webp"),
	"PRIEST5": preload("res://assets/images/monsters/priest.webp"),
}
const CARD_SINGLE := 320.0  # a lone group of monsters
const CARD_PAIR := 225.0  # each of two groups, nearly filling the window's width
const CARD_GRID := 165.0  # each of three or four groups
const CARD_GAP := 10.0
const PLAQUE_HEIGHT := 28.0
const PLAQUE_FILL := Color("2b1f16")
const PLAQUE_EDGE := Color("a9824a")
const PLAQUE_FONT_MAX := 18
const PLAQUE_FONT_MIN := 9
const BADGE_FONT := 15

var kind := "castle"
var mono: Font
var battle: Battle = null
var world: MazeWorld
var _targets: Array = []  # the groups that can be clicked now, by their place in battle.groups
var _on_target := Callable()
var _hover := -1


func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # keeps the paintings' ink lines clean when small
	world = MazeWorld.new()
	add_child(world)
	resized.connect(_fit_world)
	get_viewport().size_changed.connect(_fit_world)
	visibility_changed.connect(_update_world)
	_fit_world()


func show_view(k: String) -> void:
	kind = k
	_clear_targets()
	_update_world()
	queue_redraw()


func _shows_maze() -> bool:
	return kind == "maze" or kind == "camp" or kind == "combat" or kind == "chest"


func _update_world() -> void:
	if world != null:
		world.set_active(_shows_maze() and is_visible_in_tree())
		world.set_campfire(kind == "camp" and is_visible_in_tree())


## Lets the player pick one of these monster groups by clicking its card.
func set_targets(groups: Array, on_pick: Callable) -> void:
	_targets = groups
	_on_target = on_pick
	queue_redraw()


func _clear_targets() -> void:
	_targets = []
	_on_target = Callable()
	_hover = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if _targets.is_empty():
		return
	if event is InputEventMouseMotion:
		var over := _target_at(event.position)
		if over != _hover:
			_hover = over
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over >= 0 else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var picked := _target_at(event.position)
		if picked >= 0:
			accept_event()
			var on_pick := _on_target
			_clear_targets()
			on_pick.call(picked)


## The group under a point in this control, if it can be picked now, or -1.
func _target_at(point: Vector2) -> int:
	if battle == null:
		return -1
	var alive_groups := battle.alive_groups()
	var rects := card_rects(alive_groups.size())
	for i in rects.size():
		if rects[i].has_point(canvas_point(point)) and _targets.has(alive_groups[i]):
			return alive_groups[i]
	return -1


func _canvas_scale() -> float:
	return min(size.x / W, size.y / H)


func _canvas_origin() -> Vector2:
	return (size - Vector2(W, H) * _canvas_scale()) / 2.0


## From this control's pixels to the 480x360 canvas.
func canvas_point(point: Vector2) -> Vector2:
	return (point - _canvas_origin()) / _canvas_scale()


## And back again.
func view_point(canvas: Vector2) -> Vector2:
	return _canvas_origin() + canvas * _canvas_scale()


## Renders the Maze at the window's own pixels, so the art stays sharp.
func _fit_world() -> void:
	var px := size * get_global_transform_with_canvas().get_scale()
	world.size = Vector2i(maxi(1, int(px.x)), maxi(1, int(px.y)))
	queue_redraw()


func _draw() -> void:
	var sc := _canvas_scale()
	draw_rect(Rect2(Vector2.ZERO, size), Color("05060a"))
	draw_set_transform(_canvas_origin(), 0.0, Vector2(sc, sc))
	match kind:
		"maze": _maze(true)
		"camp": _camp()
		"combat": _combat()
		"chest": _chest()
		"tavern": _castle("GILGAMESH'S"); draw_rect(Rect2(150, 230, 30, 26), Color(TORCH, .35)); draw_rect(Rect2(300, 230, 30, 26), Color(TORCH, .35))
		"shop": _castle("BOLTAC'S"); _txt("OPEN AROUND THE CLOCK", 240, 300, 22, TORCH)
		"train": _train()
		"edge": _edge()
		_: _castle("HOME OF THE ELITE GUARD" if Game.won else "TREBOR'S CASTLE")
	draw_set_transform(Vector2.ZERO)


# ---------- primitives ----------
func _txt(t: String, x: float, y: float, sz: int, col: Color) -> void:
	draw_string(mono, Vector2(x - 240, y), t, HORIZONTAL_ALIGNMENT_CENTER, 480, sz, col)


func _poly(pts: PackedVector2Array, fill: Color, stroke := Color(0, 0, 0, 0)) -> void:
	draw_colored_polygon(pts, fill)
	if stroke.a > 0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, stroke, 1.5, true)


func _circ(c: Vector2, r: float, fill: Color, stroke := INK) -> void:
	draw_circle(c, r, fill)
	draw_arc(c, r, 0, TAU, 32, stroke, 2.0, true)


func _sky() -> void:
	for i in 12:
		var t := i / 12.0
		draw_rect(Rect2(0, H * t, W, H / 12.0 + 1), Color("0a0c16").lerp(Color("1b2033"), t))
	draw_circle(Vector2(395, 62), 22, Color("e9e1c8"))
	draw_circle(Vector2(405, 56), 20, Color("0d1020"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		draw_rect(Rect2(rng.randf() * W, rng.randf() * 150, 1.5, 1.5), Color(INK, .6))


func _castle(sign: String) -> void:
	_sky()
	var stone := Color("141826")
	draw_rect(Rect2(60, 170, 360, 150), stone)
	for x in range(60, 420, 24):
		draw_rect(Rect2(x, 156, 14, 16), stone)
	for tw in [[40, 110, 70], [370, 110, 70], [205, 80, 70]]:
		draw_rect(Rect2(tw[0], tw[1], tw[2], 320 - tw[1]), stone)
		for i in 4:
			draw_rect(Rect2(tw[0] + i * 20, tw[1] - 14, 12, 14), stone)
	for p in [Vector2(70, 150), Vector2(400, 150), Vector2(235, 120), Vector2(255, 120)]:
		draw_rect(Rect2(p, Vector2(6, 10)), TORCH)
	var gate := PackedVector2Array([Vector2(205, 320), Vector2(205, 255)])
	for i in 13:
		var a := PI + PI * i / 12.0
		gate.append(Vector2(240 + cos(a) * 35, 255 + sin(a) * 35))
	gate.append(Vector2(275, 320))
	draw_colored_polygon(gate, Color("05060a"))
	draw_rect(Rect2(205, 255, 70, 65), Color(TORCH, .18))
	draw_rect(Rect2(0, 320, W, 40), Color("1e2232"))
	draw_rect(Rect2(90, 18, 300, 44), Color("0f1119", .88))
	draw_rect(Rect2(90.5, 18.5, 299, 43), TORCH, false, 1.0)
	_txt(sign, 240, 49, 28, INK)


func _train() -> void:
	_sky()
	draw_rect(Rect2(0, 300, W, 60), Color("1e2232"))
	for x in [80, 200, 320]:
		draw_rect(Rect2(x, 220, 12, 80), Color("5a4a36"))
		draw_rect(Rect2(x - 16, 236, 44, 8), Color("5a4a36"))
	_txt("TRAINING GROUNDS", 240, 60, 32, INK)


func _edge() -> void:
	_sky()
	var stone := Color("141826")
	draw_rect(Rect2(300, 170, 180, 150), stone)
	for x in range(300, 480, 24):
		draw_rect(Rect2(x, 156, 14, 16), stone)
	draw_rect(Rect2(0, 300, W, 60), Color("1e2232"))
	var hole := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		hole.append(Vector2(140 + cos(a) * 70, 310 + sin(a) * 18))
	draw_colored_polygon(hole, Color("05060a"))
	_txt("TO THE MAZE", 140, 270, 24, TORCH)


# ---------- the Maze ----------
func _maze(with_map: bool, with_signs := true) -> void:
	var p: Dictionary = Game.pos
	var lv: MazeLevel = Game.level()
	if lv.flag(p["x"], p["y"], "dark"):
		if with_signs:
			_txt("DARKNESS", 240, 190, 28, Color("3a4159"))
		return
	world.sync_to_party()
	draw_texture_rect(world.get_texture(), Rect2(0, 0, W, H), false)
	if with_signs and lv.flag(p["x"], p["y"], "up"):
		_txt("A LADDER LEADS UP", 240, 340, 22, TORCH)
	if with_signs and lv.flag(p["x"], p["y"], "down"):
		_txt("A LADDER LEADS DOWN", 240, 340, 22, TORCH)
	if with_map and Game.show_map:
		_map()


func _map() -> void:
	var p: Dictionary = Game.pos
	var lv: MazeLevel = Game.level()
	var s := 13.0
	var n := MazeLevel.N
	var ox := (W - n * s) / 2.0
	var oy := (H - n * s) / 2.0
	var seen: Dictionary = Game.seen.get(str(p["z"]), {})
	draw_rect(Rect2(ox - 8, oy - 8, n * s + 16, n * s + 16), Color("05060a", .92))
	for y in n:
		for x in n:
			if not seen.has("%d,%d" % [x, y]):
				continue
			var X := ox + x * s
			var Y := oy + (n - 1 - y) * s
			draw_rect(Rect2(X, Y, s, s), Color.BLACK if lv.flag(x, y, "dark") else Color("1e2232"))
			if lv.flag(x, y, "up") or lv.flag(x, y, "down"):
				draw_string(mono, Vector2(X + 2, Y + s - 1), "U" if lv.flag(x, y, "up") else "D", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MOSS)
			var segs := [[0, Vector2(X, Y), Vector2(X + s, Y)], [2, Vector2(X, Y + s), Vector2(X + s, Y + s)], [1, Vector2(X + s, Y), Vector2(X + s, Y + s)], [3, Vector2(X, Y), Vector2(X, Y + s)]]
			for sg in segs:
				var w := lv.wall(x, y, sg[0])
				if w == 0 or (w == 3 and not lv.flag(x, y, "k%d" % sg[0])):
					continue
				draw_line(sg[1], sg[2], TORCH if w == 1 else MANA, 1.2)
	var X2: float = ox + p["x"] * s + s / 2
	var Y2: float = oy + (n - 1 - p["y"]) * s + s / 2
	draw_circle(Vector2(X2 + MazeLevel.DX[p["d"]] * 3, Y2 - MazeLevel.DY[p["d"]] * 3), 3.5, BLOOD)
	_txt("LEVEL %d  ·  YOUR MAP NOTES" % p["z"], 240, oy - 12, 18, INK)


func _camp() -> void:
	_maze(false)
	if not world.has_campfire():
		_drawn_campfire()
	_txt("CAMP", 240, 60, 40, INK)


## Stands in for the real fire when the Vefects pack isn't installed.
func _drawn_campfire() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("05060a", .55))
	var f := Vector2(240, 300)
	draw_rect(Rect2(f.x - 30, f.y, 60, 8), Color("5a4a36"))
	for fl in [[BLOOD, 26, 54], [TORCH, 18, 40], [INK, 8, 22]]:
		_poly(PackedVector2Array([Vector2(f.x - fl[1], f.y), Vector2(f.x, f.y - fl[2]), Vector2(f.x + fl[1], f.y)]), fl[0])


# ---------- combat ----------
func _combat() -> void:
	_maze(false, false)
	if battle == null:
		return
	var alive_groups := battle.alive_groups()
	var rects := card_rects(alive_groups.size())
	for i in rects.size():
		_monster_card(battle.groups[alive_groups[i]], rects[i])
		if not _targets.is_empty():
			_target_mark(alive_groups[i], rects[i])


## Where the monster groups go, in order: up to two rows of two, with a lone group larger and in the middle.
static func card_rects(count: int) -> Array:
	if count <= 0:
		return []
	if count == 1:
		return [Rect2((W - CARD_SINGLE) / 2.0, (H - CARD_SINGLE) / 2.0, CARD_SINGLE, CARD_SINGLE)]
	var out := []
	var rows := 1 if count == 2 else 2
	var card := CARD_PAIR if count == 2 else CARD_GRID
	var top := (H - rows * card - (rows - 1) * CARD_GAP) / 2.0
	for row in rows:
		var in_row: int = mini(count - row * 2, 2)
		var left := (W - in_row * card - (in_row - 1) * CARD_GAP) / 2.0
		for col in in_row:
			out.append(Rect2(left + col * (card + CARD_GAP), top + row * (card + CARD_GAP), card, card))
	return out


func _monster_card(gp: Dictionary, r: Rect2) -> void:
	var n := battle.live(gp).size()
	if MONSTER_ART.has(gp["id"]):
		draw_texture_rect(MONSTER_ART[gp["id"]], r, false)
	else:
		draw_rect(r, Color("14161f"))
		_monster(Data.MONS[gp["id"]]["look"], r.get_center().x, r.position.y + (r.size.y - PLAQUE_HEIGHT) / 2.0, r.size.x * .62)
	draw_rect(r, PLAQUE_EDGE, false, 2.0)
	_plaque(battle.gname(gp, n), Rect2(r.position.x, r.end.y - PLAQUE_HEIGHT, r.size.x, PLAQUE_HEIGHT))
	if n > 1:
		_badge("x%d" % n, Vector2(r.end.x, r.position.y), TORCH, true)
	var sleeping := true
	for m in battle.live(gp):
		if not m["asleep"]:
			sleeping = false
	if sleeping:
		_badge("Z z z", r.position, MANA, false)


## While choosing: picks glow, the hovered one most, and groups out of reach dim.
func _target_mark(group: int, r: Rect2) -> void:
	if not _targets.has(group):
		draw_rect(r, Color(0, 0, 0, .62))
	elif group == _hover:
		draw_rect(r, Color(TORCH, .16))
		draw_rect(r.grow(1.0), INK, false, 4.0)
	else:
		draw_rect(r.grow(1.0), TORCH, false, 3.0)


## A riveted bronze plate with the name on it, in the largest size that fits.
func _plaque(text: String, r: Rect2) -> void:
	draw_rect(r, PLAQUE_FILL)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1.5)), Color(PLAQUE_EDGE, .7))
	draw_rect(r, PLAQUE_EDGE, false, 2.0)
	for x in [r.position.x + 7.0, r.end.x - 7.0]:
		draw_circle(Vector2(x, r.get_center().y), 2.0, PLAQUE_EDGE)
	var room := r.size.x - 26.0
	var sz := PLAQUE_FONT_MAX
	while sz > PLAQUE_FONT_MIN and mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > room:
		sz -= 1
	var baseline := r.position.y + (r.size.y + mono.get_ascent(sz) - mono.get_descent(sz)) / 2.0
	draw_string(mono, Vector2(r.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, sz, INK)


## A small dark tag in a corner of a card, for the count and for sleep.
func _badge(text: String, corner: Vector2, col: Color, on_right: bool) -> void:
	var w := mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_FONT).x + 10.0
	var r := Rect2(corner.x - w if on_right else corner.x, corner.y, w, 20.0)
	draw_rect(r, PLAQUE_FILL)
	draw_rect(r, PLAQUE_EDGE, false, 1.5)
	draw_string(mono, Vector2(r.position.x, r.end.y - 5.0), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, BADGE_FONT, col)


func _chest() -> void:
	_combat()
	_poly(PackedVector2Array([Vector2(160, 210), Vector2(320, 210), Vector2(320, 290), Vector2(160, 290)]), Color("4a3420"), TORCH)
	var lid := PackedVector2Array([Vector2(160, 210)])
	for i in range(1, 12):
		var t := i / 12.0
		lid.append(Vector2(160 + 160 * t, 210 - sin(PI * t) * 30))
	lid.append(Vector2(320, 210))
	_poly(lid, Color("5a4028"), TORCH)
	draw_rect(Rect2(232, 222, 16, 20), TORCH)


func _monster(look: String, cx: float, cy: float, s: float) -> void:
	var dk := Color("2a2f44")
	var eyes := func(x: float, y: float, w: float, col: Color):
		draw_rect(Rect2(x - w, y, 4, 4), col)
		draw_rect(Rect2(x + w - 4, y, 4, 4), col)
	match look:
		"blob":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				pts.append(Vector2(cx + cos(a) * s * .55, cy + s * .25 + sin(a) * s * .38))
			pts.append(Vector2(cx + s * .55, cy + s * .45))
			pts.append(Vector2(cx - s * .55, cy + s * .45))
			_poly(pts, Color("2d4a3a"), INK)
			eyes.call(cx, cy + s * .05, s * .18, TORCH)
		"cloud":
			for o in [[-.25, 0], [.2, -.1], [0, .15], [.3, .2], [-.3, .25]]:
				draw_circle(Vector2(cx + o[0] * s, cy + o[1] * s), s * .28, Color(MOSS, .35))
			eyes.call(cx, cy, s * .15, TORCH)
		"beast":
			_poly(_ellipse(Vector2(cx, cy + s * .2), s * .45, s * .22), dk, INK)
			for i in [-2, -1, 1, 2]:
				draw_line(Vector2(cx + i * s * .15, cy + s * .35), Vector2(cx + i * s * .22, cy + s * .55), INK, 2.0)
			_circ(Vector2(cx - s * .5, cy + s * .05), s * .16, dk)
			eyes.call(cx - s * .5, cy, s * .09, BLOOD)
		"dragon":
			_poly(PackedVector2Array([Vector2(cx - s * .1, cy), Vector2(cx - s * .55, cy - s * .45), Vector2(cx - s * .3, cy + s * .05)]), Color("3a2622"), INK)
			_poly(PackedVector2Array([Vector2(cx + s * .1, cy), Vector2(cx + s * .55, cy - s * .45), Vector2(cx + s * .3, cy + s * .05)]), Color("3a2622"), INK)
			_poly(_ellipse(Vector2(cx, cy + s * .2), s * .3, s * .25), Color("4a2a22"), INK)
			_circ(Vector2(cx, cy - s * .2), s * .15, Color("4a2a22"))
			eyes.call(cx, cy - s * .24, s * .08, TORCH)
		"undead":
			var bone := Color("cfc6ad")
			_circ(Vector2(cx, cy - s * .3), s * .17, bone, bone)
			draw_rect(Rect2(cx - s * .09, cy - s * .33, s * .06, s * .06), Color.BLACK)
			draw_rect(Rect2(cx + s * .03, cy - s * .33, s * .06, s * .06), Color.BLACK)
			draw_line(Vector2(cx, cy - s * .13), Vector2(cx, cy + s * .25), bone, 2.0)
			for i in 3:
				draw_line(Vector2(cx - s * .16, cy - s * .05 + i * s * .09), Vector2(cx + s * .16, cy - s * .05 + i * s * .09), bone, 2.0)
			for lg in [[-.12, .55], [.12, .55]]:
				draw_line(Vector2(cx, cy + s * .25), Vector2(cx + lg[0] * s, cy + lg[1] * s), bone, 2.0)
			draw_line(Vector2(cx - s * .16, cy - s * .05), Vector2(cx - s * .3, cy + s * .2), bone, 2.0)
			draw_line(Vector2(cx + s * .16, cy - s * .05), Vector2(cx + s * .3, cy + s * .2), bone, 2.0)
		"robe", "boss":
			var col := Color("3b2550") if look == "boss" else Color("24304a")
			_poly(PackedVector2Array([Vector2(cx, cy - s * .5), Vector2(cx - s * .14, cy - s * .2), Vector2(cx + s * .14, cy - s * .2)]), col, INK)
			_poly(PackedVector2Array([Vector2(cx - s * .14, cy - s * .2), Vector2(cx + s * .14, cy - s * .2), Vector2(cx + s * .3, cy + s * .55), Vector2(cx - s * .3, cy + s * .55)]), col, INK)
			eyes.call(cx, cy - s * .28, s * .07, BLOOD if look == "boss" else TORCH)
			draw_line(Vector2(cx + s * .38, cy - s * .45), Vector2(cx + s * .38, cy + s * .55), Color("8a6b3c"), 2.0)
			if look == "boss":
				draw_circle(Vector2(cx, cy), s * .06, MANA)
		"daemon":
			_poly(PackedVector2Array([Vector2(cx - s * .15, cy - s * .1), Vector2(cx - s * .6, cy - s * .4), Vector2(cx - s * .45, cy + s * .2)]), Color("3a2028"), INK)
			_poly(PackedVector2Array([Vector2(cx + s * .15, cy - s * .1), Vector2(cx + s * .6, cy - s * .4), Vector2(cx + s * .45, cy + s * .2)]), Color("3a2028"), INK)
			_poly(PackedVector2Array([Vector2(cx - s * .18, cy - s * .15), Vector2(cx + s * .18, cy - s * .15), Vector2(cx + s * .22, cy + s * .55), Vector2(cx - s * .22, cy + s * .55)]), Color("4a2430"), INK)
			_circ(Vector2(cx, cy - s * .3), s * .15, Color("4a2430"))
			draw_line(Vector2(cx - s * .1, cy - s * .42), Vector2(cx - s * .18, cy - s * .58), INK, 2.0)
			draw_line(Vector2(cx + s * .1, cy - s * .42), Vector2(cx + s * .18, cy - s * .58), INK, 2.0)
			eyes.call(cx, cy - s * .34, s * .08, BLOOD)
		_:
			_circ(Vector2(cx, cy - s * .32), s * .14, dk)
			_poly(PackedVector2Array([Vector2(cx - s * .2, cy - s * .15), Vector2(cx + s * .2, cy - s * .15), Vector2(cx + s * .16, cy + s * .3), Vector2(cx - s * .16, cy + s * .3)]), dk, INK)
			draw_line(Vector2(cx - s * .1, cy + s * .3), Vector2(cx - s * .14, cy + s * .55), INK, 2.0)
			draw_line(Vector2(cx + s * .1, cy + s * .3), Vector2(cx + s * .14, cy + s * .55), INK, 2.0)
			draw_line(Vector2(cx + s * .2, cy - s * .1), Vector2(cx + s * .42, cy - s * .35), INK, 2.0)
			eyes.call(cx, cy - s * .36, s * .07, TORCH)


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

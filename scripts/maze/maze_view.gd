class_name MazeView
extends Control
## The picture window. Draws the Castle scenes, the first-person wireframe Maze, camp,
## monsters in combat, and treasure chests. Everything is drawn on a 480x360 canvas and scaled.

const W := 480.0
const H := 360.0
const INK := Color("eadfc4")
const TORCH := Color("e3a33f")
const BLOOD := Color("d6563f")
const MANA := Color("8bace6")
const MOSS := Color("93c07e")
const DOOR := Color("2a2016")

var kind := "castle"
var mono: Font
var battle: Battle = null


func _ready() -> void:
	clip_contents = true
	resized.connect(queue_redraw)


func show_view(k: String) -> void:
	kind = k
	queue_redraw()


func _draw() -> void:
	var sc: float = min(size.x / W, size.y / H)
	draw_rect(Rect2(Vector2.ZERO, size), Color("05060a"))
	draw_set_transform(Vector2((size.x - W * sc) / 2.0, (size.y - H * sc) / 2.0), 0.0, Vector2(sc, sc))
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
func _frame(i: int) -> Rect2:
	var s: float = [1.0, .64, .42, .29, .2, .14, .1, .07][i]
	return Rect2((W - W * s) / 2.0, (H - H * s) / 2.0, W * s, H * s)


func _shade(d: float) -> Color:
	var v: float = max(0.0, 1.0 - d * 0.19)
	return Color8(int(52 * v + 10), int(58 * v + 11), int(82 * v + 16))


func _edge_col(d: float) -> Color:
	return Color(TORCH, max(0.15, 0.85 - d * 0.16))


func _vis(code: int) -> int:
	return 1 if code == 3 and Game.light <= 0 else code


func _maze(with_map: bool) -> void:
	var p: Dictionary = Game.pos
	var lv: MazeLevel = Game.level()
	if lv.flag(p["x"], p["y"], "dark"):
		_txt("DARKNESS", 240, 190, 28, Color("3a4159"))
		return
	draw_rect(Rect2(0, 0, W, H / 2), Color("0c0e16"))
	draw_rect(Rect2(0, H / 2, W, H / 2), Color("151824"))
	var dir: int = p["d"]
	var depth := 5 if Game.light > 0 else 3
	var left := (dir + 3) % 4
	var right := (dir + 1) % 4
	var cells := []
	var x: int = p["x"]
	var y: int = p["y"]
	for d in depth:
		if not lv.in_bounds(x, y) or (d > 0 and lv.flag(x, y, "dark")):
			break
		cells.append(Vector2i(x, y))
		if _vis(lv.wall(x, y, dir)) != 0:
			break
		x += MazeLevel.DX[dir]
		y += MazeLevel.DY[dir]
	for d in range(cells.size() - 1, -1, -1):
		var c: Vector2i = cells[d]
		var a := _frame(d)
		var b := _frame(d + 1)
		if lv.flag(c.x, c.y, "up") or lv.flag(c.x, c.y, "down"):
			for i in range(1, 4):
				var t := i / 4.0
				var yy: float = a.end.y + (b.end.y - a.end.y) * t
				draw_line(Vector2(a.position.x + (b.position.x - a.position.x) * t + 8, yy), Vector2(a.end.x + (b.end.x - a.end.x) * t - 8, yy), _edge_col(d), 1.0)
		for side in [[left, a.position.x, b.position.x], [right, a.end.x, b.end.x]]:
			var sd: int = side[0]
			var ax: float = side[1]
			var bx: float = side[2]
			var w := _vis(lv.wall(c.x, c.y, sd))
			if w != 0:
				_poly(PackedVector2Array([Vector2(ax, a.position.y), Vector2(bx, b.position.y), Vector2(bx, b.end.y), Vector2(ax, a.end.y)]), _shade(d + .5), _edge_col(d))
				if w >= 2:
					var f := 0.22
					var ix0 := ax + (bx - ax) * f
					var ix1 := ax + (bx - ax) * (1 - f)
					var ty0 := a.position.y + (b.position.y - a.position.y) * f + (a.end.y - a.position.y) * .22
					var ty1 := b.position.y + (a.position.y - b.position.y) * f + (b.end.y - b.position.y) * .22
					_poly(PackedVector2Array([Vector2(ix0, ty0), Vector2(ix1, ty1), Vector2(ix1, b.end.y + (a.end.y - b.end.y) * f), Vector2(ix0, a.end.y + (b.end.y - a.end.y) * f)]), DOOR, _edge_col(d))
			else:
				var nx: int = c.x + MazeLevel.DX[sd]
				var ny: int = c.y + MazeLevel.DY[sd]
				if not lv.in_bounds(nx, ny) or _vis(lv.wall(nx, ny, dir)) != 0:
					_poly(PackedVector2Array([Vector2(ax, b.position.y), Vector2(bx, b.position.y), Vector2(bx, b.end.y), Vector2(ax, b.end.y)]), _shade(d + 1), _edge_col(d + 1))
		var fw := _vis(lv.wall(c.x, c.y, dir))
		if fw != 0:
			_poly(PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), b.end, Vector2(b.position.x, b.end.y)]), _shade(d + 1), _edge_col(d + 1))
			if fw >= 2:
				var bw := b.size.x
				var bh := b.size.y
				_poly(PackedVector2Array([Vector2(b.position.x + bw * .28, b.end.y), Vector2(b.position.x + bw * .28, b.position.y + bh * .22),
					Vector2(b.end.x - bw * .28, b.position.y + bh * .22), Vector2(b.end.x - bw * .28, b.end.y)]), DOOR, _edge_col(d + 1))
	if lv.flag(p["x"], p["y"], "up"):
		_txt("A STAIRCASE LEADS UP", 240, 340, 22, TORCH)
	if lv.flag(p["x"], p["y"], "down"):
		_txt("A STAIRCASE LEADS DOWN", 240, 340, 22, TORCH)
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
	draw_rect(Rect2(0, 0, W, H), Color("05060a", .55))
	var f := Vector2(240, 300)
	draw_rect(Rect2(f.x - 30, f.y, 60, 8), Color("5a4a36"))
	for fl in [[BLOOD, 26, 54], [TORCH, 18, 40], [INK, 8, 22]]:
		_poly(PackedVector2Array([Vector2(f.x - fl[1], f.y), Vector2(f.x, f.y - fl[2]), Vector2(f.x + fl[1], f.y)]), fl[0])
	_txt("CAMP", 240, 60, 40, INK)


# ---------- combat ----------
func _combat() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("07080d"))
	draw_circle(Vector2(240, 220), 180, Color(TORCH, .05))
	draw_rect(Rect2(0, 290, W, 70), Color("151824"))
	if battle == null:
		return
	var alive_groups := battle.alive_groups()
	var k := alive_groups.size()
	for i in k:
		var gi: int = alive_groups[i]
		var gp: Dictionary = battle.groups[gi]
		var cx: float = 240.0 if k == 1 else 140.0 + i * (200.0 / max(1, k - 1))
		var s := 210.0 if k == 1 else 150.0
		var n := battle.live(gp).size()
		_monster(Data.MONS[gp["id"]]["look"], cx, 175, s)
		if n > 1:
			_txt("x%d" % n, cx, 175 + s * .78, 24, TORCH)
		var sleeping := true
		for m in battle.live(gp):
			if not m["asleep"]:
				sleeping = false
		if sleeping:
			_txt("Z z z", cx + s * .3, 90, 26, MANA)
		_txt(battle.gname(gp, n), cx, 34, 22, INK)


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
		"coin":
			for i in 5:
				_circ(Vector2(cx - s * .3 + (i % 3) * s * .3, cy + s * .3 - (i / 3) * s * .3), s * .16, Color("6b5424"))
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

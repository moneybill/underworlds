class_name MazeGen
## Builds each Maze level from a fixed seed, so the layout is identical every time you play
## (players are meant to map it on graph paper). Change SEED_BASE to get a different dungeon.

const SEED_BASE := 4111


static func generate(z: int, start: Vector2i, max_z: int) -> MazeLevel:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_BASE + z * 7919
	var lv := MazeLevel.new()
	lv.z = z
	var n := MazeLevel.N
	for y in n:
		var row := []
		for x in n:
			row.append({"w": [1, 1, 1, 1], "room": 0, "f": {}})
		lv.cells.append(row)

	# Rooms (monster lairs). Kept clear of the arrival stairs.
	var rooms := []
	for t in 90:
		if rooms.size() >= 9:
			break
		var w := rng.randi_range(2, 4)
		var h := rng.randi_range(2, 4)
		var x0 := rng.randi_range(0, n - w)
		var y0 := rng.randi_range(0, n - h)
		if start.x >= x0 - 1 and start.x <= x0 + w and start.y >= y0 - 1 and start.y <= y0 + h:
			continue
		var overlap := false
		for q in rooms:
			if x0 < q.position.x + q.size.x + 1 and x0 + w + 1 > q.position.x and y0 < q.position.y + q.size.y + 1 and y0 + h + 1 > q.position.y:
				overlap = true
		if overlap:
			continue
		var rid := rooms.size() + 1
		rooms.append(Rect2i(x0, y0, w, h))
		for y in range(y0, y0 + h):
			for x in range(x0, x0 + w):
				lv.cells[y][x]["room"] = rid
				if x < x0 + w - 1:
					lv.set_wall(x, y, 1, 0)
				if y < y0 + h - 1:
					lv.set_wall(x, y, 0, 0)

	# Depth-first carve; crossing a room boundary makes a door.
	var visited := {}
	var stack := [start]
	visited[start] = true
	while not stack.is_empty():
		var p: Vector2i = stack.back()
		var opts := []
		for d in 4:
			var q := Vector2i(p.x + MazeLevel.DX[d], p.y + MazeLevel.DY[d])
			if lv.in_bounds(q.x, q.y) and not visited.has(q):
				opts.append(d)
		if opts.is_empty():
			stack.pop_back()
			continue
		var dd: int = opts[rng.randi() % opts.size()]
		var nq := Vector2i(p.x + MazeLevel.DX[dd], p.y + MazeLevel.DY[dd])
		if lv.cells[p.y][p.x]["room"] != lv.cells[nq.y][nq.x]["room"]:
			lv.set_wall(p.x, p.y, dd, 2)
		elif lv.wall(p.x, p.y, dd) == 1:
			lv.set_wall(p.x, p.y, dd, 0)
		visited[nq] = true
		stack.append(nq)

	# Extra loops between corridors, and some doors become secret.
	for y in n:
		for x in n:
			for d in [0, 1]:
				var nx: int = x + MazeLevel.DX[d]
				var ny: int = y + MazeLevel.DY[d]
				if not lv.in_bounds(nx, ny):
					continue
				var wv := lv.wall(x, y, d)
				if wv == 1 and lv.cells[y][x]["room"] == 0 and lv.cells[ny][nx]["room"] == 0 and rng.randf() < 0.09:
					lv.set_wall(x, y, d, 0)
				if wv == 2 and rng.randf() < 0.18:
					lv.set_wall(x, y, d, 3)

	# Distances from the stairs decide where the way down goes.
	var dist := {start: 0}
	var queue := [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d in 4:
			var q := Vector2i(p.x + MazeLevel.DX[d], p.y + MazeLevel.DY[d])
			if lv.wall(p.x, p.y, d) != 1 and lv.in_bounds(q.x, q.y) and not dist.has(q):
				dist[q] = dist[p] + 1
				queue.append(q)
	var far := start
	var best := 0
	for q in dist:
		if lv.cells[q.y][q.x]["room"] == 0 and dist[q] > best:
			best = dist[q]
			far = q

	lv.cells[start.y][start.x]["f"]["up"] = true
	for i in rooms.size():
		var r: Rect2i = rooms[i]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				lv.cells[y][x]["f"]["lair"] = i + 1
	if z < max_z:
		lv.cells[far.y][far.x]["f"]["down"] = true
		lv.down = far
	else:
		# Werdna's chamber: the room farthest from the stairs.
		var boss: Rect2i = rooms[0]
		var bd := -1
		for r in rooms:
			var dv: int = dist.get(r.position, 0)
			if dv > bd:
				bd = dv
				boss = r
		for y in range(boss.position.y, boss.end.y):
			for x in range(boss.position.x, boss.end.x):
				lv.cells[y][x]["f"]["boss"] = true

	# Graffiti, darkness and spinners in plain corridors.
	for i in Data.GRAFFITI[z].size():
		var c := _corridor(lv, rng, start)
		lv.cells[c.y][c.x]["f"]["msg"] = i + 1
	if z >= 2:
		var c := _corridor(lv, rng, start)
		for i in 7:
			var f: Dictionary = lv.cells[c.y][c.x]["f"]
			if lv.cells[c.y][c.x]["room"] == 0 and not f.has("up") and not f.has("down"):
				f["dark"] = true
			var ds := []
			for d in 4:
				if lv.wall(c.x, c.y, d) == 0 and lv.in_bounds(c.x + MazeLevel.DX[d], c.y + MazeLevel.DY[d]):
					ds.append(d)
			if ds.is_empty():
				break
			var d2: int = ds[rng.randi() % ds.size()]
			c = Vector2i(c.x + MazeLevel.DX[d2], c.y + MazeLevel.DY[d2])
	if z >= 3:
		for i in 2:
			var c := _corridor(lv, rng, start)
			lv.cells[c.y][c.x]["f"]["spin"] = true
	return lv


static func _corridor(lv: MazeLevel, rng: RandomNumberGenerator, start: Vector2i) -> Vector2i:
	for t in 200:
		var x := rng.randi_range(0, MazeLevel.N - 1)
		var y := rng.randi_range(0, MazeLevel.N - 1)
		var f: Dictionary = lv.cells[y][x]["f"]
		if lv.cells[y][x]["room"] == 0 and f.is_empty() and Vector2i(x, y) != start:
			return Vector2i(x, y)
	return start

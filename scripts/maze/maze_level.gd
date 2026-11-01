class_name MazeLevel
extends RefCounted
## One 20x20 level of the Maze. Walls are thin and stored per cell edge.
## Wall codes: 0 open, 1 wall, 2 door, 3 secret door.
## Directions: 0 north (+y), 1 east (+x), 2 south (-y), 3 west (-x). (0,0) is the south-west corner.

const N := 20
const DX := [0, 1, 0, -1]
const DY := [1, 0, -1, 0]
const DIR_NAMES := ["NORTH", "EAST", "SOUTH", "WEST"]

var z := 1
var cells: Array = []  # cells[y][x] = {w: [n,e,s,w], room: int, f: {flags}}
var down := Vector2i.ZERO


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < N and y < N


func cell(x: int, y: int) -> Variant:
	if not in_bounds(x, y):
		return null
	return cells[y][x]


func wall(x: int, y: int, d: int) -> int:
	var c = cell(x, y)
	return 1 if c == null else int(c["w"][d])


func set_wall(x: int, y: int, d: int, v: int) -> void:
	cells[y][x]["w"][d] = v
	var nx: int = x + DX[d]
	var ny: int = y + DY[d]
	if in_bounds(nx, ny):
		cells[ny][nx]["w"][(d + 2) % 4] = v


func flag(x: int, y: int, f: String) -> Variant:
	var c = cell(x, y)
	return null if c == null else c["f"].get(f)

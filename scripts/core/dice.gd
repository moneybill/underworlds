class_name Dice
## Dice and randomness helpers. Uses the global RNG (seed it with seed() for repeatable tests).


static func rnd(a: int, b: int) -> int:
	return randi_range(a, b)


static func chance(pct: float) -> bool:
	return randf() * 100.0 < pct


## Rolls dice notation such as "2d6+1" or "1d8-1". Never returns below zero.
static func roll(spec: String) -> int:
	var re := RegEx.create_from_string("^(\\d+)d(\\d+)([+-]\\d+)?$")
	var m := re.search(spec)
	if m == null:
		return int(spec)
	var total := 0
	for i in int(m.get_string(1)):
		total += randi_range(1, int(m.get_string(2)))
	if m.get_string(3) != "":
		total += int(m.get_string(3))
	return maxi(0, total)


static func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]

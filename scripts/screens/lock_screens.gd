class_name LockScreens
extends RefCounted
## The lockpicking game: the pattern is fixed from the start, so the player sets every pin up or down and
## guesses. Each STUDY says how many are wrong, but not which, and a character only gets so many.

const DOOR_SLOTS := 2
const MIN_STUDIES := 1
const FLASH_TIMES := 5  # how often a missed chest shows its pattern
const FLASH_LIT := 0.3  # seconds
const FLASH_DARK := 0.15
const BODY_HEIGHT := 160.0  # room for what the character says, so that saying it moves nothing
const CHEST_SIZES := {3: "small", 4: "medium", 5: "large"}  # slots -> the size of a chest with that many
const WRONG_WORDS := ["One tumbler", "Two tumblers", "Three tumblers", "Four tumblers"]  # how many don't seem right

var ui
var _pick := {}  # the lock being picked


func _init(root) -> void:
	ui = root


## Thieves and ninjas use their level. Anyone else may try, as a thief of level 0. A Shadow Hood adds to it.
static func thief_level(c: Character) -> int:
	return (c.lvl if c.cdata().get("thief", false) or c.cdata().get("ninja", false) else 0) + c.worn_bonus("pick")


## How many times this character may study a lock: (Luck + 2 x thief level) / 2 / 10, to the nearest
## whole number, and always at least once.
static func studies(c: Character) -> int:
	return maxi(roundi((c.stats["luk"] + 2 * thief_level(c)) / 2.0 / 10.0), MIN_STUDIES)


static func wrong_pins(pins: Array, solution: Array) -> int:
	var wrong := 0
	for i in pins.size():
		if pins[i] != solution[i]:
			wrong += 1
	return wrong


## What a study says about a setting.
static func study_message(wrong: int, slots: int) -> String:
	if wrong == 0:
		return "All tumblers seem right."
	if wrong == slots:
		return "All tumblers seem wrong."
	return WRONG_WORDS[wrong - 1] + (" doesn't seem right." if wrong == 1 else " don't seem right.")


static func random_solution(slots: int) -> Array:
	var out := []
	for i in slots:
		out.append(Dice.rnd(LockPins.UP, LockPins.DOWN))
	return out


## on_open is called with no arguments, on_fail and on_back likewise. state is kept with the lock, and holds
## how often it has been studied, so that walking away and coming back doesn't give more.
## With show_on_miss, a wrong try flashes the right pattern before on_fail.
func pick(c: Character, solution: Array, title: String, view: String, on_open: Callable, on_fail: Callable, on_back: Callable, state: Dictionary, show_on_miss := false) -> void:
	var pins: Array[int] = []
	pins.resize(solution.size())
	pins.fill(LockPins.NOT_SET)
	_pick = {"c": c, "solution": solution, "pins": pins, "title": title, "view": view, "open": on_open, "fail": on_fail, "back": on_back, "said": "", "state": state, "show_on_miss": show_on_miss, "missed": false}
	_show()


func _show() -> void:
	var lock := LockPins.new(_pick["pins"])
	lock.changed.connect(_pins_changed)
	var c: Character = _pick["c"]
	var left := _studies_left()
	var body: String = ui.flav("%s works at the lock. Click above or below the bar to set each pin." % ui.esc(c.name)) + "\nStudies left: %d" % left
	if _pick["said"] != "":
		body += "\n\n\"%s\"" % ui.esc(_pick["said"])
	var missed: bool = _pick["missed"]
	var ready: bool = lock.all_set() and not missed
	ui.show_screen({"title": _pick["title"], "view": _pick["view"], "widget": lock, "party_grid": true, "body": body, "body_height": BODY_HEIGHT, "opts": [
		{"k": "S", "label": "STUDY", "dis": not ready or left <= 0, "fn": _study},
		{"k": "T", "label": "TRY", "dis": not ready, "fn": _try},
		{"k": "L", "label": "BACK", "dis": missed, "fn": _pick["back"]},
	]})
	if missed:
		lock.flash(_pick["solution"], FLASH_TIMES, FLASH_LIT, FLASH_DARK, _pick["fail"])


func _pins_changed() -> void:
	_pick["said"] = ""
	_show.call_deferred()  # the lock that was clicked is still at work


func _studies_left() -> int:
	return maxi(studies(_pick["c"]) - int(_pick["state"].get("studied", 0)), 0)


func _study() -> void:
	if _studies_left() <= 0:
		return
	_pick["state"]["studied"] = int(_pick["state"].get("studied", 0)) + 1
	_pick["said"] = study_message(wrong_pins(_pick["pins"], _pick["solution"]), _pick["pins"].size())
	_show()


func _try() -> void:
	if _pick["pins"] == _pick["solution"]:
		_pick["open"].call()
	elif _pick["show_on_miss"]:
		_pick["missed"] = true
		_pick["said"] = "That's not it! This was the pattern..."
		_show()
	else:
		_pick["fail"].call()

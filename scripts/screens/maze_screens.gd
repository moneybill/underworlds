class_name MazeScreens
extends RefCounted
## Entering the Maze, camp, walking, stairs, graffiti, searching for lost parties, and wipe-outs.

const DOOR_NOISE_CHANCE := 0.25
const CAMP_BUTTON_SIZE := Vector2(190, 48)
const CAMP_CARD_BUTTONS := 30.0  # the row on a card for INSPECT and SWAP
const INSPECT_ICON := "res://assets/images/inspect.svg"
const NOTES_ICON := "res://assets/images/notes.svg"

var ui
var _door_states := {}  # door -> how often its lock has been studied
var _camp_pick: Character = null  # the one selected at camp
var _camp_swapping := false  # SWAP was pressed, so the next card clicked swaps places with them


func _init(root) -> void:
	ui = root


func enter_maze() -> void:
	ui.place_image = ""
	for c in Game.party_chars():
		c.loc = "MAZE"
		c.cac = 0
		c.reset_sp()
		c.maze_trips += 1
	Game.pos = {"x": 0, "y": 0, "z": 1, "d": 0}
	Game.light = 0
	Game.maporfic = 0
	Game.latumapic = false
	Game.cleared = {}
	Game.mark_seen()
	ui.clear_log()
	Game.say("YOU ARE AT THE FOOT OF THE LADDER TO THE CASTLE.")
	camp()


func camp() -> void:
	Game.mode = "camp"
	Game.save_game()
	var ps := Game.party_chars()
	if not ps.has(_camp_pick):
		_camp_pick = null
		_camp_swapping = false
	var opts := []
	for i in ps.size():
		opts.append({"k": str(i + 1), "label": ps[i].name, "in_widget": true, "fn": _camp_card.bind(ps[i])})
	opts.append({"k": "I", "label": "INSPECT", "in_widget": true, "hide": _camp_pick == null, "fn": _camp_inspect})
	opts.append({"k": "S", "label": "SWAP", "in_widget": true, "hide": _camp_pick == null, "fn": _camp_swap})
	opts.append({"k": "L", "label": "LEAVE CAMP", "under_view": CAMP_BUTTON_SIZE, "fn": _leave_camp})
	var hint := "Click a character to select them."
	if _camp_swapping:
		hint = "Click who %s swaps places with." % _camp_pick.name
	var cards := VBoxContainer.new()
	var hint_line := Label.new()
	hint_line.name = "Hint"
	hint_line.text = hint
	hint_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_line.add_theme_font_size_override("font_size", ui.GEAR_HINT_FONT)
	cards.add_child(hint_line)
	var grid := PartyCards.grid(_fill_camp_card, ps.find(_camp_pick), 3, _camp_card, true, 1.0, {}, true, true)
	grid.name = "Cards"
	cards.add_child(grid)
	ui.show_screen({"title": "Camp", "where": "Maze · Level %d" % Game.pos["z"], "view": "camp", "opts": opts,
		"widget": cards, "party_grid": true,
		"after_widget": ui.flav("Guards are posted and the fire is lit. No monster will trouble you while you stay in camp.")})


## Every card keeps room for the selected one's buttons, so that selecting someone moves nothing.
func _fill_camp_card(v: VBoxContainer, c: Character, _i: int) -> void:
	PartyCards.add_head(v, c, true)
	if c.status != "OK" and c.is_alive():
		ui.fight._add_state_badge(v.get_child(0), c.status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size.y = CAMP_CARD_BUTTONS
	v.add_child(row)
	if c != _camp_pick:
		return
	for spec in [["INSPECT", _camp_inspect], ["SWAP", _camp_swap]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		UiStyle.make_small_button(b)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(spec[1])
		row.add_child(b)
	if _camp_swapping:
		var swap_button: Button = row.get_node("SWAP")
		UiStyle.make_small_button(swap_button, UiStyle.C_TORCH, UiStyle.C_TORCH)  # waiting for the other one
		swap_button.add_theme_color_override("font_color", UiStyle.C_BG)


## Selects someone, or while swapping, swaps places with them.
func _camp_card(c: Character) -> void:
	if _camp_swapping and _camp_pick != null and c != _camp_pick:
		var a := Game.party.find(_camp_pick.id)
		var b := Game.party.find(c.id)
		Game.party[a] = c.id
		Game.party[b] = _camp_pick.id
		Game.say("%s AND %s SWAP PLACES." % [_camp_pick.name, c.name])
		_camp_swapping = false
	else:
		_camp_pick = c
		_camp_swapping = false
	camp()


func _camp_inspect() -> void:
	_camp_swapping = false
	ui.chars.inspect(_camp_pick, "camp", camp)


## Pressed again, it stops waiting.
func _camp_swap() -> void:
	_camp_swapping = not _camp_swapping
	camp()


## The window fades to black and back into the Maze.
func _leave_camp() -> void:
	_camp_pick = null
	_camp_swapping = false
	ui.view.fade_through_black(func():
		if Game.mode == "camp":  # unless the town button was pressed meanwhile
			maze())


func maze() -> void:
	Game.mode = "maze"
	Game.save_game()
	var p: Dictionary = Game.pos
	var dark = Game.level().flag(p["x"], p["y"], "dark")
	var fx := ""
	if Game.light > 0:
		fx += ("LOMILWA" if Game.light > 999 else "MILWA") + " ACTIVE · "
	if Game.maporfic > 0:
		fx += "MAPORFIC · "
	if Game.latumapic:
		fx += "LATUMAPIC · "
	ui.show_screen({"title": "In darkness" if dark else ("Lit corridor" if Game.light > 0 else "The Maze"), "where": fx + "Maze · Level %d" % p["z"],
		"view": "maze", "pad": true, "widget": ui.fight.explore_grid(), "party_grid": true, "opts_bottom": true,
		"moves": {"W": forward, "A": turn.bind(3), "D": turn.bind(1), "X": turn.bind(2)},
		"opts": [
			{"k": "C", "label": "CAMP", "small": true, "at": "right", "fn": camp},
			{"k": "I", "label": "INSPECT AREA", "in_widget": true, "tool": INSPECT_ICON, "fn": inspect_area},
			{"k": "M", "label": "MAP OFF" if Game.show_map else "MAP NOTES", "in_widget": true, "tool": NOTES_ICON, "fn": func(): Game.show_map = not Game.show_map; maze()},
		]})


func _pick_door(c: Character) -> void:
	var p: Dictionary = Game.pos
	var solution: Array = Game.door_solution(p["z"], p["x"], p["y"], p["d"], LockScreens.DOOR_SLOTS)
	var door: String = Game._door_id(p["z"], p["x"], p["y"], p["d"])
	if not _door_states.has(door):
		_door_states[door] = {}
	ui.lock.pick(c, solution, "A locked door", "maze", _door_picked.bind(c), _door_jammed.bind(c), maze, _door_states[door])


func _door_picked(c: Character) -> void:
	var p: Dictionary = Game.pos
	Game.open_door(p["z"], p["x"], p["y"], p["d"])
	Game.say("%s PICKS THE LOCK!" % c.name, "ok")
	maze()


## A wrong try makes a noise, which something may come to see about.
func _door_jammed(c: Character) -> void:
	Game.say("THE PINS RATTLE AND THE LOCK HOLDS.", "hit")
	if Game.monsters_on and randf() < DOOR_NOISE_CHANCE:
		Game.say("SOMETHING HEARD THAT!", "hit")
		ui.fight.encounter(false, false)
		return
	_pick_door(c)


func turn(k: int) -> void:
	Game.pos["d"] = (Game.pos["d"] + k) % 4
	ui.view.queue_redraw()


func forward() -> void:
	var p: Dictionary = Game.pos
	var lv := Game.level()
	var w := lv.wall(p["x"], p["y"], p["d"])
	if w == 1:
		Game.say("OUCH!")
		return
	if w == 2 and not Game.door_open(p["z"], p["x"], p["y"], p["d"]):
		if Game.door_locked(p["z"], p["x"], p["y"], p["d"]):
			Game.say("THE DOOR IS LOCKED.")
			ui.pick_member("Who picks the lock?", maze, _pick_door, func(c): return c.can_act())
			return
		Game.open_door(p["z"], p["x"], p["y"], p["d"])
		Game.say("THE DOOR CREAKS OPEN.")
	if w == 3:
		Game.say("YOU STUMBLE THROUGH A HIDDEN DOOR!", "mag")
		lv.cell(p["x"], p["y"])["f"]["k%d" % p["d"]] = true
		Game.open_door(p["z"], p["x"], p["y"], p["d"])
	p["x"] += MazeLevel.DX[p["d"]]
	p["y"] += MazeLevel.DY[p["d"]]
	Game.mark_seen()
	if Game.light > 0 and Game.light < 999:
		Game.light -= 1
	for c in Game.party_chars():
		if c.status == "POISON" and randf() < 0.5:
			Game.hurt(c, 1)
			if c.hp <= 0:
				c.hp = 0
				c.status = "DEAD"
				Game.say("%s SUCCUMBS TO POISON!" % c.name, "hit")
		if c.is_alive() and c.hp < c.maxhp and c.items.any(func(it): return c.item_def(it).has("regen")):
			c.hp += 1
	if Game.living().is_empty():
		wiped()
		return
	if lv.flag(p["x"], p["y"], "spin"):
		p["d"] = Dice.rnd(0, 3)
	var msg = lv.flag(p["x"], p["y"], "msg")
	if msg != null:
		maze()
		ui.say("Graffiti", Data.GRAFFITI[p["z"]][int(msg) - 1], _after_step)
		return
	_after_step()


func _after_step() -> void:
	var p: Dictionary = Game.pos
	var lv := Game.level()
	var x: int = p["x"]
	var y: int = p["y"]
	var lair = lv.flag(x, y, "lair")
	var key := "%d:%d" % [p["z"], 0 if lair == null else int(lair)]
	if Game.monsters_on:
		if lv.flag(x, y, "boss") and not Game.cleared.has("boss"):
			ui.fight.encounter(false, true)
			return
		if lair != null and not Game.cleared.has(key):
			Game.cleared[key] = true
			ui.fight.encounter(true, false)
			return
		if randf() < 0.035 + p["z"] * 0.006:
			ui.fight.encounter(false, false)
			return
	if lv.flag(x, y, "up"):
		ui.yesno("Ladder going up", "This ladder leads back to the Castle. Climb it?" if p["z"] == 1 else "Climb the ladder up?", _go_up, maze)
		ui.view.show_view("maze")
		return
	if lv.flag(x, y, "down"):
		ui.yesno("Ladder going down", "Climb down the ladder, deeper into the Maze?", _go_down, maze)
		ui.view.show_view("maze")
		return
	maze()


func _go_up() -> void:
	if Game.pos["z"] == 1:
		ui.town.return_to_castle()
		return
	Game.pos["z"] -= 1
	Game.mark_seen()
	Game.say("YOU CLIMB TO LEVEL %d." % Game.pos["z"])
	maze()


func _go_down() -> void:
	Game.pos["z"] += 1
	Game.mark_seen()
	Game.say("YOU DESCEND TO LEVEL %d." % Game.pos["z"])
	maze()


## Looks for stranded adventurers on this square or the squares next to it.
func inspect_area() -> void:
	var p: Dictionary = Game.pos
	var found := []
	for o in Game.outs:
		var q: Dictionary = o["pos"]
		if q["z"] == p["z"] and absi(q["x"] - p["x"]) + absi(q["y"] - p["y"]) <= 1:
			for cid in o["ids"]:
				var c := Game.ch(cid)
				if c != null and c.loc == "OUT":
					found.append(c)
	if found.is_empty():
		Game.say("YOU SEARCH THE AREA BUT FIND NO ONE.")
		return
	var items := []
	for c in found:
		items.append({"label": c.name, "right": c.status, "dis": Game.party.size() >= 6 or not Game.compatible(c), "fn": _rescue.bind(c)})
	ui.choose_list("You found adventurers!", ui.flav("Choose who to bring along. You need room in the party."), items, maze)


func _rescue(c: Character) -> void:
	Game.party.append(c.id)
	c.loc = "MAZE"
	for o in Game.outs:
		o["ids"].erase(c.id)
	Game.outs = Game.outs.filter(func(o): return o["ids"].any(func(cid): return Game.ch(cid) != null and Game.ch(cid).loc == "OUT"))
	Game.save_game()
	Game.say("%s JOINS YOUR PARTY." % c.name, "ok")
	inspect_area()


func wiped() -> void:
	Game.outs.append({"ids": Game.party.duplicate(), "pos": Game.pos.duplicate()})
	for c in Game.party_chars():
		c.loc = "OUT"
	Game.party.clear()
	Game.mode = "castle"
	Game.save_game()
	ui.say("Your party is wiped out", "The whole party lies dead in the Maze. Their bodies stay where they fell.\n\n" +
		ui.flav("Send a rescue party to that spot and use INSPECT AREA to carry them home to the Cathedral."), ui.town.castle, "Castle")

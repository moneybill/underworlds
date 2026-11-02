class_name MazeScreens
extends RefCounted
## Entering the Maze, camp, walking, stairs, graffiti, searching for lost parties, and wipe-outs.

var ui


func _init(root) -> void:
	ui = root


func enter_maze() -> void:
	for c in Game.party_chars():
		c.loc = "MAZE"
		c.cac = 0
		c.reset_sp()
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
	var opts := []
	for i in ps.size():
		opts.append({"k": str(i + 1), "label": ps[i].name, "fn": ui.chars.inspect.bind(ps[i], "camp", camp)})
	opts.append({"k": "R", "label": "REORDER", "fn": reorder.bind([])})
	opts.append({"k": "E", "label": "EQUIP", "fn": _equip_all.bind(0)})
	opts.append({"k": "L", "label": "LEAVE CAMP", "fn": maze})
	ui.show_screen({"title": "Camp", "where": "Maze · Level %d" % Game.pos["z"], "view": "camp", "opts": opts,
		"body": ui.flav("Guards are posted and the fire is lit. No monster will trouble you while you stay in camp.")})


func _equip_all(i: int) -> void:
	var ps := Game.party_chars()
	if i >= ps.size():
		camp()
	else:
		ui.chars.equip_flow(ps[i], _equip_all.bind(i + 1), ["W", "A", "S", "H"])


func reorder(picked: Array) -> void:
	var rest := Game.party_chars().filter(func(c): return not picked.has(c.id))
	if rest.is_empty():
		Game.party.clear()
		for cid in picked:
			Game.party.append(cid)
		Game.save_game()
		camp()
		return
	var items := []
	for c in rest:
		items.append({"label": c.name, "right": "%s-%s" % [c.align.substr(0, 1), c.cdata()["ab"]], "fn": reorder.bind(picked + [c.id])})
	ui.choose_list("Who goes in position %d?" % (picked.size() + 1), ui.flav("Only the first three can fight with weapons, and only they can be struck in melee."), items, camp)


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
	ui.show_screen({"title": "In darkness" if dark else ("Lit corridor" if Game.light > 0 else "The Maze"), "where": "Maze · Level %d" % p["z"],
		"view": "maze", "pad": true, "body": fx + "USE THE ARROWS TO MOVE",
		"moves": {"W": forward, "A": turn.bind(3), "D": turn.bind(1), "X": turn.bind(2)},
		"opts": [
			{"k": "C", "label": "CAMP", "fn": camp},
			{"k": "S", "label": "STATUS", "fn": _status},
			{"k": "I", "label": "INSPECT AREA", "fn": inspect_area},
			{"k": "M", "label": "MAP OFF" if Game.show_map else "MAP NOTES", "fn": func(): Game.show_map = not Game.show_map; maze()},
			{"k": "Q", "label": "QUIT", "fn": func(): ui.yesno("Quit the expedition?", "The party stays where it is, marked OUT. Restart it later from Utilities at the Edge of Town. Light and shield spells are forgotten.", _quit, maze)},
		]})


func _status() -> void:
	ui.render_party()
	Game.say(" · ".join(Game.party_chars().map(func(c): return "%s %d/%d %s" % [c.name, c.hp, c.maxhp, c.status])))


func _quit() -> void:
	Game.outs.append({"ids": Game.party.duplicate(), "pos": Game.pos.duplicate()})
	for c in Game.party_chars():
		c.loc = "OUT"
	Game.party.clear()
	Game.mode = "castle"
	Game.save_game()
	ui.town.castle()


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
	ui.say("Your party is wiped out", "The whole party lies dead in the Maze. Their bodies stay where they fell, marked OUT.\n\n" +
		ui.flav("Send a rescue party to that spot and use INSPECT AREA to carry them home to the Temple."), ui.town.castle, "Castle")

extends Node
## The self-test body. Loaded by tools/selftest.gd after the autoloads are registered.

var main
var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func press(k: String) -> bool:
	for o in main.scr.get("opts", []):
		if String(o["k"]).to_upper() == k.to_upper() and not o.get("hide", false) and not o.get("dis", false):
			main._run(o)
			return true
	return false


func run() -> int:
	seed(20261101)
	var last := []
	get_node("/root/Game").logged.connect(func(t, _k): last.append(t); if last.size() > 25: last.pop_front())
	var g = get_node("/root/Game")
	g.save_path = "user://selftest_save.json"
	if FileAccess.file_exists(g.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(g.save_path))
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	check(main.scr.get("title", "") == "Welcome to the Proving Grounds", "welcome screen on a fresh roster")

	# --- a Hawkwind party ---
	var specs := [["DERF", "DWARF", "GOOD", {"str": 11, "agi": 9}, "FIGHTER"], ["THOMAS", "HUMAN", "GOOD", {"str": 12}, "FIGHTER"],
		["SEBASTION", "GNOME", "GOOD", {"pie": 12}, "PRIEST"], ["SNATCH", "HOBBIT", "NEUTRAL", {"agi": 12}, "THIEF"],
		["ALFREDO", "ELF", "GOOD", {"iq": 12}, "MAGE"], ["GABRIELLA", "ELF", "GOOD", {"iq": 12}, "MAGE"]]
	var party := []
	for s in specs:
		var st: Dictionary = Data.RACES[s[1]].duplicate()
		st.merge(s[3], true)
		var c = g.make_char(s[0], s[1], s[2], st, s[4])
		party.append(c)
		check(Character.eligible(st, s[2]).has(s[4]), "%s qualifies as %s" % [s[0], s[4]])
	check(party[4].spells.size() >= 1 and party[4].sp["M"][0] >= 2, "level 1 mage knows a spell and has 2+ points")
	check(party[2].spells.has("DIOS") or party[2].spells.size() > 0, "level 1 priest knows spells")

	# --- creation screens ---
	print("creation screens")
	main.chars.create_name()
	main._on_input_submitted("NEWBIE")
	press("1")  # HUMAN
	press("G")
	check(main.scr["title"].begins_with("NEWBIE"), "bonus point screen")
	for i in 30:
		main.scr["keys"]["Right"].call()
		main.scr["keys"]["Down"].call()
	press("Q")

	# --- town ---
	print("town")
	for c in party:
		g.party.append(c.id)
	main.town.tavern()
	press("1")
	check(main.scr["title"] == "Inspect", "inspect from the tavern")
	press("L")
	main.town.shop(party[0])
	press("B")
	press("F")
	press("B")
	main.town.buy(party[0], 0)
	press("4")  # LONG SWORD
	check(party[0].items.size() == 1, "bought a sword (got %d items)" % party[0].items.size())
	main.town.shop(party[4])
	press("P")  # pool gold lambda
	check(party[4].gold > 100, "pooled gold")
	g.divvy()
	for c in party:
		c.add_item("staff", true)
		c.add_item("robes", true)
		main.chars.equip_flow(c, func(): pass, ["W", "A", "S", "H"])
		for guard in 8:
			if not main.scr.get("title", "").begins_with("Equip"):
				break
			press("1")
	check(party[1].equipped("W") != null, "equip flow equips a weapon")
	main.town.sell(party[5])
	press("1")
	press("Y")
	party[5].status = "DEAD"
	main.town.temple()
	press("1")
	press("1")  # payer
	check(main.scr["title"] == "Temple of Cant", "temple tithe resolves (bind order)")
	party[5].status = "OK"
	party[5].hp = party[5].maxhp
	party[0].xp = 5000
	main.town.inn_rooms(party[0])
	press("1")
	check(party[0].lvl >= 2, "inn level-up")
	main.town.edge_of_town()
	press("U")
	press("L")

	# --- the Maze ---
	print("the Maze")
	main.mz.enter_maze()
	check(g.mode == "camp", "enter maze lands in camp")
	press("L")
	var fights := 0
	var steps := 0
	for i in 6000:
		if g.party.is_empty():
			print("party wiped after %d steps" % steps)
			print("\n".join(last))
			break
		if main.fight.battle != null and g.mode == "combat" and main.scr.get("title", "").ends_with("options"):
			fights += 1
			var b = main.fight.battle
			b.cmds = []
			var ps = g.party_chars()
			for k in ps.size():
				var c = ps[k]
				if not c.can_act():
					continue
				var sp = b.combat_spells(c)
				if not sp.is_empty() and randf() < 0.5:
					b.cmds.append({"c": c, "type": "spell", "n": sp[0], "t": b.alive_groups()[0] if Data.SPELLS[sp[0]][3] in ["mon", "grp"] else c})
				elif k < 3:
					b.cmds.append({"c": c, "type": "fight", "g": b.alive_groups()[0]})
				else:
					b.cmds.append({"c": c, "type": "parry"})
			main.fight._after(b.play_round(false))
			for c in g.party_chars():
				if c.is_alive() and c.hp < c.maxhp / 2:
					c.hp = c.maxhp  # keep the test party alive longer
			continue
		if not main.fight.chest.is_empty() and main.scr.get("title", "") == "A chest!":
			press("I")
			press("1")
			if not main.fight.chest.is_empty():
				press("O")
				press("4")
			continue
		var keys: Dictionary = main.scr.get("keys", {})
		if keys.has("W"):
			var k: String = ["W", "W", "W", "A", "D"][randi() % 5]
			keys[k].call()
			steps += 1
			for c in g.party_chars():
				if c.hp < c.maxhp / 2 and c.is_alive():
					c.hp = c.maxhp  # keep the test party alive longer
			continue
		if main.scr.get("title", "") == "A friendly group":
			press("L")
			continue
		if not press("Enter") and not press("N") and not press("L"):
			print("stuck on screen: ", main.scr.get("title"))
			break
	print("steps %d, fights %d, mode %s, pos %s" % [steps, fights, g.mode, g.pos])
	check(fights > 0, "at least one fight happened")

	# --- boss ---
	print("boss")
	g.party.clear()
	for c in party:
		c.status = "OK"
		c.loc = "MAZE"
		c.lvl = 12
		c.maxhp = 120
		c.hp = 120
		g.party.append(c.id)
	g.pos = {"x": 0, "y": 0, "z": 4, "d": 0}
	main.fight.encounter(false, true)
	var rounds := 0
	while main.fight.battle != null and rounds < 60:
		rounds += 1
		var b = main.fight.battle
		b.cmds = []
		for c in g.party_chars():
			if c.can_act():
				b.cmds.append({"c": c, "type": "fight", "g": b.alive_groups()[0]})
		main.fight._after(b.play_round(false))
	print("boss fight rounds: %d" % rounds)

	print("boss victory path")
	g.party.clear()
	for c in party:
		c.status = "OK"
		c.hp = c.maxhp
		c.loc = "MAZE"
		g.party.append(c.id)
	g.cleared.erase("boss")
	main.fight.encounter(false, true)
	for gp in main.fight.battle.groups:
		for m in gp["ms"]:
			m["hp"] = 1
			m["asleep"] = true
	var b2 = main.fight.battle
	b2.cmds = []
	for c in g.party_chars():
		b2.cmds.append({"c": c, "type": "fight", "g": 0})
	main.fight._after(b2.play_round(false))
	if main.fight.battle != null:
		b2.cmds = []
		for c in g.party_chars():
			b2.cmds.append({"c": c, "type": "fight", "g": b2.alive_groups()[0]})
		main.fight._after(b2.play_round(false))
	check(g.party_chars().any(func(c): return c.items.any(func(it): return it["id"] == "amulet")), "Werdna drops the amulet")
	check(main.scr.get("title", "") == "A chest!", "boss leaves a chest")
	press("O")
	press("1")
	main.town.return_to_castle()
	check(g.won and main.scr.get("title", "") == "The Amulet returns", "returning with the amulet wins the game")

	# --- save / load ---
	print("save / load")
	var n: int = g.roster.size()
	g.save_game()
	g.load_game()
	check(g.roster.size() == n, "save/load keeps the roster")

	print("SELFTEST DONE, failures: %d" % failures)
	return failures

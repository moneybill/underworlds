class_name CombatScreens
extends RefCounted
## Combat orders (Fight, Parry, Dispell, Spell, Use, Run, Take back), friendly encounters,
## and treasure chests with their traps.

var ui
var battle: Battle = null
var chest: Dictionary = {}


func _init(root) -> void:
	ui = root


func _where() -> String:
	return "Maze · Level %d" % Game.pos["z"]


func encounter(is_lair: bool, is_boss: bool) -> void:
	battle = Battle.new()
	battle.setup(is_lair, is_boss)
	ui.view.battle = battle
	Game.mode = "combat"
	ui.clear_log()
	if battle.is_friendly():
		_friendly()
		return
	if is_boss:
		Game.say("A COLD VOICE: \"SO, TREBOR SENDS CHILDREN NOW.\"", "hit")
	var r := randf()
	if not is_boss and r < 0.12:
		battle.surprise = "party"
		Game.say("YOU SURPRISED THE MONSTERS! NO TIME FOR SPELLS.", "ok")
	elif r > 0.88:
		battle.surprise = "mon"
		Game.say("THE MONSTERS SURPRISED YOU!", "hit")
		_after(battle.play_round(true))
		return
	start_round()


func _friendly() -> void:
	var gp: Dictionary = battle.groups[0]
	var n := battle.live(gp).size()
	ui.show_screen({"title": "A friendly group", "where": _where(), "view": "combat",
		"body": "A friendly group of %d %s. They hail you in welcome!\n\n" % [n, battle.gname(gp, n)] + ui.flav("How you answer a peaceful greeting may change you."),
		"opts": [{"k": "F", "label": "FIGHT", "fn": _attack_friends}, {"k": "L", "label": "LEAVE IN PEACE", "def": true, "fn": _leave_in_peace}]})


func _attack_friends() -> void:
	for c in Game.party_chars():
		if c.align == "GOOD" and randf() < 0.25:
			c.align = "EVIL"
			Game.say("%s FEELS A DARKNESS SETTLE IN. (NOW EVIL)" % c.name, "hit")
	start_round()


func _leave_in_peace() -> void:
	for c in Game.party_chars():
		if c.align == "EVIL" and randf() < 0.1:
			c.align = "GOOD"
			Game.say("%s FEELS STRANGELY WARM INSIDE. (NOW GOOD)" % c.name, "ok")
	_done()
	ui.mz.maze()


func _done() -> void:
	battle = null
	ui.view.battle = null


# ---------- orders ----------
func start_round() -> void:
	battle.round_no += 1
	battle.cmds = []
	next_cmd(0)


func groups_text() -> String:
	var t := ""
	for i in battle.groups.size():
		var gp: Dictionary = battle.groups[i]
		var l := battle.live(gp)
		if l.is_empty():
			continue
		var sl := l.filter(func(m): return m["asleep"]).size()
		var pa := l.filter(func(m): return m["para"]).size()
		t += "%d) %d %s [color=#9c947f](%d ACTIVE%s%s)[/color]\n" % [i + 1, l.size(), battle.gname(gp, l.size()), l.size() - sl - pa,
			", %d ASLEEP" % sl if sl > 0 else "", ", %d PARALYZED" % pa if pa > 0 else ""]
	return t


func next_cmd(i: int) -> void:
	var ps := Game.party_chars()
	while i < ps.size() and not ps[i].can_act():
		i += 1
	if i >= ps.size():
		_confirm()
		return
	var c: Character = ps[i]
	var front := i < 3
	var again := next_cmd.bind(i)
	var no_magic := battle.surprise == "party" and battle.round_no == 1
	var undead := battle.alive_groups().filter(func(g): return Data.MONS[battle.groups[g]["id"]].get("undead", false))
	var usable := c.items.filter(func(it): return c.item_def(it).has("spell") and not it.get("broken", false) and "CA".contains(Data.SPELLS[c.item_def(it)["spell"]][2]))
	ui.show_screen({"title": "%s's options" % c.name, "where": _where(), "view": "combat", "body": groups_text(), "opts": [
		{"k": "F", "label": "FIGHT", "hide": not front, "def": front, "fn": _choose_group.bind(battle.alive_groups().slice(0, 2), _order.bind(i, c, "fight"), again)},
		{"k": "P", "label": "PARRY", "def": not front, "fn": _push.bind(i, {"c": c, "type": "parry"})},
		{"k": "D", "label": "DISPELL", "hide": not battle.can_dispel(c), "dis": undead.is_empty() or no_magic, "fn": _choose_group.bind(undead, _order.bind(i, c, "dispel"), again)},
		{"k": "S", "label": "SPELL", "hide": c.spells.is_empty(), "dis": no_magic or battle.combat_spells(c).is_empty(), "fn": _pick_spell.bind(i, c)},
		{"k": "U", "label": "USE", "dis": usable.is_empty() or no_magic, "fn": _pick_item.bind(i, c, usable)},
		{"k": "R", "label": "RUN", "fn": func(): _after(battle.resolve(true))},
		{"k": "T", "label": "TAKE BACK", "hide": battle.cmds.is_empty(), "fn": func(): battle.cmds = []; next_cmd(0)},
	]})


func _push(i: int, order: Dictionary) -> void:
	battle.cmds.append(order)
	next_cmd(i + 1)


func _order(g: int, i: int, c: Character, type: String) -> void:
	_push(i, {"c": c, "type": type, "g": g})


func _choose_group(list: Array, fn: Callable, back: Callable) -> void:
	if list.size() == 1:
		fn.call(list[0])
		return
	var items := []
	for g in list:
		var gp: Dictionary = battle.groups[g]
		var n := battle.live(gp).size()
		items.append({"label": "%d %s" % [n, battle.gname(gp, n)], "fn": fn.bind(g)})
	ui.choose_list("Which group?", groups_text(), items, back)


func _target_for(n: String, fn: Callable, back: Callable) -> void:
	var t: String = Data.SPELLS[n][3]
	if t == "mon" or t == "grp":
		_choose_group(battle.alive_groups(), fn, back)
	elif t == "ally":
		ui.pick_member("On whom?", back, fn)
	else:
		fn.call(null)


func _pick_spell(i: int, c: Character) -> void:
	var items := []
	for n in battle.combat_spells(c):
		var d: Array = Data.SPELLS[n]
		items.append({"label": n, "right": "%s %d · %s" % ["MAGE" if d[0] == "M" else "PRIEST", d[1], d[4]],
			"fn": _target_for.bind(n, func(t): _push(i, {"c": c, "type": "spell", "n": n, "t": t}), next_cmd.bind(i))})
	ui.choose_list("%s casts" % c.name, "MAGE %s · PRIEST %s" % ["/".join(c.sp["M"].map(func(v): return str(v))), "/".join(c.sp["P"].map(func(v): return str(v)))], items, next_cmd.bind(i))


func _pick_item(i: int, c: Character, usable: Array) -> void:
	var items := []
	for it in usable:
		var n: String = c.item_def(it)["spell"]
		items.append({"label": c.item_name(it), "fn": _target_for.bind(n, func(t): _push(i, {"c": c, "type": "use", "item": it, "n": n, "t": t}), next_cmd.bind(i))})
	ui.choose_list("Use which item?", "", items, next_cmd.bind(i))


func _confirm() -> void:
	ui.show_screen({"title": "Ready?", "where": _where(), "view": "combat", "body": groups_text() + "\nPress ENTER to fight, or take back your orders.", "opts": [
		{"k": "Enter", "label": "FIGHT!", "def": true, "fn": func(): ui.clear_log(); _after(battle.play_round(false))},
		{"k": "T", "label": "TAKE BACK", "esc": true, "fn": func(): battle.cmds = []; next_cmd(0)},
	]})


func _after(result: String) -> void:
	Game.save_game()
	match result:
		"fled":
			Game.pos["d"] = (Game.pos["d"] + 2) % 4
			_done()
			ui.mz.maze()
		"wiped":
			_done()
			ui.mz.wiped()
		"victory":
			_victory()
		_:
			start_round()


func _victory() -> void:
	var gold := battle.award()
	var z: int = Game.pos["z"]
	var was_boss := battle.boss
	var was_lair := battle.lair
	_done()
	if was_boss:
		Game.cleared["boss"] = true
		var surv := Game.living()
		var holder: Character = surv[0]
		for c in surv:
			if c.items.size() < 8:
				holder = c
				break
		holder.items.append({"id": "amulet", "eq": false, "known": true, "cursed": false, "bad": false, "broken": false, "ch": 0})
		Game.say("%s TAKES WERDNA'S AMULET!" % holder.name, "gold")
	if was_boss or was_lair or randf() < 0.4:
		open_chest(gold * 2 + Dice.rnd(10, 40) * z, was_boss)
	else:
		Game.split_gold(gold)
		ui.mz.maze()


# ---------- treasure chests ----------
func open_chest(gold: int, boss_chest: bool) -> void:
	var z: int = Game.pos["z"]
	var item := ""
	if boss_chest:
		item = "cusinart"
	elif randf() < 0.35 + 0.1 * z:
		item = Dice.pick(Data.LOOT[z])
	chest = {"trap": 0 if randf() < 0.15 else Dice.rnd(1, mini(6, 3 + z)), "gold": gold, "item": item}
	chest_menu()


func chest_menu() -> void:
	var who := func(title: String, fn: Callable): ui.pick_member(title, chest_menu, fn, func(c): return c.can_act())
	ui.show_screen({"title": "A chest!", "where": _where(), "view": "chest",
		"body": ui.flav("The monsters were guarding a treasure chest. Chests are usually trapped, and this is the moment your thief earns his share."),
		"opts": [
			{"k": "O", "label": "OPEN", "fn": func(): who.call("Who opens it?", _open)},
			{"k": "I", "label": "INSPECT", "fn": func(): who.call("Who inspects it?", _inspect)},
			{"k": "C", "label": "CALFO", "fn": func(): who.call("Who casts CALFO?", _calfo)},
			{"k": "D", "label": "DISARM", "fn": func(): who.call("Who disarms it?", _disarm)},
			{"k": "L", "label": "LEAVE", "esc": true, "fn": func(): Game.say("YOU LEAVE THE CHEST ALONE."); chest = {}; ui.mz.maze()},
		]})


func _deft(c: Character) -> bool:
	return c.cdata().get("thief", false) or c.cdata().get("ninja", false)


func _open(c: Character) -> void:
	if chest["trap"] > 0:
		_spring(c)
	else:
		_loot()


func _inspect(c: Character) -> void:
	if Dice.chance(3 if _deft(c) else 10):
		Game.say("%s FUMBLES WITH THE LOCK..." % c.name, "hit")
		_spring(c)
		return
	var pct: float = (55 + c.lvl * 4 + (c.stats["agi"] - 10) * 3) if _deft(c) else (15 + (c.stats["agi"] - 10) * 2)
	var guess: String = Data.TRAPS[chest["trap"]]
	if not Dice.chance(pct):
		var wrong := Data.TRAPS.filter(func(t): return t != guess)
		guess = Dice.pick(wrong)
	Game.say("%s THINKS IT IS A %s." % [c.name, guess])
	chest_menu()


func _calfo(c: Character) -> void:
	if not c.can_cast("CALFO"):
		Game.say("%s CANNOT CAST CALFO NOW." % c.name)
		chest_menu()
		return
	c.spend("CALFO")
	Game.say("%s CASTS CALFO. THE CHEST IS A %s." % [c.name, Data.TRAPS[chest["trap"]] if randf() < 0.95 else Dice.pick(Data.TRAPS)], "mag")
	chest_menu()


func _disarm(c: Character) -> void:
	ui.show_screen({"title": "Disarm", "view": "chest",
		"body": "%s studies the lock. Type the name of the trap. Spelling counts.\n[color=#9c947f]%s[/color]" % [ui.esc(c.name), " · ".join(Data.TRAPS)],
		"input": {"ph": "TRAP NAME", "max": 20, "fn": func(v): _try_disarm(c, v)}, "opts": [{"k": "Escape", "label": "LEAVE", "esc": true, "fn": chest_menu}]})


func _try_disarm(c: Character, v: String) -> void:
	if v == Data.TRAPS[chest["trap"]]:
		if chest["trap"] == 0:
			Game.say("THE CHEST WAS NOT TRAPPED.", "ok")
			_loot()
			return
		var pct: float = (50 + c.lvl * 5 + (c.stats["agi"] - 10) * 3) if _deft(c) else (10 + (c.stats["agi"] - 10) * 2)
		if Dice.chance(pct):
			Game.say("%s DISARMED THE TRAP!" % c.name, "ok")
			_loot()
		elif randf() < 0.3:
			Game.say("%s IS A SHADE TOO CLUMSY..." % c.name, "hit")
			_spring(c)
		else:
			Game.say("FAILED TO DISARM IT. THE TRAP IS STILL SET.")
			chest_menu()
		return
	if randf() < 0.5:
		Game.say("WRONG TRAP!", "hit")
		_spring(c)
	else:
		Game.say("NOTHING HAPPENS. YOU ARE NOT SURE THAT WAS RIGHT.")
		chest_menu()


func _poison(t: Character) -> void:
	if t.status == "OK":
		t.status = "POISON"
		Game.say("%s IS POISONED!" % t.name, "hit")


func _hurt(t: Character, d: int) -> void:
	Game.say("%s TAKES %d DAMAGE." % [t.name, d], "hit")
	t.hp -= d
	if t.hp <= 0:
		t.hp = 0
		t.status = "DEAD"
		Game.say("%s IS KILLED!" % t.name, "hit")


func _spring(c: Character) -> void:
	var z: int = Game.pos["z"]
	Game.say("OOPS! A %s!" % Data.TRAPS[chest["trap"]], "hit")
	match int(chest["trap"]):
		1: _poison(c)
		2:
			for t in Game.living():
				if randf() * 22.0 >= t.stats["luk"] / 2.0:
					_poison(t)
		3: _hurt(c, Dice.roll("%dd8" % z))
		4:
			for t in Game.living():
				var d := Dice.roll("%dd6" % z)
				if randf() * 22.0 < t.stats["luk"] / 2.0:
					d = int(ceil(d / 2.0))
				_hurt(t, d)
		5:
			if c.is_alive():
				c.status = "PARALYZED"
				Game.say("%s IS PARALYZED!" % c.name, "hit")
		6:
			var lv := Game.level()
			var x := 0
			var y := 0
			while true:
				x = Dice.rnd(0, MazeLevel.N - 1)
				y = Dice.rnd(0, MazeLevel.N - 1)
				if not lv.flag(x, y, "boss"):
					break
			Game.pos["x"] = x
			Game.pos["y"] = y
			Game.pos["d"] = Dice.rnd(0, 3)
			Game.mark_seen()
			chest = {}
			Game.save_game()
			ui.view.show_view("maze")
			ui.say("Teleported!", "The world spins. You are somewhere else on this level, and the chest is gone.", ui.mz.maze)
			return
	if Game.living().is_empty():
		ui.mz.wiped()
		return
	_loot()


func _loot() -> void:
	var c := chest
	chest = {}
	Game.split_gold(c["gold"])
	if c["item"] != "":
		var who: Character = null
		for o in Game.living():
			if o.items.size() < 8:
				who = o
				break
		if who != null:
			who.add_item(c["item"], false)
			Game.say("%s FOUND A %s?" % [who.name, Data.ITEMS[c["item"]]["unk"]], "gold")
		else:
			Game.say("YOUR PACKS ARE FULL. THE TREASURE STAYS BEHIND.")
	Game.save_game()
	ui.mz.maze()

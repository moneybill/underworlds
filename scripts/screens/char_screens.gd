class_name CharScreens
extends RefCounted
## Character screens: inspecting (spell books, equip, drop, trade, identify, camp spells),
## the Training Grounds, character creation, and class changes.

var ui


func _init(root) -> void:
	ui = root


# ---------- inspect ----------
func inspect(c: Character, from: String, back: Callable) -> void:
	var camp := from == "camp"
	var can := camp or from == "tavern"
	var again := inspect.bind(c, from, back)
	ui.show_screen({"title": "Inspect", "body": ui.sheet(c), "opts": [
		{"k": "R", "label": "READ", "fn": read_books.bind(c, again)},
		{"k": "D", "label": "DROP", "hide": not can, "fn": drop_item.bind(c, again)},
		{"k": "P", "label": "POOL GOLD", "hide": not can, "fn": _pool.bind(c, again)},
		{"k": "I", "label": "IDENTIFY", "hide": not can or not c.cdata().get("ident", false), "fn": bishop_identify.bind(c, again)},
		{"k": "E", "label": "EQUIP", "hide": not can, "fn": equip_flow.bind(c, again, ["W", "A", "S", "H"])},
		{"k": "T", "label": "TRADE", "hide": not can or Game.party.size() < 2, "fn": trade.bind(c, again)},
		{"k": "S", "label": "SPELL", "hide": not camp, "dis": not c.can_act(), "fn": camp_spell.bind(c, again)},
		{"k": "U", "label": "USE", "hide": not camp, "dis": not c.can_act(), "fn": camp_use.bind(c, again)},
		{"k": "L", "label": "LEAVE", "esc": true, "def": true, "fn": back},
	]})


func _pool(c: Character, back: Callable) -> void:
	Game.pool_gold(c)
	Game.say("%s NOW HOLDS %d GOLD." % [c.name, c.gold], "gold")
	back.call()


func read_books(c: Character, back: Callable) -> void:
	var t := ""
	for school in ["M", "P"]:
		t += "[color=#e3a33f]%s SPELLS[/color]\n" % ("MAGE" if school == "M" else "PRIEST")
		var known: Array = c.spells.filter(func(n): return Data.SPELLS[n][0] == school)
		known.sort_custom(func(a, b): return Data.SPELLS[a][1] < Data.SPELLS[b][1])
		if known.is_empty():
			t += "[color=#9c947f]NO SPELLS[/color]\n"
		for n in known:
			t += "%d %s [color=#9c947f]%s[/color]\n" % [Data.SPELLS[n][1], n, Data.SPELLS[n][4]]
		t += "\n"
	ui.say("Spell books", t, back)


func drop_item(c: Character, back: Callable) -> void:
	var items := []
	for it in c.items:
		items.append({"label": c.item_name(it), "right": "EQUIPPED" if it["eq"] else "", "fn": _drop_one.bind(c, it, back)})
	ui.choose_list("Drop which item?", ui.flav("Dropped items are gone forever."), items, back)


func _drop_one(c: Character, it: Dictionary, back: Callable) -> void:
	if it["eq"] and it["cursed"]:
		Game.say("THE %s IS CURSED. IT WILL NOT LET GO." % c.item_name(it), "hit")
		back.call()
		return
	ui.yesno("Drop it?", "Drop the %s for good?" % ui.esc(c.item_name(it)), func(): c.items.erase(it); Game.say("%s DROPS IT." % c.name); back.call(), back)


func bishop_identify(c: Character, back: Callable) -> void:
	var unk: Array = c.items.filter(func(it): return not it["known"])
	if unk.is_empty():
		Game.say("NOTHING HERE NEEDS IDENTIFYING.")
		back.call()
		return
	var items := []
	for it in unk:
		items.append({"label": c.item_name(it), "fn": _identify_one.bind(c, it, back)})
	ui.choose_list("Identify which item?", "", items, back)


func _identify_one(c: Character, it: Dictionary, back: Callable) -> void:
	if Dice.chance(15 + c.lvl * 6 + c.stats["iq"]):
		it["known"] = true
		Game.say("SUCCESS! IT IS A %s." % c.item_name(it), "ok")
	else:
		Game.say("YOU FAIL TO IDENTIFY IT.")
		var slot: String = c.item_def(it)["slot"]
		if randf() < 0.33 and c.can_use(it) and "WASH".contains(slot):
			for o in c.items:
				if o["eq"] and c.item_def(o)["slot"] == slot and not o["cursed"]:
					o["eq"] = false
			it["eq"] = true
			Game.say("OOPS! %s TOUCHED IT AND IS NOW WEARING IT." % c.name, "hit")
			if c.item_def(it).get("curse", false):
				it["cursed"] = true
				it["known"] = true
				Game.say("IT IS CURSED!", "hit")
	back.call()


## Walks through weapon, armor, shield and helm in turn, as the manual's EQUIP does.
func equip_flow(c: Character, done: Callable, slots: Array) -> void:
	if slots.is_empty():
		done.call()
		return
	var slot: String = slots[0]
	var rest := slots.slice(1)
	var next := equip_flow.bind(c, done, rest)
	var nm: String = {"W": "weapon", "A": "armor", "S": "shield", "H": "helm"}[slot]
	var cur = c.equipped(slot)
	if cur != null and cur["cursed"]:
		Game.say("%s'S %s IS CURSED AND WILL NOT COME OFF." % [c.name, c.item_name(cur)], "hit")
		next.call()
		return
	var own: Array = c.items.filter(func(it): return c.item_def(it)["slot"] == slot and c.can_use(it))
	if own.is_empty():
		if cur != null:
			cur["eq"] = false
		next.call()
		return
	var opts := []
	for i in own.size():
		opts.append({"k": str(i + 1), "label": c.item_name(own[i]), "right": "NOW" if own[i]["eq"] else "", "fn": _equip_one.bind(c, own[i], slot, next)})
	opts.append({"k": "Enter", "label": "NONE", "def": true, "fn": func(): _unequip(c, slot); next.call()})
	ui.show_screen({"title": "Equip " + nm, "body": "%s: choose a %s, or none." % [ui.esc(c.name), nm], "col": true, "opts": opts})


func _unequip(c: Character, slot: String) -> void:
	for o in c.items:
		if c.item_def(o)["slot"] == slot:
			o["eq"] = false


func _equip_one(c: Character, it: Dictionary, slot: String, next: Callable) -> void:
	_unequip(c, slot)
	it["eq"] = true
	var d := c.item_def(it)
	if d.get("curse", false):
		it["cursed"] = true
		it["known"] = true
		Game.say("IT'S CURSED! %s IS STUCK WITH THE %s." % [c.name, c.item_name(it)], "hit")
	if d.has("align") and d["align"] != c.align.substr(0, 1):
		it["cursed"] = true
		it["bad"] = true
		it["known"] = true
		Game.say("THE %s REJECTS %s'S ALIGNMENT. IT BINDS ITSELF TO HIM AND SAPS HIS STRENGTH." % [c.item_name(it), c.name], "hit")
	next.call()


func trade(c: Character, back: Callable) -> void:
	var items := []
	for o in Game.party_chars():
		if o != c:
			items.append({"label": o.name, "fn": _trade_gold.bind(c, o, back)})
	ui.choose_list("Trade with whom?", "", items, back)


func _trade_gold(c: Character, o: Character, back: Callable) -> void:
	ui.show_screen({"title": "Trade gold", "body": "%s has %d gold. How much to give %s? Press ENTER for none." % [ui.esc(c.name), c.gold, ui.esc(o.name)],
		"input": {"ph": "AMOUNT", "max": 7, "fn": func(v): _give_gold(c, o, v, back)}, "opts": [{"k": "Escape", "label": "LEAVE", "esc": true, "fn": back}]})


func _give_gold(c: Character, o: Character, v: String, back: Callable) -> void:
	var n := clampi(int(v) if v.is_valid_int() else 0, 0, c.gold)
	c.gold -= n
	o.gold += n
	if n > 0:
		Game.say("%s GIVES %s %d GOLD." % [c.name, o.name, n], "gold")
	_trade_items(c, o, back)


func _trade_items(c: Character, o: Character, back: Callable) -> void:
	var items := []
	for it in c.items:
		if not it["eq"]:
			items.append({"label": c.item_name(it), "dis": o.items.size() >= 8, "fn": _give_item.bind(c, o, it, back)})
	ui.choose_list("Trade items", "Give an item to %s, or leave. Equipped items cannot be traded." % ui.esc(o.name), items, back)


func _give_item(c: Character, o: Character, it: Dictionary, back: Callable) -> void:
	c.items.erase(it)
	o.items.append(it)
	Game.say("%s GIVES %s THE %s." % [c.name, o.name, c.item_name(it)])
	_trade_items(c, o, back)


# ---------- spells and items in camp ----------
func camp_spell(c: Character, back: Callable) -> void:
	var list: Array = c.spells.filter(func(n): return "AK".contains(Data.SPELLS[n][2]) and c.can_cast(n))
	if list.is_empty():
		Game.say("%s HAS NO SPELLS TO CAST HERE." % c.name)
		back.call()
		return
	var items := []
	for n in list:
		items.append({"label": n, "right": Data.SPELLS[n][4], "fn": _camp_target.bind(c, n, Dictionary(), back)})
	ui.choose_list("Cast a spell", "Spells that work outside combat.", items, back)


func camp_use(c: Character, back: Callable) -> void:
	var list: Array = c.items.filter(func(it): return c.item_def(it).has("spell") and not it.get("broken", false) and "AK".contains(Data.SPELLS[c.item_def(it)["spell"]][2]))
	if list.is_empty():
		Game.say("NOTHING HERE CAN BE USED OUTSIDE COMBAT.")
		back.call()
		return
	var items := []
	for it in list:
		items.append({"label": c.item_name(it), "fn": _camp_target.bind(c, c.item_def(it)["spell"], it, back)})
	ui.choose_list("Use an item", "", items, back)


func _camp_target(c: Character, n: String, item: Dictionary, back: Callable) -> void:
	if Data.SPELLS[n][3] == "ally":
		ui.pick_member("On whom?", back, func(t): _camp_cast(c, n, item, t, back))
	else:
		_camp_cast(c, n, item, c, back)


func _camp_cast(c: Character, n: String, item: Dictionary, t: Character, back: Callable) -> void:
	if item.is_empty():
		c.spend(n)
	else:
		Spells.use_charge(c, item)
	if Spells.utility(c, n, t) == "dumapic":
		var p: Dictionary = Game.pos
		ui.say("Dumapic", "YOUR PARTY IS %d SQUARES EAST AND %d SQUARES NORTH OF THE STAIRS TO THE CASTLE, AND %d LEVEL%s BELOW IT. THE PARTY IS FACING %s." %
			[p["x"], p["y"], p["z"], "S" if p["z"] > 1 else "", MazeLevel.DIR_NAMES[p["d"]]], back)
	else:
		back.call()


# ---------- roster picking ----------
func roster_pick(title: String, filter: Callable, fn: Callable, back: Callable, page := 0) -> void:
	var all: Array = Game.roster.filter(filter)
	var items := []
	for c in all.slice(page * 9, page * 9 + 9):
		items.append({"label": c.name, "right": ("L%d %s-%s %s" % [c.lvl, c.align.substr(0, 1), c.cdata()["ab"], "" if c.status == "OK" else c.status]).strip_edges(), "fn": fn.bind(c)})
	var extra := []
	if all.size() > (page + 1) * 9:
		extra.append({"k": "N", "label": "NEXT PAGE", "fn": roster_pick.bind(title, filter, fn, back, page + 1)})
	if page > 0:
		extra.append({"k": "B", "label": "BACK A PAGE", "fn": roster_pick.bind(title, filter, fn, back, page - 1)})
	ui.choose_list(title, "" if not all.is_empty() else ui.flav("No one here answers your call."), items, back, extra)


# ---------- Training Grounds ----------
func training() -> void:
	if not Game.party.is_empty():
		Game.say("THE PARTY DISBANDS.")
	for c in Game.party_chars():
		c.loc = "CASTLE"
	Game.party.clear()
	Game.save_game()
	ui.show_screen({"title": "Training Grounds", "where": "Training Grounds", "view": "train",
		"body": ui.flav("Youngsters hack at wooden posts, and most of the battle cries end in yelps when the blades bounce back."),
		"opts": [
			{"k": "C", "label": "CREATE A CHARACTER", "fn": create_name},
			{"k": "I", "label": "INSPECT A CHARACTER", "fn": func(): roster_pick("Inspect whom?", func(_c): return true, train_char, training)},
			{"k": "R", "label": "ROSTER OF CHARACTERS", "fn": show_roster},
			{"k": "L", "label": "LEAVE", "esc": true, "fn": ui.town.edge_of_town},
		]})


func show_roster() -> void:
	var t := ""
	for c in Game.roster:
		t += "%s L%2d %s-%s %s %s\n" % [ui.esc(c.name.rpad(15)), c.lvl, c.align.substr(0, 1), c.cdata()["ab"], "" if c.loc == "CASTLE" else c.loc, c.status]
	ui.say("Roster", t if t != "" else "THE ROSTER IS EMPTY.", training)


func train_char(c: Character) -> void:
	var home := c.loc == "CASTLE"
	ui.show_screen({"title": c.name, "view": "train", "body": ui.sheet(c) + ("" if home else "\n" + ui.flav("This adventurer is OUT in the Maze. Bring them home first.")), "opts": [
		{"k": "R", "label": "READ", "fn": read_books.bind(c, train_char.bind(c))},
		{"k": "D", "label": "DELETE", "dis": not home, "fn": func(): ui.yesno("Retire to Club Wiz?", "%s will pack up and leave the game forever. Delete?" % ui.esc(c.name), _delete.bind(c), train_char.bind(c))},
		{"k": "C", "label": "CHANGE CLASS", "dis": not home or not c.is_alive(), "fn": change_class.bind(c)},
		{"k": "L", "label": "LEAVE", "esc": true, "def": true, "fn": training},
	]})


func _delete(c: Character) -> void:
	Game.roster.erase(c)
	Game.save_game()
	Game.say("%s RETIRES TO CLUB WIZ." % c.name)
	training()


func change_class(c: Character) -> void:
	var el := Character.eligible(c.stats, c.align).filter(func(k): return k != c.cls)
	if el.is_empty():
		Game.say("%s DOES NOT QUALIFY FOR ANY OTHER CLASS." % c.name)
		train_char(c)
		return
	var items := []
	for k in el:
		items.append({"label": k, "fn": func(): ui.yesno("Are you sure?", "Make %s a %s?" % [ui.esc(c.name), k], _do_change.bind(c, k), train_char.bind(c))})
	ui.choose_list("Change class", ui.flav("The new class starts at level 1. Statistics drop to the racial minimum, experience to zero, and every item is unequipped. Known spells are kept."),
		items, train_char.bind(c))


func _do_change(c: Character, k: String) -> void:
	c.change_class(k)
	Game.save_game()
	Game.say("%s IS NOW A %s." % [c.name, k], "ok")
	train_char(c)


# ---------- character creation ----------
func create_name() -> void:
	ui.show_screen({"title": "Create a character", "view": "train", "body": "Type the new adventurer's name and press ENTER.",
		"input": {"ph": "NAME", "max": 15, "fn": _name_entered}, "opts": [{"k": "Escape", "label": "LEAVE", "esc": true, "fn": training}]})


func _name_entered(v: String) -> void:
	if v == "":
		return
	if Game.roster.any(func(o): return o.name == v):
		Game.say("THAT NAME IS TAKEN.")
		return
	create_race(v)


func create_race(nm: String) -> void:
	var items := []
	for r in Data.RACES:
		var st := " ".join(Data.STATS.map(func(s): return str(Data.RACES[r][s])))
		items.append({"label": r, "right": st, "fn": create_align.bind(nm, r)})
	ui.choose_list("%s: choose a race" % nm, ui.flav("Humans are steady, elves clever and pious, dwarves strong, gnomes pious and agile, hobbits agile and very lucky.") +
		"\n[color=#9c947f]STR I.Q. PIE VIT AGI LUK[/color]", items, training)


func create_align(nm: String, race: String) -> void:
	ui.show_screen({"title": "%s: choose an alignment" % nm, "view": "train", "body": ui.flav("Good characters will not adventure with evil ones. Neutrals get along with either."), "opts": [
		{"k": "G", "label": "GOOD", "fn": create_stats.bind(nm, race, "GOOD")},
		{"k": "N", "label": "NEUTRAL", "fn": create_stats.bind(nm, race, "NEUTRAL")},
		{"k": "E", "label": "EVIL", "fn": create_stats.bind(nm, race, "EVIL")},
		{"k": "L", "label": "LEAVE", "esc": true, "fn": training},
	]})


## Bonus-point allocation. State lives in one dictionary so the button callbacks can change it.
func create_stats(nm: String, race: String, al: String) -> void:
	var pts := Dice.rnd(5, 9) + (10 if randf() < 0.12 else 0) + (10 if randf() < 0.02 else 0)
	var b := {"nm": nm, "race": race, "al": al, "st": Data.RACES[race].duplicate(), "pts": pts, "max": pts, "sel": 0}
	_draw_stats(b)


func _adjust(b: Dictionary, stat: String, d: int) -> void:
	var st: Dictionary = b["st"]
	if d > 0 and b["pts"] > 0 and st[stat] < 18:
		st[stat] += 1
		b["pts"] -= 1
	elif d < 0 and st[stat] > Data.RACES[b["race"]][stat]:
		st[stat] -= 1
		b["pts"] += 1
	_draw_stats(b)


func _move_sel(b: Dictionary, d: int) -> void:
	b["sel"] = (b["sel"] + d + 6) % 6
	_draw_stats(b)


func _draw_stats(b: Dictionary) -> void:
	var st: Dictionary = b["st"]
	var el := Character.eligible(st, b["al"])
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	for i in Data.STATS.size():
		var s: String = Data.STATS[i]
		var arrow := Label.new()
		arrow.text = "►" if i == b["sel"] else " "
		var lbl := Label.new()
		lbl.text = Data.STAT_NAMES[s]
		var val := Label.new()
		val.text = str(st[s])
		for l in [arrow, lbl, val]:
			if i == b["sel"]:
				l.add_theme_color_override("font_color", ui.C_TORCH)
			grid.add_child(l)
		for spec in [["−", -1], ["+", 1]]:
			var btn := Button.new()
			btn.text = spec[0]
			btn.focus_mode = Control.FOCUS_NONE
			btn.custom_minimum_size = Vector2(36, 30)
			btn.pressed.connect(_adjust.bind(b, s, spec[1]))
			grid.add_child(btn)
	var body := "BONUS POINTS: [color=#e3a33f]%d[/color] of %d\nCLASSES: [color=#93c07e]%s[/color]\n" % [b["pts"], b["max"], "  ".join(el) if not el.is_empty() else "NONE YET"]
	body += ui.flav("Arrow keys move and adjust. Spend every bonus point, then choose a class.")
	var sel_stat: String = Data.STATS[b["sel"]]
	ui.show_screen({"title": "%s: %s-%s" % [b["nm"], b["al"].substr(0, 1), b["race"]], "view": "train", "widget": grid, "body": body,
		"keys": {"Up": _move_sel.bind(b, -1), "Down": _move_sel.bind(b, 1), "Enter": _move_sel.bind(b, 1),
			"Right": _adjust.bind(b, sel_stat, 1), "+": _adjust.bind(b, sel_stat, 1), "=": _adjust.bind(b, sel_stat, 1),
			"Left": _adjust.bind(b, sel_stat, -1), "-": _adjust.bind(b, sel_stat, -1)},
		"opts": [
			{"k": "C", "label": "CHOOSE CLASS", "dis": b["pts"] > 0 or el.is_empty(), "fn": _choose_class.bind(b, el)},
			{"k": "R", "label": "REROLL BONUS", "fn": create_stats.bind(b["nm"], b["race"], b["al"])},
			{"k": "Q", "label": "QUIT", "esc": true, "fn": training},
		]})


func _choose_class(b: Dictionary, el: Array) -> void:
	var items := []
	for k in el:
		items.append({"label": k, "fn": _confirm_char.bind(b, k)})
	ui.choose_list("Choose a class", "", items, _draw_stats.bind(b))


func _confirm_char(b: Dictionary, k: String) -> void:
	var st: Dictionary = b["st"]
	var line := " · ".join(Data.STATS.map(func(s): return "%s %d" % [Data.STAT_NAMES[s], st[s]]))
	ui.yesno("Keep this character?", "%s — %s-%s-%s\n%s" % [ui.esc(b["nm"]), b["al"].substr(0, 1), b["race"], k, line], _make.bind(b, k), _draw_stats.bind(b))


func _make(b: Dictionary, k: String) -> void:
	var c := Game.make_char(b["nm"], b["race"], b["al"], b["st"], k)
	Game.save_game()
	Game.say("%s JOINS THE ROSTER. (%d GOLD)" % [c.name, c.gold], "ok")
	training()

class_name CharScreens
extends RefCounted
## Character screens: inspecting (spell books, equip, discard, trade, identify, camp spells),
## the Training Grounds, character creation, and class changes.

const TRAINING_IMAGE := "res://assets/images/training.webp"
const PORTRAIT_THUMB := 126.0
const PORTRAIT_COLUMNS := 4
const PORTRAITS_PER_PAGE := 12
const PORTRAIT_TAKEN_TINT := Color(1, 1, 1, 0.2)
const RACE_POPUP_WIDTH := 340.0
const INFO_ICON := "res://assets/images/info.svg"
const INFO_ICON_SIZE := 28.0
const ROLL_BUTTON_SIZE := Vector2(260, 58)
const STAT_HEADING_FONT := 16
# The roll screen is laid out to fixed sizes, so that no dice value can move anything on it.
const STAT_NAME_WIDTH := 105.0
const STAT_NUMBER_WIDTH := 58.0
const STAT_ROW_HEIGHT := 30.0
const STAT_BODY_HEIGHT := 96.0  # four lines: the points, up to two of classes, and a note
const ROLL_DICE := 3  # six-sided, for each attribute
const REROLL_POINTS := 6
const REROLL_COST := 2  # every attribute
const REROLL_ONE_COST := 1  # just one

var ui


func _init(root) -> void:
	ui = root


# ---------- inspect ----------
func inspect(c: Character, from: String, back: Callable) -> void:
	var camp := from == "camp"
	var can := camp or from == "tavern"
	var again := inspect.bind(c, from, back)
	var opts := [
		{"k": "R", "label": "READ", "in_widget": true, "sheet_at": CharacterSheet.AT_BOOK, "fn": read_books.bind(c, again)},
		{"k": "S", "label": "SPELL", "in_widget": true, "sheet_at": CharacterSheet.AT_BOOK, "hide": not camp, "dis": not c.can_act(), "fn": camp_spell.bind(c, again)},
		{"k": "E", "label": "EQUIP", "in_widget": true, "sheet_at": CharacterSheet.AT_EQUIPMENT, "hide": not can, "fn": equip_flow.bind(c, again, ["W", "A", "S", "H"])},
		{"k": "D", "label": "DISCARD", "in_widget": true, "sheet_at": CharacterSheet.AT_EQUIPMENT, "hide": not can, "fn": discard_item.bind(c, again)},
		{"k": "T", "label": "TRADE", "in_widget": true, "sheet_at": CharacterSheet.AT_EQUIPMENT, "hide": not can or Game.party.size() < 2, "fn": trade.bind(c, again)},
		{"k": "I", "label": "IDENTIFY", "in_widget": true, "sheet_at": CharacterSheet.AT_EQUIPMENT, "hide": not can or not c.cdata().get("ident", false), "fn": bishop_identify.bind(c, again)},
		{"k": "U", "label": "USE", "in_widget": true, "sheet_at": CharacterSheet.AT_EQUIPMENT, "hide": not camp, "dis": not c.can_act(), "fn": camp_use.bind(c, again)},
		{"k": "P", "label": "POOL GOLD", "small": true, "hide": not can, "fn": _pool.bind(c, again)},
		{"k": "L", "label": "BACK", "small": true, "fn": back},
	]
	ui.show_screen({"title": "Inspect", "body": ui.esc(c.bio()), "sheet": CharacterSheet.build.bind(ui, c, opts), "opts": opts})


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


func discard_item(c: Character, back: Callable) -> void:
	var items := []
	for it in c.items:
		items.append({"label": c.item_name(it), "right": "EQUIPPED" if it["eq"] else "", "fn": _discard_one.bind(c, it, back)})
	ui.choose_list("Discard which item?", ui.flav("Discarded items are gone forever."), items, back)


func _discard_one(c: Character, it: Dictionary, back: Callable) -> void:
	if it["eq"] and it["cursed"]:
		Game.say("THE %s IS CURSED. IT WILL NOT LET GO." % c.item_name(it), "hit")
		back.call()
		return
	ui.yesno("Discard it?", "Discard the %s for good?" % ui.esc(c.item_name(it)), func(): c.items.erase(it); Game.say("%s DISCARDS IT." % c.name); back.call(), back)


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
	opts.append({"k": "Enter", "label": "NONE", "fn": func(): _unequip(c, slot); next.call()})
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
		Game.say("THE %s REJECTS %s'S ALIGNMENT. IT BINDS ITSELF TO %s AND SAPS %s STRENGTH." % [c.item_name(it), c.name, c.him(), c.his()], "hit")
	next.call()


func trade(c: Character, back: Callable) -> void:
	var items := []
	for o in Game.party_chars():
		if o != c:
			items.append({"label": o.name, "fn": _trade_gold.bind(c, o, back)})
	ui.choose_list("Trade with whom?", "", items, back)


func _trade_gold(c: Character, o: Character, back: Callable) -> void:
	ui.show_screen({"title": "Trade gold", "body": "%s has %d gold. How much to give %s? Leave it blank for none." % [ui.esc(c.name), c.gold, ui.esc(o.name)],
		"input": {"ph": "AMOUNT", "max": 7, "fn": func(v): _give_gold(c, o, v, back)}, "opts": [{"k": "Escape", "label": "BACK", "fn": back}]})


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
	ui.choose_list("Trade items", "Give an item to %s, or go back. Equipped items cannot be traded." % ui.esc(o.name), items, back)


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
		ui.say("Dumapic", "YOUR PARTY IS %d SQUARES EAST AND %d SQUARES NORTH OF THE LADDER TO THE CASTLE, AND %d LEVEL%s BELOW IT. THE PARTY IS FACING %s." %
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
	ui.place_image = TRAINING_IMAGE
	Game.save_game()
	var count := "ROSTER: %d OF %d" % [Game.roster.size(), Game.MAX_ROSTER]
	if Game.roster_full():
		count += "\nThe roster is full. Delete a character to make room for a new one."
	ui.show_screen({"title": "Training Grounds", "where": "Training Grounds", "view": "train",
		"body": ui.flav("Youngsters hack at wooden posts, and most of the battle cries end in yelps when the blades bounce back.") + "\n\n" + count,
		"opts": [
			{"k": "C", "label": "CREATE A CHARACTER", "dis": Game.roster_full(), "fn": create_name},
			{"k": "I", "label": "INSPECT A CHARACTER", "fn": func(): roster_pick("Inspect whom?", func(_c): return true, train_char, training)},
			{"k": "R", "label": "ROSTER OF CHARACTERS", "fn": show_roster},
			{"k": "L", "label": "EXIT", "fn": ui.town.castle},
		]})


func show_roster() -> void:
	var t := ""
	for c in Game.roster:
		t += "%s L%2d %s-%s %s %s\n" % [ui.esc(c.name.rpad(15)), c.lvl, c.align.substr(0, 1), c.cdata()["ab"], "" if c.loc == "CASTLE" else "MAZE", c.status]
	ui.say("Roster", t if t != "" else "THE ROSTER IS EMPTY.", training)


func change_name(c: Character) -> void:
	ui.show_screen({"title": "Rename %s" % c.name, "view": "train", "body": "Type the new name, then choose SELECT.",
		"input": {"ph": "NEW NAME", "fn": _renamed.bind(c)}, "opts": [{"k": "Escape", "label": "BACK", "small": true, "at": "right", "fn": train_char.bind(c)}]})


func _renamed(v: String, c: Character) -> void:
	if v == "":
		return
	if Game.roster.any(func(o): return o.name == v):
		Game.say("THAT NAME IS TAKEN.")
		return
	c.name = v
	Game.save_game()
	Game.say("NOW KNOWN AS %s." % v)
	train_char(c)


func train_char(c: Character) -> void:
	var home := c.loc == "CASTLE"
	ui.show_screen({"title": c.name, "view": "train", "portrait": c.portrait_path(), "portrait_dead": not c.is_alive(), "body": ui.sheet(c) + ("" if home else "\n" + ui.flav("This adventurer lies dead in the Maze. Bring them home first.")), "opts": [
		{"k": "R", "label": "READ", "fn": read_books.bind(c, train_char.bind(c))},
		{"k": "D", "label": "DELETE", "dis": not home, "fn": func(): ui.yesno("Retire to Club Wiz?", "%s will pack up and leave the game forever. Delete?" % ui.esc(c.name), _delete.bind(c), train_char.bind(c))},
		{"k": "C", "label": "CHANGE CLASS", "dis": not home or not c.is_alive(), "fn": change_class.bind(c)},
		{"k": "N", "label": "CHANGE NAME", "fn": change_name.bind(c)},
		{"k": "P", "label": "CHANGE PORTRAIT", "fn": change_portrait.bind(c)},
		{"k": "L", "label": "BACK", "fn": training},
	]})


func _delete(c: Character) -> void:
	Game.party.erase(c.id)
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
	ui.show_screen({"title": "Create a character", "view": "train", "body": "Type the new adventurer's name, then choose SELECT.",
		"input": {"ph": "NAME", "max": 15, "fn": _name_entered}, "opts": [{"k": "Escape", "label": "BACK", "small": true, "at": "right", "fn": training}]})


func _name_entered(v: String) -> void:
	if v == "":
		return
	if Game.roster.any(func(o): return o.name == v):
		Game.say("THAT NAME IS TAKEN.")
		return
	create_race(v)


## Picking a race opens its popup, and the popup's button moves on to alignment.
func create_race(nm: String, selected := "") -> void:
	var list := VBoxContainer.new()
	for r in Data.RACES:
		var btn := _race_button(r, create_race.bind(nm, r))
		btn.name = r
		if r == selected:
			btn.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.C_STONE2, UiStyle.C_TORCH, 7))
		list.add_child(btn)
	var leave := _race_button("BACK", create_name)
	UiStyle.make_small_button(leave)
	leave.size_flags_horizontal = Control.SIZE_SHRINK_END
	leave.name = "Leave"
	list.add_child(leave)
	var s := {"title": "%s: choose a race" % nm, "view": "train", "widget": list, "body": "Select a race to see bonus stats:"}
	if selected != "":
		s["side"] = _race_popup(nm, selected)
	ui.show_screen(s)


func _race_button(text: String, fn: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(fn)
	return btn


func _race_popup(nm: String, race: String) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = RACE_POPUP_WIDTH
	box.add_theme_constant_override("separation", 10)
	var blurb := Label.new()
	blurb.text = Data.RACE_TEXT[race]
	blurb.add_theme_color_override("font_color", UiStyle.C_TORCH)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(blurb)
	var heading := Label.new()
	heading.text = "Bonus Stats"
	box.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	var explain := Label.new()
	explain.name = "Explain"
	explain.add_theme_color_override("font_color", UiStyle.C_DIM)
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explain.custom_minimum_size.y = 72  # room for the longest text, so the popup does not jump
	for st in Data.STATS:
		var stat := Label.new()
		stat.text = "%s: %s" % [Data.STAT_INFO[st][0], _bonus_text(race, st, "None")]
		stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(stat)
		var info := Button.new()
		info.name = "Info_" + st
		info.icon = load(INFO_ICON)
		info.expand_icon = true
		info.custom_minimum_size = Vector2.ONE * INFO_ICON_SIZE
		info.flat = true
		info.focus_mode = Control.FOCUS_NONE
		var show_text := func(): explain.text = Data.STAT_INFO[st][1]
		info.mouse_entered.connect(show_text)
		info.pressed.connect(show_text)
		info.mouse_exited.connect(func(): explain.text = "")
		grid.add_child(info)
	box.add_child(explain)
	var choose := _race_button("CHOOSE " + race, create_align.bind(nm, race))
	choose.name = "Choose"
	choose.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(choose)
	return box


## "+2" or "-1", or none_text when this race gets nothing for this statistic.
func _bonus_text(race: String, st: String, none_text: String) -> String:
	var bonus: int = Data.RACE_BONUS[race].get(st, 0)
	return "%+d" % bonus if bonus != 0 else none_text


func create_align(nm: String, race: String) -> void:
	ui.show_screen({"title": "%s: choose an alignment" % nm, "view": "train", "body": ui.flav("Good characters will not adventure with evil ones. Neutrals get along with either."), "opts": [
		{"k": "G", "label": "GOOD", "fn": create_stats.bind(nm, race, "GOOD")},
		{"k": "N", "label": "NEUTRAL", "fn": create_stats.bind(nm, race, "NEUTRAL")},
		{"k": "E", "label": "EVIL", "fn": create_stats.bind(nm, race, "EVIL")},
		{"k": "L", "label": "BACK", "small": true, "at": "right", "fn": create_race.bind(nm, race)},
	]})


## Rolling the attributes, one at a time. State lives in one dictionary so the button callbacks can change it:
## rolls holds what the dice gave, and st those scores with the race's bonus added.
func create_stats(nm: String, race: String, al: String) -> void:
	ui.dice_tray().rest()
	_draw_stats({"nm": nm, "race": race, "al": al, "st": {}, "rolls": {}, "rolled": 0, "rolling": false, "reroll": REROLL_POINTS})


func _roll_attribute(b: Dictionary) -> void:
	_roll_stat(b, Data.STATS[b["rolled"]])


func _roll_stat(b: Dictionary, stat: String) -> void:
	var faces := []
	for i in ROLL_DICE:
		faces.append(Dice.rnd(1, 6))
	b["rolling"] = true
	b["current"] = stat
	ui.dice_tray().roll(faces, _attribute_rolled.bind(b, stat, faces.reduce(func(sum, f): return sum + f, 0)))
	_draw_stats(b)


func _attribute_rolled(b: Dictionary, stat: String, score: int) -> void:
	b["rolls"][stat] = score
	b["st"][stat] = score + Data.RACE_BONUS[b["race"]].get(stat, 0)
	if b["rolled"] < Data.STATS.size():
		b["rolled"] += 1
	b["rolling"] = false
	_draw_stats(b)


## Scores that qualify for no class, with no points left for any re-roll, would leave the player stuck.
func _reroll_cost(b: Dictionary) -> int:
	var stuck: bool = Character.eligible(b["st"], b["al"]).is_empty() and b["reroll"] < REROLL_ONE_COST
	return 0 if stuck else REROLL_COST


func _reroll(b: Dictionary) -> void:
	b["reroll"] -= _reroll_cost(b)
	b["st"] = {}
	b["rolls"] = {}
	b["rolled"] = 0
	ui.dice_tray().rest()
	_draw_stats(b)


func _reroll_one(b: Dictionary, stat: String) -> void:
	b["reroll"] -= REROLL_ONE_COST
	_roll_stat(b, stat)


func _stat_cell(text: String, color: Variant = null) -> Label:
	var cell := Label.new()
	cell.text = text
	cell.custom_minimum_size = Vector2(STAT_NUMBER_WIDTH, STAT_ROW_HEIGHT)
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if color != null:
		cell.add_theme_color_override("font_color", color)
	return cell


func _draw_stats(b: Dictionary) -> void:
	var st: Dictionary = b["st"]
	var finished: bool = b["rolled"] >= Data.STATS.size()
	var rolling: bool = b["rolling"]
	var grid := GridContainer.new()
	grid.columns = 5 if finished else 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	var corner := Control.new()
	corner.custom_minimum_size.x = STAT_NAME_WIDTH
	grid.add_child(corner)
	for heading in ["Rolled", "Bonus", "Total"]:
		var head := _stat_cell(heading, UiStyle.C_DIM)
		head.add_theme_font_size_override("font_size", STAT_HEADING_FONT)
		grid.add_child(head)
	if finished:
		grid.add_child(Control.new())
	for i in Data.STATS.size():
		var s: String = Data.STATS[i]
		var active: bool = s == b["current"] if rolling else i == b["rolled"]
		var ink: Variant = UiStyle.C_TORCH if active else null
		var lbl := _stat_cell(Data.STAT_NAMES[s], ink)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.custom_minimum_size.x = STAT_NAME_WIDTH
		grid.add_child(lbl)
		grid.add_child(_stat_cell(str(b["rolls"][s]) if b["rolls"].has(s) else "-", ink))
		grid.add_child(_stat_cell(_bonus_text(b["race"], s, "0"), UiStyle.C_TORCH if active else UiStyle.C_DIM))
		grid.add_child(_stat_cell(str(st[s]) if st.has(s) else "-", ink))
		if finished:
			var again: Button = ui._small_button({"k": "", "label": "RE-ROLL (%d)" % REROLL_ONE_COST, "dis": rolling or b["reroll"] < REROLL_ONE_COST, "fn": _reroll_one.bind(b, s)}, ui.PAGER_FILL, ui.PAGER_EDGE)
			again.name = "Reroll_" + s
			again.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			again.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END  # out at the panel's edge
			grid.add_child(again)
	var el := Character.eligible(st, b["al"]) if finished else []
	var body := "RE-ROLL POINTS: [color=#e3a33f]%d[/color]\n" % b["reroll"]
	if finished:
		body += "CLASSES: [color=#93c07e]%s[/color]\n" % ("  ".join(el) if not el.is_empty() else "NONE")
		body += ui.flav("Choose a class next." if not el.is_empty() else "No class qualifies. Re-roll to try again.")
	else:
		body += ui.flav("Roll three dice for each attribute.")
	var cost := _reroll_cost(b) if finished else REROLL_COST
	ui.show_screen({"title": "%s: %s-%s" % [b["nm"], b["al"].substr(0, 1), b["race"]], "view": "train", "widget": grid, "body": body, "dice": true,
		"body_height": STAT_BODY_HEIGHT, "row_height": ROLL_BUTTON_SIZE.y,
		"opts": [
			{"k": "R", "label": "ROLL", "big": ROLL_BUTTON_SIZE, "at": "center", "hide": finished, "dis": rolling, "fn": _roll_attribute.bind(b)},
			{"k": "A", "label": "RE-ROLL ALL (%s)" % (str(cost) if cost > 0 else "FREE"), "small": true, "hide": not finished, "dis": rolling or b["reroll"] < cost, "fn": _reroll.bind(b)},
			{"k": "N", "label": "NEXT", "small": true, "hide": not finished, "dis": rolling or el.is_empty(), "fn": _choose_class.bind(b, el)},
			{"k": "L", "label": "BACK", "small": true, "at": "right", "dis": rolling, "fn": create_align.bind(b["nm"], b["race"])},
		]})


func _choose_class(b: Dictionary, el: Array) -> void:
	var items := []
	for k in el:
		items.append({"label": k, "fn": create_sex.bind(b, k)})
	ui.choose_list("Choose a class", "", items, _draw_stats.bind(b))


func create_sex(b: Dictionary, k: String) -> void:
	ui.show_screen({"title": "%s: male or female?" % b["nm"], "view": "train", "opts": [
		{"k": "M", "label": "MALE", "fn": create_portrait.bind(b, k, "MALE")},
		{"k": "F", "label": "FEMALE", "fn": create_portrait.bind(b, k, "FEMALE")},
		{"k": "L", "label": "BACK", "fn": func(): _choose_class(b, Character.eligible(b["st"], b["al"]))},
	]})


func create_portrait(b: Dictionary, k: String, sex: String, page := 0) -> void:
	_portrait_picker(b["nm"], sex, page, _pick_portrait.bind(b, k, sex), create_sex.bind(b, k))


func change_portrait(c: Character, page := 0) -> void:
	_portrait_picker(c.name, c.sex, page, _portrait_changed.bind(c), train_char.bind(c), c)


func _portrait_changed(portrait: String, c: Character) -> void:
	c.portrait = portrait
	Game.save_game()
	train_char(c)


## pick is called with the chosen portrait's name. Portraits other characters have, apart from who, can't be chosen.
## Each visit deals the portraits in a new order, and turning the page keeps that order.
func _portrait_picker(nm: String, sex: String, page: int, pick: Callable, back: Callable, who: Character = null, order: Array = []) -> void:
	var taken := Game.portraits_taken(who)
	var grid := GridContainer.new()
	grid.columns = PORTRAIT_COLUMNS
	var all: Array = order if not order.is_empty() else _shuffled(Data.portraits(sex))
	var pages := ceili(float(all.size()) / PORTRAITS_PER_PAGE)
	var names: Array = all.slice(page * PORTRAITS_PER_PAGE, (page + 1) * PORTRAITS_PER_PAGE)
	for portrait in names:
		var btn := Button.new()
		btn.name = portrait
		btn.icon = load(Character.PORTRAIT_FILE % portrait)
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2.ONE * PORTRAIT_THUMB
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(pick.bind(portrait))
		if taken.has(portrait):
			btn.disabled = true
			btn.modulate = PORTRAIT_TAKEN_TINT
		grid.add_child(btn)
	ui.show_screen({"title": "%s: choose a portrait" % nm, "view": "train", "widget": grid,
		"body": "Pick a portrait." + ("  Page %d of %d." % [page + 1, pages] if pages > 1 else ""),
		"opts": [
			{"k": "N", "label": "NEXT PAGE", "hide": page + 1 >= pages, "fn": _portrait_picker.bind(nm, sex, page + 1, pick, back, who, all)},
			{"k": "B", "label": "BACK A PAGE", "hide": page == 0, "fn": _portrait_picker.bind(nm, sex, page - 1, pick, back, who, all)},
			{"k": "L", "label": "BACK", "fn": back},
		]})


## In an order of its own, leaving the game's dice alone.
func _shuffled(list: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := list.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = out[i]
		out[i] = out[j]
		out[j] = swap
	return out


func _pick_portrait(portrait: String, b: Dictionary, k: String, sex: String) -> void:
	b["sex"] = sex
	b["portrait"] = portrait
	_confirm_char(b, k)


func _confirm_char(b: Dictionary, k: String) -> void:
	var st: Dictionary = b["st"]
	var line := " · ".join(Data.STATS.map(func(s): return "%s %d" % [Data.STAT_NAMES[s], st[s]]))
	ui.yesno("Keep this character?", "%s — %s-%s-%s, %s\n%s" % [ui.esc(b["nm"]), b["al"].substr(0, 1), b["race"], k, b["sex"], line], _make.bind(b, k), _draw_stats.bind(b), Character.PORTRAIT_FILE % b["portrait"])


func _make(b: Dictionary, k: String) -> void:
	var c := Game.make_char(b["nm"], b["race"], b["al"], b["st"], k, b["sex"], b["portrait"])
	Game.save_game()
	Game.say("%s JOINS THE ROSTER. (%d GOLD)" % [c.name, c.gold], "ok")
	training()

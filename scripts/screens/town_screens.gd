class_name TownScreens
extends RefCounted
## The Castle and its shops: Gilgamesh's Tavern, Boltac's Trading Post, the Temple of Cant,
## the Adventurer's Inn, the Edge of Town and the Utilities.

const TAVERN_IMAGE := "res://assets/images/tavern.webp"
const BOLTAC_IMAGE := "res://assets/images/boltac.webp"
const GEAR_PLACES := [TAVERN_IMAGE, BOLTAC_IMAGE]  # the buildings that show the party with its equipment
const GEAR_SLOTS := [["Weapon", "W"], ["Helm", "H"], ["Armor", "A"], ["Shield", "S"]]  # in Data.ITEMS' slot letters
const GEAR_FONT := 15
const GEAR_FONT_MIN := 11
const MAX_PARTY := 6
const BUY_OFFER := "I will haggle no further, this is my best price!"
const SELL_OFFER := "This is my offer, take it or leave it..."
const BUY_NOTE_FONT := 18  # four sizes under the body text
const BOLTAC_TEXT := "The scent of cedar shavings, dank polishing oil, and cold iron hangs heavy in the air. Boltac's is the premier depot for adventurers seeking to upgrade their arsenal and spend their hard earned coin."
const INN_IMAGE := "res://assets/images/inn.webp"
const TEMPLE_IMAGE := "res://assets/images/temple.webp"

var ui


var _selected: Character = null  # the party member picked in the Tavern or at Boltac's


func _init(root) -> void:
	ui = root


# ---------- Castle ----------
func castle() -> void:
	ui.place_image = ""
	_selected = null
	Game.mode = "castle"
	Game.save_game()
	var has_party := not Game.party.is_empty()
	var body := "Banners bearing your names hang from the battlements. Trebor's Elite Guard drinks free at Gilgamesh's." if Game.won \
		else "Trebor's castle rises over the maze he claims he built on purpose. " + ("Your party waits by the gate." if has_party else "No party has been formed.")
	var need_party := "Form a party at Gilgamesh's Tavern first."
	ui.show_screen({"title": "Castle", "where": "Castle", "view": "castle", "map": true, "body": ui.flav(body), "opts": [
		{"k": "G", "label": "GILGAMESH'S TAVERN", "fn": tavern},
		{"k": "A", "label": "ADVENTURER'S INN", "dis": not has_party, "why": need_party, "fn": inn},
		{"k": "B", "label": "BOLTAC'S TRADING POST", "dis": not has_party, "why": need_party, "fn": boltac},
		{"k": "T", "label": "TEMPLE OF CANT", "dis": not has_party, "why": need_party, "fn": temple},
		{"k": "R", "label": "TRAINING GROUNDS", "fn": ui.chars.training},
		{"k": "M", "label": "MAZE", "dis": Game.living().is_empty(), "why": need_party, "fn": ui.mz.enter_maze},
		{"k": "E", "label": "EDGE OF TOWN", "fn": edge_of_town},
	]})


# ---------- Gilgamesh's Tavern ----------
func tavern() -> void:
	ui.place_image = TAVERN_IMAGE
	var ps := Game.party_chars()
	if not ps.has(_selected):
		_selected = null
	var chosen := _selected != null
	var opts := [
		{"k": "A", "label": "ADD", "in_widget": true, "hide": ps.size() >= MAX_PARTY, "fn": func(): ui.chars.roster_pick("Add whom?", _can_add, _add, tavern)},
		{"k": "R", "label": "REMOVE", "in_widget": true, "hide": not chosen, "fn": _remove.bind(_selected)},
		{"k": "D", "label": "DIVVY GOLD", "in_widget": true, "gear_at": "center", "dis": ps.is_empty(), "fn": _divvy},
		{"k": "I", "label": "INSPECT", "in_widget": true, "gear_at": "right", "hide": not chosen, "fn": ui.chars.inspect.bind(_selected, "tavern", tavern)},
		{"k": "L", "label": "EXIT", "fn": castle},
	]
	var hint := "Click a party member to select them." if not ps.is_empty() else "Add adventurers to form a party."
	ui.show_screen({"title": "Gilgamesh's Tavern", "where": "Gilgamesh's Tavern", "view": "tavern", "opts": opts,
		"gear_pick": select_member, "gear_hint": hint,
		"body": ui.flav("Smoke hangs over the scarred tables and a haunch of boar turns over the fire. Small groups of adventurers talk in low voices.")})


func select_member(c: Character) -> void:
	_selected = c
	tavern()


func _can_add(c: Character) -> bool:
	return c.loc == "CASTLE" and not Game.party.has(c.id) and Game.compatible(c)


func _add(c: Character) -> void:
	Game.party.append(c.id)
	Game.save_game()
	Game.say("%s JOINS THE PARTY.%s" % [c.name, "" if c.is_alive() else " (%s, CARRIED BY FRIENDS)" % c.status], "ok")
	tavern()


func _remove(c: Character) -> void:
	Game.party.erase(c.id)
	Game.save_game()
	Game.say("%s WANDERS BACK TO %s DRINK." % [c.name, c.his()])
	tavern()


func _divvy() -> void:
	Game.divvy()
	Game.save_game()
	Game.say("THE PARTY GOLD IS SPLIT EVENLY.", "gold")
	tavern()


# ---------- Boltac's Trading Post ----------
## The party with what each member has equipped.
func gear_grid(on_click := Callable(), click_dead := true) -> GridContainer:
	return PartyCards.grid(_fill_gear_cell, Game.party_chars().find(_selected), 4 + GEAR_SLOTS.size(), on_click, click_dead)


func _fill_gear_cell(v: VBoxContainer, c: Character, _slot: int) -> void:
	PartyCards.add_head(v, c, true)
	for gear in GEAR_SLOTS:
		var it: Variant = c.equipped(gear[1])
		var text := "%s: %s" % [gear[0], c.item_name(it) if it != null else "NONE"]
		var line := PartyCards.label(text, UiStyle.C_INK if it != null else UiStyle.C_DIM)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.add_theme_font_size_override("font_size", _gear_font(text))
		v.add_child(line)
	var gold := PartyCards.label("Gold: %d" % c.gold, UiStyle.C_TORCH)
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gold.add_theme_font_size_override("font_size", GEAR_FONT)
	v.add_child(gold)


## The largest size at which this line fits a card, so a long item name still reads in full.
func _gear_font(text: String) -> int:
	var sz := GEAR_FONT
	while sz > GEAR_FONT_MIN and ui.mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > ui.gear_line_room():
		sz -= 1
	return sz


func boltac() -> void:
	ui.place_image = BOLTAC_IMAGE
	var ps := Game.party_chars()
	if not ps.has(_selected):
		_selected = null
	var c := _selected
	var chosen := c != null
	ui.show_screen({"title": "Boltac's Trading Post", "where": "Boltac's Trading Post", "view": "shop",
		"gear_pick": shop, "gear_hint": "Click a party member to select them.",
		"body": ui.flav(BOLTAC_TEXT),
		"opts": [
			{"k": "B", "label": "BUY", "in_widget": true, "hide": not chosen, "fn": buy.bind(c, 0)},
			{"k": "S", "label": "SELL", "in_widget": true, "hide": not chosen, "fn": sell.bind(c)},
			{"k": "U", "label": "UNCURSE", "in_widget": true, "hide": not chosen or _fee_items(c, "U").is_empty(), "fn": fee_service.bind(c, "U")},
			{"k": "I", "label": "IDENTIFY", "in_widget": true, "hide": not chosen or _fee_items(c, "I").is_empty(), "fn": fee_service.bind(c, "I")},
			{"k": "P", "label": "POOL GOLD", "in_widget": true, "hide": not chosen, "fn": func(): Game.pool_gold(c); boltac()},
			{"k": "L", "label": "EXIT", "fn": castle},
		]})


## Selects a party member at Boltac's; the shop's other screens return here too.
func shop(c: Character) -> void:
	_selected = c
	boltac()


func buy(c: Character, page: int) -> void:
	var ids := []
	for k in Game.stock:
		if Game.stock[k] != 0:
			ids.append(k)
	var per := 7
	var items := []
	for id in ids.slice(page * per, page * per + per):
		var d: Dictionary = Data.ITEMS[id]
		var ok := String(d["cls"]).contains(c.cdata()["l"])
		var left: int = Game.stock[id]
		items.append({"label": ("" if ok else "#") + d["name"], "right": "%d GP%s" % [d["price"], " (%d)" % left if left > 0 else ""],
			"dis": c.gold < d["price"] or c.items.size() >= 8, "fn": _buy_one.bind(c, id, page, ok)})
	var pager := []
	if page > 0:
		pager.append({"k": "B", "label": "PREVIOUS", "fn": buy.bind(c, page - 1)})
	if (page + 1) * per < ids.size():
		pager.append({"k": "F", "label": "NEXT", "fn": buy.bind(c, page + 1)})
	ui.choose_list("Buy", "[font_size=%d]# Not usable by this character.[/font_size]" % BUY_NOTE_FONT, items, shop.bind(c), [], pager, _buy_for.bind(page))


## Clicking another living member's card keeps the list open for them.
func _buy_for(c: Character, page: int) -> void:
	_selected = c
	buy(c, page)


func _sell_for(c: Character) -> void:
	_selected = c
	sell(c)


func _buy_one(c: Character, id: String, page: int, ok: bool) -> void:
	var d: Dictionary = Data.ITEMS[id]
	var note := "" if ok else "%s can't use that, you know." % c.name
	ui.confirm_window(BUY_OFFER, "Buy %s for %d GP" % [d["name"], d["price"]], note, "Buy", "Not Now", _complete_buy.bind(c, id, page))


func _complete_buy(c: Character, id: String, page: int) -> void:
	var d: Dictionary = Data.ITEMS[id]
	c.gold -= d["price"]
	if Game.stock[id] > 0:
		Game.stock[id] -= 1
	c.add_item(id, true)
	Game.save_game()
	Game.say("\"A FINE CHOICE!\" %s BUYS A %s." % [c.name, d["name"]], "gold")
	buy(c, page)


func sell(c: Character) -> void:
	var items := []
	for it in c.items:
		var d: Dictionary = c.item_def(it)
		var sellable: bool = it["known"] and not it["cursed"] and not d.get("quest", false)
		items.append({"label": c.item_name(it), "right": ("%d GP" % _sell_price(c, it) if sellable else "NO SALE") + (" *" if it["eq"] else ""),
			"dis": not sellable, "fn": _sell_one.bind(c, it)})
	ui.choose_list("Sell", ui.flav("Boltac pays half of what he charges. He will not buy cursed or unidentified goods."), items, shop.bind(c), [], null, _sell_for)


func _sell_one(c: Character, it: Dictionary) -> void:
	var note := "%s has that equipped." % c.name if it["eq"] else ""
	ui.confirm_window(SELL_OFFER, "Sell %s for %d GP" % [c.item_name(it), _sell_price(c, it)], note, "Sell", "Maybe Later", _complete_sell.bind(c, it))


func _sell_price(c: Character, it: Dictionary) -> int:
	return 0 if it.get("broken", false) else int(c.item_def(it)["price"]) / 2


func _complete_sell(c: Character, it: Dictionary) -> void:
	var price := _sell_price(c, it)
	c.gold += price
	c.items.erase(it)
	if not it.get("broken", false) and Game.stock.get(it["id"], 0) != -1:
		Game.stock[it["id"]] = int(Game.stock.get(it["id"], 0)) + 1
	Game.save_game()
	Game.say("%s SELLS THE %s FOR %d GOLD." % [c.name, c.item_name(it), price], "gold")
	sell(c)


## The items Boltac could uncurse (kind U) or identify (kind I).
func _fee_items(c: Character, kind: String) -> Array:
	return c.items.filter(func(it): return it["cursed"] if kind == "U" else not it["known"])


func fee_service(c: Character, kind: String) -> void:
	var list := _fee_items(c, kind)
	if list.is_empty():
		Game.say("NOTHING CURSED HERE. BOLTAC LOOKS DISAPPOINTED." if kind == "U" else "EVERYTHING IS ALREADY IDENTIFIED.")
		shop(c)
		return
	var items := []
	for it in list:
		var fee := maxi(10, int(c.item_def(it)["price"]) / 2)
		items.append({"label": c.item_name(it), "right": "%d GP" % fee, "dis": c.gold < fee, "fn": _do_fee.bind(c, it, kind, fee)})
	ui.choose_list("Uncurse" if kind == "U" else "Identify", "", items, shop.bind(c))


func _do_fee(c: Character, it: Dictionary, kind: String, fee: int) -> void:
	c.gold -= fee
	if kind == "U":
		c.items.erase(it)
		Game.say("BOLTAC PRIES THE %s LOOSE AND KEEPS IT." % c.item_name(it), "gold")
	else:
		it["known"] = true
		Game.say("\"AH, A %s!\" SAYS BOLTAC." % c.item_name(it), "gold")
	Game.save_game()
	shop(c)


# ---------- Temple of Cant ----------
func _tithe(c: Character) -> int:
	return int({"DEAD": 250, "ASHES": 500, "PARALYZED": 100, "ASLEEP": 10}.get(c.status, 0)) * c.lvl


func temple() -> void:
	ui.place_image = TEMPLE_IMAGE
	var items := []
	for c in Game.party_chars():
		if _tithe(c) > 0:
			items.append({"label": c.name, "right": "%s · %d GP" % [c.status, _tithe(c)], "fn": _temple_who_pays.bind(c)})
	var body: String = ui.flav("Robed priests chant before the altar. Their healing is certain, except for the dead. Raising the dead may fail, and ashes are a last chance.")
	if items.is_empty():
		body += "\n\nNo one in your party needs the priests."
	ui.choose_list("Temple of Cant", body, items, castle)


func _temple_who_pays(c: Character) -> void:
	ui.pick_member("Who pays the %d gold tithe?" % _tithe(c), temple, _temple_heal.bind(c))


func _temple_heal(payer: Character, c: Character) -> void:
	var fee := _tithe(c)
	if payer.gold < fee:
		Game.pool_gold(payer)
	if payer.gold < fee:
		Game.say("\"YOU CANNOT AFFORD THE TITHE, CHEAPSKATE!\"", "hit")
		temple()
		return
	payer.gold -= fee
	var msg := ""
	var age_pen := c.age / 52 - 20
	if c.status == "DEAD":
		if Dice.chance(45 + c.stats["vit"] * 3 - age_pen):
			c.status = "OK"
			c.hp = 1
			c.stats["vit"] = maxi(3, c.stats["vit"] - 1)
			msg = "%s IS ALIVE AND WELL. (1 HIT POINT)" % c.name
		else:
			c.status = "ASHES"
			msg = "OOPS! %s NEEDS MORE HELP. %s IS NOW ASHES." % [c.name, c.name]
	elif c.status == "ASHES":
		if Dice.chance(35 + c.stats["vit"] * 3 - age_pen):
			c.status = "OK"
			c.hp = c.maxhp
			c.stats["vit"] = maxi(3, c.stats["vit"] - 1)
			msg = "%s RISES FROM THE ASHES, FULLY HEALED!" % c.name
		else:
			c.status = "LOST"
			msg = "%s IS LOST FOREVER. THE TEMPLE GIVES A FREE BURIAL." % c.name
			Game.party.erase(c.id)
			Game.roster.erase(c)
	else:
		c.status = "OK"
		msg = "%s IS WELL AGAIN." % c.name
	c.age += 52
	Game.save_game()
	ui.say("Temple of Cant", "MURMUR - CHANT - PRAY - INVOKE!\n\n" + ui.esc(msg), temple)


# ---------- Adventurer's Inn ----------
func inn() -> void:
	ui.place_image = INN_IMAGE
	ui.pick_member("Adventurer's Inn: who checks in?", castle, inn_rooms, func(c): return c.is_alive() and c.status != "PARALYZED")


func inn_rooms(c: Character) -> void:
	var items := []
	for r in Data.ROOMS:
		items.append({"label": r[0], "right": ("%d HP/WEEK · %d GP" % [r[1], r[2]]) if r[1] > 0 else "FREE · NO HEALING", "dis": r[2] > c.gold, "fn": stay.bind(c, r[1], r[2])})
	ui.choose_list("Welcome, %s" % c.name, "HITS %d/%d · GOLD %d · AGE %d\n" % [c.hp, c.maxhp, c.gold, c.age / 52] + ui.flav("Each room restores hit points by the week. Every week in bed is a week older."),
		items, inn, [{"k": "P", "label": "POOL GOLD", "fn": func(): Game.pool_gold(c); inn_rooms(c)}])


func stay(c: Character, heal: int, fee: int) -> void:
	var weeks := 0
	if heal > 0:
		while c.hp < c.maxhp and c.gold >= fee:
			c.gold -= fee
			c.hp = mini(c.maxhp, c.hp + heal)
			weeks += 1
	weeks = maxi(weeks, 1)
	c.age += weeks
	var lines := ["%s RESTS %d WEEK%s. HITS %d/%d, GOLD %d." % [c.name, weeks, "S" if weeks > 1 else "", c.hp, c.maxhp, c.gold]]
	var need := Data.xp_needed(c.cls, c.lvl)
	if c.xp >= need:
		lines.append_array(c.level_up())
	else:
		lines.append("YOU NEED %d MORE EXPERIENCE POINTS TO MAKE LEVEL %d." % [need - c.xp, c.lvl + 1])
	var el := Character.eligible(c.stats, c.align).filter(func(k): return k != c.cls)
	if not el.is_empty() and c.lvl > 1:
		lines.append("%s NOW QUALIFIES AS: %s." % [c.name, ", ".join(el)])
	Game.save_game()
	ui.say("Adventurer's Inn", ui.esc("\n".join(lines)), inn)


# ---------- Edge of Town & Utilities ----------
func edge_of_town() -> void:
	var any_alive := not Game.living().is_empty()
	ui.show_screen({"title": "Edge of Town", "where": "Edge of Town", "view": "edge",
		"body": ui.flav("Screams and loud munching drift up from the stair to the Maze.") + ("" if not Game.party.is_empty() else "\n\nForm a party in the Tavern before entering the Maze."),
		"opts": [
			{"k": "M", "label": "MAZE", "dis": not any_alive, "fn": ui.mz.enter_maze},
			{"k": "T", "label": "TRAINING GROUNDS", "fn": ui.chars.training},
			{"k": "U", "label": "UTILITIES", "fn": utilities},
			{"k": "C", "label": "CASTLE", "fn": castle},
			{"k": "Q", "label": "EXIT GAME", "fn": func(): Game.save_game(); ui.get_tree().quit()},
		]})


func utilities() -> void:
	ui.show_screen({"title": "Utilities", "where": "Utilities", "view": "edge", "opts": [
		{"k": "C", "label": "CHANGE NAME", "fn": func(): ui.chars.roster_pick("Rename whom?", func(_c): return true, _rename, utilities)},
		{"k": "R", "label": "RESTART AN \"OUT\" PARTY", "dis": Game.outs.is_empty() or not Game.party.is_empty(), "fn": restart_out},
		{"k": "L", "label": "EXIT", "fn": edge_of_town},
	]})


func _rename(c: Character) -> void:
	ui.show_screen({"title": "Rename %s" % c.name, "view": "edge", "body": "Type the new name, then choose OK.",
		"input": {"ph": "NEW NAME", "fn": func(v): _do_rename(c, v)}, "opts": [{"k": "Escape", "label": "EXIT", "fn": utilities}]})


func _do_rename(c: Character, v: String) -> void:
	var taken := Game.roster.any(func(o): return o.name == v)
	if v != "" and not taken:
		c.name = v
		Game.save_game()
		Game.say("NOW KNOWN AS %s." % v)
	utilities()


func restart_out() -> void:
	var items := []
	for i in Game.outs.size():
		var o: Dictionary = Game.outs[i]
		var names := []
		for cid in o["ids"]:
			var c := Game.ch(cid)
			if c != null:
				names.append(c.name)
		items.append({"label": ", ".join(names), "right": "LEVEL %d" % o["pos"]["z"], "fn": _restart.bind(i)})
	ui.choose_list("Restart which party?", ui.flav("The whole party returns to exactly where it was left."), items, utilities)


func _restart(i: int) -> void:
	var o: Dictionary = Game.outs[i]
	Game.outs.remove_at(i)
	Game.party.clear()
	for cid in o["ids"]:
		var c := Game.ch(cid)
		if c != null and c.loc == "OUT":
			Game.party.append(c.id)
			c.loc = "MAZE"
	Game.pos = o["pos"].duplicate()
	Game.light = 0
	Game.maporfic = 0
	Game.latumapic = false
	Game.cleared = {}
	ui.mz.camp()


func return_to_castle() -> void:
	for c in Game.party_chars():
		c.loc = "CASTLE"
		c.cac = 0
		if c.status == "POISON" or c.status == "ASLEEP":
			c.status = "OK"
	Game.light = 0
	Game.maporfic = 0
	Game.latumapic = false
	Game.mode = "castle"
	for c in Game.party_chars():
		for it in c.items:
			if it["id"] == "amulet" and not Game.won:
				victory(c, it)
				return
	Game.save_game()
	Game.say("THE PARTY CLIMBS BACK INTO THE DAYLIGHT. ANY POISON IS CURED.", "ok")
	castle()


func victory(holder: Character, amulet: Dictionary) -> void:
	Game.won = true
	holder.items.erase(amulet)
	for c in Game.party_chars():
		c.honor = true
		c.xp += 5000
		c.gold += 2000
	Game.save_game()
	ui.say("The Amulet returns", "Trebor snatches the amulet from %s before the dust has settled on your boots. His eyes gleam.\n\n" % ui.esc(holder.name) +
		"\"Splendid. You are all inducted into my Elite Guard, effective immediately. Refusal would be... unwise.\"\n\n" +
		"EACH SURVIVOR GAINS 5000 EXPERIENCE AND 2000 GOLD, AND WEARS THE MARK OF HONOR (&).\n\n" +
		ui.flav("Knight of Diamonds and the scenarios beyond still await. Your characters can keep adventuring."), castle)

extends Node
## The self-test body. Loaded by tools/selftest.gd after the autoloads are registered.

var main
var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


## The words in the open confirmation window.
func confirm_text() -> String:
	if main._confirm_box == null:
		return ""
	return " | ".join(main._confirm_box.find_children("*", "Label", true, false).map(func(l): return l.text))


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
	g.settings_path = "user://selftest_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(g.settings_path))
	g.load_settings()
	if FileAccess.file_exists(g.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(g.save_path))
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	main.fight.instant = true
	await get_tree().process_frame
	check(main.scr.get("title", "") == "Welcome to the Underworlds", "welcome screen on a fresh roster")

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
	main.scr["widget"].get_node("HUMAN").pressed.emit()
	main.scr["side"].find_child("Choose", true, false).pressed.emit()
	press("G")
	check(main.scr["title"].begins_with("NEWBIE"), "attribute rolling screen")
	check(not main.has_method("_input"), "the game takes no keyboard commands")
	_test_attribute_rolls()
	press("L")
	check(not main.dice_tray().visible, "the dice leave with the screen")
	main.chars.create_name()
	main._entry.text = "buttoned"
	check(_row_labels("left") == ["SELECT"] and _row_labels("right") == ["BACK"], "the name screen has SELECT, and BACK at the right")
	check(_row_button("right", 0).get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "BACK is brown")
	check(main.scr["opts"][0]["fn"] == main.chars.training, "and goes back to the Training Grounds")
	_row_button("left", 0).pressed.emit()
	check(main.scr["title"] == "BUTTONED: choose a race", "the SELECT button submits typed text")
	check(main.scr["body"] == "Select a race to see bonus stats:", "the race screen asks for a race")
	main.scr["widget"].get_node("Leave").pressed.emit()

	# --- town ---
	print("town")
	for c in party:
		g.party.append(c.id)
	main.town.tavern()
	main.town.select_member(g.party_chars()[0])
	press("I")
	check(main.scr["title"] == "Inspect", "inspect from the tavern")
	press("L")
	main.town.shop(party[0])
	press("B")
	press("F")
	press("B")
	main.town.buy(party[0], 0)
	var buy_gold: int = party[0].gold
	press("4")  # LONG SWORD
	check(main._confirm_box != null and party[0].items.is_empty(), "buying asks first")
	check(confirm_text() == "I will haggle no further, this is my best price! | Buy LONG SWORD for 25 GP", "the buy window names the item and price")
	check(main._confirm_yes.text == "Buy" and main._confirm_no.text == "Not Now", "the buy window's buttons")
	main._confirm_no.pressed.emit()
	check(main._confirm_box == null and party[0].items.is_empty() and party[0].gold == buy_gold and main.scr["title"] == "Buy", "Not Now buys nothing and stays on the list")
	press("4")
	main._confirm_yes.pressed.emit()
	check(main._confirm_box == null and party[0].gold == buy_gold - 25, "Buy pays and closes the window")
	check(party[0].items.size() == 1, "bought a sword (got %d items)" % party[0].items.size())
	main.town._buy_one(party[0], "staff", 0, false)
	check(confirm_text().contains("can't use that"), "the buy window warns when the buyer can't use the item")
	main._confirm_no.pressed.emit()
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
	var sell_item: Dictionary = party[5].items[0]
	var sell_gold: int = party[5].gold
	var sell_price: int = main.town._sell_price(party[5], sell_item)
	press("1")
	check(confirm_text().begins_with("This is my offer, take it or leave it... | Sell %s for %d GP" % [party[5].item_name(sell_item), sell_price]), "the sell window names the item and price")
	check(main._confirm_yes.text == "Sell" and main._confirm_no.text == "Maybe Later", "the sell window's buttons")
	check(confirm_text().contains("has that equipped") == sell_item["eq"], "the sell window warns about an equipped item")
	main._confirm_no.pressed.emit()
	check(party[5].items.has(sell_item) and party[5].gold == sell_gold and main.scr["title"] == "Sell", "Maybe Later keeps the item and stays on the list")
	press("1")
	main._confirm_yes.pressed.emit()
	check(not party[5].items.has(sell_item) and party[5].gold == sell_gold + sell_price and main._confirm_box == null, "Sell takes the item and pays")
	var broken_price: Dictionary = {"id": "lsword", "broken": true}
	check(main.town._sell_price(party[5], broken_price) == 0, "a broken item is worth nothing")
	party[5].status = "DEAD"
	main.town.temple()
	check(main._backdrop.visible, "the temple shows its painting")
	var temple_art: Texture2D = main._backdrop.texture
	check(temple_art != null and absf(float(temple_art.get_width()) / temple_art.get_height() - 16.0 / 9.0) < 0.001, "the temple painting is 16:9")
	press("1")
	check(main._backdrop.visible, "the tithe question keeps the painting")
	press("1")  # payer
	check(main.scr["title"] == "Temple of Cant", "temple tithe resolves (bind order)")
	check(main._backdrop.visible, "the temple's answer keeps the painting")
	press("Enter")
	press("L")
	check(main.scr["title"] == "Castle" and not main._backdrop.visible and main.town_map.visible, "leaving the temple returns to the map")
	main.show_screen({"title": "Unpainted", "view": "edge"})
	check(not main._backdrop.visible and main._view_box.visible and main._header.visible, "screens without a painting keep the normal layout")
	main.town.tavern()
	var tavern_art: Texture2D = main._backdrop.texture
	check(main._gear.visible and not main._table.visible, "the tavern shows the party as a grid instead of the table")
	check(is_equal_approx(main._gear.get_theme_stylebox("panel").bg_color.a, main.GEAR_PANEL_ALPHA) and is_equal_approx(main._panel.get_theme_stylebox("panel").bg_color.a, main.BACKDROP_PANEL_ALPHA), "the painting shows through the panels")
	check(is_equal_approx(main._gear_grid.get_child(0).get_theme_stylebox("panel").bg_color.a, TownScreens.CARD_ALPHA), "the painting shows through the cards")
	check(main._gear_grid.get_child_count() == PartyCards.COLUMNS * PartyCards.ROWS, "the tavern's grid has every party slot")
	var tavern_button := func(label: String) -> Button:
		for b in main._gear_row.find_children("*", "Button", true, false):
			if b.text == label:
				return b
		return null
	var tavern_labels := func() -> Array:
		return main.scr["opts"].filter(func(o): return not o.get("in_widget", false) and not o.get("hide", false) and o["label"] != "EXIT").map(func(o): return o["label"])
	var tavern_party: Array = g.party.duplicate()
	var tavern_first: Character = g.party_chars()[0]
	var tavern_few: Array = tavern_party.slice(0, 3)
	g.party.assign(tavern_few)
	main.town.tavern()
	check(tavern_labels.call().is_empty(), "the left panel no longer lists party members or buttons")
	check(tavern_button.call("ADD") != null and tavern_button.call("DROP") == null and tavern_button.call("INSPECT") == null, "with nobody selected, DROP and INSPECT stay hidden")
	check(tavern_button.call("DIVVY GOLD") != null, "DIVVY GOLD sits under the cards")
	var exit_button := func() -> Button:
		return main._exit_row.get_child(main._exit_row.get_child_count() - 1)
	check(main._exit_row.visible and exit_button.call().text == "EXIT" and tavern_button.call("EXIT") == null, "EXIT sits in the left panel, not under the cards")
	check(main._exit_row.alignment == BoxContainer.ALIGNMENT_END, "EXIT sits on the right of the left panel")
	check(not main.scr["body"].contains("Click a party member"), "the hint has left the left panel")
	var hint_label: Label = main._gear_grid.get_parent().get_child(0)
	check(hint_label.text == "Click a party member to select them." and hint_label.get_theme_font_size("font_size") == 18, "the hint tops the cards, four sizes smaller")
	check(exit_button.call().get_theme_stylebox("normal").bg_color == main.PAGER_EXIT_FILL and exit_button.call().get_theme_font_size("font_size") < 22, "the main screen's EXIT is small and red")
	check(main._exit_row.get_parent() == main._body.get_parent() and main._exit_row.get_index() > main._body.get_index() and main._exit_row.get_index() < main._log.get_index(), "EXIT sits under the text, above the log")
	var tavern_cell: Control = main._gear_grid.get_child(0)
	var tavern_hit: Button = tavern_cell.get_child(1)
	tavern_hit.pressed.emit()
	check(main._gear_grid.get_child(0).get_theme_stylebox("panel").border_color == UiStyle.C_TORCH, "clicking a card selects that member")
	var tavern_row: Control = main._gear_row
	check(tavern_button.call("ADD").get_parent() == tavern_row.get_child(0) and tavern_button.call("ADD").get_index() == 0 and tavern_button.call("DROP").get_index() == 1, "DROP sits right of ADD")
	check(tavern_button.call("DIVVY GOLD").get_parent() == tavern_row.get_child(1), "DIVVY GOLD sits in the center")
	for brown_label in ["ADD", "DROP", "DIVVY GOLD", "INSPECT"]:
		var brown: Button = tavern_button.call(brown_label)
		check(brown.get_theme_stylebox("normal").bg_color == main.PAGER_FILL and brown.get_theme_font_size("font_size") == main.PAGER_FONT, "the Tavern's %s is small and brown" % brown_label)
	check(tavern_button.call("INSPECT").get_parent() == tavern_row.get_child(2), "INSPECT sits at the far right")
	tavern_button.call("INSPECT").pressed.emit()
	check(main.scr["title"] == "Inspect" and main._sheet.visible and main._sheet.find_child("Stats", true, false).text.contains(tavern_first.name), "INSPECT opens the selected member's sheet")
	press("L")
	check(main._gear_grid.get_child(0).get_theme_stylebox("panel").border_color == UiStyle.C_TORCH, "the selection survives inspecting")
	tavern_button.call("DROP").pressed.emit()
	check(not g.party.has(tavern_first.id) and g.party.size() == tavern_few.size() - 1, "DROP takes the selected member out of the party")
	check(tavern_button.call("DROP") == null and tavern_button.call("INSPECT") == null, "removing clears the selection")
	g.party.assign(tavern_party)
	main.town.tavern()
	check(g.party.size() == main.town.MAX_PARTY and tavern_button.call("ADD") == null, "a full party hides ADD")
	g.party.assign(tavern_few)
	main.town.select_member(tavern_first)
	main.town.castle()
	main.town.tavern()
	check(tavern_button.call("DROP") == null, "leaving the tavern clears the selection")
	main.town.boltac()
	check(main.scr["body"].contains("cedar shavings"), "Boltac's has its description")
	check(tavern_labels.call().is_empty() and exit_button.call().text == "EXIT", "Boltac's lists no names and has EXIT in the left panel")
	check(not main.scr["body"].contains("Click a party member") and main._gear_grid.get_parent().get_child(0).text == "Click a party member to select them.", "Boltac's hint tops the cards too")
	check(tavern_button.call("BUY") == null and tavern_button.call("POOL GOLD") == null, "nobody selected at Boltac's, no shop buttons")
	main._gear_grid.get_child(1).get_child(1).pressed.emit()
	check(main._gear_grid.get_child(1).get_theme_stylebox("panel").border_color == UiStyle.C_TORCH, "clicking a card at Boltac's selects that member")
	check(tavern_labels.call().is_empty() and tavern_button.call("BUY") != null and tavern_button.call("SELL") != null and tavern_button.call("POOL GOLD") != null, "selecting at Boltac's offers the shop under the cards")
	for shop_label in ["BUY", "SELL", "POOL GOLD"]:
		var shop_button: Button = tavern_button.call(shop_label)
		check(shop_button.get_theme_stylebox("normal").bg_color == main.PAGER_FILL and shop_button.get_theme_font_size("font_size") == main.PAGER_FONT, "Boltac's %s is small and brown" % shop_label)
	var fee_hero: Character = g.party_chars()[1]
	var fee_keep: Array = fee_hero.items
	fee_hero.items = []
	main.town.shop(fee_hero)
	check(tavern_button.call("UNCURSE") == null and tavern_button.call("IDENTIFY") == null, "no cursed or unknown items, no UNCURSE or IDENTIFY")
	fee_hero.add_item("lsword", false)
	main.town.shop(fee_hero)
	check(tavern_button.call("UNCURSE") == null and tavern_button.call("IDENTIFY") != null, "an unidentified item offers IDENTIFY")
	fee_hero.items[0]["known"] = true
	fee_hero.items[0]["cursed"] = true
	main.town.shop(fee_hero)
	check(tavern_button.call("UNCURSE") != null and tavern_button.call("IDENTIFY") == null, "a cursed item offers UNCURSE")
	fee_hero.items = fee_keep
	main.town.shop(fee_hero)
	check(not main.scr["body"].contains(" HAS ") and not main.scr["body"].contains("ITEMS "), "Boltac's left panel doesn't repeat the member's gold and items")
	press("B")
	check(main.scr["title"] == "Buy" and main._gear_grid.get_child(1).get_theme_stylebox("panel").border_color == UiStyle.C_TORCH, "the buyer stays highlighted while buying")
	var switch_from: Character = g.party_chars()[1]
	var switch_to: Character = g.party_chars()[2]
	main.town.buy(switch_from, 1)
	check(main._gear_grid.get_child(2).get_child_count() == 2, "another member's card can be clicked while buying")
	check(main._gear_grid.get_parent().get_child(0).text == TownScreens.SELECT_HINT, "the hint stays up while buying")
	check(main.scr["opts"][-1]["label"] == "BACK" and main._pager_row.get_child(-1).text == "BACK", "Buy leaves by BACK")
	main._gear_grid.get_child(2).get_child(1).pressed.emit()
	check(main.town._selected == switch_to and main.scr["title"] == "Buy" and main._gear_grid.get_child(2).get_theme_stylebox("panel").border_color == UiStyle.C_TORCH, "clicking a card switches the buyer and stays on Buy")
	check(main._pager_row.get_child(0).text == "PREVIOUS", "switching the buyer keeps the page")
	var switch_status: String = switch_to.status
	switch_to.status = "DEAD"
	main.town.buy(switch_from, 0)
	check(main._gear_grid.get_child(2).get_child_count() == 1 and main._gear_grid.get_child(1).get_child_count() == 2, "a dead member's card can't be clicked while buying")
	main.town.sell(switch_from)
	check(main._gear_grid.get_child(2).get_child_count() == 1 and main._gear_grid.get_child(1).get_child_count() == 2, "nor while selling")
	switch_to.status = switch_status
	main.town.sell(switch_from)
	check(main._gear_grid.get_parent().get_child(0).text == TownScreens.SELECT_HINT, "and while selling")
	check(main.scr["opts"][-1]["label"] == "BACK" and main._pager_row.get_child(-1).text == "BACK", "Sell leaves by BACK")
	main._gear_grid.get_child(2).get_child(1).pressed.emit()
	check(main.town._selected == switch_to and main.scr["title"] == "Sell", "clicking a card switches the seller and stays on Sell")
	main.town.shop(switch_from)
	press("B")
	var pager_labels := func() -> Array:
		return main._pager_row.get_children().filter(func(n): return n is Button).map(func(n): return n.text)
	check(main.scr["body"].contains("# Not usable by this character.") and not main.scr["body"].contains(" GOLD"), "the Buy note drops the gold")
	check(main.scr["body"].contains("[font_size=18]"), "the Buy note is four sizes smaller")
	check(pager_labels.call() == ["NEXT", "BACK"], "the first page has NEXT and BACK on one row")
	var pager_spacer: Control = main._pager_row.get_parent().get_child(main._pager_row.get_index() - 1)
	check(pager_spacer.custom_minimum_size.y + main._opts_col.get_theme_constant("separation") == main.PAGER_DROP, "the row sits 15 lower")
	var pager_exit: Button = main._pager_row.get_child(main._pager_row.get_child_count() - 1)
	check(pager_exit.get_index() == main._pager_row.get_child_count() - 1 and main._pager_row.get_child(pager_exit.get_index() - 1).size_flags_horizontal == Control.SIZE_EXPAND_FILL, "BACK is on the right of the row")
	check(main._pager_row.get_child(0).get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "the page buttons are brown")
	check(pager_exit.get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "BACK is brown too")
	check(main._pager_row.get_child(0).get_theme_font_size("font_size") < 22, "the page buttons are smaller")
	main.town.sell(g.party_chars()[1])
	check(pager_labels.call() == ["BACK"] and main._pager_row.get_child(main._pager_row.get_child_count() - 1).get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "Sell has the small brown BACK under its list")
	press("L")
	press("B")
	press("F")
	check(pager_labels.call().slice(0, 2) == ["PREVIOUS", "NEXT"] or pager_labels.call() == ["PREVIOUS", "BACK"], "later pages offer PREVIOUS first")
	press("B")
	press("L")
	check(main.scr["title"] == "Boltac's Trading Post" and tavern_button.call("BUY") != null, "leaving Buy returns to the shop with the member still selected")
	main.town.castle()
	main.town.boltac()
	check(tavern_button.call("BUY") == null, "coming back to Boltac's starts with nobody selected")
	g.party.assign(tavern_party)
	main.town.tavern()
	check(main._backdrop.visible and tavern_art != temple_art, "the tavern shows its own painting")
	check(tavern_art != null and absf(float(tavern_art.get_width()) / tavern_art.get_height() - 16.0 / 9.0) < 0.001, "the tavern painting is 16:9")
	main.chars.roster_pick("Add whom?", main.town._can_add, main.town._add, main.town.tavern)
	check(main._backdrop.texture == tavern_art, "adding a member keeps the tavern painting")
	press("L")
	main.town.select_member(tavern_first)
	press("R")
	check(main._backdrop.texture == tavern_art, "removing a member keeps the tavern painting")
	g.party.assign(tavern_party)
	main.town.select_member(tavern_first)
	press("I")
	check(main.scr["title"] == "Inspect" and main._backdrop.texture == tavern_art, "inspecting keeps the tavern painting")
	var inspect_hero: Character = g.party_chars()[0]
	var inspect_keep: String = inspect_hero.portrait
	inspect_hero.portrait = "female_1"
	main.chars.inspect(inspect_hero, "tavern", main.town.tavern)
	check(not main._gear.visible and not main._portrait.visible and main._sheet.visible, "inspecting gives the grid's place to the character sheet")
	var sheet_part := func(part: String) -> Node:
		return main._sheet.find_child(part, true, false)
	check(sheet_part.call("Portrait").texture == load(inspect_hero.portrait_path()), "the sheet has the portrait")
	var sheet_stats: String = sheet_part.call("Stats").text
	check(sheet_stats.contains("STRENGTH") and sheet_stats.contains("GOLD") and sheet_stats.contains("HITS") and sheet_stats.contains("STATUS"), "the sheet has the statistics")
	check(sheet_part.call("Items").text == main.item_lines(inspect_hero), "the sheet lists the equipment")
	var sheet_buttons := func(section: String) -> Array:
		return sheet_part.call(section).find_children("*", "Button", true, false).map(func(b): return b.text)
	check(sheet_buttons.call("SpellBook") == ["READ"], "READ sits by the Spell Book heading")
	check(sheet_buttons.call("Equipment").slice(0, 3) == ["EQUIP", "DISCARD", "TRADE"], "EQUIP, DISCARD and TRADE sit by the Equipment heading")
	check(_row_labels("left") == ["POOL GOLD"] and _row_labels("right") == ["BACK"], "the bio's window has POOL GOLD, and BACK at the right")
	var left_buttons: Array = [_row_button("left", 0), _row_button("right", 0)]
	check(left_buttons.all(func(b): return b.get_theme_stylebox("normal").bg_color == main.PAGER_FILL and b.get_theme_font_size("font_size") == main.PAGER_FONT), "and they are small and brown")
	check(main._sheet.find_children("*", "Button", true, false).all(func(b): return b.text != "EXIT" and b.text != "BACK" and b.text != "POOL GOLD"), "and neither is on the sheet")
	var sheet_kids: Array = sheet_part.call("Equipment").get_parent().get_children()
	check(sheet_kids.find(sheet_part.call("Equipment")) == sheet_kids.find(sheet_part.call("Spells")) + 1 and sheet_part.call("Spells").fit_content, "Equipment follows straight after the spells, however few")
	check(main._body.visible and main._body.text == main.esc(inspect_hero.bio()), "the left panel has the character's bio")
	var bio_hero: Character = g.make_char("BIOGRAPH", "HUMAN", "GOOD", Data.RACES["HUMAN"].duplicate(), "FIGHTER", "FEMALE", "female_4")
	g.roster.erase(bio_hero)
	check(bio_hero.bio() == "BIOGRAPH is a good level 1 fighter. BIOGRAPH has yet to level up. She has ventured into the maze 0 times and has slain 0 creatures. She has found 0 gold and 0 items.", "a new character's bio is short")
	bio_hero.align = "EVIL"
	check(bio_hero.bio().begins_with("BIOGRAPH is an evil level 1 fighter."), "an evil character is AN evil one")
	bio_hero.level_up()
	check(bio_hero.last_level_date == Character.date_today() and bio_hero.bio().contains("BIOGRAPH last leveled up on %s." % Character.date_today()), "the bio has the date of the last level up")
	Character.add_to(bio_hero.weapon_damage, "LONG SWORD", 30)
	Character.add_to(bio_hero.weapon_damage, "DAGGER", 10)
	Character.add_to(bio_hero.spell_damage, "HALITO", 90)
	check(bio_hero.bio().contains("Her favorite weapon is the Long Sword."), "a fighter's favorite is the weapon that did the most damage")
	bio_hero.cls = "MAGE"
	check(bio_hero.bio().contains("Her favorite spell is Halito."), "a mage's favorite is a spell")
	bio_hero.cls = "FIGHTER"
	bio_hero.weapon_damage = {Character.BARE_HANDS: 5}
	check(bio_hero.bio().contains("Her favorite weapon is Bare Hands."), "bare hands can be a favorite")
	Character.add_to(bio_hero.kills, "ORC", 2)
	Character.add_to(bio_hero.kills, "RAT", 5)
	bio_hero.maze_trips = 1
	bio_hero.gold_found = 120
	bio_hero.items_found = 1
	check(bio_hero.bio().ends_with("She has ventured into the maze 1 time and has slain 7 creatures. She is an expert at killing %s. She has found 120 gold and 1 item." % String(Data.MONS["RAT"].get("pl", Data.MONS["RAT"]["n"] + "S")).capitalize()), "the bio counts the maze, kills, gold and items")
	bio_hero.sex = "MALE"
	check(bio_hero.bio().contains("His favorite weapon") and bio_hero.bio().contains("He has ventured") and bio_hero.bio().contains("He is an expert") and bio_hero.bio().contains("He has found"), "a man's bio says He and His")
	bio_hero.sex = "FEMALE"
	var bio_saved := Character.from_dict(JSON.parse_string(JSON.stringify(bio_hero.to_dict())))
	check(bio_saved.bio() == bio_hero.bio(), "the bio survives a save")
	var bio_old: Dictionary = bio_hero.to_dict()
	for bio_key in ["last_level_date", "weapon_damage", "spell_damage", "kills", "maze_trips", "gold_found", "items_found"]:
		bio_old.erase(bio_key)
	check(Character.from_dict(bio_old).bio().contains("0 creatures"), "older saves load with an empty bio")
	var bio_gold: int = inspect_hero.gold_found
	g.split_gold(g.living().size() * 3)
	check(inspect_hero.gold_found == bio_gold + 3 or not inspect_hero.is_alive(), "shares of found gold count as found")
	var bio_battle := Battle.new()
	bio_battle.groups.append(Battle.mk_group("ORC", 1))
	bio_battle.groups[0]["ms"][0]["hp"] = 1
	bio_hero.items = []
	bio_hero.status = "OK"
	bio_hero.kills = {}
	bio_hero.weapon_damage = {}
	bio_battle._acts = [{"c": bio_hero, "type": "fight", "g": 0}]
	while bio_hero.kills.is_empty() and bio_battle.groups[0]["ms"][0]["hp"] > 0:
		bio_battle._acts = [{"c": bio_hero, "type": "fight", "g": 0}]
		bio_battle.step()
	check(bio_hero.kills.get("ORC", 0) == 1 and bio_hero.weapon_damage.get(Character.BARE_HANDS, 0) > 0, "landing the killing blow counts the kill and the damage")
	bio_battle.groups[0]["ms"][0]["dead"] = false
	bio_battle.groups[0]["ms"][0]["hp"] = 1
	bio_battle._hurt(bio_battle.groups[0]["ms"][0], 5)
	check(bio_hero.kills["ORC"] == 1, "a kill with nobody acting goes to no one")
	var sheet_keep: Array = inspect_hero.spells
	inspect_hero.spells = ["KATINO", "HALITO", "DIOS"]
	main.chars.inspect(inspect_hero, "tavern", main.town.tavern)
	var sheet_spells: String = sheet_part.call("Spells").text
	check(sheet_spells.contains("HALITO") and sheet_spells.contains("KATINO") and sheet_spells.contains("DIOS"), "the sheet lists the known spells")
	inspect_hero.spells = []
	main.chars.inspect(inspect_hero, "tavern", main.town.tavern)
	check(sheet_part.call("Spells").text.contains("NO SPELLS"), "and says when there are none")
	inspect_hero.spells = sheet_keep
	main.town.tavern()
	check(not main._sheet.visible and main._gear.visible, "the sheet closes with the screen")
	inspect_hero.portrait = inspect_keep
	main.chars.inspect(inspect_hero, "tavern", main.town.tavern)
	press("R")
	check(main._backdrop.texture == tavern_art, "the spell books keep the tavern painting")
	press("Enter")
	press("L")
	check(main.scr["title"] == "Gilgamesh's Tavern", "inspect returns to the tavern")
	check(main._gear.visible, "the grid comes back after inspecting")
	press("L")
	check(main.scr["title"] == "Castle" and not main._backdrop.visible, "leaving the tavern clears its painting")
	check(not main._gear.visible, "leaving the tavern clears the grid")
	party[5].status = "OK"
	party[5].hp = party[5].maxhp
	party[0].xp = 5000
	main.town.inn_rooms(party[0])
	press("1")
	check(party[0].lvl >= 2, "inn level-up")

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
		if main.scr.has("moves"):
			main._pad_press(["W", "W", "W", "A", "D"][randi() % 5])
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

	await _test_town_map(g)
	await _test_start_flow(g, g.roster.size())

	print("SELFTEST DONE, failures: %d" % failures)
	return failures


## The row that spreads a screen's buttons across the panel, and what is in one of its groups.
func _row_group(group: String) -> Node:
	for row in main._opts_col.get_children():
		if not row.is_queued_for_deletion() and row.has_node(group):
			return row.get_node(group)
	return null


func _row_labels(group: String) -> Array:
	return _row_group(group).get_children().map(func(b): return b.text)


func _row_button(group: String, i: int) -> Button:
	return _row_group(group).get_child(i)


## The buttons a screen shows, in order.
func _shown_labels() -> Array:
	return main.scr["opts"].filter(func(o): return not o.get("hide", false)).map(func(o): return o["label"])


func _roll_attributes() -> void:
	while _shown_labels().has("ROLL"):
		press("R")
		main.dice_tray().finish_now()


## A cell of the roll screen's grid: 0 the name, 1 rolled, 2 bonus, 3 total.
func _stat_cell(row: int, column: int) -> String:
	var grid: GridContainer = main.scr["widget"]
	return grid.get_child((row + 1) * grid.columns + column).text


func _test_attribute_rolls() -> void:
	var tray: DiceTray = main.dice_tray()
	var score_of := func(row: int) -> String:
		return _stat_cell(row, 3)
	var rolled_of := func(row: int) -> String:
		return _stat_cell(row, 1)
	check(tray.visible and tray.dice.size() == 3, "three dice wait beside the stats panel")
	check(tray.get_global_rect().position.x >= main._panel.get_global_rect().end.x, "to its right")
	check(_shown_labels() == ["ROLL", "BACK"], "the first choice is to roll")
	check(score_of.call(0) == "-" and main.scr["body"].contains("RE-ROLL POINTS: [color=#e3a33f]6[/color]"), "nothing is rolled yet, and there are 6 re-roll points")
	var roll_button: Button = _row_button("center", 0)
	check(roll_button.text == "ROLL" and roll_button.get_theme_stylebox("normal").bg_color == UiStyle.C_STONE2, "ROLL is a blue button in the middle of the row")
	check(roll_button.custom_minimum_size == main.chars.ROLL_BUTTON_SIZE and roll_button.get_theme_font_size("font_size") > 22, "and a larger one")
	check(_row_labels("right") == ["BACK"] and _row_button("right", 0).get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "BACK is brown at the right")
	var head_row: Array = main.scr["widget"].get_children().slice(1, 4).map(func(n): return n.text)
	check(head_row == ["Rolled", "Bonus", "Total"], "the columns are Rolled, Bonus and Total")
	check(_stat_cell(0, 2) == "+1", "each row shows the race's bonus")
	check(_stat_cell(0, 1) == "-" and _stat_cell(0, 3) == "-", "with nothing rolled yet")
	check(main.scr["widget"].get_children().slice(1).all(func(n): return n.custom_minimum_size.x == main.chars.STAT_NUMBER_WIDTH or n is Button or n is Control and n.custom_minimum_size.x == main.chars.STAT_NAME_WIDTH), "the columns have fixed widths, so a value can't move them")
	check(main._body.custom_minimum_size.y == main.chars.STAT_BODY_HEIGHT and main.scr["row_height"] == main.chars.ROLL_BUTTON_SIZE.y, "and the text and buttons have fixed heights")
	press("R")
	check(main.scr["opts"].filter(func(o): return o["label"] == "ROLL")[0]["dis"], "ROLL waits for the dice to land")
	check(main.scr["opts"].filter(func(o): return o["label"] == "BACK")[0]["dis"], "and so does BACK")
	check(score_of.call(0) == "-", "the score waits for the dice too")
	tray.finish_now()
	check(int(rolled_of.call(0)) >= 3 and int(rolled_of.call(0)) <= 18 and score_of.call(1) == "-", "the first attribute gets a roll of 3-18, the rest wait")
	check(int(score_of.call(0)) == int(rolled_of.call(0)) + 1, "the total is the roll plus the bonus")
	_roll_attributes()
	check(_shown_labels() == ["RE-ROLL ALL (2)", "NEXT", "BACK"], "once all are rolled the choices are re-roll and next")
	check(_row_labels("left") == ["RE-ROLL ALL (2)", "NEXT"] and _row_labels("center").is_empty() and _row_labels("right") == ["BACK"], "with BACK still at the right")
	for row in Data.STATS.size():
		check(int(rolled_of.call(row)) >= 3 and int(rolled_of.call(row)) <= 18, "%s is rolled" % Data.STATS[row])
		var one_button: Button = main.scr["widget"].get_node("Reroll_" + Data.STATS[row])
		check(one_button.text == "RE-ROLL (1)" and one_button.get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "with a brown RE-ROLL (1) beside it")
	var one_before: String = rolled_of.call(1)
	var one_other: String = rolled_of.call(2)
	main.scr["widget"].get_node("Reroll_iq").pressed.emit()
	check(main.scr["body"].contains("RE-ROLL POINTS: [color=#e3a33f]5[/color]"), "re-rolling one attribute costs 1 point")
	check(main.scr["widget"].get_node("Reroll_str").disabled and main.scr["opts"].filter(func(o): return o["label"] == "NEXT")[0]["dis"] and main.scr["opts"].filter(func(o): return o["label"] == "BACK")[0]["dis"], "everything waits for the dice")
	check(rolled_of.call(1) == one_before, "and the old score stays until they land")
	tray.finish_now()
	check(int(rolled_of.call(1)) >= 3 and int(score_of.call(1)) == int(rolled_of.call(1)) + 1 and rolled_of.call(2) == one_other, "only that attribute changes, and its total follows")
	check(_shown_labels().has("NEXT") and not _shown_labels().has("ROLL"), "and the screen stays on the final choices")
	var last_b := {"nm": "T", "race": "HUMAN", "al": "GOOD", "st": {}, "rolls": {}, "rolled": 6, "rolling": false, "reroll": 0}
	for last_stat in Data.STATS:
		last_b["st"][last_stat] = 18
	main.chars._draw_stats(last_b)
	check(main.scr["widget"].get_node("Reroll_str").disabled, "a re-roll of one needs a point to pay for it")
	main.chars.create_stats("NEWBIE", "HUMAN", "GOOD")
	_roll_attributes()
	press("A")
	check(main.scr["body"].contains("RE-ROLL POINTS: [color=#e3a33f]4[/color]") and score_of.call(0) == "-" and score_of.call(5) == "-" and rolled_of.call(0) == "-", "a re-roll of everything costs 2 points and erases the scores")
	check(_shown_labels() == ["ROLL", "BACK"], "and starts over")
	var bonus_b := {"nm": "T", "race": "GNOME", "al": "GOOD", "st": {}, "rolls": {}, "rolled": 0, "rolling": false, "reroll": 6}
	main.chars._attribute_rolled(bonus_b, "str", 10)
	main.chars._attribute_rolled(bonus_b, "iq", 10)
	main.chars._attribute_rolled(bonus_b, "pie", 10)
	check(bonus_b["st"]["str"] == 9 and bonus_b["st"]["iq"] == 12 and bonus_b["st"]["pie"] == 10, "the race's bonus goes on the rolled score, and a statistic without one stays as rolled")
	check(bonus_b["rolls"]["str"] == 10 and _stat_cell(0, 1) == "10" and _stat_cell(0, 2) == "-1" and _stat_cell(0, 3) == "9" and _stat_cell(2, 2) == "0", "the row shows the roll, the bonus and the total")
	bonus_b["rolled"] = 0
	main.chars._attribute_rolled(bonus_b, "str", 3)
	check(bonus_b["st"]["str"] == 2, "a penalty can take the total under 3")
	for bonus_stat in Data.STATS:
		bonus_b["st"][bonus_stat] = 10
	bonus_b["rolled"] = 5
	main.chars._attribute_rolled(bonus_b, "luk", 18)
	check(bonus_b["st"]["luk"] == 21, "and a bonus can take it over 18")
	for bonus_race in Data.RACES:
		check(Data.RACE_BONUS.has(bonus_race), "%s has its bonuses" % bonus_race)
	check(Data.RACE_TEXT.has("HALF-ORC") and Data.RACE_BONUS["HALF-ORC"] == {"str": 3, "iq": -2, "agi": 1, "vit": 2}, "half-orcs get their bonuses")
	check(Data.RACE_BONUS["HUMAN"].size() == 6 and Data.RACE_BONUS["HUMAN"].values().all(func(v): return v == 1), "humans get +1 to everything")
	main.chars.create_stats("NEWBIE", "HUMAN", "GOOD")
	var sum_seen := {}
	for trial in 200:
		var trial_b := {"nm": "T", "race": "HUMAN", "al": "GOOD", "st": {}, "rolls": {}, "rolled": 0, "rolling": false, "reroll": 6}
		main.chars._roll_attribute(trial_b)
		tray.finish_now()
		sum_seen[trial_b["rolls"]["str"]] = true
	check(sum_seen.keys().all(func(v): return v >= 3 and v <= 18) and sum_seen.size() > 8, "scores spread across 3-18")
	var low := {}
	var high := {}
	for s in Data.STATS:
		low[s] = 3
		high[s] = 18
	var done_b := {"nm": "T", "race": "HUMAN", "al": "GOOD", "st": high, "rolls": {}, "rolled": 6, "rolling": false, "reroll": 1}
	main.chars._draw_stats(done_b)
	check(main.scr["opts"].filter(func(o): return o["label"].begins_with("RE-ROLL"))[0]["dis"], "a re-roll needs the points to pay for it")
	press("N")
	check(main.scr["title"] == "Choose a class", "NEXT goes on to the classes")
	press("L")
	check(main.scr["title"] == "T: G-HUMAN" and _stat_cell(0, 3) == "18", "and coming back keeps the scores")
	done_b["st"] = low
	done_b["reroll"] = 2
	main.chars._draw_stats(done_b)
	check(_shown_labels()[0] == "RE-ROLL ALL (2)" and main.scr["opts"].filter(func(o): return o["label"] == "NEXT")[0]["dis"], "NEXT needs a class to qualify for")
	done_b["reroll"] = 1
	main.chars._draw_stats(done_b)
	check(_shown_labels()[0] == "RE-ROLL ALL (2)" and not main.scr["widget"].get_node("Reroll_str").disabled, "with one point left, re-rolling one attribute is still a way out")
	done_b["reroll"] = 0
	main.chars._draw_stats(done_b)
	check(_shown_labels()[0] == "RE-ROLL ALL (FREE)", "with no class and no points the re-roll is free, so nobody is stuck")
	press("A")
	check(done_b["reroll"] == 0 and done_b["rolled"] == 0, "and costs nothing")
	main.chars.create_stats("NEWBIE", "HUMAN", "GOOD")


func _click_spot(k: String) -> void:
	var poly: Array = TownMap.SPOTS[k]["poly"]
	var mid := Vector2.ZERO
	for p in poly:
		mid += p
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	# The gate is notched, so its average point sits on the outline; its plate is inside it.
	ev.position = main.town_map.view_point(TownMap.SPOTS[k]["plate"] if k == "E" else mid / poly.size())
	main.town_map._gui_input(ev)


## The Castle is a map: each option has a building, clicks enter it, and greyed ones stay shut.
func _test_town_map(g) -> void:
	print("braziers")
	var all_spots := 0
	var corner_spots := 0
	var spots_ok := true
	for spot_z in range(1, g.MAZE_LEVELS + 1):
		var spot_lv: MazeLevel = g.levels[spot_z]
		var spots: Array = MazeWorld.brazier_spots(spot_lv)
		check(spots.size() >= 5, "level %d has braziers" % spot_z)
		check(spots.size() == MazeWorld.brazier_spots(spot_lv).size(), "level %d keeps its braziers in the same places" % spot_z)
		for spot in spots:
			all_spots += 1
			if spot["corner"]:
				corner_spots += 1
			if spot_lv.flag(spot["c"].x, spot["c"].y, "dark") or spot_lv.flag(spot["c"].x, spot["c"].y, "up") or spot_lv.flag(spot["c"].x, spot["c"].y, "down"):
				spots_ok = false
			if spot["pos"].distance_to(MazeWorld.cell_centre(spot["c"])) >= MazeWorld.CELL:
				spots_ok = false
	check(spots_ok, "braziers stand inside their squares, away from stairs and darkness")
	check(corner_spots * 2 > all_spots, "braziers are mostly in corners")
	print("braziers: %d, in corners: %d" % [all_spots, corner_spots])
	print("cobwebs")
	var web_counts := {}
	var webs_ok := true
	var webs_clear := true
	var webs_anchored := true
	var web_lv: MazeLevel = g.levels[1]
	var web_face: float = MazeWorld.CELL / 2.0 - MazeWorld.THICKNESS / 2.0
	for web_y in MazeLevel.N:
		for web_x in MazeLevel.N:
			var web_cell := Vector2i(web_x, web_y)
			var webs: Array = MazeWorld.web_spots(web_lv, web_cell)
			if webs.size() != MazeWorld.web_spots(web_lv, web_cell).size():
				webs_ok = false
			for web in webs:
				web_counts[web["art"]] = web_counts.get(web["art"], 0) + 1
				if not is_equal_approx(web["top"].y, MazeWorld.HEIGHT):
					webs_ok = false
				if web["top"].y - web["drop"] <= MazeWorld.HEIGHT / 2.0:
					webs_clear = false
				var web_side: Vector3 = MazeWorld.web_right(web["facing"])
				var web_across: float = (web["top"] - MazeWorld.cell_centre(web_cell)).dot(web_side)
				if MazeWorld.WEB_FULL.has(web["art"]) and (not is_zero_approx(web_across) or not is_equal_approx(web["width"], web_face * 2.0)):
					webs_anchored = false
				if web["art"] == MazeWorld.WEB_LEFT and not is_equal_approx(web_across - web["width"] / 2.0, -web_face):
					webs_anchored = false
				if web["art"] == MazeWorld.WEB_RIGHT and not is_equal_approx(web_across + web["width"] / 2.0, web_face):
					webs_anchored = false
				var wall_needed: int = MazeWorld.DIRS.find(web_side) if web["art"] != MazeWorld.WEB_LEFT else MazeWorld.DIRS.find(-web_side)
				if web_lv.wall(web_x, web_y, wall_needed) != 1:
					webs_anchored = false
	check(web_counts.size() == MazeWorld.WEB_FULL.size() + 2, "every full, left and right cobweb hangs somewhere")
	check(webs_ok, "cobwebs hang from the ceiling and stay in the same places")
	check(webs_clear, "cobwebs stay above the party's eye line")
	check(webs_anchored, "cobwebs reach the walls they hang from")
	print("cobwebs on level 1: full %s, left %d, right %d" % [MazeWorld.WEB_FULL.map(func(art): return web_counts.get(art, 0)), web_counts.get(MazeWorld.WEB_LEFT, 0), web_counts.get(MazeWorld.WEB_RIGHT, 0)])
	print("monster cards")
	check(MazeView.card_rects(0).is_empty(), "no groups, no cards")
	var view_box := Rect2(0, 0, MazeView.W, MazeView.H)
	for card_count in range(1, Battle.MAX_GROUPS + 1):
		var cards: Array = MazeView.card_rects(card_count)
		var cards_ok: bool = cards.size() == card_count
		for card_a in card_count:
			cards_ok = cards_ok and view_box.encloses(cards[card_a])
			for card_b in range(card_a + 1, card_count):
				cards_ok = cards_ok and not cards[card_a].intersects(cards[card_b])
		check(cards_ok, "%d groups of monsters fit the window without overlapping" % card_count)
	var mid_of_view := Vector2(MazeView.W, MazeView.H) / 2.0
	var one_card: Rect2 = MazeView.card_rects(1)[0]
	check(one_card.get_center().is_equal_approx(mid_of_view) and one_card.size.x > MazeView.CARD_GRID, "one group is larger and centered")
	var two_cards: Array = MazeView.card_rects(2)
	check(is_equal_approx(two_cards[0].get_center().y, mid_of_view.y) and is_equal_approx(two_cards[1].get_center().y, mid_of_view.y) and is_equal_approx((two_cards[0].get_center().x + two_cards[1].get_center().x) / 2.0, mid_of_view.x), "two groups are centered in a row")
	check(two_cards[0].size.x == MazeView.CARD_PAIR and MazeView.CARD_PAIR > MazeView.CARD_GRID, "two groups are larger than three or four")
	var three_cards: Array = MazeView.card_rects(3)
	check(is_equal_approx(three_cards[2].get_center().x, mid_of_view.x) and is_equal_approx((three_cards[0].get_center().x + three_cards[1].get_center().x) / 2.0, mid_of_view.x) and is_equal_approx((three_cards[0].position.y + three_cards[2].end.y) / 2.0, mid_of_view.y - MazeView.GRID_LIFT), "three groups make two over one, centered across and lifted for the text below")
	var four_cards: Array = MazeView.card_rects(4)
	check(four_cards[0].position.y == four_cards[1].position.y and four_cards[2].position.y == four_cards[3].position.y and four_cards[0].position.x == four_cards[2].position.x and four_cards[0].position.y < four_cards[2].position.y, "four groups make a 2x2 grid")
	var keep_kind: String = main.view.kind
	for shown_kind in ["combat", "chest"]:
		main.view.kind = shown_kind
		check(main.view._shows_maze(), "the Maze stays up behind the %s" % shown_kind)
	main.view.kind = keep_kind
	print("monster art")
	check(Data.MON_BY_LEVEL[1].has("MIMIC") and not Data.MONS.has("COINS"), "the mimic has replaced the creeping coins")
	var mimic_group := Battle.mk_group("MIMIC", 2)
	var mimic_battle := Battle.new()
	check(mimic_battle.gname(mimic_group, 2) == "CHESTS" and mimic_battle.a_name(mimic_group) == "A CHEST", "an unidentified mimic looks like a chest")
	mimic_group["known"] = true
	check(mimic_battle.gname(mimic_group, 2) == "MIMICS" and mimic_battle.a_name(mimic_group) == "A MIMIC", "an identified mimic is named")
	for new_id in ["TOADMAN", "LIZARD", "BASILISK", "FROST", "FIREG", "GDAEMON", "REDDRAG", "YETI", "SPAWN", "DLORD"]:
		check(MazeView.MONSTER_ART.has(new_id), "%s has its painting" % new_id)
		var new_lairs := range(1, Data.MON_BY_LEVEL.size()).filter(func(z): return Data.MON_BY_LEVEL[z].has(new_id))
		check(not new_lairs.is_empty(), "%s can be met in the Maze" % new_id)
	for table_z in range(1, Data.MON_BY_LEVEL.size()):
		for table_id in Data.MON_BY_LEVEL[table_z]:
			check(Data.MONS.has(table_id), "%s on level %d is a real monster" % [table_id, table_z])
	var plural_battle := Battle.new()
	var plural_group: Dictionary = Battle.mk_group("LIZARD", 2)
	plural_group["known"] = true
	check(plural_battle.gname(plural_group, 2) == "LIZARDMEN" and plural_battle.gname(plural_group, 1) == "LIZARDMAN", "lizardmen have their own plural")
	plural_group["known"] = false
	check(plural_battle.gname(plural_group, 2) == "SCALED HUMANOID", "and keep their vague name until identified")
	for painted_id in Data.MONS:
		check(MazeView.MONSTER_ART.has(painted_id), "%s has a painting" % painted_id)
	for art_id in MazeView.MONSTER_ART:
		check(Data.MONS.has(art_id), "the painting %s belongs to a monster" % art_id)
		check(MazeView.MONSTER_ART[art_id] is Texture2D, "the painting %s loads" % art_id)
	print("chests")
	var chest_total := 0
	var chests_ok := true
	for chest_z in range(1, g.MAZE_LEVELS + 1):
		var chest_lv: MazeLevel = g.levels[chest_z]
		var chest_spots: Array = MazeWorld.chest_spots(chest_lv)
		chest_total += chest_spots.size()
		var chest_braziers := {}
		for chest_b in MazeWorld.brazier_spots(chest_lv):
			chest_braziers[chest_b["c"]] = true
		for chest_spot in chest_spots:
			var chest_c: Vector2i = chest_spot["c"]
			if chest_braziers.has(chest_c) or chest_lv.flag(chest_c.x, chest_c.y, "dark") or chest_lv.flag(chest_c.x, chest_c.y, "up") or chest_lv.flag(chest_c.x, chest_c.y, "down"):
				chests_ok = false
			if chest_lv.wall(chest_c.x, chest_c.y, chest_spot["side"]) != 1:
				chests_ok = false
			var chest_front: Vector3 = Basis(Vector3.UP, MazeWorld.chest_yaw(chest_spot["side"])) * Vector3(0, 0, 1)
			if not chest_front.is_equal_approx(-MazeWorld.DIRS[chest_spot["side"]]):
				chests_ok = false
	check(chest_total >= 8, "the levels have chests")
	check(chests_ok, "chests sit against plain walls, face the room, and stay clear of braziers and ladders")
	print("chests: %d" % chest_total)
	print("maze in 3D")
	var turn_button: Button = main._pad.get_child(4)
	check(turn_button.icon != null and turn_button.text == "", "the turn around button shows its rotate icon")
	main.mz.maze()
	var turn_before: int = g.pos["d"]
	turn_button.pressed.emit()
	check(g.pos["d"] == (turn_before + 2) % 4, "the turn around button still turns the party around")
	g.pos["d"] = turn_before
	check(MazeWorld.camera_yaw(0) == 0.0 and is_equal_approx(MazeWorld.camera_yaw(1), -PI / 2.0), "the camera turns clockwise from north")
	var cam_at := MazeWorld.camera_place(Vector2i(0, 0), 0)
	check(cam_at.is_equal_approx(Vector3(1.0, 0.75, -0.1)), "the camera stands near the back of the square, halfway up")
	check(MazeWorld.camera_place(Vector2i(0, 0), 1).is_equal_approx(Vector3(0.1, 0.75, -1.0)), "facing east it backs up to the west")
	check(MazeWorld.seen_wall(3, false) == 1 and MazeWorld.seen_wall(3, true) == 3, "a secret door looks like wall until the light reveals it")
	var map_world: MazeWorld = main.view.world
	var wall_counts := {}
	for wall_y in MazeLevel.N:
		for wall_x in MazeLevel.N:
			for wall_d in 4:
				var wall_tex: Texture2D = map_world._wall_piece(1, Vector2i(wall_x, wall_y), wall_d)
				wall_counts[wall_tex] = wall_counts.get(wall_tex, 0) + 1
	check(wall_counts.size() == MazeWorld.WALL_ART.size() + MazeWorld.RARE_WALL_ART.size(), "every wall piece turns up")
	check(map_world._wall_piece(1, Vector2i(3, 4), 2) == map_world._wall_piece(1, Vector2i(3, 4), 2), "a wall always keeps the same piece")
	check(wall_counts[MazeWorld.RARE_WALL_ART[0]] < wall_counts[MazeWorld.WALL_ART[0]] and wall_counts[MazeWorld.RARE_WALL_ART[1]] < wall_counts[MazeWorld.WALL_ART[0]], "landmark walls are rarer than plain ones")
	var floor_counts := {}
	for floor_y in MazeLevel.N:
		for floor_x in MazeLevel.N:
			var floor_tex: Texture2D = map_world._floor_piece(1, Vector2i(floor_x, floor_y))
			floor_counts[floor_tex] = floor_counts.get(floor_tex, 0) + 1
	check(floor_counts.size() == MazeWorld.FLOOR_ART.size() + MazeWorld.RARE_FLOOR_ART.size(), "every floor piece turns up")
	check(floor_counts[MazeWorld.RARE_FLOOR_ART[0]] < floor_counts[MazeWorld.FLOOR_ART[0]] and floor_counts[MazeWorld.RARE_FLOOR_ART[1]] < floor_counts[MazeWorld.FLOOR_ART[0]], "crest floors are rarer than plain ones")
	var map_pos: Dictionary = g.pos.duplicate()
	var map_light: int = g.light
	g.pos = {"x": 0, "y": 0, "z": 1, "d": 0}
	g.light = 0
	map_world.sync_to_party()
	check(map_world._level.mesh.get_surface_count() >= 5, "the level mesh holds its walls, doors, floors and ceilings")
	var plain_mesh: Mesh = map_world._level.mesh
	map_world.sync_to_party()
	check(map_world._level.mesh == plain_mesh, "the level is only built once")
	g.light = 30
	map_world.sync_to_party()
	check(map_world._level.mesh != plain_mesh, "light rebuilds the level, to reveal secret doors")
	check(map_world._torch.omni_range == MazeWorld.SPELL_REACH, "light spells reach farther than the torch")
	var ladder_in_mesh := false
	var shows_ladder_up := false
	for ladder_surface in map_world._level.mesh.get_surface_count():
		var ladder_mat: StandardMaterial3D = map_world._level.mesh.surface_get_material(ladder_surface)
		ladder_in_mesh = ladder_in_mesh or ladder_mat.albedo_texture == MazeWorld.LADDER_DOWN_ART
		shows_ladder_up = shows_ladder_up or ladder_mat.albedo_texture == MazeWorld.LADDER_UP_ART
	var ladder_lv: MazeLevel = g.levels[1]
	check(not ladder_in_mesh and map_world._ladder_floor.visible, "the ladder floor stands apart from the level's mesh")
	check(map_world._ladder_floor.position.is_equal_approx(MazeWorld.cell_centre(ladder_lv.down)), "the ladder floor is on the way down")
	check(map_world._ladder_light.visible and map_world._ladder_light.shadow_enabled, "the way down has a light that walls block")
	check(map_world._ladder_up_light.visible and map_world._ladder_up_light.shadow_enabled, "the way up has a light that walls block")
	check(map_world._ladder_up_light.position.is_equal_approx(MazeWorld.cell_centre(Vector2i(0, 0)) + Vector3.UP * MazeWorld.LADDER_LIGHT_HEIGHT), "the way up's light is on its square")
	check(map_world._ladder_up_light.light_color == map_world._ladder_light.light_color and map_world._ladder_up_light.light_energy == map_world._ladder_light.light_energy and map_world._ladder_up_light.omni_range == map_world._ladder_light.omni_range, "both ladder lights match")
	for ladder_d in 4:
		g.pos["d"] = ladder_d
		map_world.sync_to_party()
		check(is_equal_approx(wrapf(map_world._ladder_floor.rotation.y, -PI, PI), wrapf(MazeWorld.camera_yaw(ladder_d), -PI, PI)), "the ladder floor turns with the party, facing %d" % ladder_d)
	g.pos["d"] = 0
	var deepest: MazeLevel = g.levels[g.MAZE_LEVELS]
	g.pos["z"] = g.MAZE_LEVELS
	map_world.sync_to_party()
	check(map_world._ladder_floor.visible == (deepest.flag(deepest.down.x, deepest.down.y, "down") == true), "a level with no way down shows no ladder")
	g.pos["z"] = 1
	map_world.sync_to_party()
	check(shows_ladder_up, "the way up shows the ladder wall")
	for up_z in range(1, g.MAZE_LEVELS + 1):
		var up_lv: MazeLevel = g.levels[up_z]
		var up_walls := 0
		for up_y in MazeLevel.N:
			for up_x in MazeLevel.N:
				var up_side := MazeWorld.ladder_up_side(up_lv, Vector2i(up_x, up_y))
				if up_lv.flag(up_x, up_y, "up"):
					if up_side >= 0 and up_lv.wall(up_x, up_y, up_side) == 1:
						up_walls += 1
				elif up_side != -1:
					up_walls += 100
		check(up_walls == 1, "level %d has one ladder wall, on its way up" % up_z)
	var shows_hatch := false
	for hatch_surface in map_world._level.mesh.get_surface_count():
		shows_hatch = shows_hatch or map_world._level.mesh.surface_get_material(hatch_surface).albedo_texture == MazeWorld.LADDER_HATCH_ART
	check(shows_hatch, "the way up has the hatch ceiling")
	for hatch_side in 4:
		var hatch_c: Array = MazeWorld.ladder_hatch_corners(Vector3.ZERO, hatch_side)
		var hatch_edge: Vector3 = (hatch_c[1] + hatch_c[2]) / 2.0 - Vector3.UP * MazeWorld.HEIGHT
		check(hatch_edge.is_equal_approx(MazeWorld.DIRS[hatch_side] * MazeWorld.CELL / 2.0), "the hatch sits over the ladder, on side %d" % hatch_side)
		var hatch_turn: Vector3 = (hatch_c[1] - hatch_c[0]).cross(hatch_c[2] - hatch_c[1])
		check(hatch_turn.y > 0.0, "the hatch ceiling faces the same way as the others, on side %d" % hatch_side)
	check(map_world._braziers.size() == MazeWorld.brazier_spots(g.levels[1]).size(), "the level has its braziers standing")
	check(map_world._chests.size() == MazeWorld.chest_spots(g.levels[1]).size(), "the level has its chests in place")
	check(map_world._chest_mesh_shared.get_surface_count() == 3, "a chest is a real 3D model, in three colours")
	var burning_ok := true
	for burning in map_world._braziers:
		var burning_near: bool = maxi(absi(burning["c"].x), absi(burning["c"].y)) <= MazeWorld.BRAZIER_NEAR
		if burning["light"].visible != burning_near or burning["fire_on"] != burning_near:
			burning_ok = false
		if burning["fire"] != null and burning["fire"].find_children("*", "AudioStreamPlayer3D", true, false).size() > 0:
			burning_ok = false
	check(burning_ok, "only braziers near the party burn, and they stay silent")
	var shows_open := func() -> bool:
		for surface in map_world._level.mesh.get_surface_count():
			if map_world._level.mesh.surface_get_material(surface).albedo_texture == MazeWorld.OPEN_DOOR_ART[0]:
				return true
		return false
	g.opened = {}  # a walk earlier in the test may have opened one
	map_world.sync_to_party()
	check(not shows_open.call(), "no door shows open at first")
	var lv_one: MazeLevel = g.levels[1]
	for open_y in MazeLevel.N:
		for open_x in MazeLevel.N:
			for open_d in 4:
				if g.opened.is_empty() and lv_one.wall(open_x, open_y, open_d) == 2:
					g.open_door(1, open_x, open_y, open_d)
	map_world.sync_to_party()
	check(shows_open.call(), "an opened door shows as open")
	g.opened = {}
	g.pos = map_pos
	g.light = map_light
	print("town map")
	var saved: Array[int] = g.party.duplicate()
	g.mode = "castle"
	g.party.clear()
	main.town.castle()
	await get_tree().process_frame
	check(main.town_map.visible, "the castle shows the map")
	var map_party: GridContainer = main.town_map._party
	var saved_party: Array[int] = g.party.duplicate()
	var map_first: Character = g.make_char("MAPPER", "HUMAN", "GOOD", Data.RACES["HUMAN"].duplicate(), "FIGHTER", "FEMALE", "female_4")
	g.party.assign([map_first.id])
	main.town.castle()
	check(map_party.get_child_count() == 12, "the map's party window has a header and a row per member")
	var map_cells := map_party.get_children().map(func(n): return n.text if n is Label else "")
	check(map_cells.slice(0, 6) == ["", "NAME", "CLASS", "LVL", "HEALTH", "STATUS"], "the party window has the header row")
	check(map_cells.slice(7) == [map_first.name, "G-FIG", str(map_first.lvl), "%d/%d" % [map_first.hp, map_first.maxhp], "OK"], "a row follows the header's columns")
	for col in [1, 7]:
		check(map_party.get_child(col).horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "names are left justified")
	for col in [2, 3, 4, 5, 8, 9, 10, 11]:
		check(map_party.get_child(col).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "the other party columns are centered")
	check(map_party.get_child(6) is TextureRect and map_party.get_child(6).texture == load(map_first.portrait_path()), "the row starts with the member's portrait")
	check(map_party.get_children().all(func(n): return n.mouse_filter == Control.MOUSE_FILTER_IGNORE), "the party window lets clicks through to the buildings")
	g.party.assign(saved_party)
	g.roster.erase(map_first)
	main.town.castle()
	var rect: Rect2 = main.town_map._map_rect()
	check(absf(rect.size.x / rect.size.y - 16.0 / 9.0) < 0.001, "the map is 16:9")
	check(main.town_map._texture != null and absf(float(main.town_map._texture.get_width()) / main.town_map._texture.get_height() - 16.0 / 9.0) < 0.001, "the painting is 16:9")
	for map_smoke in [main.town_map._smoke, main.town_map._mist]:
		check(map_smoke.mouse_filter == Control.MOUSE_FILTER_IGNORE and map_smoke.get_index() < main.town_map._party_panel.get_index(), "smoke lets clicks through and sits under the panels")
	for smoke_kind in [MapSmoke.CHIMNEY, MapSmoke.MAZE_MIST]:
		var smoke_ok := true
		for smoke_i in 300:
			var smoke_puff := MapSmoke.puff(smoke_kind, smoke_i % smoke_kind["puffs"], smoke_i * 0.17)
			smoke_ok = smoke_ok and smoke_puff["strength"] >= 0.0 and smoke_puff["strength"] <= smoke_kind["strength"]
		check(smoke_ok, "smoke fades as it goes")
		check(MapSmoke.puff(smoke_kind, 0, 0.0)["width"] < MapSmoke.puff(smoke_kind, 0, smoke_kind["life"] * 0.9)["width"], "smoke spreads as it goes")
	var chimney_top := MapSmoke.puff(MapSmoke.CHIMNEY, 0, MapSmoke.CHIMNEY["life"] * 0.9)
	check(chimney_top["offset"].y < 0.0, "the chimney's smoke rises")
	var mist_far := MapSmoke.puff(MapSmoke.MAZE_MIST, 0, MapSmoke.MAZE_MIST["life"] * 0.9)
	check(mist_far["offset"].x < 0.0 and mist_far["offset"].y > 0.0 and MapSmoke.MAZE_MIST["squash"] < 1.0, "the Maze's mist flows low, out and down its steps")
	check(MapSmoke.MAZE_MIST["lit"] == Color.WHITE, "and it is white")
	check((main.town_map._torch_window != null) == ResourceLoader.exists(TownMap.FIRE_SCENE), "the Maze's torch burns when the Vefects pack is installed")
	if main.town_map._torch_window != null:
		var torch_fire: Node3D = main.town_map._torch_window.get_child(0).get_child(1)
		check(torch_fire.find_children("*", "AudioStreamPlayer3D", true, false).is_empty(), "the torch makes no sound")
		check(torch_fire.find_children("*", "GPUParticles3D", true, false).all(func(n): return n.speed_scale == TownMap.FIRE_SPEED), "the torch burns slowly")
		check(TownMap.TORCH_WINDOW.y < TownMap.FIRE_WINDOW.y, "and smaller than the campfire")
	var forges: ForgeGlow = main.town_map._forges
	check(forges.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the forge glow lets clicks through")
	check(forges.get_index() < main.town_map._party_panel.get_index(), "the forge glow sits under the corner panels")
	var heats := []
	for heat_i in 40:
		heats.append(ForgeGlow.heat(ForgeGlow.FORGES[0]["phase"], heat_i * 0.2))
	check(heats.min() >= 0.0 and heats.max() <= 1.0 and heats.max() - heats.min() > 0.3, "the forges pulse")
	check(ForgeGlow.heat(ForgeGlow.FORGES[0]["phase"], 1.0) != ForgeGlow.heat(ForgeGlow.FORGES[1]["phase"], 1.0), "each forge pulses on its own")
	var ember_source: Dictionary = ForgeGlow.EMBERS[0]
	var ember_ok := true
	for ember_i in 200:
		var ember_now := ForgeGlow.ember(ember_source, ember_i % ember_source["count"], ember_i * 0.07)
		ember_ok = ember_ok and ember_now["offset"].y <= 0.0 and ember_now["offset"].y >= -ember_source["rise"] and ember_now["bright"] >= 0.0 and ember_now["bright"] <= 1.0
	check(ember_ok, "embers only rise, and fade in and out")
	var fire_window: SubViewportContainer = main.town_map._fire_window
	check((fire_window != null) == ResourceLoader.exists(TownMap.FIRE_SCENE), "the campfire burns when the Vefects pack is installed")
	if fire_window != null:
		var fire_scene: Node3D = fire_window.get_child(0).get_child(1)
		check(fire_scene.find_children("*", "AudioStreamPlayer3D", true, false).is_empty(), "the village campfire makes no sound")
		check(not fire_scene.get_children().any(func(n): return "intensity_multiplier" in n), "the village campfire has no light of its own")
		var fire_flames := fire_scene.find_children("*", "GPUParticles3D", true, false)
		check(not fire_flames.is_empty() and fire_flames.all(func(n): return n.speed_scale == TownMap.FIRE_SPEED), "the village campfire burns slowly")
		check(fire_window.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the fire lets clicks through")
		check(fire_window.get_index() < main.town_map._party_panel.get_index(), "the fire burns under the corner panels")
		var fire_foot: Vector2 = fire_window.position + Vector2(fire_window.size.x * 0.5, fire_window.size.y * (1.0 - TownMap.FIRE_BASE_HEIGHT))
		check(fire_foot.distance_to(main.town_map.view_point(TownMap.FIRE_BASE)) < 1.0, "the fire stands on the campfire")
	for o in main.scr["opts"]:
		check(TownMap.SPOTS.has(o["k"]), "%s has a building on the map" % o["label"])
	_click_spot("B")
	check(main.scr["title"] == "Castle", "a greyed-out building stays shut")
	_click_spot("G")
	check(main.scr["title"] == "Gilgamesh's Tavern" and not main.town_map.visible, "clicking the tavern enters it and hides the map")
	check(main._backdrop.visible, "clicking the tavern shows its painting")
	press("L")
	check(main.scr["title"] == "Castle" and main.town_map.visible, "leaving the tavern returns to the map")
	_click_spot("E")
	check(main.scr["title"] == "Edge of Town", "clicking the gate opens the Edge of Town")
	var edge_art: Texture2D = main._backdrop.texture
	check(main._backdrop.visible and edge_art == load(TownScreens.EDGE_IMAGE), "the Edge of Town shows its painting")
	check(absf(float(edge_art.get_width()) / edge_art.get_height() - 16.0 / 9.0) < 0.001, "the Edge of Town painting is 16:9")
	check(main.scr["body"].contains("Many adventurers have walked this road...few returned."), "the Edge of Town has its line")
	check(_shown_labels() == ["RETURN TO TOWN", "EXIT GAME"], "and only two buttons")
	check(_row_labels("left") == ["RETURN TO TOWN"] and _row_button("left", 0).get_theme_stylebox("normal").bg_color == UiStyle.C_STONE2, "RETURN TO TOWN is blue")
	check(_row_labels("right") == ["EXIT GAME"] and _row_button("right", 0).get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "EXIT GAME is brown, at the right")
	_row_button("left", 0).pressed.emit()
	check(main.scr["title"] == "Castle" and main.town_map.visible and not main._backdrop.visible, "RETURN TO TOWN goes back to the map")
	main.town.edge_of_town()
	check(not main.town.has_method("utilities") and not main.town.has_method("restart_out"), "there are no OUT parties to restart")
	var edge_party: Array = g.party.duplicate()
	main.mz.enter_maze()
	check(not main._backdrop.visible and main.place_image == "", "entering the Maze leaves the painting behind")
	for edge_c in g.party_chars():
		edge_c.loc = "CASTLE"
	g.party = edge_party
	main.town.edge_of_town()
	press("C")
	_click_spot("R")
	check(main.scr["title"] == "Training Grounds", "clicking the yard opens the Training Grounds")
	var training_art: Texture2D = main._backdrop.texture
	check(main._backdrop.visible and training_art != null, "the Training Grounds show their painting")
	check(absf(float(training_art.get_width()) / training_art.get_height() - 16.0 / 9.0) < 0.001, "the Training Grounds painting is 16:9")
	press("C")
	check(main.scr["title"] == "Create a character" and main._backdrop.texture == training_art, "creating a character keeps the painting")
	main.chars.create_race("RACER")
	check(main.scr.get("opts", []).is_empty(), "the race screen uses its own buttons")
	check(not main._side.visible, "no race popup shows until a race is clicked")
	main.scr["widget"].get_node("DWARF").pressed.emit()
	check(main._side.visible and main.scr["side"].get_child(0).text == "Dwarves are strong and pious", "clicking a race opens its popup")
	var explain: Label = main.scr["side"].find_child("Explain", true, false)
	for st in Data.STATS:
		var info: Button = main.scr["side"].find_child("Info_" + st, true, false)
		info.mouse_entered.emit()
		check(explain.text == Data.STAT_INFO[st][1], "the info icon beside %s explains it" % st)
		check(info.icon != null and info.text == "", "and is an icon")
		info.mouse_exited.emit()
		check(explain.text == "", "and there is no message until then")
	var popup_grid: Node = main.scr["side"].get_child(2)
	check(main.scr["side"].get_child(1).text == "Bonus Stats" and popup_grid.get_child(0).text == "Strength: +2", "the popup shows the race's bonuses")
	check(popup_grid.get_child(2).text == "Intelligence: None", "and None where there is no bonus")
	main.chars.create_race("RACER", "GNOME")
	check(main.scr["side"].get_child(2).get_child(0).text == "Strength: -1", "a penalty shows as one")
	main.scr["widget"].get_node("HALF-ORC").pressed.emit()
	check(main.scr["side"].get_child(0).text == "Half-orcs are strong and tough" and main.scr["side"].get_child(2).get_child(2).text == "Intelligence: -2", "half-orcs can be chosen")
	main.chars.create_race("RACER", "DWARF")
	main.scr["side"].find_child("Choose", true, false).pressed.emit()
	check(main.scr["title"] == "RACER: choose an alignment" and not main._side.visible, "choosing a race moves on and closes the popup")
	check(_row_labels("left") == ["GOOD", "NEUTRAL", "EVIL"] and _row_labels("right") == ["BACK"], "the alignment screen has BACK at the right")
	check(_row_button("right", 0).get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "and it is brown")
	press("L")
	check(main.scr["title"] == "RACER: choose a race" and main._side.visible and main.scr["side"].get_child(0).text == "Dwarves are strong and pious", "BACK returns to the race, still selected")
	main.scr["side"].find_child("Choose", true, false).pressed.emit()
	press("G")
	check(main.scr["title"].begins_with("RACER: G-DWARF"), "the chosen race carries through")
	main.chars.create_race("RACER")
	main.scr["widget"].get_node("Leave").pressed.emit()
	check(main.scr["title"] == "Create a character", "BACK on the race screen returns to the name")
	main.chars.create_stats("RACER", "DWARF", "GOOD")
	press("L")
	check(main.scr["title"] == "RACER: choose an alignment", "BACK on the roll screen returns to the alignment")
	main.town.temple()
	check(main.scr["opts"][-1]["label"] == "EXIT" and main.scr["opts"][-1]["fn"] == main.town.castle, "the Temple returns to town, so it says EXIT")
	main.town.inn()
	check(main.scr["opts"][-1]["label"] == "EXIT", "and so does the Inn")
	main.town.inn_rooms(g.roster[0])
	check(main.scr["opts"][-1]["label"] == "BACK", "but the Inn's rooms go back to the Inn")
	main.town.castle()
	main.chars.training()
	main.chars.create_stats("PAINTED", "HUMAN", "GOOD")
	check(main._backdrop.texture == training_art, "rolling attributes keeps the painting")
	for sex in ["MALE", "FEMALE"]:
		check(not Data.portraits(sex).is_empty(), "%s has portraits" % sex)
		for portrait in Data.portraits(sex):
			check(ResourceLoader.exists(Character.PORTRAIT_FILE % portrait), "portrait %s exists" % portrait)
	var picked := {"nm": "PICKED", "race": "HUMAN", "al": "GOOD", "st": Data.RACES["HUMAN"].duplicate(), "rolls": {}, "rolled": Data.STATS.size(), "rolling": false, "reroll": 0}
	main.chars.create_sex(picked, "FIGHTER")
	press("F")
	check(main.scr["title"].ends_with("choose a portrait") and main.scr["widget"].get_child_count() == 12 and main.scr["widget"].columns == 4, "a page of portraits is a 4x3 grid")
	check(main.scr["widget"].get_child(0).get_child_count() == 0, "portraits carry no numbers")
	check(not press("B"), "the first page of portraits has nothing before it")
	check(press("N") and main.scr["widget"].get_child_count() == 12, "the next page of portraits offers twelve more")
	var keep_nm: String = picked["nm"]
	var page_names := func() -> Array:
		return main.scr["widget"].get_children().map(func(n): return String(n.name))
	for shuffle_sex in ["MALE", "FEMALE"]:
		main.chars.create_portrait(picked, "FIGHTER", shuffle_sex)
		var dealt: Array = page_names.call()
		var first_page: Array = dealt.duplicate()
		while press("N"):
			dealt.append_array(page_names.call())
		var dealt_sorted: Array = dealt.duplicate()
		var all_sorted: Array = Data.portraits(shuffle_sex).duplicate()
		dealt_sorted.sort()
		all_sorted.sort()
		check(dealt_sorted == all_sorted, "every %s portrait is offered exactly once" % shuffle_sex)
		check(dealt != Data.portraits(shuffle_sex), "and not in file order")
		while press("B"):
			pass
		check(page_names.call() == first_page, "turning the pages keeps the order")
		main.chars.create_portrait(picked, "FIGHTER", shuffle_sex)
		check(page_names.call() != first_page, "and coming back deals them anew")
	var shuffle_seed := randi()
	seed(shuffle_seed)
	var seed_expect := randi()
	seed(shuffle_seed)
	main.chars.create_portrait(picked, "FIGHTER", "FEMALE")
	check(randi() == seed_expect, "dealing the portraits leaves the game's dice alone")
	var file_order: Array = Data.portraits("FEMALE")
	var taken_first: Character = g.roster[0]
	var taken_keep: String = taken_first.portrait
	taken_first.portrait = file_order[12]
	var taken_pick := func(_p): pass
	main.chars._portrait_picker("PICKED", "FEMALE", 1, taken_pick, taken_pick, null, file_order)
	check(main.scr["widget"].get_child(0).disabled and not main.scr["widget"].get_child(1).disabled, "a portrait another character has can't be selected")
	press("N")
	press("B")
	check(main.scr["widget"].get_child(0).disabled, "it stays taken after turning the page")
	main.chars._portrait_picker(taken_first.name, "FEMALE", 1, taken_pick, taken_pick, taken_first, file_order)
	check(not main.scr["widget"].get_child(0).disabled, "a character can keep their own portrait")
	taken_first.portrait = taken_keep
	main.chars.create_portrait(picked, "FIGHTER", "FEMALE", 1)
	var clicked_portrait := String(main.scr["widget"].get_child(1).name)
	main.scr["widget"].get_child(1).pressed.emit()
	check(picked["portrait"] == clicked_portrait, "clicking a portrait picks from the page on show")
	check(keep_nm == "PICKED", "picking a portrait keeps the character")
	main.chars.create_portrait(picked, "FIGHTER", "FEMALE", ceili(Data.portraits("FEMALE").size() / 12.0) - 1)
	check(not press("N") and main.scr["widget"].get_child_count() == (Data.portraits("FEMALE").size() - 1) % 12 + 1, "the last page holds the remaining portraits")
	main.chars.create_portrait(picked, "FIGHTER", "MALE")
	check(main.scr["widget"].get_child_count() == 12 and press("N") and main.scr["widget"].get_child_count() == 12, "the male portraits have pages too")
	main.chars.create_portrait(picked, "FIGHTER", "FEMALE")
	var kept_portrait := String(main.scr["widget"].get_child(1).name)
	main.scr["widget"].get_child(1).pressed.emit()
	check(main.scr["title"] == "Keep this character?" and main._portrait.visible, "the confirmation shows the chosen portrait")
	press("Y")
	var made: Character = g.roster.back()
	check(made.name == "PICKED" and made.sex == "FEMALE" and made.portrait == kept_portrait, "the new character keeps the sex and portrait chosen")
	check(not main._portrait.visible, "the Training Grounds hide the portrait again")
	check(made.his() == "HER" and made.him() == "HER", "a female character gets female pronouns")
	var reloaded := Character.from_dict(JSON.parse_string(JSON.stringify(made.to_dict())))
	check(reloaded.sex == "FEMALE" and reloaded.portrait == kept_portrait, "sex and portrait survive a save")
	var old_save := made.to_dict()
	old_save.erase("sex")
	old_save.erase("portrait")
	var old_char := Character.from_dict(old_save)
	check(old_char.sex == "MALE" and old_char.portrait == "male_1", "characters from older saves default to portrait 1")
	var old_woman := made.to_dict()
	old_woman["portrait"] = "female_9999"
	check(Character.from_dict(old_woman).portrait == "female_1", "a missing portrait defaults to portrait 1 of the right sex")
	main.chars.inspect(old_char, "tavern", main.chars.training)
	check(main._sheet.visible and main._sheet.find_child("Portrait", true, false).texture != null, "inspecting a character from an older save shows a portrait")
	old_char.portrait = ""
	main.chars.train_char(made)
	check(main._portrait.visible and main._portrait_image.texture != null, "inspecting a character shows their portrait")
	main.chars.train_char(old_char)
	check(not main._portrait.visible, "a character with no portrait shows none")
	main.chars.train_char(made)
	check(_row_labels("right") == ["BACK"] and _row_button("right", 0).get_theme_stylebox("normal").bg_color == main.PAGER_FILL and _row_button("right", 0).get_theme_font_size("font_size") < 22, "BACK is small and brown, at the right")
	check(_row_labels("left").has("CHANGE PORTRAIT"), "with the other buttons on the left")
	main.chars._choose_class(picked, ["FIGHTER"])
	check(main._pager_row.get_child(-1).text == "BACK" and main._pager_row.get_child(-1).get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "a list's BACK is too")
	main.chars.train_char(made)
	press("N")
	check(main.scr["title"] == "Rename PICKED" and _row_labels("left") == ["SELECT"] and _row_labels("right") == ["BACK"], "Change Name asks for the new name")
	main._on_input_submitted(g.roster[0].name)
	check(made.name == "PICKED" and main.scr["title"] == "Rename PICKED", "a taken name is refused")
	main._on_input_submitted("RENAMED")
	check(made.name == "RENAMED" and main.scr["title"] == "RENAMED", "a free name is taken, back on the character's screen")
	made.name = "PICKED"
	main.chars.train_char(made)
	press("P")
	check(main.scr["title"] == "PICKED: choose a portrait" and main.scr["widget"].get_child_count() == 12, "Change Portrait opens the picker")
	press("L")
	check(main.scr["title"] == "PICKED" and made.portrait == kept_portrait, "leaving the picker keeps the old portrait")
	press("P")
	press("N")
	var changed_portrait := String(main.scr["widget"].get_child(0).name)
	main.scr["widget"].get_child(0).pressed.emit()
	check(main.scr["title"] == "PICKED" and made.portrait == changed_portrait, "Change Portrait replaces the portrait")
	check(main._portrait_image.texture == load(made.portrait_path()), "the character screen shows the new portrait")
	g.roster.erase(made)
	main.chars.training()
	press("R")
	check(main.scr["title"] == "Roster" and main._backdrop.texture == training_art, "the roster keeps the painting")
	press("Enter")
	press("L")
	check(main.scr["title"] == "Castle", "leaving the Training Grounds returns to the map")
	check(not main._backdrop.visible, "leaving the Training Grounds clears their painting")
	press("T")
	check(main.scr["title"] == "Castle", "the Temple key respects the greying")
	for id in saved:
		g.party.append(id)
	main.town.castle()
	press("T")
	check(main.scr["title"] != "Castle", "the Temple key opens the Temple with a party")
	main.town.castle()
	_click_spot("B")
	var boltac_art: Texture2D = main._backdrop.texture
	check(main._backdrop.visible and boltac_art != null, "clicking Boltac's shows its painting")
	check(absf(float(boltac_art.get_width()) / boltac_art.get_height() - 16.0 / 9.0) < 0.001, "Boltac's painting is 16:9")
	check(main._gear.visible and not main._table.visible, "Boltac's shows the party as a grid instead of the table")
	var gear_hero: Character = g.party_chars()[0]
	var gear_keep: Array = gear_hero.items
	gear_hero.items = []
	main.rerender()
	var gear_lines := func() -> Array:
		var cell: Control = main._gear_grid.get_child(0)
		var out := []
		for l in cell.get_child(0).get_children():
			if l is Label:
				out.append(l.text)
		return out
	var gear_seen: Array = gear_lines.call()
	check(gear_seen.size() == 8 and gear_seen[0] == gear_hero.name, "a card has the name, class, hit points, four lines of gear and gold")
	check(gear_seen[1] == "LVL %d %s" % [gear_hero.lvl, gear_hero.cls], "a card has the level and class")
	check(gear_seen[7] == "Gold: %d" % gear_hero.gold, "a card ends with the gold")
	check(gear_seen[2].contains("HP ") and gear_seen[2].contains("AC "), "a card has hit points and AC")
	check(gear_seen.slice(3, 7) == ["Weapon: NONE", "Helm: NONE", "Armor: NONE", "Shield: NONE"], "bare slots say NONE, in order")
	for gear_id in ["lsword", "helm", "chain", "lshield", "pdios"]:
		gear_hero.add_item(gear_id, true)
		gear_hero.items[-1]["eq"] = true
	main.rerender()
	gear_seen = gear_lines.call()
	check(gear_seen.slice(3, 7) == ["Weapon: LONG SWORD", "Helm: HELM", "Armor: CHAIN MAIL", "Shield: LARGE SHIELD"], "each slot names what is equipped")
	gear_hero.items = []
	gear_hero.add_item("lsword", false)
	gear_hero.items[-1]["eq"] = true
	main.rerender()
	check(gear_lines.call()[3] == "Weapon: SWORD?", "an unidentified weapon keeps its secret")
	check(main.town._gear_font("Weapon: STAFF OF MOGREF (BROKEN)") < main.town.GEAR_FONT, "a long name shrinks to fit")
	gear_hero.items = gear_keep
	main.town.shop(gear_hero)
	check(main.scr["title"] == "Boltac's Trading Post" and main._backdrop.texture == boltac_art, "the shop keeps the painting")
	check(main._gear.visible, "the shop keeps the party grid")
	check(main._gear.position.x >= 16.0 + main.BACKDROP_COLUMN and main._gear.position.y == main.GEAR_TOP, "the party grid sits at the top, right of the store window")
	press("B")
	check(main.scr["title"] == "Buy" and main._backdrop.texture == boltac_art, "buying keeps the painting")
	press("L")
	press("S")
	check(main.scr["title"] == "Sell" and main._backdrop.texture == boltac_art, "selling keeps the painting")
	press("L")
	press("L")
	check(main.scr["title"] == "Castle" and not main._backdrop.visible, "leaving Boltac's clears its painting")
	check(not main._gear.visible, "leaving Boltac's clears the party grid")
	check(not main._exit_row.visible and main._pager_row == null, "other screens have no EXIT at the lower left")
	main.town.temple()
	check(main._pager_row == null, "the Temple's list keeps its usual EXIT")
	main.town.castle()
	check(main._opts_flow.get_children().all(func(b): return not String(b.text).begins_with("LEAVE")), "the buttons say EXIT, not LEAVE")
	_click_spot("A")
	var inn_art: Texture2D = main._backdrop.texture
	check(main._backdrop.visible and inn_art != null and inn_art != boltac_art, "clicking the inn shows its own painting")
	check(absf(float(inn_art.get_width()) / inn_art.get_height() - 16.0 / 9.0) < 0.001, "the inn painting is 16:9")
	main.town.inn_rooms(g.party_chars()[0])
	check(main.scr["title"].begins_with("Welcome") and main._backdrop.texture == inn_art, "the rooms keep the painting")
	press("L")
	check(main.scr["title"].begins_with("Adventurer's Inn") and main._backdrop.texture == inn_art, "leaving the rooms returns to the inn")
	press("L")
	check(main.scr["title"] == "Castle" and not main._backdrop.visible, "leaving the inn clears its painting")
	var party_before: Array[int] = g.party.duplicate()
	press("R")
	check(main.scr["title"] == "Training Grounds" and g.party == party_before and not party_before.is_empty(), "the Training Grounds keep the party together")
	var retiree: Character = g.make_char("RETIREE", "HUMAN", "GOOD", Data.RACES["HUMAN"].duplicate(), "FIGHTER")
	g.party.append(retiree.id)
	main.chars._delete(retiree)
	check(g.party == party_before and g.ch(retiree.id) == null, "retiring a party member takes them out of the party")
	var fillers: Array[Character] = []
	while not g.roster_full():
		fillers.append(g.make_char("FILLER%d" % fillers.size(), "HUMAN", "GOOD", Data.RACES["HUMAN"].duplicate(), "FIGHTER"))
	check(g.roster.size() == 16, "the roster holds 16 characters")
	main.chars.training()
	press("C")
	check(main.scr["title"] == "Training Grounds", "a full roster cannot create a character")
	main.chars._delete(fillers.pop_back())
	press("C")
	check(main.scr["title"] == "Create a character", "deleting a character makes room for a new one")
	for filler in fillers:
		main.chars._delete(filler)
	press("L")
	press("T")
	await get_tree().process_frame
	await get_tree().process_frame
	check(main._table.get_global_rect().end.y <= main.size.y, "the party table fits the window over the temple painting")
	var long_named: Character = g.party_chars()[0]
	var real_name: String = long_named.name
	long_named.name = "BARTHOLOMEWSMIT"  # the longest name, which is what used to wrap
	main.town.castle()
	main.show_screen({"title": "Unpainted", "view": "edge"})
	await get_tree().process_frame
	await get_tree().process_frame
	var plain_height: int = main._party.get_content_height()
	main.town.temple()
	await get_tree().process_frame
	await get_tree().process_frame
	check(main._party.get_content_height() < plain_height, "the party table is compact over the temple painting (%d, normally %d)" % [main._party.get_content_height(), plain_height])
	var healed: Character = g.party_chars()[0]
	healed.hp -= 1  # a healing changes the table while the temple is showing
	main.town.temple()
	await get_tree().process_frame
	await get_tree().process_frame
	main.town.castle()
	main.show_screen({"title": "Unpainted", "view": "edge"})
	await get_tree().process_frame
	await get_tree().process_frame
	check(main._party.get_content_height() == plain_height, "the party table recovers its layout after the temple (%d, was %d)" % [main._party.get_content_height(), plain_height])
	healed.hp += 1
	long_named.name = real_name
	main.town.castle()


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	return ev


func _release() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	return ev


func _click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


func _scene_is(path: String) -> bool:
	for i in 4:
		await get_tree().process_frame
	return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path


## Company screen -> title screen -> game, with and without a saved game.
func _test_start_flow(g, roster_size: int) -> void:
	print("start-up flow")
	main.queue_free()
	g.save_game()
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/splash.tscn", "the game boots to the company screen")

	# The company screen moves on by itself, and a click skips it. Keys do nothing.
	get_tree().change_scene_to_file("res://scenes/splash.tscn")
	check(await _scene_is("res://scenes/splash.tscn"), "company screen loads")
	get_tree().current_scene._process(100.0)
	check(await _scene_is("res://scenes/title.tscn"), "company screen times out to the title")
	get_tree().change_scene_to_file("res://scenes/splash.tscn")
	await _scene_is("res://scenes/splash.tscn")
	get_tree().current_scene._input(_key(KEY_SPACE))
	check(await _scene_is("res://scenes/splash.tscn"), "a key does not skip the company screen")
	get_tree().current_scene._input(_click())
	check(await _scene_is("res://scenes/title.tscn"), "a click skips the company screen")

	# The title shows its painting and waits for a whole tap before its buttons appear.
	var title = get_tree().current_scene
	check(title.get_node("Art").texture == load("res://assets/images/title.webp"), "the title shows its painting")
	title._process(100.0)
	check(await _scene_is("res://scenes/title.tscn") and not title.nav.visible, "the title waits")
	title._input(_key(KEY_SPACE))
	check(not title.nav.visible, "a key does not bring up the buttons")
	title._input(_release())
	check(not title.nav.visible, "the release of the click that skipped the company screen does nothing")
	title._input(_click())
	check(not title.nav.visible, "a press alone cannot land on a button")
	title._input(_release())
	check(title.nav.visible and not title._tap.visible, "a tap brings up the buttons")
	check(await _scene_is("res://scenes/title.tscn") and title.get_node("Art").visible, "the title stays up behind the buttons")
	var title_rect: Rect2 = title.get_global_rect()
	var venture_rect: Rect2 = title.venture_button.get_global_rect()
	var options_rect: Rect2 = title.options_button.get_global_rect()
	check(absf(venture_rect.get_center().x - title_rect.get_center().x) < 1.0, "venture onwards stays centered")
	check(absf(venture_rect.get_center().y - title._tap.get_global_rect().get_center().y) < 1.0 and absf(venture_rect.get_center().x - title._tap.get_global_rect().get_center().x) < 1.0, "venture onwards takes the tap message's place")
	check(venture_rect.end.y < title_rect.end.y, "venture onwards fits on the screen")
	check(absf(options_rect.end.x - (title_rect.end.x - title.OPTIONS_MARGIN)) < 1.0 and absf(options_rect.end.y - (title_rect.end.y - title.OPTIONS_MARGIN)) < 1.0, "options sits in the bottom right corner")
	check(title.venture_button.text == "Venture Onwards" and title.options_button.text == "Options" and title.nav.get_child_count() == 2, "the title has its two buttons")
	check(title.venture_button.get_theme_stylebox("normal").bg_color == UiStyle.C_STONE2, "venture onwards is a regular button")
	check(title.options_button.get_theme_stylebox("normal").bg_color == UiStyle.C_BROWN and title.options_button.get_theme_font_size("font_size") == UiStyle.SMALL_BUTTON_FONT, "options is a small brown button")

	# Options opens the panel and Back closes it.
	title.options_button.pressed.emit()
	check(title.options_panel.visible and not title.nav.visible, "options opens its panel")
	check(title.fast_results_label.text == "Fast Combat Results" and not title.fast_results_button.on, "fast combat results starts off")
	check(title.fast_results_button is ToggleSwitch and title.fast_results_button.get_parent() == title.fast_results_label.get_parent() and title.fast_results_button.get_index() > title.fast_results_label.get_index(), "its switch sits to the right of its name")
	check(title.back_button.get_theme_stylebox("normal").bg_color == UiStyle.C_BROWN, "back is a small brown button")
	title.fast_results_button.pressed.emit()
	check(g.fast_results and title.fast_results_button.on, "the option turns on")
	g.load_settings()
	check(g.fast_results, "the option is remembered")
	title.fast_results_button.pressed.emit()
	check(not g.fast_results and not title.fast_results_button.on, "the option turns off")
	g.load_settings()
	check(not g.fast_results, "and stays off")
	title.back_button.pressed.emit()
	check(not title.options_panel.visible and title.nav.visible, "back returns to the title buttons")

	# Venture Onwards resumes the save.
	title.venture_button.pressed.emit()
	check(await _scene_is("res://scenes/main.tscn"), "venture onwards enters the game")
	check(g.roster.size() == roster_size, "venture onwards keeps the roster")
	check(get_tree().current_scene.scr.get("title", "") == "Castle", "a town save resumes at the castle")

	# A save out in the Maze resumes there, with its position and spells.
	var hero: Character = g.roster[0]
	hero.status = "OK"
	g.party.clear()
	g.party.append(hero.id)
	g.pos = {"x": 3, "y": 4, "z": 2, "d": 1}
	g.light = 30
	g.outs = []
	g.mode = "maze"
	g.save_game()
	await _venture_from_title()
	check(g.mode == "maze" and g.pos == {"x": 3, "y": 4, "z": 2, "d": 1}, "a maze save resumes on its square")
	check(g.light == 30 and g.party == [hero.id], "a maze save keeps the party and its light")
	check(get_tree().current_scene.scr.get("where", "") == "Maze · Level 2", "a maze save shows the maze")
	check(g.outs.is_empty(), "a resumed party is not stranded")
	var door_lv: MazeLevel = g.levels[2]
	var door := Vector3i(-1, -1, 0)
	for door_y in MazeLevel.N:
		for door_x in MazeLevel.N:
			for door_d in 4:
				var far := Vector2i(door_x + MazeLevel.DX[door_d], door_y + MazeLevel.DY[door_d])
				if door.x < 0 and door_lv.wall(door_x, door_y, door_d) == 2 and door_lv.in_bounds(far.x, far.y):
					door = Vector3i(door_x, door_y, door_d)
	var door_far := Vector2i(door.x + MazeLevel.DX[door.z], door.y + MazeLevel.DY[door.z])
	var door_start := {"x": door.x, "y": door.y, "z": 2, "d": door.z}
	g.pos = door_start.duplicate()
	var door_mz = get_tree().current_scene.mz
	door_mz.forward()
	check(g.pos["x"] == door_far.x and g.pos["y"] == door_far.y and g.door_open(2, door.x, door.y, door.z), "one push opens a door and walks through")
	check(g.door_open(2, door_far.x, door_far.y, (door.z + 2) % 4), "an opened door is open from the far side too")
	g.save_game()
	g.load_game()
	check(g.door_open(2, door.x, door.y, door.z), "an opened door stays open after a load")

	# The testing switches on screen.
	var sw_scene = get_tree().current_scene
	check(sw_scene.monsters_button.text == "MONSTERS: ON" and sw_scene.god_button.text == "GOD MODE: OFF", "the switches start with monsters on and god mode off")
	sw_scene.god_button.button_pressed = true
	sw_scene.monsters_button.button_pressed = false
	check(g.god_mode and not g.monsters_on, "the switches set god mode and monsters")
	check(sw_scene.monsters_button.text == "MONSTERS: OFF" and sw_scene.god_button.text == "GOD MODE: ON", "the switches show their state")
	var god_hero: Character = g.ch(g.party[0])
	god_hero.status = "OK"
	var god_hp: int = god_hero.hp
	var god_battle := Battle.new()
	god_battle.setup(false, true)
	for god_round in 25:
		god_battle.play_round(true)
	check(god_hero.hp == god_hp and god_hero.status == "OK", "god mode takes no damage or conditions in a fight")
	var most_groups := 0
	var keep_pos: Dictionary = g.pos.duplicate()
	g.pos["z"] = g.MAZE_LEVELS
	for group_try in 400:
		var group_battle := Battle.new()
		group_battle.setup(true, false)
		most_groups = maxi(most_groups, group_battle.groups.size())
	g.pos = keep_pos
	check(most_groups > 2 and most_groups <= Battle.MAX_GROUPS, "encounters can bring more than two groups, up to the limit")
	var four_battle := Battle.new()
	for four_id in ["ORC", "RAT", "SKEL", "MAGE1"]:
		four_battle.groups.append(Battle.mk_group(four_id, 2))
	four_battle.play_round(true)
	check(four_battle.alive_groups().size() == 4, "four groups can fight a round")

	# Choosing a target by clicking its card.
	var aim_battle := Battle.new()
	for aim_id in ["ORC", "RAT", "SKEL"]:
		aim_battle.groups.append(Battle.mk_group(aim_id, 2))
	sw_scene.fight.battle = aim_battle
	sw_scene.view.battle = aim_battle
	var aimed := [-1, 0]
	var aim_pick := func(aim_g: int): aimed[0] = aim_g
	var aim_back := func():  # like the real ones, going back shows another screen
		aimed[1] += 1
		sw_scene.show_screen({"title": "Back", "view": "combat", "opts": []})
	var aim_click := func(canvas: Vector2):
		var aim_ev := InputEventMouseButton.new()
		aim_ev.button_index = MOUSE_BUTTON_LEFT
		aim_ev.pressed = true
		aim_ev.position = sw_scene.view.view_point(canvas)
		sw_scene.view._gui_input(aim_ev)
	var aim_cards: Array = MazeView.card_rects(3)
	sw_scene.fight._choose_group([0, 1], aim_pick, aim_back)
	check(sw_scene._view_note.visible and sw_scene._view_note.text == "Choose a target", "the target screen asks for a target")
	check(sw_scene._view_note.get_theme_color("font_color") == Color.WHITE and sw_scene._view_note.get_theme_font_size("font_size") == PartyCards.FONT_SIZE and not sw_scene._view_note.has_theme_font_override("font"), "in white, in the party cards' font")
	check(sw_scene._view_note.get_parent() == sw_scene.view, "inside the Maze window")
	for note_groups in [2, 3, 4]:
		var note_battle := Battle.new()
		for note_g in note_groups:
			note_battle.groups.append(Battle.mk_group("RAT", 1))
		sw_scene.view.battle = note_battle
		sw_scene._place_view_note()
		var note_top: float = sw_scene._view_note.position.y
		var note_scale: float = sw_scene.view.size.y / MazeView.H
		check(note_top >= MazeView.card_rects(note_groups)[-1].end.y * note_scale, "under %d groups of monsters" % note_groups)
		check(note_top + sw_scene._view_note.size.y <= sw_scene.view.size.y, "and inside the window with %d groups" % note_groups)
		check(absf(sw_scene._view_note.position.x + sw_scene._view_note.size.x * 0.5 - sw_scene.view.size.x * 0.5) < 1.0, "and centered with %d groups" % note_groups)
	sw_scene.view.battle = sw_scene.fight.battle
	sw_scene._place_view_note()
	check(not sw_scene._title.visible and not sw_scene._body.visible and sw_scene._body.text == "", "the side window drops its title and the click text")
	aim_click.call(Vector2(4, 4))
	check(aimed[0] == -1, "clicking the Maze picks nothing")
	aim_click.call(aim_cards[2].get_center())
	check(aimed[0] == -1, "clicking a group out of reach picks nothing")
	aim_click.call(aim_cards[1].get_center())
	check(aimed[0] == 1, "clicking a card picks its group")
	aimed[0] = -1
	aim_click.call(aim_cards[0].get_center())
	check(aimed[0] == -1, "once picked, clicks do nothing")
	sw_scene.fight._choose_group([0, 1], aim_pick, aim_back)
	sw_scene._run(sw_scene.scr["opts"][0])
	check(aimed[1] == 1, "back leaves the target screen")
	aim_click.call(aim_cards[0].get_center())
	check(aimed[0] == -1, "clicks do nothing after going back")
	sw_scene.fight._choose_group([2], aim_pick, aim_back)
	check(aimed[0] == 2, "a lone target is picked without a click")
	aimed[0] = -1
	for aim_m in aim_battle.groups[0]["ms"]:
		aim_m["dead"] = true
	sw_scene.fight._choose_group([1, 2], aim_pick, aim_back)
	aim_click.call(MazeView.card_rects(2)[1].get_center())
	check(aimed[0] == 2, "cards follow the groups still alive")
	print("party grid")
	var turn_battle := Battle.new()
	turn_battle.groups.append(Battle.mk_group("SKEL", 2))
	sw_scene.fight.battle = turn_battle
	sw_scene.view.battle = turn_battle
	var keep_cls: String = god_hero.cls
	var keep_lvl: int = god_hero.lvl
	var keep_items := god_hero.items.duplicate()
	god_hero.items.clear()  # a found magic item would add USE ITEM to the options
	god_hero.lvl = 13
	var turn_labels := func(turn_i: int, turn_cls: String) -> Array:
		god_hero.cls = turn_cls
		var names := []
		for turn_o in sw_scene.fight._turn_options(turn_i, god_hero):
			if turn_o.get("in_widget", false) and not turn_o.get("hide", false):
				names.append(turn_o["label"])
		return names
	check(turn_labels.call(0, "FIGHTER") == ["FIGHT", "PARRY"], "a front row fighter can fight or parry")
	check(turn_labels.call(3, "FIGHTER") == ["PARRY"], "a back row fighter can only parry")
	check(turn_labels.call(0, "THIEF") == ["FIGHT", "BACKSTAB", "PARRY"], "a front row thief can backstab")
	check(turn_labels.call(3, "THIEF") == ["PARRY"], "a back row thief cannot")
	check(turn_labels.call(3, "MAGE") == ["CAST SPELL", "PARRY"], "a mage can cast from the back row")
	check(turn_labels.call(3, "PRIEST") == ["CAST SPELL", "DISPEL", "PARRY"], "a priest can cast and dispel")
	check(turn_labels.call(0, "BISHOP") == ["FIGHT", "CAST SPELL", "DISPEL", "PARRY"], "so can a bishop")
	check(turn_labels.call(0, "LORD") == ["FIGHT", "PARRY"] and turn_labels.call(0, "SAMURAI") == ["FIGHT", "PARRY"], "lords and samurai only fight and parry")
	god_hero.cls = "THIEF"
	var stab_ok := true
	var stab_hits := 0
	for stab_try in 200:
		turn_battle.results = []
		turn_battle._fight(god_hero, 0, true)
		for stab_res in turn_battle.results:
			if stab_res["hit"]:
				stab_hits += 1
				stab_ok = stab_ok and stab_res["text"].begins_with("BACKSTABS FOR ") and int(stab_res["text"].split(" ")[2]) % Battle.BACKSTAB_DAMAGE == 0
		for stab_m in turn_battle.groups[0]["ms"]:
			stab_m["dead"] = false
			stab_m["hp"] = 999
	check(stab_hits > 0 and stab_ok, "a backstab says so, and lands for multiplied damage")
	sw_scene.fight.next_cmd(0)
	var turn_grid: GridContainer = sw_scene.scr["widget"]
	var card_texts := func(card_i: int) -> Array:
		return turn_grid.get_child(card_i).find_children("*", "Label", true, false).map(func(n): return n.text)
	check(not sw_scene._view_note.visible and sw_scene._title.visible, "other screens hide the note and show their title")
	check(card_texts.call(0).has("LVL %d %s" % [god_hero.lvl, god_hero.cls]), "a combat card shows level and class")
	for card_i in turn_grid.get_child_count():
		check(not card_texts.call(card_i).any(func(t): return t.begins_with("Weapon:") or t.begins_with("Shield:")), "combat cards leave out equipment")
	check(turn_grid.columns == 3 and turn_grid.get_child_count() == 6, "the party shows as two rows of three")
	check(not sw_scene._table.visible, "the party table hides while the grid shows")
	var grid_buttons := turn_grid.get_child(0).find_children("*", "Button", true, false)
	check(grid_buttons.size() == 3 and grid_buttons[1].text == "BACKSTAB", "the options sit under the current character's portrait")
	check(turn_grid.get_child(1).find_children("*", "Button", true, false).is_empty(), "and no one else's")
	var flow_labels := []
	for flow_b in sw_scene._opts_flow.get_children():
		if not flow_b.is_queued_for_deletion():
			flow_labels.append(flow_b.text)
	check(not flow_labels.has("PARRY") and not flow_labels.has("USE ITEM") and flow_labels.has("RUN"), "only the party's options sit below the grid")
	var item_id := ""
	for item_key in Data.ITEMS:
		var item_spell = Data.ITEMS[item_key].get("spell")
		if item_spell != null and "CA".contains(Data.SPELLS[item_spell][2]):
			item_id = item_key
	check(item_id != "", "there is a magic item that works in a fight")
	var magic_item := {"id": item_id}
	god_hero.items.append(magic_item)
	var item_labels: Array = turn_labels.call(0, "THIEF")
	god_hero.items.erase(magic_item)
	check(item_labels.has("USE ITEM"), "a character with a magic item can use it, under their portrait")
	check(not turn_labels.call(0, "THIEF").has("USE ITEM"), "one without has no such option")
	god_hero.cls = "THIEF"
	sw_scene.fight.next_cmd(0)
	turn_grid = sw_scene.scr["widget"]
	grid_buttons = turn_grid.get_child(0).find_children("*", "Button", true, false)
	grid_buttons[2].pressed.emit()
	check(turn_battle.cmds.size() == 1 and turn_battle.cmds[0]["type"] == "parry", "a portrait's button gives the order")
	var back_opts: Array = sw_scene.scr["opts"].filter(func(back_o): return back_o["label"] == "BACK" and not back_o.get("hide", false))
	check(back_opts.size() == 1, "back appears once an order is given")
	sw_scene._run(back_opts[0])
	check(turn_battle.cmds.is_empty(), "back takes back the order")
	check(sw_scene.fight._active == 0 and sw_scene.scr.get("title", "") == "%s's options" % god_hero.name, "back returns to that character")
	var alive_grid: GridContainer = sw_scene.fight._party_grid()
	check(alive_grid.get_child(0).find_child("Tombstone", true, false) == null, "the living have no tombstone")
	alive_grid.free()
	var keep_status: String = god_hero.status
	god_hero.status = "DEAD"
	var tomb_grid: GridContainer = sw_scene.fight._party_grid()
	check(tomb_grid.get_child(0).find_child("Tombstone", true, false) != null, "the dead have a tombstone on their portrait")
	check(tomb_grid.get_child(0).get_theme_stylebox("panel").bg_color == PartyCards.DEAD_FILL, "a dead character's box is shaded red")
	god_hero.status = keep_status
	var alive_grid2: GridContainer = sw_scene.fight._party_grid()
	check(alive_grid2.get_child(0).get_theme_stylebox("panel").bg_color != PartyCards.DEAD_FILL, "a living character's box is not")
	alive_grid2.free()
	tomb_grid.free()
	god_hero.status = keep_status
	god_hero.cls = keep_cls
	god_hero.items.assign(keep_items)
	god_hero.lvl = keep_lvl
	sw_scene.mz.maze()
	check(sw_scene._table.visible, "the party table returns after the fight")
	print("attack sounds")
	var slime_attacks: Array = MonsterSounds.BY_MONSTER["SLIME"][MonsterSounds.ATTACK]
	check(slime_attacks.size() == 4, "the slime has its four attack sounds")
	for sfx_stream in slime_attacks:
		check(sfx_stream is AudioStreamWAV and sfx_stream.get_length() > 1.0, "a slime sound loads")
	var sound_events: Array = [MonsterSounds.IDLE] + MonsterSounds.LOUDEST_FIRST
	check(sound_events.size() == 4, "a monster has four kinds of sound")
	for sfx_id in MonsterSounds.BY_MONSTER:
		check(Data.MONS.has(sfx_id), "%s is a monster" % sfx_id)
		for sfx_event in MonsterSounds.BY_MONSTER[sfx_id]:
			check(sound_events.has(sfx_event), "%s is a kind of sound" % sfx_event)
	var fake_sounds := {"ORC": {"idle": ["orc idle"], "attack": ["orc attack"], "hit": ["orc hit"], "death": ["orc death"]}, "RAT": {"hit": ["rat hit"], "idle": ["rat idle"]}}
	var orc_event := func(event: String) -> Dictionary:
		return {"id": "ORC", "event": event}
	check(MonsterSounds.for_events([orc_event.call("attack")], fake_sounds) == ["orc attack"], "an attack plays the attack sound")
	check(MonsterSounds.for_events([orc_event.call("hit")], fake_sounds) == ["orc hit"], "a hit plays the hit sound")
	check(MonsterSounds.for_events([orc_event.call("hit"), orc_event.call("death")], fake_sounds) == ["orc death"], "a death is heard over a hit")
	check(MonsterSounds.for_events([{"id": "RAT", "event": "death"}, orc_event.call("hit")], fake_sounds) == ["orc hit"], "a monster with no death sound lets another's hit be heard")
	check(MonsterSounds.for_events([{"id": "RAT", "event": "attack"}], fake_sounds).is_empty(), "a missing sound is silent")
	check(MonsterSounds.idle_for(["ORC", "RAT", "SLIME"], fake_sounds) == ["orc idle", "rat idle"], "idle sounds come from the monsters present")
	var sound_battle := Battle.new()
	sound_battle.groups.append(Battle.mk_group("ORC", 2))
	var sound_orc: Dictionary = sound_battle.groups[0]["ms"][0]
	sound_orc["hp"] = 10
	sound_battle._hurt(sound_orc, 1)
	check(sound_battle.sounds == [{"id": "ORC", "event": "hit"}], "a monster that lives through damage is hit")
	sound_battle.sounds = []
	sound_battle._hurt(sound_orc, 99)
	check(sound_battle.sounds == [{"id": "ORC", "event": "death"}], "a monster that doesn't dies")
	var sfx_fight: CombatScreens = sw_scene.fight
	var sfx_start := func(sfx_id: String, sfx_n: int) -> Battle:
		var sfx_b := Battle.new()
		sfx_b.groups.append(Battle.mk_group(sfx_id, sfx_n))
		sfx_b.round_no = 1
		sfx_fight.battle = sfx_b
		sw_scene.view.battle = sfx_b
		sfx_fight.sounds_played = 0
		sfx_fight._fight_round()
		return sfx_b
	sfx_start.call("SLIME", 5)
	check(sfx_fight.sounds_played == 1 and sw_scene.view._results.size() == 1, "the first attack's sound and result come together")
	sw_scene.view._process(MazeView.STEP_GAP - 0.1)
	check(sfx_fight.sounds_played == 1, "the next attack waits its turn")
	sw_scene.view._process(0.2)
	check(sfx_fight.sounds_played == 2 and sw_scene.view._results.size() == 2, "the next attack brings its own sound and result")
	sfx_start.call("RAT", 3)
	check(sfx_fight.sounds_played == 0 and sw_scene.view._results.size() == 1, "monsters without sounds still show their attack")
	var mon_res: Dictionary = sw_scene.view._results[0]
	check((String(mon_res["who"]).begins_with("HITS ") and String(mon_res["text"]).ends_with(" DAMAGE")) or mon_res["who"] == "MISSES", "a monster's attack says what it did")
	sw_scene.view.show_view("combat")
	sw_scene.view._process(MazeView.STEP_GAP + 0.1)
	check(sfx_fight.sounds_played == 0 and sw_scene.view._results.is_empty(), "leaving stops the round")
	print("fight results")
	var res_battle := Battle.new()
	res_battle.groups.append(Battle.mk_group("ORC", 2))
	res_battle.groups.append(Battle.mk_group("RAT", 2))
	res_battle.round_no = 1
	sw_scene.fight.battle = res_battle
	sw_scene.view.battle = res_battle
	for res_try in 30:
		res_battle.results = []
		res_battle._fight(god_hero, 1)
		if res_battle.alive_groups().has(1):
			check(res_battle.results.size() == 1 and res_battle.results[0]["g"] == 1, "an attack leaves one result on its target")
			var res_text: String = res_battle.results[0]["text"]
			check((res_text == "MISSES!" and not res_battle.results[0]["hit"]) or (res_text.begins_with("HITS FOR ") and res_text.ends_with(" DAMAGE") and res_battle.results[0]["hit"]), "the result reads MISSES! or HITS FOR x DAMAGE")
			check(res_battle.results[0]["who"] == god_hero.name, "the result names the attacker")
		for res_m in res_battle.groups[1]["ms"]:
			res_m["dead"] = false
			res_m["hp"] = 5
	for res_gp in res_battle.groups:  # none of them can die, so all four monsters get their attack
		for res_m in res_gp["ms"]:
			res_m["hp"] = 9999
	res_battle.cmds = [{"c": god_hero, "type": "fight", "g": 0}]
	sw_scene.fight._fight_round()
	check(sw_scene.scr.get("title", "") == "Round 1" and sw_scene.view._results.size() == 1, "a round starts with one attack showing")
	var res_steps := 0
	while sw_scene.scr.get("title", "") == "Round 1" and res_steps < 200:
		sw_scene.view._process(0.2)
		res_steps += 1
	check(res_steps > 8 and res_steps < 200 and sw_scene.view._results.is_empty(), "the fight moves on once the round has played and faded")
	check(res_battle.results.size() >= 4, "every attack in the round has a result")
	var hold_calls := [0]
	sw_scene.view.show_results([0], [{"g": 0, "text": "MISSES!", "hit": false}], func(): hold_calls[0] += 1)
	sw_scene.view._process(MazeView.RESULT_HOLD + MazeView.RESULT_FADE - 0.1)
	check(hold_calls[0] == 0, "a result stays up for its time")
	sw_scene.view._process(0.2)
	check(hold_calls[0] == 1, "then fades")
	g.fast_results = true
	sw_scene.view.show_results([0], [{"g": 0, "text": "MISSES!", "hit": false}], func(): hold_calls[0] += 1)
	sw_scene.view._process(MazeView.FAST_RESULT_HOLD + MazeView.FAST_RESULT_FADE - 0.1)
	check(hold_calls[0] == 1, "fast combat results still shows the result")
	sw_scene.view._process(0.2)
	check(hold_calls[0] == 2, "for half a second")
	check(sw_scene.view._step_gap() == MazeView.FAST_STEP_GAP, "and attacks come faster")
	g.fast_results = false
	var res_calls := [0]
	sw_scene.view.show_results([0], [{"g": 0, "text": "MISS!", "hit": false}], func(): res_calls[0] += 1)
	sw_scene.view.show_view("combat")
	sw_scene.view._process(5.0)
	check(res_calls[0] == 0 and sw_scene.view._results.is_empty(), "leaving cancels the results")
	sw_scene.fight.battle = null
	sw_scene.view.battle = null
	sw_scene.fight._hurt(god_hero, 50)
	check(god_hero.hp == god_hp and god_hero.is_alive(), "god mode takes no damage from traps")
	var quiet_lv: MazeLevel = g.levels[g.MAZE_LEVELS]
	var boss_at := Vector2i(-1, -1)
	for quiet_y in MazeLevel.N:
		for quiet_x in MazeLevel.N:
			if quiet_lv.flag(quiet_x, quiet_y, "boss"):
				boss_at = Vector2i(quiet_x, quiet_y)
	check(boss_at.x >= 0, "the boss square exists")
	g.pos = {"x": boss_at.x, "y": boss_at.y, "z": g.MAZE_LEVELS, "d": 0}
	g.cleared = {}
	sw_scene.fight.battle = null  # walking through the door above can start one
	for quiet_step in 300:
		sw_scene.mz._after_step()
	check(sw_scene.fight.battle == null, "with monsters off, no fight starts, even on the boss square")
	sw_scene.monsters_button.button_pressed = true
	sw_scene.mz._after_step()
	check(sw_scene.fight.battle != null, "with monsters on, the boss fights again")
	sw_scene.fight.battle = null
	sw_scene.god_button.button_pressed = false
	check(not g.god_mode and g.monsters_on, "the switches go back")
	g.hurt(god_hero, 1)
	check(god_hero.hp == god_hp - 1, "damage counts again with god mode off")
	god_hero.hp = god_hp
	g.pos = {"x": 3, "y": 4, "z": 2, "d": 1}
	g.light = 30
	sw_scene.mz.maze()
	check(not sw_scene.town_button.disabled, "the town button works in the Maze")
	var home_gold: int = god_hero.gold
	var home_xp: int = god_hero.xp
	var home_items: int = god_hero.items.size()
	god_hero.hp = god_hp - 3
	sw_scene.town_button.pressed.emit()
	check(g.mode == "castle" and sw_scene.scr.get("title", "") == "Castle", "the town button brings the party to the castle")
	check(god_hero.loc == "CASTLE" and g.party.has(god_hero.id), "the party comes home together")
	check(god_hero.gold == home_gold and god_hero.xp == home_xp and god_hero.items.size() == home_items and god_hero.hp == god_hp - 3 and god_hero.status == "OK", "the town button costs nothing")
	check(sw_scene.town_button.disabled, "the town button is off at the castle")
	sw_scene.mz.camp()
	check(not sw_scene.town_button.disabled, "the town button works in camp")
	sw_scene.town_button.pressed.emit()
	check(g.mode == "castle" and not sw_scene.view.world.has_campfire(), "leaving camp by the town button puts the campfire out")
	g.pos = {"x": 3, "y": 4, "z": 2, "d": 1}
	god_hero.loc = "MAZE"
	sw_scene.fight.encounter(false, false)
	check(sw_scene.fight.battle != null, "a fight has started")
	sw_scene.town_button.pressed.emit()
	check(g.mode == "castle" and sw_scene.fight.battle == null and sw_scene.view.battle == null, "the town button escapes a fight")
	check(sw_scene.scr.get("title", "") == "Castle", "and shows the castle")
	god_hero.loc = "MAZE"
	god_hero.hp = god_hp
	g.pos = {"x": 3, "y": 4, "z": 2, "d": 1}
	g.mode = "maze"
	g.mode = "camp"
	g.save_game()
	await _venture_from_title()
	check(g.mode == "camp", "a camp save resumes in camp")
	var camp_scene = get_tree().current_scene
	var camp_world: MazeWorld = camp_scene.view.world
	var pack_here := ResourceLoader.exists(MazeWorld.CAMPFIRE_SCENE)
	check(camp_world.has_campfire() == pack_here, "camp lights the campfire if the fire pack is installed")
	if pack_here:
		var fire_at: Vector3 = camp_world._campfire.position
		check(is_equal_approx(fire_at.y, 0.0), "the campfire sits on the floor")
		check(fire_at.distance_to(MazeWorld.cell_centre(Vector2i(g.pos["x"], g.pos["y"]))) < MazeWorld.CELL / 2.0, "the campfire is on the party's square")
		var campfire_sound: AudioStreamPlayer3D = camp_world._campfire.get_node("Audio")
		check(campfire_sound.autoplay and campfire_sound.stream != null, "the campfire has its sound")
		check(camp_world._campfire.find_children("*", "OmniLight3D", true, false).is_empty() and camp_world._campfire_light.visible, "the campfire uses its own steady light, not the pack's")
		var no_pack_light := true
		for part in camp_world._campfire.get_children():
			no_pack_light = no_pack_light and not ("intensity_multiplier" in part)
		check(no_pack_light, "the pack's light node is gone from the campfire")
	camp_scene.mz.maze()
	check(not camp_world.has_campfire() and not camp_world._campfire_light.visible, "leaving camp puts the campfire and its light out")
	g.mode = "combat"
	g.save_game()
	await _venture_from_title()
	check(g.mode == "maze" and get_tree().current_scene.fight.battle == null, "a save from a fight resumes in the maze")
	g.ch(g.party[0]).status = "DEAD"
	g.save_game()
	await _venture_from_title()
	check(get_tree().current_scene.scr.get("title", "") == "Your party is wiped out" and g.party.is_empty(), "a dead party resumes as wiped out")

	# With nothing saved, Venture Onwards starts a new game at the castle.
	g.set_fast_results(true)
	g.new_game()
	check(g.fast_results, "a new game keeps the options")
	g.set_fast_results(false)
	check(not g.door_open(2, door.x, door.y, door.z), "a new game closes the doors")
	check(not FileAccess.file_exists(g.save_path), "starting over deletes the save")
	await _venture_from_title()
	check(g.roster.is_empty() and g.mode == "castle", "no save starts a new game at the castle")
	check(get_tree().current_scene.scr.get("title", "") == "Welcome to the Underworlds", "a new game shows the welcome")


func _venture_from_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
	await _scene_is("res://scenes/title.tscn")
	var title = get_tree().current_scene
	title._input(_click())
	title._input(_release())
	title.venture_button.pressed.emit()
	await _scene_is("res://scenes/main.tscn")

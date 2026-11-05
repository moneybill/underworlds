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
	MazeView.instant_fades = true  # leaving camp fades; only its own test waits for it
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
	check(_row_labels("left") == ["SELECT", "RANDOM"] and _row_labels("right") == ["BACK"], "the name screen has SELECT and RANDOM, and BACK at the right")
	check(Data.MALE_NAMES.size() == 100 and Data.MALE_NAMES.has("WESLEY") and Data.MALE_NAMES.has("ALDRIC") and not Data.MALE_NAMES.has("AELARA"), "the male names are marked")
	check(Data.FEMALE_NAMES.size() == 100 and Data.FEMALE_NAMES.has("AELARA") and not Data.FEMALE_NAMES.has("ALDRIC"), "and so are the female ones")
	check(Data.CHARACTER_NAMES.size() == 200 and Data.CHARACTER_NAMES.has("ALDRIC") and Data.CHARACTER_NAMES.has("AELARA") and Data.CHARACTER_NAMES.all(func(n): return n == n.to_upper() and n.length() <= 15 and Data.CHARACTER_NAMES.count(n) == 1), "the names fit the entry, in capitals, with no repeats")
	check(Data.LAST_NAMES.size() == 165 and Data.LAST_NAMES.count("BLACKTHORN") == 1 and Data.LAST_NAMES.count("WOLFSBANE") == 1 and Data.LAST_NAMES.has("EVERDARK"), "the last names have their duplicates removed")
	check(Data.LAST_NAMES.all(func(n): return n == n.to_upper() and Data.LAST_NAMES.count(n) == 1), "all of them")
	check(Data.MALE_TITLES == ["SIR", "LORD", "DUKE", "BARON", "MARQUIS"] and Data.FEMALE_TITLES == ["LADY", "DUCHESS", "DAME", "BARONESS", "MARQUESS"], "the titles are kept for later")
	var name_longest := 0
	for name_first in Data.CHARACTER_NAMES:
		name_longest = maxi(name_longest, name_first.length())
	var name_longest_last := 0
	for name_last in Data.LAST_NAMES:
		name_longest_last = maxi(name_longest_last, name_last.length())
	check(name_longest + 1 + name_longest_last <= Data.MAX_NAME and main._entry.max_length == Data.MAX_NAME, "the box has room for the longest pair")
	var fit_mono: Font = UiStyle.mono_font()
	var fit_long := "BELLADONNA THORNBREAKER"
	var fit_card: int = PartyCards.fit_font(fit_long, PartyCards.NAME_ROOM, PartyCards.FONT_SIZE)
	check(fit_card < PartyCards.FONT_SIZE and fit_mono.get_string_size(fit_long, HORIZONTAL_ALIGNMENT_LEFT, -1, fit_card).x <= PartyCards.NAME_ROOM, "a long name shrinks to fit a party card")
	var fit_roster: int = PartyCards.fit_font(fit_long, main.chars.ROSTER_CARD_WIDTH, main.chars.ROSTER_FONT)
	check(fit_mono.get_string_size(fit_long, HORIZONTAL_ALIGNMENT_LEFT, -1, fit_roster).x <= main.chars.ROSTER_CARD_WIDTH, "and a roster card")
	check(PartyCards.fit_font("FAY", PartyCards.NAME_ROOM, PartyCards.FONT_SIZE) == PartyCards.FONT_SIZE, "a short one keeps its size")
	var name_seen := {}
	var name_ok := true
	var name_alone := 0
	var name_title: String = main.scr["title"]
	for name_try in 300:
		var name_before: String = main._entry.text
		press("R")
		var name_parts: PackedStringArray = main._entry.text.split(" ")
		name_seen[main._entry.text] = true
		name_ok = name_ok and name_parts.size() <= 2 and Data.CHARACTER_NAMES.has(name_parts[0]) and (name_parts.size() == 1 or Data.LAST_NAMES.has(name_parts[1])) and main._entry.text != name_before
		name_alone += 1 if name_parts.size() == 1 else 0
		name_ok = name_ok and not name_parts[0] in Data.MALE_TITLES and not name_parts[0] in Data.FEMALE_TITLES
	check(name_ok and name_seen.size() > 200 and main.scr["title"] == name_title, "RANDOM fills in a name, different each time, and stays on the screen")
	check(name_alone > 100 and name_alone < 200, "about half of them have no last name (%d of 300)" % name_alone)
	var name_taken: Character = g.make_char(main._entry.text, "HUMAN", "GOOD", Data.RACES["HUMAN"].duplicate(), "FIGHTER")
	check(g.roster.any(func(o): return o.name == main._entry.text), "the box's name is on the roster")
	press("R")
	check(main._entry.text != name_taken.name, "and a name on the roster isn't offered")
	main.set_input_text("CUSTOM")
	check(main._entry.text == "CUSTOM", "the box can still be typed over")
	g.roster.erase(name_taken)
	press("R")
	main._submit_input()
	check(main.scr["title"] != name_title, "SELECT accepts the random name")
	main.chars.create_name()
	main._entry.text = "buttoned"
	check(_row_button("right", 0).get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "BACK is brown")
	check(main.scr["opts"][-1]["label"] == "BACK" and main.scr["opts"][-1]["fn"] == main.chars.training, "and goes back to the Proving Grounds")
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
	check(main.scr["title"] == "Character Sheet", "inspect from the tavern")
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
	check(main.scr["title"] == "Cathedral of Rebirth", "temple tithe resolves (bind order)")
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
	check(main._exit_row.get_parent() == main._body.get_parent() and main._exit_row.get_index() > main._body.get_index(), "EXIT sits under the text")
	var tavern_cell: Control = main._gear_grid.get_child(0)
	var tavern_hit: Button = tavern_cell.get_child(1)
	tavern_hit.pressed.emit()
	check(main._gear_grid.get_child(0).get_theme_stylebox("panel").border_color == PartyCards.SELECTED_EDGE, "clicking a card selects that member")
	check(main._gear_grid.get_child(0).get_theme_stylebox("panel").border_width_top == PartyCards.SELECTED_WIDTH and main._gear_grid.get_child(1).get_theme_stylebox("panel").border_width_top == 1, "the selected card's edge is much heavier than the others'")
	check(main._gear_grid.get_child(0).get_combined_minimum_size().y == main._gear_grid.get_child(1).get_combined_minimum_size().y, "and it stays the same size")
	var tavern_row: Control = main._gear_row
	check(tavern_button.call("ADD").get_parent() == tavern_row.get_child(0) and tavern_button.call("ADD").get_index() == 0 and tavern_button.call("DROP").get_index() == 1, "DROP sits right of ADD")
	check(tavern_button.call("DIVVY GOLD").get_parent() == tavern_row.get_child(1), "DIVVY GOLD sits in the center")
	check(tavern_button.call("ADD").get_theme_stylebox("normal").bg_color == UiStyle.C_STONE2, "ADD is blue")
	for brown_label in ["DROP", "DIVVY GOLD", "INSPECT"]:
		var brown: Button = tavern_button.call(brown_label)
		check(brown.get_theme_stylebox("normal").bg_color == main.PAGER_FILL and brown.get_theme_font_size("font_size") == main.PAGER_FONT, "the Tavern's %s is small and brown" % brown_label)
	check(tavern_button.call("INSPECT").get_parent() == tavern_row.get_child(2), "INSPECT sits at the far right")
	tavern_button.call("INSPECT").pressed.emit()
	check(main.scr["title"] == "Character Sheet" and main._sheet.visible and main._sheet.find_child("Stats", true, false).text.contains(tavern_first.name), "INSPECT opens the selected member's sheet")
	press("L")
	check(main._gear_grid.get_child(0).get_theme_stylebox("panel").border_color == PartyCards.SELECTED_EDGE, "the selection survives inspecting")
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
	check(main.scr["body"].contains("rhythmic clang"), "Boltac's has its description")
	check(tavern_labels.call().is_empty() and exit_button.call().text == "EXIT", "Boltac's lists no names and has EXIT in the left panel")
	check(not main.scr["body"].contains("Click a party member") and main._gear_grid.get_parent().get_child(0).text == "Click a party member to select them.", "Boltac's hint tops the cards too")
	check(tavern_button.call("BUY") == null and tavern_button.call("POOL GOLD") == null, "nobody selected at Boltac's, no shop buttons")
	main._gear_grid.get_child(1).get_child(1).pressed.emit()
	check(main._gear_grid.get_child(1).get_theme_stylebox("panel").border_color == PartyCards.SELECTED_EDGE, "clicking a card at Boltac's selects that member")
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
	check(main.scr["title"] == "Buy" and main._gear_grid.get_child(1).get_theme_stylebox("panel").border_color == PartyCards.SELECTED_EDGE, "the buyer stays highlighted while buying")
	var switch_from: Character = g.party_chars()[1]
	var switch_to: Character = g.party_chars()[2]
	main.town.buy(switch_from, 1)
	check(main._gear_grid.get_child(2).get_child_count() == 2, "another member's card can be clicked while buying")
	check(main._gear_grid.get_parent().get_child(0).text == TownScreens.SELECT_HINT, "the hint stays up while buying")
	check(main.scr["opts"][-1]["label"] == "BACK" and main._pager_row.get_child(-1).text == "BACK", "Buy leaves by BACK")
	main._gear_grid.get_child(2).get_child(1).pressed.emit()
	check(main.town._selected == switch_to and main.scr["title"] == "Buy" and main._gear_grid.get_child(2).get_theme_stylebox("panel").border_color == PartyCards.SELECTED_EDGE, "clicking a card switches the buyer and stays on Buy")
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
	check(main.scr["title"] == "The Broken Anvil" and tavern_button.call("BUY") != null, "leaving Buy returns to the shop with the member still selected")
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
	check(main.scr["title"] == "Character Sheet" and main._backdrop.texture == tavern_art, "inspecting keeps the tavern painting")
	var inspect_hero: Character = g.party_chars()[0]
	var inspect_keep: String = inspect_hero.portrait
	inspect_hero.portrait = "female_1"
	main.chars.inspect(inspect_hero, "tavern", main.town.tavern)
	check(main._gear.visible and main._sheet.visible and main._popup_block.visible, "inspecting opens a window over the screen it was called from, which stays up")
	check(main._popup_block.mouse_filter == Control.MOUSE_FILTER_STOP and main._sheet.get_index() > main._gear.get_index() and main._popup_block.get_index() > main._gear.get_index(), "and it takes the clicks")
	await get_tree().process_frame
	await get_tree().process_frame
	check(absf(main._sheet.get_rect().get_center().x - main.size.x * 0.5) < 2.0, "centered in the window")
	check(main._sheet.find_children("*", "RichTextLabel", true, false).any(func(t): return t.text == inspect_hero.bio()), "with the character's story in it")
	check(_row_labels("right") == ["CLOSE"], "its way out says CLOSE")
	var popup_title: Label = main._sheet.find_child("PopupTitle", true, false)
	check(popup_title.text == "Character Sheet" and popup_title.get_parent().get_child(0) == popup_title, "the window is titled Character Sheet, at its top")
	check(popup_title.get_theme_color("font_color") == main._title.get_theme_color("font_color") and popup_title.get_theme_font("font") == main._title.get_theme_font("font"), "in the color and font of the screen's title")
	check(popup_title.get_theme_font_size("font_size") == main._title.get_theme_font_size("font_size") - 2, "two sizes smaller")
	var popup_town_title := "The Red Dragon Inn"
	press("L")
	check(not main._sheet.visible and not main._popup_block.visible and main.scr["title"] == popup_town_title, "CLOSE leaves the screen it was called from")
	main.chars.inspect(inspect_hero, "tavern", main.town.tavern)
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
	check(_row_labels("left") == ["POOL GOLD"] and _row_labels("right") == ["CLOSE"], "the bottom of the window has POOL GOLD, and CLOSE at the right")
	var left_buttons: Array = [_row_button("left", 0), _row_button("right", 0)]
	check(left_buttons.all(func(b): return b.get_theme_stylebox("normal").bg_color == main.PAGER_FILL and b.get_theme_font_size("font_size") == main.PAGER_FONT), "and they are small and brown")
	check(main._sheet.get_child(0).get_child(1).find_children("*", "Button", true, false).all(func(b): return b.text != "CLOSE" and b.text != "POOL GOLD"), "and neither is on the sheet")
	var sheet_kids: Array = sheet_part.call("Equipment").get_parent().get_children()
	check(sheet_kids.find(sheet_part.call("Equipment")) == sheet_kids.find(sheet_part.call("Spells")) + 1 and sheet_part.call("Spells").fit_content, "Equipment follows straight after the spells, however few")
	check(main._sheet.get_child(0).get_child(2).text == main.esc(inspect_hero.bio()), "the character's bio is under the sheet")
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
	check(main.scr["title"] == "The Red Dragon Inn", "inspect returns to the tavern")
	check(main._gear.visible, "the grid comes back after inspecting")
	press("L")
	check(main.scr["title"] == "Castle" and not main._backdrop.visible, "leaving the tavern clears its painting")
	check(not main._gear.visible, "leaving the tavern clears the grid")
	party[5].status = "OK"
	party[5].hp = party[5].maxhp
	party[0].xp = 5000
	main.town.select_guest(party[0])
	press("S")
	check(party[0].lvl >= 2, "inn level-up")
	press("Enter")
	check(main.scr["title"] == "The Drunken Slumber" and main.town._selected == party[0], "after a stay the guest stays selected")
	main.town.castle()

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
const NEW_ITEMS_WITHOUT_PICTURES := ["ward", "amufire"]  # until the amulets are painted


func _test_class_gear() -> void:
	var slots := func(cls: String) -> Array:
		var who := Character.new()
		who.cls = cls
		return TownScreens.gear_slots(who).map(func(g): return g[0])
	check(slots.call("MAGE") == ["Weapon", "Amulet", "Armor", "Ring"], "mages wear an amulet and a ring")
	check(slots.call("BISHOP") == ["Weapon", "Amulet", "Armor", "Cross"], "bishops an amulet and a cross")
	check(slots.call("PRIEST") == ["Weapon", "Cross", "Armor", "Shield"], "priests a cross")
	check(slots.call("THIEF") == ["Weapon", "Hood", "Armor", "Shield"], "thieves a hood")
	check(slots.call("FIGHTER") == ["Weapon", "Helm", "Armor", "Shield"], "and fighters a helm and shield")
	for cls in TownScreens.CLASS_GEAR:
		var letter: String = Data.CLASSES[cls]["l"]
		for g in TownScreens.CLASS_GEAR[cls]:
			check(Data.class_uses_slot(letter, g[1]), "a %s has something to wear as %s" % [cls, g[0]])
	check(Data.ITEMS["hood"]["slot"] == "H" and Data.ITEMS["hood"]["cls"] == "T", "only thieves wear hoods")
	check(Data.SHOP_START.has("ring") and Data.ITEMS["ring"]["slot"] == "R", "the Broken Anvil sells a plain ring")
	check(Data.ITEMS["ringprot"]["cls"] == "M" and Data.ITEMS.values().all(func(d): return d["slot"] != "R" or d["cls"] == "M"), "only mages wear rings")
	check(Data.ITEMS["ringheal"]["name"] == "BOOK OF HEALING" and Data.ITEMS["ringheal"]["cls"] == Data.ALL_CLASSES and Data.ITEMS["ringheal"]["slot"] == "U", "anyone may carry the Book of Healing")
	check(Data.ITEMS["amulet"]["slot"] == "Q", "Werdna's Amulet is carried, not worn")
	var hero: Character = Game.roster[0]
	var kept: Array = hero.items.duplicate(true)
	hero.items = []
	hero.add_item("cross1", true)
	check(hero.worn_bonus("dispel") == 0, "a cross in the pack does nothing")
	hero.items[0]["eq"] = true
	check(hero.worn_bonus("dispel") == 3, "worn, a Silver Cross dispels as if three levels higher")
	var base_level := LockScreens.thief_level(hero)
	hero.items = []
	hero.add_item("hood1", true)
	hero.items[0]["eq"] = true
	check(LockScreens.thief_level(hero) == base_level + 2, "a Shadow Hood picks locks as if two levels higher")
	hero.items.assign(kept)


func _test_small_buttons() -> void:
	var b := Button.new()
	b.text = "CAMP"
	UiStyle.make_small_button(b)
	var pads := []
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box: StyleBox = b.get_theme_stylebox(st)
		pads.append(Vector4(box.content_margin_left, box.content_margin_right, box.content_margin_top, box.content_margin_bottom))
	check(pads.all(func(p): return p == pads[0]), "a small button keeps its padding when pressed, so no letter drops off")
	b.free()


func _test_item_icons() -> void:
	var missing := []
	for id in Data.ITEMS:
		var slot: String = Data.ITEMS[id]["slot"]
		if Data.item_icon(id) == "":
			missing.append(id)
	missing = missing.filter(func(id): return not NEW_ITEMS_WITHOUT_PICTURES.has(id))
	check(missing.is_empty(), "every item has a picture: %s" % [missing])
	for id in Data.ITEM_ICONS:
		check(ResourceLoader.exists(Data.item_icon(id)), "the picture for %s is there" % id)
	check(Data.item_icon("lsword2", false) == Data.item_icon("lsword") and Data.item_icon("lsword2") != Data.item_icon("lsword"), "an unknown LONG SWORD +2 looks like a plain long sword until identified")
	check(Data.item_icon("plato", false) == Data.item_icon("pdios") and Data.item_icon("plato") != Data.item_icon("pdios"), "an unknown potion looks like a Potion of DIOS until identified")
	var hero: Character = Game.party_chars()[0] if not Game.party_chars().is_empty() else Game.roster[0]
	var hero_items: Array = hero.items.duplicate(true)
	hero.items = []
	hero.add_item("evilsw", true)
	check(main.item_lines(hero).contains("[img=") and main.item_lines(hero).contains("EvilSword"), "the character sheet shows the picture beside the name")
	hero.items.assign(hero_items)
	main.choose_list("Pick", "", [{"label": "LONG SWORD", "icon": Data.item_icon("lsword"), "fn": func(): pass}, {"label": "CHAIN MAIL", "icon": "", "fn": func(): pass}], func(): pass)
	var shown: Array = main.find_children("*", "Button", true, false).filter(func(b): return not b.is_queued_for_deletion() and (b.text.contains("LONG SWORD") or b.text.contains("CHAIN MAIL")))
	check(shown.size() == 2 and shown.all(func(b): return b.icon != null), "a list gives each item its picture, or an empty space to keep the names in line")


func _test_mercenaries() -> void:
	print("mercenaries")
	var g = get_node("/root/Game")
	var t: TownScreens = main.town
	var saved_party: Array[int] = g.party.duplicate()
	var saved_roster: Array = g.roster.duplicate()
	var saved_mode: String = g.mode
	g.mode = "castle"
	var st: Dictionary = Data.RACES["HUMAN"].duplicate()
	var leader: Character = g.make_char("LEADER", "HUMAN", "NEUTRAL", st, "FIGHTER")
	var second: Character = g.make_char("SECOND", "HUMAN", "NEUTRAL", st.duplicate(), "FIGHTER")
	leader.lvl = 4
	second.lvl = 7
	leader.gold = 1000
	second.gold = 500
	g.party.assign([leader.id, second.id])
	check(t.round_cost() == 1400, "a round costs 200 gold for each level of the party's best")
	t.tavern()
	var buy_opt: Dictionary = main.scr["opts"].filter(func(o): return o["k"] == "B")[0]
	check(buy_opt["label"] == "BUY ROUND (1400)" and not buy_opt["dis"], "the button says what it costs")
	var buy_buttons: Array = main._gear_row.find_children("*", "Button", true, false).filter(func(b): return b.text == "BUY ROUND (1400)")
	check(buy_buttons.size() == 1, "and sits under the cards")
	check(main._gear_row.get_combined_minimum_size().x <= main.GEAR_COLUMN - 2.0 * main.GEAR_PANEL_MARGIN, "with room for the whole row")
	var roster_before: int = g.roster.size()
	press("B")
	check(leader.gold + second.gold == 100, "the party pays between them")
	check(main.scr["title"] == "A mercenary offers to join" and main._sheet.visible and main._gear.visible, "a mercenary's sheet opens over the inn")
	check(_row_labels("left") == ["YES", "NO"], "with the choice under it")
	check(g.roster.size() == roster_before, "they aren't on the roster yet")
	press("N")
	check(not main._sheet.visible and g.party.size() == 2 and g.roster.size() == roster_before and leader.gold + second.gold == 100, "NO leaves the gold spent and no one added")
	check(not main.scr["opts"].filter(func(o): return o["k"] == "B")[0].has("x") and main.scr["opts"].filter(func(o): return o["k"] == "B")[0]["dis"], "and with no gold left there's no second round")
	check(not press("B"), "so it can't be pressed")
	leader.gold = 1400
	t.tavern()
	press("B")
	var hire_next: int = g.next_id
	press("Y")
	check(g.party.size() == 3 and g.roster.size() == roster_before + 1 and g.next_id == hire_next + 1, "YES adds them to the roster and the party")
	var hired: Character = g.roster.back()
	check(hired.lvl == 10 and g.party.has(hired.id), "three levels above the best")
	check(hired.mercenary and not leader.mercenary, "marked as a mercenary")
	check(t.round_cost() == 1400 and t.make_mercenary().lvl == 10, "who doesn't count: the next round costs the same and brings the same level")
	hired.lvl = 20
	check(t.round_cost() == 1400 and t.make_mercenary().lvl == 10, "even after levelling up")
	check(Character.from_dict(JSON.parse_string(JSON.stringify(hired.to_dict()))).mercenary, "and a save remembers it")
	check(not Character.from_dict(JSON.parse_string(JSON.stringify(leader.to_dict()))).mercenary, "and who isn't one")
	g.party.assign([hired.id])
	check(t.round_cost() == 200 and t.make_mercenary().lvl == 4, "a party of only mercenaries counts as level 1")
	hired.lvl = 10
	g.party.assign([leader.id, second.id, hired.id])
	g.party.assign([leader.id, second.id])
	g.roster.erase(hired)
	var races := {}
	var sexes := {}
	var titled := 0
	var merc_last := 0
	var merc_ok := {"level": true, "first": true, "last": true, "align": true, "hp": true, "xp": true, "portrait": true, "title": true}
	var trials := 600
	for i in trials:
		var m: Character = t.make_mercenary()
		races[m.race] = races.get(m.race, 0) + 1
		sexes[m.sex] = sexes.get(m.sex, 0) + 1
		var parts: PackedStringArray = m.name.split(" ")
		var titles: Array = Data.FEMALE_TITLES if m.sex == "FEMALE" else Data.MALE_TITLES
		var has_title: bool = titles.has(parts[0])
		if has_title:
			titled += 1
		var first: String = parts[1] if has_title else parts[0]
		merc_ok["first"] = merc_ok["first"] and (Data.FEMALE_NAMES if m.sex == "FEMALE" else Data.MALE_NAMES).has(first)
		var has_last: bool = parts.size() == (3 if has_title else 2)
		merc_ok["title"] = merc_ok["title"] and parts.size() <= (3 if has_title else 2)
		merc_last += 1 if has_last else 0
		merc_ok["last"] = merc_ok["last"] and (not has_last or Data.LAST_NAMES.has(parts[-1]))
		merc_ok["level"] = merc_ok["level"] and m.lvl == 10
		merc_ok["align"] = merc_ok["align"] and g.compatible(m) and Data.alignments_for(m.race).has(m.align)
		merc_ok["hp"] = merc_ok["hp"] and m.hp == m.maxhp and m.maxhp > 0 and m.is_alive()
		merc_ok["xp"] = merc_ok["xp"] and m.xp == Data.xp_needed(m.cls, 9)
		merc_ok["portrait"] = merc_ok["portrait"] and m.portrait.begins_with(m.sex.to_lower() + "_")
	check(g.roster.size() == roster_before, "making mercenaries adds no one")
	check(races.size() == Data.RACES.size() and races.values().all(func(n): return n > trials / Data.RACES.size() / 2), "every race is about equally likely (%s)" % str(races))
	check(sexes.size() == 2 and absi(sexes["MALE"] - sexes["FEMALE"]) < trials / 4, "and each sex (%s)" % str(sexes))
	check(merc_ok["level"], "always three levels above the best")
	check(merc_ok["first"] and merc_ok["last"], "with a first name for their sex, and any last name from the list")
	check(merc_last > trials * 0.4 and merc_last < trials * 0.6, "about half of them have a last name (%d of %d)" % [merc_last, trials])
	check(merc_ok["title"], "and a title for their sex, when they have one")
	check(titled > trials * 0.30 and titled < trials * 0.50, "40 percent of them at level 10 (%d of %d)" % [titled, trials])
	check(merc_ok["align"], "of an alignment the race allows and the party accepts")
	check(merc_ok["hp"] and merc_ok["xp"] and merc_ok["portrait"], "healthy, with the experience for their level and a portrait to match")
	var good_party: Character = g.make_char("GOODONE", "HUMAN", "GOOD", st.duplicate(), "FIGHTER")
	g.party.assign([good_party.id])
	var good_ok := true
	for i in 200:
		good_ok = good_ok and t.make_mercenary().align != "EVIL"
	check(good_ok, "a good party is never offered an evil mercenary")
	g.party.assign([leader.id])
	leader.gold = 99999
	g.party.resize(0)
	g.party.assign([leader.id, second.id, leader.id, second.id, leader.id, second.id])
	check(not t.can_buy_round(), "a full party can't buy a round for a mercenary")
	g.party.assign([])
	t.tavern()
	check(main.scr["opts"].filter(func(o): return o["k"] == "B")[0]["hide"], "and with no party there's no one to buy it")
	g.party.assign(saved_party)
	g.roster.assign(saved_roster)
	g.mode = saved_mode
	main.clear_log()
	t.castle()


func _test_lockpicking() -> void:
	print("lockpicking")
	var g = get_node("/root/Game")
	var st: Dictionary = Data.RACES["HUMAN"].duplicate()
	for k in Data.STATS:
		st[k] = 15
	var picker: Character = g.make_char("PICKER", "HUMAN", "NEUTRAL", st, "THIEF")
	picker.lvl = 5
	var clumsy: Character = g.make_char("CLUMSY", "HUMAN", "GOOD", st.duplicate(), "FIGHTER")
	clumsy.lvl = 5
	check(LockScreens.studies(picker) == 1, "a level 5 thief with 15 luck: (15 + 10) / 2 / 10 = 1.25, so one study")
	check(LockScreens.studies(clumsy) == 1, "anyone else counts as thief level 0: 0.75 rounds to one")
	var lucky: Character = g.make_char("LUCKY", "HUMAN", "NEUTRAL", st.duplicate(), "THIEF")
	lucky.lvl = 13
	lucky.stats["luk"] = 18
	check(LockScreens.studies(lucky) == 2, "level 13 with 18 luck: 2.2, so two")
	lucky.lvl = 40
	check(LockScreens.studies(lucky) == 5, "level 40 with 18 luck: 4.9, so five")
	lucky.lvl = 13
	clumsy.stats["luk"] = 5
	check(LockScreens.studies(clumsy) == 1, "5 luck and no thief levels: 0.25, but everyone gets at least one")
	clumsy.stats["luk"] = 15
	check(LockScreens.study_message(1, 5) == "One tumbler doesn't seem right." and LockScreens.study_message(2, 5) == "Two tumblers don't seem right.", "a study counts the wrong tumblers")
	check(LockScreens.study_message(3, 5) == "Three tumblers don't seem right." and LockScreens.study_message(4, 5) == "Four tumblers don't seem right.", "up to four")
	check(LockScreens.study_message(5, 5) == "All tumblers seem wrong." and LockScreens.study_message(2, 2) == "All tumblers seem wrong.", "or says all of them")
	check(LockScreens.study_message(0, 5) == "All tumblers seem right.", "and says when they are all right")
	check(LockScreens.wrong_pins([0, 1, 1], [0, 1, 1]) == 0 and LockScreens.wrong_pins([1, 1, 0], [0, 1, 1]) == 2, "it counts them truly")
	var opened := [0]
	var failed := [0]
	var backed := [0]
	main.lock.pick(picker, [0, 1, 1], "A small chest", "chest", func(): opened[0] += 1, func(): failed[0] += 1, func(): backed[0] += 1, {})
	var lock: LockPins = main.scr["widget"]
	var opt_of := func(label: String) -> Dictionary:
		return main.scr["opts"].filter(func(o): return o["label"] == label)[0]
	check(lock.pins.size() == 3 and lock.pins.all(func(p): return p == LockPins.NOT_SET), "a small chest has three pins, none set")
	check(opt_of.call("STUDY")["dis"] and opt_of.call("TRY")["dis"], "STUDY and TRY wait until they are all set")
	lock.set_pin(0, LockPins.UP)
	await get_tree().process_frame
	lock = main.scr["widget"]
	check(lock.pins[0] == LockPins.UP and opt_of.call("TRY")["dis"], "one pin set isn't enough")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(lock._pin_left(1) + 5.0, lock.custom_minimum_size.y - 5.0)
	lock._gui_input(click)
	await get_tree().process_frame
	lock = main.scr["widget"]
	check(lock.pins[1] == LockPins.DOWN, "clicking below the bar sets a pin down")
	click.position = Vector2(lock._pin_left(2) + 5.0, 5.0)
	lock._gui_input(click)
	await get_tree().process_frame
	lock = main.scr["widget"]
	check(lock.pins[2] == LockPins.UP and lock.all_set() and not opt_of.call("STUDY")["dis"] and not opt_of.call("TRY")["dis"], "clicking above sets it up, and now STUDY and TRY are ready")
	check(main.scr["body"].contains("Studies left: 1"), "the screen says how many studies are left")
	press("S")
	check(main.scr["body"].contains("One tumbler doesn't seem right."), "STUDY says how many are wrong")
	check(main.scr["body"].contains("Studies left: 0") and opt_of.call("STUDY")["dis"], "and uses one up")
	check(not press("S"), "with none left STUDY does nothing")
	press("T")
	check(failed[0] == 1 and opened[0] == 0, "a wrong setting fails")
	var kept_state := {"studied": 1}
	main.lock.pick(picker, [0, 1, 1], "A small chest", "chest", func(): opened[0] += 1, func(): failed[0] += 1, func(): backed[0] += 1, kept_state)
	check(main.scr["body"].contains("Studies left: 0"), "coming back to a lock doesn't give more studies")
	main.lock.pick(lucky, [0, 1, 1], "A small chest", "chest", func(): opened[0] += 1, func(): failed[0] += 1, func(): backed[0] += 1, kept_state)
	check(main.scr["body"].contains("Studies left: 1"), "and a better thief has only the rest of their own")
	main.lock.pick(picker, [0, 1, 1], "A small chest", "chest", func(): opened[0] += 1, func(): failed[0] += 1, func(): backed[0] += 1, {})
	main.scr["widget"].pins.assign([0, 1, 1])
	main.lock._show()
	press("T")
	check(opened[0] == 1 and failed[0] == 1, "the right setting opens it")
	press("L")
	check(backed[0] == 1, "BACK leaves it")
	check(g.door_locked(1, 3, 3, 1) == g.door_locked(1, 4, 3, 3) and g.door_solution(1, 3, 3, 1, 2) == g.door_solution(1, 4, 3, 3, 2), "a door's lock is the same from both sides")
	var door_counts := [0, 0]
	for dx in 20:
		for dy in 20:
			door_counts[1] += 1
			if g.door_locked(1, dx, dy, 1):
				door_counts[0] += 1
	check(door_counts[0] > door_counts[1] / 10 and door_counts[0] < door_counts[1] / 2, "about a quarter of doors are locked (%d of %d)" % door_counts)
	var door_at := []
	var door_lv: MazeLevel = g.levels[1]
	for dy in MazeLevel.N:
		for dx in MazeLevel.N:
			for dd in 4:
				if door_at.is_empty() and door_lv.wall(dx, dy, dd) == 2 and g.door_locked(1, dx, dy, dd):
					door_at = [dx, dy, dd]
	check(not door_at.is_empty(), "the first level has a locked door")
	var door_pos: Dictionary = g.pos.duplicate()
	var door_party: Array[int] = g.party.duplicate()
	var door_opened: Dictionary = g.opened.duplicate()
	var door_monsters: bool = g.monsters_on
	var door_mode: String = g.mode
	g.monsters_on = false
	g.mode = "maze"
	g.party.assign([picker.id])
	g.opened.erase(g._door_key(1, door_at[0], door_at[1], door_at[2]))
	g.opened.erase(g._door_key(1, door_at[0] + MazeLevel.DX[door_at[2]], door_at[1] + MazeLevel.DY[door_at[2]], (door_at[2] + 2) % 4))
	g.pos = {"x": door_at[0], "y": door_at[1], "z": 1, "d": door_at[2]}
	main.mz.forward()
	check(g.pos["x"] == door_at[0] and g.pos["y"] == door_at[1] and not g.door_open(1, door_at[0], door_at[1], door_at[2]), "walking into a locked door stops the party")
	check(main.scr["title"] == "Who picks the lock?", "and asks who picks it")
	main.mz._pick_door(picker)
	check(main.scr["title"] == "A locked door" and main.scr["widget"].pins.size() == 2, "a door's lock has two pins")
	var door_body_height: float = main._body.custom_minimum_size.y
	var door_key: Array = g.door_solution(1, door_at[0], door_at[1], door_at[2], 2)
	main.scr["widget"].pins.assign([1 - door_key[0], door_key[1]])
	main.lock._show()
	press("T")
	check(main.scr["title"] == "A locked door" and not g.door_open(1, door_at[0], door_at[1], door_at[2]), "a wrong try leaves it locked")
	main.scr["widget"].pins.assign(door_key)
	main.lock._show()
	press("S")
	check(main._body.custom_minimum_size.y == door_body_height and door_body_height > 0.0, "what the character says doesn't move the lock")
	press("T")
	check(g.door_open(1, door_at[0], door_at[1], door_at[2]) and main.scr["where"].ends_with("Level 1"), "the right setting opens it, back in the Maze")
	check(g.door_open(1, door_at[0] + MazeLevel.DX[door_at[2]], door_at[1] + MazeLevel.DY[door_at[2]], (door_at[2] + 2) % 4), "from both sides")
	g.pos = door_pos
	g.party.assign(door_party)
	g.opened = door_opened
	g.monsters_on = door_monsters
	g.mode = door_mode
	var f: CombatScreens = main.fight
	var miss_mode: String = g.mode
	var miss_party: Array[int] = g.party.duplicate()
	g.mode = "maze"
	g.party.assign([picker.id])
	f.chest = {"trap": 0, "gold": 0, "item": "", "solution": [0, 1, 1, 0]}
	f._pick_chest(picker)
	var miss_lock: LockPins = main.scr["widget"]
	miss_lock.pins.assign([1, 1, 1, 0])
	main.lock._show()
	press("T")
	miss_lock = main.scr["widget"]
	check(miss_lock.flashing and not f.chest.is_empty(), "a missed chest flashes before it opens")
	check(not press("T") and not press("S") and not press("L"), "and nothing can be pressed meanwhile")
	var miss_seen := []
	var miss_step: float = (LockScreens.FLASH_LIT + LockScreens.FLASH_DARK) / 2.0
	var miss_changes := 0
	var miss_was_lit := false
	for miss_tick in 40:
		if f.chest.is_empty():
			break
		miss_lock.flash_tween.custom_step(miss_step / 3.0)
		var miss_lit: bool = not miss_lock._flash_lit.is_empty()
		if miss_lit:
			miss_seen = miss_lock._flash_lit
		if miss_lit and not miss_was_lit:
			miss_changes += 1
		miss_was_lit = miss_lit
	check(miss_seen == [0, 1, 1, 0], "it shows the right pattern, not the guess")
	check(miss_changes == LockScreens.FLASH_TIMES, "five times (%d)" % miss_changes)
	check(f.chest.is_empty(), "and then the chest opens")
	f.chest = {"trap": 0, "gold": 0, "item": "", "solution": [0, 1, 1, 0]}
	f._pick_chest(picker)
	main.scr["widget"].pins.assign([0, 1, 1, 0])
	main.lock._show()
	press("T")
	check(f.chest.is_empty() and not (main.scr.get("widget") is LockPins), "the right setting doesn't flash")
	g.party.assign(miss_party)
	g.mode = miss_mode
	f.chest = {"trap": 3, "gold": 0, "item": "", "solution": [0, 1, 1, 0]}
	var chest_hp: int = picker.hp
	f._chest_picked(picker)
	check(f.chest.is_empty() and picker.hp == chest_hp, "picking a chest gets past its trap")
	g.roster.erase(picker)
	g.roster.erase(clumsy)
	g.roster.erase(lucky)
	main.clear_log()


func _row_group(group: String) -> Node:
	if main._sheet.visible:
		return main._popup_row.get_node(group)
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
	return grid.get_child((row + 2) * grid.columns + column).text  # under the row with RE-ROLL ALL, and the headings


func _test_attribute_rolls() -> void:
	var tray: DiceTray = main.dice_tray()
	var score_of := func(row: int) -> String:
		return _stat_cell(row, 3)
	var rolled_of := func(row: int) -> String:
		return _stat_cell(row, 1)
	check(tray.visible and tray.dice.size() == 3, "three dice wait beside the stats panel")
	check(tray.get_global_rect().position.x >= main._panel.get_global_rect().end.x, "to its right")
	check(_shown_labels() == ["ROLL", "BACK"], "the first choice is to roll")
	check(not main._opts_col.find_children("RowNote", "", true, false).any(func(n): return not n.is_queued_for_deletion()), "with no note beside it")
	check(score_of.call(0) == "-" and main.scr["body"].contains("RE-ROLL POINTS: [color=#e3a33f]6[/color]"), "nothing is rolled yet, and there are 6 re-roll points")
	var roll_button: Button = _row_button("center", 0)
	check(roll_button.text == "ROLL" and roll_button.get_theme_stylebox("normal").bg_color == UiStyle.C_STONE2, "ROLL is a blue button in the middle of the row")
	check(roll_button.custom_minimum_size == main.chars.ROLL_BUTTON_SIZE and roll_button.get_theme_font_size("font_size") > 22, "and a larger one")
	check(_row_labels("right") == ["BACK"] and _row_button("right", 0).get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "BACK is brown at the right")
	var head_row: Array = main.scr["widget"].get_children().slice(main.scr["widget"].columns + 1, main.scr["widget"].columns + 4).map(func(n): return n.text)
	check(head_row == ["Rolled", "Bonus", "Total"], "the columns are Rolled, Bonus and Total")
	check(_stat_cell(0, 2) == "+1", "each row shows the race's bonus")
	check(_stat_cell(0, 1) == "-" and _stat_cell(0, 3) == "-", "with nothing rolled yet")
	check(main.scr["widget"].get_children().slice(main.scr["widget"].columns + 1).all(func(n): return n.custom_minimum_size.x == main.chars.STAT_NUMBER_WIDTH or n is Button or n is Control and n.custom_minimum_size.x == main.chars.STAT_NAME_WIDTH), "the columns have fixed widths, so a value can't move them")
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
	check(_row_labels("left")[0] == "NEXT" and _row_labels("center").is_empty() and _row_labels("right") == ["BACK"], "with NEXT at the left and BACK still at the right")
	check(main.scr["widget"].get_node("RerollAll").text == "RE-ROLL ALL (2)" and main.scr["widget"].get_node("RerollAll").get_index() == 4, "RE-ROLL ALL is at the top, over the column of re-rolls")
	check(main.scr["widget"].get_node("RerollAll").get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "and it is small and brown")
	var next_button: Button = _row_button("left", 0)
	check(next_button.get_theme_stylebox("normal").bg_color == UiStyle.C_STONE2 and next_button.custom_minimum_size == main.chars.NEXT_BUTTON_SIZE, "NEXT is a blue button")
	check(next_button.custom_minimum_size.y == main.scr["row_height"] and _row_button("right", 0).size_flags_vertical == Control.SIZE_SHRINK_CENTER, "NEXT fills the row's height and BACK is centered in it, so their middles line up")
	var row_note: Control = _row_group("left").get_node("RowNote")
	check((row_note.text.contains("Choose a class next.") or row_note.text.contains("No class qualifies.")) and not main.scr["body"].contains("Choose a class") and not main.scr["body"].contains("No class qualifies"), "what to do next is beside NEXT, not above")
	check(row_note.get_index() == next_button.get_index() + 1, "right after NEXT")
	check(main.chars.NEXT_BUTTON_SIZE.x + main.ROW_NOTE_WIDTH + _row_button("right", 0).get_combined_minimum_size().x < main.BACKDROP_COLUMN - 16.0, "with room for all three on one line")
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
	var info_mode: String = g.mode
	g.mode = "maze"
	main.mz.maze()
	g.say("BILL HITS FOR 3 DAMAGE.")
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_equal_approx(main.view.get_global_rect().position.y, main._panel.get_global_rect().position.y), "the Maze's picture is level with the panel beside it")
	check(main._table.get_global_rect().position.x >= main.view.get_global_rect().end.x and is_equal_approx(main._table.get_global_rect().position.x, main._panel.get_global_rect().position.x), "and the party table is under that panel")
	check(main._info.visible and is_equal_approx(main._info.get_global_rect().position.x, main.view.get_global_rect().position.x) and is_equal_approx(main._info.get_global_rect().size.x, main.view.get_global_rect().size.x), "the info window lines up with the picture")
	check(main._info.get_global_rect().position.y >= main.view.get_global_rect().end.y and main._info.get_global_rect().position.y - main.view.get_global_rect().end.y <= main.INFO_GAP + 1.0, "right under it")
	main.clear_log()
	g.mode = "maze"
	main.mz.maze()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not main._table.visible and main.scr["widget"].get_child_count() == 6 and main.scr["party_grid"], "walking the Maze keeps the party's cards up, not the table")
	var empty_party: Array[int] = g.party.duplicate()
	g.party.assign([g.roster[0].id])
	var empty_labels := func(grid: GridContainer) -> Array:
		return grid.get_children().map(func(cell): return cell.get_child(0).get_child(0).text if cell.get_child(0).get_child(0) is Label else "")
	var empty_walk: GridContainer = main.fight.explore_grid()
	check(empty_labels.call(empty_walk).slice(1) == ["* EMPTY *", "* EMPTY *", "* EMPTY *", "* EMPTY *", "* EMPTY *"], "open slots in the Maze say * EMPTY *")
	check(empty_walk.get_child(1).get_child(0).get_child(0).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and empty_walk.get_child(1).get_child(0).get_child(0).vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "centered in the square")
	main.fight.battle = Battle.new()
	var empty_fight: GridContainer = main.fight._party_grid()
	main.fight.battle = null
	check(empty_labels.call(empty_fight)[5] == "* EMPTY *", "in combat too")
	var empty_shop: GridContainer = main.town.gear_grid()
	check(empty_labels.call(empty_shop)[5] == "", "but not in the shops")
	empty_walk.free()
	empty_fight.free()
	empty_shop.free()
	g.party.assign(empty_party)
	var maze_buttons: Array = main._opts_col.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(maze_buttons == ["CAMP"] and not main.scr["opts"].any(func(o): return o["label"] == "QUIT" or o["label"] == "STATUS"), "CAMP is the only button left, with no QUIT or STATUS")
	var camp_button: Button = main._opts_col.find_children("*", "Button", true, false)[0]
	check(camp_button.get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "CAMP is small and brown")
	var camp_rect: Rect2 = camp_button.get_global_rect()
	var party_rect: Rect2 = main._panel.get_global_rect()
	check(party_rect.end.y - camp_rect.end.y < 30.0 and party_rect.end.x - camp_rect.end.x < 30.0, "at the lower right of the party window")
	check(main._tools.visible and main._tools.get_child_count() == 2 and main._tools.get_child(0).icon != null and main._tools.get_child(1).icon != null, "Inspect and Notes are icons on the picture")
	check(main._tools.get_child(0).tooltip_text == "INSPECT AREA" and main._tools.get_child(1).tooltip_text == "MAP NOTES", "and say what they are under the mouse")
	check(main._tools.get_global_rect().position.x - main.view.get_global_rect().position.x < 20.0 and main.view.get_global_rect().end.y - main._tools.get_global_rect().end.y < 20.0, "at the lower left of the picture")
	var map_before: bool = g.show_map
	main._tools.get_child(1).pressed.emit()
	check(g.show_map != map_before and main._tools.get_child(1).tooltip_text == "MAP OFF", "the Notes icon switches the map")
	g.show_map = map_before
	main.mz.maze()
	main._tools.get_child(0).pressed.emit()
	check(main._info_text.text.contains("YOU SEARCH THE AREA"), "the Inspect icon inspects the area")
	main.clear_log()
	main.yesno("Ladder going up", "Climb it?", main.mz.maze, main.mz.maze)
	check(not main._table.visible and main.scr["party_grid"], "a question in the Maze keeps the party's cards up")
	var ladder_from: Dictionary = g.pos.duplicate()
	var icon_lv: MazeLevel = g.level()
	var icon_at := Vector2i(-1, -1)
	var icon_way := ""
	for iy in icon_lv.cells.size():
		for ix in icon_lv.cells[iy].size():
			for way in ["up", "down"]:
				if icon_at.x < 0 and icon_lv.flag(ix, iy, way):
					icon_at = Vector2i(ix, iy)
					icon_way = way
	g.pos = {"x": icon_at.x, "y": icon_at.y, "z": ladder_from["z"], "d": 0}
	main.mz.maze()
	check(main._tools.get_child_count() == 3 and main._tools.get_child(2).tooltip_text == "CLIMB " + icon_way.to_upper(), "on a ladder, a ladder icon stands next to Notes")
	main._tools.get_child(2).pressed.emit()
	check(main.scr["title"] == "Ladder going " + icon_way, "and asks whether to climb")
	main.scr["opts"].filter(func(o): return o["label"] == "NO")[0]["fn"].call()
	check(g.pos["z"] == ladder_from["z"] and main._tools.get_child_count() == 3, "No leaves the party on the ladder, icon and all")
	g.pos = ladder_from
	main.mz.maze()
	check(main._tools.get_children().filter(func(n): return not n.is_queued_for_deletion()).size() == 2, "off the ladder the icon is gone")
	main.chars.training()
	check(main._tools.get_child_count() == 0 or main._tools.get_children().all(func(n): return n.is_queued_for_deletion()), "other screens have no icons")
	main.mz.maze()
	var closing_light: int = g.light
	g.light = 77
	main._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	check(FileAccess.get_file_as_string(g.save_path).contains("\"light\":77"), "closing the window saves the game")
	g.light = closing_light
	g.mode = info_mode
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
		map_world.finish_glide()
		check(is_equal_approx(wrapf(map_world._ladder_floor.rotation.y, -PI, PI), wrapf(MazeWorld.camera_yaw(ladder_d), -PI, PI)), "the ladder floor turns with the party, facing %d" % ladder_d)
	g.pos["d"] = 0
	print("gliding")
	var glide_pos: Dictionary = g.pos.duplicate()
	var glide_active: bool = map_world.is_processing()
	var cam: Camera3D = map_world._camera
	map_world.set_process(true)
	g.pos = {"x": 5, "y": 5, "z": 1, "d": 0}
	map_world.sync_to_party()
	map_world.finish_glide()
	var glide_start := MazeWorld.camera_place(Vector2i(5, 5), 0)
	var glide_end := MazeWorld.camera_place(Vector2i(5 + MazeLevel.DX[0], 5 + MazeLevel.DY[0]), 0)
	check(cam.position.is_equal_approx(glide_start), "the camera starts on its square")
	g.pos["x"] += MazeLevel.DX[0]
	g.pos["y"] += MazeLevel.DY[0]
	map_world.sync_to_party()
	check(cam.position.is_equal_approx(glide_start), "a step doesn't jump")
	map_world._process(MazeWorld.GLIDE_SECONDS * 0.5)
	var glide_mid: Vector3 = cam.position
	check(glide_mid.distance_to(glide_start) > 0.1 and glide_mid.distance_to(glide_end) > 0.1, "halfway through it is between the squares")
	map_world.sync_to_party()
	check(cam.position.is_equal_approx(glide_mid), "being drawn again doesn't disturb the glide")
	map_world._process(MazeWorld.GLIDE_SECONDS * 0.5 + 0.01)
	check(cam.position.is_equal_approx(glide_end), "and it arrives")
	g.pos["d"] = 1
	map_world.sync_to_party()
	map_world._process(MazeWorld.GLIDE_SECONDS * 0.5)
	var turn_mid: float = cam.rotation.y
	check(turn_mid < -0.1 and turn_mid > -PI / 2.0 + 0.1, "a turn sweeps round")
	check(is_equal_approx(map_world._ladder_floor.rotation.y, turn_mid), "with the ladder tile keeping up")
	map_world.finish_glide()
	g.pos["d"] = 0
	map_world.sync_to_party()
	map_world.finish_glide()
	g.pos["d"] = 3
	map_world.sync_to_party()
	map_world._process(MazeWorld.GLIDE_SECONDS * 0.5)
	check(absf(angle_difference(cam.rotation.y, 0.0)) < PI / 2.0, "from north to west it takes the short way round")
	map_world.finish_glide()
	g.pos["d"] = 1
	map_world.sync_to_party()
	check(is_equal_approx(map_world._glide_length, MazeWorld.TURN_AROUND_SECONDS), "turning around takes a little longer")
	map_world.finish_glide()
	g.pos["x"] = 1
	g.pos["y"] = 1
	map_world.sync_to_party()
	check(cam.position.is_equal_approx(MazeWorld.camera_place(Vector2i(1, 1), 1)) and map_world._glide_length == 0.0, "a teleport jumps")
	g.pos["z"] = 2
	map_world.sync_to_party()
	check(map_world._glide_length == 0.0, "and so does a new level")
	g.pos = glide_pos
	map_world.sync_to_party()
	map_world.finish_glide()
	map_world.set_process(glide_active)
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
	check(map_world._braziers[0]["stand"].find_children("*", "Sprite3D", true, false).is_empty() and map_world._braziers[0]["stand"].get_child(0).get_child_count() == 1, "each is the pack's 3D cauldron")
	check(is_equal_approx(MazeWorld.TORCH_MODEL_HEIGHT, 0.3), "and the wall torches are 40% smaller")
	if ResourceLoader.exists(MazeWorld.BRAZIER_FIRE_SCENE):
		var full_fire: Node3D = map_world._brazier_flames()
		check(full_fire.get_child_count() == MazeWorld.BRAZIER_FLAMES, "a cauldron is full of flames")
		check(full_fire.find_children("*", "AudioStreamPlayer3D", true, false).is_empty(), "silent ones")
		full_fire.free()
	var cauldron_pieces: Array = map_world._braziers[0]["stand"].get_child(0).find_children("*", "MeshInstance3D", true, false)
	if map_world._braziers[0]["stand"].get_child(0).get_child(0) is MeshInstance3D:
		cauldron_pieces.append(map_world._braziers[0]["stand"].get_child(0).get_child(0))
	check(cauldron_pieces.all(func(m): return m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON), "a cauldron casts a shadow")
	check(map_world._chests.size() == MazeWorld.chest_spots(g.levels[1]).size(), "the level has its chests in place")
	check(map_world._chests[0].find_children("*", "MeshInstance3D", true, false).size() + (1 if map_world._chests[0].get_child(0) is MeshInstance3D else 0) >= 1, "a chest is the pack's 3D model")
	main.view.show_view("chest")
	var found_shown: bool = map_world.has_found_chest() == main.view.is_visible_in_tree()
	check(found_shown, "the chest screen stands one in front of the party, whenever it shows the Maze")
	main.view.show_view("maze")
	check(not map_world.has_found_chest(), "and it goes when they leave")
	var burning_ok := true
	for burning in map_world._braziers:
		var burning_near: bool = maxi(absi(burning["c"].x), absi(burning["c"].y)) <= MazeWorld.BRAZIER_NEAR
		if burning["light"].visible != burning_near or burning["fire_on"] != burning_near:
			burning_ok = false
		if burning["fire"] != null and burning["fire"].find_children("*", "AudioStreamPlayer3D", true, false).size() > 0:
			burning_ok = false
	check(burning_ok, "only braziers near the party burn, and they stay silent")
	await _test_lockpicking()
	_test_mercenaries()
	_test_item_icons()
	_test_small_buttons()
	_test_class_gear()
	print("wall torches")
	var torch_lv: MazeLevel = g.levels[1]
	var torch_all: Array = MazeWorld.torch_spots(torch_lv)
	check(torch_all.size() >= 5, "the first level has torches (%d)" % torch_all.size())
	check(MazeWorld.torch_spots(g.levels[2]).is_empty(), "the other levels don't")
	check(str(torch_all) == str(MazeWorld.torch_spots(torch_lv)), "and they are always in the same places")
	var torch_ok := true
	var torch_taken := {}
	for torch_other in MazeWorld.brazier_spots(torch_lv) + MazeWorld.chest_spots(torch_lv):
		torch_taken[torch_other["c"]] = true
	for torch_a in torch_all:
		var torch_c: Vector2i = torch_a["c"]
		if torch_lv.wall(torch_c.x, torch_c.y, torch_a["side"]) != 1 or torch_taken.has(torch_c) or torch_lv.flag(torch_c.x, torch_c.y, "dark") or torch_lv.flag(torch_c.x, torch_c.y, "up") or torch_lv.flag(torch_c.x, torch_c.y, "down"):
			torch_ok = false
		for torch_b in torch_all:
			if torch_a != torch_b and absi(torch_c.x - torch_b["c"].x) + absi(torch_c.y - torch_b["c"].y) < MazeWorld.TORCH_SPACING:
				torch_ok = false
	check(torch_ok, "each is on a plain wall, in a square of its own, well apart from the others")
	var torch_quadrants := {}
	for torch_a in torch_all:
		torch_quadrants[Vector2i(torch_a["c"].x * 2 / MazeLevel.N, torch_a["c"].y * 2 / MazeLevel.N)] = true
	check(torch_quadrants.size() == 4, "they are spread around the whole level")
	check(map_world._torches.size() == torch_all.size(), "the level has its torches hanging")
	var clip_pos: Dictionary = g.pos.duplicate()
	var clip_torch: Dictionary = map_world._torches[0]
	var clip_side: int = torch_all[0]["side"]
	g.pos = {"x": clip_torch["c"].x, "y": clip_torch["c"].y, "z": 1, "d": (clip_side + 2) % 4}
	map_world.sync_to_party()
	map_world.finish_glide()
	check(not clip_torch["stand"].get_child(0).visible, "with their back to a torch's wall, the camera doesn't sit inside the torch")
	check(clip_torch["light"].visible == clip_torch["fire_on"], "though it still lights the room")
	g.pos["d"] = clip_side
	map_world.sync_to_party()
	map_world.finish_glide()
	check(clip_torch["stand"].get_child(0).visible, "facing it, the torch shows")
	g.pos["d"] = (clip_side + 1) % 4
	map_world.sync_to_party()
	map_world.finish_glide()
	check(clip_torch["stand"].get_child(0).visible, "and from the side")
	var clip_chest_spot: Dictionary = MazeWorld.chest_spots(torch_lv)[0]
	var clip_chest: Node3D = map_world._chests[0]
	g.pos = {"x": clip_chest_spot["c"].x, "y": clip_chest_spot["c"].y, "z": 1, "d": (clip_chest_spot["side"] + 2) % 4}
	map_world.sync_to_party()
	map_world.finish_glide()
	check(not clip_chest.visible, "and the same goes for a chest")
	g.pos["d"] = clip_chest_spot["side"]
	map_world.sync_to_party()
	map_world.finish_glide()
	check(clip_chest.visible, "which shows when facing it")
	g.pos = clip_pos
	map_world.sync_to_party()
	map_world.finish_glide()
	check(map_world._torches[0]["stand"].find_children("*", "Sprite3D", true, false).is_empty() and map_world._torches[0]["stand"].get_child(0).get_child_count() == 1, "each is the pack's 3D model")
	var torch_burn_ok := true
	for torch_t in map_world._torches:
		var torch_near: bool = maxi(absi(torch_t["c"].x), absi(torch_t["c"].y)) <= MazeWorld.TORCH_NEAR
		if torch_t["light"].visible != torch_near or torch_t["fire_on"] != torch_near:
			torch_burn_ok = false
		if torch_t["fire"] != null and torch_t["fire"].find_children("*", "AudioStreamPlayer3D", true, false).size() > 0:
			torch_burn_ok = false
		if torch_t["light"].shadow_enabled != true:
			torch_burn_ok = false
	check(torch_burn_ok, "only torches near the party burn, silently, and walls block their light")
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
	g.mode = "castle"  # away from the Maze, where the window has a place of its own
	main.clear_log()
	check(not main._info.visible and main._info.get_parent() == main, "the info window is separate, and hidden until there is news")
	g.say("FIRST NEWS.")
	check(main._info.visible and main._info_text.text.contains("FIRST NEWS."), "news shows the info window")
	check(is_equal_approx(main._info_timer.wait_time, 3.0) and not main._info_timer.is_stopped(), "and starts its 3 seconds")
	main._info_timer.stop()
	g.say("SECOND NEWS.")
	check(main._info_text.text.contains("FIRST NEWS.") and main._info_text.text.contains("SECOND NEWS."), "more news joins it")
	check(main._info_timer.time_left > 2.5, "and restarts the 3 seconds")
	for news_i in 20:
		g.say("NEWS %d." % news_i)
	check(main._info_lines.size() == main.INFO_MAX_LINES and main._info_text.text.contains("NEWS 19."), "a burst of news keeps its latest lines")
	check(main._info.mouse_filter == Control.MOUSE_FILTER_IGNORE and main._info_text.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the info window lets clicks through")
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_equal_approx(main._info.get_rect().end.y, main.size.y - main.INFO_MARGIN), "the info window sits at the bottom of the screen")
	main._info_timer.timeout.emit()
	check(not main._info.visible and main._info_lines.is_empty(), "when the time is up it hides and forgets")
	g.say("LATER NEWS.")
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_equal_approx(main._info.get_rect().end.y, main.size.y - main.INFO_MARGIN), "and comes back in the same place")
	main.clear_log()
	var saved: Array[int] = g.party.duplicate()
	g.mode = "castle"
	g.party.clear()
	main.town.castle()
	await get_tree().process_frame
	check(main.town_map.visible, "the castle shows the map")
	check(not main.town_map._party_toggle.visible and main.town_map._party.visible, "with no party there is no list to close")
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
	var party_toggle: Button = main.town_map._party_toggle
	check(party_toggle.visible and party_toggle.text == "CLOSE PARTY LIST" and party_toggle.icon == load(main.town_map.PARTY_CLOSE_ARROW) and party_toggle.get_index() > map_party.get_index(), "the list ends with a button to close it")
	party_toggle.pressed.emit()
	check(not map_party.visible and party_toggle.visible and party_toggle.text == "OPEN PARTY LIST" and party_toggle.icon == load(main.town_map.PARTY_OPEN_ARROW), "closing leaves only the button to open it, with its arrow pointing down")
	main.town.tavern()
	main.town.castle()
	check(not map_party.visible and party_toggle.text == "OPEN PARTY LIST", "the list stays closed after visiting a building")
	party_toggle.pressed.emit()
	check(map_party.visible and party_toggle.text == "CLOSE PARTY LIST" and party_toggle.icon == load(main.town_map.PARTY_CLOSE_ARROW), "opening it brings the list back, and the arrow points up again")
	g.party.assign(saved_party)
	g.roster.erase(map_first)
	main.town.castle()
	var rect: Rect2 = main.town_map._map_rect()
	await get_tree().process_frame
	await get_tree().process_frame
	check(main.town_map._party_panel.position == rect.position + Vector2.ONE * 3.0, "the party list is 3 pixels from the top and left")
	check(is_equal_approx(main.town_map._info_panel.position.x, rect.position.x + 3.0) and is_equal_approx(main.town_map._info_panel.get_rect().end.y, rect.end.y - 3.0), "the description is 3 pixels from the bottom and left")
	var map_labels := {}
	for map_opt in main.scr["opts"]:
		map_labels[map_opt["k"]] = map_opt["label"]
	check(map_labels["G"] == "THE RED DRAGON INN" and map_labels["A"] == "THE DRUNKEN SLUMBER" and map_labels["T"] == "CATHEDRAL OF REBIRTH" and map_labels["B"] == "THE BROKEN ANVIL" and map_labels["R"] == "PROVING GROUNDS", "the buildings have their new names")
	check(main._body.get_theme_stylebox("focus") is StyleBoxEmpty, "clicking a description doesn't outline it")
	for about in [["G", "rowdy tavern"], ["A", "quiet refuge"], ["T", "sacred sanctuary"], ["B", "bustling forge"], ["R", "great adventure"], ["E", "well-worn path"]]:
		main.town_map._set_hover(about[0])
		check(main.town_map._info.text.contains(map_labels[about[0]]) and main.town_map._info.text.contains(about[1]), "%s describes itself under the mouse" % map_labels[about[0]])
	main.town_map._set_hover("")
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
		check(fire_window.foot().distance_to(main.town_map.view_point(TownMap.FIRE_BASE)) < 1.0, "the fire stands on the campfire")
	for o in main.scr["opts"]:
		check(TownMap.SPOTS.has(o["k"]), "%s has a building on the map" % o["label"])
	_click_spot("B")
	check(main.scr["title"] == "Castle", "a greyed-out building stays shut")
	_click_spot("G")
	check(main.scr["title"] == "The Red Dragon Inn" and not main.town_map.visible, "clicking the tavern enters it and hides the map")
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
	check(main.scr["title"] == "Proving Grounds", "clicking the yard opens the Proving Grounds")
	var training_art: Texture2D = main._backdrop.texture
	check(main._backdrop.visible and training_art != null, "the Proving Grounds show their painting")
	check(absf(float(training_art.get_width()) / training_art.get_height() - 16.0 / 9.0) < 0.001, "the Proving Grounds painting is 16:9")
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
	main.chars.create_align("TUSK", "HALF-ORC")
	check(_row_labels("left") == ["NEUTRAL", "EVIL"] and _row_labels("right") == ["BACK"], "half-orcs can only be neutral or evil")
	check(not press("G"), "so there is no good to choose")
	press("E")
	check(main.scr["title"] == "TUSK: E-HALF-ORC", "evil is on offer")
	main.chars.create_align("TUSK", "HALF-ORC")
	press("N")
	check(main.scr["title"] == "TUSK: N-HALF-ORC", "and so is neutral")
	for other_race in ["HUMAN", "ELF", "DWARF", "GNOME", "HOBBIT"]:
		check(Data.alignments_for(other_race) == ["GOOD", "NEUTRAL", "EVIL"], "%s can be any" % other_race)
	var peace_orc: Character = g.make_char("PEACEORC", "HALF-ORC", "EVIL", Data.RACES["HALF-ORC"].duplicate(), "FIGHTER")
	var peace_human: Character = g.make_char("PEACEHUMAN", "HUMAN", "EVIL", Data.RACES["HUMAN"].duplicate(), "FIGHTER")
	var peace_party: Array[int] = g.party.duplicate()
	var peace_fight: Variant = main.fight.battle
	var peace_turned := [false, false]
	main.fight.battle = Battle.new()
	g.party.assign([peace_orc.id, peace_human.id])
	for peace_try in 200:
		peace_orc.align = "EVIL"
		peace_human.align = "EVIL"
		main.fight._leave_in_peace()
		peace_turned[0] = peace_turned[0] or peace_orc.align == "GOOD"
		peace_turned[1] = peace_turned[1] or peace_human.align == "GOOD"
		main.fight.battle = Battle.new()
	check(not peace_turned[0], "and a half-orc is never won over to good by leaving friends in peace")
	check(peace_turned[1], "though others can be")
	main.fight.battle = peace_fight
	g.party.assign(peace_party)
	g.roster.erase(peace_orc)
	g.roster.erase(peace_human)
	main.clear_log()
	main.chars.create_align("RACER", "DWARF")
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
	var keep_count: int = g.roster.size()
	var keep_id: int = g.next_id
	check(main.scr["title"] == "Keep this character?" and main._sheet.visible and main._sheet.find_child("PopupTitle", true, false).text == "Keep this character?", "the confirmation is a window titled with the question")
	check(main._sheet.find_child("Stats", true, false).text.contains("PICKED") and main._sheet.find_child("Portrait", true, false).texture == load("res://assets/images/portraits/%s.webp" % kept_portrait), "showing the character's sheet, with the chosen portrait")
	check(_row_labels("left") == ["YES", "NO"], "and the choice under it")
	check(g.roster.size() == keep_count and g.next_id == keep_id, "they aren't on the roster yet")
	var keep_hits: String = main._sheet.find_child("Stats", true, false).text
	press("N")
	check(not main._sheet.visible and g.roster.size() == keep_count and g.next_id == keep_id and main.scr.has("dice"), "NO goes back to the scores, with no one added")
	main.chars._confirm_char(picked, "FIGHTER")
	check(main._sheet.find_child("Stats", true, false).text == keep_hits, "coming back shows the same character, not a free re-roll")
	press("Y")
	check(g.roster.size() == keep_count + 1 and g.next_id == keep_id + 1, "YES adds them")
	var made: Character = g.roster.back()
	check(made.name == "PICKED" and made.sex == "FEMALE" and made.portrait == kept_portrait, "the new character keeps the sex and portrait chosen")
	check(not main._portrait.visible, "the Proving Grounds hide the portrait again")
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
	check(main._sheet.visible and main._sheet.find_child("Portrait", true, false).texture == load(made.portrait_path()), "inspecting a character shows their portrait")
	main.chars.train_char(old_char)
	check(main._sheet.find_child("Portrait", true, false).texture == null, "a character with no portrait shows none")
	main.chars.train_char(made)
	check(_row_labels("right") == ["CLOSE"] and _row_button("right", 0).get_theme_stylebox("normal").bg_color == main.PAGER_FILL and _row_button("right", 0).get_theme_font_size("font_size") < 22, "CLOSE is small and brown, at the right")
	check(_row_labels("left").has("CHANGE PORTRAIT"), "with the other buttons on the left")
	main.chars._choose_class(picked, ["FIGHTER"])
	check(main._pager_row.get_child(-1).text == "BACK" and main._pager_row.get_child(-1).get_theme_stylebox("normal").bg_color == main.PAGER_FILL, "a list's BACK is too")
	main.chars.train_char(made)
	press("N")
	check(main.scr["title"] == "Rename PICKED" and _row_labels("left") == ["SELECT"] and _row_labels("right") == ["BACK"], "Change Name asks for the new name")
	main._on_input_submitted(g.roster[0].name)
	check(made.name == "PICKED" and main.scr["title"] == "Rename PICKED", "a taken name is refused")
	main._on_input_submitted("RENAMED")
	check(made.name == "RENAMED" and main.scr["title"] == "Character Sheet", "a free name is taken, back on the character's sheet")
	made.name = "PICKED"
	main.chars.train_char(made)
	press("P")
	check(main.scr["title"] == "PICKED: choose a portrait" and main.scr["widget"].get_child_count() == 12, "Change Portrait opens the picker")
	press("L")
	check(main.scr["title"] == "Character Sheet" and made.portrait == kept_portrait, "leaving the picker keeps the old portrait")
	press("P")
	press("N")
	var changed_portrait := String(main.scr["widget"].get_child(0).name)
	main.scr["widget"].get_child(0).pressed.emit()
	check(main.scr["title"] == "Character Sheet" and made.portrait == changed_portrait, "Change Portrait replaces the portrait")
	check(main._sheet.find_child("Portrait", true, false).texture == load(made.portrait_path()), "the character's sheet shows the new portrait")
	g.roster.erase(made)
	main.chars.training()
	check(main._backdrop.texture == training_art and main._gear.visible and not main._table.visible, "the roster shows as a grid over the painting")
	check(g.MAX_ROSTER == 20 and main._gear_grid.columns == 5 and main._gear_grid.get_child_count() == 20, "five across and four down")
	var empty_card: Control = main._gear_grid.get_child(19)
	check(g.roster.size() < 20 and empty_card.get_child(0).get_child(0).text == "* EMPTY *" and empty_card.get_child(0).get_child(0).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and empty_card.get_child(0).get_child(0).vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "an empty slot says so, in its middle")
	check(empty_card.get_child_count() == 1, "and can't be selected")
	await get_tree().process_frame
	await get_tree().process_frame
	var roster_note: Label = main._gear_grid.get_parent().get_child(main._gear_grid.get_parent().get_child_count() - 1)
	check(roster_note.text.begins_with("ROSTER: ") and not main._body.text.contains("ROSTER: "), "the roster count is at the bottom of the right panel")
	check(roster_note.get_global_rect().position.y >= main._gear_grid.get_global_rect().end.y and roster_note.get_theme_font_size("font_size") == main._gear_grid.get_parent().get_child(0).get_theme_font_size("font_size"), "under the cards, in the small text of the line above them")
	check(main._gear.get_global_rect().end.y <= main.size.y, "and the panel still fits the window")
	check(_row_labels("left") == ["CREATE A CHARACTER"] and _row_labels("right") == ["EXIT"], "CREATE and EXIT share a row")
	check(is_equal_approx(_row_button("left", 0).get_global_rect().get_center().y, _row_button("right", 0).get_global_rect().get_center().y), "level with each other")
	check(_row_button("right", 0).get_theme_stylebox("normal").bg_color == main.PAGER_EXIT_FILL and main._exit_row.get_child_count() == 0, "with EXIT still red")
	main.town.tavern()
	await get_tree().process_frame
	await get_tree().process_frame
	check(main._panel.get_global_rect().size.y <= main._panel.get_combined_minimum_size().y + 1.0, "a building's text panel is only as tall as its contents")
	var panel_short: float = main._panel.size.y
	main.show_screen({"title": "The Red Dragon Inn", "body": "\n".join(range(12).map(func(i): return "A LINE OF TEXT")), "opts": []})
	await get_tree().process_frame
	await get_tree().process_frame
	check(main._panel.size.y > panel_short, "and grows with more text")
	main.town.tavern()
	check(main._exit_row.get_child_count() == 1 and main._gear_grid.get_parent().get_child(main._gear_grid.get_parent().get_child_count() - 1) == main._gear_row, "other screens have no note, and keep their EXIT")
	main.chars.training()
	check(not main.scr["opts"].any(func(o): return o["label"] == "ROSTER OF CHARACTERS" or o["label"] == "INSPECT A CHARACTER"), "the old roster and inspect buttons are gone")
	check(main._gear_grid.get_parent().get_child(0).text == "Click a character to select them.", "it says to click someone")
	var roster_cards_before: Vector2 = main._gear_grid.get_child(0).get_combined_minimum_size()
	var inspect_buttons := func() -> Array:
		return main._gear_grid.find_children("*", "Button", true, false).filter(func(b): return b.text == "INSPECT")
	check(inspect_buttons.call().is_empty(), "nobody is selected yet, so nothing can be inspected")
	main._gear_grid.get_child(0).get_child(1).pressed.emit()
	var roster_chosen: Character = g.roster[0]
	check(main.chars._recruit == roster_chosen and inspect_buttons.call().size() == 1, "clicking a card selects them, with INSPECT under them")
	check(inspect_buttons.call()[0].get_parent().get_parent() == main._gear_grid.get_child(0), "on their own card")
	check(main._gear_grid.get_child(0).get_theme_stylebox("panel").border_color == PartyCards.SELECTED_EDGE, "which lights up")
	check(main._gear_grid.get_child(0).get_combined_minimum_size().y == roster_cards_before.y, "and no card changes size")
	inspect_buttons.call()[0].pressed.emit()
	check(main.scr["title"] == "Character Sheet" and main.scr.has("sheet"), "INSPECT brings up their sheet")
	check(main.scr["opts"].any(func(o): return o["label"] == "DELETE") and main.scr["opts"].any(func(o): return o["label"] == "CHANGE PORTRAIT"), "with what the Proving Grounds can do to them")
	press("L")
	check(main.scr["title"] == "Proving Grounds" and main.chars._recruit == roster_chosen, "BACK returns with them still selected")
	press("L")
	check(main.scr["title"] == "Castle" and main.chars._recruit == null, "leaving forgets who was selected")
	main.chars.training()
	press("Enter")
	press("L")
	check(main.scr["title"] == "Castle", "leaving the Proving Grounds returns to the map")
	check(not main._backdrop.visible, "leaving the Proving Grounds clears their painting")
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
			elif l is HBoxContainer and l.has_meta("gear"):
				out.append(TownScreens.gear_text(l))
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
	var gear_icon: TextureRect = main._gear_grid.get_child(0).get_child(0).find_children("*", "TextureRect", true, false).filter(func(n): return n.get_parent().has_meta("gear"))[0]
	check(gear_icon.texture.resource_path == Data.item_icon("lsword"), "with the plain long sword's picture left of its name")
	check(main.town._gear_font("Weapon: STAFF OF MOGREF (BROKEN)") < main.town.GEAR_FONT, "a long name shrinks to fit")
	check(not Data.class_uses_slot("M", "H") and not Data.class_uses_slot("M", "S") and Data.class_uses_slot("M", "A") and not Data.class_uses_slot("B", "S"), "mages can't use helms or shields, nor bishops shields")
	var gear_cls: String = gear_hero.cls
	gear_hero.cls = "MAGE"
	main.rerender()
	var mage_lines: Array = gear_lines.call()
	check(mage_lines.slice(3, 7) == ["Weapon: SWORD?", "Amulet: NONE", "Armor: NONE", "Ring: NONE"], "a mage's card has an amulet and a ring instead of a helm and shield")
	var mage_card: Control = main._gear_grid.get_child(0)
	gear_hero.cls = gear_cls
	main.rerender()
	check(main._gear_grid.get_child(0).get_combined_minimum_size().y == mage_card.get_combined_minimum_size().y, "keeping the card the same height")
	gear_hero.items = gear_keep
	main.town.shop(gear_hero)
	check(main.scr["title"] == "The Broken Anvil" and main._backdrop.texture == boltac_art, "the shop keeps the painting")
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
	check(main.scr["title"] == "The Drunken Slumber" and main._gear.visible and not main._table.visible, "the inn shows the party as a grid, like the tavern")
	var room_labels := ["STABLES", "COMMON ROOM", "SHARED ROOM", "PRIVATE ROOM", "KING'S SUITE"]
	var shown_rooms := func() -> Array:
		return main._gear_row.find_children("*", "Button", true, false).map(func(b): return b.text)
	check(main._gear_grid.get_parent().get_child(0).text == "Click a party member to select them." and shown_rooms.call().is_empty(), "nobody is selected yet, so there are no rooms to choose")
	check(main.scr["body"].contains("KING'S SUITE") and main.scr["body"].contains("FREE, NO HEALING"), "the left panel lists what the rooms cost")
	var guest: Character = g.party_chars()[0]
	var guest_gold: int = guest.gold
	var guest_status: String = guest.status
	guest.status = "PARALYZED"
	main.town.select_guest(guest)
	check(main.town._selected == null and shown_rooms.call().is_empty(), "the paralyzed cannot check in")
	guest.status = "DEAD"
	main.town.select_guest(guest)
	check(main.town._selected == null and shown_rooms.call().is_empty(), "nor can the dead")
	guest.status = "OK"  # whatever the fights earlier in this test left this member as
	guest.gold = 50
	main.town.select_guest(guest)
	check(main.town._selected == guest and shown_rooms.call() == room_labels, "selecting a member shows the rooms under the cards")
	check(main._gear_row.get_combined_minimum_size().x <= main.GEAR_COLUMN - 2.0 * main.GEAR_PANEL_MARGIN, "and the rooms fit under the cards without widening them")
	var room_button := func(label: String) -> Button:
		return main._gear_row.find_children("*", "Button", true, false).filter(func(b): return b.text == label)[0]
	check(not room_button.call("SHARED ROOM").disabled and room_button.call("PRIVATE ROOM").disabled and room_button.call("KING'S SUITE").disabled, "rooms the member can't afford are disabled")
	check(main._gear_row.find_children("*", "Button", true, false).all(func(b): return b.get_theme_stylebox("normal").bg_color == main.PAGER_FILL), "the rooms are small and brown")
	guest.gold = guest_gold
	guest.status = guest_status
	main.town.inn()
	check(main._backdrop.texture == inn_art and main.scr["opts"][-1]["label"] == "EXIT", "the inn keeps its painting and its EXIT")
	press("L")
	check(main.scr["title"] == "Castle" and not main._backdrop.visible, "leaving the inn clears its painting")
	var party_before: Array[int] = g.party.duplicate()
	press("R")
	check(main.scr["title"] == "Proving Grounds" and g.party == party_before and not party_before.is_empty(), "the Proving Grounds keep the party together")
	var retiree: Character = g.make_char("RETIREE", "HUMAN", "GOOD", Data.RACES["HUMAN"].duplicate(), "FIGHTER")
	g.party.append(retiree.id)
	main.chars._delete(retiree)
	check(g.party == party_before and g.ch(retiree.id) == null, "retiring a party member takes them out of the party")
	var lost_one: Character = g.make_char("LOSTONE", "HUMAN", "GOOD", Data.RACES["HUMAN"].duplicate(), "FIGHTER")
	var lost_two: Character = g.make_char("LOSTTWO", "HUMAN", "GOOD", Data.RACES["HUMAN"].duplicate(), "FIGHTER")
	var dead_home: Character = g.make_char("DEADHOME", "HUMAN", "GOOD", Data.RACES["HUMAN"].duplicate(), "FIGHTER")
	var outs_before: Array = g.outs.duplicate()
	lost_one.loc = "OUT"
	lost_one.status = "DEAD"
	lost_two.loc = "OUT"
	lost_two.status = "DEAD"
	dead_home.status = "DEAD"
	g.outs.append({"ids": [lost_one.id, lost_two.id], "pos": {"x": 1, "y": 1, "z": 1, "d": 0}})
	main.chars.train_char(lost_one)
	var delete_opt: Dictionary = main.scr["opts"].filter(func(o): return o["label"] == "DELETE")[0]
	check(not delete_opt.get("dis", false), "someone lost in the Maze can be deleted")
	check(main.scr["opts"].filter(func(o): return o["label"] == "CHANGE CLASS")[0]["dis"], "though their class still can't change")
	press("D")
	check(main.scr["title"] == "Lay them to rest?" and main.scr["body"].contains("LOSTONE"), "it asks first")
	press("N")
	check(g.ch(lost_one.id) != null and main.scr["title"] == "Character Sheet", "NO keeps them")
	press("D")
	press("Y")
	check(g.ch(lost_one.id) == null and main.scr["title"] == "Proving Grounds", "YES lets them go")
	check(g.outs.back()["ids"] == [lost_two.id], "the others lost with them stay where they fell")
	main.chars.train_char(lost_two)
	press("D")
	press("Y")
	check(g.ch(lost_two.id) == null and g.outs == outs_before, "and when no one is left, nothing is left in the Maze to find")
	main.chars.train_char(dead_home)
	check(not main.scr["opts"].filter(func(o): return o["label"] == "DELETE")[0].get("dis", false), "someone dead at home can be deleted")
	press("D")
	check(main.scr["title"] == "Lay them to rest?", "and is laid to rest too")
	press("Y")
	check(g.ch(dead_home.id) == null, "and is gone")
	var fillers: Array[Character] = []
	while not g.roster_full():
		fillers.append(g.make_char("FILLER%d" % fillers.size(), "HUMAN", "GOOD", Data.RACES["HUMAN"].duplicate(), "FIGHTER"))
	check(g.roster.size() == 20, "the roster holds 20 characters")
	main.chars.training()
	press("C")
	check(main.scr["title"] == "Proving Grounds", "a full roster cannot create a character")
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
	check(String(get_tree().current_scene.scr.get("where", "")).ends_with("Maze · Level 2"), "a maze save shows the maze")
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
	print("debug menu")
	check(not sw_scene._debug_list.visible and sw_scene._debug_toggle.text == "OPEN DEBUG MENU" and sw_scene._debug_toggle.icon == load(TownMap.PARTY_OPEN_ARROW), "the debug menu starts closed, with a down arrow")
	sw_scene._debug_toggle.pressed.emit()
	check(sw_scene._debug_list.visible and sw_scene._debug_toggle.text == "CLOSE DEBUG MENU" and sw_scene._debug_toggle.icon == load(TownMap.PARTY_CLOSE_ARROW), "pressing it opens the menu, with an up arrow")
	var debug_labels: Array = sw_scene._debug_list.get_children().map(func(b): return b.text)
	check(debug_labels[0].begins_with("MONSTERS") and debug_labels[1].begins_with("GOD MODE") and debug_labels[2] == "TO TOWN" and debug_labels[3] == "SPAWN CHEST" and debug_labels[4] == "ADD 500 GOLD" and debug_labels.size() == 5, "it has the monsters, god mode, town, chest and gold options")
	var debug_mode: String = g.mode
	var debug_party: Array[int] = g.party.duplicate()
	var debug_all_off := func() -> bool:
		return sw_scene._debug_list.get_children().all(func(b): return b.disabled or b == sw_scene.gold_button)
	g.mode = "castle"
	sw_scene._show_test_switches()
	check(debug_all_off.call(), "away from the Maze every option is greyed out")
	check(not sw_scene._debug_toggle.disabled, "but the menu still opens and closes")
	g.party.assign([g.roster[0].id])
	g.mode = "maze"
	sw_scene._show_test_switches()
	check(sw_scene._debug_list.get_children().all(func(b): return not b.disabled), "walking the Maze they all work")
	var gold_hero: Character = g.party_chars()[0]
	var gold_before: int = gold_hero.gold
	sw_scene.gold_button.pressed.emit()
	check(gold_hero.gold == gold_before + 500, "ADD 500 GOLD gives each member 500")
	gold_hero.gold = gold_before
	g.mode = "castle"
	sw_scene._show_test_switches()
	check(not sw_scene.gold_button.disabled, "and it works in town too, where gold is spent")
	var gold_party: Array[int] = g.party.duplicate()
	g.party.clear()
	sw_scene._show_test_switches()
	check(sw_scene.gold_button.disabled, "as long as there is a party")
	g.party.assign(gold_party)
	g.mode = "maze"
	sw_scene._show_test_switches()
	g.mode = "combat"
	sw_scene._show_test_switches()
	check(not sw_scene.town_button.disabled and not sw_scene.god_button.disabled and sw_scene.chest_button.disabled, "in a fight or at camp, all but the chest")
	g.mode = "maze"
	sw_scene.mz.maze()
	var debug_sizes := {}
	for debug_try in 60:
		sw_scene.chest_button.pressed.emit()
		debug_sizes[sw_scene.fight.chest["solution"].size()] = true
		check(sw_scene.scr["title"] == "A chest!", "SPAWN CHEST brings up a chest") if debug_try == 0 else null
	check(debug_sizes.size() == 3 and debug_sizes.has(3) and debug_sizes.has(4) and debug_sizes.has(5), "of every size, at random")
	check(sw_scene.scr["opts"].any(func(o): return o["label"] == "PICK LOCK"), "with its lock to pick")
	sw_scene.fight.chest = {}
	sw_scene._debug_toggle.pressed.emit()
	check(not sw_scene._debug_list.visible and sw_scene._debug_toggle.text == "OPEN DEBUG MENU", "pressing it again closes the menu")
	g.party.assign(debug_party)
	g.mode = debug_mode
	sw_scene._show_test_switches()
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
	check(not sw_scene._table.visible and sw_scene.scr["party_grid"] and sw_scene.scr["where"].ends_with("Level %d" % g.pos["z"]), "the party's cards stay up after the fight")
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
	var land_time: float = sfx_fight.BY_SECONDS + sfx_fight.ON_SECONDS
	sfx_start.call("SLIME", 5)
	check(sfx_fight.sounds_played == 0 and sw_scene.view._mark_by == 0, "the attacking monster lights up first, before any sound")
	sw_scene.view._process(land_time + 0.05)
	check(sfx_fight.sounds_played == 1 and sfx_fight._word != "", "the sound comes as the blow lands")
	sw_scene.view._process(sfx_fight.WORD_SECONDS - 0.2)
	check(sfx_fight.sounds_played == 1, "the next attack waits its turn")
	for sfx_wait in 40:
		if sfx_fight.sounds_played == 2:
			break
		sw_scene.view._process(0.1)
	check(sfx_fight.sounds_played == 2, "the next attack brings its own sound")
	sfx_start.call("RAT", 3)
	check(sfx_fight.sounds_played == 0 and sw_scene.view._mark_by == 0, "monsters without sounds still show their attack")
	var mon_res: Dictionary = sfx_fight.battle.results[0]
	check((String(mon_res["who"]).begins_with("HITS ") and String(mon_res["text"]).ends_with(" DAMAGE")) or mon_res["who"] == "MISSES", "a monster's attack says what it did")
	sw_scene.view.show_view("combat")
	sw_scene.view._process(land_time + 0.1)
	check(sfx_fight.sounds_played == 0 and sw_scene.view._beats.is_empty() and sw_scene.view._mark_by == -1, "leaving stops the round")
	print("attacks in steps")
	var card_edge := func() -> Color:
		var edge_grid: GridContainer = sfx_fight._party_grid()
		var edge: Color = edge_grid.get_child(0).get_theme_stylebox("panel").border_color
		edge_grid.free()
		return edge
	var card_fill := func() -> Color:
		var fill_grid: GridContainer = sfx_fight._party_grid()
		var fill: Color = fill_grid.get_child(0).get_theme_stylebox("panel").bg_color
		fill_grid.free()
		return fill
	var blow_battle := Battle.new()
	blow_battle.groups.append(Battle.mk_group("ORC", 3))
	blow_battle.round_no = 1
	sfx_fight.battle = blow_battle
	sw_scene.view.battle = blow_battle
	sfx_fight._run_round(true)
	sw_scene.view.show_view("combat")
	var blow_hero: Character = g.party_chars()[0]
	var blow_hp := [blow_hero.hp, blow_hero.maxhp, blow_hero.status]
	blow_hero.maxhp = 8
	blow_hero.hp = 4
	blow_hero.status = "OK"
	sw_scene.view.start_steps([0], Callable())
	sw_scene.hold_info(true)
	g.say("THE ORC HITS FOR 4 DAMAGE.")
	sfx_fight._present({"g": 0, "on": blow_hero, "hit": true}, [], {blow_hero: 8}, [blow_hero])
	check(sw_scene.view._mark_by == 0 and sfx_fight._on == null and sfx_fight._word == "", "first only the attacker is lit")
	check(not sw_scene._info_text.text.contains("THE ORC HITS") and sfx_fight._hp_labels[blow_hero].text.begins_with("HP 8/8"), "the news and the damage wait")
	sw_scene.view._process(sfx_fight.BY_SECONDS + 0.01)
	check(sfx_fight._on == blow_hero and sfx_fight._word == "" and card_edge.call() == sfx_fight.ON_COLOR, "then the one attacked lights up too")
	sw_scene.view._process(sfx_fight.ON_SECONDS)
	check(sfx_fight._word == "HIT" and sw_scene._info_text.text.contains("THE ORC HITS"), "then the blow lands, with its news")
	var blow_labels := []
	for blow_tick in 16:
		blow_labels.append(sfx_fight._hp_labels[blow_hero].text.get_slice("/", 0))
		sw_scene.view._process(0.1)
	check(blow_labels.has("HP 7") and blow_labels.has("HP 6") and blow_labels.has("HP 5") and blow_labels.has("HP 4"), "the hit points count down one at a time")
	check(blow_labels.find("HP 7") < blow_labels.find("HP 6") and blow_labels.find("HP 6") < blow_labels.find("HP 5") and blow_labels.find("HP 5") < blow_labels.find("HP 4"), "in order")
	check(blow_labels.find("HP 4") >= 11 and blow_labels.back() == "HP 4", "over about a second and a half")
	sfx_fight._clear_marks()
	blow_hero.hp = 0
	blow_hero.status = "DEAD"
	sw_scene.view.start_steps([0], Callable())
	sfx_fight._present({"g": 0, "on": blow_hero, "hit": true}, [], {blow_hero: 2}, [blow_hero])
	check(card_fill.call() != PartyCards.DEAD_FILL, "someone killed doesn't fall until the blow has counted down")
	sw_scene.view._process(sfx_fight.BY_SECONDS + 0.01)
	sw_scene.view._process(sfx_fight.ON_SECONDS)
	sw_scene.view._process(sfx_fight.HP_COUNT_SECONDS + 0.1)
	check(card_fill.call() == PartyCards.DEAD_FILL, "and then they do")
	sfx_fight._clear_marks()
	sw_scene.view.start_steps([0], Callable())
	blow_hero.status = "OK"
	blow_hero.hp = 8
	sfx_fight._present({"g": 0, "on": blow_hero, "hit": false}, [], {blow_hero: 8}, [])
	sw_scene.view._process(sfx_fight.BY_SECONDS + sfx_fight.ON_SECONDS + 0.01)
	check(sfx_fight._word == "MISS" and sfx_fight._hp_labels[blow_hero].text.begins_with("HP 8/8"), "a miss says MISS and takes nothing")
	sfx_fight._clear_marks()
	sw_scene.view.start_steps([0], Callable())
	sfx_fight._present({"g": 0, "by": blow_hero, "hit": true}, [], {}, [])
	check(sfx_fight._by == blow_hero and sw_scene.view._mark_by == -1 and sw_scene.view._mark_on == -1, "a character attacking lights up first")
	sw_scene.view._process(sfx_fight.BY_SECONDS + 0.01)
	check(sw_scene.view._mark_on == 0, "then the monsters attacked")
	sw_scene.view._process(sfx_fight.ON_SECONDS)
	check(sw_scene.view._results.size() == 1 and sw_scene.view._results[0]["text"] == "HIT", "then HIT shows on the monsters")
	sfx_fight._clear_marks()
	check(sw_scene.view._results.is_empty() and sw_scene.view._mark_on == -1, "and the next attack clears it")
	blow_hero.hp = blow_hp[0]
	blow_hero.maxhp = blow_hp[1]
	blow_hero.status = blow_hp[2]
	sw_scene.view.show_view("combat")
	sw_scene.clear_log()
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
	check(sw_scene.scr.get("title", "") == "Round 1" and (sw_scene.view._mark_by != -1 or sw_scene.fight._by != null), "a round starts with its first attacker lit")
	var res_steps := 0
	while sw_scene.scr.get("title", "") == "Round 1" and res_steps < 300:
		sw_scene.view._process(0.2)
		res_steps += 1
	check(res_steps > 8 and res_steps < 300 and sw_scene.view._results.is_empty(), "the fight moves on once the round has played and faded")
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
	var camp_cards := func() -> GridContainer:
		return sw_scene.scr["widget"].get_node("Cards")
	check(not sw_scene._table.visible and sw_scene.scr["party_grid"] and camp_cards.call().get_child_count() == 6, "camp shows the party's cards")
	check(sw_scene.scr["widget"].get_node("Hint").text == "Click a character to select them.", "and says to click one, over them")
	check(sw_scene._after_widget.visible and sw_scene._after_widget.text.contains("Guards are posted") and sw_scene._body.text == "", "with the guards' line under the cards")
	check(not sw_scene.scr["opts"].any(func(o): return o["label"] == "REORDER" or o["label"] == "EQUIP"), "and no REORDER or EQUIP")
	check(sw_scene._under_view != null and sw_scene._under_view.text == "LEAVE CAMP", "with LEAVE CAMP under the picture")
	var camp_ids: Array[int] = g.party.duplicate()
	g.party.assign([g.roster[0].id, g.roster[1].id, g.roster[2].id])
	sw_scene.mz.camp()
	var camp_size_before: Vector2 = camp_cards.call().get_child(0).get_combined_minimum_size()
	var camp_a: Character = g.party_chars()[0]
	var camp_c: Character = g.party_chars()[2]
	camp_cards.call().get_child(0).get_child(1).pressed.emit()
	check(sw_scene.mz._camp_pick == camp_a and camp_cards.call().get_child(0).get_theme_stylebox("panel").border_color == PartyCards.SELECTED_EDGE, "clicking a card selects that character")
	var camp_buttons: Array = camp_cards.call().get_child(0).find_children("*", "Button", true, false).map(func(b): return b.text)
	check(camp_buttons.has("INSPECT") and camp_buttons.has("SWAP"), "with INSPECT and SWAP on their card")
	check(camp_cards.call().get_child(0).get_combined_minimum_size().y == camp_size_before.y, "and no card changes height")
	camp_cards.call().get_child(0).find_child("INSPECT", true, false).pressed.emit()
	check(sw_scene.scr["title"] == "Character Sheet" and sw_scene._sheet.find_child("Stats", true, false).text.contains(camp_a.name), "INSPECT opens their sheet")
	sw_scene.scr["opts"].filter(func(o): return o["label"] == "CLOSE")[0]["fn"].call()
	check(sw_scene.scr["title"] == "Camp" and sw_scene.mz._camp_pick == camp_a, "CLOSE returns to camp, still selected")
	camp_cards.call().get_child(0).find_child("SWAP", true, false).pressed.emit()
	check(sw_scene.mz._camp_swapping and sw_scene.scr["widget"].get_node("Hint").text.contains("swaps places"), "SWAP waits for another card")
	camp_cards.call().get_child(2).get_child(1).pressed.emit()
	check(g.party_chars()[0] == camp_c and g.party_chars()[2] == camp_a and not sw_scene.mz._camp_swapping, "clicking one swaps their places")
	check(sw_scene.mz._camp_pick == camp_a and camp_cards.call().get_child(2).get_theme_stylebox("panel").border_color == PartyCards.SELECTED_EDGE, "and the one who moved stays selected")
	var camp_saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(g.save_path))
	check(Array(camp_saved["party"]).map(func(n): return int(n)) == Array(g.party), "the new order is saved")
	camp_cards.call().get_child(2).find_child("SWAP", true, false).pressed.emit()
	camp_cards.call().get_child(2).find_child("SWAP", true, false).pressed.emit()
	check(not sw_scene.mz._camp_swapping, "pressing SWAP again stops waiting")
	camp_cards.call().get_child(1).get_child(1).pressed.emit()
	check(sw_scene.mz._camp_pick == g.party_chars()[1] and g.party_chars()[0] == camp_c, "so a click just selects")
	g.party.assign(camp_ids)
	sw_scene.mz.camp()
	var leave_button: Button = sw_scene._under_view
	MazeView.instant_fades = false
	sw_scene.mz.maze()
	var make_camp: Callable = sw_scene.scr["opts"].filter(func(o): return o["label"] == "CAMP")[0]["fn"]
	make_camp.call()
	check(sw_scene.view.is_fading() and g.mode == "maze", "making camp fades the window to black first")
	make_camp.call()
	await get_tree().create_timer(MazeView.FADE_TIME + 0.1).timeout
	check(g.mode == "camp" and sw_scene.view._black.modulate.a < 1.0, "then fades up on the camp")
	if sw_scene.view.is_fading():
		await sw_scene.view.fade_done
	check(sw_scene.view._black.modulate.a == 0.0, "until it is clear")
	leave_button = sw_scene._under_view
	leave_button.pressed.emit()
	check(sw_scene.mz._camp_pick == null, "leaving camp forgets who was selected")
	check(sw_scene.view.is_fading() and g.mode == "camp", "and fades the window to black first")
	leave_button.pressed.emit()
	await get_tree().create_timer(MazeView.FADE_TIME + 0.1).timeout
	check(g.mode == "maze" and sw_scene.view._black.modulate.a < 1.0, "then shows the Maze as it fades back")
	if sw_scene.view.is_fading():
		await sw_scene.view.fade_done
	check(sw_scene.view._black.modulate.a == 0.0, "until it is clear")
	MazeView.instant_fades = true
	check(sw_scene.scr["where"].ends_with("Level %d" % g.pos["z"]) and sw_scene.scr.has("moves"), "pressing it walks out of camp")
	check(sw_scene._under_view == null and not is_instance_valid(leave_button), "and the button goes with it")
	sw_scene.mz.camp()
	check(not sw_scene.town_button.disabled, "the town button works in camp")
	sw_scene.town_button.pressed.emit()
	check(g.mode == "castle" and sw_scene.view.camp_fire == null, "leaving camp by the town button puts the campfire out")
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
	var camp_view: MazeView = camp_scene.view
	var pack_here := ResourceLoader.exists(MazeView.CAMP_FIRE_SCENE)
	check(camp_view.kind == "camp" and not camp_view.world.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "camp is a painting, so the 3D Maze stops drawing")
	check((camp_view.camp_fire != null) == pack_here, "camp lights the fire if the fire pack is installed")
	check(camp_view.camp_glow.visible and camp_view.camp_glow.mouse_filter == Control.MOUSE_FILTER_IGNORE, "an orange light flickers over the camp, letting clicks through")
	var flickers := []
	for flicker_i in 60:
		flickers.append(CampGlow.flicker(flicker_i * 0.05))
	check(flickers.min() >= CampGlow.LOW and flickers.max() <= 1.0 and flickers.max() - flickers.min() > 0.25, "and it flickers")
	if pack_here:
		check(camp_view.camp_fire.foot().distance_to(camp_view.view_point(MazeView.CAMP_FIRE_BASE)) < 1.0, "the fire stands on the painted logs")
		var crackle: AudioStreamPlayer = camp_view.camp_fire.get_node("Crackle")
		check(crackle.autoplay and crackle.stream != null, "the campfire crackles")
		var camp_flames: Node3D = camp_view.camp_fire.get_child(0).get_child(1)
		check(camp_flames.find_children("*", "AudioStreamPlayer3D", true, false).is_empty() and not camp_flames.get_children().any(func(n): return "intensity_multiplier" in n), "without the pack's own sound and light")
		check(camp_view.camp_fire.mouse_filter == Control.MOUSE_FILTER_IGNORE, "and lets clicks through")
		check(camp_view.camp_fire.fire().scale.y > camp_view.camp_fire.fire().scale.x and camp_view.camp_fire.get_child(0).get_child_count() == 4, "the fire is taller, with a smaller flame to each side")
		var camp_smoke: GPUParticles3D = camp_view.camp_fire.fire().get_node(MazeView.CAMP_SMOKE)
		var camp_main: GPUParticles3D = camp_view.camp_fire.fire().get_node("Flames")
		check(is_equal_approx(camp_smoke.speed_scale, camp_main.speed_scale * 2.0), "and its smoke rises twice as fast")
	camp_scene.mz.maze()
	check(camp_view.camp_fire == null and camp_view.world.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "leaving camp puts the fire out and the Maze back")
	check(not camp_view.camp_glow.visible, "and its light")
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

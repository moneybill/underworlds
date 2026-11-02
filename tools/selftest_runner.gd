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
	check(main.scr["title"].begins_with("NEWBIE"), "bonus point screen")
	check(not main.has_method("_input"), "the game takes no keyboard commands")
	for i in 30:
		main.scr["widget"].get_child(i % 6 * 4 + 3).pressed.emit()  # each row: name, value, -, +
	check(main.scr["body"].contains("BONUS POINTS: [color=#e3a33f]0[/color]"), "the + buttons spend every bonus point")
	main.scr["widget"].get_child(3).pressed.emit()
	main.scr["widget"].get_child(2).pressed.emit()
	check(main.scr["body"].contains("BONUS POINTS: [color=#e3a33f]1[/color]"), "the - buttons give a point back")
	press("Q")
	main.chars.create_name()
	main._entry.text = "buttoned"
	_ok_button().pressed.emit()
	check(main.scr["title"] == "BUTTONED: choose a race", "the OK button submits typed text")
	main.scr["widget"].get_node("Leave").pressed.emit()

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
	main.town.edge_of_town()
	check(not main._backdrop.visible and main._view_box.visible and main._header.visible, "other screens keep the normal layout")
	main.town.tavern()
	var tavern_art: Texture2D = main._backdrop.texture
	check(main._backdrop.visible and tavern_art != temple_art, "the tavern shows its own painting")
	check(tavern_art != null and absf(float(tavern_art.get_width()) / tavern_art.get_height() - 16.0 / 9.0) < 0.001, "the tavern painting is 16:9")
	main.chars.roster_pick("Add whom?", main.town._can_add, main.town._add, main.town.tavern)
	check(main._backdrop.texture == tavern_art, "adding a member keeps the tavern painting")
	press("L")
	press("R")
	check(main._backdrop.texture == tavern_art, "removing a member keeps the tavern painting")
	press("L")
	press("1")
	check(main.scr["title"] == "Inspect" and main._backdrop.texture == tavern_art, "inspecting keeps the tavern painting")
	press("R")
	check(main._backdrop.texture == tavern_art, "the spell books keep the tavern painting")
	press("Enter")
	press("L")
	check(main.scr["title"] == "Gilgamesh's Tavern", "inspect returns to the tavern")
	press("L")
	check(main.scr["title"] == "Castle" and not main._backdrop.visible, "leaving the tavern clears its painting")
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
	check(is_equal_approx(three_cards[2].get_center().x, mid_of_view.x) and is_equal_approx((three_cards[0].get_center().x + three_cards[1].get_center().x) / 2.0, mid_of_view.x) and is_equal_approx((three_cards[0].position.y + three_cards[2].end.y) / 2.0, mid_of_view.y), "three groups make two over one, centered")
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
	for art_id in MazeView.MONSTER_ART:
		check(Data.MONS.has(art_id), "the painting %s belongs to a monster" % art_id)
		check(MazeView.MONSTER_ART[art_id] is Texture2D, "the painting %s loads" % art_id)
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
	check(main._side.visible and main.scr["side"].get_child(0).text == "Dwarves are strong", "clicking a race opens its popup")
	var explain: Label = main.scr["side"].find_child("Explain", true, false)
	for st in Data.STATS:
		var info: Button = main.scr["side"].find_child("Info_" + st, true, false)
		info.mouse_entered.emit()
		check(explain.text == Data.STAT_INFO[st][1], "the (i) beside %s explains it" % st)
		info.mouse_exited.emit()
	check(main.scr["side"].get_child(2).get_child(0).text == "Strength: 10", "the popup shows the race's base statistics")
	main.scr["side"].find_child("Choose", true, false).pressed.emit()
	check(main.scr["title"] == "RACER: choose an alignment" and not main._side.visible, "choosing a race moves on and closes the popup")
	press("G")
	check(main.scr["title"].begins_with("RACER: G-DWARF"), "the chosen race carries through")
	main.chars.create_race("RACER")
	main.scr["widget"].get_node("Leave").pressed.emit()
	check(main.scr["title"] == "Training Grounds", "leaving the race screen returns to the Training Grounds")
	main.chars.create_stats("PAINTED", "HUMAN", "GOOD")
	check(main._backdrop.texture == training_art, "spending bonus points keeps the painting")
	for sex in ["MALE", "FEMALE"]:
		check(not Data.portraits(sex).is_empty(), "%s has portraits" % sex)
		for portrait in Data.portraits(sex):
			check(ResourceLoader.exists(Character.PORTRAIT_FILE % portrait), "portrait %s exists" % portrait)
	var picked := {"nm": "PICKED", "race": "HUMAN", "al": "GOOD", "st": Data.RACES["HUMAN"].duplicate(), "pts": 0, "max": 0}
	main.chars.create_sex(picked, "FIGHTER")
	press("F")
	check(main.scr["title"].ends_with("choose a portrait") and main.scr["widget"].get_child_count() == 12 and main.scr["widget"].columns == 4, "a page of portraits is a 4x3 grid")
	check(main.scr["widget"].get_child(0).get_child_count() == 0, "portraits carry no numbers")
	check(not press("B"), "the first page of portraits has nothing before it")
	check(press("N") and main.scr["widget"].get_child_count() == 12, "the next page of portraits offers twelve more")
	var keep_nm: String = picked["nm"]
	main.scr["widget"].get_child(1).pressed.emit()
	check(picked["portrait"] == "female_14", "clicking a portrait picks from the page on show")
	check(keep_nm == "PICKED", "picking a portrait keeps the character")
	main.chars.create_portrait(picked, "FIGHTER", "FEMALE", ceili(Data.portraits("FEMALE").size() / 12.0) - 1)
	check(not press("N") and main.scr["widget"].get_child_count() == (Data.portraits("FEMALE").size() - 1) % 12 + 1, "the last page holds the remaining portraits")
	main.chars.create_portrait(picked, "FIGHTER", "MALE")
	check(main.scr["widget"].get_child_count() == 12 and press("N") and main.scr["widget"].get_child_count() == 12, "the male portraits have pages too")
	main.chars.create_portrait(picked, "FIGHTER", "FEMALE")
	main.scr["widget"].get_child(1).pressed.emit()
	check(main.scr["title"] == "Keep this character?" and main._portrait.visible, "the confirmation shows the chosen portrait")
	press("Y")
	var made: Character = g.roster.back()
	check(made.name == "PICKED" and made.sex == "FEMALE" and made.portrait == "female_2", "the new character keeps the sex and portrait chosen")
	check(not main._portrait.visible, "the Training Grounds hide the portrait again")
	check(made.his() == "HER" and made.him() == "HER", "a female character gets female pronouns")
	var reloaded := Character.from_dict(JSON.parse_string(JSON.stringify(made.to_dict())))
	check(reloaded.sex == "FEMALE" and reloaded.portrait == "female_2", "sex and portrait survive a save")
	var old_save := made.to_dict()
	old_save.erase("sex")
	old_save.erase("portrait")
	var old_char := Character.from_dict(old_save)
	check(old_char.sex == "MALE" and old_char.portrait == "male_1", "characters from older saves default to portrait 1")
	var old_woman := made.to_dict()
	old_woman["portrait"] = "female_9999"
	check(Character.from_dict(old_woman).portrait == "female_1", "a missing portrait defaults to portrait 1 of the right sex")
	main.chars.inspect(old_char, "tavern", main.chars.training)
	check(main._portrait.visible and main._portrait_image.texture != null, "inspecting a character from an older save shows a portrait")
	old_char.portrait = ""
	main.chars.train_char(made)
	check(main._portrait.visible and main._portrait_image.texture != null, "inspecting a character shows their portrait")
	main.chars.train_char(old_char)
	check(not main._portrait.visible, "a character with no portrait shows none")
	main.chars.train_char(made)
	press("P")
	check(main.scr["title"] == "PICKED: choose a portrait" and main.scr["widget"].get_child_count() == 12, "Change Portrait opens the picker")
	press("L")
	check(main.scr["title"] == "PICKED" and made.portrait == "female_2", "leaving the picker keeps the old portrait")
	press("P")
	press("N")
	main.scr["widget"].get_child(0).pressed.emit()
	check(main.scr["title"] == "PICKED" and made.portrait == "female_13", "Change Portrait replaces the portrait")
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
	press("1")
	check(main.scr["title"] == "Boltac's Trading Post" and main._backdrop.texture == boltac_art, "the shop keeps the painting")
	press("B")
	check(main.scr["title"] == "Buy" and main._backdrop.texture == boltac_art, "buying keeps the painting")
	press("L")
	press("S")
	check(main.scr["title"] == "Sell" and main._backdrop.texture == boltac_art, "selling keeps the painting")
	press("L")
	press("L")
	check(main.scr["title"] == "Castle" and not main._backdrop.visible, "leaving Boltac's clears its painting")
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
	main.town.edge_of_town()
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
	main.town.edge_of_town()
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


func _ok_button() -> Button:
	for b in main._opts_flow.get_children():
		if b.text == "OK" and not b.is_queued_for_deletion():
			return b
	return null


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
	check(title.nav.get_global_rect().get_center().distance_to(title.get_global_rect().get_center()) < 1.0, "the title's buttons sit at the centre of the screen")
	check(title.venture_button.text == "Venture Onwards" and title.options_button.text == "Options" and title.nav.get_child_count() == 2, "the title has its two buttons")
	check(title.venture_button.get_theme_stylebox("normal").texture == load("res://assets/images/buttons/large_normal.png") and title.venture_button.get_theme_stylebox("pressed").texture == load("res://assets/images/buttons/large_pressed.png"), "venture onwards uses the large button art")
	check(title.options_button.get_theme_stylebox("normal").texture == load("res://assets/images/buttons/medium_normal.png"), "options uses the medium button art")

	# Options opens the panel and Back closes it.
	title.options_button.pressed.emit()
	check(title.options_panel.visible and not title.nav.visible, "options opens its panel")
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
	check(sw_scene.scr.get("title", "") == "Choose a target", "the target screen shows")
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
	g.new_game()
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

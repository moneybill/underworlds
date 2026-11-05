class_name CombatScreens
extends RefCounted
## Combat orders (Fight, Parry, Dispell, Spell, Use, Run, Take back), friendly encounters,
## and treasure chests with their traps.

const IDLE_GAP_MIN := 6.0  # seconds between idle sounds, at least
const IDLE_GAP_MAX := 12.0  # and at most

const BY_SECONDS := 0.4  # how long the attacker shows alone
const ON_SECONDS := 0.4  # and then the target, before the blow lands
const WORD_SECONDS := 0.9  # HIT or MISS, when no hit points are counting down
const HP_COUNT_SECONDS := 1.5  # hit points counting down
const FAST_BY_SECONDS := 0.1  # the same, with Fast Combat Results on
const FAST_ON_SECONDS := 0.1
const FAST_WORD_SECONDS := 0.3
const FAST_HP_COUNT_SECONDS := 0.4
const HIT_WORD := "HIT"
const MISS_WORD := "MISS"
const WORD_FONT := 34
const MARK_WIDTH := 4
const ON_COLOR := Color("d6563f")

var ui
var instant := false  # tests play rounds in one go
var _by: Character = null  # the character attacking now
var _on: Character = null  # the character being attacked now
var _word := ""  # HIT or MISS, on the attacked character's portrait
var _shown_hp := {}  # character -> the hit points still showing while a blow lands
var _hp_labels := {}  # character -> the hit point line on their card
var sounds_played := 0
var idles_played := 0
var battle: Battle = null
var chest: Dictionary = {}


var _in_round := false  # a round is playing, rather than the party giving its orders
var _idle_timer: Timer
var _sound_dice := RandomNumberGenerator.new()  # its own, so that sounds can't change what the game's dice roll


func _init(root) -> void:
	ui = root
	_sound_dice.randomize()
	_idle_timer = Timer.new()
	_idle_timer.wait_time = IDLE_GAP_MAX
	_idle_timer.autostart = true
	_idle_timer.timeout.connect(idle_tick)
	ui.add_child(_idle_timer)


func _where() -> String:
	return "Maze · Level %d" % Game.pos["z"]


const FRONT_ROW := PartyCards.COLUMNS  # party slots in each row
const CASTERS := ["MAGE", "PRIEST", "BISHOP"]  # may cast in a fight
const DISPELLERS := ["PRIEST", "BISHOP"]

var _active := -1  # the party slot choosing its orders, or -1


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
		_run_round(true)
		return
	start_round()


func _friendly() -> void:
	var gp: Dictionary = battle.groups[0]
	var n := battle.live(gp).size()
	ui.show_screen({"title": "A friendly group", "where": _where(), "view": "combat",
		"body": "A friendly group of %d %s. They hail you in welcome!\n\n" % [n, battle.gname(gp, n)] + ui.flav("How you answer a peaceful greeting may change you."),
		"opts": [{"k": "F", "label": "FIGHT", "fn": _attack_friends}, {"k": "L", "label": "LEAVE IN PEACE", "fn": _leave_in_peace}]})


func _attack_friends() -> void:
	for c in Game.party_chars():
		if c.align == "GOOD" and randf() < 0.25:
			c.align = "EVIL"
			Game.say("%s FEELS A DARKNESS SETTLE IN. (NOW EVIL)" % c.name, "hit")
	start_round()


func _leave_in_peace() -> void:
	for c in Game.party_chars():
		if c.align == "EVIL" and Data.alignments_for(c.race).has("GOOD") and randf() < 0.1:
			c.align = "GOOD"
			Game.say("%s FEELS STRANGELY WARM INSIDE. (NOW GOOD)" % c.name, "ok")
	_done()
	ui.mz.maze()


func _done() -> void:
	battle = null
	_in_round = false
	ui.view.battle = null


# ---------- orders ----------
func start_round() -> void:
	_in_round = false
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
	_active = i
	ui.show_screen({"title": "%s's options" % ps[i].name, "where": _where(), "view": "combat", "widget": _party_grid(_turn_options(i, ps[i])), "party_grid": true, "opts": _turn_options(i, ps[i])})


## What a character can do goes under their portrait. Run and Back are for the whole party, and sit below it.
func _turn_options(i: int, c: Character) -> Array:
	var front := i < FRONT_ROW
	var again := next_cmd.bind(i)
	var no_magic := battle.surprise == "party" and battle.round_no == 1
	var undead := battle.alive_groups().filter(func(g): return Data.MONS[battle.groups[g]["id"]].get("undead", false))
	var usable := c.items.filter(func(it): return c.item_def(it).has("spell") and not it.get("broken", false) and "CA".contains(Data.SPELLS[c.item_def(it)["spell"]][2]))
	var reach: Array = battle.alive_groups().slice(0, 2)
	return [
		{"k": "F", "label": "FIGHT", "in_widget": true, "hide": not front, "fn": _choose_group.bind(reach, _order.bind(i, c, "fight"), again)},
		{"k": "B", "label": "BACKSTAB", "in_widget": true, "hide": not front or c.cls != "THIEF", "fn": _choose_group.bind(reach, _order.bind(i, c, "backstab"), again)},
		{"k": "S", "label": "CAST SPELL", "in_widget": true, "hide": not CASTERS.has(c.cls), "dis": no_magic or battle.combat_spells(c).is_empty(), "fn": _pick_spell.bind(i, c)},
		{"k": "D", "label": "DISPEL", "in_widget": true, "hide": not DISPELLERS.has(c.cls), "dis": not battle.can_dispel(c) or undead.is_empty() or no_magic, "fn": _choose_group.bind(undead, _order.bind(i, c, "dispel"), again)},
		{"k": "P", "label": "PARRY", "in_widget": true, "fn": _push.bind(i, {"c": c, "type": "parry"})},
		{"k": "U", "label": "USE ITEM", "in_widget": true, "hide": usable.is_empty(), "dis": no_magic, "fn": _pick_item.bind(i, c, usable)},
		{"k": "R", "label": "RUN", "fn": _run},
		{"k": "T", "label": "BACK", "hide": battle.cmds.is_empty(), "fn": _undo_order},
	]


## The party, with the current character's options under their portrait.
## The same cards for walking the Maze, with no fight going on.
func explore_grid(on_click := Callable(), selected := -1) -> GridContainer:
	return PartyCards.grid(_fill_explore_cell, selected, 3, on_click, true, 1.0, {}, true)


func _fill_explore_cell(v: VBoxContainer, c: Character, _i: int) -> void:
	PartyCards.add_head(v, c, true)
	if c.status != "OK" and c.is_alive():  # the dead have their tombstone
		_add_state_badge(v.get_child(0), c.status)


func _party_grid(opts: Array = []) -> GridContainer:
	var g := PartyCards.grid(_fill_cell.bind(opts), _active, 3, Callable(), true, 1.0, _shown_hp, true)
	var ps := Game.party_chars()
	if ps.has(_by):
		_mark_card(g.get_child(ps.find(_by)), UiStyle.C_TORCH)
	if ps.has(_on):
		_mark_card(g.get_child(ps.find(_on)), ON_COLOR)
	return g


func _mark_card(cell: PanelContainer, edge: Color) -> void:
	var mark: StyleBoxFlat = cell.get_theme_stylebox("panel").duplicate()
	mark.border_color = edge
	mark.set_border_width_all(MARK_WIDTH)
	cell.add_theme_stylebox_override("panel", mark)


func _fill_cell(v: VBoxContainer, c: Character, i: int, opts: Array) -> void:
	PartyCards.add_head(v, c, true, _shown_hp.get(c, -1))
	_hp_labels[c] = v.get_child(v.get_child_count() - 1)
	if c == _on and _word != "":
		_add_word(v.get_child(0), _word)
	var state := "" if c.status == "OK" else c.status
	for order in battle.cmds:
		if order["c"] == c:
			state = String(order["type"]).to_upper()
	if state != "" and c.is_alive():  # the dead have their tombstone
		_add_state_badge(v.get_child(0), state)
	var own := opts.filter(func(o): return o.get("in_widget", false) and not o.get("hide", false))
	if i != _active or own.is_empty():
		return
	var buttons := GridContainer.new()
	buttons.columns = 2
	buttons.add_theme_constant_override("h_separation", 3)
	buttons.add_theme_constant_override("v_separation", 3)
	v.add_child(buttons)
	for o in own:
		var b := Button.new()
		b.text = o["label"]
		b.disabled = o.get("dis", false)
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		for st in ["normal", "hover", "disabled"]:
			b.add_theme_stylebox_override(st, UiStyle.box(UiStyle.C_STONE if st == "disabled" else UiStyle.C_STONE2, UiStyle.C_LINE if st != "hover" else UiStyle.C_DIM, 3))
		b.add_theme_stylebox_override("pressed", UiStyle.box(UiStyle.C_TORCH, UiStyle.C_TORCH, 3))
		b.pressed.connect(ui._run.bind(o))
		buttons.add_child(b)


## A character's order or condition, across the foot of their portrait.
## HIT or MISS, large in the middle of a portrait.
func _add_word(portrait: Control, word: String) -> void:
	var l := Label.new()
	l.text = word
	l.add_theme_font_size_override("font_size", WORD_FONT)
	l.add_theme_color_override("font_color", ON_COLOR if word == HIT_WORD else UiStyle.C_INK)
	l.add_theme_stylebox_override("normal", UiStyle.box(Color(UiStyle.C_BG, 0.8), Color(UiStyle.C_BG, 0.8), 2))
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(l)


func _add_state_badge(portrait: Control, state: String) -> void:
	var badge := PartyCards.label(state, UiStyle.C_TORCH)
	var back := UiStyle.box(Color(UiStyle.C_BG, 0.85), UiStyle.C_TORCH, 0)
	back.content_margin_left = 5.0
	back.content_margin_right = 5.0
	badge.add_theme_stylebox_override("normal", back)
	badge.clip_text = false
	badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(badge)


## Plays the round the party has ordered.
func _fight_round() -> void:
	_run_round(false)


## Plays a round one attack at a time, so each result and sound comes as it happens.
func _run_round(mon_only: bool) -> void:
	if instant:
		_after(battle.play_round(mon_only))
		return
	_active = -1
	_in_round = true
	_clear_marks()
	var shown := battle.alive_groups()
	battle.begin_round(mon_only)
	var title := "The monsters attack!" if mon_only else "Round %d" % battle.round_no
	ui.show_screen({"title": title, "where": _where(), "view": "combat", "widget": _party_grid(), "party_grid": true, "opts": []})
	ui.view.start_steps(shown, _step_round)


## The next act that shows or sounds; acts that do neither just go in the log.
func _step_round() -> void:
	_clear_marks()
	while battle.has_next_act():
		var old_results: int = battle.results.size()
		var old_sounds: int = battle.sounds.size()
		var old_hp := {}
		for c in Game.party_chars():
			old_hp[c] = c.hp
		var old_counts := {}
		for g in battle.groups.size():
			old_counts[g] = battle.live(battle.groups[g]).size()
		ui.hold_info(true)
		battle.step()
		var streams := MonsterSounds.for_events(battle.sounds.slice(old_sounds))
		var hurt: Array = Game.party_chars().filter(func(c): return old_hp.has(c) and c.hp < old_hp[c])
		var news := battle.results.slice(old_results)
		if news.is_empty() and streams.is_empty() and hurt.is_empty():
			ui.hold_info(false)
			continue
		ui.view.shown_counts = old_counts
		_present(news.front() if not news.is_empty() else {}, streams, old_hp, hurt)
		return
	ui.hold_info(false)
	var outcome := battle.finish_round()
	_show_party()
	ui.view.end_steps(_after.bind(outcome))


func _beat(normal: float, fast: float) -> float:
	return fast if Game.fast_results else normal


## An attack: the attacker lights up, then the one attacked, then HIT or MISS and the damage counting down.
## res is empty for what has no attacker to show, like a spell: its damage just counts down.
func _present(res: Dictionary, streams: Array, old_hp: Dictionary, hurt: Array) -> void:
	for c in hurt:
		_shown_hp[c] = old_hp[c]
	var count: float = _beat(HP_COUNT_SECONDS, FAST_HP_COUNT_SECONDS) if not hurt.is_empty() else 0.0
	if res.is_empty():
		_show_party()
		_land({}, streams, hurt, old_hp, count)
		ui.view.hold_next_step(maxf(ui.view._step_gap(), count))
		return
	var by_group: int = res["g"] if res.has("on") else -1
	_by = res.get("by")
	ui.view.set_marks(by_group, -1)
	_show_party()
	var to_target := _beat(BY_SECONDS, FAST_BY_SECONDS)
	var to_word := to_target + _beat(ON_SECONDS, FAST_ON_SECONDS)
	ui.view.after(to_target, _mark_target.bind(res, by_group))
	ui.view.after(to_word, _land.bind(res, streams, hurt, old_hp, count))
	ui.view.hold_next_step(to_word + maxf(count, _beat(WORD_SECONDS, FAST_WORD_SECONDS)))


func _mark_target(res: Dictionary, by_group: int) -> void:
	_on = res.get("on")
	ui.view.set_marks(by_group, res["g"] if res.has("by") else -1)
	_show_party()


## The blow lands: its word, its sound and its news come together, and the damage starts counting down.
func _land(res: Dictionary, streams: Array, hurt: Array, old_hp: Dictionary, count: float) -> void:
	ui.hold_info(false)
	ui.view.shown_counts = {}
	if not streams.is_empty():
		_play_one(streams)
		sounds_played += 1
	if not res.is_empty():
		var word: String = HIT_WORD if res["hit"] else MISS_WORD
		if res.has("on"):
			_word = word
		else:
			ui.view.add_result({"g": res["g"], "text": word, "hit": res["hit"]})
	_show_party()
	for c in hurt:
		var from: int = old_hp[c]
		var to: int = maxi(c.hp, 0)
		for i in range(1, from - to + 1):
			ui.view.after(count * i / (from - to), _count_hp.bind(c, from - i, to))


func _count_hp(c: Character, hp: int, last: int) -> void:
	_shown_hp[c] = hp
	if _hp_labels.has(c):
		_hp_labels[c].text = PartyCards.hp_text(c, hp)
	if hp == last:
		_shown_hp.erase(c)
		if not c.is_alive():
			_show_party()  # only now do they fall


func _clear_marks() -> void:
	_by = null
	_on = null
	_word = ""
	_shown_hp = {}
	ui.view.clear_words()
	ui.view.set_marks(-1, -1)


func _play_one(streams: Array) -> void:
	ui.play_sound(streams[_sound_dice.randi_range(0, streams.size() - 1)])


## Now and then, a monster makes a noise while the party decides what to do.
func idle_tick() -> void:
	_idle_timer.wait_time = _sound_dice.randf_range(IDLE_GAP_MIN, IDLE_GAP_MAX)
	if battle == null or _in_round or instant or Game.mode != "combat":
		return
	var streams := MonsterSounds.idle_for(battle.alive_groups().map(func(g): return battle.groups[g]["id"]))
	if not streams.is_empty():
		_play_one(streams)
		idles_played += 1


## Redraws the party's portraits, as hits land during a round.
func _show_party() -> void:
	for n in ui.widget_box().get_children():
		n.queue_free()
	ui.widget_box().add_child(_party_grid())


## Takes back the last order given, and returns to that character.
func _undo_order() -> void:
	var last: Dictionary = battle.cmds.pop_back()
	next_cmd(Game.party_chars().find(last["c"]))


func _push(i: int, order: Dictionary) -> void:
	battle.cmds.append(order)
	next_cmd(i + 1)


func _order(g: int, i: int, c: Character, type: String) -> void:
	_push(i, {"c": c, "type": type, "g": g})


func _choose_group(list: Array, fn: Callable, back: Callable) -> void:
	if list.size() == 1:
		fn.call(list[0])
		return
	ui.show_screen({"view_note": "Choose a target", "where": _where(), "view": "combat", "widget": _party_grid(), "party_grid": true, "opts": [
		{"k": "L", "label": "BACK", "fn": back},
	]})
	ui.view.set_targets(list, fn)


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
		items.append({"label": c.item_name(it), "icon": c.item_icon(it), "fn": _target_for.bind(n, func(t): _push(i, {"c": c, "type": "use", "item": it, "n": n, "t": t}), next_cmd.bind(i))})
	ui.choose_list("Use which item?", "", items, next_cmd.bind(i))


func _confirm() -> void:
	_active = -1
	ui.show_screen({"title": "Ready?", "where": _where(), "view": "combat", "widget": _party_grid(), "party_grid": true, "opts": [
		{"k": "Enter", "label": "FIGHT!", "fn": func(): ui.clear_log(); _fight_round()},
		{"k": "T", "label": "BACK", "hide": battle.cmds.is_empty(), "fn": _undo_order},
	]})


func _run() -> void:
	if battle.try_run():
		_after("fled")
	else:
		_run_round(true)


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
	var slots: int = Dice.rnd(LockScreens.CHEST_SIZES.keys().min(), LockScreens.CHEST_SIZES.keys().max())
	chest = {"trap": 0 if randf() < 0.15 else Dice.rnd(1, mini(6, 3 + z)), "gold": gold, "item": item, "solution": LockScreens.random_solution(slots)}
	chest_menu()


func chest_menu() -> void:
	var who := func(title: String, fn: Callable): ui.pick_member(title, chest_menu, fn, func(c): return c.can_act())
	ui.show_screen({"title": "A chest!", "where": _where(), "view": "chest",
		"body": ui.flav("The monsters were guarding a %s treasure chest. Chests are usually trapped, and this is the moment your thief earns a share." % LockScreens.CHEST_SIZES[chest["solution"].size()]),
		"opts": [
			{"k": "O", "label": "OPEN", "fn": func(): who.call("Who opens it?", _open)},
			{"k": "P", "label": "PICK LOCK", "fn": func(): who.call("Who picks the lock?", _pick_chest)},
			{"k": "I", "label": "INSPECT", "fn": func(): who.call("Who inspects it?", _inspect)},
			{"k": "C", "label": "CALFO", "fn": func(): who.call("Who casts CALFO?", _calfo)},
			{"k": "D", "label": "DISARM", "fn": func(): who.call("Who disarms it?", _disarm)},
			{"k": "L", "label": "BACK", "fn": func(): Game.say("YOU LEAVE THE CHEST ALONE."); chest = {}; ui.mz.maze()},
		]})


func _deft(c: Character) -> bool:
	return c.cdata().get("thief", false) or c.cdata().get("ninja", false)


func _open(c: Character) -> void:
	if chest["trap"] > 0:
		_spring(c)
	else:
		_loot()


func _pick_chest(c: Character) -> void:
	ui.lock.pick(c, chest["solution"], "A %s chest" % LockScreens.CHEST_SIZES[chest["solution"].size()], "chest", _chest_picked.bind(c), _chest_slipped.bind(c), chest_menu, chest, true)


## A picked lock gets past the trap.
func _chest_picked(c: Character) -> void:
	Game.say("%s PICKS THE LOCK!" % c.name, "ok")
	_loot()


## A wrong try forces the lid, as if it had just been opened.
func _chest_slipped(c: Character) -> void:
	Game.say("THE PICK SLIPS AND THE LID JUMPS OPEN.", "hit")
	_open(c)


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
		"input": {"ph": "TRAP NAME", "max": 20, "fn": func(v): _try_disarm(c, v)}, "opts": [{"k": "Escape", "label": "BACK", "fn": chest_menu}]})


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
	if t.status == "OK" and not Game.god_mode:
		t.status = "POISON"
		Game.say("%s IS POISONED!" % t.name, "hit")


func _hurt(t: Character, d: int) -> void:
	Game.say("%s TAKES %d DAMAGE." % [t.name, d], "hit")
	Game.hurt(t, d)
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
			if c.is_alive() and not Game.god_mode:
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
			who.items_found += 1
			Game.say("%s FOUND A %s?" % [who.name, Data.ITEMS[c["item"]]["unk"]], "gold")
		else:
			Game.say("YOUR PACKS ARE FULL. THE TREASURE STAYS BEHIND.")
	Game.save_game()
	ui.mz.maze()

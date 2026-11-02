class_name Battle
extends RefCounted
## One fight: monster groups, the party's orders for the round, and how a round plays out.
## Each group: {id, ac_mod, known, ms: [{hp, asleep, para, sil, dead, disp}]}
## Orders: {c: Character, type: fight|parry|dispel|spell|use, g: group index, n: spell, t: target, item}

var groups: Array = []
var lair := false
var boss := false
var round_no := 0
var surprise := ""  # "party", "mon" or ""
var cmds: Array = []


const MAX_GROUPS := 4  # as many as the fight screen's 2x2 grid holds


static func mk_group(id: String, n: int) -> Dictionary:
	var M: Dictionary = Data.MONS[id]
	var ms := []
	for i in n:
		ms.append({"hp": Dice.rnd(M["hp"][0], M["hp"][1]), "asleep": false, "para": false, "sil": false, "dead": false, "disp": false})
	return {"id": id, "ac_mod": 0, "known": false, "ms": ms}


## Rolls up an encounter for the current Maze level.
func setup(is_lair: bool, is_boss: bool) -> void:
	lair = is_lair
	boss = is_boss
	var z: int = Game.pos["z"]
	if boss:
		groups = [mk_group("WERDNA", 1), mk_group("VAMP", 2)]
	else:
		var n := 1
		var chance: float = (0.45 if lair else 0.22) + 0.08 * (z - 1)
		while n < MAX_GROUPS and randf() < chance:
			n += 1
			chance /= 2.0  # each extra group is half as likely as the last
		var used := []
		for i in n:
			var id: String = Dice.pick(Data.MON_BY_LEVEL[z])
			if used.has(id):
				continue
			used.append(id)
			var M: Dictionary = Data.MONS[id]
			groups.append(mk_group(id, Dice.rnd(M["g"][0], M["g"][1])))
	for gp in groups:
		gp["known"] = Data.MONS[gp["id"]].get("boss", false)
		for c in Game.living():
			if Dice.rnd(1, 22) <= c.stats["iq"] - 6:
				gp["known"] = true
	for c in Game.party_chars():
		c.cac = 0
		c.parry = false


func live(gp: Dictionary) -> Array:
	return gp["ms"].filter(func(m): return not m["dead"])


func alive_groups() -> Array:
	var out := []
	for i in groups.size():
		if not live(groups[i]).is_empty():
			out.append(i)
	return out


func gname(gp: Dictionary, n: int) -> String:
	var M: Dictionary = Data.MONS[gp["id"]]
	var s: String = M["n"] if gp["known"] or Game.latumapic else M["u"]
	if n > 1 and not s.contains(" ") and not s.ends_with("S"):
		s += "S"
	return s


## "AN ORC", "A SKELETON": the name of one monster with its article.
func a_name(gp: Dictionary) -> String:
	var s := gname(gp, 1)
	return ("AN " if "AEIOU".contains(s.substr(0, 1)) else "A ") + s


func is_friendly() -> bool:
	return not boss and groups.size() == 1 and Data.MONS[groups[0]["id"]].get("friendly", false) and randf() < 0.5


func can_dispel(c: Character) -> bool:
	var d = c.cdata().get("dispel")
	return d != null and c.lvl >= d


func combat_spells(c: Character) -> Array:
	return c.spells.filter(func(n): return "CA".contains(Data.SPELLS[n][2]) and c.can_cast(n))


# ---------- a round ----------
## Returns "fled", "victory", "wiped" or "next".
func resolve(run: bool) -> String:
	var mon_only := false
	if run:
		var avg := 0.0
		for c in Game.party_chars():
			avg += c.lvl
		avg /= max(1, Game.party.size())
		var mx := 1
		for gi in alive_groups():
			mx = maxi(mx, Data.MONS[groups[gi]["id"]]["lv"])
		var pct := 0.0 if boss else clampf(55 + 6 * (avg - mx), 15, 95)
		if Dice.chance(pct):
			Game.say("YOU FLEE!", "ok")
			_cleanup()
			return "fled"
		Game.say("A WALL OF FORCE BLOCKS YOUR ESCAPE!" if boss else "YOU COULD NOT GET AWAY!", "hit")
		mon_only = true
	return play_round(mon_only)


func play_round(mon_only: bool) -> String:
	var acts := []
	if not mon_only:
		for a in cmds:
			if a["type"] == "parry":
				a["c"].parry = true
			else:
				var o: Dictionary = a.duplicate()
				o["init"] = Dice.rnd(1, 10) + Character.agi_init(a["c"].stats["agi"])
				acts.append(o)
	if not (surprise == "party" and round_no == 1 and not mon_only):
		for gp in groups:
			for m in gp["ms"]:
				if not m["dead"]:
					acts.append({"mon": true, "gp": gp, "m": m, "init": Dice.rnd(1, 10) - Data.MONS[gp["id"]]["lv"] / 3})
	acts.sort_custom(func(a, b): return a["init"] < b["init"])
	for a in acts:
		if alive_groups().is_empty() or Game.living().is_empty():
			break
		if a.get("mon", false):
			_mon_act(a["gp"], a["m"])
		else:
			_party_act(a)
	return _end_of_round()


func _end_of_round() -> String:
	for c in Game.party_chars():
		c.parry = false
		if c.status == "ASLEEP" and randf() < 0.5:
			c.status = "OK"
			Game.say("%s WAKES UP." % c.name)
		if c.status == "POISON":
			Game.hurt(c, Dice.rnd(1, 2))
			if c.hp <= 0:
				c.hp = 0
				c.status = "DEAD"
				Game.say("%s DIES OF POISON!" % c.name, "hit")
	for gp in groups:
		for m in gp["ms"]:
			if m["asleep"] and randf() < 0.25:
				m["asleep"] = false
			if m["para"] and randf() < 0.1:
				m["para"] = false
	# The dead are carried at the back of the line.
	var front: Array[int] = []
	var back: Array[int] = []
	for cid in Game.party:
		(front if Game.ch(cid).is_alive() else back).append(cid)
	Game.party = front + back
	if Game.living().is_empty():
		return "wiped"
	if alive_groups().is_empty():
		return "victory"
	return "next"


func _cleanup() -> void:
	for c in Game.party_chars():
		c.cac = 0
		c.parry = false
		if c.status == "ASLEEP":
			c.status = "OK"


func _kill(m: Dictionary, dispelled := false) -> void:
	m["dead"] = true
	m["hp"] = 0
	m["disp"] = dispelled


func _hurt(m: Dictionary, d: int) -> bool:
	m["hp"] -= d
	if m["hp"] <= 0:
		_kill(m)
		return true
	return false


func _target_group(g: int) -> Variant:
	if g >= 0 and g < groups.size() and not live(groups[g]).is_empty():
		return groups[g]
	var ag := alive_groups()
	return null if ag.is_empty() else groups[ag[0]]


func _party_act(a: Dictionary) -> void:
	var c: Character = a["c"]
	if not c.can_act():
		return
	match a["type"]:
		"fight": _fight(c, a.get("g", 0))
		"dispel":
			var gp: Dictionary = groups[a["g"]]
			var k := 0
			for m in live(gp):
				if Dice.chance(clampf(50 + 5 * c.lvl - 10 * Data.MONS[gp["id"]]["lv"], 5, 95)):
					_kill(m, true)
					k += 1
			Game.say("%s DISPELLS! %s" % [c.name, ("%d %s DISSOLVE INTO THE ABYSS." % [k, gname(gp, k)]) if k > 0 else "NOTHING HAPPENS."], "mag" if k > 0 else "")
		"spell":
			if not c.can_cast(a["n"]):
				Game.say("%s IS OUT OF SPELL POINTS." % c.name)
				return
			c.spend(a["n"])
			Game.say("%s CASTS %s!" % [c.name, a["n"]], "mag")
			_cast(c, a["n"], a.get("t"))
		"use":
			var it: Dictionary = a["item"]
			if not c.items.has(it) or it.get("broken", false):
				return
			Game.say("%s USES THE %s!" % [c.name, c.item_name(it)], "mag")
			Spells.use_charge(c, it)
			_cast(c, a["n"], a.get("t"))


func _fight(c: Character, g: int) -> void:
	var gp = _target_group(g)
	if gp == null:
		return
	var M: Dictionary = Data.MONS[gp["id"]]
	var wpn = c.equipped("W")
	var p: Dictionary = {} if wpn == null else c.item_def(wpn)
	var dice: String = p.get("dmg", "2d4" if c.cdata().get("ninja", false) else "1d2")
	var war: bool = c.cdata().get("war", false)
	var hb: int = (1 + c.lvl / 2 if war else c.lvl / 3) + Character.str_bonus(c.stats["str"]) + int(p.get("hit", 0))
	if wpn != null and wpn.get("bad", false):
		hb -= 3
	var swings: int = 1 + (c.lvl / 5 if war else 0) + (1 if c.cdata().get("ninja", false) and wpn == null else 0)
	var hits := 0
	var dmg := 0
	var killed := 0
	var crit := false
	var tgt = Dice.pick(live(gp))
	for i in swings:
		if tgt == null or tgt["dead"]:
			tgt = Dice.pick(live(gp))
			if tgt == null:
				break
		var need := clampi(11 - hb + (10 - (int(M["ac"]) + int(gp["ac_mod"]))), 2, 20)
		if tgt["asleep"] or tgt["para"] or Dice.rnd(1, 20) >= need:
			hits += 1
			if c.cdata().get("ninja", false) and wpn == null and not M.get("boss", false) and Dice.chance(c.lvl * 2 + 4):
				_kill(tgt)
				killed += 1
				crit = true
				continue
			var d := maxi(1, Dice.roll(dice) + Character.str_bonus(c.stats["str"]))
			dmg += d
			if _hurt(tgt, d):
				killed += 1
	var nm := a_name(gp)
	if hits == 0:
		Game.say("%s SWINGS AT %s AND MISSES." % [c.name, nm])
		return
	var line := "%s STRIKES %s. A CRITICAL HIT!" % [c.name, nm] if crit else "%s HITS %s %s FOR %d DAMAGE!" % [c.name, nm, "%d TIMES" % hits if hits > 1 else "ONCE", dmg]
	if killed > 0:
		line += " %s KILLED!" % ("%d ARE" % killed if killed > 1 else "IT IS")
	Game.say(line, "ok" if killed > 0 else "")


func _cast(c: Character, n: String, t: Variant) -> void:
	var tp: String = Data.SPELLS[n][3]
	if Data.SPELL_DAMAGE.has(n):
		var gp = _target_group(t if t is int else -1)
		if gp == null:
			return
		var tg: Array = [Dice.pick(live(gp))] if tp == "mon" else live(gp)
		if n == "MOLITO":
			tg = tg.filter(func(_m): return randf() < 0.5)
		var tot := 0
		var k := 0
		for m in tg:
			var d := Dice.roll(Data.SPELL_DAMAGE[n])
			if tp == "grp" and randf() < 0.18:
				d = int(ceil(d / 2.0))
			tot += d
			if _hurt(m, d):
				k += 1
		if tg.is_empty():
			Game.say("THE SPARKS MISS EVERYONE.", "mag")
		else:
			Game.say("%s %d DAMAGE.%s" % [("%d %s TAKE" % [tg.size(), gname(gp, 2)]) if tg.size() > 1 else "%s TAKES" % a_name(gp), tot, (" %d KILLED!" % k) if k > 0 else ""], "ok" if k > 0 else "mag")
		return
	var gp2: Dictionary = groups[t] if t is int and t >= 0 and t < groups.size() else {}
	var M: Dictionary = Data.MONS[gp2["id"]] if not gp2.is_empty() else {}
	match n:
		"KATINO", "MANIFO", "MONTINO":
			var k := 0
			for m in live(gp2):
				if n == "KATINO" and not Dice.chance(M.get("sleep_res", 0)) and Dice.chance(85 - M["lv"] * 8):
					m["asleep"] = true
					k += 1
				elif n == "MANIFO" and Dice.chance(70 - M["lv"] * 6):
					m["para"] = true
					k += 1
				elif n == "MONTINO" and Dice.chance(75 - M["lv"] * 5):
					m["sil"] = true
					k += 1
			var verb: String = {"KATINO": "FALL ASLEEP", "MANIFO": "ARE HELD FAST", "MONTINO": "ARE SILENCED"}[n]
			Game.say("%d %s %s." % [k, gname(gp2, k), verb] if k > 0 else "THEY RESIST THE SPELL.", "mag")
		"DILTO":
			gp2["ac_mod"] += 2
			Game.say("DARKNESS ENGULFS THE %s." % gname(gp2, 2), "mag")
		"MORLIS":
			gp2["ac_mod"] += 3
			Game.say("THE %s TREMBLE WITH FEAR." % gname(gp2, 2), "mag")
		"MOGREF":
			c.cac += 2
			Game.say("%s IS SURROUNDED BY A SHIELD." % c.name, "mag")
		"SOPIC", "PORFIC":
			c.cac += 4
			Game.say("%s IS SURROUNDED BY A STRONG SHIELD." % c.name, "mag")
		"KALKI", "MATU", "BAMATU":
			var v: int = {"KALKI": 1, "MATU": 2, "BAMATU": 4}[n]
			for o in Game.party_chars():
				o.cac += v
			Game.say("A BLESSING SETTLES OVER THE PARTY.", "mag")
		"MAKANITO":
			var k2 := 0
			for g in groups:
				var MM: Dictionary = Data.MONS[g["id"]]
				if MM["lv"] < 8 and not MM.get("boss", false):
					for m in live(g):
						_kill(m)
						k2 += 1
			Game.say("A DEADLY WIND! %d MONSTERS DIE." % k2 if k2 > 0 else "THE WIND PASSES HARMLESSLY.", "mag")
		_:
			Spells.utility(c, n, t if t is Character else c)


func _hurt_party(t: Character, d: int) -> void:
	Game.hurt(t, d)
	if t.hp <= 0:
		t.hp = 0
		t.status = "DEAD"
		Game.say("%s IS KILLED!" % t.name, "hit")


func _luck_save(c: Character) -> bool:
	return randf() * 22.0 < c.stats["luk"] / 2.0


func _mon_act(gp: Dictionary, m: Dictionary) -> void:
	if m["dead"] or m["asleep"] or m["para"]:
		return
	var M: Dictionary = Data.MONS[gp["id"]]
	var nm := a_name(gp)
	var ps := Game.living()
	if ps.is_empty():
		return
	if M.has("sp") and not m["sil"] and randf() < (0.65 if M.get("boss", false) else 0.45):
		var sn: String = Dice.pick(M["sp"])
		Game.say("%s CASTS %s!" % [nm, sn], "hit")
		match sn:
			"HALITO", "BADIOS", "BADIAL":
				var t: Character = Dice.pick(ps)
				var d := Dice.roll(Data.SPELL_DAMAGE[sn])
				Game.say("%s TAKES %d DAMAGE." % [t.name, d], "hit")
				_hurt_party(t, d)
			"MAHALITO", "LAHALITO", "MADALTO":
				for t in ps:
					var d := Dice.roll(Data.SPELL_DAMAGE[sn])
					if _luck_save(t):
						d = int(ceil(d / 2.0))
					Game.say("%s TAKES %d DAMAGE." % [t.name, d], "hit")
					_hurt_party(t, d)
			"KATINO":
				for t in ps:
					if not Game.god_mode and t.status == "OK" and not _luck_save(t) and randf() < 0.6:
						t.status = "ASLEEP"
						Game.say("%s FALLS ASLEEP." % t.name, "hit")
			"MANIFO":
				for t in ps:
					if not Game.god_mode and t.can_act() and not _luck_save(t) and randf() < 0.3:
						t.status = "PARALYZED"
						Game.say("%s IS PARALYZED!" % t.name, "hit")
			_:
				var lv := live(gp)
				lv.sort_custom(func(a, b): return a["hp"] < b["hp"])
				lv[0]["hp"] = mini(M["hp"][1], lv[0]["hp"] + Dice.roll("2d8" if sn == "DIAL" else "1d8"))
				Game.say("%s IS HEALED." % nm)
		return
	if M.has("breath") and randf() < 0.35:
		Game.say("%s BREATHES!" % nm, "hit")
		for t in ps:
			var d := Dice.roll(M["breath"])
			if _luck_save(t):
				d = int(ceil(d / 2.0))
			Game.say("%s TAKES %d DAMAGE." % [t.name, d], "hit")
			_hurt_party(t, d)
			if not Game.god_mode and M["look"] == "cloud" and t.status == "OK" and randf() < 0.3:
				t.status = "POISON"
				Game.say("%s IS POISONED!" % t.name, "hit")
		return
	var front: Array = Game.party_chars().slice(0, 3).filter(func(c): return c.is_alive())
	var t: Character = Dice.pick(front if not front.is_empty() else ps)
	var hits := 0
	var dmg := 0
	for dice in M["atk"]:
		var need := clampi(11 - int(M["lv"]) + (10 - t.ac()) + (2 if t.parry else 0), 2, 20)
		if t.status == "ASLEEP" or t.status == "PARALYZED" or Dice.rnd(1, 20) >= need:
			hits += 1
			var d := Dice.roll(dice)
			dmg += d
			Game.hurt(t, d)
	if hits == 0:
		Game.say("%s ATTACKS %s AND MISSES." % [nm, t.name])
		return
	Game.say("%s HITS %s %s FOR %d DAMAGE." % [nm, t.name, "%d TIMES" % hits if hits > 1 else "ONCE", dmg], "hit")
	if t.hp <= 0:
		t.hp = 0
		t.status = "DEAD"
		Game.say("%s IS KILLED!" % t.name, "hit")
		return
	if Game.god_mode:
		return
	if M.get("poison", false) and t.status == "OK" and randf() < 0.33:
		t.status = "POISON"
		Game.say("%s IS POISONED!" % t.name, "hit")
	if M.get("para", false) and t.status != "PARALYZED" and randf() < 0.2:
		t.status = "PARALYZED"
		Game.say("%s IS PARALYZED!" % t.name, "hit")


# ---------- spoils ----------
## Awards experience; returns gold found. Experience is divided among the survivors.
func award() -> int:
	var z: int = Game.pos["z"]
	var xp := 0
	var gold := 0
	for gp in groups:
		for m in gp["ms"]:
			if m["dead"] and not m["disp"]:
				xp += int(Data.MONS[gp["id"]]["xp"])
				gold += Dice.rnd(0, 6 * z + int(Data.MONS[gp["id"]]["lv"]) * 4)
	var surv := Game.living()
	var each := xp / maxi(1, surv.size())
	for c in surv:
		c.xp += each
	_cleanup()
	Game.say("FOR SURVIVING, EACH ADVENTURER GETS %d EXPERIENCE POINTS." % each, "ok")
	return gold

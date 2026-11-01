class_name Spells
## Spells and item effects that work both in camp and in combat (healing, cures, light, shields).


static func heal_dice(n: String) -> String:
	return {"DIOS": "1d8", "DIAL": "2d8", "DIALMA": "3d8"}.get(n, "")


## Applies a non-combat spell. Returns "dumapic" when the caller should show the position screen.
static func utility(caster: Character, n: String, t: Character) -> String:
	if t == null:
		t = caster
	var hd := heal_dice(n)
	if hd != "":
		if not t.is_alive():
			Game.say("%s IS BEYOND SUCH HEALING." % t.name)
			return ""
		var h := Dice.roll(hd)
		t.hp = mini(t.maxhp, t.hp + h)
		Game.say("%s IS HEALED %d POINTS. (%d/%d)" % [t.name, h, t.hp, t.maxhp], "ok")
		return ""
	match n:
		"DIALKO":
			if t.status == "ASLEEP" or t.status == "PARALYZED":
				t.status = "OK"
				Game.say("%s IS RESTORED." % t.name, "ok")
			else:
				Game.say("NOTHING HAPPENS.")
		"LATUMOFIS":
			if t.status == "POISON":
				t.status = "OK"
				Game.say("THE POISON LEAVES %s." % t.name, "ok")
			else:
				Game.say("NOTHING HAPPENS.")
		"DI":
			if t.status != "DEAD":
				Game.say("NOTHING HAPPENS.")
			elif Dice.chance(40 + t.stats["vit"] * 3):
				t.status = "OK"
				t.hp = 1
				t.stats["vit"] = maxi(3, t.stats["vit"] - 1)
				Game.say("%s LIVES AGAIN!" % t.name, "ok")
			else:
				t.status = "ASHES"
				Game.say("THE SPELL FAILS. %s CRUMBLES TO ASHES!" % t.name, "hit")
		"MILWA":
			Game.light = maxi(Game.light, 40)
			Game.say("A SOFT LIGHT FILLS THE CORRIDOR.", "mag")
		"LOMILWA":
			Game.light = 9999
			Game.say("A BRIGHT, LASTING LIGHT SURROUNDS THE PARTY.", "mag")
		"LATUMAPIC":
			Game.latumapic = true
			Game.say("YOUR EYES ARE OPENED TO THE TRUE NATURE OF THINGS.", "mag")
		"MAPORFIC":
			Game.maporfic = 2
			Game.say("A SHIMMERING SHIELD SURROUNDS THE PARTY.", "mag")
		"DUMAPIC":
			return "dumapic"
	return ""


## Spends one charge of a usable item. Potions and scrolls vanish; rods and staffs may break.
static func use_charge(c: Character, it: Dictionary) -> void:
	it["known"] = true
	it["ch"] = int(it.get("ch", 1)) - 1
	var d: Dictionary = Data.ITEMS[it["id"]]
	var max_ch: int = d.get("ch", 1)
	if it["ch"] <= 0 or (max_ch > 1 and randf() < 0.08):
		if d["slot"] == "U" and max_ch == 1:
			c.items.erase(it)
		else:
			it["broken"] = true
			Game.say("THE %s BREAKS!" % d["name"], "hit")

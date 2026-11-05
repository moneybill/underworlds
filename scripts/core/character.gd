class_name Character
extends RefCounted
## One adventurer on the roster. Plain data plus the rules that belong to a single character.

const DEAD_STATES := ["DEAD", "ASHES", "LOST"]
const PORTRAIT_FILE := "res://assets/images/portraits/%s.webp"
const SPELL_FAVORITES := ["MAGE", "PRIEST", "BISHOP"]  # their bios name a favorite spell, not a weapon
const BARE_HANDS := "BARE HANDS"
const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

var id := 0
var name := ""
var race := "HUMAN"
var sex := "MALE"
var portrait := ""  # a name from Data.portraits()
var align := "GOOD"
var cls := "FIGHTER"
var lvl := 1
var xp := 0
var age := 18 * 52  # in weeks
var status := "OK"  # OK, POISON, ASLEEP, PARALYZED, DEAD, ASHES, LOST
var loc := "CASTLE"  # CASTLE, MAZE, or OUT for the dead of a wiped party, where they fell
var gold := 0
var hp := 1
var maxhp := 1
var stats := {"str": 8, "iq": 8, "pie": 8, "vit": 8, "agi": 8, "luk": 8}
var items: Array = []  # each: {id, eq, known, cursed, bad, broken, ch}
var spells: Array = []
var sp := {"M": [0, 0, 0, 0, 0, 0, 0], "P": [0, 0, 0, 0, 0, 0, 0]}
var honor := false
var mercenary := false  # hired over a round of drinks, and doesn't raise the level of the next one
# for the bio
var last_level_date := ""  # as the player's calendar read
var weapon_damage := {}  # total damage done, by what the weapon is called
var spell_damage := {}  # and by spell
var kills := {}  # by monster id
var maze_trips := 0
var gold_found := 0
var items_found := 0
# combat-only
var cac := 0
var parry := false


func his() -> String:
	return "HER" if sex == "FEMALE" else "HIS"


func he_word() -> String:
	return "She" if sex == "FEMALE" else "He"


func his_word() -> String:
	return "Her" if sex == "FEMALE" else "His"


func him() -> String:
	return "HER" if sex == "FEMALE" else "HIM"


## The portrait's file, or "" when this character has none.
func portrait_path() -> String:
	var path := PORTRAIT_FILE % portrait
	return path if portrait != "" and ResourceLoader.exists(path) else ""


# ---------- bonuses ----------
static func str_bonus(s: int) -> int:
	if s <= 5: return -2
	if s <= 7: return -1
	if s >= 18: return 3
	if s >= 17: return 2
	if s >= 16: return 1
	return 0


static func vit_bonus(v: int) -> int:
	if v <= 3: return -2
	if v <= 5: return -1
	if v >= 18: return 3
	if v >= 17: return 2
	if v >= 16: return 1
	return 0


static func agi_init(a: int) -> int:
	if a <= 5: return 2
	if a <= 7: return 1
	if a >= 18: return -3
	if a >= 17: return -2
	if a >= 15: return -1
	return 0


## Classes these statistics and alignment qualify for.
static func eligible(st: Dictionary, al: String) -> Array:
	var out := []
	for k in Data.CLASSES:
		var c: Dictionary = Data.CLASSES[k]
		if not String(c["al"]).contains(al.substr(0, 1)):
			continue
		var ok := true
		for s in c["req"]:
			if st[s] < c["req"][s]:
				ok = false
		if ok:
			out.append(k)
	return out


# ---------- state ----------
func cdata() -> Dictionary: return Data.CLASSES[cls]
func is_alive() -> bool: return not DEAD_STATES.has(status)
func can_act() -> bool: return status == "OK" or status == "POISON"
func s(stat: String) -> int: return stats[stat]


func item_def(i: Dictionary) -> Dictionary:
	return Data.ITEMS[i["id"]]


func item_name(i: Dictionary) -> String:
	var d := item_def(i)
	var n: String = d["name"] if i.get("known", false) else d["unk"] + "?"
	return n + (" (BROKEN)" if i.get("broken", false) else "")


## The picture shown left of item_name, or "" for none. It keeps an unknown item's secret too.
func item_icon(i: Dictionary) -> String:
	return Data.item_icon(i["id"], i.get("known", false))


func can_use(i: Dictionary) -> bool:
	return String(item_def(i)["cls"]).contains(cdata()["l"])


func equipped(slot: String) -> Variant:
	for i in items:
		if i["eq"] and item_def(i)["slot"] == slot:
			return i
	return null


func add_item(item_id: String, known: bool) -> bool:
	if items.size() >= 8:
		return false
	items.append({"id": item_id, "eq": false, "known": known, "cursed": false, "bad": false, "broken": false,
		"ch": Data.ITEMS[item_id].get("ch", 0)})
	return true


## The sum of one bonus (like "dispel" or "pick") over everything worn.
func worn_bonus(key: String) -> int:
	var total := 0
	for i in items:
		if i["eq"]:
			total += int(item_def(i).get(key, 0))
	return total


func ac() -> int:
	var a := 10
	for i in items:
		if i["eq"]:
			a -= int(item_def(i).get("ac", 0))
			if i.get("bad", false):
				a += 2
	if cdata().get("ninja", false) and equipped("A") == null and equipped("S") == null:
		a -= lvl / 3 + 2
	a -= cac
	if loc == "MAZE":
		a -= Game.maporfic
	return a


# ---------- spells ----------
func max_spell_lvl(school: String) -> int:
	var cfg = cdata().get(school)
	if cfg == null or lvl < cfg[0]:
		return 0
	return mini(7, 1 + (lvl - cfg[0]) / cfg[1])


func knows_at(school: String, l: int) -> int:
	var n := 0
	for sn in spells:
		if Data.SPELLS[sn][0] == school and Data.SPELLS[sn][1] == l:
			n += 1
	return n


func learn_spells(first: bool) -> Array:
	var learned := []
	for school in ["M", "P"]:
		var ml := max_spell_lvl(school)
		for l in range(1, 8):
			var pool := []
			for sn in Data.spells_at(school, l):
				if not spells.has(sn):
					pool.append(sn)
			if pool.is_empty():
				continue
			var known := knows_at(school, l)
			var smart: int = stats["iq"] if school == "M" else stats["pie"]
			if l <= ml and known == 0:
				learned.append(pool.pop_front())
				if first and not pool.is_empty():
					learned.append(pool.pop_front())
			elif (l <= ml or known > 0) and randf() < 0.25 + smart / 40.0:
				learned.append(Dice.pick(pool))
	var fresh := []
	for sn in learned:
		if not spells.has(sn):
			spells.append(sn)
			fresh.append(sn)
	return fresh


func reset_sp() -> void:
	for school in ["M", "P"]:
		var ml := max_spell_lvl(school)
		var cfg = cdata().get(school)
		var arr := []
		for l in range(1, 8):
			var k := knows_at(school, l)
			var extra := 0
			if ml >= l and cfg != null:
				extra = 1 + (lvl - (cfg[0] + cfg[1] * (l - 1))) / 2
			arr.append(mini(9, k + (extra if k > 0 else 0)))
		sp[school] = arr


func can_cast(sn: String) -> bool:
	return spells.has(sn) and sp[Data.SPELLS[sn][0]][Data.SPELLS[sn][1] - 1] > 0


func spend(sn: String) -> void:
	sp[Data.SPELLS[sn][0]][Data.SPELLS[sn][1] - 1] -= 1


# ---------- growth ----------
## "November 4, 2026"
static func date_today() -> String:
	var now := Time.get_date_dict_from_system()
	return "%s %d, %d" % [MONTHS[now["month"] - 1], now["day"], now["year"]]


## The key with the highest count, or "" for an empty tally. Ties go to the first alphabetically.
static func _top(tally: Dictionary) -> String:
	var best := ""
	var keys := tally.keys()
	keys.sort()
	for k in keys:
		if best == "" or tally[k] > tally[best]:
			best = k
	return best


static func add_to(tally: Dictionary, key: String, amount: int) -> void:
	tally[key] = int(tally.get(key, 0)) + amount


static func _counted(n: int, thing: String) -> String:
	return "%d %s%s" % [n, thing, "" if n == 1 else "s"]


static func _monster_plural(id: String) -> String:
	var M: Dictionary = Data.MONS[id]
	if M.has("pl"):
		return M["pl"]
	return M["n"] if String(M["n"]).ends_with("S") else M["n"] + "S"


## A short account of this character's career.
func bio() -> String:
	var kind := align.to_lower()
	var t := "%s is %s %s level %d %s." % [name, "an" if "aeiou".contains(kind.substr(0, 1)) else "a", kind, lvl, cls.to_lower()]
	t += " %s last leveled up on %s." % [name, last_level_date] if last_level_date != "" else " %s has yet to level up." % name
	var casts_best := SPELL_FAVORITES.has(cls)
	var favorite := _top(spell_damage if casts_best else weapon_damage)
	if favorite != "":
		t += " %s favorite %s is %s%s." % [his_word(), "spell" if casts_best else "weapon", "" if casts_best or favorite == BARE_HANDS else "the ", favorite.capitalize()]
	var slain := 0
	for id in kills:
		slain += int(kills[id])
	t += " %s has ventured into the maze %s and has slain %s." % [he_word(), _counted(maze_trips, "time"), _counted(slain, "creature")]
	if slain > 0:
		t += " %s is an expert at killing %s." % [he_word(), _monster_plural(_top(kills)).capitalize()]
	t += " %s has found %d gold and %s." % [he_word(), gold_found, _counted(items_found, "item")]
	return t


func level_up() -> Array:
	var out := []
	lvl += 1
	last_level_date = date_today()
	var gain := maxi(1, Dice.roll("1d%d" % cdata()["hd"]) + vit_bonus(stats["vit"]))
	maxhp += gain
	hp += gain
	out.append("%s MADE LEVEL %d!" % [name, lvl])
	out.append("YOU GAINED %d HIT POINTS." % gain)
	var old := age / 52 >= 50
	for st in Data.STATS:
		if randf() < 0.55:
			if randf() < (0.35 if old else 0.8):
				if stats[st] < 18:
					stats[st] += 1
					out.append("YOU GAINED " + Data.STAT_NAMES[st])
			elif stats[st] > 3:
				stats[st] -= 1
				out.append("YOU LOST " + Data.STAT_NAMES[st])
	var learned := learn_spells(false)
	if not learned.is_empty():
		out.append("YOU LEARNED NEW SPELLS: " + ", ".join(learned))
	reset_sp()
	return out


func change_class(new_cls: String) -> void:
	cls = new_cls
	lvl = 1
	xp = 0
	for st in Data.STATS:
		stats[st] = Data.RACES[race][st]
	for i in items:
		if not i["cursed"]:
			i["eq"] = false
	age += 52 * Dice.rnd(1, 3)
	learn_spells(false)
	reset_sp()


# ---------- save / load ----------
func to_dict() -> Dictionary:
	return {"id": id, "name": name, "race": race, "sex": sex, "portrait": portrait, "align": align, "cls": cls, "lvl": lvl, "xp": xp, "age": age,
		"status": status, "loc": loc, "gold": gold, "hp": hp, "maxhp": maxhp, "stats": stats, "items": items,
		"spells": spells, "sp": sp, "honor": honor, "mercenary": mercenary, "last_level_date": last_level_date, "weapon_damage": weapon_damage, "spell_damage": spell_damage,
		"kills": kills, "maze_trips": maze_trips, "gold_found": gold_found, "items_found": items_found}


## Saved numbers come back as floats.
static func _tally(saved: Dictionary) -> Dictionary:
	var out := {}
	for k in saved:
		out[String(k)] = int(saved[k])
	return out


static func from_dict(d: Dictionary) -> Character:
	var c := Character.new()
	for k in ["name", "race", "align", "cls", "status", "loc"]:
		c.set(k, String(d[k]))
	for k in ["id", "lvl", "xp", "age", "gold", "hp", "maxhp"]:
		c.set(k, int(d[k]))
	for st in Data.STATS:
		c.stats[st] = int(d["stats"][st])
	c.items = []
	for i in d["items"]:
		var it: Dictionary = i.duplicate()
		it["ch"] = int(it.get("ch", 0))
		c.items.append(it)
	c.spells = Array(d["spells"])
	for school in ["M", "P"]:
		c.sp[school] = []
		for v in d["sp"][school]:
			c.sp[school].append(int(v))
	c.honor = bool(d.get("honor", false))
	c.mercenary = bool(d.get("mercenary", false))
	c.last_level_date = String(d.get("last_level_date", ""))  # older saves have none of these
	c.weapon_damage = _tally(d.get("weapon_damage", {}))
	c.spell_damage = _tally(d.get("spell_damage", {}))
	c.kills = _tally(d.get("kills", {}))
	c.maze_trips = int(d.get("maze_trips", 0))
	c.gold_found = int(d.get("gold_found", 0))
	c.items_found = int(d.get("items_found", 0))
	c.sex = String(d.get("sex", "MALE"))
	c.portrait = String(d.get("portrait", ""))
	if c.portrait_path() == "":  # older saves have none
		c.portrait = Data.portraits(c.sex)[0]
	return c

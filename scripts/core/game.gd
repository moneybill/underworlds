extends Node
## Global game state, autoloaded as `Game`. Holds the roster, the party, the party's position
## in the Maze, Boltac's stock, and expedition-long spell effects. Saves to user://.

signal logged(text: String, kind: String)

const SAVE_PATH := "user://underworlds2_save.json"

var save_path := SAVE_PATH  # tests point this elsewhere
const MAZE_LEVELS := 4

var roster: Array[Character] = []
var party: Array[int] = []
var pos := {"x": 0, "y": 0, "z": 1, "d": 0}
var mode := "castle"  # castle, camp, maze, combat
var next_id := 1
var stock := {}
var outs: Array = []  # stranded parties: {ids: [], pos: {}}
var light := 0  # steps of MILWA left; 9999 = LOMILWA
var maporfic := 0
var latumapic := false
var cleared := {}  # lairs cleared this expedition
var seen := {}  # "z" -> {"x,y": true}, the player's map notes
var won := false
var show_map := false
var levels: Array = []  # MazeLevel per depth, index 1..MAZE_LEVELS


func _ready() -> void:
	reset_state()
	build_levels()


func reset_state() -> void:
	roster.clear()
	party.clear()
	pos = {"x": 0, "y": 0, "z": 1, "d": 0}
	mode = "castle"
	next_id = 1
	stock = Data.SHOP_START.duplicate()
	outs = []
	light = 0
	maporfic = 0
	latumapic = false
	cleared = {}
	seen = {}
	won = false
	show_map = false


func build_levels() -> void:
	levels = [null]
	var start := Vector2i(0, 0)
	for z in range(1, MAZE_LEVELS + 1):
		var lv := MazeGen.generate(z, start, MAZE_LEVELS)
		levels.append(lv)
		start = lv.down


func say(text: String, kind: String = "") -> void:
	logged.emit(text, kind)


# ---------- roster & party ----------
func ch(cid: int) -> Character:
	for c in roster:
		if c.id == cid:
			return c
	return null


func party_chars() -> Array[Character]:
	var out: Array[Character] = []
	for cid in party:
		var c := ch(cid)
		if c != null:
			out.append(c)
	return out


func living() -> Array[Character]:
	var out: Array[Character] = []
	for c in party_chars():
		if c.is_alive():
			out.append(c)
	return out


func make_char(nm: String, race: String, al: String, st: Dictionary, cls_name: String) -> Character:
	var c := Character.new()
	c.id = next_id
	next_id += 1
	c.name = nm
	c.race = race
	c.align = al
	c.cls = cls_name
	c.age = Dice.rnd(17, 21) * 52
	c.gold = 90 + Dice.rnd(0, 75)
	c.stats = st.duplicate()
	var cd: Dictionary = Data.CLASSES[cls_name]
	c.maxhp = maxi(3, int(ceil(cd["hd"] * 0.75)) + int(cd.get("hp0", 0)) + Character.vit_bonus(st["vit"]) + Dice.rnd(0, 1))
	c.hp = c.maxhp
	c.learn_spells(true)
	c.reset_sp()
	roster.append(c)
	return c


func party_align() -> String:
	var a := ""
	for c in party_chars():
		a += c.align.substr(0, 1)
	if a.contains("G"):
		return "G"
	if a.contains("E"):
		return "E"
	return "N"


func compatible(c: Character) -> bool:
	var a := party_align()
	var b := c.align.substr(0, 1)
	return not ((a == "G" and b == "E") or (a == "E" and b == "G"))


func pool_gold(to: Character) -> void:
	for c in party_chars():
		if c != to:
			to.gold += c.gold
			c.gold = 0


func divvy() -> void:
	var ps := party_chars()
	if ps.is_empty():
		return
	var total := 0
	for c in ps:
		total += c.gold
		c.gold = 0
	var each := total / ps.size()
	for c in ps:
		c.gold = each
	ps[0].gold += total - each * ps.size()


func split_gold(amount: int) -> void:
	var surv := living()
	if amount <= 0 or surv.is_empty():
		return
	var each := amount / surv.size()
	for c in surv:
		c.gold += each
	say("EACH SURVIVOR FINDS %d GOLD PIECES." % each, "gold")


func mark_seen() -> void:
	var key := str(pos["z"])
	if not seen.has(key):
		seen[key] = {}
	seen[key]["%d,%d" % [pos["x"], pos["y"]]] = true


func level() -> MazeLevel:
	return levels[pos["z"]]


# ---------- save / load ----------
func save_game() -> void:
	var data := {"version": 1, "party": party, "pos": pos, "mode": mode, "next_id": next_id, "stock": stock, "outs": outs,
		"light": light, "maporfic": maporfic, "latumapic": latumapic, "cleared": cleared, "seen": seen, "won": won,
		"show_map": show_map, "roster": roster.map(func(c: Character): return c.to_dict())}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


## Loads the save. Returns a notice when a party was stranded in the Maze (the game closed mid-expedition).
func load_game() -> String:
	reset_state()
	if not FileAccess.file_exists(save_path):
		return ""
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return ""
	var d: Dictionary = parsed
	for cd in d.get("roster", []):
		roster.append(Character.from_dict(cd))
	for cid in d.get("party", []):
		party.append(int(cid))
	pos = _int_dict(d.get("pos", pos))
	next_id = int(d.get("next_id", 1))
	stock = {}
	for k in d.get("stock", Data.SHOP_START):
		stock[k] = int(d["stock"][k]) if d.has("stock") else Data.SHOP_START[k]
	outs = []
	for o in d.get("outs", []):
		outs.append({"ids": o["ids"].map(func(v): return int(v)), "pos": _int_dict(o["pos"])})
	cleared = d.get("cleared", {})
	seen = d.get("seen", {})
	won = bool(d.get("won", false))
	show_map = bool(d.get("show_map", false))
	var notice := ""
	if String(d.get("mode", "castle")) != "castle" and not party.is_empty():
		outs.append({"ids": party.duplicate(), "pos": pos.duplicate()})
		for c in party_chars():
			c.loc = "OUT"
		party.clear()
		notice = "Your last expedition never came home. Those adventurers are now OUT in the Maze."
	mode = "castle"
	return notice


func _int_dict(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[k] = int(src[k])
	return out

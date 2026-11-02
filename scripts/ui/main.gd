extends Control
## Root of the game. Builds the screen layout in code and runs the menu system that every
## location uses: a title, a body, and lettered options you press (B)UY style, as in the manual.

const C_BG := Color("0f1119")
const C_STONE := Color("191d29")
const C_STONE2 := Color("222738")
const C_LINE := Color("3a4159")
const C_INK := Color("eadfc4")
const C_DIM := Color("9c947f")
const C_TORCH := Color("e3a33f")
const C_BLOOD := Color("d6563f")
const C_MANA := Color("8bace6")
const C_MOSS := Color("93c07e")
const KIND_COLORS := {"hit": "d6563f", "mag": "8bace6", "gold": "e3a33f", "ok": "93c07e", "": "9c947f"}

var town: TownScreens
var chars: CharScreens
var mz: MazeScreens
var fight: CombatScreens

var view: MazeView
var title: TitleScreen
var scr: Dictionary = {}
var _where: Label
var _title: Label
var _body: RichTextLabel
var _widget_box: VBoxContainer
var _entry: LineEdit
var _opts_flow: HFlowContainer
var _opts_col: VBoxContainer
var _log: RichTextLabel
var _party: RichTextLabel
var _pad: GridContainer
var mono: Font
var display: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_fonts()
	theme = _build_theme()
	_build_layout()
	town = TownScreens.new(self)
	chars = CharScreens.new(self)
	mz = MazeScreens.new(self)
	fight = CombatScreens.new(self)
	Game.logged.connect(log_line)
	title = TitleScreen.new(display, mono)
	title.venture.connect(_venture_onwards)
	add_child(title)


## Title screen's "Venture Onwards": pick up from the last save, or start fresh at the Castle.
func _venture_onwards() -> void:
	var where := Game.load_game()
	title.queue_free()
	title = null
	match where:
		"camp":
			Game.say("YOUR PARTY STIRS BESIDE THE CAMP FIRE.")
			mz.camp()
		"new":
			town.castle()
			say("Welcome to the Proving Grounds", "Trebor, the Mad Overlord, wants his amulet back from the wizard Werdna, who hides at the bottom of the maze beneath the castle.\n\n" +
				"Start at the [color=#e3a33f]Edge of Town[/color]: open the [color=#e3a33f]Training Grounds[/color] and create six adventurers. Hawkwind recommends two fighters, a priest, a thief and two mages.\n\n" +
				"Then gather them at Gilgamesh's Tavern, outfit them at Boltac's, and enter the Maze. Run home often.", town.castle)
		_:
			town.castle()


# ---------- look & feel ----------
func _build_fonts() -> void:
	mono = _font_or_system("res://fonts/VT323-Regular.ttf", ["VT323", "Menlo", "Consolas", "Courier New", "monospace"])
	display = _font_or_system("res://fonts/IMFellEnglishSC-Regular.ttf", ["IM Fell English SC", "Georgia", "Times New Roman", "serif"])


func _font_or_system(path: String, names: Array) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	return f


func _box(bg: Color, border: Color, pad := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(pad)
	return sb


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = mono
	t.default_font_size = 22
	t.set_color("font_color", "Label", C_INK)
	t.set_color("default_color", "RichTextLabel", C_INK)
	for st in ["normal", "focus"]:
		t.set_stylebox(st, "Button", _box(C_STONE2, C_LINE, 7))
	t.set_stylebox("hover", "Button", _box(C_STONE2, C_DIM, 7))
	t.set_stylebox("pressed", "Button", _box(C_TORCH, C_TORCH, 7))
	t.set_stylebox("disabled", "Button", _box(C_STONE, C_STONE2, 7))
	t.set_color("font_color", "Button", C_INK)
	t.set_color("font_hover_color", "Button", C_INK)
	t.set_color("font_pressed_color", "Button", C_BG)
	t.set_color("font_disabled_color", "Button", Color(C_INK, 0.35))
	t.set_stylebox("normal", "LineEdit", _box(C_BG, C_LINE, 6))
	t.set_stylebox("focus", "LineEdit", _box(C_BG, C_TORCH, 6))
	t.set_color("font_color", "LineEdit", C_INK)
	t.set_stylebox("panel", "PanelContainer", _box(C_STONE, C_LINE, 14))
	return t


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	var h1 := Label.new()
	h1.text = "Underworlds 2"
	h1.add_theme_font_override("font", display)
	h1.add_theme_font_size_override("font_size", 38)
	h1.add_theme_color_override("font_color", C_TORCH)
	header.add_child(h1)
	var sub := Label.new()
	sub.text = "  PROVING GROUNDS OF THE MAD OVERLORD"
	sub.add_theme_color_override("font_color", C_DIM)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sub)
	_where = Label.new()
	_where.add_theme_color_override("font_color", C_DIM)
	header.add_child(_where)
	root.add_child(header)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 14)
	root.add_child(main)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 4.0 / 3.0
	aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect.size_flags_stretch_ratio = 1.1
	main.add_child(aspect)
	view = MazeView.new()
	view.mono = mono
	aspect.add_child(view)
	_pad = GridContainer.new()
	_pad.columns = 3
	_pad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_pad.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pad.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pad.position = Vector2(-10, -10)
	for spec in [["◄", "A"], ["▲", "W"], ["►", "D"], ["", ""], ["▼", "X"], ["", ""]]:
		if spec[0] == "":
			_pad.add_child(Control.new())
			continue
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(52, 46)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pad_press.bind(spec[1]))
		_pad.add_child(b)
	view.add_child(_pad)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)
	_title = Label.new()
	_title.add_theme_font_override("font", display)
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", C_TORCH)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.add_child(_title)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.selection_enabled = true
	pv.add_child(_body)
	_widget_box = VBoxContainer.new()
	pv.add_child(_widget_box)
	_entry = LineEdit.new()
	_entry.text_submitted.connect(_on_input_submitted)
	pv.add_child(_entry)
	_opts_flow = HFlowContainer.new()
	_opts_flow.add_theme_constant_override("h_separation", 6)
	_opts_flow.add_theme_constant_override("v_separation", 6)
	pv.add_child(_opts_flow)
	_opts_col = VBoxContainer.new()
	pv.add_child(_opts_col)
	var sep := HSeparator.new()
	pv.add_child(sep)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 120)
	pv.add_child(_log)

	var tbl := PanelContainer.new()
	root.add_child(tbl)
	_party = RichTextLabel.new()
	_party.bbcode_enabled = true
	_party.fit_content = true
	_party.scroll_active = false
	tbl.add_child(_party)
	var foot := Label.new()
	foot.text = "Press the letter before the ) or click a command. In the Maze: W step forward, A/D turn, X about-face."
	foot.add_theme_color_override("font_color", C_DIM)
	foot.add_theme_font_size_override("font_size", 18)
	root.add_child(foot)


# ---------- the menu system ----------
## s: {title, where, body (bbcode), opts: [{k, label, fn, def, esc, dis, hide, right}], col,
##     input: {ph, max, fn}, keys: {key: Callable}, view, pad, widget: Control}
func show_screen(s: Dictionary) -> void:
	scr = s
	_title.text = s.get("title", "")
	if s.has("where"):
		_where.text = String(s["where"]).to_upper()
	_body.text = s.get("body", "")
	for n in _widget_box.get_children():
		n.queue_free()
	if s.has("widget"):
		_widget_box.add_child(s["widget"])
	for n in _opts_flow.get_children() + _opts_col.get_children():
		n.queue_free()
	var col: bool = s.get("col", false)
	_opts_flow.visible = not col
	_opts_col.visible = col
	for o in s.get("opts", []):
		if o.get("hide", false):
			continue
		var b := Button.new()
		b.text = _opt_text(o)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = o.get("dis", false)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if o.get("def", false):
			b.add_theme_stylebox_override("normal", _box(C_STONE2, C_TORCH, 7))
		b.pressed.connect(_run.bind(o))
		(_opts_col if col else _opts_flow).add_child(b)
	_entry.visible = s.has("input")
	if s.has("input"):
		_entry.text = s["input"].get("val", "")
		_entry.placeholder_text = s["input"].get("ph", "")
		_entry.max_length = s["input"].get("max", 15)
		_entry.call_deferred("grab_focus")
	else:
		_entry.release_focus()
	_pad.visible = s.get("pad", false)
	view.show_view(s.get("view", view.kind))
	render_party()


func _opt_text(o: Dictionary) -> String:
	var k: String = o["k"]
	var label: String = String(o["label"]).to_upper()
	var t := ""
	if k.length() == 1 and label.begins_with(k.to_upper()):
		t = k.to_upper() + ")" + label.substr(1)
	elif k.length() == 1:
		t = k.to_upper() + ") " + label
	else:
		t = "[" + k.to_upper() + "] " + label
	if o.has("right") and String(o["right"]) != "":
		t += "   " + String(o["right"])
	return t


func _run(o: Dictionary) -> void:
	if o.get("dis", false):
		return
	var f: Callable = o.get("fn", Callable())
	if f.is_valid():
		f.call()


func rerender() -> void:
	show_screen(scr)


func _on_input_submitted(text: String) -> void:
	if scr.has("input"):
		var f: Callable = scr["input"]["fn"]
		f.call(text.strip_edges().to_upper())


func _pad_press(k: String) -> void:
	var keys: Dictionary = scr.get("keys", {})
	if keys.has(k):
		keys[k].call()


func _input(event: InputEvent) -> void:
	if title != null:
		return  # the title screen handles its own input
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var ke := event as InputEventKey
	if ke.ctrl_pressed or ke.meta_pressed or ke.alt_pressed:
		return
	var key := OS.get_keycode_string(ke.keycode)
	if key.begins_with("Kp "):
		key = key.substr(3)
	if key == "Kp Enter":
		key = "Enter"
	var ch := char(ke.unicode) if ke.unicode > 0 else ""
	if _entry.has_focus():
		if key == "Escape":
			_press_flag("esc")
			get_viewport().set_input_as_handled()
		return
	var keys: Dictionary = scr.get("keys", {})
	for cand in [key, ch]:
		if cand != "" and keys.has(cand):
			get_viewport().set_input_as_handled()
			keys[cand].call()
			return
	if key == "Enter":
		_press_flag("def")
	elif key == "Escape":
		_press_flag("esc")
	else:
		for o in scr.get("opts", []):
			if o.get("hide", false) or o.get("dis", false):
				continue
			var ok: String = String(o["k"]).to_upper()
			if ok == key.to_upper() or (ch != "" and ok == ch.to_upper()):
				get_viewport().set_input_as_handled()
				_run(o)
				return
		return
	get_viewport().set_input_as_handled()


func _press_flag(flag: String) -> void:
	for o in scr.get("opts", []):
		if o.get(flag, false) and not o.get("dis", false) and not o.get("hide", false):
			_run(o)
			return


# ---------- helpers every screen uses ----------
func esc(t: String) -> String:
	return t.replace("[", "[lb]")


func flav(t: String) -> String:
	return "[color=#9c947f][i]" + t + "[/i][/color]"


func say(title: String, body: String, next: Callable, where := "") -> void:
	var s := {"title": title, "body": body, "opts": [{"k": "Enter", "label": "CONTINUE", "def": true, "esc": true, "fn": next}]}
	if where != "":
		s["where"] = where
	show_screen(s)


func yesno(title: String, body: String, yes: Callable, no: Callable) -> void:
	show_screen({"title": title, "body": body, "opts": [
		{"k": "Y", "label": "YES", "fn": yes},
		{"k": "N", "label": "NO", "def": true, "esc": true, "fn": no}]})


## items: [{label, fn, dis, right}] become numbered options 1..9.
func choose_list(title: String, body: String, items: Array, back: Callable, extra: Array = []) -> void:
	var opts := []
	for i in items.size():
		var it: Dictionary = items[i]
		opts.append({"k": str(i + 1), "label": it["label"], "fn": it["fn"], "dis": it.get("dis", false), "right": it.get("right", "")})
	opts.append_array(extra)
	opts.append({"k": "L", "label": "LEAVE", "esc": true, "fn": back})
	show_screen({"title": title, "body": body, "opts": opts, "col": true})


func pick_member(title: String, back: Callable, fn: Callable, filter := Callable()) -> void:
	var items := []
	for c in Game.party_chars():
		var right: String = c.status if c.status != "OK" else "%d GP" % c.gold
		items.append({"label": c.name, "right": right, "fn": fn.bind(c), "dis": filter.is_valid() and not filter.call(c)})
	choose_list(title, "Who?", items, back)


func log_line(text: String, kind := "") -> void:
	_log.append_text("[color=#%s]%s[/color]\n" % [KIND_COLORS.get(kind, "9c947f"), esc(text)])


func clear_log() -> void:
	_log.clear()


func render_party() -> void:
	var ps := Game.party_chars()
	if ps.is_empty():
		_party.text = "[color=#9c947f]NO PARTY FORMED. VISIT GILGAMESH'S TAVERN TO GATHER ADVENTURERS.[/color]"
		return
	var t := "[table=6][cell][color=#9c947f]#  [/color][/cell][cell][color=#9c947f]CHARACTER NAME     [/color][/cell][cell][color=#9c947f]CLASS   [/color][/cell]" + \
		"[cell][color=#9c947f]  AC[/color][/cell][cell][color=#9c947f]    HITS[/color][/cell][cell][color=#9c947f]   STATUS[/color][/cell]"
	for i in ps.size():
		var c: Character = ps[i]
		var col := "eadfc4" if i < 3 else "9c947f"
		var st := c.status
		var sc: String = {"OK": col, "POISON": "93c07e", "ASLEEP": "8bace6"}.get(st, "d6563f")
		t += "[cell][color=#%s]%d[/color][/cell][cell][color=#%s]%s%s[/color][/cell][cell][color=#%s]%s-%s[/color][/cell]" % [col, i + 1, col, esc(c.name), " &" if c.honor else "", col, c.align.substr(0, 1), c.cdata()["ab"]]
		t += "[cell][color=#%s]%4d[/color][/cell][cell][color=#%s]%8s[/color][/cell][cell][color=#%s]   %s[/color][/cell]" % [col, c.ac(), col, "%d/%d" % [c.hp, c.maxhp], sc, st]
	_party.text = t + "[/table]"


func sheet(c: Character) -> String:
	var nx := Data.xp_needed(c.cls, c.lvl)
	var t := "[color=#e3a33f]%s  L %d  %s-%s-%s[/color]\n" % [esc(c.name), c.lvl, c.align.substr(0, 1), c.race, c.cls]
	t += "[table=3]"
	for st in Data.STATS:
		t += "[cell][color=#9c947f]%s[/color] %d   [/cell]" % [Data.STAT_NAMES[st], c.stats[st]]
	t += "[cell][color=#9c947f]GOLD[/color] %d   [/cell][cell][color=#9c947f]EXP[/color] %d   [/cell][cell][color=#9c947f]NEXT[/color] %d[/cell]" % [c.gold, c.xp, nx]
	t += "[cell][color=#9c947f]AGE[/color] %d   [/cell][cell][color=#9c947f]HITS[/color] %d/%d   [/cell][cell][color=#9c947f]AC[/color] %d[/cell]" % [c.age / 52, c.hp, c.maxhp, c.ac()]
	t += "[cell][color=#9c947f]STATUS[/color] %s   [/cell][cell][color=#9c947f]MAGE[/color] %s   [/cell][cell][color=#9c947f]PRIEST[/color] %s[/cell][/table]\n" % [c.status, "/".join(c.sp["M"].map(func(v): return str(v))), "/".join(c.sp["P"].map(func(v): return str(v)))]
	if c.items.is_empty():
		t += "[color=#9c947f]NO ITEMS[/color]"
	for i in c.items.size():
		var it: Dictionary = c.items[i]
		var sym := ("*" if it["eq"] else "") + ("" if c.can_use(it) else "#") + ("" if it["known"] else "?") + ("-" if it["eq"] and it["cursed"] else "")
		t += "%d)%s %s\n" % [i + 1, sym if sym != "" else " ", esc(c.item_name(it))]
	return t

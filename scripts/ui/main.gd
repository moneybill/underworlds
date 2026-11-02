extends Control
## Root of the game. Builds the screen layout in code and runs the menu system that every
## location uses: a title, a body, and options to click or tap.

const KIND_COLORS := {"hit": "d6563f", "mag": "8bace6", "gold": "e3a33f", "ok": "93c07e", "": "9c947f"}
const PORTRAIT_SIZE := 300.0
const BACKDROP_COLUMN := 540.0  # width of the text column over a painted backdrop, clear of its center
const BACKDROP_TABLE_FONT := 15  # lets the longest party row fit that column on one line
const LOG_HEIGHT := 120.0
const BACKDROP_LOG_HEIGHT := 50.0  # the column is short of room, and a full Inspect screen needs it

var town: TownScreens
var chars: CharScreens
var mz: MazeScreens
var fight: CombatScreens

var view: MazeView
var scr: Dictionary = {}
var _where: Label
var _title: Label
var _body: RichTextLabel
var _widget_box: VBoxContainer
var _portrait: PanelContainer
var _side: PanelContainer
var _portrait_image: TextureRect
var _entry: LineEdit
var _opts_flow: HFlowContainer
var _opts_col: VBoxContainer
var _log: RichTextLabel
var _party: RichTextLabel
var _pad: GridContainer
var town_map: TownMap
var place_image := ""  # the painting of the building the party is in; every screen shows it until cleared
var _backdrop: TextureRect
var _header: HBoxContainer
var _view_box: AspectRatioContainer
var _panel: PanelContainer
var _table: PanelContainer
var _foot: Label
var mono: Font
var display: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mono = UiStyle.mono_font()
	display = UiStyle.display_font()
	theme = UiStyle.build_theme(mono)
	_build_layout()
	town_map = TownMap.new(self)
	town_map.visible = false
	town_map.chosen.connect(_run)
	add_child(town_map)
	town = TownScreens.new(self)
	chars = CharScreens.new(self)
	mz = MazeScreens.new(self)
	fight = CombatScreens.new(self)
	Game.logged.connect(log_line)
	Game.load_game()
	if not Game.roster.is_empty():
		_resume()
	else:
		town.castle()
		say("Welcome to the Underworlds", "Trebor, the Mad Overlord, wants his amulet back from the wizard Werdna, who hides at the bottom of the maze beneath the castle.\n\n" +
			"Start at the [color=#e3a33f]Edge of Town[/color]: open the [color=#e3a33f]Training Grounds[/color] and create six adventurers. Hawkwind recommends two fighters, a priest, a thief and two mages.\n\n" +
			"Then gather them at Gilgamesh's Tavern, outfit them at Boltac's, and enter the Maze. Run home often.", town.castle)


## Returns to where the last save left the party. A fight isn't saved, so it resumes in the Maze.
func _resume() -> void:
	if Game.mode == "castle":
		town.castle()
	elif Game.living().is_empty():
		mz.wiped()
	elif Game.mode == "camp":
		mz.camp()
	else:
		mz.maze()


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = UiStyle.C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.visible = false
	add_child(_backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	_portrait = PanelContainer.new()
	_portrait.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.C_BG, UiStyle.C_LINE, 4))
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.visible = false
	add_child(_portrait)
	_portrait_image = TextureRect.new()
	_portrait_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_portrait_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.add_child(_portrait_image)
	_side = PanelContainer.new()
	_side.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.C_BG, 0.94), UiStyle.C_LINE, 14))
	_side.visible = false
	add_child(_side)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_header = HBoxContainer.new()
	var h1 := Label.new()
	h1.text = "Underworlds"
	h1.add_theme_font_override("font", display)
	h1.add_theme_font_size_override("font_size", 38)
	h1.add_theme_color_override("font_color", UiStyle.C_TORCH)
	_header.add_child(h1)
	var sub := Label.new()
	sub.text = "  DESCENT INTO DARKNESS"
	sub.add_theme_color_override("font_color", UiStyle.C_DIM)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(sub)
	_where = Label.new()
	_where.add_theme_color_override("font_color", UiStyle.C_DIM)
	_header.add_child(_where)
	root.add_child(_header)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 14)
	root.add_child(main)
	_view_box = AspectRatioContainer.new()
	_view_box.ratio = 4.0 / 3.0
	_view_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_box.size_flags_stretch_ratio = 1.1
	main.add_child(_view_box)
	view = MazeView.new()
	view.mono = mono
	_view_box.add_child(view)
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

	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.item_rect_changed.connect(_place_portrait)
	main.add_child(_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	_panel.add_child(pv)
	_title = Label.new()
	_title.add_theme_font_override("font", display)
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", UiStyle.C_TORCH)
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
	_log.custom_minimum_size = Vector2(0, LOG_HEIGHT)
	pv.add_child(_log)

	_table = PanelContainer.new()
	root.add_child(_table)
	_party = RichTextLabel.new()
	_party.bbcode_enabled = true
	_party.fit_content = true
	_party.scroll_active = false
	_table.add_child(_party)
	_foot = Label.new()
	_foot.text = "Click or tap a command. In the Maze, use the arrow buttons to move."
	_foot.add_theme_color_override("font_color", UiStyle.C_DIM)
	_foot.add_theme_font_size_override("font_size", 18)
	root.add_child(_foot)


# ---------- the menu system ----------
## s: {title, where, body (bbcode), opts: [{k (the option's id), label, fn, dis, hide, right}], col,
##     input: {ph, max, fn}, moves: {pad button: Callable}, view, pad, widget: Control, map, portrait: path, side: Control}
func show_screen(s: Dictionary) -> void:
	scr = s
	_set_backdrop(place_image)
	_set_portrait(s.get("portrait", ""))
	_set_side(s.get("side"))
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
	var opts: Array = s.get("opts", [])
	if s.has("input"):
		opts = [{"k": "OK", "label": "OK", "fn": _submit_input}] + opts
	for o in opts:
		if o.get("hide", false):
			continue
		var b := Button.new()
		b.text = _opt_text(o)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = o.get("dis", false)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	town_map.visible = s.get("map", false)
	if town_map.visible:
		town_map.show_options(s)


## With a backdrop, the painting fills the window and the text and party share a column on the left.
func _set_backdrop(path: String) -> void:
	var on := path != ""
	if on != _backdrop.visible:
		_party.text = ""  # a table keeps its old column widths unless it is rebuilt at the new size
	_backdrop.visible = on
	_backdrop.texture = load(path) if on else null
	_header.visible = not on
	_view_box.visible = not on
	_foot.visible = not on
	_log.custom_minimum_size.y = BACKDROP_LOG_HEIGHT if on else LOG_HEIGHT
	if on:
		_party.add_theme_font_size_override("normal_font_size", BACKDROP_TABLE_FONT)
	else:
		_party.remove_theme_font_size_override("normal_font_size")
	for p: PanelContainer in [_panel, _table]:
		p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if on else Control.SIZE_EXPAND_FILL
		p.custom_minimum_size.x = BACKDROP_COLUMN if on else 0.0
		if on:
			p.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.C_BG, 0.88), UiStyle.C_LINE, 8))
		else:
			p.remove_theme_stylebox_override("panel")


func _set_portrait(path: String) -> void:
	_portrait.visible = path != ""
	_portrait_image.texture = load(path) if path != "" else null
	_place_portrait()


## A popup of the screen's own beside the text panel, in the same place as a portrait.
func _set_side(content: Control) -> void:
	for n in _side.get_children():
		_side.remove_child(n)
		n.queue_free()
	_side.visible = content != null
	if content != null:
		_side.add_child(content)
		_fit_side.call_deferred()
	_place_portrait()


## Wrapped text only knows its height once it has been laid out at its width.
func _fit_side() -> void:
	await get_tree().process_frame
	_side.reset_size()


## The portrait sits beside the text panel: over the painting, or over the view on unpainted screens.
func _place_portrait() -> void:
	var r := _panel.get_global_rect()
	var x := r.end.x + 14 if _backdrop.visible else r.position.x - 14 - PORTRAIT_SIZE
	_portrait.size = Vector2.ONE * PORTRAIT_SIZE
	_portrait.global_position = Vector2(x, r.position.y)
	_side.global_position = Vector2(x, r.position.y)


func _opt_text(o: Dictionary) -> String:
	var t := String(o["label"]).to_upper()
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


func _submit_input() -> void:
	_on_input_submitted(_entry.text)


func _pad_press(k: String) -> void:
	var moves: Dictionary = scr.get("moves", {})
	if moves.has(k):
		moves[k].call()


# ---------- helpers every screen uses ----------
func esc(t: String) -> String:
	return t.replace("[", "[lb]")


func flav(t: String) -> String:
	return "[color=#9c947f][i]" + t + "[/i][/color]"


func say(title: String, body: String, next: Callable, where := "") -> void:
	var s := {"title": title, "body": body, "opts": [{"k": "Enter", "label": "CONTINUE", "fn": next}]}
	if where != "":
		s["where"] = where
	show_screen(s)


func yesno(title: String, body: String, yes: Callable, no: Callable, portrait := "") -> void:
	show_screen({"title": title, "body": body, "portrait": portrait, "opts": [
		{"k": "Y", "label": "YES", "fn": yes},
		{"k": "N", "label": "NO", "fn": no}]})


## items: [{label, fn, dis, right}] become numbered options 1..9.
func choose_list(title: String, body: String, items: Array, back: Callable, extra: Array = []) -> void:
	var opts := []
	for i in items.size():
		var it: Dictionary = items[i]
		opts.append({"k": str(i + 1), "label": it["label"], "fn": it["fn"], "dis": it.get("dis", false), "right": it.get("right", "")})
	opts.append_array(extra)
	opts.append({"k": "L", "label": "LEAVE", "fn": back})
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


## The front three party rows are bright, the back three dim.
func party_row_color(row: int) -> String:
	return "eadfc4" if row < 3 else "9c947f"


func status_color(st: String, ok_color: String) -> String:
	return {"OK": ok_color, "POISON": "93c07e", "ASLEEP": "8bace6"}.get(st, "d6563f")


func render_party() -> void:
	var ps := Game.party_chars()
	if ps.is_empty():
		_party.text = "[color=#9c947f]NO PARTY FORMED. VISIT GILGAMESH'S TAVERN TO GATHER ADVENTURERS.[/color]"
		return
	var t := "[table=6][cell][color=#9c947f]#  [/color][/cell][cell][color=#9c947f]CHARACTER NAME     [/color][/cell][cell][color=#9c947f]CLASS   [/color][/cell]" + \
		"[cell][color=#9c947f]  AC[/color][/cell][cell][color=#9c947f]    HITS[/color][/cell][cell][color=#9c947f]   STATUS[/color][/cell]"
	for i in ps.size():
		var c: Character = ps[i]
		var col := party_row_color(i)
		var st := c.status
		var sc := status_color(st, col)
		t += "[cell][color=#%s]%d[/color][/cell][cell][color=#%s]%s%s[/color][/cell][cell][color=#%s]%s-%s[/color][/cell]" % [col, i + 1, col, esc(c.name), " &" if c.honor else "", col, c.align.substr(0, 1), c.cdata()["ab"]]
		t += "[cell][color=#%s]%4d[/color][/cell][cell][color=#%s]%8s[/color][/cell][cell][color=#%s]   %s[/color][/cell]" % [col, c.ac(), col, "%d/%d" % [c.hp, c.maxhp], sc, st]
	_party.text = t + "[/table]"


func sheet(c: Character) -> String:
	var nx := Data.xp_needed(c.cls, c.lvl)
	var t := "[color=#e3a33f]%s  L %d  %s-%s-%s  %s[/color]\n" % [esc(c.name), c.lvl, c.align.substr(0, 1), c.race, c.cls, c.sex.substr(0, 1)]
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

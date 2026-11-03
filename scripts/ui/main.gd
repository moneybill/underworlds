extends Control
## Root of the game. Builds the screen layout in code and runs the menu system that every
## location uses: a title, a body, and options to click or tap.

const KIND_COLORS := {"hit": "d6563f", "mag": "8bace6", "gold": "e3a33f", "ok": "93c07e", "": "9c947f"}
const PORTRAIT_SIZE := 300.0
const BACKDROP_COLUMN := 540.0  # width of the text column over a painted backdrop, clear of its center
const GEAR_COLUMN := 600.0  # width of the party's equipment over a painting
const GEAR_PANEL_MARGIN := 8.0  # inside its panel
const CONFIRM_WIDTH := 560.0
const CONFIRM_LAYER := 100  # above the test switches
const CONFIRM_DIM := Color(0, 0, 0, 0.6)
const GEAR_HINT_FONT := 18  # four sizes under the body text
const PAGER_FONT := 18
const PAGER_FILL := Color("5a3d24")  # brown, to stand apart from the list above
const PAGER_EDGE := Color("8a6238")
const PAGER_EXIT_FILL := Color("6e2a26")  # oxblood
const PAGER_EXIT_EDGE := Color("a04a42")
const GEAR_BUTTONS_HEIGHT := 40.0  # the row under the cards keeps its height with no buttons in it
const GEAR_LEFT := 570.0  # just right of the text column
const GEAR_TOP := 46.0  # just under the test switches
const CARD_MARGIN := 16.0  # a card's edges and padding, left and right together
const BACKDROP_TABLE_FONT := 15  # lets the longest party row fit that column on one line
const LOG_HEIGHT := 120.0
const SOUND_VOICES := 4  # sounds that can overlap
const FIGHT_LOG_HEIGHT := 50.0  # room for a front row bishop's options, and a magic item
const BACKDROP_LOG_HEIGHT := 50.0  # the column is short of room, and a full Inspect screen needs it

const TURN_AROUND_ICON: Texture2D = preload("res://assets/images/rotate.png")

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
var _gear: PanelContainer
var _gear_grid: GridContainer
var _gear_row: HBoxContainer
var _exit_row: HBoxContainer
var _pager_row: HBoxContainer
var _confirm_box: Control = null
var _confirm_yes: Button
var _confirm_no: Button
var _portrait_image: TextureRect
var _portrait_tomb: TextureRect
var _entry: LineEdit
var _opts_flow: HFlowContainer
var _opts_col: VBoxContainer
var _log: RichTextLabel
var _party: RichTextLabel
var _pad: GridContainer
var _sounds: AudioStreamPlayer
var monsters_button: Button
var god_button: Button
var town_button: Button
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
	_build_test_switches()
	town = TownScreens.new(self)
	chars = CharScreens.new(self)
	mz = MazeScreens.new(self)
	fight = CombatScreens.new(self)
	_sounds = AudioStreamPlayer.new()
	_sounds.max_polyphony = SOUND_VOICES
	add_child(_sounds)
	Game.logged.connect(log_line)
	Game.load_game()
	if not Game.roster.is_empty():
		_resume()
	else:
		town.castle()
		say("Welcome to the Underworlds", "Trebor, the Mad Overlord, wants his amulet back from the wizard Werdna, who hides at the bottom of the maze beneath the castle.\n\n" +
			"Start at the [color=#e3a33f]Edge of Town[/color]: open the [color=#e3a33f]Training Grounds[/color] and create six adventurers. Hawkwind recommends two fighters, a priest, a thief and two mages.\n\n" +
			"Then gather them at Gilgamesh's Tavern, outfit them at Boltac's, and enter the Maze. Run home often.", town.castle)


## This button turns the party to face the other way, so it shows a rotate icon.
func _show_turn_around(b: Button) -> void:
	b.icon = TURN_AROUND_ICON
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = "Turn around"
	b.add_theme_constant_override("icon_max_width", 26)
	for state in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
		b.add_theme_color_override(state, UiStyle.C_INK)
	for state in ["icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(state, UiStyle.C_BG)


func widget_box() -> VBoxContainer:
	return _widget_box


## Plays a sound effect. Sounds can overlap.
func play_sound(stream: AudioStream) -> void:
	_sounds.stream = stream
	_sounds.play()


## Top middle of every screen, above the paintings.
func _build_test_switches() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	monsters_button = _test_switch(Game.monsters_on, _set_monsters)
	row.add_child(monsters_button)
	god_button = _test_switch(Game.god_mode, _set_god)
	row.add_child(god_button)
	town_button = Button.new()
	town_button.text = "TO TOWN"
	town_button.focus_mode = Control.FOCUS_NONE
	town_button.add_theme_font_size_override("font_size", 16)
	town_button.pressed.connect(_teleport_to_town)
	row.add_child(town_button)
	_show_test_switches()
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.offset_top = 10


func _test_switch(on: bool, handler: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.set_pressed_no_signal(on)
	b.toggled.connect(handler)
	return b


func _set_monsters(on: bool) -> void:
	Game.monsters_on = on
	_show_test_switches()


func _set_god(on: bool) -> void:
	Game.god_mode = on
	_show_test_switches()


## Brings the party home at once, from anywhere in the Maze and even mid-fight, as if it had walked out.
func _teleport_to_town() -> void:
	fight.battle = null
	view.battle = null
	town.return_to_castle()


func _show_test_switches() -> void:
	town_button.disabled = Game.mode == "castle" or Game.party.is_empty()
	monsters_button.text = "MONSTERS: %s" % ("ON" if Game.monsters_on else "OFF")
	god_button.text = "GOD MODE: %s" % ("ON" if Game.god_mode else "OFF")


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
	_portrait_tomb = UiStyle.add_tombstone(_portrait_image)
	_side = PanelContainer.new()
	_side.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.C_BG, 0.94), UiStyle.C_LINE, 14))
	_side.visible = false
	add_child(_side)
	_gear = PanelContainer.new()
	_gear.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.C_BG, 0.88), UiStyle.C_LINE, int(GEAR_PANEL_MARGIN)))
	_gear.position = Vector2(GEAR_LEFT, GEAR_TOP)
	_gear.custom_minimum_size.x = GEAR_COLUMN
	_gear.visible = false
	add_child(_gear)
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
	for spec in [["◄", "A"], ["▲", "W"], ["►", "D"], ["", ""], ["", "X"], ["", ""]]:
		if spec[1] == "":
			_pad.add_child(Control.new())
			continue
		var b := Button.new()
		b.text = spec[0]
		if spec[1] == "X":
			_show_turn_around(b)
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
	_exit_row = HBoxContainer.new()  # under the text at the right, on screens with the party's cards
	_exit_row.alignment = BoxContainer.ALIGNMENT_END
	pv.add_child(_exit_row)
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
##     party_grid: the widget shows the party, so the party table hides,
##     input: {ph, max, fn}, moves: {pad button: Callable}, view, pad, widget: Control, map, portrait: path, side: Control}
func show_screen(s: Dictionary) -> void:
	_close_confirm()
	scr = s
	_set_backdrop(place_image)
	_set_portrait(s.get("portrait", ""))
	_portrait_tomb.visible = s.get("portrait_dead", false)
	_set_side(s.get("side"))
	_title.text = s.get("title", "")
	if s.has("where"):
		_where.text = String(s["where"]).to_upper()
	_body.text = s.get("body", "")
	for n in _widget_box.get_children():
		n.queue_free()
	if s.has("widget"):
		_widget_box.add_child(s["widget"])
	# A screen with its own portrait, like Inspect, keeps that spot for it.
	var gear: bool = TownScreens.GEAR_PLACES.has(place_image) and s.get("portrait", "") == ""
	for n in _opts_flow.get_children() + _opts_col.get_children():
		n.queue_free()
	var col: bool = s.get("col", false)
	_opts_flow.visible = not col
	_opts_col.visible = col
	var opts: Array = s.get("opts", [])
	if s.has("input"):
		opts = [{"k": "OK", "label": "OK", "fn": _submit_input}] + opts
	for o in opts:
		if o.has("pager"):
			continue  # these share the row under the list
		if o.get("hide", false) or o.get("in_widget", false) or (gear and _is_exit(o)):
			continue  # an in_widget option has its button in the screen's widget instead, and EXIT has its own place
		var b := Button.new()
		b.text = _opt_text(o)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = o.get("dis", false)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_run.bind(o))
		(_opts_col if col else _opts_flow).add_child(b)
	_pager_row = null
	if opts.any(func(o): return o.has("pager")):
		_pager_row = _pager_buttons(opts)
		_opts_col.add_child(_pager_row)
	_entry.visible = s.has("input")
	if s.has("input"):
		_entry.text = s["input"].get("val", "")
		_entry.placeholder_text = s["input"].get("ph", "")
		_entry.max_length = s["input"].get("max", 15)
		_entry.call_deferred("grab_focus")
	else:
		_entry.release_focus()
	_pad.visible = s.get("pad", false)
	_table.visible = not s.has("party_grid") and not gear
	for n in _gear.get_children():
		n.queue_free()
	_gear.visible = gear
	if gear:
		var gear_box := VBoxContainer.new()
		_gear.add_child(gear_box)
		if s.has("gear_hint"):
			var hint := Label.new()
			hint.text = s["gear_hint"]
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.add_theme_font_size_override("font_size", GEAR_HINT_FONT)
			gear_box.add_child(hint)
		_gear_grid = town.gear_grid(s.get("gear_pick", Callable()), not s.get("gear_skip_dead", false))
		gear_box.add_child(_gear_grid)
		_gear_row = _gear_buttons(opts)
		gear_box.add_child(_gear_row)
	for n in _exit_row.get_children():
		n.queue_free()
	_exit_row.visible = gear
	if gear:
		for o in opts:
			if _is_exit(o) and not o.get("hide", false) and not o.has("pager"):
				_exit_row.add_child(_small_button(o, PAGER_EXIT_FILL, PAGER_EXIT_EDGE))
	if s.has("party_grid"):
		_log.custom_minimum_size.y = FIGHT_LOG_HEIGHT
	_show_test_switches()
	view.show_view(s.get("view", view.kind))
	render_party()
	town_map.visible = s.get("map", false)
	if town_map.visible:
		town_map.show_options(s)


## The row under the cards: in_widget options at the left, or at their gear_at of center or right.
func _gear_buttons(opts: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = GEAR_BUTTONS_HEIGHT
	var left := HBoxContainer.new()
	var center := HBoxContainer.new()
	var right := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	for part: HBoxContainer in [left, center, right]:
		part.add_theme_constant_override("separation", 6)
		row.add_child(part)
	for o in opts:
		if o.get("hide", false) or not o.get("in_widget", false):
			continue
		var at: String = o.get("gear_at", "left")
		(right if at == "right" else (center if at == "center" else left)).add_child(_gear_button(o))
	return row


func _gear_button(o: Dictionary) -> Button:
	var b := Button.new()
	b.text = _opt_text(o)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = o.get("dis", false)
	b.pressed.connect(_run.bind(o))
	return b


## Page buttons on the left of the row, EXIT on the right.
func _pager_buttons(opts: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	for o in opts:
		if not o.has("pager"):
			continue
		var is_exit: bool = o["pager"] == "exit"
		var b := _small_button(o, PAGER_EXIT_FILL if is_exit else PAGER_FILL, PAGER_EXIT_EDGE if is_exit else PAGER_EDGE)
		row.add_child(b)
		if not is_exit:
			row.move_child(b, gap.get_index())
	return row


func _small_button(o: Dictionary, fill: Color, edge: Color) -> Button:
	var b := _gear_button(o)
	b.add_theme_font_size_override("font_size", PAGER_FONT)
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, UiStyle.box(fill, edge, 4))
	b.add_theme_stylebox_override("hover", UiStyle.box(fill.lightened(0.15), edge, 4))
	return b


func _is_exit(o: Dictionary) -> bool:
	return String(o["label"]) == "EXIT"


## The width of one line of text on a card in the equipment panel.
func gear_line_room() -> float:
	var cards := GEAR_COLUMN - 2.0 * GEAR_PANEL_MARGIN - (PartyCards.COLUMNS - 1) * 6.0
	return cards / PartyCards.COLUMNS - CARD_MARGIN


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


## A window over the current screen, which waits for an answer. Saying no just closes it.
func confirm_window(quote: String, ask: String, note: String, yes_label: String, no_label: String, on_yes: Callable) -> void:
	_close_confirm()
	_confirm_box = Control.new()
	_confirm_box.z_index = CONFIRM_LAYER
	add_child(_confirm_box)
	_confirm_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = CONFIRM_DIM
	_confirm_box.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_confirm_box.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = CONFIRM_WIDTH
	panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.C_STONE, UiStyle.C_TORCH, 18))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	v.add_child(_confirm_label(quote, UiStyle.C_DIM))
	v.add_child(_confirm_label(ask, UiStyle.C_TORCH))
	if note != "":
		v.add_child(_confirm_label(note, UiStyle.C_INK))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	_confirm_yes = Button.new()
	_confirm_yes.text = yes_label
	_confirm_yes.focus_mode = Control.FOCUS_NONE
	_confirm_yes.pressed.connect(func(): _close_confirm(); on_yes.call())
	row.add_child(_confirm_yes)
	_confirm_no = Button.new()
	_confirm_no.text = no_label
	_confirm_no.focus_mode = Control.FOCUS_NONE
	_confirm_no.pressed.connect(_close_confirm)
	row.add_child(_confirm_no)


func _confirm_label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	return l


func _close_confirm() -> void:
	if _confirm_box != null:
		_confirm_box.queue_free()
		_confirm_box = null


## items: [{label, fn, dis, right}] become numbered options 1..9.
## With a pager, or in a building that shows the party's cards, the page buttons and EXIT share a smaller row under the list.
## With switch_member, clicking a living member's card calls it with that character.
func choose_list(title: String, body: String, items: Array, back: Callable, extra: Array = [], pager: Variant = null, switch_member := Callable()) -> void:
	var opts := []
	for i in items.size():
		var it: Dictionary = items[i]
		opts.append({"k": str(i + 1), "label": it["label"], "fn": it["fn"], "dis": it.get("dis", false), "right": it.get("right", "")})
	opts.append_array(extra)
	var exit_opt := {"k": "L", "label": "EXIT", "fn": back}
	if pager != null:
		for o in pager:
			o["pager"] = "page"
		opts.append_array(pager)
	if pager != null or TownScreens.GEAR_PLACES.has(place_image):
		exit_opt["pager"] = "exit"
	opts.append(exit_opt)
	var s := {"title": title, "body": body, "opts": opts, "col": true}
	if switch_member.is_valid():
		s["gear_pick"] = switch_member
		s["gear_skip_dead"] = true
	show_screen(s)


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

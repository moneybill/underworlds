extends Control
## Root of the game. Builds the screen layout in code and runs the menu system that every
## location uses: a title, a body, and options to click or tap.

const KIND_COLORS := {"hit": "d6563f", "mag": "8bace6", "gold": "e3a33f", "ok": "93c07e", "": "9c947f"}
const PORTRAIT_SIZE := 300.0
const ITEM_ICON_SIZE := 26  # an item's picture on a button
const ITEM_ICON_LINE := 20  # and in a line of text
const BLANK_ICON := "res://assets/images/blank_icon.png"
const UNDER_VIEW_DROP := 3.7  # a big button under the picture sits this much lower (5 pixels on a 1920 wide screen)
const BACKDROP_COLUMN := 540.0  # width of the text column over a painted backdrop, clear of its center
const GEAR_COLUMN := 600.0  # width of the party's equipment over a painting
const GEAR_PANEL_MARGIN := 8.0  # inside its panel
const SHEET_MARGIN := 8.0  # inside the popup window
const POPUP_ALPHA := 1.0
const POPUP_EDGE := 3
const TITLE_FONT := 28  # a screen's title
const POPUP_TITLE_FONT := TITLE_FONT - 2
const GEAR_PANEL_ALPHA := 0.63  # the painting shows through, more so than through the text column
const BACKDROP_PANEL_ALPHA := 0.83
const CONFIRM_WIDTH := 560.0
const CONFIRM_LAYER := 100  # above the test switches
const CONFIRM_DIM := Color(0, 0, 0, 0.6)
const GEAR_HINT_FONT := 18  # four sizes under the body text
const VIEW_NOTE_DROP := 6.0  # below the monsters
const VIEW_NOTE_BACK := Color(0, 0, 0, 0.7)  # keeps it readable over the painted walls
const PAGER_DROP := 15.0  # extra room between a list and its row of small buttons
const PAGER_FONT := UiStyle.SMALL_BUTTON_FONT
const BIG_BUTTON_FONT := 28
const PAGER_FILL := UiStyle.C_BROWN  # to stand apart from the list above
const PAGER_EDGE := UiStyle.C_BROWN_EDGE
const PAGER_EXIT_FILL := Color("6e2a26")  # oxblood
const PAGER_EXIT_EDGE := Color("a04a42")
const GEAR_BUTTON_GAP := 4  # small enough for the Inn's five rooms to fit under the cards
const GEAR_BUTTONS_HEIGHT := 40.0  # the row under the cards keeps its height with no buttons in it
const GEAR_LEFT := 570.0  # just right of the text column
const GEAR_TOP := 46.0  # just under the test switches
const CARD_MARGIN := 16.0  # a card's edges and padding, left and right together
const BACKDROP_TABLE_FONT := 15  # lets the longest party row fit that column on one line
const DEBUG_TOP := 4.0
const DEBUG_ARROW_SIZE := 14
const DEBUG_GOLD := 500
const DEBUG_CHEST_GOLD_MIN := 10
const DEBUG_CHEST_GOLD_MAX := 100
const ROW_NOTE_WIDTH := 320.0  # beside a big button, and short of BACK at the right of the row
const ROW_NOTE_FONT := 18
const INFO_SECONDS := 3.0  # how long the info window stays up after its newest line
const INFO_WIDTH := 560.0
const INFO_FONT := 16
const INFO_MARGIN := 6.0  # from the bottom of the window
const INFO_MAX_LINES := 8  # a burst of news keeps only its latest lines
const INFO_LAYER := 10  # above every panel
const INFO_PADDING := 16.0  # the window's edges and padding, left and right together
const TOOL_SIZE := Vector2(40, 40)  # the small icon buttons on the Maze's picture
const TOOL_ICON_SIZE := 24
const INFO_GAP := 2.0  # between the Maze's picture and the window under it
const TABLE_FONT := 18  # lets the longest party row fit the right-hand column on one line
const SOUND_VOICES := 4  # sounds that can overlap

const TURN_AROUND_ICON: Texture2D = preload("res://assets/images/rotate.png")

var town: TownScreens
var chars: CharScreens
var mz: MazeScreens
var fight: CombatScreens

var view: MazeView
var scr: Dictionary = {}
var _where: Label
var _title: Label
var _view_note: Label
var _body: RichTextLabel
var _widget_box: VBoxContainer
var _after_widget: RichTextLabel  # text under the screen's widget
var _portrait: PanelContainer
var _side: PanelContainer
var lock: LockScreens
var _sheet: PanelContainer  # the popup window
var _popup_block: Control  # stops clicks reaching the screen behind the popup
var _popup_row: HBoxContainer
var _dice_tray: DiceTray
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
var _info: PanelContainer  # news of what just happened, shown only while there is some
var _info_text: RichTextLabel
var _info_timer: Timer
var _info_lines: Array[String] = []
var _info_holding := false
var _info_held: Array = []  # news that mustn't show yet: [text, kind]
var _party: RichTextLabel
var _pad: GridContainer
var _tools: HBoxContainer  # the small icons at the lower left of the Maze's picture
var _under_view: Button = null  # an option's big button, centered under the Maze's picture
var _sounds: AudioStreamPlayer
var monsters_button: Button
var god_button: Button
var town_button: Button
var chest_button: Button
var gold_button: Button
var _debug_panel: PanelContainer
var _debug_toggle: Button
var _debug_list: VBoxContainer
var town_map: TownMap
var place_image := ""  # the painting of the building the party is in; every screen shows it until cleared
var _backdrop: TextureRect
var _header: HBoxContainer
var _view_box: AspectRatioContainer
var _panel: PanelContainer
var _right: VBoxContainer  # the text, with the party table under it
var _table: PanelContainer
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
	_build_popup()
	_build_info_window()
	town = TownScreens.new(self)
	chars = CharScreens.new(self)
	mz = MazeScreens.new(self)
	fight = CombatScreens.new(self)
	lock = LockScreens.new(self)
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
			"Start at the [color=#e3a33f]Proving Grounds[/color] and create six adventurers. Hawkwind recommends two fighters, a priest, a thief and two mages.\n\n" +
			"Then gather them at the Red Dragon Inn, outfit them at the Broken Anvil, and enter the Maze. Run home often.", town.castle)


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
## There is no QUIT button in the Maze: closing the window keeps the party where it stands.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not Game.roster.is_empty():
		Game.save_game()


## A menu for testing, closed to just its button. It opens and closes like the town map's party list.
func _build_test_switches() -> void:
	_debug_panel = PanelContainer.new()
	_debug_panel.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.C_BG, 0.94), UiStyle.C_LINE, 4))
	_debug_panel.minimum_size_changed.connect(_place_debug_menu, CONNECT_DEFERRED)
	resized.connect(_place_debug_menu)
	add_child(_debug_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_debug_panel.add_child(col)
	_debug_toggle = Button.new()
	_debug_toggle.add_theme_constant_override("icon_max_width", DEBUG_ARROW_SIZE)
	_debug_toggle.focus_mode = Control.FOCUS_NONE
	UiStyle.make_small_button(_debug_toggle)
	_debug_toggle.pressed.connect(_toggle_debug_menu)
	col.add_child(_debug_toggle)
	_debug_list = VBoxContainer.new()
	_debug_list.add_theme_constant_override("separation", 4)
	_debug_list.visible = false
	col.add_child(_debug_list)
	monsters_button = _test_switch(Game.monsters_on, _set_monsters)
	_debug_list.add_child(monsters_button)
	god_button = _test_switch(Game.god_mode, _set_god)
	_debug_list.add_child(god_button)
	town_button = _debug_button("TO TOWN", _teleport_to_town)
	_debug_list.add_child(town_button)
	chest_button = _debug_button("SPAWN CHEST", _spawn_chest)
	_debug_list.add_child(chest_button)
	gold_button = _debug_button("ADD %d GOLD" % DEBUG_GOLD, _add_debug_gold)
	_debug_list.add_child(gold_button)
	_show_test_switches()
	_place_debug_menu.call_deferred()


func _debug_button(text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(fn)
	return b


func _toggle_debug_menu() -> void:
	_debug_list.visible = not _debug_list.visible
	_show_test_switches()
	_place_debug_menu.call_deferred()


func _place_debug_menu() -> void:
	_debug_panel.reset_size()
	_debug_panel.position = Vector2((size.x - _debug_panel.size.x) * 0.5, DEBUG_TOP)


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


## To each member of the party, and showing at once on a building's cards and buttons.
func _add_debug_gold() -> void:
	for c in Game.party_chars():
		c.gold += DEBUG_GOLD
	Game.save_game()
	Game.say("EACH PARTY MEMBER GAINS %d GOLD." % DEBUG_GOLD, "gold")
	if _sheet.visible:
		return
	match place_image:
		TownScreens.TAVERN_IMAGE:
			town.tavern()
		TownScreens.BOLTAC_IMAGE:
			town.boltac()
		TownScreens.INN_IMAGE:
			town.inn()


## A chest of a random size, to test picking its lock without fighting for it.
func _spawn_chest() -> void:
	fight.open_chest(Dice.rnd(DEBUG_CHEST_GOLD_MIN, DEBUG_CHEST_GOLD_MAX), false)


## Brings the party home at once, from anywhere in the Maze and even mid-fight, as if it had walked out.
func _teleport_to_town() -> void:
	fight.battle = null
	view.battle = null
	town.return_to_castle()


## Everything in the menu works only in the Maze, and a chest only while walking, not in a fight or at camp.
## Gold is the exception: it works anywhere there is a party, as town is where it gets spent.
func _show_test_switches() -> void:
	var in_maze: bool = Game.mode != "castle" and not Game.party.is_empty()
	monsters_button.disabled = not in_maze
	god_button.disabled = not in_maze
	town_button.disabled = not in_maze
	chest_button.disabled = not in_maze or Game.mode != "maze"
	gold_button.disabled = Game.party.is_empty()
	var is_open := _debug_list.visible
	_debug_toggle.text = "CLOSE DEBUG MENU" if is_open else "OPEN DEBUG MENU"
	_debug_toggle.icon = load(TownMap.PARTY_CLOSE_ARROW if is_open else TownMap.PARTY_OPEN_ARROW)
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
	_gear.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.C_BG, GEAR_PANEL_ALPHA), UiStyle.C_LINE, int(GEAR_PANEL_MARGIN)))
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
	_view_box.alignment_vertical = AspectRatioContainer.ALIGNMENT_BEGIN  # level with the panel beside it
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
	_tools = HBoxContainer.new()
	_tools.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_tools.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tools.offset_left = 10.0
	_tools.offset_bottom = -10.0
	_tools.add_theme_constant_override("separation", 6)
	view.add_child(_tools)
	_view_note = Label.new()  # in the picture, under the monsters
	_view_note.add_theme_font_size_override("font_size", PartyCards.FONT_SIZE)
	_view_note.add_theme_color_override("font_color", Color.WHITE)
	var note_back := UiStyle.box(VIEW_NOTE_BACK, VIEW_NOTE_BACK, 0)
	note_back.content_margin_left = 8.0
	note_back.content_margin_right = 8.0
	note_back.set_border_width_all(0)
	_view_note.add_theme_stylebox_override("normal", note_back)
	_view_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_note.visible = false
	view.add_child(_view_note)
	view.item_rect_changed.connect(_place_view_note)

	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 12)
	main.add_child(_right)
	_panel = PanelContainer.new()
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.item_rect_changed.connect(_place_portrait)
	_right.add_child(_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	_panel.add_child(pv)
	_title = Label.new()
	_title.add_theme_font_override("font", display)
	_title.add_theme_font_size_override("font_size", TITLE_FONT)
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
	_after_widget = RichTextLabel.new()
	_after_widget.bbcode_enabled = true
	_after_widget.fit_content = true
	_after_widget.scroll_active = false
	pv.add_child(_after_widget)
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

	_table = PanelContainer.new()
	_right.add_child(_table)
	_party = RichTextLabel.new()
	_party.bbcode_enabled = true
	_party.fit_content = true
	_party.scroll_active = false
	_table.add_child(_party)


# ---------- the menu system ----------
## s: {title, where, body (bbcode), opts: [{k (the option's id), label, fn, dis, hide, right}], col,
##     party_grid: the widget shows the party, so the party table hides,
##     row_note: a line beside the left-hand buttons of a spread row, after_widget: text under the widget,
##     gear_widget: shown in the panel of the party's cards instead of them, gear_note: a line under it,
##     opts_bottom: the option buttons sit at the bottom of the panel instead of right under the contents,
##     view_note: a line under the picture,
##     body_height, row_height: fixed heights, for a screen whose layout must not move with its contents,
##     input: {ph, max, fn}, moves: {pad button: Callable}, view, pad, widget: Control, map, portrait: path, side: Control}
func show_screen(s: Dictionary) -> void:
	_close_confirm()
	scr = s
	_set_backdrop(place_image)
	_set_portrait(s.get("portrait", ""))
	_portrait_tomb.visible = s.get("portrait_dead", false)
	_set_side(s.get("side"))
	_close_popup()
	if _dice_tray != null or s.get("dice", false):
		dice_tray().visible = s.get("dice", false)
		_place_portrait()
	_title.text = s.get("title", "")
	_title.visible = _title.text != ""
	_view_note.text = s.get("view_note", "")
	_view_note.visible = _view_note.text != ""
	_place_view_note()
	if s.has("where"):
		_where.text = String(s["where"]).to_upper()
	_body.text = s.get("body", "")
	_body.visible = _body.text != ""
	_body.custom_minimum_size.y = s.get("body_height", 0.0)
	_after_widget.text = s.get("after_widget", "")
	_after_widget.visible = _after_widget.text != ""
	for n in _widget_box.get_children():
		n.queue_free()
	if s.has("widget"):
		_widget_box.add_child(s["widget"])
	# A screen with its own portrait, like Inspect, keeps that spot for it.
	var gear: bool = (TownScreens.GEAR_PLACES.has(place_image) or s.has("gear_widget")) and s.get("portrait", "") == ""
	for n in _opts_flow.get_children() + _opts_col.get_children():
		n.queue_free()
	var col: bool = s.get("col", false)
	_opts_flow.visible = not col
	_opts_col.visible = col
	var opts: Array = s.get("opts", [])
	if s.has("input"):
		opts = [{"k": "OK", "label": "SELECT", "fn": _submit_input}] + opts
	for o in opts:
		if o["label"] == "BACK" and not o.has("pager") and not o.get("in_widget", false):  # always small, brown and at the right
			o["small"] = true
			o["at"] = "right"
	# An option with "at" (center or right) puts all of them on one row, spread across the panel.
	var row: HBoxContainer = _spread_row(opts.any(func(o): return o.get("at", "") == "center" and not o.get("hide", false))) if opts.any(func(o): return o.has("at") and not o.get("hide", false)) else null
	if row != null:
		_opts_flow.visible = false
		_opts_col.visible = true
		row.custom_minimum_size.y = s.get("row_height", 0.0)
		_opts_col.add_child(row)
	for o in opts:
		if o.has("pager"):
			continue  # these share the row under the list
		if o.get("hide", false) or o.get("in_widget", false) or o.has("under_view") or (gear and _is_exit(o) and not o.has("at")):
			continue  # an in_widget option has its button in the screen's widget instead, and EXIT has its own place unless given one
		var b: Button
		if o.get("small", false):
			b = _small_button(o, PAGER_EXIT_FILL if _is_exit(o) else PAGER_FILL, PAGER_EXIT_EDGE if _is_exit(o) else PAGER_EDGE)
		else:
			b = Button.new()
			b.text = _opt_text(o)
			b.focus_mode = Control.FOCUS_NONE
			b.disabled = o.get("dis", false)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(_run.bind(o))
			_add_item_icon(b, o)
			if o.has("big"):
				b.custom_minimum_size = o["big"]
				b.alignment = HORIZONTAL_ALIGNMENT_CENTER
				b.add_theme_font_size_override("font_size", BIG_BUTTON_FONT)
		if row != null:
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # a big button beside it stays the only big one
			row.get_node(String(o.get("at", "left"))).add_child(b)
		else:
			(_opts_col if col else _opts_flow).add_child(b)
	if row != null and s.get("row_note", "") != "":
		var note := RichTextLabel.new()
		note.name = "RowNote"
		note.bbcode_enabled = true
		note.scroll_active = false
		note.text = s["row_note"]
		note.custom_minimum_size = Vector2(ROW_NOTE_WIDTH, s.get("row_height", 0.0))
		note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		note.add_theme_font_size_override("normal_font_size", ROW_NOTE_FONT)
		note.add_theme_font_size_override("italics_font_size", ROW_NOTE_FONT)
		row.get_node("left").add_child(note)
	_pager_row = null
	if opts.any(func(o): return o.has("pager")):
		_pager_row = _pager_buttons(opts)
		var drop := Control.new()  # the column's own gap counts toward the drop
		drop.custom_minimum_size.y = PAGER_DROP - _opts_col.get_theme_constant("separation")
		_opts_col.add_child(drop)
		_opts_col.add_child(_pager_row)
	_entry.visible = s.has("input")
	if s.has("input"):
		_entry.text = s["input"].get("val", "")
		_entry.placeholder_text = s["input"].get("ph", "")
		_entry.max_length = s["input"].get("max", 15)
		_entry.call_deferred("grab_focus")
	else:
		_entry.release_focus()
	hold_info(false)
	_pad.visible = s.get("pad", false)
	_show_tools(s.get("opts", []))
	_show_under_view(s.get("opts", []))
	_widget_box.size_flags_vertical = Control.SIZE_EXPAND_FILL if s.get("opts_bottom", false) else Control.SIZE_FILL
	_table.visible = not s.has("party_grid") and not gear
	for n in _gear.get_children():
		n.queue_free()
	_gear.visible = gear
	if gear:
		var gear_box := VBoxContainer.new()
		_gear.add_child(gear_box)
		if s.has("gear_hint"):
			gear_box.add_child(_gear_line(s["gear_hint"]))
		_gear_grid = s["gear_widget"] if s.has("gear_widget") else town.gear_grid(s.get("gear_pick", Callable()), not s.get("gear_skip_dead", false))
		gear_box.add_child(_gear_grid)
		_gear_row = _gear_buttons(opts)
		_gear_row.visible = not s.has("gear_widget")  # that widget has its buttons on its cards
		gear_box.add_child(_gear_row)
		if s.has("gear_note"):
			gear_box.add_child(_gear_line(s["gear_note"]))
	for n in _exit_row.get_children():
		n.queue_free()
	_exit_row.visible = gear
	if gear:
		for o in opts:
			if _is_exit(o) and not o.get("hide", false) and not o.has("pager") and not o.has("at"):
				_exit_row.add_child(_small_button(o, PAGER_EXIT_FILL, PAGER_EXIT_EDGE))
	_show_test_switches()
	view.show_view(s.get("view", view.kind))
	render_party()
	town_map.visible = s.get("map", false)
	if town_map.visible:
		town_map.show_options(s)
	_place_info.call_deferred()


func _place_view_note() -> void:
	if not _view_note.visible:
		return
	_view_note.reset_size()
	_view_note.position = Vector2((view.size.x - _view_note.size.x) * 0.5, view.cards_bottom() + VIEW_NOTE_DROP)


## A line of small text across the panel of the party's cards.
func _gear_line(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", GEAR_HINT_FONT)
	return l


## An option with "under_view" (a size) is a big button under the picture, instead of in the panel.
func _show_under_view(opts: Array) -> void:
	if _under_view != null:
		_under_view.hide()
		_under_view.queue_free()  # it may be the button being pressed right now
		_under_view = null
	for o in opts:
		if o.has("under_view"):
			_under_view = Button.new()
			_under_view.text = o["label"]
			_under_view.custom_minimum_size = o["under_view"]
			_under_view.focus_mode = Control.FOCUS_NONE
			_under_view.add_theme_font_size_override("font_size", BIG_BUTTON_FONT)
			_under_view.pressed.connect(_run.bind(o))
			add_child(_under_view)
			_place_under_view.call_deferred()


func _place_under_view() -> void:
	if _under_view == null:
		return
	var r := view.get_global_rect()
	_under_view.reset_size()
	_under_view.position = Vector2(r.get_center().x - _under_view.size.x * 0.5, r.end.y + INFO_GAP + UNDER_VIEW_DROP)


## An option with "tool" is a small icon on the picture, showing its label when the mouse is over it.
func _show_tools(opts: Array) -> void:
	for n in _tools.get_children():
		_tools.remove_child(n)
		n.queue_free()
	for o in opts:
		if not o.has("tool") or o.get("hide", false):
			continue
		var b := Button.new()
		b.icon = load(o["tool"])
		b.tooltip_text = o["label"]
		b.custom_minimum_size = TOOL_SIZE
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", TOOL_ICON_SIZE)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_run.bind(o))
		_tools.add_child(b)


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
		part.add_theme_constant_override("separation", GEAR_BUTTON_GAP)
		row.add_child(part)
	for o in opts:
		if o.get("hide", false) or not o.get("in_widget", false):
			continue
		var at: String = o.get("gear_at", "left")
		var small: bool = o.get("small", false)
		var b := _small_button(o, UiStyle.C_STONE2 if o.get("blue", false) else PAGER_FILL, UiStyle.C_LINE if o.get("blue", false) else PAGER_EDGE) if small else _gear_button(o)
		if small:
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		(right if at == "right" else (center if at == "center" else left)).add_child(b)
	if center.get_child_count() == 0 and right.get_child_count() == 0:
		center.visible = false  # their spacing would cost the left group room
		right.visible = false
	return row


func _gear_button(o: Dictionary) -> Button:
	var b := Button.new()
	b.text = _opt_text(o)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = o.get("dis", false)
	b.pressed.connect(_run.bind(o))
	_add_item_icon(b, o)
	return b


## An option with "icon" shows that picture left of its text. "" keeps the room empty, so names in a list line up.
func _add_item_icon(b: Button, o: Dictionary) -> void:
	if not o.has("icon"):
		return
	b.icon = load(o["icon"]) if o["icon"] != "" else blank_icon()
	b.add_theme_constant_override("icon_max_width", ITEM_ICON_SIZE)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static var _blank_icon: ImageTexture = null


## A clear square, standing in for an item without a picture.
static func blank_icon() -> ImageTexture:
	if _blank_icon == null:
		_blank_icon = ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))
	return _blank_icon


## Three groups: left, center and right. The outer two share the spare room, so the center stays centered.
func _spread_row(opts_centered: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var left := HFlowContainer.new()  # the one that can hold enough buttons to need a second line
	left.name = "left"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	for spec in [["center", BoxContainer.ALIGNMENT_CENTER], ["right", BoxContainer.ALIGNMENT_END]]:
		var group := HBoxContainer.new()
		group.name = spec[0]
		group.alignment = spec[1]
		group.add_theme_constant_override("separation", 6)
		if spec[0] == "right":
			group.size_flags_horizontal = Control.SIZE_EXPAND_FILL if opts_centered else Control.SIZE_SHRINK_END
		row.add_child(group)
	return row


## Page buttons on the left of the row, the way out on the right. Only EXIT, the way back to town, is red.
func _pager_buttons(opts: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	for o in opts:
		if not o.has("pager"):
			continue
		var red := _is_exit(o)
		var b := _small_button(o, PAGER_EXIT_FILL if red else PAGER_FILL, PAGER_EXIT_EDGE if red else PAGER_EDGE)
		row.add_child(b)
		if o["pager"] != "exit":
			row.move_child(b, gap.get_index())
	return row


func _small_button(o: Dictionary, fill: Color, edge: Color) -> Button:
	var b := _gear_button(o)
	UiStyle.make_small_button(b, fill, edge)
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
	_party.add_theme_font_size_override("normal_font_size", BACKDROP_TABLE_FONT if on else TABLE_FONT)
	_right.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if on else Control.SIZE_EXPAND_FILL
	_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if on else Control.SIZE_EXPAND_FILL  # over a painting, only as tall as its contents
	for p: PanelContainer in [_panel, _table]:
		p.custom_minimum_size.x = BACKDROP_COLUMN if on else 0.0
		if on:
			p.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.C_BG, BACKDROP_PANEL_ALPHA), UiStyle.C_LINE, 8))
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


## The dice beside the text panel, made the first time they are wanted.
func dice_tray() -> DiceTray:
	if _dice_tray == null:
		_dice_tray = DiceTray.new()
		_dice_tray.visible = false
		add_child(_dice_tray)
	return _dice_tray


## A character sheet takes the place of the portrait and side panel. make_panel builds its contents,
## afresh each time the screen is shown.
func _build_popup() -> void:
	_popup_block = Control.new()
	_popup_block.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_block.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_block.visible = false
	add_child(_popup_block)
	_sheet = PanelContainer.new()
	var frame := UiStyle.box(Color(UiStyle.C_BG, POPUP_ALPHA), UiStyle.C_TORCH, int(SHEET_MARGIN))
	frame.set_border_width_all(POPUP_EDGE)
	_sheet.add_theme_stylebox_override("panel", frame)
	_sheet.visible = false
	_sheet.minimum_size_changed.connect(_center_popup, CONNECT_DEFERRED)
	resized.connect(_center_popup)
	add_child(_sheet)


## A window over the current screen, which stays as it is behind it. Its options work as a screen's do;
## showing any screen, which is how one of them closes it, closes the window too.
## make_top builds what goes above s's text, and those of s's options that it doesn't place go below.
func show_popup(s: Dictionary, make_top: Callable) -> void:
	scr = s
	_empty_popup()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_sheet.add_child(v)
	var heading := Label.new()
	heading.name = "PopupTitle"
	heading.text = s.get("title", "")
	heading.add_theme_font_override("font", display)
	heading.add_theme_font_size_override("font_size", POPUP_TITLE_FONT)
	heading.add_theme_color_override("font_color", UiStyle.C_TORCH)
	v.add_child(heading)
	v.add_child(make_top.call())
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.text = s.get("body", "")
	text.visible = text.text != ""
	v.add_child(text)
	_popup_row = _spread_row(false)
	v.add_child(_popup_row)
	for o in s.get("opts", []):
		if o.get("hide", false) or o.get("in_widget", false):
			continue
		_popup_row.get_node(String(o.get("at", "left"))).add_child(_small_button(o, PAGER_FILL, PAGER_EDGE))
	_popup_block.visible = true
	_sheet.visible = true
	_popup_block.move_to_front()
	_sheet.move_to_front()
	_center_popup()
	_fit_popup.call_deferred()


## Its text wraps, and asks for far too much height until it has been laid out at its width.
func _fit_popup() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_center_popup()


func _center_popup() -> void:
	if not _sheet.visible:
		return
	_sheet.reset_size()
	_sheet.position = ((size - _sheet.size) * 0.5).max(Vector2.ZERO)


func _empty_popup() -> void:
	for n in _sheet.get_children():
		_sheet.remove_child(n)
		n.queue_free()


func _close_popup() -> void:
	_empty_popup()
	_sheet.visible = false
	_popup_block.visible = false


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
	_side.global_position = Vector2(x, maxf(r.position.y, GEAR_TOP))  # clear of the buttons along the top
	if _dice_tray != null:
		_dice_tray.global_position = Vector2(r.end.x + 14, r.position.y + (r.size.y - DiceTray.SIZE.y) * 0.5)


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


func set_input_text(text: String) -> void:
	_entry.text = text
	_entry.caret_column = text.length()


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
	_keep_cards_in_maze(s)
	if where != "":
		s["where"] = where
	show_screen(s)


func yesno(title: String, body: String, yes: Callable, no: Callable, portrait := "") -> void:
	var s := {"title": title, "body": body, "portrait": portrait, "opts": [
		{"k": "Y", "label": "YES", "fn": yes},
		{"k": "N", "label": "NO", "fn": no}]}
	_keep_cards_in_maze(s)
	show_screen(s)


## The party's cards stay up while walking the Maze, through its messages and questions too.
func _keep_cards_in_maze(s: Dictionary) -> void:
	if Game.mode == "maze" and s.get("portrait", "") == "":
		s["widget"] = fight.explore_grid()
		s["party_grid"] = true


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


## items: [{label, fn, dis, right, icon}] become numbered options 1..9. If any has an icon, the rest keep its room.
## With a pager, or in a building that shows the party's cards, the page buttons and the way out share a smaller row under the list.
## The way out says EXIT only when it returns to town, and BACK otherwise.
## With switch_member, clicking a living member's card calls it with that character, and the cards say so.
func choose_list(title: String, body: String, items: Array, back: Callable, extra: Array = [], pager: Variant = null, switch_member := Callable()) -> void:
	var opts := []
	var icons := items.any(func(it): return it.get("icon", "") != "")
	for i in items.size():
		var it: Dictionary = items[i]
		opts.append({"k": str(i + 1), "label": it["label"], "fn": it["fn"], "dis": it.get("dis", false), "right": it.get("right", "")})
		if icons:
			opts[-1]["icon"] = it.get("icon", "")
	opts.append_array(extra)
	var exit_opt := {"k": "L", "label": "EXIT" if back == town.castle else "BACK", "fn": back}
	if pager != null:
		for o in pager:
			o["pager"] = "page"
		opts.append_array(pager)
	if pager != null or TownScreens.GEAR_PLACES.has(place_image) or exit_opt["label"] == "BACK":
		exit_opt["pager"] = "exit"
	opts.append(exit_opt)
	var s := {"title": title, "body": body, "opts": opts, "col": true}
	if switch_member.is_valid():
		s["gear_pick"] = switch_member
		s["gear_skip_dead"] = true
		s["gear_hint"] = TownScreens.SELECT_HINT
	show_screen(s)


func pick_member(title: String, back: Callable, fn: Callable, filter := Callable()) -> void:
	var items := []
	for c in Game.party_chars():
		var right: String = c.status if c.status != "OK" else "%d GP" % c.gold
		items.append({"label": c.name, "right": right, "fn": fn.bind(c), "dis": filter.is_valid() and not filter.call(c)})
	choose_list(title, "Who?", items, back)


## A window of its own at the bottom of the screen. It lets clicks through to whatever is beneath it.
func _build_info_window() -> void:
	_info = PanelContainer.new()
	_info.visible = false
	_info.z_index = INFO_LAYER
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.C_BG, 0.94), UiStyle.C_LINE, 8))
	_info.minimum_size_changed.connect(_place_info, CONNECT_DEFERRED)
	resized.connect(_place_info)
	view.item_rect_changed.connect(_place_info)  # in the Maze it follows the picture
	view.item_rect_changed.connect(_place_under_view)
	add_child(_info)
	_info_text = RichTextLabel.new()
	_info_text.bbcode_enabled = true
	_info_text.fit_content = true
	_info_text.scroll_active = false
	_info_text.custom_minimum_size.x = INFO_WIDTH
	_info_text.add_theme_font_size_override("normal_font_size", INFO_FONT)
	_info_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_child(_info_text)
	_info_timer = Timer.new()
	_info_timer.one_shot = true
	_info_timer.wait_time = INFO_SECONDS
	_info_timer.timeout.connect(clear_log)
	add_child(_info_timer)


## Centered at the bottom of the screen, as tall as its text. In the Maze it sits under the picture, as
## wide as the picture, and keeps only the lines that fit there.
func _place_info() -> void:
	var in_maze: bool = Game.mode != "castle" and _view_box.visible
	var r := view.get_global_rect()
	_info_text.custom_minimum_size.x = r.size.x - INFO_PADDING if in_maze else INFO_WIDTH
	var top := r.end.y + INFO_GAP
	if _under_view != null:
		top += _under_view.get_combined_minimum_size().y + INFO_GAP + UNDER_VIEW_DROP  # below the button that is under the picture
	if in_maze:
		var room: float = size.y - INFO_MARGIN - top - INFO_PADDING
		while _info_lines.size() > 1 and _info_text.get_content_height() > room:
			_info_lines.pop_front()
			_info_text.text = "\n".join(_info_lines)
	_info.reset_size()
	_info.position = Vector2(r.position.x, top) if in_maze else Vector2((size.x - _info.size.x) * 0.5, size.y - INFO_MARGIN - _info.size.y)


## Shows the info window with this line added, for INFO_SECONDS from now.
func log_line(text: String, kind := "") -> void:
	if _info_holding:
		_info_held.append([text, kind])
		return
	_info_lines.append("[color=#%s]%s[/color]" % [KIND_COLORS.get(kind, "c9c0a8"), esc(text)])
	_info_lines = _info_lines.slice(-INFO_MAX_LINES)
	_info_text.text = "\n".join(_info_lines)
	_info.visible = true
	_info_timer.start()
	_place_info.call_deferred()


## Keeps news back while on, so a fight's news doesn't come before its blow lands. Off shows what was kept.
func hold_info(on: bool) -> void:
	_info_holding = on
	if not on:
		for news in _info_held:
			log_line(news[0], news[1])
		_info_held = []


func clear_log() -> void:
	_info_timer.stop()
	_info_lines.clear()
	_info_text.text = ""
	_info.visible = false


## The front three party rows are bright, the back three dim.
func party_row_color(row: int) -> String:
	return "eadfc4" if row < 3 else "9c947f"


func status_color(st: String, ok_color: String) -> String:
	return {"OK": ok_color, "POISON": "93c07e", "ASLEEP": "8bace6"}.get(st, "d6563f")


func render_party() -> void:
	var ps := Game.party_chars()
	if ps.is_empty():
		_party.text = "[color=#9c947f]NO PARTY FORMED. VISIT THE RED DRAGON INN TO GATHER ADVENTURERS.[/color]"
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
	var t := _stat_rows(c)
	t += "[cell][color=#9c947f]STATUS[/color] %s   [/cell][cell][color=#9c947f]MAGE[/color] %s   [/cell][cell][color=#9c947f]PRIEST[/color] %s[/cell][/table]\n" % [c.status, "/".join(c.sp["M"].map(func(v): return str(v))), "/".join(c.sp["P"].map(func(v): return str(v)))]
	return t + item_lines(c)


## The name line and statistics, for the character sheet panel.
func stat_text(c: Character) -> String:
	return _stat_rows(c) + "[/table]"


func _stat_rows(c: Character) -> String:
	var nx := Data.xp_needed(c.cls, c.lvl)
	var t := "[color=#e3a33f]%s  L %d  %s-%s-%s  %s[/color]\n" % [esc(c.name), c.lvl, c.align.substr(0, 1), c.race, c.cls, c.sex.substr(0, 1)]
	t += "[table=3]"
	for st in Data.STATS:
		t += "[cell][color=#9c947f]%s[/color] %d   [/cell]" % [Data.STAT_NAMES[st], c.stats[st]]
	t += "[cell][color=#9c947f]GOLD[/color] %d   [/cell][cell][color=#9c947f]EXP[/color] %d   [/cell][cell][color=#9c947f]NEXT[/color] %d[/cell]" % [c.gold, c.xp, nx]
	t += "[cell][color=#9c947f]AGE[/color] %d   [/cell][cell][color=#9c947f]HITS[/color] %d/%d   [/cell][cell][color=#9c947f]AC[/color] %d[/cell]" % [c.age / 52, c.hp, c.maxhp, c.ac()]
	return t


## A character's items, numbered, with * for equipped, # for unusable, ? for unknown and - for cursed.
func item_lines(c: Character) -> String:
	var t := ""
	if c.items.is_empty():
		t += "[color=#9c947f]NO ITEMS[/color]"
	var pictures := c.items.any(func(it): return c.item_icon(it) != "")
	for i in c.items.size():
		var it: Dictionary = c.items[i]
		var sym := ("*" if it["eq"] else "") + ("" if c.can_use(it) else "#") + ("" if it["known"] else "?") + ("-" if it["eq"] and it["cursed"] else "")
		var pic := c.item_icon(it)
		if pic == "" and pictures:
			pic = BLANK_ICON  # keeps the names in line
		var icon := "[img=%dx%d]%s[/img] " % [ITEM_ICON_LINE, ITEM_ICON_LINE, pic] if pic != "" else ""
		t += "%d)%s %s%s\n" % [i + 1, sym if sym != "" else " ", icon, esc(c.item_name(it))]
	return t

class_name PartyCards
extends RefCounted
## The party as a grid of portrait cards, front row above back row, for combat and the Trading Post.

const COLUMNS := 3
const ROWS := 2
const PORTRAIT_SIZE := 90.0
const LINE_HEIGHT := 19.0
const LINE_GAP := 3
const FONT_SIZE := 16
const DEAD_FILL := Color("4a1a1c")  # a dead character's box
const DEAD_EDGE := Color("8a2f2c")


## Calls fill(box, character, slot) for each member. Empty slots stay the height of a card with this many lines.
## With on_click, clicking a member's card calls on_click(character). With click_dead off, the dead's cards ignore clicks.
static func grid(fill: Callable, active := -1, lines := 3, on_click := Callable(), click_dead := true) -> GridContainer:
	var g := GridContainer.new()
	g.columns = COLUMNS
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	var ps := Game.party_chars()
	for i in COLUMNS * ROWS:
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		g.add_child(cell)
		var is_active := i < ps.size() and i == active
		var dead := i < ps.size() and not ps[i].is_alive()
		var box_fill: Color = DEAD_FILL if dead else (UiStyle.C_STONE2 if is_active else UiStyle.C_STONE)
		var edge: Color = UiStyle.C_TORCH if is_active else (DEAD_EDGE if dead else UiStyle.C_LINE)
		cell.add_theme_stylebox_override("panel", UiStyle.box(box_fill, edge, 5))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", LINE_GAP)
		cell.add_child(v)
		if i < ps.size():
			fill.call(v, ps[i], i)
			if on_click.is_valid() and (click_dead or not dead):
				var hit := Button.new()  # an invisible button over the whole card
				hit.flat = true
				hit.focus_mode = Control.FOCUS_NONE
				hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				hit.pressed.connect(on_click.bind(ps[i]))
				cell.add_child(hit)
		else:
			var empty := Control.new()
			empty.custom_minimum_size = Vector2(0, PORTRAIT_SIZE + lines * (LINE_HEIGHT + LINE_GAP))
			v.add_child(empty)
	return g


## The top of every card: portrait, name, level and class if asked for, hit points and armor class.
static func add_head(v: VBoxContainer, c: Character, show_class := false) -> void:
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(0, PORTRAIT_SIZE)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if c.portrait_path() != "":
		pic.texture = load(c.portrait_path())
	v.add_child(pic)
	if not c.is_alive():
		UiStyle.add_tombstone(pic)
	v.add_child(label(c.name, UiStyle.C_INK))
	if show_class:
		v.add_child(label("LVL %d %s" % [c.lvl, c.cls], UiStyle.C_TORCH))
	v.add_child(label("HP %d/%d · AC %d" % [c.hp, c.maxhp, c.ac()], UiStyle.C_DIM))


static func label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.custom_minimum_size = Vector2(0, LINE_HEIGHT)
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", col)
	return l

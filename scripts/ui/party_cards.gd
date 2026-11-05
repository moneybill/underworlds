class_name PartyCards
extends RefCounted
## The party as a grid of portrait cards, front row above back row, for combat and the Trading Post.

const COLUMNS := 3
const ROWS := 2
const PORTRAIT_SIZE := 90.0
const LINE_HEIGHT := 19.0
const EMPTY_TEXT := "* EMPTY *"
const NAME_ROOM := 176.0  # a long name shrinks to fit a card this wide inside, in the narrowest panel that shows them
const NAME_MIN_FONT := 9

static var _measuring_font: Font = null
const LINE_GAP := 3
const FONT_SIZE := 16
const SELECTED_EDGE := Color("ffc21a")  # brighter than anything else on a card
const SELECTED_WIDTH := 4  # no wider than a card's padding, so that selecting moves nothing
const DEAD_FILL := Color("4a1a1c")  # a dead character's box
const DEAD_EDGE := Color("8a2f2c")


## Calls fill(box, character, slot) for each member. Empty slots stay the height of a card with this many lines.
## With on_click, clicking a member's card calls on_click(character). With click_dead off, the dead's cards ignore clicks.
## Below 1, fill_alpha lets what's behind the cards show through.
## shown_hp holds the hit points a character still shows while a blow lands, and until then they aren't shown dead.
## With say_empty, empty slots say so in their middle. With buttons_on_active, the active card has buttons
## of its own, so clicking it as a whole does nothing.
static func grid(fill: Callable, active := -1, lines := 3, on_click := Callable(), click_dead := true, fill_alpha := 1.0, shown_hp := {}, say_empty := false, buttons_on_active := false) -> GridContainer:
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
		var dead: bool = i < ps.size() and not ps[i].is_alive() and shown_hp.get(ps[i], 0) <= 0
		var box_fill: Color = DEAD_FILL if dead else (UiStyle.C_STONE2 if is_active else UiStyle.C_STONE)
		cell.add_theme_stylebox_override("panel", card_style(Color(box_fill, fill_alpha), is_active, dead))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", LINE_GAP)
		cell.add_child(v)
		if i < ps.size():
			fill.call(v, ps[i], i)
			if on_click.is_valid() and (click_dead or not dead) and not (buttons_on_active and is_active):
				var hit := Button.new()  # an invisible button over the whole card
				hit.flat = true
				hit.focus_mode = Control.FOCUS_NONE
				hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				hit.pressed.connect(on_click.bind(ps[i]))
				cell.add_child(hit)
		else:
			var empty := label(EMPTY_TEXT if say_empty else "", UiStyle.C_DIM)
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.custom_minimum_size = Vector2(0, PORTRAIT_SIZE + lines * (LINE_HEIGHT + LINE_GAP))
			v.add_child(empty)
	return g


## A card's box, which stands out when it is the one selected.
static func card_style(fill: Color, selected: bool, dead: bool) -> StyleBoxFlat:
	var style := UiStyle.box(fill, SELECTED_EDGE if selected else (DEAD_EDGE if dead else UiStyle.C_LINE), 5)
	if selected:
		style.set_border_width_all(SELECTED_WIDTH)
	return style


## The top of every card: portrait, name, level and class if asked for, hit points and armor class.
static func add_head(v: VBoxContainer, c: Character, show_class := false, shown_hp := -1) -> void:
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(0, PORTRAIT_SIZE)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if c.portrait_path() != "":
		pic.texture = load(c.portrait_path())
	v.add_child(pic)
	if not c.is_alive() and shown_hp <= 0:
		UiStyle.add_tombstone(pic)
	var name_line := label(c.name, UiStyle.C_INK)
	name_line.add_theme_font_size_override("font_size", fit_font(c.name, NAME_ROOM, FONT_SIZE))
	v.add_child(name_line)
	if show_class:
		v.add_child(label("LVL %d %s" % [c.lvl, c.cls], UiStyle.C_TORCH))
	v.add_child(label(hp_text(c, shown_hp if shown_hp >= 0 else c.hp), UiStyle.C_DIM))


## The largest size up to this one at which the text fits the room.
static func fit_font(text: String, room: float, largest: int) -> int:
	if _measuring_font == null:
		_measuring_font = UiStyle.mono_font()  # cards are rebuilt often, so it is only looked up once
	var size := largest
	while size > NAME_MIN_FONT and _measuring_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > room:
		size -= 1
	return size


static func hp_text(c: Character, hp: int) -> String:
	return "HP %d/%d · AC %d" % [hp, c.maxhp, c.ac()]


static func label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.custom_minimum_size = Vector2(0, LINE_HEIGHT)
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", col)
	return l

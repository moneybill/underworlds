class_name CharacterSheet
extends RefCounted
## A character's sheet as a panel: portrait, statistics, spell book and equipment, each section with
## the options that belong to it. Inspect uses it, and it is built to be used anywhere.

const WIDTH := 633.0
const PORTRAIT := 244.0
const FONT := 16
const HEADING_FONT := 20
const BUTTON_FILL := UiStyle.C_STONE2
const BUTTON_EDGE := UiStyle.C_LINE
const SCHOOLS := [["M", "MAGE"], ["P", "PRIEST"]]
const AT_BOOK := "book"  # an option's sheet_at: its button sits beside the Spell Book heading
const AT_EQUIPMENT := "equipment"  # or beside the Equipment heading


## opts are the screen's options; those with a sheet_at get their buttons here.
static func build(ui, c: Character, opts: Array) -> Control:
	var columns := HBoxContainer.new()
	columns.custom_minimum_size.x = WIDTH
	columns.add_theme_constant_override("separation", 14)
	columns.add_child(_portrait(c))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	columns.add_child(v)
	v.add_child(_text("Stats", ui.stat_text(c) + "\n[color=#9c947f]STATUS[/color] %s" % c.status))
	v.add_child(_section_row(ui, "Spell Book", AT_BOOK, opts))
	var points := _points(c)
	if points != "":
		v.add_child(_text("Points", points))
	v.add_child(_text("Spells", _spell_names(c)))
	v.add_child(_section_row(ui, "Equipment", AT_EQUIPMENT, opts))
	v.add_child(_text("Items", ui.item_lines(c)))
	return columns


static func _portrait(c: Character) -> Control:
	var pic := TextureRect.new()
	pic.name = "Portrait"
	pic.custom_minimum_size = Vector2.ONE * PORTRAIT
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if c.portrait_path() != "":
		pic.texture = load(c.portrait_path())
	if not c.is_alive():
		UiStyle.add_tombstone(pic)
	return pic


## A section's heading with its buttons at the right. They wrap if there are too many for one line.
static func _section_row(ui, title: String, at: String, opts: Array) -> Control:
	var row := HBoxContainer.new()
	row.name = title.replace(" ", "")
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_override("font", UiStyle.display_font())
	heading.add_theme_font_size_override("font_size", HEADING_FONT)
	heading.add_theme_color_override("font_color", UiStyle.C_TORCH)
	row.add_child(heading)
	var buttons := HFlowContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.alignment = FlowContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("h_separation", 6)
	buttons.add_theme_constant_override("v_separation", 4)
	row.add_child(buttons)
	for o in opts:
		if o.get("sheet_at", "") == at and not o.get("hide", false):
			buttons.add_child(ui._small_button(o, BUTTON_FILL, BUTTON_EDGE))
	return row


## Spell points left at each level, for the schools this character has any in.
static func _points(c: Character) -> String:
	var lines := []
	for school in SCHOOLS:
		if c.sp[school[0]].any(func(v): return v > 0) or c.cdata().has(school[0]):
			lines.append("[color=#9c947f]%s[/color] %s" % [school[1], "/".join(c.sp[school[0]].map(func(v): return str(v)))])
	return "\n".join(lines)


static func _spell_names(c: Character) -> String:
	if c.spells.is_empty():
		return "[color=#9c947f]NO SPELLS[/color]"
	var known: Array = c.spells.duplicate()
	known.sort_custom(func(a, b): return [Data.SPELLS[a][0], Data.SPELLS[a][1], a] < [Data.SPELLS[b][0], Data.SPELLS[b][1], b])
	return ", ".join(known)


static func _text(node_name: String, bbcode: String) -> RichTextLabel:
	var t := RichTextLabel.new()
	t.name = node_name
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.add_theme_font_size_override("normal_font_size", FONT)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # item pictures shrink cleanly
	t.text = bbcode
	return t

class_name UiStyle
extends RefCounted
## The game's palette, fonts and theme, shared by the start-up screens and the game itself.

const C_BG := Color("0f1119")
const TOMBSTONE: Texture2D = preload("res://assets/images/tombstone.webp")
const C_STONE := Color("191d29")
const C_STONE2 := Color("222738")
const C_LINE := Color("3a4159")
const C_INK := Color("eadfc4")
const C_DIM := Color("9c947f")
const C_TORCH := Color("e3a33f")
const C_BLOOD := Color("d6563f")
const C_MANA := Color("8bace6")
const C_MOSS := Color("93c07e")
const C_BROWN := Color("5a3d24")
const C_BROWN_EDGE := Color("8a6238")
const SMALL_BUTTON_FONT := 18


static func mono_font() -> Font:
	return _font_or_system("res://fonts/VT323-Regular.ttf", ["VT323", "Menlo", "Consolas", "Courier New", "monospace"])


static func display_font() -> Font:
	return _font_or_system("res://fonts/IMFellEnglishSC-Regular.ttf", ["IM Fell English SC", "Georgia", "Times New Roman", "serif"])


static func _font_or_system(path: String, names: Array) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	return f


## Stands a tombstone over a dead character's portrait, and returns it.
static func add_tombstone(portrait: Control) -> TextureRect:
	var tomb := TextureRect.new()
	tomb.name = "Tombstone"
	tomb.texture = TOMBSTONE
	tomb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tomb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tomb.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tomb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tomb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.add_child(tomb)
	return tomb


static func box(bg: Color, border: Color, pad := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(pad)
	return sb


## The small button style: a smaller font on a flat colour.
static func make_small_button(b: Button, fill: Color = C_BROWN, edge: Color = C_BROWN_EDGE) -> void:
	b.add_theme_font_size_override("font_size", SMALL_BUTTON_FONT)
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, box(fill, edge, 4))
	b.add_theme_stylebox_override("hover", box(fill.lightened(0.15), edge, 4))
	b.add_theme_stylebox_override("disabled", box(fill.darkened(0.45), edge.darkened(0.45), 4))  # the same size as the others


static func build_theme(mono: Font) -> Theme:
	var t := Theme.new()
	t.default_font = mono
	t.default_font_size = 22
	t.set_color("font_color", "Label", C_INK)
	t.set_color("default_color", "RichTextLabel", C_INK)
	for st in ["normal", "focus"]:
		t.set_stylebox(st, "Button", box(C_STONE2, C_LINE, 7))
	t.set_stylebox("hover", "Button", box(C_STONE2, C_DIM, 7))
	t.set_stylebox("pressed", "Button", box(C_TORCH, C_TORCH, 7))
	t.set_stylebox("disabled", "Button", box(C_STONE, C_STONE2, 7))
	t.set_color("font_color", "Button", C_INK)
	t.set_color("font_hover_color", "Button", C_INK)
	t.set_color("font_pressed_color", "Button", C_BG)
	t.set_color("font_disabled_color", "Button", Color(C_INK, 0.35))
	t.set_stylebox("normal", "LineEdit", box(C_BG, C_LINE, 6))
	t.set_stylebox("focus", "LineEdit", box(C_BG, C_TORCH, 6))
	t.set_color("font_color", "LineEdit", C_INK)
	t.set_stylebox("panel", "PanelContainer", box(C_STONE, C_LINE, 14))
	return t

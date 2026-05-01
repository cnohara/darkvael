class_name UITheme
extends RefCounted

const BASE_SIZE := 24

static func font_size(n: int) -> int:
	return roundi(n * BASE_SIZE / 15.0)

static func create() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"SF Pro Text",
		"SF Pro Display",
		"Inter",
		"Segoe UI",
		"Helvetica Neue",
		"Noto Sans",
		"DejaVu Sans",
		"Arial"
	])
	font.multichannel_signed_distance_field = true
	font.generate_mipmaps = true
	font.msdf_pixel_range = 24

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = BASE_SIZE
	theme.set_font_size("font_size", "Label", BASE_SIZE)
	theme.set_font_size("font_size", "Button", BASE_SIZE)
	theme.set_font_size("font_size", "LineEdit", BASE_SIZE)
	theme.set_font_size("font_size", "TextEdit", BASE_SIZE)
	theme.set_font_size("font_size", "RichTextLabel", BASE_SIZE)
	theme.set_constant("minimum_character_width", "LineEdit", 1)
	return theme

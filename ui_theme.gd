class_name UITheme
extends RefCounted

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
	theme.default_font_size = 18
	theme.set_font_size("font_size", "Label", 18)
	theme.set_font_size("font_size", "Button", 18)
	theme.set_font_size("font_size", "LineEdit", 18)
	theme.set_font_size("font_size", "TextEdit", 18)
	theme.set_font_size("font_size", "RichTextLabel", 18)
	theme.set_constant("minimum_character_width", "LineEdit", 1)
	return theme

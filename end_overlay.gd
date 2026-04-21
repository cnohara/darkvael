extends Control

signal restart_requested
signal title_requested

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func setup(victory: bool) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var result_lbl := Label.new()
	result_lbl.text = "VICTORY!" if victory else "DEFEAT"
	result_lbl.add_theme_font_size_override("font_size", 60)
	result_lbl.add_theme_color_override("font_color",
		Color(0.35, 0.92, 0.35) if victory else Color(0.92, 0.28, 0.28))
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(result_lbl)

	vbox.add_child(_spacer(36))

	var restart_btn := _make_btn("Restart Battle", Color(0.18, 0.38, 0.55))
	restart_btn.pressed.connect(func() -> void: restart_requested.emit())
	vbox.add_child(restart_btn)

	vbox.add_child(_spacer(12))

	var title_btn := _make_btn("Return to Title", Color(0.28, 0.28, 0.38))
	title_btn.pressed.connect(func() -> void: title_requested.emit())
	vbox.add_child(title_btn)

func _make_btn(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(260, 58)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

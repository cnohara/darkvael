extends Control

signal start_battle(player_count: int)
signal host_online_requested(server_url: String)
signal join_online_requested(server_url: String, room_code: String)
signal quit_requested

var _player_count_box: VBoxContainer = null
var _online_host_box: VBoxContainer = null
var _online_join_box: VBoxContainer = null
var _server_url_edit: LineEdit = null
var _join_code_edit: LineEdit = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "DarkVael Prototype"
	title_lbl.add_theme_font_size_override("font_size", 56)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.72, 0.28))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	vbox.add_child(_spacer(20))

	var sub_lbl := Label.new()
	sub_lbl.text = "Single Battle Prototype"
	sub_lbl.add_theme_font_size_override("font_size", 24)
	sub_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_lbl)

	vbox.add_child(_spacer(40))

	var hint_lbl := Label.new()
	hint_lbl.text = "Each player selects cards from their own hand, marks Ready, then acts in initiative order."
	hint_lbl.add_theme_font_size_override("font_size", 18)
	hint_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.custom_minimum_size = Vector2(760, 0)
	vbox.add_child(hint_lbl)

	vbox.add_child(_spacer(48))

	var single_btn := _make_btn("Start Single Player", Color(0.18, 0.45, 0.22))
	single_btn.pressed.connect(func() -> void: start_battle.emit(1))
	vbox.add_child(single_btn)

	vbox.add_child(_spacer(12))

	var local_btn := _make_btn("Start Local Multiplayer", Color(0.18, 0.28, 0.50))
	local_btn.pressed.connect(_toggle_local_multiplayer)
	vbox.add_child(local_btn)

	_player_count_box = VBoxContainer.new()
	_player_count_box.visible = false
	_player_count_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_player_count_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_player_count_box)

	var count_lbl := Label.new()
	count_lbl.text = "Choose player count"
	count_lbl.add_theme_font_size_override("font_size", 18)
	count_lbl.add_theme_color_override("font_color", Color(0.80, 0.82, 0.90))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_count_box.add_child(count_lbl)

	var counts := HBoxContainer.new()
	counts.alignment = BoxContainer.ALIGNMENT_CENTER
	counts.add_theme_constant_override("separation", 8)
	_player_count_box.add_child(counts)
	for player_count in [2, 3, 4]:
		var count_btn := _make_btn("%d Players" % player_count, Color(0.22, 0.36, 0.62))
		count_btn.custom_minimum_size = Vector2(160, 50)
		count_btn.add_theme_font_size_override("font_size", 18)
		count_btn.pressed.connect(start_battle.emit.bind(player_count))
		counts.add_child(count_btn)

	vbox.add_child(_spacer(12))

	var host_online_btn := _make_btn("Host Online Game", Color(0.44, 0.22, 0.18))
	host_online_btn.pressed.connect(_toggle_host_online)
	vbox.add_child(host_online_btn)

	_online_host_box = VBoxContainer.new()
	_online_host_box.visible = false
	_online_host_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_online_host_box)

	_server_url_edit = LineEdit.new()
	_server_url_edit.placeholder_text = "Server URL"
	_server_url_edit.text = "http://127.0.0.1:8787"
	_server_url_edit.custom_minimum_size = Vector2(380, 44)
	_online_host_box.add_child(_server_url_edit)

	var host_go_btn := _make_btn("Create Room Code", Color(0.52, 0.26, 0.20))
	host_go_btn.custom_minimum_size = Vector2(240, 48)
	host_go_btn.add_theme_font_size_override("font_size", 18)
	host_go_btn.pressed.connect(func() -> void:
		host_online_requested.emit(_server_url_edit.text)
	)
	_online_host_box.add_child(host_go_btn)

	vbox.add_child(_spacer(12))

	var join_online_btn := _make_btn("Join Online Game", Color(0.20, 0.36, 0.56))
	join_online_btn.pressed.connect(_toggle_join_online)
	vbox.add_child(join_online_btn)

	_online_join_box = VBoxContainer.new()
	_online_join_box.visible = false
	_online_join_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_online_join_box)

	var join_server_edit := LineEdit.new()
	join_server_edit.placeholder_text = "Server URL"
	join_server_edit.text = "http://127.0.0.1:8787"
	join_server_edit.custom_minimum_size = Vector2(380, 44)
	join_server_edit.text_changed.connect(func(new_text: String) -> void:
		_server_url_edit.text = new_text
	)
	_online_join_box.add_child(join_server_edit)

	_join_code_edit = LineEdit.new()
	_join_code_edit.placeholder_text = "Room code"
	_join_code_edit.custom_minimum_size = Vector2(280, 44)
	_online_join_box.add_child(_join_code_edit)

	var join_go_btn := _make_btn("Join By Code", Color(0.22, 0.40, 0.62))
	join_go_btn.custom_minimum_size = Vector2(240, 48)
	join_go_btn.add_theme_font_size_override("font_size", 18)
	join_go_btn.pressed.connect(func() -> void:
		join_online_requested.emit(join_server_edit.text, _join_code_edit.text)
	)
	_online_join_box.add_child(join_go_btn)

	vbox.add_child(_spacer(12))

	var quit_btn := _make_btn("Quit", Color(0.35, 0.18, 0.18))
	quit_btn.pressed.connect(func() -> void: quit_requested.emit())
	vbox.add_child(quit_btn)

func _toggle_local_multiplayer() -> void:
	_player_count_box.visible = not _player_count_box.visible

func _toggle_host_online() -> void:
	_online_host_box.visible = not _online_host_box.visible

func _toggle_join_online() -> void:
	_online_join_box.visible = not _online_join_box.visible

func _make_btn(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(220, 52)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

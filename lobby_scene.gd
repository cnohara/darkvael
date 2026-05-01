extends Control

signal cancel_requested
signal start_requested

var session_manager = null

var title_lbl: Label
var code_lbl: Label
var status_lbl: Label
var server_lbl: Label
var start_btn: Button

func configure(manager) -> void:
	session_manager = manager
	if is_inside_tree():
		_connect_manager()
		_refresh()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_connect_manager()
	_refresh()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.10)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 380)
	panel.add_theme_stylebox_override("panel", _flat_style(Color(0.11, 0.11, 0.16), 8, 12))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	title_lbl = _lbl("Online Lobby", true, 36)
	vbox.add_child(title_lbl)

	server_lbl = _lbl("")
	server_lbl.add_theme_color_override("font_color", Color(0.68, 0.70, 0.78))
	vbox.add_child(server_lbl)

	code_lbl = _lbl("Room Code: ----", true, 30)
	code_lbl.add_theme_color_override("font_color", Color(0.96, 0.84, 0.34))
	vbox.add_child(code_lbl)

	status_lbl = _lbl("Waiting for connection…", false, 22)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_lbl)

	var tip_lbl := _lbl("Share the room code with your friend. The host can start once the guest is connected.", false, 18)
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_lbl.add_theme_color_override("font_color", Color(0.74, 0.74, 0.82))
	vbox.add_child(tip_lbl)

	vbox.add_child(_expand_spacer())

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	start_btn = Button.new()
	start_btn.text = "Start Match"
	start_btn.custom_minimum_size = Vector2(170, 50)
	_style_btn(start_btn, Color(0.18, 0.45, 0.22))
	start_btn.pressed.connect(func() -> void:
		start_requested.emit()
	)
	btn_row.add_child(start_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(140, 50)
	_style_btn(cancel_btn, Color(0.35, 0.18, 0.18))
	cancel_btn.pressed.connect(func() -> void:
		cancel_requested.emit()
	)
	btn_row.add_child(cancel_btn)

func _connect_manager() -> void:
	if session_manager == null:
		return
	if not session_manager.room_state_updated.is_connected(_on_room_state_updated):
		session_manager.room_state_updated.connect(_on_room_state_updated)
	if not session_manager.request_failed.is_connected(_on_request_failed):
		session_manager.request_failed.connect(_on_request_failed)

func _refresh() -> void:
	if session_manager == null:
		return
	server_lbl.text = "Server: %s" % session_manager.backend_url
	code_lbl.text = "Room Code: %s" % (session_manager.room_code if session_manager.room_code != "" else "----")
	if session_manager.is_host():
		title_lbl.text = "Host Online Game"
		start_btn.visible = true
		start_btn.disabled = not session_manager.guest_present
		status_lbl.text = "Waiting for your friend to join…" if not session_manager.guest_present else "Guest connected. Start the match when ready."
	else:
		title_lbl.text = "Join Online Game"
		start_btn.visible = false
		status_lbl.text = "Joined room. Waiting for the host to start the match." if session_manager.guest_present else "Connecting to host…"

func _on_room_state_updated(_state: Dictionary) -> void:
	_refresh()

func _on_request_failed(message: String) -> void:
	status_lbl.text = message

func _flat_style(color: Color, radius: int = 4, margin: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func _style_btn(btn: Button, color: Color) -> void:
	btn.add_theme_stylebox_override("normal", _flat_style(color, 6, 8))
	btn.add_theme_stylebox_override("hover", _flat_style(color.lightened(0.15), 6, 8))
	btn.add_theme_stylebox_override("pressed", _flat_style(color.darkened(0.12), 6, 8))
	btn.add_theme_font_size_override("font_size", UITheme.font_size(18))
	btn.add_theme_color_override("font_color", Color.WHITE)

func _lbl(text: String, bold: bool = false, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", UITheme.font_size(font_size))
	if bold:
		label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.76))
	return label

func _expand_spacer() -> Control:
	var control := Control.new()
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return control

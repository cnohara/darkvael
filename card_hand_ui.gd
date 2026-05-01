class_name CardHandUI
extends Control

signal select_mode_requested(hand_index: int, mode: String)
signal deselect_requested(selected_index: int)
signal reorder_requested(selected_index: int, direction: int)
signal ready_requested

const CARD_SIZE := Vector2(150, 196)
const PREVIEW_RISE := 118.0
const HOVER_RISE := 28.0
const FAN_ROTATION_MAX := 14.0

var _player: PlayerState = null
var _can_edit := false
var _show_hand := false
var _active_selected_index := -1
var _preview_index := -1
var _hover_index := -1
var _animate_deal_pending := false

var _backdrop: PanelContainer
var _selected_area: Control
var _selected_title: Label
var _ready_btn: Button
var _hand_area: Control
var _preview_actions: HBoxContainer

var _hand_nodes: Array = []
var _selected_nodes: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

	_backdrop = PanelContainer.new()
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.anchor_top = 1.0
	_backdrop.anchor_right = 1.0
	_backdrop.anchor_bottom = 1.0
	_backdrop.offset_top = -250.0
	_backdrop.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.05, 0.09, 0.78), 24, 16))
	add_child(_backdrop)

	_selected_title = Label.new()
	_selected_title.text = "Queued Actions"
	_selected_title.add_theme_font_size_override("font_size", UITheme.font_size(16))
	_selected_title.add_theme_color_override("font_color", Color(0.94, 0.87, 0.68))
	_selected_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_selected_title)

	_selected_area = Control.new()
	_selected_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_selected_area)

	_ready_btn = Button.new()
	_ready_btn.text = "Ready"
	_ready_btn.custom_minimum_size = Vector2(124, 40)
	_ready_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_ready_btn.pressed.connect(func() -> void:
		ready_requested.emit()
	)
	add_child(_ready_btn)

	_hand_area = Control.new()
	_hand_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_area)

	_preview_actions = HBoxContainer.new()
	_preview_actions.visible = false
	_preview_actions.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_actions.add_theme_constant_override("separation", 10)
	add_child(_preview_actions)

	for action in [
		{"label": "Use Ability", "mode": "normal", "color": Color(0.32, 0.22, 0.52)},
		{"label": "Move 1", "mode": "rotated_move", "color": Color(0.18, 0.40, 0.28)},
		{"label": "Block 1", "mode": "rotated_block", "color": Color(0.16, 0.34, 0.46)},
	]:
		var action_color: Color = action["color"]
		var btn := Button.new()
		btn.text = String(action["label"])
		btn.custom_minimum_size = Vector2(118, 34)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.set_meta("mode", String(action["mode"]))
		btn.pressed.connect(_on_preview_action_pressed.bind(String(action["mode"])))
		btn.add_theme_font_size_override("font_size", UITheme.font_size(13))
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_stylebox_override("normal", _panel_style(action_color, 8, 8))
		btn.add_theme_stylebox_override("hover", _panel_style(action_color.lightened(0.12), 8, 8))
		btn.add_theme_stylebox_override("pressed", _panel_style(action_color.darkened(0.12), 8, 8))
		_preview_actions.add_child(btn)

	_update_layout(false)

func set_view(player: PlayerState, can_edit: bool, show_hand: bool, active_selected_index: int = -1, animate_deal: bool = false) -> void:
	var previous_seat := _player.seat_index if _player != null else -1
	_player = player
	_can_edit = can_edit
	_show_hand = show_hand
	_active_selected_index = active_selected_index
	_animate_deal_pending = animate_deal
	if _player == null:
		_preview_index = -1
		_hover_index = -1
	elif previous_seat != _player.seat_index:
		_preview_index = -1
		_hover_index = -1
	if _preview_index >= 0 and (_player == null or _preview_index >= _player.hand.size() or not _show_hand):
		_preview_index = -1
	if _hover_index >= 0 and (_player == null or _hover_index >= _player.hand.size() or not _show_hand):
		_hover_index = -1
	_refresh()

func preview_hand_index(hand_index: int) -> void:
	if not _show_hand or not _can_edit or _player == null:
		return
	if hand_index < 0 or hand_index >= _player.hand.size():
		return
	_preview_index = hand_index
	_update_layout(true)

func clear_preview() -> void:
	if _preview_index < 0:
		return
	_preview_index = -1
	_update_layout(true)

func set_hover_hand_index(hand_index: int) -> void:
	if not _show_hand or not _can_edit or _player == null:
		return
	if hand_index < 0 or hand_index >= _player.hand.size():
		return
	if _hover_index == hand_index:
		return
	_hover_index = hand_index
	_update_layout(true)

func clear_hover_hand_index(hand_index: int = -1) -> void:
	if hand_index >= 0 and _hover_index != hand_index:
		return
	if _hover_index < 0:
		return
	_hover_index = -1
	_update_layout(true)

func _unhandled_input(event: InputEvent) -> void:
	if _preview_index < 0 or not _show_hand:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if _point_inside_hand(mb.position) or _point_inside_actions(mb.position):
			return
		clear_preview()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _backdrop != null:
		_update_layout(false)

func _refresh() -> void:
	visible = _player != null
	_backdrop.visible = visible and (_show_hand or _player.selected.size() > 0)
	_selected_area.visible = visible and _player.selected.size() > 0
	_selected_title.visible = visible and _player.selected.size() > 0
	_hand_area.visible = visible and _show_hand
	_ready_btn.visible = visible and _show_hand
	if not visible:
		_preview_actions.visible = false
		return

	_ready_btn.text = "Unready" if _player.ready else "Ready"
	_ready_btn.disabled = not _can_edit or _player.selected.is_empty()
	_apply_button_style(_ready_btn, Color(0.20, 0.46, 0.24) if not _player.ready else Color(0.50, 0.28, 0.18))

	_sync_hand_nodes()
	_sync_selected_nodes()
	_update_layout(_animate_deal_pending)
	_animate_deal_pending = false

func _sync_hand_nodes() -> void:
	var count := _player.hand.size() if _player != null and _show_hand else 0
	while _hand_nodes.size() < count:
		var node := _make_hand_card_node(_hand_nodes.size())
		_hand_area.add_child(node["root"])
		_hand_nodes.append(node)
	while _hand_nodes.size() > count:
		var tail: Dictionary = _hand_nodes.pop_back()
		(tail["root"] as Control).queue_free()
	for i in range(_hand_nodes.size()):
		var node: Dictionary = _hand_nodes[i]
		var card: CardData = _player.hand[i] as CardData
		node["root"].visible = true
		node["root"].set_meta("hand_index", i)
		var panel := node["panel"] as PanelContainer
		panel.mouse_filter = Control.MOUSE_FILTER_STOP if _can_edit else Control.MOUSE_FILTER_IGNORE
		_refresh_card_panel(panel, card, false, false)

func _sync_selected_nodes() -> void:
	var count := _player.selected.size() if _player != null else 0
	while _selected_nodes.size() < count:
		var node := _make_selected_card_node(_selected_nodes.size())
		_selected_area.add_child(node["root"])
		_selected_nodes.append(node)
	while _selected_nodes.size() > count:
		var tail: Dictionary = _selected_nodes.pop_back()
		(tail["root"] as Control).queue_free()
	for i in range(_selected_nodes.size()):
		var node: Dictionary = _selected_nodes[i]
		var card: CardData = _player.selected[i] as CardData
		node["root"].visible = true
		node["root"].set_meta("selected_index", i)
		var left_btn: Button = node["left_btn"] as Button
		var right_btn: Button = node["right_btn"] as Button
		var panel := node["panel"] as PanelContainer
		panel.mouse_filter = Control.MOUSE_FILTER_STOP if (_show_hand and _can_edit) else Control.MOUSE_FILTER_IGNORE
		left_btn.visible = _show_hand and _can_edit and i > 0
		right_btn.visible = _show_hand and _can_edit and i < (_selected_nodes.size() - 1)
		_refresh_card_panel(panel, card, true, i == _active_selected_index)

func _update_layout(animated: bool) -> void:
	if not is_inside_tree():
		return
	var scale_factor := clampf(size.x / 1600.0, 0.82, 1.0)
	var card_size := CARD_SIZE * scale_factor
	var selected_card_size := card_size * 0.84
	_backdrop.offset_top = -maxf(232.0, card_size.y + 84.0)
	_backdrop.offset_left = 96.0
	_backdrop.offset_right = -96.0
	_backdrop.offset_bottom = -8.0

	var selected_header_y := size.y - selected_card_size.y - 88.0
	var selected_y := size.y - selected_card_size.y - 30.0
	var hand_center := Vector2(size.x * 0.5, size.y - card_size.y * 0.18)
	var selected_total_width := 0.0
	if _selected_nodes.size() > 0:
		selected_total_width = float(_selected_nodes.size()) * selected_card_size.x + float(maxi(_selected_nodes.size() - 1, 0)) * 34.0
	_selected_title.position = Vector2(28.0, selected_header_y)
	_layout_selected_nodes(selected_card_size, selected_y, animated)
	_layout_ready_button(selected_header_y, selected_total_width, animated)
	_layout_hand_nodes(card_size, hand_center, animated)
	_layout_preview_actions(card_size, animated)

func _layout_selected_nodes(card_size: Vector2, selected_y: float, animated: bool) -> void:
	var gap := 34.0
	var start_x := 28.0
	for i in range(_selected_nodes.size()):
		var node: Dictionary = _selected_nodes[i]
		var root := node["root"] as Control
		var panel := node["panel"] as PanelContainer
		root.size = card_size + Vector2(0, 28)
		panel.size = card_size
		panel.position = Vector2.ZERO
		panel.pivot_offset = card_size * 0.5
		var target_pos := Vector2(start_x + float(i) * (card_size.x + gap), selected_y)
		panel.rotation_degrees = 0.0
		panel.scale = Vector2.ONE
		root.z_index = 40 + i
		if animated:
			var tw := create_tween()
			tw.set_ease(Tween.EASE_OUT)
			tw.set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(root, "position", target_pos, 0.18)
		else:
			root.position = target_pos
		var left_btn: Button = node["left_btn"] as Button
		var right_btn: Button = node["right_btn"] as Button
		left_btn.position = Vector2(4, card_size.y + 2)
		right_btn.position = Vector2(card_size.x - right_btn.custom_minimum_size.x - 4, card_size.y + 2)

func _layout_ready_button(selected_header_y: float, selected_total_width: float, animated: bool) -> void:
	var title_size := _selected_title.get_combined_minimum_size()
	var button_pos := Vector2(maxf(272.0, 48.0 + title_size.x + 32.0), selected_header_y - 10.0)
	if animated:
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(_ready_btn, "position", button_pos, 0.18)
	else:
		_ready_btn.position = button_pos

func _layout_hand_nodes(card_size: Vector2, hand_center: Vector2, animated: bool) -> void:
	var count := _hand_nodes.size()
	var total_span := minf(size.x * 0.42, maxf(card_size.x * 0.62 * float(maxi(count - 1, 1)), card_size.x * 2.2))
	for i in range(count):
		var node: Dictionary = _hand_nodes[i]
		var root := node["root"] as Control
		var panel := node["panel"] as PanelContainer
		root.size = card_size
		panel.size = card_size
		panel.position = Vector2.ZERO
		panel.pivot_offset = card_size * 0.5
		var ratio := 0.0 if count <= 1 else float(i) / float(count - 1)
		var arc_t := lerpf(-1.0, 1.0, ratio)
		var target_pos := Vector2(
			hand_center.x - card_size.x * 0.5 + arc_t * total_span * 0.5,
			hand_center.y - card_size.y * 0.5 + absf(arc_t) * 44.0
		)
		var target_rotation := arc_t * FAN_ROTATION_MAX
		var target_scale := Vector2.ONE
		if i == _preview_index:
			target_pos.y -= PREVIEW_RISE
			target_rotation = 0.0
			target_scale = Vector2(1.16, 1.16)
			root.z_index = 120
		elif i == _hover_index:
			target_pos.y -= HOVER_RISE
			target_scale = Vector2(1.05, 1.05)
			root.z_index = 92 + i
		else:
			root.z_index = 60 + i
		root.set_meta("layout_target_pos", target_pos)
		if animated:
			var tw := create_tween()
			tw.set_ease(Tween.EASE_OUT)
			tw.set_trans(Tween.TRANS_CUBIC)
			if _animate_deal_pending:
				root.position = Vector2(hand_center.x - card_size.x * 0.5, size.y + 80.0 + float(i) * 12.0)
				panel.rotation_degrees = 0.0
				panel.scale = Vector2(0.92, 0.92)
				tw.tween_interval(float(i) * 0.03)
			tw.tween_property(root, "position", target_pos, 0.24)
			tw.parallel().tween_property(panel, "rotation_degrees", target_rotation, 0.24)
			tw.parallel().tween_property(panel, "scale", target_scale, 0.24)
		else:
			root.position = target_pos
			panel.rotation_degrees = target_rotation
			panel.scale = target_scale

func _layout_preview_actions(card_size: Vector2, animated: bool) -> void:
	if _preview_index < 0 or not _show_hand or _preview_index >= _hand_nodes.size():
		_preview_actions.visible = false
		return
	_preview_actions.visible = true
	var preview_root: Control = (_hand_nodes[_preview_index] as Dictionary)["root"] as Control
	var preview_target_pos: Vector2 = preview_root.get_meta("layout_target_pos", preview_root.position)
	var actions_size := _preview_actions.get_combined_minimum_size()
	var button_gap := 18.0
	var action_pos := Vector2(
		clampf(preview_target_pos.x + card_size.x * 0.5 - actions_size.x * 0.5, 16.0, size.x - actions_size.x - 16.0),
		maxf(16.0, preview_target_pos.y - actions_size.y - button_gap)
	)
	if animated:
		var tw := create_tween()
		tw.set_ease(Tween.EASE_OUT)
		tw.set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(_preview_actions, "position", action_pos, 0.18)
	else:
		_preview_actions.position = action_pos
	for child in _preview_actions.get_children():
		var btn := child as Button
		if btn == null:
			continue
		var mode := String(btn.get_meta("mode"))
		btn.disabled = not _action_enabled(mode)

func _action_enabled(mode: String) -> bool:
	if _player == null or _preview_index < 0 or _preview_index >= _player.hand.size():
		return false
	if not _can_edit:
		return false
	var card: CardData = _player.hand[_preview_index] as CardData
	match mode:
		"normal":
			return _player.can_select(card)
		"rotated_move":
			return _player.can_select(CardData.create_rotate_move_card(card.card_name, card.initiative))
		"rotated_block":
			return _player.can_select(CardData.create_rotate_block_card(card.card_name, card.initiative))
	return false

func _on_preview_action_pressed(mode: String) -> void:
	if _preview_index < 0:
		return
	var hand_index := _preview_index
	_preview_index = -1
	_update_layout(true)
	select_mode_requested.emit(hand_index, mode)

func _make_hand_card_node(hand_index: int) -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := _make_card_panel()
	panel.gui_input.connect(_on_hand_card_gui_input.bind(hand_index))
	panel.mouse_entered.connect(_on_hand_card_mouse_entered.bind(hand_index))
	panel.mouse_exited.connect(_on_hand_card_mouse_exited.bind(hand_index))
	root.add_child(panel)
	return {
		"root": root,
		"panel": panel,
	}

func _make_selected_card_node(selected_index: int) -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := _make_card_panel()
	panel.gui_input.connect(_on_selected_card_gui_input.bind(selected_index))
	root.add_child(panel)

	var left_btn := _make_mini_button("←")
	left_btn.pressed.connect(func() -> void:
		reorder_requested.emit(int(root.get_meta("selected_index", selected_index)), -1)
	)
	root.add_child(left_btn)

	var right_btn := _make_mini_button("→")
	right_btn.pressed.connect(func() -> void:
		reorder_requested.emit(int(root.get_meta("selected_index", selected_index)), 1)
	)
	root.add_child(right_btn)

	return {
		"root": root,
		"panel": panel,
		"left_btn": left_btn,
		"right_btn": right_btn,
	}

func _make_card_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var badge := Label.new()
	badge.visible = false
	badge.add_theme_font_size_override("font_size", UITheme.font_size(11))
	badge.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
	vbox.add_child(badge)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", UITheme.font_size(15))
	name_lbl.add_theme_color_override("font_color", Color(0.94, 0.94, 0.98))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)

	var meta_lbl := Label.new()
	meta_lbl.add_theme_font_size_override("font_size", UITheme.font_size(12))
	meta_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.48))
	vbox.add_child(meta_lbl)

	var fx_lbl := Label.new()
	fx_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fx_lbl.add_theme_font_size_override("font_size", UITheme.font_size(12))
	fx_lbl.add_theme_color_override("font_color", Color(0.78, 0.80, 0.86))
	fx_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vbox.add_child(fx_lbl)

	panel.set_meta("badge_lbl", badge)
	panel.set_meta("name_lbl", name_lbl)
	panel.set_meta("meta_lbl", meta_lbl)
	panel.set_meta("fx_lbl", fx_lbl)
	_refresh_card_panel(panel, null, false, false)
	return panel

func _refresh_card_panel(panel: PanelContainer, card: CardData, selected: bool, active: bool) -> void:
	var badge_lbl: Label = panel.get_meta("badge_lbl") as Label
	var name_lbl: Label = panel.get_meta("name_lbl") as Label
	var meta_lbl: Label = panel.get_meta("meta_lbl") as Label
	var fx_lbl: Label = panel.get_meta("fx_lbl") as Label
	var bg := Color(0.08, 0.10, 0.16, 0.96)
	var border := Color(0.24, 0.28, 0.40, 0.90)
	if card != null:
		match card.selection_mode():
			"rotated_move":
				bg = Color(0.10, 0.24, 0.16, 0.98)
				border = Color(0.48, 0.88, 0.64, 0.92)
			"rotated_block":
				bg = Color(0.08, 0.18, 0.26, 0.98)
				border = Color(0.50, 0.80, 0.96, 0.92)
			_:
				bg = Color(0.14, 0.15, 0.24, 0.98) if selected else Color(0.10, 0.12, 0.19, 0.96)
				border = Color(0.50, 0.66, 0.98, 0.90) if selected else Color(0.26, 0.30, 0.42, 0.90)
	if active:
		bg = bg.lightened(0.18)
		border = Color(1.0, 0.92, 0.40, 0.98)
	var style := _panel_style(bg, 16, 12)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border
	panel.add_theme_stylebox_override("panel", style)

	if card == null:
		badge_lbl.visible = false
		name_lbl.text = ""
		meta_lbl.text = ""
		fx_lbl.text = ""
		return

	var title := card.original_card_name() if card.selection_mode() != "normal" else card.card_name
	name_lbl.text = title
	meta_lbl.text = "Cost %d   Init %d" % [card.effective_cost(), card.effective_initiative()]
	fx_lbl.text = card.effective_action_text()
	match card.selection_mode():
		"rotated_move":
			badge_lbl.visible = true
			badge_lbl.text = "MOVE 1"
		"rotated_block":
			badge_lbl.visible = true
			badge_lbl.text = "BLOCK 1"
		_:
			badge_lbl.visible = false

func _on_hand_card_gui_input(event: InputEvent, hand_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	preview_hand_index(int((_hand_nodes[hand_index] as Dictionary)["root"].get_meta("hand_index", hand_index)))
	accept_event()

func _on_hand_card_mouse_entered(hand_index: int) -> void:
	if hand_index >= _hand_nodes.size():
		return
	set_hover_hand_index(int((_hand_nodes[hand_index] as Dictionary)["root"].get_meta("hand_index", hand_index)))

func _on_hand_card_mouse_exited(hand_index: int) -> void:
	if hand_index >= _hand_nodes.size():
		return
	clear_hover_hand_index(int((_hand_nodes[hand_index] as Dictionary)["root"].get_meta("hand_index", hand_index)))

func _on_selected_card_gui_input(event: InputEvent, selected_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	if not _show_hand or not _can_edit:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	deselect_requested.emit(int((_selected_nodes[selected_index] as Dictionary)["root"].get_meta("selected_index", selected_index)))
	accept_event()

func _point_inside_hand(point: Vector2) -> bool:
	for node in _hand_nodes:
		var root := (node as Dictionary)["root"] as Control
		if not root.visible:
			continue
		var rect := Rect2(root.global_position, root.size)
		if rect.has_point(point):
			return true
	return false

func _point_inside_actions(point: Vector2) -> bool:
	return _preview_actions.visible and Rect2(_preview_actions.global_position, _preview_actions.size).has_point(point)

func _make_mini_button(text_value: String) -> Button:
	var btn := Button.new()
	btn.text = text_value
	btn.custom_minimum_size = Vector2(28, 22)
	btn.add_theme_font_size_override("font_size", UITheme.font_size(12))
	btn.add_theme_color_override("font_color", Color.WHITE)
	_apply_button_style(btn, Color(0.22, 0.26, 0.36))
	return btn

func _apply_button_style(btn: Button, color: Color) -> void:
	btn.add_theme_stylebox_override("normal", _panel_style(color, 8, 8))
	btn.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.12), 8, 8))
	btn.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.12), 8, 8))

func _panel_style(color: Color, radius: int = 8, margin: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

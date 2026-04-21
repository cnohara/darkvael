extends Control

signal return_to_title
signal move_dest_chosen(pos: Vector2i)
signal attack_target_chosen(enemy_idx: int)
signal next_round_confirmed

const CARD_PANEL_SIZE := Vector2(102, 104)
const PLAYER_PANEL_WIDTH := 540
const PLAYER_MAX_SELECTED := 3
const PLAYER_HAND_SIZE := 5
const ACTIVE_PLAYER_COLOR := Color(0.16, 0.28, 0.48)
const READY_PLAYER_COLOR := Color(0.16, 0.34, 0.22)
const INACTIVE_PLAYER_COLOR := Color(0.10, 0.13, 0.20)
const DEAD_PLAYER_COLOR := Color(0.24, 0.10, 0.10)
const STAMINA_BASE_COLOR := Color(0.90, 0.75, 0.30)
const STAMINA_SPEND_COLOR := Color(1.00, 0.95, 0.45)
const STAMINA_REFUND_COLOR := Color(0.72, 0.95, 0.55)
const HP_BASE_COLOR := Color(0.42, 0.92, 0.54)
const HP_GAIN_COLOR := Color(0.72, 1.00, 0.78)
const HP_LOSS_COLOR := Color(1.00, 0.58, 0.58)
const BLOCK_BASE_COLOR := Color(0.52, 0.72, 0.98)
const BLOCK_PULSE_COLOR := Color(0.78, 0.90, 1.00)
const STATUS_BASE_COLOR := Color(0.95, 0.82, 0.34)
const STATUS_PULSE_COLOR := Color(1.00, 0.94, 0.62)
const ENEMY_HP_BASE_COLOR := Color(0.92, 0.40, 0.40)
const ENEMY_STATUS_BASE_COLOR := Color(0.88, 0.82, 0.48)
const ENEMY_PANEL_BASE_COLOR := Color(0.18, 0.09, 0.09)
const ENEMY_PANEL_TARGETABLE_COLOR := Color(0.40, 0.26, 0.08)
const ENEMY_PANEL_ACTIVE_COLOR := Color(0.70, 0.56, 0.12)

var requested_player_count := 1
var bs: BattleState
var ui_locked := false
var highlighted_tiles: Array = []
var _pending_move_player_index := -1
var _pending_attack_player_index := -1
var _targetable_enemy_indices: Array = []
var _active_target_enemy_idx := -1
var _enemy_panel_target_tweens: Dictionary = {}
var _board_zoom_size := Board3D.ZOOM_MIN
var online_session = null
var online_enabled := false
var online_is_host := false
var owned_seat_index := 0
var _last_guest_snapshot_revision := -1
var _level_up_queue: Array = []

var round_lbl: Label
var phase_lbl: Label
var active_player_lbl: Label
var order_lbl: Label
var _turn_order_row: Control = null
var planning_hint_lbl: Label
var prev_player_btn: Button
var next_player_btn: Button
var next_round_btn: Button

var board_3d: Board3D = null
var _enemy_panels: Array = []
var _enemy_hp_lbls: Array = []
var _enemy_block_lbls: Array = []
var _enemy_status_lbls: Array = []
var _enemy_behavior_lbls: Array = []
var _enemy_deck_lbls: Array = []
var _enemy_hp_tweens: Array = []
var _enemy_block_tweens: Array = []
var _enemy_status_tweens: Array = []
var _enemy_prev_hp: Array = []
var _enemy_prev_block: Array = []
var _enemy_prev_status: Array = []
var end_overlay: Control = null
var log_lbl: Label
var _screen_flash: ColorRect = null
var _active_resolving_seat := -1
var _active_resolving_card := -1

var _player_cards: Array = []
var _rotate_btns: Array = []  # Move rotation buttons: Array[Array[Button]] per seat per hand slot
var _rotate_block_btns: Array = []  # Block rotation buttons: Array[Array[Button]] per seat per hand slot

func configure_battle(player_count: int) -> void:
	requested_player_count = clampi(player_count, 1, BattleState.MAX_PLAYERS)
	if is_inside_tree():
		_start_battle()

func configure_online(session) -> void:
	online_session = session
	online_enabled = session != null and session.is_online()
	online_is_host = online_enabled and session.is_host()
	owned_seat_index = session.seat_index if session != null else 0
	requested_player_count = 2
	if is_inside_tree():
		_start_battle()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bs = BattleState.new()
	_build_ui()
	_connect_online_session()
	_start_battle()

func _connect_online_session() -> void:
	if online_session == null:
		return
	if not online_session.room_state_updated.is_connected(_on_online_room_state_updated):
		online_session.room_state_updated.connect(_on_online_room_state_updated)
	if not online_session.command_received.is_connected(_on_online_command_received):
		online_session.command_received.connect(_on_online_command_received)
	if not online_session.request_failed.is_connected(_on_online_request_failed):
		online_session.request_failed.connect(_on_online_request_failed)

func _input(event: InputEvent) -> void:
	if board_3d:
		if event is InputEventMagnifyGesture:
			board_3d.adjust_zoom(event.factor)
			_board_zoom_size = board_3d.get_zoom_size()
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				board_3d.adjust_zoom(1.12)
				_board_zoom_size = board_3d.get_zoom_size()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				board_3d.adjust_zoom(0.89)
				_board_zoom_size = board_3d.get_zoom_size()

	if event is InputEventKey and event.pressed:
		if ui_locked or bs.current_phase != BattleState.Phase.SELECT:
			return
		match event.keycode:
			KEY_1: _try_select_hand(_active_player(), 0)
			KEY_2: _try_select_hand(_active_player(), 1)
			KEY_3: _try_select_hand(_active_player(), 2)
			KEY_4: _try_select_hand(_active_player(), 3)
			KEY_5: _try_select_hand(_active_player(), 4)
			KEY_TAB:
				_focus_unready_player(1)
			KEY_ENTER, KEY_KP_ENTER:
				_toggle_player_ready(_active_player())

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	_build_top_bar(root)
	_build_main_row(root)
	_build_log(root)

	_screen_flash = ColorRect.new()
	_screen_flash.color = Color(0.75, 0.05, 0.05, 0.0)
	_screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_flash)

func _build_top_bar(parent: Control) -> void:
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 4)
	parent.add_child(top)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	top.add_child(row)

	round_lbl = _lbl("Round: 1", true)
	row.add_child(round_lbl)

	phase_lbl = _lbl("Phase: Setup")
	phase_lbl.add_theme_color_override("font_color", Color(0.62, 0.80, 0.95))
	row.add_child(phase_lbl)

	row.add_child(_expand_spacer())

	prev_player_btn = Button.new()
	prev_player_btn.text = "Prev Player"
	prev_player_btn.custom_minimum_size = Vector2(112, 34)
	_style_btn(prev_player_btn, Color(0.20, 0.26, 0.42))
	prev_player_btn.pressed.connect(func() -> void:
		_focus_unready_player(-1)
	)
	row.add_child(prev_player_btn)

	next_player_btn = Button.new()
	next_player_btn.text = "Next Player"
	next_player_btn.custom_minimum_size = Vector2(112, 34)
	_style_btn(next_player_btn, Color(0.20, 0.26, 0.42))
	next_player_btn.pressed.connect(func() -> void:
		_focus_unready_player(1)
	)
	row.add_child(next_player_btn)

	active_player_lbl = _lbl("Editing: Player 1")
	active_player_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.34))
	row.add_child(active_player_lbl)

	order_lbl = _lbl("Order: -")
	order_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(order_lbl)

	_turn_order_row = Control.new()
	_turn_order_row.custom_minimum_size = Vector2(0, 82)
	_turn_order_row.visible = false
	top.add_child(_turn_order_row)

	planning_hint_lbl = _lbl("Each player has their own hand, selected row, and Ready button.")
	planning_hint_lbl.add_theme_color_override("font_color", Color(0.68, 0.70, 0.78))
	top.add_child(planning_hint_lbl)

func _build_main_row(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	_build_players_column(hbox)
	_build_board(hbox)
	_build_enemy_panel(hbox)

func _build_players_column(parent: Control) -> void:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(PLAYER_PANEL_WIDTH, 0)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_stylebox_override("panel", _flat_style(Color(0.10, 0.10, 0.14), 6, 6))
	parent.add_child(outer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	_player_cards.clear()
	_rotate_btns.clear()
	_rotate_block_btns.clear()
	for seat_index in range(BattleState.MAX_PLAYERS):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(PLAYER_PANEL_WIDTH - 24, 0)
		panel.visible = false
		vbox.add_child(panel)

		var panel_vbox := VBoxContainer.new()
		panel_vbox.add_theme_constant_override("separation", 4)
		panel.add_child(panel_vbox)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 6)
		panel_vbox.add_child(header)

		var name_lbl := _lbl("Player %d" % (seat_index + 1), true)
		header.add_child(name_lbl)

		var hp_lbl := _lbl("HP: 12/12")
		hp_lbl.add_theme_color_override("font_color", Color(0.42, 0.92, 0.54))
		header.add_child(hp_lbl)

		var block_lbl := _lbl("Block: 0")
		block_lbl.add_theme_color_override("font_color", Color(0.52, 0.72, 0.98))
		header.add_child(block_lbl)

		var status_lbl := _lbl("")
		status_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.34))
		header.add_child(status_lbl)

		header.add_child(_expand_spacer())

		var focus_btn := Button.new()
		focus_btn.text = "Focus"
		focus_btn.custom_minimum_size = Vector2(72, 32)
		_style_btn(focus_btn, Color(0.22, 0.32, 0.52))
		focus_btn.pressed.connect(_on_focus_player.bind(seat_index))
		header.add_child(focus_btn)

		var ready_btn := Button.new()
		ready_btn.text = "Ready"
		ready_btn.custom_minimum_size = Vector2(84, 32)
		_style_btn(ready_btn, Color(0.18, 0.45, 0.22))
		ready_btn.pressed.connect(_on_ready_pressed.bind(seat_index))
		header.add_child(ready_btn)

		var meta_lbl := _lbl("Cleric  Lv1  XP:0  Draw: 16  Discard: 0  Init: -")
		meta_lbl.add_theme_color_override("font_color", Color(0.64, 0.66, 0.74))
		panel_vbox.add_child(meta_lbl)

		var stamina_holder := Control.new()
		stamina_holder.custom_minimum_size = Vector2(0, 26)
		panel_vbox.add_child(stamina_holder)

		var stamina_lbl := _lbl("Stamina: 3/3")
		stamina_lbl.add_theme_color_override("font_color", STAMINA_BASE_COLOR)
		stamina_holder.add_child(stamina_lbl)

		panel_vbox.add_child(_lbl("Selected:"))
		var selected_row := HBoxContainer.new()
		selected_row.add_theme_constant_override("separation", 4)
		panel_vbox.add_child(selected_row)

		var selected_cards: Array = []
		var selected_left_btns: Array = []
		var selected_right_btns: Array = []
		for card_idx in range(PLAYER_MAX_SELECTED):
			var slot_box := VBoxContainer.new()
			slot_box.add_theme_constant_override("separation", 2)
			selected_row.add_child(slot_box)

			var card_panel := _make_card_panel()
			card_panel.gui_input.connect(_on_selected_card_input.bind(seat_index, card_idx))
			slot_box.add_child(card_panel)
			selected_cards.append(card_panel)

			var btn_row := HBoxContainer.new()
			btn_row.add_theme_constant_override("separation", 2)
			slot_box.add_child(btn_row)

			var left_btn := Button.new()
			left_btn.text = "←"
			left_btn.custom_minimum_size = Vector2(48, 28)
			_style_btn(left_btn, Color(0.26, 0.26, 0.34))
			left_btn.pressed.connect(_on_move_selected_pressed.bind(seat_index, card_idx, -1))
			btn_row.add_child(left_btn)
			selected_left_btns.append(left_btn)

			var right_btn := Button.new()
			right_btn.text = "→"
			right_btn.custom_minimum_size = Vector2(48, 28)
			_style_btn(right_btn, Color(0.26, 0.26, 0.34))
			right_btn.pressed.connect(_on_move_selected_pressed.bind(seat_index, card_idx, 1))
			btn_row.add_child(right_btn)
			selected_right_btns.append(right_btn)

		panel_vbox.add_child(_lbl("Hand:"))
		var hand_row := HBoxContainer.new()
		hand_row.add_theme_constant_override("separation", 4)
		panel_vbox.add_child(hand_row)

		var hand_cards: Array = []
		var seat_rotate_btns: Array = []
		var seat_rotate_block_btns: Array = []
		for hand_idx in range(PLAYER_HAND_SIZE):
			var slot_vbox := VBoxContainer.new()
			slot_vbox.add_theme_constant_override("separation", 2)
			hand_row.add_child(slot_vbox)

			var hand_panel := _make_card_panel()
			hand_panel.gui_input.connect(_on_hand_card_input.bind(seat_index, hand_idx))
			slot_vbox.add_child(hand_panel)
			hand_cards.append(hand_panel)

			var rot_btn := Button.new()
			rot_btn.text = "\u21bb Mv"
			rot_btn.custom_minimum_size = Vector2(102, 22)
			_style_btn(rot_btn, Color(0.28, 0.22, 0.44))
			rot_btn.add_theme_font_size_override("font_size", 14)
			rot_btn.pressed.connect(_try_rotate_card.bind(seat_index, hand_idx, "move"))
			slot_vbox.add_child(rot_btn)
			seat_rotate_btns.append(rot_btn)

			var block_btn := Button.new()
			block_btn.text = "\u21bb Blk"
			block_btn.custom_minimum_size = Vector2(102, 22)
			_style_btn(block_btn, Color(0.18, 0.32, 0.46))
			block_btn.add_theme_font_size_override("font_size", 14)
			block_btn.pressed.connect(_try_rotate_card.bind(seat_index, hand_idx, "block"))
			slot_vbox.add_child(block_btn)
			seat_rotate_block_btns.append(block_btn)

		_rotate_btns.append(seat_rotate_btns)
		_rotate_block_btns.append(seat_rotate_block_btns)

		_player_cards.append({
			"panel": panel,
			"name_lbl": name_lbl,
			"hp_lbl": hp_lbl,
			"block_lbl": block_lbl,
			"status_lbl": status_lbl,
			"hp_tween": null,
			"block_tween": null,
			"status_tween": null,
			"prev_hp": null,
			"prev_block": null,
			"prev_status": null,
			"meta_lbl": meta_lbl,
			"stamina_lbl": stamina_lbl,
			"stamina_tween": null,
			"focus_btn": focus_btn,
			"ready_btn": ready_btn,
			"selected_cards": selected_cards,
			"selected_left_btns": selected_left_btns,
			"selected_right_btns": selected_right_btns,
			"hand_cards": hand_cards,
		})

func _build_board(parent: Control) -> void:
	var svc := SubViewportContainer.new()
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.stretch = true
	parent.add_child(svc)

	var sv := SubViewport.new()
	sv.size = Vector2i(520, 420)
	sv.world_3d = World3D.new()
	sv.physics_object_picking = true
	sv.transparent_bg = false
	svc.add_child(sv)

	board_3d = Board3D.new()
	sv.add_child(board_3d)
	board_3d.setup()
	board_3d.set_zoom_size(_board_zoom_size)
	board_3d.tile_pressed.connect(_on_tile_pressed)
	board_3d.enemy_pressed.connect(_on_board_enemy_pressed)

func _build_enemy_panel(parent: Control) -> void:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(225, 0)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_stylebox_override("panel", _flat_style(Color(0.12, 0.08, 0.08), 6, 6))
	parent.add_child(outer)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_enemy_panels.clear()
	_enemy_hp_lbls.clear()
	_enemy_block_lbls.clear()
	_enemy_status_lbls.clear()
	_enemy_behavior_lbls.clear()
	_enemy_deck_lbls.clear()
	_enemy_hp_tweens.clear()
	_enemy_block_tweens.clear()
	_enemy_status_tweens.clear()
	_enemy_prev_hp.clear()
	_enemy_prev_block.clear()
	_enemy_prev_status.clear()

	for i in range(BattleState.MAX_ENEMIES):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _flat_style(ENEMY_PANEL_BASE_COLOR, 5, 6))
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_enemy_panel_input.bind(i))
		panel.visible = false
		vbox.add_child(panel)
		_enemy_panels.append(panel)

		var panel_vbox := VBoxContainer.new()
		panel_vbox.add_theme_constant_override("separation", 3)
		panel.add_child(panel_vbox)

		panel_vbox.add_child(_lbl("Enemy %d" % (i + 1), true))
		var hp_lbl := _lbl("HP: 6/6")
		hp_lbl.add_theme_color_override("font_color", ENEMY_HP_BASE_COLOR)
		panel_vbox.add_child(hp_lbl)
		_enemy_hp_lbls.append(hp_lbl)

		var block_lbl := _lbl("Block: 0")
		block_lbl.add_theme_color_override("font_color", Color(0.52, 0.72, 0.98))
		panel_vbox.add_child(block_lbl)
		_enemy_block_lbls.append(block_lbl)

		var status_lbl := _lbl("")
		status_lbl.add_theme_color_override("font_color", ENEMY_STATUS_BASE_COLOR)
		panel_vbox.add_child(status_lbl)
		_enemy_status_lbls.append(status_lbl)

		var behavior_lbl := _lbl("Intent: ?")
		behavior_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		behavior_lbl.custom_minimum_size = Vector2(0, 86)
		panel_vbox.add_child(behavior_lbl)
		_enemy_behavior_lbls.append(behavior_lbl)

		var deck_lbl := _lbl("Draw: 6  Discard: 0")
		deck_lbl.add_theme_color_override("font_color", Color(0.64, 0.66, 0.74))
		panel_vbox.add_child(deck_lbl)
		_enemy_deck_lbls.append(deck_lbl)
		_enemy_hp_tweens.append(null)
		_enemy_block_tweens.append(null)
		_enemy_status_tweens.append(null)
		_enemy_prev_hp.append(null)
		_enemy_prev_block.append(null)
		_enemy_prev_status.append(null)

func _build_log(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	log_lbl = Label.new()
	log_lbl.custom_minimum_size = Vector2(0, 120)
	log_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_lbl.add_theme_color_override("font_color", Color(0.76, 0.76, 0.84))
	log_lbl.add_theme_font_size_override("font_size", 18)
	log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(log_lbl)

	next_round_btn = Button.new()
	next_round_btn.text = "Next Round"
	next_round_btn.custom_minimum_size = Vector2(124, 40)
	next_round_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_btn(next_round_btn, Color(0.18, 0.38, 0.52))
	next_round_btn.visible = false
	next_round_btn.pressed.connect(_on_next_round_pressed)
	row.add_child(next_round_btn)

func _start_battle() -> void:
	_level_up_queue.clear()
	if online_enabled and not online_is_host:
		ui_locked = true
		highlighted_tiles.clear()
		_pending_move_player_index = -1
		_update_ui()
		return
	bs.setup(requested_player_count)
	ui_locked = false
	highlighted_tiles.clear()
	_pending_move_player_index = -1
	_clear_attack_targeting()
	bs.start_next_round()
	_update_ui()
	_sync_online_snapshot()

func _begin_next_round() -> void:
	_level_up_queue.clear()
	ui_locked = false
	highlighted_tiles.clear()
	_pending_move_player_index = -1
	_clear_attack_targeting()
	bs.start_next_round()
	_update_ui()
	_sync_online_snapshot()

func _update_ui() -> void:
	round_lbl.text = "Round: %d" % bs.round_number
	phase_lbl.text = "Phase: %s" % _phase_text(bs.current_phase)
	var multiplayer_ui: bool = bs.player_count > 1
	prev_player_btn.visible = multiplayer_ui
	next_player_btn.visible = multiplayer_ui
	next_round_btn.visible = bs.current_phase == BattleState.Phase.REFRESH
	next_round_btn.disabled = online_enabled and not online_is_host
	active_player_lbl.visible = multiplayer_ui
	active_player_lbl.text = "Editing: %s" % _active_player().name
	order_lbl.text = "Order: %s" % _actor_order_preview()
	planning_hint_lbl.text = _planning_hint_text()

	for enemy_idx in range(_enemy_panels.size()):
		if enemy_idx < bs.enemies.size():
			var enemy = bs.enemies[enemy_idx]
			var prev_enemy_hp = _enemy_prev_hp[enemy_idx]
			var prev_enemy_block = _enemy_prev_block[enemy_idx]
			var prev_enemy_status = _enemy_prev_status[enemy_idx]
			_enemy_panels[enemy_idx].visible = true
			_refresh_enemy_panel_visual(enemy_idx)
			_enemy_hp_lbls[enemy_idx].text = "HP: %d/%d  PA:%d" % [enemy.hp, enemy.max_hp, enemy.physical_armor]
			_enemy_block_lbls[enemy_idx].text = "%s  Block: %d" % [enemy.enemy_type, enemy.block]
			_enemy_status_lbls[enemy_idx].text = enemy.status_text()
			_enemy_prev_hp[enemy_idx] = enemy.hp
			_enemy_prev_block[enemy_idx] = enemy.block
			_enemy_prev_status[enemy_idx] = _enemy_status_lbls[enemy_idx].text
			if prev_enemy_hp != null and int(prev_enemy_hp) != enemy.hp:
				_pulse_enemy_stat_label(enemy_idx, _enemy_hp_lbls, _enemy_hp_tweens, ENEMY_HP_BASE_COLOR, HP_GAIN_COLOR if enemy.hp > int(prev_enemy_hp) else HP_LOSS_COLOR)
			if prev_enemy_block != null and int(prev_enemy_block) != enemy.block:
				_pulse_enemy_stat_label(enemy_idx, _enemy_block_lbls, _enemy_block_tweens, BLOCK_BASE_COLOR, BLOCK_PULSE_COLOR)
			if prev_enemy_status != null and String(prev_enemy_status) != _enemy_status_lbls[enemy_idx].text:
				_pulse_enemy_stat_label(enemy_idx, _enemy_status_lbls, _enemy_status_tweens, ENEMY_STATUS_BASE_COLOR, STATUS_PULSE_COLOR)
			if enemy.revealed != null:
				_enemy_behavior_lbls[enemy_idx].text = "Intent: %s\nInit %d\n%s" % [
					enemy.revealed.behavior_name,
					enemy.revealed.initiative,
					enemy.revealed.effect_text,
				]
			else:
				_enemy_behavior_lbls[enemy_idx].text = "Intent: ?"
			_enemy_deck_lbls[enemy_idx].text = "Draw: %d  Discard: %d  XP:%d" % [enemy.draw.size(), enemy.discard.size(), enemy.xp_reward]
		else:
			_enemy_panels[enemy_idx].visible = false
			_stop_enemy_panel_target_pulse(enemy_idx)
			_enemy_prev_hp[enemy_idx] = null
			_enemy_prev_block[enemy_idx] = null
			_enemy_prev_status[enemy_idx] = null

	for seat_index in range(_player_cards.size()):
		var ui := _player_cards[seat_index] as Dictionary
		var panel: PanelContainer = ui["panel"]
		panel.visible = seat_index < bs.players.size()
		if not panel.visible:
			continue

		var player = bs.get_player(seat_index)
		var prev_hp = ui["prev_hp"]
		var prev_block = ui["prev_block"]
		var prev_status = ui["prev_status"]
		ui["name_lbl"].text = "%s (%s)" % [player.name, player.hero_type]
		ui["hp_lbl"].text = "HP: %d/%d" % [player.hp, player.max_hp]
		ui["block_lbl"].text = "Block: %d" % player.block
		ui["status_lbl"].text = player.status_text()
		ui["prev_hp"] = player.hp
		ui["prev_block"] = player.block
		ui["prev_status"] = ui["status_lbl"].text
		ui["meta_lbl"].text = "Lv%d XP:%d/%d  Draw: %d  Discard: %d  Init: %s" % [
			player.level,
			player.xp,
			player.xp_for_next_level(),
			player.draw_pile.size(),
			player.discard_pile.size(),
			"-" if player.selected.is_empty() else str(player.initiative())
		]
		ui["stamina_lbl"].text = "Stamina: %d/%d" % [player.max_stamina - player.selected_stamina(), player.max_stamina]
		if prev_hp != null and int(prev_hp) != player.hp:
			_pulse_player_stat_label(ui, "hp_lbl", "hp_tween", HP_BASE_COLOR, HP_GAIN_COLOR if player.hp > int(prev_hp) else HP_LOSS_COLOR)
		if prev_block != null and int(prev_block) != player.block:
			_pulse_player_stat_label(ui, "block_lbl", "block_tween", BLOCK_BASE_COLOR, BLOCK_PULSE_COLOR)
		if prev_status != null and String(prev_status) != ui["status_lbl"].text:
			_pulse_player_stat_label(ui, "status_lbl", "status_tween", STATUS_BASE_COLOR, STATUS_PULSE_COLOR)

		var can_focus: bool = player.alive
		var can_edit = _player_is_editable(player)
		var panel_color = INACTIVE_PLAYER_COLOR
		if not player.alive:
			panel_color = DEAD_PLAYER_COLOR
		elif player.ready:
			panel_color = READY_PLAYER_COLOR
		elif seat_index == bs.selected_planning_player_index:
			panel_color = ACTIVE_PLAYER_COLOR
		panel.add_theme_stylebox_override("panel", _flat_style(panel_color, 6, 6))

		var focus_btn: Button = ui["focus_btn"]
		focus_btn.disabled = not can_focus

		var ready_btn: Button = ui["ready_btn"]
		ready_btn.disabled = ui_locked or bs.current_phase != BattleState.Phase.SELECT or not player.alive
		ready_btn.text = "Unready" if player.ready else "Ready"
		_style_btn(ready_btn, Color(0.54, 0.30, 0.18) if player.ready else Color(0.18, 0.45, 0.22))

		var selected_cards: Array = ui["selected_cards"]
		var left_btns: Array = ui["selected_left_btns"]
		var right_btns: Array = ui["selected_right_btns"]
		for card_idx in range(PLAYER_MAX_SELECTED):
			var selected_card: CardData = player.selected[card_idx] if card_idx < player.selected.size() else null
			var active_card := seat_index == _active_resolving_seat and card_idx == _active_resolving_card
			_refresh_card_panel(selected_cards[card_idx], selected_card, selected_card != null, active_card)
			selected_cards[card_idx].mouse_filter = Control.MOUSE_FILTER_STOP if can_edit else Control.MOUSE_FILTER_IGNORE
			left_btns[card_idx].disabled = not can_edit or selected_card == null or card_idx == 0
			right_btns[card_idx].disabled = not can_edit or selected_card == null or card_idx >= player.selected.size() - 1

		var hand_cards: Array = ui["hand_cards"]
		for hand_idx in range(PLAYER_HAND_SIZE):
			var hand_card: CardData = player.hand[hand_idx] if hand_idx < player.hand.size() else null
			_refresh_card_panel(hand_cards[hand_idx], hand_card, false)
			var filter := Control.MOUSE_FILTER_STOP if can_edit else Control.MOUSE_FILTER_IGNORE
			hand_cards[hand_idx].mouse_filter = filter
			if seat_index < _rotate_btns.size() and hand_idx < _rotate_btns[seat_index].size():
				var rot_btn: Button = _rotate_btns[seat_index][hand_idx]
				rot_btn.visible = can_edit and hand_card != null
				rot_btn.disabled = not can_edit or hand_card == null or not player.can_select(CardData.create_rotate_move_card(hand_card.card_name, hand_card.initiative))
			if seat_index < _rotate_block_btns.size() and hand_idx < _rotate_block_btns[seat_index].size():
				var block_btn: Button = _rotate_block_btns[seat_index][hand_idx]
				block_btn.visible = can_edit and hand_card != null
				block_btn.disabled = not can_edit or hand_card == null or not player.can_select(CardData.create_rotate_block_card(hand_card.card_name, hand_card.initiative))

	_update_board()
	var log_lines: Array = bs.combat_log.slice(maxi(0, bs.combat_log.size() - 8))
	log_lbl.text = "\n".join(log_lines)
	_sync_online_snapshot()

func _update_board() -> void:
	if board_3d == null:
		return
	var player_positions: Array = []
	for player in bs.players:
		player_positions.append(player.pos if player.alive else Vector2i(-1, -1))
	var enemy_positions: Array = []
	for enemy in bs.enemies:
		enemy_positions.append(enemy.pos if enemy.alive else Vector2i(-1, -1))
	var active_idx: int = bs.selected_planning_player_index if bs.current_phase == BattleState.Phase.SELECT else -1
	board_3d.update_board(player_positions, enemy_positions, highlighted_tiles, active_idx)
	board_3d.set_enemy_target_state(_targetable_enemy_indices, _active_target_enemy_idx)

func _planning_hint_text() -> String:
	if ui_locked:
		return "Round resolving. Planning input is locked."
	var player = _active_player()
	if bs.current_phase == BattleState.Phase.REFRESH:
		if online_enabled and not online_is_host:
			return "Round cleanup complete. Waiting for the host to start the next round."
		return "Round cleanup complete. Press Next Round when you're ready."
	if bs.current_phase != BattleState.Phase.SELECT:
		return "Watch the actor order resolve from lowest initiative upward."
	if player.ready:
		return "%s is ready. Focus another player or unready to edit." % player.name
	if player.stun:
		return "%s is stunned. Choose only 1 card, then press Ready." % player.name
	return "%s is active. Click hand cards to select, or rotate any card for +1 Move / +1 Block." % player.name

func _phase_text(phase: int) -> String:
	match phase:
		BattleState.Phase.SETUP: return "Setup"
		BattleState.Phase.SELECT: return "Planning"
		BattleState.Phase.REVEAL: return "Reveal"
		BattleState.Phase.RESOLVE: return "Resolve"
		BattleState.Phase.REFRESH: return "Refresh"
		BattleState.Phase.VICTORY: return "Victory"
		BattleState.Phase.DEFEAT: return "Defeat"
		_: return "Title"

func _actor_order_preview() -> String:
	var pieces: Array[String] = []
	for actor in bs.build_actor_order(false):
		if actor["actor_type"] == "player":
			var player = bs.get_player(int(actor["seat_index"]))
			pieces.append("%s(%d)" % [player.name, actor["initiative"]])
		else:
			pieces.append("E%d(%d)" % [int(actor["enemy_index"]) + 1, actor["initiative"]])
	if pieces.is_empty():
		return "all players pass"
	return " → ".join(pieces)

func _show_turn_order(actors: Array) -> void:
	if _turn_order_row == null:
		return
	for child in _turn_order_row.get_children():
		child.queue_free()
	_turn_order_row.visible = not actors.is_empty()
	if actors.is_empty():
		return

	var tokens: Array = []
	var final_gap := 22.0
	var initial_actors: Array = actors.duplicate()
	initial_actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["seat_index"]) < int(b["seat_index"])
	)
	for actor_idx in range(initial_actors.size()):
		var actor := initial_actors[actor_idx] as Dictionary
		var token := _make_turn_order_token(actor)
		token.position = Vector2(float(actor_idx) * (150.0 + final_gap), 8)
		token.set_meta("actor_key", _actor_key(actor))
		_turn_order_row.add_child(token)
		tokens.append(token)

	await get_tree().create_timer(0.35).timeout
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	for token in tokens:
		var target_idx: int = _actor_order_index(actors, String(token.get_meta("actor_key")))
		var target_x := float(target_idx) * (150.0 + final_gap)
		tw.tween_property(token, "position:x", target_x, 0.42)
	await tw.finished
	for i in range(maxi(actors.size() - 1, 0)):
		var arrow := _lbl("→", true)
		arrow.position = Vector2(float(i) * (150.0 + final_gap) + 157.0, 24.0)
		_turn_order_row.add_child(arrow)
	await get_tree().create_timer(0.55).timeout

func _actor_key(actor: Dictionary) -> String:
	if actor["actor_type"] == "player":
		return "p%d" % int(actor["seat_index"])
	return "e%d" % int(actor["enemy_index"])

func _actor_order_index(actors: Array, key: String) -> int:
	for i in range(actors.size()):
		if _actor_key(actors[i] as Dictionary) == key:
			return i
	return 0

func _make_turn_order_token(actor: Dictionary) -> PanelContainer:
	var is_player: bool = String(actor["actor_type"]) == "player"
	var title: String = ""
	var color: Color = Color(0.46, 0.10, 0.10)
	if is_player:
		var player = bs.get_player(int(actor["seat_index"]))
		title = player.name.to_upper()
		color = Color(0.12, 0.22, 0.55)
	else:
		title = "ENEMY %d" % (int(actor["enemy_index"]) + 1)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 64)
	panel.add_theme_stylebox_override("panel", _flat_style(color, 6, 8))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var name_lbl := _lbl(title, true)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_lbl)
	var init_lbl := _lbl("Init: %d" % actor["initiative"], true)
	init_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	init_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.34))
	box.add_child(init_lbl)
	return panel

func _set_selected_card_highlight(seat_index: int, card_idx: int) -> void:
	if seat_index < 0 or seat_index >= _player_cards.size():
		return
	_active_resolving_seat = seat_index
	_active_resolving_card = card_idx
	var ui := _player_cards[seat_index] as Dictionary
	var selected_cards: Array = ui["selected_cards"]
	var player = bs.get_player(seat_index)
	for i in range(selected_cards.size()):
		var selected_card: CardData = player.selected[i] if player != null and i < player.selected.size() else null
		var is_active := i == card_idx and selected_card != null
		_refresh_card_panel(selected_cards[i], selected_card, selected_card != null, is_active)

func _clear_selected_card_highlight(seat_index: int) -> void:
	if seat_index < 0 or seat_index >= _player_cards.size():
		return
	_active_resolving_seat = -1
	_active_resolving_card = -1
	var ui := _player_cards[seat_index] as Dictionary
	var selected_cards: Array = ui["selected_cards"]
	var player = bs.get_player(seat_index)
	for i in range(selected_cards.size()):
		var selected_card: CardData = player.selected[i] if player != null and i < player.selected.size() else null
		_refresh_card_panel(selected_cards[i], selected_card, selected_card != null)

func _active_player():
	var player = bs.get_player(bs.selected_planning_player_index)
	return player if player != null else bs.get_player(0)

func _player_is_editable(player) -> bool:
	return (
		not ui_locked
		and bs.current_phase == BattleState.Phase.SELECT
		and player.alive
		and not player.ready
		and player.seat_index == bs.selected_planning_player_index
		and (not online_enabled or player.seat_index == owned_seat_index)
	)

func _focus_unready_player(direction: int) -> void:
	if ui_locked or bs.current_phase != BattleState.Phase.SELECT:
		return
	var next_idx: int = bs.next_unready_player(bs.selected_planning_player_index, direction)
	bs.set_active_planning_player(next_idx)
	_update_ui()

func _on_focus_player(seat_index: int) -> void:
	if ui_locked:
		return
	bs.set_active_planning_player(seat_index)
	_update_ui()

func _on_next_round_pressed() -> void:
	if bs.current_phase != BattleState.Phase.REFRESH:
		return
	if online_enabled and not online_is_host:
		return
	next_round_confirmed.emit()

func _on_ready_pressed(seat_index: int) -> void:
	_toggle_player_ready(bs.get_player(seat_index))

func _toggle_player_ready(player) -> void:
	if player == null or ui_locked or bs.current_phase != BattleState.Phase.SELECT:
		return
	if online_enabled and player.seat_index != owned_seat_index:
		return
	var new_ready: bool = not player.ready
	if new_ready and player.selected.size() > player.selection_limit():
		bs.log_msg("%s is stunned and can only ready 1 selected card." % player.name)
		_update_ui()
		return
	if online_enabled and not online_is_host:
		online_session.send_command({
			"kind": "set_ready",
			"seat_index": player.seat_index,
			"ready": new_ready,
		})
		return
	bs.set_player_ready(player.seat_index, new_ready)
	if not new_ready:
		bs.set_active_planning_player(player.seat_index)
	bs.log_msg("%s is %s." % [player.name, "ready" if new_ready else "editing again"])
	_update_ui()
	if new_ready and bs.all_living_players_ready():
		_run_round()

func _on_hand_card_input(event: InputEvent, seat_index: int, hand_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_try_select_hand(bs.get_player(seat_index), hand_index)

func _try_select_hand(player, hand_index: int) -> void:
	if player == null or not _player_is_editable(player):
		return
	if _selection_blocked_by_stun(player):
		_pulse_stunned_status(player.seat_index)
		return
	if online_enabled and not online_is_host:
		online_session.send_command({
			"kind": "select_card",
			"seat_index": player.seat_index,
			"hand_index": hand_index,
		})
		return
	if not bs.select_card(player.seat_index, hand_index):
		return
	_update_ui()
	_pulse_stamina_label(player.seat_index, true)

func _try_rotate_card(seat_index: int, hand_index: int, rotation_kind: String) -> void:
	var player = bs.get_player(seat_index)
	if player == null or not _player_is_editable(player):
		return
	if hand_index < 0 or hand_index >= player.hand.size():
		return
	if _selection_blocked_by_stun(player):
		_pulse_stunned_status(seat_index)
		return
	var rotate_card := _make_rotated_card(player, hand_index, rotation_kind)
	if not player.can_select(rotate_card):
		return
	if online_enabled and not online_is_host:
		online_session.send_command({
			"kind": "rotate_card",
			"seat_index": seat_index,
			"hand_index": hand_index,
			"rotation_kind": rotation_kind,
		})
		return
	if not _select_rotated_card(player, hand_index, rotation_kind):
		return
	var label := "Move" if rotation_kind == "move" else "Block"
	bs.log_msg("%s rotates %s for +1 %s (costs 1 stamina)." % [player.name, rotate_card.rotated_from_name, label])
	_update_ui()
	_pulse_stamina_label(seat_index, true)

func _make_rotated_card(player, hand_index: int, rotation_kind: String) -> CardData:
	if player == null or hand_index < 0 or hand_index >= player.hand.size():
		return null
	var original: CardData = player.hand[hand_index] as CardData
	if rotation_kind == "block":
		return CardData.create_rotate_block_card(original.card_name, original.initiative)
	return CardData.create_rotate_move_card(original.card_name, original.initiative)

func _select_rotated_card(player, hand_index: int, rotation_kind: String) -> bool:
	var rotate_card := _make_rotated_card(player, hand_index, rotation_kind)
	if rotate_card == null or not player.can_select(rotate_card):
		return false
	player.hand.remove_at(hand_index)
	player.selected.append(rotate_card)
	return true

func _selection_blocked_by_stun(player) -> bool:
	return player != null and player.stun and player.selected.size() >= player.selection_limit()

func _pulse_stunned_status(seat_index: int) -> void:
	if seat_index < 0 or seat_index >= _player_cards.size():
		return
	var ui := _player_cards[seat_index] as Dictionary
	_pulse_player_stat_label(ui, "status_lbl", "status_tween", STATUS_BASE_COLOR, STATUS_PULSE_COLOR)

func _on_selected_card_input(event: InputEvent, seat_index: int, selected_index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var player = bs.get_player(seat_index)
	if player == null or not _player_is_editable(player):
		return
	if online_enabled and not online_is_host:
		online_session.send_command({
			"kind": "deselect_card",
			"seat_index": seat_index,
			"selected_index": selected_index,
		})
		return
	if bs.deselect_card(seat_index, selected_index):
		_update_ui()
		_pulse_stamina_label(seat_index, false)

func _pulse_stamina_label(seat_index: int, spent: bool) -> void:
	if seat_index < 0 or seat_index >= _player_cards.size():
		return
	var ui := _player_cards[seat_index] as Dictionary
	var accent := STAMINA_SPEND_COLOR if spent else STAMINA_REFUND_COLOR
	_pulse_player_stat_label(ui, "stamina_lbl", "stamina_tween", STAMINA_BASE_COLOR, accent)

func _pulse_player_stat_label(ui: Dictionary, label_key: String, tween_key: String, base_color: Color, accent: Color) -> void:
	var target_lbl: Label = ui.get(label_key)
	if target_lbl == null:
		return
	var existing: Tween = ui.get(tween_key)
	var tw := _pulse_stat_label(target_lbl, existing, base_color, accent)
	ui[tween_key] = tw

func _pulse_enemy_stat_label(enemy_idx: int, labels: Array, tweens: Array, base_color: Color, accent: Color) -> void:
	if enemy_idx < 0 or enemy_idx >= labels.size() or enemy_idx >= tweens.size():
		return
	var target_lbl: Label = labels[enemy_idx]
	if target_lbl == null:
		return
	tweens[enemy_idx] = _pulse_stat_label(target_lbl, tweens[enemy_idx], base_color, accent)

func _pulse_stat_label(target_lbl: Label, existing: Tween, base_color: Color, accent: Color) -> Tween:
	if existing != null:
		existing.kill()
	target_lbl.add_theme_color_override("font_color", base_color)
	target_lbl.scale = Vector2.ONE
	target_lbl.modulate = Color.WHITE
	target_lbl.pivot_offset = target_lbl.size * 0.5
	target_lbl.z_index = 20

	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(target_lbl, "scale", Vector2(1.55, 1.55), 0.10)
	tw.parallel().tween_property(target_lbl, "modulate", accent, 0.08)
	tw.tween_property(target_lbl, "scale", Vector2(0.92, 0.92), 0.09)
	tw.parallel().tween_property(target_lbl, "modulate", Color.WHITE, 0.09)
	tw.tween_property(target_lbl, "scale", Vector2(1.22, 1.22), 0.08)
	tw.parallel().tween_property(target_lbl, "modulate", accent, 0.06)
	tw.tween_property(target_lbl, "scale", Vector2.ONE, 0.14)
	tw.parallel().tween_property(target_lbl, "modulate", Color.WHITE, 0.12)
	tw.tween_callback(func() -> void:
		target_lbl.z_index = 0
		target_lbl.add_theme_color_override("font_color", base_color)
	)
	return tw

func _on_move_selected_pressed(seat_index: int, selected_index: int, direction: int) -> void:
	var player = bs.get_player(seat_index)
	if player == null or not _player_is_editable(player):
		return
	if online_enabled and not online_is_host:
		online_session.send_command({
			"kind": "move_selected_card",
			"seat_index": seat_index,
			"selected_index": selected_index,
			"direction": direction,
		})
		return
	if bs.move_selected_card(seat_index, selected_index, direction):
		_update_ui()

# ─── Round Flow ───────────────────────────────────────────────────────────────

func _run_round() -> void:
	if ui_locked:
		return
	ui_locked = true
	bs.current_phase = BattleState.Phase.REVEAL
	bs.reveal_enemy_behaviors()
	for enemy in bs.enemies:
		if enemy.alive and enemy.revealed != null:
			bs.log_msg("Enemy %d reveals %s (Init %d)." % [enemy.index + 1, enemy.revealed.behavior_name, enemy.revealed.initiative])
	_update_ui()
	_sync_online_snapshot()

	await get_tree().create_timer(0.35).timeout
	bs.current_phase = BattleState.Phase.RESOLVE
	_update_ui()
	_sync_online_snapshot()

	var actors = bs.build_actor_order(true)
	await _show_turn_order(actors)
	if actors.is_empty():
		bs.log_msg("No actors this round.")
		await _finish_round()
		return

	for actor in actors:
		if await _check_end():
			return
		if actor["actor_type"] == "player":
			var player = bs.get_player(int(actor["seat_index"]))
			if player == null or not player.alive:
				continue
			# Start-of-turn: tick poison, clear expired conditions
			await _apply_start_of_turn_player(player)
			if not player.alive:
				_update_ui()
				if await _check_end():
					return
				continue
			await _resolve_player(player)
			# Stun clears after player acts
			player.stun = false
		else:
			var enemy = bs.get_enemy(int(actor["enemy_index"]))
			if enemy == null or not enemy.alive:
				continue
			await _apply_start_of_turn_enemy(enemy)
			if not enemy.alive:
				_update_ui()
				if await _check_end():
					return
				continue
			if enemy.stun:
				bs.log_msg("  Enemy %d is stunned — skips turn." % (enemy.index + 1))
				enemy.stun = false
				await get_tree().create_timer(0.25).timeout
				continue
			await _resolve_enemy(enemy)
			enemy.stun = false
		_update_ui()
		if await _check_end():
			return

	await _finish_round()

func _apply_start_of_turn_player(player: PlayerState) -> void:
	# Poison ticks at start of turn; conditions clear in end_round_cleanup
	if player.poison:
		var dmg: int = player.apply_poison_damage()
		bs.log_msg("  %s suffers %d poison damage (HP→%d)." % [player.name, dmg, player.hp])
		if board_3d:
			await board_3d.animate_player_hit(player.seat_index)
		_update_ui()

func _apply_start_of_turn_enemy(enemy: EnemyState) -> void:
	if enemy.poison:
		var dmg: int = enemy.apply_poison_damage()
		bs.log_msg("  Enemy %d suffers %d poison damage (HP→%d)." % [enemy.index + 1, dmg, enemy.hp])
		if board_3d:
			await board_3d.animate_enemy_hit(enemy.index)
		_update_ui()

func _finish_round() -> void:
	bs.end_round_cleanup()
	await _process_level_up_queue()
	ui_locked = false
	bs.log_msg("Round %d cleanup complete. Press Next Round to continue." % bs.round_number)
	_update_ui()
	_sync_online_snapshot()
	await next_round_confirmed
	_begin_next_round()

func _check_end() -> bool:
	if bs.all_enemies_dead():
		bs.current_phase = BattleState.Phase.VICTORY
		_update_ui()
		await get_tree().create_timer(0.4).timeout
		_show_end(true)
		return true
	if bs.any_player_dead():
		bs.current_phase = BattleState.Phase.DEFEAT
		_update_ui()
		await get_tree().create_timer(0.4).timeout
		_show_end(false)
		return true
	return false

# ─── Player Resolution ────────────────────────────────────────────────────────

func _resolve_player(player: PlayerState) -> void:
	if player == null or not player.alive:
		return
	if player.selected.is_empty():
		return
	var was_stunned: bool = player.stun
	var max_cards: int = 1 if was_stunned else player.selected.size()
	if was_stunned:
		bs.log_msg("  %s is stunned — limited to 1 card." % player.name)
	var selected_cards: Array = player.selected.duplicate()
	for card_idx in range(mini(selected_cards.size(), max_cards)):
		_set_selected_card_highlight(player.seat_index, card_idx)
		await get_tree().create_timer(1.0).timeout
		var card = selected_cards[card_idx]
		var c: CardData = card as CardData
		bs.log_msg("▶ %s: %s" % [player.name, c.card_name])
		_update_ui()
		await get_tree().create_timer(0.2).timeout
		for effect in c.effects:
			await _resolve_player_effect(player, effect, c)
			_update_ui()
			if bs.all_enemies_dead() or bs.any_player_dead():
				_clear_selected_card_highlight(player.seat_index)
				return
	_clear_selected_card_highlight(player.seat_index)

func _resolve_player_effect(player: PlayerState, fx: Dictionary, card: CardData) -> void:
	var fx_type: String = String(fx.get("type", ""))
	match fx_type:
		"attack":
			var rng: int = fx.get("range", 1)
			var attack_type: String = String(fx.get("attack_type", "physical"))
			var ignore_block: bool = bool(fx.get("ignore_block", false))
			var aoe_adj: bool = bool(fx.get("aoe_adjacent", false))
			var apply_cond: String = String(fx.get("apply_condition", ""))
			var bonus: int = 2 if player.bless else 0
			player.bless = false

			if aoe_adj:
				# Hit all adjacent enemies — no targeting needed
				var hit_any := false
				for enemy_entry in bs.enemies:
					var enemy: EnemyState = enemy_entry as EnemyState
					if not enemy.alive or enemy.hidden:
						continue
					if Pathfinder.manhattan(player.pos, enemy.pos) != 1:
						continue
					var raw: int = int(fx["value"]) + bonus
					bonus = 0
					if board_3d:
						await board_3d.animate_melee_attack(player.pos, enemy.pos)
					var actual := bs.apply_damage_enemy(enemy, raw, attack_type, ignore_block)
					bs.log_msg("  %s hits Enemy %d for %d (→%d HP)" % [player.name, enemy.index + 1, actual, enemy.hp])
					if apply_cond != "":
						_apply_condition_to_enemy(enemy, apply_cond)
					if not enemy.alive:
						_award_xp_for_kill(enemy)
					hit_any = true
				if not hit_any:
					bs.log_msg("  %s's Flurry: no adjacent enemies." % player.name)
				await get_tree().create_timer(0.18).timeout
				return

			var is_ranged := rng > 1
			var targets := _enemies_in_range(player.pos, rng, is_ranged)
			if targets.is_empty():
				bs.log_msg("  %s fizzled: no valid target in range %d." % [player.name, rng])
				await get_tree().create_timer(0.18).timeout
				return
			var target: EnemyState = await _choose_attack_target(player, targets, card)
			if target == null:
				bs.log_msg("  %s: targeting cancelled." % player.name)
				await get_tree().create_timer(0.18).timeout
				return
			var raw: int = int(fx["value"]) + bonus
			var hp_before: int = target.hp
			if board_3d:
				if is_ranged:
					await board_3d.animate_ranged_attack(player.pos, target.pos)
				else:
					await board_3d.animate_melee_attack(player.pos, target.pos)
				if target.block > 0 and not ignore_block:
					await board_3d.animate_block(target.pos)
				await board_3d.animate_enemy_hit(target.index)
			var actual := bs.apply_damage_enemy(target, raw, attack_type, ignore_block)
			var msg := "  %s deals %d" % [player.name, raw]
			if bonus > 0:
				msg += " (+%d Bless)" % (bonus)
			msg += " — %d absorbed = %d HP lost (Enemy %d: %d→%d)" % [raw - actual, actual, target.index + 1, hp_before, target.hp]
			bs.log_msg(msg)
			if apply_cond != "" and target.alive:
				_apply_condition_to_enemy(target, apply_cond)
			elif apply_cond != "":
				_apply_condition_to_enemy(target, apply_cond)
			if not target.alive:
				_award_xp_for_kill(target)
			await get_tree().create_timer(0.12).timeout

		"heal":
			var heal_target: PlayerState = await _choose_heal_target(player, fx)
			if heal_target == null:
				return
			var result_msg: String = heal_target.apply_heal(int(fx.get("value", 0)))
			bs.log_msg("  %s heals %s: %s" % [player.name, heal_target.name, result_msg])
			if bool(fx.get("also_bless", false)):
				heal_target.bless = true
				bs.log_msg("  %s gains Bless." % heal_target.name)
			elif bool(fx.get("bless_if_no_conditions", false)):
				if not heal_target.has_any_condition():
					heal_target.bless = true
					bs.log_msg("  %s gains Bless (no conditions)." % heal_target.name)
			await get_tree().create_timer(0.14).timeout

		"block":
			var block_target: String = String(fx.get("target", "self"))
			if block_target == "self_and_adjacent_allies":
				player.block += fx["value"]
				bs.log_msg("  %s gains Block %d (→%d)" % [player.name, fx["value"], player.block])
				for other_entry in bs.players:
					var other: PlayerState = other_entry as PlayerState
					if other.alive and other.seat_index != player.seat_index:
						if Pathfinder.manhattan(player.pos, other.pos) <= 1:
							other.block += fx["value"]
							bs.log_msg("  %s gains Block %d (→%d)" % [other.name, fx["value"], other.block])
			else:
				player.block += fx["value"]
				bs.log_msg("  %s gains Block %d (→%d)" % [player.name, fx["value"], player.block])
			await get_tree().create_timer(0.14).timeout

		"move", "jump":
			if player.entangle:
				bs.log_msg("  %s is entangled — cannot move." % player.name)
				await get_tree().create_timer(0.14).timeout
				return
			await _resolve_player_move(player, int(fx.get("value", 0)))

		"bless":
			player.bless = true
			bs.log_msg("  %s gains Bless." % player.name)
			await get_tree().create_timer(0.14).timeout

		"slow":
			var nearest: EnemyState = _nearest_enemy_to_player(player.pos)
			if nearest != null:
				nearest.slow = true
				bs.log_msg("  Enemy %d gains Slow." % (nearest.index + 1))
			await get_tree().create_timer(0.14).timeout

		"votive_step_bonus":
			var adj_ally = _nearest_living_ally(player.pos, player.seat_index, 1)
			if adj_ally != null:
				adj_ally.block += 2
				bs.log_msg("  %s adjacent to %s — grants Block 2 (→%d)." % [player.name, adj_ally.name, adj_ally.block])
				if not adj_ally.entangle:
					await _resolve_player_move(adj_ally, 1)
			await get_tree().create_timer(0.10).timeout

		"guiding_chant":
			var rng: int = fx.get("range", 3)
			var val: int = fx.get("value", 2)
			var gc_target = await _choose_heal_target(player, {"range": rng, "target": "self_or_ally", "value": 0})
			if gc_target != null:
				gc_target.block += val
				bs.log_msg("  %s grants %s Block %d (→%d)." % [player.name, gc_target.name, val, gc_target.block])
				if gc_target.seat_index != player.seat_index and not gc_target.entangle:
					await _resolve_player_move(gc_target, 1)
			await get_tree().create_timer(0.14).timeout

func _resolve_player_move(player: PlayerState, budget: int) -> void:
	var end_blocked := bs.occupied_positions_for_player(player.seat_index)
	var reachable := Pathfinder.get_reachable(player.pos, budget, end_blocked)
	if reachable.is_empty():
		bs.log_msg("  %s's move: no reachable tiles." % player.name)
		return
	_pending_move_player_index = player.seat_index
	highlighted_tiles = reachable
	_update_board()
	_sync_online_snapshot()
	bs.log_msg("  %s: choose a destination tile." % player.name)
	var dest: Vector2i = await move_dest_chosen
	highlighted_tiles.clear()
	_pending_move_player_index = -1
	_update_board()
	var path := Pathfinder.find_path(player.pos, dest, end_blocked)
	if path.is_empty() and dest != player.pos:
		bs.log_msg("  %s: path not found." % player.name)
		return
	for step in path:
		player.pos = step
		if board_3d:
			await board_3d.animate_player_step(player.seat_index, step)
		_update_ui()
	bs.log_msg("  %s moves to %s." % [player.name, str(dest)])

func _choose_heal_target(player: PlayerState, fx: Dictionary) -> PlayerState:
	var target_mode: String = String(fx.get("target", "self"))
	if target_mode == "self":
		return player
	var rng: int = fx.get("range", 0)
	var living_allies: Array = []
	for p in bs.players:
		var ally: PlayerState = p as PlayerState
		if ally.alive and Pathfinder.manhattan(player.pos, ally.pos) <= rng:
			living_allies.append(ally)
	if living_allies.is_empty():
		return player
	if living_allies.size() == 1:
		return living_allies[0] as PlayerState
	living_allies.sort_custom(func(a, b) -> bool: return a.hp < b.hp)
	return living_allies[0] as PlayerState

func _nearest_living_ally(from_pos: Vector2i, excluded_seat: int, max_range: int) -> PlayerState:
	var best: PlayerState = null
	var best_dist := 999
	for p in bs.players:
		var player: PlayerState = p as PlayerState
		if not player.alive or player.seat_index == excluded_seat:
			continue
		var dist := Pathfinder.manhattan(from_pos, player.pos)
		if dist > max_range:
			continue
		if dist < best_dist:
			best = player
			best_dist = dist
	return best

# ─── Enemy Resolution ─────────────────────────────────────────────────────────

func _resolve_enemy(enemy: EnemyState) -> void:
	if enemy == null or not enemy.alive or enemy.revealed == null:
		return
	if enemy.hidden:
		bs.log_msg("◀ Enemy %d is hidden — skips revealed action." % (enemy.index + 1))
		await get_tree().create_timer(0.18).timeout
		return
	bs.log_msg("◀ Enemy %d: %s" % [enemy.index + 1, enemy.revealed.behavior_name])
	_update_ui()
	await get_tree().create_timer(0.2).timeout
	for effect_index in range(enemy.revealed.effects.size()):
		var effect: Dictionary = enemy.revealed.effects[effect_index]
		await _resolve_enemy_effect(enemy, effect, effect_index)
		_update_ui()
		if bs.all_enemies_dead() or bs.any_player_dead():
			return

func _resolve_enemy_effect(enemy: EnemyState, fx: Dictionary, effect_index: int = -1) -> void:
	var fx_type: String = String(fx.get("type", ""))
	match fx_type:
		"block":
			enemy.block += fx["value"]
			bs.log_msg("  Enemy %d gains Block %d (→%d)." % [enemy.index + 1, fx["value"], enemy.block])
			await get_tree().create_timer(0.14).timeout

		"move_toward":
			var steps: int = fx["value"]
			if enemy.slow:
				steps = maxi(steps - 1, 0)
				bs.log_msg("  Slow: Enemy %d move reduced to %d." % [enemy.index + 1, steps])
			if enemy.entangle:
				bs.log_msg("  Enemy %d is entangled — cannot move." % (enemy.index + 1))
				await get_tree().create_timer(0.14).timeout
				return
			await _enemy_move(enemy, steps, _enemy_preferred_distance(enemy, effect_index))

		"melee_attack":
			var target: PlayerState = _nearest_living_player(enemy.pos)
			if target == null:
				return
			if Pathfinder.manhattan(enemy.pos, target.pos) > 1:
				bs.log_msg("  Enemy %d: not adjacent to target." % (enemy.index + 1))
				await get_tree().create_timer(0.16).timeout
				return
			await _enemy_strike(enemy, target, fx, true)

		"ranged_attack":
			var rng: int = fx.get("range", 4)
			var is_aoe: bool = bool(fx.get("aoe", false))
			var multi: int = fx.get("multi_target", 0)
			if is_aoe:
				var aoe_target: PlayerState = _nearest_valid_ranged_target(enemy.pos, rng)
				if aoe_target == null:
					bs.log_msg("  Enemy %d: no ranged target." % (enemy.index + 1))
					await get_tree().create_timer(0.16).timeout
					return
				await _enemy_aoe_strike(enemy, aoe_target.pos, fx)
			elif multi > 1:
				await _enemy_multi_strike(enemy, rng, fx, multi)
			else:
				var target: PlayerState = _nearest_valid_ranged_target(enemy.pos, rng)
				if target == null:
					bs.log_msg("  Enemy %d: no ranged target." % (enemy.index + 1))
					await get_tree().create_timer(0.16).timeout
					return
				await _enemy_strike(enemy, target, fx, false)

		"apply_condition_if_adj":
			var target: PlayerState = _nearest_living_player(enemy.pos)
			if target == null:
				return
			if Pathfinder.manhattan(enemy.pos, target.pos) > 1:
				bs.log_msg("  Enemy %d: not adjacent — condition fizzled." % (enemy.index + 1))
				await get_tree().create_timer(0.16).timeout
				return
			var cond: String = String(fx.get("condition", ""))
			_apply_condition_to_player(target, cond)
			await get_tree().create_timer(0.14).timeout

		"apply_condition_self":
			var cond: String = String(fx.get("condition", ""))
			_apply_condition_to_enemy(enemy, cond)
			await get_tree().create_timer(0.14).timeout

		"executioner_blow":
			var target: PlayerState = _nearest_living_player(enemy.pos)
			if target == null:
				return
			if Pathfinder.manhattan(enemy.pos, target.pos) > 1:
				bs.log_msg("  Enemy %d: not adjacent." % (enemy.index + 1))
				await get_tree().create_timer(0.16).timeout
				return
			var threshold: int = fx.get("hp_threshold", 6)
			var val: int = int(fx["high_value"] if target.hp <= threshold else fx["low_value"])
			var strike_fx := {"value": val, "attack_type": "physical"}
			await _enemy_strike(enemy, target, strike_fx, true)

func _enemy_preferred_distance(enemy: EnemyState, effect_index: int) -> int:
	if enemy == null or enemy.revealed == null:
		return 1
	for i in range(effect_index + 1, enemy.revealed.effects.size()):
		var fx: Dictionary = enemy.revealed.effects[i]
		var fx_type: String = String(fx.get("type", ""))
		if fx_type == "ranged_attack":
			return int(fx.get("range", 4))
		if fx_type == "melee_attack" or fx_type == "apply_condition_if_adj" or fx_type == "executioner_blow":
			return 1
	return 1

func _enemy_move(enemy: EnemyState, steps: int, preferred_distance: int = 1) -> void:
	if steps <= 0:
		return
	var target: PlayerState = _nearest_living_player(enemy.pos)
	if target == null:
		return
	var end_blocked := bs.living_player_positions()
	for pos in bs.living_enemy_positions(enemy.index):
		end_blocked.append(pos)
	var reachable := Pathfinder.get_reachable(enemy.pos, steps, end_blocked)
	if reachable.is_empty():
		return
	var best_dest: Vector2i = enemy.pos
	var preferred: int = maxi(preferred_distance, 1)
	var best_score: int = abs(Pathfinder.manhattan(enemy.pos, target.pos) - preferred)
	var best_steps_used: int = 0
	for tile in reachable:
		var tile_pos: Vector2i = tile as Vector2i
		var d: int = Pathfinder.manhattan(tile_pos, target.pos)
		var score: int = abs(d - preferred)
		var path_len: int = Pathfinder.manhattan(enemy.pos, tile_pos)
		if score < best_score or (score == best_score and path_len < best_steps_used):
			best_dest = tile_pos
			best_score = score
			best_steps_used = path_len
	if best_dest == enemy.pos:
		return
	var path := Pathfinder.find_path(enemy.pos, best_dest, end_blocked)
	for step in path:
		enemy.pos = step
		if board_3d:
			await board_3d.animate_enemy_step(enemy.index, step)
		bs.log_msg("  Enemy %d moves to %s." % [enemy.index + 1, str(step)])
		_update_ui()

func _enemy_strike(enemy: EnemyState, target: PlayerState, fx: Dictionary, is_melee: bool) -> void:
	if target == null or target.hidden:
		return
	var raw: int = fx.get("value", 0)
	var attack_type: String = String(fx.get("attack_type", "physical"))
	var ignore_block: bool = bool(fx.get("ignore_block", false))
	var apply_cond: String = String(fx.get("apply_condition", ""))
	var hp_before: int = target.hp
	if board_3d:
		if is_melee:
			await board_3d.animate_melee_attack(enemy.pos, target.pos)
		else:
			await board_3d.animate_ranged_attack(enemy.pos, target.pos)
		if target.block > 0 and not ignore_block:
			await board_3d.animate_block(target.pos)
		await board_3d.animate_player_hit(target.seat_index)
	var actual := bs.apply_damage_player(target, raw, attack_type, ignore_block)
	if actual > 0:
		await _flash_red_screen()
	var msg := "  Enemy %d %s %s for %d — %d HP lost (%d→%d)" % [
		enemy.index + 1,
		"strikes" if is_melee else "shoots",
		target.name, raw, actual, hp_before, target.hp
	]
	bs.log_msg(msg)
	if apply_cond != "":
		_apply_condition_to_player(target, apply_cond)
	await get_tree().create_timer(0.12).timeout

func _enemy_aoe_strike(enemy: EnemyState, center_pos: Vector2i, fx: Dictionary) -> void:
	var raw: int = fx.get("value", 0)
	var attack_type: String = String(fx.get("attack_type", "physical"))
	var ignore_block: bool = bool(fx.get("ignore_block", false))
	var apply_cond: String = String(fx.get("apply_condition", ""))
	if board_3d:
		await board_3d.animate_ranged_attack(enemy.pos, center_pos)
	bs.log_msg("  Enemy %d AoE at %s!" % [enemy.index + 1, str(center_pos)])
	for player in bs.players:
		var target: PlayerState = player as PlayerState
		if not target.alive or target.hidden:
			continue
		var dx: int = abs(target.pos.x - center_pos.x)
		var dy: int = abs(target.pos.y - center_pos.y)
		if dx <= 1 and dy <= 1:
			var hp_before: int = target.hp
			var actual := bs.apply_damage_player(target, raw, attack_type, ignore_block)
			if actual > 0:
				await _flash_red_screen()
			bs.log_msg("  %s hit by AoE: %d HP lost (%d→%d)" % [target.name, actual, hp_before, target.hp])
			if apply_cond != "":
				_apply_condition_to_player(target, apply_cond)
	await get_tree().create_timer(0.16).timeout

func _enemy_multi_strike(enemy: EnemyState, rng: int, fx: Dictionary, count: int) -> void:
	var targets: Array = []
	for p in bs.players:
		var player: PlayerState = p as PlayerState
		if not player.alive or player.hidden:
			continue
		var dist := Pathfinder.manhattan(enemy.pos, player.pos)
		if dist > 1 and dist <= rng:
			targets.append(player)
	targets.sort_custom(func(a, b) -> bool:
		return Pathfinder.manhattan(enemy.pos, a.pos) < Pathfinder.manhattan(enemy.pos, b.pos)
	)
	var hit_count := mini(count, targets.size())
	for i in range(hit_count):
		await _enemy_strike(enemy, targets[i] as PlayerState, fx, false)
		_update_ui()
		if bs.any_player_dead():
			return
	if hit_count == 0:
		bs.log_msg("  Enemy %d: no valid ranged targets." % (enemy.index + 1))
		await get_tree().create_timer(0.16).timeout

func _nearest_valid_ranged_target(from_pos: Vector2i, max_range: int) -> PlayerState:
	var best: PlayerState = null
	var best_dist := 999
	for p in bs.players:
		var player: PlayerState = p as PlayerState
		if not player.alive or player.hidden:
			continue
		var dist := Pathfinder.manhattan(from_pos, player.pos)
		if dist <= 1 or dist > max_range:
			continue
		if dist < best_dist or (dist == best_dist and best != null and player.seat_index < best.seat_index):
			best = player
			best_dist = dist
	return best

# ─── Targeting Helpers ────────────────────────────────────────────────────────

func _nearest_enemy_to_player(from_pos: Vector2i, max_range: int = 99) -> EnemyState:
	var best: EnemyState = null
	var best_dist: int = 999
	for enemy_entry in bs.enemies:
		var enemy: EnemyState = enemy_entry as EnemyState
		if not enemy.alive:
			continue
		var dist: int = Pathfinder.manhattan(from_pos, enemy.pos)
		if dist > max_range:
			continue
		if dist < best_dist:
			best = enemy
			best_dist = dist
		elif dist == best_dist and best != null and enemy.index < best.index:
			best = enemy
	return best

func _enemies_in_range(from_pos: Vector2i, max_range: int, ranged: bool = false) -> Array:
	var targets: Array = []
	for enemy_entry in bs.enemies:
		var enemy: EnemyState = enemy_entry as EnemyState
		if not enemy.alive or enemy.hidden:
			continue
		var dist := Pathfinder.manhattan(from_pos, enemy.pos)
		if dist > max_range:
			continue
		if ranged and dist <= 1:
			continue
		targets.append(enemy)
	targets.sort_custom(func(a, b) -> bool:
		var da: int = Pathfinder.manhattan(from_pos, a.pos)
		var db: int = Pathfinder.manhattan(from_pos, b.pos)
		if da == db:
			return a.index < b.index
		return da < db
	)
	return targets

func _choose_attack_target(player: PlayerState, targets: Array, card: CardData) -> EnemyState:
	if targets.is_empty():
		return null
	if targets.size() == 1:
		return targets[0] as EnemyState

	_pending_attack_player_index = player.seat_index
	_targetable_enemy_indices.clear()
	for enemy_entry in targets:
		var enemy: EnemyState = enemy_entry as EnemyState
		_targetable_enemy_indices.append(enemy.index)
	_active_target_enemy_idx = -1
	bs.log_msg("  %s: tap an enemy to target, then tap again to attack." % card.card_name)
	_update_ui()
	_sync_online_snapshot()

	var chosen_idx: int = await attack_target_chosen
	for enemy in targets:
		var target_enemy: EnemyState = enemy as EnemyState
		if target_enemy.index == chosen_idx and target_enemy.alive:
			_clear_attack_targeting()
			_update_ui()
			_sync_online_snapshot()
			return target_enemy

	_clear_attack_targeting()
	_update_ui()
	_sync_online_snapshot()
	return null

func _nearest_living_player(from_pos: Vector2i) -> PlayerState:
	var best: PlayerState = null
	var best_dist: int = 999
	for player_entry in bs.players:
		var player: PlayerState = player_entry as PlayerState
		if not player.alive:
			continue
		var dist: int = Pathfinder.manhattan(from_pos, player.pos)
		if dist < best_dist:
			best = player
			best_dist = dist
		elif dist == best_dist and best != null and player.seat_index < best.seat_index:
			best = player
	return best

# ─── Condition Helpers ────────────────────────────────────────────────────────

func _apply_condition_to_player(player: PlayerState, condition: String) -> void:
	if player == null or not player.alive:
		return
	match condition:
		"poison": player.poison = true
		"stun": player.stun = true
		"entangle": player.entangle = true
		"hidden": player.hidden = true
		"confused": player.confused = true
		"slow": pass
	bs.log_msg("  %s gains %s." % [player.name, condition.capitalize()])

func _apply_condition_to_enemy(enemy: EnemyState, condition: String) -> void:
	if enemy == null or not enemy.alive:
		return
	match condition:
		"poison": enemy.poison = true
		"stun": enemy.stun = true
		"entangle": enemy.entangle = true
		"hidden": enemy.hidden = true
		"confused": enemy.confused = true
		"slow": enemy.slow = true
	bs.log_msg("  Enemy %d gains %s." % [enemy.index + 1, condition.capitalize()])

# ─── XP and Level-Up ─────────────────────────────────────────────────────────

func _award_xp_for_kill(enemy: EnemyState) -> void:
	var xp: int = enemy.xp_reward
	for player_entry in bs.players:
		var player: PlayerState = player_entry as PlayerState
		if not player.alive:
			continue
		player.xp += xp
		bs.log_msg("  %s earns %d XP (total: %d, next level: %d)." % [
			player.name, xp, player.xp, player.xp_for_next_level()])
		if player.can_level_up() and not _level_up_queue.has(player.seat_index):
			_level_up_queue.append(player.seat_index)
			bs.log_msg("  %s is ready to level up!" % player.name)

func _process_level_up_queue() -> void:
	while not _level_up_queue.is_empty():
		var seat_idx: int = _level_up_queue.pop_front()
		var player: PlayerState = bs.get_player(seat_idx)
		if player == null or not player.can_level_up():
			continue
		await _show_level_up_overlay(player)

func _show_level_up_overlay(player: PlayerState) -> void:
	var new_level: int = player.level + 1
	var class_cards := CardData.get_class_cards_for_level(player.hero_type, new_level)
	if class_cards.is_empty():
		player.level += 1
		bs.log_msg("%s reached Level %d (no class cards available)." % [player.name, player.level])
		return

	var scene := load("res://LevelUpOverlay.tscn") as PackedScene
	if scene == null:
		push_error("LevelUpOverlay.tscn not found")
		player.level += 1
		return

	var overlay: Control = scene.instantiate()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	overlay.setup(player, new_level)

	var result_option := -1
	var result_cards: Array = []
	overlay.level_up_confirmed.connect(func(option: int, chosen_names: Array) -> void:
		result_option = option
		result_cards = chosen_names
	)

	await overlay.level_up_confirmed
	overlay.queue_free()
	await get_tree().process_frame

	player.level += 1
	if result_option == 0:
		player.max_hp += 1
		bs.log_msg("%s leveled up to %d! +1 Max HP (now %d)." % [player.name, player.level, player.max_hp])
	elif result_option == 1:
		player.max_stamina += 1
		bs.log_msg("%s leveled up to %d! +1 Max Stamina (now %d)." % [player.name, player.level, player.max_stamina])
	else:
		bs.log_msg("%s leveled up to %d! (3 class cards)." % [player.name, player.level])

	for card_name in result_cards:
		var card := CardData.from_name(String(card_name))
		if card != null:
			player.discard_pile.append(card)
			bs.log_msg("  %s added to %s's deck." % [card.card_name, player.name])

	_update_ui()

# ─── Board Input Handlers ─────────────────────────────────────────────────────

func _on_tile_pressed(pos: Vector2i) -> void:
	if _pending_move_player_index >= 0 and highlighted_tiles.has(pos):
		if online_enabled and not online_is_host:
			online_session.send_command({
				"kind": "choose_move_destination",
				"seat_index": _pending_move_player_index,
				"pos": [pos.x, pos.y],
			})
			return
		move_dest_chosen.emit(pos)

func _on_board_enemy_pressed(enemy_idx: int) -> void:
	_try_choose_attack_target(enemy_idx)

func _on_enemy_panel_input(event: InputEvent, enemy_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_try_choose_attack_target(enemy_idx)

func _show_end(victory: bool) -> void:
	var scene := load("res://EndOverlay.tscn") as PackedScene
	end_overlay = scene.instantiate()
	end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(end_overlay)
	end_overlay.setup(victory)
	end_overlay.restart_requested.connect(_on_restart)
	end_overlay.title_requested.connect(_on_title)

func _on_restart() -> void:
	if end_overlay:
		end_overlay.queue_free()
		end_overlay = null
	_start_battle()

func _on_title() -> void:
	if online_session != null and online_enabled:
		online_session.reset()
	return_to_title.emit()

func _flash_red_screen() -> void:
	if _screen_flash == null:
		return
	var tw := create_tween()
	tw.tween_property(_screen_flash, "color:a", 0.45, 0.06)
	tw.tween_property(_screen_flash, "color:a", 0.0, 0.30)
	await tw.finished

func _try_choose_attack_target(enemy_idx: int) -> void:
	if not _targetable_enemy_indices.has(enemy_idx):
		return
	if online_enabled and not online_is_host:
		if _pending_attack_player_index == owned_seat_index:
			online_session.send_command({
				"kind": "choose_attack_target",
				"seat_index": owned_seat_index,
				"enemy_index": enemy_idx,
			})
		return
	if _active_target_enemy_idx != enemy_idx:
		_active_target_enemy_idx = enemy_idx
		bs.log_msg("  Enemy %d targeted. Tap again to attack." % (enemy_idx + 1))
		_update_ui()
		_sync_online_snapshot()
		return
	_update_ui()
	attack_target_chosen.emit(enemy_idx)

func _clear_attack_targeting() -> void:
	_pending_attack_player_index = -1
	_targetable_enemy_indices.clear()
	_active_target_enemy_idx = -1
	for enemy_idx in range(_enemy_panels.size()):
		_stop_enemy_panel_target_pulse(enemy_idx)
	if board_3d:
		board_3d.clear_enemy_target_state()

func _refresh_enemy_panel_visual(enemy_idx: int) -> void:
	var panel: PanelContainer = _enemy_panels[enemy_idx]
	if panel == null:
		return
	var color := ENEMY_PANEL_BASE_COLOR
	if enemy_idx == _active_target_enemy_idx:
		color = ENEMY_PANEL_ACTIVE_COLOR
		_start_enemy_panel_target_pulse(enemy_idx)
	elif _targetable_enemy_indices.has(enemy_idx):
		color = ENEMY_PANEL_TARGETABLE_COLOR
		_stop_enemy_panel_target_pulse(enemy_idx)
		panel.scale = Vector2.ONE
	else:
		_stop_enemy_panel_target_pulse(enemy_idx)
		panel.scale = Vector2.ONE
	panel.add_theme_stylebox_override("panel", _flat_style(color, 5, 6))

func _start_enemy_panel_target_pulse(enemy_idx: int) -> void:
	if enemy_idx < 0 or enemy_idx >= _enemy_panels.size() or _enemy_panel_target_tweens.has(enemy_idx):
		return
	var panel: PanelContainer = _enemy_panels[enemy_idx]
	if panel == null:
		return
	panel.pivot_offset = panel.size * 0.5
	var tw := create_tween()
	_enemy_panel_target_tweens[enemy_idx] = tw
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(panel, "scale", Vector2(1.03, 1.03), 0.34)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.34)

func _stop_enemy_panel_target_pulse(enemy_idx: int) -> void:
	if not _enemy_panel_target_tweens.has(enemy_idx):
		return
	var tw: Tween = _enemy_panel_target_tweens[enemy_idx]
	if tw != null:
		tw.kill()
	_enemy_panel_target_tweens.erase(enemy_idx)
	if enemy_idx >= 0 and enemy_idx < _enemy_panels.size() and _enemy_panels[enemy_idx] != null:
		_enemy_panels[enemy_idx].scale = Vector2.ONE

# ─── Card Panel UI ────────────────────────────────────────────────────────────

func _make_card_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	var meta_lbl := Label.new()
	meta_lbl.add_theme_font_size_override("font_size", 13)
	meta_lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.42))
	vbox.add_child(meta_lbl)

	var fx_lbl := Label.new()
	fx_lbl.add_theme_font_size_override("font_size", 13)
	fx_lbl.add_theme_color_override("font_color", Color(0.74, 0.74, 0.82))
	fx_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(fx_lbl)

	panel.set_meta("name_lbl", name_lbl)
	panel.set_meta("meta_lbl", meta_lbl)
	panel.set_meta("fx_lbl", fx_lbl)
	_refresh_card_panel(panel, null, false)
	return panel

func _refresh_card_panel(panel: PanelContainer, card: CardData, selected: bool, active: bool = false) -> void:
	var bg := Color(0.10, 0.10, 0.14)
	if card != null:
		bg = Color(0.18, 0.30, 0.50) if selected else Color(0.14, 0.14, 0.21)
	var style := _flat_style(bg, 4, 5)
	if active:
		style.bg_color = Color(0.42, 0.48, 0.15)
		style.border_color = Color(1.0, 0.92, 0.22)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	var name_lbl: Label = panel.get_meta("name_lbl")
	var meta_lbl: Label = panel.get_meta("meta_lbl")
	var fx_lbl: Label = panel.get_meta("fx_lbl")
	if card == null:
		name_lbl.text = "empty"
		meta_lbl.text = ""
		fx_lbl.text = ""
		return
	name_lbl.text = card.card_name
	meta_lbl.text = "S:%d  I:%d" % [card.cost, card.initiative]
	fx_lbl.text = card.effect_text

# ─── Style Helpers ────────────────────────────────────────────────────────────

func _flat_style(color: Color, radius: int = 4, margin: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin - 2
	style.content_margin_bottom = margin - 2
	return style

func _style_btn(btn: Button, color: Color) -> void:
	btn.add_theme_stylebox_override("normal", _flat_style(color, 5, 6))
	btn.add_theme_stylebox_override("hover", _flat_style(color.lightened(0.14), 5, 6))
	btn.add_theme_stylebox_override("pressed", _flat_style(color.darkened(0.12), 5, 6))
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color.WHITE)

func _lbl(text: String, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20 if bold else 18)
	if bold:
		label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.76))
	return label

func _expand_spacer() -> Control:
	var control := Control.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return control

# ─── Online Sync ──────────────────────────────────────────────────────────────

func _sync_online_snapshot() -> void:
	if not online_enabled or not online_is_host or online_session == null:
		return
	var snapshot := {
		"battle": bs.to_dict(),
		"highlighted_tiles": _serialize_positions(highlighted_tiles),
		"pending_move_player_index": _pending_move_player_index,
		"pending_attack_player_index": _pending_attack_player_index,
		"targetable_enemy_indices": _targetable_enemy_indices.duplicate(),
		"active_target_enemy_idx": _active_target_enemy_idx,
	}
	online_session.push_snapshot(snapshot)

func _on_online_room_state_updated(room_state: Dictionary) -> void:
	if online_is_host:
		return
	var revision: int = int(room_state.get("revision", -1))
	if revision == _last_guest_snapshot_revision:
		return
	_last_guest_snapshot_revision = revision
	var snapshot: Dictionary = room_state.get("snapshot", {})
	if snapshot.is_empty() or not snapshot.has("battle"):
		return
	bs.load_from_dict(snapshot.get("battle", {}))
	highlighted_tiles = _deserialize_positions(snapshot.get("highlighted_tiles", []))
	_pending_move_player_index = int(snapshot.get("pending_move_player_index", -1))
	_pending_attack_player_index = int(snapshot.get("pending_attack_player_index", -1))
	_targetable_enemy_indices.clear()
	for enemy_idx in snapshot.get("targetable_enemy_indices", []):
		_targetable_enemy_indices.append(int(enemy_idx))
	_active_target_enemy_idx = int(snapshot.get("active_target_enemy_idx", -1))
	if bs.current_phase == BattleState.Phase.SELECT:
		var owned_player = bs.get_player(owned_seat_index)
		if owned_player != null and owned_player.alive and not owned_player.ready:
			bs.selected_planning_player_index = owned_seat_index
	ui_locked = (
		bs.current_phase != BattleState.Phase.SELECT
		and bs.current_phase != BattleState.Phase.REFRESH
		and _pending_move_player_index < 0
		and _pending_attack_player_index < 0
	)
	_update_ui()

func _on_online_command_received(command: Dictionary) -> void:
	if not online_is_host:
		return
	var payload: Dictionary = command.get("payload", {})
	var seat: int = int(payload.get("seat_index", -1))
	if seat < 0:
		return
	match String(payload.get("kind", "")):
		"select_card":
			bs.select_card(seat, int(payload.get("hand_index", -1)))
		"deselect_card":
			bs.deselect_card(seat, int(payload.get("selected_index", -1)))
		"move_selected_card":
			bs.move_selected_card(seat, int(payload.get("selected_index", -1)), int(payload.get("direction", 0)))
		"rotate_card":
			var player = bs.get_player(seat)
			if player != null:
				_select_rotated_card(player, int(payload.get("hand_index", -1)), String(payload.get("rotation_kind", "move")))
		"rotate_as_move":
			var player = bs.get_player(seat)
			if player != null:
				_select_rotated_card(player, int(payload.get("hand_index", -1)), "move")
		"set_ready":
			bs.set_player_ready(seat, bool(payload.get("ready", false)))
			if bs.all_living_players_ready():
				_run_round()
		"choose_move_destination":
			if seat == _pending_move_player_index:
				var pos_arr: Array = payload.get("pos", [])
				if pos_arr.size() >= 2:
					move_dest_chosen.emit(Vector2i(int(pos_arr[0]), int(pos_arr[1])))
		"choose_attack_target":
			if seat == _pending_attack_player_index:
				_try_choose_attack_target(int(payload.get("enemy_index", -1)))
	_update_ui()

func _on_online_request_failed(message: String) -> void:
	bs.log_msg("Network: %s" % message)
	_update_ui()

func _serialize_positions(positions: Array) -> Array:
	var result: Array = []
	for pos in positions:
		var typed_pos: Vector2i = pos
		result.append([typed_pos.x, typed_pos.y])
	return result

func _deserialize_positions(data: Array) -> Array:
	var result: Array = []
	for entry in data:
		var arr: Array = entry
		if arr.size() >= 2:
			result.append(Vector2i(int(arr[0]), int(arr[1])))
	return result

extends Control

signal return_to_title
signal move_dest_chosen(pos: Vector2i)
signal attack_target_chosen(enemy_idx: int)

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

var round_lbl: Label
var phase_lbl: Label
var active_player_lbl: Label
var order_lbl: Label
var _turn_order_row: Control = null
var planning_hint_lbl: Label
var prev_player_btn: Button
var next_player_btn: Button

var board_3d: Board3D = null
var _enemy_panels: Array = []
var _enemy_hp_lbls: Array = []
var _enemy_block_lbls: Array = []
var _enemy_status_lbls: Array = []
var _enemy_behavior_lbls: Array = []
var _enemy_deck_lbls: Array = []
var end_overlay: Control = null
var log_lbl: Label
var _screen_flash: ColorRect = null
var _active_resolving_seat := -1
var _active_resolving_card := -1

var _player_cards: Array = []  # Array[Dictionary]

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

		var meta_lbl := _lbl("Cleric  Draw: 10  Discard: 0  Init: -")
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
		for hand_idx in range(PLAYER_HAND_SIZE):
			var hand_panel := _make_card_panel()
			hand_panel.gui_input.connect(_on_hand_card_input.bind(seat_index, hand_idx))
			hand_row.add_child(hand_panel)
			hand_cards.append(hand_panel)

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
		var hp_lbl := _lbl("HP: 10/10")
		hp_lbl.add_theme_color_override("font_color", Color(0.92, 0.40, 0.40))
		panel_vbox.add_child(hp_lbl)
		_enemy_hp_lbls.append(hp_lbl)

		var block_lbl := _lbl("Block: 0")
		block_lbl.add_theme_color_override("font_color", Color(0.52, 0.72, 0.98))
		panel_vbox.add_child(block_lbl)
		_enemy_block_lbls.append(block_lbl)

		var status_lbl := _lbl("")
		status_lbl.add_theme_color_override("font_color", Color(0.88, 0.82, 0.48))
		panel_vbox.add_child(status_lbl)
		_enemy_status_lbls.append(status_lbl)

		var behavior_lbl := _lbl("Intent: ?")
		behavior_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		behavior_lbl.custom_minimum_size = Vector2(0, 86)
		panel_vbox.add_child(behavior_lbl)
		_enemy_behavior_lbls.append(behavior_lbl)

		var deck_lbl := _lbl("Draw: 3  Discard: 0")
		deck_lbl.add_theme_color_override("font_color", Color(0.64, 0.66, 0.74))
		panel_vbox.add_child(deck_lbl)
		_enemy_deck_lbls.append(deck_lbl)

func _build_log(parent: Control) -> void:
	log_lbl = Label.new()
	log_lbl.custom_minimum_size = Vector2(0, 120)
	log_lbl.add_theme_color_override("font_color", Color(0.76, 0.76, 0.84))
	log_lbl.add_theme_font_size_override("font_size", 18)
	log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(log_lbl)

func _start_battle() -> void:
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
	for enemy in bs.enemies:
		if enemy.alive and enemy.revealed != null:
			bs.log_msg("Enemy %d reveals %s (Init %d)." % [enemy.index + 1, enemy.revealed.behavior_name, enemy.revealed.initiative])
	_update_ui()
	_sync_online_snapshot()

func _begin_next_round() -> void:
	ui_locked = false
	highlighted_tiles.clear()
	_pending_move_player_index = -1
	_clear_attack_targeting()
	bs.start_next_round()
	for enemy in bs.enemies:
		if enemy.alive and enemy.revealed != null:
			bs.log_msg("Enemy %d reveals %s (Init %d)." % [enemy.index + 1, enemy.revealed.behavior_name, enemy.revealed.initiative])
	_update_ui()
	_sync_online_snapshot()

func _update_ui() -> void:
	round_lbl.text = "Round: %d" % bs.round_number
	phase_lbl.text = "Phase: %s" % _phase_text(bs.current_phase)
	var multiplayer_ui: bool = bs.player_count > 1
	prev_player_btn.visible = multiplayer_ui
	next_player_btn.visible = multiplayer_ui
	active_player_lbl.visible = multiplayer_ui
	active_player_lbl.text = "Editing: %s" % _active_player().name
	order_lbl.text = "Order: %s" % _actor_order_preview()
	planning_hint_lbl.text = _planning_hint_text()

	for enemy_idx in range(_enemy_panels.size()):
		if enemy_idx < bs.enemies.size():
			var enemy = bs.enemies[enemy_idx]
			_enemy_panels[enemy_idx].visible = true
			_refresh_enemy_panel_visual(enemy_idx)
			_enemy_hp_lbls[enemy_idx].text = "HP: %d/%d" % [enemy.hp, enemy.max_hp]
			_enemy_block_lbls[enemy_idx].text = "Block: %d" % enemy.block
			_enemy_status_lbls[enemy_idx].text = enemy.status_text()
			if enemy.revealed != null:
				_enemy_behavior_lbls[enemy_idx].text = "Intent: %s\nInit %d\n%s" % [
					enemy.revealed.behavior_name,
					enemy.revealed.initiative,
					enemy.revealed.effect_text,
				]
			else:
				_enemy_behavior_lbls[enemy_idx].text = "Intent: ?"
			_enemy_deck_lbls[enemy_idx].text = "Draw: %d  Discard: %d" % [enemy.draw.size(), enemy.discard.size()]
		else:
			_enemy_panels[enemy_idx].visible = false
			_stop_enemy_panel_target_pulse(enemy_idx)

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
		ui["meta_lbl"].text = "Draw: %d  Discard: %d  Init: %s" % [
			player.draw_pile.size(),
			player.discard_pile.size(),
			"-" if player.selected.is_empty() else str(player.initiative())
		]
		ui["stamina_lbl"].text = "Stamina: %d/3" % (3 - player.selected_stamina())
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
			hand_cards[hand_idx].mouse_filter = Control.MOUSE_FILTER_STOP if can_edit else Control.MOUSE_FILTER_IGNORE

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
	if bs.current_phase != BattleState.Phase.SELECT:
		return "Watch the actor order resolve from lowest initiative upward."
	if player.ready:
		return "%s is ready. Focus another player or unready to edit." % player.name
	return "%s is active. Click that player's hand to select up to 3 cards, reorder selected cards, then press Ready." % player.name

func _phase_text(phase: int) -> String:
	match phase:
		BattleState.Phase.SETUP:
			return "Setup"
		BattleState.Phase.SELECT:
			return "Planning"
		BattleState.Phase.REVEAL:
			return "Reveal"
		BattleState.Phase.RESOLVE:
			return "Resolve"
		BattleState.Phase.REFRESH:
			return "Refresh"
		BattleState.Phase.VICTORY:
			return "Victory"
		BattleState.Phase.DEFEAT:
			return "Defeat"
		_:
			return "Title"

func _actor_order_preview() -> String:
	var pieces: Array[String] = []
	for actor in bs.build_actor_order(false):
		if actor["actor_type"] == "player":
			var player = bs.get_player(actor["seat_index"])
			pieces.append("%s(%d)" % [player.name, actor["initiative"]])
		else:
			pieces.append("Enemy %d(%d)" % [actor["enemy_index"] + 1, actor["initiative"]])
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
		if _actor_key(actors[i]) == key:
			return i
	return 0

func _make_turn_order_token(actor: Dictionary) -> PanelContainer:
	var is_player: bool = String(actor["actor_type"]) == "player"
	var title: String = ""
	var color: Color = Color(0.46, 0.10, 0.10)
	if is_player:
		var player = bs.get_player(actor["seat_index"])
		title = player.name.to_upper()
		color = Color(0.12, 0.22, 0.55)
	else:
		title = "ENEMY %d" % (actor["enemy_index"] + 1)
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

func _on_ready_pressed(seat_index: int) -> void:
	_toggle_player_ready(bs.get_player(seat_index))

func _toggle_player_ready(player) -> void:
	if player == null or ui_locked or bs.current_phase != BattleState.Phase.SELECT:
		return
	if online_enabled and player.seat_index != owned_seat_index:
		return
	var new_ready: bool = not player.ready
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
	if existing != null:
		existing.kill()
	target_lbl.add_theme_color_override("font_color", base_color)
	target_lbl.scale = Vector2.ONE
	target_lbl.modulate = Color.WHITE
	target_lbl.pivot_offset = target_lbl.size * 0.5

	var tw := create_tween()
	ui[tween_key] = tw
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(target_lbl, "scale", Vector2(1.28, 1.28), 0.14)
	tw.tween_property(target_lbl, "modulate", accent, 0.10)

	var settle := tw.chain()
	settle.set_parallel(true)
	settle.set_ease(Tween.EASE_IN_OUT)
	settle.set_trans(Tween.TRANS_CUBIC)
	settle.tween_property(target_lbl, "scale", Vector2.ONE, 0.18)
	settle.tween_property(target_lbl, "modulate", Color.WHITE, 0.16)

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

func _run_round() -> void:
	if ui_locked:
		return
	ui_locked = true
	bs.current_phase = BattleState.Phase.RESOLVE
	_update_ui()

	var actors = bs.build_actor_order(true)
	await _show_turn_order(actors)
	if actors.is_empty():
		bs.log_msg("No actors this round.")
		_finish_round()
		return

	for actor in actors:
		if await _check_end():
			return
		if actor["actor_type"] == "player":
			var player = bs.get_player(actor["seat_index"])
			await _resolve_player(player)
		else:
			await _resolve_enemy(bs.get_enemy(actor["enemy_index"]))
		_update_ui()
		if await _check_end():
			return

	_finish_round()

func _finish_round() -> void:
	bs.end_round_cleanup()
	for enemy in bs.enemies:
		if enemy.alive:
			enemy.slow = false
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

func _resolve_player(player) -> void:
	if player == null or not player.alive:
		return
	if player.selected.is_empty():
		return
	var selected_cards: Array = player.selected.duplicate()
	for card_idx in range(selected_cards.size()):
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

func _resolve_player_effect(player, fx: Dictionary, card: CardData) -> void:
	match fx["type"]:
		"attack":
			var rng: int = fx.get("range", 1)
			var bonus: int = 2 if player.bless else 0
			player.bless = false
			var target = await _choose_attack_target(player, rng, card)
			if target == null:
				bs.log_msg("  %s fizzled for %s (enemy out of range %d)." % [card.card_name, player.name, rng])
				await get_tree().create_timer(0.18).timeout
				return
			var raw: int = fx["value"] + bonus
			var absorbed: int = mini(target.block, raw)
			var hp_before: int = target.hp
			if board_3d:
				if rng <= 1:
					await board_3d.animate_melee_attack(player.pos, target.pos)
				else:
					await board_3d.animate_ranged_attack(player.pos, target.pos)
				if absorbed > 0:
					await board_3d.animate_block(target.pos)
				await board_3d.animate_enemy_hit(target.index)
			bs.apply_damage_enemy(target, raw)
			var msg: String = "  %s deals %d" % [player.name, raw]
			if bonus > 0:
				msg += " (+%d Bless)" % bonus
			if absorbed > 0:
				msg += " — %d blocked" % absorbed
			msg += " = %d HP lost (Enemy %d: %d→%d)" % [raw - absorbed, target.index + 1, hp_before, target.hp]
			bs.log_msg(msg)
			await get_tree().create_timer(0.12).timeout
		"heal":
			var old_hp: int = player.hp
			player.hp = mini(player.hp + fx["value"], player.max_hp)
			player.alive = player.hp > 0
			bs.log_msg("  %s heals %d (HP %d→%d)" % [player.name, fx["value"], old_hp, player.hp])
			await get_tree().create_timer(0.14).timeout
		"block":
			player.block += fx["value"]
			bs.log_msg("  %s gains Block %d (→%d)" % [player.name, fx["value"], player.block])
			await get_tree().create_timer(0.14).timeout
		"move":
			await _resolve_player_move(player, fx["value"])
		"bless":
			player.bless = true
			bs.log_msg("  %s gains Bless." % player.name)
			await get_tree().create_timer(0.14).timeout
		"slow":
			var target = _nearest_enemy_to_player(player.pos)
			if target != null:
				target.slow = true
				bs.log_msg("  Enemy %d gains Slow." % (target.index + 1))
			await get_tree().create_timer(0.14).timeout

func _resolve_player_move(player, budget: int) -> void:
	var blocked = bs.occupied_positions_for_player(player.seat_index)
	var reachable = Pathfinder.get_reachable(player.pos, budget, blocked)
	if reachable.is_empty():
		bs.log_msg("  %s's move fizzled: no reachable tiles." % player.name)
		return
	_pending_move_player_index = player.seat_index
	highlighted_tiles = reachable
	_update_board()
	_sync_online_snapshot()
	bs.log_msg("  %s choose a destination tile." % player.name)
	var dest: Vector2i = await move_dest_chosen
	highlighted_tiles.clear()
	_pending_move_player_index = -1
	_update_board()
	var path = Pathfinder.find_path(player.pos, dest, blocked)
	if path.is_empty() and dest != player.pos:
		bs.log_msg("  %s's move fizzled: path blocked." % player.name)
		return
	for step in path:
		player.pos = step
		if board_3d:
			await board_3d.animate_player_step(player.seat_index, step)
		_update_ui()
	bs.log_msg("  %s moves to %s." % [player.name, str(dest)])

func _resolve_enemy(enemy) -> void:
	if enemy == null or not enemy.alive or enemy.revealed == null:
		return
	bs.log_msg("◀ Enemy %d: %s" % [enemy.index + 1, enemy.revealed.behavior_name])
	_update_ui()
	await get_tree().create_timer(0.2).timeout
	for effect in enemy.revealed.effects:
		await _resolve_enemy_effect(enemy, effect)
		_update_ui()
		if bs.all_enemies_dead() or bs.any_player_dead():
			return

func _resolve_enemy_effect(enemy, fx: Dictionary) -> void:
	match fx["type"]:
		"block":
			enemy.block += fx["value"]
			bs.log_msg("  Enemy %d gains Block %d (→%d)." % [enemy.index + 1, fx["value"], enemy.block])
			await get_tree().create_timer(0.14).timeout
		"move_toward":
			var steps: int = fx["value"]
			if enemy.slow:
				steps = maxi(steps - 1, 0)
				bs.log_msg("  Slow reduces enemy %d move to %d." % [enemy.index + 1, steps])
			await _enemy_move(enemy, steps)
		"attack_if_adj":
			await _enemy_attack_if_adj(enemy, fx["value"], false)
		"lunge":
			var target = _nearest_living_player(enemy.pos)
			if target != null and Pathfinder.manhattan(enemy.pos, target.pos) <= 1:
				await _enemy_attack_if_adj(enemy, fx["attack_value"], true)
			else:
				var steps: int = fx["move_value"]
				if enemy.slow:
					steps = maxi(steps - 1, 0)
				await _enemy_move(enemy, steps)

func _enemy_move(enemy, steps: int) -> void:
	for _step in range(steps):
		var target = _nearest_living_player(enemy.pos)
		if target == null:
			return
		var blocked = bs.living_player_positions()
		for pos in bs.living_enemy_positions(enemy.index):
			blocked.append(pos)
		var next: Vector2i = _best_step_toward(enemy.pos, target.pos, blocked)
		if next == Vector2i(-1, -1):
			return
		enemy.pos = next
		if board_3d:
			await board_3d.animate_enemy_step(enemy.index, next)
		bs.log_msg("  Enemy %d moves to %s." % [enemy.index + 1, str(next)])
		_update_ui()

func _enemy_attack_if_adj(enemy, raw: int, is_lunge: bool) -> void:
	var target = _nearest_living_player(enemy.pos)
	if target == null:
		return
	if Pathfinder.manhattan(enemy.pos, target.pos) > 1:
		bs.log_msg("  Enemy %d is not adjacent to any hero." % (enemy.index + 1))
		await get_tree().create_timer(0.16).timeout
		return
	var absorbed: int = mini(target.block, raw)
	var hp_before: int = target.hp
	if board_3d:
		await board_3d.animate_melee_attack(enemy.pos, target.pos)
		if absorbed > 0:
			await board_3d.animate_block(target.pos)
		await board_3d.animate_player_hit(target.seat_index)
	bs.apply_damage_player(target, raw)
	await _flash_red_screen()
	var msg: String = "  Enemy %d %s %s for %d" % [
		enemy.index + 1,
		"lunges at" if is_lunge else "hits",
		target.name,
		raw,
	]
	if absorbed > 0:
		msg += " — %d blocked" % absorbed
	msg += " = %d HP lost (%s: %d→%d)" % [raw - absorbed, target.name, hp_before, target.hp]
	bs.log_msg(msg)
	await get_tree().create_timer(0.12).timeout

func _nearest_enemy_to_player(from_pos: Vector2i, max_range: int = 99):
	var best = null
	var best_dist: int = 999
	for enemy in bs.enemies:
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

func _enemies_in_range(from_pos: Vector2i, max_range: int) -> Array:
	var targets: Array = []
	for enemy in bs.enemies:
		if not enemy.alive:
			continue
		if Pathfinder.manhattan(from_pos, enemy.pos) <= max_range:
			targets.append(enemy)
	targets.sort_custom(func(a, b) -> bool:
		var da: int = Pathfinder.manhattan(from_pos, a.pos)
		var db: int = Pathfinder.manhattan(from_pos, b.pos)
		if da == db:
			return a.index < b.index
		return da < db
	)
	return targets

func _choose_attack_target(player, rng: int, card: CardData):
	var targets := _enemies_in_range(player.pos, rng)
	if targets.is_empty():
		return null
	if targets.size() == 1:
		return targets[0]

	_pending_attack_player_index = player.seat_index
	_targetable_enemy_indices.clear()
	for enemy in targets:
		_targetable_enemy_indices.append(enemy.index)
	_active_target_enemy_idx = -1
	bs.log_msg("  %s: tap an enemy to target, then tap again to attack." % card.card_name)
	_update_ui()
	_sync_online_snapshot()

	var chosen_idx: int = await attack_target_chosen
	for enemy in targets:
		if enemy.index == chosen_idx and enemy.alive:
			_clear_attack_targeting()
			_update_ui()
			_sync_online_snapshot()
			return enemy

	_clear_attack_targeting()
	_update_ui()
	_sync_online_snapshot()
	return null

func _nearest_living_player(from_pos: Vector2i):
	var best = null
	var best_dist: int = 999
	# Enemy targeting is deterministic for multiplayer:
	# nearest living hero by Manhattan distance, then lower seat index on ties.
	for player in bs.players:
		if not player.alive:
			continue
		var dist: int = Pathfinder.manhattan(from_pos, player.pos)
		if dist < best_dist:
			best = player
			best_dist = dist
		elif dist == best_dist and best != null and player.seat_index < best.seat_index:
			best = player
	return best

func _best_step_toward(from_pos: Vector2i, toward: Vector2i, blocked: Array) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: int = Pathfinder.manhattan(from_pos, toward)
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var candidate: Vector2i = from_pos + delta
		if candidate.x < 0 or candidate.x >= 5 or candidate.y < 0 or candidate.y >= 5:
			continue
		if blocked.has(candidate):
			continue
		var dist: int = Pathfinder.manhattan(candidate, toward)
		if dist < best_dist:
			best = candidate
			best_dist = dist
	return best

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
	meta_lbl.text = "C:%d  I:%d" % [card.cost, card.initiative]
	fx_lbl.text = card.effect_text

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
	ui_locked = bs.current_phase != BattleState.Phase.SELECT and _pending_move_player_index < 0 and _pending_attack_player_index < 0
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

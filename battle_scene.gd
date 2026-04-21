extends Control

signal return_to_title

# ── state ──────────────────────────────────────────────────────────────────
var bs: BattleState
var ui_locked := false
var highlighted_tiles: Array = []
var _targetable_enemy_indices: Array = []
var _active_target_enemy_idx := -1
var _enemy_panel_target_tweens: Dictionary = {}

signal move_dest_chosen(pos: Vector2i)
signal attack_target_chosen(enemy_idx: int)

# ── UI refs ────────────────────────────────────────────────────────────────
var round_lbl: Label
var stamina_lbl: Label
var initiative_lbl: Label
var confirm_btn: Button

var hero_hp_lbl: Label
var hero_block_lbl: Label
var hero_status_lbl: Label
var hero_deck_lbl: Label

# Per-enemy panel refs (always 3 slots, hidden if unused)
var _enemy_panels: Array = []
var _enemy_hp_lbls: Array = []
var _enemy_block_lbls: Array = []
var _enemy_status_lbls: Array = []
var _enemy_behavior_lbls: Array = []
var _enemy_deck_lbls: Array = []

var board_3d: Board3D = null
var hand_panels: Array = []
var sel_panels: Array = []

# ── Turn order panel ───────────────────────────────────────────────────────
var _turn_row: Control = null
var _hero_tok: PanelContainer = null
var _enemy_tok: PanelContainer = null
var _hero_tok_init_lbl: Label = null
var _enemy_tok_init_lbl: Label = null

var log_lbl: Label
var end_overlay: Control = null
var _screen_flash: ColorRect = null
var _stamina_pulse_tween: Tween = null
var _hero_area_pulse_tweens: Dictionary = {}
var _last_hero_block: int = -1
var _last_hero_status_text := ""
var _board_zoom_size := Board3D.ZOOM_MIN

const STAMINA_BASE_FONT_SIZE := 14
const STAMINA_PULSE_FONT_SIZE := 22
const STAMINA_BASE_COLOR := Color(0.9, 0.75, 0.3)
const STAMINA_SPEND_COLOR := Color(1.0, 0.95, 0.45)
const STAMINA_REFUND_COLOR := Color(0.72, 0.95, 0.55)
const HERO_AREA_BASE_SCALE := Vector2.ONE
const HERO_AREA_PULSE_SCALE := Vector2(1.14, 1.14)
const HERO_BLOCK_BASE_COLOR := Color(0.5, 0.7, 0.95)
const HERO_BLOCK_PULSE_COLOR := Color(0.78, 0.88, 1.0)
const HERO_STATUS_BASE_COLOR := Color(0.9, 0.85, 0.3)
const HERO_STATUS_PULSE_COLOR := Color(1.0, 0.96, 0.58)
const ENEMY_PANEL_BASE_COLOR := Color(0.18, 0.09, 0.09)
const ENEMY_PANEL_TARGETABLE_COLOR := Color(0.40, 0.26, 0.08)
const ENEMY_PANEL_ACTIVE_COLOR := Color(0.70, 0.56, 0.12)

# ═══════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bs = BattleState.new()
	_build_ui()
	_start_battle()

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
			KEY_1: _try_select_hand(0)
			KEY_2: _try_select_hand(1)
			KEY_3: _try_select_hand(2)
			KEY_4: _try_select_hand(3)
			KEY_5: _try_select_hand(4)
			KEY_ENTER, KEY_KP_ENTER: _on_confirm_pressed()

# ═══════════════════════════════════════════════════════════════════════════
# UI BUILD
# ═══════════════════════════════════════════════════════════════════════════

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
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	_build_top_bar(root)
	_build_turn_order_row(root)
	_build_middle(root)
	_build_selected_row(root)
	_build_hand_row(root)
	_build_log(root)

	_screen_flash = ColorRect.new()
	_screen_flash.color = Color(0.75, 0.05, 0.05, 0.0)
	_screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_flash)

func _build_top_bar(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	round_lbl = _lbl("Round: 1")
	hbox.add_child(round_lbl)

	hbox.add_child(_expand_spacer())

	initiative_lbl = _lbl("Initiative: -")
	initiative_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.95))
	hbox.add_child(initiative_lbl)

	hbox.add_child(_fixed_spacer(12))

	confirm_btn = Button.new()
	confirm_btn.text = "CONFIRM"
	confirm_btn.custom_minimum_size = Vector2(130, 40)
	confirm_btn.add_theme_font_size_override("font_size", 15)
	_style_btn(confirm_btn, Color(0.18, 0.48, 0.22))
	confirm_btn.pressed.connect(_on_confirm_pressed)
	hbox.add_child(confirm_btn)

func _build_turn_order_row(parent: Control) -> void:
	_turn_row = Control.new()
	_turn_row.custom_minimum_size = Vector2(0, 54)
	_turn_row.visible = false
	parent.add_child(_turn_row)

	var order_lbl := _lbl("Turn order:", true)
	order_lbl.position = Vector2(0, 14)
	_turn_row.add_child(order_lbl)

	var tok_c := Control.new()
	tok_c.custom_minimum_size = Vector2(340, 50)
	tok_c.position = Vector2(125, 2)
	_turn_row.add_child(tok_c)

	_hero_tok  = _make_tok(Color(0.12, 0.22, 0.52), "HERO")
	_hero_tok.position = Vector2(0, 0)
	tok_c.add_child(_hero_tok)

	var arrow := _lbl("→")
	arrow.position = Vector2(157, 12)
	arrow.add_theme_font_size_override("font_size", 20)
	tok_c.add_child(arrow)

	_enemy_tok = _make_tok(Color(0.45, 0.10, 0.10), "ENEMY")
	_enemy_tok.position = Vector2(172, 0)
	tok_c.add_child(_enemy_tok)

	_hero_tok_init_lbl  = _hero_tok.get_meta("init_lbl")
	_enemy_tok_init_lbl = _enemy_tok.get_meta("init_lbl")

func _make_tok(color: Color, unit_name: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(150, 48)
	p.add_theme_stylebox_override("panel", _flat_style(color, 5, 7))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	var nl := _lbl(unit_name, true)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nl)
	var il := _lbl("Init: ?")
	il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	il.add_theme_color_override("font_color", Color(0.9, 0.82, 0.3))
	vb.add_child(il)
	p.set_meta("init_lbl", il)
	return p

func _show_initiative(hero_init: int, enemy_init: int) -> void:
	_hero_tok_init_lbl.text  = "Init: %d" % hero_init
	_enemy_tok_init_lbl.text = "Init: %d" % enemy_init
	_hero_tok.position.x  = 0.0
	_enemy_tok.position.x = 172.0
	_turn_row.visible = true
	await get_tree().create_timer(0.55).timeout
	if hero_init > enemy_init:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.set_ease(Tween.EASE_IN_OUT)
		tw.set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(_hero_tok,  "position:x", 172.0, 0.44)
		tw.tween_property(_enemy_tok, "position:x",   0.0, 0.44)
		await tw.finished
		await get_tree().create_timer(0.25).timeout

func _hide_turn_order() -> void:
	_turn_row.visible = false
	_hero_tok.position.x  = 0.0
	_enemy_tok.position.x = 172.0

func _build_middle(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	_build_hero_panel(hbox)
	_build_board(hbox)
	_build_enemy_panels(hbox)

func _build_hero_panel(parent: Control) -> void:
	var panel := _panel(Color(0.09, 0.13, 0.20), 185)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	vbox.add_child(_lbl("HERO: Cleric", true))
	vbox.add_child(_lbl("──────────────"))
	hero_hp_lbl = _lbl("HP: 12/12")
	hero_hp_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	vbox.add_child(hero_hp_lbl)
	hero_block_lbl = _lbl("Block: 0")
	hero_block_lbl.add_theme_color_override("font_color", HERO_BLOCK_BASE_COLOR)
	vbox.add_child(hero_block_lbl)
	hero_status_lbl = _lbl("")
	hero_status_lbl.add_theme_color_override("font_color", HERO_STATUS_BASE_COLOR)
	vbox.add_child(hero_status_lbl)
	vbox.add_child(_expand_spacer())
	vbox.add_child(_lbl("──────────────"))
	hero_deck_lbl = _lbl("Draw: 10\nDiscard: 0")
	hero_deck_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	hero_deck_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(hero_deck_lbl)

func _build_board(parent: Control) -> void:
	var svc := SubViewportContainer.new()
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	svc.stretch = true
	parent.add_child(svc)

	var sv := SubViewport.new()
	sv.size = Vector2i(560, 460)
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

func _build_enemy_panels(parent: Control) -> void:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(185, 0)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_stylebox_override("panel", _flat_style(Color(0.10, 0.06, 0.06), 5, 0))
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

	for i in range(3):
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", _flat_style(ENEMY_PANEL_BASE_COLOR, 4, 5))
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.gui_input.connect(_on_enemy_panel_input.bind(i))
		p.visible = false
		vbox.add_child(p)
		_enemy_panels.append(p)

		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 2)
		p.add_child(pv)

		var name_lbl := _lbl("UNDEAD %d" % (i + 1), true)
		pv.add_child(name_lbl)
		pv.add_child(_lbl("──────────"))

		var hp_lbl := _lbl("HP: 10/10")
		hp_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		pv.add_child(hp_lbl)
		_enemy_hp_lbls.append(hp_lbl)

		var block_lbl := _lbl("Block: 0")
		block_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.95))
		pv.add_child(block_lbl)
		_enemy_block_lbls.append(block_lbl)

		var status_lbl := _lbl("")
		status_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 0.9))
		pv.add_child(status_lbl)
		_enemy_status_lbls.append(status_lbl)

		var beh_lbl := _lbl("Intent: ?")
		beh_lbl.add_theme_color_override("font_color", Color(0.85, 0.65, 0.3))
		beh_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		pv.add_child(beh_lbl)
		_enemy_behavior_lbls.append(beh_lbl)

		var deck_lbl := _lbl("Draw: 3")
		deck_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
		deck_lbl.add_theme_font_size_override("font_size", 12)
		pv.add_child(deck_lbl)
		_enemy_deck_lbls.append(deck_lbl)

func _build_selected_row(parent: Control) -> void:
	var stamina_holder := Control.new()
	stamina_holder.custom_minimum_size = Vector2(0, 34)
	parent.add_child(stamina_holder)

	stamina_lbl = _lbl("Stamina: 3/3")
	stamina_lbl.add_theme_font_size_override("font_size", STAMINA_BASE_FONT_SIZE)
	stamina_lbl.add_theme_color_override("font_color", STAMINA_BASE_COLOR)
	stamina_holder.add_child(stamina_lbl)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	var lbl := _lbl("Selected:")
	lbl.custom_minimum_size = Vector2(70, 0)
	hbox.add_child(lbl)

	sel_panels.clear()
	for i in range(3):
		var cp := _make_card_panel()
		cp.gui_input.connect(_on_sel_card_input.bind(i))
		hbox.add_child(cp)
		sel_panels.append(cp)

	hbox.add_child(_expand_spacer())

func _build_hand_row(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	var lbl := _lbl("Hand:")
	lbl.custom_minimum_size = Vector2(70, 0)
	hbox.add_child(lbl)

	hand_panels.clear()
	for i in range(5):
		var cp := _make_card_panel()
		cp.gui_input.connect(_on_hand_card_input.bind(i))
		hbox.add_child(cp)
		hand_panels.append(cp)

	hbox.add_child(_expand_spacer())

func _build_log(parent: Control) -> void:
	log_lbl = Label.new()
	log_lbl.custom_minimum_size = Vector2(0, 100)
	log_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.80))
	log_lbl.add_theme_font_size_override("font_size", 16)
	log_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(log_lbl)

# ═══════════════════════════════════════════════════════════════════════════
# UI UPDATE
# ═══════════════════════════════════════════════════════════════════════════

func _update_ui() -> void:
	round_lbl.text = "Round: " + str(bs.round_number)
	stamina_lbl.text = "Stamina: %d/3" % (3 - bs.selected_stamina())

	var hi := bs.hero_initiative()
	var ei := bs.enemy_min_initiative()
	var ei_str := str(ei) if ei < 99 else "?"
	initiative_lbl.text = "Init: " + (str(hi) if hi < 99 else "-") + " vs " + ei_str

	var in_select := bs.current_phase == BattleState.Phase.SELECT
	confirm_btn.disabled = ui_locked or not in_select

	hero_hp_lbl.text = "HP: %d/%d" % [bs.hero_hp, bs.hero_max_hp]
	hero_block_lbl.text = "Block: %d" % bs.hero_block
	var hero_status_text := "[Bless]" if bs.hero_bless else ""
	hero_status_lbl.text = hero_status_text
	hero_deck_lbl.text = "Draw: %d\nDiscard: %d" % [bs.hero_draw.size(), bs.hero_discard.size()]

	if _last_hero_block >= 0 and bs.hero_block > _last_hero_block:
		_pulse_hero_area_label(hero_block_lbl, HERO_BLOCK_BASE_COLOR, HERO_BLOCK_PULSE_COLOR)
	if _last_hero_status_text != "" and hero_status_text != _last_hero_status_text and hero_status_text != "":
		_pulse_hero_area_label(hero_status_lbl, HERO_STATUS_BASE_COLOR, HERO_STATUS_PULSE_COLOR)
	elif _last_hero_status_text == "" and hero_status_text != "" and _last_hero_block >= 0:
		_pulse_hero_area_label(hero_status_lbl, HERO_STATUS_BASE_COLOR, HERO_STATUS_PULSE_COLOR)
	_last_hero_block = bs.hero_block
	_last_hero_status_text = hero_status_text

	for i in range(3):
		if i < bs.enemies.size():
			_enemy_panels[i].visible = true
			var e: EnemyState = bs.enemies[i]
			_refresh_enemy_panel_visual(i)
			_enemy_hp_lbls[i].text = "HP: %d/%d" % [e.hp, e.max_hp]
			_enemy_block_lbls[i].text = "Block: %d" % e.block
			_enemy_status_lbls[i].text = "[Slow]" if e.slow else ("[Dead]" if e.hp <= 0 else "")
			_enemy_deck_lbls[i].text = "Draw: %d  Dis: %d" % [e.draw.size(), e.discard.size()]
			if e.revealed != null:
				_enemy_behavior_lbls[i].text = "Intent:\n%s\n[Init %d]" % [e.revealed.behavior_name, e.revealed.initiative]
			else:
				_enemy_behavior_lbls[i].text = "Intent: ?"
		else:
			_enemy_panels[i].visible = false
			_stop_enemy_panel_target_pulse(i)

	_update_board()

	var interactive_hand := (not ui_locked) and in_select
	for i in range(5):
		var card: CardData = bs.hero_hand[i] if i < bs.hero_hand.size() else null
		_refresh_card_panel(hand_panels[i], card, false)
		hand_panels[i].mouse_filter = \
			Control.MOUSE_FILTER_STOP if interactive_hand else Control.MOUSE_FILTER_IGNORE

	var interactive_sel := (not ui_locked) and in_select
	for i in range(3):
		var card: CardData = bs.hero_selected[i] if i < bs.hero_selected.size() else null
		_refresh_card_panel(sel_panels[i], card, card != null)
		sel_panels[i].mouse_filter = \
			Control.MOUSE_FILTER_STOP if interactive_sel else Control.MOUSE_FILTER_IGNORE

	var lines: Array = bs.combat_log.slice(maxi(0, bs.combat_log.size() - 5))
	log_lbl.text = "\n".join(lines)

func _update_board() -> void:
	if board_3d:
		var positions: Array = []
		for e in bs.enemies:
			positions.append(e.pos if e.hp > 0 else Vector2i(-1, -1))
		board_3d.update_board(bs.hero_pos, positions, highlighted_tiles)
		board_3d.set_enemy_target_state(_targetable_enemy_indices, _active_target_enemy_idx)

# ═══════════════════════════════════════════════════════════════════════════
# STATE MACHINE
# ═══════════════════════════════════════════════════════════════════════════

func _start_battle() -> void:
	bs.setup()
	bs.draw_hero_hand()
	bs.round_number = 1
	bs.log_msg("=== Round 1 ===")
	bs.current_phase = BattleState.Phase.SELECT
	ui_locked = false
	highlighted_tiles.clear()
	_clear_attack_targeting()
	_update_ui()

func _on_confirm_pressed() -> void:
	if ui_locked or bs.current_phase != BattleState.Phase.SELECT:
		return
	ui_locked = true
	_update_ui()
	_run_round()

func _run_round() -> void:
	# ── REVEAL ──
	bs.current_phase = BattleState.Phase.REVEAL
	bs.reveal_enemy_behavior()
	for e in bs.enemies:
		if e.hp > 0 and e.revealed != null:
			bs.log_msg("Undead %d: %s (Init %d)" % [e.index + 1, e.revealed.behavior_name, e.revealed.initiative])
	_update_ui()
	await get_tree().create_timer(0.9).timeout

	var hi := bs.hero_initiative()
	var ei := bs.enemy_min_initiative()
	bs.log_msg("Hero init %d  vs  Enemy init %d" % [hi, ei])

	await _show_initiative(hi, ei)

	if hi <= ei:
		bs.current_phase = BattleState.Phase.RESOLVE_HERO
		_update_ui()
		await _resolve_hero()
		if await _check_end(): return
		bs.current_phase = BattleState.Phase.RESOLVE_ENEMY
		_update_ui()
		await _resolve_enemy()
		if await _check_end(): return
	else:
		bs.current_phase = BattleState.Phase.RESOLVE_ENEMY
		_update_ui()
		await _resolve_enemy()
		if await _check_end(): return
		bs.current_phase = BattleState.Phase.RESOLVE_HERO
		_update_ui()
		await _resolve_hero()
		if await _check_end(): return

	_hide_turn_order()

	bs.current_phase = BattleState.Phase.REFRESH
	bs.refresh()
	bs.round_number += 1
	bs.log_msg("=== Round %d ===" % bs.round_number)
	bs.current_phase = BattleState.Phase.SELECT
	ui_locked = false
	_update_ui()

func _check_end() -> bool:
	if bs.all_enemies_dead():
		bs.current_phase = BattleState.Phase.VICTORY
		_update_ui()
		await get_tree().create_timer(0.5).timeout
		_show_end(true)
		return true
	if bs.hero_hp <= 0:
		bs.current_phase = BattleState.Phase.DEFEAT
		_update_ui()
		await get_tree().create_timer(0.5).timeout
		_show_end(false)
		return true
	return false

# ═══════════════════════════════════════════════════════════════════════════
# RESOLUTION
# ═══════════════════════════════════════════════════════════════════════════

func _resolve_hero() -> void:
	var cards := bs.hero_selected.duplicate()
	if cards.is_empty():
		bs.log_msg("Hero passes.")
		await get_tree().create_timer(0.4).timeout
		return
	for idx in range(cards.size()):
		_set_sel_highlight(idx)
		await get_tree().create_timer(0.8).timeout
		var c := cards[idx] as CardData
		bs.log_msg("▶ " + c.card_name)
		_update_ui()
		await get_tree().create_timer(0.25).timeout
		for effect in c.effects:
			await _hero_effect(effect, c)
			_update_ui()
			if bs.all_enemies_dead():
				_clear_sel_highlight()
				return
	_clear_sel_highlight()

func _set_sel_highlight(active_idx: int) -> void:
	for i in range(sel_panels.size()):
		var card: CardData = bs.hero_selected[i] if i < bs.hero_selected.size() else null
		if i == active_idx and card != null:
			sel_panels[i].add_theme_stylebox_override("panel", _flat_style(Color(0.22, 0.75, 0.18), 4, 5))
		else:
			_refresh_card_panel(sel_panels[i], card, card != null)

func _clear_sel_highlight() -> void:
	for i in range(sel_panels.size()):
		var card: CardData = bs.hero_selected[i] if i < bs.hero_selected.size() else null
		_refresh_card_panel(sel_panels[i], card, card != null)

func _hero_effect(fx: Dictionary, card: CardData) -> void:
	match fx["type"]:
		"attack":
			var rng: int = fx.get("range", 1)
			var bonus := 2 if bs.hero_bless else 0
			bs.hero_bless = false
			var target_e := await _choose_attack_target(rng, card)
			if target_e != null:
				var raw: int = fx["value"] + bonus
				var absorbed := mini(target_e.block, raw)
				var hp_before := target_e.hp
				if board_3d:
					if rng <= 1:
						await board_3d.animate_melee_attack(bs.hero_pos, target_e.pos)
					else:
						await board_3d.animate_ranged_attack(bs.hero_pos, target_e.pos)
					if absorbed > 0:
						await board_3d.animate_block(target_e.pos)
					await board_3d.animate_hit(false, target_e.index)
				bs.apply_damage_enemy(target_e, raw)
				var msg := "  %d dmg" % raw
				if bonus > 0: msg += " (+%d Bless)" % bonus
				if absorbed > 0: msg += " — %d blocked" % absorbed
				msg += " = %d HP lost  (Undead %d: %d→%d)" % [raw - absorbed, target_e.index + 1, hp_before, target_e.hp]
				bs.log_msg(msg)
				await get_tree().create_timer(0.15).timeout
			else:
				bs.log_msg("  %s fizzled (no enemy in range %d)" % [card.card_name, rng])
				await get_tree().create_timer(0.25).timeout
		"heal":
			var old_hp := bs.hero_hp
			bs.hero_hp = mini(bs.hero_hp + fx["value"], bs.hero_max_hp)
			bs.log_msg("  Healed %d  (HP %d→%d)" % [fx["value"], old_hp, bs.hero_hp])
			await get_tree().create_timer(0.25).timeout
		"block":
			bs.hero_block += fx["value"]
			bs.log_msg("  Gained Block %d  (→%d)" % [fx["value"], bs.hero_block])
			await get_tree().create_timer(0.25).timeout
		"move":
			await _hero_move(fx["value"])
		"bless":
			bs.hero_bless = true
			bs.log_msg("  Hero gains Bless")
			await get_tree().create_timer(0.25).timeout
		"slow":
			# Slow the nearest enemy
			var target_e: EnemyState = _nearest_living_enemy()
			if target_e != null:
				target_e.slow = true
				bs.log_msg("  Undead %d gains Slow" % (target_e.index + 1))
			await get_tree().create_timer(0.25).timeout

func _enemies_in_range(rng: int) -> Array:
	var targets: Array = []
	for e in bs.enemies:
		if e.hp <= 0: continue
		var d := Pathfinder.manhattan(bs.hero_pos, e.pos)
		if d <= rng:
			targets.append(e)
	targets.sort_custom(func(a: EnemyState, b: EnemyState) -> bool:
		var da := Pathfinder.manhattan(bs.hero_pos, a.pos)
		var db := Pathfinder.manhattan(bs.hero_pos, b.pos)
		if da == db:
			return a.index < b.index
		return da < db
	)
	return targets

func _choose_attack_target(rng: int, card: CardData) -> EnemyState:
	var targets := _enemies_in_range(rng)
	if targets.is_empty():
		return null
	if targets.size() == 1:
		return targets[0]

	_targetable_enemy_indices.clear()
	for e in targets:
		_targetable_enemy_indices.append((e as EnemyState).index)
	_active_target_enemy_idx = -1
	bs.log_msg("  %s: tap an enemy to target, then tap again to attack" % card.card_name)
	_update_ui()

	var chosen_idx: int = await attack_target_chosen
	for e in targets:
		var enemy := e as EnemyState
		if enemy.index == chosen_idx and enemy.hp > 0:
			_clear_attack_targeting()
			_update_ui()
			return enemy

	_clear_attack_targeting()
	_update_ui()
	return null

func _nearest_living_enemy() -> EnemyState:
	var best: EnemyState = null
	var best_d := 999
	for e in bs.enemies:
		if e.hp <= 0: continue
		var d := Pathfinder.manhattan(bs.hero_pos, e.pos)
		if d < best_d:
			best_d = d
			best = e
	return best

func _hero_move(budget: int) -> void:
	var enemy_positions: Array = []
	for e in bs.enemies:
		if e.hp > 0: enemy_positions.append(e.pos)
	var reachable := Pathfinder.get_reachable(bs.hero_pos, budget, enemy_positions)
	if reachable.is_empty():
		bs.log_msg("  Move fizzled: no reachable tiles")
		return
	highlighted_tiles = reachable
	_update_board()
	bs.log_msg("  Choose move destination…")
	var dest: Vector2i = await move_dest_chosen
	highlighted_tiles.clear()
	_update_board()
	var path := Pathfinder.find_path(bs.hero_pos, dest, enemy_positions)
	for step in path:
		bs.hero_pos = step
		if board_3d:
			await board_3d.animate_step(true, step)
		_update_ui()
	bs.log_msg("  Hero → %s" % str(dest))

func _resolve_enemy() -> void:
	for e in bs.enemies:
		if e.hp <= 0: continue
		if e.revealed == null: continue
		bs.log_msg("◀ Undead %d: %s" % [e.index + 1, e.revealed.behavior_name])
		_update_ui()
		await get_tree().create_timer(0.3).timeout
		for effect in e.revealed.effects:
			await _enemy_effect(effect, e)
			_update_ui()
			if bs.hero_hp <= 0: return
		if e.slow:
			e.slow = false
			bs.log_msg("  Slow fades (Undead %d)" % (e.index + 1))
			_update_ui()

func _enemy_effect(fx: Dictionary, e: EnemyState) -> void:
	match fx["type"]:
		"block":
			e.block += fx["value"]
			bs.log_msg("  Undead %d gains Block %d  (→%d)" % [e.index + 1, fx["value"], e.block])
			await get_tree().create_timer(0.25).timeout
		"move_toward":
			var steps: int = fx["value"]
			if e.slow:
				steps = maxi(steps - 1, 0)
				bs.log_msg("  Slow: Undead %d move → %d" % [e.index + 1, steps])
			await _enemy_move(e, steps)
		"attack_if_adj":
			var dist := Pathfinder.manhattan(e.pos, bs.hero_pos)
			if dist <= 1:
				var raw: int = fx["value"]
				var absorbed := mini(bs.hero_block, raw)
				var hp_before := bs.hero_hp
				if board_3d:
					await board_3d.animate_melee_attack(e.pos, bs.hero_pos)
					if absorbed > 0:
						await board_3d.animate_block(bs.hero_pos)
					await board_3d.animate_hit(true)
				bs.apply_damage_hero(raw)
				await _flash_red_screen()
				var msg := "  Undead %d strikes %d dmg" % [e.index + 1, raw]
				if absorbed > 0: msg += " — %d blocked" % absorbed
				msg += " = %d HP lost  (Hero: %d→%d)" % [raw - absorbed, hp_before, bs.hero_hp]
				bs.log_msg(msg)
				await get_tree().create_timer(0.15).timeout
			else:
				bs.log_msg("  Undead %d not adjacent" % (e.index + 1))
				await get_tree().create_timer(0.2).timeout
		"lunge":
			var dist := Pathfinder.manhattan(e.pos, bs.hero_pos)
			if dist <= 1:
				var raw: int = fx["attack_value"]
				var absorbed := mini(bs.hero_block, raw)
				var hp_before := bs.hero_hp
				if board_3d:
					await board_3d.animate_melee_attack(e.pos, bs.hero_pos)
					if absorbed > 0:
						await board_3d.animate_block(bs.hero_pos)
					await board_3d.animate_hit(true)
				bs.apply_damage_hero(raw)
				await _flash_red_screen()
				var msg := "  Undead %d lunges %d dmg" % [e.index + 1, raw]
				if absorbed > 0: msg += " — %d blocked" % absorbed
				msg += " = %d HP lost  (Hero: %d→%d)" % [raw - absorbed, hp_before, bs.hero_hp]
				bs.log_msg(msg)
				await get_tree().create_timer(0.15).timeout
			else:
				var steps: int = fx["move_value"]
				if e.slow:
					steps = maxi(steps - 1, 0)
				await _enemy_move(e, steps)

func _enemy_move(e: EnemyState, steps: int) -> void:
	for _i in range(steps):
		var blocked: Array = [bs.hero_pos]
		for other in bs.enemies:
			if other != e and other.hp > 0:
				blocked.append(other.pos)
		var next := _best_step(e.pos, bs.hero_pos, blocked)
		if next == Vector2i(-1, -1): break
		e.pos = next
		if board_3d:
			await board_3d.animate_step(false, next, e.index)
		bs.log_msg("  Undead %d → %s" % [e.index + 1, str(e.pos)])
		_update_ui()

func _best_step(from: Vector2i, toward: Vector2i, blocked: Array) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := Pathfinder.manhattan(from, toward)
	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var n: Vector2i = from + d
		if n.x < 0 or n.x >= 5 or n.y < 0 or n.y >= 5: continue
		if blocked.has(n): continue
		var dist := Pathfinder.manhattan(n, toward)
		if dist < best_dist:
			best_dist = dist
			best = n
	return best

# ═══════════════════════════════════════════════════════════════════════════
# INPUT HANDLERS
# ═══════════════════════════════════════════════════════════════════════════

func _on_tile_pressed(pos: Vector2i) -> void:
	if highlighted_tiles.has(pos):
		move_dest_chosen.emit(pos)

func _on_board_enemy_pressed(enemy_idx: int) -> void:
	_try_choose_attack_target(enemy_idx)

func _on_enemy_panel_input(event: InputEvent, enemy_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and
			event.button_index == MOUSE_BUTTON_LEFT):
		return
	_try_choose_attack_target(enemy_idx)

func _on_hand_card_input(event: InputEvent, slot: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and
			event.button_index == MOUSE_BUTTON_LEFT):
		return
	if ui_locked or bs.current_phase != BattleState.Phase.SELECT:
		return
	_try_select_hand(slot)

func _try_select_hand(slot: int) -> void:
	if slot >= bs.hero_hand.size():
		return
	var card := bs.hero_hand[slot] as CardData
	if not bs.can_select(card):
		_flash_reject(hand_panels[slot])
		return
	bs.select_card(card)
	_update_ui()
	_pulse_stamina(true)

func _on_sel_card_input(event: InputEvent, slot: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and
			event.button_index == MOUSE_BUTTON_LEFT):
		return
	if ui_locked or bs.current_phase != BattleState.Phase.SELECT:
		return
	if slot < bs.hero_selected.size():
		bs.deselect_card(bs.hero_selected[slot] as CardData)
		_update_ui()
		_pulse_stamina(false)

# ═══════════════════════════════════════════════════════════════════════════
# END GAME
# ═══════════════════════════════════════════════════════════════════════════

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
	return_to_title.emit()

# ═══════════════════════════════════════════════════════════════════════════
# VISUAL HELPERS
# ═══════════════════════════════════════════════════════════════════════════

func _flash_red_screen() -> void:
	if _screen_flash == null:
		return
	var tw := create_tween()
	tw.tween_property(_screen_flash, "color:a", 0.45, 0.06)
	tw.tween_property(_screen_flash, "color:a", 0.0,  0.30)
	await tw.finished

func _flash_tile(pos: Vector2i, color: Color) -> void:
	if board_3d:
		board_3d.flash_tile(pos, color)
	await get_tree().create_timer(0.28).timeout
	_update_board()

func _flash_reject(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _flat_style(Color(0.6, 0.1, 0.1)))
	await get_tree().create_timer(0.22).timeout
	_update_ui()

func _pulse_stamina(spent: bool) -> void:
	if stamina_lbl == null:
		return
	if _stamina_pulse_tween != null:
		_stamina_pulse_tween.kill()
	_set_stamina_visual(STAMINA_BASE_FONT_SIZE, STAMINA_BASE_COLOR)

	var accent := STAMINA_SPEND_COLOR if spent else STAMINA_REFUND_COLOR
	var pulse_up := func(t: float) -> void:
		var size := int(round(lerpf(float(STAMINA_BASE_FONT_SIZE), float(STAMINA_PULSE_FONT_SIZE), t)))
		_set_stamina_visual(size, STAMINA_BASE_COLOR.lerp(accent, t))
	var pulse_down := func(t: float) -> void:
		var size := int(round(lerpf(float(STAMINA_PULSE_FONT_SIZE), float(STAMINA_BASE_FONT_SIZE), t)))
		_set_stamina_visual(size, accent.lerp(STAMINA_BASE_COLOR, t))

	_stamina_pulse_tween = create_tween()
	_stamina_pulse_tween.set_ease(Tween.EASE_OUT)
	_stamina_pulse_tween.set_trans(Tween.TRANS_BACK)
	_stamina_pulse_tween.tween_method(pulse_up, 0.0, 1.0, 0.13)

	var settle := _stamina_pulse_tween.chain()
	settle.set_ease(Tween.EASE_IN_OUT)
	settle.set_trans(Tween.TRANS_CUBIC)
	settle.tween_method(pulse_down, 0.0, 1.0, 0.20)

func _set_stamina_visual(font_size: int, color: Color) -> void:
	stamina_lbl.add_theme_font_size_override("font_size", font_size)
	stamina_lbl.add_theme_color_override("font_color", color)

func _pulse_hero_area_label(label: Label, base_color: Color, accent: Color) -> void:
	if label == null:
		return
	if _hero_area_pulse_tweens.has(label):
		var running: Tween = _hero_area_pulse_tweens[label]
		if running != null:
			running.kill()

	_set_hero_area_label_visual(label, base_color, HERO_AREA_BASE_SCALE)

	var pulse_up := func(t: float) -> void:
		_set_hero_area_label_visual(
			label,
			base_color.lerp(accent, t),
			HERO_AREA_BASE_SCALE.lerp(HERO_AREA_PULSE_SCALE, t)
		)
	var pulse_down := func(t: float) -> void:
		_set_hero_area_label_visual(
			label,
			accent.lerp(base_color, t),
			HERO_AREA_PULSE_SCALE.lerp(HERO_AREA_BASE_SCALE, t)
		)

	var tw := create_tween()
	_hero_area_pulse_tweens[label] = tw
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_method(pulse_up, 0.0, 1.0, 0.13)

	var settle := tw.chain()
	settle.set_ease(Tween.EASE_IN_OUT)
	settle.set_trans(Tween.TRANS_CUBIC)
	settle.tween_method(pulse_down, 0.0, 1.0, 0.20)
	tw.finished.connect(func() -> void:
		_set_hero_area_label_visual(label, base_color, HERO_AREA_BASE_SCALE)
		_hero_area_pulse_tweens.erase(label)
	)

func _set_hero_area_label_visual(label: Label, color: Color, scale_value: Vector2) -> void:
	label.add_theme_color_override("font_color", color)
	label.pivot_offset = label.size * 0.5
	label.scale = scale_value

func _try_choose_attack_target(enemy_idx: int) -> void:
	if not _targetable_enemy_indices.has(enemy_idx):
		return
	if _active_target_enemy_idx != enemy_idx:
		_active_target_enemy_idx = enemy_idx
		bs.log_msg("  Undead %d targeted — tap again to attack" % (enemy_idx + 1))
		_update_ui()
		return
	_active_target_enemy_idx = enemy_idx
	_update_ui()
	attack_target_chosen.emit(enemy_idx)

func _clear_attack_targeting() -> void:
	_targetable_enemy_indices.clear()
	_active_target_enemy_idx = -1
	for i in range(_enemy_panels.size()):
		_stop_enemy_panel_target_pulse(i)
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
	panel.add_theme_stylebox_override("panel", _flat_style(color, 4, 5))

func _start_enemy_panel_target_pulse(enemy_idx: int) -> void:
	var panel: PanelContainer = _enemy_panels[enemy_idx]
	if panel == null:
		return
	if _enemy_panel_target_tweens.has(enemy_idx):
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
	if enemy_idx < _enemy_panels.size() and _enemy_panels[enemy_idx] != null:
		_enemy_panels[enemy_idx].scale = Vector2.ONE

# ═══════════════════════════════════════════════════════════════════════════
# STYLE / WIDGET FACTORIES
# ═══════════════════════════════════════════════════════════════════════════

func _make_card_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(148, 96)
	p.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	p.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	var badge := HBoxContainer.new()
	vbox.add_child(badge)

	var cost_lbl := Label.new()
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25))
	badge.add_child(cost_lbl)

	var init_lbl := Label.new()
	init_lbl.add_theme_font_size_override("font_size", 12)
	init_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.95))
	badge.add_child(init_lbl)

	var fx_lbl := Label.new()
	fx_lbl.add_theme_font_size_override("font_size", 11)
	fx_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	fx_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(fx_lbl)

	p.set_meta("name_lbl", name_lbl)
	p.set_meta("cost_lbl", cost_lbl)
	p.set_meta("init_lbl", init_lbl)
	p.set_meta("fx_lbl", fx_lbl)

	_refresh_card_panel(p, null, false)
	return p

func _refresh_card_panel(p: PanelContainer, card: CardData, selected: bool) -> void:
	var bg: Color
	if card == null:
		bg = Color(0.10, 0.10, 0.14)
	elif selected:
		bg = Color(0.18, 0.30, 0.50)
	else:
		bg = Color(0.14, 0.14, 0.21)
	p.add_theme_stylebox_override("panel", _flat_style(bg, 4, 5))

	var nl: Label = p.get_meta("name_lbl")
	var cl: Label = p.get_meta("cost_lbl")
	var il: Label = p.get_meta("init_lbl")
	var fl: Label = p.get_meta("fx_lbl")

	if card:
		nl.text = card.card_name
		cl.text = "C:%d " % card.cost
		il.text = "I:%d" % card.initiative
		fl.text = card.effect_text
	else:
		nl.text = "─ empty ─"
		cl.text = ""
		il.text = ""
		fl.text = ""

func _panel(color: Color, min_w: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(min_w, 0)
	p.add_theme_stylebox_override("panel", _flat_style(color, 5, 6))
	return p

func _flat_style(color: Color, radius: int = 4, margin: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin - 2
	s.content_margin_bottom = margin - 2
	return s

func _style_btn(btn: Button, color: Color) -> void:
	btn.add_theme_stylebox_override("normal", _flat_style(color, 5))
	btn.add_theme_stylebox_override("hover", _flat_style(color.lightened(0.15), 5))
	btn.add_theme_stylebox_override("pressed", _flat_style(color.darkened(0.15), 5))
	btn.add_theme_color_override("font_color", Color.WHITE)

func _lbl(text: String, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15 if bold else 14)
	if bold:
		l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	return l

func _expand_spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

func _fixed_spacer(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 0)
	return c

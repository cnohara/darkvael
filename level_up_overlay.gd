extends Control

signal level_up_confirmed(option: int, chosen_card_names: Array)

const OPTION_A := 0
const OPTION_B := 1
const OPTION_C := 2

var _player = null
var _new_level: int = 1
var _selected_option: int = -1
var _required_cards: int = 2
var _chosen_card_indices: Array = []
var _class_cards: Array = []

var _title_lbl: Label
var _option_btns: Array = []
var _option_desc_lbls: Array = []
var _card_step_container: Control
var _card_grid: GridContainer
var _card_panels: Array = []
var _card_count_lbl: Label
var _continue_btn: Button
var _confirm_btn: Button
var _step1_container: Control
var _step2_container: Control

func setup(player, new_level: int) -> void:
	_player = player
	_new_level = new_level
	_selected_option = -1
	_chosen_card_indices.clear()
	_class_cards = CardData.get_class_cards_for_level(player.hero_type, new_level)
	_build_ui()
	_show_step1()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(680, 0)
	outer.add_theme_stylebox_override("panel", _flat_style(Color(0.09, 0.09, 0.14), 10, 16))
	center.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	outer.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", UITheme.font_size(26))
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_lbl)

	_step1_container = VBoxContainer.new()
	_step1_container.add_theme_constant_override("separation", 10)
	vbox.add_child(_step1_container)
	_build_step1(_step1_container)

	_step2_container = VBoxContainer.new()
	_step2_container.add_theme_constant_override("separation", 10)
	_step2_container.visible = false
	vbox.add_child(_step2_container)
	_build_step2(_step2_container)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue →"
	_continue_btn.custom_minimum_size = Vector2(180, 44)
	_style_btn(_continue_btn, Color(0.18, 0.42, 0.22))
	_continue_btn.disabled = true
	_continue_btn.pressed.connect(_on_continue_pressed)
	btn_row.add_child(_continue_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirm Level Up"
	_confirm_btn.custom_minimum_size = Vector2(200, 44)
	_style_btn(_confirm_btn, Color(0.26, 0.18, 0.52))
	_confirm_btn.disabled = true
	_confirm_btn.visible = false
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(_confirm_btn)

func _build_step1(parent: Control) -> void:
	var sub_lbl := Label.new()
	sub_lbl.text = "Choose a level-up benefit:"
	sub_lbl.add_theme_font_size_override("font_size", UITheme.font_size(20))
	sub_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.88))
	parent.add_child(sub_lbl)

	var opts_row := HBoxContainer.new()
	opts_row.add_theme_constant_override("separation", 10)
	parent.add_child(opts_row)

	var option_data := [
		["Option A", "+1 Max HP\n+\nChoose 2 class cards"],
		["Option B", "+1 Max Stamina\n+\nChoose 2 class cards"],
		["Option C", "Choose 3 class cards"],
	]
	_option_btns.clear()
	for i in range(3):
		var op_panel := PanelContainer.new()
		op_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		op_panel.add_theme_stylebox_override("panel", _flat_style(Color(0.13, 0.13, 0.22), 8, 10))
		op_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		op_panel.gui_input.connect(_on_option_clicked.bind(i))
		opts_row.add_child(op_panel)

		var op_vbox := VBoxContainer.new()
		op_vbox.add_theme_constant_override("separation", 6)
		op_panel.add_child(op_vbox)

		var op_title := Label.new()
		op_title.text = option_data[i][0]
		op_title.add_theme_font_size_override("font_size", UITheme.font_size(20))
		op_title.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))
		op_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		op_vbox.add_child(op_title)

		var op_desc := Label.new()
		op_desc.text = option_data[i][1]
		op_desc.add_theme_font_size_override("font_size", UITheme.font_size(18))
		op_desc.add_theme_color_override("font_color", Color(0.72, 0.78, 0.90))
		op_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		op_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		op_vbox.add_child(op_desc)

		_option_btns.append(op_panel)

func _build_step2(parent: Control) -> void:
	_card_count_lbl = Label.new()
	_card_count_lbl.add_theme_font_size_override("font_size", UITheme.font_size(20))
	_card_count_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.34))
	parent.add_child(_card_count_lbl)

	_card_grid = GridContainer.new()
	_card_grid.columns = 3
	_card_grid.add_theme_constant_override("h_separation", 8)
	_card_grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(_card_grid)

func _show_step1() -> void:
	if _player == null:
		return
	_title_lbl.text = "%s leveled up to Level %d!" % [_player.name, _new_level]
	_step1_container.visible = true
	_step2_container.visible = false
	_continue_btn.visible = true
	_confirm_btn.visible = false
	_continue_btn.disabled = true
	_selected_option = -1
	_refresh_option_styles()

func _show_step2() -> void:
	_required_cards = 3 if _selected_option == OPTION_C else 2
	_chosen_card_indices.clear()
	_step1_container.visible = false
	_step2_container.visible = true
	_continue_btn.visible = false
	_confirm_btn.visible = true
	_confirm_btn.disabled = true

	for child in _card_grid.get_children():
		child.queue_free()
	_card_panels.clear()

	for i in range(_class_cards.size()):
		var card: CardData = _class_cards[i] as CardData
		var cp := _make_class_card_panel(card, i)
		_card_grid.add_child(cp)
		_card_panels.append(cp)

	_refresh_card_count_lbl()

func _on_option_clicked(event: InputEvent, option_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_selected_option = option_idx
	_continue_btn.disabled = false
	_refresh_option_styles()

func _refresh_option_styles() -> void:
	for i in range(_option_btns.size()):
		var panel: PanelContainer = _option_btns[i]
		var selected := i == _selected_option
		panel.add_theme_stylebox_override("panel",
			_flat_style(Color(0.22, 0.34, 0.58) if selected else Color(0.13, 0.13, 0.22), 8, 10))

func _make_class_card_panel(card: CardData, idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(192, 110)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _flat_style(Color(0.14, 0.14, 0.21), 6, 8))
	panel.gui_input.connect(_on_card_clicked.bind(idx))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", UITheme.font_size(17))
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	vbox.add_child(name_lbl)

	var meta_lbl := Label.new()
	meta_lbl.text = "Cost: %d  Init: %d" % [card.cost, card.initiative]
	meta_lbl.add_theme_font_size_override("font_size", UITheme.font_size(14))
	meta_lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.42))
	vbox.add_child(meta_lbl)

	var fx_lbl := Label.new()
	fx_lbl.text = card.effect_text
	fx_lbl.add_theme_font_size_override("font_size", UITheme.font_size(14))
	fx_lbl.add_theme_color_override("font_color", Color(0.74, 0.74, 0.82))
	fx_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(fx_lbl)

	return panel

func _on_card_clicked(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _chosen_card_indices.has(idx):
		_chosen_card_indices.erase(idx)
	else:
		if _chosen_card_indices.size() < _required_cards:
			_chosen_card_indices.append(idx)
	_refresh_card_selections()
	_refresh_card_count_lbl()
	_confirm_btn.disabled = _chosen_card_indices.size() != _required_cards

func _refresh_card_selections() -> void:
	for i in range(_card_panels.size()):
		var panel: PanelContainer = _card_panels[i]
		var selected := _chosen_card_indices.has(i)
		panel.add_theme_stylebox_override("panel",
			_flat_style(Color(0.22, 0.34, 0.58) if selected else Color(0.14, 0.14, 0.21), 6, 8))

func _refresh_card_count_lbl() -> void:
	_card_count_lbl.text = "Selected %d / %d" % [_chosen_card_indices.size(), _required_cards]

func _on_continue_pressed() -> void:
	if _selected_option < 0:
		return
	_show_step2()

func _on_confirm_pressed() -> void:
	if _chosen_card_indices.size() != _required_cards:
		return
	var chosen_names: Array = []
	for idx in _chosen_card_indices:
		var card: CardData = _class_cards[idx] as CardData
		chosen_names.append(card.card_name)
	level_up_confirmed.emit(_selected_option, chosen_names)

func _flat_style(color: Color, radius: int = 6, margin: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin - 2
	style.content_margin_bottom = margin - 2
	return style

func _style_btn(btn: Button, color: Color) -> void:
	btn.add_theme_stylebox_override("normal", _flat_style(color, 5, 8))
	btn.add_theme_stylebox_override("hover", _flat_style(color.lightened(0.14), 5, 8))
	btn.add_theme_stylebox_override("pressed", _flat_style(color.darkened(0.12), 5, 8))
	btn.add_theme_font_size_override("font_size", UITheme.font_size(18))
	btn.add_theme_color_override("font_color", Color.WHITE)

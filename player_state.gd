class_name PlayerState
extends RefCounted

const BASE_MAX_HP := 12
const BASE_MAX_STAMINA := 3
const MAX_SELECTED := 3
const STUNNED_MAX_SELECTED := 1
const HAND_SIZE := 5

const XP_THRESHOLDS := [0, 2, 5, 9, 14]

var seat_index: int = 0
var name: String = ""
var hero_type: String = "Cleric"
var level: int = 1
var xp: int = 0
var hp: int = BASE_MAX_HP
var max_hp: int = BASE_MAX_HP
var max_stamina: int = BASE_MAX_STAMINA
var block: int = 0
var pos: Vector2i = Vector2i.ZERO
var draw_pile: Array = []
var hand: Array = []
var selected: Array = []
var discard_pile: Array = []
var ready: bool = false
var alive: bool = true

var bless: bool = false
var poison: bool = false
var stun: bool = false
var entangle: bool = false
var hidden: bool = false
var confused: bool = false
var burn: int = 0

func setup_for_battle(p_seat_index: int, spawn_pos: Vector2i) -> void:
	seat_index = p_seat_index
	name = "Player %d" % (seat_index + 1)
	hero_type = "Cleric"
	level = 1
	xp = 0
	hp = max_hp
	max_hp = BASE_MAX_HP
	max_stamina = BASE_MAX_STAMINA
	block = 0
	_clear_conditions()
	bless = false
	pos = spawn_pos
	draw_pile = CardData.create_hero_deck(hero_type)
	draw_pile.shuffle()
	hand.clear()
	selected.clear()
	discard_pile.clear()
	ready = false
	alive = true

func draw_to_hand() -> void:
	while hand.size() < HAND_SIZE:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		hand.append(draw_pile.pop_front())

func selected_stamina() -> int:
	var total := 0
	for card in selected:
		total += card.cost
	return total

func initiative() -> int:
	if selected.is_empty():
		return 99
	return (selected[0] as CardData).initiative

func can_select(card: CardData) -> bool:
	if not alive or ready:
		return false
	if selected.size() >= selection_limit():
		return false
	if selected_stamina() + card.cost > max_stamina:
		return false
	return true

func selection_limit() -> int:
	return STUNNED_MAX_SELECTED if stun else MAX_SELECTED

func select_card_by_hand_index(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card := hand[hand_index] as CardData
	if not can_select(card):
		return false
	hand.remove_at(hand_index)
	selected.append(card)
	return true

func deselect_selected_index(selected_index: int) -> bool:
	if ready:
		return false
	if selected_index < 0 or selected_index >= selected.size():
		return false
	var card: CardData = selected[selected_index] as CardData
	selected.remove_at(selected_index)
	if CardData.is_rotate_card(card):
		var original := CardData.from_name(card.rotated_from_name)
		if original != null:
			hand.append(original)
	else:
		hand.append(card)
	return true

func reorder_selected(selected_index: int, direction: int) -> bool:
	if ready:
		return false
	var target := selected_index + direction
	if selected_index < 0 or selected_index >= selected.size():
		return false
	if target < 0 or target >= selected.size():
		return false
	var tmp: CardData = selected[selected_index] as CardData
	selected[selected_index] = selected[target]
	selected[target] = tmp
	return true

func end_round_cleanup() -> void:
	block = 0
	for card in selected:
		var c: CardData = card as CardData
		if CardData.is_rotate_card(c):
			var original := CardData.from_name(c.rotated_from_name)
			if original != null:
				discard_pile.append(original)
		else:
			discard_pile.append(card)
	selected.clear()
	ready = false
	entangle = false
	confused = false
	hidden = false
	draw_to_hand()

func has_any_condition() -> bool:
	return poison or stun or entangle or hidden or confused or burn > 0

func _clear_conditions() -> void:
	poison = false
	stun = false
	entangle = false
	hidden = false
	confused = false
	burn = 0

func apply_damage(amount: int, attack_type: String = "physical", ignore_block: bool = false) -> int:
	var remaining := amount
	if not ignore_block:
		var absorbed := mini(block, remaining)
		block -= absorbed
		remaining -= absorbed
	hp = maxi(hp - remaining, 0)
	alive = hp > 0
	return remaining

func apply_poison_damage() -> int:
	hp = maxi(hp - 1, 0)
	alive = hp > 0
	return 1

func apply_burn_damage() -> int:
	var dmg := burn
	hp = maxi(hp - dmg, 0)
	alive = hp > 0
	burn = maxi(burn - 1, 0)
	return dmg

func apply_heal(amount: int) -> String:
	if has_any_condition():
		var cond_list := condition_list()
		_clear_conditions()
		return "conditions cleared (%s), no HP healed" % cond_list
	var old_hp := hp
	hp = mini(hp + amount, max_hp)
	alive = hp > 0
	return "HP %d→%d" % [old_hp, hp]

func xp_for_next_level() -> int:
	if level >= XP_THRESHOLDS.size():
		return 9999
	return XP_THRESHOLDS[level]

func can_level_up() -> bool:
	return level < XP_THRESHOLDS.size() and xp >= xp_for_next_level()

func condition_list() -> String:
	var parts: Array[String] = []
	if poison:
		parts.append("Poison")
	if stun:
		parts.append("Stun")
	if entangle:
		parts.append("Entangle")
	if hidden:
		parts.append("Hidden")
	if confused:
		parts.append("Confused")
	if burn > 0:
		parts.append("Burn(%d)" % burn)
	return ", ".join(parts)

func status_text() -> String:
	var parts: Array[String] = []
	if bless:
		parts.append("Bless")
	if poison:
		parts.append("Poison")
	if stun:
		parts.append("Stun")
	if entangle:
		parts.append("Entangle")
	if hidden:
		parts.append("Hidden")
	if confused:
		parts.append("Confused")
	if burn > 0:
		parts.append("Burn(%d)" % burn)
	if not alive:
		parts.append("Dead")
	return "" if parts.is_empty() else "[" + ", ".join(parts) + "]"

func to_dict() -> Dictionary:
	return {
		"seat_index": seat_index,
		"name": name,
		"hero_type": hero_type,
		"level": level,
		"xp": xp,
		"hp": hp,
		"max_hp": max_hp,
		"max_stamina": max_stamina,
		"block": block,
		"pos": [pos.x, pos.y],
		"draw_pile": _cards_to_names(draw_pile),
		"hand": _cards_to_names(hand),
		"selected": _cards_to_names(selected),
		"discard_pile": _cards_to_names(discard_pile),
		"ready": ready,
		"alive": alive,
		"bless": bless,
		"poison": poison,
		"stun": stun,
		"entangle": entangle,
		"hidden": hidden,
		"confused": confused,
		"burn": burn,
	}

func load_from_dict(data: Dictionary) -> void:
	seat_index = int(data.get("seat_index", seat_index))
	name = String(data.get("name", name))
	hero_type = String(data.get("hero_type", hero_type))
	level = int(data.get("level", level))
	xp = int(data.get("xp", xp))
	hp = int(data.get("hp", hp))
	max_hp = int(data.get("max_hp", max_hp))
	max_stamina = int(data.get("max_stamina", max_stamina))
	block = int(data.get("block", block))
	var pos_arr: Array = data.get("pos", [pos.x, pos.y])
	pos = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
	draw_pile = _names_to_cards(data.get("draw_pile", []))
	hand = _names_to_cards(data.get("hand", []))
	selected = _names_to_cards(data.get("selected", []))
	discard_pile = _names_to_cards(data.get("discard_pile", []))
	ready = bool(data.get("ready", ready))
	alive = bool(data.get("alive", alive))
	bless = bool(data.get("bless", bless))
	poison = bool(data.get("poison", poison))
	stun = bool(data.get("stun", stun))
	entangle = bool(data.get("entangle", entangle))
	hidden = bool(data.get("hidden", hidden))
	confused = bool(data.get("confused", confused))
	burn = int(data.get("burn", burn))

func _cards_to_names(cards: Array) -> Array:
	var names: Array = []
	for card in cards:
		var typed_card: CardData = card as CardData
		names.append(CardData.encoded_name(typed_card))
	return names

func _names_to_cards(names: Array) -> Array:
	var cards: Array = []
	for card_name in names:
		var card := CardData.from_name(String(card_name))
		if card != null:
			cards.append(card)
	return cards

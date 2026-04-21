class_name PlayerState
extends RefCounted

const MAX_HP := 12
const MAX_SELECTED := 3
const STAMINA_CAP := 3
const HAND_SIZE := 5

var seat_index: int = 0
var name: String = ""
var hero_type: String = "Cleric"
var hp: int = MAX_HP
var max_hp: int = MAX_HP
var block: int = 0
var bless: bool = false
var pos: Vector2i = Vector2i.ZERO
var draw_pile: Array = []
var hand: Array = []
var selected: Array = []
var discard_pile: Array = []
var ready: bool = false
var alive: bool = true

func setup_for_battle(p_seat_index: int, spawn_pos: Vector2i) -> void:
	seat_index = p_seat_index
	name = "Player %d" % (seat_index + 1)
	hero_type = "Cleric"
	hp = MAX_HP
	max_hp = MAX_HP
	block = 0
	bless = false
	pos = spawn_pos
	draw_pile = CardData.create_hero_deck()
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
	if selected.size() >= MAX_SELECTED:
		return false
	if selected_stamina() + card.cost > STAMINA_CAP:
		return false
	return true

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
		discard_pile.append(card)
	selected.clear()
	ready = false
	draw_to_hand()

func apply_damage(amount: int) -> int:
	var absorbed := mini(block, amount)
	block -= absorbed
	var actual := amount - absorbed
	hp = maxi(hp - actual, 0)
	alive = hp > 0
	return actual

func status_text() -> String:
	var parts: Array[String] = []
	if bless:
		parts.append("Bless")
	if not alive:
		parts.append("Dead")
	return "" if parts.is_empty() else "[" + ", ".join(parts) + "]"

func to_dict() -> Dictionary:
	return {
		"seat_index": seat_index,
		"name": name,
		"hero_type": hero_type,
		"hp": hp,
		"max_hp": max_hp,
		"block": block,
		"bless": bless,
		"pos": [pos.x, pos.y],
		"draw_pile": _cards_to_names(draw_pile),
		"hand": _cards_to_names(hand),
		"selected": _cards_to_names(selected),
		"discard_pile": _cards_to_names(discard_pile),
		"ready": ready,
		"alive": alive,
	}

func load_from_dict(data: Dictionary) -> void:
	seat_index = int(data.get("seat_index", seat_index))
	name = String(data.get("name", name))
	hero_type = String(data.get("hero_type", hero_type))
	hp = int(data.get("hp", hp))
	max_hp = int(data.get("max_hp", max_hp))
	block = int(data.get("block", block))
	bless = bool(data.get("bless", bless))
	var pos_arr: Array = data.get("pos", [pos.x, pos.y])
	pos = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
	draw_pile = _names_to_cards(data.get("draw_pile", []))
	hand = _names_to_cards(data.get("hand", []))
	selected = _names_to_cards(data.get("selected", []))
	discard_pile = _names_to_cards(data.get("discard_pile", []))
	ready = bool(data.get("ready", ready))
	alive = bool(data.get("alive", alive))

func _cards_to_names(cards: Array) -> Array:
	var names: Array = []
	for card in cards:
		var typed_card: CardData = card as CardData
		names.append(typed_card.card_name)
	return names

func _names_to_cards(names: Array) -> Array:
	var cards: Array = []
	for card_name in names:
		var card := CardData.from_name(String(card_name))
		if card != null:
			cards.append(card)
	return cards

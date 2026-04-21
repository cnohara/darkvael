class_name CardData
extends Resource

var card_name: String = ""
var cost: int = 1
var initiative: int = 5
var effect_text: String = ""
var effects: Array = []
var rotated_from_name: String = ""

static func _make(p_name: String, p_cost: int, p_init: int, p_text: String, p_fx: Array) -> CardData:
	var c := CardData.new()
	c.card_name = p_name
	c.cost = p_cost
	c.initiative = p_init
	c.effect_text = p_text
	c.effects = p_fx
	return c

static func create_base_deck() -> Array:
	return [
		_make("Sidestep Strike", 2, 5, "Attack 3, Move 3",
			[{"type": "attack", "value": 3, "range": 1, "attack_type": "physical"},
			 {"type": "move", "value": 3}]),
		_make("Shielded Shift", 2, 5, "Jump 3, Block 3",
			[{"type": "jump", "value": 3},
			 {"type": "block", "value": 3}]),
		_make("Crushing Strike", 1, 5, "Attack 4",
			[{"type": "attack", "value": 4, "range": 1, "attack_type": "physical"}]),
		_make("Mend", 2, 5, "Heal 3 self/ally Rng3",
			[{"type": "heal", "value": 3, "range": 3, "target": "self_or_ally"}]),
		_make("Flurry", 2, 4, "Attack 2, all adjacent enemies",
			[{"type": "attack", "value": 2, "range": 1, "attack_type": "physical", "aoe_adjacent": true}]),
		_make("Shielded Advance", 2, 5, "Move 4, Block 3",
			[{"type": "move", "value": 4},
			 {"type": "block", "value": 3}]),
		_make("Dash Strike", 2, 5, "Move 4, Attack 3",
			[{"type": "move", "value": 4},
			 {"type": "attack", "value": 3, "range": 1, "attack_type": "physical"}]),
		_make("Fortify", 1, 5, "Block 4",
			[{"type": "block", "value": 4}]),
		_make("Evade", 1, 3, "Move 3",
			[{"type": "move", "value": 3}]),
		_make("Rejuvenate", 1, 6, "Heal 4 self",
			[{"type": "heal", "value": 4, "target": "self"}]),
	]

static func create_class_deck(hero_type: String, level: int) -> Array:
	match hero_type:
		"Cleric":
			return _cleric_cards(level)
	return []

static func _cleric_cards(level: int) -> Array:
	match level:
		1:
			return [
				_make("Healing Light", 1, 4, "Heal 3+Bless self/ally Rng4",
					[{"type": "heal", "value": 3, "range": 4, "target": "self_or_ally", "also_bless": true}]),
				_make("Divine Smite", 2, 7, "Magic Atk 3, Rng3, Slow",
					[{"type": "attack", "value": 3, "range": 3, "attack_type": "magic", "apply_condition": "slow"}]),
				_make("Sacred Barrier", 1, 4, "Block 2 self+adj allies",
					[{"type": "block", "value": 2, "target": "self_and_adjacent_allies"}]),
				_make("Quiet Petition", 1, 5, "Heal 2 self/ally Rng3; Bless if no conditions",
					[{"type": "heal", "value": 2, "range": 3, "target": "self_or_ally", "bless_if_no_conditions": true}]),
				_make("Votive Step", 1, 6, "Move 3; adj ally gains Block 2, Move 1",
					[{"type": "move", "value": 3},
					 {"type": "votive_step_bonus"}]),
				_make("Guiding Chant", 1, 4, "Block 2 self/ally Rng3; ally Move 1",
					[{"type": "guiding_chant", "value": 2, "range": 3}]),
			]
	return []

static func get_class_cards_for_level(hero_type: String, level: int) -> Array:
	return create_class_deck(hero_type, level)

static func create_hero_deck(hero_type: String = "Cleric") -> Array:
	var deck := create_base_deck()
	deck.append_array(create_class_deck(hero_type, 1))
	return deck

static func create_rotate_move_card(p_rotated_from_name: String = "", p_initiative: int = 5) -> CardData:
	var c := _make("\u21bb +1 Move", 1, p_initiative, "Rotate: Move 1",
		[{"type": "move", "value": 1}])
	c.rotated_from_name = p_rotated_from_name
	return c

static func create_rotate_block_card(p_rotated_from_name: String = "", p_initiative: int = 5) -> CardData:
	var c := _make("\u21bb +1 Block", 1, p_initiative, "Rotate: Block 1",
		[{"type": "block", "value": 1}])
	c.rotated_from_name = p_rotated_from_name
	return c

static func is_rotate_card(card: CardData) -> bool:
	return card != null and (card.card_name == "\u21bb +1 Move" or card.card_name == "\u21bb +1 Block")

static func encoded_name(card: CardData) -> String:
	if is_rotate_card(card) and card.rotated_from_name != "":
		return "%s<-%s" % [card.card_name, card.rotated_from_name]
	return card.card_name

static func _all_known_cards() -> Array:
	var cards := create_base_deck()
	cards.append(create_rotate_move_card())
	cards.append(create_rotate_block_card())
	for hero_type in ["Cleric"]:
		for level in range(1, 6):
			cards.append_array(create_class_deck(hero_type, level))
	return cards

static func from_name(p_card_name: String) -> CardData:
	if p_card_name.begins_with("\u21bb +1 Move<-"):
		var original_move := from_name(p_card_name.substr("\u21bb +1 Move<-".length()))
		return create_rotate_move_card(original_move.card_name, original_move.initiative) if original_move != null else create_rotate_move_card()
	if p_card_name.begins_with("\u21bb +1 Block<-"):
		var original_block := from_name(p_card_name.substr("\u21bb +1 Block<-".length()))
		return create_rotate_block_card(original_block.card_name, original_block.initiative) if original_block != null else create_rotate_block_card()
	if p_card_name == "\u21bb +1 Move":
		return create_rotate_move_card()
	if p_card_name == "\u21bb +1 Block":
		return create_rotate_block_card()
	for card in _all_known_cards():
		var typed_card: CardData = card as CardData
		if typed_card.card_name == p_card_name:
			return typed_card
	return null

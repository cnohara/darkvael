class_name CardData
extends Resource

var card_name: String = ""
var id: String = ""
var hero_class: String = "Base"
var level: int = 0
var cost: int = 1
var initiative: int = 5
var effect_text: String = ""
var effects: Array = []
var rotated_from_name: String = ""

static func _slug(value: String) -> String:
	var slug := value.to_lower()
	for ch in [" ", "-", "+", ",", ".", ":", ";", "(", ")", "/", "'"]:
		slug = slug.replace(ch, "_")
	while slug.contains("__"):
		slug = slug.replace("__", "_")
	while slug.begins_with("_"):
		slug = slug.substr(1)
	while slug.ends_with("_"):
		slug = slug.substr(0, slug.length() - 1)
	return slug

static func _make_card_id(p_hero_class: String, p_level: int, p_name: String) -> String:
	var level_part := "base" if p_level == 0 else "l%d" % p_level
	return "%s_%s_%s" % [_slug(p_hero_class), level_part, _slug(p_name)]

static func _make(p_name: String, p_cost: int, p_init: int, p_text: String, p_fx: Array, p_hero_class: String = "Base", p_level: int = 0) -> CardData:
	var c := CardData.new()
	c.card_name = p_name
	c.id = _make_card_id(p_hero_class, p_level, p_name)
	c.hero_class = p_hero_class
	c.level = p_level
	c.cost = p_cost
	c.initiative = p_init
	c.effect_text = p_text
	c.effects = p_fx
	return c

static func create_base_deck() -> Array:
	return [
		_make("Sidestep Strike", 2, 5, "Attack 5, Move 3.",
			[{"type": "attack", "value": 5, "range": 1, "attack_type": "physical"},
			 {"type": "move", "value": 3}]),
		_make("Shielded Shift", 2, 5, "Jump 3, Block 3.",
			[{"type": "jump", "value": 3},
			 {"type": "block", "value": 3}]),
		_make("Crushing Strike", 1, 5, "Attack 6.",
			[{"type": "attack", "value": 6, "range": 1, "attack_type": "physical"}]),
		_make("Mend", 2, 5, "Heal 3 to self or ally, Range 3.",
			[{"type": "heal", "value": 3, "range": 3, "target": "self_or_ally"}]),
		_make("Flurry", 2, 4, "Attack 4 to all adjacent enemies.",
			[{"type": "attack", "value": 4, "range": 1, "attack_type": "physical", "aoe_adjacent": true}]),
		_make("Shielded Advance", 2, 5, "Move 4, Block 3.",
			[{"type": "move", "value": 4},
			 {"type": "block", "value": 3}]),
		_make("Dash Strike", 2, 5, "Move 4, Attack 5.",
			[{"type": "move", "value": 4},
			 {"type": "attack", "value": 5, "range": 1, "attack_type": "physical"}]),
		_make("Fortify", 1, 5, "Block 4.",
			[{"type": "block", "value": 4}]),
		_make("Evade", 1, 3, "Move 3.",
			[{"type": "move", "value": 3}]),
		_make("Rejuvenate", 1, 6, "Heal 4 self.",
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
					[{"type": "heal", "value": 3, "range": 4, "target": "self_or_ally", "also_bless": true}], "Cleric", 1),
				_make("Divine Smite", 2, 7, "Magic Atk 5, Rng3, Slow",
					[{"type": "attack", "value": 5, "range": 3, "attack_type": "magic", "apply_condition": "slow"}], "Cleric", 1),
				_make("Sacred Barrier", 1, 4, "Block 2 self+adj allies",
					[{"type": "block", "value": 2, "target": "self_and_adjacent_allies"}], "Cleric", 1),
				_make("Quiet Petition", 1, 5, "Heal 2 self/ally Rng3; Bless if no conditions",
					[{"type": "heal", "value": 2, "range": 3, "target": "self_or_ally", "bless_if_no_conditions": true}], "Cleric", 1),
				_make("Votive Step", 1, 6, "Move 3; adj ally gains Block 2, Move 1",
					[{"type": "move", "value": 3},
					 {"type": "votive_step_bonus"}], "Cleric", 1),
				_make("Guiding Chant", 1, 4, "Block 2 self/ally Rng3; ally Move 1",
					[{"type": "guiding_chant", "value": 2, "range": 3}], "Cleric", 1),
			]
		2:
			return [
				_make("Holy Bolt", 2, 7, "Attack 5, Range 2. If the target is undead, +2 damage.",
					[{"type": "attack", "value": 5, "range": 2, "attack_type": "magic",
					  "undead_bonus": 2}], "Cleric", 2),
				_make("Blessed Strike", 2, 7, "Attack 6, Range 2. Confuse.",
					[{"type": "attack", "value": 6, "range": 2, "attack_type": "physical",
					  "apply_condition": "confused"}], "Cleric", 2),
				_make("Renew", 2, 5, "Heal 3 to self and all adjacent allies. Bless to self and one adjacent ally.",
					[{"type": "heal", "value": 3, "target": "self_and_adjacent_allies"},
					 {"type": "bless_self_and_one_adjacent_ally"}], "Cleric", 2),
				_make("Chant of Warding", 2, 5, "Block 2 to all allies in Range 2. Any ally who already has a Bless card gains Block 4 instead.",
					[{"type": "block", "value": 2, "target": "all_allies_in_range", "range": 2,
					  "bless_bonus_value": 4}], "Cleric", 2),
				_make("Halo Pulse", 2, 6, "Heal 2 to all adjacent allies. Push 2 adjacent enemies; enemies hitting walls are Stunned.",
					[{"type": "heal", "value": 2, "target": "adjacent_allies"},
					 {"type": "push", "value": 2, "target": "adjacent_enemies",
					  "stun_on_wall": true}], "Cleric", 2),  # TODO: implement forced push movement and stun_on_wall.
				_make("Burden Breaker", 2, 5, "Remove 1 condition from self or ally in Range 3, then Heal 3. If 2+ conditions were removed, gain Block 2.",
					[{"type": "cleanse", "count": 1, "range": 3, "target": "self_or_ally",
					  "then_heal": 3, "block_if_cleanse_count": 2}], "Cleric", 2),
			]
		3:
			return [
				_make("Smite Evil", 3, 7, "Attack 5, Range 4. If the target is undead, 2× damage.",
					[{"type": "attack", "value": 5, "range": 4, "attack_type": "magic",
					  "undead_multiplier": 2}], "Cleric", 3),
				_make("Sanctuary", 3, 4, "All allies in Range 3 take no damage this turn. Heal 4 to self and all allies in Range 3.",
					[{"type": "sanctuary", "range": 3},
					 {"type": "heal", "value": 4, "target": "self_and_allies_in_range", "range": 3}], "Cleric", 3),
				_make("Shield of Faith", 2, 4, "Block 4 and Bless to self or an ally in Range 3.",
					[{"type": "block", "value": 4, "target": "self_or_ally", "range": 3,
					  "also_bless": true}], "Cleric", 3),
				_make("Hymn of Reckoning", 3, 7, "Attack 5, Range 3. Increase damage by +2 for every Bless card currently held by allies in the party.",
					[{"type": "attack", "value": 5, "range": 3, "attack_type": "magic",
					  "party_bless_bonus": 2}], "Cleric", 3),
				_make("Devout Surge", 2, 6, "Attack 6, Range 3. You may move the target 2 spaces in any direction.",
					[{"type": "attack", "value": 6, "range": 3, "attack_type": "magic"},
					 {"type": "push_target", "value": 2, "direction": "any"}], "Cleric", 3),  # TODO: implement player-chosen forced movement.
				_make("Invoke Burden", 3, 5, "All allies in Range 2 gain Block 3. You may move each adjacent enemy 1 space.",
					[{"type": "block", "value": 3, "target": "all_allies_in_range", "range": 2},
					 {"type": "push", "value": 1, "target": "adjacent_enemies"}], "Cleric", 3),  # TODO: implement player-chosen forced movement.
			]
		4:
			return [
				_make("Divine Intervention", 3, 4, "Heal 6 to self or ally in Range 4. Remove all conditions. Bless.",
					[{"type": "heal", "value": 6, "range": 4, "target": "self_or_ally",
					  "cleanse_all": true, "also_bless": true}], "Cleric", 4),
				_make("Holy Nova", 3, 6, "Attack 5 to all enemies in Range 2. If an enemy is undead, +2 damage.",
					[{"type": "attack", "value": 5, "range": 2, "attack_type": "magic",
					  "aoe_all_in_range": true, "undead_bonus": 2}], "Cleric", 4),
				_make("Repel", 2, 5, "Push all adjacent enemies 2 spaces. Enemies hitting walls are Stunned.",
					[{"type": "push", "value": 2, "target": "adjacent_enemies",
					  "stun_on_wall": true}], "Cleric", 4),  # TODO: implement forced push movement and stun_on_wall.
				_make("Manifest Supplication", 3, 5, "Heal 3 and Block 3 to all allies in Range 3.",
					[{"type": "heal", "value": 3, "target": "all_allies_in_range", "range": 3},
					 {"type": "block", "value": 3, "target": "all_allies_in_range", "range": 3}], "Cleric", 4),
				_make("Incense Nova", 3, 6, "Attack 4 to all enemies in Range 2. Burn.",
					[{"type": "attack", "value": 4, "range": 2, "attack_type": "magic",
					  "aoe_all_in_range": true, "apply_condition": "burn"}], "Cleric", 4),
				_make("Liturgical Rush", 2, 6, "Move 4. Heal 2 to all adjacent allies. Gain Bless.",
					[{"type": "move", "value": 4},
					 {"type": "heal", "value": 2, "target": "adjacent_allies"},
					 {"type": "bless", "target": "self"}], "Cleric", 4),
			]
		5:
			return [
				_make("Wrath of the Divine", 4, 7, "Attack 7, Range 4. If the target is undead, +3 damage.",
					[{"type": "attack", "value": 7, "range": 4, "attack_type": "magic",
					  "undead_bonus": 3}], "Cleric", 5),
				_make("Divine Shield", 3, 4, "All allies in Range 3 gain Block 5 and cannot take damage this turn.",
					[{"type": "block", "value": 5, "target": "all_allies_in_range", "range": 3},
					 {"type": "sanctuary", "range": 3}], "Cleric", 5),
				_make("Holy Empowerment", 3, 5, "All allies in Range 3 gain Bless. Heal 3 to all allies in Range 3.",
					[{"type": "bless", "target": "all_allies_in_range", "range": 3},
					 {"type": "heal", "value": 3, "target": "all_allies_in_range", "range": 3}], "Cleric", 5),
				_make("Apotheosis Strike", 4, 7, "Attack 6, Range 3. Increase damage by +2 for every Bless card currently held by allies in the party.",
					[{"type": "attack", "value": 6, "range": 3, "attack_type": "magic",
					  "party_bless_bonus": 2}], "Cleric", 5),
				_make("Divine Chorus", 3, 4, "Heal 4, Block 4, and remove all conditions from all allies in Range 3.",
					[{"type": "heal", "value": 4, "target": "all_allies_in_range", "range": 3,
					  "cleanse_all": true},
					 {"type": "block", "value": 4, "target": "all_allies_in_range", "range": 3}], "Cleric", 5),
				_make("Pillar of Burden", 3, 6, "Attack 5 to all enemies in Range 2. Stun all enemies hit.",
					[{"type": "attack", "value": 5, "range": 2, "attack_type": "magic",
					  "aoe_all_in_range": true, "apply_condition": "stun"}], "Cleric", 5),
			]
	return []

static func get_class_cards_for_level(hero_type: String, level: int) -> Array:
	return create_class_deck(hero_type, level)

static func create_starting_deck(hero_type: String = "Cleric") -> Array:
	var deck := create_base_deck()
	deck.append_array(create_class_deck(hero_type, 1))
	return deck

static func create_hero_deck(hero_type: String = "Cleric") -> Array:
	return create_starting_deck(hero_type)

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

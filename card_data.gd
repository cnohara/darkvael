class_name CardData
extends Resource

var card_name: String = ""
var cost: int = 1
var initiative: int = 5
var effect_text: String = ""
var effects: Array = []

static func _make(p_name: String, p_cost: int, p_init: int, p_text: String, p_fx: Array) -> CardData:
	var c := CardData.new()
	c.card_name = p_name
	c.cost = p_cost
	c.initiative = p_init
	c.effect_text = p_text
	c.effects = p_fx
	return c

static func create_hero_deck() -> Array:
	return [
		_make("Crushing Strike", 1, 5, "Melee attack 4",
			[{"type": "attack", "value": 4, "range": 1}]),
		_make("Mend", 2, 5, "Heal self 3",
			[{"type": "heal", "value": 3}]),
		_make("Fortify", 1, 5, "Gain Block 4",
			[{"type": "block", "value": 4}]),
		_make("Evade", 1, 6, "Move 2, Gain Block 1",
			[{"type": "move", "value": 2}, {"type": "block", "value": 1}]),
		_make("Healing Light", 1, 4, "Heal 2, gain Bless",
			[{"type": "heal", "value": 2}, {"type": "bless"}]),
		_make("Divine Smite", 2, 7, "Rng3 atk 3, Slow",
			[{"type": "attack", "value": 3, "range": 3}, {"type": "slow"}]),
		_make("Sacred Barrier", 1, 4, "Gain Block 2",
			[{"type": "block", "value": 2}]),
		_make("Quiet Petition", 1, 5, "Heal self 2",
			[{"type": "heal", "value": 2}]),
		_make("Votive Step", 1, 6, "Move 3",
			[{"type": "move", "value": 3}]),
		_make("Guiding Chant", 1, 4, "Block 2, Move 1",
			[{"type": "block", "value": 2}, {"type": "move", "value": 1}]),
	]

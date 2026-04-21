class_name BehaviorData
extends Resource

var behavior_name: String = ""
var initiative: int = 5
var effect_text: String = ""
var effects: Array = []

static func _make(p_name: String, p_init: int, p_text: String, p_fx: Array) -> BehaviorData:
	var b := BehaviorData.new()
	b.behavior_name = p_name
	b.initiative = p_init
	b.effect_text = p_text
	b.effects = p_fx
	return b

static func create_enemy_deck() -> Array:
	return [
		_make("Advance & Strike", 5, "Move 2, atk 2 if adj",
			[{"type": "move_toward", "value": 2}, {"type": "attack_if_adj", "value": 2}]),
		_make("Guarded March", 4, "Block 2, move 1 toward",
			[{"type": "block", "value": 2}, {"type": "move_toward", "value": 1}]),
		_make("Lunge", 7, "Atk 3 if adj, else move 2",
			[{"type": "lunge", "attack_value": 3, "move_value": 2}]),
	]

static func from_name(behavior_name: String) -> BehaviorData:
	for behavior in create_enemy_deck():
		var typed_behavior: BehaviorData = behavior as BehaviorData
		if typed_behavior.behavior_name == behavior_name:
			return typed_behavior
	return null

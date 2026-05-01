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

static func create_deck_for_type(enemy_type: String) -> Array:
	match enemy_type:
		"UndeadSoldier":
			return _undead_soldier_deck()
		"UndeadArcher":
			return _undead_archer_deck()
		"BlackKnight":
			return _black_knight_deck()
		"Nashrat":
			return _nashrat_deck()
		"AshenSkeleton":
			return _ashen_skeleton_deck()
	return _undead_soldier_deck()

static func _undead_soldier_deck() -> Array:
	return [
		_make("Basic Strike", 4, "Move 1, Attack 4",
			[{"type": "move_toward", "value": 1},
			 {"type": "melee_attack", "value": 4}]),
		_make("Entangling Charge", 6, "Move 2, Entangle if adj",
			[{"type": "move_toward", "value": 2},
			 {"type": "apply_condition_if_adj", "condition": "entangle"}]),
		_make("Bomb Toss", 6, "Move 2, AoE Atk 4 Rng3",
			[{"type": "move_toward", "value": 2},
			 {"type": "ranged_attack", "value": 4, "range": 3, "aoe": true}]),
		_make("Poisoned Strike", 5, "Move 2, Attack 4, Poison",
			[{"type": "move_toward", "value": 2},
			 {"type": "melee_attack", "value": 4, "apply_condition": "poison"}]),
		_make("Shield Bash", 7, "Move 2, Attack 4, Stun",
			[{"type": "move_toward", "value": 2},
			 {"type": "melee_attack", "value": 4, "apply_condition": "stun"}]),
		_make("Undead Fury", 7, "Move 1, Attack 3, Poison",
			[{"type": "move_toward", "value": 1},
			 {"type": "melee_attack", "value": 3, "apply_condition": "poison"}]),
	]

static func _undead_archer_deck() -> Array:
	return [
		_make("Piercing Shot", 5, "Move 2, Atk 2 Rng5 IgnBlock",
			[{"type": "move_toward", "value": 2},
			 {"type": "ranged_attack", "value": 2, "range": 5, "ignore_block": true}]),
		_make("Venomous Strike", 6, "Move 2, Atk 3 Rng4, Poison",
			[{"type": "move_toward", "value": 2},
			 {"type": "ranged_attack", "value": 3, "range": 4, "apply_condition": "poison"}]),
		_make("Rapid Volley", 4, "Move 2, Atk 3 Rng4 x2 targets",
			[{"type": "move_toward", "value": 2},
			 {"type": "ranged_attack", "value": 3, "range": 4, "multi_target": 2}]),
		_make("Hidden Watch", 3, "Hidden",
			[{"type": "apply_condition_self", "condition": "hidden"}]),
		_make("Death's Aim", 5, "Move 1, Atk 4 Rng3",
			[{"type": "move_toward", "value": 1},
			 {"type": "ranged_attack", "value": 4, "range": 3}]),
		_make("Cursed Barrage", 6, "Move 3, Atk 2 Rng5, Poison",
			[{"type": "move_toward", "value": 3},
			 {"type": "ranged_attack", "value": 2, "range": 5, "apply_condition": "poison"}]),
	]

static func _black_knight_deck() -> Array:
	return [
		_make("Heavy Strike", 6, "Move 1, Atk 4, Block 3",
			[{"type": "move_toward", "value": 1},
			 {"type": "melee_attack", "value": 4},
			 {"type": "block", "value": 3}]),
		_make("Sweeping Cleave", 5, "Move 3, AoE Atk 4",
			[{"type": "move_toward", "value": 3},
			 {"type": "melee_attack", "value": 4, "aoe_adjacent": true}]),
		_make("Shield Bash", 6, "Move 2, Stun if adj",
			[{"type": "move_toward", "value": 2},
			 {"type": "apply_condition_if_adj", "condition": "stun"}]),
		_make("Guard Stance", 8, "Block 5",
			[{"type": "block", "value": 5}]),
		_make("Executioner's Blow", 5, "Move 2, Atk 4 if target HP<=6 else Atk 2",
			[{"type": "move_toward", "value": 2},
			 {"type": "executioner_blow", "high_value": 4, "low_value": 2, "hp_threshold": 6}]),
		_make("Dark Lunge", 7, "Move 4, Atk 5 IgnBlock",
			[{"type": "move_toward", "value": 4},
			 {"type": "melee_attack", "value": 5, "ignore_block": true}]),
	]

static func _nashrat_deck() -> Array:
	return [
		_make("Scurry Away", 2, "Move 1 away",
			[{"type": "move_away", "value": 1}]),
		_make("Bite", 3, "Move 3, Attack 1",
			[{"type": "move_toward", "value": 3},
			 {"type": "melee_attack", "value": 1}]),
		_make("Swarm", 4, "Attack 2",
			[{"type": "melee_attack", "value": 2}]),
		_make("Frenzied Rush", 3, "Move 3, Attack 1",
			[{"type": "move_toward", "value": 3},
			 {"type": "melee_attack", "value": 1}]),
		_make("Diseased Bite", 4, "Attack 1, Poison",
			[{"type": "melee_attack", "value": 1, "apply_condition": "poison"}]),
		_make("Retreat", 2, "Move 2 away",
			[{"type": "move_away", "value": 2}]),
	]

static func _ashen_skeleton_deck() -> Array:
	return [
		_make("Tainted Slash", 5, "Move 2, Attack 4, Burn",
			[{"type": "move_toward", "value": 2},
			 {"type": "melee_attack", "value": 4, "apply_condition": "burn"}]),
		_make("Cracked Blade", 5, "Move 2, Attack 4",
			[{"type": "move_toward", "value": 2},
			 {"type": "melee_attack", "value": 4}]),
		_make("Splintered Fury", 7, "Move 3, Attack 2 twice",
			[{"type": "move_toward", "value": 3},
			 {"type": "multi_melee", "value": 2, "count": 2}]),
		_make("Boneguard", 4, "Block 3",
			[{"type": "block", "value": 3}]),
		_make("Fire Arrow", 6, "Atk 3 Rng3, Burn",
			[{"type": "ranged_attack", "value": 3, "range": 3, "apply_condition": "burn"}]),
		_make("Death Rattle", 5, "Attack 4, Entangle",
			[{"type": "melee_attack", "value": 4, "apply_condition": "entangle"}]),
	]

static func from_name_for_type(p_behavior_name: String, enemy_type: String) -> BehaviorData:
	for behavior in create_deck_for_type(enemy_type):
		var typed: BehaviorData = behavior as BehaviorData
		if typed.behavior_name == p_behavior_name:
			return typed
	return null

static func from_name(p_behavior_name: String) -> BehaviorData:
	for enemy_type in ["UndeadSoldier", "UndeadArcher", "BlackKnight", "Nashrat", "AshenSkeleton"]:
		var result := from_name_for_type(p_behavior_name, enemy_type)
		if result != null:
			return result
	return null

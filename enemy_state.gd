class_name EnemyState
extends RefCounted

var index: int = 0
var enemy_type: String = "UndeadSoldier"
var hp: int = 6
var max_hp: int = 6
var physical_armor: int = 0
var magic_armor: int = 0
var xp_reward: int = 1
var block: int = 0
var pos: Vector2i = Vector2i(2, 0)
var alive: bool = true
var draw: Array = []
var discard: Array = []
var revealed = null

var poison: bool = false
var stun: bool = false
var entangle: bool = false
var hidden: bool = false
var confused: bool = false
var slow: bool = false

func apply_damage(amount: int, attack_type: String = "physical", ignore_block: bool = false) -> int:
	var remaining := amount
	if not ignore_block:
		var absorbed := mini(block, remaining)
		block -= absorbed
		remaining -= absorbed
	if attack_type == "magic":
		remaining = maxi(remaining - magic_armor, 0)
	else:
		remaining = maxi(remaining - physical_armor, 0)
	hp = maxi(hp - remaining, 0)
	alive = hp > 0
	return remaining

func apply_poison_damage() -> int:
	hp = maxi(hp - 1, 0)
	alive = hp > 0
	return 1

func has_any_condition() -> bool:
	return poison or stun or entangle or hidden or confused or slow

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
	if slow:
		parts.append("Slow")
	return ", ".join(parts)

func status_text() -> String:
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
	if slow:
		parts.append("Slow")
	if not alive:
		parts.append("Dead")
	return "" if parts.is_empty() else "[" + ", ".join(parts) + "]"

func to_dict() -> Dictionary:
	return {
		"index": index,
		"enemy_type": enemy_type,
		"hp": hp,
		"max_hp": max_hp,
		"physical_armor": physical_armor,
		"magic_armor": magic_armor,
		"xp_reward": xp_reward,
		"block": block,
		"pos": [pos.x, pos.y],
		"alive": alive,
		"draw": _behaviors_to_names(draw),
		"discard": _behaviors_to_names(discard),
		"revealed": "" if revealed == null else revealed.behavior_name,
		"poison": poison,
		"stun": stun,
		"entangle": entangle,
		"hidden": hidden,
		"confused": confused,
		"slow": slow,
	}

func load_from_dict(data: Dictionary) -> void:
	index = int(data.get("index", index))
	enemy_type = String(data.get("enemy_type", enemy_type))
	hp = int(data.get("hp", hp))
	max_hp = int(data.get("max_hp", max_hp))
	physical_armor = int(data.get("physical_armor", physical_armor))
	magic_armor = int(data.get("magic_armor", magic_armor))
	xp_reward = int(data.get("xp_reward", xp_reward))
	block = int(data.get("block", block))
	var pos_arr: Array = data.get("pos", [pos.x, pos.y])
	pos = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
	alive = bool(data.get("alive", alive))
	draw = _names_to_behaviors(data.get("draw", []), enemy_type)
	discard = _names_to_behaviors(data.get("discard", []), enemy_type)
	var revealed_name := String(data.get("revealed", ""))
	revealed = null if revealed_name == "" else BehaviorData.from_name_for_type(revealed_name, enemy_type)
	poison = bool(data.get("poison", poison))
	stun = bool(data.get("stun", stun))
	entangle = bool(data.get("entangle", entangle))
	hidden = bool(data.get("hidden", hidden))
	confused = bool(data.get("confused", confused))
	slow = bool(data.get("slow", slow))

func _behaviors_to_names(behaviors: Array) -> Array:
	var names: Array = []
	for behavior in behaviors:
		if behavior == null:
			continue
		names.append(behavior.behavior_name)
	return names

func _names_to_behaviors(names: Array, p_enemy_type: String) -> Array:
	var behaviors: Array = []
	for behavior_name in names:
		var behavior = BehaviorData.from_name_for_type(String(behavior_name), p_enemy_type)
		if behavior != null:
			behaviors.append(behavior)
	return behaviors

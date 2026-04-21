class_name EnemyState
extends RefCounted

const BehaviorDataScript = preload("res://behavior_data.gd")

var index: int = 0
var hp: int = 10
var max_hp: int = 10
var block: int = 0
var pos: Vector2i = Vector2i(2, 0)
var slow: bool = false
var alive: bool = true
var draw: Array = []
var discard: Array = []
var revealed = null

func apply_damage(amount: int) -> int:
	var absorbed := mini(block, amount)
	block -= absorbed
	var actual := amount - absorbed
	hp = maxi(hp - actual, 0)
	alive = hp > 0
	return actual

func status_text() -> String:
	var parts: Array[String] = []
	if slow:
		parts.append("Slow")
	if not alive:
		parts.append("Dead")
	return "" if parts.is_empty() else "[" + ", ".join(parts) + "]"

func to_dict() -> Dictionary:
	return {
		"index": index,
		"hp": hp,
		"max_hp": max_hp,
		"block": block,
		"pos": [pos.x, pos.y],
		"slow": slow,
		"alive": alive,
		"draw": _behaviors_to_names(draw),
		"discard": _behaviors_to_names(discard),
		"revealed": "" if revealed == null else revealed.behavior_name,
	}

func load_from_dict(data: Dictionary) -> void:
	index = int(data.get("index", index))
	hp = int(data.get("hp", hp))
	max_hp = int(data.get("max_hp", max_hp))
	block = int(data.get("block", block))
	var pos_arr: Array = data.get("pos", [pos.x, pos.y])
	pos = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
	slow = bool(data.get("slow", slow))
	alive = bool(data.get("alive", alive))
	draw = _names_to_behaviors(data.get("draw", []))
	discard = _names_to_behaviors(data.get("discard", []))
	var revealed_name := String(data.get("revealed", ""))
	revealed = null if revealed_name == "" else BehaviorDataScript.from_name(revealed_name)

func _behaviors_to_names(behaviors: Array) -> Array:
	var names: Array = []
	for behavior in behaviors:
		if behavior == null:
			continue
		names.append(behavior.behavior_name)
	return names

func _names_to_behaviors(names: Array) -> Array:
	var behaviors: Array = []
	for behavior_name in names:
		var behavior = BehaviorDataScript.from_name(String(behavior_name))
		if behavior != null:
			behaviors.append(behavior)
	return behaviors

class_name EnemyState
extends RefCounted

var hp: int = 10
var max_hp: int = 10
var block: int = 0
var pos: Vector2i = Vector2i(2, 0)
var slow: bool = false
var alive: bool = true

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
		"hp": hp,
		"max_hp": max_hp,
		"block": block,
		"pos": [pos.x, pos.y],
		"slow": slow,
		"alive": alive,
	}

func load_from_dict(data: Dictionary) -> void:
	hp = int(data.get("hp", hp))
	max_hp = int(data.get("max_hp", max_hp))
	block = int(data.get("block", block))
	var pos_arr: Array = data.get("pos", [pos.x, pos.y])
	pos = Vector2i(int(pos_arr[0]), int(pos_arr[1]))
	slow = bool(data.get("slow", slow))
	alive = bool(data.get("alive", alive))

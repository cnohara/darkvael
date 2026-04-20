class_name EnemyState
extends RefCounted

var index: int = 0
var hp: int = 10
var max_hp: int = 10
var block: int = 0
var pos: Vector2i = Vector2i(2, 0)
var slow: bool = false
var draw: Array = []
var revealed: BehaviorData = null
var discard: Array = []

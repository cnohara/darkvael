class_name Pathfinder

const BOARD_SIZE := 5

static func get_reachable(from: Vector2i, steps: int, blocked_list: Array) -> Array:
	var visited: Dictionary = {}
	var queue: Array = [[from, 0]]
	var result: Array = []
	visited[from] = true
	while queue.size() > 0:
		var item: Array = queue.pop_front()
		var pos: Vector2i = item[0]
		var dist: int = item[1]
		if pos != from:
			result.append(pos)
		if dist >= steps:
			continue
		for neighbor in get_neighbors(pos):
			if blocked_list.has(neighbor):
				continue
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			queue.append([neighbor, dist + 1])
	return result

static func find_path(from: Vector2i, to: Vector2i, blocked_list: Array) -> Array:
	if from == to:
		return []
	var visited: Dictionary = {}
	var parent: Dictionary = {}
	var queue: Array = [from]
	visited[from] = true
	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		for neighbor in get_neighbors(pos):
			if blocked_list.has(neighbor):
				continue
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			parent[neighbor] = pos
			if neighbor == to:
				return _reconstruct(parent, from, to)
			queue.append(neighbor)
	return []

static func _reconstruct(parent: Dictionary, from: Vector2i, to: Vector2i) -> Array:
	var path: Array = []
	var cur := to
	while cur != from:
		path.push_front(cur)
		cur = parent[cur]
	return path

static func get_neighbors(pos: Vector2i) -> Array:
	var result: Array = []
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var n: Vector2i = pos + d
		if n.x >= 0 and n.x < BOARD_SIZE and n.y >= 0 and n.y < BOARD_SIZE:
			result.append(n)
	return result

static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

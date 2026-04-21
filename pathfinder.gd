class_name Pathfinder

const BOARD_SIZE := 5

# Units may pass through occupied tiles but cannot END on them.
# Terrain-blocked tiles cannot be passed through or used as a destination.
# end_blocked: tiles that cannot be a final destination.
static func get_reachable(from: Vector2i, steps: int, end_blocked: Array, terrain_blocked: Array = [], exit_destinations: Array = []) -> Array:
	var visited: Dictionary = {}
	var queue: Array = [[from, 0]]
	var result: Array = []
	visited[from] = true
	while queue.size() > 0:
		var item: Array = queue.pop_front()
		var pos: Vector2i = item[0]
		var dist: int = item[1]
		if pos != from and not end_blocked.has(pos) and not terrain_blocked.has(pos):
			result.append(pos)
		if dist >= steps:
			continue
		for neighbor in get_neighbors(pos, terrain_blocked, exit_destinations):
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			queue.append([neighbor, dist + 1])
	return result

# Path allows passing through end_blocked tiles but destination must not be in end_blocked.
# Terrain-blocked tiles are never valid path steps.
static func find_path(from: Vector2i, to: Vector2i, end_blocked: Array, terrain_blocked: Array = [], exit_destinations: Array = []) -> Array:
	if from == to:
		return []
	if end_blocked.has(to) or terrain_blocked.has(to):
		return []
	if not _is_in_bounds(to) and not exit_destinations.has(to):
		return []
	var visited: Dictionary = {}
	var parent: Dictionary = {}
	var queue: Array = [from]
	visited[from] = true
	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()
		for neighbor in get_neighbors(pos, terrain_blocked, exit_destinations):
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

static func get_neighbors(pos: Vector2i, terrain_blocked: Array = [], exit_destinations: Array = []) -> Array:
	var result: Array = []
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		var n: Vector2i = pos + d
		if _is_in_bounds(n) and not terrain_blocked.has(n):
			result.append(n)
		elif exit_destinations.has(n):
			result.append(n)
	return result

static func _is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE

static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

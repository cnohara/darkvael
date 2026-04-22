class_name MapTileData

const DIR_NORTH := "north"
const DIR_EAST := "east"
const DIR_SOUTH := "south"
const DIR_WEST := "west"
const DEFAULT_TILE_ID := "map_tile_1"

const MAP_TILE_1 := {
	"id": "map_tile_1",
	"name": "Map Tile 1",
	"image_path": "res://assets/maps/map_tiles_card1.png",
	"obstacles": [
		Vector2i(0, 0),
		Vector2i(0, 2),
		Vector2i(0, 4),
		Vector2i(2, 2),
	],
	"exits": [
		{ "cell": Vector2i(1, 0), "dir": DIR_SOUTH },
		{ "cell": Vector2i(2, 0), "dir": DIR_SOUTH },
		{ "cell": Vector2i(1, 4), "dir": DIR_NORTH },
		{ "cell": Vector2i(2, 4), "dir": DIR_NORTH },
		{ "cell": Vector2i(4, 0), "dir": DIR_EAST },
		{ "cell": Vector2i(4, 1), "dir": DIR_EAST },
		{ "cell": Vector2i(4, 2), "dir": DIR_EAST },
		{ "cell": Vector2i(4, 3), "dir": DIR_EAST },
		{ "cell": Vector2i(4, 4), "dir": DIR_EAST },
	],
	"torches": [
		{ "cell": Vector2i(0, 0), "dir": DIR_WEST },
		{ "cell": Vector2i(0, 4), "dir": DIR_WEST },
	],
	"props": [
		{
			"asset": "res://assets/3d/crates_and_barrels.glb",
			"node": "C16",
			"cell": Vector2i(2, 2),
			"rotation": 0.0,
			"scale": 1.0,
			"offset": Vector3(0.12, 0.0, 0.08),
		},
	],
	"walls": [],
}

const MAP_TILE_2 := {
	"id": "map_tile_2",
	"name": "Map Tile 2",
	"image_path": "res://assets/maps/map_tiles_card2.png",
	"obstacles": [
		Vector2i(0, 0),
		Vector2i(3, 1),
		Vector2i(4, 0),
		Vector2i(4, 4),
	],
	"exits": [
		{ "cell": Vector2i(2, 0), "dir": DIR_SOUTH },
		{ "cell": Vector2i(0, 2), "dir": DIR_WEST },
		{ "cell": Vector2i(2, 4), "dir": DIR_NORTH },
	],
	"walls": [],
}

const ALL_TILES := {
	"map_tile_1": MAP_TILE_1,
	"map_tile_2": MAP_TILE_2,
}

static func get_tile(tile_id: String) -> Dictionary:
	return ALL_TILES.get(tile_id, {})

static func get_obstacles(tile_id: String = DEFAULT_TILE_ID) -> Array:
	return get_tile(tile_id).get("obstacles", [])

static func get_exits(tile_id: String = DEFAULT_TILE_ID) -> Array:
	return get_tile(tile_id).get("exits", [])

static func get_torches(tile_id: String = DEFAULT_TILE_ID) -> Array:
	return get_tile(tile_id).get("torches", [])

static func get_props(tile_id: String = DEFAULT_TILE_ID) -> Array:
	return get_tile(tile_id).get("props", [])

static func get_tile_ids() -> Array:
	return ALL_TILES.keys()

static func get_random_tile_id() -> String:
	var ids := get_tile_ids()
	if ids.is_empty():
		return DEFAULT_TILE_ID
	return String(ids[randi() % ids.size()])

static func get_random_connected_tile_id(exit_dir: String, exclude_tile_id: String = "") -> String:
	var entry_dir := opposite_dir(exit_dir)
	var candidates: Array = []
	for tile_id in get_tile_ids():
		if tile_id == exclude_tile_id and ALL_TILES.size() > 1:
			continue
		if has_exit_on_side(String(tile_id), entry_dir):
			candidates.append(tile_id)
	if candidates.is_empty():
		for tile_id in get_tile_ids():
			if has_exit_on_side(String(tile_id), entry_dir):
				candidates.append(tile_id)
	if candidates.is_empty():
		return exclude_tile_id if not exclude_tile_id.is_empty() else DEFAULT_TILE_ID
	return String(candidates[randi() % candidates.size()])

static func has_exit_on_side(tile_id: String, dir: String) -> bool:
	for exit in get_exits(tile_id):
		if exit.get("dir") == dir:
			return true
	return false

static func exit_destination(cell: Vector2i, dir: String) -> Vector2i:
	match dir:
		DIR_NORTH:
			return Vector2i(cell.x, Pathfinder.BOARD_SIZE)
		DIR_EAST:
			return Vector2i(Pathfinder.BOARD_SIZE, cell.y)
		DIR_SOUTH:
			return Vector2i(cell.x, -1)
		DIR_WEST:
			return Vector2i(-1, cell.y)
	return cell

static func exit_dir_from_destination(pos: Vector2i) -> String:
	if pos.x < 0:
		return DIR_WEST
	if pos.x >= Pathfinder.BOARD_SIZE:
		return DIR_EAST
	if pos.y < 0:
		return DIR_SOUTH
	if pos.y >= Pathfinder.BOARD_SIZE:
		return DIR_NORTH
	return ""

static func exit_cell_from_destination(pos: Vector2i) -> Vector2i:
	return Vector2i(clampi(pos.x, 0, Pathfinder.BOARD_SIZE - 1), clampi(pos.y, 0, Pathfinder.BOARD_SIZE - 1))

static func opposite_dir(dir: String) -> String:
	match dir:
		DIR_NORTH:
			return DIR_SOUTH
		DIR_EAST:
			return DIR_WEST
		DIR_SOUTH:
			return DIR_NORTH
		DIR_WEST:
			return DIR_EAST
	return ""

static func closest_open_entry(tile_id: String, entry_dir: String, from_exit_cell: Vector2i, occupied: Array = []) -> Vector2i:
	var terrain_blocked := get_obstacles(tile_id)
	var best := Vector2i(-1, -1)
	var best_dist := 999
	for exit in get_exits(tile_id):
		if exit.get("dir") != entry_dir:
			continue
		var cell: Vector2i = exit.get("cell")
		if terrain_blocked.has(cell) or occupied.has(cell):
			continue
		var dist := _side_axis_distance(entry_dir, from_exit_cell, cell)
		if dist < best_dist:
			best = cell
			best_dist = dist
	if best != Vector2i(-1, -1):
		return best
	return _nearest_open_side_cell(tile_id, entry_dir, from_exit_cell, occupied)

static func _side_axis_distance(dir: String, a: Vector2i, b: Vector2i) -> int:
	if dir == DIR_NORTH or dir == DIR_SOUTH:
		return abs(a.x - b.x)
	return abs(a.y - b.y)

static func _nearest_open_side_cell(tile_id: String, dir: String, from_exit_cell: Vector2i, occupied: Array) -> Vector2i:
	var terrain_blocked := get_obstacles(tile_id)
	var best := Vector2i(-1, -1)
	var best_dist := 999
	for i in range(Pathfinder.BOARD_SIZE):
		var cell := Vector2i.ZERO
		match dir:
			DIR_NORTH:
				cell = Vector2i(i, Pathfinder.BOARD_SIZE - 1)
			DIR_EAST:
				cell = Vector2i(Pathfinder.BOARD_SIZE - 1, i)
			DIR_SOUTH:
				cell = Vector2i(i, 0)
			DIR_WEST:
				cell = Vector2i(0, i)
		if terrain_blocked.has(cell) or occupied.has(cell):
			continue
		var dist := _side_axis_distance(dir, from_exit_cell, cell)
		if dist < best_dist:
			best = cell
			best_dist = dist
	if best != Vector2i(-1, -1):
		return best
	for y in range(Pathfinder.BOARD_SIZE):
		for x in range(Pathfinder.BOARD_SIZE):
			var fallback := Vector2i(x, y)
			if not terrain_blocked.has(fallback) and not occupied.has(fallback):
				return fallback
	return Vector2i(2, 2)

static func get_perimeter_walls(tile: Dictionary) -> Array:
	var exits: Array = tile.get("exits", [])
	var result: Array = []
	for i in range(Pathfinder.BOARD_SIZE):
		_add_perimeter_wall_if_needed(result, exits, Vector2i(i, 0), DIR_SOUTH)
		_add_perimeter_wall_if_needed(result, exits, Vector2i(i, Pathfinder.BOARD_SIZE - 1), DIR_NORTH)
		_add_perimeter_wall_if_needed(result, exits, Vector2i(0, i), DIR_WEST)
		_add_perimeter_wall_if_needed(result, exits, Vector2i(Pathfinder.BOARD_SIZE - 1, i), DIR_EAST)
	return result

static func _add_perimeter_wall_if_needed(result: Array, exits: Array, cell: Vector2i, dir: String) -> void:
	for exit in exits:
		if exit.get("cell") == cell and exit.get("dir") == dir:
			return
	result.append({ "cell": cell, "dir": dir })

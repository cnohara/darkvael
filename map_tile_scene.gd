@tool
class_name MapTileScene
extends Node3D

const MAP_OBSTACLE_SCRIPT := preload("res://map_obstacle.gd")
const MAP_LIGHT_SOURCE_SCRIPT := preload("res://map_light_source.gd")
const AUTO_OBSTACLE_CELL := Vector2i(-999, -999)
const AUTO_LIGHT_CELL := Vector2i(-999, -999)
const DIR_NORTH := "north"
const DIR_EAST := "east"
const DIR_SOUTH := "south"
const DIR_WEST := "west"

@export var map_id := ""
@export var display_name := ""
@export var image_path := ""
@export var obstacles: Array[Vector2i] = []
@export var exits: Array[Dictionary] = []
@export var torches: Array[Dictionary] = []
@export var props: Array[Dictionary] = []
@export var walls: Array[Dictionary] = []
@export var include_marker_obstacles := true
@export var include_marker_lights := true
@export var grid_size := 5

func to_tile_dict() -> Dictionary:
	return {
		"id": map_id,
		"name": display_name,
		"image_path": image_path,
		"scene_path": scene_file_path,
		"obstacles": get_all_obstacles(),
		"exits": exits.duplicate(true),
		"torches": get_all_torches(),
		"props": props.duplicate(true),
		"walls": walls.duplicate(true),
	}

func get_all_obstacles() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in obstacles:
		_add_obstacle_cell(result, cell)

	if not include_marker_obstacles:
		return result

	for node in find_children("*", "Node3D", true, false):
		if node.get_script() != MAP_OBSTACLE_SCRIPT:
			continue
		if not bool(node.get("blocks_movement")):
			continue

		var obstacle_cell: Vector2i = node.get("cell")
		if bool(node.get("infer_cell_from_position")) or obstacle_cell == AUTO_OBSTACLE_CELL:
			obstacle_cell = _local_position_to_cell(_relative_transform(self, node as Node3D).origin)

		_add_obstacle_cell(result, obstacle_cell)

	return result

func get_all_torches() -> Array[Dictionary]:
	var result: Array[Dictionary] = torches.duplicate(true)

	if not include_marker_lights:
		return result

	for node in find_children("*", "Node3D", true, false):
		if node.get_script() != MAP_LIGHT_SOURCE_SCRIPT:
			continue
		if not bool(node.get("enabled")):
			continue
		if String(node.get("kind")) != "torch":
			continue

		var torch_cell: Vector2i = node.get("cell")
		if bool(node.get("infer_cell_from_position")) or torch_cell == AUTO_LIGHT_CELL:
			torch_cell = _local_position_to_cell(_relative_transform(self, node as Node3D).origin)

		var torch := {
			"cell": torch_cell,
			"dir": String(node.get("dir")),
		}
		_add_unique_torch(result, torch)

	return result

func _add_unique_torch(result: Array[Dictionary], torch: Dictionary) -> void:
	var cell: Vector2i = torch.get("cell", Vector2i(-1, -1))
	if not _is_cell_in_bounds(cell):
		return
	var dir := String(torch.get("dir", ""))
	for existing in result:
		if existing.get("cell") == cell and String(existing.get("dir", "")) == dir:
			return
	result.append(torch)

func _add_obstacle_cell(result: Array[Vector2i], cell: Vector2i) -> void:
	if not _is_cell_in_bounds(cell):
		return
	if not result.has(cell):
		result.append(cell)

func _is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size and cell.y >= 0 and cell.y < grid_size

func _local_position_to_cell(local_position: Vector3) -> Vector2i:
	return Vector2i(
		clampi(roundi(local_position.x), 0, grid_size - 1),
		clampi(grid_size - 1 - roundi(local_position.z), 0, grid_size - 1)
	)

func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform

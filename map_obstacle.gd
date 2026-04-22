@tool
class_name MapObstacle
extends Node3D

const AUTO_CELL := Vector2i(-999, -999)

@export var blocks_movement := true
@export var infer_cell_from_position := true
@export var cell := AUTO_CELL

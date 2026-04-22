@tool
class_name MapLightSource
extends Node3D

const AUTO_CELL := Vector2i(-999, -999)

@export var enabled := true
@export var kind := "torch"
@export_enum("north", "east", "south", "west") var dir := "west"
@export var infer_cell_from_position := false
@export var cell := AUTO_CELL

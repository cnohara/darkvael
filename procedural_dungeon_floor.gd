@tool
class_name ProceduralDungeonFloor
extends Node3D

@export var grid_size := 5:
	set(value):
		grid_size = max(value, 1)
		_rebuild()
@export var cell_size := 1.0:
	set(value):
		cell_size = maxf(value, 0.1)
		_rebuild()
@export var floor_seed := 1401:
	set(value):
		floor_seed = value
		_rebuild()
@export var slab_height := 0.075:
	set(value):
		slab_height = maxf(value, 0.01)
		_rebuild()
@export var seam_gap := 0.026:
	set(value):
		seam_gap = maxf(value, 0.0)
		_rebuild()
@export var edge_margin := 0.035:
	set(value):
		edge_margin = maxf(value, 0.0)
		_rebuild()
@export var base_color := Color(0.37, 0.35, 0.29):
	set(value):
		base_color = value
		_rebuild()
@export var color_variation := 0.055:
	set(value):
		color_variation = maxf(value, 0.0)
		_rebuild()
@export var chip_density := 0.65:
	set(value):
		chip_density = clampf(value, 0.0, 1.0)
		_rebuild()

var _generated_root: Node3D
var _rebuild_queued := false

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild_deferred")

func _rebuild_deferred() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	if _generated_root != null and is_instance_valid(_generated_root):
		_generated_root.queue_free()

	_generated_root = Node3D.new()
	_generated_root.name = "GeneratedDungeonStoneFloor"
	add_child(_generated_root)

	_add_mortar_base()
	for y in range(grid_size):
		for x in range(grid_size):
			_build_cell(Vector2i(x, y))

func _add_mortar_base() -> void:
	var base := MeshInstance3D.new()
	base.name = "DarkMortarBase"
	base.position = Vector3(
		float(grid_size - 1) * cell_size * 0.5,
		-slab_height - 0.018,
		float(grid_size - 1) * cell_size * 0.5
	)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(
		float(grid_size) * cell_size + 0.12,
		0.045,
		float(grid_size) * cell_size + 0.12
	)
	base.mesh = mesh
	base.material_override = _flat_material(Color(0.055, 0.058, 0.050), 1.0)
	_generated_root.add_child(base)

func _build_cell(cell: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_seed + cell.x * 389 + cell.y * 997

	var cell_root := Node3D.new()
	cell_root.name = "Cell_%d_%d" % [cell.x, cell.y]
	cell_root.position = Vector3(
		float(cell.x) * cell_size,
		-slab_height * 0.5,
		float(grid_size - 1 - cell.y) * cell_size
	)
	_generated_root.add_child(cell_root)

	_build_cell_layout(cell_root, rng)
	_add_cell_wear(cell_root, rng)

func _build_cell_layout(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var m := edge_margin + rng.randf_range(-0.01, 0.012)
	var left := -0.5 + m
	var right := 0.5 - m
	var top := -0.5 + m
	var bottom := 0.5 - m
	var split_x := rng.randf_range(-0.16, 0.18)
	var split_z := rng.randf_range(-0.15, 0.17)
	var layout := int(rng.randi_range(0, 5))

	match layout:
		0:
			_add_slab(parent, left, right, top, bottom, rng)
		1:
			_add_slab(parent, left, split_x, top, bottom, rng)
			_add_slab(parent, split_x, right, top, bottom, rng)
		2:
			_add_slab(parent, left, right, top, split_z, rng)
			_add_slab(parent, left, right, split_z, bottom, rng)
		3:
			_add_slab(parent, left, split_x, top, split_z, rng)
			_add_slab(parent, split_x, right, top, split_z, rng)
			_add_slab(parent, left, right, split_z, bottom, rng)
		4:
			_add_slab(parent, left, right, top, split_z, rng)
			_add_slab(parent, left, split_x, split_z, bottom, rng)
			_add_slab(parent, split_x, right, split_z, bottom, rng)
		_:
			_add_slab(parent, left, split_x, top, split_z, rng)
			_add_slab(parent, split_x, right, top, split_z, rng)
			_add_slab(parent, left, split_x, split_z, bottom, rng)
			_add_slab(parent, split_x, right, split_z, bottom, rng)

func _add_slab(parent: Node3D, left: float, right: float, top: float, bottom: float, rng: RandomNumberGenerator) -> void:
	var width := maxf(absf(right - left) - seam_gap, 0.08)
	var depth := maxf(absf(bottom - top) - seam_gap, 0.08)
	var slab := MeshInstance3D.new()
	slab.name = "StoneSlab"
	slab.position = Vector3(
		(left + right) * 0.5 + rng.randf_range(-0.009, 0.009),
		rng.randf_range(-0.005, 0.006),
		(top + bottom) * 0.5 + rng.randf_range(-0.009, 0.009)
	)
	slab.rotation_degrees.y = rng.randf_range(-0.9, 0.9)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, slab_height + rng.randf_range(-0.014, 0.014), depth)
	slab.mesh = mesh
	slab.material_override = _stone_material(rng)
	parent.add_child(slab)

func _add_cell_wear(parent: Node3D, rng: RandomNumberGenerator) -> void:
	if rng.randf() > chip_density:
		return
	var detail_count := int(rng.randi_range(2, 5))
	for i in range(detail_count):
		if rng.randf() < 0.7:
			_add_chip(parent, rng)
		else:
			_add_stain(parent, rng)

func _add_chip(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var chip := MeshInstance3D.new()
	chip.name = "Chip"
	chip.position = Vector3(
		rng.randf_range(-0.42, 0.42),
		slab_height * 0.5 + 0.004,
		rng.randf_range(-0.42, 0.42)
	)
	chip.rotation_degrees.y = rng.randf_range(-35.0, 35.0)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(
		rng.randf_range(0.045, 0.13),
		0.006,
		rng.randf_range(0.012, 0.035)
	)
	chip.mesh = mesh
	chip.material_override = _flat_material(Color(0.10, 0.105, 0.092), 1.0)
	parent.add_child(chip)

func _add_stain(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var stain := MeshInstance3D.new()
	stain.name = "Grime"
	stain.position = Vector3(
		rng.randf_range(-0.34, 0.34),
		slab_height * 0.5 + 0.005,
		rng.randf_range(-0.34, 0.34)
	)
	stain.rotation_degrees.y = rng.randf_range(-18.0, 18.0)

	var mesh := BoxMesh.new()
	var side := rng.randf_range(0.10, 0.22)
	mesh.size = Vector3(side, 0.004, side * rng.randf_range(0.35, 0.75))
	stain.mesh = mesh
	stain.material_override = _flat_material(Color(0.065, 0.080, 0.060), 0.72)
	parent.add_child(stain)

func _stone_material(rng: RandomNumberGenerator) -> StandardMaterial3D:
	var shade := rng.randf_range(-color_variation, color_variation)
	var moss := rng.randf_range(0.0, color_variation * 0.45)
	var color := Color(
		clampf(base_color.r + shade, 0.0, 1.0),
		clampf(base_color.g + shade + moss, 0.0, 1.0),
		clampf(base_color.b + shade * 0.75, 0.0, 1.0)
	)
	return _flat_material(color, 1.0)

func _flat_material(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.roughness = 0.96
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

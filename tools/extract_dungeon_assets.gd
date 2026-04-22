@tool
extends SceneTree

const OBSTACLE_SCRIPT := "res://map_obstacle.gd"
const FLOOR_SOURCE := "res://assets/3d/floor_material.glb"
const MODULAR_SOURCE := "res://assets/3d/modular_dungeon_kit.glb"
const STYLIZED_SOURCE := "res://assets/3d/stylized_dungeon.glb"
const FLOOR_SOURCE_TILE_SIZE := 400.0
const MODULAR_SOURCE_TILE_SIZE := 200.0

const FLOOR_SPECS := [
	{"source": "Plane", "scene_name": "DungeonFloorMaterial", "output": "res://props/DungeonFloorMaterial.tscn", "blocks": false, "mode": "floor_fixed"},
]

const MODULAR_SPECS := [
	{"source": "Tile1_01", "scene_name": "DungeonTile1", "output": "res://props/DungeonTile1.tscn", "blocks": false, "mode": "fixed"},
	{"source": "Tile2_01", "scene_name": "DungeonTile2", "output": "res://props/DungeonTile2.tscn", "blocks": false, "mode": "fixed"},
	{"source": "Tile3_01", "scene_name": "DungeonTile3", "output": "res://props/DungeonTile3.tscn", "blocks": false, "mode": "fixed"},
	{"source": "Wall_01", "scene_name": "DungeonWall1", "output": "res://props/DungeonWall1.tscn", "blocks": false, "mode": "fixed"},
	{"source": "Wall2_01", "scene_name": "DungeonWall2", "output": "res://props/DungeonWall2.tscn", "blocks": false, "mode": "fixed"},
	{"source": "Wall3_01", "scene_name": "DungeonWall3", "output": "res://props/DungeonWall3.tscn", "blocks": false, "mode": "fixed"},
	{"source": "Wall4_01", "scene_name": "DungeonWall4", "output": "res://props/DungeonWall4.tscn", "blocks": false, "mode": "fixed"},
	{"source": "Pillar_01", "scene_name": "DungeonPillar", "output": "res://props/DungeonPillar.tscn", "blocks": true, "mode": "fixed"},
	{"source": "Rock_01", "scene_name": "DungeonRock1", "output": "res://props/DungeonRock1.tscn", "blocks": true, "mode": "fixed"},
	{"source": "Rock2_01", "scene_name": "DungeonRock2", "output": "res://props/DungeonRock2.tscn", "blocks": true, "mode": "fixed"},
	{"source": "BarrelBroken_01", "scene_name": "DungeonBarrelBroken", "output": "res://props/DungeonBarrelBroken.tscn", "blocks": true, "mode": "fixed"},
	{"source": "BarrelOpen_01", "scene_name": "DungeonBarrelOpen", "output": "res://props/DungeonBarrelOpen.tscn", "blocks": true, "mode": "fixed"},
	{"source": "BarrelClosed_01", "scene_name": "DungeonBarrelClosed", "output": "res://props/DungeonBarrelClosed.tscn", "blocks": true, "mode": "fixed"},
	{"source": "Braiser_01", "scene_name": "DungeonBrazier", "output": "res://props/DungeonBrazier.tscn", "blocks": true, "mode": "fixed"},
	{"source": "WallTorch_01", "scene_name": "DungeonWallTorch", "output": "res://props/DungeonWallTorch.tscn", "blocks": false, "mode": "fixed"},
	{"source": "Banner_01", "scene_name": "DungeonBanner1", "output": "res://props/DungeonBanner1.tscn", "blocks": false, "mode": "fixed"},
	{"source": "Banner_02", "scene_name": "DungeonBanner2", "output": "res://props/DungeonBanner2.tscn", "blocks": false, "mode": "fixed"},
	{"source": "Banner_03", "scene_name": "DungeonBanner3", "output": "res://props/DungeonBanner3.tscn", "blocks": false, "mode": "fixed"},
]

const STYLIZED_SPECS := [
	{"source": "Object_2", "scene_name": "StylizedDungeonObject02", "output": "res://props/StylizedDungeonObject02.tscn", "blocks": false, "mode": "fit"},
	{"source": "Object_3", "scene_name": "StylizedDungeonObject03", "output": "res://props/StylizedDungeonObject03.tscn", "blocks": false, "mode": "fit"},
	{"source": "Object_4", "scene_name": "StylizedDungeonObject04", "output": "res://props/StylizedDungeonObject04.tscn", "blocks": false, "mode": "fit"},
	{"source": "Object_5", "scene_name": "StylizedDungeonObject05", "output": "res://props/StylizedDungeonObject05.tscn", "blocks": false, "mode": "fit"},
	{"source": "Object_6", "scene_name": "StylizedDungeonObject06", "output": "res://props/StylizedDungeonObject06.tscn", "blocks": false, "mode": "fit"},
	{"source": "Object_7", "scene_name": "StylizedDungeonObject07", "output": "res://props/StylizedDungeonObject07.tscn", "blocks": false, "mode": "fit"},
	{"source": "Object_8", "scene_name": "StylizedDungeonObject08", "output": "res://props/StylizedDungeonObject08.tscn", "blocks": false, "mode": "fit"},
	{"source": "Object_9", "scene_name": "StylizedDungeonObject09", "output": "res://props/StylizedDungeonObject09.tscn", "blocks": false, "mode": "fit"},
	{"source": "Object_10", "scene_name": "StylizedDungeonObject10", "output": "res://props/StylizedDungeonObject10.tscn", "blocks": false, "mode": "fit"},
]

func _initialize() -> void:
	var failed := false
	failed = _extract_specs(FLOOR_SOURCE, FLOOR_SPECS) or failed
	failed = _extract_specs(MODULAR_SOURCE, MODULAR_SPECS) or failed
	failed = _extract_specs(STYLIZED_SOURCE, STYLIZED_SPECS) or failed
	quit(1 if failed else 0)

func _extract_specs(source_scene: String, specs: Array) -> bool:
	var packed := load(source_scene) as PackedScene
	if packed == null:
		push_error("Could not load %s" % source_scene)
		return true

	var failed := false
	for spec in specs:
		if not _save_prop_scene(packed, source_scene, spec):
			failed = true
	return failed

func _save_prop_scene(packed: PackedScene, source_scene: String, spec: Dictionary) -> bool:
	var source_name := spec["source"] as String
	var scene_name := spec["scene_name"] as String
	var output_scene := spec["output"] as String

	var source_root := packed.instantiate()
	var source_node := source_root.find_child(source_name, true, false)
	if source_node == null:
		source_root.queue_free()
		push_error("Could not find node %s in %s" % [source_name, source_scene])
		return false

	var root := Node3D.new()
	root.name = scene_name
	if bool(spec.get("blocks", false)):
		root.set_script(load(OBSTACLE_SCRIPT))

	var visual := source_node.duplicate(Node.DUPLICATE_USE_INSTANTIATION)
	visual.name = "Visual"
	if visual is Node3D:
		(visual as Node3D).transform = Transform3D.IDENTITY
	root.add_child(visual)
	_set_owner_recursive(visual, root)

	match String(spec.get("mode", "fit")):
		"floor_fixed":
			_normalize_with_scale(root, visual, 1.0 / FLOOR_SOURCE_TILE_SIZE)
		"fixed":
			_normalize_with_scale(root, visual, 1.0 / MODULAR_SOURCE_TILE_SIZE)
		_:
			_fit_to_cell(root, visual, 0.9)

	var output := PackedScene.new()
	var pack_result := output.pack(root)
	if pack_result != OK:
		source_root.queue_free()
		root.queue_free()
		push_error("Could not pack %s: %s" % [output_scene, pack_result])
		return false

	var save_result := ResourceSaver.save(output, output_scene)
	if save_result != OK:
		source_root.queue_free()
		root.queue_free()
		push_error("Could not save %s: %s" % [output_scene, save_result])
		return false

	source_root.queue_free()
	root.queue_free()
	print("Saved %s from %s/%s" % [output_scene, source_scene, source_name])
	return true

func _normalize_with_scale(root: Node3D, visual: Node, fixed_scale: float) -> void:
	var bounds := _combined_local_aabb(root)
	if bounds.size == Vector3.ZERO or not visual is Node3D:
		return

	var visual_3d := visual as Node3D
	var center := bounds.get_center()
	visual_3d.scale = Vector3.ONE * fixed_scale
	visual_3d.position = Vector3(
		-center.x * fixed_scale,
		-bounds.position.y * fixed_scale,
		-center.z * fixed_scale
	)

func _fit_to_cell(root: Node3D, visual: Node, fit_size: float) -> void:
	var bounds := _combined_local_aabb(root)
	if bounds.size == Vector3.ZERO or not visual is Node3D:
		return

	var visual_3d := visual as Node3D
	var center := bounds.get_center()
	var max_footprint := maxf(bounds.size.x, bounds.size.z)
	if max_footprint <= 0.001:
		return

	var fit_scale := fit_size / max_footprint
	visual_3d.scale = Vector3.ONE * fit_scale
	visual_3d.position = Vector3(
		-center.x * fit_scale,
		-bounds.position.y * fit_scale,
		-center.z * fit_scale
	)

func _combined_local_aabb(root: Node3D) -> AABB:
	var has_bounds := false
	var combined := AABB()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local_xform := _relative_transform(root, mi)
		var local_aabb := _transform_aabb(mi.get_aabb(), local_xform)
		if has_bounds:
			combined = combined.merge(local_aabb)
		else:
			combined = local_aabb
			has_bounds = true
	return combined if has_bounds else AABB()

func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)

func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform

func _transform_aabb(aabb: AABB, xform: Transform3D) -> AABB:
	var points := [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
		aabb.position + Vector3(0.0, aabb.size.y, 0.0),
		aabb.position + Vector3(0.0, 0.0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
		aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
		aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size,
	]
	var transformed := AABB(xform * points[0], Vector3.ZERO)
	for i in range(1, points.size()):
		transformed = transformed.expand(xform * points[i])
	return transformed

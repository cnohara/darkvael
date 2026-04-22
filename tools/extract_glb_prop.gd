@tool
extends SceneTree

const SOURCE_SCENE := "res://assets/3d/crates_and_barrels.glb"
const OBSTACLE_SCRIPT := "res://map_obstacle.gd"
const CELL_FIT_SIZE := 0.78
const VISUAL_OFFSET := Vector3.ZERO

const PROP_SPECS := [
	{"source": "C1", "scene_name": "CrateC01", "output": "res://props/CrateC01.tscn"},
	{"source": "C2", "scene_name": "CrateC02", "output": "res://props/CrateC02.tscn"},
	{"source": "C3", "scene_name": "CrateC03", "output": "res://props/CrateC03.tscn"},
	{"source": "C4", "scene_name": "CrateC04", "output": "res://props/CrateC04.tscn"},
	{"source": "C5", "scene_name": "CrateC05", "output": "res://props/CrateC05.tscn"},
	{"source": "C6", "scene_name": "CrateC06", "output": "res://props/CrateC06.tscn"},
	{"source": "C7", "scene_name": "CrateC07", "output": "res://props/CrateC07.tscn"},
	{"source": "C8", "scene_name": "CrateC08", "output": "res://props/CrateC08.tscn"},
	{"source": "C9", "scene_name": "CrateC09", "output": "res://props/CrateC09.tscn"},
	{"source": "C10", "scene_name": "CrateC10", "output": "res://props/CrateC10.tscn"},
	{"source": "C11", "scene_name": "CrateC11", "output": "res://props/CrateC11.tscn"},
	{"source": "C12", "scene_name": "CrateC12", "output": "res://props/CrateC12.tscn"},
	{"source": "C13", "scene_name": "CrateC13", "output": "res://props/CrateC13.tscn"},
	{"source": "C14", "scene_name": "CrateC14", "output": "res://props/CrateC14.tscn"},
	{"source": "C15", "scene_name": "CrateC15", "output": "res://props/CrateC15.tscn"},
	{"source": "C16", "scene_name": "CrateC16", "output": "res://props/CrateC16.tscn"},
	{"source": "B1", "scene_name": "BarrelB01", "output": "res://props/BarrelB01.tscn"},
	{"source": "B2", "scene_name": "BarrelB02", "output": "res://props/BarrelB02.tscn"},
	{"source": "B3", "scene_name": "BarrelB03", "output": "res://props/BarrelB03.tscn"},
	{"source": "B4", "scene_name": "BarrelB04", "output": "res://props/BarrelB04.tscn"},
	{"source": "B5", "scene_name": "BarrelB05", "output": "res://props/BarrelB05.tscn"},
	{"source": "B6", "scene_name": "BarrelB06", "output": "res://props/BarrelB06.tscn"},
]

func _initialize() -> void:
	var packed := load(SOURCE_SCENE) as PackedScene
	if packed == null:
		push_error("Could not load %s" % SOURCE_SCENE)
		quit(1)
		return

	var failed := false
	for spec in PROP_SPECS:
		if not _save_prop_scene(packed, spec):
			failed = true

	quit(1 if failed else 0)

func _save_prop_scene(packed: PackedScene, spec: Dictionary) -> bool:
	var source_name := spec["source"] as String
	var scene_name := spec["scene_name"] as String
	var output_scene := spec["output"] as String

	var source_root := packed.instantiate()
	var source_node := source_root.find_child(source_name, true, false)
	if source_node == null:
		source_root.queue_free()
		push_error("Could not find node %s in %s" % [source_name, SOURCE_SCENE])
		return false

	var root := Node3D.new()
	root.name = scene_name
	root.set_script(load(OBSTACLE_SCRIPT))

	var visual := source_node.duplicate(Node.DUPLICATE_USE_INSTANTIATION)
	visual.name = "Visual"
	if visual is Node3D:
		(visual as Node3D).transform = Transform3D.IDENTITY
	root.add_child(visual)
	_set_owner_recursive(visual, root)

	_normalize_visual(root, visual)

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
	print("Saved %s from %s/%s" % [output_scene, SOURCE_SCENE, source_name])
	return true

func _normalize_visual(root: Node3D, visual: Node) -> void:
	var bounds := _combined_local_aabb(root)
	if bounds.size == Vector3.ZERO or not visual is Node3D:
		return

	var visual_3d := visual as Node3D
	var center := bounds.get_center()

	var max_footprint := maxf(bounds.size.x, bounds.size.z)
	if max_footprint <= 0.001:
		return

	var fit_scale := CELL_FIT_SIZE / max_footprint
	visual_3d.scale = Vector3.ONE * fit_scale
	visual_3d.position = Vector3(
		-center.x * fit_scale,
		-bounds.position.y * fit_scale,
		-center.z * fit_scale
	) + VISUAL_OFFSET

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

@tool
extends SceneTree

const SOURCES := [
	"res://assets/3d/floor_material.glb",
	"res://assets/3d/modular_dungeon_kit.glb",
	"res://assets/3d/stylized_dungeon.glb",
]

func _initialize() -> void:
	for source in SOURCES:
		_print_source(source)
	quit(0)

func _print_source(source: String) -> void:
	var packed := load(source) as PackedScene
	if packed == null:
		push_error("Could not load %s" % source)
		return

	var root := packed.instantiate()
	print("\n== %s ==" % source)
	_print_node(root, 0)
	root.queue_free()

func _print_node(node: Node, depth: int) -> void:
	var prefix := ""
	for i in range(depth):
		prefix += "  "

	var suffix := ""
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var aabb := mesh_instance.get_aabb()
			suffix = " mesh surfaces=%d aabb=%s" % [mesh_instance.mesh.get_surface_count(), aabb]
	print("%s- %s [%s]%s" % [prefix, node.name, node.get_class(), suffix])

	for child in node.get_children():
		_print_node(child, depth + 1)

@tool
extends PanelContainer

const PROP_DIR := "res://props"
const TILE_SIZE := Vector2i(112, 132)
const PREVIEW_SIZE := Vector2i(84, 84)

var editor_interface: EditorInterface

var _search: LineEdit
var _grid: GridContainer
var _prop_paths: Array[String] = []
var _tiles: Array[Control] = []

func _ready() -> void:
	name = "Prop Browser"
	_build_ui()
	_scan_props()
	_rebuild_tiles()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var title := Label.new()
	title.text = "Prop Browser"
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)

	_search = LineEdit.new()
	_search.placeholder_text = "Search props"
	_search.text_changed.connect(_on_search_changed)
	root.add_child(_search)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

func _scan_props() -> void:
	_prop_paths.clear()

	var dir := DirAccess.open(PROP_DIR)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".tscn") and file_name != "PropGallery.tscn":
			_prop_paths.append("%s/%s" % [PROP_DIR, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()

	_prop_paths.sort()

func _rebuild_tiles() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_tiles.clear()

	var filter := _search.text.strip_edges().to_lower()
	for prop_path in _prop_paths:
		if not filter.is_empty() and prop_path.get_file().get_basename().to_lower().find(filter) == -1:
			continue

		var tile := PropTile.new()
		tile.custom_minimum_size = TILE_SIZE
		tile.prop_path = prop_path
		tile.tooltip_text = "%s\nDrag into an open scene." % prop_path
		_grid.add_child(tile)
		_tiles.append(tile)

func _on_search_changed(_new_text: String) -> void:
	_rebuild_tiles()

class PropTile extends PanelContainer:
	var prop_path := ""

	var _label: Label
	var _viewport: SubViewport

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 4)
		add_child(box)

		var preview := SubViewportContainer.new()
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.custom_minimum_size = PREVIEW_SIZE
		preview.stretch = true
		box.add_child(preview)

		_viewport = SubViewport.new()
		_viewport.size = PREVIEW_SIZE
		_viewport.own_world_3d = true
		_viewport.transparent_bg = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		preview.add_child(_viewport)

		_build_preview_scene()

		_label = Label.new()
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.text = prop_path.get_file().get_basename()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(_label)

	func _build_preview_scene() -> void:
		var world := Node3D.new()
		_viewport.add_child(world)

		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45, -35, 0)
		light.light_energy = 2.2
		world.add_child(light)

		var camera := Camera3D.new()
		camera.current = true
		world.add_child(camera)

		var packed := load(prop_path) as PackedScene
		if packed == null:
			return

		var prop := packed.instantiate() as Node3D
		if prop == null:
			return
		world.add_child(prop)

		var bounds := _combined_local_aabb(prop)
		if bounds.size == Vector3.ZERO:
			return

		var center := bounds.get_center()
		prop.position -= Vector3(center.x, bounds.position.y, center.z)

		var max_size := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		if max_size > 0.001:
			prop.scale *= Vector3.ONE * (1.0 / max_size)

		camera.look_at_from_position(Vector3(1.45, 1.15, 1.75), Vector3(0.0, 0.35, 0.0))

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var drag_label := Label.new()
		drag_label.text = prop_path.get_file().get_basename()
		drag_label.add_theme_font_size_override("font_size", 16)
		set_drag_preview(drag_label)

		return {
			"type": "files",
			"files": PackedStringArray([prop_path]),
			"from": "prop_browser"
		}

	func _combined_local_aabb(root_node: Node3D) -> AABB:
		var has_bounds := false
		var combined := AABB()
		for child in root_node.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := child as MeshInstance3D
			if mesh_instance == null or mesh_instance.mesh == null:
				continue
			var local_xform := _relative_transform(root_node, mesh_instance)
			var local_aabb := _transform_aabb(mesh_instance.get_aabb(), local_xform)
			if has_bounds:
				combined = combined.merge(local_aabb)
			else:
				combined = local_aabb
				has_bounds = true
		return combined if has_bounds else AABB()

	func _relative_transform(root_node: Node3D, node: Node3D) -> Transform3D:
		var xform := Transform3D.IDENTITY
		var current: Node = node
		while current != null and current != root_node:
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

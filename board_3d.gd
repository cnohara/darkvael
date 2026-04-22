class_name Board3D
extends Node3D

signal tile_pressed(pos: Vector2i)
signal enemy_pressed(enemy_idx: int)

const TILE_SIZE := 1.0
const TILE_GAP  := 0.07
const TILE_H    := 0.14
const UNIT_H    := 0.82
const ZOOM_MIN  := 5.8
const ZOOM_MAX  := 14.0
const WALL_H    := 0.72
const MAP_TILE_DATA := preload("res://map_tile_data.gd")

var _tile_mats: Array = []
var _exit_mats: Dictionary = {}
var _map_dressing_root: Node3D = null
var _player_mis: Array = []
var _enemy_mis: Array = []
var _cam: Camera3D
var _active_map_tile_id := MAP_TILE_DATA.DEFAULT_TILE_ID
var _map_floor_mat: StandardMaterial3D = null
var _player_colors := [
	Color(0.22, 0.42, 0.88),
	Color(0.16, 0.62, 0.46),
	Color(0.72, 0.42, 0.92),
	Color(0.88, 0.66, 0.20),
]
var _enemy_colors := [
	Color(0.82, 0.18, 0.18),
	Color(0.84, 0.40, 0.12),
	Color(0.64, 0.16, 0.42),
]
var _targetable_enemy_indices: Array = []
var _active_target_enemy_idx := -1
var _enemy_target_tweens: Dictionary = {}

# ── Public API ───────────────────────────────────────────────────────────────

func setup() -> void:
	_build_environment()
	_build_light()
	_build_map_floor()
	_build_tiles()
	_build_exit_tiles()
	_rebuild_map_dressing()
	_build_units()
	_build_camera()
	update_board([], [], [], -1)

func adjust_zoom(factor: float) -> void:
	_cam.size = clampf(_cam.size / factor, ZOOM_MIN, ZOOM_MAX)

func get_zoom_size() -> float:
	return _cam.size

func set_zoom_size(size: float) -> void:
	_cam.size = clampf(size, ZOOM_MIN, ZOOM_MAX)

func set_map_tile_id(tile_id: String) -> void:
	if tile_id.is_empty() or tile_id == _active_map_tile_id:
		return
	_active_map_tile_id = tile_id
	_update_map_floor_texture()
	_rebuild_map_dressing()

func set_enemy_label(enemy_idx: int, label_text: String) -> void:
	if enemy_idx < 0 or enemy_idx >= _enemy_mis.size():
		return
	var mi: MeshInstance3D = _enemy_mis[enemy_idx]
	if mi.get_child_count() > 0:
		var lbl := mi.get_child(0) as Label3D
		if lbl != null:
			lbl.text = label_text

func update_board(player_positions: Array, enemy_positions: Array, highlighted: Array, active_player_idx: int = -1) -> void:
	for y in range(5):
		for x in range(5):
			var mat: StandardMaterial3D = _tile_mats[y * 5 + x]
			var gp := Vector2i(x, y)
			if highlighted.has(gp):
				mat.albedo_color = Color(0.08, 0.72, 0.48, 0.42)
				mat.emission_enabled = true
				mat.emission = Color(0.04, 0.38, 0.28)
				mat.emission_energy_multiplier = 0.6
			else:
				mat.albedo_color = Color(0.20, 0.20, 0.28, 0.0)
				mat.emission_enabled = false
	_update_exit_tiles(highlighted)
	for i in range(_player_mis.size()):
		var mi: MeshInstance3D = _player_mis[i]
		var mat := mi.material_override as StandardMaterial3D
		if i < player_positions.size() and player_positions[i] != Vector2i(-1, -1):
			mi.visible = true
			var pp: Vector2i = player_positions[i]
			mi.position = _grid_to_world(pp, TILE_H + UNIT_H * 0.5)
			if mat != null:
				mat.emission_enabled = i == active_player_idx
				mat.emission = Color(0.95, 0.90, 0.40)
				mat.emission_energy_multiplier = 1.4 if i == active_player_idx else 0.0
		else:
			mi.visible = false
	for i in range(_enemy_mis.size()):
		var enemy_mi: MeshInstance3D = _enemy_mis[i]
		var mat := enemy_mi.material_override as StandardMaterial3D
		if i < enemy_positions.size() and enemy_positions[i] != Vector2i(-1, -1):
			enemy_mi.visible = true
			var enemy_pos: Vector2i = enemy_positions[i]
			enemy_mi.position = _grid_to_world(enemy_pos, TILE_H + UNIT_H * 0.5)
			if mat != null:
				mat.albedo_color = _enemy_colors[i]
				mat.emission_enabled = false
				mat.emission_energy_multiplier = 0.0
				if _targetable_enemy_indices.has(i):
					mat.emission_enabled = true
					mat.emission = Color(0.95, 0.72, 0.18)
					mat.emission_energy_multiplier = 1.2
				if i == _active_target_enemy_idx:
					mat.emission_enabled = true
					mat.emission = Color(1.0, 0.92, 0.30)
					mat.emission_energy_multiplier = 2.5
		else:
			enemy_mi.visible = false

func flash_tile(pos: Vector2i, color: Color) -> void:
	if _exit_mats.has(pos):
		var exit_mat: StandardMaterial3D = _exit_mats[pos]
		exit_mat.albedo_color = Color(color.r, color.g, color.b, 0.66)
		exit_mat.emission_enabled = true
		exit_mat.emission = color
		exit_mat.emission_energy_multiplier = 1.0
		return
	var mat: StandardMaterial3D = _tile_mats[pos.y * 5 + pos.x]
	mat.albedo_color = Color(color.r, color.g, color.b, 0.58)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.0

func set_enemy_target_state(selectable_indices: Array, active_enemy_idx: int = -1) -> void:
	_targetable_enemy_indices = selectable_indices.duplicate()
	if active_enemy_idx != _active_target_enemy_idx:
		_stop_enemy_target_pulse(_active_target_enemy_idx)
		_active_target_enemy_idx = active_enemy_idx
	if _active_target_enemy_idx >= 0:
		_start_enemy_target_pulse(_active_target_enemy_idx)
	for i in range(_enemy_mis.size()):
		if i != _active_target_enemy_idx:
			_stop_enemy_target_pulse(i)
			_enemy_mis[i].scale = Vector3.ONE

func clear_enemy_target_state() -> void:
	set_enemy_target_state([], -1)

# ── Animations ───────────────────────────────────────────────────────────────

func animate_player_step(player_idx: int, target_grid: Vector2i) -> void:
	var mi: MeshInstance3D = _player_mis[player_idx]
	await _animate_step_mesh(mi, target_grid)

func animate_enemy_step(enemy_idx: int, target_grid: Vector2i) -> void:
	await _animate_step_mesh(_enemy_mis[enemy_idx], target_grid)

func _animate_step_mesh(mi: MeshInstance3D, target_grid: Vector2i) -> void:
	var from := mi.position
	var to   := _grid_to_world(target_grid, TILE_H + UNIT_H * 0.5)
	var hop  := 0.48

	var step_fn := func(t: float) -> void:
		mi.position.x = lerpf(from.x, to.x, t)
		mi.position.y = lerpf(from.y, to.y, t) + sin(t * PI) * hop
		mi.position.z = lerpf(from.z, to.z, t)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_method(step_fn, 0.0, 1.0, 0.42)
	await tween.finished

func animate_melee_attack(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var world := _grid_to_world(from_pos, TILE_H + UNIT_H * 0.65)
	var target_world := _grid_to_world(to_pos, TILE_H + UNIT_H * 0.65)

	var pivot := Node3D.new()
	pivot.position = world
	var dx := target_world.x - world.x
	var dz := target_world.z - world.z
	pivot.rotation.y = atan2(dx, dz)
	pivot.rotation_degrees.x = -65.0
	add_child(pivot)

	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 0.74)
	blade.mesh = bm
	blade.position = Vector3(0.0, 0.0, 0.35)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.85, 0.90, 0.98)
	bmat.metallic = 0.95
	bmat.roughness = 0.08
	bmat.emission_enabled = true
	bmat.emission = Color(0.70, 0.82, 1.0)
	bmat.emission_energy_multiplier = 2.5
	blade.material_override = bmat
	pivot.add_child(blade)

	var guard := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.44, 0.07, 0.07)
	guard.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.85, 0.65, 0.20)
	gmat.metallic = 0.65
	gmat.roughness = 0.30
	guard.material_override = gmat
	pivot.add_child(guard)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(pivot, "rotation_degrees:x", 65.0, 0.24)
	await tween.finished
	pivot.queue_free()

func animate_player_hit(player_idx: int) -> void:
	await _animate_hit_mesh(_player_mis[player_idx])

func animate_enemy_hit(enemy_idx: int) -> void:
	await _animate_hit_mesh(_enemy_mis[enemy_idx])

func _animate_hit_mesh(mi: MeshInstance3D) -> void:
	var origin := mi.position

	var shake_fn := func(t: float) -> void:
		mi.position.x = origin.x + sin(t * PI * 6.0) * 0.20 * (1.0 - t)

	var tween := create_tween()
	tween.tween_method(shake_fn, 0.0, 1.0, 0.38)
	await tween.finished
	mi.position = origin

func animate_ranged_attack(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var from_w := _grid_to_world(from_pos, TILE_H + UNIT_H * 0.72)
	var to_w   := _grid_to_world(to_pos, TILE_H + UNIT_H * 0.72)

	var proj := MeshInstance3D.new()
	var sph  := SphereMesh.new()
	sph.radius = 0.11
	sph.height = 0.22
	proj.mesh  = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.12)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.0)
	mat.emission_energy_multiplier = 5.0
	proj.material_override = mat
	proj.position = from_w
	add_child(proj)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(proj, "position", to_w, 0.36)
	await tween.finished
	proj.queue_free()

func animate_block(target_pos: Vector2i) -> void:
	var world := _grid_to_world(target_pos, TILE_H + UNIT_H * 0.55)

	var shield := MeshInstance3D.new()
	var bm     := BoxMesh.new()
	bm.size    = Vector3(0.70, 0.82, 0.09)
	shield.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.55, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.20, 0.42, 1.0)
	mat.emission_energy_multiplier = 3.0
	shield.material_override = mat
	shield.position = world
	shield.scale    = Vector3.ZERO
	add_child(shield)

	var tween := create_tween()
	tween.tween_property(shield, "scale", Vector3.ONE, 0.10)
	tween.tween_interval(0.26)
	tween.tween_property(shield, "scale", Vector3.ZERO, 0.12)
	await tween.finished
	shield.queue_free()

# ── Scene Build ──────────────────────────────────────────────────────────────

func _build_environment() -> void:
	var we  := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color(0.06, 0.06, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.40, 0.42, 0.52)
	env.ambient_light_energy = 1.5
	we.environment = env
	add_child(we)

func _build_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy   = 1.1
	sun.light_color    = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = false
	add_child(sun)

func _build_map_floor() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(5.0, 5.0)
	mi.mesh = plane
	mi.position = Vector3(2.0, 0.005, 2.0)

	_map_floor_mat = StandardMaterial3D.new()
	_map_floor_mat.roughness = 0.9
	_map_floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = _map_floor_mat
	add_child(mi)
	_update_map_floor_texture()

func _update_map_floor_texture() -> void:
	if _map_floor_mat == null:
		return
	var map_tile := MAP_TILE_DATA.get_tile(_active_map_tile_id)
	var image_path: String = map_tile.get("image_path", "")
	var image := Image.load_from_file(image_path)
	if image != null:
		_map_floor_mat.albedo_texture = ImageTexture.create_from_image(image)

func _build_tiles() -> void:
	var side := TILE_SIZE - TILE_GAP
	for y in range(5):
		for x in range(5):
			var area  := Area3D.new()
			area.position = _grid_to_world(Vector2i(x, y), 0.0)
			add_child(area)

			var col   := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size   = Vector3(side + 0.06, TILE_H + 0.14, side + 0.06)
			col.shape    = shape
			col.position = Vector3(0.0, TILE_H * 0.5, 0.0)
			area.add_child(col)

			var mi  := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size    = Vector3(side, TILE_H, side)
			mi.mesh     = box
			mi.position = Vector3(0.0, TILE_H * 0.5, 0.0)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.20, 0.20, 0.28, 0.0)
			mat.roughness    = 0.85
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.material_override = mat
			area.add_child(mi)

			_tile_mats.append(mat)
			area.input_event.connect(_on_tile_event.bind(Vector2i(x, y)))

func _build_exit_tiles() -> void:
	for i in range(Pathfinder.BOARD_SIZE):
		_add_exit_tile(Vector2i(i, -1), _grid_to_world(Vector2i(i, -1), 0.0))
		_add_exit_tile(Vector2i(i, Pathfinder.BOARD_SIZE), _grid_to_world(Vector2i(i, Pathfinder.BOARD_SIZE), 0.0))
		_add_exit_tile(Vector2i(-1, i), _grid_to_world(Vector2i(-1, i), 0.0))
		_add_exit_tile(Vector2i(Pathfinder.BOARD_SIZE, i), _grid_to_world(Vector2i(Pathfinder.BOARD_SIZE, i), 0.0))

func _add_exit_tile(gpos: Vector2i, world_pos: Vector3) -> void:
	var side := TILE_SIZE - TILE_GAP
	var area := Area3D.new()
	area.position = world_pos
	add_child(area)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(side + 0.06, TILE_H + 0.14, side + 0.06)
	col.shape = shape
	col.position = Vector3(0.0, TILE_H * 0.5, 0.0)
	area.add_child(col)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(side, TILE_H * 0.72, side)
	mi.mesh = box
	mi.position = Vector3(0.0, TILE_H * 0.36, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.70, 0.48, 0.0)
	mat.roughness = 0.85
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	area.add_child(mi)

	_exit_mats[gpos] = mat
	area.input_event.connect(_on_tile_event.bind(gpos))

func _update_exit_tiles(highlighted: Array) -> void:
	for gpos in _exit_mats.keys():
		var mat: StandardMaterial3D = _exit_mats[gpos]
		if highlighted.has(gpos):
			mat.albedo_color = Color(0.04, 0.86, 0.56, 0.58)
			mat.emission_enabled = true
			mat.emission = Color(0.04, 0.42, 0.28)
			mat.emission_energy_multiplier = 0.8
		else:
			mat.albedo_color = Color(0.04, 0.70, 0.48, 0.0)
			mat.emission_enabled = false

func _rebuild_map_dressing() -> void:
	if _map_dressing_root != null:
		_map_dressing_root.queue_free()
	_map_dressing_root = Node3D.new()
	_map_dressing_root.name = "MapDressing"
	add_child(_map_dressing_root)

	var map_tile := MAP_TILE_DATA.get_tile(_active_map_tile_id)
	for wall in MAP_TILE_DATA.get_perimeter_walls(map_tile):
		_add_wall_segment(wall.get("cell"), String(wall.get("dir", "")))
	for exit in MAP_TILE_DATA.get_exits(_active_map_tile_id):
		_add_exit_dressing(exit.get("cell"), String(exit.get("dir", "")))
	for obstacle in MAP_TILE_DATA.get_obstacles(_active_map_tile_id):
		_add_obstacle_dressing(obstacle)
	for torch in MAP_TILE_DATA.get_torches(_active_map_tile_id):
		_add_torch_dressing(torch.get("cell"), String(torch.get("dir", "")))

func _add_wall_segment(cell: Vector2i, dir: String) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	var thickness := 0.18
	match dir:
		MAP_TILE_DATA.DIR_NORTH, MAP_TILE_DATA.DIR_SOUTH:
			box.size = Vector3(0.96, WALL_H, thickness)
		MAP_TILE_DATA.DIR_EAST, MAP_TILE_DATA.DIR_WEST:
			box.size = Vector3(thickness, WALL_H, 0.96)
		_:
			return
	mi.mesh = box
	mi.position = _edge_world_position(cell, dir, WALL_H * 0.5)
	mi.material_override = _stone_wall_material()
	_map_dressing_root.add_child(mi)

func _add_exit_dressing(cell: Vector2i, dir: String) -> void:
	var pad := MeshInstance3D.new()
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(0.78, 0.045, 0.78)
	pad.mesh = pad_mesh
	pad.position = _exit_pad_world_position(cell, dir)
	pad.material_override = _exit_material()
	_map_dressing_root.add_child(pad)

	var left := MeshInstance3D.new()
	var right := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.16, 0.62, 0.16)
	left.mesh = post_mesh
	right.mesh = post_mesh
	left.material_override = _stone_wall_material()
	right.material_override = _stone_wall_material()
	var offsets := _exit_post_offsets(dir)
	var base := _edge_world_position(cell, dir, 0.31)
	left.position = base + offsets[0]
	right.position = base + offsets[1]
	_map_dressing_root.add_child(left)
	_map_dressing_root.add_child(right)

func _add_obstacle_dressing(cell: Vector2i) -> void:
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.70, 0.18, 0.70)
	base.mesh = base_mesh
	base.position = _grid_to_world(cell, TILE_H + 0.09)
	base.rotation_degrees.y = float((cell.x * 41 + cell.y * 23) % 25 - 12)
	base.material_override = _rubble_material()
	_map_dressing_root.add_child(base)

	var shard := MeshInstance3D.new()
	var shard_mesh := BoxMesh.new()
	shard_mesh.size = Vector3(0.54, 0.16, 0.18)
	shard.mesh = shard_mesh
	shard.position = _grid_to_world(cell, TILE_H + 0.26) + Vector3(0.07, 0.0, -0.05)
	shard.rotation_degrees = Vector3(0.0, float((cell.x * 29 + cell.y * 17) % 180), 12.0)
	shard.material_override = _rubble_material()
	_map_dressing_root.add_child(shard)

func _add_torch_dressing(cell: Vector2i, dir: String) -> void:
	var root := Node3D.new()
	root.name = "Torch_%d_%d_%s" % [cell.x, cell.y, dir]
	root.position = _edge_world_position(cell, dir, 0.58)
	root.rotation_degrees.y = _wall_yaw_degrees(dir)
	_map_dressing_root.add_child(root)

	var bracket := MeshInstance3D.new()
	var bracket_mesh := CylinderMesh.new()
	bracket_mesh.top_radius = 0.035
	bracket_mesh.bottom_radius = 0.035
	bracket_mesh.height = 0.34
	bracket.mesh = bracket_mesh
	bracket.rotation_degrees.x = 90.0
	bracket.position = Vector3(0.0, 0.0, 0.13)
	bracket.material_override = _torch_bracket_material()
	root.add_child(bracket)

	var cup := MeshInstance3D.new()
	var cup_mesh := CylinderMesh.new()
	cup_mesh.top_radius = 0.09
	cup_mesh.bottom_radius = 0.055
	cup_mesh.height = 0.13
	cup.mesh = cup_mesh
	cup.position = Vector3(0.0, 0.0, 0.31)
	cup.material_override = _torch_bracket_material()
	root.add_child(cup)

	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.12
	flame_mesh.height = 0.28
	flame.mesh = flame_mesh
	flame.position = Vector3(0.0, 0.13, 0.32)
	flame.scale = Vector3(0.72, 1.18, 0.72)
	flame.material_override = _flame_material()
	root.add_child(flame)

	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.16, 0.24)
	light.light_color = Color(1.0, 0.52, 0.18)
	light.light_energy = 3.2
	light.omni_range = 3.2
	light.shadow_enabled = false
	root.add_child(light)
	_start_torch_flicker(light, flame)

func _start_torch_flicker(light: OmniLight3D, flame: MeshInstance3D) -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(light, "light_energy", 2.35, 0.12)
	tween.parallel().tween_property(flame, "scale", Vector3(0.62, 0.98, 0.62), 0.12)
	tween.tween_property(light, "light_energy", 3.85, 0.18)
	tween.parallel().tween_property(flame, "scale", Vector3(0.78, 1.30, 0.78), 0.18)
	tween.tween_property(light, "light_energy", 2.85, 0.10)
	tween.parallel().tween_property(flame, "scale", Vector3(0.70, 1.08, 0.70), 0.10)
	tween.tween_property(light, "light_energy", 3.35, 0.16)
	tween.parallel().tween_property(flame, "scale", Vector3(0.74, 1.20, 0.74), 0.16)

func _edge_world_position(cell: Vector2i, dir: String, y: float) -> Vector3:
	var center := _grid_to_world(cell, y)
	match dir:
		MAP_TILE_DATA.DIR_NORTH:
			return center + Vector3(0.0, 0.0, -0.5)
		MAP_TILE_DATA.DIR_EAST:
			return center + Vector3(0.5, 0.0, 0.0)
		MAP_TILE_DATA.DIR_SOUTH:
			return center + Vector3(0.0, 0.0, 0.5)
		MAP_TILE_DATA.DIR_WEST:
			return center + Vector3(-0.5, 0.0, 0.0)
	return center

func _exit_pad_world_position(cell: Vector2i, dir: String) -> Vector3:
	var center := _grid_to_world(cell, TILE_H + 0.035)
	match dir:
		MAP_TILE_DATA.DIR_NORTH:
			return center + Vector3(0.0, 0.0, -0.86)
		MAP_TILE_DATA.DIR_EAST:
			return center + Vector3(0.86, 0.0, 0.0)
		MAP_TILE_DATA.DIR_SOUTH:
			return center + Vector3(0.0, 0.0, 0.86)
		MAP_TILE_DATA.DIR_WEST:
			return center + Vector3(-0.86, 0.0, 0.0)
	return center

func _grid_to_world(pos: Vector2i, y: float) -> Vector3:
	return Vector3(float(pos.x) * TILE_SIZE, y, float(Pathfinder.BOARD_SIZE - 1 - pos.y) * TILE_SIZE)

func _world_to_grid(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / TILE_SIZE), Pathfinder.BOARD_SIZE - 1 - roundi(pos.z / TILE_SIZE))

func _exit_post_offsets(dir: String) -> Array:
	match dir:
		MAP_TILE_DATA.DIR_NORTH, MAP_TILE_DATA.DIR_SOUTH:
			return [Vector3(-0.40, 0.0, 0.0), Vector3(0.40, 0.0, 0.0)]
		MAP_TILE_DATA.DIR_EAST, MAP_TILE_DATA.DIR_WEST:
			return [Vector3(0.0, 0.0, -0.40), Vector3(0.0, 0.0, 0.40)]
	return [Vector3.ZERO, Vector3.ZERO]

func _wall_yaw_degrees(dir: String) -> float:
	match dir:
		MAP_TILE_DATA.DIR_NORTH:
			return 180.0
		MAP_TILE_DATA.DIR_EAST:
			return -90.0
		MAP_TILE_DATA.DIR_SOUTH:
			return 0.0
		MAP_TILE_DATA.DIR_WEST:
			return 90.0
	return 0.0

func _stone_wall_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.35, 0.34)
	mat.roughness = 0.92
	return mat

func _rubble_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.37, 0.32, 0.25)
	mat.roughness = 0.88
	return mat

func _exit_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.46, 0.22, 0.72)
	mat.emission_enabled = true
	mat.emission = Color(0.22, 0.16, 0.06)
	mat.emission_energy_multiplier = 0.35
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.8
	return mat

func _torch_bracket_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.06)
	mat.metallic = 0.7
	mat.roughness = 0.35
	return mat

func _flame_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.46, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.36, 0.04)
	mat.emission_energy_multiplier = 4.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _build_units() -> void:
	_player_mis.clear()
	for i in range(4):
		var player_mi := _unit_mesh(_player_colors[i], "P%d" % (i + 1), Color(1.0, 1.0, 0.15))
		player_mi.visible = false
		add_child(player_mi)
		_player_mis.append(player_mi)
	_enemy_mis.clear()
	for i in range(3):
		var enemy_mi := _unit_mesh(_enemy_colors[i], str(i + 1), Color(1.0, 0.88, 0.70))
		var area := Area3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.9, UNIT_H + 0.35, 0.9)
		shape.shape = box
		area.input_event.connect(_on_enemy_event.bind(i))
		enemy_mi.add_child(area)
		area.add_child(shape)
		enemy_mi.visible = false
		add_child(enemy_mi)
		_enemy_mis.append(enemy_mi)

func _unit_mesh(color: Color, label_text: String, label_color: Color) -> MeshInstance3D:
	var mi  := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.58, UNIT_H, 0.58)
	mi.mesh  = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.42
	mat.metallic     = 0.18
	mi.material_override = mat
	var lbl := Label3D.new()
	lbl.text = label_text
	lbl.pixel_size = 0.010
	lbl.font_size = 72
	lbl.outline_size = 6
	lbl.modulate = label_color
	lbl.position = Vector3(0.0, UNIT_H * 0.95, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	mi.add_child(lbl)
	return mi

func _build_camera() -> void:
	_cam            = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size       = ZOOM_MIN
	_cam.current    = true
	_cam.position   = Vector3(5.5, 5.8, 8.06)
	add_child(_cam)
	_cam.look_at(Vector3(2.0, 0.0, 2.0), Vector3.UP)

func _on_tile_event(_cam_node: Camera3D, ev: InputEvent,
		_ep: Vector3, _n: Vector3, _si: int, gpos: Vector2i) -> void:
	if ev is InputEventMouseButton:
		if ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			tile_pressed.emit(gpos)

func _on_enemy_event(_cam_node: Camera3D, ev: InputEvent,
		_ep: Vector3, _n: Vector3, _si: int, enemy_idx: int) -> void:
	if ev is InputEventMouseButton:
		if ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			tile_pressed.emit(_enemy_grid_pos(enemy_idx))
			enemy_pressed.emit(enemy_idx)

func _enemy_grid_pos(enemy_idx: int) -> Vector2i:
	if enemy_idx < 0 or enemy_idx >= _enemy_mis.size():
		return Vector2i(-1, -1)
	var enemy_mi: MeshInstance3D = _enemy_mis[enemy_idx] as MeshInstance3D
	var pos: Vector3 = enemy_mi.position
	return _world_to_grid(pos)

func _start_enemy_target_pulse(enemy_idx: int) -> void:
	if enemy_idx < 0 or enemy_idx >= _enemy_mis.size() or _enemy_target_tweens.has(enemy_idx):
		return
	var mi: MeshInstance3D = _enemy_mis[enemy_idx]
	var tw := create_tween()
	_enemy_target_tweens[enemy_idx] = tw
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mi, "scale", Vector3(1.18, 1.10, 1.18), 0.34)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.34)

func _stop_enemy_target_pulse(enemy_idx: int) -> void:
	if not _enemy_target_tweens.has(enemy_idx):
		return
	var tw: Tween = _enemy_target_tweens[enemy_idx]
	if tw != null:
		tw.kill()
	_enemy_target_tweens.erase(enemy_idx)

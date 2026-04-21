class_name Board3D
extends Node3D

signal tile_pressed(pos: Vector2i)

const TILE_SIZE := 1.0
const TILE_GAP  := 0.07
const TILE_H    := 0.14
const UNIT_H    := 0.82
const ZOOM_MIN  := 5.8
const ZOOM_MAX  := 14.0

var _tile_mats: Array = []
var _player_mis: Array = []
var _enemy_mi: MeshInstance3D
var _cam: Camera3D
var _player_colors := [
	Color(0.22, 0.42, 0.88),
	Color(0.16, 0.62, 0.46),
	Color(0.72, 0.42, 0.92),
	Color(0.88, 0.66, 0.20),
]

# ── Public API ───────────────────────────────────────────────────────────────

func setup() -> void:
	_build_environment()
	_build_light()
	_build_tiles()
	_build_units()
	_build_camera()
	update_board([], Vector2i(-1, -1), [], -1)

func adjust_zoom(factor: float) -> void:
	_cam.size = clampf(_cam.size / factor, ZOOM_MIN, ZOOM_MAX)

func get_zoom_size() -> float:
	return _cam.size

func set_zoom_size(size: float) -> void:
	_cam.size = clampf(size, ZOOM_MIN, ZOOM_MAX)

func update_board(player_positions: Array, enemy_pos: Vector2i, highlighted: Array, active_player_idx: int = -1) -> void:
	for y in range(5):
		for x in range(5):
			var mat: StandardMaterial3D = _tile_mats[y * 5 + x]
			var gp := Vector2i(x, y)
			if highlighted.has(gp):
				mat.albedo_color = Color(0.08, 0.52, 0.40)
				mat.emission_enabled = true
				mat.emission = Color(0.04, 0.38, 0.28)
				mat.emission_energy_multiplier = 0.6
			else:
				mat.albedo_color = Color(0.20, 0.20, 0.28)
				mat.emission_enabled = false
	for i in range(_player_mis.size()):
		var mi: MeshInstance3D = _player_mis[i]
		var mat := mi.material_override as StandardMaterial3D
		if i < player_positions.size() and player_positions[i] != Vector2i(-1, -1):
			mi.visible = true
			var pp: Vector2i = player_positions[i]
			mi.position = Vector3(float(pp.x), TILE_H + UNIT_H * 0.5, float(pp.y))
			if mat != null:
				mat.emission_enabled = i == active_player_idx
				mat.emission = Color(0.95, 0.90, 0.40)
				mat.emission_energy_multiplier = 1.4 if i == active_player_idx else 0.0
		else:
			mi.visible = false
	if _enemy_mi != null:
		_enemy_mi.visible = enemy_pos != Vector2i(-1, -1)
		if _enemy_mi.visible:
			_enemy_mi.position = Vector3(float(enemy_pos.x), TILE_H + UNIT_H * 0.5, float(enemy_pos.y))

func flash_tile(pos: Vector2i, color: Color) -> void:
	var mat: StandardMaterial3D = _tile_mats[pos.y * 5 + pos.x]
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.0

# ── Animations ───────────────────────────────────────────────────────────────

func animate_player_step(player_idx: int, target_grid: Vector2i) -> void:
	var mi: MeshInstance3D = _player_mis[player_idx]
	await _animate_step_mesh(mi, target_grid)

func animate_enemy_step(target_grid: Vector2i) -> void:
	await _animate_step_mesh(_enemy_mi, target_grid)

func _animate_step_mesh(mi: MeshInstance3D, target_grid: Vector2i) -> void:
	var from := mi.position
	var to   := Vector3(float(target_grid.x), TILE_H + UNIT_H * 0.5, float(target_grid.y))
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
	var world := Vector3(float(from_pos.x), TILE_H + UNIT_H * 0.65, float(from_pos.y))

	var pivot := Node3D.new()
	pivot.position = world
	var dx := float(to_pos.x - from_pos.x)
	var dz := float(to_pos.y - from_pos.y)
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

func animate_enemy_hit() -> void:
	await _animate_hit_mesh(_enemy_mi)

func _animate_hit_mesh(mi: MeshInstance3D) -> void:
	var origin := mi.position

	var shake_fn := func(t: float) -> void:
		mi.position.x = origin.x + sin(t * PI * 6.0) * 0.20 * (1.0 - t)

	var tween := create_tween()
	tween.tween_method(shake_fn, 0.0, 1.0, 0.38)
	await tween.finished
	mi.position = origin

func animate_ranged_attack(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var from_w := Vector3(float(from_pos.x), TILE_H + UNIT_H * 0.72, float(from_pos.y))
	var to_w   := Vector3(float(to_pos.x),   TILE_H + UNIT_H * 0.72, float(to_pos.y))

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
	var world := Vector3(float(target_pos.x), TILE_H + UNIT_H * 0.55, float(target_pos.y))

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

func _build_tiles() -> void:
	var side := TILE_SIZE - TILE_GAP
	for y in range(5):
		for x in range(5):
			var area  := Area3D.new()
			area.position = Vector3(float(x) * TILE_SIZE, 0.0, float(y) * TILE_SIZE)
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
			mat.albedo_color = Color(0.20, 0.20, 0.28)
			mat.roughness    = 0.85
			mi.material_override = mat
			area.add_child(mi)

			_tile_mats.append(mat)
			area.input_event.connect(_on_tile_event.bind(Vector2i(x, y)))

func _build_units() -> void:
	_player_mis.clear()
	for i in range(4):
		var player_mi := _unit_mesh(_player_colors[i], "P%d" % (i + 1), Color(1.0, 1.0, 0.15))
		player_mi.visible = false
		add_child(player_mi)
		_player_mis.append(player_mi)
	_enemy_mi = _unit_mesh(Color(0.82, 0.18, 0.18), "E", Color(1.0, 0.88, 0.70))
	_enemy_mi.visible = false
	add_child(_enemy_mi)

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
	lbl.pixel_size = 0.011
	lbl.font_size = 64
	lbl.outline_size = 8
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
	_cam.position   = Vector3(2.0, 5.8, 9.0)
	add_child(_cam)
	_cam.look_at(Vector3(2.0, 0.0, 2.0), Vector3.UP)

func _on_tile_event(_cam_node: Camera3D, ev: InputEvent,
		_ep: Vector3, _n: Vector3, _si: int, gpos: Vector2i) -> void:
	if ev is InputEventMouseButton:
		if ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			tile_pressed.emit(gpos)

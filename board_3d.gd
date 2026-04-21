class_name Board3D
extends Node3D

signal tile_pressed(pos: Vector2i)
signal enemy_pressed(enemy_idx: int)

const TILE_SIZE := 1.0
const TILE_GAP  := 0.07
const TILE_H    := 0.14
const UNIT_H    := 0.82
const ZOOM_MIN  := 4.5
const ZOOM_MAX  := 14.0

var _tile_mats: Array = []
var _hero_mi:   MeshInstance3D
var _enemy_mis: Array = []   # up to 3 MeshInstance3D
var _cam:       Camera3D
var _enemy_base_colors := [
	Color(0.80, 0.18, 0.18),
	Color(0.82, 0.38, 0.10),
	Color(0.65, 0.10, 0.38),
]
var _targetable_enemy_indices: Array = []
var _active_target_enemy_idx := -1
var _enemy_target_tweens: Dictionary = {}

# ── Public API ───────────────────────────────────────────────────────────────

func setup() -> void:
	_build_environment()
	_build_light()
	_build_tiles()
	_build_units()
	_build_camera()
	update_board(Vector2i(2, 4), [], [])

func adjust_zoom(factor: float) -> void:
	_cam.size = clampf(_cam.size / factor, ZOOM_MIN, ZOOM_MAX)

func get_zoom_size() -> float:
	return _cam.size

func set_zoom_size(size: float) -> void:
	_cam.size = clampf(size, ZOOM_MIN, ZOOM_MAX)

# enemy_positions: Array[Vector2i], one per enemy slot; Vector2i(-1,-1) = hidden
func update_board(hero_pos: Vector2i, enemy_positions: Array, highlighted: Array) -> void:
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
	_hero_mi.position = Vector3(float(hero_pos.x), TILE_H + UNIT_H * 0.5, float(hero_pos.y))
	for i in range(3):
		var mi: MeshInstance3D = _enemy_mis[i]
		if i < enemy_positions.size() and enemy_positions[i] != Vector2i(-1, -1):
			mi.visible = true
			var ep: Vector2i = enemy_positions[i]
			mi.position = Vector3(float(ep.x), TILE_H + UNIT_H * 0.5, float(ep.y))
		else:
			mi.visible = false

func flash_tile(pos: Vector2i, color: Color) -> void:
	var mat: StandardMaterial3D = _tile_mats[pos.y * 5 + pos.x]
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.0

func set_enemy_target_state(selectable_indices: Array, active_enemy_idx: int = -1) -> void:
	_targetable_enemy_indices = selectable_indices.duplicate()
	_active_target_enemy_idx = active_enemy_idx
	for i in range(_enemy_mis.size()):
		var mi: MeshInstance3D = _enemy_mis[i]
		var mat := mi.material_override as StandardMaterial3D
		if mat == null:
			continue
		var base_color: Color = _enemy_base_colors[i]
		mat.albedo_color = base_color
		mat.emission_enabled = false
		mat.emission_energy_multiplier = 0.0
		if _enemy_target_tweens.has(i):
			var running: Tween = _enemy_target_tweens[i]
			if running != null:
				running.kill()
			_enemy_target_tweens.erase(i)
		mi.scale = Vector3.ONE
		if i == _active_target_enemy_idx:
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.92, 0.30)
			mat.emission_energy_multiplier = 2.4
			_start_enemy_target_pulse(i)
		elif _targetable_enemy_indices.has(i):
			mat.emission_enabled = true
			mat.emission = Color(0.95, 0.72, 0.18)
			mat.emission_energy_multiplier = 1.2

func clear_enemy_target_state() -> void:
	set_enemy_target_state([], -1)

# ── Animations ───────────────────────────────────────────────────────────────

func animate_step(is_hero: bool, target_grid: Vector2i, enemy_idx: int = 0) -> void:
	var mi: MeshInstance3D = _hero_mi if is_hero else _enemy_mis[enemy_idx]
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

func animate_hit(is_hero: bool, enemy_idx: int = 0) -> void:
	var mi: MeshInstance3D = _hero_mi if is_hero else _enemy_mis[enemy_idx]
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
	_hero_mi = _unit_mesh(Color(0.22, 0.42, 0.88))
	add_child(_hero_mi)

	_enemy_mis.clear()
	for i in range(3):
		var mi := _unit_mesh(_enemy_base_colors[i])
		var area := Area3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.9, UNIT_H + 0.35, 0.9)
		shape.shape = box
		shape.position = Vector3(0.0, 0.0, 0.0)
		area.input_event.connect(_on_enemy_event.bind(i))
		mi.add_child(area)
		area.add_child(shape)
		var lbl := Label3D.new()
		lbl.text = str(i + 1)
		lbl.pixel_size = 0.011
		lbl.font_size = 64
		lbl.outline_size = 8
		lbl.modulate = Color(1.0, 1.0, 0.15)
		lbl.position = Vector3(0.0, UNIT_H * 0.95, 0.0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		mi.add_child(lbl)
		mi.visible = false
		add_child(mi)
		_enemy_mis.append(mi)

func _unit_mesh(color: Color) -> MeshInstance3D:
	var mi  := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.58, UNIT_H, 0.58)
	mi.mesh  = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness    = 0.42
	mat.metallic     = 0.18
	mi.material_override = mat
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

func _on_enemy_event(_cam_node: Camera3D, ev: InputEvent,
		_ep: Vector3, _n: Vector3, _si: int, enemy_idx: int) -> void:
	if ev is InputEventMouseButton:
		if ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			enemy_pressed.emit(enemy_idx)

func _start_enemy_target_pulse(enemy_idx: int) -> void:
	var mi: MeshInstance3D = _enemy_mis[enemy_idx]
	var tw := create_tween()
	_enemy_target_tweens[enemy_idx] = tw
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(mi, "scale", Vector3(1.18, 1.10, 1.18), 0.34)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.34)

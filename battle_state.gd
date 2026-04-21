class_name BattleState
extends RefCounted

const PlayerStateScript = preload("res://player_state.gd")
const MAP_TILE_DATA = preload("res://map_tile_data.gd")

enum Phase {
	TITLE, SETUP, SELECT, REVEAL, RESOLVE, REFRESH, VICTORY, DEFEAT
}

const MAX_PLAYERS := 4
const MAX_ENEMIES := 3
const PASS_INITIATIVE := 99

const ENEMY_TYPES := ["UndeadSoldier", "UndeadArcher", "BlackKnight", "Nashrat", "AshenSkeleton"]

var player_count: int = 1
var players: Array = []
var enemies: Array = []
var selected_planning_player_index: int = 0
var active_map_tile_id: String = MAP_TILE_DATA.DEFAULT_TILE_ID

var current_phase: Phase = Phase.TITLE
var round_number: int = 0
var combat_log: Array = []

static func enemy_base_stats(enemy_type: String) -> Dictionary:
	match enemy_type:
		"UndeadSoldier":
			return {"max_hp": 6, "physical_armor": 2, "magic_armor": 0, "xp_reward": 1}
		"UndeadArcher":
			return {"max_hp": 5, "physical_armor": 1, "magic_armor": 0, "xp_reward": 1}
		"BlackKnight":
			return {"max_hp": 12, "physical_armor": 5, "magic_armor": 0, "xp_reward": 2}
		"Nashrat":
			return {"max_hp": 3, "physical_armor": 0, "magic_armor": 0, "xp_reward": 1}
		"AshenSkeleton":
			return {"max_hp": 5, "physical_armor": 2, "magic_armor": 0, "xp_reward": 2}
	return {"max_hp": 6, "physical_armor": 0, "magic_armor": 0, "xp_reward": 1}

func setup(p_player_count: int) -> void:
	player_count = clampi(p_player_count, 1, MAX_PLAYERS)
	active_map_tile_id = MAP_TILE_DATA.get_random_tile_id()
	players.clear()
	var spawns := _player_spawn_positions(player_count)
	for i in range(player_count):
		var player = PlayerStateScript.new()
		player.setup_for_battle(i, spawns[i])
		player.draw_to_hand()
		players.append(player)

	enemies.clear()
	var enemy_count := randi_range(1, MAX_ENEMIES)
	var occupied: Array = []
	for player in players:
		occupied.append(player.pos)
	var black_knight_spawned := false
	for i in range(enemy_count):
		var enemy = EnemyState.new()
		enemy.index = i
		var available_types := ENEMY_TYPES.filter(func(t): return t != "BlackKnight" or not black_knight_spawned)
		var et: String = available_types[randi() % available_types.size()]
		if et == "BlackKnight":
			black_knight_spawned = true
		enemy.enemy_type = et
		var stats := enemy_base_stats(et)
		enemy.max_hp = stats["max_hp"]
		enemy.hp = enemy.max_hp
		enemy.physical_armor = stats["physical_armor"]
		enemy.magic_armor = stats["magic_armor"]
		enemy.xp_reward = stats["xp_reward"]
		enemy.block = 0
		enemy.pos = _pick_enemy_spawn(occupied, 3)
		enemy.alive = true
		enemy.draw = BehaviorData.create_deck_for_type(et)
		enemy.draw.shuffle()
		enemy.discard = []
		enemy.revealed = null
		enemies.append(enemy)
		occupied.append(enemy.pos)

	round_number = 0
	selected_planning_player_index = 0
	current_phase = Phase.SETUP
	combat_log.clear()

func _player_spawn_positions(count: int) -> Array:
	var preferred: Array = []
	match count:
		1:
			preferred = [Vector2i(2, 4)]
		2:
			preferred = [Vector2i(1, 4), Vector2i(3, 4)]
		3:
			preferred = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]
		_:
			preferred = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)]
	return _filter_spawn_positions(preferred, count)

func _filter_spawn_positions(preferred: Array, count: int) -> Array:
	var terrain_blocked := MAP_TILE_DATA.get_obstacles(active_map_tile_id)
	var result: Array = []
	for pos in preferred:
		if not terrain_blocked.has(pos):
			result.append(pos)
	for y in range(Pathfinder.BOARD_SIZE - 1, -1, -1):
		for x in range(Pathfinder.BOARD_SIZE):
			if result.size() >= count:
				return result
			var fallback := Vector2i(x, y)
			if not terrain_blocked.has(fallback) and not result.has(fallback):
				result.append(fallback)
	return result

func _pick_enemy_spawn(occupied: Array, desired_min: int) -> Vector2i:
	var terrain_blocked := MAP_TILE_DATA.get_obstacles(active_map_tile_id)
	for min_d in range(desired_min, 0, -1):
		var candidates: Array = []
		for y in range(5):
			for x in range(5):
				var pos := Vector2i(x, y)
				if occupied.has(pos) or terrain_blocked.has(pos):
					continue
				var ok := true
				for blocked in occupied:
					if Pathfinder.manhattan(pos, blocked) < min_d:
						ok = false
						break
				if ok:
					candidates.append(pos)
		if not candidates.is_empty():
			candidates.shuffle()
			return candidates[0]
	for y in range(5):
		for x in range(5):
			var fallback := Vector2i(x, y)
			if not occupied.has(fallback) and not terrain_blocked.has(fallback):
				return fallback
	return Vector2i(2, 0)

func setup_new_encounter() -> void:
	active_map_tile_id = MAP_TILE_DATA.get_random_tile_id()
	_relocate_players_for_active_map()
	enemies.clear()
	var enemy_count := randi_range(1, MAX_ENEMIES)
	var occupied: Array = []
	for player in players:
		if player.alive:
			occupied.append(player.pos)
	var black_knight_spawned_enc := false
	for i in range(enemy_count):
		var enemy = EnemyState.new()
		enemy.index = i
		var available_types := ENEMY_TYPES.filter(func(t): return t != "BlackKnight" or not black_knight_spawned_enc)
		var et: String = available_types[randi() % available_types.size()]
		if et == "BlackKnight":
			black_knight_spawned_enc = true
		enemy.enemy_type = et
		var stats := enemy_base_stats(et)
		enemy.max_hp = stats["max_hp"]
		enemy.hp = enemy.max_hp
		enemy.physical_armor = stats["physical_armor"]
		enemy.magic_armor = stats["magic_armor"]
		enemy.xp_reward = stats["xp_reward"]
		enemy.block = 0
		enemy.pos = _pick_enemy_spawn(occupied, 3)
		enemy.alive = true
		enemy.draw = BehaviorData.create_deck_for_type(et)
		enemy.draw.shuffle()
		enemy.discard = []
		enemy.revealed = null
		enemies.append(enemy)
		occupied.append(enemy.pos)
	log_msg("A new wave of %d enemies approaches!" % enemy_count)

func _relocate_players_for_active_map() -> void:
	var terrain_blocked := MAP_TILE_DATA.get_obstacles(active_map_tile_id)
	var occupied: Array = []
	for player in players:
		if not player.alive:
			continue
		if not terrain_blocked.has(player.pos) and not occupied.has(player.pos):
			occupied.append(player.pos)
			continue
		player.pos = _nearest_open_tile(player.pos, occupied, terrain_blocked)
		occupied.append(player.pos)

func _nearest_open_tile(from: Vector2i, occupied: Array, terrain_blocked: Array) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_dist := 999
	for y in range(Pathfinder.BOARD_SIZE):
		for x in range(Pathfinder.BOARD_SIZE):
			var pos := Vector2i(x, y)
			if occupied.has(pos) or terrain_blocked.has(pos):
				continue
			var dist := Pathfinder.manhattan(from, pos)
			if dist < best_dist:
				best = pos
				best_dist = dist
	if best != Vector2i(-1, -1):
		return best
	return from

func start_next_round() -> void:
	round_number += 1
	log_msg("=== Round %d ===" % round_number)
	current_phase = Phase.SELECT
	selected_planning_player_index = first_editable_player_index()

func reveal_enemy_behaviors() -> void:
	for enemy in enemies:
		if not enemy.alive:
			enemy.revealed = null
			continue
		if enemy.draw.is_empty():
			enemy.draw = enemy.discard.duplicate()
			enemy.discard.clear()
			enemy.draw.shuffle()
		enemy.revealed = enemy.draw.pop_front() if not enemy.draw.is_empty() else null

func end_round_cleanup() -> void:
	current_phase = Phase.REFRESH
	for enemy in enemies:
		enemy.block = 0
		enemy.slow = false
		enemy.entangle = false
		enemy.confused = false
		enemy.hidden = false
		if enemy.revealed != null:
			enemy.discard.append(enemy.revealed)
			enemy.revealed = null
	for player in players:
		player.end_round_cleanup()

func all_living_players_ready() -> bool:
	for player in players:
		if player.alive and not player.ready:
			return false
	return true

func any_player_dead() -> bool:
	for player in players:
		if not player.alive or player.hp <= 0:
			return true
	return false

func all_enemies_dead() -> bool:
	for enemy in enemies:
		if enemy.alive and enemy.hp > 0:
			return false
	return true

func living_players() -> Array:
	var result: Array = []
	for player in players:
		if player.alive:
			result.append(player)
	return result

func living_enemies() -> Array:
	var result: Array = []
	for enemy in enemies:
		if enemy.alive:
			result.append(enemy)
	return result

func build_actor_order(log_passes: bool = true) -> Array:
	var actors: Array = []
	for player in players:
		if not player.alive:
			continue
		if player.selected.is_empty():
			if log_passes:
				log_msg("%s passes." % player.name)
			continue
		actors.append({
			"actor_type": "player",
			"seat_index": player.seat_index,
			"initiative": player.initiative(),
			"tie_priority": 0,
		})
	for enemy in enemies:
		if enemy.alive and enemy.revealed != null:
			actors.append({
				"actor_type": "enemy",
				"enemy_index": enemy.index,
				"seat_index": MAX_PLAYERS + enemy.index,
				"initiative": enemy.revealed.initiative,
				"tie_priority": 1,
			})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["initiative"] != b["initiative"]:
			return a["initiative"] < b["initiative"]
		if a["tie_priority"] != b["tie_priority"]:
			return a["tie_priority"] < b["tie_priority"]
		return a["seat_index"] < b["seat_index"]
	)
	return actors

func first_editable_player_index() -> int:
	for player in players:
		if player.alive and not player.ready:
			return player.seat_index
	return 0

func set_active_planning_player(seat_index: int) -> bool:
	var player = get_player(seat_index)
	if player == null or not player.alive:
		return false
	selected_planning_player_index = seat_index
	return true

func next_unready_player(from_seat: int, direction: int) -> int:
	if players.is_empty():
		return 0
	var count = players.size()
	for offset in range(1, count + 1):
		var idx = posmod(from_seat + direction * offset, count)
		var player = players[idx]
		if player.alive and not player.ready:
			return idx
	return from_seat

func get_player(seat_index: int) -> PlayerState:
	if seat_index < 0 or seat_index >= players.size():
		return null
	return players[seat_index] as PlayerState

func get_enemy(enemy_index: int) -> EnemyState:
	if enemy_index < 0 or enemy_index >= enemies.size():
		return null
	return enemies[enemy_index] as EnemyState

func select_card(player_id: int, hand_index: int) -> bool:
	var player = get_player(player_id)
	if player == null:
		return false
	return player.select_card_by_hand_index(hand_index)

func deselect_card(player_id: int, selected_index: int) -> bool:
	var player = get_player(player_id)
	if player == null:
		return false
	return player.deselect_selected_index(selected_index)

func move_selected_card(player_id: int, selected_index: int, direction: int) -> bool:
	var player = get_player(player_id)
	if player == null:
		return false
	return player.reorder_selected(selected_index, direction)

func set_player_ready(player_id: int, ready: bool) -> bool:
	var player = get_player(player_id)
	if player == null or not player.alive:
		return false
	if ready and player.selected.size() > player.selection_limit():
		return false
	player.ready = ready
	if ready:
		selected_planning_player_index = next_unready_player(player_id, 1)
	return true

func living_player_positions(excluded_seat: int = -1) -> Array:
	var result: Array = []
	for player in players:
		if not player.alive or player.seat_index == excluded_seat:
			continue
		result.append(player.pos)
	return result

func living_enemy_positions(excluded_index: int = -1) -> Array:
	var result: Array = []
	for enemy in enemies:
		if not enemy.alive or enemy.index == excluded_index:
			continue
		result.append(enemy.pos)
	return result

func occupied_positions_for_player(excluded_seat: int) -> Array:
	var blocked = living_player_positions(excluded_seat)
	for enemy_pos in living_enemy_positions():
		blocked.append(enemy_pos)
	return blocked

func apply_damage_player(player: PlayerState, amount: int, attack_type: String = "physical", ignore_block: bool = false) -> int:
	return player.apply_damage(amount, attack_type, ignore_block)

func apply_damage_enemy(enemy: EnemyState, amount: int, attack_type: String = "physical", ignore_block: bool = false) -> int:
	if enemy == null:
		return 0
	return enemy.apply_damage(amount, attack_type, ignore_block)

func log_msg(msg: String) -> void:
	combat_log.append(msg)
	if combat_log.size() > 30:
		combat_log.pop_front()

func to_dict() -> Dictionary:
	var player_data: Array = []
	for player in players:
		player_data.append(player.to_dict())
	var enemy_data: Array = []
	for enemy in enemies:
		enemy_data.append(enemy.to_dict())
	return {
		"player_count": player_count,
		"players": player_data,
		"enemies": enemy_data,
		"selected_planning_player_index": selected_planning_player_index,
		"active_map_tile_id": active_map_tile_id,
		"current_phase": int(current_phase),
		"round_number": round_number,
		"combat_log": combat_log.duplicate(),
	}

func load_from_dict(data: Dictionary) -> void:
	player_count = int(data.get("player_count", player_count))
	players.clear()
	for player_entry in data.get("players", []):
		var player = PlayerStateScript.new()
		player.load_from_dict(player_entry)
		players.append(player)
	enemies.clear()
	for enemy_entry in data.get("enemies", []):
		var enemy = EnemyState.new()
		enemy.load_from_dict(enemy_entry)
		enemies.append(enemy)
	selected_planning_player_index = int(data.get("selected_planning_player_index", selected_planning_player_index))
	active_map_tile_id = String(data.get("active_map_tile_id", active_map_tile_id))
	current_phase = int(data.get("current_phase", int(current_phase)))
	round_number = int(data.get("round_number", round_number))
	combat_log = data.get("combat_log", []).duplicate()

class_name BattleState
extends RefCounted

const PlayerStateScript = preload("res://player_state.gd")

enum Phase {
	TITLE, SETUP, SELECT, REVEAL, RESOLVE, REFRESH, VICTORY, DEFEAT
}

const MAX_PLAYERS := 4
const PASS_INITIATIVE := 99

var player_count: int = 1
var players: Array = []  # Array[PlayerState]
var enemy: EnemyState = null
var enemy_behavior_draw: Array = []
var enemy_behavior_discard: Array = []
var revealed_behavior: BehaviorData = null
var selected_planning_player_index: int = 0

var current_phase: Phase = Phase.TITLE
var round_number: int = 0
var combat_log: Array = []

func setup(p_player_count: int) -> void:
	player_count = clampi(p_player_count, 1, MAX_PLAYERS)
	players.clear()
	for i in range(player_count):
		var player = PlayerStateScript.new()
		player.setup_for_battle(i, _player_spawn_positions(player_count)[i])
		player.draw_to_hand()
		players.append(player)

	enemy = EnemyState.new()
	enemy.hp = 10
	enemy.max_hp = 10
	enemy.block = 0
	enemy.pos = Vector2i(2, 0)
	enemy.slow = false
	enemy.alive = true
	enemy_behavior_draw = BehaviorData.create_enemy_deck()
	enemy_behavior_draw.shuffle()
	enemy_behavior_discard.clear()
	revealed_behavior = null
	round_number = 0
	selected_planning_player_index = 0
	current_phase = Phase.SETUP
	combat_log.clear()

func _player_spawn_positions(count: int) -> Array:
	match count:
		1:
			return [Vector2i(2, 4)]
		2:
			return [Vector2i(1, 4), Vector2i(3, 4)]
		3:
			return [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]
		_:
			return [Vector2i(0, 4), Vector2i(1, 4), Vector2i(3, 4), Vector2i(4, 4)]

func start_next_round() -> void:
	round_number += 1
	current_phase = Phase.REVEAL
	log_msg("=== Round %d ===" % round_number)
	reveal_enemy_behavior()
	current_phase = Phase.SELECT
	selected_planning_player_index = first_editable_player_index()

func reveal_enemy_behavior() -> void:
	if enemy == null or not enemy.alive:
		revealed_behavior = null
		return
	if enemy_behavior_draw.is_empty():
		enemy_behavior_draw = enemy_behavior_discard.duplicate()
		enemy_behavior_discard.clear()
		enemy_behavior_draw.shuffle()
	revealed_behavior = enemy_behavior_draw.pop_front() if not enemy_behavior_draw.is_empty() else null

func end_round_cleanup() -> void:
	current_phase = Phase.REFRESH
	enemy.block = 0
	if revealed_behavior != null:
		enemy_behavior_discard.append(revealed_behavior)
		revealed_behavior = null
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

func enemy_dead() -> bool:
	return enemy == null or not enemy.alive or enemy.hp <= 0

func living_players() -> Array:
	var result: Array = []
	for player in players:
		if player.alive:
			result.append(player)
	return result

func player_initiative(player) -> int:
	return player.initiative()

func enemy_initiative() -> int:
	return revealed_behavior.initiative if revealed_behavior != null else PASS_INITIATIVE

func build_actor_order(log_passes: bool = true) -> Array:
	var actors: Array = []
	for player in players:
		if not player.alive:
			continue
		if player.selected.is_empty():
			# Passing players are deterministic but omitted from actor order.
			if log_passes:
				log_msg("%s passes." % player.name)
			continue
		actors.append({
			"actor_type": "player",
			"seat_index": player.seat_index,
			"initiative": player.initiative(),
			"tie_priority": 0,
		})
	if enemy != null and enemy.alive and revealed_behavior != null:
		actors.append({
			"actor_type": "enemy",
			"seat_index": MAX_PLAYERS,
			"initiative": revealed_behavior.initiative,
			"tie_priority": 1,
		})
	# Deterministic turn order:
	# 1. lower initiative first
	# 2. players beat enemy on ties
	# 3. lower seat index breaks player-vs-player ties
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

func get_player(seat_index: int):
	if seat_index < 0 or seat_index >= players.size():
		return null
	return players[seat_index]

# These command-style helpers are the intended seam for later remote input.
# A future WebRTC transport can validate and forward these calls instead of
# letting UI code mutate player piles directly.
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

func occupied_positions_for_player(excluded_seat: int) -> Array:
	var blocked = living_player_positions(excluded_seat)
	if enemy != null and enemy.alive:
		blocked.append(enemy.pos)
	return blocked

func apply_damage_player(player, amount: int) -> int:
	return player.apply_damage(amount)

func apply_damage_enemy(amount: int) -> int:
	if enemy == null:
		return 0
	return enemy.apply_damage(amount)

func log_msg(msg: String) -> void:
	combat_log.append(msg)
	if combat_log.size() > 30:
		combat_log.pop_front()

func to_dict() -> Dictionary:
	var player_data: Array = []
	for player in players:
		player_data.append(player.to_dict())
	return {
		"player_count": player_count,
		"players": player_data,
		"enemy": enemy.to_dict() if enemy != null else {},
		"enemy_behavior_draw": _behaviors_to_names(enemy_behavior_draw),
		"enemy_behavior_discard": _behaviors_to_names(enemy_behavior_discard),
		"revealed_behavior": "" if revealed_behavior == null else revealed_behavior.behavior_name,
		"selected_planning_player_index": selected_planning_player_index,
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
	if enemy == null:
		enemy = EnemyState.new()
	enemy.load_from_dict(data.get("enemy", {}))
	enemy_behavior_draw = _names_to_behaviors(data.get("enemy_behavior_draw", []))
	enemy_behavior_discard = _names_to_behaviors(data.get("enemy_behavior_discard", []))
	var revealed_name := String(data.get("revealed_behavior", ""))
	revealed_behavior = null if revealed_name == "" else BehaviorData.from_name(revealed_name)
	selected_planning_player_index = int(data.get("selected_planning_player_index", selected_planning_player_index))
	current_phase = int(data.get("current_phase", int(current_phase)))
	round_number = int(data.get("round_number", round_number))
	combat_log = data.get("combat_log", []).duplicate()

func _behaviors_to_names(behaviors: Array) -> Array:
	var names: Array = []
	for behavior in behaviors:
		var typed_behavior: BehaviorData = behavior as BehaviorData
		names.append(typed_behavior.behavior_name)
	return names

func _names_to_behaviors(names: Array) -> Array:
	var behaviors: Array = []
	for behavior_name in names:
		var behavior := BehaviorData.from_name(String(behavior_name))
		if behavior != null:
			behaviors.append(behavior)
	return behaviors

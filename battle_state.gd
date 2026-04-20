class_name BattleState
extends RefCounted

enum Phase {
	TITLE, SETUP, DRAW, SELECT, REVEAL,
	RESOLVE_HERO, RESOLVE_ENEMY, REFRESH, VICTORY, DEFEAT
}

# Hero
var hero_hp: int = 12
var hero_max_hp: int = 12
var hero_block: int = 0
var hero_pos: Vector2i = Vector2i(2, 4)
var hero_bless: bool = false

# Enemies
var enemies: Array = []  # Array[EnemyState]

# Hero deck zones
var hero_draw: Array = []
var hero_hand: Array = []
var hero_selected: Array = []
var hero_discard: Array = []

var current_phase: Phase = Phase.TITLE
var round_number: int = 0
var combat_log: Array = []

func setup() -> void:
	hero_hp = hero_max_hp
	hero_block = 0
	hero_bless = false
	round_number = 0
	combat_log.clear()

	hero_draw = CardData.create_hero_deck()
	hero_hand.clear()
	hero_selected.clear()
	hero_discard.clear()
	hero_draw.shuffle()

	# Random hero spawn
	var all_tiles: Array = []
	for y in range(5):
		for x in range(5):
			all_tiles.append(Vector2i(x, y))
	all_tiles.shuffle()
	hero_pos = all_tiles.pop_front()

	# Spawn 1–3 enemies, each at least 3 tiles from hero and each other
	var enemy_count := randi_range(1, 3)
	enemies.clear()
	var occupied: Array = [hero_pos]
	for i in range(enemy_count):
		var ep := _pick_spawn(occupied, 3)
		var e := EnemyState.new()
		e.index = i
		e.hp = 10
		e.max_hp = 10
		e.block = 0
		e.pos = ep
		e.slow = false
		e.draw = BehaviorData.create_enemy_deck()
		e.draw.shuffle()
		e.revealed = null
		e.discard = []
		enemies.append(e)
		occupied.append(ep)

func _pick_spawn(occupied: Array, desired_min: int) -> Vector2i:
	for min_d in range(desired_min, 0, -1):
		var cands: Array = []
		for y in range(5):
			for x in range(5):
				var p := Vector2i(x, y)
				if occupied.has(p):
					continue
				var ok := true
				for b in occupied:
					if Pathfinder.manhattan(p, b) < min_d:
						ok = false
						break
				if ok:
					cands.append(p)
		if not cands.is_empty():
			cands.shuffle()
			return cands[0]
	# Fallback: any unoccupied tile
	for y in range(5):
		for x in range(5):
			var p := Vector2i(x, y)
			if not occupied.has(p):
				return p
	return Vector2i(0, 0)

func all_enemies_dead() -> bool:
	for e in enemies:
		if e.hp > 0:
			return false
	return true

func draw_hero_hand() -> void:
	while hero_hand.size() < 5:
		if hero_draw.is_empty():
			if hero_discard.is_empty():
				break
			hero_draw = hero_discard.duplicate()
			hero_discard.clear()
			hero_draw.shuffle()
		hero_hand.append(hero_draw.pop_front())

func reveal_enemy_behavior() -> void:
	for e in enemies:
		if e.hp <= 0:
			continue
		if e.draw.is_empty():
			e.draw = e.discard.duplicate()
			e.discard.clear()
			e.draw.shuffle()
		if not e.draw.is_empty():
			e.revealed = e.draw.pop_front()

func enemy_min_initiative() -> int:
	var mn := 99
	for e in enemies:
		if e.hp > 0 and e.revealed != null:
			mn = mini(mn, e.revealed.initiative)
	return mn

func selected_stamina() -> int:
	var total := 0
	for card in hero_selected:
		total += (card as CardData).cost
	return total

func hero_initiative() -> int:
	if hero_selected.is_empty():
		return 99
	return (hero_selected[0] as CardData).initiative

func can_select(card: CardData) -> bool:
	if hero_selected.size() >= 3:
		return false
	if selected_stamina() + card.cost > 3:
		return false
	return true

func select_card(card: CardData) -> bool:
	if not can_select(card):
		return false
	hero_hand.erase(card)
	hero_selected.append(card)
	return true

func deselect_card(card: CardData) -> void:
	hero_selected.erase(card)
	hero_hand.append(card)

func reorder_selected(index: int, direction: int) -> void:
	var target := index + direction
	if target < 0 or target >= hero_selected.size():
		return
	var tmp = hero_selected[index]
	hero_selected[index] = hero_selected[target]
	hero_selected[target] = tmp

func refresh() -> void:
	hero_block = 0
	for e in enemies:
		e.block = 0
		if e.revealed != null:
			e.discard.append(e.revealed)
			e.revealed = null
	for card in hero_selected:
		hero_discard.append(card)
	hero_selected.clear()
	draw_hero_hand()

func apply_damage_hero(amount: int) -> int:
	var absorbed := mini(hero_block, amount)
	hero_block -= absorbed
	var actual := amount - absorbed
	hero_hp = maxi(hero_hp - actual, 0)
	return actual

func apply_damage_enemy(e: EnemyState, amount: int) -> int:
	var absorbed := mini(e.block, amount)
	e.block -= absorbed
	var actual := amount - absorbed
	e.hp = maxi(e.hp - actual, 0)
	return actual

func log_msg(msg: String) -> void:
	combat_log.append(msg)
	if combat_log.size() > 30:
		combat_log.pop_front()

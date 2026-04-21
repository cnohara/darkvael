# Darkvael Code Notes

This is a Godot 4.6 GL Compatibility prototype for a single-battle tactical card game. The main project root is this `darkvael/` folder, and `project.godot` launches `res://Main.tscn`.

## Current Game State

- Entry point: `main.gd` creates a shared `SessionManager`, applies the UI theme, shows the title screen, and swaps between title, lobby, and battle scenes.
- Modes: single player, local multiplayer for 2-4 players, and prototype online host/join for 2 players.
- Board: a 5x5 tactical grid rendered in `Board3D` with simple 3D tile/unit meshes, orthographic camera, wheel/pinch zoom, highlighted movement tiles, and clickable enemy targets.
- Battle loop: setup, planning/select, reveal, resolve, refresh, victory, defeat.
- Planning: each living player has their own hand, selected row, ready button, and stamina budget.
- Resolution: actors are ordered by ascending initiative. Player actors win initiative ties over enemies, then lower seat/enemy index wins.
- Win/loss: victory when all enemies are dead; defeat when any player dies.
- Online play: the host is authoritative. The host pushes serialized battle snapshots, while the guest sends commands for card selection, ready state, movement destinations, and attack targets.

## Core Files

- `Main.tscn` / `main.gd`: app boot, scene switching, fullscreen toggle, global theme.
- `TitleScreen.tscn` / `title_screen.gd`: mode selection and online host/join inputs.
- `LobbyScene.tscn` / `lobby_scene.gd`: room-code lobby for online games.
- `BattleScene.tscn` / `battle_scene.gd`: main combat UI, round flow, card/effect resolution, targeting, online command handling.
- `board_3d.gd`: 5x5 3D board, unit meshes, click handling, zoom, and combat animations.
- `battle_state.gd`: serializable battle model, player/enemy setup, phases, actor ordering, queries.
- `player_state.gd`: player resources, hand/selected/discard logic, damage, status serialization.
- `enemy_state.gd`: enemy HP/block/status, behavior deck state, serialization.
- `card_data.gd`: hero card definitions.
- `behavior_data.gd`: enemy behavior card definitions.
- `pathfinder.gd`: grid reachability, pathfinding, neighbors, Manhattan distance.
- `session_manager.gd`: Godot HTTP client wrapper for online room state and commands.
- `tools/online_room_server.py`: local threaded HTTP room server.
- `tools/start_online_tunnel.sh`: starts the room server and Cloudflare Quick Tunnel.
- `ONLINE_PLAY.md`: online setup instructions.

## Player Characters

The code currently has one implemented hero type:

| Character | Count | HP | Stamina | Hand | Selected Cards | Spawn Logic | Status |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Cleric | 1-4 player seats | 12/12 | 3 per planning round | Draw to 5 | Up to 3 | Seats spawn along bottom row based on player count | Can gain Bless; dies at 0 HP |

Player spawn positions are:

- 1 player: `(2, 4)`
- 2 players: `(1, 4)`, `(3, 4)`
- 3 players: `(1, 4)`, `(2, 4)`, `(3, 4)`
- 4 players: `(0, 4)`, `(1, 4)`, `(3, 4)`, `(4, 4)`

All player seats currently use the same Cleric deck.

## Cleric Cards

Defined in `card_data.gd` via `CardData.create_hero_deck()`.

| Card | Cost | Initiative | Text | Effects |
| --- | ---: | ---: | --- | --- |
| Crushing Strike | 1 | 5 | Melee attack 4 | Attack 4, range 1 |
| Mend | 2 | 5 | Heal self 3 | Heal 3 |
| Fortify | 1 | 5 | Gain Block 4 | Block 4 |
| Evade | 1 | 6 | Move 2, Gain Block 1 | Move 2; Block 1 |
| Healing Light | 1 | 4 | Heal 2, gain Bless | Heal 2; gain Bless |
| Divine Smite | 2 | 7 | Rng3 atk 3, Slow | Attack 3, range 3; apply Slow |
| Sacred Barrier | 1 | 4 | Gain Block 2 | Block 2 |
| Quiet Petition | 1 | 5 | Heal self 2 | Heal 2 |
| Votive Step | 1 | 6 | Move 3 | Move 3 |
| Guiding Chant | 1 | 4 | Block 2, Move 1 | Block 2; Move 1 |

Player card details:

- The first selected card determines player initiative for the round.
- Selected cards are resolved left to right.
- Selected cards are discarded during round cleanup.
- If the draw pile is empty, discard is shuffled back into draw.
- Bless adds +2 to the next player attack, then clears.
- Slow is applied to the nearest living enemy when the Slow effect resolves.

## Enemies

The code currently has generic enemies, not separate enemy classes.

| Enemy | Count | HP | Behavior Deck | Spawn Logic | Status |
| --- | ---: | ---: | --- | --- | --- |
| Enemy 1-3 | Random 1-3 per battle | 10/10 | Shared 3-card behavior deck | Random unoccupied 5x5 tile, preferring distance 3+ from occupied units | Can gain Slow; dies at 0 HP |

Enemy details:

- Each enemy gets its own shuffled copy of the enemy behavior deck.
- At reveal, each living enemy draws one behavior. If draw is empty, discard is shuffled back into draw.
- Revealed behaviors are discarded during round cleanup.
- Enemy block clears during round cleanup.
- Slow reduces `move_toward` and `lunge` movement by 1 for that round, then clears at the end of the round.
- Enemy targeting is deterministic: nearest living player by Manhattan distance, with lower player seat index winning ties.

## Enemy Behavior Cards

Defined in `behavior_data.gd` via `BehaviorData.create_enemy_deck()`.

| Behavior | Initiative | Text | Effects |
| --- | ---: | --- | --- |
| Advance & Strike | 5 | Move 2, atk 2 if adj | Move toward nearest player 2; attack 2 if adjacent |
| Guarded March | 4 | Block 2, move 1 toward | Block 2; move toward nearest player 1 |
| Lunge | 7 | Atk 3 if adj, else move 2 | If adjacent, attack 3; otherwise move toward nearest player 2 |

## Combat Rules In Code

- Movement uses `Pathfinder.get_reachable()` and `find_path()` over orthogonal 5x5 grid movement.
- Players cannot move through living players or living enemies.
- Enemies move one step at a time toward the nearest living player using the neighbor that strictly reduces Manhattan distance.
- Player attacks choose from living enemies within Manhattan range. If multiple enemies are in range, the player must target an enemy by clicking/tapping; the first click marks the active target and the second confirms.
- Enemy attacks only hit if adjacent by Manhattan distance.
- Damage is reduced by block before HP loss.
- Block is not capped.
- Healing is capped at max HP.

## UI And Controls

- Title screen supports single player, local multiplayer, host online, join online, and quit.
- In planning, click hand cards to select and click selected cards to deselect.
- Selected card arrow buttons reorder card execution order.
- Ready/Unready toggles player planning state.
- Keyboard shortcuts in planning: `1`-`5` select active player hand slots, `Tab` cycles unready players, `Enter` toggles ready.
- `F11` toggles fullscreen/maximized.
- Board zoom supports mouse wheel and magnify gestures.

## Online Architecture

- `SessionManager.DEFAULT_SERVER_URL` is `http://127.0.0.1:8787`.
- Host creates a room and receives seat `0`; guest joins by room code and receives seat `1`.
- Host starts the match only after a guest joins.
- Guest receives host snapshots from `/api/rooms/state`.
- Guest sends commands to `/api/rooms/command`.
- Host polls `/api/rooms/commands` and applies guest commands to authoritative state.
- Room server keeps rooms in memory and prunes stale rooms after 6 hours.

## Development Notes

- Godot scripts use tabs for indentation.
- Keep game data definitions in `card_data.gd` and `behavior_data.gd` unless there is a reason to migrate to resource files.
- Keep serializable state in `to_dict()` / `load_from_dict()` paths when adding online-visible battle data.
- If adding new card or behavior effect types, update both the data file and the relevant resolver in `battle_scene.gd`.
- If adding new characters, `PlayerState.setup_for_battle()` currently hardcodes `hero_type = "Cleric"` and `CardData.create_hero_deck()`.
- If adding new enemy types, `BattleState.setup()` currently creates generic `EnemyState` instances with fixed 10 HP and the shared `BehaviorData.create_enemy_deck()`.

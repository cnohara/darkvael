# Darkvael Code Notes

This is a Godot 4.6 GL Compatibility prototype for a tactical card battler. The main project root is this `darkvael/` folder, and `project.godot` launches `res://Main.tscn`.

## Current Game State

- Entry point: `main.gd` configures the window, installs the shared UI theme, creates a `SessionManager`, shows the title screen, and swaps between title, lobby, and battle scenes.
- Modes: single player, local multiplayer for 2-4 players, and prototype online host/join for 2 players.
- Board: a 5x5 tactical grid rendered by `Board3D` with 3D tiles, unit blocks, orthographic camera, mouse-wheel/pinch zoom, movement highlights, target highlights, and simple movement/attack/block/hit animations.
- Battle loop: setup, planning/select, reveal, resolve, refresh, repeated encounters, defeat overlay.
- Planning: each living player has a hand, selected-card row, Ready button, stamina budget, and independent active-planning focus.
- Round resolution: enemies reveal intent, actors sort by ascending initiative, players win initiative ties over enemies, then lower player/enemy index wins.
- Victory behavior: killing all current enemies starts a new encounter after cleanup and any pending level-ups.
- Defeat behavior: death of any player ends the run and shows the defeat overlay.
- Online play: the host is authoritative. The host serializes battle snapshots, and the guest sends commands for planning input, movement choices, and attack target choices.

## Core Files

- `Main.tscn` / `main.gd`: app boot, scene switching, fullscreen toggle, global theme.
- `TitleScreen.tscn` / `title_screen.gd`: single-player, local multiplayer, online host/join, and quit UI.
- `LobbyScene.tscn` / `lobby_scene.gd`: room-code lobby for online games.
- `BattleScene.tscn` / `battle_scene.gd`: main combat UI, round flow, card/effect resolution, targeting, XP/level-up flow, online command handling.
- `board_3d.gd` (`Board3D`): 5x5 3D board, tile and enemy clicks, unit meshes, zoom, highlights, and combat animations.
- `battle_state.gd` (`BattleState`): serializable battle model, setup, encounters, actor ordering, phase tracking, damage entry points, and queries.
- `player_state.gd` (`PlayerState`): player resources, hand/selected/discard logic, conditions, damage/healing, XP/leveling, serialization.
- `enemy_state.gd` (`EnemyState`): enemy HP, armor, block, conditions, behavior deck state, damage, serialization.
- `card_data.gd` (`CardData`): base cards, Cleric class cards for levels 1-5, rotated card helpers, card lookup/encoding.
- `behavior_data.gd` (`BehaviorData`): enemy-specific behavior decks and behavior lookup.
- `pathfinder.gd` (`Pathfinder`): 5x5 grid reachability, pathfinding, neighbors, Manhattan distance.
- `LevelUpOverlay.tscn` / `level_up_overlay.gd`: modal two-step level-up chooser.
- `EndOverlay.tscn` / `end_overlay.gd`: defeat/restart/title overlay.
- `ui_theme.gd`: shared system-font theme.
- `session_manager.gd`: Godot HTTP wrapper for room hosting, joining, polling, snapshots, and commands.
- `tools/online_room_server.py`: local threaded HTTP room server.
- `tools/start_online_tunnel.sh`: starts the room server and Cloudflare Quick Tunnel.
- `ONLINE_PLAY.md`: online setup instructions.

## App And Scene Flow

- `_ready()` in `main.gd` maximizes the window outside headless mode, sets a minimum size of `1280x800`, installs `UITheme`, creates `SessionManager`, then shows `TitleScreen`.
- `F11` toggles fullscreen/maximized from anywhere.
- Starting a local battle instantiates `BattleScene`, calls `configure_battle(player_count)`, applies the theme, and listens for `return_to_title`.
- Hosting or joining online calls `SessionManager.host_room()` or `join_room()`, then opens `LobbyScene` if a room code was obtained.
- The lobby starts an online match only after the host sees a guest connected.
- When `SessionManager.match_started` fires while in the lobby, `main.gd` opens `BattleScene` via `configure_online(session_manager)`.
- Returning to title from an online battle resets the online session.

## Player Characters

The code currently has one implemented hero type: `Cleric`. All player seats use the same starting deck.

| Character | Count | HP | Stamina | Hand | Selected Cards | Level | Status |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Cleric | 1-4 local seats, 2 online seats | 12 base | 3 base | Draw to 5 | Up to 3, or 1 while stunned | Starts at 1, max data through 5 | Bless plus poison/stun/entangle/hidden/confused/burn/immune |

Player spawn positions:

- 1 player: `(2, 4)`
- 2 players: `(1, 4)`, `(3, 4)`
- 3 players: `(1, 4)`, `(2, 4)`, `(3, 4)`
- 4 players: `(0, 4)`, `(1, 4)`, `(3, 4)`, `(4, 4)`

Player resource and deck rules:

- Players draw to 5 cards at battle setup and at round cleanup.
- If the draw pile is empty, discard is shuffled into draw.
- Selecting a card moves it from hand to selected.
- Deselecting a normal card returns it to hand.
- Deselecting a rotated card returns the original card to hand.
- At cleanup, selected normal cards go to discard; selected rotated cards discard their original card.
- Selected stamina cannot exceed `max_stamina`.
- The first selected card determines player initiative.
- Selected cards resolve left to right.
- Stun limits a player to one selected card and clears after that player acts.
- Block resets during round cleanup.
- Entangle, confused, hidden, and damage immunity clear during player cleanup.
- Bless persists until spent by an attack or removed by level-up restoration.
- Poison persists until cleansed; it deals 1 damage at the start of that player's turn.
- Burn stacks; it deals damage equal to current burn at start of turn, then decreases by 1.
- Healing a character with any condition clears all player conditions instead of restoring HP, unless the effect explicitly cleanses first.
- Healing is capped at max HP.
- Player damage is reduced by block; player armor is not currently modeled.
- Damage immunity makes player damage resolve to 0.

## XP And Leveling

- Each killed enemy grants its `xp_reward` to every living player.
- XP thresholds are `[0, 2, 5, 9, 14]`, so levels 2-5 require 2, 5, 9, and 14 total XP.
- Players can level up while `level < 5`.
- Level-up processing happens after a round ends and before a new encounter starts.
- The level-up overlay offers:
  - Option A: `+1 Max HP` and choose 2 class cards.
  - Option B: `+1 Max Stamina` and choose 2 class cards.
  - Option C: choose 3 class cards.
- Chosen class cards are added to the player's discard pile.
- Level-up restores HP to max, clears player conditions, clears Bless, and clears damage immunity.
- If no class cards exist for the next level, the player still levels up and restores.

## Player Cards

`CardData.create_starting_deck("Cleric")` returns the base deck plus Cleric level 1 cards. Base deck cards have `hero_class = "Base"` and `level = 0`.

### Base Deck

| Card | Cost | Init | Text | Implemented Effects |
| --- | ---: | ---: | --- | --- |
| Sidestep Strike | 2 | 5 | Attack 5, Move 3. | Physical melee attack 5; move 3 |
| Shielded Shift | 2 | 5 | Jump 3, Block 3. | Jump currently uses normal movement; block 3 |
| Crushing Strike | 1 | 5 | Attack 6. | Physical melee attack 6 |
| Mend | 2 | 5 | Heal 3 to self or ally, Range 3. | Auto-targets lowest-HP living ally in range, or self |
| Flurry | 2 | 4 | Attack 4 to all adjacent enemies. | Physical AoE adjacent attack 4 |
| Shielded Advance | 2 | 5 | Move 4, Block 3. | Move 4; block 3 |
| Dash Strike | 2 | 5 | Move 4, Attack 5. | Move 4; physical melee attack 5 |
| Fortify | 1 | 5 | Block 4. | Block 4 |
| Evade | 1 | 3 | Move 3. | Move 3 |
| Rejuvenate | 1 | 6 | Heal 4 self. | Heal self 4 |

### Cleric Level 1 Starting Class Cards

| Card | Cost | Init | Text | Implemented Effects |
| --- | ---: | ---: | --- | --- |
| Healing Light | 1 | 4 | Heal 3+Bless self/ally Rng4 | Auto-targeted heal 3 in range 4; grants Bless |
| Divine Smite | 2 | 7 | Magic Atk 5, Rng3, Slow | Magic ranged attack 5; applies Slow |
| Sacred Barrier | 1 | 4 | Block 2 self+adj allies | Block 2 to self and adjacent living allies |
| Quiet Petition | 1 | 5 | Heal 2 self/ally Rng3; Bless if no conditions | Auto-targeted heal 2; grants Bless if target has no conditions after healing/cleansing |
| Votive Step | 1 | 6 | Move 3; adj ally gains Block 2, Move 1 | Move 3; nearest adjacent ally gains Block 2 and may move 1 |
| Guiding Chant | 1 | 4 | Block 2 self/ally Rng3; ally Move 1 | Auto-targeted ally gains Block 2; if not self and not entangled, ally may move 1 |

### Cleric Level 2 Class Cards

| Card | Cost | Init | Text | Implemented Effects |
| --- | ---: | ---: | --- | --- |
| Holy Bolt | 2 | 7 | Attack 5, Range 2. If the target is undead, +2 damage. | Magic ranged attack 5; +2 versus undead |
| Blessed Strike | 2 | 7 | Attack 6, Range 2. Confuse. | Physical ranged attack 6; applies Confused |
| Renew | 2 | 5 | Heal 3 to self and all adjacent allies. Bless to self and one adjacent ally. | Heal 3 self/adjacent allies; Bless self and nearest adjacent ally |
| Chant of Warding | 2 | 5 | Block 2 to all allies in Range 2. Any ally who already has a Bless card gains Block 4 instead. | Block 2 to allies in range; blessed allies get Block 4 |
| Halo Pulse | 2 | 6 | Heal 2 to all adjacent allies. Push 2 adjacent enemies; enemies hitting walls are Stunned. | Heal adjacent allies; push/stun logs as not implemented |
| Burden Breaker | 2 | 5 | Remove 1 condition from self or ally in Range 3, then Heal 3. If 2+ conditions were removed, gain Block 2. | Clears 1 condition, then healing may clear remaining conditions instead of HP; block branch requires removing 2+ but count is 1 |

### Cleric Level 3 Class Cards

| Card | Cost | Init | Text | Implemented Effects |
| --- | ---: | ---: | --- | --- |
| Smite Evil | 3 | 7 | Attack 5, Range 4. If the target is undead, 2x damage. | Magic ranged attack 5; doubles versus undead |
| Sanctuary | 3 | 4 | All allies in Range 3 take no damage this turn. Heal 4 to self and all allies in Range 3. | Applies damage immunity to allies in range; heals allies in range |
| Shield of Faith | 2 | 4 | Block 4 and Bless to self or an ally in Range 3. | Auto-targeted Block 4 and Bless |
| Hymn of Reckoning | 3 | 7 | Attack 5, Range 3. Increase damage by +2 for every Bless card currently held by allies in the party. | Magic ranged attack 5; party Bless bonus is a TODO/no-op |
| Devout Surge | 2 | 6 | Attack 6, Range 3. You may move the target 2 spaces in any direction. | Magic ranged attack 6; forced movement logs as not implemented |
| Invoke Burden | 3 | 5 | All allies in Range 2 gain Block 3. You may move each adjacent enemy 1 space. | Block 3 to allies in range; forced movement logs as not implemented |

### Cleric Level 4 Class Cards

| Card | Cost | Init | Text | Implemented Effects |
| --- | ---: | ---: | --- | --- |
| Divine Intervention | 3 | 4 | Heal 6 to self or ally in Range 4. Remove all conditions. Bless. | Auto-targeted cleanse all, heal 6, Bless |
| Holy Nova | 3 | 6 | Attack 5 to all enemies in Range 2. If an enemy is undead, +2 damage. | Magic AoE range attack; +2 versus undead |
| Repel | 2 | 5 | Push all adjacent enemies 2 spaces. Enemies hitting walls are Stunned. | Forced movement logs as not implemented |
| Manifest Supplication | 3 | 5 | Heal 3 and Block 3 to all allies in Range 3. | Heal 3 and Block 3 to allies in range |
| Incense Nova | 3 | 6 | Attack 4 to all enemies in Range 2. Burn. | Magic AoE range attack 4; applies Burn |
| Liturgical Rush | 2 | 6 | Move 4. Heal 2 to all adjacent allies. Gain Bless. | Move 4; heal adjacent allies; Bless self |

### Cleric Level 5 Class Cards

| Card | Cost | Init | Text | Implemented Effects |
| --- | ---: | ---: | --- | --- |
| Wrath of the Divine | 4 | 7 | Attack 7, Range 4. If the target is undead, +3 damage. | Magic ranged attack 7; +3 versus undead |
| Divine Shield | 3 | 4 | All allies in Range 3 gain Block 5 and cannot take damage this turn. | Block 5 and damage immunity to allies in range |
| Holy Empowerment | 3 | 5 | All allies in Range 3 gain Bless. Heal 3 to all allies in Range 3. | Bless and heal 3 to allies in range |
| Apotheosis Strike | 4 | 7 | Attack 6, Range 3. Increase damage by +2 for every Bless card currently held by allies in the party. | Magic ranged attack 6; party Bless bonus is a TODO/no-op |
| Divine Chorus | 3 | 4 | Heal 4, Block 4, and remove all conditions from all allies in Range 3. | Cleanse all, heal 4, and Block 4 to allies in range |
| Pillar of Burden | 3 | 6 | Attack 5 to all enemies in Range 2. Stun all enemies hit. | Magic AoE range attack 5; applies Stun |

### Rotated Cards

- Every hand card can be rotated into a generated `+1 Move` card or `+1 Block` card.
- Rotated cards cost 1 stamina and inherit the original card's initiative.
- The selected rotated card remembers `rotated_from_name`.
- Rotated card serialization uses `RotatedName<-OriginalName`.
- On cleanup, the original card goes to discard.

## Player Effect Implementation Notes

- `attack`: supports physical/magic damage, melee/ranged targeting, adjacent AoE, all-enemies-in-range AoE, ignore block, undead bonus, undead multiplier, Bless multiplier, and applying conditions.
- Bless currently multiplies raw attack damage by 1.5 and then clears.
- Ranged player attacks exclude adjacent enemies (`dist <= 1`).
- Multi-target player attacks use click/tap targeting when more than one target is valid.
- Targeting requires two taps/clicks: first marks the active target, second confirms.
- `heal`: supports self, auto-selected self-or-ally, adjacent allies, self plus adjacent allies, allies in range, optional cleanse-all, optional Bless, and Bless-if-no-conditions.
- Auto-targeted self-or-ally effects pick the lowest-HP living ally in range, or self if none are found.
- `block`: supports self, self plus adjacent allies, all allies in range with Bless bonus, and auto-selected self-or-ally.
- `move` and `jump`: both use normal pathfinding movement.
- `bless`: applies Bless to resolved ally targets.
- `sanctuary`: applies `damage_immune` to allies in range for the current round.
- `cleanse`: clears a limited number of player conditions, then applies a follow-up heal.
- `push` and `push_target`: currently log that forced movement is not implemented.
- `party_bless_bonus`: currently a TODO/no-op because Bless is tracked as a status, not as held Bless cards.

## Enemies

Encounters contain 1-3 random enemies. Types are chosen from:

- `UndeadSoldier`
- `UndeadArcher`
- `BlackKnight`
- `Nashrat`
- `AshenSkeleton`

Only one `BlackKnight` can spawn in a single encounter. Enemies spawn on random unoccupied 5x5 tiles, preferring positions at least Manhattan distance 3 from all occupied positions.

| Enemy Type | HP | Physical Armor | Magic Armor | XP | Deck |
| --- | ---: | ---: | ---: | ---: | --- |
| UndeadSoldier | 6 | 2 | 0 | 1 | Undead Soldier deck |
| UndeadArcher | 5 | 1 | 0 | 1 | Undead Archer deck |
| BlackKnight | 12 | 5 | 0 | 2 | Black Knight deck |
| Nashrat | 3 | 0 | 0 | 1 | Nashrat deck |
| AshenSkeleton | 5 | 2 | 0 | 2 | Ashen Skeleton deck |

Enemy rules:

- Each enemy has its own shuffled behavior deck.
- At reveal, each living enemy draws one behavior. If draw is empty, discard is shuffled into draw.
- Revealed behaviors are discarded during cleanup.
- Enemy block clears during round cleanup.
- Slow, entangle, confused, and hidden clear during enemy cleanup.
- Poison persists until cleansed; enemies have no enemy-side cleanse effect yet.
- Burn stacks and ticks at start of enemy turn.
- Stun makes an enemy skip its turn and then clears.
- Hidden makes an enemy skip its revealed action, but currently clears only at round cleanup.
- Enemy damage is reduced by block first, then by physical or magic armor.
- Dead enemies stop appearing on the board and are ignored by targeting.
- Enemy target selection prefers nearest living non-hidden player by Manhattan distance, with lower seat index winning ties.

## Enemy Behavior Cards

### Undead Soldier

| Behavior | Init | Text | Implemented Effects |
| --- | ---: | --- | --- |
| Basic Strike | 4 | Move 1, Attack 4 | Move toward preferred attack range; melee attack 4 |
| Entangling Charge | 6 | Move 2, Entangle if adj | Move 2; apply Entangle if adjacent |
| Bomb Toss | 6 | Move 2, AoE Atk 4 Rng3 | Move 2; ranged 3x3 AoE attack centered on nearest valid ranged target |
| Poisoned Strike | 5 | Move 2, Attack 4, Poison | Move 2; melee attack 4; apply Poison |
| Soldier Shield Bash | 7 | Move 2, Attack 4, Stun | Move 2; melee attack 4; apply Stun |
| Undead Fury | 7 | Move 1, Attack 3, Poison | Move 1; melee attack 3; apply Poison |

### Undead Archer

| Behavior | Init | Text | Implemented Effects |
| --- | ---: | --- | --- |
| Piercing Shot | 5 | Move 2, Atk 2 Rng5 IgnBlock | Move toward range; ranged attack 2 ignoring block |
| Venomous Strike | 6 | Move 2, Atk 3 Rng4, Poison | Move toward range; ranged attack 3; apply Poison |
| Rapid Volley | 4 | Move 2, Atk 3 Rng4 x2 targets | Move toward range; attack up to 2 ranged targets |
| Hidden Watch | 3 | Hidden | Apply Hidden to self |
| Death's Aim | 5 | Move 1, Atk 4 Rng3 | Move toward range; ranged attack 4 |
| Cursed Barrage | 6 | Move 3, Atk 2 Rng5, Poison | Move toward range; ranged attack 2; apply Poison |

### Black Knight

| Behavior | Init | Text | Implemented Effects |
| --- | ---: | --- | --- |
| Heavy Strike | 6 | Move 1, Atk 4, Block 3 | Move 1; melee attack 4; Block 3 |
| Sweeping Cleave | 5 | Move 3, AoE Atk 4 | Move 3; melee AoE to adjacent targets |
| Knight Shield Bash | 6 | Move 2, Stun if adj | Move 2; apply Stun if adjacent |
| Guard Stance | 8 | Block 5 | Block 5 |
| Executioner's Blow | 5 | Move 2, Atk 4 if target HP<=6 else Atk 2 | Move 2; melee attack based on target HP |
| Dark Lunge | 7 | Move 4, Atk 5 IgnBlock | Move 4; melee attack 5 ignoring block |

### Nashrat

| Behavior | Init | Text | Implemented Effects |
| --- | ---: | --- | --- |
| Scurry Away | 2 | Move 1 away | Move away from nearest player |
| Bite | 3 | Move 1, Attack 1 | Move 1; melee attack 1 |
| Swarm | 4 | Attack 2 | Melee attack 2 if adjacent |
| Frenzied Rush | 3 | Move 2, Attack 1 | Move 2; melee attack 1 |
| Group Distraction | 4 | Attack 1, Poison | Melee attack 1; apply Poison |
| Retreat | 2 | Move 3 away | Move away from nearest player |

### Ashen Skeleton

| Behavior | Init | Text | Implemented Effects |
| --- | ---: | --- | --- |
| Tainted Slash | 5 | Move 2, Attack 4, Burn | Move 2; melee attack 4; apply Burn |
| Cracked Blade | 5 | Move 2, Attack 4 | Move 2; melee attack 4 |
| Splintered Fury | 7 | Move 3, Attack 2 twice | Move 3; two melee hits, split across two adjacent targets when possible |
| Boneguard | 4 | Block 3 | Block 3 |
| Fire Arrow | 6 | Atk 3 Rng3, Burn | Ranged attack 3; apply Burn |
| Death Rattle | 5 | Attack 4, Entangle | Melee attack 4; apply Entangle |

## Combat And Movement Rules

- The board is fixed at 5x5.
- Movement and pathfinding are orthogonal.
- `Pathfinder.get_reachable()` allows units to pass through occupied tiles but forbids ending on blocked tiles.
- `Pathfinder.find_path()` also permits passing through blocked tiles but rejects blocked destinations.
- Player movement uses highlighted reachable destination tiles and waits for tile input.
- Enemy movement chooses a reachable tile that best approaches the preferred distance for its next attack/effect.
- Ranged enemy movement uses the upcoming ranged attack range as preferred distance.
- Melee and adjacency-condition enemy movement uses preferred distance 1.
- Enemy `move_away` chooses the reachable tile farthest from the nearest living player.
- Enemy ranged attacks require distance greater than 1 and less than or equal to range.
- Enemy melee attacks require adjacency.
- Ranged AoE attacks affect a 3x3 square around the chosen target position.
- `ignore_block` bypasses block but still uses armor for enemies.
- Block is not capped.
- Physical/magic armor applies only to enemies.

## Conditions

Player and enemy state supports:

- `Bless`: player-only status that boosts the next attack by 1.5x, then clears.
- `Poison`: start-of-turn damage 1.
- `Burn`: start-of-turn damage equal to stacks, then stacks decrease by 1.
- `Stun`: players can select/resolve only 1 card; enemies skip their turn.
- `Entangle`: prevents movement.
- `Hidden`: prevents being targeted by enemies/player targeting helpers and makes enemies skip revealed actions.
- `Confused`: tracked and displayed, but no gameplay behavior currently uses it.
- `Slow`: enemy-only movement reduction by 1 for `move_toward` and `move_away`.
- `damage_immune`: player-only status from Sanctuary-style effects; damage resolves to 0 until cleanup.

## UI And Controls

- Title screen supports single player, local multiplayer, host online, join online, and quit.
- Local multiplayer expands to 2, 3, or 4 player buttons.
- Host/join panels accept a server URL; join also accepts a room code.
- Battle top bar shows round, phase, active player, actor order preview, and enemy panels.
- Enemy panels show HP, physical armor, block, status, revealed intent, draw/discard counts, and XP reward.
- Player panels show name/class, HP, block, status, level, XP, deck counts, initiative, stamina, selected cards, hand cards, and Ready button.
- Hand cards can be clicked to select.
- Selected cards can be clicked to deselect.
- Selected card arrow buttons reorder execution order.
- Rotate buttons under each hand card create `+1 Move` or `+1 Block` rotated cards.
- Ready/Unready toggles player planning state.
- `Prev Player` / `Next Player` cycle among unready living players.
- Keyboard shortcuts during unlocked planning:
  - `1`-`5`: select active player's hand slots.
  - `Tab`: focus next unready player.
  - `Enter` / keypad Enter: toggle active player ready.
- Board zoom supports mouse wheel and magnify gestures.
- Board tiles are clickable during movement prompts.
- Enemy units and enemy panels are clickable during attack targeting.
- The combat log shows the latest 8 messages and auto-scrolls.
- HP, block, status, and stamina labels pulse when their values change.
- Targetable enemies are highlighted on both board and panel; the active target pulses.

## Online Architecture

- `SessionManager.DEFAULT_SERVER_URL` is `http://127.0.0.1:8787`.
- Online mode is fixed to 2 players.
- Host receives seat `0`; guest receives seat `1`.
- Host creates a room with `POST /api/rooms/host`.
- Guest joins with `POST /api/rooms/join`.
- Host starts the match with `POST /api/rooms/start`.
- Both sides poll `GET /api/rooms/state` every 0.45 seconds.
- Host additionally polls `GET /api/rooms/commands`.
- Host snapshots are pushed to `POST /api/rooms/snapshot`.
- Guest commands are sent to `POST /api/rooms/command`.
- The room server stores host and guest tokens, started/guest flags, the latest snapshot, a revision number, and a command queue.
- Rooms are in memory only and prune after 6 hours of staleness.
- `start_online_tunnel.sh` runs the Python room server and exposes it with a Cloudflare Quick Tunnel.

Online battle sync details:

- Host serializes `BattleState.to_dict()` plus highlighted tiles, pending movement seat, pending attack seat, targetable enemy indices, and active target index.
- Guest loads snapshots with `BattleState.load_from_dict()` and mirrors pending input state.
- Guest can only edit its owned seat.
- Guest sends commands for `select_card`, `deselect_card`, `move_selected_card`, `rotate_card`, `set_ready`, `choose_move_destination`, and `choose_attack_target`.
- Host applies guest commands to authoritative state, then updates UI and snapshots.
- Guest cannot press Next Round; the host controls refresh-to-next-round progression.

## Serialization

- `BattleState.to_dict()` serializes player count, players, enemies, selected planning player, phase, round number, and combat log.
- `PlayerState.to_dict()` serializes identity, level/XP/resources, position, deck zones, readiness, alive state, Bless, conditions, burn, and damage immunity.
- `EnemyState.to_dict()` serializes type, HP, armor, XP reward, position, alive state, behavior zones, revealed behavior name, and conditions.
- Cards serialize by card name, with rotated cards encoded as `+1 Move<-Original` or `+1 Block<-Original`.
- Behaviors serialize by behavior name and are restored against the owning enemy type's deck.

## Known Gaps And TODOs

- `jump` currently uses normal movement and does not ignore pathing.
- Forced movement effects (`push`, `push_target`) are not implemented.
- Wall-collision stun for forced movement is not implemented.
- `party_bless_bonus` is a TODO/no-op because Bless is tracked as a status, not as Bless cards held by allies.
- `Confused` is tracked and displayed but has no behavior yet.
- Enemy-side cleansing does not exist.
- There is no victory overlay for clearing an encounter; victory immediately transitions toward a new wave.
- Online level-up is risky for guests because the host-owned battle resolves and displays level-up overlays on the host side.

## Development Notes

- Godot scripts use tabs for indentation.
- Keep game data definitions in `card_data.gd` and `behavior_data.gd` unless there is a reason to migrate to resource files.
- When adding online-visible battle data, update all `to_dict()` / `load_from_dict()` paths and host snapshot fields if needed.
- When adding new card effect types, update `CardData`, `_resolve_player_effect()`, and the known gaps section above.
- When adding new enemy behavior effect types, update `BehaviorData`, `_resolve_enemy_effect()`, and any movement/targeting helpers.
- If adding new characters, `PlayerState.setup_for_battle()` currently hardcodes `hero_type = "Cleric"`.
- If adding new enemy types, update `BattleState.ENEMY_TYPES`, `BattleState.enemy_base_stats()`, `BehaviorData.create_deck_for_type()`, `BehaviorData.from_name()`, and any undead/type-specific logic.
- If changing online commands, update both guest send paths and host `_on_online_command_received()`.
- If changing player movement blocking rules, update both `Pathfinder` comments and `BattleState.occupied_positions_for_player()`.

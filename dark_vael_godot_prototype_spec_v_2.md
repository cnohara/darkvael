# DarkVael Godot Prototype Spec

## Purpose
Build a **fully playable single-battle prototype** in Godot that captures the core feel of DarkVael combat in the smallest useful scope.

This is **not** a full game, not a dungeon run, and not a content-generation project. It is a **single tactical combat sandbox** with one hero, one enemy, one room, and a complete round loop.

The goal is to prove that these core systems feel good together:
- visible hand of cards
- select up to 3 cards
- reorder selected cards
- enemy behavior reveal
- initiative-driven action order
- movement on a 5x5 grid
- attacks, healing, block, Bless, Slow
- win/loss flow

---

## Scope

### In scope
- 1 hardcoded battle scene
- 1 hardcoded 5x5 room
- 1 hero: Cleric
- 1 enemy: Undead Soldier
- 10 hero cards
- 3 enemy behavior cards
- title screen
- battle scene
- victory/defeat overlay
- mouse-first controls
- **zero external assets required**
- **zero user-provided assets required**
- **fully playable using only Godot-built UI shapes, labels, and theme styling**

### Out of scope
Do **not** implement any of the following in this prototype:
- procedural map generation
- AI-generated maps
- AI-generated cards
- AI-generated characters
- AI-generated art
- externally provided art assets as a requirement
- multiple rooms
- map progression
- loot
- XP or leveling
- multiple heroes
- multiple enemies
- multiplayer
- obstacles or walls
- line of sight
- deckbuilder screen
- save/load system
- settings menu
- controller support
- web-specific work
- ornate visual polish

---

## Target Platform
- Build as a **desktop Godot app** first.
- Primary control method is **mouse**.
- Keyboard shortcuts are optional quality-of-life only.

### Required controls
- Click cards to select/deselect
- Click arrow buttons to reorder selected cards
- Click Confirm to lock the round
- Click highlighted board tile to choose movement destination
- Click menu buttons on title / end screens

### Optional keyboard shortcuts
- `1-5`: toggle hand cards by slot
- `Enter`: confirm selection
- `Esc`: cancel current sub-selection or close overlay

Do not require full keyboard-only support for MVP.

---

## Core Player Experience
The player should be able to:
1. Start the battle
2. See the board, hero, enemy, hand, and stats
3. Select 0 to 3 cards from hand
4. Reorder selected cards
5. See stamina total and projected initiative before confirming
6. Confirm the round
7. See the enemy behavior card revealed
8. Watch initiative determine who acts first
9. If a move card resolves, click a highlighted valid destination tile
10. Watch attacks, healing, block, and status effects resolve
11. Repeat until victory or defeat

---

## Screen Flow

### 1. Title Screen
Contains:
- Title: `DarkVael Prototype`
- `Start Battle` button
- `Quit` button
- One-line controls hint:
  - `Click cards to select. Click highlighted tiles to move. Confirm to resolve the round.`

### 2. Battle Screen
Contains:
- Round counter
- Hero panel
- Enemy panel
- 5x5 battle board
- Enemy behavior reveal zone
- Selected card row (3 slots)
- Hand row (up to 5 cards)
- Stamina display
- Initiative display
- Confirm button
- Combat log

### 3. End Overlay
Shown on victory or defeat.
Contains:
- `Victory` or `Defeat`
- `Restart Battle`
- `Return to Title`

### Asset requirement for all screens
All screens must be built without requiring imported art assets.
Use only:
- Godot `ColorRect`
- Godot `Panel` / `PanelContainer`
- Godot `Label` / `RichTextLabel`
- Godot `Button`
- simple drawn circles/rectangles or theme-styled controls

The prototype must remain fully playable even if there are **no image files at all** in the project.

---

## Battle State Machine
Use these states:
- `TITLE`
- `SETUP`
- `DRAW`
- `SELECT`
- `REVEAL`
- `RESOLVE_HERO`
- `RESOLVE_ENEMY`
- `REFRESH`
- `VICTORY`
- `DEFEAT`

### Flow
- `TITLE -> SETUP -> DRAW -> SELECT -> REVEAL`
- If hero acts first:
  - `REVEAL -> RESOLVE_HERO -> RESOLVE_ENEMY -> REFRESH`
- If enemy acts first:
  - `REVEAL -> RESOLVE_ENEMY -> RESOLVE_HERO -> REFRESH`
- Repeat until `VICTORY` or `DEFEAT`

### Interaction lock rules
- In `SELECT`: hand and selected row are interactive
- In move-targeting mode: only highlighted legal destination tiles are interactive
- During `REVEAL`, `RESOLVE_HERO`, `RESOLVE_ENEMY`, `REFRESH`: battle planning UI is locked

---

## Board Rules

### Grid
- Board size: **5 columns x 5 rows**
- Coordinates run from `(0,0)` at top-left to `(4,4)` at bottom-right
- The room is **not generated**
- The room is a single hardcoded empty 5x5 combat board

### Starting positions
- Hero starts at `(2,4)`
- Enemy starts at `(2,0)`

### Movement rules
- Orthogonal movement only
- No diagonal movement
- Cannot leave the board
- Cannot move through occupied tiles
- Cannot end on occupied tiles
- No obstacles in MVP

### Range rules
Use **Manhattan distance**:
- Melee range = `1`
- Ranged attack valid if `distance <= attack_range`

### Board visual implementation
The board must be rendered using built-in Godot UI or drawing primitives only.
Recommended implementation:
- 25 square tiles laid out in a 5x5 grid
- each tile is a `Button`, `Panel`, or custom-drawn square
- normal tiles have a neutral color
- highlighted movement tiles change color
- hovered tile may brighten slightly

No tile art files are required.

---

## Units

### Hero: Cleric
- HP: `12`
- Max HP: `12`
- Block: `0`
- Round stamina cap: `3`
- Hand size: `5`
- Statuses used in MVP:
  - Bless

### Enemy: Undead Soldier
- HP: `10`
- Max HP: `10`
- Block: `0`
- Statuses used in MVP:
  - Slow

### Unit visual implementation
Units must not require external sprite assets.
Use one of these approaches:
- a colored circle drawn in code on top of the tile
- a colored `Panel`/`TextureRect` substitute with text label
- a simple token-like marker with initials

Recommended MVP style:
- Hero token: blue or gold circle with label `C`
- Enemy token: red or gray circle with label `U`

The prototype must remain fully readable and playable with these abstract markers only.

---

## Round Structure

### 1. Draw Phase
- Draw hero hand up to 5 cards
- If draw pile runs out during draw, reshuffle discard into draw pile and continue

### 2. Select Phase
Player may:
- Select 0 to 3 cards from hand
- Deselect selected cards
- Reorder selected cards left-to-right

Selection is legal if:
- Selected card count <= 3
- Total stamina cost <= 3

UI must show:
- `Selected: X/3`
- `Stamina: Y/3`
- `Initiative: Z` (from the leftmost selected card)

Confirm rules:
- Confirm is allowed if selection is legal
- Confirming with 0 cards means the hero passes the round

### 3. Reveal Phase
- Reveal 1 enemy behavior card
- Hero initiative = initiative of the **leftmost selected hero card**
- Enemy initiative = initiative of the revealed behavior card
- Lower initiative acts first
- Ties go to hero

### 4. Resolution Phase
- The side with better initiative resolves its **entire action package first**
- Then the other side resolves its action package
- If one side dies during the first package, battle ends immediately and the second package does not occur

### 5. Refresh Phase
- Selected hero cards -> hero discard pile
- Revealed enemy behavior card -> enemy behavior discard pile
- Unselected cards remain in hand
- Draw hero hand back up to 5
- If enemy behavior draw pile is empty next round, reshuffle its discard pile

---

## Card Commitment Rules
Once the player presses Confirm:
- selected cards are locked in
- selected cards are not refunded
- if a card becomes invalid when it resolves, it fizzles but is still spent

This is required to preserve planning tension.

---

## Hero Deck
Use this exact 10-card prototype deck.

### 1. Crushing Strike
- Cost: `1`
- Initiative: `5`
- Effect: Melee attack 4

### 2. Mend
- Cost: `2`
- Initiative: `5`
- Effect: Heal self 3

### 3. Fortify
- Cost: `1`
- Initiative: `5`
- Effect: Gain Block 4

### 4. Evade
- Cost: `1`
- Initiative: `6`
- Effect: Move 2, then gain Block 1

### 5. Healing Light
- Cost: `1`
- Initiative: `4`
- Effect: Heal self 2, then gain Bless

### 6. Divine Smite
- Cost: `2`
- Initiative: `7`
- Effect: Range 3 attack 3, then apply Slow

### 7. Sacred Barrier
- Cost: `1`
- Initiative: `4`
- Effect: Gain Block 2

### 8. Quiet Petition
- Cost: `1`
- Initiative: `5`
- Effect: Heal self 2

### 9. Votive Step
- Cost: `1`
- Initiative: `6`
- Effect: Move 3

### 10. Guiding Chant
- Cost: `1`
- Initiative: `4`
- Effect: Gain Block 2, then Move 1

---

## Enemy Behavior Deck
Use this exact 3-card enemy behavior deck.

### 1. Advance and Strike
- Initiative: `5`
- Effect:
  - Move toward hero up to 2
  - If adjacent after moving, attack 2

### 2. Guarded March
- Initiative: `4`
- Effect:
  - Gain Block 2
  - Move toward hero up to 1

### 3. Lunge
- Initiative: `7`
- Effect:
  - If adjacent, attack 3
  - Else move toward hero up to 2

When behavior deck is empty, reshuffle its discard pile.

---

## Status Rules

### Block
- Damage reduces Block first
- Remaining damage reduces HP
- Block persists until spent

### Bless
- Next **attempted** hero attack gets `+2 damage`
- Bless is then removed, whether the attack hits or fizzles

### Slow
- Next enemy move amount is reduced by `1` (minimum `0`)
- Slow is removed after the enemy behavior resolves

---

## Card Selection Interaction

### Hand display
Show up to 5 cards in the hand row.
Each card must display:
- Card name
- Cost
- Initiative
- One-line effect summary

Cards must be built from Godot UI panels and labels only.
No card art, illustration, or imported frame assets are required.

### Selecting a card
- Clicking a hand card adds it to the next open selected slot if legal
- If adding the card would exceed stamina cap, reject the click and flash/shake the card red

### Deselecting a card
- Clicking a selected card removes it back to the hand row

### Reordering selected cards
For MVP, each selected card should have small `Left` and `Right` arrow buttons.
- Clicking arrows swaps the card with its neighbor
- Drag-and-drop is optional later, but not required for MVP

### Passing the round
- Player may confirm with 0 selected cards
- Hero does nothing that round
- Enemy still acts normally

### Card visual implementation
Recommended card layout:
- top row: card name
- small badges or labels for `Cost` and `Init`
- one short rules line under that
- simple panel background color by card type if desired

Cards should prioritize readability over style.
The game must be playable without any art assets.

---

## Movement Interaction
When a move effect resolves:
1. Enter movement targeting mode
2. Compute all legal reachable destination tiles using BFS from the hero’s current tile
3. Highlight only legal tiles
4. Wait for player click on one highlighted tile
5. Compute a shortest valid path to that tile
6. Move the hero along that path
7. Continue resolving the card or next effect

### Important movement rules
- Player chooses only the **destination tile**, not each path step
- The game automatically determines a shortest valid path
- Because there are no obstacles, BFS remains simple
- If no legal tile exists, the move effect fizzles automatically

### Valid destination definition
A tile is a valid movement destination if:
- it is on the board
- it is reachable within the movement allowance
- it is not occupied
- there exists a valid path to it under current occupancy rules

### Interaction rules during movement targeting
- Only highlighted destination tiles are clickable
- Hand and selected-row interactions are disabled
- Confirm button is disabled

---

## Attack Interaction
In this MVP, there is only one enemy.

### Hero attack behavior
When a hero attack effect resolves:
1. Check whether the enemy is in legal range from the hero’s **current** position
2. If legal, automatically target that enemy
3. Apply damage to Block first, then HP
4. Apply any status effects
5. Log the result

### If attack is invalid
- The attack fizzles
- The card is still spent
- Log why it failed, such as:
  - `Crushing Strike fizzled: target not adjacent`
  - `Divine Smite fizzled: target out of range`

### Multi-effect cards
If a card has multiple effects, resolve them in order.
Example:
- `Move 3, then Attack 3`
- The movement destination is chosen first
- Hero moves
- Attack is then checked from the new position

### Enemy attacks
Enemy attacks are fully automatic.
- Enemy behavior determines movement and attack
- Enemy always targets the hero

### Attack feedback
No hit effect assets are required.
Use simple feedback only:
- target tile flashes briefly
- floating damage text is optional
- HP/block numbers update immediately
- combat log records result

---

## Enemy Movement and AI Rules
Use very simple behavior execution.

### Enemy pathing
- Enemy uses shortest path movement toward hero
- Orthogonal movement only
- Cannot move through hero
- Cannot move off board

### Enemy target
- Always the hero

### Behavior resolution
Resolve behavior effects in the listed order.
Examples:
- `Gain Block 2, then Move 1`
- `Move 2, then Attack 2 if adjacent`

### Slow interaction
- If the enemy has Slow, reduce the next movement amount by 1
- Then clear Slow after the behavior resolves

---

## Deck and Discard Rules

### Hero zones
- Draw pile
- Hand
- Selected row
- Discard pile

### Enemy zones
- Behavior draw pile
- Revealed behavior slot
- Behavior discard pile

### Hero refresh rules
- At end of round, selected cards go to discard
- Unselected cards remain in hand
- Draw until hand size is 5
- If draw pile empties during draw, reshuffle discard into draw pile and continue

### Enemy refresh rules
- At end of round, revealed behavior goes to behavior discard
- When behavior draw pile is empty, reshuffle discard into draw pile

### What is shown to player
Show counts for:
- hero draw pile
- hero discard pile
- enemy behavior draw pile
- enemy behavior discard pile

Do not build pile-inspection UI for MVP.
Do not build manual discard actions for MVP.

---

## Visual and Asset Rules

### Absolute requirement
The prototype must be fully playable with **no external assets provided by the user**.

### Do not require
- character sprites
- card art
- tile art
- portraits
- icons from an external asset pack
- sound effects
- animations beyond basic tweens/color flashes

### Build visuals using only Godot-native elements
Use:
- `ColorRect`
- `Panel`
- `PanelContainer`
- `Label`
- `RichTextLabel`
- `Button`
- `HBoxContainer` / `VBoxContainer` / `GridContainer`
- `_draw()` for circles, borders, and simple markers if desired
- built-in font/theme defaults unless the implementer chooses to style them further

### Recommended look
- dark background
- mid-gray board tiles
- highlighted move tiles in teal or green
- hero marker in blue/gold
- enemy marker in red/gray
- readable card panels with light text on dark panels
- simple badges for statuses like `Bless` and `Slow`

### Playability first
The prototype should feel like a clean tactics testbed, not an art showcase.
Logic, readability, and responsiveness matter more than visual polish.

---

## Menus and UI Minimum

### Title screen minimum
- title label
- start button
- quit button
- one-line controls hint

### Battle screen minimum
- board
- hero panel
- enemy panel
- hand row
- selected row
- reveal zone
- confirm button
- round number
- combat log

### End overlay minimum
- victory/defeat label
- restart button
- return to title button

No other menus are required.

---

## Recommended Scene List
- `Main.tscn`
- `TitleScreen.tscn`
- `BattleScene.tscn`
- `CardView.tscn`
- `TileView.tscn`
- `UnitTokenView.tscn`
- `EndOverlay.tscn`

---

## Recommended Script List
- `main.gd`
- `battle_scene.gd`
- `battle_state.gd`
- `card_data.gd`
- `behavior_data.gd`
- `resolver.gd`
- `pathfinder.gd`
- `battle_ui.gd`
- `tile_view.gd`
- `card_view.gd`

---

## Handoff Summary
Build a **desktop Godot prototype** of a single DarkVael-inspired battle.

The prototype must:
- require **zero external art assets**
- require **zero user-provided assets**
- use a **hardcoded 5x5 room**
- use **abstract unit tokens** and **UI-built cards**
- let the player select up to 3 cards, reorder them, confirm, reveal enemy intent, move by clicking highlighted legal tiles, and resolve attacks automatically against the single enemy
- end in victory or defeat and allow restart

The deliverable is a **fully playable combat prototype**, not a polished vertical slice.


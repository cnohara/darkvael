extends Node

const MIN_WINDOW_SIZE := Vector2i(1280, 800)
const DEFAULT_UI_FONT_SIZE := 18

var current_scene: Node = null
var session_manager = null
var app_theme: Theme = null

func _ready() -> void:
	_configure_window()
	_configure_theme()
	session_manager = SessionManager.new()
	add_child(session_manager)
	session_manager.match_started.connect(_on_match_started)
	_show_title()

func _configure_window() -> void:
	DisplayServer.window_set_min_size(MIN_WINDOW_SIZE)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _configure_theme() -> void:
	app_theme = UITheme.create()
	var font := app_theme.default_font
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = DEFAULT_UI_FONT_SIZE
	ThemeDB.fallback_base_scale = 1.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _show_title() -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var scene = load("res://TitleScreen.tscn") as PackedScene
	current_scene = scene.instantiate()
	_apply_scene_theme()
	add_child(current_scene)
	current_scene.start_battle.connect(_show_battle)
	current_scene.host_online_requested.connect(_host_online_game)
	current_scene.join_online_requested.connect(_join_online_game)
	current_scene.quit_requested.connect(_on_quit)

func _show_battle(player_count: int = 1) -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var scene = load("res://BattleScene.tscn") as PackedScene
	current_scene = scene.instantiate()
	current_scene.configure_battle(player_count)
	_apply_scene_theme()
	add_child(current_scene)
	current_scene.return_to_title.connect(_show_title)

func _show_online_battle() -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var scene = load("res://BattleScene.tscn") as PackedScene
	current_scene = scene.instantiate()
	current_scene.configure_online(session_manager)
	_apply_scene_theme()
	add_child(current_scene)
	current_scene.return_to_title.connect(_show_title)

func _show_lobby() -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var scene = load("res://LobbyScene.tscn") as PackedScene
	current_scene = scene.instantiate()
	current_scene.configure(session_manager)
	_apply_scene_theme()
	current_scene.start_requested.connect(_start_online_match)
	current_scene.cancel_requested.connect(_cancel_online_match)
	add_child(current_scene)

func _apply_scene_theme() -> void:
	if current_scene is Control and app_theme != null:
		(current_scene as Control).theme = app_theme

func _host_online_game(server_url: String) -> void:
	await session_manager.host_room(server_url)
	if session_manager.room_code != "":
		_show_lobby()

func _join_online_game(server_url: String, room_code: String) -> void:
	await session_manager.join_room(server_url, room_code)
	if session_manager.room_code != "":
		_show_lobby()

func _start_online_match() -> void:
	await session_manager.start_match()

func _cancel_online_match() -> void:
	session_manager.reset()
	_show_title()

func _on_match_started() -> void:
	if current_scene != null and current_scene.name == "LobbyScene":
		_show_online_battle()

func _on_quit() -> void:
	get_tree().quit()

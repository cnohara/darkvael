extends Node

var current_scene: Node = null
var session_manager = null

func _ready() -> void:
	session_manager = SessionManager.new()
	add_child(session_manager)
	session_manager.match_started.connect(_on_match_started)
	_show_title()

func _show_title() -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var scene = load("res://TitleScreen.tscn") as PackedScene
	current_scene = scene.instantiate()
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
	add_child(current_scene)
	current_scene.return_to_title.connect(_show_title)

func _show_online_battle() -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var scene = load("res://BattleScene.tscn") as PackedScene
	current_scene = scene.instantiate()
	current_scene.configure_online(session_manager)
	add_child(current_scene)
	current_scene.return_to_title.connect(_show_title)

func _show_lobby() -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var scene = load("res://LobbyScene.tscn") as PackedScene
	current_scene = scene.instantiate()
	current_scene.configure(session_manager)
	current_scene.start_requested.connect(_start_online_match)
	current_scene.cancel_requested.connect(_cancel_online_match)
	add_child(current_scene)

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

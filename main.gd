extends Node

var current_scene: Node = null

func _ready() -> void:
	_show_title()

func _show_title() -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var scene = load("res://TitleScreen.tscn") as PackedScene
	current_scene = scene.instantiate()
	add_child(current_scene)
	current_scene.start_battle.connect(_show_battle)
	current_scene.quit_requested.connect(_on_quit)

func _show_battle() -> void:
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	var scene = load("res://BattleScene.tscn") as PackedScene
	current_scene = scene.instantiate()
	add_child(current_scene)
	current_scene.return_to_title.connect(_show_title)

func _on_quit() -> void:
	get_tree().quit()

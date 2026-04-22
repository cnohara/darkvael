@tool
extends EditorPlugin

var _dock: Control

func _enter_tree() -> void:
	var dock_script := load("res://addons/prop_browser/prop_browser_dock.gd")
	_dock = dock_script.new()
	_dock.editor_interface = get_editor_interface()
	add_control_to_dock(DOCK_SLOT_LEFT_BR, _dock)

func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

class_name SessionManager
extends Node

signal room_hosted(room_code: String)
signal room_joined(room_code: String, seat_index: int)
signal room_state_updated(room_state: Dictionary)
signal guest_joined()
signal match_started()
signal command_received(command: Dictionary)
signal request_failed(message: String)

const DEFAULT_SERVER_URL := "http://127.0.0.1:8787"

var backend_url := DEFAULT_SERVER_URL
var room_code := ""
var session_token := ""
var seat_index := 0
var role := "local"
var player_count := 1
var started := false
var guest_present := false
var last_revision := -1
var _last_command_id := 0
var _poll_timer: Timer
var _last_snapshot_json := ""

func _ready() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.45
	_poll_timer.one_shot = false
	_poll_timer.timeout.connect(_on_poll_timeout)
	add_child(_poll_timer)

func reset() -> void:
	room_code = ""
	session_token = ""
	seat_index = 0
	role = "local"
	player_count = 1
	started = false
	guest_present = false
	last_revision = -1
	_last_command_id = 0
	_last_snapshot_json = ""
	_poll_timer.stop()

func is_online() -> bool:
	return role == "host" or role == "guest"

func is_host() -> bool:
	return role == "host"

func is_guest() -> bool:
	return role == "guest"

func host_room(server_url: String) -> void:
	reset()
	backend_url = _normalize_server_url(server_url)
	var response := await _request_json(HTTPClient.METHOD_POST, "/api/rooms/host", {})
	if response.is_empty():
		return
	room_code = String(response.get("room_code", ""))
	session_token = String(response.get("token", ""))
	seat_index = int(response.get("seat_index", 0))
	role = "host"
	player_count = 2
	_poll_timer.start()
	room_hosted.emit(room_code)

func join_room(server_url: String, requested_room_code: String) -> void:
	reset()
	backend_url = _normalize_server_url(server_url)
	var response := await _request_json(HTTPClient.METHOD_POST, "/api/rooms/join", {
		"room_code": requested_room_code.strip_edges().to_upper(),
	})
	if response.is_empty():
		return
	room_code = String(response.get("room_code", ""))
	session_token = String(response.get("token", ""))
	seat_index = int(response.get("seat_index", 1))
	role = "guest"
	player_count = 2
	_poll_timer.start()
	room_joined.emit(room_code, seat_index)

func start_match() -> void:
	if not is_host():
		return
	var response := await _request_json(HTTPClient.METHOD_POST, "/api/rooms/start", {
		"room_code": room_code,
		"token": session_token,
	})
	if response.is_empty():
		return
	started = bool(response.get("started", false))
	if started:
		match_started.emit()

func push_snapshot(snapshot: Dictionary) -> void:
	if not is_host():
		return
	var snapshot_json := JSON.stringify(snapshot)
	if snapshot_json == _last_snapshot_json:
		return
	_last_snapshot_json = snapshot_json
	_request_json_fire_and_forget(HTTPClient.METHOD_POST, "/api/rooms/snapshot", {
		"room_code": room_code,
		"token": session_token,
		"snapshot": snapshot,
	})

func send_command(command: Dictionary) -> void:
	if not is_online():
		return
	_request_json_fire_and_forget(HTTPClient.METHOD_POST, "/api/rooms/command", {
		"room_code": room_code,
		"token": session_token,
		"command": command,
	})

func _on_poll_timeout() -> void:
	if room_code == "" or session_token == "":
		return
	var room_state := await _request_json(HTTPClient.METHOD_GET, "/api/rooms/state?room_code=%s&token=%s" % [room_code.uri_encode(), session_token.uri_encode()], {})
	if room_state.is_empty():
		return
	var was_guest_present := guest_present
	var was_started := started
	guest_present = bool(room_state.get("guest_joined", guest_present))
	started = bool(room_state.get("started", started))
	var revision := int(room_state.get("revision", last_revision))
	if guest_present and not was_guest_present:
		guest_joined.emit()
	if revision != last_revision:
		last_revision = revision
		room_state_updated.emit(room_state)
	if started and not was_started:
		match_started.emit()
	if is_host():
		await _poll_commands()

func _poll_commands() -> void:
	var response := await _request_json(HTTPClient.METHOD_GET, "/api/rooms/commands?room_code=%s&token=%s&after=%d" % [
		room_code.uri_encode(),
		session_token.uri_encode(),
		_last_command_id
	], {})
	if response.is_empty():
		return
	for command in response.get("commands", []):
		var command_dict: Dictionary = command
		_last_command_id = maxi(_last_command_id, int(command_dict.get("id", 0)))
		command_received.emit(command_dict)

func _normalize_server_url(server_url: String) -> String:
	var trimmed := server_url.strip_edges()
	return DEFAULT_SERVER_URL if trimmed == "" else trimmed.trim_suffix("/")

func _request_json_fire_and_forget(method: int, path: String, body: Dictionary) -> void:
	call_deferred("_async_fire_and_forget", method, path, body)

func _async_fire_and_forget(method: int, path: String, body: Dictionary) -> void:
	await _request_json(method, path, body)

func _request_json(method: int, path: String, body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body_text := ""
	if method != HTTPClient.METHOD_GET:
		body_text = JSON.stringify(body)
	var err := http.request(backend_url + path, headers, method, body_text)
	if err != OK:
		http.queue_free()
		request_failed.emit("Could not contact server at %s." % backend_url)
		return {}
	var result: Array = await http.request_completed
	http.queue_free()
	if result.size() < 4:
		request_failed.emit("Server response was incomplete.")
		return {}
	var response_code: int = result[1]
	var raw_body: PackedByteArray = result[3]
	var text := raw_body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if response_code >= 400:
		var message := "Server error %d." % response_code
		if parsed is Dictionary:
			message = String(parsed.get("error", message))
		request_failed.emit(message)
		return {}
	if parsed is Dictionary:
		return parsed
	request_failed.emit("Server returned invalid JSON.")
	return {}

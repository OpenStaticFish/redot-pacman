extends SceneTree
## Exercise the actual view's keyboard controls through Godot's input system.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _key(code: Key) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = code
	press.keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	var release: InputEventKey = press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _pointer_position(view: Node2D, point: Vector2) -> Vector2:
	return view.get_viewport().get_screen_transform() * view.get_global_transform_with_canvas() * point


func _touch(view: Node2D, point: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.position = _pointer_position(view, point)
	press.pressed = true
	Input.parse_input_event(press)
	var release: InputEventScreenTouch = press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)


func _click(view: Node2D, point: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = _pointer_position(view, point)
	press.global_position = press.position
	press.pressed = true
	Input.parse_input_event(press)
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)


func _run() -> void:
	var scene: PackedScene = load("res://scenes/arcade.tscn")
	var view: Node2D = scene.instantiate()
	root.add_child(view)
	await process_frame
	var session: GameSession = view.get("game")
	var audio: ArcadeAudio = view.get("audio")
	var original_mute: bool = audio.muted
	_expect(session.demo, "The app must open in live attract mode.")
	_key(KEY_ENTER)
	await process_frame
	_expect(not session.demo and session.lives == 3, "Enter must start a human run.")
	_key(KEY_RIGHT)
	await process_frame
	_expect(session.player.requested_direction == Vector2i.RIGHT, "Arrow keys must steer the player.")
	_key(KEY_P)
	await process_frame
	_expect(session.phase == GameSession.Phase.PAUSED, "P must pause.")
	_key(KEY_ESCAPE)
	await process_frame
	_expect(session.phase != GameSession.Phase.PAUSED, "Escape must resume.")
	_key(KEY_M)
	await process_frame
	_expect(audio.muted != original_mute, "M must toggle sound.")
	_key(KEY_M)
	await process_frame
	_expect(audio.muted == original_mute, "A second M must restore sound.")
	_key(KEY_C)
	await process_frame
	_expect(bool(view.get("credits_open")), "C must open credits.")
	_key(KEY_ESCAPE)
	await process_frame
	_expect(not bool(view.get("credits_open")), "Escape must close credits.")
	_key(KEY_TAB)
	await process_frame
	_expect(session.demo, "Tab must restart the demo.")
	_key(KEY_R)
	await process_frame
	_expect(not session.demo and session.score == 0, "R must reset to a fresh human run.")
	var buttons: Dictionary = view.get_script().get_script_constant_map()
	var mute_button: Rect2 = buttons["MUTE_BUTTON"]
	var pause_button: Rect2 = buttons["PAUSE_BUTTON"]
	var play_button: Rect2 = buttons["PLAY_BUTTON"]
	var demo_button: Rect2 = buttons["DEMO_BUTTON"]
	_touch(view, mute_button.get_center())
	await process_frame
	_expect(audio.muted != original_mute, "Touching the sound control must toggle once, without an emulated mouse double-toggle.")
	_click(view, mute_button.get_center())
	await process_frame
	_expect(audio.muted == original_mute, "Clicking the sound control must restore audio.")
	_touch(view, pause_button.get_center())
	await process_frame
	_expect(session.phase == GameSession.Phase.PAUSED, "Touching Pause must pause the run.")
	_click(view, pause_button.get_center())
	await process_frame
	_expect(session.phase != GameSession.Phase.PAUSED, "Clicking Resume must resume the run.")
	_click(view, demo_button.get_center())
	await process_frame
	_expect(session.demo, "The autoplay button must start a demo.")
	_touch(view, play_button.get_center())
	await process_frame
	_expect(not session.demo, "The play button must start a human run.")
	if DisplayServer.get_name() != "headless":
		var fullscreen_button: Rect2 = buttons["FULLSCREEN_BUTTON"]
		_click(view, fullscreen_button.get_center())
		await process_frame
		_expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "The fullscreen control must enter fullscreen.")
		_key(KEY_F11)
		await process_frame
		_expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "F11 must return to windowed mode.")
	view.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	if failures.is_empty():
		print("PASS: native keyboard, mouse, and touch controls for play, steering, pause, mute, credits, demo, and restart; fullscreen on graphical drivers.")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)

extends Node2D
## Native arcade presentation, input, juice, and persistent preferences.

const REDION: Texture2D = preload("res://assets/branding/redion.svg")
const REDION_OUTLINE: Texture2D = preload("res://assets/branding/redion_outline.svg")
const GODOT_ICON: Texture2D = preload("res://assets/godot/icon_color.svg")
const REGULAR: Font = preload("res://assets/fonts/Roboto-Variable.ttf")
const BOLD: Font = preload("res://assets/fonts/Roboto-Bold.tres")
const BLACK: Font = preload("res://assets/fonts/Roboto-Heading.tres")
const MONO: Font = preload("res://assets/fonts/JetBrainsMono-Regular.ttf")
const MONO_BOLD: Font = preload("res://assets/fonts/JetBrainsMono-Bold.ttf")
const ICONS = preload("res://scripts/arcade_icons.gd")
const BRAND_STYLE = preload("res://scripts/redot_style.gd")

const SIZE := Vector2(1600, 900)
const BOARD_ORIGIN := Vector2(435, 163)
const TILE: float = 26.0
const BOARD_RECT := Rect2(435, 163, 650, 650)
const FRAME_RECT := Rect2(408, 122, 704, 720)
const PLAY_BUTTON := Rect2(60, 577, 300, 60)
const DEMO_BUTTON := Rect2(60, 651, 300, 48)
const MUTE_BUTTON := Rect2(1132, 31, 166, 50)
const PAUSE_BUTTON := Rect2(1310, 31, 162, 50)
const FULLSCREEN_BUTTON := Rect2(1484, 31, 56, 50)

const BG: Color = BRAND_STYLE.INK
const INK: Color = BRAND_STYLE.TEXT
const MUTED: Color = BRAND_STYLE.TEXT_SECONDARY
const FAINT: Color = BRAND_STYLE.TEXT_DIM
const ORANGE: Color = BRAND_STYLE.BRAND
const RED: Color = BRAND_STYLE.BRAND_DARK
const PEACH: Color = BRAND_STYLE.PEACH
const PANEL: Color = BRAND_STYLE.SURFACE
const EDGE: Color = BRAND_STYLE.BORDER

var game := GameSession.new()
var audio: ArcadeAudio
var best_score: int = 0
var time: float = 0.0
var frames: int = 0
var particles: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var trail_timer: float = 0.0
var wall_paths: Array[PackedVector2Array] = []
var random := RandomNumberGenerator.new()
var mouse_position := Vector2.ZERO
var swipe_start := Vector2.ZERO
var dragging: bool = false
var feed_title: String = "THE FORK HAS AN APPETITE."
var feed_detail: String = "No royalties. Just raw appetite."
var feed_age: float = 0.0
var banner: String = ""
var banner_time: float = 0.0
var pulse: float = 0.0
var shake: float = 0.0
var credits_open: bool = false
var capture_path: String = ""
var capture_frame: int = 240
var capture_started: bool = false
var screenshot_index: int = 0
var quitting: bool = false
var hero_labels: Array[Label] = []
var web_build: bool = OS.has_feature("web")
var web_maze_normal: Texture2D
var web_maze_power: Texture2D
var style_pool: Array[StyleBoxFlat] = []
var style_index: int = 0


func _ready() -> void:
	random.seed = 404
	if web_build:
		Engine.max_fps = 60
		web_maze_normal = load("res://assets/web/maze_normal.png")
		web_maze_power = load("res://assets/web/maze_power.png")
	audio = ArcadeAudio.new()
	var preferences := ConfigFile.new()
	if preferences.load("user://dot_eater.cfg") == OK:
		best_score = int(preferences.get_value("arcade", "best_score", 0))
		audio.muted = bool(preferences.get_value("arcade", "muted", false))
	add_child(audio)
	_build_brand_layers()
	game.arcade_event.connect(_on_arcade_event)
	_build_wall_paths()
	var autoplay: bool = true
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--play":
			autoplay = false
		elif argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--capture-frame="):
			capture_frame = maxi(2, int(argument.trim_prefix("--capture-frame=")))
		elif argument == "--1440p":
			get_window().size = Vector2i(2560, 1440)
	game.start(autoplay)
	get_window().title = "DOT EATER / Redot After Hours Arcade"
	get_tree().auto_accept_quit = false


func _build_brand_layers() -> void:
	var backdrop: Control
	if web_build:
		var baked := TextureRect.new()
		baked.texture = load("res://assets/web/backdrop.png")
		backdrop = baked
	else:
		var procedural := ColorRect.new()
		var background_material := ShaderMaterial.new()
		background_material.shader = BRAND_STYLE.BACKDROP
		procedural.material = background_material
		backdrop = procedural
	backdrop.name = "RedotPixelBackdrop"
	backdrop.size = SIZE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -10
	add_child(backdrop)
	_add_gradient_heading("DOT", Vector2(56, 244), 100, 0.0)
	_add_gradient_heading("EATER.", Vector2(56, 337), 91, 0.16)


func _add_gradient_heading(text: String, baseline: Vector2, font_size: int, gradient_offset: float) -> void:
	var label := Label.new()
	label.text = text
	label.position = baseline - Vector2(0, BLACK.get_ascent(font_size))
	label.size = Vector2(340, BLACK.get_height(font_size))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 2
	label.add_theme_font_override("font", BLACK)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	var gradient_material := ShaderMaterial.new()
	gradient_material.shader = BRAND_STYLE.HERO_TEXT
	gradient_material.set_shader_parameter("line_offset", gradient_offset)
	label.material = gradient_material
	add_child(label)
	hero_labels.append(label)


func _physics_process(delta: float) -> void:
	if not credits_open:
		_read_gamepad()
		game.tick(delta)
	if not game.demo:
		best_score = maxi(best_score, game.score)
	audio.set_game_paused(game.phase == GameSession.Phase.PAUSED or credits_open)


func _process(delta: float) -> void:
	time += delta
	frames += 1
	feed_age += delta
	banner_time = maxf(0.0, banner_time - delta)
	pulse = maxf(0.0, pulse - delta * 1.8)
	shake = maxf(0.0, shake - delta * 20.0)
	mouse_position = get_global_mouse_position()
	for label: Label in hero_labels:
		label.visible = not credits_open
	_update_effects(delta)
	var over_button: bool = PLAY_BUTTON.has_point(mouse_position) or DEMO_BUTTON.has_point(mouse_position) or MUTE_BUTTON.has_point(mouse_position) or PAUSE_BUTTON.has_point(mouse_position) or FULLSCREEN_BUTTON.has_point(mouse_position)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over_button else Input.CURSOR_ARROW)
	queue_redraw()
	if not capture_path.is_empty() and frames >= capture_frame and not capture_started:
		capture_started = true
		_capture(capture_path, true)


func _read_gamepad() -> void:
	if game.demo or game.phase == GameSession.Phase.GAME_OVER:
		return
	var pads: Array[int] = Input.get_connected_joypads()
	if pads.is_empty():
		return
	var axis := Vector2(Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_X), Input.get_joy_axis(pads[0], JOY_AXIS_LEFT_Y))
	if axis.length() > 0.4:
		game.turn(Vector2i(signi(int(signf(axis.x))), 0) if absf(axis.x) > absf(axis.y) else Vector2i(0, signi(int(signf(axis.y)))))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if credits_open:
			if key == KEY_C or key == KEY_ESCAPE:
				credits_open = false
			return
		match key:
			KEY_UP, KEY_W:
				_handle_direction(Vector2i.UP)
			KEY_DOWN, KEY_S:
				_handle_direction(Vector2i.DOWN)
			KEY_LEFT, KEY_A:
				_handle_direction(Vector2i.LEFT)
			KEY_RIGHT, KEY_D:
				# D is movement during a run; the demo shortcut is Tab.
				_handle_direction(Vector2i.RIGHT)
			KEY_ENTER, KEY_KP_ENTER:
				if game.demo or game.phase == GameSession.Phase.GAME_OVER:
					_start_run()
				elif game.phase == GameSession.Phase.READY:
					game.phase = GameSession.Phase.PLAYING
			KEY_SPACE:
				if game.demo or game.phase == GameSession.Phase.GAME_OVER:
					_start_run()
				else:
					game.toggle_pause()
			KEY_P, KEY_ESCAPE:
				game.toggle_pause()
			KEY_R:
				_start_run()
			KEY_TAB:
				_start_demo()
			KEY_M:
				_toggle_sound()
			KEY_F11:
				_toggle_fullscreen()
			KEY_F9:
				screenshot_index += 1
				_capture("user://dot-eater-%02d.png" % screenshot_index, false)
			KEY_C:
				credits_open = true
	elif event is InputEventJoypadButton and event.pressed:
		if credits_open:
			credits_open = false
			return
		match event.button_index:
			JOY_BUTTON_A:
				if game.demo or game.phase == GameSession.Phase.GAME_OVER:
					_start_run()
			JOY_BUTTON_START:
				game.toggle_pause()
			JOY_BUTTON_DPAD_UP:
				_handle_direction(Vector2i.UP)
			JOY_BUTTON_DPAD_DOWN:
				_handle_direction(Vector2i.DOWN)
			JOY_BUTTON_DPAD_LEFT:
				_handle_direction(Vector2i.LEFT)
			JOY_BUTTON_DPAD_RIGHT:
				_handle_direction(Vector2i.RIGHT)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		if credits_open:
			credits_open = false
			return
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed:
			if not _activate_button(point) and BOARD_RECT.has_point(point):
				swipe_start = point
				dragging = true
		else:
			if dragging:
				_swipe(point - swipe_start)
			dragging = false
	elif event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
		if credits_open:
			credits_open = false
			return
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed:
			swipe_start = point
			dragging = not _activate_button(point) and BOARD_RECT.has_point(point)
		elif dragging:
			_swipe(point - swipe_start)
			dragging = false


func _activate_button(point: Vector2) -> bool:
	if PLAY_BUTTON.has_point(point):
		_start_run()
	elif DEMO_BUTTON.has_point(point):
		_start_demo()
	elif MUTE_BUTTON.has_point(point):
		_toggle_sound()
	elif PAUSE_BUTTON.has_point(point):
		game.toggle_pause()
	elif FULLSCREEN_BUTTON.has_point(point):
		_toggle_fullscreen()
	else:
		return false
	return true


func _toggle_sound() -> void:
	audio.toggle_mute()
	_save_preferences()


func _toggle_fullscreen() -> void:
	var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _handle_direction(direction: Vector2i) -> void:
	if game.demo or game.phase == GameSession.Phase.GAME_OVER:
		_start_run()
	game.turn(direction)


func _swipe(difference: Vector2) -> void:
	if difference.length() < 18.0:
		return
	_handle_direction(Vector2i(signi(int(signf(difference.x))), 0) if absf(difference.x) > absf(difference.y) else Vector2i(0, signi(int(signf(difference.y)))))


func _start_run() -> void:
	_save_preferences()
	trails.clear()
	particles.clear()
	floaters.clear()
	game.start(false)


func _start_demo() -> void:
	_save_preferences()
	trails.clear()
	particles.clear()
	floaters.clear()
	game.start(true)


func _save_preferences() -> void:
	var preferences := ConfigFile.new()
	preferences.set_value("arcade", "best_score", best_score)
	preferences.set_value("arcade", "muted", audio.muted if is_instance_valid(audio) else false)
	preferences.save("user://dot_eater.cfg")


func _exit_tree() -> void:
	_save_preferences()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_gracefully()
	elif web_build and what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		get_tree().paused = true
		if is_instance_valid(audio):
			audio.set_game_paused(true)
	elif web_build and what == NOTIFICATION_APPLICATION_FOCUS_IN:
		get_tree().paused = false


func _quit_gracefully() -> void:
	if quitting:
		return
	quitting = true
	_save_preferences()
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	audio.stop_all()
	# Give queued audio-server stop commands a mixing cycle before teardown.
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()


func _capture(path: String, quit_after: bool) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(path)
	if error == OK:
		print("Arcade screenshot: ", ProjectSettings.globalize_path(path))
	else:
		push_error("Screenshot failed: %s" % error_string(error))
	if quit_after:
		_quit_gracefully()


func _on_arcade_event(kind: String, grid_position: Vector2, points: int) -> void:
	audio.play_effect(kind)
	var position: Vector2 = _board_position(grid_position)
	match kind:
		"start":
			feed_title = "THE FORK HAS AN APPETITE."
			feed_detail = "Autoplay engaged. Press Enter to take over." if game.demo else "New branch. Same insatiable appetite."
		"dot":
			_emit_sparks(position, 2, ORANGE, 30.0)
		"power":
			feed_title = "THE FOOD CHAIN JUST FLIPPED."
			feed_detail = "Upstream is now a downstream snack."
			banner = "UPSTREAM IS NOW A SNACK."
			banner_time = 1.5
			pulse = 0.5
			_emit_sparks(position, 22, ORANGE, 150.0)
		"ghost":
			feed_title = "404: GHOST NOT FOUND."
			feed_detail = "+%d points. That's one way to resolve it." % points
			_emit_sparks(position, 25, PEACH, 170.0)
			_add_floater(position, "+%d" % points, PEACH)
			shake = 2.0
		"hit":
			feed_title = "MERGE CONFLICT. OUCH."
			feed_detail = "Rebase your expectations. Keep chomping."
			_emit_sparks(position, 40, ORANGE, 210.0)
			shake = 5.0
			trails.clear()
			_save_preferences()
		"fork_spawn":
			feed_title = "A WILD FORK APPEARED."
			feed_detail = "Grab the cutlery in the middle. +500."
		"fork":
			feed_title = "FORK AROUND. FIND OUT."
			feed_detail = "Cutlery acquired. Appetite: unreasonable."
			_add_floater(position, "+500 / NICE FORK", ORANGE)
			_emit_sparks(position, 25, ORANGE, 170.0)
		"clear":
			feed_title = "UPSTREAM SUCCESSFULLY EATEN."
			feed_detail = "+1000. Shipping the next release..."
			_save_preferences()
		"game_over":
			feed_title = "IT'S SO OVER. (FOR NOW.)"
			feed_detail = "Press Enter. Make questionable choices again."
			_save_preferences()
		"power_end":
			feed_title = "THEY REMEMBERED HOW TO CHASE."
			feed_detail = "Find another big dot. Act natural."
	if kind != "dot":
		feed_age = 0.0


func _emit_sparks(position: Vector2, count: int, color: Color, speed: float) -> void:
	for i in count:
		var angle: float = random.randf() * TAU
		var lifetime: float = random.randf_range(0.2, 0.65)
		particles.append({"position": position, "velocity": Vector2.from_angle(angle) * random.randf_range(speed * 0.3, speed), "life": lifetime, "total": lifetime, "color": color, "size": random.randf_range(1.0, 3.0)})
	while particles.size() > 300:
		particles.pop_front()


func _add_floater(position: Vector2, text: String, color: Color) -> void:
	var nearby: int = 0
	for floater: Dictionary in floaters:
		if (floater["position"] as Vector2).distance_to(position) < 65.0:
			nearby += 1
	position.y -= nearby * 21.0
	var half_width: float = MONO_BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x * 0.5
	position.x = clampf(position.x, BOARD_RECT.position.x + half_width + 10, BOARD_RECT.end.x - half_width - 10)
	position.y = maxf(BOARD_RECT.position.y + 25, position.y)
	floaters.append({"position": position, "text": text, "color": color, "life": 1.2})


func _update_effects(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle["life"] = float(particle["life"]) - delta
		particle["position"] = (particle["position"] as Vector2) + (particle["velocity"] as Vector2) * delta
		particle["velocity"] = (particle["velocity"] as Vector2) * exp(-delta * 4.0)
		if float(particle["life"]) <= 0.0:
			particles.remove_at(i)
	for i in range(floaters.size() - 1, -1, -1):
		var floater: Dictionary = floaters[i]
		floater["life"] = float(floater["life"]) - delta
		floater["position"] = (floater["position"] as Vector2) + Vector2(0, -24) * delta
		if float(floater["life"]) <= 0.0:
			floaters.remove_at(i)
	for i in range(trails.size() - 1, -1, -1):
		trails[i]["life"] = float(trails[i]["life"]) - delta
		if float(trails[i]["life"]) <= 0.0:
			trails.remove_at(i)
	trail_timer -= delta
	if trail_timer <= 0.0 and game.phase == GameSession.Phase.PLAYING and game.player.moving:
		trail_timer = 0.035
		trails.append({"position": _board_position(game.player.grid_position()), "life": 0.28})


func _draw() -> void:
	style_index = 0
	_draw_background()
	_draw_header()
	_draw_pitch()
	_draw_scoreboard()
	_draw_power_panel()
	_draw_ghost_roster()
	_draw_feed()
	_draw_board_frame()
	var offset := Vector2(sin(time * 73.0), cos(time * 61.0)) * shake
	draw_set_transform(offset)
	_draw_maze()
	_draw_pickups()
	_draw_trails_and_sparks()
	_draw_actors()
	_draw_floaters()
	draw_set_transform(Vector2.ZERO)
	_draw_board_edge_masks()
	_draw_tunnel_cues()
	_draw_board_overlay()
	_draw_footer()
	_draw_toolbar_tooltip()
	if credits_open:
		_draw_credits()


func _draw_background() -> void:
	draw_rect(Rect2(0, 0, 1600, 100), BRAND_STYLE.HEADER)
	draw_line(Vector2(60, 100), Vector2(1540, 100), EDGE, 1.0)
	draw_line(Vector2(60, 852), Vector2(1540, 852), EDGE, 1.0)
	draw_line(Vector2(530, 852), Vector2(1070, 852), Color(ORANGE, 0.18), 1.0)


func _draw_header() -> void:
	_texture_fit(REDION, Rect2(60, 32, 36, 37))
	_text("Redot Engine", Vector2(109, 62), 25, INK, BOLD)
	draw_line(Vector2(278, 40), Vector2(278, 77), EDGE, 1.0)
	_text("AFTER HOURS ARCADE", Vector2(301, 53), 13, INK, MONO_BOLD)
	_text("OPEN-SOURCE GAME CREATION", Vector2(301, 74), 10, MUTED, MONO)
	_text("OPEN SOURCE. FULL APPETITE.", Vector2(678, 62), 12, MUTED, MONO)
	_rounded(Rect2(934, 38, 172, 36), BRAND_STYLE.BRAND_WASH, 18, Color(ORANGE, 0.45))
	_glow(Vector2(953, 56), ORANGE, 7.0, 0.04)
	draw_circle(Vector2(953, 56), 3.5, ORANGE)
	_text("FREE PLAY / LIVE", Vector2(968, 61), 11, ORANGE, MONO_BOLD)
	_toolbar_button(MUTE_BUTTON, "MUTED" if audio.muted else "SOUND ON", "M", ICONS.Symbol.MUTED if audio.muted else ICONS.Symbol.SOUND, audio.muted)
	var paused: bool = game.phase == GameSession.Phase.PAUSED
	_toolbar_button(PAUSE_BUTTON, "RESUME" if paused else "PAUSE", "P", ICONS.Symbol.PLAY if paused else ICONS.Symbol.PAUSE, paused)
	var hovered: bool = FULLSCREEN_BUTTON.has_point(mouse_position)
	_rounded(FULLSCREEN_BUTTON, BRAND_STYLE.BRAND_WASH if hovered else BRAND_STYLE.INK_DEEP, 11, ORANGE if hovered else Color(ORANGE, 0.55))
	_icon(ICONS.Symbol.FULLSCREEN, Vector2(1512, 49), ORANGE, 0.85)
	_text_center("F11", Vector2(1512, 72), 10, MUTED, MONO_BOLD)


func _draw_pitch() -> void:
	_glow(Vector2(64, 145), ORANGE, 8.0, 0.025)
	draw_circle(Vector2(64, 145), 3.0, ORANGE)
	_text("001 / THE REDOT ARCADE", Vector2(78, 151), 11, MUTED, MONO_BOLD)
	draw_rect(Rect2(62, 356, 42, 3), ORANGE)
	_text("Eat dots.", Vector2(60, 400), 28, INK, BOLD)
	_text("Chase your upstream.", Vector2(60, 435), 28, INK, BOLD)
	_text("A FORK WITH AN APPETITE.", Vector2(60, 466), 12, MUTED, MONO)
	# A tiny, animated visual punchline: Redion eats the dots between engines.
	var hero := Vector2(90, 513)
	_glow(hero, ORANGE, 35.0, 0.08)
	_texture_fit(REDION, Rect2(hero - Vector2(22, 23), Vector2(44, 46)))
	for i in 4:
		var center := Vector2(153 + i * 29, 513)
		var alpha: float = 0.3 + 0.6 * (0.5 + sin(time * 4.0 - i * 0.8) * 0.5)
		draw_circle(center, 3.3, Color(ORANGE, alpha))
	_draw_ghost(Vector2(308, 513), 0, 1.5, false, false, Vector2i.LEFT)
	draw_line(Vector2(60, 551), Vector2(360, 551), EDGE, 1.0)
	_text("NO QUARTERS. NO PERMISSION NEEDED.", Vector2(60, 568), 11, MUTED, MONO)
	var hovered: bool = PLAY_BUTTON.has_point(mouse_position)
	for i in range(3, 0, -1):
		_rounded(Rect2(PLAY_BUTTON.position + Vector2(0, 6), PLAY_BUTTON.size).grow(i * 4), Color(ORANGE, 0.018), 11 + i * 4)
	_rounded(PLAY_BUTTON, ORANGE.lightened(0.1) if hovered else ORANGE, 11)
	var play_text: String = "Play now"
	if game.demo:
		play_text = "Play now"
	elif game.phase == GameSession.Phase.GAME_OVER:
		play_text = "Run it back"
	else:
		play_text = "Restart run"
	_text(play_text, Vector2(82, 615), 21, BG, BOLD)
	_icon(ICONS.Symbol.ARROW_RIGHT, Vector2(249, 607), BG, 0.8)
	_shortcut_badge(Rect2(274, 596, 65, 24), "ENTER" if game.demo or game.phase == GameSession.Phase.GAME_OVER else "R", BG, Color(0, 0, 0, 0.12))
	var demo_hovered: bool = DEMO_BUTTON.has_point(mouse_position)
	_rounded(DEMO_BUTTON, BRAND_STYLE.BRAND_WASH if demo_hovered else BRAND_STYLE.INK_DEEP, 11, ORANGE if demo_hovered else Color(ORANGE, 0.62))
	_icon(ICONS.Symbol.PLAY, Vector2(84, 675), ORANGE, 0.7)
	_text("Watch autoplay", Vector2(106, 681), 16, ORANGE, BOLD)
	_shortcut_badge(Rect2(305, 664, 35, 22), "TAB", ORANGE)
	_rounded(Rect2(60, 717, 300, 125), PANEL, 12, EDGE)
	_keycap(Rect2(112, 731, 31, 29), "W", KEY_W)
	_keycap(Rect2(76, 765, 31, 29), "A", KEY_A)
	_keycap(Rect2(112, 765, 31, 29), "S", KEY_S)
	_keycap(Rect2(148, 765, 31, 29), "D", KEY_D)
	_text("Find your way.", Vector2(192, 749), 16, INK, BOLD)
	_text("WASD / arrow keys", Vector2(192, 772), 13, MUTED, REGULAR)
	_text("Gamepad / swipe", Vector2(192, 792), 12, MUTED, REGULAR)
	_shortcut_badge(Rect2(76, 809, 20, 21), "P")
	_text("Pause", Vector2(102, 824), 11, MUTED, REGULAR)
	_shortcut_badge(Rect2(164, 809, 20, 21), "M")
	_text("Sound", Vector2(190, 824), 11, MUTED, REGULAR)
	_shortcut_badge(Rect2(252, 809, 20, 21), "R")
	_text("Reset", Vector2(278, 824), 11, MUTED, REGULAR)


func _draw_scoreboard() -> void:
	var rect := Rect2(1160, 128, 380, 204)
	_rounded(rect, PANEL, 12, EDGE)
	draw_line(Vector2(1184, 129), Vector2(1324, 129), ORANGE, 2.0)
	_text("DEMO SCORE" if game.demo else "YOUR SCORE", Vector2(1184, 158), 11, MUTED, MONO_BOLD)
	_text("%06d" % game.score, Vector2(1180, 230), 59, INK, MONO_BOLD)
	_icon(ICONS.Symbol.TROPHY, Vector2(1415, 154), ORANGE, 0.55)
	_text("BEST RUN", Vector2(1429, 158), 11, MUTED, MONO_BOLD)
	_text("%06d" % best_score, Vector2(1414, 189), 21, ORANGE, MONO_BOLD)
	draw_line(Vector2(1184, 249), Vector2(1516, 249), EDGE, 1.0)
	_text("LIVES", Vector2(1184, 273), 11, MUTED, MONO)
	for i in 3:
		var center := Vector2(1197 + i * 35, 297)
		draw_circle(center, 15.0, Color(ORANGE, 0.08) if i < game.lives else BRAND_STYLE.SURFACE_RAISED)
		draw_arc(center, 15.0, 0, TAU, 28, Color(ORANGE, 0.22) if i < game.lives else EDGE, 1.0, true)
		_texture_fit(REDION if i < game.lives else REDION_OUTLINE, Rect2(center - Vector2(10, 11), Vector2(20, 22)), Color(1, 1, 1, 1.0 if i < game.lives else 0.25))
	_text("RELEASE", Vector2(1408, 273), 11, MUTED, MONO)
	_rounded(Rect2(1408, 282, 108, 32), BRAND_STYLE.SURFACE_RAISED, 8, EDGE)
	_icon(ICONS.Symbol.BRANCH, Vector2(1424, 298), ORANGE, 0.7)
	_text("v.%02d" % game.level, Vector2(1440, 305), 22, INK, MONO_BOLD)


func _draw_power_panel() -> void:
	var powered: bool = game.power_time > 0.0
	var power_dots: int = 0
	for points: int in game.maze.pellets.values():
		if points == 50:
			power_dots += 1
	_rounded(Rect2(1160, 356, 380, 158), BRAND_STYLE.BRAND_WASH if powered else PANEL, 12, Color(ORANGE, 0.45) if powered else EDGE)
	_icon(ICONS.Symbol.POWER, Vector2(1189, 381), ORANGE, 0.6)
	_text("THE FOOD CHAIN", Vector2(1206, 386), 11, ORANGE if powered else MUTED, MONO_BOLD)
	_rounded(Rect2(1460, 370, 56, 23), Color(ORANGE, 0.1) if powered else BRAND_STYLE.SURFACE_RAISED, 5)
	_text_center("%.1fs" % game.power_time if powered else "%d LEFT" % power_dots, Vector2(1488, 386), 11, ORANGE if powered else MUTED, MONO_BOLD)
	_text("UPSTREAM PANIC" if powered else "YOU ARE THE SNACK", Vector2(1183, 424), 25, ORANGE if powered else INK, BLACK)
	if powered:
		for i in 8:
			var segment := Rect2(1184 + i * 42, 443, 38, 8)
			_rounded(segment, BRAND_STYLE.BRAND_DEEP.darkened(0.45), 3)
			var strength: float = clampf(game.power_time - i, 0.0, 1.0)
			if strength > 0.02:
				_rounded(Rect2(segment.position, Vector2(segment.size.x * strength, segment.size.y)), ORANGE, 3)
		_text("POWER LEFT", Vector2(1184, 469), 10, MUTED, MONO)
		_text_right("8 SEC MAX", Vector2(1516, 469), 10, MUTED, MONO)
		_text("Chomp ghosts. Stack the combo.", Vector2(1184, 494), 13, INK, REGULAR)
	else:
		draw_line(Vector2(1193, 447), Vector2(1295, 447), EDGE, 1.0)
		for i in 4:
			var center := Vector2(1193 + i * 34, 447)
			draw_circle(center, 8.0, PANEL)
			draw_arc(center, 8.0, 0, TAU, 24, Color(ORANGE, 0.45) if i < power_dots else EDGE, 1.0, true)
			draw_circle(center, 4.3, ORANGE if i < power_dots else FAINT.darkened(0.3))
		_text_right("%d BIG DOTS LEFT" % power_dots, Vector2(1516, 452), 11, MUTED, MONO)
		_text("Find a big dot. Flip the food chain.", Vector2(1184, 491), 13, MUTED, REGULAR)
	if game.combo > 0:
		_rounded(Rect2(1460, 400, 56, 28), Color(ORANGE, 0.12), 5, Color(ORANGE, 0.3))
		_text_center("%dx" % game.combo, Vector2(1488, 421), 20, INK, MONO_BOLD)


func _draw_ghost_roster() -> void:
	_rounded(Rect2(1160, 538, 380, 155), PANEL, 12, EDGE)
	_text("UPSTREAM WATCH", Vector2(1184, 568), 11, MUTED, MONO_BOLD)
	var out_count: int = 0
	for ghost: Dictionary in game.ghosts:
		if not bool(ghost["returning"]) and not bool(ghost["exiting"]):
			out_count += 1
	_text_right("%d/4 OUT" % out_count, Vector2(1516, 568), 11, ORANGE, MONO)
	var names: Array[String] = ["MAIN", "PR #404", "LEGACY", "HOTFIX"]
	for i in 4:
		var rect := Rect2(1182 + i * 86, 582, 78, 99)
		var center := Vector2(rect.get_center().x, 612)
		var ghost: Dictionary = game.ghosts[i]
		var scared: bool = game.power_time > 0.0 and not bool(ghost["returning"])
		_rounded(rect, BRAND_STYLE.CHROME, 8, EDGE)
		draw_arc(center, 22.0, 0, TAU, 28, Color(ORANGE, 0.14), 1.0, true)
		_draw_ghost(center + Vector2(0, sin(time * 3.0 + i) * 1.4), i, 1.35, scared, bool(ghost["returning"]), Vector2i.LEFT)
		_text_center(names[i], Vector2(center.x, 650), 11, INK, MONO_BOLD)
		var status: String = "CHASING"
		if bool(ghost["returning"]):
			status = "404'D"
		elif float(ghost["wait"]) > 0.0 or bool(ghost["exiting"]):
			status = "QUEUED"
		elif scared:
			status = "BITE SIZE"
		_text_center(status, Vector2(center.x, 671), 10, ORANGE if scared else MUTED, MONO)


func _draw_feed() -> void:
	_rounded(Rect2(1160, 717, 380, 125), PANEL, 12, EDGE)
	draw_circle(Vector2(1187, 744), 3, Color(ORANGE, 0.65) if feed_age > 0.5 else ORANGE)
	_text("LIVE COMMIT LOG", Vector2(1200, 748), 11, MUTED, MONO_BOLD)
	_text_right("JUST NOW" if feed_age < 2.0 else "%ds AGO" % int(feed_age), Vector2(1516, 748), 10, FAINT, MONO)
	_text(feed_title, Vector2(1184, 780), 18, INK, BOLD)
	_text(feed_detail, Vector2(1184, 804), 13, MUTED, REGULAR)
	_icon(ICONS.Symbol.BRANCH, Vector2(1191, 825), ORANGE, 0.55)
	_text("absolute-chaos", Vector2(1207, 829), 11, FAINT, MONO)


func _draw_board_frame() -> void:
	for i in range(3, 0, -1):
		_rounded(FRAME_RECT.grow(i * 4), Color(ORANGE, 0.012), 18 + i * 4)
	_rounded(FRAME_RECT.grow(5), Color(0.0, 0.0, 0.0, 0.3), 23)
	_rounded(FRAME_RECT, BRAND_STYLE.CHROME, 18, BRAND_STYLE.BORDER_STRONG)
	if pulse > 0.0:
		_rounded(FRAME_RECT.grow(2), Color.TRANSPARENT, 16, Color(ORANGE, pulse))
	var status_color: Color = ORANGE if game.demo else PEACH
	if game.phase == GameSession.Phase.PAUSED:
		status_color = ORANGE
	draw_circle(Vector2(438, 144), 3, status_color)
	var status: String = "AUTOPLAY / ATTRACT" if game.demo else "LIVE / PLAYER 01"
	if game.phase == GameSession.Phase.PAUSED:
		status = "PAUSED / REBASING"
	_text(status, Vector2(451, 149), 11, status_color, MONO_BOLD)
	_text_right(banner if banner_time > 0.0 else "ONE MAZE. ZERO CHILL.", Vector2(961, 149), 10, ORANGE if banner_time > 0.0 else MUTED, MONO)
	_rounded(Rect2(983, 131, 101, 24), BRAND_STYLE.SURFACE_RAISED, 6, EDGE)
	_text_center("MAZE %02d" % game.level, Vector2(1033, 148), 11, INK, MONO_BOLD)
	draw_rect(BOARD_RECT, BRAND_STYLE.INK_DEEP)
	var completion: float = float(game.collected) / game.maze.total_pellets
	_text("DOTS", Vector2(439, 834), 11, MUTED, MONO)
	_text("%03d" % game.maze.pellets.size(), Vector2(484, 835), 14, INK, MONO_BOLD)
	_rounded(Rect2(535, 825, 340, 6), BRAND_STYLE.SURFACE_RAISED, 3)
	if completion > 0.0:
		_rounded(Rect2(535, 825, 340 * completion, 6), ORANGE, 3)
	_text("%02d%%" % int(completion * 100), Vector2(890, 834), 12, ORANGE, MONO_BOLD)
	_text_right("CLEAR THE MAZE", Vector2(1081, 834), 11, MUTED, MONO)
	# Cabinet corner accents.
	for corner: Vector2 in [Vector2(418, 132), Vector2(1102, 132), Vector2(418, 832), Vector2(1102, 832)]:
		draw_circle(corner, 1.5, Color(ORANGE, 0.35))


func _build_wall_paths() -> void:
	for contour: PackedVector2Array in game.maze.contours:
		var corners := PackedVector2Array()
		for i in contour.size():
			var previous: Vector2 = contour[posmod(i - 1, contour.size())]
			var current: Vector2 = contour[i]
			var next: Vector2 = contour[(i + 1) % contour.size()]
			var incoming: Vector2 = (current - previous).normalized()
			var outgoing: Vector2 = (next - current).normalized()
			if absf(incoming.cross(outgoing)) < 0.1:
				continue
			var normal_in := Vector2(-incoming.y, incoming.x)
			var normal_out := Vector2(-outgoing.y, outgoing.x)
			corners.append(BOARD_ORIGIN + current * TILE + (normal_in + normal_out) * 4.0)
		var path := PackedVector2Array()
		for i in corners.size():
			var previous: Vector2 = corners[posmod(i - 1, corners.size())]
			var current: Vector2 = corners[i]
			var next: Vector2 = corners[(i + 1) % corners.size()]
			var radius: float = minf(6.0, minf(previous.distance_to(current), next.distance_to(current)) * 0.3)
			var before: Vector2 = current - (current - previous).normalized() * radius
			var after: Vector2 = current + (next - current).normalized() * radius
			for step in 5:
				var t: float = float(step) / 4.0
				path.append(before.lerp(current, t).lerp(current.lerp(after, t), t))
		if not path.is_empty():
			path.append(path[0])
			wall_paths.append(path)


func _maze_outline_color() -> Color:
	return ORANGE if game.power_time > 0.0 else BRAND_STYLE.MAZE_OUTLINE


func _draw_maze() -> void:
	var powered: bool = game.power_time > 0.0
	if web_build:
		var texture: Texture2D = web_maze_power if powered else web_maze_normal
		if game.phase == GameSession.Phase.CLEAR:
			texture = web_maze_power if sin(time * 12.0) > 0.0 else web_maze_normal
		draw_texture_rect(texture, BOARD_RECT, false)
		return
	var wall_fill: Color = BRAND_STYLE.MAZE_WALL_POWER if powered else BRAND_STYLE.MAZE_WALL
	for y in ArcadeMaze.HEIGHT:
		for x in ArcadeMaze.WIDTH:
			var cell := Vector2i(x, y)
			if game.maze.is_wall(cell):
				draw_rect(Rect2(BOARD_ORIGIN + Vector2(cell) * TILE, Vector2.ONE * TILE), wall_fill)
			elif game.maze.walkable(cell, true):
				draw_circle(_board_position(Vector2(cell)), 0.6, Color(PEACH, 0.055))
	var wall_color: Color = _maze_outline_color()
	if game.phase == GameSession.Phase.CLEAR:
		wall_color = INK if sin(time * 12.0) > 0.0 else ORANGE
	_draw_maze_inlays(wall_color)
	for path: PackedVector2Array in wall_paths:
		draw_polyline(path, Color(wall_color, 0.05), 9.0, true)
		draw_polyline(path, Color(wall_color, 0.16), 4.0, true)
		draw_polyline(path, wall_color, 1.5, true)
	# The ghost-house gate: a small dashed upstream branch.
	for i in 3:
		draw_line(BOARD_ORIGIN + Vector2(12 * TILE + 3 + i * 8, 9 * TILE + 4), BOARD_ORIGIN + Vector2(12 * TILE + 7 + i * 8, 9 * TILE + 4), Color(wall_color.lightened(0.25), 0.55), 1.7)
	_texture_fit(GODOT_ICON, Rect2(_board_position(Vector2(12, 10)) - Vector2(11, 11), Vector2(22, 22)), Color(1, 1, 1, 0.16))
	_text_center("UPSTREAM", _board_position(Vector2(12, 12)) + Vector2(0, 6), 10, Color(wall_color.lightened(0.25), 0.5), MONO_BOLD)


func _draw_maze_inlays(wall_color: Color) -> void:
	# These are solid walls, not large unmarked areas that look like open lanes.
	for side in 2:
		var column: int = 0 if side == 0 else 19
		var plate := Rect2(BOARD_ORIGIN + Vector2(column * TILE + 14, 7 * TILE + 14), Vector2(128, 102))
		_rounded(plate, BRAND_STYLE.CHROME, 8, Color(wall_color, 0.28))
		var center: Vector2 = plate.get_center()
		_texture_fit(REDION_OUTLINE, Rect2(center.x - 12, plate.position.y + 12, 24, 25), Color(wall_color, 0.6))
		_text_center("WARP LINK", Vector2(center.x, plate.position.y + 58), 11, Color(wall_color.lightened(0.25), 0.7), MONO_BOLD)
		_text_center("A <-> B" if side == 0 else "B <-> A", Vector2(center.x, plate.position.y + 77), 10, Color(wall_color.lightened(0.15), 0.5), MONO)
		for i in 3:
			draw_circle(Vector2(center.x - 9 + i * 9, plate.end.y - 12), 1.2, Color(wall_color, 0.4 + 0.2 * sin(time * 2.0 - i)))
		var lower := Rect2(BOARD_ORIGIN + Vector2(column * TILE + 14, 13 * TILE + 14), Vector2(128, 50))
		_rounded(lower, BRAND_STYLE.CHROME, 7, Color(wall_color, 0.22))
		_text_center("PORT A" if side == 0 else "PORT B", Vector2(lower.get_center().x, lower.position.y + 23), 11, Color(wall_color.lightened(0.2), 0.6), MONO_BOLD)
		draw_line(lower.position + Vector2(23, 34), lower.position + Vector2(105, 34), Color(wall_color, 0.28), 1.0)


func _draw_board_edge_masks() -> void:
	# Clip wraparound sprites to the screen before they emerge at the other port.
	draw_rect(Rect2(FRAME_RECT.position.x + 1, BOARD_ORIGIN.y, BOARD_ORIGIN.x - FRAME_RECT.position.x - 1, BOARD_RECT.size.y), BRAND_STYLE.CHROME)
	draw_rect(Rect2(BOARD_RECT.end.x, BOARD_ORIGIN.y, FRAME_RECT.end.x - BOARD_RECT.end.x - 1, BOARD_RECT.size.y), BRAND_STYLE.CHROME)


func _draw_tunnel_cues() -> void:
	var portal_color: Color = _maze_outline_color()
	var tunnel_y: float = BOARD_ORIGIN.y + (ArcadeMaze.TUNNEL_ROW + 0.5) * TILE
	for side in 2:
		var edge: float = BOARD_ORIGIN.x if side == 0 else BOARD_RECT.end.x
		var x: float = edge - 13 if side == 0 else edge + 13
		var direction: float = -1.0 if side == 0 else 1.0
		var alpha: float = 0.6 + 0.2 * sin(time * 3.0)
		draw_line(Vector2(edge, tunnel_y - 11), Vector2(edge, tunnel_y + 11), Color(portal_color, 0.12), 8.0, true)
		draw_line(Vector2(edge, tunnel_y - 11), Vector2(edge, tunnel_y + 11), Color(portal_color, alpha), 1.7, true)
		for i in 2:
			var center := Vector2(x - direction * i * 5, tunnel_y)
			draw_polyline(PackedVector2Array([center + Vector2(-direction * 2, -4), center + Vector2(direction * 2, 0), center + Vector2(-direction * 2, 4)]), Color(portal_color, alpha - i * 0.25), 1.5, true)


func _draw_pickups() -> void:
	for cell: Vector2i in game.maze.pellets:
		var position: Vector2 = _board_position(Vector2(cell))
		if int(game.maze.pellets[cell]) == 50:
			var radius: float = 7.0 + sin(time * 4.5) * 1.0
			_glow(position, ORANGE, 17, 0.09)
			draw_circle(position, radius, ORANGE)
			draw_arc(position, radius + 4, 0, TAU, 32, Color(ORANGE, 0.25 + sin(time * 4.5) * 0.1), 1.0, true)
			draw_circle(position - Vector2(1.5, 1.5), 2.0, PEACH)
		else:
			draw_circle(position, 2.4, PEACH.darkened(0.17))
	if game.fork_active:
		var position: Vector2 = _board_position(Vector2(12, 14)) + Vector2(0, sin(time * 4.0) * 3.0)
		_glow(position, ORANGE, 20.0, 0.1)
		_draw_fork(position, ORANGE)


func _draw_trails_and_sparks() -> void:
	for trail: Dictionary in trails:
		var ratio: float = float(trail["life"]) / 0.28
		var position: Vector2 = trail["position"]
		if BOARD_RECT.has_point(position):
			draw_circle(position, 8.0 * ratio, Color(ORANGE, ratio * 0.17))
	for particle: Dictionary in particles:
		var ratio: float = float(particle["life"]) / float(particle["total"])
		var color: Color = particle["color"]
		draw_circle(particle["position"], float(particle["size"]) * ratio, Color(color, ratio))


func _draw_actors() -> void:
	for ghost: Dictionary in game.ghosts:
		var mover: MazeRunner = ghost["mover"]
		var position: Vector2 = _board_position(mover.grid_position())
		var scared: bool = game.power_time > 0.0 and not bool(ghost["returning"])
		_draw_ghost(position + Vector2(0, sin(time * 7.0 + int(ghost["index"])) * 1.0), int(ghost["index"]), 1.0, scared, bool(ghost["returning"]), mover.direction)
		if position.x < BOARD_ORIGIN.x + 12:
			_draw_ghost(position + Vector2(650, 0), int(ghost["index"]), 1.0, scared, bool(ghost["returning"]), mover.direction)
		elif position.x > BOARD_RECT.end.x - 12:
			_draw_ghost(position - Vector2(650, 0), int(ghost["index"]), 1.0, scared, bool(ghost["returning"]), mover.direction)
	if game.phase == GameSession.Phase.HIT:
		return
	var position: Vector2 = _board_position(game.player.grid_position())
	_draw_player(position)
	if position.x < BOARD_ORIGIN.x + 15:
		_draw_player(position + Vector2(650, 0))
	elif position.x > BOARD_RECT.end.x - 15:
		_draw_player(position - Vector2(650, 0))


func _draw_player(position: Vector2) -> void:
	var powered: bool = game.power_time > 0.0
	_glow(position, ORANGE, 25.0 if powered else 20.0, 0.055)
	var direction := Vector2(game.player.direction)
	var angle: float = direction.angle() if direction != Vector2.ZERO else 0.0
	var chomp: float = 0.12 + absf(sin(time * 19.0)) * 0.5
	draw_arc(position, 15.0, angle + chomp, angle + TAU - chomp, 44, ORANGE, 2.4, true)
	_texture_fit(REDION, Rect2(position - Vector2(11.5, 12), Vector2(23, 24)))
	if powered:
		draw_arc(position, 20.0, -time * 3.0, -time * 3.0 + PI * 1.3, 32, PEACH, 1.0, true)


func _ghost_color(index: int) -> Color:
	return GameSession.GHOST_COLORS[index]


func _draw_ghost(position: Vector2, index: int, scale_factor: float, scared: bool, returning: bool, direction: Vector2i) -> void:
	var radius: float = 12.0 * scale_factor
	var gaze := Vector2(direction) * 1.1 * scale_factor
	if returning:
		for side in [-1, 1]:
			var eye: Vector2 = position + Vector2(side * 4.0, -2.0) * scale_factor
			draw_circle(eye, 3.4 * scale_factor, INK)
			draw_circle(eye + gaze, 1.7 * scale_factor, Color("428bbd"))
		return
	var color: Color = _ghost_color(index)
	if scared:
		color = Color("315fa0")
		if game.power_time < 2.0 and sin(time * 13.0) > 0.0:
			color = Color("c4ccd7")
	_glow(position, color, radius * 1.8, 0.045)
	var body := PackedVector2Array()
	for i in 17:
		var angle: float = PI + PI * float(i) / 16.0
		body.append(position + Vector2(cos(angle) * radius, sin(angle) * radius - scale_factor))
	body.append(position + Vector2(radius, 12 * scale_factor))
	for i in range(5, -1, -1):
		var x: float = lerpf(-radius, radius, float(i) / 5.0)
		var y: float = (9.0 if i % 2 == 0 else 12.0) * scale_factor
		body.append(position + Vector2(x, y))
	body.append(body[0])
	draw_colored_polygon(body, color.darkened(0.62))
	draw_polyline(body, Color(color, 0.7), 1.0, true)
	if scared:
		for side in [-1, 1]:
			draw_circle(position + Vector2(side * 4.0, -3.0) * scale_factor, 1.6 * scale_factor, INK)
		var mouth := PackedVector2Array()
		for i in 6:
			mouth.append(position + Vector2(-6.0 + i * 2.4, 3.0 + (i % 2) * 2.0) * scale_factor)
		draw_polyline(mouth, INK, 1.1, true)
	else:
		_texture_fit(GODOT_ICON, Rect2(position - Vector2(11, 12) * scale_factor, Vector2(22, 22) * scale_factor))
		# A color-coded, tiny branch badge keeps the official logo intact.
		draw_circle(position + Vector2(9.0, 9.0) * scale_factor, 2.0 * scale_factor, color)


func _draw_floaters() -> void:
	for floater: Dictionary in floaters:
		var color: Color = floater["color"]
		color.a = minf(1.0, float(floater["life"]) * 2.0)
		_text_center(floater["text"], floater["position"], 16, color, MONO_BOLD)


func _draw_board_overlay() -> void:
	if not game.demo:
		match game.phase:
			GameSession.Phase.READY:
				_center_message("READY TO FORK?", "MOVE WITH WASD / ARROWS", ORANGE)
			GameSession.Phase.PAUSED:
				_center_message("BRB. REBASING.", "P / ESC / SPACE TO RESUME", INK)
			GameSession.Phase.GAME_OVER:
				_center_message("MERGE CONFLICTED.", "ENTER TO RUN IT BACK", ORANGE)
			GameSession.Phase.CLEAR:
				_center_message("UPSTREAM CLEARED.", "+1000 / NEXT RELEASE INCOMING", PEACH)
	elif game.phase == GameSession.Phase.PAUSED:
		_center_message("CHAOS ON HOLD.", "P / ESC TO RESUME", INK)


func _center_message(title: String, subtitle: String, color: Color) -> void:
	draw_rect(BOARD_RECT, Color(BRAND_STYLE.INK_DEEP, 0.72))
	_rounded(Rect2(521, 386, 478, 197), Color(0, 0, 0, 0.35), 17)
	_rounded(Rect2(528, 379, 464, 197), PANEL, 14, Color(ORANGE, 0.45))
	draw_line(Vector2(548, 380), Vector2(972, 380), Color(color, 0.8), 2.0)
	draw_circle(Vector2(760, 420), 22, Color(color, 0.08))
	var symbol: ICONS.Symbol = ICONS.Symbol.PLAY
	if game.phase == GameSession.Phase.PAUSED:
		symbol = ICONS.Symbol.PAUSE
	elif game.phase == GameSession.Phase.CLEAR:
		symbol = ICONS.Symbol.TROPHY
	_icon(symbol, Vector2(760, 420), color, 1.1)
	_text_center(title, Vector2(760, 484), 30, color, BLACK)
	_text_center(subtitle, Vector2(760, 522), 13, INK, MONO)
	_text_center("NO COINS REQUIRED. JUST APPETITE.", Vector2(760, 556), 11, MUTED, MONO)


func _draw_footer() -> void:
	_text("REDOT AFTER HOURS / ARCADE 001", Vector2(60, 879), 11, MUTED, MONO)
	_text_center("POV: YOUR FORK HAS AN APPETITE" if game.demo else "BUILT WITH REDOT. SERVED WITH ATTITUDE.", Vector2(760, 879), 11, ORANGE, MONO)
	_text_right("F9 SCREENSHOT   /   C CREDITS", Vector2(1540, 879), 11, MUTED, MONO)


func _draw_credits() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(BRAND_STYLE.INK_DEEP, 0.94))
	_rounded(Rect2(450, 238, 700, 424), PANEL, 16, EDGE)
	_texture_fit(REDION, Rect2(486, 278, 46, 48))
	_text("GOOD FORKS GIVE CREDIT.", Vector2(557, 312), 29, INK, BLACK)
	_text("REDOT LOGO / REDION", Vector2(486, 380), 12, ORANGE, MONO_BOLD)
	_text("Asrorul Irsyad, 2024. Creative Commons Attribution 4.0.", Vector2(486, 407), 18, INK, REGULAR)
	_text("GODOT LOGO / UPSTREAM MASCOTS", Vector2(486, 454), 12, ORANGE, MONO_BOLD)
	_text("Andrea Calabró, 2017. Creative Commons Attribution 4.0.", Vector2(486, 481), 18, INK, REGULAR)
	_text("Roboto + JetBrains Mono / SIL Open Font License.", Vector2(486, 529), 17, MUTED, REGULAR)
	_text("Original maze, arcade effects & procedural chip audio.", Vector2(486, 557), 17, MUTED, REGULAR)
	_text("Full notices and the original brand kit are in assets/.", Vector2(486, 585), 17, MUTED, REGULAR)
	_text("ESC / C / CLICK TO GET BACK TO CHOMPING", Vector2(486, 632), 12, ORANGE, MONO)


func _board_position(grid_position: Vector2) -> Vector2:
	return BOARD_ORIGIN + (grid_position + Vector2.ONE * 0.5) * TILE


func _rounded(rect: Rect2, color: Color, radius: int, border: Color = Color.TRANSPARENT, width: int = 1) -> void:
	# One resource per draw slot, reused next frame without an unbounded color cache.
	if style_index == style_pool.size():
		style_pool.append(StyleBoxFlat.new())
	var style: StyleBoxFlat = style_pool[style_index]
	style_index += 1
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(width if border.a > 0.0 else 0)
	style.anti_aliasing = true
	draw_style_box(style, rect)


func _text(text: String, position: Vector2, size: int, color: Color = INK, font: Font = REGULAR) -> void:
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_center(text: String, position: Vector2, size: int, color: Color = INK, font: Font = REGULAR) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(text, position - Vector2(width * 0.5, 0), size, color, font)


func _text_right(text: String, position: Vector2, size: int, color: Color = INK, font: Font = REGULAR) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(text, position - Vector2(width, 0), size, color, font)


func _texture_fit(texture: Texture2D, rect: Rect2, color: Color = Color.WHITE) -> void:
	var texture_size: Vector2 = texture.get_size()
	var scale_factor: float = minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	var fitted: Vector2 = texture_size * scale_factor
	draw_texture_rect(texture, Rect2(rect.position + (rect.size - fitted) * 0.5, fitted), false, color)


func _glow(position: Vector2, color: Color, radius: float, opacity: float) -> void:
	for i in range(4, 0, -1):
		draw_circle(position, radius * float(i) / 4.0, Color(color, opacity))


func _icon(symbol: ICONS.Symbol, position: Vector2, color: Color, scale_factor: float = 1.0) -> void:
	ICONS.paint(self, symbol, position, color, scale_factor)


func _keycap(rect: Rect2, text: String, key: Key = KEY_NONE) -> void:
	var held: bool = key != KEY_NONE and Input.is_physical_key_pressed(key)
	_rounded(rect, BRAND_STYLE.BRAND_WASH if held else BRAND_STYLE.SURFACE_RAISED, 6, ORANGE if held else BRAND_STYLE.BORDER_STRONG)
	draw_line(Vector2(rect.position.x + 5, rect.end.y - 3), rect.end - Vector2(5, 3), Color(ORANGE, 0.35) if held else EDGE, 1.0)
	_text_center(text, rect.get_center() + Vector2(0, 5), 13, ORANGE if held else INK, MONO_BOLD)


func _shortcut_badge(rect: Rect2, text: String, color: Color = MUTED, background: Color = BRAND_STYLE.SURFACE_RAISED) -> void:
	_rounded(rect, background, 4)
	_text_center(text, rect.get_center() + Vector2(0, 4), 11, color, MONO_BOLD)


func _toolbar_button(rect: Rect2, title: String, key: String, symbol: ICONS.Symbol, active: bool) -> void:
	var hovered: bool = rect.has_point(mouse_position)
	var border: Color = ORANGE if hovered or active else Color(ORANGE, 0.55)
	_rounded(rect, BRAND_STYLE.BRAND_WASH if active or hovered else BRAND_STYLE.INK_DEEP, 11, border)
	_icon(symbol, Vector2(rect.position.x + 23, rect.get_center().y), ORANGE, 0.8)
	_text(title, Vector2(rect.position.x + 43, rect.get_center().y + 5), 13, ORANGE, BOLD)
	_shortcut_badge(Rect2(rect.end.x - 32, rect.position.y + 14, 21, 22), key, ORANGE)


func _draw_toolbar_tooltip() -> void:
	if credits_open:
		return
	var text: String = ""
	var center_x: float = 0.0
	if MUTE_BUTTON.has_point(mouse_position):
		text = "Unmute audio / M" if audio.muted else "Mute audio / M"
		center_x = MUTE_BUTTON.get_center().x
	elif PAUSE_BUTTON.has_point(mouse_position):
		text = "Resume the chaos / P" if game.phase == GameSession.Phase.PAUSED else "Pause the chaos / P"
		center_x = PAUSE_BUTTON.get_center().x
	elif FULLSCREEN_BUTTON.has_point(mouse_position):
		text = "Toggle fullscreen / F11"
		center_x = FULLSCREEN_BUTTON.get_center().x
	if text.is_empty():
		return
	var width: float = REGULAR.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24
	var rect := Rect2(clampf(center_x - width * 0.5, 60, 1540 - width), 89, width, 27)
	_rounded(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.35), 6)
	_rounded(rect, PANEL, 8, Color(ORANGE, 0.35))
	_text_center(text, Vector2(rect.get_center().x, rect.position.y + 18), 13, INK, REGULAR)


func _draw_fork(position: Vector2, color: Color) -> void:
	draw_line(position + Vector2(0, -2), position + Vector2(0, 12), color, 3.0, true)
	draw_arc(position + Vector2(0, -5), 5.0, 0, PI, 16, color, 2.2, true)
	for x in [-5, 0, 5]:
		draw_line(position + Vector2(x, -5), position + Vector2(x, -12), color, 2.0, true)

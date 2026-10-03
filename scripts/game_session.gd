class_name GameSession
extends RefCounted
## Game rules and AI, independent of rendering and audio.

signal arcade_event(kind: String, grid_position: Vector2, points: int)

enum Phase { READY, PLAYING, PAUSED, HIT, GAME_OVER, CLEAR }

const GHOST_COLORS: Array[Color] = [Color("60b9ff"), Color("f19cdb"), Color("72e3cc"), Color("c5b3ff")]
const SCATTER_TARGETS: Array[Vector2i] = [Vector2i(23, 1), Vector2i(1, 1), Vector2i(23, 23), Vector2i(1, 23)]
const POWER_DURATION: float = 8.0

var maze := ArcadeMaze.new()
var player := MazeRunner.new()
var ghosts: Array[Dictionary] = []
var phase: Phase = Phase.READY
var previous_phase: Phase = Phase.PLAYING
var demo: bool = true
var score: int = 0
var lives: int = 3
var level: int = 1
var power_time: float = 0.0
var combo: int = 0
var best_combo: int = 0
var phase_time: float = 0.0
var play_time: float = 0.0
var invulnerable_time: float = 0.0
var collected: int = 0
var fork_active: bool = false
var fork_time: float = 0.0
var fork_spawned: bool = false
var death_position := Vector2.ZERO
var random := RandomNumberGenerator.new()


func _init() -> void:
	random.seed = 20261002
	_reset_actors()


func start(autoplay: bool = false) -> void:
	demo = autoplay
	score = 0
	lives = 3
	level = 1
	play_time = 0.0
	best_combo = 0
	_begin_level()
	arcade_event.emit("start", player.grid_position(), 0)


func _begin_level() -> void:
	maze.reset_pellets()
	collected = 0
	fork_active = false
	fork_spawned = false
	_reset_actors()
	phase = Phase.READY
	phase_time = 1.6 if not demo else 0.5


func _reset_actors() -> void:
	player = MazeRunner.new(ArcadeMaze.PLAYER_START)
	player.direction = Vector2i.LEFT
	player.requested_direction = Vector2i.LEFT
	player.speed = 6.4 + minf((level - 1) * 0.2, 1.0)
	power_time = 0.0
	combo = 0
	invulnerable_time = 1.5
	ghosts.clear()
	for i in 4:
		var mover := MazeRunner.new(Vector2i(10 + i, 11), true)
		ghosts.append({
			"mover": mover,
			"color": GHOST_COLORS[i],
			"wait": 0.8 + i * 1.8,
			"returning": false,
			"exiting": true,
			"index": i,
		})


func turn(direction: Vector2i) -> void:
	if not demo:
		player.request_turn(direction)


func toggle_pause() -> void:
	if phase == Phase.PAUSED:
		phase = previous_phase
	elif phase == Phase.PLAYING or phase == Phase.READY:
		previous_phase = phase
		phase = Phase.PAUSED


func tick(delta: float) -> void:
	if phase == Phase.PAUSED or phase == Phase.GAME_OVER:
		return
	if phase != Phase.PLAYING:
		phase_time -= delta
		if phase_time <= 0.0:
			match phase:
				Phase.READY:
					phase = Phase.PLAYING
				Phase.HIT:
					if lives <= 0:
						if demo:
							start(true)
						else:
							phase = Phase.GAME_OVER
							arcade_event.emit("game_over", death_position, score)
					else:
						_reset_actors()
						phase = Phase.READY
						phase_time = 1.3
				Phase.CLEAR:
					level += 1
					_begin_level()
		return
	play_time += delta
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	var was_powered: bool = power_time > 0.0
	power_time = maxf(0.0, power_time - delta)
	if was_powered and power_time == 0.0:
		combo = 0
		arcade_event.emit("power_end", player.grid_position(), 0)
	if fork_active:
		fork_time -= delta
		if fork_time <= 0.0:
			fork_active = false
	var arrivals: Array[Vector2i] = player.advance(delta, maze, _choose_player_direction)
	for arrival: Vector2i in arrivals:
		_collect(arrival)
		if phase != Phase.PLAYING:
			return
	for ghost: Dictionary in ghosts:
		var mover: MazeRunner = ghost["mover"]
		ghost["wait"] = maxf(0.0, float(ghost["wait"]) - delta)
		if float(ghost["wait"]) > 0.0:
			continue
		mover.speed = 10.0 if bool(ghost["returning"]) else (3.3 if power_time > 0.0 else 4.7 + minf((level - 1) * 0.25, 1.5))
		mover.advance(delta, maze, _choose_ghost_direction.bind(ghost))
		if bool(ghost["returning"]) and mover.cell == ArcadeMaze.HOME:
			ghost["returning"] = false
			ghost["exiting"] = true
			ghost["wait"] = 1.0
		if bool(ghost["exiting"]) and mover.cell.y <= 8:
			ghost["exiting"] = false
		_check_collision(ghost)
		if phase != Phase.PLAYING:
			return


func _choose_player_direction(mover: MazeRunner) -> Vector2i:
	if demo:
		return _autoplay_direction(mover)
	if maze.step(mover.cell, mover.requested_direction) != ArcadeMaze.INVALID and mover.requested_direction != Vector2i.ZERO:
		return mover.requested_direction
	if maze.step(mover.cell, mover.direction) != ArcadeMaze.INVALID:
		return mover.direction
	return Vector2i.ZERO


func _choose_ghost_direction(mover: MazeRunner, ghost: Dictionary) -> Vector2i:
	var returning: bool = ghost["returning"]
	var exiting: bool = ghost["exiting"]
	if returning and mover.cell == ArcadeMaze.HOME:
		return Vector2i.ZERO
	var options: Array[Vector2i] = []
	for direction: Vector2i in ArcadeMaze.DIRECTIONS:
		var destination: Vector2i = maze.step(mover.cell, direction, true)
		if destination == ArcadeMaze.INVALID:
			continue
		if not returning and not exiting and maze.is_home(destination):
			continue
		if direction != -mover.direction:
			options.append(direction)
	if options.is_empty():
		return -mover.direction if maze.step(mover.cell, -mover.direction, true) != ArcadeMaze.INVALID else Vector2i.ZERO
	var target: Vector2i = player.cell
	var index: int = ghost["index"]
	if returning:
		target = ArcadeMaze.HOME
	elif exiting:
		target = ArcadeMaze.EXIT
	elif fmod(play_time, 24.0) < 5.0:
		target = SCATTER_TARGETS[index]
	else:
		match index:
			1:
				target += player.direction * 4
			2:
				var leader: MazeRunner = ghosts[0]["mover"]
				target = player.cell + (player.cell - leader.cell) / 2
			3:
				if Vector2(mover.cell).distance_to(Vector2(player.cell)) < 7.0:
					target = SCATTER_TARGETS[index]
	target = maze.nearest_walkable(target, returning or exiting)
	var distances: Dictionary = maze.distances_from(target, returning or exiting)
	var best: Vector2i = options[0]
	var best_value: float = INF
	for direction: Vector2i in options:
		var destination: Vector2i = maze.step(mover.cell, direction, true)
		var value: float = float(distances.get(destination, 999))
		if power_time > 0.0 and not returning and not exiting:
			value = -value + random.randf_range(-2.0, 2.0)
		if value < best_value:
			best_value = value
			best = direction
	return best


func _autoplay_direction(mover: MazeRunner) -> Vector2i:
	# Breadth-first routes to pickups, penalized by nearby live ghosts.
	var distances: Dictionary = {mover.cell: 0}
	var first_steps: Dictionary = {}
	var queue: Array[Vector2i] = [mover.cell]
	var index: int = 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		for neighbor: Vector2i in maze.neighbors(current):
			if distances.has(neighbor):
				continue
			distances[neighbor] = int(distances[current]) + 1
			first_steps[neighbor] = maze.direction_between(current, neighbor) if current == mover.cell else first_steps[current]
			queue.append(neighbor)
	var best := Vector2i.ZERO
	var best_value: float = INF
	var targets: Dictionary = maze.pellets.duplicate()
	if fork_active:
		targets[Vector2i(12, 14)] = 100
	if power_time > 1.5:
		for ghost: Dictionary in ghosts:
			if not bool(ghost["returning"]) and not bool(ghost["exiting"]) and float(ghost["wait"]) <= 0.0:
				var enemy: MazeRunner = ghost["mover"]
				if int(distances.get(enemy.cell, 999)) < power_time * player.speed * 0.4:
					targets[enemy.cell] = 200
	for target: Vector2i in targets:
		if not first_steps.has(target):
			continue
		var direction: Vector2i = first_steps[target]
		var value: float = float(distances[target])
		var points: int = targets[target]
		if points >= 50:
			if points >= 200:
				# Attract mode should show off the food-chain flip, not just farm dots.
				value = value * 0.12 - 3.0
			else:
				value *= 0.45 if points == 50 else 0.25
		if power_time <= 0.0:
			var next: Vector2i = maze.step(mover.cell, direction)
			for ghost: Dictionary in ghosts:
				if bool(ghost["returning"]) or bool(ghost["exiting"]) or float(ghost["wait"]) > 0.0:
					continue
				var enemy: MazeRunner = ghost["mover"]
				var threat: float = Vector2(next).distance_to(enemy.grid_position())
				if threat < 4.0:
					value += (4.0 - threat) * 25.0
		if direction == -mover.direction:
			value += 0.35
		if value < best_value:
			best_value = value
			best = direction
	return best


func _collect(cell: Vector2i) -> void:
	if maze.pellets.has(cell):
		var points: int = maze.pellets[cell]
		maze.pellets.erase(cell)
		collected += 1
		score += points
		if points == 50:
			power_time = POWER_DURATION
			combo = 0
			for ghost: Dictionary in ghosts:
				if not bool(ghost["returning"]) and not bool(ghost["exiting"]):
					var mover: MazeRunner = ghost["mover"]
					mover.request_turn(-mover.direction)
			arcade_event.emit("power", Vector2(cell), points)
		else:
			arcade_event.emit("dot", Vector2(cell), points)
		if collected >= 65 and not fork_spawned:
			fork_spawned = true
			fork_active = true
			fork_time = 16.0
			arcade_event.emit("fork_spawn", Vector2(12, 14), 0)
		if maze.pellets.is_empty():
			phase = Phase.CLEAR
			phase_time = 2.5
			score += 1000
			arcade_event.emit("clear", player.grid_position(), 1000)
	if fork_active and cell == Vector2i(12, 14):
		fork_active = false
		score += 500
		arcade_event.emit("fork", Vector2(cell), 500)


func _check_collision(ghost: Dictionary) -> void:
	if bool(ghost["returning"]) or bool(ghost["exiting"]) or float(ghost["wait"]) > 0.0:
		return
	var mover: MazeRunner = ghost["mover"]
	var difference: Vector2 = player.grid_position() - mover.grid_position()
	# Compare the short distance across the horizontal wrap tunnel as well.
	if absf(difference.x) > ArcadeMaze.WIDTH * 0.5:
		difference.x = ArcadeMaze.WIDTH - absf(difference.x)
	if difference.length() >= 0.72:
		return
	if power_time > 0.0:
		ghost["returning"] = true
		combo += 1
		best_combo = maxi(best_combo, combo)
		var points: int = 200 * (1 << mini(combo - 1, 3))
		score += points
		arcade_event.emit("ghost", mover.grid_position(), points)
	elif invulnerable_time <= 0.0:
		lives -= 1
		death_position = player.grid_position()
		phase = Phase.HIT
		phase_time = 1.4
		arcade_event.emit("hit", death_position, 0)

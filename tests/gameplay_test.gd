extends SceneTree
## Headless behavioral checks: redot --headless --path . -s tests/gameplay_test.gd

var failures: Array[String] = []
var event_counts: Dictionary = {}


func _initialize() -> void:
	_test_maze_reachability()
	_test_single_tile_corridors()
	_test_buffered_turns_and_reversals()
	_test_tunnel()
	_test_power_and_combo()
	_test_lives_and_game_over()
	_test_pause()
	_test_next_release()
	_test_autoplay_soak()
	if failures.is_empty():
		print("PASS: single-width corridors, reachability, buffered controls, reversals, tunnel, power/combo, lives, pause, releases, and 45s autoplay.")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_maze_reachability() -> void:
	var maze := ArcadeMaze.new()
	var reachable: Dictionary = maze.distances_from(ArcadeMaze.PLAYER_START)
	for cell: Vector2i in maze.pellets:
		_expect(reachable.has(cell), "Unreachable pellet at %s" % cell)
	_expect(not reachable.has(ArcadeMaze.HOME), "The player must not enter the ghost house.")
	_expect(maze.distances_from(ArcadeMaze.HOME, true).has(ArcadeMaze.EXIT), "Ghosts need a route out of the house.")
	_expect(maze.total_pellets > 200, "The maze should have a full arcade run's worth of dots.")
	print("Maze: %d reachable dots, %d traversable player tiles." % [maze.total_pellets, reachable.size()])


func _manual_direction(mover: MazeRunner, maze: ArcadeMaze) -> Vector2i:
	if mover.requested_direction != Vector2i.ZERO and maze.step(mover.cell, mover.requested_direction) != ArcadeMaze.INVALID:
		return mover.requested_direction
	return mover.direction


func _test_single_tile_corridors() -> void:
	var maze := ArcadeMaze.new()
	var wide_sections: Array[Vector2i] = []
	for y in ArcadeMaze.HEIGHT - 1:
		for x in ArcadeMaze.WIDTH - 1:
			var corner := Vector2i(x, y)
			if maze.walkable(corner) and maze.walkable(corner + Vector2i.RIGHT) and maze.walkable(corner + Vector2i.DOWN) and maze.walkable(corner + Vector2i.ONE):
				wide_sections.append(corner)
	_expect(wide_sections.is_empty(), "Playable lanes must be one tile wide; open 2x2 sections at %s." % [wide_sections])
	var reachable: Dictionary = maze.distances_from(ArcadeMaze.PLAYER_START)
	for y in ArcadeMaze.HEIGHT:
		for x in ArcadeMaze.WIDTH:
			var cell := Vector2i(x, y)
			if maze.walkable(cell):
				_expect(reachable.has(cell), "Every playable lane must connect to the maze: %s." % cell)
				_expect(maze.neighbors(cell).size() >= 2, "Classic arcade lanes should have an escape route, not a dead end: %s." % cell)


func _test_buffered_turns_and_reversals() -> void:
	var maze := ArcadeMaze.new()
	var runner := MazeRunner.new(Vector2i(2, 4))
	runner.speed = 6.0
	runner.direction = Vector2i.RIGHT
	runner.requested_direction = Vector2i.RIGHT
	runner.advance(0.05, maze, _manual_direction.bind(maze))
	var before: Vector2 = runner.grid_position()
	runner.request_turn(Vector2i.LEFT)
	_expect(before.distance_to(runner.grid_position()) < 0.0001, "Reversing mid-tile must preserve the exact visual position.")
	runner.advance(0.05, maze, _manual_direction.bind(maze))
	_expect(runner.cell == Vector2i(2, 4), "An immediate reversal should return to the previous tile.")
	var session := GameSession.new()
	session.start(false)
	session.player = MazeRunner.new(Vector2i(2, 4))
	session.player.direction = Vector2i.RIGHT
	session.player.request_turn(Vector2i.UP)
	_expect(session._choose_player_direction(session.player) == Vector2i.RIGHT, "A blocked buffered turn should continue the current direction.")
	session.player.cell = Vector2i(6, 4)
	_expect(session._choose_player_direction(session.player) == Vector2i.UP, "The buffered turn must activate at the first valid intersection.")


func _test_tunnel() -> void:
	var maze := ArcadeMaze.new()
	var runner := MazeRunner.new(Vector2i(0, ArcadeMaze.TUNNEL_ROW))
	runner.speed = 6.0
	runner.direction = Vector2i.LEFT
	runner.requested_direction = Vector2i.LEFT
	runner.advance(1.0 / runner.speed, maze, _manual_direction.bind(maze))
	_expect(runner.cell == Vector2i(24, ArcadeMaze.TUNNEL_ROW), "The left tunnel should wrap to the right side.")
	_expect(maze.step(Vector2i(24, ArcadeMaze.TUNNEL_ROW), Vector2i.RIGHT) == Vector2i(0, ArcadeMaze.TUNNEL_ROW), "The right tunnel should wrap to the left side.")
	_expect(maze.step(Vector2i(0, 4), Vector2i.LEFT) == ArcadeMaze.INVALID, "Only the tunnel row may wrap.")


func _put_ghost_on_player(session: GameSession, index: int) -> Dictionary:
	var ghost: Dictionary = session.ghosts[index]
	var mover: MazeRunner = ghost["mover"]
	mover.cell = session.player.cell
	mover.moving = false
	ghost["wait"] = 0.0
	ghost["exiting"] = false
	ghost["returning"] = false
	return ghost


func _test_power_and_combo() -> void:
	var session := GameSession.new()
	session.start(false)
	session.player.cell = Vector2i(1, 1)
	session._collect(session.player.cell)
	_expect(session.score == 50 and session.power_time == GameSession.POWER_DURATION, "A power dot must score 50 and start frightened mode.")
	var ghost: Dictionary = _put_ghost_on_player(session, 0)
	session._check_collision(ghost)
	_expect(session.score == 250 and session.combo == 1 and bool(ghost["returning"]), "The first ghost must score 200 and return home.")
	session._check_collision(_put_ghost_on_player(session, 1))
	_expect(session.score == 650 and session.combo == 2, "The second ghost in the combo must score 400.")
	session.power_time = 0.0
	session.invulnerable_time = 0.0
	session._check_collision(ghost)
	_expect(session.lives == 3, "Returning ghosts must never cost a life.")


func _test_lives_and_game_over() -> void:
	var session := GameSession.new()
	session.start(false)
	session.phase = GameSession.Phase.PLAYING
	session._collect(Vector2i(11, 18))
	var remaining: int = session.maze.pellets.size()
	session.invulnerable_time = 0.0
	session._check_collision(_put_ghost_on_player(session, 0))
	_expect(session.lives == 2 and session.phase == GameSession.Phase.HIT, "A normal collision must cost one life and show the hit state.")
	session.tick(1.5)
	_expect(session.phase == GameSession.Phase.READY and session.maze.pellets.size() == remaining and session.score == 10, "Respawning must keep score and eaten dots.")
	session.phase = GameSession.Phase.PLAYING
	session.lives = 1
	session.invulnerable_time = 0.0
	session._check_collision(_put_ghost_on_player(session, 0))
	session.tick(1.5)
	_expect(session.phase == GameSession.Phase.GAME_OVER and session.lives == 0, "Losing the final life should end a human run.")
	session.start(false)
	_expect(session.lives == 3 and session.score == 0 and session.level == 1, "Restart should reset the run.")


func _test_pause() -> void:
	var session := GameSession.new()
	session.start(false)
	session.phase = GameSession.Phase.PLAYING
	session.power_time = 3.0
	session.tick(0.03)
	var position: Vector2 = session.player.grid_position()
	var remaining_power: float = session.power_time
	session.toggle_pause()
	session.tick(2.0)
	_expect(session.player.grid_position() == position and session.power_time == remaining_power, "Pause must freeze movement and gameplay timers.")
	session.toggle_pause()
	_expect(session.phase == GameSession.Phase.PLAYING, "Unpausing must restore the previous state.")


func _test_next_release() -> void:
	var session := GameSession.new()
	session.start(false)
	session.phase = GameSession.Phase.PLAYING
	session.maze.pellets = {Vector2i(11, 18): 10}
	session._collect(Vector2i(11, 18))
	_expect(session.phase == GameSession.Phase.CLEAR and session.score == 1010, "Clearing the maze should award a 1000-point release bonus.")
	session.tick(3.0)
	_expect(session.level == 2 and session.maze.pellets.size() == session.maze.total_pellets and session.score == 1010, "The next release must repopulate dots and preserve the score.")


func _count_event(kind: String, _position: Vector2, _points: int) -> void:
	event_counts[kind] = int(event_counts.get(kind, 0)) + 1


func _test_autoplay_soak() -> void:
	var session := GameSession.new()
	session.arcade_event.connect(_count_event)
	session.start(true)
	for i in 5400:
		session.tick(1.0 / 120.0)
		_expect(session.maze.walkable(session.player.cell), "Autoplay left a traversable tile at step %d." % i)
		for ghost: Dictionary in session.ghosts:
			var mover: MazeRunner = ghost["mover"]
			_expect(session.maze.walkable(mover.cell, true), "A ghost left the maze at step %d." % i)
	_expect(int(event_counts.get("dot", 0)) >= 30, "Autoplay should actually collect dots.")
	_expect(int(event_counts.get("power", 0)) >= 1, "Autoplay should demonstrate power dots.")
	print("45s autoplay events: ", event_counts)

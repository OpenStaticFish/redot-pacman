class_name MazeRunner
extends RefCounted
## Tile-centered motion with buffered turns, immediate reversals, and tunnels.

var cell: Vector2i
var next_cell: Vector2i
var direction := Vector2i.ZERO
var requested_direction := Vector2i.ZERO
var progress: float = 0.0
var moving: bool = false
var speed: float = 6.4
var allow_home: bool = false


func _init(start: Vector2i = ArcadeMaze.PLAYER_START, home_access: bool = false) -> void:
	cell = start
	next_cell = start
	allow_home = home_access


func grid_position() -> Vector2:
	return Vector2(cell) + Vector2(direction) * progress if moving else Vector2(cell)


func request_turn(new_direction: Vector2i) -> void:
	if new_direction == Vector2i.ZERO:
		return
	requested_direction = new_direction
	if moving and new_direction == -direction:
		var old_cell: Vector2i = cell
		cell = next_cell
		next_cell = old_cell
		direction = new_direction
		progress = 1.0 - progress


func advance(delta: float, maze: ArcadeMaze, selector: Callable) -> Array[Vector2i]:
	var arrivals: Array[Vector2i] = []
	var distance: float = delta * speed
	var safety: int = 0
	while distance > 0.00001 and safety < 16:
		safety += 1
		if not moving:
			var selected: Vector2i = selector.call(self)
			if selected == Vector2i.ZERO:
				break
			next_cell = maze.step(cell, selected, allow_home)
			if next_cell == ArcadeMaze.INVALID:
				break
			direction = selected
			moving = true
			progress = 0.0
		var amount: float = minf(distance, 1.0 - progress)
		progress += amount
		distance -= amount
		if progress >= 0.99999:
			cell = next_cell
			progress = 0.0
			moving = false
			arrivals.append(cell)
	return arrivals

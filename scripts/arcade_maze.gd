class_name ArcadeMaze
extends RefCounted
## A single source of truth for walls, pickups, tunnels, and pathfinding.

const ROWS: Array[String] = [
	"#########################",
	"#o..........#..........o#",
	"#.####.####.#.####.####.#",
	"#.####.####.#.####.####.#",
	"#.......................#",
	"#.####.#.#######.#.####.#",
	"#......#....#....#......#",
	"######.#### # ####.######",
	"######.#         #.######",
	"######.# ### ### #.######",
	"######.# #     # #.######",
	"######.# #     # #.######",
	".......  #     #  .......",
	"######.# ####### #.######",
	"######.#         #.######",
	"######.# ####### #.######",
	"#...........#...........#",
	"#.####.####.#.####.####.#",
	"#o...#.............#...o#",
	"####.#.#.#######.#.#.####",
	"#......#....#....#......#",
	"#.#########.#.#########.#",
	"#.#########.#.#########.#",
	"#.......................#",
	"#########################",
]
const WIDTH: int = 25
const HEIGHT: int = 25
const TUNNEL_ROW: int = 12
const PLAYER_START := Vector2i(12, 18)
const HOME := Vector2i(12, 11)
const EXIT := Vector2i(12, 8)
const INVALID := Vector2i(-999, -999)
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]

var pellets: Dictionary = {}
var total_pellets: int = 0
var contours: Array[PackedVector2Array] = []


func _init() -> void:
	reset_pellets()
	_build_contours()


func reset_pellets() -> void:
	pellets.clear()
	for y in HEIGHT:
		assert(ROWS[y].length() == WIDTH, "Maze rows must have equal width.")
		for x in WIDTH:
			var character: String = ROWS[y][x]
			if character == "." or character == "o":
				pellets[Vector2i(x, y)] = 50 if character == "o" else 10
	pellets.erase(PLAYER_START)
	total_pellets = pellets.size()


func is_wall(cell: Vector2i) -> bool:
	return in_bounds(cell) and ROWS[cell.y][cell.x] == "#"


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT


func is_home(cell: Vector2i) -> bool:
	return cell.x >= 10 and cell.x <= 14 and cell.y >= 9 and cell.y <= 12


func walkable(cell: Vector2i, allow_home: bool = false) -> bool:
	if not in_bounds(cell):
		return false
	var character: String = ROWS[cell.y][cell.x]
	return character != "#" and character != "X" and (allow_home or not is_home(cell))


func step(cell: Vector2i, direction: Vector2i, allow_home: bool = false) -> Vector2i:
	var destination: Vector2i = cell + direction
	if cell.y == TUNNEL_ROW and direction.y == 0:
		destination.x = posmod(destination.x, WIDTH)
	return destination if walkable(destination, allow_home) else INVALID


func neighbors(cell: Vector2i, allow_home: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		var destination: Vector2i = step(cell, direction, allow_home)
		if destination != INVALID:
			result.append(destination)
	return result


func distances_from(origin: Vector2i, allow_home: bool = false) -> Dictionary:
	var distances: Dictionary = {origin: 0}
	var queue: Array[Vector2i] = [origin]
	var index: int = 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		for neighbor: Vector2i in neighbors(current, allow_home):
			if not distances.has(neighbor):
				distances[neighbor] = int(distances[current]) + 1
				queue.append(neighbor)
	return distances


func nearest_walkable(target: Vector2i, allow_home: bool = false) -> Vector2i:
	var best: Vector2i = PLAYER_START
	var best_distance: int = 99999
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if walkable(cell, allow_home):
				var distance: int = absi(x - target.x) + absi(y - target.y)
				if distance < best_distance:
					best_distance = distance
					best = cell
	return best


func direction_between(origin: Vector2i, destination: Vector2i) -> Vector2i:
	var direction: Vector2i = destination - origin
	if absi(direction.x) > 1:
		direction.x = -signi(direction.x)
	return direction


func _add_edge(edges: Dictionary, start: Vector2i, end: Vector2i) -> void:
	if not edges.has(start):
		edges[start] = []
	(edges[start] as Array).append(end)


func _build_contours() -> void:
	# Trace the union of wall tiles, so walls have continuous neon outlines.
	var edges: Dictionary = {}
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if not is_wall(cell):
				continue
			if not is_wall(cell + Vector2i.UP):
				_add_edge(edges, cell, cell + Vector2i.RIGHT)
			if not is_wall(cell + Vector2i.RIGHT):
				_add_edge(edges, cell + Vector2i.RIGHT, cell + Vector2i.ONE)
			if not is_wall(cell + Vector2i.DOWN):
				_add_edge(edges, cell + Vector2i.ONE, cell + Vector2i.DOWN)
			if not is_wall(cell + Vector2i.LEFT):
				_add_edge(edges, cell + Vector2i.DOWN, cell)
	while not edges.is_empty():
		var start: Vector2i = edges.keys()[0]
		var current: Vector2i = start
		var previous_direction := Vector2i.RIGHT
		var polygon := PackedVector2Array()
		var safety: int = 0
		while edges.has(current) and safety < 5000:
			polygon.append(Vector2(current))
			var options: Array = edges[current]
			var choice: int = 0
			var best_turn: int = -100
			for i in options.size():
				var next_direction: Vector2i = (options[i] as Vector2i) - current
				var cross: int = previous_direction.x * next_direction.y - previous_direction.y * next_direction.x
				var turn: int = 2 if cross > 0 else (1 if next_direction == previous_direction else 0)
				if turn > best_turn:
					best_turn = turn
					choice = i
			var next: Vector2i = options[choice]
			options.remove_at(choice)
			if options.is_empty():
				edges.erase(current)
			previous_direction = next - current
			current = next
			safety += 1
			if current == start:
				break
		if polygon.size() >= 4:
			contours.append(polygon)

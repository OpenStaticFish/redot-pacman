extends SceneTree
## Bake static, native-resolution art so WebGL need not retessellate it each frame.

class MazeArt:
	extends "res://scripts/arcade_view.gd"

	func _draw() -> void:
		_draw_maze()


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	# A fixed offscreen viewport avoids desktop window-manager resize/scaling.
	var canvas := SubViewport.new()
	canvas.size = Vector2i(1600, 900)
	canvas.transparent_bg = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	DirAccess.make_dir_recursive_absolute("res://assets/web")
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(1600, 900)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/redot_backdrop.gdshader")
	backdrop.material = material
	canvas.add_child(backdrop)
	await process_frame
	await RenderingServer.frame_post_draw
	_save(canvas.get_texture().get_image(), "backdrop")
	backdrop.queue_free()
	await process_frame
	var maze := MazeArt.new()
	canvas.add_child(maze)
	maze.set_process(false)
	maze.set_physics_process(false)
	maze.audio.stop_all()
	for child: Node in maze.get_children():
		if child is CanvasItem:
			child.hide()
	for powered: bool in [false, true]:
		maze.game.power_time = 8.0 if powered else 0.0
		maze.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := canvas.get_texture().get_image().get_region(Rect2i(435, 163, 650, 650))
		_save(image, "maze_power" if powered else "maze_normal")
	maze.queue_free()
	await process_frame
	quit()


func _save(image: Image, name: String) -> void:
	var path: String = "res://assets/web/%s.png" % name
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Could not bake %s: %s" % [path, error_string(error)])
		quit(1)
	else:
		print("Baked ", path)

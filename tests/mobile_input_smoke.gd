extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var packed_scene: PackedScene = load("res://scenes/Main.tscn")
	assert(packed_scene != null, "Main scene could not be loaded")
	var game: Node = packed_scene.instantiate()
	root.add_child(game)
	await process_frame

	# Two-finger pan and pinch must move and zoom the battle camera without selecting the map.
	var camera: Camera2D = game.get_node("Camera2D")
	var start_position: Vector2 = camera.position
	var start_zoom: Vector2 = camera.zoom

	var first_touch := InputEventScreenTouch.new()
	first_touch.index = 0
	first_touch.position = Vector2(100, 100)
	first_touch.pressed = true
	game.call("_unhandled_input", first_touch)

	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 1
	second_touch.position = Vector2(300, 100)
	second_touch.pressed = true
	game.call("_unhandled_input", second_touch)

	var pinch_drag := InputEventScreenDrag.new()
	pinch_drag.index = 1
	pinch_drag.position = Vector2(420, 100)
	game.call("_unhandled_input", pinch_drag)

	assert(camera.zoom.x > start_zoom.x, "Pinch-out gesture did not zoom the camera in")
	assert(camera.position.distance_to(start_position) > 0.1, "Two-finger pan did not move the camera")

	second_touch.pressed = false
	second_touch.position = Vector2(420, 100)
	game.call("_unhandled_input", second_touch)
	first_touch.pressed = false
	game.call("_unhandled_input", first_touch)
	assert(game.get("selected_units").is_empty(), "A two-finger camera gesture must not select or command units")

	# A three-unit formation must receive distinct destinations and obstacle-safe A* routes.
	var selected_units: Array[Dictionary] = game.get("selected_units")
	var group: Array[Dictionary] = []
	for i in range(3):
		var start: Vector2 = Vector2(900.0 + float(i) * 22.0, 1500.0 + float(i) * 12.0)
		var unit: Dictionary = {
			"pos": start,
			"destination": start,
			"path": [],
			"path_index": 0
		}
		selected_units.append(unit)
		group.append(unit)

	game.call("_issue_group_move", Vector2(5200, 1600))
	var pathfinder: AStarGrid2D = game.get("pathfinder")
	var destinations: Array[Vector2] = []
	for unit in group:
		var destination: Vector2 = unit["destination"]
		destinations.append(destination)
		var route: Array = unit["path"]
		assert(not route.is_empty(), "A formation member did not receive an A* route")
		var crossed_bridge := false
		for waypoint in route:
			var cell: Vector2i = game.call("_world_to_grid", waypoint)
			assert(not pathfinder.is_point_solid(cell), "A formation route crossed a blocked river cell")
			if cell.y >= 29 and cell.y <= 35:
				crossed_bridge = true
		assert(crossed_bridge, "A formation route did not use the road bridge")

	assert(destinations[0].distance_to(destinations[1]) > 20.0, "Formation slots overlap")
	assert(destinations[0].distance_to(destinations[2]) > 20.0, "Formation rows overlap")

	print("PASS: mobile two-finger camera pan/pinch, gesture isolation, three-unit formation slots and A* bridge routing")
	game.queue_free()
	quit()

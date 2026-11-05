extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var packed_scene: PackedScene = load("res://scenes/Main.tscn")
	assert(packed_scene != null, "Main scene could not be loaded")
	var game: Node = packed_scene.instantiate()
	root.add_child(game)
	await process_frame

	var start_cell: Vector2i = game.call("_world_to_grid", Vector2(800, 1600))
	var goal_cell: Vector2i = game.call("_world_to_grid", Vector2(5400, 1600))
	assert(start_cell == Vector2i(8, 55), "Player base grid conversion is incorrect")
	assert(goal_cell == Vector2i(55, 8), "Enemy base grid conversion is incorrect")

	var test_unit := {
		"pos": Vector2(800, 1600),
		"destination": Vector2(800, 1600),
		"path": [],
		"path_index": 0
	}
	game.call("_set_unit_destination", test_unit, Vector2(5400, 1600))
	var route: Array = test_unit["path"]
	assert(not route.is_empty(), "A* did not find a route between the two bases")
	var pathfinder: AStarGrid2D = game.get("pathfinder")
	var crossed_bridge := false
	for waypoint in route:
		var cell: Vector2i = game.call("_world_to_grid", waypoint)
		assert(not pathfinder.is_point_solid(cell), "A* route crossed a blocked river cell")
		if cell.y >= 29 and cell.y <= 35:
			crossed_bridge = true
	assert(crossed_bridge, "A* route did not use the road bridge")

	var original_credits: int = game.get("credits")
	game.set("credits", original_credits + 123)
	game.call("_save_game")
	game.set("credits", 0)
	game.call("_load_game")
	assert(int(game.get("credits")) == original_credits + 123, "Local save/load did not restore credits")

	print("PASS: scene load, isometric grid mapping, A* river bridge routing, and local save/load")
	game.queue_free()
	quit()

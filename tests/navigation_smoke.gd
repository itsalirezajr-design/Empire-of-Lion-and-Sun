extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var packed_scene: PackedScene = load("res://scenes/Main.tscn")
	assert(packed_scene != null, "Main scene could not be loaded")
	var game: Node = packed_scene.instantiate()
	root.add_child(game)
	await process_frame

	# Phase 1: scene, isometric mapping, A* river bridge and local battle state.
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

	# Phase 2: build all three structures, enforce placement, and test production queues.
	game.set("credits", 3000)
	game.set("materials", 3000)
	game.call("_begin_build_barracks")
	game.call("_place_building", Vector2(1100, 1400))
	game.call("_begin_build_factory")
	game.call("_place_building", Vector2(1300, 1400))
	game.call("_begin_build_depot")
	game.call("_place_building", Vector2(1100, 1700))
	var buildings: Array = game.get("buildings")
	assert(buildings.size() == 3, "Barracks, factory and depot were not all placed")
	assert(float(buildings[0]["construction_remaining"]) > 0.0, "New building skipped its construction timer")

	# A blocked placement must not spend resources or create another structure.
	var credits_before_blocked_place: int = game.get("credits")
	game.call("_begin_build_barracks")
	game.call("_place_building", Vector2(1100, 1400))
	assert(buildings.size() == 3, "Overlapping building placement was accepted")
	assert(int(game.get("credits")) == credits_before_blocked_place, "Rejected placement charged resources")

	for building in buildings:
		building["construction_remaining"] = 0.0
	game.call("_enqueue_unit", "infantry")
	game.call("_enqueue_unit", "tank")
	game.call("_enqueue_unit", "apc")
	assert(buildings[0]["queue"].size() == 1, "Infantry was not queued at barracks")
	assert(buildings[1]["queue"].size() == 2, "Armored units were not queued at factory")

	# Enemy AI must attack a nearby friendly structure rather than ignoring it.
	var enemy_units: Array = game.get("enemy_units")
	game.call("_spawn_unit", "infantry", "enemy", buildings[0]["pos"] + Vector2(0, 80))
	var no_opponents: Array[Dictionary] = []
	var building_hp_before_attack: float = buildings[0]["hp"]
	game.call("_update_team", enemy_units, no_opponents, 1.0, false)
	assert(float(buildings[0]["hp"]) < building_hp_before_attack, "Enemy AI did not damage a nearby friendly building")

	# Upgrade and repair controls must update building state and consume resources.
	game.set("selected_building", buildings[0])
	buildings[0]["hp"] = 300.0
	game.call("_repair_selected_building")
	assert(float(buildings[0]["hp"]) > 300.0, "Building repair did not restore health")
	var previous_level: int = buildings[0]["level"]
	game.call("_upgrade_selected_building")
	assert(int(buildings[0]["level"]) == previous_level + 1, "Building upgrade did not increase level")

	# Version 2 save data must preserve buildings and their production queues.
	var saved_credits: int = game.get("credits")
	game.call("_save_game")
	game.set("credits", 0)
	game.set("materials", 0)
	game.call("_load_game")
	assert(int(game.get("credits")) == saved_credits, "Save/load did not restore credits")
	var restored_buildings: Array = game.get("buildings")
	assert(restored_buildings.size() == 3, "Save/load did not restore buildings")
	assert(restored_buildings[0]["queue"].size() == 1, "Save/load did not restore barracks queue")
	assert(restored_buildings[1]["queue"].size() == 2, "Save/load did not restore factory queue")
	assert(int(game.call("_resource_capacity")) == 1500, "Depot did not increase resource capacity")
	assert(int(game.get("materials")) > 0, "Save/load did not restore materials")

	# Advance production and ensure the barracks actually spawns a unit.
	restored_buildings[0]["production_remaining"] = 0.01
	restored_buildings[1]["production_remaining"] = 0.01
	game.call("_update_buildings", 1.0)
	restored_buildings[1]["production_remaining"] = 0.01
	game.call("_update_buildings", 1.0)
	var player_units: Array = game.get("player_units")
	assert(player_units.size() == 6, "Barracks/factory did not produce infantry, tank and APC")

	print("PASS: phase 1 navigation/save plus phase 2 construction, placement, production, capacity, repair, upgrade and persistence")
	game.queue_free()
	quit()

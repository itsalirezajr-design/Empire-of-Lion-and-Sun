extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var packed_scene: PackedScene = load("res://scenes/Main.tscn")
	assert(packed_scene != null, "Main scene could not be loaded")
	var game: Node = packed_scene.instantiate()
	root.add_child(game)
	await process_frame

	var player_units: Array[Dictionary] = game.get("player_units")
	var enemy_units: Array[Dictionary] = game.get("enemy_units")
	player_units.clear()
	enemy_units.clear()

	# A unit killed by the first team update must be removed before it can retaliate.
	var player: Dictionary = _make_unit("player", Vector2(2000, 1600), 100.0)
	var defeated_enemy: Dictionary = _make_unit("enemy", Vector2(2050, 1600), 1.0)
	player_units.append(player)
	enemy_units.append(defeated_enemy)
	game.call("_update_team", player_units, enemy_units, 0.1, true)
	assert(float(defeated_enemy["hp"]) <= 0.0, "Player attack did not defeat the low-health enemy")
	game.call("_update_team", enemy_units, player_units, 0.1, false)
	assert(is_equal_approx(float(player["hp"]), 100.0), "A defeated enemy retaliated before being removed")
	assert(enemy_units.is_empty(), "Defeated enemy was not removed from its team")

	# Living units must exchange damage, while the attack cooldown prevents over-firing.
	player["cooldown"] = 0.0
	var living_enemy: Dictionary = _make_unit("enemy", Vector2(2050, 1600), 100.0)
	enemy_units.append(living_enemy)
	game.call("_update_team", player_units, enemy_units, 0.1, true)
	var enemy_hp_after_first_shot: float = float(living_enemy["hp"])
	assert(enemy_hp_after_first_shot < 100.0, "Player unit did not damage a nearby enemy")
	game.call("_update_team", player_units, enemy_units, 0.1, true)
	assert(is_equal_approx(float(living_enemy["hp"]), enemy_hp_after_first_shot), "Attack cooldown allowed an extra shot")
	game.call("_update_team", enemy_units, player_units, 0.1, false)
	assert(float(player["hp"]) < 100.0, "Living enemy AI did not retaliate against a nearby unit")

	# The match loop must resolve both command-center outcomes.
	player_units.clear()
	enemy_units.clear()
	var buildings: Array[Dictionary] = game.get("buildings")
	buildings.clear()
	game.set("match_over", false)
	game.set("enemy_base_hp", 0.0)
	game.call("_process", 0.016)
	assert(bool(game.get("match_over")), "Destroying the enemy command center did not end the match")
	assert(str(game.get("match_message")).begins_with("VICTORY"), "Enemy command-center loss did not produce victory")

	game.set("match_over", false)
	game.set("enemy_base_hp", 1200.0)
	game.set("player_base_hp", 0.0)
	game.call("_process", 0.016)
	assert(bool(game.get("match_over")), "Destroying the player command center did not end the match")
	assert(str(game.get("match_message")).begins_with("DEFEAT"), "Player command-center loss did not produce defeat")

	print("PASS: unit combat, attack cooldown, defeated-unit cleanup, enemy retaliation and victory/defeat resolution")
	game.queue_free()
	quit()


func _make_unit(team: String, position: Vector2, health: float) -> Dictionary:
	return {
		"kind": "infantry",
		"team": team,
		"pos": position,
		"destination": position,
		"hp": health,
		"max_hp": 100.0,
		"speed": 115.0,
		"damage": 12.0,
		"cooldown": 0.0,
		"path": [],
		"path_index": 0
	}

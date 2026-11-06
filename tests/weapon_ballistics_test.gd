extends SceneTree

const Ballistics = preload("res://scripts/weapon_ballistics.gd")

func _initialize() -> void:
	var idle_spread := Ballistics.calculate_spread(0.18, 0.0, 0.0, true, 0.95, 1.65)
	assert(is_equal_approx(idle_spread, 0.18), "Standing still should use base spread.")

	var moving_spread := Ballistics.calculate_spread(0.18, 0.0, 9.0, true, 0.95, 1.65)
	assert(moving_spread > idle_spread, "Movement should increase spread.")

	var airborne_spread := Ballistics.calculate_spread(0.18, 0.0, 0.0, false, 0.95, 1.65)
	assert(airborne_spread > idle_spread, "Airborne firing should increase spread.")

	var burst_spread := Ballistics.calculate_spread(0.18, 1.0, 0.0, true, 0.95, 1.65)
	assert(burst_spread > idle_spread, "Repeated shots should increase spread.")

	var direction := Ballistics.direction_with_spread(
		Vector3.FORWARD, Vector3.RIGHT, Vector3.UP, 2.0, 0.7, -0.4
	)
	assert(absf(direction.length() - 1.0) < 0.0001, "Spread direction must stay normalized.")
	assert(direction.z < 0.0, "Shot direction must remain forward.")

	var perfect_direction := Ballistics.direction_with_spread(
		Vector3.FORWARD, Vector3.RIGHT, Vector3.UP, 0.0, 1.0, -1.0
	)
	assert(perfect_direction.is_equal_approx(Vector3.FORWARD), "Zero spread must preserve aim.")

	print("PASS: weapon spread, movement penalty, airborne penalty, bloom and shot direction.")
	quit()

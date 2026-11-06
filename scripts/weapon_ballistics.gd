extends RefCounted
class_name WeaponBallistics

static func calculate_spread(
	base_spread_degrees: float,
	shot_bloom_degrees: float,
	horizontal_speed: float,
	grounded: bool,
	movement_spread_degrees: float,
	airborne_spread_degrees: float,
	movement_speed_reference: float = 9.0
) -> float:
	var movement_factor := clampf(horizontal_speed / maxf(movement_speed_reference, 0.001), 0.0, 1.0)
	var movement_spread := movement_factor * maxf(movement_spread_degrees, 0.0)
	var airborne_spread := 0.0 if grounded else maxf(airborne_spread_degrees, 0.0)
	return maxf(0.0, base_spread_degrees + maxf(shot_bloom_degrees, 0.0) + movement_spread + airborne_spread)

static func direction_with_spread(
	forward: Vector3,
	right: Vector3,
	up: Vector3,
	spread_degrees: float,
	horizontal_sample: float,
	vertical_sample: float
) -> Vector3:
	var spread_radius := tan(deg_to_rad(maxf(spread_degrees, 0.0)))
	var direction := (
		forward.normalized()
		+ right.normalized() * clampf(horizontal_sample, -1.0, 1.0) * spread_radius
		+ up.normalized() * clampf(vertical_sample, -1.0, 1.0) * spread_radius
	)
	return direction.normalized()

extends Node2D

const MAP_SIZE := Vector2(3200, 3200)
const ISO_TILE_WIDTH := 96.0
const ISO_TILE_HEIGHT := 48.0
const ISO_GRID_SIZE := 64
const UNIT_SPEED := 115.0
const ATTACK_RANGE := 145.0
const ATTACK_INTERVAL := 0.85
const PLAYER_BASE := Vector2(320, 1600)
const ENEMY_BASE := Vector2(2880, 1600)

var player_units: Array[Dictionary] = []
var enemy_units: Array[Dictionary] = []
var selected_units: Array[Dictionary] = []
var player_base_hp := 1200.0
var enemy_base_hp := 1200.0
var credits := 500
var fuel := 300
var materials := 300
var elapsed := 0.0
var enemy_spawn_clock := 0.0
var income_clock := 0.0
var touch_origin := Vector2.ZERO
var dragging := false
var drag_end := Vector2.ZERO
var match_over := false
var match_message := ""
var active_touches: Dictionary = {}
var previous_pinch_distance := 0.0
var previous_touch_midpoint := Vector2.ZERO
var multitouch_used := false
var mouse_pan_active := false
var mouse_pan_last := Vector2.ZERO

@onready var camera: Camera2D = $Camera2D
@onready var stats_label: Label = $HUD/Stats


func _ready() -> void:
	camera.position = Vector2(1600, 1600)
	camera.make_current()
	camera.zoom = Vector2.ONE
	_clamp_camera_position()
	_spawn_unit("infantry", "player", PLAYER_BASE + Vector2(150, -100))
	_spawn_unit("tank", "player", PLAYER_BASE + Vector2(220, 0))
	_spawn_unit("apc", "player", PLAYER_BASE + Vector2(150, 100))
	_spawn_unit("infantry", "enemy", ENEMY_BASE + Vector2(-150, -100))
	_spawn_unit("tank", "enemy", ENEMY_BASE + Vector2(-220, 0))
	_spawn_unit("apc", "enemy", ENEMY_BASE + Vector2(-150, 100))
	_update_hud()
	queue_redraw()


func _process(delta: float) -> void:
	if match_over:
		return
	elapsed += delta
	income_clock += delta
	enemy_spawn_clock += delta
	if income_clock >= 3.0:
		credits += 45
		fuel += 12
		materials += 18
		income_clock = 0.0
	if enemy_spawn_clock >= 14.0:
		_spawn_unit("infantry" if int(elapsed) % 2 == 0 else "tank", "enemy", ENEMY_BASE + Vector2(-100, randf_range(-180, 180)))
		enemy_spawn_clock = 0.0
	_update_team(player_units, enemy_units, delta, true)
	_update_team(enemy_units, player_units, delta, false)
	if player_base_hp <= 0.0:
		match_over = true
		match_message = "DEFEAT — Your command center was destroyed"
	elif enemy_base_hp <= 0.0:
		match_over = true
		match_message = "VICTORY — Enemy command center destroyed"
	_update_hud()
	queue_redraw()


func _spawn_unit(kind: String, team: String, at: Vector2) -> void:
	var unit := {
		"kind": kind,
		"team": team,
		"pos": at,
		"destination": at,
		"hp": 100.0,
		"max_hp": 100.0,
		"speed": UNIT_SPEED,
		"damage": 12.0,
		"cooldown": randf_range(0.0, 0.4)
	}
	match kind:
		"tank":
			unit["hp"] = 190.0
			unit["max_hp"] = 190.0
			unit["speed"] = 78.0
			unit["damage"] = 27.0
		"apc":
			unit["hp"] = 145.0
			unit["max_hp"] = 145.0
			unit["speed"] = 105.0
			unit["damage"] = 15.0
	if team == "player":
		player_units.append(unit)
	else:
		enemy_units.append(unit)


func _update_team(team: Array[Dictionary], opponents: Array[Dictionary], delta: float, is_player: bool) -> void:
	for i in range(team.size() - 1, -1, -1):
		var unit: Dictionary = team[i]
		unit["cooldown"] = maxf(0.0, float(unit["cooldown"]) - delta)
		var pos: Vector2 = unit["pos"]
		var target: Dictionary = _nearest_enemy(pos, opponents)
		if not target.is_empty() and pos.distance_to(target["pos"]) <= ATTACK_RANGE:
			if float(unit["cooldown"]) <= 0.0:
				target["hp"] = float(target["hp"]) - float(unit["damage"])
				unit["cooldown"] = ATTACK_INTERVAL
		else:
			var destination: Vector2 = unit["destination"]
			if not is_player and (destination == ENEMY_BASE or pos.distance_to(PLAYER_BASE) < pos.distance_to(ENEMY_BASE)):
				destination = PLAYER_BASE
			if pos.distance_to(destination) > 7.0:
				pos = pos.move_toward(destination, float(unit["speed"]) * delta)
				unit["pos"] = pos
			elif is_player:
				if pos.distance_to(ENEMY_BASE) <= 150.0 and float(unit["cooldown"]) <= 0.0:
					enemy_base_hp -= float(unit["damage"])
					unit["cooldown"] = ATTACK_INTERVAL
			elif not is_player:
				if pos.distance_to(PLAYER_BASE) <= 150.0 and float(unit["cooldown"]) <= 0.0:
					player_base_hp -= float(unit["damage"])
					unit["cooldown"] = ATTACK_INTERVAL
		if float(unit["hp"]) <= 0.0:
			if selected_units.has(unit):
				selected_units.erase(unit)
			team.remove_at(i)


func _nearest_enemy(pos: Vector2, opponents: Array[Dictionary]) -> Dictionary:
	var nearest: Dictionary = {}
	var best_distance := ATTACK_RANGE
	for candidate in opponents:
		var distance: float = pos.distance_to(candidate["pos"])
		if distance < best_distance and float(candidate["hp"]) > 0.0:
			best_distance = distance
			nearest = candidate
	return nearest


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _handle_tap(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var clicked_unit := _unit_at(world_pos)
	if not clicked_unit.is_empty():
		if clicked_unit["team"] == "player":
			if not Input.is_key_pressed(KEY_SHIFT):
				selected_units.clear()
			if not selected_units.has(clicked_unit):
				selected_units.append(clicked_unit)
		elif not selected_units.is_empty():
			for unit in selected_units:
				unit["destination"] = clicked_unit["pos"]
	else:
		if not selected_units.is_empty():
			for unit in selected_units:
				unit["destination"] = _clamp_to_map(world_pos)
		else:
			selected_units.clear()


func _unit_at(world_pos: Vector2) -> Dictionary:
	for unit in player_units:
		if world_pos.distance_to(unit["pos"]) <= 34.0:
			return unit
	for unit in enemy_units:
		if world_pos.distance_to(unit["pos"]) <= 34.0:
			return unit
	return {}


func _clamp_to_map(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, 40.0, MAP_SIZE.x - 40.0), clampf(pos.y, 40.0, MAP_SIZE.y - 40.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_id: int = event.index
		if event.pressed:
			active_touches[touch_id] = event.position
			if active_touches.size() == 1:
				touch_origin = event.position
				drag_end = event.position
				dragging = false
				multitouch_used = false
			elif active_touches.size() >= 2:
				multitouch_used = true
				dragging = false
				previous_pinch_distance = _touch_distance()
				previous_touch_midpoint = _touch_midpoint()
		else:
			if active_touches.has(touch_id):
				active_touches.erase(touch_id)
			if active_touches.is_empty():
				if not multitouch_used:
					if dragging:
						_select_in_rectangle(touch_origin, event.position)
					else:
						_handle_tap(event.position)
				dragging = false
				previous_pinch_distance = 0.0
				multitouch_used = false
			elif active_touches.size() == 1:
				previous_pinch_distance = 0.0
				previous_touch_midpoint = _touch_midpoint()
			_clamp_camera_position()
	elif event is InputEventScreenDrag:
		if active_touches.has(event.index):
			active_touches[event.index] = event.position
		if active_touches.size() >= 2:
			multitouch_used = true
			dragging = false
			var midpoint := _touch_midpoint()
			var distance := _touch_distance()
			camera.position -= (midpoint - previous_touch_midpoint) / camera.zoom
			if previous_pinch_distance > 1.0 and distance > 1.0:
				var zoom_factor := distance / previous_pinch_distance
				camera.zoom = (camera.zoom * zoom_factor).clamp(Vector2(0.55, 0.55), Vector2(1.8, 1.8))
			previous_touch_midpoint = midpoint
			previous_pinch_distance = distance
			_clamp_camera_position()
		else:
			drag_end = event.position
			if touch_origin.distance_to(drag_end) > 14.0:
				dragging = true
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				touch_origin = event.position
				dragging = false
			else:
				if dragging:
					_select_in_rectangle(touch_origin, event.position)
				else:
					_handle_tap(event.position)
				dragging = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			mouse_pan_active = event.pressed
			mouse_pan_last = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = (camera.zoom * 1.08).clamp(Vector2(0.55, 0.55), Vector2(1.8, 1.8))
			_clamp_camera_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = (camera.zoom / 1.08).clamp(Vector2(0.55, 0.55), Vector2(1.8, 1.8))
			_clamp_camera_position()
	elif event is InputEventMouseMotion and mouse_pan_active:
		camera.position -= event.relative / camera.zoom
		_clamp_camera_position()


func _touch_midpoint() -> Vector2:
	var points: Array = active_touches.values()
	if points.size() < 2:
		return Vector2.ZERO
	return (points[0] + points[1]) * 0.5


func _touch_distance() -> float:
	var points: Array = active_touches.values()
	if points.size() < 2:
		return 0.0
	return points[0].distance_to(points[1])


func _clamp_camera_position() -> void:
	var visible_size := get_viewport_rect().size / camera.zoom
	var half_visible := visible_size * 0.5
	var min_x := minf(half_visible.x, MAP_SIZE.x * 0.5)
	var min_y := minf(half_visible.y, MAP_SIZE.y * 0.5)
	var max_x := maxf(MAP_SIZE.x - half_visible.x, MAP_SIZE.x * 0.5)
	var max_y := maxf(MAP_SIZE.y - half_visible.y, MAP_SIZE.y * 0.5)
	camera.position = Vector2(
		clampf(camera.position.x, min_x, max_x),
		clampf(camera.position.y, min_y, max_y)
	)


func _select_in_rectangle(screen_a: Vector2, screen_b: Vector2) -> void:
	selected_units.clear()
	var a := _screen_to_world(screen_a)
	var b := _screen_to_world(screen_b)
	var rect := Rect2(a, b - a).abs()
	for unit in player_units:
		if rect.has_point(unit["pos"]):
			selected_units.append(unit)


func _update_hud() -> void:
	stats_label.text = "EMPIRE OF LION AND SUN   |   CREDITS %d   FUEL %d   MATERIALS %d\nPLAYER BASE %.0f HP   |   ENEMY BASE %.0f HP   |   UNITS %d   |   %.0f SEC" % [credits, fuel, materials, player_base_hp, enemy_base_hp, player_units.size(), elapsed]
	if match_over:
		stats_label.text += "\n" + match_message


func _grid_to_iso(column: int, row: int) -> Vector2:
	return Vector2(1600.0 + (column - row) * ISO_TILE_WIDTH * 0.5, (column + row) * ISO_TILE_HEIGHT * 0.5)


func _draw() -> void:
	# Large isometric diamond-tile battlefield. Logic positions remain in world pixels.
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.10, 0.16, 0.13), true)
	for row in range(ISO_GRID_SIZE):
		for column in range(ISO_GRID_SIZE):
			var center := _grid_to_iso(column, row)
			var terrain_seed := (column * 17 + row * 31 + column * row * 3) % 13
			var terrain := Color(0.22, 0.34, 0.23)
			if terrain_seed == 0 or terrain_seed == 7:
				terrain = Color(0.25, 0.38, 0.25)
			elif terrain_seed == 4:
				terrain = Color(0.19, 0.30, 0.22)
			elif terrain_seed == 10:
				terrain = Color(0.31, 0.34, 0.24)
			var diamond := PackedVector2Array([
				center + Vector2(0, -ISO_TILE_HEIGHT * 0.5),
				center + Vector2(ISO_TILE_WIDTH * 0.5, 0),
				center + Vector2(0, ISO_TILE_HEIGHT * 0.5),
				center + Vector2(-ISO_TILE_WIDTH * 0.5, 0)
			])
			draw_colored_polygon(diamond, terrain)
			draw_polyline(PackedVector2Array([
				diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]
			]), Color(0.08, 0.15, 0.11, 0.34), 1.0, true)
			# Sparse rock/vegetation marks add readable terrain texture.
			if terrain_seed == 2:
				draw_circle(center + Vector2(0, -4), 5.0, Color(0.13, 0.20, 0.14))
				draw_circle(center + Vector2(7, 1), 3.5, Color(0.17, 0.24, 0.16))
	# A river and a road follow the isometric grid.
	var river_points := PackedVector2Array()
	for row in range(4, 61, 4):
		river_points.append(_grid_to_iso(29 + int(sin(float(row) * 0.22) * 5.0), row))
	draw_polyline(river_points, Color(0.10, 0.29, 0.43), 34.0, true)
	draw_polyline(river_points, Color(0.17, 0.40, 0.53), 23.0, true)
	var road_points := PackedVector2Array([
		_grid_to_iso(5, 31), _grid_to_iso(18, 29), _grid_to_iso(32, 32), _grid_to_iso(47, 30), _grid_to_iso(59, 33)
	])
	draw_polyline(road_points, Color(0.24, 0.22, 0.17), 25.0, true)
	draw_polyline(road_points, Color(0.43, 0.39, 0.29), 17.0, true)
	# Map edge.
	draw_rect(Rect2(Vector2(12, 12), MAP_SIZE - Vector2(24, 24)), Color(0.55, 0.67, 0.49, 0.8), false, 5.0)
	_draw_base(PLAYER_BASE, Color(0.2, 0.55, 0.95), player_base_hp)
	_draw_base(ENEMY_BASE, Color(0.9, 0.25, 0.2), enemy_base_hp)
	for unit in player_units:
		_draw_unit(unit)
	for unit in enemy_units:
		_draw_unit(unit)
	if dragging:
		var a := _screen_to_world(touch_origin)
		var b := _screen_to_world(drag_end)
		draw_rect(Rect2(a, b - a).abs(), Color(0.3, 0.75, 1.0, 0.12), true)
		draw_rect(Rect2(a, b - a).abs(), Color(0.4, 0.85, 1.0, 0.9), false, 2.0)

func _draw_base(pos: Vector2, tint: Color, hp: float) -> void:
	draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -95), pos + Vector2(125, 0), pos + Vector2(0, 95), pos + Vector2(-125, 0)]), tint.darkened(0.25))
	draw_rect(Rect2(pos + Vector2(-65, -10), Vector2(130, 14)), Color(0.12, 0.12, 0.12), true)
	draw_rect(Rect2(pos + Vector2(-65, -10), Vector2(130.0 * clampf(hp / 1200.0, 0.0, 1.0), 14)), Color(0.2, 0.9, 0.35), true)


func _draw_unit(unit: Dictionary) -> void:
	var pos: Vector2 = unit["pos"]
	var tint := Color(0.25, 0.7, 1.0) if unit["team"] == "player" else Color(1.0, 0.32, 0.25)
	var size := 22.0 if unit["kind"] == "tank" else 16.0
	var diamond := PackedVector2Array([pos + Vector2(0, -size), pos + Vector2(size, 0), pos + Vector2(0, size * 0.65), pos + Vector2(-size, 0)])
	draw_colored_polygon(diamond, tint)
	draw_rect(Rect2(pos + Vector2(-18, -size - 10), Vector2(36, 4)), Color(0.08, 0.08, 0.08), true)
	draw_rect(Rect2(pos + Vector2(-18, -size - 10), Vector2(36.0 * clampf(float(unit["hp"]) / float(unit["max_hp"]), 0.0, 1.0), 4)), Color(0.2, 0.9, 0.35), true)
	if selected_units.has(unit):
		draw_arc(pos, size + 9.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.25), 3.0)

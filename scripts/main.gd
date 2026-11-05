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
var hud_message := "Select units and capture the enemy command center."
var selection_label: Label
var pathfinder := AStarGrid2D.new()

@onready var camera: Camera2D = $Camera2D
@onready var stats_label: Label = $HUD/Stats


func _ready() -> void:
	camera.position = Vector2(1600, 1600)
	camera.make_current()
	camera.zoom = Vector2.ONE
	_clamp_camera_position()
	_setup_pathfinding()
	_spawn_unit("infantry", "player", PLAYER_BASE + Vector2(150, -100))
	_spawn_unit("tank", "player", PLAYER_BASE + Vector2(220, 0))
	_spawn_unit("apc", "player", PLAYER_BASE + Vector2(150, 100))
	_spawn_unit("infantry", "enemy", ENEMY_BASE + Vector2(-150, -100))
	_spawn_unit("tank", "enemy", ENEMY_BASE + Vector2(-220, 0))
	_spawn_unit("apc", "enemy", ENEMY_BASE + Vector2(-150, 100))
	_build_hud()
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
		if enemy_units.size() < 30:
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



func _setup_pathfinding() -> void:
	pathfinder.region = Rect2i(0, 0, ISO_GRID_SIZE, ISO_GRID_SIZE)
	pathfinder.cell_size = Vector2.ONE
	pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	pathfinder.update()
	# The river blocks movement except at the road crossing, which acts as a bridge.
	for row in range(4, 61):
		var river_column := 29 + int(sin(float(row) * 0.22) * 5.0)
		for offset in range(-1, 2):
			var column := river_column + offset
			var is_bridge := row >= 29 and row <= 35
			if not is_bridge and column >= 0 and column < ISO_GRID_SIZE:
				pathfinder.set_point_solid(Vector2i(column, row), true)


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var u := (world_pos.x - 1600.0) / (ISO_TILE_WIDTH * 0.5)
	var v := world_pos.y / (ISO_TILE_HEIGHT * 0.5)
	var column := int(round((u + v) * 0.5))
	var row := int(round((v - u) * 0.5))
	return Vector2i(
		clampi(column, 0, ISO_GRID_SIZE - 1),
		clampi(row, 0, ISO_GRID_SIZE - 1)
	)


func _grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		1600.0 + float(cell.x - cell.y) * ISO_TILE_WIDTH * 0.5,
		float(cell.x + cell.y) * ISO_TILE_HEIGHT * 0.5
	)


func _nearest_walkable_cell(origin: Vector2i) -> Vector2i:
	if not pathfinder.is_point_solid(origin):
		return origin
	for radius in range(1, 9):
		for row_offset in range(-radius, radius + 1):
			for column_offset in range(-radius, radius + 1):
				if maxi(absi(row_offset), absi(column_offset)) != radius:
					continue
				var candidate := origin + Vector2i(column_offset, row_offset)
				if candidate.x >= 0 and candidate.x < ISO_GRID_SIZE and candidate.y >= 0 and candidate.y < ISO_GRID_SIZE:
					if not pathfinder.is_point_solid(candidate):
						return candidate
	return origin


func _set_unit_destination(unit: Dictionary, destination: Vector2) -> void:
	var start_cell := _nearest_walkable_cell(_world_to_grid(unit["pos"]))
	var requested_destination := _clamp_to_map(destination)
	var end_cell := _nearest_walkable_cell(_world_to_grid(requested_destination))
	var final_destination := requested_destination if end_cell == _world_to_grid(requested_destination) else _grid_to_world(end_cell)
	var cell_path: Array[Vector2i] = pathfinder.get_id_path(start_cell, end_cell)
	var world_path: Array[Vector2] = []
	for i in range(1, cell_path.size()):
		world_path.append(_grid_to_world(cell_path[i]))
	if not world_path.is_empty():
		world_path.append(final_destination)
	elif start_cell == end_cell and unit["pos"].distance_to(final_destination) > 7.0:
		world_path.append(final_destination)
	unit["destination"] = final_destination
	unit["path"] = world_path
	unit["path_index"] = 0


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
		"cooldown": randf_range(0.0, 0.4),
		"path": [],
		"path_index": 0
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
		_set_unit_destination(unit, PLAYER_BASE)


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
			if not is_player and pos.distance_to(PLAYER_BASE) > 150.0:
				destination = PLAYER_BASE
				if unit["destination"].distance_to(destination) > 20.0:
					_set_unit_destination(unit, destination)
			var route: Array = unit["path"]
			var route_index: int = int(unit["path_index"])
			if route_index < route.size():
				var waypoint: Vector2 = route[route_index]
				if pos.distance_to(waypoint) <= 10.0:
					route_index += 1
					unit["path_index"] = route_index
				else:
					pos = pos.move_toward(waypoint, float(unit["speed"]) * delta)
					unit["pos"] = _clamp_to_map(pos)
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
			_issue_group_move(clicked_unit["pos"])
	else:
		if not selected_units.is_empty():
			_issue_group_move(_clamp_to_map(world_pos))
		else:
			selected_units.clear()



func _issue_group_move(target: Vector2) -> void:
	var count := selected_units.size()
	if count == 0:
		return
	var columns := ceili(sqrt(float(count)))
	var rows := ceili(float(count) / float(columns))
	for i in range(count):
		var column := i % columns
		var row := int(i / columns)
		var offset := Vector2(
			(float(column) - float(columns - 1) * 0.5) * 52.0,
			(float(row) - float(rows - 1) * 0.5) * 46.0
		)
		_set_unit_destination(selected_units[i], target + offset)


func _separation_vector(unit: Dictionary, team: Array[Dictionary]) -> Vector2:
	var push := Vector2.ZERO
	var unit_pos: Vector2 = unit["pos"]
	for other in team:
		if other == unit:
			continue
		var difference: Vector2 = unit_pos - other["pos"]
		var distance := difference.length()
		if distance > 0.1 and distance < 38.0:
			push += difference.normalized() * ((38.0 - distance) / 38.0)
	return push.limit_length(1.0)


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
	var touch_ids: Array = active_touches.keys()
	if touch_ids.size() < 2:
		return Vector2.ZERO
	touch_ids.sort()
	var first: Vector2 = active_touches[touch_ids[0]]
	var second: Vector2 = active_touches[touch_ids[1]]
	return (first + second) * 0.5


func _touch_distance() -> float:
	var touch_ids: Array = active_touches.keys()
	if touch_ids.size() < 2:
		return 0.0
	touch_ids.sort()
	var first: Vector2 = active_touches[touch_ids[0]]
	var second: Vector2 = active_touches[touch_ids[1]]
	return first.distance_to(second)


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


func _build_hud() -> void:
	var hud: CanvasLayer = $HUD
	var top_panel := PanelContainer.new()
	top_panel.name = "TopStatusPanel"
	top_panel.anchor_left = 0.0
	top_panel.anchor_top = 0.0
	top_panel.anchor_right = 1.0
	top_panel.anchor_bottom = 0.0
	top_panel.offset_left = 12.0
	top_panel.offset_top = 10.0
	top_panel.offset_right = -12.0
	top_panel.offset_bottom = 88.0
	hud.add_child(top_panel)
	stats_label.reparent(top_panel)
	stats_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_label.offset_left = 8.0
	stats_label.offset_top = 4.0
	stats_label.offset_right = -8.0
	stats_label.offset_bottom = -4.0
	stats_label.custom_minimum_size = Vector2(0, 64)
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bottom_panel := PanelContainer.new()
	bottom_panel.name = "CommandPanel"
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = 12.0
	bottom_panel.offset_top = -128.0
	bottom_panel.offset_right = -12.0
	bottom_panel.offset_bottom = -10.0
	hud.add_child(bottom_panel)
	var command_rows := VBoxContainer.new()
	command_rows.add_theme_constant_override("separation", 4)
	bottom_panel.add_child(command_rows)
	var recruit_row := HBoxContainer.new()
	recruit_row.add_theme_constant_override("separation", 6)
	command_rows.add_child(recruit_row)
	_add_hud_button(recruit_row, "INFANTRY", _recruit_infantry)
	_add_hud_button(recruit_row, "TANK", _recruit_tank)
	_add_hud_button(recruit_row, "APC", _recruit_apc)
	var utility_row := HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 6)
	command_rows.add_child(utility_row)
	_add_hud_button(utility_row, "STOP", _stop_selected_units)
	_add_hud_button(utility_row, "SELECT ALL", _select_all_player_units)
	_add_hud_button(utility_row, "SAVE", _save_game)
	_add_hud_button(utility_row, "LOAD", _load_game)
	selection_label = Label.new()
	selection_label.text = "SELECTED: 0"
	selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selection_label.add_theme_font_size_override("font_size", 14)
	utility_row.add_child(selection_label)


func _add_hud_button(parent: HBoxContainer, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(105, 54)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(action)
	parent.add_child(button)


func _recruit_unit(kind: String) -> void:
	if match_over:
		return
	if player_units.size() >= 30:
		hud_message = "Army limit reached (30 units)."
		_update_hud()
		return
	var cost_credits := 100
	var cost_fuel := 0
	var cost_materials := 40
	match kind:
		"tank":
			cost_credits = 220
			cost_fuel = 60
			cost_materials = 90
		"apc":
			cost_credits = 180
			cost_fuel = 35
			cost_materials = 70
	if credits < cost_credits or fuel < cost_fuel or materials < cost_materials:
		hud_message = "Not enough resources to recruit " + kind.to_upper() + "."
		_update_hud()
		return
	credits -= cost_credits
	fuel -= cost_fuel
	materials -= cost_materials
	var spawn_offset := Vector2(randf_range(110.0, 190.0), randf_range(-150.0, 150.0))
	_spawn_unit(kind, "player", _clamp_to_map(PLAYER_BASE + spawn_offset))
	hud_message = kind.to_upper() + " recruited."
	_update_hud()



func _save_game() -> void:
	var save_data := {
		"version": 1,
		"credits": credits,
		"fuel": fuel,
		"materials": materials,
		"elapsed": elapsed,
		"player_base_hp": player_base_hp,
		"enemy_base_hp": enemy_base_hp,
		"player_units": _serialize_units(player_units),
		"enemy_units": _serialize_units(enemy_units)
	}
	var file := FileAccess.open("user://empire_save.json", FileAccess.WRITE)
	if file == null:
		hud_message = "Save failed: cannot open save file."
	else:
		file.store_string(JSON.stringify(save_data))
		file.close()
		hud_message = "Game saved on this device."
	_update_hud()


func _serialize_units(units: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for unit in units:
		var pos: Vector2 = unit["pos"]
		var destination: Vector2 = unit["destination"]
		records.append({
			"kind": unit["kind"],
			"pos": [pos.x, pos.y],
			"destination": [destination.x, destination.y],
			"hp": unit["hp"],
			"max_hp": unit["max_hp"],
			"speed": unit["speed"],
			"damage": unit["damage"],
			"cooldown": unit["cooldown"]
		})
	return records


func _load_game() -> void:
	if not FileAccess.file_exists("user://empire_save.json"):
		hud_message = "No local save found."
		_update_hud()
		return
	var file := FileAccess.open("user://empire_save.json", FileAccess.READ)
	if file == null:
		hud_message = "Load failed: cannot read save file."
		_update_hud()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary) or int(parsed.get("version", 0)) != 1:
		hud_message = "Load failed: save format is invalid."
		_update_hud()
		return
	credits = int(parsed.get("credits", 500))
	fuel = int(parsed.get("fuel", 300))
	materials = int(parsed.get("materials", 300))
	elapsed = float(parsed.get("elapsed", 0.0))
	player_base_hp = float(parsed.get("player_base_hp", 1200.0))
	enemy_base_hp = float(parsed.get("enemy_base_hp", 1200.0))
	player_units.clear()
	enemy_units.clear()
	selected_units.clear()
	var player_records: Array = parsed.get("player_units", [])
	var enemy_records: Array = parsed.get("enemy_units", [])
	_restore_units(player_records, "player")
	_restore_units(enemy_records, "enemy")
	match_over = player_base_hp <= 0.0 or enemy_base_hp <= 0.0
	match_message = "VICTORY — Enemy command center destroyed" if enemy_base_hp <= 0.0 else "DEFEAT — Your command center was destroyed" if player_base_hp <= 0.0 else ""
	hud_message = "Game loaded from this device."
	_update_hud()
	queue_redraw()


func _restore_units(records: Array, team: String) -> void:
	for record_variant in records:
		if not (record_variant is Dictionary):
			continue
		var record: Dictionary = record_variant
		var pos_data: Array = record.get("pos", [320.0, 1600.0])
		if pos_data.size() < 2:
			continue
		var unit_pos := _clamp_to_map(Vector2(float(pos_data[0]), float(pos_data[1])))
		var kind := str(record.get("kind", "infantry"))
		if not (kind in ["infantry", "tank", "apc"]):
			kind = "infantry"
		_spawn_unit(kind, team, unit_pos)
		var units := player_units if team == "player" else enemy_units
		var unit: Dictionary = units.back()
		unit["hp"] = clampf(float(record.get("hp", 100.0)), 0.0, float(record.get("max_hp", 100.0)))
		unit["max_hp"] = maxf(1.0, float(record.get("max_hp", 100.0)))
		unit["speed"] = maxf(1.0, float(record.get("speed", UNIT_SPEED)))
		unit["damage"] = maxf(0.0, float(record.get("damage", 12.0)))
		unit["cooldown"] = maxf(0.0, float(record.get("cooldown", 0.0)))
		var destination_data: Array = record.get("destination", [unit_pos.x, unit_pos.y])
		if destination_data.size() >= 2:
			_set_unit_destination(unit, Vector2(float(destination_data[0]), float(destination_data[1])))


func _recruit_infantry() -> void:
	_recruit_unit("infantry")


func _recruit_tank() -> void:
	_recruit_unit("tank")


func _recruit_apc() -> void:
	_recruit_unit("apc")


func _stop_selected_units() -> void:
	for unit in selected_units:
		_set_unit_destination(unit, unit["pos"])
	hud_message = "Selected units stopped."
	_update_hud()


func _select_all_player_units() -> void:
	selected_units.clear()
	selected_units.append_array(player_units)
	hud_message = "All friendly units selected."
	_update_hud()
	queue_redraw()


func _update_hud() -> void:
	stats_label.text = "EMPIRE OF LION AND SUN  |  CREDITS %d   FUEL %d   MATERIALS %d\nBASE %.0f HP  |  ENEMY %.0f HP  |  ARMY %d  |  %.0f SEC\n%s" % [credits, fuel, materials, player_base_hp, enemy_base_hp, player_units.size(), elapsed, hud_message]
	if selection_label != null:
		selection_label.text = "SELECTED: %d" % selected_units.size()
	if match_over:
		stats_label.text += "\n" + match_message


func _grid_to_iso(column: int, row: int) -> Vector2:
	return Vector2(1600.0 + (column - row) * ISO_TILE_WIDTH * 0.5, (column + row) * ISO_TILE_HEIGHT * 0.5)


func _draw() -> void:
	# Static terrain is rendered by TerrainLayer; this node redraws only active gameplay objects.
	_draw_base(PLAYER_BASE, Color(0.2, 0.55, 0.95), player_base_hp)
	_draw_base(ENEMY_BASE, Color(0.9, 0.25, 0.2), enemy_base_hp)
	var render_units: Array[Dictionary] = []
	render_units.append_array(player_units)
	render_units.append_array(enemy_units)
	render_units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"].y < b["pos"].y)
	for unit in render_units:
		_draw_unit(unit)
	if dragging:
		var a := _screen_to_world(touch_origin)
		var b := _screen_to_world(drag_end)
		draw_rect(Rect2(a, b - a).abs(), Color(0.3, 0.75, 1.0, 0.12), true)
		draw_rect(Rect2(a, b - a).abs(), Color(0.4, 0.85, 1.0, 0.9), false, 2.0)


func _draw_base(pos: Vector2, tint: Color, hp: float) -> void:
	# Command center: layered isometric platform, walls and central control tower.
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -112), pos + Vector2(150, -8),
		pos + Vector2(0, 96), pos + Vector2(-150, -8)
	]), Color(0.08, 0.10, 0.11, 0.65))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -102), pos + Vector2(137, -7),
		pos + Vector2(0, 88), pos + Vector2(-137, -7)
	]), tint.darkened(0.38))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-66, -12), pos + Vector2(-25, -42),
		pos + Vector2(23, -15), pos + Vector2(-18, 15)
	]), tint.lightened(0.12))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-18, -42), pos + Vector2(35, -76),
		pos + Vector2(84, -48), pos + Vector2(31, -17)
	]), tint.darkened(0.12))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-18, -42), pos + Vector2(31, -17),
		pos + Vector2(31, 28), pos + Vector2(-18, 0)
	]), tint.darkened(0.42))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(31, -17), pos + Vector2(84, -48),
		pos + Vector2(84, -4), pos + Vector2(31, 28)
	]), tint.darkened(0.30))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-18, -42), pos + Vector2(35, -76),
		pos + Vector2(84, -48), pos + Vector2(31, -17)
	]), tint.lightened(0.22))
	draw_rect(Rect2(pos + Vector2(-65, -126), Vector2(130, 7)), Color(0.08, 0.08, 0.08), true)
	draw_rect(Rect2(pos + Vector2(-65, -126), Vector2(130.0 * clampf(hp / 1200.0, 0.0, 1.0), 7)), Color(0.2, 0.9, 0.35), true)


func _draw_unit(unit: Dictionary) -> void:
	var pos: Vector2 = unit["pos"]
	var is_player: bool = unit["team"] == "player"
	var tint := Color(0.25, 0.68, 0.96) if is_player else Color(0.92, 0.28, 0.22)
	var shadow := Color(0.03, 0.05, 0.04, 0.42)
	var kind: String = unit["kind"]
	var body_width := 23.0 if kind == "tank" else 19.0
		# Soft ground shadow and selection ring.
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, 12), pos + Vector2(body_width + 8, 3),
		pos + Vector2(0, -6), pos + Vector2(-body_width - 8, 3)
	]), shadow)
	if selected_units.has(unit):
		draw_arc(pos + Vector2(0, 2), 31.0, 0.0, TAU, 40, Color(1.0, 0.88, 0.22), 3.0)
	# Unit silhouettes use layered polygons to read clearly at mobile scale.
	if kind == "infantry":
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(0, -22), pos + Vector2(9, -13),
			pos + Vector2(7, 5), pos + Vector2(-7, 5),
			pos + Vector2(-9, -13)
		]), tint.darkened(0.28))
		draw_circle(pos + Vector2(0, -20), 6.0, tint.lightened(0.18))
		draw_line(pos + Vector2(7, -12), pos + Vector2(18, -18), Color(0.12, 0.13, 0.12), 3.0)
	elif kind == "tank":
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-25, -1), pos + Vector2(-15, -13),
			pos + Vector2(17, -13), pos + Vector2(26, -1),
			pos + Vector2(15, 12), pos + Vector2(-16, 12)
		]), Color(0.10, 0.12, 0.11))
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-20, -3), pos + Vector2(-12, -10),
			pos + Vector2(13, -10), pos + Vector2(21, -3),
			pos + Vector2(13, 8), pos + Vector2(-13, 8)
		]), tint.darkened(0.18))
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-10, -7), pos + Vector2(4, -16),
			pos + Vector2(15, -10), pos + Vector2(1, -2)
		]), tint.lightened(0.18))
		draw_line(pos + Vector2(5, -11), pos + Vector2(26, -23), Color(0.12, 0.14, 0.13), 5.0)
		draw_circle(pos + Vector2(2, -8), 5.0, Color(0.16, 0.18, 0.16))
	else:
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-25, -2), pos + Vector2(-16, -12),
			pos + Vector2(17, -12), pos + Vector2(26, -2),
			pos + Vector2(17, 11), pos + Vector2(-18, 11)
		]), Color(0.12, 0.14, 0.13))
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-19, -4), pos + Vector2(-12, -9),
			pos + Vector2(13, -9), pos + Vector2(20, -3),
			pos + Vector2(13, 7), pos + Vector2(-14, 7)
		]), tint)
		draw_colored_polygon(PackedVector2Array([
			pos + Vector2(-9, -7), pos + Vector2(3, -13),
			pos + Vector2(12, -8), pos + Vector2(0, -2)
		]), tint.lightened(0.22))
	# Health bar remains readable above every unit.
	draw_rect(Rect2(pos + Vector2(-19, -35), Vector2(38, 5)), Color(0.06, 0.07, 0.07), true)
	draw_rect(Rect2(pos + Vector2(-19, -35), Vector2(38.0 * clampf(float(unit["hp"]) / float(unit["max_hp"]), 0.0, 1.0), 5)), Color(0.22, 0.92, 0.38), true)

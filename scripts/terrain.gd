extends Node2D

const ISO_TILE_WIDTH := 96.0
const ISO_TILE_HEIGHT := 48.0
const ISO_GRID_SIZE := 64
const MAP_SIZE := Vector2(6200, 3200)


func _ready() -> void:
	z_index = -1
	queue_redraw()


func _grid_to_iso(column: int, row: int) -> Vector2:
	return Vector2(3100.0 + (column - row) * ISO_TILE_WIDTH * 0.5, 88.0 + (column + row) * ISO_TILE_HEIGHT * 0.5)


func _draw() -> void:
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
			if terrain_seed == 2:
				draw_circle(center + Vector2(0, -4), 5.0, Color(0.13, 0.20, 0.14))
				draw_circle(center + Vector2(7, 1), 3.5, Color(0.17, 0.24, 0.16))
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
	draw_rect(Rect2(Vector2(12, 12), MAP_SIZE - Vector2(24, 24)), Color(0.55, 0.67, 0.49, 0.8), false, 5.0)

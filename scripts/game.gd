extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const MAGAZINE_SIZE := 30
const FIRE_INTERVAL := 0.105
const RELOAD_DURATION := 1.65
const RAY_LENGTH := 100.0

var player: CharacterBody3D
var ammo := MAGAZINE_SIZE
var reserve_ammo := 90
var score := 0
var fire_cooldown := 0.0
var is_reloading := false
var reload_time := 0.0
var fire_held := false
var hud: Label
var message: Label

func _ready() -> void:
	_build_arena()
	_spawn_player()
	_build_hud()
	_spawn_targets()
	if DisplayServer.is_touchscreen_available():
		_build_mobile_controls()

func _process(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if fire_held:
		_shoot()
	if is_reloading:
		reload_time -= delta
		if reload_time <= 0.0:
			var needed := MAGAZINE_SIZE - ammo
			var loaded: int = mini(needed, reserve_ammo)
			ammo += loaded
			reserve_ammo -= loaded
			is_reloading = false
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_shoot()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_reload()

func _build_arena() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.18, 0.28)
	sky_mat.sky_horizon_color = Color(0.48, 0.52, 0.58)
	env.sky.sky_material = sky_mat
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.68, 0.75)
	env.ambient_light_energy = 0.65
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.3
	add_child(sun)

	_add_box("ArenaFloor", Vector3(0, -0.25, 0), Vector3(34, 0.5, 34), Color(0.24, 0.27, 0.25))
	_add_box("NorthWall", Vector3(0, 2, -17), Vector3(34, 4, 0.5), Color(0.32, 0.34, 0.36))
	_add_box("SouthWall", Vector3(0, 2, 17), Vector3(34, 4, 0.5), Color(0.32, 0.34, 0.36))
	_add_box("WestWall", Vector3(-17, 2, 0), Vector3(0.5, 4, 34), Color(0.32, 0.34, 0.36))
	_add_box("EastWall", Vector3(17, 2, 0), Vector3(0.5, 4, 34), Color(0.32, 0.34, 0.36))
	_add_box("CoverA", Vector3(-5, 0.8, -3), Vector3(3, 1.6, 1.2), Color(0.43, 0.32, 0.22))
	_add_box("CoverB", Vector3(5, 0.8, 3), Vector3(3, 1.6, 1.2), Color(0.43, 0.32, 0.22))
	_add_box("CrateA", Vector3(0, 0.65, -8), Vector3(2, 1.3, 2), Color(0.38, 0.29, 0.2))
	_add_box("CrateB", Vector3(-9, 0.65, 5), Vector3(2, 1.3, 2), Color(0.38, 0.29, 0.2))
	_add_box("CrateC", Vector3(9, 0.65, -5), Vector3(2, 1.3, 2), Color(0.38, 0.29, 0.2))

func _add_box(label: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh_instance.material_override = mat
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)

func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.position = Vector3(0, 0.1, 11)
	add_child(player)

func _spawn_targets() -> void:
	var positions := [
		Vector3(-10, 0, -9), Vector3(-5, 0, -12),
		Vector3(0, 0, -10), Vector3(5, 0, -12),
		Vector3(10, 0, -9), Vector3(10, 0, 5)
	]
	for i in positions.size():
		_create_target(positions[i], i + 1)

func _create_target(pos: Vector3, index: int) -> void:
	var target := StaticBody3D.new()
	target.name = "Target_%d" % index
	target.position = pos + Vector3(0, 1.0, 0)
	target.add_to_group("shootable")
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.42
	mesh.height = 1.8
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.18, 0.12)
	mat.metallic = 0.15
	mesh_instance.material_override = mat
	target.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.8
	collision.shape = shape
	target.add_child(collision)
	add_child(target)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 22)
	hud.add_theme_font_size_override("font_size", 22)
	hud.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(hud)

	message = Label.new()
	message.anchor_left = 0.5
	message.anchor_top = 1.0
	message.anchor_right = 0.5
	message.anchor_bottom = 1.0
	message.offset_left = -300
	message.offset_top = -62
	message.offset_right = 300
	message.offset_bottom = -25
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 16)
	message.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	message.text = "موبایل: سمت چپ حرکت | سمت راست نگاه | دکمه‌ها شلیک و پرش"
	layer.add_child(message)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -10
	crosshair.offset_top = -19
	crosshair.offset_right = 10
	crosshair.offset_bottom = 19
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 30)
	crosshair.add_theme_color_override("font_color", Color(0.85, 1.0, 0.9))
	layer.add_child(crosshair)

func _build_mobile_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MobileControls"
	add_child(layer)

	var fire_button := _make_touch_button(layer, "FIRE", Vector2(-118, -150), Vector2(104, 104))
	fire_button.button_down.connect(func(): fire_held = true)
	fire_button.button_up.connect(func(): fire_held = false)

	var reload_button := _make_touch_button(layer, "RELOAD", Vector2(-230, -94), Vector2(92, 58))
	reload_button.pressed.connect(_reload)

	var jump_button := _make_touch_button(layer, "JUMP", Vector2(-118, -270), Vector2(86, 62))
	jump_button.button_down.connect(func(): Input.action_press("jump"))
	jump_button.button_up.connect(func(): Input.action_release("jump"))

	var sprint_button := _make_touch_button(layer, "RUN", Vector2(-230, -170), Vector2(86, 58))
	sprint_button.button_down.connect(func(): Input.action_press("sprint"))
	sprint_button.button_up.connect(func(): Input.action_release("sprint"))

func _make_touch_button(parent: CanvasLayer, caption: String, offset: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = button_size
	button.anchor_left = 1.0
	button.anchor_top = 1.0
	button.anchor_right = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = offset.x
	button.offset_top = offset.y
	button.offset_right = offset.x + button_size.x
	button.offset_bottom = offset.y + button_size.y
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(button)
	return button

func _update_hud() -> void:
	if is_instance_valid(hud):
		var state := "در حال بارگذاری خشاب..." if is_reloading else ""
		hud.text = "STRIKE ZONE     امتیاز: %d\nRIFLE   %02d / %02d   %s" % [score, ammo, reserve_ammo, state]

func _shoot() -> void:
	if is_reloading or fire_cooldown > 0.0 or ammo <= 0:
		if ammo <= 0 and not is_reloading:
			_reload()
		return
	ammo -= 1
	fire_cooldown = FIRE_INTERVAL
	var camera := player.get_node("Camera3D") as Camera3D
	var origin := camera.global_position
	var end := origin - camera.global_basis.z * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is Node and hit.collider.is_in_group("shootable"):
		score += 100
		hit.collider.queue_free()
		message.text = "هدف منهدم شد! +100"
		_spawn_target_after_delay()
	_update_hud()

func _spawn_target_after_delay() -> void:
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree():
		_create_target(Vector3(randf_range(-11, 11), 0, randf_range(-13, -7)), randi_range(1, 999))

func _reload() -> void:
	if is_reloading or ammo == MAGAZINE_SIZE or reserve_ammo <= 0:
		return
	is_reloading = true
	reload_time = RELOAD_DURATION
	_update_hud()

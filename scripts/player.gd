extends CharacterBody3D

const WALK_SPEED := 6.0
const SPRINT_SPEED := 9.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.0022
const TOUCH_LOOK_SENSITIVITY := 0.0035
const LOOK_LIMIT := 88.0
const JOYSTICK_RADIUS := 78.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera: Camera3D
var _move_touch_index := -1
var _look_touch_index := -1
var _move_touch_origin := Vector2.ZERO
var _touch_move := Vector2.ZERO

func _ready() -> void:
	_setup_input_actions()
	_build_collision()
	_build_camera_and_weapon()
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_input_actions() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)

func _add_key_action(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)

func _build_collision() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

func _build_camera_and_weapon() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.62
	camera.current = true
	add_child(camera)

	var gun := MeshInstance3D.new()
	gun.name = "PrototypeWeapon"
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.18, 0.16, 0.65)
	gun.mesh = gun_mesh
	gun.position = Vector3(0.28, -0.23, -0.48)
	var gun_material := StandardMaterial3D.new()
	gun_material.albedo_color = Color(0.12, 0.14, 0.17)
	gun_material.metallic = 0.75
	gun_material.roughness = 0.32
	gun.material_override = gun_material
	camera.add_child(gun)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative, MOUSE_SENSITIVITY)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var screen_width := get_viewport().get_visible_rect().size.x
	if event.pressed:
		if event.position.x < screen_width * 0.48 and _move_touch_index == -1:
			_move_touch_index = event.index
			_move_touch_origin = event.position
			_touch_move = Vector2.ZERO
		elif event.position.x >= screen_width * 0.48 and _look_touch_index == -1:
			_look_touch_index = event.index
	else:
		if event.index == _move_touch_index:
			_move_touch_index = -1
			_touch_move = Vector2.ZERO
		if event.index == _look_touch_index:
			_look_touch_index = -1

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == _move_touch_index:
		var displacement: Vector2 = event.position - _move_touch_origin
		_touch_move = (displacement / JOYSTICK_RADIUS).limit_length(1.0)
	elif event.index == _look_touch_index:
		_apply_look(event.relative, TOUCH_LOOK_SENSITIVITY)

func _apply_look(relative_motion: Vector2, sensitivity: float) -> void:
	rotate_y(-relative_motion.x * sensitivity)
	camera.rotate_x(-relative_motion.y * sensitivity)
	camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-LOOK_LIMIT), deg_to_rad(LOOK_LIMIT))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var keyboard_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_dir := (keyboard_dir + _touch_move).limit_length(1.0)
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED

	if direction.length_squared() > 0.0001:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * 7.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * 7.0 * delta)
	move_and_slide()

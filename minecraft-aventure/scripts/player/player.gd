extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _ready() -> void:
	add_to_group("player")
	
func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# El movimiento se alinea con la cámara isométrica actual, no con el mundo.
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd_dir := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	input_dir = (input_dir + wasd_dir).limit_length()
	var direction := Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var camera_right := camera.global_transform.basis.x
		var camera_forward := -camera.global_transform.basis.z
		camera_right.y = 0.0
		camera_forward.y = 0.0
		direction = (camera_right.normalized() * input_dir.x - camera_forward.normalized() * input_dir.y).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

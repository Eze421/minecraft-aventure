class_name CinematicCamera
extends Camera3D

## Cámara de tercera persona con encuadres cinemáticos reutilizables.
@export_group("Seguimiento")
@export_node_path("Node3D") var follow_target_path: NodePath = NodePath("..")
@export var follow_offset := Vector3(5.0, 4.5, 7.0)
@export_range(0.0, 10.0, 0.1, "or_greater") var follow_focus_height := 1.2
@export_range(0.1, 20.0, 0.1, "or_greater") var follow_smoothing := 6.0
@export_group("Órbita con mouse")
@export var mouse_orbit_enabled := true
@export var capture_mouse_on_ready := false
@export_range(0.001, 0.02, 0.001) var mouse_sensitivity := 0.005
@export_range(-80.0, 0.0, 1.0) var minimum_pitch_degrees := -35.0
@export_range(0.0, 80.0, 1.0) var maximum_pitch_degrees := 45.0
@export_group("Prueba en editor")
@export var debug_shortcuts_enabled := true
@export var debug_shots: Array[NodePath] = []

var _follow_target: Node3D
var _current_shot: CinematicShot
var _is_following := true
var _current_transition_duration := 0.75
var _follow_distance := 1.0
var _orbit_yaw := 0.0
var _orbit_pitch := 0.0
var _follow_fov := 55.0
var _target_fov := 55.0


func _ready() -> void:
	top_level = true
	current = true
	_follow_fov = fov
	_target_fov = fov
	_configure_orbit_from_offset()
	_follow_target = get_node_or_null(follow_target_path) as Node3D
	if _follow_target == null:
		_follow_target = get_parent() as Node3D
	_snap_to_follow()
	if capture_mouse_on_ready:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var desired_position := global_position
	var desired_focus := global_position - global_transform.basis.z
	var duration := 1.0 / follow_smoothing

	if _is_following:
		if _follow_target == null:
			return
		desired_position = _follow_target.global_position + _get_orbit_offset()
		desired_focus = _follow_target.global_position + Vector3.UP * follow_focus_height
		_target_fov = _follow_fov
	else:
		if not is_instance_valid(_current_shot):
			return_to_follow()
			return
		desired_position = _current_shot.global_position
		desired_focus = _current_shot.get_look_target()
		duration = _current_transition_duration
		_target_fov = _current_shot.get_fov()

	var blend := 1.0 - exp(-delta / maxf(duration, 0.01))
	global_position = global_position.lerp(desired_position, blend)
	fov = lerpf(fov, _target_fov, blend)
	look_at(desired_focus)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key_input(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if mouse_orbit_enabled and _is_following:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion:
		if mouse_orbit_enabled and _is_following and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_orbit_yaw -= event.relative.x * mouse_sensitivity
			_orbit_pitch = clampf(
				_orbit_pitch - event.relative.y * mouse_sensitivity,
				deg_to_rad(minimum_pitch_degrees),
				deg_to_rad(maximum_pitch_degrees)
			)


func _handle_key_input(event: InputEventKey) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if not debug_shortcuts_enabled:
		return
	if event.keycode == KEY_1:
		return_to_follow()
		return
	var shot_index: int = int(event.keycode) - int(KEY_2)
	var available_shots := _get_available_shots()
	if shot_index >= 0 and shot_index < available_shots.size():
		var shot: CinematicShot = available_shots[shot_index]
		if shot != null:
			play_shot(shot)


## Cambia suavemente al encuadre. Puede llamarse desde cualquier script.
func play_shot(shot: CinematicShot, transition_override := -1.0) -> void:
	if shot == null:
		return
	_current_shot = shot
	_is_following = false
	_current_transition_duration = shot.get_transition_duration() if transition_override < 0.0 else transition_override


## Vuelve al seguimiento de tercera persona.
func return_to_follow() -> void:
	_is_following = true
	_current_shot = null


func _snap_to_follow() -> void:
	if _follow_target == null:
		return
	global_position = _follow_target.global_position + _get_orbit_offset()
	look_at(_follow_target.global_position + Vector3.UP * follow_focus_height)


func _configure_orbit_from_offset() -> void:
	_follow_distance = follow_offset.length()
	var horizontal_length := Vector2(follow_offset.x, follow_offset.z).length()
	_orbit_yaw = atan2(follow_offset.x, follow_offset.z)
	_orbit_pitch = atan2(follow_offset.y, horizontal_length)


func _get_orbit_offset() -> Vector3:
	var horizontal_distance := _follow_distance * cos(_orbit_pitch)
	return Vector3(
		sin(_orbit_yaw) * horizontal_distance,
		sin(_orbit_pitch) * _follow_distance,
		cos(_orbit_yaw) * horizontal_distance
	)


func _get_available_shots() -> Array[CinematicShot]:
	var shots: Array[CinematicShot] = []
	for shot_path in debug_shots:
		var configured_shot := get_node_or_null(shot_path) as CinematicShot
		if configured_shot != null:
			shots.append(configured_shot)
	if not shots.is_empty():
		return shots

	for node in get_tree().get_nodes_in_group("cinematic_shots"):
		var discovered_shot := node as CinematicShot
		if discovered_shot != null:
			shots.append(discovered_shot)
	return shots

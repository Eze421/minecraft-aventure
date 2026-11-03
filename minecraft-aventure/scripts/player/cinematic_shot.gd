class_name CinematicShot
extends Marker3D

## Punto reutilizable de una cinemática. Su posición define la cámara.
@export_node_path("Node3D") var look_target_path: NodePath
@export var template: CinematicShotTemplate
@export var look_at_offset := Vector3(0.0, 1.0, 0.0)
@export_range(0.05, 5.0, 0.05, "or_greater") var transition_duration := 0.75


func _ready() -> void:
	add_to_group("cinematic_shots")


func get_look_target() -> Vector3:
	var target := get_node_or_null(look_target_path) as Node3D
	if target != null:
		return target.global_position + get_look_at_offset()
	return global_position - global_transform.basis.z * 10.0


func get_transition_duration() -> float:
	return template.transition_duration if template != null else transition_duration


func get_fov() -> float:
	return template.fov if template != null else 55.0


func get_look_at_offset() -> Vector3:
	return template.look_at_offset if template != null else look_at_offset

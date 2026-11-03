class_name CinematicShotTemplate
extends Resource

## Ajustes reutilizables para diferentes encuadres cinematográficos.
@export var display_name := "Plano personalizado"
@export_range(0.05, 5.0, 0.05, "or_greater") var transition_duration := 0.75
@export_range(20.0, 100.0, 1.0) var fov := 55.0
@export var look_at_offset := Vector3(0.0, 1.0, 0.0)

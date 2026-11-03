class_name TestScene
extends Node3D

## Controlador de la escena principal.
## Administra el sistema de cámaras cinemáticas y transiciones desde código.

static var current: TestScene

@export_group("Cámara y Encuadres")
## Referencia opcional a la CinematicCamera. Si se omite, se detecta automáticamente.
@export var cinematic_camera: CinematicCamera
## Contenedor que agrupa los nodos CinematicShot de esta escena.
@export_node_path("Node3D") var shots_container_path: NodePath

@export_group("Control y Pruebas")
## Si está activo, permite probar el cambio de cámara con teclas (1: Jugador, 2: Overview, 3: NfcCloseup).
@export var debug_keys_enabled := false

@onready var _player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var _area_nfc: Area3D = get_node_or_null("Area3D") as Area3D
@onready var _shots_container: Node3D = get_node_or_null(shots_container_path) as Node3D


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	_init_camera_reference()
	_connect_area_triggers()


## Inicializa y enlaza la cámara cinemática.
func _init_camera_reference() -> void:
	if cinematic_camera == null:
		# 1. Intentar buscar como hijo del Player
		if _player != null and _player.has_node("Camera3D"):
			cinematic_camera = _player.get_node("Camera3D") as CinematicCamera
		# 2. Intentar buscar en el grupo "cinematic_camera"
		if cinematic_camera == null:
			cinematic_camera = get_tree().get_first_node_in_group("cinematic_camera") as CinematicCamera

	if cinematic_camera != null:
		if not cinematic_camera.shot_started.is_connected(_on_camera_shot_started):
			cinematic_camera.shot_started.connect(_on_camera_shot_started)
		if not cinematic_camera.returned_to_follow.is_connected(_on_camera_returned_to_follow):
			cinematic_camera.returned_to_follow.connect(_on_camera_returned_to_follow)
	else:
		push_warning("TestScene: No se encontró una CinematicCamera en la escena.")


## Conecta eventos del mundo (como acercarse al altar NFC) para transiciones automáticas por código.
func _connect_area_triggers() -> void:
	if _area_nfc != null:
		if not _area_nfc.body_entered.is_connected(_on_area_body_entered):
			_area_nfc.body_entered.connect(_on_area_body_entered)
		if not _area_nfc.body_exited.is_connected(_on_area_body_exited):
			_area_nfc.body_exited.connect(_on_area_body_exited)


# ------------------------------------------------------------------------------
# API PÚBLICA PARA CONTROLAR CÁMARAS DESDE CÓDIGO
# ------------------------------------------------------------------------------

## Cambia a un encuadre por su nombre de nodo (ej: "Overview", "NfcCloseup").
## Opcionalmente se puede sobreescribir la duración de la transición en segundos.
func switch_to_shot(shot_name: String, transition_duration := -1.0) -> bool:
	if cinematic_camera == null:
		push_warning("TestScene: No se puede cambiar a '%s' porque no hay CinematicCamera." % shot_name)
		return false
	var shot := _find_shot(shot_name)
	if shot == null:
		push_warning("TestScene: No existe el shot '%s' en el contenedor configurado." % shot_name)
		return false
	cinematic_camera.play_shot(shot, transition_duration)
	return true


## Vuelve a la cámara de tercera persona siguiendo al jugador.
func return_to_player() -> void:
	if cinematic_camera != null:
		cinematic_camera.return_to_follow()


## Atajo por código para cambiar al plano panorámico general.
func switch_to_overview(transition_duration := -1.0) -> bool:
	return switch_to_shot("Overview", transition_duration)


## Atajo por código para enfocar el altar NFC en primer plano.
func switch_to_nfc_closeup(transition_duration := -1.0) -> bool:
	return switch_to_shot("NfcCloseup", transition_duration)


## Alterna entre un encuadre cinemático y la vista del jugador.
func toggle_shot(shot_name: String, transition_duration := -1.0) -> void:
	if cinematic_camera != null:
		var current_shot := cinematic_camera.get_current_shot()
		if current_shot != null and current_shot.name.nocasecmp_to(shot_name) == 0:
			return_to_player()
		else:
			switch_to_shot(shot_name, transition_duration)


## Retorna true si la cámara está siguiendo al jugador.
func is_following_player() -> bool:
	return cinematic_camera != null and cinematic_camera.is_following()


## Retorna la lista de nombres de todos los encuadres disponibles.
func get_available_shots() -> Array[String]:
	var names: Array[String] = []
	for shot in _get_scene_shots():
		names.append(shot.name)
	return names


func _get_scene_shots() -> Array[CinematicShot]:
	var shots: Array[CinematicShot] = []
	if _shots_container != null:
		_collect_shots(_shots_container, shots)
	return shots


func _collect_shots(node: Node, shots: Array[CinematicShot]) -> void:
	for child in node.get_children():
		var shot := child as CinematicShot
		if shot != null:
			shots.append(shot)
		_collect_shots(child, shots)


func _find_shot(shot_name: String) -> CinematicShot:
	for shot in _get_scene_shots():
		if shot.name.nocasecmp_to(shot_name) == 0:
			return shot
	return null


# ------------------------------------------------------------------------------
# REACCIONES A EVENTOS DEL JUEGO
# ------------------------------------------------------------------------------

func _on_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		# Al entrar a la zona de NFC, la cámara cambia suavemente al encuadre NfcCloseup
		switch_to_nfc_closeup()


func _on_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		# Al salir de la zona, la cámara vuelve suavemente al jugador
		return_to_player()


func _on_camera_shot_started(shot: CinematicShot) -> void:
	print("[TestScene] Cámara cambió al encuadre: '%s'" % shot.name)


func _on_camera_returned_to_follow() -> void:
	print("[TestScene] Cámara volvió a seguimiento del jugador")


# ------------------------------------------------------------------------------
# ENTRADA DE TECLADO (OPCIONAL, SOLO SI debug_keys_enabled ESTÁ ACTIVO)
# ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not debug_keys_enabled:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			KEY_1:
				return_to_player()
			KEY_2:
				switch_to_overview()
			KEY_3:
				switch_to_nfc_closeup()

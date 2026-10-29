extends CharacterBody2D

@export var speed := 240.0

func _ready() -> void:
	add_to_group("test_player")

func _physics_process(_delta: float) -> void:
	velocity = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * speed
	move_and_slide()

extends Area2D

@onready var requirement: NfcRequirement = $NfcRequirement
@onready var status: Label = $"../CanvasLayer/Status"

func _ready() -> void:
	requirement.completed.connect(_on_requirement_completed)
	requirement.rejected.connect(_on_requirement_rejected)
	status.text = "Entrá al área dorada para activar el requisito NFC."

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("test_player"):
		requirement.set_active(true)
		status.text = "Esperando %s en lector %s." % [_item_label(), _reader_label()]

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("test_player"):
		requirement.set_active(false)
		status.text = "Requisito NFC desactivado al salir del área."

func _on_requirement_completed(item: Dictionary, reader_id: int) -> void:
	status.text = "✓ Correcto: %s desde lector %d." % [item.get("id", ""), reader_id]

func _on_requirement_rejected(item: Dictionary, reader_id: int) -> void:
	status.text = "✗ No coincide: %s, lector %d." % [item.get("id", ""), reader_id]

func _item_label() -> String:
	return requirement.required_item_id if not requirement.required_item_id.is_empty() else "un ítem"

func _reader_label() -> String:
	return "cualquier lector" if requirement.required_reader_id == 0 else "lector %d" % requirement.required_reader_id

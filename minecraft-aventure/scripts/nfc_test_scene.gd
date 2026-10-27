extends Control

@onready var reader: NfcTestReader = $NfcBackground
@onready var requirement: NfcRequirement = $GameplayLayer/WoodRequirement
@onready var status: Label = %Status
@onready var endpoint: Label = %Endpoint

func _ready() -> void:
	reader.server_ready.connect(func(value): endpoint.text = "Servidor: " + value)
	requirement.started.connect(func(items): status.text = "Gameplay pide: " + ", ".join(items))
	reader.card_received.connect(func(card, reader_id): print("[Test] UI recibió lectura de ", card.get("name")))
	requirement.rejected.connect(func(card, reader_id, reason): status.text = "Rechazado: " + reason)
	requirement.item_accepted.connect(func(card, reader_id, remaining): status.text = "✓ Aceptado: " + str(card.get("name")))
	requirement.completed.connect(func(): status.text = "✓ Requisito completado.")

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_1:
		reader.nfc_events.simulate(1, "04A1B2C3D4")

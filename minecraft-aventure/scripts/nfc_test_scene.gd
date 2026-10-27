extends Control

@onready var reader: NfcTestReader = $NfcBackground
@onready var requirement: NfcRequirement = $GameplayLayer/WoodStoneRequirement
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
	if not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_1, KEY_KP_1:
			reader.nfc_events.simulate_payload(1, '{"v":1,"id":"CARD_001","name":"Madera","type":"wood"}')
		KEY_2, KEY_KP_2:
			reader.nfc_events.simulate_payload(2, '{"v":1,"id":"CARD_002","name":"Piedra","type":"stone"}')

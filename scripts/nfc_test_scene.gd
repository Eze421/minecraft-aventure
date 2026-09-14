extends Control

@onready var reader: NfcTestReader = $NfcBackground
@onready var status: Label = %Status
@onready var endpoint: Label = %Endpoint

func _ready() -> void:
	reader.server_ready.connect(func(value): endpoint.text = "Servidor: " + value)
	reader.item_requested.connect(func(card): status.text = "Gameplay pidió: " + str(card.get("name")))
	reader.card_received.connect(func(card, reader_id): print("[Test] UI recibió lectura de ", card.get("name")))
	reader.request_rejected.connect(func(expected, received): status.text = "Se pidió %s; llegó %s." % [expected.get("name"), received.get("name")])
	reader.request_completed.connect(func(card, reader_id): status.text = "✓ Gameplay recibió: " + str(card.get("name")))

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.keycode == KEY_1:
		reader.nfc_events.simulate(1, "04A1B2C3D4")

class_name NfcTestReader
extends Node

## Capa de infraestructura para la escena de prueba.
## Siempre escucha NFC, muestra cada lectura en Output y solo entrega una
## tarjeta al gameplay si éste la solicitó explícitamente.
signal server_ready(endpoint: String)
signal card_received(card: Dictionary, reader_id: int)
signal item_requested(card: Dictionary)
signal request_completed(card: Dictionary, reader_id: int)
signal request_rejected(expected: Dictionary, received: Dictionary)

const CARDS_DATA_PATH := "res://data/cards.json"
const ITEMS_DATA_PATH := "res://data/items.json"

var _database := CardDatabase.new()
var _requested_card: Dictionary = {}

@onready var nfc_events: NfcEventSource = $NfcEventSource
@onready var http_receiver: HttpNfcReceiver = $HttpNfcReceiver

func _ready() -> void:
	add_to_group("nfc_test_reader")
	add_to_group("nfc_reader")
	_database.load_from_files(CARDS_DATA_PATH, ITEMS_DATA_PATH)
	nfc_events.card_detected.connect(_on_uid_received)
	nfc_events.card_data_detected.connect(_on_card_data_received)
	nfc_events.protocol_status.connect(func(message): print("[NFC] ", message))
	http_receiver.nfc_payload_received.connect(nfc_events.parse_ndef_payload)
	http_receiver.nfc_uid_received.connect(nfc_events.simulate)
	http_receiver.server_status.connect(_on_server_status)

func request_item(reference: String) -> bool:
	var card := _database.find(reference)
	if card.is_empty():
		push_warning("[Gameplay] No existe el objeto NFC: " + reference)
		return false
	_requested_card = card
	print("[Gameplay] Solicitud NFC activa: ", card.get("id"), " (", card.get("name"), ")")
	item_requested.emit(card)
	return true

func _on_uid_received(reader_id: int, uid: String) -> void:
	print("[NFC] Datos recibidos — lector %d, UID: %s" % [reader_id, uid])
	var card := _database.find_by_uid(uid)
	if card.is_empty():
		print("[NFC] Lector %d recibió UID desconocido: %s" % [reader_id, uid])
		return
	_register_card(card, reader_id)

func _on_card_data_received(reader_id: int, card_data: Dictionary) -> void:
	print("[NFC] Datos recibidos — lector %d, NDEF: %s" % [reader_id, card_data])
	var card := _database.find_by_id(str(card_data.get("id", "")))
	if card.is_empty():
		print("[NFC] Lector %d recibió ID desconocido: %s" % [reader_id, card_data])
		return
	_register_card(card, reader_id)

func _register_card(card: Dictionary, reader_id: int) -> void:
	# Este print ocurre siempre, haya o no una solicitud de gameplay.
	print("[NFC] Lector %d recibió %s: %s" % [reader_id, card.get("id"), card.get("name")])
	card_received.emit(card, reader_id)
	if _requested_card.is_empty():
		print("[NFC] Sin solicitud activa: lectura guardada solo como diagnóstico.")
		return
	if card.get("id") != _requested_card.get("id"):
		print("[Gameplay] Se esperaba %s; se recibió %s." % [_requested_card.get("name"), card.get("name")])
		request_rejected.emit(_requested_card, card)
		return
	_requested_card = {}
	print("[Gameplay] Solicitud completada con: ", card.get("name"))
	request_completed.emit(card, reader_id)

func _on_server_status(message: String, is_error: bool) -> void:
	print("[NFC] ", message)
	if not is_error:
		server_ready.emit(http_receiver.get_endpoint_hint())

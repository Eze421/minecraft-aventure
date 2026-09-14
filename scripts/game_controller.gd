class_name GameController
extends Node

signal state_changed(title: String, instruction: String)
signal event_feedback(message: String, accepted: bool)
signal progress_changed(current: int, total: int)
signal nfc_requested(card: Dictionary)
signal nfc_request_completed(card: Dictionary, reader_id: int)

const CARD_DATA_PATH := "res://data/cards.json"
const REPEAT_LOCK_SECONDS := 1.2

var _database := CardDatabase.new()
var _expected_cards := ["CARD_001", "CARD_002", "CARD_003"]
var _step := 0
var _locked_uids: Dictionary = {}
var _requested_card: Dictionary = {}

func initialize() -> void:
	var error := _database.load_from_file(CARD_DATA_PATH)
	if error != OK:
		event_feedback.emit("No se pudo cargar la base de tarjetas.", false)
		return
	progress_changed.emit(0, _expected_cards.size())
	request_nfc(_expected_cards[_step])

## API para el gameplay. El receptor NFC sigue activo todo el tiempo, pero
## solamente esta solicitud hace que una lectura tenga efecto en el juego.
## Acepta ID, nombre o tipo: request_nfc("CARD_001"), request_nfc("Madera")
## o request_nfc("wood"). Devuelve false si el objeto no existe en el catálogo.
func request_nfc(card_reference: String) -> bool:
	var card := _database.find(card_reference)
	if card.is_empty():
		event_feedback.emit("No existe una tarjeta NFC para: " + card_reference, false)
		return false
	_requested_card = card
	state_changed.emit("Esperando NFC", "Acercá la tarjeta: " + str(card.get("name")) + ".")
	nfc_requested.emit(card)
	return true

func process_card(reader_id: int, uid: String) -> void:
	# Una lectura de fondo no debe bloquear una futura solicitud.
	if _requested_card.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _locked_uids.get(uid, 0.0) > now:
		return
	_locked_uids[uid] = now + REPEAT_LOCK_SECONDS

	var card := _database.find_by_uid(uid)
	if card.is_empty():
		return
	_process_known_card(reader_id, card)

func process_card_data(reader_id: int, card: Dictionary) -> void:
	# Los datos externos solo aportan un ID. El catálogo local es la fuente de
	# verdad para nombre/tipo y para decidir si es un objeto permitido.
	var catalog_card := _database.find_by_id(str(card.get("id", "")))
	if not catalog_card.is_empty():
		_process_known_card(reader_id, catalog_card)

func _process_known_card(reader_id: int, card: Dictionary) -> void:
	# El servidor y la app pueden leer siempre. Sin una solicitud activa no se
	# modifica el juego: la lectura queda ignorada en segundo plano.
	if _requested_card.is_empty():
		return
	if card.get("id") != _requested_card.get("id"):
		event_feedback.emit("Se pidió %s, no %s." % [_requested_card.get("name"), card.get("name")], false)
		return
	_requested_card = {}
	_step += 1
	event_feedback.emit("Correcto: %s colocado en el lector %d." % [card.get("name"), reader_id], true)
	nfc_request_completed.emit(card, reader_id)
	progress_changed.emit(_step, _expected_cards.size())
	if _step == _expected_cards.size():
		state_changed.emit("¡Construcción completada!", "El cofre se abrió. Presioná R para iniciar otra partida.")
	else:
		request_nfc(_expected_cards[_step])

func restart() -> void:
	_step = 0
	_locked_uids.clear()
	progress_changed.emit(0, _expected_cards.size())
	event_feedback.emit("Partida reiniciada.", true)
	request_nfc(_expected_cards[_step])

func _card_name(card_id: String) -> String:
	return _database.find_by_id(card_id).get("name", card_id)

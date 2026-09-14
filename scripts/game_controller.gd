class_name GameController
extends Node

signal state_changed(title: String, instruction: String)
signal event_feedback(message: String, accepted: bool)
signal progress_changed(current: int, total: int)

const CARD_DATA_PATH := "res://data/cards.json"
const REPEAT_LOCK_SECONDS := 1.2

var _database := CardDatabase.new()
var _expected_cards := ["CARD_001", "CARD_002", "CARD_003"]
var _step := 0
var _locked_uids: Dictionary = {}

func initialize() -> void:
	var error := _database.load_from_file(CARD_DATA_PATH)
	if error != OK:
		event_feedback.emit("No se pudo cargar la base de tarjetas.", false)
		return
	state_changed.emit("Prepará la mesa", "Colocá los materiales en orden: Madera, Piedra e Hierro.")
	progress_changed.emit(0, _expected_cards.size())

func process_card(reader_id: int, uid: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _locked_uids.get(uid, 0.0) > now:
		return
	_locked_uids[uid] = now + REPEAT_LOCK_SECONDS

	var card := _database.find_by_uid(uid)
	if card.is_empty():
		event_feedback.emit("Lector %d: tarjeta desconocida (%s)." % [reader_id, uid], false)
		return
	_process_known_card(reader_id, card)

func process_card_data(reader_id: int, card: Dictionary) -> void:
	_process_known_card(reader_id, card)

func _process_known_card(reader_id: int, card: Dictionary) -> void:
	if _step >= _expected_cards.size():
		event_feedback.emit("La aventura ya terminó. Presioná R para reiniciar.", false)
		return
	var expected: String = _expected_cards[_step]
	if card.get("id") != expected:
		event_feedback.emit("%s no corresponde todavía. Revisá el orden." % card.get("name"), false)
		return
	_step += 1
	event_feedback.emit("Correcto: %s colocado en el lector %d." % [card.get("name"), reader_id], true)
	progress_changed.emit(_step, _expected_cards.size())
	if _step == _expected_cards.size():
		state_changed.emit("¡Construcción completada!", "El cofre se abrió. Presioná R para iniciar otra partida.")
	else:
		var next_name := _card_name(_expected_cards[_step])
		state_changed.emit("Material aceptado", "Siguiente material: " + next_name + ".")

func restart() -> void:
	_step = 0
	_locked_uids.clear()
	state_changed.emit("Prepará la mesa", "Colocá los materiales en orden: Madera, Piedra e Hierro.")
	progress_changed.emit(0, _expected_cards.size())
	event_feedback.emit("Partida reiniciada.", true)

func _card_name(card_id: String) -> String:
	return _database.find_by_id(card_id).get("name", card_id)

class_name NfcRequirement
extends Node

## Componente reutilizable para gameplay.
##
## Configurá required_items desde el Inspector con ID, nombre o tipo de las
## tarjetas. Ejemplos: ["CARD_001"], ["wood", "stone"] o ["Madera"].
## required_reader_id = 0 acepta cualquier lector; 1..9 exige ese lector.

signal started(remaining_items: PackedStringArray)
signal item_accepted(card: Dictionary, reader_id: int, remaining_items: PackedStringArray)
signal rejected(card: Dictionary, reader_id: int, reason: String)
signal completed()

@export var required_items: PackedStringArray = []
@export_range(0, 9, 1, "or_greater") var required_reader_id := 0
@export var start_on_ready := false
@export var reset_after_completion := false

var _remaining_items: PackedStringArray = []
var _active := false
var _reader: NfcTestReader

func _ready() -> void:
	_reader = get_tree().get_first_node_in_group("nfc_reader") as NfcTestReader
	if _reader == null:
		call_deferred("_connect_reader")
	else:
		_connect_reader()
	if start_on_ready:
		call_deferred("start")

## Activa el requisito. Las lecturas anteriores no cuentan.
func start() -> bool:
	if required_items.is_empty():
		push_warning("NfcRequirement necesita al menos un ítem en required_items.")
		return false
	if _reader == null:
		_connect_reader()
	if _reader == null:
		push_warning("NfcRequirement no encontró un nodo NFC en el grupo nfc_reader.")
		return false
	_remaining_items = required_items.duplicate()
	_active = true
	started.emit(_remaining_items)
	return true

func stop() -> void:
	_active = false

func is_active() -> bool:
	return _active

func get_remaining_items() -> PackedStringArray:
	return _remaining_items.duplicate()

func _connect_reader() -> void:
	if _reader == null:
		_reader = get_tree().get_first_node_in_group("nfc_reader") as NfcTestReader
	if _reader != null and not _reader.card_received.is_connected(_on_card_received):
		_reader.card_received.connect(_on_card_received)

func _on_card_received(card: Dictionary, reader_id: int) -> void:
	if not _active:
		return
	if required_reader_id != 0 and reader_id != required_reader_id:
		rejected.emit(card, reader_id, "Se requiere el lector %d." % required_reader_id)
		return
	var matched_index := _find_matching_item(card)
	if matched_index == -1:
		rejected.emit(card, reader_id, "Esta tarjeta no forma parte del requisito.")
		return
	_remaining_items.remove_at(matched_index)
	item_accepted.emit(card, reader_id, _remaining_items)
	if _remaining_items.is_empty():
		_active = false
		completed.emit()
		if reset_after_completion:
			call_deferred("start")

func _find_matching_item(card: Dictionary) -> int:
	for index in _remaining_items.size():
		var reference := _remaining_items[index].strip_edges().to_lower()
		var matches_id := reference == str(card.get("id", "")).to_lower()
		var matches_name := reference == str(card.get("name", "")).to_lower()
		var matches_type := reference == str(card.get("type", "")).to_lower()
		if matches_id or matches_name or matches_type:
			return index
	return -1

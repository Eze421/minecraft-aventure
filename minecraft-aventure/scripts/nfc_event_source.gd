class_name NfcEventSource
extends Node

## Única entrada de eventos NFC para el juego. Un futuro adaptador serie debe
## llamar parse_serial_message(), sin tocar la lógica de la aventura.
signal card_detected(reader_id: int, uid: String)
signal card_data_detected(reader_id: int, card_data: Dictionary)
signal protocol_status(message: String)

func parse_serial_message(message: String) -> void:
	var line := message.strip_edges()
	if line == "READY" or line == "READER_CONNECTED":
		protocol_status.emit(line)
		return
	var matcher := RegEx.new()
	matcher.compile("^READER=(\\d+);UID=([0-9A-Fa-f]+)$")
	var result := matcher.search(line)
	if result == null:
		protocol_status.emit("Mensaje NFC inválido: " + line)
		return
	card_detected.emit(result.get_string(1).to_int(), result.get_string(2).to_upper())

func simulate(reader_id: int, uid: String) -> void:
	card_detected.emit(reader_id, uid.to_upper())

func parse_ndef_payload(reader_id: int, payload: String) -> void:
	var parsed = JSON.parse_string(payload)
	if not parsed is Dictionary:
		protocol_status.emit("El contenido NDEF no es un JSON valido.")
		return
	if not parsed.has("id") or not parsed.has("v"):
		protocol_status.emit("El JSON NDEF requiere los campos v e id.")
		return
	# Claves compactas para que el NDEF URI entre también en una NTAG213.
	if parsed.has("n") and not parsed.has("name"):
		parsed["name"] = parsed["n"]
	if parsed.has("t") and not parsed.has("type"):
		parsed["type"] = parsed["t"]
	card_data_detected.emit(reader_id, parsed)

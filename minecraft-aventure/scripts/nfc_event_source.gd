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
	matcher.compile("^READER=(\\d+);NDEF=(.+)$")
	var result := matcher.search(line)
	if result == null:
		if line.begins_with("READER=") and line.contains(";UID="):
			protocol_status.emit("UID recibido sin NDEF: no identifica el ítem para el juego.")
			return
		protocol_status.emit("Mensaje NFC inválido: " + line)
		return
	parse_ndef_payload(result.get_string(1).to_int(), result.get_string(2))

func simulate_payload(reader_id: int, payload: String) -> void:
	parse_ndef_payload(reader_id, payload)

func report_uid(reader_id: int, uid: String) -> void:
	protocol_status.emit("Lector %d recibió UID %s sin datos NDEF." % [reader_id, uid])

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

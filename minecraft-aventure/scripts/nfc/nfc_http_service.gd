class_name NfcHttpService
extends Node

## Servicio global: recibe GET /nfc?reader=<n>&d=<JSON> en el puerto 8080.
## No contiene lógica de gameplay. Valida el paquete y lo publica por señal.

signal item_received(item_id: String, reader_id: int, item: Dictionary)
signal invalid_request(reason: String)
signal server_started(endpoint: String)

const PORT := 8080

var _server := TCPServer.new()
var _clients: Array[StreamPeerTCP] = []

func _ready() -> void:
	var error := _server.listen(PORT, "0.0.0.0")
	if error != OK:
		push_error("NFC HTTP: no se pudo abrir el puerto %d (error %d)." % [PORT, error])
		return
	call_deferred("_announce_ready")

func _process(_delta: float) -> void:
	while _server.is_connection_available():
		_clients.append(_server.take_connection())
	for client in _clients.duplicate():
		if client.get_status() == StreamPeerTCP.STATUS_NONE:
			_clients.erase(client)
			continue
		if client.get_available_bytes() > 0:
			_handle_request(client)
			_clients.erase(client)

func endpoint() -> String:
	for address in IP.get_local_addresses():
		if _is_private_ipv4(address):
			return "http://%s:%d/nfc" % [address, PORT]
	return "http://127.0.0.1:%d/nfc" % PORT

func _announce_ready() -> void:
	server_started.emit(endpoint())
	print("[NFC HTTP] Escuchando en ", endpoint())

func _handle_request(client: StreamPeerTCP) -> void:
	var bytes: PackedByteArray = client.get_data(client.get_available_bytes())[1]
	var first_line := bytes.get_string_from_utf8().get_slice("\r\n", 0)
	var parts := first_line.split(" ")
	if parts.size() < 2 or parts[0] != "GET":
		_reply(client, 405, "Solo se acepta GET.")
		return
	var target: String = parts[1]
	if target == "/nfc":
		_reply(client, 200, "Servidor NFC activo. Falta d=<JSON>.")
		return
	if not target.begins_with("/nfc?"):
		_reply(client, 404, "Ruta no encontrada.")
		return
	var parameters := _parse_query(target.get_slice("?", 1))
	var reader_id := int(parameters.get("reader", "0"))
	if reader_id < 1:
		_reject(client, "reader debe ser un entero mayor que cero.")
		return
	var raw_payload := str(parameters.get("d", ""))
	var item: Variant = JSON.parse_string(raw_payload)
	if not item is Dictionary:
		_reject(client, "d debe ser un JSON de objeto.")
		return
	var item_id := str(item.get("id", "")).strip_edges()
	if int(item.get("v", 0)) != 1 or item_id.is_empty():
		_reject(client, "El JSON requiere v=1 e id.")
		return
	item_received.emit(item_id, reader_id, item)
	print("[NFC HTTP] Item recibido: %s desde lector %d" % [item_id, reader_id])
	_reply(client, 200, "Item recibido: %s." % item_id)

func _reject(client: StreamPeerTCP, reason: String) -> void:
	invalid_request.emit(reason)
	_reply(client, 400, reason)

func _parse_query(query: String) -> Dictionary:
	var result := {}
	for pair in query.split("&", false):
		var key_value := pair.split("=", true, 1)
		if key_value.size() == 2:
			result[key_value[0].uri_decode()] = key_value[1].uri_decode()
	return result

func _reply(client: StreamPeerTCP, status: int, body: String) -> void:
	var response := "HTTP/1.1 %d OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [status, body.to_utf8_buffer().size(), body]
	client.put_data(response.to_utf8_buffer())
	client.disconnect_from_host()

func _is_private_ipv4(address: String) -> bool:
	var octets := address.split(".")
	if octets.size() != 4:
		return false
	var first := octets[0].to_int()
	var second := octets[1].to_int()
	return first == 10 or first == 192 and second == 168 or first == 172 and second >= 16 and second <= 31

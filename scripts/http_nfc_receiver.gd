class_name HttpNfcReceiver
extends Node

## Receptor HTTP local para las lecturas que el teléfono envía por Wi-Fi.
## Recibe: GET /nfc?d=<JSON-codificado-para-URL>&reader=1
signal nfc_payload_received(reader_id: int, payload: String)
signal server_status(message: String, is_error: bool)

const PORT := 8080
var _server := TCPServer.new()
var _clients: Array[StreamPeerTCP] = []

func _ready() -> void:
	var error := _server.listen(PORT, "0.0.0.0")
	if error != OK:
		server_status.emit("No se pudo abrir el puerto %d (error %d)." % [PORT, error], true)
		return
	call_deferred("_announce_ready")

func _announce_ready() -> void:
	server_status.emit("Receptor Wi-Fi listo: " + get_endpoint_hint(), false)

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

func get_endpoint_hint() -> String:
	# IP.get_local_addresses() también incluye VPNs (por ejemplo Tailscale,
	# que usa 100.64.0.0/10). Para un teléfono en la misma Wi-Fi priorizamos
	# explícitamente los rangos privados de la red local.
	for address in IP.get_local_addresses():
		if _is_local_wifi_ipv4(address):
			return "http://%s:%d/nfc" % [address, PORT]
	return "http://IP_DE_ESTA_PC:%d/nfc" % PORT

func _is_local_wifi_ipv4(address: String) -> bool:
	var octets := address.split(".")
	if octets.size() != 4:
		return false
	var first := octets[0].to_int()
	var second := octets[1].to_int()
	return first == 10 or first == 192 and second == 168 or first == 172 and second >= 16 and second <= 31

func _handle_request(client: StreamPeerTCP) -> void:
	var bytes: PackedByteArray = client.get_data(client.get_available_bytes())[1]
	var first_line := bytes.get_string_from_utf8().get_slice("\r\n", 0)
	var parts := first_line.split(" ")
	if parts.size() < 2 or parts[0] != "GET":
		_reply(client, 405, "Solo se acepta GET.")
		return
	var target: String = parts[1]
	if target == "/nfc":
		_reply(client, 200, "Servidor NFC activo. Falta el contenido de la tarjeta (?d=...).")
		return
	if not target.begins_with("/nfc?"):
		_reply(client, 404, "Ruta no encontrada.")
		return
	var parameters := _parse_query(target.get_slice("?", 1))
	var data: String = parameters.get("d", "")
	if data.is_empty():
		_reply(client, 400, "Falta el parametro d.")
		return
	nfc_payload_received.emit(int(parameters.get("reader", "1")), data)
	_reply(client, 200, "Tarjeta recibida. Podes volver al juego.")

func _parse_query(query: String) -> Dictionary:
	var parameters := {}
	for pair in query.split("&", false):
		var key_value := pair.split("=", true, 1)
		if key_value.size() == 2:
			parameters[key_value[0].uri_decode()] = key_value[1].uri_decode()
	return parameters

func _reply(client: StreamPeerTCP, status: int, body: String) -> void:
	var response := "HTTP/1.1 %d OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [status, body.to_utf8_buffer().size(), body]
	client.put_data(response.to_utf8_buffer())
	client.disconnect_from_host()

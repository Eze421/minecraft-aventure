class_name CardDatabase
extends RefCounted

var _cards_by_uid: Dictionary = {}

func load_from_file(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	_cards_by_uid = parsed
	return OK

func find_by_uid(uid: String) -> Dictionary:
	return _cards_by_uid.get(uid.strip_edges().to_upper(), {})

func find_by_id(card_id: String) -> Dictionary:
	for card in _cards_by_uid.values():
		if card.get("id") == card_id:
			return card
	return {}

## Permite que el gameplay pida una tarjeta con su ID, nombre o tipo.
## Ejemplos: CARD_001, Madera o wood.
func find(reference: String) -> Dictionary:
	var normalized := reference.strip_edges().to_lower()
	for card in _cards_by_uid.values():
		var matches_id := str(card.get("id", "")).to_lower() == normalized
		var matches_name := str(card.get("name", "")).to_lower() == normalized
		var matches_type := str(card.get("type", "")).to_lower() == normalized
		if matches_id or matches_name or matches_type:
			return card
	return {}

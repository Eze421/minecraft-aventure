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

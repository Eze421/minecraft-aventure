class_name CardDatabase
extends RefCounted

var _items_by_id: Dictionary = {}

func load_from_file(items_path: String) -> Error:
	var items := _read_dictionary(items_path)
	if items.is_empty():
		return ERR_FILE_NOT_FOUND
	_items_by_id = items
	return OK

func find_by_id(card_id: String) -> Dictionary:
	var item: Dictionary = _items_by_id.get(card_id, {})
	if item.is_empty():
		return {}
	var card := item.duplicate()
	card["id"] = card_id
	return card

## Permite que el gameplay pida una tarjeta con su ID, nombre o tipo.
## Ejemplos: CARD_001, Madera o wood.
func find(reference: String) -> Dictionary:
	var normalized := reference.strip_edges().to_lower()
	for item_id in _items_by_id:
		var card := find_by_id(item_id)
		var matches_id := str(card.get("id", "")).to_lower() == normalized
		var matches_name := str(card.get("name", "")).to_lower() == normalized
		var matches_type := str(card.get("type", "")).to_lower() == normalized
		if matches_id or matches_name or matches_type:
			return card
	return {}

func _read_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

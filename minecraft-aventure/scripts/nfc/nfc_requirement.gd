@tool
class_name NfcRequirement
extends Node

## Componente reusable para cualquier objeto o dinámica.
## Configurá sus listas directamente desde el Inspector.

signal accepted(item: Dictionary, reader_id: int)
signal rejected(item: Dictionary, reader_id: int)
signal completed(item: Dictionary, reader_id: int)

var required_item_id := ""
var required_reader_id := 0
@export var active := false
@export var one_shot := true

func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name": "Requisito NFC/Ítem requerido",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": ",".join(_item_ids_from_catalog()),
			"usage": PROPERTY_USAGE_DEFAULT,
		},
		{
			"name": "Requisito NFC/Nombre del ítem",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY,
		},
		{
			"name": "Requisito NFC/Lector requerido",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Cualquier lector:0,Lector 1:1,Lector 2:2,Lector 3:3,Lector 4:4,Lector 5:5,Lector 6:6,Lector 7:7,Lector 8:8,Lector 9:9",
			"usage": PROPERTY_USAGE_DEFAULT,
		},
	]

func _get(property: StringName) -> Variant:
	match property:
		&"Requisito NFC/Ítem requerido":
			return required_item_id
		&"Requisito NFC/Nombre del ítem":
			return _item_name_from_catalog(required_item_id)
		&"Requisito NFC/Lector requerido":
			return required_reader_id
	return null

func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"Requisito NFC/Ítem requerido":
			required_item_id = str(value)
			notify_property_list_changed()
			return true
		&"Requisito NFC/Lector requerido":
			required_reader_id = int(value)
			return true
	return false

func _item_ids_from_catalog() -> PackedStringArray:
	var file := FileAccess.open("res://data/items.json", FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return PackedStringArray()
	var ids := PackedStringArray()
	for item_id in data:
		ids.append(str(item_id))
	ids.sort()
	return ids

func _item_name_from_catalog(item_id: String) -> String:
	var file := FileAccess.open("res://data/items.json", FileAccess.READ)
	if file == null:
		return ""
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		return ""
	var item: Dictionary = data.get(item_id, {})
	return str(item.get("name", ""))

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	NfcHttp.item_received.connect(_on_item_received)

## Devuelve true únicamente si item y lector coinciden con esta configuración.
func accepts(item_id: String, reader_id: int) -> bool:
	return active \
		and item_id == required_item_id \
		and (required_reader_id == 0 or reader_id == required_reader_id)

func reset() -> void:
	active = true

func set_active(value: bool) -> void:
	active = value

func _on_item_received(item_id: String, reader_id: int, item: Dictionary) -> void:
	if not active:
		return
	if not accepts(item_id, reader_id):
		rejected.emit(item, reader_id)
		return
	accepted.emit(item, reader_id)
	completed.emit(item, reader_id)
	if one_shot:
		active = false

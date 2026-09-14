class_name NfcTestZone
extends Area2D

@export var requested_item := "wood"
var _used := false

func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or _used:
		return
	var reader := get_tree().get_first_node_in_group("nfc_test_reader") as NfcTestReader
	if reader != null and reader.request_item(requested_item):
		_used = true

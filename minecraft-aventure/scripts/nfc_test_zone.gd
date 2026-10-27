class_name NfcTestZone
extends Area2D

@export var requirement_path: NodePath
var _used := false

func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or _used:
		return
	var requirement := get_node_or_null(requirement_path) as NfcRequirement
	if requirement != null and requirement.start():
		_used = true

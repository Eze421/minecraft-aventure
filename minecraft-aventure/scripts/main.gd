extends Control

@onready var nfc_events: NfcEventSource = $NfcEventSource
@onready var game: GameController = $GameController
@onready var http_receiver: HttpNfcReceiver = $HttpNfcReceiver
@onready var title_label: Label = %Title
@onready var instruction_label: Label = %Instruction
@onready var feedback_label: Label = %Feedback
@onready var progress_label: Label = %Progress

const SIMULATED_UIDS := ["04A1B2C3D4", "049F72AB31", "0478129ABC"]

func _ready() -> void:
	nfc_events.card_detected.connect(game.process_card)
	nfc_events.card_data_detected.connect(game.process_card_data)
	nfc_events.protocol_status.connect(_show_protocol_status)
	http_receiver.nfc_payload_received.connect(nfc_events.parse_ndef_payload)
	http_receiver.nfc_uid_received.connect(nfc_events.simulate)
	http_receiver.server_status.connect(_show_server_status)
	game.state_changed.connect(_show_state)
	game.event_feedback.connect(_show_feedback)
	game.progress_changed.connect(_show_progress)
	game.initialize()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_1, KEY_KP_1:
			nfc_events.simulate(1, SIMULATED_UIDS[0])
		KEY_2, KEY_KP_2:
			nfc_events.simulate(1, SIMULATED_UIDS[1])
		KEY_3, KEY_KP_3:
			nfc_events.simulate(1, SIMULATED_UIDS[2])
		KEY_R:
			game.restart()

func _show_state(title: String, instruction: String) -> void:
	title_label.text = title
	instruction_label.text = instruction

func _show_feedback(message: String, accepted: bool) -> void:
	feedback_label.text = message
	feedback_label.modulate = Color("8be28b") if accepted else Color("ff9a8f")

func _show_progress(current: int, total: int) -> void:
	progress_label.text = "Progreso: %d / %d" % [current, total]

func _show_protocol_status(message: String) -> void:
	_show_feedback(message, false)

func _show_server_status(message: String, is_error: bool) -> void:
	_show_feedback(message, not is_error)

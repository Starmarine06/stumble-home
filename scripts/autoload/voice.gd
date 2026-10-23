class_name Voice
extends Node
## Voice chat over the EOS RTC room that belongs to the lobby. Net calls
## room_joined() / room_left(). Without EOS (solo, ENet) every call is a safe
## no-op and only the local state changes.

signal speaking_changed(peer_name: String, speaking: bool)
signal participant_changed(peer_name: String, in_room: bool)

const ACTION := "push_to_talk"

var muted := false
var push_to_talk := false
var talk_held := false

var _room := ""
var _active := false
var _notif_status := 0
var _notif_audio := 0
var _speaking := {}
var _blocked := {}
var _bound := false


func _ready() -> void:
	register_action()


## Adds the push_to_talk input action (V) if the project does not have it yet.
static func register_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_V
	InputMap.action_add_event(ACTION, ev)


func is_active() -> bool:
	return _active


func is_speaking(peer_name: String) -> bool:
	return _speaking.get(peer_name, false)


func set_muted(value: bool) -> void:
	muted = value
	_apply_sending()


func set_push_to_talk(value: bool) -> void:
	push_to_talk = value
	_apply_sending()


func set_participant_muted(id: String, value: bool) -> void:
	_blocked[id] = value
	if not _active:
		return
	var o := EOS.RTCAudio.UpdateReceivingOptions.new()
	o.room_name = _room
	o.participant_id = id
	o.audio_enabled = not value
	EOS.RTCAudio.RTCAudioInterface.update_receiving(o)


func is_participant_muted(id: String) -> bool:
	return _blocked.get(id, false)


func _input(event: InputEvent) -> void:
	if event.is_action(ACTION) and not event.is_echo():
		talk_held = event.is_pressed()
		_apply_sending()


## True when the microphone should currently be transmitting.
func is_transmitting() -> bool:
	if muted:
		return false
	return talk_held or not push_to_talk


# --- Net hooks ---------------------------------------------------------------

## Called after a lobby is created or joined. rtc tells whether it has a voice room.
func room_joined(lobby_id: String, rtc: bool) -> void:
	room_left()
	if not rtc or lobby_id == "" or not _eos_available():
		return
	var o := EOS.Lobby.GetRtcRoomNameOptions.new()
	o.lobby_id = lobby_id
	var ret = EOS.Lobby.LobbyInterface.get_rtc_room_name(o)
	if not EOS.is_success(ret) or str(ret.get("rtc_room_name", "")) == "":
		return
	_room = ret.rtc_room_name
	if not _bound:
		_bound = true
		IEOS.rtc_interface_participant_status_changed.connect(handle_participant_status)
		IEOS.rtc_audio_participant_updated.connect(handle_audio_status)
	var s := EOS.RTC.AddNotifyParticipantStatusChangedOptions.new()
	s.room_name = _room
	_notif_status = EOS.RTC.RTCInterface.add_notify_participant_status_changed(s)
	var a := EOS.RTCAudio.AddNotifyParticipantUpdatedOptions.new()
	a.room_name = _room
	_notif_audio = EOS.RTCAudio.RTCAudioInterface.add_notify_participant_updated(a)
	_active = true
	_apply_sending()
	for id in _blocked:
		if _blocked[id]:
			set_participant_muted(id, true)


func room_left() -> void:
	if _active and _eos_available():
		if _notif_status != EOS.NotificationIdInvalid:
			EOS.RTC.RTCInterface.remove_notify_participant_status_changed(_notif_status)
		if _notif_audio != EOS.NotificationIdInvalid:
			EOS.RTCAudio.RTCAudioInterface.remove_notify_participant_updated(_notif_audio)
	_notif_status = 0
	_notif_audio = 0
	_active = false
	_room = ""
	for id in _speaking.keys():
		if _speaking[id]:
			speaking_changed.emit(id, false)
	_speaking.clear()


# --- Notification handlers -----------------------------------------------------

## data: {room_name, participant_id, speaking, audio_status}
func handle_audio_status(data: Dictionary) -> void:
	if not _same_room(data):
		return
	var id := str(data.get("participant_id", ""))
	if id == "":
		return
	var on := bool(data.get("speaking", false))
	if _speaking.get(id, false) == on:
		return
	_speaking[id] = on
	speaking_changed.emit(id, on)


## data: {room_name, participant_id, participant_status}
func handle_participant_status(data: Dictionary) -> void:
	if not _same_room(data):
		return
	var id := str(data.get("participant_id", ""))
	if id == "":
		return
	var joined := int(data.get("participant_status", 0)) == 0 # EOS.RTC.ParticipantStatus.Joined
	participant_changed.emit(id, joined)
	if not joined and _speaking.get(id, false):
		_speaking[id] = false
		speaking_changed.emit(id, false)


# --- Internals -----------------------------------------------------------------

func _same_room(data: Dictionary) -> bool:
	var r := str(data.get("room_name", ""))
	return _room == "" or r == "" or r == _room


func _eos_available() -> bool:
	var parent := get_parent()
	return parent != null and parent.get("_eos_ready") == true


func _apply_sending() -> void:
	if not _active:
		return
	var o := EOS.RTCAudio.UpdateSendingOptions.new()
	o.room_name = _room
	o.audio_status = EOS.RTCAudio.AudioStatus.Enabled if is_transmitting() else EOS.RTCAudio.AudioStatus.Disabled
	EOS.RTCAudio.RTCAudioInterface.update_sending(o)

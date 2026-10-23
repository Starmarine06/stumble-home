extends SceneTree
## Voice autoload checks, offline. Run:
##   godot --headless --path . -s res://tests/voice_test.gd

var _fails := 0
var _events: Array = []


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _on_speaking(peer_name: String, speaking: bool) -> void:
	_events.append([peer_name, speaking])


func _key_action(pressed: bool) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = "push_to_talk"
	ev.pressed = pressed
	return ev


func _run() -> void:
	var net := root.get_node("Net")
	var voice = net.get_node_or_null("Voice")
	_check(voice != null, "Net has a Voice child")
	if voice == null:
		quit(1)
		return
	_check(not voice.is_active(), "not active without EOS")

	voice.set_muted(true)
	_check(voice.muted, "set_muted updates state")
	voice.set_muted(false)
	_check(not voice.muted, "unmute updates state")
	voice.set_push_to_talk(true)
	_check(voice.push_to_talk, "set_push_to_talk updates state")
	_check(not voice.is_transmitting(), "push to talk silent until pressed")
	voice._input(_key_action(true))
	_check(voice.talk_held and voice.is_transmitting(), "push_to_talk press transmits")
	voice._input(_key_action(false))
	_check(not voice.talk_held and not voice.is_transmitting(), "push_to_talk release stops")
	voice.set_push_to_talk(false)
	voice.set_participant_muted("someone", true)
	_check(voice.is_participant_muted("someone"), "participant mute stored offline")
	voice.room_joined("SHABCDE", true)
	_check(not voice.is_active(), "room_joined is a no-op without EOS")
	voice.room_joined("SHABCDE", false)
	voice.room_left()

	_check(InputMap.has_action("push_to_talk"), "push_to_talk action exists")
	var found := false
	for ev in InputMap.action_get_events("push_to_talk"):
		if ev is InputEventKey and ev.physical_keycode == KEY_V:
			found = true
	_check(found, "push_to_talk is bound to KEY_V")

	voice.speaking_changed.connect(_on_speaking)
	voice.handle_audio_status({"room_name": "r", "participant_id": "p1", "speaking": true, "audio_status": 1})
	voice.handle_audio_status({"room_name": "r", "participant_id": "p1", "speaking": true, "audio_status": 1})
	_check(_events == [["p1", true]], "fake audio status emits speaking_changed once")
	voice.handle_audio_status({"room_name": "r", "participant_id": "p1", "speaking": false, "audio_status": 1})
	_check(_events == [["p1", true], ["p1", false]], "speaking stop emits")
	voice.handle_audio_status({"room_name": "r", "participant_id": "p2", "speaking": true})
	voice.handle_participant_status({"room_name": "r", "participant_id": "p2", "participant_status": 1})
	_check(_events.back() == ["p2", false], "participant leaving clears speaking")

	print("voice_test: %d failure(s)" % _fails)
	quit(1 if _fails > 0 else 0)

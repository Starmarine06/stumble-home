extends SceneTree
## Headless audio hook test. Run:
##   godot --headless --path . -s res://tests/audio_test.gd

var _fails := 0


func _check(cond: bool, label: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + label)
	if not cond:
		_fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var audio := root.get_node("Audio")
	var game := root.get_node("Game")
	for b in ["SFX", "Music", "Voice"]:
		_check(AudioServer.get_bus_index(b) != -1, "bus " + b)
	audio.play(&"nonexistent")
	_check(true, "play nonexistent does not error")
	game.cop_warning.emit("left", 3.0)
	_check(audio.played.get(&"cop_siren", 0) == 1, "cop_warning -> cop_siren")
	game.engine_hot = true
	game.stats_changed.emit()
	game.stats_changed.emit()
	_check(audio.played.get(&"engine_overheat", 0) == 1, "overheat rising edge once")
	game.won = true
	game._set_phase(game.Phase.RESULT)
	_check(audio.played.get(&"win", 0) == 1, "RESULT won -> win")
	quit(1 if _fails > 0 else 0)

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

	# Hazard and kebab audio hooks
	game.hazard_hit.emit("dog")
	_check(audio.played.get(&"dog_bark", 0) == 1, "Game.hazard_hit('dog') -> dog_bark")
	game.hazard_hit.emit("traffic")
	_check(audio.played.get(&"horn", 0) == 1, "Game.hazard_hit('traffic') -> horn")
	game.hazard_hit.emit("mugger")
	_check(audio.played.get(&"mugger", 0) == 1, "Game.hazard_hit('mugger') -> mugger")
	game.kebab_opened.emit(123, 1)
	_check(audio.played.get(&"kebab_open", 0) == 1, "kebab_opened -> kebab_open")
	game.kebab_reward.emit(1.0)
	_check(audio.played.get(&"kebab_done", 0) == 1, "kebab_reward -> kebab_done")

	# HUD voice indicator check
	var hud_cls = load("res://scripts/ui/hud.gd")
	var hud = hud_cls.new()
	root.add_child(hud)
	var vi = hud.get_node_or_null("VoiceIndicator")
	_check(vi != null, "HUD voice indicator node exists")
	_check(vi != null and not vi.visible, "HUD voice indicator hidden when voice inactive")
	hud.queue_free()

	quit(1 if _fails > 0 else 0)

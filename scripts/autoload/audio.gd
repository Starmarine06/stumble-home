extends Node
## Audio hub: buses, event registry, pooled one-shots, and hooks onto Game signals.
## Missing streams are a silent no-op; `played` still counts every trigger.

const POOL_SIZE := 12
const PLACEHOLDER_HZ := {
	&"clang": 180.0, &"part_fit_good": 660.0, &"part_fit_bad": 220.0, &"part_fell": 140.0,
	&"rattle": 300.0, &"passout": 110.0, &"cop_siren": 880.0, &"engine_overheat": 400.0,
	&"engine_cooled": 520.0, &"crash": 90.0, &"win": 784.0, &"lose": 130.0, &"ui_click": 1000.0,
	&"dog_bark": 320.0, &"horn": 440.0, &"mugger": 160.0, &"kebab_open": 587.0, &"kebab_done": 784.0,
}

## event -> stream path (files are optional; placeholder tone plays when absent)
var events := {
	&"clang": "res://audio/sfx/clang.ogg",
	&"part_fit_good": "res://audio/sfx/part_fit_good.ogg",
	&"part_fit_bad": "res://audio/sfx/part_fit_bad.ogg",
	&"part_fell": "res://audio/sfx/part_fell.ogg",
	&"rattle": "res://audio/sfx/rattle.ogg",
	&"passout": "res://audio/sfx/passout.ogg",
	&"cop_siren": "res://audio/sfx/cop_siren.ogg",
	&"engine_overheat": "res://audio/sfx/engine_overheat.ogg",
	&"engine_cooled": "res://audio/sfx/engine_cooled.ogg",
	&"crash": "res://audio/sfx/crash.ogg",
	&"win": "res://audio/sfx/win.ogg",
	&"lose": "res://audio/sfx/lose.ogg",
	&"ui_click": "res://audio/sfx/ui_click.ogg",
	&"dog_bark": "res://audio/sfx/dog_bark.ogg",
	&"horn": "res://audio/sfx/horn.ogg",
	&"mugger": "res://audio/sfx/mugger.ogg",
	&"kebab_open": "res://audio/sfx/kebab_open.ogg",
	&"kebab_done": "res://audio/sfx/kebab_done.ogg",
}
var played := {}
var use_placeholders := true

var _players2d: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _next2d := 0
var _next3d := 0
var _cache := {}
var _was_hot := false
var _last_hp := -1.0


func _ready() -> void:
	_setup_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players2d.append(p)
		var q := AudioStreamPlayer3D.new()
		q.bus = &"SFX"
		add_child(q)
		_players3d.append(q)
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	game.cop_warning.connect(_on_cop_warning)
	game.phase_changed.connect(_on_phase_changed)
	game.stats_changed.connect(_on_stats_changed)
	game.toast_msg.connect(_on_toast)
	game.hazard_hit.connect(_on_hazard_hit)
	game.kebab_opened.connect(_on_kebab_opened)
	game.kebab_reward.connect(_on_kebab_reward)


func _setup_buses() -> void:
	for bus_name in ["SFX", "Music", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


## Plays an event as a 3D one-shot when pos is a Vector3, else 2D.
func play(event: StringName, pos = null) -> void:
	played[event] = int(played.get(event, 0)) + 1
	var stream := _get_stream(event)
	if stream == null or _players2d.is_empty():
		return
	if pos is Vector3:
		var q := _players3d[_next3d]
		_next3d = (_next3d + 1) % _players3d.size()
		q.stream = stream
		q.global_position = pos
		q.play()
	else:
		var p := _players2d[_next2d]
		_next2d = (_next2d + 1) % _players2d.size()
		p.stream = stream
		p.play()


func _get_stream(event: StringName) -> AudioStream:
	if _cache.has(event):
		return _cache[event]
	var stream: AudioStream = null
	var path: String = events.get(event, "")
	if path != "" and ResourceLoader.exists(path):
		stream = load(path)
	elif use_placeholders and PLACEHOLDER_HZ.has(event):
		stream = make_tone(PLACEHOLDER_HZ[event], 0.18)
	_cache[event] = stream
	return stream


## Cheap generated sine blip with a decay envelope.
func make_tone(hz: float, length: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var env := 1.0 - float(i) / n
		var s := int(sin(TAU * hz * i / rate) * env * 0.4 * 32767.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func _on_cop_warning(_side: String, _seconds: float) -> void:
	play(&"cop_siren")


func _on_phase_changed() -> void:
	var game := get_node("/root/Game")
	if game.phase == game.Phase.RESULT:
		play(&"win" if game.won else &"lose")


func _on_stats_changed() -> void:
	var game := get_node("/root/Game")
	var hot: bool = game.engine_hot
	if hot and not _was_hot:
		play(&"engine_overheat")
	_was_hot = hot
	var hp: float = game.car_hp
	if _last_hp >= 0.0 and _last_hp - hp >= 8.0:
		play(&"crash")
	_last_hp = hp


func _on_toast(text: String) -> void:
	if text.begins_with("Clang!"):
		play(&"clang")
	elif text.ends_with("fitted perfectly!") or text.ends_with("fitted. Good enough."):
		play(&"part_fit_good")
	elif text.ends_with("That will not hold."):
		play(&"part_fit_bad")
	elif text.begins_with("Something is rattling"):
		play(&"rattle")
	elif text.ends_with("fell off the car!"):
		play(&"part_fell")
	elif text.contains("passed out"):
		play(&"passout")
	elif text.begins_with("Engine cooled"):
		play(&"engine_cooled")


func _on_hazard_hit(kind: String) -> void:
	match kind:
		"dog":
			play(&"dog_bark")
		"traffic":
			play(&"horn")
		"mugger":
			play(&"mugger")


func _on_kebab_opened(_order_seed: int, _reader_peer: int) -> void:
	play(&"kebab_open")


func _on_kebab_reward(_sober: float) -> void:
	play(&"kebab_done")


class_name CarFx
extends Node3D

var car: Node3D
var engine_bay: Node3D
var exhaust: Node3D
var smoke: CPUParticles3D
var sparks: CPUParticles3D
var puff: CPUParticles3D
var _shake_tw: Tween
var _shake_base := {}


func setup(c: Node3D) -> void:
	car = c
	engine_bay = c.get_node_or_null("EngineBay") as Node3D if c else null
	exhaust = c.get_node_or_null("Exhaust") as Node3D if c else null
	if get_parent() == null and c != null:
		c.add_child(self)
	smoke = _make_particles(Color(0.08, 0.08, 0.08, 0.8), 1.6, 24, Vector3(0, 1, 0), 0.8, 0.5)
	smoke.emitting = true
	puff = _make_particles(Color(0.6, 0.6, 0.6, 0.6), 0.6, 12, Vector3(0, 0.3, -1), 1.5, 0.25)
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.emitting = false
	sparks = _make_particles(Color(1.0, 0.8, 0.2), 0.5, 20, Vector3(0, 1, 0), 4.0, 0.05)
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.gravity = Vector3(0, -9.8, 0)
	sparks.spread = 80.0
	sparks.emitting = false
	if engine_bay:
		engine_bay.add_child(smoke)
	else:
		add_child(smoke)
	if exhaust:
		exhaust.add_child(puff)
	else:
		add_child(puff)
	add_child(sparks)
	set_repair(0.0)


func _make_particles(col: Color, life: float, amount: int, dir: Vector3, vel: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = 25.0
	p.initial_velocity_min = vel * 0.6
	p.initial_velocity_max = vel
	p.gravity = Vector3(0, 0.5, 0)
	p.color = col
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	p.mesh = m
	return p


func set_repair(t: float) -> void:
	if smoke == null:
		return
	t = clampf(t, 0.0, 1.0)
	smoke.emitting = t < 1.0
	var dmg := 1.0 - t
	smoke.amount = maxi(1, int(ceil(32.0 * dmg)))
	smoke.scale_amount_min = 0.4 + 0.6 * dmg
	smoke.scale_amount_max = 0.6 + 1.0 * dmg
	smoke.color = Color(0.08 + 0.4 * t, 0.08 + 0.4 * t, 0.08 + 0.4 * t, 0.8 * (1.0 - t * 0.5))


func is_smoking() -> bool:
	return smoke != null and smoke.emitting


func spark_burst(local_pos: Vector3) -> void:
	if sparks == null:
		return
	sparks.position = local_pos
	if sparks.is_inside_tree():
		sparks.restart()
	sparks.emitting = true


func _shake_nodes() -> Array:
	var out: Array = []
	if car == null:
		return out
	for c in car.get_children():
		if c is Node3D and c != self and c != engine_bay and c != exhaust:
			out.append(c)
	return out


func _restore_shake() -> void:
	if _shake_tw and _shake_tw.is_valid():
		_shake_tw.kill()
	_shake_tw = null
	for n in _shake_base:
		if is_instance_valid(n):
			n.position = _shake_base[n]
	_shake_base.clear()


func engine_start() -> void:
	if puff:
		if puff.is_inside_tree():
			puff.restart()
		puff.emitting = true
	if car == null or not car.is_inside_tree():
		return
	_restore_shake()
	var nodes := _shake_nodes()
	if nodes.is_empty():
		return
	for n in nodes:
		_shake_base[n] = n.position
	_shake_tw = create_tween().set_parallel(false)
	for i in 4:
		var off := Vector3(randf_range(-0.04, 0.04), randf_range(0.0, 0.03), randf_range(-0.04, 0.04))
		_shake_tw.tween_callback(_apply_shake.bind(off))
		_shake_tw.tween_interval(0.04)
	_shake_tw.tween_callback(_restore_shake)


func _apply_shake(off: Vector3) -> void:
	for n in _shake_base:
		if is_instance_valid(n):
			n.position = _shake_base[n] + off


func flicker_lights(lights: Array) -> void:
	for l in lights:
		if not (l is Light3D) or not l.is_inside_tree():
			continue
		if not l.has_meta("fx_base_energy"):
			l.set_meta("fx_base_energy", l.light_energy)
		var base: float = l.get_meta("fx_base_energy")
		if l.has_meta("fx_tween"):
			var old = l.get_meta("fx_tween")
			if old is Tween and old.is_valid():
				old.kill()
		l.light_energy = base
		var tw: Tween = l.create_tween()
		l.set_meta("fx_tween", tw)
		tw.tween_property(l, "light_energy", 0.0, 0.05)
		tw.tween_property(l, "light_energy", base, 0.05)
		tw.tween_property(l, "light_energy", 0.0, 0.05)
		tw.tween_property(l, "light_energy", base, 0.1)

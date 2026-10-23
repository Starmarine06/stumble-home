class_name CarFx
extends Node3D

var car: Node3D
var engine_bay: Node3D
var exhaust: Node3D
var smoke: CPUParticles3D
var sparks: CPUParticles3D
var puff: CPUParticles3D


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


func engine_start() -> void:
	if puff:
		if puff.is_inside_tree():
			puff.restart()
		puff.emitting = true
	if car == null or not car.is_inside_tree():
		return
	var origin := car.position
	var tw := car.create_tween()
	for i in 4:
		tw.tween_property(car, "position", origin + Vector3(randf_range(-0.04, 0.04), randf_range(0.0, 0.03), randf_range(-0.04, 0.04)), 0.04)
	tw.tween_property(car, "position", origin, 0.05)


func flicker_lights(lights: Array) -> void:
	for l in lights:
		if l is Light3D and l.is_inside_tree():
			var base: float = l.light_energy
			var tw: Tween = l.create_tween()
			tw.tween_property(l, "light_energy", 0.0, 0.05)
			tw.tween_property(l, "light_energy", base, 0.05)
			tw.tween_property(l, "light_energy", 0.0, 0.05)
			tw.tween_property(l, "light_energy", base, 0.1)

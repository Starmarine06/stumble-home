extends SceneTree

var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", msg)


func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)


func _initialize() -> void:
	var car: Node3D = load("res://scripts/world/car_model.gd").build()
	root.add_child(car)
	check(car.name == "Car", "name")
	for m in ["EngineBay", "Exhaust", "HeadlightL", "HeadlightR"]:
		check(car.get_node_or_null(m) is Node3D, "marker " + m)
	var sb: StaticBody3D = null
	for c in car.get_children():
		if c is StaticBody3D:
			sb = c
	check(sb != null, "static body")
	if sb:
		var shp = sb.get_child(0).shape
		check(shp is BoxShape3D and shp.size.is_equal_approx(Vector3(2.2, 1.6, 4.4)), "box collider")
		check(is_equal_approx(sb.position.y, 0.8), "collider y")
	var meshes: Array = []
	_meshes(car, meshes)
	check(meshes.size() >= 25, "mesh count %d" % meshes.size())
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for mi in meshes:
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != car:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var bb: AABB = xf * mi.mesh.get_aabb()
		lo = Vector2(minf(lo.x, bb.position.x), minf(lo.y, bb.position.z))
		hi = Vector2(maxf(hi.x, bb.end.x), maxf(hi.y, bb.end.z))
	print("footprint ", hi - lo)
	check(hi.x - lo.x <= 2.4 and hi.y - lo.y <= 4.6, "footprint")
	var mat: StandardMaterial3D = car.get_meta("body_mat")
	var cm = load("res://scripts/world/car_model.gd")
	cm.set_repair(car, 0.0)
	var a: Color = mat.albedo_color
	cm.set_repair(car, 1.0)
	var b: Color = mat.albedo_color
	check(a != b, "colour changes")
	print("failures: ", fails)
	quit(fails)

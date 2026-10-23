extends SceneTree

var fails := 0


func check(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", m)


func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)


func _init() -> void:
	var s = load("res://scripts/world/yard_props.gd")
	var a = s.build(1, [])
	var b = s.build(1, [])
	check(a.get_child_count() == b.get_child_count(), "same child count")
	check(a.get_child(0).position == b.get_child(0).position, "same first child pos")
	var ms := []
	_meshes(a, ms)
	check(ms.size() >= 40 and ms.size() <= 400, "mesh count %d" % ms.size())
	var keep := [Vector3(10, 0, 0), Vector3(-15, 0, 12), Vector3(0, 0, -25), Vector3(38, 0, 0)]
	var c = s.build(1, keep)
	var cm := []
	_meshes(c, cm)
	for m in cm:
		var p: Vector3 = m.global_position if m.is_inside_tree() else m.get_parent_node_3d().position + m.position
		# nested shells: compute via transform chain
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n and n != c:
			if n is Node3D:
				t = n.transform * t
			n = n.get_parent()
		p = t.origin
		for k in keep:
			check(Vector2(p.x - k.x, p.z - k.z).length() >= 6.0, "prop near keep_clear %s" % str(p))
	print("meshes: ", ms.size(), " failures: ", fails)
	a.free()
	b.free()
	c.free()
	quit(fails)

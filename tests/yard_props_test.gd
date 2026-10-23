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


func _world_pos(m: Node, root: Node) -> Vector3:
	var t := Transform3D.IDENTITY
	var n: Node = m
	while n and n != root:
		if n is Node3D:
			t = n.transform * t
		n = n.get_parent()
	return t.origin


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
	for sd in [1, 7, 42]:
		var c = s.build(sd, keep)
		var cm := []
		_meshes(c, cm)
		check(cm.size() >= 40 and cm.size() <= 400, "keep mesh count %d (seed %d)" % [cm.size(), sd])
		for m in cm:
			var p := _world_pos(m, c)
			for k in keep:
				check(Vector2(p.x - k.x, p.z - k.z).length() >= 6.0, "prop near keep_clear %s" % str(p))
		# colliders only on non-tyre/barrel/pallet props: all bodies on layer 1
		for m in cm:
			for ch in m.get_children():
				if ch is StaticBody3D:
					check(ch.collision_layer == 1, "collider layer")
		c.free()
	print("meshes: ", ms.size(), " failures: ", fails)
	a.free()
	b.free()
	quit(fails)

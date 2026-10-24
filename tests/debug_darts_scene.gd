extends SceneTree

func _init() -> void:
	var sc = load("res://scenes/feature_main.tscn").instantiate()
	root.add_child(sc)
	for i in 4:
		await process_frame
	var db = sc.find_child("DartBoard3D", true, false)
	print("DartBoard node: ", db)
	if db:
		print("DB global_position: ", db.global_position)
		print("DB position: ", db.position)
		print("DB children count: ", db.get_child_count())
		for c in db.get_children():
			print("  Child: ", c.name, " class: ", c.get_class(), " pos: ", c.position)
	var barney = sc.find_child("NPC_Barney", true, false)
	print("Barney node: ", barney)
	if barney:
		print("Barney global_position: ", barney.global_position)
	var pub = sc.find_child("PubCasinoBuilding", true, false)
	print("PubCasino global_position: ", pub.global_position if pub else "null")
	quit(0)

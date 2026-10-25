class_name DeliverySite
extends Node3D
## The delivery shop's in-world pieces: the scooter parked outside, the job board at the shop door,
## the parcel (carried, or loose on the road) and the beacon over the address it is going to.
## It listens to the host's job state in Game and only draws it.

var world: Node3D                 # the World; untyped because World owns this node
var scooter: Scooter
var parcel: Interactable
var dest: Interactable
var board_count := 0              # how many job boards have been built (the shop's block can reload)

var _beacon: MeshInstance3D
var _dest_job := -1
var _mat_beacon := StandardMaterial3D.new()


func setup() -> void:
	scooter = Scooter.new()
	scooter.name = "Scooter"
	add_child(scooter)
	var shop: Dictionary = Game.city.landmarks.get("delivery", {})
	if not shop.is_empty():
		var f: Vector3 = shop.facing
		var along := Vector3(f.z, 0.0, -f.x)
		scooter.place(Game.shop_front() + along * 5.0 + Vector3(0, 0.1, 0), atan2(-along.x, -along.z))
	_build_parcel()
	_build_dest()
	Game.job_changed.connect(_sync)
	_sync()


func _exit_tree() -> void:
	if Game.job_changed.is_connected(_sync):
		Game.job_changed.disconnect(_sync)


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, emit := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)


func _build_parcel() -> void:
	parcel = Interactable.new()
	parcel.name = "Parcel"
	parcel.range_m = 2.6
	parcel.prompt = "[E] pick up the parcel"
	parcel.visible = false
	add_child(parcel)
	_box(parcel, Vector3(0.5, 0.32, 0.4), Vector3(0, 0.16, 0), Color(0.55, 0.38, 0.2))
	_box(parcel, Vector3(0.52, 0.34, 0.08), Vector3(0, 0.16, 0), Color(0.9, 0.8, 0.3), 0.4)
	parcel.activated.connect(func(_p): Game.request_parcel_pickup())


func _build_dest() -> void:
	dest = Interactable.new()
	dest.name = "DeliveryDoor"
	dest.range_m = 4.0
	dest.visible = false
	add_child(dest)
	_beacon = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.6
	cm.bottom_radius = 0.9
	cm.height = 90.0
	_beacon.mesh = cm
	_mat_beacon.albedo_color = Color(1.0, 0.6, 0.15, 0.35)
	_mat_beacon.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_beacon.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_beacon.emission_enabled = true
	_mat_beacon.emission = Color(1.0, 0.6, 0.15)
	_beacon.material_override = _mat_beacon
	_beacon.position.y = 45.0
	dest.add_child(_beacon)
	dest.activated.connect(func(_p): Game.request_deliver())


## Called by the city as each reserved lot is built; the delivery shop gets its job board.
func on_special(lot: Dictionary, parent: Node3D, _pos: Vector3, _size: Vector3) -> void:
	if lot.special != "delivery":
		return
	var board := Interactable.new()
	board.name = "JobBoard"
	board.position = Game.city.front_point(lot) - Game.city.block_center(lot.block)
	board.prompt = "[E] job board: pick a sketchy delivery"
	board.range_m = 3.2
	parent.add_child(board)
	_box(board, Vector3(1.8, 1.3, 0.12), Vector3(0, 1.4, 0), Color(0.12, 0.1, 0.08))
	_box(board, Vector3(1.6, 0.2, 0.14), Vector3(0, 1.8, 0), Color(0.95, 0.55, 0.1), 1.0)
	_box(board, Vector3(0.12, 1.0, 0.12), Vector3(-0.8, 0.5, 0), Color(0.2, 0.2, 0.2))
	_box(board, Vector3(0.12, 1.0, 0.12), Vector3(0.8, 0.5, 0), Color(0.2, 0.2, 0.2))
	board.activated.connect(func(player): world.open_modal(OrderBoardPanel.new(), player))
	board_count += 1


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	var job: Dictionary = Game.job
	if job.is_empty():
		parcel.visible = false
		parcel.enabled = false
		dest.visible = false
		dest.enabled = false
		_dest_job = -1
		return
	if int(job.id) != _dest_job:
		_dest_job = int(job.id)
		var lot := Game.city.lot_by_id(int(job.lot))
		dest.position = Game.to_world(Game.city.front_point(lot))
		dest.prompt = "[E] hand the parcel over (%s)" % job.addr
	dest.visible = true
	dest.enabled = Game.carried_job_by(Game.my_id())
	parcel.enabled = job.state == "loose"
	parcel.visible = true
	parcel.prompt = "[E] pick up the parcel (%s)" % job.item
	if job.state == "loose":
		parcel.global_position = job.pos + Vector3(0, 0.05, 0)
		parcel.rotation = Vector3.ZERO
	else:
		var holder := world.players.get_node_or_null(str(int(job.carrier))) as Node3D
		if holder != null:
			parcel.global_position = holder.global_position + holder.global_transform.basis * Vector3(0.35, 0.95, -0.55)
			parcel.global_rotation.y = holder.global_rotation.y
		else:
			parcel.visible = false

extends Node
## Shared game state and all gameplay RPCs. The host (peer 1) is the referee:
## clients send requests, the host validates and broadcasts the result.

signal roster_changed
signal phase_changed
signal parts_changed
signal stats_changed
signal toast_msg(text: String)
signal cop_warning(side: String, seconds: float)
signal car_state(pos: Vector3, yaw: float, speed: float)
signal spawn_players
signal drive_started(drive_seed: int)

enum Phase { MENU, LOBBY, SCAVENGE, DRIVE, RESULT }
enum PS { WORLD, CARRIED, INSTALLED }

const PART_NAMES := ["Battery", "Fuel Pump", "Spark Plugs", "Spare Tyre"]
## Where each part belongs, in car-local space (the car faces -Z).
const SLOTS := [Vector3(0.5, 1.35, -1.7), Vector3(0, 0.6, 2.5), Vector3(-0.5, 1.35, -1.7), Vector3(1.5, 0.9, 0.0)]
const SLOT_YAW := [PI * 0.5, 0.0, 0.0, 0.0]
const SLOT_SYMMETRIC := [false, true, true, true]  # round parts do not care which way they face
const PART_MASS := [12.0, 5.0, 0.4, 9.0]            # kg: heavy things really are hard to hold
const PLACE_R := 0.5         # let go this close to the slot and it seats; any further and it just drops
const SOLID_Q := 0.75        # fitted at least this well and it will never come loose
const PASSOUT_SECS := 25.0   # how long a worn-out hauler stays down
const WANTED_MAX := 100.0
const CAR_POS := Vector3.ZERO

var phase: int = Phase.MENU
var names: Dictionary = {}        # peer_id -> display name
var role_owner: Dictionary = {}   # Roles.Id -> peer_id
var world_seed := 0
var drive_seed := 0
var parts: Array = []             # [{name, state, holder, pos, yaw, q, loose_t, warned}]; pos is the part origin (ground level when resting)
var fatigue: Dictionary = {}      # peer -> 0..1; only non-Mechanics tire from hauling parts
var out_left: Dictionary = {}     # peer -> seconds left passed out
var build_damage := 0.0           # car damage from sloppy fitting, carried into the drive
var coolers: Array = []           # water cooler positions
var wanted := 0.0
var car_hp := 100.0
var engine_hot := false
var won := false
var result_text := ""

var _fat_sync := 0.0
var _ready_peers: Dictionary = {}
var _stat_timer := 0.0
var _phase_timer := 0.0
var _hot_timer := 0.0
var _cop_timer := 0.0
var _cop_open := false
var _cop_left := 0.0


func _ready() -> void:
	_setup_input()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _setup_input() -> void:
	var map := {
		"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN],
		"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"act": [KEY_E], "turn_l": [KEY_Q], "turn_r": [KEY_E],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "flashlight": [KEY_F],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


# --- Helpers -----------------------------------------------------------------

func my_id() -> int:
	return multiplayer.get_unique_id()


func is_host() -> bool:
	return multiplayer.is_server()


func roles_of(peer: int) -> Array:
	var out: Array = []
	for r in role_owner:
		if role_owner[r] == peer:
			out.append(r)
	out.sort()
	return out


func my_roles() -> Array:
	return roles_of(my_id())


func has_role(r: int) -> bool:
	return role_owner.get(r, -1) == my_id()


func has_role_for(peer: int, r: int) -> bool:
	return role_owner.get(r, -1) == peer


func is_out(peer: int) -> bool:
	return out_left.get(peer, 0.0) > 0.0


func fatigue_of(peer: int) -> float:
	return fatigue.get(peer, 0.0)


func carried_by(peer: int) -> int:
	for i in parts.size():
		if parts[i].state == PS.CARRIED and parts[i].holder == peer:
			return i
	return -1


func all_installed() -> bool:
	for p in parts:
		if p.state != PS.INSTALLED:
			return false
	return not parts.is_empty()


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return my_id() if id == 0 else id


## Run a method here and on every connected peer.
func _bcast(method: StringName, args: Array = []) -> void:
	callv(method, args)
	if not multiplayer.get_peers().is_empty():
		callv("rpc", [method] + args)


## Ask the host to run a method (runs directly if we are the host).
func _to_host(method: StringName, args: Array = []) -> void:
	if is_host():
		callv(method, args)
	else:
		callv("rpc_id", [1, method] + args)


func _set_phase(p: int) -> void:
	phase = p
	phase_changed.emit()


func _toast_all(text: String) -> void:
	_bcast("c_toast", [text])


func _layout(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	parts.clear()
	fatigue.clear()
	out_left.clear()
	build_damage = 0.0
	var used: Array[Vector3] = []
	for i in PART_NAMES.size():
		var pos := Vector3.ZERO
		for _try in 40:
			var ang := rng.randf() * TAU
			var rad := rng.randf_range(14.0, 34.0)
			pos = Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
			var ok := true
			for u in used:
				if u.distance_to(pos) < 10.0:
					ok = false
			if ok:
				break
		used.append(pos)
		parts.append({"name": PART_NAMES[i], "state": PS.WORLD, "holder": 0, "pos": pos, "yaw": 0.0, "q": 0.0, "loose_t": 0.0, "warned": false})
	coolers.clear()
	for i in 3:
		var ang2 := rng.randf() * TAU
		var rad2 := rng.randf_range(10.0, 30.0)
		coolers.append(Vector3(cos(ang2) * rad2, 0.0, sin(ang2) * rad2))


# --- Lobby -------------------------------------------------------------------

func start_hosting() -> void:
	names = {1: Net.player_name}
	role_owner = {}
	_set_phase(Phase.LOBBY)
	roster_changed.emit()


func on_joined() -> void:
	_to_host("s_hello", [Net.player_name])


func go_menu() -> void:
	names.clear()
	role_owner.clear()
	_set_phase(Phase.MENU)


@rpc("any_peer", "call_remote", "reliable")
func s_hello(player_name: String) -> void:
	if not is_host():
		return
	names[_sender()] = player_name.substr(0, 16)
	_send_roster()
	# Late joiners while a night is running just watch the lobby until it ends.
	if phase != Phase.LOBBY:
		rpc_id(_sender(), "c_lobby")


func claim_role(role: int) -> void:
	_to_host("s_claim_role", [role])


@rpc("any_peer", "call_remote", "reliable")
func s_claim_role(role: int) -> void:
	if not is_host() or phase != Phase.LOBBY:
		return
	var who := _sender()
	var cur: int = role_owner.get(role, -1)
	if cur == who:
		role_owner.erase(role)
	elif cur == -1:
		role_owner[role] = who
	_send_roster()


func _send_roster() -> void:
	_bcast("c_roster", [names, role_owner])


@rpc("authority", "call_remote", "reliable")
func c_roster(n: Dictionary, ro: Dictionary) -> void:
	names = n
	role_owner = ro
	if phase == Phase.MENU:
		_set_phase(Phase.LOBBY)
	roster_changed.emit()


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	names.erase(id)
	for r in role_owner.keys():
		if role_owner[r] == id:
			role_owner.erase(r)
	for i in parts.size():
		if parts[i].state == PS.CARRIED and parts[i].holder == id:
			parts[i].state = PS.WORLD
			parts[i].holder = 0
	_send_parts()
	_send_roster()


func _on_server_disconnected() -> void:
	Net.leave()
	go_menu()
	toast_msg.emit("Host left the game.")


# --- Starting a night ---------------------------------------------------------

func start_game() -> void:
	if not is_host() or names.is_empty():
		return
	# Unclaimed roles go round-robin to whoever is here (lets you test solo).
	var peers := names.keys()
	peers.sort()
	var k := 0
	for r in Roles.Id.values():
		if not role_owner.has(r):
			role_owner[r] = peers[k % peers.size()]
			k += 1
	_ready_peers.clear()
	_bcast("c_begin_scavenge", [randi(), role_owner])


@rpc("authority", "call_remote", "reliable")
func c_begin_scavenge(seed_value: int, ro: Dictionary) -> void:
	role_owner = ro
	world_seed = seed_value
	wanted = 0.0
	car_hp = 100.0
	engine_hot = false
	won = false
	_cop_open = false
	_phase_timer = 0.0
	_layout(seed_value)
	_set_phase(Phase.SCAVENGE)


func world_ready() -> void:
	_to_host("s_world_ready")


@rpc("any_peer", "call_remote", "reliable")
func s_world_ready() -> void:
	if not is_host():
		return
	_ready_peers[_sender()] = true
	for p in names:
		if not _ready_peers.has(p):
			return
	spawn_players.emit()


func return_to_lobby() -> void:
	if is_host():
		_bcast("c_lobby")


@rpc("authority", "call_remote", "reliable")
func c_lobby() -> void:
	_set_phase(Phase.LOBBY)
	roster_changed.emit()


# --- Scavenging: parts ----------------------------------------------------------

func request_pickup(i: int) -> void:
	_to_host("s_pickup", [i])


@rpc("any_peer", "call_remote", "reliable")
func s_pickup(i: int) -> void:
	if not is_host() or phase != Phase.SCAVENGE or i < 0 or i >= parts.size():
		return
	var who := _sender()
	if parts[i].state != PS.WORLD or carried_by(who) != -1 or is_out(who):
		return
	_tire(who, 0.1)
	parts[i].state = PS.CARRIED
	parts[i].holder = who
	_send_parts()


## The holder let go and the part has landed at pos; impact is how hard it hit (m/s).
func request_drop(pos: Vector3, yaw: float, impact: float) -> void:
	_to_host("s_drop", [pos, yaw, impact])


@rpc("any_peer", "call_remote", "reliable")
func s_drop(pos: Vector3, yaw: float, impact: float) -> void:
	if not is_host():
		return
	var who := _sender()
	var i := carried_by(who)
	if i == -1:
		return
	parts[i].state = PS.WORLD
	parts[i].holder = 0
	parts[i].pos = Vector3(clampf(pos.x, -50.0, 50.0), 0.0, clampf(pos.z, -50.0, 50.0))
	parts[i].yaw = yaw
	if impact > 3.0:
		_add_wanted((impact - 3.0) * 2.0)
		_toast_all("Clang! %s dropped the %s." % [names.get(who, "?"), parts[i].name])
	_send_parts()


## While held, the holder streams where the part is so everyone sees it move.
func send_pose(i: int, pos: Vector3, yaw: float) -> void:
	_to_host("s_pose", [i, pos, yaw])


@rpc("any_peer", "call_remote", "unreliable")
func s_pose(i: int, pos: Vector3, yaw: float) -> void:
	if not is_host() or i < 0 or i >= parts.size():
		return
	if parts[i].state != PS.CARRIED or parts[i].holder != _sender():
		return
	parts[i].pos = pos
	parts[i].yaw = yaw
	if not multiplayer.get_peers().is_empty():
		rpc("c_pose", i, pos, yaw)


@rpc("authority", "call_remote", "unreliable")
func c_pose(i: int, pos: Vector3, yaw: float) -> void:
	if i >= 0 and i < parts.size() and parts[i].holder != my_id():
		parts[i].pos = pos
		parts[i].yaw = yaw


## q is how well the held part lined up with its slot (0..1), judged by the placing client.
func request_place(q: float) -> void:
	_to_host("s_place", [q])


@rpc("any_peer", "call_remote", "reliable")
func s_place(q: float) -> void:
	if not is_host() or phase != Phase.SCAVENGE:
		return
	var who := _sender()
	var i := carried_by(who)
	if i == -1 or is_out(who):
		return
	_tire(who, 0.1)
	q = clampf(q, 0.0, 1.0)
	var p: Dictionary = parts[i]
	p.state = PS.INSTALLED
	p.holder = 0
	p.q = q
	p.warned = false
	p.loose_t = randf_range(10.0, 22.0) * (0.4 + q) if q < SOLID_Q else 0.0
	var dmg := (1.0 - q) * 18.0
	build_damage += dmg
	_add_wanted((1.0 - q) * 10.0)
	if q >= 0.9:
		_toast_all("%s fitted perfectly!" % p.name)
	elif q >= SOLID_Q:
		_toast_all("%s fitted. Good enough." % p.name)
	else:
		_toast_all("%s jammed in crooked. That will not hold." % p.name)
	if all_installed():
		_phase_timer = 3.0
	_send_parts()


func request_rest() -> void:
	_to_host("s_rest")


@rpc("any_peer", "call_remote", "reliable")
func s_rest() -> void:
	if not is_host():
		return
	var who := _sender()
	if not is_out(who):
		fatigue[who] = maxf(0.0, fatigue_of(who) - 0.4)


## Hauling parts wears out everyone except the Mechanic.
func _tire(who: int, amount: float) -> void:
	if has_role_for(who, Roles.Id.MECHANIC) or is_out(who):
		return
	fatigue[who] = fatigue_of(who) + amount
	if fatigue[who] >= 1.0:
		out_left[who] = PASSOUT_SECS
		_toast_all("%s passed out from hauling parts. That is the Mechanic's job!" % names.get(who, "?"))
		var i := carried_by(who)
		if i != -1:
			var ang := randf() * TAU
			parts[i].pos = CAR_POS + Vector3(cos(ang) * 4.0, 0.0, sin(ang) * 4.0)
			parts[i].state = PS.WORLD
			parts[i].holder = 0
			_send_parts()


func _tick_fatigue(delta: float) -> void:
	for who in names.keys():
		if is_out(who):
			out_left[who] = maxf(0.0, out_left[who] - delta)
			if out_left[who] <= 0.0:
				fatigue[who] = 0.4
				_toast_all("%s woke up. Mouth tastes like a battery." % names.get(who, "?"))
		elif carried_by(who) != -1:
			_tire(who, (0.01 + 0.003 * PART_MASS[carried_by(who)]) * delta)
		else:
			fatigue[who] = maxf(0.0, fatigue_of(who) - 0.03 * delta)
	_fat_sync -= delta
	if _fat_sync <= 0.0:
		_fat_sync = 0.25
		_bcast("c_fatigue", [fatigue, out_left])


@rpc("authority", "call_remote", "unreliable")
func c_fatigue(f: Dictionary, o: Dictionary) -> void:
	fatigue = f
	out_left = o


## Badly fitted parts rattle, then fall off.
func _tick_loose(delta: float) -> void:
	for i in parts.size():
		var p: Dictionary = parts[i]
		if p.state != PS.INSTALLED or p.loose_t <= 0.0:
			continue
		p.loose_t -= delta
		if p.loose_t <= 3.0 and not p.warned:
			p.warned = true
			_toast_all("Something is rattling on the car...")
			_send_parts()
		if p.loose_t <= 0.0:
			p.loose_t = 0.0
			_part_falls_off(i)


func _part_falls_off(i: int) -> void:
	var p: Dictionary = parts[i]
	_toast_all("The %s fell off the car!" % p.name)
	if phase == Phase.SCAVENGE:
		var ang := randf() * TAU
		p.pos = CAR_POS + Vector3(cos(ang) * 4.0, 0.0, sin(ang) * 4.0)
		p.state = PS.WORLD
		p.q = 0.0
		_add_wanted(4.0)
	else:
		# On the road there is no going back for it.
		p.q = SOLID_Q
		car_hp -= 12.0
		_add_wanted(8.0)
	p.warned = false
	_send_parts()


func _send_parts() -> void:
	var states := []
	for p in parts:
		states.append([p.state, p.holder, p.q, p.warned, p.pos, p.yaw])
	_bcast("c_parts", [states])


@rpc("authority", "call_remote", "reliable")
func c_parts(states: Array) -> void:
	for i in mini(states.size(), parts.size()):
		parts[i].state = states[i][0]
		parts[i].holder = states[i][1]
		parts[i].q = states[i][2]
		parts[i].warned = states[i][3]
		parts[i].pos = states[i][4]
		parts[i].yaw = states[i][5]
	parts_changed.emit()


func _drunk_of(peer: int) -> float:
	var best := 0.0
	for r in roles_of(peer):
		best = maxf(best, Roles.role_drunk(r))
	return best if best > 0.0 else 0.9


# --- Stats -------------------------------------------------------------------

func _add_wanted(v: float) -> void:
	wanted = clampf(wanted + v, 0.0, WANTED_MAX)


@rpc("authority", "call_remote", "unreliable")
func c_stats(w: float, hp: float, hot: bool) -> void:
	wanted = w
	car_hp = hp
	engine_hot = hot
	stats_changed.emit()


@rpc("authority", "call_remote", "reliable")
func c_toast(text: String) -> void:
	toast_msg.emit(text)


# --- Driving ---------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func c_begin_drive(seed_value: int) -> void:
	drive_seed = seed_value
	_set_phase(Phase.DRIVE)
	drive_started.emit(seed_value)


func send_car_state(pos: Vector3, yaw: float, speed: float) -> void:
	if not multiplayer.get_peers().is_empty():
		rpc("c_car_state", pos, yaw, speed)


@rpc("any_peer", "call_remote", "unreliable")
func c_car_state(pos: Vector3, yaw: float, speed: float) -> void:
	car_state.emit(pos, yaw, speed)


func request_car_damage(dmg: float, wanted_add: float) -> void:
	_to_host("s_car_damage", [dmg, wanted_add])


@rpc("any_peer", "call_remote", "reliable")
func s_car_damage(dmg: float, wanted_add: float) -> void:
	if not is_host() or phase != Phase.DRIVE or not has_role_for(_sender(), Roles.Id.DRIVER):
		return
	car_hp -= clampf(dmg, 0.0, 30.0)
	_add_wanted(clampf(wanted_add, 0.0, 30.0))


func request_cool(ok: bool) -> void:
	_to_host("s_cool", [ok])


@rpc("any_peer", "call_remote", "reliable")
func s_cool(ok: bool) -> void:
	if not is_host() or phase != Phase.DRIVE or not engine_hot:
		return
	if not has_role_for(_sender(), Roles.Id.MECHANIC):
		return
	if ok:
		engine_hot = false
		_hot_timer = randf_range(25.0, 40.0)
		_toast_all("Engine cooled. Mechanic is a legend.")
	else:
		car_hp -= 5.0


func request_cop_result(ok: bool) -> void:
	_to_host("s_cop_result", [ok])


@rpc("any_peer", "call_remote", "reliable")
func s_cop_result(ok: bool) -> void:
	if not is_host() or phase != Phase.DRIVE or not _cop_open:
		return
	if not has_role_for(_sender(), Roles.Id.LOOKOUT):
		return
	_cop_open = false
	_cop_timer = randf_range(20.0, 30.0)
	if ok:
		_add_wanted(-8.0)
		_toast_all("The Lookout got everyone ducked. Cops drive past.")
	else:
		_add_wanted(10.0)
		_toast_all("The Lookout wobbled. The cops noticed.")


func request_arrived() -> void:
	_to_host("s_arrived")


@rpc("any_peer", "call_remote", "reliable")
func s_arrived() -> void:
	if not is_host() or phase != Phase.DRIVE or not has_role_for(_sender(), Roles.Id.DRIVER):
		return
	_finish(true, "Home sweet home! Everybody into bed.")


func _finish(win: bool, text: String) -> void:
	_bcast("c_result", [win, text])


@rpc("authority", "call_remote", "reliable")
func c_result(win: bool, text: String) -> void:
	won = win
	result_text = text
	_set_phase(Phase.RESULT)


# --- Host tick ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_host():
		return
	match phase:
		Phase.SCAVENGE:
			wanted = maxf(0.0, wanted - 0.6 * delta)
			_tick_loose(delta)
			_tick_fatigue(delta)
			if _phase_timer > 0.0:
				_phase_timer -= delta
				if _phase_timer <= 0.0 and all_installed():
					_start_drive()
			if wanted >= WANTED_MAX:
				_finish(false, "Busted! The guard caught you at the junkyard.")
		Phase.DRIVE:
			_tick_drive(delta)
		_:
			return
	_stat_timer -= delta
	if _stat_timer <= 0.0:
		_stat_timer = 0.25
		if not multiplayer.get_peers().is_empty():
			rpc("c_stats", wanted, car_hp, engine_hot)
		stats_changed.emit()


func _start_drive() -> void:
	wanted = maxf(0.0, wanted * 0.5)
	car_hp = maxf(40.0, 100.0 - build_damage)
	engine_hot = false
	_hot_timer = randf_range(18.0, 28.0)
	_cop_timer = randf_range(14.0, 20.0)
	_cop_open = false
	_bcast("c_begin_drive", [randi()])


func _tick_drive(delta: float) -> void:
	_tick_loose(delta)
	if engine_hot:
		car_hp -= 1.5 * delta
	else:
		_hot_timer -= delta
		if _hot_timer <= 0.0:
			engine_hot = true
			_toast_all("The engine is overheating!")
	if _cop_open:
		_cop_left -= delta
		if _cop_left <= 0.0:
			_cop_open = false
			_cop_timer = randf_range(20.0, 30.0)
			_add_wanted(25.0)
			_toast_all("The cops clocked you!")
	else:
		wanted = maxf(0.0, wanted - 0.3 * delta)
		_cop_timer -= delta
		if _cop_timer <= 0.0:
			_cop_open = true
			_cop_left = 7.0
			var side := "LEFT" if randf() < 0.5 else "RIGHT"
			_bcast("c_cop_warning", [side, _cop_left])
	if wanted >= WANTED_MAX:
		_finish(false, "Arrested! The whole crew spends the night in a cell.")
	elif car_hp <= 0.0:
		_finish(false, "The car gave up. You walk home. It takes until Thursday.")


@rpc("authority", "call_remote", "reliable")
func c_cop_warning(side: String, seconds: float) -> void:
	cop_warning.emit(side, seconds)

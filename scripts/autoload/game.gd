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
enum PS { WORLD, CARRIED, DELIVERED, INSTALLED }

const PART_NAMES := ["Battery", "Fuel Pump", "Spark Plugs", "Spare Tyre"]
const WANTED_MAX := 100.0
const CAR_POS := Vector3.ZERO

var phase: int = Phase.MENU
var names: Dictionary = {}        # peer_id -> display name
var role_owner: Dictionary = {}   # Roles.Id -> peer_id
var world_seed := 0
var drive_seed := 0
var parts: Array = []             # [{name, state, holder, pos}]
var coolers: Array = []           # water cooler positions
var wanted := 0.0
var car_hp := 100.0
var engine_hot := false
var won := false
var result_text := ""

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
		"act": [KEY_E], "drop": [KEY_Q],
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


func carried_by(peer: int) -> int:
	for i in parts.size():
		if parts[i].state == PS.CARRIED and parts[i].holder == peer:
			return i
	return -1


func delivered_part() -> int:
	for i in parts.size():
		if parts[i].state == PS.DELIVERED:
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
		parts.append({"name": PART_NAMES[i], "state": PS.WORLD, "holder": 0, "pos": pos})
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
	if parts[i].state != PS.WORLD or carried_by(who) != -1:
		return
	var fumble := 0.25 + 0.5 * _drunk_of(who)
	if has_role_for(who, Roles.Id.DRIVER):
		fumble -= 0.2
	if randf() < fumble:
		_add_wanted(3.0)
		_toast_all("%s fumbled the %s!" % [names.get(who, "?"), parts[i].name])
		return
	parts[i].state = PS.CARRIED
	parts[i].holder = who
	_send_parts()


func request_drop() -> void:
	_to_host("s_drop")


@rpc("any_peer", "call_remote", "reliable")
func s_drop() -> void:
	if not is_host():
		return
	var who := _sender()
	var i := carried_by(who)
	if i == -1:
		return
	parts[i].state = PS.WORLD
	parts[i].holder = 0
	_add_wanted(6.0)
	_toast_all("Clang! %s dropped the %s." % [names.get(who, "?"), parts[i].name])
	_send_parts()


func request_deliver() -> void:
	_to_host("s_deliver")


@rpc("any_peer", "call_remote", "reliable")
func s_deliver() -> void:
	if not is_host() or phase != Phase.SCAVENGE:
		return
	var who := _sender()
	var i := carried_by(who)
	if i == -1:
		return
	parts[i].state = PS.DELIVERED
	parts[i].holder = 0
	_send_parts()
	_toast_all("%s delivered the %s to the car." % [names.get(who, "?"), parts[i].name])


func request_install(i: int, ok: bool) -> void:
	_to_host("s_install", [i, ok])


@rpc("any_peer", "call_remote", "reliable")
func s_install(i: int, ok: bool) -> void:
	if not is_host() or phase != Phase.SCAVENGE or i < 0 or i >= parts.size():
		return
	if not has_role_for(_sender(), Roles.Id.MECHANIC) or parts[i].state != PS.DELIVERED:
		return
	if ok:
		parts[i].state = PS.INSTALLED
		_toast_all("%s fitted!" % parts[i].name)
		if all_installed():
			_phase_timer = 3.0
	else:
		_add_wanted(8.0)
		_toast_all("The Mechanic fumbled the %s. Bang!" % parts[i].name)
	_send_parts()


func _send_parts() -> void:
	var states := []
	for p in parts:
		states.append([p.state, p.holder])
	_bcast("c_parts", [states])


@rpc("authority", "call_remote", "reliable")
func c_parts(states: Array) -> void:
	for i in mini(states.size(), parts.size()):
		parts[i].state = states[i][0]
		parts[i].holder = states[i][1]
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
	car_hp = 100.0
	engine_hot = false
	_hot_timer = randf_range(18.0, 28.0)
	_cop_timer = randf_range(14.0, 20.0)
	_cop_open = false
	_bcast("c_begin_drive", [randi()])


func _tick_drive(delta: float) -> void:
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

class_name Casino
extends Node3D
## The pub casino (the hand-made scene) with its four tables wired to the shared pool.
## A player walks up, presses [E], places a stake (taken from the crew's money by the host),
## plays the game on their own screen, and the winnings are paid back against that stake.
## Everyone else carries on with their own thing, which is the point.

signal session_ended

## The building footprint around its own origin, used to keep junk out of it.
const HALF_X := 33.0
const HALF_Z := 15.0
const SCENE := preload("res://scenes/pub_casino.tscn")
const DartsBetting := preload("res://scripts/ui/darts_betting_dialog.gd")
const RouletteBetting := preload("res://scripts/ui/roulette_betting_dialog.gd")
const Darts3D := preload("res://scripts/minigames/darts_3d_game.gd")
const CupPong := preload("res://scripts/minigames/cup_pong_game.gd")
const Slots := preload("res://scripts/minigames/slots_game.gd")

## Where each table stands, relative to the casino origin.
const TABLES := {
	"darts": {"pos": Vector3(13.8, 0.8, -10.8), "prompt": "[E] Darts with Barney: bet the crew's money", "color": Color(0.95, 0.25, 0.25)},
	"cup_pong": {"pos": Vector3(-6.0, 0.8, 6.0), "prompt": "[E] Cup pong: sink 2 cups to double your stake", "color": Color(0.95, 0.75, 0.2)},
	"slots": {"pos": Vector3(-18.0, 0.8, 0.0), "prompt": "[E] Slots: pairs pay half back, triples pay 4x", "color": Color(0.3, 0.85, 0.95)},
	"roulette": {"pos": Vector3(18.0, 0.8, -2.0), "prompt": "[E] Roulette with Antoine: bet the crew's money", "color": Color(0.85, 0.2, 0.25)},
}
const CUP_PONG_MULT := 2.0
const SLOTS_PAIR_MULT := 0.5
const SLOTS_TRIPLE_MULT := 4.0

var tables: Dictionary = {}    # kind -> Interactable
var busy := false              # you play one game at a time


func _ready() -> void:
	add_child(SCENE.instantiate())
	_drop_shadows(self)
	for kind in TABLES:
		var t: Dictionary = TABLES[kind]
		var it := Interactable.new()
		it.name = "Table_" + kind
		it.position = t.pos
		it.prompt = t.prompt
		it.range_m = 3.4
		add_child(it)
		var glow := OmniLight3D.new()
		glow.light_color = t.color
		glow.light_energy = 1.4
		glow.omni_range = 3.5
		glow.position.y = 0.5
		it.add_child(glow)
		it.activated.connect(_on_table.bind(kind))
		tables[kind] = it


## The building carries a dozen shadow-casting spotlights. Together with the city that overflows
## the renderer's shadow atlas and the lights flicker, so they all light without casting shadows.
func _drop_shadows(n: Node) -> void:
	if n is Light3D:
		(n as Light3D).shadow_enabled = false
	for c in n.get_children():
		_drop_shadows(c)


## Is this point (world space) inside the building, with a margin?
static func covers(origin: Vector3, p: Vector3, margin := 4.0) -> bool:
	return absf(p.x - origin.x) <= HALF_X + margin and absf(p.z - origin.z) <= HALF_Z + margin


func _on_table(player: Node3D, kind: String) -> void:
	var me := player as Player
	if me == null or busy or me.ui_lock:
		return
	if Game.money <= 0:
		Game.toast_msg.emit("The pool is empty. Go and earn something first.")
		return
	if kind == "roulette":
		var table := _roulette_table()
		if table != null and table.get("is_spinning"):
			Game.toast_msg.emit("The wheel is still spinning. Watch the ball settle.")
			return
	busy = true
	me.ui_lock = true
	match kind:
		"darts":
			_ask(me, DartsBetting.new(Game.money), kind, _start_darts)
		"roulette":
			_ask(me, RouletteBetting.new(Game.money), kind, _start_roulette)
		"cup_pong":
			_ask(me, SimpleBetDialog.new("CUP PONG", "Sink 2 cups out of 4 balls and the stake doubles.", Game.money), kind, _start_cup_pong)
		"slots":
			_ask(me, SimpleBetDialog.new("SLOTS", "Stop the reels. A pair gives half your stake back, three of a kind pays 4x.", Game.money), kind, _start_slots)


## Show the bet screen; once the host has taken the stake, call go(me, bet, extra, extra).
func _ask(me: Player, dlg: Control, kind: String, go: Callable) -> void:
	var layer: Node = me.get_node_or_null("HUD")
	(layer if layer != null else me).add_child(dlg)
	dlg.cancelled.connect(func(): _finish(me))
	dlg.bet_confirmed.connect(func(bet: int, a: Variant = null, b: Variant = null):
		dlg.queue_free()
		_stake(me, kind, bet, a, b, go))


func _stake(me: Player, kind: String, bet: int, a: Variant, b: Variant, go: Callable) -> void:
	me.casino_kind = kind
	# The host answers at once when it is us, so listen before asking.
	var got := {"done": false, "ok": false}
	var on_result := func(k: String, ok: bool, _b: int):
		if k == kind:
			got.done = true
			got.ok = ok
	Game.stake_result.connect(on_result)
	Game.request_stake(kind, bet)
	var frames := 0
	while not got.done and frames < 600:
		await get_tree().process_frame
		frames += 1
	Game.stake_result.disconnect(on_result)
	if not got.ok:
		Game.toast_msg.emit("The pool cannot cover that bet.")
		_finish(me)
		return
	go.call(me, bet, a, b)


func _finish(me: Player) -> void:
	if is_instance_valid(me):
		me.ui_lock = false
		me.casino_kind = ""
		me.is_mouse_unlocked = false
	busy = false
	session_ended.emit()


# --- The games ---------------------------------------------------------------------------

func _start_darts(me: Player, bet: int, _a: Variant, _b: Variant) -> void:
	var session: Node = Darts3D.new()
	me.add_child(session)
	session.start_darts_session(me, find_child("DartBoard3D", true, false), find_child("NPC_Barney", true, false), bet)
	session.finished.connect(func(_won: bool, _payout: int): _finish(me))


func _roulette_table() -> Node3D:
	return find_child("RouletteTable3D", true, false) as Node3D


func _start_roulette(me: Player, bet: int, bet_type: Variant, param: Variant) -> void:
	var table := _roulette_table()
	if table == null:
		Game.request_payout("roulette", bet)    # no wheel to spin: give the stake back
		_finish(me)
		return
	# The ball keeps rolling in the world; you are free to walk around while it settles.
	me.ui_lock = false
	me.is_mouse_unlocked = false
	table.spin_finished.connect(func(_won, _n, _c, _p): _finish(me), CONNECT_ONE_SHOT)
	table.start_spin(me, bet, str(bet_type), param)


func _start_cup_pong(me: Player, bet: int, _a: Variant, _b: Variant) -> void:
	var mg: Control = CupPong.new()
	_show_game(me, mg)
	mg.finished.connect(func(won: bool):
		if won:
			Game.request_payout("cup_pong", int(bet * CUP_PONG_MULT))
		_finish(me))


func _start_slots(me: Player, bet: int, _a: Variant, _b: Variant) -> void:
	var mg: Control = Slots.new()
	_show_game(me, mg)
	mg.finished.connect(func(won: bool):
		if won:
			var r: Array = mg.reel_states
			var triple: bool = r[0] == r[1] and r[1] == r[2]
			Game.request_payout("slots", int(bet * (SLOTS_TRIPLE_MULT if triple else SLOTS_PAIR_MULT)))
		_finish(me))


func _show_game(me: Player, mg: Control) -> void:
	var layer: Node = me.get_node_or_null("HUD")
	(layer if layer != null else me).add_child(mg)
	var vp := get_viewport().get_visible_rect().size
	mg.position = (vp - mg.size) * 0.5

extends Node
## Connection layer. Online play goes through Epic Online Services (EOS):
## a lobby holds the room code, EOSGMultiplayerPeer carries the game traffic.
## A plain ENet backend exists for local testing.

signal status_changed(text: String)
signal hosted(code: String)
signal host_failed(reason: String)
signal join_failed(reason: String)
signal joined

const SOCKET := "stumble"
const BUCKET := "stumble_home"
const CODE_PREFIX := "SH"
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LEN := 5
const ENET_PORT := 7777
const MAX_PLAYERS := 4
const CREDENTIALS_PATH := "res://eos_credentials.cfg"

var player_name := "Drunk%d" % (randi() % 900 + 100)
var room_code := ""
var lobby: HLobby

var _eos_ready := false


func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): joined.emit())
	multiplayer.connection_failed.connect(func(): join_failed.emit("Could not reach the host."))


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


# --- EOS -------------------------------------------------------------------

func init_eos() -> bool:
	if _eos_ready:
		return true
	var cfg := ConfigFile.new()
	if cfg.load(CREDENTIALS_PATH) != OK:
		status_changed.emit("Missing eos_credentials.cfg")
		return false
	var c := HCredentials.new()
	c.product_name = cfg.get_value("eos", "product_name", "Stumble Home")
	c.product_version = "0.1"
	c.product_id = cfg.get_value("eos", "product_id", "")
	c.sandbox_id = cfg.get_value("eos", "sandbox_id", "")
	c.deployment_id = cfg.get_value("eos", "deployment_id", "")
	c.client_id = cfg.get_value("eos", "client_id", "")
	c.client_secret = cfg.get_value("eos", "client_secret", "")
	status_changed.emit("Connecting to Epic Online Services...")
	if not await HPlatform.setup_eos_async(c):
		status_changed.emit("EOS setup failed (check the log).")
		return false
	status_changed.emit("Signing in...")
	if not await HAuth.login_anonymous_async(player_name):
		status_changed.emit("EOS sign-in failed.")
		return false
	_eos_ready = true
	return true


func host_eos() -> void:
	if not await init_eos():
		host_failed.emit("Could not connect to EOS.")
		return
	status_changed.emit("Creating room...")
	for attempt in 6:
		var code := _make_code()
		for voice in [true, false]:
			var o := EOS.Lobby.CreateLobbyOptions.new()
			o.lobby_id = CODE_PREFIX + code
			o.bucket_id = BUCKET
			o.max_lobby_members = MAX_PLAYERS
			o.permission_level = EOS.Lobby.LobbyPermissionLevel.InviteOnly
			o.presence_enabled = false
			o.enable_join_by_id = true
			o.allow_invites = false
			o.disable_host_migration = true
			o.enable_rtc_room = voice
			lobby = await HLobbies.create_lobby_async(o)
			if lobby:
				break
		if lobby:
			room_code = code
			break
	if not lobby:
		host_failed.emit("Could not create a room.")
		return
	var peer := EOSGMultiplayerPeer.new()
	var err = peer.create_server(SOCKET)
	if err != OK:
		host_failed.emit("Could not open the P2P socket (%s)." % err)
		return
	multiplayer.multiplayer_peer = peer
	hosted.emit(room_code)


func join_eos(code: String) -> void:
	code = code.strip_edges().to_upper()
	if code.length() != CODE_LEN:
		join_failed.emit("Room codes are %d characters." % CODE_LEN)
		return
	if not await init_eos():
		join_failed.emit("Could not connect to EOS.")
		return
	status_changed.emit("Looking for room %s..." % code)
	lobby = await HLobbies.join_by_id_async(CODE_PREFIX + code)
	if not lobby:
		join_failed.emit("No room with that code.")
		return
	room_code = code
	var peer := EOSGMultiplayerPeer.new()
	var err = peer.create_client(SOCKET, lobby.owner_product_user_id)
	if err != OK:
		join_failed.emit("Could not connect to the host (%s)." % err)
		return
	multiplayer.multiplayer_peer = peer
	status_changed.emit("Connecting to host...")


# --- ENet (local testing) --------------------------------------------------

func host_enet() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(ENET_PORT, MAX_PLAYERS)
	if err != OK:
		host_failed.emit("Could not host on port %d (%s)." % [ENET_PORT, err])
		return
	multiplayer.multiplayer_peer = peer
	room_code = "LAN"
	hosted.emit(room_code)


func join_enet(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip.strip_edges(), ENET_PORT)
	if err != OK:
		join_failed.emit("Could not connect (%s)." % err)
		return
	multiplayer.multiplayer_peer = peer


# --- Shared ------------------------------------------------------------------

func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if lobby:
		if lobby.is_owner():
			lobby.destroy_async()
		else:
			lobby.leave_async()
		lobby = null
	room_code = ""


func _make_code() -> String:
	var s := ""
	for i in CODE_LEN:
		s += CODE_CHARS[randi() % CODE_CHARS.length()]
	return s

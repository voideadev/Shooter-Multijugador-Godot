class_name Ffa
extends Node3D

const APP_ID := "desertstrike-ffa"
const MAX_PLAYERS := 4
const JOIN_TIMEOUT := 10.0
const KILL_LIMIT := 15
const TEAM_KILL_LIMIT := 25
const RESPAWN_TIME := 3.0
const PROTECT_TIME := 2.5
const INTERMISSION := 8.0
const STATE_DT := 0.033
const BOT_DT := 0.033
const MENU_SCENE := "res://menu.tscn"

static var pending_message := ""
static var entry := "solo"

var mode := ""
var cfg: Dictionary = {}
var game_mode := "ffa"
var team_count := 0
var bot_diff := 1
var my_team := -1
var local_fid := 1
var my_name := "Jugador"
var map_idx := 0
var bot_count := 0
var world_ready := false
var intermission := false
var inter_t := 0.0
var respawn_t := 0.0
var protect_t := 0.0
var joining := false
var join_token := 0
var private_game := false
var private_code := ""
var game_name := ""

var map: MapBase
var controls: Controls
var hud: FfaHud
var player: Player
var link: NetLink
var lan: NetLan
var lobby: FfaMenu
var lobby_layer: CanvasLayer
var pause: PauseMenu

var bots := {}
var remotes := {}
var infos := {}
var teams := {}
var picker: TeamPicker
var scores := {}

var _state_t := 0.0
var _bot_t := 0.0
var _rows_t := 0.0


func _ready() -> void:
	_setup_input()
	Loadout.ensure_loaded()
	my_name = Loadout.display_name()

	link = $Link
	lan = $Lan
	lan.app_id = APP_ID
	lobby_layer = $LobbyLayer
	lobby = $LobbyLayer/Lobby
	lobby.solo_confirmed.connect(_on_solo)
	lobby.waves_confirmed.connect(_on_waves)
	lobby.host_confirmed.connect(_on_host)
	lobby.join_requested.connect(_on_join)
	lobby.join_opened.connect(lan.start_listening)
	lobby.join_closed.connect(lan.stop_listening)
	lobby.back_pressed.connect(_back_to_menu)
	lan.games_changed.connect(lobby.set_games)
	lan.listen_failed.connect(func(): lobby.show_message("No se pudo buscar partidas en esta red"))

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	lobby.open_start(entry)
	if pending_message != "":
		lobby.show_message(pending_message)
		pending_message = ""


func _device_name() -> String:
	var n := OS.get_model_name()
	if n == "" or n == "GenericDevice":
		return "Jugador"
	return n


func _is_net() -> bool:
	return (mode == "host" or mode == "client") and multiplayer.get_peers().size() > 0


func _is_authority() -> bool:
	return mode == "solo" or mode == "host"


func _on_solo(c: Dictionary) -> void:
	mode = "solo"
	local_fid = 1
	_start_world(c, true)


func _on_waves(map_index: int) -> void:
	Maps.current = map_index
	_teardown()
	get_tree().change_scene_to_file("res://main.tscn")


func _mode_text(c: Dictionary) -> String:
	var d := String(Bot.LEVELS[int(c.get("diff", 1))]["name"]).capitalize()
	if String(c.get("mode", "ffa")) == "teams":
		return "%d equipos · bots %s" % [int(c.get("teams", 2)), d]
	return "Todos contra todos · bots %s" % d


func _bots_total(c: Dictionary) -> int:
	var n := 0
	for v in c.get("bots", []):
		n += int(v)
	return n


func _on_host(c: Dictionary, is_private: bool, code: String, p_name: String) -> void:
	private_game = is_private
	private_code = code
	game_name = p_name if p_name != "" else "Partida de " + my_name
	if link.host(MAX_PLAYERS - 1) != OK:
		lobby.show_message("No se pudo crear la partida")
		return
	mode = "host"
	local_fid = 1
	lan.start_advertising({"name": game_name, "priv": private_game, "port": link.port, "code": private_code,
		"n": 1, "max": MAX_PLAYERS, "map": String(Maps.LIST[int(c["map"])]["name"]), "bots": _bots_total(c), "mode": _mode_text(c)})
	_start_world(c, true)


func _on_join(entry: Dictionary, code: String) -> void:
	var p: int = lan.resolve(entry, code)
	if p <= 0:
		lobby.show_code_error("Código incorrecto")
		return
	lan.stop_listening()
	_start_join(String(entry.get("ip", "")), p)


func _start_join(ip: String, p: int) -> void:
	if link.join(ip, p) != OK:
		_join_failed("No se pudo conectar a la partida")
		return
	joining = true
	join_token += 1
	var token := join_token
	lobby.show_message("Conectando...")
	get_tree().create_timer(JOIN_TIMEOUT).timeout.connect(func():
		if token == join_token and joining:
			joining = false
			link.leave()
			_join_failed("No se pudo conectar a la partida"))


func _join_failed(text: String) -> void:
	lobby.show_message(text)
	lobby.show_join()


func _on_connected_to_server() -> void:
	joining = false
	mode = "client"
	local_fid = multiplayer.get_unique_id()
	lobby.show_message("Entrando en la partida...")


func _on_connection_failed() -> void:
	if not joining:
		return
	joining = false
	link.leave()
	_join_failed("No se pudo conectar a la partida")


func _on_server_disconnected() -> void:
	if mode == "client":
		_back_to_lobby("El anfitrión cerró la partida")


func _on_peer_connected(id: int) -> void:
	if mode == "host" and world_ready:
		rpc_id(id, "net_welcome", cfg, scores, intermission, teams)
		rpc_id(id, "net_barrels", map.exploded_keys())
		lan.set_count(multiplayer.get_peers().size() + 1)
	if world_ready:
		rpc_id(id, "net_info", my_name, Loadout.suit, Loadout.character)
		if game_mode == "teams" and my_team >= 0:
			rpc_id(id, "net_set_team", my_team)


func _on_peer_disconnected(id: int) -> void:
	var nm := _name_of(id)
	if remotes.has(id):
		(remotes[id] as Node).queue_free()
		remotes.erase(id)
	infos.erase(id)
	teams.erase(id)
	if mode == "host":
		scores.erase(id)
		_broadcast_scores()
		_broadcast_feed("%s se ha desconectado" % nm)
		lan.set_count(multiplayer.get_peers().size() + 1)


func _on_arsenal_changed() -> void:
	if player != null and is_instance_valid(player):
		player.apply_loadout()


func _back_to_menu() -> void:
	get_tree().paused = false
	MainMenu.start_panel = "play" if entry == "solo" else "multi"
	_teardown()
	get_tree().change_scene_to_file(MENU_SCENE)


func _back_to_lobby(msg: String) -> void:
	pending_message = msg
	_teardown()
	get_tree().reload_current_scene()


func _teardown() -> void:
	lan.stop_advertising()
	lan.stop_listening()
	link.leave()


@rpc("authority", "reliable")
func net_welcome(c: Dictionary, sc: Dictionary, inter: bool, tm: Dictionary) -> void:
	if world_ready:
		return
	teams = tm
	scores = sc
	intermission = inter
	_start_world(c, false)
	_on_scores_changed()
	rpc("net_info", my_name, Loadout.suit, Loadout.character)


@rpc("any_peer", "reliable")
func net_set_team(t: int) -> void:
	var fid := multiplayer.get_remote_sender_id()
	teams[fid] = t
	if remotes.has(fid):
		(remotes[fid] as RemoteFighter).set_team(t)
	if mode == "host" and world_ready and scores.has(fid):
		_broadcast_feed("%s se unió al equipo %s" % [String(scores[fid][0]), Teams.name_of(t)])
	_on_scores_changed()


@rpc("any_peer", "reliable")
func net_info(p_name: String, suit: int, character: int = 0) -> void:
	var fid := multiplayer.get_remote_sender_id()
	infos[fid] = {"name": p_name, "suit": suit, "character": character}
	if remotes.has(fid):
		(remotes[fid] as RemoteFighter).set_info(p_name, suit, character)
	if mode == "host" and world_ready:
		if not scores.has(fid):
			scores[fid] = [p_name, 0, 0]
			_broadcast_feed("%s se ha unido" % p_name)
		else:
			scores[fid][0] = p_name
		_broadcast_scores()


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func net_state(s: Array) -> void:
	if not world_ready:
		return
	_get_remote(multiplayer.get_remote_sender_id()).apply_state(s)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func net_bot_states(arr: Array) -> void:
	if not world_ready:
		return
	for e in arr:
		var a: Array = e
		_get_remote(int(a[0])).apply_state(a.slice(1))


@rpc("any_peer", "unreliable")
func net_event(fid: int, kind: String, wid: String) -> void:
	if not world_ready or not remotes.has(fid):
		return
	(remotes[fid] as RemoteFighter).on_event(kind, wid)


@rpc("any_peer", "reliable")
func net_throw(_fid: int, wid: String, origin: Vector3, vel: Vector3) -> void:
	if not world_ready:
		return
	var t := Thrown.create()
	add_child(t)
	t.harmless = true
	t.setup(RemoteFighter.def_by_id(wid), origin, vel)


@rpc("any_peer", "reliable")
func net_damage(target: int, amount: float, attacker: int, impulse: Vector3 = Vector3.ZERO) -> void:
	_apply_damage(target, amount, attacker, impulse)


@rpc("any_peer", "reliable")
func net_died(victim: int, killer: int) -> void:
	if mode == "host":
		_host_death(victim, killer)


@rpc("authority", "reliable")
func net_scores(d: Dictionary) -> void:
	scores = d
	_on_scores_changed()


@rpc("authority", "reliable")
func net_feed(text: String) -> void:
	if hud != null:
		hud.add_feed(text)


@rpc("authority", "reliable")
func net_round_end(winner: int, team_win: int = -1) -> void:
	_apply_round_end(winner, team_win)


@rpc("any_peer", "reliable")
func net_barrel(key: String) -> void:
	if map != null:
		map.explode_barrel(key, false)


@rpc("authority", "reliable")
func net_barrels(keys: Array) -> void:
	if map != null:
		for k in keys:
			map.hide_barrel(String(k))


func _on_barrel_exploded(key: String) -> void:
	if _is_net():
		rpc("net_barrel", key)


@rpc("authority", "reliable")
func net_round_start() -> void:
	_apply_round_start()


func _start_world(c: Dictionary, authority: bool) -> void:
	if world_ready:
		return
	cfg = c
	map_idx = int(c["map"])
	game_mode = String(c["mode"])
	team_count = int(c["teams"])
	bot_diff = int(c["diff"])
	var counts: Array = c["bots"]
	bot_count = _bots_total(c)
	Maps.current = map_idx
	lobby_layer.visible = false
	map = Maps.create()
	add_child(map)
	Barrel.on_exploded = _on_barrel_exploded
	if authority and bot_count > 0:
		map.bake_navigation()
	map.spawn_health_pickups()
	_build_hud()
	Gfx.apply(self)
	world_ready = true
	if authority:
		scores[local_fid] = [my_name, 0, 0]
		if game_mode == "teams":
			my_team = clampi(int(c["my_team"]), 0, team_count - 1)
			teams[local_fid] = my_team
		_update_team_button()
		_spawn_local_player()
		var k := 0
		if game_mode == "teams":
			for t in team_count:
				for i in int(counts[t]):
					k += 1
					teams[-k] = t
					scores[-k] = ["BOT %d" % k, 0, 0]
					_spawn_bot(-k)
		else:
			for i in int(counts[0]):
				k += 1
				scores[-k] = ["BOT %d" % k, 0, 0]
				_spawn_bot(-k)
		_broadcast_scores()
	elif game_mode == "teams":
		my_team = -1
		_update_team_button()
		_open_team_picker(false)
	else:
		_spawn_local_player()


func _team_counts() -> Array:
	var out: Array = [0, 0, 0, 0]
	for fid in teams:
		var t: int = int(teams[fid])
		if t >= 0 and t < 4 and int(fid) != local_fid:
			out[t] += 1
	return out


func _open_team_picker(allow_cancel: bool) -> void:
	if picker == null or game_mode != "teams":
		return
	if controls != null:
		controls.reset_touch()
		controls.set_process_input(false)
	picker.open(team_count, _team_counts(), my_team, allow_cancel)


func _on_team_picked(t: int) -> void:
	if controls != null:
		controls.set_process_input(true)
	var first := player == null or not is_instance_valid(player)
	var changed := t != my_team
	my_team = t
	teams[local_fid] = t
	if _is_net():
		rpc("net_set_team", t)
	_update_team_button()
	_on_scores_changed()
	if first:
		_spawn_local_player()
	elif changed:
		_respawn_player()


func _on_team_cancelled() -> void:
	if controls != null:
		controls.set_process_input(true)


func _update_team_button() -> void:
	if controls == null:
		return
	controls.team_button = game_mode == "teams"
	controls.team_color = Teams.color(my_team)
	controls.team_label = ("EQUIPO: " + Teams.name_of(my_team)) if my_team >= 0 else "ELEGIR EQUIPO"


func team_of(fid: int) -> int:
	return int(teams.get(fid, -1)) if game_mode == "teams" else -1


func is_friendly(attacker: int, victim: int) -> bool:
	if game_mode != "teams" or attacker == 0 or attacker == victim:
		return false
	var ta := team_of(attacker)
	return ta >= 0 and ta == team_of(victim)


func _build_hud() -> void:
	var layer: CanvasLayer = $HudLayer
	controls = Controls.create()
	controls.show_wave = false
	layer.add_child(controls)
	hud = FfaHud.create()
	hud.kill_limit = KILL_LIMIT
	hud.team_limit = TEAM_KILL_LIMIT
	layer.add_child(hud)
	controls.team_pressed.connect(func(): _open_team_picker(true))
	pause = PauseMenu.create()
	pause.controls = controls
	pause.pause_tree = mode == "solo"
	add_child(pause)
	pause.exit_pressed.connect(_back_to_menu)
	pause.arsenal_changed.connect(_on_arsenal_changed)
	controls.menu_pressed.connect(pause.open)
	picker = TeamPicker.create()
	$PickerLayer.add_child(picker)
	picker.picked.connect(_on_team_picked)
	picker.cancelled.connect(_on_team_cancelled)


func _spawn_local_player() -> void:
	player = Player.create()
	player.controls = controls
	player.fid = local_fid
	player.net = self
	player.team = my_team if game_mode == "teams" else -1
	player.god = true
	protect_t = PROTECT_TIME
	var sp := _pick_spawn(player.team)
	player.position = sp
	var to_center := Vector3(-sp.x, 0.0, -sp.z)
	if to_center.length() > 0.5:
		to_center = to_center.normalized()
		player.yaw = atan2(-to_center.x, -to_center.z)
		player._cyaw = player.yaw
	add_child(player)
	player.reset_physics_interpolation()
	player.add_to_group("fighters")
	player.died.connect(_on_local_died)
	player.fired.connect(func(): _send_event("shot", String(player.weapon["id"])))
	player.melee_started.connect(func(id: String): _send_event("melee", id))
	player.throw_started.connect(func(id: String): _send_event("throw", id))
	player.threw.connect(_on_local_threw)
	controls.first_person = false
	controls.ads_on = false
	controls.crouch_on = false
	controls.prone_on = false
	controls.damage_flash = 0.0
	if not intermission:
		controls.message = ""
		controls.sub_message = ""


func _spawn_bot(fid: int) -> void:
	var b := Bot.create()
	b.fid = fid
	b.net = self
	b.team = team_of(fid)
	b.level = bot_diff
	b.position = _pick_spawn(b.team)
	add_child(b)
	b.reset_physics_interpolation()
	b.died.connect(_on_bot_died)
	bots[fid] = b


func _pick_spawn(team: int = -1) -> Vector3:
	var pts: Array = map.enemy_spawns.duplicate()
	pts.append(map.player_spawn)
	pts.shuffle()
	var fighters := get_tree().get_nodes_in_group("fighters")
	var best: Vector3 = pts[0]
	var best_d := -INF
	for p in pts:
		var md := 9999.0
		var occupied := false
		for f in fighters:
			if f.dead:
				continue
			var d := (p as Vector3).distance_to(f.global_position)
			if d < 2.5:
				occupied = true
			if team >= 0 and int(f.team) == team:
				continue
			md = minf(md, d)
		var sc := md - (1000.0 if occupied else 0.0) - (1000.0 if _spawn_blocked(p) else 0.0)
		if sc > best_d:
			best_d = sc
			best = p
	return best


func free_spawn(team: int, _who: Node = null) -> Vector3:
	return _pick_spawn(team)


func _spawn_blocked(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.4
	sh.height = 1.6
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0.0, 1.0, 0.0))
	q.collision_mask = 1
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _get_remote(fid: int) -> RemoteFighter:
	if remotes.has(fid):
		return remotes[fid] as RemoteFighter
	var r := RemoteFighter.create()
	r.net = self
	r.fid = fid
	r.owner_peer = fid if fid > 0 else 1
	r.team = team_of(fid)
	r.display_name = _name_of(fid)
	var inf: Dictionary = infos.get(fid, {})
	r.suit_idx = int(inf.get("suit", absi(fid) % Loadout.SUITS.size()))
	r.character_idx = int(inf.get("character", absi(fid) % Loadout.CHARACTERS.size()))
	add_child(r)
	remotes[fid] = r
	return r


func _name_of(fid: int) -> String:
	if fid < 0:
		return "BOT %d" % -fid
	if fid == local_fid:
		return my_name
	var inf: Dictionary = infos.get(fid, {})
	return String(inf.get("name", "Jugador"))


func _process(delta: float) -> void:
	if not world_ready:
		return
	if player != null and is_instance_valid(player):
		controls.hp_ratio = player.hp / player.max_hp
		player.god = intermission or protect_t > 0.0
		if protect_t > 0.0:
			protect_t -= delta
		if player.dead:
			respawn_t -= delta
			if not intermission:
				controls.message = "ELIMINADO"
				controls.sub_message = "Reapareces en %d..." % maxi(1, ceili(respawn_t))
			if respawn_t <= 0.0 and not intermission:
				_respawn_player()
	if _is_net():
		_state_t -= delta
		if _state_t <= 0.0 and player != null:
			_state_t = STATE_DT
			rpc("net_state", _pack_state())
		if mode == "host" and not bots.is_empty():
			_bot_t -= delta
			if _bot_t <= 0.0:
				_bot_t = BOT_DT
				rpc("net_bot_states", _pack_bots())
	if intermission and _is_authority():
		inter_t -= delta
		if inter_t <= 0.0:
			_host_round_start()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not world_ready:
			_back_to_menu()


func _pack_state() -> Array:
	var p := player
	return [p.global_position, p.model.rotation.y, p.aim_dir, p._anim_speed, p._anim_aim_t, p._crouch,
		p.model.airborne, p.model.vspeed, String(p.weapon["id"]), p.dead, p.velocity, p.model.reload_p, p.death_impulse, p._prone]


func _pack_bots() -> Array:
	var out: Array = []
	for fid in bots:
		var b = bots[fid]
		if not is_instance_valid(b):
			continue
		out.append([fid, b.global_position, b.model.rotation.y, b.aim_dir, b.anim_speed, b.anim_aim, 0.0,
			false, 0.0, "rifle", b.dead, b.velocity, -1.0, b.death_impulse])
	return out


func _send_event(kind: String, wid: String) -> void:
	if _is_net():
		rpc("net_event", local_fid, kind, wid)


func bot_event(fid: int, kind: String) -> void:
	if mode == "host" and _is_net():
		rpc("net_event", fid, kind, "rifle")


func _on_local_threw(id: String, origin: Vector3, vel: Vector3) -> void:
	if _is_net():
		rpc("net_throw", local_fid, id, origin, vel)


func hit_marker() -> void:
	if hud != null:
		hud.hit()


func send_damage(target: int, amount: float, attacker: int, impulse: Vector3 = Vector3.ZERO) -> void:
	amount = clampf(amount, 0.0, 600.0)
	var peer := target if target > 0 else 1
	if peer == local_fid:
		_apply_damage(target, amount, attacker, impulse)
	elif _is_net():
		rpc_id(peer, "net_damage", target, amount, attacker, impulse)


func _apply_damage(target: int, amount: float, attacker: int, impulse: Vector3 = Vector3.ZERO) -> void:
	amount = clampf(amount, 0.0, 600.0)
	if target == local_fid:
		if player != null and is_instance_valid(player):
			player.take_damage(amount, player.global_position + Vector3(0, 1.0, 0), attacker, impulse)
	elif bots.has(target) and is_instance_valid(bots[target]):
		(bots[target] as Bot).take_damage(amount, Vector3.ZERO, attacker, impulse)


func _on_local_died() -> void:
	player.collision_layer = 0
	respawn_t = RESPAWN_TIME
	var killer: int = player.last_attacker
	if mode == "client":
		if _is_net():
			rpc_id(1, "net_died", local_fid, killer)
	else:
		_host_death(local_fid, killer)


func _respawn_player() -> void:
	if game_mode == "teams" and my_team < 0:
		return
	if player != null and is_instance_valid(player):
		player.remove_from_group("fighters")
		player.remove_from_group("player")
		player.queue_free()
	_spawn_local_player()


func _on_bot_died(bot: Bot, killer: int) -> void:
	var fid := bot.fid
	_host_death(fid, killer)
	get_tree().create_timer(RESPAWN_TIME).timeout.connect(func():
		if not is_inside_tree() or intermission:
			return
		if bots.get(fid) == bot:
			bot.queue_free()
			_spawn_bot(fid))


func _host_death(victim: int, killer: int) -> void:
	if intermission or not scores.has(victim):
		return
	scores[victim][2] += 1
	var text := ""
	if killer != 0 and killer != victim and scores.has(killer):
		scores[killer][1] += 1
		text = "%s eliminó a %s" % [scores[killer][0], scores[victim][0]]
	else:
		text = "%s se eliminó solo" % scores[victim][0]
	_broadcast_scores()
	_broadcast_feed(text)
	if killer == victim or not scores.has(killer):
		return
	if game_mode == "teams":
		var tt := _team_totals()
		for t in team_count:
			if int(tt[t]) >= TEAM_KILL_LIMIT:
				_host_round_end(killer, t)
				return
	elif int(scores[killer][1]) >= KILL_LIMIT:
		_host_round_end(killer)


func _broadcast_scores() -> void:
	if _is_net():
		rpc("net_scores", scores)
	_on_scores_changed()


func _broadcast_feed(text: String) -> void:
	if hud != null:
		hud.add_feed(text)
	if _is_net():
		rpc("net_feed", text)


func _host_round_end(winner: int, team_win: int = -1) -> void:
	if _is_net():
		rpc("net_round_end", winner, team_win)
	_apply_round_end(winner, team_win)
	inter_t = INTERMISSION


func _host_round_start() -> void:
	for fid in scores:
		scores[fid][1] = 0
		scores[fid][2] = 0
	_broadcast_scores()
	if _is_net():
		rpc("net_round_start")
	_apply_round_start()


func _apply_round_end(winner: int, team_win: int = -1) -> void:
	intermission = true
	var wn := String(scores[winner][0]) if scores.has(winner) else _name_of(winner)
	if team_win >= 0:
		wn = "EL EQUIPO " + Teams.name_of(team_win)
	controls.message = "¡GANA %s!" % wn
	controls.sub_message = "Nueva ronda en unos segundos..."


func _apply_round_start() -> void:
	intermission = false
	if map != null:
		map.restore_barrels()
	controls.message = ""
	controls.sub_message = ""
	_respawn_player()
	if _is_authority():
		for fid in bots.keys():
			var b = bots[fid]
			if is_instance_valid(b):
				b.queue_free()
			_spawn_bot(fid)


func _on_scores_changed() -> void:
	if controls == null or hud == null:
		return
	var rows: Array = []
	for fid in scores:
		var s: Array = scores[fid]
		rows.append([String(s[0]), int(s[1]), int(s[2]), fid == local_fid, team_of(int(fid))])
	rows.sort_custom(func(a, b):
		if a[1] != b[1]:
			return a[1] > b[1]
		return a[2] < b[2])
	hud.rows = rows
	if game_mode == "teams":
		var tot := _team_totals()
		var trs: Array = []
		for t in team_count:
			trs.append([t, int(tot[t]), t == my_team])
		trs.sort_custom(func(a, b): return a[1] > b[1])
		hud.team_rows = trs
	else:
		hud.team_rows = []
	var mine := 0
	if scores.has(local_fid):
		mine = int(scores[local_fid][1])
	if mine > controls.kills:
		controls.kill_popup(1)
	controls.kills = mine


func _team_totals() -> Array:
	var out: Array = [0, 0, 0, 0]
	for fid in scores:
		var t := team_of(int(fid))
		if t >= 0 and t < 4:
			out[t] += int(scores[fid][1])
	return out


func _setup_input() -> void:
	_key_action("move_forward", [KEY_W])
	_key_action("move_back", [KEY_S])
	_key_action("move_left", [KEY_A])
	_key_action("move_right", [KEY_D])
	_key_action("look_up", [KEY_UP])
	_key_action("look_down", [KEY_DOWN])
	_key_action("look_left", [KEY_LEFT])
	_key_action("look_right", [KEY_RIGHT])
	_key_action("fire", [KEY_J, KEY_F])
	_key_action("walk", [KEY_SHIFT])
	_key_action("jump", [KEY_SPACE])
	_key_action("crouch", [KEY_C, KEY_CTRL])
	_key_action("toggle_view", [KEY_V])
	_key_action("weapon_next", [KEY_E])
	_key_action("weapon_prev", [KEY_Q])
	var nums := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
	for n in nums.size():
		_key_action("weapon_%d" % (n + 1), [nums[n]])
	_key_action("quick_melee", [KEY_X])
	_key_action("quick_throw", [KEY_G])
	_key_action("reload", [KEY_R])
	_key_action("aim", [KEY_Z])
	_wheel_action("aim", MOUSE_BUTTON_RIGHT)
	_wheel_action("weapon_prev", MOUSE_BUTTON_WHEEL_UP)
	_wheel_action("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)


func _key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		for k in keys:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)


func _wheel_action(action: String, button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_add_event(action, e)

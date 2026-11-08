class_name FfaMenu
extends Control

signal solo_confirmed(cfg: Dictionary)
signal waves_confirmed(map: int)
signal host_confirmed(cfg: Dictionary, is_private: bool, code: String, game_name: String)
signal join_requested(entry: Dictionary, code: String)
signal join_opened
signal join_closed
signal back_pressed

const ORANGE := Color(1.0, 0.7, 0.25)
const WHITE := Color(1, 1, 1, 0.95)
const MAX_BOTS := 10
const SCENE_PATH := "res://ffa_menu.tscn"
const GAME_BUTTON := preload("res://scenes/ui/game_button.tscn")

var map_idx := 0
var bots := 5
var mode := "ffa"
var team_count := 2
var team_bots: Array = [3, 3, 0, 0]
var diff := 1
var my_team := 0
var games: Array = []
var pending_entry: Dictionary = {}

var _kind := "solo"
var _preview_idx := -1
var _preview_map: Node3D
var _screens: Array = []
var _tb_rows: Array = []
var _msg_token := 0

@onready var _scr_config: ScrollContainer = $Config
@onready var _cfg_bar: HBoxContainer = $ConfigBar
@onready var _scr_join: Control = $Join
@onready var _scr_code: Control = $Code
@onready var _msg: Label = $Message
@onready var _config_title: Label = $Config/Box/Title
@onready var _map_btn: Button = $Config/Box/MapButton
@onready var _preview_frame: Control = $MapPreviewFrame
@onready var _map_name: Label = $MapName
@onready var _preview_box: SubViewportContainer = $MapPreviewFrame/MapPreview
@onready var _preview_vp: SubViewport = $MapPreviewFrame/MapPreview/Viewport
@onready var _preview_cam: Camera3D = $MapPreviewFrame/MapPreview/Viewport/Camera
@onready var _mode_btn: Button = $Config/Box/ModeButton
@onready var _ffa_box: Control = $Config/Box/FfaBox
@onready var _bots_label: Label = $Config/Box/FfaBox/BotsRow/BotsLabel
@onready var _teams_box: Control = $Config/Box/TeamsBox
@onready var _teams_btn: Button = $Config/Box/TeamsBox/TeamsButton
@onready var _tb_total: Label = $Config/Box/TeamsBox/TotalLabel
@onready var _myteam_btn: Button = $Config/Box/TeamsBox/MyTeamButton
@onready var _diff_btn: Button = $Config/Box/DiffButton
@onready var _host_box: Control = $Config/Box/HostBox
@onready var _name_edit: LineEdit = $Config/Box/HostBox/NameEdit
@onready var _private_btn: Button = $Config/Box/HostBox/PrivateRow/PrivateButton
@onready var _code_edit: LineEdit = $Config/Box/HostBox/PrivateRow/CodeEdit
@onready var _config_ok: Button = $ConfigBar/OkButton
@onready var _status: Label = $Join/Status
@onready var _list: VBoxContainer = $Join/Scroll/List
@onready var _join_code: LineEdit = $Code/CodeEdit
@onready var _join_error: Label = $Code/Error


static func create() -> FfaMenu:
	return load(SCENE_PATH).instantiate() as FfaMenu


func _ready() -> void:
	size = get_viewport_rect().size
	map_idx = Maps.current
	get_viewport().size_changed.connect(_layout_config)
	_screens = [_scr_config, _scr_join, _scr_code]
	$Config/Box/MapButton.pressed.connect(_on_map)
	$Config/Box/ModeButton.pressed.connect(_on_mode)
	$Config/Box/FfaBox/BotsRow/MinusButton.pressed.connect(_on_bots.bind(-1))
	$Config/Box/FfaBox/BotsRow/PlusButton.pressed.connect(_on_bots.bind(1))
	_teams_btn.pressed.connect(_on_teams)
	for t in Teams.MAX_TEAMS:
		var row := $Config/Box/TeamsBox.get_node("TeamRow%d" % (t + 1)) as HBoxContainer
		var lab := row.get_node("Label") as Label
		lab.add_theme_color_override("font_color", Teams.color(t).lightened(0.25))
		(row.get_node("MinusButton") as Button).pressed.connect(_on_team_bots.bind(t, -1))
		(row.get_node("PlusButton") as Button).pressed.connect(_on_team_bots.bind(t, 1))
		_tb_rows.append({"row": row, "label": lab, "minus": row.get_node("MinusButton"), "plus": row.get_node("PlusButton")})
	_myteam_btn.pressed.connect(_on_my_team)
	_diff_btn.pressed.connect(_on_diff)
	_private_btn.toggled.connect(_on_private_toggled)
	_config_ok.pressed.connect(_confirm_config)
	$ConfigBar/BackButton.pressed.connect(show_main)
	$Join/BackButton.pressed.connect(_on_join_back)
	$Code/EnterButton.pressed.connect(_on_enter_code)
	$Code/CancelButton.pressed.connect(_on_code_cancel)


func _on_map() -> void:
	map_idx = (map_idx + 1) % Maps.LIST.size()
	_refresh_config()


func _on_mode() -> void:
	var order: Array = ["waves", "ffa", "teams"] if _kind == "solo" else ["ffa", "teams"]
	mode = String(order[(order.find(mode) + 1) % order.size()])
	_refresh_config()


func _on_bots(d: int) -> void:
	bots = clampi(bots + d, 0, MAX_BOTS)
	_refresh_config()


func _on_teams() -> void:
	var total := _team_bot_total()
	team_count = 2 if team_count >= Teams.MAX_TEAMS else team_count + 1
	team_bots = Teams.split_bots(total, team_count)
	my_team = mini(my_team, team_count - 1)
	_refresh_config()


func _on_my_team() -> void:
	my_team = (my_team + 1) % team_count
	_refresh_config()


func _on_diff() -> void:
	diff = (diff + 1) % Bot.LEVELS.size()
	_refresh_config()


func _on_private_toggled(on: bool) -> void:
	_private_btn.text = "PRIVADA" if on else "PÚBLICA"
	_code_edit.visible = on


func _on_join_back() -> void:
	join_closed.emit()
	show_main()


func _on_enter_code() -> void:
	var code := _join_code.text.strip_edges()
	if code.is_empty():
		_join_error.text = "Escribe el código"
		return
	_join_error.text = ""
	join_requested.emit(pending_entry, code)


func _on_code_cancel() -> void:
	_show(_scr_join)


func _show(target: Control) -> void:
	for s in _screens:
		s.visible = (s == target)
	_cfg_bar.visible = target == _scr_config
	_preview_frame.visible = target == _scr_config
	_map_name.visible = target == _scr_config
	if target == _scr_config:
		_update_preview()
		_render_preview.call_deferred()


func show_main() -> void:
	back_pressed.emit()


func open_start(entry: String) -> void:
	match entry:
		"host":
			_open_config("host")
		"join":
			show_join()
		_:
			_open_config("solo")


func show_join() -> void:
	_show(_scr_join)
	join_opened.emit()
	_rebuild_list()


func show_message(text: String) -> void:
	_msg_token += 1
	var token := _msg_token
	_msg.text = text
	await get_tree().create_timer(4.0).timeout
	if token == _msg_token and is_instance_valid(_msg):
		_msg.text = ""


func show_code_error(text: String) -> void:
	_join_error.text = text


func set_games(list: Array) -> void:
	games = list
	if _scr_join != null and _scr_join.visible:
		_rebuild_list()


func _layout_config() -> void:
	size = get_viewport_rect().size
	$Config/Box.custom_minimum_size = Vector2(_scr_config.size.x - 12.0, 0.0)


func _team_bot_total() -> int:
	var n := 0
	for t in Teams.MAX_TEAMS:
		n += int(team_bots[t])
	return n


func _on_team_bots(t: int, d: int) -> void:
	if t >= team_count:
		return
	if d > 0 and _team_bot_total() >= MAX_BOTS:
		return
	team_bots[t] = maxi(0, int(team_bots[t]) + d)
	_refresh_config()


func _open_config(kind: String) -> void:
	_kind = kind
	_config_title.text = "JUGAR SOLO" if kind == "solo" else "CREAR PARTIDA"
	_config_ok.text = "JUGAR" if kind == "solo" else "CREAR Y JUGAR"
	if kind == "host" and mode == "waves":
		mode = "ffa"
	_host_box.visible = kind == "host"
	_private_btn.button_pressed = false
	_code_edit.text = str(randi_range(1000, 9999))
	_show(_scr_config)
	_layout_config()
	_refresh_config()
	_layout_config.call_deferred()


func _refresh_config() -> void:
	_map_btn.text = "MAPA: " + String(Maps.LIST[map_idx]["name"])
	_map_name.text = String(Maps.LIST[map_idx]["name"])
	_update_preview()
	var mode_names := {"waves": "OLEADAS (SOBREVIVE)", "ffa": "TODOS CONTRA TODOS", "teams": "POR EQUIPOS"}
	_mode_btn.text = "MODO: " + String(mode_names[mode])
	_ffa_box.visible = mode == "ffa"
	_teams_box.visible = mode == "teams"
	_diff_btn.visible = mode != "waves"
	_bots_label.text = "BOTS: %d" % bots
	_teams_btn.text = "EQUIPOS: %d  (%s)" % [team_count, " · ".join(PackedStringArray(Teams.NAMES.slice(0, team_count)))]
	var total := _team_bot_total()
	for t in Teams.MAX_TEAMS:
		var r: Dictionary = _tb_rows[t]
		(r["row"] as Control).visible = t < team_count
		(r["label"] as Label).text = "%s: %d bots" % [Teams.NAMES[t], int(team_bots[t])]
		(r["minus"] as Button).disabled = int(team_bots[t]) <= 0
		(r["plus"] as Button).disabled = total >= MAX_BOTS
	_tb_total.text = "Total: %d / %d bots" % [total, MAX_BOTS]
	var mc: Color = Teams.color(my_team)
	_myteam_btn.text = "MI EQUIPO: " + Teams.NAMES[my_team]
	_myteam_btn.add_theme_color_override("font_color", mc.lightened(0.35))
	var ms := _myteam_btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	ms.bg_color = Color(mc.r, mc.g, mc.b, 0.4)
	ms.border_color = mc
	ms.set_border_width_all(3)
	_myteam_btn.add_theme_stylebox_override("normal", ms)
	_diff_btn.text = "DIFICULTAD DE LOS BOTS: " + String(Bot.LEVELS[diff]["name"])


func make_config() -> Dictionary:
	var counts: Array = [0, 0, 0, 0]
	if mode == "ffa":
		counts[0] = bots
	else:
		for t in team_count:
			counts[t] = int(team_bots[t])
	return {"map": map_idx, "mode": mode, "teams": team_count if mode == "teams" else 0, "bots": counts,
		"diff": diff, "my_team": my_team if mode == "teams" else -1}


func _confirm_config() -> void:
	if _kind == "solo":
		if mode == "waves":
			waves_confirmed.emit(map_idx)
		else:
			solo_confirmed.emit(make_config())
		return
	var priv := _private_btn.button_pressed
	var code := _code_edit.text.strip_edges()
	if priv and code.is_empty():
		show_message("Escribe un código para la partida privada")
		return
	host_confirmed.emit(make_config(), priv, code, _name_edit.text.strip_edges())


func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_status.text = "Elige una partida" if not games.is_empty() else "Buscando partidas en tu wifi..."
	for g in games:
		var b := GAME_BUTTON.instantiate() as Button
		var t := "%s  (%d/%d)" % [g["name"], int(g["n"]), int(g["max"])]
		var extra := String(g.get("map", ""))
		if extra != "":
			t += "\n%s · %s · %d bots" % [extra, String(g.get("mode", "")), int(g.get("bots", 0))]
		if bool(g["priv"]):
			t += "  [privada]"
		var full: bool = int(g["n"]) >= int(g["max"])
		if full:
			t += "  llena"
		b.text = t
		b.disabled = full
		b.pressed.connect(_on_game_pressed.bind(g))
		_list.add_child(b)


func _on_game_pressed(entry: Dictionary) -> void:
	if bool(entry["priv"]):
		pending_entry = entry
		_join_code.text = ""
		_join_error.text = ""
		_show(_scr_code)
		_join_code.grab_focus()
	else:
		join_requested.emit(entry, "")


func _update_preview() -> void:
	if _preview_idx == map_idx and _preview_map != null:
		return
	_preview_idx = map_idx
	if _preview_map != null:
		_preview_map.queue_free()
		_preview_map = null
	var packed: PackedScene = load(Maps.LIST[map_idx]["scene"])
	var m := packed.instantiate() as Node3D
	_preview_map = m
	_preview_vp.add_child(m)
	for we in m.find_children("*", "WorldEnvironment", true, false):
		var holder := we as WorldEnvironment
		if holder.environment != null:
			var env := holder.environment.duplicate() as Environment
			env.fog_enabled = false
			holder.environment = env
	await get_tree().process_frame
	if m != _preview_map or not is_inside_tree():
		return
	_frame_preview(m)
	_render_preview()


func _frame_preview(m: Node3D) -> void:
	var pts: Array = []
	var en = m.get("enemy_spawns")
	var pl = m.get("player_spawn")
	if en != null:
		pts.append_array(en)
	if pl != null:
		pts.append(pl)
	var lo := Vector2(-40.0, -40.0)
	var hi := Vector2(40.0, 40.0)
	if not pts.is_empty():
		lo = Vector2(INF, INF)
		hi = Vector2(-INF, -INF)
		for p in pts:
			lo.x = minf(lo.x, p.x)
			lo.y = minf(lo.y, p.z)
			hi.x = maxf(hi.x, p.x)
			hi.y = maxf(hi.y, p.z)
	var c := (lo + hi) * 0.5
	var radius := maxf(hi.x - lo.x, hi.y - lo.y) * 0.5 + 12.0
	var center := Vector3(c.x, 1.5, c.y)
	var dir := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(28.0))
	dir = (dir + Vector3.UP * 0.62).normalized()
	_preview_cam.global_position = center + dir * radius * 2.15
	_preview_cam.look_at(center, Vector3.UP)


func _render_preview() -> void:
	if _preview_map == null:
		return
	_frame_preview(_preview_map)
	_preview_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_preview_vp.render_target_update_mode = SubViewport.UPDATE_ONCE

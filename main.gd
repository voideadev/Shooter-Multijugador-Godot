extends Node3D

var map: MapBase
var pause: PauseMenu
var controls: Controls
var player: Player
var wave := 0
var score := 0
var alive := 0
var spawn_queue := 0
var spawn_cd := 0.0
var wave_t := 1.5
var msg_t := 0.0
var game_over := false
var restart_t := 0.0


func _ready() -> void:
	_setup_input()
	_build_map()
	_build_hud()
	_build_player()
	Gfx.apply(self)


func _process(delta: float) -> void:
	controls.hp_ratio = player.hp / player.max_hp
	if msg_t > 0.0:
		msg_t -= delta
		if msg_t <= 0.0 and not game_over:
			controls.message = ""
			controls.sub_message = ""
	if game_over:
		restart_t -= delta
		return
	if spawn_queue > 0:
		spawn_cd -= delta
		if spawn_cd <= 0.0:
			_spawn_enemy()
			spawn_queue -= 1
			spawn_cd = 0.7
	elif alive <= 0:
		wave_t -= delta
		if wave_t <= 0.0:
			_start_wave()


func _go_menu() -> void:
	get_tree().paused = false
	MainMenu.start_panel = "play"
	get_tree().change_scene_to_file("res://menu.tscn")


func _input(event: InputEvent) -> void:
	if game_over and restart_t <= 0.0:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed):
			get_tree().reload_current_scene()


func _start_wave() -> void:
	wave += 1
	spawn_queue = mini(2 + wave, 9)
	spawn_cd = 0.0
	controls.wave = wave
	controls.message = "RONDA %d" % wave
	controls.sub_message = ""
	msg_t = 2.0


func _spawn_enemy() -> void:
	var pts: Array = map.enemy_spawns.duplicate()
	pts.shuffle()
	var pos: Vector3 = pts[0]
	for p in pts:
		if p.distance_to(player.global_position) > 14.0:
			pos = p
			break
	var e := Enemy.create()
	e.player = player
	e.hp = 45.0 + wave * 5.0
	e.speed = 3.0 + minf(wave, 8) * 0.15
	e.position = pos
	add_child(e)
	e.reset_physics_interpolation()
	e.killed.connect(_on_enemy_killed)
	alive += 1


func _on_enemy_killed(_e: Enemy) -> void:
	alive -= 1
	score += 100
	controls.score = score
	controls.kill_popup(100)
	if alive <= 0 and spawn_queue == 0 and not game_over:
		wave_t = 3.0
		player.hp = minf(player.max_hp, player.hp + 30.0)
		player.restock()
		controls.message = "¡RONDA SUPERADA!"
		controls.sub_message = "+30 de vida  ·  +lanzables"
		msg_t = 2.5


func _on_player_died() -> void:
	game_over = true
	restart_t = 1.0
	controls.message = "GAME OVER"
	controls.sub_message = "Puntos: %d  -  Toca la pantalla para reiniciar" % score


func _build_map() -> void:
	map = Maps.create()
	add_child(map)
	map.bake_navigation()
	map.spawn_health_pickups()


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
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)


func _build_hud() -> void:
	var layer: CanvasLayer = $HudLayer
	controls = Controls.create()
	layer.add_child(controls)
	pause = PauseMenu.create()
	pause.controls = controls
	pause.pause_tree = true
	add_child(pause)
	pause.exit_pressed.connect(_go_menu)
	controls.menu_pressed.connect(pause.open)


func _build_player() -> void:
	player = Player.create()
	player.controls = controls
	player.position = map.player_spawn
	add_child(player)
	player.reset_physics_interpolation()
	player.died.connect(_on_player_died)

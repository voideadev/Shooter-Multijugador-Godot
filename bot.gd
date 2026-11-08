class_name Bot
extends CharacterBody3D

signal died(bot: Bot, killer: int)

enum State { PATROL, CHASE, SEARCH }

const GRAVITY := 28.0
const FOV_COS := 0.34
const NEAR_SENSE := 2.5
const HEAR_SHOT := 26.0
const PATROL_SPEED := 0.5
const SEARCH_SPEED := 0.8
const LEVELS := [
	{"name": "FÁCIL", "spread": 0.085, "damage": 6.0, "speed": 0.85, "burst": 2, "pause_min": 1.3, "pause_max": 2.2, "range": 28.0, "lead": 0.0, "sight": 22.0, "notice": 0.9, "memory": 2.0},
	{"name": "NORMAL", "spread": 0.045, "damage": 8.0, "speed": 1.0, "burst": 3, "pause_min": 0.8, "pause_max": 1.5, "range": 40.0, "lead": 0.4, "sight": 32.0, "notice": 0.6, "memory": 3.0},
	{"name": "DIFÍCIL", "spread": 0.02, "damage": 10.0, "speed": 1.15, "burst": 4, "pause_min": 0.4, "pause_max": 0.9, "range": 55.0, "lead": 0.85, "sight": 42.0, "notice": 0.35, "memory": 4.0},
]

var fid := -1
var team := -1
var level := 1
var net: Node = null
var hp := 100.0
var max_hp := 100.0
var speed := 4.0
var dead := false
var god := false
var last_attacker := 0
var death_impulse := Vector3.ZERO
var last_noise := -10.0
var state := State.PATROL

var model: Humanoid
var yaw := 0.0
var aim_dir := Vector3.FORWARD
var anim_speed := 0.0
var anim_aim := 0.0
var target = null

var _protect := 2.5
var _goal := Vector3.ZERO
var _goal_new := true
var _last_known := Vector3.ZERO
var _watch = null
var _seen_now := false
var _notice_t := 0.0
var _mem_t := 0.0
var _look_t := 0.0
var _patrol_t := 0.0
var _patrol_wait := 0.0
var _search_arrived := false
var _scan_dir := 1.0
var _sense_t := 0.0
var _shoot_cd := 1.0
var _burst := 0
var _strafe_dir := 1.0
var _strafe_t := 2.0
var _dead_t := 0.0
var _path := PackedVector3Array()
var _path_i := 1
var _path_t := 0.0
var _stuck_t := 0.0
var _check_t := 0.4
var _unstuck_n := 0


static func create() -> Bot:
	return load("res://scenes/characters/bot.tscn").instantiate() as Bot


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("fighters")
	collision_layer = 4
	collision_mask = 1 | 2 | 4

	model = $Model
	var sd: Dictionary = Loadout.SUITS[absi(fid) % Loadout.SUITS.size()]
	var suit_c: Color = sd["suit"]
	var armor_c: Color = sd["armor"]
	var accent_c := Color(1.0, 0.6, 0.2)
	if team >= 0:
		suit_c = Teams.suit(team)
		armor_c = Teams.armor(team)
		accent_c = Teams.color(team)
	model.build(suit_c, armor_c, accent_c, 1, Color(0.86, 0.66, 0.52), Color(0.13, 0.09, 0.07), absi(fid) % Loadout.CHARACTERS.size())
	model.max_speed = speed

	_shoot_cd = randf_range(0.8, 1.8)
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	_scan_dir = 1.0 if randf() < 0.5 else -1.0
	_patrol_wait = randf_range(0.2, 2.0)
	_sense_t = randf_range(0.0, 0.15)
	yaw = randf() * TAU
	model.rotation.y = yaw
	speed = randf_range(3.6, 4.4) * float(LEVELS[level]["speed"])
	model.max_speed = speed


func _physics_process(delta: float) -> void:
	if dead:
		_dead_t += delta
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		model.animate(delta, 0.0, 1.0, 0.0, aim_dir)
		return

	if _protect > 0.0:
		_protect -= delta
	if _check_t > 0.0:
		_check_t -= delta
		if _check_t <= 0.0 and _embedded():
			_relocate()
	var pause: bool = net != null and net.intermission
	god = pause or _protect > 0.0

	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta

	if pause:
		_stop(delta)
		return

	_sense_t -= delta
	if _sense_t <= 0.0:
		_sense_t = 0.15
		_sense(0.15)

	match state:
		State.CHASE:
			_chase(delta)
		State.SEARCH:
			_search(delta)
		_:
			_patrol(delta)


func _sense(dt: float) -> void:
	var lv: Dictionary = LEVELS[level]
	var fwd := -Basis(Vector3.UP, yaw).z
	var sight := float(lv["sight"])
	var now := Time.get_ticks_msec() / 1000.0
	var seen = null
	var seen_d := INF
	var heard := false
	var heard_pos := Vector3.ZERO
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == self or f.dead or f.god:
			continue
		if team >= 0 and int(f.team) == team:
			continue
		var to: Vector3 = f.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if "last_noise" in f and now - float(f.last_noise) < 0.5 and d < HEAR_SHOT:
			heard = true
			heard_pos = f.global_position
		if d > sight:
			continue
		if d > NEAR_SENSE and d > 0.01 and fwd.dot(to / d) < FOV_COS:
			continue
		if d < seen_d and _can_see(f):
			seen = f
			seen_d = d

	_seen_now = seen != null
	if seen != null:
		_notice_t += dt
		_last_known = seen.global_position
		if state == State.CHASE or _notice_t >= float(lv["notice"]):
			if state != State.CHASE:
				_burst = 0
				_shoot_cd = maxf(_shoot_cd, 0.35)
			state = State.CHASE
			target = seen
			_mem_t = 0.0
			_watch = null
		else:
			_watch = seen
	else:
		_watch = null
		_notice_t = maxf(0.0, _notice_t - dt * 2.0)
		if state == State.CHASE:
			_mem_t += dt
			if target == null or not is_instance_valid(target) or target.dead:
				_begin_patrol()
			elif _mem_t >= float(lv["memory"]):
				_begin_search(_last_known)
		elif heard:
			var off := Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
			_begin_search(heard_pos + off)


func _begin_patrol() -> void:
	state = State.PATROL
	_notice_t = 0.0
	target = null
	_goal_new = true
	_patrol_wait = randf_range(0.3, 1.2)


func _begin_search(pos: Vector3) -> void:
	state = State.SEARCH
	_notice_t = 0.0
	target = null
	_last_known = pos
	_goal = pos
	_path_t = 0.0
	_look_t = 0.0
	_patrol_t = 0.0
	_search_arrived = false
	_scan_dir = 1.0 if randf() < 0.5 else -1.0


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	move_and_slide()
	anim_speed = 0.0
	anim_aim = 0.0
	model.animate(delta, 0.0, 1.0, 0.0, -Basis(Vector3.UP, yaw).z)


func _react(delta: float) -> bool:
	if _watch == null or not is_instance_valid(_watch):
		return false
	var d: Vector3 = _watch.global_position - global_position
	d.y = 0.0
	if d.length() > 0.01:
		yaw = lerp_angle(yaw, atan2(-d.x, -d.z), minf(1.0, 8.0 * delta))
	model.rotation.y = yaw
	_stop(delta)
	return true


func _separation() -> Vector3:
	var m := Vector3.ZERO
	for o in get_tree().get_nodes_in_group("fighters"):
		if o == self or o.dead:
			continue
		var d: Vector3 = global_position - o.global_position
		d.y = 0.0
		if d.length() < 1.6 and d.length() > 0.01:
			m += d.normalized() * 0.6
	return m


func _apply_move(delta: float, move: Vector3, mul: float) -> Vector3:
	var tv := move.limit_length(1.0) * speed * mul
	velocity.x = move_toward(velocity.x, tv.x, 20.0 * delta)
	velocity.z = move_toward(velocity.z, tv.z, 20.0 * delta)
	move_and_slide()
	anim_speed = Vector2(velocity.x, velocity.z).length()
	return tv


func _is_stuck(delta: float, tv: Vector3) -> bool:
	if tv.length() > 0.3 * speed and anim_speed < 0.3:
		_stuck_t += delta
		if _stuck_t > 1.2:
			_stuck_t = 0.0
			return true
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta * 2.0)
	return false


func _face_move(delta: float, move: Vector3) -> void:
	if move.length() > 0.05:
		yaw = lerp_angle(yaw, atan2(-move.x, -move.z), minf(1.0, 6.0 * delta))
	model.rotation.y = yaw


func _patrol(delta: float) -> void:
	if _react(delta):
		return
	if _patrol_wait > 0.0:
		_patrol_wait -= delta
		yaw += _scan_dir * 0.5 * delta
		model.rotation.y = yaw
		_stop(delta)
		return
	if _goal_new:
		_pick_patrol_goal()
	_patrol_t += delta
	var to := _goal - global_position
	to.y = 0.0
	if to.length() < 1.4 or _patrol_t > 14.0:
		_goal_new = true
		_patrol_wait = randf_range(1.5, 3.5)
		_scan_dir = 1.0 if randf() < 0.5 else -1.0
		_stop(delta)
		return
	var move := _path_dir(delta, to.normalized())
	_face_move(delta, move)
	move += _separation()
	var tv := _apply_move(delta, move, PATROL_SPEED)
	if _is_stuck(delta, tv):
		_unstick(move.cross(Vector3.UP))
		_goal_new = true
	model.animate(delta, anim_speed, 1.0, 0.0, -Basis(Vector3.UP, yaw).z)


func _pick_patrol_goal() -> void:
	var nav := get_world_3d().navigation_map
	var pick := Vector3.ZERO
	for i in 6:
		var p := NavigationServer3D.map_get_random_point(nav, 1, true)
		var d := p.distance_to(global_position)
		if p != Vector3.ZERO and d > 8.0 and d < 45.0:
			pick = p
			break
	if pick == Vector3.ZERO:
		var a := randf() * TAU
		pick = global_position + Vector3(cos(a), 0.0, sin(a)) * randf_range(8.0, 16.0)
	_goal = pick
	_goal_new = false
	_patrol_t = 0.0
	_path_t = 0.0


func _search(delta: float) -> void:
	if _react(delta):
		return
	var to := _goal - global_position
	to.y = 0.0
	_patrol_t += delta
	if not _search_arrived and to.length() > 1.6 and _patrol_t < 12.0:
		var move := _path_dir(delta, to.normalized())
		_face_move(delta, move)
		move += _separation()
		var tv := _apply_move(delta, move, SEARCH_SPEED)
		if _is_stuck(delta, tv):
			_unstick(move.cross(Vector3.UP))
		model.animate(delta, anim_speed, 1.0, 0.6, -Basis(Vector3.UP, yaw).z)
		return
	_search_arrived = true
	_look_t += delta
	yaw += _scan_dir * 1.1 * delta
	model.rotation.y = yaw
	_stop(delta)
	if _look_t > 3.5:
		_begin_patrol()


func _chase(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		_begin_patrol()
		_stop(delta)
		return
	var tp: Vector3 = target.global_position if _seen_now else _last_known
	_goal = tp
	var to := tp - global_position
	to.y = 0.0
	var dist := to.length()
	var dir_to := to.normalized() if dist > 0.01 else Vector3.FORWARD
	var side := dir_to.cross(Vector3.UP)

	yaw = lerp_angle(yaw, atan2(-dir_to.x, -dir_to.z), minf(1.0, 8.0 * delta))
	model.rotation.y = yaw

	var move := Vector3.ZERO
	if dist > 12.0 or not _seen_now:
		if dist > 1.5:
			move = _path_dir(delta, dir_to)
			if _path.size() < 2 and get_slide_collision_count() > 0:
				move += side * _strafe_dir * 0.8
	elif dist < 5.0:
		move = -dir_to * 0.7 + side * _strafe_dir * 0.6
	else:
		_strafe_t -= delta
		if _strafe_t <= 0.0:
			_strafe_dir = -_strafe_dir
			_strafe_t = randf_range(1.0, 2.2)
		move = side * _strafe_dir * 0.7
	move += _separation()

	var tv := _apply_move(delta, move, 1.0)
	if _is_stuck(delta, tv):
		_unstick(side)

	var lv: Dictionary = LEVELS[level]
	var aiming := _seen_now and dist < float(lv["range"])
	if _seen_now:
		var chest: Vector3 = tp + Vector3(0, _body_h(target), 0)
		var wanted := (chest - model.muzzle.global_position).normalized()
		aim_dir = aim_dir.lerp(wanted, minf(1.0, 10.0 * delta)).normalized()
	else:
		aim_dir = aim_dir.lerp(-Basis(Vector3.UP, yaw).z, minf(1.0, 6.0 * delta)).normalized()
	anim_aim = 1.0 if aiming else 0.0
	_shoot_cd -= delta
	if aiming and _shoot_cd <= 0.0:
		_shoot(dist)
		_burst += 1
		if _burst >= int(lv["burst"]):
			_burst = 0
			_shoot_cd = randf_range(float(lv["pause_min"]), float(lv["pause_max"]))
		else:
			_shoot_cd = 0.16

	model.animate(delta, anim_speed, 1.0, anim_aim, aim_dir)


func _embedded() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.3
	sh.height = 1.5
	q.shape = sh
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 0.95, 0.0))
	q.collision_mask = 1
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _relocate() -> void:
	var nav := get_world_3d().navigation_map
	var np := NavigationServer3D.map_get_closest_point(nav, global_position)
	var ok := np != Vector3.ZERO and np.distance_to(global_position) < 6.0 and np.distance_to(global_position) > 0.2
	if ok:
		global_position = np + Vector3(0.0, 0.1, 0.0)
	elif net != null and net.has_method("free_spawn"):
		global_position = net.free_spawn(team, self)
	velocity = Vector3.ZERO
	_path = PackedVector3Array()
	_path_t = 0.0
	reset_physics_interpolation()


func _unstick(side: Vector3) -> void:
	_unstuck_n += 1
	_path = PackedVector3Array()
	_path_t = 0.0
	if _embedded() or _unstuck_n % 3 == 0:
		_relocate()
		return
	_strafe_dir = -_strafe_dir
	velocity.x += side.x * _strafe_dir * 3.0
	velocity.z += side.z * _strafe_dir * 3.0


func _can_see(f) -> bool:
	var from := global_position + Vector3(0, 1.4, 0)
	var to: Vector3 = f.global_position + Vector3(0, _body_h(f), 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _path_dir(delta: float, fallback: Vector3) -> Vector3:
	_path_t -= delta
	if _path_t <= 0.0:
		_path_t = 0.4
		_path = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, _goal, true)
		_path_i = 1
	if _path.size() < 2:
		return fallback
	while _path_i < _path.size() - 1:
		var p := _path[_path_i]
		if Vector2(global_position.x - p.x, global_position.z - p.z).length() < 0.7 and absf(global_position.y - p.y) < 1.5:
			_path_i += 1
		else:
			break
	var t := _path[mini(_path_i, _path.size() - 1)]
	var d := Vector3(t.x - global_position.x, 0.0, t.z - global_position.z)
	return d.normalized() if d.length() > 0.05 else fallback


func _shoot(dist: float) -> void:
	last_noise = Time.get_ticks_msec() / 1000.0
	var tv: Vector3 = target.velocity
	var lv: Dictionary = LEVELS[level]
	var lead: Vector3 = target.global_position + Vector3(0, _body_h(target), 0) + tv * (dist / 60.0) * float(lv["lead"])
	var origin := Bullet.safe_origin(self, global_position + Vector3(0, 1.3, 0), model.muzzle.global_position)
	var dir := (lead - origin).normalized()
	dir += Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * float(lv["spread"])
	var b := Bullet.create()
	get_parent().add_child(b)
	b.setup(origin, dir, 60.0, float(lv["damage"]), Teams.color(team) if team >= 0 else Color(1.0, 0.65, 0.25), 1 | 2 | 4, float(lv["range"]) / 60.0 + 0.15, 1.0)
	b.attacker = fid
	b.exclude = [get_rid()]
	model.fire_effect()
	Sfx.play_at(self, "enemy_shot", origin, -2.0)
	if net != null:
		net.bot_event(fid, "shot")


func head_y() -> float:
	return global_position.y + 1.5


func stagger(v: Vector3) -> void:
	if dead:
		return
	velocity.x += v.x
	velocity.z += v.z


func take_damage(amount: float, _pos: Vector3 = Vector3.ZERO, attacker: int = 0, impulse: Vector3 = Vector3.ZERO) -> void:
	if dead or god:
		return
	if net != null and net.is_friendly(attacker, fid):
		return
	hp -= amount
	if attacker != 0:
		last_attacker = attacker
		if state != State.CHASE:
			for f in get_tree().get_nodes_in_group("fighters"):
				if f != self and "fid" in f and int(f.fid) == attacker:
					_begin_search(f.global_position)
					_notice_t = float(LEVELS[level]["notice"])
					break
	model.hit()
	Sfx.play_at(self, "hit", global_position + Vector3(0, 1.2, 0), 0.0)
	if net != null and attacker == net.local_fid:
		net.hit_marker()
	if hp <= 0.0:
		dead = true
		collision_layer = 0
		collision_mask = 1
		remove_from_group("enemies")
		var push := Vector3(0.0, 1.5, 0.0)
		if impulse != Vector3.ZERO:
			death_impulse = impulse
			push = impulse / 0.6
		model.die(push)
		Sfx.play_at(self, "die", global_position, 0.0)
		died.emit(self, last_attacker)


func _body_h(n) -> float:
	var v = n.get("body_h")
	return float(v) if v != null else 1.2

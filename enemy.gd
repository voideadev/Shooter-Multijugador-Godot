class_name Enemy
extends CharacterBody3D

signal killed(enemy: Enemy)

enum State { PATROL, CHASE, SEARCH }

const GRAVITY := 28.0
const SIGHT := 30.0
const FOV_COS := 0.34
const NEAR_SENSE := 2.5
const HEAR_SHOT := 24.0
const NOTICE_TIME := 0.6
const MEMORY := 3.0
const PATROL_SPEED := 0.5
const SEARCH_SPEED := 0.8

var player: Player
var hp := 60.0
var speed := 3.4
var dead := false
var state := State.PATROL

var model: Humanoid
var yaw := 0.0
var aim_dir := Vector3.FORWARD
var _shoot_cd := 1.0
var _strafe_dir := 1.0
var _strafe_t := 2.0
var _dead_t := 0.0
var _fwd_sign := 1.0
var _path := PackedVector3Array()
var _path_i := 1
var _path_t := 0.0
var _goal := Vector3.ZERO
var _goal_new := true
var _last_known := Vector3.ZERO
var _watch := false
var _seen_now := false
var _notice_t := 0.0
var _mem_t := 0.0
var _look_t := 0.0
var _patrol_t := 0.0
var _patrol_wait := 0.0
var _search_arrived := false
var _scan_dir := 1.0
var _sense_t := 0.0
var _stuck_t := 0.0


static func create() -> Enemy:
	return load("res://scenes/characters/enemy.tscn").instantiate() as Enemy


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4

	model = $Model
	model.build(Color(0.36, 0.31, 0.2), Color(0.22, 0.17, 0.12), Color(1.0, 0.6, 0.2), 1)
	model.max_speed = speed

	_shoot_cd = randf_range(1.0, 2.2)
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	_scan_dir = 1.0 if randf() < 0.5 else -1.0
	_patrol_wait = randf_range(0.2, 2.0)
	_sense_t = randf_range(0.0, 0.15)
	yaw = randf() * TAU
	model.rotation.y = yaw


func _physics_process(delta: float) -> void:
	if dead:
		_dead_t += delta
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		model.animate(delta, 0.0, 1.0, 0.0, aim_dir)
		if _dead_t > 4.0:
			model.position.y -= delta * 0.4
		if _dead_t > 7.0:
			queue_free()
		return

	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta

	if player == null or player.dead:
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
	var to := player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	var fwd := -Basis(Vector3.UP, yaw).z
	var seen := false
	if d <= SIGHT and (d <= NEAR_SENSE or d < 0.01 or fwd.dot(to / d) >= FOV_COS):
		seen = _has_los()
	_seen_now = seen
	if seen:
		_notice_t += dt
		_last_known = player.global_position
		if state == State.CHASE or _notice_t >= NOTICE_TIME:
			if state != State.CHASE:
				_shoot_cd = maxf(_shoot_cd, 0.5)
			state = State.CHASE
			_mem_t = 0.0
			_watch = false
		else:
			_watch = true
		return
	_watch = false
	_notice_t = maxf(0.0, _notice_t - dt * 2.0)
	if state == State.CHASE:
		_mem_t += dt
		if _mem_t >= MEMORY:
			_begin_search(_last_known)
	elif "last_noise" in player and Time.get_ticks_msec() / 1000.0 - float(player.last_noise) < 0.5 and d < HEAR_SHOT:
		var off := Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
		_begin_search(player.global_position + off)


func _begin_patrol() -> void:
	state = State.PATROL
	_notice_t = 0.0
	_goal_new = true
	_patrol_wait = randf_range(0.3, 1.2)


func _begin_search(pos: Vector3) -> void:
	state = State.SEARCH
	_notice_t = 0.0
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
	model.animate(delta, 0.0, 1.0, 0.0, -Basis(Vector3.UP, yaw).z)


func _react(delta: float) -> bool:
	if not _watch or player == null:
		return false
	var d := player.global_position - global_position
	d.y = 0.0
	if d.length() > 0.01:
		yaw = lerp_angle(yaw, atan2(-d.x, -d.z), minf(1.0, 8.0 * delta))
	model.rotation.y = yaw
	_stop(delta)
	return true


func _separation() -> Vector3:
	var m := Vector3.ZERO
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == self:
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
	return tv


func _is_stuck(delta: float, tv: Vector3) -> bool:
	var spd := Vector2(velocity.x, velocity.z).length()
	if tv.length() > 0.3 * speed and spd < 0.3:
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
		_goal_new = true
	model.animate(delta, Vector2(velocity.x, velocity.z).length(), 1.0, 0.0, -Basis(Vector3.UP, yaw).z)


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
		_is_stuck(delta, tv)
		model.animate(delta, Vector2(velocity.x, velocity.z).length(), 1.0, 0.6, -Basis(Vector3.UP, yaw).z)
		return
	_search_arrived = true
	_look_t += delta
	yaw += _scan_dir * 1.1 * delta
	model.rotation.y = yaw
	_stop(delta)
	if _look_t > 3.5:
		_begin_patrol()


func _chase(delta: float) -> void:
	var tp: Vector3 = player.global_position if _seen_now else _last_known
	_goal = tp
	var to := tp - global_position
	to.y = 0.0
	var dist := to.length()
	var dir_to := to.normalized() if dist > 0.01 else Vector3.FORWARD
	var side := dir_to.cross(Vector3.UP)

	yaw = lerp_angle(yaw, atan2(-dir_to.x, -dir_to.z), minf(1.0, 8.0 * delta))
	model.rotation.y = yaw

	var move := Vector3.ZERO
	if dist > 13.0 or not _seen_now:
		if dist > 1.5:
			move = _path_dir(delta, dir_to)
			if _path.size() < 2 and get_slide_collision_count() > 0:
				move += side * _strafe_dir * 0.8
	elif dist < 6.0:
		move = -dir_to * 0.8 + side * _strafe_dir * 0.5
	else:
		_strafe_t -= delta
		if _strafe_t <= 0.0:
			_strafe_dir = -_strafe_dir
			_strafe_t = randf_range(1.5, 3.0)
		move = side * _strafe_dir * 0.55
	move += _separation()

	var tv := _apply_move(delta, move, 1.0)
	_is_stuck(delta, tv)

	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > 0.4:
		var f := -Basis(Vector3.UP, yaw).z
		_fwd_sign = -1.0 if velocity.dot(f) < -0.4 * spd else 1.0

	var aiming := _seen_now and dist < 24.0
	if _seen_now:
		var chest := tp + Vector3(0, _body_h(player), 0)
		var wanted := (chest - model.muzzle.global_position).normalized()
		aim_dir = aim_dir.lerp(wanted, minf(1.0, 10.0 * delta)).normalized()
	else:
		aim_dir = aim_dir.lerp(-Basis(Vector3.UP, yaw).z, minf(1.0, 6.0 * delta)).normalized()
	_shoot_cd -= delta
	if aiming and _shoot_cd <= 0.0:
		_shoot(dist)
		_shoot_cd = randf_range(1.0, 1.8)

	model.animate(delta, spd, _fwd_sign, 1.0 if aiming else 0.0, aim_dir)


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


func _has_los() -> bool:
	var from := global_position + Vector3(0, 1.4, 0)
	var to := player.global_position + Vector3(0, _body_h(player), 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _shoot(dist: float) -> void:
	var lead := player.global_position + Vector3(0, 1.2, 0) + player.velocity * (dist / 24.0) * 0.5
	var dir := (lead - model.muzzle.global_position).normalized()
	dir += Vector3(randf_range(-1, 1), randf_range(-0.6, 0.6), randf_range(-1, 1)) * 0.05
	var b := Bullet.create()
	get_parent().add_child(b)
	b.setup(Bullet.safe_origin(self, global_position + Vector3(0, 1.3, 0), model.muzzle.global_position), dir, 24.0, 9.0, Color(1.0, 0.65, 0.25), 1 | 2)
	model.fire_effect()
	Sfx.play_at(self, "enemy_shot", model.muzzle.global_position, -2.0)


func head_y() -> float:
	return global_position.y + 1.5


func stagger(v: Vector3) -> void:
	if dead:
		return
	velocity.x += v.x
	velocity.z += v.z


func take_damage(amount: float, _pos: Vector3 = Vector3.ZERO, _attacker: int = 0, impulse: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	hp -= amount
	if state != State.CHASE and player != null and not player.dead:
		_begin_search(player.global_position)
		_notice_t = NOTICE_TIME
	model.hit()
	Sfx.play_at(self, "hit", global_position + Vector3(0, 1.2, 0), 0.0)
	if hp <= 0.0:
		dead = true
		collision_layer = 0
		collision_mask = 1
		remove_from_group("enemies")
		var push := Vector3(0.0, 1.5, 0.0)
		if player != null:
			var away := global_position - player.global_position
			away.y = 0.0
			if away.length() > 0.01:
				push += away.normalized() * 3.5
		if impulse != Vector3.ZERO:
			push = impulse / 0.6
		model.die(push)
		Sfx.play_at(self, "die", global_position, 0.0)
		killed.emit(self)


func _body_h(n) -> float:
	var v = n.get("body_h")
	return float(v) if v != null else 1.2

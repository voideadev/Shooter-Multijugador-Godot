class_name Player
extends CharacterBody3D

signal died
signal fired
signal melee_started(id: String)
signal throw_started(id: String)
signal threw(id: String, origin: Vector3, vel: Vector3)

const WALK_SPEED := 3.0
const RUN_SPEED := 5.4
const CROUCH_SPEED := 1.5
const SPEED := RUN_SPEED
const ACCEL := 45.0
const AIR_ACCEL := 14.0
const GRAVITY := 28.0
const JUMP_VELOCITY := 8.4
const LOOK_SENS := 0.0042
const CAM_SMOOTH := 28.0
const FP_EYE_FWD := 0.1
const AIM_ASSIST_DEG := 0.0
const AIM_SMOOTH := 22.0

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.25
const PRONE_HEIGHT := 0.7
const PRONE_SPEED := 1.3
const PRONE_HOLD := 0.45
const EYE_HEIGHT_PRONE := 0.5
const TP_HEIGHT_PRONE := 0.8
const TP_HEIGHT := 1.45
const TP_HEIGHT_CROUCH := 1.1
const EYE_HEIGHT := 1.62
const EYE_HEIGHT_CROUCH := 1.35
const VAULT_REACH := 1.15
const VAULT_MIN := 0.55
const VAULT_MAX := 1.5
const SLOT_MELEE := 2
const SLOT_THROW := 3
const TP_FOV := 70.0
const FP_FOV := 84.0

var controls: Controls
var fid := 1
var god := false
var last_attacker := 0
var last_noise := -10.0
var team := -1
var net: Node = null
var max_hp := 100.0
var hp := 100.0
var dead := false
var yaw := 0.0
var pitch := -0.12
var model: Humanoid
var aim_dir := Vector3.FORWARD
var first_person := false
var slots: Array = []
var slot := 0
var _last_gun := 0
var weapon: Dictionary = Weapons.LIST[Weapons.DEFAULT]
var mags := {}
var reloading := false
var ammo := {}

var _pivot: Node3D
var _arm: SpringArm3D
var _cam: Camera3D
var _col: CollisionShape3D
var _shape: CapsuleShape3D
var _cooldown := 0.0
var _reload_t := 0.0
var _reload_dur := 1.0
var _fire_buf := 0.0
var _hold_t := 0.0
var _traj: MeshInstance3D
var _traj_mesh: ImmediateMesh
var _fire_prev := false
var _jump_buf := 0.0
var death_impulse := Vector3.ZERO
var _vault_t := -1.0
var _vault_dur := 0.7
var _vault_p0 := Vector3.ZERO
var _vault_c := Vector3.ZERO
var _vault_p2 := Vector3.ZERO
var _vault_dir := Vector3.FORWARD
var _vault_mask := 1 | 4
var _air_time := 0.0
var _crouch := 0.0
var _crouch_vis := 0.0
var _prone := 0.0
var _prone_vis := 0.0
var _prone_hold := 0.0
var _prone_lock := false
var body_h := 1.2
var _view_t := 0.0
var _kick := 0.0
var _rec_pend := Vector2.ZERO
var _rec_total := 0.0
var _last_shot := -10.0
var _burst := 0
var _burst_bias := 0.0
var _fwd_sign := 1.0
var _anim_speed := 0.0
var _run_fx := 0.0
var _anim_aim_t := 1.0
var _ads_t := 0.0
var _cyaw := 0.0
var _cpitch := -0.12
var _aim_s := Vector3.FORWARD
var _eye_fp := Vector3.ZERO
var _aim_point := Vector3.ZERO
var _pend_t := -1.0
var _pend_kind := ""
var _quick_state := 0
var _quick_prev := -1


static func create() -> Player:
	return load("res://scenes/characters/player.tscn").instantiate() as Player


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4

	_col = $Collision
	_shape = _col.shape.duplicate() as CapsuleShape3D
	_col.shape = _shape
	model = $Model
	var sd := Loadout.suit_def()
	var suit_c: Color = sd["suit"]
	var armor_c: Color = sd["armor"]
	var accent_c := Color(1.0, 0.7, 0.25)
	if team >= 0:
		suit_c = Teams.suit(team)
		armor_c = Teams.armor(team)
		accent_c = Teams.color(team)
	model.build(suit_c, armor_c, accent_c, 0, Color(0.86, 0.66, 0.52), Color(0.13, 0.09, 0.07), Loadout.character)
	model.max_speed = SPEED
	model.global_position = global_position
	_pivot = $CameraPivot
	_pivot.global_position = global_position + Vector3(0, TP_HEIGHT, 0)
	_arm = $CameraPivot/SpringArm
	_arm.add_excluded_object(get_rid())
	_cam = $CameraPivot/SpringArm/Camera

	var gi := Loadout.slots()
	slots = [Weapons.LIST[gi[0]], Weapons.LIST[gi[1]], Loadout.melee_def(), Loadout.throw_def()]
	slot = 0
	for d in slots:
		if d.has("ammo"):
			ammo[d["id"]] = int(d["ammo"])
		if d.has("mag"):
			mags[d["id"]] = int(d["mag"])
	_apply_weapon()


func apply_loadout() -> void:
	var gi := Loadout.slots()
	slots = [Weapons.LIST[gi[0]], Weapons.LIST[gi[1]], Loadout.melee_def(), Loadout.throw_def()]
	ammo.clear()
	mags.clear()
	for d in slots:
		if d.has("ammo"):
			ammo[d["id"]] = int(d["ammo"])
		if d.has("mag"):
			mags[d["id"]] = int(d["mag"])
	_cancel_reload()
	_quick_state = 0
	_quick_prev = -1
	_pend_t = -1.0
	_pend_kind = ""
	_last_gun = 0
	slot = 0
	_apply_weapon()
	_cooldown = maxf(_cooldown, 0.3)


func _weapon_kind() -> String:
	return String(weapon.get("kind", "gun"))


func _apply_weapon() -> void:
	weapon = slots[slot]
	model.equip(weapon)
	if _weapon_kind() != "gun":
		controls.ads_on = false
	_update_hud_weapon()


func _update_hud_weapon() -> void:
	var nm: String = weapon["name"]
	if weapon.has("ammo"):
		nm += " x%d" % int(ammo.get(weapon["id"], 0))
	if weapon.has("mag"):
		controls.ammo_text = "%d / %d" % [int(mags.get(weapon["id"], 0)), int(weapon["mag"])]
	else:
		controls.ammo_text = ""
		controls.reload_ratio = -1.0
	controls.weapon_name = nm
	controls.weapon_index = slot
	controls.weapon_count = slots.size()
	var g: Dictionary = slots[_last_gun]
	controls.holding = _weapon_kind()
	controls.gun_id = String(g["id"])
	controls.gun_name = String(g["name"])
	controls.gun_ammo = "%d / %d" % [int(mags.get(g["id"], 0)), int(g["mag"])]
	controls.melee_id = String(slots[SLOT_MELEE]["id"])
	var td: Dictionary = slots[SLOT_THROW]
	controls.throw_id = String(td["id"])
	controls.throw_count = int(ammo.get(td["id"], 0))


func select_weapon(i: int, draw: float = 0.3, quick: bool = false) -> void:
	i = posmod(i, slots.size())
	if i == slot or dead:
		return
	if not quick:
		_quick_state = 0
		_quick_prev = -1
	_cancel_reload()
	_hold_t = 0.0
	_hide_traj()
	_pend_t = -1.0
	_pend_kind = ""
	slot = i
	if i <= 1:
		_last_gun = i
	_apply_weapon()
	_cooldown = maxf(_cooldown, draw)
	_fire_buf = 0.0
	Sfx.play_at(self, "swap", global_position + Vector3(0, 1.2, 0), -6.0)


func tap_weapon() -> void:
	if dead:
		return
	if slot <= 1:
		select_weapon(1 - slot)
	else:
		select_weapon(_last_gun)


func tap_throw() -> void:
	if dead:
		return
	select_weapon(SLOT_THROW)


func _process(delta: float) -> void:
	if not dead:
		var look := controls.consume_look()
		var kb := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		var sens := clampf(_cam.fov / FP_FOV, 0.3, 1.0)
		yaw -= (look.x * LOOK_SENS + kb.x * 2.4 * delta) * sens
		var pmin := lerpf(-0.85, -1.35, _view_t)
		var pmax := lerpf(0.5, 1.25, _view_t)
		pitch = clampf(pitch - (look.y * LOOK_SENS + kb.y * 1.6 * delta) * sens, pmin, pmax)
		_handle_buttons()

		var rp := _rec_pend * (1.0 - exp(-40.0 * delta))
		_rec_pend -= rp
		yaw += rp.x
		pitch = clampf(pitch + rp.y, pmin, pmax)
		_rec_total += rp.y
		if Time.get_ticks_msec() / 1000.0 - _last_shot > 0.12:
			var back := _rec_total * (1.0 - exp(-5.0 * delta))
			_rec_total -= back
			pitch -= back * 0.6

	var ks := 1.0 - exp(-CAM_SMOOTH * delta)
	_cyaw = lerp_angle(_cyaw, yaw, ks)
	_cpitch = lerpf(_cpitch, pitch, ks)
	_aim_s = _aim_s.slerp(aim_dir, 1.0 - exp(-AIM_SMOOTH * delta)).normalized()

	_view_t = move_toward(_view_t, 1.0 if first_person else 0.0, delta * 5.0)
	var e := smoothstep(0.0, 1.0, _view_t)
	_crouch_vis = lerpf(_crouch_vis, _crouch, 1.0 - exp(-24.0 * delta))
	_prone_vis = lerpf(_prone_vis, _prone, 1.0 - exp(-12.0 * delta))
	_kick *= exp(-9.0 * delta)

	if controls.ads_on and not first_person and not dead and _weapon_kind() == "gun":
		first_person = true
		controls.first_person = true
	var want_ads := first_person and not dead and not reloading and _weapon_kind() == "gun" and (controls.ads_on or Input.is_action_pressed("aim"))
	_ads_t = move_toward(_ads_t, 1.0 if want_ads else 0.0, delta * 7.0)
	var adsb := smoothstep(0.0, 1.0, _ads_t)
	controls.ads_amount = adsb
	controls.scope = adsb if bool(weapon.get("scope", weapon["id"] == "sniper")) else 0.0
	model.ads = 1.0 if want_ads else 0.0

	var base := get_global_transform_interpolated().origin
	model.global_position = base
	model.rotation.y = lerp_angle(model.rotation.y, yaw, minf(1.0, (40.0 if first_person else 14.0) * delta))

	var eye_h := lerpf(lerpf(EYE_HEIGHT, EYE_HEIGHT_CROUCH, _crouch_vis), EYE_HEIGHT_PRONE, _prone_vis) - model.land_dip()
	_eye_fp = base + Vector3(0.0, eye_h, 0.0) + Basis(Vector3.UP, _cyaw) * Vector3(0.0, 0.0, -FP_EYE_FWD)
	model.cam_xf = Transform3D(Basis.from_euler(Vector3(_cpitch + _kick, _cyaw, 0.0)), _eye_fp)
	model.animate(delta, _anim_speed, _fwd_sign, _anim_aim_t, _aim_s)

	_pivot.rotation = Vector3(_cpitch + _kick, _cyaw, 0.0)
	var h_tp := lerpf(lerpf(TP_HEIGHT, TP_HEIGHT_CROUCH, _crouch_vis), TP_HEIGHT_PRONE, _prone_vis)
	_pivot.global_position = (base + Vector3(0.0, h_tp, 0.0)).lerp(_eye_fp, e)

	_arm.spring_length = lerpf(4.2, 0.0, e)
	_arm.position = Vector3(lerpf(0.75, 0.0, e), lerpf(0.15, 0.0, e), 0.0)
	_arm.collision_mask = 1 if e < 0.5 else 0
	_cam.fov = lerpf(lerpf(TP_FOV, FP_FOV, e), float(weapon.get("ads_fov", FP_FOV)), adsb)
	_run_fx = lerpf(_run_fx, clampf((_anim_speed - 3.2) / 2.6, 0.0, 1.0), minf(1.0, 6.0 * get_process_delta_time()))
	_cam.fov += 7.0 * _run_fx * (1.0 - adsb)
	model.set_first_person(e > 0.5)


func _handle_buttons() -> void:
	if controls.consume_view() or Input.is_action_just_pressed("toggle_view"):
		first_person = not first_person
		controls.first_person = first_person
		if not first_person:
			controls.ads_on = false
	var q := controls.consume_quick()
	if Input.is_action_just_pressed("quick_melee"):
		q = "melee"
	if Input.is_action_just_pressed("quick_throw"):
		q = "throw"
	if q != "":
		quick_use(q)
	if controls.consume_reload() or (InputMap.has_action("reload") and Input.is_action_just_pressed("reload")):
		start_reload()
	if controls.consume_weapon_tap() or Input.is_action_just_pressed("weapon_next") or Input.is_action_just_pressed("weapon_prev"):
		tap_weapon()
	if controls.consume_throw_tap():
		tap_throw()
	for n in slots.size():
		if Input.is_action_just_pressed("weapon_%d" % (n + 1)):
			select_weapon(n)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	_fire_buf = maxf(0.0, _fire_buf - delta)
	_jump_buf = maxf(0.0, _jump_buf - delta)

	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		model.crouch = 0.0
		model.prone = 0.0
		model.airborne = false
		_anim_speed = 0.0
		_anim_aim_t = 0.0
		return

	if _vault_t >= 0.0:
		_vault_step(delta)
		return

	var on_floor := is_on_floor()
	_air_time = 0.0 if on_floor else _air_time + delta

	if Input.is_action_just_pressed("crouch"):
		_prone_hold = 0.0
		if controls.prone_on:
			controls.prone_on = false
			_prone_lock = true
	if Input.is_action_pressed("crouch"):
		if not _prone_lock:
			_prone_hold += delta
			if _prone_hold >= PRONE_HOLD:
				controls.prone_on = true
				controls.crouch_on = false
	else:
		_prone_hold = 0.0
		_prone_lock = false
	var mv0 := controls.move_vector
	if mv0.length() > 0.05 and controls.sprint and (controls.crouch_on or controls.prone_on):
		controls.crouch_on = false
		controls.prone_on = false
	var want_prone := controls.prone_on
	if not want_prone and _prone > 0.0 and _blocked_between(PRONE_HEIGHT - 0.1, CROUCH_HEIGHT + 0.05):
		want_prone = true
	var want_crouch := (controls.crouch_on or Input.is_action_pressed("crouch")) and not want_prone
	if not want_crouch and not want_prone and _crouch > 0.0 and _blocked_above():
		want_crouch = true
	_prone = move_toward(_prone, 1.0 if want_prone else 0.0, 4.0 * delta)
	_crouch = move_toward(_crouch, 1.0 if want_crouch else 0.0, 6.0 * delta)
	body_h = lerpf(lerpf(1.2, 0.95, _crouch), 0.4, _prone)
	var h := lerpf(lerpf(STAND_HEIGHT, CROUCH_HEIGHT, _crouch), PRONE_HEIGHT, _prone)
	if not is_equal_approx(_shape.height, h):
		_shape.height = h
		_col.position.y = h * 0.5

	if controls.consume_jump() or Input.is_action_just_pressed("jump"):
		_jump_buf = 0.12
	if _jump_buf > 0.0 and on_floor and (controls.prone_on or _prone > 0.3):
		controls.prone_on = false
		controls.crouch_on = false
		_prone_lock = true
		_jump_buf = 0.0
	if _jump_buf > 0.0 and on_floor:
		if _try_vault():
			_jump_buf = 0.0
			return
		velocity.y = JUMP_VELOCITY
		_jump_buf = 0.0
		controls.crouch_on = false
		on_floor = false

	var mv := controls.move_vector
	if mv.length() < 0.05:
		mv = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	mv = mv.limit_length(1.0)
	var kb_only := controls.move_vector.length() < 0.05

	var yaw_basis := Basis(Vector3.UP, yaw)
	var dir := yaw_basis * Vector3(mv.x, 0.0, mv.y)
	var crouched := _crouch > 0.5
	var proned := _prone > 0.5
	var run := false
	if not crouched and not proned and mv.length() > 0.05:
		if kb_only:
			run = mv.length() > 0.8 and not Input.is_action_pressed("walk")
		else:
			run = controls.sprint
	var top := WALK_SPEED * minf(1.0, mv.length() / 0.8)
	if proned:
		top = PRONE_SPEED * minf(1.0, mv.length() / 0.8)
	elif crouched:
		top = CROUCH_SPEED * minf(1.0, mv.length() / 0.8)
	elif run:
		top = RUN_SPEED
	top *= lerpf(1.0, 0.6, _ads_t)
	var target := dir.normalized() * top if mv.length() > 0.01 else Vector3.ZERO
	var acc := ACCEL if on_floor else AIR_ACCEL
	velocity.x = move_toward(velocity.x, target.x, acc * delta)
	velocity.z = move_toward(velocity.z, target.z, acc * delta)
	if on_floor:
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	var spd := Vector2(velocity.x, velocity.z).length()
	if spd > 0.5:
		var fwd := -yaw_basis.z
		_fwd_sign = -1.0 if velocity.dot(fwd) < -0.45 * spd else 1.0

	if _pend_t >= 0.0:
		_pend_t -= delta
		if _pend_t < 0.0:
			_pend_t = -1.0
			var pend := _pend_kind
			_pend_kind = ""
			if pend == "melee":
				_melee_hit()
			elif pend == "throw":
				_throw_release()

	if _quick_state == 1 and _cooldown <= 0.0:
		_fire_buf = 0.18
	elif _quick_state == 2 and _cooldown <= 0.0 and _pend_t < 0.0:
		var back := _quick_prev
		_quick_state = 0
		_quick_prev = -1
		if back >= 0:
			select_weapon(back, 0.2, true)

	_update_reload(delta)
	_compute_aim()
	var trigger := controls.firing or Input.is_action_pressed("fire")
	if trigger and not _fire_prev:
		_fire_buf = 0.18
	_fire_prev = trigger
	if _weapon_kind() == "throw":
		_throw_aim(trigger, delta)
	else:
		_hold_t = 0.0
		_hide_traj()
		if _cooldown <= 0.0 and not reloading:
			if (trigger and bool(weapon.get("auto", false))) or _fire_buf > 0.0:
				match _weapon_kind():
					"melee":
						_melee_start()
					_:
						if int(mags.get(weapon["id"], 0)) <= 0:
							start_reload()
						else:
							_shoot()
				_fire_buf = 0.0

	_anim_speed = spd
	_anim_aim_t = 0.3 if (spd > 3.4 and not trigger and not first_person) else 1.0
	model.crouch = _crouch
	model.prone = _prone
	model.airborne = _air_time > 0.1
	model.vspeed = velocity.y


func _try_vault() -> bool:
	if _vault_t >= 0.0 or dead:
		return false
	var mv := controls.move_vector
	if mv.length() < 0.05:
		mv = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yb := Basis(Vector3.UP, yaw)
	var dir := -yb.z
	if mv.length() > 0.05:
		dir = yb * Vector3(mv.x, 0.0, mv.y)
	dir.y = 0.0
	if dir.length() < 0.01:
		return false
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP).normalized()
	for off in [0.0, 0.3, -0.3, 0.6, -0.6]:
		var plan := _vault_probe(dir, side * float(off))
		if not plan.is_empty():
			_start_vault(plan)
			return true
	return false


func _vault_probe(dir: Vector3, shift: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var base := global_position
	var knee := base + shift + Vector3(0.0, 0.45, 0.0)
	var h1 := space.intersect_ray(PhysicsRayQueryParameters3D.create(knee, knee + dir * VAULT_REACH, 1))
	if h1.is_empty():
		return {}
	var n: Vector3 = h1["normal"]
	n.y = 0.0
	if n.length() < 0.1:
		return {}
	n = n.normalized()
	if dir.dot(-n) < 0.55:
		return {}
	var into := -n
	var wall_p: Vector3 = h1["position"]
	var top_from := wall_p + into * 0.15
	top_from.y = base.y + VAULT_MAX + 0.1
	var top_to := top_from
	top_to.y = base.y + 0.2
	var h2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(top_from, top_to, 1))
	if h2.is_empty():
		return {}
	var top_y: float = (h2["position"] as Vector3).y
	var rise := top_y - base.y
	if rise < VAULT_MIN or rise > VAULT_MAX:
		return {}
	var lowp := Vector3(wall_p.x, top_y - 0.3, wall_p.z)
	var h3 := space.intersect_ray(PhysicsRayQueryParameters3D.create(lowp + into * 1.5, lowp + into * 0.02, 1))
	var thick := 0.45
	if not h3.is_empty():
		thick = clampf(((h3["position"] as Vector3) - lowp).dot(into), 0.1, 1.4)
	for dy in [0.15, 0.8]:
		var y := top_y + float(dy)
		var a := Vector3(wall_p.x, y, wall_p.z) - into * 0.25
		var b := Vector3(wall_p.x, y, wall_p.z) + into * (thick + 0.5)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1)).is_empty():
			return {}
	var mid := wall_p + into * (thick * 0.5)
	var side := into.cross(Vector3.UP).normalized()
	var gp := Vector3(mid.x, top_y + 0.4, mid.z)
	var hl := space.intersect_ray(PhysicsRayQueryParameters3D.create(gp, gp + side * 1.5, 1))
	var hr := space.intersect_ray(PhysicsRayQueryParameters3D.create(gp, gp - side * 1.5, 1))
	if not hl.is_empty() and not hr.is_empty():
		var dl := gp.distance_to(hl["position"])
		var dr := gp.distance_to(hr["position"])
		mid += side * ((dl - dr) * 0.5)
	var land := mid + into * (thick * 0.5 + 0.6)
	var fl := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(land.x, top_y + 0.9, land.z), Vector3(land.x, base.y - 4.0, land.z), 1))
	if fl.is_empty():
		return {}
	land.y = (fl["position"] as Vector3).y + 0.03
	var over := Vector3(mid.x, top_y + 0.02, mid.z)
	return {"p0": base, "m": over, "p2": land, "dir": into}


func _start_vault(plan: Dictionary) -> void:
	_vault_p0 = plan["p0"]
	var m: Vector3 = plan["m"]
	_vault_p2 = plan["p2"]
	_vault_dir = plan["dir"]
	_vault_c = m * 2.0 - (_vault_p0 + _vault_p2) * 0.5
	_vault_dur = clampf(_vault_p0.distance_to(_vault_p2) / 3.4, 0.55, 0.9)
	_vault_t = 0.0
	_vault_mask = collision_mask
	collision_mask = 0
	_shape.height = CROUCH_HEIGHT
	_col.position.y = CROUCH_HEIGHT * 0.5
	controls.crouch_on = false
	controls.prone_on = false
	_prone = 0.0
	_cancel_reload()
	Sfx.play_at(self, "swing", global_position + Vector3(0, 1.0, 0), -6.0)


func _vault_step(delta: float) -> void:
	_vault_t += delta / _vault_dur
	var t := clampf(_vault_t, 0.0, 1.0)
	var u := 1.0 - t
	global_position = _vault_p0 * (u * u) + _vault_c * (2.0 * u * t) + _vault_p2 * (t * t)
	velocity = Vector3.ZERO
	_air_time = 0.0
	_crouch = 1.0
	model.crouch = 1.0
	model.airborne = false
	model.vspeed = 0.0
	_anim_speed = 2.2
	_anim_aim_t = 0.3
	_compute_aim()
	if _vault_t >= 1.0:
		_vault_t = -1.0
		collision_mask = _vault_mask
		velocity = _vault_dir * 1.5


func _blocked_between(y0: float, y1: float) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, y0, 0.0)
	var to := global_position + Vector3(0.0, y1, 0.0)
	return not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty()


func _blocked_above() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, CROUCH_HEIGHT - 0.1, 0.0)
	var to := global_position + Vector3(0.0, STAND_HEIGHT + 0.05, 0.0)
	return not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty()


func _compute_aim() -> void:
	var space := get_world_3d().direct_space_state
	var origin := _cam.global_position
	var fwd := -_cam.global_basis.z
	var point := origin + fwd * 80.0
	var q := PhysicsRayQueryParameters3D.create(origin, origin + fwd * 80.0, 1 | 4)
	var r := space.intersect_ray(q)
	if not r.is_empty():
		point = r["position"]

	var best := deg_to_rad(AIM_ASSIST_DEG)
	for e in get_tree().get_nodes_in_group("enemies"):
		var c: Vector3 = e.global_position + Vector3(0, 1.25, 0)
		var to := c - origin
		var d := to.length()
		if d > 45.0 or d < 1.0:
			continue
		var ang := fwd.angle_to(to)
		if ang < best:
			var lq := PhysicsRayQueryParameters3D.create(origin, c, 1)
			if space.intersect_ray(lq).is_empty():
				best = ang
				point = c

	_aim_point = point
	var m := model.muzzle.global_position
	var dv := point - m
	if dv.length() < 1.5 or dv.normalized().dot(fwd) < 0.6:
		aim_dir = fwd
	else:
		aim_dir = dv.normalized()


func _shoot() -> void:
	var rate: float = weapon["rate"]
	var pellets: int = weapon["pellets"]
	var spread: float = weapon["spread"]
	var speed: float = weapon["speed"]
	var dmg: float = weapon["damage"]
	var rng: float = weapon["range"]
	var col: Color = weapon["color"]
	var tracer: float = weapon["tracer"]
	var vol: float = weapon["vol"]
	var sfx_name: String = weapon["sfx"]
	var recoil: float = weapon["recoil"]
	var kick: float = weapon["kick"]
	var rec_up: float = weapon["rec_up"]
	var rec_side: float = weapon["rec_side"]

	_cooldown = rate
	mags[weapon["id"]] = maxi(0, int(mags.get(weapon["id"], 0)) - 1)
	var spread_mul := lerpf(1.0, 0.55, maxf(_crouch, _prone)) * lerpf(1.0, 0.35, _ads_t)
	if _air_time > 0.1:
		spread_mul *= 2.0
	var origin := Bullet.safe_origin(self, global_position + Vector3(0.0, lerpf(lerpf(1.3, 0.95, _crouch), 0.45, _prone), 0.0), model.muzzle.global_position)
	var blast: float = float(weapon.get("blast", 0.0))
	var grav: float = float(weapon.get("grav", 0.0))
	var base_dir := aim_dir
	if grav > 0.0:
		var dist := minf(origin.distance_to(_aim_point), rng)
		var tt := dist / speed
		base_dir = (aim_dir * dist + Vector3.UP * (0.5 * grav * tt * tt)).normalized()
	last_noise = Time.get_ticks_msec() / 1000.0
	for i in pellets:
		var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spread * spread_mul
		var b := Bullet.create()
		get_parent().add_child(b)
		b.setup(origin, base_dir + jitter, speed, dmg, col, 1 | 4, rng / speed, tracer)
		b.attacker = fid
		b.blast = blast
		b.grav = grav
	model.fire_effect(recoil)
	_kick = minf(_kick + kick, 0.14)

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_shot > rate * 1.8 + 0.12:
		_burst = 0
		_burst_bias = randf_range(-1.0, 1.0)
	_last_shot = now
	var rmul := lerpf(1.0, 0.7, maxf(_crouch, _prone)) * lerpf(1.0, 0.6, _ads_t)
	if _air_time > 0.1:
		rmul *= 1.3
	rmul *= 1.0 + minf(float(_burst), 8.0) * 0.05
	_burst += 1
	_rec_pend += Vector2((_burst_bias * 0.5 + randf_range(-0.5, 0.5)) * rec_side, rec_up) * rmul
	Sfx.play_at(self, sfx_name, origin, vol)
	fired.emit()
	_update_hud_weapon()
	if int(mags.get(weapon["id"], 0)) <= 0:
		start_reload()


func start_reload() -> void:
	if dead or reloading or _weapon_kind() != "gun":
		return
	if int(mags.get(weapon["id"], 0)) >= int(weapon["mag"]):
		return
	reloading = true
	_reload_dur = float(weapon["reload"])
	_reload_t = 0.0
	_fire_buf = 0.0
	controls.ads_on = false
	Sfx.play_at(self, "swap", global_position + Vector3(0, 1.2, 0), -2.0)


func _update_reload(delta: float) -> void:
	if not reloading:
		return
	_reload_t += delta
	var p := clampf(_reload_t / _reload_dur, 0.0, 1.0)
	model.reload_p = p
	controls.reload_ratio = p
	if _reload_t >= _reload_dur:
		mags[weapon["id"]] = int(weapon["mag"])
		_cancel_reload()
		_cooldown = maxf(_cooldown, 0.12)
		Sfx.play_at(self, "swap", global_position + Vector3(0, 1.2, 0), -4.0)
		_update_hud_weapon()


func _cancel_reload() -> void:
	reloading = false
	_reload_t = 0.0
	if model != null:
		model.reload_p = -1.0
	if controls != null:
		controls.reload_ratio = -1.0


func head_y() -> float:
	return global_position.y + _shape.height - 0.3


func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + amount)
	controls.heal_flash = 1.0


func quick_use(kind: String) -> void:
	if dead or _quick_state != 0:
		return
	var target := SLOT_MELEE if kind == "melee" else SLOT_THROW
	if slot == target:
		_fire_buf = 0.18
		return
	_quick_prev = slot
	_quick_state = 1
	select_weapon(target, 0.14, true)


func _melee_start() -> void:
	if _quick_state == 1:
		_quick_state = 2
	_cooldown = float(weapon["rate"])
	_pend_kind = "melee"
	_pend_t = float(weapon["hit_t"])
	model.attack(weapon)
	melee_started.emit(String(weapon["id"]))
	Sfx.play_at(self, "swing", global_position + Vector3(0, 1.3, 0), -4.0)


func _melee_hit() -> void:
	var reach: float = weapon["reach"]
	var arc := deg_to_rad(float(weapon["arc"]))
	var dmg: float = weapon["damage"]
	var max_hits: int = int(weapon["max_hits"])
	var knock: float = weapon["knock"]
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0.0, 1.3, 0.0)
	var fwd := -Basis.from_euler(Vector3(pitch, yaw, 0.0)).z
	var cands: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		var c: Vector3 = e.global_position + Vector3(0.0, 1.0, 0.0)
		var to := c - origin
		var d := to.length()
		if d > reach + 0.4 or d < 0.01:
			continue
		var ang := fwd.angle_to(to)
		if ang > arc:
			continue
		var lq := PhysicsRayQueryParameters3D.create(origin, c, 1)
		if not space.intersect_ray(lq).is_empty():
			continue
		cands.append([ang, e])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var hits := 0
	for cd in cands:
		if hits >= max_hits:
			break
		var en = cd[1]
		var c2: Vector3 = en.global_position + Vector3(0.0, 1.0, 0.0)
		var flat := c2 - origin
		flat.y = 0.0
		en.take_damage(dmg, c2, fid)
		if en.has_method("stagger") and flat.length() > 0.01:
			en.stagger(flat.normalized() * knock)
		Bullet.spark(get_parent(), c2, Color(0.9, 0.2, 0.15))
		hits += 1
	if hits > 0:
		_kick = minf(_kick + 0.03, 0.14)
	else:
		var wq := PhysicsRayQueryParameters3D.create(origin, origin + fwd * reach, 1)
		var wh := space.intersect_ray(wq)
		if not wh.is_empty():
			Bullet.spark(get_parent(), wh["position"], Color(0.75, 0.65, 0.48))
			Sfx.play_at(self, "tink", wh["position"], -4.0)


func _throw_aim(trigger: bool, delta: float) -> void:
	if dead:
		_hold_t = 0.0
		_hide_traj()
		return
	if _quick_state == 1 and _cooldown <= 0.0 and _fire_buf > 0.0:
		_fire_buf = 0.0
		_throw_start()
		return
	if trigger:
		_hold_t += delta
		if _hold_t > 0.22 and int(ammo.get(weapon["id"], 0)) > 0:
			_show_traj()
		return
	_hide_traj()
	if _hold_t > 0.0:
		_hold_t = 0.0
		_fire_buf = 0.0
		if _cooldown <= 0.0:
			_throw_start()


func _hide_traj() -> void:
	if _traj != null:
		_traj.visible = false


func _show_traj() -> void:
	if _traj == null:
		_traj_mesh = ImmediateMesh.new()
		_traj = MeshInstance3D.new()
		_traj.mesh = _traj_mesh
		_traj.top_level = true
		_traj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1, 0.9)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_traj.material_override = m
		add_child(_traj)
	_traj.global_transform = Transform3D.IDENTITY
	_traj.visible = true
	var origin := model.muzzle.global_position
	var v := _throw_velocity(origin)
	var g := float(weapon["grav"])
	var space := get_world_3d().direct_space_state
	var p := origin
	var pts: Array = [origin]
	for i in 70:
		v.y -= g * 0.04
		var np := p + v * 0.04
		var q := PhysicsRayQueryParameters3D.create(p, np, 1 | 4)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			pts.append(hit["position"])
			break
		pts.append(np)
		p = np
	_traj_mesh.clear_surfaces()
	_traj_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for pt in pts:
		_traj_mesh.surface_add_vertex(pt as Vector3)
	_traj_mesh.surface_end()


func _throw_start() -> void:
	if _quick_state == 1:
		_quick_state = 2
	var id: String = weapon["id"]
	if int(ammo.get(id, 0)) <= 0:
		_cooldown = 0.35
		Sfx.play_at(self, "swap", global_position + Vector3(0, 1.2, 0), -8.0)
		return
	_cooldown = float(weapon["rate"])
	_pend_kind = "throw"
	_pend_t = float(weapon["release_t"])
	model.attack(weapon)
	throw_started.emit(String(weapon["id"]))
	Sfx.play_at(self, "pin", global_position + Vector3(0, 1.3, 0), -6.0)


func _throw_release() -> void:
	var id: String = weapon["id"]
	if int(ammo.get(id, 0)) <= 0:
		return
	ammo[id] = int(ammo[id]) - 1
	_update_hud_weapon()
	var origin := model.muzzle.global_position
	var t := Thrown.create()
	get_parent().add_child(t)
	var tvel := _throw_velocity(origin)
	t.attacker = fid
	t.setup(weapon, origin, tvel)
	threw.emit(id, origin, tvel)
	Sfx.play_at(self, "throw", origin, -3.0)


func _throw_velocity(origin: Vector3) -> Vector3:
	var s: float = weapon["throw_speed"]
	var g: float = weapon["grav"]
	var d := _aim_point - origin
	var hd := Vector3(d.x, 0.0, d.z)
	var dh := hd.length()
	if dh < 0.8:
		return aim_dir * s * 0.5
	hd /= dh
	var s2 := s * s
	var disc := s2 * s2 - g * (g * dh * dh + 2.0 * d.y * s2)
	var th := PI * 0.25
	if disc >= 0.0:
		th = atan2(s2 - sqrt(disc), g * dh)
	return (hd * cos(th) + Vector3.UP * sin(th)) * s


func restock() -> void:
	for d in slots:
		if d.has("ammo"):
			var id: String = d["id"]
			ammo[id] = mini(int(d["ammo"]), int(ammo.get(id, 0)) + int(d.get("refill", 1)))
		if d.has("mag"):
			mags[d["id"]] = int(d["mag"])
	_cancel_reload()
	_update_hud_weapon()


func shake(amount: float) -> void:
	_kick = minf(_kick + amount, 0.14)


func take_damage(amount: float, _pos: Vector3 = Vector3.ZERO, attacker: int = 0, impulse: Vector3 = Vector3.ZERO) -> void:
	if dead or god:
		return
	if net != null and net.is_friendly(attacker, fid):
		return
	if attacker != 0:
		last_attacker = attacker
	hp = maxf(0.0, hp - amount)
	model.hit()
	controls.damage_flash = 1.0
	Sfx.play_at(self, "hurt", global_position, 0.0)
	if hp <= 0.0:
		dead = true
		_cancel_reload()
		_pend_t = -1.0
		_pend_kind = ""
		_quick_state = 0
		first_person = false
		controls.ads_on = false
		controls.first_person = false
		death_impulse = impulse
		if _vault_t >= 0.0:
			_vault_t = -1.0
			collision_mask = _vault_mask
		model.die(impulse / 0.6 if impulse != Vector3.ZERO else Vector3.ZERO)
		Sfx.play_at(self, "die", global_position, 2.0)
		died.emit()

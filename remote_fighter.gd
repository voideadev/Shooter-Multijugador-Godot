class_name RemoteFighter
extends CharacterBody3D

var net: Node = null
var fid := 0
var team := -1
var owner_peer := 1
var display_name := ""
var suit_idx := 0
var character_idx := 0
var dead := false
var god := false
var model: Humanoid
var weapon_id := ""

var target_pos := Vector3.ZERO
var target_yaw := 0.0
var aim_dir := Vector3.FORWARD
var anim_speed := 0.0
var anim_aim := 1.0
var crouch := 0.0
var prone := 0.0
var body_h := 1.2
var air := false
var vspeed := 0.0
var net_vel := Vector3.ZERO
var _since := 0.0

var _aim_s := Vector3.FORWARD
var _got := false
var _tag: Label3D
var _model_used := false
var last_noise := -10.0


static func create() -> RemoteFighter:
	return load("res://scenes/characters/remote_fighter.tscn").instantiate() as RemoteFighter


static func def_by_id(id: String) -> Dictionary:
	for list in [Weapons.LIST, Weapons.MELEE, Weapons.THROW]:
		for d in list:
			if d["id"] == id:
				return d
	return Weapons.LIST[Weapons.DEFAULT]


func _ready() -> void:
	($Collision as CollisionShape3D).shape = ($Collision as CollisionShape3D).shape.duplicate()
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("enemies")
	add_to_group("fighters")
	collision_layer = 4
	collision_mask = 0

	_tag = $NameTag
	_tag.text = display_name
	_tag.modulate = Teams.color(team) if team >= 0 else Color(1.0, 0.85, 0.5)
	_build_model()


func _build_model() -> void:
	if _model_used:
		model.queue_free()
		model = Humanoid.create()
		add_child(model)
	else:
		model = $Model
		_model_used = true
	var sd: Dictionary = Loadout.SUITS[suit_idx % Loadout.SUITS.size()]
	var suit_c: Color = sd["suit"]
	var armor_c: Color = sd["armor"]
	var accent_c := Color(1.0, 0.7, 0.25)
	if team >= 0:
		suit_c = Teams.suit(team)
		armor_c = Teams.armor(team)
		accent_c = Teams.color(team)
	model.build(suit_c, armor_c, accent_c, 1 if fid < 0 else 0, Color(0.86, 0.66, 0.52), Color(0.13, 0.09, 0.07), character_idx % Loadout.CHARACTERS.size())
	model.max_speed = 5.4
	weapon_id = ""


func _update_tag_visibility() -> void:
	if _tag == null:
		return
	var show_tag := not dead
	if show_tag and net != null and net.game_mode == "teams":
		show_tag = team >= 0 and team == net.my_team
	_tag.visible = show_tag


func set_team(t: int) -> void:
	if t == team:
		return
	team = t
	if _tag != null:
		_tag.modulate = Teams.color(team) if team >= 0 else Color(1.0, 0.85, 0.5)
	if is_inside_tree() and not dead:
		_build_model()


func set_info(p_name: String, p_suit: int, p_char: int = 0) -> void:
	display_name = p_name
	if _tag != null:
		_tag.text = p_name
	if p_suit != suit_idx or p_char != character_idx:
		suit_idx = p_suit
		character_idx = p_char
		if is_inside_tree() and not dead:
			_build_model()


func _equip(wid: String) -> void:
	weapon_id = wid
	model.reload_p = -1.0
	model.equip(def_by_id(wid))


func apply_state(s: Array) -> void:
	target_pos = s[0]
	net_vel = s[10] if s.size() > 10 else Vector3.ZERO
	_since = 0.0
	target_yaw = float(s[1])
	aim_dir = (s[2] as Vector3).normalized()
	anim_speed = float(s[3])
	anim_aim = float(s[4])
	crouch = float(s[5])
	prone = float(s[13]) if s.size() > 13 else 0.0
	air = bool(s[6])
	vspeed = float(s[7])
	var d := bool(s[9])
	if d and not dead:
		dead = true
		collision_layer = 0
		remove_from_group("enemies")
		var push := Vector3(0.0, 1.5, 0.0)
		if s.size() > 12 and (s[12] as Vector3) != Vector3.ZERO:
			push = (s[12] as Vector3) / 0.6
		model.die(push)
		if _tag != null:
			_tag.visible = false
	elif not d and dead:
		dead = false
		collision_layer = 4
		add_to_group("enemies")
		global_position = target_pos
		_build_model()
		_got = true
		if _tag != null:
			_tag.visible = true
	if not _got:
		_got = true
		global_position = target_pos
	var wid := String(s[8])
	if wid != weapon_id and not dead:
		_equip(wid)
	var rp := float(s[11]) if s.size() > 11 else -1.0
	if not dead and model != null:
		if rp < 0.0:
			model.reload_p = -1.0
		elif model.reload_p < 0.0:
			model.reload_p = rp
			Sfx.play_at(self, "swap", global_position + Vector3(0, 1.2, 0), -2.0)
		elif absf(model.reload_p - rp) > 0.12:
			model.reload_p = rp


func _process(delta: float) -> void:
	_update_tag_visibility()
	if not _got or model == null:
		return
	if dead:
		model.animate(delta, 0.0, 1.0, 0.0, _aim_s)
		return
	var old := global_position
	_since += delta
	if _since < 0.2:
		target_pos += Vector3(net_vel.x, 0.0, net_vel.z) * delta
	if old.distance_to(target_pos) > 6.0:
		global_position = target_pos
	else:
		global_position = old.lerp(target_pos, 1.0 - exp(-22.0 * delta))
	if delta > 0.0:
		velocity = velocity.lerp((global_position - old) / delta, 0.25)
	model.rotation.y = lerp_angle(model.rotation.y, target_yaw, minf(1.0, 14.0 * delta))
	model.crouch = crouch
	model.prone = prone
	body_h = lerpf(lerpf(1.2, 0.95, crouch), 0.4, prone)
	var ch := lerpf(lerpf(1.8, 1.25, crouch), 0.7, prone)
	var cs := $Collision as CollisionShape3D
	cs.position.y = ch * 0.5
	if not is_equal_approx((cs.shape as CapsuleShape3D).height, ch):
		(cs.shape as CapsuleShape3D).height = ch
	model.airborne = air
	model.vspeed = vspeed
	_aim_s = _aim_s.slerp(aim_dir, minf(1.0, 18.0 * delta)).normalized()
	if model.reload_p >= 0.0:
		var rd := float(def_by_id(weapon_id).get("reload", 1.5))
		model.reload_p = minf(model.reload_p + delta / maxf(rd, 0.1), 1.0)
	model.animate(delta, anim_speed, 1.0, anim_aim, _aim_s)


func on_event(kind: String, wid: String) -> void:
	if dead or model == null or model.muzzle == null:
		return
	var d := def_by_id(wid)
	if kind == "shot":
		var origin := model.muzzle.global_position
		model.fire_effect(float(d.get("recoil", 1.0)))
		var spd := float(d["speed"])
		last_noise = Time.get_ticks_msec() / 1000.0
		var grav := float(d.get("grav", 0.0))
		var vdir := aim_dir
		if grav > 0.0:
			var tt := 25.0 / spd
			vdir = (aim_dir * 25.0 + Vector3.UP * (0.5 * grav * tt * tt)).normalized()
		for i in mini(int(d["pellets"]), 8):
			var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * float(d["spread"])
			var b := Bullet.create()
			get_parent().add_child(b)
			b.setup(origin, vdir + jitter, spd, 0.0, d["color"], 1, float(d["range"]) / spd, float(d["tracer"]))
			b.blast = float(d.get("blast", 0.0))
			b.grav = grav
		Sfx.play_at(self, String(d["sfx"]), origin, float(d["vol"]))
	elif kind == "melee" or kind == "throw":
		model.attack(d)
		Sfx.play_at(self, "swing" if kind == "melee" else "pin", global_position + Vector3(0, 1.3, 0), -4.0)


func head_y() -> float:
	return global_position.y + 1.5


func take_damage(amount: float, _pos: Vector3 = Vector3.ZERO, attacker: int = 0, impulse: Vector3 = Vector3.ZERO) -> void:
	if dead or net == null:
		return
	var who: int = attacker if attacker != 0 else net.local_fid
	if net.is_friendly(who, fid):
		return
	if model != null:
		model.hit()
	Sfx.play_at(self, "hit", global_position + Vector3(0, 1.2, 0), 0.0)
	net.send_damage(fid, amount, who, impulse)
	net.hit_marker()


func stagger(_v: Vector3) -> void:
	pass

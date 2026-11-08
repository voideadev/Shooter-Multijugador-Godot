class_name Thrown
extends Node3D

const SCENE_PATH := "res://scenes/objects/thrown.tscn"

var kind := "grenade"
var def: Dictionary = {}
var velocity := Vector3.ZERO
var grav := 16.0
var fuse := 2.3
var attacker := 0
var harmless := false

var _life := 10.0
var _stuck := false
var _spin := Vector3.ZERO
var _dyn: Node3D

@onready var _vis: Node3D = $Visual
@onready var data_mesh: MeshInstance3D = $Visual/DataMesh
@onready var grenade_model: Node3D = $Visual/Grenade
@onready var molotov_model: Node3D = $Visual/Molotov
@onready var knife_model: Node3D = $Visual/Knife


func setup(d: Dictionary, pos: Vector3, vel: Vector3) -> void:
	def = d
	kind = String(d["proj"])
	velocity = vel
	grav = float(d["grav"])
	fuse = float(d.get("fuse", 2.3))
	global_position = pos
	reset_physics_interpolation()
	_build_visual()
	if kind != "knife":
		_spin = Vector3(randf_range(-9.0, 9.0), randf_range(-3.0, 3.0), randf_range(-9.0, 9.0))
	_orient(0.0)


func _build_visual() -> void:
	var model_id := "tknife" if kind == "knife" else kind
	var has_data := ModelDataB.has_weapon(model_id)
	data_mesh.visible = has_data
	if has_data:
		data_mesh.mesh = Humanoid.extra_mesh(model_id)
	var is_dyn := String(def.get("id", "")) == "dynamite"
	grenade_model.visible = not has_data and kind == "grenade" and not is_dyn
	if is_dyn and _dyn == null:
		_dyn = _make_dynamite()
		_vis.add_child(_dyn)
	molotov_model.visible = not has_data and kind == "molotov"
	knife_model.visible = not has_data and kind == "knife"


func _make_dynamite() -> Node3D:
	var root := Node3D.new()
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.75, 0.12, 0.1)
	red.roughness = 0.7
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.13)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.85, 0.8, 0.65)
	for k in 3:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.035
		cm.height = 0.3
		mi.mesh = cm
		mi.material_override = red
		mi.position = Vector3((float(k) - 1.0) * 0.07, 0.0, 0.0)
		root.add_child(mi)
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.04, 0.07)
	band.mesh = bm
	band.material_override = dark
	band.position = Vector3(0.0, 0.04, 0.0)
	root.add_child(band)
	var wick := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.006
	wm.bottom_radius = 0.006
	wm.height = 0.14
	wick.mesh = wm
	wick.material_override = cloth
	wick.position = Vector3(0.0, 0.22, 0.0)
	root.add_child(wick)
	return root


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if kind == "grenade":
		fuse -= delta
		if fuse <= 0.0:
			_explode()
			return
	if _stuck:
		return
	velocity.y -= grav * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		_orient(delta)
		return
	_on_hit(hit)


func _orient(delta: float) -> void:
	if kind == "knife":
		if velocity.length() < 0.01:
			return
		var dir := velocity.normalized()
		var up := Vector3.UP
		if absf(dir.dot(up)) > 0.98:
			up = Vector3.RIGHT
		global_basis = Basis.looking_at(dir, up)
	elif _vis != null:
		_vis.rotation += _spin * delta


func _on_hit(hit: Dictionary) -> void:
	var pos: Vector3 = hit["position"]
	var n: Vector3 = hit["normal"]
	var c = hit["collider"]
	match kind:
		"knife":
			if c != null and c.has_method("take_damage"):
				if not harmless:
					c.take_damage(float(def["damage"]), pos, attacker)
				Bullet.spark(get_parent(), pos, Color(0.9, 0.15, 0.1))
				queue_free()
			else:
				Bullet.spark(get_parent(), pos, Color(0.75, 0.65, 0.48))
				Sfx.play_at(get_parent(), "tink", pos, -4.0)
				global_position = pos
				_stuck = true
				_life = 4.0
		"molotov":
			global_position = pos + n * 0.1
			_explode()
		_:
			global_position = pos + n * 0.07
			var vn := velocity.dot(n)
			if absf(vn) > 2.5:
				Sfx.play_at(get_parent(), "tink", pos, -8.0)
			velocity -= n * vn * 1.45
			var normal_v := n * velocity.dot(n)
			var tangent_v := velocity - normal_v
			velocity = normal_v + tangent_v * 0.8
			if velocity.length() < 0.7 and n.y > 0.6:
				velocity = Vector3.ZERO
				_stuck = true
				_spin = Vector3.ZERO


func _explode() -> void:
	var host := get_parent()
	var pos := global_position
	if kind == "molotov":
		FireZone.create(host, def, pos, attacker, harmless)
		Sfx.play_at(host, "glass", pos, 2.0)
		Bullet.spark(host, pos + Vector3(0.0, 0.3, 0.0), Color(1.0, 0.55, 0.15))
	else:
		Thrown.blast(host, pos, float(def["radius"]), float(def["damage"]), attacker, harmless)
	queue_free()


static func blast(host: Node, pos: Vector3, radius: float, dmg: float, attacker: int = 0, harmless: bool = false, direct = null) -> void:
	var space := (host as Node3D).get_world_3d().direct_space_state
	var center := pos + Vector3(0.0, 0.25, 0.0)
	var tree := host.get_tree()
	var targets: Array = []
	targets.append_array(tree.get_nodes_in_group("enemies"))
	targets.append_array(tree.get_nodes_in_group("player"))
	targets.append_array(tree.get_nodes_in_group("barrels"))
	if harmless:
		targets.clear()
	elif direct != null and is_instance_valid(direct) and not targets.has(direct):
		targets.append(direct)
	for t in targets:
		if not is_instance_valid(t):
			continue
		var is_direct: bool = (t == direct)
		var c: Vector3 = t.global_position + Vector3(0.0, 0.0 if t.is_in_group("barrels") else 1.0, 0.0)
		var d := c.distance_to(center)
		if d > radius and not is_direct:
			continue
		if not is_direct:
			var lq := PhysicsRayQueryParameters3D.create(center, c, 1)
			if t is CollisionObject3D:
				var ex: Array[RID] = [(t as CollisionObject3D).get_rid()]
				lq.exclude = ex
			if not space.intersect_ray(lq).is_empty():
				continue
		var f := clampf(1.0 - d / radius, 0.0, 1.0)
		var amount := dmg if is_direct else dmg * (0.45 + 0.55 * f)
		if t.is_in_group("player") and not is_direct:
			amount *= 0.5
		var away: Vector3 = c - center
		var hz := Vector3(away.x, 0.0, away.z)
		if hz.length() < 0.05:
			hz = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
		hz = hz.normalized()
		var power := 0.4 + 0.6 * f
		var imp := hz * (9.0 + 13.0 * power) + Vector3.UP * (7.0 + 7.0 * power)
		t.take_damage(amount, c, attacker, imp)
		if t.has_method("stagger"):
			t.stagger(hz * (4.0 + 8.0 * f))
	for p in tree.get_nodes_in_group("player"):
		var dp: float = p.global_position.distance_to(pos)
		if dp < 25.0 and p.has_method("shake"):
			p.shake(0.1 * (1.0 - dp / 25.0))
	_boom_visual(host, pos, radius)
	Sfx.play_at(host, "boom", pos, 6.0)


static func _boom_visual(host: Node, pos: Vector3, radius: float) -> void:
	Explosion.create(host, pos, radius)


static func create() -> Thrown:
	return load(SCENE_PATH).instantiate() as Thrown

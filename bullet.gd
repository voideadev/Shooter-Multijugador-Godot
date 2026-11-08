class_name Bullet
extends Node3D

const SCENE_PATH := "res://scenes/objects/bullet.tscn"

var velocity := Vector3.ZERO
var damage := 10.0
var mask := 1
var attacker := 0
var exclude: Array = []
var color := Color.WHITE
var blast := 0.0
var grav := 0.0
var _life := 2.0

const CRIT_MULT := 2.5

@onready var tracer: MeshInstance3D = $Tracer


func setup(pos: Vector3, dir: Vector3, speed: float, dmg: float, col: Color, ray_mask: int, life: float = 2.0, size: float = 1.0) -> void:
	dir = dir.normalized()
	velocity = dir * speed
	damage = dmg
	color = col
	mask = ray_mask
	_life = life
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.98:
		up = Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(dir, up), pos)
	reset_physics_interpolation()
	_apply_visual(size)


func _apply_visual(size: float) -> void:
	tracer.scale = Vector3.ONE * size
	var mat := tracer.material_override.duplicate() as StandardMaterial3D
	mat.albedo_color = Color(color.r * 2.5, color.g * 2.5, color.b * 2.5)
	tracer.material_override = mat


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if grav > 0.0:
		velocity.y -= grav * delta
		var up := Vector3.UP
		if absf(velocity.normalized().dot(up)) > 0.98:
			up = Vector3.RIGHT
		global_transform.basis = Basis.looking_at(velocity.normalized(), up)
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	if not exclude.is_empty():
		var ex: Array[RID] = []
		for r in exclude:
			ex.append(r)
		q.exclude = ex
	q.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	var c = hit["collider"]
	var pos: Vector3 = hit["position"]
	if blast > 0.0:
		var n: Vector3 = hit.get("normal", Vector3.UP)
		var direct = c if (c != null and c.has_method("take_damage")) else null
		Thrown.blast(get_parent(), pos + n * 0.15, blast, damage, attacker, damage <= 0.0, direct)
		queue_free()
		return
	var dmg := damage
	var crit := false
	if dmg > 0.0 and c != null and c.has_method("head_y") and pos.y >= float(c.head_y()):
		dmg *= CRIT_MULT
		crit = true
	if c != null and c.has_method("take_damage"):
		c.take_damage(dmg, pos, attacker)
	if crit:
		Bullet.spark(get_parent(), pos, Color(1.0, 0.85, 0.2))
		Sfx.play_at(get_parent(), "crit", pos, 3.0)
	else:
		Bullet.spark(get_parent(), pos, Color(0.75, 0.65, 0.48))
	queue_free()


static func safe_origin(body: Node3D, chest: Vector3, muzzle: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(chest, muzzle, 1)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return muzzle
	return (hit["position"] as Vector3) - (muzzle - chest).normalized() * 0.05


static func create() -> Bullet:
	return load(SCENE_PATH).instantiate() as Bullet


static func spark(parent: Node, pos: Vector3, col: Color) -> void:
	Spark.create(parent, pos, col)

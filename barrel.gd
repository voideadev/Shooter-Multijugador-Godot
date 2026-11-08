class_name Barrel
extends StaticBody3D

static var on_exploded: Callable = Callable()

const MAX_HP := 30.0
const RADIUS := 6.0
const DAMAGE := 190.0

var hp := MAX_HP
var exploded := false
var key := ""
var last_attacker := 0
var _pending := false


func setup(p_key: String) -> void:
	key = p_key
	add_to_group("barrels")


func take_damage(amount: float, _pos: Vector3 = Vector3.ZERO, attacker: int = 0, _impulse: Vector3 = Vector3.ZERO) -> void:
	if exploded or _pending or amount <= 0.0:
		return
	if attacker != 0:
		last_attacker = attacker
	hp -= amount
	if hp > 0.0:
		Bullet.spark(get_parent(), global_position + Vector3(0.0, 0.3, 0.0), Color(1.0, 0.6, 0.25))
		return
	_pending = true
	await get_tree().create_timer(randf_range(0.05, 0.16)).timeout
	if is_inside_tree():
		explode(true)


func explode(local: bool) -> void:
	if exploded:
		return
	set_exploded_silent()
	Thrown.blast(get_parent(), global_position, RADIUS, DAMAGE, last_attacker, not local)
	if local and on_exploded.is_valid():
		on_exploded.call(key)


func set_exploded_silent() -> void:
	exploded = true
	_pending = false
	remove_from_group("barrels")
	collision_layer = 0
	for ch in get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).visible = false
		elif ch is CollisionShape3D:
			(ch as CollisionShape3D).set_deferred("disabled", true)


func restore() -> void:
	exploded = false
	_pending = false
	hp = MAX_HP
	last_attacker = 0
	collision_layer = 1
	for ch in get_children():
		if ch is MeshInstance3D:
			(ch as MeshInstance3D).visible = true
		elif ch is CollisionShape3D:
			(ch as CollisionShape3D).set_deferred("disabled", false)
	add_to_group("barrels")

class_name FireZone
extends Node3D

const SCENE_PATH := "res://scenes/objects/firezone.tscn"
const FLAME := preload("res://scenes/effects/flame.tscn")

var radius := 3.0
var duration := 6.0
var tick_dmg := 8.0
var attacker := 0
var harmless := false

var _t := 0.0
var _tick := 0.0
var _flames: Array = []
var _disc_mat: StandardMaterial3D

@onready var _disc: MeshInstance3D = $Disc
@onready var _flames_root: Node3D = $Flames


static func create(host: Node, def: Dictionary, pos: Vector3, p_attacker: int, p_harmless: bool) -> FireZone:
	var z := load(SCENE_PATH).instantiate() as FireZone
	z.attacker = p_attacker
	z.harmless = p_harmless
	z.radius = float(def.get("radius", 3.0))
	z.duration = float(def.get("duration", 6.0))
	z.tick_dmg = float(def.get("tick_dmg", 8.0))
	host.add_child(z)
	z.global_position = pos
	return z


func _ready() -> void:
	_disc.scale = Vector3(radius, 1.0, radius)
	_disc_mat = _disc.material_override.duplicate() as StandardMaterial3D
	_disc.material_override = _disc_mat
	var n := int(roundf(radius * 4.0))
	for i in n:
		var a := randf() * TAU
		var r := sqrt(randf()) * radius * 0.92
		var f := FLAME.instantiate() as MeshInstance3D
		var mat := f.material_override.duplicate() as StandardMaterial3D
		mat.albedo_color = Color(1.0, randf_range(0.35, 0.7), 0.05, 0.8)
		f.material_override = mat
		var h := 0.95 * randf_range(0.74, 1.26)
		var wf := randf_range(0.7, 1.3)
		_flames_root.add_child(f)
		f.position = Vector3(cos(a) * r, h * 0.5, sin(a) * r)
		_flames.append({"node": f, "ph": randf() * TAU, "sp": randf_range(6.0, 11.0), "h": h, "wf": wf})


func _process(delta: float) -> void:
	_t += delta
	var fade := clampf((duration - _t) / 1.5, 0.0, 1.0)
	for d in _flames:
		var f: MeshInstance3D = d["node"]
		var sp: float = d["sp"]
		var ph: float = d["ph"]
		var h: float = d["h"]
		var wf: float = d["wf"]
		var w := (0.75 + 0.35 * sin(_t * sp + ph)) * (0.4 + 0.6 * fade) * wf
		var sy := maxf(0.05, (0.8 + 0.5 * sin(_t * sp * 1.3 + ph)) * fade)
		f.scale = Vector3(w, sy * h / 0.95, w)
		f.position.y = h * 0.5 * sy
	_disc_mat.albedo_color.a = 0.35 * fade


func _physics_process(delta: float) -> void:
	if _t >= duration:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	if harmless:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if _inside(e):
			e.take_damage(tick_dmg, e.global_position + Vector3(0.0, 1.0, 0.0), attacker)
	for p in get_tree().get_nodes_in_group("player"):
		if _inside(p):
			p.take_damage(tick_dmg * 0.6, p.global_position + Vector3(0.0, 1.0, 0.0), attacker)


func _inside(n) -> bool:
	var d: Vector3 = n.global_position - global_position
	return Vector2(d.x, d.z).length() < radius and absf(d.y) < 1.8

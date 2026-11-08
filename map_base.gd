class_name MapBase
extends Node3D

@export var map_name := "Mapa"
@export var health_pickup_scene: PackedScene = preload("res://scenes/objects/health_pickup.tscn")
@export var health_pickup_count := 8

var player_spawn := Vector3.ZERO
var enemy_spawns: Array = []
var barrels := {}

@onready var navigation: NavigationRegion3D = $Navigation
@onready var player_marker: Marker3D = $Spawns/Player
@onready var enemy_markers: Node3D = $Spawns/Enemies


func _ready() -> void:
	player_spawn = player_marker.global_position
	enemy_spawns.clear()
	for m in enemy_markers.get_children():
		enemy_spawns.append((m as Marker3D).global_position)
	_setup_barrels()


func _setup_barrels() -> void:
	barrels.clear()
	for n in find_children("Barrel*", "StaticBody3D", true, false):
		if not _is_red(n):
			continue
		n.set_script(preload("res://barrel.gd"))
		var key := str(get_path_to(n))
		n.call("setup", key)
		barrels[key] = n


func _is_red(body: Node) -> bool:
	var mi := body.get_node_or_null("Mesh") as MeshInstance3D
	if mi == null:
		return false
	var mat := mi.material_override as StandardMaterial3D
	if mat == null:
		return false
	var c := mat.albedo_color
	return c.r > 0.45 and c.g < 0.25 and c.b < 0.2


func explode_barrel(key: String, local: bool) -> void:
	var b = barrels.get(key)
	if b != null and is_instance_valid(b):
		b.explode(local)


func hide_barrel(key: String) -> void:
	var b = barrels.get(key)
	if b != null and is_instance_valid(b):
		b.set_exploded_silent()


func exploded_keys() -> Array:
	var out: Array = []
	for k in barrels:
		if is_instance_valid(barrels[k]) and barrels[k].exploded:
			out.append(k)
	return out


func restore_barrels() -> void:
	for k in barrels:
		if is_instance_valid(barrels[k]):
			barrels[k].restore()


func bake_navigation() -> void:
	var nm: NavigationMesh = navigation.navigation_mesh.duplicate()
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, self)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	navigation.navigation_mesh = nm


func spawn_health_pickups() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var base: Array = enemy_spawns.duplicate()
	base.append(player_spawn)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + base.size()
	var chosen: Array = []
	var tries := 0
	while chosen.size() < health_pickup_count and tries < 300:
		tries += 1
		var a: Vector3 = base[rng.randi() % base.size()]
		var ang := rng.randf() * TAU
		var d := rng.randf_range(1.5, 4.5)
		var p := a + Vector3(cos(ang) * d, 0.0, sin(ang) * d)
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.0, 1.6, 0.0), p + Vector3(0.0, -1.2, 0.0), 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var fp: Vector3 = hit["position"]
		if absf(fp.y - a.y) > 0.5:
			continue
		var close := false
		for c in chosen:
			if (c as Vector3).distance_to(fp) < 7.0:
				close = true
				break
		if close:
			continue
		chosen.append(fp)
		var pk := health_pickup_scene.instantiate()
		pk.position = fp
		add_child(pk)

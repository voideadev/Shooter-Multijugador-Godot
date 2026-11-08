class_name Maps
extends RefCounted

const LIST := [
	{"name": "Ciudadela del Desierto", "scene": "res://scenes/maps/map_01.tscn"},
	{"name": "Pueblo Viejo", "scene": "res://scenes/maps/map_02.tscn"},
	{"name": "Fábrica Abandonada", "scene": "res://scenes/maps/map_03.tscn"},
	{"name": "Frente de Guerra", "scene": "res://scenes/maps/map_04.tscn"},
	{"name": "Bosque", "scene": "res://scenes/maps/map_05.tscn"},
]

static var current := 0


static func create() -> MapBase:
	var packed: PackedScene = load(LIST[current]["scene"])
	return packed.instantiate() as MapBase

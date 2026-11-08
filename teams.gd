class_name Teams
extends RefCounted

const NAMES := ["ROJO", "AZUL", "VERDE", "AMARILLO"]
const COLORS := [
	Color(0.92, 0.2, 0.18),
	Color(0.22, 0.48, 0.98),
	Color(0.24, 0.8, 0.32),
	Color(0.98, 0.82, 0.16),
]
const MAX_TEAMS := 4
const MAX_BOTS := 10


static func color(t: int) -> Color:
	return COLORS[t] if t >= 0 and t < COLORS.size() else Color(1.0, 0.8, 0.4)


static func name_of(t: int) -> String:
	return NAMES[t] if t >= 0 and t < NAMES.size() else ""


static func suit(t: int) -> Color:
	return color(t).darkened(0.12)


static func armor(t: int) -> Color:
	return color(t).darkened(0.38)


static func split_bots(total: int, teams: int) -> Array:
	var out: Array = [0, 0, 0, 0]
	teams = clampi(teams, 1, MAX_TEAMS)
	for i in total:
		out[i % teams] += 1
	return out

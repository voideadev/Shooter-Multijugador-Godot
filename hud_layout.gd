class_name HudLayout
extends RefCounted

const PATH := "user://hud_layout.cfg"
const ORDER := ["fire", "melee", "jump", "crouch", "aim", "reload", "throw", "weapon", "view"]
const NAMES := {
	"fire": "DISPARAR", "melee": "CUERPO A CUERPO", "jump": "SALTAR", "crouch": "AGACHARSE", "aim": "MIRA",
	"reload": "RECARGAR", "throw": "LANZABLE", "weapon": "CAMBIAR ARMA", "view": "CAMBIAR VISTA"
}
const COLORS := {
	"fire": Color(1.0, 0.3, 0.25), "melee": Color(1.0, 0.45, 0.35), "jump": Color(0.35, 0.9, 0.6),
	"crouch": Color(1.0, 0.8, 0.4), "aim": Color(0.5, 0.85, 1.0), "reload": Color(0.55, 0.8, 1.0),
	"throw": Color(1.0, 0.65, 0.2), "weapon": Color(1.0, 0.8, 0.4), "view": Color(0.5, 0.85, 1.0),
}
const DEFS := {
	"fire": {"shape": "circle", "pos": Vector2(0.891, 0.792), "size": Vector2(72.0, 72.0)},
	"melee": {"shape": "circle", "pos": Vector2(0.758, 0.914), "size": Vector2(50.0, 50.0)},
	"jump": {"shape": "circle", "pos": Vector2(0.883, 0.556), "size": Vector2(50.0, 50.0)},
	"crouch": {"shape": "circle", "pos": Vector2(0.754, 0.736), "size": Vector2(50.0, 50.0)},
	"aim": {"shape": "circle", "pos": Vector2(0.742, 0.542), "size": Vector2(50.0, 50.0)},
	"reload": {"shape": "circle", "pos": Vector2(0.641, 0.636), "size": Vector2(50.0, 50.0)},
	"throw": {"shape": "circle", "pos": Vector2(0.625, 0.885), "size": Vector2(44.0, 44.0)},
	"weapon": {"shape": "rect", "pos": Vector2(0.5, 0.885), "size": Vector2(210.0, 72.0)},
	"view": {"shape": "rect", "pos": Vector2(0.893, 0.256), "size": Vector2(200.0, 44.0)},
}

const RUN_GAP_DEF := 200.0
const RUN_GAP_MIN := 110.0
const RUN_GAP_MAX := 320.0

static var run_gap := RUN_GAP_DEF
static var data := {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for id in ORDER:
		data[id] = {"pos": DEFS[id]["pos"], "scale": 1.0, "visible": true}
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	run_gap = clampf(float(cf.get_value("run", "gap", RUN_GAP_DEF)), RUN_GAP_MIN, RUN_GAP_MAX)
	for id in ORDER:
		if not cf.has_section(id):
			continue
		var d: Dictionary = data[id]
		var dp: Vector2 = d["pos"]
		d["pos"] = Vector2(clampf(float(cf.get_value(id, "x", dp.x)), 0.0, 1.0), clampf(float(cf.get_value(id, "y", dp.y)), 0.0, 1.0))
		d["scale"] = clampf(float(cf.get_value(id, "scale", 1.0)), 0.5, 2.0)
		d["visible"] = bool(cf.get_value(id, "visible", true))


static func save() -> void:
	ensure_loaded()
	var cf := ConfigFile.new()
	for id in ORDER:
		var d: Dictionary = data[id]
		var dp: Vector2 = d["pos"]
		cf.set_value(id, "x", dp.x)
		cf.set_value(id, "y", dp.y)
		cf.set_value(id, "scale", float(d["scale"]))
		cf.set_value(id, "visible", bool(d["visible"]))
	cf.set_value("run", "gap", run_gap)
	cf.save(PATH)


static func reset(id: String = "") -> void:
	ensure_loaded()
	if id == "":
		run_gap = RUN_GAP_DEF
	for k in ORDER:
		if id == "" or id == k:
			data[k] = {"pos": DEFS[k]["pos"], "scale": 1.0, "visible": true}
	save()


static func center(id: String, vp: Vector2) -> Vector2:
	ensure_loaded()
	var dp: Vector2 = data[id]["pos"]
	return Vector2(dp.x * vp.x, dp.y * vp.y)


static func size_of(id: String) -> Vector2:
	ensure_loaded()
	var ds: Vector2 = DEFS[id]["size"]
	return ds * float(data[id]["scale"])


static func shape_of(id: String) -> String:
	return String(DEFS[id]["shape"])


static func is_shown(id: String) -> bool:
	ensure_loaded()
	return bool(data[id]["visible"])


static func set_pos(id: String, frac: Vector2) -> void:
	ensure_loaded()
	data[id]["pos"] = Vector2(clampf(frac.x, 0.03, 0.97), clampf(frac.y, 0.05, 0.95))


static func set_scale(id: String, s: float) -> void:
	ensure_loaded()
	data[id]["scale"] = clampf(s, 0.5, 2.0)


static func set_shown(id: String, v: bool) -> void:
	ensure_loaded()
	data[id]["visible"] = v


static func hit(id: String, p: Vector2, vp: Vector2, margin: float = 0.0) -> bool:
	var c := center(id, vp)
	var sz := size_of(id)
	if shape_of(id) == "circle":
		return p.distance_to(c) <= sz.x + margin
	var m := Vector2(margin, margin)
	return Rect2(c - sz * 0.5 - m, sz + m * 2.0).has_point(p)

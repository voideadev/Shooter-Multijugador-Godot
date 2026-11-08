class_name Gfx
extends RefCounted

const PATH := "user://graphics.cfg"
const PRESET_NAMES := ["BAJA", "MEDIA", "ALTA"]
const PRESETS := [
	{"res": 0.6, "msaa": 0, "shadows": 0, "fps": 30, "fog": false},
	{"res": 0.8, "msaa": 0, "shadows": 1, "fps": 60, "fog": true},
	{"res": 1.0, "msaa": 1, "shadows": 2, "fps": 60, "fog": true},
]
const RES_STEPS := [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
const SHADOW_NAMES := ["NO", "BAJAS", "ALTAS"]
const MSAA_NAMES := ["NO", "2X", "4X"]
const FPS_STEPS := [30, 45, 60, 90, 120]

static var res := 1.0
static var msaa := 1
static var shadows := 2
static var fps := 60
static var fog := true
static var preset := 2
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		res = clampf(float(cf.get_value("gfx", "res", res)), 0.4, 1.0)
		msaa = clampi(int(cf.get_value("gfx", "msaa", msaa)), 0, 2)
		shadows = clampi(int(cf.get_value("gfx", "shadows", shadows)), 0, 2)
		fps = int(cf.get_value("gfx", "fps", fps))
		fog = bool(cf.get_value("gfx", "fog", fog))
		preset = int(cf.get_value("gfx", "preset", -1))
		return
	var cores := OS.get_processor_count()
	set_preset(0 if cores <= 4 else (1 if cores <= 6 else 2), false)


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("gfx", "res", res)
	cf.set_value("gfx", "msaa", msaa)
	cf.set_value("gfx", "shadows", shadows)
	cf.set_value("gfx", "fps", fps)
	cf.set_value("gfx", "fog", fog)
	cf.set_value("gfx", "preset", preset)
	cf.save(PATH)


static func set_preset(i: int, do_save: bool = true) -> void:
	var p: Dictionary = PRESETS[clampi(i, 0, PRESETS.size() - 1)]
	res = float(p["res"])
	msaa = int(p["msaa"])
	shadows = int(p["shadows"])
	fps = int(p["fps"])
	fog = bool(p["fog"])
	preset = clampi(i, 0, PRESETS.size() - 1)
	if do_save:
		save()


static func touched() -> void:
	preset = -1
	save()


static func preset_name() -> String:
	return String(PRESET_NAMES[preset]) if preset >= 0 else "PERSONALIZADA"


static func apply(node: Node) -> void:
	ensure_loaded()
	if node == null or not node.is_inside_tree():
		return
	var vp := node.get_viewport()
	vp.scaling_3d_scale = res
	match msaa:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
		1:
			vp.msaa_3d = Viewport.MSAA_2X
		_:
			vp.msaa_3d = Viewport.MSAA_4X
	Engine.max_fps = fps
	RenderingServer.directional_shadow_atlas_set_size(1024 if shadows <= 1 else 4096, true)
	var root := node.get_tree().root
	for n in root.find_children("*", "DirectionalLight3D", true, false):
		var l := n as DirectionalLight3D
		if l == null:
			continue
		l.shadow_enabled = shadows > 0
		l.directional_shadow_max_distance = 25.0 if shadows == 1 else 45.0
	for n in root.find_children("*", "WorldEnvironment", true, false):
		var we := n as WorldEnvironment
		if we != null and we.environment != null:
			we.environment.fog_enabled = fog

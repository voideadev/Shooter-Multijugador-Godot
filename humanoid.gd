class_name Humanoid
extends Node3D

const SCENE_PATH := "res://scenes/characters/humanoid.tscn"
const CODE_GUNS := ["ak47", "bazooka", "potato", "revolver", "mpistol", "marksman", "lmg", "vector", "mp5", "doublebarrel", "autoshot", "semisniper", "antimat", "gl", "minigun"]

static func create() -> Humanoid:
	return load(SCENE_PATH).instantiate() as Humanoid


const HIP_Y := 0.95
const SH_Y := 0.19
const SH_X := 0.215
const LT := 0.42
const LS := 0.41
const L1 := 0.28
const L2 := 0.27
const ANK_H := 0.07
const STANCE := 0.115

static var _tex_cache := {}

var max_speed := 6.0
var muzzle: Marker3D
var _wall_pb := 0.0
var prone := 0.0
var crouch := 0.0
var airborne := false
var vspeed := 0.0

var _hips: Node3D
var _spine: Node3D
var _upper: Node3D
var _chest: Node3D
var _head: Node3D
var _sh: Array[Node3D] = [null, null]
var _el: Array[Node3D] = [null, null]
var _hand: Array[Node3D] = [null, null]
var _thigh: Array[Node3D] = [null, null]
var _knee: Array[Node3D] = [null, null]
var _ankle: Array[Node3D] = [null, null]
var _gun: Node3D
var _flash_mesh: MeshInstance3D
var _body_mats: Array[StandardMaterial3D] = []
var _head_meshes: Array = []
var _first_person := false
const GUN_SMOOTH := 22.0
var _gun_l := Transform3D.IDENTITY
var _gun_ready := false
const FP_EYE := Vector3(0.0, 0.075, 0.0)
const FP_HIP_SHIFT := Vector3(0.06, 0.0, 0.06)
const FP_ANCHOR := Vector3(0.0, -0.19, 0.1)
var ads := 0.0
var cam_xf := Transform3D.IDENTITY
var _ads_s := 0.0
var _ads_d := 0.3
var _sight_h := 0.1
var _sight_z := 0.0
var _hold := Vector3(0.11, -0.075, 0.16)
var _carry_z := 0.2
var _wid := ""
var _scoped := false
var _fp_only: Array = []
var _rd_root: Node3D
var _rd_head: RigidBody3D
var _ragdolled := false
var _fp_s := 0.0
var _gun_models := {}
var _accent := Color(1.0, 0.7, 0.25)
var _grip_r := Vector3(0.0, -0.02, 0.03)
var _grip_l := Vector3(0.0, 0.0, -0.27)
var reload_p := -1.0
var _mag_prop: MeshInstance3D
var _swap := 0.0
var _one_hand := false
var _two_hand := false
var _carry_up := 0.35
var _carry_off := Vector3(0.2, -0.22, 0.36)
var _atk_t := -1.0
var _atk_dur := 0.4
var _atk_style := "slash"
var _atk_hit := 0.5
var _land := 0.0
var _air_s := 0.0
var _air_lift := 0.2
var _vy_last := 0.0
var _was_air := false

var _fp: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _st: Array[float] = [-1.0, -1.0]
var _sdur: Array[float] = [0.2, 0.2]
var _slift: Array[float] = [0.1, 0.1]
var _fyaw: Array[float] = [0.0, 0.0]
var _fyaw_from: Array[float] = [0.0, 0.0]
var _fyaw_to: Array[float] = [0.0, 0.0]
var _fpitch: Array[float] = [0.0, 0.0]
var _feet_ready := false

var _pelv_y := HIP_Y
var _time := randf() * 10.0
var _aim := 0.0
var _ap := 0.0
var _recoil := 0.0
var _hit := 0.0
var _flash_t := 0.0
var _dead := false
var _dead_t := 0.0
var _prev_pos := Vector3.ZERO
var _prev_yaw := 0.0
var _has_prev := false
var _vel := Vector3.ZERO
var _lat := 0.0
var _fwdc := 0.0
var _yr := 0.0
var _uy := 0.0
var _spd := 0.0


func build(suit: Color, armor: Color, accent: Color, variant: int = 0, skin: Color = Color(0.86, 0.66, 0.52), _hair: Color = Color(0.13, 0.09, 0.07), character: int = 0) -> void:
	var pal := _soldier_palette(suit, armor, accent, skin, variant, character)
	var data: Dictionary
	match character:
		1:
			data = ModelDataB.soldier()
		2:
			data = ModelDataC.soldier()
		_:
			data = ModelData.soldier()

	_body_mats.clear()
	_head_meshes.clear()
	_hips = $Hips
	_attach(_hips, data.get("hips", {}), pal)
	for i in 2:
		var thigh := _hips.get_node("Thigh%d" % i) as Node3D
		_attach(thigh, data.get("thigh%d" % i, {}), pal)
		var knee := thigh.get_node("Knee%d" % i) as Node3D
		_attach(knee, data.get("knee%d" % i, {}), pal)
		var ankle := knee.get_node("Ankle%d" % i) as Node3D
		_attach(ankle, data.get("ankle%d" % i, {}), pal)
		_thigh[i] = thigh
		_knee[i] = knee
		_ankle[i] = ankle
	_spine = _hips.get_node("Spine")
	_attach(_spine, data.get("spine", {}), pal)
	_upper = _spine.get_node("Upper")
	_chest = _upper.get_node("Chest")
	_attach(_chest, data.get("chest", {}), pal)
	var neck := _upper.get_node("NeckMesh") as MeshInstance3D
	_set_mesh(neck, data.get("neck", {}), pal)
	if neck.mesh != null:
		_head_meshes.append(neck)
	_head = _upper.get_node("Head")
	_attach(_head, data.get("head", {}), pal)
	var head_mesh := _head.get_node("Mesh") as MeshInstance3D
	if head_mesh.mesh != null:
		_head_meshes.append(head_mesh)
	for i in 2:
		var sh := _upper.get_node("Shoulder%d" % i) as Node3D
		_attach(sh, data.get("sh%d" % i, {}), pal)
		var el := sh.get_node("Elbow%d" % i) as Node3D
		_attach(el, data.get("el%d" % i, {}), pal)
		var hand := el.get_node("Hand%d" % i) as Node3D
		_attach(hand, data.get("hand%d" % i, {}), pal)
		_sh[i] = sh
		_el[i] = el
		_hand[i] = hand
	_mag_prop = _hand[1].get_node("MagProp")
	_build_gun(_hand[0], accent)


func _soldier_palette(suit: Color, armor: Color, accent: Color, skin: Color, variant: int, character: int = 0) -> Dictionary:
	if character == 2:
		var neon := Color(0.0, 0.88, 1.0) if variant == 0 else Color(1.0, 0.25, 0.2)
		var vis := Color(0.6, 0.98, 1.0) if variant == 0 else Color(1.0, 0.55, 0.45)
		return {
			"skin": _mat(skin, 0.0, 0.65, true),
			"uniform": _mat(suit.darkened(0.5), 0.1, 0.7, true),
			"uniform_d": _mat(suit.darkened(0.7), 0.1, 0.7, true),
			"plate": _mat(armor.lightened(0.15), 0.4, 0.45, true),
			"plate_l": _mat(armor.lightened(0.45), 0.4, 0.4, true),
			"plate_d": _mat(armor.darkened(0.1), 0.4, 0.5, true),
			"dark": _mat(Color(0.05, 0.06, 0.08), 0.3, 0.6, true),
			"glow": _glow(neon, 2.5),
			"visor": _glow(vis, 1.5),
		}
	if character == 1:
		var lens_b := Color(0.95, 0.66, 0.2) if variant == 0 else Color(1.0, 0.3, 0.2)
		var coyote := armor.lerp(Color(0.55, 0.45, 0.3), 0.7)
		var uni := suit.lightened(0.1)
		return {
			"skin": _mat(skin, 0.0, 0.65, true),
			"skin_d": _mat(skin.darkened(0.18), 0.0, 0.7, true),
			"uniform": _mat(uni, 0.0, 0.9, true),
			"uniform_d": _mat(uni.darkened(0.22), 0.0, 0.9, true),
			"pants": _mat(suit.darkened(0.05), 0.0, 0.9, true),
			"pack": _mat(suit.darkened(0.25), 0.0, 0.9, true),
			"canteen": _mat(suit.darkened(0.3), 0.1, 0.7, true),
			"hat": _mat(suit.lightened(0.18), 0.0, 0.95, true),
			"hat_d": _mat(suit.darkened(0.35), 0.0, 0.95, true),
			"vest": _mat(coyote, 0.05, 0.85, true),
			"vest_l": _mat(coyote.lightened(0.2), 0.05, 0.85, true),
			"pouch": _mat(coyote.darkened(0.15), 0.0, 0.9, true),
			"leather": _mat(Color(0.36, 0.24, 0.15), 0.0, 0.8, true),
			"sole": _mat(Color(0.13, 0.12, 0.11), 0.0, 0.9, true),
			"gloves": _mat(Color(0.18, 0.16, 0.14), 0.0, 0.8, true),
			"scarf": _mat(Color(0.84, 0.78, 0.62), 0.0, 0.95, true),
			"scarf_d": _mat(Color(0.69, 0.61, 0.44), 0.0, 0.95, true),
			"goggle": _mat(Color(0.11, 0.11, 0.13), 0.3, 0.5, true),
			"metal": _mat(Color(0.24, 0.25, 0.27), 0.6, 0.45, true),
			"dark": _mat(Color(0.12, 0.12, 0.13), 0.2, 0.7, true),
			"accent": _mat(accent, 0.0, 0.6, true),
			"lensB": _glow(lens_b, 1.2),
		}
	var lens := Color(0.31, 0.78, 0.9) if variant == 0 else Color(1.0, 0.35, 0.2)
	return {
		"skin": _mat(skin, 0.0, 0.65, true),
		"skin_d": _mat(skin.darkened(0.18), 0.0, 0.7, true),
		"helmet": _mat(suit.darkened(0.14), 0.05, 0.85, true),
		"helmet_d": _mat(suit.darkened(0.45), 0.05, 0.85, true),
		"uniform": _mat(suit, 0.0, 0.9, true),
		"uniform_d": _mat(suit.darkened(0.22), 0.0, 0.9, true),
		"pants": _mat(suit.darkened(0.28), 0.0, 0.9, true),
		"pack": _mat(suit.darkened(0.35), 0.0, 0.9, true),
		"vest": _mat(armor, 0.1, 0.8, true),
		"vest_l": _mat(armor.lightened(0.25), 0.1, 0.8, true),
		"pouch": _mat(Color(0.33, 0.29, 0.2), 0.0, 0.9, true),
		"boots": _mat(Color(0.12, 0.12, 0.125), 0.1, 0.7, true),
		"gloves": _mat(Color(0.15, 0.15, 0.165), 0.0, 0.8, true),
		"belt": _mat(Color(0.16, 0.13, 0.11), 0.0, 0.9, true),
		"mask": _mat(Color(0.13, 0.15, 0.14), 0.0, 0.9, true),
		"goggle": _mat(Color(0.1, 0.13, 0.17), 0.3, 0.5, true),
		"accent": _mat(accent, 0.0, 0.6, true),
		"lens": _glow(lens, 1.5),
	}


func _set_mesh(mi: MeshInstance3D, parts: Dictionary, pal: Dictionary) -> void:
	mi.mesh = null if parts.is_empty() else _parts_mesh(parts, pal)


func _attach(bone: Node3D, parts: Dictionary, pal: Dictionary) -> MeshInstance3D:
	var mi := bone.get_node("Mesh") as MeshInstance3D
	_set_mesh(mi, parts, pal)
	return mi if mi.mesh != null else null


static func _parts_mesh(parts: Dictionary, pal: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for cname in parts:
		var f: PackedFloat32Array = parts[cname]
		var n := f.size() / 3
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		verts.resize(n)
		norms.resize(n)
		for i in n:
			verts[i] = Vector3(f[i * 3], f[i * 3 + 1], f[i * 3 + 2])
		for t in range(0, n, 3):
			var nn := (verts[t + 2] - verts[t]).cross(verts[t + 1] - verts[t]).normalized()
			norms[t] = nn
			norms[t + 1] = nn
			norms[t + 2] = nn
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if pal.has(cname):
			mesh.surface_set_material(mesh.get_surface_count() - 1, pal[cname])
	return mesh


func _build_gun(hand: Node3D, p_accent: Color) -> void:
	_accent = p_accent
	for k in _gun_models:
		(_gun_models[k] as Node).queue_free()
	_gun_models.clear()
	_fp_only.clear()
	_gun = hand.get_node("Gun")
	muzzle = _gun.get_node("Muzzle")
	_flash_mesh = muzzle.get_node("FlashMesh")
	_flash_mesh.material_override = _glow(_accent.lightened(0.3), 7.0)
	_flash_mesh.visible = false
	equip(Weapons.LIST[Weapons.DEFAULT])


func equip(def: Dictionary) -> void:
	var id: String = def["id"]
	if not _gun_models.has(id):
		_gun_models[id] = _make_gun_model(id, String(def.get("kind", "gun")))
	for k in _gun_models:
		(_gun_models[k] as Node3D).visible = (k == id)
	var gs: float = def.get("scale", 1.0)
	(_gun_models[id] as Node3D).scale = Vector3.ONE * gs
	muzzle.position = (def["muzzle"] as Vector3) * gs
	_grip_r = (def["grip_r"] as Vector3) * gs
	_grip_l = (def["grip_l"] as Vector3) * gs
	_hold = def.get("hold", Vector3(0.11, -0.075, 0.16))
	_carry_z = def.get("carry_z", _hold.z + 0.04)
	_wid = id
	_scoped = bool(def.get("scope", id == "sniper"))
	_one_hand = bool(def.get("one_hand", false))
	_two_hand = bool(def.get("two_hand", false))
	_carry_up = float(def.get("carry_up", 0.35))
	_carry_off = def.get("carry_pos", Vector3(0.2, -0.22, 0.36))
	_atk_t = -1.0
	_ads_d = def.get("ads_d", 0.3)
	_sight_h = float(def.get("sight_h", 0.1)) * gs
	_sight_z = float(def.get("sight_z", 0.0)) * gs
	var flash: float = def["flash"]
	_flash_mesh.scale = Vector3(1.0, 1.0, 1.8) * flash
	_swap = 1.0


func eye_position() -> Vector3:
	if is_instance_valid(_rd_head):
		return _rd_head.global_transform * FP_EYE
	return _head.global_transform * FP_EYE


func land_dip() -> float:
	return _land * 0.1


func set_first_person(on: bool) -> void:
	if on == _first_person:
		return
	_first_person = on
	for m in _head_meshes:
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for n in _fp_only:
		(n as Node3D).visible = on


func _make_gun_model(id: String, kind: String = "gun") -> Node3D:
	var g := _node(_gun)
	var glass_t := StandardMaterial3D.new()
	glass_t.albedo_color = Color(0.5, 0.75, 1.0, 0.16)
	glass_t.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_t.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pal := {
		"lens_t": glass_t,
		"metal": _mat(Color(0.23, 0.235, 0.26), 0.6, 0.4, false),
		"metal_l": _mat(Color(0.44, 0.46, 0.49), 0.7, 0.35, false),
		"poly": _mat(Color(0.18, 0.18, 0.17), 0.1, 0.8, false),
		"wood": _mat(Color(0.41, 0.25, 0.13), 0.0, 0.7, false),
		"wood_d": _mat(Color(0.31, 0.19, 0.1), 0.0, 0.7, false),
		"accent": _mat(_accent, 0.0, 0.5, false),
		"dark": _mat(Color(0.11, 0.11, 0.12), 0.3, 0.7, false),
		"lens": _glow(Color(0.31, 0.78, 0.9), 1.2),
	}
	if kind != "gun":
		if ModelDataB.has_weapon(id):
			var xm := MeshInstance3D.new()
			xm.mesh = _parts_mesh(ModelDataB.weapon(id), extra_palette())
			g.add_child(xm)
		else:
			_build_extra(g, id, pal)
		return g
	if id in CODE_GUNS:
		_build_code_gun(g, id, pal)
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _parts_mesh(ModelData.weapon(id), pal)
		g.add_child(mi)
	_make_sights(g, id)
	return g


func _build_code_gun(g: Node3D, id: String, pal: Dictionary) -> void:
	match id:
		"ak47":
			_box(g, Vector3(0.04, 0.07, 0.34), pal["metal"], Vector3(0.0, 0.07, -0.07))
			_box(g, Vector3(0.034, 0.012, 0.3), pal["dark"], Vector3(0.0, 0.112, -0.09))
			_box(g, Vector3(0.046, 0.06, 0.28), pal["wood"], Vector3(0.0, 0.058, -0.4))
			_box(g, Vector3(0.04, 0.022, 0.24), pal["wood_d"], Vector3(0.0, 0.1, -0.41))
			_box(g, Vector3(0.02, 0.02, 0.3), pal["metal_l"], Vector3(0.0, 0.078, -0.69))
			_box(g, Vector3(0.014, 0.014, 0.28), pal["metal"], Vector3(0.0, 0.102, -0.66))
			_box(g, Vector3(0.026, 0.026, 0.045), pal["dark"], Vector3(0.0, 0.078, -0.87))
			_box(g, Vector3(0.006, 0.04, 0.008), pal["dark"], Vector3(0.0, 0.105, -0.8))
			_box(g, Vector3(0.03, 0.018, 0.02), pal["dark"], Vector3(0.0, 0.122, -0.15))
			_box(g, Vector3(0.03, 0.09, 0.05), pal["metal"], Vector3(0.0, -0.02, -0.14))
			_box(g, Vector3(0.03, 0.08, 0.05), pal["dark"], Vector3(0.0, -0.09, -0.17))
			_box(g, Vector3(0.032, 0.1, 0.04), pal["wood_d"], Vector3(0.0, -0.035, 0.03))
			_box(g, Vector3(0.036, 0.08, 0.22), pal["wood"], Vector3(0.0, 0.045, 0.27))
			_box(g, Vector3(0.04, 0.09, 0.012), pal["dark"], Vector3(0.0, 0.04, 0.386))
		"bazooka":
			var olive := _mat(Color(0.26, 0.33, 0.18), 0.2, 0.6, false)
			var olive_d := _mat(Color(0.19, 0.24, 0.13), 0.2, 0.6, false)
			_cylz(g, 0.055, 1.0, olive, Vector3(0.0, 0.07, -0.35))
			_cylz(g, 0.068, 0.12, pal["dark"], Vector3(0.0, 0.07, 0.2))
			_cylz(g, 0.062, 0.06, pal["dark"], Vector3(0.0, 0.07, -0.86))
			_cylz(g, 0.058, 0.04, olive_d, Vector3(0.0, 0.07, -0.2))
			_cylz(g, 0.058, 0.04, olive_d, Vector3(0.0, 0.07, -0.55))
			var tip := _cyl(g, 0.0, 0.045, 0.14, pal["accent"], Vector3(0.0, 0.07, -0.95))
			tip.rotation.x = -PI * 0.5
			_box(g, Vector3(0.03, 0.1, 0.04), pal["poly"], Vector3(0.0, -0.02, 0.02))
			_box(g, Vector3(0.03, 0.1, 0.04), pal["poly"], Vector3(0.0, -0.02, -0.4))
			_box(g, Vector3(0.07, 0.1, 0.05), pal["poly"], Vector3(0.0, 0.0, 0.27))
			_box(g, Vector3(0.006, 0.03, 0.008), pal["dark"], Vector3(0.012, 0.14, 0.0))
			_box(g, Vector3(0.006, 0.03, 0.008), pal["dark"], Vector3(-0.012, 0.14, 0.0))
			_box(g, Vector3(0.006, 0.035, 0.008), pal["dark"], Vector3(0.0, 0.142, -0.7))
		"revolver":
			_box(g, Vector3(0.03, 0.05, 0.12), pal["metal"], Vector3(0.0, 0.075, -0.03))
			_cylz(g, 0.032, 0.07, pal["metal_l"], Vector3(0.0, 0.07, -0.03))
			_box(g, Vector3(0.02, 0.026, 0.16), pal["metal_l"], Vector3(0.0, 0.088, -0.17))
			_box(g, Vector3(0.012, 0.018, 0.14), pal["dark"], Vector3(0.0, 0.058, -0.16))
			_box(g, Vector3(0.03, 0.09, 0.045), pal["wood"], Vector3(0.0, 0.0, 0.05))
			_box(g, Vector3(0.008, 0.012, 0.01), pal["dark"], Vector3(0.0, 0.108, -0.23))
		"mpistol":
			_box(g, Vector3(0.03, 0.045, 0.2), pal["metal"], Vector3(0.0, 0.08, -0.08))
			_box(g, Vector3(0.024, 0.012, 0.18), pal["dark"], Vector3(0.0, 0.108, -0.08))
			_box(g, Vector3(0.03, 0.09, 0.045), pal["poly"], Vector3(0.0, 0.0, 0.04))
			_box(g, Vector3(0.024, 0.14, 0.035), pal["dark"], Vector3(0.0, -0.06, 0.02))
			_box(g, Vector3(0.016, 0.016, 0.04), pal["metal_l"], Vector3(0.0, 0.082, -0.2))
		"marksman":
			_box(g, Vector3(0.04, 0.07, 0.36), pal["metal"], Vector3(0.0, 0.07, -0.05))
			_box(g, Vector3(0.02, 0.02, 0.46), pal["metal_l"], Vector3(0.0, 0.075, -0.54))
			_box(g, Vector3(0.045, 0.055, 0.3), pal["poly"], Vector3(0.0, 0.065, -0.4))
			_cylz(g, 0.022, 0.2, pal["dark"], Vector3(0.0, 0.145, -0.1))
			_cylz(g, 0.027, 0.03, pal["lens_t"], Vector3(0.0, 0.145, -0.21))
			_box(g, Vector3(0.02, 0.03, 0.03), pal["metal"], Vector3(0.0, 0.115, -0.04))
			_box(g, Vector3(0.03, 0.1, 0.05), pal["dark"], Vector3(0.0, -0.03, -0.1))
			_box(g, Vector3(0.032, 0.1, 0.04), pal["poly"], Vector3(0.0, -0.035, 0.03))
			_box(g, Vector3(0.04, 0.08, 0.24), pal["poly"], Vector3(0.0, 0.04, 0.27))
			_box(g, Vector3(0.026, 0.026, 0.05), pal["dark"], Vector3(0.0, 0.075, -0.78))
		"lmg":
			_box(g, Vector3(0.05, 0.09, 0.4), pal["metal"], Vector3(0.0, 0.07, -0.1))
			_box(g, Vector3(0.07, 0.09, 0.12), pal["dark"], Vector3(0.0, -0.04, -0.12))
			_box(g, Vector3(0.04, 0.04, 0.3), pal["poly"], Vector3(0.0, 0.08, -0.45))
			_box(g, Vector3(0.024, 0.024, 0.5), pal["metal_l"], Vector3(0.0, 0.08, -0.62))
			_box(g, Vector3(0.01, 0.12, 0.01), pal["dark"], Vector3(0.025, 0.02, -0.72))
			_box(g, Vector3(0.01, 0.12, 0.01), pal["dark"], Vector3(-0.025, 0.02, -0.72))
			_box(g, Vector3(0.03, 0.1, 0.04), pal["poly"], Vector3(0.0, -0.035, 0.03))
			_box(g, Vector3(0.04, 0.09, 0.24), pal["poly"], Vector3(0.0, 0.04, 0.3))
			_box(g, Vector3(0.03, 0.03, 0.05), pal["dark"], Vector3(0.0, 0.08, -0.88))
		"vector":
			_box(g, Vector3(0.045, 0.09, 0.3), pal["poly"], Vector3(0.0, 0.06, -0.1))
			_box(g, Vector3(0.04, 0.05, 0.12), pal["metal"], Vector3(0.0, 0.07, -0.3))
			_box(g, Vector3(0.03, 0.14, 0.04), pal["dark"], Vector3(0.0, -0.07, -0.02))
			_box(g, Vector3(0.03, 0.08, 0.03), pal["dark"], Vector3(0.0, -0.02, -0.25))
			_box(g, Vector3(0.02, 0.02, 0.2), pal["metal_l"], Vector3(0.0, 0.07, 0.17))
			_box(g, Vector3(0.036, 0.07, 0.02), pal["poly"], Vector3(0.0, 0.05, 0.28))
			_box(g, Vector3(0.016, 0.016, 0.04), pal["metal_l"], Vector3(0.0, 0.07, -0.38))
		"mp5":
			_box(g, Vector3(0.04, 0.07, 0.3), pal["metal"], Vector3(0.0, 0.07, -0.08))
			_box(g, Vector3(0.034, 0.034, 0.16), pal["metal_l"], Vector3(0.0, 0.075, -0.32))
			_box(g, Vector3(0.04, 0.05, 0.14), pal["poly"], Vector3(0.0, 0.06, -0.26))
			_box(g, Vector3(0.026, 0.14, 0.04), pal["dark"], Vector3(0.0, -0.05, -0.1))
			_box(g, Vector3(0.03, 0.04, 0.22), pal["metal_l"], Vector3(0.0, 0.06, 0.2))
			_box(g, Vector3(0.036, 0.08, 0.015), pal["poly"], Vector3(0.0, 0.05, 0.32))
			_box(g, Vector3(0.03, 0.1, 0.04), pal["poly"], Vector3(0.0, -0.035, 0.03))
			_box(g, Vector3(0.014, 0.014, 0.04), pal["dark"], Vector3(0.0, 0.078, -0.42))
		"doublebarrel":
			_cylz(g, 0.016, 0.62, pal["metal_l"], Vector3(0.018, 0.082, -0.52))
			_cylz(g, 0.016, 0.62, pal["metal_l"], Vector3(-0.018, 0.082, -0.52))
			_box(g, Vector3(0.01, 0.01, 0.6), pal["metal"], Vector3(0.0, 0.1, -0.52))
			_box(g, Vector3(0.05, 0.06, 0.2), pal["metal"], Vector3(0.0, 0.07, -0.1))
			_box(g, Vector3(0.05, 0.04, 0.2), pal["wood"], Vector3(0.0, 0.055, -0.36))
			_box(g, Vector3(0.032, 0.1, 0.04), pal["wood_d"], Vector3(0.0, -0.035, 0.03))
			_box(g, Vector3(0.04, 0.09, 0.3), pal["wood"], Vector3(0.0, 0.03, 0.25))
			_box(g, Vector3(0.006, 0.014, 0.008), pal["dark"], Vector3(0.0, 0.114, -0.82))
		"autoshot":
			_cylz(g, 0.02, 0.6, pal["dark"], Vector3(0.0, 0.088, -0.5))
			_cylz(g, 0.018, 0.5, pal["metal_l"], Vector3(0.0, 0.05, -0.45))
			_box(g, Vector3(0.045, 0.08, 0.28), pal["poly"], Vector3(0.0, 0.07, -0.05))
			_box(g, Vector3(0.05, 0.05, 0.16), pal["poly"], Vector3(0.0, 0.055, -0.4))
			_box(g, Vector3(0.032, 0.1, 0.04), pal["poly"], Vector3(0.0, -0.035, 0.03))
			_box(g, Vector3(0.04, 0.09, 0.25), pal["poly"], Vector3(0.0, 0.03, 0.27))
			_box(g, Vector3(0.012, 0.014, 0.1), pal["metal"], Vector3(0.0, 0.118, -0.1))
		"semisniper":
			_box(g, Vector3(0.045, 0.08, 0.4), pal["dark"], Vector3(0.0, 0.07, -0.05))
			_box(g, Vector3(0.022, 0.022, 0.6), pal["metal_l"], Vector3(0.0, 0.075, -0.6))
			_cylz(g, 0.03, 0.3, pal["dark"], Vector3(0.0, 0.15, -0.12))
			_cylz(g, 0.034, 0.03, pal["lens_t"], Vector3(0.0, 0.15, -0.28))
			_cylz(g, 0.034, 0.03, pal["lens_t"], Vector3(0.0, 0.15, 0.04))
			_box(g, Vector3(0.02, 0.04, 0.03), pal["metal"], Vector3(0.0, 0.11, -0.2))
			_box(g, Vector3(0.02, 0.04, 0.03), pal["metal"], Vector3(0.0, 0.11, 0.0))
			_box(g, Vector3(0.034, 0.1, 0.06), pal["dark"], Vector3(0.0, -0.03, -0.1))
			_box(g, Vector3(0.04, 0.1, 0.28), pal["poly"], Vector3(0.0, 0.035, 0.3))
			_box(g, Vector3(0.032, 0.1, 0.04), pal["poly"], Vector3(0.0, -0.035, 0.03))
			_box(g, Vector3(0.03, 0.03, 0.06), pal["dark"], Vector3(0.0, 0.075, -0.95))
		"antimat":
			_box(g, Vector3(0.06, 0.1, 0.45), pal["metal"], Vector3(0.0, 0.07, -0.05))
			_cylz(g, 0.026, 0.9, pal["metal_l"], Vector3(0.0, 0.085, -0.75))
			_cylz(g, 0.04, 0.18, pal["dark"], Vector3(0.0, 0.085, -1.18))
			_cylz(g, 0.036, 0.35, pal["dark"], Vector3(0.0, 0.17, -0.1))
			_cylz(g, 0.04, 0.03, pal["lens_t"], Vector3(0.0, 0.17, -0.29))
			_cylz(g, 0.04, 0.03, pal["lens_t"], Vector3(0.0, 0.17, 0.09))
			_box(g, Vector3(0.03, 0.05, 0.04), pal["metal"], Vector3(0.0, 0.12, -0.2))
			_box(g, Vector3(0.05, 0.1, 0.1), pal["dark"], Vector3(0.0, -0.03, -0.1))
			_box(g, Vector3(0.01, 0.14, 0.01), pal["dark"], Vector3(0.03, 0.01, -0.85))
			_box(g, Vector3(0.01, 0.14, 0.01), pal["dark"], Vector3(-0.03, 0.01, -0.85))
			_box(g, Vector3(0.045, 0.11, 0.3), pal["poly"], Vector3(0.0, 0.03, 0.34))
			_box(g, Vector3(0.032, 0.1, 0.04), pal["poly"], Vector3(0.0, -0.035, 0.05))
		"gl":
			var olive := _mat(Color(0.26, 0.33, 0.18), 0.2, 0.6, false)
			_cylz(g, 0.05, 0.5, pal["dark"], Vector3(0.0, 0.07, -0.3))
			_cylz(g, 0.07, 0.12, pal["metal_l"], Vector3(0.0, 0.07, -0.02))
			_cylz(g, 0.055, 0.04, olive, Vector3(0.0, 0.07, -0.56))
			_box(g, Vector3(0.036, 0.12, 0.045), pal["wood"], Vector3(0.0, -0.03, 0.05))
			_box(g, Vector3(0.03, 0.1, 0.04), pal["poly"], Vector3(0.0, -0.02, -0.3))
			_box(g, Vector3(0.04, 0.07, 0.2), pal["wood_d"], Vector3(0.0, 0.04, 0.2))
			_box(g, Vector3(0.006, 0.03, 0.008), pal["dark"], Vector3(0.0, 0.14, -0.5))
		"minigun":
			for k in 6:
				var a := float(k) * TAU / 6.0
				_cylz(g, 0.012, 0.62, pal["metal_l"], Vector3(cos(a) * 0.035, 0.08 + sin(a) * 0.035, -0.58))
			_cylz(g, 0.065, 0.05, pal["dark"], Vector3(0.0, 0.08, -0.3))
			_cylz(g, 0.065, 0.05, pal["dark"], Vector3(0.0, 0.08, -0.85))
			_cylz(g, 0.06, 0.34, pal["metal"], Vector3(0.0, 0.08, -0.08))
			_box(g, Vector3(0.1, 0.14, 0.2), pal["olive"] if pal.has("olive") else pal["dark"], Vector3(0.0, -0.1, 0.0))
			_box(g, Vector3(0.03, 0.1, 0.04), pal["poly"], Vector3(0.0, -0.035, 0.1))
			_box(g, Vector3(0.03, 0.1, 0.04), pal["poly"], Vector3(0.0, -0.03, -0.3))
		"potato":
			var pipe := _mat(Color(0.82, 0.84, 0.86), 0.0, 0.5, false)
			var tape := _mat(Color(0.85, 0.2, 0.15), 0.0, 0.6, false)
			_cylz(g, 0.045, 0.62, pipe, Vector3(0.0, 0.07, -0.43))
			_cylz(g, 0.062, 0.26, pal["dark"], Vector3(0.0, 0.07, -0.03))
			_cylz(g, 0.066, 0.03, pipe, Vector3(0.0, 0.07, 0.115))
			_cylz(g, 0.052, 0.04, pipe, Vector3(0.0, 0.07, -0.74))
			_cylz(g, 0.048, 0.03, tape, Vector3(0.0, 0.07, -0.25))
			_cylz(g, 0.048, 0.03, tape, Vector3(0.0, 0.07, -0.55))
			_box(g, Vector3(0.022, 0.03, 0.022), tape, Vector3(0.0, 0.138, 0.0))
			_box(g, Vector3(0.036, 0.12, 0.045), pal["wood"], Vector3(0.0, -0.03, 0.05))
			_box(g, Vector3(0.04, 0.07, 0.16), pal["wood_d"], Vector3(0.0, 0.04, 0.2))
			_box(g, Vector3(0.006, 0.03, 0.008), pal["dark"], Vector3(0.0, 0.13, -0.7))


static func extra_palette() -> Dictionary:
	var mk := func(c: Color, metallic: float, rough: float, glow: float = 0.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = metallic
		m.roughness = rough
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
		return m
	return {
		"metal": mk.call(Color(0.23, 0.235, 0.26), 0.6, 0.4),
		"metal_l": mk.call(Color(0.44, 0.46, 0.49), 0.7, 0.35),
		"steel": mk.call(Color(0.62, 0.65, 0.7), 0.8, 0.3),
		"poly": mk.call(Color(0.18, 0.18, 0.17), 0.1, 0.8),
		"dark": mk.call(Color(0.11, 0.11, 0.12), 0.3, 0.7),
		"wood": mk.call(Color(0.41, 0.25, 0.13), 0.0, 0.7),
		"wood_d": mk.call(Color(0.31, 0.19, 0.1), 0.0, 0.7),
		"leather": mk.call(Color(0.36, 0.24, 0.15), 0.0, 0.8),
		"accent": mk.call(Color(1.0, 0.7, 0.25), 0.0, 0.5),
		"olive": mk.call(Color(0.26, 0.33, 0.18), 0.2, 0.6),
		"olive_d": mk.call(Color(0.19, 0.24, 0.13), 0.2, 0.6),
		"glass": mk.call(Color(0.18, 0.44, 0.24), 0.1, 0.25),
		"label": mk.call(Color(0.89, 0.84, 0.69), 0.0, 0.9),
		"cloth": mk.call(Color(0.87, 0.82, 0.66), 0.0, 0.95),
		"flame": mk.call(Color(1.0, 0.6, 0.15), 0.0, 0.5, 6.0),
	}


static func extra_mesh(id: String) -> ArrayMesh:
	return _parts_mesh(ModelDataB.weapon(id), extra_palette())


func _build_extra(g: Node3D, id: String, pal: Dictionary) -> void:
	var olive := _mat(Color(0.22, 0.3, 0.16), 0.2, 0.6, false)
	var glass := _mat(Color(0.2, 0.45, 0.25), 0.1, 0.3, false)
	var cloth := _mat(Color(0.85, 0.8, 0.65), 0.0, 0.9, false)
	match id:
		"knife":
			_box(g, Vector3(0.026, 0.03, 0.11), pal["poly"], Vector3(0.0, 0.0, 0.02))
			_box(g, Vector3(0.05, 0.014, 0.014), pal["metal"], Vector3(0.0, 0.0, -0.04))
			_box(g, Vector3(0.01, 0.034, 0.2), pal["metal_l"], Vector3(0.0, 0.004, -0.15))
		"machete":
			_box(g, Vector3(0.03, 0.034, 0.13), pal["wood"], Vector3(0.0, 0.0, 0.03))
			_box(g, Vector3(0.05, 0.022, 0.015), pal["metal"], Vector3(0.0, 0.0, -0.045))
			_box(g, Vector3(0.01, 0.075, 0.52), pal["metal_l"], Vector3(0.0, 0.0, -0.31))
			_box(g, Vector3(0.016, 0.012, 0.52), pal["dark"], Vector3(0.0, 0.04, -0.31))
		"axe":
			_box(g, Vector3(0.03, 0.03, 0.62), pal["wood"], Vector3(0.0, 0.0, -0.14))
			_box(g, Vector3(0.04, 0.12, 0.12), pal["metal"], Vector3(0.0, 0.0, -0.43))
			_box(g, Vector3(0.014, 0.2, 0.035), pal["metal_l"], Vector3(0.0, 0.0, -0.5))
			_box(g, Vector3(0.03, 0.06, 0.06), pal["dark"], Vector3(0.0, 0.0, -0.37))
		"grenade":
			_sph(g, 0.055, olive)
			_cyl(g, 0.014, 0.014, 0.03, pal["metal_l"], Vector3(0.0, 0.062, 0.0))
			_box(g, Vector3(0.01, 0.012, 0.055), pal["metal_l"], Vector3(0.0, 0.08, 0.015))
		"molotov":
			_cyl(g, 0.045, 0.045, 0.15, glass, Vector3.ZERO)
			_cyl(g, 0.015, 0.022, 0.07, glass, Vector3(0.0, 0.105, 0.0))
			_cyl(g, 0.013, 0.013, 0.06, cloth, Vector3(0.0, 0.16, 0.0))
			_sph(g, 0.03, _glow(Color(1.0, 0.6, 0.15), 6.0), Vector3(0.0, 0.205, 0.0), Vector3(0.8, 1.4, 0.8))
		"katana":
			_box(g, Vector3(0.026, 0.03, 0.2), pal["dark"], Vector3(0.0, 0.0, 0.04))
			_box(g, Vector3(0.05, 0.05, 0.012), pal["metal"], Vector3(0.0, 0.0, -0.065))
			_box(g, Vector3(0.008, 0.04, 0.62), pal["metal_l"], Vector3(0.0, 0.004, -0.38))
			_box(g, Vector3(0.012, 0.01, 0.62), pal["dark"], Vector3(0.0, 0.026, -0.38))
		"bat":
			_cylz(g, 0.02, 0.2, pal["wood_d"], Vector3(0.0, 0.0, 0.05))
			_cylz(g, 0.032, 0.3, pal["wood"], Vector3(0.0, 0.0, -0.2))
			_cylz(g, 0.042, 0.28, pal["wood"], Vector3(0.0, 0.0, -0.48))
			_cylz(g, 0.03, 0.03, pal["wood_d"], Vector3(0.0, 0.0, 0.16))
		"dynamite":
			var red := _mat(Color(0.75, 0.12, 0.1), 0.0, 0.7, false)
			for k in 3:
				_cyl(g, 0.02, 0.02, 0.2, red, Vector3((float(k) - 1.0) * 0.042, 0.0, 0.0))
			_box(g, Vector3(0.14, 0.03, 0.03), pal["dark"], Vector3(0.0, 0.03, 0.0))
			_cyl(g, 0.004, 0.004, 0.1, cloth, Vector3(0.0, 0.14, 0.0))
		"tknife":
			_box(g, Vector3(0.02, 0.024, 0.09), pal["dark"], Vector3(0.0, 0.0, 0.02))
			_box(g, Vector3(0.007, 0.03, 0.17), pal["metal_l"], Vector3(0.0, 0.0, -0.11))


func _make_sights(g: Node3D, id: String) -> void:
	var s := _node(g)
	var dark := _mat(Color(0.07, 0.07, 0.08), 0.5, 0.5, false)
	var tip := _mat(_accent, 0.0, 0.5, false)
	match id:
		"rifle", "smg":
			var by := 0.122 if id == "rifle" else 0.12
			var z := -0.05
			_box(s, Vector3(0.03, 0.013, 0.07), dark, Vector3(0, by + 0.0065, z))
			_box(s, Vector3(0.004, 0.03, 0.05), dark, Vector3(0.017, by + 0.028, z))
			_box(s, Vector3(0.004, 0.03, 0.05), dark, Vector3(-0.017, by + 0.028, z))
			_box(s, Vector3(0.038, 0.004, 0.05), dark, Vector3(0, by + 0.045, z))
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.5, 0.75, 1.0, 0.16)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.cull_mode = BaseMaterial3D.CULL_DISABLED
			_box(s, Vector3(0.03, 0.028, 0.001), glass, Vector3(0, by + 0.028, z - 0.022))
			_sph(s, 0.0035, _glow(Color(1.0, 0.12, 0.08), 5.0), Vector3(0, by + 0.028, z - 0.02))
		"pistol":
			_box(s, Vector3(0.005, 0.014, 0.008), dark, Vector3(0.0085, 0.083, 0.02))
			_box(s, Vector3(0.005, 0.014, 0.008), dark, Vector3(-0.0085, 0.083, 0.02))
			_box(s, Vector3(0.004, 0.017, 0.006), tip, Vector3(0, 0.0815, -0.16))
		"shotgun":
			_box(s, Vector3(0.005, 0.014, 0.008), dark, Vector3(0.009, 0.107, 0.02))
			_box(s, Vector3(0.005, 0.014, 0.008), dark, Vector3(-0.009, 0.107, 0.02))
			_box(s, Vector3(0.004, 0.013, 0.006), tip, Vector3(0, 0.1075, -0.83))
		"lmg", "vector", "mp5", "minigun", "revolver", "mpistol", "doublebarrel", "autoshot", "gl", "marksman":
			_extra_sights(s, id, dark, tip)
	for c in s.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.visible = _first_person
	_fp_only.append(s)


static func _def_by_id(id: String) -> Dictionary:
	for d in Weapons.LIST:
		if String(d["id"]) == id:
			return d
	return {}


func _extra_sights(s: Node3D, id: String, dark: Material, tip: Material) -> void:
	var wd := _def_by_id(id)
	var sh := float(wd.get("sight_h", 0.14))
	var sz := float(wd.get("sight_z", 0.0))
	var mz := float((wd.get("muzzle", Vector3.ZERO) as Vector3).z)
	if id in ["revolver", "mpistol", "doublebarrel", "autoshot", "gl"]:
		_box(s, Vector3(0.005, 0.014, 0.008), dark, Vector3(0.009, sh - 0.007, sz))
		_box(s, Vector3(0.005, 0.014, 0.008), dark, Vector3(-0.009, sh - 0.007, sz))
		_box(s, Vector3(0.004, 0.015, 0.006), tip, Vector3(0.0, sh - 0.0065, mz + 0.04))
		return
	if id == "marksman":
		_sph(s, 0.0035, _glow(Color(1.0, 0.12, 0.08), 5.0), Vector3(0.0, sh - 0.015, -0.12))
		return
	var by := sh - 0.028
	var z := sz + 0.022
	_box(s, Vector3(0.03, 0.013, 0.07), dark, Vector3(0.0, by + 0.0065, z + 0.02))
	_box(s, Vector3(0.004, 0.03, 0.05), dark, Vector3(0.017, by + 0.028, z + 0.02))
	_box(s, Vector3(0.004, 0.03, 0.05), dark, Vector3(-0.017, by + 0.028, z + 0.02))
	_box(s, Vector3(0.038, 0.004, 0.05), dark, Vector3(0.0, by + 0.045, z + 0.02))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.5, 0.75, 1.0, 0.16)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_box(s, Vector3(0.03, 0.028, 0.001), glass, Vector3(0.0, by + 0.028, z - 0.002))
	_sph(s, 0.0035, _glow(Color(1.0, 0.12, 0.08), 5.0), Vector3(0.0, by + 0.028, z))


func fire_effect(strength: float = 1.0) -> void:
	_recoil = clampf(strength, 0.0, 2.0)
	_flash_t = 0.05


func hit() -> void:
	_hit = 1.0


func attack(def: Dictionary) -> void:
	_atk_style = String(def.get("swing", "slash"))
	_atk_dur = float(def.get("dur", 0.4))
	_atk_t = 0.0
	var hit_time := float(def.get("hit_t", def.get("release_t", _atk_dur * 0.5)))
	_atk_hit = clampf(hit_time / maxf(_atk_dur, 0.05), 0.3, 0.7)


func die(push: Vector3 = Vector3.ZERO) -> void:
	if _dead:
		return
	_dead = true
	_dead_t = 0.0
	_atk_t = -1.0
	_sh[0].scale = Vector3.ONE
	_sh[1].scale = Vector3.ONE
	_make_ragdoll(push)
	if not _ragdolled:
		_hips.position = Vector3(0, HIP_Y, 0)


func animate(delta: float, speed_in: float, _fwd_sign: float, aim_target: float, aim_dir: Vector3) -> void:
	_time += delta
	_recoil = maxf(0.0, _recoil - delta * 8.0)
	_hit = maxf(0.0, _hit - delta * 3.5)
	_swap = maxf(0.0, _swap - delta * 4.5)
	if _atk_t >= 0.0:
		_atk_t += delta / maxf(_atk_dur, 0.05)
		if _atk_t >= 1.0:
			_atk_t = -1.0
	_flash_t -= delta
	if _flash_mesh:
		_flash_mesh.visible = _flash_t > 0.0
	var em := Color(1.0, 0.25, 0.2) * (_hit * 0.8)
	for m in _body_mats:
		m.emission = em

	if _dead:
		_animate_dead(delta)
		return
	if delta <= 0.0:
		return

	var yr := 0.0
	if _has_prev:
		var raw := (global_position - _prev_pos) / delta
		raw.y = 0.0
		_vel = _vel.lerp(raw, 1.0 - exp(-10.0 * delta))
		yr = wrapf(rotation.y - _prev_yaw, -PI, PI) / delta
	_prev_pos = global_position
	_prev_yaw = rotation.y
	_has_prev = true
	_spd = lerpf(_spd, speed_in, 1.0 - exp(-12.0 * delta))
	var spd := _spd
	if _vel.length() > 0.01:
		_vel = _vel.normalized() * spd
	var lv := global_basis.inverse() * _vel
	var k := minf(1.0, 8.0 * delta)
	_lat = lerpf(_lat, clampf(lv.x / max_speed, -1.0, 1.0), k)
	_fwdc = lerpf(_fwdc, clampf(-lv.z / max_speed, -1.0, 1.0), k)
	_yr = lerpf(_yr, clampf(yr, -12.0, 12.0), k)
	_aim = move_toward(_aim, aim_target, 7.0 * delta)
	_fp_s = move_toward(_fp_s, 1.0 if _first_person else 0.0, 6.0 * delta)
	var pr := smoothstep(0.0, 1.0, prone)
	var rf := clampf((spd - 3.2) / 2.8, 0.0, 1.0) * (1.0 - crouch) * (1.0 - pr)
	var lean := 1.0 - 0.9 * _fp_s

	if airborne:
		_vy_last = vspeed
	elif _was_air:
		_land = clampf(absf(_vy_last) / 9.0, 0.3, 1.0)
	_was_air = airborne
	_land = maxf(0.0, _land - delta * 4.0)
	var cr := crouch

	var f := -global_basis.z
	f.y = 0.0
	f = f.normalized() if f.length() > 0.001 else Vector3.FORWARD
	var rt := f.cross(Vector3.UP)
	var gp := global_position
	var model_yaw := atan2(-f.x, -f.z)

	_update_feet(delta, gp, rt, f, model_yaw, spd)

	var ab := _atk_body() * lerpf(1.0, 0.15, _fp_s)
	var mid := (_fp[0] + _fp[1]) * 0.5
	var pelv_xz := Vector3(gp.x, 0, gp.z).lerp(Vector3(mid.x, 0, mid.z), 0.35) - f * (0.07 * cr) + f * ab.z
	var sr := clampf(spd / 4.0, 0.0, 1.0) * (1.0 - cr * 0.6)
	var hj := lerpf(0.77, 0.69, sr) - _aim * 0.01
	hj = lerpf(hj, 0.5, cr) - _land * 0.14
	var target_y := gp.y + ANK_H + hj
	var lmax := (LT + LS) * 0.985
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var hip_xz := pelv_xz + rt * side * 0.095
		var h := Vector2(hip_xz.x - _fp[i].x, hip_xz.z - _fp[i].z).length()
		var reach := sqrt(maxf(0.04, lmax * lmax - h * h))
		if _st[i] < 0.0 or _st[i] < 0.5:
			target_y = minf(target_y, _fp[i].y + ANK_H + reach)
	target_y = maxf(target_y, gp.y + ANK_H + hj - 0.1)
	if _st[0] >= 0.0 and _st[1] >= 0.0:
		target_y += 0.05
	var pk := 120.0 if airborne else 32.0
	_pelv_y = lerpf(_pelv_y, target_y + 0.05, 1.0 - exp(-pk * delta))
	_hips.global_position = Vector3(pelv_xz.x, _pelv_y, pelv_xz.z)

	var swr := _swing(0)
	var swl := _swing(1)
	var o_r := (_fp[0] - gp).dot(f)
	var o_l := (_fp[1] - gp).dot(f)
	var tw := clampf((o_r - o_l) * 0.4, -0.32, 0.32)
	var shift := sin(_time * 0.7)
	var idle := 1.0 - sr
	_hips.rotation = Vector3(
		-0.03 - (0.1 * _fwdc + 0.18 * cr + 0.14 * rf) * lean,
		tw * 1.3,
		-(swr - swl) * 0.06 * lean + shift * 0.012 * idle)
	if pr > 0.001:
		var crawl := clampf(spd / 1.3, 0.0, 1.0)
		var sway := sin(_time * 5.0) * 0.07 * crawl
		_hips.rotation = Vector3(lerpf(_hips.rotation.x, -PI * 0.5, pr), lerpf(_hips.rotation.y, 0.0, pr), lerpf(_hips.rotation.z, sway, pr))
		_hips.global_position = _hips.global_position.lerp(Vector3(gp.x, gp.y + 0.2, gp.z) - f * 0.32, pr)

	var an := aim_dir.normalized()
	var la0 := global_basis.inverse() * an
	var ay0 := atan2(-la0.x, -la0.z)
	var ap_t := asin(clampf(la0.y, -1.0, 1.0)) * _aim * lerpf(1.0, 0.2, _fp_s)
	_ap = lerpf(_ap, ap_t, minf(1.0, 14.0 * delta))
	var ap_s := clampf(_ap * 0.25, -0.35, 0.35)
	var ap_u := clampf(_ap * 0.4, -0.55, 0.55)

	var br := sin(_time * 2.2)
	_spine.rotation = Vector3(
		-(0.2 * _fwdc + 0.22 * cr + 0.2 * rf) * lean - _hit * 0.2 + ap_s - ab.y * 0.55,
		-tw * lerpf(0.9, 1.3, _fp_s) - clampf(_yr * 0.04, -0.3, 0.3) * lean,
		(-_lat * 0.1 + (swr - swl) * 0.03) * lean)
	var uy_target := clampf(ay0 * 0.6, -0.6, 0.6) * _aim - tw * 0.1 + ab.x
	_uy = lerp_angle(_uy, uy_target, minf(1.0, 10.0 * delta))
	_upper.rotation = Vector3(-0.04 * _fwdc * lean + _recoil * 0.06 - _hit * 0.1 + ap_u - ab.y * 0.45, _uy, 0.0)
	_chest.scale = Vector3(1.0 + br * 0.01, 1.0 + br * 0.014, 1.0 + br * 0.012)

	var la := _upper.global_basis.inverse() * an
	var ay := atan2(-la.x, -la.z)
	var look_y := clampf(ay * 0.85, -0.9, 0.9) * _aim + sin(_time * 0.45) * 0.25 * (1.0 - _aim)
	_head.rotation.y = lerp_angle(_head.rotation.y, look_y, minf(1.0, 9.0 * delta))
	var pitch := asin(clampf(la.y, -1.0, 1.0))
	var head_x := clampf(pitch, -0.8, 0.8) * 0.9 - (_upper.rotation.x - ap_u) * 0.6
	_head.rotation.x = lerpf(_head.rotation.x, head_x, minf(1.0, 12.0 * delta))
	_head.rotation.z = -(_spine.rotation.z) * 0.6
	if pr > 0.001:
		_spine.rotation = Vector3(lerpf(_spine.rotation.x, 0.28, pr), lerpf(_spine.rotation.y, 0.0, pr), lerpf(_spine.rotation.z, 0.0, pr))
		_upper.rotation = Vector3(lerpf(_upper.rotation.x, clampf(_ap * 0.3, -0.3, 0.45), pr), lerpf(_upper.rotation.y, 0.0, pr), lerpf(_upper.rotation.z, _uy * 0.9, pr))
		_head.rotation = Vector3(lerpf(_head.rotation.x, 1.05 + clampf(pitch, -0.6, 0.6) * 0.6, pr), lerpf(_head.rotation.y, 0.0, pr), lerpf(_head.rotation.z, 0.0, pr))

	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var fb := Basis(Vector3.UP, _fyaw[i])
		var ff := fb * Vector3(0, 0, -1)
		var pole := ff + rt * side * 0.12
		_solve_limb(_thigh[i], _knee[i], _fp[i] + Vector3.UP * ANK_H, pole, ff, LT, LS)
		_ankle[i].global_basis = fb * Basis(Vector3.RIGHT, _fpitch[i])
		if pr > 0.001:
			var splay := side * 0.1
			var crawl_k := clampf(spd / 1.3, 0.0, 1.0)
			var kick := sin(_time * 5.0 + (0.0 if i == 0 else PI)) * 0.25 * crawl_k
			_thigh[i].basis = _thigh[i].basis.slerp(Basis.from_euler(Vector3(kick, 0.0, splay)), pr)
			_knee[i].basis = _knee[i].basis.slerp(Basis.from_euler(Vector3(maxf(0.0, -kick) * 0.8, 0.0, 0.0)), pr)
			_ankle[i].basis = _ankle[i].basis.slerp(Basis.IDENTITY, pr)

	var sc: Vector3 = _upper.global_transform * Vector3(0, SH_Y, 0)
	if _fp_s > 0.0:
		sc = sc.lerp(cam_xf.origin + cam_xf.basis * FP_ANCHOR, _fp_s)
	var ur := _upper.global_basis.x.normalized()
	var uf := -_upper.global_basis.z.normalized()
	var gan := an.lerp(-cam_xf.basis.z.normalized(), _fp_s).normalized()
	var ra := gan.cross(Vector3.UP)
	ra = ra.normalized() if ra.length() > 0.01 else ur
	var aim_pos := sc + ra * _hold.x + Vector3.UP * _hold.y + gan * _hold.z - gan * _recoil * 0.09
	aim_pos += (gan * FP_HIP_SHIFT.z + Vector3.UP * FP_HIP_SHIFT.y + ra * FP_HIP_SHIFT.x) * _fp_s
	var aim_d := (gan + Vector3.UP * _recoil * 0.1).normalized()
	var carry_d := (gan + Vector3.DOWN * 0.45).normalized()
	var carry_pos := sc + carry_d * _carry_z + ur * _hold.x + Vector3.UP * (_hold.y - 0.1)
	if _one_hand:
		carry_d = (gan + Vector3.UP * _carry_up).normalized()
		carry_pos = sc + gan * _carry_off.z + ur * _carry_off.x + Vector3.UP * _carry_off.y
	var aim_k := 0.0 if _one_hand else _aim
	var gpos := carry_pos.lerp(aim_pos, aim_k) + Vector3.UP * br * 0.003
	var gsw := (swr - swl) * (1.0 - _aim * 0.7) * (1.0 - 0.8 * _fp_s) * (1.0 + 1.6 * rf)
	gpos += ur * gsw * 0.03 + Vector3.UP * absf(gsw) * 0.02
	gpos += Vector3.DOWN * _swap * 0.25
	var gdir := carry_d.lerp(aim_d, aim_k).normalized()
	gdir = (gdir + Vector3.DOWN * _swap * 0.5).normalized()
	var roll := 0.0
	var shr := sc + ur * SH_X
	var shl := sc - ur * SH_X
	if _atk_t >= 0.0:
		var pose := _attack_pose(_atk_t, gpos, gdir, shr, ra, gan)
		gpos = pose[0]
		gdir = pose[1]
		roll = pose[2]
	var rp := reload_p
	if rp >= 0.0:
		var rk := smoothstep(0.0, 0.14, rp) * (1.0 - smoothstep(0.88, 1.0, rp))
		gpos += Vector3.DOWN * rk * 0.14 - gan * rk * 0.05
		gdir = (gdir + Vector3.UP * rk * 0.45).normalized()
		roll = rk * 0.35
		if rp > 0.8 and rp < 0.9:
			gpos += Vector3.UP * 0.03 * sin((rp - 0.8) / 0.1 * PI)
		if rp >= 0.9:
			gpos -= gan * 0.06 * sin((rp - 0.9) / 0.1 * PI)
	_ads_s = move_toward(_ads_s, ads if _fp_s > 0.5 else 0.0, 7.0 * delta)
	var adsb := smoothstep(0.0, 1.0, _ads_s)
	if adsb > 0.001:
		var cfw := -cam_xf.basis.z
		var cup := cam_xf.basis.y
		var apos := cam_xf.origin + cfw * (_ads_d + _sight_z - _recoil * 0.035) - cup * _sight_h
		gpos = gpos.lerp(apos, adsb)
		gdir = gdir.lerp(cfw, adsb).normalized()
	var pen := 0.0
	if is_inside_tree() and not _dead and _gun != null:
		var glen := (maxf(0.3, -muzzle.position.z) if muzzle != null else 0.6) + 0.1
		var tip := gpos + gdir * glen
		var space := get_world_3d().direct_space_state
		for off in [0.0, 0.14, -0.14]:
			var side := ur * float(off)
			var rq := PhysicsRayQueryParameters3D.create(sc + side, tip + side, 1)
			var rh := space.intersect_ray(rq)
			if not rh.is_empty():
				pen = maxf(pen, clampf(tip.distance_to(rh["position"] - side) / glen, 0.0, 1.0))
		pen = clampf(pen * 1.35, 0.0, 1.0)
	_wall_pb = lerpf(_wall_pb, pen, 1.0 - exp(-(22.0 if pen > _wall_pb else 9.0) * delta))
	if _wall_pb > 0.004:
		var wf := smoothstep(0.0, 1.0, _wall_pb)
		gpos -= gdir * wf * 0.3
		gpos += Vector3.DOWN * wf * 0.16
		gdir = (gdir + Vector3.UP * wf * 1.5 + ra * wf * 0.35).normalized()
		roll += wf * 0.35
	var gup := Vector3.UP
	if roll != 0.0:
		gup = Vector3.UP.rotated(gdir, roll)
	if absf(gdir.dot(gup)) > 0.97:
		gup = ra
	var gun_xf := Transform3D(Basis.looking_at(gdir, gup), gpos)
	var gl := global_transform.affine_inverse() * gun_xf
	if not _gun_ready:
		_gun_l = gl
		_gun_ready = true
	var gk := 1.0 - exp(-(600.0 if _atk_t >= 0.0 else lerpf(GUN_SMOOTH, 600.0, _fp_s)) * delta)
	var gq := Quaternion(_gun_l.basis.orthonormalized()).slerp(Quaternion(gl.basis.orthonormalized()), gk)
	_gun_l = Transform3D(Basis(gq), _gun_l.origin.lerp(gl.origin, gk))
	gun_xf = global_transform * _gun_l
	if _gun_models.has(_wid):
		var released := _atk_t >= 0.0 and _atk_style == "throw" and _atk_t > _atk_hit
		(_gun_models[_wid] as Node3D).visible = not released
	_gun.visible = not (_scoped and adsb > 0.92)

	var grip_r: Vector3 = gun_xf * _grip_r
	var grip_l: Vector3 = gun_xf * _grip_l
	if _one_hand and not _two_hand:
		grip_l = sc - ur * 0.17 + Vector3.DOWN * 0.3 + uf * 0.28 + Vector3.UP * br * 0.004
		if _atk_t >= 0.0:
			grip_l = _attack_left(_atk_t, grip_l, shl, ra, gan)
	if rp >= 0.0 and not _one_hand:
		grip_l = _reload_hand(rp, grip_l, gun_xf, sc, ur, uf)
	_update_mag_prop(rp)
	_solve_limb(_sh[0], _el[0], grip_r, ur * 0.7 + Vector3.DOWN, f, L1, L2, _arm_stretch(_sh[0].global_position, grip_r))
	_solve_limb(_sh[1], _el[1], grip_l, -ur * 0.7 + Vector3.DOWN, f, L1, L2, _arm_stretch(_sh[1].global_position, grip_l))
	_hand[0].global_basis = gun_xf.basis
	_hand[1].global_basis = _upper.global_basis if (_one_hand and not _two_hand) else gun_xf.basis
	_gun.global_transform = gun_xf


func _reload_hand(rp: float, grip0: Vector3, gun_xf: Transform3D, sc: Vector3, ur: Vector3, uf: Vector3) -> Vector3:
	var well := gun_xf * Vector3(0.0, -0.12, -0.08)
	var belt := sc - ur * 0.12 + Vector3.DOWN * 0.6 + uf * 0.22
	if rp < 0.18:
		return grip0.lerp(well, smoothstep(0.0, 0.18, rp))
	if rp < 0.4:
		return well.lerp(belt, smoothstep(0.18, 0.4, rp))
	if rp < 0.62:
		return belt + ur * sin((rp - 0.4) / 0.22 * PI) * 0.04
	if rp < 0.8:
		return belt.lerp(well, smoothstep(0.62, 0.8, rp))
	if rp < 0.9:
		return well + Vector3.UP * 0.03 * sin((rp - 0.8) / 0.1 * PI)
	return well.lerp(grip0, smoothstep(0.9, 1.0, rp))


func _update_mag_prop(rp: float) -> void:
	if _mag_prop == null:
		return
	_mag_prop.visible = rp >= 0.2 and rp < 0.82


func _atk_phases() -> Vector3:
	var ph := _atk_hit
	var ws := ph * 0.6
	var se := ph + (0.08 if _atk_style == "slash" else 0.0)
	return Vector3(ws, se, se + 0.14)


func _atk_body() -> Vector3:
	if _atk_t < 0.0:
		return Vector3.ZERO
	var ph := _atk_phases()
	var tw := Vector2(-0.3, 0.25)
	var ln := Vector2(0.05, 0.28)
	var sh := Vector2(-0.04, 0.16)
	match _atk_style:
		"slash":
			tw = Vector2(-0.45, 0.55)
			ln = Vector2(0.05, 0.2)
			sh = Vector2(-0.03, 0.1)
		"chop":
			tw = Vector2(-0.1, 0.12)
			ln = Vector2(-0.2, 0.42)
			sh = Vector2(-0.05, 0.14)
		"throw":
			tw = Vector2(-0.5, 0.45)
			ln = Vector2(-0.2, 0.35)
			sh = Vector2(-0.1, 0.12)
	var wu := smoothstep(0.0, ph.x, _atk_t)
	var st := smoothstep(ph.x, ph.y, _atk_t)
	var rc := smoothstep(ph.z, 1.0, _atk_t)
	var out := Vector3(
		lerpf(tw.x * wu, tw.y, st),
		lerpf(ln.x * wu, ln.y, st),
		lerpf(sh.x * wu, sh.y, st))
	return out.lerp(Vector3.ZERO, rc)


func _attack_pose(p: float, base_pos: Vector3, base_dir: Vector3, shr: Vector3, ra: Vector3, fwd: Vector3) -> Array:
	var up := ra.cross(fwd)
	var wp: Vector3
	var wd: Vector3
	var mp: Vector3
	var md: Vector3
	var ep: Vector3
	var ed: Vector3
	var fp: Vector3
	var fd: Vector3
	var r_m := 0.0
	var r_e := 0.0
	match _atk_style:
		"stab":
			wp = shr + fwd * 0.08 + ra * 0.1 - up * 0.13
			wd = (fwd + ra * 0.2).normalized()
			mp = shr + fwd * 0.3 + ra * 0.05 - up * 0.07
			md = fwd
			ep = shr + fwd * 0.5 - up * 0.03
			ed = (fwd - up * 0.04).normalized()
			fp = shr + fwd * 0.46 - up * 0.07
			fd = (fwd - up * 0.1).normalized()
		"chop":
			wp = shr - fwd * 0.04 + ra * 0.16 + up * 0.3
			wd = (up + ra * 0.45 - fwd * 0.3).normalized()
			mp = shr + fwd * 0.28 + ra * 0.05 + up * 0.22
			md = (fwd * 0.9 + up * 0.25).normalized()
			ep = shr + fwd * 0.44 - up * 0.26
			ed = (fwd * 0.75 - up * 0.75).normalized()
			fp = shr + fwd * 0.4 - up * 0.32
			fd = (fwd * 0.4 - up * 0.9).normalized()
		"throw":
			wp = shr - fwd * 0.18 + ra * 0.15 + up * 0.26
			wd = (fwd * 0.4 + up * 0.6).normalized()
			mp = shr + fwd * 0.1 + ra * 0.08 + up * 0.38
			md = fwd
			ep = shr + fwd * 0.4 + ra * 0.03 + up * 0.3
			ed = (fwd + up * 0.2).normalized()
			fp = shr + fwd * 0.34 - ra * 0.08 - up * 0.12
			fd = (fwd - up * 0.3).normalized()
		_:
			wp = shr + fwd * 0.16 + ra * 0.22 + up * 0.28
			wd = (up * 0.9 + ra * 0.4 + fwd * 0.3).normalized()
			mp = shr + fwd * 0.42 + ra * 0.02 + up * 0.08
			md = (fwd * 0.9 - ra * 0.25 - up * 0.1).normalized()
			ep = shr + fwd * 0.42 - ra * 0.2 - up * 0.14
			ed = (fwd * 0.8 - ra * 0.55 - up * 0.3).normalized()
			fp = shr + fwd * 0.32 - ra * 0.28 - up * 0.22
			fd = (fwd * 0.5 - ra * 0.6 - up * 0.4).normalized()
			r_m = 0.2
			r_e = 0.45
	var ph := _atk_phases()
	var pos: Vector3
	var dir: Vector3
	var roll := 0.0
	if p < ph.x:
		var t := smoothstep(0.0, 1.0, p / ph.x)
		pos = base_pos.lerp(wp, t)
		if _atk_style == "chop":
			pos += ra * 0.16 * sin(t * PI) - fwd * 0.04 * sin(t * PI)
		dir = base_dir.slerp(wd, t)
	elif p < ph.y:
		var t2 := (p - ph.x) / (ph.y - ph.x)
		t2 = pow(t2, 1.5)
		pos = wp.lerp(mp, t2).lerp(mp.lerp(ep, t2), t2)
		if t2 < 0.5:
			dir = wd.slerp(md, t2 * 2.0)
			roll = lerpf(0.0, r_m, t2 * 2.0)
		else:
			dir = md.slerp(ed, t2 * 2.0 - 1.0)
			roll = lerpf(r_m, r_e, t2 * 2.0 - 1.0)
	elif p < ph.z:
		var t3 := smoothstep(0.0, 1.0, (p - ph.y) / (ph.z - ph.y))
		pos = ep.lerp(fp, t3)
		dir = ed.slerp(fd, t3)
		roll = r_e
	else:
		var t4 := smoothstep(0.0, 1.0, (p - ph.z) / (1.0 - ph.z))
		pos = fp.lerp(base_pos, t4)
		dir = fd.slerp(base_dir, t4)
		roll = lerpf(r_e, 0.0, t4)
	return [pos, dir.normalized(), roll]


func _attack_left(p: float, base_l: Vector3, shl: Vector3, ra: Vector3, fwd: Vector3) -> Vector3:
	var up := ra.cross(fwd)
	var wl := shl + fwd * 0.3 + ra * 0.08 - up * 0.12
	var el := shl + fwd * 0.02 + ra * 0.18 - up * 0.34
	match _atk_style:
		"slash":
			wl = shl + fwd * 0.22 + ra * 0.12 - up * 0.1
			el = shl + fwd * 0.02 + ra * 0.14 - up * 0.36
		"chop":
			wl = shl + fwd * 0.25 + ra * 0.05 + up * 0.06
			el = shl + fwd * 0.05 + ra * 0.1 - up * 0.3
		"throw":
			wl = shl + fwd * 0.42 + ra * 0.04 + up * 0.1
			el = shl + ra * 0.2 - up * 0.32
	var ph := _atk_phases()
	var pos := base_l.lerp(wl, smoothstep(0.0, ph.x, p))
	pos = pos.lerp(el, smoothstep(ph.x, ph.y, p))
	return pos.lerp(base_l, smoothstep(ph.z, 1.0, p))


func _arm_stretch(shoulder: Vector3, target: Vector3) -> float:
	if _fp_s <= 0.0:
		return 1.0
	var max_d := L1 + L2 - 0.02
	var d := shoulder.distance_to(target)
	if d <= max_d:
		return 1.0
	return lerpf(1.0, clampf((d - L2 + 0.02) / L1, 1.0, 2.0), _fp_s)


func _swing(i: int) -> float:
	return sin(PI * _st[i]) if _st[i] >= 0.0 else 0.0


func _update_feet(delta: float, gp: Vector3, rt: Vector3, f: Vector3, model_yaw: float, spd: float) -> void:
	var floor_y := gp.y
	var cr := crouch
	var stance := STANCE + 0.05 * cr
	var run := spd > 3.2 and cr < 0.5
	var step_len := clampf(0.3 + spd * 0.16, 0.3, 0.8) * lerpf(1.0, 0.6, cr)
	var thr := maxf(0.15, step_len * 0.45)
	var land := step_len * 0.55
	var dur := clampf(step_len / maxf(spd, 0.5) * 1.1, 0.18, 0.36)
	var lift := clampf(0.05 + spd * 0.012, 0.05, 0.11)
	if run:
		var rs := clampf((spd - 3.2) / 3.4, 0.0, 1.0)
		thr = 0.4 + 0.12 * rs
		land = 0.4 + 0.12 * rs
		dur = 0.4 - 0.12 * rs
		lift = 0.2 + 0.08 * rs

	if not _feet_ready:
		for i in 2:
			var side := 1.0 if i == 0 else -1.0
			_fp[i] = Vector3(gp.x, floor_y, gp.z) + rt * side * stance
			_fyaw[i] = model_yaw + side * 0.08
			_fpitch[i] = 0.0
			_st[i] = -1.0
		_feet_ready = true

	if airborne:
		_air_lift = lerpf(_air_lift, 0.22 - clampf(-vspeed, 0.0, 8.0) * 0.014, minf(1.0, 12.0 * delta))
		for i in 2:
			var side := 1.0 if i == 0 else -1.0
			var tgt := Vector3(gp.x, gp.y + _air_lift, gp.z) + rt * side * stance + f * (0.12 if i == 0 else -0.06)
			_st[i] = -1.0
			_fp[i] = _fp[i].lerp(tgt, minf(1.0, 22.0 * delta))
			_fyaw[i] = lerp_angle(_fyaw[i], model_yaw, minf(1.0, 12.0 * delta))
			_fpitch[i] = lerpf(_fpitch[i], -0.45, minf(1.0, 12.0 * delta))
		return

	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var base := Vector3(gp.x, floor_y, gp.z) + rt * side * stance
		var target_yaw := model_yaw + side * 0.08 * (1.0 - clampf(spd / 2.0, 0.0, 1.0))
		var lead := Vector3.ZERO
		if spd > 0.3 and _vel.length() > 0.01:
			lead = _vel.normalized() * land

		if _st[i] < 0.0:
			if _land > 0.0:
				_fp[i].y = lerpf(_fp[i].y, floor_y, minf(1.0, 40.0 * delta))
			else:
				_fp[i].y = floor_y
			var err := base - _fp[i]
			err.y = 0.0
			var d := err.length()
			var yaw_diff := absf(wrapf(_fyaw[i] - model_yaw, -PI, PI))
			if d > 1.3:
				_fp[i] = base
				_fyaw[i] = target_yaw
			else:
				var other_busy := _st[1 - i] >= 0.0
				if run:
					other_busy = _st[1 - i] >= 0.0 and _st[1 - i] < 0.55
				if (d > thr or yaw_diff > 0.75) and (not other_busy or d > thr * 1.7):
					_st[i] = 0.0
					_sdur[i] = dur
					_slift[i] = lift
					_from[i] = _fp[i]
					_to[i] = base + lead
					_fyaw_from[i] = _fyaw[i]
					_fyaw_to[i] = target_yaw
			_fpitch[i] = lerpf(_fpitch[i], 0.0, minf(1.0, 22.0 * delta))
		else:
			_st[i] += delta / maxf(_sdur[i], 0.05)
			var t := minf(_st[i], 1.0)
			_to[i] = base + lead
			var e := smoothstep(0.0, 1.0, t)
			var p := _from[i].lerp(_to[i], e)
			p.y = floor_y + sin(PI * t) * _slift[i]
			_fp[i] = p
			_fyaw_to[i] = target_yaw
			_fyaw[i] = lerp_angle(_fyaw_from[i], _fyaw_to[i], e)
			var tp := lerpf(-0.6 if run else -0.5, 0.3, smoothstep(0.0, 0.9, t)) * minf(1.0, t * 7.0)
			_fpitch[i] = lerpf(_fpitch[i], tp, minf(1.0, 25.0 * delta))
			if t >= 1.0:
				_fp[i] = Vector3(_to[i].x, floor_y, _to[i].z)
				_st[i] = -1.0


func _animate_dead(delta: float) -> void:
	if _ragdolled:
		return
	_dead_t += delta
	var t := clampf(_dead_t / 0.7, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - t, 3.0)
	rotation.x = 1.5 * e
	if top_level:
		position.y += 0.12 * e
	else:
		position.y = 0.12 * e
	_hips.rotation = Vector3.ZERO
	_spine.rotation = Vector3.ZERO
	_upper.rotation = Vector3.ZERO
	_head.rotation = Vector3(0.35 * e, 0.0, 0.2 * e)
	_sh[0].rotation = Vector3(0.2, 0.0, 0.7)
	_sh[1].rotation = Vector3(0.2, 0.0, -0.7)
	_el[0].rotation = Vector3(-0.2, 0.0, 0.0)
	_el[1].rotation = Vector3(-0.2, 0.0, 0.0)
	_thigh[0].rotation = Vector3(lerpf(_thigh[0].rotation.x, 0.15, 6.0 * delta), 0.0, 0.0)
	_thigh[1].rotation = Vector3(lerpf(_thigh[1].rotation.x, -0.1, 6.0 * delta), 0.0, 0.0)
	_knee[0].rotation.x = lerpf(_knee[0].rotation.x, -0.1, 6.0 * delta)
	_knee[1].rotation.x = lerpf(_knee[1].rotation.x, -0.2, 6.0 * delta)
	_ankle[0].rotation.x = lerpf(_ankle[0].rotation.x, 0.3, 6.0 * delta)
	_ankle[1].rotation.x = lerpf(_ankle[1].rotation.x, 0.2, 6.0 * delta)


static func _bone_basis(down: Vector3, front: Vector3) -> Basis:
	var y := -down.normalized()
	var z := -front
	z = z - y * z.dot(y)
	if z.length() < 0.001:
		z = y.cross(Vector3.RIGHT)
		if z.length() < 0.001:
			z = y.cross(Vector3.FORWARD)
	z = z.normalized()
	var x := y.cross(z)
	return Basis(x, y, z)


func _solve_limb(root: Node3D, mid: Node3D, target: Vector3, pole: Vector3, front: Vector3, l1: float, l2: float, stretch: float = 1.0) -> void:
	l1 *= stretch
	var s := root.global_position
	var to := target - s
	var dir := Vector3.DOWN
	if to.length() > 0.001:
		dir = to.normalized()
	var dist := clampf(to.length(), 0.12, l1 + l2 - 0.005)
	var cos_a := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var a := acos(cos_a)
	var perp := pole - dir * pole.dot(dir)
	if perp.length() < 0.001:
		perp = front - dir * front.dot(dir)
		if perp.length() < 0.001:
			perp = Vector3.DOWN
	perp = perp.normalized()
	var upper := (dir * cos(a) + perp * sin(a)).normalized()
	var end := s + dir * dist
	var elbow := s + upper * l1
	var lower := end - elbow
	lower = lower.normalized() if lower.length() > 0.001 else upper
	root.global_basis = _bone_basis(upper, front)
	root.scale = Vector3(1.0, stretch, 1.0)
	mid.global_basis = _bone_basis(lower, front)


func _camo(base: Color) -> StandardMaterial3D:
	var key := base.to_html()
	var tex: ImageTexture
	if _tex_cache.has(key):
		tex = _tex_cache[key]
	else:
		var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
		img.fill(base)
		var cols := [base.darkened(0.3), base.lightened(0.15), Color(0.08, 0.08, 0.09), base.darkened(0.12)]
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		for n in 70:
			var c: Color = cols[rng.randi() % cols.size()]
			var w := rng.randi_range(2, 6)
			var h := rng.randi_range(2, 6)
			var x0 := rng.randi_range(0, 31)
			var y0 := rng.randi_range(0, 31)
			for yy in h:
				for xx in w:
					img.set_pixel((x0 + xx) % 32, (y0 + yy) % 32, c)
		tex = ImageTexture.create_from_image(img)
		_tex_cache[key] = tex
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	m.metallic = 0.0
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission = Color.BLACK
	_body_mats.append(m)
	return m


func _mat(color: Color, metallic: float, rough: float, body: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	if body:
		m.emission_enabled = true
		m.emission = Color.BLACK
		_body_mats.append(m)
	return m


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.3)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _node(parent: Node, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _mi(parent: Node, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _cap(parent: Node, r: float, h: float, mat: Material, pos: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0 + 0.001)
	m.radial_segments = 12
	m.rings = 4
	return _mi(parent, m, mat, pos, scl)


func _sph(parent: Node, r: float, mat: Material, pos: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return _mi(parent, m, mat, pos, scl)


func _cyl(parent: Node, top: float, bottom: float, h: float, mat: Material, pos: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 12
	m.rings = 1
	return _mi(parent, m, mat, pos, scl)


func _tor(parent: Node, inner: float, outer: float, mat: Material, pos: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 12
	m.ring_segments = 6
	return _mi(parent, m, mat, pos, scl)


func _cylz(parent: Node, radius: float, length: float, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := _cyl(parent, radius, radius, length, mat, pos)
	mi.rotation.x = PI * 0.5
	return mi


func _box(parent: Node, size: Vector3, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mi(parent, m, mat, pos, Vector3.ONE)


func _make_ragdoll(push: Vector3) -> void:
	var tree := get_tree()
	if tree == null or not is_inside_tree():
		return
	push = push.limit_length(26.0)
	var host: Node = tree.current_scene if tree.current_scene else tree.root
	_rd_root = Node3D.new()
	host.add_child(_rd_root)
	var mat := PhysicsMaterial.new()
	mat.friction = 1.0
	mat.bounce = 0.0

	var pelvis := _rd_body(_hips, _rd_box(Vector3(0.34, 0.2, 0.22)), Vector3(0, -0.02, 0), 3.0, mat)
	var torso := _rd_body(_upper, _rd_box(Vector3(0.38, 0.5, 0.24)), Vector3(0, -0.12, 0), 5.0, mat)
	var head := _rd_body(_head, _rd_ball(0.14), Vector3(0, 0.07, 0), 1.5, mat)
	_rd_take(pelvis, _hips)
	_rd_take(torso, _spine)
	_rd_take(torso, _chest)
	_rd_take(torso, _upper)
	_rd_take(head, _head)
	_rd_head = head
	for m in _head_meshes:
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var bodies: Array = [pelvis, torso, head]
	var thigh: Array = []
	var shin: Array = []
	var uarm: Array = []
	var farm: Array = []
	for i in 2:
		var t := _rd_body(_thigh[i], _rd_cap(0.08, 0.42), Vector3(0, -0.21, 0), 1.5, mat)
		var s := _rd_body(_knee[i], _rd_cap(0.065, 0.41), Vector3(0, -0.205, 0), 1.0, mat)
		var u := _rd_body(_sh[i], _rd_cap(0.05, 0.28), Vector3(0, -0.14, 0), 0.8, mat)
		var f := _rd_body(_el[i], _rd_cap(0.045, 0.27), Vector3(0, -0.135, 0), 0.6, mat)
		_rd_take(t, _thigh[i])
		_rd_take(s, _knee[i])
		_rd_take(s, _ankle[i])
		_rd_take(u, _sh[i])
		_rd_take(f, _el[i])
		_rd_take(f, _hand[i])
		thigh.append(t)
		shin.append(s)
		uarm.append(u)
		farm.append(f)
		bodies.append_array([t, s, u, f])

	_gun.visible = true
	_flash_mesh.visible = false
	_gun.reparent(farm[0], true)

	_rd_joint(pelvis, torso, _spine.global_position, _hips.global_basis.y, 55.0, 35.0)
	_rd_joint(torso, head, _head.global_position, _upper.global_basis.y, 60.0, 45.0)
	for i in 2:
		_rd_joint(torso, uarm[i], _sh[i].global_position, -_sh[i].global_basis.y, 110.0, 60.0)
		_rd_joint(uarm[i], farm[i], _el[i].global_position, -_el[i].global_basis.y, 80.0, 30.0)
		_rd_joint(pelvis, thigh[i], _thigh[i].global_position, -_thigh[i].global_basis.y, 80.0, 30.0)
		_rd_joint(thigh[i], shin[i], _knee[i].global_position, -_knee[i].global_basis.y, 70.0, 10.0)

	var blast := clampf(push.length() / 14.0, 0.0, 1.0)
	for b in bodies:
		var rb := b as RigidBody3D
		var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-0.4, 1.0), randf_range(-1.0, 1.0))
		var lim_k := 1.0 if (rb == pelvis or rb == torso) else 1.35
		rb.linear_velocity = push * 0.6 * lim_k * randf_range(0.8, 1.15) + jitter * (0.5 + 4.5 * blast)
		rb.angular_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (1.5 + 9.0 * blast)
		rb.angular_damp = lerpf(2.5, 0.6, blast)
	var spin := 2.0 + 6.0 * blast
	torso.angular_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0)) * spin
	pelvis.angular_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0)) * spin * 0.8

	var guard := RagdollGuard.new()
	_rd_root.add_child(guard)
	guard.setup(pelvis, bodies)

	var tm := Timer.new()
	tm.wait_time = 9.0
	tm.one_shot = true
	tm.autostart = true
	_rd_root.add_child(tm)
	tm.timeout.connect(_rd_root.queue_free)
	_ragdolled = true


func _rd_box(size: Vector3) -> Shape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s


func _rd_ball(r: float) -> Shape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


func _rd_cap(r: float, h: float) -> Shape3D:
	var s := CapsuleShape3D.new()
	s.radius = r
	s.height = h
	return s


func _rd_body(bone: Node3D, shape: Shape3D, shape_pos: Vector3, mass: float, mat: PhysicsMaterial) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.collision_layer = 0
	b.collision_mask = 1
	b.mass = mass
	b.linear_damp = 0.35
	b.angular_damp = 1.5
	b.continuous_cd = true
	b.physics_material_override = mat
	_rd_root.add_child(b)
	b.global_transform = Transform3D(bone.global_basis.orthonormalized(), bone.global_position)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = shape_pos
	b.add_child(cs)
	return b


func _rd_take(body: RigidBody3D, node: Node3D) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).reparent(body, true)


func _rd_joint(a: RigidBody3D, b: RigidBody3D, at: Vector3, along: Vector3, swing_deg: float, twist_deg: float) -> void:
	var j := ConeTwistJoint3D.new()
	_rd_root.add_child(j)
	var x := along.normalized()
	var ref := Vector3.UP if absf(x.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var z := x.cross(ref).normalized()
	var y := z.cross(x)
	j.global_transform = Transform3D(Basis(x, y, z), at)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)
	j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(swing_deg))
	j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(twist_deg))
	j.set_param(ConeTwistJoint3D.PARAM_BIAS, 0.2)

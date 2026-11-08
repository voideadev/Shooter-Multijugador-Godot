class_name Controls
extends Control

signal menu_pressed
signal team_pressed

const SCENE_PATH := "res://scenes/ui/controls.tscn"
const JOY_RADIUS := 95.0
const RUN_RADIUS := 44.0

var move_vector := Vector2.ZERO
var look_delta := Vector2.ZERO
var firing := false
var crouch_on := false
var prone_on := false
var _crouch_idx := -1
var _crouch_t := 0.0
var _prone_fired := false

const PRONE_HOLD := 0.45
var sprint := false
var first_person := false
var ads_on := false
var ads_amount := 0.0
var scope := 0.0
var kills := 0

var hp_ratio := 1.0
var score := 0
var wave := 0
var team_button := false
var team_color := Color(1, 1, 1)
var team_label := ""
var show_wave := true
var damage_flash := 0.0
var message := ""
var sub_message := ""
var weapon_name := ""
var weapon_index := 0
var weapon_count := 1
var ammo_text := ""
var holding := "gun"
var gun_id := "rifle"
var gun_name := ""
var gun_ammo := ""
var melee_id := "knife"
var throw_id := "grenade"
var throw_count := 0
var reload_ratio := -1.0
var heal_flash := 0.0

var _joy_idx := -1
var _look_idx := -1
var _fire_idx := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _jump_req := false
var _view_req := false
var _quick_req := ""
var _weapon_tap := false
var _throw_tap := false
var _f_melee := 0.0
var _f_throw := 0.0
var _f_reload := 0.0
var _reload_req := false
var _f_jump := 0.0
var _f_view := 0.0
var _f_weapon := 0.0
var _pop_t := 0.0
var _pop_text := ""


@onready var _damage_flash: ColorRect = $DamageFlash
@onready var _heal_flash: ColorRect = $HealFlash
@onready var _scope: Control = $Scope
@onready var _crosshair: Control = $Crosshair
@onready var _popup: Label = $KillPopup
@onready var _touch: Control = $TouchLayer
@onready var _health_fill: ColorRect = $Hud/HealthFill
@onready var _kills_label: Label = $Hud/KillsLabel
@onready var _pause_panel: Panel = $Hud/PausePanel
@onready var _team_panel: Panel = $Hud/TeamPanel
@onready var _team_text: Label = $Hud/TeamLabel
@onready var _score_label: Label = $Hud/ScoreLabel
@onready var _wave_label: Label = $Hud/WaveLabel
@onready var _ammo_panel: Panel = $Hud/AmmoPanel
@onready var _ammo_label: Label = $Hud/AmmoLabel
@onready var _message_label: Label = $Hud/Message
@onready var _sub_label: Label = $Hud/SubMessage


static func create() -> Controls:
	return load(SCENE_PATH).instantiate() as Controls


func _ready() -> void:
	_touch.draw.connect(_draw_touch)
	_scope.draw.connect(_draw_scope)


func kill_popup(points: int) -> void:
	kills += 1
	_pop_t = 1.0
	_pop_text = "+%d" % points


func reset_touch() -> void:
	_crouch_idx = -1
	_joy_idx = -1
	_look_idx = -1
	_fire_idx = -1
	firing = false
	sprint = false
	move_vector = Vector2.ZERO
	look_delta = Vector2.ZERO


func consume_look() -> Vector2:
	var v := look_delta
	look_delta = Vector2.ZERO
	return v


func consume_jump() -> bool:
	var r := _jump_req
	_jump_req = false
	return r


func consume_reload() -> bool:
	var r := _reload_req
	_reload_req = false
	return r


func consume_view() -> bool:
	var r := _view_req
	_view_req = false
	return r


func consume_quick() -> String:
	var r := _quick_req
	_quick_req = ""
	return r


func consume_weapon_tap() -> bool:
	var r := _weapon_tap
	_weapon_tap = false
	return r


func consume_throw_tap() -> bool:
	var r := _throw_tap
	_throw_tap = false
	return r


func hud_info() -> Dictionary:
	return {
		"gun_id": gun_id, "gun_name": gun_name, "gun_ammo": gun_ammo, "holding_gun": holding == "gun",
		"low_ammo": gun_ammo.begins_with("0 ") or reload_ratio >= 0.0, "reload_ratio": reload_ratio,
		"throw_id": throw_id, "throw_count": throw_count, "melee_id": melee_id,
		"view_text": "1ª PERSONA" if first_person else "3ª PERSONA",
		"prone": prone_on,
	}


func _run_center() -> Vector2:
	HudLayout.ensure_loaded()
	var d := JOY_RADIUS + HudLayout.run_gap
	var up := _joy_origin.y - d >= 50.0
	return _joy_origin + Vector2(0.0, -d if up else d)


func _menu_rect() -> Rect2:
	return Rect2(24.0, 114.0, 104.0, 40.0)


func _team_rect() -> Rect2:
	return Rect2(136.0, 114.0, 196.0, 40.0)


const HIT_ORDER := ["fire", "melee", "throw", "reload", "jump", "crouch", "aim", "weapon", "view"]


func _button_at(p: Vector2, vp: Vector2) -> String:
	for id in HIT_ORDER:
		if not HudLayout.is_shown(id):
			continue
		var margin := 8.0
		if id == "fire":
			margin = 25.0
		elif id == "jump" or id == "crouch" or id == "aim":
			margin = 14.0
		if HudLayout.hit(id, p, vp, margin):
			return id
	if _menu_rect().has_point(p):
		return "menu"
	if team_button and _team_rect().has_point(p):
		return "team"
	return ""


func _input(event: InputEvent) -> void:
	var vp := get_viewport_rect().size
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			var b := _button_at(p, vp)
			if b == "fire" and _fire_idx == -1:
				_fire_idx = event.index
				firing = true
			elif b == "jump":
				_jump_req = true
				_f_jump = 1.0
			elif b == "crouch":
				_crouch_idx = event.index
				_crouch_t = 0.0
				_prone_fired = false
			elif b == "aim":
				ads_on = not ads_on
			elif b == "melee":
				_quick_req = "melee"
				_f_melee = 1.0
			elif b == "throw":
				_throw_tap = true
				_f_throw = 1.0
			elif b == "reload":
				_reload_req = true
				_f_reload = 1.0
			elif b == "menu":
				menu_pressed.emit()
			elif b == "team":
				team_pressed.emit()
			elif b == "weapon":
				_weapon_tap = true
				_f_weapon = 1.0
			elif b == "view":
				_view_req = true
				_f_view = 1.0
			elif _joy_idx == -1 and p.x < vp.x * 0.45:
				_joy_idx = event.index
				_joy_origin = p
				_joy_pos = p
				move_vector = Vector2.ZERO
				sprint = false
			elif _look_idx == -1:
				_look_idx = event.index
		else:
			if event.index == _crouch_idx:
				_crouch_idx = -1
				if not _prone_fired:
					if prone_on:
						prone_on = false
						crouch_on = true
					else:
						crouch_on = not crouch_on
			if event.index == _fire_idx:
				_fire_idx = -1
				firing = false
			if event.index == _joy_idx:
				_joy_idx = -1
				move_vector = Vector2.ZERO
				sprint = false
			if event.index == _look_idx:
				_look_idx = -1
	elif event is InputEventScreenDrag:
		if event.index == _joy_idx:
			var v: Vector2 = event.position - _joy_origin
			if v.length() > JOY_RADIUS:
				v = v.normalized() * JOY_RADIUS
			_joy_pos = _joy_origin + v
			move_vector = v / JOY_RADIUS
			if move_vector.length() < 0.12:
				move_vector = Vector2.ZERO
			if not sprint and event.position.distance_to(_run_center()) <= RUN_RADIUS + 10.0:
				sprint = true
		elif event.index == _look_idx or event.index == _fire_idx:
			look_delta += event.relative


func _process(delta: float) -> void:
	damage_flash = maxf(0.0, damage_flash - delta * 2.5)
	heal_flash = maxf(0.0, heal_flash - delta * 2.0)
	_f_reload = maxf(0.0, _f_reload - delta * 5.0)
	_f_jump = maxf(0.0, _f_jump - delta * 5.0)
	_f_view = maxf(0.0, _f_view - delta * 5.0)
	_f_weapon = maxf(0.0, _f_weapon - delta * 5.0)
	_f_melee = maxf(0.0, _f_melee - delta * 5.0)
	_f_throw = maxf(0.0, _f_throw - delta * 5.0)
	_pop_t = maxf(0.0, _pop_t - delta * 1.1)
	if _crouch_idx != -1 and not _prone_fired:
		_crouch_t += delta
		if _crouch_t >= PRONE_HOLD:
			_prone_fired = true
			prone_on = true
			crouch_on = false
	_update_hud()
	_touch.queue_redraw()
	_scope.queue_redraw()


func _update_hud() -> void:
	var vp := get_viewport_rect().size
	_damage_flash.visible = damage_flash > 0.0
	_damage_flash.color.a = damage_flash * 0.35
	_heal_flash.visible = heal_flash > 0.0
	_heal_flash.color.a = heal_flash * 0.22
	_scope.visible = scope > 0.01
	_crosshair.visible = ads_amount < 0.3
	_crosshair.modulate.a = 1.0 - ads_amount / 0.3
	_popup.visible = _pop_t > 0.0
	_popup.text = _pop_text
	_popup.modulate.a = minf(1.0, _pop_t * 2.5)
	_popup.offset_top = -90.0 - (1.0 - _pop_t) * 60.0
	_popup.offset_bottom = _popup.offset_top + 50.0
	var hp := clampf(hp_ratio, 0.0, 1.0)
	_health_fill.offset_right = 24.0 + 300.0 * hp
	_health_fill.color = Color(1.0, 0.2, 0.2).lerp(Color(0.2, 1.0, 0.5), hp)
	_kills_label.text = "BAJAS %d" % kills
	_team_panel.visible = team_button
	_team_text.visible = team_button
	_team_text.text = team_label
	_team_text.add_theme_color_override("font_color", Color.WHITE)
	var tstyle := _team_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	tstyle.bg_color = Color(team_color.r, team_color.g, team_color.b, 0.35)
	tstyle.border_color = Color(team_color.r, team_color.g, team_color.b, 0.95)
	_team_panel.add_theme_stylebox_override("panel", tstyle)
	_score_label.visible = show_wave
	_wave_label.visible = show_wave
	_score_label.text = "PUNTOS %d" % score
	_wave_label.text = "RONDA %d" % wave
	var show_ammo := ammo_text != "" and not HudLayout.is_shown("weapon")
	_ammo_panel.visible = show_ammo
	_ammo_label.visible = show_ammo
	if show_ammo:
		var low := ammo_text.begins_with("0 ") or reload_ratio >= 0.0
		var astyle := _ammo_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		astyle.border_color = Color(1.0, 0.35, 0.3, 0.9) if low else Color(1.0, 0.8, 0.4, 0.85)
		_ammo_panel.add_theme_stylebox_override("panel", astyle)
		_ammo_label.text = "RECARGANDO..." if reload_ratio >= 0.0 else "BALAS  " + ammo_text
	_message_label.text = message
	_sub_label.text = sub_message


func _draw_scope() -> void:
	if scope <= 0.01:
		return
	var vp := get_viewport_rect().size
	var c := vp * 0.5
	var hole := vp.y * 0.44
	var width := vp.length()
	var black := Color(0, 0, 0, scope)
	_scope.draw_arc(c, hole + width * 0.5, 0.0, TAU, 128, black, width)
	_scope.draw_arc(c, hole, 0.0, TAU, 96, black, 6.0)
	_scope.draw_line(c + Vector2(-hole, 0), c + Vector2(hole, 0), Color(0, 0, 0, scope * 0.85), 1.5)
	_scope.draw_line(c + Vector2(0, -hole), c + Vector2(0, hole), Color(0, 0, 0, scope * 0.85), 1.5)
	for k in range(-4, 5):
		if k != 0:
			_scope.draw_circle(c + Vector2(k * 26.0, 0), 2.0, Color(0, 0, 0, scope * 0.85))
			_scope.draw_circle(c + Vector2(0, k * 26.0), 2.0, Color(0, 0, 0, scope * 0.85))
	_scope.draw_circle(c, 2.5, Color(1.0, 0.15, 0.1, scope))


func _draw_touch() -> void:
	var vp := get_viewport_rect().size
	if _joy_idx != -1:
		_touch.draw_circle(_joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.07))
		_touch.draw_arc(_joy_origin, JOY_RADIUS, 0.0, TAU, 48, Color(1.0, 0.8, 0.4, 0.5), 3.0)
		_touch.draw_arc(_joy_origin, JOY_RADIUS * 0.8, 0.0, TAU, 48, Color(1.0, 0.8, 0.4, 0.25), 2.0)
		_touch.draw_circle(_joy_pos, 40.0, Color(1.0, 0.8, 0.4, 0.4))
		var rc := _run_center()
		var rcol := Color(0.95, 0.85, 0.3)
		var near := _joy_pos.distance_to(rc) <= RUN_RADIUS + 10.0
		var rs := 1.0 if (sprint or near) else 0.0
		_touch.draw_circle(rc, RUN_RADIUS, Color(rcol.r, rcol.g, rcol.b, 0.2 + 0.4 * rs))
		_touch.draw_arc(rc, RUN_RADIUS, 0.0, TAU, 32, Color(rcol.r, rcol.g, rcol.b, 0.9), 3.0)
		HudIcons.draw_icon(_touch, "run", rc, RUN_RADIUS * 0.5, Color(1, 1, 1, 0.95))
	else:
		var hint := Vector2(180.0, vp.y - 160.0)
		_touch.draw_arc(hint, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 3.0)
		_touch.draw_circle(hint, 38.0, Color(1, 1, 1, 0.1))
	var info := hud_info()
	var crouching := crouch_on or Input.is_action_pressed("crouch")
	var strengths := {
		"fire": 1.0 if firing else 0.0,
		"melee": maxf(_f_melee, 1.0 if holding == "melee" else 0.0),
		"jump": _f_jump,
		"crouch": 1.0 if (crouching or prone_on) else 0.0,
		"aim": 1.0 if (ads_on or ads_amount > 0.5) else 0.0,
		"reload": 1.0 if reload_ratio >= 0.0 else _f_reload,
		"throw": maxf(_f_throw, 1.0 if holding == "throw" else 0.0),
		"weapon": _f_weapon,
		"view": _f_view,
	}
	for id in HudLayout.ORDER:
		if HudLayout.is_shown(id):
			HudIcons.draw_button(_touch, id, HudLayout.center(id, vp), HudLayout.size_of(id), HudLayout.COLORS[id], float(strengths[id]), info)
	var mr := _menu_rect()
	HudIcons.draw_icon(_touch, "pause", mr.position + Vector2(24.0, 20.0), 14.0, Color(1, 1, 1, 0.9))

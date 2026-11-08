class_name PauseMenu
extends CanvasLayer

signal exit_pressed
signal resumed
signal arsenal_changed

const SCENE_PATH := "res://scenes/ui/pause_menu.tscn"

var controls: Controls
var pause_tree := true
var is_open := false

var _screens: Dictionary = {}
var _cur := "main"
var _ars_labels: Array = []

@onready var _dim: ColorRect = $Root/Dim
@onready var _editor: LayoutEditor = $Root/Editor
@onready var _q_btn: Button = $Root/Graphics/Box/QualityButton
@onready var _res_btn: Button = $Root/Graphics/Box/ResolutionButton
@onready var _sh_btn: Button = $Root/Graphics/Box/ShadowsButton
@onready var _aa_btn: Button = $Root/Graphics/Box/AntialiasingButton
@onready var _fps_btn: Button = $Root/Graphics/Box/FpsButton
@onready var _fog_btn: Button = $Root/Graphics/Box/FogButton


static func create() -> PauseMenu:
	return load(SCENE_PATH).instantiate() as PauseMenu


func _ready() -> void:
	_screens = {"main": $Root/Main, "settings": $Root/Settings, "gfx": $Root/Graphics}
	_build_arsenal()
	$Root/Main/ContinueButton.pressed.connect(close)
	$Root/Main/SettingsButton.pressed.connect(_show.bind("settings"))
	$Root/Main/ExitButton.pressed.connect(_on_exit)
	$Root/Settings/ButtonsButton.pressed.connect(_show.bind("editor"))
	$Root/Settings/GraphicsButton.pressed.connect(_show.bind("gfx"))
	$Root/Settings/BackButton.pressed.connect(_show.bind("main"))
	$Root/Graphics/Box/BackButton.pressed.connect(_show.bind("settings"))
	_q_btn.pressed.connect(_on_quality)
	_res_btn.pressed.connect(_on_resolution)
	_sh_btn.pressed.connect(_on_shadows)
	_aa_btn.pressed.connect(_on_antialiasing)
	_fps_btn.pressed.connect(_on_fps)
	_fog_btn.pressed.connect(_on_fog)
	_editor.visible = false
	_editor.done.connect(_show.bind("settings"))
	Gfx.ensure_loaded()
	_show("main")


func _build_arsenal() -> void:
	var main: VBoxContainer = $Root/Main
	var ab := Button.new()
	ab.text = "ARSENAL"
	ab.custom_minimum_size = Vector2(0, 84)
	ab.add_theme_font_size_override("font_size", 36)
	ab.pressed.connect(_show.bind("arsenal"))
	main.add_child(ab)
	main.move_child(ab, $Root/Main/SettingsButton.get_index())

	var box := VBoxContainer.new()
	box.anchor_left = 0.2
	box.anchor_right = 0.8
	box.anchor_bottom = 1.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	$Root.add_child(box)
	var title := Label.new()
	title.text = "ARSENAL"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var titles := ["PRINCIPAL", "SECUNDARIA", "CUERPO A CUERPO", "LANZABLE"]
	_ars_labels = []
	for i in 4:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var prev := Button.new()
		prev.text = "<"
		prev.custom_minimum_size = Vector2(90, 72)
		prev.add_theme_font_size_override("font_size", 34)
		prev.pressed.connect(_on_arsenal_step.bind(i, -1))
		var lab := Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.add_theme_font_size_override("font_size", 28)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nxt := Button.new()
		nxt.text = ">"
		nxt.custom_minimum_size = Vector2(90, 72)
		nxt.add_theme_font_size_override("font_size", 34)
		nxt.pressed.connect(_on_arsenal_step.bind(i, 1))
		row.add_child(prev)
		row.add_child(lab)
		row.add_child(nxt)
		box.add_child(row)
		_ars_labels.append([lab, titles[i]])
	var back := Button.new()
	back.text = "ATRÁS"
	back.custom_minimum_size = Vector2(0, 72)
	back.add_theme_font_size_override("font_size", 30)
	back.pressed.connect(_show.bind("main"))
	box.add_child(back)
	box.visible = false
	_screens["arsenal"] = box


func _on_arsenal_step(slot: int, step: int) -> void:
	Loadout.ensure_loaded()
	var n := Weapons.LIST.size()
	match slot:
		0:
			var idx := posmod(Loadout.primary + step, n)
			if idx == Loadout.secondary:
				idx = posmod(idx + step, n)
			Loadout.primary = idx
		1:
			var idx2 := posmod(Loadout.secondary + step, n)
			if idx2 == Loadout.primary:
				idx2 = posmod(idx2 + step, n)
			Loadout.secondary = idx2
		2:
			Loadout.melee = posmod(Loadout.melee + step, Weapons.MELEE.size())
		3:
			Loadout.throwable = posmod(Loadout.throwable + step, Weapons.THROW.size())
	Loadout.save()
	_refresh_arsenal()
	arsenal_changed.emit()


func _refresh_arsenal() -> void:
	Loadout.ensure_loaded()
	var names := [
		String(Weapons.LIST[Loadout.primary]["name"]),
		String(Weapons.LIST[Loadout.secondary]["name"]),
		String(Weapons.MELEE[Loadout.melee]["name"]),
		String(Weapons.THROW[Loadout.throwable]["name"]),
	]
	for i in _ars_labels.size():
		var e: Array = _ars_labels[i]
		(e[0] as Label).text = "%s\n%s" % [e[1], names[i]]


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	if controls != null:
		controls.reset_touch()
		controls.set_process_input(false)
		controls.visible = false
		_editor.controls = controls
	if pause_tree:
		get_tree().paused = true
	_show("main")


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	if controls != null:
		controls.set_process_input(true)
		controls.visible = true
	HudLayout.save()
	resumed.emit()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _on_exit() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	if controls != null:
		controls.set_process_input(true)
		controls.visible = true
	exit_pressed.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if not is_open:
			open()
		elif _cur == "main":
			close()
		elif _cur == "gfx" or _cur == "editor":
			_show("settings")
		else:
			_show("main")


func _show(screen: String) -> void:
	_cur = screen
	for k in _screens:
		(_screens[k] as Control).visible = (k == screen)
	_editor.visible = screen == "editor"
	_dim.visible = screen != "editor"
	if screen == "gfx":
		_refresh_gfx()
	if screen == "arsenal":
		_refresh_arsenal()


func _on_quality() -> void:
	Gfx.set_preset(0 if Gfx.preset < 0 or Gfx.preset >= Gfx.PRESETS.size() - 1 else Gfx.preset + 1)
	_gfx_changed(false)


func _on_resolution() -> void:
	var i := 0
	for k in Gfx.RES_STEPS.size():
		if absf(float(Gfx.RES_STEPS[k]) - Gfx.res) < 0.01:
			i = k
	Gfx.res = float(Gfx.RES_STEPS[(i + 1) % Gfx.RES_STEPS.size()])
	_gfx_changed(true)


func _on_shadows() -> void:
	Gfx.shadows = (Gfx.shadows + 1) % 3
	_gfx_changed(true)


func _on_antialiasing() -> void:
	Gfx.msaa = (Gfx.msaa + 1) % 3
	_gfx_changed(true)


func _on_fps() -> void:
	var i := 2
	for k in Gfx.FPS_STEPS.size():
		if int(Gfx.FPS_STEPS[k]) == Gfx.fps:
			i = k
	Gfx.fps = int(Gfx.FPS_STEPS[(i + 1) % Gfx.FPS_STEPS.size()])
	_gfx_changed(true)


func _on_fog() -> void:
	Gfx.fog = not Gfx.fog
	_gfx_changed(true)


func _gfx_changed(custom: bool) -> void:
	if custom:
		Gfx.touched()
	Gfx.apply(self)
	_refresh_gfx()


func _refresh_gfx() -> void:
	Gfx.ensure_loaded()
	_q_btn.text = "CALIDAD: " + Gfx.preset_name()
	_res_btn.text = "RESOLUCIÓN 3D: %d%%" % int(round(Gfx.res * 100.0))
	_sh_btn.text = "SOMBRAS: " + String(Gfx.SHADOW_NAMES[Gfx.shadows])
	_aa_btn.text = "ANTIALIASING: " + String(Gfx.MSAA_NAMES[Gfx.msaa])
	_fps_btn.text = "FPS MÁXIMOS: %d" % Gfx.fps
	_fog_btn.text = "NIEBLA: " + ("SÍ" if Gfx.fog else "NO")

class_name MainMenu
extends Control

const GAME_SCENE := "res://main.tscn"
const FFA_SCENE := "res://ffa.tscn"
const ORANGE := Color(1.0, 0.7, 0.25)

static var start_panel := "home"

var _model: Humanoid
var _yaw := 0.45
var _idle := 10.0
var _show_def: Dictionary = {}
var _atk_repeat := 99.0
var _wbtn: Array = [[], []]
var _mbtn: Array = []
var _tbtn: Array = []
var _sbtn: Array = []

@onready var _home: Control = $Home
@onready var _play: Control = $Play
@onready var _multi: Control = $Multi
@onready var _custom: Control = $Custom
@onready var _preview: SubViewportContainer = $Preview
@onready var _name_edit: LineEdit = $Home/NameEdit
@onready var _char_label: Label = $Custom/CharacterBar/CharacterLabel
@onready var _stats: Label = $Custom/Scroll/Box/Stats


func _ready() -> void:
	Loadout.ensure_loaded()
	_model = $Preview/Viewport/Soldier
	_show_def = Weapons.LIST[Loadout.primary]
	_rebuild_model()
	_name_edit.text = Loadout.player_name
	_name_edit.max_length = Loadout.NAME_MAX
	_name_edit.text_changed.connect(func(t: String): Loadout.player_name = t)
	_name_edit.text_submitted.connect(func(_t: String): _name_edit.release_focus())
	_name_edit.focus_exited.connect(_save_name)
	_preview.gui_input.connect(_on_preview_input)
	$Home/Buttons/PlayButton.pressed.connect(_show_play)
	$Home/Buttons/CustomizeButton.pressed.connect(_show_custom)
	$Play/Buttons/SoloButton.pressed.connect(_on_solo)
	$Play/Buttons/MultiButton.pressed.connect(_on_multi_menu)
	$Play/Buttons/BackButton.pressed.connect(_show_home)
	$Multi/Buttons/HostButton.pressed.connect(_on_host)
	$Multi/Buttons/JoinButton.pressed.connect(_on_join)
	$Multi/Buttons/BackButton.pressed.connect(_show_play)
	$Custom/CharacterBar/PrevButton.pressed.connect(_pick_character.bind(-1))
	$Custom/CharacterBar/NextButton.pressed.connect(_pick_character.bind(1))
	$Custom/AcceptButton.pressed.connect(_on_accept)
	_wbtn[0] = _bind_buttons($Custom/Scroll/Box/PrimaryGrid, Weapons.LIST, "name", func(i: int): _pick(0, i))
	_wbtn[1] = _bind_buttons($Custom/Scroll/Box/SecondaryGrid, Weapons.LIST, "name", func(i: int): _pick(1, i))
	_compact_grid($Custom/Scroll/Box/PrimaryGrid)
	_compact_grid($Custom/Scroll/Box/SecondaryGrid)
	_mbtn = _bind_buttons($Custom/Scroll/Box/MeleeRow, Weapons.MELEE, "name", func(i: int): _pick_extra(0, i))
	_tbtn = _bind_buttons($Custom/Scroll/Box/ThrowRow, Weapons.THROW, "name", func(i: int): _pick_extra(1, i))
	_sbtn = _bind_buttons($Custom/Scroll/Box/SuitRow, Loadout.SUITS, "name", func(i: int): _pick_suit(i))
	var first := start_panel
	start_panel = "home"
	_show_panel(first)


func _compact_grid(grid: GridContainer) -> void:
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	for c in grid.get_children():
		var b := c as Button
		b.add_theme_font_size_override("font_size", 14)
		b.custom_minimum_size = Vector2(0, 30)
		b.clip_text = true


func _bind_buttons(container: Node, data: Array, key: String, action: Callable) -> Array:
	var out: Array = []
	var template := container.get_child(0) as Button
	while container.get_child_count() < data.size():
		container.add_child(template.duplicate())
	for i in container.get_child_count():
		var b := container.get_child(i) as Button
		if i >= data.size():
			b.visible = false
			continue
		b.text = String(data[i][key])
		b.pressed.connect(action.bind(i))
		out.append(b)
	return out


func _process(delta: float) -> void:
	if _model == null:
		return
	_idle += delta
	if _idle > 2.5:
		_yaw += 0.5 * delta
	_model.rotation.y = _yaw
	var fwd := -_model.global_basis.z
	_model.animate(delta, 0.0, 1.0, 1.0, (fwd + Vector3(0, 0.06, 0)).normalized())
	if String(_show_def.get("kind", "gun")) != "gun":
		_atk_repeat -= delta
		if _atk_repeat <= 0.0:
			_model.attack(_show_def)
			_atk_repeat = 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _custom.visible:
			_on_accept()
		elif _multi.visible:
			_show_play()
		elif _play.visible:
			_show_home()


func _rebuild_model() -> void:
	var sd := Loadout.suit_def()
	_model.build(sd["suit"], sd["armor"], ORANGE, 0, Color(0.86, 0.66, 0.52), Color(0.13, 0.09, 0.07), Loadout.character)
	_model.max_speed = 4.6
	_model.equip(_show_def)


func _set_selected(b: Button, selected: bool) -> void:
	b.theme_type_variation = &"SelectedButton" if selected else &""


func _show_panel(which: String) -> void:
	if _name_edit.has_focus():
		_name_edit.release_focus()
	_home.visible = which == "home"
	_play.visible = which == "play"
	_multi.visible = which == "multi"
	_custom.visible = which == "custom"
	_set_preview_weapon(Loadout.primary)
	if which == "custom":
		_refresh()


func _show_home() -> void:
	_show_panel("home")


func _show_play() -> void:
	_show_panel("play")


func _on_multi_menu() -> void:
	_show_panel("multi")


func _show_custom() -> void:
	_show_panel("custom")


func _set_preview_weapon(i: int) -> void:
	_set_preview_def(Weapons.LIST[i])


func _set_preview_def(d: Dictionary) -> void:
	if _model != null and (d != _show_def or _model.muzzle == null):
		_model.equip(d)
	_show_def = d
	_atk_repeat = 0.4 if String(d.get("kind", "gun")) != "gun" else 99.0


func _refresh() -> void:
	_char_label.text = "PERSONAJE: " + String(Loadout.CHARACTERS[Loadout.character]["name"])
	for s in 2:
		var cur := Loadout.primary if s == 0 else Loadout.secondary
		for i in _wbtn[s].size():
			_set_selected(_wbtn[s][i], i == cur)
	for i in _mbtn.size():
		_set_selected(_mbtn[i], i == Loadout.melee)
	for i in _tbtn.size():
		_set_selected(_tbtn[i], i == Loadout.throwable)
	for i in _sbtn.size():
		_set_selected(_sbtn[i], i == Loadout.suit)
		_tint(_sbtn[i], Loadout.SUITS[i]["suit"], i == Loadout.suit)
	_stats.text = _stats_text(_show_def)


func _tint(b: Button, col: Color, selected: bool) -> void:
	var n := b.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	n.bg_color = col.darkened(0.2)
	n.border_color = ORANGE if selected else Color(1, 1, 1, 0.35)
	n.set_border_width_all(4 if selected else 2)
	b.add_theme_stylebox_override("normal", n)


func _stats_text(w: Dictionary) -> String:
	var kind := String(w.get("kind", "gun"))
	if kind == "melee":
		return "%s  ·  Daño %d  ·  %.1f golpes/s  ·  Alcance %.1f m" % [w["name"], int(w["damage"]), 1.0 / float(w["rate"]), float(w["reach"])]
	if kind == "throw":
		return "%s  ·  %s" % [w["name"], w["desc"]]
	var pel := int(w["pellets"])
	var dmg := "%d" % int(w["damage"]) if pel <= 1 else "%d x%d" % [int(w["damage"]), pel]
	var mode := "automática" if w["auto"] else "semiautomática"
	return "%s  ·  Daño %s  ·  %.1f disp/s  ·  %s" % [w["name"], dmg, 1.0 / float(w["rate"]), mode]


func _pick(slot: int, idx: int) -> void:
	if slot == 0:
		if idx == Loadout.secondary:
			Loadout.secondary = Loadout.primary
		Loadout.primary = idx
	else:
		if idx == Loadout.primary:
			Loadout.primary = Loadout.secondary
		Loadout.secondary = idx
	_set_preview_weapon(idx)
	_refresh()


func _pick_extra(kind: int, idx: int) -> void:
	if kind == 0:
		Loadout.melee = idx
		_set_preview_def(Weapons.MELEE[idx])
	else:
		Loadout.throwable = idx
		_set_preview_def(Weapons.THROW[idx])
	_refresh()


func _pick_character(step: int) -> void:
	Loadout.character = posmod(Loadout.character + step, Loadout.CHARACTERS.size())
	_rebuild_model()
	_refresh()


func _pick_suit(i: int) -> void:
	Loadout.suit = i
	_rebuild_model()
	_refresh()


func _save_name() -> void:
	Loadout.player_name = Loadout.clean_name(_name_edit.text)
	_name_edit.text = Loadout.player_name
	Loadout.save()


func _on_accept() -> void:
	Loadout.save()
	_show_home()


func _go_ffa(entry: String) -> void:
	Loadout.player_name = Loadout.clean_name(_name_edit.text)
	Loadout.save()
	Ffa.entry = entry
	get_tree().change_scene_to_file(FFA_SCENE)


func _on_solo() -> void:
	_go_ffa("solo")


func _on_host() -> void:
	_go_ffa("host")


func _on_join() -> void:
	_go_ffa("join")


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_yaw += event.relative.x * 0.012
		_idle = 0.0

class_name TeamPicker
extends Control

signal picked(team: int)
signal cancelled

const SCENE_PATH := "res://scenes/ui/team_picker.tscn"

@onready var _buttons: Array[Button] = [
	$Box/TeamRedButton, $Box/TeamBlueButton, $Box/TeamGreenButton, $Box/TeamYellowButton]
@onready var _cancel: Button = $Box/CancelButton


static func create() -> TeamPicker:
	return load(SCENE_PATH).instantiate() as TeamPicker


func _ready() -> void:
	for t in _buttons.size():
		_buttons[t].pressed.connect(_on_team.bind(t))
	_cancel.pressed.connect(_on_cancel)


func open(team_count: int, counts: Array, current: int, allow_cancel: bool) -> void:
	for t in _buttons.size():
		var b := _buttons[t]
		b.visible = t < team_count
		b.text = "%s   (%d)" % [Teams.NAMES[t], int(counts[t]) if t < counts.size() else 0]
		_style(b, Teams.color(t), t == current)
	_cancel.visible = allow_cancel
	visible = true


func _on_team(t: int) -> void:
	visible = false
	picked.emit(t)


func _on_cancel() -> void:
	visible = false
	cancelled.emit()


func _style(b: Button, col: Color, selected: bool) -> void:
	var base := b.get_theme_stylebox("normal") as StyleBoxFlat
	var n := base.duplicate() as StyleBoxFlat
	n.bg_color = Color(col.r, col.g, col.b, 0.55)
	n.border_color = Color.WHITE if selected else col
	n.set_border_width_all(5 if selected else 2)
	b.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(col.r, col.g, col.b, 0.75)
	h.border_color = Color.WHITE
	h.set_border_width_all(3)
	b.add_theme_stylebox_override("hover", h)
	var p := h.duplicate() as StyleBoxFlat
	p.bg_color = col
	b.add_theme_stylebox_override("pressed", p)

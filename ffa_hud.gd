class_name FfaHud
extends Control

const SCENE_PATH := "res://scenes/ui/ffa_hud.tscn"
const SCORE_ROW := preload("res://scenes/ui/score_row.tscn")
const TEAM_ROW := preload("res://scenes/ui/team_row.tscn")

var rows: Array = []
var team_rows: Array = []
var team_limit := 25
var feed: Array = []
var hit_t := 0.0
var kill_limit := 15

@onready var _header: Label = $Scoreboard/Header
@onready var _team_box: VBoxContainer = $Scoreboard/TeamRows
@onready var _row_box: VBoxContainer = $Scoreboard/Rows
@onready var _feed_lines: Array = $Feed.get_children()
@onready var _hit: Control = $HitMarker


static func create() -> FfaHud:
	return load(SCENE_PATH).instantiate() as FfaHud


func add_feed(text: String) -> void:
	feed.append([text, 5.0])
	while feed.size() > 5:
		feed.pop_front()


func hit() -> void:
	hit_t = 0.18


func _process(delta: float) -> void:
	for f in feed:
		f[1] -= delta
	feed = feed.filter(func(f): return f[1] > 0.0)
	hit_t = maxf(0.0, hit_t - delta)
	_update_scoreboard()
	_update_feed()
	_hit.visible = hit_t > 0.0
	_hit.modulate.a = clampf(hit_t / 0.18, 0.0, 1.0)


func _update_scoreboard() -> void:
	_header.text = ("PRIMER EQUIPO A %d BAJAS" % team_limit) if not team_rows.is_empty() else ("PRIMERO A %d BAJAS" % kill_limit)
	_sync(_team_box, TEAM_ROW, team_rows.size())
	for i in team_rows.size():
		var trw: Array = team_rows[i]
		var row := _team_box.get_child(i)
		var tc := Teams.color(int(trw[0]))
		(row.get_node("Swatch") as ColorRect).color = tc
		var l := row.get_node("Name") as Label
		l.text = "%s  %d" % [Teams.NAMES[int(trw[0])], int(trw[1])]
		l.add_theme_color_override("font_color", tc.lightened(0.25))
	var shown: Array = []
	for i in rows.size():
		var r: Array = rows[i]
		if shown.size() >= 6 and not bool(r[3]):
			continue
		shown.append(i)
	_sync(_row_box, SCORE_ROW, shown.size())
	for k in shown.size():
		var i: int = shown[k]
		var r: Array = rows[i]
		var col := Color(1.0, 0.8, 0.4) if bool(r[3]) else Color(1, 1, 1, 0.85)
		if r.size() > 4 and int(r[4]) >= 0:
			col = Teams.color(int(r[4])).lightened(0.3 if bool(r[3]) else 0.1)
		var row := _row_box.get_child(k)
		var n := row.get_node("Name") as Label
		var s := row.get_node("Score") as Label
		n.text = "%d. %s" % [i + 1, String(r[0]).left(14)]
		s.text = "%d / %d" % [int(r[1]), int(r[2])]
		n.add_theme_color_override("font_color", col)
		s.add_theme_color_override("font_color", col)


func _sync(box: Node, scene: PackedScene, count: int) -> void:
	while box.get_child_count() < count:
		box.add_child(scene.instantiate())
	while box.get_child_count() > count:
		var c := box.get_child(box.get_child_count() - 1)
		box.remove_child(c)
		c.queue_free()


func _update_feed() -> void:
	for i in _feed_lines.size():
		var l := _feed_lines[i] as Label
		if i < feed.size():
			var f: Array = feed[i]
			l.text = String(f[0])
			l.modulate.a = clampf(float(f[1]), 0.0, 1.0)
		else:
			l.text = ""

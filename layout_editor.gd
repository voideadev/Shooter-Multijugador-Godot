class_name LayoutEditor
extends Control

signal done

const ORANGE := Color(1.0, 0.7, 0.25)
const WHITE := Color(1, 1, 1, 0.95)

var controls: Controls
var _sel := "fire"
var _drag := ""
var _touch_idx := -1
var _panel: PanelContainer
var _grab := Vector2.ZERO
var _name_label: Label
var _slider: HSlider
var _vis_btn: Button
var _gap_slider: HSlider
var _updating := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_panel()
	_refresh_panel()
	visibility_changed.connect(func():
		_touch_idx = -1
		_drag = "")


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _build_panel() -> void:
	var panel := PanelContainer.new()
	_panel = panel
	panel.anchor_left = 0.17
	panel.anchor_right = 0.83
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_top = 10.0
	panel.offset_bottom = 10.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	sb.border_color = ORANGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var hint := Label.new()
	hint.text = "Arrastra un botón para moverlo · toca uno para elegirlo y cambiar su tamaño"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	_name_label = Label.new()
	_name_label.custom_minimum_size = Vector2(210, 0)
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", ORANGE)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_name_label)
	var tl := Label.new()
	tl.text = "TAMAÑO"
	tl.add_theme_font_size_override("font_size", 18)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tl)
	_slider = HSlider.new()
	_slider.min_value = 0.5
	_slider.max_value = 2.0
	_slider.step = 0.05
	_slider.value = 1.0
	_slider.custom_minimum_size = Vector2(170, 36)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.value_changed.connect(_on_slider)
	_slider.drag_ended.connect(func(_changed: bool): HudLayout.save())
	row.add_child(_slider)
	_vis_btn = _btn("", 20, Vector2(160, 44))
	_vis_btn.pressed.connect(_on_visible)
	row.add_child(_vis_btn)

	var rowg := HBoxContainer.new()
	rowg.add_theme_constant_override("separation", 12)
	vb.add_child(rowg)
	var gl := Label.new()
	gl.text = "DISTANCIA DE CORRER"
	gl.add_theme_font_size_override("font_size", 18)
	gl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rowg.add_child(gl)
	_gap_slider = HSlider.new()
	_gap_slider.min_value = HudLayout.RUN_GAP_MIN
	_gap_slider.max_value = HudLayout.RUN_GAP_MAX
	_gap_slider.step = 5.0
	_gap_slider.value = HudLayout.run_gap
	_gap_slider.custom_minimum_size = Vector2(170, 36)
	_gap_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gap_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gap_slider.value_changed.connect(func(v: float):
		if not _updating:
			HudLayout.run_gap = v)
	_gap_slider.drag_ended.connect(func(_changed: bool): HudLayout.save())
	rowg.add_child(_gap_slider)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	vb.add_child(row2)
	var reset_one := _btn("RESTABLECER ESTE", 20, Vector2(0, 44))
	reset_one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_one.pressed.connect(func():
		HudLayout.reset(_sel)
		_refresh_panel())
	row2.add_child(reset_one)
	var reset_all := _btn("RESTABLECER TODOS", 20, Vector2(0, 44))
	reset_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_all.pressed.connect(func():
		HudLayout.reset()
		_refresh_panel())
	row2.add_child(reset_all)
	var ok := _btn("LISTO", 22, Vector2(0, 44))
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func():
		HudLayout.save()
		done.emit())
	row2.add_child(ok)


func _btn(text: String, fsize: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _style(Color(0, 0, 0, 0.45), ORANGE.darkened(0.15), 2))
	b.add_theme_stylebox_override("hover", _style(Color(0.12, 0.12, 0.12, 0.6), ORANGE, 3))
	b.add_theme_stylebox_override("pressed", _style(ORANGE.darkened(0.3), ORANGE, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(6)
	s.content_margin_left = 10.0
	s.content_margin_right = 10.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	return s


func _refresh_panel() -> void:
	HudLayout.ensure_loaded()
	_updating = true
	_name_label.text = String(HudLayout.NAMES[_sel])
	_slider.value = float(HudLayout.data[_sel]["scale"])
	if _gap_slider != null:
		_gap_slider.value = HudLayout.run_gap
	_vis_btn.text = "VISIBLE: SÍ" if HudLayout.is_shown(_sel) else "VISIBLE: NO"
	_updating = false


func _on_slider(v: float) -> void:
	if _updating:
		return
	HudLayout.set_scale(_sel, v)


func _on_visible() -> void:
	HudLayout.set_shown(_sel, not HudLayout.is_shown(_sel))
	HudLayout.save()
	_refresh_panel()


func _pick(p: Vector2, vp: Vector2) -> String:
	var best := ""
	var best_d := INF
	for id in HudLayout.ORDER:
		if HudLayout.hit(id, p, vp, 10.0):
			var d := p.distance_to(HudLayout.center(id, vp))
			if d < best_d:
				best_d = d
				best = id
	return best


func _begin_drag(pos: Vector2, vp: Vector2) -> void:
	var id := _pick(pos, vp)
	if id != "":
		_sel = id
		_drag = id
		_grab = HudLayout.center(id, vp) - pos
		_refresh_panel()


func _move_drag(pos: Vector2, vp: Vector2) -> void:
	if _drag == "":
		return
	var c: Vector2 = pos + _grab
	HudLayout.set_pos(_drag, Vector2(c.x / vp.x, c.y / vp.y))


func _end_drag() -> void:
	if _drag != "":
		HudLayout.save()
	_drag = ""


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var vp := get_viewport_rect().size
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_idx == -1 and not _over_panel(event.position):
				_begin_drag(event.position, vp)
				if _drag != "":
					_touch_idx = event.index
					get_viewport().set_input_as_handled()
		elif event.index == _touch_idx:
			_touch_idx = -1
			_end_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _touch_idx:
			_move_drag(event.position, vp)
			get_viewport().set_input_as_handled()


func _over_panel(p: Vector2) -> bool:
	return _panel != null and _panel.get_global_rect().has_point(p)


func _gui_input(_event: InputEvent) -> void:
	accept_event()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.62))
	var jo := Vector2(vp.x * 0.14, vp.y * 0.62)
	var jd := Controls.JOY_RADIUS + HudLayout.run_gap
	var rc := jo + Vector2(0.0, -jd if jo.y - jd >= 40.0 else jd)
	var yel := Color(0.95, 0.85, 0.3)
	draw_arc(jo, Controls.JOY_RADIUS, 0.0, TAU, 48, Color(1.0, 0.8, 0.4, 0.5), 3.0)
	draw_circle(jo, 38.0, Color(1.0, 0.8, 0.4, 0.3))
	draw_circle(rc, Controls.RUN_RADIUS, Color(yel.r, yel.g, yel.b, 0.3))
	draw_arc(rc, Controls.RUN_RADIUS, 0.0, TAU, 32, Color(yel.r, yel.g, yel.b, 0.9), 3.0)
	HudIcons.draw_icon(self, "run", rc, Controls.RUN_RADIUS * 0.5, Color(1, 1, 1, 0.95))
	draw_string(ThemeDB.fallback_font, jo + Vector2(-90.0, Controls.JOY_RADIUS + 34.0), "JOYSTICK + CORRER", HORIZONTAL_ALIGNMENT_CENTER, 180.0, 15, Color(1, 1, 1, 0.6))
	var info: Dictionary = controls.hud_info() if controls != null else {}
	for id in HudLayout.ORDER:
		var shown := HudLayout.is_shown(id)
		var c := HudLayout.center(id, vp)
		var sz := HudLayout.size_of(id)
		HudIcons.draw_button(self, id, c, sz, HudLayout.COLORS[id], 0.0, info, 1.0 if shown else 0.28)
		if id == _sel:
			var half := Vector2(sz.x + 8.0, sz.x + 8.0) if HudLayout.shape_of(id) == "circle" else sz * 0.5 + Vector2(8.0, 8.0)
			draw_rect(Rect2(c - half, half * 2.0), ORANGE, false, 3.0)
		if not shown:
			draw_string(ThemeDB.fallback_font, c + Vector2(-60.0, 6.0), "OCULTO", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 16, Color(1, 1, 1, 0.6))

class_name HudIcons
extends RefCounted

const WHITE := Color(1, 1, 1, 0.95)


static func draw_button(ci: CanvasItem, id: String, c: Vector2, size: Vector2, col: Color, strength: float, info: Dictionary, dim: float = 1.0) -> void:
	var font: Font = ThemeDB.fallback_font
	var icol := Color(1, 1, 1, 0.95 * dim)
	if HudLayout.shape_of(id) == "circle":
		var r := size.x
		ci.draw_circle(c, r, Color(col.r, col.g, col.b, (0.24 + 0.32 * strength) * dim))
		ci.draw_arc(c, r, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.85 * dim), 3.0)
		var kind := id
		if id == "throw":
			kind = String(info.get("throw_id", "grenade"))
		elif id == "melee":
			kind = String(info.get("melee_id", "knife"))
		elif id == "crouch" and bool(info.get("prone", false)):
			kind = "prone"
		draw_icon(ci, kind, c, r * 0.5, icol)
		if id == "throw":
			var n := int(info.get("throw_count", 0))
			ci.draw_string(font, c + Vector2(-r, r * 0.9), "x%d" % n, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 16, icol)
		return
	var rc := Rect2(c - size * 0.5, size)
	ci.draw_rect(rc, Color(0, 0, 0, (0.42 + 0.3 * strength) * dim))
	ci.draw_rect(rc, Color(col.r, col.g, col.b, 0.85 * dim), false, 2.0)
	if id == "weapon":
		var holding_gun := bool(info.get("holding_gun", true))
		var a := 1.0 if holding_gun else 0.45
		var gcol := Color(1, 1, 1, 0.95 * dim * a)
		draw_icon(ci, String(info.get("gun_id", "rifle")), c + Vector2(-size.x * 0.25, -size.y * 0.04), size.y * 0.3, gcol)
		var txt := String(info.get("gun_ammo", ""))
		var low := bool(info.get("low_ammo", false))
		var tcol := Color(1.0, 0.4, 0.35, dim) if low else Color(1, 1, 1, 0.95 * dim)
		ci.draw_string(font, Vector2(c.x - size.x * 0.02, c.y - size.y * 0.04), txt, HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.52, int(size.y * 0.3), tcol)
		ci.draw_string(font, Vector2(c.x - size.x * 0.02, c.y + size.y * 0.3), String(info.get("gun_name", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.52, int(size.y * 0.2), Color(1, 1, 1, 0.7 * dim))
		var rr := float(info.get("reload_ratio", -1.0))
		if rr >= 0.0:
			ci.draw_rect(Rect2(rc.position.x, rc.end.y - 6.0, size.x * clampf(rr, 0.0, 1.0), 6.0), Color(0.55, 0.8, 1.0, 0.95 * dim))
	elif id == "view":
		draw_icon(ci, "view", c + Vector2(-size.x * 0.34, 0.0), size.y * 0.32, icol)
		ci.draw_string(font, Vector2(c.x - size.x * 0.2, c.y + size.y * 0.18), String(info.get("view_text", "3ª PERSONA")), HORIZONTAL_ALIGNMENT_LEFT, size.x * 0.7, int(size.y * 0.4), icol)


static func _r(ci: CanvasItem, c: Vector2, u: float, x: float, y: float, w: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(x, y) * u, Vector2(w, h) * u), col)


static func _poly(ci: CanvasItem, c: Vector2, u: float, pts: Array, col: Color) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(c + (p as Vector2) * u)
	ci.draw_colored_polygon(arr, col)


static func draw_icon(ci: CanvasItem, kind: String, c: Vector2, u: float, col: Color) -> void:
	var w := maxf(2.0, u * 0.16)
	match kind:
		"pistol", "revolver", "mpistol":
			_r(ci, c, u, -0.6, -0.35, 1.2, 0.32, col)
			_r(ci, c, u, 0.45, -0.3, 0.3, 0.14, col)
			_r(ci, c, u, -0.55, -0.05, 0.3, 0.7, col)
			_r(ci, c, u, -0.25, -0.03, 0.4, 0.1, col)
		"rifle", "marksman", "lmg":
			_r(ci, c, u, -1.2, -0.12, 0.5, 0.3, col)
			_r(ci, c, u, -0.7, -0.17, 1.25, 0.28, col)
			_r(ci, c, u, 0.55, -0.1, 0.65, 0.12, col)
			_r(ci, c, u, -0.1, 0.1, 0.26, 0.5, col)
			_r(ci, c, u, -0.5, 0.1, 0.2, 0.38, col)
			_r(ci, c, u, -0.25, -0.28, 0.4, 0.1, col)
		"smg", "vector", "mp5":
			_r(ci, c, u, -1.0, -0.12, 0.3, 0.1, col)
			_r(ci, c, u, -0.7, -0.17, 1.05, 0.3, col)
			_r(ci, c, u, 0.3, -0.1, 0.4, 0.12, col)
			_r(ci, c, u, -0.05, 0.12, 0.2, 0.62, col)
			_r(ci, c, u, -0.5, 0.12, 0.2, 0.38, col)
		"shotgun", "doublebarrel", "autoshot":
			_r(ci, c, u, -1.2, -0.1, 0.5, 0.3, col)
			_r(ci, c, u, -0.7, -0.14, 0.95, 0.26, col)
			_r(ci, c, u, 0.2, -0.14, 1.0, 0.12, col)
			_r(ci, c, u, 0.25, 0.0, 0.55, 0.16, col)
			_r(ci, c, u, -0.4, 0.1, 0.2, 0.36, col)
		"sniper", "semisniper", "antimat":
			_r(ci, c, u, -1.25, -0.08, 0.55, 0.3, col)
			_r(ci, c, u, -0.7, -0.12, 1.2, 0.24, col)
			_r(ci, c, u, 0.5, -0.07, 0.78, 0.1, col)
			_r(ci, c, u, -0.35, -0.42, 0.75, 0.14, col)
			_r(ci, c, u, -0.2, -0.28, 0.1, 0.16, col)
			_r(ci, c, u, 0.2, -0.28, 0.1, 0.16, col)
			_r(ci, c, u, -0.15, 0.1, 0.2, 0.34, col)
		"ak47":
			_r(ci, c, u, -1.25, -0.12, 0.5, 0.3, col)
			_r(ci, c, u, -0.75, -0.17, 1.1, 0.3, col)
			_r(ci, c, u, 0.35, -0.1, 0.85, 0.12, col)
			_poly(ci, c, u, [Vector2(-0.05, 0.13), Vector2(0.25, 0.13), Vector2(0.45, 0.7), Vector2(0.17, 0.7)], col)
			_r(ci, c, u, -0.5, 0.1, 0.2, 0.38, col)
		"bazooka":
			_r(ci, c, u, -1.3, -0.2, 2.3, 0.36, col)
			_r(ci, c, u, -1.38, -0.28, 0.18, 0.52, col)
			_poly(ci, c, u, [Vector2(1.0, -0.2), Vector2(1.35, -0.02), Vector2(1.0, 0.16)], col)
			_r(ci, c, u, -0.3, 0.14, 0.18, 0.42, col)
			_r(ci, c, u, 0.4, 0.14, 0.18, 0.42, col)
		"potato", "gl":
			_r(ci, c, u, -0.2, -0.2, 1.4, 0.3, col)
			_r(ci, c, u, -1.0, -0.27, 0.8, 0.44, col)
			_r(ci, c, u, -1.1, -0.22, 0.1, 0.34, col)
			_r(ci, c, u, -0.8, 0.16, 0.22, 0.5, col)
		"grenade", "dynamite":
			ci.draw_circle(c + Vector2(0.0, 0.12) * u, 0.55 * u, col)
			_r(ci, c, u, -0.17, -0.62, 0.34, 0.24, col)
			_r(ci, c, u, 0.0, -0.7, 0.62, 0.1, col)
			ci.draw_arc(c + Vector2(-0.25, -0.62) * u, 0.18 * u, 0.0, TAU, 12, col, w * 0.7)
		"molotov":
			_r(ci, c, u, -0.38, -0.05, 0.76, 0.8, col)
			_r(ci, c, u, -0.16, -0.55, 0.32, 0.5, col)
			ci.draw_circle(c + Vector2(0.0, -0.78) * u, 0.2 * u, Color(1.0, 0.6, 0.15, col.a))
		"tknife", "knife":
			_poly(ci, c, u, [Vector2(-1.0, 0.0), Vector2(0.15, -0.28), Vector2(0.15, 0.28)], col)
			_r(ci, c, u, 0.15, -0.12, 0.8, 0.24, col)
		"machete", "katana":
			_poly(ci, c, u, [Vector2(-1.0, -0.32), Vector2(0.2, -0.32), Vector2(0.25, 0.28), Vector2(-1.0, 0.05)], col)
			_r(ci, c, u, 0.2, -0.12, 0.8, 0.24, col)
		"minigun":
			_r(ci, c, u, -1.2, -0.25, 0.9, 0.5, col)
			_r(ci, c, u, -0.3, -0.18, 1.5, 0.1, col)
			_r(ci, c, u, -0.3, 0.0, 1.5, 0.1, col)
			_r(ci, c, u, -0.3, 0.18, 1.5, 0.1, col)
			_r(ci, c, u, -0.6, 0.25, 0.26, 0.5, col)
		"bat":
			_poly(ci, c, u, [Vector2(-1.0, -0.08), Vector2(0.1, -0.08), Vector2(0.95, -0.28), Vector2(0.95, 0.28), Vector2(0.1, 0.08), Vector2(-1.0, 0.08)], col)
		"axe":
			_r(ci, c, u, -0.95, -0.08, 1.9, 0.16, col)
			_poly(ci, c, u, [Vector2(0.15, -0.55), Vector2(0.75, -0.7), Vector2(0.75, 0.3), Vector2(0.15, 0.15)], col)
		"jump":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.6, -0.05) * u, c + Vector2(0.0, -0.65) * u, c + Vector2(0.6, -0.05) * u]), col, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.6, 0.45) * u, c + Vector2(0.0, -0.15) * u, c + Vector2(0.6, 0.45) * u]), col, w)
		"crouch":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.6, -0.45) * u, c + Vector2(0.0, 0.15) * u, c + Vector2(0.6, -0.45) * u]), col, w)
			_r(ci, c, u, -0.55, 0.4, 1.1, 0.14, col)
		"prone":
			_r(ci, c, u, -0.8, 0.1, 1.6, 0.22, col)
			ci.draw_circle(c + Vector2(0.95, 0.0) * u, 0.2 * u, col)
			_r(ci, c, u, -0.8, -0.28, 0.5, 0.12, col)
		"reload":
			var rad := 0.62 * u
			ci.draw_arc(c, rad, -PI * 0.5, PI * 1.15, 28, col, w)
			var ang := PI * 1.15
			var pt := c + Vector2(cos(ang), sin(ang)) * rad
			var nrm := Vector2(cos(ang), sin(ang))
			var tng := Vector2(-sin(ang), cos(ang))
			ci.draw_colored_polygon(PackedVector2Array([pt + tng * 0.38 * u, pt + nrm * 0.3 * u - tng * 0.1 * u, pt - nrm * 0.3 * u - tng * 0.1 * u]), col)
		"aim":
			ci.draw_arc(c, 0.5 * u, 0.0, TAU, 28, col, w * 0.8)
			ci.draw_line(c + Vector2(0.0, -0.9) * u, c + Vector2(0.0, -0.3) * u, col, w * 0.8)
			ci.draw_line(c + Vector2(0.0, 0.9) * u, c + Vector2(0.0, 0.3) * u, col, w * 0.8)
			ci.draw_line(c + Vector2(-0.9, 0.0) * u, c + Vector2(-0.3, 0.0) * u, col, w * 0.8)
			ci.draw_line(c + Vector2(0.9, 0.0) * u, c + Vector2(0.3, 0.0) * u, col, w * 0.8)
			ci.draw_circle(c, 0.08 * u, col)
		"fire":
			_r(ci, c, u, -0.85, -0.24, 0.12, 0.48, col)
			_r(ci, c, u, -0.7, -0.2, 0.95, 0.4, col)
			_poly(ci, c, u, [Vector2(0.25, -0.2), Vector2(0.85, 0.0), Vector2(0.25, 0.2)], col)
		"view":
			var pts := PackedVector2Array()
			for i in 13:
				var t := -1.0 + float(i) / 6.0
				pts.append(c + Vector2(t * 0.85, -0.42 * (1.0 - t * t)) * u)
			for i in 13:
				var t2 := 1.0 - float(i) / 6.0
				pts.append(c + Vector2(t2 * 0.85, 0.42 * (1.0 - t2 * t2)) * u)
			ci.draw_polyline(pts, col, w * 0.8)
			ci.draw_circle(c, 0.24 * u, col)
		"run":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.2, -0.55) * u, c + Vector2(0.4, 0.0) * u, c + Vector2(-0.2, 0.55) * u]), col, w)
			ci.draw_polyline(PackedVector2Array([c + Vector2(0.3, -0.55) * u, c + Vector2(0.9, 0.0) * u, c + Vector2(0.3, 0.55) * u]), col, w)
			ci.draw_line(c + Vector2(-0.95, -0.3) * u, c + Vector2(-0.45, -0.3) * u, col, w * 0.8)
			ci.draw_line(c + Vector2(-0.95, 0.3) * u, c + Vector2(-0.45, 0.3) * u, col, w * 0.8)
		"pause":
			_r(ci, c, u, -0.45, -0.55, 0.3, 1.1, col)
			_r(ci, c, u, 0.15, -0.55, 0.3, 1.1, col)
		_:
			ci.draw_circle(c, 0.4 * u, col)

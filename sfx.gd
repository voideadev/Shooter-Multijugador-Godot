class_name Sfx
extends RefCounted

static var _cache := {}


static func _synth(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.2
	var decay := 25.0
	var tone := 0.0
	var tone_drop := 0.0
	var noise := 1.0
	match kind:
		"shot":
			dur = 0.22; decay = 22.0; tone = 150.0; tone_drop = 70.0; noise = 0.9
		"enemy_shot":
			dur = 0.28; decay = 16.0; tone = 95.0; tone_drop = 35.0; noise = 0.8
		"hit":
			dur = 0.07; decay = 55.0; tone = 900.0; tone_drop = 0.0; noise = 0.25
		"shot_pistol":
			dur = 0.18; decay = 30.0; tone = 200.0; tone_drop = 110.0; noise = 0.8
		"shot_smg":
			dur = 0.12; decay = 40.0; tone = 170.0; tone_drop = 80.0; noise = 0.85
		"shot_shotgun":
			dur = 0.4; decay = 12.0; tone = 100.0; tone_drop = 60.0; noise = 1.0
		"shot_sniper":
			dur = 0.5; decay = 9.0; tone = 120.0; tone_drop = 90.0; noise = 0.7
		"shot_ak":
			dur = 0.24; decay = 18.0; tone = 130.0; tone_drop = 60.0; noise = 0.95
		"shot_rocket":
			dur = 0.6; decay = 7.0; tone = 90.0; tone_drop = 55.0; noise = 1.0
		"shot_potato":
			dur = 0.3; decay = 14.0; tone = 150.0; tone_drop = 70.0; noise = 0.55
		"crit":
			dur = 0.16; decay = 28.0; tone = 1700.0; tone_drop = 900.0; noise = 0.2
		"swing":
			dur = 0.2; decay = 16.0; tone = 380.0; tone_drop = 300.0; noise = 0.95
		"throw":
			dur = 0.15; decay = 22.0; tone = 260.0; tone_drop = 150.0; noise = 0.6
		"pin":
			dur = 0.05; decay = 80.0; tone = 1700.0; tone_drop = 400.0; noise = 0.15
		"tink":
			dur = 0.08; decay = 60.0; tone = 1300.0; tone_drop = 300.0; noise = 0.25
		"boom":
			dur = 1.0; decay = 4.5; tone = 62.0; tone_drop = 40.0; noise = 1.0
		"glass":
			dur = 0.35; decay = 14.0; tone = 2200.0; tone_drop = 1500.0; noise = 0.95
		"swap":
			dur = 0.06; decay = 70.0; tone = 500.0; tone_drop = 200.0; noise = 0.3
		"hurt":
			dur = 0.25; decay = 14.0; tone = 75.0; tone_drop = 25.0; noise = 0.5
		"die":
			dur = 0.5; decay = 7.0; tone = 240.0; tone_drop = 190.0; noise = 0.6
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * decay)
		var f := maxf(10.0, tone - tone_drop * (t / dur))
		ph += TAU * f / rate
		var s := (sin(ph) * 0.6 + randf_range(-1.0, 1.0) * noise) * env * 0.6
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


static func get_stream(kind: String) -> AudioStreamWAV:
	if not _cache.has(kind):
		_cache[kind] = _synth(kind)
	return _cache[kind]


static func play_at(host: Node, kind: String, pos: Vector3, vol_db: float = 0.0) -> void:
	if host == null or not host.is_inside_tree():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = get_stream(kind)
	p.volume_db = vol_db
	p.unit_size = 14.0
	p.max_distance = 80.0
	host.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()

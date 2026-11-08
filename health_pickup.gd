class_name HealthPickup
extends Area3D

const HEAL := 40.0
const RESPAWN := 25.0

var _active := true
var _t := 0.0

@onready var _body: Node3D = $Body


func _ready() -> void:
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	_body.position = Vector3(0.0, 0.75 + sin(_t * 2.2) * 0.08, 0.0)
	_body.rotation.y = _t * 1.4


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	for b in get_overlapping_bodies():
		if b is Player:
			var p := b as Player
			if p.dead or p.hp >= p.max_hp:
				continue
			p.heal(HEAL)
			Sfx.play_at(self, "swap", global_position + Vector3(0.0, 1.0, 0.0), 0.0)
			_set_active(false)
			get_tree().create_timer(RESPAWN).timeout.connect(_on_respawn)
			return


func _on_respawn() -> void:
	if is_inside_tree():
		_set_active(true)


func _set_active(on: bool) -> void:
	_active = on
	_body.visible = on

class_name Explosion
extends Node3D

const SCENE_PATH := "res://scenes/effects/explosion.tscn"

@onready var ball: MeshInstance3D = $Ball


static func create(host: Node, pos: Vector3, radius: float) -> Explosion:
	var e := load(SCENE_PATH).instantiate() as Explosion
	host.add_child(e)
	e.global_position = pos
	e.start(radius)
	return e


func start(radius: float) -> void:
	var mat := ball.material_override.duplicate() as StandardMaterial3D
	ball.material_override = mat
	var tw := ball.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * radius * 0.55, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(queue_free)
	for i in 5:
		var off := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.2), randf_range(-1.0, 1.0)) * radius * 0.35
		Spark.create(get_parent(), global_position + off, Color(1.0, randf_range(0.45, 0.8), 0.2))

class_name Spark
extends MeshInstance3D

const SCENE_PATH := "res://scenes/effects/spark.tscn"


static func create(parent: Node, pos: Vector3, col: Color) -> Spark:
	var s := load(SCENE_PATH).instantiate() as Spark
	parent.add_child(s)
	s.global_position = pos
	s.start(col)
	return s


func start(col: Color) -> void:
	var mat := material_override.duplicate() as StandardMaterial3D
	material_override = mat
	mat.albedo_color = Color(col.r, col.g, col.b, 0.8)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * 2.6, 0.16)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.16)
	tw.chain().tween_callback(queue_free)

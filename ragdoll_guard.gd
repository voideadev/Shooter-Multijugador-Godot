class_name RagdollGuard
extends Node

const MAX_LIN := 22.0
const MAX_ANG := 18.0
const MAX_STRETCH := 1.9

var _pelvis: RigidBody3D
var _parts: Array = []


func setup(pelvis: RigidBody3D, parts: Array) -> void:
	_pelvis = pelvis
	_parts = parts


func _physics_process(_delta: float) -> void:
	for p in _parts:
		var b := p as RigidBody3D
		if b == null or not is_instance_valid(b):
			continue
		if b.linear_velocity.length() > MAX_LIN:
			b.linear_velocity = b.linear_velocity.normalized() * MAX_LIN
		if b.angular_velocity.length() > MAX_ANG:
			b.angular_velocity = b.angular_velocity.normalized() * MAX_ANG
		if _pelvis != null and is_instance_valid(_pelvis) and b != _pelvis:
			var off := b.global_position - _pelvis.global_position
			if off.length() > MAX_STRETCH:
				b.global_position = _pelvis.global_position + off.normalized() * MAX_STRETCH
				b.linear_velocity = _pelvis.linear_velocity
				b.angular_velocity = Vector3.ZERO

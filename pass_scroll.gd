class_name PassScroll
extends ScrollContainer


func _ready() -> void:
	scroll_deadzone = 16
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	for b in find_children("*", "BaseButton", true, false):
		(b as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is BaseButton and is_ancestor_of(n):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_PASS

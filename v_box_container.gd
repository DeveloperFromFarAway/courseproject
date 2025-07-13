extends VBoxContainer

func _ready() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	custom_minimum_size = viewport_size

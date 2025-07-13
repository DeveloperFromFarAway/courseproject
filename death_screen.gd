extends CanvasLayer

func _ready() -> void:
	get_tree().current_scene.tree_exiting.connect(_on_scene_change)
	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()

func _on_resize():
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	$CenterContainer.size = viewport_size
	$Blood.position = Vector2(viewport_size.x / 2, viewport_size.y / 2)
	$Blood.scale = Vector2(
	viewport_size.x / $Blood.texture.get_width(),
		viewport_size.y / $Blood.texture.get_height()
	)
	"""
	# Динамический размер шрифта (пример для Label )
	$CenterContainer/VBoxContainer/Label.add_theme_font_size_override(
		"font_size", 
		viewport_size.y * 0.04  # 4% от высоты экрана
	)
	"""

func _on_scene_change():
	queue_free()

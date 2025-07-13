extends CanvasLayer

func _on_touch_screen_attack_pressed() -> void:
	Input.action_press("ui_Q")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("ui_Q")

func _on_touch_screen_button_pressed() -> void:
	Input.action_press("ui_alt")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("ui_alt")

func _on_touch_screen_slide_pressed() -> void:
	Input.action_press("ui_shift")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("ui_shift")

func _on_touch_screen_up_pressed() -> void:
	Input.action_press("ui_up")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("ui_up")

func _on_touch_screen_strelka_pressed() -> void:
	get_tree().change_scene_to_file("res://GenerationPresets/StartRoom.tscn")

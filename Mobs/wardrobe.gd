extends CharacterBody2D

var max_health = 100
var current_health = 100  # крепкое здоровье шкафа
var hp_bar = preload("res://healBar/mob_heal_bar.tscn").instantiate()
var is_facing_right: bool = true
var right_detected := false

func _ready() -> void:
	# первичные настройки хп бара
	add_child(hp_bar)
	hp_bar.visible = false
	hp_bar.value = current_health
	hp_bar.max_value = current_health
	hp_bar.position = Vector2(-25, -40)

func take_damage(damage: int):
	current_health -= damage
	hp_bar.value = current_health
	if current_health < 0:
		current_health = 0
	if !hp_bar.visible:
		hp_bar.visible = true
	if current_health <= 0:
		SHKAF_incident()

func SHKAF_incident():
	Global.SHKAF_incident = true
	get_tree().change_scene_to_file("res://GenerationPresets/StartRoom.tscn")

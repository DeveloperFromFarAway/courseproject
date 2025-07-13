extends Node2D

@export var spawnable_scenes: Array[PackedScene] = [
	preload("res://Mobs/skeleton_archer.tscn"),
	preload("res://Mobs/skeleton_spearman.tscn"),
	preload("res://Mobs/skeleton_warrior.tscn")
]

func _ready():
	spawn_random_enemy()

func spawn_random_enemy():
	if spawnable_scenes.is_empty():
		push_error("No scenes to spawn!")
		return
		
	var random_scene = spawnable_scenes.pick_random()
	var enemy = random_scene.instantiate()
	add_child(enemy)

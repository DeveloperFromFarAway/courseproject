extends Node2D

const ROOMS_PATH = "res://GenerationPresets/"
var room_spacing = Vector2(640, 0)

func _ready():
	if not Global.SHKAF_incident:
		Global.bones_rested = 0
	if Global.bones_rested > 0:
		var label = $CanvasLayer/Label
		label.text = "Костей упокоено: %d" % Global.bones_rested
		Global.SHKAF_incident = false
	generate_level()

func generate_level():
	var rooms = [
		"Room_1.tscn", "Room_2.tscn", "Room_3.tscn",	
		"Room_4.tscn", "Room_5.tscn", "Room_6.tscn", "Room_7.tscn"
	]
	
	rooms.shuffle()
	print("Базовый список комнат: ", rooms)

	process_special_rooms(rooms)
	
	rooms.append("EndRoom.tscn")
	print("Добавлена EndRoom в конец уровня")

	var current_pos = room_spacing
	for room_path in rooms:
		var full_path = ROOMS_PATH + room_path
		var room = load(full_path).instantiate()
		add_child(room)
		room.position = current_pos
		set_background_layer(room)
		current_pos += room_spacing
		print("Добавлена ", room_path, " на позицию ", room.position)

func process_special_rooms(rooms: Array):
	var protected_indices = []
	var room3_idx = rooms.find("Room_3.tscn")
		
	if room3_idx != -1:
		rooms.insert(room3_idx + 1, "Room_3_2.tscn")
		protected_indices.append(room3_idx)
		protected_indices.append(room3_idx + 1)  # защита Room_3 и Room_3_2
	
	var room2_idx = rooms.find("Room_2.tscn")
	if room2_idx != -1:
		if randf() > 0.5:
			rooms.insert(room2_idx + 1, "Room_2_2.tscn")
			rooms.insert(room2_idx + 2, "Room_2_3.tscn")
		else:
			var max_attempts = 10
			var attempt = 0
			
			while attempt < max_attempts:
				attempt += 1
				var insert_pos = randi() % rooms.size()
				
				var valid_position = true
				for protected in protected_indices:
					if insert_pos >= protected - 1 and insert_pos <= protected + 1:
						valid_position = false
						break
				
				if valid_position:
					rooms.insert(insert_pos, "Room_2.tscn")
					rooms.insert(insert_pos + 1, "Room_2_2.tscn")
					rooms.insert(insert_pos + 2, "Room_2_3.tscn")
					break
							
				if attempt >= max_attempts:
					rooms.append("Room_2.tscn")
					rooms.append("Room_2_2.tscn")
					rooms.append("Room_2_3.tscn")

func set_background_layer(room_instance: Node2D):
	room_instance.z_index = -10

	var tilemap = room_instance.get_node_or_null("TileMap")
	if tilemap:
		tilemap.z_index = -10

	for child in room_instance.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			child.z_index = -10

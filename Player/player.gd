extends CharacterBody2D

var SPEED := 100
const JUMP_VELOCITY = -350.0

@export var RUN_MULTIPLIER := 2
@onready var anim = $AnimatedSprite2D
@onready var animPlayer = $AnimationPlayer
var is_facing_right = true
var is_running = false 

var is_rolling = false
var roll_timer = 0.0
var roll_direction = 0
var roll_distance = 100.0
var base_roll_distance = 100.0
var roll_duration = 0.4
var roll_JerkInAir_duration = 0.1
var roll_or_jerk = false
var once_per_flight = true
var numberJumps = 0
var slide = false

var camera_offset = Vector2(30, -30) # смещение камеры вперед

var max_health = 200
var current_health = 200
var is_dead = false

var takeDamage_timer: Timer
var takeDamage = false

var animation_time = 0.0
var anim_attack_playing = false
var attack_cooldown_timer: Timer
var attack_sequence_timer: Timer
var current_attack = 1
var can_attack = true
var is_in_attack_sequence = false
var attack_damage = 0

var last_roll_time: float = -100.0
var can_do_special_attack: bool = false
var special_attack_cooldown_timer: Timer

var current_hit_area: Area2D
var temp_bodies: Array = [] 

var death_screen_scene = preload("res://deathScreen.tscn")
var death_screen = death_screen_scene.instantiate()
var darken = death_screen.find_child("CenterContainer")
var blood = death_screen.find_child("Blood")

var can_restore_health := true
var health_restore_timer: Timer
var is_chased := false

var current_endurance = 200
var max_endurance = 200
var last_action_time := 0.0
var endurance_restore_timer: Timer
var can_restore_endurance := false
var is_resting := false  # Флаг режима отдыха после истощения
var base_restore_delay := 2.0  # Обычная задержка
var exhausted_restore_delay := 4.0  # Задержка после истощения

var is_changing_direction := false
var can_flip := false
var direction_change_timer: Timer
var is_interrupting_attack := false

var was_moving := 0  # -1=влево, 0=стоял, 1=вправо | предыдущий
var current_movement := 0  # -1=влево, 0=стоит, 1=вправо | сейчаснийший

func _ready() -> void:
	darken.modulate.a = 0
	blood.modulate.a = 0
	get_tree().root.add_child.call_deferred(death_screen)
	death_screen.visible = false
	
	takeDamage_timer = Timer.new()
	takeDamage_timer.one_shot = true
	add_child(takeDamage_timer)
	# Таймер для задержки между атаками (1 секунда)
	attack_cooldown_timer = Timer.new()
	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.wait_time = 0.5
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timeout)
	add_child(attack_cooldown_timer)
	# Таймер для отслеживания последовательности атак (5 секунд)
	attack_sequence_timer = Timer.new()
	attack_sequence_timer.one_shot = true
	attack_sequence_timer.wait_time = 5.0
	attack_sequence_timer.timeout.connect(_on_attack_sequence_timeout)
	add_child(attack_sequence_timer)
	# Инициализация таймера для спецатаки
	special_attack_cooldown_timer = Timer.new()
	special_attack_cooldown_timer.one_shot = true
	special_attack_cooldown_timer.wait_time = 10.0  # Кулдаун спецатаки
	special_attack_cooldown_timer.timeout.connect(_on_special_attack_cooldown_timeout)
	add_child(special_attack_cooldown_timer)
	# Таймер для ограничения восстановления ХП
	health_restore_timer = Timer.new()
	health_restore_timer.wait_time = 10.0
	health_restore_timer.one_shot = true
	health_restore_timer.timeout.connect(_on_health_restore_cooldown)
	add_child(health_restore_timer)
	# Таймер для ограничения восстановления СТАМИНЫ
	endurance_restore_timer = Timer.new()
	endurance_restore_timer.wait_time = base_restore_delay
	endurance_restore_timer.one_shot = true
	#endurance_restore_timer.timeout.connect(_start_endurance_restore)
	endurance_restore_timer.timeout.connect(restoring_endurance)
	add_child(endurance_restore_timer)
	# Таймер для принудительного завершения разворота
	direction_change_timer = Timer.new()
	direction_change_timer.one_shot = true
	direction_change_timer.timeout.connect(_force_finish_direction_change)
	add_child(direction_change_timer)

func _physics_process(delta: float) -> void:
	if current_health == 0:
		try_dead()
		return
	handle_gravity(delta)
	handle_running_toggle()
	restoring_health()
	if (Time.get_ticks_msec() - last_action_time >= 2000) or is_resting:
		restoring_endurance()
	attack()
	play_attack_animation()
	if not is_changing_direction:
		update_flip_state()
		handle_movement()
		handle_jump()
		update_animation()
		handle_roll(delta)
	move_and_slide()

func killSkeleton(): # +1 упокоенная кость
	current_endurance = max_endurance
	current_health = max_health
	Global.bones_rested += 1
	update_bones_label()
	
func update_bones_label(): # текст с спокойными костями
	$"../CanvasLayer/Label".text = "Костей упокоено: %d" % Global.bones_rested
	var tween = create_tween()
	tween.tween_property(blood, "modulate:a", 0.0, 0.5)

func handle_gravity(delta: float) -> void: # гравитация
	if not is_on_floor():
		velocity += get_gravity() * delta

func restoring_health() -> void: # реген хп
	if can_restore_health and not is_chased and  current_health < max_health:
		var hp_reg = 5
		current_health = min(current_health + hp_reg, max_health)
		can_restore_health = false
		health_restore_timer.start()
		var tween = create_tween()
		tween.tween_property(blood, "modulate:a", max(0, blood.modulate.a - float(hp_reg)/max_health), 1.0)

func restoring_endurance() -> void: # пассивная регенерация
	if !is_resting:
		var endurance_reg = 3.0 * (2.0 - current_endurance/max_endurance)
		current_endurance = min(current_endurance + endurance_reg, max_endurance)
		if current_endurance >= max_endurance:
			endurance_restore_timer.stop()
	else:
		var progress = 1.0 - (endurance_restore_timer.time_left / exhausted_restore_delay)
		current_endurance = lerp(0, max_endurance, progress)
		if progress >= 1.0:
			is_resting = false
			endurance_restore_timer.stop()

func manage_stamina(action: String) -> bool: # затраты стамины
	last_action_time = Time.get_ticks_msec()
	stop_endurance_restore()
	var cost := 0.0
	match action:
		"attack":
			match current_attack:
				1: cost = 3
				2: cost = 4
				3: cost = 10
				4: cost = 4
				5: cost = 7
			
		"roll":       cost = 3
		"slide":      cost = 5
		"jump":       cost = 2
		"air_dash":   cost = 5
		"take_damage": cost = 8 * (2.0 - (current_health / max_health))
		
	if is_running:
		cost *= 1.5
		attack_damage *= 1.5
	elif not is_running:
		cost *= 0.7
		
	current_endurance = max(current_endurance - cost, 0)
	if current_endurance <= 0:
		_enter_exhaustion()
		
	if cost > 0 or current_endurance < max_endurance:
		endurance_restore_timer.start()
		
	return current_endurance >= cost

func _start_endurance_restore(): # начало регена стамины
	is_resting = false
	endurance_restore_timer.wait_time = base_restore_delay
	can_restore_endurance = true
	restoring_endurance()

func _enter_exhaustion(): # когда уже отрегенилась
	endurance_restore_timer.stop()
	current_endurance = 0.0
	is_running = false
	anim_attack_playing = false
	is_resting = true
	endurance_restore_timer.wait_time = exhausted_restore_delay
	endurance_restore_timer.start()

func stop_endurance_restore():
	can_restore_endurance = false
	endurance_restore_timer.stop()

func set_chased_state(value: bool):
	is_chased = value
	if value:
		if health_restore_timer.time_left > 0:
			health_restore_timer.stop()
			_on_health_restore_cooldown()

func handle_jump() -> void: # прыжок
	if not is_on_floor() and not is_running:
		return
	if not (is_rolling or takeDamage or is_resting):
		if Input.is_action_just_pressed("ui_up") and numberJumps < 1:
			#manage_stamina('jump')
			once_per_flight = true
			numberJumps += 1
			velocity.y = JUMP_VELOCITY

func update_animation() -> void: # анимации
	if is_rolling or anim_attack_playing:
		return

	if takeDamage:
		anim.play("TakingDamage")
		if takeDamage_timer.time_left <= 0:
			takeDamage = false
		return
	
	if not is_on_floor():
		if velocity.y < 0:
			anim.play("BeginningJump")
		elif velocity.y > 0:
			anim.play("EndJump")
			anim.stop()
			anim.frame = anim.sprite_frames.get_frame_count("EndJump") - 1
		return
	if velocity.x != 0:
		numberJumps = 0
		anim.play("Run" if is_running else "Walk")
	else:
		numberJumps = 0
		if is_on_floor():
			anim.play("idle")

func handle_movement() -> void: # скорость перемещения
	if not anim_attack_playing or is_rolling or takeDamage:
		var direction := Input.get_axis("ui_left", "ui_right")
		var current_speed := SPEED * (RUN_MULTIPLIER if is_running else 1)
		if direction != 0:
			velocity.x = direction * current_speed
		elif is_changing_direction:
			velocity.x = was_moving * SPEED * 0.7
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

func update_flip_state() -> void: # направление в котором смотрит персонаж
	if not is_rolling:
		current_movement = sign(velocity.x) if abs(velocity.x) > 10 else (
			-1 if Input.is_action_pressed("ui_left") else (
				1 if Input.is_action_pressed("ui_right") else 0
			)
		)
		
		var should_change = (
			current_movement != was_moving and was_moving != 0 and
			(is_running or is_changing_direction) and 
			not can_flip and not is_rolling and is_on_floor()
		)
		if should_change:
			start_direction_change(was_moving)
			return
		"""
		Персонаж бежит в сторону = 1, при попытке изменить направлении нажимается <- и direction = -1, надо поймать этот момент
		и узнать что предыдущее заначение не соответствует нынешнему и запустить метод изменения направления
		"""
		can_flip = false
		if current_movement == -1 and is_facing_right:
			flip_character(false)
		elif current_movement == 1 and not is_facing_right:
			flip_character(true)
		was_moving = current_movement

func flip_character(facing_right: bool):
	is_facing_right = facing_right
	$AnimatedSprite2D.flip_h = !facing_right
	var offset = 30 if facing_right else -30
	$AnimatedSprite2D.position.x += offset
	$Camera2D.position.x = abs(offset) * 1.67  # ~50
	for area in [$AttackArea1, $AttackArea2, $AttackArea3, $SlideAttackArea, $AttackInFallArea]:
		area.scale.x = 1 if facing_right else -1

func start_direction_change(direction: int): # смена направления
	if animPlayer.current_animation == "AttackInSliding":
		return
	is_changing_direction = true
	animPlayer.play("changeOfDirection")
	direction_change_timer.start(0.34)

func _direction_change_animation_finished():
	if animPlayer.current_animation == "changeOfDirection":
		finish_direction_change()

func finish_direction_change():
	is_changing_direction = false
	can_flip = true
	animPlayer.stop()
	velocity.x = 0

func _force_finish_direction_change():
	if is_changing_direction:
		finish_direction_change()

func handle_running_toggle() -> void: # бег
	if Input.is_action_just_pressed("ui_alt") and not is_resting:
		is_running = !is_running

func handle_roll(delta: float) -> void: # перекат
	if is_rolling:
		roll_timer += delta
		if roll_or_jerk:
			velocity.y = 0
		if roll_timer >= (roll_JerkInAir_duration if roll_or_jerk else roll_duration):
			is_rolling = false
			velocity.x = 0
			set_collision_mask_value(2, true)
			if slide:
				slide = false
		else:
			velocity.x = roll_direction * (roll_distance / (roll_JerkInAir_duration if roll_or_jerk else roll_duration))
		return
	if Input.is_action_just_pressed("ui_shift") and not is_resting and not is_on_floor() and not is_rolling and once_per_flight:
		once_per_flight = false
		roll_or_jerk = true
		is_rolling = true
		roll_timer = 0.0
		roll_direction = sign(velocity.x) if velocity.x != 0 else (1 if is_facing_right else -1)
		roll_distance = base_roll_distance * (RUN_MULTIPLIER / 1.9)
		if not is_running:
			set_collision_mask_value(2, false)
		manage_stamina('air_dash')
		anim.play("JerkInAir")
	if Input.is_action_just_pressed("ui_shift") and not is_resting and is_on_floor() and not is_rolling and is_running:
		roll_or_jerk = false
		is_rolling = true
		roll_timer = 0.0
		roll_direction = sign(velocity.x) if velocity.x != 0 else (1 if is_facing_right else -1)
		roll_distance = base_roll_distance * (RUN_MULTIPLIER)
		current_attack = 3
		slide = true
		set_collision_mask_value(2, false)
		manage_stamina('slide')
		anim.play("Sliding")
	if Input.is_action_just_pressed("ui_shift") and not is_resting and is_on_floor() and not is_rolling and not is_running:
		animPlayer.stop()
		roll_or_jerk = false
		is_rolling = true
		anim_attack_playing = false
		roll_timer = 0.0
		roll_direction = sign(velocity.x) if velocity.x != 0 else (1 if is_facing_right else -1)
		roll_distance = base_roll_distance
		anim.play("RollingOver")
		manage_stamina('roll')
		last_roll_time = Time.get_ticks_msec() / 1000.0  # Записываем время в секундах
		can_do_special_attack = true
		set_collision_mask_value(2, false)

func update_camera_position() -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	var target_position = position
	if direction != 0:
		target_position.x += direction * camera_offset.x
	$Camera2D.position = lerp($Camera2D.position, target_position, 0.1)

func take_damage(amount: int) -> void:
	if not is_rolling or slide:
		current_health -= amount
		if current_health < 0:
			current_health = 0
		takeDamage_timer.wait_time = 0.4
		takeDamage = true
		velocity.x = 0
		anim.play("take_damage")
		takeDamage_timer.start()
		manage_stamina("take_damage")
		
		death_screen.visible = true
		var health_lost_percent: float = (max_health - current_health)/100.0
		var tween = create_tween()
		tween.tween_property(blood, "modulate:a", health_lost_percent, 1.0)

func try_dead() -> void: # смерть
	if not is_dead:
		is_dead = true
		animPlayer.stop()
		anim.play("Death")
		set_collision_layer_value(1, false)
		anim.connect("animation_finished", _on_death_animation_finished)
		
		darken.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(darken, "modulate:a", 1, 1.0)
	if is_dead:
		return

func _on_death_animation_finished(anim_name: String): # анимка смерти
	anim.stop()
	anim.frame = anim.sprite_frames.get_frame_count("Death") - 1

func attack() -> void: # нажатие атаки
	if Input.is_action_just_pressed("ui_Q") and not is_resting and not anim_attack_playing and (not is_rolling or current_attack in [3, 5]):
		var time_since_roll = Time.get_ticks_msec() / 1000.0 - last_roll_time
		if can_do_special_attack and time_since_roll <= 5.0 and not special_attack_cooldown_timer.time_left > 0:
			current_attack = 5
			can_do_special_attack = false
			special_attack_cooldown_timer.start()
		if not is_on_floor():
			current_attack = 4
		velocity.x = 0
		anim_attack_playing = true
		if current_attack == 3 or current_attack == 4 or current_attack == 5:
			return
		if is_in_attack_sequence:
			current_attack = (current_attack % 2) + 1
		else:
			current_attack = 1
			is_in_attack_sequence = true

func play_attack_animation() -> void: # процесс атаки
	if anim_attack_playing:
		match current_attack:
			1:
				animPlayer.play("Attack1")
				current_hit_area = $AttackArea1
				attack_damage = 8
			2:
				animPlayer.play("Attack2")
				current_hit_area = $AttackArea2
				attack_damage = 12
			3:
				animPlayer.play("AttackInSliding")
				current_hit_area = $SlideAttackArea
				attack_damage = 8
			4:
				animPlayer.play("AttackInFall")
				current_hit_area = $AttackInFall
				attack_damage = 12
				if not once_per_flight:
					AttackInFall()
			5:
				animPlayer.play("Attack3")
				current_hit_area = $AttackArea3
				attack_damage = 20
				knockback_mobs()

func trigger_attack_hit() -> void: # нанесение урона
	if !current_hit_area: return
	manage_stamina("attack")
	for body in current_hit_area.get_overlapping_bodies():
		if body.has_method("take_damage") and not body.is_in_group("Player"):
			body.take_damage(attack_damage)
	temp_bodies.clear()

func finish_attack() -> void: # конец атаки
	animPlayer.stop()
	anim_attack_playing = false
	can_attack = false
	attack_cooldown_timer.start()    
	if current_attack in [3, 4, 5]:
		current_attack = 1

func knockback_mobs(): # колющий удар
	var knockback_distance = 20
	var knockback_duration = 1
	var mobs = $AttackArea3.get_overlapping_bodies()
	for mob in mobs:
		if mob != self and mob.is_in_group("SkeletonWarrior"):
			if mob.has_method("take_stunn"):
				mob.take_stunn(knockback_duration)
			var direction = (mob.global_position - global_position).normalized()
			var tween = create_tween()
			tween.tween_property(mob, "position", 
			mob.position + direction * knockback_distance, 
			knockback_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func AttackInFall(): # отскок
	var mobs = $AttackInFallArea.get_overlapping_bodies()
	for mob in mobs:
		if mob != self and mob.is_in_group("SkeletonWarrior"):
			if mob.has_method("take_stunn"):
				mob.take_stunn(1.5)
			once_per_flight = true
			numberJumps += 1
			velocity.y = -100
			velocity.x = -300 * $AttackArea1.scale.x

func _on_attack_cooldown_timeout() -> void:
	can_attack = true 

func _on_attack_sequence_timeout() -> void:
	is_in_attack_sequence = false
	current_attack = 1

func _on_special_attack_cooldown_timeout():
	can_do_special_attack = true

func _on_health_restore_cooldown():
	can_restore_health = true

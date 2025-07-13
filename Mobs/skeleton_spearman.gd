extends CharacterBody2D
@onready var anim = $AnimatedSprite2D
var chase = false
var SPEED = 150

var wander_timer: Timer
var idle_or_wander = false
var wander_direction = 0
var WANDER_SPEED = SPEED / 2
var a1 = true
var animation_time = 0.0
var anim_attack_playing = false
var attack_cooldown_timer: Timer
var attack_sequence_timer: Timer
var current_attack = 1
var can_attack = true
var is_in_attack_sequence = false
var attack_damage = 0

var bodies_in_attack_area: Array = []
var current_attack_area: Area2D = null
var temp_bodies: Array = []

var can_run_attack: bool = true
var run_attack_cooldown_timer: Timer

var current_health = 50
var previous_health = current_health
var max_heal = 50

var is_dead = false  # флаг смерти
var is_stunning = false
var stun_timer: Timer

var hp_bar = preload("res://healBar/mob_heal_bar.tscn").instantiate()
var is_facing_right: bool = true
var right_detected := false

func _ready() -> void:
	wander_timer = Timer.new()
	wander_timer.wait_time = randf_range(1.0, 4.0) # Время для первого цикла
	wander_timer.one_shot = true
	add_child(wander_timer)
	wander_timer.start()
	# таймер для задержки между атаками (1 секунда)
	attack_cooldown_timer = Timer.new()
	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.wait_time = 0.5
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timeout)
	add_child(attack_cooldown_timer)
	# таймер для отслеживания последовательности атак (5 секунд)
	attack_sequence_timer = Timer.new()
	add_child(attack_sequence_timer)
	attack_sequence_timer.one_shot = true
	attack_sequence_timer.wait_time = 5.0
	attack_sequence_timer.timeout.connect(_on_attack_sequence_timeout)
	# Инициализация таймера для атаки в беге
	run_attack_cooldown_timer = Timer.new()
	add_child(run_attack_cooldown_timer)
	run_attack_cooldown_timer.one_shot = true
	run_attack_cooldown_timer.wait_time = 10.0
	run_attack_cooldown_timer.timeout.connect(_on_run_attack_cooldown_timeout)
	# инициализация таймера стана (если его нет)
	stun_timer = Timer.new()
	add_child(stun_timer)
	stun_timer.one_shot = true
	stun_timer.timeout.connect(_on_stun_timeout)
	# первичные настройки хп бара
	add_child(hp_bar)
	hp_bar.visible = false
	hp_bar.value = current_health
	hp_bar.max_value = current_health
	hp_bar.position = Vector2(-25, -40)

func _physics_process(delta: float) -> void:
	if current_health <= 0:
		try_dead()
		return
	handle_gravity(delta)
	if is_stunning:
		anim.play("stunn")
		move_and_slide()
		return
	update_flip_state()
	chasing_player(delta)
	handle_wandering(delta)

	move_and_slide()

func handle_gravity(delta: float) -> void: # гравитация
	if not is_on_floor():
		velocity += get_gravity() * delta

func chasing_player(_delta: float) -> void:
	if not chase:
		return
	var distance_to_player = position.distance_to(get_tree().get_first_node_in_group("Player").position)
	if not anim_attack_playing and can_run_attack and velocity.x != 0:
		if distance_to_player > 650 and distance_to_player < 2400:
			start_attack(true)
			return
	if right_detected:
		velocity.x = SPEED
		if not is_facing_right:
			update_flip_state(true)
	else:
		velocity.x = -SPEED
		if is_facing_right:
			update_flip_state(true)
	if ($Detection/WallCheck.is_colliding() or not $Detection/GroundCheck.is_colliding()):
		var wall_collider = $Detection/WallCheck.get_collider()
		if wall_collider and wall_collider.is_in_group("Player") and can_attack:
			velocity.x = 0
			start_attack(false)
	if anim_attack_playing:
		animation_time += get_process_delta_time()
		if animation_time >= 0.4:
			finish_attack()
			animation_time = 0.0
			anim_attack_playing = false
			can_attack = false
			attack_cooldown_timer.start()
	elif velocity.x != 0:
		anim.play("run")
	else:
		anim.play("idle")
	if not $Detection/GroundCheck.is_colliding():
		velocity.x = 0
		anim.play("idle")

func start_attack(is_run_attack: bool) -> void:
	if not anim_attack_playing:
		anim_attack_playing = true
		animation_time = 0.0
		
		if is_run_attack and can_run_attack:
			velocity.x = SPEED * 3 * (1 if right_detected else -1)
			anim.play("attackInRun")
			current_attack_area = $RunAttackArea
			attack_damage = 15
			can_run_attack = false
			run_attack_cooldown_timer.start()
		else:
			if is_in_attack_sequence:
				current_attack = (current_attack % 3) + 1
			else:
				current_attack = 1
				is_in_attack_sequence = true
				attack_sequence_timer.start()
			match current_attack:
				1:
					anim.play("attack1")
					current_attack_area = $AttackArea1
					attack_damage = 15
				2:
					anim.play("attack2")
					current_attack_area = $AttackArea2
					attack_damage = 30

func finish_attack() -> void:
	if !current_attack_area:
		return
	temp_bodies = current_attack_area.get_overlapping_bodies()
	for body in temp_bodies:
		if body.has_method("take_damage") and not body.is_in_group("SkeletonWarrior"):
			body.take_damage(attack_damage)
	temp_bodies.clear()

func update_flip_state(force_flip: bool = false) -> void: # поворот модельки
	if anim_attack_playing and not force_flip:
		return
	
	var new_flip_state = $AnimatedSprite2D.flip_h

	if force_flip:
		new_flip_state = not new_flip_state
	elif velocity.x != 0:
		new_flip_state = velocity.x < 0
		
	if $AnimatedSprite2D.flip_h != new_flip_state:
		$AnimatedSprite2D.flip_h = new_flip_state
		is_facing_right = not new_flip_state
		
		var attack_scale = -1 if new_flip_state else 1
		$AttackArea1.scale.x = attack_scale
		$AttackArea2.scale.x = attack_scale
		$RunAttackArea.scale.x = attack_scale
		
		var detection_offset = 75 if is_facing_right else -75
		$Detection/CollisionShape2D.position.x = detection_offset
		
		var check_offset = 35 if is_facing_right else -35
		$Detection/WallCheck.target_position.x = check_offset
		$Detection/GroundCheck.target_position.x = check_offset

func _on_detection_body_entered(body: Node2D) -> void: # вход игрока в зону видимости
	if body.name == "Player":
		chase = true
		if body.has_method("set_chased_state"):
			body.set_chased_state(true)

func _on_detection_body_exited(body: Node2D) -> void: # выход игрока из зоны видимости
	if body.name == "Player":
		a1 = true
		chase = false
		anim_attack_playing = false
		if body.has_method("set_chased_state"):
			body.set_chased_state(false)

func handle_wandering(delta: float) -> void: # блуждание
	if chase:
		return
	if wander_timer.time_left <= 0 and not (a1 and (not $Detection/GroundCheck.is_colliding() or $Detection/WallCheck.is_colliding())):
		_on_wander_timeout()
	if idle_or_wander:
		if a1 and (not $Detection/GroundCheck.is_colliding() or $Detection/WallCheck.is_colliding()):
			a1 = false
			wander_direction= -wander_direction
		velocity.x = wander_direction * WANDER_SPEED
		anim.play("walk")
	else:
		if a1 and (not $Detection/GroundCheck.is_colliding() or $Detection/WallCheck.is_colliding()):
			a1 = false
			_on_wander_timeout("walk")
		else:
			velocity.x = 0
			anim.play("idle")

func _on_wander_timeout(action := "random", direction := 0) -> void:
	match action:
		"walk":
			idle_or_wander = true
			wander_direction = randf_range(-1, 1)
			wander_timer.wait_time = randf_range(1, 4)
		"idle":
			idle_or_wander = false
			wander_timer.wait_time = randf_range(1, 5)
		"random":
			if randi() % 2 == 0:
				idle_or_wander = true
				wander_direction = randf_range(-1, 1)
				wander_timer.wait_time = randf_range(1, 4)
			else:
				idle_or_wander = false
				wander_timer.wait_time = randf_range(1, 10)
	a1 = true
	wander_timer.start()

func take_damage(amount: int) -> void:
	current_health -= amount
	hp_bar.value = current_health
	if current_health < 0:
		current_health = 0
	if !hp_bar.visible:
		hp_bar.visible = true

func take_stunn(amount: int) -> void:
	if is_stunning:
		return
	is_stunning = true
	anim_attack_playing = false
	velocity.x = 0
	stun_timer.start(amount)

func try_dead():
	if not is_dead:
		var player = get_tree().get_first_node_in_group("Player")
		if player and player.has_method("killSkeleton"):
			player.killSkeleton()
		set_collision_layer_value(2, false)
		is_dead = true
		anim.play("dead")
		anim.connect("animation_finished", _on_death_animation_finished)
		hp_bar.queue_free()
	if is_dead:
		return

func _on_stun_timeout() -> void:
	is_stunning = false

func _on_death_animation_finished(anim_name: String):
	if anim_name == "dead":
		anim.stop()
		anim.frame = anim.sprite_frames.get_frame_count("dead") - 1

func _on_attack_cooldown_timeout() -> void:
	can_attack = true

func _on_attack_sequence_timeout() -> void:
	is_in_attack_sequence = false
	current_attack = 1

func _on_run_attack_cooldown_timeout() -> void:
	can_run_attack = true
	
func _on_right_detection_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		right_detected = true
	
func _on_right_detection_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		right_detected = false

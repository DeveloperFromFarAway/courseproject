extends CharacterBody2D
@onready var anim = $AnimatedSprite2D
var chase = false
var SPEED = 150

var wander_timer: Timer
var idle_or_wander = false
var wander_direction = 0 # -1 для левого направления, 1 для правого
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

var can_run_attack: bool = true
var run_attack_cooldown_timer: Timer

var current_health = 30
var previous_health = current_health
var max_heal = 30

var is_dead = false  # флаг смерти
var is_stunning = false
var stun_timer: Timer

var hp_bar = preload("res://healBar/mob_heal_bar.tscn").instantiate()
var is_facing_right: bool = true
var right_detected := false

var arrow_scene = preload("res://Mobs/skeleton_arrow.tscn")
const SHOT_DAMAGE = 15
const SHOT_COOLDOWN = 3
const SHOT_DELAY = 0.3
enum State {WANDERING, CHASING, ATTACKING}
var current_state = State.WANDERING
@onready var animPlayer = $AnimationPlayer

func _ready() -> void:
	wander_timer = Timer.new()
	wander_timer.wait_time = randf_range(1.0, 4.0) # время для первого цикла
	wander_timer.one_shot = true
	add_child(wander_timer)
	wander_timer.start()
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
	if current_state != State.CHASING:
		animPlayer.stop()
		return
	velocity.x = 0
	
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return
	
	if right_detected:
		if not is_facing_right:
			update_flip_state(true)
	else:
		if is_facing_right:
			update_flip_state(true)

func perform_shot():
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not is_instance_valid(player):
		return
		
	# Создаем стрелу
	var arrow = arrow_scene.instantiate()
	get_parent().add_child(arrow)
	
	arrow.global_position = $ShotPosition.global_position
	arrow.direction = (player.global_position - global_position).normalized()
	arrow.rotation = arrow.direction.angle()
	arrow.damage = SHOT_DAMAGE
	arrow.speed = 600
	current_state = State.CHASING
	anim_attack_playing = false

func handle_wandering(delta: float) -> void: # блуждание
	if current_state != State.WANDERING:
		animPlayer.play("Shot_1")
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

func _on_detection_body_entered(body: Node2D) -> void: # вход игрока в зону видимости
	if body.name == "Player":
		current_state = State.CHASING
		if body.has_method("set_chased_state"):
			body.set_chased_state(true)

func _on_detection_body_exited(body: Node2D) -> void: # выход игрока из зоны видимости
	if body.name == "Player":
		a1 = true
		current_state = State.WANDERING
		anim_attack_playing = false
		if body.has_method("set_chased_state"):
			body.set_chased_state(false)

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
		
		var detection_offset = 75 if is_facing_right else -75
		$Detection/CollisionShape2D.position.x = detection_offset
		
		var check_offset = 35 if is_facing_right else -35
		$Detection/WallCheck.target_position.x = check_offset
		$Detection/GroundCheck.target_position.x = check_offset

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
	take_stunn(1)
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
	animPlayer.stop()
	stun_timer.start(amount)

func try_dead():
	if not is_dead:
		var player = get_tree().get_first_node_in_group("Player")
		if player and player.has_method("killSkeleton"):
			player.killSkeleton()
		
		set_collision_layer_value(2, false)
		is_dead = true
		animPlayer.stop()
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
	
func _on_right_detection_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		right_detected = true
	
func _on_right_detection_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		right_detected = false

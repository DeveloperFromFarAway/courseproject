extends Area2D

var speed = 300
var damage = 15
var direction = Vector2.RIGHT
var velocity = Vector2.ZERO

func _ready():
	$LifetimeTimer.start(3.0)

func _physics_process(delta):
	position += direction * speed * delta

func _on_Arrow_body_entered(body):
	if body.has_method("take_damage") and not body.is_in_group("SkeletonWarrior"):
		body.take_damage(damage)
		queue_free()

func _on_LifetimeTimer_timeout():
	queue_free()

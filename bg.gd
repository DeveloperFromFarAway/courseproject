extends ParallaxBackground

var speed = 15

func _process(delta):
	scroll_offset.x -= speed * delta

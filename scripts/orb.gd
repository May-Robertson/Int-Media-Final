extends Area2D

var speed = 30 + ProgressManager.enemies_killed
var direction = Vector2.RIGHT  # in case of any issues getting direction

func _ready():
	body_entered.connect(_on_body_entered)
	
func set_direction(new_direction: Vector2):
	direction = new_direction.normalized()

func set_velocity(velocity_vector: Vector2):
	direction = velocity_vector.normalized()


func _physics_process(delta):
	position += direction * speed * delta
	rotation = direction.angle()

func _on_body_entered(body):
	if body.is_in_group("player") and body.current_state != 4:
		if not body.is_jumping:
			if body.has_method("take_damage"):
				body.take_damage(10, (body.global_position - global_position).normalized())
			queue_free()
	elif body.is_in_group("walls"):
		queue_free()

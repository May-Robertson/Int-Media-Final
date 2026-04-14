extends Label

@onready var flash_timer: Timer = $Timer

func _ready() -> void:
	if flash_timer:
		flash_timer.wait_time = 0.8
		flash_timer.one_shot = false
		flash_timer.timeout.connect(_on_flash_timeout)
		flash_timer.start()

func _on_flash_timeout() -> void:
	self.visible = !self.visible

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/Level.tscn")

		

extends Camera2D

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var original_position: Vector2

# camera shake is stronger for stronger attacks

func _ready():
	original_position = position
	HitStopManager.camera_shake_requested.connect(_on_camera_shake_requested)

func _on_camera_shake_requested(intensity: float, duration: float):
	start_shake(intensity, duration)
func _process(delta: float):
	if shake_duration > 0:
		shake_duration -= delta
		position = original_position + Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		
		if shake_duration <= 0:
			position = original_position
			shake_intensity = 0.0

func start_shake(intensity: float, duration: float):
	shake_intensity = intensity
	shake_duration = duration

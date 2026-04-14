extends Node

signal camera_shake_requested(intensity:float, duration: float)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass





func hit_stop_short():
	print("HITSTOP SHORT")
	Engine.time_scale = 0
	# process always = true
	# process in physics = false
	# ignore time scale = true
	# these let it run even when the game is paused
	await get_tree().create_timer(0.09, true, false, true).timeout
	Engine.time_scale = 1 


func hit_stop_medium():
	print("HITSTOP MED")
	Engine.time_scale = 0
	camera_shake_requested.emit(0.3, 0.1)
	await get_tree().create_timer(0.09, true, false, true).timeout
	Engine.time_scale = 1 


func hit_stop_long():
	print("HITSTOP LONG")
	Engine.time_scale = 0
	camera_shake_requested.emit(1.0, 0.2)
	await get_tree().create_timer(0.25, true, false, true).timeout
	Engine.time_scale = 1 

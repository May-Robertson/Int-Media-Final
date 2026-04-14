extends Node

@onready var PauseLabel: Label = $"../Pause_Overlay"
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# pause and unpause
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		if get_tree().paused == false:	
			PauseLabel.visible = true
			get_tree().paused = true	
		elif get_tree().paused == true:
			PauseLabel.visible = false
			get_tree().paused = false

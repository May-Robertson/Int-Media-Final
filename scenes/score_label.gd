extends Label


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	self.text = "Enemies Killed: "+str(ProgressManager.enemies_killed)
	pass

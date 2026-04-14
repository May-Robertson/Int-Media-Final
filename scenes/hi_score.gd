extends Label

var high_score = ""
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	high_score = ProgressManager.load()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	self.text = "High Score: "+str(high_score)
	pass

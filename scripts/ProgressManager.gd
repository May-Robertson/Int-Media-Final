extends Node

var difficulty = 0
var enemies_killed = 0
var curr_high_score = 0
func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if ProgressManager.load():
		curr_high_score = ProgressManager.load()
	pass

func save(content):
	print("CONTENT"+str(content))
	if int(content) > int(curr_high_score):
		var file = FileAccess.open("res://hi-score.txt", FileAccess.WRITE)
		file.store_string(content)

func load():
	var file = FileAccess.open("res://hi-score.txt", FileAccess.READ)
	var content = file.get_as_text()
	return content

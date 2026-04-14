extends Label

@onready var player_scene = preload("res://scenes/player.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player_scene = get_tree().get_first_node_in_group("player")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player_scene:
		self.text = "HP: "+str(player_scene.health)
	else:
		pass

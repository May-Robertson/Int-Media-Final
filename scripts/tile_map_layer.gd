extends TileMapLayer

var _3d_layer: int = 0

var brightness_base: float = 0.75
var brightness_fade_step: float = 0.15

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# -1 to put the player on top of the tiles
	z_index = _3d_layer - 1
	
	#brightness of the tiles to make them visually set apart from each other
	var brightness: float = brightness_base + ((_3d_layer - 1) * brightness_fade_step)
	brightness = clamp(brightness, 0.0, 2.0)
	modulate = Color(brightness, brightness, brightness)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

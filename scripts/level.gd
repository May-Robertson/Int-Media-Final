extends Node2D

@onready var PauseLabel: Label = $Pause_Overlay


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var window = get_window()
	window.mode = Window.MODE_FULLSCREEN
	get_viewport().set_default_canvas_item_texture_filter(Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
		pass

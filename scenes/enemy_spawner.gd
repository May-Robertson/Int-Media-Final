extends Node2D

var spawn_interval = 5.0
var spawn_timer = 0.0
@onready var enemy_scene = preload("res://scenes/enemy.tscn")
@onready var enemy_lvl2_scene = preload("res://scenes/enemy_lvl2.tscn")
@onready var enemy_lvl3_scene = preload("res://scenes/enemy_lvl3.tscn")


func _ready():
	spawn_timer = 0.0

func _process(delta: float):
	# count down
	spawn_timer -= delta
	
	# when timer reaches 0 or below
	if spawn_timer <= 0:
		spawn_enemy()
		# reset timer
		spawn_timer = spawn_interval

func spawn_enemy():
	
	# spawn different enemy depending on how many enemies have been killed
	if ProgressManager.enemies_killed < 10:
		var enemy = enemy_scene.instantiate()
		enemy.global_position = Vector2(randf_range(0, 225), randf_range(0, 125))
		add_child(enemy)
	elif ProgressManager.enemies_killed > 10 and ProgressManager.enemies_killed < 20:
		var enemylvl2 = enemy_lvl2_scene.instantiate()
		enemylvl2.global_position = Vector2(randf_range(0, 225), randf_range(0, 125))
		add_child(enemylvl2)
	if ProgressManager.enemies_killed > 20:
		var enemylvl3 = enemy_lvl3_scene.instantiate()
		enemylvl3.global_position = Vector2(randf_range(0, 225), randf_range(0, 125))
		add_child(enemylvl3)
	
	
	
	
	# Set random position
	

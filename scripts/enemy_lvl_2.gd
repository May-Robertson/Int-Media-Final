extends CharacterBody2D


signal enemy_hit(damage, knockback_direction)
signal enemy_died

const GRAVITY: float = -400.0
var z_height: float = 0.0
var z_velocity: float = 0.0
var is_bouncing: bool = false
var wallbounce_force: float = 180.0
var horizontal_bounce_force: float = 150.0

var in_hitstun: bool = false
var hitstun_timer: float = 0.0
var hitstun_duration: float = 0.5

var in_air: bool = false
var knockdown_timer: float = 0.0
var knockdown_duration: float = 1.0

var launch_force: float = 175.0
var launch_upward_force: float = 100.0 

var heavy_launch_horizontal_max: float = 450.0
var heavy_launch_upward_max: float = 150.0

var current_speed: float = 0.0
var final_knockback = 0.0

var health: int = 300
var max_health: int = 150
var speed: float = 80.0
var damage: int = 50
var knockback_force: float = 0
var invincible: bool = false
var invincible_duration: float = 0.1

var bounce_timer: float = 0.0
var bounce_duration: float = 0.2

var is_charging_heavy: bool = false
var heavy_charge_time: float = 0.0
var max_charge_time: float = 2.0
var min_knockback: float = 50.0
var max_knockback: float = 200.0
var min_damage: int = 25
var max_damage: int = 80




@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var shadow: Sprite2D = $Shadow
@onready var hitbox: Area2D = $Hitbox

@onready var orb = preload("res://scenes/orb.tscn")
@onready var AudioPlayer: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var DeathAudioPlayer: AudioStreamPlayer2D = $AudioDeath

var is_moving: bool = false
var move_duration: float = 0.3
var move_timer: float = 0.0
var pause_duration: float = 2.0
var pause_timer: float = 0.0
var current_direction: Vector2 = Vector2.ZERO

var shoot_timer: float = 0.0
var shoot_interval: float = 0.4



enum AttackPattern {
	SINGLE_SHOT,
	TRIPLE_SHOT,
	SHOTGUN_BLAST,
	HEAVY_BARRAGE
}

var current_attack: AttackPattern = AttackPattern.SINGLE_SHOT
var is_attacking: bool = false
var heavy_attack_timer: float = 0.0
var heavy_charge_duration: float = 2.0
var heavy_barrage_waves: int = 6
var heavy_barrage_wave_count: int = 0
var heavy_barrage_wave_timer: float = 0.0
var heavy_barrage_wave_interval: float = 0.3
var heavy_barrage_shots_per_wave: int = 8


var rng = RandomNumberGenerator.new()
func _ready():
	add_to_group("enemy")
	rng.randomize()
	
	if has_node("Hitbox"):
		$Hitbox.area_entered.connect(_on_hitbox_entered)

func _physics_process(delta: float):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	

	if is_charging_heavy:
		handle_heavy_attack(delta, player)
		return
	
	if in_air:
		apply_air_physics(delta)
		update_visuals()
		
		var collision = move_and_collide(velocity * delta)
		if collision:
			var collider = collision.get_collider()
			if collider.is_in_group("walls"):
				print("WALL COLLISION IN AIR!")
				wall_bounce_anim(collision)
				return
		
		if z_height <= 0:
			land_from_launch()
		return
	
	if is_bouncing:
		apply_bounce_physics(delta)
		update_visuals()
		return
	
	update_visuals()
	
	if in_hitstun:
		hitstun_timer -= delta
		if hitstun_timer <= 0:
			in_hitstun = false
			modulate = Color.WHITE
	
	if in_hitstun:
		var collision = move_and_collide(velocity * delta)
		if collision:
			var collider = collision.get_collider()
			if collider.is_in_group("walls"):
				print("WALL COLLISION! WITH MOVE_AND_COLLIDE!")
				wall_bounce_anim(collision)
				return
		return
	
	if is_moving:
		current_speed = move_toward(current_speed, speed, speed * delta * 2)
		velocity = current_direction * current_speed
		move_and_slide()
		
		move_timer -= delta
		if move_timer <= 0:
			is_moving = false
			current_speed = 0
			velocity = Vector2.ZERO
			pause_timer = pause_duration
	else:
		current_speed = move_toward(current_speed, 0, speed * delta * 4)
		velocity = velocity.move_toward(Vector2.ZERO, speed * delta)
		move_and_slide()
		
		pause_timer -= delta
		if pause_timer <= 0 and not is_attacking:
			start_movement_burst(player)
			if floor(randf_range(0, 2)) == 1 and not is_attacking:
				choose_and_execute_attack(player)

func choose_and_execute_attack(player: Node2D):
	if in_air or is_bouncing or in_hitstun or is_attacking:
		return
	
	var killed = ProgressManager.enemies_killed
	
	var single_weight = max(100 - killed * 5, 10)
	var triple_weight = 30 + killed * 3
	var shotgun_weight = 10 + killed * 4
	var heavy_weight = max(killed * 2 - 10, 0)
	
	var total_weight = single_weight + triple_weight + shotgun_weight + heavy_weight
	var roll = rng.randf() * total_weight
	
	if roll < single_weight:
		current_attack = AttackPattern.SINGLE_SHOT
		execute_single_shot(player)
	elif roll < single_weight + triple_weight:
		current_attack = AttackPattern.TRIPLE_SHOT
		execute_triple_shot(player)
	elif roll < single_weight + triple_weight + shotgun_weight:
		current_attack = AttackPattern.SHOTGUN_BLAST
		execute_shotgun_blast(player)
	else:
		current_attack = AttackPattern.HEAVY_BARRAGE
		execute_heavy_barrage_start()

func execute_single_shot(player: Node2D):
	is_attacking = true
	anim.play("ghoul_shoot")
	
	var direction = (player.global_position - global_position).normalized()
	fire_projectile_at_direction(direction)
	
	await get_tree().create_timer(0.5).timeout
	is_attacking = false

func execute_triple_shot(player: Node2D):
	is_attacking = true
	
	var direction = (player.global_position - global_position).normalized()
	
	for i in range(3):
		anim.play("ghoul_shoot")
		fire_projectile_at_direction(direction)
		await get_tree().create_timer(0.9).timeout
	
	await get_tree().create_timer(0.3).timeout
	is_attacking = false

func execute_shotgun_blast(player: Node2D):
	is_attacking = true
	anim.play("ghoul_shoot")
	
	var base_direction = (player.global_position - global_position).normalized()
	var spread_angle = 60.0
	var num_projectiles = 6
	for j in range(3):
		for i in range(num_projectiles):
			var angle_offset = deg_to_rad(-spread_angle/2 + (spread_angle * i / (num_projectiles - 1)))
			var shot_direction = base_direction.rotated(angle_offset)
			fire_projectile_at_direction(shot_direction)
		await get_tree().create_timer(0.9).timeout	
	
	await get_tree().create_timer(0.5).timeout
	is_attacking = false

func execute_heavy_barrage_start():
	is_attacking = true
	is_charging_heavy = true
	heavy_attack_timer = heavy_charge_duration
	
	modulate = Color(1.5, 1.5, 1.5)
	anim.play("enemy_heavy")
	
	print("Heavy attack charging...")

func handle_heavy_attack(delta: float, player: Node2D):
	heavy_attack_timer -= delta
	
	modulate = Color(1.5, 1.5, 1.5) if int(heavy_attack_timer * 10) % 2 == 0 else Color.WHITE
	
	if heavy_attack_timer <= 0:
		is_charging_heavy = false
		modulate = Color.WHITE
		heavy_barrage_wave_count = 0
		heavy_barrage_wave_timer = 0
		execute_heavy_barrage_wave(player)

func execute_heavy_barrage_wave(player: Node2D):
	if heavy_barrage_wave_count >= heavy_barrage_waves:
		is_attacking = false
		anim.play("ghoul_move")
		return
	
	heavy_barrage_wave_count += 1
	
	for i in range(heavy_barrage_shots_per_wave):
		var angle = (2 * PI * i) / heavy_barrage_shots_per_wave
		var direction = Vector2.RIGHT.rotated(angle)
		fire_projectile_at_direction(direction)
	
	await get_tree().create_timer(heavy_barrage_wave_interval).timeout
	execute_heavy_barrage_wave(player)

func fire_projectile():
	if in_air:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var direction = (player.global_position - global_position).normalized()
		fire_projectile_at_direction(direction)

func fire_projectile_at_direction(direction: Vector2):
	var fired_orb = orb.instantiate()
	get_tree().root.add_child(fired_orb)
	fired_orb.global_position = $projectile_spawner.global_position
	
	if fired_orb.has_method("set_direction"):
		fired_orb.set_direction(direction)
	elif fired_orb.has_method("set_velocity"):
		fired_orb.set_velocity(direction * 200)

func start_movement_burst(player: Node2D):
	if in_hitstun or is_bouncing or in_air or is_attacking:
		return
	current_direction = (player.global_position - global_position).normalized()
	if current_direction.x != 0:
		anim.flip_h = current_direction.x < 0
	is_moving = true
	anim.play("ghoul_move")
	move_timer = move_duration

func apply_air_physics(delta: float):
	z_velocity += GRAVITY * delta
	z_height += z_velocity * delta
	velocity = velocity.lerp(Vector2.ZERO, 5.0 * delta)

func land_from_launch():
	print("LANDED FROM LAUNCH!")
	z_height = 0
	z_velocity = 0
	in_air = false
	z_index = 0

func wall_bounce_anim(collision: KinematicCollision2D):
	print("WALL BOUNCE FROM COLLISION")
	is_bouncing = true
	in_air = false
	z_index = 1
	
	var bounce_direction = collision.get_normal()
	velocity = bounce_direction * horizontal_bounce_force
	z_velocity = wallbounce_force
	
	if bounce_direction.x != 0:
		anim.flip_h = bounce_direction.x > 0

func apply_bounce_physics(delta: float):
	z_velocity += GRAVITY * delta
	z_height += z_velocity * delta
	velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
	move_and_slide()
	
	if z_height <= 0:
		z_height = 0
		z_velocity = 0
		is_bouncing = false
		in_hitstun = false
		modulate = Color.WHITE
		z_index = 0
		pause_timer = 0.5

func update_visuals():
	anim.position.y = -z_height
	var shadow_scale = clamp(1.0 - (z_height * 0.005), 0.4, 1.0)
	shadow.scale = Vector2.ONE * shadow_scale

func _on_hitbox_entered(area: Area2D):
	if area.get_parent().is_in_group("player"):
		var player = area.get_parent()
		var knockback_direction = (player.global_position - global_position).normalized()
		if player.has_method("take_damage"):
			player.take_damage(damage, knockback_direction)

func take_damage(damage_amount: int, knockback_direction: Vector2, combo_stage: int, is_comboing, custom_knockback: float = 0, hit_type: String = "normal"):
	if invincible:
		return
	AudioPlayer.play()
	if is_attacking or is_charging_heavy:
		is_attacking = false
		is_charging_heavy = false
		modulate = Color.WHITE
	
	health -= damage_amount
	print("Enemy took ", damage_amount, " damage! Health: ", health, "/", max_health)
	enemy_hit.emit(damage_amount, knockback_direction)
	
	if hit_type == "helm_breaker":
		HitStopManager.hit_stop_short()
	
	if custom_knockback > 0 and not is_comboing:
		var charge_percent = clamp((custom_knockback - min_knockback) / (max_knockback - min_knockback), 0.0, 1.0)
		launch_from_heavy(knockback_direction, charge_percent)
		invincible = true
		await get_tree().create_timer(invincible_duration).timeout
		invincible = false
		if health <= 0:
			die()
		return
	
	if combo_stage == 2 and is_comboing:
		HitStopManager.hit_stop_medium()
		launch_enemy(knockback_direction)
		invincible = true
		await get_tree().create_timer(invincible_duration).timeout
		invincible = false
		if health <= 0:
			die()
		return
	
	in_hitstun = true
	hitstun_timer = hitstun_duration
	modulate = Color.RED
	anim.play("ghoul_hitstun")

	if combo_stage == 1:
		final_knockback = 20
	else:
		final_knockback = 10
	
	velocity = knockback_direction * final_knockback
	print("HIT WITH ", final_knockback, " knockback")
	
	invincible = true
	await get_tree().create_timer(invincible_duration).timeout
	invincible = false
	
	if health <= 0:
		die()

func launch_with_forces(horizontal_force: float, upward_force: float, direction: Vector2):
	print("LAUNCHED! Horizontal: ", horizontal_force, " Upward: ", upward_force)
	in_air = true
	in_hitstun = false
	is_bouncing = false
	z_index = 1
	
	velocity = direction * horizontal_force
	z_velocity = upward_force
	
	anim.play("ghoul_hitstun")

func launch_enemy(knockback_direction: Vector2):
	launch_with_forces(launch_force, launch_upward_force, knockback_direction)

func launch_from_heavy(knockback_direction: Vector2, charge_percent: float):
	HitStopManager.hit_stop_long()
	var horizontal = lerp(min_knockback, heavy_launch_horizontal_max, charge_percent)
	var upward = lerp(50.0, heavy_launch_upward_max, charge_percent)
	launch_with_forces(horizontal, upward, knockback_direction)

func die():
	print("Enemy died!")
	DeathAudioPlayer.play()
	ProgressManager.enemies_killed += 1
	enemy_died.emit()
	queue_free()

func _on_animated_sprite_2d_animation_finished() -> void:
	if not in_hitstun and not is_bouncing and not in_air and not is_attacking:
		anim.play("ghoul_move")

extends CharacterBody2D

@onready var player_anim: AnimatedSprite2D = $animation_holder/AnimatedSprite2D
@onready var shadow: Node2D = $Shadow
@onready var anim_player: AnimationPlayer = $animation_holder/AnimationPlayer
@onready var anim_holder: Node2D = $animation_holder
@onready var WeaponHitbox: Area2D = $animation_holder/WeaponHitbox
@onready var AudioPlayer: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var AudioDamagePlayer: AudioStreamPlayer2D = $AudioDamage
signal player_hit(damage, knockback_direction)
signal player_died

var health: int = 20
var max_health: int = 100
var invincible: bool = false
var invincible_duration: float = 1.0
var knockback_force: float = 50

var charge_flash_timer: float = 0.0
var is_in_knockback: bool = false

enum State { IDLE, MOVING, ATTACKING, JUMPING, ROLLING, HELM_BREAKER }
var current_state = State.IDLE

var is_dead = false

# ground combo array
var LightComboState: Array[String] = ["combo1", "combo2", "combo3"]

var combo_stage = 0

# window to hit the next attack in the combo before the combo drops
var combo_timer: SceneTreeTimer = null
var is_comboing: bool = false
var waiting_for_combo_input: bool = false

# roll variables
var is_rolling: bool = false
var roll_speed: float = 100.0
var roll_duration: float = 0.3
var roll_timer: float = 0.0
var roll_cancel_available: bool = false
var can_roll: bool = true
var roll_cooldown: float = 0.5
var roll_cooldown_timer: float = 0.0

const MAX_SPEED: float = 60.0
const ACCELERATION: float = 30.5
const FRICTION: float = 16.5
const JUMP_FORCE: float = 100.0
const GRAVITY: float = -280.0

# air attack, "Helm Breaker"
var helm_breaker_fall_speed: float = -100.0
var is_helm_breaker: bool = false
var helm_breaker_phase: int = 0

var z_height: float = 0.0
var z_velocity: float = 0.0
var is_jumping: bool = false
var is_attacking: bool = false

var original_holder_pos: Vector2
var current_sprite_offset_x: float = 0.0
var current_sprite_offset_y: float = 0.0

var is_charging_heavy: bool = false
var heavy_charge_time: float = 0.0
var max_charge_time: float = 2.0
var min_knockback: float = 50.0
var max_knockback: float = 200.0
var min_damage: int = 25
var max_damage: int = 80

var charge_damage: int = 25
var charge_knockback: float = 50
var current_anim_name: String = ""

func _ready():
	original_holder_pos = anim_holder.position
	anim_player.animation_finished.connect(_on_animation_player_animation_finished)
	player_anim.animation_finished.connect(_on_animated_sprite_finished)
	add_to_group("player")
	WeaponHitbox.area_entered.connect(_on_weapon_hitbox_entered)
	$"animation_holder/WeaponHitbox/smear-box".disabled = true
	$"animation_holder/WeaponHitbox/large-box".disabled = true
	$animation_holder/WeaponHitbox/CollisionShape2D.disabled = true

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var input = Input.get_vector("left", "right", "up", "down")
	if roll_cooldown_timer > 0:
		roll_cooldown_timer -= delta
	
	if is_rolling:
		handle_roll(delta)
		return
	if is_helm_breaker:
		handle_helm_breaker(delta, input)
		return
	
	if not is_attacking:
		if is_charging_heavy and not is_jumping:
			velocity = velocity.lerp(Vector2.ZERO, FRICTION * delta)
		else:
			velocity = velocity.lerp(input * MAX_SPEED, (ACCELERATION if input else FRICTION) * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, FRICTION * delta)
	
	if not is_in_knockback and velocity.x != 0 and not is_rolling:
		anim_holder.scale.x = -1 if velocity.x < 0 else 1
	
	if Input.is_action_just_pressed("roll"):
		attempt_roll()
	
	if Input.is_action_just_pressed("jump") and not is_jumping and not is_attacking and not is_rolling:
		z_velocity = JUMP_FORCE
		is_jumping = true
		current_state = State.JUMPING
		z_index = 1

	if not is_jumping and z_index != 0:
		z_index = 0
	
	if is_jumping:
		apply_z_physics(delta)

	# ground combo
	if Input.is_action_just_pressed("player_light_attack") and not is_jumping and not is_rolling:
		if waiting_for_combo_input and is_comboing:
			continue_combo()
		elif not is_attacking and not waiting_for_combo_input:
			start_new_combo()
	
	# air attack
	if Input.is_action_just_pressed("player_light_attack") and is_jumping and not is_rolling and not is_attacking:
		start_helm_breaker()

	# heavy attack start
	if Input.is_action_pressed("player_heavy_attack") and not is_attacking and not is_jumping and not is_charging_heavy and not is_rolling:
		start_charging_heavy()
	
	# heavy attack
	if is_charging_heavy:
		if Input.is_action_pressed("player_heavy_attack"):
			heavy_charge_time += delta
			
			if int(heavy_charge_time * 10) % 3 == 0:
				modulate = Color.RED
			else:
				modulate = Color.WHITE
		else:
			perform_charged_heavy_attack()
			modulate = Color.WHITE
	
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
	
	update_visuals(delta)
	if is_attacking or is_charging_heavy or is_rolling:
		return

	# jump animation
	if is_jumping:
		if z_velocity > 0:
			play_animation("jump_up")
		else:
			play_animation("falling")
		return
		
	# run animation
	if velocity.length() > 10:
		current_state = State.MOVING
		play_animation("run")
	else:
	# idle animation
		current_state = State.IDLE
		play_animation("idle")

# air attack functions
func start_helm_breaker():
	is_helm_breaker = true
	is_attacking = true
	helm_breaker_phase = 0
	current_state = State.HELM_BREAKER
	
	# reset combo
	reset_combo()
	
	# start helm breaker
	current_anim_name = "helm_breaker_start"
	play_animation("helm_breaker_start")
	
	# enable hitbox
	$animation_holder/WeaponHitbox/CollisionShape2D.disabled = false

# increase gravity so the attack falls to the ground faster
const HELM_BREAKER_GRAVITY_SCALE: float = 3.0

func handle_helm_breaker(delta: float, input: Vector2):
	velocity.x = lerp(velocity.x, input.x * MAX_SPEED * 0.3, ACCELERATION * delta)
	
	if helm_breaker_phase == 0:
		# animation start, hovers in the air for a bit
		z_velocity += GRAVITY * 0.3 * delta
		z_height += z_velocity * delta
		
		# land at end of attack
		if z_height <= 0 and z_velocity <= 0:
			z_height = 0
			z_velocity = 0
			is_jumping = false
			land_helm_breaker()
			
	elif helm_breaker_phase == 1:
		z_velocity = helm_breaker_fall_speed
		z_height += z_velocity * delta
		if z_height <= 0:
			land_helm_breaker()
	
	move_and_slide()
	update_visuals(delta)

func land_helm_breaker():
	is_helm_breaker = false
	is_attacking = false
	helm_breaker_phase = 0
	z_height = 0
	z_velocity = 0
	is_jumping = false
	current_state = State.IDLE
	current_anim_name = ""
	
	# make sure all the hitboxes are disabled when the attack is done
	$"animation_holder/WeaponHitbox/smear-box".disabled = true
	$"animation_holder/WeaponHitbox/air-combo-box".disabled = true
	$"animation_holder/WeaponHitbox/large-box".disabled = true
	$animation_holder/WeaponHitbox/CollisionShape2D.disabled = true


# ground combo functions
func start_new_combo():
	is_comboing = true
	combo_stage = 0
	waiting_for_combo_input = false
	roll_cancel_available = false
	
	if combo_timer:
		combo_timer.timeout.disconnect(_on_combo_timeout)
		combo_timer = null
	
	start_attack(LightComboState[combo_stage])

func continue_combo():
	if combo_stage < 2:
		combo_stage += 1
		
		waiting_for_combo_input = false
		roll_cancel_available = false
		
		if combo_timer:
			combo_timer.timeout.disconnect(_on_combo_timeout)
			combo_timer = null
		
		start_attack(LightComboState[combo_stage])
	else:
		reset_combo()


# roll function
func attempt_roll():
	if not can_roll:
		return
	
	if roll_cooldown_timer > 0:
		return
	
	if is_jumping:
		return
	
	if is_in_knockback:
		return
	
	if is_attacking and not roll_cancel_available:
		return
	
	start_roll()

func start_roll():
	$"animation_holder/WeaponHitbox/smear-box".disabled = true
	$"animation_holder/WeaponHitbox/large-box".disabled = true
	$animation_holder/WeaponHitbox/CollisionShape2D.disabled = true

	is_rolling = true
	is_attacking = false
	is_charging_heavy = false
	is_helm_breaker = false
	current_state = State.ROLLING
	
	reset_combo()
	roll_cancel_available = false
	
	var roll_direction = 1 if anim_holder.scale.x > 0 else -1
	velocity.x = roll_direction * roll_speed
	velocity.y = 0
	
	roll_timer = roll_duration
	invincible = true
	
	play_animation("roll")

func handle_roll(delta: float):
	roll_timer -= delta
	
	if roll_timer < 0.1:
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
	
	move_and_slide()
	
	if roll_timer <= 0:
		end_roll()

func end_roll():
	is_rolling = false
	velocity = Vector2.ZERO
	current_state = State.IDLE
	
	invincible = false
	roll_cooldown_timer = roll_cooldown
	
	play_animation("idle")

# handles passing variables to the enemy that gets hit
func _on_weapon_hitbox_entered(area: Area2D):
	if area.get_parent().is_in_group("enemy"):
		
		var enemy = area.get_parent()
		
		if is_attacking:
			roll_cancel_available = true
		
		var damage = charge_damage if is_attacking and not is_comboing else 25
		var knockback_value = charge_knockback if is_attacking and not is_comboing else knockback_force
		var hit_type = "normal"

		if is_helm_breaker:
			damage = int(damage * 1.5)
			knockback_value = knockback_value * 1.5
			hit_type = "helm_breaker"
		
		var raw_direction = (enemy.global_position - global_position).normalized()
		
		var knockback_direction = Vector2.ZERO
		if abs(raw_direction.x) > abs(raw_direction.y):
			knockback_direction = Vector2.RIGHT if raw_direction.x > 0 else Vector2.LEFT
		else:
			knockback_direction = Vector2.DOWN if raw_direction.y > 0 else Vector2.UP
		
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, knockback_direction, combo_stage, is_comboing, knockback_value, hit_type)
			

# func for enemy taking damage	
func take_damage(damage: int, knockback_direction: Vector2):
	if invincible:
		return
	if health > 0:
		AudioDamagePlayer.play()
	health -= damage
	
	player_hit.emit(damage, knockback_direction)
	
	is_rolling = false
	is_attacking = false
	is_charging_heavy = false
	is_helm_breaker = false
	roll_cancel_available = false
	
	is_in_knockback = true
	velocity = knockback_direction * knockback_force
	if health <= 0:
		die()
	invincible = true
	await get_tree().create_timer(invincible_duration).timeout
	invincible = false
	is_in_knockback = false
	
	

# start charging heavy
func start_heavy_attack():
	is_attacking = true
	current_state = State.ATTACKING
	roll_cancel_available = false
	play_animation("Heavy")

# reset combo state
func reset_combo():
	is_comboing = false
	waiting_for_combo_input = false
	combo_stage = 0
	roll_cancel_available = false
	current_anim_name = ""
	
	if combo_timer:
		combo_timer.timeout.disconnect(_on_combo_timeout)
		combo_timer = null

func start_attack(anim_name: String):
	is_attacking = true
	current_anim_name = anim_name
	
	var slide_dir = 1 if anim_holder.scale.x > 0 else -1
	velocity.x = slide_dir * 150
	
	current_state = State.ATTACKING
	roll_cancel_available = false
	
	# enable hitbox
	$animation_holder/WeaponHitbox/CollisionShape2D.disabled = false
	
	play_animation(anim_name)

func start_combo_timer():
	if combo_timer:
		combo_timer.timeout.disconnect(_on_combo_timeout)
	
	combo_timer = get_tree().create_timer(0.5)
	combo_timer.timeout.connect(_on_combo_timeout)

func _on_combo_timeout():
	if waiting_for_combo_input and is_comboing:
		reset_combo()

func apply_z_physics(delta: float, gravity_scale: float = 1.0):
	z_velocity += GRAVITY * gravity_scale * delta
	z_height += z_velocity * delta
	
	if z_height <= 0:
		z_height = 0
		z_velocity = 0
		is_jumping = false
		if current_state == State.JUMPING:
			current_state = State.IDLE

func update_visuals(delta: float):
	player_anim.position.y = -z_height 
	
	var shadow_scale = clamp(1.0 - (z_height * 0.005), 0.4, 1.0)
	shadow.scale = Vector2.ONE * shadow_scale

func play_animation(anim_name: String):
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
	else:
		player_anim.play(anim_name)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	_handle_animation_finished(str(anim_name))

func _on_animated_sprite_finished():
	_handle_animation_finished(player_anim.animation)

func _handle_animation_finished(anim_name: String):
	print("ANIMATION FINISHED: ", anim_name)
	
	if anim_name == "death":
		player_died.emit()
		queue_free()
		get_tree().change_scene_to_file("res://scenes/game_over.tscn")
	if anim_name != current_anim_name and is_attacking and not is_helm_breaker:
		print("  (Ignoring stale animation: ", anim_name, " vs current: ", current_anim_name, ")")
		return
	if anim_name == "roll":
		return
	if is_helm_breaker:
		if anim_name == "helm_breaker_start" and helm_breaker_phase == 0:
			print("HELM BREAKER START FINISHED - Transitioning to fall")
			helm_breaker_phase = 1
			current_anim_name = "helm_breaker_fall"
			play_animation("helm_breaker_fall")
		elif anim_name == "helm_breaker_fall":
			# fall animation loops until landing
			pass
		return
	
	# check if on ground
	var is_ground_anim = anim_name in LightComboState
	
	if is_attacking:
		is_attacking = false
		current_anim_name = ""
		
		$animation_holder/WeaponHitbox/CollisionShape2D.disabled = true
		
		# handle continuing combo
		if is_comboing:
			if is_ground_anim and combo_stage < 2:
				waiting_for_combo_input = true
				start_combo_timer()
			elif is_comboing and combo_stage >= 2:
				reset_combo()
			else:
				reset_combo()
		if is_jumping:
			current_state = State.JUMPING
		else:
			current_state = State.IDLE

func die():
	AudioPlayer.play()
	var high_score = ProgressManager.enemies_killed
	ProgressManager.save(high_score)
	if is_dead:
		return
	is_dead = true
	
	# disable everything
	is_attacking = false
	is_rolling = false
	is_charging_heavy = false
	is_helm_breaker = false
	is_jumping = false
	current_state = State.IDLE
	velocity = Vector2.ZERO
	z_velocity = 0
	invincible = true
	$animation_holder/WeaponHitbox/CollisionShape2D.disabled = true
	
	# play death animation
	current_anim_name = "death"
	if anim_player.has_animation("death"):
		anim_player.play("death")
		print("Playing death animation")
	else:
		player_anim.play("death")
		print("Playing death on AnimatedSprite2D")

func start_charging_heavy():
	anim_player.play("charging_heavy")
	is_charging_heavy = true
	is_attacking = false
	heavy_charge_time = 0.0
	current_state = State.ATTACKING
	charge_flash_timer = 0.0
	roll_cancel_available = false

func perform_charged_heavy_attack():
	is_charging_heavy = false
	is_attacking = true
	
	var charge_percent = heavy_charge_time / max_charge_time
	
	var final_damage = int(lerp(min_damage, max_damage, charge_percent))
	var final_knockback = lerp(min_knockback, max_knockback, charge_percent)
	
	charge_damage = final_damage
	charge_knockback = final_knockback
	
	
	var slide_dir = 1 if anim_holder.scale.x > 0 else -1
	velocity.x = slide_dir * 150
	
	$animation_holder/WeaponHitbox/CollisionShape2D.disabled = false
	
	current_anim_name = "Heavy"
	if anim_player.has_animation("Heavy"):
		anim_player.play("Heavy")
		anim_player.seek(0, true)
		anim_player.play()
	
	heavy_charge_time = 0.0

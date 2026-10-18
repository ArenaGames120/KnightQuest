extends CharacterBody2D
class_name Knight
## Рыцарь — управляемый персонаж.

signal died

const SPEED := 108.0
const ACCEL := 1000.0
const FRICTION := 1300.0
const AIR_ACCEL := 720.0
const GRAVITY := 900.0
const MAX_FALL := 430.0
const JUMP_VELOCITY := -350.0
const JUMP_CUT := 0.42
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
const ATTACK_TIME := 0.22
const ATTACK_CD := 0.32
const PUSH_SPEED := 62.0
const INVULN_TIME := 1.3

const LAYER_WORLD := 1
const LAYER_ENEMY := 4
const LAYER_PICKUP := 16
const LAYER_CRATE := 32

var facing := 1
var dead := false
var invuln := 0.0
var attack_timer := 0.0
var attack_cd := 0.0
var coyote := 0.0
var buffer := 0.0
var control_enabled := true

var sprite: AnimatedSprite2D
var camera: Camera2D
var pickup_area: Area2D
var _death_sprite: Node2D
var _blink := 0.0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = LAYER_WORLD | LAYER_CRATE
	floor_snap_length = 4.0
	up_direction = Vector2.UP

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 18)
	col.shape = rect
	col.position = Vector2(0, -9)
	add_child(col)

	sprite = Art.actor("knight", 16, 20, {
		"idle": {"frames": [0, 4], "fps": 3.0},
		"run": {"frames": [1, 2, 3, 2], "fps": 11.0},
		"jump": {"frames": [5], "fps": 1.0, "loop": false},
		"fall": {"frames": [6], "fps": 1.0, "loop": false},
	})
	add_child(sprite)

	pickup_area = Area2D.new()
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = LAYER_PICKUP
	pickup_area.monitoring = true
	var pcol := CollisionShape2D.new()
	var prect := RectangleShape2D.new()
	prect.size = Vector2(22, 26)
	pcol.shape = prect
	pcol.position = Vector2(0, -13)
	pickup_area.add_child(pcol)
	add_child(pickup_area)
	pickup_area.area_entered.connect(_on_pickup_area)

	camera = Camera2D.new()
	camera.position = Vector2(0, -34)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)

func _physics_process(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	invuln = maxf(0.0, invuln - delta)

	if invuln > 0.0 and not dead:
		_blink += delta * 14.0
		sprite.modulate = Color(1, 1, 1, 1) if fmod(_blink, 1.0) < 0.5 else Color(1, 0.5, 0.5, 0.45)
	else:
		sprite.modulate = Color(1, 1, 1, 1)

	if dead:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		velocity.x = move_toward(velocity.x, 0, 240.0 * delta)
		move_and_slide()
		return

	coyote = maxf(0.0, coyote - delta)
	buffer = maxf(0.0, buffer - delta)

	var dir := 0.0
	if control_enabled:
		dir = Input.get_axis("move_left", "move_right")
		if Input.is_action_just_pressed("jump"):
			buffer = JUMP_BUFFER
		if Input.is_action_just_pressed("attack") and attack_cd <= 0.0:
			_attack()

	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
		sprite.flip_h = facing < 0

	# горизонталь
	var target := dir * SPEED
	var a := ACCEL if is_on_floor() else AIR_ACCEL
	if dir == 0.0 and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	else:
		velocity.x = move_toward(velocity.x, target, a * delta)

	# вертикаль
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	else:
		coyote = COYOTE_TIME
		if velocity.y > 0.0:
			velocity.y = 0.0

	if buffer > 0.0 and coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		buffer = 0.0
		coyote = 0.0
		Game.play_sfx("jump", randf_range(0.95, 1.05))

	if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= 1.0 - JUMP_CUT * delta * 12.0

	move_and_slide()
	_handle_collisions()
	_update_anim()

func _handle_collisions() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if other == null:
			continue
		# толкаем ящик
		if other.has_method("push"):
			var n := c.get_normal()
			if absf(n.x) > 0.5:
				other.push(-n.x, PUSH_SPEED)
		# прыжок на голову врага
		elif other.has_method("take_damage") and other.has_method("is_stompable"):
			if c.get_normal().y < -0.5 and velocity.y > 30.0 and other.is_stompable():
				other.take_damage(99, 0)
				velocity.y = -250.0
				Game.play_sfx("stomp")

func _update_anim() -> void:
	if dead:
		return
	var anim := "idle"
	if attack_timer > 0.0:
		anim = "idle"
	elif not is_on_floor():
		anim = "jump" if velocity.y < -10.0 else "fall"
	elif absf(velocity.x) > 12.0:
		anim = "run"
	if sprite.animation != anim:
		sprite.play(anim)

func _attack() -> void:
	attack_cd = ATTACK_CD
	attack_timer = ATTACK_TIME
	Game.play_sfx("slash", randf_range(0.96, 1.08), 0.8)
	var level := get_parent()
	Art.play_effect(level, "slash", 24, 24, global_position + Vector2(facing * 11, -11), 26.0, facing < 0)
	var space := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, 24)
	params.shape = shape
	params.transform = Transform2D(0.0, global_position + Vector2(facing * 15, -11))
	params.collision_mask = LAYER_ENEMY | LAYER_PICKUP
	params.collide_with_bodies = true
	params.collide_with_areas = true
	for hit in space.intersect_shape(params, 12):
		var obj = hit.get("collider")
		if obj == null or obj == self:
			continue
		if obj.has_method("take_damage"):
			obj.take_damage(1, facing)
		elif obj.has_method("sword_hit"):
			obj.sword_hit(facing)

func _on_pickup_area(area: Area2D) -> void:
	if area.has_method("collect") and not dead:
		area.collect(self)

# ---------------------------------------------------------------- урон и смерть
func hit(damage := 1, from_position := Vector2.ZERO) -> void:
	if dead or invuln > 0.0 or not control_enabled:
		return
	if Game.damage(damage):
		kill()
		return
	invuln = INVULN_TIME
	Game.play_sfx("hurt", randf_range(0.95, 1.08))
	var away := signf(global_position.x - from_position.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 130.0, -170.0)

func kill() -> void:
	if dead:
		return
	Game.set_hp(0)
	dead = true
	Game.play_sfx("death")
	sprite.visible = false
	collision_layer = 0
	collision_mask = LAYER_WORLD
	velocity = Vector2(-facing * 60.0, -220.0)
	var d := Art.sprite("knight_dead", true)
	d.position = Vector2(0, -10)
	add_child(d)
	_death_sprite = d
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(d, "rotation", PI * 0.5 * -facing, 0.5)
	tw.tween_property(d, "position:y", -2.0, 0.5)
	died.emit()

func set_control(on: bool) -> void:
	control_enabled = on
	if not on:
		velocity.x = 0.0

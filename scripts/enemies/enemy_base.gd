extends CharacterBody2D
class_name EnemyBase
## Базовый класс врагов: здоровье, урон при касании, смерть, гравитация.

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_CRATE := 32
const MAX_FALL := 420.0

# настройки (переопределяются в наследниках)
var max_hp := 2
var contact_damage := 1
var stompable := true
var has_gravity := true
var gravity := 900.0
var drop_chance := 0.55

var hp := 2
var dead := false
var hurt_timer := 0.0
var facing := -1
var custom_death_anim := false
var player: Knight
var level: Node2D
var sprite: AnimatedSprite2D
var touch_area: Area2D

func _ready() -> void:
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD | LAYER_CRATE
	hp = max_hp
	level = _find_level()
	_build_body()
	_build_sprite()
	_build_touch_area()
	_after_ready()

## Уровень всегда лежит выше по дереву (враги добавляются в узел Entities).
func _find_level() -> Node2D:
	var p: Node = get_parent()
	while p != null:
		if p is Level:
			return p as Level
		p = p.get_parent()
	return null

# --- переопределяемые хуки ---
func _build_body() -> void:
	add_collision(Vector2(10, 18), Vector2(0, -9))

func _build_sprite() -> void:
	pass

func _after_ready() -> void:
	pass

func _ai(_delta: float) -> void:
	pass

func sprite_size() -> Vector2:
	return Vector2(16, 20)

# --- сборка ---
func add_collision(size: Vector2, offset: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = offset
	add_child(cs)

func _build_touch_area() -> void:
	touch_area = Area2D.new()
	touch_area.collision_layer = 0
	touch_area.collision_mask = LAYER_PLAYER
	touch_area.monitoring = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var s := sprite_size()
	rect.size = s + Vector2(2, 2)
	cs.shape = rect
	cs.position = Vector2(0, -s.y * 0.5)
	touch_area.add_child(cs)
	add_child(touch_area)
	touch_area.body_entered.connect(_on_touch)

func _on_touch(body: Node) -> void:
	if dead or body == null:
		return
	if body.has_method("hit"):
		body.hit(contact_damage, global_position)

func is_stompable() -> bool:
	return stompable and not dead

func _physics_process(delta: float) -> void:
	if dead:
		return
	hurt_timer = maxf(0.0, hurt_timer - delta)
	if sprite != null:
		sprite.modulate = Color(1.9, 0.55, 0.55) if hurt_timer > 0.0 else Color(1, 1, 1, 1)

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Knight

	if has_gravity and not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, MAX_FALL)

	_ai(delta)
	move_and_slide()
	if sprite != null:
		sprite.flip_h = facing > 0

func take_damage(amount: int, from_dir := 0) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0:
		die(from_dir)
		return
	hurt_timer = 0.18
	Game.play_sfx("enemy_hit", randf_range(0.95, 1.1))
	if from_dir != 0:
		velocity.x = from_dir * 90.0
		velocity.y = minf(velocity.y, -90.0)
	_on_damaged()

func _on_damaged() -> void:
	pass

func die(from_dir := 0) -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	if touch_area != null:
		touch_area.set_deferred("monitoring", false)
	velocity = Vector2(from_dir * 40.0, -120.0)
	Game.play_sfx("enemy_hit", 1.25)
	if level != null and randf() < drop_chance and level.has_method("spawn_coin"):
		level.spawn_coin(position + Vector2(0, -6))
	Art.play_effect(self, "spark", 9, 9, Vector2(0, -8), 14.0, false, 1.6)
	if custom_death_anim:
		_on_death()
		return
	if sprite != null:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(sprite, "scale", Vector2(1.5, 0.35), 0.22)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.24)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()
	_on_death()

func _on_death() -> void:
	pass

## Проверка «впереди пропасть?» — луч вниз перед собой.
func edge_ahead() -> bool:
	var space := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(facing * 8.0, -4.0),
		global_position + Vector2(facing * 10.0, 12.0))
	params.collision_mask = LAYER_WORLD | LAYER_CRATE
	params.exclude = [get_rid()]
	return space.intersect_ray(params).is_empty()

## Проверка «впереди стена?»
func wall_ahead() -> bool:
	var space := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(facing * 6.0, -10.0),
		global_position + Vector2(facing * 13.0, -10.0))
	params.collision_mask = LAYER_WORLD | LAYER_CRATE
	params.exclude = [get_rid()]
	return not space.intersect_ray(params).is_empty()

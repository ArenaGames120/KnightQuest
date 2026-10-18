extends EnemyBase
class_name Boss
## Босс — Чёрный рыцарь. Таран, прыжок с сотрясением и призыв слуг.

signal defeated

enum State {IDLE, WALK, TELEGRAPH, CHARGE, JUMP, RECOVER}

const SPEED_WALK := 48.0
const SPEED_CHARGE := 178.0
const CHARGE_MAX := 1.0

var state: State = State.IDLE
var state_timer := 0.6
var invuln_timer := 0.0
var summoned := 0
var _started := false

func _build_body() -> void:
	add_collision(Vector2(16, 22), Vector2(0, -11))

func sprite_size() -> Vector2:
	return Vector2(18, 22)

func _build_sprite() -> void:
	max_hp = 8
	stompable = false
	drop_chance = 0.0
	contact_damage = 1
	sprite = Art.actor("boss", 20, 22, {
		"idle": {"frames": [0], "fps": 1.0},
		"walk": {"frames": [1, 2], "fps": 6.0},
		"slam": {"frames": [3], "fps": 1.0, "loop": false},
	}, "idle")
	add_child(sprite)

func _after_ready() -> void:
	if level != null and level.has_method("register_boss"):
		level.register_boss(self)
	custom_death_anim = true

func take_damage(amount: int, from_dir := 0) -> void:
	if invuln_timer > 0.0 or dead:
		return
	invuln_timer = 0.28
	super.take_damage(amount, from_dir)
	Game.play_sfx("boss_hit", randf_range(0.95, 1.05))

func _on_damaged() -> void:
	# смена фазы: призывает подмогу
	if hp <= max_hp / 2 and summoned == 0:
		summoned = 1
		invuln_timer = 1.0
		_summon(_summon_count())

## Сколько слуг призвать в фазе (у Короля-лича их больше).
func _summon_count() -> int:
	return 2

## Дополнительное поведение босса (переопределяют наследники, чтобы не копировать _ai).
func _extra_ai(_delta: float) -> void:
	pass

func _summon(count: int) -> void:
	if level == null:
		return
	for i in count:
		var kind := "slime" if i % 2 == 0 else "skeleton"
		level.spawn_enemy(kind, global_position + Vector2(-30.0 + i * 60.0, -6.0))
	Game.play_sfx("door", 1.4, 0.6)

func _on_death() -> void:
	defeated.emit()
	Game.play_sfx("death", 0.8)
	if level != null:
		level.shake(0.7, 6.0)
		for i in 10:
			level.spawn_coin(global_position + Vector2(randf_range(-24, 24), randf_range(-26, -4)))
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "modulate", Color(1, 0.4, 0.3, 0.0), 1.4)
	tw.tween_property(sprite, "scale", Vector2(1.3, 1.3), 1.4)
	tw.chain().tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	invuln_timer = maxf(0.0, invuln_timer - delta)
	if not _started and player != null and absf(player.global_position.x - global_position.x) < 200.0:
		_started = true
	super._physics_process(delta)

func _ai(delta: float) -> void:
	if not _started:
		velocity.x = 0.0
		return
	var dx := 0.0
	if player != null and not player.dead:
		dx = player.global_position.x - global_position.x
	state_timer -= delta
	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			sprite.play("idle")
			if state_timer <= 0.0:
				if absf(dx) > 76.0:
					_enter(State.WALK, randf_range(0.7, 1.2))
					facing = 1 if dx > 0.0 else -1
				elif randf() < 0.45:
					_enter(State.JUMP, 0.2)
				else:
					_enter(State.TELEGRAPH, 0.45)
		State.WALK:
			facing = 1 if dx > 0.0 else -1
			velocity.x = move_toward(velocity.x, facing * SPEED_WALK, 400.0 * delta)
			sprite.play("walk")
			if state_timer <= 0.0 or wall_ahead():
				_enter(State.IDLE, randf_range(0.25, 0.5))
		State.TELEGRAPH:
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			facing = 1 if dx > 0.0 else -1
			sprite.modulate = Color(2.0, 0.7, 0.7, 1.0) if fmod(state_timer * 12.0, 1.0) < 0.5 else Color(1, 1, 1, 1)
			if state_timer <= 0.0:
				_enter(State.CHARGE, CHARGE_MAX)
				Game.play_sfx("slash", 0.6, 0.7)
		State.CHARGE:
			velocity.x = facing * SPEED_CHARGE
			sprite.play("walk")
			if state_timer <= 0.0 or wall_ahead():
				if wall_ahead():
					level.shake(0.3, 4.0)
				_enter(State.IDLE, randf_range(0.3, 0.6))
		State.JUMP:
			sprite.play("slam")
			if is_on_floor() and state_timer <= 0.0:
				velocity.y = -330.0
				velocity.x = clampf(dx * 1.4, -110.0, 110.0)
				_enter(State.RECOVER, 1.6)
		State.RECOVER:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
				if state_timer < 1.2:
					_land_slam()
					_enter(State.IDLE, 0.5)
			if state_timer <= 0.0:
				_enter(State.IDLE, 0.4)
	_extra_ai(delta)
	if invuln_timer > 0.0:
		sprite.modulate = Color(1.6, 1.6, 1.9, 1.0)

func _land_slam() -> void:
	level.shake(0.4, 5.0)
	Game.play_sfx("stomp", 0.7)
	for i in 6:
		var dir := -1.0 if i % 2 == 0 else 1.0
		var rock := Rock.new()
		rock.setup(global_position + Vector2(dir * 8.0, -8.0),
			Vector2(dir * randf_range(60.0, 130.0), randf_range(-190.0, -110.0)), 420.0)
		level.add_child.call_deferred(rock)

func _enter(s: State, t: float) -> void:
	state = s
	state_timer = t

extends EnemyBase
class_name Gargoyle
## Каменная гаргулья: стоит на месте и швыряет камни в рыцаря.

const SHOOT_RANGE := 215.0
const SHOOT_CD := 1.9

var shoot_timer := 0.7
var anim_timer := 0.0

func _build_body() -> void:
	add_collision(Vector2(14, 18), Vector2(0, -9))

func _build_sprite() -> void:
	max_hp = 3
	stompable = false
	drop_chance = 0.8
	sprite = Art.actor("gargoyle", 16, 20, {
		"idle": {"frames": [0], "fps": 1.0},
		"shoot": {"frames": [1, 2], "fps": 9.0},
	})
	add_child(sprite)

func _ai(delta: float) -> void:
	velocity.x = 0.0
	shoot_timer -= delta
	if anim_timer > 0.0:
		anim_timer -= delta
		if anim_timer <= 0.0:
			sprite.play("idle")
	if player == null or player.dead:
		return
	var d := player.global_position - global_position
	facing = 1 if d.x > 0.0 else -1
	if shoot_timer <= 0.0 and d.length() < SHOOT_RANGE and absf(d.y) < 150.0:
		shoot_timer = SHOOT_CD + randf() * 0.6
		anim_timer = 0.35
		sprite.play("shoot")
		_shoot()

func _shoot() -> void:
	var rock := Rock.new()
	var from := global_position + Vector2(facing * 6.0, -13.0)
	var dir := (player.global_position + Vector2(0, -8) - from).normalized()
	rock.setup(from, dir * 130.0)
	Game.play_sfx("slash", 0.7, 0.5)
	if level != null:
		level.add_child.call_deferred(rock)

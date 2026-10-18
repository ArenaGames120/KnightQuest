extends EnemyBase
class_name Bat
## Летучая мышь: летает по синусоиде, подлетает к рыцарю, если он рядом.

const SPEED := 46.0
const SIGHT := 130.0

var home := Vector2.ZERO
var time := 0.0

func _build_body() -> void:
	has_gravity = false
	add_collision(Vector2(12, 6), Vector2(0, -4))

func sprite_size() -> Vector2:
	return Vector2(14, 8)

func _build_sprite() -> void:
	max_hp = 1
	drop_chance = 0.4
	sprite = Art.actor("bat", 16, 8, {
		"fly": {"frames": [0, 1, 2, 3], "fps": 11.0},
	}, "fly")
	add_child(sprite)

func _after_ready() -> void:
	home = global_position
	time = randf() * TAU

func _ai(delta: float) -> void:
	time += delta
	var target := home + Vector2(sin(time * 1.6) * 22.0, sin(time * 2.7) * 12.0)
	if player != null and not player.dead:
		var d := player.global_position - global_position
		if d.length() < SIGHT:
			target = player.global_position + Vector2(0, -14)
			facing = 1 if d.x > 0.0 else -1
	var to := target - global_position
	if to.length() > 1.0:
		velocity = to.normalized() * SPEED
	else:
		velocity = Vector2.ZERO

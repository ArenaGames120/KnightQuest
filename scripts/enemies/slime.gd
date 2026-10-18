extends EnemyBase
class_name Slime
## Слизень: прыгает к рыцарю. Погибает от одного удара (и от прыжка на голову).

var timer := 0.0
var jumping := false

func _build_body() -> void:
	add_collision(Vector2(12, 10), Vector2(0, -5))

func sprite_size() -> Vector2:
	return Vector2(14, 10)

func _build_sprite() -> void:
	max_hp = 1
	drop_chance = 0.35
	sprite = Art.actor("slime", 16, 10, {
		"idle": {"frames": [0, 1], "fps": 3.0},
		"jump": {"frames": [2], "fps": 1.0, "loop": false},
		"land": {"frames": [3], "fps": 1.0, "loop": false},
	})
	add_child(sprite)
	timer = randf_range(0.2, 0.8)

func _ai(delta: float) -> void:
	if is_on_floor():
		if jumping:
			jumping = false
			timer = randf_range(0.5, 0.9)
			timer *= 0.5 if player != null and absf(player.global_position.x - global_position.x) < 120.0 else 1.0
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		timer -= delta
		if timer <= 0.0:
			jumping = true
			var dir := 1.0 if facing > 0 else -1.0
			if player != null and not player.dead:
				var d := player.global_position - global_position
				if absf(d.x) < 140.0:
					dir = signf(d.x) if absf(d.x) > 6.0 else dir
					facing = 1 if dir > 0.0 else -1
				else:
					facing = -facing
					dir = 1.0 if facing > 0 else -1.0
			velocity = Vector2(dir * 52.0, -190.0)
			Game.play_sfx("jump", randf_range(1.35, 1.5), 0.35)
	sprite.play("jump" if not is_on_floor() else ("land" if jumping else "idle"))

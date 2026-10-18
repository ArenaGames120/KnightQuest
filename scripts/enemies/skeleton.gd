extends EnemyBase
class_name Skeleton
## Скелет-стражник: патрулирует площадку, замечает рыцаря и бросается в погоню.

const SPEED_PATROL := 34.0
const SPEED_CHASE := 72.0
const SIGHT_X := 96.0
const SIGHT_Y := 40.0

func _build_sprite() -> void:
	max_hp = 2
	sprite = Art.actor("skeleton", 16, 20, {
		"walk": {"frames": [0, 1, 2, 3], "fps": 6.0},
	})
	add_child(sprite)

func _ai(delta: float) -> void:
	var chasing := false
	if player != null and not player.dead:
		var d := player.global_position - global_position
		if absf(d.x) < SIGHT_X and absf(d.y) < SIGHT_Y:
			chasing = true
			facing = 1 if d.x > 0.0 else -1

	if is_on_floor():
		var speed := SPEED_CHASE if chasing else SPEED_PATROL
		if not chasing and (edge_ahead() or wall_ahead()):
			facing = -facing
			velocity.x = 0.0
		elif wall_ahead():
			velocity.x = 0.0
		else:
			velocity.x = move_toward(velocity.x, facing * speed, 260.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, facing * 20.0, 120.0 * delta)

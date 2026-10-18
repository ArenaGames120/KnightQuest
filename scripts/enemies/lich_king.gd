extends Boss
class_name LichKing
## Финальный босс — Король-лич: держит дистанцию, швыряет камни веером и зовёт слуг.
## Наследует поведение Чёрного рыцаря (таран, прыжок с сотрясением) и добавляет стрельбу.

const CAST_CD := 2.8

var _cast_cd := 2.2

func _build_sprite() -> void:
	max_hp = 14
	stompable = false
	drop_chance = 0.0
	contact_damage = 1
	sprite = Art.actor("boss_lich", 20, 22, {
		"idle": {"frames": [0], "fps": 1.0},
		"walk": {"frames": [1, 2], "fps": 6.0},
		"slam": {"frames": [3], "fps": 1.0, "loop": false},
	}, "idle")
	add_child(sprite)

## У лича подмоги больше, чем у рыцаря.
func _summon_count() -> int:
	return 3

## Две фазы: на половине здоровья и на четверти.
func _on_damaged() -> void:
	if hp <= max_hp / 4 and summoned < 2:
		summoned = 2
		invuln_timer = 1.2
		_summon(_summon_count())
	elif hp <= max_hp / 2 and summoned < 1:
		summoned = 1
		invuln_timer = 1.0
		_summon(_summon_count())

func _extra_ai(delta: float) -> void:
	# в рывке и прыжке не колдует
	if state == State.CHARGE or state == State.TELEGRAPH or state == State.JUMP:
		return
	_cast_cd -= delta
	if _cast_cd > 0.0:
		return
	_cast_cd = CAST_CD
	_volley()

## Залп из трёх камней веером в сторону рыцаря.
func _volley() -> void:
	if level == null or player == null or not is_instance_valid(player) or player.dead:
		return
	facing = 1 if player.global_position.x > global_position.x else -1
	var target := player.global_position + Vector2(0, -10)
	var to_player := (target - global_position).normalized()
	Game.play_sfx("boss_hit", 0.55, 0.7)
	for i in 3:
		var spread := float(i - 1) * 0.20
		var v := to_player.rotated(spread) * randf_range(120.0, 150.0)
		v.y -= 40.0
		var rock := Rock.new()
		rock.setup(global_position + Vector2(0, -16), v, 380.0)
		level.add_child.call_deferred(rock)

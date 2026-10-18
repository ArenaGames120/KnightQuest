extends Area2D
class_name Coin
## Монета. Собирается «зоной подбора» рыцаря.

const LAYER_PICKUP := 16

var collected := false
var sprite: AnimatedSprite2D

func _ready() -> void:
	collision_layer = LAYER_PICKUP
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	cs.shape = circle
	add_child(cs)
	sprite = Art.actor("coin", 8, 8, {"spin": {"frames": [0, 1, 2, 3, 4, 5], "fps": 9.0}}, "spin")
	sprite.offset = Vector2(-4, -4)
	add_child(sprite)
	var base_y := position.y
	var tw := create_tween().set_loops()
	tw.tween_property(self, "position:y", base_y - 2.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", base_y, 0.55).set_trans(Tween.TRANS_SINE)

func collect(_who: Node) -> void:
	if collected:
		return
	collected = true
	Game.add_coin(1)
	Game.play_sfx("coin", randf_range(0.97, 1.07))
	Art.play_effect(get_parent(), "spark", 9, 9, global_position + Vector2(0, -4), 18.0, false, 1.3)
	queue_free()

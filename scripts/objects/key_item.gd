extends Area2D
class_name KeyItem
## Ключ: открывает ворота с замком.

const LAYER_PICKUP := 16

var collected := false
var sprite: AnimatedSprite2D

func _ready() -> void:
	collision_layer = LAYER_PICKUP
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 14)
	cs.shape = rect
	cs.position = Vector2(0, -5)
	add_child(cs)
	sprite = Art.actor("key", 10, 12, {"idle": {"frames": [0, 1], "fps": 3.0}})
	sprite.offset = Vector2(-5, -6)
	add_child(sprite)
	var base_y := position.y
	var tw := create_tween().set_loops()
	tw.tween_property(self, "position:y", base_y - 3.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", base_y, 0.7).set_trans(Tween.TRANS_SINE)

func collect(_who: Node) -> void:
	if collected:
		return
	collected = true
	Game.add_key(1)
	Game.play_sfx("key")
	Art.play_effect(get_parent(), "spark", 9, 9, global_position + Vector2(0, -6), 16.0, false, 1.4)
	queue_free()

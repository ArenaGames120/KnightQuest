extends Area2D
class_name HeartItem
## Сердце: восстанавливает здоровье.

const LAYER_PICKUP := 16

var collected := false

func _ready() -> void:
	collision_layer = LAYER_PICKUP
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 12)
	cs.shape = rect
	cs.position = Vector2(0, -5)
	add_child(cs)
	var spr := Art.sprite("heart")
	spr.offset = Vector2(-5, -4)
	add_child(spr)
	var base_y := position.y
	var tw := create_tween().set_loops()
	tw.tween_property(self, "position:y", base_y - 3.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", base_y, 0.6).set_trans(Tween.TRANS_SINE)

func collect(_who: Node) -> void:
	if collected:
		return
	collected = true
	Game.heal(1)
	Art.play_effect(get_parent(), "spark", 9, 9, global_position + Vector2(0, -6), 16.0, false, 1.4)
	queue_free()

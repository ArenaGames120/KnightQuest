extends Area2D
class_name Princess
## Принцесса — цель последнего уровня.

signal rescued

const LAYER_PLAYER := 2

var sprite: AnimatedSprite2D
var _done := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_PLAYER
	monitoring = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 20)
	cs.shape = rect
	cs.position = Vector2(0, -10)
	add_child(cs)
	sprite = Art.actor("princess", 16, 20, {
		"idle": {"frames": [0, 1], "fps": 2.0},
		"saved": {"frames": [2], "fps": 1.0, "loop": false},
	})
	add_child(sprite)
	body_entered.connect(_on_body)

func _on_body(body: Node) -> void:
	if _done or not (body is Knight):
		return
	_done = true
	sprite.play("saved")
	Game.play_sfx("win", 1.0, 0.9)
	for i in 6:
		var tw := create_tween()
		tw.tween_interval(i * 0.09)
		tw.tween_callback(func() -> void:
			Art.play_effect(get_parent(), "heart", 10, 8,
				global_position + Vector2(randf_range(-14, 14), -18), 6.0, false, 1.2))
	rescued.emit()

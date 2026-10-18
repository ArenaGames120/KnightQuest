extends Area2D
class_name Checkpoint
## Контрольная флаг-точка: после неё рыцарь возрождается здесь.

signal reached(pos: Vector2)

const LAYER_PLAYER := 2

var activated := false
var sprite: AnimatedSprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_PLAYER
	monitoring = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 30)
	cs.shape = rect
	cs.position = Vector2(0, -15)
	add_child(cs)
	sprite = Art.actor("checkpoint", 16, 32, {
		"off": {"frames": [0], "fps": 1.0},
		"on": {"frames": [1], "fps": 1.0},
	}, "off")
	sprite.offset = Vector2(-8, -32)
	add_child(sprite)
	body_entered.connect(_on_body)

func _on_body(body: Node) -> void:
	if activated or not (body is Knight):
		return
	activated = true
	sprite.play("on")
	Game.play_sfx("checkpoint")
	Art.play_effect(get_parent(), "spark", 9, 9, global_position + Vector2(0, -22), 14.0, false, 1.6)
	reached.emit(global_position)

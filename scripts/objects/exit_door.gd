extends Area2D
class_name ExitDoor
## Дверь в конце уровня.

signal entered

const LAYER_PLAYER := 2

var opened := false
var sprite: AnimatedSprite2D
var _fired := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = LAYER_PLAYER
	monitoring = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 30)
	cs.shape = rect
	cs.position = Vector2(0, -15)
	add_child(cs)
	sprite = Art.actor("exit_door", 24, 32, {
		"closed": {"frames": [0], "fps": 1.0},
		"open": {"frames": [1], "fps": 2.0},
	}, "closed")
	sprite.offset = Vector2(-12, -32)
	add_child(sprite)
	body_entered.connect(_on_body)

func set_opened(v: bool) -> void:
	opened = v
	if sprite != null:
		sprite.play("open" if v else "closed")

func _on_body(body: Node) -> void:
	if _fired or not (body is Knight):
		return
	_fired = true
	Game.play_sfx("win", 1.0, 0.8)
	entered.emit()

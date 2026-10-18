extends Area2D
class_name Lever
## Рычаг: срабатывает один раз (от касания рыцаря или от удара мечом)
## и открывает ворота своего канала.

signal activated(channel: String)

const LAYER_PICKUP := 16
const LAYER_PLAYER := 2

var channel := "a"
var used := false
var sprite: AnimatedSprite2D

func _ready() -> void:
	collision_layer = LAYER_PICKUP
	collision_mask = LAYER_PLAYER
	monitoring = true
	monitorable = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 12)
	cs.shape = rect
	cs.position = Vector2(0, -6)
	add_child(cs)
	sprite = Art.actor("lever", 16, 16, {"off": {"frames": [0], "fps": 1.0}, "on": {"frames": [1], "fps": 1.0}}, "off")
	sprite.offset = Vector2(-8, -16)
	add_child(sprite)
	body_entered.connect(_on_body)

func _on_body(body: Node) -> void:
	if body is Knight:
		activate()

func sword_hit(_dir: int) -> void:
	activate()

func activate() -> void:
	if used:
		return
	used = true
	sprite.play("on")
	Game.play_sfx("lever")
	activated.emit(channel)
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", sprite.position.y - 0.0, 0.1)

extends Area2D
class_name PressurePlate
## Нажимная плита: ворота открыты, пока на плите лежит рыцарь или ящик.

signal state_changed(pressed: bool)

const LAYER_PICKUP := 16
const LAYER_PLAYER := 2
const LAYER_CRATE := 32

var channel := "e"
var pressed := 0
var sprite: AnimatedSprite2D

func _ready() -> void:
	collision_layer = LAYER_PICKUP
	collision_mask = LAYER_PLAYER | LAYER_CRATE
	monitoring = true
	monitorable = true
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(13, 9)
	cs.shape = rect
	cs.position = Vector2(0, -11)
	add_child(cs)
	sprite = Art.actor("plate", 16, 8, {"up": {"frames": [0], "fps": 1.0}, "down": {"frames": [1], "fps": 1.0}}, "up")
	sprite.offset = Vector2(-8, -8)
	add_child(sprite)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(_body: Node) -> void:
	pressed += 1
	sprite.play("down")
	if pressed == 1:
		Game.play_sfx("lever", 1.15)
		state_changed.emit(true)

func _on_exit(_body: Node) -> void:
	pressed = maxi(0, pressed - 1)
	if pressed == 0:
		sprite.play("up")
		Game.play_sfx("lever", 0.85)
		state_changed.emit(false)

extends Area2D
class_name Saw
## Циркулярная пила — вращающаяся ловушка.

const LAYER_HAZARD := 8
const LAYER_PLAYER := 2

var sprite: Sprite2D
var spin_speed := 7.0

func _ready() -> void:
	collision_layer = LAYER_HAZARD
	collision_mask = LAYER_PLAYER
	monitoring = true
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.5
	cs.shape = circle
	add_child(cs)
	sprite = Art.sprite("saw", true)
	add_child(sprite)
	body_entered.connect(_on_body)

func _process(delta: float) -> void:
	if sprite != null:
		sprite.rotation += delta * spin_speed * (1.0 if spin_speed > 0.0 else -1.0)

func _on_body(body: Node) -> void:
	if body.has_method("hit"):
		body.hit(1, global_position)

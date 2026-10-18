extends Area2D
class_name Rock
## Камень, который бросает гаргулья (и разлетающиеся обломки босса).

var velocity := Vector2.ZERO
var grav_accel := 150.0
var life := 5.0
var _sprite: Sprite2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = EnemyBase.LAYER_WORLD | EnemyBase.LAYER_PLAYER
	monitoring = true
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	cs.shape = circle
	add_child(cs)
	_sprite = Art.sprite("rock", true)
	add_child(_sprite)
	body_entered.connect(_on_body)

func setup(pos: Vector2, vel: Vector2, grav := 150.0) -> void:
	global_position = pos
	velocity = vel
	grav_accel = grav

func _physics_process(delta: float) -> void:
	velocity.y += grav_accel * delta
	position += velocity * delta
	if _sprite != null:
		_sprite.rotation += delta * 7.0
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body(body: Node) -> void:
	if body.has_method("hit"):
		body.hit(1, global_position)
		Art.play_effect(get_parent(), "spark", 9, 9, position, 14.0, false, 1.2)
		queue_free()
	elif body is TileMapLayer or body is StaticBody2D:
		Art.play_effect(get_parent(), "spark", 9, 9, position, 16.0, false, 1.0)
		queue_free()

extends CharacterBody2D
class_name Crate
## Ящик: рыцарь может толкать его. Ящик давит на плиты и горит в лаве.

const LAYER_WORLD := 1
const LAYER_CRATE := 32
const LAYER_HAZARD := 8
const GRAVITY := 900.0

var push_vel := 0.0
var square_mode := false
var sprite: Sprite2D
var _touched := false

func setup(stone := false) -> void:
	square_mode = stone

func _ready() -> void:
	collision_layer = LAYER_CRATE
	collision_mask = LAYER_WORLD | LAYER_CRATE
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	cs.shape = rect
	cs.position = Vector2(0, -8)
	add_child(cs)
	sprite = Art.sprite("crate_stone" if square_mode else "crate")
	sprite.offset = Vector2(-8, -16)
	add_child(sprite)

	var det := Area2D.new()
	det.collision_layer = 0
	det.collision_mask = LAYER_HAZARD
	det.monitoring = true
	var dcs := CollisionShape2D.new()
	var drect := RectangleShape2D.new()
	drect.size = Vector2(12, 12)
	dcs.shape = drect
	dcs.position = Vector2(0, -8)
	det.add_child(dcs)
	add_child(det)
	det.area_entered.connect(_on_hazard)

func _on_hazard(_area: Area2D) -> void:
	if _touched:
		return
	_touched = true
	Game.play_sfx("hurt", 0.7, 0.7)
	Art.play_effect(get_parent(), "spark", 9, 9, global_position + Vector2(0, -8), 12.0, false, 1.6)
	queue_free()

func push(dir: float, strength: float) -> void:
	push_vel = dir * strength

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
	else:
		velocity.y = 0.0
	velocity.x = push_vel
	push_vel = move_toward(push_vel, 0.0, 260.0 * delta)
	move_and_slide()

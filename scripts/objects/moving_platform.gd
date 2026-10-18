extends AnimatableBody2D
class_name MovingPlatform
## Движущаяся платформа (таскает рыцаря на себе).

const LAYER_WORLD := 1

var axis := Vector2.RIGHT
var distance := 64.0
var speed := 42.0
var tiles := 3

var _origin := Vector2.ZERO
var _t := 0.0

func _ready() -> void:
	collision_layer = LAYER_WORLD
	collision_mask = 0
	sync_to_physics = true
	_origin = position
	var w := tiles * 16.0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, 8)
	cs.shape = rect
	cs.position = Vector2(0, -4)
	add_child(cs)
	for i in tiles:
		var s := Sprite2D.new()
		s.texture = Art.tile_top_strip(9, 8)
		s.centered = false
		s.offset = Vector2(-w * 0.5 + i * 16.0, -8)
		add_child(s)
	# «цепь» движения: пара декоративных звёздочек
	var tw := create_tween().set_loops()
	tw.tween_property(self, "modulate", Color(0.92, 0.92, 0.96, 1.0), 0.6)
	tw.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.6)

func _physics_process(delta: float) -> void:
	_t += delta * speed
	var cycle := distance * 2.0
	var p := fmod(_t, cycle)
	var off := p if p <= distance else cycle - p
	position = _origin + axis * off

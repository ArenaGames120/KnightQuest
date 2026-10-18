extends Node2D
class_name Decor
## Украшения уровня: факелы, кусты, знамёна, таблички с подсказкой, сундуки.

signal hint_requested(text: String)

const LAYER_PLAYER := 2

var kind := "torch"
var hint_text := ""
var sprite_node: Node2D

func setup(k: String, text := "") -> void:
	kind = k
	hint_text = text

func _ready() -> void:
	match kind:
		"torch":
			var a := Art.actor("torch", 16, 16, {"fire": {"frames": [0, 1, 2], "fps": 7.0}}, "fire")
			a.offset = Vector2(-8, -16)
			add_child(a)
			sprite_node = a
		"bush":
			var s := Art.sprite("bush")
			s.offset = Vector2(-8, -16)
			add_child(s)
		"banner":
			var b := Art.sprite("banner")
			b.offset = Vector2(-8, -16)
			add_child(b)
		"sign":
			var g := Art.sprite("sign")
			g.offset = Vector2(-8, -16)
			add_child(g)
			var area := Area2D.new()
			area.collision_layer = 0
			area.collision_mask = LAYER_PLAYER
			area.monitoring = true
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(18, 16)
			cs.shape = rect
			cs.position = Vector2(0, -10)
			area.add_child(cs)
			add_child(area)
			area.body_entered.connect(_on_sign_touch)
		"chest":
			var c := Art.actor("chest", 16, 16, {
				"closed": {"frames": [0], "fps": 1.0},
				"open": {"frames": [1], "fps": 1.0},
			}, "closed")
			c.offset = Vector2(-8, -16)
			add_child(c)
			sprite_node = c
			var area2 := Area2D.new()
			area2.collision_layer = 0
			area2.collision_mask = LAYER_PLAYER
			area2.monitoring = true
			var cs2 := CollisionShape2D.new()
			var rect2 := RectangleShape2D.new()
			rect2.size = Vector2(18, 16)
			cs2.shape = rect2
			cs2.position = Vector2(0, -10)
			area2.add_child(cs2)
			add_child(area2)
			area2.body_entered.connect(_on_chest_touch)

func _on_sign_touch(body: Node) -> void:
	if body is Knight and hint_text != "":
		hint_requested.emit(hint_text)
		Game.play_sfx("select", 0.9)

func _on_chest_touch(body: Node) -> void:
	if not (body is Knight) or sprite_node == null:
		return
	var anim := sprite_node as AnimatedSprite2D
	if anim.animation == "open":
		return
	anim.play("open")
	Game.play_sfx("coin", 0.85)
	for i in 4:
		var tw := create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_callback(func() -> void:
			if is_instance_valid(self) and get_parent() != null:
				var c := Coin.new()
				c.position = position + Vector2(randf_range(-10, 10), -10)
				get_parent().add_child.call_deferred(c))

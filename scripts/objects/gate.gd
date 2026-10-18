extends StaticBody2D
class_name Gate
## Ворота (решётка). Типы: lever (открываются рычагом), plate (пока нажата плита),
## key (нужен ключ — тратится при открытии).

signal hint_requested(text: String)
signal opened

const LAYER_WORLD := 1
const LAYER_PLAYER := 2

var gate_type := "lever"
var channel := "a"
var is_open := false
var tile_height := 3
var sprite: Sprite2D
var col: CollisionShape2D
var lock_area: Area2D

func setup(kind: String, ch: String, height_tiles := 3) -> void:
	gate_type = kind
	channel = ch
	tile_height = maxi(1, height_tiles)

func _ready() -> void:
	collision_layer = LAYER_WORLD
	collision_mask = 0
	var h := tile_height * 16.0
	col = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, h)
	col.shape = rect
	col.position = Vector2(0, -h * 0.5)
	add_child(col)

	sprite = Art.sprite("gate_locked" if gate_type == "key" else "gate")
	sprite.offset = Vector2(-8, -h)
	sprite.scale.y = h / 48.0
	add_child(sprite)

	if gate_type == "key":
		lock_area = Area2D.new()
		lock_area.collision_layer = 0
		lock_area.collision_mask = LAYER_PLAYER
		lock_area.monitoring = true
		var lcs := CollisionShape2D.new()
		var lrect := RectangleShape2D.new()
		lrect.size = Vector2(20, h + 6)
		lcs.shape = lrect
		lcs.position = Vector2(0, -h * 0.5)
		lock_area.add_child(lcs)
		add_child(lock_area)
		lock_area.body_entered.connect(_on_lock_touch)

func _on_lock_touch(body: Node) -> void:
	if is_open or not (body is Knight):
		return
	if Game.keys > 0:
		Game.use_key()
		open()
	else:
		Game.play_sfx("gate", 0.6)
		hint_requested.emit("Ворота заперты. Нужен ключ!")

func open() -> void:
	if is_open:
		return
	is_open = true
	Game.play_sfx("door", randf_range(0.95, 1.05), 0.8)
	col.set_deferred("disabled", true)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tw.tween_property(sprite, "position:y", sprite.position.y - 12.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func() -> void: sprite.visible = false)
	opened.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	sprite.visible = true
	Game.play_sfx("gate", 0.85)
	col.set_deferred("disabled", false)
	sprite.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 1.0, 0.35)
	tw.tween_property(sprite, "position:y", sprite.position.y + 12.0, 0.35).set_trans(Tween.TRANS_SINE)

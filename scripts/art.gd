class_name Art
## Помощник для работы с нарисованными спрайтами (res://art/*.png).

static var _tex_cache := {}
static var _frames_cache := {}

static func tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load("res://art/%s.png" % name)
	return _tex_cache[name]

## Кадр i из листа (лист — горизонтальная лента кадров fw x fh).
## Если лист уже, чем fw, или не кратен fw — берётся весь лист как один кадр.
static func frame(name: String, fw: int, fh: int, i: int) -> AtlasTexture:
	var key := "%s|%d|%d" % [name, fw, fh]
	if not _frames_cache.has(key):
		var list := []
		var t := tex(name)
		var tw := t.get_width()
		var th := t.get_height()
		var count := maxi(1, int(tw / maxi(1, fw)))
		var cell_w := mini(fw, tw)
		var cell_h := mini(fh, th)
		for k in count:
			var at := AtlasTexture.new()
			at.atlas = t
			at.region = Rect2(k * fw, 0, cell_w, cell_h)
			at.filter_clip = true
			list.append(at)
		_frames_cache[key] = list
	return _frames_cache[key][i % _frames_cache[key].size()]

static func frame_count(name: String, fw: int) -> int:
	var t := tex(name)
	return maxi(1, int(t.get_width() / maxi(1, fw)))

## Тайл из атласа res://art/tiles.png (8 тайлов в ряду).
static func tile(index: int, tile_size := 16) -> AtlasTexture:
	var ts := tex("tiles")
	var at := AtlasTexture.new()
	at.atlas = ts
	at.region = Rect2((index % 8) * tile_size, (index / 8) * tile_size, tile_size, tile_size)
	return at

## Верхняя часть тайла (для платформ).
static func tile_top_strip(index: int, height: int, tile_size := 16) -> AtlasTexture:
	var at := tile(index, tile_size)
	at.region = Rect2(at.region.position, Vector2(tile_size, height))
	return at

## Собирает SpriteFrames. anims = { "idle": {"frames": [0], "fps": 6, "loop": true}, ... }
static func sprite_frames(name: String, fw: int, fh: int, anims: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim_name in anims.keys():
		var spec: Dictionary = anims[anim_name]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, float(spec.get("fps", 8)))
		sf.set_animation_loop(anim_name, bool(spec.get("loop", true)))
		for i in spec.get("frames", [0]):
			sf.add_frame(anim_name, frame(name, fw, fh, int(i)))
	return sf

## AnimatedSprite2D, у которого начало координат — по центру снизу.
static func actor(name: String, fw: int, fh: int, anims: Dictionary, start := "idle") -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sprite_frames(name, fw, fh, anims)
	s.centered = false
	s.offset = Vector2(-fw * 0.5, -fh)
	var names := s.sprite_frames.get_animation_names()
	if names.is_empty():
		return s
	s.animation = start if s.sprite_frames.has_animation(start) else names[0]
	s.play()
	return s

## Одноразовый визуальный эффект из кадров спрайт-листа.
static func play_effect(parent: Node, name: String, fw: int, fh: int, pos: Vector2,
		fps := 20.0, flip := false, scale_mul := 1.0) -> void:
	var spr := Sprite2D.new()
	spr.texture = frame(name, fw, fh, 0)
	spr.centered = true
	spr.position = pos
	spr.flip_h = flip
	spr.scale = Vector2(scale_mul, scale_mul)
	parent.add_child(spr)
	var count := frame_count(name, fw)
	var t := 0.0
	var tw := spr.create_tween()
	tw.tween_method(func(v: float) -> void:
		var idx := mini(int(v * fps), count - 1)
		spr.texture = frame(name, fw, fh, idx)
		, 0.0, float(count) / fps, float(count) / fps)
	tw.tween_callback(spr.queue_free)

## Рисует одну картинку как отдельный спрайт.
static func sprite(name: String, centered := false, anchor_bottom := false) -> Sprite2D:
	var s := Sprite2D.new()
	var t := tex(name)
	s.texture = t
	s.centered = centered
	if anchor_bottom and not centered:
		s.offset = Vector2(-t.get_width() * 0.5, -t.get_height())
	return s

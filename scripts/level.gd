extends Node2D
class_name Level
## Сборка уровня из ASCII-схемы: тайлы, ловушки, враги, головоломки.

signal finished
signal hint(text: String)

const TILE := 16
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_HAZARD := 8
const LAYER_PICKUP := 16
const LAYER_CRATE := 32

const THEME_TILES := {
	"forest": {"ground": 0, "ground_top": 1, "stone": 2, "stone_top": 3, "bg": 13},
	"cave": {"ground": 2, "ground_top": 3, "stone": 6, "stone_top": 7, "bg": 14},
	"dungeon": {"ground": 2, "ground_top": 3, "stone": 4, "stone_top": 5, "bg": 15},
	"castle": {"ground": 4, "ground_top": 5, "stone": 4, "stone_top": 5, "bg": 15},
}

## Наборы дальнего плана для уровней под открытым небом.
const SKY_SETS := {
	"forest": ["bg_clouds", "bg_mountain", "bg_hills"],
	"castle": ["bg_clouds", "bg_castle"],
}

var data: Dictionary = {}
var index := 0
var map: LevelMap
var theme := "forest"
var player: Knight
var boss: Boss
var has_boss := false
var start_point := Vector2.ZERO
var respawn_point := Vector2.ZERO
var channels := {}          # канал -> Array[Gate]
var channel_on := {}        # канал -> bool (рычаги, босс)
var plate_state := {}       # канал -> число нажатых плит
var exit_door: ExitDoor
var princess: Princess

var back_layer: TileMapLayer
var solid_layer: TileMapLayer
var hazard_layer: TileMapLayer
var entities: Node2D

var _hazard_area: Area2D
var _lava_area: Area2D
var _hazard_tick := 0.0
var _shake_time := 0.0
var _shake_power := 0.0
var _finished := false

# ================================================================ сборка
func build(level_data: Dictionary, level_index: int) -> void:
	data = level_data
	index = level_index
	theme = str(data.get("theme", "forest"))
	map = LevelMap.new()
	var rows: Array = data.get("map", [])
	if rows.is_empty():
		rows = LevelMap.rows_from_description(data)
	map.parse(rows)
	start_point = map.cell_feet(map.player_start.x, map.player_start.y)
	respawn_point = start_point

	_build_tiles()
	_build_entities()
	_build_hazards()
	_build_player()
	_setup_channels()

func level_name() -> String:
	return str(data.get("name", "Уровень %d" % (index + 1)))

# ---------------------------------------------------------------- тайлы
func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = Art.tex("tiles")
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in 16:
		src.create_tile(Vector2i(i % 8, i / 8))
	ts.add_source(src, 0)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, LAYER_WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	# твёрдые тайлы (все, кроме шипов, лавы и фоновой кладки)
	for idx in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]:
		var td := src.get_tile_data(Vector2i(idx % 8, idx / 8), 0)
		td.set_collision_polygons_count(0, 1)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	return ts

func _new_layer(z: int, collide: bool) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = _make_tileset()
	l.collision_enabled = collide
	l.z_index = z
	add_child(l)
	return l

func theme_tile(key: String) -> int:
	var t: Dictionary = THEME_TILES.get(theme, THEME_TILES["forest"])
	return int(t.get(key, 0))

func _build_tiles() -> void:
	back_layer = _new_layer(-20, false)
	solid_layer = _new_layer(0, true)
	hazard_layer = _new_layer(1, false)

	if sky_set() != "":
		_build_sky(sky_set())
	else:
		_fill_backdrop()

	for y in map.height:
		for x in map.width:
			var ch := map.char_at(x, y)
			if LevelMap.SOLID.has(ch):
				var idx := _solid_tile_index(ch, x, y)
				solid_layer.set_cell(Vector2i(x, y), 0, Vector2i(idx % 8, idx / 8))
			elif LevelMap.HAZARD.has(ch):
				var hi := 10 if ch == "^" else (11 if ch == "v" else 12)
				hazard_layer.set_cell(Vector2i(x, y), 0, Vector2i(hi % 8, hi / 8))

## "" — закрытый уровень (кладка), иначе имя набора неба из SKY_SETS.
func sky_set() -> String:
	return str(data.get("bg", ""))

## Кладка на весь уровень (плюс запас, чтобы камера не выглядывала в пустоту).
## Затемнена, чтобы пол и стены читались на фоне.
func _fill_backdrop() -> void:
	back_layer.modulate = Color(0.6, 0.6, 0.72)
	var bg := theme_tile("bg")
	var cell := Vector2i(bg % 8, bg / 8)
	for y in range(-6, map.height + 8):
		for x in range(-3, map.width + 3):
			back_layer.set_cell(Vector2i(x, y), 0, cell)

## Небо, облака и силуэты дальнего плана для открытых уровней.
func _build_sky(preset: String) -> void:
	var map_size := map.size_px()
	var horizon := map_size.y - 32.0          # линия земли: нижние два ряда — грунт
	var top := -96.0
	var bottom := horizon + 8.0
	var sky := Sprite2D.new()
	sky.texture = Art.tex("bg_sky")
	sky.centered = false
	sky.position = Vector2(-8, top)
	sky.scale = Vector2((map_size.x + 16.0) / sky.texture.get_width(),
		(bottom - top) / sky.texture.get_height())
	sky.z_index = -60
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sky)

	var z := -56
	for layer_name in SKY_SETS.get(preset, SKY_SETS["forest"]):
		var t: Texture2D = Art.tex(str(layer_name))
		var y := bottom - t.get_height()
		if str(layer_name) == "bg_clouds":
			y = horizon - 235.0
		var x := -60.0
		var i := 0
		while x < map_size.x + 60.0:
			var s := Sprite2D.new()
			s.texture = t
			s.centered = false
			s.position = Vector2(x, y)
			s.z_index = z
			s.flip_h = i % 2 == 1
			add_child(s)
			x += t.get_width() - 12.0
			i += 1
		z += 3

func _solid_tile_index(ch: String, x: int, y: int) -> int:
	var top := not map.is_solid(x, y - 1)
	match ch:
		"#":
			return theme_tile("ground_top") if top else theme_tile("ground")
		"=":
			return theme_tile("stone_top") if top else theme_tile("stone")
		"%":
			return 5 if top else 4
		"M":
			return 7 if top else 6
		"W":
			return 9 if top else 8
	return theme_tile("ground")

# ---------------------------------------------------------------- опасности
func _build_hazards() -> void:
	_hazard_area = Area2D.new()
	_hazard_area.collision_layer = LAYER_HAZARD
	_hazard_area.collision_mask = LAYER_PLAYER
	_hazard_area.monitoring = true
	add_child(_hazard_area)
	_lava_area = Area2D.new()
	_lava_area.collision_layer = 0
	_lava_area.collision_mask = LAYER_PLAYER
	_lava_area.monitoring = true
	add_child(_lava_area)

	for y in map.height:
		for x in map.width:
			var ch := map.char_at(x, y)
			if not LevelMap.HAZARD.has(ch):
				continue
			var cs := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(15, 15)
			cs.shape = rect
			cs.position = map.cell_center(x, y)
			if ch == "~":
				_lava_area.add_child(cs)
			else:
				_hazard_area.add_child(cs)

# ---------------------------------------------------------------- объекты
func _gate_height(x: int, y: int) -> int:
	var h := 1
	while h < 5 and not map.is_solid(x, y - h) and not map.is_hazard(x, y - h):
		h += 1
	return h

func _register_channel(ch: String, gate: Gate) -> void:
	if not channels.has(ch):
		channels[ch] = []
	channels[ch].append(gate)

func _make_entity(ch: String, x: int, y: int) -> Node:
	var feet := map.cell_feet(x, y)
	var center := map.cell_center(x, y)
	match ch:
		"o":
			var c := Coin.new()
			c.position = center
			return c
		"j":
			var hi := HeartItem.new()
			hi.position = center
			return hi
		"k":
			var k := KeyItem.new()
			k.position = feet
			return k
		"C":
			var cr := Crate.new()
			cr.position = feet
			return cr
		"H":
			var chest := Decor.new()
			chest.setup("chest")
			chest.position = feet
			return chest
		"t", "u", "F", "n":
			var d := Decor.new()
			var kind: String = {"t": "torch", "u": "bush", "F": "banner", "n": "sign"}[ch]
			d.setup(kind, str(data.get("hint", "")))
			d.position = feet
			d.hint_requested.connect(_on_hint)
			return d
		"S":
			return _enemy_node("skeleton", feet)
		"b":
			return _enemy_node("bat", feet + Vector2(0, -20))
		"z":
			return _enemy_node("slime", feet)
		"T":
			return _enemy_node("gargoyle", feet)
		"Z":
			has_boss = true
			return _enemy_node(boss_kind(), feet)
		"x":
			var saw := Saw.new()
			saw.position = center
			return saw
		"X":
			var cp := Checkpoint.new()
			cp.position = feet
			cp.reached.connect(_on_checkpoint)
			return cp
		"E":
			exit_door = ExitDoor.new()
			exit_door.position = feet
			exit_door.entered.connect(finish)
			return exit_door
		"p":
			princess = Princess.new()
			princess.position = feet
			princess.rescued.connect(finish)
			return princess
		"-":
			var mp := MovingPlatform.new()
			mp.position = feet
			mp.axis = Vector2.RIGHT
			mp.distance = 64.0
			return mp
		"|":
			var mp2 := MovingPlatform.new()
			mp2.position = feet
			mp2.axis = Vector2.UP
			mp2.distance = 48.0
			return mp2
		"1", "2", "3", "4":
			var lever := Lever.new()
			lever.channel = "abcd"["1234".find(ch)]
			lever.position = feet
			lever.activated.connect(_on_lever)
			return lever
		"A", "B", "c", "D":
			var gate := Gate.new()
			gate.setup("lever", "abcd"[["A", "B", "c", "D"].find(ch)], _gate_height(x, y))
			gate.position = feet
			gate.hint_requested.connect(_on_hint)
			_register_channel(gate.channel, gate)
			return gate
		"K":
			var kg := Gate.new()
			kg.setup("key", "key", _gate_height(x, y))
			kg.position = feet
			kg.hint_requested.connect(_on_hint)
			return kg
		"G":
			var bg := Gate.new()
			bg.setup("lever", "boss", _gate_height(x, y))
			bg.position = feet
			bg.hint_requested.connect(_on_hint)
			_register_channel("boss", bg)
			return bg
		"5", "6", "7", "8":
			var plate := PressurePlate.new()
			plate.channel = "efgh"["5678".find(ch)]
			plate.position = feet
			plate.state_changed.connect(_on_plate.bind(plate.channel))
			return plate
		"e", "f", "g", "h":
			var pg := Gate.new()
			pg.setup("plate", ch, _gate_height(x, y))
			pg.position = feet
			pg.hint_requested.connect(_on_hint)
			_register_channel(ch, pg)
			return pg
	return null

func _enemy_node(kind: String, pos: Vector2) -> Node:
	var n: Node = null
	match kind:
		"skeleton":
			n = Skeleton.new()
		"slime":
			n = Slime.new()
		"bat":
			n = Bat.new()
		"gargoyle":
			n = Gargoyle.new()
		"boss", "knight":
			n = Boss.new()
		"lich":
			n = LichKing.new()
	if n != null:
		n.position = pos
	return n

func _build_entities() -> void:
	entities = Node2D.new()
	entities.name = "Entities"
	add_child(entities)
	for e in map.entities:
		var node := _make_entity(str(e["ch"]), int(e["x"]), int(e["y"]))
		if node != null:
			entities.add_child(node)

func _build_player() -> void:
	player = Knight.new()
	player.position = start_point
	player.died.connect(_on_player_died)
	entities.add_child(player)
	player.camera.limit_left = 0
	player.camera.limit_top = -96
	player.camera.limit_right = int(map.size_px().x)
	player.camera.limit_bottom = int(map.size_px().y)
	player.camera.reset_smoothing()
	# после пересборки уровня старая камера могла остаться «текущей» и не удалиться из
	# вьюпорта — тогда вид замирает и больше не следит за рыцарем. Назначаем явно.
	player.camera.make_current()

func _setup_channels() -> void:
	for ch in channels.keys():
		_update_channel(ch)

func _on_lever(channel: String) -> void:
	channel_on[channel] = true
	_update_channel(channel)
	_on_hint("Ворота открылись!")

func _on_plate(pressed: bool, channel: String) -> void:
	plate_state[channel] = int(plate_state.get(channel, 0)) + (1 if pressed else -1)
	_update_channel(channel)

func _update_channel(channel: String) -> void:
	if not channels.has(channel):
		return
	var pressed := int(plate_state.get(channel, 0)) > 0
	var switched := bool(channel_on.get(channel, false))
	for g in channels[channel]:
		if not is_instance_valid(g):
			continue
		if g.gate_type == "plate":
			if pressed:
				g.open()
			else:
				g.close()
		elif switched:
			g.open()

func _on_checkpoint(pos: Vector2) -> void:
	respawn_point = pos
	_on_hint("Контрольная точка пройдена!")

func _on_hint(text: String) -> void:
	hint.emit(text)

func _on_player_died() -> void:
	pass

func register_boss(b: Boss) -> void:
	boss = b
	b.defeated.connect(_on_boss_defeated)
	hint.emit("%s! Победи его мечом!" % boss_name())

## Имя босса уровня (для подсказок).
func boss_name() -> String:
	return str(data.get("boss_name", "Чёрный рыцарь"))

## Какой босс стоит на уровне: "knight" — Чёрный рыцарь, "lich" — Король-лич.
func boss_kind() -> String:
	return str(data.get("boss", "knight"))

func _on_boss_defeated() -> void:
	channel_on["boss"] = true
	_update_channel("boss")
	if princess != null:
		_on_hint("%s побеждён! Принцесса ждёт!" % boss_name())
	else:
		_on_hint("%s побеждён! Дорога дальше открыта!" % boss_name())

# ---------------------------------------------------------------- утилиты
func spawn_coin(pos: Vector2) -> void:
	if entities == null:
		return
	var c := Coin.new()
	c.position = pos
	entities.add_child.call_deferred(c)

func spawn_enemy(kind: String, pos: Vector2) -> void:
	if entities == null:
		return
	var n := _enemy_node(kind, pos)
	if n != null:
		entities.add_child.call_deferred(n)

func shake(duration: float, power: float) -> void:
	_shake_time = maxf(_shake_time, duration)
	_shake_power = maxf(_shake_power, power)

func finish() -> void:
	if _finished:
		return
	_finished = true
	finished.emit()

func is_finished() -> bool:
	return _finished

func _ensure_camera() -> void:
	# страховка: если по какой-то причине во вьюпорте не осталось камеры (например,
	# после пересборки уровня), снова отдаём управление камере рыцаря.
	if player == null or not is_instance_valid(player) or player.camera == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_2d()
	if cam == null or not is_instance_valid(cam):
		player.camera.reset_smoothing()
		player.camera.make_current()

func _process(delta: float) -> void:
	_ensure_camera()
	if player != null and is_instance_valid(player) and player.camera != null:
		if _shake_time > 0.0:
			_shake_time -= delta
			var p := _shake_power * (_shake_time / 0.4 + 0.2)
			player.camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * p
		else:
			player.camera.offset = player.camera.offset.lerp(Vector2.ZERO, 0.3)
			_shake_power = 0.0

	if player == null or not is_instance_valid(player):
		return
	if not player.dead and player.global_position.y > map.size_px().y + 40.0:
		player.kill()

	# урон от ловушек (повторяется, пока стоим)
	_hazard_tick -= delta
	if _hazard_tick <= 0.0:
		_hazard_tick = 0.25
		for b in _lava_area.get_overlapping_bodies():
			if b is Knight and not b.dead:
				b.kill()
		for b in _hazard_area.get_overlapping_bodies():
			if b is Knight and not b.dead:
				b.hit(1, b.global_position + Vector2(0, 12))

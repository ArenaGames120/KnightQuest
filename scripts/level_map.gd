class_name LevelMap
## Разбор ASCII-схемы уровня: твёрдые тайлы, опасности, точки появления объектов.
## Используется и игрой (Level), и проверкой уровней (tools/check_levels.gd).

const SOLID := ["#", "=", "%", "M", "W"]
const HAZARD := ["^", "v", "~"]
const LAVA := ["~"]
const PLATFORM := ["-", "|"]

var rows: Array = []
var width := 0
var height := 0
var entities: Array = []          # [{ "ch": char, "x": int, "y": int }]
var player_start := Vector2i(2, 2)
var has_player := false

func parse(map_rows: Array) -> void:
	rows = []
	entities = []
	has_player = false
	height = map_rows.size()
	width = 0
	for r in map_rows:
		var s := str(r)
		width = maxi(width, s.length())
	for r in map_rows:
		var s := str(r)
		while s.length() < width:
			s += " "
		rows.append(s)
	for y in height:
		var line: String = rows[y]
		for x in width:
			var ch := line[x]
			if ch == " " or ch == ".":
				continue
			if SOLID.has(ch) or HAZARD.has(ch):
				continue
			if ch == "P":
				player_start = Vector2i(x, y)
				has_player = true
				continue
			entities.append({"ch": ch, "x": x, "y": y})

const ITEM_CHARS := {
	"player": "P", "exit": "E", "princess": "p", "coin": "o", "heart": "j", "key": "k",
	"key_gate": "K", "boss_gate": "G", "checkpoint": "X", "chest": "H", "crate": "C", "saw": "x",
	"skeleton": "S", "slime": "z", "bat": "b", "gargoyle": "T", "boss": "Z",
	"torch": "t", "bush": "u", "banner": "F", "sign": "n",
	"platform_h": "-", "platform_v": "|",
	"lever1": "1", "lever2": "2", "lever3": "3", "lever4": "4",
	"gate_a": "A", "gate_b": "B", "gate_c": "c", "gate_d": "D",
	"plate5": "5", "plate6": "6", "plate7": "7", "plate8": "8",
	"gate_e": "e", "gate_f": "f", "gate_g": "g", "gate_h": "h",
}

## Превращает координатное описание уровня в ASCII-строки.
static func rows_from_description(d: Dictionary) -> Array:
	var size: Vector2i = d.get("size", Vector2i(80, 21))
	var w := int(size.x)
	var h := int(size.y)
	var cells := []
	for y in h:
		var row := []
		row.resize(w)
		row.fill(" ")
		cells.append(row)
	for r in d.get("rects", []):
		var tile := str(r.get("tile", "#"))
		if tile.length() != 1:
			tile = "#"
		var x0 := int(r.get("x", 0))
		var y0 := int(r.get("y", 0))
		for y in range(y0, y0 + int(r.get("h", 1))):
			for x in range(x0, x0 + int(r.get("w", 1))):
				if y >= 0 and y < h and x >= 0 and x < w:
					cells[y][x] = tile
	for it in d.get("items", []):
		var tname := str(it.get("t", ""))
		if not ITEM_CHARS.has(tname):
			push_error("Неизвестный тип объекта: " + tname)
			continue
		var ch: String = ITEM_CHARS[tname]
		if ch.length() != 1:
			push_error("Код объекта должен быть одним символом: " + tname)
			continue
		var n := int(it.get("n", 1))
		for k in n:
			var x := int(it.get("x", 0)) + (k if bool(it.get("horiz", true)) else 0)
			var y := int(it.get("y", 0)) + (0 if bool(it.get("horiz", true)) else k)
			if y >= 0 and y < h and x >= 0 and x < w:
				cells[y][x] = ch
	var out := []
	for y in h:
		out.append("".join(cells[y]))
	return out

func char_at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= width or y >= height:
		return "="
	return rows[y][x]

func is_solid(x: int, y: int) -> bool:
	return SOLID.has(char_at(x, y))

func is_hazard(x: int, y: int) -> bool:
	return HAZARD.has(char_at(x, y))

func is_lava(x: int, y: int) -> bool:
	return LAVA.has(char_at(x, y))

func is_empty(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= width or y >= height:
		return false
	var ch := char_at(x, y)
	return ch == " " or ch == "." or not SOLID.has(ch)

func is_platform(x: int, y: int) -> bool:
	return PLATFORM.has(char_at(x, y))

## Опора снизу: твёрдый тайл или движущаяся платформа.
func has_floor(x: int, y: int) -> bool:
	return is_solid(x, y) or is_platform(x, y)

## Можно ли стоять в клетке (x,y): снизу опора, сама клетка и клетка выше свободны.
func standable(x: int, y: int) -> bool:
	if is_solid(x, y) or is_solid(x, y - 1):
		return false
	if not has_floor(x, y + 1):
		return false
	return true

func cell_center(x: int, y: int) -> Vector2:
	return Vector2(x * 16 + 8, y * 16 + 8)

func cell_feet(x: int, y: int) -> Vector2:
	return Vector2(x * 16 + 8, (y + 1) * 16)

func size_px() -> Vector2:
	return Vector2(width * 16, height * 16)

func stats() -> Dictionary:
	var count := {}
	for e in entities:
		var k: String = e["ch"]
		count[k] = int(count.get(k, 0)) + 1
	return count

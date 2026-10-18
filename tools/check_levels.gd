extends SceneTree
## Проверка уровней: рисует ASCII-схему каждого уровня и ищет проблемы.
## Запуск: godot --headless --path . --script res://tools/check_levels.gd
##
## Правила прыжка рыцаря (spеed 108, jump 350, gravity 900, апекс ~68 px):
##   подъём до 3 клеток: до 3 клеток в сторону;
##   подъём до 2 клеток: до 4 клеток в сторону;
##   плоский прыжок/переход: до 5 клеток;
##   прыжок вниз: до 6 клеток.
## Ворота нельзя перепрыгнуть: либо высота 5 клеток (80 px > 68 px), либо
## сверху сразу стена/шипы.

const GATE_CHARS := ["A", "B", "c", "D", "e", "f", "g", "h", "K", "G"]
const GROUND_CHARS := [
	"S", "z", "T", "Z", "C",
	"1", "2", "3", "4", "5", "6", "7", "8",
	"A", "B", "c", "D", "e", "f", "g", "h", "K", "G",
	"E", "p", "X", "t", "u", "F", "n", "H",
]
const ENEMY_CHARS := ["S", "z", "T", "Z", "b"]

func _initialize() -> void:
	var dump := []
	var problems_total := 0
	for i in LevelsData.LEVELS.size():
		var data: Dictionary = LevelsData.LEVELS[i]
		var map := LevelMap.new()
		var rows: Array = data.get("map", [])
		if rows.is_empty():
			rows = LevelMap.rows_from_description(data)
		map.parse(rows)
		expand_platforms(map)
		var res := check_level(i, data, map)
		problems_total += res.size()
		dump.append_array(render(i, data, map))
		dump.append("")
		dump.append("Проблемы: " + ("нет" if res.is_empty() else str(res.size())))
		for p in res:
			dump.append("  ! " + p)
		dump.append("")
	var f := FileAccess.open("res://levels_dump.txt", FileAccess.WRITE)
	f.store_string("\n".join(dump))
	f.close()
	print("Проблем найдено: ", problems_total, " (подробности в res://levels_dump.txt)")
	quit()

## Размечает реальный след движущихся платформ:
## горизонтальная — 3 клетки в ширину (x-1..x+1), вертикальная — 3 клетки вверх.
func expand_platforms(map: LevelMap) -> void:
	for e in map.entities:
		var ch: String = e["ch"]
		var x: int = e["x"]
		var y: int = e["y"]
		if ch == "-":
			for dx in range(-1, 2):
				_set_char_if_empty(map, x + dx, y, "-")
		elif ch == "|":
			for dy in range(0, 4):
				_set_char_if_empty(map, x, y - dy, "|")

func _set_char_if_empty(map: LevelMap, x: int, y: int, ch: String) -> void:
	if x < 0 or y < 0 or x >= map.width or y >= map.height:
		return
	var row: String = map.rows[y]
	var cur := row[x]
	if cur != " " and cur != ".":
		return
	map.rows[y] = row.substr(0, x) + ch + row.substr(x + 1)

func render(index: int, data: Dictionary, map: LevelMap) -> Array:
	var out := []
	var size: Vector2i = data.get("size", Vector2i(0, 0))
	out.append("=== Уровень %d: %s [%s] %dx%d ===" % [
		index + 1, data.get("name", "?"), data.get("theme", "?"), size.x, size.y])
	var ruler := "    "
	for x in map.width:
		ruler += str((x / 10) % 10) if x % 10 == 0 else " "
	out.append(ruler)
	for y in map.height:
		out.append("%3d %s" % [y, map.rows[y]])
	out.append("    " + ruler)
	var stats := map.stats()
	var parts := []
	for k in stats.keys():
		parts.append("%s=%d" % [k, stats[k]])
	parts.sort()
	out.append("    объекты: " + " ".join(parts))
	return out

# ================================================================ проверки
func check_level(index: int, data: Dictionary, map: LevelMap) -> Array:
	var problems := []
	var size: Vector2i = data.get("size", Vector2i(80, 21))

	# 1. длины строк
	if map.height != int(size.y):
		problems.append("высота карты %d, в size %d" % [map.height, int(size.y)])
	for y in map.height:
		var l: int = str(map.rows[y]).length()
		if l != int(size.x):
			problems.append("строка %d длиной %d, ожидалось %d" % [y, l, int(size.x)])

	# 2. старт, выход, принцесса
	if not map.has_player:
		problems.append("нет точки старта игрока (player)")
	var stats := map.stats()
	var is_last := index == LevelsData.LEVELS.size() - 1
	if not is_last and not stats.has("E"):
		problems.append("нет двери-выхода (exit)")
	if is_last and not stats.has("p"):
		problems.append("на последнем уровне нет принцессы (princess)")
	if int(stats.get("o", 0)) == 0:
		problems.append("на уровне нет монет")
	var enemies_here := 0
	for ch in ENEMY_CHARS:
		enemies_here += int(stats.get(ch, 0))
	if enemies_here == 0:
		problems.append("на уровне нет врагов")
	if stats.has("K") and int(stats.get("k", 0)) == 0:
		problems.append("есть ворота с ключом (K), но нет ключа (k)")

	# 3. объекты на земле / в стенах / в опасности
	for e in map.entities:
		var ch: String = e["ch"]
		var x: int = e["x"]
		var y: int = e["y"]
		if ch == "P":
			continue
		if map.is_hazard(x, y):
			problems.append("объект '%s' в (%d,%d) стоит в опасности (шипы/лава)" % [ch, x, y])
		if map.is_solid(x, y):
			problems.append("объект '%s' в (%d,%d) внутри стены" % [ch, x, y])
		if GROUND_CHARS.has(ch):
			if not map.has_floor(x, y + 1):
				problems.append("объект '%s' в (%d,%d) стоит в воздухе (нет опоры снизу)" % [ch, x, y])
			if map.is_solid(x, y - 1):
				problems.append("объект '%s' в (%d,%d) зажат в проёме высотой 1" % [ch, x, y])

	# 4. рычаги/плиты: есть ли для их канала ворота
	var lever_channels := {}
	var plate_channels := {}
	for e in map.entities:
		var ch: String = e["ch"]
		if "1234".contains(ch) and ch.length() == 1:
			lever_channels["abcd"["1234".find(ch)]] = true
		elif ch.length() == 1 and "5678".contains(ch):
			plate_channels["efgh"["5678".find(ch)]] = true
	var gate_channels := {}
	for e in map.entities:
		var ch: String = e["ch"]
		if not GATE_CHARS.has(ch):
			continue
		if ch == "K":
			gate_channels["key"] = true
		elif ch == "G":
			gate_channels["boss"] = true
		elif "ABCD".contains(ch) and ch.length() == 1:
			gate_channels["abcd"[["A", "B", "c", "D"].find(ch)]] = true
		elif "efgh".contains(ch) and ch.length() == 1:
			gate_channels[ch] = true
	for c in lever_channels.keys():
		if not gate_channels.has(c):
			problems.append("рычаг канала '%s' не открывает ни одних ворот" % c)
	for c in plate_channels.keys():
		if not gate_channels.has(c):
			problems.append("плита канала '%s' не открывает ни одних ворот" % c)
	for c in gate_channels.keys():
		if c == "key" or c == "boss":
			continue
		if not lever_channels.has(c) and not plate_channels.has(c):
			problems.append("ворота канала '%s' нечем открыть (нет рычага/плиты)" % c)
	if stats.has("G") and not stats.has("Z"):
		problems.append("есть ворота босса (G), но нет босса (Z)")

	# 4b. неизвестные символы
	var known := {}
	for v in LevelMap.ITEM_CHARS.values():
		known[v] = true
	for ch in stats.keys():
		if not known.has(ch):
			problems.append("неизвестный символ '%s' (%d шт.) — такого объекта в игре нет" % [ch, stats[ch]])

	# 5. ворота: высота и возможность перепрыгнуть/запрыгнуть сверху
	var solid_reach := reachable(map, true)
	for e in map.entities:
		var ch: String = e["ch"]
		if not GATE_CHARS.has(ch):
			continue
		var x: int = e["x"]
		var y: int = e["y"]
		var h := gate_height(map, x, y)
		if h < 5 and not map.is_solid(x, y - h):
			problems.append("ворота '%s' в (%d,%d): высота %d, сверху пусто — можно перепрыгнуть" % [ch, x, y, h])
		if solid_reach.has(Vector2i(x, y - h)):
			problems.append("ворота '%s' в (%d,%d): можно запрыгнуть сверху (клетка %d,%d)" % [ch, x, y, x, y - h])

	# 6. достижимость (ворота считаем открываемыми)
	var reach := reachable(map, false)
	if map.has_player and reach.is_empty():
		problems.append("старт недостижим?! (%d,%d)" % [map.player_start.x, map.player_start.y])
	for e in map.entities:
		var ch: String = e["ch"]
		var x: int = e["x"]
		var y: int = e["y"]
		if ch == "o" or ch == "j" or ch == "k":
			if not near_reachable(reach, Vector2i(x, y), 3):
				problems.append("подбираемый объект '%s' в (%d,%d) недостижим" % [ch, x, y])
		elif ch == "b":
			if not near_reachable(reach, Vector2i(x, y), 6):
				problems.append("летун 'b' в (%d,%d) недостижим" % [x, y])
		elif ch == "E" or ch == "p":
			if not near_reachable(reach, Vector2i(x, y), 2):
				problems.append("цель '%s' в (%d,%d) недостижима" % [ch, x, y])
		elif ch == "C" or ch == "K" or ch == "G":
			if not near_reachable(reach, Vector2i(x, y), 3):
				problems.append("'%s' в (%d,%d) недостижим" % [ch, x, y])
	return problems

## Высота ворот так же, как её считает игра.
func gate_height(map: LevelMap, x: int, y: int) -> int:
	var h := 1
	while h < 5 and not map.is_solid(x, y - h) and not map.is_hazard(x, y - h):
		h += 1
	return h

func solid_at(map: LevelMap, x: int, y: int, gates_solid: bool) -> bool:
	if map.is_solid(x, y):
		return true
	return gates_solid and GATE_CHARS.has(map.char_at(x, y))

func floor_at(map: LevelMap, x: int, y: int, gates_solid: bool) -> bool:
	return solid_at(map, x, y, gates_solid) or map.is_platform(x, y)

func standable_at(map: LevelMap, x: int, y: int, gates_solid: bool) -> bool:
	if x < 0 or y < 0 or x >= map.width or y >= map.height:
		return false
	if solid_at(map, x, y, gates_solid) or solid_at(map, x, y - 1, gates_solid):
		return false
	if map.is_hazard(x, y) or map.is_hazard(x, y - 1):
		return false
	return floor_at(map, x, y + 1, gates_solid)

## Обход достижимых «стоячих» клеток с учётом прыжков.
func reachable(map: LevelMap, gates_solid: bool) -> Dictionary:
	var out := {}
	if not map.has_player:
		return out
	var s := map.player_start
	while s.y < map.height - 1 and not standable_at(map, s.x, s.y, gates_solid) and not solid_at(map, s.x, s.y, gates_solid):
		s.y += 1
	if not standable_at(map, s.x, s.y, gates_solid):
		return out
	out[s] = true
	var queue: Array = [s]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_back()
		for dy in range(-3, 7):
			for dx in range(-6, 7):
				if dx == 0 and dy == 0:
					continue
				var to := Vector2i(cur.x + dx, cur.y + dy)
				if out.has(to):
					continue
				if not standable_at(map, to.x, to.y, gates_solid):
					continue
				if not jump_ok(map, cur, to, gates_solid):
					continue
				out[to] = true
				queue.append(to)
	return out

func jump_ok(map: LevelMap, from: Vector2i, to: Vector2i, gates_solid: bool) -> bool:
	var dx := to.x - from.x
	var dy := to.y - from.y
	var adx := absi(dx)
	if dy < -3:
		return false
	if dy == -3:
		if adx > 3:
			return false
	elif dy < 0:
		if adx > 4:
			return false
	elif dy == 0:
		if adx > 5:
			return false
	else:
		if adx > 6:
			return false
	# при подъёме: голова не бьётся о потолок над стартом
	if dy < 0:
		for k in range(1, -dy + 1):
			if solid_at(map, from.x, from.y - k, gates_solid):
				return false
	# верхняя линия траектории свободна по всей длине перелёта
	var ytop := mini(from.y, to.y) - 1
	for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
		if solid_at(map, x, ytop, gates_solid):
			return false
	return true

func near_reachable(reach: Dictionary, cell: Vector2i, radius: int) -> bool:
	for r in reach.keys():
		var v: Vector2i = r
		if maxi(absi(v.x - cell.x), absi(v.y - cell.y)) <= radius:
			return true
	return false

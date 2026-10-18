extends CanvasLayer
class_name Hud
## Экранный интерфейс: сердца, монеты, ключи, подсказки, пауза, смерть, победа.

const MAX_HEARTS := 5
const HINT_FADE := 0.8

var hearts: Array[TextureRect] = []
var coin_label: Label
var key_label: Label
var key_icon: TextureRect
var level_label: Label
var hint_label: Label
var panels := {}                 # имя -> { "root": Control, "lines": Array[Label] }

var hint_timer := 0.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	Game.hp_changed.connect(_update_hearts)
	Game.coins_changed.connect(_update_coins)
	Game.keys_changed.connect(_update_keys)
	_update_hearts()
	_update_coins()
	_update_keys()

# ================================================================ построение
func _build_ui() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(6, 4)
	bar.add_theme_constant_override("separation", 3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 1)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hb)
	for i in MAX_HEARTS:
		var h := TextureRect.new()
		h.texture = Art.frame("heart", 10, 8, 0)
		h.custom_minimum_size = Vector2(10, 8)
		h.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(h)
		hearts.append(h)

	bar.add_child(_gap(12))
	bar.add_child(_icon("coin", 8, 8))
	coin_label = _text("0", 10)
	bar.add_child(coin_label)

	bar.add_child(_gap(10))
	key_icon = _icon("key", 10, 12)
	bar.add_child(key_icon)
	key_label = _text("0", 10)
	bar.add_child(key_label)

	level_label = _text("", 10)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_left = 6
	level_label.offset_top = 5
	level_label.offset_right = -6
	level_label.offset_bottom = 20
	level_label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 0.9))
	add_child(level_label)

	hint_label = _text("", 11)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_left = 24
	hint_label.offset_top = -44
	hint_label.offset_right = -24
	hint_label.offset_bottom = -6
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hint_label.add_theme_constant_override("outline_size", 4)
	add_child(hint_label)

	panels["pause"] = _make_panel("ПАУЗА", [
		"ESC — продолжить игру",
		"R — начать уровень заново",
		"M — выйти в меню",
	])
	panels["death"] = _make_panel("РЫЦАРЬ ПАЛ", [
		"Сердца кончились, но принцесса всё ещё ждёт!",
		"R — попробовать снова",
		"M — выйти в меню",
	])
	panels["win"] = _make_panel("УРОВЕНЬ ПРОЙДЕН!", [
		"",
		"ПРОБЕЛ — дальше",
		"M — выйти в меню",
	])
	panels["final"] = _make_panel("ПРИНЦЕССА СПАСЕНА!", [
		"Рыцарь прошёл все %d уровней и спас принцессу!" % Game.LEVEL_COUNT,
		"",
		"ПРОБЕЛ — в меню",
	])

func _gap(w: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _icon(sheet: String, w: int, h: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.frame(sheet, w, h, 0)
	t.custom_minimum_size = Vector2(w + 2, h)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _text(txt: String, size: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _make_panel(title: String, lines: Array) -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.11, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	var t := _text(title, 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	box.add_child(t)

	var body: Array[Label] = []
	for s in lines:
		var l := _text(str(s), 11)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		body.append(l)
	return {"root": root, "lines": body}

# ================================================================ обновление
func _update_hearts() -> void:
	var hp := clampi(Game.hp, 0, MAX_HEARTS)
	for i in hearts.size():
		var full := i < hp
		hearts[i].modulate = Color(1, 1, 1, 1) if full else Color(0.35, 0.35, 0.42, 0.8)

func _update_coins() -> void:
	coin_label.text = str(Game.coins)

func _update_keys() -> void:
	key_label.text = str(Game.keys)
	var has := Game.keys > 0
	key_icon.modulate = Color(1, 1, 1, 1) if has else Color(0.5, 0.5, 0.55, 0.6)
	key_label.modulate = Color(1, 1, 1, 1) if has else Color(0.5, 0.5, 0.55, 0.6)

func set_level_text(index: int, name: String) -> void:
	level_label.text = "Уровень %d/%d — %s" % [index + 1, Game.LEVEL_COUNT, name]

# ================================================================ подсказки
func show_hint(text: String, duration := 4.0) -> void:
	if text == "":
		return
	hint_label.text = text
	hint_label.modulate.a = 1.0
	hint_timer = duration

func clear_hints() -> void:
	hint_timer = 0.0
	hint_label.text = ""
	hint_label.modulate.a = 1.0

func _process(delta: float) -> void:
	for p in panels.values():
		var root: Control = p["root"]
		if root.visible and root.modulate.a < 1.0:
			root.modulate.a = minf(1.0, root.modulate.a + delta * 5.0)
	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= HINT_FADE:
			hint_label.modulate.a = clampf(hint_timer / HINT_FADE, 0.0, 1.0)
		if hint_timer <= 0.0:
			hint_label.text = ""

# ================================================================ панели
func show_panel(name: String) -> void:
	for k in panels.keys():
		var root: Control = panels[k]["root"]
		root.visible = k == name
		if root.visible:
			root.modulate.a = 0.0

func hide_panels() -> void:
	for k in panels.keys():
		panels[k]["root"].visible = false

func set_panel_line(name: String, index: int, text: String) -> void:
	if not panels.has(name):
		return
	var lines: Array = panels[name]["lines"]
	if index >= 0 and index < lines.size():
		lines[index].text = text

func show_win(coins: int, next_index: int) -> void:
	set_panel_line("win", 0, "Монет собрано: %d" % coins)
	set_panel_line("win", 1, "ПРОБЕЛ — уровень %d" % (next_index + 1))
	show_panel("win")

func show_final(total_coins: int, cleared: int) -> void:
	set_panel_line("final", 0,
		"Рыцарь прошёл все %d уровней и спас принцессу!" % Game.LEVEL_COUNT)
	set_panel_line("final", 1,
		"Пройдено уровней: %d/%d, монет: %d" % [cleared, Game.LEVEL_COUNT, total_coins])
	show_panel("final")

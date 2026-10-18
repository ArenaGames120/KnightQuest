extends CanvasLayer
class_name Menu
## Главное меню: заголовок, выбор уровня, прогресс и справка по управлению.

signal level_chosen(index: int)

const RESET_HOLD := 3.0

var buttons: Array[Button] = []
var info_label: Label
var total_label: Label
var reset_button: Button
var reset_armed := 0.0

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func open() -> void:
	_update()
	visible = true
	for b in buttons:
		if not b.disabled:
			b.grab_focus()
			break

func close() -> void:
	visible = false
	if reset_armed > 0.0:
		reset_armed = 0.0
		reset_button.text = "Сбросить прогресс"

# ================================================================ построение
func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = Art.tex("bg_sky")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.14, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)

	# --- заголовок с рыцарем и принцессой
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 10)
	box.add_child(title_row)
	title_row.add_child(_pic("knight", 16, 20, 30, 38))
	var title := _text("КВЕСТ РЫЦАРЯ", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	title_row.add_child(title)
	title_row.add_child(_pic("princess", 16, 20, 30, 38))

	var sub := _text("Пройди %d уровней с головоломками, монетами и врагами — и спаси принцессу!" % Game.LEVEL_COUNT, 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	# --- сетка уровней
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for i in Game.LEVEL_COUNT:
		var b := Button.new()
		b.custom_minimum_size = Vector2(58, 24)
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_on_level_pressed.bind(i))
		b.focus_entered.connect(_on_level_focus.bind(i))
		b.mouse_entered.connect(_on_level_focus.bind(i))
		grid.add_child(b)
		buttons.append(b)

	info_label = _text("", 10)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.custom_minimum_size = Vector2(320, 14)
	box.add_child(info_label)

	total_label = _text("", 10)
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(total_label)

	var help := _text("A/D — идти, ПРОБЕЛ — прыжок, J — меч, R — заново, ESC — пауза, F11 — весь экран", 9)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0, 0.85))
	box.add_child(help)

	reset_button = Button.new()
	reset_button.text = "Сбросить прогресс"
	reset_button.add_theme_font_size_override("font_size", 9)
	reset_button.pressed.connect(_on_reset_pressed)
	box.add_child(reset_button)

func _pic(sheet: String, w: int, h: int, sw: int, sh: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.frame(sheet, w, h, 0)
	t.custom_minimum_size = Vector2(sw, sh)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _text(txt: String, size: int) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ================================================================ состояние
func _update() -> void:
	for i in buttons.size():
		var unlocked := Game.is_level_unlocked(i)
		var cleared := Game.levels_cleared.has(str(i + 1))
		buttons[i].disabled = not unlocked
		buttons[i].text = str(i + 1) + (" ✓" if cleared else "")
		buttons[i].modulate = Color(1, 1, 1, 1) if unlocked else Color(0.55, 0.55, 0.62, 0.7)
		buttons[i].tooltip_text = "%d. %s" % [i + 1, _level_name(i)] if unlocked else "Уровень закрыт"
	_update_info(0)
	total_label.text = "Всего монет: %d   •   Пройдено: %d/%d" % [
		Game.total_coins, Game.levels_cleared.size(), Game.LEVEL_COUNT]

func _level_name(i: int) -> String:
	var data: Dictionary = LevelsData.LEVELS[i]
	return str(data.get("name", "Уровень"))

func _update_info(i: int) -> void:
	if not Game.is_level_unlocked(i):
		info_label.text = "Уровень %d закрыт — пройди предыдущие!" % (i + 1)
		return
	var best := int(Game.best_coins.get(str(i + 1), -1))
	var tail := "монет ещё нет" if best < 0 else ("лучший результат: %d монет" % best)
	info_label.text = "Уровень %d: %s — %s" % [i + 1, _level_name(i), tail]

func _on_level_focus(i: int) -> void:
	_update_info(i)

func _on_level_pressed(i: int) -> void:
	if not Game.is_level_unlocked(i):
		Game.play_sfx("gate", 0.7)
		_update_info(i)
		return
	Game.play_sfx("select")
	level_chosen.emit(i)

func _on_reset_pressed() -> void:
	if reset_armed <= 0.0:
		reset_armed = RESET_HOLD
		reset_button.text = "Нажми ещё раз, чтобы сбросить!"
		return
	reset_armed = 0.0
	reset_button.text = "Сбросить прогресс"
	Game.reset_progress()
	Game.play_sfx("door", 0.7)
	_update()

func _process(delta: float) -> void:
	if reset_armed > 0.0:
		reset_armed -= delta
		if reset_armed <= 0.0:
			reset_button.text = "Сбросить прогресс"

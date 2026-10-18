extends Node2D
class_name Main
## Корень игры: меню, запуск уровней, пауза, смерть и переходы между уровнями.

enum State { MENU, PLAY, PAUSE, DEAD_WAIT, DEAD, WIN }

var state := State.MENU
var level: Level
var hud: Hud
var menu: Menu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	menu = Menu.new()
	menu.name = "Menu"
	add_child(menu)
	menu.level_chosen.connect(_on_level_chosen)
	_open_menu()

# ================================================================ меню
func _open_menu() -> void:
	get_tree().paused = false
	state = State.MENU
	_clear_level()
	hud.visible = false
	hud.hide_panels()
	hud.clear_hints()
	menu.open()
	Game.play_music("music_world")

func _on_level_chosen(index: int) -> void:
	_start_level(index)

func _clear_level() -> void:
	if level != null and is_instance_valid(level):
		level.free()
	level = null

# ================================================================ уровень
func _start_level(index: int) -> void:
	Game.start_level(index)
	_build_level(index)

func _build_level(index: int) -> void:
	_clear_level()
	var data: Dictionary = LevelsData.LEVELS[index]
	level = Level.new()
	level.name = "Level"
	add_child(level)
	level.build(data, index)
	level.finished.connect(_on_level_finished)
	level.hint.connect(_on_hint)
	level.player.died.connect(_on_player_died)
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	menu.close()
	hud.visible = true
	hud.hide_panels()
	hud.clear_hints()
	hud.set_level_text(index, level.level_name())
	if str(data.get("hint", "")) != "":
		hud.show_hint(str(data.get("hint", "")), 6.0)
	if level.has_boss:
		hud.show_hint("%s! Победи его мечом!" % level.boss_name(), 6.0)
	Game.play_music("music_boss" if level.has_boss else "music_world")
	state = State.PLAY
	get_tree().paused = false

func _restart_level(at_checkpoint: bool) -> void:
	var coins := Game.coins
	var keys := Game.keys
	var index := Game.level_index
	var spawn := Vector2.ZERO
	if at_checkpoint and level != null and is_instance_valid(level):
		spawn = level.respawn_point
	Game.start_level(index)
	_build_level(index)
	Game.coins = coins
	Game.keys = keys
	Game.coins_changed.emit()
	Game.keys_changed.emit()
	if at_checkpoint and spawn != Vector2.ZERO:
		level.player.position = spawn
		level.respawn_point = spawn
		level.player.camera.reset_smoothing()
		level.player.camera.make_current()
		hud.show_hint("С контрольной точки — вперёд!", 3.0)
	else:
		hud.show_hint("Уровень начат заново!", 3.0)

func _next_level() -> void:
	if Game.level_index + 1 >= Game.LEVEL_COUNT:
		_open_menu()
	else:
		_start_level(Game.level_index + 1)

# ================================================================ события уровня
func _on_hint(text: String) -> void:
	hud.show_hint(text, 3.5)

func _on_level_finished() -> void:
	if state != State.PLAY:
		return
	if level != null and is_instance_valid(level) and level.player != null:
		level.player.set_control(false)
	Game.complete_level()
	state = State.WIN
	Game.stop_music()
	if Game.level_index >= Game.LEVEL_COUNT - 1:
		hud.show_final(Game.total_coins, Game.levels_cleared.size())
	else:
		hud.show_win(Game.coins, Game.level_index + 1)

func _on_player_died() -> void:
	if state != State.PLAY:
		return
	state = State.DEAD_WAIT
	var t := get_tree().create_timer(1.5)
	t.timeout.connect(_show_death_panel)

func _show_death_panel() -> void:
	if state != State.DEAD_WAIT:
		return
	state = State.DEAD
	hud.show_panel("death")
	Game.play_sfx("lose")

# ================================================================ ввод
func _set_pause(on: bool) -> void:
	if on:
		state = State.PAUSE
		get_tree().paused = true
		hud.show_panel("pause")
	else:
		state = State.PLAY
		get_tree().paused = false
		hud.hide_panels()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		return
	if event.is_action_pressed("menu"):
		if state != State.MENU:
			_open_menu()
			get_viewport().set_input_as_handled()
		return
	match state:
		State.PLAY:
			if event.is_action_pressed("pause"):
				_set_pause(true)
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("restart"):
				_restart_level(false)
				get_viewport().set_input_as_handled()
		State.PAUSE:
			if event.is_action_pressed("pause"):
				_set_pause(false)
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("restart"):
				get_tree().paused = false
				_restart_level(false)
				get_viewport().set_input_as_handled()
		State.DEAD:
			if event.is_action_pressed("restart") or event.is_action_pressed("jump"):
				_restart_level(true)
				get_viewport().set_input_as_handled()
		State.WIN:
			if event.is_action_pressed("jump") or event.is_action_pressed("interact") or event.is_action_pressed("attack"):
				_next_level()
				get_viewport().set_input_as_handled()

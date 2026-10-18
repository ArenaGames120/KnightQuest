extends Node
## Глобальное состояние игры: ввод, звук, сохранения, прогресс.
## Автозагружается как синглтон "Game".

signal coins_changed
signal keys_changed
signal hp_changed

const LEVEL_COUNT := 20
const START_HP := 3
const SAVE_PATH := "user://knight_quest_save.json"
const SFX_PATH := "res://audio/%s.wav"

# --- прогресс ---
var level_index := 0        # текущий уровень (0-based)
var unlocked := 1           # сколько уровней доступно (1..LEVEL_COUNT)
var total_coins := 0        # суммарно монет (по лучшим результатам)
var best_coins := {}        # "номер уровня" -> лучший результат
var coins := 0              # монеты на текущем прохождении уровня
var keys := 0               # ключи на текущем уровне
var hp := START_HP
var levels_cleared := {}    # "номер" -> true

var sfx_volume := 0.8
var music_volume := 0.5

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _sfx_cache := {}

func _ready() -> void:
	randomize()
	_setup_input()
	_setup_audio()
	load_save()
	set_process_input(true)

# ---------------------------------------------------------------- ввод
func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action("attack", [KEY_J, KEY_X, KEY_Z])
	_add_action("interact", [KEY_E, KEY_ENTER])
	_add_action("restart", [KEY_R])
	_add_action("pause", [KEY_ESCAPE, KEY_P])
	_add_action("menu", [KEY_M])
	_add_action("fullscreen", [KEY_F11])

func _add_action(name: String, keys: Array) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(name, ev)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# ---------------------------------------------------------------- звук
func _setup_audio() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = linear_to_db(music_volume)
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = linear_to_db(sfx_volume)
		add_child(p)
		_sfx_pool.append(p)

func play_sfx(sound: String, pitch := 1.0, volume := 1.0) -> void:
	if not _sfx_cache.has(sound):
		_sfx_cache[sound] = load(SFX_PATH % sound)
	var stream: AudioStream = _sfx_cache[sound]
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch
			p.volume_db = linear_to_db(sfx_volume * volume)
			p.play()
			return

func play_music(name: String) -> void:
	var stream: AudioStream = load(SFX_PATH % name)
	if stream == null:
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(music_volume)
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func _on_music_finished() -> void:
	if _music_player.stream != null:
		_music_player.play()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_music_player.volume_db = linear_to_db(music_volume)

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)

# ---------------------------------------------------------------- монеты / ключи / сердце
func add_coin(n := 1) -> void:
	coins += n
	total_coins += n
	coins_changed.emit()

func add_key(n := 1) -> void:
	keys += n
	keys_changed.emit()

func use_key() -> bool:
	if keys <= 0:
		return false
	keys -= 1
	keys_changed.emit()
	play_sfx("key")
	return true

func set_hp(v: int) -> void:
	hp = clampi(v, 0, 99)
	hp_changed.emit()

func heal(n := 1) -> void:
	set_hp(hp + n)
	play_sfx("coin", 1.3)

func damage(n := 1) -> bool:
	if hp <= 0:
		return false
	set_hp(hp - n)
	return hp <= 0

func reset_level_progress() -> void:
	coins = 0
	keys = 0
	coins_changed.emit()
	keys_changed.emit()

# ---------------------------------------------------------------- прогресс и сохранение
func start_level(index: int) -> void:
	level_index = clampi(index, 0, LEVEL_COUNT - 1)
	reset_level_progress()
	set_hp(START_HP)

func complete_level() -> void:
	var num := str(level_index + 1)
	var prev: int = best_coins.get(num, 0)
	best_coins[num] = maxi(prev, coins)
	total_coins = 0
	for k in best_coins.keys():
		total_coins += int(best_coins[k])
	levels_cleared[num] = true
	unlocked = maxi(unlocked, mini(level_index + 2, LEVEL_COUNT))
	save_game()

func is_level_unlocked(index: int) -> bool:
	return index < unlocked

func save_game() -> void:
	var data := {
		"unlocked": unlocked,
		"best_coins": best_coins,
		"cleared": levels_cleared,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	unlocked = int(parsed.get("unlocked", 1))
	best_coins = parsed.get("best_coins", {})
	levels_cleared = parsed.get("cleared", {})
	music_volume = float(parsed.get("music_volume", 0.5))
	sfx_volume = float(parsed.get("sfx_volume", 0.8))
	total_coins = 0
	for k in best_coins.keys():
		total_coins += int(best_coins[k])
	if _music_player != null:
		_music_player.volume_db = linear_to_db(music_volume)

func reset_progress() -> void:
	unlocked = 1
	best_coins = {}
	levels_cleared = {}
	total_coins = 0
	save_game()

extends Node
## Захват скриншотов: запускаем игру в окне и сохраняем кадры в папку.
## Запуск: godot --path . res://tools/Capture.tscn -- --shots=ПАПКА

const SHOT_FRAMES := 14

var main: Main
var out_dir := ""
var shots := 0
var fails: Array[String] = []
var _save_backup := ""
var _had_save := false

func _ready() -> void:
	_prepare_save()
	out_dir = _shots_dir()
	print("=== Захват скриншотов в ", out_dir, " ===")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var packed: PackedScene = load("res://scenes/Main.tscn")
	main = packed.instantiate()
	add_child(main)
	await _wait(6)

	await _shot("01_menu")
	for i in _level_range():
		await _level_shots(i)

	await _panel_shots()

	print("=== Кадров: %d ===" % shots)
	if fails.is_empty():
		print("ЗАХВАТ ОК")
	else:
		for f in fails:
			print("  ! " + f)
	_restore_save()
	get_tree().quit(0)

## Скриншоты снимаем на «чистом» прогрессе, после — возвращаем сохранение игрока.
func _prepare_save() -> void:
	_had_save = FileAccess.file_exists(Game.SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_string(Game.SAVE_PATH)
	Game.reset_progress()

func _restore_save() -> void:
	if _had_save:
		var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_save_backup)
			f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))

func _shots_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			return a.substr(8)
	var base := OS.get_environment("TEMP")
	if base == "":
		base = OS.get_user_data_dir()
	return base.replace("\\", "/").rstrip("/") + "/knight_quest_shots"

# ================================================================ уровни
## Какие уровни снимать: --from=11 --to=20 (нумерация с 1). По умолчанию — все.
func _level_range() -> Array:
	var from := 1
	var to := LevelsData.LEVELS.size()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			from = clampi(int(a.substr(7)), 1, LevelsData.LEVELS.size())
		elif a.begins_with("--to="):
			to = clampi(int(a.substr(5)), 1, LevelsData.LEVELS.size())
	var out: Array = []
	for i in range(from - 1, to):
		out.append(i)
	return out

func _level_shots(index: int) -> void:
	main._start_level(index)
	await _wait(SHOT_FRAMES)
	var level := main.level
	if level == null:
		fails.append("уровень %d не собрался" % (index + 1))
		return
	await _shot("lv%02d_start" % (index + 1))

	var target: Variant = _interest_point(level)
	if target != null:
		var pos: Vector2 = target
		await _free_camera(pos)
		await _shot("lv%02d_puzzle" % (index + 1))
		_open_everything(level)
		await _shot("lv%02d_open" % (index + 1))
		await _player_camera()
	if level.has_boss and level.boss != null and is_instance_valid(level.boss):
		await _free_camera(level.boss.global_position + Vector2(0, -10))
		await _shot("lv%02d_boss" % (index + 1))
		await _player_camera()
	if level.princess != null and is_instance_valid(level.princess):
		await _free_camera(level.princess.global_position + Vector2(0, -14))
		await _shot("lv%02d_princess" % (index + 1))
		await _player_camera()

## Средняя точка «интересных» объектов уровня (ворота, рычаги, плиты, ящики...)
func _interest_point(level: Level) -> Variant:
	var pts: Array[Vector2] = []
	for n in level.entities.get_children():
		if n is Gate or n is Lever or n is PressurePlate or n is KeyItem \
				or n is Crate or n is MovingPlatform or n is Saw:
			pts.append(n.global_position)
	if pts.is_empty():
		return null
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / pts.size()

func _open_everything(level: Level) -> void:
	for ch in level.channels.keys():
		level._on_lever(str(ch))
		level._on_plate(true, str(ch))
	for n in level.entities.get_children():
		if n is Gate:
			n.open()
	await _wait(4)

func _free_camera(pos: Vector2) -> void:
	var cam := Camera2D.new()
	cam.position = pos
	cam.zoom = Vector2.ONE
	var pc := main.level.player.camera
	cam.limit_left = pc.limit_left
	cam.limit_top = pc.limit_top
	cam.limit_right = pc.limit_right
	cam.limit_bottom = pc.limit_bottom
	main.level.add_child(cam)
	cam.make_current()
	await _wait(3)

func _player_camera() -> void:
	if main.level != null and main.level.player != null:
		main.level.player.camera.make_current()
		main.level.player.camera.reset_smoothing()
	await _wait(3)

# ================================================================ панели
func _panel_shots() -> void:
	main._start_level(0)
	await _wait(SHOT_FRAMES)
	main._set_pause(true)
	await _wait(25)
	await _shot("panel_pause")
	main._set_pause(false)
	await _wait(2)
	main.state = Main.State.DEAD_WAIT
	main._show_death_panel()
	await _wait(25)
	await _shot("panel_death")
	main.state = Main.State.PLAY
	main.hud.hide_panels()
	main.level.finish()
	await _wait(25)
	await _shot("panel_win")
	main.state = Main.State.PLAY
	main._start_level(Game.LEVEL_COUNT - 1)
	await _wait(SHOT_FRAMES)
	await _free_camera(main.level.princess.global_position + Vector2(0, -14))
	main.level._on_boss_defeated()
	await _wait(45)
	await _shot("lv%02d_rescue" % Game.LEVEL_COUNT)
	main.level.finish()
	await _wait(25)
	await _shot("panel_final")
	await _player_camera()

# ================================================================ утилиты
func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [out_dir, name]
	var err := img.save_png(path)
	if err != OK:
		fails.append("не сохранился %s (%d)" % [path, err])
		print("  ! кадр ", name, " ошибка ", err)
	else:
		shots += 1
		print("  кадр %-18s %dx%d" % [name, img.get_width(), img.get_height()])

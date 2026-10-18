extends Node
## Прогон игры без вывода: грузим Main.tscn, проходим по всем уровням,
## проверяем смерть/возрождение/победу.
## Запуск: godot --headless --path . res://tools/TestPlay.tscn

var main: Node
var fails: Array[String] = []
var _save_backup := ""
var _had_save := false

func _ready() -> void:
	_prepare_save()
	var packed := load("res://scenes/Main.tscn")
	if packed == null:
		push_error("не загрузилась res://scenes/Main.tscn")
		get_tree().quit(1)
		return
	main = packed.instantiate()
	add_child(main)
	await get_tree().process_frame

	_check_menu()

	for i in LevelsData.LEVELS.size():
		await _run_level(i)

	await _test_death_and_respawn()
	await _test_win_and_next()
	await _test_gameplay()

	print("----")
	if fails.is_empty():
		print("ТЕСТ ПРОЙДЕН: все проверки ок")
	else:
		print("ТЕСТ НЕ ПРОЙДЕН:")
		for f in fails:
			print("  ! " + f)
	_restore_save()
	get_tree().quit(1 if not fails.is_empty() else 0)

## Тест не должен портить сохранение игрока: прогресс сбрасывается, файл возвращается.
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

func _fail(text: String) -> void:
	fails.append(text)
	print("  ОШИБКА: " + text)

func _check_menu() -> bool:
	var menu = main.menu
	var ok: bool = menu != null and menu.visible
	if not ok:
		_fail("меню не открылось при старте")
		return false
	var unlocked := 0
	for b in menu.buttons:
		if not b.disabled:
			unlocked += 1
	print("меню: кнопок %d, доступно %d" % [menu.buttons.size(), unlocked])
	if menu.buttons.size() != Game.LEVEL_COUNT:
		_fail("в меню %d кнопок, ожидалось %d" % [menu.buttons.size(), Game.LEVEL_COUNT])
	return ok

func _run_level(index: int) -> void:
	main._start_level(index)
	await get_tree().process_frame
	var level = main.level
	if level == null:
		_fail("уровень %d не собрался" % (index + 1))
		return
	var stats: Dictionary = level.map.stats()
	var enemies := 0
	for ch in ["S", "z", "T", "b", "Z"]:
		enemies += int(stats.get(ch, 0))
	var ground: float = level.map.size_px().y
	for f in 110:
		await get_tree().process_frame
		if level.player != null and not is_instance_valid(level.player):
			_fail("уровень %d: игрок исчез" % (index + 1))
			return
	if level.player != null:
		var p: Vector2 = level.player.global_position
		if p.y > ground + 24.0:
			_fail("уровень %d: рыцарь улетел под карту (y=%.0f)" % [index + 1, p.y])
	print("уровень %2d: %-22s монет=%-3d врагов=%-2d ключей=%d босс=%s состояние=%d" % [
		index + 1, level.level_name(), int(stats.get("o", 0)), enemies,
		int(stats.get("k", 0)), str(level.has_boss), main.state])

func _test_death_and_respawn() -> void:
	main._start_level(4)
	await get_tree().process_frame
	var level = main.level
	level.respawn_point = level.start_point + Vector2(96, 0)
	level.player.kill()
	for f in 400:
		await get_tree().process_frame
		if main.state == 4:      # State.DEAD
			break
	if main.state != 4:
		_fail("после смерти панель смерти не показалась (state=%d)" % main.state)
	else:
		print("смерть: панель показана, возрождаемся с чекпоинта")
	main._restart_level(true)
	await get_tree().process_frame
	if main.state != 1:
		_fail("после возрождения состояние %d, ожидалось PLAY" % main.state)
	if main.level == null or main.level.player == null:
		_fail("после возрождения нет рыцаря")
	else:
		var p: Vector2 = main.level.player.global_position
		if absf(p.x - (main.level.start_point.x + 96.0)) > 2.0:
			_fail("рыцарь возродился в (%.0f,%.0f), а не на чекпоинте" % [p.x, p.y])
		print("возрождение на чекпоинте: x=%.0f (старт x=%.0f)" % [p.x, main.level.start_point.x])
		await _check_camera_follows()

## Камера должна следить за рыцарем и после возрождения (частая жалоба игроков).
func _check_camera_follows() -> void:
	var cam: Camera2D = main.level.player.camera
	var view_cam := get_viewport().get_camera_2d()
	if view_cam != cam:
		_fail("после возрождения камера вида — %s, а не камера рыцаря" % [view_cam])
		return
	var before: float = cam.get_screen_center_position().x
	# двигаем рыцаря далеко вправо: у левого края карты камера прижата к границе
	main.level.player.global_position += Vector2(500, 0)
	for i in 60:
		await get_tree().process_frame
	var p: Vector2 = main.level.player.global_position
	var after: float = cam.get_screen_center_position().x
	if after - before < 200.0:
		_fail("камера не поехала за рыцарем (%.0f -> %.0f)" % [before, after])
	elif absf(after - p.x) > 80.0:
		_fail("камера отстала от рыцаря (камера %.0f, рыцарь %.0f)" % [after, p.x])
	else:
		print("камера: следит за рыцарем после возрождения ок (%.0f -> %.0f)" % [before, after])

func _test_win_and_next() -> void:
	main._start_level(2)
	await get_tree().process_frame
	main.level.finish()
	await get_tree().process_frame
	if main.state != 5:      # State.WIN
		_fail("после финиша состояние %d, ожидалось WIN" % main.state)
	else:
		print("финиш уровня: панель победы показана")
	main._next_level()
	await get_tree().process_frame
	if Game.level_index != 3:
		_fail("переход на следующий уровень не сработал (index=%d)" % Game.level_index)
	else:
		print("переход на уровень %d ок" % (Game.level_index + 1))
	await _test_final_level()

## Финальный уровень: Король-лич, ворота после босса, принцесса и панель с итогами.
func _test_final_level() -> void:
	print("--- финал (уровень %d) ---" % Game.LEVEL_COUNT)
	if Game.LEVEL_COUNT != 20:
		_fail("уровней %d, ожидалось 20" % Game.LEVEL_COUNT)
	main._start_level(Game.LEVEL_COUNT - 1)
	await _wait(4)
	var level: Level = main.level
	if level == null:
		_fail("финальный уровень не собрался")
		return
	if level.princess == null:
		_fail("на финальном уровне нет принцессы")
	if not level.has_boss:
		_fail("на финальном уровне нет босса")
	var boss: Boss = level.boss
	if boss == null:
		_fail("босс финального уровня не зарегистрирован")
	elif not (boss is LichKing):
		_fail("финальный босс — %s, а не Король-лич" % [boss.get_class()])
	else:
		print("финальный босс: Король-лич, здоровья %d" % boss.max_hp)
	var bg := _find_gate(level, "boss")
	if bg == null:
		_fail("на финальном уровне нет ворот босса")
	elif bg.is_open:
		_fail("ворота босса открыты до победы над боссом")
	elif boss != null:
		level.player.global_position = boss.global_position + Vector2(-60, 0)
		await _wait(30)
		if not boss._started:
			_fail("Король-лич не заметил рыцаря (бой не начался)")
		else:
			print("Король-лич: бой начался")
		boss.take_damage(99, 0)
		await _wait(20)
		if not boss.dead:
			_fail("Король-лич не погиб от удара (hp=%d)" % boss.hp)
		elif not bg.is_open:
			_fail("ворота к принцессе не открылись после смерти Короля-лича")
		else:
			print("финальные ворота: открылись после победы над Королём-личом")
	level.finish()
	await get_tree().process_frame
	if main.state != 5:
		_fail("финал не сработал (state=%d)" % main.state)
	else:
		print("финал: принцесса спасена, монет всего %d" % Game.total_coins)
	var panel = main.hud.panels.get("final")
	if panel == null or not panel["root"].visible:
		_fail("после финала не показана панель с итогами")
	else:
		print("финал: панель с итогами показана")

# ================================================================ геймплей
func _find_coin(level: Level) -> Coin:
	for n in level.entities.get_children():
		if n is Coin:
			return n
	return null

func _find_enemy(level: Level) -> EnemyBase:
	for n in level.entities.get_children():
		if n is EnemyBase:
			return n
	return null

func _find_lever(level: Level) -> Lever:
	for n in level.entities.get_children():
		if n is Lever and not n.used:
			return n
	return null

func _find_plate(level: Level) -> PressurePlate:
	for n in level.entities.get_children():
		if n is PressurePlate:
			return n
	return null

func _find_gate(level: Level, channel: String) -> Gate:
	for n in level.entities.get_children():
		if n is Gate and n.channel == channel:
			return n
	return null

func _test_gameplay() -> void:
	print("--- геймплей ---")
	# рыцарь, монеты, враги и уровни у врагов
	main._start_level(0)
	await _wait(4)
	var level: Level = main.level
	if not level.player.is_in_group("player"):
		_fail("рыцарь не в группе \"player\"")
	var enemy := _find_enemy(level)
	if enemy == null:
		_fail("на уровне 1 нет врагов")
	else:
		if enemy.player == null:
			_fail("враг не видит рыцаря (player == null)")
		if not (enemy.level is Level):
			_fail("враг не нашёл уровень (level = %s)" % [enemy.level])
		else:
			print("враги: видят рыцаря и уровень ок")

	var coin := _find_coin(level)
	if coin == null:
		_fail("на уровне 1 нет монет")
	else:
		var before := Game.coins
		level.player.global_position = coin.global_position
		await _wait(30)
		if Game.coins <= before:
			_fail("монета не собралась (было %d, стало %d)" % [before, Game.coins])
		else:
			print("монета: собрана (%d -> %d)" % [before, Game.coins])

	# сердце лечит
	Game.set_hp(1)
	var heart := _find_heart(level)
	if heart != null:
		level.player.global_position = heart.global_position
		await _wait(30)
		if Game.hp <= 1:
			_fail("сердце не вылечило рыцаря (hp=%d)" % Game.hp)
		else:
			print("сердце: вылечило до %d" % Game.hp)
	Game.set_hp(5)

	# рычаг открывает ворота
	main._start_level(5)
	await _wait(4)
	level = main.level
	var lever := _find_lever(level)
	if lever == null:
		_fail("на уровне 6 нет рычагов")
	else:
		var gate := _find_gate(level, lever.channel)
		if gate == null:
			_fail("у рычага нет ворот канала %s" % lever.channel)
		else:
			level.player.global_position = lever.global_position
			await _wait(30)
			if not lever.used:
				_fail("рычаг не сработал от касания рыцаря")
			if not gate.is_open:
				_fail("ворота канала %s не открылись от рычага" % lever.channel)
			else:
				print("рычаг: ворота канала %s открылись" % lever.channel)

	# ключ открывает ворота с замком
	var kg := _find_gate(level, "key")
	if kg == null:
		_fail("на уровне 6 нет ворот с замком")
	else:
		Game.add_key(1)
		level.player.global_position = kg.global_position + Vector2(0, -2)
		await _wait(30)
		if not kg.is_open:
			_fail("ворота с замком не открылись ключом (ключей %d)" % Game.keys)
		else:
			print("ключ: ворота с замком открылись, ключей осталось %d" % Game.keys)

	# плита открывает ворота, пока на ней стоит (уровень 4 — «Подземный склад»)
	main._start_level(3)
	await _wait(4)
	level = main.level
	var plate := _find_plate(level)
	if plate == null:
		_fail("на уровне 4 нет нажимной плиты")
	else:
		var pg := _find_gate(level, plate.channel)
		if pg == null:
			_fail("у плиты нет ворот канала %s" % plate.channel)
		else:
			if pg.is_open:
				_fail("ворота плиты открыты до нажатия")
			level.player.global_position = plate.global_position + Vector2(0, -2)
			await _wait(30)
			if plate.pressed <= 0:
				_fail("плита не нажалась рыцарем")
			if not pg.is_open:
				_fail("ворота канала %s не открылись от плиты" % plate.channel)
			else:
				print("плита: нажалась, ворота канала %s открылись" % plate.channel)
			level.player.global_position = plate.global_position + Vector2(-60, -40)
			await _wait(40)
			if pg.is_open:
				_fail("ворота плиты остались открытыми, когда рыцарь ушёл")
			else:
				print("плита: отпущена, ворота закрылись")

	# босс оживает рядом с рыцарем и открывает ворота после смерти
	main._start_level(9)
	await _wait(4)
	level = main.level
	var boss: Boss = level.boss
	if boss == null:
		_fail("босс не зарегистрирован на уровне (level.boss == null)")
	else:
		level.player.global_position = boss.global_position + Vector2(-60, 0)
		await _wait(30)
		if not boss._started:
			_fail("босс не заметил рыцаря (не начал бой)")
		else:
			print("босс: бой начался")
		boss.take_damage(99, 0)
		await _wait(20)
		if not boss.dead:
			_fail("босс не погиб от удара (hp=%d)" % boss.hp)
		var bg := _find_gate(level, "boss")
		if bg != null and not bg.is_open:
			_fail("ворота принцессы не открылись после смерти босса")
		else:
			print("босс: побеждён, ворота к принцессе открылись")

func _find_heart(level: Level) -> HeartItem:
	for n in level.entities.get_children():
		if n is HeartItem:
			return n
	return null

func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

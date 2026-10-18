extends SceneTree
## Генератор ассетов игры Knight Quest.
## Запуск: godot --headless --path . --script res://tools/gen_sprites.gd
## Рисует всю графику (пиксель-арт) и сохраняет PNG в res://art/.

const ART := "res://art/"

# ---------------------------------------------------------------- палитра
var PAL := {
	"K": Color("#0d0b1a"), # контур / тёмный
	"W": Color("#f7f7fb"), # белый / кость
	"S": Color("#cdd9ea"), # сталь светлая
	"s": Color("#8e9db5"), # сталь средняя
	"E": Color("#e9e0c2"), # доспех светлый
	"e": Color("#b3a882"), # доспех тень
	"d": Color("#3a3f52"), # тёмные сапоги
	"N": Color("#26263a"), # тёмный камень / броня босса
	"n": Color("#45455e"), # камень
	"M": Color("#767690"), # светлый камень
	"T": Color("#3a2b52"), # тёмно-фиолетовый
	"t": Color("#6b4d94"), # фиолетовый
	"R": Color("#c0392b"), # красный
	"r": Color("#7d1f1a"), # тёмно-красный
	"G": Color("#5ec05f"), # зелёный
	"g": Color("#2f7a3a"), # тёмно-зелёный
	"Y": Color("#ffd34e"), # золото
	"y": Color("#b08112"), # тёмное золото
	"O": Color("#f0b060"), # светлое дерево / волосы
	"o": Color("#a9713a"), # дерево
	"B": Color("#6b4a2b"), # кожа
	"b": Color("#3f2a17"), # тёмная кожа
	"P": Color("#ff9ec4"), # розовое платье
	"p": Color("#d2508e"), # насыщенный розовый
	"C": Color("#9fe3ff"), # голубой
	"c": Color("#3a86b0"), # синий
	"F": Color("#ff7a2a"), # огонь
	"f": Color("#ffd76b"), # огонь светлый
	"A": Color("#191926"), # фоновая кладка тёмная
	"a": Color("#2a2a3d"), # фоновая кладка светлее
	"U": Color("#5a4a7a"), # сиреневый камень
	"D": Color("#8b5cf6"), # магический фиолетовый
	"V": Color("#22c55e"), # акцент зелёный
}

var rng := RandomNumberGenerator.new()

# ================================================================ запуск
func _initialize() -> void:
	rng.seed = 20261018
	DirAccess.make_dir_recursive_absolute(ART)
	print("=== Генерация спрайтов ===")
	gen_knight()
	gen_skeleton()
	gen_bat()
	gen_slime()
	gen_gargoyle()
	gen_boss()
	gen_lich()
	gen_princess()
	gen_pickups()
	gen_props()
	gen_fx()
	print("=== Генерация тайлов и фонов ===")
	gen_tiles()
	gen_backgrounds()
	print("=== Готово ===")
	quit()

# ================================================================ утилиты
func new_img(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)

func img_ascii(rows: Array, w: int, h: int, name := "") -> Image:
	var img := new_img(w, h)
	for y in range(min(rows.size(), h)):
		var line := str(rows[y])
		if line.length() > w:
			print("  ! строка %d длиннее %d в %s: %s" % [y, w, name, line])
		for x in range(min(line.length(), w)):
			var ch := line[x]
			if ch == "." or ch == " ":
				continue
			if not PAL.has(ch):
				print("  ! неизвестный символ '%s' в %s" % [ch, name])
				continue
			img.set_pixel(x, y, PAL[ch])
	return img

func blit(dst: Image, src: Image, pos: Vector2i) -> void:
	dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), pos)

func blit_outline(dst: Image, src: Image, pos: Vector2i, col: Color) -> void:
	## обводка вокруг непрозрачных пикселей
	var sz := src.get_size()
	for y in sz.y:
		for x in sz.x:
			if src.get_pixel(x, y).a < 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x < 0 or p.y < 0 or p.x >= sz.x or p.y >= sz.y:
					continue
				if src.get_pixel(p.x, p.y).a < 0.5:
					var target: Vector2i = pos + p
					if target.x >= 0 and target.y >= 0 and target.x < dst.get_width() and target.y < dst.get_height():
						dst.set_pixel(target.x, target.y, col)

func mirror(img: Image) -> Image:
	var out := new_img(img.get_width(), img.get_height())
	for y in img.get_height():
		for x in img.get_width():
			out.set_pixel(img.get_width() - 1 - x, y, img.get_pixel(x, y))
	return out

func save_png(img: Image, name: String) -> void:
	var path := ART + name + ".png"
	var err := img.save_png(path)
	if err != OK:
		print("ERR ", path, " ", err)
	else:
		print("  art/%s.png %dx%d" % [name, img.get_width(), img.get_height()])

func sheet(name: String, frames: Array, fw: int, fh: int) -> void:
	var out := new_img(fw * frames.size(), fh)
	for i in frames.size():
		var f: Image = frames[i]
		if f.get_width() != fw or f.get_height() != fh:
			print("  ! размер кадра %d не %dx%d в %s" % [i, fw, fh, name])
		blit(out, f, Vector2i(fw * i, 0))
	save_png(out, name)

func tint(img: Image, col: Color, amount: float) -> Image:
	var out: Image = img.duplicate()
	for y in out.get_height():
		for x in out.get_width():
			var c: Color = out.get_pixel(x, y)
			if c.a < 0.5:
				continue
			out.set_pixel(x, y, Color(
				lerpf(c.r, col.r, amount),
				lerpf(c.g, col.g, amount),
				lerpf(c.b, col.b, amount),
				c.a))
	return out

func ellipsis(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col)

# ================================================================ рыцарь
const KNIGHT_BODY := [
	"......RR........",
	".....RRRR.......",
	"....SSSSSS......",
	"...SSSSSSSS.....",
	"...SSKKKKSS.....",
	"...SSSSSSSS.....",
	"....SSSSSS......",
	"...BSSSSSSB.....",
	"..bBSSSSSSBb....",
	"..bBSSYYSSBb....",
	"..bBSSSSSSBb....",
	"...BSSSSSSB.....",
	"...BBBBBBBB.....",
	"...bYYYYYYb.....",
]

const KNIGHT_SWORD := [
	"..W..",
	"..W..",
	"..W..",
	"..S..",
	"..S..",
	".YYS.",
	"..y..",
	"..B..",
	"..B..",
]

const KNIGHT_LEGS := {
	"idle": [
		"....EE..EE......",
		"....EE..EE......",
		"....EE..EE......",
		"....EE..EE......",
		"...ddd..ddd.....",
		"...ddd..ddd.....",
	],
	"run1": [
		"...EE....EE.....",
		"...EE....EE.....",
		"..EE......EE....",
		"..EE......EE....",
		".ddd......ddd...",
		".ddd......ddd...",
	],
	"run2": [
		"....EE..EE......",
		"....EE..EE......",
		".....EE.EE......",
		".....dd.dd......",
		"....ddd.ddd.....",
		"....ddd.ddd.....",
	],
	"run3": [
		"....EE..EE......",
		"....EE..EE......",
		"....EE..EE......",
		"....dd..dd......",
		"...ddd..ddd.....",
		"...ddd..ddd.....",
	],
	"jump": [
		"...EE....EE.....",
		"..EEE....EEE....",
		"..EE......EE....",
		"..dd......dd....",
		"................",
		"................",
	],
	"fall": [
		"..EE......EE....",
		"..EE......EE....",
		".EE........EE...",
		".dd........dd...",
		"ddd........ddd..",
		"ddd........ddd..",
	],
}

func knight_frame(legs_name: String, sword := true) -> Image:
	var rows := [] as Array
	rows.append_array(KNIGHT_BODY)
	rows.append_array(KNIGHT_LEGS[legs_name])
	var img := img_ascii(rows, 16, 20, "knight_" + legs_name)
	if sword:
		blit(img, img_ascii(KNIGHT_SWORD, 5, 9, "sword"), Vector2i(11, 6))
	return img

func gen_knight() -> void:
	var frames := [
		knight_frame("idle"),
		knight_frame("run1"),
		knight_frame("run2"),
		knight_frame("run3"),
		knight_frame("idle"),
		knight_frame("jump"),
		knight_frame("fall"),
	]
	sheet("knight", frames, 16, 20)
	# состояния: 7 idle / 8 hurt / 9 dead
	var hurt := tint(knight_frame("jump", false), Color("#ff5a5a"), 0.55)
	var dead := tint(knight_frame("fall", false), Color("#8a8a8a"), 0.6)
	save_png(hurt, "knight_hurt")
	save_png(dead, "knight_dead")

# ================================================================ скелет
const SKELETON_BODY := [
	"....WWWWWW......",
	"...WWWWWWWW.....",
	"...WKKWWKKW.....",
	"...WKKWWKKW.....",
	"...WWWWWWWW.....",
	"....WKWKWK......",
	"....WWWWWW......",
	".....WWWW.......",
	"..WWWWWWWWWW....",
	"..W.WWWWWW.W....",
	"..WWWWWWWWWW....",
	"....WWWWWW......",
	"....WKWKWK......",
	"...WWWWWWWW.....",
]

const SKELETON_LEGS := {
	"walk1": [
		"...WW....WW.....",
		"...WW....WW.....",
		"..WW......WW....",
		"..WW......WW....",
		"..WW......WW....",
		".WWW......WWW...",
	],
	"walk2": [
		"....WW..WW......",
		"....WW..WW......",
		"....WW..WW......",
		".....WW.WW......",
		".....WWWWW......",
		"....WWWWWWW.....",
	],
}

func skeleton_frame(legs: String) -> Image:
	var rows := [] as Array
	rows.append_array(SKELETON_BODY)
	rows.append_array(SKELETON_LEGS[legs])
	return img_ascii(rows, 16, 20, "skeleton_" + legs)

func gen_skeleton() -> void:
	sheet("skeleton", [
		skeleton_frame("walk1"), skeleton_frame("walk2"),
		skeleton_frame("walk1"), skeleton_frame("walk2"),
	], 16, 20)

# ================================================================ летучая мышь
const BAT_WINGS_UP := [
	"..TT........TT..",
	".TTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTT",
	"..TTTTTTTTTTTT..",
]
const BAT_WINGS_MID := [
	"................",
	"..TT........TT..",
	".TTTTTTTTTTTTTTT",
	"TTTTTTTTTTTTTTTT",
]
const BAT_BODY := [
	"....TTTTTTTT....",
	"....TKKTTKKT....",
	".....TTTTTT.....",
	"......KTTK......",
]

func bat_frame(wing: Array) -> Image:
	var rows := [] as Array
	rows.append_array(wing)
	rows.append_array(BAT_BODY)
	return img_ascii(rows, 16, 8, "bat")

func gen_bat() -> void:
	var up := bat_frame(BAT_WINGS_UP)
	var mid := bat_frame(BAT_WINGS_MID)
	var down := bat_frame(BAT_WINGS_MID)
	sheet("bat", [up, mid, down, mid], 16, 8)

# ================================================================ слизень
func gen_slime() -> void:
	var tall := img_ascii([
		"......GGGG......",
		"....GGGGGGGG....",
		"...GGgGGGGgGG...",
		"...GGKGGGGKGG...",
		"..gGGGGGGGGGGg..",
		"..gGGGGGGGGGGg..",
		".ggGGGGGGGGGGgg.",
		".gggGGGGGGGGggg.",
		".ggggGGGGGGgggg.",
		".gggggggggggggg.",
	], 16, 10, "slime")
	var squat := img_ascii([
		"................",
		"................",
		".....GGGGGG.....",
		"...GGGGGGGGGG...",
		"..GGgGGGGGGgGG..",
		"..GGKGGGGGGKGG..",
		".ggGGGGGGGGGGgg.",
		".gggGGGGGGGGggg.",
		".gggggGGGGggggg.",
		".gggggggggggggg.",
	], 16, 10, "slime_squat")
	var jump := img_ascii([
		"......GGGG......",
		"....GGGGGGGG....",
		"...GGgGGGGgGG...",
		"...GGKGGGGKGG...",
		"..gGGGGGGGGGGg..",
		"..gGGGGGGGGGGg..",
		"..ggGGGGGGGGgg..",
		"...gggggggggg...",
		"................",
		"................",
	], 16, 10, "slime_jump")
	sheet("slime", [tall, squat, jump, squat], 16, 10)

# ================================================================ гаргулья-турель
func gen_gargoyle() -> void:
	var idle := img_ascii([
		"...nnnnnnnnnn...",
		"..nMMMMMMMMMMn..",
		"..nMMnnnnnnMMn..",
		"..nMKKnnnnKKMn..",
		"..nMKKnnnnKKMn..",
		"..nMMnnnnnnMMn..",
		"..nMMMnnnnMMMn..",
		"...nMMMMMMMMn...",
		"..nnnMMMMMMnnn..",
		"..nMMMMMMMMMMn..",
		"...nMMMMMMMMn...",
		"....nMMMMMMn....",
		"....nMMMMMMn....",
		"....nMMMMMMn....",
		"...nnMMMMMMnn...",
		"..nnMMMMMMMMnn..",
		".nnMMMMMMMMMMnn.",
		"nnMMMMMMMMMMMMnn",
		"nnMMMMMMMMMMMMnn",
		"nnnnnnnnnnnnnnnn",
	], 16, 20, "gargoyle")
	var shoot := img_ascii([
		"...nnnnnnnnnn...",
		"..nMMMMMMMMMMn..",
		"..nMMnnnnnnMMn..",
		"..nMKKnnnnKKMn..",
		"..nMKKnnnnKKMn..",
		"..nMMnnnnnnMMn..",
		"..nMMMFFFFMMMn..",
		"...nMFffffFMn...",
		"..nnnMMMMMMnnn..",
		"..nMMMMMMMMMMn..",
		"...nMMMMMMMMn...",
		"....nMMMMMMn....",
		"....nMMMMMMn....",
		"....nMMMMMMn....",
		"...nnMMMMMMnn...",
		"..nnMMMMMMMMnn..",
		".nnMMMMMMMMMMnn.",
		"nnMMMMMMMMMMMMnn",
		"nnMMMMMMMMMMMMnn",
		"nnnnnnnnnnnnnnnn",
	], 16, 20, "gargoyle")
	var cracked := tint(idle, Color("#ff8080"), 0.5)
	sheet("gargoyle", [idle, shoot, cracked, shoot], 16, 20)

# ================================================================ босс: чёрный рыцарь
const BOSS_BODY := [
	".....TTTTTTTT.......",
	"....TKKKKKKKKT......",
	"...TKKKKKKKKKKT.....",
	"...TKKRRKKRRKKT.....",
	"...TKKKKKKKKKKT.....",
	"....TKKKKKKKKT......",
	"...NTTTTTTTTTTN.....",
	"..NTTTTTTTTTTTTN....",
	"..NTTTTTTTTTTTTN....",
	"..NTTTRTTTTTTTTN....",
	"..NTTTTTTTTTTTTN....",
	"..NTTTTTTTTTTTTN....",
	"..NTTTTTTTTTTTTN....",
	"...NTTTTTTTTTTN.....",
	"...NNNNNNNNNNNN.....",
	"....TTTTTTTTTT......",
]

const BOSS_LEGS := {
	"idle": [
		"....TTTT..TTTT......",
		"...TTTTT..TTTTT.....",
		"...NNNNN..NNNNN.....",
		"...NNNNN..NNNNN.....",
		"..NNNNNN..NNNNNN....",
		"..NNNNNN..NNNNNN....",
	],
	"walk1": [
		"...TTTT....TTTT.....",
		"..TTTTT....TTTTT....",
		"..NNNNN....NNNNN....",
		"..NNNNN....NNNNN....",
		".NNNNNN....NNNNNN...",
		".NNNNNN....NNNNNN...",
	],
	"walk2": [
		"....TTTT..TTTT......",
		"....TTTT..TTTT......",
		"....NNNN..NNNN......",
		"...NNNNN..NNNNN.....",
		"...NNNNN..NNNNN.....",
		"...NNNNN..NNNNN.....",
	],
	"slam": [
		"...TTTTTTTTTT.......",
		"..TTTTTTTTTTTT......",
		"..NNNNNNNNNNNN......",
		"..NNNNNNNNNNNN......",
		".NNNNNNNNNNNNNN.....",
		".NNNNNNNNNNNNNN.....",
	],
}

func boss_frame(legs: String, tint_col := Color(0, 0, 0, 0)) -> Image:
	var rows := [] as Array
	rows.append_array(BOSS_BODY)
	rows.append_array(BOSS_LEGS[legs])
	var img := img_ascii(rows, 20, 22, "boss_" + legs)
	# большой меч справа
	var sword := img_ascii([
		"...W...",
		"...W...",
		"...S...",
		"...S...",
		"...S...",
		"..YYY..",
		"...y...",
		"...B...",
		"...B...",
	], 7, 9, "boss_sword")
	blit(img, sword, Vector2i(13, 7))
	if tint_col.a > 0.0:
		img = tint(img, tint_col, 0.5)
	return img

func gen_boss() -> void:
	sheet("boss", [
		boss_frame("idle"),
		boss_frame("walk1"),
		boss_frame("walk2"),
		boss_frame("slam"),
	], 20, 22)

# ================================================================ босс 2: король-лич
const LICH_BODY := [
	"......Y.Y.Y.........",
	".....YYYYYYY........",
	"....UUUUUUUUU.......",
	"...UUUUUUUUUUU......",
	"...UUWWWWWWWUU......",
	"...UUWVWWWWVWUU.....",
	"...UUWWWWWWWUU......",
	"....UWWKKKWWU.......",
	"....UUUUUUUUU.......",
	"...UUUUUUUUUUU......",
	"..UUtttttttttUU.....",
	"..UUtttDDDtttUU.....",
	"..UUtttttttttUU.....",
	"...UUUUUUUUUUU......",
	"...UUUUUUUUUUU......",
	"....UUUUUUUUU.......",
]

const LICH_LEGS := {
	"idle": [
		"....UUUU..UUUU......",
		"...UUUUU..UUUUU.....",
		"...ttttt..ttttt.....",
		"...ttttt..ttttt.....",
		"..tttttt..tttttt....",
		"..tttttt..tttttt....",
	],
	"walk1": [
		"...UUUU....UUUU.....",
		"..UUUUU....UUUUU....",
		"..ttttt....ttttt....",
		"..ttttt....ttttt....",
		".tttttt....tttttt...",
		".tttttt....tttttt...",
	],
	"walk2": [
		"....UUUU..UUUU......",
		"....UUUU..UUUU......",
		"....tttt..tttt......",
		"...ttttt..ttttt.....",
		"...ttttt..ttttt.....",
		"...ttttt..ttttt.....",
	],
	"slam": [
		"...UUUUUUUUUU.......",
		"..UUUUUUUUUUUU......",
		"..tttttttttttt......",
		"..tttttttttttt......",
		".tttttttttttttt.....",
		".tttttttttttttt.....",
	],
}

func lich_frame(legs: String) -> Image:
	var rows := [] as Array
	rows.append_array(LICH_BODY)
	rows.append_array(LICH_LEGS[legs])
	var img := img_ascii(rows, 20, 22, "lich_" + legs)
	# посох с магическим кристаллом справа
	var staff := img_ascii([
		"...o...",
		"...o...",
		"...o...",
		"...o...",
		"...o...",
		"..VoV..",
		"..VDV..",
		"...V...",
		"...o...",
		"...o...",
	], 7, 10, "lich_staff")
	blit(img, staff, Vector2i(13, 6))
	return img

func gen_lich() -> void:
	sheet("boss_lich", [
		lich_frame("idle"),
		lich_frame("walk1"),
		lich_frame("walk2"),
		lich_frame("slam"),
	], 20, 22)

# ================================================================ принцесса
func gen_princess() -> void:
	var idle := img_ascii([
		"......Y.Y.......",
		"......YYY.......",
		".....OOOOO......",
		"....OOOOOOO.....",
		"....OWWWWWO.....",
		"....OWKWKWO.....",
		"....OWWWWWO.....",
		"....OWWRWWO.....",
		"....OOOOOOO.....",
		"...PPPPPPPPP....",
		"...PPPPWPPPP....",
		"...PPPPPPPPP....",
		"..PPPPPPPPPPP...",
		"..PPPPPPPPPPP...",
		".PPPPPPPPPPPPP..",
		".PPPPPPPPPPPPP..",
		"PPPPPPPPPPPPPPP.",
		".ppppppppppppp..",
		"..ppppppppppp...",
		"...ppppppppp....",
	], 16, 20, "princess")
	var blink := img_ascii([
		"......Y.Y.......",
		"......YYY.......",
		".....OOOOO......",
		"....OOOOOOO.....",
		"....OWWWWWO.....",
		"....OWKKKKO.....",
		"....OWWWWWO.....",
		"....OWWRWWO.....",
		"....OOOOOOO.....",
		"...PPPPPPPPP....",
		"...PPPPWPPPP....",
		"...PPPPPPPPP....",
		"..PPPPPPPPPPP...",
		"..PPPPPPPPPPP...",
		".PPPPPPPPPPPPP..",
		".PPPPPPPPPPPPP..",
		"PPPPPPPPPPPPPPP.",
		".ppppppppppppp..",
		"..ppppppppppp...",
		"...ppppppppp....",
	], 16, 20, "princess")
	var saved := img_ascii([
		"......Y.Y.......",
		"..O...YYY...O...",
		".OOOOOOOOOOOOO..",
		".O.OOOOOOO.O.O..",
		"....OWWWWWO.....",
		"....OWKWKWO.....",
		"....OWWWWWO.....",
		"....OWWRWWO.....",
		"....OOOOOOO.....",
		"...PPPPPPPPP....",
		"...PPPPWPPPP....",
		"..PPPPPPPPPPP...",
		"..PPPPPPPPPPP...",
		".PPPPPPPPPPPPP..",
		".PPPPPPPPPPPPP..",
		"PPPPPPPPPPPPPPP.",
		"PPPPPPPPPPPPPPP.",
		".ppppppppppppp..",
		"..ppppppppppp...",
		"...ppppppppp....",
	], 16, 20, "princess")
	sheet("princess", [idle, blink, saved], 16, 20)

# ================================================================ монеты, ключ, сердце
func gen_pickups() -> void:
	var coin_frames := []
	for i in 6:
		var img := new_img(8, 8)
		var widths := [7.0, 5.0, 3.0, 1.4, 3.0, 5.0]
		var w: float = widths[i]
		var rx: float = w * 0.5
		for y in 8:
			var dy: float = (y + 0.5 - 4.0) / 3.4
			if absf(dy) > 1.0 or rx <= 0.2:
				continue
			for x in 8:
				var dx: float = absf(x + 0.5 - 4.0)
				var rel: float = dx / rx
				if rel > 1.0:
					continue
				var col: Color = PAL["Y"]
				if rel > 0.68 or absf(dy) > 0.82:
					col = PAL["y"]
				img.set_pixel(x, y, col)
		# блик
		if i <= 2:
			for k in (3 - i):
				var pxx := 3 - k
				if img.get_pixel(pxx, 3).a > 0.5:
					img.set_pixel(pxx, 3, PAL["W"])
				if img.get_pixel(pxx, 2).a > 0.5:
					img.set_pixel(pxx, 2, Color("#fff3c4"))
		coin_frames.append(img)
	sheet("coin", coin_frames, 8, 8)

	var key := img_ascii([
		"..YYYY....",
		".YWWWWY...",
		".YWKKWY...",
		".YWWWWY...",
		"..YYYY....",
		"...YY.....",
		"...YY.....",
		"...YY.....",
		"...YYY....",
		"...YY.....",
		"...YYYYY..",
		"...YY.....",
	], 10, 12, "key")
	var key2 := key.duplicate()
	for p in [Vector2i(3, 1), Vector2i(4, 1), Vector2i(3, 2), Vector2i(8, 3), Vector2i(9, 0), Vector2i(0, 4)]:
		key2.set_pixel(p.x, p.y, PAL["W"])
	sheet("key", [key, key2], 10, 12)

	var heart := img_ascii([
		"..RR.RR...",
		".RRRRRRR..",
		"RRRRRRRRR.",
		"RRWWRRRRR.",
		".RRRRRRR..",
		"..RRRRR...",
		"...RRR....",
		"....R.....",
	], 10, 8, "heart")
	sheet("heart", [heart], 10, 8)

# ================================================================ объекты уровня
func gen_props() -> void:
	# Ворота (16x48), закрытая решётка
	make_gate("gate", false)
	make_gate("gate_locked", true)

	# Рычаг 16x16, 2 кадра
	var lever_off := img_ascii([
		"................",
		"..............S.",
		".............SS.",
		"............SS..",
		"...........SS...",
		"................",
		"................",
		"................",
		"....nnnnnnnn....",
		"...nMMMMMMMn....",
		"...nMMMMMMMn....",
		"....nnnnnnnn....",
		"....nnnnnnnn....",
		"...nnnnnnnnnn...",
		"...nnnnnnnnnn...",
		"...nnnnnnnnnn...",
	], 16, 16, "lever")
	var lever_on := img_ascii([
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"..S.............",
		".SS.............",
		"....nnnnnnnn....",
		".SSnMMMMMMMn....",
		"SS.nMMMMMMMn....",
		"....nnnnnnnn....",
		"....nnnnnnnn....",
		"...nnnnnnnnnn...",
		"...nnnnnnnnnn...",
		"...nnnnnnnnnn...",
	], 16, 16, "lever")
	sheet("lever", [lever_off, lever_on], 16, 16)

	# Нажимная плита 16x8, 2 кадра
	var plate_up := img_ascii([
		"..MMMMMMMMMMMM..",
		".MMMMMMMMMMMMMM.",
		"nMMMMMMMMMMMMMMn",
		"nnnnnnnnnnnnnnnn",
		"................",
		"................",
		"................",
		"................",
	], 16, 8, "plate")
	var plate_down := img_ascii([
		"................",
		"................",
		"..MMMMMMMMMMMM..",
		".MMMMMMMMMMMMMM.",
		"nMMMMMMMMMMMMMMn",
		"nnnnnnnnnnnnnnnn",
		"................",
		"................",
	], 16, 8, "plate")
	sheet("plate", [plate_up, plate_down], 16, 8)

	# Ящик 16x16 (доски с косыми перекладинами)
	var crate := new_img(16, 16)
	for y in 16:
		for x in 16:
			var edge := x == 0 or y == 0 or x == 15 or y == 15
			var brace := absi(x - y) <= 1 or absi((15 - x) - y) <= 1
			if edge:
				crate.set_pixel(x, y, PAL["b"])
			elif brace:
				crate.set_pixel(x, y, PAL["o"].lerp(PAL["O"], 0.35))
			else:
				crate.set_pixel(x, y, PAL["o"])
	for y in 16:
		if y % 5 == 0 or y % 5 == 4:
			for x in range(1, 15):
				crate.set_pixel(x, y, PAL["b"].lerp(PAL["o"], 0.45))
	for y in 16:
		crate.set_pixel(1, y, PAL["O"] if y > 0 and y < 15 else PAL["b"])
		crate.set_pixel(2, y, PAL["O"] if y > 0 and y < 15 else PAL["b"])
	sheet("crate", [crate], 16, 16)
	# ящик из камня (для тяжёлых плит) — светлее
	sheet("crate_stone", [tint(crate, Color("#9aa4b8"), 0.65)], 16, 16)

	# Чекпоинт-флаг 16x32, 2 кадра
	var cp_off := img_ascii([
		"................",
		".........nnn....",
		"........nMMMn...",
		"........nMMn....",
		"........nMMMn...",
		".........nnn....",
		"................",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
	], 16, 32, "checkpoint")
	var cp_on := img_ascii([
		"................",
		"....RRRRRRR.....",
		"...RRRRRRRRR....",
		"...RRWWWRRRR....",
		"...RRRRRRRRR....",
		"....RRRRRRR.....",
		"................",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
		"..n.............",
	], 16, 32, "checkpoint")
	sheet("checkpoint", [cp_off, cp_on], 16, 32)

	# Циркулярная пила
	var saw := new_img(16, 16)
	for y in 16:
		for x in 16:
			var dx := x + 0.5 - 8.0
			var dy := y + 0.5 - 8.0
			var d := sqrt(dx * dx + dy * dy)
			if d <= 5.0:
				saw.set_pixel(x, y, PAL["M"])
			elif d <= 7.5:
				var ang := atan2(dy, dx)
				if fmod(absf(ang) * 4.0 / PI, 1.0) < 0.5:
					saw.set_pixel(x, y, PAL["S"])
			if d <= 1.6:
				saw.set_pixel(x, y, PAL["n"])
	sheet("saw", [saw], 16, 16)

	# Факел 16x16, 3 кадра
	var torch_base := img_ascii([
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"......oo........",
		"......oo........",
		"......oo........",
		"......oo........",
		"......oo........",
		"......bb........",
		"......bb........",
		"......bb........",
		"................",
	], 16, 16, "torch")
	var flames := [
		img_ascii([
			"................",
			"................",
			"................",
			"................",
			"......f.........",
			".....fFf........",
			".....FFF........",
			".....fFf........",
		], 16, 16, "torch"),
		img_ascii([
			"................",
			"................",
			"................",
			".......F........",
			"......fFf.......",
			".....fFFF.......",
			".....FFFFf......",
			"......FFf.......",
		], 16, 16, "torch"),
		img_ascii([
			"................",
			"................",
			"......f.........",
			".....fFf........",
			".....FFf........",
			".....fFf........",
			"......FF........",
			"......f.........",
		], 16, 16, "torch"),
	]
	var torch_frames := []
	for f in flames:
		var img := torch_base.duplicate()
		blit(img, f, Vector2i.ZERO)
		torch_frames.append(img)
	sheet("torch", torch_frames, 16, 16)

	# Табличка с подсказкой
	var sign := img_ascii([
		"................",
		"................",
		".oooooooooooo...",
		".oOOOOOOOOOOo...",
		".oOKKKKKKKOOo...",
		".oOKOOOOOKOOo...",
		".oOKKKKKKKOOo...",
		".oOKKKOKKKOOo...",
		".oOOOOOOOOOOo...",
		".oooooooooooo...",
		".....oo.........",
		".....oo.........",
		".....oo.........",
		".....oo.........",
		"....oooo........",
		"................",
	], 16, 16, "sign")
	sheet("sign", [sign], 16, 16)

	# Камень-снаряд
	var rock := new_img(8, 8)
	ellipsis(rock, 4.0, 4.0, 3.4, 3.4, PAL["n"])
	ellipsis(rock, 3.4, 3.2, 1.8, 1.6, PAL["M"])
	sheet("rock", [rock], 8, 8)

	# Сундук 16x16, 2 кадра
	var chest_closed := img_ascii([
		"................",
		"....oooooooo....",
		"..ooYYYYYYYYoo..",
		".oYYYYYYYYYYYYo.",
		".oYyYYYYYYYYyYo.",
		".oYYYYYyYYYYYYo.",
		".oYYYYYyYYYYYYo.",
		".bYYYYYYYYYYYYb.",
		".bYYYYYyYYYYYYb.",
		".bYYYYYyYYYYYYb.",
		".bYYYYYYYYYYYYb.",
		".bbbbbbbbbbbbbb.",
		"................",
		"................",
		"................",
		"................",
	], 16, 16, "chest")
	var chest_open := img_ascii([
		"................",
		"....oooooooo....",
		"..oo........oo..",
		"..ooYYYYYYYYoo..",
		"..oYyYYYYYYyYo..",
		"..oYYYYYYYYYYo..",
		"...YYYYYYYYYY...",
		".bYYYYYYYYYYYYb.",
		".bYYYYYWWYYYYYb.",
		".bYYYYWWWWYYYYb.",
		".bYYYYYWWYYYYYb.",
		".bbbbbbbbbbbbbb.",
		"................",
		"................",
		"................",
		"................",
	], 16, 16, "chest")
	sheet("chest", [chest_closed, chest_open], 16, 16)

	# Дверь-выход 24x32, 2 кадра
	var door := img_ascii([
		"......nnnnnnnnnn........",
		"....nnMMMMMMMMMMnn......",
		"...nMMMMMMMMMMMMMMn.....",
		"..nMMnnnnnnnnnnnnMMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBoooooooooBBnMn....",
		"..nMnBoOOOOOOOoBBnMn....",
		"..nMnBoOoooooOoBBnMn....",
		"..nMnBoOooooOOoBBnMn....",
		"..nMnBoOoooooOoBBnMn....",
		"..nMnBoOOOOOOOoBBnMn....",
		"..nMnBoooooooooBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBYBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMnBBBBBBBBBBBBnMn....",
		"..nMMMMMMMMMMMMMMMn.....",
		"...nMMMMMMMMMMMMMn......",
		"....nnMMMMMMMMMnn.......",
		"......nnnnnnnn..........",
		"........................",
	], 24, 32, "exit_door")
	var door_open := door.duplicate()
	for y in range(4, 28):
		for x in range(5, 18):
			var c := door.get_pixel(x, y)
			if c.a > 0.5:
				door_open.set_pixel(x, y, PAL["f"].lerp(PAL["Y"], 0.35))
	sheet("exit_door", [door, door_open], 24, 32)

	# Куст
	var bush := img_ascii([
		"................",
		"................",
		"................",
		"................",
		"......gg........",
		"....gGGGGg......",
		"...gGGGGGGg.....",
		"..gGGGGGGGGg....",
		"..gGGgGGgGGg....",
		".gGGGGGGGGGGg...",
		".gGGGGGGGGGGg...",
		".ggGGGGGGGGgg...",
		"..gggggggggg....",
		"................",
		"................",
		"................",
	], 16, 16, "bush")
	sheet("bush", [bush], 16, 16)

	# Знамя
	var banner := img_ascii([
		"oooooooooooooooo",
		"nMMMMMMMMMMMMMMn",
		"..RRRRRRRRRRRR..",
		"..RYYYYYYYYYYR..",
		"..RYyYYYYYYyYR..",
		"..RYYYWWWWYYYR..",
		"..RYYWKKKKWYYR..",
		"..RYYYWWWWYYYR..",
		"..RYYYYYYYYYYR..",
		"..RYYYYYYYYYYR..",
		"..RRRRRRRRRRRR..",
		"...rRRRRRRRRr...",
		"...rRRRRRRRRr...",
		"....rRRRRRRr....",
		".....rRRRRr.....",
		"......rrrr......",
	], 16, 16, "banner")
	sheet("banner", [banner], 16, 16)

func make_gate(name: String, locked: bool) -> void:
	var p := PAL
	var img := new_img(16, 48)
	# рамка
	for y in 48:
		img.set_pixel(0, y, p["N"])
		img.set_pixel(15, y, p["N"])
	# вертикальные прутья
	for x in range(2, 14):
		for y in 48:
			if x % 4 == 2:
				img.set_pixel(x, y, p["M"])
			elif x % 4 == 3:
				img.set_pixel(x, y, p["S"])
	# поперечины
	for y in [6, 7, 24, 25, 42, 43]:
		for x in range(1, 15):
			img.set_pixel(x, y, p["S"] if y % 2 == 0 else p["n"])
	if locked:
		# золотая окантовка и замок
		for y in 48:
			img.set_pixel(1, y, p["y"])
			img.set_pixel(14, y, p["y"])
		for y in range(20, 30):
			for x in range(4, 12):
				img.set_pixel(x, y, p["Y"] if y in [20, 29] or x in [4, 11] else p["y"])
		img.set_pixel(7, 24, p["K"])
		img.set_pixel(8, 24, p["K"])
		img.set_pixel(7, 25, p["K"])
		img.set_pixel(8, 25, p["K"])
	save_png(img, name)

# ================================================================ эффекты
func gen_fx() -> void:
	var frames := []
	for i in 3:
		var img := new_img(24, 24)
		var radius := 15.0
		var thick := 3.0 - i * 0.6
		var alpha := 1.0 - i * 0.25
		var col_a := Color("#ffffff")
		var col_b := Color("#ffe08a")
		for a in range(-75, 76, 2):
			var ang := deg_to_rad(a)
			for t in range(int(thick * 3.0)):
				var rr := radius - t * 0.45
				var x := int(round(9.0 + cos(ang) * rr))
				var y := int(round(12.0 + sin(ang) * rr))
				if x < 0 or y < 0 or x >= 24 or y >= 24:
					continue
				var f := float(t) / maxf(thick * 3.0, 1.0)
				var c := col_a.lerp(col_b, f)
				c.a = alpha * (1.0 - f * 0.7)
				img.set_pixel(x, y, c)
		frames.append(img)
	sheet("slash", frames, 24, 24)

	# искра монеты / звёздочка
	var spark := img_ascii([
		"....W....",
		"....W....",
		"....W....",
		"W...W...W",
		".WWWWWWW.",
		"....W....",
		"....W....",
		"....W....",
		"....W....",
	], 9, 9, "spark")
	sheet("spark", [spark], 9, 9)

# ================================================================ тайлы 16x16
const TILE := 16

func gen_tiles() -> void:
	var tiles := []
	# 0 dirt, 1 dirt_top
	tiles.append(tile_dirt(false))
	tiles.append(tile_dirt(true))
	# 2 stone, 3 stone_top
	tiles.append(tile_brick(PAL["n"], PAL["N"], PAL["M"]))
	tiles.append(tile_brick(PAL["n"], PAL["N"], PAL["M"], true))
	# 4 castle, 5 castle_top
	tiles.append(tile_brick(PAL["T"], Color("#211a30"), PAL["t"]))
	tiles.append(tile_brick(PAL["T"], Color("#211a30"), PAL["t"], true))
	# 6 metal, 7 metal_top
	tiles.append(tile_metal(false))
	tiles.append(tile_metal(true))
	# 8 wood, 9 wood_top
	tiles.append(tile_wood(false))
	tiles.append(tile_wood(true))
	# 10 spikes up, 11 spikes down
	tiles.append(tile_spikes(false))
	tiles.append(tile_spikes(true))
	# 12 lava
	tiles.append(tile_lava())
	# 13 bg brick, 14 bg stone, 15 bg castle
	tiles.append(tile_bg_brick(PAL["A"], PAL["a"]))
	tiles.append(tile_bg_brick(Color("#141422"), Color("#20203a")))
	tiles.append(tile_bg_brick(Color("#1d1430"), Color("#2c2044")))

	var atlas := new_img(8 * TILE, 2 * TILE)
	for i in tiles.size():
		blit(atlas, tiles[i], Vector2i((i % 8) * TILE, (i / 8) * TILE))
	save_png(atlas, "tiles")

func tile_dirt(grass: bool) -> Image:
	var img := new_img(TILE, TILE)
	img.fill(PAL["b"].lerp(PAL["B"], 0.25))
	for i in 70:
		var x := rng.randi_range(0, TILE - 1)
		var y := rng.randi_range(0, TILE - 1)
		var c: Color = PAL["B"] if rng.randf() < 0.6 else PAL["b"]
		img.set_pixel(x, y, c)
	for x in TILE:
		img.set_pixel(x, TILE - 1, PAL["b"].darkened(0.35))
	if grass:
		for x in TILE:
			var h := 5 + int(round(sin(x * 0.9) * 1.2))
			for y in h:
				var c: Color = PAL["G"] if y > 1 else PAL["g"]
				img.set_pixel(x, y, c)
			img.set_pixel(x, h, PAL["g"].darkened(0.2))
	return img

func tile_brick(base: Color, mortar: Color, hi: Color, top := false) -> Image:
	var img := new_img(TILE, TILE)
	img.fill(mortar)
	var bh := 4
	var bw := 8
	for row in 4:
		var y0 := row * bh
		var offset := 0 if row % 2 == 0 else 4
		for bx in range(-1, 3):
			var x0 := bx * bw + offset
			for y in range(y0 + 1, min(y0 + bh, TILE)):
				for x in range(max(x0 + 1, 0), min(x0 + bw, TILE)):
					var c := base
					if y == y0 + 1 and x > x0:
						c = base.lerp(hi, 0.45)
					elif y == y0 + bh - 1:
						c = base.darkened(0.25)
					img.set_pixel(x, y, c)
				if x0 + 1 >= 0 and x0 + 1 < TILE:
					img.set_pixel(x0 + 1, y0 + 1, base.lerp(hi, 0.3))
	if top:
		for x in TILE:
			img.set_pixel(x, 0, hi)
			img.set_pixel(x, 1, base.lerp(hi, 0.5))
	return img

func tile_metal(top: bool) -> Image:
	var img := new_img(TILE, TILE)
	for y in TILE:
		var t := float(y) / TILE
		var c: Color = PAL["n"].lerp(PAL["M"], 0.35 + 0.35 * sin(t * PI))
		for x in TILE:
			img.set_pixel(x, y, c)
	for pos in [Vector2i(2, 2), Vector2i(13, 2), Vector2i(2, 13), Vector2i(13, 13)]:
		img.set_pixel(pos.x, pos.y, PAL["S"])
		img.set_pixel(pos.x - 1, pos.y, PAL["N"])
		img.set_pixel(pos.x, pos.y - 1, PAL["N"])
	for x in TILE:
		img.set_pixel(x, 0, PAL["N"] if not top else PAL["S"])
		img.set_pixel(x, TILE - 1, PAL["N"])
	return img

func tile_wood(top: bool) -> Image:
	var img := new_img(TILE, TILE)
	img.fill(PAL["o"])
	for plank in 3:
		var y0 := plank * 5 + 1
		for y in range(y0, min(y0 + 5, TILE)):
			for x in TILE:
				if y == y0:
					img.set_pixel(x, y, PAL["O"])
				elif y == y0 + 4:
					img.set_pixel(x, y, PAL["b"])
				else:
					var c: Color = PAL["o"]
					if (x + plank * 5) % 7 == 0:
						c = PAL["b"].lerp(PAL["o"], 0.5)
					img.set_pixel(x, y, c)
	if top:
		for x in TILE:
			img.set_pixel(x, 0, PAL["O"])
			img.set_pixel(x, 1, PAL["o"].lerp(PAL["O"], 0.6))
	return img

func tile_spikes(flipped: bool) -> Image:
	var img := new_img(TILE, TILE)
	for x in TILE:
		for y in TILE:
			var yy := (TILE - 1 - y) if flipped else y
			var local := x % 4
			var h := absf(1.5 - float(local % 4))
			var tip := int(round(3.0 - h))
			if yy >= TILE - 4 - tip:
				var shade: Color = PAL["W"] if local == 1 or local == 2 else PAL["M"]
				if yy >= TILE - 2:
					shade = PAL["n"]
				img.set_pixel(x, y, shade)
	# основание
	for x in TILE:
		img.set_pixel(x, TILE - 1 if not flipped else 0, PAL["N"])
		img.set_pixel(x, TILE - 2 if not flipped else 1, PAL["n"])
	return img

func tile_lava() -> Image:
	var img := new_img(TILE, TILE)
	for y in TILE:
		for x in TILE:
			var t := float(y) / TILE
			var c: Color = PAL["F"].lerp(PAL["r"], t * 0.9)
			if y < 2:
				c = PAL["f"]
			elif y < 4:
				c = PAL["f"].lerp(PAL["F"], float(y - 2) / 2.0)
			img.set_pixel(x, y, c)
	for i in 18:
		var x := rng.randi_range(0, TILE - 1)
		var y := rng.randi_range(6, TILE - 1)
		img.set_pixel(x, y, PAL["f"] if rng.randf() < 0.5 else PAL["r"])
	return img

func tile_bg_brick(base: Color, hi: Color) -> Image:
	var img := new_img(TILE, TILE)
	img.fill(base)
	var bh := 8
	for row in 2:
		var y0 := row * bh
		var offset := 0 if row % 2 == 0 else 4
		for y in range(y0, y0 + bh):
			for x in TILE:
				var bx := (x + offset) % 8
				var c := base
				if bx == 0 or y == y0:
					c = hi
				img.set_pixel(x, y, c)
	return img

# ================================================================ фоны
func gen_backgrounds() -> void:
	# небо: градиент
	var sky := new_img(320, 180)
	for y in 180:
		var t := float(y) / 179.0
		var c := Color("#1b2b4b").lerp(Color("#f0a868"), pow(t, 1.6))
		if t < 0.15:
			c = Color("#0f1b33").lerp(Color("#1b2b4b"), t / 0.15)
		for x in 320:
			sky.set_pixel(x, y, c)
	save_png(sky, "bg_sky")

	# облака (бесшовные по горизонтали)
	var clouds := new_img(480, 180)
	for i in 16:
		var cx := float(i) * 30.0
		var cy := 20.0 + 45.0 * absf(sin(i * 1.7))
		var rx := 22.0 + 12.0 * absf(sin(i * 2.3))
		var ry := 7.0 + 3.0 * absf(cos(i * 1.1))
		for y in 180:
			for x in 480:
				var dx := (x + 0.5 - cx) / rx
				if dx > 1.5 or dx < -1.5:
					continue
				var dy := (y + 0.5 - cy) / ry
				if dx * dx + dy * dy <= 1.0:
					var c := Color(1, 1, 1, 0.55)
					clouds.set_pixel(x, y, c)
	save_png(clouds, "bg_clouds")

	# горы (бесшовные)
	var mts := new_img(480, 180)
	for x in 480:
		var h1 := 60.0 + 40.0 * sin(x * TAU / 240.0) + 18.0 * sin(x * TAU / 80.0)
		var h2 := 40.0 + 26.0 * sin(x * TAU / 160.0 + 1.3) + 12.0 * sin(x * TAU / 55.0)
		for y in 180:
			var yy := float(y)
			if yy > 180.0 - h2:
				mts.set_pixel(x, y, Color("#2c3c5e"))
			if yy > 180.0 - h1:
				var c := Color("#3c4f76")
				var depth := (180.0 - yy) / maxf(h1, 1.0)
				if depth < 0.12:
					c = Color("#dfe8f5")
				elif depth < 0.22:
					c = Color("#9fb0cd")
				mts.set_pixel(x, y, c)
	save_png(mts, "bg_mountain")

	# холмы + деревья
	var hills := new_img(480, 180)
	for x in 480:
		var h := 34.0 + 12.0 * sin(x * TAU / 200.0) + 6.0 * sin(x * TAU / 70.0 + 0.7)
		for y in 180:
			if float(y) > 180.0 - h:
				hills.set_pixel(x, y, Color("#22402c"))
	for i in 26:
		var tx := float(i) * 18.0 + 5.0
		var base_y := 180.0 - (26.0 + 8.0 * sin(i * 1.9))
		var th := 26.0 + 10.0 * absf(sin(i * 2.7))
		for y in range(int(base_y - th), int(base_y)):
			var rel := (base_y - float(y)) / th
			var half := (1.0 - rel) * (7.0 + 4.0 * sin(i))
			for x in range(int(tx - half), int(tx + half) + 1):
				if x < 0 or x >= 480:
					continue
				var c := Color("#173322") if rel > 0.4 else Color("#1d4029")
				hills.set_pixel(x, y, c)
		for y in range(int(base_y), int(base_y) + 4):
			for x in range(int(tx) - 1, int(tx) + 2):
				if x >= 0 and x < 480 and y < 180:
					hills.set_pixel(x, y, Color("#241a10"))
	save_png(hills, "bg_hills")

	# замок
	var castle := new_img(480, 180)
	var wall_col := Color("#2a2440")
	var wall_hi := Color("#3b3358")
	var win_col := Color("#ffd88a")
	draw_rect(castle, 40, 120, 400, 60, wall_col)
	draw_rect(castle, 40, 120, 400, 3, wall_hi)
	# зубцы
	for i in 30:
		var bx := 40 + i * 14
		draw_rect(castle, bx, 114, 8, 7, wall_col)
	# башни
	for t in [Vector2i(60, 60), Vector2i(200, 34), Vector2i(340, 50), Vector2i(430, 74)]:
		var tw := 42
		var th: int = 180 - t.y
		draw_rect(castle, t.x, t.y, tw, th, wall_col)
		draw_rect(castle, t.x - 3, t.y, tw + 6, 6, wall_hi)
		for i in 5:
			draw_rect(castle, t.x + i * 9, t.y - 7, 6, 7, wall_col)
		# крыша
		for i in 14:
			var w := 14 - i
			if w <= 0:
				continue
			draw_rect(castle, t.x + tw / 2 - w, t.y - 7 - (14 - i), w * 2, 1, Color("#5b3f6e"))
		# окна
		for wy in range(t.y + 16, 170, 24):
			for wx in range(t.x + 8, t.x + tw - 8, 14):
				draw_rect(castle, wx, wy, 5, 8, win_col)
				draw_rect(castle, wx, wy + 3, 5, 1, Color("#8a5f1a"))
	save_png(castle, "bg_castle")

	# пещера: сталактиты
	var cave := new_img(480, 180)
	for x in 480:
		var h := 18.0 + 12.0 * sin(x * TAU / 90.0) + 6.0 * sin(x * TAU / 37.0)
		for i in range(int(h)):
			cave.set_pixel(x, i, Color("#12101f"))
		var hb := 14.0 + 9.0 * sin(x * TAU / 110.0 + 2.0)
		for i in range(int(hb)):
			cave.set_pixel(x, 179 - i, Color("#12101f"))
	save_png(cave, "bg_cave")

func draw_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in range(maxi(y, 0), mini(y + h, img.get_height())):
		for xx in range(maxi(x, 0), mini(x + w, img.get_width())):
			img.set_pixel(xx, yy, col)

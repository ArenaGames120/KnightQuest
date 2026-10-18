extends SceneTree
## Быстрая проверка размеров листов спрайтов (что видит движок).

const EXPECT := {
	"knight": [16, 20], "skeleton": [16, 20], "bat": [16, 8], "slime": [16, 10],
	"gargoyle": [16, 20], "boss": [20, 22], "boss_lich": [20, 22], "princess": [16, 20],
	"coin": [8, 8], "key": [10, 12], "heart": [10, 8],
	"gate": [16, 48], "gate_locked": [16, 48], "lever": [16, 16], "plate": [16, 8],
	"crate": [16, 16], "crate_stone": [16, 16], "checkpoint": [16, 32],
	"chest": [16, 16], "banner": [16, 16], "sign": [16, 16], "torch": [16, 16],
	"exit_door": [24, 32], "princess_extra": [0, 0],
	"slash": [24, 24], "spark": [9, 9], "rock": [8, 8], "saw": [16, 16],
	"knight_dead": [16, 20], "knight_hurt": [16, 20], "bush": [16, 16],
}

func _initialize() -> void:
	print("=== Размеры листов (арт) ===")
	var problems := 0
	var dir := DirAccess.open("res://art")
	var names := dir.get_files()
	names.sort()
	for f in names:
		if not f.ends_with(".png"):
			continue
		var n := f.get_basename()
		var t: Texture2D = load("res://art/" + f)
		if t == null:
			print("  ERR не загрузился: ", f)
			problems += 1
			continue
		var s := t.get_size()
		var mark := "  "
		if EXPECT.has(n):
			var fw: int = EXPECT[n][0]
			var fh: int = EXPECT[n][1]
			var div_ok := fw > 0 and int(s.x) % fw == 0 and int(s.y) == fh
			mark = "ok" if div_ok else "!!"
			if not div_ok:
				problems += 1
		print("  %s %-14s %3dx%-3d  кадр %dx%d -> %d" % [mark, n, int(s.x), int(s.y), int(EXPECT.get(n, [0, 0])[0]), int(EXPECT.get(n, [0, 0])[1]), int(s.x) / maxi(1, int(EXPECT.get(n, [1, 1])[0]))])
	print("=== Проблем: %d ===" % problems)
	quit()

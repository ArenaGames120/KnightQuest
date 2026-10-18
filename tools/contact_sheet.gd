extends SceneTree
## Собирает превью всех ассетов в один PNG (для проверки глазами).

const ART := "res://art/"
const SCALE := 4

func _initialize() -> void:
	var names := ["knight", "knight_hurt", "knight_dead", "skeleton", "bat", "slime", "gargoyle", "boss",
		"princess", "coin", "key", "heart", "gate", "gate_locked", "lever", "plate", "crate", "crate_stone",
		"checkpoint", "saw", "torch", "sign", "rock", "chest", "exit_door", "bush", "banner", "slash", "spark",
		"tiles", "bg_sky", "bg_clouds", "bg_mountain", "bg_hills", "bg_castle", "bg_cave"]
	var sheet := Image.create_empty(1400, 900, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#202030"))
	var x := 4
	var y := 4
	var row_h := 0
	for n in names:
		var img: Image = load(ART + n + ".png").get_image()
		img.convert(Image.FORMAT_RGBA8)
		var big: Image = img.duplicate()
		big.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		if x + big.get_width() > sheet.get_width() - 4:
			x = 4
			y += row_h + 8
			row_h = 0
		if y + big.get_height() > sheet.get_height() - 4:
			break
		sheet.blend_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(x, y))
		x += big.get_width() + 12
		row_h = maxi(row_h, big.get_height())
	var err := sheet.save_png("res://preview_assets.png")
	print("preview: ", err)
	quit()

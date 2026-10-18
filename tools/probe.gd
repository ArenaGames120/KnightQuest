extends SceneTree

func _initialize() -> void:
	print("=== ENGINE ===")
	print(Engine.get_version_info())
	print("=== CLASSDB ===")
	for m in ["create", "create_empty", "blend_rect", "blit_rect", "save_png", "fill_rect", "set_pixel"]:
		print("Image.%s : %s" % [m, ClassDB.class_has_method("Image", m, true)])
	for c in ["TileMapLayer", "TileMap", "TileSet", "TileSetAtlasSource", "CharacterBody2D", "AudioStreamWAV", "AnimatedSprite2D", "PointLight2D", "CanvasModulate", "ParallaxBackground", "ParallaxLayer", "GradientTexture2D", "Line2D", "GPUParticles2D", "AudioStreamPlayer", "Timer", "AnimationPlayer", "Tween"]:
		print("class %s : %s" % [c, ClassDB.class_exists(c)])
	print("=== TileMapLayer methods ===")
	var ml: Array = ClassDB.class_get_method_list("TileMapLayer", true)
	for m in ml:
		var n: String = m["name"]
		if n in ["set_cell", "get_cell_source_id", "clear", "get_used_cells", "local_to_map", "map_to_local"]:
			print("  ", n, " ", m["args"])
	print("=== TileSet methods ===")
	for m in ClassDB.class_get_method_list("TileSet", true):
		var n2: String = m["name"]
		if n2 in ["add_source", "add_physics_layer", "set_physics_layer_collision_layer", "set_physics_layer_collision_mask", "set_physics_layer_collision_priority", "add_terrain_set"]:
			print("  ", n2)
	print("=== AudioStreamWAV ===")
	for m in ClassDB.class_get_property_list("AudioStreamWAV", true):
		print("  prop ", m["name"])
	print("=== TilesetAtlasSource ===")
	for m in ClassDB.class_get_method_list("TileSetAtlasSource", true):
		var n3: String = m["name"]
		if n3 in ["create_tile", "set_texture_region_size", "get_tile_data", "create_alternative_tile"]:
			print("  ", n3, " ", m["args"])
	print("=== ImageTexture ===")
	print("  create_from_image: ", ClassDB.class_has_method("ImageTexture", "create_from_image", true))
	print("=== get_cmdline ===")
	print(OS.get_cmdline_args(), " | user: ", OS.get_cmdline_user_args())
	quit()

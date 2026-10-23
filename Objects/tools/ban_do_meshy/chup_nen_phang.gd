extends SceneTree
## Chụp mặt sân bản Meshy (models/ban_do_meshy/ban_do.glb) thẳng từ trên xuống, phủ đúng sân 50 x 45 m,
## không ánh sáng: ra ảnh màu liền một tấm theo (x, z) cho lam_min.py làm mịn. Dùng ảnh màu gốc 2048 px
## chưa làm mịn (mau_goc.jpg do build_ban_do.py chép ra) để mép lối đất còn rõ.
## Chạy: godot --path . --rendering-driver opengl3 --resolution 2048x1844 -s Objects/tools/ban_do_meshy/chup_nen_phang.gd -- tu_tren.png [anh_mau.jpg]
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map: Node3D = (load("res://Objects/models/ban_do_meshy/ban_do.glb") as PackedScene).instantiate()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var args := OS.get_cmdline_user_args()
	var img := Image.load_from_file(args[1]) if args.size() > 1 else (load("res://Objects/models/ban_do_meshy/mau_goc.jpg") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	m.albedo_texture = ImageTexture.create_from_image(img)
	for mi: MeshInstance3D in map.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = m
	get_root().add_child(map)
	get_root().size = Vector2i(2048, 1844)
	var cam := Camera3D.new()
	get_root().add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 45.0 # chiều dọc ảnh = 45 m (z), chiều ngang 2048 / 1844 * 45 = 50 m (x)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.far = 100.0
	cam.look_at_from_position(Vector3(25, 50, 22.5), Vector3(25, 0, 22.5), Vector3(0, 0, -1))
	cam.make_current()
	for k in 10:
		await process_frame
	get_root().get_texture().get_image().save_png(args[0])
	quit()

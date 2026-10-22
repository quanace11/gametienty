extends SceneTree
## Chụp mô hình .glb từ trên xuống (chỉ ánh sáng môi trường) để tách ảnh lớp nền: xem lop_nen.py.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(OS.get_cmdline_user_args()[0], st)
	var n := doc.generate_scene(st)
	get_root().add_child(n)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(1,0,1); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color.WHITE; env.environment.ambient_light_energy = 1.0; get_root().add_child(env)
	var cam := Camera3D.new(); get_root().add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.0 # 2 đơn vị theo chiều dọc 1000 px
	cam.look_at_from_position(Vector3(0, 5, 0.0001), Vector3.ZERO); cam.make_current()
	await create_timer(0.5).timeout
	get_root().get_texture().get_image().save_png(OS.get_cmdline_user_args()[1])
	quit()

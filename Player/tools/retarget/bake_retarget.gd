extends SceneTree
## Chuyển động tác KayKit (Barbarian) sang khung xương AccuRig của ma tu, đổi tên
## 18 xương chính sang tên KayKit, xuất GLB có sẵn động tác. Cách chạy: README.md.

const MAP := { # KayKit -> AccuRig
	"hips": "pelvis", "spine": "spine_02", "chest": "spine_04", "head": "head",
	"upperarm.l": "upperarm_l", "lowerarm.l": "lowerarm_l", "hand.l": "hand_l",
	"upperarm.r": "upperarm_r", "lowerarm.r": "lowerarm_r", "hand.r": "hand_r",
	"upperleg.l": "thigh_l", "lowerleg.l": "calf_l", "foot.l": "foot_l", "toes.l": "ball_l",
	"upperleg.r": "thigh_r", "lowerleg.r": "calf_r", "foot.r": "foot_r", "toes.r": "ball_r",
}
const DIR_CHILD := { # xương -> xương con để đo hướng (cùng tên KayKit)
	"spine": "chest", "chest": "head",
	"upperarm.l": "lowerarm.l", "lowerarm.l": "hand.l", "upperarm.r": "lowerarm.r", "lowerarm.r": "hand.r",
	"upperleg.l": "lowerleg.l", "lowerleg.l": "foot.l", "foot.l": "toes.l",
	"upperleg.r": "lowerleg.r", "lowerleg.r": "foot.r", "foot.r": "toes.r",
}
const CLIPS := ["Walking_A", "Walking_B", "Running_A", "Running_B", "1H_Melee_Attack_Chop",
	"2H_Melee_Attack_Chop", "Spellcast_Shoot", "Throw", "Hit_A", "Lie_Idle", "Sit_Floor_Idle",
	"Jump_Idle", "PickUp", "Cheer", "Death_A"]
const FPS := 30.0
const ARM_IN := deg_to_rad(18.0) # khép tay

var S: Skeleton3D
var T: Skeleton3D
var s_rest: Array[Transform3D] = []
var t_rest: Array[Transform3D] = []
var O := {} # tên KayKit -> Basis bù
var t_map := {} # chỉ số xương đích -> tên KayKit


func _globals(sk: Skeleton3D, local: Array[Transform3D]) -> Array[Transform3D]:
	var g: Array[Transform3D] = []
	g.resize(sk.get_bone_count())
	for b in sk.get_bone_count():
		var p := sk.get_bone_parent(b)
		g[b] = local[b] if p < 0 else g[p] * local[b]
	return g


func _rest_locals(sk: Skeleton3D) -> Array[Transform3D]:
	var l: Array[Transform3D] = []
	for b in sk.get_bone_count():
		l.append(sk.get_bone_rest(b))
	return l


## Dáng cục bộ của khung xương sk ở giây t theo động tác anim (xương không có track giữ nguyên rest).
func _sample(sk: Skeleton3D, anim: Animation, t: float, skip_root: bool) -> Array[Transform3D]:
	var l := _rest_locals(sk)
	for i in anim.get_track_count():
		var path := str(anim.track_get_path(i))
		var bone := sk.find_bone(path.get_slice(":", 1))
		if bone < 0 or (skip_root and sk.get_bone_parent(bone) < 0):
			continue
		match anim.track_get_type(i):
			Animation.TYPE_ROTATION_3D:
				l[bone].basis = Basis(anim.rotation_track_interpolate(i, t)).scaled(l[bone].basis.get_scale())
			Animation.TYPE_POSITION_3D:
				l[bone].origin = anim.position_track_interpolate(i, t)
	return l


## Từ dáng thế giới của các xương chính (tên KayKit -> Basis, vị trí hông) ra track cục bộ.
func _write_frame(anim: Animation, tracks: Dictionary, t: float, world: Dictionary, hips_pos: Vector3) -> void:
	var g := _globals(T, _rest_locals(T)) # xương phụ giữ rest; cập nhật dần theo thứ tự cha trước
	for b in T.get_bone_count():
		var p := T.get_bone_parent(b)
		var parent_g := Transform3D.IDENTITY if p < 0 else g[p]
		var local := t_rest[b]
		if t_map.has(b):
			var k: String = t_map[b]
			var lb := (parent_g.basis.orthonormalized().inverse() * (world[k] as Basis)).orthonormalized()
			local.basis = lb.scaled(t_rest[b].basis.get_scale())
			anim.rotation_track_insert_key(tracks[k], t, lb.get_rotation_quaternion())
			if k == "hips":
				local.origin = parent_g.affine_inverse() * hips_pos
				anim.position_track_insert_key(tracks["hips_pos"], t, local.origin)
		g[b] = parent_g * local


func _new_anim(length: float, loop: bool) -> Array:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	for k in MAP:
		var i := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(i, NodePath("Skeleton3D:%s" % k))
		tracks[k] = i
	var hp := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hp, NodePath("Skeleton3D:hips"))
	tracks["hips_pos"] = hp
	return [anim, tracks]


func _init() -> void:
	var args := OS.get_cmdline_user_args() # nguồn KayKit, mô hình AccuRig, tệp ra
	var src: Node3D = (load(args[0]) as PackedScene).instantiate()
	var dst: Node3D = (load(args[1]) as PackedScene).instantiate()
	S = src.find_children("*", "Skeleton3D", true, false)[0]
	T = dst.find_children("*", "Skeleton3D", true, false)[0]
	var src_player: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	var dst_player: AnimationPlayer = dst.find_children("*", "AnimationPlayer", true, false)[0]
	var sg := _globals(S, _rest_locals(S))
	var tg := _globals(T, _rest_locals(T))
	t_rest = _rest_locals(T)
	var C := {}
	for k: String in MAP: # cha trước con theo thứ tự MAP
		var sb := S.find_bone(k)
		var tb := T.find_bone(MAP[k])
		t_map[tb] = k
		var c := Basis.IDENTITY
		if DIR_CHILD.has(k):
			var ds := (sg[S.find_bone(DIR_CHILD[k])].origin - sg[sb].origin).normalized()
			var dt := (tg[T.find_bone(MAP[DIR_CHILD[k]])].origin - tg[tb].origin).normalized()
			c = Basis(Quaternion(dt, ds))
		else:
			var p := S.get_bone_parent(sb)
			var pk := S.get_bone_name(p) if p >= 0 else ""
			if C.has(pk):
				c = C[pk]
			elif k.begins_with("hand.") or k.begins_with("toes."):
				c = C[{"hand.l": "lowerarm.l", "hand.r": "lowerarm.r", "toes.l": "foot.l", "toes.r": "foot.r"}[k]]
		C[k] = c
		O[k] = sg[sb].basis.orthonormalized().inverse() * (c * tg[tb].basis.orthonormalized())
	var s_hips_rest := sg[S.find_bone("hips")].origin
	var t_hips_rest := tg[T.find_bone("pelvis")].origin
	var k_scale := t_hips_rest.y / s_hips_rest.y
	var t_chest_rest := (C["chest"] as Basis) * tg[T.find_bone("spine_04")].basis.orthonormalized()
	print("tỉ lệ hông ", k_scale)

	var lib := AnimationLibrary.new()
	for clip in CLIPS:
		var src_anim := src_player.get_animation(clip)
		var made := _new_anim(src_anim.length, src_anim.loop_mode != Animation.LOOP_NONE)
		var anim: Animation = made[0]
		var t := 0.0
		while t <= src_anim.length + 0.0001:
			var g := _globals(S, _sample(S, src_anim, minf(t, src_anim.length), false))
			var world := {}
			for k in MAP:
				world[k] = g[S.find_bone(k)].basis.orthonormalized() * (O[k] as Basis)
			# Tay chibi dang rộng (thân KayKit to ngang): khép tay vào thân theo khung ngực.
			var d := (world["chest"] as Basis) * t_chest_rest.inverse()
			world["upperarm.l"] = d * Basis(Vector3.BACK, -ARM_IN) * d.inverse() * (world["upperarm.l"] as Basis)
			world["upperarm.r"] = d * Basis(Vector3.BACK, ARM_IN) * d.inverse() * (world["upperarm.r"] as Basis)
			var hp := t_hips_rest + (g[S.find_bone("hips")].origin - s_hips_rest) * k_scale
			_write_frame(anim, made[1], minf(t, src_anim.length), world, hp)
			t += 1.0 / FPS
		lib.add_animation(clip, anim)
	# Động tác nghỉ của chính mô hình (AccuRig): bỏ xoay / dời của xương gốc.
	var relax: Animation # động tác nghỉ xuất từ AccuRig (bỏ dáng chữ A "0_...")
	for a in dst_player.get_animation_list():
		if not a.begins_with("0_"):
			relax = dst_player.get_animation(a)
	var made := _new_anim(relax.length, true)
	var t := 0.0
	while t <= relax.length + 0.0001:
		var g := _globals(T, _sample(T, relax, minf(t, relax.length), true))
		var world := {}
		for k in MAP:
			world[k] = g[T.find_bone(MAP[k])].basis.orthonormalized()
		_write_frame(made[0], made[1], minf(t, relax.length), world, g[T.find_bone("pelvis")].origin)
		t += 1.0 / FPS
	lib.add_animation("Idle", made[0])

	# Cảnh xuất: khung xương (đổi tên 18 xương chính) + lưới + động tác.
	for k: String in MAP:
		T.set_bone_name(T.find_bone(MAP[k]), k)
	var mi: MeshInstance3D = T.find_children("*", "MeshInstance3D", true, false)[0]
	var skin := mi.skin
	for i in skin.get_bind_count():
		var bn := skin.get_bind_name(i)
		for k: String in MAP:
			if MAP[k] == bn:
				skin.set_bind_name(i, k)
	dst_player.get_parent().remove_child(dst_player)
	dst_player.free()
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	dst.add_child(ap)
	ap.owner = dst
	ap.add_animation_library("", lib)
	dst.name = "MaTu"
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(dst, state)
	print("append ", err)
	err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(args[2]))
	print("write ", err)
	quit()

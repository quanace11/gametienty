extends SceneTree
## Chuyển động tác có sẵn sang khung xương 17 xương của mô hình dự án, lưu thành
## AnimationLibrary (Player/anim/*.res). Chạy lại khi đổi mô hình hay thêm động tác:
##   godot --headless --path . -s Player/tools/retarget/bake_anim.gd -- \
##       <KayKit Knight.glb trong project> <thư mục BVH CMU> <mô hình.glb> <ra.res>
## Nguồn (xem README cùng thư mục):
## - Đi, chạy: mocap người thật CMU Graphics Lab (bản BVH của B. Hahne), dùng tự do
##   cả trong sản phẩm bán, chỉ cấm bán lại chính dữ liệu.
## - Chém, ném, trúng đòn, nằm, ngồi...: KayKit Adventurers (CC0, Kay Lousberg).
## Cách chuyển: nguồn có dáng chữ T (KayKit: dáng gốc; CMU: khung đầu). Xoay từng
## xương của mô hình cho cùng hướng với nguồn ở dáng T, rồi mỗi khung hình cộng
## đúng độ xoay toàn cục mà xương nguồn đã xoay so với dáng T. Hướng tay chân giữ
## đúng dù tỉ lệ người khác nhau; hông dịch theo tỉ lệ chiều dài chân.

const FPS := 30.0
const DST_BONES: Array[String] = ["hips", "spine", "chest", "neck", "head",
	"upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r",
	"thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
## Xương con đích để lấy hướng xương ("" = giữ theo xương cha, không chỉnh hướng).
const DST_CHILD := {
	"spine": "chest", "chest": "neck", "neck": "head",
	"upper_arm_l": "forearm_l", "forearm_l": "hand_l", "upper_arm_r": "forearm_r", "forearm_r": "hand_r",
	"thigh_l": "shin_l", "shin_l": "foot_l", "thigh_r": "shin_r", "shin_r": "foot_r",
}
## Xương đích -> [xương nguồn, xương con nguồn để lấy hướng].
const KAYKIT_MAP := {
	"hips": ["hips", ""], "spine": ["spine", "chest"], "chest": ["chest", "head"],
	"neck": ["chest", ""], "head": ["head", ""],
	"upper_arm_l": ["upperarm.l", "lowerarm.l"], "forearm_l": ["lowerarm.l", "wrist.l"], "hand_l": ["hand.l", ""],
	"upper_arm_r": ["upperarm.r", "lowerarm.r"], "forearm_r": ["lowerarm.r", "wrist.r"], "hand_r": ["hand.r", ""],
	"thigh_l": ["upperleg.l", "lowerleg.l"], "shin_l": ["lowerleg.l", "foot.l"], "foot_l": ["foot.l", ""],
	"thigh_r": ["upperleg.r", "lowerleg.r"], "shin_r": ["lowerleg.r", "foot.r"], "foot_r": ["foot.r", ""],
}
const CMU_MAP := {
	"hips": ["Hips", ""], "spine": ["Spine", "Spine1"], "chest": ["Spine1", "Neck1"],
	"neck": ["Neck", "Head"], "head": ["Head", ""],
	"upper_arm_l": ["LeftArm", "LeftForeArm"], "forearm_l": ["LeftForeArm", "LeftHand"], "hand_l": ["LeftHand", ""],
	"upper_arm_r": ["RightArm", "RightForeArm"], "forearm_r": ["RightForeArm", "RightHand"], "hand_r": ["RightHand", ""],
	"thigh_l": ["LeftUpLeg", "LeftLeg"], "shin_l": ["LeftLeg", "LeftFoot"], "foot_l": ["LeftFoot", ""],
	"thigh_r": ["RightUpLeg", "RightLeg"], "shin_r": ["RightLeg", "RightFoot"], "foot_r": ["RightFoot", ""],
}
## Động tác: [tên lưu, nguồn, động tác KayKit | [tệp BVH, giây bắt đầu, (giây kết thúc)]].
## BVH đi / chạy: tự tìm một chu kỳ bước từ giây bắt đầu, bỏ quãng di chuyển (chạy tại
## chỗ, game tự dịch nhân vật), ghi tốc độ gốc vào meta "speed" (đơn vị mô hình / giây).
## Có giây kết thúc thì lấy đúng đoạn đó (bằng nhau: một dáng đứng yên).
## Đứng yên lấy dáng người thật (dáng đứng của KayKit là người lùn, dạng chân, xòe tay).
const CLIPS := [
	["Walk", "cmu", ["35_01.bvh", 0.6]],
	["Run", "cmu", ["09_01.bvh", 0.4]],
	["Stand", "cmu", ["16_33.bvh", 2.3, 2.3]],
	["Attack", "kaykit", "1H_Melee_Attack_Slice_Diagonal"],
	["Throw", "kaykit", "Throw"],
	["Hit", "kaykit", "Hit_A"],
	["Lie", "kaykit", "Lie_Idle"],
	["Sit", "kaykit", "Sit_Floor_Idle"],
	["Jump", "kaykit", "Jump_Idle"],
	["PickUp", "kaykit", "PickUp"],
]


## Một nguồn chuyển động: tên xương, xương cha, dáng T (toàn cục) và cách lấy dáng
## toàn cục tại một thời điểm.
class Source:
	var names := PackedStringArray()
	var parent := PackedInt32Array()
	var ref: Array[Transform3D] = []
	func index(n: String) -> int:
		return names.find(n)
	func globals(_t: float) -> Array[Transform3D]:
		return []
	func to_globals(locals: Array[Transform3D]) -> Array[Transform3D]:
		var out: Array[Transform3D] = []
		out.resize(names.size())
		for i in names.size():
			out[i] = out[parent[i]] * locals[i] if parent[i] >= 0 else locals[i]
		return out


class KayKitSource extends Source:
	var sk: Skeleton3D
	var path: String
	var anim: Animation
	func _init(scene: Node) -> void:
		sk = scene.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		path = str(ap.get_node(ap.root_node).get_path_to(sk))
		for i in sk.get_bone_count():
			names.append(sk.get_bone_name(i))
			parent.append(sk.get_bone_parent(i))
			ref.append(sk.get_bone_global_rest(i))
	func globals(t: float) -> Array[Transform3D]:
		var locals: Array[Transform3D] = []
		for i in names.size():
			var rest := sk.get_bone_rest(i)
			var pos := rest.origin
			var rot := rest.basis.get_rotation_quaternion()
			var scl := rest.basis.get_scale()
			var p := NodePath(path + ":" + names[i])
			var tp := anim.find_track(p, Animation.TYPE_POSITION_3D)
			var tr := anim.find_track(p, Animation.TYPE_ROTATION_3D)
			var ts := anim.find_track(p, Animation.TYPE_SCALE_3D)
			if tp >= 0: pos = anim.position_track_interpolate(tp, t)
			if tr >= 0: rot = anim.rotation_track_interpolate(tr, t)
			if ts >= 0: scl = anim.scale_track_interpolate(ts, t)
			locals.append(Transform3D(Basis(rot).scaled(scl), pos))
		return to_globals(locals)


## BVH (Y lên, dáng T ở khung đầu nhìn về +Z). Góc theo thứ tự kênh, độ.
class BvhSource extends Source:
	var offsets: Array[Vector3] = []
	var channels: Array[PackedStringArray] = []
	var frames: Array[PackedFloat32Array] = []
	var frame_time := 1.0 / 120.0
	func _init(file: String) -> void:
		var text := FileAccess.get_file_as_string(file)
		var lines := text.split("\n")
		var stack: Array[int] = []
		var i := 0
		var last := -1
		while i < lines.size():
			var w := lines[i].strip_edges().split(" ", false)
			i += 1
			if w.is_empty():
				continue
			match w[0]:
				"ROOT", "JOINT":
					names.append(w[1])
					parent.append(stack.back() if not stack.is_empty() else -1)
					offsets.append(Vector3.ZERO)
					channels.append(PackedStringArray())
					last = names.size() - 1
				"End":
					last = -2 # bỏ End Site
				"{":
					stack.append(last)
				"}":
					stack.pop_back()
				"OFFSET":
					if stack.back() >= 0:
						offsets[stack.back()] = Vector3(float(w[1]), float(w[2]), float(w[3]))
				"CHANNELS":
					channels[stack.back()] = w.slice(2)
				"Frame":
					if w[1] == "Time:":
						frame_time = float(w[2])
				"MOTION", "Frames:":
					pass
				_:
					if w[0].is_valid_float():
						frames.append(PackedFloat32Array(Array(w).map(func(s: String) -> float: return float(s))))
		ref = _frame(0)
	func length() -> float:
		return (frames.size() - 1) * frame_time
	func _frame(f: int) -> Array[Transform3D]:
		var data := frames[clampi(f, 0, frames.size() - 1)]
		var k := 0
		var locals: Array[Transform3D] = []
		for j in names.size():
			var pos := offsets[j]
			var basis := Basis.IDENTITY
			for c in channels[j]:
				var v := data[k]
				k += 1
				match c:
					"Xposition": pos.x = v
					"Yposition": pos.y = v
					"Zposition": pos.z = v
					"Xrotation": basis = basis * Basis(Vector3.RIGHT, deg_to_rad(v))
					"Yrotation": basis = basis * Basis(Vector3.UP, deg_to_rad(v))
					"Zrotation": basis = basis * Basis(Vector3.BACK, deg_to_rad(v))
			locals.append(Transform3D(basis, pos))
		return to_globals(locals)
	func globals(t: float) -> Array[Transform3D]:
		return _frame(roundi(t / frame_time))


var dst_sk: Skeleton3D
var dst_path: String
var dst_parent := {}
var last_pose := {} # xương -> Basis toàn cục ở khung cuối vừa chuyển (dáng đứng CMU)


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var kaykit := KayKitSource.new((load(a[0]) as PackedScene).instantiate())
	var kay_player: AnimationPlayer = kaykit.sk.get_parent().get_parent().find_children("*", "AnimationPlayer", true, false)[0]
	var dst: Node = (load(a[2]) as PackedScene).instantiate()
	dst_sk = dst.find_children("*", "Skeleton3D", true, false)[0]
	dst_path = str(dst.get_path_to(dst_sk))
	for n in DST_BONES:
		var p := dst_sk.get_bone_parent(dst_sk.find_bone(n))
		while p >= 0 and not DST_BONES.has(dst_sk.get_bone_name(p)):
			p = dst_sk.get_bone_parent(p)
		dst_parent[n] = "" if p < 0 else dst_sk.get_bone_name(p)
	var lib := AnimationLibrary.new()
	var stand := {}
	for c: Array in CLIPS:
		var anim: Animation
		if c[1] == "kaykit":
			# KayKit là người lùn đầu to: đứng thì dạng chân, tay xòe xa thân. Lấy dáng
			# đứng của KayKit làm mốc, coi nó là dáng đứng người thật (CMU), rồi chỉ
			# chuyển phần lệch khỏi dáng đứng: tay không còn xòe, chân không dạng.
			kaykit.anim = kay_player.get_animation("Idle")
			kaykit.ref = kaykit.globals(0.0)
			kaykit.anim = kay_player.get_animation(c[2])
			anim = _bake(kaykit, KAYKIT_MAP, 0.0, kaykit.anim.length, false, c[2] != "Jump_Idle", stand)
			anim.loop_mode = kaykit.anim.loop_mode
		else:
			var bvh := BvhSource.new(a[1].path_join(c[2][0]))
			var start: float = c[2][1]
			var end: float = c[2][2] if c[2].size() > 2 else _cycle_end(bvh, start)
			anim = _bake(bvh, CMU_MAP, start, end, true, false)
			anim.loop_mode = Animation.LOOP_LINEAR
			if c[0] == "Stand":
				stand = last_pose.duplicate()
		lib.add_animation(c[0], anim)
		print("%s: %.2f giây, tốc độ %.2f" % [c[0], anim.length, anim.get_meta("speed", 0.0)])
	ResourceSaver.save(lib, a[3])
	print("Đã lưu ", lib.get_animation_list().size(), " động tác vào ", a[3])
	quit()


## Dáng T của mô hình theo nguồn: xoay từng xương (cha trước) cho hướng tới xương
## con trùng hướng tương ứng của nguồn ở dáng T. Trả xương -> Basis toàn cục.
func _calibrate(src: Source, map: Dictionary) -> Dictionary:
	var calib := {}
	for n in DST_BONES:
		var p: String = dst_parent[n]
		var rest_g := dst_sk.get_bone_global_rest(dst_sk.find_bone(n))
		var rel := (dst_sk.get_bone_global_rest(dst_sk.find_bone(p)).basis.inverse() * rest_g.basis) if p != "" else rest_g.basis
		var g: Basis = ((calib[p] as Basis) * rel) if p != "" else rel
		var m: Array = map[n]
		if DST_CHILD.has(n) and m[1] != "":
			var child := dst_sk.get_bone_global_rest(dst_sk.find_bone(DST_CHILD[n])).origin
			var u := (g * (rest_g.basis.inverse() * (child - rest_g.origin))).normalized()
			var v := (src.ref[src.index(m[1])].origin - src.ref[src.index(m[0])].origin).normalized()
			g = Basis(Quaternion(u, v)) * g
		calib[n] = g.orthonormalized()
	return calib


func _leg_len_dst() -> float:
	return dst_sk.get_bone_global_rest(dst_sk.find_bone("thigh_l")).origin.y - dst_sk.get_bone_global_rest(dst_sk.find_bone("foot_l")).origin.y


func _leg_len_src(src: Source, map: Dictionary) -> float:
	return src.ref[src.index(map["thigh_l"][0])].origin.y - src.ref[src.index(map["foot_l"][0])].origin.y


## Chu kỳ bước: từ `start`, tìm thời điểm trong 0,6 - 1,6 giây sau có dáng giống
## nhất (góc các xương chân tay so với hông), để lặp lại không giật.
func _cycle_end(src: BvhSource, start: float) -> float:
	var a := src.globals(start)
	var best := start + 1.0
	var best_d := INF
	var t := start + 0.6
	while t < minf(start + 1.6, src.length()):
		var b := src.globals(t)
		var d := 0.0
		for n: String in ["LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg", "LeftArm", "RightArm"]:
			var i := src.index(n)
			var qa := (a[0].basis.inverse() * a[i].basis).get_rotation_quaternion()
			var qb := (b[0].basis.inverse() * b[i].basis).get_rotation_quaternion()
			d += qa.angle_to(qb)
		if d < best_d:
			best_d = d
			best = t
		t += src.frame_time
	return best


## Chuyển đoạn [t0, t1] của nguồn. `in_place`: bỏ quãng di chuyển và quay cho đi về
## +Z. `ground_each`: mỗi khung đặt hông cho mắt cá thấp nhất chạm đất (nguồn chân
## ngắn), không thì dịch hông theo nguồn và chỉ nâng cả đoạn cho khỏi lún.
## `calib`: dáng mô hình ứng với src.ref (mặc định: dáng T tính từ nguồn).
func _bake(src: Source, map: Dictionary, t0: float, t1: float, in_place: bool, ground_each: bool, calib := {}) -> Animation:
	if calib.is_empty():
		calib = _calibrate(src, map)
	var hips_i := src.index(map["hips"][0])
	var ratio := _leg_len_dst() / _leg_len_src(src, map)
	var hip_rest := dst_sk.get_bone_rest(dst_sk.find_bone("hips")).origin
	var ankle_y := dst_sk.get_bone_global_rest(dst_sk.find_bone("foot_l")).origin.y
	var p0 := src.globals(t0)[hips_i].origin
	var p1 := src.globals(t1)[hips_i].origin
	var travel := Vector3(p1.x - p0.x, 0.0, p1.z - p0.z)
	var turn := Basis.IDENTITY
	if in_place and travel.length() > 0.05 * _leg_len_src(src, map):
		turn = Basis(Vector3.UP, -atan2(travel.x, travel.z))
	elif in_place: # đứng yên: quay theo hướng hông
		var fwd := (src.globals(t0)[hips_i].basis * src.ref[hips_i].basis.inverse()) * Vector3.BACK
		turn = Basis(Vector3.UP, -atan2(fwd.x, fwd.z))
	var n_frames := maxi(1, roundi((t1 - t0) * FPS))
	if in_place and t1 - t0 < 0.01:
		n_frames = 1
	var keys_rot := {}
	for n in DST_BONES:
		keys_rot[n] = []
	var keys_hips: Array[Vector3] = []
	var lowest := INF
	var first := 0 # chu kỳ bắt đầu lúc bàn chân trái ra trước xa nhất (vừa chạm gót),
	var reach := -INF # để đi và chạy cùng pha, trộn với nhau không lệch chân
	for f in n_frames + (0 if in_place else 1):
		var t := minf(t0 + f / FPS, t1)
		var sg := src.globals(t)
		var g := {}
		for n in DST_BONES:
			var s := sg[src.index(map[n][0])].basis.orthonormalized()
			var r := src.ref[src.index(map[n][0])].basis.orthonormalized()
			g[n] = (turn * s * r.inverse() * (calib[n] as Basis)).orthonormalized()
			var p: String = dst_parent[n]
			var local: Basis = g[n] if p == "" else (g[p] as Basis).inverse() * g[n]
			keys_rot[n].append(local.get_rotation_quaternion())
		last_pose = g
		var hp := sg[hips_i].origin
		if in_place:
			hp -= p0.lerp(p1, (t - t0) / maxf(t1 - t0, 0.001)) * Vector3(1, 0, 1)
			hp = turn * hp
		var off := (hp - Vector3(0, src.ref[hips_i].origin.y, 0)) if in_place else (hp - src.ref[hips_i].origin)
		var hips := hip_rest + off * ratio
		var low := minf(_fk("foot_l", g, hips).y, _fk("foot_r", g, hips).y)
		var ahead := _fk("foot_l", g, hips).z - hips.z
		if ahead > reach:
			reach = ahead
			first = f
		if ground_each:
			hips.y += ankle_y - low
		else:
			lowest = minf(lowest, low)
		keys_hips.append(hips)
	if in_place and n_frames > 1:
		for n in DST_BONES:
			keys_rot[n] = keys_rot[n].slice(first) + keys_rot[n].slice(0, first)
		keys_hips = keys_hips.slice(first) + keys_hips.slice(0, first)
	var anim := Animation.new()
	anim.length = n_frames / FPS
	for n in DST_BONES:
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath(dst_path + ":" + n))
		for f in keys_rot[n].size():
			anim.rotation_track_insert_key(tr, f / FPS, keys_rot[n][f])
	var th := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(th, NodePath(dst_path + ":hips"))
	var lift := 0.0 if ground_each else ankle_y - lowest
	for f in keys_hips.size():
		anim.position_track_insert_key(th, f / FPS, keys_hips[f] + Vector3(0, lift, 0))
	if in_place:
		anim.set_meta("speed", travel.length() * ratio / maxf(t1 - t0, 0.001))
	return anim


## Vị trí xương `n` (hệ khung xương) khi hông ở `hips` và các xương xoay theo `g`.
func _fk(n: String, g: Dictionary, hips: Vector3) -> Vector3:
	var p: String = dst_parent[n]
	if p == "":
		return hips
	var off := dst_sk.get_bone_global_rest(dst_sk.find_bone(n)).origin - dst_sk.get_bone_global_rest(dst_sk.find_bone(p)).origin
	return _fk(p, g, hips) + (g[p] as Basis) * off

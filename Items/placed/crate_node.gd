extends StaticBody3D
## Hộp gỗ (id = obj_id): vật cản layer 1, chắn đường và chắn đạn.

const SIZE := Vector3(1.2, 1.2, 1.2)

static var _mesh: BoxMesh


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	shape.position.y = SIZE.y / 2
	add_child(shape)
	if _mesh == null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.38, 0.2)
		_mesh = BoxMesh.new()
		_mesh.size = SIZE
		_mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.position.y = SIZE.y / 2
	add_child(mi)

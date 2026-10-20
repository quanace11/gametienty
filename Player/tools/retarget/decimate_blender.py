# Giảm lưới GLB có xương bằng Blender (giữ trọng số xương, chịu được đường nối UV): blender -b -P decimate_blender.py -- vao.glb ra.glb so_tam_giac (README.md).
import bpy, sys
src, out, target = sys.argv[-3], sys.argv[-2], int(sys.argv[-1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in [o for o in bpy.context.scene.objects if o.type == 'MESH']:
    if o.data.shape_keys:
        o.shape_key_clear()
    n = len(o.data.polygons)
    m = o.modifiers.new('giam', 'DECIMATE')
    m.ratio = min(1.0, target / max(1, n))
    m.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = o
    o.modifiers.move(o.modifiers.find('giam'), 0)
    bpy.ops.object.modifier_apply(modifier='giam')
    print('tam giác', n, '->', len(o.data.polygons))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_animations=True, export_force_sampling=True, export_skins=True, export_all_influences=False, export_morph=False, export_animation_mode='ACTIONS')

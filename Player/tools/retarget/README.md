# Chuyển động tác KayKit sang nhân vật gắn xương AccuRig

Dùng cho ma tu (`Player/models/ma_tu/`). `player_character.gd` đặt góc 18 xương chính
theo tên KayKit (`hips`, `spine`, `chest`, `head`, `upperarm.l`...), nên mô hình mới chỉ
cần có khung xương mang các tên đó và kèm động tác cùng tên với KayKit.

1. Gắn xương ở AccuRig, xuất FBX (Target Unity hoặc Blender), có thể kèm một động tác
   nghỉ: động tác đó thành `Idle` (đứng yên trong game).
2. Chép FBX và `Player/models/kaykit/Barbarian.glb` vào một project Godot trống, import, rồi:
   ```bash
   godot --headless --path <project> -s bake_retarget.gd -- res://Barbarian.glb res://ma_tu.fbx res://ma_tu_full.glb
   ```
   Script đo hướng xương lúc đứng của cả hai (KayKit chữ T, AccuRig chữ A) để bù,
   chuyển góc theo không gian thế giới, hông dời theo tỉ lệ chiều cao hông, tay khép
   vào thân 18 độ (thân KayKit chibi to ngang nên tay dang rộng).
3. Giảm lưới thành 3 mức đồ họa (bỏ morph mặt, giữ 4 trọng số xương lớn nhất):
   ```bash
   npm install @gltf-transform/core@4.2.1 @gltf-transform/functions@4.2.1 @gltf-transform/extensions@4.2.1 meshoptimizer
   node slim.mjs ma_tu_full.glb ma_tu_thap.glb 6000
   node slim.mjs ma_tu_full.glb ma_tu_vua.glb 20000
   node slim.mjs ma_tu_full.glb ma_tu_cao.glb 60000
   ```
4. Đổi nhân vật khác chiều cao thì sửa `MODEL_HEIGHT` và `CLIP_SPEED` trong
   `player_character.gd` (tốc độ bước KayKit nhân tỉ lệ hông script in ra).

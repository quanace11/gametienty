# Chuyển động tác KayKit sang nhân vật gắn xương AccuRig

Dùng cho ma tu (`Player/models/ma_tu/`) và kiếm tu (`Player/models/de_tu/`). `player_character.gd` đặt góc 18 xương chính
theo tên KayKit (`hips`, `spine`, `chest`, `head`, `upperarm.l`...), nên mô hình mới chỉ
cần có khung xương mang các tên đó và kèm động tác cùng tên với KayKit.

1. Gắn xương ở AccuRig, xuất FBX (Target Unity hoặc Blender), có thể kèm một động tác
   nghỉ: động tác đó thành `Idle` (đứng yên trong game).
2. Chép FBX và `Player/models/kaykit/Barbarian.glb` vào một project Godot trống, import, rồi:
   ```bash
   godot --headless --path <project> -s bake_retarget.gd -- res://Barbarian.glb res://ma_tu.fbx res://ma_tu_full.glb ma_tu
   godot --headless --path <project> -s bake_retarget.gd -- res://Mage.glb res://de_tu.fbx res://de_tu_full.glb de_tu
   ```
   Tham số cuối là vai, chọn bộ động tác (`CLIPS` trong script). Ma tu thêm tư thế kéo
   người (Drag), kiếm tu thêm gục bò bằng tay và đầu gối (Crawl), cả hai dựng bằng hướng xương chứ không
   lấy từ KayKit.
   Script đo hướng xương lúc đứng của cả hai (KayKit chữ T, AccuRig chữ A) để bù,
   chuyển góc theo không gian thế giới, hông dời theo tỉ lệ chiều cao hông, tay khép
   vào thân 18 độ (thân KayKit chibi to ngang nên tay dang rộng).
3. Giảm lưới thành 3 mức đồ họa (bỏ morph mặt, giữ 4 trọng số xương lớn nhất):
   ```bash
   npm install @gltf-transform/core@4.2.1 @gltf-transform/functions@4.2.1 @gltf-transform/extensions@4.2.1 meshoptimizer
   node slim.mjs ma_tu_full.glb ma_tu_thap.glb 6000 mau_512.png
   node slim.mjs ma_tu_full.glb ma_tu_vua.glb 20000 mau_1024.png
   node slim.mjs ma_tu_full.glb ma_tu_cao.glb 60000 mau_2048.png normal_1024.png
   ```
   FBX của AccuRig không kèm màu, nhưng giữ nguyên UV của mô hình gốc (tệp GLB tạo bằng
   AI), nên lấy ảnh màu / normal trong tệp gốc, thu nhỏ theo từng mức rồi truyền vào.

   Lưới nhiều đường nối UV (kiếm tu) thì meshopt không giảm được dưới ~26k tam giác.
   Khi đó giảm bằng Blender (bản `pip install bpy` cũng được), ghép lưới đó vào tệp đầy
   đủ để giữ nguyên khung xương và động tác, rồi chỉ gắn ảnh (số tam giác lớn thì
   `slim.mjs` không giản lược thêm):
   ```bash
   blender -b -P decimate_blender.py -- de_tu_full.glb de_tu_thap_blender.glb 6000
   node swap_mesh.mjs de_tu_full.glb de_tu_thap_blender.glb de_tu_thap_ghep.glb
   node slim.mjs de_tu_thap_ghep.glb de_tu_thap.glb 999999 mau_512.png
   ```
4. Đổi nhân vật khác chiều cao thì sửa `MODEL_HEIGHT` và `CLIP_SPEED` trong
   `player_character.gd` (tốc độ bước KayKit nhân tỉ lệ hông script in ra).

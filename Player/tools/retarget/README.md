# Chuyển động tác sang khung xương của mô hình

`bake_anim.gd` lấy động tác có sẵn, chuyển sang khung xương 17 xương của mô hình
dự án (gắn bằng `../rig/`), lưu thành `Player/anim/ma_tu.res` và `Player/anim/de_tu.res`
(AnimationLibrary). Game chỉ đọc hai file này, không cần file nguồn.

## Nguồn và giấy phép

| Động tác | Nguồn | Giấy phép |
|---|---|---|
| Đứng, đi, chạy | CMU Graphics Lab Motion Capture Database (mocap.cs.cmu.edu), bản BVH của Bruce Hahne (cgspeed.com; bản trên GitHub: `una-dinosauria/cmu-mocap`). Tệp: `35_01` (đi), `09_01` (chạy), `16_33` (đứng) | Dùng tự do, kể cả trong sản phẩm bán; chỉ cấm bán lại chính dữ liệu. Ghi công: "The data used in this project was obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217." |
| Vung kiếm, ném, trúng đòn, nằm, ngồi, nhảy, cúi | KayKit Character Pack: Adventurers 1.0, Kay Lousberg (kaylousberg.com; GitHub `KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0`), động tác trong `Knight.glb` | CC0 |

## Chạy lại

1. Tải `Knight.glb` của KayKit vào một thư mục tạm trong project (ví dụ `_kk/`) và
   các tệp BVH CMU ở trên vào một thư mục bất kỳ.
2. Mở editor hoặc chạy `godot --headless --path . --import` để Godot nhập `Knight.glb`.
3. Với mỗi mô hình:
   ```bash
   godot --headless --path . -s Player/tools/retarget/bake_anim.gd -- \
       res://_kk/Knight.glb /duong/dan/bvh res://Player/models/ma_tu_vua.glb res://Player/anim/ma_tu.res
   godot --headless --path . -s Player/tools/retarget/bake_anim.gd -- \
       res://_kk/Knight.glb /duong/dan/bvh res://Player/models/de_tu_vua.glb res://Player/anim/de_tu.res
   ```
4. Xóa thư mục tạm, không commit tệp nguồn.

Ba mức chi tiết của cùng một mô hình dùng chung khung xương nên dùng chung thư viện.

## Cách chuyển

- Nguồn có dáng chữ T (KayKit: dáng gốc; CMU: khung đầu mỗi tệp). Xoay từng xương
  của mô hình cho cùng hướng với nguồn ở dáng T, rồi mỗi khung hình cộng đúng độ
  xoay toàn cục mà xương nguồn đã xoay. Tỉ lệ người khác nhau vẫn giữ đúng hướng
  tay chân.
- Đi, chạy: tự tìm một chu kỳ bước, bỏ quãng di chuyển (game tự dịch nhân vật),
  quay cho đi về +Z, cắt cho chu kỳ bắt đầu lúc chân trái ra trước xa nhất để đi và
  chạy cùng pha. Tốc độ gốc ghi vào meta `speed` (đơn vị mô hình / giây); game phát
  nhanh chậm theo tốc độ thật nên bàn chân không trượt.
- KayKit là người lùn đầu to (đứng dạng chân, tay xòe). Lấy dáng đứng của KayKit làm
  mốc ứng với dáng đứng CMU, chỉ chuyển phần lệch khỏi dáng đứng. Mỗi khung đặt
  hông cho mắt cá thấp nhất chạm đất.
- Thêm động tác: thêm một dòng vào `CLIPS`, chạy lại, rồi dùng tên đó trong
  `player_character.gd`.

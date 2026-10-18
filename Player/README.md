# Player (Thành viên B)

Điều khiển và trạng thái nhân vật. Cài đặt `EntityBase` và `InputSource`.

- `player_character.gd`: nhân vật tiên hiệp (ma tu áo đen đỏ cầm kiếm, 3 phi kiếm lơ lửng sau lưng; đệ tử áo trắng, một nửa số đệ tử có cánh lửa sau lưng). Mô hình có khung xương 17 xương (gắn bằng `tools/rig/`) cộng chuỗi xương tóc, tay áo, vạt áo sau đung đưa theo lò xo (`SpringBoneSimulator3D`), động tác lấy từ thư viện `anim/ma_tu.res`, `anim/de_tu.res` (chuyển sẵn sang khung xương bằng `tools/retarget/`, xem README ở đó): đứng, đi, chạy là mocap người thật (CMU), trộn theo tốc độ và phát nhanh chậm cho bàn chân không trượt; vung kiếm, ném, trúng đòn (chỉ thân trên, chân vẫn đi / chạy), gục nằm, ngồi trong tù, bay, ngồi xổm cạy rương lấy từ bộ KayKit Adventurers (CC0). Di chuyển 8 hướng có trọng lực; thợ săn bắn súng (ngắm tay hoặc tự nhắm), túm và kéo người gục; người trốn đỡ đồng đội; bị đệm lò xo hất qua tường (`server_launch`). Hình vẽ nội suy giữa hai lần tính vật lý nên mượt trên màn 90/120 Hz. Xem [docs/CHU_TRINH_BAT.md](../docs/CHU_TRINH_BAT.md)
- `shot_fx.gd`: hình phi kiếm và kiếm khí (pool): ma tu hóa ra thanh kiếm tím trên vai rồi phóng đi có vệt sáng (phù kiếm là thanh nhỏ màu ngọc), chạm người / tường / hết tầm thì nổ kiếm khí (chớp sáng, vòng khí, mảnh sáng); trúng người thật (`player_hit`) thì thêm vụ nổ lửa vàng cam to ở ngực người đó và thân người đó chớp đỏ; chỉ để nhìn, server tính trúng
- `follow_camera.gd`: camera nhìn chéo bám nhân vật của máy này; đã thoát hoặc bị loại thì xem người còn chơi (Tab / nút xanh để đổi người)
- `local_input_source.gd`: bàn phím và nút cảm ứng (WASD / mũi tên, E / Space tương tác, chuột phải ngắm, 1-5 dùng thẻ, Tab đổi người xem); hướng kéo thẻ gửi trong `aim`
- `models/`: mô hình ma tu / đệ tử của dự án, mỗi nhân vật 3 file theo mức đồ họa: `*_thap.glb` (~4,5k tam giác, texture 512, nướng lại UV), `*_vua.glb` (~10k, 1024), `*_cao.glb` (lưới gốc ~31k, texture 2048 + normal map 1024). Gốc ở chân, cao 1 đơn vị, nhìn về +Z; `player_character.gd` chọn file theo ProjectSettings `game/graphics_quality` (UI ghi)

Tiếp theo: dash (phím Shift đã gán, chưa có luật), nhảy / vượt tường thấp.
Đổi trạng thái nhân vật luôn qua các lệnh `GameState.server_*()`.

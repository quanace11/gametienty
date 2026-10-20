# Player (Thành viên B)

Điều khiển và trạng thái nhân vật. Cài đặt `EntityBase` và `InputSource`.

- `player_character.gd`: thợ săn là ma tu của dự án (`models/ma_tu/`), người trốn là kiếm tu (đệ tử) của dự án (`models/de_tu/`). Cả hai dùng khung xương và động tác có sẵn trong tệp, đặt thẳng lên xương mỗi frame: đứng, đi, chạy trộn theo tốc độ cùng một pha bước; chém, ném, trúng đòn chỉ ở thân trên (chân vẫn đi / chạy); gục thì bò (chỉ cử động khi đang bò đi), bị kéo thì nằm, ngồi trong tù, bay, cúi cạy rương. Di chuyển 8 hướng có trọng lực; thợ săn bắn súng (ngắm tay hoặc tự nhắm), túm và kéo người gục; người trốn đỡ đồng đội; bị đệm lò xo hất qua tường (`server_launch`). Hình vẽ nội suy giữa hai lần tính vật lý nên mượt trên màn 90/120 Hz. Xem [docs/CHU_TRINH_BAT.md](../docs/CHU_TRINH_BAT.md)
- `shot_fx.gd`: hình phi kiếm và kiếm khí (pool): ma tu hóa ra thanh kiếm tím trên vai rồi phóng đi có vệt sáng (phù kiếm là thanh nhỏ màu ngọc), chạm người / tường / hết tầm thì nổ kiếm khí (chớp sáng, vòng khí, mảnh sáng); trúng người thật (`player_hit`) thì thêm vụ nổ lửa vàng cam to ở ngực người đó và thân người đó chớp đỏ; chỉ để nhìn, server tính trúng
- `follow_camera.gd`: camera nhìn chéo bám nhân vật của máy này; đã thoát hoặc bị loại thì xem người còn chơi (Tab / nút xanh để đổi người)
- `local_input_source.gd`: bàn phím và nút cảm ứng (WASD / mũi tên, E / Space tương tác, chuột phải ngắm, 1-5 dùng thẻ, Tab đổi người xem); hướng kéo thẻ gửi trong `aim`
- `models/ma_tu/`: ma tu (thợ săn) của dự án, gắn xương bằng AccuRig, động tác KayKit chuyển sẵn sang khung xương của nó (`tools/retarget/`). Mỗi mức đồ họa một tệp: `ma_tu_thap.glb` (~6k tam giác), `ma_tu_vua.glb` (~20k), `ma_tu_cao.glb` (~60k); `player_character.gd` chọn theo ProjectSettings `game/graphics_quality` (UI ghi). Màu lấy từ mô hình gốc tạo bằng Rodin (cùng UV): Thấp ảnh màu 512, Vừa 1024, Cao 2048 + normal map 1024.
- `models/de_tu/`: kiếm tu (người trốn), làm y như ma tu: gắn xương AccuRig, động tác lấy từ Mage của KayKit (đi, chạy, ném thẻ, trúng đòn, bị kéo, ngồi tù, bay, cúi cạy rương) cộng thêm gục bò (Crawl) tự dựng. `de_tu_thap.glb` ~6k tam giác, `de_tu_vua.glb` ~20k (giảm bằng Blender vì lưới nhiều đường nối UV, xem `tools/retarget/README.md`), `de_tu_cao.glb` ~60k; ảnh màu 512 / 1024 / 2048, Cao thêm normal map 1024
- `models/kaykit/`: Barbarian, Mage của KayKit Adventurers (CC0), chỉ để lấy động tác khi chuyển sang ma tu / kiếm tu, game không nạp

Tiếp theo: dash (phím Shift đã gán, chưa có luật), nhảy / vượt tường thấp.
Đổi trạng thái nhân vật luôn qua các lệnh `GameState.server_*()`.

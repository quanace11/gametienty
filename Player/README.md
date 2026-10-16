# Player (Thành viên B)

Điều khiển và trạng thái nhân vật. Cài đặt `EntityBase` và `InputSource`.

- `player_character.gd`: nhân vật chibi KayKit (thợ săn Rogue trùm đầu, người trốn hiệp sĩ) có animation chạy, đứng, gục, ngồi tù, bay, bắn, trúng đạn, ném, ngồi mò khóa khi cạy rương. Di chuyển 8 hướng có trọng lực; thợ săn bắn súng (ngắm tay hoặc tự nhắm), túm và kéo người gục; người trốn đỡ đồng đội; bị đệm lò xo hất qua tường (`server_launch`). Hình vẽ nội suy giữa hai lần tính vật lý nên mượt trên màn 90/120 Hz. Xem [docs/CHU_TRINH_BAT.md](../docs/CHU_TRINH_BAT.md)
- `shot_fx.gd`: hình đạn và vụ nổ (pool): tên lửa có lửa đuôi, chạm người / tường / hết tầm thì nổ (chớp vàng, cầu lửa, khói); chỉ để nhìn, server tính trúng
- `follow_camera.gd`: camera nhìn chéo bám nhân vật của máy này; đã thoát hoặc bị loại thì xem người còn chơi (Tab / nút xanh để đổi người)
- `local_input_source.gd`: bàn phím và nút cảm ứng (WASD / mũi tên, E / Space tương tác, chuột phải ngắm, 1-5 dùng thẻ, Tab đổi người xem); hướng kéo thẻ gửi trong `aim`
- `models/`: model + animation KayKit (CC0)

Tiếp theo: dash (phím Shift đã gán, chưa có luật), nhảy / vượt tường thấp.
Đổi trạng thái nhân vật luôn qua các lệnh `GameState.server_*()`.

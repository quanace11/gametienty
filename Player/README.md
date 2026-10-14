# Player (Thành viên B)

Điều khiển và trạng thái nhân vật. Cài đặt `EntityBase` và `InputSource`.

- `player_character.gd`: nhân vật 3D (capsule tạm), di chuyển 8 hướng có trọng lực, quay mặt theo hướng chạy; bản mẫu chu trình bắt: đánh hình nón, túm và kéo người gục, đỡ đồng đội, bị đệm lò xo hất bay qua tường (`server_launch`) (xem docs/CHU_TRINH_BAT.md)
- `shot_fx.gd`: hình đạn và vụ nổ (pool): súng thợ săn bắn tên lửa có lửa đuôi, chạm người / tường / hết tầm thì nổ (chớp vàng, cầu lửa, khói); chỉ để nhìn, server tính trúng
- `follow_camera.gd`: camera nhìn chéo bám theo nhân vật của máy này
- `local_input_source.gd`: bàn phím (WASD/mũi tên, E/Space tương tác, Shift dash, Q/R kỹ năng)

Tiếp theo: model + AnimationTree, dash, nhảy/vượt tường thấp, anim sync qua `get_snapshot()`/`apply_snapshot()`.
Đổi trạng thái nhân vật luôn qua các lệnh `GameState.server_*()` (xem docs/CHU_TRINH_BAT.md).

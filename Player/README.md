# Player (Thành viên B)

Điều khiển và trạng thái nhân vật. Cài đặt `EntityBase` và `InputSource`.

- `player_character.gd`: nhân vật 3D (capsule tạm), di chuyển 8 hướng có trọng lực, quay mặt theo hướng chạy, tốc độ/hitbox khác nhau theo vai, thợ săn chạm là nhốt (tạm thời)
- `follow_camera.gd`: camera nhìn chéo bám theo nhân vật của máy này
- `local_input_source.gd`: bàn phím (WASD/mũi tên, E/Space tương tác, Shift dash, Q/R kỹ năng)

Tiếp theo: model + AnimationTree, dash, nhảy/vượt tường thấp, đòn đánh của thợ săn -> `DOWNED` -> vác -> nhà tù, cứu đồng đội, anim sync qua `get_snapshot()`/`apply_snapshot()`.
Đổi trạng thái nhân vật luôn qua `GameState.server_set_player_state()`.

# Player (Thành viên B)

Điều khiển và trạng thái nhân vật. Cài đặt `EntityBase` và `InputSource`.

- `player_character.gd`: di chuyển 8 hướng, tốc độ/hitbox khác nhau theo vai, thợ săn chạm là nhốt (tạm thời)
- `local_input_source.gd`: bàn phím (WASD/mũi tên, E/Space tương tác, Shift dash, Q/R kỹ năng)

Tiếp theo: dash, vượt tường thấp, đòn đánh của thợ săn -> `DOWNED` -> vác -> nhà tù, cứu đồng đội, anim sync qua `get_snapshot()`/`apply_snapshot()`.
Đổi trạng thái nhân vật luôn qua `GameState.server_set_player_state()`.

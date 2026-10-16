# Items (Thành viên C)

Thẻ đạo cụ trong bộ bài. Luật chung (giá, hồi chiêu, khi nào dùng được) nằm ở Core; module này chỉ làm hiệu ứng. Đọc [docs/LUAT_TRAN.md](../docs/LUAT_TRAN.md#7-thẻ-đạo-cụ-bộ-bài).

- `item_catalog.gd`: bảng thẻ (tên, giá, hồi chiêu, tầm kéo `aim_range`, bán kính `area`, file hiệu ứng) và bộ bài mặc định
- `effects/*.gd`: hiệu ứng từng thẻ (extends `ItemEffect`): `plan()` chọn mục tiêu, `server_apply()` gọi `GameState.server_*()`; `aim_point.gd` tính chỗ rơi từ hướng kéo thẻ
- `placed/*.gd`: vật thể đặt xuống đất (bẫy kẹp, đệm lò xo, hộp gỗ, túi cứu nằm chờ đón), phần luật chạy trên server trong chính node
- `item_visuals.gd`: hiệu ứng ném (túi máu bay vòng, lựu đạn, vùng xanh, cột sáng) lấy từ pool, dựng / xóa vật thể theo `EventBus`
- `medkit_mesh.gd`: trận bàn hồi phục (đĩa đồng mặt ngọc) và 5 lá cờ ngũ hành dựng bằng code, dùng chung. Ném ra thì trận bàn xoay bay tới, rơi xuống bày vòng hồi máu có 5 cờ mọc quanh mép (`item_visuals.gd`); nằm chờ thì đĩa lơ lửng giữa vòng cờ nhỏ (`placed/medkit_node.gd`)

Thẻ của thợ săn (`allowed_roles = [HUNTER]`, 0 xu): radar dấu chân (`effects/radar.gd`) và dịch chuyển (`effects/teleport.gd`, tới điểm đã chạm trên minimap, chưa chạm thì tới rương đang mở nhiều nhất). `ItemCatalog.choices(role)` cho màn chọn bài.

Súng lục (`effects/pistol.gd`) dùng khung đạn bay của Core (`GameState.server_shoot_bullet`), đường bay do nhân vật vẽ theo `shot_fired`.

Tiếp theo: hóa trang, icon thẻ, âm thanh khi ném / nổ.

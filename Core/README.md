# Core (Thành viên A, Lead)

Xương sống của game. **Không sửa khi chưa có Lead duyệt.**

- `types/`: enum, `ItemData`, `MatchConfig`
- `event_bus.gd`: tín hiệu chung (autoload `EventBus`)
- `game_state.gd`: trạng thái trận, API `server_*` (autoload `GameState`)
- `match/match_rules.gd`: luật thắng thua thuần logic; `match/match.gd`: dựng trận, đồng bộ input/vị trí
- `network/`: phòng, offline, input qua mạng (autoload `Net`)
- `interfaces/`: `EntityBase`, `InputSource`, `Interactable`, `ItemEffect`, `MapBase`
- `module_registry.gd`: chọn bản cài đặt của từng module

Đã có: enum, EventBus, GameState, offline + host + server riêng, rương + vòng căn (bù trễ), tiền, 2 cổng mở trễ, chu trình bắt (gục, kéo, tù, cứu), đạn bay thật, bộ bài + vật đặt xuống đất, bụi cây (`can_see`, không gửi vị trí người nấp), kết quả riêng từng người.
Tiếp theo: gộp dữ liệu rương gửi xuống còn 10 lần/giây khi có người cạy; đo băng thông và CPU trận online; đoán trước di chuyển, phòng có mã, vào lại khi rớt mạng.

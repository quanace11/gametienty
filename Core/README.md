# Core (Thành viên A, Lead)

Xương sống của game. **Không sửa khi chưa có Lead duyệt.**

- `types/`: enum, `ItemData`, `MatchConfig`
- `event_bus.gd`: tín hiệu chung (autoload `EventBus`)
- `game_state.gd`: trạng thái trận, API `server_*` (autoload `GameState`)
- `match/match_rules.gd`: luật thắng thua thuần logic; `match/match.gd`: dựng trận, đồng bộ input/vị trí
- `network/`: phòng, offline, input qua mạng (autoload `Net`)
- `interfaces/`: `EntityBase`, `InputSource`, `Interactable`, `MapBase`
- `module_registry.gd`: chọn bản cài đặt của từng module

Đã có: enum, EventBus, GameState, đếm giờ, đếm két, thắng/thua, offline + host + server riêng.
Tiếp theo: thêm tín hiệu/trạng thái khi các module cần (DOWNED, vác, nhà tù, cứu).

# CLAUDE.md

Bối cảnh cho Claude Code và mọi thành viên. Đọc hết trước khi sửa code.

## Dự án

Game rượt đuổi bất đối xứng 1 Thợ săn (Hunter) vs 4 Người trốn (Escapee), kiểu 逃跑吧!少年. Người trốn mở két, đủ két thì cổng thoát mở; thợ săn bắt và nhốt người trốn. Mục tiêu 4 tuần: một trận 1v4 offline trọn vẹn với bot, chọn được vai.

- Engine: **Godot 4.6.x**, ngôn ngữ **GDScript** (không dùng C#).
- **3D**, camera nhìn chéo từ trên xuống. Đơn vị: 1 = 1 mét, trục Y hướng lên, mặt sàn là (x, z). Renderer `gl_compatibility` (chạy được máy yếu và điện thoại).
- Giai đoạn hiện tại: **offline** (1 người + 4 bot), nhưng code luôn chạy theo mô hình client-server để lên online không phải viết lại. Đọc [docs/KIEN_TRUC.md](docs/KIEN_TRUC.md) trước khi code.
- Mạng: multiplayer có sẵn của Godot (ENet). Chưa dùng server trả phí.

## Kiến trúc: Strict Client-Server (Local Host)

Luôn có một **server có thẩm quyền** (peer id 1). Server có thể là:
1. Máy chơi offline (`OfflineMultiplayerPeer`): người chơi + bot đều chạy trên server cục bộ.
2. Máy người chơi làm chủ phòng (host).
3. Server riêng không chơi (`--server`), sau này thuê VPS.

Cả 3 chạy **cùng một đường code**. Quy tắc:
- **Chỉ server quyết định luật**: di chuyển thật, bắt người, mở két, thoát, thắng thua.
- Client chỉ gửi **input** (`InputSource`: hướng + nút bấm) và vẽ lại những gì server gửi xuống.
- Đổi trạng thái trận **chỉ qua `GameState.server_*()`**. GameState gửi xuống mọi máy rồi phát `EventBus`. Không tự emit tín hiệu nhóm 1 của EventBus.
- Code luật chạy trên server phải được bọc trong `multiplayer.is_server()` hoặc nằm trong các hàm chỉ server gọi (`server_move`, `interact_tick`).
- Không tin dữ liệu client: luôn kẹp giá trị (ví dụ `limit_length(1.0)`).
- Bot là nhân vật có id âm (-1, -2...), chạy trên server, được điều khiển bằng `BotInputSource` thay cho bàn phím.
- Gameplay **không đọc `Input` trực tiếp**, chỉ đọc `InputSource` được truyền vào. Hiệu ứng/âm thanh/HUD chạy theo tín hiệu `EventBus`.
- **Không viết `if offline:`** trong code gameplay. Danh sách đầy đủ những thứ cấm: [docs/KIEN_TRUC.md](docs/KIEN_TRUC.md#những-thứ-cấm-sẽ-làm-hỏng-online).

## Module và quyền sở hữu

```
/project_root
├── CLAUDE.md
├── main.tscn       # gốc game, script Core/main.gd
├── Core/           # Lead (A). DO NOT TOUCH nếu chưa có Lead duyệt
├── Player/         # B: Controller, Input, Anim Sync
├── Objects/        # C: Két, Cổng, Cửa, Bẫy, Nhà tù, bản đồ
├── Items/          # C: Thẻ, Kỹ năng, Hóa trang, Vật phẩm
├── AI/             # D: Bot, Behavior Tree, Giác quan, NavMesh
├── UI/             # HUD, Spectate, Minimap, Menu
├── tests/          # test thuần logic
└── docs/
```

### Luật bất khả xâm phạm

1. **Không sửa file của module khác.** Chỉ dùng API công khai của Core (danh sách bên dưới) và group/tín hiệu đã định nghĩa.
2. **Không gọi thẳng hàm của module khác.** Module A muốn báo module B thì qua `EventBus` hoặc qua interface trong `Core/interfaces/`.
3. **Không sửa `Core/`** khi chưa có Lead duyệt. Cần thêm enum, tín hiệu, hàm `server_*` hay interface mới: mở issue/PR riêng cho Core, ghi rõ lý do.
4. Module chọn bản cài đặt qua `Core/module_registry.gd`. Chỉ Lead sửa file này.
5. Nếu task yêu cầu vi phạm các luật trên: **dừng lại và hỏi**, đừng tự làm.

## API công khai của Core

| Thứ | File | Dùng để |
|---|---|---|
| `GameTypes` | `Core/types/game_types.gd` | Enum `Role`, `PlayerState`, `MatchState`, `Winner`, `ItemType`; tên group |
| `ItemData`, `MatchConfig` | `Core/types/` | Dữ liệu vật phẩm, thông số trận |
| `EventBus` (autoload) | `Core/event_bus.gd` | Tín hiệu chung |
| `GameState` (autoload) | `Core/game_state.gd` | `rules` (đọc), `server_set_player_state()`, `server_set_safe_progress()`, `my_role()` |
| `MatchRules` | `Core/match/match_rules.gd` | Luật thuần logic, đọc qua `GameState.rules` |
| `Net` (autoload) | `Core/network/net.gd` | Tạo/vào phòng, offline, bắt đầu trận |
| `EntityBase` | `Core/interfaces/entity_base.gd` | Lớp cha của mọi nhân vật |
| `InputSource` | `Core/interfaces/input_source.gd` | Nguồn điều khiển (bàn phím, mạng, bot) |
| `Interactable` | `Core/interfaces/interactable.gd` | Lớp cha của két, cổng, nhà tù... |
| `MapBase` | `Core/interfaces/map_base.gd` | Lớp cha của bản đồ |

Group để tìm nhau (hằng trong `GameTypes`): `entities`, `safes`, `exit_gates`, `prisons`.

Layer va chạm: 1 = sàn/tường/vật cản, 2 = nhân vật. Nhân vật không chặn nhau.
Gốc nhân vật đặt dưới chân. `EntityBase.flat_position()` trả vị trí trên mặt sàn (x, z) để tính khoảng cách.

## Quy ước code

Theo [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html):
- File, hàm, biến, tín hiệu: `snake_case`. `class_name` và tên node: `PascalCase`. Hằng và giá trị enum: `CONSTANT_CASE`.
- Tên tín hiệu ở thì quá khứ: `gate_opened`, `player_downed`.
- **Bắt buộc gõ kiểu tĩnh** (`var speed := 200.0`, `func f(x: int) -> void`).
- Hàm/biến riêng tư bắt đầu bằng `_`. Hàm chỉ server gọi đặt tên `server_*`.
- Thụt lề bằng tab. Mỗi file có một dòng `##` mô tả ở đầu.
- Hàm RPC: `@rpc("authority", ...)` cho server -> client; `@rpc("any_peer", ...)` cho client -> server và **phải kiểm tra người gửi**.
- Override `_ready()` của lớp có sẵn `_ready()` (như `Interactable`) thì gọi `super()`.
- Comment và chữ trong game viết tiếng Việt có dấu.
- Không thêm addon/plugin khi chưa có Lead duyệt.

## Chạy và kiểm tra

Cần Godot 4.6.x. Trong editor: Debug > Customize Run Instances để bật nhiều cửa sổ.

```bash
# Kiểm tra toàn bộ: test luật + trận offline + trận online 3 máy (CI chạy y hệt)
GODOT=/duong/dan/godot tools/smoke_test.sh
# Từng bước riêng:
godot --headless --path . -s tests/test_match_rules.gd
# Một trận offline do bot chơi hết, in kết quả rồi thoát
godot --headless --path . -- --offline=escapee --bot --time=60 --quit-after-match
# Online: 1 server + 2 client bot + bot lấp chỗ
godot --headless --path . -- --server --auto-start=2 --fill-bots --quit-after-match &
godot --headless --path . -- --join=127.0.0.1 --bot --quit-after-match &
godot --headless --path . -- --join=127.0.0.1 --bot --quit-after-match
```

Trước khi mở PR: `tools/smoke_test.sh` phải qua. GitHub Actions chạy lại trên mỗi push/PR; CI đỏ thì không merge.

## Git

- Nhánh theo module: `core/...`, `player/...`, `objects/...`, `items/...`, `ai/...`, `ui/...` (ví dụ `player/dash`).
- Mỗi PR chỉ chạm thư mục của module mình. PR chạm `Core/` cần Lead duyệt.
- Không commit thư mục `.godot/`.

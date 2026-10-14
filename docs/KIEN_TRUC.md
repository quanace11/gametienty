# Kiến trúc: làm offline trước, lên online không phải viết lại

Tài liệu này giải thích **vì sao** code được tổ chức như hiện tại và **những gì phải tuân theo** để bản offline hôm nay chạy online được sau này. Ai mới vào dự án, đọc file này sau README.

## 1. Vấn đề

Đội làm bản offline trước (1 người + 4 bot) vì an toàn và không tốn tiền server. Cách làm offline "thông thường" là: đọc phím, di chuyển nhân vật, kiểm tra va chạm, cộng điểm, tất cả trong cùng một chỗ. Khi lên online, cách đó phải đập đi vì online cần:

- một máy duy nhất quyết định chuyện gì xảy ra (nếu không mỗi máy thấy một kiểu, và người chơi gian lận được);
- tách "người chơi muốn làm gì" (input) khỏi "chuyện gì thực sự xảy ra" (luật);
- gửi kết quả cho mọi máy.

## 2. Giải pháp: offline chính là online với một máy

Ngay từ bây giờ, game **luôn chạy theo mô hình client-server**, kể cả khi chơi offline:

```
          CLIENT (máy người chơi)                     SERVER (có thẩm quyền)
 ┌───────────────────────────────────┐       ┌──────────────────────────────────────┐
 │ Bàn phím / cảm ứng                │       │                                      │
 │   -> LocalInputSource             │ input │ NetworkInputSource / BotInputSource  │
 │      (hướng, nút, góc camera) ────┼──────>│   -> EntityBase.server_move()        │
 │                                   │       │   -> Interactable.interact_tick()    │
 │                                   │       │   -> GameState.server_*()  (luật)    │
 │                                   │ sự    │                                      │
 │ EventBus  <- GameState  <─────────┼───────┤ GameState gửi sự kiện (tin cậy)      │
 │ apply_snapshot() <────────────────┼───────┤ get_snapshot() 20 lần/giây           │
 │   -> vẽ, anim, âm thanh, HUD      │ vị trí│                                      │
 └───────────────────────────────────┘       └──────────────────────────────────────┘
```

Ba cách chạy, **cùng một code**, chỉ khác "đường dây" giữa hai khối:

| Chế độ | Server là ai | Đường dây | Lúc nào dùng |
|---|---|---|---|
| Offline | Chính máy mình (`OfflineMultiplayerPeer`) | Gọi hàm trực tiếp trong cùng tiến trình | Bây giờ, 4 tuần đầu |
| Host / LAN | Máy một người chơi | ENet qua mạng LAN/Internet | Test với bạn bè, đã chạy được |
| Server riêng | Máy chủ thuê (VPS), không có người chơi | ENet qua Internet | Khi phát hành |

Bot luôn chạy trên server, giống hệt người chơi, chỉ khác nguồn input (`BotInputSource` thay cho bàn phím). Vì vậy bot làm cho offline cũng dùng luôn để lấp chỗ trong phòng online.

## 3. Năm luật vàng (bắt buộc với mọi module)

1. **Luật chỉ chạy trên server.** Di chuyển thật, trúng đòn, mở két, bắt người, thắng thua: chỉ trong `server_move()`, `interact_tick()` hoặc code bọc `multiplayer.is_server()`. Client chỉ vẽ.
2. **Gameplay không đọc bàn phím trực tiếp.** Không gọi `Input.is_action_pressed()` trong code luật. Luôn đọc qua `InputSource` được truyền vào. Nút mới thì thêm vào `InputSource.ACTIONS` (cần Lead duyệt).
3. **Đổi trạng thái chỉ qua `GameState.server_*()`.** Không tự gán `state = ...` hay tự emit tín hiệu nhóm 1 của `EventBus`. GameState lo gửi xuống mọi máy.
4. **Hiệu ứng nghe theo `EventBus`, không tự đoán.** Âm thanh, hạt, rung, HUD: nghe tín hiệu (`player_imprisoned`, `gate_opened`...) để chạy, vì tín hiệu đó đến trên mọi máy khi server xác nhận.
5. **Không có chữ "offline" trong code gameplay.** Không viết `if offline:`. Nếu thấy cần, nghĩa là thiết kế đang sai, hỏi Lead.

### Những thứ cấm (sẽ làm hỏng online)

| Đừng làm | Vì sao | Làm thế này |
|---|---|---|
| `Input.is_action_pressed()` trong luật | Server không có bàn phím của client | `input.is_pressed(&"interact")` |
| `randf()` quyết định kết quả trên client | Mỗi máy ra một số khác | Random trên server, gửi kết quả xuống |
| Timer/`await` trên client quyết định thắng thua | Client lệch giờ, có thể gian lận | Đếm trên server, client chỉ hiển thị |
| `get_tree().paused` để dừng gameplay | Online không ai dừng được thế giới của người khác | Trạng thái trận trong `MatchRules` |
| Biến toàn cục giữ trạng thái gameplay ngoài `GameState` | Không được đồng bộ | Thêm vào `MatchRules`, đề xuất với Lead |
| Gọi `multiplayer.get_unique_id()` trong luật để tìm "người chơi chính" | Server riêng không có người chơi | Dùng `peer_id` của nhân vật |
| Truyền node/Object qua RPC | Không gửi qua mạng được | Gửi id (`peer_id`, `interactable_id`) |

## 4. Ví dụ cho từng loại tính năng

**Két có QTE (Objects):** server quyết định lúc nào QTE xuất hiện và gửi xuống người đang mở két. Vòng tròn QTE là UI ở client. Người chơi bấm thì gửi nút `interact` lên như input bình thường. Server so thời điểm bấm với cửa sổ QTE (cho phép trễ khoảng 150 ms vì mạng), quyết định đúng/sai rồi phát `qte_failed`. Bot bấm QTE cũng đi qua `InputSource` như vậy.

**Hóa trang (Items):** người chơi bấm `skill_1`, server kiểm tra cooldown, đổi trạng thái hóa trang, gửi xuống. Client nhận và đổi model thành cái thùng. Không client nào tự đổi model của mình trước khi server đồng ý.

**Thợ săn đánh (Player):** server tính hitbox trước mặt thợ săn tại thời điểm nhận input rồi gọi `GameState.server_attack(hunter_id, targets)`; Core lo hồi chiêu, trừ máu, ngã (xem [CHU_TRINH_BAT.md](CHU_TRINH_BAT.md)). Client phát anim vung tay ngay khi bấm (cho cảm giác nhanh) nhưng chỉ hiện hiệu ứng trúng khi nhận `player_downed`.

**Bot (AI):** bot là `InputSource`. Nó đọc thế giới (vị trí, két, `GameState.rules`) và trả về hướng đi + nút bấm. Nó không bao giờ tự dịch chuyển nhân vật hay đổi trạng thái.

**Anim (Player):** server đưa thông tin anim vào `get_snapshot()` (tốc độ, đang bò, đang vác...). Client dựng anim từ đó trong `apply_snapshot()` / `client_update()`.

## 5. Lộ trình lên online và phần nào phải sửa

| Giai đoạn | Việc | Phần code bị sửa | Phần KHÔNG phải sửa |
|---|---|---|---|
| 0. Offline (bây giờ) | Gameplay, bot, bản đồ | Mọi module | |
| 1. Host / LAN | Đã chạy được. Chỉ cần test thường xuyên | Không | Mọi module |
| 2. Server riêng (VPS) | Export bản Linux "Dedicated Server", chạy `--server` | Cấu hình export | Mọi module |
| 3. Chơi qua Internet mượt | Dự đoán phía client cho nhân vật của mình, bộ đệm nội suy, bù độ trễ cho đòn đánh | `Core/match/`, `Player/` (phần client) | Objects, Items, AI, luật |
| 4. Nhiều phòng, nhiều người | Mỗi phòng một tiến trình server, dịch vụ ghép trận, tài khoản | Thêm dịch vụ mới bên ngoài game, `Core/network/` | Gameplay |

Tức là nếu giữ đúng năm luật vàng, lên online chỉ đụng tới `Core/` và phần hiển thị của `Player/`, không đụng tới két, vật phẩm, bot hay luật thắng thua.

## 6. Hàng rào tự động

`tools/smoke_test.sh` chạy trên GitHub Actions mỗi lần push:

1. test luật thuần logic (`tests/`);
2. một trận offline do bot chơi;
3. **một trận online thật**: 1 server riêng + 2 client qua mạng + bot lấp chỗ, và kiểm tra mọi máy thấy cùng một kết quả.

Bước 3 chạy ngay cả khi đội chỉ đang làm offline. Ai lỡ viết code chỉ chạy được offline thì CI đỏ ngay, không phải đợi tới lúc lên online mới biết.

Chạy trên máy mình: `GODOT=/duong/dan/godot tools/smoke_test.sh`

## 7. Chi phí

| Giai đoạn | Chi phí server |
|---|---|
| 0 - 1 | 0 đồng (offline, LAN, nhiều cửa sổ trên một máy) |
| 2 | 1 VPS Linux nhỏ, khoảng 5 USD/tháng, đủ cho vài phòng 5 người cùng lúc |
| 4 | Tăng theo số phòng chơi cùng lúc; tính khi có người chơi thật |

GitHub Actions miễn phí cho repo công khai và có hạn mức miễn phí hàng tháng cho repo riêng tư.

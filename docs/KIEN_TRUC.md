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
| Gọi `multiplayer.get_unique_id()` để tìm "người chơi chính" hay "nhân vật của mình" | Server riêng không có người chơi; vào lại giữa trận thì peer id đổi | Luật: `peer_id` của nhân vật (là số ghế). Hiển thị: `GameState.my_id()` |
| Truyền node/Object qua RPC | Không gửi qua mạng được | Gửi id (`peer_id`, `interactable_id`) |

## 4. Ví dụ cho từng loại tính năng

**Rương có vòng căn (Objects, đã làm):** server quyết định lúc nào vòng hiện ra và vùng sáng ở đâu, gửi xuống trong `PlayerRecord`. Vòng là UI ở client. Người chơi bấm thì gửi nút `interact` lên như input bình thường. Server lùi kim lại đúng độ trễ đo được của máy đó (kẹp tối đa), chấm đúng/sai rồi phát `qte_resolved`. Bot bấm cũng đi qua `InputSource`. Chi tiết: [LUAT_TRAN.md](LUAT_TRAN.md).

**Hóa trang (Items):** người chơi bấm `skill_1`, server kiểm tra cooldown, đổi trạng thái hóa trang, gửi xuống. Client nhận và đổi model thành cái thùng. Không client nào tự đổi model của mình trước khi server đồng ý.

**Thợ săn bắn (Player):** client gửi hướng ngắm trong gói input (`InputSource.get_aim()`, 2 số float, 0 = tự nhắm) cùng nút `shoot`; server chọn điểm ngắm tại thời điểm nhận input rồi gọi `GameState.server_fire_rifle(hunter, target)`; Core raycast một lần tìm tường, ghi viên đạn, tới giờ thì xét người đầu tiên trên đường bay theo vị trí trên server, trừ máu, ngã (xem [LUAT_TRAN.md](LUAT_TRAN.md#8-bắn-súng-của-thợ-săn-súng-lục-của-người-trốn)). Đạn chỉ gửi xuống client hai lần (lúc bắn, lúc tới); client tự vẽ đường bay.

**Bot (AI):** bot là `InputSource`. Nó đọc thế giới (vị trí, két, `GameState.rules`) và trả về hướng đi + nút bấm. Nó không bao giờ tự dịch chuyển nhân vật hay đổi trạng thái.

**Anim (Player):** server đưa thông tin anim vào `get_snapshot()` (tốc độ, đang bò, đang kéo người...). Client dựng anim từ đó trong `apply_snapshot()` / `client_update()`.

## 5. Lộ trình lên online và phần nào phải sửa

| Giai đoạn | Việc | Phần code bị sửa | Phần KHÔNG phải sửa |
|---|---|---|---|
| 0. Offline (trận 1v4 với bot đã xong, đang hoàn thiện) | Gameplay, bot, bản đồ | Mọi module | |
| 1. Host / LAN | Đã chạy được. Chỉ cần test thường xuyên | Không | Mọi module |
| 2. Server riêng (VPS) | Export bản Linux "Dedicated Server", chạy `--server` | Cấu hình export | Mọi module |
| 3. Chơi qua Internet mượt | Dự đoán phía client cho nhân vật của mình (chờ test cảm giác trên máy thật). Đã có: bộ đệm nội suy, cú bấm có giờ, bù trễ vòng căn và bắn, rớt mạng vào lại | `Core/match/`, `Player/` (phần client) | Objects, Items, AI, luật |
| 4. Nhiều phòng, nhiều người | Mỗi phòng một tiến trình server, dịch vụ ghép trận, tài khoản | Thêm dịch vụ mới bên ngoài game, `Core/network/` | Gameplay |

Việc của từng tuần: mục Kế hoạch trong [README](../README.md#kế-hoạch). Online (các bước 2-4 dưới đây) để sang giai đoạn 2, sau khi xong bản offline.

Tức là nếu giữ đúng năm luật vàng, lên online chỉ đụng tới `Core/` và phần hiển thị của `Player/`, không đụng tới két, vật phẩm, bot hay luật thắng thua.

## 5b. Ghế, rớt mạng, vào lại

- Mỗi người chơi giữ một **ghế** suốt trận: số ghế là peer id lúc vào phòng, bot là số âm. `peer_id` của nhân vật, khóa trong `MatchRules` đều là số ghế. `Net.seat_of(peer)` / `Net.peer_of(seat)` đổi qua lại.
- Rớt mạng giữa trận (kể cả thợ săn): ghế giữ **tới hết trận**, bot chơi thay đúng nhân vật đó. Máy vào lại (mã vào lại cấp lúc vào phòng) tiếp quản trạng thái hiện tại: không hồi máu, không đặt lại hồi chiêu, không sống lại. Nhân vật đã bị loại thì chỉ xem.
- Chủ phòng (host) tắt máy thì trận kết thúc, không tính kết quả: bot không thay được server.
- Vào trận có pha **chờ tải** (`MatchState.LOADING`): server chờ mọi máy dựng xong (tối đa 20 giây, máy chậm thì bot đứng thay) rồi mới đếm ngược. Đồng hồ trận gửi 2 lần/giây, client trừ trễ đo được.
- Server gửi cho từng máy **chỉ những gì máy đó được thấy**: vị trí người trong bụi phe kia, bộ bài / tiền / vòng căn của phe kia, vật đặt chưa lộ đều không gửi.
- Cú bấm: client ghi mỗi lần bấm thành sự kiện có số thứ tự và giờ bấm, gửi lặp tới khi server xác nhận. Server chấm vòng căn theo giờ bấm nhưng chỉ tin trong ±40 ms quanh ước tính của mình.
- Thông số trận: `Core/config/match_config.tres` (chỉnh trong Inspector), server đọc rồi gửi xuống client dạng mảng số.
- Log: `GameLog.info()` in kèm giờ, mã trận, số ghế; server riêng ghi ra `user://logs/`. Mã trận và hạt giống random in lúc vào trận để dò lỗi.
- Khác `Net.PROTOCOL_VERSION` thì không vào được phòng. Tăng số này mỗi khi đổi gói tin.

## 6. Hàng rào tự động

`tools/smoke_test.sh` chạy trên GitHub Actions mỗi lần push:

1. test luật thuần logic (`tests/`);
2. một trận offline do bot chơi;
3. **một trận online thật**: 1 server riêng + 2 client qua mạng + bot lấp chỗ, và kiểm tra mọi máy thấy cùng một kết quả;
4. trận online qua mạng xấu (`tools/udp_proxy.py`: ping 150 ms, mất 3% gói);
5. thợ săn đứng yên (`--idle-hunter`): người trốn phải mở được cổng và thoát;
6. một client rớt mạng 12 giây giữa trận: bot chơi thay rồi client vào lại đúng ghế.

Bước 3 chạy ngay cả khi đội chỉ đang làm offline. Ai lỡ viết code chỉ chạy được offline thì CI đỏ ngay, không phải đợi tới lúc lên online mới biết.

Chạy trên máy mình: `GODOT=/duong/dan/godot tools/smoke_test.sh`

## 7. Chi phí

| Giai đoạn | Chi phí server |
|---|---|
| 0 - 1 | 0 đồng (offline, LAN, nhiều cửa sổ trên một máy) |
| 2 | 1 VPS Linux nhỏ, khoảng 5 USD/tháng, đủ cho vài phòng 5 người cùng lúc |
| 4 | Tăng theo số phòng chơi cùng lúc; tính khi có người chơi thật |

GitHub Actions miễn phí cho repo công khai và có hạn mức miễn phí hàng tháng cho repo riêng tư.

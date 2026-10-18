# Game Tiền Tỷ

Game rượt đuổi bất đối xứng **3D cho điện thoại**: 1 Thợ săn vs 4 Người trốn, lấy cảm hứng từ 逃跑吧!少年. Người trốn cạy rương lấy chìa khóa và nhặt tiền, đủ chìa thì 2 cổng thoát mở, ai chạy qua cổng thì người đó thắng. Thợ săn đánh gục, kéo vào tù. Kết quả tính riêng từng người.

Làm bằng Godot 4.6 (GDScript), đội 4 người.

![Trong trận](docs/screenshot.png)

## Dự án đang ở đâu

- **Mục tiêu 4 tuần đầu đã xong**: một trận 1v4 offline trọn vẹn với bot, chọn được vai (đánh gục, kéo vào tù, cứu đồng đội, bộ bài, bot cả hai phe). Mới thử trên máy tính.
- **Code đã là client-server từ đầu.** Bản offline chạy đúng đường code của bản online, nên lên online không phải viết lại. Tạo phòng / vào phòng qua mạng LAN đã chạy. Lý do và cách làm: [docs/KIEN_TRUC.md](docs/KIEN_TRUC.md).
- **Việc tiếp theo**: 4 tuần hoàn thiện bản offline (có thử trên điện thoại thật), 5 nhóm làm song song theo thư mục. Online để sang giai đoạn 2. Chi tiết: mục [Kế hoạch](#kế-hoạch).

Việc đã làm: mục [Tiến độ](#tiến-độ) bên dưới.

## Chơi thử

Mở thư mục này bằng Godot 4.6 rồi bấm Play.

- **Offline**: bấm "Offline: làm Thợ săn" hoặc "Offline: làm Người trốn".
- **Nhiều cửa sổ / LAN**: Debug > Customize Run Instances, bật nhiều instance. Một cửa sổ "Tạo phòng", các cửa sổ khác "Vào phòng" (IP `127.0.0.1` hoặc IP LAN của chủ phòng). Chủ phòng bấm "Bắt đầu trận".

Điều khiển: WASD / mũi tên hoặc cần trái trên màn hình, E / Space hoặc nút tròn bên phải để tương tác, chạm thẻ ở thanh dưới (hoặc phím 1-5) để dùng thẻ; thẻ ném được (túi máu, lựu đạn, đệm lò xo, bẫy, hộp gỗ) thì giữ thẻ kéo để chọn chỗ như kỹ năng Liên Quân, thả tay là ném, kéo tới nút Hủy thì thôi, chạm nhanh thì dùng ngay dưới chân. Người trốn đứng yên sát rương nâu để cạy (nhân vật ngồi xuống mò ổ khóa, mở xong một rương mất 14 giây), vòng căn bung ra quanh chân thì chạm bất kỳ đâu trên màn hình (hoặc E) khi kim vào vùng sáng (vùng đậm: mở nhanh hơn + tiền, vùng mờ: ít tiền, trượt: không được tiền, rương nổ và phải mở lại từ đầu). Đủ 3 chìa thì 2 cổng rung 3 giây rồi mở, chạy vào là thoát; giữ E gần đồng đội gục để đỡ dậy, phím 1-5 dùng thẻ trong bộ bài, trả bằng tiền (túi máu bay chậm theo đường vòng, rơi xuống cứu mọi người trốn trong vùng tròn 1,2 m, kể cả người đang bị kéo và người trong tù; không ai cần cứu thì túi nằm chờ 8 giây để chạy tới đón; súng lục bắn thợ săn, hết máu thì thợ săn buông người và chạy chậm; người trốn không làm choáng được thợ săn). Thợ săn kéo cần BẮN bên phải (hoặc giữ chuột phải) để ngắm: luồng xanh chỉ hướng và tầm bắn, thả tay là bắn, kéo về giữa hoặc thả tay trên nút Hủy thì thôi; chạm nhanh nút BẮN hoặc bấm E thì tự nhắm chỗ người gần nhất đang đứng trong 12 m (tên lửa bay thẳng, đủ chậm để người trốn né, tường chặn, trúng 2 lần là gục), rồi túm người gục kéo vào nhà tù; phím 1 bật radar dấu chân, chạm minimap rồi phím 2 để dịch chuyển. Trong tù mất máu dần, 45 giây không ai ném túi máu qua tường là bị đốt chết; được cứu thì bước lên đệm lò xo xanh trong tù để bật ra. Mỗi người trốn thoát được là thắng riêng; thợ săn bắt 0-1 người là thua, 2-3 thắng một phần, 4 thắng tuyệt đối. Đứng trong bụi cây xanh thì phe kia không thấy mình, trừ khi họ cũng bước vào cùng bụi.

## Cho người code

1. Đọc [CLAUDE.md](CLAUDE.md): ranh giới module, quy ước code, cách chạy test. Claude Code cũng tự đọc file này.
2. Đọc [docs/KIEN_TRUC.md](docs/KIEN_TRUC.md): năm luật vàng để code offline lên online không phải sửa. Luật trận: [docs/CHU_TRINH_BAT.md](docs/CHU_TRINH_BAT.md), [docs/LUAT_TRAN.md](docs/LUAT_TRAN.md).
3. Đọc README trong thư mục module của mình.
4. Trước khi mở PR: `GODOT=/duong/dan/godot tools/smoke_test.sh` (CI cũng tự chạy).

| Thư mục | Nhóm (xem [Kế hoạch](#kế-hoạch)) | Nội dung |
|---|---|---|
| `Core/` | 1 (Lead) | Kiểu dữ liệu, EventBus, trạng thái trận, mạng, interface |
| `Player/` | 2 | Điều khiển, di chuyển, đánh/ngã/cứu, camera, anim |
| `UI/` | 2 | Menu, HUD, nút cảm ứng, minimap, cài đặt |
| `Objects/` | 3 | Rương, cổng, nhà tù, bụi cây, bản đồ |
| `Items/` | 3 | Thẻ kỹ năng, vật đặt xuống đất |
| `AI/` | 4 | Bot, NavMesh |
| `Audio/`, `Fx/` | 5 | Âm thanh, hiệu ứng hạt (chưa có, tạo ở tuần 1) |

## Tiến độ

Cập nhật mỗi khi merge một phần lớn. Người mới vào đọc mục này để biết làm gì tiếp.

### Đã làm

| Phần | Nội dung | Ở đâu |
|---|---|---|
| Kiến trúc | Server có thẩm quyền, offline / host / server riêng chạy cùng code, gửi trạng thái khi đổi, CI chạy test luật + trận offline + trận online 3 máy | `Core/`, `tools/smoke_test.sh` |
| Người trốn | Di chuyển, cạy rương (ngồi mò ổ khóa, 14 giây) có vòng căn bung ra quanh chân, chạm màn hình để căn (trượt thì mở lại từ đầu), nhặt tiền, đỡ đồng đội gục, 2 cổng mở trễ 3 giây, thoát là thắng riêng | `Player/`, `Objects/`, `UI/qte_ring.gd` |
| Thợ săn | Súng bắn tên lửa bay thẳng (tường chặn), chạm thì nổ lửa + khói, ngắm tay có luồng xanh + nút Hủy, tự nhắm khi chạm nhanh (không đón đầu), tên lửa bay thật nên né được, bắn xong khựng nhẹ, có máu (bị bắn hết máu thì buông người + chạy chậm), túm người gục kéo vào tù | `Player/player_character.gd`, `Core/match/match_rules.gd` |
| Nhà tù | Tường cao, bị đốt sau 45 giây, cứu bằng túi máu ném qua tường, đệm lò xo bật ra | `Objects/prison.gd` |
| Bộ bài | Người trốn chọn 5 thẻ ở menu, trả bằng tiền: túi máu (bay chậm, vùng tròn xanh 1,2 m, không ai cần cứu thì nằm chờ 8 giây để chạy tới đón), lựu đạn làm chậm, súng lục, ván trượt, đệm lò xo, bẫy, hộp gỗ. Thợ săn: radar dấu chân, dịch chuyển (chạm minimap chọn chỗ) | `Items/`, `UI/main_menu.gd` |
| Giao diện | Kiểu game chibi dựng bằng code (`UI/ui_theme.gd`): menu nền trời có nút vai to và ô chọn thẻ; HUD có thanh trên (đồng hồ, chìa, cổng), hàng đầu người trốn theo màu, tim máu + tiền, thông báo nổi; nút cảm ứng viền đậm, thẻ hồi chiêu quét hình quạt; minimap khung bo tròn; bảng kết quả thắng/thua. Giao diện co theo màn hình (stretch `canvas_items`). Nhân vật và camera vẽ nội suy giữa hai lần tính vật lý nên chạy mượt cả trên màn 90/120 Hz | `UI/`, `Player/` |
| Nhân vật | Nhân vật gốc của bộ KayKit Adventurers (CC0): thợ săn là Barbarian cầm rìu (ma khí tím đỏ dưới chân), người trốn là Mage. Dùng nguyên mô hình (~6k tam giác), khung xương và động tác có sẵn: đứng, đi, chạy, chém, ném, trúng đòn, gục nằm, ngồi tù, bay, cúi cạy rương | `Player/models/kaykit/` |
| Bản đồ | Phong cách chibi dựng bằng code: sân cỏ, tường thấp mái ngói, hàng rào cây ở viền, nhà tù ở chính giữa, rương có nắp và đai vàng | `Objects/maps/test_map.gd`, `Objects/safe.gd` |
| Bụi cây | Đứng trong bụi thì phe kia không thấy, trừ khi đứng cùng bụi; đồng đội vẫn thấy nhau. Server không gửi vị trí người nấp xuống máy phe kia; bot và súng tự nhắm cũng không thấy | `Objects/bush.gd`, `GameState.can_see()` |
| Bot | Bot người trốn cạy rương, chạy trốn, cứu nhau, ném túi máu / lựu đạn đúng chỗ, dùng thẻ; bot thợ săn đuổi, bắn, kéo vào tù, dùng radar / dịch chuyển | `AI/bot_input_source.gd` |
| Thẻ kéo-thả | Túi máu, lựu đạn, đệm lò xo, bẫy, hộp gỗ: giữ thẻ kéo để chọn chỗ như kỹ năng Liên Quân (vòng tầm + vòng chỗ rơi, nút Hủy, chạm nhanh thì dưới chân). Không thêm dữ liệu mạng | `UI/touch_controls.gd`, `Items/effects/aim_point.gd` |
| Xem người khác | Đã thoát hoặc bị loại thì camera xem đồng đội còn chơi; Tab hoặc nút xanh để đổi người (cả thợ săn) | `Player/follow_camera.gd` |
| Hiệu năng | Đạn, tên lửa, vụ nổ, túi máu, lựu đạn, vùng xanh, cột sáng dùng pool; vật giống nhau dùng chung mesh/material; server riêng không tạo hình; texture nén ETC2/ASTC cho điện thoại | `Player/shot_fx.gd`, `Items/item_visuals.gd`, `project.godot` |

### Việc nhỏ đang treo

- Đệm lò xo trong nhà tù (`Objects/prison.gd`) và thẻ đệm lò xo (`Items/placed/jump_pad_node.gd`) đang lặp code hất tung.
- Server tính lại dữ liệu rương gửi xuống mỗi frame khi có người đang cạy (`Core/game_state.gd`), nên gộp 10 lần/giây. Cần Lead duyệt.
- Cân bằng: 10 trận bot ngày 15/10 cho thợ săn thắng tuyệt đối 3/10, thắng một phần 4/10, thua 3/10, bắt trung bình 2,6/4 người: thợ săn hơi mạnh. Bot chưa giống người nên chờ trận người thật rồi mới chỉnh (`Core/types/match_config.gd`, `Items/item_catalog.gd`).

### Asset bên ngoài

| Asset | Tác giả | Giấy phép | Ở đâu |
|---|---|---|---|
| Nhân vật Barbarian, Mage kèm khung xương và động tác (`Player/models/kaykit/`), KayKit Character Pack: Adventurers 1.0 | Kay Lousberg (kaylousberg.com) | CC0 | `Player/models/kaykit/` |
| Mô hình ma tu và đệ tử cũ (`ma_tu_*.glb`, `de_tu_*.glb`, hiện không dùng): quan gửi | Dự án (quan) | Của dự án | `Player/models/` |

Chỉ thêm asset CC0 hoặc giấy phép cho dùng thương mại, và ghi vào bảng này.

## Kế hoạch

**Giai đoạn 1 (4 tuần): hoàn thiện bản offline.** Xong khi: 60 FPS và dưới 400 MB trên máy tầm thấp (RAM 3 GB, Mali-G52 / Adreno 610), 2 bản đồ, đủ âm thanh, người thật chơi 10 trận thấy vui và thợ săn thắng (một phần hoặc tuyệt đối) khoảng một nửa số trận.

**Giai đoạn 2: online.** Chưa làm gì; chỉ giữ khung đã có trong Core (server có thẩm quyền, offline / host / server riêng cùng đường code, `Net` với ENet, CI chạy trận online 3 máy). Mọi PR giai đoạn 1 vẫn phải qua CI đó.

**Đổi bối cảnh tiên hiệp** (ma tu, phi kiếm, huyết trận, trận linh, lối ra phải phá giải): thuật ngữ và 6 ticket luật TH-01..06 ở [docs/TIEN_HIEP.md](docs/TIEN_HIEP.md). Phần giao diện tiên hiệp Lead làm riêng.

### Nhóm việc (tránh conflict)

Mỗi nhóm chỉ commit trong thư mục mình sở hữu. Có 3 người thêm thì gộp nhóm 5 vào nhóm 2.

| Nhóm | Sở hữu | Việc chính |
|---|---|---|
| 1. Lõi và build (Lead) | `Core/`, `main.tscn`, `project.godot`, `tools/`, `.github/`, `export_presets.cfg`, `README.md` | Build APK, đo hiệu năng, số cân bằng, duyệt PR, thêm tín hiệu / hàm cho nhóm khác |
| 2. Điều khiển và giao diện | `Player/`, `UI/` | Nút cảm ứng, icon thẻ, cài đặt, chọn bản đồ, hướng dẫn |
| 3. Bản đồ và đạo cụ | `Objects/`, `Items/` | Bản đồ trong editor, model cổng / tiền, bản đồ 2, số của thẻ |
| 4. Bot | `AI/` | NavMesh, hành vi, độ khó |
| 5. Âm thanh và hiệu ứng | `Audio/`, `Fx/` (mới) | Âm thanh, nhạc nền, hiệu ứng hạt dùng pool |

1. Cần sửa file nhóm khác (kể cả thêm tín hiệu `EventBus`, số trong `match_config.gd`, dòng trong `project.godot`): mở issue cho nhóm đó, không tự sửa.
2. Nói chuyện giữa các nhóm chỉ qua `EventBus`, group và `Core/interfaces/`. Chốt ngày đầu tuần 1: bản đồ có sẵn `NavigationRegion3D` đã bake (nhóm 3 → 4); danh sách tín hiệu cho âm thanh (nhóm 5 → 1).
3. Mỗi việc một nhánh `<module>/<việc>`, PR nhỏ, kéo `main` mỗi sáng, `tools/smoke_test.sh` qua trước khi mở PR.
4. Asset mới ghi trong README của module; nhóm 1 gộp vào bảng asset bên trên.
5. PR nặng (bản đồ, âm thanh, hiệu ứng) ghi số FPS đo bằng `--perf` trước và sau.

### Tuần 1: đo trên điện thoại, dựng khung

| Nhóm | Việc | File |
|---|---|---|
| 1 | Export preset Android + CI build APK thử (khóa debug) | `export_presets.cfg`, `.github/` |
| 1 | Lớp đo hiệu năng `--perf`: FPS, thời gian vẽ, RAM, draw call, ghi file sau trận | `Core/debug/`, `Core/main.gd` |
| 1 | Đăng ký autoload `Audio` rỗng, thêm tín hiệu nhóm 5 cần | `project.godot`, `Core/event_bus.gd` |
| 1 | Gộp dữ liệu rương gửi xuống còn 10 lần/giây | `Core/game_state.gd` |
| 1 | Lead cài APK lên máy tầm thấp, chơi 3 trận mỗi vai, gửi số đo | |
| 2 | Cỡ / khoảng cách nút thành hằng chỉnh được | `UI/touch_controls.gd` |
| 2 | Màn Cài đặt: âm lượng Nhạc / Hiệu ứng, lưu `user://` | `UI/settings_menu.gd` (mới) |
| 3 | Bản đồ thử từ code sang `.tscn` (giữ bố cục) + `NavigationRegion3D` đã bake | `Objects/maps/` |
| 3 | Gộp code hất tung của đệm lò xo trong tù và thẻ đệm lò xo | `Objects/prison.gd`, `Items/placed/` |
| 4 | Bot đi theo `NavigationAgent3D` (tạm bake lúc vào trận), vẽ đường đi khi `--bot-debug` | `AI/` |
| 5 | Bộ âm thanh CC0 (Kenney) sang `.ogg`; `audio_director.gd` dùng pool, phát 6 âm cơ bản theo `EventBus` | `Audio/` |

### Tuần 2: sửa theo số đo, nội dung chính

| Nhóm | Việc | File |
|---|---|---|
| 1 | Sửa điểm nặng trong Core, chuyển điểm nặng của nhóm khác thành issue | `Core/` |
| 1 | `tools/balance.sh`: chạy 20 trận bot, in tỉ lệ thắng, số người bị bắt | `tools/` |
| 2 | Chỉnh nút theo tay thật; icon 9 thẻ; mức đồ họa Thấp / Cao | `UI/` |
| 3 | Model cổng thoát và cọc tiền chibi (KayKit CC0); phác bố cục bản đồ 2 cho Lead duyệt | `Objects/` |
| 4 | Bỏ hẳn đi thẳng / rẽ ngẫu nhiên; thợ săn tuần tra rương; người trốn chạy xa thợ săn | `AI/` |
| 5 | Đủ âm còn lại (thẻ, tiền, đếm ngược, radar, dịch chuyển), nhạc nền, bus Nhạc / Hiệu ứng | `Audio/` |

### Tuần 3: bản đồ 2, bot khôn hơn, hiệu ứng, buổi chơi thật

| Nhóm | Việc | File |
|---|---|---|
| 1 | Chọn bản đồ trong luật (`MatchConfig.map_id`), CI chạy cả 2 bản đồ; tổ chức buổi chơi 4-5 người thật | `Core/`, `tools/` |
| 2 | Menu chọn bản đồ, hướng dẫn 3 trang lần đầu chơi, rung khi trúng đạn / căn trượt | `UI/`, `Player/` |
| 3 | Bản đồ 2 có nhà cửa, đồ vật, bụi cây, NavMesh; trang trí bản đồ 1 | `Objects/maps/` |
| 4 | Bot né tên lửa, nấp bụi khi bị đuổi, chọn rương xa thợ săn; độ khó Dễ / Thường | `AI/` |
| 5 | Hiệu ứng hạt dùng pool: bụi khi cạy, tia sáng khi căn trúng, pháo khi thoát, lửa nhà tù | `Fx/` |

### Tuần 4: cân bằng, đóng gói bản thử

| Nhóm | Việc | File |
|---|---|---|
| 1 | Chỉnh số trận theo buổi chơi; đo lại cả trận trên máy thật; build APK bản thử; Lead chơi 10 trận chốt | `Core/types/match_config.gd`, `.github/` |
| 2 | Sửa lỗi giao diện từ buổi chơi; bảng kết quả thêm số liệu | `UI/` |
| 3 | Chỉnh giá / hồi chiêu thẻ; sửa chỗ kẹt tường trên 2 bản đồ | `Items/item_catalog.gd`, `Objects/maps/` |
| 4 | Chỉnh độ khó bot cho trận 1 người + 4 bot cân | `AI/` |
| 5 | Cân âm lượng, nén lại (tổng âm thanh dưới 10 MB) | `Audio/` |

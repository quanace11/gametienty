# Game Tiền Tỷ

Game rượt đuổi bất đối xứng **3D cho điện thoại**: 1 Thợ săn vs 4 Người trốn, lấy cảm hứng từ 逃跑吧!少年. Người trốn cạy rương lấy chìa khóa và nhặt tiền, đủ chìa thì 2 cổng thoát mở, ai chạy qua cổng thì người đó thắng. Thợ săn đánh gục, kéo vào tù. Kết quả tính riêng từng người.

Làm bằng Godot 4.6 (GDScript), đội 4 người.

![Trong trận](docs/screenshot.png)

## Dự án đang ở đâu

- **Mục tiêu 4 tuần đầu đã xong**: một trận 1v4 offline trọn vẹn với bot, chọn được vai (đánh gục, kéo vào tù, cứu đồng đội, bộ bài, bot cả hai phe). Mới thử trên máy tính.
- **Code đã là client-server từ đầu.** Bản offline chạy đúng đường code của bản online, nên lên online không phải viết lại. Tạo phòng / vào phòng qua mạng LAN đã chạy. Lý do và cách làm: [docs/KIEN_TRUC.md](docs/KIEN_TRUC.md).
- **Việc tiếp theo**: chạy trên điện thoại thật, rồi hoàn thiện trận offline, rồi lên online. Chi tiết: mục [Kế hoạch](#kế-hoạch).

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

| Thư mục | Người phụ trách | Nội dung |
|---|---|---|
| `Core/` | A (Lead) | Kiểu dữ liệu, EventBus, trạng thái trận, mạng, interface |
| `Player/` | B | Điều khiển, di chuyển, đánh/ngã/cứu, camera, anim |
| `Objects/` | C | Két, cổng, nhà tù, cửa, bẫy, bản đồ |
| `Items/` | C | Thẻ kỹ năng, vật phẩm |
| `AI/` | D | Bot, giác quan, NavMesh |
| `UI/` | | Menu, HUD, theo dõi, minimap |

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
| Nhân vật | 2 nhân vật chibi KayKit (CC0) kiểu tiên hiệp: ma tu (thợ săn) là Rogue trùm đầu áo tím đen, ma khí tím đỏ dưới chân; đệ tử (người trốn) là Mage áo trắng ngọc, búi tóc, mượn khung xương + animation của Knight. Có animation chạy, đứng, gục, ngồi tù, bay, phóng kiếm, bị trúng, ném | `Player/models/` |
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
| KayKit Character Pack: Adventurers 1.0 (Knight, Rogue_Hooded), đã cắt bớt animation | Kay Lousberg | CC0 1.0 (dùng thương mại, không cần ghi công) | `Player/models/`, `Player/models/LICENSE_KayKit.txt` |
| KayKit Character Pack: Adventurers 2.0 (Mage, chỉ lưới, không animation); `ma_tu_texture.png`, `de_tu_texture.png` là bảng màu Rogue / Mage tô lại | Kay Lousberg | CC0 1.0 | `Player/models/mage.glb` |

Chỉ thêm asset CC0 hoặc giấy phép cho dùng thương mại, và ghi vào bảng này.

## Kế hoạch

Ba giai đoạn, làm theo thứ tự; giai đoạn sau chỉ bắt đầu khi giai đoạn trước đạt tiêu chí xong. Cột "Ai" ghi việc cần chủ dự án (máy thật, tài khoản, tiền, người chơi thật); còn lại là code.

### Giai đoạn 1: chạy trên điện thoại thật (đang làm)

Xong khi: APK chạy 60 FPS trên máy tầm thấp (RAM 3 GB, Mali-G52 / Adreno 610), dưới 400 MB RAM, không nóng máy sau 3 trận, nút cảm ứng bấm thoải mái.

| # | Việc | Ai |
|---|---|---|
| 1.1 | Export preset Android + CI tự build APK thử (khóa debug), tải về từ GitHub Actions | Code |
| 1.2 | Lớp đo hiệu năng bật bằng tham số: FPS, thời gian vẽ, RAM, draw call, ghi ra file sau mỗi trận | Code |
| 1.3 | Cài APK lên một điện thoại tầm thấp, chơi 3 trận mỗi vai, gửi số đo + ảnh + cảm nhận nút | Chủ dự án |
| 1.4 | Chỉnh theo kết quả: cỡ và chỗ nút, giảm bóng / tam giác / draw call, mức đồ họa thấp | Code |

### Giai đoạn 2: hoàn thiện trận offline

Xong khi: người thật chơi 10 trận trên điện thoại thấy vui, thợ săn thắng (một phần hoặc tuyệt đối) khoảng một nửa số trận, vẫn 60 FPS.

| # | Việc | Ai |
|---|---|---|
| 2.1 | Dọn hai việc nhỏ đang treo ở trên | Code, Lead duyệt Core |
| 2.2 | Âm thanh `.ogg` CC0 (Kenney): bắn, nổ, cạy rương, căn trúng / trượt, cổng mở, bị gục, nhạc nền; chạy theo `EventBus`, có nút tắt tiếng | Code |
| 2.3 | NavMesh cho bot, tính đường thưa để server nhẹ | Code |
| 2.4 | Model cổng và tiền chibi (KayKit CC0) | Code |
| 2.5 | Bản đồ dựng trong editor có nhà cửa / đồ vật, thêm bản đồ thứ hai | Code, chủ dự án góp ý bố cục |
| 2.6 | Chơi thật với bạn bè, ghi kết quả và chỗ khó chịu | Chủ dự án |
| 2.7 | Chỉnh số cân bằng theo 2.6 | Code |

### Giai đoạn 3: chơi online qua Internet

Xong khi: 5 người ở 5 mạng khác nhau chơi trọn trận qua VPS, ping 150 ms vẫn chơi được, dưới 8 KB/s mỗi người mỗi chiều, một trận dưới 2% một nhân CPU.

| # | Việc | Ai |
|---|---|---|
| 3.1 | Đo băng thông và CPU trận online trong CI | Code |
| 3.2 | Giả lập ping 150 ms + mất gói, đoán trước di chuyển trên máy người chơi | Code |
| 3.3 | Phòng có mã, bot lấp chỗ, vào lại khi rớt mạng | Code |
| 3.4 | Server nhiều phòng một lúc, script cài đặt + tự khởi động lại trên Linux | Code |
| 3.5 | Thuê VPS (khoảng 5 USD/tháng, gần Việt Nam), mở cổng UDP | Chủ dự án |
| 3.6 | Chơi thử online với 4 người khác | Chủ dự án |

Sau đó: chế độ 8v2 (kiến trúc đã sẵn), quyết định phát hành (Google Play cần tài khoản nhà phát triển và khóa ký riêng; iOS cần máy Mac và tài khoản Apple Developer).

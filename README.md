# Game Tiền Tỷ

Game rượt đuổi bất đối xứng **3D cho điện thoại**: 1 Thợ săn vs 4 Người trốn, lấy cảm hứng từ 逃跑吧!少年. Người trốn cạy rương lấy chìa khóa và nhặt tiền, đủ chìa thì 2 cổng thoát mở, ai chạy qua cổng thì người đó thắng. Thợ săn đánh gục, kéo vào tù. Kết quả tính riêng từng người.

Làm bằng Godot 4.6 (GDScript), đội 4 người.

![Trong trận](docs/screenshot.png)

## Dự án đang ở đâu

- **Giai đoạn hiện tại: offline.** Một người chơi với 4 bot, chọn làm Thợ săn hoặc Người trốn. Không tốn tiền server.
- **Nhưng code đã là client-server từ đầu.** Bản offline chạy đúng đường code của bản online, nên sau này lên online không phải viết lại. Chế độ tạo phòng/vào phòng qua mạng LAN đã chạy được. Lý do và cách làm: [docs/KIEN_TRUC.md](docs/KIEN_TRUC.md).
- Mục tiêu 4 tuần: một trận 1v4 offline trọn vẹn (đánh gục, kéo vào tù, cứu đồng đội, kỹ năng, bot thông minh).

Chi tiết việc đã làm và việc còn lại: mục [Tiến độ](#tiến-độ) bên dưới.

## Chơi thử

Mở thư mục này bằng Godot 4.6 rồi bấm Play.

- **Offline**: bấm "Offline: làm Thợ săn" hoặc "Offline: làm Người trốn".
- **Nhiều cửa sổ / LAN**: Debug > Customize Run Instances, bật nhiều instance. Một cửa sổ "Tạo phòng", các cửa sổ khác "Vào phòng" (IP `127.0.0.1` hoặc IP LAN của chủ phòng). Chủ phòng bấm "Bắt đầu trận".

Điều khiển: WASD / mũi tên hoặc cần trái trên màn hình, E / Space hoặc nút tròn bên phải để tương tác, chạm thẻ ở thanh dưới (hoặc phím 1-5) để dùng thẻ. Người trốn đứng sát rương nâu để cạy, vòng căn hiện ra thì bấm E khi kim vào vùng sáng (vùng đậm: mở nhanh hơn + tiền, vùng mờ: ít tiền, trượt: rương nổ và về 0). Đủ 3 chìa thì 2 cổng rung 3 giây rồi mở, chạy vào là thoát; giữ E gần đồng đội gục để đỡ dậy, phím 1-5 dùng thẻ trong bộ bài, trả bằng tiền (túi máu rơi thành vùng tròn xanh, cứu mọi người trốn trong vùng, kể cả người đang bị kéo và người trong tù; súng lục bắn thợ săn, hết máu thì thợ săn buông người và chạy chậm; người trốn không làm choáng được thợ săn). Thợ săn kéo cần BẮN bên phải (hoặc giữ chuột phải) để ngắm: luồng xanh chỉ hướng và tầm bắn, thả tay là bắn, kéo về giữa hoặc vào nút Hủy thì thôi; chạm nhanh nút BẮN hoặc bấm E thì tự ngắm đón đầu trong 12 m (đạn bay thẳng, tường chặn, trúng 2 lần là gục), rồi túm người gục kéo vào nhà tù; phím 1 bật radar dấu chân, chạm minimap rồi phím 2 để dịch chuyển. Trong tù mất máu dần, 45 giây không ai ném túi máu qua tường là bị đốt chết; được cứu thì bước lên đệm lò xo xanh trong tù để bật ra. Mỗi người trốn thoát được là thắng riêng; thợ săn bắt 0-1 người là thua, 2-3 thắng một phần, 4 thắng tuyệt đối. Đứng trong bụi cây xanh thì phe kia không thấy mình, trừ khi họ cũng bước vào cùng bụi.

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
| Người trốn | Di chuyển, cạy rương có vòng căn (vẽ trên sàn), nhặt tiền, đỡ đồng đội gục, 2 cổng mở trễ 3 giây, thoát là thắng riêng | `Player/`, `Objects/`, `UI/qte_ring.gd` |
| Thợ săn | Súng bắn thẳng (tường chặn), ngắm tay có luồng xanh + nút Hủy, tự ngắm khi chạm nhanh, bắn xong khựng nhẹ, có máu (bị bắn hết máu thì buông người + chạy chậm), túm người gục kéo vào tù | `Player/player_character.gd`, `Core/match/match_rules.gd` |
| Nhà tù | Tường cao, bị đốt sau 45 giây, cứu bằng túi máu ném qua tường, đệm lò xo bật ra | `Objects/prison.gd` |
| Bộ bài | Người trốn chọn 5 thẻ ở menu, trả bằng tiền: túi máu (vùng tròn xanh), lựu đạn làm chậm, súng lục, ván trượt, đệm lò xo, bẫy, hộp gỗ. Thợ săn: radar dấu chân, dịch chuyển (chạm minimap chọn chỗ) | `Items/`, `UI/main_menu.gd` |
| Giao diện | Cần di chuyển, nút BẮN / Cạy, thanh thẻ có giá và hồi chiêu, minimap, bảng kết quả từng người | `UI/` |
| Nhân vật | 2 nhân vật chibi KayKit (CC0): thợ săn là Rogue trùm đầu cầm nỏ (vòng đỏ dưới chân), người trốn là hiệp sĩ. Có animation chạy, đứng, gục, ngồi tù, bay, bắn, bị trúng, ném | `Player/models/` |
| Bản đồ | Phong cách chibi dựng bằng code: sân cỏ, tường thấp mái ngói, hàng rào cây ở viền, nhà tù ở chính giữa, rương có nắp và đai vàng | `Objects/maps/test_map.gd`, `Objects/safe.gd` |
| Bụi cây | Đứng trong bụi thì phe kia không thấy, trừ khi đứng cùng bụi; đồng đội vẫn thấy nhau. Server không gửi vị trí người nấp xuống máy phe kia; bot và súng tự nhắm cũng không thấy | `Objects/bush.gd`, `GameState.can_see()` |
| Bot | Bot người trốn cạy rương, chạy trốn, cứu nhau, dùng thẻ; bot thợ săn đuổi, bắn, kéo vào tù, dùng radar / dịch chuyển | `AI/bot_input_source.gd` |

### Còn lại (theo thứ tự nên làm)

1. **Bản đồ dựng trong editor** (thay vì bằng code), thêm nhà cửa / đồ vật chibi (gợi ý: KayKit City Builder Bits / Furniture Bits, CC0), nhiều bản đồ. Phụ trách: `Objects/`.
2. **Cổng, tiền, hiệu ứng** dùng model đẹp hơn; pool cho đạn và hiệu ứng (luật hiệu năng trong CLAUDE.md). Phụ trách: `Objects/`, `Items/`.
3. **Kéo thẻ để chọn chỗ ném** (túi máu, lựu đạn) như game gốc; hiện tự chọn chỗ. Phụ trách: `UI/`, `Items/`.
4. **Xem người khác khi bị nhốt / bị loại**, âm thanh `.ogg`, menu đẹp hơn. Phụ trách: `UI/`.
5. **Cân bằng** sau khi giao diện ổn: hiện bot thợ săn thắng phần lớn trận (tầm súng, hồi chiêu, tốc độ, giá thẻ đều nằm trong `Core/types/match_config.gd` và `Items/item_catalog.gd`).
6. **NavMesh cho bot** (bot đang đi thẳng, hay kẹt tường). Phụ trách: `AI/`.
7. **Xuất bản điện thoại**: export Android, kiểm tra 60 FPS trên máy tầm thấp, nén texture ETC2/ASTC.
8. **Online qua Internet**: server riêng trên VPS, ghép phòng, bù trễ.

### Asset bên ngoài

| Asset | Tác giả | Giấy phép | Ở đâu |
|---|---|---|---|
| KayKit Character Pack: Adventurers 1.0 (Knight, Rogue_Hooded), đã cắt bớt animation | Kay Lousberg | CC0 1.0 (dùng thương mại, không cần ghi công) | `Player/models/`, `Player/models/LICENSE_KayKit.txt` |

Chỉ thêm asset CC0 hoặc giấy phép cho dùng thương mại, và ghi vào bảng này.

## Lộ trình

| Tuần | Mục tiêu |
|---|---|
| 1 | Khung kiến trúc (xong), di chuyển + dash, két tương tác, NavMesh nháp |
| 2 | Thợ săn đánh gục, kéo vào tù, cứu đồng đội bằng tay và túi máu (API Core + bản mẫu xong), bot tự mở két |
| 3 | 3 thẻ kỹ năng, QTE ở két, bot thợ săn tuần tra và đuổi |
| 4 | Ghép trận 1v4 offline hoàn chỉnh, màn hình kết thúc |
| Sau đó | Server riêng trên VPS, chơi qua Internet mượt, ghép trận nhiều phòng |

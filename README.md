# Game Tiền Tỷ

Game rượt đuổi bất đối xứng **3D cho điện thoại**: 1 Thợ săn vs 4 Người trốn, lấy cảm hứng từ 逃跑吧!少年. Người trốn cạy rương lấy chìa khóa và nhặt tiền, đủ chìa thì 2 cổng thoát mở, ai chạy qua cổng thì người đó thắng. Thợ săn đánh gục, kéo vào tù. Kết quả tính riêng từng người.

Làm bằng Godot 4.6 (GDScript), đội 4 người.

![Trong trận](docs/screenshot.png)

## Dự án đang ở đâu

- **Giai đoạn hiện tại: offline.** Một người chơi với 4 bot, chọn làm Thợ săn hoặc Người trốn. Không tốn tiền server.
- **Nhưng code đã là client-server từ đầu.** Bản offline chạy đúng đường code của bản online, nên sau này lên online không phải viết lại. Chế độ tạo phòng/vào phòng qua mạng LAN đã chạy được. Lý do và cách làm: [docs/KIEN_TRUC.md](docs/KIEN_TRUC.md).
- Mục tiêu 4 tuần: một trận 1v4 offline trọn vẹn (đánh gục, kéo vào tù, cứu đồng đội, kỹ năng, bot thông minh).

Đã có: di chuyển 3D, rương có vòng căn, tiền, bộ bài 5 thẻ mua bằng tiền (túi máu, lựu đạn choáng, súng lục, ván trượt, đệm lò xo, bẫy, hộp gỗ), thợ săn bắn cối và có máu, 2 cổng mở trễ 3 giây, kết quả từng người, chu trình bắt người (bắn gục, kéo lê, nhà tù tường cao bị đốt, cứu bằng tay hoặc túi máu, đệm lò xo bật ra khỏi tù), thắng/thua, bot đơn giản, offline + host + server riêng, CI tự kiểm tra.
Hình dạng nhân vật và bản đồ đang là khối tạm, sẽ thay bằng model.

## Chơi thử

Mở thư mục này bằng Godot 4.6 rồi bấm Play.

- **Offline**: bấm "Offline: làm Thợ săn" hoặc "Offline: làm Người trốn".
- **Nhiều cửa sổ / LAN**: Debug > Customize Run Instances, bật nhiều instance. Một cửa sổ "Tạo phòng", các cửa sổ khác "Vào phòng" (IP `127.0.0.1` hoặc IP LAN của chủ phòng). Chủ phòng bấm "Bắt đầu trận".

Điều khiển: WASD / mũi tên, E hoặc Space để tương tác. Người trốn đứng sát rương nâu để cạy, vòng căn hiện ra thì bấm E khi kim vào vùng sáng (vùng đậm: mở nhanh hơn + tiền, vùng mờ: ít tiền, trượt: rương nổ và về 0). Đủ 3 chìa thì 2 cổng rung 3 giây rồi mở, chạy vào là thoát; giữ E gần đồng đội gục để đỡ dậy, phím 1-5 dùng thẻ trong bộ bài, trả bằng tiền (túi máu cứu được cả người đang bị kéo và người trong tù; súng lục bắn thợ săn, hết máu thì thợ săn bị choáng và buông người). Thợ săn bấm E để bắn cối (vòng đỏ báo chỗ rơi, trúng 2 lần là gục), rồi túm người gục kéo vào nhà tù. Trong tù mất máu dần, 45 giây không ai ném túi máu qua tường là bị đốt chết; được cứu thì bước lên đệm lò xo xanh trong tù để bật ra. Mỗi người trốn thoát được là thắng riêng; thợ săn bắt 0-1 người là thua, 2-3 thắng một phần, 4 thắng tuyệt đối.

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

## Lộ trình

| Tuần | Mục tiêu |
|---|---|
| 1 | Khung kiến trúc (xong), di chuyển + dash, két tương tác, NavMesh nháp |
| 2 | Thợ săn đánh gục, kéo vào tù, cứu đồng đội bằng tay và túi máu (API Core + bản mẫu xong), bot tự mở két |
| 3 | 3 thẻ kỹ năng, QTE ở két, bot thợ săn tuần tra và đuổi |
| 4 | Ghép trận 1v4 offline hoàn chỉnh, màn hình kết thúc |
| Sau đó | Server riêng trên VPS, chơi qua Internet mượt, ghép trận nhiều phòng |

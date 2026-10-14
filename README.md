# Game Tiền Tỷ

Game rượt đuổi bất đối xứng **3D**: 1 Thợ săn vs 4 Người trốn, lấy cảm hứng từ 逃跑吧!少年. Người trốn mở két sắt, đủ két thì cổng thoát mở và chạy ra ngoài. Thợ săn đuổi bắt và nhốt người trốn vào tù.

Làm bằng Godot 4.6 (GDScript), đội 4 người.

![Trong trận](docs/screenshot.png)

## Dự án đang ở đâu

- **Giai đoạn hiện tại: offline.** Một người chơi với 4 bot, chọn làm Thợ săn hoặc Người trốn. Không tốn tiền server.
- **Nhưng code đã là client-server từ đầu.** Bản offline chạy đúng đường code của bản online, nên sau này lên online không phải viết lại. Chế độ tạo phòng/vào phòng qua mạng LAN đã chạy được. Lý do và cách làm: [docs/KIEN_TRUC.md](docs/KIEN_TRUC.md).
- Mục tiêu 4 tuần: một trận 1v4 offline trọn vẹn (đánh ngã, vác vào tù, cứu đồng đội, kỹ năng, bot thông minh).

Đã có: di chuyển 3D, két (đông người mở nhanh hơn), cổng thoát, chu trình bắt người (đánh, ngã, vác, nhà tù, cứu, bị loại), thắng/thua, bot đơn giản, offline + host + server riêng, CI tự kiểm tra.
Hình dạng nhân vật và bản đồ đang là khối tạm, sẽ thay bằng model.

## Chơi thử

Mở thư mục này bằng Godot 4.6 rồi bấm Play.

- **Offline**: bấm "Offline: làm Thợ săn" hoặc "Offline: làm Người trốn".
- **Nhiều cửa sổ / LAN**: Debug > Customize Run Instances, bật nhiều instance. Một cửa sổ "Tạo phòng", các cửa sổ khác "Vào phòng" (IP `127.0.0.1` hoặc IP LAN của chủ phòng). Chủ phòng bấm "Bắt đầu trận".

Điều khiển: WASD / mũi tên, E hoặc Space để tương tác. Người trốn đứng sát két vàng để mở, mở đủ 3 két thì cổng đỏ chuyển xanh, chạy vào là thoát; giữ E gần đồng đội ngã để đỡ dậy, đứng trong nhà tù để phá khóa. Thợ săn đánh 2 đòn là ngã, bấm E để nhấc lên rồi mang vào nhà tù. Bị nhốt lần 2 hoặc ở tù quá 60 giây là bị loại. Người trốn thắng nếu ít nhất một nửa thoát được.

## Cho người code

1. Đọc [CLAUDE.md](CLAUDE.md): ranh giới module, quy ước code, cách chạy test. Claude Code cũng tự đọc file này.
2. Đọc [docs/KIEN_TRUC.md](docs/KIEN_TRUC.md): năm luật vàng để code offline lên online không phải sửa.
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
| 2 | Thợ săn đánh ngã, vác vào tù, cứu đồng đội (API Core + bản mẫu xong), bot tự mở két |
| 3 | 3 thẻ kỹ năng, QTE ở két, bot thợ săn tuần tra và đuổi |
| 4 | Ghép trận 1v4 offline hoàn chỉnh, màn hình kết thúc |
| Sau đó | Server riêng trên VPS, chơi qua Internet mượt, ghép trận nhiều phòng |

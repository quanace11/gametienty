# Game Tiền Tỷ

Game rượt đuổi bất đối xứng 1 Thợ săn vs 4 Người trốn, kiểu 逃跑吧!少年. Godot 4.6, GDScript, 2D top-down.

![Trong trận](docs/screenshot.png)

## Chơi thử

Mở project bằng Godot 4.6 rồi bấm Play.

- **Offline**: bấm "Offline: làm Thợ săn" hoặc "Offline: làm Người trốn", 4 chỗ còn lại là bot.
- **Nhiều máy / nhiều cửa sổ**: Debug > Customize Run Instances, bật nhiều instance. Một cửa sổ "Tạo phòng", các cửa sổ khác "Vào phòng" (IP `127.0.0.1`, hoặc IP LAN của chủ phòng). Chủ phòng bấm "Bắt đầu trận", tick "Thêm bot" để lấp chỗ trống.

Điều khiển: WASD/mũi tên. Người trốn đứng trong két vàng để mở (đông người mở nhanh hơn), mở đủ 3 két thì cổng đỏ bên phải chuyển xanh, chạy vào là thoát. Thợ săn chạm là nhốt. Người trốn thắng nếu ít nhất một nửa thoát được.

## Cho đội phát triển

Đọc [CLAUDE.md](CLAUDE.md) trước: kiến trúc client-server, ranh giới module, quy ước code, cách test. Mỗi thư mục module có README riêng nói đã có gì và việc tiếp theo.

## Chi phí server

- Đang phát triển: không cần server (offline, nhiều cửa sổ, LAN).
- Chơi qua mạng với bạn bè: 1 VPS Linux rẻ chạy `godot --headless -- --server`.
- Nhiều người chơi: nhiều tiến trình server, mỗi tiến trình một phòng, cộng thêm dịch vụ ghép trận. Làm sau khi gameplay ổn.

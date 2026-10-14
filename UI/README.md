# UI

Chỉ đọc `GameState.rules`, nghe `EventBus` và gọi API của `Net`. Không đổi luật.

- `main_menu.gd`: offline (chọn vai), tạo/vào phòng, sảnh chờ, thêm bot
- `hud.gd`: vai, đếm ngược, thời gian, chìa, cổng, tiền, cảnh báo rương nổ, bảng kết quả từng người
- `qte_ring.gd`: vòng căn khi cạy rương (vùng đậm, vùng mờ, kim)

Tiếp theo: màn hình kết thúc trận đẹp hơn, theo dõi khi bị nhốt (spectate), minimap, điều khiển cảm ứng.

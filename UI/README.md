# UI

Chỉ đọc `GameState.rules`, nghe `EventBus` và gọi API của `Net`. Không đổi luật.

- `main_menu.gd`: chọn bộ bài người trốn (5 thẻ, lưu `Net.my_deck`), offline (chọn vai), tạo/vào phòng, sảnh chờ, thêm bot
- `hud.gd`: vai, đếm ngược, thời gian, chìa, cổng, máu, tiền, bộ bài, cảnh báo (rương nổ, thợ săn dịch chuyển, radar)
- `minimap.gd`: bản đồ góc phải (tường, rương, cổng, nhà tù, đồng đội); thợ săn thấy dấu chân radar và chạm để chọn điểm dịch chuyển
- `results_screen.gd`: bảng kết quả cuối trận xếp theo điểm
- `qte_ring.gd`: vòng căn khi cạy rương (vùng đậm, vùng mờ, kim)

Tiếp theo: theo dõi khi bị nhốt (spectate), điều khiển cảm ứng (cần analog, nút thẻ), icon thẻ.

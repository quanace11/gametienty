# UI

Chỉ đọc `GameState.rules`, nghe `EventBus` và gọi API của `Net`. Không đổi luật. Giao diện kiểu game chibi dựng bằng code, co theo màn hình.

- `ui_theme.gd`: màu, font, khung bo tròn dùng chung
- `main_menu.gd`: chọn vai offline, chọn bộ bài người trốn (5 thẻ, lưu `Net.my_deck`), tạo / vào phòng, sảnh chờ, thêm bot
- `hud.gd`: thanh trên (đồng hồ, chìa, cổng), hàng đầu người trốn, tim máu + tiền, bộ bài có hồi chiêu hình quạt, thông báo nổi (rương nổ, thợ săn dịch chuyển, radar)
- `touch_controls.gd`: cần analog trái, nút tương tác, cần BẮN của thợ săn (luồng xanh + nút Hủy), thẻ kéo-thả chọn chỗ ném, nút đổi người xem; trong lúc vòng căn chạy thì chạm bất kỳ đâu là căn
- `minimap.gd`: bản đồ góc phải (tường, rương, cổng, nhà tù, đồng đội); thợ săn thấy dấu chân radar và chạm để chọn điểm dịch chuyển
- `qte_ring.gd`: vòng căn bung ra quanh chân khi cạy rương (vùng đậm, vùng mờ, kim, chữ "Được! +tiền" / "Trượt! Mở lại từ đầu")
- `results_screen.gd`: bảng kết quả cuối trận xếp theo điểm

Tiếp theo: chỉnh cỡ nút theo tay thật trên điện thoại, icon thẻ, nút tắt tiếng khi có âm thanh.

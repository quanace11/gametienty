# UI

Chỉ đọc `GameState.rules`, nghe `EventBus` và gọi API của `Net`. Không đổi luật. Giao diện kiểu game chibi dựng bằng code, co theo màn hình.

- `ui_theme.gd`: màu, font, khung bo tròn dùng chung
- `main_menu.gd`: sảnh (nhân vật đã chọn đứng nghỉ giữa màn hình, nút ĐỔI NHÂN VẬT / BẮT ĐẦU), màn chọn nhân vật chia Tiên Môn (đệ tử) / Ma Đạo (ma tu), màn chọn chế độ (luyện công cùng bot, tạo / vào phòng LAN) vào trận theo vai của nhân vật đang chọn; bảng Phù bảo (5 thẻ, lưu `Net.my_deck`) và Cài đặt (đồ họa, FPS)
- `character_roster.gd`: danh sách nhân vật hai phe, tên tiên hiệp, nhớ nhân vật đã chọn ở `user://cai_dat.cfg` (mặc định Lăng Vân Kiếm Tu)
- `lobby_stage.gd`: sân khấu 3D ở sảnh (đài đá, nhân vật phát động tác Idle, vuốt để xoay); menu ẩn thì ngừng vẽ
- `hud.gd`: thanh trên (đồng hồ, chìa, cổng), hàng đầu người trốn, tim máu + tiền, bộ bài có hồi chiêu hình quạt, thông báo nổi (rương nổ, thợ săn dịch chuyển, radar)
- `health_bars.gd`: thanh máu nổi trên đầu mọi nhân vật đang thấy (mỗi ô một máu: đệ tử 2, ma tu 6; mình vàng, cùng phe xanh, phe kia đỏ); vừa mất máu thì ô đó chớp trắng và hiện "-1" bay lên
- `touch_controls.gd`: cần analog trái, nút tương tác, cần PHI KIẾM của ma tu (luồng tím + nút Hủy), nút TRÓI của ma tu (sáng khi có đệ tử gục trong tầm, chạm là trói kéo đi), thẻ kéo-thả chọn chỗ ném, nút đổi người xem; trong lúc vòng căn chạy thì chạm bất kỳ đâu là căn
- `minimap.gd`: bản đồ góc phải (tường, rương, cổng, nhà tù, đồng đội); thợ săn thấy dấu chân radar và chạm để chọn điểm dịch chuyển
- `qte_ring.gd`: vòng căn bung ra quanh chân khi cạy rương (vùng đậm, vùng mờ, kim, chữ "Được! +tiền" / "Trượt! Mở lại từ đầu")
- `results_screen.gd`: bảng kết quả cuối trận xếp theo điểm

Tiếp theo: chỉnh cỡ nút theo tay thật trên điện thoại, icon thẻ, nút tắt tiếng khi có âm thanh.

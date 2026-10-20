# Objects (Thành viên C)

Vật thể tương tác trên bản đồ. Cài đặt `Interactable` và `MapBase`.

- `safe.gd`: trận linh nhỏ (xưa là rương): bệ đá, 4 trụ phù văn, linh tinh xanh lơ lửng, vòng trận loang theo tiến độ; người trốn đứng yên sát trận để giải (đông thì nhanh), chạm màn hình / E khi vòng căn hiện ra; trượt thì trận bùng đỏ, cột sáng đỏ và giải lại từ đầu; giải xong linh tinh thành vàng, văng linh thạch
- `coin.gd`: linh thạch trên sàn (trong code là tiền), chạm là nhặt (mesh dùng chung)
- `exit_gate.gd`: lối ra là cửa phong ấn đặt trong tường động phủ (khung gỗ son, mái đồng, tấm phong ấn cam); giải đủ trận linh thì phong ấn rung 3 giây rồi thành cửa ngọc, đệ tử bước vào là thoát
- `prison.gd`: huyết trận (xưa là nhà tù): kết giới đỏ cao không cửa, trận văn đỏ dưới sàn quay nhanh khi có người bị tế, thợ săn kéo người tới sát tường là nhốt, người bị nhốt mất máu 45 giây rồi bị đốt; chỉ túi máu ném qua tường cứu được. Được cứu thì bước lên đệm lò xo bên trong để bật ra (hướng `exit_side` do bản đồ đặt)
- `bush.gd`: bụi cỏ cao để nấp (luật ở `GameState.can_see()`), mô hình `models/bui_co/` giảm từ grass.glb (30k tam giác) xuống 3 mức theo cài đặt đồ họa: mỗi khóm Thấp ~250, Vừa ~400, Cao ~800 tam giác, mỗi bụi 3 khóm xoay lệch nhau
- `maps/test_map.gd`: bản đồ "Động phủ Linh Đài" 52 x 30 m dựng bằng code theo ảnh thiết kế: phòng truyền tống mái đỏ bên trái (đệ tử xuất hiện), phế tích có hốc tường phía trên (ma tu xuất hiện), huyết trận ở giữa, 4 trận linh ngũ tinh (cần 3), động phủ tường đá bên phải có 2 cửa phong ấn cam là 2 lối ra, linh đài + 4 cột đá bên trong, cửa hang mật đạo (chỉ để nhìn), đá tảng, cây cổ thụ, lối đất, 18 bụi cỏ, 20 linh thạch. Phần trang trí gộp mỗi material một mesh

Tiếp theo: bản đồ dựng trong editor có nhà cửa / đồ vật chibi, bản đồ thứ hai, model cổng và tiền đẹp hơn.

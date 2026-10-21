# Objects (Thành viên C)

Vật thể tương tác trên bản đồ. Cài đặt `Interactable` và `MapBase`.

- `safe.gd`: trận linh nhỏ (xưa là rương): bệ đá, 4 trụ phù văn, linh tinh xanh lơ lửng, vòng trận loang theo tiến độ; người trốn đứng yên sát trận để giải (đông thì nhanh), chạm màn hình / E khi vòng căn hiện ra; trượt thì trận bùng đỏ, cột sáng đỏ và giải lại từ đầu; giải xong linh tinh thành vàng, văng linh thạch
- `coin.gd`: linh thạch trên sàn (trong code là tiền), chạm là nhặt (mesh dùng chung)
- `exit_gate.gd`: lối ra là cửa phong ấn đặt trong tường động phủ (khung gỗ son, mái đồng, tấm phong ấn cam); giải đủ trận linh thì phong ấn rung 3 giây rồi thành cửa ngọc, đệ tử bước vào là thoát
- `prison.gd`: huyết trận (xưa là nhà tù): kết giới đỏ cao không cửa, trận văn đỏ dưới sàn quay nhanh khi có người bị tế, thợ săn kéo người tới sát tường là nhốt, người bị nhốt mất máu 45 giây rồi bị đốt; chỉ túi máu ném qua tường cứu được. Được cứu thì bước lên đệm lò xo bên trong để bật ra (hướng `exit_side` do bản đồ đặt)
- `bush.gd`: bụi cỏ cao để nấp (luật ở `GameState.can_see()`), thành đám rộng 3 - 5 m như bụi Liên Quân, mô hình `models/bui_co/` giảm từ grass.glb (30k tam giác); mỗi bụi Thấp 4 khóm x 250, Vừa 7 x 250, Cao 7 x 400 tam giác, cao 2,1 m (hơn đầu nhân vật)
- `maps/test_map.gd`: bản đồ "Động phủ Linh Đài" 60 x 36 m dựng bằng code theo ảnh thiết kế: phòng truyền tống mái đỏ bên trái (đệ tử xuất hiện), ma tu chui ra từ cửa hang mật đạo bên phải, phế tích có hốc tường phía trên, huyết trận ở giữa, 6 trận linh ngũ tinh (cần 3), động phủ tường đá bên phải có 2 cửa phong ấn cam là 2 lối ra, linh đài + 4 cột đá bên trong, 22 tảng đá chắn đường và phi kiếm, cây cổ thụ, rừng cây quanh viền, lối đất, 23 đám bụi cỏ cao hơn đầu người, 20 linh thạch. Tường cao 2,4 m, cây ~4,5 m: tỉ lệ người / bụi / cây / tường theo kiểu Liên Quân. Phần trang trí gộp mỗi material một mesh trong mỗi ô 15 x 12 m
- `models/kaykit_dungeon/`, `models/kaykit_hex/`: tường, cột, đá vụn, cây, đá, nhà từ bộ KayKit Dungeon Remastered và Medieval Hexagon của Kay Lousberg (CC0, miễn phí cả dùng thương mại, giấy phép trong `LICENSE.txt` mỗi thư mục)

Tiếp theo: bản đồ dựng trong editor có nhà cửa / đồ vật chibi, bản đồ thứ hai, model cổng và tiền đẹp hơn.

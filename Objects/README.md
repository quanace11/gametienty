# Objects (Thành viên C)

Vật thể tương tác trên bản đồ. Cài đặt `Interactable` và `MapBase`.

- `safe.gd`: trận linh nhỏ (xưa là rương): bệ đá, 4 trụ phù văn, linh tinh xanh lơ lửng, vòng trận loang theo tiến độ; người trốn đứng yên sát trận để giải (đông thì nhanh), chạm màn hình / E khi vòng căn hiện ra; trượt thì trận bùng đỏ, cột sáng đỏ và giải lại từ đầu; giải xong linh tinh thành vàng, văng linh thạch
- `coin.gd`: linh thạch trên sàn (trong code là tiền), chạm là nhặt (mesh dùng chung)
- `exit_gate.gd`: lối ra là cửa phong ấn đặt trong tường động phủ (khung gỗ son, mái đồng, tấm phong ấn cam); giải đủ trận linh thì phong ấn rung 3 giây rồi thành cửa ngọc, đệ tử bước vào là thoát
- `prison.gd`: huyết trận (xưa là nhà tù): kết giới đỏ cao không cửa, trận văn đỏ dưới sàn quay nhanh khi có người bị tế, thợ săn kéo người tới sát tường là nhốt, người bị nhốt mất máu 45 giây rồi bị đốt; chỉ túi máu ném qua tường cứu được. Được cứu thì bước lên đệm lò xo bên trong để bật ra (hướng `exit_side` do bản đồ đặt)
- `bush.gd`: bụi cỏ cao để nấp (luật ở `GameState.can_see()`), thành đám rộng 3 - 5 m như bụi Liên Quân, ghép từ khóm cỏ cao Quaternius (Thấp 4, Vừa 6, Cao 9 khóm, ~1,3k - 4,3k tam giác mỗi bụi), cao 2,1 m (hơn đầu nhân vật), màu gốc đậm ngọn sáng bằng `shaders/co.gdshader`
- `maps/test_map.gd`: bản đồ "Động phủ Linh Đài" 60 x 36 m dựng bằng code theo ảnh thiết kế: phòng truyền tống mái đỏ bên trái (đệ tử xuất hiện), ma tu chui ra từ cửa hang mật đạo bên phải, phế tích có hốc tường phía trên, huyết trận ở giữa, 6 trận linh ngũ tinh (cần 3), động phủ tường đá bên phải có 2 cửa phong ấn cam là 2 lối ra, linh đài + 4 cột đá bên trong, 22 tảng đá chắn đường và phi kiếm, cây cổ thụ, viền ngoài kiểu đền đài: vách đá to xếp liền, cột đá chạm trổ nối lan can tròn, 2 cổng đôi có vòng đá ở góc bắc (phía nam thấp cho khỏi che camera), rừng thông phía sau, lối đất có sỏi thưa, cỏ thấp và hoa lác đác trên sân (nhiều ít theo mức đồ họa), màu dịu xanh lục sẫm kiểu bản đồ MOBA, 23 đám bụi cỏ cao hơn đầu người, 20 linh thạch. Tường cao 2,4 m, cây ~5,5 m: tỉ lệ người / bụi / cây / tường theo kiểu Liên Quân. Phần trang trí gộp mỗi material một mesh trong mỗi ô 15 x 12 m
- `models/kaykit_dungeon/`, `models/kaykit_hex/`: tường (đã giảm lưới), cột, nhà mái đỏ từ bộ KayKit Dungeon Remastered và Medieval Hexagon của Kay Lousberg (CC0, giấy phép trong `LICENSE.txt` mỗi thư mục)
- `models/quaternius_nature/`: cây, thông, bụi lá, cỏ, hoa, đá, sỏi từ Quaternius Stylized Nature MegaKit (CC0, `LICENSE.txt`), đổi sang OBJ mỗi phần một file (`_vo` thân, `_la` lá, `_hoa`, `_da`, `_soi`, `_co`), thân cây và đá to đã giảm lưới, ảnh thu về 256 - 512 px
- `shaders/`: `nen.gdshader` nền cỏ / lối đất loang 2 màu theo nhiễu, `co.gdshader` cỏ gốc đậm ngọn sáng

Tiếp theo: bản đồ dựng trong editor có nhà cửa / đồ vật chibi, bản đồ thứ hai, model cổng và tiền đẹp hơn.

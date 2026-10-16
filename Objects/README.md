# Objects (Thành viên C)

Vật thể tương tác trên bản đồ. Cài đặt `Interactable` và `MapBase`.

- `safe.gd`: trận linh nhỏ (xưa là rương): bệ đá, 4 trụ phù văn, linh tinh xanh lơ lửng, vòng trận loang theo tiến độ; người trốn đứng yên sát trận để giải (đông thì nhanh), chạm màn hình / E khi vòng căn hiện ra; trượt thì trận bùng đỏ, cột sáng đỏ và giải lại từ đầu; giải xong linh tinh thành vàng, văng linh thạch
- `coin.gd`: linh thạch trên sàn (trong code là tiền), chạm là nhặt (mesh dùng chung)
- `exit_gate.gd`: lối ra kiểu sơn môn (cột đỏ son, mái ngói) có phong ấn đỏ; giải đủ trận linh thì phong ấn rung 3 giây rồi thành cổng xoáy ngọc
- `prison.gd`: huyết trận (xưa là nhà tù): kết giới đỏ cao không cửa, trận văn đỏ dưới sàn quay nhanh khi có người bị tế, thợ săn kéo người tới sát tường là nhốt, người bị nhốt mất máu 45 giây rồi bị đốt; chỉ túi máu ném qua tường cứu được. Được cứu thì bước lên đệm lò xo bên trong để bật ra (hướng `exit_side` do bản đồ đặt)
- `bush.gd`: bụi cây để nấp (luật ở `GameState.can_see()`)
- `maps/test_map.gd`: bản đồ tiên hiệp chibi 48 x 30 m dựng bằng code: tường vôi trắng mái ngói đen có đèn lồng, hàng rào trúc ở viền, cây tùng, 5 trận linh (cần 3), 2 lối ra hai đầu, 1 huyết trận ở giữa (cạnh trong 4,2 m, vòng đỏ ngoài kết giới đánh dấu vùng nhốt), 12 bụi cây, 20 linh thạch

Tiếp theo: bản đồ dựng trong editor có nhà cửa / đồ vật chibi, bản đồ thứ hai, model cổng và tiền đẹp hơn.

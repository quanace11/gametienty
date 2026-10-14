# Objects (Thành viên C)

Vật thể tương tác trên bản đồ. Cài đặt `Interactable` và `MapBase`.

- `safe.gd`: két, người trốn đứng trong vùng để mở, 2 người x1.5, 3+ người x2
- `exit_gate.gd`: cổng thoát, mở khi đủ két
- `prison.gd`: nhà tù, thợ săn vác người vào là nhốt, người trốn đứng trong là phá khóa
- `maps/test_map.gd`: bản đồ thử 32 x 20 m dựng bằng khối hộp, có đèn và bóng

Tiếp theo: bản đồ thật dựng trong editor (GridMap/model), QTE ở két (fail thì phát `EventBus.qte_failed` và `noise_made`), cổng cần thời gian gạt, cửa, bẫy.

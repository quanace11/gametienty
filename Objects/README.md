# Objects (Thành viên C)

Vật thể tương tác trên bản đồ. Cài đặt `Interactable` và `MapBase`.

- `safe.gd`: rương, người trốn đứng sát để cạy (đông thì nhanh), bấm E khi vòng căn hiện ra; nổ thì cột khói đỏ; mở xong văng tiền
- `coin.gd`: cọc tiền trên sàn, chạm là nhặt (mesh dùng chung)
- `exit_gate.gd`: cổng thoát, đủ chìa thì rung 3 giây rồi mở
- `prison.gd`: nhà tù, thợ săn kéo người vào là nhốt, người bị nhốt mất máu 45 giây rồi bị đốt; chỉ túi máu cứu được (tường cao + đệm lò xo làm sau)
- `maps/test_map.gd`: bản đồ thử 32 x 20 m dựng bằng khối hộp: 5 rương (cần 3), 2 cổng hai đầu, 2 nhà tù, 20 cọc tiền

Tiếp theo: bản đồ thật dựng trong editor (GridMap/model), nhà tù tường cao + đệm lò xo, cửa, bẫy.

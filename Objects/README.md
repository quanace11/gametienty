# Objects (Thành viên C)

Vật thể tương tác trên bản đồ. Cài đặt `Interactable` và `MapBase`.

- `safe.gd`: rương có nắp và đai vàng; người trốn đứng yên sát rương để cạy (đông thì nhanh), chạm màn hình / E khi vòng căn hiện ra; trượt thì rương nổ, cột khói đỏ và mở lại từ đầu; mở xong văng tiền
- `coin.gd`: cọc tiền trên sàn, chạm là nhặt (mesh dùng chung)
- `exit_gate.gd`: cổng thoát, đủ chìa thì rung 3 giây rồi mở
- `prison.gd`: nhà tù tường cao không cửa, thợ săn kéo người tới sát tường là nhốt, người bị nhốt mất máu 45 giây rồi bị đốt; chỉ túi máu ném qua tường cứu được. Được cứu thì bước lên đệm lò xo bên trong để bật ra (hướng `exit_side` do bản đồ đặt)
- `bush.gd`: bụi cây để nấp (luật ở `GameState.can_see()`)
- `maps/test_map.gd`: bản đồ chibi 32 x 20 m dựng bằng code: tường thấp mái ngói, hàng rào cây ở viền, 5 rương (cần 3), 2 cổng hai đầu, 1 nhà tù ở giữa, 8 bụi cây, 20 cọc tiền

Tiếp theo: bản đồ dựng trong editor có nhà cửa / đồ vật chibi, bản đồ thứ hai, model cổng và tiền đẹp hơn.

# AI (Thành viên D)

Bot cho chế độ offline và để lấp chỗ online. Bot là `InputSource`, cắm vào nhân vật như bàn phím, nghĩ 10 lần/giây (`THINK_INTERVAL`); vòng căn và né đạn xét từng frame vì cần chính xác.

- `bot_input_source.gd`: hành vi bot.
  - Người trốn: cạy rương (chọn rương xa thợ săn, gần xong, không trùng đồng đội) và căn vòng; thấy thợ săn trong tầm thì chạy về chỗ thoáng có tường chắn đạn, chạy chữ chi, chui bụi nấp; thấy đạn bay tới thì bước ngang né; đồng đội gục thì người gần nhất tới đỡ; ném túi máu cứu người bị kéo / bị nhốt, lựu đạn / súng lục / ván trượt khi bị đuổi; cổng mở thì chạy cổng không bị canh. Thợ săn đứng im lâu (không đi, không bắn) thì chỉ né khi nó sát bên.
  - Thợ săn: đuổi người thấy được (ưu tiên người còn 1 máu, đang cạy rương), bắn theo hướng ngắm, đón đầu theo hướng chạy, không bắn khi tường chắn; mất dấu thì tới chỗ thấy lần cuối, bật radar đọc dấu chân, dịch chuyển tới chỗ xa; không còn gì thì canh rương sắp mở xong / cổng đang mở.
- `bot_level.gd`: 3 mức Dễ / Trung bình / Khó (khung nhìn, thời gian phản ứng, trí nhớ, tỉ lệ căn trúng, né đạn, ngắm, độ trễ bóp cò...). Chọn bằng `--bot-level=de|tb|kho`, không có thì đọc ProjectSettings `game/bot_level` (menu ghi, `UI/bot_level_setting.gd`). Mức áp cho bot phe địch của người chơi máy này, bot đồng đội luôn Trung bình. Test cân bằng: `--bot-level-hunter=` / `--bot-level-escapee=`.
- `bot_nav_grid.gd`: lưới A* ô 0,5 m dựng một lần mỗi bản đồ bằng cách dò khối va chạm layer 1 (~25 ms), mọi bot dùng chung. Đánh số vùng liền nhau để không tìm đường xuyên tường nhà tù. Vật đặt giữa trận (hộp gỗ) không có trong lưới: kẹt thì bot tự rẽ.

Chơi công bằng: bot chỉ biết những gì người cùng vai thấy. Phe kia chỉ thấy trong khung cỡ màn hình quanh mình (`BotLevel.sight`), không thấy người nấp bụi (`GameState.can_see()`), nhớ chỗ thấy lần cuối vài giây rồi quên. Đồng đội thấy hết như minimap. Thợ săn chỉ biết dấu chân khi bật radar.

Đọc thế giới qua group trong `GameTypes` và `GameState.rules`, không gọi thẳng code module khác.

Cân bằng (12 trận bot mỗi ô, 180 giây, số người trốn bị bắt trung bình / 4):

| Thợ săn \ Người trốn | Dễ | Trung bình | Khó |
|---|---|---|---|
| Dễ | 3,0 | 0,75 | 0,9 |
| Trung bình | 4,0 | 3,6 | 3,4 |
| Khó | 4,0 | 4,0 | 4,0 |

Chạy lại: `godot --headless --fixed-fps 60 --path . -- --offline=hunter --bot --time=180 --quit-after-match --bot-level-hunter=tb --bot-level-escapee=kho` (`--fixed-fps 60` tua nhanh, một trận vài giây).

Tiếp theo: bot dùng đệm lò xo / hộp gỗ, thợ săn đặt bẫy; chỉnh lại số khi có buổi chơi người thật.

# AI (Thành viên D)

Bot cho chế độ offline và để lấp chỗ online. Bot là `InputSource`, cắm vào nhân vật như bàn phím, nghĩ 10 lần/giây (`THINK_INTERVAL`).

- `bot_input_source.gd`: bot người trốn cạy rương và căn vòng (65% trúng vùng đậm), nhặt tiền, chạy trốn khi thợ săn tới gần, đỡ / cứu đồng đội, ném túi máu và lựu đạn đúng chỗ, dùng thẻ; bot thợ săn đuổi, bắn, kéo người gục vào tù, dùng radar và dịch chuyển. Bot không thấy người đang nấp trong bụi (`GameState.can_see()`). Đi đường thẳng tới mục tiêu, kẹt tường thì rẽ ngẫu nhiên

Tiếp theo: NavigationRegion3D + NavigationAgent3D (tính đường thưa để server nhẹ), tuần tra rương cho thợ săn.
Đọc thế giới qua group trong `GameTypes` và `GameState.rules`, không gọi thẳng code module khác.

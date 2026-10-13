# AI (Thành viên D)

Bot cho chế độ offline. Bot là `InputSource`, cắm vào nhân vật như bàn phím.

- `bot_input_source.gd`: bot đơn giản, đi thẳng tới mục tiêu, kẹt thì rẽ ngẫu nhiên

Tiếp theo: NavigationRegion3D + NavigationAgent3D cho bản đồ, tầm nhìn hình nón, nghe `EventBus.noise_made`, state machine Escapee (mở két, chạy trốn, cứu) và Hunter (tuần tra két, đuổi, vác vào tù).
Đọc thế giới qua group trong `GameTypes` và `GameState.rules`, không gọi thẳng code module khác.

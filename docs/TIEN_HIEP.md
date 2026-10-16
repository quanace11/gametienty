# Đổi bối cảnh tiên hiệp: thuật ngữ và ticket

Game chuyển sang bối cảnh tiên hiệp và có một thay đổi luật: phải giải **hết** trận linh thì 2 lối ra mới hiện, và mỗi lối ra phải đứng phá giải một lúc mới đi qua được. Trong code giữ nguyên tên cũ (`safe`, `prison`, `hunter`, `ShotKind.RIFLE`...) để các nhóm không đụng file của nhau; chỉ đổi chữ hiển thị, hình và luật lối ra. Nhóm và tuần theo mục [Kế hoạch](../README.md#kế-hoạch).

## Thuật ngữ

Cột "đề xuất" là gợi ý, Lead chốt trong TH-03 trước khi nhóm 2 đổi chữ.

| Cũ | Mới | Trong code |
|---|---|---|
| Thợ săn | Ma tu (tu sĩ ma tông) | `Role.HUNTER` |
| Người trốn | Đệ tử (đề xuất) | `Role.ESCAPEE` |
| Rương, ổ khóa, cạy | Trận linh nhỏ, giải trận | `safe`, `safe_progress` |
| Chìa khóa | Bỏ; đếm số trận linh đã giải | `safes_unlocked()` |
| Cổng thoát | Lối ra (phải phá giải) | `exit_gate`, `gate_*` |
| Nhà tù, bị đốt | Huyết trận (trận văn tà huyết), bị tế huyết | `prison`, `IMPRISONED` |
| Súng, tên lửa | Phi kiếm | `server_fire_rifle`, `ShotKind.RIFLE` |
| Tiền | Linh thạch (đề xuất) | `coins` |
| Túi cứu thương | Hồi sinh đan (đề xuất) | `ItemType.MEDKIT` |
| Lựu đạn làm chậm | Định thân phù (đề xuất) | `STUN_GRENADE` |
| Súng lục | Phù kiếm (đề xuất) | `PISTOL` |
| Ván trượt | Thần hành phù (đề xuất) | `SPEED_BOOST` |
| Đệm lò xo | Khinh thân trận (đề xuất) | `JUMP_PAD` |
| Bẫy kẹp | Khốn trận (đề xuất) | `TRAP` |
| Hộp gỗ | Thạch tường phù (đề xuất) | `CRATE` |
| Radar dấu chân, dịch chuyển | Thần thức dò tìm, huyết độn (đề xuất) | `RADAR`, `TELEPORT` |

## Ticket

Mỗi ticket là một PR, làm cùng các việc trong bảng tuần của README. TH-02 là gốc của luật mới nên nhóm 1 làm đầu tuần 1.

| Mã | Nhóm | Tuần | Việc | File | Xong khi | Cần trước |
|---|---|---|---|---|---|---|
| TH-01 | 1 | 1 | Luật: phải giải hết trận linh. `safes_required = 0` nghĩa là giải hết, `MatchRules.safes_required()` trả về tổng số trận linh | `Core/types/match_config.gd`, `Core/match/match_rules.gd`, `tests/` | Test luật: giải 4/5 thì lối ra chưa hiện, 5/5 thì hiện | |
| TH-02 | 1 | 1 | Luật: lối ra phải phá giải. Thêm `gate_progress` (0..1 mỗi lối), `channel_gate(id, gate_id, delta)` (người trốn đứng trong vùng, nhiều người cộng dồn, bị choáng / gục thì dừng), `gate_break_time` 8 giây, `escape(id, gate_id)` chỉ được khi lối đó đã phá. Đồng bộ `gates` trong world dict: tiến độ gộp 10 lần/giây, phá xong gửi ngay (khoảng 2 số float, dưới 100 B/s). Tín hiệu mới `gate_progress_changed(gate_id, progress)`, `gate_broken(gate_id)`; `GameState.server_channel_gate()` | `Core/match/`, `Core/game_state.gd`, `Core/event_bus.gd`, `tests/` | Test luật + smoke qua; trận bot có người thoát qua lối ra đã phá | |
| TH-03 | 1 | 1 | Chốt bảng thuật ngữ, sửa `README.md`, `docs/LUAT_TRAN.md`, `docs/CHU_TRINH_BAT.md` theo từ mới | `docs/`, `README.md` | Các nhóm dùng chung một bảng từ | |
| TH-04 | 2 | 2 | Đổi toàn bộ chữ trong menu, HUD, thông báo, bảng kết quả. HUD: "Trận linh 2/5"; ô lối ra ẩn → "Lối ra đang hiện" → "Phá giải 40%" → "Lối ra MỞ"; nút BẮN → PHI KIẾM. Minimap chỉ vẽ lối ra khi đã hiện | `UI/` | Không còn chữ cũ (rương, chìa, cổng, súng, nhà tù) trên màn hình | TH-02, TH-03 |
| TH-05 | 2 | 2 | Nhân vật: ma tu = Rogue trùm đầu tô áo đen tím, sương tím đỏ dưới chân thay vòng đỏ, động tác bắn thành chỉ tay phóng kiếm; đệ tử = Mage của cùng bộ KayKit Adventurers (CC0) thay Knight, dưới 5k tam giác | `Player/player_character.gd`, `Player/models/` | Nhìn ra ngay ai là ma tu, ai là đệ tử | TH-03 |
| TH-06 | 2 | 2 | Phi kiếm thay tên lửa: mesh kiếm (lưỡi, chắn, chuôi) dùng chung, bay xoay theo hướng, vệt sáng tím; trúng / chạm tường thì nổ kiếm khí tím đỏ thay lửa khói; luồng ngắm màu tím. Vẫn dùng pool, không đổi luật đạn | `Player/shot_fx.gd`, `UI/touch_controls.gd` | FPS không tụt khi bắn liên tục | |
| TH-07 | 3 | 1 | Trận linh thay rương: vòng trận phát sáng trên đất, linh thạch lơ lửng ở giữa, 4 trụ phù văn; tiến độ là vòng sáng dần; căn trượt thì trận bùng đỏ (thay cột khói đỏ); giải xong thì linh thạch vỡ, văng linh thạch nhỏ. Va chạm giữ như cũ | `Objects/safe.gd` | Mesh / material dùng chung, đứng giải vẫn ngồi mò như cũ | |
| TH-08 | 3 | 1 | Lối ra: ẩn hẳn (không hình, không vùng) tới khi giải hết; `gate_opening` thì cổng đá + trận đồ mọc lên trong 3 giây; phong ấn đỏ mờ dần theo `gate_progress`; phá xong thành cổng xoáy sáng. `interact_tick`: chưa phá thì `server_channel_gate`, đã phá thì `server_escape(id, gate_id)`; nhãn hiện % | `Objects/exit_gate.gd` | Trận bot: lối ra hiện, bị phá, có người thoát | TH-02 |
| TH-09 | 3 | 2 | Huyết trận thay nhà tù ở giữa bản đồ: tường thành kết giới đỏ trong suốt (giữ va chạm và độ cao), trận văn đỏ dưới sàn quay chậm, vòng máu đầy dần theo thời gian tế huyết, hết giờ thì cột sáng đỏ "bị tế huyết"; đệm lò xo bên trong thành trận truyền tống nhỏ | `Objects/prison.gd` | Luật tù không đổi, smoke qua | |
| TH-10 | 3 | 2-3 | Bản đồ phong cách tiên hiệp: nền đá, tường mái cong, cây tùng, đèn lồng, sương; linh thạch thay cọc tiền. Làm cùng việc chuyển bản đồ sang `.tscn` và bản đồ 2 | `Objects/maps/`, `Objects/coin.gd` | Dưới 60k tam giác trên màn hình, 60 FPS | TH-03 |
| TH-11 | 3 | 2 | Thẻ đạo cụ theo thuật ngữ: tên trong `item_catalog.gd`; hình ném: đan dược thay túi máu, lá phù thay lựu đạn, tường đá thay hộp gỗ, trận nhỏ thay bẫy / đệm | `Items/` | Không đổi số của thẻ | TH-03 |
| TH-12 | 4 | 2 | Bot theo luật mới: đệ tử giải hết trận linh, tới lối ra đã hiện đứng phá giải (ưu tiên lối đã phá nhiều, xa ma tu), chạy khi ma tu tới gần; ma tu canh lối ra đang bị phá | `AI/bot_input_source.gd` | 20 trận bot có người thoát qua cả 2 lối | TH-02, TH-08 |
| TH-13 | 5 | 2 | Âm thanh hợp tiên hiệp (CC0): kiếm vút, trận pháp ngân khi giải, chuông khi lối ra hiện, tiếng vỡ phong ấn, nhạc nền cổ phong; không tìm được bản CC0 hợp thì báo Lead | `Audio/` | Nghe đúng 6 âm cơ bản + 2 âm lối ra | TH-02 |
| TH-14 | 5 | 3 | Hiệu ứng hạt (pool): linh khí bay vào trận linh lúc giải, máu chảy vào huyết trận, mảnh phong ấn vỡ ở lối ra, kiếm khí khi phi kiếm trúng | `Fx/` | Không tạo / xóa node trong trận | TH-07, TH-08, TH-09 |
| TH-15 | 1 | 4 | Cân lại số trận vì giờ phải giải hết và phá lối ra: thời gian trận, thời gian giải trận linh, `gate_break_time` | `Core/types/match_config.gd` | `balance.sh` và buổi chơi thật ra khoảng 50/50 | TH-12 |

# Đổi bối cảnh tiên hiệp: thuật ngữ và ticket

Game chuyển sang bối cảnh tiên hiệp và có một thay đổi luật: phải giải **hết** trận linh thì 2 lối ra mới hiện, và mỗi lối ra phải đứng phá giải một lúc mới đi qua được. Trong code giữ nguyên tên cũ (`safe`, `prison`, `hunter`, `ShotKind.RIFLE`...) để các nhóm không đụng file của nhau. Giao diện, hình, chữ và âm thanh tiên hiệp do Lead làm riêng, không nằm trong các ticket dưới đây; ticket ở đây chỉ là luật và bot. Nhóm và tuần theo mục [Kế hoạch](../README.md#kế-hoạch).

## Thuật ngữ

Cột "đề xuất" là gợi ý, Lead chốt trong TH-03.

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
| TH-04 | 3 | 1 | Lối ra: ẩn hẳn (không hình, không vùng) tới khi giải hết. `interact_tick`: chưa phá thì `server_channel_gate`, đã phá thì `server_escape(id, gate_id)`; nhãn hiện % | `Objects/exit_gate.gd` | Trận bot: lối ra hiện, bị phá, có người thoát | TH-02 |
| TH-05 | 4 | 2 | Bot theo luật mới: đệ tử giải hết trận linh, tới lối ra đã hiện đứng phá giải (ưu tiên lối đã phá nhiều, xa ma tu), chạy khi ma tu tới gần; ma tu canh lối ra đang bị phá | `AI/bot_input_source.gd` | 20 trận bot có người thoát qua cả 2 lối | TH-02, TH-04 |
| TH-06 | 1 | 4 | Cân lại số trận vì giờ phải giải hết và phá lối ra: thời gian trận, thời gian giải trận linh, `gate_break_time` | `Core/types/match_config.gd` | `balance.sh` và buổi chơi thật ra khoảng 50/50 | TH-05 |

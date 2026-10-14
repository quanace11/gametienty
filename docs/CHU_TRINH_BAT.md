# API chu trình bắt người

Đánh, ngã, vác, nhốt, cứu, loại. Tài liệu cho người làm Player (B), Objects (C), AI (D) và UI.

## 1. Bảng chuyển trạng thái (người trốn)

```
              đánh hết máu             thợ săn nhấc             vào nhà tù
  IDLE ─────────────────────> DOWNED ───────────────> CARRIED ──────────────> IMPRISONED
   ▲ ▲  <─── đồng đội đỡ ────    ▲    <── bị thả ────    │                        │  │
   │ │                           │                       │ vùng thoát /           │  │ hết giờ tù /
   │ └───────────────────────────┼───────────────────────┘ thợ săn bị choáng      │  │ bị nhốt lần thứ N
   │                                                                              │  ▼
   └──────────────────────── đồng đội phá khóa ───────────────────────────────────┘  ELIMINATED
  IDLE ── vào cổng đã mở ──> ESCAPED          IDLE <──> RESCUING (đang cứu người khác)
```

Thợ săn luôn `IDLE`, có thêm `carrying_id` (đang vác ai) và `stunned_left` (đang choáng).

Mọi chuyển trạng thái nằm trong `Core/match/match_rules.gd`. Module **không bao giờ** tự gán `state`.

## 2. Gọi lệnh (chỉ có tác dụng trên server)

Tất cả trả về `true` nếu lệnh hợp lệ và đã thực hiện. Gọi sai lúc (gọi 2 lần, gọi khi đã ngã, gọi trên client) thì trả về `false` và **không đổi gì**, nên module không cần tự kiểm tra trước.

| Lệnh | Ai gọi | Khi nào |
|---|---|---|
| `GameState.server_attack(hunter_id, target_ids)` | Player | Thợ săn bấm đánh. `target_ids` là người trong hitbox (module tự tính). Core lo hồi chiêu, bất tử sau khi trúng, trừ máu |
| `GameState.server_pick_up(hunter_id, target_id)` | Player | Thợ săn bấm gần người đang ngã |
| `GameState.server_drop(hunter_id)` | Player | Thợ săn thả người đang vác |
| `GameState.server_imprison(hunter_id, prison_id)` | Objects (nhà tù) | Thợ săn đang vác bước vào nhà tù |
| `GameState.server_channel_rescue(rescuer_id, target_id, delta)` | Player, Objects | **Mỗi physics frame** khi đang giữ nút cứu. Mục tiêu đang ngã thì đỡ dậy, đang bị nhốt thì phá khóa. Nhiều người cứu cùng lúc thì nhanh hơn |
| `GameState.server_add_struggle(target_id, amount)` | Player | Người bị vác bấm vùng vẫy. Không bấm thì vẫn tự thoát sau `carry_escape_time` |
| `GameState.server_stun(id, seconds)` | Items (súng), Objects (bẫy) | Làm choáng. Thợ săn đang vác mà bị choáng thì người bị vác thoát ra |
| `GameState.server_escape(id)` | Objects (cổng) | Người trốn bước vào cổng đã mở |

## 3. Đọc trạng thái (mọi máy)

```gdscript
var rules := GameState.rules
var me := rules.record(peer_id)        # PlayerRecord: state, hp, carrier_id, carrying_id,
                                       # prison_id, prison_time_left, rescue_progress, struggle...
rules.can_move(peer_id)                # có được tự đi không
rules.speed_factor(peer_id)            # nhân với tốc độ chạy: ngã thì bò, đang vác thì chậm, đang cứu thì đứng
rules.can_attack(peer_id)              # thợ săn: hết hồi chiêu, không choáng, không đang vác
rules.is_hittable(peer_id)             # người trốn: đang đứng và không trong thời gian bất tử
```

## 4. Sự kiện (EventBus, phát trên mọi máy)

Dùng để chạy anim, âm thanh, hiệu ứng, HUD, và cho AI "nghe".

| Tín hiệu | Ý nghĩa |
|---|---|
| `player_attacked(attacker_id)` | Thợ săn vung đòn (trúng hay trượt): phát anim vung tay |
| `player_hit(id, attacker_id, hp_left)` | Trúng đòn: chớp đỏ, âm thanh |
| `player_downed(id, attacker_id)` | Ngã |
| `player_picked_up(id, carrier_id)` | Bị nhấc lên vai |
| `player_dropped(id)` | Bị thả xuống |
| `player_released(id)` | Thoát khỏi vai (vùng vẫy hoặc thợ săn bị choáng) |
| `player_imprisoned(id, prison_id)` | Vào tù |
| `player_rescued(id, rescuer_id)` | Được đỡ dậy hoặc ra tù |
| `player_eliminated(id)` | Bị loại |
| `player_escaped(id)` | Thoát qua cổng |
| `player_stunned(id, seconds)` | Bị choáng |
| `rescue_progress_changed(id, progress)` | Thanh tiến độ cứu (10 lần/giây) |
| `player_state_changed(id, old, new)` | Mọi lần đổi trạng thái |

## 5. Cách đồng bộ (vì sao không lệch, không giật)

1. Module gọi lệnh `server_*`. `MatchRules` kiểm tra, đổi dữ liệu, đánh dấu người bị đổi.
2. Cuối physics frame, `GameState.flush()` gửi **nguyên bản** `PlayerRecord` của người bị đổi xuống mọi máy (reliable). Thay đổi quan trọng (đổi trạng thái, máu) gửi ngay; số đổi liên tục (tiến độ cứu, vùng vẫy) gộp lại 10 lần/giây.
3. Mỗi máy so bản cũ với bản mới (`PlayerRecord.events_between`) để sinh sự kiện. Gói tin có gộp nhiều bước thì sự kiện vẫn đúng trạng thái cuối.
4. Giữa hai lần nhận, client tự đếm lùi các con số (giờ tù, vùng vẫy) để thanh tiến độ chạy mượt, nhưng **không bao giờ tự đổi trạng thái**.

Offline đi đúng đường này (server là chính máy mình).

## 6. Cân bằng game

Mọi con số nằm trong `Core/types/match_config.gd`: số máu, hồi chiêu đánh, thời gian bất tử, thời gian vùng thoát, thời gian ở tù, số lần bị nhốt tối đa, thời gian cứu, hệ số tốc độ. Đổi ở đó, không sửa code luật.

## 7. Bản cài đặt mẫu (để chơi được ngay, các thành viên thay dần)

- `Player/player_character.gd`: E/Space: thợ săn nhấc người ngã gần nhất, không có thì vung đòn hình nón trước mặt; người trốn giữ để đỡ đồng đội ngã; bị vác thì bấm liên tục để vùng vẫy. Người bị vác bám theo vai thợ săn, người bị nhốt đứng trong nhà tù.
- `Objects/prison.gd`: thợ săn vác người bước vào là nhốt; người trốn đứng trong vùng là phá khóa, cứu tất cả người trong tù đó.
- `AI/bot_input_source.gd`: thợ săn đánh, nhấc, mang về tù; người trốn mở két, đi cứu khi thợ săn ở xa, vùng vẫy khi bị vác.

## 8. Test

`tests/test_match_rules.gd` kiểm tra từng chuyển trạng thái, các lệnh bị từ chối, đếm thời gian, rời trận giữa chừng và việc sinh sự kiện. Thêm luật mới thì thêm test ở đây.

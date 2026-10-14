# API chu trình bắt người

Đánh gục, kéo lê, nhốt (bị đốt), cứu bằng tay hoặc túi máu. Tài liệu cho người làm Player (B), Objects (C), AI (D) và UI.

## 1. Bảng chuyển trạng thái (người trốn)

```
              đánh hết máu             thợ săn túm              kéo vào tù
  IDLE ─────────────────────> DOWNED ───────────────> CARRIED ──────────────> IMPRISONED
   ▲ ▲  <── giữ E / túi máu ──   ▲    <── bị thả ────    │                        │  │ mất máu dần 45 giây,
   │ │                           │                       │ túi máu /              │  │ hết thì bị đốt chết
   │ └───────────────────────────┼───────────────────────┘ thợ săn bị choáng      │  ▼
   │                                                                              │  ELIMINATED
   └──────────────────────────────── túi máu ─────────────────────────────────────┘
  IDLE ── vào cổng đã mở ──> ESCAPED          IDLE <──> RESCUING (đang giữ E đỡ người khác)
```

- Bị kéo (`CARRIED`): người trốn nằm sau lưng thợ săn, bị khóa hoàn toàn, không nút nào có tác dụng, không tự thoát.
- Cứu người đang gục dưới đất: đứng gần giữ E, hoặc ném túi máu.
- Cứu người đang bị kéo hoặc trong tù: chỉ túi máu (hoặc làm choáng thợ săn khi đang bị kéo).
- Túi máu là vật phẩm mang theo. Tạm thời mỗi người trốn có `medkits_per_escapee` túi; sau này lấy từ bộ bài.

Thợ săn luôn `IDLE`, có thêm `carrying_id` (đang kéo ai) và `stunned_left` (đang choáng).

Mọi chuyển trạng thái nằm trong `Core/match/match_rules.gd`. Module **không bao giờ** tự gán `state`.

## 2. Gọi lệnh (chỉ có tác dụng trên server)

Tất cả trả về `true` nếu lệnh hợp lệ và đã thực hiện. Gọi sai lúc (gọi 2 lần, gọi khi đã ngã, gọi trên client) thì trả về `false` và **không đổi gì**, nên module không cần tự kiểm tra trước.

| Lệnh | Ai gọi | Khi nào |
|---|---|---|
| `GameState.server_fire_mortar(hunter, target)` | Player | Thợ săn bắn cối về điểm `target` (module tự ngắm). Core kẹp tầm, lo hồi chiêu, đạn rơi thì trừ máu người trong vùng nổ. Xem [LUAT_TRAN.md](LUAT_TRAN.md#8-bắn-cối-của-thợ-săn-súng-của-người-trốn) |
| `GameState.server_attack(hunter_id, target_ids)` | (dành cho cận chiến) | Đòn trúng ngay `target_ids`. Core lo hồi chiêu, bất tử sau khi trúng, trừ máu |
| `GameState.server_pick_up(hunter_id, target_id)` | Player | Thợ săn bấm gần người đang gục: túm lấy để kéo |
| `GameState.server_drop(hunter_id)` | Player | Thợ săn thả người đang kéo |
| `GameState.server_imprison(hunter_id, prison_id)` | Objects (nhà tù) | Thợ săn đang kéo người bước vào nhà tù |
| `GameState.server_channel_rescue(rescuer_id, target_id, delta)` | Player | **Mỗi physics frame** khi đang giữ E gần người đang gục. Nhiều người cùng đỡ thì nhanh hơn. Không dùng được cho người bị kéo / bị nhốt |
| `GameState.server_use_medkit(thrower_id, target_id)` | Player, Items | Ném túi máu (module tự kiểm tra tầm `medkit_range` và đường bay). Người đang gục / bị kéo / bị nhốt đứng dậy ngay; đang đứng thì hồi máu. `target_id = thrower_id` là tự dùng |
| `GameState.server_stun(id, seconds)` | Items (súng, lựu đạn), Objects (bẫy) | Làm choáng. Thợ săn đang kéo người mà bị choáng thì buông tay |
| `GameState.server_escape(id)` | Objects (cổng) | Người trốn bước vào cổng đã mở |

## 3. Đọc trạng thái (mọi máy)

```gdscript
var rules := GameState.rules
var me := rules.record(peer_id)        # PlayerRecord: state, hp, carrier_id, carrying_id,
                                       # prison_id, prison_time_left (máu còn trong tù, giây), rescue_progress, items...
rules.item_count(peer_id, GameTypes.ItemType.MEDKIT)  # còn bao nhiêu túi máu
rules.can_move(peer_id)                # có được tự đi không
rules.speed_factor(peer_id)            # nhân với tốc độ chạy: gục thì bò, đang kéo người thì chậm, đang cứu thì đứng
rules.can_attack(peer_id)              # thợ săn: hết hồi chiêu, không choáng, không đang kéo người
rules.is_hittable(peer_id)             # người trốn: đang đứng và không trong thời gian bất tử
```

## 4. Sự kiện (EventBus, phát trên mọi máy)

Dùng để chạy anim, âm thanh, hiệu ứng, HUD, và cho AI "nghe".

| Tín hiệu | Ý nghĩa |
|---|---|
| `player_attacked(attacker_id)` | Thợ săn vung đòn (trúng hay trượt): phát anim vung tay |
| `player_hit(id, attacker_id, hp_left)` | Trúng đòn: chớp đỏ, âm thanh |
| `player_downed(id, attacker_id)` | Ngã |
| `player_picked_up(id, carrier_id)` | Bị túm, bắt đầu bị kéo |
| `player_dropped(id)` | Bị thả xuống |
| `player_released(id)` | Thợ săn bị choáng nên buông tay |
| `player_imprisoned(id, prison_id)` | Vào tù, bắt đầu mất máu |
| `player_healed(id, healer_id, hp)` | Trúng túi máu (để làm hiệu ứng ném) |
| `player_rescued(id, rescuer_id)` | Được đỡ dậy, được túi máu cứu khỏi tay thợ săn hoặc khỏi tù |
| `player_eliminated(id)` | Bị đốt chết trong tù (hoặc rời trận) |
| `player_escaped(id)` | Thoát qua cổng |
| `player_stunned(id, seconds)` | Bị choáng |
| `rescue_progress_changed(id, progress)` | Thanh tiến độ cứu (10 lần/giây) |
| `player_state_changed(id, old, new)` | Mọi lần đổi trạng thái |

## 5. Cách đồng bộ (vì sao không lệch, không giật)

1. Module gọi lệnh `server_*`. `MatchRules` kiểm tra, đổi dữ liệu, đánh dấu người bị đổi.
2. Cuối physics frame, `GameState.flush()` gửi **nguyên bản** `PlayerRecord` của người bị đổi xuống mọi máy (reliable). Thay đổi quan trọng (đổi trạng thái, máu) gửi ngay; số đổi liên tục (tiến độ cứu, máu trong tù) gộp lại 10 lần/giây.
3. Mỗi máy so bản cũ với bản mới (`PlayerRecord.events_between`) để sinh sự kiện. Gói tin có gộp nhiều bước thì sự kiện vẫn đúng trạng thái cuối.
4. Giữa hai lần nhận, client tự đếm lùi các con số (máu trong tù) để thanh tiến độ chạy mượt, nhưng **không bao giờ tự đổi trạng thái**.

Offline đi đúng đường này (server là chính máy mình).

## 6. Cân bằng game

Mọi con số nằm trong `Core/types/match_config.gd`: số máu, hồi chiêu đánh, thời gian bất tử, thời gian bị đốt trong tù (45 giây), số lần bị nhốt tối đa (0 = không giới hạn), thời gian đỡ dậy, số túi máu, tầm ném, hệ số tốc độ. Đổi ở đó, không sửa code luật.

## 7. Bản cài đặt mẫu (để chơi được ngay, các thành viên thay dần)

- `Player/player_character.gd`: E/Space: thợ săn túm người gục gần nhất, không có thì vung đòn hình nón trước mặt; người trốn giữ để đỡ đồng đội gục. Q: ném túi máu cho đồng đội cần cứu gần nhất trong tầm (tạm thời trúng ngay), không có ai thì tự dùng. Người bị kéo nằm sau lưng thợ săn, người bị nhốt đứng trong nhà tù.
- `Objects/prison.gd`: thợ săn kéo người bước vào là nhốt, hiện số giây trước khi bị đốt. Chưa có tường cao và đệm lò xo: được túi máu cứu thì đi thẳng ra ngoài.
- `AI/bot_input_source.gd`: thợ săn đánh, túm, kéo về tù; người trốn mở két, đỡ đồng đội gục khi thợ săn ở xa, tới gần người bị kéo / bị nhốt để ném túi máu.

## 8. Test

`tests/test_match_rules.gd` kiểm tra từng chuyển trạng thái, các lệnh bị từ chối, đếm thời gian, rời trận giữa chừng và việc sinh sự kiện. Thêm luật mới thì thêm test ở đây.

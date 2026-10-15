# Luật trận: rương, vòng căn, tiền, cổng, kết quả

Phần còn lại của trận ngoài chu trình bắt người ([CHU_TRINH_BAT.md](CHU_TRINH_BAT.md)). Mọi con số nằm trong `Core/types/match_config.gd`.

## 1. Rương và chìa khóa

Trong code Core rương vẫn tên là `safe` (`safe_progress`, `GROUP_SAFES`, `safe_unlocked`).

- Người trốn đứng sát rương là cạy (`GameState.server_channel_chest(id, safe_id, delta)` mỗi physics frame). Một người mất `chest_open_time` giây, nhiều người cùng cạy thì cộng dồn.
- Mở xong rương thì nhả 1 chìa khóa và văng `chest_coins` cọc tiền ra sàn. Đủ `safes_required` chìa thì cổng bắt đầu mở.

## 2. Vòng căn

Trong lúc cạy, cứ `qte_interval_min..max` giây vòng căn hiện ra một lần: kim chạy một vòng trong `1 / qte_speed` giây, trên vòng có vùng sáng đậm ở giữa và vùng mờ hai bên. Vị trí vùng do server random.

| Bấm E khi kim ở | Kết quả |
|---|---|
| Vùng sáng đậm (`qte_perfect_width`) | `PERFECT`: rương mở thêm `qte_perfect_bonus`, được `qte_perfect_coins` tiền |
| Vùng mờ (`qte_good_width`) | `GOOD`: được `qte_good_coins` tiền, không tăng tốc |
| Ngoài vùng, hoặc không bấm hết vòng | `FAIL`: "Đoàng!", rương về 0, cột khói đỏ báo vị trí cho mọi người kể cả thợ săn |

Rời rương khi vòng đang chạy thì vòng biến mất, không phạt.

Chấm điểm trên server (`MatchRules.resolve_qte`). Server tự đo độ trễ của từng máy (`Net.latency_of`) và lùi kim lại đúng chừng đó, kẹp tối đa `qte_grace`, nên người ping cao không bị thiệt và không ai khai gian được. Rương (Objects) đọc nút bằng `EntityBase.just_pressed(&"interact")`. UI vẽ vòng từ `qte_zone`, `qte_started` và `MatchRules.elapsed`.

Sự kiện: `qte_started(id, safe_id)`, `qte_resolved(id, safe_id, result)`.

## 3. Tiền

- Tiền rải sẵn: bản đồ trả vị trí qua `MapBase.get_coin_spots()`, id là thứ tự. Tiền từ rương có id `MatchRules.chest_coin_ids(safe_id)`.
- Người trốn chạm vào là nhặt (`GameState.server_take_coin`). `PlayerRecord.coins` là tiền đang có (để mua thẻ), `coins_earned` là tổng cả trận (tính điểm).
- Sự kiện: `coin_taken(coin_id, by_id)`, `coins_changed(id, coins, gained)`.

## 4. Hai cổng

- Bản đồ có 2 cổng ở hai đầu đối diện.
- Đủ chìa: `gate_opening(seconds)`, cả 2 cổng rung và nháy đèn `gate_open_delay` (3) giây, chưa qua được. Sau đó `gate_opened`, mở tới hết trận.

## 5. Kết quả (tính riêng từng người)

Trận hết khi không còn người trốn nào ở ngoài, hết giờ, hoặc thợ săn rời trận. `EventBus.match_ended(result)` mang `MatchRules.results()`:

- Người trốn thoát qua cổng: `ESCAPED`, có `score_escape` cộng điểm rương, cứu bạn, căn đẹp, tiền, sát thương bắn thợ săn (`damage`).
- Bị nhốt, bị loại, hoặc kẹt lại khi hết giờ: `CAUGHT`, chỉ có điểm rương, cứu bạn, căn đẹp, tiền, sát thương.
- Thợ săn theo số người bắt được (4 người trốn): 0-1 `LOSE`, 2-3 `PARTIAL`, 4 `TOTAL`. Số người khác 4 thì: bắt hết là `TOTAL`, từ một nửa là `PARTIAL`.
- Thợ săn rời trận giữa chừng: ai chưa bị nhốt/loại coi như thoát.

## 6. Đồng bộ

Rương, cổng, tiền trên sàn, vật đặt, đạn đang bay là "thế giới" (`MatchRules.world_dict()`), đồng bộ như người chơi: server chỉ gửi phần đổi (`WorldRecord.diff`), mỗi máy dựng lại rồi tự sinh sự kiện (`WorldRecord.events_between`). Rương xong, rương về 0, cổng, tiền bị nhặt, vật đặt, đạn bắn / rơi gửi ngay; tiến độ rương bình thường gộp 10 lần/giây.

## 7. Thẻ đạo cụ (bộ bài)

Mỗi người có bộ bài 5 ô (`MatchConfig.deck_size`), bấm nút `skill_1..skill_5` (phím 1-5 hoặc Q/R/F/G/T) để dùng. Mỗi lần dùng **trả tiền** (`cost`) và có hồi chiêu. Vào trận có sẵn `start_coins`.

| Thẻ | Giá | Hồi | Tác dụng |
|---|---|---|---|
| Túi cứu thương | 10 | 6 s | Kéo thẻ chọn chỗ ném trong 8 m (chạm nhanh: dưới chân). Túi bay 6 m/s (ít nhất 0,4 giây). Rơi thành vùng tròn xanh bán kính 1,2 m: mọi người trốn trong vùng (cả người ném) được cứu / hồi máu; người được nhắm lúc ném lệch thêm 0,6 m vẫn được cứu. Lúc rơi không ai cần cứu thì túi nằm chờ 8 giây, người trốn cần cứu chạy tới đón là được cứu (người bị nhốt không tự ra đón được). Hết giờ thì mất, vẫn mất tiền |
| Lựu đạn làm chậm | 10 | 12 s | Kéo thẻ chọn chỗ ném trong 8 m (chạm nhanh: dưới chân), nổ bán kính 2.5 m, thợ săn chạy chậm một nửa trong 2 giây (không choáng, không buông người) |
| Súng lục | 4 | 1.5 s | Tự nhắm thợ săn trong 10 m, ngắm đón đầu; trúng thì thợ săn mất 1 máu (xem mục 8). Không có thợ săn trong tầm thì không bắn, không mất tiền |
| Ván trượt | 5 | 12 s | Chạy nhanh x1.7 trong 3.5 giây |
| Đệm lò xo | 6 | 8 s | Kéo thẻ đặt xa tới 6 m (chạm nhanh: dưới chân), bước lên là bật vút theo hướng ném, qua được tường cao (vào / ra nhà tù) |
| Bẫy kẹp | 6 | 10 s | Kéo thẻ đặt xa tới 4 m (chạm nhanh: dưới chân), thợ săn dẫm vào thì chạy chậm một nửa trong 2.5 giây; thợ săn thấy mờ |
| Hộp gỗ | 5 | 10 s | Kéo thẻ đặt xa tới 4 m (chạm nhanh: trước mặt), vật cản chắn đường, chắn đạn trong 15 giây |

Thẻ kéo-thả (`ItemData.aim_range > 0`): giữ thẻ rồi kéo, dưới đất hiện vòng tầm xa nhất quanh nhân vật và vòng chỗ rơi (bán kính `area_radius`); thả tay mới dùng, kéo tới nút Hủy rồi thả thì thôi. Máy người chơi gửi chỗ ném trong `aim` của gói input sẵn có (không thêm dữ liệu mạng); server đọc qua `EntityBase.aim_offset()` (hướng x, z thế giới, độ xa 0..1).

Bộ bài mặc định của người trốn: túi cứu thương, lựu đạn, súng lục, ván trượt, đệm lò xo. Người chơi chọn bộ bài ở menu (thứ tự chọn = ô 1..5), gửi lên server khi vào phòng, đi kèm `info["decks"]`. Luật tự lọc: bỏ thẻ không có, thẻ không dành cho vai mình (`allowed_roles`), thẻ trùng, quá 5 ô; lọc xong rỗng thì dùng bộ mặc định. Thợ săn luôn dùng bộ của thợ săn (mục 9).

Cách chạy (server): Core (Match) thấy nút thẻ vừa bấm thì gọi `GameState.server_use_item(user, slot)`:

1. Hỏi hiệu ứng `ItemEffect.plan(user)` (Items) có dùng được không, nhắm ai / chỗ nào. Không được thì không mất tiền.
2. `MatchRules.use_item` trừ tiền, tính hồi chiêu, ghi `item_seq` để mọi máy phát `item_used`.
3. `ItemEffect.server_apply` làm hiệu ứng bằng lệnh `server_heal`, `server_stun`, `server_speed_boost`, `server_place`, `server_shoot_bullet`.

Vật thể đặt xuống đất nằm trong `MatchRules.placed` (đồng bộ như rương), mọi máy dựng node theo `object_placed` / `object_removed`. Phần luật của vật thể (bẫy kẹp, đệm hất) chạy trong node đó trên server.

Thêm thẻ mới: thêm giá trị vào `GameTypes.ItemType` (Lead), viết `Items/effects/<tên>.gd` (extends `ItemEffect`), khai báo trong `Items/item_catalog.gd`. Không cần sửa Core.

## 8. Bắn: súng của thợ săn, súng lục của người trốn

Thợ săn không đánh cận chiến. Bấm E / Space (không có người gục để túm) là **bắn súng**:

- Ngắm tay: kéo cần ngắm (hoặc giữ chuột phải), máy mình hiện luồng xanh chỉ hướng và tầm bắn (dừng ở tường), thả tay thì client gửi nút `shoot` kèm hướng ngắm (`InputSource.get_aim()`), server bắn theo hướng đó hết tầm. Kéo về giữa hoặc vào nút Hủy rồi thả thì không bắn.
- Tự nhắm (E / chạm nhanh nút BẮN): người trốn gần nhất trong tầm `rifle_range` (12 m) ở phía trước (góc 150°), nhắm vào chỗ người đó đang đứng (không đón đầu, người đang chạy vẫn né được; muốn trúng người chạy thì tự kéo cần ngắm canh góc). Không có ai thì bắn thẳng về phía trước.
- Đạn bay **đường thẳng** ngang tầm ngực, tốc độ `rifle_speed` (15 m/s, 10 m mất gần 0.7 giây, thấy tên lửa bay tới thì kịp né). Server raycast một lần lúc bắn: gặp tường / vật cản (layer 1, kể cả hộp gỗ) thì đạn dừng ở đó.
- Đạn bay thật: mỗi frame server xét đoạn đạn vừa bay qua, chạm người trốn đầu tiên nằm trong `rifle_radius` (0.3 m, cộng thân người, bằng bề rộng luồng ngắm) thì nổ ở đó, người đó mất 1 máu (2 lần là gục). Bước ra khỏi đường bay trước khi đạn tới là né được. Súng lục cũng bay và trúng theo cách này. Một viên chỉ trúng một người. Hồi chiêu `attack_cooldown`.
- Bắn xong thì người bắn khựng lại `shoot_flinch_time` (0.25 giây, đi chậm còn `flinch_speed` = 20%); người trốn trúng đạn khựng `hit_flinch_time` (0.35 giây). Súng lục cũng làm người bắn khựng, nhưng thợ săn trúng đạn thì không khựng. Khựng chỉ tính trên server (di chuyển do server quyết), không gửi thêm dữ liệu.

Người trốn có **súng lục** (thẻ trong bộ bài), đạn cũng bay thẳng và bị tường chặn. Thợ săn có `hunter_max_hp` (6) máu. **Người trốn không làm choáng được thợ săn**: hết máu thì thợ săn buông người đang kéo, chạy chậm `hunter_knockout_slow_factor` (một nửa) trong `hunter_knockout_slow` (3 giây), và hồi đầy máu ngay. Mỗi máu bắn mất được `score_damage` điểm.

Cách chạy (server):

1. Player gọi `GameState.server_fire_rifle(hunter, target)`; Items (súng lục) gọi `GameState.server_shoot_bullet(shooter, target)`. GameState kẹp tầm bắn, raycast tìm tường, ghi viên đạn vào `MatchRules.shots` kèm giờ rơi.
2. Mỗi physics frame Match gọi `GameState.server_land_shots(entities)`: đạn tới giờ thì tìm người gần nòng nhất đứng sát đường bay (theo mặt sàn, cộng 0.3 m thân người, lọc bằng `MatchRules.can_be_shot`) rồi gọi `MatchRules.land_shot`. Súng thợ săn chỉ trúng người trốn, súng lục chỉ trúng thợ săn.
3. Đạn đồng bộ như vật đặt: bắn thì gửi một lần (điểm đầu, điểm rơi, giờ bắn, giờ rơi), rơi thì chỉ gửi id. Mọi máy phát `shot_fired` / `shot_landed`; ai trúng thì có `player_hit` riêng. Client tự vẽ đường bay, không gửi vị trí đạn từng frame.

`MatchRules.attack(hunter, targets)` (đòn trúng ngay) vẫn giữ cho vũ khí cận chiến sau này.

## 9. Thợ săn: radar dấu chân, dịch chuyển

Bộ bài của thợ săn (0 xu): **Radar dấu chân** (hồi 15 giây) và **Dịch chuyển** (hồi 30 giây), phím 1 và 2.

- Server ghi vị trí người trốn mỗi `footprint_interval` (0.5 giây), giữ `footprint_history` (6 giây). Bật radar thì server gửi các dấu chân đó **chỉ tới máy thợ săn** (`EventBus.footprints_revealed`), hiện chấm đỏ mờ dần trên minimap trong `radar_time` (4 giây). Máy khác không nhận gì.
- Dịch chuyển: thợ săn chạm minimap để chọn điểm (`GameState.set_aim_point`, server kẹp trong bản đồ), rồi bấm thẻ. Chưa chọn thì tới cạnh rương đang mở nhiều nhất. Server tìm chỗ đứng được gần điểm đó (tránh tường, tránh nhà tù), thợ săn đứng yên tụ lực `teleport_charge` (1.75 giây) rồi mới tới. Lúc tụ lực có cột tím ở cả chỗ đứng và chỗ tới, người trốn được báo. Bị choáng thì hủy; đang kéo người thì không dùng được.

## 10. Bụi cây

- Bản đồ khai báo bụi cây qua `MapBase.get_bushes()`: `Vector3(x, z, bán kính)`.
- Mỗi frame server ghi mỗi người đang đứng trong bụi nào (`GameState.bush_at()`).
- `GameState.can_see(người nhìn, người bị nhìn)`: người đứng trong bụi thì **phe kia** không thấy, trừ khi người nhìn đứng cùng bụi đó. Đồng đội luôn thấy nhau.
- Server gửi gói vị trí riêng cho từng máy (`Match._send_snapshot`): người máy đó không được thấy thì gửi `null`, nên không lộ vị trí. Máy nhận gọi `EntityBase.set_concealed(true)` để ẩn hình. Máy chủ phòng / offline tự ẩn theo `can_see` mỗi frame.
- Bot, súng tự nhắm của thợ săn, súng lục và lựu đạn tự nhắm cũng dùng `can_see`, nên không nhắm được người đang nấp. Bắn mù vào bụi vẫn trúng nếu đạn đi qua người.
- Radar dấu chân của thợ săn vẫn thấy dấu chân người nấp (đó là tác dụng của radar).

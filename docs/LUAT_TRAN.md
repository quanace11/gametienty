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

- Người trốn thoát qua cổng: `ESCAPED`, có `score_escape` cộng điểm rương, cứu bạn, căn đẹp, tiền.
- Bị nhốt, bị loại, hoặc kẹt lại khi hết giờ: `CAUGHT`, chỉ có điểm rương, cứu bạn, căn đẹp, tiền.
- Thợ săn theo số người bắt được (4 người trốn): 0-1 `LOSE`, 2-3 `PARTIAL`, 4 `TOTAL`. Số người khác 4 thì: bắt hết là `TOTAL`, từ một nửa là `PARTIAL`.
- Thợ săn rời trận giữa chừng: ai chưa bị nhốt/loại coi như thoát.

## 6. Đồng bộ

Rương, cổng, tiền trên sàn là "thế giới" (`MatchRules.world_dict()`), đồng bộ như người chơi: server chỉ gửi phần đổi (`WorldRecord.diff`), mỗi máy dựng lại rồi tự sinh sự kiện (`WorldRecord.events_between`). Rương xong, rương về 0, cổng, tiền bị nhặt gửi ngay; tiến độ rương bình thường gộp 10 lần/giây.

## 7. Thẻ đạo cụ (bộ bài)

Mỗi người có bộ bài 4 ô (`MatchConfig.deck_size`), bấm nút `skill_1..skill_4` (phím 1-4 hoặc Q/R/F/G) để dùng. Mỗi lần dùng **trả tiền** (`cost`) và có hồi chiêu. Vào trận có sẵn `start_coins`.

| Thẻ | Giá | Hồi | Tác dụng |
|---|---|---|---|
| Túi cứu thương | 10 | 6 s | Ném cho đồng đội đang bị kéo / bị nhốt / gục gần nhất trong 8 m (đứng dậy ngay), không có ai thì tự hồi máu |
| Lựu đạn choáng | 10 | 12 s | Tự nhắm thợ săn gần nhất trong 8 m, nổ bán kính 2.5 m, choáng 2 giây (đang kéo người thì buông) |
| Ván trượt | 5 | 12 s | Chạy nhanh x1.7 trong 3.5 giây |
| Đệm lò xo | 6 | 8 s | Đặt trước mặt, bước lên là bật vút qua tường cao (vào / ra nhà tù) |
| Bẫy kẹp | 6 | 10 s | Đặt dưới chân, thợ săn dẫm vào bị kẹp 2.5 giây; thợ săn thấy mờ |
| Hộp gỗ | 5 | 10 s | Vật cản chắn đường, chắn đạn trong 15 giây |

Bộ bài mặc định của người trốn: túi cứu thương, lựu đạn, ván trượt, đệm lò xo. Màn chọn bộ bài làm ở UI sau; Core đã nhận `info["decks"]`.

Cách chạy (server): Core (Match) thấy nút thẻ vừa bấm thì gọi `GameState.server_use_item(user, slot)`:

1. Hỏi hiệu ứng `ItemEffect.plan(user)` (Items) có dùng được không, nhắm ai / chỗ nào. Không được thì không mất tiền.
2. `MatchRules.use_item` trừ tiền, tính hồi chiêu, ghi `item_seq` để mọi máy phát `item_used`.
3. `ItemEffect.server_apply` làm hiệu ứng bằng lệnh `server_heal`, `server_stun`, `server_speed_boost`, `server_place`.

Vật thể đặt xuống đất nằm trong `MatchRules.placed` (đồng bộ như rương), mọi máy dựng node theo `object_placed` / `object_removed`. Phần luật của vật thể (bẫy kẹp, đệm hất) chạy trong node đó trên server.

Thêm thẻ mới: thêm giá trị vào `GameTypes.ItemType` (Lead), viết `Items/effects/<tên>.gd` (extends `ItemEffect`), khai báo trong `Items/item_catalog.gd`. Không cần sửa Core.

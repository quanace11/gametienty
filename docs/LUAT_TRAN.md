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

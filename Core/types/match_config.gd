class_name MatchConfig
extends Resource
## Thông số một trận. Đổi cân bằng game ở đây, không sửa code luật.

@export_group("Trận")
@export var duration := 180.0 # giây
@export var countdown := 3.0
@export var safes_required := 3 # số rương (chìa khóa) phải mở để cổng mở
@export var gate_open_delay := 3.0 # đủ chìa thì cổng rung 3 giây rồi mới mở

@export_group("Rương và vòng căn")
@export var chest_open_time := 8.0 # giây mở xong một rương khi một người mở, không tính vòng căn
@export var qte_interval_min := 1.5 # giây giữa hai lần vòng căn hiện ra
@export var qte_interval_max := 3.5
@export var qte_speed := 0.8 # vòng/giây kim chạy
@export var qte_zone_min := 0.3 # vị trí vùng sáng trên vòng (0..1), random trong khoảng này
@export var qte_zone_max := 0.85
@export var qte_perfect_width := 0.035 # nửa bề rộng vùng sáng đậm (phần vòng)
@export var qte_good_width := 0.1 # nửa bề rộng vùng mờ bên ngoài
@export var qte_grace := 0.2 # giây bù độ trễ mạng tối đa khi chấm điểm (server tự đo trễ từng máy)
@export var qte_perfect_bonus := 0.15 # căn trúng vùng đậm: rương mở thêm chừng này
@export var qte_perfect_coins := 6
@export var qte_good_coins := 2 # vùng mờ: được ít tiền, không tăng tốc
@export var chest_coins := 6 # số cọc tiền văng ra khi mở xong rương
@export var chest_coin_value := 5
@export var floor_coin_value := 2

@export_group("Đánh và bắn")
@export var max_hp := 2 # số đòn để người trốn ngã
@export var attack_cooldown := 1.2 # giây giữa hai phát súng của thợ săn
@export var shoot_flinch_time := 0.25 # giây khựng lại sau khi bắn (thợ săn bắn súng, người trốn bắn súng lục)
@export var hit_flinch_time := 0.35 # giây người trốn khựng lại khi trúng đạn (thợ săn trúng đạn thì không khựng)
@export var flinch_speed := 0.2 # hệ số tốc độ lúc khựng
@export var hit_invulnerable_time := 1.0 # sau khi trúng đòn/được cứu, không bị đánh tiếp
@export var hunter_max_hp := 6 # máu thợ săn (số viên súng lục)
@export var hunter_knockout_slow := 3.0 # thợ săn hết máu: buông người đang kéo, chạy chậm chừng này giây, rồi hồi đầy (không bị choáng)
@export var hunter_knockout_slow_factor := 0.5
@export var rifle_range := 12.0 # mét, tầm súng thợ săn (tường chặn đạn)
@export var rifle_speed := 25.0 # m/s, đạn bay thẳng
@export var rifle_radius := 0.5 # mét, đạn đi qua gần chừng này (cộng thân người) là trúng
@export var bullet_range := 10.0 # mét, tầm súng lục
@export var bullet_speed := 30.0
@export var bullet_radius := 0.8
@export var bullet_damage := 1

@export_group("Kéo và nhà tù")
@export var prison_time := 45.0 # gục trong tù chừng này giây mà không được cứu thì bị đốt chết
@export var max_imprisonments := 0 # bị nhốt lần thứ N thì bị loại luôn; 0 = không giới hạn

@export_group("Cứu")
@export var revive_time := 4.0 # đỡ đồng đội đang ngã dậy (một người cứu)
@export var revive_hp := 1 # máu sau khi được đỡ dậy bằng tay hoặc thoát khỏi thợ săn

@export_group("Thẻ đạo cụ")
@export var start_coins := 12 # tiền lúc vào trận, đủ dùng một thẻ rẻ
@export var deck_size := 5 # số ô thẻ (nút skill_1..skill_5)
@export var medkit_heal := 1 # máu hồi; người đang gục/bị kéo/bị nhốt thì đứng dậy ngay
@export var medkit_range := 8.0 # mét, tầm ném (Items kiểm tra khoảng cách)

@export_group("Thợ săn: radar và dịch chuyển")
@export var teleport_charge := 1.75 # giây đứng tụ lực trước khi dịch chuyển (bị choáng thì hủy)
@export var radar_time := 4.0 # giây dấu chân hiện trên màn hình thợ săn
@export var footprint_interval := 0.5 # server ghi vị trí người trốn mỗi chừng này giây
@export var footprint_history := 6.0 # radar thấy dấu chân trong chừng này giây gần nhất

@export_group("Tốc độ (hệ số)")
@export var downed_speed := 0.3 # bò
@export var carrying_speed := 0.85 # thợ săn đang kéo người
@export var rescuing_speed := 0.0 # đứng yên khi đang cứu

@export_group("Điểm cuối trận")
@export var score_escape := 100 # chỉ người thoát được mới có
@export var score_chest := 40 # mỗi rương góp công (tính theo phần đã mở)
@export var score_rescue := 30 # mỗi lần cứu đồng đội
@export var score_perfect_qte := 5
@export var score_per_coin := 1 # theo tổng tiền nhặt được
@export var score_damage := 10 # mỗi máu bắn mất của thợ săn
@export var score_hunter_catch := 100 # thợ săn: mỗi người bắt được

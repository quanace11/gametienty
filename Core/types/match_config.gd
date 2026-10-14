class_name MatchConfig
extends Resource
## Thông số một trận. Đổi cân bằng game ở đây, không sửa code luật.

@export_group("Trận")
@export var duration := 180.0 # giây
@export var countdown := 3.0
@export var safes_required := 3 # số két phải mở để cổng mở
@export var escapees_to_win := 0 # 0 = một nửa số người trốn (làm tròn lên)

@export_group("Đánh")
@export var max_hp := 2 # số đòn để người trốn ngã
@export var attack_cooldown := 1.2 # giây giữa hai đòn của thợ săn
@export var hit_invulnerable_time := 1.0 # sau khi trúng đòn/được cứu, không bị đánh tiếp

@export_group("Kéo và nhà tù")
@export var prison_time := 45.0 # gục trong tù chừng này giây mà không được cứu thì bị đốt chết
@export var max_imprisonments := 0 # bị nhốt lần thứ N thì bị loại luôn; 0 = không giới hạn

@export_group("Cứu")
@export var revive_time := 4.0 # đỡ đồng đội đang ngã dậy (một người cứu)
@export var revive_hp := 1 # máu sau khi được đỡ dậy bằng tay hoặc thoát khỏi thợ săn

@export_group("Túi máu")
@export var medkits_per_escapee := 2 # tạm thời, sau thay bằng bộ bài
@export var medkit_heal := 1 # máu hồi; người đang gục/bị kéo/bị nhốt thì đứng dậy ngay
@export var medkit_range := 8.0 # mét, tầm ném (Player kiểm tra khoảng cách)

@export_group("Tốc độ (hệ số)")
@export var downed_speed := 0.3 # bò
@export var carrying_speed := 0.85 # thợ săn đang kéo người
@export var rescuing_speed := 0.0 # đứng yên khi đang cứu

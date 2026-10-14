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

@export_group("Vác và nhà tù")
@export var carry_escape_time := 12.0 # bị vác lâu chừng này thì tự vùng thoát
@export var stun_after_struggle := 1.5 # thợ săn bị choáng khi người bị vác vùng thoát
@export var prison_time := 60.0 # ở tù quá lâu thì bị loại
@export var max_imprisonments := 2 # bị nhốt lần thứ N thì bị loại luôn

@export_group("Cứu")
@export var revive_time := 4.0 # đỡ đồng đội đang ngã dậy (một người cứu)
@export var prison_rescue_time := 3.0 # phá khóa nhà tù (một người cứu)
@export var revive_hp := 1 # máu sau khi được đỡ dậy

@export_group("Tốc độ (hệ số)")
@export var downed_speed := 0.3 # bò
@export var carrying_speed := 0.85 # thợ săn đang vác
@export var rescuing_speed := 0.0 # đứng yên khi đang cứu

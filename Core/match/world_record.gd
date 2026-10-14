class_name WorldRecord
extends RefCounted
## Sinh sự kiện EventBus khi trạng thái thế giới (rương, cổng, tiền trên sàn, vật đặt, đạn bay)
## đổi từ `old` sang `new` (hai dict từ MatchRules.world_dict()). Giống
## PlayerRecord.events_between: hàm thuần, mọi máy ra cùng sự kiện.


## Gói gửi qua mạng: chỉ phần đổi (rương đổi, cọc tiền mới bị nhặt, cổng, vật đặt, đạn).
static func diff(old: Dictionary, new: Dictionary) -> Dictionary:
	var out := {}
	if old.is_empty():
		return new.duplicate(true)
	if old["gate_open"] != new["gate_open"]:
		out["gate_open"] = new["gate_open"]
	if old["gate_opening"] != new["gate_opening"]:
		out["gate_opening"] = new["gate_opening"]
		out["gate_opening_left"] = new["gate_opening_left"] # client tự đếm lùi, chỉ gửi lúc bắt đầu
	var safes := {}
	for safe_id: int in new["safes"]:
		if old["safes"].get(safe_id, -1.0) != new["safes"][safe_id]:
			safes[safe_id] = new["safes"][safe_id]
	if not safes.is_empty():
		out["safes"] = safes
	var taken := {}
	for coin_id: int in new["coins_taken"]:
		if not old["coins_taken"].has(coin_id):
			taken[coin_id] = new["coins_taken"][coin_id]
	if not taken.is_empty():
		out["coins_taken"] = taken
	_diff_keys(old["placed"], new["placed"], out, "placed_add", "placed_remove")
	_diff_keys(old["shots"], new["shots"], out, "shot_add", "shot_remove")
	return out


## Phần tử mới gửi nguyên thông tin; phần tử đã mất chỉ gửi id.
static func _diff_keys(old: Dictionary, new: Dictionary, out: Dictionary, add_key: String, remove_key: String) -> void:
	var added := {}
	for k: int in new:
		if not old.has(k):
			added[k] = new[k]
	var removed := []
	for k: int in old:
		if not new.has(k):
			removed.append(k)
	if not added.is_empty():
		out[add_key] = added
	if not removed.is_empty():
		out[remove_key] = removed


## Dựng bản đầy đủ mới từ bản cũ + gói diff(). Không đổi `base`.
static func apply_diff(base: Dictionary, changes: Dictionary) -> Dictionary:
	var d := base.duplicate(true)
	for key: String in ["gate_open", "gate_opening", "gate_opening_left"]:
		if changes.has(key):
			d[key] = changes[key]
	for safe_id: int in changes.get("safes", {}):
		d["safes"][safe_id] = changes["safes"][safe_id]
	for coin_id: int in changes.get("coins_taken", {}):
		d["coins_taken"][coin_id] = changes["coins_taken"][coin_id]
	for obj_id: int in changes.get("placed_add", {}):
		d["placed"][obj_id] = changes["placed_add"][obj_id]
	for obj_id: int in changes.get("placed_remove", []):
		d["placed"].erase(obj_id)
	for shot_id: int in changes.get("shot_add", {}):
		d["shots"][shot_id] = changes["shot_add"][shot_id]
	for shot_id: int in changes.get("shot_remove", []):
		d["shots"].erase(shot_id)
	return d


static func events_between(old: Dictionary, new: Dictionary, required: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if old.is_empty():
		return out
	var unlocked := 0
	for safe_id: int in new["safes"]:
		if new["safes"][safe_id] >= 1.0:
			unlocked += 1
	for safe_id: int in new["safes"]:
		var a: float = old["safes"].get(safe_id, 0.0)
		var b: float = new["safes"][safe_id]
		if a == b:
			continue
		out.append({"signal": &"safe_progress_changed", "args": [safe_id, b]})
		if b >= 1.0 and a < 1.0:
			out.append({"signal": &"safe_unlocked", "args": [safe_id, unlocked, required]})
	if new["gate_opening"] and not old["gate_opening"] and not new["gate_open"]:
		out.append({"signal": &"gate_opening", "args": [new["gate_opening_left"]]})
	if new["gate_open"] and not old["gate_open"]:
		out.append({"signal": &"gate_opened", "args": []})
	for coin_id: int in new["coins_taken"]:
		if not old["coins_taken"].has(coin_id):
			out.append({"signal": &"coin_taken", "args": [coin_id, new["coins_taken"][coin_id]]})
	for obj_id: int in new["placed"]:
		if not old["placed"].has(obj_id):
			var o: Dictionary = new["placed"][obj_id]
			out.append({"signal": &"object_placed", "args": [obj_id, o["type"], o["pos"], o["yaw"], o["owner"]]})
	for obj_id: int in old["placed"]:
		if not new["placed"].has(obj_id):
			out.append({"signal": &"object_removed", "args": [obj_id]})
	for shot_id: int in new["shots"]:
		if not old["shots"].has(shot_id):
			var s: Dictionary = new["shots"][shot_id]
			out.append({"signal": &"shot_fired", "args": [shot_id, s["kind"], s["owner"], s["from"], s["to"], s["lands"] - s["fired"]]})
	for shot_id: int in old["shots"]:
		if not new["shots"].has(shot_id):
			var s: Dictionary = old["shots"][shot_id]
			out.append({"signal": &"shot_landed", "args": [shot_id, s["kind"], s["to"]]})
	return out

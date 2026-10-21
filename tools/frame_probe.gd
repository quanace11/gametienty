extends Node
## Đo giật khung hình (bật bằng --perf-log): ghi lại mọi khung hình chậm hơn
## SPIKE_MS kể từ lúc vào trận, in tóm tắt sau WINDOW giây. Chạy được trên điện
## thoại: xem bằng `adb logcat -s godot`. Chỉ để đo, không ảnh hưởng luật.

const SPIKE_MS := 34.0 # chậm hơn 2 khung hình 60 FPS
const WINDOW := 12.0 # giây đầu trận cần đo

var _start_us := 0
var _last_us := 0
var _frames := 0
var _spikes := 0
var _worst_ms := 0.0
var _lost_ms := 0.0
var _running := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Net.match_started.connect(_on_match_started)
	set_process(false)


func _on_match_started(_info: Dictionary) -> void:
	_start_us = Time.get_ticks_usec()
	_last_us = _start_us
	_frames = 0
	_spikes = 0
	_worst_ms = 0.0
	_lost_ms = 0.0
	_running = true
	set_process(true)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	_frames += 1
	var t := (now - _start_us) / 1000000.0
	if ms > SPIKE_MS:
		_spikes += 1
		_lost_ms += ms - 1000.0 / 60.0
		_worst_ms = maxf(_worst_ms, ms)
		print("[perf] %.2fs khung hình %.0f ms" % [t, ms])
	if t >= WINDOW:
		print("[perf] %.0f giây đầu: %d khung hình, %d lần giật > %.0f ms, chậm nhất %.0f ms, tổng mất %.0f ms" % [
			WINDOW, _frames, _spikes, SPIKE_MS, _worst_ms, _lost_ms])
		_running = false
		set_process(false)

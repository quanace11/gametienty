#!/usr/bin/env bash
# Kiểm tra nhanh toàn bộ game, chạy được trên máy dev và trên CI.
#   GODOT=/duong/dan/godot tools/smoke_test.sh
# 1. Test luật thuần logic.
# 2. Một trận offline (người + 4 bot trên cùng máy).
# 3. Một trận online thật: 1 server riêng + 2 client qua mạng + bot lấp chỗ.
# Trận online LUÔN phải qua, kể cả khi đội đang chỉ làm offline: đây là
# hàng rào chặn code chỉ chạy được offline.
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGS="${LOGS:-$(mktemp -d)}"
PORT="${PORT:-7790}"
TIME="${TIME:-60}"
fail=0

run() { timeout 120 "$GODOT" --headless --path "$ROOT" "$@"; }

check_log() { # tên_log mô_tả
	local f="$LOGS/$1.log"
	if grep -q "SCRIPT ERROR" "$f"; then
		echo "FAIL $2: có SCRIPT ERROR"; grep -A4 "SCRIPT ERROR" "$f" | head -20; fail=1
	elif ! grep -q "Hết trận" "$f"; then
		echo "FAIL $2: trận không kết thúc"; tail -20 "$f"; fail=1
	else
		echo "OK   $2: $(grep 'Hết trận' "$f" | head -1)"
	fi
}

echo "== Import project"
run --import > "$LOGS/import.log" 2>&1 || true

echo "== Test luật"
if run -s tests/test_match_rules.gd > "$LOGS/rules.log" 2>&1; then
	echo "OK   test luật"
else
	echo "FAIL test luật"; cat "$LOGS/rules.log"; fail=1
fi

echo "== Trận offline"
run -- --offline=escapee --bot --time="$TIME" --quit-after-match > "$LOGS/offline.log" 2>&1 || true
check_log offline "offline"

echo "== Trận online (1 server + 2 client)"
run -- --server --port="$PORT" --auto-start=2 --fill-bots --time="$TIME" --quit-after-match > "$LOGS/server.log" 2>&1 &
sleep 2
run -- --join=127.0.0.1 --port="$PORT" --name=Client1 --bot --quit-after-match > "$LOGS/client1.log" 2>&1 &
run -- --join=127.0.0.1 --port="$PORT" --name=Client2 --bot --quit-after-match > "$LOGS/client2.log" 2>&1 &
wait || true
for n in server client1 client2; do check_log "$n" "online/$n"; done

# Mọi máy phải thấy cùng một kết quả.
results=$(for n in server client1 client2; do grep -o "Hết trận.*" "$LOGS/$n.log" | head -1; done | sort -u | wc -l)
if [ "$results" != "1" ]; then echo "FAIL online: các máy thấy kết quả khác nhau"; fail=1; fi

echo "Log: $LOGS"
exit $fail

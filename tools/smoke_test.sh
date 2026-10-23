#!/usr/bin/env bash
# Kiểm tra nhanh toàn bộ game, chạy được trên máy dev và trên CI.
#   GODOT=/duong/dan/godot tools/smoke_test.sh
# 1. Test luật thuần logic.
# 2. Một trận offline (người + 4 bot trên cùng máy).
# 3. Một trận online thật: 1 server riêng + 2 client qua mạng + bot lấp chỗ.
# 4. Online qua mạng xấu (tools/udp_proxy.py: ping 150 ms, mất 3% gói, dao động 20 ms).
# 5. Thợ săn đứng yên: người trốn phải mở được cổng và thoát.
# 6. Một client rớt mạng 12 giây giữa trận: bot chơi thay, client vào lại đúng ghế.
# Trận online LUÔN phải qua, kể cả khi đội đang chỉ làm offline: đây là
# hàng rào chặn code chỉ chạy được offline.
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGS="${LOGS:-$(mktemp -d)}"
PORT="${PORT:-7790}"
TIME="${TIME:-60}"
fail=0

run() { timeout $((${MATCH_TIME:-$TIME} + 90)) "$GODOT" --headless --path "$ROOT" "$@"; }

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

# online_run TÊN "CỜ_SERVER" TRỄ MẤT DAO_ĐỘNG [CẮT_TỪ CẮT_TRONG]
# Client1 đi qua proxy, Client2 nối thẳng.
online_run() {
	local tag=$1 sflags=$2 proxy_port=$((PORT + 1))
	python3 -I "$ROOT/tools/udp_proxy.py" "$proxy_port" "$PORT" "$3" "$4" "$5" "$LOGS/$tag.proxy.json" ${6:-} ${7:-} &
	local px=$!
	# shellcheck disable=SC2086
	run -- --server --port="$PORT" --auto-start=2 --fill-bots --time="${MATCH_TIME:-$TIME}" --quit-after-match $sflags > "$LOGS/$tag.server.log" 2>&1 &
	local sp=$!
	sleep 2
	run -- --join=127.0.0.1 --port="$proxy_port" --name=Client1 --bot --quit-after-match > "$LOGS/$tag.client1.log" 2>&1 &
	local c1=$!
	run -- --join=127.0.0.1 --port="$PORT" --name=Client2 --bot --quit-after-match > "$LOGS/$tag.client2.log" 2>&1 &
	local c2=$!
	wait $sp $c1 $c2 || true
	kill $px 2>/dev/null; wait $px 2>/dev/null || true
	for n in server client1 client2; do check_log "$tag.$n" "$tag/$n"; done
	local r
	r=$(for n in server client1 client2; do grep -o "Hết trận.*" "$LOGS/$tag.$n.log" | head -1; done | sort -u | wc -l)
	if [ "$r" != "1" ]; then echo "FAIL $tag: các máy thấy kết quả khác nhau"; fail=1; fi
}

echo "== Online qua mạng xấu (ping 150 ms, mất 3% gói)"
online_run lag "" 75 0.03 20

echo "== Thợ săn đứng yên: người trốn phải thoát được"
MATCH_TIME=180 online_run escape "--idle-hunter" 0 0 0 # 6 rương + mở cổng cần ~2 phút
if ! grep -q "Hết trận.*thoát [1-9]" "$LOGS/escape.server.log"; then
	echo "FAIL escape: không ai thoát được khi thợ săn đứng yên"; fail=1
fi

echo "== Rớt mạng giữa trận rồi vào lại"
online_run rejoin "" 0 0 0 12 12
if ! grep -q "rớt mạng, bot chơi thay" "$LOGS/rejoin.server.log" || ! grep -q "vào lại trận" "$LOGS/rejoin.server.log"; then
	echo "FAIL rejoin: không thấy rớt mạng / vào lại trong log server"; grep -h "Ghế\|Mất\|vào lại" "$LOGS"/rejoin.*.log | head; fail=1
else
	echo "OK   rejoin: $(grep -h "vào lại trận" "$LOGS/rejoin.server.log" | head -1)"
fi

echo "Log: $LOGS"
exit $fail

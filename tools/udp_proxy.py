"""Proxy UDP giả lập mạng xấu cho test online (tools/smoke_test.sh).

python3 tools/udp_proxy.py CỔNG_NGHE CỔNG_SERVER TRỄ_MS MẤT_GÓI DAO_ĐỘNG_MS FILE_JSON [CẮT_TỪ_GIÂY CẮT_TRONG_GIÂY]

- TRỄ_MS: trễ một chiều (ping = 2 lần), DAO_ĐỘNG_MS: cộng thêm ngẫu nhiên 0..x.
- MẤT_GÓI: tỉ lệ bỏ gói mỗi chiều (0.03 = 3%).
- CẮT_TỪ/CẮT_TRONG: sau gói đầu tiên CẮT_TỪ giây thì bỏ hết gói trong
  CẮT_TRONG giây (giả rớt mạng để test vào lại trận).
- FILE_JSON: mỗi giây ghi số byte / gói mỗi chiều (đo băng thông).
"""
import asyncio
import json
import random
import sys
import time

listen_port, server_port = int(sys.argv[1]), int(sys.argv[2])
delay = float(sys.argv[3]) / 1000.0
loss = float(sys.argv[4])
jitter = float(sys.argv[5]) / 1000.0
out = sys.argv[6]
cut_from = float(sys.argv[7]) if len(sys.argv) > 7 else -1.0
cut_for = float(sys.argv[8]) if len(sys.argv) > 8 else 0.0
stats = {"up_bytes": 0, "up_pkts": 0, "down_bytes": 0, "down_pkts": 0, "up_lost": 0, "down_lost": 0,
         "t0": None, "t1": None, "cut": False}
clients = {}  # địa chỉ client -> kết nối tới server


def dropped():
    if cut_from >= 0 and stats["t0"] is not None:
        t = time.time() - stats["t0"]
        if cut_from <= t < cut_from + cut_for:
            stats["cut"] = True
            return True
    return random.random() < loss


def later(fn, *a):
    d = delay + (random.uniform(0, jitter) if jitter else 0.0)
    asyncio.get_running_loop().call_later(d, fn, *a)


class ToServer(asyncio.DatagramProtocol):
    def __init__(self, front, caddr):
        self.front, self.caddr = front, caddr

    def connection_made(self, t):
        self.t = t

    def datagram_received(self, data, addr):
        stats["down_bytes"] += len(data)
        stats["down_pkts"] += 1
        stats["t1"] = time.time()
        if dropped():
            stats["down_lost"] += 1
            return
        later(self.front.sendto, data, self.caddr)


class Front(asyncio.DatagramProtocol):
    def connection_made(self, t):
        self.t = t

    def datagram_received(self, data, addr):
        stats["up_bytes"] += len(data)
        stats["up_pkts"] += 1
        if stats["t0"] is None:
            stats["t0"] = time.time()
        stats["t1"] = time.time()
        if addr not in clients:
            clients[addr] = None
            asyncio.ensure_future(self._open(addr, data))
            return
        if clients[addr] is None:
            return
        if dropped():
            stats["up_lost"] += 1
            return
        later(clients[addr].t.sendto, data)

    async def _open(self, addr, first):
        loop = asyncio.get_running_loop()
        _, p = await loop.create_datagram_endpoint(lambda: ToServer(self.t, addr), remote_addr=("127.0.0.1", server_port))
        clients[addr] = p
        later(p.t.sendto, first)


async def main():
    loop = asyncio.get_running_loop()
    await loop.create_datagram_endpoint(Front, local_addr=("127.0.0.1", listen_port))
    while True:
        await asyncio.sleep(1)
        with open(out, "w") as f:
            json.dump(stats, f)

asyncio.run(main())

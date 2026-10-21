"""Dựng bản đồ từ tệp Meshy quan gửi (một lưới ~30k tam giác, 4 ảnh 2048 px, 16 MB).

Chạy: python3 -I build_ban_do.py map_meshy.glb ../../models/ban_do_meshy/ban_do.glb ../../maps/meshy_va_cham.gd

1. Đặt vào hệ tọa độ trận: góc trong tường tây bắc ở (0, 0), sân 50 x 45 m, mặt cỏ ở y = 0.
   Ngang dọc cùng một tỉ lệ (không méo), chiều cao nén còn 0,75 cho bụi, tường thấp hơn đầu người một chút.
2. Hạ nền phòng truyền tống (mô hình gốc kê cao ~0,7 m) xuống sát mặt cỏ để người đứng đúng sàn.
3. Ảnh màu thu về 1024 px, dịu màu kiểu bản đồ MOBA; bỏ ảnh phát sáng, normal map, ảnh kim loại.
4. Bản đồ độ cao 0,25 m: ô nào cao hơn BLOCK_HEIGHT thành vật cản, gộp thành hình chữ nhật,
   ghi ra tệp GDScript (const BLOCKS) cho bản đồ dựng va chạm và vẽ minimap.
"""

import io
import json
import struct
import sys

import numpy as np
from PIL import Image, ImageEnhance

INNER_X = (-0.725, 0.725) # mép trong tường tây / đông trong mô hình gốc
INNER_Z = (-0.6125, 0.70) # mép trong tường bắc / nam
GROUND_Y = -0.172 # mặt cỏ trong mô hình gốc
SIZE = (50.0, 45.0) # sân trong trận (m)
SCALE = SIZE[0] / (INNER_X[1] - INNER_X[0])
HEIGHT_SCALE = 0.75
SPAWN_ROOM = (0.0, 23.2, 7.0, 33.0) # x0, z0, x1, z1 (m): nền kê cao cần hạ
SPAWN_DROP = 0.7
TEXTURE_SIZE = 1024
CELL = 0.25 # ô bản đồ độ cao (m)
BLOCK_HEIGHT = 0.55 # cao hơn chừng này (m) là vật cản (sỏi, lối đá thấp hơn)
BLOCK_CELL = 0.5 # ô gộp vật cản (m): thô hơn cho ít hình chữ nhật


def read_glb(path):
	d = open(path, "rb").read()
	n = struct.unpack("<I", d[12:16])[0]
	j = json.loads(d[20:20 + n])
	b = d[20 + n + 8:]

	def acc(i):
		a = j["accessors"][i]
		bv = j["bufferViews"][a["bufferView"]]
		k = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[a["type"]]
		dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a["componentType"]]
		x = np.frombuffer(b, dt, a["count"] * k, bv.get("byteOffset", 0) + a.get("byteOffset", 0))
		return x.reshape(-1, k) if k > 1 else x

	p = j["meshes"][0]["primitives"][0]
	mat = j["materials"][p.get("material", 0)]
	src = j["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]
	bv = j["bufferViews"][j["images"][src]["bufferView"]]
	o = bv.get("byteOffset", 0)
	img = Image.open(io.BytesIO(b[o:o + bv["byteLength"]])).convert("RGB")
	a = p["attributes"]
	return (acc(a["POSITION"]).astype(np.float64), acc(a["NORMAL"]).astype(np.float64),
		acc(a["TEXCOORD_0"]).astype(np.float32), acc(p["indices"]).reshape(-1, 3).astype(np.int64), img)


def to_game(pos, nor):
	p = np.empty_like(pos)
	p[:, 0] = (pos[:, 0] - INNER_X[0]) * SCALE
	p[:, 2] = (pos[:, 2] - INNER_Z[0]) * SCALE
	p[:, 1] = (pos[:, 1] - GROUND_Y) * SCALE * HEIGHT_SCALE
	n = nor / np.array([1.0, HEIGHT_SCALE, 1.0]) # pháp tuyến theo nghịch đảo phép co
	n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
	x0, z0, x1, z1 = SPAWN_ROOM
	inside = (p[:, 0] > x0) & (p[:, 0] < x1) & (p[:, 2] > z0) & (p[:, 2] < z1)
	p[inside, 1] = np.maximum(p[inside, 1] - SPAWN_DROP, np.minimum(p[inside, 1], 0.0))
	return p, n


def grade(img):
	"""Dịu màu: bớt rực, tối nhẹ, ngả xanh lục sẫm như bản đồ MOBA."""
	img = img.resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.LANCZOS)
	img = ImageEnhance.Color(img).enhance(0.5)
	img = ImageEnhance.Brightness(img).enhance(0.8)
	a = np.asarray(img, np.float32)
	a = a * np.array([0.95, 0.97, 1.03]) # bớt vàng
	return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def height_map(pos, tris):
	w, h = int(SIZE[0] / CELL), int(SIZE[1] / CELL)
	hm = np.zeros((h, w))
	t = pos[tris]
	edge = np.max([np.linalg.norm(t[:, i] - t[:, (i + 1) % 3], axis=1) for i in range(3)], axis=0)
	steps = np.clip(np.ceil(edge / CELL * 2), 2, 400).astype(int)
	for n in np.unique(steps):
		tt = t[steps == n]
		for a in range(n + 1):
			for c in range(n + 1 - a):
				q = tt[:, 0] * (1 - (a + c) / n) + tt[:, 1] * (a / n) + tt[:, 2] * (c / n)
				ix = np.floor(q[:, 0] / CELL).astype(int)
				iz = np.floor(q[:, 2] / CELL).astype(int)
				ok = (ix >= 0) & (ix < w) & (iz >= 0) & (iz < h)
				np.maximum.at(hm, (iz[ok], ix[ok]), q[ok, 1])
	return hm


def rects(mask):
	"""Gộp ô bị chặn thành ít hình chữ nhật (tham lam: kéo ngang rồi kéo dọc)."""
	m = mask.copy()
	out = []
	h, w = m.shape
	for z in range(h):
		x = 0
		while x < w:
			if not m[z, x]:
				x += 1
				continue
			x1 = x
			while x1 < w and m[z, x1]:
				x1 += 1
			z1 = z + 1
			while z1 < h and m[z1, x:x1].all():
				z1 += 1
			m[z:z1, x:x1] = False
			out.append((x * CELL, z * CELL, (x1 - x) * CELL, (z1 - z) * CELL))
			x = x1
	return out


def write_glb(path, pos, nor, uv, tris, img):
	blob = bytearray()
	views, accs = [], []

	def add(data, target=None):
		while len(blob) % 4:
			blob.append(0)
		v = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)}
		if target:
			v["target"] = target
		views.append(v)
		blob.extend(data)
		return len(views) - 1

	def add_acc(arr, typ, comp, minmax=False, target=34962):
		a = {"bufferView": add(arr.tobytes(), target), "componentType": comp, "count": len(arr), "type": typ}
		if minmax:
			a["min"] = arr.min(0).tolist()
			a["max"] = arr.max(0).tolist()
		accs.append(a)
		return len(accs) - 1

	attrs = {
		"POSITION": add_acc(pos.astype(np.float32), "VEC3", 5126, True),
		"NORMAL": add_acc(nor.astype(np.float32), "VEC3", 5126),
		"TEXCOORD_0": add_acc(uv.astype(np.float32), "VEC2", 5126),
	}
	idx = add_acc(tris.astype(np.uint32).ravel(), "SCALAR", 5125, target=34963)
	b = io.BytesIO()
	img.save(b, "JPEG", quality=88)
	gltf = {
		"asset": {"version": "2.0", "generator": "build_ban_do.py"},
		"scene": 0,
		"scenes": [{"nodes": [0]}],
		"nodes": [{"name": "BanDo", "mesh": 0}],
		"meshes": [{"name": "BanDo", "primitives": [{"attributes": attrs, "indices": idx, "material": 0}]}],
		"materials": [{
			"name": "ban_do",
			"doubleSided": True, # lưới gốc lật mặt lung tung
			"pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 1.0},
		}],
		"textures": [{"source": 0, "sampler": 0}],
		"samplers": [{"magFilter": 9729, "minFilter": 9987}],
		"images": [{"bufferView": add(b.getvalue()), "mimeType": "image/jpeg"}],
		"accessors": accs,
		"bufferViews": views,
		"buffers": [{"byteLength": len(blob)}],
	}
	js = json.dumps(gltf, separators=(",", ":")).encode()
	js += b" " * (-len(js) % 4)
	while len(blob) % 4:
		blob.append(0)
	out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob))
	out += struct.pack("<II", len(js), 0x4E4F534A) + js
	out += struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
	open(path, "wb").write(out)


def main(src, dst_glb, dst_gd):
	pos, nor, uv, tris, img = read_glb(src)
	pos, nor = to_game(pos, nor)
	write_glb(dst_glb, pos, nor, uv, tris, grade(img))
	hm = height_map(pos, tris)
	np.save(dst_glb + ".hm.npy", hm)
	k = int(BLOCK_CELL / CELL)
	hh, ww = hm.shape[0] // k, hm.shape[1] // k
	coarse = hm[:hh * k, :ww * k].reshape(hh, k, ww, k).max(axis=(1, 3))
	blocks = [tuple(v * k for v in r) for r in rects(coarse > BLOCK_HEIGHT)]
	lines = ["## Sinh bởi Objects/tools/ban_do_meshy/build_ban_do.py, đừng sửa tay.",
		"## Vật cản (tường, đá, bụi, cột) đo từ độ cao lưới bản đồ Meshy: Rect2(x, z, rộng, sâu), mét.",
		"", "const BLOCKS: Array[Rect2] = ["]
	lines += ["\tRect2(%g, %g, %g, %g)," % r for r in blocks]
	lines += ["]"]
	open(dst_gd, "w").write("\n".join(lines) + "\n")
	print("tam giác", len(tris), "vật cản", len(blocks))


if __name__ == "__main__":
	main(*sys.argv[1:4])

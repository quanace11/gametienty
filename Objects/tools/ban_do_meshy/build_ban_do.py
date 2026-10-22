"""Đưa bản Meshy quan gửi (một lưới ~30k tam giác, ảnh 2048 px) vào hệ tọa độ trận.

Chạy: python3 -I build_ban_do.py map_meshy.glb ../../models/ban_do_meshy/ban_do.glb

1. Mép trong viền đá (đo từ bản đồ độ cao) khớp sân 50 x 45 m, mặt cỏ ở y = 0.
2. Chiều cao: phần sát đất (lối đất, lối đá kê cao ~25 cm) nén còn 0,35 để chân người không lún;
   phần cao (vách đá, lan can, cổng vòng) nén 0,6 cho viền thấp hơn, đỡ che camera.
3. Chia lưới thành ô 4 x 3 theo tâm tam giác, mỗi ô một mesh để camera chỉ vẽ ô đang thấy.
4. Giữ nguyên màu gốc: ảnh màu thu về 1024 px (nằm trong GLB, cho đồ họa Thấp / Vừa), ảnh 2048 px gốc
   chép nguyên ra mau_goc.jpg (đồ họa Cao); bỏ normal map, ảnh phát sáng, ảnh kim loại.
5. Phá bờ kè tây chỗ đặt pháp trận truyền tống: bỏ tam giác vách đá, lan can chạm vào vòng CUT (giữ mặt đất),
   tường vòng của pháp trận nối vào 2 đầu bờ kè. Đổi chỗ pháp trận (TELEPORT trong maps/test_map.gd) thì sửa CUT.
"""

import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

INNER_X = (-0.816, 0.82)
INNER_Z = (-0.804, 0.816)
GROUND_Y = -0.119
SIZE = (50.0, 45.0)
LOW = 0.3 # m: dưới mức này là mặt đất
LOW_SCALE = 0.35
HIGH_SCALE = 0.6
TEXTURE_SIZE = 1024
CHUNKS = (4, 3) # số ô theo x, z
CUT = (1.6, 29.4, 4.0) # tâm x, z và bán kính (m) vòng phá bờ kè
CUT_ABOVE = 0.05 # m: chỉ bỏ phần cao hơn mặt đất


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

	def image(tex):
		src = j["textures"][tex["index"]]["source"]
		bv = j["bufferViews"][j["images"][src]["bufferView"]]
		o = bv.get("byteOffset", 0)
		return bytes(b[o:o + bv["byteLength"]])

	p = j["meshes"][0]["primitives"][0]
	mat = j["materials"][p.get("material", 0)]
	a = p["attributes"]
	return (acc(a["POSITION"]).astype(np.float64), acc(a["NORMAL"]).astype(np.float64),
		acc(a["TEXCOORD_0"]).astype(np.float32), acc(p["indices"]).reshape(-1, 3).astype(np.int64),
		image(mat["pbrMetallicRoughness"]["baseColorTexture"]))


def to_game(pos, nor):
	sx = SIZE[0] / (INNER_X[1] - INNER_X[0])
	sz = SIZE[1] / (INNER_Z[1] - INNER_Z[0])
	p = np.empty_like(pos)
	p[:, 0] = (pos[:, 0] - INNER_X[0]) * sx
	p[:, 2] = (pos[:, 2] - INNER_Z[0]) * sz
	y = (pos[:, 1] - GROUND_Y) * (sx + sz) / 2
	p[:, 1] = np.where(y < LOW, y * LOW_SCALE, LOW * LOW_SCALE + (y - LOW) * HIGH_SCALE)
	ys = np.where(y < LOW, LOW_SCALE, HIGH_SCALE)
	n = nor / np.stack([np.full_like(ys, sx), (sx + sz) / 2 * ys, np.full_like(ys, sz)], axis=1)
	n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
	return p, n


def write_glb(path, pos, nor, uv, chunks, img):
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

	def add_img(im, fmt, mime):
		b = io.BytesIO()
		im.save(b, fmt, quality=90) if fmt == "JPEG" else im.save(b, fmt)
		return {"bufferView": add(b.getvalue()), "mimeType": mime}

	meshes = []
	for tris in chunks:
		used, local = np.unique(tris, return_inverse=True)
		attrs = {
			"POSITION": add_acc(pos[used].astype(np.float32), "VEC3", 5126, True),
			"NORMAL": add_acc(nor[used].astype(np.float32), "VEC3", 5126),
			"TEXCOORD_0": add_acc(uv[used].astype(np.float32), "VEC2", 5126),
		}
		idx = add_acc(local.astype(np.uint32).ravel(), "SCALAR", 5125, target=34963)
		meshes.append({"name": "O%d" % len(meshes), "primitives": [{"attributes": attrs, "indices": idx, "material": 0}]})
	gltf = {
		"asset": {"version": "2.0", "generator": "build_ban_do.py"},
		"scene": 0,
		"scenes": [{"nodes": list(range(len(meshes)))}],
		"nodes": [{"name": m["name"], "mesh": i} for i, m in enumerate(meshes)],
		"meshes": meshes,
		"materials": [{
			"name": "ban_do",
			"doubleSided": True, # lưới gốc lật mặt lung tung
			"pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 1.0},
		}],
		"textures": [{"source": 0, "sampler": 0}],
		"samplers": [{"magFilter": 9729, "minFilter": 9987}],
		"images": [add_img(img, "JPEG", "image/jpeg")],
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


def main(src, dst):
	pos, nor, uv, tris, raw = read_glb(src)
	open(os.path.join(os.path.dirname(dst), "mau_goc.jpg"), "wb").write(raw)
	img = Image.open(io.BytesIO(raw)).convert("RGB")
	pos, nor = to_game(pos, nor)
	c = pos[tris].mean(axis=1)
	v = pos[tris] # tam giác x 3 đỉnh x 3
	pts = np.concatenate([v, c[:, None]], axis=1) # 3 đỉnh và tâm (lan can dài: 2 đầu ngoài vòng, giữa trong vòng)
	inside = (np.hypot(pts[:, :, 0] - CUT[0], pts[:, :, 2] - CUT[1]) < CUT[2]).any(axis=1)
	keep = ~inside | (v[:, :, 1].max(axis=1) < CUT_ABOVE)
	tris, c = tris[keep], c[keep]
	cx = np.clip((c[:, 0] / SIZE[0] * CHUNKS[0]).astype(int), 0, CHUNKS[0] - 1)
	cz = np.clip((c[:, 2] / SIZE[1] * CHUNKS[1]).astype(int), 0, CHUNKS[1] - 1)
	cell = cz * CHUNKS[0] + cx
	chunks = [tris[cell == k] for k in range(CHUNKS[0] * CHUNKS[1]) if (cell == k).any()]
	write_glb(dst, pos, nor, uv, chunks, img.resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.LANCZOS))
	print("tam giác", len(tris), "ô", [len(t) for t in chunks], "cao nhất", round(float(pos[:, 1].max()), 2), "m")


if __name__ == "__main__":
	main(*sys.argv[1:3])

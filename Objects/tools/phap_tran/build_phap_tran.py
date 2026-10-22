"""Đưa mô hình pháp trận truyền tống Meshy quan gửi (~29k tam giác, ảnh 2048 px) vào game.

Chạy: python3 -I build_phap_tran.py phap_tran_meshy.glb ../../models/phap_tran/phap_tran.glb
Cần numpy, scipy, Pillow, meshoptimizer, xatlas (chỉ cho công cụ này, game không dùng).

1. Giảm lưới còn ~TRIS tam giác bằng meshoptimizer. Lưới Meshy cắt UV thành rất nhiều mảnh nhỏ nên
   gộp đỉnh trùng vị trí rồi mới giảm được, và UV cũ không dùng lại được nữa.
2. Trải UV mới (xatlas) rồi nướng lại ảnh: mỗi điểm ảnh mới lấy màu của điểm gần nhất trên lưới gốc
   (cùng hướng mặt), nướng ở BAKE px rồi thu nhỏ cho mịn.
3. Tâm về gốc tọa độ, đế ở y = 0, phóng to cho bề ngang WIDTH mét. Tường vòng phía -z (sau lưng), mở về
   phía +z. Phần từ đế lên tới mặt vòng phù văn (bậc đá, lòng chảo) nén còn LOW_SCALE để vòng chỉ nhô vài cm,
   chân người đứng trên không bị lún; tường vòng, cột phía trên giữ nguyên chiều cao.
4. Giữ nguyên màu: ảnh màu thu về 1024 px. Vòng phù văn sáng sẵn trong ảnh màu (ảnh phát sáng gốc gần như
   đen) nên bỏ ảnh phát sáng, normal map, ảnh kim loại.
"""

import io
import json
import struct
import sys

import meshoptimizer
import numpy as np
import xatlas
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

TRIS = 4000
WIDTH = 4.9 # m
FLOOR_Y = -0.11 # mặt vòng phù văn trong mô hình gốc
LOW_SCALE = 0.3
BAKE = 2048 # px lúc nướng ảnh
SAMPLES = 1500000 # số điểm lấy mẫu trên lưới gốc
NORMAL_WEIGHT = 0.03 # độ ưu tiên điểm cùng hướng mặt khi tìm điểm gần nhất


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
		return Image.open(io.BytesIO(b[o:o + bv["byteLength"]])).convert("RGB")

	p = j["meshes"][0]["primitives"][0]
	mat = j["materials"][p.get("material", 0)]
	a = p["attributes"]
	return (acc(a["POSITION"]).astype(np.float32), acc(a["NORMAL"]).astype(np.float32),
		acc(a["TEXCOORD_0"]).astype(np.float32), acc(p["indices"]).astype(np.uint32),
		image(mat["pbrMetallicRoughness"]["baseColorTexture"]))


def _face_normals(pos, tris):
	n = np.cross(pos[tris[:, 1]] - pos[tris[:, 0]], pos[tris[:, 2]] - pos[tris[:, 0]])
	area = np.linalg.norm(n, axis=1)
	return n / np.maximum(area, 1e-12)[:, None], area / 2


## Rải điểm đều theo diện tích trên lưới gốc, mỗi điểm nhớ UV gốc và hướng mặt.
def _surface_samples(pos, uv, tris, rng):
	normal, area = _face_normals(pos, tris)
	face = rng.choice(len(tris), SAMPLES, p=area / area.sum())
	r1, r2 = rng.random(SAMPLES), rng.random(SAMPLES)
	flip = r1 + r2 > 1
	r1[flip], r2[flip] = 1 - r1[flip], 1 - r2[flip]
	w = np.stack([1 - r1 - r2, r1, r2], axis=1)
	t = tris[face]
	p = (pos[t] * w[:, :, None]).sum(axis=1)
	u = (uv[t] * w[:, :, None]).sum(axis=1)
	return np.hstack([p, normal[face] * NORMAL_WEIGHT]), u


## Tô ảnh mới: quét từng tam giác trong không gian UV mới, mỗi điểm ảnh tìm điểm gốc gần nhất.
def _bake(pos, tris, new_uv, tree, sample_uv, image):
	normal, _ = _face_normals(pos, tris)
	px_all, pt_all = [], []
	for f, t in enumerate(tris):
		q = new_uv[t] * BAKE
		lo = np.floor(q.min(axis=0)).astype(int)
		hi = np.ceil(q.max(axis=0)).astype(int)
		xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
		c = np.stack([xs.ravel(), ys.ravel()], axis=1) + 0.5
		m = np.array([q[1] - q[0], q[2] - q[0]]).T
		if abs(np.linalg.det(m)) < 1e-9:
			continue
		b = np.linalg.solve(m, (c - q[0]).T).T
		w = np.stack([1 - b[:, 0] - b[:, 1], b[:, 0], b[:, 1]], axis=1)
		inside = (w > -0.02).all(axis=1) # tràn nhẹ ra ngoài cho khỏi hở mép
		ok = inside & (c[:, 0] < BAKE) & (c[:, 1] < BAKE) & (c[:, 0] >= 0) & (c[:, 1] >= 0)
		if not ok.any():
			continue
		px_all.append(c[ok].astype(int))
		p3 = w[ok] @ pos[t]
		pt_all.append(np.hstack([p3, np.repeat(normal[f][None] * NORMAL_WEIGHT, ok.sum(), axis=0)]))
	px = np.concatenate(px_all)
	_, nearest = tree.query(np.concatenate(pt_all), workers=-1)
	src_uv = sample_uv[nearest]
	a = np.asarray(image)
	h, w_ = a.shape[:2]
	sx = np.clip((src_uv[:, 0] * w_).astype(int), 0, w_ - 1)
	sy = np.clip((src_uv[:, 1] * h).astype(int), 0, h - 1)
	baked = np.zeros((BAKE, BAKE, 3), np.uint8)
	baked[px[:, 1], px[:, 0]] = a[sy, sx]
	filled = np.zeros((BAKE, BAKE), bool)
	filled[px[:, 1], px[:, 0]] = True
	_, (iy, ix) = ndimage.distance_transform_edt(~filled, return_indices=True) # loang màu ra khe trống
	return Image.fromarray(baked[iy, ix])


def write_glb(path, pos, nor, uv, idx, albedo):
	blob = bytearray()
	views = []
	accs = []

	def add(data, target=None):
		while len(blob) % 4:
			blob.append(0)
		v = {"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)}
		if target:
			v["target"] = target
		blob.extend(data)
		views.append(v)
		return len(views) - 1

	def add_acc(arr, typ, comp, minmax=False, target=34962):
		a = {"bufferView": add(arr.tobytes(), target), "componentType": comp, "count": len(arr), "type": typ}
		if minmax:
			a["min"] = arr.min(axis=0).tolist()
			a["max"] = arr.max(axis=0).tolist()
		accs.append(a)
		return len(accs) - 1

	def add_img(im):
		b = io.BytesIO()
		im.save(b, "JPEG", quality=90)
		return {"bufferView": add(b.getvalue()), "mimeType": "image/jpeg"}

	attrs = {
		"POSITION": add_acc(pos, "VEC3", 5126, True),
		"NORMAL": add_acc(nor, "VEC3", 5126),
		"TEXCOORD_0": add_acc(uv, "VEC2", 5126),
	}
	ind = add_acc(idx, "SCALAR", 5125, target=34963)
	gltf = {
		"asset": {"version": "2.0", "generator": "build_phap_tran.py"},
		"scene": 0,
		"scenes": [{"nodes": [0]}],
		"nodes": [{"name": "PhapTran", "mesh": 0}],
		"meshes": [{"name": "PhapTran", "primitives": [{"attributes": attrs, "indices": ind, "material": 0}]}],
		"materials": [{
			"name": "phap_tran",
			"doubleSided": True,
			"pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 1.0},
		}],
		"textures": [{"source": 0, "sampler": 0}],
		"samplers": [{"magFilter": 9729, "minFilter": 9987}],
		"images": [add_img(albedo)],
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
	pos, nor, uv, idx, albedo = read_glb(src)
	keys, weld = np.unique(np.round(pos / 1e-5).astype(np.int64), axis=0, return_inverse=True)
	tris = weld.ravel()[idx].reshape(-1, 3)
	wpos = (keys * 1e-5).astype(np.float32)
	out = np.zeros(tris.size, dtype=np.uint32)
	n = meshoptimizer.simplify(out, tris.ravel().astype(np.uint32), wpos, target_index_count=TRIS * 3, target_error=0.05)
	small = out[:n].reshape(-1, 3)
	atlas = xatlas.Atlas()
	atlas.add_mesh(wpos, small)
	pack = xatlas.PackOptions()
	pack.resolution = BAKE
	pack.padding = 4
	atlas.generate(pack_options=pack)
	vmap, new_tris, new_uv = atlas[0]
	new_pos = wpos[vmap]
	samples, sample_uv = _surface_samples(pos, uv, idx.reshape(-1, 3), np.random.default_rng(1))
	albedo = _bake(new_pos, new_tris, new_uv, cKDTree(samples), sample_uv, albedo)
	normal, area = _face_normals(new_pos, new_tris)
	new_nor = np.zeros_like(new_pos)
	for k in range(3):
		np.add.at(new_nor, new_tris[:, k], normal * area[:, None])
	new_nor /= np.maximum(np.linalg.norm(new_nor, axis=1), 1e-12)[:, None]
	center = (new_pos.min(axis=0) + new_pos.max(axis=0)) / 2
	scale = WIDTH / float(new_pos[:, 0].max() - new_pos[:, 0].min())
	base = float(new_pos[:, 1].min())
	new_pos = (new_pos - np.array([center[0], base, center[2]], np.float32)) * scale
	low = (FLOOR_Y - base) * scale
	y = new_pos[:, 1]
	new_pos[:, 1] = np.minimum(y, low) * LOW_SCALE + np.maximum(y - low, 0.0)
	write_glb(dst, new_pos.astype(np.float32), new_nor.astype(np.float32), new_uv.astype(np.float32),
		new_tris.astype(np.uint32).ravel(), albedo.resize((1024, 1024), Image.LANCZOS))
	print("tam giác", len(new_tris), "đỉnh", len(new_pos), "cỡ", np.round(new_pos.max(axis=0) - new_pos.min(axis=0), 2),
		"vòng phù văn cao", round(low * LOW_SCALE, 3), "m")


if __name__ == "__main__":
	main(*sys.argv[1:3])

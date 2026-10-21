# Dựng mô hình trận linh cho game từ tệp GLB gốc (tạo bằng AI, một lưới 30k tam giác, ảnh 2048).
#   python3 -I build_tran_linh.py tran.glb ../../models/tran_linh/tran_linh.glb   (README.md)
# Cần: pip install numpy pillow scipy meshoptimizer xatlas
# - Tách lưới thành: bệ cỏ + vòng phù văn (nen), 4 đá dựng (da_0..da_3), linh thạch (linh_thach).
# - Cân đối: linh thạch dời về đúng giữa vòng phù văn, lơ lửng; 4 đá đặt đúng 4 góc chéo, cùng
#   bán kính, chân ngang mặt cỏ. Chỗ đá cũ trên bệ vá bằng mặt cỏ.
# - Giảm lưới cho điện thoại (cả trận linh ~3k tam giác). UV gốc vụn từng mảnh nhỏ nên không
#   giữ được khi giảm: trải UV mới (xatlas) rồi nướng lại ảnh màu + ảnh phát sáng 512 px từ
#   lưới gốc. Bỏ normal map và ảnh kim loại.
# - Mỗi đá và linh thạch cắt sẵn thành mảnh vỡ (da_k_manh_i, linh_thach_manh_i) để game làm
#   hiệu ứng vỡ: gốc mảnh ở tâm mảnh, đặt đúng chỗ trong khối.
# Gốc mô hình: tâm vòng phù văn, y = 0 ở đáy bệ. Đơn vị giữ như tệp gốc (game tự phóng to).
import ctypes
import io
import json
import struct
import sys

import meshoptimizer as mo
import numpy as np
import xatlas
from PIL import Image
from scipy.spatial import cKDTree

GRASS_Y = -0.665 # mặt cỏ trong tệp gốc
STONE_CUT_Y = -0.645 # cao hơn mặt cỏ một chút: phần trên là đá dựng
STONE_MIN_R = 0.5 # đá đứng ngoài vòng phù văn
STONE_FOOT = 0.3 # bán kính chân đá cũ (vá lỗ, bỏ khỏi lưới mẫu khi nướng ảnh bệ)
GRASS_DISC_R = 0.86 # đĩa lấp lỗ mặt cỏ, trong mép bệ
STONE_R = 0.7 # bán kính đặt 4 đá sau khi cân đối
STONE_SINK = 0.025 # chân đá lún xuống cỏ cho khỏi hở
CRYSTAL_GAP = 0.32 # linh thạch lơ lửng cách mặt vòng phù văn chừng này
CRYSTAL_SCALE = 0.85
TARGET_TRIS = {"nen": 1700, "da": 200, "linh_thach": 420}
HARD_ANGLE = {"nen": 55.0, "da": 55.0, "linh_thach": 25.0} # góc giữa 2 mặt lớn hơn thì cạnh sắc
STONE_PIECES = 5
CRYSTAL_PIECES = 9
TEXTURE_SIZE = 512


def read_glb(path):
	d = open(path, "rb").read()
	n = struct.unpack("<I", d[12:16])[0]
	j = json.loads(d[20:20 + n])
	b = d[20 + n + 8:]

	def acc(i):
		a = j["accessors"][i]
		bv = j["bufferViews"][a["bufferView"]]
		k = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
		dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[a["componentType"]]
		o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
		x = np.frombuffer(b, dt, a["count"] * k, o)
		return x.reshape(-1, k) if k > 1 else x

	def image(i):
		bv = j["bufferViews"][j["images"][i]["bufferView"]]
		o = bv.get("byteOffset", 0)
		return np.asarray(Image.open(io.BytesIO(b[o:o + bv["byteLength"]])).convert("RGB"), np.float32)

	p = j["meshes"][0]["primitives"][0]
	mat = j["materials"][p["material"]]
	tex = lambda t: j["textures"][t["index"]]["source"]
	return (
		acc(p["attributes"]["POSITION"]).astype(np.float64),
		acc(p["attributes"]["TEXCOORD_0"]).astype(np.float64),
		acc(p["indices"]).reshape(-1, 3).astype(np.int64),
		image(tex(mat["pbrMetallicRoughness"]["baseColorTexture"])),
		image(tex(mat["emissiveTexture"])),
	)


def weld_ids(pos):
	key = np.round(pos * 1e4).astype(np.int64)
	_, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
	return inv.ravel(), first


def components(tris):
	"""Nhãn nhóm tam giác nối nhau cho từng tam giác."""
	par = np.arange(tris.max() + 1)

	def find(x):
		while par[x] != x:
			par[x] = par[par[x]]
			x = par[x]
		return x

	for t in tris:
		a = find(t[0])
		for v in t[1:]:
			bb = find(v)
			if bb != a:
				par[bb] = a
	return np.array([find(t[0]) for t in tris])


def rot_y(angle):
	"""Ma trận xoay quanh trục đứng, góc đo theo atan2(z, x) giảm đi angle."""
	c, s = np.cos(angle), np.sin(angle)
	return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


class Part:
	"""Một khối lưới. pos: vị trí trong mô hình mới; src: vị trí cùng điểm trong tệp gốc (để nướng ảnh)."""

	def __init__(self, pos, tris, src=None):
		used, inv = np.unique(tris.ravel(), return_inverse=True)
		self.pos = pos[used].copy()
		self.src = (pos if src is None else src)[used].copy()
		self.tris = inv.reshape(-1, 3)
		self.nor = None
		self.uv = None

	def simplify(self, target):
		if len(self.tris) <= target:
			return
		src = self.tris.astype(np.uint32).ravel()
		dst = np.zeros_like(src)
		n = mo.simplify(dst, src, self.pos.astype(np.float32), target_index_count=target * 3,
			target_error=ctypes.c_float(0.5)) # bản python cần c_float
		keep = Part(self.pos, dst[:n].reshape(-1, 3).astype(np.int64), self.src)
		self.pos, self.src, self.tris = keep.pos, keep.src, keep.tris

	def split_normals(self, hard_angle):
		"""Pháp tuyến mượt trong mỗi mặt, cạnh gãy hơn hard_angle thì tách đỉnh (cạnh sắc)."""
		v = self.pos[self.tris]
		fn = np.cross(v[:, 1] - v[:, 0], v[:, 2] - v[:, 0])
		fn /= np.linalg.norm(fn, axis=1, keepdims=True) + 1e-12
		around = [[] for _ in range(len(self.pos))]
		for f, t in enumerate(self.tris):
			for c in t:
				around[c].append(f)
		cos_hard = np.cos(np.radians(hard_angle))
		pos, src, nor, tris, seen = [], [], [], [], {}
		for f, t in enumerate(self.tris):
			tri = []
			for c in t:
				faces = [g for g in around[c] if fn[g] @ fn[f] > cos_hard]
				n = fn[faces].sum(0)
				n /= np.linalg.norm(n) + 1e-12
				key = (c, tuple(np.round(n, 3)))
				if key not in seen:
					seen[key] = len(pos)
					pos.append(self.pos[c])
					src.append(self.src[c])
					nor.append(n)
				tri.append(seen[key])
			tris.append(tri)
		self.pos, self.src, self.nor, self.tris = np.array(pos), np.array(src), np.array(nor), np.array(tris)

	def take(self, vmap, tris, uv):
		self.pos, self.src, self.nor = self.pos[vmap], self.src[vmap], self.nor[vmap]
		self.tris, self.uv = tris.reshape(-1, 3).astype(np.int64), uv

	def center(self):
		return (self.pos.min(0) + self.pos.max(0)) / 2

	def pieces(self, count, seed):
		"""Cắt thành count mảnh theo vị trí tam giác (k-means), gốc mỗi mảnh ở tâm mảnh."""
		cen = self.pos[self.tris].mean(1)
		rng = np.random.default_rng(seed)
		k = cen[rng.choice(len(cen), count, replace=False)]
		for _ in range(20):
			lab = np.argmin(((cen[:, None] - k[None]) ** 2).sum(-1), 1)
			k = np.array([cen[lab == i].mean(0) if (lab == i).any() else k[i] for i in range(count)])
		out = []
		for i in range(count):
			if (lab == i).sum() < 4:
				continue
			used, inv = np.unique(self.tris[lab == i].ravel(), return_inverse=True)
			p = Part.__new__(Part)
			p.pos, p.nor, p.uv = self.pos[used].copy(), self.nor[used], self.uv[used]
			p.tris = inv.reshape(-1, 3)
			c = p.center()
			p.pos -= c
			out.append((p, c))
		return out


def fill_holes(part, near_xz, radius):
	"""Vá lỗ trên bệ ở chỗ đá cũ: quạt tam giác từ tâm mỗi vòng biên."""
	edges = set()
	for t in part.tris:
		for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
			edges.add((a, b))
	nxt = {a: b for a, b in edges if (b, a) not in edges and np.hypot(*(part.pos[a, [0, 2]] - near_xz)) < radius}
	seen = set()
	new_pos, new_tris = [], []
	for start in list(nxt):
		loop, w = [], start
		while w in nxt and w not in seen:
			seen.add(w)
			loop.append(w)
			w = nxt[w]
		if len(loop) < 3:
			continue
		c = len(part.pos) + len(new_pos)
		new_pos.append(part.pos[loop].mean(0))
		for i in range(len(loop)):
			new_tris.append((loop[i], c, loop[(i + 1) % len(loop)]))
	if new_pos:
		part.pos = np.vstack([part.pos, new_pos])
		part.src = np.vstack([part.src, new_pos])
		part.tris = np.vstack([part.tris, new_tris])


def add_grass_disc(part, center):
	"""Đĩa cỏ phẳng ngay dưới mặt cỏ: lấp các lỗ nhỏ của lưới gốc (nhìn từ trên thấy đáy bệ)."""
	n = len(part.pos)
	ring = [center + [np.cos(a) * GRASS_DISC_R, GRASS_Y - 0.012, np.sin(a) * GRASS_DISC_R]
		for a in np.linspace(0, 2 * np.pi, 32, endpoint=False)]
	pts = np.array([center + [0, GRASS_Y - 0.012, 0]] + ring)
	tris = [(n, n + 1 + (i + 1) % 32, n + 1 + i) for i in range(32)]
	part.pos = np.vstack([part.pos, pts])
	part.src = np.vstack([part.src, pts])
	part.tris = np.vstack([part.tris, tris])


class Baker:
	"""Nướng ảnh: mỗi điểm ảnh của UV mới lấy màu điểm gần nhất trên lưới gốc."""

	def __init__(self, pos, uv, albedo, emission):
		self.pos, self.uv, self.images = pos, uv, (albedo, emission)
		self.out = [np.zeros((TEXTURE_SIZE, TEXTURE_SIZE, 3), np.float32) for _ in range(2)]
		self.filled = np.zeros((TEXTURE_SIZE, TEXTURE_SIZE), bool)

	def bake(self, part, ref_tris):
		v = self.pos[ref_tris]
		tree = cKDTree(v.mean(1))
		pts, pix = [], []
		for t in part.tris:
			uv = part.uv[t] * TEXTURE_SIZE
			lo = np.floor(uv.min(0) - 1).astype(int).clip(0, TEXTURE_SIZE - 1)
			hi = np.ceil(uv.max(0) + 1).astype(int).clip(0, TEXTURE_SIZE - 1)
			xs, ys = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
			p = np.stack([xs.ravel(), ys.ravel()], 1) + 0.5
			w = barycentric(p, uv)
			inside = (w > -0.02).all(1) # nới mép một chút cho khỏi hở đường nối
			if not inside.any():
				continue
			pts.append(w[inside] @ part.src[t])
			pix.append(p[inside].astype(int))
		pts, pix = np.vstack(pts), np.vstack(pix)
		_, near = tree.query(pts, k=8)
		best_d = np.full(len(pts), np.inf)
		best_uv = np.zeros((len(pts), 2))
		for k in range(near.shape[1]):
			tri = v[near[:, k]]
			q, w = closest_on_triangle(pts, tri)
			d = ((q - pts) ** 2).sum(1)
			better = d < best_d
			best_d[better] = d[better]
			uv = np.einsum("ni,nij->nj", w, self.uv[ref_tris[near[:, k]]])
			best_uv[better] = uv[better]
		for img, out in zip(self.images, self.out):
			out[pix[:, 1], pix[:, 0]] = sample(img, best_uv)
		self.filled[pix[:, 1], pix[:, 0]] = True

	def images_out(self):
		# Loang màu ra quanh mảnh UV để mipmap không lẫn nền đen ở đường nối.
		filled = self.filled.copy()
		outs = [o.copy() for o in self.out]
		for _ in range(8):
			acc = [np.zeros_like(o) for o in outs]
			cnt = np.zeros(filled.shape, np.float32)
			for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
				f = np.roll(filled, (dy, dx), (0, 1))
				cnt += f
				for a, o in zip(acc, outs):
					a += np.roll(o, (dy, dx), (0, 1)) * f[..., None]
			grow = ~filled & (cnt > 0)
			for a, o in zip(acc, outs):
				o[grow] = a[grow] / cnt[grow][:, None]
			filled |= grow
		return [Image.fromarray(o.clip(0, 255).astype(np.uint8)) for o in outs]


def barycentric(p, tri):
	a, b, c = tri
	v0, v1, v2 = b - a, c - a, p - a
	den = v0[0] * v1[1] - v1[0] * v0[1]
	if abs(den) < 1e-12:
		return np.full((len(p), 3), -1.0)
	l1 = (v2[:, 0] * v1[1] - v1[0] * v2[:, 1]) / den
	l2 = (v0[0] * v2[:, 1] - v2[:, 0] * v0[1]) / den
	return np.stack([1 - l1 - l2, l1, l2], 1)


def closest_on_triangle(p, tri):
	"""Điểm gần nhất trên từng tam giác (n, 3, 3) với từng điểm p (n, 3), kèm tọa độ trọng tâm."""
	a, b, c = tri[:, 0], tri[:, 1], tri[:, 2]
	ab, ac = b - a, c - a
	n = np.cross(ab, ac)
	nn = (n * n).sum(1) + 1e-18
	q = p - ((p - a) * n).sum(1)[:, None] * n / nn[:, None] # chiếu xuống mặt phẳng
	d00, d01, d11 = (ab * ab).sum(1), (ab * ac).sum(1), (ac * ac).sum(1)
	ap = q - a
	d20, d21 = (ap * ab).sum(1), (ap * ac).sum(1)
	den = d00 * d11 - d01 * d01 + 1e-18
	v = (d11 * d20 - d01 * d21) / den
	w = (d00 * d21 - d01 * d20) / den
	bar = np.stack([1 - v - w, v, w], 1).clip(0, None)
	bar /= bar.sum(1, keepdims=True) + 1e-12 # ra ngoài tam giác thì kéo về mép (gần đúng)
	return np.einsum("ni,nij->nj", bar, tri), bar


def sample(img, uv):
	h, w = img.shape[:2]
	x = (uv[:, 0] % 1.0) * w - 0.5
	y = (uv[:, 1] % 1.0) * h - 0.5
	x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
	fx, fy = (x - x0)[:, None], (y - y0)[:, None]
	px = lambda xx, yy: img[yy.clip(0, h - 1), xx.clip(0, w - 1)]
	return (px(x0, y0) * (1 - fx) * (1 - fy) + px(x0 + 1, y0) * fx * (1 - fy)
		+ px(x0, y0 + 1) * (1 - fx) * fy + px(x0 + 1, y0 + 1) * fx * fy)


def write_glb(path, nodes, albedo, emission):
	"""nodes: [(tên, Part, vị trí)]; một material dùng chung, ảnh màu + ảnh phát sáng."""
	blob = bytearray()
	views, accs, meshes, gnodes = [], [], [], []

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

	for name, p, at in nodes:
		attrs = {
			"POSITION": add_acc(p.pos.astype(np.float32), "VEC3", 5126, True),
			"NORMAL": add_acc(p.nor.astype(np.float32), "VEC3", 5126),
			"TEXCOORD_0": add_acc(p.uv.astype(np.float32), "VEC2", 5126),
		}
		idx = add_acc(p.tris.astype(np.uint16).ravel(), "SCALAR", 5123, target=34963)
		meshes.append({"name": name, "primitives": [{"attributes": attrs, "indices": idx, "material": 0}]})
		gnodes.append({"name": name, "mesh": len(meshes) - 1, "translation": [float(x) for x in at]})
	images = []
	for img in (albedo, emission):
		b = io.BytesIO()
		img.save(b, "JPEG", quality=90)
		images.append({"bufferView": add(b.getvalue()), "mimeType": "image/jpeg"})
	gltf = {
		"asset": {"version": "2.0", "generator": "build_tran_linh.py"},
		"scene": 0,
		"scenes": [{"nodes": list(range(len(gnodes)))}],
		"nodes": gnodes,
		"meshes": meshes,
		"materials": [{
			"name": "tran_linh",
			"doubleSided": True, # lưới gốc lật mặt lung tung
			"pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0.0, "roughnessFactor": 0.85},
			"emissiveTexture": {"index": 1},
			"emissiveFactor": [1.0, 1.0, 1.0],
		}],
		"textures": [{"source": 0, "sampler": 0}, {"source": 1, "sampler": 0}],
		"samplers": [{"magFilter": 9729, "minFilter": 9987}],
		"images": images,
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


def main(src_path, dst_path):
	pos, uv, tris, albedo, emission = read_glb(src_path)
	wid, first = weld_ids(pos)
	wpos = pos[first] # lưới gộp đỉnh trùng vị trí (bỏ UV gốc)
	wtris = wid[tris]
	lab = components(wtris)
	labels, counts = np.unique(lab, return_counts=True)
	big = lab == labels[np.argmax(counts)]

	cen = pos[tris].mean(1)
	r = np.hypot(cen[:, 0], cen[:, 2])
	# Tâm vòng phù văn: giữa khung bao phần bệ nhô lên quanh tâm.
	rp = pos[tris[big & (r < 0.48) & (cen[:, 1] > -0.6)].ravel()]
	rune = (rp.min(0) + rp.max(0)) / 2
	rune[1] = 0.0
	rune_top = rp[:, 1].max()
	off = cen - rune
	stone_mask = big & (cen[:, 1] > STONE_CUT_Y) & (np.hypot(off[:, 0], off[:, 2]) > STONE_MIN_R)
	quad = np.floor((np.arctan2(off[:, 2], off[:, 0]) + np.pi) / (np.pi / 2)).astype(int) % 4

	base = Part(wpos, wtris[big & ~stone_mask])
	base_ref = big & ~stone_mask # lưới mẫu nướng ảnh bệ: bỏ chân đá cũ để chỗ vá lấy màu cỏ
	stones = []
	for q in range(4):
		s = Part(wpos, wtris[stone_mask & (quad == q)])
		foot = s.pos[s.pos[:, 1] < STONE_CUT_Y + 0.03]
		foot_c = foot.mean(0) if len(foot) else (s.pos.min(0) + s.pos.max(0)) / 2
		fill_holes(base, foot_c[[0, 2]], STONE_FOOT)
		base_ref &= ~((np.hypot(cen[:, 0] - foot_c[0], cen[:, 2] - foot_c[2]) < STONE_FOOT) & (cen[:, 1] > GRASS_Y + 0.01))
		# Xoay quanh tâm vòng phù văn về đúng góc chéo, gốc đá ở chân đá ngang mặt cỏ.
		a0 = np.arctan2(foot_c[2] - rune[2], foot_c[0] - rune[0])
		a1 = -np.pi * 3 / 4 + q * np.pi / 2
		basis = rot_y(a0 - a1)
		foot_new = (foot_c - rune) @ basis.T
		s.pos = (s.pos - rune) @ basis.T - [foot_new[0], GRASS_Y, foot_new[2]]
		stones.append((s, np.array([np.cos(a1), 0, np.sin(a1)]) * STONE_R, stone_mask & (quad == q)))
	add_grass_disc(base, rune)
	base.pos -= rune
	bottom = base.pos[:, 1].min()
	base.pos[:, 1] -= bottom
	grass_y = GRASS_Y - bottom

	crystal = Part(wpos, wtris[~big])
	cc = (crystal.pos.min(0) + crystal.pos.max(0)) / 2
	crystal.pos = (crystal.pos - cc) * CRYSTAL_SCALE
	half = (crystal.pos[:, 1].max() - crystal.pos[:, 1].min()) / 2

	parts = [("nen", base, np.zeros(3), base_ref, "nen")]
	for q, (s, want, m) in enumerate(stones):
		parts.append(("da_%d" % q, s, np.array([want[0], grass_y - STONE_SINK, want[2]]), m, "da"))
	parts.append(("linh_thach", crystal, np.array([0.0, rune_top - bottom + CRYSTAL_GAP + half, 0.0]), ~big, "linh_thach"))

	atlas = xatlas.Atlas()
	for name, p, at, m, kind in parts:
		p.simplify(TARGET_TRIS[kind])
		p.split_normals(HARD_ANGLE[kind])
		atlas.add_mesh(p.pos.astype(np.float32), p.tris.astype(np.uint32), p.nor.astype(np.float32))
	pack = xatlas.PackOptions()
	pack.resolution = TEXTURE_SIZE
	pack.padding = 2
	pack.bilinear = True
	atlas.generate(pack_options=pack)
	baker = Baker(pos, uv, albedo, emission)
	for i, (name, p, at, m, kind) in enumerate(parts):
		vmap, idx, auv = atlas[i]
		p.take(vmap, idx, auv.astype(np.float64))
		baker.bake(p, tris[m])

	nodes = []
	for q, (name, p, at, m, kind) in enumerate(parts):
		nodes.append((name, p, at))
		if kind == "nen":
			continue
		for i, (piece, c) in enumerate(p.pieces(CRYSTAL_PIECES if kind == "linh_thach" else STONE_PIECES, q)):
			nodes.append(("%s_manh_%d" % (name, i), piece, at + c))
	write_glb(dst_path, nodes, *baker.images_out())
	for name, p, at in nodes:
		if "manh" not in name:
			print(name, len(p.tris), "tam giác, đặt ở", np.round(at, 3))
	print("tổng:", sum(len(p.tris) for n, p, a in nodes if "manh" not in n), "tam giác | mặt cỏ y =",
		round(grass_y, 3), "| đỉnh vòng phù văn y =", round(rune_top - bottom, 3))


if __name__ == "__main__":
	main(sys.argv[1], sys.argv[2])

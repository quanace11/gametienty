"""Dựng nền sân vẽ tay sắc nét cho shaders/ban_do_meshy.gdshader từ ảnh nền liền nen_min.jpg (lam_min.py).

Vì sao: nen_min.jpg chỉ 41 px/m (Thấp 20 px/m) mà camera trong trận cần ~100 px/m, ảnh bị phóng 2,5 - 5 lần
nên mép cỏ, mép lối đất nhòe như phim mờ. Thay vì phóng to ảnh (tốn bộ nhớ), tách nền thành:
- nen_lop.png (2048 x 1844, RGBA): R = khoảng cách có dấu tới mép cỏ, G = khoảng cách có dấu tới vùng đá /
  phù văn (0,5 là mép, mỗi đơn vị 1 m, kẹp +-0,5 m), B = bóng đổ vẽ sẵn dưới cây, đá, bụi, tường, A = nhiễu
  thưa để trộn 2 lớp vân cho không lộ ô lặp. Shader làm nét mép theo khoảng cách nên mép sắc ở mọi độ phóng
  (kiểu chữ SDF).
- nen_co.png, nen_dat.png (512 px): sắc màu cỏ, đất theo từng chỗ, loang tràn qua mép cho shader chọn bên.
- nen_da.png (1024 px, RGBA): màu vùng đá lát, phù văn, phiến đá, loang tràn qua mép; lối gạch và phiến đá xám
  chỉ giữ màu loang, phù văn giữ nguyên hình vẽ Meshy. A = lối gạch (STONE_PATHS).
- van_da.png (512 px, lát theo mét): R trống, G = phiến đá nứt (san_da.png), B = gạch cuội (da.png).
- van_nen.png (512 px, lát theo mét): R = vân cỏ (co_1.png + co_2.png), G = vân đất (dat.png + chút vết nứt san_da.png),
  B = vân lá cỏ ở mép (co_2.png), độ sáng chuẩn hóa quanh 0,5; chỉ đổi độ sáng nên giữ đúng tông màu.
Ảnh vân: nen_ve_tay/ (CC0, xem LICENSE.txt ở đó).

Chạy (sau lam_min.py, cần opencv-python-headless):
python3 -I nen_sac.py ../../models/ban_do_meshy/nen_min.jpg ../../maps/test_map.gd ../../models/nen_ve_tay ../../models/ban_do_meshy
"""

import os
import re
import sys

import cv2
import numpy as np

SIZE = (50.0, 45.0) # mét (x, z) mà nen_min.jpg phủ
SUN = np.array([-0.29, -0.5]) # hướng bóng đổ trên mặt sàn (đèn mặt trời test_map.gd xoay -55°, 30°)


def classes(img):
	"""Nhãn 0 cỏ, 1 đất, 2 đá / phù văn theo sắc độ, làm tròn mép cho mềm như nét cọ."""
	hsv = cv2.cvtColor(cv2.GaussianBlur(img, (0, 0), 1.5), cv2.COLOR_BGR2HSV) # ảnh float: H 0..360, S 0..1
	h, s = hsv[..., 0] / 2.0, hsv[..., 1]
	grass = ((h >= 31) & (h <= 80) & (s > 0.28)).astype(np.float32)
	dirt = ((h >= 5) & (h < 31) & (s > 0.22)).astype(np.float32) * (1.0 - grass)
	other = 1.0 - grass - dirt
	stack = np.stack([cv2.GaussianBlur(m, (0, 0), 4.0) for m in (grass, dirt, other)], -1)
	label = np.argmax(stack, -1).astype(np.uint8)
	return cv2.medianBlur(label, 7)


def signed_field(mask, px_per_m):
	"""Khoảng cách có dấu tới mép mask (dương bên trong), mét, kẹp +-0,5 -> 0..1."""
	m = mask.astype(np.uint8)
	inside = cv2.distanceTransform(m, cv2.DIST_L2, 5)
	outside = cv2.distanceTransform(1 - m, cv2.DIST_L2, 5)
	d = (inside - outside) / px_per_m
	return np.clip(d + 0.5, 0.0, 1.0)


def spread(img, mask, sigma):
	"""Màu trong mask (làm mịn bán kính sigma) loang tràn ra ngoài: chỗ xa mask lấy trung bình rộng dần."""
	out = np.zeros_like(img)
	done = np.zeros(mask.shape, bool)
	for s in (sigma, sigma * 4, sigma * 16, sigma * 64):
		wgt = cv2.GaussianBlur(mask, (0, 0), s)
		col = cv2.GaussianBlur(img * mask[..., None], (0, 0), s) / np.maximum(wgt, 1e-6)[..., None]
		take = ~done & (wgt > 0.02)
		out[take] = col[take]
		done |= take
	out[~done] = img[mask > 0].mean(0)
	return out


def consts(source, name):
	"""Đọc mảng hằng Vector3 / Vector2 / Rect2 trong test_map.gd (bỏ comment như GDScript)."""
	body = re.search(r"const %s[^=]*=\s*\[(.*?)\][ \t]*\n" % name, source, re.S).group(1)
	body = re.sub(r"#[^\n]*", "", body)
	return [tuple(float(v) for v in m.split(",")) for m in re.findall(r"(?:Vector3|Vector2|Rect2)\(([^)]*)\)", body)]


def shadows(shape, px_per_m, source):
	"""Bóng vẽ sẵn: đốm tối mềm dưới cây, đá, bụi, cột đổ, tường; lệch theo hướng nắng."""
	h, w = shape
	acc = np.zeros(shape, np.float32)

	def blob(x, z, r, strength, lean):
		cx = (x + SUN[0] * lean) * px_per_m
		cy = (z + SUN[1] * lean) * px_per_m
		cv2.circle(acc, (int(cx), int(cy)), max(1, int(r * px_per_m)), strength, -1, cv2.LINE_AA)

	for x, z, size in consts(source, "TREES"):
		blob(x, z, 1.6 * size, 0.55, 1.2 * size)
	for x, z, r in consts(source, "ROCKS"):
		blob(x, z, r * 1.15, 0.6, r * 0.5)
	for x, z, r in consts(source, "BUSHES") + consts(source, "DECOR_BUSHES"):
		blob(x, z, r * 0.95, 0.45, r * 0.3)
	a, b = consts(source, "FALLEN_PILLAR")
	cv2.line(acc, (int(a[0] * px_per_m), int(a[1] * px_per_m)), (int(b[0] * px_per_m), int(b[1] * px_per_m)),
		0.6, int(1.2 * px_per_m), cv2.LINE_AA)
	for x, z, rw, rd in consts(source, "WALLS")[5:]: # tường trong sân; viền ngoài là vách đá Meshy đã vẽ bóng
		p0 = (int((x - 0.3) * px_per_m), int((z - 0.3) * px_per_m))
		p1 = (int((x + rw + 0.3) * px_per_m), int((z + rd + 0.3) * px_per_m))
		cv2.rectangle(acc, p0, p1, 0.5, -1)
	acc = cv2.GaussianBlur(np.clip(acc, 0, 1), (0, 0), 0.45 * px_per_m)
	return 1.0 - 0.42 * acc


def cobble_mask(shape, px_per_m, source):
	"""Vùng lối gạch (STONE_PATHS trong test_map.gd): 1 trong lối, rộng PATH_WIDTH + 0,4 m."""
	block = re.search(r"const STONE_PATHS[^=]*=\s*\[(.*?)\n\]", source, re.S).group(1)
	width = float(re.search(r"const PATH_WIDTH := ([0-9.]+)", source).group(1))
	acc = np.zeros(shape, np.float32)
	for path in re.findall(r"\[(.*?)\]", re.sub(r"#[^\n]*", "", block), re.S):
		pts = np.array([[float(v) for v in m.split(",")] for m in re.findall(r"Vector2\(([^)]*)\)", path)])
		cv2.polylines(acc, [(pts * px_per_m).astype(np.int32)], False, 1.0, int((width + 0.4) * px_per_m), cv2.LINE_AA)
	return acc


def stone_detail(textures):
	"""van_da.png: G = phiến đá nứt (san_da.png), B = gạch cuội (da.png), độ sáng chuẩn hóa quanh 0,5."""
	def lum(name, contrast):
		g = cv2.cvtColor(cv2.imread(os.path.join(textures, name)), cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
		g = cv2.resize(g, (512, 512), interpolation=cv2.INTER_AREA)
		g = g - g.mean()
		return np.clip(0.5 + g / (4.0 * g.std() + 1e-4) * contrast, 0.0, 1.0)

	return np.stack([lum("da.png", 1.1), lum("san_da.png", 1.0), np.full((512, 512), 0.5, np.float32)], -1) # BGR cho cv2


def detail(textures):
	def lum(name):
		img = cv2.imread(os.path.join(textures, name)).astype(np.float32) / 255.0
		g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
		return cv2.resize(g, (512, 512), interpolation=cv2.INTER_AREA)

	def norm(g, contrast):
		g = g - g.mean()
		return np.clip(0.5 + g / (4.0 * g.std() + 1e-4) * contrast, 0.0, 1.0)

	grass = norm(0.5 * lum("co_1.png") + 0.5 * lum("co_2.png"), 0.8)
	dirt = norm(0.8 * norm(lum("dat.png"), 1.0) + 0.2 * norm(lum("san_da.png"), 1.0), 0.9)
	blades = norm(lum("co_2.png"), 1.2)
	return np.stack([blades, dirt, grass], -1) # BGR cho cv2


def main():
	src_path, map_path, textures, out = sys.argv[1:5]
	img = cv2.imread(src_path).astype(np.float32) / 255.0
	h, w = img.shape[:2]
	px_per_m = w / SIZE[0]
	with open(map_path, encoding="utf-8") as f:
		source = f.read()

	label = classes(img)
	grass = (label == 0).astype(np.float32)
	dirt = (label == 1).astype(np.float32)
	other = (label == 2).astype(np.float32)
	noise = cv2.resize(np.random.default_rng(20261026).random((12, 12)).astype(np.float32), (w, h), interpolation=cv2.INTER_CUBIC)
	bgra = np.stack([ # cv2 ghi theo thứ tự B, G, R, A
		shadows((h, w), px_per_m, source),
		signed_field(other, px_per_m),
		signed_field(grass, px_per_m),
		0.15 + 0.85 * np.clip(noise, 0, 1), # không để alpha 0 (Godot sửa màu điểm ảnh trong suốt khi import)
	], -1)
	cv2.imwrite(os.path.join(out, "nen_lop.png"), (bgra * 255 + 0.5).astype(np.uint8))

	small = cv2.resize(img, (512, round(512 * h / w)), interpolation=cv2.INTER_AREA)
	for name, mask in (("nen_co.png", grass), ("nen_dat.png", dirt)):
		m = cv2.resize(cv2.erode(mask, np.ones((17, 17), np.uint8)), (small.shape[1], small.shape[0]), interpolation=cv2.INTER_AREA)
		m = (m > 0.99).astype(np.float32) # bỏ dải mép đã lem màu bên kia
		col = cv2.GaussianBlur(spread(small, m, 3.0), (0, 0), 2.0)
		cv2.imwrite(os.path.join(out, name), (np.clip(col, 0, 1) * 255 + 0.5).astype(np.uint8))
	half = cv2.resize(img, (1024, round(1024 * h / w)), interpolation=cv2.INTER_AREA)
	m = cv2.resize(cv2.erode(other, np.ones((5, 5), np.uint8)), (half.shape[1], half.shape[0]), interpolation=cv2.INTER_AREA)
	m = (m > 0.99).astype(np.float32)
	col = np.where(m[..., None] > 0, half, spread(half, m, 2.0))
	# Lối gạch, phiến đá xám: chỉ giữ màu loang (vân sắc do van_da.png lo), phù văn tím xanh giữ nguyên hình vẽ.
	hsv = cv2.cvtColor(col.astype(np.float32), cv2.COLOR_BGR2HSV)
	grey = 1.0 - np.clip((hsv[..., 1] - 0.18) / 0.15, 0.0, 1.0)
	cob = cv2.resize(cobble_mask((h, w), px_per_m, source), (half.shape[1], half.shape[0]), interpolation=cv2.INTER_AREA)
	cob = cv2.GaussianBlur(cob, (0, 0), 1.0)
	flat = np.maximum(grey, cob)[..., None]
	col = col * (1.0 - flat) + cv2.GaussianBlur(col, (0, 0), 5.0) * flat
	bgra = np.concatenate([col, (0.1 + 0.9 * np.clip(cob, 0, 1))[..., None]], -1) # alpha: lối gạch (không để 0)
	cv2.imwrite(os.path.join(out, "nen_da.png"), (np.clip(bgra, 0, 1) * 255 + 0.5).astype(np.uint8))
	cv2.imwrite(os.path.join(out, "van_da.png"), (stone_detail(textures) * 255 + 0.5).astype(np.uint8))
	cv2.imwrite(os.path.join(out, "van_nen.png"), (detail(textures) * 255 + 0.5).astype(np.uint8))


if __name__ == "__main__":
	main()

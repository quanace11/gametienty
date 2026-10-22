"""Tách ảnh lớp nền (R: lối đất, G: nền đá vỡ) từ bản Meshy quan gửi, cho shaders/nen_meshy.gdshader.

1. Chụp bản Meshy từ trên xuống (chỉ ánh sáng môi trường trắng, 2000 px phủ -1..1):
   godot --path <dự án trống> --rendering-driver opengl3 --resolution 2000x2000 -s chup_tu_tren.gd -- map.glb tu_tren.png
2. python3 -I lop_nen.py tu_tren.png ../../models/ban_do_meshy/lop_nen.png

Mép trong viền đá của mô hình (đo từ bản đồ độ cao): x -0,816..0,82, z -0,804..0,816, ứng với sân 50 x 45 m.
Lối lát đá và phù văn không lấy từ ảnh: map dựng bằng code (STONE_PATHS, RUNE_SPOTS) cho sắc nét.
"""

import sys

import numpy as np
from PIL import Image, ImageFilter

CROP = (184, 196, 1820, 1816) # mép trong viền đá trên ảnh chụp 2000 px
RUNES = [(150, 130, 130), (700, 90, 130), (930, 60, 110), (160, 900, 150), (600, 900, 110), (920, 900, 130)]


def smooth(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)


def main(src, dst):
	crop = Image.open(src).convert("RGB").crop(CROP).resize((1024, 1024), Image.LANCZOS)
	hsv = np.asarray(crop.convert("HSV")).astype(float) / 255
	hue, sat, val = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
	dirt = smooth(62, 48, hue) * smooth(0.18, 0.3, sat) * smooth(5, 15, hue) # vàng nâu
	slab = smooth(0.22, 0.12, sat) * smooth(0.5, 0.62, val) # xám sáng
	yy, xx = np.mgrid[0:1024, 0:1024]
	edge = (xx < 12) | (yy < 12) | (xx > 1011) | (yy > 1011)
	dirt[edge] = 0
	slab[edge] = 0
	for cx, cy, r in RUNES: # chữ phù văn vẽ trên nền: thay bằng vòng phù văn phát sáng dựng bằng code
		slab[(xx - cx) ** 2 + (yy - cy) ** 2 < r * r] = 0

	def layer(m):
		img = Image.fromarray((np.clip(m, 0, 1) * 255).astype(np.uint8))
		return img.filter(ImageFilter.GaussianBlur(2.5)).resize((512, 512), Image.LANCZOS)

	Image.merge("RGB", (layer(dirt), layer(slab), Image.new("L", (512, 512), 0))).save(dst, optimize=True)


if __name__ == "__main__":
	main(sys.argv[1], sys.argv[2])

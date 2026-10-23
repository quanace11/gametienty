"""Làm mịn ảnh màu bản Meshy cho shaders/ban_do_meshy.gdshader, giữ nguyên tông màu.

Vì sao: ảnh màu Meshy là hàng trăm mảnh vụn (UV atlas), mặt sân cắt thành nhiều mảnh nên lộ đường nối,
màu mảnh này lem sang mảnh kia khi thu nhỏ (mipmap), thêm hạt nhiễu JPEG và vệt sọc trên vách đá: nhìn
lởm chởm. Lọc giữ viền (bỏ hạt, mịn mặt, mép lối đất, mép đá vẫn rõ) như tranh vẽ tay.

Chạy ngay sau build_ban_do.py, theo thứ tự (bước 3 làm mịn tại chỗ, chạy lại sẽ mịn thêm, mất chi tiết):
1. Mặt sân: chụp thẳng từ trên xuống thành một tấm theo (x, z), từ ảnh màu gốc chưa làm mịn:
   godot --path . --rendering-driver opengl3 --resolution 2048x1844 -s Objects/tools/ban_do_meshy/chup_nen_phang.gd -- tu_tren.png
2. python3 -I lam_min.py nen tu_tren.png ../../models/ban_do_meshy/nen_min.jpg
3. Vách đá, lan can, cổng vòng (ảnh theo UV): làm mịn tại chỗ mau_goc.jpg (2048 px, đồ họa Cao) và ảnh
   1024 px trong ban_do.glb (Thấp / Vừa):
   python3 -I lam_min.py vien ../../models/ban_do_meshy
Cần opencv-python-headless.
"""

import io
import json
import os
import struct
import sys

import cv2
import numpy as np


def smooth_ground(img):
	img = cv2.medianBlur(img, 5) # bỏ hạt nhiễu, chấm lốm đốm
	return cv2.edgePreservingFilter(img, flags=cv2.RECURS_FILTER, sigma_s=25, sigma_r=0.15) # mịn mặt, giữ mép


def smooth_atlas(img, scale):
	# Bán kính nhỏ để màu không lem qua mép mảnh UV; scale: 1 cho ảnh 2048 px, 0,5 cho ảnh 1024 px.
	img = cv2.medianBlur(img, 5 if scale >= 1 else 3)
	return cv2.edgePreservingFilter(img, flags=cv2.RECURS_FILTER, sigma_s=12 * scale, sigma_r=0.12)


def jpg(img):
	return cv2.imencode(".jpg", img, [cv2.IMWRITE_JPEG_QUALITY, 92])[1].tobytes()


def replace_glb_image(path, fn):
	d = open(path, "rb").read()
	n = struct.unpack("<I", d[12:16])[0]
	j = json.loads(d[20:20 + n])
	b = d[20 + n + 8:]
	image_views = {im["bufferView"] for im in j["images"]}
	blob = bytearray()
	for i, v in enumerate(j["bufferViews"]):
		data = b[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
		if i in image_views:
			data = fn(cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR))
			j["images"] = [dict(im, mimeType="image/jpeg") if im["bufferView"] == i else im for im in j["images"]]
		while len(blob) % 4:
			blob.append(0)
		v["byteOffset"] = len(blob)
		v["byteLength"] = len(data)
		blob.extend(data)
	while len(blob) % 4:
		blob.append(0)
	j["buffers"][0]["byteLength"] = len(blob)
	js = json.dumps(j, separators=(",", ":")).encode()
	js += b" " * (-len(js) % 4)
	out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob))
	out += struct.pack("<II", len(js), 0x4E4F534A) + js
	out += struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
	open(path, "wb").write(out)


def main(mode, *paths):
	if mode == "nen":
		cv2.imwrite(paths[1], smooth_ground(cv2.imread(paths[0])), [cv2.IMWRITE_JPEG_QUALITY, 92])
	elif mode == "vien":
		original = os.path.join(paths[0], "mau_goc.jpg")
		data = jpg(smooth_atlas(cv2.imread(original), 1.0))
		open(original, "wb").write(data)
		replace_glb_image(os.path.join(paths[0], "ban_do.glb"), lambda img: jpg(smooth_atlas(img, img.shape[1] / 2048)))


if __name__ == "__main__":
	main(*sys.argv[1:])

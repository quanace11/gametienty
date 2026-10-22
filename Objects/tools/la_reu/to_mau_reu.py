"""Tô lại ảnh lá (Quaternius) theo màu rêu sàn Meshy: giữ vân sáng tối, đổi hẳn sắc màu.

Ảnh gốc không có kênh xanh lam nên nhân màu trong game không ra được tông rêu, phải tô lại ảnh.
Chạy: python3 -I Objects/tools/la_reu/to_mau_reu.py
"""
from pathlib import Path

import numpy as np
from PIL import Image

FOLDER = Path(__file__).resolve().parents[2] / "models" / "quaternius_nature"
LEAVES = ["la_cay", "la_thong", "la_bui", "la_nho"]
MOSS = np.array([0.54, 0.65, 0.29])  # màu rêu ở độ sáng giữa của lá
CONTRAST = 0.9  # giữ bớt vân sáng tối (1 = giữ nguyên)


def main() -> None:
	for name in LEAVES:
		img = np.asarray(Image.open(FOLDER / f"{name}.png").convert("RGBA")).astype(np.float64) / 255.0
		rgb, alpha = img[..., :3], img[..., 3:]
		lum = rgb @ np.array([0.3, 0.59, 0.11])
		mid = np.median(lum[alpha[..., 0] > 0.3])
		shade = 1.0 + (lum / max(mid, 1e-4) - 1.0) * CONTRAST
		out = np.clip(MOSS * shade[..., None], 0.0, 1.0)
		res = np.concatenate([out, alpha], axis=-1)
		Image.fromarray((res * 255.0 + 0.5).astype(np.uint8)).save(FOLDER / f"{name}_reu.png")
		print(name, "->", f"{name}_reu.png")


if __name__ == "__main__":
	main()

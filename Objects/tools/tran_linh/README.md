# Dựng mô hình trận linh

`Objects/models/tran_linh/tran_linh.glb` dựng từ tệp `tran.glb` quan gửi (tạo bằng AI: bệ cỏ có
vòng phù văn, 4 đá dựng, linh thạch lơ lửng; một lưới ~30k tam giác, 4 ảnh 2048 px, 14 MB).
Tệp gốc không commit vì nặng; muốn dựng lại thì xin tệp gốc rồi chạy:

```bash
python3 -m venv venv && venv/bin/pip install numpy pillow scipy meshoptimizer xatlas
venv/bin/python -I build_tran_linh.py tran.glb ../../models/tran_linh/tran_linh.glb
```

Script làm:
1. Tách lưới: bệ (`nen`), 4 đá dựng (`da_0`..`da_3`, cắt ngay trên mặt cỏ), linh thạch (`linh_thach`).
2. Cân đối: linh thạch dời về đúng giữa vòng phù văn, lơ lửng; 4 đá xoay quanh tâm về đúng
   4 góc chéo, cùng bán kính. Chỗ chân đá cũ vá bằng mặt cỏ, thêm đĩa cỏ mỏng lấp lỗ lưới gốc.
3. Giảm lưới (meshoptimizer) còn ~2,9k tam giác cả trận. UV gốc vụn nên trải UV mới (xatlas)
   rồi nướng lại ảnh màu + ảnh phát sáng 512 px từ lưới gốc; bỏ normal map, ảnh kim loại.
4. Cắt sẵn mảnh vỡ cho mỗi đá (5 mảnh) và linh thạch (9 mảnh): `da_k_manh_i`,
   `linh_thach_manh_i`, gốc ở tâm mảnh, đặt đúng chỗ trong khối. `Objects/safe.gd` dùng để làm
   hiệu ứng vỡ.

Đổi tham số (bán kính đặt đá, độ cao linh thạch, số tam giác...) ở đầu script. Số in ra cuối
(mặt cỏ, đỉnh vòng phù văn) phải khớp `GRASS_TOP`, `RUNE_TOP` trong `Objects/safe.gd`.

# Gắn khung xương tự động

Gắn bộ xương người 17 xương (hông, sống lưng, ngực, cổ, đầu, cánh tay, cẳng tay,
bàn tay, đùi, cẳng chân, bàn chân) vào mô hình tĩnh rồi tính trọng số da.
`player_character.gd` tìm xương theo đúng các tên này để làm động tác.

```bash
npm install @gltf-transform/core
node rig.mjs vao.glb ra.glb de_tu.json
```

- Đầu vào: mô hình **chưa có xương**, đã chuẩn hóa (cao 1, chân ở y = 0, nhìn về +Z), một lưới.
- `de_tu.json` / `ma_tu.json`: vị trí khớp (X dương là bên trái nhân vật) và các chỉnh riêng:
  - `arm_bias`: lớn hơn 1 thì vạt áo sát tay theo thân nhiều hơn theo tay.
  - `arm_min_y_l` / `arm_min_y_r`: thấp hơn mức này tay không kéo theo (vạt áo dưới bàn tay).
  - `reach`: bàn tay chỉ ôm đỉnh trong bán kính này.
  - `rigid`: vật cứng cầm tay (kiếm của ma tu) theo hẳn một xương, không cong theo chân.
  - `smooth`: số lượt làm mượt trọng số trên lưới.
  - `chains`: chuỗi xương phụ (tóc `hair`, tay áo `sleeve_l` / `sleeve_r`, vạt áo sau `skirt_b`)
    đặt tên `<tên>_1`, `<tên>_2`... Trong game chúng đung đưa theo lò xo (`SPRING_CHAINS`
    trong `player_character.gd`). Mỗi chuỗi: `parent` (xương cha), `points` (các điểm dọc chuỗi,
    điểm đầu gắn vào cha), `box` (chỉ đỉnh trong hộp này mới theo chuỗi), `r` (bán kính quanh chuỗi),
    `scale` (co giãn khoảng cách theo trục, ví dụ tóc rộng ngang thì x nhỏ), `fade` (đoạn đầu
    chuỗi chuyển dần từ cha sang), `max` (vạt áo vẫn theo chân một phần), `only` (chỉ lấy đỉnh
    đang theo chủ yếu các xương này).
- Mô hình mới từ Tripo / Meshy đã có xương sẵn thì không cần công cụ này, chỉ cần đặt tên xương như trên.

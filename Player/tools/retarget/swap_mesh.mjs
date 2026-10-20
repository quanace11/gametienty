// Thay lưới của GLB gốc (giữ nguyên khung xương, động tác) bằng lưới đã giảm của Blender: node swap_mesh.mjs goc.glb blender.glb ra.glb (README.md).
// Chỉ số xương trong JOINTS_0 đổi theo tên xương, vì Blender xếp lại thứ tự xương của skin.
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
const [orig, low, out] = process.argv.slice(2);
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const A = await io.read(orig), B = await io.read(low);
const meshB = B.getRoot().listMeshes().map(m => m.listPrimitives()[0]).sort((a, b) => b.getIndices().getCount() - a.getIndices().getCount())[0];
const nodeB = B.getRoot().listNodes().find(n => n.getMesh() && n.getMesh().listPrimitives()[0] === meshB);
const jointsB = nodeB.getSkin().listJoints().map(j => j.getName());
const nodeA = A.getRoot().listNodes().find(n => n.getMesh() && n.getSkin());
const jointsA = nodeA.getSkin().listJoints().map(j => j.getName());
// Xương Blender không có trong skin gốc: dồn trọng số sang xương cha gần nhất có trong skin gốc.
const parentOf = new Map(); for (const n of B.getRoot().listNodes()) for (const c of n.listChildren()) parentOf.set(c, n);
const remap = nodeB.getSkin().listJoints().map(j => { let n = j; while (n) { const i = jointsA.indexOf(n.getName()); if (i >= 0) { if (n !== j) console.log('dồn', j.getName(), '->', n.getName()); return i; } n = parentOf.get(n); } throw new Error('thiếu xương ' + j.getName()); });
const pa = nodeA.getMesh().listPrimitives()[0];
const copy = (sem) => {
  const src = meshB.getAttribute(sem); if (!src) { pa.setAttribute(sem, null); return; }
  let arr = src.getArray().slice();
  // Blender xuất lưới Y lên, lưới gốc nằm trong khung Z lên của nút skin: (x, y, z) -> (x, -z, y).
  if (sem === 'POSITION' || sem === 'NORMAL') for (let i = 0; i < arr.length; i += 3) { const y = arr[i + 1]; arr[i + 1] = -arr[i + 2]; arr[i + 2] = y; }
  if (sem === 'JOINTS_0') { const J = new Uint16Array(arr.length); for (let i = 0; i < arr.length; i++) J[i] = remap[arr[i]]; arr = J; }
  const acc = A.createAccessor().setType(src.getType()).setArray(arr).setNormalized(src.getNormalized());
  pa.setAttribute(sem, acc);
};
for (const s of pa.listSemantics()) if (!['POSITION', 'NORMAL', 'TEXCOORD_0', 'JOINTS_0', 'WEIGHTS_0'].includes(s)) pa.setAttribute(s, null);
for (const s of ['POSITION', 'NORMAL', 'TEXCOORD_0', 'JOINTS_0', 'WEIGHTS_0']) copy(s);
for (const t of pa.listTargets()) pa.removeTarget(t);
nodeA.getMesh().setWeights([]);
pa.setIndices(A.createAccessor().setType('SCALAR').setArray(meshB.getIndices().getArray().slice()));
const pb = meshB.getAttribute('POSITION'); console.log('đỉnh', pb.getCount(), 'tam giác', meshB.getIndices().getCount() / 3, 'min', pb.getMin([]), 'max', pb.getMax([]));
const pn = pa.getAttribute('POSITION'); console.log('sau đổi min', pn.getMin([]), 'max', pn.getMax([]));
await io.write(out, A);

// node rig.mjs in.glb out.glb landmarks.json
// Gắn khung xương người (17 xương) vào mô hình đã chuẩn hóa (cao 1, chân ở y=0, nhìn +Z)
// và tính trọng số da theo khoảng cách tới đoạn xương, có chặn theo vùng.
import {NodeIO} from '@gltf-transform/core';
import fs from 'fs';
const [,, inp, out, lmFile] = process.argv;
const L = JSON.parse(fs.readFileSync(lmFile, 'utf8'));
// tên, cha, khớp đầu, khớp cuối
const B = [
  ['hips', -1, 'hips', 'spine'], ['spine', 0, 'spine', 'chest'], ['chest', 1, 'chest', 'neck'],
  ['neck', 2, 'neck', 'head'], ['head', 3, 'head', 'head_end'],
  ['upper_arm_l', 2, 'upper_arm_l', 'forearm_l'], ['forearm_l', 5, 'forearm_l', 'hand_l'], ['hand_l', 6, 'hand_l', 'hand_l_end'],
  ['upper_arm_r', 2, 'upper_arm_r', 'forearm_r'], ['forearm_r', 8, 'forearm_r', 'hand_r'], ['hand_r', 9, 'hand_r', 'hand_r_end'],
  ['thigh_l', 0, 'thigh_l', 'shin_l'], ['shin_l', 11, 'shin_l', 'foot_l'], ['foot_l', 12, 'foot_l', 'foot_l_end'],
  ['thigh_r', 0, 'thigh_r', 'shin_r'], ['shin_r', 14, 'shin_r', 'foot_r'], ['foot_r', 15, 'foot_r', 'foot_r_end'],
];
const LEGS = new Set([11,12,13,14,15,16]), HEADB = new Set([3,4]), ARMS = new Set([5,6,7,8,9,10]);
const io = new NodeIO();
const doc = await io.read(inp);
const root = doc.getRoot();
const prim = root.listMeshes()[0].listPrimitives()[0];
const P = prim.getAttribute('POSITION').getArray();
const n = P.length / 3;
// tinh chỉnh z (và x) của gối / bàn chân theo trọng tâm lưới quanh đó
function refine(name, side) {
  const j = L[name]; let sx = 0, sz = 0, c = 0;
  for (let v = 0; v < n; v++) {
    const x = P[3*v], y = P[3*v+1], z = P[3*v+2];
    if (Math.abs(y - j[1]) < 0.025 && Math.sign(x - L.hips[0]) === side && Math.abs(x - j[0]) < 0.08) { sx += x; sz += z; c++; }
  }
  if (c > 10) { j[0] = sx / c; j[2] = sz / c; }
}
if (L.refine_legs) for (const [nm, s] of [['foot_l',1],['foot_r',-1],['shin_l',1],['shin_r',-1]]) refine(nm, s);
for (const s of ['l','r']) { const f = L['foot_'+s]; if (!L['foot_'+s+'_end']) L['foot_'+s+'_end'] = [f[0], 0.01, f[2] + 0.08]; }
const segA = B.map(b => L[b[2]]), segB = B.map(b => L[b[3]]);
function dseg(p, a, b) {
  const ab = [b[0]-a[0], b[1]-a[1], b[2]-a[2]], ap = [p[0]-a[0], p[1]-a[1], p[2]-a[2]];
  const l2 = ab[0]*ab[0]+ab[1]*ab[1]+ab[2]*ab[2];
  let t = l2 > 0 ? (ap[0]*ab[0]+ap[1]*ab[1]+ap[2]*ab[2]) / l2 : 0; t = Math.max(0, Math.min(1, t));
  const q = [a[0]+ab[0]*t-p[0], a[1]+ab[1]*t-p[1], a[2]+ab[2]*t-p[2]];
  return Math.hypot(q[0], q[1], q[2]);
}
const NB = B.length, hipY = L.hips[1], neckY = L.neck[1];
function allowed(i, p) {
  if (LEGS.has(i) && p[1] > hipY + 0.04) return false;
  if (HEADB.has(i) && p[1] < neckY - 0.05) return false;
  // tay không kéo vạt áo phía dưới (riêng từng bên; mức đặt ngay dưới đầu ngón tay)
  if (ARMS.has(i)) { const m = i <= 7 ? L.arm_min_y_l : L.arm_min_y_r; if (m !== undefined && p[1] < m) return false; }
  return true;
}
// trọng số thô theo khoảng cách tới đoạn xương (đủ 17 xương mỗi đỉnh)
const Wf = new Float32Array(n * NB);
for (let v = 0; v < n; v++) {
  const p = [P[3*v], P[3*v+1], P[3*v+2]];
  let s = 0;
  for (let i = 0; i < NB; i++) {
    if (!allowed(i, p)) continue;
    let d = dseg(p, segA[i], segB[i]);
    if (ARMS.has(i)) d *= L.arm_bias ?? 1.0; // >1: ưu tiên thân hơn tay (vạt áo sát tay)
    const r = L.reach?.[B[i][0]]; if (r !== undefined && d > r) d = r + (d - r) * 4; // xương nhỏ (bàn tay) chỉ ôm đỉnh sát nó
    const w = 1 / Math.pow(d + 0.012, 4); Wf[v*NB+i] = w; s += w;
  }
  for (let i = 0; i < NB; i++) Wf[v*NB+i] /= s;
}
// làm mượt trọng số trên lưới (đỉnh trùng vị trí coi là một), cho chỗ chuyển khớp mềm, bớt gai
const SMOOTH = Number(process.env.SMOOTH ?? L.smooth ?? 0);
if (SMOOTH > 0) {
  const key = new Map(), wid = new Int32Array(n);
  for (let v = 0; v < n; v++) { const k = `${P[3*v].toFixed(5)},${P[3*v+1].toFixed(5)},${P[3*v+2].toFixed(5)}`; if (!key.has(k)) key.set(k, key.size); wid[v] = key.get(k); }
  const m = key.size, I = prim.getIndices().getArray();
  const nbs = Array.from({length: m}, () => new Set());
  for (let t = 0; t < I.length; t += 3) for (let a = 0; a < 3; a++) { const x = wid[I[t+a]], y = wid[I[t+(a+1)%3]]; if (x !== y) { nbs[x].add(y); nbs[y].add(x); } }
  const nb = nbs.map(st => [...st]);
  let G = new Float32Array(m * NB), cnt = new Float32Array(m);
  const rep = new Int32Array(m);
  for (let v = 0; v < n; v++) { const g = wid[v]; rep[g] = v; cnt[g]++; for (let i = 0; i < NB; i++) G[g*NB+i] += Wf[v*NB+i]; }
  for (let g = 0; g < m; g++) for (let i = 0; i < NB; i++) G[g*NB+i] /= cnt[g];
  for (let it = 0; it < SMOOTH; it++) {
    const H = new Float32Array(m * NB);
    for (let g = 0; g < m; g++) {
      const ns = nb[g]; const k = ns.length;
      for (let i = 0; i < NB; i++) {
        let a = 0; for (const h of ns) a += G[h*NB+i];
        H[g*NB+i] = k ? 0.5 * G[g*NB+i] + 0.5 * a / k : G[g*NB+i];
      }
    }
    G = H;
  }
  for (let v = 0; v < n; v++) {
    const g = wid[v], p = [P[3*v], P[3*v+1], P[3*v+2]]; let s = 0;
    for (let i = 0; i < NB; i++) { const w = allowed(i, p) ? G[g*NB+i] : 0; Wf[v*NB+i] = w; s += w; }
    for (let i = 0; i < NB; i++) Wf[v*NB+i] /= s;
  }
}
// vật cứng cầm tay (kiếm): đỉnh trong ống quanh đoạn a-b theo hẳn một xương, không cong theo chân
for (const rg of L.rigid ?? []) {
  const bi = B.findIndex(b => b[0] === rg.bone);
  for (let v = 0; v < n; v++) {
    if (dseg([P[3*v], P[3*v+1], P[3*v+2]], rg.a, rg.b) > rg.r) continue;
    for (let i = 0; i < NB; i++) Wf[v*NB+i] = i === bi ? 1 : 0;
  }
}
const J = new Uint16Array(n * 4), W = new Float32Array(n * 4);
for (let v = 0; v < n; v++) {
  const cand = [];
  for (let i = 0; i < NB; i++) if (Wf[v*NB+i] > 0) cand.push([i, Wf[v*NB+i]]);
  cand.sort((a, b) => b[1] - a[1]);
  const top = cand.slice(0, 4); let s = top.reduce((a, c) => a + c[1], 0);
  for (let k = 0; k < 4; k++) {
    if (k < top.length && top[k][1] / s > 0.03) { J[4*v+k] = top[k][0]; W[4*v+k] = top[k][1]; } else { J[4*v+k] = 0; W[4*v+k] = 0; }
  }
  s = W[4*v] + W[4*v+1] + W[4*v+2] + W[4*v+3];
  for (let k = 0; k < 4; k++) W[4*v+k] /= s;
}
const buf = root.listBuffers()[0];
prim.setAttribute('JOINTS_0', doc.createAccessor().setType('VEC4').setArray(J).setBuffer(buf));
prim.setAttribute('WEIGHTS_0', doc.createAccessor().setType('VEC4').setArray(W).setBuffer(buf));
// nút xương: vị trí so với cha
const nodes = B.map(b => doc.createNode(b[0]));
B.forEach((b, i) => {
  const g = L[b[2]], pg = b[1] >= 0 ? L[B[b[1]][2]] : [0, 0, 0];
  nodes[i].setTranslation([g[0]-pg[0], g[1]-pg[1], g[2]-pg[2]]);
  if (b[1] >= 0) nodes[b[1]].addChild(nodes[i]);
});
const ibm = new Float32Array(16 * B.length);
B.forEach((b, i) => { const g = L[b[2]]; ibm.set([1,0,0,0, 0,1,0,0, 0,0,1,0, -g[0],-g[1],-g[2],1], 16*i); });
const skin = doc.createSkin('Body').setSkeleton(nodes[0]).setInverseBindMatrices(doc.createAccessor().setType('MAT4').setArray(ibm).setBuffer(buf));
nodes.forEach(nd => skin.addJoint(nd));
const meshNode = root.listNodes().find(nd => nd.getMesh());
meshNode.setSkin(skin).setTranslation([0,0,0]).setRotation([0,0,0,1]).setScale([1,1,1]);
const armature = doc.createNode('Armature').addChild(nodes[0]);
root.listScenes()[0].addChild(armature);
await io.write(out, doc);
console.log(out, 'verts', n);

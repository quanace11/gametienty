// Giảm lưới GLB cho một mức đồ họa: node slim.mjs vao.glb ra.glb so_tam_giac (README.md).
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { weld, simplify, prune, dedup } from '@gltf-transform/functions';
import { MeshoptSimplifier } from 'meshoptimizer';
const [inp, out, target] = process.argv.slice(2);
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
const doc = await io.read(inp);
for (const m of doc.getRoot().listMeshes()) for (const p of m.listPrimitives()) {
  for (const t of p.listTargets()) p.removeTarget(t);
  m.setWeights([]);
  for (const s of ['COLOR_0', 'TANGENT']) { const a = p.getAttribute(s); if (a) p.setAttribute(s, null); }
  const j0 = p.getAttribute('JOINTS_0'), j1 = p.getAttribute('JOINTS_1'), w0 = p.getAttribute('WEIGHTS_0'), w1 = p.getAttribute('WEIGHTS_1');
  if (j1) {
    const n = j0.getCount(), J = new Uint16Array(n*4), W = new Float32Array(n*4);
    const a=[0,0,0,0], b=[0,0,0,0], c=[0,0,0,0], d=[0,0,0,0];
    for (let i=0;i<n;i++) {
      j0.getElement(i,a); j1.getElement(i,b); w0.getElement(i,c); w1.getElement(i,d);
      const items = [0,1,2,3].map(k=>[a[k],c[k]]).concat([0,1,2,3].map(k=>[b[k],d[k]])).sort((x,y)=>y[1]-x[1]).slice(0,4);
      const sum = items.reduce((s,x)=>s+x[1],0) || 1;
      items.forEach((x,k)=>{J[i*4+k]=x[0]; W[i*4+k]=x[1]/sum;});
    }
    j0.setArray(J); w0.setArray(W);
    p.setAttribute('JOINTS_1', null); p.setAttribute('WEIGHTS_1', null);
  }
  const tris = p.getIndices().getCount()/3;
  console.log('trước', tris);
}
await doc.transform(dedup(), weld(), prune());
let tris = 0;
for (const m of doc.getRoot().listMeshes()) for (const p of m.listPrimitives()) tris += p.getIndices().getCount()/3;
await doc.transform(simplify({ simplifier: MeshoptSimplifier, ratio: Number(target)/tris, error: 0.02, lockBorder: false }), prune());
for (const m of doc.getRoot().listMeshes()) for (const p of m.listPrimitives()) console.log('sau', p.getIndices().getCount()/3, 'đỉnh', p.getAttribute('POSITION').getCount());
await io.write(out, doc);

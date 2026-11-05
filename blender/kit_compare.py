# Starfall Vanguard: check that two builds of trooper_kit.glb are the same kit.
# Blender does not write the same bytes twice for this kit: it lists the vertices of some meshes in a different order
# on each run (measured: positions agree to 0.003 mm once matched, baked shading exactly). So a rebuild is checked part
# by part instead: the same nodes and meshes, the same vertex and triangle counts, every vertex matched to one in the
# other build within --tol metres (preferring the same normal, since seams repeat positions), and shading within --ao.
# Run: python3 -I kit_compare.py a.glb b.glb [--tol 0.0002] [--ao 0.08]   (exit 0 when they match)
# MIT License. Copyright (c) 2026 Brian Guarino / Guarino Gaming Group (G3), a department of Guarino Industries LLC.
import sys, json, struct
import numpy as np

CT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}

def load(path):
    b = open(path, 'rb').read(); n = struct.unpack('<I', b[12:16])[0]; j = json.loads(b[20:20 + n])
    o = 20 + n; bl = struct.unpack('<I', b[o:o + 4])[0]; return j, b[o + 8:o + 8 + bl]

def acc(j, BIN, i):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]; t = CT[a['componentType']]; n = NC[a['type']]
    arr = np.frombuffer(BIN, dtype=t, count=a['count'] * n, offset=bv.get('byteOffset', 0) + a.get('byteOffset', 0))
    arr = arr.reshape(a['count'], n).astype(np.float64)
    if a.get('normalized'): arr /= np.iinfo(t).max
    return arr

# every vertex of P against its nearest vertex of Q (preferring one with the same normal, since seams duplicate
# positions): the largest distance, and the largest shading difference among matched vertices
def match(P, NP, CP, Q, NQ, CQ):
    worst_d, worst_c = 0.0, 0.0
    for i0 in range(0, len(P), 512):
        p, n = P[i0:i0 + 512], NP[i0:i0 + 512]
        D = np.linalg.norm(p[:, None, :] - Q[None, :, :], axis=2)
        score = D + .01 * (1.0 - n @ NQ.T)                 # ties at one position go to the vertex facing the same way
        k = score.argmin(1); worst_d = max(worst_d, D[np.arange(len(p)), k].max())
        if CP is not None and CQ is not None: worst_c = max(worst_c, np.abs(CP[i0:i0 + 512] - CQ[k]).max())
    return worst_d, worst_c

def main():
    args = sys.argv[1:]
    tol = float(args[args.index('--tol') + 1]) if '--tol' in args else 2e-4
    aot = float(args[args.index('--ao') + 1]) if '--ao' in args else .08
    (ja, Ba), (jb, Bb) = load(args[0]), load(args[1]); bad = []
    na, nb = sorted(n['name'] for n in ja['nodes']), sorted(n['name'] for n in jb['nodes'])
    if na != nb: bad.append('nodes differ: %s' % sorted(set(na) ^ set(nb))[:10])
    ma = {m['name']: m for m in ja['meshes']}; mb = {m['name']: m for m in jb['meshes']}
    if set(ma) != set(mb): bad.append('meshes differ: %s' % sorted(set(ma) ^ set(mb))[:10])
    worst_p, worst_c = 0.0, 0.0
    for name in sorted(set(ma) & set(mb)):
        pa, pb = ma[name]['primitives'], mb[name]['primitives']
        if len(pa) != len(pb): bad.append('%s: %d against %d primitives' % (name, len(pa), len(pb))); continue
        for x, y in zip(pa, pb):
            P, Q = acc(ja, Ba, x['attributes']['POSITION']), acc(jb, Bb, y['attributes']['POSITION'])
            ta, tb = ja['accessors'][x['indices']]['count'], jb['accessors'][y['indices']]['count']
            if P.shape != Q.shape or ta != tb: bad.append('%s: counts %s/%d against %s/%d' % (name, P.shape, ta, Q.shape, tb)); continue
            NP, NQ = acc(ja, Ba, x['attributes']['NORMAL']), acc(jb, Bb, y['attributes']['NORMAL'])
            CP = acc(ja, Ba, x['attributes']['COLOR_0']) if 'COLOR_0' in x['attributes'] else None
            CQ = acc(jb, Bb, y['attributes']['COLOR_0']) if 'COLOR_0' in y['attributes'] else None
            dp, dc = match(P, NP, CP, Q, NQ, CQ); d2, _ = match(Q, NQ, CQ, P, NP, CP)
            d = max(dp, d2); worst_p = max(worst_p, d); worst_c = max(worst_c, dc)
            if d > tol: bad.append('%s: positions differ by %.6f m' % (name, d))
            if dc > aot: bad.append('%s: baked shading differs by %.3f' % (name, dc))
    print('KIT %d nodes, %d meshes; largest position difference %.6f m, largest shading difference %.3f'
          % (len(na), len(ma), worst_p, worst_c))
    for b in bad[:40]: print('KIT DIFFERS', b)
    print('KIT SAME' if not bad else 'KIT NOT THE SAME (%d differences)' % len(bad))
    sys.exit(0 if not bad else 1)

main()

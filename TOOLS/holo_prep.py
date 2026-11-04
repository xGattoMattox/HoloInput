#!/usr/bin/env python3
"""
holo_prep.py - prepara una mesh TRELLIS/Pixal3D per HoloInput.

Ingresso : .glb (uscita del workflow ComfyUI) oppure .obj
Uscita   : <nome>_holo.obj con due oggetti
             o holo_fill   -> triangoli (riempimento traslucido)
             o holo_lines  -> polilinee 'l' degli spigoli vivi (le linee dell'ologramma)
           sistema Y in alto (standard OBJ/glTF), pivot nell'origine 0,0,0
           <nome>_holo.png anteprima in stile ologramma (se Pillow e' installato)

Esempi:
  python holo_prep.py holo_00001.glb                       (allineamento automatico, pivot in cima)
  python holo_prep.py base.glb --pivot bottom --size 1 --largest
  python holo_prep.py warbrd.obj --pivot top
  python holo_prep.py vpap_r.obj --align stick --pivot bottom --scale 0.66
  python holo_prep.py xbox.obj --align pad --pivot center
  python holo_prep.py grip.glb --align none --rot -28.3 -0.1 -45.1 --pivot 0,-0.21,0
  python holo_prep.py grip.glb --angle 30 --min-len 1.5

Requisiti: numpy (Pillow opzionale per l'anteprima). Gira con il python di ComfyUI.
"""
import argparse, json, math, os, struct, sys
import numpy as np


# --------------------------------------------------------------------------- lettura

def load_glb(path):
    data = open(path, 'rb').read()
    magic, _, length = struct.unpack('<4sII', data[:12])
    if magic != b'glTF':
        sys.exit('File GLB non valido: ' + path)
    off, js, binc = 12, None, b''
    while off < length:
        clen, ctype = struct.unpack('<II', data[off:off + 8])
        chunk = data[off + 8:off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk)
        elif ctype == 0x004E4942:
            binc = chunk
        off += 8 + clen
    CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
    NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}

    def acc(i):
        a = js['accessors'][i]
        bv = js['bufferViews'][a['bufferView']]
        dt, n = np.dtype(CT[a['componentType']]), NC[a['type']]
        o = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
        stride = bv.get('byteStride', 0)
        if stride and stride != dt.itemsize * n:
            raw = np.frombuffer(binc, np.uint8, stride * a['count'], o).reshape(a['count'], stride)
            return raw[:, :dt.itemsize * n].copy().view(dt).reshape(a['count'], n)
        return np.frombuffer(binc, dt, a['count'] * n, o).reshape(a['count'], n)

    def node_matrix(nd):
        if 'matrix' in nd:
            return np.array(nd['matrix'], float).reshape(4, 4).T
        M = np.eye(4)
        if 'scale' in nd:
            M = np.diag(list(nd['scale']) + [1]) @ M
        if 'rotation' in nd:
            x, y, z, w = nd['rotation']
            R = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                          [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                          [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
            R4 = np.eye(4); R4[:3, :3] = R; M = R4 @ M
        if 'translation' in nd:
            T = np.eye(4); T[:3, 3] = nd['translation']; M = T @ M
        return M

    Ps, Is, base = [], [], 0

    def walk(ni, parent):
        nonlocal base
        nd = js['nodes'][ni]
        M = parent @ node_matrix(nd)
        if 'mesh' in nd:
            for pr in js['meshes'][nd['mesh']]['primitives']:
                if pr.get('mode', 4) != 4:
                    continue
                P = acc(pr['attributes']['POSITION']).astype(float)
                I = acc(pr['indices']).astype(np.int64).reshape(-1, 3) if 'indices' in pr \
                    else np.arange(len(P)).reshape(-1, 3)
                P = P @ M[:3, :3].T + M[:3, 3]
                Ps.append(P); Is.append(I + base); base += len(P)
        for c in nd.get('children', []):
            walk(c, M)

    scene = js['scenes'][js.get('scene', 0)] if 'scenes' in js else {'nodes': list(range(len(js['nodes'])))}
    for r in scene['nodes']:
        walk(r, np.eye(4))
    if not Ps:
        sys.exit('Nessuna mesh a triangoli nel GLB')
    return np.vstack(Ps), np.vstack(Is)


def load_obj(path):
    P, F = [], []
    with open(path, encoding='utf-8', errors='ignore') as f:
        for ln in f:
            if ln.startswith('v '):
                P.append([float(t) for t in ln.split()[1:4]])
            elif ln.startswith('f '):
                idx = [int(t.split('/')[0]) for t in ln.split()[1:]]
                idx = [i - 1 if i > 0 else len(P) + i for i in idx]
                for k in range(1, len(idx) - 1):
                    F.append([idx[0], idx[k], idx[k + 1]])
    return np.array(P, float), np.array(F, np.int64)


# --------------------------------------------------------------------------- pulizia

def weld(P, I, tol):
    q = np.round(P / tol).astype(np.int64)
    _, first, inv = np.unique(q, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    P2, I2 = P[first], inv[I]
    ok = (I2[:, 0] != I2[:, 1]) & (I2[:, 1] != I2[:, 2]) & (I2[:, 0] != I2[:, 2])
    I2 = I2[ok]
    s = np.sort(I2, 1)
    _, u = np.unique(s, axis=0, return_index=True)
    return P2, I2[np.sort(u)]


def compact(P, I):
    used = np.unique(I)
    remap = -np.ones(len(P), np.int64); remap[used] = np.arange(len(used))
    return P[used], remap[I]


def face_normals(P, I):
    n = np.cross(P[I[:, 1]] - P[I[:, 0]], P[I[:, 2]] - P[I[:, 0]])
    a = np.linalg.norm(n, axis=1)
    return n / (a[:, None] + 1e-20), a * 0.5


def components(nv, edges):
    par = np.arange(nv)

    def find(x):
        r = x
        while par[r] != r:
            r = par[r]
        while par[x] != r:
            par[x], x = r, par[x]
        return r
    for a, b in edges:
        ra, rb = find(a), find(b)
        if ra != rb:
            par[ra] = rb
    return np.array([find(i) for i in range(nv)])


def drop_small(P, I, min_frac):
    e = np.vstack([I[:, [0, 1]], I[:, [1, 2]]])
    lab = components(len(P), e)
    _, area = face_normals(P, I)
    fl = lab[I[:, 0]]
    tot = np.bincount(fl, area, minlength=len(P))
    keep = tot[fl] >= min_frac * area.sum()
    nd = len(np.unique(fl)) - len(np.unique(fl[keep]))
    return compact(P, I[keep]) + (nd,)


def cluster_decimate(P, I, target):
    """Riduzione di emergenza (vertex clustering) se la mesh e' troppo pesante.
    Meglio usare DecimateMesh in ComfyUI: questa serve solo come ripiego."""
    lo, hi = P.min(0), P.max(0)
    ext = (hi - lo).max()
    g = max(16, int(math.sqrt(target) * 1.1))
    for _ in range(12):
        cell = ext / g
        key = np.floor((P - lo) / cell).astype(np.int64)
        _, inv = np.unique(key, axis=0, return_inverse=True)
        inv = inv.ravel()
        I2 = inv[I]
        ok = (I2[:, 0] != I2[:, 1]) & (I2[:, 1] != I2[:, 2]) & (I2[:, 0] != I2[:, 2])
        nf = int(ok.sum())
        if nf > target * 1.15:
            g = int(g / math.sqrt(nf / target))
        elif nf < target * 0.7:
            g = int(g * math.sqrt(target / max(nf, 1)))
        else:
            break
    cnt = np.bincount(inv)
    Pc = np.zeros((cnt.size, 3))
    for k in range(3):
        Pc[:, k] = np.bincount(inv, P[:, k]) / cnt
    I2 = I2[ok]
    s = np.sort(I2, 1)
    _, u = np.unique(s, axis=0, return_index=True)
    return compact(Pc, I2[np.sort(u)])


# --------------------------------------------------------------------------- allineamento

def rot_xyz_deg(rx, ry, rz):
    """Euler XYZ come nel pannello di Blender (R = Rz*Ry*Rx)."""
    a, b, c = map(math.radians, (rx, ry, rz))
    Rx = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
    Ry = np.array([[math.cos(b), 0, math.sin(b)], [0, 1, 0], [-math.sin(b), 0, math.cos(b)]])
    Rz = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return Rz @ Ry @ Rx

# glTF/OBJ (Y su)  <->  Blender (Z su): Blender importa (x,y,z) come (x,-z,y)
Y2B = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]], float)


def dominant_axes(P, I, rng):
    n, a = face_normals(P, I)
    m = a > 0
    n, a = n[m], a[m]
    cand = n[rng.choice(len(n), size=min(1500, len(n)), replace=False, p=a / a.sum())]
    tol = math.cos(math.radians(8))

    def score(c):
        return a[np.abs(n @ c) > tol].sum()

    def refine(c):
        for _ in range(3):
            s = n @ c
            sel = np.abs(s) > tol
            v = (n[sel] * np.sign(s[sel])[:, None] * a[sel][:, None]).sum(0)
            c = v / np.linalg.norm(v)
        return c
    sc = np.array([score(c) for c in cand])
    c1 = refine(cand[sc.argmax()])
    orth = np.abs(cand @ c1) < math.sin(math.radians(8))
    if not orth.any():
        return None
    c2c = cand[orth]
    sc2 = np.array([score(c) for c in c2c])
    c2 = refine(c2c[sc2.argmax()])
    c2 = c2 - c1 * (c2 @ c1); c2 /= np.linalg.norm(c2)
    c3 = np.cross(c1, c2)
    return c1, c2, c3, sc.max() / a.sum(), sc2.max() / a.sum()


def auto_align(P, I, up_mode):
    rng = np.random.default_rng(1)
    r = dominant_axes(P, I, rng)
    if r is None:
        print('  allineamento automatico non riuscito: lascio l\'orientamento originale')
        return np.eye(3)
    c1, c2, c3, f1, f2 = r
    print('  piani dominanti: %.0f%% e %.0f%% della superficie' % (f1 * 100, f2 * 100))
    axes = {'1': c1, '2': c2, '3': c3}
    # quale asse e' "su": di default il piano piu' esteso (piastra della base)
    up = axes.get(up_mode, c1) if up_mode in axes else c1
    others = [c for c in (c1, c2, c3) if c is not up]
    # verso: il piano dominante e' la piastra d'appoggio, il grosso dell'oggetto sta sopra
    n, a = face_normals(P, I)
    t = P @ up
    tf = (t[I[:, 0]] + t[I[:, 1]] + t[I[:, 2]]) / 3
    flat = np.abs(n @ up) > 0.95
    o = np.argsort(tf[flat]); cw = np.cumsum(a[flat][o])
    plate = tf[flat][o][np.searchsorted(cw, cw[-1] / 2)]
    eps = (t.max() - t.min()) * 0.02
    if a[tf < plate - eps].sum() > a[tf > plate + eps].sum():
        up = -up
    x = others[0]
    z = np.cross(x, up)
    R = np.vstack([x, up, z])           # righe = nuovi assi X, Y(su), Z
    if np.linalg.det(R) < 0:
        R[2] = -R[2]
    return R


def stick_align(P, I):
    """Impugnature: l'asse verticale e' quello del connettore in basso
    (l'estremita' piu' stretta dell'oggetto, che ha un tappo piatto).
    Davanti (+Z) = lato del grilletto, dove la presa si sporge a meta' altezza."""
    n, a = face_normals(P, I)
    X = P - P.mean(0)
    ax = np.linalg.eigh(np.cov(X.T))[1][:, 2]
    t = X @ ax
    band = 0.12 * np.ptp(t)

    def radius(sel):
        Q = X[sel] - X[sel].mean(0)
        return np.linalg.norm(Q - np.outer(Q @ ax, ax), axis=1).mean()
    lo_sel, hi_sel = t < t.min() + band, t > t.max() - band
    if radius(hi_sel) < radius(lo_sel):          # il connettore e' all'altra estremita'
        ax, t = -ax, -t
        lo_sel = t < t.min() + band
    fs = lo_sel[I].all(1)
    c = -ax
    for _ in range(4):                           # normale del tappo del connettore
        m = fs & (n @ c > 0.9)
        if not m.any():
            break
        v = (n[m] * a[m, None]).sum(0); c = v / np.linalg.norm(v)
    up = -c
    print('  asse connettore inclinato di %.1f gradi rispetto all\'asse lungo' % math.degrees(math.acos(min(1, abs(up @ ax)))))
    Xh = X - np.outer(X @ up, up)
    z = np.linalg.eigh(np.cov(Xh.T))[1][:, 2]
    z -= up * (z @ up); z /= np.linalg.norm(z)
    h = X @ up; hr = (h - h.min()) / np.ptp(h)
    foot = X[hr < 0.04].mean(0)
    mid = X[(hr > 0.15) & (hr < 0.5)].mean(0)
    if (mid - foot) @ z < 0:
        z = -z
    x = np.cross(up, z)
    return np.vstack([x, up, z])


def pad_align(P, I):
    """Gamepad: larghezza = asse principale (X), spessore = asse minore (Y su,
    pulsanti verso l'alto), profondita' Z (+Z = bumper/grilletti, -Z = impugnature).
    Il lato delle impugnature e' quello "biforcato" (due manici staccati) e le
    impugnature scendono sotto il piano dei pulsanti."""
    X = P - P.mean(0)
    V = np.linalg.eigh(np.cov(X.T))[1]
    up, fwd, wid = V[:, 0], V[:, 1], V[:, 2]
    w = X @ wid
    d = X @ fwd
    h = X @ up
    lo_d = d < d.min() + 0.2 * np.ptp(d)
    hi_d = d > d.max() - 0.2 * np.ptp(d)
    if np.abs(w[hi_d]).mean() > np.abs(w[lo_d]).mean():    # le impugnature vanno verso -Z
        fwd, d = -fwd, -d
        lo_d, hi_d = hi_d, lo_d
    if h[lo_d].mean() > h.mean():                            # le impugnature stanno in basso
        up = -up
    x = np.cross(up, fwd)                                    # destra del giocatore = -X
    print('  gamepad: larghezza %.3f, spessore %.3f, profondita\' %.3f' % (np.ptp(w), np.ptp(h), np.ptp(d)))
    return np.vstack([x, up, fwd])


# --------------------------------------------------------------------------- spigoli

def edge_table(I):
    e = np.vstack([I[:, [0, 1]], I[:, [1, 2]], I[:, [2, 0]]])
    f = np.tile(np.arange(len(I)), 3)
    e.sort(1)
    o = np.lexsort((e[:, 1], e[:, 0]))
    e, f = e[o], f[o]
    new = np.ones(len(e), bool); new[1:] = np.any(e[1:] != e[:-1], axis=1)
    gid = np.cumsum(new) - 1
    ue = e[new]
    cnt = np.bincount(gid)
    first = np.flatnonzero(new)
    f0 = f[first]
    f1 = np.where(cnt >= 2, f[np.minimum(first + 1, len(f) - 1)], -1)
    return ue, f0, f1, cnt


def filtered_normals(P, I, iters, sigma=0.1):
    """Filtro bilaterale sulle normali: toglie il rumore delle superfici
    generate dall'IA senza ammorbidire gli spigoli veri."""
    n, a = face_normals(P, I)
    if iters <= 0:
        return n
    ue, f0, f1, cnt = edge_table(I)
    m = f1 >= 0
    g0, g1 = f0[m], f1[m]
    for _ in range(iters):
        d = np.einsum('ij,ij->i', n[g0], n[g1])
        w = np.exp(-((1 - d) / sigma) ** 2)
        acc = n * a[:, None]
        for k in range(3):
            acc[:, k] += np.bincount(g0, w * a[g1] * n[g1, k], len(I)) + np.bincount(g1, w * a[g0] * n[g0, k], len(I))
        n = acc / (np.linalg.norm(acc, axis=1, keepdims=True) + 1e-20)
    return n


def feature_edges(P, I, angle, min_len_frac, smooth=3, region=0.4):
    """Spigoli vivi 'puliti': la superficie viene divisa in zone lisce
    (normali entro 'angle'), le zone troppo piccole (rumore) vengono assorbite
    dalle vicine e restano solo i confini tra zone vere."""
    n = filtered_normals(P, I, smooth)
    _, area = face_normals(P, I)
    ue, f0, f1, cnt = edge_table(I)
    inner = f1 >= 0
    g0, g1 = f0[inner], f1[inner]
    smooth_e = np.einsum('ij,ij->i', n[g0], n[g1]) >= math.cos(math.radians(angle))
    lab = components(len(I), np.c_[g0[smooth_e], g1[smooth_e]])
    big_lab = np.bincount(lab, area, len(I)) >= region / 100.0 * area.sum()
    for _ in range(500):
        big = big_lab[lab]
        m = ~big[g0] & big[g1]
        lab[g0[m]] = lab[g1[m]]
        m2 = ~big[g1] & big[g0]
        lab[g1[m2]] = lab[g0[m2]]
        if not (m.any() or m2.any()):
            break
    sharp = np.ones(len(ue), bool)                 # bordi aperti e non-manifold = sempre spigolo
    sharp[np.flatnonzero(inner)] = lab[g0] != lab[g1]
    E = ue[sharp]
    if len(E) == 0:
        return E
    # togli il "rumore": catene di spigoli troppo corte
    L = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1)
    used = np.unique(E)
    rm = -np.ones(len(P), np.int64); rm[used] = np.arange(len(used))
    lab = components(len(used), rm[E])
    cl = lab[rm[E[:, 0]]]
    tot = np.bincount(cl, L)
    diag = np.linalg.norm(P.max(0) - P.min(0))
    return E[tot[cl] >= min_len_frac / 100.0 * diag]


def chain(E):
    """Unisce gli spigoli in polilinee (file piu' piccolo, disegno piu' veloce)."""
    from collections import defaultdict
    adj = defaultdict(list)
    for k, (a, b) in enumerate(E):
        adj[a].append((b, k)); adj[b].append((a, k))
    used = np.zeros(len(E), bool)
    lines = []
    starts = [v for v in adj if len(adj[v]) != 2] + list(adj.keys())
    for s in starts:
        for _ in range(len(adj[s])):
            nxt = next(((b, k) for b, k in adj[s] if not used[k]), None)
            if nxt is None:
                break
            pl, cur = [s], s
            while nxt is not None:
                b, k = nxt; used[k] = True; pl.append(b); cur = b
                if len(adj[cur]) != 2:
                    break
                nxt = next(((bb, kk) for bb, kk in adj[cur] if not used[kk]), None)
            lines.append(pl)
    return lines


def clean_lines(P, lines, diag, smooth=3, tol=0.002):
    """Ammorbidisce le polilinee (via le seghettature dei triangoli) e le semplifica
    (Douglas-Peucker): tratti dritti e puliti come in un disegno tecnico."""
    def dp(pts):
        if len(pts) < 3:
            return pts
        a, b = pts[0], pts[-1]
        ab = b - a; L = np.linalg.norm(ab)
        if L < 1e-12:
            d = np.linalg.norm(pts - a, axis=1)
        else:
            d = np.linalg.norm(np.cross(pts - a, ab / L), axis=1)
        k = int(d.argmax())
        if d[k] <= tol * diag:
            return np.array([a, b])
        return np.vstack([dp(pts[:k + 1])[:-1], dp(pts[k:])])
    out = []
    for pl in lines:
        pts = P[pl].copy()
        closed = pl[0] == pl[-1] and len(pl) > 3
        for _ in range(smooth):
            if closed:
                body = pts[:-1]
                body = 0.5 * body + 0.25 * (np.roll(body, 1, 0) + np.roll(body, -1, 0))
                pts = np.vstack([body, body[:1]])
            elif len(pts) > 2:
                pts[1:-1] = 0.5 * pts[1:-1] + 0.25 * (pts[:-2] + pts[2:])
        out.append(dp(pts))
    return out


def silhouette(P, I, view_dir, n=None, min_len_frac=2.0):
    """Contorno visto dalla camera. Nell'app va ricalcolato a ogni frame
    (stesso algoritmo: spigoli tra una faccia rivolta verso la camera e una no)."""
    if n is None:
        n = filtered_normals(P, I, 4)
    ue, f0, f1, cnt = edge_table(I)
    s = n @ view_dir
    ok = f1 >= 0
    E = ue[ok & ((s[f0] > 0) != (s[np.maximum(f1, 0)] > 0))]
    if len(E) == 0:
        return E
    L = np.linalg.norm(P[E[:, 0]] - P[E[:, 1]], axis=1)
    used = np.unique(E)
    rm = -np.ones(len(P), np.int64); rm[used] = np.arange(len(used))
    cl = components(len(used), rm[E])[rm[E[:, 0]]]
    diag = np.linalg.norm(P.max(0) - P.min(0))
    return E[np.bincount(cl, L)[cl] >= min_len_frac / 100.0 * diag]


# --------------------------------------------------------------------------- anteprima

def preview(P, I, polys, path, yaw=-35, pitch=20, S=900, with_sil=True):
    try:
        from PIL import Image, ImageDraw, ImageFilter
    except ImportError:
        print('  (Pillow non installato: niente anteprima)')
        return
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rx = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    R = Rx @ Ry
    V = P @ R.T                      # camera guarda verso -Z
    view = R.T @ np.array([0, 0, 1.0])
    ctr = (V.max(0) + V.min(0)) / 2
    sc = S * 0.8 / max((V.max(0) - V.min(0))[:2].max(), 1e-9)
    uv = np.c_[(V[:, 0] - ctr[0]) * sc + S / 2, S / 2 - (V[:, 1] - ctr[1]) * sc]
    z = V[:, 2]
    # z-buffer + riempimento con effetto Fresnel (piu' chiaro ai bordi)
    n, _ = face_normals(P, I)
    fres = 1 - np.abs(n @ view)
    zb = np.full((S, S), -1e9); fill = np.zeros((S, S))
    A, B, C = I[:, 0], I[:, 1], I[:, 2]
    for w in ((1/3, 1/3, 1/3), (.7, .15, .15), (.15, .7, .15), (.15, .15, .7), (.45, .45, .1), (.1, .45, .45), (.45, .1, .45)):
        px = uv[A] * w[0] + uv[B] * w[1] + uv[C] * w[2]
        pz = z[A] * w[0] + z[B] * w[1] + z[C] * w[2]
        u, v = px[:, 0].astype(int), px[:, 1].astype(int)
        ok = (u >= 0) & (u < S) & (v >= 0) & (v < S)
        o = np.argsort(pz[ok])
        uu, vv, zz, ff = u[ok][o], v[ok][o], pz[ok][o], fres[ok][o]
        m = zz > zb[vv, uu]
        zb[vv[m], uu[m]] = zz[m]; fill[vv[m], uu[m]] = 0.06 + 0.22 * ff[m] ** 2
    col = np.array([80, 220, 255], float)
    img = np.zeros((S, S, 3)); img[..., :] = [4, 10, 18]
    img += fill[..., None] * col
    base = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    lay = Image.new('RGB', (S, S), (0, 0, 0)); dr = ImageDraw.Draw(lay)
    tol = 0.012 * (V.max(0) - V.min(0)).max()
    def proj(Q):
        W = Q @ R.T
        return np.c_[(W[:, 0] - ctr[0]) * sc + S / 2, S / 2 - (W[:, 1] - ctr[1]) * sc], W[:, 2]
    sil = clean_lines(P, chain(silhouette(P, I, view)), np.linalg.norm(P.max(0) - P.min(0))) if with_sil else []
    for group, bright in ((polys, 1.0), (sil, 0.9)):
        for Q in group:
            q, qz = proj(Q)
            for k in range(len(Q) - 1):
                m = (q[k] + q[k + 1]) / 2
                mi, mj = int(m[1]), int(m[0])
                front = 0 <= mi < S and 0 <= mj < S and (qz[k] + qz[k + 1]) / 2 >= zb[mi, mj] - tol
                c = bright if front else 0.18
                dr.line([tuple(q[k]), tuple(q[k + 1])], fill=tuple(int(x * c) for x in col), width=2 if front else 1)
    glow = lay.filter(ImageFilter.GaussianBlur(4))
    out = np.clip(np.asarray(base, float) + np.asarray(glow, float) * 1.3 + np.asarray(lay, float), 0, 255)
    out[::3] *= 0.85                                   # scanline
    Image.fromarray(out.astype(np.uint8)).save(path)


# --------------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description='Prepara una mesh per l\'ologramma di HoloInput')
    ap.add_argument('input')
    ap.add_argument('-o', '--output')
    ap.add_argument('--align', choices=['auto', 'base', 'stick', 'pad', 'none'], default='auto',
                    help='base/auto = piani dominanti (basi, oggetti squadrati); '
                         'stick = impugnature (asse del connettore, grilletto verso +Z); '
                         'pad = gamepad (pulsanti in alto, bumper verso +Z)')
    ap.add_argument('--up', choices=['1', '2', '3'], default='1',
                    help='con --align auto: quale piano dominante diventa il "sotto" (1 = il piu\' esteso)')
    ap.add_argument('--rot', nargs=3, type=float, metavar=('X', 'Y', 'Z'),
                    help='rotazione extra in gradi, Euler XYZ come nel pannello N di Blender (Z in alto)')
    ap.add_argument('--yaw', type=float, default=0, help='rotazione finale attorno all\'asse verticale (gradi)')
    ap.add_argument('--pivot', default='top',
                    help='top (cima della base) | bottom (piede/connettore dell\'impugnatura) | center | none | x,y,z')
    ap.add_argument('--size', type=float, default=0, help='scala la dimensione maggiore a questo valore (0 = invariata)')
    ap.add_argument('--scale', type=float, default=1.0, help='fattore di scala finale (es. per accordare impugnatura e base)')
    ap.add_argument('--faces', type=int, default=60000, help='oltre questo numero di facce riduce la mesh (ripiego)')
    ap.add_argument('--angle', type=float, default=35, help='angolo minimo (gradi) per considerare uno spigolo "vivo"')
    ap.add_argument('--smooth', type=int, default=4, help='passate di filtro sulle normali contro il rumore (0 = nessuno)')
    ap.add_argument('--region', type=float, default=0.4, help='zone lisce sotto questa %% di superficie sono rumore e vengono assorbite')
    ap.add_argument('--min-len', type=float, default=2.0, help='scarta catene di spigoli piu\' corte di questa %% della diagonale')
    ap.add_argument('--min-part', type=float, default=0.02, help='scarta pezzi staccati sotto questa frazione di superficie')
    ap.add_argument('--largest', action='store_true', help='tiene solo il pezzo principale (es. toglie il morsetto da tavolo)')
    ap.add_argument('--no-preview', action='store_true')
    a = ap.parse_args()

    root, ext = os.path.splitext(a.input)
    out = a.output or root + '_holo.obj'
    print('Lettura', a.input)
    P, I = load_glb(a.input) if ext.lower() in ('.glb',) else load_obj(a.input)
    print('  %d vertici, %d triangoli' % (len(P), len(I)))

    diag = np.linalg.norm(P.max(0) - P.min(0))
    P, I = weld(P, I, diag * 1e-6)
    P, I, nd = drop_small(P, I, 0.5 if a.largest else a.min_part)
    if nd:
        print('  rimossi %d pezzi staccati piccoli' % nd)
    if len(I) > a.faces:
        P, I = cluster_decimate(P, I, a.faces // 2)
        print('  ridotta a %d triangoli (meglio farlo con DecimateMesh in ComfyUI)' % len(I))

    # orientamento: tutto nel sistema Y in alto
    R = np.eye(3)
    if a.align in ('auto', 'base'):
        print('Allineamento automatico (base)')
        R = auto_align(P, I, a.up)
    elif a.align == 'stick':
        print('Allineamento automatico (impugnatura)')
        R = stick_align(P, I)
    elif a.align == 'pad':
        print('Allineamento automatico (gamepad)')
        R = pad_align(P, I)
    P = P @ R.T
    if a.rot:
        Rb = rot_xyz_deg(*a.rot)
        P = P @ (Y2B.T @ Rb @ Y2B).T
    if a.yaw:
        c, s = math.cos(math.radians(a.yaw)), math.sin(math.radians(a.yaw))
        P = P @ np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]]).T

    # pivot
    lo, hi = P.min(0), P.max(0)
    if a.pivot == 'top':
        h = hi[1] - lo[1]
        tip = P[P[:, 1] > hi[1] - 0.03 * h]
        piv = np.array([tip[:, 0].mean(), hi[1], tip[:, 2].mean()])
    elif a.pivot == 'center':
        piv = (lo + hi) / 2
    elif a.pivot == 'bottom':
        h = hi[1] - lo[1]
        foot = P[P[:, 1] < lo[1] + 0.03 * h]
        piv = np.array([foot[:, 0].mean(), lo[1], foot[:, 2].mean()])
    elif a.pivot == 'none':
        piv = np.zeros(3)
    else:
        piv = np.array([float(t) for t in a.pivot.split(',')])
    P = P - piv
    if a.size > 0:
        P *= a.size / (P.max(0) - P.min(0)).max()
    P *= a.scale

    E = feature_edges(P, I, a.angle, a.min_len, a.smooth, a.region)
    diag = np.linalg.norm(P.max(0) - P.min(0))
    lines = clean_lines(P, chain(E), diag)
    nseg = sum(len(q) - 1 for q in lines)
    dims = P.max(0) - P.min(0)
    print('Linee ologramma: %d polilinee, %d segmenti (da %d spigoli, angolo %.0f gradi)' % (len(lines), nseg, len(E), a.angle))
    print('Dimensioni (X, Y su, Z): %.4f  %.4f  %.4f   pivot spostato di %s' % (*dims, np.round(-piv, 4)))

    with open(out, 'w', encoding='utf-8') as f:
        f.write('# HoloInput - mesh per ologramma\n# Y in alto, pivot in 0,0,0\n')
        f.write('# dimensioni %.5f %.5f %.5f\n' % tuple(dims))
        f.write('o holo_fill\n')
        f.writelines('v %.6f %.6f %.6f\n' % tuple(p) for p in P)
        f.writelines('f %d %d %d\n' % tuple(t + 1) for t in I)
        f.write('o holo_lines\n')
        base = len(P) + 1
        for q in lines:
            f.writelines('v %.6f %.6f %.6f\n' % tuple(p) for p in q)
            f.write('l ' + ' '.join(str(base + k) for k in range(len(q))) + '\n')
            base += len(q)
    print('Scritto', out)
    if not a.no_preview:
        png = os.path.splitext(out)[0] + '.png'
        preview(P, I, lines, png)
        if os.path.exists(png):
            print('Anteprima', png)


if __name__ == '__main__':
    main()

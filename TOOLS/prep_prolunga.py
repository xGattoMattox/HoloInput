#!/usr/bin/env python3
"""
prep_prolunga.py - prepara una prolunga (es. Flightstick Z-Extension) per HoloInput.

Trova sul modello grezzo (TRELLIS/Pixal3D) i due collari:
  - inferiore: si innesta sulla torretta della base (faccia piana in basso);
  - superiore: dove si monta l'impugnatura (faccia piana nella zona piu'
    lontana dal collare inferiore).
Raddrizza il pezzo (asse del collare inferiore in verticale, pivot al centro
della sua faccia), lo orienta in orizzontale (--yaw: direzione del braccio,
gradi dietro la sinistra del pilota per il joystick sinistro), lo scala
(--scale) e scrive <nome>_up.obj, da passare poi a holo_prep.py:

  python prep_prolunga.py zaxis.obj --yaw 30 --scale 0.456
  python holo_prep.py zaxis_up.obj -o zaxis_holo.obj --align none --pivot none --scale 0.456 --angle 30 --region 0.2 --min-len 1.5

Stampa infine le righe Punto=/Asse= per <nome>_holo.ini (coordinate Blender).
--collar: profondita' del collare superiore (distanza tra la faccia trovata e
la faccia dove si innesta l'impugnatura, in unita' del modello grezzo).
"""
import argparse, math, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import holo_prep as hp


def dominant(n, a, mask):
    """normale piu' frequente (per area) nella zona: la faccia piana del collare"""
    N, w = n[mask], a[mask]
    best = None
    for k in range(0, len(N), max(1, len(N) // 800)):
        sc = w[N @ N[k] > 0.985].sum()
        if best is None or sc > best[0]:
            best = (sc, N[k])
    nn = best[1]
    for _ in range(3):
        s = N @ nn > 0.97
        nn = (N[s] * w[s, None]).sum(0); nn /= np.linalg.norm(nn)
    return nn


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('input')
    ap.add_argument('--yaw', type=float, default=30)
    ap.add_argument('--scale', type=float, default=0.456)
    ap.add_argument('--collar', type=float, default=0.355)
    a = ap.parse_args()
    P, I = hp.load_obj(a.input)
    P, I = hp.weld(P, I, 1e-6)
    n = hp.filtered_normals(P, I, 4); _, area = hp.face_normals(P, I)
    C = P[I].mean(1)
    lo, hi = P.min(0), P.max(0); h = hi[1] - lo[1]
    bot = C[:, 1] < lo[1] + 0.18 * h
    nb = dominant(n, area, bot)
    cap = bot & (n @ nb > 0.97); cb = (C[cap] * area[cap, None]).sum(0) / area[cap].sum()
    d = np.linalg.norm(C - C[bot].mean(0), axis=1); top = d > d.max() - 0.25 * h
    nt = dominant(n, area, top)
    capt = top & (n @ nt > 0.97); ct = (C[capt] * area[capt, None]).sum(0) / area[capt].sum()
    ub, A = -nb, -nt
    Mraw = ct + a.collar * A
    hz = (Mraw - cb) - ((Mraw - cb) @ ub) * ub; hz /= np.linalg.norm(hz)
    T = np.array([math.cos(math.radians(a.yaw)), 0, -math.sin(math.radians(a.yaw))])
    Y = np.array([0, 1.0, 0])
    R = np.c_[T, Y, np.cross(T, Y)] @ np.c_[hz, ub, np.cross(hz, ub)].T
    out = os.path.splitext(a.input)[0] + '_up.obj'
    with open(out, 'w') as f, open(a.input) as src:
        for l in src:
            if l.startswith('v '):
                q = R @ (np.array([float(x) for x in l.split()[1:4]]) - cb)
                f.write('v %.6f %.6f %.6f\n' % tuple(q))
            else:
                f.write(l)
    M = R @ (Mraw - cb) * a.scale; Ax = R @ A
    print('Scritto', out)
    print('Angolo tra i collari: %.1f gradi' % math.degrees(math.acos(np.clip(ub @ A, -1, 1))))
    print('Per <nome>_holo.ini, sezione [Montaggio]:')
    print('Punto=%.4f;%.4f;%.4f' % (M[0], -M[2], M[1]))
    print('Asse=%.4f;%.4f;%.4f' % (Ax[0], -Ax[2], Ax[1]))


if __name__ == '__main__':
    main()

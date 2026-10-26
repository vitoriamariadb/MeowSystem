#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
import tempfile

import numpy as np

RES = 256
ESCALA = 48.0 / RES


def rasterizar(caminho: str, res: int = RES) -> np.ndarray:
    ext = os.path.splitext(caminho)[1].lower()
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        png = tmp.name
    try:
        if ext == ".svg":
            subprocess.run(
                ["rsvg-convert", "-w", str(res), "-h", str(res), caminho, "-o", png],
                check=True, capture_output=True)
        else:
            subprocess.run(
                ["convert", caminho, "-background", "none", "-filter", "Lanczos",
                 "-resize", f"{res}x{res}!", png],
                check=True, capture_output=True)
        cru = subprocess.run(["convert", png, "-depth", "8", "RGBA:-"],
                             check=True, capture_output=True).stdout
        return np.frombuffer(cru, np.uint8).reshape(res, res, 4).copy()
    finally:
        os.unlink(png)


def _luma(rgb: np.ndarray) -> np.ndarray:
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def _funde(centros: np.ndarray, dist: float) -> np.ndarray:
    pai = list(range(len(centros)))

    def raiz(i):
        while pai[i] != i:
            pai[i] = pai[pai[i]]
            i = pai[i]
        return i

    for i in range(len(centros)):
        for j in range(i + 1, len(centros)):
            if np.linalg.norm(centros[i] - centros[j]) < dist:
                pai[raiz(i)] = raiz(j)
    grupos = {}
    for i in range(len(centros)):
        grupos.setdefault(raiz(i), []).append(i)
    return np.stack([centros[g].mean(0) for g in grupos.values()]).astype(np.float32)


def quantizar(rgba: np.ndarray, k: int, funde: float) -> tuple[np.ndarray, np.ndarray]:
    fundo = rgba[..., 3] < 128
    rgb = rgba[..., :3].astype(np.float32)
    amostra = rgb[~fundo]
    if amostra.size == 0:
        return np.zeros(rgba.shape[:2], np.int16), np.zeros((1, 3), np.float32)

    chave = (amostra[:, 0].astype(np.int32) << 16
             | amostra[:, 1].astype(np.int32) << 8
             | amostra[:, 2].astype(np.int32))
    vals, cont = np.unique(chave, return_counts=True)
    ordem = np.argsort(-cont, kind="stable")
    topo = vals[ordem[:k]]
    cobertura = cont[ordem[:k]].sum() / len(chave)

    if cobertura >= 0.60:
        centros = np.stack([[(v >> 16) & 255, (v >> 8) & 255, v & 255]
                            for v in topo]).astype(np.float32)
    else:
        lum = _luma(amostra)
        qs = np.linspace(0, 100, k + 2)[1:-1]
        centros = np.stack([amostra[np.argmin(np.abs(lum - np.percentile(lum, q)))]
                            for q in qs]).astype(np.float32)
        for _ in range(12):
            d = ((amostra[:, None, :] - centros[None, :, :]) ** 2).sum(-1)
            atr = d.argmin(1)
            novos = np.array([amostra[atr == i].mean(0) if (atr == i).any() else centros[i]
                              for i in range(len(centros))], np.float32)
            if np.allclose(novos, centros, atol=0.5):
                centros = novos
                break
            centros = novos

    centros = _funde(centros, funde)

    if len(centros) > 2:
        manter = []
        for i, c in enumerate(centros):
            mistura = False
            for a in range(len(centros)):
                for b in range(a + 1, len(centros)):
                    if i in (a, b):
                        continue
                    p, q = centros[a], centros[b]
                    v = q - p
                    ln = float(v @ v)
                    if ln == 0:
                        continue
                    t = float((c - p) @ v) / ln
                    if not (0.15 < t < 0.85):
                        continue
                    if np.linalg.norm(c - (p + t * v)) < 26.0:
                        mistura = True
                        break
                if mistura:
                    break
            if not mistura:
                manter.append(i)
        if manter:
            centros = centros[manter]

    d = ((rgb[..., None, :] - centros[None, None, :, :]) ** 2).sum(-1)
    rot = d.argmin(-1).astype(np.int16) + 1
    rot[fundo] = 0
    return rot, centros


LIMIAR_FRACA = 70.0


def fundir_fracas(rot: np.ndarray, cores: np.ndarray, n: int, limiar: float):
    if limiar <= 0:
        return rot, []

    vizinhos = set()
    for a, b in ((rot[:-1, :], rot[1:, :]), (rot[:, :-1], rot[:, 1:])):
        d = a != b
        if not d.any():
            continue
        par = np.unique(np.stack([a[d], b[d]]), axis=1)
        for i in range(par.shape[1]):
            u, v = int(par[0, i]), int(par[1, i])
            if u and v:
                vizinhos.add((min(u, v), max(u, v)))

    pai = list(range(n))

    def raiz(i):
        while pai[i] != i:
            pai[i] = pai[pai[i]]
            i = pai[i]
        return i

    fundidas = []
    for u, v in sorted(vizinhos):
        d = float(np.linalg.norm(cores[u - 1] - cores[v - 1]))
        if d >= limiar:
            continue
        fundidas.append((u, v, round(d, 1)))
        ru, rv = raiz(u), raiz(v)
        if ru != rv:
            pai[max(ru, rv)] = min(ru, rv)
    if not fundidas:
        return rot, []
    tab = np.array([raiz(i) for i in range(n)], np.int16)
    return tab[rot], fundidas


def moda2d(rot: np.ndarray, w: int, nclasses: int) -> np.ndarray:
    if w <= 1:
        return rot
    r = w // 2
    h, wd = rot.shape
    melhor = np.zeros((h, wd), np.int32)
    conta = np.full((h, wd), -1, np.int32)
    for c in range(nclasses):
        m = (rot == c).astype(np.int32)
        ii = np.zeros((h + 1, wd + 1), np.int32)
        ii[1:, 1:] = m.cumsum(0).cumsum(1)
        y0 = np.clip(np.arange(h) - r, 0, h)[:, None]
        y1 = np.clip(np.arange(h) + r + 1, 0, h)[:, None]
        x0 = np.clip(np.arange(wd) - r, 0, wd)[None, :]
        x1 = np.clip(np.arange(wd) + r + 1, 0, wd)[None, :]
        s = ii[y1, x1] - ii[y0, x1] - ii[y1, x0] + ii[y0, x0]
        troca = s > conta
        melhor = np.where(troca, c, melhor)
        conta = np.where(troca, s, conta)
    return melhor.astype(np.int16)


def _dilata(m: np.ndarray, r: int) -> np.ndarray:
    d = m.copy()
    for _ in range(r):
        e = d.copy()
        e[1:, :] |= d[:-1, :]
        e[:-1, :] |= d[1:, :]
        e[:, 1:] |= d[:, :-1]
        e[:, :-1] |= d[:, 1:]
        d = e
    return d


def componentes(rot: np.ndarray) -> np.ndarray:
    h, w = rot.shape
    lab = np.full((h, w), -1, np.int32)
    pai = []

    def raiz(i):
        while pai[i] != i:
            pai[i] = pai[pai[i]]
            i = pai[i]
        return i

    rl = rot.tolist()
    ll = [[-1] * w for _ in range(h)]
    for y in range(h):
        linha, ant = rl[y], (ll[y - 1] if y else None)
        cur = ll[y]
        for x in range(w):
            v = linha[x]
            e = cur[x - 1] if x and rl[y][x - 1] == v else -1
            c = ant[x] if y and rl[y - 1][x] == v else -1
            if e < 0 and c < 0:
                pai.append(len(pai))
                cur[x] = len(pai) - 1
            elif e < 0 or c < 0:
                cur[x] = e if c < 0 else c
            else:
                re_, rc = raiz(e), raiz(c)
                if re_ != rc:
                    pai[re_] = rc
                cur[x] = rc
        ll[y] = cur
    lab = np.array(ll, np.int32)
    tab = np.array([raiz(i) for i in range(len(pai))], np.int32)
    return tab[lab]


def colapsar_fitas(rot: np.ndarray, n: int, limiar48: float, res: int,
                   envolve: float = 0.55):
    limiar = limiar48 * res / 48.0
    comp = componentes(rot)
    ids = [c for c in np.unique(comp) if c >= 0]

    finos = []
    for cid in ids:
        m = comp == cid
        area = int(m.sum())
        per = int((m[:, :-1] != m[:, 1:]).sum() + (m[:-1, :] != m[1:, :]).sum())
        per += int(m[0].sum() + m[-1].sum() + m[:, 0].sum() + m[:, -1].sum())
        if per and area / per < limiar and int(rot[m][0]) != 0:
            finos.append(cid)
    if not finos:
        return rot, []

    borda = {}
    for eixo in (0, 1):
        a = comp[:-1, :] if eixo == 0 else comp[:, :-1]
        b = comp[1:, :] if eixo == 0 else comp[:, 1:]
        dif = a != b
        par = np.stack([a[dif], b[dif]])
        chaves, cont = np.unique(par, axis=1, return_counts=True)
        for i in range(chaves.shape[1]):
            u, v = int(chaves[0, i]), int(chaves[1, i])
            borda[(u, v)] = borda.get((u, v), 0) + int(cont[i])
            borda[(v, u)] = borda.get((v, u), 0) + int(cont[i])
    perim = {}
    for (u, _), c in borda.items():
        perim[u] = perim.get(u, 0) + c
    classe = {}
    for cid in ids:
        m = comp == cid
        classe[cid] = int(rot[m][0])

    envolvidos = {}
    for c in finos:
        for b in ids:
            if b != c and b not in finos and classe[b] != 0 and \
                    borda.get((c, b), 0) >= envolve * perim.get(b, 1):
                envolvidos.setdefault(c, []).append(b)
    if not envolvidos:
        return rot, []
    alvo = list(envolvidos)
    fitas = sorted({int(rot[comp == c][0]) for c in alvo})

    r = max(1, int(round(limiar)))
    dentro = np.isin(comp, sum(envolvidos.values(), []))
    fora = ~(dentro | np.isin(comp, alvo))
    livre = np.isin(comp, alvo) & _dilata(fora, r)
    if not livre.any():
        return rot, []
    saida = np.where(livre, -1, rot).astype(np.int16)
    for _ in range(int(limiar * 2) + 4):
        pend = saida == -1
        if not pend.any():
            break
        votos = np.zeros((n,) + saida.shape, np.int16)
        for eixo, desl in ((0, 1), (0, -1), (1, 1), (1, -1)):
            viz = np.roll(saida, desl, axis=eixo)
            if eixo == 0:
                if desl == 1:
                    viz[0] = -1
                else:
                    viz[-1] = -1
            else:
                if desl == 1:
                    viz[:, 0] = -1
                else:
                    viz[:, -1] = -1
            ok = viz >= 0
            votos[np.clip(viz, 0, n - 1), np.arange(saida.shape[0])[:, None],
                  np.arange(saida.shape[1])[None, :]] += ok
        melhor = votos.argmax(0).astype(np.int16)
        tem = votos.max(0) > 0
        saida = np.where(pend & tem, melhor, saida)
    saida[saida == -1] = 0
    return saida, fitas


def segmentos(mask: np.ndarray):
    h, w = mask.shape
    m = np.zeros((h + 2, w + 2), bool)
    m[1:-1, 1:-1] = mask
    ys, xs = np.nonzero(m)
    lim_x, lim_y = w + 1, h + 1

    def moldura(a, b):
        return ((a[0] == b[0] == 1) or (a[0] == b[0] == lim_x)
                or (a[1] == b[1] == 1) or (a[1] == b[1] == lim_y))

    segs = []
    for y, x in zip(ys, xs):
        cand = []
        if not m[y - 1, x]:
            cand.append(((x, y), (x + 1, y)))
        if not m[y, x + 1]:
            cand.append(((x + 1, y), (x + 1, y + 1)))
        if not m[y + 1, x]:
            cand.append(((x + 1, y + 1), (x, y + 1)))
        if not m[y, x - 1]:
            cand.append(((x, y + 1), (x, y)))
        segs.extend(s for s in cand if not moldura(*s))
    return segs


def encadear(segs):
    saindo = {}
    for a, b in segs:
        saindo.setdefault(a, []).append(b)
    linhas = []
    entrando = {}
    for a, b in segs:
        entrando[b] = entrando.get(b, 0) + 1
    partidas = [v for v in saindo if len(saindo[v]) > entrando.get(v, 0)]
    partidas += list(saindo.keys())
    for p in partidas:
        while saindo.get(p):
            linha = [p]
            atual = p
            while saindo.get(atual):
                prox = saindo[atual].pop()
                if not saindo[atual]:
                    del saindo[atual]
                linha.append(prox)
                atual = prox
                if atual == p:
                    break
            if len(linha) > 2:
                linhas.append(linha)
    return linhas


def _dp_guarda(pts, tol):
    n = len(pts)
    if n < 3:
        return [True] * n
    guarda = [False] * n
    guarda[0] = guarda[-1] = True
    pilha = [(0, n - 1)]
    while pilha:
        i, j = pilha.pop()
        if j <= i + 1:
            continue
        ax, ay = pts[i]
        bx, by = pts[j]
        dx, dy = bx - ax, by - ay
        norma = math.hypot(dx, dy)
        pior, iw = -1.0, -1
        for k in range(i + 1, j):
            px, py = pts[k]
            if norma == 0:
                d = math.hypot(px - ax, py - ay)
            else:
                d = abs(dy * px - dx * py + bx * ay - by * ax) / norma
            if d > pior:
                pior, iw = d, k
        if pior > tol:
            guarda[iw] = True
            pilha.append((i, iw))
            pilha.append((iw, j))
    return guarda


def dp(pts, tol):
    if len(pts) < 3:
        return pts
    return [p for p, g in zip(pts, _dp_guarda(pts, tol)) if g]


def comprimento(pts):
    return sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


TOL_CURVAS = 1.0
TOL_POLILINHA = 1.6
JANELA_ALISAR = 5
TOL_RETA = 0.5
MIN_RETA = 16.0


def alisar(pts, fechada: bool, w: int = 5) -> np.ndarray:
    p = np.asarray(pts, np.float64)
    if fechada and len(p) > 1 and np.allclose(p[0], p[-1]):
        p = p[:-1]
    n = len(p)
    if n < w:
        return np.vstack([p, p[:1]]) if fechada and n else p
    r = w // 2
    if fechada:
        idx = (np.arange(n)[:, None] + np.arange(-r, r + 1)[None, :]) % n
        s = p[idx].mean(1)
        return np.vstack([s, s[:1]])
    s = p.copy()
    acum = np.vstack([np.zeros((1, 2)), np.cumsum(p, 0)])
    for i in range(1, n - 1):
        a, b = max(0, i - r), min(n, i + r + 1)
        s[i] = (acum[b] - acum[a]) / (b - a)
    return s


def cantos(p: np.ndarray, fechada: bool, limiar: float = 60.0,
           passo: int = 3) -> list[int]:
    if fechada and len(p) > 1 and np.allclose(p[0], p[-1]):
        p = p[:-1]
    n = len(p)
    if n < 2 * passo + 1:
        return []
    i = np.arange(n)
    if fechada:
        atras, frente = p[(i - passo) % n], p[(i + passo) % n]
    else:
        atras, frente = p[np.clip(i - passo, 0, n - 1)], p[np.clip(i + passo, 0, n - 1)]
    v1, v2 = p - atras, frente - p
    n1, n2 = np.linalg.norm(v1, axis=1), np.linalg.norm(v2, axis=1)
    ok = (n1 > 0) & (n2 > 0)
    cos = np.ones(n)
    cos[ok] = (v1[ok] * v2[ok]).sum(1) / (n1[ok] * n2[ok])
    ang = np.degrees(np.arccos(np.clip(cos, -1.0, 1.0)))
    achados = []
    for k in np.nonzero(ang > limiar)[0]:
        k = int(k)
        if achados and k - achados[-1] <= passo:
            if ang[k] > ang[achados[-1]]:
                achados[-1] = k
        else:
            achados.append(k)
    if fechada and len(achados) > 1 and achados[0] + n - achados[-1] <= passo:
        if ang[achados[0]] >= ang[achados[-1]]:
            achados.pop()
        else:
            achados.pop(0)
    if not fechada:
        achados = [k for k in achados if 0 < k < n - 1]
    return achados


def partir(p: np.ndarray, idx: list[int], fechada: bool) -> list[np.ndarray]:
    if fechada:
        if len(p) > 1 and np.allclose(p[0], p[-1]):
            p = p[:-1]
        n = len(p)
        if n < 2:
            return []
        idx = sorted({int(k) % n for k in idx})
        if not idx:
            c = p.mean(0)
            k = int(np.linalg.norm(p - c, axis=1).argmax())
            rodado = np.roll(p, -k, axis=0)
            return [np.vstack([rodado, rodado[:1]])]
        rodado = np.roll(p, -idx[0], axis=0)
        cortes = [(k - idx[0]) % n for k in idx] + [n]
        return [np.vstack([rodado[a:b], rodado[b % n:b % n + 1]])
                for a, b in zip(cortes, cortes[1:])]
    cortes = [0] + sorted({int(k) for k in idx}) + [len(p) - 1]
    return [p[a:b + 1] for a, b in zip(cortes, cortes[1:]) if b > a]


def fatiar(p: np.ndarray, tol_reta: float = None, min_reta: float = None):
    tol_reta = TOL_RETA if tol_reta is None else tol_reta
    min_reta = MIN_RETA if min_reta is None else min_reta
    n = len(p)
    if n < 3:
        return [(0, n - 1, False)] if n == 2 else []
    marcos = [i for i, g in enumerate(_dp_guarda([tuple(q) for q in p], tol_reta)) if g]
    retas = [(a, b) for a, b in zip(marcos, marcos[1:])
             if float(np.linalg.norm(p[b] - p[a])) >= min_reta]
    if not retas:
        return [(0, n - 1, False)]
    fatias, pos = [], 0
    for a, b in retas:
        if a > pos:
            fatias.append((pos, a, False))
        fatias.append((a, b, True))
        pos = b
    if pos < n - 1:
        fatias.append((pos, n - 1, False))
    return fatias


def _bezier(ctrl: np.ndarray, t) -> np.ndarray:
    t = np.asarray(t, np.float64)[:, None]
    u = 1.0 - t
    return ((u ** 3) * ctrl[0] + 3 * (u ** 2) * t * ctrl[1]
            + 3 * u * (t ** 2) * ctrl[2] + (t ** 3) * ctrl[3])


def _param_corda(p: np.ndarray) -> np.ndarray:
    d = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))])
    return d / d[-1] if d[-1] > 0 else np.linspace(0.0, 1.0, len(p))


def _gerar(p: np.ndarray, u: np.ndarray, t1: np.ndarray, t2: np.ndarray) -> np.ndarray:
    b0, b1 = (1 - u) ** 3, 3 * u * (1 - u) ** 2
    b2, b3 = 3 * u * u * (1 - u), u ** 3
    A1, A2 = t1[None, :] * b1[:, None], t2[None, :] * b2[:, None]
    C11, C12, C22 = (A1 * A1).sum(), (A1 * A2).sum(), (A2 * A2).sum()
    resto = p - (b0 + b1)[:, None] * p[0] - (b2 + b3)[:, None] * p[-1]
    X1, X2 = (A1 * resto).sum(), (A2 * resto).sum()
    det = C11 * C22 - C12 * C12
    a1 = (X1 * C22 - X2 * C12) / det if abs(det) > 1e-12 else 0.0
    a2 = (C11 * X2 - C12 * X1) / det if abs(det) > 1e-12 else 0.0
    corda = float(np.linalg.norm(p[-1] - p[0]))
    if a1 < 1e-6 * corda or a2 < 1e-6 * corda:
        a1 = a2 = corda / 3.0
    return np.array([p[0], p[0] + t1 * a1, p[-1] + t2 * a2, p[-1]])


def _reparametrizar(p: np.ndarray, u: np.ndarray, ctrl: np.ndarray) -> np.ndarray:
    q1 = 3.0 * (ctrl[1:] - ctrl[:-1])
    q2 = 2.0 * (q1[1:] - q1[:-1])
    t = u[:, None]
    v = 1.0 - t
    Q = _bezier(ctrl, u)
    Q1 = (v ** 2) * q1[0] + 2 * v * t * q1[1] + (t ** 2) * q1[2]
    Q2 = v * q2[0] + t * q2[1]
    num = ((Q - p) * Q1).sum(1)
    den = (Q1 * Q1).sum(1) + ((Q - p) * Q2).sum(1)
    seguro = np.where(np.abs(den) > 1e-12, den, 1.0)
    novo = np.where(np.abs(den) > 1e-12, u - num / seguro, u)
    return np.clip(novo, 0.0, 1.0)


def _erro(p: np.ndarray, u: np.ndarray, ctrl: np.ndarray) -> tuple[float, int]:
    d = np.linalg.norm(_bezier(ctrl, u) - p, axis=1)
    i = int(d.argmax())
    return float(d[i]), i


def ajustar(p: np.ndarray, tol: float, t1=None, t2=None, prof: int = 0,
            prof_max: int = 10):
    n = len(p)
    if n < 2:
        return None
    if t1 is None:
        t1 = p[1] - p[0]
        t1 = t1 / (np.linalg.norm(t1) or 1.0)
    if t2 is None:
        t2 = p[-2] - p[-1]
        t2 = t2 / (np.linalg.norm(t2) or 1.0)
    if n == 2:
        d = np.linalg.norm(p[1] - p[0]) / 3.0
        return [np.array([p[0], p[0] + t1 * d, p[1] + t2 * d, p[1]])]
    u = _param_corda(p)
    ctrl = _gerar(p, u, t1, t2)
    err, i = _erro(p, u, ctrl)
    if err < tol:
        return [ctrl]
    if err < tol * 4:
        for _ in range(4):
            u = _reparametrizar(p, u, ctrl)
            ctrl = _gerar(p, u, t1, t2)
            err, i = _erro(p, u, ctrl)
            if err < tol:
                return [ctrl]
    if prof >= prof_max or i <= 0 or i >= n - 1:
        return None
    tc = p[i - 1] - p[i + 1]
    tc = tc / (np.linalg.norm(tc) or 1.0)
    esq = ajustar(p[:i + 1], tol, t1, tc, prof + 1, prof_max)
    dire = ajustar(p[i:], tol, -tc, t2, prof + 1, prof_max)
    if esq is None or dire is None:
        return None
    return esq + dire


def area_cheia(rot: np.ndarray, n: int):
    if n < 3:
        return None
    opaco = int((rot != 0).sum())
    if not opaco:
        return None
    borda0 = np.zeros(n, np.int64)
    for a, b in ((rot[:-1, :], rot[1:, :]), (rot[:, :-1], rot[:, 1:])):
        d = a != b
        for x, y in ((a[d], b[d]), (b[d], a[d])):
            m = (y == 0)
            np.add.at(borda0, x[m].astype(np.intp), 1)
    borda0[0] = -1
    corpo = int(borda0.argmax())
    areas = np.bincount(rot.ravel().astype(np.intp), minlength=n).astype(np.int64)
    areas[0] = 0
    areas[corpo] = 0
    cand = int(areas.argmax())
    if areas[cand] < 0.02 * opaco:
        return None
    return rot == cand


def emitir(linhas, esc: float) -> str:
    partes = []
    for fechar, trechos, cheia in linhas:
        primeiro = trechos[0][1][0]
        primeiro = primeiro[0] if trechos[0][0] == "C" else primeiro
        d = [f"M{primeiro[0] * esc:.2f} {primeiro[1] * esc:.2f}"]
        for tipo, dados in trechos:
            if tipo == "C":
                for c in dados:
                    d.append("C" + " ".join(f"{q[0] * esc:.2f} {q[1] * esc:.2f}"
                                            for q in c[1:]))
            else:
                pares = " ".join(f"{q[0] * esc:.2f} {q[1] * esc:.2f}" for q in dados[1:])
                if pares:
                    d.append(pares if len(d) == 1 else "L" + pares)
        if fechar:
            d.append("Z")
        atrib = ' fill="currentColor"' if cheia else ""
        partes.append(f'<path{atrib} d="{" ".join(d)}"/>')
    return "".join(partes)


def converter(entrada, k=6, moda=3, funde=46.0, tol=None, min_traco=3.2,
              fita=2.2, envolve=0.55, res=RES, curvas=True, cheia=False,
              limiar_canto=60.0, passo_canto=3, peso=0.0):
    if tol is None:
        tol = TOL_CURVAS if curvas else TOL_POLILINHA
    rgba = rasterizar(entrada, res)
    rot, cores = quantizar(rgba, k, funde)
    n = int(rot.max()) + 1
    rot = moda2d(rot, moda, n)
    rot, fitas = colapsar_fitas(rot, n, fita, res, envolve)
    rot, fundidas = fundir_fracas(rot, cores, n, peso)

    esc = 48.0 / (res + 2)
    tol_dp = TOL_POLILINHA if curvas else tol

    linhas, caidos, ncantos, ncurvas, nretas = [], 0, 0, 0, 0
    mascara_cheia = None

    def tracar(pontos, fechada, com_cheia=False, s=None):
        nonlocal caidos, ncantos, ncurvas, nretas
        if not curvas:
            if s is None:
                s = dp(pontos, tol)
                if fechada and len(s) > 2 and s[0] != s[-1]:
                    s.append(s[0])
            if len(s) < 2:
                return None
            return (False, [("L", np.asarray(s, np.float64))], com_cheia)
        cru = np.asarray(pontos, np.float64)
        idx = cantos(cru, fechada, limiar_canto, passo_canto)
        ncantos += len(idx)
        if fechada and not idx:
            pecas = partir(alisar(cru, True, JANELA_ALISAR), [], True)
        else:
            pecas = [alisar(tr, False, JANELA_ALISAR)
                     for tr in partir(cru, idx, fechada)]
        trechos = []
        for tr in pecas:
            if len(tr) < 2:
                continue
            fatias = fatiar(tr)
            for a, b, reto in fatias:
                if b <= a:
                    continue
                if reto:
                    nretas += 1
                    trechos.append(("L", tr[[a, b]]))
                    continue
                sub = tr[a:b + 1]
                if fechada and not idx and len(fatias) == 1:
                    t = sub[1] - sub[-2]
                    t = t / (np.linalg.norm(t) or 1.0)
                    c = ajustar(sub, tol, t1=t, t2=-t)
                else:
                    c = ajustar(sub, tol)
                if c is None:
                    caidos += 1
                    trechos.append(("L", np.asarray(
                        dp([tuple(q) for q in sub], tol_dp), np.float64)))
                else:
                    ncurvas += len(c)
                    trechos.append(("C", c))
        return (fechada, trechos, com_cheia) if trechos else None

    if cheia:
        mascara_cheia = area_cheia(rot, n)
        if mascara_cheia is not None:
            for linha in encadear(segmentos(mascara_cheia)):
                t = tracar(linha, linha[0] == linha[-1], com_cheia=True)
                if t:
                    linhas.append(t)

    vistas = set()
    for c in range(n):
        m = (rot == c)
        if not m.any():
            continue
        segs = []
        for a, b in segmentos(m):
            chave = (a, b) if a <= b else (b, a)
            if chave in vistas:
                continue
            vistas.add(chave)
            segs.append((a, b))
        for linha in encadear(segs):
            fechada = linha[0] == linha[-1]
            s = dp(linha, tol_dp)
            if fechada and len(s) > 2 and s[0] != s[-1]:
                s.append(s[0])
            if len(s) < 2:
                continue
            if comprimento(s) * ESCALA * (RES / res) < min_traco:
                continue
            t = tracar(linha, fechada, s=s)
            if t:
                linhas.append(t)

    corpo = emitir(linhas, esc)
    metricas = {
        "modo": "curvas" if curvas else "polilinha",
        "classes": n,
        "fitas": len(fitas),
        "peso": peso or None,
        "fundidas": len(fundidas),
        "fracas": [{"a": a, "b": b, "contraste": d} for a, b, d in fundidas],
        "linhas": len(linhas),
        "curvas": ncurvas,
        "retas": nretas,
        "cantos": ncantos,
        "caidos": caidos,
        "cheia": True if mascara_cheia is not None else None,
        "pontos": sum(len(c) * 3 if t == "C" else len(c)
                      for _, tr, _ in linhas for t, c in tr),
    }
    return corpo, metricas


def svg(corpo, lw=None):
    largura = f' stroke-width="{lw}"' if lw is not None else ""
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" '
            'viewBox="0 0 48 48"><g fill="none" stroke="currentColor"'
            f'{largura} stroke-linecap="round" stroke-linejoin="round">'
            + corpo + "</g></svg>")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("entrada")
    p.add_argument("saida")
    p.add_argument("--k", type=int, default=6, help="cores na quantização")
    p.add_argument("--moda", type=int, default=3, help="janela do filtro de moda")
    p.add_argument("--funde", type=float, default=46.0, help="distância RGB p/ fundir cores")
    p.add_argument("--envolve", type=float, default=0.55, help="fração do perímetro que faz a fita ser contorno")
    p.add_argument("--fita", type=float, default=2.2, help="meia-espessura (px de 48) abaixo da qual a classe vira traço único")
    p.add_argument("--tol", type=float, default=None,
                   help="curvas: erro máximo do ajuste (px de 256, padrão 1,0); "
                        "polilinha: tolerância Douglas-Peucker (padrão 1,6)")
    p.add_argument("--min-traco", type=float, default=3.2, help="descarta traço menor (px de 48)")
    p.add_argument("--peso-fronteira", dest="peso", type=float, nargs="?",
                   const=LIMIAR_FRACA, default=0.0, metavar="CONTRASTE",
                   help="não desenha fronteira com contraste RGB abaixo deste "
                        f"valor (padrão: desligado; sem número, {LIMIAR_FRACA:.0f})")
    p.add_argument("--lw", type=float, default=None,
                   help="grava stroke-width no arquivo (padrao: NAO grava, "
                        "para o TRACO do icones_apps_arcticons.sh mandar)")
    modo = p.add_mutually_exclusive_group()
    modo.add_argument("--curvas", dest="curvas", action="store_true", default=True,
                      help="(padrão) alisa, acha os cantos e ajusta Bézier")
    modo.add_argument("--polilinha", dest="curvas", action="store_false",
                      help="o traçado anterior a 09/09/2026, byte a byte")
    p.add_argument("--cantos", type=float, default=60.0, metavar="GRAUS",
                   help="virada acima da qual o vértice é canto e não alisa (padrão 60)")
    p.add_argument("--cheia", action="store_true",
                   help='a maior área interna sai com fill="currentColor"')
    p.add_argument("--json", action="store_true",
                   help="imprime as métricas como UMA linha JSON no stdout")
    a = p.parse_args()
    corpo, m = converter(a.entrada, a.k, a.moda, a.funde, a.tol, a.min_traco,
                         a.fita, a.envolve, RES, a.curvas, a.cheia, a.cantos,
                         peso=a.peso)
    with open(a.saida, "w") as f:
        f.write(svg(corpo, a.lw))
    if a.json:
        print(json.dumps(m, ensure_ascii=False))
    if a.curvas:
        frase = (f"{m['classes']} classes ({m['fitas']} fita), "
                 f"{m['linhas']} traços, {m['curvas']} curvas, "
                 f"{m['cantos']} cantos, {m['caidos']} caídos")
    else:
        frase = (f"{m['classes']} classes ({m['fitas']} fita), "
                 f"{m['linhas']} traços, {m['pontos']} pontos")
    if m["fundidas"]:
        pares = ", ".join(f"{d:.0f}" for _, _, d in
                          ((f["a"], f["b"], f["contraste"]) for f in m["fracas"]))
        frase += f", {m['fundidas']} fronteira(s) fraca(s) fundida(s) [{pares}]"
    print(f"{os.path.basename(a.entrada)}: {frase}", file=sys.stderr)


if __name__ == "__main__":
    main()

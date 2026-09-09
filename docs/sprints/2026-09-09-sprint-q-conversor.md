# Sprint Q, materializada — o conversor: curva em vez de escada

Detalhamento da Sprint Q de
[`2026-09-09-heroic-e-oficina.md`](2026-09-09-heroic-e-oficina.md). Este
arquivo é para quem vai **escrever o código**: cada função tem assinatura,
corpo e o número que a valida. Nada aqui foi executado; o que está marcado
como *medido* foi medido em 09/09/2026 sobre o código de hoje.

**Arquivos desta sprint, e só estes:**

| arquivo | o quê |
|---|---|
| `scripts/converter_icone.py` | as funções novas, as chaves `--curvas` / `--polilinha` / `--cheia` / `--json`, e a emissão `M C Z` |
| `scripts/folha_conversor.py` | **novo** — a folha de quatro colunas que ela olha antes de qualquer instalação |
| `tests/conversor.sh` | **novo** — a trava contra a escada voltar |
| `assets/icones/convertidos-apps/retoques/LEIA-ME.txt` | duas frases que envelhecem |
| `docs/SPRINTS.md` | a linha de fechamento, no fim |

`construir_convertidos.sh`, `icones_apps_arcticons.sh` e `app/` **não são
tocados** por esta sprint. A regeneração dos 33 (passo 7) só acontece depois
do "sim" dela, e é uma rodada do construtor que já existe.

---

## 0. O estado de hoje, medido

```
$ time python3 scripts/converter_icone.py /usr/share/icons/Papirus/64x64/apps/org.gimp.GIMP.svg /tmp/gimp.svg
org.gimp.GIMP.svg: 4 classes (0 fita), 6 traços, 94 pontos
0,215 s de relógio (1,17 s de CPU — o numpy usa os núcleos)
```

A saída começa assim (a primeira das seis `<path>`):

```
<path d="M40.19 4.65 39.44 5.21 39.07 6.70 37.58 9.12 32.56 13.40 26.60 16.00 23.63 15.81 21.77 16.74 …"/>
```

Só `M` e pares implícitos: **uma polilinha**. Os 94 pontos são os degraus
que o Douglas–Peucker deixou de uma escada de ~1 800 arestas de pixel. A 48
px com traço de 2,25 a escada lê como tremida; a 200 px, na lupa da oficina,
lê como serra.

O pipeline em `converter()` (linha 614) é:

```
rasterizar → quantizar → moda2d → colapsar_fitas → [por classe] segmentos → encadear → dp → emitir
```

**Esta sprint substitui só o último terço**: entre `encadear()` e a emissão.
Tudo o que vem antes — a quantização, o filtro de moda, o colapso de fitas
(o achado mais importante do conversor, segundo o próprio cabeçalho) e a
deduplicação global de aresta — **fica como está**. É o que garante que a
forma continua a mesma; só a linha que a desenha muda.

---

## 1. As funções novas em `converter_icone.py`

Entram depois de `comprimento()` (linha 608), numa seção nova
`# ------------------------------------------------------------ curvas`. Só
`numpy`, como o resto do arquivo. Todas recebem e devolvem arrays
`float64 (n, 2)` em **coordenadas de canto de pixel na grade de 256**, que é
o que `encadear()` devolve (como listas de tuplas de inteiros).

### 1.1 `alisar(pts, fechada, w=5)` — mata a escada

```python
def alisar(pts, fechada: bool, w: int = 5) -> np.ndarray:
    """Média móvel de janela `w` ao longo da cadeia. Laço fechado: circular.
    Linha aberta: as duas pontas ficam onde estão.

    POR QUE ISTO NÃO DEFORMA: numa escada de degraus de 1 px, a média de 5
    vizinhos fica a menos de 0,5 px da diagonal verdadeira — 0,09 px de 48.
    Numa curva de raio r a janela puxa para dentro ~w²/(8r): com w=5 e o menor
    raio que sobrevive a 48 px (r ≈ 8 px de 256), 0,4 px de 256. Abaixo do
    que o olho vê e abaixo da tolerância do ajuste (1,0).
    """
    p = np.asarray(pts, np.float64)
    n = len(p)
    if n < w:
        return p
    r = w // 2
    if fechada:
        if np.allclose(p[0], p[-1]):
            p, n = p[:-1], n - 1
        idx = (np.arange(n)[:, None] + np.arange(-r, r + 1)[None, :]) % n
        s = p[idx].mean(1)
        return np.vstack([s, s[:1]])          # volta a fechar: último == primeiro
    s = p.copy()
    acum = np.vstack([np.zeros((1, 2)), np.cumsum(p, 0)])
    for i in range(1, n - 1):
        a, b = max(0, i - r), min(n, i + r + 1)
        s[i] = (acum[b] - acum[a]) / (b - a)
    return s
```

### 1.2 `cantos(p, fechada, limiar=60.0, passo=3)` — onde a curva NÃO pode alisar

```python
def cantos(p: np.ndarray, fechada: bool, limiar: float = 60.0, passo: int = 3) -> list[int]:
    """Índices dos vértices onde a direção vira mais que `limiar` graus,
    medida entre o vetor que chega (de `passo` atrás) e o que sai (para
    `passo` à frente). Um canto por vale: numa vizinhança de `passo`, fica o
    de maior ângulo.

    A RÉGUA DOS DOIS NÚMEROS É O `>_` DO TERMINAL E O `B` DO BTOP (ver §5):
    o `>` tem um canto de ~90°, o `B` tem cantos de 90° e curvas de raio
    pequeno. 60° separa os dois com folga: uma curva de raio 8 px medida com
    passo 3 dá ~42° de virada por vértice, e um canto reto dá 90°.
    """
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
    if not fechada:
        achados = [k for k in achados if 0 < k < n - 1]
    return achados
```

### 1.3 `partir(p, idx, fechada)` — a cadeia vira trechos entre cantos

```python
def partir(p: np.ndarray, idx: list[int], fechada: bool) -> list[np.ndarray]:
    """Trechos [canto_i … canto_{i+1}], cada um incluindo as duas pontas.

    LAÇO FECHADO SEM CANTO: um trecho só, começando no ponto mais distante
    do centroide — é onde a curvatura costuma ser menor, e a emenda (§1.4,
    tangente contínua) fica no lugar mais discreto. Começar no p[0] de
    `encadear()` poria a emenda num lugar arbitrário da grade.
    """
    if fechada:
        p = p[:-1]                                   # sem o ponto repetido
        n = len(p)
        if not idx:
            c = p.mean(0)
            k = int(np.linalg.norm(p - c, axis=1).argmax())
            rodado = np.roll(p, -k, axis=0)
            return [np.vstack([rodado, rodado[:1]])]
        idx = sorted(idx)
        rodado = np.roll(p, -idx[0], axis=0)
        cortes = [(k - idx[0]) % n for k in idx] + [n]
        return [np.vstack([rodado[a:b], rodado[b % n:b % n + 1]]) for a, b in zip(cortes, cortes[1:])]
    cortes = [0] + sorted(idx) + [len(p) - 1]
    return [p[a:b + 1] for a, b in zip(cortes, cortes[1:]) if b > a]
```

### 1.4 O ajuste de Bézier — Schneider (Graphics Gems, 1990), em numpy

Seis funções pequenas. Os nomes seguem o artigo para quem for conferir.

```python
def _bezier(ctrl: np.ndarray, t) -> np.ndarray:
    t = np.asarray(t, np.float64)[:, None]
    u = 1.0 - t
    return (u ** 3) * ctrl[0] + 3 * (u ** 2) * t * ctrl[1] + 3 * u * (t ** 2) * ctrl[2] + (t ** 3) * ctrl[3]


def _param_corda(p: np.ndarray) -> np.ndarray:
    d = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))])
    return d / d[-1] if d[-1] > 0 else np.linspace(0.0, 1.0, len(p))


def _gerar(p: np.ndarray, u: np.ndarray, t1: np.ndarray, t2: np.ndarray) -> np.ndarray:
    """Os dois pontos de controle por mínimos quadrados (generateBezier)."""
    b0, b1 = (1 - u) ** 3, 3 * u * (1 - u) ** 2
    b2, b3 = 3 * u * u * (1 - u), u ** 3
    A1, A2 = t1[None, :] * b1[:, None], t2[None, :] * b2[:, None]
    C11, C12, C22 = (A1 * A1).sum(), (A1 * A2).sum(), (A2 * A2).sum()
    resto = p - (b0 + b1)[:, None] * p[0] - (b2 + b3)[:, None] * p[-1]
    X1, X2 = (A1 * resto).sum(), (A2 * resto).sum()
    det = C11 * C22 - C12 * C12
    a1 = (X1 * C22 - X2 * C12) / det if abs(det) > 1e-12 else 0.0
    a2 = (C11 * X2 - C12 * X1) / det if abs(det) > 1e-12 else 0.0
    corda = np.linalg.norm(p[-1] - p[0])
    if a1 < 1e-6 * corda or a2 < 1e-6 * corda:      # degenerado: a heurística de Wu/Barsky
        a1 = a2 = corda / 3.0
    return np.array([p[0], p[0] + t1 * a1, p[-1] + t2 * a2, p[-1]])


def _reparametrizar(p: np.ndarray, u: np.ndarray, ctrl: np.ndarray) -> np.ndarray:
    """Um passo de Newton–Raphson em cada parâmetro."""
    q1 = 3.0 * (ctrl[1:] - ctrl[:-1])
    q2 = 2.0 * (q1[1:] - q1[:-1])
    t = u[:, None]
    v = 1.0 - t
    Q = _bezier(ctrl, u)
    Q1 = (v ** 2) * q1[0] + 2 * v * t * q1[1] + (t ** 2) * q1[2]
    Q2 = v * q2[0] + t * q2[1]
    num = ((Q - p) * Q1).sum(1)
    den = (Q1 * Q1).sum(1) + ((Q - p) * Q2).sum(1)
    novo = np.where(np.abs(den) > 1e-12, u - num / den, u)
    return np.clip(novo, 0.0, 1.0)


def _erro(p: np.ndarray, u: np.ndarray, ctrl: np.ndarray) -> tuple[float, int]:
    d = np.linalg.norm(_bezier(ctrl, u) - p, axis=1)
    i = int(d.argmax())
    return float(d[i]), i


def ajustar(p: np.ndarray, tol: float, t1=None, t2=None, prof: int = 0):
    """Lista de curvas (cada uma `ctrl` 4×2) que cobre `p` com erro < `tol`,
    ou `None` quando o ajuste não converge — e aí o trecho fica polilinha.

    `t1` é a tangente unitária SAINDO de p[0]; `t2` a tangente unitária
    CHEGANDO em p[-1], apontada para trás (convenção do artigo).
    """
    n = len(p)
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
    if err < tol * 4:                       # perto: vale iterar antes de dividir
        for _ in range(4):
            u = _reparametrizar(p, u, ctrl)
            ctrl = _gerar(p, u, t1, t2)
            err, i = _erro(p, u, ctrl)
            if err < tol:
                return [ctrl]
    if prof >= 6 or i <= 0 or i >= n - 1:   # a guarda: não divide para sempre
        return None
    tc = p[i - 1] - p[i + 1]
    tc = tc / (np.linalg.norm(tc) or 1.0)
    esq = ajustar(p[:i + 1], tol, t1, tc, prof + 1)
    dire = ajustar(p[i:], tol, -tc, t2, prof + 1)
    if esq is None or dire is None:
        return None
    return esq + dire
```

**A emenda do laço fechado sem canto** (o círculo do Reprodutor, o disco do
Spotify): `partir()` devolve um trecho `p0 … p0`. Chamar `ajustar()` com as
tangentes automáticas põe um bico em `p0`, porque `t1` olha para `p1` e
`t2` para `p[-2]`, independentes. A chamada certa é com **uma** tangente,
partilhada:

```python
t = p[1] - p[-2]
t = t / (np.linalg.norm(t) or 1.0)
curvas = ajustar(trecho, tol, t1=t, t2=-t)
```

### 1.5 `--cheia` — a maior área interna, cheia

```python
def area_cheia(rot: np.ndarray, n: int):
    """A classe que vira `fill="currentColor"` na variação «Área cheia»,
    ou None. Regra: o CORPO é a classe (≠ fundo) que mais faz fronteira com o
    fundo; a candidata é a maior classe restante, com ao menos 2 % da área
    opaca. Devolve a máscara booleana dela.

    É a variação, não o padrão: 13 dos 39 Arcticons têm uma área cheia
    (`keymapper`, `osmonitor`), e é para esse dialeto que ela existe.
    """
    if n < 3:
        return None
    opaco = int((rot != 0).sum())
    borda0 = np.zeros(n, np.int64)
    for a, b in ((rot[:-1, :], rot[1:, :]), (rot[:, :-1], rot[:, 1:])):
        d = a != b
        for x, y in ((a[d], b[d]), (b[d], a[d])):
            m = (y == 0)
            np.add.at(borda0, x[m], 1)
    borda0[0] = -1
    corpo = int(borda0.argmax())
    areas = np.bincount(rot.ravel(), minlength=n)
    areas[0] = areas[corpo] = 0
    cand = int(areas.argmax())
    if areas[cand] < 0.02 * opaco:
        return None
    return rot == cand
```

Em `converter()`, quando `cheia=True` e `area_cheia()` devolve máscara: os
segmentos dessa máscara passam pelo mesmo `encadear → alisar → cantos →
partir → ajustar` e viram **um** `<path fill="currentColor" d="… Z"/>`,
emitido **antes** dos traços (fica por baixo). O `_vestido()` do
`icones_apps_arcticons.sh` já troca o literal `currentColor` nos dois
atributos, e a `_conferir_dialeto` do painel só exige que `fill="none"`
exista no texto (está no `<g>`). A métrica `cheia` diz qual classe foi, ou
`null` — e é por ela que a oficina decide se mostra o cartão.

### 1.6 A emissão

```python
def emitir(linhas, esc: float) -> str:
    """linhas: lista de (fechada, trechos), trecho = ("C", [ctrl…]) | ("L", pts).
    Sai `M x y` + `C …`/`L …` + `Z` quando fechada. Duas casas, como hoje."""
    partes = []
    for fechada, trechos, cheia in linhas:
        primeiro = trechos[0][1][0]
        primeiro = primeiro[0] if trechos[0][0] == "C" else primeiro
        d = [f"M{primeiro[0] * esc:.2f} {primeiro[1] * esc:.2f}"]
        for tipo, dados in trechos:
            if tipo == "C":
                for c in dados:
                    d.append("C" + " ".join(f"{q[0] * esc:.2f} {q[1] * esc:.2f}" for q in c[1:]))
            else:
                for q in dados[1:]:
                    d.append(f"L{q[0] * esc:.2f} {q[1] * esc:.2f}")
        if fechada:
            d.append("Z")
        atrib = ' fill="currentColor"' if cheia else ""
        partes.append(f'<path{atrib} d="{" ".join(d)}"/>')
    return "".join(partes)
```

A gramática de saída ganha `C`, `L` e `Z`. **Quem lê não muda**: o
`_vestido()` procura `<path ` (com espaço) para injetar `stroke-width` — o
`<path fill=` e o `<path d=` têm o espaço; o regex de `_conferir_dialeto`
não olha comandos de path; o `rsvg-convert` e o COSMIC rasterizam `C`
desde sempre.

### 1.7 O laço de `converter()` depois da mudança

```python
def converter(entrada, k=6, moda=3, funde=46.0, tol=1.6, min_traco=3.2,
              fita=2.2, envolve=0.55, res=RES, curvas=True, cheia=False):
    ...                                              # tudo igual até `colapsar_fitas`
    esc = 48.0 / (res + 2)
    linhas, caidos, ncantos, ncurvas = [], 0, 0, 0
    m = None                                         # a máscara da área cheia, se houver

    def tracar(pontos, fechada, com_cheia=False):
        nonlocal caidos, ncantos, ncurvas
        if not curvas:
            s = dp(pontos, tol)                      # o caminho de hoje, intacto
            if fechada and len(s) > 2 and s[0] != s[-1]:
                s.append(s[0])
            return (fechada, [("L", np.asarray(s, np.float64))], com_cheia) if len(s) >= 2 else None
        p = alisar(pontos, fechada)
        idx = cantos(p, fechada)
        ncantos += len(idx)
        trechos = []
        for tr in partir(p, idx, fechada):
            if len(tr) < 2:
                continue
            if fechada and not idx:
                t = tr[1] - tr[-2]
                t = t / (np.linalg.norm(t) or 1.0)
                c = ajustar(tr, tol, t1=t, t2=-t)
            else:
                c = ajustar(tr, tol)
            if c is None:
                caidos += 1
                trechos.append(("L", np.asarray(dp([tuple(q) for q in tr], 1.6), np.float64)))
            else:
                ncurvas += len(c)
                trechos.append(("C", c))
        return (fechada, trechos, com_cheia) if trechos else None

    if cheia:
        m = area_cheia(rot, n)
        if m is not None:
            for linha in encadear(segmentos(m)):
                t = tracar(linha, True, com_cheia=True)
                if t: linhas.append(t)

    vistas = set()
    for c in range(n):
        ...                                          # o dedupe global, igual a hoje
        for linha in encadear(segs):
            fechada = linha[0] == linha[-1]
            if comprimento(linha) * ESCALA * (RES / res) < min_traco:
                continue                             # o descarte de traço curto, ANTES de alisar
            t = tracar(linha, fechada)
            if t: linhas.append(t)

    corpo = emitir(linhas, esc)
    metricas = {"classes": n, "fitas": len(fitas), "linhas": len(linhas),
                "curvas": ncurvas, "cantos": ncantos, "caidos": caidos,
                "cheia": bool(m is not None) or None,   # True ou null — é por ela que a oficina decide o cartão
                "pontos": sum(len(c) * 3 if t == "C" else len(c) for _, tr, _ in linhas for t, c in tr)}
    return corpo, metricas
```

O descarte de traço curto (`min_traco`) mede a **polilinha crua**, como
hoje — alisar antes encurtaria um pouco e mudaria o que é descartado, e a
folha de 11/08 foi aprovada com o critério de hoje.

### 1.8 `main()` — as chaves

```
--curvas          (padrão) alisa, acha cantos e ajusta Bézier; `--tol` é o erro máximo do ajuste, px de 256 (padrão 1,0)
--polilinha       o comportamento anterior; `--tol` volta a ser a tolerância do Douglas–Peucker (padrão 1,6)
--cheia           a maior área interna sai cheia (`fill="currentColor"`)
--json            imprime as métricas como UMA linha JSON no stdout (o stderr continua com a frase de hoje)
--cantos GRAUS    limiar de canto (padrão 60)
```

O padrão de `--tol` muda com o modo — `1.0` em curvas, `1.6` em polilinha —
porque medem coisas diferentes. `argparse` com `default=None` e a escolha
depois de ler o modo. **As chaves de hoje continuam aceitas com o mesmo
sentido** (`--k`, `--moda`, `--funde`, `--envolve`, `--fita`, `--min-traco`,
`--lw`), porque o campo 4 do `apps-convertidos.map` é passado cru ao
conversor pelo `construir_convertidos.sh`.

A linha do `stderr` passa a ser:

```
org.gimp.GIMP.svg: 4 classes (0 fita), 6 traços, 41 curvas, 3 cantos, 0 caídos
```

---

## 2. `tests/conversor.sh` — a trava

```bash
#!/usr/bin/env bash
# A ESCADA NÃO VOLTA SEM NINGUÉM VER.
#
# Em 09/09/2026 ela olhou a oficina e chamou o traço de "pixelado". A causa
# era o conversor emitir só polilinha (marching squares em lados de pixel,
# aparada por Douglas–Peucker). Este teste afirma, em três origens fixas do
# repositório e do sistema, que a saída padrão é curva, é menor, rasteriza, e
# continua no dialeto do acervo (sem espessura, sem cor, viewBox 48).
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONV="$RAIZ/scripts/converter_icone.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()   { printf 'ok: %s\n' "$1"; }
falha(){ printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas+1)); }

ORIGENS=(
  "$RAIZ/assets/icones/autorais/cosmic-edit-mocha.svg"        # autoral, com contorno (a fita colapsa)
  "/usr/share/icons/Papirus/64x64/apps/org.gimp.GIMP.svg"       # Papirus, gradiente e sombra
  "$RAIZ/assets/icones/catppuccin-apps/mocha/spotify.png"       # PNG chapado — ajuste o nome ao acervo
)
for origem in "${ORIGENS[@]}"; do
  [ -f "$origem" ] || { printf 'pulado: %s não existe nesta máquina\n' "$origem"; continue; }
  nome="$(basename "$origem")"
  ini=$(date +%s%N)
  python3 "$CONV" "$origem" "$T/c.svg" --json >"$T/c.json" 2>"$T/c.err" || { falha "$nome: o conversor falhou em --curvas ($(cat "$T/c.err"))"; continue; }
  dur=$(( ($(date +%s%N) - ini) / 1000000 ))
  python3 "$CONV" "$origem" "$T/p.svg" --polilinha 2>/dev/null || { falha "$nome: o conversor falhou em --polilinha"; continue; }

  grep -q 'C[0-9]' "$T/c.svg"           && ok "$nome: a saída tem curvas" || falha "$nome: nenhum C na saída"
  grep -q 'stroke-width' "$T/c.svg"     && falha "$nome: gravou stroke-width" || ok "$nome: sem stroke-width"
  grep -Eq '#[0-9A-Fa-f]{3,8}\b' "$T/c.svg" && falha "$nome: gravou cor" || ok "$nome: sem cor"
  grep -q 'viewBox="0 0 48 48"' "$T/c.svg" && ok "$nome: viewBox 48" || falha "$nome: viewBox errado"
  rsvg-convert -w 48 -h 48 "$T/c.svg" -o "$T/c.png" 2>/dev/null && ok "$nome: rasteriza" || falha "$nome: o rsvg recusou a saída"

  # menor: número de "pontos de apoio" (cada C vale 3, cada vértice de polilinha 1)
  pc=$(python3 -c "import json;print(json.load(open('$T/c.json'))['pontos'])")
  pp=$(grep -o '[0-9.]* [0-9.]*' "$T/p.svg" | wc -l)
  [ "$pc" -le $(( pp * 40 / 100 )) ] && ok "$nome: $pc pontos contra $pp (≤ 40 %)" || falha "$nome: $pc pontos contra $pp — não encolheu"

  caidos=$(python3 -c "import json;print(json.load(open('$T/c.json'))['caidos'])")
  [ "$caidos" -le 2 ] && ok "$nome: $caidos trecho(s) caíram para polilinha" || falha "$nome: $caidos trechos caíram — o ajuste não converge"
  [ "$dur" -lt 1000 ] && ok "$nome: ${dur} ms" || falha "$nome: ${dur} ms — passou de 1 s"

  # a mesma forma: as duas saídas, rasterizadas a 48 px, diferem em menos de 6 % dos pixels
  rsvg-convert -w 48 -h 48 "$T/p.svg" -o "$T/p.png" 2>/dev/null
  dif=$(compare -metric AE -fuzz 8% "$T/c.png" "$T/p.png" null: 2>&1 | awk '{print int($1)}')
  [ "${dif:-9999}" -lt 138 ] && ok "$nome: curvas e polilinha diferem em $dif px de 2304" || falha "$nome: $dif px diferentes — a forma mudou, não só a linha"
done

# --cheia produz um fill, e só um, e só quando há área
python3 "$CONV" "/usr/share/icons/Papirus/64x64/apps/org.gimp.GIMP.svg" "$T/f.svg" --cheia --json >"$T/f.json" 2>/dev/null
n=$(grep -o 'fill="currentColor"' "$T/f.svg" | wc -l)
[ "$n" -le 1 ] && ok "--cheia: $n área cheia" || falha "--cheia: $n áreas cheias — era para ser no máximo uma"

exit "$falhas"
```

O `compare` e o `rsvg-convert` já são dependências do projeto (a suíte de
navegador usa o primeiro; o instalador exige o segundo). **Os 138 px** são
6 % de 48² — o número que separa "a mesma forma com outra linha" de "outra
forma"; se a régua se mostrar apertada num dos três, é o número que se
mede, não o teste que se apaga.

---

## 3. `scripts/folha_conversor.py` — a folha que decide

**Sai em `~/Documentos/meow-conversor-folha.html`**, arquivo único, sem rede,
tudo embutido em base64 — a regra dela de 10/08. Não instala, não escreve
no repositório.

### 3.1 O que entra

- Os **33** do `assets/icones/apps-convertidos.map` que têm origem (as
  linhas `mao` não têm o que converter — entram numa seção à parte, só com
  o retoque atual, para ela lembrar que existem).
- Os **5 recusados** de 11/08, com a origem no Papirus:
  `firefox`, `org.kde.krita`, `thunderbird`, `com.boxy_svg.BoxySVG`, `btop`.
- A cor de cada um é o campo 3 do mapa (os recusados: `mauve`).

### 3.2 As colunas

| coluna | como se produz |
|---|---|
| **original** | o arquivo de origem, embutido como está |
| **polilinha** | `converter_icone.py --polilinha --lw 2.25` + `currentColor → hex` |
| **curvas** | `converter_icone.py --lw 2.25` + `currentColor → hex` |
| **potrace** | só se `shutil.which("potrace")`; ver 3.4 |

Cada célula: a 48 px sobre os **quatro fundos** de `folha_icones.py`
(`#1e1e2e`, `#eff1f5`, `#3C3B50`, `#826E92`) e a **200 px** sobre o mocha —
o tamanho da lupa da oficina, que é onde ela viu a escada. A folha é
`.html` fora do repositório: hex literal é permitido aqui, como já é na
`folha_icones.py`.

### 3.3 O esqueleto

```python
#!/usr/bin/env python3
# folha_conversor.py — quatro jeitos de traçar o mesmo ícone, lado a lado.
#   uso: scripts/folha_conversor.py [saida.html]
import base64, json, os, re, shutil, subprocess, sys, tempfile
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONV = os.path.join(RAIZ, "scripts", "converter_icone.py")
PALETA = json.load(open(os.path.join(RAIZ, "assets", "paleta", "catppuccin.json")))["flavors"]["mocha"]
FUNDOS = [("mocha", "#1e1e2e"), ("latte", "#eff1f5"), ("vidro médio", "#3C3B50"), ("vidro claro", "#826E92")]
RECUSADOS = {"firefox": "mauve", "org.kde.krita": "mauve", "thunderbird": "mauve",
             "com.boxy_svg.BoxySVG": "mauve", "btop": "mauve"}

def ler_mapa():
    for linha in open(os.path.join(RAIZ, "assets", "icones", "apps-convertidos.map"), encoding="utf-8"):
        linha = linha.strip()
        if not linha or linha.startswith("#"): continue
        nome, origem, cor, *extra = linha.split(":")
        if origem == "mao": continue
        if not origem.startswith("/"): origem = os.path.join(RAIZ, origem)
        yield nome, origem, cor, (extra[0] if extra else "")

def converter(origem, cor, *flags):
    with tempfile.NamedTemporaryFile(suffix=".svg", delete=False) as f: saida = f.name
    subprocess.run([sys.executable, CONV, origem, saida, "--lw", "2.25", *flags], check=True, capture_output=True)
    svg = open(saida, encoding="utf-8").read(); os.unlink(saida)
    return svg.replace("currentColor", PALETA[cor])

def embute_svg(texto): return "data:image/svg+xml;base64," + base64.b64encode(texto.encode()).decode()
def embute_arquivo(caminho):
    tipo = "image/svg+xml" if caminho.endswith(".svg") else "image/png" if caminho.endswith(".png") else "image/jpeg"
    return f"data:{tipo};base64," + base64.b64encode(open(caminho, "rb").read()).decode()

def celula(uri):
    fundos = "".join(f'<span style="background:{hex_}"><img src="{uri}" width="48" height="48" title="{n}"></span>' for n, hex_ in FUNDOS)
    return f'<td><div class="quatro">{fundos}</div><img class="lupa" src="{uri}" width="200" height="200"></td>'
```

O `main()` monta uma `<table>` com uma linha por ícone (nome, cor, origem em
`<code>`), as três ou quatro células, e um rodapé com os totais da linha do
`stderr` de cada conversão (traços, curvas, cantos, caídos) — o número ao
lado da figura é o que permite dizer "o btop caiu 3 trechos, por isso está
assim". CSS mínimo, embutido: `td { vertical-align: top }`, `.quatro span {
display:inline-block; padding: 6px; border-radius: 8px }`, `.lupa { display:
block; margin-top: 8px; background:#1e1e2e; border-radius: 12px }`.

### 3.4 A coluna do potrace

Instala-se **uma vez, à mão**, só para a folha: `sudo apt install potrace`
(1.16, ~100 KB). Não entra no `install.sh` por esta sprint.

O potrace traça regiões pretas de um bitmap. Para comparar com o mesmo
recorte de cor, ele recebe **a mesma máscara por classe** que o nosso
traçador — importa-se o módulo (não faz nada ao importar, por desenho) e
reusa-se `rasterizar → quantizar → moda2d → colapsar_fitas`:

```python
sys.path.insert(0, os.path.join(RAIZ, "scripts"))
import converter_icone as ci

def potrace_svg(origem, cor, k=6, funde=46.0):
    rgba = ci.rasterizar(origem, ci.RES)
    rot, _ = ci.quantizar(rgba, k, funde)
    n = int(rot.max()) + 1
    rot = ci.moda2d(rot, 3, n)
    rot, _ = ci.colapsar_fitas(rot, n, 2.2, ci.RES)
    grupos = []
    for c in range(1, n):
        m = rot == c
        if not m.any(): continue
        pbm = ("P1\n%d %d\n" % m.shape[::-1]) + "\n".join(" ".join("1" if v else "0" for v in linha) for linha in m)
        r = subprocess.run(["potrace", "-s", "--flat", "-a", "1.0", "-O", "0.4", "-t", "8", "-o", "-", "-"],
                           input=pbm.encode(), capture_output=True, check=True)
        g = re.search(rb"<g[^>]*>.*?</g>", r.stdout, re.S).group(0).decode()
        g = re.sub(r'\s(fill|stroke)="[^"]*"', "", g)
        g = g.replace("<path ", '<path vector-effect="non-scaling-stroke" ')
        grupos.append(g)
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><g fill="none" stroke="%s" '
            'stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round" transform="scale(%.6f)">'
            % (PALETA[cor], 48.0 / ci.RES)) + "".join(grupos) + "</g></svg>"
```

Dois detalhes que custariam uma folha errada se não estivessem escritos:

- o potrace emite `<g transform="translate(0,H) scale(0.1,-0.1)">` com
  coordenadas em décimos de pixel; **o grupo dele entra inteiro, com o
  `transform`**, dentro do nosso `scale(48/256)`. Sem parse de coordenada.
- essa escala reduziria a espessura do traço a 0,1×; o
  `vector-effect="non-scaling-stroke"` em cada `<path>` mantém os 2,25.

O que a coluna vai mostrar, previsto e a confirmar: curvas mais macias que
as nossas em forma orgânica (o potrace otimiza curva por curva), e **linha
dupla** onde duas classes se encostam, porque ele traça cada região sozinha
e não sabe que a fronteira é a mesma. É exatamente o que a nota de 11/08
mediu ("duas cópias divergem e engrossam o traço"). Se, apesar disso, ela
preferir a coluna do potrace, a integração é **outra sprint**: precisa de
uma estratégia de deduplicação que o potrace não tem.

---

## 4. `retoques/LEIA-ME.txt` — duas frases que envelhecem

Trocar:

> O conversor SÓ emite polilinha (`M x y x y …`) — não há uma linha nele que
> escreva `C`.

por:

> Desde a Sprint Q (09/09/2026) o conversor emite curvas (`C`) por padrão.
> A boca do Wilber é retoque manual **porque este arquivo foi gerado em
> polilinha e a boca é a única curva nele** — os outros seis subcaminhos são
> byte a byte os de `converter_icone.py --polilinha` sobre
> `/usr/share/icones/Papirus/64x64/apps/org.gimp.GIMP.svg`, e é assim que se
> confere. Este retoque NÃO foi reconvertido em curvas: é decisão registrada,
> e a regra do diretório continua — nunca sobrescrito.

E o `1,75`/`2,25` que o próprio LEIA-ME já corrige: fica como está.

---

## 5. A régua dos dois números: `>_` e `B`

Antes da folha, dois ícones medem o limiar de canto e a tolerância:

```bash
python3 scripts/converter_icone.py assets/icones/autorais/cosmic-term-mocha.svg /tmp/term.svg --json
python3 scripts/converter_icone.py /usr/share/icons/Papirus/64x64/apps/btop.svg /tmp/btop.svg --json
rsvg-convert -w 200 -h 200 /tmp/term.svg -o /tmp/term.png   # e olhar
```

- o `>_` do terminal tem de sair com **dois cantos** no `>` e as duas pontas
  do `_` retas — `cantos ≥ 2`, `caidos = 0`;
- o `B` do btop tem de manter as duas barrigas redondas e a haste reta —
  `cantos` entre 2 e 4.

Se o `>` sair arredondado, o limiar cai de 60° para 45° **e a medição se
repete nos dois**. Se o `B` ganhar cantos nas barrigas, `passo` sobe de 3
para 4. É uma régua de dois pontos, e os dois têm de passar.

---

## 6. Ordem de execução

1. §1 — as funções e a emissão. `python3 scripts/converter_icone.py` nas
   três origens do teste, olhar os PNG a 48 e 200.
2. §5 — a régua dos dois números.
3. §2 — `tests/conversor.sh` passa.
4. §3 — `scripts/folha_conversor.py` → `~/Documentos/meow-conversor-folha.html`.
   **Parar aqui e mostrar a ela.** Nada da tela dela mudou até este ponto.
5. Depois do "sim": `./scripts/construir_convertidos.sh` regenera os 33
   (`git diff --stat` mostra 33 arquivos em `convertidos-apps/`, zero em
   `retoques/`); `meow` → ação `icones_traco` (ou o botão do painel) põe na
   tela; capturar a dock; ler a foto.
6. §4 — o LEIA-ME. Commit: `feat(icones): o conversor emite curvas, e a
   escada sai do traço`.
7. `docs/SPRINTS.md`: a Sprint Q vira FECHADA, com a data e o que a medição
   derrubou.

**Tamanho:** meio dia. §1 são ~180 linhas de Python; §3, ~150; §2, ~60.

---

## 7. O que pode dar errado, com o remédio ao lado

| sintoma | causa provável | remédio |
|---|---|---|
| o `>` do terminal sai redondo | limiar de canto alto demais | 60° → 45°, remedir §5 |
| o `B` do btop ganha bicos | `passo` curto demais para a curvatura | 3 → 4 |
| um laço vira "oito" (se cruza) | ajuste divergiu e a guarda não pegou | `caidos` > 0 na métrica: baixar `prof` de 6 para 4 e olhar o trecho |
| a emenda do círculo tem um bico | tangente da emenda não é a partilhada | conferir a chamada `t1=t, t2=-t` em `tracar()` |
| a oficina ficou lenta | Newton em trechos de 4 k pontos | medir com `time`; se > 0,3 s, subamostrar o trecho a cada 2 pontos antes do ajuste (a escada já foi alisada) |
| `--cheia` enche a forma errada | o "corpo" não é quem mais toca o fundo | olhar `borda0`; a alternativa é "a classe de maior área" quando só há duas |
| o `git diff` mostra `retoques/` | o construtor reconverteu um retoque | não pode: `_desejado_de` lê `retoques/` primeiro — algo tocou o diretório errado, parar |
| o GIMP na dock ficou diferente | ele **não** foi reconvertido (é retoque) e os vizinhos foram | esperado; é para ela decidir se quer reconverter o Wilber e redesenhar a boca em curva |

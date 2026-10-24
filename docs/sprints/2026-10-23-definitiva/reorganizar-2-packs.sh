#!/usr/bin/env bash
# reorganizar-2-packs.sh — P96, parte 2: os packs.
#
#   reorganizar-2-packs.sh --ensaio [RAIZ]   faz tudo numa cópia e imprime o que faria; aqui nada muda
#   reorganizar-2-packs.sh [RAIZ]            aplica; a segunda passada não escreve nada
#
# Roda DEPOIS do reorganizar-1-raiz.sh. O que faz:
#   1. o pack `catppuccin` entra no `meowsystem`, que vira o pack padrão (o nome de antes continua
#      achando o pack: conf, herança, `pack:catppuccin:`);
#   2. `icones/{apps,sistema,biblioteca}` de cada pack ficam PLANAS, sem subpasta; os tipos de
#      arquivo viram UM molde (`var(--vscode-ctp-*)`) que a instalação pinta com a paleta do pack;
#   3. uma versão por ícone: o que quem usa escolheu na página de 23/10
#      (`escolhas.json` + `escolhas-resolvidas.tsv`), o manuais-final lido NA HORA, cada arte de fora
#      conferida (viewBox que corta o desenho, non-scaling-stroke) antes de entrar;
#   4. os mapas, os catálogos, o PROCEDENCIA.md e `packs/CAMINHOS-DE-ANTES.tsv` no caminho novo;
#   5. o código e os testes que liam o layout de antes, por troca de trecho (nunca por número de
#      linha): o trecho de antes tem de aparecer UMA vez, ou nada é trocado e o script recusa.
#
# Tudo vai para o índice por caminho; nada é commitado.
#
# Variáveis (os padrões são os desta máquina):
#   P96_MANUAIS   a pasta da arte feita à mão           (~/Desktop/manuais-final)
#   P96_ESCOLHAS  o escolhas.json da página de escolha  (.wt-meow/p96-duvidas/escolhas.json)
#   P96_TSV       as escolhas de quem usa                (.wt-meow/p96-duvidas/escolhas-resolvidas.tsv)
set -euo pipefail

ENSAIO=0
case "${1:-}" in --ensaio|-n) ENSAIO=1; shift ;; esac
RAIZ="${1:-$(git rev-parse --show-toplevel)}"
RAIZ="$(cd "$RAIZ" && pwd -P)"
[ -f "$RAIZ/install.sh" ] && [ -d "$RAIZ/packs" ] || { echo "não é a raiz do MeowSystem: $RAIZ" >&2; exit 2; }
DUVIDAS="${P96_DUVIDAS:-$HOME/Desenvolvimento/.wt-meow/p96-duvidas}"
MANUAIS="${P96_MANUAIS:-$HOME/Desktop/manuais-final}"
ESCOLHAS="${P96_ESCOLHAS:-$DUVIDAS/escolhas.json}"
TSV="${P96_TSV:-$DUVIDAS/escolhas-resolvidas.tsv}"
TRABALHO="${P96_TRABALHO:-$HOME/Desenvolvimento/MeowSystem/.trabalho-icones/svg}"
for f in "$ESCOLHAS" "$TSV"; do [ -f "$f" ] || { echo "falta $f" >&2; exit 2; }; done
[ -d "$MANUAIS" ] || { echo "falta a pasta $MANUAIS" >&2; exit 2; }
command -v rsvg-convert >/dev/null || { echo "falta rsvg-convert (a conferência da arte renderiza)" >&2; exit 2; }
python3 -c 'import PIL' 2>/dev/null || { echo "falta o python3-pil (a conferência da arte mede o render)" >&2; exit 2; }
# Só escolha de quem usa vale como final: a recomendação provisória não entra.
if awk -F'\t' 'NR > 1 && $4 != "" && $4 != "quem-usa" && $4 != "decisao-16-vale"' "$TSV" | grep -q .; then
  echo "o $TSV ainda tem linha que não é escolha de quem usa:" >&2
  awk -F'\t' 'NR > 1 && $4 != "" && $4 != "quem-usa" && $4 != "decisao-16-vale" {print "  " $1 " (" $4 ")"}' "$TSV" >&2
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Os três programas e as trocas moram no fim deste arquivo, cada um depois do seu marcador.
for parte in mover.py arte.py trocas_motor.py trocas.json; do
  awk -v m="#__${parte}__" '$0 == m {f=1; next} /^#__[a-z_]+\.[a-z]+__$/ || /^__P96_DADOS__$/ {f=0} f' "${BASH_SOURCE[0]}" > "$TMP/$parte"
done

ALVO="$RAIZ"
if [ "$ENSAIO" = 1 ]; then
  # O ENSAIO RODA NUMA CÓPIA (a mesma porta do reorganizar-1-raiz.sh): um clone que divide os objetos
  # com o repositório e recebe a árvore de trabalho de agora.
  ALVO="$TMP/copia"
  git clone -q --shared --no-checkout "$RAIZ" "$ALVO"
  git -C "$ALVO" read-tree HEAD
  rsync -a --exclude=/.git --exclude=/.playwright-mcp --exclude=/.trabalho-icones \
        --exclude=/assets/icones/upstream --exclude=/assets/fontes/upstream "$RAIZ/" "$ALVO/"
  git -C "$ALVO" add -u -- . >/dev/null 2>&1
  git -C "$ALVO" ls-files -o --exclude-standard -z -- packs scripts docs | xargs -0 -r git -C "$ALVO" add -- >/dev/null 2>&1
fi

echo "== os packs"
python3 -I "$TMP/mover.py" "$ALVO" "$ESCOLHAS" "$TSV" "$MANUAIS" "$TRABALHO" --aplicar
echo "== o código e os testes"
python3 -I "$TMP/trocas_motor.py" "$ALVO" "$TMP/trocas.json" --aplicar
if [ "$ENSAIO" = 1 ]; then
  echo "== ensaio: nada foi escrito em $RAIZ"
else
  echo "== aplicado em $RAIZ — no índice, sem commit"
fi
exit 0

# ═══════════ os programas e as trocas (dado, nunca executado pelo bash) ═══════════
: <<'__P96_DADOS__'
#__mover.py__
"""P96 parte 2 — os packs: dois packs, três pastas planas por pack, uma versão por ícone.

Uso: python3 -I mover.py <raiz> <escolhas.json> <escolhas.tsv> <manuais-final> <trabalho-icones/svg> [--aplicar]

Sem --aplicar só imprime o plano (ensaio). Com --aplicar, cada movimento é `git mv`,
cada saída é `git rm`, e o que entra de fora é cópia + `git add` por caminho.
Rodar de novo sobre o resultado não escreve nada: o plano sai vazio.
"""
import collections, csv, hashlib, json, os, re, shutil, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from arte import corrigir_svg

RAIZ, ESCOLHAS, TSV, MANUAIS, TRABALHO = sys.argv[1:6]
APLICAR = "--aplicar" in sys.argv[6:]
PACKS = os.path.join(RAIZ, "packs")
EXT = (".svg", ".png")
TRES = ("apps", "sistema", "biblioteca")

plano = []          # (verbo, de, para) — o relatório
def nota(verbo, de="", para=""):
    plano.append((verbo, de, para))

def rel(p):
    return os.path.relpath(p, RAIZ)

_DE_FORA = {}


def de_fora(p):
    """Os bytes que entram no pack a partir de um arquivo de fora, já conferidos (ver arte.py).
    Lidos NA HORA: quem usa pode ter editado o manuais-final depois das escolhas."""
    if p not in _DE_FORA:
        with open(p, "rb") as fh:
            bruto = fh.read()
        dados, notas = corrigir_svg(bruto) if p.endswith(".svg") else (bruto, [])
        _DE_FORA[p] = (dados, notas, hashlib.sha256(bruto).hexdigest(), os.path.getmtime(p))
    return _DE_FORA[p]


def eh_de_fora(p):
    return os.path.isabs(p) and not os.path.realpath(p).startswith(os.path.realpath(RAIZ) + os.sep)


def sha(p):
    if eh_de_fora(p):
        return hashlib.sha256(de_fora(p)[0]).hexdigest()
    with open(p, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()

def git(*args, check=True):
    # Um git de fundo (o `gc --auto` que o próprio git solta) pode segurar o `index.lock` por um
    # instante: espera e tenta de novo, em vez de parar no meio com o repositório pela metade.
    for tentativa in range(60):
        r = subprocess.run(["git", "-C", RAIZ, "-c", "gc.auto=0", "-c", "maintenance.auto=false", *args],
                           capture_output=True, text=True)
        if r.returncode == 0 or "index.lock" not in r.stderr:
            break
        time.sleep(0.5)
    if check and r.returncode != 0:
        sys.stderr.write(r.stderr)
        raise subprocess.CalledProcessError(r.returncode, r.args, r.stdout, r.stderr)
    return r.stdout

def rastreados(prefixo):
    return [l for l in git("ls-files", "-z", "--", prefixo).split("\0") if l]

def mover(de, para):
    """git mv de -> para (caminhos absolutos). Se o destino já tem os mesmos bytes, só tira a origem."""
    if os.path.abspath(de) == os.path.abspath(para):
        return
    nota("move", rel(de), rel(para))
    if not APLICAR:
        return
    os.makedirs(os.path.dirname(para), exist_ok=True)
    if os.path.exists(para):
        if sha(para) != sha(de):
            raise SystemExit(f"recusa: {rel(para)} já existe com outro conteúdo")
        git("rm", "-q", "-f", "--", rel(de))
    else:
        git("mv", "--", rel(de), rel(para))

def tirar(p):
    nota("sai", rel(p))
    if APLICAR and os.path.exists(p):
        git("rm", "-q", "-f", "--", rel(p))

def entrar(origem, para):
    import time
    if eh_de_fora(origem):
        dados, notas, sha_bruto, quando = de_fora(origem)
        extra = f"  [sha256 {sha_bruto}, {time.strftime('%d/%m/%Y %H:%M', time.localtime(quando))}" + \
                ("; " + "; ".join(notas) if notas else "") + "]"
    else:
        dados, extra = open(origem, "rb").read(), ""
    nota("entra", origem + extra, rel(para))
    if APLICAR:
        os.makedirs(os.path.dirname(para), exist_ok=True)
        with open(para, "wb") as fh:
            fh.write(dados)
        git("add", "--", rel(para))

def escrever(p, texto):
    antigo = open(p, encoding="utf-8").read() if os.path.exists(p) else None
    if antigo == texto:
        return
    nota("reescreve", rel(p))
    if APLICAR:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write(texto)
        git("add", "--", rel(p))

def ler_json(p):
    with open(p, encoding="utf-8") as fh:
        return json.load(fh, object_pairs_hook=collections.OrderedDict)

def json_texto(d):
    return json.dumps(d, ensure_ascii=False, indent=2) + "\n"

# a tabela de caminho velho -> novo, para mapas, catálogos, PROCEDENCIA e a casa de quem usa
DE_PARA = collections.OrderedDict()   # "packs/<id>/<rel velho>" -> "packs/<id>/<rel novo>" ou "" (saiu)

def registrar(de, para):
    DE_PARA[rel(de)] = rel(para) if para else ""

def destino_livre(pasta, nome, conteudo_sha, ocupados):
    """O nome na pasta plana; se já tem outro desenho com esse nome, sufixo -2, -3…"""
    base, ext = os.path.splitext(nome)
    cand, n = nome, 1
    while True:
        p = os.path.join(pasta, cand)
        dono = ocupados.get(p)
        if dono is None or dono == conteudo_sha:
            ocupados[p] = conteudo_sha
            return p
        n += 1
        cand = f"{base}-{n}{ext}"

# =========================================================================================
# 1. catppuccin entra no meowsystem
# =========================================================================================
CAT = os.path.join(PACKS, "catppuccin")
MEOW = os.path.join(PACKS, "meowsystem")
DRAC = os.path.join(PACKS, "dracula")

def unir_catppuccin():
    if not os.path.isdir(CAT) or not rastreados(rel(CAT)):
        return
    if not os.path.exists(os.path.join(CAT, "pack.json")):
        raise SystemExit("recusa: packs/catppuccin sem pack.json — uma passada anterior parou no meio; "
                         "volte o repositório ao commit de antes (git reset --hard) e rode de novo")
    pj_cat = ler_json(os.path.join(CAT, "pack.json"))
    pj_meow = ler_json(os.path.join(MEOW, "pack.json"))
    novo = collections.OrderedDict()
    for k, v in pj_cat.items():
        if k == "id":
            novo[k] = "meowsystem"
        elif k == "nome":
            novo[k] = "MeowSystem"
        else:
            novo[k] = v
    novo["_nota"] = ("packs/meowsystem/pack.json — o pack padrão (P96, 23/10/2026): o MeowSystem com as cores do "
                     "Catppuccin, que era um pack à parte e entrou aqui. Todo pack herda dele.")
    ic = collections.OrderedDict()
    ic["apps"] = collections.OrderedDict([("recolorir", True)])
    ic["autorais"] = collections.OrderedDict([("desenhos", "icones/apps/")])
    ic["mimetypes"] = collections.OrderedDict([
        ("desenhos", "icones/sistema/"), ("mapa", "icones/mimetypes.map"),
        ("_nota", "Os 656 desenhos de tipo de arquivo do catppuccin/vscode-icons (MIT) guardados UMA vez, como "
                  "molde: cada cor é um `var(--vscode-ctp-<papel>)`. A instalação pinta o molde com a paleta do "
                  "pack no ar e o flavor escolhido (P96, decisão de 23/10).")])
    ic["pastas"] = collections.OrderedDict([("desenhos", "icones/sistema/"), ("mapa", "icones/pastas.map")])
    novo["icones"] = ic
    if "apps" in novo and isinstance(novo["apps"], dict):
        for app, bloco in novo["apps"].items():
            if isinstance(bloco, dict) and isinstance(bloco.get("arquivo"), str) and bloco["arquivo"].startswith("apps/"):
                bloco["arquivo"] = f"temas-de-apps/{app}/" + bloco["arquivo"][len("apps/"):]
    for k in ("papel",):
        novo.pop(k, None)
    # o que o pack-base já declarava (o mascote, os papéis de parede que a parte 1 trouxe) fica
    for k, v in pj_meow.items():
        if k in ("id", "nome", "papel", "_nota", "icones", "formato"):
            continue
        if k not in novo:
            novo[k] = v
        elif isinstance(novo[k], dict) and isinstance(v, dict):
            for kk, vv in v.items():
                novo[k].setdefault(kk, vv)
    # arquivos soltos do topo
    for nome in sorted(os.listdir(CAT)):
        de = os.path.join(CAT, nome)
        if nome == "pack.json" or os.path.isdir(de):
            continue
        para = os.path.join(MEOW, nome)
        if os.path.exists(para) and sha(para) != sha(de):
            if nome.endswith(".md"):
                # PROCEDENCIA/CREDITOS dos dois: junta o texto do catppuccin no fim
                junto = open(para, encoding="utf-8").read().rstrip("\n") + "\n\n" + open(de, encoding="utf-8").read()
                escrever(para, junto)
                tirar(de)
                continue
            raise SystemExit(f"recusa: {rel(para)} e {rel(de)} divergem")
        mover(de, para)
        registrar(de, para)
    # temas de aplicativo: apps/<arq> -> temas-de-apps/<app>/<arq>
    app_de = {}
    for app, bloco in (pj_cat.get("apps") or {}).items():
        if isinstance(bloco, dict) and isinstance(bloco.get("arquivo"), str):
            app_de[os.path.basename(bloco["arquivo"])] = app
    for f in rastreados(rel(os.path.join(CAT, "apps"))):
        nome = os.path.basename(f)
        app = app_de.get(nome)
        para = os.path.join(MEOW, "temas-de-apps", app, nome) if app else os.path.join(MEOW, "temas-de-apps", nome)
        mover(os.path.join(RAIZ, f), para)
        registrar(os.path.join(RAIZ, f), para)
    # ícones
    ICAT = os.path.join(CAT, "icones")
    for f in rastreados(rel(ICAT)):
        a = os.path.join(RAIZ, f)
        r = os.path.relpath(a, ICAT)
        partes = r.split(os.sep)
        if partes[:2] == ["apps", "autorais"]:
            para = os.path.join(MEOW, "icones", "apps", partes[-1])
        elif partes[:2] == ["sistema", "mimetypes"]:
            if partes[-1] == "LICENSE":
                para = os.path.join(MEOW, "licencas", "vscode-icons.txt")
            elif len(partes) == 4 and partes[2] == "css-variables":
                para = os.path.join(MEOW, "icones", "sistema", partes[-1])
            else:
                registrar(a, None)
                tirar(a)          # flavor pintado: a instalação refaz do molde
                continue
        elif len(partes) == 1:
            para = os.path.join(MEOW, "icones", r)      # os mapas
        else:
            raise SystemExit(f"recusa: não sei onde pôr {f}")
        mover(a, para)
        registrar(a, para)
    # o resto (capturas, e o que a parte 1 da raiz tenha trazido), no mesmo caminho
    for f in rastreados(rel(CAT)):
        a = os.path.join(RAIZ, f)
        r = os.path.relpath(a, CAT)
        if r == "pack.json" or r.startswith("icones" + os.sep) or r.startswith("apps" + os.sep) or os.sep not in r:
            continue
        para = os.path.join(MEOW, r)
        mover(a, para)
        registrar(a, para)
    escrever(os.path.join(MEOW, "pack.json"), json_texto(novo))
    tirar(os.path.join(CAT, "pack.json"))


def titulos_dos_autorais():
    """O gerador de autorais escreve no <title> o nome do pack: o Catppuccin passou a se chamar
    MeowSystem, e o desenho versionado tem de ser o que o gerador dá (senão a primeira passada do
    vigia o reescreveria)."""
    d = os.path.join(MEOW, "icones", "apps")
    if not os.path.isdir(d):
        return
    for nome in sorted(os.listdir(d)):
        p = os.path.join(d, nome)
        if not nome.endswith(".svg") or not os.path.isfile(p):
            continue
        texto = open(p, encoding="utf-8").read()
        novo = re.sub(r"(<title>[^<]* — )Catppuccin ", r"\1MeowSystem ", texto)
        if novo != texto:
            escrever(p, novo)


# =========================================================================================
# 2. o traço do pack-base, plano
# =========================================================================================
def mapa_campos(p, col):
    s = set()
    if not os.path.exists(p):
        return s
    for l in open(p, encoding="utf-8"):
        l = l.split("#")[0].strip()
        if not l:
            continue
        c = l.split(":")
        if len(c) > col:
            s.add(c[col].strip())
    return s


def aplanar_meowsystem(escolha, de_fora=()):
    IC = os.path.join(MEOW, "icones")
    glifos_app = mapa_campos(os.path.join(IC, "apps-arcticons.map"), 1)
    glifos_sis = mapa_campos(os.path.join(IC, "sistema.map"), 1)
    ocupados = {}
    for pasta in TRES:
        for f in os.listdir(os.path.join(IC, pasta)) if os.path.isdir(os.path.join(IC, pasta)) else []:
            p = os.path.join(IC, pasta, f)
            if os.path.isfile(p):
                ocupados[p] = sha(p)
    molde = set(os.listdir(os.path.join(IC, "sistema"))) if os.path.isdir(os.path.join(IC, "sistema")) else set()
    molde = {f for f in molde if os.path.isfile(os.path.join(IC, "sistema", f))}
    renomear_glifo = {}                       # glifo -> glifo-traco, quando o molde já tem o nome
    trocar_para_traco = set()                 # app que passa do convertido ao glifo do Arcticons
    retoques = set()
    fila = []
    for f in rastreados(rel(IC)):
        a = os.path.join(RAIZ, f)
        r = os.path.relpath(a, IC).split(os.sep)
        if len(r) <= 2:
            continue                          # já plano, ou mapa
        fila.append((a, r))
    # ordem: retoque antes do convertido (o retoque vence o nome)
    fila.sort(key=lambda x: (0 if "retoques" in x[1] else 1, x[1]))
    for a, r in fila:
        nome = r[-1]
        if nome == "LICENSE":
            para = os.path.join(MEOW, "licencas", "arcticons.txt")
            if os.path.exists(para) or any(d == para for d in DE_PARA.values()):
                registrar(a, None); tirar(a); continue
            mover(a, para); registrar(a, para); continue
        if nome == "LEIA-ME.txt":
            para = os.path.join(IC, "RETOQUES.txt")
            mover(a, para); registrar(a, para); continue
        fim = escolha.get(rel(a)) or escolha.get("sha:" + sha(a))
        if fim == "sai":
            registrar(a, None); tirar(a); continue
        nomes_de_fora = {n for _c, n in de_fora}
        stem = nome[:-4]
        if r[:2] == ["apps", "convertidos"]:
            if r[2] == "retoques":
                retoques.add(stem)
                para = os.path.join(IC, "apps", nome)
                if fim == "biblioteca" or nome in nomes_de_fora:
                    para = os.path.join(IC, "biblioteca", nome)
            else:
                para = os.path.join(IC, "apps", nome)
                if stem in retoques:
                    registrar(a, os.path.join(IC, "apps", nome)); tirar(a); continue
        elif r[:2] == ["apps", "arcticons"]:
            if fim == "veste" and stem not in glifos_app:
                trocar_para_traco.add(stem)          # quem usa quis o traço do Arcticons neste app
            para = os.path.join(IC, "apps" if (stem in glifos_app or fim == "veste") and nome not in nomes_de_fora
                                and fim != "biblioteca" else "biblioteca", nome)
        elif r[:2] == ["sistema", "arcticons"]:
            para = os.path.join(IC, "sistema" if stem in glifos_sis else "biblioteca", nome)
            if para.startswith(os.path.join(IC, "sistema") + os.sep) and nome in molde:
                renomear_glifo[stem] = stem + "-traco"
                para = os.path.join(IC, "sistema", stem + "-traco.svg")
        elif r[:2] == ["sistema", "leitura"]:
            para = os.path.join(IC, "sistema", "leitura-" + nome)
        else:
            raise SystemExit(f"recusa: não sei onde pôr {rel(a)}")
        h = sha(a)
        # o mesmo glifo em duas pastas: fica um
        mesmo = [p for p, s in ocupados.items() if s == h and os.path.basename(p) == nome]
        if mesmo and mesmo[0] != para:
            registrar(a, mesmo[0]); tirar(a); continue
        dono = ocupados.get(para)
        if dono is not None and dono != h:
            if os.path.basename(os.path.dirname(para)) != "biblioteca":
                raise SystemExit(f"recusa: {rel(para)} já tem outro desenho (de {rel(a)})")
            para = destino_livre(os.path.dirname(para), nome, h, ocupados)
        ocupados[para] = h
        mover(a, para)
        registrar(a, para)
    # o app que passou ao glifo do Arcticons: a linha sai do mapa dos convertidos e entra no do traço,
    # com a mesma cor
    conv = os.path.join(IC, "apps-convertidos.map")
    arct = os.path.join(IC, "apps-arcticons.map")
    if trocar_para_traco and os.path.exists(conv) and os.path.exists(arct):
        ficam, cores = [], {}
        for l in open(conv, encoding="utf-8").read().split("\n"):
            m = re.match(r"^([^#:\s][^:]*):([^:]*):([^:#\s]*)", l)
            if m and m.group(1).strip() in trocar_para_traco:
                cores[m.group(1).strip()] = m.group(3).strip()
                continue
            ficam.append(l)
        escrever(conv, "\n".join(ficam).rstrip("\n") + "\n")
        texto = open(arct, encoding="utf-8").read().rstrip("\n")
        novas = [f"{n}:{n}:{cores.get(n, 'text')}" for n in sorted(trocar_para_traco)
                 if not re.search(r"^" + re.escape(n) + r":", texto, re.M)]
        if novas:
            escrever(arct, texto + "\n\n# P96 (23/10/2026): quem usa escolheu o traço do Arcticons para estes\n"
                     + "\n".join(novas) + "\n")
    # a lista do traço do Arcticons: com as três pastas planas, o que é glifo do Arcticons não se
    # vê mais pela pasta (o afinador do conversor e a régua do estilo medem SÓ ele)
    lista = os.path.join(IC, "arcticons.lista")
    nomes = set()
    if os.path.exists(lista):
        nomes |= {l.strip() for l in open(lista, encoding="utf-8") if l.strip() and not l.startswith("#")}
    for velho, novo in DE_PARA.items():
        if novo and ("/icones/apps/arcticons/" in velho or "/icones/sistema/arcticons/" in velho) and novo.endswith(".svg"):
            nomes.add(os.path.basename(novo))
    if nomes:
        escrever(lista, "# Os glifos do Arcticons (CC BY-SA 4.0, licencas/arcticons.txt) no pack-base, um por linha:\n"
                        "# o nome do arquivo numa das três pastas. O resto da pasta é convertido, retoque ou autoral.\n"
                        + "\n".join(sorted(nomes)) + "\n")
    # o glifo que mudou de nome muda no mapa que o pede (campo 2 de nome:glifo:cor)
    for mapa in ("sistema.map", "bandeja.map", "apps-arcticons.map", "apps-marca.map"):
        mp = os.path.join(IC, mapa)
        if not renomear_glifo or not os.path.exists(mp):
            continue
        saida = []
        for l in open(mp, encoding="utf-8").read().split("\n"):
            m = re.match(r"^([^#:\s][^:]*):([^:#\s]+)(.*)$", l)
            if m and m.group(2) in renomear_glifo:
                l = f"{m.group(1)}:{renomear_glifo[m.group(2)]}{m.group(3)}"
            saida.append(l)
        escrever(mp, "\n".join(saida).rstrip("\n") + "\n")
    # o vencedor que mora fora do pack-base entra com o nome do aplicativo (escolha de 23/10)
    for c, nome in de_fora:
        para = os.path.join(IC, "apps", nome)
        if os.path.exists(c) and not (os.path.exists(para) and sha(para) == sha(c)):
            if os.path.exists(para) and APLICAR:
                raise SystemExit(f"recusa: {rel(para)} ainda ocupado")
            entrar(c, para)
            retoques.add(nome[:-4])
    # o construtor precisa saber quem é retoque: a palavra `retoque` no 4º campo do mapa
    mp = os.path.join(IC, "apps-convertidos.map")
    if retoques and os.path.exists(mp):
        linhas = []
        for l in open(mp, encoding="utf-8").read().split("\n"):
            m = re.match(r"^([^#:\s][^:]*):([^:]*):([^:#]*)(?::([^#]*))?(\s*#.*)?$", l)
            if m and m.group(1).strip() in retoques and m.group(2).strip() != "mao":
                extra = (m.group(4) or "").strip()
                if "retoque" not in extra.split():
                    extra = (extra + " retoque").strip()
                l = f"{m.group(1)}:{m.group(2)}:{m.group(3).rstrip()}:{extra}{m.group(5) or ''}"
            linhas.append(l)
        escrever(mp, "\n".join(linhas).rstrip("\n") + "\n")


# =========================================================================================
# 3. o Dracula: as escolhas de quem usa, depois o plano
# =========================================================================================
def ler_escolhas():
    grupos = json.load(open(ESCOLHAS, encoding="utf-8"))
    resolvidas = {}
    with open(TSV, encoding="utf-8") as fh:
        for linha in csv.DictReader(fh, delimiter="\t"):
            resolvidas[linha["grupo"]] = (linha["opcao_que_veste"].strip(),
                                          {x.strip() for x in (linha.get("opcoes_que_saem") or "").split(",") if x.strip()})
    return grupos, resolvidas


def externo(caminho):
    return os.path.isabs(caminho)


def caminho_real(c):
    return c if externo(c) else os.path.join(RAIZ, c)


VESTE_EXTRA = {   # nomes que passam a vestir um desenho que entrou agora (projetos pessoais, 23/10)
    "com.beholder.app": "com.beholder.app.svg",
    "elden-ring-tracker": "elden-ring-tracker.svg",
    "protocolo-ouroboros": "protocolo-ouroboros.svg",
    "io.github.andrebfarias.Mnemo": "mnemo.svg",
    # VS Code: quem usa quis o vscode.svg vestindo o app (23/10); os três nomes que o .desktop dele usa
    "code": "vscode.svg",
    "vscode": "vscode.svg",
    "com.visualstudio.code": "vscode.svg",
}
VESTE_DO_APP = {"code", "vscode", "com.visualstudio.code"}   # não é projeto pessoal: é o VS Code
# nome do mapa cujo alvo é de dois grupos: a qual grupo ele pertence
NOME_DO_GRUPO = {"io.github.cosmic_utils.camera": "camera-cosmic", "guvcview": "guvcview"}


def ler_mapa_apps(p):
    linhas = open(p, encoding="utf-8").read().split("\n")
    itens = []   # (indice, nome, alvo)
    for i, l in enumerate(linhas):
        m = re.match(r"^(\s*)([^#\s:][^:]*?)(\s*:\s*)(\S+)(.*)$", l)
        if m and not m.group(4).startswith(("motor:", "pack:")):
            itens.append((i, m.group(2).strip(), m.group(4)))
    return linhas, itens


def nome_limpo(f):
    """O nome no lugar novo: a versão deixa o `-<sha8>` que só a distinguia dentro de versoes/."""
    n = os.path.basename(f)
    if os.sep + "versoes" + os.sep in f:
        n = re.sub(r"-[0-9a-f]{8}(\.[a-z]+)$", r"\1", n)
    return n


def aplanar_dracula(grupos, resolvidas):
    IC = os.path.join(DRAC, "icones")
    if not os.path.isdir(IC):
        return {}
    mapa_p = os.path.join(IC, "apps.map")
    linhas, itens = ler_mapa_apps(mapa_p)
    # o rótulo que o mapa dava a cada app (`# Waterfox — ...` -> `Waterfox`), lido antes da reescrita
    rotulo_do_mapa = {}
    for i, nome, _alvo in itens:
        coment = linhas[i].partition("#")[2]
        r = coment.split(" — ")[0].split(" [")[0].strip()
        if r:
            rotulo_do_mapa.setdefault(nome, r)
    resg = [l.split(":")[0].strip() for l in open(os.path.join(IC, "apps-resgatados.map"), encoding="utf-8")
            if l.strip() and not l.lstrip().startswith("#")]
    mascote = os.path.join(DRAC, "mascote")
    sha_mascote = {}
    if os.path.isdir(mascote):
        for f in sorted(os.listdir(mascote)):
            sha_mascote[sha(os.path.join(mascote, f))] = os.path.join(mascote, f)

    # ---- o que existe: arquivo rastreado -> sha
    arquivos, catalogos, mimetypes = {}, [], []
    for f in rastreados(rel(IC)):
        r = os.path.relpath(os.path.join(RAIZ, f), IC).split(os.sep)
        if r[-1] == "catalog.json":
            catalogos.append(os.path.join(RAIZ, f)); continue
        if len(r) == 1:
            continue
        if r[:2] == ["sistema", "mimetypes"]:
            mimetypes.append(f); continue
        if not f.endswith(EXT):
            raise SystemExit(f"recusa: não sei onde pôr {f}")
        arquivos[f] = sha(os.path.join(RAIZ, f))

    # ---- os soltos: o conteúdo que fica naquele caminho
    conteudo_novo, sai_caminho = {}, set()
    for g in grupos:
        if g["secao"] != "soltos":
            continue
        veste = resolvidas.get(g["id"], (g["recomendado"], set()))[0]
        o = {x["id"]: x for x in g["opcoes"]}.get(veste)
        p = g["opcoes"][0]["caminho"]
        if o is None or p not in arquivos:
            continue
        if not o["caminho"]:
            sai_caminho.add(p)
        elif o["caminho"] != p and os.path.exists(caminho_real(o["caminho"])):
            conteudo_novo[p] = caminho_real(o["caminho"])
            arquivos[p] = sha(conteudo_novo[p])
    por_sha = collections.defaultdict(list)
    for f, h in sorted(arquivos.items()):
        por_sha[h].append(f)

    # ---- quem veste o quê (por conteúdo)
    nomes_de_sha = collections.defaultdict(set)
    for _i, nome, alvo in itens:
        f = rel(os.path.join(IC, alvo))
        if f in arquivos:
            nomes_de_sha[arquivos[f]].add(nome)
    for nome in resg:
        for f in (rel(os.path.join(IC, "apps", "resgatados", nome + ".svg")), rel(os.path.join(IC, "apps", nome + ".svg"))):
            if f in arquivos:
                nomes_de_sha[arquivos[f]].add(nome)
                break
    for nome, arq in VESTE_EXTRA.items():
        c = os.path.join(MANUAIS, arq)
        if os.path.exists(c):
            nomes_de_sha[sha(c)].add(nome)

    # ---- os grupos
    ORD = {"sai": 1, "biblioteca": 2, "veste": 3}
    fim_de = {}                                      # sha -> veste|biblioteca|sai
    venceu = collections.defaultdict(set)            # sha -> grupos
    nomes_grupo = collections.defaultdict(set)
    destino_grupo = {}
    externo_de = {}                                  # sha -> caminho de fora
    externo_do_grupo = {}                            # grupo -> o caminho de fora que ele veste
    for g in grupos:
        if g["secao"] == "soltos" or g["id"].startswith("traco-"):
            continue
        veste, saem = resolvidas.get(g["id"], (g["recomendado"],
                                     {o["id"] for o in g["opcoes"] if o.get("sugestao") == "sai" and o["id"] != g["recomendado"]}))
        opc = {o["id"]: o for o in g["opcoes"]}
        if veste not in opc:
            raise SystemExit(f"recusa: o grupo {g['id']} não tem a opção {veste!r}")
        sha_opc = collections.defaultdict(list)       # opção -> shas (o primeiro é o do caminho principal)
        for o in g["opcoes"]:
            for c in [o["caminho"]] + list(o.get("tambem") or []):
                if not c:
                    continue
                if externo(c):
                    if not os.path.exists(c):
                        # sumiu de fora depois das escolhas: o mesmo nome dentro do pack (era cópia dele)
                        iguais = [f for f in arquivos if os.path.basename(f).lower() == os.path.basename(c).lower()]
                        if len(iguais) == 1:
                            nota("aviso", f"{c} não existe mais; uso {iguais[0]}, de mesmo nome, no lugar")
                            h = arquivos[iguais[0]]
                            if h not in sha_opc[o["id"]]:
                                sha_opc[o["id"]].append(h)
                        elif o["id"] == veste and not os.path.exists(os.path.join(PACKS, "CAMINHOS-DE-ANTES.tsv")):
                            raise SystemExit(f"recusa: o grupo {g['id']} veste {c}, que não existe mais")
                        continue
                    h = sha(c); externo_de.setdefault(h, c)
                elif c in arquivos:
                    h = arquivos[c]
                else:
                    continue
                if h not in sha_opc[o["id"]]:
                    sha_opc[o["id"]].append(h)
        if not sha_opc.get(veste):
            continue                                  # já aplicado
        W = sha_opc[veste][0]
        if externo(opc[veste]["caminho"]) and os.path.exists(opc[veste]["caminho"]):
            externo_do_grupo[g["id"]] = opc[veste]["caminho"]
        if os.environ.get("P96_DEPURAR") and g["id"] in os.environ["P96_DEPURAR"].split(","):
            print("DEPURAR", g["id"], veste, saem, {k: [x[:8] for x in v] for k, v in sha_opc.items()},
                  {k[:8]: sorted(v) for k, v in nomes_de_sha.items() if any(k in v2 for v2 in sha_opc.values())}, file=sys.stderr)
        venceu[W].add(g["id"])
        destino_grupo[g["id"]] = g["destino"]
        for oid, hs in sha_opc.items():
            for k, h in enumerate(hs):
                if oid == veste:
                    # a cópia de antes do mesmo desenho (quem usa editou depois): é versão velha, sai
                    fim = "veste" if k == 0 else "sai"
                else:
                    fim = "sai" if oid in saem else "biblioteca"
                if ORD[fim] > ORD.get(fim_de.get(h), 0):
                    fim_de[h] = fim
                for nome in nomes_de_sha.get(h, ()):
                    dono = NOME_DO_GRUPO.get(nome)
                    if dono is None or dono == g["id"]:
                        nomes_grupo[g["id"]].add(nome)
    nome_vai_para = {}                               # nome -> sha do vencedor do grupo
    de_quem = collections.defaultdict(set)
    for W, gids in venceu.items():
        for gid in gids:
            for nome in nomes_grupo[gid]:
                de_quem[nome].add(W)
                nome_vai_para[nome] = W
    ambiguos = sorted(n for n, ws in de_quem.items() if len(ws) > 1)
    if ambiguos:
        raise SystemExit("recusa: nomes que dois grupos querem vestir com desenhos diferentes: " + ", ".join(ambiguos))

    # ---- onde cada conteúdo termina
    ocupados, final = {}, {}
    def nomes_que_ficam(h):
        return {n for n in nomes_de_sha.get(h, ()) if nome_vai_para.get(n, h) == h} | \
               {n for n, w in nome_vai_para.items() if w == h}
    for W in sorted(venceu, key=lambda h: sorted(venceu[h])):
        if W in sha_mascote:
            final[W] = None; continue
        nomes = nomes_que_ficam(W)
        if any(destino_grupo[g] == "sistema" for g in venceu[W]):
            pasta = "sistema"
        elif nomes:
            pasta = "apps"
        else:
            pasta = "biblioteca"
        rs = sorted(n for n in nomes if n in resg)
        if rs:
            nome = rs[0] + ".svg"
        else:
            cands = sorted(por_sha.get(W, []), key=lambda f: (os.sep + "apps" + os.sep not in f, f))
            # de fora, com o mesmo conteúdo em dois nomes (o firefox e o waterfox): o nome do grupo
            # que veste um aplicativo
            fora = sorted((not nomes_grupo[g], externo_do_grupo[g]) for g in venceu[W] if g in externo_do_grupo)
            if cands:
                nome = nome_limpo(cands[0])
            else:
                nome = os.path.basename(fora[0][1] if fora else externo_de[W]).lstrip("_")
        final[W] = destino_livre(os.path.join(IC, pasta), nome, W, ocupados)
    # O caminho de uma opção da página é a identidade dela numa passada futura: depois dos vencedores
    # (que têm o nome certo, o do resgatado inclusive), nenhum outro desenho herda o nome de uma opção
    # — senão a segunda passada o confundiria com ela.
    for g in grupos:
        if g["secao"] == "soltos":
            continue
        for o in g["opcoes"]:
            for c in [o["caminho"]] + list(o.get("tambem") or []):
                if c and not externo(c) and c in arquivos:
                    ocupados.setdefault(os.path.join(RAIZ, c), arquivos[c])
    for h, fs in sorted(por_sha.items(), key=lambda x: x[1]):
        if h in final:
            continue
        if fim_de.get(h) == "sai" or h in sha_mascote or all(f in sai_caminho for f in fs):
            final[h] = None; continue
        nomes = nomes_que_ficam(h)
        topos = {f.split(os.sep)[3] for f in fs}
        if "sistema" in topos:
            pasta = "sistema"
        elif nomes or any(os.sep + "autorais" + os.sep in f for f in fs):
            pasta = "apps"
        elif fim_de.get(h) == "biblioteca" or "apps" not in topos:
            pasta = "biblioteca"
        else:
            pasta = "apps"
        prefer = sorted(fs, key=lambda f: (f.split(os.sep)[3] != pasta, f.count(os.sep), f))
        nome = nome_limpo(prefer[0])
        livre = os.path.join(IC, pasta, nome)
        if ocupados.get(livre, h) != h and nomes:
            # o nome do arquivo já é de outro desenho: usa o nome do aplicativo que ele veste
            nome = sorted(nomes)[0] + os.path.splitext(nome)[1]
        final[h] = destino_livre(os.path.join(IC, pasta), nome, h, ocupados)
    # de fora, para a biblioteca (alternativa que quem usa guardou) ou vestindo um projeto pessoal
    for h, c in sorted(externo_de.items(), key=lambda x: x[1]):
        if h in final or h in sha_mascote:
            continue
        if fim_de.get(h) == "biblioteca":
            final[h] = destino_livre(os.path.join(IC, "biblioteca"), os.path.basename(c).lstrip("_"), h, ocupados)
    extra_nome = {}
    for nome, arq in VESTE_EXTRA.items():
        c = os.path.join(MANUAIS, arq)
        if not os.path.exists(c):
            continue
        h = sha(c)
        if h not in final:
            externo_de.setdefault(h, c)
            final[h] = destino_livre(os.path.join(IC, "apps"), arq, h, ocupados)
        extra_nome[nome] = h

    # ---- aplicar: tirar, levar para a coxia, trazer para o lugar, entrar de fora
    fonte_de = {}
    for h, fs in por_sha.items():
        dest = final.get(h)
        if dest is None:
            for f in fs:
                DE_PARA[f] = rel(sha_mascote[h]) if h in sha_mascote else ""
                tirar(os.path.join(RAIZ, f))
            continue
        fonte = sorted(fs, key=lambda f: (os.path.join(RAIZ, f) != dest, f in conteudo_novo, f))[0]
        fonte_de[h] = fonte
        for f in fs:
            DE_PARA[f] = rel(dest)
            if f != fonte:
                tirar(os.path.join(RAIZ, f))
    for f in mimetypes:
        DE_PARA[f] = ""
        tirar(os.path.join(RAIZ, f))
    coxia = os.path.join(DRAC, ".p96-coxia")
    em_coxia = []
    for i, (h, f) in enumerate(sorted(fonte_de.items(), key=lambda x: x[1])):
        dest = final[h]
        if f in conteudo_novo:
            tirar(os.path.join(RAIZ, f))
            em_coxia.append((conteudo_novo[f], dest, True))
        elif os.path.join(RAIZ, f) != dest:
            tmp = os.path.join(coxia, f"{i:05d}-" + os.path.basename(f))
            if APLICAR:
                os.makedirs(coxia, exist_ok=True)
                git("mv", "--", f, rel(tmp))
            em_coxia.append((tmp, dest, False))
            nota("move", f, rel(dest))
    for tmp, dest, de_fora in em_coxia:
        if de_fora:
            entrar(tmp, dest)
        elif APLICAR:
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            git("mv", "--", rel(tmp), rel(dest))
    if APLICAR and os.path.isdir(coxia):
        os.rmdir(coxia)
    novo_de = {}
    for h, dest in final.items():
        if dest and h not in fonte_de and h in externo_de:
            entrar(externo_de[h], dest)
            novo_de[externo_de[h]] = dest

    # ---- o apps.map
    for i, nome, alvo in itens:
        f = rel(os.path.join(IC, alvo))
        h = nome_vai_para.get(nome) or arquivos.get(f)
        dest = final.get(h) if h else None
        if not dest:
            if f in arquivos or nome in nome_vai_para:
                raise SystemExit(f"recusa: {nome} veste {alvo}, que saiu sem ninguém no lugar")
            continue
        novo = os.path.relpath(dest, IC)
        if novo != alvo:
            linhas[i] = re.sub(r"(:\s*)" + re.escape(alvo), lambda m: m.group(1) + novo, linhas[i], count=1)
            if nome in nome_vai_para and "#" in linhas[i] and arquivos.get(f) != nome_vai_para[nome]:
                # o comentário dizia por que vestia o desenho de antes; agora veste o escolhido
                util, _sep, coment = linhas[i].partition("#")
                rotulo = coment.split(" — ")[0].split(" [")[0].strip()
                linhas[i] = f"{util}# {rotulo} — o desenho escolhido por quem usa em 23/10 (P96)"
    ja = {n for _i, n, _a in itens}
    extra = []
    for nome, h in extra_nome.items():
        if nome not in ja and final.get(h):
            porque = ("o desenho do manuais-final, escolhido por quem usa (P96, 23/10/2026)" if nome in VESTE_DO_APP
                      else "projeto pessoal — entra no Dracula (P96, 23/10/2026)")
            extra.append(f"{nome:<28} : {os.path.relpath(final[h], IC)}   # {porque}")
    # o resgatado cujo desenho escolhido não se chama <nome>.svg: uma linha no apps.map o leva
    for nome in resg:
        h = nome_vai_para.get(nome) or arquivos.get(rel(os.path.join(IC, "apps", "resgatados", nome + ".svg"))) \
            or arquivos.get(rel(os.path.join(IC, "apps", nome + ".svg")))
        dest = final.get(h) if h else None
        if dest and os.path.basename(dest) != nome + ".svg" and nome not in ja:
            extra.append(f"{nome:<28} : {os.path.relpath(dest, IC)}   # P96: o desenho escolhido em 23/10")
    while linhas and not linhas[-1].strip():
        linhas.pop()
    if extra:
        linhas += ["", "# --- P96 (23/10/2026) ---"] + extra
    escrever(mapa_p, "\n".join(linhas) + "\n")

    # ---- os catálogos: um por pasta, a chave é o nome do arquivo
    junto = {p: collections.OrderedDict() for p in TRES}
    for cat in catalogos:
        pasta_velha = os.path.dirname(cat)
        for nome, info in ler_json(cat).items():
            velho = rel(os.path.join(pasta_velha, nome))
            destino = DE_PARA.get(velho)
            if destino is None:
                destino = velho if velho in arquivos else ""
            if not destino or not destino.startswith(rel(IC) + os.sep):
                continue
            pasta = destino.split(os.sep)[3]
            if pasta not in junto:
                continue
            info = collections.OrderedDict(info)
            if "nome" in info:
                info["nome"] = os.path.splitext(os.path.basename(destino))[0]
            # Na biblioteca, a descrição É o rótulo do seletor. A do catálogo de apps que é nota de
            # procedência (`Firefox do dracula-icons (circle) — Firefox/Waterfox`) vira o nome do app
            # que o mapa dava ao desenho.
            stem = os.path.splitext(os.path.basename(destino))[0]
            if pasta == "biblioteca" and " — " in str(info.get("descricao") or "") \
                    and os.sep + "biblioteca" + os.sep not in velho and stem in rotulo_do_mapa:
                info["descricao"] = rotulo_do_mapa[stem]
            junto[pasta].setdefault(os.path.basename(destino), info)
    for cat in catalogos:
        if os.path.dirname(cat) not in [os.path.join(IC, p) for p in TRES]:
            tirar(cat)
    # todo desenho da biblioteca tem descrição no catálogo (o seletor busca por ela); o que veio de
    # uma pasta de origem sem catálogo ganha a do nome e da origem
    ORIGEM_LEGIVEL = {"feitos-a-mao": "feito à mão", "versoes": "versão", "projetos": "projeto dela",
                      "resgatados": "resgatado", "autorais": "autoral"}
    de_onde = {v: k for k, v in DE_PARA.items() if v}
    for pasta in ("biblioteca",):
        d = os.path.join(IC, pasta)
        for nome in sorted(os.listdir(d)) if os.path.isdir(d) else []:
            if not nome.endswith(".svg") or str((junto[pasta].get(nome) or {}).get("descricao") or "").strip():
                continue
            stem = nome[:-4]
            # o id de app (domínio invertido) vira a última parte dele: o rótulo é de gente
            base_nome = stem.rsplit(".", 1)[-1] if re.match(r"^[a-z]+\.[A-Za-z0-9_.-]+\.", stem) else stem
            legivel = re.sub(r"[-_]+", " ", base_nome).strip()
            velho = de_onde.get(rel(os.path.join(d, nome)), "")
            sub = velho.split(os.sep)[4] if velho.count(os.sep) >= 5 else ""
            info = collections.OrderedDict(junto[pasta].get(nome) or {})
            info["descricao"] = legivel[:1].upper() + legivel[1:] + (f" · {ORIGEM_LEGIVEL[sub]}" if sub in ORIGEM_LEGIVEL else "")
            info.setdefault("nome", stem)
            info.setdefault("tags", [stem.lower()])
            junto[pasta][nome] = info
    for pasta, dados in junto.items():
        if dados:
            escrever(os.path.join(IC, pasta, "catalog.json"),
                     json_texto(collections.OrderedDict(sorted(dados.items(), key=lambda x: x[0].lower()))))
    return novo_de


# =========================================================================================
# 4. os pack.json do Dracula, e os temas de aplicativo
# =========================================================================================
def pack_json_dracula():
    p = os.path.join(DRAC, "pack.json")
    d = ler_json(p)
    if d.get("heranca") == "catppuccin":
        d["heranca"] = "meowsystem"
    ic = d.get("icones") or {}
    if "resgatados" in ic:
        ic["resgatados"]["desenhos"] = "icones/apps/"
    if "pastas" in ic:
        ic["pastas"]["desenhos"] = "icones/sistema/"
    if "autorais" in ic:
        ic["autorais"]["desenhos"] = "icones/apps/"
    if "mimetypes" in ic:
        ic["mimetypes"] = collections.OrderedDict([
            ("herda", "meowsystem"),
            ("_nota", "Os 656 tipos de arquivo vêm do molde do pack meowsystem, pintados na instalação com a "
                      "paleta deste pack (P96, 23/10/2026). Até aqui eram dois diretórios pintados à mão, um por flavor.")])
    for app, bloco in (d.get("apps") or {}).items():
        if isinstance(bloco, dict) and isinstance(bloco.get("arquivo"), str) and bloco["arquivo"].startswith("apps/"):
            nome = bloco["arquivo"][len("apps/"):]
            de = os.path.join(DRAC, "apps", nome)
            if ".modelo." in nome:
                para = os.path.join(RAIZ, "scripts", "temas-de-apps", app, nome)
                del bloco["arquivo"]
            else:
                para = os.path.join(DRAC, "temas-de-apps", app, nome)
                bloco["arquivo"] = f"temas-de-apps/{app}/{nome}"
            if os.path.exists(de):
                mover(de, para)
                registrar(de, para)
    escrever(p, json_texto(d))
    # o que sobrou em packs/dracula/apps/ (procedência dos temas, se houver)
    for f in rastreados(rel(os.path.join(DRAC, "apps"))):
        a = os.path.join(RAIZ, f)
        para = os.path.join(DRAC, "temas-de-apps", os.path.basename(f))
        mover(a, para)
        registrar(a, para)


# =========================================================================================
# 5. PROCEDENCIA.md: o caminho novo em cada linha; a linha do que saiu sai junto
# =========================================================================================
def procedencias(novo_de):
    for pid in ("dracula", "meowsystem"):
        p = os.path.join(PACKS, pid, "PROCEDENCIA.md")
        if not os.path.exists(p):
            continue
        base = os.path.join("packs", pid) + os.sep
        texto = open(p, encoding="utf-8").read()
        trocas = {}
        for velho, novo in DE_PARA.items():
            if velho.startswith(base) or velho.startswith("packs/catppuccin/"):
                rv = velho.split(os.sep, 2)[2]
                rn = novo.split(os.sep, 2)[2] if novo and novo.startswith(base) else ("" if not novo else novo)
                trocas[rv] = rn
        saida = []
        for linha in texto.split("\n"):
            m = re.match(r"^\| `([^`]+)` \|", linha)
            if m and m.group(1) in trocas and trocas[m.group(1)] == "":
                continue                                   # a linha do arquivo que saiu
            def troca(mm):
                v = mm.group(1)
                n = trocas.get(v)
                if n:
                    return f"`{n}`"
                # o padrão ou a pasta de antes (`icones/sistema/pastas/*.svg`): a pasta plana de hoje
                plano = re.match(r"^icones/(apps|sistema|biblioteca)/(?:resgatados|autorais|pastas|mimetypes|feitos-a-mao|versoes|projetos|arcticons|convertidos|retoques|leitura)/(\*\.svg|\*|)$", v)
                if plano:
                    return f"`icones/{plano.group(1)}/{plano.group(2)}`"
                return mm.group(0)
            linha = re.sub(r"`([^`]+)`", troca, linha)
            # a coluna «lido de» que aponta para dentro de um pack (`pack:<id>:<caminho>`): o caminho
            # de hoje, quando a cópia ainda é igual a ele; senão a linha vira só registro (a origem
            # interna saiu ou é outro desenho — uma versão por ícone)
            celulas = linha.split("|")
            if m and len(celulas) > 4 and "pack:" in celulas[3]:
                lido = re.search(r"pack:([a-z0-9-]+):([^`\s|]+)", celulas[3])
                sha_linha = re.findall(r"`([0-9a-f]{64})`", linha)
                if lido:
                    velho = os.path.join("packs", lido.group(1), "icones", lido.group(2))
                    novo = DE_PARA.get(velho, velho)
                    cheio = os.path.join(RAIZ, novo) if novo else ""
                    if novo and os.path.isfile(cheio) and sha_linha and sha(cheio) == sha_linha[-1]:
                        celulas[3] = celulas[3].replace(lido.group(2), novo.split(os.sep, 3)[3])
                    elif novo != velho or not os.path.isfile(cheio):
                        celulas[3] = " "
                    linha = "|".join(celulas)
            saida.append(linha)
        # as linhas do que entrou de fora
        novas = []
        presentes = set(re.findall(r"^\| `([^`]+)` \|", "\n".join(saida), re.M))
        for c, para in novo_de.items():
            if not (para and os.path.isabs(c)) or not para.startswith(os.path.join(PACKS, pid) + os.sep):
                continue
            r = os.path.relpath(para, os.path.join(PACKS, pid))
            if r in presentes:
                continue
            fonte = ("manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026)" if c.startswith(MANUAIS)
                     else "rascunho de `.trabalho-icones/svg/`, escolhido por quem usa em 23/10/2026"
                     if c.startswith(TRABALHO) else "o checkout principal, mexido à mão por quem usa")
            novas.append(f"| `{r}` | {fonte}; fonte: P96 |  | GPL-3.0 | 2026-10-23 | `{sha(c)}` |")
        # todo desenho da biblioteca tem a linha dele (a regra que o tests/pack.sh cobra): o que
        # chegou lá agora, vindo de uma pasta que não tinha linha (os resgatados), ganha uma
        de_onde = {v: k for k, v in DE_PARA.items() if v}
        bib = os.path.join(PACKS, pid, "icones", "biblioteca")
        presentes |= {re.sub(r"^.*?`", "", l.split("|")[1]).strip().strip("`") for l in novas}
        for nome in sorted(os.listdir(bib)) if os.path.isdir(bib) else []:
            if not nome.endswith(EXT):
                continue
            r = os.path.join("icones", "biblioteca", nome)
            if r in presentes:
                continue
            velho = de_onde.get(os.path.join("packs", pid, r), "")
            origem = f"antes em `{velho.split(os.sep, 2)[2]}`" if velho else "desenho do pack"
            novas.append(f"| `{r}` | {origem}; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | "
                         f"`{sha(os.path.join(bib, nome))}` |")
        if novas:
            # depois da última linha da tabela das artes
            linhas_tab = [i for i, l in enumerate(saida) if re.match(r"^\| `icones/", l)]
            if linhas_tab:
                saida[linhas_tab[-1] + 1:linhas_tab[-1] + 1] = novas
            else:
                saida += ["", "## O que entrou na P96 (23/10/2026)", "",
                          "| arquivo | de onde | lido de | licença | copiado em | sha256 |", "|---|---|---|---|---|---|"] + novas
        escrever(p, "\n".join(saida))


def aplanar_exemplo(d):
    """O pack de exemplo da documentação (docs/pack-minimo) no formato de hoje: três pastas planas."""
    IC = os.path.join(d, "icones")
    if not os.path.isdir(IC):
        return
    for f in rastreados(rel(IC)):
        a = os.path.join(RAIZ, f)
        r = os.path.relpath(a, IC).split(os.sep)
        if len(r) > 2 and r[0] in TRES:
            para = os.path.join(IC, r[0], r[-1])
            mover(a, para)
            registrar(a, para)
    pj = os.path.join(d, "pack.json")
    dados = ler_json(pj)
    for bloco in (dados.get("icones") or {}).values():
        if isinstance(bloco, dict) and isinstance(bloco.get("desenhos"), str):
            partes = bloco["desenhos"].strip("/").split("/")
            if len(partes) > 2 and partes[0] == "icones" and partes[1] in TRES:
                bloco["desenhos"] = f"icones/{partes[1]}/"
    escrever(pj, json_texto(dados))


def resgatados_depois_da_folha():
    """O resgatado cujo desenho mudou na P96 entra na tabela «depois da folha de <data>» do
    PROCEDENCIA do pack-base (a regra que o tests/frases-velhas.sh cobra), até a folha ser refeita."""
    mapa = os.path.join(DRAC, "icones", "apps-resgatados.map")
    proc = os.path.join(MEOW, "PROCEDENCIA.md")
    if not os.path.exists(mapa) or not os.path.exists(proc):
        return
    folha = subprocess.run(["git", "-C", RAIZ, "log", "-1", "--follow", "--diff-filter=AM", "--date=format:%d/%m/%Y",
                            "--format=%ad", "--", "assets/icones/resgatados-antes-e-depois.png"],
                           capture_output=True, text=True).stdout.strip()
    if not folha:
        return
    mudaram = []
    for l in open(mapa, encoding="utf-8"):
        l = l.split("#")[0]
        if ":" not in l:
            continue
        nome = l.split(":")[0].strip()
        antes = subprocess.run(["git", "-C", RAIZ, "rev-parse", "-q", "--verify",
                                f"HEAD:packs/dracula/icones/apps/resgatados/{nome}.svg"],
                               capture_output=True, text=True).stdout.strip()
        agora_p = os.path.join(DRAC, "icones", "apps", nome + ".svg")
        if not antes or not os.path.exists(agora_p):
            continue
        agora = subprocess.run(["git", "hash-object", "--", agora_p], capture_output=True, text=True).stdout.strip()
        if agora != antes:
            mudaram.append(nome)
    texto = open(proc, encoding="utf-8").read()
    cab = f"| resgatado — depois da folha de {folha} | o que mudou |"
    if not mudaram or cab in texto:
        return
    linhas = ["", f"### Os resgatados que mudaram na P96 (23/10/2026)", "",
              "Quem usa escolheu uma versão por ícone (a página de escolha de 23/10); estes vestem agora",
              "outro desenho que o da folha. A tabela vale até a folha ser refeita.", "",
              cab, "|---|---|"] + [f"| `{n}` | o desenho escolhido em 23/10 |" for n in mudaram]
    # dentro da nota da folha (do «ANTES-E-DEPOIS» até o próximo «## »), que é onde a regra lê
    ini = texto.find("ANTES-E-DEPOIS")
    fim = texto.find("\n## ", ini) if ini >= 0 else -1
    if fim < 0:
        escrever(proc, texto.rstrip("\n") + "\n" + "\n".join(linhas) + "\n")
    else:
        escrever(proc, texto[:fim] + "\n".join(linhas).replace("### ", "#### ") + "\n" + texto[fim:])


# =========================================================================================
def main():
    grupos, resolvidas = ler_escolhas()
    escolha_meow = {}
    de_fora_meow = []          # (origem, nome no apps/ do meowsystem): o vencedor que mora fora do pack
    for g in grupos:
        if not g["id"].startswith("traco-"):
            continue
        veste, saem = resolvidas.get(g["id"], (g["recomendado"], set()))
        alvo_nome = os.path.basename(g["opcoes"][0]["caminho"])
        for o in g["opcoes"]:
            fim = "veste" if o["id"] == veste else ("sai" if o["id"] in saem else "biblioteca")
            c = caminho_real(o["caminho"])
            if fim == "veste" and not o["caminho"].startswith("packs/meowsystem/"):
                de_fora_meow.append((c, alvo_nome))
                # quem tinha o nome vai para a biblioteca
                escolha_meow[g["opcoes"][0]["caminho"]] = escolha_meow.get(g["opcoes"][0]["caminho"], "biblioteca")
                continue
            if o["caminho"].startswith("packs/meowsystem/"):
                escolha_meow[o["caminho"]] = fim
                if os.path.exists(c):
                    escolha_meow["sha:" + sha(c)] = fim
    unir_catppuccin()
    titulos_dos_autorais()
    aplanar_meowsystem(escolha_meow, de_fora_meow)
    novo_de = aplanar_dracula(grupos, resolvidas)
    pack_json_dracula()
    procedencias(novo_de)
    resgatados_depois_da_folha()
    aplanar_exemplo(os.path.join(RAIZ, "docs", "pack-minimo"))
    # a tabela de-para, para a casa de quem usa e para o caminho_de_hoje
    tabela = os.path.join(PACKS, "CAMINHOS-DE-ANTES.tsv")
    linhas = ["# caminho de antes da P96 (23/10/2026)\tcaminho de hoje (vazio: saiu; quem vestia, veste o escolhido)"]
    antiga = {}
    if os.path.exists(tabela):
        for l in open(tabela, encoding="utf-8").read().split("\n")[1:]:
            if "\t" in l:
                k, v = l.split("\t", 1)
                antiga[k] = v
    antiga.update({k: v for k, v in DE_PARA.items() if k != v})
    linhas += [f"{k}\t{v}" for k, v in sorted(antiga.items())]
    if DE_PARA:
        escrever(tabela, "\n".join(linhas) + "\n")
    if APLICAR:
        for base in (PACKS, os.path.join(RAIZ, "docs", "pack-minimo"), os.path.join(RAIZ, "scripts", "temas-de-apps")):
            for raiz, dirs, arqs in os.walk(base, topdown=False):
                if os.path.isdir(raiz) and not os.listdir(raiz) and raiz != base:
                    os.rmdir(raiz)
        sobra = os.path.join(RAIZ, "scripts", "temas-de-apps")
    cont = collections.Counter(v for v, _a, _b in plano)
    if os.environ.get("P96_DETALHE"):
        for v, a, b in plano:
            print(f"{v:9} {a}" + (f"  ->  {b}" if b else ""))
    else:
        # o que entra de fora, o aviso e o que se reescreve: um por linha (são poucos e importam)
        for v, a, b in plano:
            if v in ("entra", "aviso", "reescreve"):
                print(f"{v:9} {a}" + (f"  ->  {b}" if b else ""))
        # mover e tirar, por pasta (milhares de linhas; P96_DETALHE=1 lista um por um)
        grupos = collections.Counter()
        for v, a, b in plano:
            if v == "move":
                grupos[(v, os.path.dirname(a), os.path.dirname(b))] += 1
            elif v == "sai":
                grupos[(v, os.path.dirname(a), "")] += 1
        for (v, a, b), n in sorted(grupos.items(), key=lambda x: (x[0][0], x[0][1])):
            print(f"{v:9} {n:5}  {a}/" + (f"  ->  {b}/" if b else ""))
    print("resumo:", dict(cont) if cont else "nada a fazer")


main()
#__arte.py__
"""A conferência da arte que entra num pack: nada do desenho fora do viewBox, nenhum non-scaling-stroke.

corrigir_svg(bytes) -> (bytes, [o que mudou]). Idempotente: o que sai daqui, passado de novo, volta igual.
"""
import io, re, subprocess
from PIL import Image

RE_VB = re.compile(r'(<svg\b[^>]*?\bviewBox=")([^"]+)(")', re.S)
RE_NS_ESTILO = re.compile(r"vector-effect\s*:\s*non-scaling-stroke\s*;?\s*", re.I)
RE_NS_ATTR = re.compile(r'\s+vector-effect\s*=\s*"non-scaling-stroke"', re.I)
TOLERANCIA = 0.005      # 0,5% do lado: o anti-serrilhado de um desenho que só encosta na borda
FOLGA = 2.0             # unidades de folga entre o desenho e a borda nova (a mesma da correção de 23/10)


def _vb(texto):
    m = RE_VB.search(texto)
    if not m:
        return None
    v = [float(x) for x in re.split(r"[\s,]+", m.group(2).strip())]
    return v if len(v) == 4 and v[2] > 0 and v[3] > 0 else None


def _com_vb(texto, vb):
    num = " ".join(f"{x:.3f}".rstrip("0").rstrip(".") for x in vb)
    return RE_VB.sub(lambda m: m.group(1) + num + m.group(3), texto, count=1)


def _caixa(texto, vb):
    """A caixa do desenho em unidades do viewBox, medida pelo render (pixel com alfa > 16)."""
    x, y, w, h = vb
    largo = [x - w / 2, y - h / 2, w * 2, h * 2]
    t = _com_vb(texto, largo)
    t = re.sub(r'(<svg\b[^>]*?)\s(width|height)="[^"]*"', r"\1", t, count=2)
    png = subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024", "-a"], input=t.encode(),
                         capture_output=True, check=True).stdout
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    alfa = im.split()[3].point(lambda a: 255 if a > 16 else 0)
    bb = alfa.getbbox()
    if not bb:
        return None
    ex = largo[2] / im.width
    ey = largo[3] / im.height
    return (largo[0] + bb[0] * ex, largo[1] + bb[1] * ey, largo[0] + bb[2] * ex, largo[1] + bb[3] * ey)


def _sem_ns(texto, escala):
    """Tira o non-scaling-stroke; a espessura em px vira unidade do desenho, na escala pedida."""
    def estilo(m):
        s = m.group(2)
        if not RE_NS_ESTILO.search(s):
            return m.group(0)
        s = RE_NS_ESTILO.sub("", s)
        s = re.sub(r"stroke-width\s*:\s*([0-9.]+)\s*(px)?",
                   lambda k: f"stroke-width: {round(float(k.group(1)) * escala):g}", s)
        return m.group(1) + s.strip() + m.group(3)
    t = re.sub(r'(style=")([^"]*)(")', estilo, texto)
    return RE_NS_ATTR.sub("", t)


def corrigir_svg(dados):
    texto = dados.decode("utf-8")
    vb0 = _vb(texto)
    if vb0 is None:
        return dados, []
    notas = []
    tem_ns = bool(RE_NS_ESTILO.search(texto) or RE_NS_ATTR.search(texto))
    atual, vb = (_sem_ns(texto, 1.0) if tem_ns else texto), vb0
    if tem_ns:
        notas.append("non-scaling-stroke tirado")
    if not tem_ns:
        # sem non-scaling-stroke, a borda é do desenho: círculo de ponta a ponta, chama que encosta.
        # Só se avisa (quem usa: «são desenho de propósito; não mexa neles»).
        cx = _caixa(atual, vb)
        x, y, w, h = vb
        tol = TOLERANCIA * max(w, h)
        if cx and not (cx[0] >= x - tol and cx[1] >= y - tol and cx[2] <= x + w + tol and cx[3] <= y + h + tol):
            return dados, ["aviso: o desenho passa da borda do viewBox (deixado como está)"]
        return dados, []
    for _volta in range(6):
        cx = _caixa(atual, vb)
        if cx is None:
            break
        x, y, w, h = vb
        tol = TOLERANCIA * max(w, h)
        if cx[0] >= x - tol and cx[1] >= y - tol and cx[2] <= x + w + tol and cx[3] <= y + h + tol:
            break
        lado = max(cx[2] - cx[0], cx[3] - cx[1]) + 2 * FOLGA
        meio = ((cx[0] + cx[2]) / 2, (cx[1] + cx[3]) / 2)
        vb = [meio[0] - lado / 2, meio[1] - lado / 2, lado, lado]
        if tem_ns:
            # a espessura acompanha o desenho: a proporção traço/lado da arte de origem fica
            atual = _sem_ns(texto, vb0[2] / lado)
        atual = _com_vb(atual, vb)
    if vb != vb0:
        notas.append("viewBox " + " ".join(f"{v:g}" for v in vb0) + " -> " + " ".join(f"{v:.3f}" for v in vb))
    if not notas or all(n.startswith("aviso") for n in notas):
        return dados, notas
    return atual.encode("utf-8"), notas


if __name__ == "__main__":
    import sys, hashlib
    for p in sys.argv[1:]:
        d = open(p, "rb").read()
        novo, notas = corrigir_svg(d)
        again, n2 = corrigir_svg(novo)
        print(p.split("/")[-1], notas or "ok", "| idempotente" if again == novo and not n2 else f"| NAO idempotente {n2}")
#__trocas_motor.py__
"""Aplica as trocas por padrão: cada `antes` vira `depois`, no arquivo dele.

Já aplicada (o `depois` está lá): nada. O `antes` uma vez só: troca. Fora disso: recusa, com o
arquivo e a primeira linha do trecho — nenhuma troca é feita se alguma recusar.
uso: python3 trocas_motor.py <raiz> <trocas.json> [--aplicar]
"""
import collections, json, os, subprocess, sys, time

RAIZ, ARQ = sys.argv[1:3]
APLICAR = "--aplicar" in sys.argv[3:]
trocas = json.load(open(ARQ, encoding="utf-8"))
textos, recusas, feitas, ja = {}, [], collections.Counter(), collections.Counter()
for t in trocas:
    p = os.path.join(RAIZ, t["arquivo"])
    if p not in textos:
        try:
            textos[p] = open(p, encoding="utf-8").read()
        except OSError as e:
            recusas.append(f"{t['arquivo']}: {e.strerror}")
            continue
    txt = textos[p]
    if t["depois"] in txt:
        ja[t["arquivo"]] += 1
        continue
    n = txt.count(t["antes"])
    if n != 1:
        primeira = next((l for l in t["antes"].splitlines() if l.strip()), "")[:90]
        recusas.append(f"{t['arquivo']}: o trecho aparece {n} vez(es): {primeira!r}")
        continue
    textos[p] = txt.replace(t["antes"], t["depois"], 1)
    feitas[t["arquivo"]] += 1
for r in recusas:
    print("recusa   " + r)
for a in sorted(feitas):
    print(f"troca    {a} ({feitas[a]} trecho(s))")
print(f"trocas: {sum(feitas.values())} a fazer, {sum(ja.values())} já feitas, {len(recusas)} recusada(s)")
if recusas:
    sys.exit(1)
if APLICAR:
    for p, txt in textos.items():
        if feitas[os.path.relpath(p, RAIZ)]:
            with open(p, "w", encoding="utf-8") as fh:
                fh.write(txt)
            for _vez in range(60):   # um git de fundo pode segurar o index.lock por um instante
                r = subprocess.run(["git", "-C", RAIZ, "-c", "gc.auto=0", "add", "--", os.path.relpath(p, RAIZ)],
                                   capture_output=True, text=True)
                if r.returncode == 0 or "index.lock" not in r.stderr:
                    break
                time.sleep(0.5)
            if r.returncode != 0:
                sys.stderr.write(r.stderr)
                raise SystemExit(r.returncode)
#__trocas.json__
[
{
"arquivo": "app/servidor.py",
"antes": "ICONES_DO_MOTOR = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\")\nCONF_PADRAO = os.environ.get(\"MEOW_CONF_PADRAO\") or os.path.join(RAIZ, \"meow.conf.exemplo\")\n",
"depois": "ICONES_DO_MOTOR = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\")\n\n\ndef _glifo_do_motor(nome):\n    \"\"\"O glifo de traço do pack-base: `apps/` ou `biblioteca/` (as três pastas são planas desde a P96).\"\"\"\n    for pasta in (\"apps\", \"biblioteca\", \"sistema\"):\n        cand = os.path.join(ICONES_DO_MOTOR, pasta, nome + \".svg\")\n        if os.path.isfile(cand):\n            return cand\n    return os.path.join(ICONES_DO_MOTOR, \"apps\", nome + \".svg\")\nCONF_PADRAO = os.environ.get(\"MEOW_CONF_PADRAO\") or os.path.join(RAIZ, \"meow.conf.exemplo\")\n"
},
{
"arquivo": "app/servidor.py",
"antes": "        if pack in alvo:\n",
"depois": "        # O pack padrão leva o nome do produto (P96): «meowsystem» num caminho ou num nome\n        # de tema é o MeowSystem, não um vestígio do pack. O que denuncia o valor dele é o\n        # nome de antes, «catppuccin» (os apelidos do pack.py).\n        mod_p = modulo_pack()\n        apelidos = [a for a, d in (getattr(mod_p, \"APELIDOS\", {}) or {}).items() if d == pack]\n        nomes = apelidos if pack == getattr(mod_p, \"PACK_BASE\", \"meowsystem\") else [pack] + apelidos\n        if any(n in alvo for n in nomes):\n"
},
{
"arquivo": "app/servidor.py",
"antes": "    # de existir em `packs/meowsystem/icones/apps/arcticons/`, e rodar o\n",
"depois": "    # de existir em `packs/meowsystem/icones/apps/`, e rodar o\n"
},
{
"arquivo": "app/servidor.py",
"antes": "                else os.path.join(icones, \"apps\", \"arcticons\", glifo + \".svg\")\n",
"depois": "                else _glifo_do_motor(glifo)\n"
},
{
"arquivo": "app/servidor.py",
"antes": "            arq = os.path.join(icones, \"apps\", \"convertidos\", nome + \".svg\")\n",
"depois": "            arq = os.path.join(icones, \"apps\", nome + \".svg\")\n"
},
{
"arquivo": "app/servidor.py",
"antes": "                caminho = os.path.join(ICONES_DO_MOTOR, \"apps\", \"convertidos\", nome + \".svg\")\n",
"depois": "                caminho = os.path.join(ICONES_DO_MOTOR, \"apps\", nome + \".svg\")\n"
},
{
"arquivo": "app/servidor.py",
"antes": "        trazer = os.path.join(ICONES_DO_MOTOR, \"apps\", \"arcticons\")\n",
"depois": "        trazer = os.path.join(ICONES_DO_MOTOR, \"apps\")\n"
},
{
"arquivo": "app/servidor.py",
"antes": "        return os.path.join(ICONES_DO_MOTOR, \"apps\", \"convertidos\", \"retoques\", app + \".svg\")\n",
"depois": "        return os.path.join(ICONES_DO_MOTOR, \"apps\", app + \".svg\")\n"
},
{
"arquivo": "app/servidor.py",
"antes": "            arte = os.path.join(ICONES_DO_MOTOR, \"apps\", \"arcticons\",\n                                campos[1] + \".svg\")\n",
"depois": "            arte = _glifo_do_motor(campos[1])\n"
},
{
"arquivo": "app/servidor.py",
"antes": "        conv = os.path.join(ICONES_DO_MOTOR, \"apps\", \"convertidos\")\n",
"depois": "        conv = os.path.join(ICONES_DO_MOTOR, \"apps\")\n"
},
{
"arquivo": "bin/meow",
"antes": "  local pastas=() p\n  for p in packs/meowsystem/mascote/ packs/dracula/mascote/ packs/meowsystem/icones/sistema/leitura assets/icones/overrides; do\n    [ -d \"$RAIZ/$p\" ] && pastas+=(\"$RAIZ/$p\")\n",
"depois": "  local pastas=() p\n  for p in packs/meowsystem/mascote/ packs/dracula/mascote/ assets/icones/overrides; do\n    [ -d \"$RAIZ/$p\" ] && pastas+=(\"$RAIZ/$p\")\n"
},
{
"arquivo": "bin/meow",
"antes": "  for p in \"$RAIZ\"/packs/*/icones/apps/autorais; do\n    [ -d \"$p\" ] && pastas+=(\"$p\")\n  done\n",
"depois": "  # P96: as pastas dos packs são planas — os desenhos do modo de leitura (`leitura-*.svg`) e os\n  # autorais (`<nome>-<flavor>.svg` em `apps/`, um flavor da paleta do pack) entram arquivo a arquivo.\n  for p in \"$RAIZ\"/packs/meowsystem/icones/sistema/leitura-*.svg; do [ -f \"$p\" ] && pastas+=(\"$p\"); done\n  while IFS= read -r p; do [ -n \"$p\" ] && pastas+=(\"$p\"); done < <(python3 -I - \"$RAIZ\" <<'PYAUT' 2>/dev/null\nimport glob, json, os, sys\nfor d in sorted(glob.glob(os.path.join(sys.argv[1], \"packs\", \"*\"))):\n    try:\n        fl = json.load(open(os.path.join(d, \"paleta.json\"), encoding=\"utf-8\"))[\"flavors\"]\n    except Exception:\n        continue\n    for f in sorted(glob.glob(os.path.join(d, \"icones\", \"apps\", \"*.svg\"))):\n        if any(f.endswith(\"-%s.svg\" % x) for x in fl):\n            print(f)\nPYAUT\n  )\n"
},
{
"arquivo": "bin/meow",
"antes": "                  for p in packs/meowsystem/mascote/ packs/dracula/mascote/ packs/meowsystem/icones/sistema/leitura assets/icones/overrides; do\n",
"depois": "                  for p in packs/meowsystem/mascote/ packs/dracula/mascote/ assets/icones/overrides; do\n"
},
{
"arquivo": "bin/meow",
"antes": "                  for p in \"$RAIZ\"/packs/*/icones/apps/autorais; do\n                    [ -d \"$p\" ] && pastas+=(\"$p\")\n                  done\n",
"depois": "                  # P96: as pastas dos packs são planas — os desenhos do modo de leitura (`leitura-*.svg`) e os\n                  # autorais (`<nome>-<flavor>.svg` em `apps/`, um flavor da paleta do pack) entram arquivo a arquivo.\n                  for p in \"$RAIZ\"/packs/meowsystem/icones/sistema/leitura-*.svg; do [ -f \"$p\" ] && pastas+=(\"$p\"); done\n                  while IFS= read -r p; do [ -n \"$p\" ] && pastas+=(\"$p\"); done < <(python3 -I - \"$RAIZ\" <<'PYAUT' 2>/dev/null\nimport glob, json, os, sys\nfor d in sorted(glob.glob(os.path.join(sys.argv[1], \"packs\", \"*\"))):\n    try:\n        fl = json.load(open(os.path.join(d, \"paleta.json\"), encoding=\"utf-8\"))[\"flavors\"]\n    except Exception:\n        continue\n    for f in sorted(glob.glob(os.path.join(d, \"icones\", \"apps\", \"*.svg\"))):\n        if any(f.endswith(\"-%s.svg\" % x) for x in fl):\n            print(f)\nPYAUT\n                  )\n"
},
{
"arquivo": "docs/sprints/2026-10-09-uso-real/02-decisoes.md",
"antes": "| 13 | Os SVG/PNG achados na varredura e na recuperação de 15/10 | **Tudo entra no pack** («Joga tudo pro pack», 15/10): os nossos, as versões editadas (TODAS as versões entram, com nome que as distingue — o seletor mostra todas, e mais novo não é melhor) e os de terceiros com licença conhecida (linha no PROCEDENCIA). Ficam fora só: rascunho quebrado/lixo, e ícone de projeto pessoal (Beholder, Elden Ring Tracker, Nyx, Protocolo Ouroboros, Caldeirão) — regra de 23/09, porque o pack é produto público | pedido de 15/10; regra de 23/09 |\n| 14 | Formato de ícone dos packs | **Três pastas por pack, no máximo: `icones/apps/` (desenho ligado a um programa pelo `apps.map`), `icones/sistema/` (pastas, mimetypes, status, simbólicos) e `icones/biblioteca/` (todo o resto, para escolher). Uma biblioteca POR PACK.** O acervo do motor (`assets/icones/`: traço Arcticons, resgatados, convertidos, retoques, autorais) vira o pack-base `meowsystem`, no mesmo formato, que todo pack herda. Vale para o Dracula, o Catppuccin e todo pack futuro (validador, `meow pack novo`, importar, exportar). Revoga a fronteira de 21/09 («o acervo pode ser do motor») | pedido de 15/10: «unificar tudo lá, incluindo as pastas, no máximo três… pro formato dos packs meu e do meowsystem e pros futuros»; escolha «uma por pack» |\n| 15 | Alterar um desenho do pack | **Tudo que deriva dele se atualiza sozinho**: SVG alterado (ou PNG-fonte, ou linha do `apps.map`) em qualquer das três pastas de qualquer pack → em segundos o tema instalado, os PNG por tamanho, o `icon-theme.cache`, o ícone do lançador e o seletor refletem a mudança, sem comando. Idempotente (só refaz o que mudou, por sha256), um reler do painel no fim | pedido de 15/10: «SVG alterado numa das três, qualquer outro arquivo, seja PNG ou afins, se auto atualiza»; memória da fonte única (21/09: «alterando lá alteraremos o resto») |\n| 16 | Os achados da varredura de 15/10 (`docs/pesquisas/2026-10-15-svgs-faltando.md`) | **(1)** os 19 desenhos Dracula do motor vão para `packs/dracula` (cor Dracula fixa; o pack-base `meowsystem` fica só com o que é neutro/traço). **(2)** Projetos dela fora da lista de 23/09 (Hefesto, Sigilo, Luna, PDForge…) e o `aurora-iniciar` entram na `biblioteca/` (precedente: `hefesto-dracula.svg`); a lista de exclusão continua só Beholder, Elden Ring Tracker, Nyx, Protocolo Ouroboros, Caldeirão. **(3)** Toda versão entra na `biblioteca/`; a LIGADA ao programa é a que vence pela régua do BRIEFING (RMSE contra o PNG feito à mão): motor no Clapper, PhotoGIMP, Waterfox e Citrix de 12/09; P84 no Edge e no WhatsApp; Nautilus fica a atual. **(4)** uad-ng e Ubuntu: fica ligado o novo pedido em 15/09 (pedido explícito), o desenho dela de 12/09 entra na biblioteca. **(5)** folder-download: as três versões entram; a ligada continua a atual até quem usa escolher no seletor. **(6)** As 33 ligações perdidas na P37 (Discord, Spotify, Opera, Gradia, 11 nomes do Citrix, mimetypes) voltam ao `apps.map`; as 7 que passaram a apontar para outro desenho voltam ao original. **(7)** Desenho do pack vence o traço Arcticons em TODO tamanho (hoje o de 48 px encobre 17), salvo escolha de traço feita por quem usa | «Joga tudo pro pack» (15/10); régua do BRIEFING; memória «mais novo não é melhor» |\n",
"depois": "| 13 | Os SVG/PNG achados na varredura e na recuperação de 15/10 | **Tudo entra no pack** («Joga tudo pro pack», 15/10): os nossos e os de terceiros com licença conhecida (linha no PROCEDENCIA). **Uma versão por ícone** (23/10, P96): a que quem usa escolheu na página de 23/10, ou a do manuais-final; as outras saem (o git guarda). Fica fora só rascunho quebrado/lixo. **Os projetos pessoais entram no Dracula** (Beholder, Elden Ring Tracker, Protocolo Ouroboros, Luna, Mnemo, ArcaneTab, Crononauta): a regra de 23/09 está revogada para ícones | pedido de 15/10; sim de 23/10 (P96: «projetos pessoais entram no Dracula», «uma versão por ícone»), que revoga a regra de 23/09 para ícones |\n| 14 | Formato de ícone dos packs | **Três pastas por pack, no máximo: `icones/apps/` (desenho ligado a um programa pelo `apps.map`), `icones/sistema/` (pastas, mimetypes, status, simbólicos) e `icones/biblioteca/` (todo o resto, para escolher). Uma biblioteca POR PACK.** O acervo do motor (`assets/icones/`: traço Arcticons, resgatados, convertidos, retoques, autorais) vira o pack-base `meowsystem`, no mesmo formato, que todo pack herda. Vale para o Dracula, o pack padrão e todo pack futuro (validador, `meow pack novo`, importar, exportar). Revoga a fronteira de 21/09 («o acervo pode ser do motor»). **Desde 23/10 (P96): as três pastas são planas, sem subpasta** (flavor no nome, origem no PROCEDENCIA), e o Catppuccin entrou no pack `meowsystem`, que é o padrão | pedido de 15/10: «unificar tudo lá, incluindo as pastas, no máximo três… pro formato dos packs meu e do meowsystem e pros futuros»; escolha «uma por pack» |\n| 15 | Alterar um desenho do pack | **Tudo que deriva dele se atualiza sozinho**: SVG alterado (ou PNG-fonte, ou linha do `apps.map`) em qualquer das três pastas de qualquer pack → em segundos o tema instalado, os PNG por tamanho, o `icon-theme.cache`, o ícone do lançador e o seletor refletem a mudança, sem comando. Idempotente (só refaz o que mudou, por sha256), um reler do painel no fim | pedido de 15/10: «SVG alterado numa das três, qualquer outro arquivo, seja PNG ou afins, se auto atualiza»; memória da fonte única (21/09: «alterando lá alteraremos o resto») |\n| 16 | Os achados da varredura de 15/10 (`docs/pesquisas/2026-10-15-svgs-faltando.md`) | **(1)** os 19 desenhos Dracula do motor vão para `packs/dracula` (cor Dracula fixa; o pack-base `meowsystem` fica só com o que é neutro/traço). **(2)** Projetos dela fora da lista de 23/09 (Hefesto, Sigilo, Luna, PDForge…) e o `aurora-iniciar` entram na `biblioteca/` (precedente: `hefesto-dracula.svg`); a lista de exclusão continua só Beholder, Elden Ring Tracker, Nyx, Protocolo Ouroboros, Caldeirão. **(3)** Uma versão por ícone (23/10, P96): a LIGADA ao programa é a que quem usa escolheu na página de escolha de 23/10 — inclusive o Citrix, que veste o Ubuntu-selfservice do manuais-final (sim explícito de 23/10, dado na página, que desfaz o «Citrix de 12/09» desta linha); as outras versões saem (o git guarda). **(4)** uad-ng e Ubuntu: fica ligado o novo pedido em 15/09 (pedido explícito), o desenho dela de 12/09 entra na biblioteca. **(5)** folder-download: as três versões entram; a ligada continua a atual até quem usa escolher no seletor. **(6)** As 33 ligações perdidas na P37 (Discord, Spotify, Opera, Gradia, 11 nomes do Citrix, mimetypes) voltam ao `apps.map`; as 7 que passaram a apontar para outro desenho voltam ao original. **(7)** Desenho do pack vence o traço Arcticons em TODO tamanho (hoje o de 48 px encobre 17), salvo escolha de traço feita por quem usa | «Joga tudo pro pack» (15/10); régua do BRIEFING; memória «mais novo não é melhor» |\n"
},
{
"arquivo": "install.sh",
"antes": "  for p in packs/meowsystem/mascote/ packs/dracula/mascote/ packs/meowsystem/icones/sistema/leitura assets/icones/overrides; do\n",
"depois": "  for p in packs/meowsystem/mascote/ packs/dracula/mascote/ assets/icones/overrides; do\n"
},
{
"arquivo": "install.sh",
"antes": "  for p in \"$MEOW_RAIZ\"/packs/*/icones/apps/autorais; do\n    [ -d \"$p\" ] && pastas+=(\"$p\")\n  done\n",
"depois": "  # P96: as pastas dos packs são planas — os desenhos do modo de leitura (`leitura-*.svg`) e os\n  # autorais (`<nome>-<flavor>.svg` em `apps/`, um flavor da paleta do pack) entram arquivo a arquivo.\n  for p in \"$MEOW_RAIZ\"/packs/meowsystem/icones/sistema/leitura-*.svg; do [ -f \"$p\" ] && pastas+=(\"$p\"); done\n  while IFS= read -r p; do [ -n \"$p\" ] && pastas+=(\"$p\"); done < <(python3 -I - \"$MEOW_RAIZ\" <<'PYAUT' 2>/dev/null\nimport glob, json, os, sys\nfor d in sorted(glob.glob(os.path.join(sys.argv[1], \"packs\", \"*\"))):\n    try:\n        fl = json.load(open(os.path.join(d, \"paleta.json\"), encoding=\"utf-8\"))[\"flavors\"]\n    except Exception:\n        continue\n    for f in sorted(glob.glob(os.path.join(d, \"icones\", \"apps\", \"*.svg\"))):\n        if any(f.endswith(\"-%s.svg\" % x) for x in fl):\n            print(f)\nPYAUT\n  )\n"
},
{
"arquivo": "lib/comum.sh",
"antes": "# São os mesmos hex de `packs/catppuccin/paleta.json`, convertidos para o\n",
"depois": "# São os mesmos hex de `packs/meowsystem/paleta.json`, convertidos para o\n"
},
{
"arquivo": "lib/comum.sh",
"antes": "        validos.add(n)\nfor n in sorted(validos):\n",
"depois": "        validos.add(n)\n# O nome de antes de um pack (o `catppuccin`, que entrou no `meowsystem` na P96) ainda nomeia\n# o que é dele: um snippet, um tema, um vestígio.\nfor antes, hoje in getattr(pack, \"APELIDOS\", {}).items():\n    if hoje in validos:\n        validos.add(antes)\nfor n in sorted(validos):\n"
},
{
"arquivo": "scripts/afinar_conversor.py",
"antes": "ACERVO = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps\", \"arcticons\")\nMAPA = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps-convertidos.map\")\nRETOQUES = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps\", \"convertidos\", \"retoques\")\n",
"depois": "ACERVO = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"arcticons.lista\")   # P96: a lista do traço\nMAPA = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps-convertidos.map\")\nRETOQUES = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps\")\n"
},
{
"arquivo": "scripts/afinar_conversor.py",
"antes": "            if origem == \"mao\" or os.path.exists(os.path.join(RETOQUES, nome + \".svg\")):\n",
"depois": "            # P96: retoque é a palavra `retoque` no 4º campo (o arquivo mora em apps/, plano, como todos)\n            if origem == \"mao\" or \"retoque\" in (p[3].split() if len(p) > 3 else []):\n"
},
{
"arquivo": "scripts/completar_icones.sh",
"antes": "              icones.autorais.desenhos icones/apps/autorais/)\" || AUTORAIS=\"\"\n",
"depois": "              icones.autorais.desenhos icones/apps/)\" || AUTORAIS=\"\"\n"
},
{
"arquivo": "scripts/construir_convertidos.sh",
"antes": "# `packs/meowsystem/icones/apps/convertidos/`: os ícones do lançador que nós\n",
"depois": "# `packs/meowsystem/icones/apps/`: os ícones do lançador que nós\n"
},
{
"arquivo": "scripts/construir_convertidos.sh",
"antes": "DESTINO=\"$RAIZ/packs/meowsystem/icones/apps/convertidos\"\nRETOQUES=\"$DESTINO/retoques\"\n",
"depois": "# P96 (23/10/2026): as três pastas do pack são planas. O convertido e o retoque moram juntos em\n# `apps/`; quem diz que um nome é retoque (desenho à mão, que o conversor nunca sobrescreve) é a\n# palavra `retoque` no 4º campo do mapa, ou a origem `mao`.\nDESTINO=\"$RAIZ/packs/meowsystem/icones/apps\"\nRETOQUES=\"$DESTINO\"\n"
},
{
"arquivo": "scripts/construir_convertidos.sh",
"antes": "declare -A MAO=()        # nome -> 1 quando a linha declara `mao` (sem origem)\n\n",
"depois": "declare -A MAO=()        # nome -> 1 quando a linha declara `mao` (sem origem)\ndeclare -A RETOQUE=()    # nome -> 1 quando o 4º campo traz a palavra `retoque` (P96)\n\n"
},
{
"arquivo": "scripts/construir_convertidos.sh",
"antes": "    ARGS[\"$nome\"]=\"${extra:-}\"\n    if [ \"${dono:-}\" = usuario ]; then\n",
"depois": "    ARGS[\"$nome\"]=\"${extra:-}\"\n    case \" ${extra:-} \" in\n      *\" retoque \"*) RETOQUE[\"$nome\"]=1\n                     ARGS[\"$nome\"]=\"$(printf '%s' \" ${extra:-} \" | sed -e 's/ retoque / /g' -e 's/^ *//' -e 's/ *$//')\" ;;\n    esac\n    if [ \"${dono:-}\" = usuario ]; then\n"
},
{
"arquivo": "scripts/construir_convertidos.sh",
"antes": "  if [ -f \"$retoques/$nome.svg\" ]; then\n",
"depois": "  if [ -f \"$retoques/$nome.svg\" ] && { [ -n \"${DO_USUARIO[$nome]:-}\" ] || [ -n \"${RETOQUE[$nome]:-}\" ] || [ -n \"${MAO[$nome]:-}\" ]; }; then\n"
},
{
"arquivo": "scripts/construir_convertidos.sh",
"antes": "  # O órfão é contado por dono (P82): o do projeto saiu do mapa do projeto, o\n  # de quem usa saiu do dela.\n  if [ -d \"$DESTINO\" ]; then\n    for arq in \"$DESTINO\"/*.svg; do\n      [ -e \"$arq\" ] || continue\n      nome=\"$(basename \"$arq\" .svg)\"\n      [ -n \"${DO_PROJETO[$nome]:-}\" ] || { orfaos=$((orfaos + 1)); n_orfaos+=(\"$nome\"); }\n    done\n  fi\n",
"depois": "  # O órfão é contado por dono (P82): o de quem usa saiu do mapa dela. A `apps/`\n  # do pack é plana e guarda também o traço e os autorais, que não são deste\n  # mapa: ela não tem órfão a contar, como o `_aplicar` não tem a varrer (P96).\n"
},
{
"arquivo": "scripts/construir_convertidos.sh",
"antes": "  # `packs/meowsystem/icones/apps/convertidos/` nasce aqui e nenhum outro script escreve nele.\n",
"depois": "  # `packs/meowsystem/icones/apps/` nasce aqui e nenhum outro script escreve nele.\n"
},
{
"arquivo": "scripts/construir_convertidos.sh",
"antes": "  for pasta in \"$DESTINO\" \"$DESTINO_USUARIO\"; do\n",
"depois": "  # A varredura de órfão é só na casa: a `apps/` do pack é plana e guarda também o traço e os\n  # autorais, que não são deste mapa (P96).\n  for pasta in \"$DESTINO_USUARIO\"; do\n"
},
{
"arquivo": "scripts/converter_icone.py",
"antes": "    `packs/meowsystem/icones/apps/convertidos/`, que fica COMMITADO no repositório como o\n    `packs/meowsystem/icones/apps/arcticons/`. Arte que ela aprovou numa folha tem de aparecer no\n",
"depois": "    `packs/meowsystem/icones/apps/`, que fica COMMITADO no repositório como o\n    `packs/meowsystem/icones/apps/`. Arte que ela aprovou numa folha tem de aparecer no\n"
},
{
"arquivo": "scripts/converter_icone.py",
"antes": "    e Gradia têm desenho à mão em `packs/meowsystem/icones/apps/convertidos/retoques/`, que vence\n",
"depois": "    e Gradia têm desenho à mão em `packs/meowsystem/icones/apps/retoques/`, que vence\n"
},
{
"arquivo": "scripts/derivados.sh",
"antes": "    */icones/apps-resgatados.map|*/icones/apps/resgatados/*) printf 'resgatados\\narcticons\\n' ;;\n    */icones/apps-arcticons.map|*/icones/apps-convertidos.map|*/icones/apps-marca.map \\\n      |*/icones/apps/arcticons/*|*/icones/apps/convertidos/*) printf 'arcticons\\n' ;;\n    */icones/apps-hicolor.map)                 printf 'completar\\n' ;;\n    */icones/apps/autorais/*)                  printf 'completar\\n' ;;\n    */icones/sistema.map)                      printf 'sistema\\n' ;;\n    */icones/bandeja.map)                      printf 'bandeja\\n' ;;\n    */icones/sistema/arcticons/*)              printf 'sistema\\nbandeja\\narcticons\\n' ;;\n    */icones/pastas.map|*/icones/sistema/pastas/*) printf 'pastas\\n' ;;\n    */icones/mimetypes.map|*/icones/sistema/mimetypes/*) printf 'mimetypes\\n' ;;\n    */icones/sistema/leitura/*)                : ;;\n    # Uma linha do `apps.map` pode apontar para a biblioteca, e a escolha do\n    # painel para qualquer desenho de `apps/` ou dela.\n    */icones/apps/*|*/icones/biblioteca/*)     printf 'dracula\\narcticons\\n' ;;\n",
"depois": "    */icones/apps-resgatados.map)              printf 'resgatados\\narcticons\\n' ;;\n    */icones/apps-arcticons.map|*/icones/apps-convertidos.map|*/icones/apps-marca.map) printf 'arcticons\\n' ;;\n    */icones/apps-hicolor.map)                 printf 'completar\\n' ;;\n    */icones/sistema.map)                      printf 'sistema\\n' ;;\n    */icones/bandeja.map)                      printf 'bandeja\\n' ;;\n    */icones/pastas.map)                       printf 'pastas\\n' ;;\n    */icones/mimetypes.map)                    printf 'mimetypes\\n' ;;\n    # P96: as três pastas são planas, e um arquivo de `apps/` pode ser desenho de app, resgate,\n    # traço, convertido ou autoral; um de `sistema/`, molde de tipo de arquivo, pasta ou glifo.\n    # Refazer os passos da pasta inteira custa uma passada; errar o passo deixa o tema velho.\n    */icones/sistema/leitura-*)                : ;;\n    */icones/apps/*)                           printf 'dracula\\nresgatados\\narcticons\\ncompletar\\n' ;;\n    */icones/sistema/*)                        printf 'sistema\\nbandeja\\npastas\\nmimetypes\\n' ;;\n    # Uma linha do `apps.map` pode apontar para a biblioteca, e a escolha do\n    # painel para qualquer desenho de `apps/` ou dela.\n    */icones/biblioteca/*)                     printf 'dracula\\narcticons\\n' ;;\n"
},
{
"arquivo": "scripts/derivar_claro.py",
"antes": "    cat = json.load(open(f\"{RAIZ}/packs/catppuccin/paleta.json\"))\n",
"depois": "    cat = json.load(open(f\"{RAIZ}/packs/meowsystem/paleta.json\"))\n"
},
{
"arquivo": "scripts/estilo_icone.py",
"antes": "    ./scripts/estilo_icone.py --faixa packs/meowsystem/icones/apps/arcticons\n",
"depois": "    ./scripts/estilo_icone.py --faixa packs/meowsystem/icones/apps\n"
},
{
"arquivo": "scripts/estilo_icone.py",
"antes": "    arqs = sorted(os.path.join(b, f)\n                  for b, _, fs in os.walk(raiz) for f in fs if f.endswith(\".svg\"))\n",
"depois": "    if os.path.isfile(raiz) and raiz.endswith(\".lista\"):\n        # P96: as três pastas do pack são planas; a lista diz quais arquivos são do acervo\n        base = os.path.dirname(raiz)\n        nomes = [l.strip() for l in open(raiz, encoding=\"utf-8\") if l.strip() and not l.startswith(\"#\")]\n        arqs = sorted(c for n in nomes for c in (os.path.join(base, p, n) for p in (\"apps\", \"sistema\", \"biblioteca\"))\n                      if os.path.isfile(c))\n    else:\n        arqs = sorted(os.path.join(b, f)\n                      for b, _, fs in os.walk(raiz) for f in fs if f.endswith(\".svg\"))\n"
},
{
"arquivo": "scripts/folha_conversor.py",
"antes": "RETOQUES = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps\", \"convertidos\", \"retoques\")\nARCTICONS = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps\", \"arcticons\")\n# Para essas nove, a coluna \"o traço de hoje\" desenhada a partir da origem\n# mostra arte que ela nunca viu — o Chrome do acervo tem UM subcaminho\n# desenhado à mão, e a conversão tem oito.\nACERVO = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps\", \"convertidos\")\n",
"depois": "RETOQUES = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps\")\nARCTICONS = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps\")   # P96: glifo em apps/ ou na biblioteca\n# Para essas nove, a coluna \"o traço de hoje\" desenhada a partir da origem\n# mostra arte que ela nunca viu — o Chrome do acervo tem UM subcaminho\n# desenhado à mão, e a conversão tem oito.\nACERVO = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps\")\n\n\ndef _e_retoque(nome):\n    \"\"\"P96: o retoque mora em apps/ como o convertido; quem diz que é à mão é o mapa (`mao` ou `retoque`).\"\"\"\n    try:\n        with open(MAPA, encoding=\"utf-8\") as fh:\n            for linha in fh:\n                p = linha.split(\"#\", 1)[0].rstrip(\"\\n\").split(\":\")\n                if len(p) >= 3 and p[0].strip() == nome:\n                    return p[1].strip() == \"mao\" or \"retoque\" in (p[3].split() if len(p) > 3 else [])\n    except OSError:\n        pass\n    return False\n"
},
{
"arquivo": "scripts/folha_conversor.py",
"antes": "    if not os.path.exists(arq):\n        return None\n",
"depois": "    if not os.path.exists(arq):\n        arq = os.path.join(os.path.dirname(ARCTICONS), \"biblioteca\", g + \".svg\")\n    if not os.path.exists(arq):\n        return None\n"
},
{
"arquivo": "scripts/folha_conversor.py",
"antes": "            if os.path.exists(os.path.join(RETOQUES, nome + \".svg\")):\n",
"depois": "            if _e_retoque(nome):\n"
},
{
"arquivo": "scripts/folha_proposta.py",
"antes": "      Os 35 glifos vão para <code>packs/meowsystem/icones/apps/arcticons/</code> com a cor aplicada, as 35\n",
"depois": "      Os 35 glifos vão para <code>packs/meowsystem/icones/apps/</code> com a cor aplicada, as 35\n"
},
{
"arquivo": "scripts/gerar_icones_autorais.py",
"antes": "                               padrao=\"icones/apps/autorais/\"))\n",
"depois": "                               padrao=\"icones/apps/\"))\n"
},
{
"arquivo": "scripts/icones_apps_arcticons.sh",
"antes": "#   `packs/meowsystem/icones/apps/arcticons/`    glifos do pack Arcticons, desenhados à mão por\n#                              terceiros. Mapa: `packs/meowsystem/icones/apps-arcticons.map`.\n#   `packs/meowsystem/icones/apps/convertidos/`  a arte do PRÓPRIO aplicativo, convertida de\n",
"depois": "#   `packs/meowsystem/icones/apps/`    glifos do pack Arcticons, desenhados à mão por\n#                              terceiros. Mapa: `packs/meowsystem/icones/apps-arcticons.map`.\n#   `packs/meowsystem/icones/apps/`  a arte do PRÓPRIO aplicativo, convertida de\n"
},
{
"arquivo": "scripts/icones_apps_arcticons.sh",
"antes": "ORIGEM=\"$RAIZ/packs/meowsystem/icones/apps/arcticons\"\n",
"depois": "ORIGEM=\"$RAIZ/packs/meowsystem/icones/apps\"\n# P96: o glifo que nenhum mapa do pack-base pede mora na biblioteca (a escolha de traço de quem usa o alcança)\nORIGEM_BIBLIOTECA=\"$RAIZ/packs/meowsystem/icones/biblioteca\"\n"
},
{
"arquivo": "scripts/icones_apps_arcticons.sh",
"antes": "ORIGEM_CONV=\"$RAIZ/packs/meowsystem/icones/apps/convertidos\"\n",
"depois": "ORIGEM_CONV=\"$RAIZ/packs/meowsystem/icones/apps\"\n"
},
{
"arquivo": "scripts/icones_apps_arcticons.sh",
"antes": "    ARTE[\"$nome\"]=\"$ORIGEM/$glifo.svg\"\n    # O caminho gravado antes das três pastas (P88) é lido no endereço de hoje.\n",
"depois": "    ARTE[\"$nome\"]=\"$ORIGEM/$glifo.svg\"\n    [ -f \"${ARTE[$nome]}\" ] || [ ! -f \"$ORIGEM_BIBLIOTECA/$glifo.svg\" ] || ARTE[\"$nome\"]=\"$ORIGEM_BIBLIOTECA/$glifo.svg\"\n    # O caminho gravado antes das três pastas (P88) é lido no endereço de hoje.\n"
},
{
"arquivo": "scripts/icones_apps_arcticons.sh",
"antes": "    meow_pula \"o acervo Arcticons de aplicativo não está em packs/meowsystem/icones/apps/arcticons\"\n",
"depois": "    meow_pula \"o acervo Arcticons de aplicativo não está em packs/meowsystem/icones/apps\"\n"
},
{
"arquivo": "scripts/icones_apps_arcticons.sh",
"antes": "    meow_aviso \"o glifo '$glifo' não está em packs/meowsystem/icones/apps/arcticons — '$nome' fica no Papirus\"\n    meow_info \"  baixe com: curl -s https://api.iconify.design/arcticons/$glifo.svg -o packs/meowsystem/icones/apps/arcticons/$glifo.svg\"\n",
"depois": "    meow_aviso \"o glifo '$glifo' não está em packs/meowsystem/icones/apps — '$nome' fica no Papirus\"\n    meow_info \"  baixe com: curl -s https://api.iconify.design/arcticons/$glifo.svg -o packs/meowsystem/icones/apps/$glifo.svg\"\n"
},
{
"arquivo": "scripts/icones_bandeja.sh",
"antes": "ORIGEM=\"${MEOW_BANDEJA_ORIGEM:-$RAIZ/packs/meowsystem/icones/sistema/arcticons}\"\n",
"depois": "ORIGEM=\"${MEOW_BANDEJA_ORIGEM:-$RAIZ/packs/meowsystem/icones/sistema}\"\n"
},
{
"arquivo": "scripts/icones_bandeja.sh",
"antes": "    meow_pula \"o acervo Arcticons não está em packs/meowsystem/icones/sistema/arcticons — nada a vestir\"\n",
"depois": "    meow_pula \"o acervo Arcticons não está em packs/meowsystem/icones/sistema — nada a vestir\"\n"
},
{
"arquivo": "scripts/icones_bandeja.sh",
"antes": "    meow_aviso \"o glifo '$glifo' não está em packs/meowsystem/icones/sistema/arcticons — '$nome' fica como está\"\n    meow_info \"  baixe com: curl -s https://api.iconify.design/arcticons/$glifo.svg -o packs/meowsystem/icones/sistema/arcticons/$glifo.svg\"\n",
"depois": "    meow_aviso \"o glifo '$glifo' não está em packs/meowsystem/icones/sistema — '$nome' fica como está\"\n    meow_info \"  baixe com: curl -s https://api.iconify.design/arcticons/$glifo.svg -o packs/meowsystem/icones/sistema/$glifo.svg\"\n"
},
{
"arquivo": "scripts/icones_bandeja.sh",
"antes": "    printf '%s linha(s) no mapa e nenhum glifo em packs/meowsystem/icones/sistema/arcticons — nada a vestir' \"${#MAPA_LIDO[@]}\"\n",
"depois": "    printf '%s linha(s) no mapa e nenhum glifo em packs/meowsystem/icones/sistema — nada a vestir' \"${#MAPA_LIDO[@]}\"\n"
},
{
"arquivo": "scripts/icones_mimetypes.sh",
"antes": "ORIGEM=\"$(python3 \"$RAIZ/scripts/pack.py\" acervo \"$_pack_ref\" \\\n            icones.mimetypes.desenhos \"$FLAVOR_ICONES\")\" || ORIGEM=\"\"\n",
"depois": "# P96 (23/10/2026): um molde só no pack, pintado aqui com a paleta do pack no ar. O\n# `pintados` refaz do molde a cada passada (só escreve o que mudou) e devolve a pasta.\n# Quem só confere (ou roda a seco) pinta numa pasta temporária: conferir não escreve na casa.\n_pintar_onde=\"\"\n{ [ \"${1:-}\" = \"--conferir\" ] || meow_seco; } && _pintar_onde=\"--temporario\"\nORIGEM=\"$( [ -n \"$FLAVOR_ICONES\" ] && python3 \"$RAIZ/scripts/pack.py\" pintados \"$_pack_ref\" \"$FLAVOR_ICONES\" $_pintar_onde)\" || ORIGEM=\"\"\n# A pasta temporária vai num nome próprio: o ORIGEM pode mudar logo abaixo (as pastas do pack), e\n# o trap leria o valor de então — apagaria o acervo do pack.\n_pintado_temporario=\"\"\ncase \"$ORIGEM\" in */meow-pintados-*) _pintado_temporario=\"$ORIGEM\"; trap 'rm -rf \"$_pintado_temporario\"' EXIT ;; esac\n"
},
{
"arquivo": "scripts/icones_mimetypes.sh",
"antes": "DONO_ACERVO=\"$( [ -n \"$ORIGEM\" ] && python3 -I - \"$RAIZ/scripts\" \"$ORIGEM\" <<'PY' 2>/dev/null\nimport sys\nsys.path.insert(0, sys.argv[1])\nimport pack\ndono = pack._pack_de(sys.argv[2])\nprint(pack.campo(dono, \"nome\", dono) or \"\")\n",
"depois": "DONO_ACERVO=\"$( [ -n \"$ORIGEM\" ] && python3 -I - \"$RAIZ/scripts\" \"$_pack_ref\" <<'PY' 2>/dev/null\nimport sys\nsys.path.insert(0, sys.argv[1])\nimport pack\nprint(pack.campo(sys.argv[2], \"nome\", \"\") or \"\")\n"
},
{
"arquivo": "scripts/icones_pastas.sh",
"antes": "ORIGEM=\"$(python3 \"$RAIZ/scripts/pack.py\" acervo \"$_pack_ref\" \\\n            icones.mimetypes.desenhos \"$FLAVOR_ICONES\")\" || ORIGEM=\"\"\n",
"depois": "# P96 (23/10/2026): o acervo de tipo de arquivo é um molde só, pintado aqui com a paleta do\n# pack no ar (o `pintados` refaz do molde a cada passada e devolve a pasta pintada).\n# Quem só confere (ou roda a seco) pinta numa pasta temporária: conferir não escreve na casa.\n_pintar_onde=\"\"\n{ [ \"${1:-}\" = \"--conferir\" ] || meow_seco; } && _pintar_onde=\"--temporario\"\nORIGEM=\"$( [ -n \"$FLAVOR_ICONES\" ] && python3 \"$RAIZ/scripts/pack.py\" pintados \"$_pack_ref\" \"$FLAVOR_ICONES\" $_pintar_onde)\" || ORIGEM=\"\"\n# A pasta temporária vai num nome próprio: o ORIGEM pode mudar logo abaixo (as pastas do pack), e\n# o trap leria o valor de então — apagaria o acervo do pack.\n_pintado_temporario=\"\"\ncase \"$ORIGEM\" in */meow-pintados-*) _pintado_temporario=\"$ORIGEM\"; trap 'rm -rf \"$_pintado_temporario\"' EXIT ;; esac\n"
},
{
"arquivo": "scripts/icones_pastas.sh",
"antes": "_pastas_do_pack=\"$(meow_pack_arquivo icones/sistema/pastas)\"\n[ -n \"$_pastas_do_pack\" ] || _pastas_do_pack=\"$(meow_pack_arquivo icones/pastas assets/icones/pastas-dracula)\"\n",
"depois": "# As pastas desenhadas pelo pack (o Dracula) moram em `icones/sistema/`, plana; quando a pasta\n# declarada é o próprio molde (o pack-base), a origem é o molde pintado, acima.\n_pastas_decl=\"$(python3 \"$RAIZ/scripts/pack.py\" acervo \"$_pack_ref\" icones.pastas.desenhos 2>/dev/null)\" || _pastas_decl=\"\"\n_molde=\"$(python3 \"$RAIZ/scripts/pack.py\" acervo \"$_pack_ref\" icones.mimetypes.desenhos 2>/dev/null)\" || _molde=\"\"\n_pastas_do_pack=\"\"\n[ -n \"$_pastas_decl\" ] && [ \"${_pastas_decl%/}\" != \"${_molde%/}\" ] && _pastas_do_pack=\"${_pastas_decl%/}\"\n"
},
{
"arquivo": "scripts/icones_sistema.sh",
"antes": "ORIGEM=\"$RAIZ/packs/meowsystem/icones/sistema/arcticons\"\n",
"depois": "ORIGEM=\"$RAIZ/packs/meowsystem/icones/sistema\"\n"
},
{
"arquivo": "scripts/icones_sistema.sh",
"antes": "    meow_pula \"o acervo Arcticons não está em packs/meowsystem/icones/sistema/arcticons — nada a vestir\"\n",
"depois": "    meow_pula \"o acervo Arcticons não está em packs/meowsystem/icones/sistema — nada a vestir\"\n"
},
{
"arquivo": "scripts/icones_tray_steam.sh",
"antes": "GLIFO=\"${MEOW_TRAY_STEAM_GLIFO:-$RAIZ/packs/meowsystem/icones/sistema/arcticons/steam.svg}\"\n",
"depois": "# P96: o glifo mora numa das três pastas planas do pack-base (uma cópia só, onde caiu)\nGLIFO=\"${MEOW_TRAY_STEAM_GLIFO:-}\"\nif [ -z \"$GLIFO\" ]; then\n  for _p in sistema apps biblioteca; do\n    GLIFO=\"$RAIZ/packs/meowsystem/icones/$_p/steam.svg\"; [ -f \"$GLIFO\" ] && break\n  done\nfi\n"
},
{
"arquivo": "scripts/icones_tray_steam.sh",
"antes": "    meow_pula \"sem o glifo steam em packs/meowsystem/icones/sistema/arcticons — nada a vestir\"\n",
"depois": "    meow_pula \"sem o glifo steam em packs/meowsystem/icones — nada a vestir\"\n"
},
{
"arquivo": "scripts/icones_tray_zapzap.sh",
"antes": "GLIFO=\"${MEOW_TRAY_ZAPZAP_GLIFO:-$RAIZ/packs/meowsystem/icones/sistema/arcticons/whatsapp.svg}\"\n",
"depois": "# P96: o glifo mora numa das três pastas planas do pack-base (uma cópia só, onde caiu)\nGLIFO=\"${MEOW_TRAY_ZAPZAP_GLIFO:-}\"\nif [ -z \"$GLIFO\" ]; then\n  for _p in sistema apps biblioteca; do\n    GLIFO=\"$RAIZ/packs/meowsystem/icones/$_p/whatsapp.svg\"; [ -f \"$GLIFO\" ] && break\n  done\nfi\n"
},
{
"arquivo": "scripts/leitura_build.sh",
"antes": "  \"$RAIZ/packs/meowsystem/icones/sistema/leitura/r2.svg\"\n  \"$RAIZ/packs/meowsystem/icones/sistema/leitura/s3.svg\"\n  \"$RAIZ/packs/meowsystem/icones/sistema/leitura/r1.svg\"\n  \"$RAIZ/packs/meowsystem/icones/sistema/leitura/r6.svg\"\n",
"depois": "  \"$RAIZ/packs/meowsystem/icones/sistema/leitura-r2.svg\"\n  \"$RAIZ/packs/meowsystem/icones/sistema/leitura-s3.svg\"\n  \"$RAIZ/packs/meowsystem/icones/sistema/leitura-r1.svg\"\n  \"$RAIZ/packs/meowsystem/icones/sistema/leitura-r6.svg\"\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "PACK_PADRAO = \"catppuccin\"\n",
"depois": "PACK_PADRAO = \"meowsystem\"\n\n# O Catppuccin entrou no pack `meowsystem` em 23/10/2026 (P96). Um conf, um\n# pack de terceiro (`heranca`) ou uma linha de mapa (`pack:catppuccin:`) escritos\n# antes disso continuam achando o pack, pelo nome de antes.\nAPELIDOS = {\"catppuccin\": \"meowsystem\"}\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "        return os.path.abspath(ref)\n    for base in raizes():\n",
"depois": "        return os.path.abspath(ref)\n    if ref in APELIDOS and not any(os.path.isfile(os.path.join(b, ref, \"pack.json\")) for b in raizes()):\n        ref = APELIDOS[ref]\n    for base in raizes():\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "    \"arcticons-apps\": \"apps/arcticons\",\n    \"convertidos-apps\": \"apps/convertidos\",\n    \"arcticons\": \"sistema/arcticons\",\n    \"autorais/leitura\": \"sistema/leitura\",\n",
"depois": "    \"arcticons-apps\": \"apps\",\n    \"convertidos-apps\": \"apps\",\n    \"arcticons\": \"sistema\",\n    \"autorais/leitura\": \"sistema\",\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "    (\"assets/icones/arcticons-apps/\", \"packs/meowsystem/icones/apps/arcticons/\"),\n    (\"assets/icones/convertidos-apps/\", \"packs/meowsystem/icones/apps/convertidos/\"),\n    (\"assets/icones/arcticons/\", \"packs/meowsystem/icones/sistema/arcticons/\"),\n    (\"assets/icones/autorais/leitura/\", \"packs/meowsystem/icones/sistema/leitura/\"),\n    (\"assets/icones/resgatados/\", \"packs/dracula/icones/apps/resgatados/\"),\n",
"depois": "    (\"assets/icones/arcticons-apps/\", \"packs/meowsystem/icones/apps/\"),\n    (\"assets/icones/convertidos-apps/\", \"packs/meowsystem/icones/apps/\"),\n    (\"assets/icones/arcticons/\", \"packs/meowsystem/icones/sistema/arcticons/\"),\n    (\"assets/icones/autorais/leitura/\", \"packs/meowsystem/icones/sistema/\"),\n    (\"assets/icones/resgatados/\", \"packs/dracula/icones/apps/\"),\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "PADROES_DE_ANTES = {\"icones/apps/autorais/\": \"icones/autorais/\",\n",
"depois": "PADROES_DE_ANTES = {\"icones/apps/\": \"icones/autorais/\",\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "def caminho_de_hoje(caminho):\n    \"\"\"O caminho de um desenho que mudou de pasta na P88, ou ele mesmo.\"\"\"\n",
"depois": "TABELA_DE_ANTES = os.path.join(RAIZ, \"packs\", \"CAMINHOS-DE-ANTES.tsv\")\n\n\ndef _tabela_de_antes():\n    \"\"\"{caminho de antes da P96: caminho de hoje} — a tabela que o reorganizar-2-packs.sh escreveu.\"\"\"\n    saida = {}\n    try:\n        with open(TABELA_DE_ANTES, encoding=\"utf-8\") as fh:\n            for linha in fh:\n                if linha.startswith(\"#\") or \"\\t\" not in linha:\n                    continue\n                antes, agora = linha.rstrip(\"\\n\").split(\"\\t\", 1)\n                saida[antes] = agora\n    except OSError:\n        pass\n    return saida\n\n\ndef caminho_de_hoje(caminho):\n    \"\"\"O caminho de um desenho que mudou de pasta (P88, P96), ou ele mesmo.\"\"\"\n    cheio = caminho if os.path.isabs(caminho) else os.path.join(RAIZ, caminho)\n    if os.path.exists(cheio):\n        return caminho\n    rel = os.path.relpath(cheio, RAIZ) if cheio.startswith(RAIZ + os.sep) else None\n    if rel is None:\n        return caminho\n    for _volta in range(3):\n        rel_p88 = rel\n        for antes, agora in CAMINHOS_DE_ANTES:\n            padrao = \"^\" + re.escape(antes).replace(r\"\\*\", \"([a-z0-9][a-z0-9-]*)\")\n            achou = re.match(padrao, rel)\n            if achou:\n                rel = (agora.replace(\"*\", achou.group(1)) if achou.groups() else agora) + rel[achou.end():]\n                break\n        novo = _tabela_de_antes().get(rel)\n        if novo:\n            return novo if not os.path.isabs(caminho) else os.path.join(RAIZ, novo)\n        if rel == rel_p88:\n            break\n    if os.path.exists(os.path.join(RAIZ, rel)):\n        return rel if not os.path.isabs(caminho) else os.path.join(RAIZ, rel)\n    return caminho\n\n\ndef _caminho_de_hoje_p88(caminho):\n    \"\"\"A regra da P88 sozinha (o que o `caminho_de_hoje` fazia até a P96).\"\"\"\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "        return _dentro(raiz, resto, \"alvo\")\n    except Recusa:\n        raise Recusa(f\"{valor!r} sai de {raiz}\") from None\n",
"depois": "        cheio = _dentro(raiz, resto, \"alvo\")\n    except Recusa:\n        raise Recusa(f\"{valor!r} sai de {raiz}\") from None\n    if not os.path.exists(cheio) and \"/\" in resto.strip(\"/\"):\n        # P96: as três pastas são planas; `apps/arcticons/x.svg` de um mapa de antes\n        # é o `x.svg` de uma das três, hoje.\n        partes = resto.strip(\"/\").split(\"/\")\n        nome = partes[-1]\n        for pasta in PASTAS_DO_FORMATO:\n            cand = os.path.join(raiz, pasta, nome)\n            if os.path.isfile(cand):\n                try:\n                    return _dentro(raiz, os.path.join(pasta, nome), \"alvo\")\n                except Recusa:\n                    break\n        if len(partes) > 2 and partes[0] in PASTAS_DO_FORMATO:\n            try:\n                return _dentro(raiz, os.path.join(partes[0], nome), \"alvo\")   # ausente, no lugar plano\n            except Recusa:\n                pass\n    return cheio\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "PASTA_AUTORAIS = \"icones/apps/autorais/\"\n",
"depois": "PASTA_AUTORAIS = \"icones/apps/\"\n# O rótulo do seletor mora no `catalog.json` de cada uma das três pastas; desde a P96\n# os autorais moram em `apps/`, e o catálogo não é declaração de desenho.\nCATALOGO = \"catalog.json\"\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "                if arq.endswith(\".json\"):\n",
"depois": "                if arq.endswith(\".json\") and arq != CATALOGO:\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "                valor = valor[parte]\n            if valor is None:\n",
"depois": "                valor = valor[parte]\n            if valor is None and chave == [\"arquivo\"]:\n                # P96 (23/10/2026): o modelo que a paleta preenche inteiro não é do pack, é do\n                # motor — `scripts/temas-de-apps/<app>/<app>.modelo.*`. O pack declara o\n                # aplicativo (o bloco existe) e o modelo vem daqui.\n                pasta = os.path.join(RAIZ, \"scripts\", \"temas-de-apps\", alvo)\n                try:\n                    modelos = sorted(f for f in os.listdir(pasta) if f.startswith(alvo + \".modelo.\"))\n                except OSError:\n                    modelos = []\n                if modelos:\n                    return quem, os.path.join(pasta, modelos[0])\n            if valor is None:\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "    partes = [\"MeowSystem\", _so_letras(nome) or _so_letras(ident) or \"Pack\"]\n    if flavor and flavor.lower() != ident.lower() and _so_letras(flavor):\n",
"depois": "    partes = [\"MeowSystem\", _so_letras(nome) or _so_letras(ident) or \"Pack\"]\n    if partes[1].lower() == \"meowsystem\":\n        partes = [\"MeowSystem\"]          # o pack padrão leva o nome do produto (P96): sem «MeowSystem-MeowSystem»\n    if flavor and flavor.lower() != ident.lower() and _so_letras(flavor):\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "        for arq in sorted(os.listdir(pasta_aut)):\n            if arq.endswith(\".json\"):\n                ler_autoral(os.path.join(pasta_aut, arq))\n",
"depois": "        for arq in sorted(os.listdir(pasta_aut)):\n            if arq.endswith(\".json\") and arq != CATALOGO:\n                ler_autoral(os.path.join(pasta_aut, arq))\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "            f\"    ou biblioteca/ (o resto, para escolher). Mova a pasta para dentro de uma delas.\")\n\n",
"depois": "            f\"    ou biblioteca/ (o resto, para escolher). Mova a pasta para dentro de uma delas.\")\n    # P96 (23/10/2026): as três são planas. Flavor e origem são sufixo no nome e linha no\n    # PROCEDENCIA.md, nunca subpasta.\n    dentro = sorted(f\"{t}/{d}\" for t in PASTAS_DO_FORMATO if os.path.isdir(os.path.join(pasta, t))\n                    for d in os.listdir(os.path.join(pasta, t))\n                    if os.path.isdir(os.path.join(pasta, t, d)))\n    _exigir(not dentro,\n            f\"icones/: {', '.join(dentro)} — as três pastas não têm subpasta. O flavor vai no\\n\"\n            f\"    nome (`desenho-mocha.svg`) e a origem no PROCEDENCIA.md; ponha os arquivos direto\\n\"\n            f\"    em apps/, sistema/ ou biblioteca/.\")\n\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "        svgs += [a for a in arquivos if a.endswith(\".svg\")]\n",
"depois": "        svgs += [os.path.join(base, a) for a in arquivos if a.endswith(\".svg\")]\n    # P96: as três pastas são planas e as categorias dividem a pasta; cada uma conta o que é dela.\n    cat = categoria.rsplit(\".\", 1)[-1]\n    if cat == \"mimetypes\":\n        def do_molde(c):\n            try:\n                with open(c, encoding=\"utf-8\") as fh:\n                    return bool(RE_VAR_CTP.search(fh.read()))\n            except (OSError, UnicodeDecodeError):\n                return False\n        svgs = [c for c in svgs if do_molde(c)]\n    elif cat == \"autorais\":\n        svgs = [c for c in svgs if any(os.path.basename(c).endswith(f\"-{f}.svg\") for f in flavors)]\n    elif cat == \"pastas\":\n        mapa = acervo(categoria + \".mapa\", ref=ref)\n        if mapa and os.path.isfile(mapa):\n            glifos = set()\n            for linha in open(mapa, encoding=\"utf-8\"):\n                linha = linha.split(\"#\", 1)[0].strip()\n                if \":\" in linha:\n                    glifos.add(linha.split(\":\", 1)[1].strip() + \".svg\")\n            svgs = [c for c in svgs if os.path.basename(c) in glifos]\n    svgs = [os.path.basename(c) for c in svgs]\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "            for flavor in sorted(por_flavor):\n                grupo(\"pack:%s:autorais:%s\" % (pid, flavor or \"-\"), nome_pack,\n",
"depois": "            for flavor in sorted(por_flavor):\n                if not flavor and os.path.realpath(pasta_aut) == os.path.realpath(os.path.join(dir_pack, \"icones\", \"apps\")):\n                    continue        # P96: em apps/ plana, autoral é só o que tem o flavor no nome\n                grupo(\"pack:%s:autorais:%s\" % (pid, flavor or \"-\"), nome_pack,\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "            grupo(gid, nome_pack, nome, pid, tipo, dirpath, _arquivos_da_pasta(dirpath, \".svg\"))\n",
"depois": "            svgs = _arquivos_da_pasta(dirpath, \".svg\")\n            if real_aut and os.path.realpath(dirpath) == os.path.realpath(real_aut):\n                # P96: os autorais moram em apps/ (plana); eles têm o grupo deles, por flavor\n                flavors = _flavors_do_pack(dir_pack)\n                svgs = [a for a in svgs\n                        if not any(os.path.basename(a)[:-4].endswith(\"-\" + f) for f in flavors)]\n            grupo(gid, nome_pack, nome, pid, tipo, dirpath, svgs)\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "            continue\n        chave = {\"próprio\": \"próprio\", \"herdado\": f\"herdado de {quem}\",\n",
"depois": "            continue\n        # O molde dos tipos de arquivo é desenho do motor (P96): a forma vem do pack-base e a cor da\n        # paleta do pack — dizê-lo «do motor» é o certo, e a linha do Dracula cabe nos 220.\n        if tipo == \"herdado\" and quem == PACK_BASE and cat == \"icones.mimetypes\":\n            tipo = \"motor\"\n        chave = {\"próprio\": \"próprio\", \"herdado\": f\"herdado de {quem}\",\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "    dono = _pack_de(base)\n    if dono == ident:\n        p_dono, dados_dono = p, dados\n    else:\n        p_dono, dados_dono, _d = validar(dono, silencioso=True)\n    return {\n        \"base\": base,\n        \"dono\": dono,\n        \"p_dono\": p_dono,\n        \"dados_dono\": dados_dono,\n        \"existem\": [f for f in dados_dono[\"flavors\"] if os.path.isdir(os.path.join(base, f))],\n        \"escolhido\": campo(ident, \"icones.mimetypes.flavor\") if dono != ident else None,\n    }\n",
"depois": "    # P96 (23/10/2026): o acervo é UM molde (`var(--vscode-ctp-<papel>)`), e a instalação o\n    # pinta com a paleta do pack no ar. Todo flavor da paleta dele existe, então; o dono das\n    # cores é o próprio pack.\n    return {\n        \"base\": base,\n        \"dono\": ident,\n        \"p_dono\": p,\n        \"dados_dono\": dados,\n        \"existem\": list(dados[\"flavors\"]),\n        \"escolhido\": None,\n    }\n\n\ndef _cores_do_flavor(ref, flavor):\n    \"\"\"As 26 cores de `flavor`: da paleta do pack, ou da primeira da herança que o tem.\"\"\"\n    vistos, r = set(), ref\n    while r and r not in vistos:\n        vistos.add(r)\n        try:\n            _p, dados, _d = validar(r, silencioso=True)\n        except Recusa:\n            break\n        if flavor in dados[\"flavors\"]:\n            return dados[\"flavors\"][flavor]\n        r = campo(r, \"icones.mimetypes.herda\") or campo(r, \"heranca\")\n    if ref != PACK_BASE:\n        try:\n            _p, dados, _d = validar(PACK_BASE, silencioso=True)\n            return dados[\"flavors\"].get(flavor)\n        except Recusa:\n            return None\n    return None\n\n\ndef dir_de_pintados(ident, flavor):\n    base = os.environ.get(\"XDG_CACHE_HOME\") or os.path.join(os.path.expanduser(\"~\"), \".cache\")\n    return os.path.join(base, \"meowsystem\", \"pintados\", f\"{ident}-{flavor}\")\n\n\ndef pintar_mimetypes(ref, flavor, temporario=False):\n    \"\"\"O molde de mimetype pintado no `flavor`: o diretório, refeito do pack a cada chamada.\n\n    O molde mora no pack (é a fonte); o pintado é derivado e mora no cache, como o tema\n    instalado. Só se escreve o arquivo cujo conteúdo mudou, e sai o que deixou o molde.\n    Levanta Recusa quando o flavor não existe em paleta nenhuma da cadeia.\n    \"\"\"\n    import tempfile\n    p, _dados, dir_pack = validar(_ref_ativa(ref), silencioso=True)\n    ident = p.get(\"id\", os.path.basename(dir_pack))\n    if not RE_FLAVOR_CONF.match(str(flavor or \"\")):\n        raise Recusa(f\"o flavor {flavor!r} não é um nome aceito\")\n    molde = acervo(\"icones.mimetypes.desenhos\", ref=dir_pack)\n    if not molde or not os.path.isdir(molde):\n        raise Recusa(\"a cadeia deste pack não tem molde de tipo de arquivo\")\n    cores = _cores_do_flavor(dir_pack, flavor)\n    if not cores:\n        raise Recusa(f\"nenhuma paleta da cadeia tem o flavor {flavor!r}\")\n    dentro = os.path.realpath(molde) + os.sep\n    desenhos = sorted(f for f in os.listdir(molde) if f.endswith(\".svg\")\n                      and os.path.isfile(os.path.join(molde, f)) and not os.path.islink(os.path.join(molde, f))\n                      and os.path.realpath(os.path.join(molde, f)).startswith(dentro))\n    destino = tempfile.mkdtemp(prefix=\"meow-pintados-\") if temporario else dir_de_pintados(ident, flavor)\n    os.makedirs(destino, exist_ok=True)\n    for nome in desenhos:\n        with open(os.path.join(molde, nome), encoding=\"utf-8\") as fh:\n            texto = fh.read()\n        if not RE_VAR_CTP.search(texto):\n            continue                     # não é desenho do molde (um glifo de traço, uma pasta)\n        faltou = sorted({m for m in RE_VAR_CTP.findall(texto) if m not in cores})\n        if faltou:\n            raise Recusa(f\"{nome}: a paleta {flavor!r} não tem {', '.join(faltou)}\")\n        novo = RE_VAR_CTP.sub(lambda m: cores[m.group(1)].lower(), texto)\n        alvo = os.path.join(destino, nome)\n        try:\n            with open(alvo, encoding=\"utf-8\") as fh:\n                if fh.read() == novo:\n                    continue\n        except OSError:\n            pass\n        fd, tmp = tempfile.mkstemp(dir=destino, prefix=\".meow-\")\n        with os.fdopen(fd, \"w\", encoding=\"utf-8\") as fh:\n            fh.write(novo)\n        os.chmod(tmp, 0o644)\n        os.replace(tmp, alvo)\n    vivos = set(desenhos)\n    for nome in os.listdir(destino):\n        if nome.endswith(\".svg\") and nome not in vivos:\n            os.remove(os.path.join(destino, nome))\n    return destino\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "        derivar_mimetypes(ident, seco=seco)\n",
"depois": "        # P96: o pintado não mora mais no pack; a instalação pinta do molde (`pintar_mimetypes`)\n        print(f\"  --   {ident}: icones.mimetypes.derivar não escreve mais no pack — a instalação pinta o molde\")\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "PASTA_DE_ANTES_POR_NOME = {\"autorais\": \"apps/autorais\", \"resgatados\": \"apps/resgatados\",\n                           \"feitos-a-mao\": \"biblioteca/feitos-a-mao\",\n                           \"pastas\": \"sistema/pastas\", \"mimetypes\": \"sistema/mimetypes\"}\n",
"depois": "# P96 (23/10/2026): as três pastas são planas — o que vinha de uma pasta de antes cai direto\n# na pasta dela, sem subpasta (o flavor de um acervo de tipo de arquivo vira sufixo no nome).\nPASTA_DE_ANTES_POR_NOME = {\"autorais\": \"apps\", \"resgatados\": \"apps\",\n                           \"feitos-a-mao\": \"biblioteca\",\n                           \"pastas\": \"sistema\", \"mimetypes\": \"sistema\"}\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "    if not isinstance(p, dict) or not isinstance(p.get(\"formato\"), int) or p[\"formato\"] >= 2:\n",
"depois": "    if not isinstance(p, dict) or not isinstance(p.get(\"formato\"), int):\n        return membros\n    com_subpasta = any(len(r.split(\"/\")) > 3 and r.split(\"/\")[0] == \"icones\" and r.split(\"/\")[1] in PASTAS_DO_FORMATO\n                       for r in membros)\n    if p[\"formato\"] >= 2 and not com_subpasta:\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "                \"%s/%s\" % (PASTA_DA_CATEGORIA[declarada[d]], d)\n                if declarada.get(d) in PASTA_DA_CATEGORIA else \"biblioteca/%s\" % d)\n\n    def novo(caminho, prefixo=\"icones/\"):\n        for d, para in troca.items():\n            if caminho == prefixo + d or caminho.startswith(prefixo + d + \"/\"):\n                return prefixo + para + caminho[len(prefixo + d):]\n",
"depois": "                PASTA_DA_CATEGORIA[declarada[d]] if declarada.get(d) in PASTA_DA_CATEGORIA else \"biblioteca\")\n\n    # a subpasta DENTRO de uma das três (um pack da P88: apps/autorais, sistema/pastas…) também some\n    for t in PASTAS_DO_FORMATO:\n        troca.setdefault(t, t)\n\n    def novo(caminho, prefixo=\"icones/\"):\n        \"\"\"O caminho de hoje: a pasta de antes vira uma das três, PLANA (o arquivo direto nela).\"\"\"\n        for d, para in troca.items():\n            if caminho == prefixo + d or caminho.rstrip(\"/\") == prefixo + d:\n                return prefixo + para + (\"/\" if caminho.endswith(\"/\") else \"\")\n            if caminho.startswith(prefixo + d + \"/\"):\n                resto = caminho[len(prefixo + d) + 1:]\n                if not resto or resto.endswith(\"/\"):\n                    return prefixo + para + \"/\"\n                miolo = resto.split(\"/\")\n                nome = miolo[-1]\n                if len(miolo) > 1 and miolo[-2] != \"css-variables\" and (d == \"mimetypes\" or \"mimetypes\" in miolo[:-1]):\n                    base, ext = os.path.splitext(nome)\n                    nome = \"%s-%s%s\" % (base, miolo[-2], ext)   # o flavor do tipo de arquivo vira sufixo\n                return prefixo + para + \"/\" + nome\n"
},
{
"arquivo": "scripts/pack.py",
"antes": "            return OK\n        if verbo == \"construir\" and len(argv) in (3, 4):\n",
"depois": "            return OK\n        if verbo == \"pintados\" and len(argv) in (4, 5):\n            # `--temporario`: pinta numa pasta nova do TMPDIR (quem só confere não escreve na casa)\n            temporario = len(argv) == 5 and argv[4] == \"--temporario\"\n            print(pintar_mimetypes(argv[2] or None, argv[3], temporario=temporario))\n            return OK\n        if verbo == \"construir\" and len(argv) in (3, 4):\n"
},
{
"arquivo": "scripts/prompt.sh",
"antes": "_PROMPT_PACK=\"$(basename \"${_PROMPT_PACK:-catppuccin}\")\"\n",
"depois": "_PROMPT_PACK=\"$(basename \"${_PROMPT_PACK:-meowsystem}\")\"\n# O pack padrão (P96) é o Catppuccin dentro do meowsystem: a paleta do starship continua com o\n# nome da família, `catppuccin_<flavor>`, que é o do preset de `assets/prompt/starship.toml`.\n[ \"$_PROMPT_PACK\" = \"meowsystem\" ] && _PROMPT_PACK=\"catppuccin\"\n"
},
{
"arquivo": "scripts/resgatados_folha.sh",
"antes": "ACERVO=\"$RAIZ/packs/dracula/icones/apps/resgatados\"\n",
"depois": "ACERVO=\"$RAIZ/packs/dracula/icones/apps\"\n"
},
{
"arquivo": "scripts/temas-de-apps/obsidian/manifesto.sh",
"antes": "print(\"outros=\" + regua(validos - {ident}))\nprint(\"packs=\" + regua(validos | {ident}))\n",
"depois": "# O nome de antes do pack no ar (o `catppuccin` do `meowsystem`, P96) é dele, e não de outro.\nmeus = {ident} | {a for a, d in getattr(pack, \"APELIDOS\", {}).items() if d == ident}\nprint(\"outros=\" + regua(validos - meus))\nprint(\"packs=\" + regua(validos | meus))\n"
},
{
"arquivo": "src/applets/leitura/src/main.rs",
"antes": "const ARTE_LUA: &[u8] = include_bytes!(\"../../../../packs/meowsystem/icones/sistema/leitura/r2.svg\");\nconst ARTE_SOL: &[u8] = include_bytes!(\"../../../../packs/meowsystem/icones/sistema/leitura/s3.svg\");\nconst ARTE_LIVRO: &[u8] = include_bytes!(\"../../../../packs/meowsystem/icones/sistema/leitura/r1.svg\");\nconst ARTE_HALO: &[u8] = include_bytes!(\"../../../../packs/meowsystem/icones/sistema/leitura/r6.svg\");\n",
"depois": "const ARTE_LUA: &[u8] = include_bytes!(\"../../../../packs/meowsystem/icones/sistema/leitura-r2.svg\");\nconst ARTE_SOL: &[u8] = include_bytes!(\"../../../../packs/meowsystem/icones/sistema/leitura-s3.svg\");\nconst ARTE_LIVRO: &[u8] = include_bytes!(\"../../../../packs/meowsystem/icones/sistema/leitura-r1.svg\");\nconst ARTE_HALO: &[u8] = include_bytes!(\"../../../../packs/meowsystem/icones/sistema/leitura-r6.svg\");\n"
},
{
"arquivo": "tests/acento.sh",
"antes": "saida=\"$(amb env MEOW_PACK_DIR=\"$RAIZ/packs/catppuccin\" MEOW_PALETA=\"$RAIZ/packs/catppuccin/paleta.json\" \\\n",
"depois": "saida=\"$(amb env MEOW_PACK_DIR=\"$RAIZ/packs/meowsystem\" MEOW_PALETA=\"$RAIZ/packs/meowsystem/paleta.json\" \\\n"
},
{
"arquivo": "tests/acento.sh",
"antes": "cp -a \"$RAIZ/packs/catppuccin\" \"$PACKS/\" || exit 2\nrm -rf \"$PACKS\"/catppuccin/temas/capturados/mocha-*\nconf frappe pink catppuccin\n",
"depois": "cp -a \"$RAIZ/packs/meowsystem\" \"$PACKS/\" || exit 2\nrm -rf \"$PACKS\"/meowsystem/temas/capturados/mocha-*\nconf frappe pink meowsystem\n"
},
{
"arquivo": "tests/acervo-da-ficha.sh",
"antes": "checa(\"packs/dracula/icones/apps/net.waterfox.waterfox.svg\" in achados,\n      \"«firefox» acha o net.waterfox.waterfox.svg (o Firefox-Dracula, pelo catalog.json de apps/)\",\n",
"depois": "# [P96, 23/10/2026: o Waterfox e o Firefox vestem o lobo e a lua do manuais-final, `apps/firefox.svg`.]\ncheca(\"packs/dracula/icones/apps/firefox.svg\" in achados,\n      \"«firefox» acha o firefox.svg (o desenho que veste o Firefox e o Waterfox)\",\n"
},
{
"arquivo": "tests/acervo-da-ficha.sh",
"antes": "checa(ordem and ordem[0].startswith(\"pack:dracula:\")\n      and any(g.startswith(\"pack:catppuccin:\") for g in ordem)\n      and any(g.startswith(\"pack:meowsystem:\") for g in ordem),\n",
"depois": "checa(ordem and ordem[0].startswith(\"pack:dracula:\")\n      and any(g.startswith(\"pack:meowsystem:\") for g in ordem),\n"
},
{
"arquivo": "tests/acervo-da-ficha.sh",
"antes": "checa(base and set(base.values()) == {\"traco\"} and \"pack:meowsystem:apps/arcticons\" in base,\n      \"o acervo do pack-base aparece como traço\", repr(base))\n\n# --- 4c. as subpastas da P87: versões e projetos dela — decisões 13 e 16 -----------\n#   `biblioteca/versoes/` guarda todas as versões e rascunhos recuperados (SVG e\n#   PNG), e `biblioteca/projetos/` os desenhos dos projetos dela fora da lista de\n#   exclusão. Cada uma é um grupo da ficha, com o rótulo de gente e a contagem\n#   que o disco tem; o rótulo de cada desenho vem do `catalog.json` da pasta.\npor_caminho = {os.path.normpath(caminho_de(i)): i for i in itens}\nfor sub, rotulo, minimo in ((\"versoes\", \"versões\", 100), (\"projetos\", \"projetos dela\", 5)):\n    pasta_p87 = os.path.join(raiz, \"packs\", \"dracula\", \"icones\", \"biblioteca\", sub)\n    esperado = len([a for a in os.listdir(pasta_p87) if a.endswith(\".svg\")])\n    gp = next((g for g in grupos if g[\"id\"] == \"pack:dracula:biblioteca/\" + sub), None)\n    checa(gp and gp[\"total\"] == esperado and esperado >= minimo and gp[\"nome\"] == rotulo,\n          \"a pasta «%s» da biblioteca do Dracula aparece na ficha com %d desenhos\" % (rotulo, esperado),\n          repr(gp))\n    png_p87 = next((g for g in grupos if g[\"id\"] == \"pack:dracula:biblioteca/%s:png\" % sub), None)\n    npng = len([a for a in os.listdir(pasta_p87) if a.endswith(\".png\")])\n    checa(bool(png_p87) == bool(npng) and (not npng or png_p87[\"total\"] == npng),\n          \"e os PNG de «%s», vistos e travados, num grupo à parte (%d)\" % (rotulo, npng), repr(png_p87))\n    sem_rotulo = sorted(a for a in os.listdir(pasta_p87) if a.endswith((\".svg\", \".png\"))\n                        and not (por_caminho.get(os.path.normpath(os.path.join(pasta_p87, a))) or {}).get(\"rotulo\"))\n    checa(not sem_rotulo, \"todo desenho de «%s» tem rótulo na ficha\" % rotulo, repr(sem_rotulo[:4]))\n",
"depois": "checa(base and base.get(\"pack:meowsystem:apps\") == \"traco\",\n      \"o acervo do pack-base aparece como traço\", repr(base))\n\n# --- 4c. as três pastas são planas — P96, 23/10/2026 -------------------------------\n#   Até a P96 a biblioteca do Dracula tinha `versoes/` e `projetos/`, cada uma um grupo\n#   da ficha. Uma versão por ícone, e a origem mora no PROCEDENCIA: a ficha tem um grupo\n#   por pasta (apps/, biblioteca/), com a contagem que o disco tem, e nenhum grupo de subpasta.\nfor pasta_rel in (\"apps\", \"biblioteca\"):\n    pasta_p96 = os.path.join(raiz, \"packs\", \"dracula\", \"icones\", pasta_rel)\n    gp = next((g for g in grupos if g[\"id\"] == \"pack:dracula:\" + pasta_rel), None)\n    flavors = (\"dracula\", \"alucard\")\n    esperado = len([a for a in os.listdir(pasta_p96) if a.endswith(\".svg\")\n                    and not (pasta_rel == \"apps\" and a[:-4].endswith(tuple(\"-\" + f for f in flavors)))])\n    checa(gp and gp[\"total\"] == esperado, \"a pasta %s do Dracula aparece inteira na ficha (%d)\" % (pasta_rel, esperado),\n          repr(gp and gp[\"total\"]))\nsub = [g[\"id\"] for g in grupos if re.match(r\"^pack:[a-z0-9-]+:(apps|biblioteca)/\", g[\"id\"])]\ncheca(not sub, \"nenhum grupo de subpasta: as três pastas são planas\", repr(sub))\n"
},
{
"arquivo": "tests/acervo-da-ficha.sh",
"antes": "    \"packs/dracula/icones/apps/resgatados/net.waterfox.waterfox.svg\": \"Waterfox\",   # o comentário do apps.map\n",
"depois": "    \"packs/dracula/icones/apps/firefox.svg\": \"Waterfox\",   # o comentário do apps.map\n"
},
{
"arquivo": "tests/acervo-da-ficha.sh",
"antes": "    deles = sorted({(it[\"grupo\"], it.get(\"rotulo\")) for it in itens if it[\"glifo\"] == glifo})\n",
"depois": "    # [P96: uma versão por ícone — o desenho que não veste mais o app foi para a biblioteca, com a\n    #  descrição dele; o mesmo nome em toda pasta de APLICATIVO é o que esta conta cobra.]\n    deles = sorted({(it[\"grupo\"], it.get(\"rotulo\")) for it in itens if it[\"glifo\"] == glifo\n                    and it[\"grupo\"].endswith(\":apps\")})\n"
},
{
"arquivo": "tests/acervo-da-ficha.sh",
"antes": "checa({\"packs/dracula/icones/apps/net.waterfox.waterfox.svg\",\n       \"packs/dracula/icones/apps/resgatados/net.waterfox.waterfox.svg\"} <= achados,\n      \"«firefox» acha os dois desenhos da raposa: o do pack e o resgatado\",\n",
"depois": "# [P96: uma versão por ícone — a chama do Firefox-Dracula foi para a biblioteca, e acha-se também.]\ncheca({\"packs/dracula/icones/apps/firefox.svg\",\n       \"packs/dracula/icones/biblioteca/net.waterfox.waterfox.svg\"} <= achados,\n      \"«firefox» acha o desenho que veste e a chama guardada na biblioteca\",\n"
},
{
"arquivo": "tests/acervo-da-ficha.sh",
"antes": "checa(veste == \"packs/dracula/icones/apps/resgatados/net.waterfox.waterfox.svg\",\n",
"depois": "checa(veste == \"packs/dracula/icones/apps/firefox.svg\",\n"
},
{
"arquivo": "tests/acervo-da-ficha.sh",
"antes": "for rel, rotulo in ((\"packs/meowsystem/icones/apps/convertidos/com.obsproject.Studio.svg\", \"OBS Studio\"),\n                    (\"packs/meowsystem/icones/apps/convertidos/io.github.shiftey.Desktop.svg\", \"GitHub Desktop\")):\n",
"depois": "for rel, rotulo in ((\"packs/meowsystem/icones/apps/com.obsproject.Studio.svg\", \"OBS Studio\"),\n                    (\"packs/meowsystem/icones/apps/io.github.shiftey.Desktop.svg\", \"GitHub Desktop\")):\n"
},
{
"arquivo": "tests/app-completo.py",
"antes": "    glifos = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps\", \"arcticons\")\n    for nome in sorted(os.listdir(glifos)):\n        if nome.endswith(\".svg\"):\n            shutil.copyfile(os.path.join(glifos, nome), os.path.join(tema, nome))\n",
"depois": "    # [P96, 23/10/2026: as pastas do pack são planas; a lista do traço diz quais são os glifos do Arcticons.]\n    icones_base = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\")\n    with open(os.path.join(icones_base, \"arcticons.lista\"), encoding=\"utf-8\") as fh:\n        lista = [l.strip() for l in fh if l.strip() and not l.startswith(\"#\")]\n    for nome in sorted(lista):\n        for pasta in (\"apps\", \"biblioteca\", \"sistema\"):\n            origem = os.path.join(icones_base, pasta, nome)\n            if os.path.isfile(origem):\n                shutil.copyfile(origem, os.path.join(tema, nome))\n                break\n"
},
{
"arquivo": "tests/app-navegador.py",
"antes": "    glifos = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\", \"apps\", \"arcticons\")\n    for nome in sorted(os.listdir(glifos)):\n        if nome.endswith(\".svg\"):\n            shutil.copyfile(os.path.join(glifos, nome), os.path.join(tema, nome))\n",
"depois": "    # [P96, 23/10/2026: as pastas do pack são planas; a lista do traço diz quais são os glifos do Arcticons.]\n    icones_base = os.path.join(RAIZ, \"packs\", \"meowsystem\", \"icones\")\n    with open(os.path.join(icones_base, \"arcticons.lista\"), encoding=\"utf-8\") as fh:\n        lista = [l.strip() for l in fh if l.strip() and not l.startswith(\"#\")]\n    for nome in sorted(lista):\n        for pasta in (\"apps\", \"biblioteca\", \"sistema\"):\n            origem = os.path.join(icones_base, pasta, nome)\n            if os.path.isfile(origem):\n                shutil.copyfile(origem, os.path.join(tema, nome))\n                break\n"
},
{
"arquivo": "tests/app-uso-real.py",
"antes": "   *   que a trava continua sendo cobrada.] */\n  const pastas = [...ficha.querySelectorAll('.pasta-acervo')];\n  const vetores = pastas.find((d) => /[:/]feitos-a-mao$/.test(d.dataset.grupo || ''));\n",
"depois": "   *   que a trava continua sendo cobrada.\n   * [P96, 23/10/2026: a biblioteca é plana; os feitos à mão moram nela, e é a\n   *   pasta dela que se cobra.] */\n  const pastas = [...ficha.querySelectorAll('.pasta-acervo')];\n  const vetores = pastas.find((d) => /[:/](feitos-a-mao|biblioteca)$/.test(d.dataset.grupo || ''));\n"
},
{
"arquivo": "tests/app.sh",
"antes": "svg_png = open(os.path.join(raiz, \"packs\", \"dracula\", \"icones\", \"biblioteca\", \"feitos-a-mao\",\n                            \"obsidian.svg\"), \"rb\").read()\n",
"depois": "# [P96, 23/10/2026: a biblioteca é plana e uma versão por ícone; o logo do pack é o SVG estável.]\nsvg_png = open(os.path.join(raiz, \"packs\", \"dracula\", \"logo.svg\"), \"rb\").read()\n"
},
{
"arquivo": "tests/casa-real.sh",
"antes": "conf_com \"$TMP/c1c\" 'PACK=\"catppuccin\"' 'FLAVOR=\"mocha\"' 'ICONES_PASTAS=\"cat-dracula-${ACCENT}\"'\n",
"depois": "conf_com \"$TMP/c1c\" 'PACK=\"meowsystem\"' 'FLAVOR=\"mocha\"' 'ICONES_PASTAS=\"cat-dracula-${ACCENT}\"'\n"
},
{
"arquivo": "tests/casa-real.sh",
"antes": "conf_com \"$TMP/c2\" 'PACK=\"catppuccin\"' 'FLAVOR=\"mocha\"' 'ICONES_FLAVOR=\"macchiato\"' 'ICONES_PASTAS=\"cat-frappe-blue\"'\n",
"depois": "conf_com \"$TMP/c2\" 'PACK=\"meowsystem\"' 'FLAVOR=\"mocha\"' 'ICONES_FLAVOR=\"macchiato\"' 'ICONES_PASTAS=\"cat-frappe-blue\"'\n"
},
{
"arquivo": "tests/casa-real.sh",
"antes": "   && [ \"$(linha_de \"$C3\" PACK)\" = 'PACK=\"catppuccin\"' ]; then\n",
"depois": "   && [ \"$(linha_de \"$C3\" PACK)\" = 'PACK=\"meowsystem\"' ]; then\n"
},
{
"arquivo": "tests/casa-real.sh",
"antes": "conf_com \"$TMP/p-cat\" 'PACK=\"catppuccin\"' 'FLAVOR=\"mocha\"'\n",
"depois": "conf_com \"$TMP/p-cat\" 'PACK=\"meowsystem\"' 'FLAVOR=\"mocha\"'\n"
},
{
"arquivo": "tests/casa-real.sh",
"antes": "    MEOW_DRY_RUN=1 \"$RAIZ/bin/meow\" pack usar catppuccin > /dev/null 2>&1 &\n",
"depois": "    MEOW_DRY_RUN=1 \"$RAIZ/bin/meow\" pack usar meowsystem > /dev/null 2>&1 &\n"
},
{
"arquivo": "tests/claro-do-pack.sh",
"antes": "cp -a \"$RAIZ/packs/dracula\" \"$RAIZ/packs/catppuccin\" \"$PACKS/\" || exit 2\nCAT=\"$PACKS/catppuccin/temas/capturados\"; DRA=\"$PACKS/dracula/temas/capturados\"\n",
"depois": "cp -a \"$RAIZ/packs/dracula\" \"$RAIZ/packs/meowsystem\" \"$PACKS/\" || exit 2\nCAT=\"$PACKS/meowsystem/temas/capturados\"; DRA=\"$PACKS/dracula/temas/capturados\"\n"
},
{
"arquivo": "tests/claro-do-pack.sh",
"antes": "latte = {v.upper() for v in json.load(open(packs / \"catppuccin/paleta.json\"))[\"flavors\"][\"latte\"].values()}\n",
"depois": "latte = {v.upper() for v in json.load(open(packs / \"meowsystem/paleta.json\"))[\"flavors\"][\"latte\"].values()}\n"
},
{
"arquivo": "tests/claro-do-pack.sh",
"antes": "saida=\"$(amb env MEOW_PACK_DIR=\"$PACKS/catppuccin\" MEOW_PALETA=\"$PACKS/catppuccin/paleta.json\" \\\n",
"depois": "saida=\"$(amb env MEOW_PACK_DIR=\"$PACKS/meowsystem\" MEOW_PALETA=\"$PACKS/meowsystem/paleta.json\" \\\n"
},
{
"arquivo": "tests/claro-do-pack.sh",
"antes": "saida=\"$(amb env MEOW_PACK_DIR=\"$RAIZ/packs/catppuccin\" MEOW_PACKS= \\\n",
"depois": "saida=\"$(amb env MEOW_PACK_DIR=\"$RAIZ/packs/meowsystem\" MEOW_PACKS= \\\n"
},
{
"arquivo": "tests/conversor.sh",
"antes": "  \"$RAIZ/packs/catppuccin/icones/apps/autorais/cosmic-edit-mocha.svg\"          # autoral, já tem contorno (a fita colapsa)\n",
"depois": "  \"$RAIZ/packs/meowsystem/icones/apps/cosmic-edit-mocha.svg\"          # autoral, já tem contorno (a fita colapsa)\n"
},
{
"arquivo": "tests/conversor.sh",
"antes": "TERM=\"$RAIZ/packs/catppuccin/icones/apps/autorais/cosmic-term-mocha.svg\"\n",
"depois": "TERM=\"$RAIZ/packs/meowsystem/icones/apps/cosmic-term-mocha.svg\"\n"
},
{
"arquivo": "tests/conversor.sh",
"antes": "RET=\"$RAIZ/packs/meowsystem/icones/apps/convertidos/retoques/org.gimp.GIMP.svg\"\n",
"depois": "RET=\"$RAIZ/packs/meowsystem/icones/apps/org.gimp.GIMP.svg\"\n"
},
{
"arquivo": "tests/conversor.sh",
"antes": "  \"$RAIZ/packs/catppuccin/icones/apps/autorais/cosmic-edit-mocha.svg\"             # canário: a folha em branco\n  \"$RAIZ/packs/catppuccin/icones/apps/autorais/cosmic-term-mocha.svg\"             # canário: o quadrado\n",
"depois": "  \"$RAIZ/packs/meowsystem/icones/apps/cosmic-edit-mocha.svg\"             # canário: a folha em branco\n  \"$RAIZ/packs/meowsystem/icones/apps/cosmic-term-mocha.svg\"             # canário: o quadrado\n"
},
{
"arquivo": "tests/decisoes.sh",
"antes": "grupos = lambda no_ar=\"\": pack.acervos_de_icone(no_ar)\ndef stems(pid):\n",
"depois": "grupos = lambda no_ar=\"\": pack.acervos_de_icone(no_ar)\n_tab = os.path.join(os.path.dirname(sys.argv[1]), \"packs\", \"CAMINHOS-DE-ANTES.tsv\")\nantes_png = [l.split(\"\\t\", 1)[0] for l in open(_tab, encoding=\"utf-8\")] if os.path.exists(_tab) else []\ndef stems(pid):\n"
},
{
"arquivo": "tests/decisoes.sh",
"antes": "    for n in sys.argv[3:]:\n        if n + \".svg\" not in tem:\n            print(\"falta=\" + n)\n    sem_vetor = sorted(os.path.splitext(os.path.basename(a))[0] for g in grupos()\n                       if g[\"pack\"] == \"dracula\" and g[\"tipo\"] == \"png\"\n                       # versoes/ e projetos/ guardam todas as versões, PNG inclusive (decisão 13 do 02-decisoes.md)\n                       and not g[\"id\"].startswith((\"pack:dracula:biblioteca/versoes\", \"pack:dracula:biblioteca/projetos\"))\n                       for a in g[\"arquivos\"]\n                       if os.path.splitext(os.path.basename(a))[0] + \".svg\" not in tem)\n    print(\"png_sem_vetor=\" + \",\".join(sem_vetor))\nelif caso == \"seletor\":\n    for no_ar in (\"dracula\", \"catppuccin\"):\n",
"depois": "    # P96 (23/10/2026): uma versão por ícone. O vetor feito à mão que quem usa trocou por outra\n    # versão (a do manuais-final) saiu POR ESCOLHA, e a tabela de antes diz isso; sumir sem linha\n    # na tabela é o que esta conta caça.\n    antes = {}\n    tab = os.path.join(os.path.dirname(sys.argv[1]), \"packs\", \"CAMINHOS-DE-ANTES.tsv\")\n    if os.path.exists(tab):\n        for l in open(tab, encoding=\"utf-8\"):\n            if \"\\t\" in l and not l.startswith(\"#\"):\n                k, v = l.rstrip(\"\\n\").split(\"\\t\", 1)\n                antes[k] = v\n    for n in sys.argv[3:]:\n        if n + \".svg\" not in tem and \"packs/dracula/icones/biblioteca/feitos-a-mao/%s.svg\" % n not in antes:\n            print(\"falta=\" + n)\n    sem_vetor = sorted(os.path.splitext(os.path.basename(a))[0] for g in grupos()\n                       if g[\"pack\"] == \"dracula\" and g[\"tipo\"] == \"png\"\n                       for a in g[\"arquivos\"]\n                       if os.path.splitext(os.path.basename(a))[0] + \".svg\" not in tem\n                       # o PNG que quem usa escolheu guardar (projeto dela, versão) não é feito à mão à espera\n                       # do vetor: a origem dele está na tabela de antes (P96)\n                       and not any(k.endswith(\"/\" + os.path.basename(a)) and (\"/projetos/\" in k or \"/versoes/\" in k)\n                                   for k in antes_png))\n    print(\"png_sem_vetor=\" + \",\".join(sem_vetor))\nelif caso == \"seletor\":\n    for no_ar in (\"dracula\", \"meowsystem\"):\n"
},
{
"arquivo": "tests/decisoes.sh",
"antes": "for no_ar in dracula catppuccin; do\n  grep -qx \"$no_ar:packs=catppuccin,dracula,meowsystem\" <<< \"$r\" || bom=0\n",
"depois": "for no_ar in dracula meowsystem; do\n  grep -qx \"$no_ar:packs=dracula,meowsystem\" <<< \"$r\" || bom=0\n"
},
{
"arquivo": "tests/decisoes.sh",
"antes": "    XDG_STATE_HOME=\"$CASA/.local/state\" \"$RAIZ/bin/meow\" pack usar catppuccin --sem-aplicar >/dev/null 2>&1\n",
"depois": "    XDG_STATE_HOME=\"$CASA/.local/state\" \"$RAIZ/bin/meow\" pack usar meowsystem --sem-aplicar >/dev/null 2>&1\n"
},
{
"arquivo": "tests/decisoes.sh",
"antes": "registro 16 'Os achados da varredura' && ok \"16: os achados da varredura\" || falha \"a decisão 16 saiu do registro\"\nregistro 17 'AGENTS.md' && ok \"17: o AGENTS.md é exceção do sanitizador\" || falha \"a decisão 17 saiu do registro\"\n",
"depois": "registro 16 'Os achados da varredura' && ok \"16: os achados da varredura\" || falha \"a decisão 16 saiu do registro\"\n# P96 (23/10/2026): as linhas trocadas com o sim de quem usa, e o código que as lê\nregistro 13 'Os projetos pessoais entram no Dracula' && registro 13 'Uma versão por ícone' \\\n  && ok \"13: uma versão por ícone, e os projetos pessoais entram no Dracula (sim de 23/10)\" \\\n  || falha \"a decisão 13 não diz a troca de 23/10\"\nregistro 16 'sim explícito de 23/10' \\\n  && ok \"16 (3): o Citrix veste o desenho escolhido em 23/10, com o sim citado\" \\\n  || falha \"a decisão 16 (3) não diz o sim de 23/10 sobre o Citrix\"\nfor n in Ubuntu-selfservice Ubuntu-wfica Ubuntu-receiver; do\n  a=\"$(python3 \"$RAIZ/scripts/pack.py\" fonte \"$n\" dracula 2>/dev/null | cut -f2)\"\n  [ -n \"$a\" ] && [ -f \"$RAIZ/$a\" ] && cmp -s \"$RAIZ/$a\" \"$RAIZ/packs/dracula/icones/apps/Ubuntu-selfservice.svg\" \\\n    || { falha \"16 (3): $n não veste o desenho do Citrix escolhido em 23/10 ($a)\"; continue; }\ndone\nok \"16 (3): os nomes do Citrix vestem o mesmo desenho, o escolhido em 23/10\"\nfor n in com.beholder.app elden-ring-tracker protocolo-ouroboros; do\n  python3 \"$RAIZ/scripts/pack.py\" fonte \"$n\" dracula >/dev/null 2>&1 \\\n    && ok \"13: $n veste o desenho dele no Dracula\" || falha \"13: $n não veste desenho no Dracula\"\ndone\nregistro 17 'AGENTS.md' && ok \"17: o AGENTS.md é exceção do sanitizador\" || falha \"a decisão 17 saiu do registro\"\n"
},
{
"arquivo": "tests/derivados.sh",
"antes": "esperadas=\"$R/packs/dracula/icones/apps\n$R/packs/dracula/icones/sistema/pastas\n$R/packs/dracula/icones/biblioteca/feitos-a-mao\n$R/packs/catppuccin/icones/apps/autorais\n$R/packs/meowsystem/icones/apps/arcticons\n",
"depois": "# [P96, 23/10/2026: as três pastas são planas, e o Catppuccin mora no meowsystem.]\nesperadas=\"$R/packs/dracula/icones/apps\n$R/packs/dracula/icones/sistema\n$R/packs/dracula/icones/biblioteca\n$R/packs/meowsystem/icones/apps\n$R/packs/meowsystem/icones/sistema\n"
},
{
"arquivo": "tests/derivados.sh",
"antes": "\nif [ \"$falhas\" -gt 0 ]; then\n",
"depois": "\n# --- 7. o molde do tipo de arquivo: editou no pack, o tema pinta de novo — P96 ---\n#   Desde 23/10/2026 o pack guarda UM molde (`var(--vscode-ctp-<papel>)`) e a instalação o\n#   pinta com a paleta do pack no ar. Quem usa edita o molde; o vigia refaz o pintado e o tema.\nMOLDE=\"$R/packs/meowsystem/icones/sistema/json.svg\"\nNO_TEMA_MT=\"$TEMA/scalable/mimetypes/application-json.svg\"\namb bash \"$R/scripts/icones_mimetypes.sh\" --aplicar >/dev/null 2>&1\namb bash \"$R/scripts/derivados.sh\" --registrar >/dev/null 2>&1\nvermelho=\"$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))[\"flavors\"][\"dracula\"][\"red\"].lower())' \"$R/packs/dracula/paleta.json\")\"\nif [ -f \"$NO_TEMA_MT\" ] && grep -q 'vscode-ctp-yellow' \"$MOLDE\"; then\n  sed -i 's/vscode-ctp-yellow/vscode-ctp-red/g' \"$MOLDE\"\n  sleep 1.1\n  saida=\"$(amb bash \"$R/scripts/derivados.sh\" --aplicar 2>&1)\"; rc=$?\n  [ \"$rc\" = \"1\" ] && grep -qi \"$vermelho\" \"$NO_TEMA_MT\" && ! grep -q 'var(--' \"$NO_TEMA_MT\" \\\n    && ok \"o molde editado no pack chegou ao tema, pintado com a paleta do Dracula ($vermelho)\" \\\n    || falha \"o molde editado não chegou ao tema pintado (rc=$rc)\" \"$saida$(head -c 300 \"$NO_TEMA_MT\" 2>/dev/null)\"\n  antes=\"$(stat -c %Y.%N \"$NO_TEMA_MT\" \"$TABELA\" 2>/dev/null)\"\n  saida=\"$(amb bash \"$R/scripts/derivados.sh\" --aplicar 2>&1)\"; rc=$?\n  [ \"$rc\" = \"0\" ] && [ \"$antes\" = \"$(stat -c %Y.%N \"$NO_TEMA_MT\" \"$TABELA\" 2>/dev/null)\" ] \\\n    && ok \"a segunda passada depois do molde não escreve nada\" \\\n    || falha \"a segunda passada depois do molde escreveu (rc=$rc)\" \"$saida\"\nelse\n  falha \"o tipo de arquivo do JSON não ficou no tema de partida, ou o molde mudou de papel\" \"$(ls \"$TEMA/scalable/mimetypes\" 2>&1 | head -3)\"\nfi\n\nif [ \"$falhas\" -gt 0 ]; then\n"
},
{
"arquivo": "tests/estilo.sh",
"antes": "# `packs/meowsystem/icones/apps/arcticons/` foram desenhados à mão por gente, no\n",
"depois": "# `packs/meowsystem/icones/apps/` foram desenhados à mão por gente, no\n"
},
{
"arquivo": "tests/estilo.sh",
"antes": "ACERVO=\"$RAIZ/packs/meowsystem/icones/apps/arcticons\"\nMAPA=\"$RAIZ/packs/meowsystem/icones/apps-convertidos.map\"\nRETOQUES=\"$RAIZ/packs/meowsystem/icones/apps/convertidos/retoques\"\n",
"depois": "ACERVO=\"$RAIZ/packs/meowsystem/icones/arcticons.lista\"   # P96: as pastas são planas; a lista diz o que é Arcticons\nMAPA=\"$RAIZ/packs/meowsystem/icones/apps-convertidos.map\"\n"
},
{
"arquivo": "tests/estilo.sh",
"antes": "[ -d \"$ACERVO\" ] || { printf 'pulado: o acervo Arcticons não está aqui\\n'; exit 0; }\n",
"depois": "[ -f \"$ACERVO\" ] || { printf 'pulado: o acervo Arcticons não está aqui\\n'; exit 0; }\n"
},
{
"arquivo": "tests/estilo.sh",
"antes": "  [ -f \"$RETOQUES/$nome.svg\" ] && continue\n",
"depois": "  case \" $resto \" in *\" retoque \"*) continue ;; esac   # P96: o retoque é dito no mapa\n"
},
{
"arquivo": "tests/folha-dos-resgatados.sh",
"antes": "  for n in luna sigilo discord; do\n    cp \"$RAIZ/packs/dracula/icones/apps/resgatados/$n.svg\" \"$1/packs/dracula/icones/apps/resgatados/\" || exit 2\n",
"depois": "  for n in luna sigilo pdfforge; do\n    cp \"$RAIZ/packs/dracula/icones/apps/$n.svg\" \"$1/packs/dracula/icones/apps/\" || exit 2\n"
},
{
"arquivo": "tests/folha-dos-resgatados.sh",
"antes": "png luna \"#FF5555\"; png sigilo \"#50FA7B\"; png discord \"#8BE9FD\"\nR=\"$T/raiz\"; raiz \"$R\"; mapa \"$R\" luna sigilo discord\n",
"depois": "png luna \"#FF5555\"; png sigilo \"#50FA7B\"; png pdfforge \"#8BE9FD\"\nR=\"$T/raiz\"; raiz \"$R\"; mapa \"$R\" luna sigilo pdfforge\n"
},
{
"arquivo": "tests/folha-dos-resgatados.sh",
"antes": "mkdir -p \"$T/png-fora\"; mv \"$T/png/luna.png\" \"$T/png/discord.png\" \"$T/png-fora/\"\n",
"depois": "mkdir -p \"$T/png-fora\"; mv \"$T/png/luna.png\" \"$T/png/pdfforge.png\" \"$T/png-fora/\"\n"
},
{
"arquivo": "tests/folha-dos-resgatados.sh",
"antes": "cp \"$RAIZ/packs/dracula/icones/apps/resgatados/extase-em-4r73.svg\" \"$R/packs/dracula/icones/apps/resgatados/luna.svg\"\nfolha \"$R\" \"$F\"\n#   A régua: a folha que o script monta com os PNG no disco e o desenho novo.\nR2=\"$T/raiz2\"; raiz \"$R2\"; mapa \"$R2\" luna sigilo discord\ncp \"$R/packs/dracula/icones/apps/resgatados/luna.svg\" \"$R2/packs/dracula/icones/apps/resgatados/\"\ncp \"$T/png-fora/\"*.png \"$T/png/\"\nfolha \"$R2\" \"$T/regua.png\"\nmv \"$T/png/luna.png\" \"$T/png/discord.png\" \"$T/png-fora/\"\n",
"depois": "cp \"$RAIZ/packs/dracula/icones/apps/extase-em-4r73.svg\" \"$R/packs/dracula/icones/apps/luna.svg\"\nfolha \"$R\" \"$F\"\n#   A régua: a folha que o script monta com os PNG no disco e o desenho novo.\nR2=\"$T/raiz2\"; raiz \"$R2\"; mapa \"$R2\" luna sigilo pdfforge\ncp \"$R/packs/dracula/icones/apps/luna.svg\" \"$R2/packs/dracula/icones/apps/\"\ncp \"$T/png-fora/\"*.png \"$T/png/\"\nfolha \"$R2\" \"$T/regua.png\"\nmv \"$T/png/luna.png\" \"$T/png/pdfforge.png\" \"$T/png-fora/\"\n"
},
{
"arquivo": "tests/folha-dos-resgatados.sh",
"antes": "mapa \"$R\" discord sigilo luna\nfolha \"$R\" \"$F\"\n[ \"$(rc)\" = \"3\" ] && cmp -s \"$F\" \"$T/antes-da-ordem.png\" \\\n  && grep -q 'a folha fica a de antes' \"$T/tela\" && grep -q 'discord' \"$T/tela\" && grep -q 'luna' \"$T/tela\" \\\n  && ok \"com o mapa em outra ordem e PNG faltando, o script sai 3, não escreve, e diz quais pares\" \\\n  || falha \"o script refez uma folha que ele não sabia costurar (rc=$(rc))\" \"$(cat \"$T/tela\")\"\nmapa \"$R\" luna sigilo discord\n",
"depois": "mapa \"$R\" pdfforge sigilo luna\nfolha \"$R\" \"$F\"\n[ \"$(rc)\" = \"3\" ] && cmp -s \"$F\" \"$T/antes-da-ordem.png\" \\\n  && grep -q 'a folha fica a de antes' \"$T/tela\" && grep -q 'pdfforge' \"$T/tela\" && grep -q 'luna' \"$T/tela\" \\\n  && ok \"com o mapa em outra ordem e PNG faltando, o script sai 3, não escreve, e diz quais pares\" \\\n  || falha \"o script refez uma folha que ele não sabia costurar (rc=$(rc))\" \"$(cat \"$T/tela\")\"\nmapa \"$R\" luna sigilo pdfforge\n"
},
{
"arquivo": "tests/fonte-unica.sh",
"antes": "  [ \"$rc\" = \"0\" ] && [ \"$saida\" = \"$nome\tpacks/dracula/icones/apps/resgatados/$nome.svg\tresgatados\" ] \\\n",
"depois": "  [ \"$rc\" = \"0\" ] && [ \"$saida\" = \"$nome\tpacks/dracula/icones/apps/$nome.svg\tresgatados\" ] \\\n"
},
{
"arquivo": "tests/fonte-unica.sh",
"antes": "[ \"$rc\" = \"0\" ] && [ \"$saida\" = \"net.waterfox.waterfox\tpacks/dracula/icones/apps/resgatados/net.waterfox.waterfox.svg\tpack:dracula\" ] \\\n  && ok \"o Waterfox tem uma fonte só, e ela é packs/dracula/icones/apps/resgatados/net.waterfox.waterfox.svg\" \\\n",
"depois": "# [P96, 23/10/2026: quem usa escolheu o lobo e a lua do manuais-final, corrigido (viewBox e traço).]\n[ \"$rc\" = \"0\" ] && [ \"$saida\" = \"net.waterfox.waterfox\tpacks/dracula/icones/apps/firefox.svg\tpack:dracula\" ] \\\n  && ok \"o Waterfox tem uma fonte só, e ela é packs/dracula/icones/apps/firefox.svg\" \\\n"
},
{
"arquivo": "tests/fonte-unica.sh",
"antes": "grep -q '^| `icones/apps/net.waterfox.waterfox.svg` |' \"$RAIZ/packs/dracula/PROCEDENCIA.md\" \\\n",
"depois": "grep -q '^| `icones/apps/firefox.svg` |' \"$RAIZ/packs/dracula/PROCEDENCIA.md\" \\\n"
},
{
"arquivo": "tests/fonte-unica.sh",
"antes": "        [ -f \"$RAIZ/packs/dracula/icones/apps/resgatados/$nome.svg\" ] || fora=\"$fora${mapa#\"$RAIZ\"/}: $linha\n",
"depois": "        [ -f \"$RAIZ/packs/dracula/icones/apps/$nome.svg\" ] || fora=\"$fora${mapa#\"$RAIZ\"/}: $linha\n"
},
{
"arquivo": "tests/fonte-unica.sh",
"antes": "cp \"$RAIZ/packs/dracula/icones/apps/resgatados/luna.svg\" \"$d/icones/apps/luna.svg\"\nprintf 'luna : apps/luna.svg\\n' > \"$d/icones/apps.map\"\nsaida=\"$(ICONES_DRACULA=sim pack_py fonte luna herdeira 2>\"$T/erro\")\"; rc=$?\n[ \"$rc\" = \"0\" ] && [ \"$saida\" = \"luna\t$d/icones/apps/luna.svg\tpack:herdeira\" ] \\\n  && grep -q 'packs/dracula/icones/apps/resgatados/luna.svg (resgatados) fica atrás' \"$T/erro\" \\\n",
"depois": "cp \"$RAIZ/packs/dracula/icones/apps/luna.svg\" \"$d/icones/apps/luna.svg\"\nprintf 'luna : apps/luna.svg\\n' > \"$d/icones/apps.map\"\nsaida=\"$(ICONES_DRACULA=sim pack_py fonte luna herdeira 2>\"$T/erro\")\"; rc=$?\n[ \"$rc\" = \"0\" ] && [ \"$saida\" = \"luna\t$d/icones/apps/luna.svg\tpack:herdeira\" ] \\\n  && grep -q 'packs/dracula/icones/apps/luna.svg (resgatados) fica atrás' \"$T/erro\" \\\n"
},
{
"arquivo": "tests/fonte-unica.sh",
"antes": "  meow_icones_derivados \"$1\" net.waterfox.waterfox \"$2\"' _ \"$RAIZ/packs/dracula/icones/apps/net.waterfox.waterfox.svg\" \"$tema\")\"\n",
"depois": "  meow_icones_derivados \"$1\" net.waterfox.waterfox \"$2\"' _ \"$RAIZ/packs/dracula/icones/apps/firefox.svg\" \"$tema\")\"\n"
},
{
"arquivo": "tests/fonte-unica.sh",
"antes": "  meow_icones_derivar \"$1\" net.waterfox.waterfox \"$2\"; printf %s $?' _ \"$RAIZ/packs/dracula/icones/apps/net.waterfox.waterfox.svg\" \"$tema\" 2>/dev/null | tail -c1)\"\nr2=\"$(amb bash -c '. \"$MEOW_RAIZ/lib/comum.sh\"; . \"$MEOW_RAIZ/lib/icones.sh\"\n  meow_icones_derivar \"$1\" net.waterfox.waterfox \"$2\"; printf %s $?' _ \"$RAIZ/packs/dracula/icones/apps/net.waterfox.waterfox.svg\" \"$tema\" 2>/dev/null | tail -c1)\"\n",
"depois": "  meow_icones_derivar \"$1\" net.waterfox.waterfox \"$2\"; printf %s $?' _ \"$RAIZ/packs/dracula/icones/apps/firefox.svg\" \"$tema\" 2>/dev/null | tail -c1)\"\nr2=\"$(amb bash -c '. \"$MEOW_RAIZ/lib/comum.sh\"; . \"$MEOW_RAIZ/lib/icones.sh\"\n  meow_icones_derivar \"$1\" net.waterfox.waterfox \"$2\"; printf %s $?' _ \"$RAIZ/packs/dracula/icones/apps/firefox.svg\" \"$tema\" 2>/dev/null | tail -c1)\"\n"
},
{
"arquivo": "tests/fonte-unica.sh",
"antes": "  && [ \"$(printf '%s\\n' \"$saida\" | sed -n 1p)\" = \"fonte: packs/dracula/icones/apps/resgatados/net.waterfox.waterfox.svg\" ] \\\n",
"depois": "  && [ \"$(printf '%s\\n' \"$saida\" | sed -n 1p)\" = \"fonte: packs/dracula/icones/apps/firefox.svg\" ] \\\n"
},
{
"arquivo": "tests/fonte-unica.sh",
"antes": "CATPPUCCIN=(PACK=catppuccin FLAVOR=mocha ICONES_DRACULA=sim)\nDESLIGADO=(PACK=dracula FLAVOR=dracula ICONES_DRACULA=nao)\nDO_PACK_G=\"packs/dracula/icones/apps/guvcview-lente.svg\"\nDO_PACK_M=\"packs/dracula/icones/biblioteca/tarot.svg\"\nRESG_G=\"packs/dracula/icones/apps/resgatados/guvcview.svg\"\nRESG_M=\"packs/dracula/icones/apps/resgatados/setup-mozc.svg\"\n",
"depois": "CATPPUCCIN=(PACK=meowsystem FLAVOR=mocha ICONES_DRACULA=sim)\nDESLIGADO=(PACK=dracula FLAVOR=dracula ICONES_DRACULA=nao)\n# [P96, 23/10/2026: uma versão por ícone. O mapa do pack e o resgate apontam o MESMO desenho, o\n#  que quem usa escolheu — o pote com olho no guvcview e o tarô no setup-mozc —, e a precedência\n#  continua provada: nenhum instalador troca o do outro, em ordem nenhuma.]\nDO_PACK_G=\"packs/dracula/icones/apps/guvcview.svg\"\nDO_PACK_M=\"packs/dracula/icones/apps/setup-mozc.svg\"\nRESG_G=\"packs/dracula/icones/apps/guvcview.svg\"\nRESG_M=\"packs/dracula/icones/apps/setup-mozc.svg\"\n"
},
{
"arquivo": "tests/fonte-unica.sh",
"antes": "veste \"$casa_c\" uad-ng \"packs/dracula/icones/apps/resgatados/uad-ng.svg\" \\\n",
"depois": "veste \"$casa_c\" uad-ng \"packs/dracula/icones/apps/uad-ng.svg\" \\\n"
},
{
"arquivo": "tests/frases-velhas.sh",
"antes": "            svg = \"packs/dracula/icones/apps/resgatados/%s.svg\" % nome\n",
"depois": "            svg = \"packs/dracula/icones/apps/%s.svg\" % nome\n"
},
{
"arquivo": "tests/fzf-da-paleta.sh",
"antes": "for par in \"dracula:$RAIZ/packs/dracula/paleta.json\" \"mocha:$RAIZ/packs/catppuccin/paleta.json\"; do\n",
"depois": "for par in \"dracula:$RAIZ/packs/dracula/paleta.json\" \"mocha:$RAIZ/packs/meowsystem/paleta.json\"; do\n"
},
{
"arquivo": "tests/git-limpo.sh",
"antes": "              {\"app\": \"um-chat\", \"arquivo\": \"packs/dracula/icones/apps/resgatados/discord.svg\"},\n              {\"app\": \"um-editor\", \"arquivo\": \"packs/meowsystem/icones/apps/arcticons/firefox.svg\",\n",
"depois": "              {\"app\": \"um-chat\", \"arquivo\": \"packs/dracula/icones/apps/steam.svg\"},\n              {\"app\": \"um-editor\", \"arquivo\": \"packs/meowsystem/icones/apps/firefox.svg\",\n"
},
{
"arquivo": "tests/git-limpo.sh",
"antes": "rm -f \"$RAIZ/packs/meowsystem/icones/apps/convertidos/um-desenho.svg\" \"$RAIZ/packs/meowsystem/icones/apps/convertidos/retoques/um-desenho.svg\"\n",
"depois": "rm -f \"$RAIZ/packs/meowsystem/icones/apps/um-desenho.svg\" \"$RAIZ/packs/meowsystem/icones/apps/um-desenho.svg\"\n"
},
{
"arquivo": "tests/notas-de-funcao.sh",
"antes": "cp -a \"$RAIZ/packs/dracula\" \"$RAIZ/packs/catppuccin\" \"$PACKS/\" || exit 2\n",
"depois": "cp -a \"$RAIZ/packs/dracula\" \"$RAIZ/packs/meowsystem\" \"$PACKS/\" || exit 2\n"
},
{
"arquivo": "tests/notas-de-funcao.sh",
"antes": "CAT=\"$PACKS/catppuccin/temas/capturados\"\n",
"depois": "CAT=\"$PACKS/meowsystem/temas/capturados\"\n"
},
{
"arquivo": "tests/notas-de-funcao.sh",
"antes": "azul=\"$(cor catppuccin mocha blue)\"; verde=\"$(cor catppuccin latte green)\"\nconf latte blue catppuccin escuro\n",
"depois": "azul=\"$(cor meowsystem mocha blue)\"; verde=\"$(cor meowsystem latte green)\"\nconf latte blue meowsystem escuro\n"
},
{
"arquivo": "tests/notas-de-funcao.sh",
"antes": "conf mocha green catppuccin claro\n",
"depois": "conf mocha green meowsystem claro\n"
},
{
"arquivo": "tests/notas-de-funcao.sh",
"antes": "rosa=\"$(cor catppuccin latte pink)\"\nconf mocha pink catppuccin claro\n",
"depois": "rosa=\"$(cor meowsystem latte pink)\"\nconf mocha pink meowsystem claro\n"
},
{
"arquivo": "tests/notas-de-funcao.sh",
"antes": "for pack_id in (\"dracula\", \"catppuccin\"):\n",
"depois": "for pack_id in (\"dracula\", \"meowsystem\"):\n"
},
{
"arquivo": "tests/notas-de-funcao.sh",
"antes": "P1=\"$T/packs1\"; mkdir -p \"$P1\"; cp -a \"$RAIZ/packs/catppuccin\" \"$P1/\" || exit 2\nfor cap in \"$P1\"/*/temas/capturados/*/; do\n  grep -qs '^origem: derivada de ' \"$cap/captura.txt\" && rm -rf \"$cap\"\ndone\nROSA=\"$P1/catppuccin/temas/capturados/mocha-pink\"\nsed -i 's/hover: \"#CE72B9FF\"/hover: \"#CE72B8FF\"/' \"$ROSA/com.system76.CosmicTheme.Light/v2/accent\"\ngrep -q 'hover: \"#CE72B8FF\"' \"$ROSA/com.system76.CosmicTheme.Light/v2/accent\" \\\n  || { printf 'erro: não consegui mexer na Light da mocha-pink de brinquedo\\n' >&2; exit 2; }\nsaida=\"$(amb env MEOW_PACK_DIR=\"$P1/catppuccin\" MEOW_PALETA=\"$P1/catppuccin/paleta.json\" \\\n",
"depois": "P1=\"$T/packs1\"; mkdir -p \"$P1\"; cp -a \"$RAIZ/packs/meowsystem\" \"$P1/\" || exit 2\nfor cap in \"$P1\"/*/temas/capturados/*/; do\n  grep -qs '^origem: derivada de ' \"$cap/captura.txt\" && rm -rf \"$cap\"\ndone\nROSA=\"$P1/meowsystem/temas/capturados/mocha-pink\"\nsed -i 's/hover: \"#CE72B9FF\"/hover: \"#CE72B8FF\"/' \"$ROSA/com.system76.CosmicTheme.Light/v2/accent\"\ngrep -q 'hover: \"#CE72B8FF\"' \"$ROSA/com.system76.CosmicTheme.Light/v2/accent\" \\\n  || { printf 'erro: não consegui mexer na Light da mocha-pink de brinquedo\\n' >&2; exit 2; }\nsaida=\"$(amb env MEOW_PACK_DIR=\"$P1/meowsystem\" MEOW_PALETA=\"$P1/meowsystem/paleta.json\" \\\n"
},
{
"arquivo": "tests/notas-de-funcao.sh",
"antes": "painel=\"$P2/dracula/icones/apps/autorais/meowsystem-painel-dracula.svg\"\n",
"depois": "painel=\"$P2/dracula/icones/apps/meowsystem-painel-dracula.svg\"\n"
},
{
"arquivo": "tests/notas-de-funcao.sh",
"antes": "cp \"$RAIZ/packs/dracula/icones/sistema/pastas/folder-documents.svg\" \"$LUGARES/\"\n",
"depois": "cp \"$RAIZ/packs/dracula/icones/sistema/folder-documents.svg\" \"$LUGARES/\"\n"
},
{
"arquivo": "tests/notas-de-funcao.sh",
"antes": "cp -a \"$RAIZ/packs/catppuccin\" \"$P6/\"\n",
"depois": "cp -a \"$RAIZ/packs/meowsystem\" \"$P6/\"\n"
},
{
"arquivo": "tests/notas-de-funcao.sh",
"antes": "printf 'uma ficha que não é do COSMIC\\n' > \"$P6/catppuccin/temas/capturados/latte-mauve/LEIA-ME.md\"\nsaida=\"$(env -i PATH=\"$CAMINHO\" HOME=\"$CASA\" MEOW_RAIZ=\"$R6\" MEOW_ESTADO=\"$E6\" MEOW_COSMIC_DIR=\"$C6\" \\\n           MEOW_PACK_DIR=\"$P6/catppuccin\" MEOW_PACKS=\"$P6\" TMPDIR=\"$T/tmp6\" LANG=C.UTF-8 NO_COLOR=1 \\\n",
"depois": "printf 'uma ficha que não é do COSMIC\\n' > \"$P6/meowsystem/temas/capturados/latte-mauve/LEIA-ME.md\"\nsaida=\"$(env -i PATH=\"$CAMINHO\" HOME=\"$CASA\" MEOW_RAIZ=\"$R6\" MEOW_ESTADO=\"$E6\" MEOW_COSMIC_DIR=\"$C6\" \\\n           MEOW_PACK_DIR=\"$P6/meowsystem\" MEOW_PACKS=\"$P6\" TMPDIR=\"$T/tmp6\" LANG=C.UTF-8 NO_COLOR=1 \\\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "nomes=\"$(for par in \"dracula\" \"dracula alucard\" \"catppuccin mocha\"; do\n  # shellcheck disable=SC2086\n  amb python3 \"$RAIZ/scripts/pack.py\" tema-icones $par 2>&1 | sed -n 's/^nome=//p'\ndone | paste -sd' ')\"\n[ \"$nomes\" = \"MeowSystem-Dracula-Icons MeowSystem-Dracula-Alucard-Icons MeowSystem-Catppuccin-Mocha-Icons\" ] \\\n",
"depois": "nomes=\"$(for par in \"dracula\" \"dracula alucard\" \"meowsystem mocha\"; do\n  # shellcheck disable=SC2086\n  amb python3 \"$RAIZ/scripts/pack.py\" tema-icones $par 2>&1 | sed -n 's/^nome=//p'\ndone | paste -sd' ')\"\n[ \"$nomes\" = \"MeowSystem-Dracula-Icons MeowSystem-Dracula-Alucard-Icons MeowSystem-Mocha-Icons\" ] \\\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "linha=\"$(amb python3 \"$RAIZ/scripts/pack.py\" info dracula 2>&1 | grep -E '^  icones\\.mimetypes ')\"\n[[ \"$linha\" == *\"PRÓPRIO\"*\"1.312 desenho(s)\"* ]] \\\n  && ok \"icones.mimetypes do Dracula é PRÓPRIO: 656 por flavor, nos dois flavors\" \\\n  || falha \"o info não diz os ícones de arquivo do Dracula como próprios\" \"$linha\"\nmacc=\"$(python3 -c 'import json,sys;print(\"|\".join(v.lower() for v in json.load(open(sys.argv[1]))[\"flavors\"][\"macchiato\"].values()))' \"$RAIZ/packs/catppuccin/paleta.json\")\"\ncom_macc=\"$(grep -liE \"$macc\" \"$RAIZ\"/packs/dracula/icones/sistema/mimetypes/*/*.svg | wc -l)\"\ntotal=\"$(find \"$RAIZ/packs/dracula/icones/sistema/mimetypes\" -name '*.svg' | wc -l)\"\n[ \"$total\" = 1312 ] && [ \"$com_macc\" = 0 ] \\\n  && ok \"nenhum dos $total ícones de arquivo do Dracula tem cor do macchiato\" \\\n  || falha \"ícones de arquivo do Dracula com cor do Catppuccin, ou contagem errada\" \"total=$total com_macchiato=$com_macc\"\nseco=\"$(amb python3 \"$RAIZ/scripts/pack.py\" construir dracula --seco 2>&1 | grep 'ícones de arquivo')\"\n[[ \"$seco\" == *\"escreveria 0, tirou 0\"* ]] \\\n  && ok \"o construir não tem ícone de arquivo a escrever: o versionado é o que a paleta dá\" \\\n  || falha \"os ícones de arquivo versionados não são os que a paleta do Dracula dá\" \"$seco\"\n",
"depois": "# [P96, 23/10/2026: o pack guarda UM molde (no meowsystem), e a instalação o pinta com a paleta\n#  do pack no ar — o Dracula herda o molde e não guarda pintado nenhum.]\nlinha=\"$(amb python3 \"$RAIZ/scripts/pack.py\" info dracula 2>&1 | grep -E '^  icones\\.mimetypes ')\"\n[[ \"$linha\" == *\"HERDADO de meowsystem\"*\"656 desenho(s)\"* ]] \\\n  && ok \"icones.mimetypes do Dracula vem do molde do meowsystem: 656 desenhos\" \\\n  || falha \"o info não diz os ícones de arquivo do Dracula como o molde herdado\" \"$linha\"\nmacc=\"$(python3 -c 'import json,sys;print(\"|\".join(v.lower() for v in json.load(open(sys.argv[1]))[\"flavors\"][\"macchiato\"].values()))' \"$RAIZ/packs/meowsystem/paleta.json\")\"\ntotal=0; com_macc=0\nfor fl in dracula alucard; do\n  pint=\"$(amb python3 \"$RAIZ/scripts/pack.py\" pintados dracula \"$fl\" --temporario 2>/dev/null)\"\n  [ -d \"$pint\" ] || continue\n  total=$((total + $(find \"$pint\" -name '*.svg' | wc -l)))\n  com_macc=$((com_macc + $(grep -liE \"$macc\" \"$pint\"/*.svg | wc -l)))\n  rm -rf \"$pint\"\ndone\n[ \"$total\" = 1312 ] && [ \"$com_macc\" = 0 ] \\\n  && ok \"o molde pintado com a paleta do Dracula dá $total ícones de arquivo, nenhum com cor do macchiato\" \\\n  || falha \"ícones de arquivo do Dracula com cor do Catppuccin, ou contagem errada\" \"total=$total com_macchiato=$com_macc\"\n[ ! -e \"$RAIZ/packs/dracula/icones/sistema/mimetypes\" ] && ! grep -rlq 'vscode-ctp' \"$RAIZ/packs/dracula/icones\" \\\n  && ok \"o pack Dracula não guarda tipo de arquivo pintado nem cópia do molde\" \\\n  || falha \"o pack Dracula guarda tipo de arquivo que a instalação devia pintar\"\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "  [ -f \"$RAIZ/packs/dracula/icones/sistema/pastas/$g.svg\" ] || faltam=\"$faltam $g\"\n",
"depois": "  [ -f \"$RAIZ/packs/dracula/icones/sistema/$g.svg\" ] || faltam=\"$faltam $g\"\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "prompt catppuccin mocha \"$T/st-mocha.toml\"\n",
"depois": "prompt meowsystem mocha \"$T/st-mocha.toml\"\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "som catppuccin mocha aplicar; r4=$?\n",
"depois": "som meowsystem mocha aplicar; r4=$?\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "cp -r \"$RAIZ/packs/dracula\" \"$PM\"; cp -r \"$RAIZ/packs/catppuccin\" \"$TM/packs/malsrc\"\n",
"depois": "cp -r \"$RAIZ/packs/dracula\" \"$PM\"; cp -r \"$RAIZ/packs/meowsystem\" \"$TM/packs/malsrc\"\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "G=\"$(grep -v '^#' \"$RAIZ/packs/catppuccin/icones/mimetypes.map\" | grep -v '^$' | head -1 | cut -d: -f2)\"\n",
"depois": "G=\"$(grep -v '^#' \"$RAIZ/packs/meowsystem/icones/mimetypes.map\" | grep -v '^$' | head -1 | cut -d: -f2)\"\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "p[\"icones\"][\"mimetypes\"][\"mapa\"] = \"icones/mimetypes.map\"\np[\"icones\"][\"mimetypes\"][\"derivar\"][\"de\"] = \"malsrc\"\n",
"depois": "# [P96: o mal traz o molde dele (com um link para fora no meio) em vez de derivar de outro pack.]\np[\"icones\"][\"mimetypes\"] = {\"desenhos\": \"icones/sistema/\", \"mapa\": \"icones/mimetypes.map\"}\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "cp \"$RAIZ/packs/catppuccin/icones/mimetypes.map\" \"$PM/icones/mimetypes.map\"\nprintf '../../../../../../escapou2:%s\\n' \"$G\" >> \"$PM/icones/mimetypes.map\"\nln -s \"$TM/segredo.oga\" \"$PM/sons/stereo/notification/vazou.oga\"\nln -s \"$TM/segredo.svg\" \"$PM/wallpapers/catedral/vazou.svg\"\nrm -f \"$PM/icones/sistema/mimetypes/dracula/$G.svg\"; ln -s \"$TM/segredo.svg\" \"$PM/icones/sistema/mimetypes/dracula/$G.svg\"\nln -s \"$TM/segredo.svg\" \"$TM/packs/malsrc/icones/sistema/mimetypes/css-variables/zz_vazou.svg\"\n",
"depois": "cp \"$RAIZ/packs/meowsystem/icones/mimetypes.map\" \"$PM/icones/mimetypes.map\"\nprintf '../../../../../../escapou2:%s\\n' \"$G\" >> \"$PM/icones/mimetypes.map\"\nln -s \"$TM/segredo.oga\" \"$PM/sons/stereo/notification/vazou.oga\"\nln -s \"$TM/segredo.svg\" \"$PM/wallpapers/catedral/vazou.svg\"\ncp \"$RAIZ/packs/meowsystem/icones/sistema/\"*.svg \"$PM/icones/sistema/\" 2>/dev/null\nrm -f \"$PM/icones/sistema/$G.svg\"; ln -s \"$TM/segredo.svg\" \"$PM/icones/sistema/$G.svg\"\nln -s \"$TM/segredo.svg\" \"$PM/icones/sistema/zz_vazou.svg\"\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "  vazou=\"$(grep -rlF 'SEGREDO' \"$HM\" \"$PM/icones/sistema/mimetypes\" 2>/dev/null | wc -l)\"\n",
"depois": "  vazou=\"$(grep -rlF 'SEGREDO' \"$HM\" 2>/dev/null | wc -l)\"\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "     && [ ! -L \"$PM/icones/sistema/mimetypes/dracula/$G.svg\" ] \\\n",
"depois": "     && [ -L \"$PM/icones/sistema/$G.svg\" ] \\\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "grep -qE '^dev\\.vencord\\.Vesktop[[:space:]]*:[[:space:]]*apps/com\\.discordapp\\.Discord\\.svg' \"$RAIZ/packs/dracula/icones/apps.map\" \\\n",
"depois": "# [P96: o desenho do Discord é o que quem usa escolheu em 23/10; o Vesktop veste o MESMO arquivo.]\nalvo_discord=\"$(sed -n 's/^com\\.discordapp\\.Discord[[:space:]]*:[[:space:]]*\\([^[:space:]#]*\\).*/\\1/p' \"$RAIZ/packs/dracula/icones/apps.map\" | head -1)\"\n[ -n \"$alvo_discord\" ] && grep -qE \"^dev\\.vencord\\.Vesktop[[:space:]]*:[[:space:]]*${alvo_discord//./\\\\.}([[:space:]]|$)\" \"$RAIZ/packs/dracula/icones/apps.map\" \\\n"
},
{
"arquivo": "tests/pack-dracula-completo.sh",
"antes": "ocultar catppuccin mocha > /dev/null; com_catppuccin=\"$(marcados)\"\nantes=\"$(cat \"$APPS\"/*.desktop | sha256sum)\"\nsaida=\"$(ocultar catppuccin mocha)\"; rc=$?\n",
"depois": "ocultar meowsystem mocha > /dev/null; com_catppuccin=\"$(marcados)\"\nantes=\"$(cat \"$APPS\"/*.desktop | sha256sum)\"\nsaida=\"$(ocultar meowsystem mocha)\"; rc=$?\n"
},
{
"arquivo": "tests/pack-malicioso.sh",
"antes": "  if printf '%s' \"$glifos\" | grep -q \"biblioteca/folder.svg\\|feitos-a-mao/folder.svg\\|$FORA\"; then\n",
"depois": "  # [P96: o pack-base também tem um `biblioteca/folder.svg` (o glifo do Arcticons); a busca é do pack `mal`.]\n  if printf '%s' \"$glifos\" | grep -q \"mal/icones/biblioteca/folder.svg\\|mal/icones/feitos-a-mao/folder.svg\\|$FORA\"; then\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "  PACK=catppuccin FLAVOR=mocha meow_ponte_python >/dev/null 2>&1 || exit 9\n",
"depois": "  PACK=meowsystem FLAVOR=mocha meow_ponte_python >/dev/null 2>&1 || exit 9\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "embutida=\"$(amb bash -c '. \"$MEOW_RAIZ/lib/comum.sh\"; PACK=catppuccin meow_paleta')\"\n",
"depois": "embutida=\"$(amb bash -c '. \"$MEOW_RAIZ/lib/comum.sh\"; PACK=meowsystem meow_paleta')\"\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "# `packs/catppuccin/`, e `pack.py validar catppuccin` estourava um\n",
"depois": "# `packs/catppuccin/`, e `pack.py validar meowsystem` estourava um\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "$RAIZ/packs/meowsystem/icones/sistema/arcticons/y.svg\n$RAIZ/packs/meowsystem/icones/apps/arcticons/z.svg\"\n",
"depois": "$RAIZ/packs/meowsystem/icones/sistema/y.svg\n$RAIZ/packs/meowsystem/icones/apps/z.svg\"\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "esperado_p=\"um.motor\t$RAIZ/packs/meowsystem/icones/sistema/arcticons/telegram.svg\n",
"depois": "esperado_p=\"um.motor\t$RAIZ/packs/meowsystem/icones/biblioteca/telegram.svg\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "saida=\"$(usar_amb \"$RAIZ/bin/meow\" pack usar catppuccin --sem-aplicar 2>&1)\"; rc=$?\nvolta=\"$(tema_do_conf)\"\nif [ \"$rc\" = \"0\" ] && grep -qx 'PACK=\"catppuccin\"' \"$T/usar.conf\" \\\n   && [ \"$volta\" = \"catppuccin mocha-mauve 0\" ]; then\n",
"depois": "saida=\"$(usar_amb \"$RAIZ/bin/meow\" pack usar meowsystem --sem-aplicar 2>&1)\"; rc=$?\nvolta=\"$(tema_do_conf)\"\nif [ \"$rc\" = \"0\" ] && grep -qx 'PACK=\"meowsystem\"' \"$T/usar.conf\" \\\n   && [ \"$volta\" = \"meowsystem mocha-mauve 0\" ]; then\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "  dracula \"\" 's/^PACK=.*/PACK=\"catppuccin\"/'\n",
"depois": "  dracula \"\" 's/^PACK=.*/PACK=\"meowsystem\"/'\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "#   Achado 12 da validação no painel de verdade: `meow pack usar catppuccin`\n",
"depois": "#   Achado 12 da validação no painel de verdade: `meow pack usar meowsystem`\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "  for alvo in dracula catppuccin \"$ID\"; do\n",
"depois": "  for alvo in dracula meowsystem \"$ID\"; do\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "  n_autorais=\"$(find \"$DA_PESSOA/minha-tinta/icones/apps/autorais\" -name '*.svg' | wc -l)\"\n",
"depois": "  n_autorais=\"$(find \"$DA_PESSOA/minha-tinta/icones/apps\" -name '*.svg' | wc -l)\"\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "for p in catppuccin dracula; do\n",
"depois": "for p in meowsystem dracula; do\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "    elif [ \"$script\" = \"icones_pastas\" ] && [ -d \"$RAIZ/packs/$2/icones/sistema/pastas\" ]; then\n",
"depois": "    elif [ \"$script\" = \"icones_pastas\" ] && [ -f \"$RAIZ/packs/$2/icones/sistema/folder-documents.svg\" ]; then\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "  catppuccin latte \"\" latte\np31_caso \"Dracula no ar, ICONES_FLAVOR=\\\"latte\\\" escrito à mão: o conf vence\" \\\n  dracula dracula 'ICONES_FLAVOR=\"latte\"' latte\np31_caso \"Catppuccin no Latte, ICONES_FLAVOR vazio: vazio acompanha o tema\" \\\n  catppuccin latte 'ICONES_FLAVOR=\"\"' latte\n",
"depois": "  meowsystem latte \"\" latte\np31_caso \"Dracula no ar, ICONES_FLAVOR=\\\"latte\\\" escrito à mão: o conf vence\" \\\n  dracula dracula 'ICONES_FLAVOR=\"latte\"' latte\np31_caso \"Catppuccin no Latte, ICONES_FLAVOR vazio: vazio acompanha o tema\" \\\n  meowsystem latte 'ICONES_FLAVOR=\"\"' latte\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "  python3 \"$RAIZ/scripts/pack.py\" flavor-icones catppuccin >/dev/null 2>&1; rc_vazio=$?\n",
"depois": "  python3 \"$RAIZ/scripts/pack.py\" flavor-icones meowsystem >/dev/null 2>&1; rc_vazio=$?\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "origem, pack = shas(sys.argv[1]), shas(sys.argv[2])\nfaltam = sorted(a for s, a in origem.items() if s not in pack)\n",
"depois": "origem = shas(sys.argv[1])\n# P96 (23/10/2026): o desenho ligado a um app mora em apps/, e quem usa escolheu uma versão por\n# ícone — o que saiu por escolha dela está na tabela de antes, com o destino vazio.\npack = {**shas(sys.argv[2]), **shas(os.path.join(os.path.dirname(sys.argv[2]), \"apps\"))}\ntabela = os.path.join(os.path.dirname(sys.argv[2]), \"..\", \"..\", \"CAMINHOS-DE-ANTES.tsv\")\nsaiu = set()\nif os.path.exists(tabela):\n    for l in open(tabela, encoding=\"utf-8\"):\n        if \"\\t\" in l and not l.startswith(\"#\"):\n            k, v = l.rstrip(\"\\n\").split(\"\\t\", 1)\n            if not v and k.startswith(\"packs/dracula/icones/biblioteca/\") and k.count(\"/\") == 4:\n                saiu.add(os.path.basename(k))\nfaltam = sorted(a for s, a in origem.items() if s not in pack and a not in saiu)\norigem = {s: a for s, a in origem.items() if a not in saiu}\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "    && ok \"por sha256, a biblioteca do Dracula_OS-Theme está no pack: ${achados% *} de ${achados#* }\" \\\n",
"depois": "    && ok \"por sha256, a biblioteca do Dracula_OS-Theme está no pack (apps/ e biblioteca/, menos o que quem usa tirou): ${achados% *} de ${achados#* }\" \\\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "  if [ \"$rc\" = 0 ] && printf '%s\\n' \"$saida\" | grep -qx 'pack=dracula' \\\n     && [ -f \"$valor\" ] && [ \"${valor#\"$RAIZ/packs/dracula/apps/\"}\" != \"$valor\" ]; then\n    ok \"o Dracula declara o tema do $app, e ele mora no pack ($(basename \"$valor\"))\"\n  else\n    falha \"apps.$app.arquivo do Dracula não resolveu para um arquivo do pack (rc=$rc)\" \"$saida\"\n  fi\n  grep -qF \"| \\`apps/$(basename \"$valor\")\\` |\" \"$RAIZ/packs/dracula/PROCEDENCIA.md\" \\\n    && ok \"o modelo do $app tem a linha dele no PROCEDENCIA.md\" \\\n    || falha \"o modelo do $app está no pack sem procedência escrita\"\n",
"depois": "  # P96 (23/10/2026): o modelo é preenchido inteiro pela paleta, e mora no motor\n  # (`scripts/temas-de-apps/<app>/`); o pack declara o aplicativo, e a resposta é do pack.\n  if [ \"$rc\" = 0 ] && printf '%s\\n' \"$saida\" | grep -qx 'pack=dracula' \\\n     && [ -f \"$valor\" ] && [ \"${valor#\"$RAIZ/scripts/temas-de-apps/$app/\"}\" != \"$valor\" ]; then\n    ok \"o Dracula declara o tema do $app, e o modelo mora no motor ($(basename \"$valor\"))\"\n  else\n    falha \"apps.$app.arquivo do Dracula não resolveu para o modelo do motor (rc=$rc)\" \"$saida\"\n  fi\n  [ ! -e \"$RAIZ/packs/dracula/apps\" ] && [ ! -e \"$RAIZ/packs/dracula/temas-de-apps/$app\" ] \\\n    && ok \"o modelo do $app não tem cópia dentro do pack\" \\\n    || falha \"o modelo do $app tem cópia dentro do pack\"\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "if amb python3 \"$RAIZ/scripts/pack.py\" app catppuccin apps.kitty.arquivo >/dev/null 2>&1; then\n",
"depois": "if amb python3 \"$RAIZ/scripts/pack.py\" app meowsystem apps.kitty.arquivo >/dev/null 2>&1; then\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "for par in \"catppuccin obsidian.esquema Catppuccin\" \"catppuccin vscode.esquema Catppuccin Mocha\" \\\n           \"catppuccin vscode.origem.extensao Catppuccin.catppuccin-vsc\" \\\n           \"catppuccin vscode-icones.esquema catppuccin-mocha\" \\\n",
"depois": "for par in \"meowsystem obsidian.esquema Catppuccin\" \"meowsystem vscode.esquema Catppuccin Mocha\" \\\n           \"meowsystem vscode.origem.extensao Catppuccin.catppuccin-vsc\" \\\n           \"meowsystem vscode-icones.esquema catppuccin-mocha\" \\\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "[ \"$(so_repo env FLAVOR=latte python3 \"$RAIZ/scripts/pack.py\" app catppuccin apps.heroic.esquema | sed -n 's/^valor=//p')\" \\\n",
"depois": "[ \"$(so_repo env FLAVOR=latte python3 \"$RAIZ/scripts/pack.py\" app meowsystem apps.heroic.esquema | sed -n 's/^valor=//p')\" \\\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "printf '%s\\n' \"$saida\" | grep -qx 'pack=catppuccin' \\\n  && ok \"os ícones de VS Code do Dracula sobem ao Catppuccin pela herança — e o módulo os recusa (temas-de-apps.sh)\" \\\n  || falha \"apps.vscode-icones do Dracula não subiu ao Catppuccin, e o teste do módulo deixou de provar a recusa\" \"$saida\"\nmortos=\"$(so_repo python3 \"$RAIZ/scripts/pack.py\" validar dracula 2>&1; so_repo python3 \"$RAIZ/scripts/pack.py\" validar catppuccin 2>&1)\"\n",
"depois": "printf '%s\\n' \"$saida\" | grep -qx 'pack=meowsystem' \\\n  && ok \"os ícones de VS Code do Dracula sobem ao Catppuccin pela herança — e o módulo os recusa (temas-de-apps.sh)\" \\\n  || falha \"apps.vscode-icones do Dracula não subiu ao Catppuccin, e o teste do módulo deixou de provar a recusa\" \"$saida\"\nmortos=\"$(so_repo python3 \"$RAIZ/scripts/pack.py\" validar dracula 2>&1; so_repo python3 \"$RAIZ/scripts/pack.py\" validar meowsystem 2>&1)\"\n"
},
{
"arquivo": "tests/pack.sh",
"antes": "for pack, flavor in ((\"dracula\", \"dracula\"), (\"dracula\", \"alucard\"), (\"catppuccin\", \"latte\")):\n",
"depois": "for pack, flavor in ((\"dracula\", \"dracula\"), (\"dracula\", \"alucard\"), (\"meowsystem\", \"latte\")):\n"
},
{
"arquivo": "tests/pastas-do-pack.sh",
"antes": "achado=\"$(python3 - \"$RAIZ/packs/dracula\" \"$RAIZ/packs/dracula/icones/apps/resgatados/org.gnome.Nautilus.svg\" <<'PY'\n",
"depois": "achado=\"$(python3 - \"$RAIZ/packs/dracula\" \"$RAIZ/packs/dracula/icones/apps/org.gnome.Nautilus.svg\" <<'PY'\n"
},
{
"arquivo": "tests/pastas-do-pack.sh",
"antes": "for svg in sorted(glob.glob(os.path.join(pack, \"icones\", \"sistema\", \"pastas\", \"*.svg\"))) + [resgate]:\n    vistos += 1\n    nome = os.path.basename(svg)\n",
"depois": "# [P96, 23/10/2026: o `folder.svg` e o Nautilus são a arte do manuais-final, que quem usa mandou\n#  vestir como veio («eles corrigem tudo»): o corpo deles é o que ela desenhou, e a régua da paleta\n#  vale para as outras oito.]\nDO_MANUAIS = {\"folder.svg\", \"org.gnome.Nautilus.svg\"}\nfor svg in sorted(glob.glob(os.path.join(pack, \"icones\", \"sistema\", \"*.svg\"))) + [resgate]:\n    vistos += 1\n    nome = os.path.basename(svg)\n    if nome in DO_MANUAIS:\n        continue\n"
},
{
"arquivo": "tests/pastas-do-pack.sh",
"antes": "linha = next((l for l in proc.splitlines() if l.startswith(\"| `icones/sistema/pastas/*.svg`\")), \"\")\n",
"depois": "linha = next((l for l in proc.splitlines() if l.startswith(\"| `icones/sistema/*.svg`\")), \"\")\n"
},
{
"arquivo": "tests/pastas-do-pack.sh",
"antes": "N_PASTAS=\"$(find \"$RAIZ/packs/dracula/icones/sistema/pastas\" -maxdepth 1 -name '*.svg' | wc -l)\"\naplicou=\"$(xdg \"$T/casa-xdg\" dracula dracula --aplicar)\"\nconferiu=\"$(xdg \"$T/casa-xdg\" dracula dracula --conferir)\"; rc=$?\npostos=0\nfor d in \"$RAIZ/packs/dracula/icones/sistema/pastas/\"*.svg; do\n",
"depois": "N_PASTAS=\"$(find \"$RAIZ/packs/dracula/icones/sistema\" -maxdepth 1 -name '*.svg' | wc -l)\"\naplicou=\"$(xdg \"$T/casa-xdg\" dracula dracula --aplicar)\"\nconferiu=\"$(xdg \"$T/casa-xdg\" dracula dracula --conferir)\"; rc=$?\npostos=0\nfor d in \"$RAIZ/packs/dracula/icones/sistema/\"*.svg; do\n"
},
{
"arquivo": "tests/pastas-do-pack.sh",
"antes": "with open(os.path.join(raiz, \"packs\", \"catppuccin\", \"paleta.json\"), encoding=\"utf-8\") as fh:\n",
"depois": "with open(os.path.join(raiz, \"packs\", \"meowsystem\", \"paleta.json\"), encoding=\"utf-8\") as fh:\n"
},
{
"arquivo": "tests/pastas-do-pack.sh",
"antes": "cat, dra = paleta(\"catppuccin\"), paleta(\"dracula\")[\"dracula\"]\n",
"depois": "cat, dra = paleta(\"meowsystem\"), paleta(\"dracula\")[\"dracula\"]\n"
},
{
"arquivo": "tests/pastas-do-pack.sh",
"antes": "latte, alu = paleta(\"catppuccin\")[\"latte\"], paleta(\"dracula\")[\"alucard\"]\n",
"depois": "latte, alu = paleta(\"meowsystem\")[\"latte\"], paleta(\"dracula\")[\"alucard\"]\n"
},
{
"arquivo": "tests/pastas-do-pack.sh",
"antes": "PAL_CAT=\"$RAIZ/packs/catppuccin/paleta.json\"\n",
"depois": "PAL_CAT=\"$RAIZ/packs/meowsystem/paleta.json\"\n"
},
{
"arquivo": "tests/previa-cerca.sh",
"antes": "nosso=\"$(ls \"$RAIZ\"/packs/meowsystem/icones/apps/convertidos/*.svg 2>/dev/null | head -1)\"\n",
"depois": "nosso=\"$(ls \"$RAIZ\"/packs/meowsystem/icones/apps/*.svg 2>/dev/null | head -1)\"\n"
},
{
"arquivo": "tests/restos-do-painel.sh",
"antes": "                arquivo: \"packs/meowsystem/icones/apps/arcticons/google-chrome.svg\", url: \"/previa?y\" };\n",
"depois": "                arquivo: \"packs/meowsystem/icones/apps/google-chrome.svg\", url: \"/previa?y\" };\n"
},
{
"arquivo": "tests/seletor-do-pack.sh",
"antes": "checa({\"pack:dracula:apps\", \"pack:meowsystem:apps/arcticons\"} <= grupos,\n",
"depois": "checa({\"pack:dracula:apps\", \"pack:meowsystem:apps\"} <= grupos,\n"
},
{
"arquivo": "tests/seletor-do-pack.sh",
"antes": "de_fora = [i for i, gid in enumerate(ordem) if gid.startswith(\"pack:catppuccin:\")]\ncheca(do_ar and de_fora and max(do_ar) < min(de_fora),\n      \"com o Dracula no ar, o Catppuccin aparece na pasta dele, depois das do Dracula\", repr(ordem))\n",
"depois": "de_fora = [i for i, gid in enumerate(ordem) if gid.startswith(\"pack:meowsystem:\")]\ncheca(do_ar and de_fora and max(do_ar) < min(de_fora),\n      \"com o Dracula no ar, o pack padrão aparece na pasta dele, depois das do Dracula\", repr(ordem))\n"
},
{
"arquivo": "tests/seletor-do-pack.sh",
"antes": "conf_com(PACK=\"catppuccin\", FLAVOR=\"mocha\")\n",
"depois": "conf_com(PACK=\"meowsystem\", FLAVOR=\"mocha\")\n"
},
{
"arquivo": "tests/seletor-do-pack.sh",
"antes": "checa(r.get(\"grupos\") and r[\"grupos\"][0][\"id\"].startswith(\"pack:catppuccin:\"),\n",
"depois": "checa(r.get(\"grupos\") and r[\"grupos\"][0][\"id\"].startswith(\"pack:meowsystem:\"),\n"
},
{
"arquivo": "tests/seletor-do-pack.sh",
"antes": "codigo, dados = chamar(m._api_app_icone, {\"app\": \"programa-de-brinquedo\", \"cor\": \"mauve\",\n                                          \"arquivo\": \"packs/meowsystem/icones/apps/arcticons/firefox.svg\"})\nwith open(escolhas, encoding=\"utf-8\") as fh:\n",
"depois": "codigo, dados = chamar(m._api_app_icone, {\"app\": \"programa-de-brinquedo\", \"cor\": \"mauve\",\n                                          \"arquivo\": \"packs/meowsystem/icones/apps/firefox.svg\"})\nwith open(escolhas, encoding=\"utf-8\") as fh:\n"
},
{
"arquivo": "tests/seletor-do-pack.sh",
"antes": "codigo, dados = chamar(m._api_app_icone, {\"app\": \"programa-de-brinquedo\", \"cor\": \"mauve\",\n                                          \"arquivo\": \"packs/meowsystem/icones/apps/arcticons/firefox.svg\"})\ncheca(codigo == 200 and dados.get(\"tirou_escolha\") is False,\n",
"depois": "codigo, dados = chamar(m._api_app_icone, {\"app\": \"programa-de-brinquedo\", \"cor\": \"mauve\",\n                                          \"arquivo\": \"packs/meowsystem/icones/apps/firefox.svg\"})\ncheca(codigo == 200 and dados.get(\"tirou_escolha\") is False,\n"
},
{
"arquivo": "tests/temas-de-apps.sh",
"antes": "if printf '%s' \"$saida\" | grep -qx 'pack=catppuccin'; then\n",
"depois": "if printf '%s' \"$saida\" | grep -qx 'pack=meowsystem'; then\n"
},
{
"arquivo": "tests/temas-de-apps.sh",
"antes": "mapfile -t MODELOS < <(find \"$RAIZ/packs\" -path '*/apps/*.modelo.*' -type f | sort)\nif [ \"${#MODELOS[@]}\" -eq 0 ]; then\n  falha \"nenhum modelo em packs/*/apps/ — os temas de aplicativo da P42 sumiram\"\n",
"depois": "# [P96, 23/10/2026: o modelo que a paleta preenche inteiro mora no motor, scripts/temas-de-apps/<app>/.]\nmapfile -t MODELOS < <(find \"$RAIZ/scripts/temas-de-apps\" -name '*.modelo.*' -type f | sort)\nif [ \"${#MODELOS[@]}\" -eq 0 ]; then\n  falha \"nenhum modelo em scripts/temas-de-apps/ — os temas de aplicativo da P42 sumiram\"\n"
},
{
"arquivo": "tests/temas-de-apps.sh",
"antes": "  pal=\"$(dirname \"$(dirname \"$m\")\")/paleta.json\"\n  pack_id=\"$(basename \"$(dirname \"$(dirname \"$m\")\")\")\"\n",
"depois": "  # O modelo é do motor e serve a qualquer pack; o que o declara hoje é o Dracula.\n  pal=\"$RAIZ/packs/dracula/paleta.json\"\n  pack_id=\"dracula\"\n"
},
{
"arquivo": "tests/temas-de-apps.sh",
"antes": "  && cmp -s \"$alvo_qb\" \"$RAIZ/packs/dracula/apps/dracula.qbtheme\" && escrito_ok=1\n",
"depois": "  && cmp -s \"$alvo_qb\" \"$RAIZ/packs/dracula/temas-de-apps/qbittorrent/dracula.qbtheme\" && escrito_ok=1\n"
},
{
"arquivo": "tests/temas-de-apps.sh",
"antes": "[ \"$rc\" = 0 ] && printf '%s' \"$saida\" | grep -q \"como 'WhatsApp' com o ícone Catppuccin\" \\\n",
"depois": "[ \"$rc\" = 0 ] && printf '%s' \"$saida\" | grep -q \"como 'WhatsApp' com o ícone MeowSystem\" \\\n"
},
{
"arquivo": "tests/tres-pastas.sh",
"antes": "for id in meowsystem dracula catppuccin; do\n  saida=\"$(pack_py validar \"$id\" 2>&1)\"; rc=$?\n  dirs=\"$(find \"$RAIZ/packs/$id/icones\" -mindepth 1 -maxdepth 1 -type d -printf '%f\\n' | sort | paste -sd,)\"\n  if [ \"$rc\" = \"0\" ] && [[ \"$saida\" == *\"formato 2\"* ]] \\\n     && [[ \"$dirs\" =~ ^(apps|biblioteca|sistema)(,(apps|biblioteca|sistema))*$ ]]; then\n    ok \"o pack $id valida no formato 2, e o icones/ dele tem só $dirs\"\n  else\n    falha \"o pack $id não está no formato de três pastas (rc=$rc, pastas: $dirs)\" \"$saida\"\n  fi\ndone\n# Pelo git, e não pelo disco: o `upstream/` baixado mora ali, fora do índice.\n",
"depois": "# [P96, 23/10/2026: dois packs, `meowsystem` (o padrão, com o Catppuccin dentro) e `dracula`; as\n#  três pastas são planas.]\nfor id in meowsystem dracula; do\n  saida=\"$(pack_py validar \"$id\" 2>&1)\"; rc=$?\n  dirs=\"$(find \"$RAIZ/packs/$id/icones\" -mindepth 1 -maxdepth 1 -type d -printf '%f\\n' | sort | paste -sd,)\"\n  sub=\"$(find \"$RAIZ/packs/$id/icones\" -mindepth 2 -type d | head -3)\"\n  if [ \"$rc\" = \"0\" ] && [[ \"$saida\" == *\"formato 2\"* ]] && [ -z \"$sub\" ] \\\n     && [[ \"$dirs\" =~ ^(apps|biblioteca|sistema)(,(apps|biblioteca|sistema))*$ ]]; then\n    ok \"o pack $id valida no formato 2, e o icones/ dele tem só $dirs, sem subpasta\"\n  else\n    falha \"o pack $id não está no formato de três pastas planas (rc=$rc, pastas: $dirs, subpastas: $sub)\" \"$saida\"\n  fi\ndone\n[ ! -e \"$RAIZ/packs/catppuccin\" ] && [ \"$(find \"$RAIZ/packs\" -mindepth 1 -maxdepth 1 -type d | wc -l)\" = 2 ] \\\n  && ok \"packs/ tem dois packs, e o Catppuccin mora no meowsystem\" \\\n  || falha \"packs/ não tem só os dois packs\" \"$(ls \"$RAIZ/packs\")\"\n"
},
{
"arquivo": "tests/tres-pastas.sh",
"antes": "# --- 2. o pack-base não se veste ----------------------------------------------\nsaida=\"$(pack_py caminho meowsystem id 2>&1)\"; rc=$?\n[ \"$rc\" != \"0\" ] && [[ \"$saida\" == *\"pack-base\"* ]] \\\n  && ok \"a porta do motor recusa o pack-base, e diz por quê\" \\\n  || falha \"o pack-base passou pela porta do motor (rc=$rc)\" \"$saida\"\nsaida=\"$(pack_py adocao meowsystem \"\" 2>&1)\"\n[[ \"$saida\" == *\"pack=catppuccin\"* && \"$saida\" == *\"recusado=meowsystem\"* ]] \\\n  && ok \"PACK=meowsystem veste o padrão: o pack-base não é tema\" \\\n  || falha \"o pack-base foi adotado como tema\" \"$saida\"\n",
"depois": "# O PACK PADRÃO SE VESTE (P96): ele é o meowsystem, com a paleta do Catppuccin, e o nome de antes\n#   ainda o acha — um conf ou uma herança escritos antes de 23/10 não perdem o pack.\nsaida=\"$(pack_py caminho meowsystem id 2>&1)\"; rc=$?\n[ \"$rc\" = \"0\" ] && ok \"a porta do motor aceita o meowsystem, que é o pack padrão\" \\\n  || falha \"o pack padrão não passa pela porta do motor (rc=$rc)\" \"$saida\"\nsaida=\"$(pack_py adocao \"\" \"\" 2>&1)\"\n[[ \"$saida\" == *\"pack=meowsystem\"* ]] && ok \"sem PACK no conf, veste o meowsystem\" || falha \"o padrão não é o meowsystem\" \"$saida\"\nsaida=\"$(pack_py adocao catppuccin \"\" 2>&1)\"\n[[ \"$saida\" == *\"pack=meowsystem\"* && \"$saida\" != *\"recusado=catppuccin\"* ]] \\\n  && ok \"PACK=catppuccin, o nome de antes, veste o meowsystem\" \\\n  || falha \"o nome de antes do pack padrão não acha o meowsystem\" \"$saida\"\n"
},
{
"arquivo": "tests/tres-pastas.sh",
"antes": "[[ \",$cartoes,\" != *\",meowsystem,\"* && \",$cartoes,\" == *\",dracula,\"* ]] \\\n  && ok \"o painel não faz cartão do pack-base ($cartoes)\" \\\n  || falha \"o pack-base virou cartão no painel\" \"$cartoes\"\n\n# --- 3. a quarta pasta é recusada no formato 2 ---------------------------------\n",
"depois": "[[ \",$cartoes,\" == *\",meowsystem,\"* && \",$cartoes,\" == *\",dracula,\"* && \",$cartoes,\" != *\",catppuccin,\"* ]] \\\n  && ok \"o painel faz um cartão para cada um dos dois packs ($cartoes)\" \\\n  || falha \"os cartões do painel não são os dois packs\" \"$cartoes\"\n\n"
},
{
"arquivo": "tests/tres-pastas.sh",
"antes": "( cd \"$V/velho/icones\" \\\n  && mv apps/autorais autorais && mv sistema/mimetypes mimetypes && mv sistema/pastas pastas \\\n  && mv biblioteca/feitos-a-mao feitos-a-mao && rmdir sistema )\n",
"depois": "# O pack de antes (formato 1): os autorais em icones/autorais/, as pastas em icones/pastas/ e um\n# feito à mão em icones/feitos-a-mao/ — montado a partir do de hoje, que é plano.\n( cd \"$V/velho/icones\" && mkdir -p autorais pastas feitos-a-mao \\\n  && for f in apps/*-dracula.svg apps/*-alucard.svg; do mv \"$f\" autorais/; done \\\n  && mv sistema/*.svg pastas/ && mv biblioteca/alien.svg feitos-a-mao/ && rmdir sistema )\n"
},
{
"arquivo": "tests/tres-pastas.sh",
"antes": "volta = {\"icones/apps/autorais/\": \"icones/autorais/\", \"icones/sistema/mimetypes/\": \"icones/mimetypes/\",\n         \"icones/sistema/pastas/\": \"icones/pastas/\"}\nfor bloco in p[\"icones\"].values():\n    if isinstance(bloco, dict) and bloco.get(\"desenhos\") in volta:\n        bloco[\"desenhos\"] = volta[bloco[\"desenhos\"]]\njson.dump(p, open(f, \"w\", encoding=\"utf-8\"), ensure_ascii=False, indent=2)\nm = os.path.join(d, \"icones\", \"apps.map\")\nt = open(m, encoding=\"utf-8\").read()\n# Uma linha que aponta para a pasta de antes, como um pack velho escreveria.\nt += \"\\ncom.exemplo.Velho : feitos-a-mao/opera.svg   # aponta para a pasta de antes\\n\"\nopen(m, \"w\", encoding=\"utf-8\").write(t)\npr = os.path.join(d, \"PROCEDENCIA.md\")\nt = open(pr, encoding=\"utf-8\").read()\nt = re.sub(r\"^\\| `icones/biblioteca/feitos-a-mao/\", \"| `icones/feitos-a-mao/\", t, flags=re.M)\nt = re.sub(r\"^\\| `icones/sistema/pastas/\", \"| `icones/pastas/\", t, flags=re.M)\n",
"depois": "ic = p[\"icones\"]\nic[\"autorais\"][\"desenhos\"] = \"icones/autorais/\"\nic[\"pastas\"][\"desenhos\"] = \"icones/pastas/\"\njson.dump(p, open(f, \"w\", encoding=\"utf-8\"), ensure_ascii=False, indent=2)\nm = os.path.join(d, \"icones\", \"apps.map\")\nt = open(m, encoding=\"utf-8\").read()\nt += \"\\ncom.exemplo.Velho : feitos-a-mao/alien.svg   # aponta para a pasta de antes\\n\"\nopen(m, \"w\", encoding=\"utf-8\").write(t)\npr = os.path.join(d, \"PROCEDENCIA.md\")\nt = open(pr, encoding=\"utf-8\").read()\nt = t.replace(\"| `icones/biblioteca/alien.svg` |\", \"| `icones/feitos-a-mao/alien.svg` |\")\nt = re.sub(r\"^\\| `icones/sistema/\", \"| `icones/pastas/\", t, flags=re.M)\n"
},
{
"arquivo": "tests/tres-pastas.sh",
"antes": "   && [ -f \"$NOVO/icones/apps/autorais/cosmic-term-dracula.svg\" ] \\\n   && [ -f \"$NOVO/icones/sistema/pastas/folder.svg\" ] \\\n   && [ -f \"$NOVO/icones/biblioteca/feitos-a-mao/opera.svg\" ] \\\n   && grep -q '^com.exemplo.Velho : biblioteca/feitos-a-mao/opera.svg' \"$NOVO/icones/apps.map\"; then\n  ok \"o .meowpack de formato 1 é importado no formato 2: três pastas, os mesmos bytes, o mapa e o pack.json no caminho novo\"\n",
"depois": "   && [ -f \"$NOVO/icones/apps/cosmic-term-dracula.svg\" ] \\\n   && [ -f \"$NOVO/icones/sistema/folder.svg\" ] \\\n   && [ -f \"$NOVO/icones/biblioteca/alien.svg\" ] && [ -z \"$(find \"$NOVO/icones\" -mindepth 2 -type d)\" ] \\\n   && grep -q '^com.exemplo.Velho : biblioteca/alien.svg' \"$NOVO/icones/apps.map\"; then\n  ok \"o .meowpack de formato 1 é importado no formato 2: três pastas planas, os mesmos bytes, o mapa e o pack.json no caminho novo\"\n"
},
{
"arquivo": "tests/tres-pastas.sh",
"antes": "for par in \"assets/icones/resgatados/luna.svg:packs/dracula/icones/apps/resgatados/luna.svg\" \\\n           \"assets/icones/arcticons-apps/firefox.svg:packs/meowsystem/icones/apps/arcticons/firefox.svg\" \\\n           \"packs/dracula/icones/feitos-a-mao/opera.svg:packs/dracula/icones/biblioteca/feitos-a-mao/opera.svg\" \\\n",
"depois": "for par in \"assets/icones/resgatados/luna.svg:packs/dracula/icones/apps/luna.svg\" \\\n           \"assets/icones/arcticons-apps/firefox.svg:packs/meowsystem/icones/apps/firefox.svg\" \\\n           \"packs/dracula/icones/feitos-a-mao/opera.svg:$(awk -F'\\t' '$1 == \"packs/dracula/icones/biblioteca/feitos-a-mao/opera.svg\" {print $2}' \"$RAIZ/packs/CAMINHOS-DE-ANTES.tsv\")\" \\\n"
},
{
"arquivo": "tests/tres-pastas.sh",
"antes": "[[ \"$saida\" == \"com.exemplo.Escolhido\t$RAIZ/packs/dracula/icones/apps/resgatados/luna.svg\" ]] \\\n",
"depois": "[[ \"$saida\" == \"com.exemplo.Escolhido\t$RAIZ/packs/dracula/icones/apps/luna.svg\" ]] \\\n"
},
{
"arquivo": "tests/tres-pastas.sh",
"antes": "icones7 catppuccin mocha\n",
"depois": "icones7 meowsystem mocha\n"
},
{
"arquivo": "tests/tres-pastas.sh",
"antes": "ln -s \"$T/segredo.svg\" \"$T/packs/malresg/icones/apps/resgatados/elo.svg\"\n",
"depois": "ln -s \"$T/segredo.svg\" \"$T/packs/malresg/icones/apps/elo.svg\"\n"
},
{
"arquivo": "tests/tres-pastas.sh",
"antes": "\nif [ \"$falhas\" -gt 0 ]; then\n",
"depois": "\n# A `apps/` plana do MeowSystem guarda o convertido junto do traço e dos autorais: o conferir dos\n# convertidos não conta os outros como órfãos (o container de 23/10 dizia «52 a remover»).\nmkdir -p \"$T/casa-conv\"\nsaida=\"$(env -i PATH=\"$PATH\" HOME=\"$T/casa-conv\" NO_COLOR=1 bash \"$RAIZ/scripts/construir_convertidos.sh\" --conferir 2>&1)\"\nif [[ \"$saida\" == *\"convertido(s) em dia\"* ]] && [[ \"$saida\" != *\"a remover\"* ]]; then\n  ok \"o conferir dos convertidos olha só o mapa deles, e não o resto da apps/ plana\"\nelse\n  falha \"o conferir dos convertidos acusa o resto da apps/ plana\" \"$saida\"\nfi\n\nif [ \"$falhas\" -gt 0 ]; then\n"
},
{
"arquivo": "tests/variante.sh",
"antes": "cp -a \"$RAIZ/packs/dracula\" \"$RAIZ/packs/catppuccin\" \"$PACKS/\" || exit 2\nCAT=\"$PACKS/catppuccin/temas/capturados\"; DRA=\"$PACKS/dracula/temas/capturados\"\n",
"depois": "cp -a \"$RAIZ/packs/dracula\" \"$RAIZ/packs/meowsystem\" \"$PACKS/\" || exit 2\nCAT=\"$PACKS/meowsystem/temas/capturados\"; DRA=\"$PACKS/dracula/temas/capturados\"\n"
},
{
"arquivo": "tests/variante.sh",
"antes": "                       (\"catppuccin\", {\"mocha-green\": \"mocha-pink\", \"latte-pink\": \"latte-mauve\"})):\n",
"depois": "                       (\"meowsystem\", {\"mocha-green\": \"mocha-pink\", \"latte-pink\": \"latte-mauve\"})):\n"
},
{
"arquivo": "tests/variante.sh",
"antes": "for pack_id in dracula catppuccin; do\n",
"depois": "for pack_id in dracula meowsystem; do\n"
},
{
"arquivo": "tests/variante.sh",
"antes": "esperado = {\"dracula\": (\"alucard\", \"dracula\"), \"catppuccin\": (\"latte\", \"mocha\")}[sys.argv[2]]\n",
"depois": "esperado = {\"dracula\": (\"alucard\", \"dracula\"), \"meowsystem\": (\"latte\", \"mocha\")}[sys.argv[2]]\n"
},
{
"arquivo": "tests/variante.sh",
"antes": "cp -a \"$RAIZ/packs/catppuccin\" \"$SEM/\"; rm -rf \"$SEM\"/catppuccin/temas/capturados/mocha-*\n",
"depois": "cp -a \"$RAIZ/packs/meowsystem\" \"$SEM/\"; rm -rf \"$SEM\"/meowsystem/temas/capturados/mocha-*\n"
},
{
"arquivo": "tests/variante.sh",
"antes": "saida=\"$(amb env MEOW_PACKS=\"$SEM\" MEOW_PACK_DIR=\"$SEM/catppuccin\" MEOW_PALETA=\"$SEM/catppuccin/paleta.json\" \\\n",
"depois": "saida=\"$(amb env MEOW_PACKS=\"$SEM\" MEOW_PACK_DIR=\"$SEM/meowsystem\" MEOW_PALETA=\"$SEM/meowsystem/paleta.json\" \\\n"
},
{
"arquivo": "tests/vidro-do-cosmic.sh",
"antes": "cp -a \"$RAIZ/packs/dracula\" \"$RAIZ/packs/catppuccin\" \"$PACKS/\" || exit 2\n",
"depois": "cp -a \"$RAIZ/packs/dracula\" \"$RAIZ/packs/meowsystem\" \"$PACKS/\" || exit 2\n"
},
{
"arquivo": "tests/vidro-do-cosmic.sh",
"antes": "cp -a \"$PACKS/catppuccin/temas/capturados/mocha-pink\"/com.system76.CosmicTheme.* \"$C5/\"\n",
"depois": "cp -a \"$PACKS/meowsystem/temas/capturados/mocha-pink\"/com.system76.CosmicTheme.* \"$C5/\"\n"
},
{
"arquivo": "tests/vidro-do-cosmic.sh",
"antes": "saida=\"$(amb \"$C3\" catppuccin bash \"$RAIZ/scripts/aplicar_tema.sh\" mocha-pink 2>&1)\"; rc=$?\n",
"depois": "saida=\"$(amb \"$C3\" meowsystem bash \"$RAIZ/scripts/aplicar_tema.sh\" mocha-pink 2>&1)\"; rc=$?\n"
}
]
__P96_DADOS__

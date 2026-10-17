#!/usr/bin/env bash
# frases-velhas.sh — as frases que envelheceram não voltam a ser ditas no presente.
#
# A cauda de frase velha crescia por linha.
#
# A tradução para os códigos do projeto é a última linha.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v python3 >/dev/null 2>&1 || { printf 'FALHOU: sem python3\n' >&2; exit 2; }

printf 'as frases velhas: cinco classes, no repositório inteiro\n\n'

python3 - "$RAIZ" <<'PY'
import os
import re
import subprocess
import sys

raiz = sys.argv[1]
EU = "tests/frases-velhas.sh"
FORA = ("docs/sprints/", "docs/SPRINTS.md", "docs/pesquisas/", "docs/historico/", "docs/folhas/")
BINARIO = re.compile(r"\.(?:svg|png|jpe?g|webp|gif|ico|ttf|otf|woff2?|mp3|ogg|wav|gz|zip|xcf|pdf)$", re.I)
PROSA = re.compile(r"\.(?:md|txt)$", re.I)

# ---------------------------------------------------------------------------
# As classes. `cita`: se a citação entre aspas conta como história (ver o
# cabeçalho, e a classe 4). `onde`: prefixos de caminho, quando a classe é de
# um lugar só. `gatilho`: minúsculas que o arquivo precisa conter para valer a
# pena desmontá-lo em frases.
# ---------------------------------------------------------------------------
I = re.I
CLASSES = [
    {"num": 1, "nome": "o flavor que nunca foi fotografado como o caso sem saída",
     "cita": True, "onde": None, "gatilho": ("flavor",),
     "padroes": [
         # O «ainda» no meio entrou na revisão da P67: «o flavor que ainda não
         # foi fotografado» passava.
         re.compile(r"\bflavor(?:es)?\s+(?:que\s+)?(?:ainda\s+)?(?:nunca|jamais|n[aã]o)\s+(?:foi|foram|"
                    r"tenha\s+sido|tenham\s+sido|é|são)\s+(?:fotografad|capturad)\w*", I),
         re.compile(r"\bflavor(?:es)?\s+(?:nunca|jamais)\s+(?:fotografad|capturad)\w*", I),
         re.compile(r"\bflavor(?:es)?\s+sem\s+(?:foto|fotografia|captura)(?:\s+nenhuma)?,?\s+"
                    r"(?:n[aã]o\s+(?:aplica|se\s+deriva|tem\s+de\s+onde)|(?:fica|vai)\s+para\s+a\s+GUI)", I),
         re.compile(r"n[aã]o\s+cheg\w+\s+ao\s+COSMIC\s+\(o\s+flavor\s+sem\s+(?:foto|fotografia|captura)", I),
     ]},
    {"num": 2, "nome": "a Light do Dracula como o Latte",
     "cita": True, "onde": None, "gatilho": ("latte",),
     "padroes": [
         re.compile(r"\bfoto\s+(?:do\s+)?`?dracula(?:-mauve)?`?\s+traz\s+(?:na\s+Light|no\s+claro)\s+o\s+`?Latte", I),
         re.compile(r"\b(?:Light|árvore\s+Light|claro)\s+d[ao]\s+`?dracula(?:-mauve)?`?\s+(?:é|continua\s+sendo)\s+"
                    r"o\s+`?Latte", I),
         re.compile(r"\bFLAVOR=dracula\s+e\s+MODO=claro\s+(?:a\s+tela|o\s+COSMIC)\s+(?:mostra|veste)\s+o\s+`?latte", I),
     ]},
    {"num": 3, "nome": "as pastas em mauve, ou no pastel do Catppuccin, como a regra",
     "cita": True, "onde": None, "gatilho": ("mauve", "pastel", "roxas", "catppuccin"),
     "padroes": [
         re.compile(r"\b(?:continua|continuam|fica|ficam|segue|seguem|volta|voltam|devolve|devolvem)\s+"
                    r"(?:a\s+ser\s+|a\s+|ao\s+|em\s+|de\s+)?(?:o\s+)?mauve\b", I),
         # A cor ANTES do verbo, a forma que o `bin/meow` guardava no comentário
         # do `chk_pastasxdg` («o mauve volta sozinho») e que a varredura da P67
         # deixou passar, porque o padrão de cima só olhava o verbo antes da cor.
         # O `(?<![\w-])` é para o nome de tema (`cat-mocha-mauve`) não contar.
         re.compile(r"(?<![\w-])mauve\s+(?:continua|continuam|fica|ficam|segue|seguem|volta|voltam|"
                    r"devolve|devolvem)\b", I),
         # A «PASTA MAUVE CHAPADA» é o ícone do Gestor de Arquivos de que ela
         # reclamou em 11/08/2026 — o desenho de um aplicativo, e não a regra
         # das pastas. Citada em três arquivos, sempre como a queixa dela.
         re.compile(r"\b(?:pastas?|apelidos?)\s+mauve\b(?!\s+chapada)", I),
         re.compile(r"\b(?:o|do|no|ao|cujo|sem\s+o|em\s+vez\s+do)\s+pastel\b", I),
         re.compile(r"\broxas\s+do\s+papirus-folders\b", I),
         re.compile(r"\bpack\s+Catppuccin\s+vestindo\s+as\s+pastas\s+especiais\b|"
                    r"\bvestidas\s+pelo\s+pack\s+Catppuccin\b", I),
     ]},
    {"num": 4, "nome": "o botão do traço pelo nome de antes da P64",
     "cita": False, "onde": None, "gatilho": ("voltar ao",),
     "padroes": [re.compile(r"\bVoltar\s+ao\s+[íi]cone\s+de\s+f[áa]brica\b", I)]},
    {"num": 5, "nome": "a faixa de RMSE dos resgatados sem a data dela",
     "cita": True, "onde": ("assets/icones/", "packs/meowsystem/", "packs/dracula/icones/"),
     "gatilho": ("ficaram entre",),
     "padroes": [re.compile(r"\bficaram\s+entre\s+\**\d+,\d+\**\s+e\s+\**\d+,\d+", I)]},
]

# ---------------------------------------------------------------------------
# O que faz de uma frase história
# ---------------------------------------------------------------------------
DATA = re.compile(r"\b(?:0?[1-9]|[12]\d|3[01])/(?:0[1-9]|1[0-2])(?:/(?:19|20)\d\d)?\b|\b20\d\d-[01]\d-[0-3]\d\b")
MARCA = re.compile(r"\b(?:até|antes\s+d)[ao]\s+(?:revisão\s+d[ao]\s+)?P\d+\b|\brevisão\s+d[ao]\s+P\d+\b|"
                   r"\bdesfeit[oa]s?\s+(?:pela|na)\s+P\d+\b|\b(?:medid|conferid)[oa]s?\b|\bmediu\b", I)
PASSADO = re.compile(r"^[»”\"'`)\s]*(?:era|eram|dizia|diziam|prometia|fazia|mexia|ficava|ficavam|voltava|"
                     r"chamava|tinha|tinham|virou|viraram|passou|passaram|foi|foram|saía|pedia|mostrava)\b", I)
LIDER = re.compile(r"^\s*(?:#+!?|//+|/\*+|\*+/?(?=\s|$)|<!--|>(?=\s)|--(?=\s))\s?")
REGUA = re.compile(r"(?:-{3,}|={3,}|─{3,})\s*$")
SO_DATA = re.compile(r"^[—–-]\s*\d{1,2}/\d{1,2}(?:/\d{2,4})?\b.{0,60}$")
FIM_DE_FRASE = re.compile(r"(?<=[.!?])[»”\"')\]]*\s+(?=[«“\"(\[`*]*[A-ZÁÉÍÓÚÂÊÔÃÕÇÀ0-9])")


def titulo(texto):
    letras = [c for c in texto if c.isalpha()]
    return len(letras) >= 8 and sum(c.isupper() for c in letras) >= 0.7 * len(letras)


def unidades(linhas, prosa):
    """Pedaços de texto sem quebra de linha, com (deslocamento, nº da linha,
    é comentário) de cada linha que entrou neles."""
    atual, pecas, saida = [], [], []

    def fecha():
        if atual:
            saida.append((" ".join(atual), list(pecas)))
        atual.clear()
        pecas.clear()

    def poe(texto, n, coment):
        desloc = sum(len(t) + 1 for t in atual)
        atual.append(texto)
        pecas.append((desloc, n, coment))

    for n, bruta in enumerate(linhas, 1):
        m = LIDER.match(bruta)
        coment = prosa or bool(m and m.group(0).strip())
        texto = (bruta[m.end():] if m else bruta).strip()
        if not texto:
            fecha()
        elif titulo(texto) or REGUA.search(texto) or SO_DATA.match(texto):
            fecha()
            poe(texto, n, coment)
            fecha()
        else:
            poe(texto, n, coment)
    fecha()
    return saida


def trechos(texto):
    """[(início, fim, tipo)] das citações e dos colchetes de revisão."""
    saida = []
    for abre, fecha_ in (("«", "»"), ("“", "”")):
        pilha = []
        for i, c in enumerate(texto):
            if c == abre:
                pilha.append(i)
            elif c == fecha_ and pilha:
                saida.append((pilha.pop(), i, "cita"))
    retas = [i for i, c in enumerate(texto) if c == '"']
    for a, b in zip(retas[0::2], retas[1::2]):
        saida.append((a, b, "reta"))
    for m in re.finditer(r"\[(?=[A-ZÁÉÍÓÚÂÊÔ«\"“\d])", texto):
        prof = 0
        for j in range(m.start(), min(len(texto), m.start() + 2000)):
            if texto[j] == "[":
                prof += 1
            elif texto[j] == "]":
                prof -= 1
                if prof == 0:
                    saida.append((m.start(), j, "colchete"))
                    break
    return saida


def historia(classe, caminho, texto, pecas, marcos, cercas, ini, fim):
    peca = max((p for p in pecas if p[0] <= ini), key=lambda p: p[0])
    for a, b, tipo in cercas:
        if a < ini <= b:
            if tipo == "colchete":
                return True
            if tipo == "cita" and classe["cita"]:
                return True
            if tipo == "reta" and classe["cita"] and (peca[2] or caminho.startswith("tests/")):
                return True
    a = max([0] + [x for x in marcos if x <= ini])
    b = min([len(texto)] + [x for x in marcos if x > ini])
    frase = texto[a:b]
    if DATA.search(frase) or MARCA.search(frase) or PASSADO.match(texto[fim:fim + 40]):
        return True
    return False


def arquivos():
    try:
        bruto = subprocess.run(["git", "-C", raiz, "ls-files", "-z"],
                               capture_output=True, check=True).stdout
        nomes = [n.decode("utf-8", "replace") for n in bruto.split(b"\0") if n]
    except (OSError, subprocess.CalledProcessError):
        nomes = []
        for base, dirs, fs in os.walk(raiz):
            dirs[:] = [d for d in dirs if d != ".git"]
            nomes += [os.path.relpath(os.path.join(base, f), raiz) for f in fs]
    return sorted(n for n in nomes
                  if n != EU and not n.startswith(FORA) and not BINARIO.search(n))


achados = {c["num"]: [] for c in CLASSES}
for caminho in arquivos():
    try:
        with open(os.path.join(raiz, caminho), encoding="utf-8") as fh:
            bruto = fh.read()
    except (OSError, UnicodeDecodeError):
        continue
    minusc = bruto.lower()
    vivas = [c for c in CLASSES
             if any(g in minusc for g in c["gatilho"])
             and (c["onde"] is None or caminho.startswith(c["onde"]))]
    if not vivas:
        continue
    for texto, pecas in unidades(bruto.splitlines(), bool(PROSA.search(caminho))):
        marcos = [m.end() for m in FIM_DE_FRASE.finditer(texto)]
        cercas = None
        for classe in vivas:
            for padrao in classe["padroes"]:
                for m in padrao.finditer(texto):
                    if cercas is None:
                        cercas = trechos(texto)
                    if historia(classe, caminho, texto, pecas, marcos, cercas, m.start(), m.end()):
                        continue
                    linha = max((p for p in pecas if p[0] <= m.start()), key=lambda p: p[0])[1]
                    a = max([0] + [x for x in marcos if x <= m.start()])
                    b = min([len(texto)] + [x for x in marcos if x > m.start()])
                    frase = texto[a:b].strip()
                    if len(frase) > 220:
                        c0 = max(0, m.start() - a - 100)
                        frase = "…" + frase[c0:c0 + 200] + "…"
                    achados[classe["num"]].append("%s:%d  %s" % (caminho, linha, frase))

falhas = 0
for classe in CLASSES:
    lista = achados[classe["num"]]
    if lista:
        falhas += 1
        print("  NÃO  classe %d — %s: %d frase(s) no presente" % (classe["num"], classe["nome"], len(lista)),
              file=sys.stderr)
        for item in lista[:12]:
            print("         " + item, file=sys.stderr)
        if len(lista) > 12:
            print("         ... e mais %d" % (len(lista) - 12), file=sys.stderr)
    else:
        print("  ok   classe %d — %s: nenhuma no presente" % (classe["num"], classe["nome"]))

# ---------------------------------------------------------------------------
# 5b. A FOLHA DE ANTES E DEPOIS NÃO FICA VELHA CALADA
#   A folha (`assets/icones/resgatados-antes-e-depois.png`) sai do
#   `scripts/resgatados_folha.sh`, que pede os PNG de origem nos caminhos do
#   mapa — e em 25/09/2026 doze dos 21 não estavam mais no disco, então a
#   folha daquele dia foi remontada a partir da velha, e não pelo script (o
#   PROCEDENCIA.md conta a costura). Uma folha pode ficar mais velha que os
#   desenhos, mas não calada, e a nota dela, no `packs/meowsystem/PROCEDENCIA.md`
#   (do parágrafo que fala da folha até o fim daquela seção, o próximo `## `),
#   responde por duas coisas:
#     · a data da frase «A folha de hoje é de dd/mm/aaaa» é a do commit da
#       folha. Refeita a folha, o commit anda, e a nota que ficou dizendo a
#       data de antes é achado;
#     · cada desenho que mudou depois do commit da folha, e cada linha que
#       entrou ou saiu do mapa desde então, está na primeira coluna de uma
#       tabela cujo cabeçalho diga «depois da folha de dd/mm/aaaa», com a data
#       dela. A tabela, e não a nota inteira: um nome citado de passagem (os
#       PNG que faltam, uma tabela de uma folha anterior) não é o aviso de que
#       aquele desenho mudou.
#   Refeita a folha, a data do commit anda e a tabela velha deixa de valer
#   sozinha. Pergunta ao git: fora dele, ou num clone raso (em que o commit da
#   folha pode ser só o mais velho que veio), não há como saber a idade da
#   folha, e esta seção diz e pula.
#   [Até a revisão da P67 (25/09/2026) bastava o nome aparecer em qualquer
#   ponto da nota, a data dela não era cobrada, e uma folha apagada passava por
#   «refeita nesta árvore».]
# ---------------------------------------------------------------------------
FOLHA = "assets/icones/resgatados-antes-e-depois.png"
MAPA = "packs/dracula/icones/apps-resgatados.map"
PROC = "packs/meowsystem/PROCEDENCIA.md"
DATA_DA_NOTA = re.compile(r"\bA\s+folha\s+de\s+hoje\s+é\s+de\s+\**(\d{1,2})/(\d{1,2})/(\d{4})\b", I)


def git(*args):
    return subprocess.run(["git", "-C", raiz, *args], capture_output=True, text=True)


def nomes_do_mapa(texto):
    saida = set()
    for linha in texto.splitlines():
        linha = linha.split("#", 1)[0]
        if linha.count(":") >= 2:
            saida.add(linha.split(":", 1)[0].strip())
    return saida - {""}


def nomes_da_tabela(nota, cabeca):
    """Os nomes da primeira coluna da tabela cujo cabeçalho contém `cabeca`."""
    linhas = nota.splitlines()
    for k, linha in enumerate(linhas):
        if linha.lstrip().startswith("|") and cabeca in linha.lower():
            saida = set()
            for corpo in linhas[k + 1:]:
                if not corpo.lstrip().startswith("|"):
                    break
                saida.update(corpo.strip().strip("|").split("|")[0].replace("`", " ").split())
            return saida
    return set()


try:
    # `--follow` e só A/M: a mudança de pasta da P88 (um `git mv`) não refaz a folha.
    r = git("log", "-1", "--follow", "--diff-filter=AM", "--format=%H %ad", "--date=short", "--", FOLHA)
except OSError:
    r = None
if r is None or r.returncode != 0 or not r.stdout.strip():
    print("  --   classe 5 — a folha dos resgatados: fora do git, a idade dela não se mede (pulado)")
elif not os.path.isfile(os.path.join(raiz, FOLHA)):
    falhas += 1
    print("  NÃO  classe 5 — a folha dos resgatados sumiu da árvore, e o PROCEDENCIA.md ainda aponta para "
          "ela: %s" % FOLHA, file=sys.stderr)
elif git("diff", "--quiet", "HEAD", "--", FOLHA).returncode != 0:
    print("  ok   classe 5 — a folha dos resgatados foi refeita nesta árvore (a nota se cobra no commit)")
elif git("rev-parse", "--is-shallow-repository").stdout.strip() == "true":
    print("  --   classe 5 — a folha dos resgatados: clone raso, a idade dela não se mede (pulado)")
else:
    commit, data = r.stdout.split()
    aaaa, mm, dd = data.split("-")
    quando = "%s/%s/%s" % (dd, mm, aaaa)
    with open(os.path.join(raiz, PROC), encoding="utf-8") as fh:
        proc = fh.read()
    ini = proc.find("ANTES-E-DEPOIS")
    fim = proc.find("\n## ", ini) if ini >= 0 else -1
    nota = "" if ini < 0 else proc[ini:fim if fim >= 0 else len(proc)]

    m = DATA_DA_NOTA.search(nota)
    if not m:
        falhas += 1
        print("  NÃO  classe 5 — a folha dos resgatados é de %s, e a nota dela no PROCEDENCIA.md não diz "
              "«A folha de hoje é de %s»" % (quando, quando), file=sys.stderr)
    elif (int(m.group(1)), int(m.group(2)), m.group(3)) != (int(dd), int(mm), aaaa):
        falhas += 1
        print("  NÃO  classe 5 — a nota da folha dos resgatados diz que ela é de %s, e o commit dela é de %s"
              % ("/".join(m.groups()), quando), file=sys.stderr)
    else:
        print("  ok   classe 5 — a nota da folha dos resgatados diz a data do commit dela, %s" % quando)

    velho = git("show", "%s:%s" % (commit, MAPA))
    if velho.returncode != 0:
        # o endereço do mapa antes da P88, que o desceu do motor para o pack Dracula
        velho = git("show", "%s:%s" % (commit, "assets/icones/apps-resgatados.map"))
    if velho.returncode != 0:
        print("  --   classe 5 — o mapa dos resgatados não existia no commit da folha (pulado)")
    else:
        antes = nomes_do_mapa(velho.stdout)
        with open(os.path.join(raiz, MAPA), encoding="utf-8") as fh:
            hoje = nomes_do_mapa(fh.read())
        mudaram = sorted(antes ^ hoje)
        for nome in sorted(antes & hoje):
            svg = "packs/dracula/icones/apps/resgatados/%s.svg" % nome
            era = (git("rev-parse", "--verify", "-q", "%s:%s" % (commit, svg)).stdout.strip()
                   or git("rev-parse", "--verify", "-q",
                          "%s:assets/icones/resgatados/%s.svg" % (commit, nome)).stdout.strip())
            e = git("hash-object", "--", svg).stdout.strip()
            if era and e and era != e:
                mudaram.append(nome)
        ditos = nomes_da_tabela(nota, "depois da folha de %s" % quando)
        faltam = [n for n in mudaram if n not in ditos]
        if faltam:
            falhas += 1
            print("  NÃO  classe 5 — a folha dos resgatados é de %s, e %d desenho(s) mudaram depois dela sem "
                  "estar na tabela «depois da folha de %s» do PROCEDENCIA.md: %s"
                  % (quando, len(faltam), quando, ", ".join(faltam)), file=sys.stderr)
        else:
            print("  ok   classe 5 — a folha dos resgatados é de %s, e %d desenho(s) mudaram depois dela"
                  % (quando, len(mudaram)))

sys.exit(3 if falhas else 0)
PY
rc=$?
case "$rc" in
  0) exit 0 ;;
  3) exit 1 ;;
  *) printf 'FALHOU: o python deste teste quebrou (saiu %s)\n' "$rc" >&2; exit 2 ;;
esac

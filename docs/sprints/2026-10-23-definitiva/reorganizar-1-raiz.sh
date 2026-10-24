#!/usr/bin/env bash
# reorganizar-1-raiz.sh — P96, parte 1: a raiz e o assets/.
#
#   reorganizar-1-raiz.sh --ensaio [RAIZ]   imprime a tabela do que faria, sem escrever
#   reorganizar-1-raiz.sh [RAIZ]            aplica; a segunda passada não escreve nada
#
# Roda ANTES do reorganizar-2-packs.sh. Não põe nada em packs/*/icones/ (é da
# parte 2). Troca texto por padrão literal ou regex, nunca por número de linha;
# põe no índice só os caminhos que tocou (nunca `git add -A`).
set -euo pipefail

ENSAIO=0
case "${1:-}" in --ensaio|-n) ENSAIO=1; shift ;; esac
RAIZ="${1:-$(git rev-parse --show-toplevel)}"
RAIZ="$(cd "$RAIZ" && pwd -P)"
[ -f "$RAIZ/install.sh" ] && [ -d "$RAIZ/packs" ] || { echo "não é a raiz do MeowSystem: $RAIZ" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DADOS="$TMP/trocas"
# As trocas por padrão moram no fim deste arquivo, depois da linha marcadora.
sed -n '/^#__TROCAS__$/,/^FIM_DAS_TROCAS$/p' "${BASH_SOURCE[0]}" | sed '1d;$d' > "$DADOS"

# O ENSAIO RODA NUMA CÓPIA: um clone que divide os objetos com o repositório e
# recebe a árvore de trabalho de agora. A tabela sai da cópia; nada se escreve aqui.
ALVO="$RAIZ"
if [ "$ENSAIO" = 1 ]; then
  ALVO="$TMP/copia"
  git clone -q --shared --no-checkout "$RAIZ" "$ALVO"
  git -C "$ALVO" read-tree HEAD
  rsync -a --exclude=/.git --exclude=/.playwright-mcp --exclude=/.trabalho-icones \
        --exclude=/assets/icones/upstream --exclude=/assets/fontes/upstream "$RAIZ/" "$ALVO/"
  git -C "$ALVO" add -u -- . >/dev/null 2>&1
fi

python3 -I - "$ALVO" "$ENSAIO" "$DADOS" "$RAIZ" <<'PY'
import glob, hashlib, os, re, shutil, subprocess, sys

RAIZ, RELATO, DADOS, ORIGINAL = sys.argv[1], sys.argv[2] == "1", sys.argv[3], sys.argv[4]
ENSAIO = False          # na cópia do ensaio se escreve de verdade; o relato é o que muda
os.chdir(RAIZ)
TABELA = []          # (ação, de, para, n)
TOCADOS = set()      # caminhos para o `git add`
APAGADOS = set()


def git(*a, ok=False):
    r = subprocess.run(["git", *a], capture_output=True, text=True)
    if r.returncode and not ok:
        sys.exit(f"git {' '.join(a)}: {r.stderr.strip()}")
    return r.stdout


def rastreados():
    return set(git("ls-files", "-z").split("\0")) - {""}


def anotar(acao, de, para="", n=1):
    TABELA.append((acao, de, para, n))


# ── 1. movimentos ────────────────────────────────────────────────────────────
# (padrão de origem, pasta de destino) — o caminho abaixo da raiz do padrão vai junto.
MOVER = [
    ("assets/gatos/coquinha.svg", "packs/meowsystem/mascote/"),
    ("assets/gatos/mimir.svg", "packs/meowsystem/mascote/"),
    ("assets/gatos/LEIA-ME.md", "packs/meowsystem/mascote/"),
    ("assets/gatos/morcego.svg", "packs/dracula/mascote/"),
    ("assets/gatos/morcego-dia.svg", "packs/dracula/mascote/"),
    ("assets/gatos/morcego-noite.svg", "packs/dracula/mascote/"),
    ("assets/papeis-de-parede/*", "packs/meowsystem/wallpapers/"),
    ("assets/temas-de-apps/heroic/SHA256SUMS", "packs/meowsystem/temas-de-apps/heroic/"),
    ("assets/temas-de-apps/heroic/PROCEDENCIA.md", "packs/meowsystem/temas-de-apps/heroic/"),
    ("assets/temas-de-apps/heroic/upstream/**", "packs/meowsystem/temas-de-apps/heroic/upstream/"),
    ("assets/temas-de-apps/obsidian/vendor/**", "packs/meowsystem/temas-de-apps/obsidian/vendor/"),
    ("assets/temas-de-apps/btop-bat/upstream/btop/catppuccin_*", "packs/meowsystem/temas-de-apps/btop-bat/upstream/btop/"),
    ("assets/temas-de-apps/btop-bat/upstream/bat/Catppuccin*", "packs/meowsystem/temas-de-apps/btop-bat/upstream/bat/"),
    ("assets/temas-de-apps/btop-bat/upstream/btop/dracula.theme", "packs/dracula/temas-de-apps/btop-bat/upstream/btop/"),
    ("assets/temas-de-apps/btop-bat/upstream/bat/Dracula.tmTheme", "packs/dracula/temas-de-apps/btop-bat/upstream/bat/"),
    ("assets/temas-de-apps/btop-bat/PROCEDENCIA.md", "packs/meowsystem/temas-de-apps/btop-bat/"),
    ("assets/temas-de-apps/**", "scripts/temas-de-apps/"),
    ("assets/icones/appid.map", "assets/apps/"),
    ("assets/icones/apps-nomes.map", "assets/apps/"),
    ("assets/icones/wmclass.map", "assets/apps/"),
    ("assets/icones/jogos-fora.map", "assets/apps/"),
    ("assets/icones/tray-terceiros/**", "assets/apps/tray-terceiros/"),
    ("contratos/*", "assets/contratos/"),
    ("vizinhos.conf.exemplo", "assets/contratos/"),
]
RENOMEAR = [
    ("assets/cursores/CREDITOS.md", "packs/meowsystem/licencas/cursores.md"),
    ("assets/sons/CREDITOS.md", "docs/SONS.md"),
]
APAGAR = [
    "assets/icones/previa-arcticons",        # 35 cópias byte a byte de desenhos do pack meowsystem
    "assets/temas-de-apps/btop-bat/SHA256SUMS",  # um por pack, regravado abaixo
    "scripts/icones_apps.sh",                # lia assets/icones/catppuccin-apps/, que nunca foi versionado
    "docs/folhas",
    "docs/pesquisas",
    "docs/capturas/spotify.jpg",
]
# Fora do git, no checkout onde roda: download e captura de QA.
APAGAR_SOLTOS = [
    ".playwright-mcp",
    "assets/icones/upstream",                # o papirus-folders desce para ~/.cache/meowsystem
    "assets/fontes/upstream",                # idem, o tarball da Nerd Font
    "assets/temas-de-apps",                  # sobra de __pycache__ depois do git mv
]


def base_do_padrao(padrao):
    partes = []
    for p in padrao.split("/"):
        if any(c in p for c in "*?["):
            break
        partes.append(p)
    return "/".join(partes)


def destino(origem, padrao, pasta):
    base = base_do_padrao(padrao)
    if base == origem:            # arquivo único: o nome vai para a pasta
        return pasta + os.path.basename(origem)
    if padrao.endswith("/**"):
        return pasta + os.path.relpath(origem, base)
    return pasta + os.path.basename(origem)


def mover():
    r = rastreados()
    for padrao, pasta in MOVER:
        if padrao.endswith("/**"):
            base = padrao[:-3] + "/"
            casados = sorted(f for f in r if f.startswith(base))
        else:
            rx = re.compile("^" + re.escape(padrao).replace(r"\*", "[^/]*") + "$")
            casados = sorted(f for f in r if rx.match(f))
        for f in casados:
            d = destino(f, padrao, pasta)
            anotar("mover", f, d)
            if not ENSAIO:
                os.makedirs(os.path.dirname(d), exist_ok=True)
                git("mv", "-k", f, d)
                TOCADOS.add(d)
                APAGADOS.add(f)
        r = rastreados() if not ENSAIO else r - set(casados)
    for de, para in RENOMEAR:
        if de in r:
            anotar("mover", de, para)
            if not ENSAIO:
                os.makedirs(os.path.dirname(para), exist_ok=True)
                git("mv", "-k", de, para)
                TOCADOS.add(para)
                APAGADOS.add(de)


def apagar():
    r = rastreados()
    for alvo in APAGAR:
        n = sum(1 for f in r if f == alvo or f.startswith(alvo + "/"))
        if n:
            anotar("apagar", alvo, "", n)
            if not ENSAIO:
                git("rm", "-r", "-q", "--", alvo)
                APAGADOS.add(alvo)
    for alvo in APAGAR_SOLTOS:
        caminho = os.path.join(ORIGINAL, alvo)
        if not os.path.lexists(caminho):
            continue
        if any(f == alvo or f.startswith(alvo + "/") for f in rastreados()):
            continue                 # ainda tem coisa versionada: não é sobra
        do_git = set(subprocess.run(["git", "-C", ORIGINAL, "ls-files", "--", alvo],
                                    capture_output=True, text=True).stdout.split("\n"))
        n = sum(1 for r, _, fs in os.walk(caminho) for f in fs
                if os.path.relpath(os.path.join(r, f), ORIGINAL) not in do_git)
        if n == 0 and os.path.isdir(caminho):
            continue                 # só o que o git move: a pasta vazia sai depois
        anotar("apagar (fora do git)", alvo, "", n)
        if not RELATO:
            shutil.rmtree(caminho) if os.path.isdir(caminho) and not os.path.islink(caminho) else os.remove(caminho)


# ── 2. o SHA256SUMS de cada pack, regravado do que está nele ─────────────────
def somas():
    for dono in ("meowsystem", "dracula"):
        pasta = f"packs/{dono}/temas-de-apps/btop-bat"
        if not os.path.isdir(pasta + "/upstream"):
            continue
        linhas = []
        for raiz, _, fs in os.walk(pasta + "/upstream"):
            for f in fs:
                p = os.path.join(raiz, f)
                with open(p, "rb") as fh:
                    linhas.append((os.path.relpath(p, pasta), hashlib.sha256(fh.read()).hexdigest()))
        texto = "".join(f"{h}  {p}\n" for p, h in sorted(linhas))
        escrever(pasta + "/SHA256SUMS", texto, "regravar somas")


def escrever(caminho, texto, acao="escrever"):
    atual = None
    if os.path.exists(caminho):
        with open(caminho, encoding="utf-8") as fh:
            atual = fh.read()
    if atual == texto:
        return
    anotar(acao, caminho)
    if not ENSAIO:
        os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
        with open(caminho, "w", encoding="utf-8") as fh:
            fh.write(texto)
        TOCADOS.add(caminho)


# ── 3. regras de texto ───────────────────────────────────────────────────────
FORA = re.compile(r"^(docs/sprints/|docs/historico/|docs/SPRINTS\.md$|packs/[^/]+/icones/|"
                  r"docs/reorganizar)")
BINARIO = re.compile(r"\.(png|jpe?g|gif|webp|ico|oga|ogg|wav|ttf|otf|qbtheme|gz|xz|zip|tar|pdf|svg)$")
# Dado de terceiro ou acervo: o nome ali dentro é nome de arquivo, não frase.
DADO = re.compile(r"(\.(tsv|padrao|map|theme|tmTheme|css)$|/SHA256SUMS$|/upstream/|/vendor/|LICENSE$)")

CAMINHOS = [
    (r"assets/temas-de-apps/heroic/upstream", "packs/meowsystem/temas-de-apps/heroic/upstream"),
    (r"assets/temas-de-apps/heroic/(SHA256SUMS|PROCEDENCIA\.md)", r"packs/meowsystem/temas-de-apps/heroic/\1"),
    (r"assets/temas-de-apps/obsidian/vendor", "packs/meowsystem/temas-de-apps/obsidian/vendor"),
    (r"assets/temas-de-apps/btop-bat/upstream", "packs/meowsystem/temas-de-apps/btop-bat/upstream"),
    (r"assets/temas-de-apps/btop-bat/PROCEDENCIA\.md", "packs/meowsystem/temas-de-apps/btop-bat/PROCEDENCIA.md"),
    (r"assets/temas-de-apps", "scripts/temas-de-apps"),
    (r"assets/gatos/?(?=[\s`'\")\]|,.:;]|$)", "packs/meowsystem/mascote/"),
    (r"assets/gatos/", "packs/meowsystem/mascote/"),
    (r"assets/papeis-de-parede", "packs/meowsystem/wallpapers"),
    (r"assets/icones/(appid|apps-nomes|wmclass|jogos-fora)\.map", r"assets/apps/\1.map"),
    (r"assets/icones/tray-terceiros", "assets/apps/tray-terceiros"),
    (r"(?<![\w-])(?<!assets/)contratos/(?=cosmic\.tsv|vizinhos\.tsv)", "assets/contratos/"),
    (r"(?<![\w/.-])vizinhos\.conf\.exemplo", "assets/contratos/vizinhos.conf.exemplo"),
    (r"assets/cursores/CREDITOS\.md", "packs/meowsystem/licencas/cursores.md"),
    (r"assets/sons/CREDITOS\.md", "docs/SONS.md"),
]
# «gatos» vira «mascote» no texto que se lê: comentário, texto entre aspas e
# prosa. Nome de variável, de arquivo, de unidade e de chave fica (vizinho de
# - . / _ $ { ou a palavra sozinha entre aspas).
_L = r"(?<![\w./_${-])(?<![\"'`])"
_R = r"(?![\w/_-])(?!\.\w)(?![\"'`])"
VOCABULARIO = [
    (re.compile(_L + r"gatos" + _R), "mascotes"),
    (re.compile(_L + r"gato" + _R), "mascote"),
    (re.compile(_L + r"Gatos" + _R), "Mascote"),
    (re.compile(_L + r"Gato" + _R), "Mascote"),
    (re.compile(_L + r"GATOS" + _R), "MASCOTES"),
    (re.compile(_L + r"GATO" + _R), "MASCOTE"),
]
PROSA = re.compile(r"\.(md|txt|exemplo|service|timer|path|html?)$|LEIA-?ME|README|^AGENTS|^GSD")


def _trechos_py(texto):
    import io, tokenize
    linhas = texto.splitlines(keepends=True)
    inicio = [0]
    for l in linhas:
        inicio.append(inicio[-1] + len(l))
    try:
        for tok in tokenize.generate_tokens(io.StringIO(texto).readline):
            if tok.type in (tokenize.COMMENT, tokenize.STRING) or \
               tok.type == getattr(tokenize, "FSTRING_MIDDLE", -1):
                (l0, c0), (l1, c1) = tok.start, tok.end
                yield inicio[l0 - 1] + c0, inicio[l1 - 1] + c1
    except (tokenize.TokenError, IndentationError, SyntaxError):
        yield 0, len(texto)


def _aspas(linha):
    """Os pares de aspas da linha, da esquerda para a direita, com espaço dentro."""
    i, n = 0, len(linha)
    while i < n:
        c = linha[i]
        if c in "\"'`":
            j = i + 1
            while j < n and linha[j] != c:
                j += 2 if linha[j] == "\\" else 1
            if j < n and re.search(r"\s", linha[i + 1:j]):
                yield i, j + 1
            i = j + 1
        else:
            i += 1


def _trechos_c(texto, hash_comenta):
    """Por linha: comentário (# ou //, /* */ de bloco) e texto entre aspas com
    espaço dentro — frase, nunca nome de variável."""
    marca = re.compile(r"(^|\s)#\s" if hash_comenta else r"(^|\s)//\s?")
    pos, em_bloco = 0, False
    for linha in texto.splitlines(keepends=True):
        lim = linha.strip()
        fim = pos + len(linha)
        if not hash_comenta and (em_bloco or lim.startswith("/*")):
            yield pos, fim
            em_bloco = "*/" not in lim
        elif lim.startswith(("#", "//", "*", "<!--")) if not hash_comenta else lim.startswith("#"):
            yield pos, fim
        else:
            m = marca.search(linha)
            corte = m.start() if m and linha[:m.start()].count('"') % 2 == 0 \
                and linha[:m.start()].count("'") % 2 == 0 else len(linha)
            for a, b in _aspas(linha[:corte]):
                yield pos + a, pos + b
            if corte < len(linha):
                yield pos + corte, fim
        pos = fim


def _trechos_html(texto):
    for m in re.finditer(r"<!--.*?-->|>[^<]+<", texto, re.S):
        yield m.start(), m.end()


def trechos(f, texto):
    if f.endswith(".py"):
        return list(_trechos_py(texto))
    if f.endswith((".js", ".css", ".json", ".jsonc")):
        return list(_trechos_c(texto, False))
    if re.search(r"\.html?$", f):
        return list(_trechos_html(texto))
    if PROSA.search(f):
        return [(0, len(texto))]
    return list(_trechos_c(texto, True))          # shell, conf, zsh, systemd


def vocabulario(f, texto):
    partes, ultimo, n = [], 0, 0
    for a, b in trechos(f, texto):
        if a < ultimo:
            continue
        pedaco = texto[a:b]
        for rx, sub in VOCABULARIO:
            pedaco, k = rx.subn(sub, pedaco)
            n += k
        partes.append(texto[ultimo:a]); partes.append(pedaco); ultimo = b
    partes.append(texto[ultimo:])
    return "".join(partes), n


def regras():
    for f in sorted(rastreados()):
        if FORA.match(f) or BINARIO.search(f) or not os.path.isfile(f):
            continue
        try:
            with open(f, encoding="utf-8") as fh:
                texto = fh.read()
        except UnicodeDecodeError:
            continue
        novo, n = texto, 0
        for rx, sub in CAMINHOS:
            novo, k = re.subn(rx, sub, novo)
            n += k
        # O app/ é reescrito noutra frente (P98): lá, e nos testes que leem a
        # tela dele, só os caminhos mudam.
        if not DADO.search(f) and not re.match(r"app/|tests/(app-|gate-)", f):
            novo, k = vocabulario(f, novo)
            n += k
        if novo != texto:
            anotar("texto", f, "", n)
            if not ENSAIO:
                with open(f, "w", encoding="utf-8") as fh:
                    fh.write(novo)
                TOCADOS.add(f)


# ── 4. trocas por padrão (fim deste arquivo) e arquivos novos ───────────────
def ler_trocas():
    blocos, atual, campo = [], None, None
    with open(DADOS, encoding="utf-8") as fh:
        for linha in fh:
            if linha.startswith("⟪arquivo⟫ "):
                atual = {"tipo": "troca", "arquivo": linha.split(" ", 1)[1].strip(), "de": [], "para": []}
                blocos.append(atual); campo = None
            elif linha.startswith("⟪novo⟫ "):
                atual = {"tipo": "novo", "arquivo": linha.split(" ", 1)[1].strip(), "de": [], "para": []}
                blocos.append(atual); campo = "para"
            elif linha.rstrip("\n") == "⟪de⟫":
                campo = "de"
            elif linha.rstrip("\n") == "⟪para⟫":
                campo = "para"
            elif linha.rstrip("\n") == "⟪fim⟫":
                campo = None
            elif atual is not None and campo:
                atual[campo].append(linha)
    return blocos


def trocas():
    falhas = []
    for b in ler_trocas():
        f, de, para = b["arquivo"], "".join(b["de"]), "".join(b["para"])
        if b["tipo"] == "novo":
            escrever(f, para, "criar")
            if not ENSAIO and para.startswith("#!") and os.path.exists(f):
                os.chmod(f, 0o755)
            continue
        if not os.path.isfile(f):
            falhas.append(f"{f}: não existe"); continue
        with open(f, encoding="utf-8") as fh:
            texto = fh.read()
        if para and para in texto:
            continue                                   # já trocado
        n = texto.count(de)
        if n == 1:
            anotar("trocar", f)
            if not ENSAIO:
                with open(f, "w", encoding="utf-8") as fh:
                    fh.write(texto.replace(de, para, 1))
                TOCADOS.add(f)
        else:
            falhas.append(f"{f}: o trecho aparece {n} vez(es)\n---\n{de[:300]}")
    return falhas


def vazias():
    """Pasta vazia sai (fora do .git). No ensaio só conta as que já estão vazias."""
    for raiz, dirs, fs in sorted(os.walk("."), key=lambda x: -x[0].count(os.sep)):
        if raiz == "." or raiz.startswith("./.git"):
            continue
        if not os.listdir(raiz):
            anotar("apagar pasta vazia", raiz[2:])
            if not ENSAIO:
                os.rmdir(raiz)


def main():
    mover(); apagar(); somas(); regras()
    falhas = trocas()
    vazias()
    if falhas:
        print("\n".join(falhas), file=sys.stderr)
        sys.exit(f"{len(falhas)} troca(s) não casaram — nada foi parado pela metade, mas confira")
    if not ENSAIO and (TOCADOS or APAGADOS):
        vivos = sorted(p for p in TOCADOS if os.path.exists(p))
        for i in range(0, len(vivos), 200):
            git("add", "--", *vivos[i:i + 200])
    titulo = f"ENSAIO numa cópia — nada foi escrito em {ORIGINAL}" if RELATO else "APLICADO"
    print(f"reorganizar-1-raiz: {titulo}")
    if not TABELA:
        print("  nada a fazer: a árvore já está reorganizada")
        return
    resumo = {}
    for acao, de, para, n in TABELA:
        print(f"  {acao:<22} {de}" + (f"  ->  {para}" if para else "") + (f"  ({n})" if n != 1 else ""))
        resumo[acao] = resumo.get(acao, 0) + 1
    print("  total: " + ", ".join(f"{k} {v}" for k, v in resumo.items()))


main()
PY
exit $?

# Os dados abaixo nunca rodam: o `exit` acima encerra antes, e o heredoc os
# mantém sintaxe válida para quem lê o arquivo com `bash -n`.
: <<'FIM_DAS_TROCAS'
#__TROCAS__
⟪novo⟫ scripts/terminal_bloco.sh
#!/usr/bin/env bash
# terminal_bloco.sh — o bloco do MeowSystem no arquivo de início do terminal.
#
#   terminal_bloco.sh [aplicar]   escreve ~/.config/meowsystem/terminal.sh e o bloco
#   terminal_bloco.sh --conferir  diz o que mudaria, sem escrever
#   terminal_bloco.sh remover     tira o bloco (o desinstalador chama)
#
# O bloco é uma linha que carrega ~/.config/meowsystem/terminal.sh: o prompt
# (starship), as cores do fzf, o mascote do fastfetch e a completion do `meow`.
# Ele mora entre duas marcas, e só o que está entre elas é do MeowSystem. Um
# arquivo de terminal que outro projeto guarda (vizinhos.conf) não é escrito.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# O seco vale antes do lib/comum.sh, que o lê ao carregar.
[ "${1:-}" = "--conferir" ] && { MEOW_DRY_RUN=1; export MEOW_DRY_RUN; }
. "$MEOW_RAIZ/lib/comum.sh"

ACAO="aplicar"
case "${1:-}" in
  --conferir) ;;
  remover) ACAO="remover" ;;
  ''|aplicar) ;;
  *) meow_erro "uso: terminal_bloco.sh [aplicar|--conferir|remover]"; exit "$MEOW_ERRO" ;;
esac

CARREGADO="${XDG_CONFIG_HOME:-$HOME/.config}/meowsystem/terminal.sh"
MARCA_INICIO="# >>> MeowSystem — o meow põe e tira este bloco >>>"
MARCA_FIM="# <<< MeowSystem <<<"
BLOCO="$MARCA_INICIO
"'[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/meowsystem/terminal.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/meowsystem/terminal.sh"'"
$MARCA_FIM"

# O ZDOTDIR que o zsh desta casa usa, lido do ~/.zshenv como o vizinhos.sh lê.
_zdotdir() {
  local z=""
  if [ -n "${ZDOTDIR:-}" ]; then printf '%s' "$ZDOTDIR"; return 0; fi
  [ -r "$HOME/.zshenv" ] && z="$(sed -n -E 's/^[[:space:]]*(export[[:space:]]+)?ZDOTDIR=["'"'"']?([^"'"'"' ]*).*/\2/p' "$HOME/.zshenv" | head -1)"
  z="${z//\$HOME/$HOME}"; z="${z//\$\{HOME\}/$HOME}"; z="${z/#\~/$HOME}"
  printf '%s' "${z:-$HOME}"
}

# Os arquivos de início que existem, e o do shell de login mesmo que ainda não exista.
_alvos() {
  local z; z="$(_zdotdir)/.zshrc"
  { [ -f "$HOME/.bashrc" ] || [ "${SHELL##*/}" = "bash" ]; } && printf '%s\n' "$HOME/.bashrc"
  { [ -f "$z" ] || [ "${SHELL##*/}" = "zsh" ]; } && printf '%s\n' "$z"
  return 0
}

_texto_carregado() {
  cat <<'SH'
# Gerado pelo MeowSystem (scripts/terminal_bloco.sh); a próxima passada o refaz.
case $- in *i*) ;; *) return 0 ;; esac
if [ -n "${ZSH_VERSION:-}" ]; then
  # A completion do `meow`, mesmo com o compinit já rodado.
  fpath=("${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions" $fpath)
  if (( $+functions[compdef] )); then autoload -Uz _meow 2>/dev/null && compdef _meow meow; fi
fi
[ -r "$HOME/.config/meowsystem/fzf.sh" ] && . "$HOME/.config/meowsystem/fzf.sh"
if command -v starship >/dev/null 2>&1; then
  if [ -n "${ZSH_VERSION:-}" ]; then eval "$(starship init zsh)"
  elif [ -n "${BASH_VERSION:-}" ]; then eval "$(starship init bash)"; fi
fi
# O mascote ao abrir o terminal, com os rótulos traduzidos na cor `peach` do pack.
if [ -z "${TMUX:-}" ] && command -v fastfetch >/dev/null 2>&1; then
  printf '\033c'
  _ff=fastfetch
  command -v meow-fetch >/dev/null 2>&1 && _ff=meow-fetch
  _lj="" _lz=""
  [ -n "${MEOW_SGR_LARANJA:-}" ] && _lj="$(printf '\033[%sm' "$MEOW_SGR_LARANJA")" && _lz="$(printf '\033[0m')"
  "$_ff" --pipe false | sed -E "
      s/\\[Discrete\\]/${_lj}(Dedicada)${_lz}/g;
      s/\\[Integrated\\]/${_lj}(Integrada)${_lz}/g;
      s/\\[AC Connected\\]/${_lj}(Conectado)${_lz}/g;
      s/\\[AC Disconnected\\]/${_lj}(Desconectado)${_lz}/g;
      s/\\[External\\]/${_lj}(Externo)${_lz}/g;
      s/\\[Built-in\\]/${_lj}(Embutido)${_lz}/g;
      s/\\[([^][\\x1b]+)\\]/${_lj}(\\1)${_lz}/g
  "
  unset _ff _lj _lz
  echo
fi
SH
}

# O arquivo sem o bloco (as marcas e o que há entre elas). As linhas em branco
# do fim caem na substituição de comando de quem chama.
_sem_bloco() {
  awk -v i="$MARCA_INICIO" -v f="$MARCA_FIM" '
    $0 == i { dentro = 1; next }
    dentro && $0 == f { dentro = 0; next }
    !dentro' "$1"
}

rc=0
_marcar() { [ "$1" = "$MEOW_ERRO" ] && rc="$MEOW_ERRO"; [ "$1" = "$MEOW_DIVERGENTE" ] && [ "$rc" = 0 ] && rc="$MEOW_DIVERGENTE"; }

if [ "$ACAO" = "remover" ]; then
  while IFS= read -r alvo; do
    [ -f "$alvo" ] && grep -qxF -- "$MARCA_INICIO" "$alvo" || continue
    meow_destino_permitido "$alvo" 2>/dev/null || continue
    meow_escrever "$alvo" "$(_sem_bloco "$alvo")" "$(stat -c %a "$alvo" 2>/dev/null || echo 644)"; _marcar $?
    meow_seco || meow_muda "bloco do MeowSystem tirado de $alvo"
  done < <(_alvos)
  if [ -f "$CARREGADO" ]; then
    if meow_seco; then meow_muda "removeria $CARREGADO"; else rm -f "$CARREGADO"; fi
    _marcar "$MEOW_DIVERGENTE"
  fi
  [ "$rc" = 0 ] && meow_ok "nenhum bloco do MeowSystem no terminal"
  exit "$rc"
fi

meow_escrever "$CARREGADO" "$(_texto_carregado)" 644; _marcar $?
postos=() guardados=()
while IFS= read -r alvo; do
  if ! meow_destino_permitido "$alvo" 2>/dev/null; then
    guardados+=("$alvo"); continue
  fi
  base=""
  [ -f "$alvo" ] && base="$(_sem_bloco "$alvo")"
  if [ -n "$base" ]; then novo="$base

$BLOCO"; else novo="$BLOCO"; fi
  meow_escrever "$alvo" "$novo" "$(stat -c %a "$alvo" 2>/dev/null || echo 644)"; _marcar $?
  postos+=("$alvo")
done < <(_alvos)

if [ "${#guardados[@]}" -gt 0 ]; then
  meow_pula "$(printf '%s ' "${guardados[@]}")é de outro projeto (vizinhos.conf) — o bloco fica com ele"
fi
case "$rc" in
  0) meow_ok "bloco do terminal no lugar (${postos[*]:-nenhum arquivo})" ;;
  1) meow_seco || meow_muda "bloco do terminal escrito em ${postos[*]}" ;;
esac
exit "$rc"
⟪fim⟫
⟪arquivo⟫ .gitignore
⟪de⟫
# Upstreams baixados: Papirus, cosmic-icons, wallpapers da comunidade. São grandes
# e reproduzíveis — o repo guarda o script que baixa, com commit pinado, não o conteúdo.
assets/icones/upstream/
packs/meowsystem/wallpapers/baixados/
# O tarball da Nerd Font tem 6,4 MB; a receita (versão pinada + os SHA-256 de
# cada face) está em scripts/instalar_fontes.sh, que é o que importa versionar.
assets/fontes/upstream/

# As fontes que ela solta em `assets/fontes/locais/` — o BINÁRIO fica de fora, o
⟪para⟫
# Upstreams baixados (papirus-folders, o tarball da Nerd Font) moram em
# ~/.cache/meowsystem, fora do repositório; o repo guarda o script que baixa.
packs/meowsystem/wallpapers/baixados/

# As fontes que ela solta em `assets/fontes/locais/` — o BINÁRIO fica de fora, o
⟪fim⟫
⟪arquivo⟫ .gitignore
⟪de⟫
packs/meowsystem/wallpapers/lado.tsv

# O ÚNICO ACERVO COM LICENÇA NÃO DECLARADA — 06/09/2026
#   `Daveedmee/catppuccin-icons` não diz sob que licença está, e desde que o
#   repositório é público isso deixou de ser uma nota de cuidado: republicar o
#   que não se pode republicar é o erro que não dá para desfazer, porque o
#   histórico fica. Ele já estava fora do git, mas por acidente — os 292
#   arquivos são PNG, e o `*.png` acima os pegava. Um SVG dali entraria sem
#   nada avisar. Agora a exclusão é pelo NOME.
#   O instalador não perde nada: o que ele usa daqui é gerado na máquina.
#   Ver assets/icones/PROCEDENCIA.md.
assets/icones/catppuccin-apps/

# Symlink local para diretrizes (não vai pro repo)
CLAUDE.md
⟪para⟫
packs/meowsystem/wallpapers/lado.tsv

# Symlink local para diretrizes (não vai pro repo)
CLAUDE.md
⟪fim⟫
⟪arquivo⟫ AGENTS.md
⟪de⟫
| `bin/meow` | a CLI: `doctor`, `pack`, `icones`, `compositor`, o menu |
| `lib/` | funções comuns (`comum.sh`: log, códigos de saída, travas) |
| `scripts/` | uma etapa por arquivo; `pack.py` resolve o pack e o acervo |
| `app/` | o painel local: `servidor.py` e `pagina/` (HTML, JS, CSS) |
| `packs/` | os theme packs: só dados (JSON, SVG, mapas), nunca código |
| `assets/` | o acervo do motor que os packs herdam |
| `patches/` | a série de patches do `cosmic-comp` (`series`, `versao`) |
| `src/` | applets e o oráculo em Rust |
⟪para⟫
| `bin/meow` | a CLI: `doctor`, `pack`, `icones`, `compositor`, o menu |
| `lib/` | funções comuns (`comum.sh`: log, códigos de saída, travas) |
| `scripts/` | uma etapa por arquivo; `pack.py` resolve o pack e o acervo; `temas-de-apps/` é o código de cada app |
| `app/` | o painel local: `servidor.py` e `pagina/` (HTML, JS, CSS) |
| `packs/` | os theme packs, só dados: `icones/`, `mascote/`, `wallpapers/`, `temas-de-apps/`, `sons/`, `temas/` |
| `assets/` | o que o programa usa em todo pack: modelos que a paleta preenche, mapas de app, `contratos/` |
| `patches/` | a série de patches do `cosmic-comp` (`series`, `versao`) |
| `src/` | applets e o oráculo em Rust |
⟪fim⟫
⟪arquivo⟫ AGENTS.md
⟪de⟫

- `docs/sprints/` e `docs/historico/`: registro de trabalho, longo. Leia só o arquivo citado.
- `docs/pesquisas/`: pesquisa bruta.
- `docs/SPRINTS.md`: o diário das sprints.
- `.playwright-mcp/`, `packs/*/icones/` (milhares de SVG), `docs/capturas/`, `docs/folhas/`.
⟪para⟫

- `docs/sprints/` e `docs/historico/`: registro de trabalho, longo. Leia só o arquivo citado.
- `docs/SPRINTS.md`: o diário das sprints.
- `packs/*/icones/` (milhares de SVG), `docs/capturas/`.
⟪fim⟫
⟪arquivo⟫ README.en.md
⟪de⟫

```bash
git clone https://github.com/vitoriamariadb/MeowSystem.git
cd MeowSystem
./install.sh --wizard     # first run: asks five questions, then installs
⟪para⟫

```bash
git clone https://github.com/AndreBFarias/MeowSystem.git
cd MeowSystem
./install.sh --wizard     # first run: asks five questions, then installs
⟪fim⟫
⟪arquivo⟫ README.md
⟪de⟫

```bash
git clone https://github.com/vitoriamariadb/MeowSystem.git
cd MeowSystem
./install.sh --wizard     # a primeira vez: pergunta cinco coisas e instala
⟪para⟫

```bash
git clone https://github.com/AndreBFarias/MeowSystem.git
cd MeowSystem
./install.sh --wizard     # a primeira vez: pergunta cinco coisas e instala
⟪fim⟫
⟪arquivo⟫ app/servidor.py
⟪de⟫
PAGINA = os.path.join(RAIZ, "app", "pagina")
# O mapa dos jogos que ficam fora do lançador.
MAPA_JOGOS = os.path.join(RAIZ, "assets", "icones", "jogos-fora.map")
ICONES_DO_MOTOR = os.path.join(RAIZ, "packs", "meowsystem", "icones")
CONF_PADRAO = os.environ.get("MEOW_CONF_PADRAO") or os.path.join(RAIZ, "meow.conf.exemplo")
⟪para⟫
PAGINA = os.path.join(RAIZ, "app", "pagina")
# O mapa dos jogos que ficam fora do lançador.
MAPA_JOGOS = os.path.join(RAIZ, "assets", "apps", "jogos-fora.map")
ICONES_DO_MOTOR = os.path.join(RAIZ, "packs", "meowsystem", "icones")
CONF_PADRAO = os.environ.get("MEOW_CONF_PADRAO") or os.path.join(RAIZ, "meow.conf.exemplo")
⟪fim⟫
⟪arquivo⟫ app/servidor.py
⟪de⟫
# atropelar as vizinhas.
FONTES_DO_DISCO = (
    (re.compile(r"packs/meowsystem/mascote/"), "gatos", False),
    (re.compile(r"[íi]cones?\b", re.I), "temas_icones", True),
    (re.compile(r"ponteiro|cursor", re.I), "cursores", True),
⟪para⟫
# atropelar as vizinhas.
FONTES_DO_DISCO = (
    (re.compile(r"packs/\w+/mascote/"), "gatos", False),
    (re.compile(r"[íi]cones?\b", re.I), "temas_icones", True),
    (re.compile(r"ponteiro|cursor", re.I), "cursores", True),
⟪fim⟫
⟪arquivo⟫ app/servidor.py
⟪de⟫
# página oferece é o que aquele script vai achar.
_PAPIRUS_FOLDERS = os.environ.get("MEOW_CAT_FOLDERS") or os.path.join(
    RAIZ, "assets", "icones", "upstream", "papirus-folders")
_RE_COR_DE_PASTA = re.compile(r"^folder-cat-([a-z0-9]+)-([a-z0-9]+)-documents\.svg$")

⟪para⟫
# página oferece é o que aquele script vai achar.
_PAPIRUS_FOLDERS = os.environ.get("MEOW_CAT_FOLDERS") or os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
    "meowsystem", "upstream", "papirus-folders")
_RE_COR_DE_PASTA = re.compile(r"^folder-cat-([a-z0-9]+)-([a-z0-9]+)-documents\.svg$")

⟪fim⟫
⟪arquivo⟫ app/servidor.py
⟪de⟫

# --- 3. os valores dela ------------------------------------------------------
def _gatos():
    """O acervo `packs/meowsystem/mascote/`, que é a configuração — soltou um .svg, entrou."""
    pasta = os.path.join(RAIZ, "assets", "gatos")
    try:
        nomes = sorted(
⟪para⟫

# --- 3. os valores dela ------------------------------------------------------
def _pasta_do_mascote():
    """A pasta `mascote/` do pack no ar (pela herança), ou a do pack-base."""
    mod = modulo_pack()
    if mod and hasattr(mod, "pasta_do_mascote"):
        return mod.pasta_do_mascote(_pack_adotado() or None)
    return os.path.join(RAIZ, "packs", "meowsystem", "mascote")


def _gatos():
    """O acervo `mascote/` do pack no ar, que é a configuração — soltou um .svg, entrou."""
    pasta = _pasta_do_mascote()
    try:
        nomes = sorted(
⟪fim⟫
⟪arquivo⟫ app/servidor.py
⟪de⟫
# --- os provedores: cada um lista o que existe NO DISCO agora ----------------
def _prev_gatos():
    pasta = os.path.join(RAIZ, "assets", "gatos")
    fora = []
    for nome in _gatos():
⟪para⟫
# --- os provedores: cada um lista o que existe NO DISCO agora ----------------
def _prev_gatos():
    pasta = _pasta_do_mascote()
    fora = []
    for nome in _gatos():
⟪fim⟫
⟪arquivo⟫ app/servidor.py
⟪de⟫
    if os.path.isdir(estado):
        return os.path.join(estado, "lado.tsv")
    return os.path.join(RAIZ, "assets", "papeis-de-parede", "lado.tsv.padrao")


⟪para⟫
    if os.path.isdir(estado):
        return os.path.join(estado, "lado.tsv")
    return os.path.join(RAIZ, "packs", "meowsystem", "wallpapers", "lado.tsv.padrao")


⟪fim⟫
⟪arquivo⟫ app/servidor.py
⟪de⟫
    if not re.match(r"^[a-z0-9][a-z0-9-]*$", app):
        return ""
    modulo = os.path.join(RAIZ, "assets", "temas-de-apps", app, "manifesto.sh")
    return app if os.path.isfile(modulo) else ""

⟪para⟫
    if not re.match(r"^[a-z0-9][a-z0-9-]*$", app):
        return ""
    modulo = os.path.join(RAIZ, "scripts", "temas-de-apps", app, "manifesto.sh")
    return app if os.path.isfile(modulo) else ""

⟪fim⟫
⟪arquivo⟫ app/servidor.py
⟪de⟫
                return self._recusar(403, "token de sessão ausente ou errado")
            nome = os.path.basename(valores_efetivos(["LOGO"]).get("LOGO") or "coquinha")
            arquivo = os.path.join(RAIZ, "assets", "gatos", nome + ".svg")
            if not os.path.isfile(arquivo):
                gatos = _gatos()
                if not gatos:
                    return self._recusar(404, "não há gato no acervo")
                arquivo = os.path.join(RAIZ, "assets", "gatos", gatos[0] + ".svg")
            with open(arquivo, "rb") as fh:
                return self._responder(fh.read(), tipo=TIPOS[".svg"])
⟪para⟫
                return self._recusar(403, "token de sessão ausente ou errado")
            nome = os.path.basename(valores_efetivos(["LOGO"]).get("LOGO") or "coquinha")
            arquivo = os.path.join(_pasta_do_mascote(), nome + ".svg")
            if not os.path.isfile(arquivo):
                gatos = _gatos()
                if not gatos:
                    return self._recusar(404, "não há gato no acervo")
                arquivo = os.path.join(_pasta_do_mascote(), gatos[0] + ".svg")
            with open(arquivo, "rb") as fh:
                return self._responder(fh.read(), tipo=TIPOS[".svg"])
⟪fim⟫
⟪arquivo⟫ app/servidor.py
⟪de⟫
    ACERVOS = {
        "gato": {
            "pasta": ("assets", "gatos"),
            "extensoes": (".svg",),
            "normaliza": True,
⟪para⟫
    ACERVOS = {
        "gato": {
            "casa": "pasta_do_mascote",
            "extensoes": (".svg",),
            "normaliza": True,
⟪fim⟫
⟪arquivo⟫ app/servidor.py
⟪de⟫
        },
        "parede": {
            "pasta": ("assets", "papeis-de-parede", "ativos"),
            "extensoes": (".jpg", ".jpeg", ".png", ".webp"),
            "normaliza": False,
⟪para⟫
        },
        "parede": {
            "pasta": ("packs", "meowsystem", "wallpapers", "ativos"),
            "extensoes": (".jpg", ".jpeg", ".png", ".webp"),
            "normaliza": False,
⟪fim⟫
⟪arquivo⟫ assets/contratos/vizinhos.tsv
⟪de⟫
item	dracula-spicetify	saida	$DESENV/Dracula_OS-Theme/scripts/instalar_spicetify.sh	-	-	-	o Spicetify e o tema do Spotify são do MeowSystem; as extensões seguem no spicetify_reparar
item	caches-icones-casa	bloco	$ZD/functions/sistema.zsh	for tema_dir in "$HOME/.local/share/icons/"*/; do	^    done$	scripts/hicolor.sh:_hicolor_cache_velha	a cache dos temas de ícones da casa é do MeowSystem (índice do tema e hicolor, conferidos pelo meow doctor)

# As cópias que o aplicar_overrides.sh do Dracula_OS-Theme pôs no lançador do home.
⟪para⟫
item	dracula-spicetify	saida	$DESENV/Dracula_OS-Theme/scripts/instalar_spicetify.sh	-	-	-	o Spicetify e o tema do Spotify são do MeowSystem; as extensões seguem no spicetify_reparar
item	caches-icones-casa	bloco	$ZD/functions/sistema.zsh	for tema_dir in "$HOME/.local/share/icons/"*/; do	^    done$	scripts/hicolor.sh:_hicolor_cache_velha	a cache dos temas de ícones da casa é do MeowSystem (índice do tema e hicolor, conferidos pelo meow doctor)

# O terminal: o MeowSystem escreve o bloco dele (scripts/terminal_bloco.sh) com o
# prompt, as cores do fzf e o mascote do fastfetch; o equivalente do Spellbook sai.
item	spellbook-terminal-fastfetch	bloco	$ZD/env.zsh	    if command -v fastfetch >/dev/null 2>&1; then	^    fi$	scripts/terminal_bloco.sh:# >>> MeowSystem	o mascote do fastfetch ao abrir o terminal é do bloco do MeowSystem
item	spellbook-terminal-starship	bloco	$ZD/env.zsh	if command -v starship >/dev/null 2>&1; then	^fi$	scripts/terminal_bloco.sh:# >>> MeowSystem	o prompt do starship é ligado pelo bloco do MeowSystem
item	spellbook-terminal-fzf	bloco	$ZD/env.zsh	# A paleta do fzf, para TODO fzf	^\[ -r "\$HOME/\.config/meowsystem/fzf\.sh" \] && \. 	scripts/terminal_bloco.sh:# >>> MeowSystem	as cores do fzf são carregadas pelo bloco do MeowSystem

# As cópias que o aplicar_overrides.sh do Dracula_OS-Theme pôs no lançador do home.
⟪fim⟫
⟪arquivo⟫ assets/zsh/_meow
⟪de⟫
  local f
  # O acervo dela é a lista — os mascotes do projeto foram excluídos em 08/08/2026.
  for f in "$raiz"/packs/meowsystem/mascote/*.svg(N); do
    f="${f:t:r}"
    [[ "$f" == *-symbolic ]] && continue
⟪para⟫
  local f
  # O acervo dela é a lista — os mascotes do projeto foram excluídos em 08/08/2026.
  for f in "$raiz"/packs/*/mascote/*.svg(N); do
    f="${f:t:r}"
    [[ "$f" == *-symbolic ]] && continue
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
logos_disponiveis() {
  local f n
  for f in "$RAIZ"/packs/meowsystem/mascote/*.svg; do
    [ -f "$f" ] || continue
    n="$(basename "$f" .svg)"
⟪para⟫
logos_disponiveis() {
  local f n
  for f in "$(meow_mascote_dir)"/*.svg; do
    [ -f "$f" ] || continue
    n="$(basename "$f" .svg)"
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
# inteira está no `scripts/wallpaper.sh`, no `FONTES_PERMITIDAS`.
chk_wallpaper() {
  MEOW_DRY_RUN=1 WALLPAPER_BASE="${WALLPAPER_BASE:-}" WALLPAPER_INTERVALO="${WALLPAPER_INTERVALO:-5m}" \
    WALLPAPER_ORDEM="${WALLPAPER_ORDEM:-aleatoria}" \
    WALLPAPER_FONTES_PERMITIDAS="${WALLPAPER_FONTES_PERMITIDAS-${WALLPAPER_FONTES_DELA:-}}" \
⟪para⟫
# inteira está no `scripts/wallpaper.sh`, no `FONTES_PERMITIDAS`.
chk_wallpaper() {
  local semeia rc_s saida rc
  semeia="$(MEOW_DRY_RUN=1 "$RAIZ/scripts/wallpaper.sh" semear-se-faltar 2>&1)"; rc_s=$?
  saida="$(MEOW_DRY_RUN=1 WALLPAPER_BASE="${WALLPAPER_BASE:-}" WALLPAPER_INTERVALO="${WALLPAPER_INTERVALO:-5m}" \
    WALLPAPER_ORDEM="${WALLPAPER_ORDEM:-aleatoria}" \
    WALLPAPER_FONTES_PERMITIDAS="${WALLPAPER_FONTES_PERMITIDAS-${WALLPAPER_FONTES_DELA:-}}" \
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
    WALLPAPER_NOITE="${WALLPAPER_NOITE:-}" WALLPAPER_NOITE_INICIO="${WALLPAPER_NOITE_INICIO:-}" \
    WALLPAPER_NOITE_FIM="${WALLPAPER_NOITE_FIM:-}" WALLPAPER_LIMIAR_LUZ="${WALLPAPER_LIMIAR_LUZ:-}" \
    "$RAIZ/scripts/wallpaper.sh" aplicar 2>&1
}

⟪para⟫
    WALLPAPER_NOITE="${WALLPAPER_NOITE:-}" WALLPAPER_NOITE_INICIO="${WALLPAPER_NOITE_INICIO:-}" \
    WALLPAPER_NOITE_FIM="${WALLPAPER_NOITE_FIM:-}" WALLPAPER_LIMIAR_LUZ="${WALLPAPER_LIMIAR_LUZ:-}" \
    "$RAIZ/scripts/wallpaper.sh" aplicar 2>&1)"; rc=$?
  # A semeadura que falta vem primeiro só quando o carrossel não tem outra divergência.
  if [ "$rc_s" = "$MEOW_DIVERGENTE" ] && [ "$rc" != "$MEOW_DIVERGENTE" ]; then
    printf '%s\n%s\n' "$semeia" "$saida"; return "$MEOW_DIVERGENTE"
  fi
  printf '%s\n' "$saida"
  [ "$rc_s" = "$MEOW_DIVERGENTE" ] && printf '%s\n' "$semeia"
  return "$rc"
}

⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
}

# O PNG do lançador NÃO TINHA VERIFICADOR NENHUM — `chk_apps` é o
# `aplicar_apps.sh`, que é outra coisa (tema DENTRO do aplicativo). Se um dos 16
# ícones do acervo Catppuccin sumisse ou divergisse, nada acusava.
chk_iconesapps() {
  ICONES_FLAVOR="${ICONES_FLAVOR:-}" \
    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$RAIZ/scripts/icones_apps.sh" --conferir 2>&1
}

# OS RESGATADOS PRECISAM DE VERIFICADOR PELA MESMA RAZÃO QUE O `chk_iconesapps`
# precisava: eles são vinte arquivos em `scalable/apps` que NINGUÉM MAIS
# escreve, e um `meow icones reconstruir` que apagasse o diretório os levaria
# junto, sem nada acusando.
⟪para⟫
}

# OS RESGATADOS PRECISAM DE VERIFICADOR: eles são vinte arquivos em `scalable/apps` que NINGUÉM MAIS
# escreve, e um `meow icones reconstruir` que apagasse o diretório os levaria
# junto, sem nada acusando.
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
  meow_tem python3 || { echo "python3 não está aqui — nada a conferir"; return 0; }
  local pastas=() p
  for p in packs/meowsystem/mascote/ packs/meowsystem/icones/sistema/leitura assets/icones/overrides; do
    [ -d "$RAIZ/$p" ] && pastas+=("$RAIZ/$p")
  done
⟪para⟫
  meow_tem python3 || { echo "python3 não está aqui — nada a conferir"; return 0; }
  local pastas=() p
  for p in packs/meowsystem/mascote/ packs/dracula/mascote/ packs/meowsystem/icones/sistema/leitura assets/icones/overrides; do
    [ -d "$RAIZ/$p" ] && pastas+=("$RAIZ/$p")
  done
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
# Outro programa que escreve sozinho onde o MeowSystem escreve. Só mostra: desligar
# o de fora é decisão dela (4), e a duplicata já revisada não volta a aparecer.
chk_vizinhos() {
  local rc
⟪para⟫
# Outro programa que escreve sozinho onde o MeowSystem escreve. Só mostra: desligar
# o de fora é decisão dela (4), e a duplicata já revisada não volta a aparecer.
chk_bloco() { "$RAIZ/scripts/terminal_bloco.sh" --conferir 2>&1; }
fix_bloco() { "$RAIZ/scripts/terminal_bloco.sh" aplicar 2>&1; }

chk_vizinhos() {
  local rc
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
  [ -d /usr/share/fonts/opentype/fira ] || ! apt-cache show pop-fonts >/dev/null 2>&1 \
    || faltam+=(pop-fonts)
  [ "${#faltam[@]}" -eq 0 ] || printf '%s\n' "${faltam[@]}"
  return 0
⟪para⟫
  [ -d /usr/share/fonts/opentype/fira ] || ! apt-cache show pop-fonts >/dev/null 2>&1 \
    || faltam+=(pop-fonts)
  # Os mesmos do compilar dos applets do `etapa_pacotes` (lista no lib/comum.sh).
  local prova pacote
  if [ "${MIDIA:-sim}" = "sim" ] || [ "${LEITURA_APPLET:-sim}" = "sim" ]; then
    while IFS='|' read -r prova pacote; do
      [ -e "$prova" ] || faltam+=("$pacote")
    done <<< "$MEOW_DEPS_DOS_APPLETS"
  fi
  [ "${#faltam[@]}" -eq 0 ] || printf '%s\n' "${faltam[@]}"
  return 0
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
                    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
                    "$RAIZ/scripts/construir_pastas.sh" 2>&1; }
fix_wallpaper() { WALLPAPER_BASE="${WALLPAPER_BASE:-}" WALLPAPER_INTERVALO="${WALLPAPER_INTERVALO:-5m}" \
                    WALLPAPER_ORDEM="${WALLPAPER_ORDEM:-aleatoria}" \
                    WALLPAPER_FONTES_PERMITIDAS="${WALLPAPER_FONTES_PERMITIDAS-${WALLPAPER_FONTES_DELA:-}}" \
⟪para⟫
                    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
                    "$RAIZ/scripts/construir_pastas.sh" 2>&1; }
fix_wallpaper() { "$RAIZ/scripts/wallpaper.sh" semear-se-faltar 2>&1
                  WALLPAPER_BASE="${WALLPAPER_BASE:-}" WALLPAPER_INTERVALO="${WALLPAPER_INTERVALO:-5m}" \
                    WALLPAPER_ORDEM="${WALLPAPER_ORDEM:-aleatoria}" \
                    WALLPAPER_FONTES_PERMITIDAS="${WALLPAPER_FONTES_PERMITIDAS-${WALLPAPER_FONTES_DELA:-}}" \
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
                    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
                    "$RAIZ/scripts/icones_apps_arcticons.sh" --aplicar 2>&1; }
fix_iconesapps(){ ICONES_FLAVOR="${ICONES_FLAVOR:-}" \
                    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
                    "$RAIZ/scripts/icones_apps.sh" --aplicar 2>&1; }
# Os desenhos dela que só existiam em PNG, agora em vetor. `ICONES_RESGATADOS`
# vai junto porque é ele que decide entre instalar e RETIRAR: sem a chave no
⟪para⟫
                    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
                    "$RAIZ/scripts/icones_apps_arcticons.sh" --aplicar 2>&1; }
# Os desenhos dela que só existiam em PNG, agora em vetor. `ICONES_RESGATADOS`
# vai junto porque é ele que decide entre instalar e RETIRAR: sem a chave no
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
fix_svg()       { local pastas=() p
                  meow_tem python3 || return 0
                  for p in packs/meowsystem/mascote/ packs/meowsystem/icones/sistema/leitura assets/icones/overrides; do
                    [ -d "$RAIZ/$p" ] && pastas+=("$RAIZ/$p")
                  done
⟪para⟫
fix_svg()       { local pastas=() p
                  meow_tem python3 || return 0
                  for p in packs/meowsystem/mascote/ packs/dracula/mascote/ packs/meowsystem/icones/sistema/leitura assets/icones/overrides; do
                    [ -d "$RAIZ/$p" ] && pastas+=("$RAIZ/$p")
                  done
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
#   dependência" que ela mesma tinha acabado de instalar. Logo depois da
#   ponte, que é por onde o `pacotes` passa.
VERIFICAVEIS=(conf ponte pacotes upstream gerar tema modo vidro forma painel janelas patches relogio leitura leiturabin greeter cursor flatpaktema flatpakglobal prompt fzf terminal som fastfetch files_menu icones completar hicolor mimetypes iconesapps resgatados arcticons dracula convertidos sistema bandeja traysteam trayzapzap jogos jogosheroic ocultar absolutos nomes ocultarcasa janeladock lancadorapt pastasxdg pastas wallpaper fundo onlyoffice libreoffice apps heroictema midiabin midia assets svg flatpak steamvigia heroicvigia qtvigia derivados autostart atalho lancador autoreparo cli escala fontes vizinhos logo indice)
# A PONTE MOVE TRÊS ITENS DAQUI — 08/09/2026
#   `ocultar`, `absolutos` e `lancadorapt` recusavam conserto pela MESMA razão:
⟪para⟫
#   dependência" que ela mesma tinha acabado de instalar. Logo depois da
#   ponte, que é por onde o `pacotes` passa.
VERIFICAVEIS=(conf ponte pacotes upstream gerar tema modo vidro forma painel janelas patches relogio leitura leiturabin greeter cursor flatpaktema flatpakglobal prompt fzf terminal som fastfetch bloco files_menu icones completar hicolor mimetypes resgatados arcticons dracula convertidos sistema bandeja traysteam trayzapzap jogos jogosheroic ocultar absolutos nomes ocultarcasa janeladock lancadorapt pastasxdg pastas wallpaper fundo onlyoffice libreoffice apps heroictema midiabin midia assets svg flatpak steamvigia heroicvigia qtvigia derivados autostart atalho lancador autoreparo cli escala fontes vizinhos logo indice)
# A PONTE MOVE TRÊS ITENS DAQUI — 08/09/2026
#   `ocultar`, `absolutos` e `lancadorapt` recusavam conserto pela MESMA razão:
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
    # A chave do applet INSTALADO, pelo `logo.sh applet` (revisão da P57).
    campo "arquivo" "$(MEOW_DRY_RUN=1 "$RAIZ/scripts/logo.sh" applet 2>/dev/null || printf '(nenhuma)')"
    printf '\n  %sgatos do acervo (packs/meowsystem/mascote/)%s\n' "$C_DIM" "$C_ZERO"
    logos_disponiveis | sed 's/^/    /'
    printf '\n  %ssolte um .svg em packs/meowsystem/mascote/ e ele entra na hora — a pasta é a lista%s\n' \
           "$C_DIM" "$C_ZERO"
    printf '  %smeow logo listar diz qual mascote está no ar, e POR QUÊ (a fase e a janela)%s\n' "$C_DIM" "$C_ZERO"
    printf '  %sno modo hora quem manda é o relógio: LOGO_DIA / LOGO_NOITE no meow.conf%s\n\n' "$C_DIM" "$C_ZERO"
⟪para⟫
    # A chave do applet INSTALADO, pelo `logo.sh applet` (revisão da P57).
    campo "arquivo" "$(MEOW_DRY_RUN=1 "$RAIZ/scripts/logo.sh" applet 2>/dev/null || printf '(nenhuma)')"
    printf '\n  %smascotes do pack (%s)%s\n' "$C_DIM" "$(meow_mascote_dir)" "$C_ZERO"
    logos_disponiveis | sed 's/^/    /'
    printf '\n  %ssolte um .svg em %s e ele entra na hora — a pasta é a lista%s\n' \
           "$C_DIM" "$(meow_mascote_dir)" "$C_ZERO"
    printf '  %smeow logo listar diz qual mascote está no ar, e POR QUÊ (a fase e a janela)%s\n' "$C_DIM" "$C_ZERO"
    printf '  %sno modo hora quem manda é o relógio: LOGO_DIA / LOGO_NOITE no meow.conf%s\n\n' "$C_DIM" "$C_ZERO"
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
  local disponiveis; disponiveis="$(logos_disponiveis)"
  if ! grep -qx -- "$arg" <<< "$disponiveis"; then
    meow_erro "não existe o mascote '$arg' em packs/meowsystem/mascote/"
    meow_info "disponíveis: $(logos_disponiveis | em_linha)"
    return "$MEOW_SEM_DEPENDENCIA"
⟪para⟫
  local disponiveis; disponiveis="$(logos_disponiveis)"
  if ! grep -qx -- "$arg" <<< "$disponiveis"; then
    meow_erro "não existe o mascote '$arg' em $(meow_mascote_dir)"
    meow_info "disponíveis: $(logos_disponiveis | em_linha)"
    return "$MEOW_SEM_DEPENDENCIA"
⟪fim⟫
⟪arquivo⟫ bin/meow
⟪de⟫
  meow wallpaper banir <img>   move para banidos/ (nunca apaga)
  meow wallpaper desbanir <nome>  devolve de banidos/ para ativos/ E tira do BANIDOS.txt
  meow wallpaper semear        baixa a coleção Catppuccin (commit pinado; usa rede)

  meow apps                    tabela: módulo, instalado, tema
⟪para⟫
  meow wallpaper banir <img>   move para banidos/ (nunca apaga)
  meow wallpaper desbanir <nome>  devolve de banidos/ para ativos/ E tira do BANIDOS.txt
  meow wallpaper semear        baixa a coleção do pack no ar (commit pinado; usa rede)

  meow apps                    tabela: módulo, instalado, tema
⟪fim⟫
⟪arquivo⟫ docs/CREDITOS.md
⟪de⟫
Os **52 desenhos autorais** de `assets/icones/autorais/` e os **19 retoques à
mão** de `packs/meowsystem/icones/apps/convertidos/retoques/` são deste projeto, no dialeto
do Arcticons mas sem copiar traço nenhum dele. A folha que descreve o dialeto está
em [`docs/folhas/`](folhas/).

## Os papéis de parede
⟪para⟫
Os **52 desenhos autorais** de `assets/icones/autorais/` e os **19 retoques à
mão** de `packs/meowsystem/icones/apps/convertidos/retoques/` são deste projeto, no dialeto
do Arcticons mas sem copiar traço nenhum dele. A folha que descrevia o dialeto
saiu do repositório em 23/10/2026; o git a guarda.

## Os papéis de parede
⟪fim⟫
⟪arquivo⟫ docs/PACKS.md
⟪de⟫
| fica em `assets/` | por quê |
|---|---|
| `gatos/` | a marca MeowSystem. O seu pack pode trazer os dele; estes são os de casa |
| `icones/appid.map`, `apps-nomes.map`, `jogos-fora.map` | identidade técnica de aplicativo e decisão da máquina. Não é gosto, é fato |
| `icones/previa-arcticons/` | a prévia que as folhas de proposta comparam (os mesmos bytes de desenhos que já estão no pack-base) |
| `icones/tray-terceiros/` | os originais de fábrica da bandeja da Steam e do ZapZap, para desfazer |
| `icones/resgatados-antes-e-depois.png` | a folha que prova os resgates (`meow icones resgatados folha`) |

---
⟪para⟫
| fica em `assets/` | por quê |
|---|---|
| `apps/appid.map`, `apps-nomes.map`, `wmclass.map`, `jogos-fora.map` | identidade técnica de aplicativo e decisão da máquina. Não é gosto, é fato |
| `apps/tray-terceiros/` | os originais de fábrica da bandeja da Steam e do ZapZap, para desfazer |
| `prompt/`, `fastfetch/`, `paleta/cosmic-map.json` | modelos que a paleta do pack no ar preenche: servem a todo pack |
| `contratos/` | o que o programa sabe do COSMIC e dos vizinhos |

O mascote mora no pack (`mascote/`, com `mascote.dia` e `mascote.noite` no
`pack.json`), como os papéis de parede (`wallpapers/` e `origens.wallpapers`) e
os temas de aplicativo (`temas-de-apps/<app>/`). O código de cada aplicativo é
do programa: `scripts/temas-de-apps/<app>/`.

---
⟪fim⟫
⟪arquivo⟫ docs/sprints/2026-10-09-uso-real/02-decisoes.md
⟪de⟫
| 17 | Repositório enxuto e legível para IA, apesar da regra anti-evidência | **Sim; `AGENTS.md` é exceção do sanitizador (15/10: «AGENTS.md são exceção, pode subir eles»)** («IA-friendly mesmo que tenhamos a regra original de anti-evidência de IA»): `AGENTS.md` versionado e enxuto; comentário meta e narrativo sai do código (vira porquê curto); um gancho determinístico mantém isso a cada commit. PR final para `vitoriamariadb/MeowSystem` | pedido de 15/10 |
| 18 | Ações do painel | **Só Executar e Restaurar**; o resultado abre numa janela (fundo escurecido) com OK, Guardar e Restaurar; «Ver o que faria» vira «Ver sem mudar»; sem «ver comando» nem comando cru na tela; uma regra só de divisória e cartão em todas as telas | prints e pedido de 16/10 |
⟪para⟫
| 17 | Repositório enxuto e legível para IA, apesar da regra anti-evidência | **Sim; `AGENTS.md` é exceção do sanitizador (15/10: «AGENTS.md são exceção, pode subir eles»)** («IA-friendly mesmo que tenhamos a regra original de anti-evidência de IA»): `AGENTS.md` versionado e enxuto; comentário meta e narrativo sai do código (vira porquê curto); um gancho determinístico mantém isso a cada commit. PR final para `vitoriamariadb/MeowSystem` | pedido de 15/10 |
| 18 | Ações do painel | **Só Executar e Restaurar**; o resultado abre numa janela (fundo escurecido) com OK, Guardar e Restaurar; «Ver o que faria» vira «Ver sem mudar»; sem «ver comando» nem comando cru na tela; uma regra só de divisória e cartão em todas as telas | prints e pedido de 16/10 |
| 19 | O mascote (o gato do dock e do fastfetch) | **Cada pack tem o seu**, em `packs/<id>/mascote/`, com `mascote.dia` e `mascote.noite` no `pack.json`: Coquinha e Mimir no `meowsystem`, os três morcegos no `dracula`. Na interface o nome é «Mascote» | pedido de 23/10 (P96) |
| 20 | O terminal num PC sem o Spellbook | **O MeowSystem escreve o bloco marcado** no `.bashrc`/`.zshrc` (starship, cores do fzf, mascote do fastfetch, completion) e o tira ao desinstalar; o equivalente do Spellbook sai por item do `assets/contratos/vizinhos.tsv`, desativado depois do install | pedido de 23/10 (P96) |
| 21 | O que o Pop!_OS não traz | **O instalador baixa sozinho** o compilador e as bibliotecas dos applets (lista em `MEOW_DEPS_DOS_APPLETS`); o fastfetch vem do PPA `zhangsongcui3371` | pedido de 23/10 (P96) |
| 22 | De onde o PC novo baixa | **O dev vai para o master do fork `AndreBFarias/MeowSystem`**, e o README aponta para lá | pedido de 23/10 (P96) |
| 23 | Papel de parede numa casa nova | **O install semeia sozinho**, da origem que o `pack.json` de cada pack declara (`origens.wallpapers`); nenhuma saída manda digitar `meow wallpaper semear` | pedido de 23/10 (P96) |
| 24 | O que sai do repositório | `docs/folhas/`, `docs/pesquisas/`, `docs/capturas/spotify.jpg` e a etapa morta do `assets/icones/catppuccin-apps/` (o git guarda) | pedido de 23/10 (P96) |
⟪fim⟫
⟪arquivo⟫ install.sh
⟪de⟫
  if ! cat "$origem" > "$tmp"; then rm -f "$tmp"; return "$MEOW_ERRO"; fi
  chmod 644 "$tmp"
  mv -f "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }

⟪para⟫
  if ! cat "$origem" > "$tmp"; then rm -f "$tmp"; return "$MEOW_ERRO"; fi
  chmod 644 "$tmp"
  meow_guardar_antes "$destino"
  mv -f "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }

⟪fim⟫
⟪arquivo⟫ install.sh
⟪de⟫
  # de alguém.
  if meow_tem zsh && ! zsh -f -c 'print -l -- $fpath' 2>/dev/null | grep -qxF -- "$COMPLETIONS_DIR"; then
    meow_info "o zsh não procura em $COMPLETIONS_DIR sozinho; no seu .zshrc, ANTES do compinit:"
    meow_info "  fpath=(\"$COMPLETIONS_DIR\" \$fpath)"
  fi
  return "$MEOW_DIVERGENTE"
⟪para⟫
  # de alguém.
  if meow_tem zsh && ! zsh -f -c 'print -l -- $fpath' 2>/dev/null | grep -qxF -- "$COMPLETIONS_DIR"; then
    meow_info "o bloco do MeowSystem no terminal põe $COMPLETIONS_DIR no fpath do zsh"
  fi
  return "$MEOW_DIVERGENTE"
⟪fim⟫
⟪arquivo⟫ install.sh
⟪de⟫
  python3 -I -c 'import numpy' 2>/dev/null || faltam+=(python3-numpy)

  if [ ${#faltam[@]} -eq 0 ]; then
    meow_ok "todos os pacotes necessários já estão instalados"
    return 0
  fi

⟪para⟫
  python3 -I -c 'import numpy' 2>/dev/null || faltam+=(python3-numpy)

  # O compilador e as bibliotecas dos applets (mídia e leitura), quando um deles
  # está ligado: o Pop!_OS não traz nenhum deles, e sem eles o cargo para no link.
  local prova pacote
  if [ "${MIDIA:-sim}" = "sim" ] || [ "${LEITURA_APPLET:-sim}" = "sim" ]; then
    while IFS='|' read -r prova pacote; do
      [ -e "$prova" ] || faltam+=("$pacote")
    done <<< "$MEOW_DEPS_DOS_APPLETS"
  fi
  # O fastfetch não está no apt do Pop!_OS 24.04: desce do PPA do autor.
  local ppa_fastfetch=0
  if [ "${FASTFETCH_LOGO:-sim}" != "nao" ] && ! meow_tem fastfetch; then
    ppa_fastfetch=1
    meow_tem add-apt-repository || faltam+=(software-properties-common)
  fi

  if [ ${#faltam[@]} -eq 0 ] && [ "$ppa_fastfetch" = 0 ]; then
    meow_ok "todos os pacotes necessários já estão instalados"
    return 0
  fi
  if [ ${#faltam[@]} -eq 0 ]; then
    _pacotes_fastfetch
    return $?
  fi

⟪fim⟫
⟪arquivo⟫ install.sh
⟪de⟫
  fi
  meow_ok "instalados: ${faltam[*]}"
  return "$MEOW_DIVERGENTE"
}

⟪para⟫
  fi
  meow_ok "instalados: ${faltam[*]}"
  [ "$ppa_fastfetch" = 1 ] && _pacotes_fastfetch
  return "$MEOW_DIVERGENTE"
}

# O fastfetch pelo PPA zhangsongcui3371/fastfetch (o do autor).
_pacotes_fastfetch() {
  if meow_seco; then
    meow_muda "rodaria: sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch && sudo apt-get install -y fastfetch"
    return "$MEOW_DIVERGENTE"
  fi
  meow_info "vou rodar como root, e só isto:"
  printf '      sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch\n      sudo apt-get install -y fastfetch\n'
  if sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch >/dev/null 2>&1 \
     && sudo apt-get install -y --no-install-recommends fastfetch >/dev/null 2>&1; then
    meow_ok "fastfetch instalado do PPA do autor"
    return "$MEOW_DIVERGENTE"
  fi
  meow_aviso "o fastfetch não desceu (sem rede?) — a próxima passada tenta de novo"
  return "$MEOW_SEM_DEPENDENCIA"
}

⟪fim⟫
⟪arquivo⟫ install.sh
⟪de⟫
  meow_tem python3 || { meow_pula "python3 não está aqui"; return 0; }
  local pastas=() p
  for p in packs/meowsystem/mascote/ packs/meowsystem/icones/sistema/leitura assets/icones/overrides; do
    [ -d "$MEOW_RAIZ/$p" ] && pastas+=("$MEOW_RAIZ/$p")
  done
⟪para⟫
  meow_tem python3 || { meow_pula "python3 não está aqui"; return 0; }
  local pastas=() p
  for p in packs/meowsystem/mascote/ packs/dracula/mascote/ packs/meowsystem/icones/sistema/leitura assets/icones/overrides; do
    [ -d "$MEOW_RAIZ/$p" ] && pastas+=("$MEOW_RAIZ/$p")
  done
⟪fim⟫
⟪arquivo⟫ install.sh
⟪de⟫
# declaração `scalable/mimetypes` lá, estes arquivos existiriam no disco e não
# seriam encontrados por ninguém.
# Os ícones do LANÇADOR, do acervo Catppuccin de aplicativo. Depois do
# `etapa_icones` pelo mesmo motivo da etapa irmã: quem declara `512x512/apps` no
# index.theme é aquele, e sem a declaração estes PNG não são achados por ninguém.
etapa_icones_apps() {
  passo "Ícones dos aplicativos"
  ICONES_FLAVOR="${ICONES_FLAVOR:-}" \
    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_apps.sh"
  return $?
}

# Os desenhos DELA que só existiam em PNG, de volta ao vetor. Depois do
# `etapa_icones` pelo mesmo motivo das etapas irmãs — quem declara
⟪para⟫
# declaração `scalable/mimetypes` lá, estes arquivos existiriam no disco e não
# seriam encontrados por ninguém.
# Os desenhos DELA que só existiam em PNG, de volta ao vetor. Depois do
# `etapa_icones` pelo mesmo motivo das etapas irmãs — quem declara
⟪fim⟫
⟪arquivo⟫ install.sh
⟪de⟫
    "$MEOW_RAIZ/scripts/fastfetch_logo.sh" aplicar
  return $?
}

⟪para⟫
    "$MEOW_RAIZ/scripts/fastfetch_logo.sh" aplicar
  return $?
}

# O bloco do MeowSystem no arquivo de início do terminal: prompt, cores do fzf,
# mascote do fastfetch e completion. Depois das três etapas que ele carrega.
etapa_bloco_terminal() {
  passo "Bloco do terminal"
  "$MEOW_RAIZ/scripts/terminal_bloco.sh" aplicar
}

⟪fim⟫
⟪arquivo⟫ install.sh
⟪de⟫
etapa_wallpaper() {
  passo "Papéis de parede"
  WALLPAPER_BASE="${WALLPAPER_BASE:-}" WALLPAPER_INTERVALO="${WALLPAPER_INTERVALO:-5m}" \
    WALLPAPER_ORDEM="${WALLPAPER_ORDEM:-aleatoria}" \
⟪para⟫
etapa_wallpaper() {
  passo "Papéis de parede"
  local rc_semente
  "$MEOW_RAIZ/scripts/wallpaper.sh" semear-se-faltar; rc_semente=$?
  WALLPAPER_BASE="${WALLPAPER_BASE:-}" WALLPAPER_INTERVALO="${WALLPAPER_INTERVALO:-5m}" \
    WALLPAPER_ORDEM="${WALLPAPER_ORDEM:-aleatoria}" \
⟪fim⟫
⟪arquivo⟫ install.sh
⟪de⟫
    "$MEOW_RAIZ/scripts/wallpaper.sh" aplicar
  local rc=$?
  [ "$rc" = "1" ] && [ "${WALLPAPER_NOTIFICAR:-sim}" = "sim" ] \
    && meow_notificar "MeowSystem" "Carrossel de papéis de parede ligado."

  # O CARROSSEL NASCIA VAZIO E NÃO DIZIA O QUE O ENCHE — 21/09/2026
  #   Numa máquina nova o `aplicar` sai 3 com "só 0 imagem(ns) em ... — o
  #   carrossel precisa de 2 ou mais" e manda `meow wallpaper adicionar
  #   <arquivo|pasta>`, que pressupõe que a pessoa já tenha imagens. Quem enche
  #   o acervo do zero é `meow wallpaper semear` — e `grep -c semear install.sh`
  #   devolvia 0: o instalador nunca o nomeava, em lugar nenhum. O README
  #   prometia "43 imagens curadas" duas vezes, e o estranho ficava com zero,
  #   sem nenhuma frase ligando as duas coisas.
  #
  #   POR QUE A ETAPA NÃO SEMEIA SOZINHA. O `scripts/wallpaper.sh` (cabeçalho
  #   do `semear_das_dela`) grava a regra da casa: "não baixamos nada da
  #   internet sem ela pedir: o carrossel tem de funcionar no primeiro
  #   install.sh, offline". Baixar dezenas de imagens do GitHub sem perguntar
  #   quebraria essa regra e ainda faria a primeira instalação depender de
  #   rede. O que faltava não era a semeadura automática: era a FRASE. Um
  #   comando que ninguém sabe que existe é um comando que não existe.
  if [ "$rc" = "3" ]; then
    meow_info "para encher o acervo de uma vez, com as imagens curadas:"
    meow_info "    meow wallpaper semear        # baixa o acervo (precisa de rede)"
    meow_info "  ou aponte para imagens que você já tem:"
    meow_info "    meow wallpaper adicionar ~/Imagens"
  fi

  # O RELÓGIO CURTO DO CARROSSEL — por que ele nasceu em 08/08/2026
⟪para⟫
    "$MEOW_RAIZ/scripts/wallpaper.sh" aplicar
  local rc=$?
  [ "$rc_semente" = "$MEOW_DIVERGENTE" ] && [ "$rc" = "$MEOW_OK" ] && rc="$MEOW_DIVERGENTE"
  [ "$rc" = "1" ] && [ "${WALLPAPER_NOTIFICAR:-sim}" = "sim" ] \
    && meow_notificar "MeowSystem" "Carrossel de papéis de parede ligado."

  # O carrossel vazio se enche sozinho: o `semear-se-faltar`, lá em cima, desce
  # a coleção da origem que o pack declara (`origens.wallpapers`).

  # O RELÓGIO CURTO DO CARROSSEL — por que ele nasceu em 08/08/2026
⟪fim⟫
⟪arquivo⟫ install.sh
⟪de⟫
                etapa_modo etapa_greeter etapa_vidro etapa_forma etapa_painel etapa_janelas etapa_relogio etapa_leitura etapa_escala etapa_upstream etapa_fontes
                etapa_svg etapa_icones etapa_pastas_xdg etapa_pastas etapa_hicolor etapa_completar_icones
                etapa_mimetypes etapa_icones_apps etapa_icones_resgatados etapa_icones_apps_arcticons etapa_icones_apps_dracula etapa_icones_sistema etapa_icones_bandeja
                etapa_icones_tray_steam etapa_icones_tray_zapzap etapa_jogos etapa_jogos_heroic
                etapa_logo etapa_icones_indice etapa_wallpaper etapa_ocultar etapa_nomes etapa_absolutos etapa_ocultar_casa etapa_janela_dock
                etapa_lancador_apt etapa_som etapa_terminal etapa_prompt etapa_fzf etapa_fastfetch_logo etapa_files_menu etapa_cursor etapa_flatpak_tema etapa_escritorio etapa_apps
                etapa_assets etapa_vigia_flatpak etapa_vigia_steam etapa_vigia_heroic etapa_vigia_qt etapa_vigia_apt etapa_vigia_derivados
                etapa_midia_build etapa_midia etapa_leitura_applet etapa_lancador etapa_autostart etapa_autoreparo)
⟪para⟫
                etapa_modo etapa_greeter etapa_vidro etapa_forma etapa_painel etapa_janelas etapa_relogio etapa_leitura etapa_escala etapa_upstream etapa_fontes
                etapa_svg etapa_icones etapa_pastas_xdg etapa_pastas etapa_hicolor etapa_completar_icones
                etapa_mimetypes etapa_icones_resgatados etapa_icones_apps_arcticons etapa_icones_apps_dracula etapa_icones_sistema etapa_icones_bandeja
                etapa_icones_tray_steam etapa_icones_tray_zapzap etapa_jogos etapa_jogos_heroic
                etapa_logo etapa_icones_indice etapa_wallpaper etapa_ocultar etapa_nomes etapa_absolutos etapa_ocultar_casa etapa_janela_dock
                etapa_lancador_apt etapa_som etapa_terminal etapa_prompt etapa_fzf etapa_fastfetch_logo etapa_bloco_terminal etapa_files_menu etapa_cursor etapa_flatpak_tema etapa_escritorio etapa_apps
                etapa_assets etapa_vigia_flatpak etapa_vigia_steam etapa_vigia_heroic etapa_vigia_qt etapa_vigia_apt etapa_vigia_derivados
                etapa_midia_build etapa_midia etapa_leitura_applet etapa_lancador etapa_autostart etapa_autoreparo)
⟪fim⟫
⟪arquivo⟫ lib/comum.sh
⟪de⟫
# O caminho passa pelo `meow_dentro`: uma pasta do pack que seja link para fora
# não vira acervo.
meow_pack_arquivo() {
  local no_pack="$1" no_nucleo="${2:-}" dir real
⟪para⟫
# O caminho passa pelo `meow_dentro`: uma pasta do pack que seja link para fora
# não vira acervo.
# O motivo de um `cargo build` que falhou, lido do registro dele: a falta de
# compilador ou de biblioteca do sistema vem antes de qualquer suspeita do código.
meow_motivo_do_cargo() {
  local log="$1" lib
  if grep -q 'linker `cc` not found' "$log" 2>/dev/null; then
    printf 'falta o compilador C (pacote build-essential)'
  elif lib="$(grep -o 'The system library `[^`]*`' "$log" 2>/dev/null | head -n1)" && [ -n "$lib" ]; then
    lib="${lib#*\`}"
    printf 'falta a biblioteca %s do sistema (o pacote -dev dela)' "${lib%\`}"
  elif grep -q 'Could not run `"pkg-config"\|pkg-config: not found\|failed to run.*pkg-config' "$log" 2>/dev/null; then
    printf 'falta o pkg-config'
  else
    printf 'o cargo não compilou'
  fi
}

# Os pacotes de que a compilação dos applets precisa, um por linha:
# `<arquivo que prova a presença>|<pacote>`.
MEOW_DEPS_DOS_APPLETS="/usr/bin/cc|build-essential
/usr/bin/pkg-config|pkg-config
/usr/include/xkbcommon/xkbcommon.h|libxkbcommon-dev
/usr/include/wayland-client.h|libwayland-dev
/usr/include/dbus-1.0/dbus/dbus.h|libdbus-1-dev"

# A pasta do mascote do pack no ar (pela herança); sem nenhuma, a do pack-base.
meow_mascote_dir() {
  python3 "$MEOW_RAIZ/scripts/pack.py" mascote "$(meow_pack_dir)" 2>/dev/null \
    || printf '%s' "$MEOW_RAIZ/packs/meowsystem/mascote"
}

meow_pack_arquivo() {
  local no_pack="$1" no_nucleo="${2:-}" dir real
⟪fim⟫
⟪arquivo⟫ lib/comum.sh
⟪de⟫
# --- lock: o timer pode disparar enquanto ela roda na mão (regra 10) --------
MEOW_ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"

# --- O ESTADO DO USUÁRIO SAI DO REPOSITÓRIO, E O `.padrao` FICA — 21/09/2026 -
⟪para⟫
# --- lock: o timer pode disparar enquanto ela roda na mão (regra 10) --------
MEOW_ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"
# O que se baixa (papirus-folders, o tarball da Nerd Font) mora fora do repositório.
MEOW_CACHE="${MEOW_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem}"

# --- O ESTADO DO USUÁRIO SAI DO REPOSITÓRIO, E O `.padrao` FICA — 21/09/2026 -
⟪fim⟫
⟪arquivo⟫ lib/comum.sh
⟪de⟫
meow_estado_com_padrao() {
  local pasta="$1" arquivo="$2" origem="$MEOW_RAIZ/assets/$1" dir="$MEOW_ESTADO/$1"
  local padrao semente
  if [ "${MEOW_ESTADO_SO_LE:-0}" = "1" ] && [ ! -f "$dir/$arquivo" ]; then
⟪para⟫
meow_estado_com_padrao() {
  local pasta="$1" arquivo="$2" origem="$MEOW_RAIZ/assets/$1" dir="$MEOW_ESTADO/$1"
  # A semente dos papéis de parede é a curadoria do pack-base.
  [ "$pasta" = "papeis-de-parede" ] && origem="$MEOW_RAIZ/packs/meowsystem/wallpapers"
  local padrao semente
  if [ "${MEOW_ESTADO_SO_LE:-0}" = "1" ] && [ ! -f "$dir/$arquivo" ]; then
⟪fim⟫
⟪arquivo⟫ lib/desinstalar.sh
⟪de⟫
    "$MEOW_RAIZ/scripts/icones_tray_zapzap.sh" --desfazer || true
  fi

  meow_passo "2/6 Temas por aplicativo"
⟪para⟫
    "$MEOW_RAIZ/scripts/icones_tray_zapzap.sh" --desfazer || true
  fi

  "$MEOW_RAIZ/scripts/terminal_bloco.sh" remover || true

  meow_passo "2/6 Temas por aplicativo"
⟪fim⟫
⟪arquivo⟫ packs/dracula/pack.json
⟪de⟫
    "site": "https://draculatheme.com",
    "_nota": "O que o cartão de escolher pack mostra (P15, 23/09/2026). A capa É o logo.svg que a P25 desenha — o mesmo arquivo que vira o ícone do lançador —, e não uma tira de cores: tira é paleta, não identidade. As tags foram medidas, não escolhidas: o pack tem um flavor escuro (dracula) e um claro (alucard), e o 'text' sobre o 'base' dá 13,36:1 no primeiro e 7,10:1 no segundo, os dois acima dos 7:1 do WCAG AAA. Sem 'capturas' de propósito: uma foto de tela desta máquina levaria para o git o que estava aberto nela."
  },
  "heranca": "catppuccin",
⟪para⟫
    "site": "https://draculatheme.com",
    "_nota": "O que o cartão de escolher pack mostra (P15, 23/09/2026). A capa É o logo.svg que a P25 desenha — o mesmo arquivo que vira o ícone do lançador —, e não uma tira de cores: tira é paleta, não identidade. As tags foram medidas, não escolhidas: o pack tem um flavor escuro (dracula) e um claro (alucard), e o 'text' sobre o 'base' dá 13,36:1 no primeiro e 7,10:1 no segundo, os dois acima dos 7:1 do WCAG AAA. Sem 'capturas' de propósito: uma foto de tela desta máquina levaria para o git o que estava aberto nela."
  },
  "mascote": {
    "desenhos": "mascote/",
    "dia": "morcego-dia",
    "noite": "morcego-noite",
    "_nota": "Os morcegos nas cores do Dracula: de dia o que dorme pendurado, de noite o que voa."
  },
  "heranca": "catppuccin",
⟪fim⟫
⟪arquivo⟫ packs/dracula/pack.json
⟪de⟫
      ],
      "desenhos": "wallpapers/",
      "_nota_desenhos": "Os treze SVG do tulip-orchid (MIT), dentro do pack desde 09/10/2026 (P74 item 9, T7): sem o repositório no meow.conf — o caso de toda instalação nova —, o Dracula caía no acervo do Catppuccin. O `wallpaper.sh` os rasteriza em PNG 3840x2160 ao semear; o PNG sai igual, pixel a pixel, ao do repositório. A procedência está no PROCEDENCIA.md.",
      "se_vazio": "herdar",
⟪para⟫
      ],
      "desenhos": "wallpapers/",
      "prefixo": "tulip",
      "_nota_desenhos": "Os treze SVG do tulip-orchid (MIT), dentro do pack desde 09/10/2026 (P74 item 9, T7): sem o repositório no meow.conf — o caso de toda instalação nova —, o Dracula caía no acervo do Catppuccin. O `wallpaper.sh` os rasteriza em PNG 3840x2160 ao semear; o PNG sai igual, pixel a pixel, ao do repositório. A procedência está no PROCEDENCIA.md.",
      "se_vazio": "herdar",
⟪fim⟫
⟪arquivo⟫ packs/meowsystem/pack.json
⟪de⟫
  "autor": "vitoriamariadb",
  "licenca": "GPL-3.0-or-later",
  "icones": {
    "apps": {
⟪para⟫
  "autor": "vitoriamariadb",
  "licenca": "GPL-3.0-or-later",
  "mascote": {
    "desenhos": "mascote/",
    "dia": "mimir",
    "noite": "coquinha",
    "_nota": "O mascote do dock e do fastfetch. Um .svg solto em `mascote/` entra na lista; `dia` e `noite` são os de fábrica do modo `hora` quando o LOGO_DIA/LOGO_NOITE do meow.conf não está nesta pasta."
  },
  "origens": {
    "wallpapers": {
      "repo": "zhichaoh/catppuccin-wallpapers",
      "commit": "1023077979591cdeca76aae94e0359da1707a60e",
      "prefixo": "cat",
      "curadoria": "wallpapers/FONTES.tsv",
      "_nota": "O instalador semeia sozinho: a coleção pinada do repo e a curadoria (uma linha por imagem, com a URL). As imagens não vão para o git; a receita vai."
    }
  },
  "icones": {
    "apps": {
⟪fim⟫
⟪arquivo⟫ scripts/baixar_upstream.sh
⟪de⟫
. "$RAIZ/lib/comum.sh"

DESTINO="$RAIZ/assets/icones/upstream"

# repositório                                   pasta            commit pinado
⟪para⟫
. "$RAIZ/lib/comum.sh"

DESTINO="$MEOW_CACHE/upstream"

# repositório                                   pasta            commit pinado
⟪fim⟫
⟪arquivo⟫ scripts/construir_icones.sh
⟪de⟫
# avisa "solte um .svg lá e ele entra".
GATO_PISO=""
if [ -d "$RAIZ/packs/meowsystem/mascote/" ]; then
  GATO_PISO="$(find "$RAIZ/packs/meowsystem/mascote/" -maxdepth 1 -name '*.svg' \
                 ! -name '*-symbolic.svg' | sort | head -n1)"
fi
⟪para⟫
# avisa "solte um .svg lá e ele entra".
GATO_PISO=""
if [ -d "$(meow_mascote_dir)/" ]; then
  GATO_PISO="$(find "$(meow_mascote_dir)/" -maxdepth 1 -name '*.svg' \
                 ! -name '*-symbolic.svg' | sort | head -n1)"
fi
⟪fim⟫
⟪arquivo⟫ scripts/construir_pastas.sh
⟪de⟫
unset _base
COR="${ICONES_PASTAS:-cat-mocha-mauve}"
FONTE="${MEOW_CAT_FOLDERS:-$RAIZ/assets/icones/upstream/papirus-folders}"

# O valor padrão de `ICONES_PASTAS` é `cat-${FLAVOR}-${ACCENT}`, e o
⟪para⟫
unset _base
COR="${ICONES_PASTAS:-cat-mocha-mauve}"
FONTE="${MEOW_CAT_FOLDERS:-$MEOW_CACHE/upstream/papirus-folders}"

# O valor padrão de `ICONES_PASTAS` é `cat-${FLAVOR}-${ACCENT}`, e o
⟪fim⟫
⟪arquivo⟫ scripts/derivados.sh
⟪de⟫
    */icones/apps-arcticons.map|*/icones/apps-convertidos.map|*/icones/apps-marca.map \
      |*/icones/apps/arcticons/*|*/icones/apps/convertidos/*) printf 'arcticons\n' ;;
    */icones/apps-hicolor.map)                 printf 'completar\napps\n' ;;
    */icones/apps/autorais/*)                  printf 'completar\n' ;;
    */icones/sistema.map)                      printf 'sistema\n' ;;
⟪para⟫
    */icones/apps-arcticons.map|*/icones/apps-convertidos.map|*/icones/apps-marca.map \
      |*/icones/apps/arcticons/*|*/icones/apps/convertidos/*) printf 'arcticons\n' ;;
    */icones/apps-hicolor.map)                 printf 'completar\n' ;;
    */icones/apps/autorais/*)                  printf 'completar\n' ;;
    */icones/sistema.map)                      printf 'sistema\n' ;;
⟪fim⟫
⟪arquivo⟫ scripts/derivados.sh
⟪de⟫
                FLAVOR="${FLAVOR:-}" ICONES_COR_MARCA="${ICONES_COR_MARCA:-nao}" ICONES_TEMA="$tema" \
                  "$RAIZ/scripts/icones_apps_arcticons.sh" ;;
    apps)       ICONES_FLAVOR="${ICONES_FLAVOR:-}" ICONES_TEMA="$tema" "$RAIZ/scripts/icones_apps.sh" ;;
    completar)  FLAVOR="${FLAVOR:-}" ACCENT="${ACCENT:-}" NOME_TEMA_ICONES="$tema" \
                  "$RAIZ/scripts/completar_icones.sh" ;;
⟪para⟫
                FLAVOR="${FLAVOR:-}" ICONES_COR_MARCA="${ICONES_COR_MARCA:-nao}" ICONES_TEMA="$tema" \
                  "$RAIZ/scripts/icones_apps_arcticons.sh" ;;
    completar)  FLAVOR="${FLAVOR:-}" ACCENT="${ACCENT:-}" NOME_TEMA_ICONES="$tema" \
                  "$RAIZ/scripts/completar_icones.sh" ;;
⟪fim⟫
⟪arquivo⟫ scripts/derivados.sh
⟪de⟫
  MEOW_RELER_NO_FIM="$(mktemp "${TMPDIR:-/tmp}/meow-reler.XXXXXX" 2>/dev/null)" && export MEOW_RELER_NO_FIM
  local feitos=()
  for passo in completar mimetypes apps resgatados arcticons dracula sistema bandeja pastas; do
    [ -n "${pedir[$passo]:-}" ] || continue
    feitos+=("$passo")
⟪para⟫
  MEOW_RELER_NO_FIM="$(mktemp "${TMPDIR:-/tmp}/meow-reler.XXXXXX" 2>/dev/null)" && export MEOW_RELER_NO_FIM
  local feitos=()
  for passo in completar mimetypes resgatados arcticons dracula sistema bandeja pastas; do
    [ -n "${pedir[$passo]:-}" ] || continue
    feitos+=("$passo")
⟪fim⟫
⟪arquivo⟫ scripts/exportar_tema.sh
⟪de⟫
etapa completar  'FLAVOR="$FLAVOR" ACCENT="$ACCENT" "$MEOW_RAIZ/scripts/completar_icones.sh"'
etapa mimetypes  'ICONES_FLAVOR="${ICONES_FLAVOR:-}" ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_mimetypes.sh"'
etapa apps       'ICONES_FLAVOR="${ICONES_FLAVOR:-}" ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_apps.sh"'
etapa resgatados 'ICONES_RESGATADOS="${ICONES_RESGATADOS:-sim}" "$MEOW_RAIZ/scripts/icones_resgatados.sh" --aplicar'
etapa arcticons  'FLAVOR="${FLAVOR:-}" ICONES_COR_MARCA="${ICONES_COR_MARCA:-nao}" ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_apps_arcticons.sh"'
⟪para⟫
etapa completar  'FLAVOR="$FLAVOR" ACCENT="$ACCENT" "$MEOW_RAIZ/scripts/completar_icones.sh"'
etapa mimetypes  'ICONES_FLAVOR="${ICONES_FLAVOR:-}" ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_mimetypes.sh"'
etapa resgatados 'ICONES_RESGATADOS="${ICONES_RESGATADOS:-sim}" "$MEOW_RAIZ/scripts/icones_resgatados.sh" --aplicar'
etapa arcticons  'FLAVOR="${FLAVOR:-}" ICONES_COR_MARCA="${ICONES_COR_MARCA:-nao}" ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_apps_arcticons.sh"'
⟪fim⟫
⟪arquivo⟫ scripts/fastfetch_logo.sh
⟪de⟫
    case "$(basename "$svg")" in *-symbolic.svg) continue ;; esac
    nomes+=("$(basename "${svg%.svg}")")
  done < <(find "$MEOW_RAIZ/packs/meowsystem/mascote/" -maxdepth 1 -name '*.svg' 2>/dev/null | LC_ALL=C sort)
  [ "${#nomes[@]}" -ge 2 ] || return 1
  for i in "${!nomes[@]}"; do
⟪para⟫
    case "$(basename "$svg")" in *-symbolic.svg) continue ;; esac
    nomes+=("$(basename "${svg%.svg}")")
  done < <(find "$(meow_mascote_dir)/" -maxdepth 1 -name '*.svg' 2>/dev/null | LC_ALL=C sort)
  [ "${#nomes[@]}" -ge 2 ] || return 1
  for i in "${!nomes[@]}"; do
⟪fim⟫
⟪arquivo⟫ scripts/fastfetch_logo.sh
⟪de⟫

_ffl_svg() {
  case "$FASTFETCH_LOGO_GATO" in
    */*|*.svg) printf '%s' "$FASTFETCH_LOGO_GATO" ;;
    *)         printf '%s' "$MEOW_RAIZ/packs/meowsystem/mascote/$FASTFETCH_LOGO_GATO.svg" ;;
  esac
}

⟪para⟫

_ffl_svg() {
  local dir nome
  case "$FASTFETCH_LOGO_GATO" in
    */*|*.svg) printf '%s' "$FASTFETCH_LOGO_GATO"; return ;;
  esac
  dir="$(meow_mascote_dir)"
  if [ ! -f "$dir/$FASTFETCH_LOGO_GATO.svg" ]; then
    # O nome do conf é de outro pack: vale o mascote de fábrica do pack no ar.
    nome="$(python3 "$MEOW_RAIZ/scripts/pack.py" mascote-padrao "$(meow_pack_dir)" "${FFL_FASE:-dia}" 2>/dev/null)"
    if [ -n "$nome" ] && [ -f "$dir/$nome.svg" ]; then printf '%s' "$dir/$nome.svg"; return; fi
  fi
  printf '%s' "$dir/$FASTFETCH_LOGO_GATO.svg"
}

⟪fim⟫
⟪arquivo⟫ scripts/folha_proposta.py
⟪de⟫
HOME = os.path.expanduser('~')
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREVIA_DIR = os.path.join(RAIZ, 'assets', 'icones', 'previa-arcticons')
CONF_TK = os.path.join(HOME, '.config/cosmic/com.system76.CosmicTk/v1/icon_theme')

⟪para⟫
HOME = os.path.expanduser('~')
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Os mesmos bytes que a prévia guardava: o traço Arcticons do pack-base.
PREVIA_DIR = os.path.join(RAIZ, 'packs', 'meowsystem', 'icones', 'apps', 'arcticons')
CONF_TK = os.path.join(HOME, '.config/cosmic/com.system76.CosmicTk/v1/icon_theme')

⟪fim⟫
⟪arquivo⟫ scripts/folha_proposta.py
⟪de⟫
    print(saida)
    if faltando:
        print('SEM ARQUIVO em assets/icones/previa-arcticons/: ' + ', '.join(faltando),
              file=sys.stderr)
        return 1
⟪para⟫
    print(saida)
    if faltando:
        print('SEM ARQUIVO em ' + os.path.relpath(PREVIA_DIR, RAIZ) + '/: ' + ', '.join(faltando),
              file=sys.stderr)
        return 1
⟪fim⟫
⟪arquivo⟫ scripts/fzf.sh
⟪de⟫
     else
       meow_ok "cores do fzf de $_FLAVOR escritas em $FZF_ALVO"
       meow_info "valem em todo shell que carregar o arquivo — a linha, se ainda não estiver no seu:"
       meow_info "  $(_fzf_linha)"
     fi
     exit "$MEOW_DIVERGENTE" ;;
⟪para⟫
     else
       meow_ok "cores do fzf de $_FLAVOR escritas em $FZF_ALVO"
       meow_info "valem no próximo terminal (o bloco do MeowSystem carrega o arquivo)"
     fi
     exit "$MEOW_DIVERGENTE" ;;
⟪fim⟫
⟪arquivo⟫ scripts/greeter.sh
⟪de⟫
  # nada. O md5 guardado, logo abaixo, é o que ainda reconhece um avatar posto
  # por uma versão anterior deste script.
  for f in "$RAIZ"/packs/meowsystem/mascote/*.svg; do
    [ -f "$f" ] || continue
    [ "$(md5sum < "$f" | cut -d' ' -f1)" = "$md5" ] && return 0
⟪para⟫
  # nada. O md5 guardado, logo abaixo, é o que ainda reconhece um avatar posto
  # por uma versão anterior deste script.
  for f in "$RAIZ"/packs/*/mascote/*.svg; do
    [ -f "$f" ] || continue
    [ "$(md5sum < "$f" | cut -d' ' -f1)" = "$md5" ] && return 0
⟪fim⟫
⟪arquivo⟫ scripts/greeter.sh
⟪de⟫
  # junto com a rotação diária, e cada troca é uma escrita no AccountsService
  # via D-Bus.
  desejado="$(find "$RAIZ/packs/meowsystem/mascote/" -maxdepth 1 -name '*.svg' \
                ! -name '*-symbolic.svg' 2>/dev/null | sort | head -n1)"
  [ -n "$desejado" ] && [ -f "$desejado" ] \
    || { meow_pula "não há mascote em packs/meowsystem/mascote/ para o avatar"; return 0; }
  md5_novo="$(md5sum < "$desejado" | cut -d' ' -f1)"

⟪para⟫
  # junto com a rotação diária, e cada troca é uma escrita no AccountsService
  # via D-Bus.
  desejado="$(find "$(meow_mascote_dir)/" -maxdepth 1 -name '*.svg' \
                ! -name '*-symbolic.svg' 2>/dev/null | sort | head -n1)"
  [ -n "$desejado" ] && [ -f "$desejado" ] \
    || { meow_pula "não há mascote em $(meow_mascote_dir) para o avatar"; return 0; }
  md5_novo="$(md5sum < "$desejado" | cut -d' ' -f1)"

⟪fim⟫
⟪arquivo⟫ scripts/instalar_fontes.sh
⟪de⟫
)

# O cache do tarball fica no repo e está no .gitignore: é a mesma regra do
# baixar_upstream.sh — o git guarda a RECEITA, não os megabytes.
CACHE="$RAIZ/assets/fontes/upstream"
TAR="$CACHE/$NERD_ATIVO"

⟪para⟫
)

# O cache do tarball fica fora do repositório, como o do baixar_upstream.sh — o
# git guarda a RECEITA, não os megabytes.
CACHE="$MEOW_CACHE/fontes"
TAR="$CACHE/$NERD_ATIVO"

⟪fim⟫
⟪arquivo⟫ scripts/leitura_build.sh
⟪de⟫
  if [ "$compilou" = 0 ] && ! CARGO_TARGET_DIR="$ALVO" cargo build --release --locked \
        --manifest-path "$MANIFESTO" >"$ESTADO/compilar.log" 2>&1; then
    meow_erro "o cargo falhou — o registro está em $ESTADO/compilar.log"
    meow_info "  o binário anterior, se houver, segue instalado e funcionando; nada foi trocado"
    return "$MEOW_ERRO"
⟪para⟫
  if [ "$compilou" = 0 ] && ! CARGO_TARGET_DIR="$ALVO" cargo build --release --locked \
        --manifest-path "$MANIFESTO" >"$ESTADO/compilar.log" 2>&1; then
    meow_erro "o cargo falhou — $(meow_motivo_do_cargo "$ESTADO/compilar.log")"
    meow_info "  o registro está em $ESTADO/compilar.log"
    meow_info "  o binário anterior, se houver, segue instalado e funcionando; nada foi trocado"
    return "$MEOW_ERRO"
⟪fim⟫
⟪arquivo⟫ scripts/logo.sh
⟪de⟫
. "$RAIZ/lib/noite.sh"

ACERVO="$RAIZ/packs/meowsystem/mascote/"
COSMIC="$(meow_cosmic_dir)"
LOGOS_DIR="$COSMIC/logos"
⟪para⟫
. "$RAIZ/lib/noite.sh"

ACERVO="$(meow_mascote_dir)/"
COSMIC="$(meow_cosmic_dir)"
LOGOS_DIR="$COSMIC/logos"
⟪fim⟫
⟪arquivo⟫ scripts/logo.sh
⟪de⟫
  proximo="$(_indice_de "$_quer")"
  if [ "$proximo" -lt 0 ]; then
    # O acervo é a interface: um nome que não está lá é engano de digitação no
    # conf, ou um mascote que ela apagou.
⟪para⟫
  proximo="$(_indice_de "$_quer")"
  if [ "$proximo" -lt 0 ]; then
    # O nome do conf é de outro pack (o Mimir com o Dracula no ar): vale o
    # mascote de fábrica do pack no ar para esta fase.
    _padrao="$(python3 "$RAIZ/scripts/pack.py" mascote-padrao "$(meow_pack_dir)" "$FASE" 2>/dev/null)"
    proximo="$(_indice_de "${_padrao:-}")"
    unset _padrao
  fi
  if [ "$proximo" -lt 0 ]; then
    # O acervo é a interface: um nome que não está lá é engano de digitação no
    # conf, ou um mascote que ela apagou.
⟪fim⟫
⟪arquivo⟫ scripts/midia_build.sh
⟪de⟫
  if [ "$compilou" = 0 ] && ! CARGO_TARGET_DIR="$ALVO" cargo build --release --locked \
        --manifest-path "$ARVORE/Cargo.toml" >"$ESTADO/compilar.log" 2>&1; then
    meow_erro "o cargo falhou — provável deriva do libcosmic (o Cargo.toml o aponta sem rev)"
    meow_info "  o registro está em $ESTADO/compilar.log"
    meow_info "  o binário anterior segue instalado e funcionando; nada foi trocado"
⟪para⟫
  if [ "$compilou" = 0 ] && ! CARGO_TARGET_DIR="$ALVO" cargo build --release --locked \
        --manifest-path "$ARVORE/Cargo.toml" >"$ESTADO/compilar.log" 2>&1; then
    meow_erro "o cargo falhou — $(meow_motivo_do_cargo "$ESTADO/compilar.log")"
    meow_info "  o registro está em $ESTADO/compilar.log"
    meow_info "  o binário anterior segue instalado e funcionando; nada foi trocado"
⟪fim⟫
⟪arquivo⟫ scripts/pack.py
⟪de⟫
    # Os papéis de parede do pack: o `wallpaper.sh` os semeia pelo `acervo`,
    # rasterizando o SVG.
    "origens.wallpapers.desenhos",
    # O que o pack esconde do lançador: o `ocultar_apps.sh` pergunta pelo verbo
    # `ocultar`.
⟪para⟫
    # Os papéis de parede do pack: o `wallpaper.sh` os semeia pelo `acervo`,
    # rasterizando o SVG.
    "origens.wallpapers.desenhos", "origens.wallpapers.repo",     # `origem_dos_wallpapers`
    "origens.wallpapers.commit", "origens.wallpapers.prefixo",
    "origens.wallpapers.curadoria", "origens.wallpapers.ignorar",
    "origens.wallpapers.repo_do_conf", "origens.wallpapers.commit_do_conf",
    "mascote.desenhos", "mascote.dia", "mascote.noite",   # `pasta_do_mascote`, `mascote_padrao`
    # O que o pack esconde do lançador: o `ocultar_apps.sh` pergunta pelo verbo
    # `ocultar`.
⟪fim⟫
⟪arquivo⟫ scripts/pack.py
⟪de⟫
    "prompt": "prompt",
    "fastfetch": "fastfetch",
    "gatos": "gatos",
}

⟪para⟫
    "prompt": "prompt",
    "fastfetch": "fastfetch",
    "mascote": "mascote",
}

⟪fim⟫
⟪arquivo⟫ scripts/pack.py
⟪de⟫
    "prompt": "assets/prompt/",
    "fastfetch": "assets/fastfetch/",
    "gatos": "packs/meowsystem/mascote/",
}

⟪para⟫
    "prompt": "assets/prompt/",
    "fastfetch": "assets/fastfetch/",
}

⟪fim⟫
⟪arquivo⟫ scripts/pack.py
⟪de⟫
                       (CATEGORIA_BASE, ic.get("base")),
                       ("cursores", org.get("cursores")), ("wallpapers", org.get("wallpapers")),
                       ("apps", p.get("apps")),
                       ("som", p.get("som")), (CATEGORIA_FONTES, p.get(CATEGORIA_FONTES))] \
⟪para⟫
                       (CATEGORIA_BASE, ic.get("base")),
                       ("cursores", org.get("cursores")), ("wallpapers", org.get("wallpapers")),
                       ("mascote", p.get("mascote")),
                       ("apps", p.get("apps")),
                       ("som", p.get("som")), (CATEGORIA_FONTES, p.get(CATEGORIA_FONTES))] \
⟪fim⟫
⟪arquivo⟫ scripts/pack.py
⟪de⟫
        #
        # O menor passo verdadeiro é a tabela dizer de onde a imagem sai.
        if cat == "wallpapers":
            desenhos = bloco.get("desenhos") if isinstance(bloco, dict) else None
            proprio = isinstance(desenhos, str) and dir_pack_info and \
⟪para⟫
        #
        # O menor passo verdadeiro é a tabela dizer de onde a imagem sai.
        if cat in ("wallpapers", "mascote"):
            desenhos = bloco.get("desenhos") if isinstance(bloco, dict) else None
            proprio = isinstance(desenhos, str) and dir_pack_info and \
⟪fim⟫
⟪arquivo⟫ scripts/pack.py
⟪de⟫


def main(argv):
    if len(argv) < 2:
⟪para⟫


def _na_cadeia(trilha, ref=None):
    """O valor de `trilha` no pack ou no primeiro da herança que o declara."""
    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        if not achar(ref):
            break
        valor = campo(ref, trilha)
        if valor not in (None, ""):
            return ref, valor
        ref = campo(ref, "heranca")
    valor = campo(PACK_BASE, trilha)
    return (PACK_BASE, valor) if valor not in (None, "") else (None, None)


def pasta_do_mascote(ref=None):
    """A pasta `mascote/` do pack, pela herança; sem nenhuma, a do pack-base."""
    achado = acervo("mascote.desenhos", ref=ref) if ref is None or ref else None
    if not achado:
        achado = acervo("mascote.desenhos", ref=PACK_BASE)
    return (achado or os.path.join(RAIZ, "packs", PACK_BASE, "mascote")).rstrip(os.sep)


def mascote_padrao(fase, ref=None):
    """O mascote de fábrica do pack para a fase (`dia`/`noite`) do modo `hora`."""
    ref = ref or None
    return _na_cadeia("mascote." + fase, ref)[1] or ""


def origem_dos_wallpapers(ref=None):
    """`origens.wallpapers` do pack (ou da herança), com os caminhos já absolutos."""
    ref = ref or None
    dono, decl = _na_cadeia("origens.wallpapers", ref)
    if not isinstance(decl, dict):
        return {}
    dir_pack = achar(dono) or ""
    saida = {"pack": dono}
    for chave, valor in decl.items():
        if chave.startswith("_") or isinstance(valor, (dict, list)) and chave != "ignorar":
            continue
        if chave in ("desenhos", "curadoria"):
            alvo = _dentro(dir_pack, valor, "origens.wallpapers." + chave)
            if not os.path.exists(alvo):
                continue
            valor = alvo
        elif chave == "ignorar":
            valor = " ".join(valor)
        saida[chave] = valor
    return saida


def main(argv):
    if len(argv) < 2:
⟪fim⟫
⟪arquivo⟫ scripts/pack.py
⟪de⟫
            print(f"valor={valor}")
            return OK
        if verbo == "acervo" and len(argv) in (4, 5):
            # Sem `motor` de propósito: quem chama do shell tem o
⟪para⟫
            print(f"valor={valor}")
            return OK
        if verbo == "mascote" and len(argv) in (2, 3):
            print(pasta_do_mascote(argv[2] if len(argv) == 3 else None))
            return OK
        if verbo == "mascote-padrao" and len(argv) == 4 and argv[3] in ("dia", "noite"):
            nome = mascote_padrao(argv[3], argv[2])
            if not nome:
                return RECUSADO
            print(nome)
            return OK
        if verbo == "wallpapers" and len(argv) == 3:
            for chave, valor in sorted(origem_dos_wallpapers(argv[2]).items()):
                print(f"{chave}={valor}")
            return OK
        if verbo == "acervo" and len(argv) in (4, 5):
            # Sem `motor` de propósito: quem chama do shell tem o
⟪fim⟫
⟪arquivo⟫ scripts/ponte_root.sh
⟪de⟫
#   `instalar_fontes.sh` os nomeava como faltando e não tinha a quem pedir.]
pacotes)
  PERMITIDOS=" librsvg2-bin imagemagick libgtk-3-bin python3 git btop bat papirus-icon-theme python3-numpy curl xz-utils unzip pop-fonts "
  pedidos=()
  while IFS= read -r nome || [ -n "${nome:-}" ]; do
⟪para⟫
#   `instalar_fontes.sh` os nomeava como faltando e não tinha a quem pedir.]
pacotes)
  PERMITIDOS=" librsvg2-bin imagemagick libgtk-3-bin python3 git btop bat papirus-icon-theme python3-numpy curl xz-utils unzip pop-fonts build-essential pkg-config libxkbcommon-dev libwayland-dev libdbus-1-dev software-properties-common "
  pedidos=()
  while IFS= read -r nome || [ -n "${nome:-}" ]; do
⟪fim⟫
⟪arquivo⟫ scripts/prompt.sh
⟪de⟫
# porque é o padrão do Pop!_OS.
_prompt_dizer_ligacao() {
  meow_info "para o prompt aparecer, o seu shell precisa iniciar o starship — é uma linha sua:"
  meow_info "  zsh  (no seu .zshrc):   eval \"\$(starship init zsh)\""
  meow_info "  bash (no seu .bashrc):  eval \"\$(starship init bash)\""
  meow_info "o MeowSystem não lê nem escreve arquivo de shell"
}

⟪para⟫
# porque é o padrão do Pop!_OS.
_prompt_dizer_ligacao() {
  meow_info "o terminal liga o starship pelo bloco do MeowSystem (scripts/terminal_bloco.sh)"
}

⟪fim⟫
⟪arquivo⟫ scripts/prompt.sh
⟪de⟫
# --- mostrar ----------------------------------------------------------------
cmd_mostrar() {
  meow_titulo "A linha que liga o starship — o MeowSystem NÃO a escreve"
  printf '\n'
  _prompt_dizer_ligacao
⟪para⟫
# --- mostrar ----------------------------------------------------------------
cmd_mostrar() {
  meow_titulo "O que liga o starship"
  printf '\n'
  _prompt_dizer_ligacao
⟪fim⟫
⟪arquivo⟫ scripts/temas-de-apps/btop-bat/manifesto.sh
⟪de⟫
MEOW_BB_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# ═══════════════════════════════════════════════════════════════════════════
# auxiliares privados (prefixo _bb_ para não colidir com o runner)
⟪para⟫
MEOW_BB_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Os temas vendorizados moram no pack que os traz (o Catppuccin no meowsystem,
# o Dracula no dracula): vale a pasta do pack que tem o tema do flavor.
_bb_up() {
  local d f; f="$(_bb_flavor)"
  for d in "${MEOW_RAIZ:-$MEOW_BB_DIR/../../..}"/packs/*/temas-de-apps/btop-bat/upstream; do
    if [ -f "$d/btop/$f.theme" ] || compgen -G "$d/btop/*_$f.theme" >/dev/null; then
      printf '%s' "$d"; return 0
    fi
  done
  printf '%s' "${MEOW_RAIZ:-$MEOW_BB_DIR/../../..}/packs/meowsystem/temas-de-apps/btop-bat/upstream"
}

# ═══════════════════════════════════════════════════════════════════════════
# auxiliares privados (prefixo _bb_ para não colidir com o runner)
⟪fim⟫
⟪arquivo⟫ scripts/temas-de-apps/btop-bat/manifesto.sh
⟪de⟫
  local f arq
  f="$(_bb_flavor)"
  if [ -f "$MEOW_BB_DIR/upstream/btop/$f.theme" ]; then printf '%s' "$f"; return 0; fi
  for arq in "$MEOW_BB_DIR/upstream/btop/"*_"$f.theme"; do
    if [ -f "$arq" ]; then
      arq="${arq##*/}"
⟪para⟫
  local f arq
  f="$(_bb_flavor)"
  if [ -f "$(_bb_up)/btop/$f.theme" ]; then printf '%s' "$f"; return 0; fi
  for arq in "$(_bb_up)/btop/"*_"$f.theme"; do
    if [ -f "$arq" ]; then
      arq="${arq##*/}"
⟪fim⟫
⟪arquivo⟫ scripts/temas-de-apps/btop-bat/manifesto.sh
⟪de⟫
  printf '%s %s' "$(_bb_familia_titulo)" "$f_tit"
}
_bb_bat_tema_arquivo() { printf '%s/upstream/bat/%s.tmTheme' "$MEOW_BB_DIR" "$(_bb_bat_tema_nome)"; }

# Stem do tema btop — é isto que vai na chave color_theme.
⟪para⟫
  printf '%s %s' "$(_bb_familia_titulo)" "$f_tit"
}
_bb_bat_tema_arquivo() { printf '%s/bat/%s.tmTheme' "$(_bb_up)" "$(_bb_bat_tema_nome)"; }

# Stem do tema btop — é isto que vai na chave color_theme.
⟪fim⟫
⟪arquivo⟫ scripts/temas-de-apps/btop-bat/manifesto.sh
⟪de⟫
_bb_btop_upstream() {
  if [ "$(_bb_flavor)" = "$(_bb_familia)" ]; then
    printf '%s/upstream/btop/%s.theme' "$MEOW_BB_DIR" "$(_bb_flavor)"
  else
    printf '%s/upstream/btop/%s_%s.theme' "$MEOW_BB_DIR" "$(_bb_familia)" "$(_bb_flavor)"
  fi
}
⟪para⟫
_bb_btop_upstream() {
  if [ "$(_bb_flavor)" = "$(_bb_familia)" ]; then
    printf '%s/btop/%s.theme' "$(_bb_up)" "$(_bb_flavor)"
  else
    printf '%s/btop/%s_%s.theme' "$(_bb_up)" "$(_bb_familia)" "$(_bb_flavor)"
  fi
}
⟪fim⟫
⟪arquivo⟫ scripts/temas-de-apps/btop-bat/manifesto.sh
⟪de⟫
  local pior=0 bat_rc btop_rc
  if [ "$(_bb_presentes)" = "0" ]; then
    meow_pula "btop e bat não estão instalados — temas prontos em $MEOW_BB_DIR/upstream para o dia da instalação"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
⟪para⟫
  local pior=0 bat_rc btop_rc
  if [ "$(_bb_presentes)" = "0" ]; then
    meow_pula "btop e bat não estão instalados — temas prontos em $(_bb_up) para o dia da instalação"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
⟪fim⟫
⟪arquivo⟫ scripts/temas-de-apps/btop-bat/manifesto.sh
⟪de⟫
    git clone -q "$url" "$tmp/$nome" || { meow_erro "clone de $url falhou"; rm -rf "$tmp"; return "$MEOW_ERRO"; }
    git -C "$tmp/$nome" checkout -q "$commit" || { meow_erro "commit $commit não existe em $url"; rm -rf "$tmp"; return "$MEOW_ERRO"; }
    mkdir -p "$MEOW_BB_DIR/upstream/$nome"
    # shellcheck disable=SC2086
    cp -p "$tmp/$nome/$sub"/$glob "$MEOW_BB_DIR/upstream/$nome/" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
    meow_ok "$nome rebaixado em ${commit:0:8}"
  done
  rm -rf "$tmp"
  ( cd "$MEOW_BB_DIR" && find upstream -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS )
  meow_ok "SHA256SUMS regravado"
  return "$MEOW_OK"
⟪para⟫
    git clone -q "$url" "$tmp/$nome" || { meow_erro "clone de $url falhou"; rm -rf "$tmp"; return "$MEOW_ERRO"; }
    git -C "$tmp/$nome" checkout -q "$commit" || { meow_erro "commit $commit não existe em $url"; rm -rf "$tmp"; return "$MEOW_ERRO"; }
    mkdir -p "$MEOW_RAIZ/packs/meowsystem/temas-de-apps/btop-bat/upstream/$nome"
    # shellcheck disable=SC2086
    cp -p "$tmp/$nome/$sub"/$glob "$MEOW_RAIZ/packs/meowsystem/temas-de-apps/btop-bat/upstream/$nome/" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
    meow_ok "$nome rebaixado em ${commit:0:8}"
  done
  rm -rf "$tmp"
  ( cd "$MEOW_RAIZ/packs/meowsystem/temas-de-apps/btop-bat" && find upstream -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS )
  meow_ok "SHA256SUMS regravado"
  return "$MEOW_OK"
⟪fim⟫
⟪arquivo⟫ scripts/temas-de-apps/obsidian/manifesto.sh
⟪de⟫
# Raiz do módulo — resolvida a partir deste arquivo, que é `source`.
MEOW_OBSIDIAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# O que desce pela rede, uma pasta por pacote, com o sha256 dele no nome — ver
# "O TEMA SAI DO PACK NO AR", no topo. Mesmo endereço onde o módulo do Telegram
⟪para⟫
# Raiz do módulo — resolvida a partir deste arquivo, que é `source`.
MEOW_OBSIDIAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# O tema vendorizado mora no pack que o traz.
MEOW_OBSIDIAN_VENDOR="$(cd "$MEOW_OBSIDIAN_DIR/../../.." && pwd)/packs/meowsystem/temas-de-apps/obsidian/vendor"
# O que desce pela rede, uma pasta por pacote, com o sha256 dele no nome — ver
# "O TEMA SAI DO PACK NO AR", no topo. Mesmo endereço onde o módulo do Telegram
⟪fim⟫
⟪arquivo⟫ scripts/temas-de-apps/obsidian/manifesto.sh
⟪de⟫
  fi
  if [ -z "$_OBS_URL" ]; then
    MEOW_OBSIDIAN_FONTE="$MEOW_OBSIDIAN_DIR/vendor/$MEOW_OBSIDIAN_TEMA"
    # O único motivo daqui que não é da máquina dela: ou o repositório chegou
    # incompleto, ou o pack pede um tema que o motor não traz e não diz de onde
    # ele desce. Nos dois, do lado dela não há o que consertar (3, e não 2).
    if [ ! -f "$MEOW_OBSIDIAN_FONTE/theme.css" ] || [ ! -f "$MEOW_OBSIDIAN_FONTE/manifest.json" ]; then
      meow_app_sem "obsidian: o pack $_OBS_PACK_NOME pede o tema '$MEOW_OBSIDIAN_TEMA', que não está em $MEOW_OBSIDIAN_DIR/vendor e não tem origem para descer"
      return
    fi
⟪para⟫
  fi
  if [ -z "$_OBS_URL" ]; then
    MEOW_OBSIDIAN_FONTE="$MEOW_OBSIDIAN_VENDOR/$MEOW_OBSIDIAN_TEMA"
    # O único motivo daqui que não é da máquina dela: ou o repositório chegou
    # incompleto, ou o pack pede um tema que o motor não traz e não diz de onde
    # ele desce. Nos dois, do lado dela não há o que consertar (3, e não 2).
    if [ ! -f "$MEOW_OBSIDIAN_FONTE/theme.css" ] || [ ! -f "$MEOW_OBSIDIAN_FONTE/manifest.json" ]; then
      meow_app_sem "obsidian: o pack $_OBS_PACK_NOME pede o tema '$MEOW_OBSIDIAN_TEMA', que não está em $MEOW_OBSIDIAN_VENDOR e não tem origem para descer"
      return
    fi
⟪fim⟫
⟪arquivo⟫ scripts/temas-de-apps/obsidian/manifesto.sh
⟪de⟫
# sai do manifest de cada um — é a pasta em `themes/` e o `cssTheme`.
_meow_obsidian_nossos() {
  python3 -I - "$MEOW_OBSIDIAN_DIR/vendor" "$MEOW_OBSIDIAN_BAIXADOS" <<'PYFIM' 2>/dev/null
import json, os, sys

⟪para⟫
# sai do manifest de cada um — é a pasta em `themes/` e o `cssTheme`.
_meow_obsidian_nossos() {
  python3 -I - "$MEOW_OBSIDIAN_VENDOR" "$MEOW_OBSIDIAN_BAIXADOS" <<'PYFIM' 2>/dev/null
import json, os, sys

⟪fim⟫
⟪arquivo⟫ scripts/temas-de-apps/toolkits-gtk-qt/manifesto.sh
⟪de⟫
MEOW_TK_GTK4_CSS="$HOME/.config/gtk-4.0/gtk.css"
MEOW_TK_COSMIC_CSS_DIR="$HOME/.config/gtk-4.0/cosmic"
MEOW_TK_TK_DIR="$HOME/.config/cosmic/com.system76.CosmicTk/v1"
MEOW_TK_QT5_CONF="$HOME/.config/qt5ct/qt5ct.conf"
MEOW_TK_QT6_CONF="$HOME/.config/qt6ct/qt6ct.conf"
⟪para⟫
MEOW_TK_GTK4_CSS="$HOME/.config/gtk-4.0/gtk.css"
MEOW_TK_COSMIC_CSS_DIR="$HOME/.config/gtk-4.0/cosmic"
MEOW_TK_TK_DIR="$(meow_cosmic_dir)/com.system76.CosmicTk/$(meow_cosmic_v com.system76.CosmicTk)"
MEOW_TK_QT5_CONF="$HOME/.config/qt5ct/qt5ct.conf"
MEOW_TK_QT6_CONF="$HOME/.config/qt6ct/qt6ct.conf"
⟪fim⟫
⟪arquivo⟫ scripts/vigia_assets.sh
⟪de⟫
. "$RAIZ/lib/comum.sh"

ACERVO="$RAIZ/packs/meowsystem/mascote/"
ORIGEM="$RAIZ/systemd"
DESTINO="$HOME/.config/systemd/user"
⟪para⟫
. "$RAIZ/lib/comum.sh"

# O que o vigia olha: o mascote, os papéis de parede e os temas de apps do
# pack no ar e do pack-base, com as subpastas (o systemd olha uma pasta por linha).
_pastas_vigiadas() {
  local dir sub
  for dir in "$(meow_pack_dir)" "$RAIZ/packs/meowsystem"; do
    [ -n "$dir" ] && [ -d "$dir" ] || continue
    for sub in mascote wallpapers temas-de-apps; do
      [ -d "$dir/$sub" ] && find "$dir/$sub" -type d | LC_ALL=C sort
    done
  done | awk '!visto[$0]++'
}
ACERVO="$(meow_mascote_dir)/"
ORIGEM="$RAIZ/systemd"
DESTINO="$HOME/.config/systemd/user"
⟪fim⟫
⟪arquivo⟫ scripts/vigia_assets.sh
⟪de⟫
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
⟪para⟫
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --unidade) ;;
  --disparo) ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
⟪fim⟫
⟪arquivo⟫ scripts/vigia_assets.sh
⟪de⟫
  local u="$1" texto
  texto="$(cat "$ORIGEM/$u" 2>/dev/null)" || return 1
  [ "$u" = "$GATILHO" ] && texto="${texto//@ACERVO@/$ACERVO}"
  printf '%s' "$texto"
}
⟪para⟫
  local u="$1" texto
  texto="$(cat "$ORIGEM/$u" 2>/dev/null)" || return 1
  if [ "$u" = "$GATILHO" ]; then
    local linhas="" d
    while IFS= read -r d; do linhas+="PathModified=$d"$'\n'; done < <(_pastas_vigiadas)
    linhas="${linhas%$'\n'}"
    texto="${texto//PathModified=@ACERVO@/$linhas}"
  fi
  printf '%s' "$texto"
}
⟪fim⟫
⟪arquivo⟫ scripts/vigia_assets.sh
⟪de⟫
  # Sem o acervo não há o que vigiar, e apontar o `.path` para um diretório que
  # não existe no próprio clone seria instalar um vigia sem objeto.
  if [ ! -d "$ACERVO" ]; then
    meow_pula "não existe $ACERVO — nada a vigiar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
⟪para⟫
  # Sem o acervo não há o que vigiar, e apontar o `.path` para um diretório que
  # não existe no próprio clone seria instalar um vigia sem objeto.
  if [ -z "$(_pastas_vigiadas)" ]; then
    meow_pula "o pack no ar não tem mascote, papel de parede nem tema de app — nada a vigiar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
⟪fim⟫
⟪arquivo⟫ scripts/vigia_assets.sh
⟪de⟫
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "vigiando packs/meowsystem/mascote/ — mascote novo entra sem esperar o relógio"
  return "$MEOW_OK"
}
⟪para⟫
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "vigiando o mascote, os papéis de parede e os temas de apps do pack — a mudança entra sem esperar o relógio"
  return "$MEOW_OK"
}
⟪fim⟫
⟪arquivo⟫ scripts/vigia_assets.sh
⟪de⟫

  if [ "$mudou" = 0 ]; then
    meow_ok "vigia do acervo já ligado sobre packs/meowsystem/mascote/"
    return "$MEOW_OK"
  fi
  meow_ok "vigia ligado: soltou um .svg em packs/meowsystem/mascote/, ele entra na hora"
  meow_info "  o mascote novo aparece em segundos: dock (painel reciclado), terminal e menu"
  return "$MEOW_DIVERGENTE"
}

main() {
  [ "$VIGIA" = "sim" ] || { _desligar; return $?; }
  _pronto || return $?
⟪para⟫

  if [ "$mudou" = 0 ]; then
    meow_ok "vigia do pack já ligado sobre o mascote, os papéis de parede e os temas de apps"
    return "$MEOW_OK"
  fi
  meow_ok "vigia ligado: mudou um desenho do pack, o que sai dele se refaz na hora"
  meow_info "  o mascote novo aparece em segundos: dock (painel reciclado), terminal e menu"
  return "$MEOW_DIVERGENTE"
}

# O disparo do vigia: refaz o que sai do pack. Cada um só escreve o que mudou.
_disparo() {
  local rc pior=0
  "$RAIZ/scripts/logo.sh"; rc=$?; [ "$rc" = 1 ] && pior=1
  "$RAIZ/scripts/fastfetch_logo.sh" aplicar; rc=$?; [ "$rc" = 1 ] && pior=1
  "$RAIZ/scripts/wallpaper.sh" semear; rc=$?; [ "$rc" = 1 ] && pior=1
  if [ -n "${APPS_ATIVOS:-}" ]; then
    "$RAIZ/scripts/aplicar_apps.sh"; rc=$?; [ "$rc" = 1 ] && pior=1
  fi
  return "$pior"
}

main() {
  case "${1:-}" in
    --unidade) _texto_de "${2:-$GATILHO}"; return $? ;;
    --disparo) _disparo; return $? ;;
  esac
  [ "$VIGIA" = "sim" ] || { _desligar; return $?; }
  _pronto || return $?
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
    #   era o caso de uma imagem que ela já tinha banido antes desta sessão.
    esta_banida "$nome_dela" && continue
    meow_seco || cp -n "$img" "$destino" 2>/dev/null || continue
    n=$((n + 1))
  done < <(find "$origem" -maxdepth 1 -type f \
⟪para⟫
    #   era o caso de uma imagem que ela já tinha banido antes desta sessão.
    esta_banida "$nome_dela" && continue
    meow_seco || { meow_guardar_antes "$destino"; cp -n "$img" "$destino" 2>/dev/null; } || continue
    n=$((n + 1))
  done < <(find "$origem" -maxdepth 1 -type f \
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
  printf '%s' "$conteudo" > "$tmp" 2>/dev/null \
    && chmod 644 "$tmp" 2>/dev/null \
    && mv -f "$tmp" "$LUZ_TSV" 2>/dev/null \
    || rm -f "$tmp"
⟪para⟫
  printf '%s' "$conteudo" > "$tmp" 2>/dev/null \
    && chmod 644 "$tmp" 2>/dev/null \
    && meow_guardar_antes "$LUZ_TSV" \
    && mv -f "$tmp" "$LUZ_TSV" 2>/dev/null \
    || rm -f "$tmp"
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
    base="${arq##*/}"
    [ -n "${quer[$base]:-}" ] && [ "$arq" -ef "$ATIVOS/$base" ] && continue
    rm -f -- "$arq"
  done
⟪para⟫
    base="${arq##*/}"
    [ -n "${quer[$base]:-}" ] && [ "$arq" -ef "$ATIVOS/$base" ] && continue
    meow_guardar_antes "$arq"
    rm -f -- "$arq"
  done
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
  for base in "$@"; do
    [ -e "$dir/$base" ] && continue
    ln -f -- "$ATIVOS/$base" "$dir/$base" 2>/dev/null && continue
    # Outro sistema de arquivos, ou um `ln` que recusou. O simbólico é pior (o
⟪para⟫
  for base in "$@"; do
    [ -e "$dir/$base" ] && continue
    meow_guardar_antes "$dir/$base"
    ln -f -- "$ATIVOS/$base" "$dir/$base" 2>/dev/null && continue
    # Outro sistema de arquivos, ou um `ln` que recusou. O simbólico é pior (o
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
  if [ "${#LADO[@]}" -eq 0 ]; then
    [ -f "$LADO_TSV" ] || return 0
    rm -f -- "$LADO_TSV" 2>/dev/null || return 1
    return 0
⟪para⟫
  if [ "${#LADO[@]}" -eq 0 ]; then
    [ -f "$LADO_TSV" ] || return 0
    meow_guardar_antes "$LADO_TSV"
    rm -f -- "$LADO_TSV" 2>/dev/null || return 1
    return 0
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
  # parado em ativos/, com o script dizendo "banida". Se a cópia em banidos/ já
  # existe e é idêntica, o banimento anterior valeu: basta tirar daqui.
  if [ -e "$BASE/banidos/$nome" ] && cmp -s "$img" "$BASE/banidos/$nome"; then
    rm -f "$img"
⟪para⟫
  # parado em ativos/, com o script dizendo "banida". Se a cópia em banidos/ já
  # existe e é idêntica, o banimento anterior valeu: basta tirar daqui.
  meow_guardar_antes "$img"; meow_guardar_antes "$BASE/banidos/$nome"
  if [ -e "$BASE/banidos/$nome" ] && cmp -s "$img" "$BASE/banidos/$nome"; then
    rm -f "$img"
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
  #   trocado um defeito calado por outro.
  [ -e "$ATIVOS/$(basename "$img")" ] && return 1
  cp -n "$img" "$ATIVOS/" 2>/dev/null || return 1
  return 0
⟪para⟫
  #   trocado um defeito calado por outro.
  [ -e "$ATIVOS/$(basename "$img")" ] && return 1
  meow_guardar_antes "$ATIVOS/$(basename "$img")"
  cp -n "$img" "$ATIVOS/" 2>/dev/null || return 1
  return 0
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
    local tmp; tmp="$(mktemp -p "$(dirname "$BANIDOS_TXT")" ".atomicwrite.meow.XXXXXX")" || return "$MEOW_ERRO"
    grep -vxF -- "$nome" "$BANIDOS_TXT" > "$tmp" 2>/dev/null
    mv -f "$tmp" "$BANIDOS_TXT" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  fi
⟪para⟫
    local tmp; tmp="$(mktemp -p "$(dirname "$BANIDOS_TXT")" ".atomicwrite.meow.XXXXXX")" || return "$MEOW_ERRO"
    grep -vxF -- "$nome" "$BANIDOS_TXT" > "$tmp" 2>/dev/null
    meow_guardar_antes "$BANIDOS_TXT"
    mv -f "$tmp" "$BANIDOS_TXT" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  fi
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
#   do conf que ele lê levam o nome do pack (`WALLPAPER_DRACULA_*`).
_semente_do_flavor() {
  local dono
  dono="$(meow_pack_dir)"
  dono="${dono%/}"
  case "${dono##*/}" in
    dracula)
      # ACERVO AUTORAL, GERADO EM CÓDIGO — 15/09/2026
      #   Treze desenhos em PNG 4K (3840x2160), rasterizados do SVG que o gerador
      #   da casa (tulip-orchid) produz. Cada cena é função pura: recebe largura,
      #   altura e semente, devolve o SVG inteiro. Não há bitmap de origem nem
      #   material de terceiro embutido.
      #
      #   Isto SUBSTITUI `helpotters/dracula-wallpapers`, que era provisório por
      #   duas razões que aqui deixam de valer: aquele repositório não declara
      #   licença (créditos apontavam Freepik, que exige atribuição e não
      #   autoriza sublicenciar) e entregava 3440x1440, não 4K. Este é MIT e do
      #   próprio dono — as imagens podem, enfim, ser publicadas com o tema.
      #
      #   `svg/` fica de fora do rodízio: o semear já ignora a extensão, mas a
      #   pasta contaria como uma categoria que não existe e desequilibraria o
      #   sorteio entre catedral, cemiterio, noite e ornamento.
      #   O DONO DO ACERVO NÃO MORA NO CÓDIGO — e a primeira versão disto
      #   morava. O sanitizer de identidade do Spellbook redige qualquer
      #   ocorrência do `user.name` do git nos arquivos que entram num commit, e
      #   está certo: este é repositório de DUAS pessoas, e cravar o usuário do
      #   GitHub de uma delas aqui é exatamente o que ele existe para impedir.
      #   Cravado, virou `[REDACTED]/tulip-orchid-wallpapers` e a semeadura
      #   passou a responder "não consegui falar com o GitHub".
      #
      #   O `dono/repo` vem do conf (`WALLPAPER_DRACULA_REPO`), que não é
      #   versionado. Sem ele configurado, o flavor cai no acervo comum em vez
      #   de quebrar: quem instala o tema sem ter um acervo próprio continua
      #   tendo papel de parede.
      #   O PACK TRAZ OS VETORES — 09/10/2026, P74 item 9 (T7). Sem o repositório
      #   no conf (o caso de toda instalação nova: o exemplo vem vazio, e o
      #   `dono/repo` não pode morar no código), o Dracula caía no acervo do
      #   CATPPUCCIN — «ao resetar o PC terei tudo conforme o tema dracula?»
      #   (26/09), e não teria. Os treze SVG do tulip-orchid moram agora em
      #   `packs/dracula/wallpapers/` (445 KB, MIT, a procedência no
      #   PROCEDENCIA.md do pack), e o `_semear_de_pasta` os rasteriza em PNG
      #   4K, o formato que o `cosmic-bg` lê. Medido no dia: o PNG que sai do
      #   `rsvg-convert -w 3840 -h 2160` é o do repositório pixel a pixel (RMSE
      #   0 contra o `tulip-catedral-agulhas.png` desta máquina), e com o mesmo
      #   nome — a casa que já os tem não ganha cópia nenhuma. O repositório no
      #   conf continua vencendo: é a escolha de quem o pôs lá.
      local do_pack=""
      do_pack="$(python3 "$RAIZ/scripts/pack.py" acervo "$dono" origens.wallpapers.desenhos 2>/dev/null)" || do_pack=""
      if [ -n "${WALLPAPER_DRACULA_REPO:-}" ]; then
        SEMENTE_REPO_PADRAO="$WALLPAPER_DRACULA_REPO"
        SEMENTE_COMMIT_PADRAO="${WALLPAPER_DRACULA_COMMIT:-}"
        SEMENTE_IGNORAR_PADRAO="${WALLPAPER_DRACULA_IGNORAR:-svg}"
        SEMENTE_PREFIXO_PADRAO="${WALLPAPER_DRACULA_PREFIXO:-tulip}"
        if [ -z "$SEMENTE_COMMIT_PADRAO" ] && ! _semente_e_pasta "$SEMENTE_REPO_PADRAO"; then
          meow_aviso "WALLPAPER_DRACULA_REPO sem WALLPAPER_DRACULA_COMMIT — sem pino não há receita"
        fi
      elif [ -n "$do_pack" ] && [ -d "$do_pack" ]; then
        SEMENTE_REPO_PADRAO="${do_pack%/}"
        SEMENTE_COMMIT_PADRAO=""
        SEMENTE_IGNORAR_PADRAO=""
        SEMENTE_PREFIXO_PADRAO="${WALLPAPER_DRACULA_PREFIXO:-tulip}"
      else
        SEMENTE_REPO_PADRAO="zhichaoh/catppuccin-wallpapers"
        SEMENTE_COMMIT_PADRAO="1023077979591cdeca76aae94e0359da1707a60e"
        SEMENTE_IGNORAR_PADRAO=""
        SEMENTE_PREFIXO_PADRAO="cat"
      fi
      ;;
    *)
      SEMENTE_REPO_PADRAO="zhichaoh/catppuccin-wallpapers"
      SEMENTE_COMMIT_PADRAO="1023077979591cdeca76aae94e0359da1707a60e"
      SEMENTE_IGNORAR_PADRAO=""
      SEMENTE_PREFIXO_PADRAO="cat"
      ;;
  esac
}

# `/`, `~` ou `./` no começo: é caminho, não `dono/repo`.
# MORA ANTES DA CHAMADA DE BAIXO, E NÃO AO LADO DO `_semear_de_pasta` — 24/09/2026,
# sprint P45. O `_semente_do_flavor` roda no carregamento do script, e o ramo
# `dracula)` dele pergunta a esta função; o bash só conhece a função depois de
# ler a definição. Ela morava 120 linhas abaixo: medido numa casa de brinquedo,
# `WALLPAPER_DRACULA_REPO` apontando para uma pasta e sem COMMIT imprimia
# `_semente_e_pasta: command not found` e o aviso "sem pino não há receita",
# que para pasta é falso — pasta não tem commit para pinar.
_semente_e_pasta() {
  case "$1" in
⟪para⟫
#   do conf que ele lê levam o nome do pack (`WALLPAPER_DRACULA_*`).
_semente_do_flavor() {
  # A ORIGEM É DO PACK: `origens.wallpapers` no pack.json do pack no ar (ou da
  # herança) diz de onde a coleção desce — a pasta `desenhos` do próprio pack ou
  # um `repo` com `commit` pinado — e a `curadoria` dele. O repositório no conf
  # (`<repo_do_conf>`, `<commit_do_conf>`) continua vencendo: é escolha de quem o pôs lá.
  local linhas chave valor repo="" commit="" desenhos="" prefixo="" ignorar="" curadoria=""
  local repo_conf="" commit_conf=""
  linhas="$(python3 "$RAIZ/scripts/pack.py" wallpapers "$(meow_pack_dir)" 2>/dev/null)" || linhas=""
  while IFS='=' read -r chave valor; do
    case "$chave" in
      repo) repo="$valor" ;; commit) commit="$valor" ;; desenhos) desenhos="$valor" ;;
      prefixo) prefixo="$valor" ;; ignorar) ignorar="$valor" ;; curadoria) curadoria="$valor" ;;
      repo_do_conf) repo_conf="${!valor:-}" ;; commit_do_conf) commit_conf="${!valor:-}" ;;
    esac
  done <<< "$linhas"
  SEMENTE_PREFIXO_PADRAO="${prefixo:-cat}"
  SEMENTE_IGNORAR_PADRAO=""
  SEMENTE_CURADORIA_PADRAO="$curadoria"
  if [ -n "$repo_conf" ]; then
    SEMENTE_REPO_PADRAO="$repo_conf"
    SEMENTE_COMMIT_PADRAO="$commit_conf"
    SEMENTE_IGNORAR_PADRAO="$ignorar"
    if [ -z "$SEMENTE_COMMIT_PADRAO" ] && ! _semente_e_pasta "$SEMENTE_REPO_PADRAO"; then
      meow_aviso "o repositório de papel de parede do conf está sem commit — sem pino não há receita"
    fi
  elif [ -n "$desenhos" ] && [ -d "$desenhos" ]; then
    SEMENTE_REPO_PADRAO="${desenhos%/}"
    SEMENTE_COMMIT_PADRAO=""
  else
    SEMENTE_REPO_PADRAO="$repo"
    SEMENTE_COMMIT_PADRAO="$commit"
  fi
}

_semente_e_pasta() {
  case "$1" in
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
# do bloco acima, voltaria com as 242 do upstream inteiras. Os dois juntos são a
# curadoria — um diz o que ela quer, o outro o que ela não quer.
FONTES_TSV="${WALLPAPER_FONTES:-$RAIZ/packs/meowsystem/wallpapers/FONTES.tsv}"
CURADORIA_N=0

⟪para⟫
# do bloco acima, voltaria com as 242 do upstream inteiras. Os dois juntos são a
# curadoria — um diz o que ela quer, o outro o que ela não quer.
FONTES_TSV="${WALLPAPER_FONTES:-$SEMENTE_CURADORIA_PADRAO}"
CURADORIA_N=0

⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
    local tmp; tmp="$(mktemp -p "$ATIVOS" ".meow.XXXXXX")"
    if curl -sSL --max-time 90 -o "$tmp" "$url" 2>/dev/null && [ -s "$tmp" ]; then
      mv -f "$tmp" "$destino"; CURADORIA_N=$((CURADORIA_N + 1))
    else
      rm -f "$tmp"; falhas=$((falhas + 1))
⟪para⟫
    local tmp; tmp="$(mktemp -p "$ATIVOS" ".meow.XXXXXX")"
    if curl -sSL --max-time 90 -o "$tmp" "$url" 2>/dev/null && [ -s "$tmp" ]; then
      meow_guardar_antes "$destino"; mv -f "$tmp" "$destino"; CURADORIA_N=$((CURADORIA_N + 1))
    else
      rm -f "$tmp"; falhas=$((falhas + 1))
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
    [ "$vetor" = 1 ] && nome="${nome%.*}.png"
    destino="$ATIVOS/$nome"
    [ -e "$destino" ] && continue
    esta_banida "$nome" && continue
    if meow_seco; then
⟪para⟫
    [ "$vetor" = 1 ] && nome="${nome%.*}.png"
    destino="$ATIVOS/$nome"
    # O desenho do pack mudou depois da cópia: refaz (decisão 15, o derivado segue a fonte).
    [ -e "$destino" ] && [ ! "$arq" -nt "$destino" ] && continue
    esta_banida "$nome" && continue
    if meow_seco; then
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
    if [ "$vetor" = 1 ]; then
      if rsvg-convert -w 3840 -h 2160 -f png -o "$tmp" -- "$arq" 2>/dev/null && [ -s "$tmp" ]; then
        mv -f "$tmp" "$destino"; n=$((n + 1))
      else
        rm -f "$tmp"
⟪para⟫
    if [ "$vetor" = 1 ]; then
      if rsvg-convert -w 3840 -h 2160 -f png -o "$tmp" -- "$arq" 2>/dev/null && [ -s "$tmp" ]; then
        meow_guardar_antes "$destino"; mv -f "$tmp" "$destino"; n=$((n + 1))
      else
        rm -f "$tmp"
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
    fi
    if cp -- "$arq" "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      mv -f "$tmp" "$destino"; n=$((n + 1))
    else
      rm -f "$tmp"
⟪para⟫
    fi
    if cp -- "$arq" "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      meow_guardar_antes "$destino"; mv -f "$tmp" "$destino"; n=$((n + 1))
    else
      rm -f "$tmp"
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
}

cmd_semear() {
  meow_tem python3 || { meow_erro "python3 não encontrado"; return "$MEOW_SEM_DEPENDENCIA"; }
  criar_pastas

  # UMA PASTA TAMBÉM É SEMENTE — 15/09/2026
⟪para⟫
}

# O acervo sem nenhuma imagem do pack no ar (casa nova, ou troca de pack) se
# semeia da origem dele (precisa de rede). Uma tentativa por origem (a marca
# guarda qual); com menos de duas imagens tenta sempre. Quem chama é o install
# e o conserto do doctor, não o relógio do carrossel.
cmd_semear_se_faltar() {
  local n marca="$MEOW_ESTADO/wallpaper-semeado" rc
  [ -n "$SEMENTE_REPO" ] || return "$MEOW_OK"
  compgen -G "$ATIVOS/${SEMENTE_PREFIXO}-*" >/dev/null && return "$MEOW_OK"
  n="$(quantas 2>/dev/null)"; n="${n:-0}"
  [ "$n" -lt 2 ] || [ "$(cat "$marca" 2>/dev/null)" != "$SEMENTE_REPO" ] || return "$MEOW_OK"
  if meow_seco; then
    meow_muda "semearia os papéis de parede do pack no ar (precisa de rede)"
    return "$MEOW_DIVERGENTE"
  fi
  cmd_semear; rc=$?
  mkdir -p "$MEOW_ESTADO" && printf '%s\n' "$SEMENTE_REPO" > "$marca"
  return "$rc"
}

cmd_semear() {
  meow_tem python3 || { meow_erro "python3 não encontrado"; return "$MEOW_SEM_DEPENDENCIA"; }
  criar_pastas

  if [ -z "$SEMENTE_REPO" ]; then
    meow_pula "o pack no ar não declara de onde descem os papéis de parede"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # UMA PASTA TAMBÉM É SEMENTE — 15/09/2026
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
    local tmp; tmp="$(mktemp -p "$ATIVOS" ".meow.XXXXXX")"
    if curl -sSL --max-time 60 -o "$tmp" "$base/$caminho_url" 2>/dev/null && [ -s "$tmp" ]; then
      mv -f "$tmp" "$destino"; n=$((n+1))
    else
      rm -f "$tmp"; falhas=$((falhas + 1))
⟪para⟫
    local tmp; tmp="$(mktemp -p "$ATIVOS" ".meow.XXXXXX")"
    if curl -sSL --max-time 60 -o "$tmp" "$base/$caminho_url" 2>/dev/null && [ -s "$tmp" ]; then
      meow_guardar_antes "$destino"; mv -f "$tmp" "$destino"; n=$((n+1))
    else
      rm -f "$tmp"; falhas=$((falhas + 1))
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
  fi
  criar_pastas || return "$MEOW_ERRO"
  cp -f -- "$img" "$BASE/favoritos/$nome" || return "$MEOW_ERRO"
  meow_ok "favorita: $nome — a cópia está em favoritos/, e ela segue girando"
⟪para⟫
  fi
  criar_pastas || return "$MEOW_ERRO"
  meow_guardar_antes "$BASE/favoritos/$nome"
  cp -f -- "$img" "$BASE/favoritos/$nome" || return "$MEOW_ERRO"
  meow_ok "favorita: $nome — a cópia está em favoritos/, e ela segue girando"
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
    return "$MEOW_DIVERGENTE"
  fi
  rm -f -- "$BASE/favoritos/$nome" || return "$MEOW_ERRO"
  meow_ok "$nome saiu das favoritas; a imagem de ativos/ fica"
⟪para⟫
    return "$MEOW_DIVERGENTE"
  fi
  meow_guardar_antes "$BASE/favoritos/$nome"
  rm -f -- "$BASE/favoritos/$nome" || return "$MEOW_ERRO"
  meow_ok "$nome saiu das favoritas; a imagem de ativos/ fica"
⟪fim⟫
⟪arquivo⟫ scripts/wallpaper.sh
⟪de⟫
  estado)    cmd_estado ;;
  semear)    cmd_semear ;;
  banir)     shift; cmd_banir "${1:-}" ;;
  desbanir)  shift; cmd_desbanir "${1:-}" ;;
⟪para⟫
  estado)    cmd_estado ;;
  semear)    cmd_semear ;;
  semear-se-faltar) cmd_semear_se_faltar ;;
  banir)     shift; cmd_banir "${1:-}" ;;
  desbanir)  shift; cmd_desbanir "${1:-}" ;;
⟪fim⟫
⟪arquivo⟫ systemd/meow-assets.path
⟪de⟫

[Unit]
Description=MeowSystem — vigia packs/meowsystem/mascote/ e põe o mascote novo na rotação
Documentation=man:systemd.path(5)

⟪para⟫

[Unit]
Description=MeowSystem — vigia o mascote, os papéis de parede e os temas de apps do pack
Documentation=man:systemd.path(5)

⟪fim⟫
⟪arquivo⟫ systemd/meow-assets.service
⟪de⟫

[Unit]
Description=MeowSystem — o mascote novo do acervo entra na rotação
Documentation=file:%h/.local/state/meowsystem/raiz
ConditionPathExists=%h/.local/state/meowsystem/raiz
⟪para⟫

[Unit]
Description=MeowSystem — o que sai do pack (mascote, papel de parede, temas de apps) se refaz
Documentation=file:%h/.local/state/meowsystem/raiz
ConditionPathExists=%h/.local/state/meowsystem/raiz
⟪fim⟫
⟪arquivo⟫ systemd/meow-assets.service
⟪de⟫
#   máquina onde o `install.sh` ainda não passou este serviço falhava em vez de
#   sair calado — que é o contrato de todas as outras unidades daqui.
ExecStart=/usr/bin/flock -w 60 -E 0 %h/.local/state/meowsystem/lock /bin/sh -c 'R=$(cat %h/.local/state/meowsystem/raiz); [ -x "$R/scripts/logo.sh" ] || exit 0; C=%h/.config/meow/meow.conf; set -a; [ -f "$C" ] && . "$C"; set +a; exec "$R/scripts/logo.sh"'

# 1 é "estava divergente e eu consertei" — o código que o `logo.sh` devolve
⟪para⟫
#   máquina onde o `install.sh` ainda não passou este serviço falhava em vez de
#   sair calado — que é o contrato de todas as outras unidades daqui.
ExecStart=/usr/bin/flock -w 60 -E 0 %h/.local/state/meowsystem/lock /bin/sh -c 'R=$(cat %h/.local/state/meowsystem/raiz); [ -x "$R/scripts/logo.sh" ] || exit 0; C=%h/.config/meow/meow.conf; set -a; [ -f "$C" ] && . "$C"; set +a; exec "$R/scripts/vigia_assets.sh" --disparo'

# 1 é "estava divergente e eu consertei" — o código que o `logo.sh` devolve
⟪fim⟫
⟪arquivo⟫ systemd/meow-assets.service
⟪de⟫
#   corpo se partia em três argumentos, e o `notify-send` recusa o excesso. Aspa
#   simples também não serve (o systemd já usou as dela). Texto sem aspas resolve.
ExecStopPost=-/bin/sh -c '[ "$EXIT_STATUS" = 1 ] || exit 0; C=%h/.config/meow/meow.conf; [ -f "$C" ] && . "$C"; [ "${ASSETS_VIGIA_NOTIFICAR:-sim}" = sim ] || exit 0; exec /usr/bin/notify-send -a MeowSystem -i preferences-desktop-theme "MeowSystem" "O acervo de mascotes mudou e já está no ar — dock, terminal e menu de lançamento. meow logo listar mostra quem está desenhado."'

# Um vigia travado seguraria o disparo seguinte. Isto aqui lê uma pasta e escreve
⟪para⟫
#   corpo se partia em três argumentos, e o `notify-send` recusa o excesso. Aspa
#   simples também não serve (o systemd já usou as dela). Texto sem aspas resolve.
ExecStopPost=-/bin/sh -c '[ "$EXIT_STATUS" = 1 ] || exit 0; C=%h/.config/meow/meow.conf; [ -f "$C" ] && . "$C"; [ "${ASSETS_VIGIA_NOTIFICAR:-sim}" = sim ] || exit 0; exec /usr/bin/notify-send -a MeowSystem -i preferences-desktop-theme "MeowSystem" "O pack mudou e já está no ar — mascote, papel de parede e temas de apps."'

# Um vigia travado seguraria o disparo seguinte. Isto aqui lê uma pasta e escreve
⟪fim⟫
⟪arquivo⟫ tests/acervo-da-ficha.sh
⟪de⟫
#   simbólico não são ícone de programa.]
FORA = {"pastas", "mimetypes", "previa-arcticons", "upstream", "tray-terceiros", "wallpapers",
        "sistema"}
versionados = subprocess.run(["git", "-C", raiz, "ls-files", "packs", "assets/icones"],
                             capture_output=True, text=True).stdout.split()
⟪para⟫
#   simbólico não são ícone de programa.]
FORA = {"pastas", "mimetypes", "previa-arcticons", "upstream", "tray-terceiros", "wallpapers",
        "sistema", "mascote"}
versionados = subprocess.run(["git", "-C", raiz, "ls-files", "packs", "assets/icones"],
                             capture_output=True, text=True).stdout.split()
⟪fim⟫
⟪arquivo⟫ tests/acervo-da-ficha.sh
⟪de⟫
fora_da_regra = sorted(r for r in sobra.values()
                       if not ("/icones/pastas/" in r or "/icones/sistema/" in r
                               or r.startswith("packs/meowsystem/mascote/")
                               or r.endswith("/logo.svg") or r.endswith("resgatados-antes-e-depois.png")))
print("  versionados únicos menos oferecíveis: %d — %s" % (
⟪para⟫
fora_da_regra = sorted(r for r in sobra.values()
                       if not ("/icones/pastas/" in r or "/icones/sistema/" in r
                               or "/mascote/" in r
                               or r.endswith("/logo.svg") or r.endswith("resgatados-antes-e-depois.png")))
print("  versionados únicos menos oferecíveis: %d — %s" % (
⟪fim⟫
⟪arquivo⟫ tests/app-completo.py
⟪de⟫
        if (isinstance(no, ast.Assign)
                and any(getattr(a, "id", "") == "SUFIXO_TEMA_DE_TERCEIRO" for a in no.targets)):
            modulos = os.path.join(RAIZ, "assets", "temas-de-apps")
            for app in sorted(os.listdir(modulos)):
                try:
⟪para⟫
        if (isinstance(no, ast.Assign)
                and any(getattr(a, "id", "") == "SUFIXO_TEMA_DE_TERCEIRO" for a in no.targets)):
            modulos = os.path.join(RAIZ, "scripts", "temas-de-apps")
            for app in sorted(os.listdir(modulos)):
                try:
⟪fim⟫
⟪arquivo⟫ tests/app-completo.py
⟪de⟫
    # da raiz de brinquedo cujo jogo não está aqui são as «Decisões já
    # executadas»; o nome da primeira mora só no `appinfo.vdf`.
    with open(os.path.join(RAIZ_B, "assets", "icones", "jogos-fora.map"),
              encoding="utf-8") as fh:
        orfas = [l.split(":")[0].strip() for l in fh
⟪para⟫
    # da raiz de brinquedo cujo jogo não está aqui são as «Decisões já
    # executadas»; o nome da primeira mora só no `appinfo.vdf`.
    with open(os.path.join(RAIZ_B, "assets", "apps", "jogos-fora.map"),
              encoding="utf-8") as fh:
        orfas = [l.split(":")[0].strip() for l in fh
⟪fim⟫
⟪arquivo⟫ tests/app.sh
⟪de⟫
# A pendência do tema de terceiro (P62): os DOIS botões que a Início desenha
# para ela, lidos da tabela da escolha — de um app com módulo, e de nenhum outro.
modulos = os.path.join(raiz, "assets", "temas-de-apps")
com_modulo = next(n for n in sorted(os.listdir(modulos))
                  if os.path.isfile(os.path.join(modulos, n, "manifesto.sh")))
⟪para⟫
# A pendência do tema de terceiro (P62): os DOIS botões que a Início desenha
# para ela, lidos da tabela da escolha — de um app com módulo, e de nenhum outro.
modulos = os.path.join(raiz, "scripts", "temas-de-apps")
com_modulo = next(n for n in sorted(os.listdir(modulos))
                  if os.path.isfile(os.path.join(modulos, n, "manifesto.sh")))
⟪fim⟫
⟪arquivo⟫ tests/app.sh
⟪de⟫
    # `-` vem antes do `.`, e o `morcego.svg` fica depois dos outros dois
    # morcegos (revisão da P57; sem a extensão ele vinha antes).
    nomes_gatos = [n[:-len(".svg")] for n in sorted(
        os.path.basename(p) for p in glob.glob(os.path.join(raiz, "assets", "gatos", "*.svg"))
        if not p.endswith("-symbolic.svg"))]
    espelho = nomes_gatos[(nomes_gatos.index("coquinha") + 1) % len(nomes_gatos)]
    carimbo = (ler(os.path.join(casa, ".local", "share", "meowsystem", "fastfetch", ".gato-atual"))
⟪para⟫
    # `-` vem antes do `.`, e o `morcego.svg` fica depois dos outros dois
    # morcegos (revisão da P57; sem a extensão ele vinha antes).
    def _mascotes_de(pack):
        return [n[:-len(".svg")] for n in sorted(
            os.path.basename(p) for p in glob.glob(os.path.join(raiz, "packs", pack, "mascote", "*.svg"))
            if not p.endswith("-symbolic.svg"))]
    nomes_gatos = _mascotes_de("meowsystem")
    # Os três morcegos (com quebra de linha no fim) são do pack Dracula.
    morcegos = _mascotes_de("dracula")
    espelho = nomes_gatos[(nomes_gatos.index("coquinha") + 1) % len(nomes_gatos)]
    carimbo = (ler(os.path.join(casa, ".local", "share", "meowsystem", "fastfetch", ".gato-atual"))
⟪fim⟫
⟪arquivo⟫ tests/app.sh
⟪de⟫
    # mascote do dock no terminal a qualquer hora.
    com_quebra = []
    for n in nomes_gatos:
        with open(os.path.join(raiz, "assets", "gatos", n + ".svg"), "rb") as fh:
            if fh.read().endswith(b"\n"):
                com_quebra.append(n)
    if com_quebra:
        gato = com_quebra[0]
        logo(LOGO_MODO="fixo", LOGO=gato, LOGO_DIA=gato, LOGO_NOITE=gato)
        espelho = nomes_gatos[(nomes_gatos.index(gato) + 1) % len(nomes_gatos)]
        carimbo = (ler(os.path.join(casa, ".local", "share", "meowsystem", "fastfetch",
                                    ".gato-atual")) or "").split(" ")[0]
⟪para⟫
    # mascote do dock no terminal a qualquer hora.
    com_quebra = []
    for n in morcegos:
        with open(os.path.join(raiz, "packs", "dracula", "mascote", n + ".svg"), "rb") as fh:
            if fh.read().endswith(b"\n"):
                com_quebra.append(n)
    if com_quebra:
        gato = com_quebra[0]
        logo(LOGO_MODO="fixo", LOGO=gato, LOGO_DIA=gato, LOGO_NOITE=gato, PACK="dracula", FLAVOR="dracula")
        espelho = morcegos[(morcegos.index(gato) + 1) % len(morcegos)]
        carimbo = (ler(os.path.join(casa, ".local", "share", "meowsystem", "fastfetch",
                                    ".gato-atual")) or "").split(" ")[0]
⟪fim⟫
⟪arquivo⟫ tests/app.sh
⟪de⟫
    # o mesmo mascote e o teste não separaria uma da outra. A noite é o dia inteiro
    # (início igual ao fim); o dia é uma janela de noite que começa daqui a 2 h.
    if len(nomes_gatos) >= 3:
        import datetime
        dia, noite = nomes_gatos[0], nomes_gatos[1]
        agora = datetime.datetime.now()
        longe = [(agora + datetime.timedelta(hours=h)).strftime("%H:%M") for h in (2, 3)]
⟪para⟫
    # o mesmo mascote e o teste não separaria uma da outra. A noite é o dia inteiro
    # (início igual ao fim); o dia é uma janela de noite que começa daqui a 2 h.
    if len(morcegos) >= 3:
        import datetime
        dia, noite = morcegos[0], morcegos[1]
        agora = datetime.datetime.now()
        longe = [(agora + datetime.timedelta(hours=h)).strftime("%H:%M") for h in (2, 3)]
⟪fim⟫
⟪arquivo⟫ tests/app.sh
⟪de⟫
                ("dia", tuple(longe), dia, noite)):
            logo(LOGO_MODO="hora", LOGO_DIA=dia, LOGO_NOITE=noite,
                 NOITE_INICIO=janela[0], NOITE_FIM=janela[1])
            carimbo = (ler(os.path.join(casa, ".local", "share", "meowsystem", "fastfetch",
                                        ".gato-atual")) or "").split(" ")[0]
⟪para⟫
                ("dia", tuple(longe), dia, noite)):
            logo(LOGO_MODO="hora", LOGO_DIA=dia, LOGO_NOITE=noite,
                 NOITE_INICIO=janela[0], NOITE_FIM=janela[1], PACK="dracula", FLAVOR="dracula")
            carimbo = (ler(os.path.join(casa, ".local", "share", "meowsystem", "fastfetch",
                                        ".gato-atual")) or "").split(" ")[0]
⟪fim⟫
⟪arquivo⟫ tests/arvore.sh
⟪de⟫
  falha "não consegui ler nenhum flavor de packs/*/paleta.json — sem isso esta conferência não mede nada"
else
  ISENTOS=(
    "scripts/temas-de-apps/"
  )
  soltos=$(versionados assets | grep -Ei "($flavors)" || true)
  restantes="$soltos"
  for isento in "${ISENTOS[@]}"; do
    n=$(printf '%s\n' "$restantes" | grep -c "^$isento" || true)
    if [ "$n" = "0" ]; then
⟪para⟫
  falha "não consegui ler nenhum flavor de packs/*/paleta.json — sem isso esta conferência não mede nada"
else
  ISENTOS=()
  soltos=$(versionados assets | grep -Ei "($flavors)" || true)
  restantes="$soltos"
  for isento in ${ISENTOS[@]+"${ISENTOS[@]}"}; do
    n=$(printf '%s\n' "$restantes" | grep -c "^$isento" || true)
    if [ "$n" = "0" ]; then
⟪fim⟫
⟪arquivo⟫ tests/arvore.sh
⟪de⟫
  done
  if [ -z "$restantes" ]; then
    ok "nenhum arquivo de tema solto em assets/ (1 isenção: os temas de aplicativo)"
  else
    falha "há arquivo com nome de flavor em assets/, fora das isenções — ele veste alguém, logo é de um pack"
⟪para⟫
  done
  if [ -z "$restantes" ]; then
    ok "nenhum arquivo de tema solto em assets/ (os temas de aplicativo moram nos packs)"
  else
    falha "há arquivo com nome de flavor em assets/, fora das isenções — ele veste alguém, logo é de um pack"
⟪fim⟫
⟪arquivo⟫ tests/conversor.sh
⟪de⟫
done

# As três origens são de procedências diferentes DE PROPÓSITO: o que decide a
# conversão não é PNG contra SVG, é o desenho ser geométrico ou orgânico.
#
⟪para⟫
done

# As duas origens são de procedências diferentes DE PROPÓSITO: o que decide a
# conversão não é PNG contra SVG, é o desenho ser geométrico ou orgânico.
#
⟪fim⟫
⟪arquivo⟫ tests/conversor.sh
⟪de⟫
  "$RAIZ/packs/catppuccin/icones/apps/autorais/cosmic-edit-mocha.svg"          # autoral, já tem contorno (a fita colapsa)
  "/usr/share/icons/Papirus/64x64/apps/org.gimp.GIMP.svg"       # Papirus, orgânico, com gradiente e sombra
  "$RAIZ/assets/icones/catppuccin-apps/macchiato/spotify.png"   # PNG chapado do acervo Catppuccin
)
# O acervo Catppuccin tem `latte` e `macchiato`, NÃO tem `mocha`: o tema mocha
# dela é vestido com os PNG do macchiato, e está escrito assim no
# `folha_icones.py`. Apontar para `mocha/` daria um "pulado" silencioso.

for origem in "${ORIGENS[@]}"; do
⟪para⟫
  "$RAIZ/packs/catppuccin/icones/apps/autorais/cosmic-edit-mocha.svg"          # autoral, já tem contorno (a fita colapsa)
  "/usr/share/icons/Papirus/64x64/apps/org.gimp.GIMP.svg"       # Papirus, orgânico, com gradiente e sombra
)

for origem in "${ORIGENS[@]}"; do
⟪fim⟫
⟪arquivo⟫ tests/decisoes.sh
⟪de⟫
[ -z "$faltam" ] && ok "as armadilhas estão no GSD.md" || falha "o GSD.md perdeu a armadilha:$faltam"

echo
if [ "$falhas" = 0 ]; then echo "decisoes: tudo certo"; exit 0; fi
⟪para⟫
[ -z "$faltam" ] && ok "as armadilhas estão no GSD.md" || falha "o GSD.md perdeu a armadilha:$faltam"

# --- decisões 19 a 24 de 02-decisoes.md (23/10, P96) --------------------------
[ -f "$RAIZ/packs/meowsystem/mascote/coquinha.svg" ] && [ -f "$RAIZ/packs/meowsystem/mascote/mimir.svg" ] \
  && [ "$(ls "$RAIZ"/packs/dracula/mascote/morcego*.svg 2>/dev/null | wc -l)" = 3 ] && ! ls -d "$RAIZ"/assets/gat[o]s >/dev/null 2>&1 \
  && [ "$(python3 "$RAIZ/scripts/pack.py" mascote-padrao dracula dia)" = morcego-dia ] \
  && ok "19: cada pack tem o seu mascote, e o de fábrica do Dracula é o morcego" \
  || falha "19: o mascote não mora no pack, ou o Dracula não tem o morcego de fábrica"
[ -x "$RAIZ/scripts/terminal_bloco.sh" ] && grep -q 'etapa_bloco_terminal' "$RAIZ/install.sh" \
  && grep -q 'terminal_bloco.sh" remover' "$RAIZ/lib/desinstalar.sh" \
  && [ "$(grep -c '^item	spellbook-terminal-' "$RAIZ/assets/contratos/vizinhos.tsv")" = 3 ] \
  && ok "20: o bloco do terminal é do MeowSystem, e o do Spellbook sai pelo vizinhos.tsv" \
  || falha "20: falta o bloco do terminal, a remoção dele ou os itens do Spellbook"
faltam=""
for p in build-essential pkg-config libxkbcommon-dev libwayland-dev libdbus-1-dev; do
  grep -qE "\\|$p\"?\$" <(sed -n '/^MEOW_DEPS_DOS_APPLETS=/,/"$/p' "$RAIZ/lib/comum.sh") || faltam+=" $p"
done
[ -z "$faltam" ] && grep -q 'ppa:zhangsongcui3371/fastfetch' "$RAIZ/install.sh" \
  && ok "21: o instalador declara o que os applets compilam e o PPA do fastfetch" \
  || falha "21: falta dependência declarada:${faltam:- o PPA do fastfetch}"
grep -q 'git clone https://github.com/AndreBFarias/MeowSystem.git' "$RAIZ/README.md" \
  && ok "22: o README manda baixar do fork" || falha "22: o README não aponta para AndreBFarias/MeowSystem"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d["origens"]["wallpapers"].get("repo") else 1)' \
    "$RAIZ/packs/meowsystem/pack.json" 2>/dev/null && ! grep -q 'meow wallpaper semear  ' "$RAIZ/install.sh" \
  && ok "23: a origem dos papéis de parede é do pack, e o install não manda digitar" \
  || falha "23: o pack não declara a origem dos papéis de parede, ou o install manda semear"
[ ! -e "$RAIZ/docs/folhas" ] && [ ! -e "$RAIZ/docs/pesquisas" ] && [ ! -e "$RAIZ/scripts/icones_apps.sh" ] \
  && ! grep -rqs 'catppuccin-apps' "$RAIZ/install.sh" "$RAIZ/bin/meow" "$RAIZ/scripts" \
  && ok "24: as folhas, a pesquisa bruta e a etapa morta saíram" \
  || falha "24: voltou folha, pesquisa bruta ou a etapa do catppuccin-apps"

echo
if [ "$falhas" = 0 ]; then echo "decisoes: tudo certo"; exit 0; fi
⟪fim⟫
⟪arquivo⟫ tests/doctor-veredito.sh
⟪de⟫
# a cobra: são os valores do `NECESSARIOS` do `etapa_pacotes` mais os dois que
# ele acrescenta fora do array.
do_install="$(sed -n '/^etapa_pacotes()/,/^}/p' "$RAIZ/install.sh" \
  | grep -oE '\]=[a-zA-Z0-9_.+-]+|faltam\+=\([a-zA-Z0-9_.+-]+\)' \
  | sed -E 's/^\]=//; s/^faltam\+=\((.*)\)$/\1/' | LC_ALL=C sort -u | paste -sd' ' -)"
da_ponte="$(sed -n 's/^ *PERMITIDOS=" \(.*\) "$/\1/p' "$RAIZ/scripts/ponte_root.sh" \
  | tr ' ' '\n' | LC_ALL=C sort -u | paste -sd' ' -)"
⟪para⟫
# a cobra: são os valores do `NECESSARIOS` do `etapa_pacotes` mais os dois que
# ele acrescenta fora do array.
do_install="$( (sed -n '/^etapa_pacotes()/,/^}/p' "$RAIZ/install.sh" \
  | grep -oE '\]=[a-zA-Z0-9_.+-]+|faltam\+=\([a-zA-Z0-9_.+-]+\)' \
  | sed -E 's/^\]=//; s/^faltam\+=\((.*)\)$/\1/'
  # e os do compilar dos applets, que o `etapa_pacotes` lê do lib/comum.sh
  sed -n '/^MEOW_DEPS_DOS_APPLETS=/,/"$/p' "$RAIZ/lib/comum.sh" | grep -oE '\|[a-z0-9.+-]+' | tr -d '|' \
  ) | LC_ALL=C sort -u | paste -sd' ' -)"
da_ponte="$(sed -n 's/^ *PERMITIDOS=" \(.*\) "$/\1/p' "$RAIZ/scripts/ponte_root.sh" \
  | tr ' ' '\n' | LC_ALL=C sort -u | paste -sd' ' -)"
⟪fim⟫
⟪arquivo⟫ tests/miudos-do-install.sh
⟪de⟫
# Here-string, e não pipe: com o pipefail, o `grep -q` que acha cedo fecha o
# pipe e o printf sai 141 numa saída grande.
if ! grep -qE '^  [^ ]+ +iconesapps ' <<< "$saida"; then
  reclamar "o doctor não chegou à linha iconesapps (o teste não prova nada)\n$(printf '%s\n' "$saida" | tail -5)"
elif [ -n "$vazias" ]; then
  reclamar "linha do doctor sem texto:\n$vazias"
else
  printf 'ok: nenhuma linha do doctor sai vazia: %s\n' "$(printf '%s\n' "$saida" | grep -E '^  [^ ]+ +iconesapps ' | sed 's/^ *//')"
fi

⟪para⟫
# Here-string, e não pipe: com o pipefail, o `grep -q` que acha cedo fecha o
# pipe e o printf sai 141 numa saída grande.
if ! grep -qE '^  [^ ]+ +arcticons ' <<< "$saida"; then
  reclamar "o doctor não chegou à linha arcticons (o teste não prova nada)\n$(printf '%s\n' "$saida" | tail -5)"
elif [ -n "$vazias" ]; then
  reclamar "linha do doctor sem texto:\n$vazias"
else
  printf 'ok: nenhuma linha do doctor sai vazia: %s\n' "$(printf '%s\n' "$saida" | grep -E '^  [^ ]+ +arcticons ' | sed 's/^ *//')"
fi

⟪fim⟫
⟪arquivo⟫ tests/pack-dracula-completo.sh
⟪de⟫
  falha "o flavor do lado vestido não é o que a tela veste, ou o traço e as pastas não o perguntam" "$tabela"
fi
UPF="$RAIZ/assets/icones/upstream/papirus-folders"
if [ -d "$UPF/src" ] && [ -d /usr/share/icons/Papirus-Dark ]; then
  s="$(amb PACK=dracula FLAVOR=dracula ACCENT=mauve MODO=claro ICONES_PASTAS=cat-dracula-mauve \
⟪para⟫
  falha "o flavor do lado vestido não é o que a tela veste, ou o traço e as pastas não o perguntam" "$tabela"
fi
UPF="${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem/upstream/papirus-folders"
if [ ! -d "$UPF/src" ]; then
  env -i PATH="$PATH" HOME="$T" MEOW_CACHE="$T/cache" NO_COLOR=1 bash "$RAIZ/scripts/baixar_upstream.sh" >/dev/null 2>&1
  UPF="$T/cache/upstream/papirus-folders"
fi
if [ -d "$UPF/src" ] && [ -d /usr/share/icons/Papirus-Dark ]; then
  s="$(amb PACK=dracula FLAVOR=dracula ACCENT=mauve MODO=claro ICONES_PASTAS=cat-dracula-mauve \
⟪fim⟫
⟪arquivo⟫ tests/pack-dracula-completo.sh
⟪de⟫
fi

# --- P82, item 10 (decisão 22): a camada de apps do Catppuccin só roda com ele
#   Com o Dracula no ar, o `icones_apps.sh` mandava o flavor `dracula` para o
#   `macchiato` e dizia «o acervo Catppuccin de aplicativos não está em …».
CA="$T/casa-apps"; mkdir -p "$CA"
saida="$(env -i PATH="$FALSO:$PATH" HOME="$CA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
           PACK=dracula FLAVOR=dracula ICONES_FLAVOR=dracula "$RAIZ/scripts/icones_apps.sh" 2>&1)"; rc=$?
if [ -z "$saida" ] && [ "$rc" != 1 ] && [ "$rc" != 2 ] && [ -z "$(find "$CA" -type f)" ]; then
  ok "com o Dracula no ar, a camada de apps do Catppuccin não diz nada e não escreve (rc=$rc)"
else
  falha "com o Dracula no ar, a camada de apps do Catppuccin falou ou escreveu (rc=$rc)" "$saida"
fi
saida="$(env -i PATH="$FALSO:$PATH" HOME="$CA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
           PACK=catppuccin FLAVOR=mocha ICONES_FLAVOR=mocha "$RAIZ/scripts/icones_apps.sh" 2>&1)"
[ -n "$saida" ] && ok "com o Catppuccin, a camada segue o caminho de sempre" \
  || falha "com o Catppuccin, a camada de apps não respondeu"

# --- P82, item 11 (decisões 17 e 21): trocar de pack devolve o que o pack escondia
#   O `ocultar_apps.sh` só desfazia uma marca pelo `-nome`: trocar do Dracula
⟪para⟫
fi

# --- P82, item 11 (decisões 17 e 21): trocar de pack devolve o que o pack escondia
#   O `ocultar_apps.sh` só desfazia uma marca pelo `-nome`: trocar do Dracula
⟪fim⟫
⟪arquivo⟫ tests/pack.sh
⟪de⟫
  && ok "wallpapers declarado sai DO MOTOR, e diz de onde — o info não diz PRÓPRIO sem leitor" \
  || falha "o info voltou a classificar wallpapers pelo bloco que ninguém lê" "$tabela"
n_fixas="$(printf '%s\n' "$tabela" | grep -cE '^  (gerador|prompt|fastfetch|mascotes) +DO MOTOR — não declarável')"
n_linhas="$(printf '%s\n' "$tabela" | grep -c .)"
# DEZESSEIS DESDE A P41 (24/09/2026): a base de ícones (`icones.base`) virou
# categoria. Este pack não a declara nem herda, e ela sai DO MOTOR — a conta
# das dez PRÓPRIAS acima não muda.
[ "$n_fixas" = "4" ] && [ "$n_linhas" = "16" ] \
  && ok "gerador, prompt, fastfetch e mascotes aparecem como não declaráveis, e a tabela tem as 16 linhas" \
  || falha "a tabela do info não tem as 16 linhas, ou as 4 fixas no motor (linhas=$n_linhas, fixas=$n_fixas)" "$tabela"
case "$tabela" in
  *"CURSOR=\"$ID-roxo\", do pack $ID"*"1 fonte(s), do pack $ID"*)
⟪para⟫
  && ok "wallpapers declarado sai DO MOTOR, e diz de onde — o info não diz PRÓPRIO sem leitor" \
  || falha "o info voltou a classificar wallpapers pelo bloco que ninguém lê" "$tabela"
n_fixas="$(printf '%s\n' "$tabela" | grep -cE '^  (gerador|prompt|fastfetch) +DO MOTOR — não declarável')"
n_linhas="$(printf '%s\n' "$tabela" | grep -c .)"
# DEZESSEIS DESDE A P41 (24/09/2026): a base de ícones (`icones.base`) virou
# categoria. Este pack não a declara nem herda, e ela sai DO MOTOR — a conta
# das dez PRÓPRIAS acima não muda.
[ "$n_fixas" = "3" ] && [ "$n_linhas" = "16" ] \
  && ok "gerador, prompt e fastfetch aparecem como não declaráveis, o mascote é do pack, e a tabela tem as 16 linhas" \
  || falha "a tabela do info não tem as 16 linhas, ou as 3 fixas no motor (linhas=$n_linhas, fixas=$n_fixas)" "$tabela"
case "$tabela" in
  *"CURSOR=\"$ID-roxo\", do pack $ID"*"1 fonte(s), do pack $ID"*)
⟪fim⟫
⟪arquivo⟫ tests/pack.sh
⟪de⟫
  painel="$(p31_amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; meow_ponte_python >/dev/null 2>&1 || exit 9
    exec python3 "$1"' _ "$T/p31painel.py" 2>/dev/null | tail -1)"
  for script in icones_mimetypes icones_pastas icones_apps; do
    saida="$(p31_amb bash -c 'set -a; . "$MEOW_CONF"; set +a
      PASTAS_XDG=sim MEOW_DRY_RUN=1 "$MEOW_RAIZ/scripts/$1.sh" --aplicar 2>&1' _ "$script")"
⟪para⟫
  painel="$(p31_amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; meow_ponte_python >/dev/null 2>&1 || exit 9
    exec python3 "$1"' _ "$T/p31painel.py" 2>/dev/null | tail -1)"
  for script in icones_mimetypes icones_pastas; do
    saida="$(p31_amb bash -c 'set -a; . "$MEOW_CONF"; set +a
      PASTAS_XDG=sim MEOW_DRY_RUN=1 "$MEOW_RAIZ/scripts/$1.sh" --aplicar 2>&1' _ "$script")"
⟪fim⟫
⟪arquivo⟫ tests/pastas-do-pack.sh
⟪de⟫
printf '#!/bin/sh\nprintf "sudo: recusado pelo tests/pastas-do-pack.sh\\n" >&2\nexit 1\n' > "$FALSO/sudo"
chmod 755 "$FALSO/sudo"
UP="${MEOW_CAT_FOLDERS:-$RAIZ/assets/icones/upstream/papirus-folders}"

# pastas <casa> <PACK> <FLAVOR> <ACCENT> [VAR=valor ...] — a etapa das pastas
⟪para⟫
printf '#!/bin/sh\nprintf "sudo: recusado pelo tests/pastas-do-pack.sh\\n" >&2\nexit 1\n' > "$FALSO/sudo"
chmod 755 "$FALSO/sudo"
UP="${MEOW_CAT_FOLDERS:-${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem/upstream/papirus-folders}"
# O upstream mora no cache de quem usa, fora do repositório; numa casa de
# brinquedo ele desce para a pasta do teste, pelo mesmo script do instalador.
if [ -z "${MEOW_CAT_FOLDERS:-}" ] && [ ! -d "$UP/src" ]; then
  env -i PATH="$PATH" HOME="$T" MEOW_CACHE="$T/cache" NO_COLOR=1 bash "$RAIZ/scripts/baixar_upstream.sh" >/dev/null 2>&1
  UP="$T/cache/upstream/papirus-folders"
fi

# pastas <casa> <PACK> <FLAVOR> <ACCENT> [VAR=valor ...] — a etapa das pastas
⟪fim⟫
⟪arquivo⟫ tests/seco.sh
⟪de⟫
    # O `@V_PANEL@`/`@V_DOCK@` é o esquema que o pacote traz, como o
    # `meow_cosmic_v` do lib/comum.sh o lê: o maior `v<n>`, ou `v1`.
    sed -e "s|@ATIVOS@|$1/.local/share/backgrounds/meowsystem/ativos|g" \
        -e "s|@ACERVO@|$RAIZ/packs/meowsystem/mascote/|g" \
        -e "s|@V_PANEL@|$(_v_do_pacote com.system76.CosmicPanel.Panel)|g" \
        -e "s|@V_DOCK@|$(_v_do_pacote com.system76.CosmicPanel.Dock)|g" "$u" > "$destino/$nome"
⟪para⟫
    # O `@V_PANEL@`/`@V_DOCK@` é o esquema que o pacote traz, como o
    # `meow_cosmic_v` do lib/comum.sh o lê: o maior `v<n>`, ou `v1`.
    if [ "$nome" = "meow-assets.path" ]; then
      HOME="$1" bash "$RAIZ/scripts/vigia_assets.sh" --unidade "$nome" > "$destino/$nome"
      chmod 644 "$destino/$nome"; continue
    fi
    sed -e "s|@ATIVOS@|$1/.local/share/backgrounds/meowsystem/ativos|g" \
        -e "s|@V_PANEL@|$(_v_do_pacote com.system76.CosmicPanel.Panel)|g" \
        -e "s|@V_DOCK@|$(_v_do_pacote com.system76.CosmicPanel.Dock)|g" "$u" > "$destino/$nome"
⟪fim⟫
⟪arquivo⟫ tests/temas-de-apps.sh
⟪de⟫
saida="$(mod10 obsidian aplicar catppuccin mocha)"; rc=$?
[ "$rc" = 1 ] && [ "$(aparencia10)" = "Catppuccin | catppuccin_realce,fonte" ] \
  && [ "$(cat "$COFRE10/.obsidian/themes/Catppuccin/theme.css")" = "$(cat "$ACERVO/obsidian/vendor/Catppuccin/theme.css")" ] \
  || faltam+=" obsidian (rc=$rc, $(aparencia10));"
saida="$(mod10 obsidian conferir catppuccin mocha)"; rc=$?
⟪para⟫
saida="$(mod10 obsidian aplicar catppuccin mocha)"; rc=$?
[ "$rc" = 1 ] && [ "$(aparencia10)" = "Catppuccin | catppuccin_realce,fonte" ] \
  && [ "$(cat "$COFRE10/.obsidian/themes/Catppuccin/theme.css")" = "$(cat "$RAIZ/packs/meowsystem/temas-de-apps/obsidian/vendor/Catppuccin/theme.css")" ] \
  || faltam+=" obsidian (rc=$rc, $(aparencia10));"
saida="$(mod10 obsidian conferir catppuccin mocha)"; rc=$?
⟪fim⟫
FIM_DAS_TROCAS

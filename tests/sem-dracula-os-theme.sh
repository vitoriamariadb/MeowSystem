#!/usr/bin/env bash
# sem-dracula-os-theme.sh — o MeowSystem monta o Dracula sem o repositório de
# onde a arte veio?
#
# O projeto é comentado em prosa densa, e a história da migração cita o
# `Dracula_OS-Theme` em comentário e em docstring — é documentação, não leitura.
#
#   - `tests/`: o `tests/pack.sh` lê o `Dracula_OS-Theme` de propósito, para
#     contar por sha256 que a biblioteca inteira chegou ao pack, e pula dizendo
#     por quê quando ele não existe. Teste não é execução.
#   - A PROSA do `PROCEDENCIA.md` e a coluna "de onde": são registro, e dizer
#     de onde cada cópia veio é o trabalho daquele arquivo.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v git >/dev/null 2>&1     || { printf 'pulado: o git não está disponível\n'; exit 0; }
command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

# --- 1. nenhum código que roda nomeia o Dracula_OS-Theme ---------------------
achados="$(python3 - "$RAIZ" <<'PY'
import ast, io, json, os, subprocess, sys, tokenize

ALVO = "Dracula_OS-Theme"
raiz = sys.argv[1]
RODA = ("bin/", "scripts/", "lib/", "app/", "assets/", "systemd/", "src/", "packs/")
SOLTOS = ("install.sh", "meow.conf.exemplo", "assets/contratos/vizinhos.conf.exemplo")
CERQUILHA = (".sh", ".bash", ".zsh", ".service", ".path", ".timer", ".desktop",
             ".conf", ".exemplo")
BARRAS = (".js", ".rs", ".css")

def em_python(texto):
    """Linhas em que o alvo aparece em CÓDIGO: nem comentário, nem docstring."""
    arvore = ast.parse(texto)
    docs = set()
    for no in ast.walk(arvore):
        # Uma string sozinha como instrução é docstring (ou prosa solta, que
        # dá no mesmo): ninguém a lê em execução.
        if isinstance(no, ast.Expr) and isinstance(no.value, ast.Constant) \
                and isinstance(no.value.value, str):
            docs.add((no.value.lineno, no.value.col_offset))
    linhas = []
    for tok in tokenize.generate_tokens(io.StringIO(texto).readline):
        if ALVO not in tok.string or tok.type == tokenize.COMMENT:
            continue
        if tok.type == tokenize.STRING and tok.start in docs:
            continue
        linhas.append(tok.start[0])
    return linhas

def sem_cerquilha(linha):
    # O `#` que abre comentário em shell está no começo ou depois de espaço; o
    # de `${x#prefixo}` não, e continua sendo código.
    s = linha.lstrip()
    if s.startswith("#") or s.startswith(";"):
        return ""
    for i, c in enumerate(linha):
        if c == "#" and i > 0 and linha[i - 1] in " \t":
            return linha[:i]
    return linha

def sem_barras(linha):
    s = linha.lstrip()
    if s.startswith(("//", "/*", "*")):
        return ""
    i = linha.find(" //")
    return linha[:i] if i >= 0 else linha

def em_json(valor, caminho=()):
    if isinstance(valor, dict):
        for k, v in valor.items():
            if str(k).startswith("_"):
                continue  # `_nota*`: a prosa do formato
            yield from em_json(v, caminho + (str(k),))
    elif isinstance(valor, list):
        for v in valor:
            yield from em_json(v, caminho)
    elif isinstance(valor, str) and ALVO in valor:
        yield ".".join(caminho) or "(raiz)"

def tem_shebang(caminho):
    try:
        with open(caminho, "rb") as f:
            return f.read(2) == "#!".encode()
    except OSError:
        return False

sys.path.insert(0, os.path.join(raiz, "scripts"))
import pack  # noqa: E402 — o leitor de PROCEDENCIA.md do próprio sincronizar

versionados = subprocess.run(["git", "-C", raiz, "ls-files", "-z"],
                             capture_output=True, check=True).stdout.decode().split("\0")
for rel in versionados:
    if not rel or not (rel.startswith(RODA) or rel in SOLTOS):
        continue
    caminho = os.path.join(raiz, rel)
    if os.path.basename(rel) == "PROCEDENCIA.md":
        # Só a coluna `lido de`, lida pelo MESMO leitor do `sincronizar`: uma
        # segunda leitura da tabela aqui discordaria da dele no dia em que
        # alguém mudasse a ordem das colunas.
        if os.path.isfile(caminho):
            for lin in pack._tabela_procedencia(caminho):
                if ALVO in lin.get("lido de", ""):
                    print(f"{rel}: {lin.get('arquivo', '?')} — lido de {lin['lido de']}")
        continue
    if not os.path.isfile(caminho):
        continue
    try:
        texto = open(caminho, encoding="utf-8").read()
    except (UnicodeDecodeError, OSError):
        continue  # binário: PNG, fonte, .meowpack
    if ALVO not in texto:
        continue
    if rel.endswith(".py"):
        try:
            for n in em_python(texto):
                print(f"{rel}:{n}")
        except SyntaxError as e:
            print(f"{rel}: não é Python válido ({e.msg}) — não dá para separar código de prosa")
    elif rel.endswith(".json"):
        try:
            for onde in em_json(json.loads(texto)):
                print(f"{rel}: chave {onde}")
        except ValueError:
            print(f"{rel}: não é JSON válido")
    elif rel.endswith(".map"):
        for n, linha in enumerate(texto.splitlines(), 1):
            if ALVO in linha.split("#", 1)[0]:
                print(f"{rel}:{n}")
    elif rel.endswith(CERQUILHA) or rel in SOLTOS or tem_shebang(caminho):
        for n, linha in enumerate(texto.splitlines(), 1):
            if ALVO in sem_cerquilha(linha):
                print(f"{rel}:{n}")
    elif rel.endswith(BARRAS):
        for n, linha in enumerate(texto.splitlines(), 1):
            if ALVO in sem_barras(linha):
                print(f"{rel}:{n}")
    # .md, .svg, .html, .txt: prosa e desenho, que ninguém executa.
PY
)"; rc=$?
if [ "$rc" != "0" ]; then
  falha "a varredura do código não rodou (rc=$rc)" "$achados"
elif [ -n "$achados" ]; then
  falha "código que roda nomeia o Dracula_OS-Theme — na máquina de outra pessoa isso não existe" "$achados"
else
  ok "nenhum código que roda nomeia o Dracula_OS-Theme (comentário e docstring à parte)"
fi

# --- 2. a montagem lê do pack, numa casa sem o Dracula_OS-Theme ---------------
# O ambiente é de brinquedo pela mesma razão do tests/fonte-unica.sh: sem o XDG
# e o MEOW_PACKS de brinquedo, um pack instalado em
# ~/.local/share/meowsystem/packs/ entraria na conta.
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
# A casa numa variável, e não como `$T/home/...` escrito em cada uso: a regra 1
# do tests/portabilidade.sh lê `/home/<nome>/` como home de pessoa cravado, e
# acusou esta linha na primeira passada.
CASA="$T/casa"
mkdir -p "$CASA" "$T/xdg" "$T/packs"
amb() {
  env HOME="$CASA" XDG_DATA_HOME="$T/xdg" MEOW_PACKS="$T/packs" MEOW_RAIZ="$RAIZ" \
      PACK="dracula" FLAVOR="dracula" ICONES_DRACULA="sim" NOME_TEMA_ICONES="MeowSystem-Icons" "$@"
}

# Os pares nome -> desenho, pelo parser do próprio instalador, extraído VERBATIM
# (como no tests/pack.sh e no tests/fonte-unica.sh): uma cópia dele aqui seria a
# que passaria no dia em que o original quebrasse.
pares="$(MAPA="$RAIZ/packs/dracula/icones/apps.map" ICONES_BASE_MAPA="$RAIZ/packs/dracula/icones" RAIZ="$RAIZ" \
  amb bash -c 'set -uo pipefail
  # [P73: o parser do shell é o `_dracula_pares_do_mapa`; ver o tests/fonte-unica.sh.]
  eval "$(sed -n "/^_dracula_pares_do_mapa() {\$/,/^}\$/p" "$RAIZ/scripts/icones_apps_dracula.sh")"
  _dracula_pares_do_mapa' 2>/dev/null)"
total="$(printf '%s\n' "$pares" | grep -c .)"
[ "$total" -gt 0 ] || { falha "o mapa do pack Dracula não deu par nenhum"; exit 1; }

fora="$(printf '%s\n' "$pares" | awk -F'\t' -v p="$RAIZ/packs/dracula/" -v m="$RAIZ/assets/" \
  'index($2, p) != 1 && index($2, m) != 1 {print $1 " -> " $2}')"
[ -z "$fora" ] \
  && ok "os $total desenhos do mapa do Dracula moram no pack ou no motor, dentro do repositório" \
  || falha "o mapa do Dracula aponta para fora do repositório" "$fora"

amb "$RAIZ/scripts/icones_apps_dracula.sh" instalar >"$T/instalar.log" 2>&1; rc=$?
tema="$CASA/.local/share/icons/MeowSystem-Icons/scalable/apps"
postos=0; diferentes=""
while IFS=$'\t' read -r nome origem; do
  [ -n "$nome" ] || continue
  # `$(cat)` dos dois lados: o `meow_escrever` normaliza o newline final, e é
  # assim que o `_dracula_remover` do instalador compara também.
  if [ -f "$tema/$nome.svg" ] && [ "$(cat "$tema/$nome.svg")" = "$(cat "$origem")" ]; then
    postos=$((postos+1))
  else
    diferentes="${diferentes}${nome}"$'\n'
  fi
done <<< "$pares"
[ -e "$CASA/Desenvolvimento/Dracula_OS-Theme" ] \
  && falha "o HOME de brinquedo ganhou um Dracula_OS-Theme — a pergunta 2 deixou de valer"
[ "$postos" = "$total" ] && [ "$rc" != "2" ] \
  && ok "numa casa sem o Dracula_OS-Theme, a montagem põe no tema os $total desenhos, cada um igual ao do pack" \
  || falha "a montagem do Dracula não reproduziu o pack ($postos de $total iguais, rc=$rc)" \
           "$(printf '%s' "$diferentes" | head -10; tail -5 "$T/instalar.log")"

# --- 2b. sem a chave ICONES_DRACULA, o passo do pack monta o pack inteiro ----
#   P78, aberto 4 da integração da onda 1. O passo do pack da P73 nasceu com o
#   padrão antigo (`${ICONES_DRACULA:-nao}`), e com o conf de fábrica sem a
#   chave ele só punha as escolhas do painel: 0 desenho do pack no tema. A
#   integração (`10a139f`) o pôs no padrão ligado da P74, e provou com um
#   script de rodada; esta é a prova que fica. Uma casa nova, o `aplicar` (o
#   verbo do passo) e o ambiente sem a chave nenhuma.
CASA2B="$T/casa-sem-chave"
mkdir -p "$CASA2B"
env -u ICONES_DRACULA HOME="$CASA2B" XDG_DATA_HOME="$T/xdg" MEOW_PACKS="$T/packs" MEOW_RAIZ="$RAIZ" \
    PACK="dracula" FLAVOR="dracula" NOME_TEMA_ICONES="MeowSystem-Icons" \
    MEOW_ICONES_ESCOLHAS="$T/sem-escolhas.map" \
    "$RAIZ/scripts/icones_apps_dracula.sh" aplicar >"$T/sem-chave.log" 2>&1; rc=$?
postos2b="$(find "$CASA2B/.local/share/icons/MeowSystem-Icons/scalable/apps" -name '*.svg' 2>/dev/null | wc -l)"
[ "$postos2b" = "$total" ] && [ "$rc" != "2" ] \
  && ok "sem a chave ICONES_DRACULA no conf, o passo do pack põe os $total desenhos do Dracula (o padrão é ligado)" \
  || falha "sem a chave ICONES_DRACULA o passo do pack pôs $postos2b de $total (rc=$rc)" "$(tail -5 "$T/sem-chave.log")"

# --- 3. nem o doctor lê: o sincronizar sob um gancho de auditoria (P43) -----
#   [P75, 09/10/2026 (D3): o doctor deixou de chamar o `sincronizar` — a
#   decisão de 24/09 foi «Aposentar tudo». A primeira pergunta virou a
#   contrária: a passada do doctor não compara mais nada. O gancho de
#   auditoria abaixo segue medindo o verbo, que ficou para o `meow pack
#   sincronizar <id>` à mão.]
if sed -n '/^cmd_doctor()/,/^}/p' "$RAIZ/bin/meow" | grep -vE '^[[:space:]]*#' \
   | grep -qE 'pack\.py"? sincronizar'; then
  falha "o doctor voltou a chamar o 'pack.py sincronizar' — a decisão de 24/09 foi aposentar a comparação"
else
  ok "a passada do doctor não chama o 'pack.py sincronizar' (D3, decisão de 24/09)"
fi
# Uma casa própria: a pergunta 2 confere que a dela nunca ganha um
# `Dracula_OS-Theme`, e esta não precisa de nenhum para medir — o gancho vê a
# tentativa de abrir, exista o arquivo ou não.
CASA3="$T/casa-do-doctor"
mkdir -p "$CASA3"
lidos="$(env HOME="$CASA3" XDG_DATA_HOME="$T/xdg" MEOW_PACKS="$T/packs" MEOW_RAIZ="$RAIZ" \
  python3 - "$RAIZ" "$RAIZ/packs/dracula" "$CASA3" <<'PY'
import contextlib, io, os, runpy, sys
raiz, alvo, casa = sys.argv[1:4]
abertos = []
def gancho(evento, args):
    if evento == "open" and args and isinstance(args[0], (str, bytes)):
        abertos.append(os.fsdecode(args[0]))
sys.addaudithook(gancho)
sys.argv = [os.path.join(raiz, "scripts", "pack.py"), "sincronizar", alvo]
rc = 0
with contextlib.redirect_stdout(io.StringIO()):
    try:
        runpy.run_path(sys.argv[0], run_name="__main__")
    except SystemExit as e:
        rc = e.code or 0
fora = [a for a in abertos if a.startswith(casa + os.sep) or "Dracula_OS-Theme" in a]
print(f"rc={rc}")
for a in fora:
    print(a)
PY
)"; rc=$?
if [ "$rc" != "0" ]; then
  falha "o gancho de auditoria não rodou (rc=$rc)" "$lidos"
elif [ "$(printf '%s\n' "$lidos" | sed -n 1p)" != "rc=0" ]; then
  falha "o sincronizar do Dracula não saiu 0 — o doctor diria que a arte se separou da origem" "$lidos"
elif [ "$(printf '%s\n' "$lidos" | grep -c .)" != "1" ]; then
  falha "o sincronizar abriu arquivo na casa de quem roda ou no Dracula_OS-Theme" \
        "$(printf '%s\n' "$lidos" | sed 1d | head -5)"
else
  ok "o sincronizar não abre nada na casa de quem roda nem no Dracula_OS-Theme"
fi

printf '\n'
[ "$falhas" -eq 0 ] && exit 0
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1

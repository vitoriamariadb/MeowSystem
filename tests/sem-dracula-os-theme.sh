#!/usr/bin/env bash
# sem-dracula-os-theme.sh — o MeowSystem monta o Dracula sem o repositório de
# onde a arte veio?
#
# POR QUE ESTE ARQUIVO NASCEU EM 23/09/2026 (sprint P37)
#   A regra do dono, de 23/09: "tudo do spellbook que entrar em conflito com o
#   meowsystem, migramos pra cá e desativamos no spellbook". O caso principal
#   era o `rebuild_dracula_theme()` do Spellbook, que rodava o build e o
#   `install.sh --user` do `~/Desenvolvimento/Dracula_OS-Theme` e reescrevia o
#   tema `Dracula-Icones` inteiro. Ele foi desativado lá, e o aviso dele manda
#   para cá: quem monta o Dracula agora é o `scripts/icones_apps_dracula.sh`,
#   lendo de `packs/dracula` (295 desenhos na biblioteca, 191 apps ligados, P36).
#
#   Isso só é verdade enquanto nada daqui voltar a ler de lá. O
#   `Dracula_OS-Theme` só existe na máquina de quem o escreveu; um script que o
#   lesse funcionaria aqui e quebraria em qualquer outra, calado. A pergunta
#   não tinha dono na suíte — o `tests/pack.sh` conta a biblioteca CONTRA ele,
#   de propósito, e ninguém conferia o avesso.
#
# AS DUAS PERGUNTAS
#   1. NENHUM CÓDIGO QUE RODA NOMEIA O `Dracula_OS-Theme`. Fora de comentário e
#      de docstring, em tudo o que é versionado e roda: bin/, scripts/, lib/,
#      app/, assets/, systemd/, src/, packs/ e o install.sh.
#   2. A MONTAGEM LÊ DO PACK, NUMA CASA ONDE O `Dracula_OS-Theme` NÃO EXISTE. O
#      instalador da camada Dracula roda num HOME de brinquedo e tem de pôr no
#      tema os 191 desenhos, cada um igual ao arquivo do pack de onde saiu, e
#      nenhum de fora do repositório. É a máquina de outra pessoa, simulada.
#
# COMO A PERGUNTA 1 SEPARA CÓDIGO DE PROSA, E POR QUE NÃO POR ISENÇÃO
#   O projeto é comentado em prosa densa, e a história da migração cita o
#   `Dracula_OS-Theme` em comentário e em docstring — é documentação, não
#   leitura. Uma lista de linhas isentas apodreceria na primeira vez que alguém
#   reescrevesse um comentário (e a P38, em paralelo com esta sprint, reescreve
#   comentário em todo o repositório). Então a separação é pela GRAMÁTICA:
#   Python passa pelo `tokenize` (comentário e docstring ficam de fora; string
#   de código entra), shell e unidades do systemd perdem o que vem depois do
#   `#`, os mapas perdem o comentário do mesmo jeito que o `_dracula_pares` o
#   corta, e JSON entra pelos valores — menos os das chaves `_nota*`, que são a
#   prosa do formato de pack.
#
# O QUE ELE NÃO COBRA, E POR QUÊ
#   - `tests/`: o `tests/pack.sh` lê o `Dracula_OS-Theme` de propósito, para
#     contar por sha256 que a biblioteca inteira chegou ao pack, e pula dizendo
#     por quê quando ele não existe. Teste não é execução.
#   - `PROCEDENCIA.md`: é registro. A coluna "lido de" diz de onde cada cópia
#     veio, e é assim que tem de ser. Quem a LÊ é o `meow pack sincronizar` (e a
#     linha informativa do `meow doctor`), que compara cópia e origem quando a
#     origem existe e cala quando não existe — regra 8 da P28. Aquilo não
#     alimenta a montagem, e a pergunta 2 prova: sem o `Dracula_OS-Theme`, os
#     191 chegam iguais.
#
# CÓDIGOS DE SAÍDA (os do projeto)
#   0 = tudo cobrado passou · 1 = achados · 2 = erro deste teste.
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
SOLTOS = ("install.sh", "meow.conf.exemplo", "vizinhos.conf.exemplo")
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

versionados = subprocess.run(["git", "-C", raiz, "ls-files", "-z"],
                             capture_output=True, check=True).stdout.decode().split("\0")
for rel in versionados:
    if not rel or not (rel.startswith(RODA) or rel in SOLTOS):
        continue
    if os.path.basename(rel) == "PROCEDENCIA.md":
        continue
    caminho = os.path.join(raiz, rel)
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
#   O ambiente é de brinquedo pela mesma razão do tests/fonte-unica.sh: sem o
#   XDG e o MEOW_PACKS de brinquedo, um pack instalado em
#   ~/.local/share/meowsystem/packs/ entraria na conta. E o HOME de brinquedo é
#   o que tira o ~/Desenvolvimento/Dracula_OS-Theme do alcance.
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
# A casa numa variável, e não como `$T/home/...` escrito em cada uso: a regra 1
# do tests/portabilidade.sh lê `/home/<nome>/` como home de pessoa cravado, e
# acusou esta linha na primeira passada (23/09/2026).
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
  eval "$(sed -n "/^_dracula_pares() {\$/,/^}\$/p" "$RAIZ/scripts/icones_apps_dracula.sh")"
  _dracula_pares' 2>/dev/null)"
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

printf '\n'
[ "$falhas" -eq 0 ] && exit 0
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1

#!/usr/bin/env bash

MEOW_VSCODE_BIN="${MEOW_VSCODE_BIN:-code}"
MEOW_VSCODE_SETTINGS="${MEOW_VSCODE_SETTINGS:-$HOME/.config/Code/User/settings.json}"
MEOW_VSCODE_EXTDIR="${MEOW_VSCODE_EXTDIR:-$HOME/.vscode/extensions}"

MEOW_VSCODE_TEMA=""
MEOW_VSCODE_ICONES=""
MEOW_VSCODE_EXT_TEMA=""
MEOW_VSCODE_EXT_ICONES=""
_MEOW_VSCODE_VSIX=""
_MEOW_VSCODE_VSIX_SHA=""
_MEOW_VSCODE_PACK=""
_MEOW_VSCODE_PACK_NOME=""

_MEOW_VSCODE_LISTA=""

_meow_vscode_json() {
  python3 -I - "$@" <<'PYFIM'
# -*- coding: utf-8 -*-
import json, os, re, sys

MODO = sys.argv[1] if len(sys.argv) > 1 else ""
CAMINHO = sys.argv[2] if len(sys.argv) > 2 else ""
RESTO = sys.argv[3:]

def pular(t, i):
    """Avança sobre espaço em branco e comentários // e /* */."""
    n = len(t)
    while i < n:
        c = t[i]
        if c in " \t\r\n":
            i += 1
        elif c == "/" and i + 1 < n and t[i + 1] == "/":
            j = t.find("\n", i)
            i = n if j < 0 else j
        elif c == "/" and i + 1 < n and t[i + 1] == "*":
            j = t.find("*/", i + 2)
            i = n if j < 0 else j + 2
        else:
            break
    return i

def fim_string(t, i):
    """i aponta para a aspa de ABERTURA; devolve o índice APÓS a de fechamento."""
    n = len(t)
    j = i + 1
    while j < n:
        if t[j] == "\\":
            j += 2
            continue
        if t[j] == '"':
            return j + 1
        j += 1
    return n

def fim_valor(t, i):
    """Fim do valor JSON que começa em i (string, objeto, lista ou escalar)."""
    n = len(t)
    if i >= n:
        return i
    c = t[i]
    if c == '"':
        return fim_string(t, i)
    if c in "{[":
        prof = 0
        j = i
        while j < n:
            d = t[j]
            if d == '"':
                j = fim_string(t, j)
                continue
            if d == "/" and j + 1 < n and t[j + 1] in "/*":
                j = pular(t, j)
                continue
            if d in "{[":
                prof += 1
            elif d in "}]":
                prof -= 1
                if prof == 0:
                    return j + 1
            j += 1
        return n
    j = i
    while j < n and t[j] not in ",}]\n":
        j += 1
    while j > i and t[j - 1] in " \t\r":
        j -= 1
    return j

def varrer(t):
    """{chave: (ini, fim) do VALOR} das chaves de PRIMEIRO NÍVEL, + pos após '{'.

    Pular o valor inteiro depois de casar uma chave é o que mantém o contador
    de profundidade honesto: o "[python]": { ... } dela tem chaves em
    profundidade 2 que não podem entrar no resultado.
    """
    n = len(t)
    i = 0
    prof = 0
    raiz = None
    achados = {}
    while i < n:
        c = t[i]
        if c in " \t\r\n":
            i += 1
            continue
        if c == "/" and i + 1 < n and t[i + 1] in "/*":
            i = pular(t, i)
            continue
        if c == '"':
            fim = fim_string(t, i)
            if prof == 1:
                k = pular(t, fim)
                if k < n and t[k] == ":":
                    try:
                        chave = json.loads(t[i:fim])
                    except ValueError:
                        chave = None
                    ini = pular(t, k + 1)
                    f = fim_valor(t, ini)
                    if chave is not None:
                        achados[chave] = (ini, f)
                    i = f
                    continue
            i = fim
            continue
        if c in "{[":
            prof += 1
            if c == "{" and prof == 1 and raiz is None:
                raiz = i + 1
            i += 1
            continue
        if c in "}]":
            prof -= 1
            i += 1
            continue
        i += 1
    return achados, raiz

def validar(t):
    """Confere que o texto resultante ainda é um JSONC que o VS Code aceita.

    Rede de segurança: é melhor recusar a gravação do que entregar a ela um
    settings.json quebrado (o VS Code ignora o arquivo inteiro e ela perde as
    20+ escolhas de uma vez). Comentários viram espaço para não mexer nos
    índices; vírgula sobrando é tolerada pelo VS Code, então também aqui.
    """
    saida = []
    i, n = 0, len(t)
    while i < n:
        c = t[i]
        if c == '"':
            j = fim_string(t, i)
            saida.append(t[i:j])
            i = j
            continue
        if c == "/" and i + 1 < n and t[i + 1] in "/*":
            j = pular(t, i)
            saida.append(re.sub(r"[^\n]", " ", t[i:j]))
            i = j
            continue
        saida.append(c)
        i += 1
    limpo = re.sub(r",(\s*[}\]])", r"\1", "".join(saida))
    json.loads(limpo)

if not CAMINHO:
    sys.stderr.write("uso: <modo> <arquivo> ...\n")
    sys.exit(2)

existe = os.path.isfile(CAMINHO)
if existe:
    try:
        texto = open(CAMINHO, encoding="utf-8").read()
    except OSError as e:
        sys.stderr.write("não consegui ler %s: %s\n" % (CAMINHO, e))
        sys.exit(2)
    if not texto.strip():
        texto = "{\n}\n"
else:
    texto = "{\n}\n"

try:
    achados, raiz = varrer(texto)
except Exception as e:
    sys.stderr.write("não entendi %s: %s\n" % (CAMINHO, e))
    sys.exit(2)

def valor_de(chave):
    if chave not in achados:
        return None
    ini, fim = achados[chave]
    try:
        return json.loads(texto[ini:fim])
    except ValueError:
        return None

if MODO == "ler":
    print(json.dumps({c: valor_de(c) for c in RESTO}, ensure_ascii=False))
    sys.exit(0)

pares = list(zip(RESTO[0::2], RESTO[1::2]))

if MODO == "conferir":
    if not existe:
        print("ausente %s" % CAMINHO)
        sys.exit(1)
    divergiu = 0
    for chave, desejado in pares:
        atual = valor_de(chave)
        if atual != desejado:
            print("divergente %s: atual=%r desejado=%r" % (chave, atual, desejado))
            divergiu = 1
    sys.exit(divergiu)

if MODO == "fundir":
    recuo = "    "
    for linha in texto.splitlines():
        s = linha.lstrip()
        if s.startswith('"'):
            recuo = linha[: len(linha) - len(s)] or "    "
            break
    trocas, inserir = [], []
    for chave, valor in pares:
        if chave in achados:
            ini, fim = achados[chave]
            trocas.append((ini, fim, json.dumps(valor, ensure_ascii=False)))
        else:
            inserir.append((chave, valor))
    novo = texto
    for ini, fim, txt in sorted(trocas, reverse=True):
        novo = novo[:ini] + txt + novo[fim:]
    if inserir:
        if raiz is None:
            sys.stderr.write(
                "não achei o objeto raiz em %s (tem conteúdo mas não abre com "
                "'{') — não vou adivinhar onde enfiar a chave\n" % CAMINHO)
            sys.exit(2)
        itens = [
            "%s%s: %s" % (recuo, json.dumps(c, ensure_ascii=False),
                          json.dumps(v, ensure_ascii=False))
            for c, v in inserir
        ]
        bloco = "\n" + ",\n".join(itens) + ("," if achados else "")
        if not achados and not novo[raiz:].startswith("\n"):
            bloco += "\n"
        novo = novo[:raiz] + bloco + novo[raiz:]
    try:
        validar(novo)
    except Exception as e:
        sys.stderr.write("o resultado não seria um JSON válido (%s) — nada foi gravado\n" % e)
        sys.exit(2)
    sys.stdout.write(novo)
    sys.stdout.write("X")
    sys.exit(0)

sys.stderr.write("modo desconhecido: %s\n" % MODO)
sys.exit(2)
PYFIM
}

_meow_vscode_lista() {
  if [ -z "$_MEOW_VSCODE_LISTA" ]; then
    if [ ! -d "$MEOW_VSCODE_EXTDIR" ] && [ ! -d "$HOME/.config/Code/User" ]; then
      meow_debug "VS Code sem perfil em $MEOW_VSCODE_EXTDIR nem ~/.config/Code/User"
      _MEOW_VSCODE_LISTA=$'\n'
      printf '%s\n' "$_MEOW_VSCODE_LISTA"
      return 0
    fi
    _MEOW_VSCODE_LISTA="$("$MEOW_VSCODE_BIN" --list-extensions 2>/dev/null \
                          | tr '[:upper:]' '[:lower:]')"
    if [ -z "$_MEOW_VSCODE_LISTA" ]; then _MEOW_VSCODE_LISTA=$'\n'; fi
  fi
  printf '%s\n' "$_MEOW_VSCODE_LISTA"
}

_meow_vscode_pkg() {
  local id_min achado
  id_min="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  [ -d "$MEOW_VSCODE_EXTDIR" ] || return 1
  achado="$(find "$MEOW_VSCODE_EXTDIR" -mindepth 2 -maxdepth 2 -name package.json \
              -path "$MEOW_VSCODE_EXTDIR/$id_min-[0-9]*/package.json" \
              -print 2>/dev/null | sort -V | tail -n 1)"
  [ -n "$achado" ] || return 1
  printf '%s\n' "$achado"
}

_meow_vscode_tem_ext() {
  local id_min
  id_min="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  _meow_vscode_pkg "$1" >/dev/null && return 0
  _meow_vscode_lista | grep -qixF -- "$id_min"
}

_meow_vscode_contribui() {
  python3 -I - "$@" <<'PYFIM' 2>/dev/null
import json, sys
pkg, tema, icone = sys.argv[1:4]
try:
    d = json.load(open(pkg, encoding="utf-8"))
    nome = "%s@%s" % (d.get("name"), d.get("version"))
    c = d.get("contributes") or {}
    temas = [t for t in c.get("themes") or [] if isinstance(t, dict)]
    icones = [t for t in c.get("iconThemes") or [] if isinstance(t, dict)]
except Exception:
    sys.exit(0)
falta = 0
if tema and temas and tema not in [t.get(k) for t in temas for k in ("id", "label")]:
    print("%s não contribui o tema %r (tem: %s)"
          % (nome, tema, ", ".join(str(t.get("label") or t.get("id")) for t in temas)))
    falta = 1
if icone and icones and icone not in [t.get("id") for t in icones]:
    print("%s não contribui o ícone %r (tem: %s)"
          % (nome, icone, ", ".join(str(t.get("id")) for t in icones)))
    falta = 1
sys.exit(falta)
PYFIM
}

_VSC_SEM_O_TEMA=""
_meow_vscode_sem_o_tema() {
  local pkg
  _VSC_SEM_O_TEMA=""
  pkg="$(_meow_vscode_pkg "$MEOW_VSCODE_EXT_TEMA")" || return 1
  _VSC_SEM_O_TEMA="$(_meow_vscode_contribui "$pkg" "$MEOW_VSCODE_TEMA" "")" && return 1
  [ -n "$_VSC_SEM_O_TEMA" ]
}

_meow_vscode_auditar_ext() {
  local pkg menor linha
  if [ ! -d "$MEOW_VSCODE_EXTDIR" ]; then return 0; fi
  menor="$("$MEOW_VSCODE_BIN" --version 2>/dev/null | head -1 | cut -d. -f2)"
  for pkg in "$(_meow_vscode_pkg "$MEOW_VSCODE_EXT_TEMA" 2>/dev/null || true)" \
             "$(_meow_vscode_pkg "$MEOW_VSCODE_EXT_ICONES" 2>/dev/null || true)"; do
    if [ -z "$pkg" ] || [ ! -f "$pkg" ]; then continue; fi
    python3 -I - "$pkg" "${menor:-0}" <<'PYFIM'
import json, sys
pkg, minor = sys.argv[1], int(sys.argv[2] or 0)
try:
    d = json.load(open(pkg, encoding="utf-8"))
except Exception as e:
    print("aviso: não consegui ler %s (%s)" % (pkg, e))
    sys.exit(0)
nome = "%s@%s" % (d.get("name"), d.get("version"))
eng = (d.get("engines") or {}).get("vscode", "")
v = eng.replace("^", "").replace(">=", "").split(".")
try:
    if minor and int(v[0]) == 1 and int(v[1]) > minor:
        print("aviso: %s exige VS Code %s e o instalado é 1.%d — o "
              "configurar-vscode.sh do Ritual da Aurora APAGA essa pasta na "
              "próxima passagem (até 1h) e o tema cai para o padrão" % (nome, eng, minor))
except (IndexError, ValueError):
    pass
PYFIM
    while IFS= read -r linha; do
      if [ -n "$linha" ]; then printf 'aviso: %s\n' "$linha"; fi
    done < <(_meow_vscode_contribui "$pkg" "$MEOW_VSCODE_TEMA" "$MEOW_VSCODE_ICONES")
  done
}

_meow_vscode_backup() {
  local origem="$1" carimbo destino rel
  meow_guardar_antes "$1"
  if [ ! -f "$origem" ]; then return 0; fi
  carimbo="${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
  destino="$MEOW_ESTADO/backups/$carimbo"
  case "$origem" in
    "$HOME"/*) rel="${origem#"$HOME"/}" ;;
    *)         rel="fora-da-home/${origem#/}" ;;
  esac
  mkdir -p "$destino/$(dirname "$rel")" || return 1
  cp -p -- "$origem" "$destino/$rel" || return 1
  ( cd "$destino" && sha256sum -- "$rel" >> manifesto.sha256 ) || return 1
  printf '%s\n' "$origem" >> "$destino/origens.txt" || return 1
  meow_info "backup: $destino/$rel"
  return 0
}

_VSC_EXT=""; _VSC_URL=""; _VSC_SHA=""; _VSC_ICONES=""; _VSC_ICONES_PACK=""; _VSC_EXT_ICONES=""; _VSC_DO_REPO=""
_meow_vscode_pack_no_ar() {
  local saida
  saida="$(PACK="${PACK:-}" FLAVOR="${FLAVOR:-}" python3 -I - "$MEOW_RAIZ/scripts" <<'PYFIM' 2>/dev/null
import os, sys
sys.path.insert(0, sys.argv[1])
import pack

ident, dir_pack, _recusado = pack.adocao(os.environ.get("PACK", ""), os.environ.get("FLAVOR", ""))
print("pack=" + ident)
print("nome=" + " ".join(str(pack.campo(ident, "nome") or ident).splitlines()))
icones_pack = ""
for chave, trilha in (("ext", "vscode.origem.extensao"), ("url", "vscode.origem.url"),
                      ("sha", "vscode.origem.sha256"), ("icones", "vscode-icones.esquema"),
                      ("ext_icones", "vscode-icones.origem.extensao")):
    quem, valor = pack.tema_de_app("apps." + trilha, ref=dir_pack or None)
    if quem is None or valor is None or any(c in str(valor) for c in "\r\n"):
        quem = valor = ""
    print("%s=%s" % (chave, valor))
    if chave == "icones":
        icones_pack = quem
print("icones_pack=" + icones_pack)
dir_real = os.path.realpath(dir_pack or pack.achar(ident) or "")
do_repo = os.path.realpath(os.path.join(pack.RAIZ, "packs"))
print("repo=" + ("1" if dir_real.startswith(do_repo + os.sep) else "0"))
PYFIM
)" || return 1
  _MEOW_VSCODE_PACK="$(printf '%s\n' "$saida" | sed -n 's/^pack=//p')"
  _MEOW_VSCODE_PACK_NOME="$(printf '%s\n' "$saida" | sed -n 's/^nome=//p')"
  _VSC_EXT="$(printf '%s\n' "$saida" | sed -n 's/^ext=//p')"
  _VSC_URL="$(printf '%s\n' "$saida" | sed -n 's/^url=//p')"
  _VSC_SHA="$(printf '%s\n' "$saida" | sed -n 's/^sha=//p')"
  _VSC_ICONES="$(printf '%s\n' "$saida" | sed -n 's/^icones=//p')"
  _VSC_ICONES_PACK="$(printf '%s\n' "$saida" | sed -n 's/^icones_pack=//p')"
  _VSC_EXT_ICONES="$(printf '%s\n' "$saida" | sed -n 's/^ext_icones=//p')"
  _VSC_DO_REPO="$(printf '%s\n' "$saida" | sed -n 's/^repo=//p')"
  [ -n "$_MEOW_VSCODE_PACK" ]
}

_meow_vscode_do_pack() {
  MEOW_VSCODE_TEMA=""; MEOW_VSCODE_ICONES=""; MEOW_VSCODE_EXT_TEMA=""; MEOW_VSCODE_EXT_ICONES=""
  _MEOW_VSCODE_VSIX=""; _MEOW_VSCODE_VSIX_SHA=""
  _meow_vscode_pack_no_ar || { meow_app_sem "VS Code: o scripts/pack.py não disse qual é o pack no ar"; return; }
  meow_app_tema_do_pack vscode.esquema
  if [ -z "$MEOW_APP_TEMA" ]; then
    meow_app_sem "VS Code: sem tema neste pack ($_MEOW_VSCODE_PACK_NOME) — o editor fica como está"
    return
  fi
  if [ "$MEOW_APP_TEMA_PACK" != "$_MEOW_VSCODE_PACK" ]; then
    meow_app_sem "VS Code: sem tema neste pack ($_MEOW_VSCODE_PACK_NOME) — o que a herança traz é o '$MEOW_APP_TEMA', do pack $MEOW_APP_TEMA_PACK, e o tema de um pack não vale para outro"
    return
  fi
  MEOW_VSCODE_TEMA="$MEOW_APP_TEMA"
  MEOW_VSCODE_EXT_TEMA="$_VSC_EXT"
  if [ -z "$MEOW_VSCODE_EXT_TEMA" ]; then
    meow_app_sem "VS Code: o pack $_MEOW_VSCODE_PACK_NOME pede o tema '$MEOW_VSCODE_TEMA' e não diz de que extensão ele vem (apps.vscode.origem.extensao)"
    return
  fi
  if ! [[ "$MEOW_VSCODE_EXT_TEMA" =~ ^[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
    meow_app_sem "VS Code: a extensão '$MEOW_VSCODE_EXT_TEMA' do pack $_MEOW_VSCODE_PACK_NOME não tem a forma <editor>.<nome> — nada é instalado"
    MEOW_VSCODE_EXT_TEMA=""
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$_VSC_DO_REPO" = "1" ]; then
    _MEOW_VSCODE_VSIX="$_VSC_URL"; _MEOW_VSCODE_VSIX_SHA="$_VSC_SHA"
  fi
  if [ -n "$_MEOW_VSCODE_VSIX$_MEOW_VSCODE_VSIX_SHA" ]; then
    case "$_MEOW_VSCODE_VSIX" in
      https://*) ;;
      *) meow_app_sem "VS Code: o pacote da extensão $MEOW_VSCODE_EXT_TEMA no pack $_MEOW_VSCODE_PACK_NOME não vem de uma URL https ('$_MEOW_VSCODE_VSIX')"; return ;;
    esac
    if ! [[ "$_MEOW_VSCODE_VSIX_SHA" =~ ^[0-9a-f]{64}$ ]]; then
      meow_app_sem "VS Code: o pacote da extensão $MEOW_VSCODE_EXT_TEMA no pack $_MEOW_VSCODE_PACK_NOME não traz um sha256 (64 hex) — sem ele a URL entrega o que quiser"
      return
    fi
  fi
  if [ -n "$_VSC_ICONES" ] && [ "$_VSC_ICONES_PACK" = "$_MEOW_VSCODE_PACK" ]; then
    MEOW_VSCODE_ICONES="$_VSC_ICONES"
    MEOW_VSCODE_EXT_ICONES="$_VSC_EXT_ICONES"
    if [ -z "$MEOW_VSCODE_EXT_ICONES" ]; then
      meow_app_sem "VS Code: o pack $_MEOW_VSCODE_PACK_NOME pede os ícones '$MEOW_VSCODE_ICONES' e não diz de que extensão eles vêm (apps.vscode-icones.origem.extensao)"
      return
    fi
    if ! [[ "$MEOW_VSCODE_EXT_ICONES" =~ ^[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
      meow_app_sem "VS Code: a extensão '$MEOW_VSCODE_EXT_ICONES' do pack $_MEOW_VSCODE_PACK_NOME não tem a forma <editor>.<nome> — nada é instalado"
      MEOW_VSCODE_EXT_ICONES=""
      return "$MEOW_SEM_DEPENDENCIA"
    fi
  fi
  return "$MEOW_OK"
}

_VSC_TODOS_ICONES=""
_meow_vscode_icones_de_todos() {
  _VSC_TODOS_ICONES="$(MEOW_PACKS_VALIDOS="$(meow_packs_validos)" python3 -I - "$MEOW_RAIZ/scripts" <<'PYFIM' 2>/dev/null
import os, sys
sys.path.insert(0, sys.argv[1])
import pack

icones = []
for ident in os.environ.get("MEOW_PACKS_VALIDOS", "").split():
    try:
        _quem, valor = pack.tema_de_app("apps.vscode-icones.esquema", ref=ident)
    except Exception:
        continue
    if isinstance(valor, str) and valor and "," not in valor and valor not in icones:
        icones.append(valor)
print(",".join(icones))
PYFIM
)"
}

_meow_vscode_icones_de_pack() {
  local atual
  _meow_vscode_icones_de_todos || return 1
  atual="$(_meow_vscode_json ler "$MEOW_VSCODE_SETTINGS" workbench.iconTheme 2>/dev/null \
           | python3 -c 'import json, sys; v = json.load(sys.stdin).get("workbench.iconTheme"); print(v if isinstance(v, str) else "")' 2>/dev/null)"
  [ -n "$atual" ] && [ "$atual" != "$_MEOW_VSCODE_ICONES_FABRICA" ] || return 1
  case ",$_VSC_TODOS_ICONES," in *",$atual,"*) return 0 ;; esac
  return 1
}

_VSC_PARES=()
_meow_vscode_pares() {
  _VSC_PARES=(workbench.colorTheme "$MEOW_VSCODE_TEMA")
  if [ -n "$MEOW_VSCODE_ICONES" ]; then
    _VSC_PARES+=(workbench.iconTheme "$MEOW_VSCODE_ICONES")
  elif _meow_vscode_icones_de_pack; then
    _VSC_PARES+=(workbench.iconTheme "$_MEOW_VSCODE_ICONES_FABRICA")
  fi
}

_meow_vscode_rotulo() {
  if [ -n "$MEOW_VSCODE_ICONES" ]; then printf '%s + %s' "$MEOW_VSCODE_TEMA" "$MEOW_VSCODE_ICONES"
  else printf '%s' "$MEOW_VSCODE_TEMA"; fi
}
_meow_vscode_pares_texto() {
  local i texto=""
  for ((i = 0; i < ${#_VSC_PARES[@]}; i += 2)); do
    texto+="${texto:+, }${_VSC_PARES[i]#workbench.}=${_VSC_PARES[i + 1]}"
  done
  printf '%s' "$texto"
}

_VSC_VSIX_ARQ=""
_meow_vscode_baixar_vsix() {
  local tmp obtido f
  _VSC_VSIX_ARQ=""
  for f in curl sha256sum; do
    meow_tem "$f" || { meow_app_sem "VS Code: falta '$f' para baixar a extensão $MEOW_VSCODE_EXT_TEMA do pack $_MEOW_VSCODE_PACK_NOME"; return; }
  done
  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" .meow-vscode-vsix.XXXXXX)" || return "$MEOW_ERRO"
  meow_info "baixando o pacote pinado de $MEOW_VSCODE_EXT_TEMA…"
  if ! curl -sSfL --proto '=https' --proto-redir '=https' --connect-timeout 15 \
       --max-time 300 --retry 3 --retry-delay 2 -o "$tmp/extensao.vsix" "$_MEOW_VSCODE_VSIX" 2>/dev/null; then
    rm -rf "$tmp"
    meow_app_sem "VS Code: não consegui baixar a extensão $MEOW_VSCODE_EXT_TEMA do pack $_MEOW_VSCODE_PACK_NOME (sem rede?) — fica para o próximo ciclo"
    return
  fi
  if ! echo "$_MEOW_VSCODE_VSIX_SHA  $tmp/extensao.vsix" | sha256sum --status -c - 2>/dev/null; then
    obtido="$(sha256sum "$tmp/extensao.vsix" | cut -d' ' -f1)"
    rm -rf "$tmp"
    meow_erro "VS Code: o sha256 da extensão $MEOW_VSCODE_EXT_TEMA não bate com o que o pack $_MEOW_VSCODE_PACK_NOME pinou — nada instalado"
    meow_info "  esperado $_MEOW_VSCODE_VSIX_SHA"
    meow_info "  obtido   $obtido"
    return "$MEOW_ERRO"
  fi
  _VSC_VSIX_ARQ="$tmp/extensao.vsix"
  return "$MEOW_OK"
}

_VSC_PENDENCIA_GESTO="vscode-extensao-de-terceiro"
_meow_vscode_espera_gesto() {
  local lista
  lista="$(printf '%s, ' "$@")"; lista="${lista%, }"
  meow_pendencia_acionavel "$_VSC_PENDENCIA_GESTO" \
    "O pack importado $_MEOW_VSCODE_PACK_NOME pede a extensão $lista do VS Code: extensão é código, e de pack importado ela só entra pelo seu gesto" \
    "MEOW_VSCODE_EXTENSAO=$1 meow apps aplicar vscode"
  meow_app_sem "VS Code: a extensão $lista, do pack importado $_MEOW_VSCODE_PACK_NOME, espera o seu gesto"
  meow_app_pendente vscode
}

meow_app_instalado() { meow_tem "$MEOW_VSCODE_BIN"; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "VS Code: '$MEOW_VSCODE_BIN' não está no PATH"; return; }
  meow_tem python3 || { meow_app_sem "VS Code: falta python3, que é o varredor de JSONC deste módulo"; return; }
  [ "${1:-}" = "sem-pack" ] && return "$MEOW_OK"
  _meow_vscode_do_pack || return
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar sem-pack || return "$MEOW_SEM_DEPENDENCIA"
  _meow_vscode_do_pack || { meow_app_pendente vscode; return; }

  local divergente=0 ext saida rc linha espera=0
  for ext in "$MEOW_VSCODE_EXT_TEMA" ${MEOW_VSCODE_EXT_ICONES:+"$MEOW_VSCODE_EXT_ICONES"}; do
    if ! _meow_vscode_tem_ext "$ext"; then
      if [ "$_VSC_DO_REPO" != "1" ]; then
        meow_pula "a extensão $ext, do pack importado $_MEOW_VSCODE_PACK_NOME, espera o seu gesto"
        espera=1
      else
        meow_info "extensão ausente: $ext"
        divergente=1
      fi
    fi
  done
  [ "$espera" = "1" ] && [ "$divergente" = "0" ] && return "$MEOW_SEM_DEPENDENCIA"
  if _meow_vscode_sem_o_tema; then
    meow_info "extensão sem o tema: $_VSC_SEM_O_TEMA"
    divergente=1
  fi

  _meow_vscode_pares
  saida="$(_meow_vscode_json conferir "$MEOW_VSCODE_SETTINGS" "${_VSC_PARES[@]}" 2>&1)"; rc=$?
  case "$rc" in
    0) : ;;
    1) while IFS= read -r linha; do
         if [ -n "$linha" ]; then meow_info "$linha"; fi
       done <<< "$saida"
       divergente=1 ;;
    *) meow_aviso "não consegui ler $MEOW_VSCODE_SETTINGS: $saida"; divergente=1 ;;
  esac

  if [ "$divergente" = "0" ]; then
    meow_ok "VS Code: $(_meow_vscode_rotulo) já no lugar"
    return "$MEOW_OK"
  fi
  return "$MEOW_DIVERGENTE"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_pendencia_resolvida "$_VSC_PENDENCIA_GESTO"; meow_app_pendente vscode; return; }

  local ext faltando=() mudou=0 saida novo antigo aud linha erro_json alvo
  local rc_set rc_ext rc_json rc_esc

  for ext in "$MEOW_VSCODE_EXT_TEMA" ${MEOW_VSCODE_EXT_ICONES:+"$MEOW_VSCODE_EXT_ICONES"}; do
    if ! _meow_vscode_tem_ext "$ext"; then faltando+=("$ext"); fi
  done
  if _meow_vscode_sem_o_tema; then
    if [ -z "$_MEOW_VSCODE_VSIX" ]; then
      meow_app_sem "VS Code: $_VSC_SEM_O_TEMA — atualize a extensão pelo editor; o pack $_MEOW_VSCODE_PACK_NOME não pina um pacote dela"
      meow_app_pendente vscode; return
    fi
    faltando+=("$MEOW_VSCODE_EXT_TEMA")
  fi

  local espera=() gesto="" e_min
  if [ "${#faltando[@]}" -gt 0 ] && [ "$_VSC_DO_REPO" != "1" ]; then
    gesto="$(printf '%s' "${MEOW_VSCODE_EXTENSAO:-}" | tr '[:upper:]' '[:lower:]')"
    local vale=()
    for ext in "${faltando[@]}"; do
      e_min="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
      if [ -n "$gesto" ] && [ "$e_min" = "$gesto" ]; then vale+=("$ext"); else espera+=("$ext"); fi
    done
    faltando=(${vale[@]+"${vale[@]}"})
  fi
  if [ "${#espera[@]}" = "0" ]; then meow_pendencia_resolvida "$_VSC_PENDENCIA_GESTO"; fi

  _meow_vscode_pares
  _meow_vscode_json conferir "$MEOW_VSCODE_SETTINGS" "${_VSC_PARES[@]}" >/dev/null 2>&1; rc_set=$?

  if [ "${#faltando[@]}" = "0" ] && [ "${#espera[@]}" = "0" ] && [ "$rc_set" = "0" ]; then
    meow_ok "VS Code: $(_meow_vscode_rotulo) já no lugar"
    return "$MEOW_OK"
  fi

  if meow_seco; then
    for ext in ${faltando[@]+"${faltando[@]}"}; do
      if [ "$ext" = "$MEOW_VSCODE_EXT_TEMA" ] && [ -n "$_MEOW_VSCODE_VSIX" ]; then
        meow_muda "instalaria a extensão $ext, do pacote pinado ($_MEOW_VSCODE_VSIX)"
      else
        meow_muda "instalaria a extensão $ext"
      fi
    done
    for ext in ${espera[@]+"${espera[@]}"}; do
      meow_pula "a extensão $ext, do pack importado $_MEOW_VSCODE_PACK_NOME, espera o seu gesto"
    done
    if [ "$rc_set" != "0" ] && [ "${#espera[@]}" = "0" ]; then
      meow_muda "mudaria $MEOW_VSCODE_SETTINGS: $(_meow_vscode_pares_texto)"
    fi
    return "$MEOW_DIVERGENTE"
  fi

  for ext in ${faltando[@]+"${faltando[@]}"}; do
    meow_info "instalando extensão $ext…"
    alvo="$ext"
    if [ "$ext" = "$MEOW_VSCODE_EXT_TEMA" ] && [ -n "$_MEOW_VSCODE_VSIX" ]; then
      _meow_vscode_baixar_vsix
      case $? in
        0) alvo="$_VSC_VSIX_ARQ" ;;
        3) meow_app_pendente vscode; return ;;
        *) return "$MEOW_ERRO" ;;
      esac
    fi
    if meow_tem timeout; then
      saida="$(timeout 300 "$MEOW_VSCODE_BIN" --install-extension "$alvo" 2>&1)"; rc_ext=$?
    else
      saida="$("$MEOW_VSCODE_BIN" --install-extension "$alvo" 2>&1)"; rc_ext=$?
    fi
    if [ -n "$_VSC_VSIX_ARQ" ]; then rm -rf -- "$(dirname -- "$_VSC_VSIX_ARQ")"; _VSC_VSIX_ARQ=""; fi
    if [ "$rc_ext" != "0" ]; then
      meow_erro "falhou ao instalar $ext (rc=$rc_ext): $(printf '%s' "$saida" | tail -3)"
      return "$MEOW_ERRO"
    fi
    _MEOW_VSCODE_LISTA=""
    if ! _meow_vscode_tem_ext "$ext"; then
      meow_erro "o CLI disse que instalou $ext, mas não achei a pasta em $MEOW_VSCODE_EXTDIR"
      return "$MEOW_ERRO"
    fi
    if [ "$ext" = "$MEOW_VSCODE_EXT_TEMA" ] && [ -n "$_MEOW_VSCODE_VSIX" ] && _meow_vscode_sem_o_tema; then
      meow_erro "VS Code: o pacote que o pack $_MEOW_VSCODE_PACK_NOME pina para $ext entrou, e $_VSC_SEM_O_TEMA — o settings.json não foi mudado"
      return "$MEOW_ERRO"
    fi
    meow_muda "extensão $ext instalada"
    mudou=1
  done

  if [ "${#espera[@]}" -gt 0 ]; then
    _meow_vscode_espera_gesto "${espera[@]}"
    return
  fi

  if [ "$rc_set" != "0" ] || [ ! -f "$MEOW_VSCODE_SETTINGS" ]; then
    erro_json="$(mktemp -t meow-vscode-erro.XXXXXX)" || {
      meow_erro "não consegui criar arquivo temporário — nada foi gravado"
      return "$MEOW_ERRO"
    }
    novo="$(_meow_vscode_json fundir "$MEOW_VSCODE_SETTINGS" "${_VSC_PARES[@]}" 2>"$erro_json")"; rc_json=$?
    saida="$(cat -- "$erro_json" 2>/dev/null)"
    rm -f -- "$erro_json"

    if [ "$rc_json" != "0" ] || [ "${novo: -1}" != "X" ]; then
      meow_erro "não consegui fundir $MEOW_VSCODE_SETTINGS (rc=$rc_json) — nada foi gravado${saida:+: $saida}"
      return "$MEOW_ERRO"
    fi
    novo="${novo%X}"

    antigo=""
    if [ -f "$MEOW_VSCODE_SETTINGS" ]; then
      antigo="$(cat -- "$MEOW_VSCODE_SETTINGS"; printf X)"; antigo="${antigo%X}"
    fi
    if [ "$novo" != "$antigo" ]; then
      if [ -f "$MEOW_VSCODE_SETTINGS" ] && ! _meow_vscode_backup "$MEOW_VSCODE_SETTINGS"; then
        meow_erro "não consegui fazer backup de $MEOW_VSCODE_SETTINGS — não vou gravar"
        return "$MEOW_ERRO"
      fi
      meow_escrever "$MEOW_VSCODE_SETTINGS" "$novo" 644; rc_esc=$?
      if [ "$rc_esc" = "2" ]; then
        meow_erro "falhou ao gravar $MEOW_VSCODE_SETTINGS"
        return "$MEOW_ERRO"
      fi
      meow_muda "settings.json: $(_meow_vscode_pares_texto)"
      mudou=1
    fi
  fi

  aud="$(_meow_vscode_auditar_ext 2>/dev/null || true)"
  if [ -n "$aud" ]; then
    while IFS= read -r linha; do
      if [ -n "$linha" ]; then meow_aviso "$linha"; fi
    done <<< "$aud"
  fi

  if [ "$mudou" = "0" ]; then
    meow_ok "VS Code: nada a fazer"
    return "$MEOW_OK"
  fi

  meow_registrar "vscode: $(_meow_vscode_rotulo)"
  if [ -n "$MEOW_VSCODE_ICONES" ]; then
    meow_ok "VS Code em $MEOW_VSCODE_TEMA (ícones $MEOW_VSCODE_ICONES)"
  else
    meow_ok "VS Code em $MEOW_VSCODE_TEMA (o pack $_MEOW_VSCODE_PACK_NOME não traz tema de ícones)"
  fi
  return "$MEOW_DIVERGENTE"
}

_MEOW_VSCODE_TEMA_FABRICA="${MEOW_VSCODE_TEMA_FABRICA:-Default Dark Modern}"
_MEOW_VSCODE_ICONES_FABRICA="${MEOW_VSCODE_ICONES_FABRICA:-vs-seti}"

meow_app_reverter() {
  meow_app_detectar sem-pack || { meow_app_pendente vscode; return; }
  _meow_vscode_do_pack || true
  [ -n "$_MEOW_VSCODE_PACK_NOME" ] || _MEOW_VSCODE_PACK_NOME="tema do MeowSystem"

  local ext instaladas=() mudou=0 rc_set=0 novo
  for ext in ${MEOW_VSCODE_EXT_TEMA:+"$MEOW_VSCODE_EXT_TEMA"} ${MEOW_VSCODE_EXT_ICONES:+"$MEOW_VSCODE_EXT_ICONES"}; do
    if _meow_vscode_tem_ext "$ext"; then instaladas+=("$ext"); fi
  done

  if [ -f "$MEOW_VSCODE_SETTINGS" ]; then
    _meow_vscode_json conferir "$MEOW_VSCODE_SETTINGS" \
        workbench.colorTheme "$_MEOW_VSCODE_TEMA_FABRICA" \
        workbench.iconTheme  "$_MEOW_VSCODE_ICONES_FABRICA" >/dev/null 2>&1; rc_set=$?
  fi

  if [ "${#instaladas[@]}" = "0" ] && [ "$rc_set" = "0" ]; then
    meow_ok "VS Code já estava sem o $_MEOW_VSCODE_PACK_NOME"
    return "$MEOW_OK"
  fi

  if meow_seco; then
    for ext in ${instaladas[@]+"${instaladas[@]}"}; do
      meow_muda "desinstalaria a extensão $ext"
    done
    [ "$rc_set" != "0" ] && \
      meow_muda "mudaria $MEOW_VSCODE_SETTINGS: colorTheme=$_MEOW_VSCODE_TEMA_FABRICA, iconTheme=$_MEOW_VSCODE_ICONES_FABRICA"
    return "$MEOW_DIVERGENTE"
  fi

  if [ "$rc_set" != "0" ]; then
    if novo="$(_meow_vscode_json fundir "$MEOW_VSCODE_SETTINGS" \
                 workbench.colorTheme "$_MEOW_VSCODE_TEMA_FABRICA" \
                 workbench.iconTheme  "$_MEOW_VSCODE_ICONES_FABRICA" 2>/dev/null)" \
       && [ "${novo: -1}" = "X" ]; then
      novo="${novo%X}"
      _meow_vscode_backup "$MEOW_VSCODE_SETTINGS" || {
        meow_erro "vscode: backup do settings.json falhou — não escrevi"
        return "$MEOW_ERRO"
      }
      if printf '%s' "$novo" > "$MEOW_VSCODE_SETTINGS" 2>/dev/null; then
        mudou=1
        meow_muda "vscode: colorTheme=$_MEOW_VSCODE_TEMA_FABRICA, iconTheme=$_MEOW_VSCODE_ICONES_FABRICA"
      else
        meow_erro "vscode: não consegui escrever $MEOW_VSCODE_SETTINGS"
        return "$MEOW_ERRO"
      fi
    else
      meow_erro "vscode: não consegui montar o settings.json de volta"
      return "$MEOW_ERRO"
    fi
  fi

  for ext in ${instaladas[@]+"${instaladas[@]}"}; do
    if "$MEOW_VSCODE_BIN" --uninstall-extension "$ext" >/dev/null 2>&1; then
      mudou=1; meow_muda "extensão removida: $ext"
    else
      meow_aviso "não consegui remover $ext — tire pela interface do editor"
    fi
  done
  _MEOW_VSCODE_LISTA=""

  [ "$mudou" = "0" ] && { meow_ok "VS Code já estava sem o $_MEOW_VSCODE_PACK_NOME"; return "$MEOW_OK"; }
  meow_ok "VS Code de volta ao tema de fábrica — reescolha o seu em File > Preferences > Theme"
  meow_info "tire 'vscode' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}

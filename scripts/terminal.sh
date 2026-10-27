#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

DIR="${TERMINAL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicTerm/$(meow_cosmic_v com.system76.CosmicTerm)}"
PALETA="$(meow_paleta)"

ESQUEMA="${TERMINAL_ESQUEMA:-sim}"
_FLAVOR="$(meow_flavor)"
_ACCENT="${ACCENT:-mauve}"
_CURSOR="${TERMINAL_CURSOR:-accent}"

ACAO="aplicar"
case "${1:-}" in
  ''|aplicar|--aplicar)   ACAO="aplicar" ;;
  conferir|--conferir)    ACAO="conferir" ;;
  remover|--remover)      ACAO="remover" ;;
  -h|--help)
    printf 'uso: %s [aplicar|conferir|remover]\n\n' "$(basename "$0")"
    printf '  aplicar   instala o esquema da paleta do pack no cosmic-term e o seleciona\n'
    printf '  conferir  não escreve nada (0 igual · 1 divergente · 3 sem dependência)\n'
    printf '  remover   tira o nosso esquema e volta ao de fábrica\n\n'
    printf 'conf: FLAVOR, ACCENT, TERMINAL_ESQUEMA, TERMINAL_CURSOR\n'
    exit 0 ;;
  *) meow_erro "opção desconhecida: '$1' — use aplicar, conferir ou remover"
     exit "$MEOW_ERRO" ;;
esac
# shellcheck disable=SC2034
[ "$ACAO" = "conferir" ] && MEOW_SECO=1
meow_seco && [ "$ACAO" = "aplicar" ] && ACAO="conferir"

NOMES_ESQUEMA="$(python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
nomes = d.get("nomes") or {}
for f in d.get("flavors", {}):
    n = nomes.get(f)
    if isinstance(n, str) and n:
        print("%s\t%s" % (f, n))
' "$PALETA" 2>/dev/null)"

_nome_esquema() {
  local linha
  linha="$(printf '%s\n' "$NOMES_ESQUEMA" | awk -F'\t' -v f="$1" '$1==f{print $2; exit}')"
  [ -n "$linha" ] || return 1
  printf '%s' "$linha"
}

NOSSOS_NOMES="$(python3 -I -c '
import json, os, sys
sys.path.insert(0, sys.argv[1])
import pack
nomes, vistos = [], set()
def juntar(dados):
    for n in (dados.get("nomes") or {}).values():
        if isinstance(n, str) and n and n not in nomes:
            nomes.append(n)
for base in pack.raizes():
    try:
        ids = sorted(os.listdir(base))
    except OSError:
        continue
    for ident in ids:
        if ident in vistos or not os.path.isfile(os.path.join(base, ident, "pack.json")):
            continue
        vistos.add(ident)
        try:
            juntar(pack.validar(ident, silencioso=True)[1])
        except Exception:
            continue
try:
    juntar(json.load(open(sys.argv[2])))
except Exception:
    pass
print(",".join(nomes))
' "$RAIZ/scripts" "$PALETA" 2>/dev/null)"

_FLAVOR_CLARO_PALETA="$(python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
claros = [c for c in (d.get("claros") or []) if c in (d.get("flavors") or {})]
print(claros[0] if claros else "")
' "$PALETA" 2>/dev/null)"
FLAVOR_CLARO="${_FLAVOR_CLARO_PALETA:-latte}"

_FLAVOR_ESCURO_PALETA="$(python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
claros = set(d.get("claros") or [])
escuros = [f for f in (d.get("flavors") or {}) if f not in claros]
print(escuros[0] if escuros else "")
' "$PALETA" 2>/dev/null)"
case "$_FLAVOR" in
  "$FLAVOR_CLARO") FLAVOR_ESCURO="${_FLAVOR_ESCURO_PALETA:-mocha}" ;;
  *)               FLAVOR_ESCURO="$_FLAVOR" ;;
esac

_py() {
  PALETA="$PALETA" python3 -I - "$@" <<'PY'
import json, os, re, sys

modo = sys.argv[1]


def esc(s):
    return json.dumps(s, ensure_ascii=False)


def gerar(flavor, nome, cursor_hex):
    pal = json.load(open(os.environ["PALETA"]))
    claros = set(pal.get("claros", ["latte"]))
    try:
        p = {k: v.upper() for k, v in pal["flavors"][flavor].items()}
    except KeyError:
        sys.stderr.write("flavor desconhecido na paleta: %s\n" % flavor)
        sys.exit(2)

    if flavor in claros:
        n_black, n_white = p["subtext1"], p["surface2"]
        b_black, b_white = p["subtext0"], p["surface1"]
    else:
        n_black, n_white = p["surface1"], p["subtext1"]
        b_black, b_white = p["surface2"], p["subtext0"]

    cursor = cursor_hex if cursor_hex != "--" else p["rosewater"]

    meio = [p["red"], p["green"], p["yellow"], p["blue"], p["pink"], p["teal"]]
    normal = [n_black] + meio + [n_white]
    bright = [b_black] + meio + [b_white]
    nomes = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]

    def ansi(campo, cores, ind):
        L = ["%s%s: (" % (" " * ind, campo)]
        for k, v in zip(nomes, cores):
            L.append('%s%s: "%s",' % (" " * (ind + 4), k, v))
        L.append("%s)," % (" " * ind))
        return L

    L = ["("]
    L.append("        name: %s," % esc(nome))
    L.append('        foreground: "%s",' % p["text"])
    L.append('        cursor: "%s",' % cursor)
    L.append('        bright_foreground: "%s",' % p["text"])
    L.append('        dim_foreground: "%s",' % p["overlay0"])
    L += ansi("normal", normal, 8)
    L += ansi("bright", bright, 8)
    L += ansi("dim", normal, 8)
    L.append("    )")
    sys.stdout.write("\n".join(L))


class Erro(Exception):
    pass


def ler_mapa(txt):
    n = len(txt)

    def ws(i):
        while i < n and txt[i] in " \t\r\n":
            i += 1
        return i

    def valor(i):
        prof = 0
        while i < n:
            c = txt[i]
            if c == '"':
                i += 1
                while i < n:
                    if txt[i] == "\\":
                        i += 2
                        continue
                    if txt[i] == '"':
                        i += 1
                        break
                    i += 1
                else:
                    raise Erro("string sem fechamento")
                continue
            if c in "([{":
                prof += 1
                i += 1
                continue
            if c in ")]}":
                if prof == 0:
                    return i
                prof -= 1
                i += 1
                if prof == 0:
                    return i
                continue
            if prof == 0 and c == ",":
                return i
            i += 1
        raise Erro("valor sem fechamento")

    i = ws(0)
    if i >= n or txt[i] != "{":
        raise Erro("não começa com '{'")
    i += 1
    itens = []
    while True:
        i = ws(i)
        if i >= n:
            raise Erro("faltou o '}' final")
        if txt[i] == "}":
            i += 1
            break
        j = txt.find(":", i)
        if j < 0:
            raise Erro("entrada sem ':'")
        chave = txt[i:j].strip()
        if not chave.isdigit():
            raise Erro("chave não numérica: %r" % chave)
        j = ws(j + 1)
        fim = valor(j)
        itens.append([int(chave), txt[j:fim]])
        i = ws(fim)
        if i < n and txt[i] == ",":
            i += 1
    if ws(i) != n:
        raise Erro("sobrou texto depois do '}'")
    return itens


def nome_de(cru):
    m = re.search(r'name:\s*"((?:[^"\\]|\\.)*)"', cru)
    if not m:
        return None
    return json.loads('"%s"' % m.group(1))


def carregar(caminho):
    if not os.path.exists(caminho):
        return []
    txt = open(caminho, encoding="utf-8").read()
    if not txt.strip():
        return []
    try:
        return ler_mapa(txt)
    except Erro as e:
        sys.stderr.write("não entendi %s: %s\n" % (caminho, e))
        sys.exit(2)


def emitir(itens):
    if not itens:
        sys.stdout.write("__VAZIO__")
        return
    L = ["{"]
    for chave, cru in sorted(itens, key=lambda x: x[0]):
        L.append("    %d: %s," % (chave, cru))
    L.append("}")
    sys.stdout.write("\n".join(L))


if modo == "gerar":
    gerar(sys.argv[2], sys.argv[3], sys.argv[4])
elif modo == "por":
    caminho, nome = sys.argv[2], sys.argv[3]
    entrada = os.environ["ENTRADA"]
    itens = carregar(caminho)
    for it in itens:
        if nome_de(it[1]) == nome:
            it[1] = entrada
            break
    else:
        prox = max((c for c, _ in itens), default=-1) + 1
        itens.append([prox, entrada])
    emitir(itens)
elif modo == "tirar":
    nossos = set(os.environ.get("NOSSOS", "").split(","))
    itens = [it for it in carregar(sys.argv[2]) if nome_de(it[1]) not in nossos]
    emitir(itens)
else:
    sys.stderr.write("modo inválido: %s\n" % modo)
    sys.exit(2)
PY
}

_hex_accent() {
  python3 -I -c '
import json, sys
try:
    p = json.load(open(sys.argv[1]))["flavors"][sys.argv[2]]
except Exception:
    sys.exit(1)
v = p.get(sys.argv[3])
if not isinstance(v, str) or not v.startswith("#"):
    sys.exit(1)
print(v.upper())
' "$PALETA" "$1" "$_ACCENT" 2>/dev/null
}

_pronto() {
  if ! meow_tem cosmic-term; then
    meow_pula "cosmic-term não está instalado — nada a aplicar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! meow_tem python3; then
    meow_aviso "python3 não encontrado — é ele quem lê o mapa RON sem estragá-lo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$PALETA" ]; then
    meow_erro "paleta ausente: $PALETA"
    return "$MEOW_ERRO"
  fi
  if ! _nome_esquema "$FLAVOR_ESCURO" >/dev/null; then
    meow_aviso "FLAVOR=\"$_FLAVOR\" não é um flavor da paleta do pack no ar — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$_CURSOR" != "accent" ] && [ "$_CURSOR" != "port" ]; then
    meow_aviso "TERMINAL_CURSOR=\"$_CURSOR\" não existe (use accent ou port) — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$_CURSOR" = "accent" ] && [ -z "$(_hex_accent "$FLAVOR_ESCURO")" ]; then
    meow_aviso "ACCENT=\"$_ACCENT\" não existe na paleta — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_gravar() {
  local arq="$1" conteudo="$2"
  if [ -f "$arq" ] && ! meow_seco && [ "$conteudo" != "$(cat "$arq" 2>/dev/null)" ]; then
    if ! meow_backup_sistema "$arq"; then
      meow_erro "não consegui guardar cópia de $arq — nada foi escrito"
      return "$MEOW_ERRO"
    fi
  fi
  meow_escrever "$arq" "$conteudo" 644
}

_apagar() {
  local arq="$1"
  [ -f "$arq" ] || return "$MEOW_OK"
  if meow_seco; then
    meow_muda "apagaria $arq"
    return "$MEOW_DIVERGENTE"
  fi
  meow_backup_sistema "$arq" || { meow_erro "não consegui guardar cópia de $arq"; return "$MEOW_ERRO"; }
  rm -f "$arq" || return "$MEOW_ERRO"
  return "$MEOW_DIVERGENTE"
}

_slot_por() {
  local tipo="$1" flavor="$2"
  local mapa="$DIR/color_schemes_$tipo" sel="$DIR/syntax_theme_$tipo"
  local nome entrada desejado hex rc mudou=0

  if ! nome="$(_nome_esquema "$flavor")"; then
    meow_erro "a paleta não nomeia o flavor '$flavor' (esquema $tipo do terminal)"
    meow_info "  quem declara é a chave \"nomes\" da paleta: $(basename "$PALETA")"
    [ "$tipo" = "light" ] && meow_info "  e o flavor claro sai de \"claros\" — um pack sem flavor claro não usa o modo claro"
    return "$MEOW_ERRO"
  fi

  hex="--"
  if [ "$_CURSOR" = "accent" ]; then
    hex="$(_hex_accent "$flavor")"
    [ -n "$hex" ] || hex="--"
  fi

  entrada="$(_py gerar "$flavor" "$nome" "$hex")" || return "$MEOW_ERRO"
  desejado="$(ENTRADA="$entrada" _py por "$mapa" "$nome")" || {
    meow_erro "não escrevi nada em $mapa — o seu mapa de esquemas está num formato que eu não sei reescrever com segurança"
    return "$MEOW_ERRO"
  }
  [ "$desejado" = "__VAZIO__" ] && { meow_erro "o mapa desejado saiu vazio — isto é bug"; return "$MEOW_ERRO"; }

  _gravar "$mapa" "$desejado"; rc=$?
  case $rc in
    1) mudou=1 ;;
    2) meow_erro "não consegui escrever $mapa"; return "$MEOW_ERRO" ;;
  esac

  local atual=""
  if [ -f "$sel" ]; then
    atual="$(cat "$sel" 2>/dev/null)"
    atual="${atual#\"}"; atual="${atual%\"}"
  fi
  local podemos=0
  case "$atual" in
    ''|'COSMIC Dark'|'COSMIC Light') podemos=1 ;;
  esac
  case ",$NOSSOS_NOMES," in *",$atual,"*) podemos=1 ;; esac

  if [ "$podemos" = 1 ]; then
    _gravar "$sel" "\"$nome\""; rc=$?
    case $rc in
      1) mudou=1 ;;
      2) meow_erro "não consegui escrever $sel"; return "$MEOW_ERRO" ;;
    esac
  else
    meow_aviso "syntax_theme_$tipo está em \"$atual\", escolha sua — o $nome ficou"
    meow_aviso "instalado mas NÃO selecionado. Para usá-lo: cosmic-term, Ajustes → Cores."
  fi

  [ "$mudou" = 1 ] && return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}

_slot_tirar() {
  local tipo="$1"
  local mapa="$DIR/color_schemes_$tipo" sel="$DIR/syntax_theme_$tipo"
  local desejado rc mudou=0 atual

  if [ -f "$mapa" ]; then
    desejado="$(NOSSOS="$NOSSOS_NOMES" _py tirar "$mapa")" || {
      meow_erro "não removi nada de $mapa — formato que eu não sei reescrever com segurança"
      return "$MEOW_ERRO"
    }
    if [ "$desejado" = "__VAZIO__" ]; then
      _apagar "$mapa"; rc=$?
    else
      _gravar "$mapa" "$desejado"; rc=$?
    fi
    case $rc in
      1) mudou=1 ;;
      2) return "$MEOW_ERRO" ;;
    esac
  fi

  if [ -f "$sel" ]; then
    atual="$(cat "$sel" 2>/dev/null)"
    atual="${atual#\"}"; atual="${atual%\"}"
    case ",$NOSSOS_NOMES," in
      *",$atual,"*)
        _apagar "$sel"; rc=$?
        case $rc in
          1) mudou=1 ;;
          2) return "$MEOW_ERRO" ;;
        esac ;;
      *)
        [ -n "$atual" ] && meow_pula "syntax_theme_$tipo está em \"$atual\" — escolha sua, fica" ;;
    esac
  fi

  [ "$mudou" = 1 ] && return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}

_tem_nosso() {
  local arq n
  for arq in "$DIR/color_schemes_dark" "$DIR/color_schemes_light"; do
    [ -f "$arq" ] || continue
    while IFS= read -r n; do
      [ -n "$n" ] && grep -qF "name: \"$n\"" "$arq" && return 0
    done <<< "$(printf '%s\n' "$NOSSOS_NOMES" | tr ',' '\n')"
  done
  return 1
}

_aplicar() {
  local rc mudou=0
  _slot_por dark  "$FLAVOR_ESCURO"; rc=$?; [ "$rc" = 2 ] && return "$MEOW_ERRO"; [ "$rc" = 1 ] && mudou=1
  _slot_por light "$FLAVOR_CLARO";  rc=$?; [ "$rc" = 2 ] && return "$MEOW_ERRO"; [ "$rc" = 1 ] && mudou=1

  local qual
  qual="cursor $(_hex_accent "$FLAVOR_ESCURO")"
  [ "$_CURSOR" = "port" ] && qual="cursor do port oficial"

  if [ "$mudou" = 0 ]; then
    meow_ok "terminal já estava em $(_nome_esquema "$FLAVOR_ESCURO") / $(_nome_esquema "$FLAVOR_CLARO")"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    return "$MEOW_DIVERGENTE"
  fi
  meow_registrar "terminal esquema=$FLAVOR_ESCURO/$FLAVOR_CLARO cursor=$_CURSOR"
  meow_ok "terminal com o tema: $(_nome_esquema "$FLAVOR_ESCURO") no escuro, $(_nome_esquema "$FLAVOR_CLARO") no claro ($qual)"
  meow_info "vale nas janelas já abertas — o cosmic-term vigia este diretório por inotify"
  return "$MEOW_DIVERGENTE"
}

_remover() {
  local rc mudou=0
  _slot_tirar dark;  rc=$?; [ "$rc" = 2 ] && return "$MEOW_ERRO"; [ "$rc" = 1 ] && mudou=1
  _slot_tirar light; rc=$?; [ "$rc" = 2 ] && return "$MEOW_ERRO"; [ "$rc" = 1 ] && mudou=1

  if [ "$mudou" = 0 ]; then
    meow_pula "não há esquema nosso no cosmic-term para remover"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_registrar "terminal removido"
  meow_ok "terminal de volta à paleta de fábrica do cosmic-term"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?

  [ "$ACAO" = "remover" ] && { _remover; return $?; }

  if [ "$ESQUEMA" != "sim" ]; then
    if _tem_nosso; then
      meow_muda "TERMINAL_ESQUEMA=\"$ESQUEMA\" no meow.conf, mas o esquema nosso continua instalado"
      [ "$ACAO" = "conferir" ] && return "$MEOW_DIVERGENTE"
      _remover; return $?
    fi
    meow_pula "TERMINAL_ESQUEMA=\"$ESQUEMA\" no meow.conf — o terminal fica com a paleta de fábrica"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  _aplicar
}

main "$@"
exit $?

#!/usr/bin/env bash
# terminal.sh — a paleta ANSI do `cosmic-term`, que era a única peça da tela
# dela que continuava de fábrica.
#
# VS Code, Obsidian, btop, bat, qBittorrent e Spotify já estão vestidos.
#
# A ARMADILHA QUE DECIDE O DESENHO: O ARQUIVO DE IMPORTAÇÃO NÃO É O ARQUIVO DE
# CONFIGURAÇÃO.
#
# O README do port oficial (`catppuccin/cosmic-desktop`, pasta
# `assets/temas/cosmic-term/`) manda importar pela GUI — View → Color schemes… →
# Import — e os quatro `.ron` de lá são UM `ColorScheme` solto:
#
#       (
#           name: "Catppuccin Mocha",
#           foreground: "#cdd6f4",
#
#       )
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

DIR="${TERMINAL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicTerm/$(meow_cosmic_v com.system76.CosmicTerm)}"
# A paleta vem da porta única (lib/comum.sh). Era
# `assets/paleta/catppuccin.json` cravado — e um nome cravado aqui faz este
# script continuar lendo o Catppuccin enquanto o resto do projeto já mudou de
# paleta, sem dar erro.
PALETA="$(meow_paleta)"

ESQUEMA="${TERMINAL_ESQUEMA:-sim}"
# Vazio, vale o flavor padrão do pack no ar: o `meow_flavor` (lib/comum.sh).
# Era `${FLAVOR:-mocha}`, o padrão de um pack só.
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
# O `--conferir` do projeto é o seco visto de fora. Atribuir aqui funciona
# porque o `source` do comum.sh já passou (ver o cabeçalho de MEOW_SECO lá).
# shellcheck disable=SC2034  # quem lê MEOW_SECO é o meow_seco() do comum.sh
[ "$ACAO" = "conferir" ] && MEOW_SECO=1
meow_seco && [ "$ACAO" = "aplicar" ] && ACAO="conferir"

# --- os nomes, e por que eles são a chave de tudo ---------------------------
# O nome é a IDENTIDADE da nossa entrada dentro do mapa (é por ele que o
# `remover` acha o que apagar) E é o valor que vai para `syntax_theme_*`.
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

# Tudo o que este módulo pode ter escrito algum dia, em qualquer flavor. Sai da
# MESMA paleta pelo mesmo motivo: um nome que só o `remover` conhece é lixo que
# ninguém apaga.
#
# A frase de cima dizia "em qualquer flavor" e a conta lia só a paleta do pack
# ATIVO.
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

# O slot escuro segue o FLAVOR; o claro sai da PALETA, não de um nome cravado.
#
# ERA `FLAVOR_CLARO="latte"`, E ISSO QUEBRAVA TODO PACK QUE NÃO FOSSE O
# CATPPUCCIN O comentário anterior dizia, com todas as letras, "o claro é sempre
# o Latte, porque o Catppuccin tem um flavor claro só".
#
# A mesma lição que o bloco acima já contava sobre `NOMES_ESQUEMA`: uma lista de
# nomes chumbada custa exatamente o dia em que entra o quinto nome.
_FLAVOR_CLARO_PALETA="$(python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
claros = [c for c in (d.get("claros") or []) if c in (d.get("flavors") or {})]
print(claros[0] if claros else "")
' "$PALETA" 2>/dev/null)"
FLAVOR_CLARO="${_FLAVOR_CLARO_PALETA:-latte}"

# E o escuro: se o FLAVOR escolhido for o claro, o par escuro é o primeiro
# flavor que NÃO está em `claros`. Antes isto era `latte) FLAVOR_ESCURO="mocha"`,
# com os dois nomes do Catppuccin escritos no código.
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

# --- o ajudante em python ---------------------------------------------------
# Bash não lê RON, e um `sed` sobre um mapa aninhado com strings dentro é o
# jeito mais rápido de picotar um arquivo dela. O python entra em três modos:
#
#   gerar <flavor> <nome> <cursor_hex|-->   imprime a entrada pronta
#   por   <arquivo> <nome>                  põe/substitui a nossa (ENTRADA=...)
#   tirar <arquivo>                         tira as nossas (NOSSOS=...)
# O parser devolve cru o que não é nosso; o que ele não entende vira erro, e ninguém
# escreve. O `background` nunca entra (o fundo é o do tema dela, com a opacidade).
_py() {
  PALETA="$PALETA" python3 -I - "$@" <<'PY'
import json, os, re, sys

modo = sys.argv[1]


def esc(s):
    # RON aceita as mesmas fugas de string do JSON; ensure_ascii=False mantém
    # o "é" de Frappé como UTF-8, que é como o port oficial o escreve.
    return json.dumps(s, ensure_ascii=False)


# ---------------------------------------------------------------- gerar
def gerar(flavor, nome, cursor_hex):
    pal = json.load(open(os.environ["PALETA"]))
    claros = set(pal.get("claros", ["latte"]))
    try:
        # MAIÚSCULA, E ISSO NÃO É ESTILO — ver o bloco "O HEX É MAIÚSCULO"
        # no cabeçalho deste arquivo.
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

    # magenta = pink e cyan = teal. Não é engano: é o que o port oficial faz,
    # e foi conferido contra os quatro arquivos dele.
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

    # A ORDEM DOS CAMPOS É A DA DECLARAÇÃO DO STRUCT em src/config.rs, e
    # `background` não entra — ver o cabeçalho deste arquivo.
    L = ["("]
    L.append("        name: %s," % esc(nome))
    L.append('        foreground: "%s",' % p["text"])
    L.append('        cursor: "%s",' % cursor)
    L.append('        bright_foreground: "%s",' % p["text"])
    L.append('        dim_foreground: "%s",' % p["overlay0"])
    L += ansi("normal", normal, 8)
    L += ansi("bright", bright, 8)
    L += ansi("dim", normal, 8)          # o port repete o normal no dim
    L.append("    )")
    sys.stdout.write("\n".join(L))


# ---------------------------------------------------------------- ler o mapa
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
                    return i          # escalar solto: acabou no fecha do mapa
                prof -= 1
                i += 1
                if prof == 0:
                    return i
                continue
            if prof == 0 and c == ",":
                return i              # escalar solto
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


# ---------------------------------------------------------------- por / tirar
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
        # O MESMO CRITÉRIO DA GUI: `last_key_value().map(|(id,_)| id+1)`, com
        # `unwrap_or_default()` = 0 no mapa vazio. Assim a nossa entrada nunca
        # cai em cima de uma dela, e a próxima importação pela GUI continua
        # ganhando um id livre.
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

# --- o hex do accent --------------------------------------------------------
# A tradução nome-da-paleta -> hex mora aqui pelo mesmo motivo do `midia.sh`:
# a paleta é do MeowSystem, e uma segunda cópia dos hex é uma segunda verdade.
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

# --- pré-requisitos ---------------------------------------------------------
_pronto() {
  if ! meow_tem cosmic-term; then
    meow_pula "cosmic-term não está instalado — nada a vestir"
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

# --- escrever um arquivo do cosmic-config -----------------------------------
# O `meow_backup_sistema` guarda em
# `~/.local/state/meowsystem/backups/<carimbo>-sistema/<caminho absoluto>`, uma
# vez por passagem (o `MEOW_CARIMBO` é exportado pelo comum.sh), e não faz nada
# quando o arquivo ainda não existe.
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

# Apaga uma chave = volta ao `Default` do cosmic-term. O arquivo vai para o
# backup antes, para que `meow desfazer` tenha de onde tirá-lo.
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

# --- um slot (escuro ou claro) ----------------------------------------------
# $1 = dark|light   $2 = flavor
_slot_por() {
  local tipo="$1" flavor="$2"
  local mapa="$DIR/color_schemes_$tipo" sel="$DIR/syntax_theme_$tipo"
  local nome entrada desejado hex rc mudou=0

  # Esta linha devolvia 2 sem imprimir uma palavra, e o `meow doctor`
  # mostrava `erro terminal` com a mensagem VAZIA — não havia como saber o
  # que faltava sem rodar o script com `bash -x`.
  if ! nome="$(_nome_esquema "$flavor")"; then
    meow_erro "a paleta não nomeia o flavor '$flavor' (esquema $tipo do terminal)"
    meow_info "  quem declara é a chave \"nomes\" da paleta: $(basename "$PALETA")"
    [ "$tipo" = "light" ] && meow_info "  e o flavor claro sai de \"claros\" — um pack sem flavor claro não veste o modo claro"
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

  # O `syntax_theme_*` é exatamente o que o seletor de Ajustes → Cores do
  # cosmic-term escreve.
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

  # A seleção só volta ao de fábrica se ainda estiver apontando para um nome
  # NOSSO.
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

# Algum esquema NOSSO (de qualquer pack) em algum dos dois mapas? 0 = sim.
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

# --- as ações ---------------------------------------------------------------
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
  meow_ok "terminal vestido: $(_nome_esquema "$FLAVOR_ESCURO") no escuro, $(_nome_esquema "$FLAVOR_CLARO") no claro ($qual)"
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

  # `remover` pedido na mão vem ANTES da chave do conf: quem digitou "remover"
  # não quer ouvir sobre o TERMINAL_ESQUEMA, quer o terminal de volta.
  [ "$ACAO" = "remover" ] && { _remover; return $?; }

  if [ "$ESQUEMA" != "sim" ]; then
    # Desligar tem de DESLIGAR — a mesma lição do `midia.sh`. Deixar de
    # aplicar manteria de pé o que uma passagem anterior escreveu, e o sintoma
    # seria "desliguei e continua", que é o pior porque não há onde olhar.
    # A PALAVRA "Catppuccin" ERA A RÉGUA, E ELA SÓ VIA UM PACK — P51. Com o
    # Dracula no ar o mapa não a tem, e `TERMINAL_ESQUEMA="nao"` deixava o
    # terminal vestido. A régua é a mesma do `remover`: algum nome nosso dentro
    # de um dos mapas.
    if _tem_nosso; then
      meow_muda "TERMINAL_ESQUEMA=\"$ESQUEMA\" no meow.conf, mas o esquema nosso continua instalado"
      [ "$ACAO" = "conferir" ] && return "$MEOW_DIVERGENTE"
      _remover; return $?
    fi
    meow_pula "TERMINAL_ESQUEMA=\"$ESQUEMA\" no meow.conf — o terminal fica com a paleta de fábrica"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  _aplicar   # `conferir` é `aplicar` em seco — o MEOW_SECO faz a diferença
}

main "$@"
exit $?

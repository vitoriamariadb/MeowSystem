#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

FASTFETCH_LOGO="${FASTFETCH_LOGO:-sim}"

FASTFETCH_LOGO_GATO="${FASTFETCH_LOGO_GATO:-coquinha}"

FASTFETCH_LOGO_MODO="${FASTFETCH_LOGO_MODO:-espelho}"
FASTFETCH_LOGO_DIA="${FASTFETCH_LOGO_DIA:-${LOGO_DIA:-mimir}}"
FASTFETCH_LOGO_NOITE="${FASTFETCH_LOGO_NOITE:-${LOGO_NOITE:-coquinha}}"

FASTFETCH_LOGO_CONF="${FASTFETCH_LOGO_CONF:-sim}"

FASTFETCH_LOGO_COLUNAS="${FASTFETCH_LOGO_COLUNAS:-40}"

FASTFETCH_LOGO_LINHAS="${FASTFETCH_LOGO_LINHAS:-}"

FASTFETCH_LOGO_CELULA="${FASTFETCH_LOGO_CELULA:-2.556}"

FASTFETCH_LOGO_QUEBRAS="${FASTFETCH_LOGO_QUEBRAS:-auto}"
FASTFETCH_LOGO_RECUO="${FASTFETCH_LOGO_RECUO:-3}"

FASTFETCH_TITULO="${FASTFETCH_TITULO:-}"

FASTFETCH_LOGO_ALINHAR="${FASTFETCH_LOGO_ALINHAR:-tabular}"

FFL_RASTER=2048

FFL_BASE="$HOME/.local/share/meowsystem/fastfetch"

_ffl_gato_do_dock() {
  local nome
  [ -x "$MEOW_RAIZ/scripts/logo.sh" ] || return 1
  nome="$(MEOW_DRY_RUN=1 NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-}" \
            "$MEOW_RAIZ/scripts/logo.sh" no-dock 2>/dev/null)" || return 1
  printf '%s\n' "$nome"
}

_ffl_o_outro() {
  local atual="$1" i
  local -a nomes=()
  while IFS= read -r svg; do
    case "$(basename "$svg")" in *-symbolic.svg) continue ;; esac
    nomes+=("$(basename "${svg%.svg}")")
  done < <(find "$(meow_mascote_dir)/" -maxdepth 1 -name '*.svg' 2>/dev/null | LC_ALL=C sort)
  [ "${#nomes[@]}" -ge 2 ] || return 1
  for i in "${!nomes[@]}"; do
    [ "${nomes[$i]}" = "$atual" ] && { printf '%s' "${nomes[$(( (i + 1) % ${#nomes[@]} ))]}"; return 0; }
  done
  return 1
}

FFL_FASE=""; FFL_PORQUE=""
case "$FASTFETCH_LOGO_MODO" in
  espelho)
    FFL_ALVO="$FFL_BASE/gato.ansi"
    _dock="$(_ffl_gato_do_dock || true)"
    _outro=""
    if [ -n "$_dock" ] && [ "$("$MEOW_RAIZ/scripts/logo.sh" modo 2>/dev/null)" = "hora" ]; then
      _par_dia="${LOGO_DIA:-mimir}"; _par_noite="${LOGO_NOITE:-coquinha}"
      if [ "$_par_dia" != "$_par_noite" ]; then
        case "$_dock" in
          "$_par_dia")   _outro="$_par_noite" ;;
          "$_par_noite") _outro="$_par_dia" ;;
        esac
      fi
      unset _par_dia _par_noite
    fi
    [ -z "$_outro" ] && [ -n "$_dock" ] && _outro="$(_ffl_o_outro "$_dock" || true)"
    if [ -n "$_outro" ]; then
      FASTFETCH_LOGO_GATO="$_outro"; FFL_PORQUE="o dock está com $_dock"
    else
      # shellcheck source=../lib/noite.sh
      . "$MEOW_RAIZ/lib/noite.sh"
      if meow_e_noite; then FFL_FASE="noite"; FASTFETCH_LOGO_GATO="${FASTFETCH_LOGO_DIA}"
      else                  FFL_FASE="dia";   FASTFETCH_LOGO_GATO="${FASTFETCH_LOGO_NOITE}"; fi
      FFL_PORQUE="não li o botão do dock; espelhei a fase ($FFL_FASE)"
    fi
    unset _dock _outro ;;
  hora)
    # shellcheck source=../lib/noite.sh
    . "$MEOW_RAIZ/lib/noite.sh"
    if meow_e_noite; then FFL_FASE="noite"; FASTFETCH_LOGO_GATO="$FASTFETCH_LOGO_NOITE"
    else                  FFL_FASE="dia";   FASTFETCH_LOGO_GATO="$FASTFETCH_LOGO_DIA"; fi
    FFL_PORQUE="modo hora, $FFL_FASE"
    FFL_ALVO="$FFL_BASE/gato.ansi" ;;
  *)
    FFL_ALVO="$FFL_BASE/$(basename "${FASTFETCH_LOGO_GATO%.svg}").ansi" ;;
esac

FFL_CONF_DELA="$HOME/.config/fastfetch/config.jsonc"
FFL_CONF_DIR="$(dirname "$FFL_CONF_DELA")"

_ffl_link_da_briga() {
  local link para pai
  link="$FFL_CONF_DIR/fastfetch"
  [ -L "$FFL_CONF_DIR" ] && return 1
  [ -L "$link" ] || return 1
  para="$(readlink "$link")"
  pai="$(dirname "$para")"
  if { [ -n "${ZDOTDIR:-}" ] && [ "$pai" = "$ZDOTDIR" ]; } || [ -f "$pai/.zshrc" ]; then
    printf '%s' "$para"; return 0
  fi
  return 1
}

_ffl_assumir_diretorio() {
  local para alvo novo bkp
  if para="$(_ffl_link_da_briga)"; then
    if meow_seco; then
      meow_muda "apagaria o link $FFL_CONF_DIR/fastfetch -> $para, que sobrou da briga pelo diretório"
      return 1
    fi
    rm -f "$FFL_CONF_DIR/fastfetch" || { meow_erro "não consegui apagar o link $FFL_CONF_DIR/fastfetch"; return 2; }
    meow_aviso "apaguei o link $FFL_CONF_DIR/fastfetch -> $para, que sobrou da briga pelo diretório"
    meow_registrar "fastfetch_logo.sh apagou o link $FFL_CONF_DIR/fastfetch (apontava para $para)"
    return 1
  fi
  [ -L "$FFL_CONF_DIR" ] || return 0
  if [ "$FASTFETCH_LOGO_CONF" != "sim" ]; then
    meow_pula "$FFL_CONF_DIR é symlink e FASTFETCH_LOGO_CONF=\"$FASTFETCH_LOGO_CONF\" — fica como está"
    return 0
  fi
  para="$(readlink "$FFL_CONF_DIR")"
  alvo="$(readlink -f "$FFL_CONF_DIR" 2>/dev/null || true)"
  if meow_seco; then
    meow_muda "trocaria o symlink $FFL_CONF_DIR -> $para por um diretório de verdade, com o mesmo conteúdo"
    return 1
  fi

  bkp="$MEOW_ESTADO/backups/$MEOW_CARIMBO-fastfetch"
  mkdir -p "$bkp/conteudo" 2>/dev/null \
    || { meow_erro "não consegui criar $bkp — o symlink fica como está"; return 2; }
  printf '%s\n' "$para" > "$bkp/symlink-apontava-para" 2>/dev/null \
    || { meow_erro "não consegui guardar o backup em $bkp — o symlink fica como está"; return 2; }
  if [ -d "$alvo" ]; then
    cp -a "$alvo/." "$bkp/conteudo/" 2>/dev/null \
      || { meow_erro "não consegui copiar $alvo para o backup — o symlink fica como está"; return 2; }
  fi

  novo="$(mktemp -d -p "$(dirname "$FFL_CONF_DIR")" ".fastfetch.meow.XXXXXX")" \
    || { meow_erro "não consegui montar o diretório novo ao lado de $FFL_CONF_DIR"; return 2; }
  if [ -d "$alvo" ] && ! cp -a "$alvo/." "$novo/" 2>/dev/null; then
    rm -rf "$novo"; meow_erro "não consegui copiar o conteúdo de $alvo — o symlink fica como está"; return 2
  fi
  chmod 755 "$novo"
  rm -f "$FFL_CONF_DIR" || { rm -rf "$novo"; meow_erro "não consegui tirar o symlink $FFL_CONF_DIR"; return 2; }
  if ! mv "$novo" "$FFL_CONF_DIR"; then
    ln -s "$para" "$FFL_CONF_DIR" 2>/dev/null
    rm -rf "$novo"; meow_erro "não consegui pôr o diretório no lugar — o symlink voltou"; return 2
  fi

  if [ -d "$alvo" ]; then
    meow_aviso "$FFL_CONF_DIR deixou de ser symlink para $para: agora é um diretório do MeowSystem, com o mesmo conteúdo"
  else
    meow_aviso "$FFL_CONF_DIR era symlink para $para, que não existe: agora é um diretório vazio do MeowSystem"
  fi
  meow_info  "  backup (o conteúdo e o destino do link): $bkp"
  meow_registrar "fastfetch_logo.sh assumiu $FFL_CONF_DIR (era symlink para $para)"
  return 1
}

_ffl_svg() {
  local dir nome
  case "$FASTFETCH_LOGO_GATO" in
    */*|*.svg) printf '%s' "$FASTFETCH_LOGO_GATO"; return ;;
  esac
  dir="$(meow_mascote_dir)"
  if [ ! -f "$dir/$FASTFETCH_LOGO_GATO.svg" ]; then
    nome="$(python3 "$MEOW_RAIZ/scripts/pack.py" mascote-padrao "$(meow_pack_dir)" "${FFL_FASE:-dia}" 2>/dev/null)"
    if [ -n "$nome" ] && [ -f "$dir/$nome.svg" ]; then printf '%s' "$dir/$nome.svg"; return; fi
  fi
  printf '%s' "$dir/$FASTFETCH_LOGO_GATO.svg"
}

_ffl_linhas_da_proporcao() {
  awk -v c="$FASTFETCH_LOGO_COLUNAS" -v r="$FASTFETCH_LOGO_CELULA" \
      'BEGIN { n = int(c / r + 0.5); if (n < 1) n = 1; print n }'
}

_ffl_linhas_pedida() {
  case "$FASTFETCH_LOGO_LINHAS" in
    ''|*[!0-9]*) _ffl_linhas_da_proporcao ;;
    *) [ "$FASTFETCH_LOGO_LINHAS" -ge 1 ] 2>/dev/null \
         && printf '%s' "$FASTFETCH_LOGO_LINHAS" || printf '1' ;;
  esac
}

FASTFETCH_LOGO_DESVIO_TETO=12

_ffl_linhas() {
  local pedida; pedida="$(_ffl_linhas_pedida)"
  local desvio; desvio="$(_ffl_desvio_de "$pedida")"
  if [ "${desvio:-0}" -gt "$FASTFETCH_LOGO_DESVIO_TETO" ] 2>/dev/null; then
    _ffl_linhas_da_proporcao
  else
    printf '%s' "$pedida"
  fi
}

_ffl_desvio_de() {
  awk -v c="$FASTFETCH_LOGO_COLUNAS" -v r="$FASTFETCH_LOGO_CELULA" -v l="$1" \
      'BEGIN { ideal = c / r; if (ideal <= 0) { print 0; exit }
               d = (l - ideal) / ideal * 100; if (d < 0) d = -d; printf "%d", d + 0.5 }'
}

_ffl_desvio() { _ffl_desvio_de "$(_ffl_linhas_pedida)"; }

_ffl_carimbo_texto() {
  printf '%s %s %s %s' "$(basename "${FASTFETCH_LOGO_GATO%.svg}")" \
    "$FASTFETCH_LOGO_COLUNAS" "$(_ffl_linhas)" "$(_ffl_blocos)"
}

_ffl_alinhamento() {
  case "$FASTFETCH_LOGO_ALINHAR" in
    contorno|degraus|crescente|reto) printf '%s' "$FASTFETCH_LOGO_ALINHAR" ;;
    *)                               printf 'tabular' ;;
  esac
}

_ffl_quer_meow_fetch() {
  [ "$(_ffl_alinhamento)" != "tabular" ]
}

_ffl_linhas_do_texto() {
  if [ -z "${FFL_TEXTO_LINHAS:-}" ]; then
    if meow_tem fastfetch; then
      FFL_TEXTO_LINHAS="$(fastfetch --logo none --pipe false 2>/dev/null | wc -l)"
    else
      FFL_TEXTO_LINHAS=0
    fi
  fi
  printf '%s' "$FFL_TEXTO_LINHAS"
}

_ffl_quebras() {
  case "$FASTFETCH_LOGO_QUEBRAS" in
    ''|auto)
      awk -v g="$(_ffl_linhas)" -v t="$(_ffl_linhas_do_texto)" \
          'BEGIN { n = int((t - g) / 2); if (n < 0) n = 0; print n }' ;;
    *[!0-9]*) printf '6' ;;
    *) printf '%s' "$FASTFETCH_LOGO_QUEBRAS" ;;
  esac
}

_ffl_fonte_arquivo() {
  local nome
  nome="$(sed -n 's/^"\(.*\)"$/\1/p' "$(meow_cosmic_dir)/com.system76.CosmicTerm/$(meow_cosmic_v com.system76.CosmicTerm)/font_name" 2>/dev/null)"
  [ -n "$nome" ] || nome="${FASTFETCH_LOGO_FONTE:-monospace}"
  fc-match -f '%{file}' "$nome:spacing=100" 2>/dev/null
}

_ffl_tem_sextante() {
  meow_tem convert || return 1
  local arq media
  arq="$(_ffl_fonte_arquivo)"
  [ -n "$arq" ] && [ -f "$arq" ] || return 1
  media="$(convert -background black -fill white -font "$arq" -pointsize 40 \
             label:"🬀" -format "%[fx:mean]" info: 2>/dev/null)"
  case "${media:-0}" in
    0|0.0|0.00*|"") return 1 ;;
    *) return 0 ;;
  esac
}

_ffl_blocos() {
  case "${FASTFETCH_LOGO_BLOCOS:-auto}" in
    quadrante) printf 'quad' ;;
    sextante)  printf 'sext' ;;
    *) if _ffl_tem_sextante; then printf 'sext'; else printf 'quad'; fi ;;
  esac
}

_ffl_gerar() {
  local destino="$1" svg="$2" colunas="$3" linhas="$4"
  python3 -I - "$svg" "$colunas" "$linhas" "$destino" "$FFL_RASTER" "$(_ffl_blocos)" <<'PY'
import subprocess, sys

svg, colunas, linhas, destino, raster, blocos = (
    sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], int(sys.argv[5]),
    sys.argv[6])
SX, SY = (2, 3) if blocos == "sext" else (2, 2)

png = subprocess.run(["rsvg-convert", "-a", "-w", str(raster), "-h", str(raster), svg],
                     check=True, capture_output=True).stdout

larg, alt = colunas * SX, linhas * SY
txt = subprocess.run(
    ["convert", "png:-", "-alpha", "on", "-filter", "Lanczos",
     "-resize", "%dx%d!" % (larg, alt), "-depth", "8", "txt:-"],
    input=png, check=True, capture_output=True).stdout.decode()

px = {}
for l in txt.splitlines():
    if l.startswith("#") or ":" not in l:
        continue
    pos, resto = l.split(":", 1)
    x, y = (int(v) for v in pos.split(","))
    h = resto.split("#", 1)[1].split()[0]
    px[(x, y)] = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4, 6))

LIMIAR = 128
VAZIO = (0, 0, 0, 0)

QUAD = " ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█"


def glifo(m, n):
    """O caractere que acende os subpixels de `m`, num mosaico de `n` deles."""
    if n == 4:
        return QUAD[m]
    if m == 0:
        return " "
    if m == 63:
        return "█"
    if m == 21:
        return "▌"
    if m == 42:
        return "▐"
    i = m - 1 - (1 if m > 21 else 0) - (1 if m > 42 else 0)
    return chr(0x1FB00 + i)


def _media(cores):
    n = len(cores)
    return (sum(c[0] for c in cores) // n,
            sum(c[1] for c in cores) // n,
            sum(c[2] for c in cores) // n)


def _erro(cores, m):
    """Quão longe cada pixel fica da média do seu grupo, na partição `m`."""
    a = [c for i, c in enumerate(cores) if m >> i & 1]
    b = [c for i, c in enumerate(cores) if not (m >> i & 1)]
    total = 0
    for grupo in (a, b):
        if not grupo:
            continue
        med = _media(grupo)
        for c in grupo:
            total += sum((c[k] - med[k]) ** 2 for k in (0, 1, 2))
    return total


N = SX * SY
partes = []
for ly in range(linhas):
    fg = bg = "reset"
    linha = ["\x1b[0m"]
    for x in range(colunas):
        celula = [px.get((x * SX + dx, ly * SY + dy), VAZIO)
                  for dy in range(SY) for dx in range(SX)]
        cheios = [i for i, c in enumerate(celula) if c[3] >= LIMIAR]

        if not cheios:
            novo_fg, novo_bg, ch = fg, None, " "
        elif len(cheios) < N:
            m = sum(1 << i for i in cheios)
            novo_fg, novo_bg, ch = _media([celula[i] for i in cheios]), None, glifo(m, N)
        else:
            melhor = min(range(1 << N), key=lambda m: (_erro(celula, m), m))
            a = [celula[i] for i in range(N) if melhor >> i & 1]
            b = [celula[i] for i in range(N) if not (melhor >> i & 1)]
            novo_fg = _media(a) if a else _media(b)
            novo_bg = _media(b) if b else _media(a)
            ch = glifo(melhor, N)
        if novo_bg != bg:
            linha.append("\x1b[49m" if novo_bg is None
                         else "\x1b[48;2;%d;%d;%dm" % novo_bg)
            bg = novo_bg
        if novo_fg != fg:
            linha.append("\x1b[38;2;%d;%d;%dm" % novo_fg)
            fg = novo_fg
        linha.append(ch)
    linha.append("\x1b[0m")
    partes.append("".join(linha))

with open(destino, "w", encoding="utf-8") as f:
    f.write("\n".join(partes) + "\n")
PY
}

_ffl_carimbo() { printf '%s/.gato-atual' "$FFL_BASE"; }
_ffl_ja_esta_certo() {
  local svg="$1" colunas="$2" linhas="$3" querido lido
  [ -f "$FFL_ALVO" ] || return 1
  lido="$(cat "$(_ffl_carimbo)" 2>/dev/null)" || return 1
  querido="$(_ffl_carimbo_texto)"
  [ "$lido" = "$querido" ] || return 1
  [ -f "$svg" ] && [ "$svg" -nt "$FFL_ALVO" ] && return 1
  return 0
}

_ffl_instalar() {
  local svg colunas linhas tmp
  svg="$(_ffl_svg)"; colunas="$FASTFETCH_LOGO_COLUNAS"; linhas="$(_ffl_linhas)"

  [ -f "$svg" ] || { meow_erro "não achei o SVG '$svg'"; return "$MEOW_ERRO"; }
  meow_destino_permitido "$FFL_ALVO" || return "$MEOW_ERRO"

  if [ "${FFL_FUNDO:-0}" = "1" ] && _ffl_ja_esta_certo "$svg" "$colunas" "$linhas"; then
    return "$MEOW_OK"
  fi

  if meow_seco; then
    tmp="$(mktemp -p "${TMPDIR:-/tmp}" ".meow-ffl.XXXXXX")" || return "$MEOW_ERRO"
    if ! _ffl_gerar "$tmp" "$svg" "$colunas" "$linhas"; then
      rm -f "$tmp"; meow_erro "falha ao converter '$svg' para ANSI"; return "$MEOW_ERRO"
    fi
    if [ -f "$FFL_ALVO" ] && cmp -s "$tmp" "$FFL_ALVO"; then
      rm -f "$tmp"; return "$MEOW_OK"
    fi
    rm -f "$tmp"; meow_muda "mudaria $FFL_ALVO"; return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$FFL_BASE" || return "$MEOW_ERRO"
  tmp="$(mktemp -p "$FFL_BASE" ".meow-ffl.XXXXXX")" || return "$MEOW_ERRO"
  if ! _ffl_gerar "$tmp" "$svg" "$colunas" "$linhas"; then
    rm -f "$tmp"; meow_erro "falha ao converter '$svg' para ANSI"; return "$MEOW_ERRO"
  fi
  if [ -f "$FFL_ALVO" ] && cmp -s "$tmp" "$FFL_ALVO"; then
    rm -f "$tmp"
    printf '%s\n' "$(_ffl_carimbo_texto)" > "$(_ffl_carimbo)" 2>/dev/null || true
    return "$MEOW_OK"
  fi
  chmod 644 "$tmp"
  meow_guardar_antes "$FFL_ALVO"; meow_guardar_antes "$(_ffl_carimbo)"
  mv -f "$tmp" "$FFL_ALVO" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  printf '%s\n' "$(_ffl_carimbo_texto)" > "$(_ffl_carimbo)" 2>/dev/null || true
  meow_manifesto_registrar "$FFL_ALVO"
  _ffl_varrer_orfaos
  return "$MEOW_DIVERGENTE"
}

_ffl_varrer_orfaos() {
  local velho
  [ -d "$FFL_BASE" ] || return 0
  for velho in "$FFL_BASE"/*.ansi; do
    [ -f "$velho" ] || continue
    [ "$velho" = "$FFL_ALVO" ] && continue
    if meow_seco; then meow_muda "removeria $velho (sobrou do modo anterior)"
    else meow_guardar_antes "$velho"; rm -f "$velho" && meow_info "removi $(basename "$velho") (sobrou do modo anterior)"; fi
  done
  return 0
}

_ffl_ler_conf() {
  [ -f "$FFL_CONF_DELA" ] || return 1
  python3 -I - "$FFL_CONF_DELA" <<'PY'
import json, os, sys

bruto = open(sys.argv[1], encoding="utf-8").read()
saida, i, n, dentro, escapa = [], 0, len(bruto), False, False
while i < n:
    c = bruto[i]
    if dentro:
        saida.append(c)
        if escapa:      escapa = False
        elif c == "\\": escapa = True
        elif c == '"':  dentro = False
        i += 1
    elif c == '"':
        dentro = True; saida.append(c); i += 1
    elif c == "/" and i + 1 < n and bruto[i + 1] == "/":
        while i < n and bruto[i] != "\n": i += 1
    elif c == "/" and i + 1 < n and bruto[i + 1] == "*":
        i += 2
        while i + 1 < n and not (bruto[i] == "*" and bruto[i + 1] == "/"): i += 1
        i += 2
    else:
        saida.append(c); i += 1

try:
    d = json.loads("".join(saida))
except Exception as e:
    print("erro\t%s" % e); print(""); print("0"); sys.exit(0)

logo = d.get("logo") or {}
fonte = logo.get("source") or ""
if fonte.startswith("~"):
    fonte = os.path.expanduser(fonte)
mods = d.get("modules") or []
chaves = [m.get("key") for m in mods if isinstance(m, dict) and m.get("key")]
pad = logo.get("padding") or {}
print(logo.get("type") or "")
print(fonte)
print(len(chaves))
print(pad.get("top", ""))
print(pad.get("right", ""))
PY
}

_ffl_escrever_conf() {
  local alvo_rel="~/.local/share/meowsystem/fastfetch/$(basename "$FFL_ALVO")"
  local bkp="$MEOW_ESTADO/backups/$MEOW_CARIMBO-vizinho"

  if meow_seco; then
    meow_muda "mudaria logo.source de $FFL_CONF_DELA para \"$alvo_rel\""
    return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$bkp" 2>/dev/null || { meow_erro "não consegui criar $bkp"; return "$MEOW_ERRO"; }
  cp -a "$FFL_CONF_DELA" "$bkp/config.jsonc" 2>/dev/null \
    || { meow_erro "não consegui guardar backup de $FFL_CONF_DELA — não vou escrever"; return "$MEOW_ERRO"; }

  python3 "$MEOW_RAIZ/scripts/fastfetch_conf.py" escrever-logo \
    "$FFL_CONF_DELA" "$alvo_rel" "$(_ffl_quebras)" "$FASTFETCH_LOGO_RECUO"
  case "$?" in
    0) meow_ok "o seu config.jsonc já estava como o meow.conf pede"
       return "$MEOW_OK" ;;
    2) meow_erro "não consegui escrever em $FFL_CONF_DELA"
       meow_info  "  backup intacto: $bkp/config.jsonc"
       return "$MEOW_ERRO" ;;
  esac

  meow_aviso "escrevi no config.jsonc do fastfetch (logo.source -> $alvo_rel)"
  meow_info  "  backup: $bkp/config.jsonc"
  meow_info  "  desligue com FASTFETCH_LOGO_CONF=\"nao\" no ~/.config/meow/meow.conf"
  meow_registrar "fastfetch_logo.sh escreveu logo.source=$alvo_rel em $FFL_CONF_DELA"
  return "$MEOW_DIVERGENTE"
}

_ffl_fronteira() {
  local dados tipo fonte nchaves pad_topo pad_recuo
  if ! dados="$(_ffl_ler_conf 2>/dev/null)"; then
    meow_aviso "não achei $FFL_CONF_DELA — nada a conferir no config do fastfetch"
    return 2
  fi
  tipo="$(printf '%s' "$dados"  | sed -n '1p')"
  fonte="$(printf '%s' "$dados" | sed -n '2p')"
  nchaves="$(printf '%s' "$dados" | sed -n '3p')"
  pad_topo="$(printf '%s' "$dados"  | sed -n '4p')"
  pad_recuo="$(printf '%s' "$dados" | sed -n '5p')"
  case "$tipo" in
    erro*) meow_aviso "não consegui interpretar o seu config.jsonc: $tipo"
           return 2 ;;
  esac

  meow_info "seu config.jsonc: logo.type=\"$tipo\" logo.source=\"${fonte:-<vazio>}\""
  meow_quieto || meow_info "  padding: topo=${pad_topo:-<sem>} recuo=${pad_recuo:-<sem>} (o conf pede $(_ffl_quebras) e $FASTFETCH_LOGO_RECUO)"
  meow_info "  módulos com chave própria (as em português): $nchaves"

  if [ "$fonte" != "$FFL_ALVO" ]; then
    return 1
  fi
  if [ "$tipo" != "file-raw" ]; then
    meow_aviso "aponta para $(basename "$FFL_ALVO"), mas com logo.type=\"$tipo\" — o certo é \"file-raw\""
    return 1
  fi
  if [ "$(_ffl_alinhamento)" = "tabular" ]; then
    if [ -n "$pad_topo" ] && [ "$pad_topo" != "$(_ffl_quebras)" ]; then
      meow_muda "o padding.top do config.jsonc é $pad_topo e o conf pede $(_ffl_quebras)"
      return 1
    fi
    if [ -n "$pad_recuo" ] && [ "$pad_recuo" != "$FASTFETCH_LOGO_RECUO" ]; then
      meow_muda "o padding.right do config.jsonc é $pad_recuo e o conf pede $FASTFETCH_LOGO_RECUO"
      return 1
    fi
  fi
  meow_ok "o seu config.jsonc já aponta para $(basename "$FFL_ALVO")"
  return 0
}

_ffl_meow_fetch() { printf '%s/.local/bin/meow-fetch' "$HOME"; }

_ffl_texto_meow_fetch() {
  cat <<'FIM'
#!/usr/bin/env bash
# meow-fetch — o fastfetch com o mascote do MeowSystem alinhado como o meow.conf pede.
#
# NÃO É UM SUBSTITUTO DO FASTFETCH. Com FASTFETCH_LOGO_ALINHAR="tabular" (o
# padrão) ele é um `exec fastfetch "$@"` e mais nada: mesma saída, mesmo custo,
# mesmos argumentos. Só o `contorno` faz este arquivo ter trabalho.
#
# Ele é gerado por scripts/fastfetch_logo.sh e conferido pelo `meow doctor`.
# Editar aqui não adianta: a próxima passagem reescreve.
set -uo pipefail

conf="${MEOW_CONF:-$HOME/.config/meow/meow.conf}"
alinhar="tabular"; recuo="3"; topo="auto"
if [ -r "$conf" ]; then
  # Subshell: o conf é um arquivo de atribuições, mas ler o arquivo de
  # configuração de um projeto para dentro do ambiente do terminal dela seria
  # exportar cem variáveis em toda janela nova.
  #
  # AS DUAS COSTURAS AQUI SÃO CONTRA UM MODO DE FALHA CALADO.
  #   `set +u`: a subshell herdava o `set -u` da linha acima, e uma linha do
  #   conf que expandisse variável não definida matava a subshell ANTES do
  #   `printf`. O `eval` recebia string vazia, o alinhamento caía no `tabular`
  #   do padrão, e a saída ficava byte a byte igual ao fastfetch puro: sem mascote
  #   e sem uma palavra de aviso. Nenhum `conferir` acusava, porque ele lê o
  #   conf por outro caminho.
  #
  #   `>/dev/null` no `.`: o stdout do conf não era isolado, então um `echo` de
  #   dentro dele ia para o `eval` — `echo "conf carregado"` virava
  #   `conf: comando não encontrado` em toda janela nova.
  dados="$(
    set +u
    . "$conf" >/dev/null 2>&1
    printf 'alinhar=%q; recuo=%q; topo=%q\n' \
      "${FASTFETCH_LOGO_ALINHAR:-tabular}" \
      "${FASTFETCH_LOGO_RECUO:-3}" "${FASTFETCH_LOGO_QUEBRAS:-auto}"
  )"
  if [ -n "$dados" ]; then
    eval "$dados"
  else
    printf 'meow-fetch: não consegui ler %s — alinhamento tabular\n' "$conf" >&2
  fi
fi

# O TÍTULO NÃO PASSA POR AQUI, e a tentativa de fazê-lo passar está registrada
# porque ela custou uma tela em branco: o fastfetch 2.61.0 REMOVEU as opções de
# módulo da linha de comando —
#
#   Error: Unsupported module option: --title-format
#          Support of module options has been removed.
#          Please add the flag to the JSON config instead.
#
# e, como ele sai com erro antes de imprimir uma linha, o compositor recebia
# entrada vazia e o terminal abria só com o mascote. Quem escreve o formato do
# título é o `fastfetch_logo.sh`, no `config.jsonc`, pelas mesmas quatro
# guardas de sempre.
case "$alinhar" in
  contorno|degraus|crescente|reto) ;;
  *) exec fastfetch "$@" ;;
esac

ponteiro="${XDG_STATE_HOME:-$HOME/.local/state}/meowsystem/raiz"
raiz="${MEOW_RAIZ:-}"
[ -n "$raiz" ] || raiz="$(head -n1 "$ponteiro" 2>/dev/null || true)"
alinhador="$raiz/scripts/fastfetch_alinhar.py"
gato="$HOME/.local/share/meowsystem/fastfetch/gato.ansi"

# SEM O DISCO, O TERMINAL ABRE IGUAL. Um `fastfetch` que falha porque o NVMe do
# projeto não montou seria o pior lugar possível para este projeto aparecer.
# O `python3` entra na lista porque ele é peça do cano como as outras três.
if [ -z "$raiz" ] || [ ! -f "$alinhador" ] || [ ! -f "$gato" ] \
   || ! command -v python3 >/dev/null 2>&1; then
  exec fastfetch "$@"
fi

# O CANO NÃO É O ÚNICO CAMINHO DA SAÍDA, e essa era a falha que a guarda acima
# não cobria: passada a guarda, o que a tela mostrava era só o que saísse do
# python. Um traceback, um gato.ansi ilegível, qualquer coisa — e o stdout ia a
# ZERO byte: a saudação inteira sumia numa janela nova. Aqui o fetch vai para
# uma variável primeiro, e o alinhado só a substitui se der certo E vier com
# conteúdo. O pior caso volta a ser o que o cabeçalho promete: o fastfetch
# tabular, sem mascote.
saida="$(fastfetch --logo none "$@")"
if alinhada="$(printf '%s\n' "$saida" \
     | python3 "$alinhador" --gato "$gato" --recuo "$recuo" --topo "$topo" \
         --modo "$alinhar")" && [ -n "$alinhada" ]; then
  printf '%s\n' "$alinhada"
else
  printf '%s\n' "$saida"
fi
FIM
}

_ffl_instalar_meow_fetch() {
  local alvo texto
  alvo="$(_ffl_meow_fetch)"; texto="$(_ffl_texto_meow_fetch)"
  if [ -f "$alvo" ] && [ -x "$alvo" ] && [ "$(cat "$alvo")" = "$texto" ]; then
    return 0
  fi
  meow_seco && { meow_muda "escreveria $alvo"; return 1; }
  meow_guardar_antes "$alvo"
  mkdir -p "$(dirname "$alvo")" || return 2
  printf '%s\n' "$texto" > "$alvo" || return 2
  chmod 755 "$alvo" || return 2
  meow_manifesto_registrar "$alvo"
  return 1
}

_ffl_titulo_confere() {
  local atual rc
  [ -f "$FFL_CONF_DELA" ] || return 2
  atual="$(python3 "$MEOW_RAIZ/scripts/fastfetch_conf.py" ler-titulo "$FFL_CONF_DELA" 2>/dev/null)"
  rc=$?
  [ "$rc" = "0" ] || return 2
  [ "$atual" = "$FASTFETCH_TITULO" ]
}

_ffl_escrever_titulo() {
  local bkp
  _ffl_titulo_confere; case $? in 0) return 0 ;; 2) return 2 ;; esac

  if [ "$FASTFETCH_LOGO_CONF" != "sim" ]; then
    meow_pula "FASTFETCH_LOGO_CONF=\"nao\" — não escrevo o título no config.jsonc"
    meow_info  "  para pôr à mão, troque \"title\" por:"
    meow_info  "    { \"type\": \"title\", \"format\": \"$FASTFETCH_TITULO\" }"
    return 2
  fi
  if meow_seco; then
    meow_muda "poria o título \"$FASTFETCH_TITULO\" em $FFL_CONF_DELA"
    return 1
  fi

  bkp="$MEOW_ESTADO/backups/$MEOW_CARIMBO-vizinho"
  mkdir -p "$bkp" 2>/dev/null || { meow_erro "não consegui criar $bkp"; return 2; }
  cp -a "$FFL_CONF_DELA" "$bkp/config.jsonc" 2>/dev/null \
    || { meow_erro "não consegui guardar backup de $FFL_CONF_DELA — não vou escrever"; return 2; }

  python3 "$MEOW_RAIZ/scripts/fastfetch_conf.py" escrever-titulo \
    "$FFL_CONF_DELA" "$FASTFETCH_TITULO"
  case $? in 2) meow_erro "não consegui escrever o título em $FFL_CONF_DELA"; return 2 ;; esac

  if [ -n "$FASTFETCH_TITULO" ]; then
    meow_aviso "escrevi o título no config.jsonc do fastfetch (\"$FASTFETCH_TITULO\")"
  else
    meow_aviso "devolvi o título do config.jsonc ao padrão do fastfetch"
  fi
  meow_info  "  backup: $bkp/config.jsonc"
  meow_registrar "fastfetch_logo.sh escreveu title.format=$FASTFETCH_TITULO em $FFL_CONF_DELA"
  return 1
}

_ffl_patch_texto() {
  cat <<TXT
  "logo": {
    "type": "file-raw",
    "source": "~/.local/share/meowsystem/fastfetch/$(basename "$FFL_ALVO")",
    "padding": { "top": $(_ffl_quebras), "right": $FASTFETCH_LOGO_RECUO, "left": 0 }
  },
TXT
}

cmd_patch() {
  meow_info "cole isto NO LUGAR do bloco \"logo\" de $FFL_CONF_DELA"
  meow_info "(é o seu arquivo do fastfetch: com FASTFETCH_LOGO_CONF=\"nao\""
  meow_info " este script só mostra o bloco, e não escreve nele)"
  printf '\n'
  _ffl_patch_texto
  printf '\n'
  meow_info "o \"padding\" vem do meow.conf: FASTFETCH_LOGO_QUEBRAS=$FASTFETCH_LOGO_QUEBRAS -> $(_ffl_quebras)"
  meow_info "  e FASTFETCH_LOGO_RECUO=$FASTFETCH_LOGO_RECUO, para um mascote de $(_ffl_linhas) linhas"
  meow_info "cópia pronta no repositório: assets/fastfetch/config-logo.jsonc.sugestao"
  return "$MEOW_OK"
}

cmd_aplicar() {
  local rc rcf
  [ "$FASTFETCH_LOGO" = "sim" ] || {
    meow_pula "FASTFETCH_LOGO=\"$FASTFETCH_LOGO\" no meow.conf — o logo do fastfetch fica como está"
    return "$MEOW_OK"; }
  meow_tem python3       || { meow_erro "falta python3";                 return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem rsvg-convert  || { meow_erro "falta rsvg-convert (librsvg2-bin)"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem convert       || { meow_erro "falta convert (imagemagick)";   return "$MEOW_SEM_DEPENDENCIA"; }

  _ffl_instalar; rc=$?
  [ "$rc" = "$MEOW_ERRO" ] && return "$rc"

  if [ "$rc" = "$MEOW_DIVERGENTE" ] && meow_seco; then
    meow_muda "geraria o(a) $FASTFETCH_LOGO_GATO em $FASTFETCH_LOGO_COLUNAS x $(_ffl_linhas) células em $FFL_ALVO"
  elif [ "$rc" = "$MEOW_DIVERGENTE" ]; then
    meow_muda "$FASTFETCH_LOGO_GATO em ANSI ($FASTFETCH_LOGO_COLUNAS x $(_ffl_linhas) células)${FFL_PORQUE:+ — $FFL_PORQUE}"
    meow_info "para ver: scripts/fastfetch_logo.sh ver"
  else
    meow_ok "o logo ANSI já estava gerado (${FASTFETCH_LOGO_GATO}${FFL_PORQUE:+ — $FFL_PORQUE})"
  fi

  _dv="$(_ffl_desvio)"
  if [ "${_dv:-0}" -gt "$FASTFETCH_LOGO_DESVIO_TETO" ] 2>/dev/null; then
    meow_aviso "altura aparada: $(_ffl_linhas_pedida) linhas sairiam ${_dv}% fora da proporção da célula (esticado)"
    meow_info  "  usei $(_ffl_linhas) linhas para $FASTFETCH_LOGO_COLUNAS colunas, que é a proporção desta fonte"
    meow_info  "  guardei o seu $(_ffl_linhas_pedida): ele volta a valer se você mudar as colunas, ou baixar de ${FASTFETCH_LOGO_DESVIO_TETO}% de desvio"
  fi
  unset _dv

  _ffl_instalar_meow_fetch; _rcm=$?
  case "$_rcm" in
    1) rc="$MEOW_DIVERGENTE"; meow_muda "meow-fetch em $(_ffl_meow_fetch)" ;;
    2) meow_erro "não consegui escrever o $(_ffl_meow_fetch)" ;;
  esac
  unset _rcm

  if _ffl_quer_meow_fetch; then
    meow_info "o $(_ffl_alinhamento) aparece quando o seu shell chama meow-fetch no lugar de fastfetch"
    meow_info "  o MeowSystem não lê nem escreve arquivo de shell — essa linha é sua"
  fi

  _ffl_assumir_diretorio
  case $? in
    1) rc="$MEOW_DIVERGENTE" ;;
    2) meow_erro "não assumi $FFL_CONF_DIR, e por isso não escrevo nele"
       meow_registrar "fastfetch_logo.sh aplicar rc=2, o symlink ficou"
       return "$MEOW_ERRO" ;;
  esac

  _ffl_escrever_titulo; _rct=$?
  [ "$_rct" = "1" ] && rc="$MEOW_DIVERGENTE"
  unset _rct

  _ffl_fronteira; rcf=$?

  if [ "$rcf" = "1" ] && [ "$FASTFETCH_LOGO_CONF" = "sim" ] && [ -f "$FFL_CONF_DELA" ]; then
    local rce; _ffl_escrever_conf; rce=$?
    if [ "$rce" = "$MEOW_DIVERGENTE" ]; then
      rc="$MEOW_DIVERGENTE"
      meow_seco || { _ffl_fronteira >/dev/null 2>&1; rcf=$?; }
    elif [ "$rce" = "$MEOW_ERRO" ]; then
      meow_erro "não consegui escrever no config.jsonc — deixo o patch abaixo"
    fi
  fi

  if [ "$rcf" = "1" ]; then
    printf '\n'
    meow_aviso "o fastfetch ainda NÃO vai mostrar o mascote: falta uma troca de"
    meow_aviso "  duas chaves no config.jsonc do fastfetch, que é seu e não nosso."
    printf '\n'
    _ffl_patch_texto
    printf '\n'
    meow_registrar "fastfetch_logo.sh aplicar rc=$rc fronteira=pendente"
    [ "$rc" = "$MEOW_DIVERGENTE" ] && return "$MEOW_DIVERGENTE"
    return 4
  fi

  meow_registrar "fastfetch_logo.sh aplicar rc=$rc"
  return "$rc"
}

cmd_conferir() {
  local rc rcf
  [ "$FASTFETCH_LOGO" = "sim" ] || {
    meow_pula "FASTFETCH_LOGO=\"$FASTFETCH_LOGO\" no meow.conf — nada a conferir"
    return "$MEOW_OK"; }
  meow_tem python3      || { meow_erro "falta python3";                     return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem rsvg-convert || { meow_erro "falta rsvg-convert (librsvg2-bin)"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem convert      || { meow_erro "falta convert (imagemagick)";       return "$MEOW_SEM_DEPENDENCIA"; }

  if [ ! -f "$FFL_ALVO" ]; then
    meow_muda "logo ANSI ausente ($FFL_ALVO)"
    return "$MEOW_DIVERGENTE"
  fi

  MEOW_SECO=1 _ffl_instalar >/dev/null; rc=$?
  [ "$rc" = "$MEOW_ERRO" ] && return "$rc"
  if [ "$rc" != "$MEOW_OK" ]; then
    meow_muda "logo ANSI divergente do SVG/tamanho pedidos"
    return "$MEOW_DIVERGENTE"
  fi
  if _ffl_link_da_briga >/dev/null; then
    meow_muda "$FFL_CONF_DIR/fastfetch é um link para $(readlink "$FFL_CONF_DIR/fastfetch") que sobrou da briga — sairia"
    return "$MEOW_DIVERGENTE"
  fi
  if [ -L "$FFL_CONF_DIR" ] && [ "$FASTFETCH_LOGO_CONF" = "sim" ]; then
    meow_muda "$FFL_CONF_DIR é symlink para $(readlink "$FFL_CONF_DIR") — viraria um diretório do MeowSystem, com o mesmo conteúdo"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "logo ANSI conforme ($FASTFETCH_LOGO_COLUNAS x $(_ffl_linhas) células, $(_ffl_blocos))"
  meow_info "alinhamento: $(_ffl_alinhamento) · $(_ffl_quebras) linha(s) antes, recuo de $FASTFETCH_LOGO_RECUO"

  if ! MEOW_SECO=1 _ffl_instalar_meow_fetch >/dev/null; then
    meow_muda "o $(_ffl_meow_fetch) está desatualizado (ou não existe)"
    return "$MEOW_DIVERGENTE"
  fi
  if _ffl_titulo_confere; then :; else
    [ "$?" = "1" ] && {
      meow_muda "o título do config.jsonc não é o que o conf pede (\"$FASTFETCH_TITULO\")"
      return "$MEOW_DIVERGENTE"; }
  fi

  _ffl_fronteira; rcf=$?
  case "$rcf" in
    0) return "$MEOW_OK" ;;
    2) return "$MEOW_OK" ;;
    *) meow_pula "o config.jsonc do fastfetch é seu — 'fastfetch_logo.sh patch' mostra o que colar"
       return 4 ;;
  esac
}

cmd_ver() {
  [ -f "$FFL_ALVO" ] || { meow_erro "não há logo gerado: ele nasce na próxima passada do doctor"; return "$MEOW_DIVERGENTE"; }
  printf '\n'
  cat "$FFL_ALVO"
  printf '\n'
  meow_info "$FFL_ALVO — $FASTFETCH_LOGO_COLUNAS colunas x $(_ffl_linhas) linhas"
  meow_info "no lugar, com os seus módulos: fastfetch --logo-type file-raw --logo $FFL_ALVO"
  return "$MEOW_OK"
}

cmd_remover() {
  if [ ! -f "$FFL_ALVO" ]; then meow_pula "nada a remover"; return "$MEOW_OK"; fi
  meow_seco && { meow_muda "removeria $FFL_ALVO"; return "$MEOW_DIVERGENTE"; }
  meow_guardar_antes "$FFL_ALVO"
  rm -f "$FFL_ALVO"
  rmdir "$FFL_BASE" 2>/dev/null
  meow_muda "logo ANSI removido — o fastfetch volta ao logo padrão dele"
  meow_aviso "o seu config.jsonc continua como está: se ele aponta para este"
  meow_aviso "  arquivo, o fastfetch cai no logo da distribuição (não quebra nada)"
  meow_registrar "fastfetch_logo.sh remover"
  return "$MEOW_DIVERGENTE"
}

cmd_reverter() {
  meow_pula "o MeowSystem não escreve em arquivo de shell — nada a desfazer no fastfetch"
  return "$MEOW_OK"
}

case "${1:-aplicar}" in
  aplicar)  cmd_aplicar ;;
  conferir) cmd_conferir ;;
  ver)      cmd_ver ;;
  patch)    cmd_patch ;;
  remover)  cmd_remover ;;
  reverter) cmd_reverter ;;
  *) meow_erro "uso: fastfetch_logo.sh {aplicar|conferir|ver|patch|remover|reverter}"; exit "$MEOW_ERRO" ;;
esac

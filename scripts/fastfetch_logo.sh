#!/usr/bin/env bash
# fastfetch_logo.sh — a Coquinha em ANSI no lugar do logo do Pop!_OS, e a
# fronteira que impede este script de terminar o serviço sozinho.
#
# O `fastfetch` abre o terminal dela com o logo do **Pop!_OS**, numa máquina que
# se chama MeowSystem, tem mascote no painel e cujo dono tem dois mascotes reais.
#
# Ela reprovou desenho autoral ("sinceramente são péssimos") e estava certa.
#
# **Não existe foto da Coquinha nesta máquina**.
#
#   3. O `chafa` NÃO FOI INSTALADO, E NÃO FAZ FALTA. O binário não está na
#      máquina e `ldconfig -p | grep chafa` é vazio; o `--logo-type chafa` deste
#      `fastfetch` 2.61.0 até produz saída, mas em ASCII de 8 cores (`/`, `7`,
#      `*`, com `\e[36m`/`\e[37m`) — pior que o meio-bloco truecolor que o
#      conversor daqui escreve. Um `apt install` para piorar o resultado seria
#      dependência nova em troca de nada.
# O `config.jsonc` do fastfetch é território da Aurora: este script escreve só o
# `.ansi` em `~/.local/share/meowsystem/` e lê o config; sem apontar, sai 4 (e não
# 1), para o doctor não anunciar um conserto que não pode fazer.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# Ela é LIDA aqui, e não só no `install.sh`, porque chave de configuração que
# ninguém lê é o defeito que este repositório já varreu uma vez: o `meow
# configurar` perguntava, dizia "gravado", e a saída continuava idêntica.
FASTFETCH_LOGO="${FASTFETCH_LOGO:-sim}"

# O mascote. `coquinha` e `mimir` saem de `packs/meowsystem/mascote/`; qualquer outro valor é
# tratado como caminho de arquivo, para ela poder apontar um SVG dela mesma.
FASTFETCH_LOGO_GATO="${FASTFETCH_LOGO_GATO:-coquinha}"

# --- O MASCOTE DO TERMINAL PASSA A SEGUIR O RELÓGIO ------------------
# Aqui é MUITO mais barato que lá — o `fastfetch` lê o arquivo do logo a cada
# execução, não guarda nada, e não há painel para reciclar. Trocar o conteúdo do
# arquivo é o recurso inteiro.
#
#   espelho (padrão) o terminal mostra o mascote que o dock NÃO está mostrando.
#   hora    o terminal segue o relógio igual ao dock — os dois iguais.
#   fixo `FASTFETCH_LOGO_GATO` vence sempre — o comportamento.
#
# --- O MODO `espelho`, E POR QUE ELE É UMA REGRA E NÃO QUATRO VALORES --------
FASTFETCH_LOGO_MODO="${FASTFETCH_LOGO_MODO:-espelho}"
FASTFETCH_LOGO_DIA="${FASTFETCH_LOGO_DIA:-${LOGO_DIA:-mimir}}"
FASTFETCH_LOGO_NOITE="${FASTFETCH_LOGO_NOITE:-${LOGO_NOITE:-coquinha}}"

# --- A FRONTEIRA MUDOU DE LADO, E ISSO É DECISÃO CONSCIENTE -------------------
# O cabeçalho explicava: o arquivo é symlink para `~/.config/zsh/fastfetch/`,
# território do Ritual da Aurora, recusado pela TRAVA 1 do `lib/comum.sh`, e com
# auto-commit a cada 10 min no repo PRIVADO dela.
FASTFETCH_LOGO_CONF="${FASTFETCH_LOGO_CONF:-sim}"

# --- O DIRETÓRIO PASSOU A SER NOSSO ------------------------
# As quatro guardas acima existiam porque o `~/.config/fastfetch` era SYMLINK
# para o repositório de shell de uma casa (o Spellbook, com auto-commit a cada
# 10 min): cada chave que este script gravava — `logo.source`, `logo.type` e os
# dois números do `padding`, mais o título — virava commit no repositório de
# outra pessoa.

# LARGURA EM COLUNAS. 40 não é chute: é a largura do logo `pop` que este
# substitui (medido — o bloco de informação continua começando na MESMA coluna,
# então nada do texto dela se desloca). Mexer aqui é seguro.
FASTFETCH_LOGO_COLUNAS="${FASTFETCH_LOGO_COLUNAS:-40}"

# ALTURA EM LINHAS — nova, e ela desmente o que este arquivo dizia antes ("a
# altura não se configura").
#
# Vazio (o padrão) continua sendo o comportamento de sempre: a altura sai de
# `colunas / FASTFETCH_LOGO_CELULA`, e o mascote sai redondo.
#
# Com número, ela manda ATÉ 12% fora da proporção.
FASTFETCH_LOGO_LINHAS="${FASTFETCH_LOGO_LINHAS:-}"

# É CONSTANTE de propósito: medir isto em tempo de execução tornaria o arquivo
# diferente conforme a janela, e o `conferir` (que regera e compara) acusaria
# divergência eterna.
FASTFETCH_LOGO_CELULA="${FASTFETCH_LOGO_CELULA:-2.556}"

# AS DUAS MEDIDAS DO ESPAÇO EM VOLTA DO MASCOTE, que estavam
# cravadas no `config.jsonc` dela e só se mudavam abrindo o arquivo:
#   QUEBRAS  linhas em branco antes do desenho  (`padding.top`)
#   RECUO    colunas entre o desenho e o texto  (`padding.right`, no tabular)
FASTFETCH_LOGO_QUEBRAS="${FASTFETCH_LOGO_QUEBRAS:-auto}"
FASTFETCH_LOGO_RECUO="${FASTFETCH_LOGO_RECUO:-3}"

# O TÍTULO DO BLOCO. Vazio = o fastfetch decide. Ver `meow.conf.exemplo`.
FASTFETCH_TITULO="${FASTFETCH_TITULO:-}"

# ONDE CADA LINHA DE INFORMAÇÃO COMEÇA: `tabular` (o único que o fastfetch sabe
# fazer) ou `contorno` (o texto abraça a silhueta do mascote). O `contorno` é
# composto por fora — ver `_ffl_alinhamento` e `scripts/fastfetch_alinhar.py`.
FASTFETCH_LOGO_ALINHAR="${FASTFETCH_LOGO_ALINHAR:-tabular}"

# Resolução em que o SVG é rasterizado antes de encolher. Alto de propósito: a
# redução por Lanczos a partir de 2048 px é o que preserva o traço do focinho.
FFL_RASTER=2048

FFL_BASE="$HOME/.local/share/meowsystem/fastfetch"

# --- QUEM É O MASCOTE DA VEZ, E ONDE ELE MORA ----------------------------------
# No modo `hora` a janela vem do `lib/noite.sh` — a MESMA que decide o mascote do
# dock. Duas noites nesta máquina é o que aquele arquivo existe para impedir.

# O mascote que está NO BOTÃO DO DOCK agora, pelo arquivo — ou vazio se não der
# para dizer.
_ffl_gato_do_dock() {
  local nome
  [ -x "$MEOW_RAIZ/scripts/logo.sh" ] || return 1
  nome="$(MEOW_DRY_RUN=1 NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-}" \
            "$MEOW_RAIZ/scripts/logo.sh" no-dock 2>/dev/null)" || return 1
  printf '%s\n' "$nome"
}

# O SEGUINTE no acervo, em círculo. Com dois mascotes, é "o outro".
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
    # Com o dock no `LOGO_DIA` ou no `LOGO_NOITE`, o terminal mostra o outro
    # mascote do par: à noite o do dia, de dia o da noite.
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
      # CAIR PARA A FASE, e não para o primeiro do acervo. Isto acontece na
      # PRIMEIRA instalação (o botão do dock ainda não existe) e num acervo de
      # um mascote só.
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

# O config.jsonc DELA. Só é LIDO — nunca aberto para escrita, em nenhum caminho
# deste arquivo.
FFL_CONF_DELA="$HOME/.config/fastfetch/config.jsonc"
FFL_CONF_DIR="$(dirname "$FFL_CONF_DELA")"

# 0 = nada a fazer (já é diretório, não existe, ou a chave desliga) · 1 = assumi
# (ou, no seco, assumiria) · 2 = não deu, e nada foi trocado.
#
# O diretório novo é montado INTEIRO ao lado (temporário no mesmo pai, que é o
# mesmo sistema de arquivos) antes de o link sair.
_ffl_assumir_diretorio() {
  local para alvo novo bkp
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
    # O nome do conf é de outro pack: vale o mascote de fábrica do pack no ar.
    nome="$(python3 "$MEOW_RAIZ/scripts/pack.py" mascote-padrao "$(meow_pack_dir)" "${FFL_FASE:-dia}" 2>/dev/null)"
    if [ -n "$nome" ] && [ -f "$dir/$nome.svg" ]; then printf '%s' "$dir/$nome.svg"; return; fi
  fi
  printf '%s' "$dir/$FASTFETCH_LOGO_GATO.svg"
}

# A chave vence; vazia, a proporção da célula decide.
#
# TODA A ALTURA PASSA POR AQUI, e isso é o que faz o carimbo continuar honesto:
# ele guarda `<mascote> <colunas> <linhas>`, e as linhas saem desta função.
_ffl_linhas_da_proporcao() {
  awk -v c="$FASTFETCH_LOGO_COLUNAS" -v r="$FASTFETCH_LOGO_CELULA" \
      'BEGIN { n = int(c / r + 0.5); if (n < 1) n = 1; print n }'
}

# A ALTURA PEDIDA: a chave, quando ela diz um número; vazia, a proporção.
_ffl_linhas_pedida() {
  case "$FASTFETCH_LOGO_LINHAS" in
    ''|*[!0-9]*) _ffl_linhas_da_proporcao ;;
    *) [ "$FASTFETCH_LOGO_LINHAS" -ge 1 ] 2>/dev/null \
         && printf '%s' "$FASTFETCH_LOGO_LINHAS" || printf '1' ;;
  esac
}

# O QUE ELA ERA: a chave mandava sempre, e o `aplicar` AVISAVA quando o
# resultado passava de 12% fora da proporção da célula.
#
# O QUE ELA É: acima do limite a altura é a da PROPORÇÃO, e o `aplicar` diz o
# que ajustou e por quê.
#
# Abaixo dele, a chave manda e nada muda — um mascote levemente oval por escolha
# dela continua sendo escolha.
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

# Quanto UMA altura se afasta da proporção da célula, em por cento.
#
# As duas chamando uma à outra seria recursão infinita — e a pergunta certa é
# sobre a altura PEDIDA, não sobre a que já foi aparada.
_ffl_desvio_de() {
  awk -v c="$FASTFETCH_LOGO_COLUNAS" -v r="$FASTFETCH_LOGO_CELULA" -v l="$1" \
      'BEGIN { ideal = c / r; if (ideal <= 0) { print 0; exit }
               d = (l - ideal) / ideal * 100; if (d < 0) d = -d; printf "%d", d + 0.5 }'
}

# O desvio da altura PEDIDA — é o número que a frase do `aplicar` cita.
_ffl_desvio() { _ffl_desvio_de "$(_ffl_linhas_pedida)"; }

# Ele era montado por `printf` em três pontos deste arquivo, e cada campo novo
# tinha de ser lembrado nos três — a receita para o `conferir` dizer "conforme"
# sobre um desenho que mudou.
#
# Os campos são TUDO O QUE O GERADOR CONSOME: trocar qualquer um deles tem de
# regerar o `.ansi`.
_ffl_carimbo_texto() {
  printf '%s %s %s %s' "$(basename "${FASTFETCH_LOGO_GATO%.svg}")" \
    "$FASTFETCH_LOGO_COLUNAS" "$(_ffl_linhas)" "$(_ffl_blocos)"
}

# O alinhamento pedido, com o desconhecido caindo no que sempre valeu.
_ffl_alinhamento() {
  case "$FASTFETCH_LOGO_ALINHAR" in
    contorno|degraus|crescente|reto) printf '%s' "$FASTFETCH_LOGO_ALINHAR" ;;
    *)                               printf 'tabular' ;;
  esac
}

# O `meow-fetch` precisa estar no cano? Só quando o alinhamento não é o do
# fastfetch. O título não entra nesta conta: ele é escrito no `config.jsonc` e
# vale nos dois caminhos.
_ffl_quer_meow_fetch() {
  [ "$(_ffl_alinhamento)" != "tabular" ]
}

# QUANTAS LINHAS O BLOCO DE INFORMAÇÃO OCUPA, medido rodando o fastfetch sem
# logo.
#
# O `--pipe false` importa: com o cano detectado o fastfetch some com as cores E
# com algumas linhas, e a conta sairia curta.
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

# O `padding.top` que o config.jsonc deve levar.
_ffl_quebras() {
  case "$FASTFETCH_LOGO_QUEBRAS" in
    ''|auto)
      awk -v g="$(_ffl_linhas)" -v t="$(_ffl_linhas_do_texto)" \
          'BEGIN { n = int((t - g) / 2); if (n < 0) n = 0; print n }' ;;
    *[!0-9]*) printf '6' ;;
    *) printf '%s' "$FASTFETCH_LOGO_QUEBRAS" ;;
  esac
}

# --- QUAL BLOCO A FONTE DELA SABE DESENHAR -----------------------------------
# As duas perguntas têm a mesma resposta, e ela é medível.
#
# O TETO DE DETALHE DE UM DESENHO FEITO DE LETRAS é quantos subpixels cabem numa
# célula, e isso depende do que a FONTE tem:
#
#   half   `▀▄`        1x2 por célula   qualquer fonte
#   quad   `▘▝▖▗▚▞…`   2x2              qualquer fonte monoespaçada séria
#   sext   `🬀🬁🬂…`      2x3              Symbols for Legacy Computing (Unicode 13)
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
  # Um glifo ausente é desenhado como NADA (ou como .notdef vazio) — a média de
  # pixel do rótulo é 0. É o mesmo teste que reprovou a fonte dela hoje, e ele
  # não precisa de fontTools, que não está instalado nesta máquina.
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

# --- o conversor -------------------------------------------------------------
# DETERMINÍSTICO, que é o que torna o `conferir` possível: gera de novo num
# temporário e compara com o que está no disco.
_ffl_gerar() {
  local destino="$1" svg="$2" colunas="$3" linhas="$4"
  python3 -I - "$svg" "$colunas" "$linhas" "$destino" "$FFL_RASTER" "$(_ffl_blocos)" <<'PY'
import subprocess, sys

svg, colunas, linhas, destino, raster, blocos = (
    sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], int(sys.argv[5]),
    sys.argv[6])
# Quantos subpixels cabem na célula, decidido lá fora por MEDIÇÃO da fonte.
SX, SY = (2, 3) if blocos == "sext" else (2, 2)

# 1. SVG -> PNG grande. O rsvg-convert é o mesmo renderizador que o delegado
#    `svg =>` do ImageMagick chama; usá-lo direto tira a dúvida de qual dos dois
#    (MSVG interno ou librsvg) atendeu.
# O `-a` NÃO É ENFEITE — 01/09/2026. Sem ele, `-w R -h R` estica o desenho para
# encher o quadrado, e o viewBox dos mascotes deixou de ser quadrado no dia em que
# ela aumentou o mascote dentro do quadro (1030x1079 no Mimir). Medido: o mascote saía
# 254 px de largura por 255 de altura onde o certo é 243x255 — 4,5% mais gordo,
# um círculo virando elipse. Com `-a` a proporção é preservada e o que sobra do
# quadrado fica transparente, que é exatamente o que a grade de blocos ignora.
png = subprocess.run(["rsvg-convert", "-a", "-w", str(raster), "-h", str(raster), svg],
                     check=True, capture_output=True).stdout

# 2. PNG -> grade de pixels em TEXTO. Sem PIL: o `txt:` do ImageMagick é ASCII,
#    uma linha por pixel, com `#RRGGBBAA` no meio. O `!` do -resize é
#    deliberado: a imagem é quadrada e a grade não é (2x2 pixels por célula, e a
#    célula não é 1:1), então a proporção TEM de ser forçada aqui — é isso que
#    faz o disco sair redondo na tela dela.
#
# QUATRO PIXELS POR CÉLULA, E NÃO DOIS — 01/09/2026, pedido dela: "não
# conseguimos melhorar a resolução dos meus mascotes no terminal?". A versão
# anterior amostrava `colunas x (linhas*2)` = 40x32 e desenhava com `▀`/`▄`
# (meio bloco): um subpixel de 8x8 px na tela dela, que é o serrilhado grosso
# que ela apontou. Com os QUADRANTES do bloco Unicode (▘▝▖▗▚▞▌▐▛▜▙▟) cabem
# QUATRO subpixels por célula, e a amostragem passa a 80x32 — o dobro de
# detalhe horizontal, na MESMA área da tela e sem mexer no layout dela.
#
# POR QUE NÃO SEXTANTES (2x3, que dariam 80x48): MEDIDO na fonte do terminal
# dela. `JetBrainsMonoNerdFontMono-Regular.ttf` não tem os glifos de
# `Symbols for Legacy Computing` (U+1FB00–1FB3B) — renderizados com ela, saem
# em branco (média de pixel 0.000, contra 0.234 do `▘` e 0.936 do `█`). Um
# mascote desenhado com caractere ausente vira uma parede de retângulos vazios.
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

# LIMIAR DE ALFA: 128. A borda do disco é antialiasada, e sem um corte cada
# pixel de meia transparência viraria cor cheia — o disco ganharia uma auréola
# de um pixel na cor errada sobre o fundo do terminal.
LIMIAR = 128
VAZIO = (0, 0, 0, 0)

# OS GLIFOS, INDEXADOS PELA MÁSCARA DE SUBPIXELS
#   O bit `i` é o subpixel `i` na ordem de leitura: esquerda->direita,
#   cima->baixo. Em 2x2, bit0 = superior-esquerdo … bit3 = inferior-direito.
#   Em 2x3 a mesma regra dá seis bits, e é exatamente a convenção do bloco
#   Unicode `Symbols for Legacy Computing`, o que faz a fórmula abaixo ser uma
#   soma e não uma tabela de 60 linhas.
QUAD = " ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█"


def glifo(m, n):
    """O caractere que acende os subpixels de `m`, num mosaico de `n` deles."""
    if n == 4:
        return QUAD[m]
    # 2x3. Os quatro casos fora do bloco 1FB00 são os que a Unicode já tinha:
    # vazio, cheio, e as duas colunas inteiras (que são os meios-blocos).
    if m == 0:
        return " "
    if m == 63:
        return "█"
    if m == 21:      # 0b010101 — coluna esquerda inteira
        return "▌"
    if m == 42:      # 0b101010 — coluna direita inteira
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
    # Cada linha recomeça do zero: sem isso o estado vazaria de uma linha para a
    # outra e um `.ansi` cortado pela metade desenharia lixo colorido.
    fg = bg = "reset"
    linha = ["\x1b[0m"]
    for x in range(colunas):
        celula = [px.get((x * SX + dx, ly * SY + dy), VAZIO)
                  for dy in range(SY) for dx in range(SX)]
        cheios = [i for i, c in enumerate(celula) if c[3] >= LIMIAR]

        if not cheios:
            # Célula vazia: só o FUNDO importa. Não mexer no foreground poupa
            # uma sequência por pixel transparente — e são muitos.
            novo_fg, novo_bg, ch = fg, None, " "
        elif len(cheios) < N:
            # BORDA DO DISCO: o que é transparente TEM de ficar no fundo do
            # terminal, senão o papel de parede dela some atrás de um retângulo.
            # Então aqui a partição não é escolhida — ela é imposta pelo alfa.
            m = sum(1 << i for i in cheios)
            novo_fg, novo_bg, ch = _media([celula[i] for i in cheios]), None, glifo(m, N)
        else:
            # MIOLO OPACO: aí sim há liberdade, e a pergunta é qual partição em
            # dois grupos descreve melhor os subpixels. Testam-se todas (a
            # sólida inclusa, que vence quando são quase iguais) e fica a de
            # menor erro quadrático. Empate resolve pelo menor índice, porque
            # este arquivo PRECISA ser determinístico: o `conferir` gera de novo
            # e compara byte a byte.
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

# --- escrita: temporário no diretório de DESTINO (TRAVA 2) -------------------
# O `meow_escrever` não serve aqui: ele recebe o conteúdo como argumento, e este
# conteúdo é um arquivo de 20 KB cheio de ESC — passá-lo por `$( )` e por
# `printf '%s'` é pedir para o shell comer byte.

# --- A GUARDA BARATA, E POR QUE ELA PRECISOU EXISTIR -------------------------
# É o preço do determinismo, e estava certo enquanto isto rodava uma vez por
# `install.sh`.
#
# AS TRÊS PORTAS QUE ATRAVESSAM A GUARDA — sem elas isto vira cache que mente:
#   1. o `.ansi` não existe (alguém apagou, ou é a primeira vez);
#   2. o carimbo não bate (trocou de mascote, de largura ou de proporção);
#   3. o SVG é MAIS NOVO que o `.ansi` (ela redesenhou o mascote no acervo).
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
    # O CARIMBO É REESCRITO MESMO SEM MUDANÇA, e essa linha é o que faz a guarda
    # barata nascer valendo numa máquina que já tinha o `.ansi` no lugar.
    printf '%s\n' "$(_ffl_carimbo_texto)" > "$(_ffl_carimbo)" 2>/dev/null || true
    return "$MEOW_OK"                        # regra 5: idêntico, não reescreve
  fi
  chmod 644 "$tmp"
  meow_guardar_antes "$FFL_ALVO"; meow_guardar_antes "$(_ffl_carimbo)"
  mv -f "$tmp" "$FFL_ALVO" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  printf '%s\n' "$(_ffl_carimbo_texto)" > "$(_ffl_carimbo)" 2>/dev/null || true
  meow_manifesto_registrar "$FFL_ALVO"
  _ffl_varrer_orfaos
  return "$MEOW_DIVERGENTE"
}

# --- O QUE SOBROU DO MODO ANTERIOR SAI DO DISCO ------------------------------
# Regra 3 do contrato: reescrever o estado inteiro, nunca acrescentar.
#
# SÓ SE APAGA `.ansi` DENTRO DE `$FFL_BASE`, que é diretório NOSSO, criado por
# este script e por mais ninguém — e nunca o alvo da vez.
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

# --- leitura do config.jsonc DELA -------------------------------------------
# JSONC não é JSON: tem comentários. E um `sed 's|//.*||'` ingênuo QUEBRA este
# arquivo em particular, porque a primeira linha dele é
# `"$schema": "https://github.com/..."` — o `//` está DENTRO de uma string. Daí a
# tira-comentários abaixo respeitar aspas e escapes.
#
# Devolve, em três linhas: `type`, `source` (com `~` expandido) e a contagem de
# módulos com `key` própria.
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
# As duas medidas do espaço em volta do mascote entraram na leitura em 06/09/2026:
# sem elas, mudar só `FASTFETCH_LOGO_QUEBRAS` no conf não disparava escrita
# nenhuma — a fronteira olhava para `source` e `type`, via que estavam certos, e
# dizia "já aponta para o nosso .ansi" sobre um arquivo com o recuo velho.
print(pad.get("top", ""))
print(pad.get("right", ""))
PY
}

# --- a escrita cirúrgica no config.jsonc dela --------------------------------
# Não reserializa o JSON: um `json.dump` mataria os comentários (é JSONC), a
# ordem das chaves e a indentação dela — e o arquivo vive num repo com
# auto-commit, então o diff de 10 minutos depois seria o arquivo inteiro
# reescrito por um enfeite.
#
# Gravar o caminho absoluto funcionaria igual, mas quebraria o arquivo dela no
# dia em que o home mudasse de nome — e o resto do arquivo usa `~`.
_ffl_escrever_conf() {
  local alvo_rel="~/.local/share/meowsystem/fastfetch/$(basename "$FFL_ALVO")"
  local bkp="$MEOW_ESTADO/backups/$MEOW_CARIMBO-vizinho"

  if meow_seco; then
    meow_muda "mudaria logo.source de $FFL_CONF_DELA para \"$alvo_rel\""
    return "$MEOW_DIVERGENTE"
  fi

  # GUARDA 2: backup antes de encostar. Falhar aqui ABORTA a escrita — sem rede
  # de segurança não se mexe no arquivo de outro projeto, ponto.
  mkdir -p "$bkp" 2>/dev/null || { meow_erro "não consegui criar $bkp"; return "$MEOW_ERRO"; }
  cp -a "$FFL_CONF_DELA" "$bkp/config.jsonc" 2>/dev/null \
    || { meow_erro "não consegui guardar backup de $FFL_CONF_DELA — não vou escrever"; return "$MEOW_ERRO"; }

  # A ESCRITA MORA NO `fastfetch_conf.py`, E ISSO NÃO É ORGANIZAÇÃO: é a mesma
  # lição que já custou o arquivo dela uma vez.
  #
  # Duas varreduras de ESCRITA de JSONC em duas linguagens divergiriam de novo.
  #
  # 0 = nada a mudar · 1 = mudou · 2 = não deu.
  python3 "$MEOW_RAIZ/scripts/fastfetch_conf.py" escrever-logo \
    "$FFL_CONF_DELA" "$alvo_rel" "$(_ffl_quebras)" "$FASTFETCH_LOGO_RECUO"
  case "$?" in
    0) meow_ok "o seu config.jsonc já estava como o meow.conf pede"
       return "$MEOW_OK" ;;
    2) meow_erro "não consegui escrever em $FFL_CONF_DELA"
       meow_info  "  backup intacto: $bkp/config.jsonc"
       return "$MEOW_ERRO" ;;
  esac

  # GUARDA 3: em voz alta, sempre. Tocar arquivo de vizinho sem dizer é
  # exatamente o que a TRAVA 1 existe para impedir.
  meow_aviso "escrevi no config.jsonc do fastfetch (logo.source -> $alvo_rel)"
  meow_info  "  backup: $bkp/config.jsonc"
  meow_info  "  desligue com FASTFETCH_LOGO_CONF=\"nao\" no ~/.config/meow/meow.conf"
  meow_registrar "fastfetch_logo.sh escreveu logo.source=$alvo_rel em $FFL_CONF_DELA"
  return "$MEOW_DIVERGENTE"
}

# 0 = o config.jsonc já aponta para o nosso .ansi · 1 = não aponta · 2 = não deu
# para ler. Imprime sempre uma linha dizendo o que viu.
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
  # O `$(_ffl_quebras)` roda um `fastfetch` inteiro quando as quebras estão em
  # `auto`, e a substituição de comando acontece na expansão do argumento —
  # antes de o `meow_info` poder calar pelo `LOG_NIVEL=silencioso`.
  meow_quieto || meow_info "  padding: topo=${pad_topo:-<sem>} recuo=${pad_recuo:-<sem>} (o conf pede $(_ffl_quebras) e $FASTFETCH_LOGO_RECUO)"
  meow_info "  módulos com chave própria (as em português): $nchaves"

  if [ "$fonte" != "$FFL_ALVO" ]; then
    return 1
  fi
  if [ "$tipo" != "file-raw" ]; then
    meow_aviso "aponta para $(basename "$FFL_ALVO"), mas com logo.type=\"$tipo\" — o certo é \"file-raw\""
    return 1
  fi
  # No `contorno` quem desenha o espaço é o `meow-fetch`, com as mesmas duas
  # chaves passadas na linha de comando — o `padding` do config.jsonc fica sem
  # efeito, e cobrá-lo daria uma divergência eterna sobre um número que ninguém
  # lê.
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

# Aqui está o resto: onde o compositor entra na vida dela sem que o MeowSystem
# vire dono do terminal dos outros.
#
# A PEÇA É UM LANÇADOR EM ~/.local/bin, COMO O `meow-painel` Pelo mesmo motivo
# daquele: o repositório mora num NVMe separado, e o dia em que o Ápate não
# montar não pode ser o dia em que o terminal dela abre com um erro de Python.
#
# O `meow-fetch` lê o `FASTFETCH_LOGO_ALINHAR` a cada chamada.
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

# 0 = já estava certo · 1 = escrevi (ou escreveria) · 2 = erro
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

# --- a fronteira do lado do zsh: SAIU -------------------
# AQUI MORAVA A ESCRITA NA LINHA DO FASTFETCH DO `env.zsh` DO SPELLBOOK: o
# `_ffl_zsh_estado` lia qual das duas chamadas estava lá, o `_ffl_zsh_fronteira`
# trocava `fastfetch --pipe false` por `meow-fetch --pipe false` (com backup e
# em voz alta), e o `cmd_reverter` destrocava na desinstalação.
#
# A REGRA TIROU ISTO SEM TERCEIRA VIA: o que o MeowSystem lia ou escrevia no
# Spellbook, ou migra para cá, ou sai daqui.

# --- o formato do título, no config.jsonc dela -------------------------------
# ELE TEM DE MORAR LÁ, e a alternativa foi tentada e medida: o fastfetch 2.61.0
# recusa `--title-format` com "Support of module options has been removed.
#
# A escrita é do mesmo tipo cirúrgico do `logo.source`: acha a entrada `title`
# dentro do array `modules` e troca só ela.
#
#   "title"                                    a forma curta, que é a dela
#   { "type": "title", "format": "…" }         a forma longa, com o formato

# 0 = já está como o conf pede · 1 = precisa mudar · 2 = não deu para ler
_ffl_titulo_confere() {
  local atual rc
  [ -f "$FFL_CONF_DELA" ] || return 2
  # O `2` PRECISA CHEGAR INTEIRO até aqui — "não há módulo title neste arquivo"
  # e "o título é outro" são respostas diferentes, e só a segunda autoriza
  # escrever.
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
  # OS NÚMEROS SAEM DO CONF, e não são mais constantes.
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

  # A altura virou chave dela, e o conversor estica com `-resize LxA!` sem
  # perguntar: fora da proporção da célula o círculo vira elipse.
  _dv="$(_ffl_desvio)"
  if [ "${_dv:-0}" -gt "$FASTFETCH_LOGO_DESVIO_TETO" ] 2>/dev/null; then
    # `meow_aviso` E NÃO `meow_muda`, e a diferença não é de gosto: o `~~` do
    # `meow_muda` é o que o painel lê para dizer "mexeu e aplicou" (app.js, o
    # `TRABALHO.mudou`), e aparar a altura não escreve byte nenhum a mais — o
    # desenho já nasce na medida certa.
    meow_aviso "altura aparada: $(_ffl_linhas_pedida) linhas sairiam ${_dv}% fora da proporção da célula (esticado)"
    meow_info  "  usei $(_ffl_linhas) linhas para $FASTFETCH_LOGO_COLUNAS colunas, que é a proporção desta fonte"
    meow_info  "  guardei o seu $(_ffl_linhas_pedida): ele volta a valer se você mudar as colunas, ou baixar de ${FASTFETCH_LOGO_DESVIO_TETO}% de desvio"
  fi
  unset _dv

  # Ele é instalado sempre, e não só quando o alinhamento pede: ele mesmo lê a
  # chave e vira `exec fastfetch` no tabular sem título próprio, e é isso que
  # permite trocar de alinhamento sem tocar em arquivo de vizinho de novo.
  _ffl_instalar_meow_fetch; _rcm=$?
  case "$_rcm" in
    1) rc="$MEOW_DIVERGENTE"; meow_muda "meow-fetch em $(_ffl_meow_fetch)" ;;
    2) meow_erro "não consegui escrever o $(_ffl_meow_fetch)" ;;
  esac
  unset _rcm

  # Até aqui esta passagem trocava a linha do fastfetch no `env.zsh` do
  # Spellbook e devolvia 4 quando não a achava.
  if _ffl_quer_meow_fetch; then
    meow_info "o $(_ffl_alinhamento) aparece quando o seu shell chama meow-fetch no lugar de fastfetch"
    meow_info "  o MeowSystem não lê nem escreve arquivo de shell — essa linha é sua"
  fi

  # O DIRETÓRIO ANTES DAS CHAVES: o título e o `logo.source` logo abaixo são
  # escritos dentro dele, e escritos através do link iriam parar no
  # repositório de outra pessoa.
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

  # A FRONTEIRA SE CONSERTA SOZINHA, quando ela deixou. Ver o bloco
  # `FASTFETCH_LOGO_CONF` lá em cima: as quatro guardas, o porquê da mudança e
  # a medição que descarta ping-pong com o self-heal.
  if [ "$rcf" = "1" ] && [ "$FASTFETCH_LOGO_CONF" = "sim" ] && [ -f "$FFL_CONF_DELA" ]; then
    local rce; _ffl_escrever_conf; rce=$?
    if [ "$rce" = "$MEOW_DIVERGENTE" ]; then
      rc="$MEOW_DIVERGENTE"
      # Reconferir em vez de assumir: se a troca não pegou (um `logo` aninhado
      # inesperado, um arquivo que mudou entre a leitura e a escrita), o patch
      # impresso abaixo continua sendo a saída honesta.
      meow_seco || { _ffl_fronteira >/dev/null 2>&1; rcf=$?; }
    elif [ "$rce" = "$MEOW_ERRO" ]; then
      meow_erro "não consegui escrever no config.jsonc — deixo o patch abaixo"
    fi
    # `rce` = 0 é "não havia o que trocar": a fronteira acusa divergência em
    # algo que esta escrita não cobre (uma chave `padding` que o arquivo dela
    # não tem, por exemplo).
  fi

  if [ "$rcf" = "1" ]; then
    printf '\n'
    meow_aviso "o fastfetch ainda NÃO vai mostrar o mascote: falta uma troca de"
    meow_aviso "  duas chaves no config.jsonc do fastfetch, que é seu e não nosso."
    printf '\n'
    _ffl_patch_texto
    printf '\n'
    meow_registrar "fastfetch_logo.sh aplicar rc=$rc fronteira=pendente"
    # Devolver 4 aqui esconderia do resumo do `install.sh` (e da notificação do
    # doctor) um arquivo que ACABOU de nascer — mentira de relatório na direção
    # contrária à do `midia_build`.
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
  # O symlink é divergência NOSSA (1), e não da fronteira (4): quem o conserta
  # é o `aplicar` daqui, sem mão de ninguém.
  if [ -L "$FFL_CONF_DIR" ] && [ "$FASTFETCH_LOGO_CONF" = "sim" ]; then
    meow_muda "$FFL_CONF_DIR é symlink para $(readlink "$FFL_CONF_DIR") — viraria um diretório do MeowSystem, com o mesmo conteúdo"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "logo ANSI conforme ($FASTFETCH_LOGO_COLUNAS x $(_ffl_linhas) células, $(_ffl_blocos))"
  meow_info "alinhamento: $(_ffl_alinhamento) · $(_ffl_quebras) linha(s) antes, recuo de $FASTFETCH_LOGO_RECUO"

  # O SECO É OBRIGATÓRIO AQUI, e a linha logo acima já dizia isso para a irmã
  # (`MEOW_SECO=1 _ffl_instalar`).
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
    2) return "$MEOW_OK" ;;   # sem config dela para conferir; o .ansi está certo
    *) meow_pula "o config.jsonc do fastfetch é seu — 'fastfetch_logo.sh patch' mostra o que colar"
       return 4 ;;
  esac
}

# Imprime o arquivo como ele é. Sem `cat -v`, sem tradução: é o teste honesto de
# que os bytes que o fastfetch vai ler desenham a Coquinha.
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
  # Só apaga o diretório se ele ficar vazio, e só o NOSSO: o
  # `~/.local/share/meowsystem` pode hospedar outra coisa amanhã.
  rmdir "$FFL_BASE" 2>/dev/null
  meow_muda "logo ANSI removido — o fastfetch volta ao logo padrão dele"
  meow_aviso "o seu config.jsonc continua como está: se ele aponta para este"
  meow_aviso "  arquivo, o fastfetch cai no logo da distribuição (não quebra nada)"
  meow_registrar "fastfetch_logo.sh remover"
  return "$MEOW_DIVERGENTE"
}

# --- desfazer a fronteira, na hora de desinstalar ----------------------------
# Ele devolvia `fastfetch` na linha do `env.zsh` do Spellbook antes de o
# desinstalador apagar o `meow-fetch`, para o terminal não abrir com `command
# not found`.
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

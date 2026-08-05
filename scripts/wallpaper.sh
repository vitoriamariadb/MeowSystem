#!/usr/bin/env bash
# wallpaper.sh — o carrossel de papéis de parede, na rotação NATIVA do COSMIC.
#
# POR QUE NATIVA, E NÃO UM TIMER NOSSO
#   Medido em 2026-08-04: com `source: Path(<diretório>)` e `rotation_frequency: 60`,
#   o `cosmic-bg` abriu três arquivos distintos em intervalos de 60,04s. A rotação
#   sempre funcionou — o motivo de não girar nesta máquina é que o `source` aponta
#   para um ARQUIVO ÚNICO. Em teste de controle com um arquivo só, o timer disparava
#   e redesenhava a mesma imagem. Ligar o carrossel é trocar UM campo.
#
#   Um timer `systemd --user` faria o mesmo com um processo a mais, uma unit a mais
#   e um modo de falha a mais. Fica documentado como plano B, não implementado.
#
# AS TRÊS ARMADILHAS MEDIDAS
#   1. A lista de imagens é FOTOGRAFADA quando a configuração é carregada. Um arquivo
#      novo largado no diretório NÃO entra na rotação, apesar de o log dizer
#      "watching source" — passou cinco rotações inteiras sem ser aberto. Por isso
#      `adicionar` reescreve a configuração no fim: é o que força a releitura.
#   2. Escrever na configuração NÃO AVANÇA, REINICIA: revarre o diretório, volta para
#      a PRIMEIRA imagem alfanumérica e zera o timer. Logo não existe "próximo" barato.
#   3. Escrever conteúdo IDÊNTICO é no-op total — nem releitura acontece. Quando se
#      QUER forçar a releitura, é preciso que o conteúdo mude de fato.
#
# NÃO EXISTE GATILHO DE "PRÓXIMO"
#   O `cosmic-bg` não fala D-Bus: não tem nome no barramento, não tem conexão, e o
#   binário não contém nenhuma string de D-Bus (medido). Os fds dele são dois sockets
#   Wayland e um inotify. Então `proximo` só é possível reiniciando a rotação — o que
#   leva de volta à primeira imagem, não à seguinte. Este script não finge o contrário.
#
# AS QUATRO PASTAS
#   ativos/     o que entra na rotação  <- é ela que vira `source`
#   favoritos/  guardadas por escolha dela; entram na rotação por cópia
#   banidos/    saíram por decisão dela. MOVIDAS, nunca apagadas.
#   originais/  a foto antes de qualquer recolorização, para poder refazer
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

BASE="${WALLPAPER_BASE:-$HOME/.local/share/backgrounds/meowsystem}"
ATIVOS="$BASE/ativos"
BG="$HOME/.config/cosmic/com.system76.CosmicBackground/v1"
ORDEM="${WALLPAPER_ORDEM:-aleatoria}"
INTERVALO="${WALLPAPER_INTERVALO:-5m}"

# "30s" / "5m" / "2h" -> segundos. O COSMIC quer segundos e nada mais.
segundos_de() {
  local v="$1" n u
  n="${v%[smh]}"; u="${v#$n}"
  case "$n" in ''|*[!0-9]*) echo 300; return ;; esac
  case "$u" in
    s) echo "$n" ;;
    m) echo $((n * 60)) ;;
    h) echo $((n * 3600)) ;;
    *) echo "$n" ;;   # sem sufixo já é segundos
  esac
}

# Só existem dois valores no binário: Alphanumeric e Random. Não há ordenação por
# data nem manual — se a ordem importar, prefixe os arquivos com 01-, 02-.
metodo_de() {
  case "${1:-aleatoria}" in
    alfabetica|alphanumeric) echo Alphanumeric ;;
    *) echo Random ;;
  esac
}

config_desejada() {
  local freq metodo
  freq="$(segundos_de "$INTERVALO")"
  metodo="$(metodo_de "$ORDEM")"
  # `filter_by_theme: false` de propósito: com `true` o COSMIC filtra as imagens
  # pelo claro/escuro do tema e pode acabar sem nenhuma candidata no diretório —
  # tela preta sem explicação. O carrossel é dela, não do tema.
  # `filter_method` e `scaling_mode` são as escolhas dela e são preservadas.
  cat <<FIM
(
    output: "all",
    source: Path("$ATIVOS"),
    filter_by_theme: false,
    rotation_frequency: $freq,
    filter_method: Lanczos,
    scaling_mode: Fit((0.0, 0.0, 0.0)),
    sampling_method: $metodo,
)
FIM
}

criar_pastas() {
  local p
  for p in ativos favoritos banidos originais; do
    [ -d "$BASE/$p" ] && continue
    meow_seco && { meow_muda "criaria $BASE/$p"; continue; }
    mkdir -p "$BASE/$p" || return "$MEOW_ERRO"
  done
  return 0
}

# Semear a partir das imagens que ela JÁ tem. Não baixamos nada da internet sem
# ela pedir: o carrossel tem de funcionar no primeiro `install.sh`, offline.
#
# SÓ NA PRIMEIRA VEZ, e isso não é detalhe. A versão anterior semeava a cada
# `aplicar` — e como `banir` chama `aplicar` no fim (para forçar a releitura da
# lista), banir uma imagem da pasta dela a copiava DE VOLTA no mesmo comando.
# Ela bania, o script dizia "banida", e a imagem continuava lá. Agora a semeadura
# só acontece quando `ativos/` está vazio, ou seja, na primeira instalação:
# depois disso quem manda no conteúdo da pasta é ela.
semear_das_dela() {
  local origem="$HOME/Imagens/Parede_papel"
  [ -d "$origem" ] || return 0
  [ "$(quantas)" -eq 0 ] || return 0
  local n=0
  while IFS= read -r img; do
    local destino="$ATIVOS/$(basename "$img")"
    [ -e "$destino" ] && continue
    meow_seco || cp -n "$img" "$destino" 2>/dev/null || continue
    n=$((n + 1))
  done < <(find "$origem" -maxdepth 1 -type f \
             \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null)
  if [ "$n" -gt 0 ]; then
    if meow_seco; then
      meow_muda "copiaria $n imagem(ns) de ~/Imagens/Parede_papel"
    else
      meow_info "$n imagem(ns) copiadas de ~/Imagens/Parede_papel"
    fi
  fi
  return 0
}

quantas() { find "$ATIVOS" -maxdepth 1 -type f 2>/dev/null | wc -l; }

cmd_aplicar() {
  criar_pastas || { meow_erro "não consegui criar as pastas"; return "$MEOW_ERRO"; }
  semear_das_dela

  local n; n="$(quantas)"
  if [ "$n" -lt 2 ]; then
    meow_aviso "só $n imagem(ns) em $ATIVOS — o carrossel precisa de 2 ou mais"
    meow_info "adicione com: meow wallpaper adicionar <arquivo|pasta>"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local desejada; desejada="$(config_desejada)"
  local mudou=0

  # `all` é o que vale (same-on-all está ligado), mas as saídas por nome existem e
  # o COSMIC lê a que casar. Escrever as três de forma consistente evita um estado
  # em que o monitor certo mostra a imagem errada — e tratar saída desconectada
  # sem erro é de graça, já que só escrevemos os arquivos que já existem.
  local alvo
  for alvo in all output.DP-1 output.HDMI-A-1; do
    [ "$alvo" = "all" ] || [ -f "$BG/$alvo" ] || continue
    local conteudo="$desejada"
    [ "$alvo" = "all" ] || conteudo="${desejada/output: \"all\"/output: \"${alvo#output.}\"}"
    meow_escrever "$BG/$alvo" "$conteudo" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao escrever $alvo"; return "$MEOW_ERRO" ;; esac
  done

  if [ "$mudou" = "0" ]; then
    meow_ok "carrossel já configurado ($n imagens, a cada $INTERVALO, $ORDEM)"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_ok "carrossel ligado: $n imagens, troca a cada $INTERVALO ($ORDEM)"
  return "$MEOW_DIVERGENTE"
}

cmd_estado() {
  local n; n="$(quantas)"
  echo "pasta:     $ATIVOS"
  echo "imagens:   $n"
  echo "intervalo: $INTERVALO ($(segundos_de "$INTERVALO")s)"
  echo "ordem:     $ORDEM ($(metodo_de "$ORDEM"))"
  if [ -f "$BG/all" ]; then
    local fonte; fonte="$(grep -oP 'source: Path\("\K[^"]+' "$BG/all" 2>/dev/null)"
    if [ "$fonte" = "$ATIVOS" ]; then
      echo "estado:    carrossel ATIVO"
    else
      echo "estado:    apontando para outro lugar ($fonte)"
    fi
  fi
  # A imagem exata que está na tela não é observável: o cosmic-bg não fala D-Bus
  # e não grava o índice em lugar nenhum. Dizer "não sei" é melhor que inventar.
  echo "atual:     (o cosmic-bg não expõe qual imagem está em exibição)"
}

# Mover, nunca apagar: uma imagem banida pode ser recuperada de banidos/.
cmd_banir() {
  local img="$1"
  [ -f "$img" ] || { meow_erro "não achei $img"; return "$MEOW_ERRO"; }
  criar_pastas
  local nome; nome="$(basename "$img")"
  # `mv -n` recusa sobrescrever — e uma imagem JÁ banida antes deixaria o arquivo
  # parado em ativos/, com o script dizendo "banida". Se a cópia em banidos/ já
  # existe e é idêntica, o banimento anterior valeu: basta tirar daqui.
  if [ -e "$BASE/banidos/$nome" ] && cmp -s "$img" "$BASE/banidos/$nome"; then
    rm -f "$img"
  else
    mv -f "$img" "$BASE/banidos/" || return "$MEOW_ERRO"
  fi
  meow_ok "banida: $nome — está em banidos/, não foi apagada"
  cmd_aplicar >/dev/null   # força a releitura da lista
  return "$MEOW_DIVERGENTE"
}

cmd_adicionar() {
  local alvo="$1"
  criar_pastas
  local n=0
  if [ -d "$alvo" ]; then
    while IFS= read -r img; do
      cp -n "$img" "$ATIVOS/" 2>/dev/null && n=$((n + 1))
    done < <(find "$alvo" -maxdepth 1 -type f \
               \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \))
  elif [ -f "$alvo" ]; then
    cp -n "$alvo" "$ATIVOS/" && n=1
  else
    meow_erro "não achei $alvo"; return "$MEOW_ERRO"
  fi
  meow_ok "$n imagem(ns) adicionada(s)"
  # Sem reescrever a configuração, a imagem nova NÃO entra na rotação: a lista foi
  # fotografada no carregamento. Este passo não é enfeite.
  cmd_aplicar >/dev/null
  return "$MEOW_DIVERGENTE"
}

# --- semear: a coleção Catppuccin da comunidade ----------------------------
# POR QUE NÃO CLONAR O REPOSITÓRIO
#   `zhichaoh/catppuccin-wallpapers` tem 371 MB e 242 imagens; o
#   `orangci/walls-catppuccin-mocha` tem 795 MB. Baixar tudo para usar uma dúzia
#   é desperdício de banda e de disco. Aqui se lê a árvore do commit PINADO pela
#   API e se baixam só os arquivos escolhidos, por URL crua.
#
# COMMIT PINADO, NUNCA `main`
#   Um upstream que muda sozinho transforma "rodei o instalador" em "rodei num
#   dia em que o repositório estava de um jeito".
#
# AS IMAGENS NÃO ENTRAM NO GIT
#   O repositório guarda esta receita. As fotos ficam só na máquina.
SEMENTE_REPO="${WALLPAPER_SEMENTE_REPO:-zhichaoh/catppuccin-wallpapers}"
SEMENTE_COMMIT="${WALLPAPER_SEMENTE_COMMIT:-1023077979591cdeca76aae94e0359da1707a60e}"
# 0 = TODAS as imagens do repositorio. Um numero baixa so uma amostra, uma de
# cada categoria por rodizio (util para testar sem gastar banda).
SEMENTE_QUANTAS="${WALLPAPER_SEMENTE_QUANTAS:-0}"

cmd_semear() {
  meow_tem curl || { meow_erro "curl não encontrado"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem python3 || { meow_erro "python3 não encontrado"; return "$MEOW_SEM_DEPENDENCIA"; }
  criar_pastas

  local api="https://api.github.com/repos/$SEMENTE_REPO/git/trees/$SEMENTE_COMMIT?recursive=1"
  local lista; lista="$(curl -sS --max-time 30 "$api" 2>/dev/null)" || {
    meow_aviso "não consegui falar com o GitHub — semeadura pulada"
    return "$MEOW_SEM_DEPENDENCIA"
  }

  # Escolhe espalhando pelas categorias, em vez de pegar as N primeiras (que
  # seriam todas da mesma pasta e pareceriam a mesma imagem repetida).
  local escolhidas
  escolhidas="$(printf '%s' "$lista" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if 'tree' not in d:
    sys.exit(1)
imgs = [t['path'] for t in d['tree']
        if t.get('type') == 'blob' and t['path'].lower().endswith(('.png', '.jpg', '.jpeg'))]
por_pasta = {}
for p in imgs:
    por_pasta.setdefault(p.split('/')[0], []).append(p)
# rodízio entre as pastas: uma de cada, depois a segunda de cada, e assim por diante
limite = $SEMENTE_QUANTAS or len(imgs)
saida, i = [], 0
while len(saida) < limite:
    houve = False
    for pasta in sorted(por_pasta):
        if i < len(por_pasta[pasta]):
            saida.append(por_pasta[pasta][i]); houve = True
            if len(saida) >= limite: break
    if not houve: break
    i += 1
print('\n'.join(saida))
")" || { meow_aviso "resposta do GitHub inesperada — semeadura pulada"; return "$MEOW_SEM_DEPENDENCIA"; }

  [ -n "$escolhidas" ] || { meow_aviso "nenhuma imagem encontrada"; return "$MEOW_SEM_DEPENDENCIA"; }

  local n=0 base="https://raw.githubusercontent.com/$SEMENTE_REPO/$SEMENTE_COMMIT"
  while IFS= read -r caminho; do
    [ -n "$caminho" ] || continue
    # Prefixo com a categoria: o nome vira legível e a ordem alfanumérica agrupa.
    local nome="cat-${caminho//\//-}"
    local destino="$ATIVOS/$nome"
    [ -e "$destino" ] && continue
    if meow_seco; then
      meow_muda "baixaria $nome"; n=$((n+1)); continue
    fi
    # Baixa para temporário no MESMO diretório e só então renomeia: uma imagem
    # pela metade entraria na rotação e apareceria cortada na tela dela.
    local tmp; tmp="$(mktemp -p "$ATIVOS" ".meow.XXXXXX")"
    if curl -sSL --max-time 60 -o "$tmp" "$base/$caminho" 2>/dev/null && [ -s "$tmp" ]; then
      mv -f "$tmp" "$destino"; n=$((n+1))
    else
      rm -f "$tmp"
    fi
  done <<< "$escolhidas"

  if [ "$n" -eq 0 ]; then
    meow_ok "coleção Catppuccin já semeada"
    return "$MEOW_OK"
  fi
  meow_ok "$n imagem(ns) da coleção Catppuccin baixadas (${SEMENTE_REPO}@${SEMENTE_COMMIT:0:8})"
  meow_seco || cmd_aplicar >/dev/null   # a lista é fotografada no load: precisa reescrever
  return "$MEOW_DIVERGENTE"
}

case "${1:-aplicar}" in
  aplicar)   cmd_aplicar ;;
  estado)    cmd_estado ;;
  semear)    cmd_semear ;;
  banir)     shift; cmd_banir "${1:-}" ;;
  adicionar) shift; cmd_adicionar "${1:-}" ;;
  *) echo "uso: wallpaper.sh [aplicar|estado|semear|adicionar <alvo>|banir <img>]" >&2; exit 2 ;;
esac

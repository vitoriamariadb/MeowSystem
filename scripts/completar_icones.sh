#!/usr/bin/env bash
# completar_icones.sh — os ícones que faltavam de verdade, e os dois que são dela.
#
# O levantamento que originou esta tarefa dizia que 12 dos `.desktop` da máquina
# não tinham ícone em tema nenhum. Refeita a conta com o método que a biblioteca
# de ícones usa de fato, o número é ZERO.
#
# O jeito certo é não andar no disco: LER o `index.theme` e testar o caminho
# exato, que é o que a biblioteca faz.
#
# Este script não a repete: ele só confere as PRÓPRIAS pós-condições.
#
#     - `applications-system-symbolic` e `mark-location-symbolic` terminam em
#       `-symbolic`, e ícone simbólico é contrato: o toolkit o recolore para
#       casar com o tema. Substituí-lo por desenho colorido não deixa o ícone
#       colorido — deixa o desenho achatado numa cor só. É a mesma armadilha que
#       o applet LogoMenu cria com `custom_logo_path` (docs/COSMIC-THEMING.md §3).
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
ALVO="$TEMA_DIR/scalable/apps"
# Era `/usr/share/icons/$ICONES_BASE`, a chave crua: com o conf dizendo
# `ICONES_BASE="MeowSystem-Icons-Base"` (a base do pack, em ~/.local/share) o
# apelido do repoman se pulava por sete passadas do doctor (I1/I2 do
# 01-regressoes.md).
_base="$(ICONES_BASE="${ICONES_BASE:-}" NOME_TEMA_ICONES="$TEMA_NOME" \
           python3 "$RAIZ/scripts/pack.py" base-apelidos 2>/dev/null)"
BASE="$(printf '%s\n' "$_base" | sed -n 's/^tema=//p')"
[ -n "$BASE" ] || BASE="Papirus-Dark"
BASE_DIR="$(printf '%s\n' "$_base" | sed -n 's/^dir=//p')"
unset _base
# Vazio, vale o flavor padrão do pack no ar: o `meow_flavor` (lib/comum.sh).
# Era `${FLAVOR:-mocha}`, o padrão de um pack só.
FLAVOR="$(meow_flavor)"
ACCENT="${ACCENT:-mauve}"
# Aquele diretório guardava 55 arquivos de DOIS packs no mesmo monte — 44 do
# Catppuccin e 11 do Dracula — e o nome não dizia de quem era nenhum deles. Quem
# trocava de pack levava os dois.
#
# O `onde` responde o endereço exista ele ou não — é a MESMA porta que o
# `gerar_icones_autorais.py` usa para o `DESTINO` dele, e é essa igualdade que
# garante que os dois passos falem do mesmo diretório.
_pack_ref="$(meow_pack_dir)"
[ -n "$_pack_ref" ] || _pack_ref="$(meow_pack_padrao_dir || true)"
AUTORAIS="$(python3 "$RAIZ/scripts/pack.py" onde "$_pack_ref" \
              icones.autorais.desenhos icones/apps/)" || AUTORAIS=""

# --- os dois aplicativos dela: nome pedido pelo .desktop -> desenho autoral ----
# O Hefesto aparece com DOIS nomes de ícone na máquina, e os dois precisam do
# desenho: `hefesto-dualsense4unix` é o lançador (dela, em ~/.local) e
# `com.vitoriamaria.HefestoDualsense4Unix` é o applet empacotado (em
# /usr/share/applications).
#
# O terceiro nome, `com.vitoriamaria.HefestoDualsense4Unix-symbolic`, fica FORA:
# simbólico é monocromático por contrato e seria achatado numa cor só.
# A logo do Hefesto é obra dela e vence o tema; o arquivo mora no projeto dela.
LOGO_HEFESTO_DELA="${ICONES_LOGO_HEFESTO:-}"

declare -A AUTORAL=(
  # O painel do próprio MeowSystem.
  #
  # Agora é: quem resolve é o verbo `logo` do pack.py (o mesmo do cartão do
  # pack), com as cores do flavor e do acento em vigor.
  [com.meowsystem.Painel]="__LOGO_DO_PACK__"
  # O desenho autoral que eu tinha feito era um controle genérico, sem
  # identidade nenhuma perto do dela. Autoria dela vence tema, sempre.
  [hefesto-dualsense4unix]="__LOGO_DELA__"
  [com.vitoriamaria.HefestoDualsense4Unix]="__LOGO_DELA__"
)

# --- o que este script PLANTOU E AGORA TEM DE ARRANCAR ------------------------
# Os oito `com.system76.Cosmic*` moravam na tabela acima. Tirá-los de lá faz o
# script parar de escrever — e SÓ ISSO.
#
# Numa instalação nova ela não faz nada (o `[ -f ]` abaixo é falso) e não custa
# nada.
RETIRADOS=(
  com.system76.CosmicFiles
  com.system76.CosmicTerm
  com.system76.CosmicStore
  com.system76.CosmicSettings
  com.system76.CosmicEdit
  com.system76.CosmicMonitor
  com.system76.CosmicPlayer
  com.system76.CosmicScreenshot
)

# --- apelidos de utilitário: nome pedido -> arquivo equivalente no Papirus -----
# Tabela curta de propósito. Cada linha aqui é um nome de ícone que passa a ser
# resolvido pelo NOSSO tema para sempre; o cabeçalho explica por que só o
# `repoman` entrou.
declare -A APELIDO=(
  [repoman]="64x64/apps/cs-sources.svg"
)

# --- do hicolor do SISTEMA: a marca de fábrica, quando ela é o que se quer ----
#
# Isso é gosto, não técnica — e está aberto na página de curadoria junto com os
# outros.
#
# Os dois erros somavam um só sintoma, que ela viu na grade do lançador: borrão.
MAPA_HICOLOR="$RAIZ/packs/meowsystem/icones/apps-hicolor.map"
declare -A DO_HICOLOR=()
if [ -f "$MAPA_HICOLOR" ]; then
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    chave="${linha%%:*}"; caminho="${linha#*:}"
    [ -n "$chave" ] && [ -n "$caminho" ] || continue
    DO_HICOLOR["$chave"]="$caminho"
  done < "$MAPA_HICOLOR"
fi

mudou=0
avisos=0

# --- 0. o tema precisa existir e declarar scalable/apps ----------------------
# Sem isto o script "funciona" e não aparece nada: é a armadilha clássica de tema
# de ícones montado à mão, e o `Directories=` é a única chave de tamanho que a
# crate do COSMIC lê (docs/COSMIC-THEMING.md §2).
if [ ! -f "$TEMA_DIR/index.theme" ]; then
  meow_aviso "o tema '$TEMA_NOME' ainda não existe — quem o monta é o construir_icones.sh"
  exit "$MEOW_SEM_DEPENDENCIA"
fi
if ! grep -q '^Directories=.*scalable/apps' "$TEMA_DIR/index.theme"; then
  meow_erro "'scalable/apps' não está no Directories= de $TEMA_DIR/index.theme"
  meow_info "sem essa declaração o ícone é ignorado mesmo estando no lugar certo"
  exit "$MEOW_ERRO"
fi
# O parágrafo que estava aqui dizia que sem python3 "os ícones já existem no
# clone e só faltava copiá-los", e isso foi verdade enquanto o acervo autoral
# tinha endereço fixo (`assets/icones/autorais/`).
SEM_PYTHON=0
if ! meow_tem python3; then
  meow_aviso "python3 ausente — não dá para conferir os SVGs contra a paleta"
  SEM_PYTHON=1
  avisos=1
fi
# Vale no seco também: um `--conferir` que não sabe de que diretório sairiam
# os ícones não tem nada de verdadeiro para relatar — ele imprimiria
# "instalaria X.svg" dezoito vezes sobre um caminho que começa em `/`.
if [ -z "$AUTORAIS" ]; then
  meow_erro "não sei onde mora o acervo autoral do pack ativo"
  meow_info "  quem responde esse endereço é 'scripts/pack.py onde', e ele precisa de python3"
  meow_info "  (ou o pack no ar não valida: o motivo está no cartão dele, na Início)"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

meow_destino_permitido "$ALVO" || exit "$MEOW_ERRO"
meow_seco || mkdir -p "$ALVO" || { meow_erro "não consegui criar $ALVO"; exit "$MEOW_ERRO"; }

# --- 1. desenhar os autorais, se divergirem da paleta -------------------------
# `--conferir` primeiro: regerar sempre reescreveria 8 arquivos a cada execução
# e o `git status` nunca ficaria limpo.
if [ "$SEM_PYTHON" = "0" ] &&
   ! python3 "$RAIZ/scripts/gerar_icones_autorais.py" --accent "$ACCENT" --conferir >/dev/null 2>&1; then
  if meow_seco; then
    meow_muda "regeraria os SVGs autorais em $AUTORAIS"
    mudou=1
  else
    if ! python3 "$RAIZ/scripts/gerar_icones_autorais.py" --accent "$ACCENT" | sed 's/^/  /'; then
      meow_erro "falhou ao gerar os ícones autorais"
      exit "$MEOW_ERRO"
    fi
    mudou=1
  fi
fi

# --- 2. instalar os autorais no tema -----------------------------------------
instalados=0
for nome in "${!AUTORAL[@]}"; do
  fonte="$AUTORAIS/${AUTORAL[$nome]}"
  # O LOGO DO PACK SAI PELO STDOUT DO `pack.py logo` (ele não escreve nada); a
  # recusa — pack sem logo, logo com `<script>` — cai no desenho autoral.
  if [ "${AUTORAL[$nome]}" = "__LOGO_DO_PACK__" ]; then
    fonte="$AUTORAIS/meowsystem-painel-$FLAVOR.svg"
    if logo_do_pack="$(python3 "$RAIZ/scripts/pack.py" logo "$_pack_ref" "$FLAVOR" "$ACCENT" 2>/dev/null)" \
        && [ -n "$logo_do_pack" ]; then
      meow_escrever "$ALVO/$nome.svg" "$logo_do_pack" 644
      case $? in
        1) mudou=1; instalados=$((instalados+1)) ;;
        2) meow_erro "não consegui instalar $nome.svg"; exit "$MEOW_ERRO" ;;
      esac
      continue
    fi
    meow_info "o pack no ar não deu um logo — o lançador fica com o desenho autoral"
  fi
  # A EXCEÇÃO: onde o mapa diz `__LOGO_DELA__`, a fonte é a logo que a Vitória
  # desenhou, no repositório do próprio app, apontada pela
  # `ICONES_LOGO_HEFESTO`.
  if [ "${AUTORAL[$nome]}" = "__LOGO_DELA__" ]; then
    if [ -n "$LOGO_HEFESTO_DELA" ] && [ -f "$LOGO_HEFESTO_DELA" ]; then
      fonte="$LOGO_HEFESTO_DELA"
    else
      [ -n "$LOGO_HEFESTO_DELA" ] && \
        meow_info "a logo do Hefesto não está em $LOGO_HEFESTO_DELA — o Hefesto fica com o ícone dele"
      continue
    fi
  fi
  if [ ! -f "$fonte" ]; then
    # No seco o passo 1 não escreveu nada, então a fonte pode não existir ainda.
    if meow_seco; then
      meow_muda "instalaria $nome.svg (a fonte nasce no passo anterior)"
      continue
    fi
    if [ "$SEM_PYTHON" = "1" ]; then
      # Aqui, e SÓ aqui, a falta de python3 vira dependência ausente: o SVG
      # deste flavor não está no repositório e não há com que desenhá-lo.
      #
      # O ramo continua de pé porque a condição dele ainda é a verdadeira (falta
      # o SVG e não há com que desenhá-lo) e porque apagá-lo esconderia a
      # pergunta de quem um dia der ao resolvedor uma porta que não precise de
      # python3.
      meow_erro "falta $fonte e não há python3 para desenhá-lo"
      meow_info "  sem python3, só os flavors já versionados no acervo do pack têm desenho"
      exit "$MEOW_SEM_DEPENDENCIA"
    fi
    meow_erro "falta $fonte — o gerador não produziu o flavor '$FLAVOR'"
    exit "$MEOW_ERRO"
  fi
  meow_escrever "$ALVO/$nome.svg" "$(cat "$fonte")" 644
  case $? in
    1) mudou=1; instalados=$((instalados+1)) ;;
    2) meow_erro "não consegui instalar $nome.svg"; exit "$MEOW_ERRO" ;;
  esac
done

# --- 2b. arrancar o que este script deixou de ser dono ------------------------
# Ver o comentário do `RETIRADOS`, acima. Enquanto o arquivo estiver aqui, o
# glifo de linha que ela aprovou em `48x48/apps` não chega à tela: o resolvedor
# pede `scalable` primeiro.
retirados=0
for nome in "${RETIRADOS[@]}"; do
  [ -f "$ALVO/$nome.svg" ] || continue
  if meow_seco; then
    meow_muda "removeria $nome.svg de scalable/apps (o glifo de linha é o que vale)"
    mudou=1; retirados=$((retirados+1))
    continue
  fi
  meow_destino_permitido "$ALVO/$nome.svg" || exit "$MEOW_ERRO"
  if rm -f "$ALVO/$nome.svg"; then
    mudou=1; retirados=$((retirados+1))
  else
    meow_aviso "não consegui remover $ALVO/$nome.svg — o chapado continua vencendo"
    avisos=1
  fi
done
[ "$retirados" -gt 0 ] && ! meow_seco &&
  meow_ok "$retirados desenho(s) autorais retirados — quem veste os oito agora é o Arcticons"

# O FogStripper e o Hefesto tinham desenho gerado nos autorais do pack, e ele
# saiu. A logo dela (a `ICONES_LOGO_HEFESTO`) não carrega, e fica.
for nome in fogstripper hefesto-dualsense4unix com.vitoriamaria.HefestoDualsense4Unix; do
  [ -f "$ALVO/$nome.svg" ] || continue
  grep -qE '<title>(hefesto|fogstripper) — ' "$ALVO/$nome.svg" || continue
  if meow_seco; then
    meow_muda "removeria $nome.svg de scalable/apps (o desenho gerado saiu do pack)"
    mudou=1
    continue
  fi
  meow_destino_permitido "$ALVO/$nome.svg" || exit "$MEOW_ERRO"
  rm -f "$ALVO/$nome.svg" && mudou=1
done

# --- 2d. os apps do COSMIC sem desenho em mapa nenhum ---------
# O `meow cosmic icones` dizia «sem desenho: com.system76.CosmicViewer», e
# ninguém completava.
while IFS= read -r nome; do
  case "$nome" in ''|*[!A-Za-z0-9._+-]*) continue ;; esac
  fonte="${CV_RAIZ_APPS:-}/usr/share/icons/hicolor/scalable/apps/$nome.svg"
  [ -f "$fonte" ] || continue
  meow_escrever "$ALVO/$nome.svg" "$(cat "$fonte")" 644
  case $? in
    1) mudou=1; instalados=$((instalados+1)) ;;
    2) meow_erro "não consegui instalar $nome.svg"; exit "$MEOW_ERRO" ;;
  esac
done < <(CV_RAIZ_APPS="${CV_RAIZ_APPS:-}" "$RAIZ/scripts/cosmic_prever.sh" icones-lista 2>/dev/null)

# --- 3. apelidos vindos do Papirus -------------------------------------------
# Papirus ausente NÃO é erro: os autorais já entraram e o resto do tema continua
# de pé. Vira aviso, e o `repoman` segue com o ícone do Pop até o pacote
# existir.
#
# A linha seguinte mandava rodar `sudo apt install papirus-icon-theme`, e o
# script saía 0 com o aviso por cima: o doctor mostrava `!! completar` e fechava
# em «nada a consertar».
sem_base=0
if [ ! -d "$BASE_DIR" ]; then
  meow_aviso "a base '$BASE' não está em $BASE_DIR — apelidos de utilitário pulados"
  avisos=1; sem_base=1
else
  for nome in "${!APELIDO[@]}"; do
    fonte="$BASE_DIR/${APELIDO[$nome]}"
    if [ ! -f "$fonte" ]; then
      # O Papirus renomeia arquivo entre versões. Dizer QUAL sumiu, em vez de
      # instalar um ícone vazio e deixar o sintoma para a tela dela.
      meow_aviso "o $BASE desta máquina não tem ${APELIDO[$nome]} — '$nome' fica como está"
      avisos=1
      continue
    fi
    meow_escrever "$ALVO/$nome.svg" "$(cat "$fonte")" 644
    case $? in
      1) mudou=1; instalados=$((instalados+1)) ;;
      2) meow_erro "não consegui instalar o apelido $nome.svg"; exit "$MEOW_ERRO" ;;
    esac
  done
fi

# --- 3b. a cache do tema, que engole ícone novo em silêncio -------------------
# Com a cache dentro do tema o GTK ignora o disco. Reindexa, e não apaga (quem a
# criou queria a cache), e só com ícone mais novo que ela: a segunda passada não escreve.
CACHE="$TEMA_DIR/icon-theme.cache"
if [ -f "$CACHE" ] && [ -n "$(find "$ALVO" -name '*.svg' -newer "$CACHE" -print -quit 2>/dev/null)" ]; then
  if meow_seco; then
    meow_muda "reindexaria a cache do tema ($CACHE está velha e esconde ícone novo)"
    mudou=1
  elif meow_tem gtk-update-icon-cache; then
    if gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null; then
      meow_ok "cache do tema reindexada (ela escondia os ícones novos)"
      mudou=1
    else
      meow_aviso "não consegui reindexar $CACHE — apague-a se algum ícone não aparecer"
      avisos=1
    fi
  else
    meow_aviso "$CACHE está velha e esconde os ícones novos, e não há gtk-update-icon-cache"
    meow_info "  apague o arquivo: rm '$CACHE'"
    avisos=1
  fi
fi

# --- 4. conferir as PRÓPRIAS pós-condições -----------------------------------
# Três coisas têm de valer para um arquivo aqui virar ícone na tela, e as três
# falham CALADAS.
TK="$(meow_cosmic_dir)/com.system76.CosmicTk/$(meow_cosmic_v com.system76.CosmicTk)/icon_theme"
if [ -f "$TK" ] && ! grep -q "\"$TEMA_NOME\"" "$TK"; then
  meow_aviso "'$TEMA_NOME' NÃO é o tema de ícones selecionado — nada disto vai aparecer"
  meow_info "  o «Reconstruir os ícones» o põe no ar"
  avisos=1
fi

faltando=()
for nome in "${!DO_HICOLOR[@]}"; do
  fonte="${DO_HICOLOR[$nome]}"
  if [ ! -f "$fonte" ]; then
    meow_info "$nome: $fonte não existe — pulado"
    continue
  fi
  # PNG mesmo: renomear para `.svg` seria mentira e o renderizador reclamaria.
  #
  # Não há `identify` aqui de propósito: o caminho do `hicolor` já CARREGA o
  # tamanho (`.../128x128/apps/`), e lê-lo dali não acrescenta dependência ao
  # script.
  lado="$(basename "$(dirname "$(dirname "$fonte")")")"
  case "$lado" in
    [0-9]*x[0-9]*) : ;;
    *) meow_aviso "$nome: não consigo deduzir o tamanho de $fonte — pulado"
       avisos=1; continue ;;
  esac
  # Diretório no disco que ninguém DECLARA é diretório que ninguém acha (§2).
  if ! grep -q "^Directories=.*${lado}/apps" "$TEMA_DIR/index.theme"; then
    meow_aviso "$nome: '${lado}/apps' ainda não está no Directories= — pulado"
    meow_info "  entra na próxima rodada, depois de scripts/construir_icones.sh"
    avisos=1; continue
  fi
  # O arquivo no lugar ERRADO tem de sair, senão ficam DOIS donos do mesmo nome
  # e a regra da extensão (§2) faz um deles vencer sem ninguém ter decidido. É o
  # que sobra do `scalable/apps/thunderbird.png` de antes.
  if [ -f "$ALVO/$nome.png" ]; then
    if meow_seco; then
      meow_muda "removeria $nome.png de scalable/apps (raster em diretório escalável)"
      mudou=1
    else
      rm -f "$ALVO/$nome.png" && mudou=1
    fi
  fi
  alvo_png="$TEMA_DIR/$lado/apps/$nome.png"
  if [ ! -f "$alvo_png" ] || ! cmp -s "$fonte" "$alvo_png"; then
    if meow_seco; then
      meow_muda "copiaria $nome do hicolor do sistema para $lado/apps"
    else
      meow_destino_permitido "$alvo_png" || exit "$MEOW_ERRO"
      mkdir -p "$TEMA_DIR/$lado/apps"
      cp -f "$fonte" "$alvo_png" && chmod 644 "$alvo_png" && mudou=1
    fi
  fi
done

# Um `.png` num `<tam>/apps` do nosso tema só é meu quando é BYTE A BYTE igual
# a um arquivo do `hicolor` do sistema, no mesmo tamanho — que é exatamente o
# que este laço acima escreve, com `cp -f`.
#
# Comparar por NOME seria o defeito de sempre — o nome não diz quem escreveu.
_hicolor_orfaos() {
  local dir lado arq nome fonte n=0
  for dir in "$TEMA_DIR"/*x*/apps; do
    [ -d "$dir" ] || continue
    lado="$(basename "$(dirname "$dir")")"
    for arq in "$dir"/*.png; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .png)"
      # ainda no mapa: é meu e continua sendo
      [ -n "${DO_HICOLOR[$nome]:-}" ] && continue
      fonte="/usr/share/icons/hicolor/$lado/apps/$nome.png"
      [ -f "$fonte" ] || continue
      cmp -s "$fonte" "$arq" || continue
      printf '%s\n' "$arq"
      n=$((n + 1))
    done
  done
  return 0
}

while IFS= read -r arq; do
  [ -n "$arq" ] || continue
  if meow_seco; then
    meow_muda "removeria $(printf '%s' "$arq" | sed "s|^$TEMA_DIR/||") (saiu do apps-hicolor.map; o traço volta a valer)"
    mudou=1
  else
    meow_destino_permitido "$arq" || exit "$MEOW_ERRO"
    if rm -f "$arq"; then
      meow_muda "removido $(printf '%s' "$arq" | sed "s|^$TEMA_DIR/||") — saiu do apps-hicolor.map, o traço volta a valer"
      mudou=1
    else
      meow_aviso "não consegui remover $arq — a marca de fábrica continua vencendo o traço"
      avisos=1
    fi
  fi
done < <(_hicolor_orfaos)

for nome in "${!AUTORAL[@]}" "${!APELIDO[@]}"; do
  # O Hefesto sem a logo apontada não entra de propósito: não é falta, é o
  # ícone do próprio aplicativo.
  if [ "${AUTORAL[$nome]:-}" = "__LOGO_DELA__" ] && { [ -z "$LOGO_HEFESTO_DELA" ] || [ ! -f "$LOGO_HEFESTO_DELA" ]; }; then
    continue
  fi
  [ -f "$ALVO/$nome.svg" ] || faltando+=("$nome")
done
if [ ${#faltando[@]} -gt 0 ] && ! meow_seco; then
  meow_aviso "não chegaram ao tema: ${faltando[*]}"
  avisos=1
fi

# O doctor roda este script com `MEOW_DRY_RUN=1` e mostra a PRIMEIRA linha da
# saída como veredito.
if ! meow_seco && [ -x "$RAIZ/scripts/auditar_icones.sh" ]; then
  meow_info "auditoria completa da máquina: ./scripts/auditar_icones.sh"
fi

if [ "$mudou" = "0" ]; then
  [ "$sem_base" = "1" ] && exit "$MEOW_SEM_DEPENDENCIA"
  meow_ok "ícones completos: ${#AUTORAL[@]} autorais e ${#APELIDO[@]} apelido(s) já no lugar"
  exit "$MEOW_OK"
fi

if meow_seco; then
  exit "$MEOW_DIVERGENTE"
fi

if [ "$instalados" = "0" ]; then
  # Chega-se aqui quando os SVGs já estavam certos e o que divergia era outra
  # coisa (a cache do tema, ou os fontes regerados por troca de ACCENT). Dizer
  # "0 ícones instalados" faria parecer que o script não fez nada.
  meow_ok "os ícones já estavam no lugar; o que divergia acima foi corrigido"
else
  meow_ok "$instalados ícone(s) instalados em $ALVO"
fi
meow_info "o painel só relê no início da sessão — para ver agora: meow painel reciclar"
[ "$avisos" = "1" ] && meow_info "houve avisos acima; nada ficou pela metade"
meow_notificar "MeowSystem" "Ícones completados ($instalados)."
exit "$MEOW_DIVERGENTE"

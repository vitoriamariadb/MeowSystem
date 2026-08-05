#!/usr/bin/env bash
# install.sh — instala o MeowSystem inteiro. Sem flag nenhuma.
#
#   ./install.sh              faz tudo
#   MEOW_DRY_RUN=1 ./install.sh   mostra o que faria, sem escrever nada
#
# POR QUE NÃO TEM FLAG
#   A §5.1 do RELATORIO propunha 14 flags (--tema, --icones, --logo, --all...).
#   Está declarada histórica: quem decide o que instalar é o `meow.conf`, não a
#   linha de comando. Uma flag a menos é uma decisão a menos na hora de usar.
#   O `--dry-run` sobrevive como MEOW_DRY_RUN=1 — invisível no uso normal,
#   disponível para auditar antes de deixar rodar.
#
# FALHA POR UNIDADE, NUNCA GLOBAL (regra 8 do contrato)
#   Cada etapa é uma função que RETORNA código; nenhuma chama `exit`. Um app
#   ausente vira "pulado" e o resto continua. É por isso que este script NÃO usa
#   `set -e`: com ele, uma etapa que devolvesse != 0 abortaria tudo e deixaria a
#   máquina em estado parcial — que é pior do que não ter começado.
#
# O QUE ELE NUNCA FAZ
#   - `apt upgrade` / `dist-upgrade`, nem tocar em pacote `cosmic-*`. O
#     /usr/bin/cosmic-comp desta máquina está patchado DUAS vezes (workspace
#     vazio e night light) e uma versão nova mata os dois de uma vez, derrubando
#     os workspaces alfinetados Meow e OS.
#   - escrever em /usr/share, no repo Andromeda ou nos atalhos de teclado.
#     A trava está em lib/comum.sh e recusa por caminho, não por boa intenção.
#   - sudo perto de ~/.config: um arquivo de dono root ali faz a GUI de tema
#     falhar EM SILÊNCIO, e o sintoma só aparece dias depois.

MEOW_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

CONF_PADRAO="$MEOW_RAIZ/meow.conf.exemplo"
CONF="${MEOW_CONF:-$HOME/.config/meow/meow.conf}"

declare -a FEITOS=() PULADOS=() FALHOS=()
PASSO=0
TOTAL=8

passo() { PASSO=$((PASSO+1)); meow_passo "[$PASSO/$TOTAL] $*"; }

# Registra o resultado de uma etapa sem deixar o código dela derrubar o script.
concluir() {
  local nome="$1" rc="$2"
  case "$rc" in
    0) FEITOS+=("$nome") ;;
    1) FEITOS+=("$nome") ;;                       # divergia e foi consertado
    3) PULADOS+=("$nome") ;;
    *) FALHOS+=("$nome") ;;
  esac
}

# ---------------------------------------------------------------------------
etapa_conf() {
  passo "Configuração"
  local fonte="$CONF"
  if [ -f "$CONF" ]; then
    meow_ok "meow.conf já existe em $CONF"
  else
    local conteudo; conteudo="$(cat "$CONF_PADRAO")"
    meow_escrever "$CONF" "$conteudo" 644
    case $? in
      0) meow_ok "meow.conf criado em $CONF" ;;
      1) if meow_seco; then
           # No seco o arquivo NÃO foi criado — ler dele daria "arquivo
           # inexistente" e, pior, deixaria FLAVOR/ACCENT sem valor para as
           # etapas seguintes, que morreriam com "variável não associada".
           # O exemplo é a mesma coisa que seria escrita, então serve de fonte.
           meow_info "no seco, lendo os valores de meow.conf.exemplo"
           fonte="$CONF_PADRAO"
         else
           meow_ok "meow.conf criado em $CONF"
         fi ;;
      *) meow_erro "não consegui criar $CONF"; return "$MEOW_ERRO" ;;
    esac
  fi
  # shellcheck disable=SC1090
  . "$fonte" || { meow_erro "$fonte tem erro de sintaxe"; return "$MEOW_ERRO"; }
  for v in FLAVOR ACCENT MODO LOGO; do
    if [ -z "${!v:-}" ]; then
      meow_erro "$v não está definida em $fonte"
      return "$MEOW_ERRO"
    fi
  done
  meow_info "flavor=$FLAVOR accent=$ACCENT modo=$MODO logo=$LOGO"
  return 0
}

# ---------------------------------------------------------------------------
# O ÚNICO BLOCO COM sudo DO INSTALADOR INTEIRO.
#
# POR QUE ELE VEM CEDO, E NÃO NO FIM
#   A recomendação instintiva seria deixar o apt por último, longe das escritas
#   de configuração. Aqui é o contrário, por dois motivos concretos:
#   1. O `papirus-icon-theme` é PRÉ-REQUISITO da etapa de pastas. Instalado
#      depois, a etapa de pastas já teria se pulado e só funcionaria na
#      execução seguinte — "rodei e não ficou pronto" é um péssimo primeiro uso.
#   2. Todo `apt` desta máquina dispara o hook do Ritual da Aurora, que roda o
#      self-heal COMPLETO e reconcilia configuração. Rodando o apt ANTES, esse
#      self-heal acontece antes das nossas escritas. Rodando depois, ele poderia
#      reverter o que acabamos de aplicar.
#
# O QUE ELE NUNCA FAZ
#   `upgrade`, `dist-upgrade`, `full-upgrade`, nem tocar em pacote `cosmic-*`.
#   O `/usr/bin/cosmic-comp` desta máquina está patchado duas vezes (workspace
#   vazio e night light) e uma versão nova mata os dois de uma vez, derrubando
#   junto os workspaces alfinetados. `install <pacote>` explícito e mais nada.
#
# FALTA DE sudo NÃO É ERRO
#   Devolve 3 e diz o comando exato. O resto do tema continua sendo aplicado —
#   ficam de fora só as pastas coloridas e os temas de `bat`/`btop`.
etapa_pacotes() {
  passo "Pacotes do sistema"

  # binário que testa presença -> pacote que o instala
  local -A NECESSARIOS=(
    [rsvg-convert]=librsvg2-bin
    [convert]=imagemagick
    [gtk-update-icon-cache]=libgtk-3-bin
    [python3]=python3
    [git]=git
    [btop]=btop
    # No Debian/Ubuntu o `bat` instala como `batcat`: o nome `bat` já pertence ao
    # bacula-console-qt. Testar por `bat` faria o instalador reinstalar o pacote
    # a cada execução, para sempre, sem nunca ficar satisfeito.
    [batcat]=bat
  )
  # O Papirus não tem binário — testa-se pelo diretório do tema.
  local faltam=()
  local b
  for b in "${!NECESSARIOS[@]}"; do
    meow_tem "$b" || faltam+=("${NECESSARIOS[$b]}")
  done
  [ -d /usr/share/icons/Papirus-Dark ] || faltam+=(papirus-icon-theme)

  if [ ${#faltam[@]} -eq 0 ]; then
    meow_ok "todos os pacotes necessários já estão instalados"
    return 0
  fi

  meow_info "faltam: ${faltam[*]}"
  if meow_seco; then
    meow_muda "rodaria: sudo apt-get install -y --no-install-recommends ${faltam[*]}"
    return "$MEOW_DIVERGENTE"
  fi

  if ! meow_tem sudo; then
    meow_aviso "sudo não encontrado — instale à mão:"
    meow_info "  apt install ${faltam[*]}"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # Dizer em voz alta o que vai rodar como root, ANTES de rodar. Um instalador
  # que pede senha sem explicar o que vai fazer com ela não merece a senha.
  meow_info "vou rodar como root, e só isto:"
  printf '      sudo apt-get install -y --no-install-recommends %s\n' "${faltam[*]}"

  if ! sudo apt-get install -y --no-install-recommends "${faltam[@]}" >/dev/null 2>&1; then
    meow_aviso "a instalação falhou (sem sudo? sem rede?) — seguindo sem esses pacotes"
    meow_info "  sudo apt-get install ${faltam[*]}"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  meow_ok "instalados: ${faltam[*]}"
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
etapa_gerar() {
  passo "Gerar temas e ícones a partir da paleta"
  local rc=0
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" --conferir >/dev/null 2>&1 || rc=1
  python3 "$MEOW_RAIZ/scripts/gerar_gato.py" --conferir >/dev/null 2>&1 || rc=1
  if [ "$rc" = "0" ]; then
    meow_ok "temas e gatos já correspondem à paleta"
    return 0
  fi
  if meow_seco; then
    meow_muda "regeraria temas e gatos"
    return "$MEOW_DIVERGENTE"
  fi
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" | sed 's/^/  /' || return "$MEOW_ERRO"
  python3 "$MEOW_RAIZ/scripts/gerar_gato.py" --accent "$ACCENT" | sed 's/^/  /' || return "$MEOW_ERRO"
  meow_ok "regenerados a partir de palette/"
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
# O tema é a única coisa deste instalador que já precisou de um humano — uma vez.
# O COSMIC não deriva o tema aplicado a partir do que a GUI edita: MEDIDO em
# 04/08/2026, escrever em Dark.Builder/v1/accent não moveu Dark/v1/accent nem em
# 4s nem depois; o cosmic-settings-daemon estava vivo e não derivou. Quem deriva
# é o app gráfico. Então a captura tem de nascer de um import manual.
# Depois disso a captura vai para o git e QUALQUER máquina a recebe por cópia,
# com zero clique — é uma vez na vida do projeto, não uma vez por máquina.
etapa_tema() {
  passo "Tema"
  local alvo="${FLAVOR}-${ACCENT}"
  local captura="$MEOW_RAIZ/state/tema/$alvo"

  if [ ! -d "$captura" ]; then
    meow_aviso "ainda não há captura para '$alvo'"
    meow_info "importe themes/meowsystem-$alvo.ron uma vez em"
    meow_info "  Configurações > Área de trabalho > Aparência > Importar"
    meow_info "e depois rode: ./scripts/capturar_tema.sh $alvo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if MEOW_DRY_RUN=0 "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$alvo" --conferir >/dev/null 2>&1; then
    meow_ok "tema '$alvo' já aplicado"
    return 0
  fi
  if meow_seco; then
    meow_muda "aplicaria o tema '$alvo'"
    return "$MEOW_DIVERGENTE"
  fi
  "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$alvo" | sed 's/^/  /' || return "$MEOW_ERRO"
  meow_notificar "MeowSystem" "Tema $alvo aplicado."
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
etapa_modo() {
  passo "Modo claro/escuro"
  local arq="$HOME/.config/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark"
  local desejado
  case "$MODO" in
    escuro) desejado=true ;;
    claro)  desejado=false ;;
    # Claro e escuro NÃO são dois temas: as capturas mocha-mauve e latte-mauve
    # diferem em exatamente UM arquivo, e é este `is_dark`. Então "auto" é só
    # escolher o valor pelo horário — sem reaplicar árvore e sem piscar a
    # interface. O que torna isso possível é cada captura já trazer as DUAS
    # árvores em Catppuccin; sem isso, virar o dia devolveria o tema claro de
    # fábrica.
    auto)
      local hora; hora="$(date +%-H)"
      local ini="${MODO_AUTO_CLARO_DE:-7}" fim="${MODO_AUTO_CLARO_ATE:-18}"
      if [ "$hora" -ge "$ini" ] && [ "$hora" -lt "$fim" ]; then
        desejado=false
      else
        desejado=true
      fi
      meow_info "modo automático: ${hora}h → $([ "$desejado" = true ] && echo escuro || echo claro)"
      ;;
    *)      meow_aviso "MODO='$MODO' desconhecido — esperado escuro|claro|auto"; return "$MEOW_ERRO" ;;
  esac
  meow_escrever "$arq" "$desejado" 644
  case $? in
    0) meow_ok "modo $MODO já ativo" ;;
    1) meow_ok "modo $MODO aplicado" ;;
    *) return "$MEOW_ERRO" ;;
  esac
  return 0
}

# ---------------------------------------------------------------------------
# Os dois gatos e o tema de ícones saem juntos: a logo do painel é caminho de
# arquivo e o botão do dock é tema de ícones, mas os dois vêm do mesmo SVG e
# reiniciam o mesmo processo. Separá-los custaria dois piscar de painel.
etapa_icones() {
  passo "Ícones e logo"
  FLAVOR="$FLAVOR" LOGO="$LOGO" ICONES_BASE="${ICONES_BASE:-Papirus-Dark}" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/construir_icones.sh"
  local rc=$?
  [ "$rc" = "1" ] && meow_notificar "MeowSystem" "Ícones e logo atualizados."
  return "$rc"
}

# As pastas coloridas vêm de terceiros (Papirus + catppuccin/papirus-folders) e
# pesam ~2 MB de SVG. Ficam numa etapa própria porque dependem de rede e do
# pacote do apt: sem qualquer um dos dois, o resto do tema continua de pé.
etapa_upstream() {
  passo "Upstream de terceiros (commits pinados)"
  "$MEOW_RAIZ/scripts/baixar_upstream.sh"
  return $?
}

etapa_pastas() {
  passo "Pastas na cor do flavor"
  ICONES_BASE="${ICONES_BASE:-Papirus-Dark}" \
    ICONES_PASTAS="${ICONES_PASTAS:-cat-${FLAVOR}-${ACCENT}}" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/construir_pastas.sh"
  return $?
}

etapa_apps() {
  passo "Aplicativos"
  APPS_ATIVOS="${APPS_ATIVOS:-}" "$MEOW_RAIZ/scripts/aplicar_apps.sh" aplicar
  return $?
}

etapa_wallpaper() {
  passo "Papéis de parede"
  WALLPAPER_INTERVALO="${WALLPAPER_INTERVALO:-5m}" \
    WALLPAPER_ORDEM="${WALLPAPER_ORDEM:-aleatoria}" \
    "$MEOW_RAIZ/scripts/wallpaper.sh" aplicar
  local rc=$?
  [ "$rc" = "1" ] && [ "${WALLPAPER_NOTIFICAR:-sim}" = "sim" ] \
    && meow_notificar "MeowSystem" "Carrossel de papéis de parede ligado."
  return "$rc"
}

# ---------------------------------------------------------------------------
main() {
  meow_titulo "MeowSystem — Catppuccin para o COSMIC"
  meow_seco && meow_aviso "MEOW_DRY_RUN=1 — nada será escrito"

  meow_travar || return 2

  local etapas=(etapa_conf etapa_pacotes etapa_gerar etapa_tema
                etapa_modo etapa_upstream etapa_icones etapa_pastas etapa_wallpaper
                etapa_apps)
  TOTAL=${#etapas[@]}

  for e in "${etapas[@]}"; do
    "$e"; local rc=$?
    concluir "${e#etapa_}" "$rc"
    # A configuração é a única etapa que não é opcional: sem FLAVOR e ACCENT as
    # seguintes não têm o que aplicar. Parar aqui é honesto; seguir seria morrer
    # com "variável não associada" três etapas adiante, escondendo a causa.
    if [ "$e" = "etapa_conf" ] && [ "$rc" -ge 2 ]; then
      meow_erro "sem configuração válida não há o que instalar — parando"
      break
    fi
  done

  meow_passo "Resultado"
  [ ${#FEITOS[@]}  -gt 0 ] && meow_ok    "feito:  ${FEITOS[*]}"
  [ ${#PULADOS[@]} -gt 0 ] && meow_pula  "pulado: ${PULADOS[*]}"
  [ ${#FALHOS[@]}  -gt 0 ] && meow_erro  "falhou: ${FALHOS[*]}"

  meow_registrar "install.sh feitos=${#FEITOS[@]} pulados=${#PULADOS[@]} falhos=${#FALHOS[@]}"

  if [ ${#FALHOS[@]} -gt 0 ]; then
    printf '\n  %sAlgumas etapas falharam. Nada foi deixado pela metade —%s\n' "$C_AMARELO" "$C_ZERO"
    printf '  %scada etapa é independente, e o resto foi aplicado.%s\n\n' "$C_AMARELO" "$C_ZERO"
    return 2
  fi
  printf '\n  %sPronto.%s Rode de novo quando quiser: nada é escrito duas vezes.\n\n' "$C_VERDE$C_FORTE" "$C_ZERO"
  return 0
}

main "$@"

#!/usr/bin/env bash
# preflight.sh — a única fase que SÓ OLHA.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO.
#
# Roda antes do lock e antes da primeira escrita. Não abre rede e não invoca
# binário de terceiro que tenha efeito colateral: `code --list-extensions` e
# `flatpak info` criam perfil e repositório no home só por serem perguntados, e
# uma fase de diagnóstico que escreve não é diagnóstico.
#
# NÃO HAVIA NADA DISSO ATÉ AQUI
#   O instalador escrevia o meow.conf e a CLI ANTES de descobrir que faltava o
#   apt, que o desktop não era o COSMIC ou que o esquema de tema era outro. O
#   sintoma nunca era "não dá": era meia instalação e um diretório
#   `~/.config/cosmic/` que ninguém lê.
#
# O QUE ELE DEVOLVE
#   0 = pode ir   ·   1 = vai com pedaços de fora   ·   2 = não dá.
#   Só o 2 aborta — cada etapa continua sabendo se pular sozinha.

meow_preflight() {
  local fatal=0 avisos=0
  meow_passo "Pré-voo"

  # 1. ROOT NÃO. A guarda também está no main(), que é onde ela recusa mais
  #    cedo; aqui ela fica porque o pré-voo é chamado por outros caminhos.
  if [ "$(id -u)" = "0" ]; then
    meow_erro "não me rode como root: os arquivos de ~/.config ficariam de dono root"
    if [ -n "${SUDO_USER:-}" ]; then
      meow_info "  rode assim:  ./install.sh        (como $SUDO_USER)"
    else
      meow_info "  rode como o seu usuário normal:  ./install.sh"
    fi
    meow_info "  o sudo é pedido por dentro, e ele diz o que vai rodar antes de rodar"
    return 2
  fi

  # 2. É COSMIC? `XDG_CURRENT_DESKTOP` é a variável da spec do freedesktop; no
  #    Pop!_OS a sessão a define como COSMIC. O `pgrep` cobre rodar de um TTY com
  #    a sessão gráfica viva, e a variável de escape cobre instalar antes do
  #    primeiro login.
  case "${XDG_CURRENT_DESKTOP:-}:${DESKTOP_SESSION:-}" in
    *[Cc][Oo][Ss][Mm][Ii][Cc]*)
      meow_ok "COSMIC detectado (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-?})" ;;
    *)
      if pgrep -x cosmic-comp >/dev/null 2>&1; then
        meow_aviso "XDG_CURRENT_DESKTOP='${XDG_CURRENT_DESKTOP:-}' não diz COSMIC, mas o cosmic-comp está vivo — seguindo"
        avisos=$((avisos+1))
      elif [ "${MEOW_IGNORA_DESKTOP:-0}" = "1" ]; then
        meow_aviso "MEOW_IGNORA_DESKTOP=1 — seguindo sem COSMIC"
        avisos=$((avisos+1))
      else
        meow_erro "isto veste o COSMIC, e o COSMIC não está rodando aqui"
        meow_info "  num GNOME/KDE o resultado é ~/.config/cosmic/ que ninguém lê,"
        meow_info "  mais timers do systemd e um tema de ícones sem quem o peça."
        meow_info "  para instalar mesmo assim (ex.: pelo TTY, antes do 1º login):"
        meow_info "      MEOW_IGNORA_DESKTOP=1 ./install.sh"
        return 2
      fi ;;
  esac

  # 3. Esquema de tema. As capturas deste repositório são v1+v2 (ver
  #    docs/COSMIC-THEMING.md §4 e §4h). Um esquema que não reconhecemos tem de
  #    ser dito ANTES de copiar mais de cem arquivos por cima dele.
  local esquemas="" _v
  for _v in "$HOME/.config/cosmic/com.system76.CosmicTheme.Dark/"v*; do
    [ -d "$_v" ] && esquemas="$esquemas${_v##*/} "
  done
  case " $esquemas " in
    "  ") meow_pula "o COSMIC ainda não escreveu tema neste usuário — a captura vai criar" ;;
    *" v2 "*) meow_ok "esquema de tema: ${esquemas% } (as capturas cobrem v1 e v2)" ;;
    # v1 SEM v2 É CONHECIDO, E O `case` NÃO TINHA RAMO PARA ELE ATÉ 10/08/2026.
    #   O comentário logo acima diz "as capturas deste repositório são v1+v2" e o
    #   código chamava metade disso de "desconhecido". É um COSMIC anterior ao
    #   esquema v2; a captura escreve as duas árvores e a v2 fica inerte até o dia
    #   em que ele atualizar. Inerte nesta máquina — aqui o disco tem v1 e v2 —,
    #   mas errado, e um aviso falso no pré-voo é o que faz pré-voo ser ignorado.
    *" v1 "*) meow_ok "esquema de tema: ${esquemas% } — COSMIC anterior ao v2; a captura cobre e a v2 fica inerte" ;;
    *) meow_aviso "esquema de tema desconhecido aqui: ${esquemas% }"
       meow_info "  as capturas deste repositório são v1+v2 (docs/COSMIC-THEMING.md §4)"
       avisos=$((avisos+1)) ;;
  esac

  # 4. bash. O instalador usa `declare -A`, que é 4.0; o 4.3 é o piso do nameref,
  #    e é o piso que vale a pena cobrar de uma vez.
  if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ] || \
     { [ "${BASH_VERSINFO[0]}" = "4" ] && [ "${BASH_VERSINFO[1]:-0}" -lt 3 ]; }; then
    meow_erro "preciso de bash 4.3+ (aqui: ${BASH_VERSION:-?})"; fatal=1
  fi

  # 5. O básico, sem o qual nem começa.
  local b
  for b in flock sed awk find mktemp sha256sum; do
    meow_tem "$b" || { meow_erro "falta o básico: $b"; fatal=1; }
  done

  # 6. O que ETAPAS INTEIRAS usam e a etapa de pacotes não pede. Não é fatal —
  #    cada uma se pula — mas tem de ser dito agora, não no meio de trinta.
  for b in curl tar git python3 rsvg-convert convert gtk-update-icon-cache fc-cache unzip; do
    meow_tem "$b" || { meow_pula "sem $b — a etapa que depende dele vai se pular"; avisos=$((avisos+1)); }
  done

  # 6b. O CARGO, E ELE MERECE UMA LINHA SÓ PARA SI.
  #     Até 24/08/2026 este projeto NÃO COMPILAVA NADA: um grep por
  #     `cargo|rustc|make|gcc|meson|cmake` em install.sh, scripts/, lib/ e
  #     bin/meow devolvia zero invocações. O módulo `midia` é o primeiro, e uma
  #     dependência de toolchain é de outra natureza que as de cima — ela não se
  #     instala com um `apt install` de uma linha, e quem não a tem quase sempre
  #     não a quer. Por isso ela AVISA e não mata: sem cargo, o `midia_build.sh`
  #     devolve 3, cai em "pulados", e a máquina segue com o applet de mídia que
  #     o flatpak já entrega. Degradação limpa, não falha.
  if ! meow_tem cargo; then
    meow_pula "sem cargo — o applet de mídia não é compilado (fica o do flatpak)"
    meow_info "  se quiser: rustup toolchain install stable, e rode o install.sh de novo"
    avisos=$((avisos+1))
  fi

  # 7. Gerenciador de pacotes. Só AVISA: `etapa_pacotes` fala apt, e fingir que
  #    fala dnf/pacman sem escrever os comandos é pior do que não falar.
  if ! meow_tem apt-get; then
    meow_aviso "sem apt-get — a etapa de pacotes vai se pular"
    meow_info "  instale à mão: librsvg2-bin imagemagick libgtk-3-bin python3 git btop bat papirus-icon-theme"
    avisos=$((avisos+1))
  fi

  # 8. Existe captura para o que o meow.conf pediu? Descobrir isso na etapa 5,
  #    depois de escrever a CLI e instalar pacotes, é descobrir tarde.
  if [ -n "${FLAVOR:-}" ] && [ -n "${ACCENT:-}" ] \
     && [ ! -d "$MEOW_RAIZ/assets/temas/capturados/${FLAVOR}-${ACCENT}" ]; then
    meow_aviso "não há captura para '${FLAVOR}-${ACCENT}' — o tema do COSMIC não vai ser aplicado"
    # `original` fica de fora da lista: é reset de fábrica DESTA máquina, não uma
    # variante que alguém escolheria no meow.conf.
    local prontas="" _c
    for _c in "$MEOW_RAIZ/assets/temas/capturados"/*; do
      [ -d "$_c" ] || continue
      [ "${_c##*/}" = "original" ] && continue
      prontas="$prontas${_c##*/} "
    done
    meow_info "  as prontas: ${prontas:-nenhuma}"
    avisos=$((avisos+1))
  fi

  meow_precisa_root

  [ "$fatal" = "1" ] && return 2
  if [ "$avisos" -gt 0 ]; then
    meow_info "$avisos aviso(s) — o instalador segue e pula o que não dá"
    return 1
  fi
  meow_ok "tudo no lugar"
  return 0
}

# --- A ELEVAÇÃO, UMA VEZ, EXPLICADA -----------------------------------------
# Sem isto, quatro etapas se penduravam no timestamp de 15 min que o
# `sudo apt-get` da etapa de pacotes deixava POR ACIDENTE — e numa máquina onde
# não falta pacote nenhum esse timestamp nunca existe, porque a etapa sai antes
# de invocar sudo. O resultado da instalação passava a depender de um detalhe
# invisível: se faltava ou não um pacote. O doctor.log registra o sintoma toda
# madrugada: "não consigo olhar /var/lib/cosmic-greeter/.config/cosmic sem sudo".
#
# A lista de pacotes é RECALCULADA aqui de propósito. Ler o `faltam` da
# `etapa_pacotes` não funciona: ele é `local` daquela função, e daqui seria uma
# variável não associada ou, pior, um teste que lê vazio e nunca eleva.
meow_precisa_root() {
  local -a motivos=()

  local -a pkg_faltam=()
  local b
  for b in rsvg-convert convert gtk-update-icon-cache python3 git btop batcat; do
    meow_tem "$b" || pkg_faltam+=("$b")
  done
  [ -d /usr/share/icons/Papirus-Dark ] || pkg_faltam+=(papirus-icon-theme)
  [ ${#pkg_faltam[@]} -gt 0 ] && motivos+=("instalar pacotes: ${pkg_faltam[*]}")

  # A PONTE COBRE ESTES DOIS — 08/09/2026
  #   Marcar `.desktop` de sistema e vestir a tela de login são verbos dela, e
  #   verbo dela não pede senha. Continuar anunciando "estas etapas precisam de
  #   root" numa máquina com a ponte no ar é avisar de um custo que não existe —
  #   e, pior, o aviso vem seguido de "sem terminal para pedir a senha" quando
  #   quem roda é o painel, o que faz uma instalação inteira e bem-sucedida
  #   parecer meia-instalação.
  if ! meow_ponte_viva; then
    [ "${LANCADOR_SISTEMA:-nao}" = "sim" ] && \
      motivos+=("marcar .desktop em /usr/share/applications (esconder/renomear)")
    # `[ -d /var/lib/cosmic-greeter ]` é legível sem sudo; o que exige sudo é
    # entrar no `.config` de dentro. Por isso o gatilho funciona sem elevar.
    [ -d /var/lib/cosmic-greeter ] && \
      motivos+=("vestir a tela de login em /var/lib/cosmic-greeter")
  fi

  [ ${#motivos[@]} -eq 0 ] && return 0
  sudo -n true 2>/dev/null && return 0        # já em cache: nada a pedir
  meow_tem sudo || { meow_pula "sem sudo — essas etapas ficam de fora, o resto vai"; return 0; }

  meow_info "algumas etapas precisam de root. São estas, e só estas:"
  local m; for m in "${motivos[@]}"; do printf '        %s\n' "$m"; done
  # No seco não se pede senha: `sudo -v` deixa um timestamp em /run, e uma
  # auditoria que muda o estado do sudo já não é só uma auditoria.
  if meow_seco; then
    meow_pula "ensaio — não vou pedir a senha"
  elif [ -t 0 ]; then
    # Pedir AGORA, antes de qualquer trabalho, em vez de o prompt aparecer no
    # meio de trinta etapas — ou não aparecer, que é o que acontecia.
    sudo -v || meow_pula "sem sudo — essas etapas ficam de fora, o resto vai"
  else
    meow_pula "sem terminal para pedir a senha — essas etapas ficam de fora"
  fi
  return 0
}

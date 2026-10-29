#!/usr/bin/env bash

meow_preflight() {
  local fatal=0 avisos=0
  meow_passo "Pré-voo"

  if [ "$(id -u)" = "0" ]; then
    meow_erro "como root, não: os arquivos de ~/.config ficariam de dono root — nada foi feito"
    if [ -n "${SUDO_USER:-}" ]; then
      meow_info "  o instalador roda como $SUDO_USER, na sessão dele"
    else
      meow_info "  o instalador roda como o seu usuário, na sua sessão"
    fi
    meow_info "  o sudo é pedido por dentro, e ele diz o que vai rodar antes de rodar"
    return 2
  fi

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
        meow_erro "isto arruma o COSMIC, e o COSMIC não está rodando aqui"
        meow_info "  num GNOME/KDE o resultado é ~/.config/cosmic/ que ninguém lê,"
        meow_info "  mais timers do systemd e um tema de ícones sem quem o peça."
        meow_info "  o instalador só segue sem COSMIC com MEOW_IGNORA_DESKTOP=1 no ambiente (ex.: pelo TTY, antes do 1º login)"
        return 2
      fi ;;
  esac

  local esquemas="" _v cobertos
  for _v in "$(meow_cosmic_dir)/com.system76.CosmicTheme.Dark/"v*; do
    [ -d "$_v" ] && esquemas="$esquemas${_v##*/} "
  done
  esquemas="$(printf '%s' "$esquemas" | tr ' ' '\n' | sed '/^$/d' | sort -V | tr '\n' ' ')"
  esquemas="${esquemas% }"
  cobertos="$(awk -F'\t' '$1=="esquema" && $2=="com.system76.CosmicTheme.Dark" {print $3; exit}' \
              "$MEOW_RAIZ/assets/contratos/cosmic.tsv" 2>/dev/null)"
  cobertos="${cobertos:-v1 v2}"
  case " $esquemas " in
    "  ") meow_pula "o COSMIC ainda não escreveu tema neste usuário — a captura vai criar" ;;
    " $cobertos ") meow_ok "esquema de tema: ${esquemas% } (as capturas cobrem $cobertos)" ;;
    " v1 ") meow_ok "esquema de tema: ${esquemas% } — COSMIC anterior ao v2; a captura cobre e a v2 fica inerte" ;;
    *) meow_aviso "esquema de tema desconhecido aqui: ${esquemas% }"
       meow_info "  as capturas deste repositório cobrem $cobertos (assets/contratos/cosmic.tsv)"
       avisos=$((avisos+1)) ;;
  esac

  if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ] || \
     { [ "${BASH_VERSINFO[0]}" = "4" ] && [ "${BASH_VERSINFO[1]:-0}" -lt 3 ]; }; then
    meow_erro "preciso de bash 4.3+ (aqui: ${BASH_VERSION:-?})"; fatal=1
  fi

  local -a COMANDOS=(
    "flock|base|util-linux|o lock que impede duas execuções ao mesmo tempo"
    "sed|base|sed|reescrita de arquivo em quase toda etapa"
    "awk|base|gawk|as contas do painel e da escala"
    "find|base|findutils|todo inventário de arquivo deste projeto"
    "mktemp|base|coreutils|toda escrita atômica"
    "sha256sum|base|coreutils|os manifestos de backup e o pino das fontes"
    "md5sum|base|coreutils|a ponte root — sem ele a senha é pedida em toda passagem"
    "cmp|base|diffutils|a comparação que decide se um arquivo mudou"
    "curl|etapa|curl|fontes, agente e semeadura de papel de parede"
    "tar|etapa|tar|a extração das faces Nerd"
    "git|etapa|git|o upstream pinado do Papirus"
    "python3|etapa|python3|a geração de temas, ícones e o migrar_conf"
    "rsvg-convert|etapa|librsvg2-bin|todo SVG que vira PNG"
    "convert|etapa|imagemagick|as capas de jogo e as folhas de contato"
    "gtk-update-icon-cache|etapa|libgtk-3-bin|o cache do tema de ícones"
    "fc-cache|etapa|fontconfig|o registro das fontes instaladas"
    "fc-list|etapa|fontconfig|descobrir se a face já veio de fora"
    "fc-match|etapa|fontconfig|escolher a mono do terminal"
    "unzip|etapa|unzip|o tema de agente"
    "xz|etapa|xz-utils|o tarball das fontes"
    "unxz|etapa|xz-utils|o tarball das fontes"
    "diff|etapa|diffutils|o que a tela mostra antes de escrever"
    "gsettings|etapa|libglib2.0-bin|as chaves de tema que o COSMIC ainda lê do GTK"
    "busctl|etapa|systemd|falar com o cosmic-settings-daemon"
    "systemctl|etapa|systemd|os relógios e gatilhos do carrossel e do mascote"
    "systemd-escape|etapa|systemd|o nome das unidades de caminho"
    "systemd-run|etapa|systemd|as tarefas que não podem morrer com o terminal"
    "pgrep|etapa|procps|saber se o cosmic-comp está vivo"
    "fuser|etapa|psmisc|saber quem segura um arquivo antes de trocá-lo"
    "update-desktop-database|etapa|desktop-file-utils|o menu reler os .desktop"
    "notify-send|etapa|libnotify-bin|as notificações de fim de etapa"
    "sudo|etapa|sudo|a ponte root e os .desktop de /usr/share"
    "flatpak|extra|flatpak|o applet de mídia e a vigia dos flatpaks"
    "fastfetch|extra|fastfetch|o mascote no lugar do logo, no terminal"
    "fzf|extra|fzf|a busca do Ritual no terminal"
    "btop|extra|btop|monitor com o tema"
    "batcat|extra|bat|o cat colorido com o tema"
    "pw-play|extra|pipewire-bin|o som de fim de instalação"
    "starship|extra|-|o prompt do terminal (a etapa do prompt o instala)"
    "cosmic-randr|extra|-|as telas e a escala (vem com o COSMIC)"
    "cosmic-term|extra|-|o terminal que este projeto arruma (vem com o COSMIC)"
  )
  local linha cmd nivel pacote para
  local faltam_apt="" n_faltam=0
  for linha in "${COMANDOS[@]}"; do
    IFS='|' read -r cmd nivel pacote para <<< "$linha"
    if [ "$cmd" = "starship" ]; then
      "$MEOW_RAIZ/scripts/prompt.sh" onde-starship >/dev/null 2>&1 && continue
    else
      meow_tem "$cmd" && continue
    fi
    n_faltam=$((n_faltam+1))
    case "$nivel" in
      base)  meow_erro "falta o básico: $cmd — $para"; fatal=1 ;;
      etapa) meow_pula "sem $cmd — $para"; avisos=$((avisos+1)) ;;
      extra) meow_info "sem $cmd — $para"; avisos=$((avisos+1)) ;;
    esac
    case "$pacote" in
      -) ;;
      *) case " $faltam_apt " in *" $pacote "*) ;; *) faltam_apt="$faltam_apt$pacote " ;; esac ;;
    esac
  done
  if [ -n "$faltam_apt" ]; then
    meow_info "  pacotes do apt que faltam: ${faltam_apt% }"
  fi
  [ "$n_faltam" = "0" ] && meow_ok "os ${#COMANDOS[@]} comandos do caminho de instalação estão aqui"

  if ! meow_tem cargo; then
    meow_pula "sem cargo — quem compila os applets instala o rust pelo rustup"
    avisos=$((avisos+1))
  fi

  local rota_lida=0 tem_rota=0
  if [ -r /proc/net/route ]; then
    rota_lida=1
    awk 'NR>1 && $2=="00000000" {achou=1} END {exit !achou}' /proc/net/route && tem_rota=1
  fi
  if [ "$tem_rota" = "0" ] && [ -r /proc/net/ipv6_route ]; then
    rota_lida=1
    awk '$1 ~ /^0+$/ && $2=="00" && $10 != "lo" {achou=1} END {exit !achou}' \
      /proc/net/ipv6_route && tem_rota=1
  fi
  if [ "$rota_lida" = "1" ] && [ "$tem_rota" = "0" ]; then
    meow_pula "sem rota padrão (IPv4 nem IPv6) — as etapas que baixam vão se pular"
    meow_info "  dependem de rede: fontes (faces Nerd), upstream (Papirus pinado),"
    meow_info "  agente (tema do Dracula), midia (applet compilado) e a semeadura"
    meow_info "  do carrossel. Todas devolvem \"pulado\", e o instalador termina em 0."
    avisos=$((avisos+1))
  fi

  if ! meow_tem apt-get; then
    meow_aviso "sem apt-get — a etapa de pacotes vai se pular"
    local _falta_aqui="$faltam_apt"
    [ -d /usr/share/icons/Papirus-Dark ] || _falta_aqui="${_falta_aqui}papirus-icon-theme "
    if [ -n "$_falta_aqui" ]; then
      meow_info "  instale à mão, pelo gerenciador desta distribuição: ${_falta_aqui% }"
    else
      meow_info "  não falta nada do que este projeto usa — a etapa se pula sem custo"
    fi
    avisos=$((avisos+1))
  fi

  if [ -n "${FLAVOR:-}" ] && [ -n "${ACCENT:-}" ] \
     && [ -z "$(meow_captura "${FLAVOR}-${ACCENT}")" ] \
     && { MEOW_PACK_DIR="${MEOW_PACK_DIR:-$(meow_pack_dir)}" \
            python3 "$MEOW_RAIZ/scripts/derivar_acento.py" --conferir "${FLAVOR}-${ACCENT}" >/dev/null 2>&1
          [ "$?" != "1" ]; }; then
    meow_aviso "não há captura para '${FLAVOR}-${ACCENT}' — o tema do COSMIC não vai ser aplicado"
    local prontas="" _c
    while IFS= read -r _c; do
      [ -n "$_c" ] || continue
      [ "$_c" = "original" ] && continue
      prontas="$prontas$_c "
    done < <(meow_capturas)
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

meow_precisa_root() {
  local -a motivos=()

  local -a pkg_faltam=()
  local b
  for b in rsvg-convert convert gtk-update-icon-cache python3 git btop batcat; do
    meow_tem "$b" || pkg_faltam+=("$b")
  done
  [ -d /usr/share/icons/Papirus-Dark ] || pkg_faltam+=(papirus-icon-theme)
  python3 -I -c 'import numpy' 2>/dev/null || pkg_faltam+=(python3-numpy)
  [ ${#pkg_faltam[@]} -gt 0 ] && motivos+=("instalar pacotes: ${pkg_faltam[*]}")

  if ! meow_ponte_viva; then
    [ "${LANCADOR_SISTEMA:-nao}" = "sim" ] && \
      motivos+=("marcar .desktop em /usr/share/applications (esconder/renomear)")
    [ -d /var/lib/cosmic-greeter ] && \
      motivos+=("aplicar o tema na tela de login em /var/lib/cosmic-greeter")
  fi

  [ ${#motivos[@]} -eq 0 ] && return 0
  sudo -n true 2>/dev/null && return 0
  meow_tem sudo || { meow_pula "sem sudo — essas etapas ficam de fora, o resto vai"; return 0; }

  meow_info "algumas etapas precisam de root. São estas, e só estas:"
  local m; for m in "${motivos[@]}"; do printf '        %s\n' "$m"; done
  if meow_seco; then
    meow_pula "ensaio — não vou pedir a senha"
  elif [ -t 0 ]; then
    sudo -v || meow_pula "sem sudo — essas etapas ficam de fora, o resto vai"
  else
    meow_pula "sem terminal para pedir a senha — essas etapas ficam de fora"
  fi
  return 0
}

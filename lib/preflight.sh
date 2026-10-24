#!/usr/bin/env bash
# preflight.sh — a única fase que SÓ OLHA.
#
# Roda antes do lock e antes da primeira escrita.
#
# O instalador escrevia o meow.conf e a CLI ANTES de descobrir que faltava o
# apt, que o desktop não era o COSMIC ou que o esquema de tema era outro.
#
#   0 = pode ir   ·   1 = vai com pedaços de fora   ·   2 = não dá.
#   Só o 2 aborta — cada etapa continua sabendo se pular sozinha.

meow_preflight() {
  local fatal=0 avisos=0
  meow_passo "Pré-voo"

  # 1. ROOT NÃO. A guarda também está no main(), que é onde ela recusa mais
  #    cedo; aqui ela fica porque o pré-voo é chamado por outros caminhos.
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
  #
  # A lista agora é comparada INTEIRA contra a do contrato
  # (`assets/contratos/cosmic.tsv`, a linha `esquema` do `CosmicTheme.Dark`).
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
    # O comentário logo acima diz "as capturas deste repositório são v1+v2" e o
    # código chamava metade disso de "desconhecido".
    " v1 ") meow_ok "esquema de tema: ${esquemas% } — COSMIC anterior ao v2; a captura cobre e a v2 fica inerte" ;;
    *) meow_aviso "esquema de tema desconhecido aqui: ${esquemas% }"
       meow_info "  as capturas deste repositório cobrem $cobertos (assets/contratos/cosmic.tsv)"
       avisos=$((avisos+1)) ;;
  esac

  # 4. bash. O instalador usa `declare -A`, que é 4.0; o 4.3 é o piso do nameref,
  #    e é o piso que vale a pena cobrar de uma vez.
  if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ] || \
     { [ "${BASH_VERSINFO[0]}" = "4" ] && [ "${BASH_VERSINFO[1]:-0}" -lt 3 ]; }; then
    meow_erro "preciso de bash 4.3+ (aqui: ${BASH_VERSION:-?})"; fatal=1
  fi

  # Dois deles davam o pior tipo de defeito, o SILENCIOSO E ETERNO:
  #
  # · sem `md5sum`, a comparação da ponte root (`install.sh`, `$md5_quer`) lê
  # string vazia, nunca bate com o `regra_md5=` que a ponte devolve, e a etapa
  # REINSTALA a ponte — pedindo senha — em TODA passagem, para sempre, sem nada
  # acusar; · sem `cmp`, o `cmp -s` falha e todo arquivo comparado por ele é
  # dado como divergente, com o mesmo efeito.
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
    # O `magick` (ImageMagick 7) NÃO tem linha própria: ele é ALTERNATIVA a
    # este `convert`, e não requisito — `wallpaper.sh:490` prefere um e cai no
    # outro.
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
    "systemctl|etapa|systemd|os relógios e gatilhos do carrossel e do gato"
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
    "btop|extra|btop|monitor vestido pelo tema"
    "batcat|extra|bat|o cat colorido vestido pelo tema"
    "pw-play|extra|pipewire-bin|o som de fim de instalação"
    "starship|extra|-|o prompt do terminal (instala-se pelo site do projeto)"
    "cosmic-randr|extra|-|as telas e a escala (vem com o COSMIC)"
    "cosmic-term|extra|-|o terminal que este projeto veste (vem com o COSMIC)"
  )
  local linha cmd nivel pacote para
  local faltam_apt="" n_faltam=0
  for linha in "${COMANDOS[@]}"; do
    IFS='|' read -r cmd nivel pacote para <<< "$linha"
    # O STARSHIP TEM DONO, E É A ETAPA DO PROMPT — revisão da P54. Ele mora
    # também em ~/.cargo/bin, que o PATH do systemd de usuário não tem; o
    # `meow_tem` daqui dizia «sem starship» na mesma passagem em que a etapa o
    # achava. A pergunta vai para a regra de lá (`prompt.sh onde-starship`).
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
    # Pacote repetido entra UMA vez: `fontconfig` cobre três comandos e
    # `systemd` cobre quatro, e uma linha de conserto que repete pacote parece
    # gerada por quem não conferiu.
    case "$pacote" in
      -) ;;
      *) case " $faltam_apt " in *" $pacote "*) ;; *) faltam_apt="$faltam_apt$pacote " ;; esac ;;
    esac
  done
  # [P82, 15/10/2026: dava a linha do `sudo apt install` para copiar. Os da
  #   etapa de pacotes o instalador põe sozinho, pela ponte ou pelo sudo; aqui
  #   fica o estado.]
  if [ -n "$faltam_apt" ]; then
    meow_info "  pacotes do apt que faltam: ${faltam_apt% }"
  fi
  [ "$n_faltam" = "0" ] && meow_ok "os ${#COMANDOS[@]} comandos do caminho de instalação estão aqui"

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
    # [P82: dizia «rustup toolchain install stable, e rode o install.sh de
    #   novo». Quem compila os applets instala o rust pelo rustup sozinho.]
    meow_pula "sem cargo — quem compila os applets instala o rust pelo rustup"
    avisos=$((avisos+1))
  fi

  # 6c. REDE. O pré-voo NÃO ABRE REDE — o cabeçalho deste arquivo promete isso,
  #     e um `curl` de teste numa fase de diagnóstico é a mesma quebra de
  #     promessa que o `flatpak info` foi. O que dá para saber sem mandar um
  #     pacote é se existe ROTA PADRÃO, e isso está em arquivo.
  #
  #     Rota não é garantia de internet (portal de hotel tem rota e não tem
  #     saída), e por isso o texto diz "sem rota padrão", que é o que foi
  #     medido, e não "sem internet", que seria um palpite. As duas etapas que
  #     baixam devolvem 3 desde 21/09/2026 e caem em "pulados" — o instalador
  #     termina em 0 de qualquer jeito.
  #
  #     O IPv6 TAMBÉM É REDE — 21/09/2026
  #       A primeira versão desta guarda lia só `/proc/net/route`, que é a
  #       tabela IPv4. Numa máquina IPv6-only ela não acha destino `00000000`
  #       nenhum e o pré-voo dizia "sem rota padrão" com a rota funcionando —
  #       um aviso falso é exatamente o que faz pré-voo virar ruído. O segundo
  #       arquivo é `/proc/net/ipv6_route`, e ali a rota padrão é destino todo
  #       zero com prefixo `00`.
  #
  #       O `$10 != "lo"` NÃO É ENFEITE. Toda máquina com IPv6 ligado carrega
  #       uma rota padrão de REJEIÇÃO no `lo` — conferida no disco em
  #       21/09/2026, a linha
  #           00000000000000000000000000000000 00 ... 00200200 lo
  #       existe mesmo sem nenhuma interface configurada. Sem excluí-la, o teste
  #       responderia "há rota" em TODA máquina, que é o oposto do defeito que
  #       ele veio consertar. Medido com arquivos sintéticos: só essa linha do
  #       `lo` -> "sem rota padrão"; com a default de uma interface -> silêncio.
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
  # Sem nenhum dos dois arquivos legíveis não há medição, e um palpite aqui
  # seria o mesmo aviso falso com outra causa: melhor calar.
  if [ "$rota_lida" = "1" ] && [ "$tem_rota" = "0" ]; then
    meow_pula "sem rota padrão (IPv4 nem IPv6) — as etapas que baixam vão se pular"
    meow_info "  dependem de rede: fontes (faces Nerd), upstream (Papirus pinado),"
    meow_info "  agente (tema do Dracula), midia (applet compilado) e a semeadura"
    meow_info "  do carrossel. Todas devolvem \"pulado\", e o instalador termina em 0."
    avisos=$((avisos+1))
  fi

  # 7. Gerenciador de pacotes. Só AVISA: `etapa_pacotes` fala apt, e fingir que
  #    fala dnf/pacman sem escrever os comandos é pior do que não falar.
  #
  #    A LISTA AQUI TAMBÉM SAI DA TABELA — 21/09/2026. Eram oito pacotes
  #    digitados na string (`librsvg2-bin imagemagick libgtk-3-bin python3 git
  #    btop bat papirus-icon-theme`), e ela dizia para instalar os oito mesmo
  #    numa máquina que já tinha sete. Agora manda instalar só o que FALTA, com
  #    os nomes que o laço de cima já apurou, e diz quando não falta nada.
  #    O Papirus entra à parte porque é o único que não tem binário para testar:
  #    quem responde por ele é o diretório do tema.
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

  # 8. Existe captura para o que o meow.conf pediu? Descobrir isso na etapa 5,
  #    depois de escrever a CLI e instalar pacotes, é descobrir tarde.
  #
  #    O PAR QUE SE DERIVA NÃO É AVISO — 24/09/2026, sprint P48 (achado 31)
  #      Desde a P48 o acento sem fotografia ganha captura na etapa `gerar`
  #      (`scripts/derivar_acento.py`, a partir da captura do mesmo flavor), e
  #      a etapa `tema` o aplica. Sem esta pergunta, o `dracula-pink` abria o
  #      instalador com "o tema do COSMIC não vai ser aplicado" e terminava com
  #      ele aplicado: a mesma tela dizendo as duas coisas. O `--conferir` sai 1
  #      quando derivaria (desde a P59, também o flavor sem foto, de outro do
  #      mesmo lado), e é só esse caso que deixa de ser aviso; o 3 (o par sem
  #      captura daquele lado ao alcance do pack, ou sem uma que se reproduza)
  #      continua sendo, com a lista de sempre. [Dizia «flavor que nunca foi
  #      fotografado» até a P67 (25/09/2026).]
  if [ -n "${FLAVOR:-}" ] && [ -n "${ACCENT:-}" ] \
     && [ -z "$(meow_captura "${FLAVOR}-${ACCENT}")" ] \
     && { MEOW_PACK_DIR="${MEOW_PACK_DIR:-$(meow_pack_dir)}" \
            python3 "$MEOW_RAIZ/scripts/derivar_acento.py" --conferir "${FLAVOR}-${ACCENT}" >/dev/null 2>&1
          [ "$?" != "1" ]; }; then
    meow_aviso "não há captura para '${FLAVOR}-${ACCENT}' — o tema do COSMIC não vai ser aplicado"
    # `original` fica de fora da lista: é reset de fábrica DESTA máquina, não uma
    # variante que alguém escolheria no meow.conf.
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
  # O numpy entra aqui pelo mesmo motivo que os outros: se ele falta, a etapa de
  # pacotes vai pedir sudo, e o pré-voo existe para que a senha seja pedida UMA
  # vez, antes de tudo, e não no meio de cinquenta e oito etapas.
  python3 -I -c 'import numpy' 2>/dev/null || pkg_faltam+=(python3-numpy)
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

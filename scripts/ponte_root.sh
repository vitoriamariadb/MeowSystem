#!/usr/bin/env bash
# ponte_root.sh — o braço root do MeowSystem, e a razão de a senha ser pedida
# UMA vez.
#
# Fonte-de-verdade: MeowSystem/scripts/ponte_root.sh
# Destino:          /usr/local/lib/meowsystem/ponte_root.sh  (0755, root:root)
# Regra:            /etc/sudoers.d/49-meowsystem-ponte       (0440, root:root)
# Quem instala:     install.sh, `etapa_ponte_root` — e é ele que pede a senha
#
# ============================================================================
# DE ONDE ISTO VEIO
# ============================================================================
# Ela, 08/09/2026: *"não conseguimos de alguma forma usar sudo só na instalar e
# criar um perfil naquele conf.d ... aquele que só preciso uma vez e fica lá
# registrado pra sempre? pode alterar o nosso install pra garantir o máximo de
# conforto pro user nesse sentido?"*
#
# O incômodo era real e media-se: `meow doctor --consertar` recusava consertar
# TRÊS itens (`ocultar`, `absolutos`, `lancadorapt`) com a mesma frase — "o
# conserto usa sudo, e o doctor não usa" —, e os três botões de senha do painel
# não tinham como pedir senha nenhuma, porque o painel roda sem terminal. O
# `full-upgrade` de 08/09 derrubou o hook do apt e o auto-reparo ficou olhando.
#
# ============================================================================
# POR QUE UMA PONTE, E NÃO `NOPASSWD` NOS COMANDOS QUE O PROJETO USA
# ============================================================================
# Porque não existe regra estreita para `install`. O que o projeto precisa é
# escrever `.desktop` em `/usr/share/applications`, e a regra
#
#     <usuário> ALL=(root) NOPASSWD: /usr/bin/install -m 644 * *
#
# é `NOPASSWD: ALL` com outro nome: o segundo `*` é qualquer destino, e escrever
# qualquer arquivo como root é ser root. O mesmo vale para `rm`, `cp` e `tee`.
#
# A saída é a que esta máquina JÁ usa para o Bluetooth do Hefesto
# (`/etc/sudoers.d/49-hefesto-bt-ponte`, 22/08/2026): um programa de root que
# implementa um conjunto FECHADO de verbos, com os destinos cravados aqui
# dentro, e uma regra de sudo que libera só ele.
#
# NENHUM VERBO TEM ARGUMENTO, e isso é a parte que fecha a porta. O nome do
# arquivo e o conteúdo entram por STDIN — a mesma disciplina que a ponte do
# Hefesto documenta ("o nome novo do adaptador entra pelo STDIN, não por argv,
# justamente para que não sobre argumento livre a casar"). Com zero argumento,
# a regra de sudo não tem um único curinga, e não há o que forjar.
#
# ============================================================================
# O QUE ESTA PONTE NÃO FAZ, DE PROPÓSITO
# ============================================================================
#   · não se instala nem se atualiza. Trocar o arquivo em `/usr/local/lib` e a
#     regra em `/etc/sudoers.d` continua pedindo a senha, no `install.sh`. Uma
#     ponte que pudesse regravar a si mesma seria uma ponte que qualquer coisa
#     rodando como ela reescreve para fazer outra coisa;
#   · não recebe caminho de origem. Todo destino é literal neste arquivo;
#   · não instala pacote por nome livre e não roda `.deb`. O `atualizar` é
#     `full-upgrade` dos repositórios já configurados, e o `pacotes` (P75,
#     09/10/2026) instala só nomes de uma lista LITERAL aqui dentro — ver o
#     bloco dele;
#   · não apaga nada fora dos dois caminhos do hook de apt e do da completion
#     do zsh (este desde a P47, 24/09/2026), das três chaves de tema do
#     override global do Flatpak que apontam para tema que não existe, e dos
set -euo pipefail
umask 022
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

APLICATIVOS=/usr/share/applications
GREETER_HOME=/var/lib/cosmic-greeter
GREETER_CONF="$GREETER_HOME/.config/cosmic"
GREETER_DONO=cosmic-greeter
HOOK=/etc/apt/apt.conf.d/99-meow-lancador
WRAPPER=/usr/local/sbin/meow-lancador-apt.sh
PERFIL=/usr/local/lib/meowsystem/perfil
RESERVA=/usr/local/lib/meowsystem/reserva
PECAS=/usr/local/lib/meowsystem/reserva-pecas.sha256
COMPLETION=/usr/local/share/zsh/site-functions/_meow
REGRA=/etc/sudoers.d/49-meowsystem-ponte
PONTE=/usr/local/lib/meowsystem/ponte_root.sh
POLKIT=/etc/polkit-1/rules.d/49-meowsystem-ponte-reparo.rules
FLATPAK_GLOBAL=/var/lib/flatpak/overrides/global
LIBRE_REMOVIDOS=/var/lib/meowsystem/libreoffice-removidos
USR_SHARE=/usr/share
SONS_ORIGINAIS=/var/lib/meowsystem/sons
COSMIC_COMP=/usr/bin/cosmic-comp
DPKG_INFO=/var/lib/dpkg/info

morrer() { printf 'ponte_root: %s\n' "$1" >&2; exit "${2:-2}"; }

anotar() {
  logger -t meowsystem-ponte -p auth.notice -- "$*" 2>/dev/null || true
}

conferir_desktop() {
  local nome="$1"
  case "$nome" in
    *[!A-Za-z0-9._+-]*) morrer "nome com caractere proibido" ;;
    .*|*/*|"")          morrer "nome inválido" ;;
    *.desktop)          ;;
    *)                  morrer "o nome tem de terminar em .desktop" ;;
  esac
  [ "${#nome}" -le 128 ] || morrer "nome comprido demais"
  [ -f "$APLICATIVOS/$nome" ] || morrer "$APLICATIVOS/$nome não existe — esta ponte edita, não cria" 3
}

do_libreoffice() {
  case "$1" in
    libreoffice*|python3-uno|ure|ure-java|uno-libs-private|libuno-*|libunoloader-java) return 0 ;;
  esac
  return 1
}

libreoffice_instalados() {
  dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'libreoffice*' 2>/dev/null \
    | awk '$1 ~ /^.[ic]/ && $2 ~ /^libreoffice/ { print $2 }'
}

som_destino() {
  case "$1" in
    power-plug|power-unplug|battery-caution|complete) printf '%s' "$USR_SHARE/sounds/Pop/stereo/notification/$1.oga" ;;
    power-unplug-battery-low|battery-low)             printf '%s' "$USR_SHARE/sounds/Pop/stereo/alert/$1.oga" ;;
    dialog-warning)                                   printf '%s' "$USR_SHARE/sounds/freedesktop/stereo/dialog-warning.oga" ;;
    *) return 1 ;;
  esac
}

som_evento() {
  local evento
  IFS= read -r evento || morrer "stdin vazio"
  som_destino "$evento" >/dev/null || morrer "evento fora da lista desta ponte: $evento"
  printf '%s' "$evento"
}

da_reserva() {
  local nome="$1" tmp="$2" quer
  [ -d "$RESERVA" ] && [ -f "$PECAS" ] || morrer "a reserva não tem $nome: entra no próximo «Instalar tudo»" 3
  [ "$(wc -l < "$PECAS")" = 3 ] || morrer "a lista da reserva não confere" 4
  quer="$(awk -v n="$nome" 'NF == 2 && $2 == n { print $1 }' "$PECAS")"
  [ "${#quer}" = 64 ] || morrer "a lista da reserva não confere" 4
  cat "$RESERVA/$nome" > "$tmp" 2>/dev/null || morrer "a reserva não tem $nome" 4
  [ "$(sha256sum < "$tmp" | cut -d' ' -f1)" = "$quer" ] || morrer "a reserva não confere com o sha256: $nome" 4
}

verbo="${1:-}"
[ "$#" -le 1 ] || morrer "esta ponte não aceita argumento — o dado entra por stdin"

case "$verbo" in

desktop)
  IFS= read -r nome || morrer "stdin vazio"
  conferir_desktop "$nome"
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  cat > "$tmp"
  [ -s "$tmp" ] || morrer "conteúdo vazio"
  head -c 4096 "$tmp" | grep -q '^\[Desktop Entry\]' || morrer "isto não é um .desktop"
  if cmp -s "$tmp" "$APLICATIVOS/$nome"; then exit 0; fi
  install -m 644 -o root -g root "$tmp" "$APLICATIVOS/$nome" || morrer "não consegui escrever"
  anotar "desktop $nome"
  ;;

desktop-banco)
  command -v update-desktop-database >/dev/null 2>&1 || exit 0
  update-desktop-database "$APLICATIVOS" 2>/dev/null || true
  ;;

greeter-ver)
  [ -d "$GREETER_CONF" ] || exit 3
  cd "$GREETER_CONF" || exit 3
  find . -mindepth 1 -type f -printf '%P\n' | sort | while IFS= read -r rel; do
    printf '%s  %s\n' "$(md5sum < "$rel" | cut -d' ' -f1)" "$rel"
  done
  ;;

greeter-aplicar)
  [ -d "$GREETER_HOME" ] || exit 3
  id "$GREETER_DONO" >/dev/null 2>&1 || morrer "o usuário $GREETER_DONO não existe" 3
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  tar -x -C "$tmp" --no-same-owner -f - || morrer "tar recusado: o que chegou pelo stdin não se extrai"
  [ -z "$(find "$tmp" -mindepth 1 -type l -print -quit)" ] || morrer "link simbólico no tar"
  [ -z "$(find "$tmp" -mindepth 1 ! -type f ! -type d -print -quit)" ] || morrer "só arquivo e pasta no tar"
  if ( cd "$tmp" && find . -mindepth 1 -printf '%P\n' ) | grep -qE '(^|/)\.\.(/|$)'; then
    morrer "caminho com .. no tar"
  fi
  for alvo in "$GREETER_HOME/.config" "$GREETER_CONF"; do
    [ ! -L "$alvo" ] || morrer "link simbólico no destino: $alvo"
  done
  if [ -d "$GREETER_CONF" ] && [ -n "$(find "$GREETER_CONF" -mindepth 1 -type l -print -quit)" ]; then
    morrer "link simbólico no destino, dentro de $GREETER_CONF"
  fi
  mkdir -p "$GREETER_CONF"
  cp -a "$tmp/." "$GREETER_CONF/"
  chown -R "$GREETER_DONO:$GREETER_DONO" "$GREETER_HOME/.config"
  chmod -R u=rwX,go= "$GREETER_HOME/.config"
  anotar "greeter-aplicar"
  ;;

apt-hook-instalar)
  tmp_w="$(mktemp)"; tmp_h="$(mktemp)"; trap 'rm -f "$tmp_w" "$tmp_h"' EXIT
  da_reserva meow-lancador-apt.sh "$tmp_w"
  da_reserva 99-meow-lancador "$tmp_h"
  if cmp -s "$tmp_w" "$WRAPPER" && cmp -s "$tmp_h" "$HOOK"; then exit 0; fi
  install -m 755 -o root -g root "$tmp_w" "$WRAPPER" || morrer "não consegui instalar o wrapper"
  install -m 644 -o root -g root "$tmp_h" "$HOOK" || morrer "não consegui instalar o hook"
  anotar "apt-hook-instalar da reserva"
  ;;

apt-hook-remover)
  rm -f "$HOOK" "$WRAPPER"
  anotar "apt-hook-remover"
  ;;

completion-instalar)
  [ -d "${COMPLETION%/*}" ] || morrer "${COMPLETION%/*} não existe" 3
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  da_reserva _meow "$tmp"
  if cmp -s "$tmp" "$COMPLETION"; then exit 0; fi
  install -m 644 -o root -g root "$tmp" "$COMPLETION" || morrer "não consegui instalar $COMPLETION"
  anotar "completion-instalar da reserva"
  ;;

completion-remover)
  rm -f "$COMPLETION"
  anotar "completion-remover"
  ;;

flatpak-global-limpar)
  [ -f "$FLATPAK_GLOBAL" ] || exit 0
  lar=""
  [ -r "$PERFIL" ] && lar="$(sed -n 's/^lar=//p' "$PERFIL" | head -n1)"
  case "$lar" in ''|/*) ;; *) morrer "lar inválido no perfil" ;; esac
  tmp="$(mktemp)"; pedidos="$(mktemp)"; trap 'rm -f "$tmp" "$pedidos"' EXIT
  while IFS= read -r linha || [ -n "${linha:-}" ]; do
    [ -n "$linha" ] || continue
    chave="${linha%%=*}"; valor="${linha#*=}"
    case "$chave" in ICON_THEME|XCURSOR_THEME|GTK_THEME) ;; *) morrer "chave fora da lista desta ponte: $chave" ;; esac
    case "$valor" in ''|.*|*[!A-Za-z0-9._+-]*) morrer "nome de tema inválido" ;; esac
    [ "${#valor}" -le 128 ] || morrer "nome de tema comprido demais"
    grep -qxF -- "$chave=$valor" "$FLATPAK_GLOBAL" || continue
    existe=0
    for raiz in "$USR_SHARE/icons" "$USR_SHARE/themes" \
                ${lar:+"$lar/.local/share/icons" "$lar/.local/share/themes" "$lar/.icons" "$lar/.themes"}; do
      [ -d "$raiz/$valor" ] && existe=1
    done
    [ "$existe" = "1" ] || printf '%s=%s\n' "$chave" "$valor" >> "$pedidos"
  done
  [ -s "$pedidos" ] || exit 0
  { grep -vxF -f "$pedidos" "$FLATPAK_GLOBAL" || true; } | awk '
    function solta() { if (cab != "" && n > 0) printf "%s", buf; cab = ""; buf = ""; n = 0 }
    /^\[/ { solta(); cab = $0; buf = $0 "\n"; next }
    cab == "" { print; next }
    NF { buf = buf $0 "\n"; n++; next }
    { buf = buf "\n" }
    END { solta() }' > "$tmp"
  if grep -q . "$tmp"; then
    install -m 644 -o root -g root "$tmp" "$FLATPAK_GLOBAL" || morrer "não consegui escrever $FLATPAK_GLOBAL"
  else
    rm -f "$FLATPAK_GLOBAL"
  fi
  anotar "flatpak-global-limpar $(tr '\n' ' ' < "$pedidos")"
  ;;

libreoffice-remover)
  mapfile -t pacotes < <(libreoffice_instalados)
  [ "${#pacotes[@]}" -gt 0 ] || exit 0
  export DEBIAN_FRONTEND=noninteractive
  simulado="$(apt-get -s purge "${pacotes[@]}" 2>/dev/null)" || morrer "o apt não simulou a remoção"
  mapfile -t saem < <(printf '%s\n' "$simulado" | awk '/^(Purg|Remv) / { sub(/:.*/, "", $2); print $2 }')
  faltam=""
  for p in "${pacotes[@]}"; do
    printf '%s\n' "${saem[@]}" | grep -qxF -- "$p" || faltam+="$p "
  done
  [ -z "$faltam" ] || morrer "o plano do apt não tira $faltam: não toco em nada"
  outros=""
  for p in "${saem[@]}"; do do_libreoffice "$p" || outros+="$p "; done
  [ -z "$outros" ] || morrer "o apt tiraria junto o que não é do LibreOffice ($outros): não toco em nada"
  lista="$(printf '%s\n' "${pacotes[@]}" "${saem[@]}" | sort -u)"
  [ -f "$LIBRE_REMOVIDOS" ] && lista="$(printf '%s\n%s\n' "$lista" "$(cat "$LIBRE_REMOVIDOS")" | grep . | sort -u)"
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  printf '%s\n' "$lista" > "$tmp"
  install -d -m 755 -o root -g root "${LIBRE_REMOVIDOS%/*}" || morrer "não consegui criar ${LIBRE_REMOVIDOS%/*}"
  install -m 644 -o root -g root "$tmp" "$LIBRE_REMOVIDOS" || morrer "não consegui gravar $LIBRE_REMOVIDOS"
  anotar "libreoffice-remover ${#saem[@]} pacotes"
  printf '%s\n' "${pacotes[@]}" "${saem[@]}" | sort -u
  apt-get purge -y "${pacotes[@]}" >&2 || exit 2
  ;;

libreoffice-devolver)
  [ -f "$LIBRE_REMOVIDOS" ] && [ ! -L "$LIBRE_REMOVIDOS" ] || morrer "nada removido pelo MeowSystem a devolver" 3
  pedidos=()
  while IFS= read -r nome || [ -n "${nome:-}" ]; do
    [ -n "$nome" ] || continue
    case "$nome" in *[!a-z0-9.+-]*) morrer "nome de pacote inválido" ;; esac
    do_libreoffice "$nome" || morrer "pacote fora do LibreOffice: $nome"
    pedidos+=("$nome")
  done < "$LIBRE_REMOVIDOS"
  [ "${#pedidos[@]}" -gt 0 ] || morrer "a lista do que saiu está vazia"
  export DEBIAN_FRONTEND=noninteractive
  anotar "libreoffice-devolver ${#pedidos[@]} pacotes"
  apt-get install -y --no-install-recommends "${pedidos[@]}" || exit 2
  rm -f "$LIBRE_REMOVIDOS"
  ;;

som)
  evento="$(som_evento)"
  destino="$(som_destino "$evento")"
  [ -f "$destino" ] && [ ! -L "$destino" ] || morrer "$destino não existe — esta ponte troca o som, não cria" 3
  tmp="$(mktemp)"; tmp_o="$(mktemp)"; tmp_s="$(mktemp)"; trap 'rm -f "$tmp" "$tmp_o" "$tmp_s"' EXIT
  head -c 1048577 > "$tmp"
  [ -s "$tmp" ] && [ "$(stat -c %s "$tmp")" -le 1048576 ] || morrer "som vazio ou grande demais"
  [ "$(head -c 4 "$tmp")" = "OggS" ] || morrer "isto não é um Ogg"
  novo="$(sha256sum < "$tmp" | cut -d' ' -f1)"
  atual="$(sha256sum < "$destino" | cut -d' ' -f1)"
  [ "$atual" != "$novo" ] || exit 0
  nosso="$(cat "$SONS_ORIGINAIS/$evento.sha256" 2>/dev/null || true)"
  install -d -m 755 -o root -g root "$SONS_ORIGINAIS" || morrer "não consegui criar $SONS_ORIGINAIS"
  if [ "$atual" != "$nosso" ]; then
    cat "$destino" > "$tmp_o"
    install -m 644 -o root -g root "$tmp_o" "$SONS_ORIGINAIS/$evento.original" || morrer "não consegui guardar o som de fábrica"
  fi
  install -m 644 -o root -g root "$tmp" "$destino" || morrer "não consegui escrever $destino"
  printf '%s\n' "$novo" > "$tmp_s"
  install -m 644 -o root -g root "$tmp_s" "$SONS_ORIGINAIS/$evento.sha256" || morrer "não consegui anotar o som"
  anotar "som $evento"
  ;;

som-padrao)
  evento="$(som_evento)"
  destino="$(som_destino "$evento")"
  original="$SONS_ORIGINAIS/$evento.original"
  [ -f "$original" ] && [ ! -L "$original" ] || exit 0
  [ -f "$destino" ] && [ ! -L "$destino" ] || morrer "$destino não existe" 3
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  cat "$original" > "$tmp"
  [ "$(head -c 4 "$tmp")" = "OggS" ] || morrer "o som de fábrica guardado não confere"
  install -m 644 -o root -g root "$tmp" "$destino" || morrer "não consegui escrever $destino"
  rm -f "$original" "$SONS_ORIGINAIS/$evento.sha256"
  anotar "som-padrao $evento"
  ;;

atualizar)
  export DEBIAN_FRONTEND=noninteractive
  anotar "atualizar"
  apt update || exit 2
  apt full-upgrade -y -o Dpkg::Options::=--force-confold || exit 2
  ;;

pacotes)
  PERMITIDOS=" librsvg2-bin imagemagick libgtk-3-bin python3 git btop bat papirus-icon-theme python3-numpy curl xz-utils unzip pop-fonts build-essential pkg-config libxkbcommon-dev libwayland-dev libdbus-1-dev software-properties-common "
  pedidos=()
  while IFS= read -r nome || [ -n "${nome:-}" ]; do
    [ -n "$nome" ] || continue
    case "$PERMITIDOS" in
      *" $nome "*) pedidos+=("$nome") ;;
      *) morrer "pacote fora da lista desta ponte: $nome" ;;
    esac
  done
  [ "${#pedidos[@]}" -gt 0 ] || morrer "stdin vazio"
  export DEBIAN_FRONTEND=noninteractive
  anotar "pacotes ${pedidos[*]}"
  apt-get install -y --no-install-recommends "${pedidos[@]}" || exit 2
  ;;

cosmic-comp-de-fabrica)
  [ "$(dpkg-query -W -f='${db:Status-Status}' cosmic-comp 2>/dev/null)" = installed ] || morrer "o cosmic-comp não está instalado" 3
  soma="$(awk '$2 == "usr/bin/cosmic-comp" { print $1 }' "$DPKG_INFO/cosmic-comp.md5sums" 2>/dev/null || true)"
  [ "${#soma}" = 32 ] || morrer "o dpkg não tem a soma de $COSMIC_COMP" 4
  [ "$(md5sum < "$COSMIC_COMP" 2>/dev/null | cut -d' ' -f1)" = "$soma" ] && exit 0
  export DEBIAN_FRONTEND=noninteractive
  anotar "cosmic-comp-de-fabrica"
  apt-get install -y --reinstall cosmic-comp >&2 || exit 2
  [ "$(md5sum < "$COSMIC_COMP" | cut -d' ' -f1)" = "$soma" ] || morrer "o $COSMIC_COMP ainda não bate com o pacote depois de reinstalar"
  printf 'reinstalado\n'
  ;;

limpar)
  export DEBIAN_FRONTEND=noninteractive
  anotar "limpar"
  apt autoclean -y || true
  apt autoremove -y -o Dpkg::Options::=--force-confold || true
  apt clean || true
  ;;

estado)
  printf 'ponte=%s\n' "$([ -x "$PONTE" ] && echo sim || echo nao)"
  printf 'regra=%s\n' "$([ -f "$REGRA" ] && echo sim || echo nao)"
  printf 'regra_md5=%s\n' "$(md5sum < "$REGRA" 2>/dev/null | cut -d' ' -f1)"
  printf 'regra_sha256=%s\n' "$({ sha256sum < "$REGRA"; } 2>/dev/null | cut -d' ' -f1)"
  printf 'polkit_sha256=%s\n' "$({ sha256sum < "$POLKIT"; } 2>/dev/null | cut -d' ' -f1)"
  printf 'perfil=%s\n' "$([ -r "$PERFIL" ] && echo sim || echo nao)"
  printf 'raiz=%s\n'  "$(sed -n 's/^raiz=//p' "$PERFIL" 2>/dev/null || printf '(nenhuma)')"
  printf 'hook=%s\n'  "$([ -f "$HOOK" ] && [ -x "$WRAPPER" ] && echo sim || echo nao)"
  printf 'versao=%s\n' "$(md5sum < "$PONTE" 2>/dev/null | cut -d' ' -f1)"
  ;;

regra-sudo)
  quem="${SUDO_USER:-${USER:-}}"
  case "$quem" in
    ''|root)            morrer "não sei para quem escrever a regra" ;;
    *[!a-z0-9._-]*)     morrer "nome de usuário inesperado" ;;
  esac
  cat <<REGRA_FIM
# /etc/sudoers.d/49-meowsystem-ponte — gerado por
# $PONTE regra-sudo
#
# O braço root do MeowSystem (decisão dela, 08/09/2026: "usar sudo só na
# instalação e criar um perfil naquele conf.d"). NÃO editar à mão: o install
# regrava, e \`PONTE_ROOT="nao"\` no meow.conf apaga.
#
# A regra é estreita de propósito: caminho absoluto, verbos nomeados um a um, e
# NENHUM curinga — porque nenhum verbo da ponte aceita argumento. O nome do
# arquivo e o conteúdo entram pelo STDIN, exatamente como na ponte do Hefesto ao
# lado, para que não sobre argumento livre a casar aqui.
Cmnd_Alias MEOWSYSTEM_PONTE = \\
    $PONTE desktop, \\
    $PONTE desktop-banco, \\
    $PONTE greeter-ver, \\
    $PONTE greeter-aplicar, \\
    $PONTE apt-hook-instalar, \\
    $PONTE apt-hook-remover, \\
    $PONTE completion-instalar, \\
    $PONTE completion-remover, \\
    $PONTE flatpak-global-limpar, \\
    $PONTE libreoffice-remover, \\
    $PONTE libreoffice-devolver, \\
    $PONTE som, \\
    $PONTE som-padrao, \\
    $PONTE atualizar, \\
    $PONTE pacotes, \\
    $PONTE limpar, \\
    $PONTE cosmic-comp-de-fabrica, \\
    $PONTE estado

$quem ALL=(root) NOPASSWD: MEOWSYSTEM_PONTE
REGRA_FIM
  ;;

''|-h|--help|ajuda)
  sed -n '2,60p' "$0"
  printf '\nverbos: desktop · desktop-banco · greeter-ver · greeter-aplicar ·\n'
  printf '        apt-hook-instalar · apt-hook-remover · completion-instalar ·\n'
  printf '        completion-remover · flatpak-global-limpar · libreoffice-remover ·\n'
  printf '        libreoffice-devolver · som · som-padrao · atualizar · pacotes ·\n'
  printf '        limpar · cosmic-comp-de-fabrica · estado ·\n'
  printf '        regra-sudo\n'
  ;;

*) morrer "verbo desconhecido: $verbo" ;;
esac
exit 0

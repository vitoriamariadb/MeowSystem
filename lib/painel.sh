#!/usr/bin/env bash
# lib/painel.sh — o teto do raio, as sondas do compositor e o ambiente do painel.
#
# ============================================================================
# POR QUE ESTE ARQUIVO EXISTE
# ============================================================================
#   Havia TRÊS tetos de raio contraditórios no projeto, e nenhum derivado:
#     - `scripts/forma.sh` cravava 8 (Panel) e 16 (Dock);
#     - o `meow.conf` comentava "20 é o teto do painel" e "28 é o do dock";
#     - e a medição de 26/08/2026 diz 22 e 32.
#   Três números para a mesma pergunta é o mesmo que nenhum. Aqui existe UM,
#   e ele é calculado, com a citação da fonte dentro da função.
#
# ============================================================================
# A CONTA, E DE ONDE SAI CADA PARCELA
# ============================================================================
#   A altura da barra NÃO é o tamanho do ícone. A cadeia é:
#
#   1. cada applet dimensiona a própria janela:
#        altura_applet = get_applet_icon_size + 2 * get_applet_padding
#      (cosmic-panel-config/src/panel_config.rs:145-171 e :173-199; a soma em
#       libcosmic/src/applet/mod.rs:141-158, `suggested_window_size`).
#      Simbólico e não-simbólico dão o mesmo total nos cinco tamanhos:
#
#        XS = 32   S = 40   M = 56   L = 64   XL = 80     (unidades lógicas)
#
#   2. a barra é o padding dela mais o MAIOR applet que ela hospeda:
#        altura_barra = 2 * padding + max{ altura_applet }
#      (cosmic-panel-bin/src/space/layout.rs:405-410, `new_list_thickness`).
#      O "maior applet" precisa considerar `size_center` e `size_wings`, que
#      sobrescrevem o `size` da barra por segmento
#      (panel_config.rs:541-564, `get_effective_applet_size`; o lado vem de
#       wrapper_space.rs:559-561, virando COSMIC_PANEL_SIZE do processo).
#
#   3. o compositor recusa raio maior que metade da menor dimensão da caixa
#      JÁ DESCONTADA do padding:
#        half_min_dim = padded_box.size.w.min(padded_box.size.h) / 2
#      (cosmic-comp/src/wayland/protocols/corner_radius.rs:685; a recusa em
#       :696-698; `pad_rect` em :644-655; o hook em :216).
#      A comparação é ESTRITA (`>`), então igual ao teto passa.
#
#   Logo:  teto = floor( altura_barra / 2 )
#
#   `margin` e `anchor_gap` NÃO entram na conta: o padding que o painel declara
#   ao compositor já desconta o gap (panel_space.rs:2088-2106, `set_padding`
#   com [gap, loc.x, 0, loc.x] no Top), então `padded_box.h` é a altura da
#   BARRA, não a da layer surface.
#
#   CONFERIDO CONTRA O JOURNAL desta máquina, sem usar a fonte:
#     Panel size=S padding=2  -> 2*2+40 = 44 lógicos; teto 22
#     Dock  size=M padding=4  -> 2*4+56 = 64 lógicos; teto 32
#   e o compositor desenhou `{ w: 1880, h: 64 }` para o painel (44 + 20 de gap)
#   e `{ w: 1880, h: 84 }` para o dock (64 + 20), em escala 1.0. Em escala 114%
#   (o `cosmic-randr list` desta TV) saem 72 e 95, que é o que o journal mostra.
#
#   E BATE COM O HISTÓRICO: 16 <= 22 e 24 <= 32 desenharam em 26/08 21:39;
#   67 > 32 (e 41 > 22) apagaram topbar e dock a tarde inteira.
#
# ============================================================================
# O TETO NÃO É CURA — É REDE
# ============================================================================
#   O `layer_radius_hook` compara o raio NOVO contra o bbox do frame ANTERIOR.
#   Nos instantes em que os dois não batem (boot, applet entrando ou saindo,
#   mudança de escala) até um raio dentro do teto perde a corrida — 14
#   ocorrências de `corner radius too large` no journal entre 11 e 24/08 com
#   8/16, quase todas no primeiro minuto da sessão.
#   A cura de raiz é `patches/cosmic-comp-raio-clampado.patch`, que troca o
#   `post_error` por clamp. Enquanto ELE estiver em execução, este teto não se
#   aplica: o raio é dela, sem limite. Ver `meow_painel_compositor_clampa`.

# Guarda de source duplo: este arquivo é sourced pelo forma.sh e pelo painel.sh,
# e o painel.sh pode chamar o forma.sh.
[ -n "${MEOW_PAINEL_SH_CARREGADO:-}" ] && return 0
MEOW_PAINEL_SH_CARREGADO=1

MEOW_PAINEL_BASE="${MEOW_PAINEL_BASE:-$HOME/.config/cosmic}"
MEOW_PAINEL_COMP_BIN="${MEOW_PAINEL_COMP_BIN:-/usr/bin/cosmic-comp}"
MEOW_PAINEL_MARCA_RAIO="AURORA-COSMIC-RADIUS-PATCH"

# --- a tabela de alturas ----------------------------------------------------
# `Custom(n)` existe no enum: o upstream arredonda para múltiplo de 4 com piso
# em 16 (panel_config.rs:145-171).
meow_painel_T() { # $1 = XS|S|M|L|XL|Custom(n)
  case "$1" in
    XS) printf '32' ;;
    S)  printf '40' ;;
    M)  printf '56' ;;
    L)  printf '64' ;;
    XL) printf '80' ;;
    Custom\(*\))
      local n="${1#Custom(}"; n="${n%)}"
      case "$n" in ''|*[!0-9]*) return 1 ;; esac
      [ "$n" -lt 16 ] && n=16
      printf '%s' $(( (n / 4) * 4 ))
      ;;
    *) return 1 ;;
  esac
}

# --- ler um RON simples do disco -------------------------------------------
# `Some(S)` -> S ; `None` -> vazio ; qualquer outra coisa -> falha.
_meow_painel_opt() { # $1 = arquivo
  local v
  v="$(cat "$1" 2>/dev/null)" || return 1
  case "$v" in
    None|'') return 1 ;;
    Some\(*\)) v="${v#Some(}"; v="${v%)}"; printf '%s' "$v" ;;
    *) printf '%s' "$v" ;;
  esac
}

# `size_wings` é uma TUPLA, e é o formato que mais custou tempo neste projeto:
#   Some((None, Some(S)))   <- (segmento inicial, segmento final)
# `Some(S)` cru aqui faz o cosmic-panel cuspir ExpectedStructLike e IGNORAR a
# entrada inteira, em silêncio na tela (ver scripts/forma.sh).
meow_painel_wings() { # $1 = arquivo size_wings; imprime "ini\tfim"
  local v ini fim
  v="$(cat "$1" 2>/dev/null)" || return 1
  case "$v" in Some\(\(*\)\)) : ;; *) return 1 ;; esac
  v="${v#Some((}"; v="${v%))}"
  ini="${v%%,*}"; fim="${v#*,}"
  ini="${ini# }"; fim="${fim# }"
  case "$ini" in None) ini='' ;; Some\(*\)) ini="${ini#Some(}"; ini="${ini%)}" ;; esac
  case "$fim" in None) fim='' ;; Some\(*\)) fim="${fim#Some(}"; fim="${fim%)}" ;; esac
  printf '%s\t%s' "$ini" "$fim"
}

# --- a altura efetiva da barra ---------------------------------------------
meow_painel_altura() { # $1 = dir v1 ; imprime a altura em lógicos
  local dir="$1" size padding maior t ini fim w
  size="$(_meow_painel_opt "$dir/size")" || size="$(cat "$dir/size" 2>/dev/null)"
  [ -n "$size" ] || return 1
  padding="$(cat "$dir/padding" 2>/dev/null)"
  case "$padding" in ''|*[!0-9]*) return 1 ;; esac

  maior="$(meow_painel_T "$size")" || return 1

  # os três segmentos podem ter tamanho próprio
  if t="$(_meow_painel_opt "$dir/size_center")"; then
    t="$(meow_painel_T "$t")" && [ "$t" -gt "$maior" ] && maior="$t"
  fi
  if w="$(meow_painel_wings "$dir/size_wings")"; then
    ini="${w%%$'\t'*}"; fim="${w#*$'\t'}"
    if [ -n "$ini" ]; then t="$(meow_painel_T "$ini")" && [ "$t" -gt "$maior" ] && maior="$t"; fi
    if [ -n "$fim" ]; then t="$(meow_painel_T "$fim")" && [ "$t" -gt "$maior" ] && maior="$t"; fi
  fi

  printf '%s' $(( 2 * padding + maior ))
}

meow_painel_teto() { # $1 = dir v1 ; imprime floor(altura/2)
  local h
  h="$(meow_painel_altura "$1")" || return 1
  printf '%s' $(( h / 2 ))
}

# --- as sondas do compositor ------------------------------------------------
# A PERGUNTA É SOBRE O PROCESSO, NUNCA SOBRE O ARQUIVO — 26/08/2026
#   O patch foi instalado às 22:13 e o compositor em execução era o das 01:55,
#   do binário antigo. Trocar o arquivo NÃO troca o processo: o cosmic-comp É o
#   servidor Wayland, e substituí-lo a quente fecharia todas as janelas dela.
#   Uma primeira versão desta sonda leu o binário do disco e, por 20 minutos,
#   respondeu "clampa" para uma sessão que ainda matava o cliente — desarmando a
#   rede exatamente na janela em que ela ainda podia perder a barra.
#   `grep -a` funciona em /proc/PID/exe mesmo com o inode marcado `(deleted)`,
#   que é o caso depois de o binário ser substituído.
meow_painel_compositor_clampa() {
  local p
  p="$(pgrep -x cosmic-comp | head -1)"   # há UM compositor: é o único head -1 legítimo aqui
  [ -n "$p" ] && [ -r "/proc/$p/exe" ] || return 1   # sem compositor visível: assume o pior
  grep -aqs "$MEOW_PAINEL_MARCA_RAIO" "/proc/$p/exe"
}

# disco patchado + sessão viva não patchada = "vale no próximo login"
meow_painel_patch_pendente() {
  meow_painel_compositor_clampa && return 1
  grep -aqs "$MEOW_PAINEL_MARCA_RAIO" "$MEOW_PAINEL_COMP_BIN"
}

# --- o ambiente para spawnar o painel --------------------------------------
# `env -i` E NÃO `env` — UM CARACTERE, E FOI ELE QUE MATOU A BANDEJA (25/08/2026)
#   Sem o `-i` o `env` ACRESCENTA ao ambiente de quem chamou. Rodado de um
#   terminal aberto pela dock, o painel nascia herdando `PANEL_NOTIFICATIONS_FD`
#   e `X_PRIVILEGED_WAYLAND_SOCKET` — descritores que não existem no processo
#   novo. Resultado medido: `Io error: Bad file descriptor (os error 9)` e panic
#   em libcosmic/src/applet/token/wayland_handler.rs:110 para StatusArea, Power,
#   Audio e Network. A barra sobe SEM bandeja e SEM botão de desligar, e nada na
#   tela diz por quê.
#
#   AQUI A FONTE É OUTRA, E MELHOR: dentro de uma unidade `systemd --user` o
#   ambiente já vem de `systemctl --user show-environment`, que tem
#   WAYLAND_DISPLAY, DISPLAY, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS,
#   XDG_CURRENT_DESKTOP, XDG_SESSION_TYPE e XDG_DATA_DIRS — e NÃO tem as duas
#   variáveis venenosas. Então não reconstruímos ambiente nenhum: partimos do
#   que a unidade tem e tiramos a lista negra. Menos risco de esquecer uma
#   variável do que montar a lista branca à mão.
MEOW_PAINEL_LISTA_NEGRA='PANEL_NOTIFICATIONS_FD DAEMON_NOTIFICATIONS_FD X_PRIVILEGED_WAYLAND_SOCKET'

meow_painel_ambiente_ok() {
  [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY}" ]
}

# Descobre o WAYLAND_DISPLAY pelo socket vivo, quando a unidade não o recebeu.
# O `.lock` ao lado NÃO conta: ele existe mesmo com o compositor morto.
meow_painel_achar_display() {
  local s d="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  for s in "$d"/wayland-[0-9]*; do
    case "$s" in *.lock) continue ;; esac
    [ -S "$s" ] || continue
    printf '%s' "${s##*/}"; return 0
  done
  return 1
}

# --- a trégua com o vigia da Aurora ----------------------------------------
# O `aurora-painel-fantasma.sh` mata o painel apostando na premissa escrita no
# cabeçalho dele: "o cosmic-session o respawna em ~4ms". Para um painel que NÓS
# subimos (PPID != cosmic-session) isso é falso, e ele já matou barras que
# ninguém ia ressuscitar.
#
# NÃO EDITAMOS O SCRIPT DELE. Ele já tem a trava certa — `CARENCIA=600`, lida de
# `$XDG_RUNTIME_DIR/aurora-painel-fantasma/tentativas.ts` — e ela só nunca soube
# de nós, porque só o kill DELE carimbava esse arquivo. Carimbar ali é falar a
# língua que ele já entende: "este painel acabou de nascer, não julgue ainda".
# É o contrato pelo arquivo de estado que ele mesmo definiu.
meow_painel_carencia_aurora() {
  local d="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/aurora-painel-fantasma"
  [ -d "$d" ] || return 0
  date +%s > "$d/tentativas.ts" 2>/dev/null || true
}

# --- de quem é o painel -----------------------------------------------------
# PELO PARENTESCO, NUNCA PELO environ: `PANEL_NOTIFICATIONS_FD` é herança e
# desce por toda a árvore — sete linhas do log da Aurora diziam "é o do
# supervisor" numa janela em que ele comprovadamente dormia.
# E NUNCA com `| head -1`: o menor PID é o NOSSO sempre que o supervisor chega
# atrasado, e o crédito se inverteria. Classificamos TODOS.
meow_painel_do_supervisor() {   # imprime o PID do painel do cosmic-session, se houver
  local ses p pai
  ses="$(pgrep -x cosmic-session | head -1)"
  [ -n "$ses" ] || return 1
  for p in $(pgrep -x cosmic-panel 2>/dev/null); do
    pai="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
    [ "$pai" = "$ses" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

meow_painel_nossos() {          # imprime os PIDs dos painéis que NÃO são do supervisor
  local ses p pai achou=1
  ses="$(pgrep -x cosmic-session | head -1)"
  for p in $(pgrep -x cosmic-panel 2>/dev/null); do
    pai="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
    [ -n "$ses" ] && [ "$pai" = "$ses" ] && continue
    printf '%s\n' "$p"; achou=0
  done
  return "$achou"
}

# --- quanto o supervisor do COSMIC vai dormir -------------------------------
# O backoff do `cosmic-session` é `2^restarts` ms vezes um inteiro sorteado de 0
# a 9 — medido em 26/08/2026 contra as 28 linhas de backoff de um boot inteiro,
# 28 quocientes exatos, zero exceção. Não há teto, e o contador NUNCA zera por
# sucesso: o painel viveu 2h26 e a espera seguinte ainda saiu com base 2^20.
# No restart 23 desta máquina a espera saiu 58720256 ms — 16h18min.
#
# Isto é o gatilho adaptativo: se ele volta em segundos, deixamos com ele (e
# ganhamos o applet de notificações, que só o socketpair dele fornece). Se vai
# dormir horas, assumimos.
meow_painel_espera_supervisor() {   # imprime ms, ou nada se ele nunca falhou
  journalctl --user -b -t cosmic-session --no-pager 2>/dev/null \
    | grep -oE 'sleeping for [0-9]+ms before restarting process cosmic-panel' \
    | tail -1 | grep -oE '[0-9]+'
}

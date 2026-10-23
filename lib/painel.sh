#!/usr/bin/env bash
# lib/painel.sh — o teto do raio, as sondas do compositor e o ambiente do painel.
#
# A altura da barra NÃO é o tamanho do ícone.
#
#   1. cada applet dimensiona a própria janela:
#        altura_applet = get_applet_icon_size + 2 * get_applet_padding
#      (cosmic-panel-config/src/panel_config.rs:145-171 e :173-199; a soma em
#       libcosmic/src/applet/mod.rs:141-158, `suggested_window_size`).
#      Simbólico e não-simbólico dão o mesmo total nos cinco tamanhos:
#
#   3. o compositor recusa raio maior que metade da menor dimensão da caixa
#      JÁ DESCONTADA do padding:
#        half_min_dim = padded_box.size.w.min(padded_box.size.h) / 2
#      (cosmic-comp/src/wayland/protocols/corner_radius.rs:685; a recusa em
#       :696-698; `pad_rect` em :644-655; o hook em :216).
#      A comparação é ESTRITA (`>`), então igual ao teto passa.

# Guarda de source duplo: este arquivo é sourced pelo forma.sh e pelo painel.sh,
# e o painel.sh pode chamar o forma.sh.
[ -n "${MEOW_PAINEL_SH_CARREGADO:-}" ] && return 0
MEOW_PAINEL_SH_CARREGADO=1

MEOW_PAINEL_BASE="${MEOW_PAINEL_BASE:-$(meow_cosmic_dir)}"
# o disco que conta é o do próximo login (o build do shim, ou /usr/bin).
MEOW_PAINEL_COMP_BIN="${MEOW_PAINEL_COMP_BIN:-$(meow_cosmic_comp_disco)}"
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

# Sem o patch o teto é ZERO: o compositor mede pelo `configure` que o cliente ainda
# não reconheceu, e qualquer raio > 0 vira `post_error` fatal — a barra não desenha.
meow_painel_teto() { # $1 = dir v1 ; imprime o maior raio que a barra aguenta
  local h
  h="$(meow_painel_altura "$1")" || return 1
  # Com o patch de pé o compositor clampa sozinho e nada aqui se aplica — mas
  # quem pergunta pelo teto ainda merece um número, e `altura/2` é o dele.
  meow_painel_compositor_clampa || { printf '0'; return 0; }
  printf '%s' $(( h / 2 ))
}

# --- as sondas do compositor ------------------------------------------------
#
# Trocar o arquivo NÃO troca o processo: o cosmic-comp É o servidor Wayland, e
# substituí-lo a quente fecharia todas as janelas dela.
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
#
# Sem o `-i` o `env` ACRESCENTA ao ambiente de quem chamou.
#
# AQUI A FONTE É OUTRA, E MELHOR: dentro de uma unidade `systemd --user` o
# ambiente já vem de `systemctl --user show-environment`, que tem
# WAYLAND_DISPLAY, DISPLAY, XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS,
# XDG_CURRENT_DESKTOP, XDG_SESSION_TYPE e XDG_DATA_DIRS — e NÃO tem as duas
# variáveis venenosas.
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

# --- o painel VIVO que parou de desenhar -------------------------------------
#
# Os dois sinais abaixo são filtrados por `_PID` do painel EM EXECUÇÃO. Isso é o
# que os torna confiáveis: uma mensagem do painel anterior, ou de outro cliente
# Wayland qualquer, não conta.
#
# Um painel recém-nascido ainda está montando as layer surfaces e pode
# perfeitamente ter emitido um erro no caminho.
meow_painel_fantasma() {        # 0 = há um painel vivo que não desenha
  local pid vida
  pid="$(pgrep -x cosmic-panel 2>/dev/null | head -1)"
  [ -n "$pid" ] || return 1     # sem painel não é fantasma: é ausência, e o laço já trata

  vida="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')"
  case "$vida" in ''|*[!0-9]*) return 1 ;; esac
  [ "$vida" -ge 20 ] || return 1

  journalctl --user -b --no-pager _PID="$pid" 2>/dev/null \
    | grep -qiE 'failed to render|erroneous egl|protocol error|error 1 on object' \
    && return 0
  return 1
}

# --- de quem é o painel -----------------------------------------------------
# PELO PARENTESCO, NUNCA PELO environ: `PANEL_NOTIFICATIONS_FD` é herança e
# desce por toda a árvore — sete linhas do log da Aurora diziam "é o do
# supervisor" numa janela em que ele comprovadamente dormia.
meow_painel_do_supervisor() {   # imprime o PID do painel do cosmic-session, se houver
  local ses p pai
  ses="$(pgrep -x cosmic-session | head -1)"
  [ -n "$ses" ] || return 1
  for p in $(meow_painel_desta_casa); do
    pai="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
    [ "$pai" = "$ses" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

# --- de QUEM é a casa do painel -----------------------------------------------
#
# O `reciclar` achava o painel com `pgrep -x cosmic-panel` e o derrubava com
# `pkill -x cosmic-panel`: a máquina inteira, de qualquer usuário, de qualquer
# `$HOME`.
#
# O `cosmic-session`, o laço do `meow-painel.service` e o Alt+F2 sobem o painel
# com o `HOME` da sessão, e o timer que pede o reciclo roda com esse mesmo
# `HOME`.
meow_painel_desta_casa() {      # imprime os PIDs dos cosmic-panel deste usuário e deste HOME
  local p casa eu="${HOME%/}"
  for p in $(pgrep -u "$(id -u)" -x cosmic-panel 2>/dev/null); do
    casa="$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | sed -n 's/^HOME=//p' | head -n1)"
    [ -n "$casa" ] && [ "${casa%/}" = "$eu" ] && printf '%s\n' "$p"
  done
  return 0
}

meow_painel_nossos() {          # imprime os PIDs dos painéis desta casa que NÃO são do supervisor
  local ses p pai achou=1
  ses="$(pgrep -x cosmic-session | head -1)"
  for p in $(meow_painel_desta_casa); do
    pai="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
    [ -n "$ses" ] && [ "$pai" = "$ses" ] && continue
    printf '%s\n' "$p"; achou=0
  done
  return "$achou"
}

# --- quanto o supervisor do COSMIC vai dormir -------------------------------
# O backoff do `cosmic-session` é `2^restarts` ms vezes um inteiro sorteado de 0
# a 9 — medido contra as 28 linhas de backoff de um boot inteiro, 28 quocientes
# exatos, zero exceção.
#
# Isto é o gatilho adaptativo: se ele volta em segundos, deixamos com ele (e
# ganhamos o applet de notificações, que só o socketpair dele fornece).
meow_painel_espera_supervisor() {   # imprime ms; `nao-medida`; ou nada se ele nunca falhou
  local log ms
  log="$(journalctl --user -b -t cosmic-session --no-pager 2>/dev/null)"
  ms="$(printf '%s\n' "$log" \
    | grep -oE 'sleeping for [0-9]+ms before restarting process cosmic-panel' \
    | tail -1 | grep -oE '[0-9]+')"
  if [ -n "$ms" ]; then printf '%s\n' "$ms"; return 0; fi
  if printf '%s\n' "$log" | grep -i 'cosmic-panel' | grep -qi 'restart'; then
    printf 'nao-medida\n'
  fi
}

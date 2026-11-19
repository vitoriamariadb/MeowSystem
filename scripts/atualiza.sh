#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

AT_TRONCO=master
AT_FLUXO=testes
AT_PROCURA=10
AT_ESPERA_DA_VEZ="${AT_ESPERA_DA_VEZ:-300}"
AT_API="${AT_API:-https://api.github.com/repos}"
AT_SUDO_CONF="${AT_SUDO_CONF:-/etc/sudo.conf}"
AT_LOG="$MEOW_ESTADO/atualiza.log"
AT_MEMORIA="$MEOW_ESTADO/atualiza.tsv"
AT_DESTINO="$HOME/.config/systemd/user"
AT_UNIDADES=(meow-atualiza.service meow-atualiza.timer)
AT_TIMER=meow-atualiza.timer
AT_QUANDO="3 minutos depois de ligar e uma vez por dia"
AT_QUER="${ATUALIZA:-$(meow_conf_valor ATUALIZA || true)}"
AT_QUER="${AT_QUER:-sim}"

_at_git() { GIT_TERMINAL_PROMPT=0 GIT_OPTIONAL_LOCKS=0 git -C "$MEOW_RAIZ" "$@"; }

_at_curto() { _at_git rev-parse --short "$1" 2>/dev/null || printf '%s' "${1:0:7}"; }

_at_registrar() {
  mkdir -p "$MEOW_ESTADO" && printf '%s %s\n' "$(date -Iseconds)" "$*" >> "$AT_LOG"
}

_at_lembrado() { awk -F'\t' -v k="$1" '$1 == k { print $2; exit }' "$AT_MEMORIA" 2>/dev/null; }

_at_lembrar() {
  local tmp
  [ "$(_at_lembrado "$1")" = "$2" ] && return 0
  mkdir -p "$MEOW_ESTADO" && tmp="$(mktemp -p "$MEOW_ESTADO" .atualiza.XXXXXX)" || return 1
  { awk -F'\t' -v k="$1" '$1 != k' "$AT_MEMORIA" 2>/dev/null
    [ -z "$2" ] || printf '%s\t%s\n' "$1" "$2"; } > "$tmp" && mv -f "$tmp" "$AT_MEMORIA"
}

_at_avisar() {
  [ "$(_at_lembrado aviso)" = "$1" ] && return 0
  _at_registrar "$2"
  meow_notificar "MeowSystem" "$2"
  _at_lembrar aviso "$1"
}

_at_repositorio() {
  local url="${1%/}" nome resto
  url="${url%.git}"; nome="${url##*/}"; resto="${url%/*}"
  [ "$resto" != "$url" ] || return 1
  resto="${resto##*[/:]}"
  [ -n "$resto" ] && [ -n "$nome" ] || return 1
  printf '%s/%s' "$resto" "$nome"
}

_at_ci() {
  curl -fsSL --max-time 20 -H 'Accept: application/vnd.github+json' \
       "$AT_API/$1/actions/runs?head_sha=$2&per_page=50" 2>/dev/null \
  | python3 -I -c '
import json, sys
try:
    runs = [r for r in json.load(sys.stdin).get("workflow_runs", []) if r.get("name") == sys.argv[1]]
except Exception:
    sys.exit(1)
if not runs:
    print("sem")
    sys.exit(0)
r = max(runs, key=lambda r: r.get("id") or 0)
if r.get("status") != "completed":
    print("curso")
elif r.get("conclusion") == "success":
    print("verde")
else:
    print("vermelho")
' "$AT_FLUXO"
}

_at_askpass() {
  [ -n "${SUDO_ASKPASS:-}" ] && return 0
  local a
  a="$(sed -n 's/^[[:space:]]*Path[[:space:]][[:space:]]*askpass[[:space:]][[:space:]]*//p' "$AT_SUDO_CONF" 2>/dev/null | tail -n1)"
  [ -n "$a" ] && [ -x "$a" ] && export SUDO_ASKPASS="$a"
  return 0
}

_at_instalar() {
  local alvo="$1" entrou="$2" curto rc
  curto="$(_at_curto "$alvo")"
  _at_askpass
  [ -n "${SUDO_ASKPASS:-}" ] || meow_ponte_viva \
    || _at_registrar "sem askpass e sem a ponte root: o que precisa de root fica de fora, e o resto vai"
  _at_registrar "install.sh no $curto"
  flock -w "$AT_ESPERA_DA_VEZ" "$MEOW_ESTADO/lock" true 2>/dev/null \
    || _at_registrar "outro meow segurou a vez por mais de $AT_ESPERA_DA_VEZ s; o install tenta assim mesmo"
  (cd "$MEOW_RAIZ" && ./install.sh) < /dev/null >> "$AT_LOG" 2>&1; rc=$?
  if [ "$rc" -ge 2 ]; then
    _at_lembrar instalar "$alvo"
    _at_registrar "o install.sh saiu $rc no $curto; a próxima volta tenta de novo"
    meow_notificar "MeowSystem" "O MeowSystem chegou ao $curto, mas a instalação falhou; a próxima volta tenta de novo. O registro está em atualiza.log."
    return "$MEOW_ERRO"
  fi
  _at_lembrar instalar ""
  _at_registrar "instalado no $curto: $entrou"
  meow_notificar "MeowSystem atualizado" "$entrou"
  return "$MEOW_OK"
}

_at_motivo_do_clone() {
  local cima="$1" ramo
  ramo="$(_at_git symbolic-ref --short -q HEAD)"
  if [ "$ramo" != "$AT_TRONCO" ]; then
    printf 'ramo\tO clone do MeowSystem está em %s, não no %s; a atualização sozinha não mexeu nele.' "${ramo:-um commit solto}" "$AT_TRONCO"
  elif [ -n "$(_at_git status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    printf 'sujo\tO clone do MeowSystem tem mudanças locais; a atualização sozinha não mexeu nele.'
  elif [ "$(_at_git rev-list --count "$cima..HEAD" 2>/dev/null)" != 0 ]; then
    printf 'frente\tO clone do MeowSystem tem commits que o GitHub não tem; a atualização sozinha não mexeu nele.'
  fi
}

_at_verde_mais_novo() {
  local repo="$1" cima="$2" c estado
  for c in $(_at_git rev-list --first-parent --max-count="$AT_PROCURA" "HEAD..$cima"); do
    _at_git merge-base --is-ancestor HEAD "$c" || continue
    estado="$(_at_ci "$repo" "$c")" || return 1
    case "$estado" in
      verde) printf '%s' "$c"; return 0 ;;
      vermelho)
        _at_avisar "vermelho:$c" "O commit $(_at_curto "$c") do GitHub falhou nos testes; a atualização espera o próximo verde."
        return 0 ;;
    esac
  done
  return 0
}

cmd_rodar() {
  [ "$AT_QUER" = "sim" ] || return "$MEOW_OK"
  [ -d "$MEOW_RAIZ/.git" ] && [ -d "$MEOW_ESTADO" ] || return "$MEOW_OK"
  local url repo fonte=origin trava cima aqui pendente motivo alvo n entrou
  url="$(_at_git remote get-url origin 2>/dev/null)" || return "$MEOW_OK"
  repo="$(_at_repositorio "$url")" || return "$MEOW_OK"
  case "$url" in *github*) fonte="https://github.com/$repo.git" ;; esac

  exec {trava}>>"$MEOW_ESTADO/lock" || return "$MEOW_OK"
  flock -n "$trava" || { exec {trava}>&-; return "$MEOW_OK"; }

  if ! GIT_TERMINAL_PROMPT=0 timeout 300 git -C "$MEOW_RAIZ" fetch --quiet --no-write-fetch-head \
         "$fonte" "+refs/heads/$AT_TRONCO:refs/remotes/origin/$AT_TRONCO" > /dev/null 2>&1; then
    exec {trava}>&-; return "$MEOW_OK"
  fi
  cima="$(_at_git rev-parse -q --verify "refs/remotes/origin/$AT_TRONCO^{commit}")" || { exec {trava}>&-; return "$MEOW_OK"; }
  aqui="$(_at_git rev-parse HEAD)" || { exec {trava}>&-; return "$MEOW_OK"; }
  pendente="$(_at_lembrado instalar)"

  alvo=""
  if [ "$cima" != "$aqui" ]; then
    motivo="$(_at_motivo_do_clone "$cima")"
    if [ -n "$motivo" ]; then
      exec {trava}>&-
      _at_avisar "clone:${motivo%%$'\t'*}:$aqui" "${motivo#*$'\t'}"
      return "$MEOW_OK"
    fi
    alvo="$(_at_verde_mais_novo "$repo" "$cima")" || { exec {trava}>&-; return "$MEOW_OK"; }
  fi

  if [ -z "$alvo" ]; then
    exec {trava}>&-
    [ -n "$pendente" ] && [ "$pendente" = "$aqui" ] || return "$MEOW_OK"
    _at_instalar "$aqui" "a instalação do $(_at_curto "$aqui") que tinha falhado terminou"
    return $?
  fi

  n="$(_at_git rev-list --count "HEAD..$alvo")"
  if ! MEOW_SEM_README=1 _at_git merge --ff-only --quiet "$alvo" > /dev/null 2>&1; then
    exec {trava}>&-
    _at_avisar "avanco:$alvo" "O clone do MeowSystem não avançou para o $(_at_curto "$alvo"); ele ficou como estava."
    return "$MEOW_OK"
  fi
  exec {trava}>&-
  if [ "$n" = 1 ]; then entrou="1 mudança nova, até o $(_at_curto "$alvo")"
  else entrou="$n mudanças novas, até o $(_at_curto "$alvo")"; fi
  _at_registrar "avançou do $(_at_curto "$aqui") para o $(_at_curto "$alvo")"
  _at_instalar "$alvo" "$entrou"
}

_at_armado() {
  [ "$(systemctl --user is-enabled "$AT_TIMER" 2>/dev/null)" = "enabled" ] &&
  [ "$(systemctl --user is-active  "$AT_TIMER" 2>/dev/null)" = "active" ]
}

_at_sobrou() {
  local u
  for u in "${AT_UNIDADES[@]}"; do [ -f "$AT_DESTINO/$u" ] && return 0; done
  for u in "$AT_DESTINO"/*.wants/"$AT_TIMER"; do [ -L "$u" ] && return 0; done
  return 1
}

_at_sem_systemd() { ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; }

cmd_conferir() {
  local u faltam=() difere=()
  if [ "$AT_QUER" != "sim" ]; then
    if _at_sobrou; then
      echo "ATUALIZA=\"$AT_QUER\" no meow.conf, mas o $AT_TIMER continua em $AT_DESTINO"
      return "$MEOW_DIVERGENTE"
    fi
    echo "ATUALIZA=\"$AT_QUER\" — sem atualização ao ligar, por escolha sua"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if _at_sem_systemd; then
    echo "não há systemd --user nesta sessão — a atualização ao ligar fica de fora"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  for u in "${AT_UNIDADES[@]}"; do
    [ -f "$MEOW_RAIZ/systemd/$u" ] || { echo "falta $MEOW_RAIZ/systemd/$u — repositório incompleto"; return "$MEOW_ERRO"; }
    if [ ! -f "$AT_DESTINO/$u" ]; then faltam+=("$u"); continue; fi
    meow_mesmo_conteudo "$MEOW_RAIZ/systemd/$u" "$AT_DESTINO/$u" || difere+=("$u")
  done
  if [ "${#faltam[@]}" -gt 0 ] || [ "${#difere[@]}" -gt 0 ] || ! _at_armado; then
    [ "${#faltam[@]}" -gt 0 ] && echo "não estão instaladas: ${faltam[*]}"
    [ "${#difere[@]}" -gt 0 ] && echo "diferentes das do repositório: ${difere[*]}"
    _at_armado || echo "o $AT_TIMER não está armado — o PC não se atualiza ao ligar"
    return "$MEOW_DIVERGENTE"
  fi
  echo "atualização ao ligar armada ($AT_TIMER, $AT_QUANDO)"
  return "$MEOW_OK"
}

cmd_aplicar() {
  local u mudou=0
  if [ "$AT_QUER" != "sim" ]; then
    if _at_sobrou; then
      meow_seco && { meow_muda "ATUALIZA=\"$AT_QUER\" — removeria a atualização ao ligar ($AT_TIMER)"; return "$MEOW_DIVERGENTE"; }
      systemctl --user disable --now "$AT_TIMER" > /dev/null 2>&1
      rm -f "${AT_UNIDADES[@]/#/$AT_DESTINO/}" "$AT_DESTINO"/*.wants/"$AT_TIMER"
      systemctl --user daemon-reload > /dev/null 2>&1
      meow_muda "ATUALIZA=\"$AT_QUER\" — atualização ao ligar desligada e removida ($AT_TIMER)"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "ATUALIZA=\"$AT_QUER\" — sem atualização ao ligar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if _at_sem_systemd; then
    meow_aviso "não há systemd --user nesta sessão — a atualização ao ligar fica de fora"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  for u in "${AT_UNIDADES[@]}"; do
    [ -f "$MEOW_RAIZ/systemd/$u" ] || { meow_erro "falta systemd/$u — repositório incompleto"; return "$MEOW_ERRO"; }
    meow_escrever "$AT_DESTINO/$u" "$(cat "$MEOW_RAIZ/systemd/$u")" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac
  done
  if meow_seco; then
    _at_armado || { meow_muda "armaria a atualização ao ligar ($AT_TIMER)"; mudou=1; }
    [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
    meow_ok "atualização ao ligar já armada ($AT_TIMER, $AT_QUANDO)"
    return "$MEOW_OK"
  fi
  [ "$mudou" = "1" ] && systemctl --user daemon-reload > /dev/null 2>&1
  if ! _at_armado; then
    systemctl --user enable --now "$AT_TIMER" > /dev/null 2>&1 \
      || { meow_erro "não consegui armar o $AT_TIMER"; return "$MEOW_ERRO"; }
    mudou=1
  fi
  if [ "$mudou" = "1" ]; then
    meow_muda "atualização ao ligar armada ($AT_TIMER, $AT_QUANDO)"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "atualização ao ligar já armada ($AT_TIMER, $AT_QUANDO)"
  return "$MEOW_OK"
}

case "${1:-rodar}" in
  rodar)    cmd_rodar ;;
  conferir) cmd_conferir ;;
  aplicar)  cmd_aplicar ;;
  *) printf 'uso: atualiza.sh [rodar|conferir|aplicar]\n' >&2; exit 2 ;;
esac

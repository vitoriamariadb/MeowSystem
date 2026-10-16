#!/usr/bin/env bash
# garantir_builds.sh — o compositor e o menu do cosmic-files têm build para a
# versão que o apt instalou? Se não têm, compila; se têm, não faz nada (P81).
#
#   ./garantir_builds.sh          compila o que falta, e só isso
#   ./garantir_builds.sh --seco   diz o que compilaria, sem baixar nem escrever
#   ./garantir_builds.sh --fundo  a mesma passagem em segundo plano (o conserto do doctor)
#
#   0 = tudo pronto (já estava, acabou de ficar, ou pulado por regra)
#   1 = (só no --seco e no --fundo) havia o que compilar
#   2 = um build falhou — o próximo gatilho tenta de novo · 3 = sem dpkg
#
# POR QUE UMA FUNÇÃO SÓ (medido em 15/10/2026)
#   O apt das 20:14 trouxe o COSMIC 1.10, e o pós-apt das 20:15 recompilou o
#   menu do cosmic-files e PULOU o compositor: «o shim do compositor está
#   desligado — sem build». E gravou a versão como vista: ligado o shim, nenhum
#   gatilho voltaria a ela. Cada gatilho decidia por conta própria se
#   compilava. Agora quem decide é o artefato — existe build válido daquela
#   versão, nada; não existe, compila —, e os gatilhos só chamam:
#     meow-pos-apt.service        depois de todo apt (o hook toca o carimbo);
#     meow-builds-login.service   uma vez por login: o apt feito com ela
#                                 deslogada, ou por TTY, não acorda unidade
#                                 de usuário nenhuma;
#     o doctor (`fix_patches`)    o das 5h e o «Consertar», pelo `--fundo`.
#
# O QUE É BUILD VÁLIDO, por pacote
#   cosmic-comp   `<casa>/<versão>/cosmic-comp` executável e o `estado` com o
#                 `req` presente: a mesma regra do shim, que é quem o usa. Com
#                 o shim desligado compila igual — ligar o shim é gesto dela, e
#                 o build pronto é o que faz o gesto valer no próximo login.
#   cosmic-files  os dois binários de `<guarda>/<versão>/` com o marcador do
#                 patch, se FILES_MENU for "sim".
#   O build marcado `ruim` (duas quedas, pela guarda do shim) NÃO se refaz: o
#   mesmo fonte daria o mesmo binário, e refazê-lo apagaria a guarda que tirou
#   a sessão dela do laço de quedas. Ele espera a próxima versão.
#
# O QUE CADA FALHA DEIXA
#   O `req` que não entra (degrau 4) aborta antes do make: nada é trocado e o
#   shim segue no de fábrica. Isso é regra, não falha: sai 0, e a matriz diz
#   que é rebase. E a versão no degrau 4 SAI DOS PENDENTES enquanto a série
#   não mudar depois da matriz (conferência da P81): o mesmo fonte com a mesma
#   série recusa o mesmo `req`, e cada login, apt e doctor das 5h refazia a
#   tentativa, escrevendo. O rebase chega por `git pull` em `patches/`, que
#   fica mais novo que a matriz, e a versão volta a ser tentada. O `opt` que
#   não entra sai do build sozinho (degrau 3, no `compositor_patches.sh`).
#   Erro de verdade (rede, cargo) sai 2, e o próximo gatilho tenta de novo — o
#   artefato que falta é a memória, não um carimbo.
#
# UMA PASSAGEM POR VEZ
#   `flock` em `$MEOW_ESTADO/builds.lock`, ESPERANDO: um apt no meio do build
#   do login espera ele acabar e confere de novo, já com a versão nova. O lock
#   abre em acréscimo (`>>`), e só quando há o que compilar: a segunda passagem
#   não toca em arquivo nenhum. É ele que o `compositor_patches.sh conferir` lê
#   para dizer «construindo».
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# Sobrescrevíveis para o teste trocar um build de meia hora por um registro de
# uma linha; nenhum vira chave do meow.conf.
GB_COMPOSITOR="${GB_COMPOSITOR:-$MEOW_RAIZ/scripts/compositor_patches.sh}"
GB_FILES="${GB_FILES:-$MEOW_RAIZ/scripts/files_menu.sh}"
GB_CASA="${GB_CASA:-${CP_CASA:-$HOME/.local/libexec/meow/cosmic-comp}}"
GB_FILES_GUARDA="${GB_FILES_GUARDA:-$MEOW_ESTADO/cosmic-files}"
GB_MATRIZ="${GB_MATRIZ:-${CP_MATRIZ:-$MEOW_ESTADO/cosmic-comp/matriz.tsv}}"
# A série e os patches, os mesmos do `compositor_patches.sh`.
GB_REPO="${CP_REPO:-$MEOW_RAIZ/patches}"
GB_SERIE="${CP_SERIE:-$GB_REPO/series}"
GB_TRAVA="${GB_TRAVA:-$MEOW_ESTADO/builds.lock}"
GB_UNIDADE="meow-builds-login.service"
GB_FILES_MARCA="MEOW-FILES-WALLPAPER-PATCH-1"

# O CARGO DO RUSTUP ENTRA NO PATH AQUI, pelo mesmo motivo medido no
# `cosmic_pos_apt.sh` (P76): o PATH do systemd do usuário não tem o
# `~/.cargo/bin`, e o login e o doctor chamam este arquivo sem passar por lá.
GB_CARGO_BIN="${CARGO_HOME:-$HOME/.cargo}/bin"
case ":$PATH:" in
  *":$GB_CARGO_BIN:"*) ;;
  *) [ -d "$GB_CARGO_BIN" ] && PATH="$GB_CARGO_BIN:$PATH" && export PATH ;;
esac

# pacote<TAB>versão do cosmic-comp e do cosmic-files instalados.
_gb_instalados() {
  dpkg-query -W -f='${Package}\t${Version}\t${db:Status-Status}\n' cosmic-files cosmic-comp 2>/dev/null |
    awk -F'\t' '($1=="cosmic-files" || $1=="cosmic-comp") && $3=="installed" && $2!="" {print $1"\t"$2}'
}

_gb_comp_valido() { # $1 versão
  [ -x "$GB_CASA/$1/cosmic-comp" ] && grep -q '^req [^ ]* [^ ]* presente$' "$GB_CASA/$1/estado" 2>/dev/null
}
_gb_files_valido() { # $1 versão
  local b
  for b in cosmic-files cosmic-files-applet; do
    grep -a -q -- "$GB_FILES_MARCA" "$GB_FILES_GUARDA/$1/$b" 2>/dev/null || return 1
  done
}
# 0 = a matriz diz degrau 4 para a versão, e a série não mudou depois dela.
_gb_comp_degrau4() { # $1 versão
  awk -F'\t' -v v="$1" '$1==v && $3 ~ /:4( |$)/ {a=1} END {exit !a}' "$GB_MATRIZ" 2>/dev/null || return 1
  [ -z "$(find "$GB_REPO" "$GB_SERIE" -newer "$GB_MATRIZ" -print -quit 2>/dev/null)" ]
}
# O patch obrigatório que não entra pede uma pessoa (rebase em `patches/`): vira a
# linha `patch-obrigatorio` do cartão «precisa de gente», com o desde-quando do
# primeiro registro, e sai quando a versão tem build ou a série mudou.
_gb_gente() {
  local vc linhas
  vc="$(_gb_instalados | awk -F'\t' '$1=="cosmic-comp" {print $2}')"
  if [ -n "$vc" ] && _gb_comp_degrau4 "$vc" && ! _gb_comp_valido "$vc"; then
    linhas="$(awk -F'\t' -v v="$vc" '$1==v {for (i = 1; i <= split($3, a, " "); i++) if (a[i] ~ /:4$/) {sub(/:4$/, "", a[i]); print a[i]}}' "$GB_MATRIZ" 2>/dev/null | sort -u | tr '\n' ' ')"
    meow_precisa_de_gente patch-obrigatorio "Patch obrigatório precisa de rebase" \
      "cosmic-comp $vc: ${linhas:-a série} não entra, e a sessão segue no compositor de fábrica até um rebase em patches/"
  else
    meow_precisa_de_gente_resolvida patch-obrigatorio
  fi
}

# A chave do ambiente vence (o doctor exporta o conf inteiro); sem ela, o conf.
_gb_files_quer() {
  local q="${FILES_MENU:-}"
  [ -n "$q" ] || q="$(meow_conf_valor FILES_MENU 2>/dev/null)" || q="sim"
  [ "${q:-sim}" = "sim" ]
}

# Uma linha por build que falta: pacote<TAB>versão. O `ruim` não entra.
_gb_pendentes() {
  local p v
  while IFS=$'\t' read -r p v; do
    case "$p" in
      cosmic-files) _gb_files_quer && ! _gb_files_valido "$v" && printf '%s\t%s\n' "$p" "$v" ;;
      cosmic-comp)  [ ! -e "$GB_CASA/$v/ruim" ] && ! _gb_comp_valido "$v" && ! _gb_comp_degrau4 "$v" \
                      && printf '%s\t%s\n' "$p" "$v" ;;
    esac
  done < <(_gb_instalados)
  return 0
}

# 0 = alguma passagem segura o lock agora. Sem o arquivo não há passagem.
gb_construindo() { [ -e "$GB_TRAVA" ] && ! flock -n "$GB_TRAVA" true 2>/dev/null; }

# --- os dois builds: 0 = pronto ou pulado por regra · 2 = falhou ------------
_gb_compilar_files() { # $1 versão
  meow_info "cosmic-files $1: sem o menu desta versão — compilando"
  FILES_MENU=sim "$GB_FILES" build; local rc=$?
  _gb_files_valido "$1" && return 0
  [ "$rc" = "3" ] && { meow_pula "cosmic-files $1: falta ferramenta de compilação nesta máquina — o do pacote segue valendo"; return 0; }
  meow_aviso "cosmic-files $1: o build falhou — o do pacote segue valendo, e o próximo gatilho tenta de novo"
  return 2
}

_gb_compilar_comp() { # $1 versão
  meow_info "cosmic-comp $1: sem build desta versão — compilando"
  # O degrau 4 é DESTA tentativa só se ela regravou a matriz (o `compilar`
  # a toca a cada série pesada): uma linha velha com uma falha de rede antes
  # da escada não pode virar «espera rebase».
  local t0; t0="$(date +%s)"
  "$GB_COMPOSITOR" compilar; local rc=$?
  _gb_comp_valido "$1" && return 0
  [ "$rc" = "3" ] && { meow_pula "cosmic-comp $1: falta ferramenta de compilação nesta máquina — a sessão segue no de fábrica"; return 0; }
  if [ "$(stat -c %Y "$GB_MATRIZ" 2>/dev/null || echo 0)" -ge "$t0" ] && _gb_comp_degrau4 "$1"; then
    meow_pula "cosmic-comp $1: o patch obrigatório não entra nesta versão (degrau 4) — a sessão segue no de fábrica"
    return 0
  fi
  meow_aviso "cosmic-comp $1: o build falhou — a sessão segue no de fábrica, e o próximo gatilho tenta de novo"
  return 2
}

cmd_rodar() {
  local p v falhou=0
  local -a pend=()
  meow_tem dpkg-query || { meow_pula "sem dpkg nesta máquina"; return "$MEOW_SEM_DEPENDENCIA"; }
  mapfile -t pend < <(_gb_pendentes)
  if [ "${#pend[@]}" = "0" ]; then
    _gb_gente
    local vc; vc="$(_gb_instalados | awk -F'\t' '$1=="cosmic-comp" {print $2}')"
    if [ -n "$vc" ] && _gb_comp_degrau4 "$vc" && ! _gb_comp_valido "$vc"; then
      meow_pula "cosmic-comp $vc: o patch obrigatório não entra nesta versão (degrau 4) — a sessão segue no de fábrica até a série mudar"
      return "$MEOW_OK"
    fi
    meow_ok "o compositor e o menu do cosmic-files têm build para a versão instalada"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    for p in "${pend[@]}"; do meow_muda "compilaria o ${p%%$'\t'*} ${p#*$'\t'}"; done
    return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "${GB_TRAVA%/*}" || return "$MEOW_ERRO"
  exec 9>>"$GB_TRAVA" || return "$MEOW_ERRO"
  gb_construindo && meow_info "outra passagem está compilando — espero ela acabar"
  flock 9
  # Nice 19 e IO ocioso também fora do systemd (o doctor sem a unidade).
  renice -n 19 -p $$ >/dev/null 2>&1
  ionice -c 3 -p $$ >/dev/null 2>&1

  # De novo, já com o lock: a passagem que esperou pode ter feito o trabalho.
  # O menu vem antes: minutos, contra a meia hora do compositor.
  mapfile -t pend < <(_gb_pendentes)
  for p in "${pend[@]}"; do
    v="${p#*$'\t'}"
    case "${p%%$'\t'*}" in
      cosmic-files) _gb_compilar_files "$v" || falhou=1 ;;
      cosmic-comp)  _gb_compilar_comp  "$v" || falhou=1 ;;
    esac
  done
  meow_registrar "garantir_builds.sh falhou=$falhou"
  _gb_gente
  [ "$falhou" = "1" ] && return "$MEOW_ERRO"
  return "$MEOW_OK"
}

# O CONSERTO DO DOCTOR NÃO ESPERA O BUILD: o `meow-doctor.service` tem 5 min
# de prazo e segura o lock do meow, e o compositor leva até meia hora. Com a
# unidade do login instalada, é ela que roda a passagem (Nice 19, IO ocioso,
# 2 h de prazo); e espera-se o lock aparecer, para a conferência seguinte do
# doctor já dizer «construindo». Sem a unidade, a passagem roda aqui mesmo.
cmd_fundo() {
  local -a pend=()
  mapfile -t pend < <(_gb_pendentes)
  [ "${#pend[@]}" = "0" ] && { cmd_rodar; return $?; }
  meow_seco && { cmd_rodar; return $?; }
  if [ -f "$HOME/.config/systemd/user/$GB_UNIDADE" ] \
     && systemctl --user start --no-block "$GB_UNIDADE" >/dev/null 2>&1; then
    local i
    for i in $(seq 50); do gb_construindo && break; sleep 0.2; done
    meow_muda "construindo em segundo plano: ${pend[*]//$'\t'/ } — vale no próximo login"
    return "$MEOW_DIVERGENTE"
  fi
  cmd_rodar || return $?
  return "$MEOW_DIVERGENTE"
}

case "${1:-}" in
  ""|rodar) cmd_rodar ;;
  --seco)   MEOW_SECO=1; cmd_rodar ;;
  --fundo)  cmd_fundo ;;
  *) meow_erro "uso: garantir_builds.sh [--seco|--fundo]"; exit "$MEOW_ERRO" ;;
esac

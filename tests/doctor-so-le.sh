#!/usr/bin/env bash
# `sudo` recusa (a máquina dela tem `NOPASSWD: ALL`, e um teste que chama sudo
# ali escreve em /usr — já custou restauração à mão duas vezes).
#
#   0 = passou · 1 = falhou · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$*" >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

TMP="$(mktemp -d)" || { printf 'erro: mktemp\n' >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT
CASA="$TMP/casa"; FALSO="$TMP/falso"
mkdir -p "$CASA" "$FALSO" || exit 2
export DOCTOR_REGISTRO="$TMP/registro"
: > "$DOCTOR_REGISTRO"

# --- os falsos ----------------------------------------------------------------
for c in sudo pkill killall kill notify-send systemd-run pkexec; do
  cat > "$FALSO/$c" <<'FIM'
#!/bin/sh
echo "$(basename "$0") $*" >> "$DOCTOR_REGISTRO"
exit 1
FIM
  chmod 755 "$FALSO/$c"
done
# Os que respondem pergunta: o verbo de leitura vai ao programa de verdade, o
# resto é registrado e recusado.
responde() {   # $1 = programa · $2 = padrão `case` dos verbos de leitura
  cat > "$FALSO/$1" <<FIM
#!/bin/bash
real=""
IFS=: read -ra _dirs <<< "\$PATH"
for _d in "\${_dirs[@]}"; do
  [ "\$_d" = "$FALSO" ] && continue
  [ -x "\$_d/$1" ] && { real="\$_d/$1"; break; }
done
case " \$* " in
  $2) [ -n "\$real" ] && exec "\$real" "\$@"; exit 1 ;;
esac
echo "$1 \$*" >> "\$DOCTOR_REGISTRO"
exit 1
FIM
  chmod 755 "$FALSO/$1"
}
responde systemctl '*" is-active "*|*" is-enabled "*|*" is-failed "*|*" show "*|*" status "*|*" cat "*|*" list-units "*|*" list-unit-files "*|*" show-environment "*|*" --version "*'
responde gsettings '" get "*|*" get "*|" list-"*|" range "*|" describe "*|" writable "*'
responde dconf     '" read "*|" list "*|" dump "*'
# O `FindUserByName` é a pergunta do `greeter` ("qual é o objeto desta
# usuária?"); o `call` que escreve é o `SetIconFile`, e esse fica recusado.
responde busctl    '*" get-property "*|*" introspect "*|*" FindUserByName "*'

# O `kill` do bash é BUILTIN e não passa pelo PATH. Uma função exportada vence o
# builtin em todo bash filho — é o único jeito de ouvir o `kill -TERM $pid` de
# dentro de um script. O `-0` segue para o builtin: é pergunta, não sinal.
kill() {
  [ "${1:-}" = "-0" ] && { builtin kill "$@"; return; }
  echo "kill(builtin) $*" >> "$DOCTOR_REGISTRO"; return 1
}
pkill()   { echo "pkill(função) $*"   >> "$DOCTOR_REGISTRO"; return 1; }
killall() { echo "killall(função) $*" >> "$DOCTOR_REGISTRO"; return 1; }
export -f kill pkill killall

painel_real() { pgrep -x cosmic-panel 2>/dev/null | LC_ALL=C sort | paste -sd' ' -; }

# Tirar do PATH o diretório que o guarda põe a máquina dela no mesmo ramo do
# runner e do Pop!_OS limpo.
PATH_DOCTOR=""
IFS=: read -ra _dirs <<< "$PATH"
for _d in "${_dirs[@]}"; do
  case "$_d" in /usr/bin|/bin) ;; *) [ -x "$_d/starship" ] && continue ;; esac
  PATH_DOCTOR="${PATH_DOCTOR:+$PATH_DOCTOR:}$_d"
done

# --- a corrida ----------------------------------------------------------------
printf '\n--- o doctor numa casa de brinquedo ---\n'
PATH="$PATH_DOCTOR" command -v starship >/dev/null 2>&1 \
  && printf '  --   o starship está no diretório do sistema — o ramo sem starship não rodou aqui\n'
ANTES="$(painel_real)"
env PATH="$FALSO:$PATH_DOCTOR" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
  "$RAIZ/bin/meow" doctor > "$TMP/saida" 2>&1
RC=$?
DEPOIS="$(painel_real)"

# 1. a prova positiva
# [QA final da leva H, 16/10/2026: a última linha do doctor era «rode: meow
#  doctor --consertar» e passou a dizer o estado; o fim do doctor é ela.]
if [ "$RC" = "1" ] && grep -qE '^ *~~ +logo ' "$TMP/saida" \
   && grep -q 'há divergências — o conserto do doctor as acerta' "$TMP/saida"; then
  ok "o doctor rodou até o fim e acusou a casa vazia (rc=1, com a linha do logo)"
else
  falha "o doctor não chegou ao fim como devia (rc=$RC) — as outras linhas não provam nada"
  tail -5 "$TMP/saida" | sed 's/^/       /' >&2
fi

# 2. nenhum arquivo novo
novos="$(find "$CASA" -type f | sed "s|^$CASA|~|" | LC_ALL=C sort)"
if [ -z "$novos" ]; then
  ok "nenhum arquivo novo na casa de brinquedo"
else
  falha "o doctor sem --consertar escreveu $(printf '%s\n' "$novos" | grep -c .) arquivo(s):"
  printf '%s\n' "$novos" | sed 's/^/       /' >&2
fi

# 3. nenhum sinal, nenhum verbo recusado
if [ ! -s "$DOCTOR_REGISTRO" ] || ! grep -vE '^sudo ' "$DOCTOR_REGISTRO" | grep -q .; then
  ok "nenhum pkill/kill/killall, e nenhum systemctl/gsettings/dconf que escreva"
else
  falha "o doctor sem --consertar chamou o que não devia:"
  grep -vE '^sudo ' "$DOCTOR_REGISTRO" | LC_ALL=C sort | uniq -c | sed 's/^/       /' >&2
fi

# 4. o painel de verdade
if [ -z "$ANTES" ]; then
  printf '  --   sem cosmic-panel nesta máquina — o PID de verdade não foi conferido\n'
elif [ "$ANTES" = "$DEPOIS" ]; then
  ok "o cosmic-panel de verdade é o mesmo antes e depois (pid $ANTES)"
else
  falha "o cosmic-panel de verdade mudou: antes [$ANTES], depois [$DEPOIS]"
fi

# 5. o alvo do reciclo
printf '\n--- o reciclo só mira o painel desta casa ---\n'
alvos="$(HOME="$CASA" MEOW_RAIZ="$RAIZ" bash -c '
  . "$MEOW_RAIZ/lib/comum.sh" >/dev/null 2>&1
  . "$MEOW_RAIZ/lib/painel.sh" >/dev/null 2>&1
  meow_painel_desta_casa' 2>/dev/null)"
if [ -z "$alvos" ]; then
  ok "com HOME de brinquedo, meow_painel_desta_casa não devolve painel nenhum"
else
  falha "com HOME de brinquedo o reciclo miraria: $alvos"
fi
if [ -n "$ANTES" ]; then
  # A casa da SESSÃO: sob o `tests/todos.sh` o HOME é de brinquedo (P75), e
  # ele deixa a de verdade em `SUITE_CASA_REAL` — aqui só para PERGUNTAR qual
  # painel é dela, que é leitura.
  # [P78, aberto 5 da integração da onda 1: a casa da sessão é o HOME do
  #   próprio cosmic-panel de verdade, lido do ambiente dele. O
  #   `SUITE_CASA_REAL` só vale quando o `todos.sh` foi chamado da casa real;
  #   chamado de uma casa de brinquedo (como a integração rodou), ele também
  #   era de brinquedo, e o teste ficava vermelho de ambiente. Ler o HOME do
  #   processo é leitura, e é a pergunta certa: "de quem é este painel?".]
  casa_sessao="$(tr '\0' '\n' < "/proc/${ANTES%% *}/environ" 2>/dev/null | sed -n 's/^HOME=//p' | head -1)"
  meus="$(HOME="${casa_sessao:-${SUITE_CASA_REAL:-$HOME}}" MEOW_RAIZ="$RAIZ" bash -c '
    . "$MEOW_RAIZ/lib/comum.sh" >/dev/null 2>&1
    . "$MEOW_RAIZ/lib/painel.sh" >/dev/null 2>&1
    meow_painel_desta_casa' 2>/dev/null | LC_ALL=C sort | paste -sd' ' -)"
  if [ -n "$meus" ]; then
    ok "com o HOME da sessão, ele acha o painel dela (pid $meus)"
  else
    falha "com o HOME da sessão o reciclo não acha painel nenhum — a barra não releria nunca"
  fi
fi

# --- o doctor confere pela régua de quem grava — 24/09/2026 --------------------
#   O instalador grava a CLI e as unidades do autoreparo pelo `meow_escrever`,
#   que normaliza a newline final. O doctor as comparava com `cmp`, e a máquina
#   recém-instalada saía acusada: "a CLI está diferente", "diferentes das do
#   repositório: meow-doctor.service meow-doctor.timer". Aqui a casa recebe os
#   três arquivos do jeito que o instalador os escreve, e o doctor não pode
#   acusá-los.
printf '\n--- o doctor confere pela régua de quem grava ---\n'
CASA2="$TMP/casa-instalada"; mkdir -p "$CASA2/.local/bin" "$CASA2/.config/systemd/user"
printf '%s' "$(cat "$RAIZ/bin/meow")" > "$CASA2/.local/bin/meow"; chmod 755 "$CASA2/.local/bin/meow"
for u in meow-doctor.service meow-doctor.timer; do
  printf '%s' "$(cat "$RAIZ/systemd/$u")" > "$CASA2/.config/systemd/user/$u"
done
env PATH="$FALSO:$PATH_DOCTOR" HOME="$CASA2" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
  "$RAIZ/bin/meow" doctor > "$TMP/saida2" 2>&1
if grep -qE 'está diferente do bin/meow|diferentes das do repositório: .*meow-doctor' "$TMP/saida2"; then
  falha "o doctor acusou como diferente o que o instalador gravou — as duas réguas voltaram a divergir"
  grep -E 'está diferente do bin/meow|diferentes das do repositório' "$TMP/saida2" | sed 's/^/       /' >&2
else
  ok "a CLI e as unidades gravadas pelo instalador passam no doctor"
fi

printf '\n'
if [ "$ACHADOS" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2
  exit 1
fi
printf 'passou: o doctor só lê, e o sinal não sai de casa\n'
exit 0

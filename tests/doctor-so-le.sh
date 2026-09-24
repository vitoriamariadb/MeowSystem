#!/usr/bin/env bash
# doctor-so-le.sh — o `meow doctor` sem `--consertar` só lê, e sinal nenhum sai
# da casa de quem pediu.
#
# POR QUE ESTE ARQUIVO NASCEU EM 24/09/2026 (P44)
#   A revisão da P39 rodou `HOME=$(mktemp -d) meow doctor` com o `pkill` e o
#   `kill` trocados por registradores e achou as duas regras quebradas de uma
#   vez. Remedido no dia, antes do conserto:
#
#     13 arquivos na casa de brinquedo — os cinco gatos em
#        ~/.config/cosmic/logos, os dois botões do dock, o `.ansi` e o
#        `.gato-atual` do fastfetch, o `~/.local/bin/meow-fetch`, o estado do
#        logo, o manifesto e o `meow.log`;
#     1  `pkill -x cosmic-panel` — no painel da sessão de VERDADE.
#
#   As duas vinham do `chk_logo`: o `--conferir` do `logo.sh` não ligava o seco,
#   o gato "trocado" na casa vazia pedia o reciclo, e o `painel.sh reciclar`
#   derrubava o painel da máquina inteira por `pkill -x`. O defeito é anterior à
#   P39 (dev 1e7afaa); ninguém o via porque um doctor que "só lê" nunca é
#   rodado com os olhos no painel.
#
# O QUE ESTE TESTE COBRA, E A ORDEM IMPORTA
#   1. A PROVA POSITIVA: o doctor rodou até o fim e ACUSOU divergência na casa
#      vazia (sai 1, e a linha do `logo` diz o que "mudaria"). Sem ela, um doctor
#      que morresse na primeira linha também deixaria a casa limpa, e o verde
#      seria de um programa que não fez nada.
#   2. Nenhum ARQUIVO novo na casa de brinquedo. Diretório vazio não entra na
#      conta, e está dito: o `gerar_temas.py --conferir` ainda cria a pasta de
#      saída dele (fora dos arquivos da P44); arquivo, nenhum.
#   3. Nenhum SINAL: o `pkill`, o `killall` e o `kill` (o binário E o builtin do
#      bash, que não passa pelo PATH) são registradores aqui dentro. `kill -0`
#      não conta — é pergunta, não sinal.
#   4. O PID do `cosmic-panel` de verdade é o mesmo antes e depois. Só é
#      conferido onde há painel (a máquina dela); no CI a linha diz que pulou.
#   5. O reciclo mira só o painel desta casa: com um `HOME` de brinquedo, o
#      `meow_painel_desta_casa` não devolve painel nenhum.
#
# O QUE É FALSO AQUI, E POR QUÊ
#   `sudo` recusa (a máquina dela tem `NOPASSWD: ALL`, e um teste que chama sudo
#   ali escreve em /usr — já custou restauração à mão duas vezes). `systemctl`,
#   `gsettings` e `dconf` respondem às perguntas e recusam o resto: o barramento
#   é o da sessão de verdade, e a casa de brinquedo não isola o que passa por
#   ele. Um doctor que só lê não chama nenhum dos verbos recusados; se chamar, a
#   linha aparece no registro e o teste falha dizendo qual.
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
#
# O DE VERDADE SE ACHA PULANDO ESTE DIRETÓRIO, E NÃO CORTANDO O COMEÇO DO PATH.
#   A primeira versão fazia `${PATH#$FALSO:}` e contava que o PATH ainda
#   começasse por aqui. Um script no meio do caminho que ponha outro diretório
#   na frente, e o corte não corta: o `command -v` devolve o próprio falso, o
#   `exec` chama a si mesmo, e o processo gira para sempre — medido na bancada
#   em 24/09/2026, um `gsettings` falso a 72% de CPU por dez minutos.
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

# --- a corrida ----------------------------------------------------------------
printf '\n--- o doctor numa casa de brinquedo ---\n'
ANTES="$(painel_real)"
env PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
  "$RAIZ/bin/meow" doctor > "$TMP/saida" 2>&1
RC=$?
DEPOIS="$(painel_real)"

# 1. a prova positiva
if [ "$RC" = "1" ] && grep -qE '^ *~~ +logo ' "$TMP/saida" \
   && grep -q 'rode: meow doctor --consertar' "$TMP/saida"; then
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
  meus="$(MEOW_RAIZ="$RAIZ" bash -c '
    . "$MEOW_RAIZ/lib/comum.sh" >/dev/null 2>&1
    . "$MEOW_RAIZ/lib/painel.sh" >/dev/null 2>&1
    meow_painel_desta_casa' 2>/dev/null | LC_ALL=C sort | paste -sd' ' -)"
  if [ -n "$meus" ]; then
    ok "com o HOME da sessão, ele acha o painel dela (pid $meus)"
  else
    falha "com o HOME da sessão o reciclo não acha painel nenhum — a barra não releria nunca"
  fi
fi

printf '\n'
if [ "$ACHADOS" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2
  exit 1
fi
printf 'passou: o doctor só lê, e o sinal não sai de casa\n'
exit 0

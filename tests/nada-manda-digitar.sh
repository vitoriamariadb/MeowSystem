#!/usr/bin/env bash
# nada-manda-digitar.sh — saída do MeowSystem não manda a pessoa digitar o
# conserto. P79, item 5, 10/10/2026.
#
# O QUE ABRIU ISTO — o QA de uso real da P77
#   Dentro do painel, três saídas ainda eram receita de terminal:
#     · o `icones_apps_dracula.sh` (e o irmão `icones_resgatados.sh`): «para
#       ver agora… pkill -x cosmic-panel && pkill -f cosmic-app-library»;
#     · o instalador: «Para completá-las:  sudo -v && ./install.sh»;
#     · o doctor: «conserto: LEITURA_COMPILAR=1 …» e «para construir agora:
#       meow files-menu build».
#   O princípio de 09/10 é que o programa faz (ou põe o botão que faz). A tela
#   do painel tem a porta da tela inteira (`meow_tela_reler`), o «Instalar
#   tudo», o «Construir o menu da área de trabalho» e o «Consertar o que
#   estiver fora»; a saída passa a usar a porta, ou a pendência que o botão
#   resolve.
#
# O QUE ESTE TESTE COBRA
#   1. Nenhuma mensagem (`meow_info`, `meow_pula`, `meow_aviso`, `meow_muda`,
#      `meow_ok`, `meow_erro`) de `scripts/`, `lib/`, `bin/meow` ou do
#      `install.sh` carrega as quatro receitas.
#   2. As pendências novas têm botão no painel: `instalar-com-root` roda o
#      «Instalar tudo», e `leitura-applet` o «Consertar o que estiver fora».
#   3. Os dois scripts de ícone relêem a tela pela porta única, e não dizem
#      `pkill`.
#
# PORTÁTIL: grep e python3.
#   0 = passou · 1 = falhou · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ACHADOS=0
ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /' >&2; ACHADOS=$((ACHADOS + 1)); }
command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

printf '\n--- 1. nenhuma mensagem com receita de terminal ---\n'
achados="$(cd "$RAIZ" && grep -nE '^[^#]*meow_(info|pula|aviso|muda|ok|erro) .*(pkill -[xf] |sudo -v|LEITURA_COMPILAR=1|meow files-menu build)' \
             scripts/*.sh lib/*.sh bin/meow install.sh 2>/dev/null)"
if [ -z "$achados" ]; then
  ok "nenhuma mensagem manda digitar pkill, sudo -v, LEITURA_COMPILAR=1 ou meow files-menu build"
else
  falha "mensagens que mandam digitar o conserto" "$achados"
fi

printf '\n--- 2. as pendências novas têm botão ---\n'
saida="$(env -i PATH="$PATH" HOME="$(mktemp -d)" python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
for p in ("instalar-com-root", "leitura-applet"):
    print("%s=%s" % (p, servidor.ACAO_DA_PENDENCIA.get(p, "")))
PY
)"
if grep -qx 'instalar-com-root=instalar' <<< "$saida" && grep -qx 'leitura-applet=doctor_consertar' <<< "$saida"; then
  ok "instalar-com-root -> «Instalar tudo», leitura-applet -> «Consertar o que estiver fora»"
else
  falha "as pendências novas não têm botão no painel" "$saida"
fi

printf '\n--- 3. os scripts de ícone relêem a tela pela porta única ---\n'
faltam=""
for s in icones_apps_dracula.sh icones_resgatados.sh; do
  grep -qE '^[^#]*meow_tela_reler' "$RAIZ/scripts/$s" || faltam+=" $s"
done
if [ -z "$faltam" ]; then
  ok "o icones_apps_dracula.sh e o icones_resgatados.sh chamam o meow_tela_reler"
else
  falha "sem a porta única da tela:$faltam"
fi

printf '\n--- 4. a pendência do applet nasce sem compilar e sai sem applet pedido ---\n'
#   [Conferência da P79: com `LEITURA_APPLET="nao"` a pendência de uma passagem
#    anterior ficava na Início para sempre, pedindo um applet que ninguém quer.]
CASA="$(mktemp -d)" || exit 2
trap 'rm -rf "$CASA"' EXIT
FALSO="$CASA/falso"; mkdir -p "$FALSO"
for c in sudo pkexec su pkill killall notify-send systemd-run loginctl apt apt-get cargo; do
  printf '#!/bin/sh\nexit 1\n' > "$FALSO/$c"; chmod 755 "$FALSO/$c"
done
applet() {  # <sim|nao>
  env -i PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 LEITURA_APPLET="$1" \
    "$RAIZ/scripts/leitura_build.sh" --aplicar > /dev/null 2>&1
}
TSV="$CASA/.local/state/meowsystem/pendencias.tsv"
applet sim; com="$(cut -f1 "$TSV" 2>/dev/null)"
applet nao; sem="$(cut -f1 "$TSV" 2>/dev/null)"
if grep -qx 'leitura-applet' <<< "$com" && ! grep -qx 'leitura-applet' <<< "$sem"; then
  ok "sem compilar, a pendência leitura-applet nasce; com LEITURA_APPLET=nao, ela sai"
else
  falha "a pendência do applet não nasce ou não sai" "com: $com / sem: $sem"
fi

printf '\n'
[ "$ACHADOS" -eq 0 ] || { printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2; exit 1; }
printf 'passou: nada manda digitar\n'
exit 0

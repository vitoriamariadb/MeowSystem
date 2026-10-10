#!/usr/bin/env bash
# leitura-fonte-unica.sh — o modo de leitura tem UMA fonte de verdade (P77, 10/10/2026).
#
# O DEFEITO QUE ESTE ARQUIVO VIGIA (achado 26 do uso real de 09/10)
#   O painel dizia 3500 K e «Sim», a máquina estava em 6300 K e «Não», e o
#   cartão prometia «Salvar e aplicar faz este ajuste vencer». Não fazia: o
#   `leitura.sh` lê primeiro o que o applet da barra guarda (o ponto dos
#   sliders no estado dele, a agenda e o horário no CosmicComp), e o meow.conf
#   é o padrão de fábrica. O painel lia a tela deste minuto e procurava o
#   horário num nome que o applet não grava (`leitura_horario_inicio`).
#
# O QUE ELE CONFERE
#   1. O `meow leitura adotar CHAVE...` põe o valor do meow.conf no lugar que o
#      applet guarda — a mesma casa onde o `leitura.sh` lê —, e não escreve o
#      que os portões dele recusariam (kelvin fora da faixa) nem o vazio da
#      agenda («não toca»).
#   2. O servidor lê esses mesmos lugares (`_valendo_agora`): o ponto do slider,
#      e não o zero da tela de dia; `leitura_hora_inicio`, e não o nome errado.
#   3. O «Salvar e aplicar» chama o `adotar` com as chaves do modo de leitura
#      que ele leva (conferido na fonte do servidor: a rota é uma só).
#
# NADA SAI DA CASA DE BRINQUEDO: `env -i`, HOME temporário com o COSMIC e o
#   estado dentro dela, e um `sudo` falso na frente do PATH.
#
#   0 = passou · 1 = falhou · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /' >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3, que é quem lê o servidor\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
CASA="$T/casa"; FALSO="$T/falso"
mkdir -p "$CASA/.config/meow" "$FALSO"
printf '#!/bin/sh\necho "sudo falso: $*" >&2\nexit 1\n' > "$FALSO/sudo"; chmod +x "$FALSO/sudo"
CONF="$CASA/.config/meow/meow.conf"
cp "$RAIZ/meow.conf.exemplo" "$CONF"
sed -i -e 's/^LEITURA_TEMPERATURA="[^"]*"/LEITURA_TEMPERATURA="4200"/' \
       -e 's/^LEITURA_HORARIO_INICIO="[^"]*"/LEITURA_HORARIO_INICIO="19:30"/' \
       -e 's/^LEITURA_AGENDA="[^"]*"/LEITURA_AGENDA="nao"/' "$CONF"
ESTADO_APPLET="$CASA/.local/state/cosmic/com.meowsystem.AppletLeitura/v1"
COMP="$CASA/.config/cosmic/com.system76.CosmicComp/v1"

casa() { env -i PATH="$FALSO:/usr/bin:/bin" HOME="$CASA" LANG=C.UTF-8 MEOW_CONF="$CONF" \
           MEOW_ESTADO="$CASA/.local/state/meowsystem" "$@"; }

# --- 1. o adotar escreve onde o applet guarda --------------------------------
saida="$(casa "$RAIZ/bin/meow" leitura adotar LEITURA_TEMPERATURA LEITURA_HORARIO_INICIO LEITURA_AGENDA 2>&1)"; rc=$?
lido() { tr -d '\n' < "$1" 2>/dev/null; }
if [ "$rc" -le 1 ] && [ "$(lido "$ESTADO_APPLET/ultima_temperatura")" = "4200" ] \
   && [ "$(lido "$COMP/leitura_hora_inicio")" = '"19:30"' ] \
   && [ "$(lido "$COMP/leitura_agenda")" = "false" ]; then
  ok "o adotar põe a temperatura, o horário e a agenda do meow.conf onde o applet os guarda"
else
  falha "o adotar não escreveu onde o applet guarda (rc=$rc)" "$saida"
fi

sed -i -e 's/^LEITURA_TEMPERATURA="[^"]*"/LEITURA_TEMPERATURA="9000"/' \
       -e 's/^LEITURA_AGENDA="[^"]*"/LEITURA_AGENDA=""/' "$CONF"
casa "$RAIZ/bin/meow" leitura adotar LEITURA_TEMPERATURA LEITURA_AGENDA >/dev/null 2>&1
if [ "$(lido "$ESTADO_APPLET/ultima_temperatura")" = "4200" ] && [ "$(lido "$COMP/leitura_agenda")" = "false" ]; then
  ok "kelvin fora da faixa e agenda vazia («não toca») não são escritos"
else
  falha "o adotar escreveu o que o leitura.sh recusaria" \
        "ultima_temperatura=$(lido "$ESTADO_APPLET/ultima_temperatura") leitura_agenda=$(lido "$COMP/leitura_agenda")"
fi

# --- 2. o servidor lê os mesmos lugares ---------------------------------------
printf '0' > "$COMP/leitura_temperatura"     # a tela de dia: desligada
saida="$(casa MEOW_RAIZ="$RAIZ" python3 - "$RAIZ" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
v = {c: servidor._valendo_agora(c) for c in
     ("LEITURA_TEMPERATURA", "LEITURA_HORARIO_INICIO", "LEITURA_AGENDA", "LEITURA_RAMPA_MIN")}
esperado = {"LEITURA_TEMPERATURA": "4200", "LEITURA_HORARIO_INICIO": "19:30",
            "LEITURA_AGENDA": "nao", "LEITURA_RAMPA_MIN": None}
print(v)
sys.exit(0 if v == esperado else 1)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o servidor lê o ponto do slider (e não a tela de dia), o horário e a agenda do applet" \
  || falha "o servidor não lê onde o applet guarda" "$saida"

# --- 3. o «Salvar e aplicar» chama o adotar -----------------------------------
if grep -q '_meow("leitura", "adotar"' "$RAIZ/app/servidor.py" \
   && grep -q 'adotar) shift; "$RAIZ/scripts/leitura.sh" adotar' "$RAIZ/bin/meow"; then
  ok "o «Salvar e aplicar» do painel passa as escolhas do modo de leitura ao applet"
else
  falha "o «Salvar e aplicar» não chama mais o adotar"
fi

[ "$ACHADOS" -eq 0 ] && { printf 'ok: o modo de leitura tem uma fonte de verdade\n'; exit 0; }
exit 1

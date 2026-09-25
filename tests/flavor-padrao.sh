#!/usr/bin/env bash
# flavor-padrao.sh — o flavor padrão é uma regra só (P61, 25/09/2026).
#
# O DEFEITO QUE ESTE ARQUIVO VIGIA
#   Com o FLAVOR vazio no meow.conf, a página cai no flavor padrão do pack no ar
#   (P56, o `flavorEmVigor` do app/pagina/app.js), e oito scripts caíam no
#   `${FLAVOR:-mocha}` de cada um — o padrão de UM pack: `fzf`,
#   `completar_icones`, `greeter`, `midia`, `construir_icones`, `logo`,
#   `icones_apps_arcticons` e `terminal`. O `bin/meow` perguntava ao pack e, sem
#   resposta, também caía no `mocha`; e o `meow icones` mostrava `pastas
#   cat--mauve`, o molde do meow.conf expandido com o FLAVOR ainda vazio.
#   Medido com o Dracula no ar e `FLAVOR=""`, numa casa de brinquedo:
#     fzf.sh conferir       a paleta packs/dracula/paleta.json não tem FLAVOR="mocha"
#     terminal.sh conferir  FLAVOR="mocha" não é um flavor da paleta do pack no ar
#     midia.sh --conferir   a cor "mauve" não existe na paleta mocha
#   (A sprint contava nove scripts, com o `wallpaper.sh`; nele o
#   `${FLAVOR:-mocha}` só sobrevive num comentário — a P40 o trocou pelo
#   `meow_pack_dir`.)
#
# O QUE ELE CONFERE
#   1. Nenhum script de `scripts/` nem o `bin/meow` tem um `${FLAVOR:-<nome>}`
#      próprio fora de comentário: a regra é o `meow_flavor` do lib/comum.sh.
#   2. O `meow_flavor` devolve o FLAVOR quando há um e, vazio, o
#      `paleta.flavor_padrao` do pack no ar — lido do pack.json de cada pack, e
#      não escrito aqui. Sem resposta do pack.py, avisa e devolve vazio: nenhum
#      nome de reserva.
#   3. De ponta a ponta: com o FLAVOR vazio, o `fzf.sh`, o `terminal.sh` e o
#      `midia.sh` conferem EXATAMENTE como com o flavor padrão do pack escrito, e
#      o `meow icones` diz a variante das pastas com ele.
#
# NADA SAI DA CASA DE BRINQUEDO: `env -i`, HOME temporário, os três scripts no
#   modo que só lê, e um `sudo` falso na frente do PATH — nenhum deles chama
#   sudo, e o falso existe para que nenhum passe a chamar calado numa máquina
#   com `NOPASSWD`.
#
#   0 = passou · 1 = falhou · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /' >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3, que é quem responde o pack no ar\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
printf '#!/bin/sh\nprintf "sudo: recusado pelo tests/flavor-padrao.sh\\n" >&2\nexit 1\n' > "$FALSO/sudo"
chmod 755 "$FALSO/sudo"

# O flavor padrão de um pack, lido do pack.json dele — a resposta que o teste
# espera, sem passar pelo código que ele confere.
padrao_de() {   # $1 = o diretório do pack
  python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["paleta"]["flavor_padrao"])' \
    "$1/pack.json"
}
DIR_PADRAO="$(env -i PATH="$PATH" HOME="$T/casa" MEOW_RAIZ="$RAIZ" \
                bash -c '. "$MEOW_RAIZ/lib/comum.sh" && meow_pack_padrao_dir' 2>/dev/null)"
[ -f "$DIR_PADRAO/pack.json" ] || { printf 'erro: o pack.py não disse o pack padrão\n' >&2; exit 2; }
PADRAO="$(padrao_de "$DIR_PADRAO")"
DRACULA="$(padrao_de "$RAIZ/packs/dracula")"

# --- 1. nenhum script tem o padrão dele ---------------------------------------
printf '\n--- 1. nenhum script tem o flavor padrão dele ---\n'
# O `${FLAVOR:-}` vazio (repassar) e o `${FLAVOR:-$(…)}` (ler o conf) não são
# padrão de flavor; o que se caça é um NOME depois do `:-`. Comentário não conta:
# o do wallpaper.sh cita o `${FLAVOR:-mocha}` que a P40 tirou.
cravados() {
  grep -nE '\$\{FLAVOR:-[^}$]' "$RAIZ"/scripts/*.sh "$RAIZ/bin/meow" \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#'
}
if cravados >/dev/null; then
  falha "há script com o flavor padrão dele, e não o do pack no ar:" "$(cravados | sed "s|$RAIZ/||")"
else
  ok "nenhum script de scripts/ nem o bin/meow tem um \${FLAVOR:-<nome>} fora de comentário"
fi

# --- 2. o meow_flavor ----------------------------------------------------------
printf '\n--- 2. o meow_flavor responde o pack no ar ---\n'
# Um pack de brinquedo cujo padrão NÃO é o primeiro flavor da paleta: a resposta
# tem de ser o que o pack.json declara, e não a primeira chave que aparecer.
PACKS="$T/packs"; mkdir -p "$PACKS/brinquedo"
cp "$RAIZ/packs/dracula/logo.svg" "$RAIZ/packs/dracula/paleta.json" "$PACKS/brinquedo/"
printf '{"formato": 1, "id": "brinquedo", "nome": "Brinquedo", "heranca": "catppuccin",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "alucard"}, "vitrine": {"capa": "logo.svg"}}\n' \
  > "$PACKS/brinquedo/pack.json"
flavor_de() {   # $1 = PACK · $2 = FLAVOR · resto = VAR=valor
  local p="$1" f="$2"; shift 2
  env -i PATH="$FALSO:$PATH" HOME="$T/casa" NO_COLOR=1 MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" \
    PACK="$p" FLAVOR="$f" "$@" bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 9; meow_flavor' 2>&1
}
divergem=""
for caso in "||$PADRAO" "dracula||$DRACULA" "brinquedo||$(padrao_de "$PACKS/brinquedo")" \
            "dracula|alucard|alucard" "|latte|latte"; do
  IFS='|' read -r p f quer <<< "$caso"
  tem="$(flavor_de "$p" "$f")"; rc=$?
  [ "$rc" = 0 ] && [ -n "$quer" ] && [ "$tem" = "$quer" ] \
    || divergem+=" PACK='$p' FLAVOR='$f': rc=$rc, veio '$tem', o pack diz '$quer';"
done
[ -z "$divergem" ] \
  && ok "o FLAVOR do conf vence; vazio, vale o flavor_padrao do pack no ar ($PADRAO, $DRACULA e o alucard do brinquedo)" \
  || falha "o meow_flavor não responde o pack no ar:$divergem"
# Sem resposta: um `python3` que sai 1 na frente do PATH.
mkdir -p "$T/sem-py"; printf '#!/bin/sh\nexit 1\n' > "$T/sem-py/python3"; chmod 755 "$T/sem-py/python3"
saida="$(env -i PATH="$T/sem-py:$FALSO:$PATH" HOME="$T/casa" NO_COLOR=1 MEOW_RAIZ="$RAIZ" PACK=dracula FLAVOR= \
           bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 9; f="$(meow_flavor)"; rc=$?; printf "[%s] rc=%s\n" "$f" "$rc"' 2>&1)"
[[ "$saida" == *"[] rc=1"* ]] && [[ "$saida" == *"flavor padrão"* ]] && [[ "$saida" != *mocha* ]] \
  && ok "sem resposta do pack.py, o meow_flavor avisa e devolve vazio, sem nome de reserva" \
  || falha "sem resposta do pack.py o meow_flavor calou, ou inventou um flavor" "$saida"

# --- 3. de ponta a ponta -------------------------------------------------------
printf '\n--- 3. o FLAVOR vazio confere igual ao padrão do pack escrito ---\n'
# Os três no modo que só lê, na mesma casa: a saída com o FLAVOR vazio tem de
# ser a mesma, letra por letra, da saída com o flavor padrão do pack escrito.
roda() {   # $1 = PACK · $2 = FLAVOR · $3... = o script e o verbo
  local p="$1" f="$2"; shift 2
  env -i PATH="$FALSO:$PATH" HOME="$T/casa-e2e" NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
    PACK="$p" FLAVOR="$f" ACCENT=mauve MIDIA_COR_TITULO=mauve bash "$RAIZ/scripts/$@" 2>&1
}
mkdir -p "$T/casa-e2e"
diferentes=""
for pack in dracula ""; do
  quer_flavor="$DRACULA"; [ -n "$pack" ] || quer_flavor="$PADRAO"
  for chamada in "fzf.sh conferir" "terminal.sh conferir" "midia.sh --conferir"; do
    # shellcheck disable=SC2086  # o script e o verbo, separados de propósito
    vazio="$(roda "$pack" "" $chamada)"; rc_v=$?
    # shellcheck disable=SC2086
    escrito="$(roda "$pack" "$quer_flavor" $chamada)"; rc_e=$?
    [ "$vazio" = "$escrito" ] && [ "$rc_v" = "$rc_e" ] \
      || diferentes+=$'\n'"PACK='$pack' $chamada: vazio rc=$rc_v [$(printf '%s' "$vazio" | head -2 | tr '\n' ' ')] x $quer_flavor rc=$rc_e [$(printf '%s' "$escrito" | head -2 | tr '\n' ' ')]"
  done
done
[ -z "$diferentes" ] \
  && ok "fzf, terminal e mídia com o FLAVOR vazio fazem o que fazem com o padrão do pack ($DRACULA com o Dracula, $PADRAO com o padrão)" \
  || falha "com o FLAVOR vazio, algum script não usou o padrão do pack no ar:" "${diferentes#$'\n'}"

# O `meow icones` com um meow.conf de FLAVOR vazio: a linha das pastas diz a
# variante com o flavor padrão do pack, e não o molde `cat--mauve`.
mkdir -p "$T/casa-meow/.config/meow"
sed -e 's/^FLAVOR="[^"]*"/FLAVOR=""/' -e 's/^PACK="[^"]*"/PACK="dracula"/' "$RAIZ/meow.conf.exemplo" \
  > "$T/casa-meow/.config/meow/meow.conf"
grep -qx 'FLAVOR=""' "$T/casa-meow/.config/meow/meow.conf" && grep -qx 'PACK="dracula"' "$T/casa-meow/.config/meow/meow.conf" \
  || { printf 'erro: o meow.conf.exemplo mudou a forma das linhas FLAVOR/PACK\n' >&2; exit 2; }
saida="$(env -i PATH="$FALSO:$PATH" HOME="$T/casa-meow" USER=t NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
           XDG_CONFIG_HOME="$T/casa-meow/.config" XDG_DATA_HOME="$T/casa-meow/.local/share" \
           bash "$RAIZ/bin/meow" icones 2>&1)"
linha="$(printf '%s\n' "$saida" | grep -E '^[[:space:]]+pastas[[:space:]]' | head -1 | awk '{print $2}')"
[ "$linha" = "cat-$DRACULA-mauve" ] \
  && ok "o meow icones, com o FLAVOR vazio e o Dracula no ar, diz pastas $linha" \
  || falha "o meow icones diz pastas '$linha', e o pack no ar pede cat-$DRACULA-mauve" "$(printf '%s\n' "$saida" | head -8)"
[ ! -e "$T/casa-e2e/.config" ] && [ ! -e "$T/casa-meow/.local/share/icons" ] \
  && ok "nada foi escrito nas casas de brinquedo" \
  || falha "os conferir escreveram na casa de brinquedo" "$(find "$T/casa-e2e" "$T/casa-meow/.local" -mindepth 1 2>/dev/null | head)"

printf '\n'
if [ "$ACHADOS" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2
  exit 1
fi
printf 'passou: o flavor padrão é o do pack no ar, numa regra só\n'
exit 0

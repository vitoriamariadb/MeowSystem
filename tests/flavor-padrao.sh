#!/usr/bin/env bash
# flavor-padrao.sh — o flavor padrão é uma regra só. `sudo` falso na frente do
# PATH: com `NOPASSWD`, o de verdade escreveria no sistema.
# `env -i`, HOME temporário e um `sudo` falso na frente do PATH: nada sai da casa
# de brinquedo, nem numa máquina com `NOPASSWD`.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /' >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3, que é quem responde o pack no ar\n'; exit 0; }
# O python3 de verdade, por caminho: a 4 põe um que sai 1 na frente do PATH do
# shell que o painel abre, e o próprio teste continua precisando do de verdade.
#
# Numa bancada com pyenv o primeiro `python3` do PATH é o shim, e o shim põe a
# pasta da versão na FRENTE do PATH do processo que ele abre: o shell do painel
# achava o python3 de verdade antes do falso da 4, e o caso «sem resposta» saía
# vermelho sem defeito nenhum no painel.
PY="$(python3 -c 'import sys; print(sys.executable)')"

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
# padrão de flavor; o que se caça é um NOME depois do `:-`.
cravados() {
  grep -nE '\$\{FLAVOR:-[^}$]' "$RAIZ"/scripts/*.sh "$RAIZ/bin/meow" \
       "$RAIZ"/scripts/temas-de-apps/*/manifesto.sh "$RAIZ/app/servidor.py" \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#'
}
if cravados >/dev/null; then
  falha "há script com o flavor padrão dele, e não o do pack no ar:" "$(cravados | sed "s|$RAIZ/||")"
else
  ok "nenhum script, manifesto de aplicativo, o bin/meow ou o painel tem um \${FLAVOR:-<nome>} fora de comentário"
fi
# O cabeçalho de uso é o que se lê para rodar o script à mão: um `FLAVOR="mocha"`
# ali ensina o padrão de um pack como se fosse o do script.
usos="$(grep -nE '^#[[:space:]]+FLAVOR="[^"]+"' "$RAIZ"/scripts/*.sh | sed "s|$RAIZ/||")"
[ -z "$usos" ] \
  && ok "nenhum cabeçalho de uso dá um flavor de pack como o padrão do script" \
  || falha "há cabeçalho de uso com o flavor de um pack:" "$usos"

# --- 2. o meow_flavor ----------------------------------------------------------
printf '\n--- 2. o meow_flavor responde o pack no ar ---\n'
# Um pack de brinquedo cujo padrão NÃO é o primeiro flavor da paleta: a resposta
# tem de ser o que o pack.json declara, e não a primeira chave que aparecer.
PACKS="$T/packs"; mkdir -p "$PACKS/brinquedo"
cp "$RAIZ/packs/dracula/logo.svg" "$RAIZ/packs/dracula/paleta.json" "$PACKS/brinquedo/"
printf '{"formato": 1, "id": "brinquedo", "nome": "Brinquedo", "heranca": "catppuccin",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "alucard"}, "vitrine": {"capa": "logo.svg"}}\n' \
  > "$PACKS/brinquedo/pack.json"
# A paleta é a do Dracula com o `alucard` na frente: o primeiro não é o padrão
# de pack nenhum daqui, então a resposta certa só sai da queda, e não de um
# padrão emprestado.
mkdir -p "$PACKS/sem-padrao"
cp "$RAIZ/packs/dracula/logo.svg" "$PACKS/sem-padrao/"
"$PY" - "$RAIZ/packs/dracula/paleta.json" "$PACKS/sem-padrao/paleta.json" <<'PYFIM' || exit 2
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["flavors"] = {f: d["flavors"][f] for f in sorted(d["flavors"], key=lambda f: f != "alucard")}
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
PYFIM
printf '{"formato": 1, "id": "sem-padrao", "nome": "Sem Padrão", "heranca": "catppuccin",
 "paleta": {"arquivo": "paleta.json"}, "vitrine": {"capa": "logo.svg"}}\n' \
  > "$PACKS/sem-padrao/pack.json"
# O primeiro flavor da paleta, lido do arquivo — a resposta esperada da queda.
SEM_PADRAO="$("$PY" -c 'import json, sys; print(next(iter(json.load(open(sys.argv[1], encoding="utf-8"))["flavors"])))' \
  "$PACKS/sem-padrao/paleta.json")"
flavor_de() {   # $1 = PACK · $2 = FLAVOR · resto = VAR=valor
  local p="$1" f="$2"; shift 2
  env -i PATH="$FALSO:$PATH" HOME="$T/casa" NO_COLOR=1 MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" \
    PACK="$p" FLAVOR="$f" "$@" bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 9; meow_flavor' 2>&1
}
divergem=""
for caso in "||$PADRAO" "dracula||$DRACULA" "brinquedo||$(padrao_de "$PACKS/brinquedo")" \
            "dracula|alucard|alucard" "|latte|latte" "sem-padrao||$SEM_PADRAO"; do
  IFS='|' read -r p f quer <<< "$caso"
  # O `2>&1` do `flavor_de` é de propósito: um aviso junto da resposta também
  # diverge — quem respondeu não pode sair acusado de não ter respondido.
  tem="$(flavor_de "$p" "$f")"; rc=$?
  [ "$rc" = 0 ] && [ -n "$quer" ] && [ "$tem" = "$quer" ] \
    || divergem+=" PACK='$p' FLAVOR='$f': rc=$rc, veio '$tem', o pack diz '$quer';"
done
[ -z "$divergem" ] \
  && ok "o FLAVOR do conf vence; vazio, vale o flavor_padrao do pack no ar ($PADRAO, $DRACULA e o alucard do brinquedo), e sem ele o primeiro da paleta ($SEM_PADRAO), sem aviso" \
  || falha "o meow_flavor não responde o pack no ar:$divergem"
# Os dois manifestos de aplicativo que tinham o `mocha` deles (P65): o flavor
# com que o módulo trabalha, lido depois do `source`, como o runner o carrega.
divergem=""
for caso in "btop-bat|_bb_flavor" "spotify|printf %s \"\$_SPOT_FLAVOR\""; do
  IFS='|' read -r modulo pergunta <<< "$caso"
  for par in "dracula|$DRACULA" "sem-padrao|$SEM_PADRAO"; do
    tem="$(env -i PATH="$FALSO:$PATH" HOME="$T/casa" NO_COLOR=1 MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" \
             MEOW_ESTADO="$T/estado" PACK="${par%%|*}" FLAVOR= \
             bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 9
                      . "$MEOW_RAIZ/scripts/temas-de-apps/$0/manifesto.sh" >/dev/null || exit 9
                      eval "$1"' "$modulo" "$pergunta" 2>&1)"
    [ "$tem" = "${par#*|}" ] || divergem+=" $modulo com PACK='${par%%|*}': veio '$tem', a regra diz '${par#*|}';"
  done
done
[ -z "$divergem" ] \
  && ok "o btop-bat e o spotify, com o FLAVOR vazio, trabalham no flavor do meow_flavor ($DRACULA e $SEM_PADRAO)" \
  || falha "um manifesto de aplicativo tem o flavor padrão dele:$divergem"
# Sem resposta: um `python3` que sai 1 na frente do PATH.
mkdir -p "$T/sem-py"; printf '#!/bin/sh\nexit 1\n' > "$T/sem-py/python3"; chmod 755 "$T/sem-py/python3"
saida="$(env -i PATH="$T/sem-py:$FALSO:$PATH" HOME="$T/casa" NO_COLOR=1 MEOW_RAIZ="$RAIZ" PACK=dracula FLAVOR= \
           bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 9; f="$(meow_flavor)"; rc=$?; printf "[%s] rc=%s\n" "$f" "$rc"' 2>&1)"
[[ "$saida" == *"[] rc=1"* ]] && [[ "$saida" == *"flavor padrão"* ]] && [[ "$saida" != *mocha* ]] \
  && ok "sem resposta do pack.py, o meow_flavor avisa e devolve vazio, sem nome de reserva" \
  || falha "sem resposta do pack.py o meow_flavor calou, ou inventou um flavor" "$saida"
# O único script sob `set -e` que chama o `meow_flavor` (P65): o 1 de «sem
# resposta» matava o `icones_apps_arcticons.sh` na própria atribuição, e a tela
# ficava só com o aviso do `meow_flavor`, sem saber quem parou nem o que ficou
# por fazer. Ele tem de dizer por quê, com a frase dele, e sair 2.
saida="$(env -i PATH="$T/sem-py:$FALSO:$PATH" HOME="$T/casa-arc" NO_COLOR=1 MEOW_RAIZ="$RAIZ" PACK=dracula FLAVOR= \
           bash "$RAIZ/scripts/icones_apps_arcticons.sh" --conferir 2>&1)"; rc=$?
[ "$rc" = 2 ] && printf '%s\n' "$saida" | grep -qE '^  erro .*aplicativos em traço' \
  && ok "sem flavor, o icones_apps_arcticons.sh diz por que parou, com a frase dele (rc=2)" \
  || falha "sem flavor, o icones_apps_arcticons.sh morreu calado sob o set -e (rc=$rc)" "$saida"

# --- 3. de ponta a ponta -------------------------------------------------------
printf '\n--- 3. o FLAVOR vazio confere igual ao padrão do pack escrito ---\n'
# Os três no modo que só lê, na mesma casa: a saída com o FLAVOR vazio tem de
# ser a mesma, letra por letra, da saída com o flavor padrão do pack escrito.
#   [P65: e o pack sem `paleta.flavor_padrao`, que cai no primeiro da paleta,
#   e o `icones_apps_arcticons.sh`, que sob o `set -e` morria com ele.]
roda() {   # $1 = PACK · $2 = FLAVOR · $3... = o script e o verbo
  local p="$1" f="$2"; shift 2
  env -i PATH="$FALSO:$PATH" HOME="$T/casa-e2e" NO_COLOR=1 MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" \
    PACK="$p" FLAVOR="$f" ACCENT=mauve MIDIA_COR_TITULO=mauve bash "$RAIZ/scripts/$@" 2>&1
}
mkdir -p "$T/casa-e2e"
diferentes=""
for pack in dracula "" sem-padrao; do
  case "$pack" in
    dracula)    quer_flavor="$DRACULA" ;;
    sem-padrao) quer_flavor="$SEM_PADRAO" ;;
    *)          quer_flavor="$PADRAO" ;;
  esac
  for chamada in "fzf.sh conferir" "terminal.sh conferir" "midia.sh --conferir" \
                 "icones_apps_arcticons.sh --conferir"; do
    # shellcheck disable=SC2086  # o script e o verbo, separados de propósito
    vazio="$(roda "$pack" "" $chamada)"; rc_v=$?
    # shellcheck disable=SC2086
    escrito="$(roda "$pack" "$quer_flavor" $chamada)"; rc_e=$?
    [ "$vazio" = "$escrito" ] && [ "$rc_v" = "$rc_e" ] \
      || diferentes+=$'\n'"PACK='$pack' $chamada: vazio rc=$rc_v [$(printf '%s' "$vazio" | head -2 | tr '\n' ' ')] x $quer_flavor rc=$rc_e [$(printf '%s' "$escrito" | head -2 | tr '\n' ' ')]"
  done
done
[ -z "$diferentes" ] \
  && ok "fzf, terminal, mídia e o traço dos aplicativos com o FLAVOR vazio fazem o que fazem com o padrão do pack ($DRACULA com o Dracula, $PADRAO com o padrão, $SEM_PADRAO com o pack sem padrão declarado)" \
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

# --- 4. o painel dá aos trabalhos o mesmo FLAVOR — P65 ------------------------
printf '\n--- 4. o painel dá aos trabalhos o flavor da mesma regra ---\n'
# O `conf_exportada` (app/servidor.py) é o meow.conf que um trabalho do painel
# recebe. Ele tinha a pergunta dele ao pack.py, sem a queda do primeiro flavor,
# com o `mocha` de reserva — e deixava o molde das pastas em `cat--mauve`, que o
# `carregar_conf` do bin/meow já completava. Com o molde de fábrica escrito no
# conf, o FLAVOR e o ICONES_PASTAS que ele dá têm de ser os do `meow_flavor`; e,
# sem resposta do pack.py (um python3 que sai 1 no PATH do shell dele), vazio,
# sem nome de reserva.
painel() {   # $1 = PACK · $2 = o PATH do shell do painel
  mkdir -p "$T/casa-painel"
  printf 'PACK="%s"\nFLAVOR=""\nACCENT="mauve"\nICONES_PASTAS="cat-${FLAVOR}-${ACCENT}"\n' "$1" \
    > "$T/painel.conf"
  env -i PATH="$2" HOME="$T/casa-painel" NO_COLOR=1 MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" \
    MEOW_CONF="$T/painel.conf" "$PY" - "$RAIZ/app" <<'PYFIM' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
c = servidor.conf_exportada() or {}
print("%s|%s|%s" % (c.get("FLAVOR", "?"), c.get("ICONES_PASTAS", "?"), c.get("LOGO", "?")))
PYFIM
}
divergem=""
for caso in "dracula|$DRACULA" "|$PADRAO" "sem-padrao|$SEM_PADRAO"; do
  IFS='|' read -r p quer <<< "$caso"
  tem="$(painel "$p" "$FALSO:$PATH")"
  [ "$tem" = "$quer|cat-$quer-mauve|$quer" ] \
    || divergem+=" PACK='$p': veio '$tem', a regra diz '$quer|cat-$quer-mauve|$quer';"
done
tem="$(painel dracula "$T/sem-py:$FALSO:$PATH")"
[ "$tem" = "|cat--mauve|" ] \
  || divergem+=" sem resposta do pack.py: veio '$tem', e o certo é vazio, sem nome de reserva;"
[ -z "$divergem" ] \
  && ok "o conf_exportada dá o FLAVOR do meow_flavor e completa o molde das pastas ($DRACULA, $PADRAO e $SEM_PADRAO); sem resposta, vazio" \
  || falha "o painel tem a regra dele para o flavor padrão:$divergem"

printf '\n'
if [ "$ACHADOS" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2
  exit 1
fi
printf 'passou: o flavor padrão é o do pack no ar, numa regra só\n'
exit 0

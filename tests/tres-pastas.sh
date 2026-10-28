#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /' >&2
          falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO" "$T/casa" "$T/xdg" "$T/packs"
for b in sudo pkexec su apt apt-get cargo just make rustup systemctl pkill; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/tres-pastas.sh\\n" >&2\nexit 1\n' "$b" > "$FALSO/$b"
  chmod 755 "$FALSO/$b"
done
amb() {
  env -i PATH="$FALSO:$PATH" HOME="$T/casa" XDG_DATA_HOME="$T/xdg" MEOW_PACKS="$T/packs" \
    USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 MEOW_RAIZ="$RAIZ" "$@"
}
pack_py() { amb python3 "$RAIZ/scripts/pack.py" "$@"; }

for id in meowsystem dracula; do
  saida="$(pack_py validar "$id" 2>&1)"; rc=$?
  dirs="$(find "$RAIZ/packs/$id/icones" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | paste -sd,)"
  sub="$(find "$RAIZ/packs/$id/icones" -mindepth 2 -type d | head -3)"
  if [ "$rc" = "0" ] && [[ "$saida" == *"formato 2"* ]] && [ -z "$sub" ] \
     && [[ "$dirs" =~ ^(apps|biblioteca|sistema)(,(apps|biblioteca|sistema))*$ ]]; then
    ok "o pack $id valida no formato 2, e o icones/ dele tem só $dirs, sem subpasta"
  else
    falha "o pack $id não está no formato de três pastas planas (rc=$rc, pastas: $dirs, subpastas: $sub)" "$saida"
  fi
done
[ ! -e "$RAIZ/packs/catppuccin" ] && [ "$(find "$RAIZ/packs" -mindepth 1 -maxdepth 1 -type d | wc -l)" = 2 ] \
  && ok "packs/ tem dois packs, e o Catppuccin mora no meowsystem" \
  || falha "packs/ não tem só os dois packs" "$(ls "$RAIZ/packs")"
sobra="$(git -C "$RAIZ" ls-files assets/icones 2>/dev/null | grep '\.svg$' | grep -v '/previa-arcticons/')"
[ -z "$sobra" ] \
  && ok "assets/icones/ não guarda mais desenho do motor (só a prévia das folhas e os originais de fábrica)" \
  || falha "sobrou desenho do motor em assets/icones/" "$(head <<<"$sobra")"

saida="$(pack_py caminho meowsystem id 2>&1)"; rc=$?
[ "$rc" = "0" ] && ok "a porta do motor aceita o meowsystem, que é o pack padrão" \
  || falha "o pack padrão não passa pela porta do motor (rc=$rc)" "$saida"
saida="$(pack_py adocao "" "" 2>&1)"
[[ "$saida" == *"pack=meowsystem"* ]] && ok "sem PACK no conf, veste o meowsystem" || falha "o padrão não é o meowsystem" "$saida"
saida="$(pack_py adocao catppuccin "" 2>&1)"
[[ "$saida" == *"pack=meowsystem"* && "$saida" != *"recusado=catppuccin"* ]] \
  && ok "PACK=catppuccin, o nome de antes, veste o meowsystem" \
  || falha "o nome de antes do pack padrão não acha o meowsystem" "$saida"
cartoes="$(amb python3 - "$RAIZ" <<'PY'
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
print(",".join(sorted(servidor._packs_no_disco())))
PY
)"
[[ ",$cartoes," == *",meowsystem,"* && ",$cartoes," == *",dracula,"* && ",$cartoes," != *",catppuccin,"* ]] \
  && ok "o painel faz um cartão para cada um dos dois packs ($cartoes)" \
  || falha "os cartões do painel não são os dois packs" "$cartoes"

cp -r "$RAIZ/packs/dracula" "$T/packs/quarta"
python3 - "$T/packs/quarta/pack.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8")); p["id"] = "quarta"
json.dump(p, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
mkdir -p "$T/packs/quarta/icones/extras"
cp "$RAIZ/packs/dracula/icones/apps/steam.svg" "$T/packs/quarta/icones/extras/"
saida="$(pack_py validar quarta 2>&1)"; rc=$?
[ "$rc" = "1" ] && [[ "$saida" == *"extras"* ]] \
  && ok "um pack de formato 2 com icones/extras/ é recusado, e a recusa nomeia a pasta" \
  || falha "a quarta pasta passou no validar (rc=$rc)" "$saida"
saida="$(pack_py caminho quarta id 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "a porta do motor segue vendo o pack com a pasta a mais (é a de quem publica que recusa)" \
  || falha "a quarta pasta tirou o pack do motor (rc=$rc)" "$saida"
rm -rf "$T/packs/quarta"

if ! command -v zstd >/dev/null 2>&1; then
  printf 'pulado: sem zstd, a sonda do .meowpack de formato 1\n'
else
V="$T/velhos"; mkdir -p "$V"
cp -r "$RAIZ/packs/dracula" "$V/velho"
( cd "$V/velho/icones" && mkdir -p autorais pastas feitos-a-mao \
  && for f in apps/*-dracula.svg apps/*-alucard.svg; do mv "$f" autorais/; done \
  && mv sistema/*.svg pastas/ && mv biblioteca/alien.svg feitos-a-mao/ && rmdir sistema )
python3 - "$V/velho" <<'PY'
import json, os, re, sys
d = sys.argv[1]
f = os.path.join(d, "pack.json")
p = json.load(open(f, encoding="utf-8"))
p["id"], p["formato"] = "velho", 1
ic = p["icones"]
ic["autorais"]["desenhos"] = "icones/autorais/"
ic["pastas"]["desenhos"] = "icones/pastas/"
ic["sistema"]["desenhos"] = "icones/pastas/"
json.dump(p, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
m = os.path.join(d, "icones", "apps.map")
t = open(m, encoding="utf-8").read()
t += "\ncom.exemplo.Velho : feitos-a-mao/alien.svg   # aponta para a pasta de antes\n"
open(m, "w", encoding="utf-8").write(t)
pr = os.path.join(d, "PROCEDENCIA.md")
t = open(pr, encoding="utf-8").read()
t = t.replace("| `icones/biblioteca/alien.svg` |", "| `icones/feitos-a-mao/alien.svg` |")
t = re.sub(r"^\| `icones/sistema/", "| `icones/pastas/", t, flags=re.M)
open(pr, "w", encoding="utf-8").write(t)
PY
antes="$(cd "$V/velho" && find icones -type f \( -name '*.svg' -o -name '*.png' \) -exec sha256sum {} + | cut -d' ' -f1 | sort | sha256sum)"
saida="$(amb env MEOW_PACKS="$V" python3 "$RAIZ/scripts/pack.py" validar velho 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o pack de formato 1, com as pastas de antes, ainda valida (o motor lê os dois)" \
  || falha "o pack de formato 1 deixou de validar (rc=$rc)" "$saida"
saida="$(cd "$T" && amb env MEOW_PACKS="$V" python3 "$RAIZ/scripts/pack.py" exportar velho 2>&1)"; rc=$?
[ "$rc" = "0" ] && [ -f "$T/velho.meowpack" ] \
  || falha "não consegui exportar o pack de formato 1 (rc=$rc)" "$saida"
saida="$(pack_py importar "$T/velho.meowpack" 2>&1)"; rc=$?
NOVO="$T/xdg/meowsystem/packs/velho"
dirs="$(find "$NOVO/icones" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | paste -sd,)"
depois="$(cd "$NOVO" 2>/dev/null && find icones -type f \( -name '*.svg' -o -name '*.png' \) -exec sha256sum {} + | cut -d' ' -f1 | sort | sha256sum)"
formato="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["formato"])' "$NOVO/pack.json" 2>/dev/null)"
if [ "$rc" = "0" ] && [ "$dirs" = "apps,biblioteca,sistema" ] && [ "$formato" = "2" ] && [ "$antes" = "$depois" ] \
   && [ -f "$NOVO/icones/apps/cosmic-term-dracula.svg" ] \
   && [ -f "$NOVO/icones/sistema/folder.svg" ] \
   && [ -f "$NOVO/icones/biblioteca/alien.svg" ] && [ -z "$(find "$NOVO/icones" -mindepth 2 -type d)" ] \
   && grep -q '^com.exemplo.Velho : biblioteca/alien.svg' "$NOVO/icones/apps.map"; then
  ok "o .meowpack de formato 1 é importado no formato 2: três pastas planas, os mesmos bytes, o mapa e o pack.json no caminho novo"
else
  falha "o .meowpack de antes não chegou convertido (rc=$rc, pastas: $dirs, formato: $formato)" "$saida"
fi
saida="$(pack_py validar velho 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o pack convertido passa no validar de quem publica, com a regra da quarta pasta" \
  || falha "o pack convertido não valida (rc=$rc)" "$saida"
saida="$(pack_py sincronizar velho 2>&1)"; rc=$?
[[ "$saida" != *"não existe no pack"* ]] \
  && ok "o PROCEDENCIA.md do convertido aponta os arquivos onde eles estão" \
  || falha "o PROCEDENCIA.md do convertido ficou com o caminho de antes" "$(printf '%s\n' "$saida" | grep 'não existe' | head -3)"
fi

for par in "assets/icones/resgatados/luna.svg:packs/dracula/icones/apps/luna.svg" \
           "assets/icones/arcticons-apps/firefox.svg:packs/meowsystem/icones/apps/firefox.svg" \
           "packs/dracula/icones/feitos-a-mao/opera.svg:$(awk -F'\t' '$1 == "packs/dracula/icones/biblioteca/feitos-a-mao/opera.svg" {print $2}' "$RAIZ/packs/CAMINHOS-DE-ANTES.tsv")" \
           "packs/dracula/icones/apps/steam.svg:packs/dracula/icones/apps/steam.svg"; do
  de="${par%%:*}"; para="${par#*:}"
  visto="$(pack_py hoje "$de" 2>&1)"
  [ "$visto" = "$para" ] \
    && ok "o caminho gravado antes ($de) vale pelo de hoje" \
    || falha "o caminho de antes $de não achou o de hoje" "veio $visto, esperava $para"
done
printf 'com.exemplo.Escolhido : assets/icones/resgatados/luna.svg\n' > "$T/escolhas.map"
saida="$(amb env MEOW_ICONES_ESCOLHAS="$T/escolhas.map" python3 "$RAIZ/scripts/pack.py" escolhas 2>&1)"
[[ "$saida" == "com.exemplo.Escolhido	$RAIZ/packs/dracula/icones/apps/luna.svg" ]] \
  && ok "a escolha do painel gravada com o caminho de antes continua valendo" \
  || falha "a escolha do painel com o caminho de antes foi perdida" "$saida"

saida="$(pack_py novo futuro 2>&1)"; rc=$?
dirs="$(find "$T/packs/futuro/icones" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | paste -sd,)"
[ "$rc" = "0" ] && [ "$dirs" = "apps,biblioteca,sistema" ] && grep -q '"formato": 2' "$T/packs/futuro/pack.json" \
  && grep -q 'icones/biblioteca/' "$T/packs/futuro/CREDITOS.md" \
  && ok "meow pack novo cria o pack no formato 2, com as três pastas, e os créditos dizem o que vai em cada uma" \
  || falha "o pack novo não nasceu com as três pastas (rc=$rc, pastas: $dirs)" "$saida"
cp -r "$RAIZ/docs/pack-minimo" "$T/packs/pack-minimo"
saida="$(pack_py validar pack-minimo 2>&1)"; rc=$?
dirs="$(find "$T/packs/pack-minimo/icones" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | paste -sd,)"
[ "$rc" = "0" ] && [ "$dirs" = "apps,biblioteca,sistema" ] \
  && ok "o pack mínimo do docs/ valida, com um desenho em cada uma das três pastas" \
  || falha "o pack mínimo do docs/ não valida (rc=$rc)" "$saida"

C7="$T/casa7"; TEMA7="$C7/.local/share/icons/MeowSystem-Icons"
mkdir -p "$TEMA7/scalable/apps" "$C7/.config/meow"
icones7() {
  env -i PATH="$FALSO:$PATH" HOME="$C7" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
    XDG_DATA_HOME="$T/xdg7" MEOW_ESTADO="$C7/estado" PACK="$1" FLAVOR="$2" ICONES_DRACULA="${DRAC7:-sim}" \
    NOME_TEMA_ICONES=MeowSystem-Icons ICONES_TEMA=MeowSystem-Icons \
    MEOW_ICONES_TRACO="${3:-$C7/sem-traco.map}" MEOW_ICONES_CONVERTIDOS="$C7/sem-conv.map" \
    bash -c '"$MEOW_RAIZ/scripts/icones_apps_dracula.sh" --aplicar; "$MEOW_RAIZ/scripts/icones_apps_arcticons.sh"' >/dev/null 2>&1
}
DEZESSETE="com.discordapp.Discord com.spotify.Client md.obsidian.Obsidian org.telegram.desktop steam org.kde.krita"
icones7 dracula dracula
encobertos=""; sem_pack=""
for n in $DEZESSETE; do
  [ -e "$TEMA7/48x48/apps/$n.svg" ] && encobertos="$encobertos $n"
  [ -f "$TEMA7/scalable/apps/$n.svg" ] || sem_pack="$sem_pack $n"
done
traco="$(find "$TEMA7/48x48/apps" -name '*.svg' 2>/dev/null | wc -l)"
[ -z "$encobertos" ] && [ -z "$sem_pack" ] && [ "$traco" -gt 0 ] \
  && ok "com o Dracula no ar, o desenho do pack veste a 48 px e no scalable ($traco nomes seguem em traço)" \
  || falha "o traço ainda encobre o desenho do pack a 48 px" "encobertos:$encobertos · sem desenho:$sem_pack · traço: $traco"
printf 'org.kde.krita:krita:pink\n' > "$C7/traco.map"
icones7 dracula dracula "$C7/traco.map"
[ -f "$TEMA7/48x48/apps/org.kde.krita.svg" ] && [ ! -e "$TEMA7/48x48/apps/com.spotify.Client.svg" ] \
  && ok "o traço que quem usa escolheu fica, e só ele" \
  || falha "a escolha de traço de quem usa não ficou, ou levou outros junto"
DRAC7=nao icones7 dracula dracula
[ -f "$TEMA7/48x48/apps/steam.svg" ] && [ -f "$TEMA7/48x48/apps/org.kde.krita.svg" ] \
  && [ ! -e "$TEMA7/scalable/apps/steam.svg" ] \
  && ok "com ICONES_DRACULA=nao o desenho do pack sai, e o traço volta a 48 px" \
  || falha "com ICONES_DRACULA=nao o nome ficou sem o desenho do pack e sem o traço"
icones7 meowsystem mocha
[ -f "$TEMA7/48x48/apps/steam.svg" ] && [ -f "$TEMA7/48x48/apps/com.spotify.Client.svg" ] \
  && ok "com o Catppuccin no ar (sem desenho de pack para eles), o traço volta" \
  || falha "sem desenho de pack, o traço não voltou"

cp -r "$RAIZ/packs/dracula" "$T/packs/malresg"
python3 - "$T/packs/malresg/pack.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8")); p["id"] = "malresg"
json.dump(p, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
printf '<svg xmlns="http://www.w3.org/2000/svg"><!-- SEGREDO-P88 --></svg>\n' > "$T/segredo.svg"
mkdir -p "$T/casa8/.local/share/icons/MeowSystem-Icons/scalable/apps"
cp "$T/segredo.svg" "$T/casa8/vitima.svg"
ln -s "$T/segredo.svg" "$T/packs/malresg/icones/apps/elo.svg"
printf '../../../../../../vitima : a : b\nelo : a : b\n' >> "$T/packs/malresg/icones/apps-resgatados.map"
saida="$(env -i PATH="$FALSO:$PATH" HOME="$T/casa8" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
  MEOW_RAIZ="$RAIZ" MEOW_PACKS="$T/packs" XDG_DATA_HOME="$T/xdg8" MEOW_ESTADO="$T/casa8/estado" \
  PACK=malresg FLAVOR=dracula ICONES_DRACULA=sim ICONES_RESGATADOS=sim NOME_TEMA_ICONES=MeowSystem-Icons \
  bash "$RAIZ/scripts/icones_resgatados.sh" --aplicar 2>&1)"
vazou="$(grep -rlF 'SEGREDO-P88' "$T/casa8/.local" 2>/dev/null | wc -l)"
fontes="$(pack_py fontes malresg 2>/dev/null | cut -f1 | grep -c '\.\.')"
if [ "$vazou" = 0 ] && [ -f "$T/casa8/vitima.svg" ] && [ "$fontes" = 0 ] \
   && [[ "$saida" == *"1 linha(s) com nome fora da forma"* ]] && [[ "$saida" == *"sem desenho"*"elo"* ]] \
   && [ -f "$T/casa8/.local/share/icons/MeowSystem-Icons/scalable/apps/luna.svg" ]; then
  ok "o mapa dos resgatados de um pack de terceiro não escreve fora do tema nem lê link para fora, e veste o resto"
else
  falha "o mapa dos resgatados alcançou fora do pack (vazou=$vazou, fontes=$fontes)" "$saida"
fi

mkdir -p "$T/casa-conv"
saida="$(env -i PATH="$PATH" HOME="$T/casa-conv" NO_COLOR=1 bash "$RAIZ/scripts/construir_convertidos.sh" --conferir 2>&1)"
if [[ "$saida" == *"convertido(s) em dia"* ]] && [[ "$saida" != *"a remover"* ]]; then
  ok "o conferir dos convertidos olha só o mapa deles, e não o resto da apps/ plana"
else
  falha "o conferir dos convertidos acusa o resto da apps/ plana" "$saida"
fi

if [ "$falhas" -gt 0 ]; then
  printf '\nFALHOU: %s achado(s)\n' "$falhas" >&2
  exit 1
fi
exit 0

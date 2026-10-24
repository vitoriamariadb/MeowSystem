#!/usr/bin/env bash
# pack-malicioso.sh — um pack de terceiro consegue ler, escrever ou rodar algo
# fora da raiz dele?
#
# HOME, XDG_DATA_HOME e MEOW_PACKS temporários; falsos de sudo, pkexec, apt e
# companhia à frente do PATH, que registram e recusam.
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

# A casa numa variável, e não como `$T/home/...`: a regra 1 do
# tests/portabilidade.sh lê `/home/<nome>/` como casa de pessoa cravada.
CASA="$T/casa"
XDG="$T/xdg"
RAIZ_DELA="$XDG/meowsystem/packs"        # a raiz 2, "o seu", onde um clone cai
SEGREDO="SEGREDO-P78-NAO-VAZA"
MARCA="$T/executou"
FORA="$T/fora"
mkdir -p "$CASA/.ssh" "$CASA/.config/meow" "$RAIZ_DELA" "$T/vazio" "$FORA/pasta" "$T/falso"
printf '%s\n' "$SEGREDO" > "$CASA/.ssh/id_ed25519"
chmod 600 "$CASA/.ssh/id_ed25519"
printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><!-- %s --></svg>\n' "$SEGREDO" \
  > "$FORA/arte.svg"
cp "$FORA/arte.svg" "$FORA/pasta/folder.svg"

# Os falsos: registram e recusam. Nenhuma sonda daqui precisa deles, e é por
# isso mesmo que estão aqui — se alguma chamar, o registro diz.
for f in sudo pkexec su apt apt-get systemd-run loginctl pkill killall notify-send \
         systemctl gsettings dconf busctl; do
  printf '#!/bin/sh\nprintf "%%s %%s\\n" "%s" "$*" >> "%s/falsos.log"\nexit 1\n' "$f" "$T" > "$T/falso/$f"
  chmod 755 "$T/falso/$f"
done

# O código plantado: cada um deixa a marca se rodar.
plantar() {   # <arquivo>
  mkdir -p "$(dirname "$1")"
  printf '#!/bin/sh\ntouch "%s"\n' "$MARCA" > "$1"
  chmod 755 "$1"
}

amb() {
  env -i PATH="$T/falso:$PATH" HOME="$CASA" USER="${USER:-t}" LANG="${LANG:-C.UTF-8}" \
      XDG_DATA_HOME="$XDG" MEOW_PACKS="$T/vazio" MEOW_RAIZ="$RAIZ" \
      MEOW_CONF="$CASA/.config/meow/meow.conf" MEOW_PONTE=/nao/existe "$@"
}

# --- os packs -----------------------------------------------------------------
# `mal` VALIDA: tudo o que ele tem de ruim é o que o `validar` não olha (nome de
# destino no mapa, linha do mapa de pastas, symlink dentro de pasta de desenho).
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
# O desenho bom é o que o painel serve: `<script>` e `onload` dentro dele.
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
# A biblioteca e os feitos à mão são pastas que a ficha do painel lista sem
# declaração no pack.json; aqui as duas são symlink para fora.
ln -s "$FORA/pasta" "$MAL/icones/biblioteca"
ln -s "$FORA/pasta" "$MAL/icones/feitos-a-mao"
plantar "$MAL/manifesto.sh"
plantar "$MAL/icones/manifesto.sh"

# `mal-alvo` NÃO VALIDA: o mapa dele aponta para fora. O desfecho certo é ele
# ser recusado inteiro (o validar já fazia isso), e a máquina vestir o padrão.
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

# `mal-campo`: os campos do pack.json apontam para fora — `..`, absoluto, e uma
# pasta que é symlink para fora.
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

# `mal-nulo` e `mal-esc`: texto de pack que não é caminho nem nome de destino,
# mas que chega a lugares que não o esperam.
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
# `mal-utf`: o pack.json não é UTF-8 (um `\x9b`, o CSI de 8 bits, solto no
# nome). O `json.load` levanta UnicodeDecodeError, e não JSONDecodeError: era o
# outro jeito de derrubar a ficha de ícone com um pack só instalado.
MAL_UTF="$RAIZ_DELA/mal-utf"
mkdir -p "$MAL_UTF"
cp "$RAIZ/packs/dracula/paleta.json" "$MAL_UTF/"
printf '{"formato": 1, "id": "mal-utf", "nome": "a\x9b[2Jb", "heranca": "dracula", "paleta": {"arquivo": "paleta.json"}, "icones": {"apps": {"desenhos": "icones/"}}}\n' \
  > "$MAL_UTF/pack.json"

# `mal-fl-ponto` e `mal-fl-barra`: o nome do flavor vira caminho de pasta e de
# traço (o `meow_flavor` o devolve cru), e o `validar` só recusava o hífen. Um
# flavor `..` e um claro `a/b` passavam.
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
fora_da_raiz() {   # as linhas de caminho da entrada que caem fora das raízes
  local l r
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    for r in "${PERMITIDAS[@]}"; do
      case "$(realpath -m -- "$l")" in "$r"/*) continue 2 ;; esac
    done
    printf '%s\n' "$l"
  done
}

# --- 1. os verbos do pack.py ---------------------------------------------------
saida="$(printf '%s\n' '../../../../../../fora/arte.svg' "$FORA/arte.svg" '~/.ssh/id_ed25519' \
           'motor:../../../../fora/arte.svg' 'pack:dracula:../../../../../fora/arte.svg' \
           'pastas/folder-elo.svg' \
         | amb python3 "$RAIZ/scripts/pack.py" alvo "$MAL/icones" 2>/dev/null > "$T/alvo.txt"
         cat "$T/alvo.txt")"
# Pelo arquivo, e não pelo `$( )`: ele come as linhas vazias do fim, que são
# justamente a resposta certa aqui.
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
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar mal-esc 2>&1; amb "$RAIZ/bin/meow" pack listar 2>&1)"
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

# A porta de saída (`meow_texto_seguro`): C1 cru que não forma UTF-8 também sai
# (`\x9b\x9b`, `\xff\x9b`, `\xe2\x9b` truncado, `\x90`/`\x9d`/`\x9e`/`\x9f`), e o
# `ě` (`\xc4\x9b`), que tem um `\x9b` de continuação, sobrevive.
saida="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"
  for c in $'"'"'\x9b\x9b[2J'"'"' $'"'"'\xff\x9b[2J'"'"' $'"'"'\xe2\x9b[2J'"'"' $'"'"'a\x90b\x9dc\x9ed\x9fe'"'"' $'"'"'\e]52;c;eA==\a'"'"'; do
    meow_texto_seguro "$c"; echo; done; meow_texto_seguro "ě" ' 2>/dev/null)"
if [ "$(printf '%s\n' "$saida" | tail -1)" = "ě" ] \
   && ! printf '%s\n' "$saida" | head -5 | LC_ALL=C grep -q $'[\x01-\x1f\x7f\x80-\x9f]'; then
  ok "meow_texto_seguro tira C0, DEL e C1 (também o cru que não é UTF-8) e deixa o ě"
else
  falha "meow_texto_seguro deixou passar controle (ou comeu o ě)" "$(printf '%s' "$saida" | od -c | head -5)"
fi

# --- 2. as escolhas do painel ----------------------------------------------------
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

# --- 3. os instaladores, com o pack 'mal' no ar ------------------------------------
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

# --- 4. o painel, com o HOME de brinquedo ---------------------------------------
( exec env -i PATH="$T/falso:$PATH" HOME="$CASA" USER="${USER:-t}" LANG="${LANG:-C.UTF-8}" \
    XDG_DATA_HOME="$XDG" MEOW_PACKS="$T/vazio" MEOW_RAIZ="$RAIZ" \
    MEOW_CONF="$CASA/.config/meow/meow.conf" MEOW_PONTE=/nao/existe PACK=mal \
    "$RAIZ/app/run.sh" --sem-abrir ) > "$T/painel.log" 2>&1 &
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
  # A ficha tem de RESPONDER, e com o pack 'mal' dentro: com a rota caída (o NUL
  # do `mal-nulo` fazia isso), o "não lista" logo abaixo passaria calado.
  printf '%s' "$glifos" | grep -q 'apps/bom.svg' \
    && ok "a ficha do painel responde com um pack de NUL e um que não é UTF-8 instalados ao lado" \
    || falha "a /api/glifos não respondeu (ou não trouxe o pack 'mal')" "$(tail -5 "$T/painel.log")"
  # [P96: o pack-base também tem um `biblioteca/folder.svg` (o glifo do Arcticons); a busca é do pack `mal`.]
  if printf '%s' "$glifos" | grep -q "mal/icones/biblioteca/folder.svg\|mal/icones/feitos-a-mao/folder.svg\|$FORA"; then
    falha "a ficha do painel lista desenho de pasta que é symlink para fora do pack"
  else
    ok "a ficha do painel não lista a biblioteca nem os feitos à mão que são symlink para fora"
  fi
  codigo="$(curl -s -o /dev/null -w '%{http_code}' -H "X-Meow-Token: $TOK" --get \
              --data-urlencode tipo=arquivo --data-urlencode "id=$MAL/icones/biblioteca/folder.svg" "$BASE/previa")"
  [ "$codigo" = 404 ] && ok "a /previa recusa o arquivo de dentro da pasta-symlink (404)" \
    || falha "a /previa serviu o arquivo de fora do pack (HTTP $codigo)"
  # O SVG com <script>: entra no `_ICONES_DECLARADOS` pela ficha acima, e é
  # servido — como imagem que não roda nada, aberto direto ou não.
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

# --- 5. código plantado no diretório de onde se chama ----------------------------
#   `python3 -c` e `python3 -` põem o diretório corrente na frente do sys.path:
#   um `json.py` na pasta de onde a pessoa roda o `meow` seria importado no
#   lugar do da biblioteca padrão.
CWD="$T/cwd"
mkdir -p "$CWD"
printf 'open("%s", "w").close()\nraise ImportError("plantado")\n' "$MARCA" > "$CWD/json.py"
cp "$CWD/json.py" "$CWD/re.py"
( cd "$CWD" && amb "$RAIZ/bin/meow" pack listar > "$T/listar.log" 2>&1 )
( cd "$CWD" && amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; PACK=mal FLAVOR= meow_flavor >/dev/null 2>&1; meow_packs_validos >/dev/null 2>&1' )
[ -e "$MARCA" ] && { falha "um json.py/re.py no diretório corrente rodou dentro do meow"; rm -f "$MARCA"; } \
  || ok "nenhum módulo plantado no diretório corrente rodou (meow pack listar, lib/comum.sh)"

# --- 5b. o tema de aplicativo só leva cor ---------------------------------------
#   O modelo de kitty e de GNOME Terminal vai inteiro para a configuração do
#   aplicativo: `shell`/`map … launch`/`geninclude` no kitty e `custom-command`
#   no perfil do GNOME Terminal são comando que roda a cada janela nova.
filtrado() {   # <app> <modelo montado> — o texto que o módulo vai escrever
  amb MEOW_PACKS="$T/vazio" bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2
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

# --- 5c. o papel de parede do pack ------------------------------------------------
#   `origens.wallpapers.repo_do_conf` vira `${!valor}` no wallpaper.sh, e a
#   curadoria (FONTES.tsv) dá o nome do arquivo e a URL que o curl baixa.
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
# A guarda do próprio wallpaper.sh, se o pack.py deixasse passar: um python3
# que responde ao verbo `wallpapers` com a chave plantada.
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
} > "$PAPEL/wallpapers/FONTES.tsv"
cat > "$T/curl/curl" <<CURL
#!/bin/sh
saida=""; url=""
while [ "\$#" -gt 0 ]; do
  case "\$1" in -o) saida="\$2"; shift ;; --max-time) shift ;; -*) ;; *) url="\$1" ;; esac
  shift
done
printf '%s\n' "\$url" >> "$T/curl.log"
[ -n "\$saida" ] && printf 'png' > "\$saida"
exit 0
CURL
chmod 755 "$T/curl/curl"; : > "$T/curl.log"
[ -z "$(adotado mal-papel)" ] \
  || falha "o pack mal-papel não validou; a sonda da curadoria não prova nada"
amb PATH="$T/curl:$T/falso:$PATH" PACK=mal-papel WALLPAPER_BASE="$T/papel-2" \
  bash "$RAIZ/scripts/wallpaper.sh" semear > "$T/papel-2.log" 2>&1
fora_papel="$(find "$T" -name 'mal-evil*' -not -path "$RAIZ_DELA/*" 2>/dev/null)"
if [ -f "$T/papel-2/ativos/bom.png" ] && [ -z "$fora_papel" ] && [ ! -e "$MARCA" ] \
   && [ "$(grep -c . "$T/curl.log")" = 1 ] && grep -qx 'https://exemplo.invalido/7.png' "$T/curl.log"; then
  ok "a curadoria do pack baixa só nome simples por https, dentro de ativos/ (7 linhas más recusadas)"
else
  falha "a curadoria do pack escreveu fora, baixou por outro esquema ou rodou comando" \
    "$(cat "$T/curl.log"; printf '%s\n' "$fora_papel"; tail -3 "$T/papel-2.log")"
fi

# --- 6. o .meowpack com script ---------------------------------------------------
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
  # O nome da entrada com sequência de terminal: as recusas listavam o nome cru.
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

# --- 7. o painel não sobe para QA na casa de verdade (decisão 8 da leva G) ----
#   O `getent` falso diz que a casa da conta É a casa de brinquedo: para o
#   `run.sh`, este HOME passa a ser o real. Assim a recusa é provada sem que o
#   teste chegue perto da casa de quem roda.
mkdir -p "$T/falso-getent"
printf '#!/bin/sh\nprintf "%%s:x:1000:1000::%%s:/bin/bash\\n" "$(id -un)" "%s"\n' "$CASA" \
  > "$T/falso-getent/getent"
chmod 755 "$T/falso-getent/getent"
timeout 20 env -i PATH="$T/falso-getent:$T/falso:$PATH" HOME="$CASA" USER="${USER:-t}" \
  LANG="${LANG:-C.UTF-8}" MEOW_RAIZ="$RAIZ" MEOW_CONF="$CASA/.config/meow/meow.conf" \
  MEOW_PONTE=/nao/existe "$RAIZ/app/run.sh" --sem-abrir > "$T/casa-real.log" 2>&1; rc=$?
if [ "$rc" = 2 ] && grep -q 'recusado' "$T/casa-real.log" && ! grep -q 'http://127' "$T/casa-real.log"; then
  ok "o run.sh --sem-abrir recusa subir o painel com o HOME da conta (sem MEOW_QA_HOME_REAL=1)"
else
  falha "o painel subiu para QA com o HOME da conta (rc=$rc)" "$(tail -3 "$T/casa-real.log")"
fi

# As outras portas para a mesma casa: o HOME vazio (o Python do painel cairia no
# `pwd`, a casa da conta) e, com um HOME de brinquedo, um `XDG_DATA_HOME`
# herdado que aponta para a casa da conta.
for caso in vazio xdg; do
  if [ "$caso" = vazio ]; then extra=(HOME=); else extra=(HOME="$T/outra" XDG_DATA_HOME="$CASA/.local/share"); fi
  timeout 20 env -i PATH="$T/falso-getent:$T/falso:$PATH" USER="${USER:-t}" \
    LANG="${LANG:-C.UTF-8}" MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/outra/meow.conf" \
    MEOW_PONTE=/nao/existe "${extra[@]}" "$RAIZ/app/run.sh" --sem-abrir > "$T/casa-real-$caso.log" 2>&1; rc=$?
  if [ "$rc" = 2 ] && ! grep -q 'http://127' "$T/casa-real-$caso.log"; then
    ok "o run.sh --sem-abrir recusa também o caso '$caso' (HOME vazio / XDG herdado da casa da conta)"
  else
    falha "o painel subiu para QA no caso '$caso' (rc=$rc)" "$(tail -3 "$T/casa-real-$caso.log")"
  fi
done

# --- 8. o desfecho, no disco inteiro do teste ---------------------------------------
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

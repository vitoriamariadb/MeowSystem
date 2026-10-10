#!/usr/bin/env bash
# pack-malicioso.sh — um pack de terceiro consegue ler, escrever ou rodar algo
# fora da raiz dele?
#
# POR QUE ESTE ARQUIVO NASCEU EM 09/10/2026 (sprint P78)
#   Seis alertas automáticos de segurança nos commits da onda 1 da leva G
#   (`scripts/pack.py` duas vezes, `scripts/icones_apps_dracula.sh`,
#   `scripts/som.sh`, `app/servidor.py` e `bin/meow`) disseram a mesma coisa de
#   seis jeitos: um pack pode vir de terceiros — por `meow pack importar`, ou
#   por `git clone` na raiz da pessoa, que é como o docs/PACKS.md ensina a
#   publicar —, e tudo o que vem de `packs/<id>/`, de um `.meowpack` ou do
#   `icones-escolhidos.map` é DADO NÃO CONFIÁVEL. O `git clone` é o caso mais
#   largo: ele traz symlink e arquivo executável, que o `importar` recusa.
#
# O QUE SE PROVA, E SÓ COM O DESFECHO
#   Cada sonda olha o que aconteceu no disco e na saída, e não o mecanismo:
#   "a linha foi pulada" ou "o pack foi recusado inteiro" passam igual, desde
#   que nada saia da raiz. O que não pode passar:
#     1. ler fora da raiz: um segredo em `~/.ssh` e um `.svg` fora da raiz
#        trazem o token `SEGREDO-P78-NAO-VAZA`, e ele não pode aparecer em
#        tema, saída de verbo ou listagem do painel;
#     2. escrever fora da raiz: nenhum arquivo `mal-evil*` nasce em lugar
#        nenhum (o nome com `/` ou `..` é o que o poria fora do tema);
#     3. rodar código: todo `manifesto.sh` e todo `json.py` plantados escrevem
#        uma marca, e ela não pode existir no fim;
#     4. o SVG com `<script>`/`onload`, aberto direto pela URL do painel, sai
#        com a CSP de `sandbox` e o `nosniff` — o curl mostra os cabeçalhos;
#     5. a linha ruim é PULADA E CONTADA, sem abortar: o desenho bom do mesmo
#        mapa chega ao tema.
#
# O AMBIENTE É DE BRINQUEDO, E NADA CHEGA AO SISTEMA
#   HOME, XDG_DATA_HOME e MEOW_PACKS temporários; falsos de sudo, pkexec, apt e
#   companhia à frente do PATH, que registram e recusam. O painel sobe com o
#   HOME de brinquedo (decisão 8 da leva G) e morre pelo PID dele.
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
# `mal` VALIDA: tudo o que ele tem de ruim é o que o `validar` não olha (nome
# de destino no mapa, linha do mapa de pastas, symlink dentro de pasta de
# desenho). É ele que prova que a linha ruim é pulada e a boa chega.
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
# `( exec env … ) &`, e não `amb … &`: a função em segundo plano é um subshell,
# e o `$!` seria o dele, e não o do `run.sh` — o `kill` do fim mataria o
# subshell e deixaria o painel de pé (medido: sete servidores órfãos).
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
  if printf '%s' "$glifos" | grep -q "biblioteca/folder.svg\|feitos-a-mao/folder.svg\|$FORA"; then
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

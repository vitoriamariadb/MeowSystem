#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
PAINEL=""
trap '[ -n "$PAINEL" ] && kill "$PAINEL" 2>/dev/null; wait 2>/dev/null; rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec pkill curl wget cosmic-bg; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/criar-tema-leva.sh\\n" >&2\nexit 1\n' "$b" > "$FALSO/$b"
  chmod 755 "$FALSO/$b"
done

CASA="$T/casa"; mkdir -p "$CASA" "$T/estado"
casa() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado" MEOW_IGNORA_DESKTOP=1 WALLPAPER_NOITE=nao \
    WALLPAPER_BANIDOS="$T/banidos.txt" "$@"
}
pack() { casa python3 "$RAIZ/scripts/pack.py" "$@"; }
png() { printf '\x89PNG\r\n\x1a\n%s\n' "$2" > "$1"; }

python3 - "$T/meu-tema.csv" "$RAIZ/packs/meowsystem/paleta.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[2], encoding="utf-8"))
ordem = p.get("ordem_canonica") or list(next(iter(p["flavors"].values())))
cores = p["flavors"]["mocha"]
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("slot,flavor,hex\n" + "".join(f"{n},meutema,{cores[n]}\n" for n in ordem))
PY
pack importar "$T/meu-tema.csv" >/dev/null 2>&1 || { falha "o CSV de brinquedo não virou pack"; exit 1; }
DIR="$CASA/.local/share/meowsystem/packs/meu-tema"

AT="$CASA/.local/share/backgrounds/meowsystem/ativos"; mkdir -p "$AT" "$T/fora"
png "$AT/cat-noite.png" "do pack meowsystem"
png "$AT/minha foto.png" "de quem usa"
png "$AT/outra.png" "fica fora do tema"
printf 'texto com nome de foto\n' > "$T/fora/falsa.png"
png "$T/fora/segredo.png" segredo
ln -s "$T/fora/segredo.png" "$AT/vazou.png"

s="$(pack levar meu-tema foto "$AT/cat-noite.png" 2>&1)"; r1=$?
s2="$(pack levar meu-tema foto "$AT/minha foto.png" 2>&1)"; r2=$?
postas="$(ls -1A "$DIR/wallpapers" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
if [ "$r1" = 0 ] && [ "$r2" = 0 ] && [ "$postas" = "meu-tema-cat-noite.png meu-tema-minha-foto.png " ] \
   && cmp -s "$AT/cat-noite.png" "$DIR/wallpapers/meu-tema-cat-noite.png"; then
  ok "as duas fotos entram em wallpapers/ do pack, com o nome do pack na frente e sem espaço"
else
  falha "as fotos não entraram no pack (rc=$r1/$r2)" "wallpapers: $postas
$s
$s2"
fi

pack levar meu-tema foto "$T/fora/falsa.png" >/dev/null 2>&1; rf=$?
pack levar meu-tema foto "$AT/vazou.png" >/dev/null 2>&1; rl=$?
if [ "$rf" = 1 ] && [ "$rl" = 1 ] && [ "$(ls -1A "$DIR/wallpapers" | wc -l)" = 2 ]; then
  ok "texto com nome de foto e link para fora são recusados, e nada entra"
else
  falha "o pack aceitou o que não é foto, ou um link (rc=$rf/$rl)" "$(ls -1A "$DIR/wallpapers")"
fi

png "$T/fora/-.png" "so hifen"; png "$T/fora/.png" "so extensao"
pack levar meu-tema foto "$T/fora/-.png" >/dev/null 2>&1; rh=$?
pack levar meu-tema foto "$T/fora/.png" >/dev/null 2>&1; rp=$?
sem_ext="$(ls -1A "$DIR/wallpapers" | grep -viE '\.(png|jpe?g|webp)$')"
if [ -z "$sem_ext" ] && [ "$rp" = 1 ] && { [ "$rh" = 1 ] || [ -f "$DIR/wallpapers/meu-tema-.png" ]; }; then
  ok "foto cujo nome limpo perderia a extensão entra com ela, ou não entra"
else
  falha "entrou no pack uma foto sem extensão (rc=$rh/$rp)" "$(ls -1A "$DIR/wallpapers")"
fi
rm -f "$DIR/wallpapers/meu-tema-.png"

v="$(pack validar meu-tema 2>&1)" \
  && ok "o pack com as fotos continua validando" \
  || falha "o pack com as fotos não valida" "$v"

vestir() { casa PACK=meu-tema FLAVOR=meutema bash "$RAIZ/scripts/wallpaper.sh" "$@"; }
vestir semear-se-faltar >/dev/null 2>&1
vestir aplicar >"$T/aplicar.log" 2>&1
GIRA="$CASA/.local/share/backgrounds/meowsystem/ativos-pack"
roda="$(ls -1A "$GIRA" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
if [[ "$roda" == *"meu-tema-cat-noite.png"* && "$roda" == *"meu-tema-minha-foto.png"* \
      && "$roda" != *" cat-noite.png"* && "$roda" != "cat-noite.png"* ]]; then
  ok "vestido o pack, as duas fotos dele estão na rotação, e a do outro pack não"
else
  falha "as fotos do pack não entraram na rotação" "ativos-pack: $roda
ativos: $(ls -1A "$AT" | tr '\n' ' ')
$(cat "$T/aplicar.log")"
fi

s="$(pack tirar meu-tema foto meu-tema-minha-foto.png 2>&1)"; rt=$?
pack tirar meu-tema foto "../pack.json" >/dev/null 2>&1; rx=$?
if [ "$rt" = 0 ] && [ ! -e "$DIR/wallpapers/meu-tema-minha-foto.png" ] && [ "$rx" = 1 ] \
   && [ -f "$DIR/pack.json" ]; then
  ok "tirar uma foto do pack tira só ela; nome com caminho é recusado"
else
  falha "o tirar foto do pack não fez o que devia (rc=$rt/$rx)" "$s"
fi

pack levar meowsystem foto "$AT/outra.png" >/dev/null 2>&1; rm_=$?
[ "$rm_" = 1 ] && [ -z "$(ls -A "$RAIZ/packs/meowsystem/wallpapers" 2>/dev/null | grep -F outra)" ] \
  && ok "o pack que vem com o MeowSystem não recebe nada" \
  || falha "o levar escreveu num pack do repositório (rc=$rm_)"

oga() { printf 'OggS%s\n' "$2" > "$1"; }
SONS="$DIR/sons"
s="$(pack levar meu-tema sons dracula 2>&1)"; rs=$?
n="$(find "$SONS/stereo" -name '*.oga' 2>/dev/null | wc -l)"
esperado="$(find "$RAIZ/packs/dracula/sons/stereo" -name '*.oga' | wc -l)"
if [ "$rs" = 0 ] && [ -f "$SONS/index.theme" ] && [ "$n" = "$esperado" ] \
   && cmp -s "$RAIZ/packs/dracula/sons/stereo/notification/complete.oga" "$SONS/stereo/notification/complete.oga" \
   && python3 -c 'import json,sys; sys.exit(json.load(open(sys.argv[1]))["som"]["tema"] != "sons/")' "$DIR/pack.json"; then
  ok "o tema de sons de partida (o do Dracula) entra em sons/ do pack, e o bloco som aponta para ele"
else
  falha "os sons de partida não entraram no pack (rc=$rs, $n de $esperado)" "$s"
fi

oga "$T/meu-aviso.oga" "o som de quem usa"
s="$(pack levar meu-tema som "$T/meu-aviso.oga" message-new-instant 2>&1)"; rt=$?
if [ "$rt" = 0 ] && cmp -s "$T/meu-aviso.oga" "$SONS/stereo/notification/message-new-instant.oga"; then
  ok "o som escolhido para um evento troca só aquele, no lugar dele"
else
  falha "trocar o som de um evento não funcionou (rc=$rt)" "$s"
fi

printf 'RIFF....WAVE\n' > "$T/aviso.wav"
printf 'não é ogg\n' > "$T/falso.oga"
pack levar meu-tema som "$T/aviso.wav" complete >/dev/null 2>&1; r1=$?
pack levar meu-tema som "$T/falso.oga" complete >/dev/null 2>&1; r2=$?
pack levar meu-tema som "$T/meu-aviso.oga" "../../pack" >/dev/null 2>&1; r3=$?
pack levar meu-tema som "$T/meu-aviso.oga" evento-que-nao-existe >/dev/null 2>&1; r4=$?
if [ "$r1$r2$r3$r4" = 1111 ] && cmp -s "$RAIZ/packs/dracula/sons/stereo/notification/complete.oga" "$SONS/stereo/notification/complete.oga" \
   && [ ! -e "$DIR/pack.oga" ] && [ -z "$(find "$SONS" -name 'evento-que-nao-existe*')" ]; then
  ok "formato que o tema não toca, conteúdo que não é Ogg, nome com caminho e evento que o tema não tem são recusados"
else
  falha "o pack aceitou um som que devia recusar ($r1 $r2 $r3 $r4)"
fi

v="$(pack validar meu-tema 2>&1)" \
  && ok "o pack com os sons continua validando" \
  || falha "o pack com os sons não valida" "$v"

casa PACK=meu-tema FLAVOR=meutema SOM=sim bash "$RAIZ/scripts/som.sh" aplicar >"$T/som.log" 2>&1
NO_AR="$CASA/.local/share/sounds/MeowSystem-Sons"
if diff -r "$SONS" "$NO_AR" >/dev/null 2>&1; then
  ok "vestido o pack, o tema de sons instalado é o dele, com o som escolhido"
else
  falha "o tema de sons instalado não é o do pack" "$(diff -rq "$SONS" "$NO_AR" 2>&1 | head -5)
$(cat "$T/som.log")"
fi

DRA="$RAIZ/packs/dracula/icones"
oferta="$(pack acervo-para-levar meu-tema sistema 2>&1)"
if printf '%s\n' "$oferta" | grep -q "^dracula	folder-documents	$DRA/sistema/folder-documents.svg	nao$" \
   && ! printf '%s\n' "$oferta" | grep -q "^meowsystem	"; then
  ok "a aba Sistema oferece as pastas desenhadas dos packs (o molde que se pinta fica de fora)"
else
  falha "a oferta da aba Sistema não é a esperada" "$(printf '%s\n' "$oferta" | head -5)"
fi
BIB="$(ls "$DRA/biblioteca" | grep '\.svg$' | head -1)"
s="$(pack levar meu-tema sistema "$DRA/sistema/folder-documents.svg" folder-documents 2>&1)"; r1=$?
s2="$(pack levar meu-tema biblioteca "$DRA/biblioteca/$BIB" 2>&1)"; r2=$?
if [ "$r1$r2" = 00 ] && cmp -s "$DRA/sistema/folder-documents.svg" "$DIR/icones/sistema/folder-documents.svg" \
   && cmp -s "$DRA/biblioteca/$BIB" "$DIR/icones/biblioteca/$BIB" \
   && pack acervo-para-levar meu-tema sistema | grep -q "	folder-documents	.*	sim$"; then
  ok "«Levar para o tema» copia o ícone de sistema e o da biblioteca para as pastas do pack, e a oferta o marca"
else
  falha "os ícones não entraram no pack (rc=$r1/$r2)" "$s
$s2"
fi
printf '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>\n' > "$T/mau.svg"
printf 'não é svg\n' > "$T/falso.svg"
pack levar meu-tema biblioteca "$T/mau.svg" >/dev/null 2>&1; r1=$?
pack levar meu-tema biblioteca "$T/falso.svg" >/dev/null 2>&1; r2=$?
pack levar meu-tema sistema "$DRA/sistema/folder.svg" "../../pack" >/dev/null 2>&1; r3=$?
pack levar meu-tema apps "$DRA/sistema/folder.svg" >/dev/null 2>&1; r4=$?
if [ "$r1$r2$r3" = 111 ] && [ "$r4" != 0 ] && [ ! -e "$DIR/icones/biblioteca/mau.svg" ] && [ ! -e "$DIR/pack.svg" ]; then
  ok "SVG com script, arquivo que não é SVG, nome com caminho e pasta fora das duas são recusados"
else
  falha "o pack aceitou um ícone que devia recusar ($r1 $r2 $r3 $r4)"
fi
casa PACK=meu-tema FLAVOR=meutema PASTAS_XDG=sim ICONES_TEMA=Tema-Leva \
  bash "$RAIZ/scripts/icones_pastas.sh" --aplicar >"$T/pastas.log" 2>&1
LUGARES="$CASA/.local/share/icons/Tema-Leva/scalable/places"
if [ "$(cat "$DRA/sistema/folder-documents.svg")" = "$(cat "$LUGARES/folder-documents.svg" 2>/dev/null)" ] \
   && [ -f "$LUGARES/folder-music.svg" ] \
   && [ "$(cat "$DRA/sistema/folder-music.svg")" != "$(cat "$LUGARES/folder-music.svg")" ]; then
  ok "vestido o pack, a pasta levada é a do tema de ícones, e as outras continuam as herdadas"
else
  falha "a pasta levada não chegou ao tema de ícones" "$(ls "$LUGARES" 2>&1 | head -3)
$(tail -5 "$T/pastas.log")"
fi
s="$(pack tirar meu-tema biblioteca "$BIB" 2>&1)"; rt=$?
[ "$rt" = 0 ] && [ ! -e "$DIR/icones/biblioteca/$BIB" ] \
  && ok "tirar o ícone do pack tira só ele" || falha "tirar o ícone do pack (rc=$rt)" "$s"
v="$(pack validar meu-tema 2>&1)" && ok "o pack com os ícones continua validando" \
  || falha "o pack com os ícones não valida" "$v"

mkdir -p "$CASA/.config/meow"; cp "$RAIZ/meow.conf.exemplo" "$CASA/.config/meow/meow.conf"
( exec env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 MEOW_RAIZ="$RAIZ" \
    MEOW_ESTADO="$T/estado" MEOW_CONF="$CASA/.config/meow/meow.conf" MEOW_PONTE=/nao/existe \
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
  oga "$T/outro-aviso.ogg" "o segundo som de quem usa"
  s="$(python3 - "$url" "$T/meu-aviso.oga" "$T/outro-aviso.ogg" "$SONS" <<'PY'
import base64, json, sys, urllib.request
url, meu, outro, sons = sys.argv[1:]
base, tok = url.split("/?t=")
def pedir(rota, corpo=None):
    req = urllib.request.Request(base + rota, headers={"X-Meow-Token": tok, "Content-Type": "application/json"},
                                 data=json.dumps(corpo).encode() if corpo is not None else None)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, r.headers.get("Content-Type", ""), r.read()
    except urllib.error.HTTPError as e:
        return e.code, "", e.read()
falhas = []
_, _, corpo = pedir("/api/criar?id=meu-tema")
eventos = [x["evento"] for x in json.loads(corpo).get("sons", [])]
if "message-new-instant" not in eventos or "complete" not in eventos:
    falhas.append(f"a lista não traz os eventos do tema: {eventos[:5]}")
if "audio-volume-change" in eventos:
    falhas.append("o som de volume do tema (que nunca toca) aparece na lista")
cod, tipo, dados = pedir("/som?pack=meu-tema&evento=message-new-instant")
if cod != 200 or not tipo.startswith("audio/ogg") or dados != open(meu, "rb").read():
    falhas.append(f"a prévia do som não é o arquivo do pack ({cod} {tipo})")
for rota in ("/som?pack=meu-tema&evento=../pack", "/som?pack=meowsystem&evento=complete",
             "/som?pack=..&evento=complete"):
    if pedir(rota)[0] != 404:
        falhas.append(f"{rota} não respondeu 404")
cod, _, r = pedir("/api/criar", {"id": "meu-tema", "tipo": "som", "nome": "complete", "levar": True,
                                 "arquivo": "outro-aviso.ogg",
                                 "conteudo": base64.b64encode(open(outro, "rb").read()).decode()})
if cod != 200 or open(sons + "/stereo/notification/complete.oga", "rb").read() != open(outro, "rb").read():
    falhas.append(f"o «Trocar» do painel não trocou o som ({cod} {r[:120]!r})")
cod, _, r = pedir("/api/criar", {"id": "meu-tema", "tipo": "som", "nome": "complete", "levar": True,
                                 "arquivo": "x.oga", "conteudo": base64.b64encode(b"nao e ogg").decode()})
if cod != 400:
    falhas.append(f"o painel aceitou um som que não é Ogg ({cod})")
for arquivo in ("..", ".", "../../x.oga"):
    cod, _, r = pedir("/api/criar", {"id": "meu-tema", "tipo": "som", "nome": "complete", "levar": True,
                                     "arquivo": arquivo, "conteudo": base64.b64encode(b"OggS de quem usa").decode()})
    if cod == 500 or b"/tmp" in r or b"meow-som" in r:
        falhas.append(f"o arquivo {arquivo!r} virou caminho no servidor ({cod} {r[:120]!r})")
print("\n".join(falhas))
sys.exit(1 if falhas else 0)
PY
)"
  [ $? = 0 ] && ok "o painel lista os sons de aviso do pack, toca a prévia de cada um e troca o som pelo «Trocar»" \
    || falha "os sons de aviso do painel" "$s"
fi

[ "$falhas" = 0 ] || { printf '%d falha(s)\n' "$falhas" >&2; exit 1; }
printf 'criar-tema-leva: tudo ok\n'

#!/usr/bin/env bash
# achados-tecnicos.sh — os achados técnicos das specs P77 e P78 que a P79 fecha.
# 10/10/2026, item 6.
#
# O QUE ESTE TESTE COBRA, UM ACHADO POR SEÇÃO
#   1. Mapa com CRLF. Um `pastas.map` escrito no Windows tem `\r` no glifo, o
#      `meow_nome_seguro` o recusava, e a linha era pulada: o pack inteiro
#      ficava sem pastas (P78). O `pack.py` (`splitlines`) já aceitava o mesmo
#      arquivo; o leitor de mapa do shell passa a aceitar também.
#   2. O `_proibido` do pack via só `.sh` e `#!` no primeiro byte: um
#      `leia.txt` com BOM e `#!` entrava (P78, medido). Agora o BOM não esconde
#      o `#!`.
#   3. O `vidro_janela.py` achava o tema em `~/.config/cosmic` cravado, e não
#      lia o `MEOW_COSMIC_DIR` que o `vidro.sh` respeita (conferência da P77).
#   4. Com `LOGO_MODO=""`, a página não sabia o modo que vale, e a moldura do
#      gato saía vazia (conferência da P77): o servidor manda o modo efetivo
#      (`_modo_do_gato`) no `valendo_agora` da chave.
#   5. A galeria tem a aba «Favoritos», e nenhuma imagem oferecia o gesto de
#      favoritar (QA da P77): os verbos `favoritar` e `desfavoritar` do
#      `wallpaper.sh`, as duas ações do painel e o campo `favorito` de cada
#      imagem.
#
# PORTÁTIL: HOME, COSMIC e packs de brinquedo; bash e python3.
#   0 = passou · 1 = falhou · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ACHADOS=0
ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /' >&2; ACHADOS=$((ACHADOS + 1)); }
command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/falso"
for c in sudo pkexec su pkill killall notify-send systemd-run loginctl apt apt-get xdg-open gsettings dconf busctl gdbus; do
  printf '#!/bin/sh\nexit 1\n' > "$T/falso/$c"; chmod 755 "$T/falso/$c"
done

printf '\n--- 1. o mapa com CRLF não perde as linhas ---\n'
PACKS="$T/packs"; CASA="$T/casa"; P="$PACKS/crlf"
mkdir -p "$P/icones/pastas" "$CASA/.local/share/icons/MeowSystem-Icons/scalable/places"
cp "$RAIZ/packs/dracula/paleta.json" "$P/"
cat > "$P/pack.json" <<'J'
{"formato": 1, "id": "crlf", "nome": "Crlf", "versao": "1.0.0", "autor": "x", "licenca": "MIT",
 "heranca": "dracula",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"},
 "icones": {"pastas": {"mapa": "icones/pastas.map", "desenhos": "icones/pastas/", "recolorir": false}}}
J
printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"/>\n' > "$P/icones/pastas/folder-bom.svg"
printf '# escrito no Windows\r\nfolder-documents:folder-bom\r\nfolder-music:folder-bom\r\n' > "$P/icones/pastas.map"
env -i PATH="$T/falso:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" NO_COLOR=1 \
    PACK=crlf FLAVOR=dracula PASTAS_XDG=sim ICONES_TEMA=MeowSystem-Icons \
    "$RAIZ/scripts/icones_pastas.sh" --aplicar > "$T/pastas.log" 2>&1; rc=$?
PLACES="$CASA/.local/share/icons/MeowSystem-Icons/scalable/places"
if [ "$rc" -le 1 ] && [ -f "$PLACES/folder-documents.svg" ] && [ -f "$PLACES/folder-music.svg" ] \
   && ! grep -q 'pulad' "$T/pastas.log"; then
  ok "as duas linhas do mapa CRLF chegaram ao tema, sem nenhuma pulada (rc=$rc)"
else
  falha "o mapa CRLF perdeu as linhas (rc=$rc)" "$(cat "$T/pastas.log"; ls "$PLACES")"
fi

printf '\n--- 2. o BOM não esconde o #! ---\n'
D="$T/bom"; mkdir -p "$D"
printf '\xef\xbb\xbf#!/bin/sh\ntouch /tmp/x\n' > "$D/leia.txt"
printf 'texto\n' > "$D/nota.txt"
saida="$(python3 - "$RAIZ/scripts" "$D" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import pack
saida, _ocultos, problemas = pack._arquivos_do_pack(sys.argv[2])
print("viaja=" + ",".join(saida))
print("problemas=%d" % len(problemas))
PY
)"
if grep -qx 'viaja=nota.txt' <<< "$saida" && grep -qx 'problemas=1' <<< "$saida"; then
  ok "o leia.txt com BOM e #! não viaja no pack; a nota viaja"
else
  falha "o BOM escondeu o #!" "$saida"
fi

printf '\n--- 3. o vidro_janela.py lê o MEOW_COSMIC_DIR ---\n'
CD="$T/cosmic-fora/com.system76.CosmicTheme.Dark/v1"; mkdir -p "$CD" "$T/casa-vazia"
printf '(\n    base: (red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0),\n)' > "$CD/background"
printf 'true' > "$CD/transparent_bg"
saida="$(env -i PATH="$PATH" HOME="$T/casa-vazia" MEOW_COSMIC_DIR="$T/cosmic-fora" \
           python3 "$RAIZ/scripts/vidro_janela.py" --conferir 2>&1)"
if ! grep -q 'nenhum tema COSMIC em disco' <<< "$saida"; then
  ok "com o COSMIC fora da casa, o vidro_janela.py acha o tema onde o vidro.sh acha"
else
  falha "o vidro_janela.py olhou ~/.config/cosmic com o MEOW_COSMIC_DIR apontando para outro lugar" "$saida"
fi

printf '\n--- 4. LOGO_MODO vazio: o modo que vale chega à página ---\n'
painel_logo() {  # <linhas do conf> — imprime o valendo_agora do LOGO_MODO
  printf '%b' "$1" > "$T/logo.conf"
  env -i PATH="$T/falso:$PATH" HOME="$T/casa-logo" MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/logo.conf" \
    python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
item = next(i for i in servidor.ler_esquema() if i["chave"] == "LOGO_MODO")
print("vale=%s" % (item.get("valendo_agora") or ""))
PY
}
mkdir -p "$T/casa-logo"
s1="$(painel_logo 'LOGO_MODO=""\nLOGO_ROTACAO="sim"\n')"
s2="$(painel_logo 'LOGO_MODO=""\nLOGO_ROTACAO="nao"\n')"
if grep -qx 'vale=rotacao' <<< "$s1" && grep -qx 'vale=hora' <<< "$s2"; then
  ok "LOGO_MODO vazio com LOGO_ROTACAO=sim vale rotacao; com nao, hora — e a página recebe isso"
else
  falha "o servidor não mandou o modo efetivo do gato" "$s1 / $s2"
fi

printf '\n--- 5. favoritar papel de parede ---\n'
CW="$T/casa-wp"; B="$CW/.local/share/backgrounds/meowsystem"
mkdir -p "$B/ativos" "$CW/.config/meow"
printf 'P3\n1 1\n255\n10 20 30\n' > "$B/ativos/foto.png"; cp "$B/ativos/foto.png" "$B/ativos/outra.jpg"
wpv() { local v="$1"; shift; env -i PATH="$T/falso:$PATH" HOME="$CW" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
         MEOW_COSMIC_DIR="$CW/cosmic" "$RAIZ/scripts/wallpaper.sh" "$v" "$@" 2>&1; }
env -i PATH="$T/falso:$PATH" HOME="$CW" MEOW_RAIZ="$RAIZ" NO_COLOR=1 MEOW_DRY_RUN=1 \
  "$RAIZ/scripts/wallpaper.sh" favoritar "$B/ativos/foto.png" >/dev/null 2>&1; rc_s=$?
[ "$rc_s" = 1 ] && [ ! -e "$B/favoritos/foto.png" ] || falha "o ensaio do favoritar escreveu, ou não disse que mudaria (rc=$rc_s)"
s1="$(wpv favoritar "$B/ativos/foto.png")"; rc1=$?
s2="$(wpv favoritar "$B/ativos/foto.png")"; rc2=$?
if [ "$rc1" = 1 ] && [ "$rc2" = 0 ] && cmp -s "$B/ativos/foto.png" "$B/favoritos/foto.png" \
   && [ -f "$B/ativos/foto.png" ]; then
  ok "favoritar guarda uma cópia em favoritos/, a imagem segue girando, e a segunda vez não muda nada"
else
  falha "o favoritar não guardou a imagem (rc=$rc1 $rc2)" "$s1
$s2"
fi
estado="$(env -i PATH="$T/falso:$PATH" HOME="$CW" MEOW_RAIZ="$RAIZ" MEOW_CONF="$CW/.config/meow/meow.conf" \
  python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
fav = {i["rotulo"]: i.get("favorito") for i in servidor._prev_paredes() if i["grupo"] == "ativos"}
print("favorito=%s" % fav.get("foto.png"))
print("outro=%s" % fav.get("outra.jpg"))
print("prov=%s" % ",".join(servidor.PROVEDORES["paredes_favoritas"]()))
for a in ("wallpaper_favoritar", "wallpaper_desfavoritar"):
    print("%s=%s" % (a, servidor.ACOES.get(a, {}).get("arg", "")))
PY
)"
if grep -qx 'favorito=True' <<< "$estado" && grep -qx 'outro=False' <<< "$estado" \
   && grep -qx 'prov=foto.png' <<< "$estado" \
   && grep -qx 'wallpaper_favoritar=paredes_ativas' <<< "$estado" \
   && grep -qx 'wallpaper_desfavoritar=paredes_favoritas' <<< "$estado"; then
  ok "o painel marca a favorita, e as duas ações aceitam só o que existe no disco"
else
  falha "o painel não sabe das favoritas" "$estado"
fi
s3="$(wpv desfavoritar foto.png)"; rc3=$?
s4="$(wpv desfavoritar ../ativos/foto.png)"; rc4=$?
if [ "$rc3" = 1 ] && [ ! -e "$B/favoritos/foto.png" ] && [ -f "$B/ativos/foto.png" ] && [ "$rc4" = 2 ]; then
  ok "desfavoritar tira só a cópia de favoritos/, e um nome com caminho é recusado"
else
  falha "o desfavoritar não fez o que devia (rc=$rc3 $rc4)" "$s3
$s4"
fi

printf '\n'
[ "$ACHADOS" -eq 0 ] || { printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2; exit 1; }
printf 'passou: os achados técnicos da P79 estão fechados\n'
exit 0

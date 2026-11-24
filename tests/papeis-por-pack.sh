#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /' >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 3; }

T="$(mktemp -d)" || exit 2
SHM=""
trap 'rm -rf "$T" ${SHM:+"$SHM"}' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec su apt cargo just make pkill killall cosmic-bg notify-send systemctl gsettings dconf busctl curl; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/papeis-por-pack.sh\\n" >&2\nexit 1\n' "$b" > "$FALSO/$b"
  chmod 755 "$FALSO/$b"
done
DATA_REAL="$(command -v date)"
printf '#!/bin/sh\n[ "$1" = "+%%H:%%M" ] && [ -n "${HORA_FALSA:-}" ] && { echo "$HORA_FALSA"; exit 0; }\nexec %s "$@"\n' "$DATA_REAL" > "$FALSO/date"
chmod 755 "$FALSO/date"

png() {
  python3 -I -c "
import struct, sys, zlib
def bloco(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
cru = (b'\x00' + bytes([int(sys.argv[2])]) * 8) * 8
open(sys.argv[1], 'wb').write(b'\x89PNG\r\n\x1a\n' + bloco(b'IHDR', struct.pack('>IIBBBBB', 8, 8, 8, 0, 0, 0, 0)) + bloco(b'IDAT', zlib.compress(cru)) + bloco(b'tEXt', b'n\x00' + sys.argv[1].encode()) + bloco(b'IEND', b''))
" "$1" "$2"
}

CASA="$T/casa"; B="$CASA/.local/share/backgrounds/meowsystem"; E="$CASA/estado"
mkdir -p "$CASA/cosmic" "$E/papeis-de-parede" "$CASA/.local/state/cosmic/com.system76.CosmicBackground/v1" || exit 2

rodar() {
  local pack="$1" verbo="$2"; shift 2
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_ESTADO="$E" MEOW_IGNORA_DESKTOP=1 MEOW_COSMIC_DIR="$CASA/cosmic" MEOW_COSMIC_SISTEMA="$T/sem-cosmic" \
    MEOW_PACKS="$RAIZ/packs" PACK="$pack" FLAVOR="$pack" XDG_CONFIG_HOME="$CASA/.config" \
    WALLPAPER_NOITE=nao "$@" \
    bash "$RAIZ/scripts/wallpaper.sh" $verbo
}

base_antiga() {
  local b="$1" n
  mkdir -p "$b/ativos" "$b/ativos-dia" "$b/ativos-noite" "$b/ativos-pack" "$b/originais"
  png "$b/ativos/cat-landscapes-lago.png" 30
  png "$b/ativos/cat-pares-janela-dia.png" 220
  png "$b/ativos/cat-pares-janela-noite.png" 20
  png "$b/ativos/meow-lofi-lofi-oxowr5.png" 40
  png "$b/ativos/tulip-pares-catedral-dia.png" 210
  png "$b/ativos/tulip-pares-catedral-noite.png" 15
  png "$b/ativos/tulip-catedral-agulhas.png" 25
  png "$b/ativos/minha-foto.png" 200
  png "$b/ativos/drac-galaxia.png" 35
  for n in tulip-pares-catedral-dia.png minha-foto.png cat-pares-janela-dia.png; do ln "$b/ativos/$n" "$b/ativos-dia/$n"; done
  for n in tulip-pares-catedral-noite.png tulip-catedral-agulhas.png drac-galaxia.png cat-landscapes-lago.png; do ln "$b/ativos/$n" "$b/ativos-noite/$n"; done
  for n in tulip-pares-catedral-dia.png tulip-pares-catedral-noite.png tulip-catedral-agulhas.png minha-foto.png drac-galaxia.png; do
    ln "$b/ativos/$n" "$b/ativos-pack/$n"
  done
  png "$b/ativos-pack/tulip-so-aqui.png" 50
}

base_antiga "$B"
printf '%s\n' "# BANIDOS.txt — os papéis de parede que você recusou, por nome de arquivo." \
  cat-landscapes-recusada.png tulip-velha.png minha-recusada.png > "$E/papeis-de-parede/BANIDOS.txt"
printf 'minha-foto.png\tnoite\ncat-landscapes-lago.png\tdia\n' > "$E/papeis-de-parede/lado.tsv"
( cd "$B/ativos" && ls -1 ) > "$E/wallpaper-vistas.txt"
printf '%s\t%s\n' "$B/ativos-pack/tulip-pares-catedral-dia.png" "$("$DATA_REAL" +%s)" > "$E/wallpaper-fixado"
n_antes="$(find "$B/ativos" "$B/ativos-pack" -type f -links 1 | wc -l)"
n_antes=$(( n_antes + $(find "$B/ativos" -type f -links +1 | wc -l) ))

foto() { find "$CASA" "$E" -path "$CASA/.local/state" -prune -o -printf '%P %s %y %T@\n' 2>/dev/null | LC_ALL=C sort; }

antes="$(foto)"
saida="$(rodar dracula aplicar MEOW_DRY_RUN=1 2>&1)"; rc=$?
[ "$rc" = 1 ] && [[ "$saida" == *"moveria as 9 imagem(ns)"* ]] && [ "$antes" = "$(foto)" ] \
  && ok "o ensaio vê a base antiga e não escreve nada" \
  || falha "o ensaio da base antiga calou ou escreveu (rc=$rc)" "$saida"

saida="$(rodar dracula aplicar 2>&1)"; rc=$?
esperado="dracula/catedral-agulhas.png dracula/catedral-dia.png dracula/catedral-noite.png dracula/so-aqui.png meowsystem/janela-dia.png meowsystem/janela-noite.png meowsystem/landscapes-lago.png meowsystem/meow-lofi-lofi-oxowr5.png Minhas/drac-galaxia.png Minhas/minha-foto.png"
visto="$(cd "$B" && find . -mindepth 2 -maxdepth 2 -type f ! -path './.girando/*' -printf '%P\n' | LC_ALL=C sort | paste -sd' ')"
esperado_ord="$(tr ' ' '\n' <<< "$esperado" | LC_ALL=C sort | paste -sd' ')"
[ "$rc" = 1 ] && [ "$visto" = "$esperado_ord" ] && [ "$n_antes" = 10 ] \
  && ok "uma passada migra: as $n_antes imagens moram numa pasta por pack, sem o prefixo, e a de quem usa em Minhas/" \
  || falha "a migração não pôs cada imagem na pasta do pack (rc=$rc, antes $n_antes)" "$visto
$saida"
sobra="$(cd "$B" && ls -d ativos ativos-dia ativos-noite ativos-pack originais 2>/dev/null)"
[ -z "$sobra" ] && ok "as pastas de antes (ativos, ativos-dia, ativos-noite, ativos-pack, originais) somem" \
  || falha "sobrou pasta de antes" "$sobra"
grep -qx 'landscapes-recusada.png' "$E/papeis-de-parede/BANIDOS.txt" && grep -qx 'velha.png' "$E/papeis-de-parede/BANIDOS.txt" \
  && grep -qx 'minha-recusada.png' "$E/papeis-de-parede/BANIDOS.txt" && [ -f "$E/papeis-de-parede/BANIDOS.txt.antes-pastas" ] \
  && grep -qx "$(printf 'minha-foto.png\tnoite')" "$E/papeis-de-parede/lado.tsv" \
  && grep -qx "$(printf 'landscapes-lago.png\tdia')" "$E/papeis-de-parede/lado.tsv" \
  && grep -qx 'dracula/catedral-dia.png' "$E/wallpaper-vistas.txt" \
  && [ "$(cut -f1 "$E/wallpaper-fixado" 2>/dev/null)" = "$B/dracula/catedral-dia.png" ] \
  && [ -s "$E/papeis-de-parede/base.antes-pastas.tsv" ] \
  && ok "o BANIDOS.txt, o lado.tsv, as vistas e a fixação falam o nome novo, com a cópia de antes e o guia da mudança" \
  || falha "o estado não acompanhou a migração" "$(cat "$E/papeis-de-parede/BANIDOS.txt" "$E/papeis-de-parede/lado.tsv" "$E/wallpaper-vistas.txt" "$E/wallpaper-fixado" 2>&1)"

rm -f "$E/wallpaper-fixado"
rodar dracula aplicar >/dev/null 2>&1
girando() { (cd "$B/.girando" 2>/dev/null && ls -1 | LC_ALL=C sort | paste -sd' '); }
[ "$(girando)" = "catedral-agulhas.png catedral-dia.png catedral-noite.png drac-galaxia.png minha-foto.png so-aqui.png" ] \
  && grep -q "source: Path(\"$B/.girando\")" "$CASA/cosmic/com.system76.CosmicBackground/v1/all" 2>/dev/null \
  && ok "com o Dracula no ar, gira só a pasta dracula/ e a Minhas/; a do meowsystem fica parada" \
  || falha "o carrossel não gira só o pack no ar (girando: $(girando))" "$(cat "$CASA/cosmic/com.system76.CosmicBackground/v1/all" 2>&1)"

rodar dracula aplicar >/dev/null 2>&1
antes="$(foto)"
saida="$(rodar dracula aplicar 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ "$antes" = "$(foto)" ] && ok "a segunda passada não escreve nada" \
  || falha "a segunda passada mexeu (rc=$rc)" "$(diff <(printf '%s\n' "$antes") <(foto) | head; printf '%s\n' "$saida")"

saida="$(rodar meowsystem aplicar 2>&1)"; rc=$?
[ "$(girando)" = "drac-galaxia.png janela-dia.png janela-noite.png landscapes-lago.png meow-lofi-lofi-oxowr5.png minha-foto.png" ] \
  && [ -f "$B/dracula/catedral-agulhas.png" ] && ! grep -qx 'catedral-agulhas.png' "$E/papeis-de-parede/BANIDOS.txt" \
  && ok "trocar para o meowsystem gira a pasta dele e a Minhas/; a do Dracula fica no disco, sem virar banida" \
  || falha "a troca de pack não trocou a coleção (girando: $(girando))" "$saida"

SEM="$T/semente"; mkdir -p "$SEM"
png "$SEM/velha.png" 60; png "$SEM/nova.png" 70; png "$SEM/landscapes-recusada.png" 80
rodar dracula aplicar >/dev/null 2>&1
rodar dracula semear WALLPAPER_SEMENTE_REPO="$SEM" >"$T/s1" 2>&1
[ -f "$B/dracula/nova.png" ] && [ ! -e "$B/dracula/velha.png" ] && [ ! -e "$B/dracula/landscapes-recusada.png" ] \
  && ok "de volta ao Dracula, a semente traz a nova e o que estava banido antes da migração não volta" \
  || falha "o banido de antes da migração voltou" "$(ls "$B/dracula"; cat "$T/s1")"

rm -f "$B/dracula/catedral-agulhas.png"
rodar dracula aplicar >"$T/a1" 2>&1
png "$SEM/catedral-agulhas.png" 25
rodar meowsystem aplicar >/dev/null 2>&1
rodar dracula aplicar >/dev/null 2>&1
rodar dracula semear WALLPAPER_SEMENTE_REPO="$SEM" >"$T/s2" 2>&1
grep -qx 'catedral-agulhas.png' "$E/papeis-de-parede/BANIDOS.txt" && [ ! -e "$B/dracula/catedral-agulhas.png" ] \
  && [[ "$(girando)" != *agulhas.png* ]] \
  && ok "a apagada à mão entra no BANIDOS.txt e não volta depois de trocar de pack e voltar" \
  || falha "a apagada à mão voltou" "$(cat "$T/a1" "$T/s2"; ls "$B/dracula")"

saida="$(rodar dracula aplicar WALLPAPER_NOITE=sim HORA_FALSA=23:00 2>&1)"
g="$(girando)"
[[ " $g " == *" catedral-noite.png "* && " $g " == *" minha-foto.png "* && " $g " != *" catedral-dia.png "* ]] \
  && [ ! -d "$B/ativos-noite" ] && [ ! -d "$B/ativos-dia" ] \
  && grep -qx "$(printf 'catedral-noite.png\tnoite')" "$E/wallpaper-grupos.tsv" \
  && ok "à noite gira o grupo da noite do pack e da Minhas/ (o par e a escolha escrita), sem pasta própria de grupo" \
  || falha "o grupo da noite não saiu do papeis.tsv e da escolha (girando: $g)" "$saida"

OUTRO="$T/disco-da-casa/papeis"
base_antiga "$OUTRO"
saida="$(rodar dracula aplicar WALLPAPER_BASE="$OUTRO" 2>&1)"
[ -f "$OUTRO/dracula/catedral-noite.png" ] && [ -f "$OUTRO/Minhas/minha-foto.png" ] && [ ! -d "$OUTRO/ativos" ] \
  && ok "com WALLPAPER_BASE noutro lugar, a migração acontece lá" \
  || falha "a migração não respeitou o WALLPAPER_BASE" "$saida"

imagens_de() { find "$1" -type f ! -path "$1/.girando/*" -exec md5sum {} + 2>/dev/null | cut -d' ' -f1 | LC_ALL=C sort -u | wc -l; }
nova_base() {
  CASA="$T/$1"; B="$CASA/.local/share/backgrounds/meowsystem"; E="$CASA/estado"
  mkdir -p "$CASA/cosmic" "$E/papeis-de-parede" "$B/ativos" "$B/ativos-dia" "$B/ativos-noite" "$B/ativos-pack"
  printf '%s\n' "# BANIDOS" cat-landscapes-recusada.png > "$E/papeis-de-parede/BANIDOS.txt"
}

nova_base choque
png "$B/ativos/cat-pares-janela-dia.png" 10
png "$B/ativos/cat-janela-dia.png" 20
png "$B/ativos/landscapes-lago.png" 30
png "$B/ativos/cat-landscapes-lago.png" 40
png "$B/ativos/cat-.png" 50
png "$B/ativos-pack/cat-landscapes-lago.png" 60
png "$B/ativos-dia/so-no-dia.png" 70
n0="$(imagens_de "$B")"
saida="$(rodar meowsystem aplicar 2>&1)"; rc=$?
rodar meowsystem --conferir >/dev/null 2>&1; rc2=$?
[ "$rc" = 1 ] && [ "$rc2" = 0 ] && [ "$(imagens_de "$B")" = "$n0" ] && [ "$n0" = 7 ] \
  && [ -z "$(cd "$B" && ls -d ativos ativos-dia ativos-noite ativos-pack 2>/dev/null)" ] \
  && [ -z "$(find "$B" -mindepth 2 -name '.*' ! -path "$B/.girando*")" ] \
  && [ -f "$B/meowsystem/janela-dia.png" ] && [ -f "$B/meowsystem/landscapes-lago.png" ] \
  && ok "dois nomes de antes que caem no mesmo nome novo, a órfã com o nome de outra e o nome que viraria oculto: as $n0 imagens ficam, e a migração termina" \
  || falha "a migração perdeu imagem ou não terminou com nome repetido (rc=$rc, conferir=$rc2, $n0 → $(imagens_de "$B"))" "$(cd "$B" && find . -type f | LC_ALL=C sort)
$saida"

nova_base meia
png "$B/ativos/cat-landscapes-a.png" 1
png "$B/ativos/cat-landscapes-b.png" 2
mkdir -p "$T/py-que-falha"
printf '#!/bin/sh\ncase "$*" in *papeis-de-antes*) [ -e "%s/ja-falhou" ] || { : > "%s/ja-falhou"; echo Traceback >&2; exit 1; } ;; esac\nexec %s "$@"\n' \
  "$T" "$T" "$(command -v python3)" > "$T/py-que-falha/python3"
chmod 755 "$T/py-que-falha/python3"
saida="$(PATH="$T/py-que-falha:$PATH" rodar meowsystem aplicar 2>&1)"; rc=$?
[ "$rc" = 2 ] && [ -f "$B/ativos/cat-landscapes-a.png" ] && [[ "$saida" == *"nada foi movido"* ]] && [[ "$saida" != *Traceback* ]] \
  && ok "o pack.py que falha no meio da migração: sai com erro, diz que nada foi movido, sem traceback" \
  || falha "a migração seguiu com o pack.py quebrado (rc=$rc)" "$saida"
rodar meowsystem aplicar >/dev/null 2>&1
SEM2="$T/semente2"; mkdir -p "$SEM2"; png "$SEM2/landscapes-recusada.png" 5; png "$SEM2/novinha.png" 6
rodar meowsystem semear WALLPAPER_SEMENTE_REPO="$SEM2" >/dev/null 2>&1
grep -qx 'landscapes-recusada.png' "$E/papeis-de-parede/BANIDOS.txt" && [ -f "$B/meowsystem/novinha.png" ] \
  && [ ! -e "$B/meowsystem/landscapes-recusada.png" ] && [ -f "$B/meowsystem/landscapes-a.png" ] \
  && ok "rodada de novo depois da falha, a migração traduz o BANIDOS.txt e o banido não volta" \
  || falha "depois da falha, o banido voltou ou o BANIDOS.txt ficou com o nome antigo" "$(cat "$E/papeis-de-parede/BANIDOS.txt"; ls "$B/meowsystem")"

nova_base trancada
png "$B/ativos/cat-landscapes-a.png" 1
png "$B/ativos/minha.png" 2
chmod 555 "$E/papeis-de-parede"
saida="$(rodar meowsystem aplicar 2>&1)"; rc=$?
chmod 755 "$E/papeis-de-parede"
[ "$rc" = 2 ] && [ -f "$B/ativos/cat-landscapes-a.png" ] && [ -f "$B/ativos/minha.png" ] && [[ "$saida" != *Traceback* ]] \
  && grep -qx 'cat-landscapes-recusada.png' "$E/papeis-de-parede/BANIDOS.txt" \
  && ok "sem escrita no estado: sai com erro e nenhuma imagem sai de ativos/ com o BANIDOS.txt no nome antigo" \
  || falha "a migração moveu imagem sem traduzir o BANIDOS.txt (rc=$rc)" "$saida"

TORTOS="$T/packs-tortos"; cp -r "$RAIZ/packs" "$TORTOS"
sed -i 's/^castelo\t.*/castelo\tcastelo-dia.svg/' "$TORTOS/dracula/wallpapers/papeis.tsv"
nova_base par-torto
png "$B/ativos/tulip-pares-castelo-noite.png" 1
png "$B/ativos/tulip-catedral-agulhas.png" 2
printf '%s\n' "# BANIDOS" tulip-pares-castelo-dia.png > "$E/papeis-de-parede/BANIDOS.txt"
saida="$(rodar dracula aplicar MEOW_PACKS="$TORTOS" 2>&1)"; rc=$?
[ "$rc" = 2 ] && [ -f "$B/ativos/tulip-pares-castelo-noite.png" ] && [ ! -e "$B/dracula" ] \
  && grep -qx 'tulip-pares-castelo-dia.png' "$E/papeis-de-parede/BANIDOS.txt" \
  && [[ "$saida" == *papeis.tsv* && "$saida" == *"nada foi movido"* && "$saida" != *Traceback* ]] \
  && ok "o papeis.tsv do Dracula torto: a migração para com o motivo antes de mover, sem inventar pares-castelo-noite.png" \
  || falha "com o papeis.tsv torto a migração seguiu ou calou (rc=$rc)" "$saida
$(find "$B" -type f | sed "s#$B/##")"
rm -f "$TORTOS/dracula/wallpapers/papeis.tsv"
saida="$(rodar dracula aplicar MEOW_PACKS="$TORTOS" 2>&1)"; rc=$?
[ "$rc" = 2 ] && [ -f "$B/ativos/tulip-pares-castelo-noite.png" ] && [[ "$saida" == *papeis.tsv* ]] \
  && ok "sem o papeis.tsv do Dracula, a migração também para antes de mover" \
  || falha "sem o papeis.tsv a migração seguiu (rc=$rc)" "$saida"
rodar dracula aplicar >/dev/null 2>&1
[ -f "$B/dracula/castelo-noite.png" ] && [ -f "$B/dracula/catedral-agulhas.png" ] && [ ! -e "$B/ativos" ] \
  && grep -qx 'castelo-dia.png' "$E/papeis-de-parede/BANIDOS.txt" \
  && ok "com o papeis.tsv inteiro de volta, a migração retoma com o nome que a semente grava" \
  || falha "a retomada depois do papeis.tsv torto não deu o nome da semente" "$(find "$B" -type f | sed "s#$B/##"; cat "$E/papeis-de-parede/BANIDOS.txt")"

TREZE="catedral/agulhas catedral/nave catedral/rosacea catedral/vitral cemiterio/camposanto cemiterio/corvo cemiterio/portao noite/eclipse noite/mare noite/velas ornamento/espinhos ornamento/filigrana ornamento/folios"
REDE="$T/rede"; mkdir -p "$REDE"; png "$T/baixada.png" 90
{
  printf '#!/bin/sh\nsaida=""; url=""\n'
  printf 'while [ $# -gt 0 ]; do case "$1" in -o) saida="$2"; shift 2 ;; --max-time) shift 2 ;; -*) shift ;; *) url="$1"; shift ;; esac; done\n'
  printf 'case "$url" in\n  https://api.github.com/repos/AndreBFarias/tulip-orchid-wallpapers/git/trees/98770f8a4092b0376d43187dc29fd8110de4e567*)\n'
  printf '    printf %s %s ;;\n' "'%s'" "'$(python3 -I -c 'import json, sys; print(json.dumps({"tree": [{"type": "blob", "path": p + ".png"} for p in sys.argv[1:]] + [{"type": "blob", "path": "svg/" + p.replace("/", "-") + ".svg"} for p in sys.argv[1:]]}))' $TREZE)'"
  printf '  https://raw.githubusercontent.com/*) [ -n "$saida" ] && cp "%s" "$saida" ;;\n  *) exit 1 ;;\nesac\n' "$T/baixada.png"
} > "$REDE/curl"
chmod 755 "$REDE/curl"
SOLTOS="$(for p in $TREZE; do printf '%s.png\n' "${p#*/}"; done)"
no_pack() { (cd "$B/dracula" && ls -1 | LC_ALL=C sort); }

nova_base nomes-de-hoje
rm -rf "$B/ativos-dia" "$B/ativos-noite" "$B/ativos-pack"
for p in $TREZE; do
  case "$p" in ornamento/folios|cemiterio/corvo|catedral/nave|noite/velas) continue ;; esac
  png "$B/ativos/tulip-${p//\//-}.png" 100
done
for n in catedral-dia catedral-noite castelo-dia castelo-noite camposanto-dia camposanto-noite; do png "$B/ativos/tulip-pares-$n.png" 110; done
printf '%s\n' "# BANIDOS" tulip-ornamento-folios.png tulip-cemiterio-corvo.png tulip-catedral-nave.png tulip-noite-velas.png \
  > "$E/papeis-de-parede/BANIDOS.txt"
printf 'tulip-catedral-agulhas.png\tnoite\n' > "$E/papeis-de-parede/lado.tsv"
printf '%s\n' tulip-noite-mare.png tulip-pares-castelo-dia.png > "$E/wallpaper-vistas.txt"
printf 'tulip-catedral-vitral.png\t1\t2\t0.2\n' > "$E/wallpaper-luz.tsv"
printf '%s\t%s\n' "$B/ativos/tulip-ornamento-espinhos.png" "$("$DATA_REAL" +%s)" > "$E/wallpaper-fixado"
rodar dracula aplicar PATH="$REDE:$FALSO:$PATH" >"$T/n1" 2>&1
rodar dracula semear PATH="$REDE:$FALSO:$PATH" >"$T/n2" 2>&1
esperado="$(for p in $TREZE; do case "$p" in ornamento/folios|cemiterio/corvo|catedral/nave|noite/velas) ;; *) printf '%s.png\n' "${p//\//-}" ;; esac; done
            printf '%s\n' catedral-dia.png catedral-noite.png castelo-dia.png castelo-noite.png camposanto-dia.png camposanto-noite.png)"
esperado="$(LC_ALL=C sort <<< "$esperado")"
[ "$(no_pack)" = "$esperado" ] && [ "$(no_pack | wc -l)" = 15 ] && [ -z "$(no_pack | grep -xF "$SOLTOS")" ] \
  && ok "base antiga com os treze tulip-<tema>-<nome>.png, quatro banidos: migra, o semear explícito com rede não devolve banido, e cada imagem tem um nome só, o que a semente do repo grava" \
  || falha "depois da migração e do semear, a pasta do Dracula não tem um nome por imagem" "$(diff <(printf '%s\n' "$esperado") <(no_pack); cat "$T/n1" "$T/n2")"
grep -qxF 'ornamento-folios.png' "$E/papeis-de-parede/BANIDOS.txt" && grep -qxF 'noite-velas.png' "$E/papeis-de-parede/BANIDOS.txt" \
  && grep -qx "$(printf 'catedral-agulhas.png\tnoite')" "$E/papeis-de-parede/lado.tsv" \
  && grep -qxF 'dracula/noite-mare.png' "$E/wallpaper-vistas.txt" && grep -qxF 'dracula/castelo-dia.png' "$E/wallpaper-vistas.txt" \
  && [ "$(cut -f1 "$E/wallpaper-luz.tsv")" = "catedral-vitral.png" ] \
  && [ "$(cut -f1 "$E/wallpaper-fixado")" = "$B/dracula/ornamento-espinhos.png" ] \
  && ok "o BANIDOS.txt, o lado.tsv, as vistas, a luz e a fixação levam o nome de antes para o nome que a semente grava" \
  || falha "o estado não ficou no nome da semente" "$(cat "$E/papeis-de-parede/BANIDOS.txt" "$E/papeis-de-parede/lado.tsv" "$E/wallpaper-vistas.txt" "$E/wallpaper-luz.tsv" "$E/wallpaper-fixado" 2>&1)"
antes="$(cd "$B/dracula" && sha256sum -- * | sort)"
rodar dracula semear PATH="$REDE:$FALSO:$PATH" >"$T/n3" 2>&1
[ "$antes" = "$(cd "$B/dracula" && sha256sum -- * | sort)" ] \
  && ok "a segunda passada do semear não escreve" || falha "a segunda passada do semear escreveu" "$(cat "$T/n3")"

CASA="$T/casa-nova"; B="$CASA/.local/share/backgrounds/meowsystem"; E="$CASA/estado"
mkdir -p "$CASA/cosmic" "$E"
rodar dracula semear PATH="$REDE:$FALSO:$PATH" >"$T/c1" 2>&1
fabrica="ornamento-folios.png cemiterio-corvo.png ornamento-filigrana.png catedral-rosacea.png ornamento-espinhos.png"
voltaram=""; for n in $fabrica; do [ -e "$B/dracula/$n" ] && voltaram="$voltaram $n"; done
[ -z "$voltaram" ] && [ "$(no_pack | wc -l)" = 14 ] && [ -z "$(no_pack | grep -xF "$SOLTOS")" ] \
  && ok "casa nova com rede: os cinco banidos de fábrica não entram, e entram os outros oito do repo e os seis pares" \
  || falha "casa nova com rede: entrou banido de fábrica ou a conta não bate (voltaram:${voltaram:- nenhum})" "$(no_pack; cat "$T/c1")"
antes="$(cd "$B/dracula" && sha256sum -- * | sort)"
rodar dracula semear PATH="$REDE:$FALSO:$PATH" >"$T/c2" 2>&1
[ "$antes" = "$(cd "$B/dracula" && sha256sum -- * | sort)" ] \
  && ok "casa nova: a segunda passada não escreve" || falha "casa nova: a segunda passada escreveu" "$(cat "$T/c2")"

CASA="$T/casa-solta"; B="$CASA/.local/share/backgrounds/meowsystem"; E="$CASA/estado"
mkdir -p "$CASA/cosmic" "$E" "$B/dracula"
png "$B/dracula/agulhas.png" 120; png "$B/dracula/mare.png" 121
saida="$(rodar dracula semear PATH="$REDE:$FALSO:$PATH" 2>&1)"; rc=$?
[ "$rc" = 1 ] && [ -f "$B/dracula/agulhas.png" ] && [ -f "$B/dracula/catedral-agulhas.png" ] && [[ "$saida" != *Traceback* ]] \
  && ok "uma base já no desenho novo com nomes soltos não quebra: o semear termina e nada do que estava some" \
  || falha "a base com nomes soltos quebrou o semear (rc=$rc)" "$saida"

SHM="$(mktemp -d -p /dev/shm 2>/dev/null)" || SHM=""
if [ -n "$SHM" ] && [ "$(stat -c %d "$SHM")" != "$(stat -c %d "$T")" ]; then
  LONGE="$T/longe"; mkdir -p "$LONGE"
  base_antiga "$SHM/b"
  rm -rf "$SHM/b/ativos-dia" "$SHM/b/ativos-noite" "$SHM/b/ativos-pack" "$SHM/b/originais"
  ln -s "$SHM/b/ativos" "$LONGE/ativos"
  saida="$(rodar dracula aplicar WALLPAPER_BASE="$LONGE" 2>&1)"; rc=$?
  [ "$rc" = 2 ] && [ "$(find "$SHM/b/ativos" -type f | wc -l)" = 9 ] && [ -z "$(find "$LONGE" -mindepth 2 -type f ! -path "$LONGE/ativos/*" 2>/dev/null)" ] \
    && [[ "$saida" == *"outro disco"* ]] \
    && ok "o ativos/ que mora noutro disco fica como está: a migração não copia imagem entre discos" \
    || falha "a migração copiou imagem entre discos" "$saida"
else
  falha "sem /dev/shm noutro dispositivo para provar a recusa entre discos"
fi

[ "$falhas" -eq 0 ] || { printf '\nFALHOU: %s achado(s)\n' "$falhas" >&2; exit 1; }
exit 0

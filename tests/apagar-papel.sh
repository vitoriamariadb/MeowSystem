#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec su pkill killall cosmic-bg notify-send systemctl gsettings dconf busctl; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/apagar-papel.sh\\n" >&2\nexit 1\n' "$b" > "$FALSO/$b"
  chmod 755 "$FALSO/$b"
done
png() { printf '\x89PNG\r\n\x1a\n%s\n' "$2" > "$1"; }

raiz_falsa() {
  local r="$1" d
  mkdir -p "$r/packs/meowsystem/wallpapers"
  for d in lib scripts assets bin; do ln -s "$RAIZ/$d" "$r/$d"; done
  cp "$RAIZ/packs/meowsystem/pack.json" "$r/packs/meowsystem/"
  cp "$RAIZ/packs/meowsystem/wallpapers/FONTES.tsv" "$RAIZ/packs/meowsystem/wallpapers/BANIDOS.txt.padrao" \
     "$r/packs/meowsystem/wallpapers/"
}

papel() {
  local casa="$1"; shift
  env -i PATH="$FALSO:$PATH" HOME="$casa" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_ESTADO="$casa/estado" MEOW_IGNORA_DESKTOP=1 MEOW_COSMIC_DIR="$casa/cosmic" \
    WALLPAPER_NOITE=nao "$@"
}

CURADA="$(awk -F'\t' 'NR == FNR {fora[$0] = 1; next} $1 !~ /^#/ && $1 != "arquivo" && $1 != "" && !($1 in fora) {print $1; exit}' \
  "$RAIZ/packs/meowsystem/wallpapers/BANIDOS.txt.padrao" "$RAIZ/packs/meowsystem/wallpapers/FONTES.tsv")"
[ -n "$CURADA" ] || { printf 'FALHOU: o FONTES.tsv não tem linha de imagem\n' >&2; exit 1; }
REPO_ANTES="$(git -C "$RAIZ" status --porcelain -- packs/meowsystem/wallpapers 2>/dev/null)"

printf -- '--- 1. num checkout git, o lixo apaga dos dois lugares e o repositório perde a receita ---\n'
R1="$T/raiz-checkout"; raiz_falsa "$R1"; mkdir -p "$R1/.git"
C1="$T/casa1"; B1="$C1/.local/share/backgrounds/meowsystem"
mkdir -p "$B1/ativos" "$B1/ativos-noite" "$B1/originais" "$C1/cosmic"
png "$B1/ativos/$CURADA" curada; png "$B1/ativos/outra.png" outra; png "$B1/ativos/mais.png" mais
ln "$B1/ativos/$CURADA" "$B1/ativos-noite/$CURADA"
cp "$B1/ativos/$CURADA" "$B1/originais/$CURADA"
linhas_antes="$(wc -l < "$R1/packs/meowsystem/wallpapers/FONTES.tsv")"

s0="$(papel "$C1" MEOW_DRY_RUN=1 "$R1/scripts/wallpaper.sh" banir "$B1/ativos/$CURADA" 2>&1)"; rc0=$?
if [ "$rc0" = 1 ] && [ -f "$B1/ativos/$CURADA" ] && [ -f "$B1/originais/$CURADA" ] \
   && cmp -s "$R1/packs/meowsystem/wallpapers/FONTES.tsv" "$RAIZ/packs/meowsystem/wallpapers/FONTES.tsv" \
   && [[ $s0 == *"apagaria $CURADA (3 arquivo(s))"* ]] && [[ $s0 == *FONTES.tsv* ]]; then
  ok "o ensaio diz o que apagaria nos três lugares e no repositório, sem escrever"
else
  falha "o ensaio escreveu ou calou (rc=$rc0)" "$s0"
fi

s1="$(papel "$C1" "$R1/scripts/wallpaper.sh" banir "$B1/ativos/$CURADA" 2>&1)"; rc1=$?
lista1="$C1/estado/papeis-de-parede/BANIDOS.txt"
if [ "$rc1" = 1 ] && [ ! -e "$B1/ativos/$CURADA" ] && [ ! -e "$B1/ativos-noite/$CURADA" ] \
   && [ ! -e "$B1/originais/$CURADA" ] && [ ! -e "$B1/banidos" ] && [ -f "$B1/ativos/outra.png" ] \
   && grep -qxF -- "$CURADA" "$lista1"; then
  ok "apaga de ativos/, do link duro de ativos-noite/ e de originais/, sem banidos/, e anota no BANIDOS.txt"
else
  falha "o lixo não apagou de todo lugar (rc=$rc1)" "$s1
$(find "$B1" | sort)"
fi
if ! grep -qP "^\Q$CURADA\E\t" "$R1/packs/meowsystem/wallpapers/FONTES.tsv" \
   && [ "$(wc -l < "$R1/packs/meowsystem/wallpapers/FONTES.tsv")" = "$((linhas_antes - 1))" ] \
   && [ "$(tail -n1 "$R1/packs/meowsystem/wallpapers/BANIDOS.txt.padrao")" = "$CURADA" ]; then
  ok "com .git na raiz, o FONTES.tsv perde só a linha dela e o BANIDOS.txt.padrao ganha o nome"
else
  falha "o repositório da raiz-checkout não mudou como devia" \
        "$(diff "$RAIZ/packs/meowsystem/wallpapers/FONTES.tsv" "$R1/packs/meowsystem/wallpapers/FONTES.tsv" | head -5)"
fi
cp "$R1/packs/meowsystem/wallpapers/BANIDOS.txt.padrao" "$T/padrao-1"
png "$B1/ativos/$CURADA" de-novo
papel "$C1" "$R1/scripts/wallpaper.sh" banir "$B1/ativos/$CURADA" >/dev/null 2>&1
[ "$(grep -cxF -- "$CURADA" "$R1/packs/meowsystem/wallpapers/BANIDOS.txt.padrao")" = 1 ] \
  && cmp -s "$T/padrao-1" "$R1/packs/meowsystem/wallpapers/BANIDOS.txt.padrao" \
  && ok "apagar o mesmo nome de novo não repete a linha no BANIDOS.txt.padrao" \
  || falha "o BANIDOS.txt.padrao ganhou o nome duas vezes"

printf -- '--- 2. sem .git na raiz, só o disco ---\n'
R2="$T/raiz-solta"; raiz_falsa "$R2"
C2="$T/casa2"; B2="$C2/.local/share/backgrounds/meowsystem"
mkdir -p "$B2/ativos" "$C2/cosmic"
png "$B2/ativos/$CURADA" curada; png "$B2/ativos/outra.png" outra; png "$B2/ativos/mais.png" mais
s2="$(papel "$C2" "$R2/scripts/wallpaper.sh" banir "$B2/ativos/$CURADA" 2>&1)"; rc2=$?
if [ "$rc2" = 1 ] && [ ! -e "$B2/ativos/$CURADA" ] \
   && grep -qxF -- "$CURADA" "$C2/estado/papeis-de-parede/BANIDOS.txt" \
   && cmp -s "$R2/packs/meowsystem/wallpapers/FONTES.tsv" "$RAIZ/packs/meowsystem/wallpapers/FONTES.tsv" \
   && cmp -s "$R2/packs/meowsystem/wallpapers/BANIDOS.txt.padrao" "$RAIZ/packs/meowsystem/wallpapers/BANIDOS.txt.padrao" \
   && [[ $s2 != *"no repositório"* ]]; then
  ok "sem checkout, a imagem sai do disco e o FONTES.tsv e o BANIDOS.txt.padrao ficam byte a byte"
else
  falha "sem checkout, o lixo mexeu no repositório ou não apagou (rc=$rc2)" "$s2"
fi

printf -- '--- 2b. o lixo nunca apaga fora do acervo ---\n'
C2B="$T/casa2b"; B2B="$C2B/.local/share/backgrounds/meowsystem"; FORA="$T/fotos-dela"
mkdir -p "$B2B/ativos" "$FORA" "$C2B/cosmic"
png "$B2B/ativos/um.png" um; png "$B2B/ativos/dois.png" dois; png "$B2B/ativos/tres.png" tres
png "$FORA/minha.png" minha; png "$FORA/ligada.png" ligada
ln -s "$FORA/ligada.png" "$B2B/ativos/ligada.png"
s2b="$(papel "$C2B" "$R2/scripts/wallpaper.sh" banir "$FORA/minha.png" 2>&1)"; rc2b=$?
[ "$rc2b" = 2 ] && [ -f "$FORA/minha.png" ] && ! grep -qxF minha.png "$C2B/estado/papeis-de-parede/BANIDOS.txt" 2>/dev/null \
  && ok "uma imagem fora do acervo é recusada e fica no disco" \
  || falha "o lixo apagou ou anotou uma imagem de fora do acervo (rc=$rc2b)" "$s2b"
s2c="$(papel "$C2B" "$R2/scripts/wallpaper.sh" banir "$B2B/ativos/ligada.png" 2>&1)"; rc2c=$?
[ "$rc2c" = 1 ] && [ ! -e "$B2B/ativos/ligada.png" ] && [ ! -L "$B2B/ativos/ligada.png" ] && [ -f "$FORA/ligada.png" ] \
  && ok "um link em ativos/ para fora do acervo sai, e a foto de origem fica" \
  || falha "o lixo seguiu o link para fora do acervo (rc=$rc2c)" "$s2c
$(ls -la "$B2B/ativos" "$FORA")"

printf -- '--- 3. a etapa das banidas: apaga o que está na lista, e a segunda passada fica seca ---\n'
C3="$T/casa3"; B3="$C3/.local/share/backgrounds/meowsystem"
mkdir -p "$B3/ativos" "$B3/banidos" "$B3/favoritos" "$C3/cosmic"
png "$B3/ativos/um.png" um; png "$B3/ativos/dois.png" dois; png "$B3/ativos/de-volta.png" volta
png "$B3/banidos/recusada.png" r1; png "$B3/banidos/outra-recusada.jpg" r2; png "$B3/banidos/de-volta.png" volta
LISTA3="$T/banidos3.txt"; printf '# recusadas\nrecusada.png\noutra-recusada.jpg\n' > "$LISTA3"
wp3() { papel "$C3" WALLPAPER_BANIDOS="$LISTA3" "$@" "$RAIZ/scripts/wallpaper.sh" aplicar 2>&1; }
s3="$(wp3 MEOW_DRY_RUN=1)"; rc3=$?
if [ "$rc3" = 1 ] && [ -f "$B3/banidos/recusada.png" ] && [ -d "$B3/favoritos" ] \
   && [[ $s3 == *"apagaria 2 imagem(ns) recusada(s)"* ]] && [[ $s3 == *"tiraria a pasta vazia favoritos/"* ]]; then
  ok "o ensaio (o que o doctor confere) acusa as 2 recusadas e a favoritos/ vazia, sem apagar"
else
  falha "o ensaio da etapa das banidas escreveu ou calou (rc=$rc3)" "$s3"
fi
s4="$(wp3)"; rc4=$?
if [ "$rc4" = 1 ] && [ ! -e "$B3/banidos/recusada.png" ] && [ ! -e "$B3/banidos/outra-recusada.jpg" ] \
   && [ -f "$B3/banidos/de-volta.png" ] && [ ! -e "$B3/favoritos" ] && [ -f "$B3/ativos/de-volta.png" ] \
   && [ "$(grep -c . "$LISTA3")" = 3 ]; then
  ok "apaga só as que estão no BANIDOS.txt, a que não está fica, e a favoritos/ vazia sai"
else
  falha "a etapa das banidas apagou demais ou de menos (rc=$rc4)" "$s4
$(find "$B3" | sort)"
fi
s5="$(wp3 MEOW_DRY_RUN=1)"; rc5=$?
s6="$(wp3)"; rc6=$?
[ "$rc5" = 0 ] && [ "$rc6" = 0 ] && [[ $s6 != *banidos* ]] \
  && ok "a segunda passada não escreve nada (ensaio rc=$rc5, de verdade rc=$rc6)" \
  || falha "a segunda passada mexeu de novo (rc=$rc5 $rc6)" "$s5
$s6"
rm -f "$B3/banidos/de-volta.png"; printf 'de-volta.png\n' >> "$LISTA3"
png "$B3/banidos/de-volta.png" volta
wp3 >/dev/null; [ ! -e "$B3/banidos" ] && ok "com todas listadas, a pasta banidos/ some junto" \
  || falha "a banidos/ vazia ficou" "$(ls -la "$B3")"

printf -- '--- 3b. nome com emoji, acento e espaço é só bytes: banir apaga, a pasta banidos/ limpa, a segunda passada fica seca ---\n'
GATO=$'\xf0\x9f\x90\xb1'; BRILHO=$'\xe2\x9c\xa8'; CIDADE=$'\xf0\x9f\x8c\x86'
EMOJI="Gato Neon $GATO$BRILHO ação.jpeg"
R5="$T/raiz-emoji"; raiz_falsa "$R5"; mkdir -p "$R5/.git"
C5="$T/casa5"; B5="$C5/.local/share/backgrounds/meowsystem"
mkdir -p "$B5/ativos" "$B5/banidos" "$C5/cosmic"
png "$B5/ativos/um.png" um; png "$B5/ativos/dois.png" dois; png "$B5/ativos/$EMOJI" emoji
s5a="$(papel "$C5" "$R5/scripts/wallpaper.sh" banir "$B5/ativos/$EMOJI" 2>&1)"; rc5a=$?
if [ "$rc5a" = 1 ] && [ ! -e "$B5/ativos/$EMOJI" ] \
   && LC_ALL=C grep -qxF -- "$EMOJI" "$C5/estado/papeis-de-parede/BANIDOS.txt" \
   && cmp -s "$R5/packs/meowsystem/wallpapers/BANIDOS.txt.padrao" "$RAIZ/packs/meowsystem/wallpapers/BANIDOS.txt.padrao" \
   && cmp -s "$R5/packs/meowsystem/wallpapers/FONTES.tsv" "$RAIZ/packs/meowsystem/wallpapers/FONTES.tsv"; then
  ok "banir apaga a imagem com emoji, anota no BANIDOS.txt e deixa o padrão do repositório intacto (ela não está no FONTES.tsv)"
else
  falha "banir com emoji no nome apagou de menos ou mexeu no padrão (rc=$rc5a)" "$s5a"
fi
mkdir -p "$B5/banidos"; png "$B5/banidos/$EMOJI" velha; png "$B5/banidos/só-cópia.png" copia
SOCOPIA="Cyberpunk $CIDADE Neon $BRILHO Cat.jpeg"; png "$B5/banidos/$SOCOPIA" so-copia
wp5() { papel "$C5" "$@" "$R5/scripts/wallpaper.sh" aplicar 2>&1; }
s5b="$(wp5)"; rc5b=$?
if [ "$rc5b" = 1 ] && [ ! -e "$B5/banidos" ] \
   && LC_ALL=C grep -qxF -- "só-cópia.png" "$C5/estado/papeis-de-parede/BANIDOS.txt" \
   && LC_ALL=C grep -qxF -- "$SOCOPIA" "$C5/estado/papeis-de-parede/BANIDOS.txt"; then
  ok "as cópias só em banidos/, com emoji ou sem, entram no BANIDOS.txt e saem do disco"
else
  falha "a etapa das banidas deixou cópia em banidos/ (rc=$rc5b)" "$s5b
$(find "$B5" | sort)"
fi
sha="$(sha256sum "$C5/estado/papeis-de-parede/BANIDOS.txt")"
s5c="$(wp5 MEOW_DRY_RUN=1)"; rc5c=$?
s5d="$(wp5)"; rc5d=$?
[ "$rc5c" = 0 ] && [ "$rc5d" = 0 ] && [ "$sha" = "$(sha256sum "$C5/estado/papeis-de-parede/BANIDOS.txt")" ] \
  && ok "a segunda passada não escreve nada (ensaio rc=$rc5c, de verdade rc=$rc5d)" \
  || falha "a segunda passada mexeu de novo (rc=$rc5c $rc5d)" "$s5c
$s5d"

printf -- '--- 3c. o padrão do repositório só recebe nome que está no FONTES.tsv ---\n'
R6="$T/raiz-padrao"; raiz_falsa "$R6"; mkdir -p "$R6/.git"
C6="$T/casa6"; B6="$C6/.local/share/backgrounds/meowsystem"
mkdir -p "$B6/ativos" "$C6/cosmic"
png "$B6/ativos/foto-dela.png" dela; png "$B6/ativos/outra.png" outra; png "$B6/ativos/mais.png" mais
papel "$C6" "$R6/scripts/wallpaper.sh" banir "$B6/ativos/foto-dela.png" >/dev/null 2>&1
if [ ! -e "$B6/ativos/foto-dela.png" ] && grep -qxF foto-dela.png "$C6/estado/papeis-de-parede/BANIDOS.txt" \
   && ! grep -qxF foto-dela.png "$R6/packs/meowsystem/wallpapers/BANIDOS.txt.padrao" \
   && cmp -s "$R6/packs/meowsystem/wallpapers/BANIDOS.txt.padrao" "$RAIZ/packs/meowsystem/wallpapers/BANIDOS.txt.padrao"; then
  ok "a foto dela some do disco e fica só no BANIDOS.txt dela, sem entrar no padrão que viaja no repositório"
else
  falha "a foto dela entrou no BANIDOS.txt.padrao ou não saiu do disco" \
        "$(diff "$RAIZ/packs/meowsystem/wallpapers/BANIDOS.txt.padrao" "$R6/packs/meowsystem/wallpapers/BANIDOS.txt.padrao")"
fi

printf -- '--- 3d. o arquivo temporário do programa que some não vira banida ---\n'
C7="$T/casa7"; B7="$C7/.local/share/backgrounds/meowsystem"
mkdir -p "$B7/ativos" "$C7/cosmic"
png "$B7/ativos/um.png" um; png "$B7/ativos/dois.png" dois; png "$B7/ativos/tres.png" tres
wp7() { papel "$C7" "$RAIZ/scripts/wallpaper.sh" aplicar 2>&1; }
wp7 >/dev/null
png "$B7/ativos/.meow.AbC123" temporario
wp7 >/dev/null
rm -f "$B7/ativos/.meow.AbC123"
wp7 >/dev/null
! grep -qxF .meow.AbC123 "$C7/estado/papeis-de-parede/BANIDOS.txt" 2>/dev/null \
  && ok "um .meow.XXXXXX que aparece e some em ativos/ não entra no BANIDOS.txt" \
  || falha "o arquivo temporário virou banida"

printf -- '--- 3e. o BANIDOS.txt.padrao do repositório está limpo e o FONTES.tsv não lista o que ele bane ---\n'
PADRAO="$RAIZ/packs/meowsystem/wallpapers/BANIDOS.txt.padrao"
FONTES="$RAIZ/packs/meowsystem/wallpapers/FONTES.tsv"
lixo="$(grep -v '^#' "$PADRAO" | grep -cE '^$|^\.meow\.|^\.atomicwrite')"
repetidas="$(grep -v '^#' "$PADRAO" | sort | uniq -d | wc -l)"
cruzadas="$(awk -F'\t' 'NR == FNR {if ($0 !~ /^#/) b[$0] = 1; next} $1 in b {n++} END {print n + 0}' "$PADRAO" "$FONTES")"
[ "$lixo" = 0 ] && [ "$repetidas" = 0 ] && [ "$cruzadas" = 0 ] \
  && ok "o padrão não tem linha vazia, temporário nem repetida, e nenhuma fonte dele está banida" \
  || falha "o padrão ou o FONTES.tsv sujos (lixo=$lixo repetidas=$repetidas cruzadas=$cruzadas)"

printf -- '--- 4. favoritar e desbanir não existem mais ---\n'
for v in favoritar desfavoritar desbanir; do
  papel "$C3" "$RAIZ/scripts/wallpaper.sh" "$v" x >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] && ok "wallpaper.sh $v é verbo desconhecido" || falha "wallpaper.sh $v ainda responde (rc=$rc)"
done

REPO_DEPOIS="$(git -C "$RAIZ" status --porcelain -- packs/meowsystem/wallpapers 2>/dev/null)"
[ "$REPO_ANTES" = "$REPO_DEPOIS" ] && ok "o repositório de verdade ficou como estava" \
  || falha "o teste mexeu no repositório de verdade" "$REPO_DEPOIS"

[ "$falhas" = 0 ] && { printf 'apagar-papel: tudo ok\n'; exit 0; }
printf 'apagar-papel: %s falha(s)\n' "$falhas"; exit 1

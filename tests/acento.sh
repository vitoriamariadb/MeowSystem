#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
CASA="$T/casa"; COSMIC="$T/cosmic"; PACKS="$T/packs"; ESTADO="$T/estado"
CONF="$CASA/.config/meow/meow.conf"
mkdir -p "$(dirname "$CONF")" "$COSMIC" "$PACKS" "$ESTADO"
cp -a "$RAIZ/packs/dracula" "$PACKS/" || exit 2
CAPS="$PACKS/dracula/temas/capturados"
for cap in "$CAPS"/*/; do
  grep -qs '^origem: derivada de ' "$cap/captura.txt" && rm -rf "$cap"
done

git_antes="$(git -C "$RAIZ" status --porcelain 2>/dev/null)"

git -C "$PACKS" init -q >/dev/null 2>&1 \
  || { printf 'erro: não consegui criar o repositório de brinquedo\n' >&2; exit 2; }

conf() {
  printf 'FLAVOR="%s"\nACCENT="%s"\nMODO="escuro"\nPACK="%s"\nLOGO="coquinha"\n' "$1" "$2" "$3" > "$CONF"
}
amb() {
  env -i PATH="$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_CONF="$CONF" \
    MEOW_ESTADO="$ESTADO" MEOW_COSMIC_DIR="$COSMIC" MEOW_PACKS="$PACKS" \
    LANG=C.UTF-8 NO_COLOR=1 "$@"
}

ETAPAS="$T/etapas.sh"
{ sed -n '/^etapa_gerar() {$/,/^}$/p' "$RAIZ/install.sh"
  sed -n '/^etapa_tema() {$/,/^}$/p' "$RAIZ/install.sh"; } > "$ETAPAS"
grep -q '^etapa_gerar() {' "$ETAPAS" && grep -q '^etapa_tema() {' "$ETAPAS" \
  || { printf 'erro: não achei etapa_gerar/etapa_tema no install.sh\n' >&2; exit 2; }
ordem="$(grep -o 'etapa_gerar etapa_tema' "$RAIZ/install.sh" | head -n1)"
[ -n "$ordem" ] && ok "no install.sh a etapa gerar vem logo antes da etapa tema" \
  || falha "a lista de etapas do install.sh não tem mais 'etapa_gerar etapa_tema' em sequência"

etapa() {
  amb bash -c '
    . "$MEOW_RAIZ/lib/comum.sh" >/dev/null 2>&1
    set -a; . "$MEOW_CONF"; set +a
    meow_ponte_python >/dev/null 2>&1 || exit 9
    meow_notificar() { :; }
    passo() { :; }
    . "$1"
    "etapa_$2"; r=$?
    printf "%s" "${TEMA_NAO_APLICADO:-}" > "$3"
    exit "$r"' _ "$ETAPAS" "$1" "$T/nao_aplicado" 2>&1
  printf '%s' "$?" > "$T/rc"
}
rc() { cat "$T/rc"; }

campo() {
  sed -n "s/^    $2: \"\\(#[0-9A-F]*\\)\",\$/\\1/p" "$1" | head -n1
}
floats() {
  awk '/^    base: \(/{f=1;next} f&&/red:/{r=$2} f&&/green:/{g=$2} f&&/blue:/{b=$2; print r g b; exit}' "$1"
}

cp -a "$CAPS/dracula-mauve"/com.system76.CosmicTheme.* "$COSMIC/"
conf dracula pink dracula
antes_v2="$(campo "$COSMIC/com.system76.CosmicTheme.Dark/v2/accent" base)"
antes_v1="$(floats "$COSMIC/com.system76.CosmicTheme.Dark/v1/accent")"
[ "$antes_v2" = "#BD93F9FF" ] && [ ! -e "$CAPS/dracula-pink" ] \
  && ok "antes: o COSMIC de brinquedo está no mauve do Dracula, e não há captura dracula-pink" \
  || falha "o ponto de partida não é o esperado (v2 accent=$antes_v2)"

saida_g="$(etapa gerar)"; rc_g="$(rc)"
saida_t="$(etapa tema)"; rc_t="$(rc)"
if [ "$rc_g" = "1" ] && [[ "$saida_g" == *"dracula-pink: derivada de dracula-mauve"* ]]; then
  ok "a etapa gerar deriva a captura do pink a partir da do mauve"
else
  falha "a etapa gerar não derivou o dracula-pink (rc=$rc_g)" "$saida_g"
fi
if [ "$rc_t" = "1" ] && [[ "$saida_t" == *"tema 'dracula-pink' aplicado"* ]]; then
  ok "a etapa tema aplica o dracula-pink"
else
  falha "a etapa tema não aplicou o dracula-pink (rc=$rc_t)" "$saida_t"
fi
case "$saida_g$saida_t" in
  *Importar*|*"tema capturar"*) falha "o instalador ainda manda um passo à mão" "$saida_g$saida_t" ;;
  *) ok "nenhuma linha manda importar na GUI nem capturar à mão" ;;
esac

depois_v2="$(campo "$COSMIC/com.system76.CosmicTheme.Dark/v2/accent" base)"
depois_v1="$(floats "$COSMIC/com.system76.CosmicTheme.Dark/v1/accent")"
receita="$(cat "$COSMIC/com.system76.CosmicTheme.Dark.Builder/v2/accent")"
[ "$depois_v2" = "#FF79C6FF" ] \
  && ok "Dark/v2/accent: $antes_v2 -> $depois_v2" \
  || falha "Dark/v2/accent não virou o pink do Dracula (#FF79C6FF): $depois_v2"
[ "$depois_v1" = "1.0,0.4745098,0.7764706," ] \
  && ok "Dark/v1/accent (a árvore dos applets antigos): $antes_v1 -> $depois_v1" \
  || falha "Dark/v1/accent não virou #FF79C6 em floats: $antes_v1 -> $depois_v1"
[ "$receita" = 'Some("#FF79C6FF")' ] \
  && ok "a receita (Dark.Builder/v2/accent) diz o pink" \
  || falha "a receita não diz o pink: $receita"
focos="$(grep -h '^ *focus: "' "$COSMIC"/com.system76.CosmicTheme.Dark/v2/* | sed 's/^ *//' | sort -u)"
[ "$focos" = 'focus: "#FF79C6FF",' ] \
  && ok "o foco de todos os componentes da Dark/v2 é o pink" \
  || falha "sobrou foco de outra cor na Dark/v2" "$focos"
iguais=1
for rel in com.system76.CosmicTheme.Dark.Builder/v2/neutral_tint \
           com.system76.CosmicTheme.Dark.Builder/v2/frosted \
           com.system76.CosmicTheme.Dark/v2/palette; do
  cmp -s "$CAPS/dracula-mauve/$rel" "$COSMIC/$rel" || { iguais=0; falha "mudou o que o acento não pinta: $rel"; }
done
[ "$iguais" = "1" ] && ok "a neutra, o vidro e a paleta ficaram os da captura do mauve"
claro="$(campo "$COSMIC/com.system76.CosmicTheme.Light/v2/accent" base)"
[ "$claro" = "#ED77BBFF" ] \
  && ok "a Light/v2/accent é o pink do alucard ($claro), e não o mauve da captura da base" \
  || falha "a Light do dracula-pink não é a do alucard-pink: accent $claro"

saida_g2="$(etapa gerar)"; rc_g2="$(rc)"
saida_t2="$(etapa tema)"; rc_t2="$(rc)"
[ "$rc_g2" = "0" ] && [ "$rc_t2" = "0" ] \
  && ok "a segunda passagem não escreve nada (gerar=$rc_g2 tema=$rc_t2)" \
  || falha "a segunda passagem ainda escreve (gerar=$rc_g2 tema=$rc_t2)" "$saida_g2
$saida_t2"

for f in "$COSMIC"/com.system76.CosmicTheme.*/v*/frosted_maximized_apps; do
  [ -f "$f" ] && printf 'true' > "$f"
done
for f in "$COSMIC"/com.system76.CosmicTheme.Dark.Builder/v2/alpha_map \
         "$COSMIC"/com.system76.CosmicTheme.Dark/v2/alpha_map; do
  sed -i 's/extremely_low: 0\.91999996/extremely_low: 0.78/' "$f"
done
alpha_dela="$(cat "$COSMIC/com.system76.CosmicTheme.Dark.Builder/v2/alpha_map")"
conf dracula green dracula
saida_g="$(etapa gerar)"; rc_g="$(rc)"
saida_t="$(etapa tema)"; rc_t="$(rc)"
verde_v2="$(campo "$COSMIC/com.system76.CosmicTheme.Dark/v2/accent" base)"
focos="$(grep -h '^ *focus: "' "$COSMIC"/com.system76.CosmicTheme.Dark/v2/* | sed 's/^ *//' | sort -u)"
if [ "$rc_t" = "1" ] && [ "$verde_v2" = "#50FA7BFF" ] && [ "$focos" = 'focus: "#50FA7BFF",' ]; then
  ok "com o vidro dela na receita, o acento novo chega à Dark/v2 (accent e os focos: $verde_v2)"
else
  falha "com a receita dela diferente da captura, a Dark/v2 ficou no acento velho (rc=$rc_t, accent=$verde_v2)" "$saida_g
$saida_t
$focos"
fi
[ "$(cat "$COSMIC/com.system76.CosmicTheme.Dark.Builder/v2/alpha_map")" = "$alpha_dela" ] \
  && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Dark.Builder/v2/frosted_maximized_apps")" = "true" ] \
  && ok "e o alpha_map dela e o frosted_maximized_apps do vidro.sh continuam os dela" \
  || falha "trocar o acento desfez o vidro dela"

tb="$COSMIC/com.system76.CosmicTheme.Dark/v2/transparent_background"
sed -i '0,/^    base: "#\([0-9A-F]\{6\}\)[0-9A-F]\{2\}"/s//    base: "#\171"/' "$tb"
derivado="$(cat "$tb")"
saida_t="$(etapa tema)"; rc_t="$(rc)"
! cmp -s "$tb" "$CAPS/dracula-green/com.system76.CosmicTheme.Dark/v2/transparent_background" \
  && [ "$rc_t" = "0" ] && [ "$(cat "$tb")" = "$derivado" ] \
  && ok "com o mesmo tema, o que a GUI dela derivou do vidro continua (a captura não o desfaz)" \
  || falha "a manutenção desfez o que a GUI dela derivou (rc=$rc_t)" "$saida_t"
for f in "$COSMIC"/com.system76.CosmicTheme.Dark.Builder/v2/alpha_map \
         "$COSMIC"/com.system76.CosmicTheme.Dark/v2/alpha_map; do
  cp "$CAPS/dracula-green/${f#"$COSMIC"/}" "$f"
done
saida_t="$(etapa tema)"; rc_t="$(rc)"
[ "$rc_t" = "1" ] && cmp -s "$tb" "$CAPS/dracula-green/com.system76.CosmicTheme.Dark/v2/transparent_background" \
  && ok "com só o frosted_maximized_apps do vidro.sh diferente, a Dark/v2 volta a ser a da captura" \
  || falha "o frosted_maximized_apps do vidro.sh foi tomado por vidro mexido na GUI (rc=$rc_t)" "$saida_t"

visto="$(git -C "$PACKS" status --porcelain --untracked-files=all -- dracula/temas/capturados 2>&1)"
if [ -f "$CAPS/dracula-pink/.gitignore" ] && [[ "$visto" == *dracula-mauve* ]] \
   && [[ "$visto" != *dracula-pink* ]]; then
  ok "a captura derivada mora no pack e não aparece no git status dele (a fotografia aparece)"
else
  falha "a captura derivada aparece no git do pack" "$(printf '%s\n' "$visto" | grep dracula-pink | head -n 5)"
fi
[ ! -e "$COSMIC/.gitignore" ] \
  && ok "o .gitignore da captura não foi copiado para o COSMIC" \
  || falha "o aplicar_tema.sh copiou o .gitignore da captura para o COSMIC"
grep -q "^origem: derivada de dracula-mauve" "$CAPS/dracula-pink/captura.txt" \
  && ok "o captura.txt diz de qual captura ela saiu" \
  || falha "o captura.txt da derivada não diz a base" "$(cat "$CAPS/dracula-pink/captura.txt")"

saida="$(amb env MEOW_PACK_DIR="$RAIZ/packs/meowsystem" MEOW_PALETA="$RAIZ/packs/meowsystem/paleta.json" \
  python3 "$RAIZ/scripts/derivar_acento.py" --conferir mocha-green 2>&1)"; r=$?
[ "$r" = "1" ] && [[ "$saida" == *"derivaria de mocha-pink"* ]] \
  && ok "o mocha deriva do mocha-pink, porque o mocha-mauve não se reproduz" \
  || falha "a escolha da base do mocha não passou pela guarda (rc=$r)" "$saida"

cp -a "$RAIZ/packs/meowsystem" "$PACKS/" || exit 2
rm -rf "$PACKS"/meowsystem/temas/capturados/mocha-*
conf frappe pink meowsystem
saida_t="$(etapa tema)"; rc_t="$(rc)"
if [ "$rc_t" = "3" ] && grep -q "^tema-sem-captura	.*não há tema capturado do frappe" "$ESTADO/pendencias.tsv" 2>/dev/null; then
  ok "frappe-pink não aplica: a etapa se pula e a Início ganha a pendência, com o porquê"
else
  falha "o tema que não aplica não virou pendência (rc=$rc_t)" "$saida_t
$(cat "$ESTADO/pendencias.tsv" 2>/dev/null)"
fi
[[ "$(cat "$T/nao_aplicado" 2>/dev/null)" == "O tema do COSMIC não foi aplicado: "* ]] \
  && ok "e a etapa deixa o recado que faz o instalador sair 1, sem «Pronto»" \
  || falha "a etapa não deixou o TEMA_NAO_APLICADO para o fim do install.sh" "$(cat "$T/nao_aplicado" 2>/dev/null)"
conf dracula pink dracula
etapa tema >/dev/null
grep -q "^tema-sem-captura	" "$ESTADO/pendencias.tsv" 2>/dev/null \
  && falha "a pendência do tema ficou depois de o tema voltar a aplicar" \
  || ok "com um tema que aplica, a pendência sai"
[ -z "$(cat "$T/nao_aplicado" 2>/dev/null)" ] \
  && ok "e o recado some: o instalador volta a poder dizer «Pronto»" \
  || falha "o TEMA_NAO_APLICADO ficou com o tema aplicado" "$(cat "$T/nao_aplicado")"

ESTADO_LIMPO="$T/estado-limpo"; mkdir -p "$ESTADO_LIMPO"
antes_md5="$(find "$COSMIC" -type f -exec md5sum {} + | sort | md5sum)"
saida="$(amb env MEOW_ESTADO="$ESTADO_LIMPO" "$RAIZ/bin/meow" tema original 2>&1)"; r=$?
depois_md5="$(find "$COSMIC" -type f -exec md5sum {} + | sort | md5sum)"
if [ "$r" = "3" ] && [[ "$saida" == *"foi tirada de OUTRA máquina"* ]] && [ "$antes_md5" = "$depois_md5" ]; then
  ok "meow tema original recusa (rc=3) e o COSMIC de brinquedo não muda um byte"
else
  falha "meow tema original não recusou, ou mexeu no COSMIC (rc=$r)" "$saida"
fi
saida="$(amb env MEOW_ESTADO="$ESTADO_LIMPO" "$RAIZ/bin/meow" desfazer 2>&1)"; r=$?
[ "$r" = "3" ] && [[ "$saida" == *"MEOW_TEMA_DE_OUTRA_MAQUINA=1 meow desfazer"* ]] \
  && ok "e o meow desfazer continua recusando pela mesma guarda" \
  || falha "o meow desfazer perdeu a guarda (rc=$r)" "$saida"

grep -q '^origem: /' "$RAIZ/assets/temas/capturados/original/captura.txt" \
  && falha "a captura 'original' guarda o caminho absoluto da máquina de onde saiu" \
  || ok "a captura 'original' não guarda caminho absoluto de máquina"
GO="$T/guarda"; mkdir -p "$GO/assets/temas/capturados/original"
origem_de() { bash -c "$(grep -m1 '^origem_da_maquina()' "$RAIZ/scripts/capturar_tema.sh")"'
  origem_da_maquina "$0"' "$1"; }
printf 'captura: original\norigem: %s\n' "$(origem_de "$T/casa-dela/.config/cosmic")" \
  > "$GO/assets/temas/capturados/original/captura.txt"
guarda() {
  RAIZ="$GO" COSMIC="$1" NO_COLOR=1 bash -c '
    meow_erro() { :; }; meow_info() { :; }
    eval "$(sed -n "/^guarda_original() {\$/,/^}\$/p" "$0")"
    guarda_original "meow desfazer" "" ""' "$RAIZ/bin/meow"
}
guarda "$T/casa-dela/.config/cosmic"; g1=$?
guarda "$T/outra-casa/.config/cosmic"; g2=$?
[ "$g1" = 0 ] && [ "$g2" = 1 ] \
  && ok "a guarda deixa passar na máquina de onde a captura saiu e recusa nas outras" \
  || falha "a guarda não lê a origem nova (mesma máquina rc=$g1, outra rc=$g2)"

[ "$(git -C "$RAIZ" status --porcelain 2>/dev/null)" = "$git_antes" ] \
  && ok "o repositório saiu como entrou" \
  || falha "o teste mexeu no repositório" "$(git -C "$RAIZ" status --porcelain)"

printf '\n'
[ "$falhas" = "0" ] && { printf 'acento: tudo certo\n'; exit 0; }
printf 'acento: %d achado(s)\n' "$falhas"
exit 1

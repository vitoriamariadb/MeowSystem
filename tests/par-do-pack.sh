#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec su pkill curl wget notify-send systemctl gsettings dconf busctl cosmic-bg apt apt-get systemd-run loginctl; do
  printf '#!/bin/sh\nexit 1\n' > "$FALSO/$b"; chmod 755 "$FALSO/$b"
done
CASA="$T/casa"; COSMIC="$T/cosmic"; ESTADO="$T/estado"
CONF="$CASA/.config/meow/meow.conf"
mkdir -p "$(dirname "$CONF")" "$COSMIC" "$ESTADO"

amb() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" MEOW_RAIZ="$RAIZ" MEOW_CONF="$CONF" \
    MEOW_ESTADO="$ESTADO" MEOW_COSMIC_DIR="$COSMIC" MEOW_PONTE=/caminho/inexistente \
    XDG_CONFIG_HOME="$CASA/.config" XDG_STATE_HOME="$CASA/.local/state" \
    LANG=C.UTF-8 NO_COLOR=1 "$@"
}

python3 - "$T/meu-tema.csv" "$RAIZ/packs/dracula/paleta.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[2], encoding="utf-8"))
ordem = p.get("ordem_canonica") or list(next(iter(p["flavors"].values())))
cores = p["flavors"]["dracula"]
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("slot,flavor,hex\n" + "".join(f"{n},meutema,{cores[n]}\n" for n in ordem))
PY
s="$(amb python3 "$RAIZ/scripts/pack.py" importar "$T/meu-tema.csv" 2>&1)" \
  || { falha "o CSV não virou pack pelo caminho do Personalizar" "$s"; exit 1; }

conf_com() {
  cp "$RAIZ/meow.conf.exemplo" "$CONF"
  python3 - "$CONF" "$@" <<'PY'
import re, sys
arq, pares = sys.argv[1], sys.argv[2:]
texto = open(arq, encoding="utf-8").read()
for par in pares:
    chave, valor = par.split("=", 1)
    texto, n = re.subn(r"(?m)^%s=.*$" % re.escape(chave), lambda m: "%s=%s" % (chave, valor), texto)
    if not n:
        texto += "\n%s=%s\n" % (chave, valor)
open(arq, "w", encoding="utf-8").write(texto)
PY
}
par() { printf '%s/%s' "$(sed -n 's/^PACK="\([^"]*\)".*/\1/p' "$CONF" | tail -1)" "$(sed -n 's/^FLAVOR="\([^"]*\)".*/\1/p' "$CONF" | tail -1)"; }

printf '\n--- 1. o disco cheio no meio do pack usar não parte o par ---\n'
MV_REAL="$(command -v mv)"
DISCO="$T/disco"; mkdir -p "$DISCO"
cat > "$DISCO/mv" <<SH
#!/bin/sh
for a in "\$@"; do destino="\$a"; done
if [ "\$destino" = "$CONF" ]; then
  n=\$(cat "$T/mv-conf" 2>/dev/null || echo 0); n=\$((n + 1)); echo "\$n" > "$T/mv-conf"
  [ "\$n" -ge "\$MV_FALHA_DESDE" ] && { echo "mv: No space left on device" >&2; exit 1; }
fi
exec "$MV_REAL" "\$@"
SH
chmod 755 "$DISCO/mv"
for desde in 1 2; do
  conf_com 'PACK="meu-tema"' 'FLAVOR="meutema"'
  rm -f "$T/mv-conf"
  s="$(amb env PATH="$DISCO:$FALSO:$PATH" MV_FALHA_DESDE="$desde" "$RAIZ/bin/meow" pack usar meowsystem --sem-aplicar 2>&1)"
  case "$(par)" in
    meu-tema/meutema|meowsystem/mocha)
      ok "com a escrita $desde do meow.conf falhando, o par fica inteiro: $(par)" ;;
    *) falha "a escrita $desde do meow.conf falhou e o par partiu: $(par)" "$s" ;;
  esac
  restos="$(find "$(dirname "$CONF")" -name '.atomicwrite.meow.*' 2>/dev/null)"
  [ -z "$restos" ] || falha "a escrita $desde que falhou deixou temporário ao lado do meow.conf" "$restos"
done
conf_com 'PACK="meu-tema"' 'FLAVOR="meutema"'
s="$(amb "$RAIZ/bin/meow" pack usar meowsystem --sem-aplicar 2>&1)"
[ "$(par)" = "meowsystem/mocha" ] && grep -q 'pack usar meowsystem flavor=mocha' "$ESTADO/meow.log" 2>/dev/null \
  && ok "sem falha, o pack usar grava o par e o meow.log diz a troca" \
  || falha "o pack usar sem falha não gravou o par ($(par))" "$s"

printf '\n--- 2. o doctor conserta o par partido, pelo que a pessoa escolheu por último ---\n'
doctor() {
  amb env VS="conf" bash -c 'source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow"); read -ra VERIFICAVEIS <<< "$VS"; cmd_doctor "$@"' _ "$@" 2>&1
}
caso() {
  local rotulo="$1" log="$2" quer="$3" antes s1 rc1 s2 rc2 s3 rc3 marca
  conf_com 'PACK="meowsystem"' 'FLAVOR="meutema"'
  rm -f "$ESTADO/meow.log"
  [ -z "$log" ] || printf '%s\n' "$log" > "$ESTADO/meow.log"
  s1="$(doctor)"; rc1=$?
  s2="$(doctor --consertar)"; rc2=$?
  marca="$(stat -c %Y.%s "$CONF")"; antes="$(sha256sum < "$CONF")"
  s3="$(doctor --consertar)"; rc3=$?
  if [ "$rc1" = 1 ] && grep -q 'PACK e FLAVOR' <<< "$s1" && [ "$(par)" = "$quer" ] \
     && [ "$rc3" = 0 ] && [ "$antes" = "$(sha256sum < "$CONF")" ] && [ "$marca" = "$(stat -c %Y.%s "$CONF")" ]; then
    ok "$rotulo: o doctor acusa, o --consertar deixa $quer e a segunda passada não escreve"
  else
    falha "$rotulo: o par não ficou $quer (conferir=$rc1, consertar=$rc2, segunda=$rc3, par=$(par))" \
      "$s1
---
$s2
---
$s3"
  fi
  if grep -qiE 'digite|rode `|execute|meow pack usar' <<< "$s1$s2$s3"; then
    falha "$rotulo: uma saída do doctor manda digitar" "$s1$s2$s3"
  fi
}
caso "o último pack usar foi o pack pessoal" \
  "2026-10-28T18:06:40-03:00 pack usar meu-tema flavor=meutema" "meu-tema/meutema"
caso "o último pack usar foi o meowsystem" \
  "2026-10-28T18:06:40-03:00 pack usar meu-tema flavor=meutema
2026-10-28T19:00:00-03:00 pack usar meowsystem flavor=macchiato" "meowsystem/mocha"
printf '%s\n%s' "2026-10-28T18:06:40-03:00 pack usar meu-tema flavor=meutema" \
  "2026-10-28T18:48:41-03:00 pack usar meowsystem flavor=moc" > "$T/cortada.log"
s="$(amb python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import pack; print(pack.ultimo_pack_usar(sys.argv[2]))' \
       "$RAIZ/scripts" "$T/cortada.log" 2>&1)"
[ "$s" = "('meu-tema', 'meutema')" ] \
  && ok "uma linha cortada no fim do meow.log não conta como escolha" \
  || falha "a linha cortada do meow.log virou escolha: $s"
conf_com 'PACK="meowsystem"' 'FLAVOR="meutema"'
rm -f "$ESTADO/meow.log"
s1="$(doctor)"; s2="$(doctor --consertar)"
if [ "$(par)" = "meowsystem/meutema" ] && ! grep -q 'PACK e FLAVOR' <<< "$s1$s2"; then
  ok "sem escolha no meow.log, o par fica como ela escreveu e o meow_flavor resolve na leitura"
else
  falha "sem escolha no meow.log, o doctor mexeu no par (par=$(par))" "$s1
---
$s2"
fi

printf '\n--- 3. o painel grava PACK e FLAVOR juntos e coerentes ---\n'
painel() {
  amb python3 -I - "$RAIZ" "$@" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1] + "/app")
import servidor
pares = [tuple(a.split("=", 1)) for a in sys.argv[2:]]
print(" ".join("%s:%s" % (c, rc) for c, rc, _s in sorted(servidor.definir_varias(pares))))
PY
}
conf_com 'PACK="meu-tema"' 'FLAVOR="meutema"'
s="$(painel PACK=meowsystem)"
[ "$(par)" = "meowsystem/mocha" ] && [ "$s" = "FLAVOR:1 PACK:1" ] \
  && ok "o cartão PACK sozinho no painel leva o FLAVOR padrão junto" \
  || falha "o painel gravou PACK sem o FLAVOR ($(par))" "$s"
s="$(painel FLAVOR=meutema)"
[ "$(par)" = "meu-tema/meutema" ] && [ "$s" = "FLAVOR:1 PACK:1" ] \
  && ok "o FLAVOR de outro pack no painel leva o PACK dono junto" \
  || falha "o painel gravou FLAVOR sem o PACK dono ($(par))" "$s"
s="$(painel PACK=meu-tema FLAVOR=meutema ACCENT=blue)"
[ "$(par)" = "meu-tema/meutema" ] && [ "$s" = "ACCENT:1 FLAVOR:0 PACK:0" ] \
  && ok "o par já coerente fica, e o painel diz que não mudou" \
  || falha "o par coerente mexeu ou o painel disse errado o que gravou ($(par))" "$s"
lote_no_disco() {
  conf_com 'PACK="meu-tema"' 'FLAVOR="meutema"' 'NOITE_INICIO="19:00"' 'NOITE_FIM="06:00"'
  rm -f "$T/mv-conf"
  amb env PATH="$DISCO:$FALSO:$PATH" MV_FALHA_DESDE="$1" python3 -I - "$RAIZ" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1] + "/app")
import servidor
pares = [("PACK", "meowsystem"), ("NOITE_INICIO", "20:00"), ("NOITE_FIM", "07:00")]
print(" ".join("%s:%s" % (c, rc) for c, rc, _s in sorted(servidor.definir_varias(pares))))
PY
}
s="$(lote_no_disco 2)"
[ "$(cat "$T/mv-conf" 2>/dev/null)" = 1 ] && [ "$s" = "FLAVOR:1 NOITE_FIM:1 NOITE_INICIO:1 PACK:1" ] \
  && [ "$(par)" = "meowsystem/mocha" ] && grep -qx 'NOITE_INICIO="20:00"' "$CONF" && grep -qx 'NOITE_FIM="07:00"' "$CONF" \
  && ok "o lote do painel é uma escrita só: o par do pack e as pontas da noite vão juntos" \
  || falha "o lote do painel foi em mais de uma escrita ($(par))" "$s
$(grep -E '^(NOITE_INICIO|NOITE_FIM)=' "$CONF")"
s="$(lote_no_disco 1)"
[ "$s" = "FLAVOR:2 NOITE_FIM:2 NOITE_INICIO:2 PACK:2" ] && [ "$(par)" = "meu-tema/meutema" ] \
  && grep -qx 'NOITE_INICIO="19:00"' "$CONF" && [ -z "$(find "$(dirname "$CONF")" -name '.atomicwrite.meow.*')" ] \
  && ok "com o disco cheio, o lote do painel não grava nada e não deixa temporário" \
  || falha "com o disco cheio, o lote do painel gravou pela metade ($(par))" "$s"

printf '\n--- 4. o mimetypes nunca sai calado com 1 ---\n'
mimetypes() { amb env FLAVOR="$1" ICONES_FLAVOR="$2" PACK="" "$RAIZ/scripts/icones_mimetypes.sh" 2>&1; }
ICONES="$CASA/.local/share/icons"
rm -rf "$ICONES"
s1="$(mimetypes "" "")"; rc1=$?
marca="$(find "$ICONES" -type f -printf '%P %T@ %s\n' 2>/dev/null | sort | sha256sum)"
s2="$(mimetypes "" "")"; rc2=$?
if [ "$rc1" = 1 ] && grep -q 'flavor mocha' <<< "$s1" && [ "$rc2" = 0 ] \
   && [ "$marca" = "$(find "$ICONES" -type f -printf '%P %T@ %s\n' 2>/dev/null | sort | sha256sum)" ]; then
  ok "sem flavor, os tipos de arquivo vestem o padrão do pack (mocha) e a segunda passada não escreve"
else
  falha "sem flavor, o mimetypes não caiu no padrão do pack (rc=$rc1, depois rc=$rc2)" "$s1
---
$s2"
fi
s="$(mimetypes meowsystem zzz)"; rc=$?
[ "$rc" != 1 ] && [ -n "$s" ] \
  && ok "um ICONES_FLAVOR sem acervo diz o que houve e não passa por «mexeu» (rc=$rc)" \
  || falha "o mimetypes saiu com $rc$( [ -n "$s" ] || printf ' calado')" "$s"

printf '\n--- 5. o pack usar do pack pessoal deriva o tema do COSMIC, sem ERRO ---\n'
conf_com 'PACK="meowsystem"' 'FLAVOR="mocha"' 'ACCENT="mauve"'
rm -rf "$CASA/.local/share/meowsystem/packs/meu-tema/temas/capturados"
s="$(amb bash -c 'source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow"); carregar_conf; cmd_aplicar() { printf "[o install]\n"; }; cmd_pack usar meu-tema' 2>&1)"; rc=$?
if [ "$rc" = 0 ] && ! grep -qE 'ERRO|não troca' <<< "$s" \
   && [ -d "$CASA/.local/share/meowsystem/packs/meu-tema/temas/capturados/meutema-mauve" ] \
   && grep -q "tema 'meutema-mauve' aplicado" <<< "$s"; then
  ok "o tema do COSMIC primeiro: a captura meutema-mauve nasce da paleta e é aplicada"
else
  falha "o pack usar do pack pessoal não aplicou o tema primeiro (rc=$rc)" "$s"
fi

printf '\n--- 6. o Spotify do pack pessoal ganha a seção do flavor, sem erro ---\n'
SPI="$T/spi"; mkdir -p "$SPI"
printf '#!/bin/sh\nexit 1\n' > "$SPI/pgrep"; printf '#!/bin/sh\nexit 0\n' > "$SPI/flatpak"
cat > "$SPI/spicetify" <<'SH'
#!/bin/sh
ini="$HOME/.config/spicetify/config-xpui.ini"
if [ "$1" = config ] && [ -n "$3" ]; then
  [ -f "$ini" ] || printf '[Setting]\n' > "$ini"
  grep -v "^$2 *=" "$ini" > "$ini.n"; printf '%s = %s\n' "$2" "$3" >> "$ini.n"; mv "$ini.n" "$ini"
fi
exit 0
SH
chmod 755 "$SPI"/*
SPOT_APP="$CASA/.local/share/flatpak/app/com.spotify.Client"
mkdir -p "$SPOT_APP/x86_64/stable/0123abcd/files/extra/share/spotify/Apps/xpui"
ln -sfn 0123abcd "$SPOT_APP/x86_64/stable/active"; ln -sfn x86_64/stable "$SPOT_APP/current"
spotify() {
  amb env PATH="$SPI:$FALSO:$PATH" XDG_DATA_HOME="$CASA/.local/share" TMPDIR="$T" PACK=meu-tema FLAVOR=meutema ACCENT=mauve \
    bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2; . "$MEOW_RAIZ/scripts/temas-de-apps/spotify/manifesto.sh" || exit 2; meow_app_aplicar' </dev/null 2>&1
}
INI="$CASA/.config/spicetify/Themes/catppuccin/color.ini"
PALETA="$CASA/.local/share/meowsystem/packs/meu-tema/paleta.json"
cor() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flavors"]["meutema"][sys.argv[2]].lstrip("#").lower())' "$PALETA" "$1"; }
s1="$(spotify)"; rc1=$?
secao="$(awk '$0 == "[meutema]" { d = 1; next } /^\[/ { d = 0 } d' "$INI" 2>/dev/null)"
estado="$(python3 "$RAIZ/scripts/temas-de-apps/spotify/acento.py" estado "$INI" --paleta "$PALETA" --flavor meutema --acento mauve 2>&1)"
marca="$(sha256sum < "$INI" 2>/dev/null)"
s2="$(spotify)"; rc2=$?
if [ "$rc1" = 1 ] && ! grep -q 'erro' <<< "$s1$s2" && [ "$rc2" != 2 ] \
   && grep -qE "^base +=  *$(cor base)$" <<< "$secao" && grep -qE "^text +=  *$(cor mauve)$" <<< "$secao" \
   && grep -qx 'ok=sim' <<< "$estado" && [ "$marca" = "$(sha256sum < "$INI")" ]; then
  ok "o color.ini ganha a seção [meutema] da paleta, com o acento, e a segunda passada não reescreve"
else
  falha "o Spotify do pack pessoal não ganhou a seção do flavor (rc=$rc1, depois rc=$rc2)" "$s1
---
$s2
---
$estado
$secao"
fi
printf '[Sem]\nmain = 000000\n' > "$T/sem.ini"
s="$(python3 "$RAIZ/scripts/temas-de-apps/spotify/acento.py" aplicar "$T/sem.ini" --paleta "$PALETA" --flavor meutema --acento mauve 2>&1)"; rc=$?
[ "$rc" = 3 ] && grep -q 'nem uma de onde' <<< "$s" \
  && ok "um tema sem seção de onde derivar diz 3 (fica o tema herdado), não erro" \
  || falha "o acento.py sem seção de onde derivar saiu $rc" "$s"

[ "$falhas" = 0 ] || { printf '\n%s falha(s)\n' "$falhas" >&2; exit 1; }
printf '\ntudo certo\n'

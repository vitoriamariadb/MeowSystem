#!/usr/bin/env bash
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
painel_logo() {
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


printf '\n--- 6. papéis de parede separados por pack (decisão de 23/10) ---\n'
CP="$T/casa-pack"; BP="$CP/.local/share/backgrounds/meowsystem"
mkdir -p "$BP/ativos" "$CP/.config/meow" "$CP/cosmic"
cura="$(awk -F'\t' '$1 !~ /^#/ && $1 != "arquivo" && $1 != "" {print $1; exit}' "$RAIZ/packs/meowsystem/wallpapers/FONTES.tsv")"
for n in cat-a.png cat-b.png "$cura" tulip-x.png tulip-y.png minha.png; do
  printf 'P3\n1 1\n255\n10 20 30\n' > "$BP/ativos/$n"
done
wpp() { env -i PATH="$T/falso:$PATH" HOME="$CP" MEOW_RAIZ="$RAIZ" NO_COLOR=1 MEOW_COSMIC_DIR="$CP/cosmic" \
          WALLPAPER_NOITE=nao "$@" "$RAIZ/scripts/wallpaper.sh" aplicar 2>&1; }
fonte() { grep -rhoP 'source: Path\("\K[^"]+' "$CP/cosmic" 2>/dev/null | sort -u; }
colecao() { ls -1 "$BP/ativos-pack" 2>/dev/null | tr '\n' ' '; }
s1="$(wpp PACK=dracula)"; r1=$?
if [ "$r1" = 1 ] && [ "$(fonte)" = "$BP/ativos-pack" ] && [ "$(colecao)" = "minha.png tulip-x.png tulip-y.png " ] \
   && [ "$(ls "$BP/ativos" | wc -l)" = 6 ]; then
  ok "com o Dracula no ar gira só a coleção dele (e a imagem de pack nenhum); ativos/ fica inteira"
else
  falha "o Dracula no ar girou outra coleção (rc=$r1, fonte=$(fonte), coleção=$(colecao))" "$s1"
fi
s2="$(wpp PACK=dracula)"; r2=$?
[ "$r2" = 0 ] && ok "a segunda passada não escreve" || falha "a segunda passada com o Dracula escreveu (rc=$r2)" "$s2"
s3="$(wpp PACK=meowsystem MEOW_DRY_RUN=1)"; r3=$?
[ "$r3" = 1 ] && [ "$(colecao)" = "minha.png tulip-x.png tulip-y.png " ] \
  && ok "o ensaio da troca de pack diz que refaria a coleção, sem escrever" \
  || falha "o ensaio da troca de pack escreveu ou calou (rc=$r3)" "$s3"
s4="$(wpp PACK=meowsystem)"; r4=$?
if [ "$r4" = 1 ] && [ "$(colecao)" = "cat-a.png cat-b.png $cura minha.png " ] && grep -q 'cosmic-bg avisado' <<< "$s4"; then
  ok "trocar de pack troca a coleção: cat-, a curadoria e a de pack nenhum, e o cosmic-bg relê"
else
  falha "trocar de pack não trocou a coleção (rc=$r4, coleção=$(colecao))" "$s4"
fi
painel="$(env -i PATH="$T/falso:$PATH" HOME="$CP" MEOW_RAIZ="$RAIZ" MEOW_CONF="$CP/.config/meow/meow.conf" \
  python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
itens = [i for i in servidor._prev_paredes() if i["grupo"] == "ativos"]
print(" ".join(sorted(i["rotulo"] for i in itens)))
print(all(i["banir"].endswith("/ativos/" + i["rotulo"]) for i in itens))
PY
)"
[ "$painel" = "$(printf 'cat-a.png cat-b.png %s minha.png\nTrue' "$cura")" ] \
  && ok "o «No carrossel» do painel mostra a coleção do pack no ar, e o Tirar age em ativos/" \
  || falha "o painel mostra outra coleção no «No carrossel»" "$painel"
rm -f "$BP/ativos"/tulip-*
s5="$(wpp PACK=meowsystem)"; r5=$?
[ "$r5" = 1 ] && [ "$(fonte)" = "$BP/ativos" ] && [ ! -e "$BP/ativos-pack" ] \
  && ok "sem papel de outro pack, gira ativos/ e a pasta da coleção sai" \
  || falha "sem papel de outro pack a rotação não voltou a ativos/ (rc=$r5, fonte=$(fonte))" "$s5"
printf '\n--- 9. sem cosmic-greeter, a ponte responde e nenhum sudo sai dela ---\n'
GT="$T/greeter"; mkdir -p "$GT/bin" "$GT/ponte" "$GT/casa"
cat > "$GT/ponte/ponte_root.sh" <<'PONTE'
#!/bin/sh
case "$1" in estado) exit 0 ;; greeter-ver) exit 3 ;; *) exit 1 ;; esac
PONTE
chmod 755 "$GT/ponte/ponte_root.sh"
printf 'lar=%s\n' "$GT/casa" > "$GT/ponte/perfil"
cat > "$GT/bin/sudo" <<SUDO
#!/bin/sh
[ "\$1" = -n ] && shift
[ "\$1" = "$GT/ponte/ponte_root.sh" ] && exec "\$@"
printf '%s\\n' "\$*" >> "$GT/fora.log"; exit 1
SUDO
chmod 755 "$GT/bin/sudo"; : > "$GT/fora.log"
for c in busctl gsettings pkexec; do ln -sf "$T/falso/$c" "$GT/bin/$c"; done
env -i PATH="$GT/bin:$PATH" HOME="$GT/casa" USER=gata MEOW_RAIZ="$RAIZ" MEOW_PONTE="$GT/ponte/ponte_root.sh" \
    GREETER_HOME="$GT/sem-greeter" NO_COLOR=1 FLAVOR=dracula PACK=dracula \
    bash "$RAIZ/scripts/greeter.sh" > "$GT/saida.log" 2>&1; rg=$?
[ ! -s "$GT/fora.log" ] && [ "$rg" = 0 ] && grep -q 'não há cosmic-greeter' "$GT/saida.log" \
  && ok "sem cosmic-greeter, a ponte diz que não há e o greeter.sh não chama sudo fora dela" \
  || falha "o greeter.sh chamou sudo fora da ponte, ou não pulou (rc=$rg)" "$(cat "$GT/fora.log" "$GT/saida.log")"

printf '\n--- 10. sem a ponte, nenhum sudo: o caminho vira pendência ---\n'
SP="$T/sem-ponte"; mkdir -p "$SP/bin" "$SP/casa" "$SP/sistema" "$SP/greeter" "$SP/contas"
cat > "$SP/bin/sudo" <<SUDO
#!/bin/sh
printf '%s\\n' "\$*" >> "$SP/sudo.log"; exit 1
SUDO
printf '#!/bin/sh\nexit 0\n' > "$SP/bin/update-desktop-database"
printf '[Desktop Entry]\nName=X\n' > "$SP/sistema/x.desktop"; cp "$SP/sistema/x.desktop" "$SP/novo.desktop"; chmod 444 "$SP/sistema/x.desktop"
printf 'nao-legivel\n' > "$SP/contas/gata"; chmod 000 "$SP/contas/gata"
cat > "$SP/bin/busctl" <<BUS
#!/bin/sh
case "\$*" in
  *FindUserByName*) echo 'o "/org/freedesktop/Accounts/User1000"' ;;
  *IconFile*) echo 's "$SP/contas/gata"' ;;
esac
exit 0
BUS
chmod 755 "$SP/bin/"*; chmod 555 "$SP/sistema"; : > "$SP/sudo.log"
sp_amb() {
  env -i PATH="$SP/bin:$PATH" HOME="$SP/casa" USER=gata MEOW_RAIZ="$RAIZ" MEOW_PONTE=/nao/existe \
    GREETER_HOME="$SP/greeter" NO_COLOR=1 FLAVOR=dracula PACK=dracula "$@"
}
sp_amb bash -c '. "$MEOW_RAIZ/lib/comum.sh" >/dev/null 2>&1 || exit 9
  meow_desktop_pode "$1/sistema/x.desktop"; echo "pode=$?"
  meow_desktop_escrever "$1/sistema/x.desktop" "$1/novo.desktop"; echo "escrever=$?"
  meow_desktop_banco "$1/sistema"; echo "banco=$?"' _ "$SP" > "$SP/lib.log" 2>&1
sp_amb bash "$RAIZ/scripts/greeter.sh" > "$SP/greeter.log" 2>&1; rg=$?
chmod 755 "$SP/sistema"; chmod 644 "$SP/contas/gata"
grep -qx 'pode=1' "$SP/lib.log" && ! grep -qx 'escrever=0' "$SP/lib.log" && [ "$rg" != 0 ] \
  && [ ! -s "$SP/sudo.log" ] \
  && ok "sem a ponte, o .desktop do sistema, o banco, o avatar e a tela de login ficam pendentes, com zero sudo" \
  || falha "sem a ponte, houve sudo fora dela, ou algo foi dado por feito (rc greeter=$rg)" \
       "$(cat "$SP/sudo.log" "$SP/lib.log"; tail -4 "$SP/greeter.log")"

printf '\n--- 11. sem a ponte, o Icon= de sistema é pendência, e a saída não manda rodar sudo ---\n'
IA="$T/icon-abs"; mkdir -p "$IA/apps" "$IA/casa/.local/share/icons/Falso/scalable/apps"
printf '[Icon Theme]\nName=Falso\nDirectories=scalable/apps\n[scalable/apps]\nSize=48\nType=Scalable\nMinSize=8\nMaxSize=512\n' \
  > "$IA/casa/.local/share/icons/Falso/index.theme"
printf '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48"/>\n' \
  > "$IA/casa/.local/share/icons/Falso/scalable/apps/input-remapper.svg"
printf '[Desktop Entry]\nName=Input Remapper\nIcon=/usr/share/input-remapper/input-remapper.svg\n' \
  > "$IA/apps/input-remapper-gtk.desktop"
cp "$IA/apps/input-remapper-gtk.desktop" "$IA/antes.desktop"
chmod 444 "$IA/apps/input-remapper-gtk.desktop"; chmod 555 "$IA/apps"; : > "$SP/sudo.log"
env -i PATH="$SP/bin:$PATH" HOME="$IA/casa" MEOW_RAIZ="$RAIZ" MEOW_PONTE=/nao/existe NO_COLOR=1 \
  MEOW_APLICATIVOS_SISTEMA="$IA/apps" ICONES_TEMA=Falso \
  bash "$RAIZ/scripts/icones_absolutos.sh" > "$IA/saida.log" 2>&1; ri=$?
chmod 755 "$IA/apps"
[ "$ri" != 0 ] && cmp -s "$IA/apps/input-remapper-gtk.desktop" "$IA/antes.desktop" \
  && grep -q '1 Icon= .*«Instalar tudo»' "$IA/saida.log" && ! grep -qi 'sudo' "$IA/saida.log" \
  && [ ! -s "$SP/sudo.log" ] \
  && ok "sem a ponte, o Icon= de sistema fica pendente, com a saída das outras pendências e zero sudo" \
  || falha "sem a ponte, o icones_absolutos.sh mandou rodar sudo, escreveu ou deu por feito (rc=$ri)" \
       "$(cat "$SP/sudo.log" "$IA/saida.log")"

printf '\n--- 12. o avatar ilegível da tela de login não é trocado às cegas ---\n'
AV="$T/av-ilegivel"; mkdir -p "$AV/bin" "$AV/casa" "$AV/contas"
printf '<svg/>\n' > "$AV/contas/gata"; chmod 000 "$AV/contas/gata"
cat > "$AV/bin/busctl" <<BUS
#!/bin/sh
printf '%s\n' "\$*" >> "$AV/busctl.log"
case "\$*" in
  *FindUserByName*) echo 'o "/org/freedesktop/Accounts/User1000"' ;;
  *IconFile*) echo 's "$AV/contas/gata"' ;;
esac
exit 0
BUS
chmod 755 "$AV/bin/busctl"; : > "$AV/busctl.log"
env -i PATH="$AV/bin:$SP/bin:$PATH" HOME="$AV/casa" USER=gata MEOW_RAIZ="$RAIZ" MEOW_PONTE=/nao/existe \
  GREETER_HOME="$AV/greeter" NO_COLOR=1 FLAVOR=dracula PACK=dracula \
  bash "$RAIZ/scripts/greeter.sh" > "$AV/saida.log" 2>&1
chmod 644 "$AV/contas/gata"
! grep -q 'SetIconFile' "$AV/busctl.log" && [ ! -e "$AV/casa/.local/state/meowsystem/greeter-avatar.md5" ] \
  && grep -q 'avatar.*pendente' "$AV/saida.log" \
  && ok "o avatar que não se lê fica como está, e a pendência aparece" \
  || falha "o greeter.sh trocou um avatar que não conseguiu ler, ou calou a pendência" \
       "$(cat "$AV/busctl.log"; head -6 "$AV/saida.log")"

printf '\n--- 13. sem a ponte, o nome de sistema é pendência, e a saída não manda rodar sudo ---\n'
NA="$T/nomes-abs"; mkdir -p "$NA/apps" "$NA/casa"
printf '[Desktop Entry]\nName=GNU Image Manipulation Program\nExec=gimp\n' > "$NA/apps/org.gimp.GIMP.desktop"
cp "$NA/apps/org.gimp.GIMP.desktop" "$NA/antes.desktop"
chmod 444 "$NA/apps/org.gimp.GIMP.desktop"; chmod 555 "$NA/apps"; : > "$SP/sudo.log"
env -i PATH="$SP/bin:$PATH" HOME="$NA/casa" MEOW_RAIZ="$RAIZ" MEOW_PONTE=/nao/existe NO_COLOR=1 \
  MEOW_APLICATIVOS_SISTEMA="$NA/apps" \
  bash "$RAIZ/scripts/nomes_apps.sh" > "$NA/saida.log" 2>&1; rn=$?
chmod 755 "$NA/apps"
cmp -s "$NA/apps/org.gimp.GIMP.desktop" "$NA/antes.desktop" \
  && grep -q '1 nome.*«Instalar tudo»' "$NA/saida.log" && ! grep -qi 'sudo' "$NA/saida.log" \
  && [ ! -s "$SP/sudo.log" ] \
  && ok "sem a ponte, o nome de sistema fica pendente, com a saída das outras pendências e zero sudo" \
  || falha "sem a ponte, o nomes_apps.sh mandou rodar sudo, escreveu ou deu por feito (rc=$rn)" \
       "$(cat "$SP/sudo.log" "$NA/saida.log")"

printf '\n'
[ "$ACHADOS" -eq 0 ] || { printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2; exit 1; }
printf 'passou: os achados técnicos da P79 estão fechados\n'
exit 0

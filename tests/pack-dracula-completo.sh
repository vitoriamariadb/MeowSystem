#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO" "$T/casa"
printf '#!/bin/sh\nprintf "sudo: recusado pelo tests/pack-dracula-completo.sh\\n" >&2\nexit 1\n' > "$FALSO/sudo"
chmod 755 "$FALSO/sudo"

amb() {
  env -i PATH="$FALSO:$PATH" HOME="$T/casa" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" "$@"
}

saida="$(amb env ICONES_BASE=Papirus-Dark python3 "$RAIZ/scripts/pack.py" base-icones dracula 2>&1)"
atras="$(printf '%s\n' "$saida" | sed -n 's/^atras=//p')"
if [[ "$saida" == *"quem=pack"* ]] && [[ "$saida" == *"/00a230a277d5e6ad913b90182977738335afee89.tar.gz"* ]] \
   && [ "$(printf '%s\n' "$atras" | grep -c .)" = "1" ] \
   && [[ "$atras" == *"/de2a8edd94608ba0ac4dcf5a187af0ffaa511ebc.tar.gz"$'\t'*$'\t'"dracula-icons-de2a8edd94608ba0ac4dcf5a187af0ffaa511ebc" ]] \
   && [[ "$atras" =~ $'\t'[0-9a-f]{64}$'\t' ]]; then
  ok "a base do Dracula tem duas camadas pinadas: circle na frente, main por trás"
else
  falha "o verbo base-icones não diz as duas camadas da base do Dracula" "$saida"
fi
v="$(amb env ICONES_BASE=MeowSystem-Icons-Base-2 python3 "$RAIZ/scripts/pack.py" base-icones dracula 2>&1 | sed -n 's/^quem=//p')"
[ "$v" = "pack" ] \
  && ok "ICONES_BASE=MeowSystem-Icons-Base-2 (a camada de trás) cede ao pack, como a frente" \
  || falha "o nome da camada de trás foi lido como escolha à mão" "quem=$v"

mkdir -p "$T/packs"
cp -r "$RAIZ/packs/dracula" "$T/packs/torto"
python3 - "$T/packs/torto/pack.json" <<'PY'
import json, sys
f = sys.argv[1]
p = json.load(open(f, encoding="utf-8"))
p["id"] = "torto"
p["icones"]["base"]["por_tras"][0]["origem"].pop("sha256")
json.dump(p, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
saida="$(amb env MEOW_PACKS="$T/packs" python3 "$RAIZ/scripts/pack.py" validar torto 2>&1)"; rc=$?
[ "$rc" != "0" ] && [[ "$saida" == *"icones.base.por_tras[0].origem"* ]] \
  && ok "uma camada de trás sem sha256 é recusada pelo validar, com a trilha do campo" \
  || falha "o validar aceitou uma camada de trás sem pino (rc=$rc)" "$saida"

nomes="$(for par in "dracula" "dracula alucard" "meowsystem mocha"; do
  # shellcheck disable=SC2086
  amb python3 "$RAIZ/scripts/pack.py" tema-icones $par 2>&1 | sed -n 's/^nome=//p'
done | paste -sd' ')"
[ "$nomes" = "MeowSystem-Dracula-Icons MeowSystem-Dracula-Alucard-Icons MeowSystem-Mocha-Icons" ] \
  && ok "o tema exportado se chama pelo pack e pelo flavor: $nomes" \
  || falha "o nome do tema exportado não é o do pack e do flavor" "$nomes"
com="$(amb python3 "$RAIZ/scripts/pack.py" tema-icones dracula alucard 2>&1 | sed -n 's/^comentario=//p')"
[[ "$com" == "Dracula (alucard) — "* ]] && [[ "$com" != *Catppuccin* ]] \
  && ok "o comentário do tema é o do pack, sem Catppuccin: $com" \
  || falha "o comentário do tema do Dracula não é o do pack" "$com"
grep -q '^Comment=\$COMENTARIO_TEMA$' "$RAIZ/scripts/construir_icones.sh" \
  && ! grep -q 'Comment=Catppuccin' "$RAIZ/scripts/construir_icones.sh" \
  && ok "o índice instalado escreve o comentário do pack, e não «Catppuccin»" \
  || falha "o construir_icones.sh ainda escreve um Comment fixo"

TEMA="$T/casa/.local/share/icons/MeowSystem-Icons"
mkdir -p "$TEMA/scalable/apps" "$TEMA/48x48/apps" "$TEMA/scalable/mimetypes" "$TEMA/22x22/status" "$TEMA/scalable/status"
for d in scalable/apps 48x48/apps scalable/mimetypes 22x22/status scalable/status; do
  printf '<svg/>\n' > "$TEMA/$d/x.svg"
done
printf '[Icon Theme]\nName=MeowSystem-Icons\nComment=velho\nInherits=Tema-X,MeowSystem-Icons-Base-2,breeze-dark,Cosmic,Adwaita,hicolor\nDirectories=scalable/apps\n' \
  > "$TEMA/index.theme"
indice() { amb PACK=dracula FLAVOR=dracula NOME_TEMA_ICONES=MeowSystem-Icons bash "$RAIZ/scripts/construir_icones.sh" indice 2>&1; }
s1="$(indice)"; rc1=$?
s2="$(indice)"; rc2=$?
dirs="$(sed -n 's/^Directories=//p' "$TEMA/index.theme")"
herda="$(sed -n 's/^Inherits=//p' "$TEMA/index.theme")"
if [ "$rc1" = "1" ] && [ "$rc2" = "0" ] \
   && [ "$dirs" = "48x48/apps,scalable/apps,scalable/mimetypes,22x22/status,scalable/status" ] \
   && [ "$herda" = "Tema-X,MeowSystem-Icons-Base-2,breeze-dark,Cosmic,Adwaita,hicolor" ]; then
  ok "o índice do fim declara o que as outras etapas criaram, guarda a herança, e a 2ª vez não escreve"
else
  falha "o índice do fim não descreveu o disco, mexeu na herança, ou não convergiu (rc $rc1/$rc2)" \
    "Directories=$dirs
Inherits=$herda
$s1
$s2"
fi
ordem="$(sed -n '/local etapas=(/,/)/p' "$RAIZ/install.sh" | grep -oE '\betapa_[a-z_0-9]+\b' | tr '\n' ' ')"
[[ "$ordem" == *"etapa_logo etapa_icones_indice "* ]] \
  && ok "no install.sh a etapa do índice vem logo depois da dos mascotes, a última que escreve no tema" \
  || falha "a etapa do índice não está depois da última que escreve no tema" "$ordem"
[[ "$(sed -n 's/^VERIFICAVEIS=(\(.*\))$/\1/p' "$RAIZ/bin/meow")" == *" logo indice" ]] \
  && ok "no doctor o índice é a última conferência" \
  || falha "o doctor não confere o índice depois de tudo"

linha="$(amb python3 "$RAIZ/scripts/pack.py" info dracula 2>&1 | grep -E '^  icones\.mimetypes ')"
[[ "$linha" == *"HERDADO de meowsystem"*"656 desenho(s)"* ]] \
  && ok "icones.mimetypes do Dracula vem do molde do meowsystem: 656 desenhos" \
  || falha "o info não diz os ícones de arquivo do Dracula como o molde herdado" "$linha"
macc="$(python3 -c 'import json,sys;print("|".join(v.lower() for v in json.load(open(sys.argv[1]))["flavors"]["macchiato"].values()))' "$RAIZ/packs/meowsystem/paleta.json")"
total=0; com_macc=0
for fl in dracula alucard; do
  pint="$(amb python3 "$RAIZ/scripts/pack.py" pintados dracula "$fl" --temporario 2>/dev/null)"
  [ -d "$pint" ] || continue
  total=$((total + $(find "$pint" -name '*.svg' | wc -l)))
  com_macc=$((com_macc + $(grep -liE "$macc" "$pint"/*.svg | wc -l)))
  rm -rf "$pint"
done
[ "$total" = 1312 ] && [ "$com_macc" = 0 ] \
  && ok "o molde pintado com a paleta do Dracula dá $total ícones de arquivo, nenhum com cor do macchiato" \
  || falha "ícones de arquivo do Dracula com cor do Catppuccin, ou contagem errada" "total=$total com_macchiato=$com_macc"
[ ! -e "$RAIZ/packs/dracula/icones/sistema/mimetypes" ] && ! grep -rlq 'vscode-ctp' "$RAIZ/packs/dracula/icones" \
  && ok "o pack Dracula não guarda tipo de arquivo pintado nem cópia do molde" \
  || falha "o pack Dracula guarda tipo de arquivo que a instalação devia pintar"
mapa="$(amb python3 "$RAIZ/scripts/pack.py" acervo dracula icones.pastas.mapa 2>&1)"
nomes="$(grep -v '^#' "$mapa" 2>/dev/null | grep -c ':')"
faltam=""
while IFS=: read -r n g; do
  case "$n" in ''|'#'*) continue ;; esac
  [ -f "$RAIZ/packs/dracula/icones/sistema/$g.svg" ] || faltam="$faltam $g"
done < "$mapa"
[ "$nomes" = 10 ] && [ -z "$faltam" ] && grep -q 'acervo "$_pack_ref" icones.pastas.mapa' "$RAIZ/scripts/construir_pastas.sh" \
  && ok "o mapa de pastas do Dracula veste dez nomes (folder, user-home e user-desktop inclusive), e quem cede lê o mesmo mapa" \
  || falha "o mapa de pastas do Dracula não tem as dez, falta desenho, ou o construir_pastas não o lê" "nomes=$nomes faltam=$faltam"

printf '#!/bin/sh\nexit 0\n' > "$FALSO/starship"; chmod 755 "$FALSO/starship"
prompt() {
  amb PACK="$1" FLAVOR="$2" MEOW_ESTADO="$T/estado" PROMPT_ALVO="$3" \
    bash "$RAIZ/scripts/prompt.sh" aplicar >/dev/null 2>&1
}
prompt dracula dracula "$T/st-dracula.toml"
prompt meowsystem mocha "$T/st-mocha.toml"
dra_mauve="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["flavors"]["dracula"]["mauve"].lower())' "$RAIZ/packs/dracula/paleta.json")"
if grep -qx "palette = 'dracula_dracula'" "$T/st-dracula.toml" 2>/dev/null \
   && grep -qx "mauve = \"$dra_mauve\"" "$T/st-dracula.toml" \
   && [ "$(grep -c '^\[palettes\.' "$T/st-dracula.toml")" = 1 ] \
   && ! grep -q '^\[palettes\.catppuccin' "$T/st-dracula.toml" \
   && [ "$(cat "$T/st-mocha.toml" 2>/dev/null)" = "$(cat "$RAIZ/assets/prompt/starship.toml")" ]; then
  ok "o prompt veste a paleta do Dracula com ele no ar, e com o Catppuccin Mocha é o preset de antes"
else
  falha "o prompt não segue a paleta do pack no ar" "$(grep -n '^palette\|^\[palettes\|^mauve' "$T/st-dracula.toml" 2>&1)"
fi
if ! grep -q 'valores.get("FLAVOR") or "mocha"' "$RAIZ/app/servidor.py" \
   && ! grep -qi 'que o Catppuccin escolheu' "$RAIZ/meow.conf.exemplo"; then
  ok "nenhuma rota da página cai no mocha com o FLAVOR vazio, e a aba Terminal não fala do Catppuccin"
else
  falha "sobrou um «or \"mocha\"» no servidor ou um «Catppuccin» na aba Terminal"
fi

if command -v git >/dev/null 2>&1; then
  C="$T/casa-obs"; V="$C/Cofre em Git"
  mkdir -p "$C/bin" "$V/.obsidian" "$C/.local/share/flatpak/app/md.obsidian.Obsidian/x86_64/stable/active" \
           "$C/.var/app/md.obsidian.Obsidian/config/obsidian"
  printf '#!/bin/sh\nexit 1\n' > "$C/bin/flatpak"; printf '#!/bin/sh\nexit 1\n' > "$C/bin/pgrep"
  chmod +x "$C/bin/flatpak" "$C/bin/pgrep"
  printf '{"vaults":{"v1":{"path":"%s","ts":1000,"open":true}}}' "$V" \
    > "$C/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json"
  printf '{\n  "enabledCssSnippets": [],\n  "cssTheme": "Tema do Outro",\n  "baseFontSize": 14\n}\n' \
    > "$V/.obsidian/appearance.json"
  g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$V" -c user.name=t -c user.email=t@t "$@"; }
  g init -q && g add .obsidian/appearance.json && g commit -qm inicial
  obs() {
    ( export HOME="$C" XDG_CONFIG_HOME="$C/.config" XDG_DATA_HOME="$C/.local/share" \
             MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$C/estado" NO_COLOR=1
      export PATH="$C/bin:$FALSO:$PATH" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
      unset MEOW_OBSIDIAN_VAULT PACK FLAVOR MEOW_PACK_DIR MEOW_PALETA
      . "$RAIZ/lib/comum.sh" || exit 2
      . "$RAIZ/scripts/temas-de-apps/obsidian/manifesto.sh" || exit 2
      "meow_app_$1" 2>&1; printf 'rc=%s\n' "$?" )
  }
  s1="$(obs aplicar)"
  tema_disco="$(sed -n 's/.*"cssTheme": "\([^"]*\)".*/\1/p' "$V/.obsidian/appearance.json")"
  sujo="$(g status --porcelain -- .obsidian/appearance.json)"
  g checkout -q -- .obsidian/appearance.json
  depois_checkout="$(sed -n 's/.*"cssTheme": "\([^"]*\)".*/\1/p' "$V/.obsidian/appearance.json")"
  g add .obsidian/appearance.json && g commit -qm 'outra coisa' --allow-empty
  no_commit="$(g show HEAD:.obsidian/appearance.json | sed -n 's/.*"cssTheme": "\([^"]*\)".*/\1/p')"
  s2="$(obs aplicar)"
  if [[ "$s1" == *rc=1* ]] && [ "$tema_disco" = "Catppuccin" ] && [ -z "$sujo" ] \
     && [ "$depois_checkout" = "Catppuccin" ] && [ "$no_commit" = "Tema do Outro" ] && [[ "$s2" == *rc=0* ]]; then
    ok "obsidian: o tema do pack fica no disco, o git do cofre guarda o dele, um checkout não o desfaz, e a 2ª passada é 0"
  else
    falha "obsidian: o tema do cofre em git ainda briga com o git" \
      "disco=$tema_disco sujo='$sujo' checkout=$depois_checkout commit=$no_commit
$s1
$s2"
  fi
  s3="$(obs reverter)"
  if [ -z "$(g config --local --get-regexp 'filter\.meow-obsidian|meow\.obsidian' 2>/dev/null)" ] \
     && ! grep -q meow-obsidian "$V/.git/info/attributes" 2>/dev/null; then
    ok "obsidian: o desfazer tira o filtro do git do cofre"
  else
    falha "obsidian: o filtro ficou no git do cofre depois do desfazer" "$s3"
  fi
else
  printf 'pulado: sem git, o cofre em git não se monta\n'
fi

vestido() {
  amb PACK="$1" FLAVOR="$2" MODO="$3" bash -c '. "$MEOW_RAIZ/lib/comum.sh"; meow_ponte_python >/dev/null 2>&1; meow_flavor_vestido' 2>/dev/null
}
tabela="$(for par in "dracula dracula claro" "dracula dracula escuro" "dracula alucard escuro" \
                     "dracula dracula auto" "catppuccin mocha claro" "catppuccin latte escuro"; do
  # shellcheck disable=SC2086
  printf '%s ' "$(vestido $par)"
done)"
if [ "$tabela" = "alucard dracula dracula dracula latte mocha " ] \
   && grep -q '^FLAVOR="$(meow_flavor_vestido)"' "$RAIZ/scripts/icones_apps_arcticons.sh" \
   && grep -q 'meow_flavor_vestido' "$RAIZ/scripts/construir_pastas.sh"; then
  ok "com MODO=claro o traço do dock e as pastas usam o claro do pack (e no escuro, o escuro)"
else
  falha "o flavor do lado vestido não é o que a tela veste, ou o traço e as pastas não o perguntam" "$tabela"
fi
UPF="${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem/upstream/papirus-folders"
if [ ! -d "$UPF/src" ]; then
  env -i PATH="$PATH" HOME="$T" MEOW_CACHE="$T/cache" NO_COLOR=1 bash "$RAIZ/scripts/baixar_upstream.sh" >/dev/null 2>&1
  UPF="$T/cache/upstream/papirus-folders"
fi
if [ -d "$UPF/src" ] && [ -d /usr/share/icons/Papirus-Dark ]; then
  s="$(amb PACK=dracula FLAVOR=dracula ACCENT=mauve MODO=claro ICONES_PASTAS=cat-dracula-mauve \
        MEOW_DRY_RUN=1 MEOW_CAT_FOLDERS="$UPF" bash "$RAIZ/scripts/construir_pastas.sh" 2>&1)"
  [[ "$s" == *"'cat-alucard-mauve' não existe no papirus-folders — derivada de 'cat-latte-mauve'"* ]] \
    && ok "com MODO=claro as pastas que acompanham o tema saem na variante do Alucard (derivada do Latte)" \
    || falha "com MODO=claro as pastas não foram para o claro do pack" "$s"
fi

CS="$T/casa-som"; FS="$CS/falso"; mkdir -p "$FS"
printf '#!/bin/sh\necho "pw-play $*" >> "%s/tocou.log"\n' "$CS" > "$FS/pw-play"
printf '#!/bin/sh\necho "systemctl $*" >> "%s/systemctl.log"\n' "$CS" > "$FS/systemctl"
cat > "$FS/dbus-monitor" <<'DBUS'
#!/bin/sh
printf 'signal time=1.0 sender=org.freedesktop.DBus -> destination=:1.9 serial=2; member=NameAcquired\n   string ":1.9"\n'
printf 'method call time=2.0 sender=:1.50 -> destination=:1.20 serial=7 path=/org/freedesktop/Notifications; interface=org.freedesktop.Notifications; member=Notify\n   string "app"\n   int32 -1\n'
sleep 1
printf 'method call time=3.0 sender=:1.51 -> destination=:1.20 serial=8 path=/org/freedesktop/Notifications; interface=org.freedesktop.Notifications; member=Notify\n   string "telegram"\n   array [\n      dict entry(\n         string "suppress-sound"\n         variant             boolean true\n      )\n   ]\n'
sleep 0.5
DBUS
chmod +x "$FS"/*
som() {
  env -i PATH="$FS:$FALSO:$PATH" HOME="$CS" LANG=C.UTF-8 NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
    MEOW_ESTADO="$CS/estado" PACK="$1" FLAVOR="$2" SOM=sim bash "$RAIZ/scripts/som.sh" "$3" >/dev/null 2>&1
}
som dracula dracula aplicar; r1=$?
som dracula dracula aplicar; r2=$?
som dracula dracula conferir; r3=$?
n_oga="$(find "$CS/.local/share/sounds/MeowSystem-Sons" -name '*.oga' 2>/dev/null | wc -l)"
unidade_ok=0
[ -f "$CS/.config/systemd/user/meow-som.service" ] \
  && [ "$(cat "$CS/.config/systemd/user/meow-som.service")" = "$(cat "$RAIZ/systemd/meow-som.service")" ] && unidade_ok=1
som dracula dracula vigiar
tocou="$(cat "$CS/tocou.log" 2>/dev/null)"
som meowsystem mocha aplicar; r4=$?
if [ "$r1" = 1 ] && [ "$r2" = 0 ] && [ "$r3" = 0 ] && [ "$n_oga" = 25 ] && [ "$unidade_ok" = 1 ] \
   && [ "$(printf '%s\n' "$tocou" | grep -c .)" = 1 ] && [[ "$tocou" == *"/MeowSystem-Sons/stereo/notification/message-new-instant.oga" ]] \
   && [ "$r4" = 1 ] && [ "$(find "$CS/.local/share/sounds/MeowSystem-Sons" -name '*.oga' 2>/dev/null | wc -l)" = 25 ] \
   && cmp -s "$RAIZ/packs/meowsystem/sons/stereo/notification/message-new-instant.oga" "$CS/.local/share/sounds/MeowSystem-Sons/stereo/notification/message-new-instant.oga" \
   && [ ! -e "$CS/systemctl.log" ]; then
  ok "o tema de som do Dracula (25 efeitos) entra com quem o toca nas notificações, cala no suppress-sound, e é trocado pelo do MeowSystem ao vestir o Catppuccin"
else
  falha "o tema de som do pack ou o tocador das notificações" "rc $r1/$r2/$r3/$r4 oga=$n_oga unidade=$unidade_ok
tocou: $tocou
systemctl: $(cat "$CS/systemctl.log" 2>/dev/null)"
fi

SIS="$T/aplicativos"; mkdir -p "$SIS"
for n in org.keepassxc.KeePassXC mpv vim; do
  printf '[Desktop Entry]\nName=%s\nExec=%s\n' "$n" "$n" > "$SIS/$n.desktop"
done
oculta() {
  amb PACK="$1" FLAVOR="" LANCADOR_OCULTAR="$2" MEOW_DRY_RUN=1 MEOW_APLICATIVOS_SISTEMA="$SIS" \
    bash "$RAIZ/scripts/ocultar_apps.sh" 2>&1 | sed -n 's/.*ocultaria //p' | sort | paste -sd' '
}
d1="$(oculta dracula 'vim,-mpv')"
c1="$(oculta catppuccin 'vim')"
if [ "$d1" = "org.keepassxc.KeePassXC vim" ] && [ "$c1" = "vim" ] && ! grep -q NoDisplay "$SIS"/*.desktop; then
  ok "o Dracula esconde o que o tema de antes escondia, somado ao conf; «-mpv» tira um; o Catppuccin não herda a lista"
else
  falha "a lista do lançador do pack não somou, não obedeceu ao «-nome», ou vazou para o Catppuccin" "dracula: $d1
catppuccin: $c1"
fi
printf '[Desktop Entry]\nNoDisplay=true\nName=mpv\nExec=mpv\n' > "$SIS/mpv.desktop"
oculta_de_vez() {
  amb PACK=dracula FLAVOR="" LANCADOR_OCULTAR="vim,-mpv" MEOW_APLICATIVOS_SISTEMA="$SIS" \
    bash "$RAIZ/scripts/ocultar_apps.sh" >/dev/null 2>&1
}
oculta_de_vez; r1=$?
oculta_de_vez; r2=$?
if [ "$r1" = 1 ] && [ "$r2" = 0 ] && ! grep -q '^NoDisplay=' "$SIS/mpv.desktop" \
   && grep -qx 'NoDisplay=true' "$SIS/vim.desktop"; then
  ok "o «-mpv» devolve ao lançador o mpv que já estava escondido, e a 2ª passada é 0"
else
  falha "o «-nome» não devolveu o que já estava escondido (rc $r1/$r2)" "$(cat "$SIS/mpv.desktop")"
fi

if command -v rsvg-convert >/dev/null 2>&1; then
  CW="$T/casa-papel"; mkdir -p "$CW/.config/meow"
  sed -e 's/^PACK=.*/PACK="dracula"/' -e 's/^FLAVOR=.*/FLAVOR="dracula"/' "$RAIZ/meow.conf.exemplo" > "$CW/.config/meow/meow.conf"
  : > "$T/fontes-vazio.tsv"
  papel() {
    env -i PATH="$FALSO:$PATH" HOME="$CW" LANG=C.UTF-8 NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
      MEOW_CONF="$CW/.config/meow/meow.conf" MEOW_ESTADO="$CW/estado" WALLPAPER_FONTES="$T/fontes-vazio.tsv" \
      bash -c 'set -a; . "$MEOW_CONF"; set +a; "$MEOW_RAIZ/scripts/wallpaper.sh" semear' 2>&1
  }
  s1="$(papel)"; s2="$(papel)"
  AT="$CW/.local/share/backgrounds/meowsystem/ativos"
  n_png="$(find "$AT" -name 'tulip-*.png' 2>/dev/null | wc -l)"
  n_4k="$(for f in "$AT"/tulip-*.png; do python3 -c 'import struct,sys;d=open(sys.argv[1],"rb").read(24);print(*struct.unpack(">II",d[16:24]))' "$f"; done 2>/dev/null | grep -c '^3840 2160$')"
  n_cat="$(find "$AT" -name 'cat-*' 2>/dev/null | wc -l)"
  esperado="$(find "$RAIZ/packs/dracula/wallpapers" -name '*.svg' | while read -r s; do r="${s#"$RAIZ"/packs/dracula/wallpapers/}"; n="tulip-${r//\//-}"; n="${n%.svg}.png"; grep -qxF "$n" "$RAIZ/packs/meowsystem/wallpapers/BANIDOS.txt.padrao" 2>/dev/null || echo "$n"; done | wc -l)"
  if [ "$n_png" -gt 0 ] && [ "$n_png" = "$esperado" ] && [ "$n_4k" = "$n_png" ] && [ "$n_cat" = 0 ] \
     && [[ "$s2" == *"já semeada"* ]]; then
    ok "numa casa nova, o Dracula semeia em PNG 4K os $n_png SVG do pack que não estão recusados, sem nada do Catppuccin, e a 2ª passada não faz nada"
  else
    falha "os papéis de parede do Dracula não vieram do pack em 4K" "png=$n_png esperado=$esperado 4k=$n_4k catppuccin=$n_cat
$s1
$s2"
  fi
else
  printf 'pulado: sem rsvg-convert, o SVG do pack não se rasteriza\n'
fi

TM="$T/mal"; HM="$TM/casa"; FM="$TM/falso"; PM="$TM/packs/mal"
mkdir -p "$TM/packs" "$FM" "$TM/alvo-fora/scalable/apps" "$TM/tar" \
         "$HM/.local/share/icons/MeowSystem-Icons/scalable/apps" "$HM/.config/meow"
cp -r "$RAIZ/packs/dracula" "$PM"; cp -r "$RAIZ/packs/meowsystem" "$TM/packs/malsrc"
SEGREDO='<svg xmlns="http://www.w3.org/2000/svg"><!-- SEGREDO --></svg>'
printf '%s\n' "$SEGREDO" > "$TM/segredo.svg"; cp "$TM/segredo.svg" "$TM/segredo.oga"
printf '[Icon Theme]\nName=Fora\nDirectories=scalable/apps\n[scalable/apps]\nSize=16\n' > "$TM/alvo-fora/index.theme"
ln -s "$TM/alvo-fora" "$TM/tar/tema"; tar -czf "$TM/base.tar.gz" -C "$TM/tar" tema
printf '#!/bin/sh\nwhile [ $# -gt 0 ]; do [ "$1" = "-o" ] && { cp "%s" "$2"; exit 0; }; shift; done; exit 1\n' \
  "$TM/base.tar.gz" > "$FM/curl"; chmod +x "$FM/curl"
G="$(grep -v '^#' "$RAIZ/packs/meowsystem/icones/mimetypes.map" | grep -v '^$' | head -1 | cut -d: -f2)"
D="$(sed -e 's/#.*//' "$PM/icones/apps.map" | awk -F: 'NF>=2 { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }')"
python3 - "$PM/pack.json" "$TM/packs/malsrc/pack.json" "$(sha256sum "$TM/base.tar.gz" | cut -d' ' -f1)" <<'PY'
import json, sys
a, b, sha = sys.argv[1:4]
p = json.load(open(a, encoding="utf-8")); p["id"] = "mal"
p["icones"]["base"]["origem"] = {"url": "https://exemplo.invalid/base.tar.gz", "sha256": sha, "pasta": "tema"}
p["icones"]["base"].pop("por_tras", None)
p["icones"]["mimetypes"] = {"desenhos": "icones/sistema/", "mapa": "icones/mimetypes.map"}
json.dump(p, open(a, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
q = json.load(open(b, encoding="utf-8")); q["id"] = "malsrc"
json.dump(q, open(b, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
f = a.replace("pack.json", "paleta.json")
d = json.load(open(f, encoding="utf-8"))
evil = '#000000"\n[custom.evil]\ncommand = "true"\nwhen = "true"\n#'
d["flavors"]["dracula"]["evil"] = evil.replace("\n", " ")
d["ordem_canonica"] = list(d.get("ordem_canonica") or []) + ["evil"]
json.dump(d, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
d["flavors"]["dracula"]["evil"] = evil
json.dump(d, open(f + ".nl", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
printf '../../../../../../escapou : %s\n' "$D" >> "$PM/icones/apps.map"
cp "$RAIZ/packs/meowsystem/icones/mimetypes.map" "$PM/icones/mimetypes.map"
printf '../../../../../../escapou2:%s\n' "$G" >> "$PM/icones/mimetypes.map"
ln -s "$TM/segredo.oga" "$PM/sons/stereo/notification/vazou.oga"
ln -s "$TM/segredo.svg" "$PM/wallpapers/catedral/vazou.svg"
cp "$RAIZ/packs/meowsystem/icones/sistema/"*.svg "$PM/icones/sistema/" 2>/dev/null
rm -f "$PM/icones/sistema/$G.svg"; ln -s "$TM/segredo.svg" "$PM/icones/sistema/$G.svg"
ln -s "$TM/segredo.svg" "$PM/icones/sistema/zz_vazou.svg"
printf '[Icon Theme]\nName=MeowSystem-Icons\nDirectories=scalable/apps\n' > "$HM/.local/share/icons/MeowSystem-Icons/index.theme"
sed -e 's/^PACK=.*/PACK="mal"/' -e 's/^FLAVOR=.*/FLAVOR="dracula"/' "$RAIZ/meow.conf.exemplo" > "$HM/.config/meow/meow.conf"
: > "$TM/fontes-vazio.tsv"
mal() {
  env -i PATH="$FM:$FALSO:$PATH" HOME="$HM" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
    MEOW_PACKS="$TM/packs" MEOW_ESTADO="$HM/estado" PACK=mal FLAVOR=dracula NOME_TEMA_ICONES=MeowSystem-Icons "$@"
}
if [ "$(amb env MEOW_PACKS="$TM/packs" python3 "$RAIZ/scripts/pack.py" validar mal >/dev/null 2>&1; echo $?)" = 0 ]; then
  mal ICONES_BASE= bash "$RAIZ/scripts/construir_icones.sh" base >"$TM/log-base.txt" 2>&1; rc_base=$?
  mal ICONES_DRACULA=sim bash "$RAIZ/scripts/icones_apps_dracula.sh" --aplicar >"$TM/log-apps.txt" 2>&1
  mal ICONES_FLAVOR=dracula ICONES_TEMA=MeowSystem-Icons bash "$RAIZ/scripts/icones_mimetypes.sh" >"$TM/log-mime.txt" 2>&1
  mal SOM=sim bash "$RAIZ/scripts/som.sh" aplicar >"$TM/log-som.txt" 2>&1
  mal MEOW_CONF="$HM/.config/meow/meow.conf" WALLPAPER_FONTES="$TM/fontes-vazio.tsv" \
    bash -c 'set -a; . "$MEOW_CONF"; set +a; PACK=mal; "$MEOW_RAIZ/scripts/wallpaper.sh" semear' >"$TM/log-papel.txt" 2>&1
  mal python3 "$RAIZ/scripts/pack.py" construir mal >"$TM/log-construir.txt" 2>&1
  mal PROMPT_ALVO="$TM/starship.toml" bash "$RAIZ/scripts/prompt.sh" aplicar >"$TM/log-prompt.txt" 2>&1
  injetado="$(grep -c '^\[custom' "$TM/starship.toml" 2>/dev/null)"
  escapou="$(find "$TM" -name 'escapou*' | wc -l)"
  no_alvo="$(find "$TM/alvo-fora" -name '.meow-*' | wc -l)"
  vazou="$(grep -rlF 'SEGREDO' "$HM" 2>/dev/null | wc -l)"
  intacto=0; [ "$(cat "$TM/segredo.svg")" = "$SEGREDO" ] && [ "$(cat "$TM/segredo.oga")" = "$SEGREDO" ] && intacto=1
  if [ "$rc_base" = 2 ] && [ "$no_alvo" = 0 ] && [ ! -L "$HM/.local/share/icons/MeowSystem-Icons-Base" ] \
     && [ "$escapou" = 0 ] && [ "$vazou" = 0 ] && [ "$intacto" = 1 ] \
     && [ -f "$TM/starship.toml" ] && [ "$injetado" = 0 ] \
     && [ -L "$PM/icones/sistema/$G.svg" ] \
     && grep -q 'linha(s) com nome fora' "$TM/log-apps.txt" && grep -q 'link ou saem' "$TM/log-som.txt" \
     && [ "$(find "$HM/.local/share/icons/MeowSystem-Icons/scalable/apps" -name '*.svg' | wc -l)" -gt 100 ]; then
    ok "segurança: o pack «mal» não lê nem escreve fora da raiz (base com pasta-link, ../ nos mapas, links no som, no papel, nos ícones de arquivo e no destino da derivação), nem injeta módulo no starship pela paleta"
  else
    falha "segurança: o pack «mal» alcançou fora da raiz" \
      "base rc=$rc_base escrito no alvo do link=$no_alvo escapou=$escapou segredo copiado=$vazou segredo intacto=$intacto starship injetado=${injetado:-sem arquivo}
$(cat "$TM"/log-base.txt "$TM"/log-apps.txt | tail -6)"
  fi
else
  falha "segurança: o pack «mal» de brinquedo não validou — o teste não exercitou nada" \
    "$(amb env MEOW_PACKS="$TM/packs" python3 "$RAIZ/scripts/pack.py" validar mal 2>&1 | tail -3)"
fi
cp -r "$PM" "$TM/packs/malnl"; mv "$TM/packs/malnl/paleta.json.nl" "$TM/packs/malnl/paleta.json"
rm -f "$PM/paleta.json.nl"
sed -i 's/"id": "mal"/"id": "malnl"/' "$TM/packs/malnl/pack.json"
saida="$(amb env MEOW_PACKS="$TM/packs" python3 "$RAIZ/scripts/pack.py" validar malnl 2>&1)"
if printf '%s' "$saida" | grep -q 'caractere de controle'; then
  ok "segurança: a paleta que abre linha nova (o [custom.evil] do starship) recusa o pack inteiro"
else
  falha "segurança: a paleta com quebra de linha num slot passou no validar" "$(printf '%s\n' "$saida" | tail -3)"
fi

grep -qx 'firefox:firefox:peach' "$RAIZ/packs/meowsystem/icones/apps-arcticons.map" \
  && ok "o traço do Firefox é peach" \
  || falha "o traço do Firefox não é peach" "$(grep '^firefox:' "$RAIZ/packs/meowsystem/icones/apps-arcticons.map")"
v="$(amb python3 "$RAIZ/scripts/pack.py" fonte dev.vencord.Vesktop 2>&1 | head -3)"
alvo_discord="$(sed -n 's/^com\.discordapp\.Discord[[:space:]]*:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$RAIZ/packs/dracula/icones/apps.map" | head -1)"
[ -n "$alvo_discord" ] && grep -qE "^dev\.vencord\.Vesktop[[:space:]]*:[[:space:]]*${alvo_discord//./\\.}([[:space:]]|$)" "$RAIZ/packs/dracula/icones/apps.map" \
  && ok "o Vesktop veste o Discord do pack Dracula" \
  || falha "o Vesktop não tem linha no mapa do pack Dracula" "$v"
pessoais="$(find "$RAIZ/packs" -iname '*hefesto*' -o -iname '*fogstripper*')"
[ -z "$pessoais" ] && ok "nenhum desenho de projeto pessoal (hefesto, fogstripper) nos packs" \
  || falha "os packs ainda trazem desenhos de projeto pessoal" "$pessoais"
CI="$T/casa-ci"; TEMA_CI="$CI/.local/share/icons/MeowSystem-Icons"
mkdir -p "$TEMA_CI/scalable/apps"
printf '[Icon Theme]\nName=MeowSystem-Icons\nDirectories=scalable/apps\n\n[scalable/apps]\nSize=48\nType=Scalable\n' \
  > "$TEMA_CI/index.theme"
printf '<svg xmlns="http://www.w3.org/2000/svg"><title>hefesto — Dracula</title></svg>\n' \
  > "$TEMA_CI/scalable/apps/hefesto-dualsense4unix.svg"
saida="$(env -i PATH="$FALSO:$PATH" HOME="$CI" MEOW_RAIZ="$RAIZ" NO_COLOR=1 MEOW_DRY_RUN=1 \
           PACK=dracula FLAVOR=dracula ACCENT=mauve ICONES_LOGO_HEFESTO="" \
           "$RAIZ/scripts/completar_icones.sh" 2>&1)"
if grep -q 'removeria hefesto-dualsense4unix.svg' <<< "$saida" \
   && ! grep -qE '(instalaria|mudaria) .*(hefesto|vitoriamaria|fogstripper)' <<< "$saida"; then
  ok "sem a logo apontada, o completar não desenha o Hefesto e arranca o desenho gerado antigo"
else
  falha "o completar ainda depende do desenho gerado do Hefesto" "$(grep -iE 'hefesto|fogstripper|vitoriamaria' <<< "$saida" | head -4)"
fi
saida="$(env -i PATH="$FALSO:$PATH" HOME="$CI" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
           PACK=dracula FLAVOR=dracula ACCENT=mauve ICONES_LOGO_HEFESTO="" \
           "$RAIZ/scripts/completar_icones.sh" 2>&1)"
if ! grep -qiE 'não chegaram ao tema:.*(hefesto|vitoriamaria)' <<< "$saida" && [ ! -e "$TEMA_CI/scalable/apps/hefesto-dualsense4unix.svg" ]; then
  ok "sem a logo apontada, o Hefesto fora do tema não é aviso, e o desenho gerado antigo saiu"
else
  falha "o completar avisa a falta do Hefesto, ou deixou o desenho gerado" "$(grep -iE 'chegaram|hefesto' <<< "$saida" | head -3)"
fi

APPS="$T/apps-sistema"; CO="$T/casa-ocultar"; mkdir -p "$APPS" "$CO"
nomes="$(python3 -c 'import json, sys; print("\n".join(json.load(open(sys.argv[1]))["lancador"]["ocultar"]))' \
           "$RAIZ/packs/dracula/pack.json")"
for n in $nomes vim; do
  printf '[Desktop Entry]\nName=%s\nExec=true\nType=Application\n' "$n" > "$APPS/$n.desktop"
done
ocultar() {
  env -i PATH="$FALSO:$PATH" HOME="$CO" MEOW_RAIZ="$RAIZ" NO_COLOR=1 MEOW_APLICATIVOS_SISTEMA="$APPS" \
    PACK="$1" FLAVOR="$2" LANCADOR_OCULTAR="vim" "$RAIZ/scripts/ocultar_apps.sh" 2>&1
}
marcados() { grep -l '^NoDisplay=true' "$APPS"/*.desktop 2>/dev/null | wc -l; }
ocultar dracula dracula > /dev/null; com_dracula="$(marcados)"
ocultar meowsystem mocha > /dev/null; com_catppuccin="$(marcados)"
antes="$(cat "$APPS"/*.desktop | sha256sum)"
saida="$(ocultar meowsystem mocha)"; rc=$?
depois="$(cat "$APPS"/*.desktop | sha256sum)"
if [ "$com_dracula" = 25 ] && [ "$com_catppuccin" = 1 ] && grep -q '^NoDisplay=true' "$APPS/vim.desktop" \
   && [ "$rc" = 0 ] && [ "$antes" = "$depois" ]; then
  ok "trocar do Dracula para o Catppuccin devolve os 24 que o pack escondia, e a 2ª passada não escreve"
else
  falha "a troca de pack não devolveu o que o pack escondia (Dracula: $com_dracula, Catppuccin: $com_catppuccin, 2ª rc=$rc)" "$saida"
fi

B="$T/icones12"; mkdir -p "$B/Tema" "$B/Tema-Base" "$B/Tema-Base-2"
printf '[Icon Theme]\nName=Tema\nInherits=Tema-Base,Tema-Base-2,hicolor\nDirectories=a\n' > "$B/Tema/index.theme"
printf '[Icon Theme]\nName=Dracula Circle\nInherits=Papirus-Dark,breeze-dark\nDirectories=a\n' > "$B/Tema-Base/index.theme"
printf '[Icon Theme]\nName=Dracula\nInherits=hicolor\nDirectories=a\n' > "$B/Tema-Base-2/index.theme"
lib12() { env -i PATH="$FALSO:$PATH" HOME="$T/casa12" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
            bash -c '. "$MEOW_RAIZ/lib/comum.sh"; . "$MEOW_RAIZ/lib/icones.sh"; . "$MEOW_RAIZ/lib/desinstalar.sh"; "$@"' _ "$@" 2>&1; }
lib12 meow_tema_exportado_heranca "$B" Tema > /dev/null
herda="$(sed -n 's/^Inherits=//p' "$B/Tema/index.theme")"
if [ "$herda" = "Tema-Base,Tema-Base-2,Cosmic,Adwaita,hicolor" ] \
   && grep -qx 'Hidden=true' "$B/Tema-Base/index.theme" && grep -qx 'Hidden=true' "$B/Tema-Base-2/index.theme" \
   && [ "$(sed -n 's/^Inherits=//p' "$B/Tema-Base/index.theme")" = "hicolor" ]; then
  ok "o tema exportado herda as bases, Cosmic, Adwaita e hicolor, e as bases vão escondidas"
else
  falha "a herança do tema exportado ou o Hidden das bases não saiu" "Inherits=$herda; $(grep -h Hidden "$B"/Tema-Base*/index.theme)"
fi
L="$T/base-local"; mkdir -p "$L"
printf '[Icon Theme]\nName=Dracula Circle\nDirectories=a\n' > "$L/index.theme"
( cd "$L" && sha256sum ./index.theme > .meow-somas.sha256 )
lib12 meow_tema_base_escondida "$L" > /dev/null; rc1=$?
antes="$(sha256sum < "$L/index.theme")"
lib12 meow_tema_base_escondida "$L" > /dev/null; rc2=$?
if grep -qx 'Hidden=true' "$L/index.theme" && ( cd "$L" && sha256sum --status -c .meow-somas.sha256 ) \
   && [ "$antes" = "$(sha256sum < "$L/index.theme")" ] && [ "$rc2" = 0 ]; then
  ok "a base local ganha o Hidden=true e o manifesto dela continua conferindo; a 2ª passada não escreve"
else
  falha "a base local não ficou escondida, ou o manifesto dela parou de conferir (rc=$rc1/$rc2)"
fi
IC="$T/casa12/.local/share/icons"; mkdir -p "$IC/MeowSystem-Icons-Base" "$IC/MeowSystem-Icons-Base-2" "$IC/MeowSystem-Icons-Base-3"
: > "$IC/MeowSystem-Icons-Base/.meow-origem"; : > "$IC/MeowSystem-Icons-Base-2/.meow-origem"
lib12 meow_desinstalar_bases_de_icones > /dev/null
if [ ! -e "$IC/MeowSystem-Icons-Base" ] && [ ! -e "$IC/MeowSystem-Icons-Base-2" ] && [ -d "$IC/MeowSystem-Icons-Base-3" ]; then
  ok "o desinstalador tira a -Base e a -Base-2 com a marca de dono, e deixa a que não é nossa"
else
  falha "o desinstalador não tirou as duas bases (ou tirou a que não é nossa)" "$(ls "$IC")"
fi

CD="$T/casa-dracula"; mkdir -p "$CD/.local/share/icons/MeowSystem-Icons/scalable/apps"
printf '[Icon Theme]\nName=MeowSystem-Icons\nDirectories=scalable/apps\n\n[scalable/apps]\nSize=48\nType=Scalable\n' \
  > "$CD/.local/share/icons/MeowSystem-Icons/index.theme"
saida="$(env -i PATH="$FALSO:$PATH" HOME="$CD" MEOW_RAIZ="$RAIZ" NO_COLOR=1 MEOW_DRY_RUN=1 \
           PACK=dracula FLAVOR=dracula "$RAIZ/scripts/icones_apps_dracula.sh" --aplicar 2>&1)"
if grep -q 'mudaria .*/scalable/apps/net\.waterfox\.waterfox\.svg' <<< "$saida"; then
  ok "sem a linha ICONES_DRACULA no conf, com o Dracula no ar, os desenhos do pack entram"
else
  falha "sem a linha ICONES_DRACULA, os desenhos do pack não entram" "$(tail -3 <<< "$saida")"
fi

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "o pack Dracula cumpre o que a P74 pediu"
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1

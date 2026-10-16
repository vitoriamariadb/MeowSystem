#!/usr/bin/env bash
# pack-dracula-completo.sh — o pack Dracula é um tema completo, montado certo e
# exportável (P74, 09/10/2026).
#
# O QUE ELE VIGIA
#   Cada bloco abaixo é um item da spec `docs/sprints/2026-10-09-uso-real/
#   P74-pack-dracula-completo.md`, e confere o contrato dele sem rede e sem
#   escrever fora de um temporário. As provas que pedem rede (baixar a base,
#   montar o tema inteiro) estão no relatório da spec, com o comando e a saída.
#
# NADA SAI DA CASA DE BRINQUEDO: `env -i` com HOME temporário, e um `sudo`
#   falso na frente do PATH — nenhuma linha daqui chama sudo, e o falso existe
#   para que nenhuma passe a chamar calada numa máquina com `NOPASSWD`.
#
#   0 = o pack Dracula cumpre o que a P74 pediu · 1 = achados · 2 = erro deste teste
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

# amb <comando...> — numa casa vazia, sem o ambiente de quem roda.
amb() {
  env -i PATH="$FALSO:$PATH" HOME="$T/casa" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" "$@"
}

# --- item 2: a base em duas camadas, as duas pinadas -------------------------
#   Decisão 1 de 09/10: `circle` por cima, `main` por trás, como o tema antigo.
#   O verbo diz a frente nas linhas de sempre e uma `atras=` por camada; o nome
#   da camada de trás, escolhido no conf, cede ao pack como o da frente; e o
#   `validar` recusa uma camada sem pino.
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

# --- item 4: o tema exportado tem o nome e o comentário do pack ---------------
#   O nome é do pack e do flavor (o flavor some quando é o próprio pack), e o
#   `Comment=` não diz Catppuccin com o Dracula. O índice instalado nesta
#   máquina passa a ter o mesmo comentário: quem o escreve pergunta ao mesmo
#   verbo. A montagem inteira (rede, base, etapas) fica no relatório da spec.
nomes="$(for par in "dracula" "dracula alucard" "catppuccin mocha"; do
  # shellcheck disable=SC2086
  amb python3 "$RAIZ/scripts/pack.py" tema-icones $par 2>&1 | sed -n 's/^nome=//p'
done | paste -sd' ')"
[ "$nomes" = "MeowSystem-Dracula-Icons MeowSystem-Dracula-Alucard-Icons MeowSystem-Catppuccin-Mocha-Icons" ] \
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

# --- item 5: o índice no fim, por uma etapa só --------------------------------
#   Numa casa de brinquedo com um tema já construído pela metade (o índice só
#   com `scalable/apps`) e diretórios que outras etapas criaram depois, o
#   `indice` declara todos, guarda a herança que a construção decidiu, e a
#   segunda chamada não escreve nada. E a etapa vem depois da última que
#   escreve no tema, no `install.sh` e no doctor.
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
  && ok "no install.sh a etapa do índice vem logo depois da dos gatos, a última que escreve no tema" \
  || falha "a etapa do índice não está depois da última que escreve no tema" "$ordem"
[[ "$(sed -n 's/^VERIFICAVEIS=(\(.*\))$/\1/p' "$RAIZ/bin/meow")" == *" logo indice" ]] \
  && ok "no doctor o índice é a última conferência" \
  || falha "o doctor não confere o índice depois de tudo"

# --- item 6: ícones de arquivo e pastas do próprio Dracula --------------------
#   Os 656 ícones de arquivo por flavor são do pack, derivados do
#   `css-variables` do Catppuccin pela paleta do Dracula: nenhum hex do
#   macchiato sobra, o `construir` no seco não tem nada a escrever (o versionado
#   é o que ele produz), e o `info` diz PRÓPRIO. E as pastas: o mapa do pack
#   veste as dez, e o `construir_pastas.sh` cede pelo MESMO mapa.
linha="$(amb python3 "$RAIZ/scripts/pack.py" info dracula 2>&1 | grep -E '^  icones\.mimetypes ')"
[[ "$linha" == *"PRÓPRIO"*"1.312 desenho(s)"* ]] \
  && ok "icones.mimetypes do Dracula é PRÓPRIO: 656 por flavor, nos dois flavors" \
  || falha "o info não diz os ícones de arquivo do Dracula como próprios" "$linha"
macc="$(python3 -c 'import json,sys;print("|".join(v.lower() for v in json.load(open(sys.argv[1]))["flavors"]["macchiato"].values()))' "$RAIZ/packs/catppuccin/paleta.json")"
com_macc="$(grep -liE "$macc" "$RAIZ"/packs/dracula/icones/mimetypes/*/*.svg | wc -l)"
total="$(find "$RAIZ/packs/dracula/icones/mimetypes" -name '*.svg' | wc -l)"
[ "$total" = 1312 ] && [ "$com_macc" = 0 ] \
  && ok "nenhum dos $total ícones de arquivo do Dracula tem cor do macchiato" \
  || falha "ícones de arquivo do Dracula com cor do Catppuccin, ou contagem errada" "total=$total com_macchiato=$com_macc"
seco="$(amb python3 "$RAIZ/scripts/pack.py" construir dracula --seco 2>&1 | grep 'ícones de arquivo')"
[[ "$seco" == *"escreveria 0, tirou 0"* ]] \
  && ok "o construir não tem ícone de arquivo a escrever: o versionado é o que a paleta dá" \
  || falha "os ícones de arquivo versionados não são os que a paleta do Dracula dá" "$seco"
mapa="$(amb python3 "$RAIZ/scripts/pack.py" acervo dracula icones.pastas.mapa 2>&1)"
nomes="$(grep -v '^#' "$mapa" 2>/dev/null | grep -c ':')"
faltam=""
while IFS=: read -r n g; do
  case "$n" in ''|'#'*) continue ;; esac
  [ -f "$RAIZ/packs/dracula/icones/pastas/$g.svg" ] || faltam="$faltam $g"
done < "$mapa"
[ "$nomes" = 10 ] && [ -z "$faltam" ] && grep -q 'acervo "$_pack_ref" icones.pastas.mapa' "$RAIZ/scripts/construir_pastas.sh" \
  && ok "o mapa de pastas do Dracula veste dez nomes (folder, user-home e user-desktop inclusive), e quem cede lê o mesmo mapa" \
  || falha "o mapa de pastas do Dracula não tem as dez, falta desenho, ou o construir_pastas não o lê" "nomes=$nomes faltam=$faltam"

# --- item 7: nada de Catppuccin com o Dracula no ar ---------------------------
#   O prompt: com o Dracula, a paleta do starship é a dele, nos 26 slots; com o
#   Catppuccin Mocha, o arquivo é o preset de antes. Um `starship` falso na
#   frente do PATH, porque o script só escreve com ele presente. E as quatro
#   rotas da página que caíam em `mocha` com o FLAVOR vazio.
printf '#!/bin/sh\nexit 0\n' > "$FALSO/starship"; chmod 755 "$FALSO/starship"
prompt() {   # $1 = PACK · $2 = FLAVOR · $3 = destino
  amb PACK="$1" FLAVOR="$2" MEOW_ESTADO="$T/estado" PROMPT_ALVO="$3" \
    bash "$RAIZ/scripts/prompt.sh" aplicar >/dev/null 2>&1
}
prompt dracula dracula "$T/st-dracula.toml"
prompt catppuccin mocha "$T/st-mocha.toml"
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

# --- item 8: o tema do Obsidian sobrevive ao git do cofre ---------------------
#   Um cofre de brinquedo versionado em git, com outro tema no commit (como o
#   cofre dela, com «Catppuccin» no HEAD). Depois do `aplicar`: o disco tem o
#   tema do pack no ar, o `git status` não vê o arquivo mudado, um checkout do
#   arquivo devolve o tema desta máquina (era aí que ele oscilava), um commit
#   não leva o tema para o cofre, e a segunda passada não tem o que fazer. O
#   `reverter` tira o filtro. O pack é o padrão (o tema dele mora no vendor/,
#   sem rede); o filtro não depende do pack. O flatpak e o pgrep são de
#   brinquedo, como no tests/temas-de-apps.sh.
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
  # Sem a configuração global de quem roda: um gancho de commit dela não tem
  # nada que fazer num cofre de brinquedo.
  g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$V" -c user.name=t -c user.email=t@t "$@"; }
  g init -q && g add .obsidian/appearance.json && g commit -qm inicial
  obs() {
    ( export HOME="$C" XDG_CONFIG_HOME="$C/.config" XDG_DATA_HOME="$C/.local/share" \
             MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$C/estado" NO_COLOR=1
      export PATH="$C/bin:$FALSO:$PATH" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
      unset MEOW_OBSIDIAN_VAULT PACK FLAVOR MEOW_PACK_DIR MEOW_PALETA
      . "$RAIZ/lib/comum.sh" || exit 2
      . "$RAIZ/assets/temas-de-apps/obsidian/manifesto.sh" || exit 2
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

# --- item 10 (I10): com MODO=claro, o traço e as pastas vestem o claro --------
#   O `meow_flavor_vestido` dá o flavor do lado que a tela veste: no claro, o
#   claro do pack; no escuro, o escuro, mesmo com um FLAVOR claro; no `auto`,
#   o FLAVOR. O traço do dock e as pastas perguntam a ele.
vestido() {   # $1 = PACK · $2 = FLAVOR · $3 = MODO
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
UPF="$RAIZ/assets/icones/upstream/papirus-folders"
if [ -d "$UPF/src" ] && [ -d /usr/share/icons/Papirus-Dark ]; then
  s="$(amb PACK=dracula FLAVOR=dracula ACCENT=mauve MODO=claro ICONES_PASTAS=cat-dracula-mauve \
        MEOW_DRY_RUN=1 MEOW_CAT_FOLDERS="$UPF" bash "$RAIZ/scripts/construir_pastas.sh" 2>&1)"
  [[ "$s" == *"'cat-alucard-mauve' não existe no papirus-folders — derivada de 'cat-latte-mauve'"* ]] \
    && ok "com MODO=claro as pastas que acompanham o tema saem na variante do Alucard (derivada do Latte)" \
    || falha "com MODO=claro as pastas não foram para o claro do pack" "$s"
fi

# --- item 9 (T3): o tema de som do Dracula, e quem o toca ---------------------
#   O `som.sh` instala os 25 efeitos do pack como tema de som e a unidade que
#   os toca nas notificações; a 2ª passada é 0; com o Catppuccin (sem tema de
#   som) os dois saem. E o `vigiar`, com um `dbus-monitor` de brinquedo: toca
#   o som de notificação do tema numa chamada `Notify`, e cala na que pede
#   `suppress-sound`. O `systemctl` não é chamado num HOME de teste.
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
som() {   # $1 = PACK · $2 = FLAVOR · $3 = verbo
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
som catppuccin mocha aplicar; r4=$?
if [ "$r1" = 1 ] && [ "$r2" = 0 ] && [ "$r3" = 0 ] && [ "$n_oga" = 25 ] && [ "$unidade_ok" = 1 ] \
   && [ "$(printf '%s\n' "$tocou" | grep -c .)" = 1 ] && [[ "$tocou" == *"/MeowSystem-Sons/stereo/notification/message-new-instant.oga" ]] \
   && [ "$r4" = 1 ] && [ ! -e "$CS/.local/share/sounds/MeowSystem-Sons" ] && [ ! -e "$CS/.config/systemd/user/meow-som.service" ] \
   && [ ! -e "$CS/systemctl.log" ]; then
  ok "o tema de som do Dracula (25 efeitos) entra com quem o toca nas notificações, cala no suppress-sound, e sai com o Catppuccin"
else
  falha "o tema de som do pack ou o tocador das notificações" "rc $r1/$r2/$r3/$r4 oga=$n_oga unidade=$unidade_ok
tocou: $tocou
systemctl: $(cat "$CS/systemctl.log" 2>/dev/null)"
fi

# --- item 9 (T5): os overrides de `.desktop` do Dracula moram no pack ---------
#   O pack esconde do lançador o que o tema Dracula de antes escondia, somado
#   à lista do conf; um `-nome` no conf tira um do pack; e com o Catppuccin no
#   ar a lista do Dracula não vale. No seco, numa pasta de sistema de brinquedo:
#   nada é escrito, e o que se lê é o «ocultaria».
SIS="$T/aplicativos"; mkdir -p "$SIS"
for n in org.keepassxc.KeePassXC mpv vim; do
  printf '[Desktop Entry]\nName=%s\nExec=%s\n' "$n" "$n" > "$SIS/$n.desktop"
done
oculta() {   # $1 = PACK · $2 = LANCADOR_OCULTAR
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
# O «-nome» DEVOLVE o que uma passada anterior já escondeu (conferência da P74):
#   o `mpv` marcado na forma que o script escreve volta ao lançador, o `vim`
#   continua escondido, e a segunda passada não tem nada a fazer. Na pasta de
#   sistema de brinquedo, que é gravável: nada passa por sudo.
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

# --- item 9 (T7): os papéis de parede do Dracula vêm do pack, em 4K -----------
#   Numa casa nova (o conf de fábrica, sem repositório de papel de parede), o
#   Dracula semeia os SVG do pack rasterizados em PNG 3840x2160, e não o acervo
#   do Catppuccin. A curadoria (que baixa da rede) fica de fora com uma receita
#   vazia; os recusados de fábrica (`BANIDOS.txt.padrao`) continuam recusados.
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
  esperado="$(find "$RAIZ/packs/dracula/wallpapers" -name '*.svg' | while read -r s; do r="${s#"$RAIZ"/packs/dracula/wallpapers/}"; n="tulip-${r//\//-}"; n="${n%.svg}.png"; grep -qxF "$n" "$RAIZ/assets/papeis-de-parede/BANIDOS.txt.padrao" 2>/dev/null || echo "$n"; done | wc -l)"
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

# --- segurança: o pack é dado não confiável (conferência da P74) -------------
#   Os alertas de 09/10/2026 (spec, seção «Segurança»): um pack pode ser
#   importado, e nada que vem dele pode ler ou escrever fora da raiz dele. Um
#   pack «mal», cópia do Dracula com o que um terceiro poria lá:
#     · a base pinada é um pacote cuja `pasta` é um LINK para fora (o `curl`
#       falso entrega o pacote local; o sha256 é o dele, como o pack pinou);
#     · uma linha do `apps.map` e uma do mapa de tipos de arquivo com `../`
#       no nome de destino;
#     · um som, um papel de parede e um ícone de arquivo que são links para um
#       «segredo» fora do pack;
#     · um ícone de arquivo derivado que é link no DESTINO (escrever nele seria
#       escrever no segredo), e um desenho-link na origem da derivação.
#   Nada sai da casa de brinquedo, o segredo fica intacto, e cada script segue
#   com o resto.
TM="$T/mal"; HM="$TM/casa"; FM="$TM/falso"; PM="$TM/packs/mal"
mkdir -p "$TM/packs" "$FM" "$TM/alvo-fora/scalable/apps" "$TM/tar" \
         "$HM/.local/share/icons/MeowSystem-Icons/scalable/apps" "$HM/.config/meow"
cp -r "$RAIZ/packs/dracula" "$PM"; cp -r "$RAIZ/packs/catppuccin" "$TM/packs/malsrc"
SEGREDO='<svg xmlns="http://www.w3.org/2000/svg"><!-- SEGREDO --></svg>'
printf '%s\n' "$SEGREDO" > "$TM/segredo.svg"; cp "$TM/segredo.svg" "$TM/segredo.oga"
printf '[Icon Theme]\nName=Fora\nDirectories=scalable/apps\n[scalable/apps]\nSize=16\n' > "$TM/alvo-fora/index.theme"
ln -s "$TM/alvo-fora" "$TM/tar/tema"; tar -czf "$TM/base.tar.gz" -C "$TM/tar" tema
printf '#!/bin/sh\nwhile [ $# -gt 0 ]; do [ "$1" = "-o" ] && { cp "%s" "$2"; exit 0; }; shift; done; exit 1\n' \
  "$TM/base.tar.gz" > "$FM/curl"; chmod +x "$FM/curl"
G="$(grep -v '^#' "$RAIZ/packs/catppuccin/icones/mimetypes.map" | grep -v '^$' | head -1 | cut -d: -f2)"
D="$(sed -e 's/#.*//' "$PM/icones/apps.map" | awk -F: 'NF>=2 { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }')"
python3 - "$PM/pack.json" "$TM/packs/malsrc/pack.json" "$(sha256sum "$TM/base.tar.gz" | cut -d' ' -f1)" <<'PY'
import json, sys
a, b, sha = sys.argv[1:4]
p = json.load(open(a, encoding="utf-8")); p["id"] = "mal"
p["icones"]["base"]["origem"] = {"url": "https://exemplo.invalid/base.tar.gz", "sha256": sha, "pasta": "tema"}
p["icones"]["base"].pop("por_tras", None)
p["icones"]["mimetypes"]["mapa"] = "icones/mimetypes.map"
p["icones"]["mimetypes"]["derivar"]["de"] = "malsrc"
json.dump(p, open(a, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
q = json.load(open(b, encoding="utf-8")); q["id"] = "malsrc"
json.dump(q, open(b, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
# Um slot a mais na paleta, que fecha a aspa e abre um módulo do starship que
# roda comando (o `validar` só confere o hex dos 26 slots).
#   [Conferência da P78: texto de pack com caractere de controle passou a ser
#   recusa do `validar` — o `\n` que abria o `[custom.evil]` fecha a porta
#   antes do prompt.sh. O «mal» leva a mesma injeção numa linha só (a aspa que
#   fecha continua sendo sonda do prompt.sh), e a de várias linhas vai para a
#   cópia `malnl`, que tem de ser recusada inteira.]
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
cp "$RAIZ/packs/catppuccin/icones/mimetypes.map" "$PM/icones/mimetypes.map"
printf '../../../../../../escapou2:%s\n' "$G" >> "$PM/icones/mimetypes.map"
ln -s "$TM/segredo.oga" "$PM/sons/stereo/notification/vazou.oga"
ln -s "$TM/segredo.svg" "$PM/wallpapers/catedral/vazou.svg"
rm -f "$PM/icones/mimetypes/dracula/$G.svg"; ln -s "$TM/segredo.svg" "$PM/icones/mimetypes/dracula/$G.svg"
ln -s "$TM/segredo.svg" "$TM/packs/malsrc/icones/mimetypes/css-variables/zz_vazou.svg"
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
  vazou="$(grep -rlF 'SEGREDO' "$HM" "$PM/icones/mimetypes" 2>/dev/null | wc -l)"
  intacto=0; [ "$(cat "$TM/segredo.svg")" = "$SEGREDO" ] && [ "$(cat "$TM/segredo.oga")" = "$SEGREDO" ] && intacto=1
  if [ "$rc_base" = 2 ] && [ "$no_alvo" = 0 ] && [ ! -L "$HM/.local/share/icons/MeowSystem-Icons-Base" ] \
     && [ "$escapou" = 0 ] && [ "$vazou" = 0 ] && [ "$intacto" = 1 ] \
     && [ -f "$TM/starship.toml" ] && [ "$injetado" = 0 ] \
     && [ ! -L "$PM/icones/mimetypes/dracula/$G.svg" ] \
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
# A injeção de várias linhas pela paleta: recusada na porta, o pack inteiro.
cp -r "$PM" "$TM/packs/malnl"; mv "$TM/packs/malnl/paleta.json.nl" "$TM/packs/malnl/paleta.json"
rm -f "$PM/paleta.json.nl"
sed -i 's/"id": "mal"/"id": "malnl"/' "$TM/packs/malnl/pack.json"
saida="$(amb env MEOW_PACKS="$TM/packs" python3 "$RAIZ/scripts/pack.py" validar malnl 2>&1)"
if printf '%s' "$saida" | grep -q 'caractere de controle'; then
  ok "segurança: a paleta que abre linha nova (o [custom.evil] do starship) recusa o pack inteiro"
else
  falha "segurança: a paleta com quebra de linha num slot passou no validar" "$(printf '%s\n' "$saida" | tail -3)"
fi

# --- P82, item 9 (decisões 16, 18 e 19): Firefox, Vesktop e os projetos pessoais
#   O traço do Firefox estava em `blue`, que é do Chrome (o próprio
#   `apps-marca.map` mede); o Vesktop não tinha linha no mapa do pack; e os
#   autorais `hefesto-*` e `fogstripper-*` (projetos pessoais) moravam nos dois
#   packs, contra a regra de 23/09.
grep -qx 'firefox:firefox:peach' "$RAIZ/packs/meowsystem/icones/apps-arcticons.map" \
  && ok "o traço do Firefox é peach" \
  || falha "o traço do Firefox não é peach" "$(grep '^firefox:' "$RAIZ/packs/meowsystem/icones/apps-arcticons.map")"
v="$(amb python3 "$RAIZ/scripts/pack.py" fonte dev.vencord.Vesktop 2>&1 | head -3)"
grep -qE '^dev\.vencord\.Vesktop[[:space:]]*:[[:space:]]*apps/com\.discordapp\.Discord\.svg' "$RAIZ/packs/dracula/icones/apps.map" \
  && ok "o Vesktop veste o Discord do pack Dracula" \
  || falha "o Vesktop não tem linha no mapa do pack Dracula" "$v"
pessoais="$(find "$RAIZ/packs" -iname '*hefesto*' -o -iname '*fogstripper*')"
[ -z "$pessoais" ] && ok "nenhum desenho de projeto pessoal (hefesto, fogstripper) nos packs" \
  || falha "os packs ainda trazem desenhos de projeto pessoal" "$pessoais"
# Sem a logo apontada (ICONES_LOGO_HEFESTO vazia, a de fábrica), o completar
# não põe desenho nenhum para o Hefesto, e arranca o desenho gerado que uma
# passagem antiga deixou no tema (o `<title>hefesto — ` é a marca de dono).
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
# E na passada de verdade (casa de brinquedo), a falta do Hefesto não vira aviso.
saida="$(env -i PATH="$FALSO:$PATH" HOME="$CI" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
           PACK=dracula FLAVOR=dracula ACCENT=mauve ICONES_LOGO_HEFESTO="" \
           "$RAIZ/scripts/completar_icones.sh" 2>&1)"
if ! grep -qiE 'não chegaram ao tema:.*(hefesto|vitoriamaria)' <<< "$saida" && [ ! -e "$TEMA_CI/scalable/apps/hefesto-dualsense4unix.svg" ]; then
  ok "sem a logo apontada, o Hefesto fora do tema não é aviso, e o desenho gerado antigo saiu"
else
  falha "o completar avisa a falta do Hefesto, ou deixou o desenho gerado" "$(grep -iE 'chegaram|hefesto' <<< "$saida" | head -3)"
fi

# --- P82, item 10 (decisão 22): a camada de apps do Catppuccin só roda com ele
#   Com o Dracula no ar, o `icones_apps.sh` mandava o flavor `dracula` para o
#   `macchiato` e dizia «o acervo Catppuccin de aplicativos não está em …».
CA="$T/casa-apps"; mkdir -p "$CA"
saida="$(env -i PATH="$FALSO:$PATH" HOME="$CA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
           PACK=dracula FLAVOR=dracula ICONES_FLAVOR=dracula "$RAIZ/scripts/icones_apps.sh" 2>&1)"; rc=$?
if [ -z "$saida" ] && [ "$rc" != 1 ] && [ "$rc" != 2 ] && [ -z "$(find "$CA" -type f)" ]; then
  ok "com o Dracula no ar, a camada de apps do Catppuccin não diz nada e não escreve (rc=$rc)"
else
  falha "com o Dracula no ar, a camada de apps do Catppuccin falou ou escreveu (rc=$rc)" "$saida"
fi
saida="$(env -i PATH="$FALSO:$PATH" HOME="$CA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
           PACK=catppuccin FLAVOR=mocha ICONES_FLAVOR=mocha "$RAIZ/scripts/icones_apps.sh" 2>&1)"
[ -n "$saida" ] && ok "com o Catppuccin, a camada segue o caminho de sempre" \
  || falha "com o Catppuccin, a camada de apps não respondeu"

# --- P82, item 11 (decisões 17 e 21): trocar de pack devolve o que o pack escondia
#   O `ocultar_apps.sh` só desfazia uma marca pelo `-nome`: trocar do Dracula
#   para o Catppuccin deixava os 24 do `lancador.ocultar` do pack fora do
#   lançador. Um /usr/share/applications falso, com os 24 e o `vim`; o conf
#   esconde só o `vim`, para a lista de fábrica não se misturar à do pack.
APPS="$T/apps-sistema"; CO="$T/casa-ocultar"; mkdir -p "$APPS" "$CO"
nomes="$(python3 -c 'import json, sys; print("\n".join(json.load(open(sys.argv[1]))["lancador"]["ocultar"]))' \
           "$RAIZ/packs/dracula/pack.json")"
for n in $nomes vim; do
  printf '[Desktop Entry]\nName=%s\nExec=true\nType=Application\n' "$n" > "$APPS/$n.desktop"
done
ocultar() {   # $1 = pack · $2 = flavor
  env -i PATH="$FALSO:$PATH" HOME="$CO" MEOW_RAIZ="$RAIZ" NO_COLOR=1 MEOW_APLICATIVOS_SISTEMA="$APPS" \
    PACK="$1" FLAVOR="$2" LANCADOR_OCULTAR="vim" "$RAIZ/scripts/ocultar_apps.sh" 2>&1
}
marcados() { grep -l '^NoDisplay=true' "$APPS"/*.desktop 2>/dev/null | wc -l; }
ocultar dracula dracula > /dev/null; com_dracula="$(marcados)"
ocultar catppuccin mocha > /dev/null; com_catppuccin="$(marcados)"
antes="$(cat "$APPS"/*.desktop | sha256sum)"
saida="$(ocultar catppuccin mocha)"; rc=$?
depois="$(cat "$APPS"/*.desktop | sha256sum)"
if [ "$com_dracula" = 25 ] && [ "$com_catppuccin" = 1 ] && grep -q '^NoDisplay=true' "$APPS/vim.desktop" \
   && [ "$rc" = 0 ] && [ "$antes" = "$depois" ]; then
  ok "trocar do Dracula para o Catppuccin devolve os 24 que o pack escondia, e a 2ª passada não escreve"
else
  falha "a troca de pack não devolveu o que o pack escondia (Dracula: $com_dracula, Catppuccin: $com_catppuccin, 2ª rc=$rc)" "$saida"
fi

# --- P82, item 12 (decisão 20): as bases escondidas, a herança do exportado e o desinstalar
#   Nenhum `Hidden=` nas bases, que apareciam nos seletores como «Dracula
#   Circle» e «Dracula»; o exportado herdava só as bases e o `hicolor` (os
#   `preferences-*` do COSMIC ficavam sem desenho); e o desinstalador tirava a
#   `-Base` e esquecia a `-Base-2`.
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

# --- P82, item 13: o ICONES_DRACULA ausente vale como ligado ----------------------
#   O `10a139f` (o `_dracula_no_ar` do icones_apps_dracula.sh) foi provado só por
#   rodada: todo teste escrevia `ICONES_DRACULA="sim"`. Aqui o conf não tem a
#   linha, o Dracula está no ar, e os desenhos do pack entram (no ensaio). O
#   script de antes do `10a139f` punha 0 desenhos do pack.
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

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
    ( export HOME="$C" XDG_CONFIG_HOME="$C/.config" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$C/estado" NO_COLOR=1
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

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "o pack Dracula cumpre o que a P74 pediu"
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1

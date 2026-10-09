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

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "o pack Dracula cumpre o que a P74 pediu"
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1

#!/usr/bin/env bash
# instalar_fontes.sh — a fonte do terminal e do codigo, baixada da release
# oficial do Nerd Fonts em VERSAO PINADA, instalada so no diretorio do usuario.
#
#   ./instalar_fontes.sh            instala e aplica
#   ./instalar_fontes.sh --conferir so diz se esta divergente (nao escreve)
#   MEOW_DRY_RUN=1 ./instalar_fontes.sh   mostra o que faria
#
# ---------------------------------------------------------------------------
# POR QUE "JetBrainsMono Nerd Font MONO" E NAO "JetBrainsMono Nerd Font"
#
#   O tarball traz a MESMA fonte em tres larguras de icone: `NerdFont` (icones de
#   duas celulas), `NerdFontMono` (icones espremidos em uma celula) e
#   `NerdFontPropo` (proporcional). O nome parece detalhe e nao e — MEDIDO nos
#   proprios TTF em 2026-08-04, lendo a tabela `post`:
#
#     JetBrainsMonoNerdFontMono-Regular.ttf : post.isFixedPitch = 1
#     JetBrainsMonoNerdFont-Regular.ttf     : post.isFixedPitch = 0
#
#   O `fontdb` (que o cosmic-text usa por baixo do cosmic-term e do libcosmic)
#   marca a face como monoespacada a partir desse bit. Com ele em 0, a variante
#   comum NAO aparece na lista de fontes monoespacadas do cosmic-settings nem do
#   cosmic-term — a fonte fica instalada e invisivel, e o sintoma e "baixei e nao
#   apareceu na lista".
#
#   Repare que o `fc-scan` diz `spacing=100` (monoespacada) para AS DUAS: o
#   fontconfig deduz isso do PANOSE, nao do `post`. Ou seja, conferir por
#   `fc-list` daria "as duas servem" e esconderia o problema. Foi por isso que a
#   escolha aqui saiu da tabela do arquivo, e nao do fontconfig.
#
#   A segunda razao para a variante Mono: o cosmic-term monta a grade de celulas
#   pelo avanco da fonte primaria. Icone de duas celulas numa grade de uma vira
#   glifo cortado e coluna torta.
#
# O NOME DA FAMILIA TAMBEM E UMA ARMADILHA
#
#   A tabela `name` do arquivo tem DOIS nomes de familia:
#
#     nameID  1 (Family)             = "JetBrainsMono NFM"
#     nameID 16 (Typographic Family) = "JetBrainsMono Nerd Font Mono"
#
#   O `fontdb` prefere o 16 e so cai no 1 quando o 16 nao existe; o fontconfig
#   publica os dois. Como quem le a configuracao do COSMIC e o fontdb, o valor
#   que vai para os arquivos e o LONGO. Escrever "JetBrainsMono NFM" resolveria
#   no `fc-match` e falharia calado no cosmic-term.
#
# POR QUE AS 16 FACES, E NAO SO A Regular
#
#   O cosmic-term tem tres pesos configuraveis ao mesmo tempo (`font_weight`,
#   `bold_font_weight` e `dim_font_weight`, este ultimo Light de fabrica). Sem a
#   face real, o renderizador SINTETIZA o peso — engorda o desenho por
#   algoritmo — e o resultado e visivelmente pior numa TV de 52 polegadas. As 16
#   faces (8 pesos x reto/italico) custam 39 MB e acabam com isso.
#
# INTEGRIDADE: PINAMOS A VERSAO **E** O CONTEUDO
#
#   `v3.5.0` diz de onde veio; os SHA-256 dizem que e aquilo mesmo. Os dois
#   juntos fazem a idempotencia ser por CONTEUDO e nao por marcador: a conferencia
#   de "ja esta instalado" e o sha256 de cada arquivo no destino, o que tambem
#   pega arquivo corrompido pela metade — coisa que um carimbo de versao jura que
#   esta certa. (A lista de somas e a oficial do proprio release, SHA-256.txt.)
#
# ONDE ESCREVE, E ONDE NUNCA ESCREVE
#
#   Fontes:  ~/.local/share/fonts/MeowSystem/   (nunca /usr/share — e do apt e do
#            Ritual da Aurora, e um `apt` apaga o que largarmos la)
#   Config:  ~/.config/cosmic/com.system76.CosmicTk/v1/monospace_font
#            ~/.config/cosmic/com.system76.CosmicTerm/v1/font_name
#
#   NAO tocamos, no CosmicTerm: font_size, opacity, use_bright_bold,
#   shortcuts_custom, focus_follow_mouse, tab_new_inherit_working_directory,
#   font_size_zoom_step_mul_100. Sao dela, e parte e do Aurora.
#
#   NAO tocamos no `interface_font`: ela usa "Fira Sans", que ja vem do pacote
#   `pop-fonts`. A etapa 2 daqui so CONFERE que existe e diz o que achou.
#
# NAO MATAMOS NADA PARA "RECARREGAR"
#
#   O construir_icones.sh derruba o cosmic-panel de proposito. Aqui seria
#   desastre: `pkill cosmic-term` fecha os terminais ABERTOS dela, com o que
#   estiver rodando dentro. O cosmic-term observa a propria configuracao (cosmic-
#   config) e pega a fonte nova sozinho; o que nao pegar, pega na proxima aba.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

[ "${1:-}" = "--conferir" ] && MEOW_SECO=1

# --- o upstream, pinado -----------------------------------------------------
# Origem: https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.0
# Release estavel (prerelease=false), publicada em 2026-08-02T23:35:36Z.
# Baixamos SO o tarball da JetBrainsMono (6,4 MB). O repositorio inteiro passa de
# 5 GB e nao ha razao nenhuma para cloná-lo.
NERD_TAG="v3.5.0"
NERD_ATIVO="JetBrainsMono.tar.xz"
NERD_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_TAG/$NERD_ATIVO"
# Do SHA-256.txt oficial da mesma release.
NERD_TAR_SHA256="0227b220360a6f819b9ead92343e8112b34733054782561af50cfba1e8afab63"
NERD_TAR_BYTES=6371912

VARIANTE="JetBrainsMonoNerdFontMono"
FAMILIA_MONO="JetBrainsMono Nerd Font Mono"
FAMILIA_UI="Fira Sans"

# sha256 de cada face, calculado do tarball verificado acima.
SOMAS=(
"065befdc92f7ceb456ea76c76d95af5ef8e4bfd6beffa379bed11c41c4c74c2f  JetBrainsMonoNerdFontMono-Bold.ttf"
"9764226f879560f8abc825e0b85d607e44da5093faf2029ff9b8cee6a081dbb6  JetBrainsMonoNerdFontMono-BoldItalic.ttf"
"b6b7f94cd56e8fb3a92b78df2932280d9f60521fca484b232ac66c4b49a4ff14  JetBrainsMonoNerdFontMono-ExtraBold.ttf"
"66b0494852c588848dc32e3dd28fb5f3f6e867e6cc773beb18ffb1d217ea96c5  JetBrainsMonoNerdFontMono-ExtraBoldItalic.ttf"
"fc6dd72b4c8652e8b9e7276142550c41ad11ddce2b00b0b32500469ecc89d725  JetBrainsMonoNerdFontMono-ExtraLight.ttf"
"f812332145b1d822681fcdf982cefcfba189543b8f503b5fca6108a04d78b525  JetBrainsMonoNerdFontMono-ExtraLightItalic.ttf"
"8588a1ac8f29c2e2607a58886d473d99af7974a3866bfcdb2c710b457e804113  JetBrainsMonoNerdFontMono-Light.ttf"
"3c80e1a76fb2db3ac2907890ae72b3ee956adefaab4ea30077798418893e7065  JetBrainsMonoNerdFontMono-LightItalic.ttf"
"46cada139aa74b987af467221123db6b91858f23c32b6c728ccfce826d519e74  JetBrainsMonoNerdFontMono-Medium.ttf"
"09245248fe5c7edc7d012b001da93664e5cf36ea69352b786d0715b27cbd5252  JetBrainsMonoNerdFontMono-MediumItalic.ttf"
"474634cb9b0697a3a10b3da589e896794e1128b0c7c9b49678ec2e03194ce45a  JetBrainsMonoNerdFontMono-Regular.ttf"
"79c5d4cb24560c5920fcdf1f2f0eca4d7b549df9e9def70959b57e54b1f0216a  JetBrainsMonoNerdFontMono-Italic.ttf"
"da0f5f8adfa4e8357441d5d01df0de0a9df69512fc25708ee0e3d38d11cd9f9d  JetBrainsMonoNerdFontMono-SemiBold.ttf"
"c1a72010e7c5d917d8d4c0ad793d59aedf044942bf05e701b16ba28191b20b14  JetBrainsMonoNerdFontMono-SemiBoldItalic.ttf"
"18f66e4a3105f31b9f1132e4ff0b879bae3faa0545c42108f7812b948f4ce2d9  JetBrainsMonoNerdFontMono-Thin.ttf"
"2d0ebea8655d90546434441d09ed98843d98296aff76dcadb8936b7abc318e2c  JetBrainsMonoNerdFontMono-ThinItalic.ttf"
)

# O cache do tarball fica no repo e esta no .gitignore: e a mesma regra do
# baixar_upstream.sh — o git guarda a RECEITA, nao os megabytes.
CACHE="$RAIZ/src/fonts/upstream"
TAR="$CACHE/$NERD_ATIVO"

FONTES_BASE="$HOME/.local/share/fonts"
DESTINO="$FONTES_BASE/MeowSystem"

TK="$HOME/.config/cosmic/com.system76.CosmicTk/v1"
TERM_DIR="$HOME/.config/cosmic/com.system76.CosmicTerm/v1"

mudou=0

# --- dependencias -----------------------------------------------------------
faltam=()
for c in curl tar sha256sum fc-cache fc-list fc-match; do
  meow_tem "$c" || faltam+=("$c")
done
# O tarball e .xz: sem o descompressor, o `tar` falha no meio e deixa lixo.
meow_tem xz || meow_tem unxz || faltam+=("xz-utils")
if [ ${#faltam[@]} -gt 0 ]; then
  meow_erro "faltam ferramentas: ${faltam[*]}"
  meow_info "  sudo apt-get install curl tar coreutils fontconfig xz-utils"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

meow_destino_permitido "$DESTINO" || exit "$MEOW_ERRO"

# ---------------------------------------------------------------------------
# 1. A FONTE DA INTERFACE — conferir, nunca reinstalar
#
# "Fira Sans" ja vem do pacote `pop-fonts` do Pop!_OS, em
# /usr/share/fonts/opentype/fira. Baixar uma copia para o diretorio do usuario
# criaria DUAS familias com o mesmo nome e caminhos diferentes: o fontconfig
# escolhe uma, o fontdb escolhe outra, e a interface fica sutilmente diferente
# do resto do sistema sem ninguem entender por que.
meow_passo "Fonte da interface"
ui_arquivo="$(fc-list -f '%{file}\t%{family}\n' 2>/dev/null \
              | grep -F "	$FAMILIA_UI" | cut -f1 | sort | head -1)"
if [ -n "$ui_arquivo" ]; then
  meow_ok "'$FAMILIA_UI' ja instalada — $(dirname "$ui_arquivo")"
  meow_pula "nada a baixar (vem do pacote do sistema)"
else
  # Nao e erro nosso e nao ha o que consertar aqui: a fonte de interface e do
  # sistema. Dizemos o comando e seguimos — a monoespacada nao depende dela.
  meow_aviso "'$FAMILIA_UI' NAO esta instalada"
  meow_info "  sudo apt-get install pop-fonts    # ou fonts-firacode/fonts-fira"
fi

# ---------------------------------------------------------------------------
# 2. A NERD FONT
meow_passo "Fonte monoespacada — $FAMILIA_MONO ($NERD_TAG)"

# Uma copia da MESMA familia fora do nosso diretorio (um pacote do apt, um dia)
# duplicaria as faces. Nesse caso a nossa e a sobrando: nao instalamos.
externo="$(fc-list -f '%{file}\t%{family}\n' 2>/dev/null \
           | grep -F "	$FAMILIA_MONO" | cut -f1 | grep -v "^$DESTINO/" | head -1)"

instalados_ok() {
  [ -d "$DESTINO" ] || return 1
  ( cd "$DESTINO" && printf '%s\n' "${SOMAS[@]}" | sha256sum --status -c - ) 2>/dev/null
}

if [ -n "$externo" ]; then
  meow_ok "'$FAMILIA_MONO' ja vem de fora ($externo) — nao duplico"
elif instalados_ok; then
  meow_ok "as ${#SOMAS[@]} faces ja estao em $DESTINO e conferem no sha256"
elif meow_seco; then
  meow_muda "baixaria $NERD_ATIVO ($NERD_TAG) e instalaria ${#SOMAS[@]} faces em $DESTINO"
  mudou=1
else
  # --- 2a. o tarball, no cache do repo -------------------------------------
  if [ -f "$TAR" ] && echo "$NERD_TAR_SHA256  $TAR" | sha256sum --status -c - 2>/dev/null; then
    meow_ok "$NERD_ATIVO ja no cache e confere ($NERD_TAG)"
  else
    [ -f "$TAR" ] && meow_aviso "o $NERD_ATIVO do cache nao confere no sha256 — baixando de novo"
    mkdir -p "$CACHE" || { meow_erro "nao consegui criar $CACHE"; exit "$MEOW_ERRO"; }
    meow_info "baixando $NERD_URL"
    # Temporario DENTRO do cache: o mv final e no mesmo sistema de arquivos, e
    # um Ctrl-C no meio nunca deixa um .tar.xz pela metade com o nome definitivo.
    tmp_tar="$(mktemp -p "$CACHE" ".baixando.XXXXXX")" || exit "$MEOW_ERRO"
    if ! curl -fL --retry 3 --retry-delay 2 -o "$tmp_tar" "$NERD_URL"; then
      rm -f "$tmp_tar"
      meow_erro "falhou o download de $NERD_URL"
      exit "$MEOW_ERRO"
    fi
    if ! echo "$NERD_TAR_SHA256  $tmp_tar" | sha256sum --status -c - 2>/dev/null; then
      meow_erro "sha256 do $NERD_ATIVO nao bate com o pinado ($NERD_TAG)"
      meow_info "  esperado $NERD_TAR_SHA256"
      meow_info "  obtido   $(sha256sum "$tmp_tar" | cut -d' ' -f1)"
      rm -f "$tmp_tar"
      exit "$MEOW_ERRO"
    fi
    chmod 644 "$tmp_tar"
    mv -f "$tmp_tar" "$TAR" || { rm -f "$tmp_tar"; exit "$MEOW_ERRO"; }
    meow_ok "$NERD_ATIVO baixado e verificado ($(stat -c%s "$TAR") bytes)"
  fi

  # --- 2b. extrair e instalar ----------------------------------------------
  # O repo mora em /mnt/Apate e o destino em /home: `mv` entre eles NAO e
  # atomico. Entao a area de montagem nasce dentro de ~/.local/share/fonts, e
  # so depois os arquivos entram no lugar por `mv` dentro do mesmo disco.
  #
  # O ponto no comeco do nome nao e enfeite: o fontconfig ignora arquivo e
  # diretorio comecados por '.', entao um scan que caia no meio da extracao nao
  # ve fonte pela metade.
  mkdir -p "$DESTINO" || { meow_erro "nao consegui criar $DESTINO"; exit "$MEOW_ERRO"; }
  stage="$(mktemp -d -p "$FONTES_BASE" ".meow-fontes.XXXXXX")" || exit "$MEOW_ERRO"
  # shellcheck disable=SC2064
  trap "rm -rf '$stage'" EXIT

  if ! tar -xJf "$TAR" -C "$stage" --wildcards "${VARIANTE}-*.ttf" 2>/dev/null; then
    meow_erro "falhou ao extrair ${VARIANTE}-*.ttf de $TAR"
    exit "$MEOW_ERRO"
  fi

  if ! ( cd "$stage" && printf '%s\n' "${SOMAS[@]}" | sha256sum --status -c - ) 2>/dev/null; then
    meow_erro "o conteudo extraido nao confere com os sha256 pinados"
    exit "$MEOW_ERRO"
  fi

  novos=0
  while read -r _soma nome; do
    if [ -f "$DESTINO/$nome" ] && cmp -s "$stage/$nome" "$DESTINO/$nome"; then
      continue
    fi
    chmod 644 "$stage/$nome"
    mv -f "$stage/$nome" "$DESTINO/$nome" || { meow_erro "falhou instalar $nome"; exit "$MEOW_ERRO"; }
    novos=$((novos+1))
  done < <(printf '%s\n' "${SOMAS[@]}")

  rm -rf "$stage"; trap - EXIT
  meow_ok "instaladas $novos de ${#SOMAS[@]} faces em $DESTINO"
  mudou=1

  # --- 2c. avisar o fontconfig ---------------------------------------------
  # So aqui, e so quando algo mudou: o `fc-cache -f` reconstroi todo o cache do
  # usuario e leva segundos. Rodar em toda execucao transformaria um script
  # idempotente numa espera diaria sem motivo.
  if ! fc-cache -f >/dev/null 2>&1; then
    meow_aviso "o fc-cache reclamou — as fontes estao no lugar, mas confira 'fc-list'"
  fi
fi

# ---------------------------------------------------------------------------
# 3. APONTAR O COSMIC PARA ELA
meow_passo "Configuracao do COSMIC"

# O `monospace_font` do CosmicTk e um struct RON, nao uma string:
#
#   (
#       family: "Noto Sans Mono",
#       weight: Normal,
#       stretch: Normal,
#       style: Normal,
#   )
#
# ...com quatro espacos de indentacao e SEM quebra de linha no fim. Trocamos a
# linha do `family:` e deixamos weight/stretch/style como estao, em vez de
# reescrever o arquivo com um modelo nosso: se ela um dia escolher "Light" na
# GUI, este script nao desfaz a escolha na proxima execucao.
ron_com_familia() {
  local familia="$1" atual="$2"
  if printf '%s' "$atual" | grep -qE '^[[:space:]]*family:'; then
    printf '%s' "$atual" | sed -E "s|^([[:space:]]*family:[[:space:]]*).*\$|\\1\"$familia\",|"
  else
    printf '(\n    family: "%s",\n    weight: Normal,\n    stretch: Normal,\n    style: Normal,\n)' "$familia"
  fi
}

atual_mono=""
[ -f "$TK/monospace_font" ] && atual_mono="$(cat "$TK/monospace_font")"
meow_escrever "$TK/monospace_font" "$(ron_com_familia "$FAMILIA_MONO" "$atual_mono")" 644
case $? in
  0) meow_ok "monospace_font ja aponta para '$FAMILIA_MONO'" ;;
  1) meow_muda "monospace_font -> '$FAMILIA_MONO'"; mudou=1 ;;
  *) meow_erro "nao consegui escrever $TK/monospace_font"; exit "$MEOW_ERRO" ;;
esac

# O cosmic-term guarda a fonte numa chave PROPRIA, separada do CosmicTk.
#
# A chave nao existe no disco dela — e existe no programa: o `Config` do
# cosmic-term 1.5.0 traz `font_name`, `font_size`, `font_weight`, `font_stretch`,
# `dim_font_weight` e `bold_font_weight` (lidos dos nomes de campo serializados
# dentro do binario, 2026-08-04). O cosmic-config so grava a chave quando o valor
# muda; por isso o diretorio dela so tem o que ela mexeu algum dia.
#
# `font_name` e uma String pura: o RON e a familia entre aspas, sem quebra de
# linha no fim — o mesmo formato do `icon_theme` do CosmicTk.
#
# Se o diretorio nao existir, o cosmic-term nunca rodou nesta maquina: criar a
# arvore inteira aqui inventaria configuracao para um app ausente.
if [ -d "$TERM_DIR" ]; then
  meow_escrever "$TERM_DIR/font_name" "\"$FAMILIA_MONO\"" 644
  case $? in
    0) meow_ok "CosmicTerm/font_name ja aponta para '$FAMILIA_MONO'" ;;
    1) meow_muda "CosmicTerm/font_name -> '$FAMILIA_MONO'"; mudou=1 ;;
    *) meow_erro "nao consegui escrever $TERM_DIR/font_name"; exit "$MEOW_ERRO" ;;
  esac
else
  meow_pula "$TERM_DIR nao existe — cosmic-term nunca rodou aqui"
fi

# ---------------------------------------------------------------------------
# 4. CONFERIR DE VERDADE
#
# Instalar arquivo nao e o mesmo que a fonte RESOLVER. O `fc-match` responde
# pelo fontconfig e nao pelo fontdb, mas os dois leem o mesmo TTF: se o
# fc-match cair em outra familia, o nome esta errado e o cosmic-term tambem vai
# errar — so que calado, caindo na fonte padrao sem avisar ninguem.
if ! meow_seco; then
  meow_passo "Conferencia"
  casou="$(fc-match -f '%{family}|%{file}' "$FAMILIA_MONO" 2>/dev/null)"
  fam="${casou%%|*}"; arq="${casou#*|}"
  case "$fam" in
    *"$FAMILIA_MONO"*)
      meow_ok "fc-match '$FAMILIA_MONO' -> $arq"
      total="$(du -sh "$DESTINO" 2>/dev/null | cut -f1)"
      meow_info "$(fc-list -f '.' "$FAMILIA_MONO" 2>/dev/null | wc -c) faces registradas, $total em disco"
      ;;
    *)
      meow_erro "fc-match caiu em '$fam' ($arq) — a familia nao resolveu"
      meow_info "  a fonte pode estar instalada mas o cache velho; tente 'fc-cache -f'"
      exit "$MEOW_ERRO"
      ;;
  esac
fi

if [ "$mudou" = "1" ]; then
  meow_seco || meow_info "terminais ja abertos podem precisar de uma aba nova"
  exit "$MEOW_DIVERGENTE"
fi
meow_ok "fontes ja no lugar"
exit "$MEOW_OK"

#!/usr/bin/env bash
# instalar_fontes.sh — a fonte do terminal e do código, baixada da release
# oficial do Nerd Fonts em VERSÃO PINADA, instalada só no diretório do usuário.
#
#   ./instalar_fontes.sh            instala e aplica
#   ./instalar_fontes.sh --conferir só diz se está divergente (não escreve)
#   MEOW_DRY_RUN=1 ./instalar_fontes.sh   mostra o que faria
#
# ---------------------------------------------------------------------------
# POR QUE "JetBrainsMono Nerd Font MONO" E NÃO "JetBrainsMono Nerd Font"
#
#   O tarball traz a MESMA fonte em três larguras de ícone: `NerdFont` (ícones de
#   duas células), `NerdFontMono` (ícones espremidos em uma célula) e
#   `NerdFontPropo` (proporcional). O nome parece detalhe e não é — MEDIDO nos
#   próprios TTF em 2026-08-04, lendo a tabela `post`:
#
#     JetBrainsMonoNerdFontMono-Regular.ttf : post.isFixedPitch = 1
#     JetBrainsMonoNerdFont-Regular.ttf     : post.isFixedPitch = 0
#
#   Esse bit é o que o `fontdb` — a biblioteca que o cosmic-text usa por baixo do
#   cosmic-term e do libcosmic — lê para marcar a face como monoespaçada.
#   CONFERIDO rodando o próprio fontdb (0.18) sobre os dois diretórios:
#
#     JetBrainsMonoNFM-Regular  mono=true
#     JetBrainsMonoNF-Regular   mono=false
#     JetBrainsMonoNFP-Regular  mono=false
#
#   Com `mono=false` a variante comum NÃO entra na lista de fontes monoespaçadas
#   do cosmic-settings nem do cosmic-term: a fonte fica instalada e invisível, e
#   o sintoma é "baixei e não apareceu para escolher".
#
#   Repare que o `fc-scan` diz `spacing=100` (monoespaçada) para AS DUAS: o
#   fontconfig deduz isso do PANOSE, não do `post`. Ou seja, conferir por
#   `fc-list` daria "as duas servem" e esconderia o problema. Foi por isso que a
#   escolha saiu da tabela do arquivo, e não do fontconfig.
#
#   A segunda razão para a variante Mono é a largura, MEDIDA com o ImageMagick
#   renderizando 8 glifos por linha, 48pt (8 letras "A" = 233 px em todas):
#
#     glifo      Mono   NerdFont
#     U+F09B     233      247       <- ícone do github
#     U+F015     233      254       <- casinha
#     U+EF12     233      259
#
#   Na variante Mono todo ícone cabe na MESMA célula da letra. Na comum ele
#   transborda, e o cosmic-term monta a grade pelo avanço da fonte primária:
#   ícone maior que a célula vira glifo cortado e coluna torta.
#
# SOBRE O NOME DA FAMÍLIA — a armadilha que NÃO era uma
#
#   A tabela `name` do arquivo tem dois nomes de família:
#
#     nameID  1 (Family)             = "JetBrainsMono NFM"
#     nameID 16 (Typographic Family) = "JetBrainsMono Nerd Font Mono"
#
#   A suposição natural é que só um deles funcione. Testado com o fontdb de
#   verdade: ele registra OS DOIS na mesma face, e a consulta acha a fonte por
#   qualquer um dos nomes. Nenhum dos dois "falha calado", então a escolha aqui
#   NÃO é de correção, é de coerência: usamos o nome LONGO porque é ele que o
#   cosmic-settings mostra na lista e o `fc-match` devolve primeiro. Gravar
#   "JetBrainsMono NFM" funcionaria e deixaria o arquivo de configuração
#   discordando do que a interface exibe — que é como se perde meia hora
#   procurando um problema que não existe.
#
# POR QUE AS 16 FACES, E NÃO SÓ A Regular
#
#   O cosmic-term tem três pesos configuráveis ao mesmo tempo (`font_weight`,
#   `bold_font_weight` e `dim_font_weight`, este último Light de fábrica). Sem a
#   face real, o renderizador SINTETIZA o peso — engorda o desenho por
#   algoritmo — e o resultado é visivelmente pior numa TV de 52 polegadas. As 16
#   faces (8 pesos x reto/itálico) custam 39 MB e acabam com isso.
#
# INTEGRIDADE: PINAMOS A VERSÃO **E** O CONTEÚDO
#
#   `v3.5.0` diz de onde veio; os SHA-256 dizem que é aquilo mesmo. Os dois
#   juntos fazem a idempotência ser por CONTEÚDO e não por marcador: a conferência
#   de "já está instalado" é o sha256 de cada arquivo no destino, o que também
#   pega arquivo corrompido pela metade — coisa que um carimbo de versão jura que
#   está certa. (A lista de somas é a oficial do próprio release, SHA-256.txt.)
#
# ONDE ESCREVE, E ONDE NUNCA ESCREVE
#
#   Fontes:  ~/.local/share/fonts/MeowSystem/   (nunca /usr/share — é do apt e do
#            Ritual da Aurora, e um `apt` apaga o que largarmos lá)
#   Config:  ~/.config/cosmic/com.system76.CosmicTk/v1/monospace_font
#            ~/.config/cosmic/com.system76.CosmicTerm/v1/font_name
#
#   NÃO tocamos, no CosmicTerm: font_size, opacity, use_bright_bold,
#   shortcuts_custom, focus_follow_mouse, tab_new_inherit_working_directory,
#   font_size_zoom_step_mul_100. São dela, e parte é do Aurora.
#
#   NÃO tocamos no `interface_font`: ela usa "Fira Sans", que já vem do pacote
#   `pop-fonts`. A etapa 1 daqui só CONFERE que existe e diz o que achou.
#
# NÃO MATAMOS NADA PARA "RECARREGAR"
#
#   O construir_icones.sh derruba o cosmic-panel de propósito. Aqui seria
#   desastre: `pkill cosmic-term` fecha os terminais ABERTOS dela, com o que
#   estiver rodando dentro. O cosmic-term observa a própria configuração (pelo
#   cosmic-config) e pega a fonte nova sozinho; o que não pegar, pega na aba
#   seguinte.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

# MEOW_SECO é lido pelo meow_seco() do lib/comum.sh.
#
# Argumento desconhecido NÃO pode virar instalação silenciosa. A forma antiga
# (`[ "$1" = --conferir ] && MEOW_SECO=1`) deixava `--dry-run` — que é o nome da
# VARIÁVEL documentada aqui em cima, o erro mais natural do mundo — cair direto
# no ramo que ESCREVE, com quem digitou jurando que só tinha conferido. MEDIDO
# em 2026-08-04: `./instalar_fontes.sh --dry-run` regravou o monospace_font e
# saiu 0. Erro de uso é erro de execução (2); dependência ausente é que é 3.
case "${1:-}" in
  "") : ;;
  --conferir)
    # shellcheck disable=SC2034
    MEOW_SECO=1 ;;
  *)
    meow_erro "argumento desconhecido: $1"
    meow_info "  uso: instalar_fontes.sh [--conferir]"
    meow_info "  para simular sem escrever: MEOW_DRY_RUN=1 instalar_fontes.sh"
    exit "$MEOW_ERRO" ;;
esac

# --- o upstream, pinado -----------------------------------------------------
# Origem: https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.0
# Release estável (prerelease=false), publicada em 2026-08-02T23:35:36Z.
# Baixamos SÓ o tarball da JetBrainsMono (6,4 MB). O repositório inteiro passa de
# 5 GB e não há razão nenhuma para cloná-lo.
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

# O cache do tarball fica no repo e está no .gitignore: é a mesma regra do
# baixar_upstream.sh — o git guarda a RECEITA, não os megabytes.
CACHE="$RAIZ/assets/fontes/upstream"
TAR="$CACHE/$NERD_ATIVO"

FONTES_BASE="$HOME/.local/share/fonts"
DESTINO="$FONTES_BASE/MeowSystem"

TK="$HOME/.config/cosmic/com.system76.CosmicTk/v1"
TERM_DIR="$HOME/.config/cosmic/com.system76.CosmicTerm/v1"

mudou=0

# --- dependências -----------------------------------------------------------
faltam=()
# O `cmp` está nesta lista porque é do diffutils — pacote DIFERENTE dos outros, e
# o único que pode faltar sem levar junto meia distribuição. Ele só é usado no
# ramo que instala; sem ele o script morria lá dentro com código 2 ("erro"),
# mentindo sobre a natureza do problema, que é dependência (3). MEDIDO tirando o
# cmp do PATH em 2026-08-04.
for c in curl tar sha256sum cmp fc-cache fc-list fc-match; do
  meow_tem "$c" || faltam+=("$c")
done
# O tarball é .xz: sem o descompressor, o `tar` falha no meio e deixa lixo.
meow_tem xz || meow_tem unxz || faltam+=("xz-utils")
if [ ${#faltam[@]} -gt 0 ]; then
  meow_erro "faltam ferramentas: ${faltam[*]}"
  meow_info "  sudo apt-get install curl tar coreutils diffutils fontconfig xz-utils"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

meow_destino_permitido "$DESTINO" || exit "$MEOW_ERRO"

# O `fc-list` devolve a família como LISTA separada por vírgula — o mesmo arquivo
# aparece como "JetBrainsMono Nerd Font Mono,JetBrainsMono NFM". Procurar com
# `grep` casaria "Fira Sans" dentro de "Fira Sans Compressed", que é outra fonte
# (e está instalada aqui, ao lado). A comparação abaixo é exata, item a item.
arquivos_da_familia() {
  fc-list -f '%{file}\t%{family}\n' 2>/dev/null | awk -F'\t' -v alvo="$1" '
    { n = split($2, fam, ","); for (i = 1; i <= n; i++) if (fam[i] == alvo) { print $1; next } }'
}

# ---------------------------------------------------------------------------
# 1. A FONTE DA INTERFACE — conferir, nunca reinstalar
#
# "Fira Sans" já vem do pacote `pop-fonts` do Pop!_OS, em
# /usr/share/fonts/opentype/fira. Baixar uma cópia para o diretório do usuário
# criaria DUAS famílias com o mesmo nome e caminhos diferentes: o fontconfig
# escolhe uma, o fontdb escolhe outra, e a interface fica sutilmente diferente
# do resto do sistema sem ninguém entender por quê.
meow_passo "Fonte da interface"
ui_arquivo="$(arquivos_da_familia "$FAMILIA_UI" | sort | head -1)"
if [ -n "$ui_arquivo" ]; then
  meow_ok "'$FAMILIA_UI' já instalada — $(dirname "$ui_arquivo")"
  meow_pula "nada a baixar (vem do pacote do sistema)"
else
  # Não é erro nosso e não há o que consertar aqui: a fonte de interface é do
  # sistema. Dizemos o comando e seguimos — a monoespaçada não depende dela.
  meow_aviso "'$FAMILIA_UI' NÃO está instalada"
  meow_info "  sudo apt-get install pop-fonts    # ou fonts-firacode/fonts-fira"
fi

# ---------------------------------------------------------------------------
# 2. A NERD FONT
meow_passo "Fonte monoespaçada — $FAMILIA_MONO ($NERD_TAG)"

# Uma cópia da MESMA família fora do nosso diretório (um pacote do apt, um dia)
# duplicaria as faces. Nesse caso a nossa é a sobrando: não instalamos.
externo="$(arquivos_da_familia "$FAMILIA_MONO" | grep -v "^$DESTINO/" | head -1)"

instalados_ok() {
  [ -d "$DESTINO" ] || return 1
  ( cd "$DESTINO" && printf '%s\n' "${SOMAS[@]}" | sha256sum --status -c - ) 2>/dev/null
}

# A família está utilizável nesta máquina? Vale tanto para a nossa cópia quanto
# para uma de fora. É o que decide se a conferência final (etapa 4) tem o que
# conferir — sem isto, o `--conferir` de uma máquina sem fonte nenhuma acusaria
# "não resolveu" como se fosse defeito, quando é só o que ainda não foi feito.
faces_ok=0
refazer_cache=0

if [ -n "$externo" ]; then
  # Não duplicar é a decisão certa (duas cópias da mesma família em caminhos
  # diferentes = fontconfig escolhe uma e fontdb escolhe outra). Mas isto é
  # AVISO, e não "ok" verde: as faces pinadas NÃO estão instaladas, o que ela vê
  # é a cópia de fora, e nenhum sha256 daqui garante o que tem dentro dela.
  # MEDIDO em 2026-08-04: com uma cópia sobrando em ~/.local/share/fonts, o
  # script saía 0 sem instalar nada e sem que a linha verde chamasse atenção.
  # Continua saindo 0 de propósito — divergência que nenhuma execução conserta
  # viraria alarme eterno no auto-reparo —, mas agora aparece como aviso.
  meow_aviso "'$FAMILIA_MONO' já vem de fora — não duplico"
  meow_info "  $externo"
  meow_info "  as ${#SOMAS[@]} faces pinadas ($NERD_TAG) não foram instaladas em $DESTINO"
  faces_ok=1
elif instalados_ok; then
  meow_ok "as ${#SOMAS[@]} faces já estão em $DESTINO e conferem no sha256"
  faces_ok=1
elif meow_seco; then
  meow_muda "baixaria $NERD_ATIVO ($NERD_TAG) e instalaria ${#SOMAS[@]} faces em $DESTINO"
  mudou=1
else
  # --- 2a. o tarball, no cache do repo -------------------------------------
  if [ -f "$TAR" ] && echo "$NERD_TAR_SHA256  $TAR" | sha256sum --status -c - 2>/dev/null; then
    meow_ok "$NERD_ATIVO já no cache e confere ($NERD_TAG)"
  else
    [ -f "$TAR" ] && meow_aviso "o $NERD_ATIVO do cache não confere no sha256 — baixando de novo"
    mkdir -p "$CACHE" || { meow_erro "não consegui criar $CACHE"; exit "$MEOW_ERRO"; }
    meow_info "baixando $NERD_URL"
    # Temporário DENTRO do cache: o mv final é no mesmo sistema de arquivos, e
    # um Ctrl-C no meio nunca deixa um .tar.xz pela metade com o nome definitivo.
    tmp_tar="$(mktemp -p "$CACHE" ".baixando.XXXXXX")" || exit "$MEOW_ERRO"
    if ! curl -fL --retry 3 --retry-delay 2 -o "$tmp_tar" "$NERD_URL"; then
      rm -f "$tmp_tar"
      meow_erro "falhou o download de $NERD_URL"
      exit "$MEOW_ERRO"
    fi
    # Um portal de rede ou uma página de erro do GitHub também chegam com HTTP
    # 200 e passam pelo `curl -f`. O tamanho separa "veio outra coisa" de "veio
    # corrompido" e dá uma mensagem que se entende sem abrir o arquivo.
    baixado="$(stat -c%s "$tmp_tar")"
    if [ "$baixado" != "$NERD_TAR_BYTES" ]; then
      meow_erro "o download tem $baixado bytes, esperava $NERD_TAR_BYTES ($NERD_TAG)"
      meow_info "  quase sempre é portal de rede ou proxy respondendo no lugar do GitHub"
      rm -f "$tmp_tar"
      exit "$MEOW_ERRO"
    fi
    if ! echo "$NERD_TAR_SHA256  $tmp_tar" | sha256sum --status -c - 2>/dev/null; then
      meow_erro "sha256 do $NERD_ATIVO não bate com o pinado ($NERD_TAG)"
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
  # O repo mora em /mnt/Apate e o destino em /home: `mv` entre eles NÃO é
  # atômico. Então a área de montagem nasce dentro de ~/.local/share/fonts, e
  # só depois os arquivos entram no lugar por `mv` dentro do mesmo disco.
  #
  # O ponto no começo do nome não é enfeite: o fontconfig ignora arquivo e
  # diretório começados por '.', então um scan que caia no meio da extração não
  # vê fonte pela metade.
  mkdir -p "$DESTINO" || { meow_erro "não consegui criar $DESTINO"; exit "$MEOW_ERRO"; }
  stage="$(mktemp -d -p "$FONTES_BASE" ".meow-fontes.XXXXXX")" || exit "$MEOW_ERRO"
  # shellcheck disable=SC2064
  trap "rm -rf '$stage'" EXIT

  if ! tar -xJf "$TAR" -C "$stage" --wildcards "${VARIANTE}-*.ttf" 2>/dev/null; then
    meow_erro "falhou ao extrair ${VARIANTE}-*.ttf de $TAR"
    exit "$MEOW_ERRO"
  fi

  if ! ( cd "$stage" && printf '%s\n' "${SOMAS[@]}" | sha256sum --status -c - ) 2>/dev/null; then
    meow_erro "o conteúdo extraído não confere com os sha256 pinados"
    exit "$MEOW_ERRO"
  fi

  # Instalar face a face, e só a que difere. Assim um arquivo corrompido ou
  # apagado volta sozinho sem reescrever os outros 15 — e o número que aparece
  # na tela diz exatamente o que foi consertado.
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
  faces_ok=1
  refazer_cache=1
fi

# --- 2c. faces de sobra ------------------------------------------------------
# O $DESTINO é NOSSO: quem manda nele é a lista pinada aqui em cima. Num dia de
# troca de versão (ou de fonte) as faces velhas ficariam para trás — 39 MB de
# arquivo que ninguém escolheu, competindo no fc-match com as novas. A limpeza é
# de propósito estreita: só mexe em `JetBrainsMono*.ttf`, a família que este
# script administra. Se amanhã outra frente largar uma segunda fonte aqui, ela
# não some por causa desta linha.
if [ -d "$DESTINO" ]; then
  esperadas=" $(printf '%s\n' "${SOMAS[@]}" | awk '{print $2}' | tr '\n' ' ')"
  sobrando=()
  for f in "$DESTINO"/JetBrainsMono*.ttf; do
    [ -e "$f" ] || continue          # o glob sem casar volta literal
    nome_f="$(basename "$f")"
    case "$esperadas" in *" $nome_f "*) continue ;; esac
    sobrando+=("$nome_f")
  done
  if [ ${#sobrando[@]} -gt 0 ]; then
    if meow_seco; then
      meow_muda "removeria ${#sobrando[@]} face(s) de outra versão: ${sobrando[*]}"
      mudou=1
    else
      for nome_f in "${sobrando[@]}"; do rm -f "$DESTINO/$nome_f"; done
      meow_muda "removidas ${#sobrando[@]} face(s) de outra versão: ${sobrando[*]}"
      mudou=1
      refazer_cache=1
    fi
  fi
fi

# --- 2c-bis. O ACERVO LOCAL: as fontes que ela solta ------------------------
# 27/08/2026, ela: "/home/vitoriamaria/Downloads/zrnic.zip instala essa fonte via
# install por favor."
#
# A PASTA É A INTERFACE, como em `assets/gatos/`
#   Soltou um `.otf`/`.ttf` em `assets/fontes/locais/`, ele entra; apagou, sai. Sem
#   lista dentro de script: uma lista fixa envelheceria na próxima fonte que ela
#   baixasse, e o sintoma seria "coloquei o arquivo e não aconteceu nada".
#
# POR QUE UM SUBDIRETÓRIO, E NÃO O MESMO DESTINO
#   O `$DESTINO` é do acervo Nerd Fonts, cuja verdade é a lista pinada por
#   sha256 lá em cima, e cuja limpeza de órfão é de propósito ESTREITA
#   (`JetBrainsMono*.ttf`) — o comentário de 2c diz, desde 04/08, que ela é
#   estreita justamente para não comer o que outra frente largasse ali. Esta é
#   essa outra frente. Misturar os dois no mesmo diretório obrigaria a
#   distinguir por nome ou a guardar um manifesto de estado; um subdiretório
#   resolve sem nenhum dos dois, porque `locais/` passa a ter DONO ÚNICO — e
#   remover órfão só é seguro onde o dono é único. O fontconfig varre
#   `~/.local/share/fonts` recursivamente, então a fonte é achada igual.
#
# NOMES COM ESPAÇO SÃO A NORMA AQUI, NÃO A EXCEÇÃO
#   O arquivo que ela baixou se chama `zrnic rg.otf`. Fonte de distribuidora vem
#   assim com frequência, então todo caminho abaixo é citado — e o laço lê por
#   `find -print0`, não por glob solto.
ACERVO_LOCAL="$RAIZ/assets/fontes/locais"
DESTINO_LOCAL="$DESTINO/locais"

if [ -d "$ACERVO_LOCAL" ]; then
  meow_destino_permitido "$DESTINO_LOCAL" || exit "$MEOW_ERRO"
  locais_postas=0; locais_tiradas=0
  desejadas_locais=""

  while IFS= read -r -d '' arq; do
    nome_l="$(basename "$arq")"
    desejadas_locais="$desejadas_locais$nome_l
"
    alvo_l="$DESTINO_LOCAL/$nome_l"
    if [ -f "$alvo_l" ] && cmp -s "$arq" "$alvo_l"; then
      continue
    fi
    if meow_seco; then
      meow_muda "instalaria a fonte local $nome_l em $DESTINO_LOCAL"
      mudou=1; locais_postas=$((locais_postas + 1)); continue
    fi
    mkdir -p "$DESTINO_LOCAL" || { meow_erro "não consegui criar $DESTINO_LOCAL"; exit "$MEOW_ERRO"; }
    # Temporário no MESMO diretório: `mv` entre sistemas de arquivos não é
    # atômico (a trava 2 do lib/comum.sh).
    tmp_l="$(mktemp -p "$DESTINO_LOCAL" ".meow.XXXXXX")" || exit "$MEOW_ERRO"
    cp -- "$arq" "$tmp_l" || { rm -f "$tmp_l"; meow_erro "não consegui copiar $nome_l"; exit "$MEOW_ERRO"; }
    chmod 644 "$tmp_l"
    mv -f "$tmp_l" "$alvo_l" || { rm -f "$tmp_l"; meow_erro "falhou instalar $nome_l"; exit "$MEOW_ERRO"; }
    mudou=1; refazer_cache=1; locais_postas=$((locais_postas + 1))
  done < <(find "$ACERVO_LOCAL" -maxdepth 1 -type f \( -iname '*.otf' -o -iname '*.ttf' \) -print0 2>/dev/null)

  # Órfão: estava no acervo ontem, não está hoje. Seguro porque o dono é único.
  if [ -d "$DESTINO_LOCAL" ]; then
    while IFS= read -r -d '' arq; do
      nome_l="$(basename "$arq")"
      printf '%s' "$desejadas_locais" | grep -qxF "$nome_l" && continue
      if meow_seco; then
        meow_muda "removeria $nome_l (saiu de assets/fontes/locais/)"
      else
        rm -f "$arq"; refazer_cache=1
      fi
      mudou=1; locais_tiradas=$((locais_tiradas + 1))
    done < <(find "$DESTINO_LOCAL" -maxdepth 1 -type f -print0 2>/dev/null)
  fi

  if [ "$locais_postas" = 0 ] && [ "$locais_tiradas" = 0 ]; then
    n_l="$(printf '%s' "$desejadas_locais" | grep -c . || true)"
    [ "${n_l:-0}" -gt 0 ] && meow_ok "$n_l fonte(s) do acervo local já em $DESTINO_LOCAL"
  else
    meow_info "acervo local: $locais_postas instalada(s), $locais_tiradas removida(s)"
  fi
fi

# --- 2d. avisar o fontconfig -------------------------------------------------
# Só quando algo mudou no disco: o `fc-cache -f` reconstrói todo o cache do
# usuário e leva segundos. Rodar em toda execução transformaria um script
# idempotente numa espera diária sem motivo. Vem depois da limpeza (e não dentro
# do ramo que instala) porque REMOVER arquivo também deixa o cache mentindo — e
# um cache que aponta para .ttf apagado faz o fc-match devolver caminho morto.
if [ "$refazer_cache" = "1" ] && ! fc-cache -f >/dev/null 2>&1; then
  meow_aviso "o fc-cache reclamou — as fontes estão no lugar, mas confira 'fc-list'"
fi

# ---------------------------------------------------------------------------
# 3. APONTAR O COSMIC PARA ELA
meow_passo "Configuração do COSMIC"

# O `monospace_font` do CosmicTk é um struct RON, não uma string:
#
#   (
#       family: "Noto Sans Mono",
#       weight: Normal,
#       stretch: Normal,
#       style: Normal,
#   )
#
# ...com quatro espaços de indentação e SEM quebra de linha no fim. Trocamos a
# linha do `family:` e deixamos weight/stretch/style como estão, em vez de
# reescrever o arquivo com um modelo nosso: se ela um dia escolher "Light" na
# GUI, este script não desfaz a escolha na execução seguinte.
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
  0) meow_ok "monospace_font já aponta para '$FAMILIA_MONO'" ;;
  1) meow_muda "monospace_font -> '$FAMILIA_MONO'"; mudou=1 ;;
  *) meow_erro "não consegui escrever $TK/monospace_font"; exit "$MEOW_ERRO" ;;
esac

# O cosmic-term guarda a fonte numa chave PRÓPRIA, separada do CosmicTk.
#
# A chave não existe no disco dela — e existe no programa: o `Config` do
# cosmic-term 1.5.0 traz `font_name`, `font_size`, `font_weight`, `font_stretch`,
# `dim_font_weight` e `bold_font_weight` (lidos dos nomes de campo serializados
# dentro do binário, 2026-08-04). O cosmic-config só grava a chave quando o valor
# muda; por isso o diretório dela só tem o que ela mexeu algum dia.
#
# `font_name` é uma String pura: o RON é a família entre aspas, sem quebra de
# linha no fim — o mesmo formato do `icon_theme` do CosmicTk.
#
# Se o diretório não existir, o cosmic-term nunca rodou nesta máquina: criar a
# árvore inteira aqui inventaria configuração para um app ausente.
if [ -d "$TERM_DIR" ]; then
  meow_escrever "$TERM_DIR/font_name" "\"$FAMILIA_MONO\"" 644
  case $? in
    0) meow_ok "CosmicTerm/font_name já aponta para '$FAMILIA_MONO'" ;;
    1) meow_muda "CosmicTerm/font_name -> '$FAMILIA_MONO'"; mudou=1 ;;
    *) meow_erro "não consegui escrever $TERM_DIR/font_name"; exit "$MEOW_ERRO" ;;
  esac
else
  meow_pula "$TERM_DIR não existe — cosmic-term nunca rodou aqui"
fi

# ---------------------------------------------------------------------------
# 4. CONFERIR DE VERDADE
#
# Instalar arquivo não é o mesmo que a fonte RESOLVER. O `fc-match` responde
# pelo fontconfig e não pelo fontdb, mas os dois leem o mesmo TTF: se o
# fc-match cair em outra família, o nome está errado e o cosmic-term também vai
# errar — só que calado, caindo na fonte padrão sem avisar ninguém.
#
# ESTA ETAPA RODA TAMBÉM NO `--conferir`. Antes ela era pulada no modo seco, que
# é o modo do `meow doctor`: a conferência mais forte do script justamente não
# rodava no comando chamado "conferir". Ela é LEITURA pura — o fc-match não
# escreve nada —, então o único cuidado é não rodar quando não há fonte alguma
# para resolver (aí a resposta certa é "divergente, falta instalar", e não
# "erro"). É para isso que serve o $faces_ok.
resolve_familia() {
  # FC_FAM e FC_ARQ ficam de propósito FORA do `local`: quem chama usa os dois
  # para dizer onde a fonte foi parar.
  local casou
  casou="$(fc-match -f '%{family}|%{file}' "$FAMILIA_MONO" 2>/dev/null)"
  FC_FAM="${casou%%|*}"; FC_ARQ="${casou#*|}"
  case "$FC_FAM" in *"$FAMILIA_MONO"*) return 0 ;; esac
  return 1
}

if [ "$faces_ok" = "1" ]; then
  meow_passo "Conferência"
  if ! resolve_familia && ! meow_seco; then
    # Arquivo certo e cache velho é um estado que NENHUMA outra parte do script
    # conserta: o fc-cache só roda quando algo mudou no disco, e aqui nada mudou.
    # Uma tentativa antes de desistir transforma um erro insolúvel em conserto.
    meow_aviso "a família não resolveu — refazendo o cache do fontconfig"
    fc-cache -f >/dev/null 2>&1
    mudou=1
  fi
  if resolve_familia; then
    meow_ok "fc-match '$FAMILIA_MONO' -> $FC_ARQ"
    registradas="$(arquivos_da_familia "$FAMILIA_MONO" | wc -l)"
    if [ -d "$DESTINO" ]; then
      # Sem o teste, a linha saía "16 faces registradas,  em disco" quando a
      # fonte vinha de fora e o $DESTINO nem existia.
      meow_info "$registradas faces registradas, $(du -sh "$DESTINO" 2>/dev/null | cut -f1) em $DESTINO"
    else
      meow_info "$registradas faces registradas (fora de $DESTINO)"
    fi
  elif meow_seco; then
    meow_aviso "fc-match caiu em '$FC_FAM' ($FC_ARQ) — a família não resolveu"
    meow_info "  uma execução de verdade refaz o cache do fontconfig"
    mudou=1
  else
    meow_erro "fc-match caiu em '$FC_FAM' ($FC_ARQ) — a família não resolveu"
    meow_info "  as faces estão em $DESTINO, mas o fontconfig não as enxerga"
    exit "$MEOW_ERRO"
  fi
fi

if [ "$mudou" = "1" ]; then
  meow_seco || meow_info "terminais já abertos podem precisar de uma aba nova"
  exit "$MEOW_DIVERGENTE"
fi
meow_ok "fontes já no lugar"
exit "$MEOW_OK"

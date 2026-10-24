#!/usr/bin/env bash
# instalar_fontes.sh — a fonte do terminal e do código, baixada da release
# oficial do Nerd Fonts em VERSÃO PINADA, instalada só no diretório do usuário.
#
#   ./instalar_fontes.sh            instala e aplica
#   ./instalar_fontes.sh --conferir só diz se está divergente (não escreve)
#   ./instalar_fontes.sh adicionar <arquivo>   instala uma fonte dela (.zip/.ttf/.otf)
#   MEOW_DRY_RUN=1 ./instalar_fontes.sh   mostra o que faria
#
# POR QUE "JetBrainsMono Nerd Font MONO" E NÃO "JetBrainsMono Nerd Font"
#
#     JetBrainsMonoNerdFontMono-Regular.ttf : post.isFixedPitch = 1
#     JetBrainsMonoNerdFont-Regular.ttf     : post.isFixedPitch = 0
#
#     JetBrainsMonoNFM-Regular  mono=true
#     JetBrainsMonoNF-Regular   mono=false
#     JetBrainsMonoNFP-Regular  mono=false
# Nunca `/usr/share` (é do apt); não toca no `font_size`, na opacidade nem nos atalhos
# do terminal (são dela); e não mata o `cosmic-term` para recarregar: fecharia os
# terminais abertos dela — ele relê a fonte sozinho.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

# MEOW_SECO é lido pelo meow_seco() do lib/comum.sh.
#
# Argumento desconhecido NÃO pode virar instalação silenciosa.
ACAO=""
ARQUIVO_NOVO=""
case "${1:-}" in
  "") : ;;
  --conferir)
    # shellcheck disable=SC2034
    MEOW_SECO=1 ;;
  adicionar)
    ACAO="adicionar"; ARQUIVO_NOVO="${2:-}" ;;
  *)
    meow_erro "argumento desconhecido: $1"
    meow_info "  uso: instalar_fontes.sh [--conferir | adicionar <arquivo>]"
    meow_info "  para simular sem escrever: MEOW_DRY_RUN=1 instalar_fontes.sh"
    exit "$MEOW_ERRO" ;;
esac

# --- o upstream, pinado -----------------------------------------------------
# Origem: https://github.com/ryanoasis/nerd-fonts/releases/tag/v3.5.0 Release
# estável (prerelease=false), publicada em 2026-08-02T23:35:36Z. Baixamos SÓ o
# tarball da JetBrainsMono (6,4 MB).
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

# O cache do tarball fica fora do repositório, como o do baixar_upstream.sh — o
# git guarda a RECEITA, não os megabytes.
CACHE="$MEOW_CACHE/fontes"
TAR="$CACHE/$NERD_ATIVO"

FONTES_BASE="$HOME/.local/share/fonts"
DESTINO="$FONTES_BASE/MeowSystem"

# O acervo das fontes DELA e o destino dele. Subiram para cá porque o
# `adicionar` precisa dos dois antes de o corpo do script começar; o porquê de
# serem um subdiretório próprio continua escrito por extenso na seção 2c-bis.
ACERVO_LOCAL="$RAIZ/assets/fontes/locais"
DESTINO_LOCAL="$DESTINO/locais"

COSMIC="$(meow_cosmic_dir)"
TK="$COSMIC/com.system76.CosmicTk/$(meow_cosmic_v com.system76.CosmicTk)"
TERM_DIR="$COSMIC/com.system76.CosmicTerm/$(meow_cosmic_v com.system76.CosmicTerm)"

# A rota manual existe (soltar o arquivo em `assets/fontes/locais/` e rodar o
# instalador); o que faltava era um subcomando para a página chamar.
#
# A seção 2c-bis, logo abaixo, remove de `$DESTINO/locais` TODO arquivo que não
# esteja em `assets/fontes/locais/` — é a limpeza de órfão que só é segura
# porque aquele diretório tem dono único.
#
# O arquivo é de fora: sem `eval`, citado em todo comando, o zip abre num
# temporário e o que entra no disco é o `basename`, nunca o caminho de dentro do pacote.
_fonte_nome_seguro() {
  local n; n="$(basename -- "$1" | tr -d '[:cntrl:]')"
  n="${n#"${n%%[!.-]*}"}"      # ponto na frente é fonte que o fontconfig ignora
  printf '%s' "$n"
}

# Põe UMA face no acervo e no destino. 0 = já estava idêntica · 1 = instalada ·
# 2 = erro. Quem soma isso é o chamador.
_fonte_instalar_face() {
  local origem="$1" nome alvo_acervo alvo_destino tmp
  nome="$(_fonte_nome_seguro "$origem")"
  [ -n "$nome" ] || { meow_erro "nome de arquivo vazio"; return "$MEOW_ERRO"; }
  alvo_acervo="$ACERVO_LOCAL/$nome"
  alvo_destino="$DESTINO_LOCAL/$nome"

  if [ -f "$alvo_acervo" ] && cmp -s -- "$origem" "$alvo_acervo" \
     && [ -f "$alvo_destino" ] && cmp -s -- "$origem" "$alvo_destino"; then
    meow_ok "'$nome' já está instalada"
    return "$MEOW_OK"
  fi

  if meow_seco; then
    meow_muda "instalaria '$nome' em $ACERVO_LOCAL e em $DESTINO_LOCAL"
    return "$MEOW_DIVERGENTE"
  fi

  meow_destino_permitido "$DESTINO_LOCAL" || return "$MEOW_ERRO"
  mkdir -p "$ACERVO_LOCAL" "$DESTINO_LOCAL" || {
    meow_erro "não consegui criar o acervo ou o destino"; return "$MEOW_ERRO"; }

  # Temporário no MESMO diretório dos dois lados: `mv` entre sistemas de
  # arquivos não é atômico (TRAVA 2 do lib/comum.sh — o repo está em /mnt/Apate e
  # o destino em /home), e um corte no meio deixaria meia fonte com o nome final.
  local d
  for d in "$ACERVO_LOCAL" "$DESTINO_LOCAL"; do
    tmp="$(mktemp -p "$d" ".meow-fonte.XXXXXX")" || return "$MEOW_ERRO"
    if ! cp -- "$origem" "$tmp"; then
      rm -f "$tmp"; meow_erro "não consegui copiar '$nome'"; return "$MEOW_ERRO"
    fi
    chmod 644 "$tmp"
    if ! mv -f "$tmp" "$d/$nome"; then
      rm -f "$tmp"; meow_erro "falhou instalar '$nome' em $d"; return "$MEOW_ERRO"
    fi
  done
  meow_muda "'$nome' instalada"
  return "$MEOW_DIVERGENTE"
}

# AS FERRAMENTAS QUE A PONTE ROOT INSTALA
_fontes_pela_ponte() {   # <pacote>... → 0 quando a ponte instalou algum
  local pedir=() p
  for p in "$@"; do
    case "$p" in curl|xz-utils|unzip|pop-fonts) pedir+=("$p") ;; esac
  done
  [ "${#pedir[@]}" -gt 0 ] || return 1
  meow_seco && return 1
  printf '%s\n' "${pedir[@]}" | meow_ponte pacotes >/dev/null 2>&1 || return 1
  hash -r
  meow_ok "instalados pela ponte root: ${pedir[*]}"
}

cmd_adicionar() {
  local origem="${1:-}"
  if [ -z "$origem" ]; then
    meow_erro "uso: instalar_fontes.sh adicionar <arquivo.zip|.ttf|.otf>"
    return "$MEOW_ERRO"
  fi
  [ -f "$origem" ] || { meow_erro "não achei '$origem'"; return "$MEOW_ERRO"; }

  # Dependências do SUBCOMANDO, e não as do script inteiro.
  local faltam_add=()
  meow_tem cmp      || faltam_add+=("cmp")
  meow_tem fc-cache || faltam_add+=("fc-cache")
  case "$origem" in *.zip|*.ZIP) meow_tem unzip || faltam_add+=("unzip") ;; esac
  if [ ${#faltam_add[@]} -gt 0 ] && _fontes_pela_ponte "${faltam_add[@]}"; then
    faltam_add=()
    meow_tem cmp      || faltam_add+=("cmp")
    meow_tem fc-cache || faltam_add+=("fc-cache")
    case "$origem" in *.zip|*.ZIP) meow_tem unzip || faltam_add+=("unzip") ;; esac
  fi
  if [ ${#faltam_add[@]} -gt 0 ]; then
    # O que falta fica nomeado.
    meow_erro "faltam ferramentas: ${faltam_add[*]}"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local rc="$MEOW_OK" postas=0 achadas=0 e
  case "$origem" in
    *.ttf|*.TTF|*.otf|*.OTF)
      achadas=1
      _fonte_instalar_face "$origem"; e=$?
      [ "$e" -ge 2 ] && return "$e"
      [ "$e" = "1" ] && { rc="$MEOW_DIVERGENTE"; postas=1; }
      ;;
    *.zip|*.ZIP)
      # No seco não se extrai: extrair é escrever, e o `tests/seco.sh` roda num
      # HOME de brinquedo justamente para pegar quem escreve "só num
      # temporário". A resposta honesta aqui é "instalaria as fontes deste zip".
      if meow_seco; then
        meow_muda "abriria '$origem' e instalaria as fontes dele em $DESTINO_LOCAL"
        return "$MEOW_DIVERGENTE"
      fi
      local tmp
      tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-fonte-zip.XXXXXX")" || return "$MEOW_ERRO"
      if ! unzip -q -o -- "$origem" -d "$tmp" 2>/dev/null; then
        rm -rf "$tmp"; meow_erro "o zip veio corrompido — nada instalado"; return "$MEOW_ERRO"
      fi
      local arq
      while IFS= read -r -d '' arq; do
        achadas=$((achadas + 1))
        _fonte_instalar_face "$arq"; e=$?
        if [ "$e" -ge 2 ]; then rm -rf "$tmp"; return "$e"; fi
        [ "$e" = "1" ] && { rc="$MEOW_DIVERGENTE"; postas=$((postas + 1)); }
      done < <(find "$tmp" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0 2>/dev/null)
      rm -rf "$tmp"
      ;;
    *)
      meow_erro "só sei instalar .zip, .ttf ou .otf — '$origem' não é nenhum deles"
      return "$MEOW_ERRO" ;;
  esac

  # Pacote sem uma face dentro não é "já estava assim", é o arquivo errado — e
  # dizer 0 aqui faria a página mostrar sucesso para um clique que não fez nada.
  if [ "$achadas" = "0" ]; then
    meow_erro "não achei nenhum .ttf/.otf dentro de '$origem'"
    return "$MEOW_ERRO"
  fi

  [ "$rc" = "$MEOW_OK" ] && return "$MEOW_OK"

  # O `fc-cache` FICA DENTRO DA GUARDA DO SECO, e isto quase escapou: ele
  # reconstrói `~/.cache/fontconfig`, ou seja, ensaiar escreveria no disco.
  #
  # Fora do seco ele só roda porque algo mudou no disco — a mesma regra da seção
  # 2d, e pelo mesmo motivo: `fc-cache -f` custa segundos.
  if meow_seco; then
    return "$MEOW_DIVERGENTE"
  fi
  if ! fc-cache -f >/dev/null 2>&1; then
    meow_aviso "o fc-cache reclamou — a fonte está no lugar, mas confira 'fc-list'"
  fi
  meow_registrar "instalar_fontes.sh adicionar '$origem' ($postas face(s))"
  meow_info "$postas face(s) instalada(s) — o acervo é $ACERVO_LOCAL"
  return "$MEOW_DIVERGENTE"
}

if [ "$ACAO" = "adicionar" ]; then
  cmd_adicionar "$ARQUIVO_NOVO"
  exit $?
fi

mudou=0

# --- dependências -----------------------------------------------------------
# A conta do que falta é uma função para poder ser refeita depois do pedido à
# ponte.
_fontes_faltam() {
  faltam=()
  # O `cmp` está nesta lista porque é do diffutils — pacote DIFERENTE dos
  # outros, e o único que pode faltar sem levar junto meia distribuição.
  for c in curl tar sha256sum cmp fc-cache fc-list fc-match; do
    meow_tem "$c" || faltam+=("$c")
  done
  # O tarball é .xz: sem o descompressor, o `tar` falha no meio e deixa lixo.
  meow_tem xz || meow_tem unxz || faltam+=("xz-utils")
}
_fontes_faltam
[ ${#faltam[@]} -gt 0 ] && _fontes_pela_ponte "${faltam[@]}" && _fontes_faltam
if [ ${#faltam[@]} -gt 0 ]; then
  meow_erro "faltam ferramentas: ${faltam[*]}"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

meow_destino_permitido "$DESTINO" || exit "$MEOW_ERRO"

# O `fc-list` devolve a família como LISTA separada por vírgula — o mesmo
# arquivo aparece como "JetBrainsMono Nerd Font Mono,JetBrainsMono NFM".
arquivos_da_familia() {
  fc-list -f '%{file}\t%{family}\n' 2>/dev/null | awk -F'\t' -v alvo="$1" '
    { n = split($2, fam, ","); for (i = 1; i <= n; i++) if (fam[i] == alvo) { print $1; next } }'
}

# 1. A FONTE DA INTERFACE — conferir, nunca reinstalar
#
# "Fira Sans" já vem do pacote `pop-fonts` do Pop!_OS, em
# /usr/share/fonts/opentype/fira.
meow_passo "Fonte da interface"
ui_arquivo="$(arquivos_da_familia "$FAMILIA_UI" | sort | head -1)"
if [ -z "$ui_arquivo" ] && _fontes_pela_ponte pop-fonts; then
  fc-cache -f >/dev/null 2>&1 || true
  ui_arquivo="$(arquivos_da_familia "$FAMILIA_UI" | sort | head -1)"
fi
if [ -n "$ui_arquivo" ]; then
  meow_ok "'$FAMILIA_UI' já instalada — $(dirname "$ui_arquivo")"
  meow_pula "nada a baixar (vem do pacote do sistema)"
else
  # Não é erro nosso e não há o que consertar aqui: a fonte de interface é do
  # sistema. Dizemos de onde ela vem e seguimos — a monoespaçada não depende
  # dela.
  meow_aviso "'$FAMILIA_UI' NÃO está instalada — ela vem do pacote pop-fonts do sistema"
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
# para uma de fora.
faces_ok=0
refazer_cache=0

if [ -n "$externo" ]; then
  # Não duplicar é a decisão certa (duas cópias da mesma família em caminhos
  # diferentes = fontconfig escolhe uma e fontdb escolhe outra).
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
    # Estas duas saídas devolviam 2, e o instalador de quem estava offline
    # terminava com "falhou: fontes" e `return 2`.
    if ! curl -fL --retry 3 --retry-delay 2 -o "$tmp_tar" "$NERD_URL"; then
      rm -f "$tmp_tar"
      meow_aviso "não consegui baixar $NERD_URL (sem rede?) — fica para o próximo ciclo"
      meow_info "  nada foi instalado — o terminal continua com a fonte que já tinha"
      exit "$MEOW_SEM_DEPENDENCIA"
    fi
    # Um portal de rede ou uma página de erro do GitHub também chegam com HTTP
    # 200 e passam pelo `curl -f`. O tamanho separa "veio outra coisa" de "veio
    # corrompido" e dá uma mensagem que se entende sem abrir o arquivo.
    baixado="$(stat -c%s "$tmp_tar")"
    if [ "$baixado" != "$NERD_TAR_BYTES" ]; then
      # Também 3, e pelo motivo que a própria linha de baixo já dizia: portal de
      # rede é rede que não chegou, não arquivo corrompido. Quem cai aqui está
      # num hotel ou numa rede corporativa, e a resposta certa é pular a etapa.
      meow_aviso "o download tem $baixado bytes, esperava $NERD_TAR_BYTES ($NERD_TAG)"
      meow_info "  quase sempre é portal de rede ou proxy respondendo no lugar do GitHub"
      meow_info "  nada foi instalado — o terminal continua com a fonte que já tinha"
      rm -f "$tmp_tar"
      exit "$MEOW_SEM_DEPENDENCIA"
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
  # atômico.
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
# arquivo que ninguém escolheu, competindo no fc-match com as novas.
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
#
# A PASTA É A INTERFACE, como em `packs/meowsystem/mascote/` Soltou um `.otf`/`.ttf` em
# `assets/fontes/locais/`, ele entra; apagou, sai.
#
# O `$DESTINO` é do acervo Nerd Fonts, cuja verdade é a lista pinada por sha256
# lá em cima, e cuja limpeza de órfão é de propósito ESTREITA
# (`JetBrainsMono*.ttf`) — o comentário de 2c diz, que ela é estreita justamente
# para não comer o que outra frente largasse ali.

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
  #
  # O `find` pegava todo arquivo da pasta, e o `fc-cache -f` grava ali um
  # `.uuid` (o marcador que o fontconfig põe em cada diretório que varre).
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
    done < <(find "$DESTINO_LOCAL" -maxdepth 1 -type f \( -iname '*.otf' -o -iname '*.ttf' \) -print0 2>/dev/null)
  fi

  if [ "$locais_postas" = 0 ] && [ "$locais_tiradas" = 0 ]; then
    n_l="$(printf '%s' "$desejadas_locais" | grep -c . || true)"
    [ "${n_l:-0}" -gt 0 ] && meow_ok "$n_l fonte(s) do acervo local já em $DESTINO_LOCAL"
  else
    meow_info "acervo local: $locais_postas instalada(s), $locais_tiradas removida(s)"
  fi
fi

# --- 2c-ter. AS FONTES DO PACK ----------------------
#
# Tudo neste script vinha do motor — a JetBrainsMono pinada e o acervo local
# dela —, igual para todo pack, e o `packs/dracula/pack.json` escrevia "fontes
# vêm do pack base" sobre um pack base que não declarava fonte nenhuma.
#
# O DIRETÓRIO É DE DONO ÚNICO, COMO O `locais/` `$DESTINO/pack/` só recebe o que
# o pack ativo declara, e é por isso que a limpeza de órfão aqui é segura pelo
# mesmo motivo da 2c-bis: trocar de pack tira as fontes do anterior.
#
# O verbo `tipografia` do pack.py confere cada entrada (`https://`, sha256,
# `realpath`, assinatura); aqui só se instala o que ele respondeu, e recusa quer
# dizer não mexer em nada.
DESTINO_PACK="$DESTINO/pack"
lista_pack=""; rc_pack=0
if meow_tem python3; then
  # `"$(meow_pack_dir)"` vazio é o pack padrão: o verbo trata o vazio como o
  # pack ativo, a mesma porta do `meow_app_tema_do_pack` e do `cursor.sh`.
  lista_pack="$(python3 "$RAIZ/scripts/pack.py" tipografia "$(meow_pack_dir)")"; rc_pack=$?
else
  rc_pack="$MEOW_SEM_DEPENDENCIA"
fi

if [ "$rc_pack" != "0" ]; then
  meow_aviso "não deu para ler as fontes do pack — as que ele já trouxe ficam como estão"
else
  meow_destino_permitido "$DESTINO_PACK" || exit "$MEOW_ERRO"
  pack_postas=0; pack_tiradas=0; desejadas_pack=""; quem_pack=""
  while IFS=$'\t' read -r quem_f nome_f origem_f soma_f; do
    [ -n "$nome_f" ] || continue
    quem_pack="$quem_f"
    desejadas_pack="$desejadas_pack$nome_f
"
    alvo_f="$DESTINO_PACK/$nome_f"
    case "$origem_f" in
      https://*)
        if [ -f "$alvo_f" ] && echo "$soma_f  $alvo_f" | sha256sum --status -c - 2>/dev/null; then
          continue
        fi
        if meow_seco; then
          meow_muda "baixaria a fonte $nome_f do pack $quem_f em $DESTINO_PACK"
          mudou=1; pack_postas=$((pack_postas + 1)); continue
        fi
        mkdir -p "$DESTINO_PACK" || { meow_erro "não consegui criar $DESTINO_PACK"; exit "$MEOW_ERRO"; }
        tmp_f="$(mktemp -p "$DESTINO_PACK" ".meow.XXXXXX")" || exit "$MEOW_ERRO"
        # `--proto =https` nos dois sentidos: o `pack.py` só deixa passar URL em
        # https, e um redirecionamento para http seria a mesma porta por trás.
        if ! curl -sSfL --proto '=https' --proto-redir '=https' --connect-timeout 15 \
             --max-time 300 --retry 3 --retry-delay 2 -o "$tmp_f" "$origem_f" 2>/dev/null; then
          rm -f "$tmp_f"
          meow_aviso "não consegui baixar a fonte $nome_f do pack $quem_f (sem rede?) — fica para o próximo ciclo"
          continue
        fi
        if ! echo "$soma_f  $tmp_f" | sha256sum --status -c - 2>/dev/null; then
          meow_erro "sha256 da fonte $nome_f não bate com o que o pack $quem_f pinou"
          meow_info "  esperado $soma_f"
          meow_info "  obtido   $(sha256sum "$tmp_f" | cut -d' ' -f1)"
          rm -f "$tmp_f"
          exit "$MEOW_ERRO"
        fi
        ;;
      *)
        if [ -f "$alvo_f" ] && cmp -s -- "$origem_f" "$alvo_f"; then
          continue
        fi
        if meow_seco; then
          meow_muda "instalaria a fonte $nome_f do pack $quem_f em $DESTINO_PACK"
          mudou=1; pack_postas=$((pack_postas + 1)); continue
        fi
        mkdir -p "$DESTINO_PACK" || { meow_erro "não consegui criar $DESTINO_PACK"; exit "$MEOW_ERRO"; }
        tmp_f="$(mktemp -p "$DESTINO_PACK" ".meow.XXXXXX")" || exit "$MEOW_ERRO"
        cp -- "$origem_f" "$tmp_f" || { rm -f "$tmp_f"; meow_erro "não consegui copiar $nome_f"; exit "$MEOW_ERRO"; }
        ;;
    esac
    chmod 644 "$tmp_f"
    mv -f "$tmp_f" "$alvo_f" || { rm -f "$tmp_f"; meow_erro "falhou instalar $nome_f"; exit "$MEOW_ERRO"; }
    mudou=1; refazer_cache=1; pack_postas=$((pack_postas + 1))
  done <<< "$lista_pack"

  # Órfã: estava no pack de ontem, não está no de hoje. Só fonte, pelo motivo
  # que a 2c-bis mediu em 13/09 — o `.uuid` do fontconfig não é nosso.
  if [ -d "$DESTINO_PACK" ]; then
    while IFS= read -r -d '' arq; do
      nome_l="$(basename "$arq")"
      printf '%s' "$desejadas_pack" | grep -qxF "$nome_l" && continue
      if meow_seco; then
        meow_muda "removeria $nome_l (o pack ativo não a traz)"
      else
        rm -f "$arq"; refazer_cache=1
      fi
      mudou=1; pack_tiradas=$((pack_tiradas + 1))
    done < <(find "$DESTINO_PACK" -maxdepth 1 -type f \( -iname '*.otf' -o -iname '*.ttf' \) -print0 2>/dev/null)
  fi

  if [ "$pack_postas" = 0 ] && [ "$pack_tiradas" = 0 ]; then
    n_p="$(printf '%s' "$desejadas_pack" | grep -c . || true)"
    [ "${n_p:-0}" -gt 0 ] && meow_ok "$n_p fonte(s) do pack $quem_pack já em $DESTINO_PACK"
  else
    meow_info "fontes do pack${quem_pack:+ $quem_pack}: $pack_postas instalada(s), $pack_tiradas removida(s)"
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
  # O veredito do seco, que faltava: o caminho em dia fecha com "fontes já no
  # lugar", e o divergente terminava no último detalhe. O doctor lê o veredito
  # pela última linha (`chk_fontes`), P75, 09/10/2026.
  meow_seco && meow_muda "fontes a instalar ou a apontar no COSMIC"
  exit "$MEOW_DIVERGENTE"
fi
meow_ok "fontes já no lugar"
exit "$MEOW_OK"

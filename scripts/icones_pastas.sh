#!/usr/bin/env bash
# icones_pastas.sh — o desenho do pack no ar vestindo as PASTAS ESPECIAIS do cosmic-files.
#
# A tela que ela mandou dizendo "esses são os ícones que eu quero" era a página
# do `catppuccin/vscode-icons` mostrando `folder-images`, `folder-docker`,
# `folder-github`.
#
# Medido, e a premissa caiu: das 14, o `cosmic-files` pede DUAS.
#
# O que ele pede de verdade são os nomes XDG, e disso o pack cobre 7 — com OUTRO
# NOME.
#
# Em `scalable/places`, um diretório que nasce aqui: nenhum outro script do
# projeto escreve nele.
#
#       openat(".../MeowSystem-Icons/scalable/places/folder-pictures.svg") = 99
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

# O flavor dos ÍCONES é independente do flavor do TEMA — mesma chave que as
# etapas irmãs usam, para que os tipos de arquivo e as pastas nunca discordem.
#
# Era `${ICONES_FLAVOR:-macchiato}`; agora é o `flavor-icones` do pack.py, logo
# abaixo do `_pack_ref`.

# O pack `catppuccin/vscode-icons` cobre os quatro sabores do Catppuccin e nada
# além: não existe um `catppuccin/dracula`.
#
# A condição é o DIRETÓRIO EXISTIR, não o nome do flavor: assim quem copiar o
# projeto sem esses desenhos continua caindo no Catppuccin, sem erro, e quem
# desenhar os seus não precisa editar este script.
#
# Ver o bloco gêmeo em icones_mimetypes.sh, que conta o caso inteiro.
_pack_ref="$(meow_pack_dir)"
[ -n "$_pack_ref" ] || _pack_ref="$(meow_pack_padrao_dir || true)"
FLAVOR_ICONES="$(python3 "$RAIZ/scripts/pack.py" flavor-icones "$_pack_ref")" || FLAVOR_ICONES=""
# P96 (23/10/2026): o acervo de tipo de arquivo é um molde só, pintado aqui com a paleta do
# pack no ar (o `pintados` refaz do molde a cada passada e devolve a pasta pintada).
# Quem só confere (ou roda a seco) pinta numa pasta temporária: conferir não escreve na casa.
_pintar_onde=""
{ [ "${1:-}" = "--conferir" ] || meow_seco; } && _pintar_onde="--temporario"
ORIGEM="$( [ -n "$FLAVOR_ICONES" ] && python3 "$RAIZ/scripts/pack.py" pintados "$_pack_ref" "$FLAVOR_ICONES" $_pintar_onde)" || ORIGEM=""
# A pasta temporária vai num nome próprio: o ORIGEM pode mudar logo abaixo (as pastas do pack), e
# o trap leria o valor de então — apagaria o acervo do pack.
_pintado_temporario=""
case "$ORIGEM" in */meow-pintados-*) _pintado_temporario="$ORIGEM"; trap 'rm -rf "$_pintado_temporario"' EXIT ;; esac
# Sem flavor, sem origem — a pasta-mãe do acervo não é flavor nenhum. Ver o
# bloco gêmeo em icones_mimetypes.sh.
[ -n "$FLAVOR_ICONES" ] || ORIGEM=""
# [2026-09-17] Era `if [ "${FLAVOR:-}" = "dracula" ]` — um NOME de tema cravado
# no código, que um terceiro pack nunca satisfaria.
# As pastas desenhadas pelo pack (o Dracula) moram em `icones/sistema/`, plana; quando a pasta
# declarada é o próprio molde (o pack-base), a origem é o molde pintado, acima.
_pastas_decl="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.pastas.desenhos 2>/dev/null)" || _pastas_decl=""
_molde="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.mimetypes.desenhos 2>/dev/null)" || _molde=""
_pastas_do_pack=""
[ -n "$_pastas_decl" ] && [ "${_pastas_decl%/}" != "${_molde%/}" ] && _pastas_do_pack="${_pastas_decl%/}"
if [ -n "$_pastas_do_pack" ] && [ -d "$_pastas_do_pack" ]; then
  ORIGEM="$_pastas_do_pack"
fi
# As pastas que o Criar tema levou para o pack no ar, em `icones/sistema/` com
# o nome que o tema veste: cada uma vence a da herança, e as outras seguem dela.
# Só quando o pack não declara as pastas dele (aí a pasta já é a ORIGEM).
LEVADAS=""
if [ -n "$_pack_ref" ] && [ -d "$_pack_ref/icones/sistema" ] && [ ! -L "$_pack_ref/icones/sistema" ]; then
  _levadas="$(cd "$_pack_ref/icones/sistema" && pwd -P)"
  _decl_real="$( [ -n "$_pastas_decl" ] && cd "$_pastas_decl" 2>/dev/null && pwd -P)" || _decl_real=""
  _molde_real="$( [ -n "$_molde" ] && cd "$_molde" 2>/dev/null && pwd -P)" || _molde_real=""
  [ "$_levadas" != "$_decl_real" ] && [ "$_levadas" != "$_molde_real" ] && LEVADAS="$_levadas"
fi
# As frases diziam «vestidas de Catppuccin <flavor>» fosse qual fosse a origem,
# e com o Dracula no ar a tela dizia «Catppuccin macchiato» sobre as pastas
# DELE.
VESTIDAS="de Catppuccin $FLAVOR_ICONES"; DE_QUEM="flavor $FLAVOR_ICONES"
if [ -n "$ORIGEM" ] && [ "$ORIGEM" = "$_pastas_do_pack" ]; then
  _nome_pack="$(python3 "$RAIZ/scripts/pack.py" adocao "${PACK:-}" "${FLAVOR:-}" 2>/dev/null \
                | sed -n 's/^nome=//p')" || _nome_pack=""
  VESTIDAS="com os desenhos do pack ${_nome_pack:-no ar}"
  DE_QUEM="desenhos do pack ${_nome_pack:-no ar}"
fi
# Com o caminho cravado aqui, um pack que declarasse `icones.pastas.mapa`
# passava no validador e a declaração não vestia um único ícone: é a DECLARAÇÃO
# MORTA que o bloco `CAMPOS_COM_LEITOR` do pack.py existe para caçar, entrando
# pela porta da documentação.
#
#   Mesma porta do `ORIGEM` acima (`acervo`, que SOBE A HERANÇA), e o mesmo
#   `|| MAPA=""` pelo mesmo motivo.
MAPA="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.pastas.mapa)" || MAPA=""
[ -n "$MAPA" ] || MAPA="$RAIZ/packs/meowsystem/icones/pastas.map"
TEMA="${ICONES_TEMA:-MeowSystem-Icons}"
DESTINO="$HOME/.local/share/icons/$TEMA/scalable/places"

# --- o mapa, lido uma vez -----------------------------------------------------
# Formato "nome:glifo", com # de comentário. Nenhum nome de ícone tem ':'.
declare -A MAPA_LIDO=()
_ler_mapa() {
  local linha nome glifo pulados=()
  while IFS= read -r linha || [ -n "$linha" ]; do
    # O MAPA ESCRITO NO WINDOWS. Com CRLF, o `\r` ficava no
    #   glifo, o `meow_nome_seguro` o recusava, e o pack inteiro saía sem
    #   desenho, cada linha «pulada». O `pack.py` lê o mesmo
    #   arquivo por `splitlines`, que já tira o `\r`; aqui sai do mesmo jeito.
    #   E a última linha sem quebra no fim também conta (`|| [ -n ]`).
    linha="${linha%$'\r'}"
    case "$linha" in ''|'#'*) continue ;; esac
    nome="${linha%%:*}"; glifo="${linha#*:}"
    # Os dois lados viram nome de arquivo, e um mapa de terceiro com `../` escreveria
    # fora do tema.
    #
    # Só do conjunto fechado do `meow_nome_seguro`; a linha fora dele é
    # pulada e contada.
    if ! meow_nome_seguro "$nome" || ! meow_nome_seguro "$glifo"; then
      # O nome vai para o aviso, no terminal: pela porta de saída de texto de
      # pack, e uma sequência de controle plantada no mapa não chega lá crua.
      pulados+=("$(meow_texto_seguro "$nome")"); continue
    fi
    [ -n "$nome" ] && [ -n "$glifo" ] && MAPA_LIDO["$nome"]="$glifo"
  done < "$MAPA"
  [ "${#pulados[@]}" -gt 0 ] && \
    meow_aviso "$MAPA: ${#pulados[@]} linha(s) com nome fora de [A-Za-z0-9._+-] (ou com '..') puladas: ${pulados[*]:0:3}"
  # `return 0` não é decoração: o `while` devolve o status do último teste, e com
  # `set -e` uma última linha que não case mataria o script calado. Já aconteceu
  # no `icones_sistema.sh`, na primeira execução dele.
  return 0
}

# --- dependências -------------------------------------------------------------
_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "não há acervo de pasta para o flavor '$FLAVOR_ICONES' — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem packs/meowsystem/icones/pastas.map — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- o que deveria estar no disco ---------------------------------------------
# "nome<TAB>caminho-de-origem", só dos glifos que existem de fato.
#
# As sete pastas do Dracula nasceram com o nome que o cosmic-files pede
# (`folder-documents.svg`…), e o `[ -f ]` daqui procurava `folder_docs.svg` em
# `packs/dracula/icones/pastas/`: numa casa com o Dracula no ar e
# PASTAS_XDG="sim", o `--conferir` dizia «0 pasta(s) especiais já vestidas», o
# `--aplicar` não escrevia nada, e as do Catppuccin que já estavam lá ficavam.
_desejado() {
  local nome glifo real fora=()
  for nome in "${!MAPA_LIDO[@]}"; do
    glifo="${MAPA_LIDO[$nome]}"
    if [ -n "$LEVADAS" ] && [ -f "$LEVADAS/$nome.svg" ] && [ ! -L "$LEVADAS/$nome.svg" ] \
       && real="$(meow_dentro "$LEVADAS" "$nome.svg")"; then
      printf '%s\t%s\n' "$nome" "$real"
      continue
    fi
    # Um `folder-x.svg` que é symlink para fora do pack era copiado para o
    # tema com o conteúdo do destino do link. O `meow_dentro` devolve a forma
    # conferida, e é ela que se copia.
    if [ -f "$ORIGEM/$glifo.svg" ]; then
      { [ ! -L "$ORIGEM/$glifo.svg" ] && real="$(meow_dentro "$ORIGEM" "$glifo.svg")"; } \
        || { fora+=("$glifo.svg"); continue; }
      printf '%s\t%s\n' "$nome" "$real"
    elif [ -f "$ORIGEM/$nome.svg" ]; then
      { [ ! -L "$ORIGEM/$nome.svg" ] && real="$(meow_dentro "$ORIGEM" "$nome.svg")"; } \
        || { fora+=("$nome.svg"); continue; }
      printf '%s\t%s\n' "$nome" "$real"
    fi
  done
  [ "${#fora[@]}" -gt 0 ] && \
    meow_aviso "$ORIGEM: ${#fora[@]} desenho(s) que são link (link não entra), pulados: ${fora[*]:0:3}"
  return 0
}

_conferir() {
  local nome origem divergentes=0 ausentes=0 orfaos=0 total=0 arq
  while IFS=$'\t' read -r nome origem; do
    total=$((total + 1))
    if [ ! -f "$DESTINO/$nome.svg" ]; then
      ausentes=$((ausentes + 1))
    elif [ "$(cat "$origem")" != "$(cat "$DESTINO/$nome.svg")" ]; then
      divergentes=$((divergentes + 1))
    fi
  done < <(_desejado)

  if [ -d "$DESTINO" ]; then
    for arq in "$DESTINO"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      [ -n "${MAPA_LIDO[$nome]:-}" ] || orfaos=$((orfaos + 1))
    done
  fi

  if [ "$ausentes" = 0 ] && [ "$divergentes" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$total pasta(s) especiais já vestidas $VESTIDAS"
    return "$MEOW_OK"
  fi
  meow_muda "pastas especiais: $ausentes a instalar, $divergentes a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local nome origem arq mudou=0 postos=0 removidos=0 rc

  while IFS=$'\t' read -r nome origem; do
    set +e
    meow_escrever "$DESTINO/$nome.svg" "$(cat "$origem")" 644
    rc=$?
    set -e
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") mudou=1; postos=$((postos + 1)) ;;
      *) meow_erro "não consegui escrever $DESTINO/$nome.svg"; return "$MEOW_ERRO" ;;
    esac
  done < <(_desejado)

  # Órfão: estava no mapa ontem, não está hoje. Podemos remover porque este
  # diretório tem um dono só (ver o cabeçalho).
  if [ -d "$DESTINO" ]; then
    for arq in "$DESTINO"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      if [ -z "${MAPA_LIDO[$nome]:-}" ]; then
        if meow_seco; then
          meow_muda "removeria $arq (saiu do mapa)"
        else
          meow_destino_permitido "$arq" || return "$MEOW_ERRO"
          rm -f "$arq"
        fi
        mudou=1; removidos=$((removidos + 1))
      fi
    done
  fi

  if [ "$mudou" = 0 ]; then
    meow_ok "pastas especiais já vestidas $VESTIDAS"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_info "pastas especiais: poria $postos, removeria $removidos — $DE_QUEM"
  else
    meow_info "pastas especiais: $postos posto(s), $removidos removido(s) — $DE_QUEM"
  fi
  meow_info "o cosmic-files relê o tema ao abrir uma janela nova"
  return "$MEOW_DIVERGENTE"
}

# Nenhuma delas usa `mauve`, que é o accent dela; o conjunto não fechou.
#
# As duas decisões dela apontam para o mesmo lado.
#
# Esvaziar o mapa faz todo arquivo que está em `scalable/places` virar ÓRFÃO, e
# a remoção de órfão já existe logo acima — é o mesmo caminho que roda quando
# ela tira uma linha do `pastas.map`.
_desligado() { [ "${PASTAS_XDG:-nao}" != "sim" ]; }

main() {
  _pronto || return $?
  _ler_mapa
  if _desligado; then
    # Sem nada no disco não há o que desfazer: dizer "removi" aqui seria a mesma
    # mentira de tempo verbal que o projeto já corrigiu no modo seco.
    if [ -d "$DESTINO" ] && [ -n "$(find "$DESTINO" -maxdepth 1 -name '*.svg' -print -quit 2>/dev/null)" ]; then
      # No seco, «devolveria», pelo motivo do resumo do `_aplicar`.
      if meow_seco || [ "${1:-}" = "--conferir" ]; then
        meow_info "PASTAS_XDG=\"${PASTAS_XDG:-nao}\" — devolveria as pastas especiais à cor das outras pastas"
      else
        meow_info "PASTAS_XDG=\"${PASTAS_XDG:-nao}\" — devolvendo as pastas especiais à cor das outras pastas"
      fi
      MAPA_LIDO=()
    else
      meow_ok "pastas especiais desligadas (PASTAS_XDG=\"${PASTAS_XDG:-nao}\") — elas seguem a cor das outras pastas"
      return "$MEOW_OK"
    fi
  fi
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"

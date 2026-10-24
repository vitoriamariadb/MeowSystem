#!/usr/bin/env bash
# icones_mimetypes.sh — o pack Catppuccin vestindo os ARQUIVOS, não os programas.
#
# Ela mandou usar `catppuccin/vscode-icons` em vez dos ícones autorais que o
# projeto desenhava. O pack é ótimo e tem os quatro flavors — mas ele é de
# LINGUAGEM E FORMATO DE ARQUIVO, não de aplicativo.
#
#       nomes de ícone que os .desktop desta máquina pedem ......... 50
#       cobertos pelo pack .......................................... 1  (vscode)
#
# Trocar os ícones de programa por ele deixaria 49 dos 50 sem ícone.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

# A chave separada é o que torna isso possível sem partir o significado de
# FLAVOR no resto do repo.
#
# A regra (o conf escrito à mão vence; o de fábrica que não existe cai no flavor
# que o pack escolheu) mora no `flavor_de_icones` do pack.py, e é a MESMA que a
# aba Ícones pergunta.

# O ACERVO MUDOU DE CASA — ele é do PACK, e não do motor Era
# `$RAIZ/assets/icones/catppuccin/$FLAVOR_ICONES`: 3.281 arquivos do
# `catppuccin/vscode-icons` morando em `assets/`, ao lado dos acervos que são de
# fato do motor.
#
# SEM PACK NO CONF, O ALVO É O PADRÃO — perguntado, nunca digitado.
#
# Este arquivo roda sob `set -euo pipefail`, e uma atribuição HERDA o status do
# comando substituído.
_pack_ref="$(meow_pack_dir)"
[ -n "$_pack_ref" ] || _pack_ref="$(meow_pack_padrao_dir || true)"
FLAVOR_ICONES="$(python3 "$RAIZ/scripts/pack.py" flavor-icones "$_pack_ref")" || FLAVOR_ICONES=""
# P96 (23/10/2026): um molde só no pack, pintado aqui com a paleta do pack no ar. O
# `pintados` refaz do molde a cada passada (só escreve o que mudou) e devolve a pasta.
# Quem só confere (ou roda a seco) pinta numa pasta temporária: conferir não escreve na casa.
_pintar_onde=""
{ [ "${1:-}" = "--conferir" ] || meow_seco; } && _pintar_onde="--temporario"
ORIGEM="$( [ -n "$FLAVOR_ICONES" ] && python3 "$RAIZ/scripts/pack.py" pintados "$_pack_ref" "$FLAVOR_ICONES" $_pintar_onde)" || ORIGEM=""
# A pasta temporária vai num nome próprio: o ORIGEM pode mudar logo abaixo (as pastas do pack), e
# o trap leria o valor de então — apagaria o acervo do pack.
_pintado_temporario=""
case "$ORIGEM" in */meow-pintados-*) _pintado_temporario="$ORIGEM"; trap 'rm -rf "$_pintado_temporario"' EXIT ;; esac
# SEM FLAVOR, SEM ORIGEM: `acervo ... ""` devolve a pasta-mãe do acervo (a que
# guarda um diretório por flavor), e o `_pronto` a aceitaria — o `--conferir`
# diria "0 já vestidos" com nada vestido.
[ -n "$FLAVOR_ICONES" ] || ORIGEM=""
# A frase dizia «vestidos de Catppuccin <flavor>» com qualquer pack: o doctor
# desta máquina, com o Dracula no ar, dizia «123 tipos de arquivo já vestidos de
# Catppuccin macchiato».
DONO_ACERVO="$( [ -n "$ORIGEM" ] && python3 -I - "$RAIZ/scripts" "$_pack_ref" <<'PY' 2>/dev/null
import sys
sys.path.insert(0, sys.argv[1])
import pack
print(pack.campo(sys.argv[2], "nome", "") or "")
PY
)"
[ -n "$DONO_ACERVO" ] || DONO_ACERVO="Catppuccin"
# Meio caminho: O MAPA É A DECISÃO.
#
#   Mesma porta do `ORIGEM` logo acima, e o mesmo `|| MAPA=""` pelo mesmo motivo
#   que o bloco anterior explica em detalhe: `acervo` sai 1 quando nada resolve,
#   e vazio é RESPOSTA — quem a conta em português é o `_pronto`.
MAPA="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" \
          icones.mimetypes.mapa)" || MAPA=""
TEMA="${ICONES_TEMA:-MeowSystem-Icons}"
DESTINO="$HOME/.local/share/icons/$TEMA/scalable/mimetypes"

# --- o mapa, lido uma vez -----------------------------------------------------
# Formato "nome:glifo", com # de comentário. O `cut` não serve: há nomes com '+'
# e com '.', mas nenhum com ':', então o separador é seguro.
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
    # Os dois lados viram nome de arquivo (`<nome>.svg` no tema, `<glifo>.svg`
    # no acervo): só de um conjunto fechado, sem `/` nem `..` — um mapa de pack
    # importado é dado não confiável.
    if ! meow_nome_seguro "$nome" || ! meow_nome_seguro "$glifo"; then
      # O nome vai para o aviso, no terminal: pela porta de saída de texto de
      # pack, e uma sequência de controle plantada no mapa não chega lá crua.
      pulados+=("$(meow_texto_seguro "$nome")"); continue
    fi
    [ -n "$nome" ] && [ -n "$glifo" ] && MAPA_LIDO["$nome"]="$glifo"
  done < "$MAPA"
  [ "${#pulados[@]}" -gt 0 ] && \
    meow_aviso "$MAPA: ${#pulados[@]} linha(s) com nome fora de [A-Za-z0-9._+-] (ou com '..') puladas: ${pulados[*]:0:3}"
  return 0
}

# --- dependências -------------------------------------------------------------
_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "não há acervo de mimetype para o flavor '$FLAVOR_ICONES' — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "o pack não traz mapa de mimetype (icones.mimetypes.mapa) — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- o que deveria estar no disco ---------------------------------------------
# Devolve, uma por linha, "nome<TAB>caminho-de-origem" — só dos glifos que
# existem de fato.
_desejado() {
  local nome glifo real
  for nome in "${!MAPA_LIDO[@]}"; do
    glifo="${MAPA_LIDO[$nome]}"
    # Link não entra: o `cat` o seguiria para fora do acervo.
    [ -f "$ORIGEM/$glifo.svg" ] && [ ! -L "$ORIGEM/$glifo.svg" ] \
      && real="$(meow_dentro "$ORIGEM" "$glifo.svg")" \
      && printf '%s\t%s\n' "$nome" "$real"
  done
  return 0
}

# O motivo: `meow_escrever` grava com `printf '%s' "$conteudo"`, e `$(cat ...)`
# come o `\n` final — o arquivo instalado tem exatamente 1 byte a menos que o
# original, com conteúdo idêntico.
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
    meow_ok "$total tipos de arquivo já vestidos de $DONO_ACERVO $FLAVOR_ICONES"
    return "$MEOW_OK"
  fi
  meow_muda "tipos de arquivo: $ausentes a instalar, $divergentes a atualizar, $orfaos a remover (de $total)"
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
    meow_ok "tipos de arquivo já vestidos de $DONO_ACERVO $FLAVOR_ICONES"
    return "$MEOW_OK"
  fi
  meow_info "tipos de arquivo: $postos posto(s), $removidos removido(s) — flavor $FLAVOR_ICONES"
  meow_info "o cosmic-files relê o tema ao abrir uma janela nova"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  _ler_mapa
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"

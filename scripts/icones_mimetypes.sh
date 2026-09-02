#!/usr/bin/env bash
# icones_mimetypes.sh — o pack Catppuccin vestindo os ARQUIVOS, não os programas.
#
# POR QUE ESTE SCRIPT EXISTE, E POR QUE ELE NÃO MEXE EM ÍCONE DE APLICATIVO
#   Ela mandou usar `catppuccin/vscode-icons` em vez dos ícones autorais que o
#   projeto desenhava. O pack é ótimo e tem os quatro flavors — mas ele é de
#   LINGUAGEM E FORMATO DE ARQUIVO, não de aplicativo. Medido duas vezes, por um
#   frente e depois por mim, com o mesmo resultado:
#
#       nomes de ícone que os .desktop desta máquina pedem ......... 50
#       cobertos pelo pack .......................................... 1  (vscode)
#
#   Trocar os ícones de programa por ele deixaria 49 dos 50 sem ícone. Então os
#   programas continuam vindo do Papirus (que os cobre bem) e o pack vai para
#   onde ele foi desenhado para brilhar: `mimetypes/`, que é o que o cosmic-files
#   desenha quando você abre uma pasta.
#
# ELE SÓ ESCALA PORQUE É VETOR DE VERDADE
#   O pack é grid de 16px e isso assusta — mas o SVG é stroke puro, sem raster
#   embutido. Renderizado a 64px lado a lado com o original de 16px, não há
#   diferença de nitidez. Por isso ele entra em `scalable/`, e não num tamanho
#   fixo: quem decide o tamanho é quem desenha.
#
# O DIRETÓRIO É NOSSO, E POR ISSO PODEMOS REMOVER ÓRFÃO
#   `scalable/mimetypes/` dentro de `MeowSystem-Icons` não existe no Papirus nem
#   em tema nenhum de terceiro: ele nasce aqui. Como o dono é único, tirar uma
#   linha do mapa pode remover o arquivo com segurança — a regra que o projeto
#   aprendeu a duras penas com o `custom_logo_path` (dois donos = laço eterno)
#   não é violada, porque aqui o dono é um só.
#
# O QUE NÃO ESTIVER NO MAPA CONTINUA VINDO DO PAPIRUS
#   `MeowSystem-Icons` herda `Papirus-Dark`. Um tipo de arquivo ausente do mapa
#   (xlsx e docx, por exemplo, que o pack não cobre) resolve no Papirus como
#   sempre resolveu. Não há buraco: há herança.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta o pack
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

# O flavor dos ÍCONES é independente do flavor do TEMA — ela pediu explicitamente
# "frappe ou macchiato" para os ícones, com a interface em mocha. A chave separada
# é o que torna isso possível sem partir o significado de FLAVOR no resto do repo.
FLAVOR_ICONES="${ICONES_FLAVOR:-macchiato}"

ORIGEM="$RAIZ/assets/icones/catppuccin/$FLAVOR_ICONES"
MAPA="$RAIZ/assets/icones/mimetypes.map"
TEMA="${ICONES_TEMA:-MeowSystem-Icons}"
DESTINO="$HOME/.local/share/icons/$TEMA/scalable/mimetypes"

# --- o mapa, lido uma vez -----------------------------------------------------
# Formato "nome:glifo", com # de comentário. O `cut` não serve: há nomes com '+'
# e com '.', mas nenhum com ':', então o separador é seguro.
declare -A MAPA_LIDO=()
_ler_mapa() {
  local linha nome glifo
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    nome="${linha%%:*}"; glifo="${linha#*:}"
    [ -n "$nome" ] && [ -n "$glifo" ] && MAPA_LIDO["$nome"]="$glifo"
  done < "$MAPA"
}

# --- dependências -------------------------------------------------------------
_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "o pack Catppuccin não está em assets/icones/catppuccin/$FLAVOR_ICONES — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem assets/icones/mimetypes.map — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- o que deveria estar no disco ---------------------------------------------
# Devolve, uma por linha, "nome<TAB>caminho-de-origem" — só dos glifos que existem
# de fato. Um glifo faltando é aviso, não erro: o mapa pode citar algo que o pack
# renomeou, e nesse caso o Papirus continua atendendo aquele tipo.
_desejado() {
  local nome glifo
  for nome in "${!MAPA_LIDO[@]}"; do
    glifo="${MAPA_LIDO[$nome]}"
    [ -f "$ORIGEM/$glifo.svg" ] && printf '%s\t%s\n' "$nome" "$ORIGEM/$glifo.svg"
  done
}

# O CRITÉRIO DO CONFERIR TEM DE SER O DO ESCRITOR — senão o doctor grita eternamente
#   Primeira versão disto usava `cmp -s`, byte a byte, e o resultado foi um script
#   que aplicava com sucesso e em seguida dizia "123 a atualizar", para sempre. O
#   motivo: `meow_escrever` grava com `printf '%s' "$conteudo"`, e `$(cat ...)`
#   come o `\n` final — o arquivo instalado tem exatamente 1 byte a menos que o
#   original, com conteúdo idêntico. `cmp` vê diferença; o escritor não vê.
#   Num projeto cujo auto-reparo roda todo dia por timer, um conferir mais severo
#   que o escritor é uma notificação mentirosa diária. Compare do mesmo jeito que
#   se escreve, sempre.
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
    meow_ok "$total tipos de arquivo já vestidos de Catppuccin $FLAVOR_ICONES"
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
    meow_ok "tipos de arquivo já vestidos de Catppuccin $FLAVOR_ICONES"
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

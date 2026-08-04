#!/usr/bin/env bash
# aplicar_tema.sh — devolve ao COSMIC uma captura feita por capturar_tema.sh.
#
# É ISTO QUE SUBSTITUI A GUI
#   Depois que a Vitória importou o tema uma vez e o capturamos, aplicar deixa de
#   precisar do app gráfico: é copiar a foto de volta. Vale em máquina nova, vale
#   no `install.sh` sem flag, vale no auto-reparo.
#
# NÃO ESCREVE SE JÁ ESTIVER APLICADO
#   `--conferir` compara arquivo a arquivo e sai 1 se algo divergir, sem tocar em
#   nada. É a regra 5 do contrato — comparação por conteúdo, não por existência —
#   e é o que impede o auto-reparo de "consertar" o que já está certo, de hora em
#   hora, para sempre.
#
# A GUERRA DE ALPHA COM O RITUAL DA AURORA
#   O `aurora-vidro-maximizado.py` copia o alpha de `transparent_X.base` para
#   `X.base` cerca de 1s depois de qualquer gravação, e de novo a cada ciclo do
#   self-heal. Ele mexe SÓ nos dois dígitos de alpha do `base:` raiz de
#   background, primary e secondary — o RGB Catppuccin sobrevive intacto.
#   Por isso o `--conferir` NORMALIZA esses dois dígitos nesses três arquivos:
#   sem isso o doctor acusaria divergência eterna e entraria em ping-pong com a
#   unit .path da Aurora, revertendo o vidro fosco dela a cada rodada.
#
# ESCRITA ATÔMICA, SEMPRE NO MESMO SISTEMA DE ARQUIVOS
#   O repo vive em /mnt/Apate e o destino em /home: `mv` entre eles não é atômico.
#   O temporário nasce dentro do diretório de destino final.
#
# PRECISA RELOGAR? NÃO.
#   O cosmic-config observa os arquivos por inotify; a interface acompanha em
#   segundos. O que NÃO acompanha é o cosmic-comp para night light e workspaces —
#   mas isso é outro assunto, e este script não toca neles.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COSMIC="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}"
SECO="${MEOW_DRY_RUN:-0}"

# Os três pares em que o alpha do `base:` é território da Aurora.
declare -a CHAVES_ALPHA_AURORA=(background primary secondary)

uso() {
  cat <<'FIM'
uso: aplicar_tema.sh <nome> [--conferir]

Restaura no COSMIC a captura state/tema/<nome>/.

  <nome>       qual captura aplicar. Ex.: original, mocha-mauve.
  --conferir   não escreve; sai 0 se já está aplicado, 1 se divergente.

Variáveis:
  MEOW_DRY_RUN=1    mostra o que faria e não escreve (igual a --conferir, verboso).
  MEOW_COSMIC_DIR   destino (padrão: ~/.config/cosmic).
FIM
}

[ $# -ge 1 ] || { uso >&2; exit 2; }
NOME="$1"; shift
CONFERIR=0
[ "${1:-}" = "--conferir" ] && CONFERIR=1
[ "$SECO" = "1" ] && CONFERIR=1

case "$NOME" in ''|*/*|.*) echo "ERRO: nome inválido: '$NOME'" >&2; exit 2 ;; esac
ORIGEM="$RAIZ/state/tema/$NOME"
[ -d "$ORIGEM" ] || { echo "ERRO: captura '$NOME' não existe em state/tema/" >&2; exit 3; }

# Zera os dois dígitos de alpha do `base:` de primeiro nível, para comparar só o
# que é nosso. O `base:` raiz é o que vem com 4 espaços de indentação — os
# aninhados (dentro de `component:`) têm mais, e esses NÃO são tocados pela Aurora.
#
# O casamento é com `base: "#RRGGBBAA"`, o formato de STRING HEX. Não é detalhe:
# nesta máquina o `v1` guarda cor como floats (`red: 0.19223961`) e o `v2` como
# hex — e a Aurora só mexe no hex. Num arquivo de floats este sed simplesmente
# não casa, que é o comportamento certo.
normalizar() {
  sed -E 's/^(    base: "#[0-9A-Fa-f]{6})[0-9A-Fa-f]{2}"/\1XX"/'
}

# Espelha a regra da própria Aurora em vez de fixar "v2": lá
# (aurora-vidro-maximizado.py, temas() e pares()) um diretório só entra se NÃO
# for .Builder e tiver arquivos `transparent_*`; e o par de `X` é `transparent_X`.
# Hoje isso dá exatamente Dark/v2 e Light/v2 — mas o COSMIC já migrou de v1 para
# v2 uma vez e vai migrar de novo. Deduzir a regra sobrevive à migração;
# escrever "v2" no script quebraria calado no dia seguinte.
e_chave_da_aurora() {
  local rel="$1" chave dir
  chave="$(basename "$rel")"
  dir="$(dirname "$rel")"
  case "$rel" in *.Builder/*) return 1 ;; esac
  case "$rel" in com.system76.CosmicTheme.*) ;; *) return 1 ;; esac
  for k in "${CHAVES_ALPHA_AURORA[@]}"; do
    if [ "$chave" = "$k" ] && [ -f "$ORIGEM/$dir/transparent_$k" ]; then
      return 0
    fi
  done
  return 1
}

divergentes=0
escritos=0
iguais=0

while IFS= read -r -d '' arq; do
  rel="${arq#"$ORIGEM"/}"
  case "$rel" in manifesto.sha256|captura.txt) continue ;; esac
  destino="$COSMIC/$rel"

  if [ -f "$destino" ]; then
    if e_chave_da_aurora "$rel"; then
      if diff -q <(normalizar < "$arq") <(normalizar < "$destino") >/dev/null 2>&1; then
        iguais=$((iguais+1)); continue
      fi
    elif cmp -s "$arq" "$destino"; then
      iguais=$((iguais+1)); continue
    fi
  fi

  divergentes=$((divergentes+1))
  if [ "$CONFERIR" = "1" ]; then
    [ "$SECO" = "1" ] && echo "  mudaria  $rel"
    continue
  fi

  mkdir -p "$(dirname "$destino")"
  # Temporário no diretório de DESTINO: /mnt/Apate e /home são sistemas de
  # arquivos diferentes, e mv entre eles não é atômico.
  tmp="$(mktemp -p "$(dirname "$destino")" ".meow.XXXXXX")"
  cat "$arq" > "$tmp"
  chmod 644 "$tmp"
  mv -f "$tmp" "$destino"
  escritos=$((escritos+1))
done < <(find "$ORIGEM" -type f -print0)

if [ "$CONFERIR" = "1" ]; then
  if [ "$divergentes" -eq 0 ]; then
    echo "tema '$NOME' já aplicado ($iguais arquivos conferem)"
    exit 0
  fi
  echo "tema '$NOME' divergente: $divergentes de $((divergentes+iguais)) arquivos"
  exit 1
fi

echo "tema '$NOME' aplicado: $escritos escritos, $iguais já estavam certos"
exit 0

#!/usr/bin/env bash
# icones_tray_steam.sh — o ícone da BANDEJA da Steam, e a única forma medida de
#                        ele não voltar sozinho na próxima vez que ela abrir o
#                        cliente.
#
# ============================================================================
# POR QUE ESTE SCRIPT EXISTE: A MANOBRA DE 10/08 FOI DESFEITA EM 18 MINUTOS
# ============================================================================
#
# Em 10/08/2026 o `~/.steam/debian-installation/public/steam_tray_mono.png` foi
# trocado à mão pelo glifo `steam` do Arcticons. Em 11/08 ele estava byte a byte
# igual ao de fábrica de 2014 outra vez, com o `mtime` de 2014 intacto — o que
# fazia a reversão parecer um mistério, porque nenhum arquivo escrito por nós
# nasce com data de doze anos atrás.
#
# NÃO FOI BUG NOSSO, E NÃO FOI O RITUAL DA AURORA. FOI A PRÓPRIA STEAM.
#   `grep -rn steam_tray ~/.config/zsh/scripts/` não devolve uma linha, e o
#   `meow.log` não tem nenhum registro com "steam". Quem desfez está escrito, com
#   o nome da função, no log do próprio cliente
#   (`~/.steam/debian-installation/logs/bootstrap_log.txt`):
#
#     [2026-08-10 23:29:48] Verificando a instalação...
#     [2026-08-10 23:29:48] Verifying all executable checksums
#     [2026-08-10 23:29:49] BVerifyInstalledFiles: public/steam_tray_mono.png is
#                           2342 bytes, expected 5405
#     [2026-08-10 23:29:53] Verification complete
#     [2026-08-10 23:29:53] Baixando atualização...
#     [2026-08-10 23:29:54] Extraindo o pacote...
#     [2026-08-10 23:30:05] Instalando a atualização...
#
#   Bate com o disco: TODO arquivo de `public/` tem data de nascimento
#   23:29:55–23:29:57 e `ctime` 23:30:06, com o `mtime` de dentro do pacote
#   preservado (2004, 2009, 2011, 2024…). Não foi um arquivo trocado: foi o
#   `public_all.zip` inteiro reextraído por cima.
#
# OS "11 SEGUNDOS" DA SPRINT ERAM OUTRA COISA
#   O intervalo 23:29:55 → 23:30:06 é NASCIMENTO → `ctime` do arquivo, isto é, o
#   tempo da extração do pacote inteiro mais o passo de metadados no fim. O
#   backup foi criado às 23:12:00, **17 min 55 s** antes — e não 11 segundos. A
#   hipótese de "o passo de escrita copiou o original por cima do desenhado"
#   cai por aí: entre a escrita e a reversão ela abriu a Steam, e a Steam se
#   auditou.
#
# ============================================================================
# O QUE A STEAM CONFERE — E POR QUE ISSO DECIDE O FORMATO DO ARQUIVO
# ============================================================================
#
# O cliente guarda o inventário da instalação em
# `<raiz>/package/steam_client_ubuntu12.installed`, uma linha por arquivo:
#
#     public/steam_tray_mono.png,5405;1407376580;3187707190
#     caminho                     tam ;  mtime   ;   crc
#
# Conferido aqui: `1407376580` é 2014-08-06 22:56:20, o `mtime` que o arquivo de
# fábrica tem no disco; e `zlib.crc32` do arquivo de fábrica devolve exatamente
# `3187707190`. Ou seja: os três campos são reais e o cliente tem como detectar
# qualquer mudança.
#
# E o binário confirma que ele tem as duas armas. Nas strings de
# `ubuntu12_32/steam`:
#
#     BVerifyInstalledFiles: %s is %lld bytes, expected %lld
#     BVerifyInstalledFiles: bad CRC on %s (%x expected, %x actual)
#     Verifying file sizes only      /      Verifying all executable checksums
#
# A que disparou em 10/08 foi a do TAMANHO. A do CRC não disparou porque o
# tamanho é conferido primeiro e o arquivo já tinha sido reprovado ali — não dá
# para concluir que o CRC seria poupado. Pior: todo arquivo daquele diretório
# está em modo 0775, com bit de execução ligado, então "executable checksums"
# pode muito bem alcançar um PNG.
#
# POR ISSO O ARQUIVO SAI DAQUI COM OS TRÊS CAMPOS IGUAIS AOS DE FÁBRICA
#   tamanho exato, `mtime` exato e `crc32` exato. Com os três batendo, a
#   auditoria da Steam vê uma instalação intacta e não tem o que reextrair.
#   Reaplicar sem isso seria assinar uma esteira: 180 verificações "all
#   executable checksums" e 174 "file sizes only" estão registradas naquele log,
#   uma por abertura do cliente. O `--conferir` continuaria acusando todo dia, e
#   o conserto seria desfeito toda noite.
#
#   Não há fronteira de segurança sendo furada aqui: o inventário existe para
#   pegar download corrompido, o arquivo é dela, na máquina dela, e o que muda é
#   o desenho de um ícone. O que se evita é o cliente refazer download de 24 MB
#   toda vez que ela abre a Steam.
#
# COMO SE ACERTA TAMANHO E CRC AO MESMO TEMPO
#   O PNG que o `rsvg-convert` produz tem 2429 bytes; faltam 2976 para os 5405.
#   O enchimento entra como um chunk ancilar privado `meOw` (minúsculo no 1.º
#   byte = ancilar, no 2.º = privado, maiúsculo no 3.º = reservado, minúsculo no
#   4.º = seguro de copiar), que todo decodificador ignora, com uma nota legível
#   dentro. Depois disso o `crc32` do arquivo inteiro ainda está errado, e a
#   correção são 4 bytes escolhidos por álgebra linear sobre GF(2) — o `crc32` é
#   afim nos bits da mensagem, então 32 avaliações e uma eliminação de Gauss dão
#   o valor exato, sem tentativa e erro.
#
#   OS 4 BYTES FICAM DEPOIS DO `IEND`, E NÃO DENTRO DO CHUNK — ISSO FOI MEDIDO
#     A primeira versão os pôs dentro do `meOw`, e o solucionador respondeu "sem
#     solução". O motivo é a propriedade que dá nome ao CRC: um bloco seguido do
#     próprio CRC leva o registrador a um resíduo fixo, qualquer que seja o
#     conteúdo do bloco. Dentro do chunk, os 4 bytes se cancelavam e não tinham
#     efeito nenhum sobre o total. Fora do `IEND` eles não são cobertos por CRC
#     nenhum, e a função vira uma bijeção. Byte após o `IEND` é o fim do fluxo
#     PNG pela especificação: `libpng`, `gdk-pixbuf` e o ImageMagick param ali e
#     ignoram o resto — conferido nos três com o arquivo pronto.
#
# ============================================================================
# POR QUE UM SCRIPT NOVO, E NÃO UMA LINHA NO `icones_bandeja.sh`
# ============================================================================
#
# O `icones_bandeja.sh` se declara DONO ÚNICO de `20x20/status` dentro do
# `MeowSystem-Icons` e remove órfão lá — qualquer arquivo cujo nome não esteja no
# `icons/bandeja.map` ele apaga. Este aqui escreve um PNG dentro da árvore de uma
# instalação da Steam, fora do tema de ícones, com a cor cozida no arquivo e uma
# dependência que o outro não tem (a Steam instalada). Enfiar isso naquele laço
# obrigaria o mapa a descrever destinos que não são diretório de tema, e a
# remoção de órfão passaria a mirar um diretório de terceiro. São dois contratos
# diferentes; ficam em dois arquivos.
#
# ============================================================================
# O TRAÇO É O NÚMERO DELA, E A MANOBRA DE 10/08 NÃO O USOU
# ============================================================================
#
# O arquivo de 10/08 tinha 2342 bytes. Rasterizando o mesmo glifo a 48 px SEM
# `stroke-width` dá 2342 bytes exatos; COM `stroke-width="4"` dá 2429. Ou seja: a
# manobra manual saiu com o traço padrão do SVG, que é 1 unidade de uma grade de
# 48 — 2% da caixa. A bandeja desenha esse ícone a 16×17 px (medido na captura de
# 08/08, x 1614..1629), então aquilo era 0,33 px de tela: o traço fino que o
# cabeçalho do `icones_bandeja.sh` já avisava que some.
#
# O 4 é o número que ela aprovou olhando a folha da Sprint A, e é o mesmo do
# `icones_bandeja.sh`: 4 de 48 = 8,33% da caixa, o peso relativo dela. A 16 px de
# tela isso dá 1,33 px. Se ela quiser igualar em PIXEL o peso dos vizinhos da
# barra (os simbólicos a 20 px com traço 4 saem 1,67 px), o número é 5,0 — uma
# linha aqui embaixo. É gosto, e gosto é decisão dela; o padrão fica no que ela
# já aprovou.
#
# A COR VEM COZIDA NO ARQUIVO, E NÃO DA PALETA
#   §4g do `docs/COSMIC-THEMING.md` e a remedição na própria bandeja
#   (`icons/bandeja.map:79-94`) mostram que o toolkit repinta `symbolic` e NÃO
#   repinta raster: o simbólico do Hefesto tem `#bebebe` em disco e sai `#FFFFFF`
#   na tela; este PNG saía `#DEDEDE`, a cor exata do disco. Como aqui o formato é
#   raster, a cor tem de estar no arquivo — e ela não sai de
#   `palette/catppuccin.json` de propósito: os vizinhos desta barra são cinzas
#   (`#FFFFFF` repintado nos simbólicos, `#dfdfdf` nos painéis do Papirus), e um
#   mauve aqui seria a única coisa colorida de uma barra monocromática. `#DEDEDE`
#   é o que foi medido na tela dela em 08/08.
#
# NÃO USAMOS `meow_escrever`, E A RAZÃO É O FORMATO
#   `meow_escrever` recebe o conteúdo como STRING e compara com `$(cat ...)`.
#   Substituição de comando em bash descarta bytes NUL e come `\n` final — um PNG
#   passado por ali sai corrompido, sem erro nenhum. A escrita aqui é binária e
#   direta, mas cumpre a mesma disciplina: `meow_destino_permitido` antes,
#   temporário no diretório de DESTINO (a trava 2: o repo mora em /mnt/Apate e o
#   alvo em /home, e `mv` entre sistemas de arquivos não é atômico), `mv -f` no
#   fim e `meow_manifesto_registrar` depois.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia (e foi consertado, fora do seco) · 2 erro
#   3 falta dependência: a Steam não está instalada, ou falta o rasterizador
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

GLIFO="${MEOW_TRAY_STEAM_GLIFO:-$RAIZ/icons/arcticons/steam.svg}"
TRACO="${MEOW_TRAY_STEAM_TRACO:-4}"
COR="${MEOW_TRAY_STEAM_COR:-#DEDEDE}"
FABRICA="$RAIZ/icons/tray-terceiros/steam_tray_mono.png.original"

RELATIVO="public/steam_tray_mono.png"
INVENTARIO="package/steam_client_ubuntu12.installed"

# --- onde a Steam mora -------------------------------------------------------
# `~/.steam/steam` é link para `debian-installation` nesta máquina, mas em outra
# pode ser `~/.local/share/Steam` (instalação por tarball) — o `readlink -f` de
# um link quebrado devolveria caminho que não existe, então o critério é o
# arquivo estar lá, não o diretório existir.
_raiz_steam() {
  local d
  for d in "$HOME/.steam/debian-installation" "$HOME/.steam/steam" \
           "$HOME/.local/share/Steam" "$HOME/.steam/root"; do
    [ -f "$d/$RELATIVO" ] && { readlink -f -- "$d"; return 0; }
  done
  return 1
}

# --- o que a Steam espera ver ------------------------------------------------
# Devolve "tam mtime crc". A fonte boa é o inventário do cliente, que traz os
# três campos de uma vez.
#
# O PLANO B NÃO PODE TIRAR O `mtime` DO BACKUP VERSIONADO, E ISSO QUASE PASSOU
#   `icons/tray-terceiros/steam_tray_mono.png.original` tem o CONTEÚDO de fábrica
#   mas foi copiado sem `-p` em 10/08: o `mtime` dele é 2026-08-10 23:31:54, não
#   2014-08-06 22:56:20. Tamanho e `crc32` saem do conteúdo e estão certos; o
#   `mtime` sairia doze anos errado. Por isso o plano B tira o `mtime` do arquivo
#   VIVO — que, no caso que interessa (a Steam acabou de reextrair o pacote), é
#   exatamente o de fábrica, e em regime normal é o que nós mesmos gravamos.
#
# Sem nenhuma das duas fontes o script prefere não escrever a escrever um arquivo
# que a Steam vai desfazer na próxima abertura.
_esperado() {
  local raiz="$1" linha campos
  linha="$(grep -a -m1 "^$RELATIVO," "$raiz/$INVENTARIO" 2>/dev/null)"
  if [ -n "$linha" ]; then
    campos="${linha#*,}"
    printf '%s %s %s\n' "${campos%%;*}" \
      "$(printf '%s' "$campos" | cut -d';' -f2)" \
      "$(printf '%s' "$campos" | cut -d';' -f3)"
    return 0
  fi
  if [ -f "$FABRICA" ]; then
    meow_debug "sem $INVENTARIO — tamanho e crc do backup de fábrica, mtime do arquivo vivo"
    MEOW_MTIME="$(stat -c '%Y' "$raiz/$RELATIVO" 2>/dev/null)" \
      python3 - "$FABRICA" <<'PY' 2>/dev/null || return 1
import os, sys, zlib
d = open(sys.argv[1], 'rb').read()
print(len(d), os.environ.get('MEOW_MTIME') or int(os.stat(sys.argv[1]).st_mtime),
      zlib.crc32(d) & 0xffffffff)
PY
    return 0
  fi
  return 1
}

# --- o desenho ---------------------------------------------------------------
# Rasteriza a 48 px EM TEMPO DE DESENHO (é a regra que o serrilhado de 08/08
# ensinou: nada de gerar grande e reduzir depois) e monta o arquivo no tamanho e
# no CRC que o inventário pede. 48×48 são as dimensões do arquivo de fábrica —
# mudá-las não traria nada e mexeria numa coisa que já funciona.
_desenhar() {
  local destino="$1" tam="$2" crc="$3" svg rc
  svg="$(mktemp -t meow-steam-XXXXXX.svg)" || return 1
  # UM `stroke-width` por elemento: duplicar invalida o XML e o rasterizador
  # recusa o SVG inteiro, calado. Mesma transformação do `icones_bandeja.sh`.
  if grep -q 'stroke-width' "$GLIFO"; then
    sed -E 's/stroke-width="[^"]*"/stroke-width="'"$TRACO"'"/g; s/currentColor/'"$COR"'/g' "$GLIFO" > "$svg"
  else
    sed -E 's/<(circle|rect|line|polyline|polygon|path|ellipse) /<\1 stroke-width="'"$TRACO"'" /g; s/currentColor/'"$COR"'/g' "$GLIFO" > "$svg"
  fi
  rsvg-convert -w 48 -h 48 -f png -o "$destino.cru" "$svg" 2>/dev/null; rc=$?
  rm -f "$svg"
  [ "$rc" = 0 ] || { rm -f "$destino.cru"; return 1; }

  MEOW_TAM="$tam" MEOW_CRC="$crc" python3 - "$destino.cru" "$destino" <<'PY'
import os, struct, sys, zlib

alvo_tam = int(os.environ['MEOW_TAM'])
alvo_crc = int(os.environ['MEOW_CRC'])
base = open(sys.argv[1], 'rb').read()

fim = base.rfind(b'\x00\x00\x00\x00IEND\xaeB`\x82')
if fim < 0:
    sys.exit('png sem IEND')
cabeca, iend = base[:fim], base[fim:]

# 12 = 4 do comprimento + 4 do tipo + 4 do CRC do chunk; 4 = os bytes do ajuste
# de CRC, que vão DEPOIS do IEND (ver o cabeçalho: dentro do chunk eles se
# cancelam contra o próprio CRC dele).
nota = (b'MeowSystem: o glifo steam do Arcticons (CC BY-SA 4.0) no lugar do '
        b'icone de fabrica da bandeja. Este chunk existe so para o arquivo ter '
        b'o tamanho que package/steam_client_ubuntu12.installed espera. ')
folga = alvo_tam - len(cabeca) - len(iend) - 12 - 4
if folga < 0:
    sys.exit('o desenho ja passa do tamanho de fabrica')
enchimento = (nota + b'-' * folga)[:folga]
corpo = b'meOw' + enchimento
png = (cabeca + struct.pack('>I', len(enchimento)) + corpo
       + struct.pack('>I', zlib.crc32(corpo) & 0xffffffff) + iend)

# crc32 é AFIM nos bits da mensagem: com 32 avaliações monta-se a matriz e uma
# eliminação de Gauss sobre GF(2) devolve os 4 bytes exatos. Sem chute.
def f(x): return zlib.crc32(png + struct.pack('>I', x)) & 0xffffffff
c0 = f(0)
pivos = {}
for b0 in range(32):
    v, m = f(1 << b0) ^ c0, 1 << b0
    while v:
        b = v.bit_length() - 1
        if b not in pivos:
            pivos[b] = (v, m); break
        v ^= pivos[b][0]; m ^= pivos[b][1]
x, v = 0, alvo_crc ^ c0
while v:
    b = v.bit_length() - 1
    if b not in pivos:
        sys.exit('nao ha 4 bytes que levem ao crc pedido')
    v ^= pivos[b][0]; x ^= pivos[b][1]

saida = png + struct.pack('>I', x)
if len(saida) != alvo_tam or (zlib.crc32(saida) & 0xffffffff) != alvo_crc:
    sys.exit('o arquivo montado nao bate com o alvo')
open(sys.argv[2], 'wb').write(saida)
PY
  rc=$?
  rm -f "$destino.cru"
  return "$rc"
}

# --- dependências ------------------------------------------------------------
_pronto() {
  if [ ! -f "$GLIFO" ]; then
    meow_pula "sem o glifo steam em icons/arcticons — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  RAIZ_STEAM="$(_raiz_steam)" || {
    meow_pula "a Steam não está instalada (sem $RELATIVO) — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  meow_tem rsvg-convert || {
    meow_pula "sem rsvg-convert — não dá para rasterizar o glifo"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  meow_tem python3 || {
    meow_pula "sem python3 — não dá para montar o PNG no tamanho de fábrica"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  return "$MEOW_OK"
}

# --- o desejado, calculado uma vez -------------------------------------------
# Fica num temporário FORA do HOME dela: no seco não pode sobrar arquivo nenhum,
# e o `tests/seco.sh` mede exatamente isso. O `trap` é o que garante a limpeza
# quando o script morre no meio — sem ele, um Ctrl-C deixaria PNG de 5 KB em /tmp
# a cada tentativa.
DESEJADO=""
trap '[ -n "$DESEJADO" ] && rm -f "$DESEJADO" "$DESEJADO.cru"' EXIT
_preparar() {
  local esperado tam mtime crc
  esperado="$(_esperado "$RAIZ_STEAM")" || {
    meow_erro "não achei o tamanho/crc de fábrica ($INVENTARIO nem o backup versionado)"
    meow_aviso "sem eles, um arquivo nosso seria desfeito na próxima abertura da Steam"
    return "$MEOW_ERRO"
  }
  read -r tam mtime crc <<<"$esperado"
  MTIME_FABRICA="$mtime"
  DESEJADO="$(mktemp -t meow-steam-XXXXXX.png)" || return "$MEOW_ERRO"
  if ! _desenhar "$DESEJADO" "$tam" "$crc"; then
    meow_erro "não consegui montar o PNG de $tam bytes com crc $crc"
    rm -f "$DESEJADO"; DESEJADO=""
    return "$MEOW_ERRO"
  fi
  meow_debug "alvo: $tam bytes, mtime $mtime, crc $crc"
  return "$MEOW_OK"
}

_igual() {   # 0 = o arquivo no disco já é o nosso
  cmp -s "$RAIZ_STEAM/$RELATIVO" "$DESEJADO"
}

_conferir() {
  if _igual; then
    meow_ok "o ícone da bandeja da Steam está vestido de Arcticons"
    return "$MEOW_OK"
  fi
  if cmp -s "$RAIZ_STEAM/$RELATIVO" "$FABRICA" 2>/dev/null; then
    meow_muda "o ícone da bandeja da Steam voltou ao de fábrica (o cliente reextraiu public_all.zip)"
  else
    meow_muda "o ícone da bandeja da Steam não é o nosso ($RAIZ_STEAM/$RELATIVO)"
  fi
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local alvo="$RAIZ_STEAM/$RELATIVO" tmp modo
  if _igual; then
    meow_ok "o ícone da bandeja da Steam está vestido de Arcticons"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "mudaria $alvo"
    return "$MEOW_DIVERGENTE"
  fi
  meow_destino_permitido "$alvo" || return "$MEOW_ERRO"

  # DOIS backups, e cada um responde a uma pergunta diferente. O `.meow-original`
  # ao lado é o botão de desfazer imediato ("renomeia de volta por cima") e só
  # nasce uma vez, na primeira troca — depois dela o arquivo no disco já é nosso,
  # e regravá-lo transformaria o backup numa cópia do nosso ícone. O
  # `meow_backup_sistema` é a trilha datada em `~/.local/state/meowsystem/`, a
  # mesma dos outros módulos.
  if [ ! -f "$alvo.meow-original" ]; then
    cp -a "$alvo" "$alvo.meow-original" || {
      meow_erro "não consegui guardar o original em $alvo.meow-original"
      return "$MEOW_ERRO"
    }
  fi
  meow_backup_sistema "$alvo" || {
    meow_erro "não consegui guardar o backup datado de $alvo"
    return "$MEOW_ERRO"
  }

  modo="$(stat -c '%a' "$alvo" 2>/dev/null || echo 775)"
  tmp="$(mktemp -p "$(dirname "$alvo")" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  cp -- "$DESEJADO" "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod "$modo" "$tmp"
  # O `mtime` é o terceiro campo do inventário. Sem ele o arquivo bate em tamanho
  # e em CRC e ainda assim destoa do que a Steam anotou.
  touch -d "@$MTIME_FABRICA" "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$alvo" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  meow_manifesto_registrar "$alvo"

  meow_info "ícone da bandeja da Steam: vestido de Arcticons (traço $TRACO, $COR)"
  # A espera é a mesma do `icones_bandeja.sh`, e por outro motivo ainda: o item
  # nasce quando o APP abre, e este arquivo é lido pelo cliente no start.
  meow_info "o ícone novo aparece quando a Steam reabrir"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  case "${1:-}" in
    --conferir|''|--aplicar) ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
  _preparar || return $?
  case "${1:-}" in
    --conferir) _conferir ;;
    *)          _aplicar ;;
  esac
}

main "$@"

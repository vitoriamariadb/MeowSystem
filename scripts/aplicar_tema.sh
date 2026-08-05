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

# --- OS DOIS SLIDERES DE "VIDRO FOSCO" SÃO DELA, NÃO NOSSOS ------------------
# Em Aparência → Vidro fosco a GUI do COSMIC tem dois controles: "Espessura do
# efeito fosco" (grava `frosted`) e "Opacidade do vidro" (grava `alpha_map`).
#
# ELES ESTAVAM DENTRO DA CAPTURA — e por isso não colavam. Ela movia o slider,
# via mudar, e o `meow doctor` das 5h restaurava o valor fotografado. A queixa
# "os sliders não funcionam" era literal, e a causa era esta: o projeto
# fotografou uma preferência CONTÍNUA e passou a impor a foto todo dia.
#
# A regra que sai daqui vale para além destas duas chaves: o que a GUI expõe com
# um controle contínuo é decisão de quem está na frente da tela. Medido em
# 05/08/2026 — `alpha_map`/`frosted` aparecem 268 vezes no `cosmic-settings`,
# enquanto `keep_style_on_maximize` não tem controle nenhum lá. Por isso essa
# outra continua nossa: sem GUI, se ninguém a escrever ela simplesmente se perde.
#
# CONSEQUÊNCIA PARA QUEM CAPTURA: os arquivos continuam sendo fotografados (uma
# captura tem de ser completa para servir de backup), mas deixam de ser
# IMPOSTOS. Aplicar uma captura nova respeita o vidro que ela escolheu.
declare -a CHAVES_DELA=(frosted alpha_map)

e_chave_dela() {
  local chave; chave="$(basename "$1")"
  case "$1" in com.system76.CosmicTheme.*) ;; *) return 1 ;; esac
  for k in "${CHAVES_DELA[@]}"; do [ "$chave" = "$k" ] && return 0; done
  return 1
}

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

# --- BACKUP: ESTE SCRIPT É O ÚNICO DO PROJETO QUE APAGA ARQUIVO ALHEIO -------
# Ele sobrescreve arquivos de tema e REMOVE os que sobram em relação à captura
# (ver o bloco "os arquivos que SOBRAM", mais abaixo, para saber por que remover
# é necessário). Até 05/08/2026 ele fazia as duas coisas sem guardar nada — e o
# README prometia, na cara, "todo passo faz backup antes de sobrescrever".
#
# NESTA MÁQUINA o risco era pequeno: as capturas nasceram aqui, então "sobrando"
# dá zero. O risco real é o de PUBLICAR: na máquina de um estranho, com uma
# versão do COSMIC que tenha chaves que a nossa captura não conhece, cada uma
# dessas chaves é um `rm -f` sem volta no tema que ele montou. Era a única coisa
# no projeto capaz de destruir dado de quem não é a Vitória.
#
# PREGUIÇOSO DE PROPÓSITO: o backup só nasce quando algo vai mesmo ser escrito
# ou removido. Um `--conferir` não cria nada, e a rodada que já está conforme —
# que é a esmagadora maioria — também não. Sem isso o auto-reparo diário criaria
# um diretório novo por dia sem nunca ter mudado um byte.
MEOW_ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"
BACKUPS_MANTIDOS="${BACKUPS_MANTIDOS:-10}"
BACKUP_DIR=""

garantir_backup() {
  [ -n "$BACKUP_DIR" ] && return 0            # já feito nesta execução
  BACKUP_DIR="$MEOW_ESTADO/backups/$(date -Iseconds)-tema-$NOME"
  mkdir -p "$BACKUP_DIR" || { echo "ERRO: não consegui criar $BACKUP_DIR" >&2; exit 2; }

  # Guarda as árvores INTEIRAS que esta execução pode tocar, não só os arquivos
  # que vão mudar: restaurar meia árvore devolveria o híbrido que este script
  # existe para evitar.
  for a in "$ORIGEM"/com.system76.CosmicTheme.*; do
    [ -d "$a" ] || continue
    n="$(basename "$a")"
    [ -d "$COSMIC/$n" ] || continue
    cp -a "$COSMIC/$n" "$BACKUP_DIR/" 2>/dev/null || true
  done

  ( cd "$BACKUP_DIR" && find . -type f ! -name manifesto.sha256 -exec sha256sum {} + \
      > manifesto.sha256 2>/dev/null ) || true

  # Como voltar, escrito AO LADO do backup. Um backup que só o autor sabe
  # restaurar é meia rede de segurança: quem vai precisar dele é justamente
  # alguém que não leu este script.
  cat > "$BACKUP_DIR/COMO-RESTAURAR.txt" <<FIM
Estado de ~/.config/cosmic (só as árvores de tema) antes de aplicar a captura
'$NOME', em $(date '+%d/%m/%Y %H:%M:%S').

Para voltar exatamente a este estado:

    cp -a $BACKUP_DIR/com.system76.CosmicTheme.* ~/.config/cosmic/

Para conferir que nada se corrompeu aqui dentro:

    cd $BACKUP_DIR && sha256sum -c manifesto.sha256

O COSMIC relê por inotify: a interface acompanha em segundos, sem relogar.
FIM
  echo "  backup em $BACKUP_DIR (veja COMO-RESTAURAR.txt)"

  # Retenção: as N mais recentes DESTE script. Não toca em backup de outro
  # módulo — cada um poda o que é seu.
  ls -1d "$MEOW_ESTADO"/backups/*-tema-* 2>/dev/null | sort | head -n "-$BACKUPS_MANTIDOS" \
    | while read -r velho; do rm -rf "$velho"; done
}

divergentes=0
escritos=0
iguais=0

while IFS= read -r -d '' arq; do
  rel="${arq#"$ORIGEM"/}"
  case "$rel" in manifesto.sha256|captura.txt) continue ;; esac
  destino="$COSMIC/$rel"

  # O vidro que ela ajustou na GUI vence a captura, sempre — inclusive numa
  # captura recém-aplicada. Só se escreve quando a chave ainda NÃO existe no
  # destino (máquina nova), para que o valor da captura sirva de ponto de
  # partida e nunca de correção diária.
  if e_chave_dela "$rel" && [ -f "$destino" ]; then
    iguais=$((iguais+1)); continue
  fi

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

  garantir_backup
  mkdir -p "$(dirname "$destino")"
  # Temporário no diretório de DESTINO: /mnt/Apate e /home são sistemas de
  # arquivos diferentes, e mv entre eles não é atômico.
  tmp="$(mktemp -p "$(dirname "$destino")" ".meow.XXXXXX")"
  cat "$arq" > "$tmp"
  chmod 644 "$tmp"
  mv -f "$tmp" "$destino"
  escritos=$((escritos+1))
done < <(find "$ORIGEM" -type f -print0)

# --- os arquivos que SOBRAM ------------------------------------------------
# Restaurar não é só copiar de volta: é preciso remover o que não pertence à
# captura. Isto não é hipotético — o import do tema pela GUI CRIOU 33 arquivos
# novos (o COSMIC migrou o tema para o schema v2, escrevendo Builder/v2/accent,
# palette, bg_color...). Sem esta etapa, voltar para a captura "original"
# deixaria os 33 para trás, e o tema resultante seria um híbrido: as chaves
# antigas restauradas convivendo com as novas do tema que se queria desfazer.
# É exatamente o "quase funciona" que este projeto evita desde o começo.
#
# Só se remove dentro das árvores que a captura conhece: um diretório de tema
# que não foi fotografado não é da nossa conta.
sobrando=0
for arvore in "$ORIGEM"/com.system76.CosmicTheme.*; do
  [ -d "$arvore" ] || continue
  nome_arvore="$(basename "$arvore")"
  [ -d "$COSMIC/$nome_arvore" ] || continue
  while IFS= read -r -d '' vivo; do
    rel="${vivo#"$COSMIC"/}"
    [ -e "$ORIGEM/$rel" ] && continue
    sobrando=$((sobrando+1))
    if [ "$CONFERIR" = "1" ]; then
      [ "$SECO" = "1" ] && echo "  removeria $rel"
      continue
    fi
    garantir_backup
    rm -f "$vivo"
  done < <(find "$COSMIC/$nome_arvore" -type f -print0)
done

if [ "$CONFERIR" = "1" ]; then
  if [ "$divergentes" -eq 0 ] && [ "$sobrando" -eq 0 ]; then
    echo "tema '$NOME' já aplicado ($iguais arquivos conferem)"
    exit 0
  fi
  echo "tema '$NOME' divergente: $divergentes de $((divergentes+iguais)) arquivos" \
       "${sobrando:+e $sobrando sobrando}"
  exit 1
fi

echo "tema '$NOME' aplicado: $escritos escritos, $iguais já estavam certos${sobrando:+, $sobrando removidos}"
exit 0

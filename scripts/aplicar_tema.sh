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

# --- A FRONTEIRA É POR ÁRVORE, NÃO POR CHAVE ---------------------------------
# PROTEGER O INSUMO E IMPOR O PRODUTO GARANTE UM TEMA HÍBRIDO
#   Libertar `frosted` e `alpha_map` (acima) resolveu metade do problema e criou a
#   outra. Medido nesta máquina, e é o defeito que motivou este bloco:
#
#     17:59:12–17:59:46  ela mexe os dois slideres; a GUI DERIVA o tema
#     18:00:36           o install.sh reescreve NOVE arquivos de Dark/v2 de volta
#                        para a captura de 04/08
#
#   Resultado no disco em 05/08, quatro horas depois e ainda hoje: `frosted=Low2`,
#   que implica alpha `7C`, ao lado de `transparent_background = #313244D9`. A
#   receita dela apontando para um vidro que a cor gravada não tem. Ela mexeu o
#   slider, viu mudar, e o instalador desfez sem dizer nada.
#
# ENTÃO A DIVISÃO CERTA É ESTA
#   *.Builder/v*   = A RECEITA. Continua imposta pela captura: é ela que faz o
#                    tema valer numa máquina onde ninguém nunca abriu a GUI.
#   {Dark,Light}/  = O PRODUTO da GUI. Imposto só quando o arquivo não existe
#                    (bootstrap) ou quando a receita do destino confere com a da
#                    captura. Se a receita divergiu, quem manda é a derivação
#                    dela — e a captura é que está velha.
#
# POR QUE NÃO "O RGB É NOSSO E O ALPHA É DELA"
#   Foi a outra proposta em cima da mesa, e ela parte cada arquivo ao meio. Os
#   `transparent_*` carregam o ACCENT junto: congelados como chave dela, um
#   `meow tema mocha-pink` deixaria a janela flutuante com foco mauve e a
#   maximizada com foco rosa, para sempre. Fronteira por árvore não parte arquivo
#   nenhum.
e_produto() {
  case "$1" in
    com.system76.CosmicTheme.Dark/*|com.system76.CosmicTheme.Light/*) return 0 ;;
  esac
  return 1
}

# A receita do destino confere com a da captura? Comparação por conteúdo, nas
# chaves que a GUI escreve. Ausente dos dois lados = confere (não há o que
# divergir); presente só na captura = confere (máquina nova, ainda vai receber).
receita_diverge() {
  local arv v chave a b
  for arv in Dark Light; do
    for v in v1 v2; do
      for chave in "${CHAVES_DELA[@]}"; do
        a="$ORIGEM/com.system76.CosmicTheme.$arv.Builder/$v/$chave"
        b="$COSMIC/com.system76.CosmicTheme.$arv.Builder/$v/$chave"
        [ -f "$a" ] && [ -f "$b" ] || continue
        cmp -s "$a" "$b" || return 0
      done
    done
  done
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
# Varre TODOS os argumentos, não só o primeiro. Antes olhava apenas `$1`, e com
# duas flags na linha (`--respeitar-gui --conferir`) a segunda ia para o lixo em
# silêncio — a mesma armadilha que já custou um `--yes` inventado na unidade do
# systemd. Opção desconhecida agora é erro, não é ignorada.
CONFERIR=0
for a in "$@"; do
  case "$a" in
    --conferir)      CONFERIR=1 ;;
    --respeitar-gui) ;;   # lido mais abaixo, junto do bloco que o explica
    *) echo "ERRO: opção desconhecida: '$a'" >&2; uso >&2; exit 2 ;;
  esac
done
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
cedidos=0

# --- A FRONTEIRA É OPT-IN, E ISSO NÃO É TIMIDEZ ------------------------------
# Ceder o produto derivado é o comportamento certo na MANUTENÇÃO — o install.sh
# rodando de novo, o doctor das 5h — em que ninguém pediu para mudar o tema e
# reimpor a captura só desfaria o que ela ajustou.
#
# Numa DECISÃO dela é o oposto. `meow tema mocha-pink` e `meow desfazer` são
# ordens explícitas: ali a captura tem de vencer, ou o comando não faria nada e
# ela ficaria com o accent antigo sem entender por quê. E o caso é real, não
# hipotético: `frosted` costuma ser igual entre capturas de flavors diferentes,
# então uma receita "velha" travaria a troca de flavor para sempre.
#
# Daí a flag. Quem chama para manter, passa; quem chama porque ela mandou, não.
RESPEITAR_GUI=0
[ "${MEOW_RESPEITAR_GUI:-0}" = "1" ] && RESPEITAR_GUI=1
for a in "$@"; do [ "$a" = "--respeitar-gui" ] && RESPEITAR_GUI=1; done

# Resolvido UMA vez, antes do laço: é a mesma resposta para todos os arquivos, e
# dentro do laço custaria uma varredura por arquivo.
RECEITA_VELHA=0
[ "$RESPEITAR_GUI" = "1" ] && receita_diverge && RECEITA_VELHA=1

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

  # O produto derivado só é imposto quando a receita ainda bate — ver a fronteira
  # por árvore, acima. Divergiu a receita, quem manda é a derivação da GUI dela.
  # A comparação vem ANTES desta guarda de propósito: um arquivo que já está
  # idêntico não foi "cedido", ele só está certo. Contá-lo aqui faria o script
  # anunciar "120 arquivos preservados" numa árvore em que nove divergiam.
  if [ "$RECEITA_VELHA" = "1" ] && e_produto "$rel" && [ -f "$destino" ]; then
    cedidos=$((cedidos+1)); continue
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
    # Com a receita divergente, um arquivo "a mais" dentro das árvores de produto
    # provavelmente foi a GUI dela que derivou — remover seria desfazer o ajuste
    # por outra porta, depois de ter cedido na porta da frente.
    if [ "$RECEITA_VELHA" = "1" ] && e_produto "$rel"; then
      cedidos=$((cedidos+1)); continue
    fi
    sobrando=$((sobrando+1))
    if [ "$CONFERIR" = "1" ]; then
      [ "$SECO" = "1" ] && echo "  removeria $rel"
      continue
    fi
    garantir_backup
    rm -f "$vivo"
  done < <(find "$COSMIC/$nome_arvore" -type f -print0)
done

# --- O CÓDIGO 4: "A CAPTURA ESTÁ VELHA" NÃO É DIVERGÊNCIA ---------------------
# Ele existe por causa do timer. O `meow-doctor.service` roda todo dia às 5h e o
# `ExecStopPost` notifica QUANDO O CÓDIGO É 1 — porque 1 significa "divergia e foi
# consertado". Se "a captura está velha" saísse 1, ela receberia
# "o auto-reparo corrigiu" toda madrugada, sem nada ter sido corrigido e sem nada
# PODER ser: quem decide recapturar é ela. Seria a notificação mentirosa diária,
# o mesmo anti-padrão que o projeto recusou no F11.
#
# 4 = divergente por escolha dela. O doctor mostra e não conserta; a unidade o
# aceita como sucesso (`SuccessExitStatus=1 3 4`) e o ExecStopPost fica calado,
# porque só olha o 1.
MEOW_CAPTURA_VELHA=4

aviso_receita() {
  echo "a captura '$NOME' está velha: você mexeu em Aparência e a GUI derivou um tema novo."
  echo "  $cedidos arquivo(s) preservados. Para fixar o que está na tela: meow tema capturar $NOME"
}

if [ "$CONFERIR" = "1" ]; then
  if [ "$divergentes" -eq 0 ] && [ "$sobrando" -eq 0 ]; then
    if [ "$cedidos" -gt 0 ]; then
      aviso_receita
      exit "$MEOW_CAPTURA_VELHA"
    fi
    echo "tema '$NOME' já aplicado ($iguais arquivos conferem)"
    exit 0
  fi
  echo "tema '$NOME' divergente: $divergentes de $((divergentes+iguais)) arquivos" \
       "${sobrando:+e $sobrando sobrando}"
  exit 1
fi

if [ "$escritos" -eq 0 ] && [ "$sobrando" -eq 0 ] && [ "$cedidos" -gt 0 ]; then
  aviso_receita
  exit "$MEOW_CAPTURA_VELHA"
fi

echo "tema '$NOME' aplicado: $escritos escritos, $iguais já estavam certos${sobrando:+, $sobrando removidos}${cedidos:+, $cedidos preservados da sua GUI}"
exit 0

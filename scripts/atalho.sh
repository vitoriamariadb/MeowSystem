#!/usr/bin/env bash
# atalho.sh — planta (ou tira) o `.desktop` que abre o painel de configuração.
#
#   ./atalho.sh              instala o atalho "MeowSystem" no lançador
#   ./atalho.sh --conferir   não escreve; 1 se divergir, 3 se não houver o que fazer
#   ./atalho.sh --reverter   tira o atalho e o `run.sh` copiado
#
# ─────────────────────────────────────────────────────────────────────────────
# É O ÚNICO ÍCONE DESTE PROJETO QUE ABRE UMA JANELA
# ─────────────────────────────────────────────────────────────────────────────
# Tudo o mais que o MeowSystem instala é tema, ícone de OUTRO aplicativo, applet
# de barra ou unidade de systemd. Este é o `.desktop` do MeowSystem ele mesmo — o
# que ela clica no lançador para abrir a página de configuração.
#
# ─────────────────────────────────────────────────────────────────────────────
# O `Exec=` APONTA PARA UMA CÓPIA, E NÃO PARA O CLONE
# ─────────────────────────────────────────────────────────────────────────────
# A saída óbvia era `Exec=/mnt/Apate/Desenvolvimento/MeowSystem/app/run.sh`, e ela
# tem um defeito conhecido: o repositório mora num NVMe separado, e o dia em que o
# Ápate não montar é o dia em que o ícone do lançador vira um clique que não faz
# nada — sem mensagem, sem log, sem nada na tela dizendo por quê. É o mesmo
# raciocínio que fez `etapa_cli` COPIAR o `bin/meow` para `~/.local/bin` em vez de
# linká-lo: "a cópia roda e diz 'não achei o repositório', que é uma resposta".
#
# Então o que vai para `~/.local/bin/meow-painel` é um lançador de três linhas que
# resolve a raiz do jeito que o `bin/meow` já resolve (o ponteiro
# `~/.local/state/meowsystem/raiz`), e chama o `app/run.sh` de lá. Sem o disco, ele
# diz o que houve. Com o disco, é o mesmo script de sempre — nunca uma segunda
# cópia do painel que envelheceria em silêncio.
#
# ─────────────────────────────────────────────────────────────────────────────
# `Terminal=false` — E A VERSÃO ANTERIOR ESTÁ AQUI PORQUE ELA FOI MEDIDA
# ─────────────────────────────────────────────────────────────────────────────
# Até 02/09/2026 este arquivo nascia com `Terminal=true`, e o raciocínio era
# bom: o `run.sh` fica de pé, então a janela de terminal seria o interruptor —
# fechá-la derrubaria o servidor, e um traceback do Python teria onde aparecer.
#
# NESTA MÁQUINA AQUILO NÃO ACONTECE. O journal de 02/09/2026 tem os dois cliques
# dela, às 03:22:28 e às 03:22:44, e nos dois a mesma resposta:
#
#     app-cosmic-com.meowsystem.Painel-44306.scope: PID 44306 vanished before we
#     could move it to target cgroup … Failed with result 'resources'
#
# O terminal do COSMIC é instância única: o processo que o lançador criou falou
# com a instância já aberta e saiu no mesmo instante — daí o "vanished" — e o
# painel foi parar numa ABA do terminal DELA, no meio do que ela estava fazendo.
# O `app.pid` gravado às 03:22:44.587, três décimos de segundo depois do clique,
# prova que o servidor chegou a subir: ele morreu junto quando aquela aba fechou.
# Um interruptor que ela não vê não é interruptor, e uma aba que aparece no meio
# do trabalho dela é pior que nenhuma janela.
#
# ENTÃO OS DOIS MOTIVOS DO `Terminal=true` FORAM RESOLVIDOS EM OUTRO LUGAR:
#   · o interruptor virou a própria janela do navegador — o servidor sobe com
#     `MEOW_APP_VIGIA=1` e sai quando o pulso da página some (o bloco "O PAINEL
#     MORRE COM A JANELA QUE O ABRIU", em `app/servidor.py`);
#   · a saída virou arquivo — sem tty, o `run.sh` desvia tudo para
#     `~/.local/state/meowsystem/painel.log`, e um traceback continua tendo onde
#     aparecer.
#
# `StartupWMClass` FECHA O PAR: o `run.sh` abre o Chrome com
# `--class=com.meowsystem.Painel`, e é por esta linha que o COSMIC reconhece
# aquela janela como sendo deste cartão — sem ela, a janela do painel entra no
# dock com o ícone do navegador.
#
# ─────────────────────────────────────────────────────────────────────────────
# O ÍCONE É NOME DE TEMA, NUNCA CAMINHO — e desde 02/09/2026 o desenho é NOSSO
# ─────────────────────────────────────────────────────────────────────────────
# `Icon=com.meowsystem.Painel` — um NOME, pelo mesmo motivo que o
# `leitura_build.sh` dá para o applet dele: um nome resolve pelo TEMA em uso e
# continua existindo se o repositório sair do disco; um caminho absoluto vira
# ícone quebrado.
#
# ATÉ 02/09/2026 O NOME ERA `preferences-desktop-theme`, e ela viu o resultado
# na dock: uma engrenagem cinza CHAPADA entre o Terminal e os Arquivos, que são
# traço lavender. O desenho era do Papirus (o `ICONES_BASE` de que o nosso tema
# herda) — ou seja, resolvia através do nosso tema com traço de terceiro. A
# queixa dela foi de uma linha: "não esquece de corrigir o icon da dock também".
#
# O desenho agora é o gato de traço de `meowsystem_painel()`, em
# `scripts/gerar_icones_autorais.py`, e quem o instala no tema é o
# `completar_icones.sh`, como já instala os outros autorais. Ele muda de cor com
# o `FLAVOR` e com o `ACCENT` dela, porque é gerado da paleta e não digitado.
#
# O `meow_notificar` de `lib/comum.sh` continua mandando
# `-i preferences-desktop-theme` nas notificações: são coisas diferentes, e
# trocar aquilo é outra decisão — o aviso do MeowSystem não é o painel.
#
# ─────────────────────────────────────────────────────────────────────────────
# ONDE ELE É INSTALADO, E POR QUE NÃO EM /usr/share
# ─────────────────────────────────────────────────────────────────────────────
# `~/.local/share/applications/`. A TRAVA 1 recusa `/usr/share` e está certa, e
# aqui nem há motivo para disputá-la: o problema do `cosmic-app-library` que
# obriga o `ocultar_apps.sh` a escrever lá é sobre ESCONDER um `.desktop` que já
# existe no sistema (bug pop-os/cosmic-applets#667). Criar um `.desktop` NOVO no
# home funciona normalmente — não há nada no sistema com este ID para deduplicar.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

APP_ID="com.meowsystem.Painel"
APLICATIVOS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP="$APLICATIVOS/$APP_ID.desktop"
# O CARTÃO-SOMBRA DA JANELA. O nome NÃO é escolha nossa: é o `app_id` que o
# Chromium dá a uma janela de `--app`, e o `.desktop` só é encontrado se o
# arquivo se chamar exatamente assim. Ver a seção "A JANELA TEM UM SEGUNDO
# CARTÃO" abaixo.
JANELA_ID="chrome-127.0.0.1__-Default"
JANELA="$APLICATIVOS/$JANELA_ID.desktop"
LANCADOR="$HOME/.local/bin/meow-painel"

CONFERIR=0; REVERTER=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --reverter) REVERTER=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--reverter]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && [ "$REVERTER" = 0 ] && CONFERIR=1

# --- os dois textos ---------------------------------------------------------
# O lançador que sobrevive ao Ápate desmontado. Ele repete a busca de raiz do
# `bin/meow` em versão curta: o ponteiro que o `etapa_cli` grava, e nada mais —
# quem tem o clone no disco tem o ponteiro apontando para ele.
_texto_lancador() {
  cat <<'FIM'
#!/usr/bin/env bash
# meow-painel — abre o painel de configuração do MeowSystem.
# GERADO por scripts/atalho.sh. Não edite: a próxima passagem do instalador
# reescreve este arquivo. O que ele faz de verdade mora em app/run.sh.
set -uo pipefail
ponteiro="${XDG_STATE_HOME:-$HOME/.local/state}/meowsystem/raiz"
raiz="${MEOW_RAIZ:-}"
[ -n "$raiz" ] || raiz="$(head -n1 "$ponteiro" 2>/dev/null || true)"

if [ -z "$raiz" ] || [ ! -x "$raiz/app/run.sh" ]; then
  onde="${raiz:-(o ponteiro $ponteiro está vazio ou não existe)}"
  # SEM TERMINAL, O AVISO TEM DE IR ATÉ ELA. O `.desktop` é `Terminal=false`
  # desde 02/09/2026, então escrever no stderr aqui seria falar com ninguém —
  # exatamente o "clique que não faz nada" que este lançador existe para evitar.
  # A notificação é a tela; o log é o registro; o stderr fica para quem rodou
  # `meow-painel` na mão.
  msg="Não achei o repositório do MeowSystem em $onde. Se o disco do clone não estiver montado, é isso."
  printf 'meow-painel: %s\n' "$msg" >&2
  printf '  Para apontar à mão:  MEOW_RAIZ=/caminho/do/clone meow-painel\n' >&2
  estado="${XDG_STATE_HOME:-$HOME/.local/state}/meowsystem"
  mkdir -p "$estado" 2>/dev/null &&
    printf '%s meow-painel: %s\n' "$(date -Is)" "$msg" >> "$estado/painel.log" 2>/dev/null
  command -v notify-send >/dev/null 2>&1 &&
    notify-send -a MeowSystem -i preferences-desktop-theme "MeowSystem" "$msg"
  exit 3
fi
exec "$raiz/app/run.sh" "$@"
FIM
}

# `Keywords` em português E o nome das coisas que ela procuraria: o lançador do
# COSMIC casa por prefixo em Name, GenericName e Keywords, e "tema" é a palavra
# com que alguém procura isto — não "MeowSystem", que é preciso já saber.
#
# UMA categoria principal, e isso é medido: `desktop-file-validate` em
# 01/09/2026 avisou que `Settings;DesktopSettings;Utility;` tem DUAS categorias
# principais (Settings e Utility) e que "application might appear more than once
# in the application menu". `DesktopSettings` é subcategoria de `Settings`, e o
# par sozinho não gera aviso nenhum.
_texto_desktop() {
  cat <<FIM
[Desktop Entry]
Type=Application
Name=MeowSystem
GenericName=Configuração do tema
Comment=Configurar o tema, os ícones, o papel de parede e os gatos — numa página só
Exec=$LANCADOR
Icon=$APP_ID
Terminal=false
StartupNotify=true
StartupWMClass=$APP_ID
Categories=Settings;DesktopSettings;
Keywords=meow;meowsystem;tema;theme;catppuccin;icones;ícones;gato;papel de parede;wallpaper;cosmic;aparência;
FIM
}

# A JANELA TEM UM SEGUNDO CARTÃO, E ELE EXISTE SÓ PELO ÍCONE — 02/09/2026
#
# O QUE ELA VIU
#   "não esquece de corrigir o icon da dock também", com a captura junto: entre o
#   Terminal e os Arquivos — os dois de traço lavender — o painel aberto aparecia
#   como uma engrenagem bege chapada.
#
# E A CAUSA NÃO ERA O `Icon=` DO CARTÃO DE CIMA
#   O ícone da JANELA na dock não sai do `.desktop` que a lançou: o COSMIC o
#   procura pelo `app_id` que a janela declara. Uma janela de `--app` do Chromium
#   declara `chrome-<host>__-<perfil>` e ignora o `--class` que pedimos — medido
#   na máquina dela, com o Chrome fechado, para descartar "é a instância que já
#   estava aberta". Sem `.desktop` com aquele nome, o COSMIC cai no ícone
#   genérico de aplicativo, e o genérico do Papirus é aquela engrenagem.
#
# ENTÃO O CONSERTO É DAR UM CARTÃO ÀQUELE NOME
#   `NoDisplay=true` porque ele não é um segundo aplicativo: ninguém deve
#   encontrá-lo no lançador, ele existe para o casamento da janela. O `Icon=` é o
#   mesmo do cartão de cima — os dois mostram o gato — e o `Exec=` aponta para o
#   mesmo lançador, de modo que fixar a janela na dock e clicar depois reabre o
#   painel, em vez de virar um ícone morto.
#
# O NOME É ESTÁVEL PORQUE NÓS CONTROLAMOS AS DUAS METADES
#   O host é sempre `127.0.0.1` (o servidor não escuta em outro lugar) e o perfil
#   é sempre `Default` porque o `run.sh` abre com `--user-data-dir` NOSSO. Com o
#   perfil dela seria `-Profile_2`, que muda com o que ela fizer no Chrome.
_texto_janela() {
  cat <<FIM
[Desktop Entry]
Type=Application
Name=MeowSystem
Comment=A janela do painel de configuração
Exec=$LANCADOR
Icon=$APP_ID
Terminal=false
NoDisplay=true
StartupWMClass=$JANELA_ID
FIM
}

# --- estado ------------------------------------------------------------------
_confere_arquivo() {   # 0 = igual, 1 = divergente
  local alvo="$1" esperado="$2"
  [ -f "$alvo" ] || return 1
  [ "$esperado" = "$(cat "$alvo" 2>/dev/null)" ]
}

_conferir() {
  local faltando=()
  _confere_arquivo "$DESKTOP" "$(_texto_desktop)"   || faltando+=("$APP_ID.desktop")
  _confere_arquivo "$JANELA" "$(_texto_janela)"     || faltando+=("$JANELA_ID.desktop")
  _confere_arquivo "$LANCADOR" "$(_texto_lancador)" || faltando+=("meow-painel")
  # O bit de execução conta como divergência: um lançador sem `+x` é um ícone
  # que abre e fecha na mesma hora, e nada na tela explica.
  if [ -f "$LANCADOR" ] && [ ! -x "$LANCADOR" ]; then faltando+=("meow-painel sem +x"); fi
  # A página é o que o atalho abre. Sem ela o atalho é um botão que dá 500 —
  # e a causa (clone incompleto) merece ser dita aqui, não no navegador.
  if [ ! -f "$RAIZ/app/pagina/index.html" ] || [ ! -f "$RAIZ/app/servidor.py" ]; then
    meow_erro "o atalho existe mas app/ está incompleto neste clone"
    return "$MEOW_ERRO"
  fi

  if [ "${#faltando[@]}" -gt 0 ]; then
    meow_muda "atalho do painel a instalar: ${faltando[*]}"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "atalho \"MeowSystem\" no lançador, abrindo app/run.sh"
  return "$MEOW_OK"
}

_aplicar() {
  local mudou=0 rc

  meow_escrever "$LANCADOR" "$(_texto_lancador)" 755; rc=$?
  case "$rc" in
    0) ;;
    1) mudou=1 ;;
    *) meow_erro "não consegui escrever $LANCADOR"; return "$MEOW_ERRO" ;;
  esac
  # Mesmo cinto do `etapa_cli`: a `meow_escrever` sai ANTES do chmod quando o
  # conteúdo já confere, então um arquivo que perdeu o bit nunca o recuperaria.
  if [ -f "$LANCADOR" ] && [ ! -x "$LANCADOR" ]; then chmod 755 "$LANCADOR"; mudou=1; fi

  meow_escrever "$DESKTOP" "$(_texto_desktop)" 644; rc=$?
  case "$rc" in
    0) ;;
    1) mudou=1 ;;
    *) meow_erro "não consegui escrever $DESKTOP"; return "$MEOW_ERRO" ;;
  esac

  meow_escrever "$JANELA" "$(_texto_janela)" 644; rc=$?
  case "$rc" in
    0) ;;
    1) mudou=1 ;;
    *) meow_erro "não consegui escrever $JANELA"; return "$MEOW_ERRO" ;;
  esac

  if [ "$mudou" = 0 ]; then
    meow_ok "atalho \"MeowSystem\" já está no lançador"
    return "$MEOW_OK"
  fi

  # O MENU DE LANÇAMENTO NÃO RELÊ SOZINHO — e é por isso que esta linha existe.
  # `lib/comum.sh` mede o caso: o `cosmic-app-library` e o `cosmic-launcher`
  # resolvem os `.desktop` no arranque e guardam. Sem chacoalhá-los, o atalho
  # está no disco e não está na tela dela, que são perguntas diferentes — e é
  # exatamente o "instalei e não apareceu" que aquele cabeçalho explica.
  # Chamar isto SÓ quando algo mudou é obrigatório: a função fecha a grade de
  # aplicativos se ela estiver aberta.
  meow_lancador_reler

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) meow_aviso "~/.local/bin não está no \$PATH — o atalho funciona, mas 'meow-painel' na mão não" ;;
  esac

  meow_ok "atalho \"MeowSystem\" instalado no lançador"
  meow_info "  abre em: $LANCADOR  ->  $RAIZ/app/run.sh"
  return "$MEOW_DIVERGENTE"
}

_reverter() {
  local n=0
  for arq in "$DESKTOP" "$JANELA" "$LANCADOR"; do
    [ -e "$arq" ] || continue
    if meow_seco; then meow_muda "removeria $arq"; else rm -f "$arq"; fi
    n=$((n+1))
  done
  if [ "$n" = 0 ]; then
    meow_pula "o atalho do painel não estava instalado"
    return "$MEOW_OK"
  fi
  meow_seco || meow_lancador_reler
  meow_seco || meow_ok "atalho do painel removido ($n arquivo(s))"
  return "$MEOW_DIVERGENTE"
}

main() {
  [ "$REVERTER" = 1 ] && { _reverter; return $?; }
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"

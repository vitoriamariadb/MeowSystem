#!/usr/bin/env bash
# leitura.sh — o horário liga o modo de leitura sozinho, e o desliga sozinho.
#
# O QUE ELE FAZ, EM UMA FRASE
#   A cada tique ele pergunta "que horas são?" e "que degrau o relógio pede?", e
#   põe DOIS números no disco:
#       ~/.config/cosmic/com.system76.CosmicComp/v1/leitura_temperatura   (Kelvin)
#       ~/.config/cosmic/com.system76.CosmicComp/v1/leitura_textura       (0.0..1.0)
#   Quem PINTA é o `cosmic-comp` recompilado (etapa 1 do plano de 29/08). Este
#   arquivo não pinta um pixel, não fala Wayland, não reinicia nada e não toca em
#   binário nenhum.
#
# ============================================================================
# O QUE ESTAVA MEDIDO NESTA MÁQUINA EM 30/08/2026, ANTES DE ESCREVER UMA LINHA
# ============================================================================
#
# 1. AS DUAS CHAVES AINDA NÃO EXISTEM, E ISSO É DE PROPÓSITO
#      ls ~/.config/cosmic/com.system76.CosmicComp/v1/
#        accessibility_zoom  activation_policy  active_hint  appearance_settings
#        autotile  autotile_behavior  edge_snap_threshold  input_default
#        keyboard_config  pinned_workspaces  xkb_config  xwayland_eavesdropping
#    Nenhuma `leitura_*`. O `cosmic-comp` do disco também não as conhece: ele é
#    o binário rebuildado às 01:46 de hoje, que traz só o patch de workspace.
#
#    ESCREVER NELAS HOJE É INOFENSIVO. O `cosmic-comp` ignora chave que não está
#    no struct dele (serde com `#[serde(default)]` por campo — chave a mais em
#    diretório de cosmic-config não é erro de parse, é arquivo que ninguém abre).
#    O valor passa a valer no login DEPOIS do build da etapa 1. Ou seja: este
#    script funciona hoje, e o efeito na tela chega quando o compositor souber
#    ler — sem que ninguém precise voltar aqui.
#
# 2. O `mv` DO `meow_escrever` **ACORDA** O WATCHER. O PLANO DE 29/08 ERRA AQUI.
#    O plano manda "escrever a chave com redirecionamento `>`, NUNCA com `mv` —
#    o watcher do cosmic-config descarta o evento de rename". Está errado, e é
#    grave o bastante para o desenho: seguir esse passo obrigaria este arquivo a
#    escrever por fora do `meow_escrever`, ou seja, por fora da TRAVA 1, da TRAVA
#    2, do manifesto e do `MEOW_DRY_RUN`.
#
#    O que o watcher descarta, LIDO NA FONTE desta máquina
#    (`~/.cargo/git/checkouts/libcosmic-*/cosmic-config/src/lib.rs:393-395`):
#        EventKind::Access(_)
#        | EventKind::Modify(ModifyKind::Metadata(_))
#        | EventKind::Modify(ModifyKind::Name(RenameMode::Both)) => return;
#    Só o `Both`. E o backend inotify do `notify` 8.2.0 (`src/inotify.rs:244-266`)
#    emite TRÊS eventos num rename: `Name(To)` com o caminho de DESTINO, depois
#    `Name(Both)` com os dois caminhos — e o `Name(From)` do temporário veio
#    antes. Ou seja, o `Name(To)` passa pelo filtro, carrega o nome da chave
#    (`leitura_temperatura`), e a callback é chamada.
#
#    Isto não é dedução nova: é EXATAMENTE o que o `lib/comum.sh:160-179` já
#    tinha medido do outro lado do problema — "o painel recebia QUATRO eventos
#    por chave gravada — o Create do temporário, o Modify(Data), o Name(From) e
#    só então o Name(To) legítimo". Aquele comentário existe porque o rename
#    acorda demais, não de menos. O `.atomicwrite` no nome do temporário é o que
#    cala os outros três (`lib.rs:407-408`), e é do próprio `meow_escrever`.
#
#    Então aqui se escreve pelo `meow_escrever`, como todo o resto do projeto.
#
# 3. A LUZ QUENTE DE HOJE **NÃO** É NOSSA, E ESTE ARQUIVO NÃO A TOCA
#    `/var/lib/aurora/night-light-temp` = 3500. Quem esquenta a tela dela hoje é
#    um patch BINÁRIO da Aurora dentro do shader do `cosmic-comp`. Aposentá-lo é
#    a etapa 4 do plano, de outro dono. Enquanto ela viver, os dois convivem: o
#    night light some da tela quando a Aurora for travada, não quando este script
#    escrever. É por isso que o `estado` mostra os dois lado a lado — sem isso,
#    "a tela está quente" viraria prova de que este script funcionou, e não é.
#
# 4. RON ACEITA `0` ONDE ESPERA f32 — conferido em `ron-0.11.0/src/parse.rs:852`
#    (`T::parse(&f)` = `f32::from_str`), que é a versão que o `Cargo.lock` do
#    `cosmic-comp` pina. Mesmo assim este script escreve SEMPRE com casa decimal
#    (`0.00`, `0.35`): custa nada e tira uma ambiguidade do caminho.
#
# ============================================================================
# O CONTRATO DAS CHAVES: DOIS NÍVEIS, E ELES NÃO SIGNIFICAM A MESMA COISA
# ============================================================================
#
#   LEITURA_AGENDA (meow.conf)          responde "o MeowSystem PODE agendar?"
#     vazio  o modo de leitura é dela e mais ninguém. Nada é lido, nada é
#            escrito, o `conferir` devolve 0 sem olhar. É o mesmo contrato do
#            RELOGIO_SEGUNDOS e do JANELAS_TILING.
#     nao    DESLIGAR TEM DE DESLIGAR: os dois números voltam a 0 e o
#            `install.sh` desarma o timer. Não é "deixar de escrever" — é apagar
#            o efeito, do jeito que o `WALLPAPER_NOITE="nao"` apaga as pastas
#            derivadas em vez de deixá-las paradas parecendo ligadas.
#     sim    o agendamento vale. O HORÁRIO, daqui para baixo, é do applet.
#
#   leitura_agenda (cosmic-config, o applet do painel)   "agende AGORA?"
#     false  ela desligou o "Agendar" pela interface: os sliders mandam, e este
#            script não escreve NADA — nem 0. Devolve 4, que o doctor pinta como
#            `--` ("escolha dela"). Zerar aqui seria desfazer, às 07:00, a
#            temperatura que ela acabou de arrastar às 06:58.
#     true   (ou ausente) o relógio manda.
#
# O HORÁRIO MORA NO APPLET — DECISÃO DELA, 29/08/2026
#   Ela pediu para escolher a faixa pela interface. Então a fonte da verdade é
#   `leitura_hora_inicio` / `leitura_hora_fim` em `com.system76.CosmicComp/v1`,
#   as MESMAS chaves que o applet grava. Uma fonte só, em vez de duas que podem
#   divergir em silêncio.
#
#   O APPLET EXISTE DESDE 30/08/2026 (src/applets/leitura), MAS AS CHAVES SÓ
#   NASCEM QUANDO ELA MEXE NO HORÁRIO. O applet lê o disco no arranque e só
#   ESCREVE o que ela muda — instalá-lo não cria `leitura_hora_inicio` nem
#   `leitura_hora_fim`. Então "sem applet" e "applet instalado e nunca tocado"
#   são o MESMO estado para este arquivo, e nos dois ele cai no padrão declarado
#   no `meow.conf.exemplo` (LEITURA_HORARIO_INICIO/FIM) — e DIZ que está caindo
#   nele, em vez de fingir que leu. A frase aparece no `conferir` e no `estado`;
#   no `aplicar` ela é `meow_info`, que o `LOG_NIVEL=silencioso` da unidade
#   systemd cala, senão seriam 1440 linhas por dia dizendo a mesma coisa.
#
#   Formato aceito nas duas chaves do applet: `"18:00"` (string RON, com ou sem
#   aspas) e o inteiro de minutos desde a meia-noite (`1080`). MEDIDO em
#   30/08/2026: o applet grava a PRIMEIRA forma — o campo é `String` e o
#   `cosmic_config` serializa com aspas, que o `_leitura_cru` apara. Os dois
#   formatos continuam aceitos de propósito: é ela quem pode abrir o arquivo e
#   escrever `1080` à mão, e recusar isso seria recusar por nada.
#
# A JANELA DA NOITE É A MESMA DO CARROSSEL, PALAVRA POR PALAVRA
#   Copiada do `e_noite()` do `wallpaper.sh:637`: com `início > fim` a noite é
#   "depois do início OU antes do fim" (é o caso normal, 18:00–07:00, que
#   atravessa a meia-noite); com `início == fim` é noite o dia inteiro. A máquina
#   não pode ter duas definições de noite — se um dia esta regra mudar lá, tem de
#   mudar aqui junto, e é por isso que a frase está repetida em vez de resumida.
#
# SECA OU RAMPA: A DECISÃO É DELA, E AS DUAS ESTÃO AQUI (LEITURA_RAMPA_MIN)
#   0 (padrão)  virada SECA: às 18:00 o degrau salta de uma vez.
#   N > 0       rampa de N minutos, um passo por minuto, DEPOIS da hora — às
#               18:00 começa a esquentar e chega ao valor cheio às 18:00+N.
#
#   A rampa vai DEPOIS da hora, nunca antes, e isso é decisão de desenho: "ligar
#   às 18:00" não pode significar "às 17:30 a tela já mexeu". Quem pede um
#   horário está pedindo que nada aconteça antes dele.
#
#   Na rampa a temperatura interpola a partir de 6500K — o neutro, que é o topo
#   da faixa que ela escolheu em 29/08 — até o alvo. E quando a fração chega a
#   zero escreve-se `0`, NÃO `6500`: com 6500 o passe do shader continuaria
#   ligado fazendo uma multiplicação neutra por quadro, porque o `is_noop()` da
#   etapa 1 exige `== 0` para pular o passe.
#
# POR QUE O TIMER BATE DE MINUTO EM MINUTO, E NÃO UM `OnCalendar` POR HORÁRIO
#   Porque o horário mudou de dono. Um `OnCalendar=18:00` cravado na unidade era
#   a resposta certa enquanto o horário morava no `meow.conf` — mas ele mora no
#   applet desde 29/08, e ela pode arrastá-lo a qualquer segundo. Uma unidade com
#   a hora antiga não dá erro: ela liga a tela na hora errada, calada, que é o
#   modo de falha que este projeto mais documenta ter cometido.
#
#   O preço foi medido, e é pequeno: um tique lê CINCO arquivos de poucos bytes e
#   quase sempre não escreve nada. Ver o `AccuracySec` da unidade — o systemd
#   ainda funde esses despertares com os dos outros timers.
#
#   E é este desenho que faz a promessa do plano ser verdade: trocar entre seca e
#   rampa é UMA palavra no `meow.conf`, sem `daemon-reload`, sem rearmar unidade,
#   sem tocar em arquivo de systemd. Com dois timers seria uma palavra e um
#   `./install.sh`.
#
# USO
#   leitura.sh aplicar    põe o degrau que o relógio pede (idempotente)
#   leitura.sh conferir   0 conforme · 1 divergente · 2 erro · 3 sem assunto
#                         · 4 escolha dela (o applet desligou o "Agendar")
#   leitura.sh estado     diagnóstico: que degrau o relógio pede AGORA, o que
#                         está no disco, quem manda no horário, e se o
#                         compositor já sabe ler os dois números
#   leitura.sh remover    zera os dois números e desarma o timer
#   leitura.sh tique      sinônimo de `aplicar`, o nome que o plano usou
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# VAZIO = NÃO TOCA. É o contrato inteiro deste arquivo; ver o cabeçalho.
LEITURA_AGENDA="${LEITURA_AGENDA:-}"
# Os padrões abaixo só valem quando a chave do applet não existe. Estão aqui E no
# meow.conf.exemplo, com o mesmo valor, de propósito: o exemplo é o que ela lê, e
# este é o que vale numa máquina cujo conf ainda não tem a linha.
LEITURA_HORARIO_INICIO="${LEITURA_HORARIO_INICIO:-18:00}"
LEITURA_HORARIO_FIM="${LEITURA_HORARIO_FIM:-07:00}"
LEITURA_TEMPERATURA="${LEITURA_TEMPERATURA:-3500}"
LEITURA_TEXTURA="${LEITURA_TEXTURA:-0.35}"
LEITURA_RAMPA_MIN="${LEITURA_RAMPA_MIN:-0}"

LEITURA_BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}/com.system76.CosmicComp/v1"
LEITURA_K_TEMP="$LEITURA_BASE/leitura_temperatura"
LEITURA_K_TEXT="$LEITURA_BASE/leitura_textura"
LEITURA_K_AGENDA="$LEITURA_BASE/leitura_agenda"
LEITURA_K_INI="$LEITURA_BASE/leitura_hora_inicio"
LEITURA_K_FIM="$LEITURA_BASE/leitura_hora_fim"

# As três peças do applet (etapa 3, 30/08/2026). Só LIDAS aqui: quem as instala
# e confere é o `scripts/leitura_build.sh`, e o `plugins_wings` não é escrito por
# script nenhum deste projeto (docs/FRONTEIRA.md).
LEITURA_APPLET_ID="com.meowsystem.AppletLeitura"
LEITURA_APPLET_BIN="$HOME/.local/bin/meow-applet-leitura"
LEITURA_APPLET_SOMBRA="${XDG_DATA_HOME:-$HOME/.local/share}/applications/$LEITURA_APPLET_ID.desktop"
LEITURA_APPLET_ASA="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings"

LEITURA_COMP="/usr/bin/cosmic-comp"
LEITURA_MARCADOR="AURORA-READING-MODE"
LEITURA_NIGHTLIGHT="/var/lib/aurora/night-light-temp"
LEITURA_TIMER="meow-leitura.timer"

# 6500K é o NEUTRO e o topo da faixa (decisão dela, 29/08/2026: o slider vai de
# 1000K a 6500K, e o topo é o modo desligado). 1000K é o fundo da tabela
# WHITEPOINTS do redshift que o aurora-night-light.py já carrega.
LEITURA_NEUTRO=6500
LEITURA_PISO=1000
# 4 = "divergente por escolha dela". O `rotulo_rc` do bin/meow o pinta `--`,
# igual ao 3, porque a leitura é a mesma para quem olha: não há nada que o
# auto-reparo deva fazer aqui.
LEITURA_DELA=4

# --- leitura crua de uma chave do cosmic-config -----------------------------
# Apara espaço, tira as aspas de string RON, apara de novo. Devolve 1 quando o
# arquivo não existe ou está vazio — que é o mesmo caso para quem chama: não há
# valor a considerar.
_leitura_cru() {
  local arq="$1" v
  [ -f "$arq" ] || return 1
  v="$(cat "$arq" 2>/dev/null)" || return 1
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  v="${v#\"}"; v="${v%\"}"
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
  [ -n "$v" ]
}

# "18:00" -> 1080. Também aceita o inteiro de minutos: o applet grava `"18:00"`
# (conferido em 30/08/2026), mas quem edita o arquivo à mão pode escrever 1080, e
# recusar isso seria recusar por nada. Falha (1) em qualquer outra coisa.
_leitura_minutos() {
  local v="$1" h m
  case "$v" in
    [0-9][0-9]:[0-9][0-9]|[0-9]:[0-9][0-9])
      h="${v%%:*}"; m="${v##*:}"
      [ "$((10#$h))" -le 23 ] && [ "$((10#$m))" -le 59 ] || return 1
      printf '%s' "$(( 10#$h * 60 + 10#$m ))" ;;
    ""|*[!0-9]*) return 1 ;;
    *)
      [ "$((10#$v))" -le 1439 ] || return 1
      printf '%s' "$((10#$v))" ;;
  esac
}

_leitura_hhmm() { printf '%02d:%02d' "$(( $1 / 60 ))" "$(( $1 % 60 ))"; }

# --- quem manda no horário --------------------------------------------------
LEITURA_FONTE=""        # applet | padrao
LEITURA_INI=0
LEITURA_FIM=0
LEITURA_APPLET_DIZ=""   # "" (ausente) | sim | nao

_leitura_resolver_agenda() {
  local a b ma mb
  LEITURA_FONTE="padrao"
  if a="$(_leitura_cru "$LEITURA_K_INI")" && b="$(_leitura_cru "$LEITURA_K_FIM")" \
     && ma="$(_leitura_minutos "$a")" && mb="$(_leitura_minutos "$b")"; then
    LEITURA_FONTE="applet"; LEITURA_INI="$ma"; LEITURA_FIM="$mb"
  else
    LEITURA_INI="$(_leitura_minutos "$LEITURA_HORARIO_INICIO")" || {
      meow_erro "LEITURA_HORARIO_INICIO='$LEITURA_HORARIO_INICIO' não é HH:MM"
      return "$MEOW_ERRO"; }
    LEITURA_FIM="$(_leitura_minutos "$LEITURA_HORARIO_FIM")" || {
      meow_erro "LEITURA_HORARIO_FIM='$LEITURA_HORARIO_FIM' não é HH:MM"
      return "$MEOW_ERRO"; }
  fi

  LEITURA_APPLET_DIZ=""
  if a="$(_leitura_cru "$LEITURA_K_AGENDA")"; then
    case "$a" in
      # O applet declara o campo como `bool` e grava `true`/`false` pelados —
      # conferido em 30/08/2026, em src/applets/leitura/src/main.rs. As formas
      # `Some(...)` ficam porque custam duas linhas e cobrem o dia em que o
      # campo virar `Option<bool>` (aí o RON no disco vem embrulhado). Os
      # parênteses são ESCAPADOS: sem aspas, o bash lê `(` como início de
      # subshell dentro do `case` e o arquivo nem parseia.
      true|"Some(true)")   LEITURA_APPLET_DIZ="sim" ;;
      false|"Some(false)") LEITURA_APPLET_DIZ="nao" ;;
    esac
  fi
  return "$MEOW_OK"
}

# --- os alvos, e a conta da rampa -------------------------------------------
# Ecoa "<temperatura> <textura> <fração> <fase>". A conta inteira mora num único
# `awk` porque bash não faz ponto flutuante, e porque partir a interpolação em
# dois lugares é como se ganha duas contas que discordam.
LEITURA_ALVO_T=0
LEITURA_ALVO_X="0.00"
LEITURA_ALVO_F="0.00"
LEITURA_FASE=""
LEITURA_AGORA=0

_leitura_alvo_agora() {
  local t="$LEITURA_TEMPERATURA" x="$LEITURA_TEXTURA" n="$LEITURA_RAMPA_MIN" saida
  LEITURA_AGORA="$(_leitura_minutos "$(date +%H:%M)")" || return "$MEOW_ERRO"

  # `LC_ALL=C` NÃO É ZELO, É O PRIMEIRO DEFEITO QUE ESTE ARQUIVO TEVE (30/08/2026)
  #   A locale desta máquina é pt_BR, e o `printf "%.2f"` do awk obedece ao
  #   LC_NUMERIC: a primeira execução gravou `0,35` em `leitura_textura`. Um f32
  #   de RON com vírgula não é "quase certo" — é erro de parse, e o cosmic-config
  #   devolve o Default (0.0) sem uma linha de aviso em lugar nenhum. Ou seja: a
  #   textura ficaria eternamente desligada, e a tela não teria como acusar.
  #   O `C` vale também para a LEITURA dos números: o awk converte string em
  #   número pela mesma locale, então um `0,35` vindo do disco viraria 0.
  saida="$(LC_ALL=C awk -v ini="$LEITURA_INI" -v fim="$LEITURA_FIM" -v n="$n" \
               -v agora="$LEITURA_AGORA" -v alvo_t="$t" -v alvo_x="$x" \
               -v neutro="$LEITURA_NEUTRO" -v piso="$LEITURA_PISO" 'BEGIN{
    # As três linhas abaixo são o e_noite() do wallpaper.sh:637, e a igualdade
    # entre os dois arquivos é o que impede a máquina de ter duas noites.
    if      (ini == fim) noite = 1;
    else if (ini >  fim) noite = (agora >= ini || agora <  fim);
    else                 noite = (agora >= ini && agora <  fim);

    # Com ini == fim é noite o dia inteiro: não existe borda de onde a rampa
    # partisse, e inventar uma faria a tela saltar para o neutro uma vez por dia.
    if (n <= 0 || ini == fim) {
      f = noite ? 1 : 0;
      fase = noite ? "noite" : "dia";
    } else {
      dini = (agora - ini + 1440) % 1440;
      dfim = (agora - fim + 1440) % 1440;
      if (noite) {
        if (dini < n) { f = dini / n;     fase = "esquentando" }
        else          { f = 1;            fase = "noite" }
      } else {
        if (dfim < n) { f = 1 - dfim / n; fase = "esfriando" }
        else          { f = 0;            fase = "dia" }
      }
    }

    # A temperatura sai do neutro e caminha para o alvo. Fora da faixa útil o
    # valor é aparado em silêncio aqui; quem AVISA é o `conferir`, uma vez por
    # dia, e não o timer, 1440 vezes.
    if (alvo_t < piso)   alvo_t = piso;
    if (alvo_t > neutro) alvo_t = neutro;
    if (alvo_x < 0)      alvo_x = 0;
    if (alvo_x > 1)      alvo_x = 1;

    temp = int(neutro - f * (neutro - alvo_t) + 0.5);
    # `0`, e nunca `6500`: o is_noop() da etapa 1 exige == 0 para PULAR o passe
    # do shader. Escrever o neutro deixaria a multiplicação neutra rodando por
    # quadro, para sempre, sem nada na tela para acusar.
    if (f <= 0 || temp >= neutro) temp = 0;

    tex = f * alvo_x;
    if (tex < 0.005) tex = 0;

    printf "%d %.2f %.2f %s\n", temp, tex, f, fase;
  }' 2>/dev/null)" || return "$MEOW_ERRO"

  [ -n "$saida" ] || return "$MEOW_ERRO"
  read -r LEITURA_ALVO_T LEITURA_ALVO_X LEITURA_ALVO_F LEITURA_FASE <<< "$saida"
  return "$MEOW_OK"
}

# 0 = os dois são o mesmo número até a segunda casa. Existe por causa de um caso
# concreto: o applet grava `0.4` e este script grava `0.40`. Um `[ "$a" = "$b" ]`
# — e o próprio `meow_escrever`, que compara por conteúdo — veria divergência
# eterna e reescreveria a chave a cada minuto, acordando o compositor de graça.
_leitura_mesmo_numero() {
  local a="${1:-}" b="${2:-}"
  case "$a" in ""|*[!0-9.+-]*) return 1 ;; esac
  case "$b" in ""|*[!0-9.+-]*) return 1 ;; esac
  # `LC_ALL=C` pelo mesmo motivo do `_leitura_alvo_agora`: em pt_BR o awk lê
  # `0.35` como 0 e `0,35` como 0,35 — e a comparação diria "diferente" para
  # sempre, reescrevendo a chave a cada minuto.
  LC_ALL=C awk -v a="$a" -v b="$b" 'BEGIN{ exit ((a-b) < 0.005 && (b-a) < 0.005) ? 0 : 1 }'
}

_leitura_no_disco() {
  LEITURA_DISCO_T="$(_leitura_cru "$LEITURA_K_TEMP")" || LEITURA_DISCO_T=""
  LEITURA_DISCO_X="$(_leitura_cru "$LEITURA_K_TEXT")" || LEITURA_DISCO_X=""
}
LEITURA_DISCO_T=""
LEITURA_DISCO_X=""

# Grava os dois números, e só o que MUDOU. Devolve 0 (já estava assim), 1
# (escreveu, ou escreveria no seco) ou 2.
_leitura_gravar() {
  local temp="$1" text="$2" motivo="$3" mudou=0 r
  _leitura_no_disco

  if ! _leitura_mesmo_numero "$LEITURA_DISCO_T" "$temp"; then
    meow_escrever "$LEITURA_K_TEMP" "$temp" 644; r=$?
    case "$r" in
      2) meow_erro "não consegui gravar $LEITURA_K_TEMP"; return "$MEOW_ERRO" ;;
      1) mudou=1 ;;
    esac
  fi
  if ! _leitura_mesmo_numero "$LEITURA_DISCO_X" "$text"; then
    meow_escrever "$LEITURA_K_TEXT" "$text" 644; r=$?
    case "$r" in
      2) meow_erro "não consegui gravar $LEITURA_K_TEXT"; return "$MEOW_ERRO" ;;
      1) mudou=1 ;;
    esac
  fi

  if [ "$mudou" = "1" ]; then
    if meow_seco; then
      meow_muda "gravaria temperatura=$temp textura=$text ($motivo)"
    else
      meow_muda "$motivo: temperatura=${temp}K textura=$text"
      # O registro no meow.log é condicionado ao que MUDOU, e não ao tique. Um
      # `meow_registrar` incondicional aqui daria 1440 linhas por dia num arquivo
      # que o `meow log` mostra — o log viraria só isto.
      meow_registrar "leitura.sh temp=$temp textura=$text fase=${LEITURA_FASE:-$motivo}"
    fi
    return "$MEOW_DIVERGENTE"
  fi
  return "$MEOW_OK"
}

# A frase de "de onde veio o horário". `meow_info` de propósito: o
# `LOG_NIVEL=silencioso` da unidade systemd a cala, e ela reaparece inteira
# quando alguém roda o comando na mão, no `conferir` e no `estado`.
_leitura_dizer_fonte() {
  local diz="${1:-info}"
  local janela; janela="das $(_leitura_hhmm "$LEITURA_INI") às $(_leitura_hhmm "$LEITURA_FIM")"
  if [ "$LEITURA_FONTE" = "applet" ]; then
    "meow_$diz" "horário do applet (leitura_hora_inicio/fim): $janela"
  else
    # "não gravou", e não "não existe": desde 30/08/2026 o applet existe, e o
    # que falta é ela ter mexido no horário — ele só escreve o que ela muda.
    # Dizer "não existe" mandaria procurar um binário que está instalado.
    "meow_$diz" "o applet ainda não gravou horário — usando o PADRÃO do meow.conf: $janela"
  fi
}

# --- aplicar ----------------------------------------------------------------
cmd_aplicar() {
  if [ -z "$LEITURA_AGENDA" ]; then
    meow_info "LEITURA_AGENDA vazio — o modo de leitura é seu; não escrevo nada"
    return "$MEOW_OK"
  fi
  case "$LEITURA_AGENDA" in
    sim|nao|não) ;;
    *) meow_erro "LEITURA_AGENDA='$LEITURA_AGENDA' — esperado sim, nao ou vazio"
       return "$MEOW_ERRO" ;;
  esac

  # DESLIGAR TEM DE DESLIGAR: os números voltam a 0. Quem desarma o timer é o
  # `install.sh` (etapa_leitura) e o `remover` daqui — não este caminho, porque
  # um `aplicar` disparado PELO timer que desarma o próprio timer é a receita de
  # unidade que morre no meio de si mesma.
  if [ "$LEITURA_AGENDA" != "sim" ]; then
    LEITURA_FASE="desligado"
    _leitura_gravar 0 "0.00" "LEITURA_AGENDA=\"$LEITURA_AGENDA\" — modo de leitura desligado"
    local rc=$?
    [ "$rc" = "$MEOW_OK" ] && meow_ok "modo de leitura já estava desligado (0 / 0.00)"
    return "$rc"
  fi

  _leitura_resolver_agenda || return $?

  if [ "$LEITURA_APPLET_DIZ" = "nao" ]; then
    meow_info "o applet diz 'Agendar: desligado' — os sliders mandam, não escrevo nada"
    return "$LEITURA_DELA"
  fi

  _leitura_alvo_agora || { meow_erro "não consegui calcular o degrau da hora"; return "$MEOW_ERRO"; }
  _leitura_dizer_fonte info

  _leitura_gravar "$LEITURA_ALVO_T" "$LEITURA_ALVO_X" "$LEITURA_FASE"
  local rc=$?
  if [ "$rc" = "$MEOW_OK" ]; then
    meow_ok "modo de leitura já no degrau da hora ($LEITURA_FASE: ${LEITURA_ALVO_T}K / $LEITURA_ALVO_X)"
  fi
  return "$rc"
}

# --- conferir (leitura pura; é o que o doctor chama) ------------------------
cmd_conferir() {
  if [ -z "$LEITURA_AGENDA" ]; then
    meow_pula "LEITURA_AGENDA vazio — nada a conferir (o modo de leitura é seu)"
    return "$MEOW_OK"
  fi
  case "$LEITURA_AGENDA" in
    sim|nao|não) ;;
    *) meow_erro "LEITURA_AGENDA='$LEITURA_AGENDA' — esperado sim, nao ou vazio"
       return "$MEOW_ERRO" ;;
  esac

  local alvo_t alvo_x
  if [ "$LEITURA_AGENDA" != "sim" ]; then
    alvo_t=0; alvo_x="0.00"; LEITURA_FASE="desligado"
  else
    _leitura_resolver_agenda || return $?
    if [ "$LEITURA_APPLET_DIZ" = "nao" ]; then
      meow_pula "o applet desligou o 'Agendar' — o degrau é o que você arrastou"
      return "$LEITURA_DELA"
    fi
    _leitura_alvo_agora || { meow_erro "não consegui calcular o degrau da hora"; return "$MEOW_ERRO"; }
    alvo_t="$LEITURA_ALVO_T"; alvo_x="$LEITURA_ALVO_X"

    # O aviso de valor fora da faixa mora AQUI, e não no `aplicar`: o `conferir`
    # roda uma vez por dia pelo doctor, e o `aplicar` roda 1440. Um aviso que
    # aparece 1440 vezes por dia é um aviso que se aprende a ignorar.
    case "$LEITURA_TEMPERATURA" in
      ""|*[!0-9]*) meow_aviso "LEITURA_TEMPERATURA='$LEITURA_TEMPERATURA' não é um inteiro — tratada como ${LEITURA_NEUTRO}K (desligado)" ;;
      *) if [ "$LEITURA_TEMPERATURA" -lt "$LEITURA_PISO" ] || [ "$LEITURA_TEMPERATURA" -gt "$LEITURA_NEUTRO" ]; then
           meow_aviso "LEITURA_TEMPERATURA=$LEITURA_TEMPERATURA está fora de ${LEITURA_PISO}–${LEITURA_NEUTRO}K — aparada"
         fi ;;
    esac
    _leitura_dizer_fonte pula
  fi

  _leitura_no_disco
  local ok_t=1 ok_x=1
  _leitura_mesmo_numero "$LEITURA_DISCO_T" "$alvo_t" && ok_t=0
  _leitura_mesmo_numero "$LEITURA_DISCO_X" "$alvo_x" && ok_x=0

  if [ "$ok_t" = "0" ] && [ "$ok_x" = "0" ]; then
    meow_ok "modo de leitura conforme ($LEITURA_FASE: ${alvo_t}K / $alvo_x)"
    return "$MEOW_OK"
  fi
  meow_muda "modo de leitura divergente ($LEITURA_FASE): disco=${LEITURA_DISCO_T:-<ausente>}K/${LEITURA_DISCO_X:-<ausente>}, a hora pede ${alvo_t}K/$alvo_x"
  meow_aviso "os dois sliders do applet escrevem NAS MESMAS chaves."
  meow_aviso "se foi você quem arrastou, desligue o 'Agendar' no applet — ou"
  meow_aviso "esvazie LEITURA_AGENDA no meow.conf. Senão o timer devolve o valor"
  meow_aviso "da hora no próximo minuto."
  return "$MEOW_DIVERGENTE"
}

# --- estado (read-only, e é o comando de responder "por quê?") --------------
_leitura_col() { printf '%-22s' "$1"; }

cmd_estado() {
  meow_info "$(_leitura_col "meow.conf") LEITURA_AGENDA=\"${LEITURA_AGENDA:-}\" rampa=${LEITURA_RAMPA_MIN}min"
  meow_info "$(_leitura_col "alvo do conf") ${LEITURA_TEMPERATURA}K / ${LEITURA_TEXTURA}"

  if [ -z "$LEITURA_AGENDA" ]; then
    meow_pula "LEITURA_AGENDA vazio — o MeowSystem não agenda nada; segue o diagnóstico"
  fi

  if _leitura_resolver_agenda; then
    _leitura_dizer_fonte info
    case "$LEITURA_APPLET_DIZ" in
      sim) meow_info "quem manda agora: o relógio (o applet quer o agendamento)" ;;
      nao) meow_pula "quem manda agora: OS SLIDERS — o applet desligou o 'Agendar'" ;;
      *)   meow_pula "quem manda agora: o relógio (o applet ainda não gravou o 'Agendar')" ;;
    esac
    if _leitura_alvo_agora; then
      meow_info "$(_leitura_col "agora são")$(_leitura_hhmm "$LEITURA_AGORA") — fase: $LEITURA_FASE (fração $LEITURA_ALVO_F)"
      meow_info "$(_leitura_col "o relógio pede")temperatura=${LEITURA_ALVO_T}  textura=${LEITURA_ALVO_X}"
    fi
  fi

  _leitura_no_disco
  local k v
  for k in leitura_temperatura leitura_textura leitura_agenda leitura_hora_inicio leitura_hora_fim; do
    if v="$(_leitura_cru "$LEITURA_BASE/$k")"; then
      meow_info "$(_leitura_col "$k")= $v"
    else
      meow_pula "$(_leitura_col "$k")= <ausente>"
    fi
  done

  # O APPLET, EM TRÊS PEÇAS QUE FALHAM SEPARADO (30/08/2026)
  #   Binário, sombra `.desktop` e a linha no `plugins_wings` da topbar. Cada uma
  #   some por um motivo diferente, então mostrar as três em linhas separadas é o
  #   que troca "o applet sumiu" por "sumiu ESTA peça". A conferência de verdade
  #   é do `scripts/leitura_build.sh --conferir`; aqui é diagnóstico, e por isso
  #   nada acende divergência.
  #
  #   NENHUMA DAS TRÊS PRECISA DE LOGOUT — e isso contraria o que este projeto
  #   vinha repetindo. MEDIDO em 30/08/2026, 05:43: o `cosmic-panel` mantém um
  #   watch de inotify no diretório `CosmicPanel.Panel/v1` (visto em
  #   `/proc/<pid>/fdinfo`, inode do diretório), e `plugins_wings` está na lista
  #   `must_recreate` do `space_container.rs` do painel. Escrever a linha
  #   RECRIOU o espaço da topbar na hora: o processo do painel manteve o mesmo
  #   PID e TODOS os applets renasceram com PIDs novos, o nosso incluído.
  #   Quem ainda espera o logout é o SHADER — o `cosmic-comp` da sessão.
  if [ -x "$LEITURA_APPLET_BIN" ]; then
    meow_ok "$(_leitura_col "applet: binário")$LEITURA_APPLET_BIN"
  else
    meow_pula "$(_leitura_col "applet: binário")ausente — LEITURA_COMPILAR=1 ./scripts/leitura_build.sh"
  fi
  if [ -f "$LEITURA_APPLET_SOMBRA" ]; then
    meow_ok "$(_leitura_col "applet: .desktop")$LEITURA_APPLET_SOMBRA"
  else
    meow_pula "$(_leitura_col "applet: .desktop")ausente — o painel não tem o que abrir"
  fi
  if grep -qs "\"$LEITURA_APPLET_ID\"" "$LEITURA_APPLET_ASA"; then
    meow_ok "$(_leitura_col "applet: na topbar")citado no plugins_wings"
  else
    meow_pula "$(_leitura_col "applet: na topbar")NÃO citado no plugins_wings — acrescente \"$LEITURA_APPLET_ID\" à mão"
  fi

  # AS DUAS PERGUNTAS QUE NINGUÉM VÊ HOJE, E QUE SÃO DIFERENTES: o binário do
  # DISCO sabe ler os dois números? E o processo que está desenhando a tela dela
  # AGORA sabe? Um build feito e uma sessão que não relogou são um estado normal,
  # e é justamente esse estado que faz "escrevi a chave e nada aconteceu".
  if [ -r "$LEITURA_COMP" ]; then
    if grep -aqs "$LEITURA_MARCADOR" "$LEITURA_COMP"; then
      meow_ok "$(_leitura_col "cosmic-comp no disco")sabe ler leitura_* ($LEITURA_MARCADOR presente)"
    else
      meow_pula "$(_leitura_col "cosmic-comp no disco")NÃO sabe ler leitura_* — falta a etapa 1 (o patch do compositor)"
    fi
  fi
  local pid; pid="$(pgrep -x cosmic-comp 2>/dev/null | head -1)"
  if [ -n "$pid" ]; then
    if grep -aqs "$LEITURA_MARCADOR" "/proc/$pid/exe"; then
      meow_ok "$(_leitura_col "a sessão viva")roda um cosmic-comp que sabe ler (PID $pid)"
    else
      meow_pula "$(_leitura_col "a sessão viva")roda um cosmic-comp SEM o modo de leitura (PID $pid)"
      meow_info "  escrever a chave hoje é inofensivo e passa a valer no PRÓXIMO LOGIN."
    fi
  else
    meow_aviso "cosmic-comp não está rodando — nada desenha esta tela"
  fi

  # A luz quente de hoje não é nossa. Sem esta linha, "a tela está quente"
  # viraria prova de que este script funcionou — e não é.
  if [ -r "$LEITURA_NIGHTLIGHT" ]; then
    meow_info "$(_leitura_col "night light da Aurora")$(cat "$LEITURA_NIGHTLIGHT" 2>/dev/null)K — patch BINÁRIO, outro dono; aposentá-lo é a etapa 4"
  fi

  if meow_tem systemctl; then
    local ativo; ativo="$(systemctl --user is-active "$LEITURA_TIMER" 2>/dev/null)"
    case "$ativo" in
      active) meow_ok "$(_leitura_col "$LEITURA_TIMER")armado — próximo tique em menos de 1 min" ;;
      *)      meow_pula "$(_leitura_col "$LEITURA_TIMER")${ativo:-ausente} — ninguém vai virar o degrau sozinho" ;;
    esac
  fi
  return "$MEOW_OK"
}

# --- remover ----------------------------------------------------------------
# Zera os dois números E desarma o timer. As duas coisas, porque só zerar deixa o
# relógio de pé para repor o valor no minuto seguinte — o recurso pareceria
# desligado por um minuto e voltaria sozinho, que é pior que não desligar.
#
# NÃO APAGA os arquivos: `0` é conferível e é exatamente o que o Default do
# compositor vale (etapa 1, EDIÇÃO 5). É a mesma lição do `relogio.sh`, medida em
# 25/08/2026 — apagar o arquivo é um jeito de reverter que não se pode conferir.
cmd_remover() {
  LEITURA_FASE="desligado"
  _leitura_gravar 0 "0.00" "modo de leitura removido"
  local rc=$?
  [ "$rc" = "$MEOW_OK" ] && meow_ok "os dois números já estavam em 0"

  if meow_tem systemctl && [ -d "/run/user/$(id -u)/systemd" ]; then
    if meow_seco; then
      meow_muda "desarmaria o $LEITURA_TIMER"
    elif [ "$(systemctl --user is-enabled "$LEITURA_TIMER" 2>/dev/null)" = "enabled" ] ||
         [ "$(systemctl --user is-active  "$LEITURA_TIMER" 2>/dev/null)" = "active" ]; then
      if systemctl --user disable --now "$LEITURA_TIMER" >/dev/null 2>&1; then
        meow_muda "$LEITURA_TIMER desarmado"
      else
        meow_aviso "não consegui desarmar o $LEITURA_TIMER"
      fi
      rc="$MEOW_DIVERGENTE"
    fi
  fi
  meow_seco || meow_registrar "leitura.sh remover rc=$rc"
  return "$rc"
}

case "${1:-aplicar}" in
  aplicar|tique) cmd_aplicar ;;
  conferir)      cmd_conferir ;;
  estado)        cmd_estado ;;
  remover)       cmd_remover ;;
  *) meow_erro "uso: leitura.sh {aplicar|conferir|estado|remover}"; exit "$MEOW_ERRO" ;;
esac

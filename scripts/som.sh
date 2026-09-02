#!/usr/bin/env bash
# som.sh — o ÚNICO som de evento que o COSMIC realmente toca nesta máquina.
#
# LEIA ISTO ANTES DE SONHAR COM UM "TEMA DE SOM CATPPUCCIN"
#   Ele não existe, e não é por falta de arquivo: é porque o COSMIC quase não
#   toca som nenhum. O alcance inteiro desta feature é UM arquivo.
#
#   Quem toca é o `cosmic-osd`, e só ele. Medido em 2026-08-04 varrendo os 41
#   binários `/usr/bin/cosmic-*`: `pw-play` aparece em exatamente dois deles
#   (`cosmic-osd` e `cosmic-settings-daemon`) e `canberra` em nenhum — os 3
#   acertos de "canberra" no `cosmic-initial-setup` são a CIDADE Canberra, da
#   lista de fusos horários. O COSMIC não usa libcanberra: ele faz fork de
#   `pw-play --media-role Notification`.
#
#   CUIDADO COM UMA CONCLUSÃO FÁCIL E ERRADA (já foi tirada aqui): o
#   `cosmic-settings-daemon` NÃO toca o som de volume. O binário dele tem ZERO
#   ocorrências de `audio-volume-change`, de `stereo` e de `.oga`. O `pw-play`
#   dele serve só aos sons de ENERGIA (`power-plug`, `power-unplug`,
#   `power-unplug-battery-low`), que ele procura em `/usr/share/sounds/Pop/` —
#   caminho de sistema cravado, sem XDG, ou seja, nem dava para sobrescrever.
#   E eles nunca vão tocar aqui: esta é máquina de mesa, o único
#   `/sys/class/power_supply/*` é a bateria do controle DualSense.
#
#   O daemon importa por outro motivo: ele é o GATILHO da tecla. O
#   `system_actions` do COSMIC mapeia XF86AudioLowerVolume para
#   `busctl --user call com.system76.CosmicSettingsDaemon ... VolumeDown`. Com o
#   daemon morto a tecla não muda volume, logo o osd não tem o que anunciar e
#   nenhum som nasce — o que já foi lido como "o daemon é o tocador". Não é: ele
#   é o gatilho, e o osd é o tocador.
#
#   O `cosmic-notifications` NÃO TEM reprodutor de áudio: zero ocorrências de
#   canberra, pw-play, paplay, libpulse, gstreamer ou snd_pcm. Ele ANUNCIA a
#   capacidade "sound" no `GetCapabilities`, e mesmo assim
#   `notify-send -h string:sound-name:message` produz ZERO sink-inputs.
#   Notificação com som é impossível sem um daemon nosso.
#
# O QUE FOI PROVADO, E COMO (2026-08-04)
#   1. QUEM TOCA E QUAL ARQUIVO — sem inferência. Disparando o MESMO comando da
#      tecla e varrendo `/proc/*/cmdline` durante a janela, o argv capturado foi
#      literalmente:
#        pw-play --media-role Notification \
#                /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga
#
#   2. O ARQUIVO DO USUÁRIO GANHA. Com este script aplicado, o MESMO teste
#      capturou:
#        pw-play --media-role Notification \
#                /home/.../.local/share/sounds/freedesktop/stereo/audio-volume-change.oga
#      O código do osd é `xdg::BaseDirectories::with_prefix("sounds")
#      .find_data_file("freedesktop/stereo/audio-volume-change.oga")`, e o
#      `find_data_file` consulta o XDG_DATA_HOME antes do XDG_DATA_DIRS.
#
#   3. O SOM É DEBOUNCED EM 125 ms, e sons longos SE SOBREPÕEM. No fonte do osd:
#      `if now.duration_since(self.sink_last_playback) > Duration::from_millis(125)`.
#      Provado: plantando um arquivo de 2 s e disparando duas mudanças com 300 ms
#      de intervalo, `pactl list short sink-inputs` mostrou DOIS sink-inputs
#      coexistindo. É por isso que a duração aqui é de 85 ms e não pode crescer:
#      segurar a tecla de volume empilharia cópias de um som longo.
#
# AS DUAS ARMADILHAS QUE CUSTARIAM HORAS
#   A. O NOME DO TEMA É CRAVADO NO BINÁRIO. O osd procura literalmente
#      `sounds/freedesktop/stereo/audio-volume-change.oga`. Um tema chamado
#      `MeowSystem-Sounds` NUNCA seria lido, por mais correto que fosse o
#      `index.theme`, e o `gsettings org.gnome.desktop.sound theme-name` é
#      decorativo nesta máquina — ninguém o lê. Por isso instalamos DENTRO de um
#      `freedesktop` do usuário, que sombreia o do sistema sem apagá-lo.
#      Repare que isto é o INVERSO da regra dos ÍCONES (docs/COSMIC-THEMING.md
#      seção 2): lá, mesmo nome nos dois lugares faz `/usr/share` ofuscar o
#      usuário. Em SOM o usuário vence.
#
#      E é por isso que NÃO escrevemos `index.theme` nesse diretório. Sem ele,
#      quem um dia resolver o tema `freedesktop` pela especificação lê o
#      `index.theme` do sistema e só encontra no nosso diretório o único arquivo
#      que plantamos. Escrever um `index.theme` incompleto ali seria sequestrar
#      o tema inteiro em vez de um arquivo.
#
#   B. A EXTENSÃO `.oga` É MENTIRA, E ISSO NOS SALVA. Quem lê o arquivo é a
#      libsndfile, que detecta o formato pelo CONTEÚDO. Um WAV PCM salvo com nome
#      `.oga` toca normalmente (`file` diz "RIFF (little-endian) data, WAVE
#      audio, Microsoft PCM, 16 bit, stereo 48000 Hz"; `pw-play` sai com 0 e o
#      COSMIC o tocou pelo caminho real). Logo NÃO precisamos de ffmpeg, oggenc
#      nem sox: o som nasce da biblioteca padrão do Python.
#
# LICENÇA DOS SONS (regra do projeto: cada som tem a sua registrada)
#   O som que este script instala é GERADO AQUI, por síntese, pelo código logo
#   abaixo. É obra do próprio MeowSystem e o registramos como CC0-1.0. Nada é
#   baixado, então não há licença de terceiro para auditar. Registro auditável:
#   `assets/sons/CREDITOS.md` no repositório, e um `LICENCAS.txt` que o script
#   escreve ao lado do som instalado.
#
#   NÃO copie os `.oga` do sistema para dentro do nosso tema:
#     - freedesktop `audio-volume-change.oga` é CC-BY-SA-3.0 (Lucas McCallister,
#       /usr/share/doc/sound-theme-freedesktop/copyright). A 3.0 NÃO ganhou
#       compatibilidade com a GPL-3.0; só a CC-BY-SA 4.0 ganhou, e de mão única.
#     - Pop `action/audio-volume-change.oga` é CC-BY-SA-4.0 (Mads Rosendahl),
#       essa sim redistribuível sob GPL-3.0. Mesmo assim não serve: mede 0,35 s
#       (5x o de fábrica, empilha na tecla segurada, ver prova 3 acima) e é 10 dB
#       mais alto na média (`ffmpeg -af volumedetect`: mean -20,2 dB / max -4,0 dB
#       contra mean -30,4 dB / max -17,2 dB do de fábrica). Trocaria um blip por
#       um susto.
#
# USO
#   som.sh aplicar    instala o blip autoral (idempotente)
#   som.sh conferir   0 = igual · 1 = divergente · 3 = falta dependência
#   som.sh estado     diz qual arquivo o COSMIC vai tocar, e se o gatilho vive
#   som.sh ouvir      toca o que ESTÁ instalado, baixinho, sem mexer no volume
#   som.sh remover    volta ao som de fábrica do sistema
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# O nome do tema é imposto pelo binário do osd — não é escolha nossa.
SOM_TEMA="freedesktop"
SOM_RAIZ="$HOME/.local/share/sounds"
SOM_BASE="$SOM_RAIZ/$SOM_TEMA/stereo"
SOM_ALVO="$SOM_BASE/audio-volume-change.oga"
SOM_LICENCAS="$SOM_RAIZ/$SOM_TEMA/LICENCAS.txt"
SOM_SISTEMA="/usr/share/sounds/$SOM_TEMA/stereo/audio-volume-change.oga"

# DURAÇÃO: 85 ms. Não é gosto, é o debounce de 125 ms do osd (prova 3 do
# cabeçalho): passar disso faz o som se empilhar quando ela segura a tecla.
SOM_DURACAO="${SOM_DURACAO:-0.085}"
# GANHO: calibrado para casar a intensidade do arquivo de fábrica, medido com
# `ffmpeg -af volumedetect`. Alvo: max ≈ -17 dB, mean ≈ -30 dB. Assim a troca
# muda o TIMBRE e não o susto — ela não precisa reaprender o volume dela.
SOM_GANHO="${SOM_GANHO:-0.18}"

# --- o gerador: só biblioteca padrão, e DETERMINÍSTICO ----------------------
# Determinístico é o que torna `conferir` possível: geramos de novo e comparamos
# byte a byte com o que está instalado. Sem isso, toda checagem acusaria
# divergência e o auto-reparo entraria em ping-pong.
_som_gerar() {
  local destino="$1"
  python3 - "$destino" "$SOM_DURACAO" "$SOM_GANHO" <<'PY'
import math, struct, sys, wave

destino, dur, ganho = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
taxa = 48000
n = int(taxa * dur)
quadros = bytearray()
for i in range(n):
    t = i / taxa
    # Decaimento exponencial rápido: ataque seco, sem cauda arrastada.
    env = math.exp(-t * 46.0)
    # Rampas de 2 ms nas pontas: sem elas o corte estala no alto-falante.
    janela = min(1.0, i / 96.0) * min(1.0, (n - i) / 96.0)
    # Fundamental + quinta justa: sino curto, sem soar a alarme.
    s = 0.62 * math.sin(2 * math.pi * 880.0 * t)
    s += 0.28 * math.sin(2 * math.pi * 1320.0 * t)
    v = int(max(-1.0, min(1.0, s * env * janela * ganho)) * 32767)
    quadros += struct.pack("<hh", v, v)

with wave.open(destino, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(taxa)
    w.writeframes(bytes(quadros))
PY
}

_som_licencas_texto() {
  cat <<TXT
Sons instalados pelo MeowSystem — registro de licenças
======================================================
Gerado por scripts/som.sh. Não editar à mão.

arquivo : stereo/audio-volume-change.oga
origem  : sintetizado por scripts/som.sh (obra do próprio MeowSystem)
autoria : projeto MeowSystem
licença : CC0-1.0 (domínio público)
formato : WAV PCM 16 bit 48 kHz estéreo, com nome .oga de propósito — quem lê é
          a libsndfile, que detecta pelo conteúdo. É o único arquivo aqui.
nota    : nada foi baixado; o som nasce do código do script.

Este diretório NÃO tem index.theme, e isso é deliberado: assim ele sombreia um
único arquivo do tema freedesktop do sistema, e não o tema inteiro.

Os demais arquivos do tema freedesktop continuam vindo do pacote do sistema
sound-theme-freedesktop, cuja licença está em
/usr/share/doc/sound-theme-freedesktop/copyright — o audio-volume-change.oga de
fábrica é CC-BY-SA-3.0, de Lucas McCallister, e por isso NÃO foi copiado.
TXT
}

# --- escrita atômica de BINÁRIO ---------------------------------------------
# O `meow_escrever` do comum.sh usa `printf '%s'` e serve a texto; áudio passa
# por ele corrompido. Aqui o temporário nasce dentro do diretório de DESTINO,
# pelo mesmo motivo da trava 2 do comum.sh: o repo está em /mnt/Apate e o
# destino em /home, e `mv` entre sistemas de arquivos não é atômico.
#
# NO SECO O TEMPORÁRIO VAI PARA O TMPDIR, e nenhum diretório é criado. Uma
# versão anterior fazia `mkdir -p` antes de checar o seco e deixava
# ~/.local/share/sounds/freedesktop/stereo/ para trás num "dry-run" — ou seja,
# plantava a casca do sequestro do nome `freedesktop` sem ter escrito som nenhum.
_som_instalar() {
  local tmp
  meow_destino_permitido "$SOM_ALVO" || return "$MEOW_ERRO"

  if meow_seco; then
    tmp="$(mktemp -p "${TMPDIR:-/tmp}" ".meow-som.XXXXXX")" || return "$MEOW_ERRO"
    if ! _som_gerar "$tmp"; then
      rm -f "$tmp"; meow_erro "falha ao sintetizar o som"; return "$MEOW_ERRO"
    fi
    if [ -f "$SOM_ALVO" ] && cmp -s "$tmp" "$SOM_ALVO"; then
      rm -f "$tmp"; return "$MEOW_OK"
    fi
    rm -f "$tmp"; meow_muda "mudaria $SOM_ALVO"; return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$SOM_BASE" || return "$MEOW_ERRO"
  tmp="$(mktemp -p "$SOM_BASE" ".meow-som.XXXXXX")" || return "$MEOW_ERRO"
  if ! _som_gerar "$tmp"; then
    rm -f "$tmp"; meow_erro "falha ao sintetizar o som"; return "$MEOW_ERRO"
  fi
  if [ -f "$SOM_ALVO" ] && cmp -s "$tmp" "$SOM_ALVO"; then
    rm -f "$tmp"
    return "$MEOW_OK"      # regra 5: idêntico, não reescreve
  fi
  chmod 644 "$tmp"
  mv -f "$tmp" "$SOM_ALVO" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

# --- diagnóstico: sem o GATILHO, nada dispara -------------------------------
# Vale mais que um aviso de tema: em 04/08/2026 o cosmic-settings-daemon estava
# MORTO nesta máquina no meio da sessão, e com ele morrem as teclas de volume e
# de brilho inteiras — não só o som. O `pgrep -x` não serve aqui: o kernel trunca
# /proc/PID/comm em 15 caracteres e "cosmic-settings-daemon" tem 22.
_som_daemon_vivo() {
  pgrep -f '^(/[^ ]*/)?cosmic-settings-daemon( |$)' >/dev/null 2>&1
}
_som_osd_vivo() {
  pgrep -f '^(/[^ ]*/)?cosmic-osd( |$)' >/dev/null 2>&1
}

_som_avisar_ambiente() {
  if ! _som_osd_vivo; then
    meow_aviso "o cosmic-osd NÃO está rodando: é ELE quem toca — sem ele não sai som"
  fi
  if ! _som_daemon_vivo; then
    meow_aviso "o cosmic-settings-daemon NÃO está rodando: as teclas de volume e de"
    meow_aviso "  brilho ficam mudas (ele é o gatilho). Conserto durável: sair e entrar na sessão."
  fi
}

cmd_aplicar() {
  meow_tem python3 || { meow_erro "falta python3"; return "$MEOW_SEM_DEPENDENCIA"; }
  local rc rcl; _som_instalar; rc=$?
  [ "$rc" = "$MEOW_ERRO" ] && return "$rc"

  meow_escrever "$SOM_LICENCAS" "$(_som_licencas_texto)" 644 >/dev/null
  rcl=$?
  [ "$rcl" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"
  [ "$rcl" = "$MEOW_DIVERGENTE" ] && rc="$MEOW_DIVERGENTE"

  if [ "$rc" = "$MEOW_DIVERGENTE" ] && meow_seco; then
    meow_muda "instalaria o som de volume do MeowSystem em $SOM_ALVO"
  elif [ "$rc" = "$MEOW_DIVERGENTE" ]; then
    meow_muda "som de volume do MeowSystem instalado em $SOM_ALVO"
    meow_info "licenças registradas em $SOM_LICENCAS"
    meow_info "vale na próxima mudança de volume — nada a reiniciar"
  else
    meow_ok "som de volume já estava aplicado"
  fi
  _som_avisar_ambiente
  meow_registrar "som.sh aplicar rc=$rc"
  return "$rc"
}

cmd_conferir() {
  meow_tem python3 || { meow_erro "falta python3"; return "$MEOW_SEM_DEPENDENCIA"; }
  if [ ! -f "$SOM_ALVO" ]; then
    meow_muda "som de volume ausente (o COSMIC usa o de fábrica)"; _som_avisar_ambiente
    return "$MEOW_DIVERGENTE"
  fi
  local tmp; tmp="$(mktemp -p "${TMPDIR:-/tmp}" ".meow-som.XXXXXX")" || return "$MEOW_ERRO"
  _som_gerar "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  if cmp -s "$tmp" "$SOM_ALVO"; then
    rm -f "$tmp"; meow_ok "som de volume conforme"; _som_avisar_ambiente; return "$MEOW_OK"
  fi
  rm -f "$tmp"; meow_muda "som de volume divergente"; _som_avisar_ambiente
  return "$MEOW_DIVERGENTE"
}

# Reproduz a busca do osd (XDG_DATA_HOME antes de XDG_DATA_DIRS) e diz qual
# arquivo VAI tocar. Não toca nada, não escreve nada, não mexe no volume.
cmd_estado() {
  local escolhido="" d
  if [ -f "$SOM_ALVO" ]; then
    escolhido="$SOM_ALVO"
  else
    local IFS=:
    for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
      if [ -f "$d/sounds/$SOM_TEMA/stereo/audio-volume-change.oga" ]; then
        escolhido="$d/sounds/$SOM_TEMA/stereo/audio-volume-change.oga"; break
      fi
    done
  fi
  unset IFS
  if [ -n "$escolhido" ]; then
    meow_info "o COSMIC vai tocar: $escolhido"
    [ "$escolhido" = "$SOM_ALVO" ] && meow_ok "é o som do MeowSystem" \
                                   || meow_pula "é o som de fábrica"
  else
    meow_aviso "nenhum audio-volume-change.oga encontrado — o COSMIC ficará mudo"
  fi
  _som_osd_vivo    && meow_ok "cosmic-osd vivo (o tocador)" \
                   || meow_aviso "cosmic-osd MORTO — nada toca"
  _som_daemon_vivo && meow_ok "cosmic-settings-daemon vivo (o gatilho da tecla)" \
                   || meow_aviso "cosmic-settings-daemon MORTO — teclas de volume e brilho mudas"
  meow_info "para ver ao vivo qual arquivo tocou, com a tecla de volume na mão dela:"
  meow_info "  while :; do pgrep -af '(^|/)pw-play '; done   # e aperte a tecla"
  return "$MEOW_OK"
}

# Toca o arquivo instalado SEM mexer no volume dela: é o pw-play direto, com
# ganho baixo. Nunca dispare `VolumeDown` para "testar" — isso mexe no volume.
cmd_ouvir() {
  meow_tem pw-play || { meow_erro "falta pw-play (pipewire-bin)"; return "$MEOW_SEM_DEPENDENCIA"; }
  local alvo="$SOM_ALVO"
  [ -f "$alvo" ] || alvo="$SOM_SISTEMA"
  [ -f "$alvo" ] || { meow_erro "não há som para ouvir"; return "$MEOW_ERRO"; }
  meow_info "tocando $alvo"
  pw-play --volume 0.5 --media-role Notification "$alvo"
}

cmd_remover() {
  if [ ! -f "$SOM_ALVO" ]; then meow_pula "nada a remover"; return "$MEOW_OK"; fi
  meow_seco && { meow_muda "removeria $SOM_ALVO"; return "$MEOW_DIVERGENTE"; }
  rm -f "$SOM_ALVO" "$SOM_LICENCAS"
  # rmdir só apaga diretório vazio: se ela puser outros sons ali, ficam.
  # O `$SOM_RAIZ` (~/.local/share/sounds) NÃO entra: é diretório XDG padrão que
  # não foi criado por nós, e apagar o que não criamos não é reverter, é limpar
  # a casa dos outros.
  rmdir "$SOM_BASE" "$SOM_RAIZ/$SOM_TEMA" 2>/dev/null
  meow_muda "som de volume devolvido ao de fábrica"
  meow_registrar "som.sh remover"
  return "$MEOW_DIVERGENTE"
}

case "${1:-aplicar}" in
  aplicar)  cmd_aplicar ;;
  conferir) cmd_conferir ;;
  estado)   cmd_estado ;;
  ouvir)    cmd_ouvir ;;
  remover)  cmd_remover ;;
  *) meow_erro "uso: som.sh {aplicar|conferir|estado|ouvir|remover}"; exit "$MEOW_ERRO" ;;
esac

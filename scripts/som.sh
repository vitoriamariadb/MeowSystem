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
#   som.sh remover    volta ao som de fábrica do sistema (e tira o tema do pack)
#   som.sh vigiar     o tocador das notificações (quem o roda é o meow-som.service)
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

# --- o timbre do PACK ativo, antes dos defaults ------------------------------
#
# A ORDEM AQUI É O CONTRATO DE PRECEDÊNCIA (docs/PACKS.md, "Quem vence"):
#   1. o que já está no ambiente  -> veio do meow.conf, e SEMPRE vence
#   2. o que o pack declara       -> entra só no que sobrou
#   3. o default do projeto       -> nas linhas `${VAR:-...}` logo abaixo
#
# O `: "${VAR:=valor}"` é o que faz a camada 2 respeitar a 1: ele só atribui se
# a variável estiver vazia ou ausente. Um `export VAR=valor` cru aqui passaria
# por cima do meow.conf da pessoa — que é exatamente o que o formato promete
# nunca fazer.
_som_do_pack() {
  local dir linha
  dir="$(meow_pack_dir)" || return 0
  [ -n "$dir" ] || return 0
  [ -f "$dir/pack.json" ] || return 0
  # O pack.py imprime só o que o pack DECLARA — chave ausente não vira linha.
  while IFS= read -r linha; do
    case "$linha" in
      SOM_*=*) eval ": \"\${${linha%%=*}:=${linha#*=}}\"" ;;
    esac
  done < <(python3 "$MEOW_RAIZ/scripts/pack.py" som "$(basename "$dir")" 2>/dev/null)
}
_som_do_pack

# --- O TIMBRE, E POR QUE ELE SAIU DE DENTRO DO PYTHON [2026-09-17] -----------
#
#   Até aqui as quatro decisões de timbre viviam cravadas no gerador: 880 Hz,
#   1320 Hz, os pesos 0.62/0.28 e o decaimento 46.0. Isso fazia sentido enquanto
#   o MeowSystem era um tema só. Deixou de fazer quando ele virou produto com
#   THEME PACKS (docs/PACKS.md): um pack pode trazer a própria paleta, os
#   próprios ícones e o próprio papel de parede — e ficaria com o sino do
#   vizinho.
#
#   O QUE NÃO MUDOU, e não pode mudar:
#     - a DURAÇÃO continua presa ao debounce de 125 ms do osd (ver prova 3 no
#       cabeçalho). Um pack pode encurtar; alongar além disso empilha o som;
#     - o GANHO continua calibrado contra o arquivo de fábrica. Um pack que
#       suba o ganho muda o SUSTO, não o timbre — e isso não é estética, é a
#       pessoa levando um susto ao mexer no volume;
#     - a síntese continua DETERMINÍSTICA, que é o que faz o `conferir`
#       funcionar: gera de novo e compara byte a byte. Parâmetro entra pelo
#       ambiente, nunca aleatoriedade.
#
#   O DEFAULT É O DE SEMPRE. Sem nenhuma destas chaves, o som gerado é
#   byte-idêntico ao de antes desta mudança — conferido por sha256 na mesma data.
#
# FUNDAMENTAL e HARMÔNICO: as duas senoides que formam o sino.
#   880 Hz é o lá da quinta oitava; 1320 é a quinta justa acima dele. A quinta
#   soa "resolvida" e não alarmante — foi escolhida por isso.
# --- O TEMA DE SOM DO PACK, E QUEM O TOCA — 09/10/2026, P74 item 9 (T3) -------
#   O pack Dracula trouxe de volta os 25 efeitos do tema de som de antes
#   (`som.tema` no pack.json, CC0). Eles ficaram fora em 16/09 pelo motivo do
#   cabeçalho deste arquivo: o COSMIC toca UM som de evento, o de volume. O
#   motivo vira cura em duas partes:
#     1. o tema é instalado como tema de som freedesktop, em
#        `~/.local/share/sounds/MeowSystem-Sons` (um nome nosso: a pasta é de
#        dono único, e a troca de pack a leva junto);
#     2. o `meow-som.service` (systemd/) roda o `som.sh vigiar`, que escuta as
#        chamadas `Notify` do barramento da sessão e toca o som de notificação
#        do tema, com o `pw-play` — o mesmo tocador do `cosmic-osd`. Uma
#        notificação que pede silêncio (`suppress-sound`) fica em silêncio, e
#        duas seguidas dentro de 0,8 s tocam uma vez (a armadilha 3 lá de cima:
#        sons que se sobrepõem empilham).
#   O som de VOLUME não muda: continua o sino do pack, porque os efeitos do
#   tema têm de 0,24 s a 0,95 s e empilhariam na tecla segurada.
_som_ref="$(meow_pack_dir)"
[ -n "$_som_ref" ] || _som_ref="$(meow_pack_padrao_dir 2>/dev/null || true)"
SOM_TEMA_PACK="$(python3 "$MEOW_RAIZ/scripts/pack.py" acervo "$_som_ref" som.tema 2>/dev/null)" || SOM_TEMA_PACK=""
SOM_TEMA_PACK="${SOM_TEMA_PACK%/}"
unset _som_ref
SOM_TEMA_DIR="$SOM_RAIZ/MeowSystem-Sons"
SOM_UNIDADE="$HOME/.config/systemd/user/meow-som.service"
SOM_UNIDADE_FONTE="$MEOW_RAIZ/systemd/meow-som.service"

SOM_FUNDAMENTAL="${SOM_FUNDAMENTAL:-880.0}"
SOM_HARMONICO="${SOM_HARMONICO:-1320.0}"
# Os PESOS de cada senoide na mistura. Somados devem ficar abaixo de 1.0, senão
# o ganho satura e o `max(-1, min(1, ...))` do gerador corta a onda — o que soa
# como estalo, não como sino.
SOM_PESO_FUNDAMENTAL="${SOM_PESO_FUNDAMENTAL:-0.62}"
SOM_PESO_HARMONICO="${SOM_PESO_HARMONICO:-0.28}"
# DECAIMENTO: o expoente da queda. Maior = mais seco. 46.0 dá um sino curto;
# abaixo de ~20 a cauda começa a arrastar e o som vira "blop".
SOM_DECAIMENTO="${SOM_DECAIMENTO:-46.0}"

# --- o gerador: só biblioteca padrão, e DETERMINÍSTICO ----------------------
# Determinístico é o que torna `conferir` possível: geramos de novo e comparamos
# byte a byte com o que está instalado. Sem isso, toda checagem acusaria
# divergência e o auto-reparo entraria em ping-pong.
_som_gerar() {
  local destino="$1"
  python3 - "$destino" "$SOM_DURACAO" "$SOM_GANHO" \
           "$SOM_FUNDAMENTAL" "$SOM_HARMONICO" \
           "$SOM_PESO_FUNDAMENTAL" "$SOM_PESO_HARMONICO" "$SOM_DECAIMENTO" <<'PY'
import math, struct, sys, wave

destino, dur, ganho = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
# O timbre vem do pack ativo, com os valores de sempre como default —
# ver o bloco "O TIMBRE" em scripts/som.sh e a seção "som" em docs/PACKS.md.
fund, harm = float(sys.argv[4]), float(sys.argv[5])
peso_f, peso_h, decaimento = float(sys.argv[6]), float(sys.argv[7]), float(sys.argv[8])
taxa = 48000
n = int(taxa * dur)
quadros = bytearray()
for i in range(n):
    t = i / taxa
    # Decaimento exponencial rápido: ataque seco, sem cauda arrastada.
    env = math.exp(-t * decaimento)
    # Rampas de 2 ms nas pontas: sem elas o corte estala no alto-falante.
    janela = min(1.0, i / 96.0) * min(1.0, (n - i) / 96.0)
    # Fundamental + quinta justa: sino curto, sem soar a alarme.
    s = peso_f * math.sin(2 * math.pi * fund * t)
    s += peso_h * math.sin(2 * math.pi * harm * t)
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

# O tema do pack no disco: conferir | aplicar | tirar.
# 0 = já está · 1 = divergente / escreveu · 2 = erro.
_som_tema() {
  local modo="$1"
  if [ "$modo" = "tirar" ]; then
    [ -d "$SOM_TEMA_DIR" ] || return "$MEOW_OK"
    meow_seco && { meow_muda "tiraria o tema de som de $SOM_TEMA_DIR"; return "$MEOW_DIVERGENTE"; }
    rm -rf -- "$SOM_TEMA_DIR" || return "$MEOW_ERRO"
    meow_muda "o tema de som saiu de $SOM_TEMA_DIR"
    return "$MEOW_DIVERGENTE"
  fi
  [ "$modo" = "conferir" ] || meow_seco || meow_destino_permitido "$SOM_TEMA_DIR" || return "$MEOW_ERRO"
  MEOW_PY_SECO="$( { [ "$modo" = "conferir" ] || meow_seco; } && echo 1 || echo 0)" \
  python3 - "$SOM_TEMA_PACK" "$SOM_TEMA_DIR" <<'PY'
import filecmp, os, shutil, sys
origem, destino = sys.argv[1], sys.argv[2]
so_ler = os.environ.get("MEOW_PY_SECO") == "1"
quer = set()
for raiz, _d, arqs in os.walk(origem):
    for a in arqs:
        quer.add(os.path.relpath(os.path.join(raiz, a), origem))
tem = set()
for raiz, _d, arqs in os.walk(destino):
    for a in arqs:
        tem.add(os.path.relpath(os.path.join(raiz, a), destino))
mudar = sorted(r for r in quer
               if r not in tem or not filecmp.cmp(os.path.join(origem, r), os.path.join(destino, r), shallow=False))
sobra = sorted(tem - quer)
if not mudar and not sobra:
    sys.exit(0)
if so_ler:
    sys.exit(1)
for r in mudar:
    alvo = os.path.join(destino, r)
    os.makedirs(os.path.dirname(alvo), exist_ok=True)
    tmp = alvo + ".meow-novo"
    shutil.copyfile(os.path.join(origem, r), tmp)
    os.chmod(tmp, 0o644)
    os.replace(tmp, alvo)
for r in sobra:
    os.remove(os.path.join(destino, r))
sys.exit(1)
PY
}

# O systemd do usuário só é chamado quando este HOME é o da sessão: num HOME de
# teste, `systemctl --user` mexeria na unidade da sessão de verdade (a mesma
# recusa do `construir_icones.sh`, `_ci_home_e_da_sessao`).
_som_da_sessao() {
  local dono
  dono="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)"
  [ -n "$dono" ] && [ "$HOME" = "$dono" ] && meow_tem systemctl && [ -d "/run/user/$(id -u)/systemd" ]
}

# A unidade que toca: conferir | aplicar | tirar. Mesmos códigos.
_som_unidade() {
  local modo="$1" rc
  case "$modo" in
    conferir)
      [ -f "$SOM_UNIDADE" ] && [ "$(cat "$SOM_UNIDADE")" = "$(cat "$SOM_UNIDADE_FONTE")" ] \
        && return "$MEOW_OK"
      return "$MEOW_DIVERGENTE" ;;
    aplicar)
      meow_escrever "$SOM_UNIDADE" "$(cat "$SOM_UNIDADE_FONTE")" 644; rc=$?
      [ "$rc" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"
      if ! meow_seco && _som_da_sessao; then
        systemctl --user daemon-reload >/dev/null 2>&1
        # `enable --now` não reinicia a que já está de pé; um arquivo novo pede
        # o `restart`, para a sessão tocar o tema que acabou de entrar.
        systemctl --user enable --now meow-som.service >/dev/null 2>&1
        [ "$rc" = "$MEOW_DIVERGENTE" ] && systemctl --user restart meow-som.service >/dev/null 2>&1
      fi
      return "$rc" ;;
    tirar)
      [ -f "$SOM_UNIDADE" ] || return "$MEOW_OK"
      meow_seco && { meow_muda "desligaria o meow-som.service"; return "$MEOW_DIVERGENTE"; }
      _som_da_sessao && systemctl --user disable --now meow-som.service >/dev/null 2>&1
      rm -f -- "$SOM_UNIDADE" || return "$MEOW_ERRO"
      _som_da_sessao && systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "o meow-som.service saiu"
      return "$MEOW_DIVERGENTE" ;;
  esac
}

# Conferir e aplicar o tema e a unidade juntos, pelo pack no ar: com tema, os
# dois entram; sem ele (o Catppuccin não traz tema de som), os dois saem.
_som_tema_e_unidade() {   # $1 = conferir | aplicar
  local rc_t rc_u
  if [ -n "$SOM_TEMA_PACK" ] && [ -f "$SOM_TEMA_PACK/index.theme" ]; then
    _som_tema "$1"; rc_t=$?
    _som_unidade "$1"; rc_u=$?
  elif [ "$1" = "conferir" ]; then
    rc_t="$MEOW_OK"; rc_u="$MEOW_OK"
    [ -d "$SOM_TEMA_DIR" ] && rc_t="$MEOW_DIVERGENTE"
    [ -f "$SOM_UNIDADE" ] && rc_u="$MEOW_DIVERGENTE"
  else
    _som_tema tirar; rc_t=$?
    _som_unidade tirar; rc_u=$?
  fi
  [ "$rc_t" -gt "$rc_u" ] && return "$rc_t"
  return "$rc_u"
}

cmd_aplicar() {
  # A CHAVE `SOM` decide, e "não" REMOVE em vez de só não instalar. [2026-09-17]
  #   Não instalar e remover são coisas diferentes para quem já tinha o som: sem
  #   isto, desligar a chave deixaria o arquivo instalado tocando para sempre, e
  #   a pessoa concluiria que o controle não funciona. É o mesmo desenho do
  #   `icones_apps_dracula.sh`, que chama `_dracula_remover` quando a chave dele
  #   está em "não".
  if [ "${SOM:-sim}" != "sim" ]; then
    cmd_remover
    return $?
  fi
  meow_tem python3 || { meow_erro "falta python3"; return "$MEOW_SEM_DEPENDENCIA"; }
  local rc rcl; _som_instalar; rc=$?
  [ "$rc" = "$MEOW_ERRO" ] && return "$rc"

  meow_escrever "$SOM_LICENCAS" "$(_som_licencas_texto)" 644 >/dev/null
  rcl=$?
  [ "$rcl" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"
  [ "$rcl" = "$MEOW_DIVERGENTE" ] && rc="$MEOW_DIVERGENTE"

  # O tema de som do pack e quem o toca (P74 item 9).
  local rct; _som_tema_e_unidade aplicar; rct=$?
  [ "$rct" = "$MEOW_ERRO" ] && { meow_erro "não consegui pôr o tema de som do pack"; return "$MEOW_ERRO"; }
  if [ "$rct" = "$MEOW_DIVERGENTE" ]; then
    rc="$MEOW_DIVERGENTE"
    [ -n "$SOM_TEMA_PACK" ] && ! meow_seco && meow_muda "tema de som do pack em $SOM_TEMA_DIR, tocado nas notificações"
  fi

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
  # A CHAVE MANDA AQUI TAMBÉM, e ignorá-la dava as duas respostas erradas.
  #   [2026-09-18] `cmd_aplicar` respeita SOM desde 17/09, mas esta função não —
  #   e conferir tem de responder sobre o MESMO estado que aplicar produziria.
  #   Medido antes da correção:
  #     SOM=nao + arquivo instalado  -> dizia "conforme"   (o aplicar REMOVERIA)
  #     SOM=nao + arquivo ausente    -> diria "divergente" (está como deveria)
  #   O segundo caso é o que doía: quem desligasse o som ganharia um doctor
  #   acusando divergência todo dia às 05:00, para sempre, sobre uma escolha
  #   deliberada. É a armadilha do laço não convergente, de novo.
  if [ "${SOM:-sim}" != "sim" ]; then
    if [ -f "$SOM_ALVO" ] || [ -d "$SOM_TEMA_DIR" ] || [ -f "$SOM_UNIDADE" ]; then
      meow_muda "SOM=\"nao\" e o nosso som ainda está instalado"
      return "$MEOW_DIVERGENTE"
    fi
    meow_ok "som de volume de fábrica, como pedido (SOM=\"nao\")"
    return "$MEOW_OK"
  fi
  # O tema de som do pack e a unidade que o toca (P74 item 9).
  if ! _som_tema_e_unidade conferir; then
    meow_muda "o tema de som do pack, ou quem o toca nas notificações, não está como o pack pede"
    return "$MEOW_DIVERGENTE"
  fi
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
  meow_info "para ver ao vivo qual arquivo tocou, com a tecla de volume à mão:"
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
  # O `|| return MEOW_ERRO` fecha o caso que escapava. [2026-09-18]
  #   Sem ele, um pw-play que falha (sem servidor de áudio, sink mudo, arquivo
  #   corrompido) devolvia o 1 do processo — e 1, no contrato desta casa, é
  #   MEOW_DIVERGENTE, isto é, "há divergências". O painel então pintava um
  #   fracasso de amarelo e ainda dava torrada verde.
  #   O contrato "1 = há divergências" é do VERIFICADOR. Quem só atua não tem
  #   divergência a relatar: ou tocou, ou deu erro. Esta função já devolvia
  #   MEOW_ERRO nos dois abortos acima; só este escapava.
  pw-play --volume 0.5 --media-role Notification "$alvo" || return "$MEOW_ERRO"
}

cmd_remover() {
  # O tema do pack e a unidade saem primeiro (P74 item 9), e sozinhos se o
  # som de volume já não estava.
  local rct=0
  _som_unidade tirar >/dev/null; [ $? = "$MEOW_DIVERGENTE" ] && rct=1
  _som_tema tirar >/dev/null; [ $? = "$MEOW_DIVERGENTE" ] && rct=1
  if [ ! -f "$SOM_ALVO" ]; then
    [ "$rct" = 1 ] && { meow_muda "tema de som do pack e o tocador das notificações tirados"; return "$MEOW_DIVERGENTE"; }
    meow_pula "nada a remover"; return "$MEOW_OK"
  fi
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

# `vigiar` — O TOCADOR DAS NOTIFICAÇÕES (P74 item 9; quem o roda é o
#   `meow-som.service`). O `dbus-monitor` imprime cada chamada `Notify` em um
#   bloco: a linha do cabeçalho e os argumentos, indentados. O bloco termina
#   no próximo cabeçalho, ou quando 0,3 s passam sem linha nova — sem esse
#   prazo, uma notificação só tocaria quando chegasse a seguinte.
SOM_VIGIA_ULTIMO=0
_som_vigiar_tocar() {   # $1 = o bloco de um Notify · $2 = o arquivo a tocar
  local agora
  # Quem pede silêncio, tem silêncio: o Telegram e o Discord tocam o deles.
  if grep -A1 -F 'string "suppress-sound"' <<< "$1" | grep -q 'boolean true'; then
    return 0
  fi
  agora="$(date +%s%3N)"
  [ $((agora - SOM_VIGIA_ULTIMO)) -lt 800 ] && return 0
  SOM_VIGIA_ULTIMO="$agora"
  pw-play --media-role Notification "$2" >/dev/null 2>&1 &
}

cmd_vigiar() {
  local som linha bloco="" rc
  meow_tem dbus-monitor || { meow_erro "falta dbus-monitor"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem pw-play || { meow_erro "falta pw-play (pipewire-bin)"; return "$MEOW_SEM_DEPENDENCIA"; }
  som="$SOM_TEMA_DIR/stereo/notification/message-new-instant.oga"
  [ -f "$som" ] || som="$SOM_TEMA_DIR/stereo/notification/message.oga"
  [ -f "$som" ] || { meow_pula "sem tema de som do pack instalado — nada a tocar"; return "$MEOW_OK"; }
  while :; do
    if IFS= read -r -t 0.3 linha; then
      case "$linha" in
        "method call "*"member=Notify"*)
          [ -n "$bloco" ] && _som_vigiar_tocar "$bloco" "$som"
          bloco="$linha" ;;
        " "*|"	"*)
          [ -n "$bloco" ] && bloco="$bloco"$'\n'"$linha" ;;
        *)
          [ -n "$bloco" ] && _som_vigiar_tocar "$bloco" "$som"
          bloco="" ;;
      esac
    else
      rc=$?
      [ -n "$bloco" ] && { _som_vigiar_tocar "$bloco" "$som"; bloco=""; }
      # Acima de 128 é o prazo; abaixo, o `dbus-monitor` acabou — e acabar é
      # falha, para o systemd o pôr de pé de novo (`Restart=on-failure`).
      [ "$rc" -gt 128 ] || break
    fi
  done < <(dbus-monitor --session "type='method_call',interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null)
  wait
  return "$MEOW_ERRO"
}

case "${1:-aplicar}" in
  aplicar)  cmd_aplicar ;;
  vigiar)   cmd_vigiar ;;
  conferir) cmd_conferir ;;
  estado)   cmd_estado ;;
  ouvir)    cmd_ouvir ;;
  remover)  cmd_remover ;;
  *) meow_erro "uso: som.sh {aplicar|conferir|estado|ouvir|remover|vigiar}"; exit "$MEOW_ERRO" ;;
esac

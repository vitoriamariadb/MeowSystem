#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

SOM_TEMA="freedesktop"
SOM_RAIZ="$HOME/.local/share/sounds"
SOM_BASE="$SOM_RAIZ/$SOM_TEMA/stereo"
SOM_ALVO="$SOM_BASE/audio-volume-change.oga"
SOM_LICENCAS="$SOM_RAIZ/$SOM_TEMA/LICENCAS.txt"
SOM_SISTEMA="/usr/share/sounds/$SOM_TEMA/stereo/audio-volume-change.oga"

SOM_DURACAO="${SOM_DURACAO:-0.085}"
SOM_GANHO="${SOM_GANHO:-0.18}"

_som_do_pack() {
  local dir linha var val
  dir="$(meow_pack_dir)" || return 0
  [ -n "$dir" ] || return 0
  [ -f "$dir/pack.json" ] || return 0
  while IFS= read -r linha; do
    case "$linha" in
      SOM_*=*)
        var="${linha%%=*}"; val="${linha#*=}"
        case "$var" in *[!A-Z_]*) continue ;; esac
        case "$val" in ''|*[!0-9.eE+-]*) continue ;; esac
        [ -n "${!var:-}" ] || printf -v "$var" '%s' "$val" ;;
    esac
  done < <(python3 "$MEOW_RAIZ/scripts/pack.py" som "$(basename "$dir")" 2>/dev/null)
}
_som_do_pack

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
SOM_PESO_FUNDAMENTAL="${SOM_PESO_FUNDAMENTAL:-0.62}"
SOM_PESO_HARMONICO="${SOM_PESO_HARMONICO:-0.28}"
SOM_DECAIMENTO="${SOM_DECAIMENTO:-46.0}"

_som_gerar() {
  local destino="$1"
  python3 -I - "$destino" "$SOM_DURACAO" "$SOM_GANHO" \
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
    return "$MEOW_OK"
  fi
  chmod 644 "$tmp"
  meow_guardar_antes "$SOM_ALVO"
  mv -f "$tmp" "$SOM_ALVO" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

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

_som_tema() {
  local modo="$1"
  if [ "$modo" = "tirar" ]; then
    [ -d "$SOM_TEMA_DIR" ] || return "$MEOW_OK"
    meow_seco && { meow_muda "tiraria o tema de som de $SOM_TEMA_DIR"; return "$MEOW_DIVERGENTE"; }
    meow_guardar_pasta "$SOM_TEMA_DIR"
    rm -rf -- "$SOM_TEMA_DIR" || return "$MEOW_ERRO"
    meow_muda "o tema de som saiu de $SOM_TEMA_DIR"
    return "$MEOW_DIVERGENTE"
  fi
  [ "$modo" = "conferir" ] || meow_seco || meow_destino_permitido "$SOM_TEMA_DIR" || return "$MEOW_ERRO"
  [ "$modo" = "conferir" ] || meow_guardar_pasta "$SOM_TEMA_DIR"
  MEOW_PY_SECO="$( { [ "$modo" = "conferir" ] || meow_seco; } && echo 1 || echo 0)" \
  python3 -I - "$SOM_TEMA_PACK" "$SOM_TEMA_DIR" <<'PY'
import filecmp, os, shutil, sys
origem, destino = sys.argv[1], sys.argv[2]
so_ler = os.environ.get("MEOW_PY_SECO") == "1"
dentro = os.path.realpath(origem) + os.sep
quer, recusados = set(), []
for raiz, _d, arqs in os.walk(origem):
    for a in arqs:
        cheio = os.path.join(raiz, a)
        if os.path.islink(cheio) or not os.path.isfile(cheio) \
                or not os.path.realpath(cheio).startswith(dentro):
            recusados.append(os.path.relpath(cheio, origem))
            continue
        quer.add(os.path.relpath(cheio, origem))
if recusados:
    sys.stderr.write("  !!   %d arquivo(s) do tema de som do pack são link ou saem dele, e ficaram de fora: %s\n"
                     % (len(recusados), " ".join(sorted(recusados)[:3])))
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

_som_da_sessao() {
  local dono
  dono="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)"
  [ -n "$dono" ] && [ "$HOME" = "$dono" ] && meow_tem systemctl && [ -d "/run/user/$(id -u)/systemd" ]
}

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

_som_tema_e_unidade() {
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

  local rct rcv="$rc"; _som_tema_e_unidade aplicar; rct=$?
  [ "$rct" = "$MEOW_ERRO" ] && { meow_erro "não consegui pôr o tema de som do pack"; return "$MEOW_ERRO"; }
  if [ "$rct" = "$MEOW_DIVERGENTE" ]; then
    rc="$MEOW_DIVERGENTE"
    if [ -n "$SOM_TEMA_PACK" ]; then
      if meow_seco; then meow_muda "poria o tema de som do pack em $SOM_TEMA_DIR, tocado nas notificações"
      else meow_muda "tema de som do pack em $SOM_TEMA_DIR, tocado nas notificações"; fi
    fi
  fi

  if [ "$rcv" = "$MEOW_DIVERGENTE" ] && meow_seco; then
    meow_muda "instalaria o som de volume do MeowSystem em $SOM_ALVO"
  elif [ "$rcv" = "$MEOW_DIVERGENTE" ]; then
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
  if [ "${SOM:-sim}" != "sim" ]; then
    if [ -f "$SOM_ALVO" ] || [ -d "$SOM_TEMA_DIR" ] || [ -f "$SOM_UNIDADE" ]; then
      meow_muda "SOM=\"nao\" e o nosso som ainda está instalado"
      return "$MEOW_DIVERGENTE"
    fi
    meow_ok "som de volume de fábrica, como pedido (SOM=\"nao\")"
    return "$MEOW_OK"
  fi
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

cmd_ouvir() {
  meow_tem pw-play || { meow_erro "falta pw-play (pipewire-bin)"; return "$MEOW_SEM_DEPENDENCIA"; }
  local alvo="$SOM_ALVO"
  [ -f "$alvo" ] || alvo="$SOM_SISTEMA"
  [ -f "$alvo" ] || { meow_erro "não há som para ouvir"; return "$MEOW_ERRO"; }
  meow_info "tocando $alvo"
  pw-play --volume 0.5 --media-role Notification "$alvo" || return "$MEOW_ERRO"
}

cmd_remover() {
  local rct=0
  _som_unidade tirar >/dev/null; [ $? = "$MEOW_DIVERGENTE" ] && rct=1
  _som_tema tirar >/dev/null; [ $? = "$MEOW_DIVERGENTE" ] && rct=1
  if [ ! -f "$SOM_ALVO" ]; then
    [ "$rct" = 1 ] && { meow_muda "tema de som do pack e o tocador das notificações tirados"; return "$MEOW_DIVERGENTE"; }
    meow_pula "nada a remover"; return "$MEOW_OK"
  fi
  meow_seco && { meow_muda "removeria $SOM_ALVO"; return "$MEOW_DIVERGENTE"; }
  meow_guardar_antes "$SOM_ALVO"; meow_guardar_antes "$SOM_LICENCAS"
  rm -f "$SOM_ALVO" "$SOM_LICENCAS"
  rmdir "$SOM_BASE" "$SOM_RAIZ/$SOM_TEMA" 2>/dev/null
  meow_muda "som de volume devolvido ao de fábrica"
  meow_registrar "som.sh remover"
  return "$MEOW_DIVERGENTE"
}

SOM_VIGIA_ULTIMO=0
_som_vigiar_tocar() {
  local agora
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
  local prazo
  while :; do
    prazo=(); [ -n "$bloco" ] && prazo=(-t 0.3)
    if IFS= read -r ${prazo[@]+"${prazo[@]}"} linha; then
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

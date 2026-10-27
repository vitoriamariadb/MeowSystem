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

SOM_CARIMBO="$MEOW_ESTADO/som-do-pack"
SOM_TIMBRE_CHAVES="SOM_FUNDAMENTAL SOM_HARMONICO SOM_PESO_FUNDAMENTAL SOM_PESO_HARMONICO SOM_DECAIMENTO"

_som_pack_ref() {
  local dir
  dir="$(meow_pack_dir)"
  [ -n "$dir" ] || dir="$(meow_pack_padrao_dir 2>/dev/null || true)"
  printf '%s' "$dir"
}

_som_do_pack() {
  local dir linha var val
  dir="$(_som_pack_ref)"
  [ -n "$dir" ] || return 0
  [ -f "$dir/pack.json" ] || return 0
  if [ "$(cat "$SOM_CARIMBO" 2>/dev/null)" != "$(basename "$dir")" ]; then
    for var in $SOM_TIMBRE_CHAVES; do unset "$var"; done
  fi
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

_som_ref="$(_som_pack_ref)"
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
  if [ "$modo" != "conferir" ] && ! meow_seco; then
    _som_tema_py 1 2>/dev/null && return "$MEOW_OK"
    meow_guardar_pasta "$SOM_TEMA_DIR"
  fi
  _som_tema_py "$( { [ "$modo" = "conferir" ] || meow_seco; } && echo 1 || echo 0)"
}

_som_tema_py() {
  MEOW_PY_SECO="$1" python3 -I - "$SOM_TEMA_PACK" "$SOM_TEMA_DIR" <<'PY'
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

MEOW_SONS_SISTEMA="${MEOW_SONS_SISTEMA:-/usr/share/sounds}"
MEOW_SONS_ORIGINAIS="${MEOW_SONS_ORIGINAIS:-/var/lib/meowsystem/sons}"
SOM_DA_PONTE="power-plug:notification power-unplug:notification power-unplug-battery-low:alert battery-caution:notification battery-low:alert complete:notification dialog-warning:alert"

_som_ponte_alvo() {
  case "$1" in
    dialog-warning) printf '%s' "$MEOW_SONS_SISTEMA/freedesktop/stereo/dialog-warning.oga" ;;
    power-unplug-battery-low|battery-low) printf '%s' "$MEOW_SONS_SISTEMA/Pop/stereo/alert/$1.oga" ;;
    *) printf '%s' "$MEOW_SONS_SISTEMA/Pop/stereo/notification/$1.oga" ;;
  esac
}

_som_ponte_pendentes() {
  local par ev ctx fonte alvo base="$SOM_TEMA_DIR"
  meow_seco && base="$SOM_TEMA_PACK"
  for par in $SOM_DA_PONTE; do
    ev="${par%%:*}"; ctx="${par##*:}"
    fonte="$base/stereo/$ctx/$ev.oga"
    alvo="$(_som_ponte_alvo "$ev")"
    if [ -n "$SOM_TEMA_PACK" ] && [ -f "$fonte" ]; then
      [ -f "$alvo" ] && cmp -s "$fonte" "$alvo" || printf 'som %s\n' "$ev"
    elif [ -f "$MEOW_SONS_ORIGINAIS/$ev.original" ]; then
      printf 'padrao %s\n' "$ev"
    fi
  done
}

_som_ponte() {
  local modo="$1" pendentes linha verbo ev ctx par rc=0
  pendentes="$(_som_ponte_pendentes)"
  [ -n "$pendentes" ] || return "$MEOW_OK"
  if [ "$modo" = "conferir" ]; then
    meow_ponte_viva || { meow_aviso "o carregador e a bateria ainda tocam os sons do Pop: a ponte não está viva"; return "$MEOW_OK"; }
    return "$MEOW_DIVERGENTE"
  fi
  if meow_seco; then
    meow_muda "poria $(printf '%s\n' "$pendentes" | wc -l) som(ns) do pack no lugar dos do Pop, pela ponte"
    return "$MEOW_DIVERGENTE"
  fi
  if ! meow_ponte_viva; then
    meow_aviso "o carregador e a bateria ainda tocam os sons do Pop: a ponte não está viva"
    return "$MEOW_OK"
  fi
  while read -r verbo ev; do
    [ -n "$ev" ] || continue
    if [ "$verbo" = "som" ]; then
      for par in $SOM_DA_PONTE; do [ "${par%%:*}" = "$ev" ] && ctx="${par##*:}"; done
      { printf '%s\n' "$ev"; cat "$SOM_TEMA_DIR/stereo/$ctx/$ev.oga"; } | meow_ponte som 2>/dev/null || rc=1
    else
      printf '%s\n' "$ev" | meow_ponte som-padrao 2>/dev/null || rc=1
    fi
  done <<< "$pendentes"
  if [ "$rc" = 1 ]; then
    meow_aviso "a ponte instalada não troca os sons do Pop ainda: o próximo «Instalar tudo» a atualiza"
    return "$MEOW_OK"
  fi
  return "$MEOW_DIVERGENTE"
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

  local rcp; _som_ponte aplicar; rcp=$?
  if [ "$rcp" = "$MEOW_DIVERGENTE" ]; then
    rc="$MEOW_DIVERGENTE"
    meow_seco || meow_muda "sons do carregador e da bateria no lugar dos do Pop"
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
  if ! _som_ponte conferir; then
    meow_muda "o carregador ou a bateria tocam um som que não é o do pack"
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

cmd_gerar() {
  local destino="${1:-}" par chave valor
  [ -n "$destino" ] || { meow_erro "uso: som.sh gerar <arquivo> [SOM_CHAVE=número ...]"; return "$MEOW_ERRO"; }
  shift
  for par in "$@"; do
    chave="${par%%=*}"; valor="${par#*=}"
    case " $SOM_TIMBRE_CHAVES " in *" $chave "*) ;; *) meow_erro "$chave não é do timbre do sino"; return "$MEOW_ERRO" ;; esac
    case "$valor" in ''|*[!0-9.eE+-]*) meow_erro "$chave: «$valor» não é um número"; return "$MEOW_ERRO" ;; esac
    printf -v "$chave" '%s' "$valor"
  done
  _som_gerar "$destino" || { meow_erro "falha ao sintetizar o sino"; return "$MEOW_ERRO"; }
}

cmd_timbre() {
  printf 'SOM_FUNDAMENTAL=%s\nSOM_HARMONICO=%s\nSOM_PESO_FUNDAMENTAL=%s\nSOM_PESO_HARMONICO=%s\nSOM_DECAIMENTO=%s\n' \
    "$SOM_FUNDAMENTAL" "$SOM_HARMONICO" "$SOM_PESO_FUNDAMENTAL" "$SOM_PESO_HARMONICO" "$SOM_DECAIMENTO"
}

cmd_remover() {
  local rct=0 SOM_TEMA_PACK=""
  _som_unidade tirar >/dev/null; [ $? = "$MEOW_DIVERGENTE" ] && rct=1
  _som_tema tirar >/dev/null; [ $? = "$MEOW_DIVERGENTE" ] && rct=1
  _som_ponte aplicar >/dev/null; [ $? = "$MEOW_DIVERGENTE" ] && rct=1
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
  gerar)    shift; cmd_gerar "$@" ;;
  timbre)   cmd_timbre ;;
  remover)  cmd_remover ;;
  *) meow_erro "uso: som.sh {aplicar|conferir|estado|ouvir|gerar|timbre|remover|vigiar}"; exit "$MEOW_ERRO" ;;
esac

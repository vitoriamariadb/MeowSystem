#!/usr/bin/env bash

MEOW_QBT_APP_ID="org.qbittorrent.qBittorrent"

meow_app_tema_do_pack qbittorrent.arquivo
MEOW_QBT_ORIGEM="$MEOW_APP_TEMA"
MEOW_QBT_NOME_AURORA="$MEOW_APP_TEMA_PACK"
MEOW_QBT_ARQUIVO="$(basename -- "${MEOW_QBT_ORIGEM:-sem-tema}")"
meow_app_tema_do_pack qbittorrent.sha256
MEOW_QBT_SHA256="$MEOW_APP_TEMA"

MEOW_QBT_AURORA_FONTE="${MEOW_QBT_AURORA_FONTE:-}"
MEOW_QBT_AURORA_ESTADO="$HOME/.local/state/aurora/qbittorrent-tema"

MEOW_QBT_JA_AVISOU=0
MEOW_QBT_AVISOU_NATIVO=0

_meow_qbt_conf_dir() {
  meow_tem flatpak || return 1
  meow_flatpak_tem "$MEOW_QBT_APP_ID" || return 1
  printf '%s' "$HOME/.var/app/$MEOW_QBT_APP_ID/config/qBittorrent"
}

_meow_qbt_avisar_nativo() {
  [ "$MEOW_QBT_AVISOU_NATIVO" = "1" ] && return 0
  MEOW_QBT_AVISOU_NATIVO=1
  meow_aviso "há um qBittorrent NATIVO instalado, mas este módulo cobre só o flatpak"
  meow_info  "(quem escreve o conf é o script do Aurora, que é flatpak-only)"
  return 0
}

_meow_qbt_aurora_destravado() {
  [ -n "$MEOW_QBT_NOME_AURORA" ] || return 1
  [ -f "$MEOW_QBT_AURORA_FONTE" ] || return 1
  grep -qE "^[[:space:]]*${MEOW_QBT_NOME_AURORA}\)" "$MEOW_QBT_AURORA_FONTE"
}

_meow_qbt_receita() {
  [ "$MEOW_QBT_JA_AVISOU" = "1" ] && return 0
  MEOW_QBT_JA_AVISOU=1
  meow_pendencia_acionavel qbittorrent-tema-fora-da-lista \
    "O qBittorrent é configurado por outro projeto seu, cuja lista de temas é fechada — enquanto o tema '$MEOW_QBT_NOME_AURORA' não estiver na lista dele, não há como eu aplicar o tema no app" \
    ""
  return 0
}

_meow_qbt_backup() {
  local alvo="$1" dir base
  meow_guardar_antes "$1"
  [ -e "$alvo" ] || return 0
  base="$(basename "$alvo")"
  dir="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/${_MEOW_QBT_ISO:-$(date +%Y-%m-%dT%H-%M-%S)}"
  mkdir -p "$dir" || { meow_erro "não consegui criar $dir"; return 1; }
  cp -a -- "$alvo" "$dir/$base" || { meow_erro "backup de $alvo falhou"; return 1; }
  meow_info "backup: $dir/$base"
  return 0
}

_meow_qbt_instalar_tema() {
  local origem="$1" destino="$2" dir tmp
  meow_destino_permitido "$destino" || return "$MEOW_ERRO"
  cmp -s -- "$origem" "$destino" && return "$MEOW_OK"

  if meow_seco; then
    meow_muda "instalaria $destino"
    return "$MEOW_DIVERGENTE"
  fi

  _meow_qbt_backup "$destino" || return "$MEOW_ERRO"
  dir="$(dirname "$destino")"
  mkdir -p "$dir" || return "$MEOW_ERRO"
  tmp="$(mktemp -p "$dir" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  cp -- "$origem" "$tmp"     || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod 644 "$tmp"
  mv -f -- "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

_meow_qbt_no_ar() {
  local conf_dir conf
  conf_dir="$(_meow_qbt_conf_dir)" || return 0
  conf="$conf_dir/qBittorrent.conf"
  [ -f "$conf" ] || return 0
  grep -qxF 'General\UseCustomUITheme=true' "$conf" || return 0
  grep -F 'General\CustomUIThemePath=' "$conf" | head -1 | cut -d= -f2-
  return 0
}

_meow_qbt_alvo() {
  local conf_dir
  conf_dir="$(_meow_qbt_conf_dir)" || return 1
  printf '%s' "$conf_dir/themes/$MEOW_QBT_ARQUIVO"
}

MEOW_QBT_VEREDITO_AR=""
MEOW_QBT_PODE_PERGUNTAR=""
_MEOW_QBT_NOSSO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/temas-de-apps/qbittorrent/tema-nosso"
_meow_qbt_ar_ok() {
  local no_ar alvo
  if [ -z "$MEOW_QBT_VEREDITO_AR" ]; then
    no_ar="$(_meow_qbt_no_ar)"; alvo="$(_meow_qbt_alvo)"
    if [ -n "$no_ar" ] && [ "$no_ar" != "$alvo" ] && [ "$no_ar" = "$(cat "$_MEOW_QBT_NOSSO" 2>/dev/null)" ]; then
      meow_pendencia_resolvida qbittorrent-tema-de-terceiro
      meow_info "qBittorrent: o tema do MeowSystem estava em '$no_ar' — passa a '$alvo'"
      MEOW_QBT_VEREDITO_AR="$MEOW_DIVERGENTE"
    else
      meow_app_tema_no_ar qbittorrent "$no_ar" "$alvo" \
                          "$MEOW_QBT_NOME_AURORA" "$MEOW_QBT_PODE_PERGUNTAR"
      MEOW_QBT_VEREDITO_AR=$?
    fi
  fi
  return "$MEOW_QBT_VEREDITO_AR"
}

MEOW_QBT_DISSE_O_AR=0
_meow_qbt_dizer_o_ar() {
  local no_ar
  [ "$MEOW_QBT_DISSE_O_AR" = "1" ] && return 0
  MEOW_QBT_DISSE_O_AR=1
  no_ar="$(_meow_qbt_no_ar)"
  [ -n "$no_ar" ] || return 0
  [ "$no_ar" = "$(_meow_qbt_alvo)" ] && return 0
  meow_pula "qBittorrent: já está com o tema '$no_ar', que não veio daqui — o tema do pack não é escrito por cima"
  return 0
}

MEOW_QBT_ESCRITOR=""
_meow_qbt_aberto() { pgrep -x qbittorrent >/dev/null 2>&1; }

_meow_qbt_conf_escrever() {
  local conf="$1" usar="$2" caminho="${3:-}"
  meow_destino_permitido "$conf" || return "$MEOW_ERRO"
  MEOW_PY_SECO="$(meow_seco && echo 1 || echo 0)" \
  python3 -I - "$conf" "$usar" "$caminho" <<'PYFIM'
import os, sys, tempfile
conf, usar, caminho = sys.argv[1:4]
seco = os.environ.get("MEOW_PY_SECO") == "1"
quer = {"General\\UseCustomUITheme": usar}
if caminho:
    quer["General\\CustomUIThemePath"] = caminho
try:
    with open(conf, encoding="utf-8") as fh:
        linhas = fh.read().split("\n")
except FileNotFoundError:
    linhas = []
saida, secao, feitas, achou_secao = [], None, set(), False
def fecha_secao():
    for chave, valor in quer.items():
        if chave not in feitas:
            saida.append(f"{chave}={valor}")
            feitas.add(chave)
for linha in linhas:
    if linha.startswith("[") and linha.rstrip().endswith("]"):
        if secao == "[Preferences]":
            vazia = saida and saida[-1] == ""
            if vazia:
                saida.pop()
            fecha_secao()
            if vazia:
                saida.append("")
        secao = linha.strip()
        achou_secao = achou_secao or secao == "[Preferences]"
        saida.append(linha)
        continue
    chave = linha.split("=", 1)[0]
    if secao == "[Preferences]" and chave in quer:
        saida.append(f"{chave}={quer[chave]}")
        feitas.add(chave)
        continue
    saida.append(linha)
if secao == "[Preferences]":
    fecha_secao()
if not achou_secao:
    if saida and saida[-1] != "":
        saida.append("")
    saida.append("[Preferences]")
    fecha_secao()
texto = "\n".join(saida)
if linhas and "\n".join(linhas) == texto:
    sys.exit(0)
if seco:
    sys.exit(1)
pasta = os.path.dirname(conf) or "."
os.makedirs(pasta, exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=pasta, prefix=".meow-qbt.")
with os.fdopen(fd, "w", encoding="utf-8") as fh:
    fh.write(texto if texto.endswith("\n") or not texto else texto + "\n")
os.chmod(tmp, 0o644)
os.replace(tmp, conf)
sys.exit(1)
PYFIM
}

meow_app_instalado() { meow_flatpak_tem "$MEOW_QBT_APP_ID" || meow_tem qbittorrent; }

_meow_qbt_pronto() {
  meow_app_instalado || { meow_pula "qBittorrent não instalado"; return "$MEOW_SEM_DEPENDENCIA"; }
  _meow_qbt_conf_dir >/dev/null || {
    if meow_tem qbittorrent; then
      _meow_qbt_avisar_nativo
    else
      meow_pula "qBittorrent: falta o comando flatpak"
    fi
    return "$MEOW_SEM_DEPENDENCIA"
  }
  if [ -z "$MEOW_QBT_ORIGEM" ]; then
    meow_pula "o pack ativo não declara tema para o qBittorrent (apps.qbittorrent no pack.json)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -s "$MEOW_QBT_ORIGEM" ]; then
    meow_aviso "falta o tema em $MEOW_QBT_ORIGEM (veja a PROCEDENCIA.md do pack para rebaixar)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  meow_pendencia_resolvida qbittorrent-conf-fora-de-escopo
  if [ -n "$MEOW_QBT_AURORA_FONTE" ] && [ -f "$MEOW_QBT_AURORA_FONTE" ]; then
    MEOW_QBT_ESCRITOR="aurora"
    if ! _meow_qbt_aurora_destravado; then
      _meow_qbt_dizer_o_ar
      _meow_qbt_receita
      return "$MEOW_SEM_DEPENDENCIA"
    fi
  else
    MEOW_QBT_ESCRITOR="proprio"
  fi
  meow_pendencia_resolvida qbittorrent-tema-fora-da-lista
  _meow_qbt_ar_ok
  if [ $? = "$MEOW_SEM_DEPENDENCIA" ]; then
    _meow_qbt_dizer_o_ar
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

meow_app_detectar() {
  _meow_qbt_pronto || return "$MEOW_SEM_DEPENDENCIA"
  if [ "$MEOW_QBT_ESCRITOR" = "aurora" ]; then
    meow_ok "qBittorrent presente e o Aurora conhece '$MEOW_QBT_NOME_AURORA'"
  else
    meow_ok "qBittorrent presente, e o tema do pack $MEOW_QBT_NOME_AURORA é escrito por aqui"
  fi
  return "$MEOW_OK"
}

meow_app_conferir() {
  _meow_qbt_pronto || return "$MEOW_SEM_DEPENDENCIA"

  local conf_dir conf destino divergiu=0
  conf_dir="$(_meow_qbt_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  conf="$conf_dir/qBittorrent.conf"
  destino="$conf_dir/themes/$MEOW_QBT_ARQUIVO"

  cmp -s -- "$MEOW_QBT_ORIGEM" "$destino" || {
    meow_muda "o .qbtheme não está instalado (ou está diferente) em $destino"
    divergiu=1
  }

  if [ -f "$conf" ]; then
    grep -qxF "General\\CustomUIThemePath=$destino" "$conf" || {
      meow_muda "CustomUIThemePath não aponta para o nosso tema"
      divergiu=1
    }
    grep -qxF 'General\UseCustomUITheme=true' "$conf" || {
      meow_muda "UseCustomUITheme não está em true"
      divergiu=1
    }
  else
    meow_muda "$conf ainda não existe"
    divergiu=1
  fi

  if [ "$MEOW_QBT_ESCRITOR" = "aurora" ]; then
    [ "$(cat "$MEOW_QBT_AURORA_ESTADO" 2>/dev/null)" = "$MEOW_QBT_NOME_AURORA" ] || {
      meow_muda "o estado do Aurora não diz '$MEOW_QBT_NOME_AURORA'"
      divergiu=1
    }
  fi

  if [ "$divergiu" = "0" ]; then
    meow_ok "qBittorrent com o tema do pack $MEOW_QBT_NOME_AURORA aplicado"
    return "$MEOW_OK"
  fi
  return "$MEOW_DIVERGENTE"
}

meow_app_aplicar() {
  MEOW_QBT_PODE_PERGUNTAR="pergunte"
  _meow_qbt_pronto || return "$MEOW_SEM_DEPENDENCIA"

  meow_app_conferir >/dev/null 2>&1 && {
    meow_ok "qBittorrent já está com o tema do pack $MEOW_QBT_NOME_AURORA — nada a fazer"
    return "$MEOW_OK"
  }

  _MEOW_QBT_ISO="$(date +%Y-%m-%dT%H-%M-%S)"
  local conf_dir destino rc
  conf_dir="$(_meow_qbt_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  destino="$conf_dir/themes/$MEOW_QBT_ARQUIVO"

  if [ -z "$MEOW_QBT_SHA256" ]; then
    meow_aviso "o pack ${MEOW_QBT_NOME_AURORA:-ativo} não declara sha256 para este .qbtheme — instalando sem conferir integridade"
  elif meow_tem sha256sum; then
    local soma
    soma="$(sha256sum -- "$MEOW_QBT_ORIGEM" 2>/dev/null | cut -d' ' -f1)"
    if [ "$soma" != "$MEOW_QBT_SHA256" ]; then
      meow_erro "sha256 do tema não confere (esperado $MEOW_QBT_SHA256, veio $soma)"
      return "$MEOW_ERRO"
    fi
  fi

  _meow_qbt_instalar_tema "$MEOW_QBT_ORIGEM" "$destino"
  rc=$?
  case "$rc" in
    0) : ;;
    1) meow_seco || meow_muda "tema instalado em $destino" ;;
    *) meow_erro "não consegui instalar o .qbtheme"; return "$MEOW_ERRO" ;;
  esac

  if [ "$MEOW_QBT_ESCRITOR" = "proprio" ]; then
    if _meow_qbt_aberto; then
      meow_pula "qBittorrent: o app está aberto — ele reescreve o conf ao sair; o tema já está no disco e entra na próxima passada com ele fechado"
      return "$MEOW_SEM_DEPENDENCIA"
    fi
    if ! meow_seco; then
      _meow_qbt_backup "$conf_dir/qBittorrent.conf" || return "$MEOW_ERRO"
    fi
    _meow_qbt_conf_escrever "$conf_dir/qBittorrent.conf" true "$destino"
    case $? in
      0|1) : ;;
      *) meow_erro "não consegui escrever $conf_dir/qBittorrent.conf"; return "$MEOW_ERRO" ;;
    esac
    meow_seco && { meow_muda "apontaria o qBittorrent.conf para $destino"; return "$MEOW_DIVERGENTE"; }
    if meow_app_conferir >/dev/null 2>&1; then
      mkdir -p "$(dirname -- "$_MEOW_QBT_NOSSO")" && printf '%s\n' "$destino" > "$_MEOW_QBT_NOSSO"
      meow_ok "qBittorrent com o tema do pack $MEOW_QBT_NOME_AURORA aplicado"
      return "$MEOW_DIVERGENTE"
    fi
    meow_erro "o qBittorrent.conf foi escrito e não reflete o tema"
    return "$MEOW_ERRO"
  fi

  if [ "$(cat "$MEOW_QBT_AURORA_ESTADO" 2>/dev/null)" != "$MEOW_QBT_NOME_AURORA" ]; then
    if meow_seco; then
      meow_muda "gravaria '$MEOW_QBT_NOME_AURORA' em $MEOW_QBT_AURORA_ESTADO"
    else
      _meow_qbt_backup "$MEOW_QBT_AURORA_ESTADO" || return "$MEOW_ERRO"
      meow_escrever "$MEOW_QBT_AURORA_ESTADO" "$MEOW_QBT_NOME_AURORA" 644
      case $? in
        1) meow_muda "estado do Aurora -> $MEOW_QBT_NOME_AURORA" ;;
        2) meow_erro "não consegui gravar $MEOW_QBT_AURORA_ESTADO"; return "$MEOW_ERRO" ;;
      esac
    fi
  fi

  if meow_seco; then
    meow_muda "rodaria: $MEOW_QBT_AURORA_FONTE --tema $MEOW_QBT_NOME_AURORA"
    return "$MEOW_DIVERGENTE"
  fi

  meow_info "delegando o conf ao Aurora (ele é o dono do qBittorrent.conf)"
  if ! bash "$MEOW_QBT_AURORA_FONTE" --tema "$MEOW_QBT_NOME_AURORA"; then
    meow_erro "o script do Aurora falhou ao aplicar o tema"
    return "$MEOW_ERRO"
  fi

  if meow_app_conferir >/dev/null 2>&1; then
    meow_ok "qBittorrent com o tema do pack $MEOW_QBT_NOME_AURORA aplicado"
    meow_aviso "atenção: o acento deste .qbtheme é o do tema upstream, e não o da paleta — ver a PROCEDENCIA.md do pack"
    return "$MEOW_DIVERGENTE"
  fi
  meow_aviso "o Aurora rodou mas o conf ainda não reflete o tema — ele adia a gravação"
  meow_aviso "quando há download em andamento (fechar o app perderia progresso)."
  meow_aviso "nada se perdeu: o tema já está no disco e o próximo ciclo ocioso aplica."
  return "$MEOW_DIVERGENTE"
}

_MEOW_QBT_TEMA_AURORA_PADRAO="${MEOW_QBT_TEMA_AURORA_PADRAO:-dracula}"

meow_app_reverter() {
  _meow_qbt_pronto || return "$MEOW_SEM_DEPENDENCIA"

  local conf_dir destino estado mudou=0
  conf_dir="$(_meow_qbt_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  destino="$conf_dir/themes/$MEOW_QBT_ARQUIVO"
  estado="$(cat "$MEOW_QBT_AURORA_ESTADO" 2>/dev/null)"

  if [ ! -f "$destino" ] && [ "$estado" != "$MEOW_QBT_NOME_AURORA" ]; then
    meow_ok "qBittorrent já estava sem o tema do pack"
    return "$MEOW_OK"
  fi

  if [ "$MEOW_QBT_ESCRITOR" = "proprio" ]; then
    if _meow_qbt_aberto; then
      meow_pula "qBittorrent: o app está aberto — feche-o para o tema sair"
      return "$MEOW_SEM_DEPENDENCIA"
    fi
    if grep -qxF "General\\CustomUIThemePath=$destino" "$conf_dir/qBittorrent.conf" 2>/dev/null; then
      if meow_seco; then meow_muda "desligaria o tema no qBittorrent.conf"; else
        _MEOW_QBT_ISO="$(date +%Y-%m-%dT%H-%M-%S)"
        _meow_qbt_backup "$conf_dir/qBittorrent.conf" || return "$MEOW_ERRO"
        _meow_qbt_conf_escrever "$conf_dir/qBittorrent.conf" false ""
        [ $? -ge 2 ] && { meow_erro "não consegui escrever o qBittorrent.conf"; return "$MEOW_ERRO"; }
        meow_muda "tema desligado no qBittorrent.conf"
      fi
      mudou=1
    fi
    if [ -f "$destino" ]; then
      if meow_seco; then meow_muda "removeria $destino"; elif rm -f "$destino"; then meow_muda "tema removido de $destino"; fi
      mudou=1
    fi
    meow_seco && return "$MEOW_DIVERGENTE"
    [ "$mudou" = "0" ] && { meow_ok "qBittorrent já estava sem o tema do pack"; return "$MEOW_OK"; }
    meow_info "tire 'qbittorrent' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
    return "$MEOW_DIVERGENTE"
  fi

  if meow_seco; then
    [ -f "$destino" ] && meow_muda "removeria $destino"
    [ "$estado" = "$MEOW_QBT_NOME_AURORA" ] && \
      meow_muda "gravaria '$_MEOW_QBT_TEMA_AURORA_PADRAO' em $MEOW_QBT_AURORA_ESTADO"
    meow_muda "rodaria: $MEOW_QBT_AURORA_FONTE --tema $_MEOW_QBT_TEMA_AURORA_PADRAO"
    return "$MEOW_DIVERGENTE"
  fi

  if [ "$estado" = "$MEOW_QBT_NOME_AURORA" ]; then
    if printf '%s' "$_MEOW_QBT_TEMA_AURORA_PADRAO" > "$MEOW_QBT_AURORA_ESTADO" 2>/dev/null; then
      mudou=1; meow_muda "estado do Aurora -> $_MEOW_QBT_TEMA_AURORA_PADRAO"
    else
      meow_erro "não consegui gravar $MEOW_QBT_AURORA_ESTADO"
      return "$MEOW_ERRO"
    fi
  fi

  meow_info "delegando o conf ao Aurora (ele é o dono do qBittorrent.conf)"
  if ! bash "$MEOW_QBT_AURORA_FONTE" --tema "$_MEOW_QBT_TEMA_AURORA_PADRAO"; then
    meow_erro "o script do Aurora falhou ao devolver o tema"
    return "$MEOW_ERRO"
  fi

  if [ -f "$destino" ]; then
    if grep -qxF "General\\CustomUIThemePath=$destino" "$conf_dir/qBittorrent.conf" 2>/dev/null; then
      meow_aviso "o conf ainda aponta para $destino — o Aurora adiou a gravação (download em andamento?)"
      meow_aviso "o .qbtheme fica onde está; a próxima passada com o app ocioso troca"
    elif rm -f "$destino"; then
      mudou=1; meow_muda "tema removido de $destino"
    fi
  fi

  [ "$mudou" = "0" ] && { meow_ok "qBittorrent já estava sem o tema do pack"; return "$MEOW_OK"; }
  meow_ok "qBittorrent de volta ao tema $_MEOW_QBT_TEMA_AURORA_PADRAO do Aurora"
  meow_info "tire 'qbittorrent' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}

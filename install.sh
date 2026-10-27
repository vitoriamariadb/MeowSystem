#!/usr/bin/env bash

MEOW_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"
# shellcheck source=lib/preflight.sh
. "$MEOW_RAIZ/lib/preflight.sh"

CONF_PADRAO="$MEOW_RAIZ/meow.conf.exemplo"
CONF="${MEOW_CONF:-$HOME/.config/meow/meow.conf}"

declare -a FEITOS=() CONFEREM=() PULADOS=() FALHOS=()

declare -a PULADOS_OPTIN=()

pular_por_optin() {
  PULADOS_OPTIN+=("$1")
  meow_pula 'LANCADOR_SISTEMA="nao" — os .desktop de /usr/share ficam intactos'
  return "$MEOW_SEM_DEPENDENCIA"
}
PASSO=0
TOTAL=8

passo() { PASSO=$((PASSO+1)); meow_passo "[$PASSO/$TOTAL] $*"; }

concluir() {
  local nome="$1" rc="$2"
  case "$rc" in
    0) CONFEREM+=("$nome") ;;
    1) FEITOS+=("$nome") ;;
    3|4) PULADOS+=("$nome") ;;
    *) FALHOS+=("$nome") ;;
  esac
}

etapa_conf_ler() {
  local fonte="$CONF"
  [ -f "$CONF" ] || fonte="$CONF_PADRAO"
  # shellcheck disable=SC1090
  set -a; . "$fonte" || { set +a; meow_erro "$fonte tem erro de sintaxe"; return "$MEOW_ERRO"; }; set +a
  local v
  for v in FLAVOR ACCENT MODO LOGO; do
    [ -n "${!v:-}" ] || { meow_erro "$v não está definida em $fonte"; return "$MEOW_ERRO"; }
  done
  FLAVOR="$(meow_flavor)"
  return 0
}

etapa_backup_tema() {
  passo "Backup do tema de antes"
  local cosmic; cosmic="$(meow_cosmic_dir)"
  local velho primeiro="" mais_velho=""
  for velho in "$MEOW_ESTADO"/backups/*-tema-*; do
    [ -d "$velho" ] || continue
    case "$velho" in *-tema-PRIMEIRO-*) primeiro="$velho"; break ;; esac
    case "$velho" in *-tema-v1) continue ;; esac
    [ -n "$mais_velho" ] || mais_velho="$velho"
  done
  if [ -n "$primeiro" ]; then
    meow_ok "já há backup de antes da instalação em $(basename "$primeiro")"
    return 0
  fi
  if [ -n "$mais_velho" ]; then
    meow_ok "esta máquina já rodou o MeowSystem — não há estado 'de antes' a gravar"
    meow_info "  o tema que está no disco agora já é obra nossa; chamá-lo de"
    meow_info "  \"pre-instalacao\" seria uma mentira no nome do arquivo."
    meow_info "  o mais antigo em backups/ é $(basename "$mais_velho") —"
    meow_info "  o COMO-RESTAURAR.txt dentro dele diz como voltar à mão."
    return 0
  fi

  local -a arvores=()
  local a
  for a in "$cosmic"/com.system76.CosmicTheme.*; do
    [ -d "$a" ] && arvores+=("$a")
  done
  if [ "${#arvores[@]}" = "0" ]; then
    meow_pula "o COSMIC ainda não escreveu tema aqui — não há estado anterior a guardar"
    meow_info "  o primeiro 'meow tema' desta máquina vira o ponto de volta"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local destino="$MEOW_ESTADO/backups/$(date +%Y-%m-%dT%H-%M-%S)-tema-PRIMEIRO-pre-instalacao"
  if meow_seco; then
    meow_muda "guardaria ${#arvores[@]} árvore(s) de tema de $cosmic em backups/*-tema-PRIMEIRO-pre-instalacao"
    return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$destino" || { meow_erro "não consegui criar $destino"; return "$MEOW_ERRO"; }
  for a in "${arvores[@]}"; do
    cp -a "$a" "$destino/" || { meow_erro "não consegui copiar $(basename "$a")"; return "$MEOW_ERRO"; }
  done

  ( cd "$destino" && find . -type f ! -name manifesto.sha256 -print0 \
      | sort -z | xargs -0 sha256sum > manifesto.sha256 ) 2>/dev/null || true

  local total
  total="$(find "$destino" -type f ! -name manifesto.sha256 ! -name captura.txt 2>/dev/null | wc -l)"
  {
    echo "captura: pre-instalacao"
    echo "quando: $(date -Iseconds)"
    echo "origem: $cosmic"
    echo "arquivos: $total"
  } > "$destino/captura.txt"

  local onde; onde="$(meow_onde_no_painel desfazer)"
  cat > "$destino/COMO-RESTAURAR.txt" <<FIM
Estado de $cosmic (só as árvores de tema) de ANTES do MeowSystem nesta
máquina, guardado em $(date '+%d/%m/%Y %H:%M:%S').

É o que o "meow desfazer" devolve${onde:+ — no painel, $onde}.

Para voltar exatamente a este estado, à mão:

    cp -a $destino/com.system76.CosmicTheme.* $cosmic/

Para conferir que nada se corrompeu aqui dentro:

    cd $destino && sha256sum -c manifesto.sha256

O COSMIC relê por inotify: a interface acompanha em segundos, sem relogar.
FIM

  meow_muda "$total arquivo(s) guardados em $(basename "$destino")"
  meow_info "  é o que o 'meow desfazer' devolve — e é desta máquina"
  return "$MEOW_DIVERGENTE"
}

etapa_conf() {
  passo "Configuração"
  local fonte="$CONF" mudou=0
  if [ -f "$CONF" ]; then
    meow_ok "meow.conf já existe em $CONF"
    if meow_tem python3; then
      local antes_pack="" antes_flavor=""
      [ -f "$MEOW_ESTADO/pack-do-install" ] && IFS=$'\t' read -r antes_pack antes_flavor < "$MEOW_ESTADO/pack-do-install"
      local migrar=("$MEOW_RAIZ/scripts/migrar_conf.py" "$CONF" "$CONF_PADRAO"
                    --pack-de-antes "$antes_pack" "$antes_flavor")
      if meow_seco; then
        local pendente
        if pendente="$(python3 "${migrar[@]}" --conferir 2>/dev/null)"; then :; else
          meow_muda "$pendente"; mudou=1
        fi
      else
        local saida
        saida="$(python3 "${migrar[@]}" 2>&1)"
        case $? in
          0) [ -n "$saida" ] && { meow_ok "$saida"; mudou=1; } ;;
          *) meow_aviso "não consegui conferir as chaves novas do meow.conf" ;;
        esac
      fi
    fi
  else
    local conteudo; conteudo="$(cat "$CONF_PADRAO")"
    meow_escrever "$CONF" "$conteudo" 644
    case $? in
      0) meow_ok "meow.conf criado em $CONF" ;;
      1) mudou=1
         if meow_seco; then
           meow_info "no seco, lendo os valores de meow.conf.exemplo"
           fonte="$CONF_PADRAO"
         else
           meow_ok "meow.conf criado em $CONF"
         fi ;;
      *) meow_erro "não consegui criar $CONF"; return "$MEOW_ERRO" ;;
    esac
  fi
  # shellcheck disable=SC1090
  set -a; . "$fonte" || { set +a; meow_erro "$fonte tem erro de sintaxe"; return "$MEOW_ERRO"; }; set +a
  for v in FLAVOR ACCENT MODO LOGO; do
    if [ -z "${!v:-}" ]; then
      meow_erro "$v não está definida em $fonte"
      return "$MEOW_ERRO"
    fi
  done
  FLAVOR="$(meow_flavor)"
  meow_info "flavor=$FLAVOR accent=$ACCENT modo=$MODO logo=$LOGO"
  if ! meow_seco && [ "$(cat "$MEOW_ESTADO/pack-do-install" 2>/dev/null)" != "${PACK:-}"$'\t'"$FLAVOR" ]; then
    mkdir -p "$MEOW_ESTADO" && printf '%s\t%s\n' "${PACK:-}" "$FLAVOR" > "$MEOW_ESTADO/pack-do-install"
  fi

  [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
  return 0
}

COMPLETIONS_DIR="${MEOW_COMPLETIONS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions}"
COMPLETIONS_SISTEMA=/usr/local/share/zsh/site-functions

instalar_completion() {
  local origem="$MEOW_RAIZ/assets/zsh/_meow" destino="$COMPLETIONS_DIR/_meow" tmp rc

  if [ "${MEOW_SEM_COMPLETIONS:-0}" = "1" ]; then
    meow_pula "completions do zsh puladas (MEOW_SEM_COMPLETIONS=1)"
    return "$MEOW_OK"
  fi
  [ -f "$origem" ] || { meow_erro "falta $origem"; return "$MEOW_ERRO"; }
  if [ -z "${MEOW_COMPLETIONS_DIR:-}" ]; then
    completion_no_sistema; rc=$?
    [ "$rc" = "$MEOW_SEM_DEPENDENCIA" ] || return "$rc"
  fi
  if [ ! -d "$COMPLETIONS_DIR" ] && [ -z "${MEOW_COMPLETIONS_DIR:-}" ]; then
    if meow_seco; then
      meow_muda "criaria $COMPLETIONS_DIR e instalaria a completion lá"
      return "$MEOW_DIVERGENTE"
    fi
    mkdir -p "$COMPLETIONS_DIR" 2>/dev/null || { meow_erro "não consegui criar $COMPLETIONS_DIR"; return "$MEOW_ERRO"; }
  fi
  if [ ! -d "$COMPLETIONS_DIR" ]; then
    meow_pula "não achei $COMPLETIONS_DIR — sem lugar no \$fpath para a completion"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ -f "$destino" ] && cmp -s "$origem" "$destino"; then
    meow_ok "completion do zsh já instalada em $destino"
    return "$MEOW_OK"
  fi
  if [ ! -w "$COMPLETIONS_DIR" ]; then
    meow_pula "completion do zsh pulada: '$COMPLETIONS_DIR' não é gravável (é do root)"
    meow_info "  para outro diretório do seu \$fpath: MEOW_COMPLETIONS_DIR=<dir> ./install.sh"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "instalaria a completion em $destino"
    return "$MEOW_DIVERGENTE"
  fi

  tmp="$(mktemp -p "$COMPLETIONS_DIR" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  if ! cat "$origem" > "$tmp"; then rm -f "$tmp"; return "$MEOW_ERRO"; fi
  chmod 644 "$tmp"
  meow_guardar_antes "$destino"
  mv -f "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }

  meow_ok "completion do zsh instalada em $destino"
  local viz_p viz_real
  viz_real="$(readlink -m -- "$destino")"
  for viz_p in ${MEOW_PROIBIDOS_LOCAIS[@]+"${MEOW_PROIBIDOS_LOCAIS[@]}"}; do
    case "$viz_real" in "$viz_p"/*)
      meow_aviso "esse arquivo está em $viz_p, que o vizinhos.conf protege: o dono dele vai versioná-lo"
      break ;;
    esac
  done
  meow_info "para não instalar: MEOW_SEM_COMPLETIONS=1 ./install.sh"
  meow_info "o TAB só passa a funcionar no próximo terminal (o compinit lê o fpath no início)"
  if meow_tem zsh && ! zsh -f -c 'print -l -- $fpath' 2>/dev/null | grep -qxF -- "$COMPLETIONS_DIR"; then
    meow_info "o bloco do MeowSystem no terminal põe $COMPLETIONS_DIR no fpath do zsh"
  fi
  return "$MEOW_DIVERGENTE"
}

completion_no_sistema() {
  local origem="$MEOW_RAIZ/assets/zsh/_meow" sistema="$COMPLETIONS_SISTEMA/_meow"
  local velha="$COMPLETIONS_DIR/_meow" mudou=0

  meow_tem zsh || return "$MEOW_SEM_DEPENDENCIA"
  zsh -f -c 'print -l -- $fpath' 2>/dev/null | grep -qxF -- "$COMPLETIONS_SISTEMA" \
    || return "$MEOW_SEM_DEPENDENCIA"

  if cmp -s "$origem" "$sistema"; then
    meow_ok "completion do zsh já instalada em $sistema, onde o zsh procura"
  else
    meow_ponte_viva && grep -qxF 'completion-instalar)' "$MEOW_PONTE" 2>/dev/null \
      || return "$MEOW_SEM_DEPENDENCIA"
    if meow_seco; then
      meow_muda "instalaria a completion em $sistema, pela ponte root"
    elif meow_ponte completion-instalar </dev/null >/dev/null 2>&1 && cmp -s "$origem" "$sistema"; then
      meow_muda "completion do zsh instalada em $sistema, pela ponte root — o TAB vale no próximo terminal"
    else
      meow_aviso "a ponte root não instalou a completion em $sistema — fica na casa do usuário"
      return "$MEOW_SEM_DEPENDENCIA"
    fi
    mudou=1
  fi

  if [ -e "$velha" ]; then
    if meow_seco; then
      meow_muda "removeria $velha — a cópia da P44, que o sistema já não precisa"
    else
      rm -f "$velha" && meow_muda "removida $velha — a cópia da P44; vale a de $sistema"
    fi
    mudou=1
  fi
  [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}

semear_estado_do_usuario() {
  meow_estado_com_padrao papeis-de-parede BANIDOS.txt >/dev/null
  return 0
}

registrar_driver_de_merge() {
  command -v git >/dev/null 2>&1 || return 0
  [ "$(git -C "$MEOW_RAIZ" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$MEOW_RAIZ" && pwd -P)" ] || return 0
  [ "$(git -C "$MEOW_RAIZ" config --local --get merge.ours.driver 2>/dev/null)" = "true" ] && return 0

  if meow_seco; then
    meow_muda "registraria merge.ours.driver neste clone (o .gitattributes já o declara)"
    return "$MEOW_DIVERGENTE"
  fi
  if git -C "$MEOW_RAIZ" config --local merge.ours.driver true 2>/dev/null; then
    meow_ok "driver de merge 'ours' registrado neste clone"
    return "$MEOW_DIVERGENTE"
  fi
  meow_aviso "não consegui registrar merge.ours.driver — o merge=ours do .gitattributes fica inerte neste clone"
  return 0
}

etapa_cli() {
  passo "CLI meow e completions"
  local mudou=0 rc

  meow_escrever "$HOME/.local/bin/meow" "$(cat "$MEOW_RAIZ/bin/meow")" 755
  rc=$?
  case "$rc" in
    0) meow_ok "~/.local/bin/meow já está atualizado" ;;
    1) mudou=1; meow_seco || meow_ok "~/.local/bin/meow instalado" ;;
    *) meow_erro "não consegui instalar ~/.local/bin/meow"; return "$MEOW_ERRO" ;;
  esac
  if ! meow_seco && [ -f "$HOME/.local/bin/meow" ] && [ ! -x "$HOME/.local/bin/meow" ]; then
    chmod 755 "$HOME/.local/bin/meow"
    mudou=1
  fi

  meow_escrever "$MEOW_ESTADO/raiz" "$MEOW_RAIZ" 644
  rc=$?
  [ "$rc" -ge 2 ] && { meow_erro "não consegui gravar $MEOW_ESTADO/raiz"; return "$MEOW_ERRO"; }
  [ "$rc" = "1" ] && mudou=1

  semear_estado_do_usuario
  registrar_driver_de_merge
  rc=$?
  [ "$rc" = "1" ] && mudou=1

  instalar_completion
  rc=$?
  case "$rc" in
    1)   mudou=1 ;;
    0|3) ;;
    *)   return "$MEOW_ERRO" ;;
  esac

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) meow_aviso "~/.local/bin não está no \$PATH — o comando 'meow' não vai ser achado" ;;
  esac

  [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
  return 0
}

etapa_atalho() {
  passo "Atalho do painel de configuração"
  "$MEOW_RAIZ/scripts/atalho.sh"
  return $?
}

etapa_pacotes() {
  passo "Pacotes do sistema"

  local -A NECESSARIOS=(
    [rsvg-convert]=librsvg2-bin
    [convert]=imagemagick
    [gtk-update-icon-cache]=libgtk-3-bin
    [python3]=python3
    [git]=git
    [btop]=btop
    [batcat]=bat
    [curl]=curl
    [xz]=xz-utils
    [unzip]=unzip
  )
  local faltam=()
  local b
  for b in "${!NECESSARIOS[@]}"; do
    meow_tem "$b" || faltam+=("${NECESSARIOS[$b]}")
  done
  [ -d /usr/share/icons/Papirus-Dark ] || faltam+=(papirus-icon-theme)
  [ -d /usr/share/fonts/opentype/fira ] || ! apt-cache show pop-fonts >/dev/null 2>&1 \
    || faltam+=(pop-fonts)

  python3 -I -c 'import numpy' 2>/dev/null || faltam+=(python3-numpy)

  local prova pacote
  if [ "${MIDIA:-sim}" = "sim" ] || [ "${LEITURA_APPLET:-sim}" = "sim" ]; then
    while IFS='|' read -r prova pacote; do
      [ -e "$prova" ] || faltam+=("$pacote")
    done <<< "$MEOW_DEPS_DOS_APPLETS"
  fi
  local ppa_fastfetch=0
  if [ "${FASTFETCH_LOGO:-sim}" != "nao" ] && ! meow_tem fastfetch; then
    ppa_fastfetch=1
    meow_tem add-apt-repository || faltam+=(software-properties-common)
  fi

  if [ ${#faltam[@]} -eq 0 ] && [ "$ppa_fastfetch" = 0 ]; then
    meow_ok "todos os pacotes necessários já estão instalados"
    return 0
  fi
  if [ ${#faltam[@]} -eq 0 ]; then
    _pacotes_fastfetch
    return $?
  fi

  meow_info "faltam: ${faltam[*]}"
  if meow_seco; then
    meow_muda "rodaria: sudo apt-get install -y --no-install-recommends ${faltam[*]}"
    return "$MEOW_DIVERGENTE"
  fi

  if ! meow_tem sudo; then
    meow_aviso "sudo não encontrado — instale à mão:"
    meow_info "  apt install ${faltam[*]}"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_info "vou rodar como root, e só isto:"
  printf '      sudo apt-get install -y --no-install-recommends %s\n' "${faltam[*]}"

  if ! sudo apt-get install -y --no-install-recommends "${faltam[@]}" >/dev/null 2>&1; then
    meow_aviso "a instalação falhou (sem sudo? sem rede?) — seguindo sem esses pacotes"
    meow_info "  sudo apt-get install ${faltam[*]}"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  meow_ok "instalados: ${faltam[*]}"
  [ "$ppa_fastfetch" = 1 ] && _pacotes_fastfetch
  return "$MEOW_DIVERGENTE"
}

_pacotes_fastfetch() {
  if meow_seco; then
    meow_muda "rodaria: sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch && sudo apt-get install -y fastfetch"
    return "$MEOW_DIVERGENTE"
  fi
  meow_info "vou rodar como root, e só isto:"
  printf '      sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch\n      sudo apt-get install -y fastfetch\n'
  if sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch >/dev/null 2>&1 \
     && sudo apt-get install -y --no-install-recommends fastfetch >/dev/null 2>&1; then
    meow_ok "fastfetch instalado do PPA do autor"
    return "$MEOW_DIVERGENTE"
  fi
  meow_aviso "o fastfetch não desceu (sem rede?) — a próxima passada tenta de novo"
  return "$MEOW_SEM_DEPENDENCIA"
}

etapa_gerar() {
  passo "Gerar temas e ícones a partir da paleta"
  local rc=0
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" --conferir >/dev/null 2>&1 || rc=1
  python3 "$MEOW_RAIZ/scripts/gerar_tema_v1.py" --conferir >/dev/null 2>&1 || rc=1
  if [ "$rc" = "0" ]; then
    meow_ok "os temas já correspondem à paleta"
    return 0
  fi
  if meow_seco; then
    meow_muda "regeraria os temas"
    return "$MEOW_DIVERGENTE"
  fi
  local rc_gt
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" | sed 's/^/  /'
  rc_gt="${PIPESTATUS[0]}"
  case "$rc_gt" in 0) ;; "$MEOW_SEM_DEPENDENCIA") return "$MEOW_SEM_DEPENDENCIA" ;; *) return "$MEOW_ERRO" ;; esac
  python3 "$MEOW_RAIZ/scripts/gerar_tema_v1.py" | sed 's/^/  /'
  rc_gt="${PIPESTATUS[0]}"
  case "$rc_gt" in 0) ;; "$MEOW_SEM_DEPENDENCIA") return "$MEOW_SEM_DEPENDENCIA" ;; *) return "$MEOW_ERRO" ;; esac
  meow_ok "regenerados a partir de $(meow_paleta_nome)"
  return "$MEOW_DIVERGENTE"
}

etapa_tema() {
  passo "Tema"
  local alvo="${FLAVOR}-${ACCENT}"
  local captura; captura="$(meow_captura "$alvo")"

  TEMA_SEM_CAPTURA=""
  if [ -z "$captura" ]; then
    local deriva rc_d
    deriva="$(python3 "$MEOW_RAIZ/scripts/derivar_acento.py" --conferir "$alvo" 2>&1)"; rc_d=$?
    if [ "$rc_d" = "1" ]; then
      if meow_seco; then
        TEMA_SEM_CAPTURA="deriva"
        meow_muda "derivaria a captura de '$alvo' e a aplicaria"
        return "$MEOW_DIVERGENTE"
      fi
      python3 "$MEOW_RAIZ/scripts/derivar_acento.py" "$alvo" | sed 's/^/  /'
      captura="$(meow_captura "$alvo")"
    fi
  fi

  TEMA_NAO_APLICADO=""

  if [ -z "$captura" ]; then
    TEMA_SEM_CAPTURA="falta"
    deriva="${deriva#*não se deriva — }"
    TEMA_NAO_APLICADO="O tema do COSMIC não foi aplicado: não há captura para '$alvo' (${deriva#  })."
    meow_pendencia_acionavel tema-sem-captura "$TEMA_NAO_APLICADO"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local rc
  MEOW_DRY_RUN=0 "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$alvo" --respeitar-gui --conferir >/dev/null 2>&1
  rc=$?
  meow_pendencia_resolvida tema-sem-captura
  case "$rc" in
    0) meow_ok "tema '$alvo' já aplicado"; return 0 ;;
    4) meow_pula "tema '$alvo': a captura está velha — você mexeu em Aparência"
       return 0 ;;
  esac
  if meow_seco; then
    meow_muda "aplicaria o tema '$alvo'"
    return "$MEOW_DIVERGENTE"
  fi
  "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$alvo" --respeitar-gui | sed 's/^/  /'
  rc="${PIPESTATUS[0]}"
  case "$rc" in 0|4) ;; *) return "$MEOW_ERRO" ;; esac
  meow_notificar "MeowSystem" "Tema $alvo aplicado."
  return "$MEOW_DIVERGENTE"
}

etapa_modo() {
  passo "Modo claro/escuro"
  local arq; arq="$(meow_cosmic_dir)/com.system76.CosmicTheme.Mode/$(meow_cosmic_v com.system76.CosmicTheme.Mode)/is_dark"
  local desejado
  case "$MODO" in
    escuro) desejado=true ;;
    claro)  desejado=false ;;
    auto)
      local hora; hora="$(date +%-H)"
      local ini="${MODO_AUTO_CLARO_DE:-7}" fim="${MODO_AUTO_CLARO_ATE:-18}"
      if [ "$hora" -ge "$ini" ] && [ "$hora" -lt "$fim" ]; then
        desejado=false
      else
        desejado=true
      fi
      meow_info "modo automático: ${hora}h → $([ "$desejado" = true ] && echo escuro || echo claro)"
      ;;
    *)      meow_aviso "MODO='$MODO' desconhecido — esperado escuro|claro|auto"; return "$MEOW_ERRO" ;;
  esac
  meow_escrever "$arq" "$desejado" 644
  case $? in
    0) meow_ok "modo $MODO já ativo"; return 0 ;;
    1) meow_ok "modo $MODO aplicado"; return "$MEOW_DIVERGENTE" ;;
    *) meow_erro "não consegui escrever $arq"; return "$MEOW_ERRO" ;;
  esac
}

etapa_svg() {
  passo "Desenhos (SVG normalizados)"
  meow_tem python3 || { meow_pula "python3 não está aqui"; return 0; }
  local pastas=() p
  for p in packs/meowsystem/mascote/ packs/dracula/mascote/ assets/icones/overrides; do
    [ -d "$MEOW_RAIZ/$p" ] && pastas+=("$MEOW_RAIZ/$p")
  done
  for p in "$MEOW_RAIZ"/packs/meowsystem/icones/sistema/leitura-*.svg; do [ -f "$p" ] && pastas+=("$p"); done
  while IFS= read -r p; do [ -n "$p" ] && pastas+=("$p"); done < <(python3 -I - "$MEOW_RAIZ" <<'PYAUT' 2>/dev/null
import glob, json, os, sys
for d in sorted(glob.glob(os.path.join(sys.argv[1], "packs", "*"))):
    try:
        fl = json.load(open(os.path.join(d, "paleta.json"), encoding="utf-8"))["flavors"]
    except Exception:
        continue
    for f in sorted(glob.glob(os.path.join(d, "icones", "apps", "*.svg"))):
        if any(f.endswith("-%s.svg" % x) for x in fl):
            print(f)
PYAUT
  )
  [ "${#pastas[@]}" -gt 0 ] || return 0
  local rc
  if meow_seco; then
    python3 "$MEOW_RAIZ/scripts/normalizar_svg.py" --conferir "${pastas[@]}"; rc=$?
  else
    python3 "$MEOW_RAIZ/scripts/normalizar_svg.py" "${pastas[@]}"; rc=$?
  fi
  [ "$rc" = "0" ] && meow_ok "$(find "${pastas[@]}" -name '*.svg' 2>/dev/null | wc -l) desenho(s) nossos já falam a língua dos renderizadores"
  return "$rc"
}

etapa_icones() {
  passo "Ícones e logo"
  FLAVOR="$FLAVOR" LOGO="$LOGO" ICONES_BASE="${ICONES_BASE:-Papirus-Dark}" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/construir_icones.sh"
  local rc=$?
  [ "$rc" = "1" ] && meow_notificar "MeowSystem" "Ícones e logo atualizados."
  return "$rc"
}

etapa_fontes() {
  passo "Fontes"
  "$MEOW_RAIZ/scripts/instalar_fontes.sh"
  return $?
}

etapa_completar_icones() {
  passo "Ícones que faltavam"
  FLAVOR="$FLAVOR" ACCENT="$ACCENT" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/completar_icones.sh"
  return $?
}

etapa_icones_resgatados() {
  passo "Ícones resgatados do PNG"
  ICONES_RESGATADOS="${ICONES_RESGATADOS:-sim}" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_resgatados.sh" --aplicar
  return $?
}

etapa_icones_apps_dracula() {
  passo "Pack Dracula nos aplicativos"
  ICONES_DRACULA="${ICONES_DRACULA:-sim}" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_apps_dracula.sh" --aplicar
  return $?
}

etapa_icones_apps_arcticons() {
  passo "Ícones de aplicativo em Arcticons"
  "$MEOW_RAIZ/scripts/construir_convertidos.sh" --so-mao || true
  FLAVOR="${FLAVOR:-}" \
    ICONES_COR_MARCA="${ICONES_COR_MARCA:-nao}" \
    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_apps_arcticons.sh"
  return $?
}

etapa_icones_bandeja() {
  passo "Ícones da bandeja"
  ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_bandeja.sh"
  return $?
}

etapa_icones_tray_steam() {
  passo "Ícone da bandeja da Steam"
  "$MEOW_RAIZ/scripts/icones_tray_steam.sh"
  return $?
}

etapa_icones_tray_zapzap() {
  passo "Ícone da bandeja do ZapZap"
  "$MEOW_RAIZ/scripts/icones_tray_zapzap.sh"
  return $?
}

etapa_absolutos() {
  passo "Ícone por caminho absoluto"
  if [ "${LANCADOR_SISTEMA:-nao}" != "sim" ]; then
    pular_por_optin absolutos; return $?
  fi
  ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_absolutos.sh"
  return $?
}

etapa_ocultar_casa() {
  passo "Aplicativos ocultos fora de /usr/share"
  "$MEOW_RAIZ/scripts/ocultar_casa.sh"
  local rc=$?
  [ "$rc" = "$MEOW_SEM_DEPENDENCIA" ] && [ "${LANCADOR_SISTEMA:-nao}" != "sim" ] && PULADOS_OPTIN+=(ocultar_casa)
  return "$rc"
}

etapa_janela_dock() {
  passo "Janelas que a dock casa pelo app_id"
  "$MEOW_RAIZ/scripts/appid_dock.sh" --aplicar
  return $?
}

etapa_lancador() {
  passo "Lançadores órfãos e o banco de tipos do home"
  "$MEOW_RAIZ/scripts/lancador.sh" --aplicar
  return $?
}

etapa_mimetypes() {
  passo "Ícones de tipo de arquivo"
  ICONES_FLAVOR="${ICONES_FLAVOR:-}" \
    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_mimetypes.sh"
  return $?
}

etapa_icones_sistema() {
  passo "Ícones do sistema"
  ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_sistema.sh"
  return $?
}

etapa_ocultar() {
  passo "Aplicativos ocultos do lançador"
  if [ "${LANCADOR_SISTEMA:-nao}" != "sim" ]; then
    pular_por_optin ocultar; return $?
  fi
  "$MEOW_RAIZ/scripts/ocultar_apps.sh"
  return $?
}

etapa_nomes() {
  passo "Nomes curtos no lançador"
  if [ "${LANCADOR_SISTEMA:-nao}" != "sim" ]; then
    pular_por_optin nomes; return $?
  fi
  "$MEOW_RAIZ/scripts/nomes_apps.sh"
  return $?
}

etapa_ponte_root() {
  passo "Ponte root (a senha uma vez)"
  local ponte=/usr/local/lib/meowsystem/ponte_root.sh
  local perfil=/usr/local/lib/meowsystem/perfil
  local regra=/etc/sudoers.d/49-meowsystem-ponte
  local origem="$MEOW_RAIZ/scripts/ponte_root.sh"
  local reserva=/usr/local/lib/meowsystem/reserva
  local somas=/usr/local/lib/meowsystem/reserva.sha256
  local reparo=/usr/local/lib/meowsystem/reparar_ponte.sh
  local unidade=/etc/systemd/system/meowsystem-ponte-reparo.service
  local reparo_origem="$MEOW_RAIZ/scripts/reparar_ponte.sh"
  local unidade_origem="$MEOW_RAIZ/assets/ponte/meowsystem-ponte-reparo.service"
  local polkit=/etc/polkit-1/rules.d/49-meowsystem-ponte-reparo.rules
  local polkit_origem="$MEOW_RAIZ/assets/ponte/49-meowsystem-ponte-reparo.rules"
  local pecas=/usr/local/lib/meowsystem/reserva-pecas.sha256
  local wrapper_origem="$MEOW_RAIZ/scripts/meow-lancador-apt.sh"
  local hook_origem="$MEOW_RAIZ/scripts/99-meow-lancador"
  local completion_origem="$MEOW_RAIZ/assets/zsh/_meow"

  if [ "${PONTE_ROOT:-sim}" != "sim" ]; then
    if [ ! -e "$ponte" ] && [ ! -e "$regra" ] && [ ! -e "$unidade" ]; then
      meow_pula 'PONTE_ROOT="nao" — sem braço root; o sudo volta a ser pedido no terminal'
      return "$MEOW_OK"
    fi
    if meow_seco; then meow_muda "removeria $regra e $ponte"; return "$MEOW_DIVERGENTE"; fi
    sudo rm -f "$regra" "$polkit" "$unidade" 2>/dev/null
    sudo rm -rf /usr/local/lib/meowsystem 2>/dev/null
    sudo systemctl daemon-reload 2>/dev/null
    if [ -e "$ponte" ] || [ -e "$regra" ] || [ -e "$unidade" ]; then
      meow_aviso "sem sudo para remover a ponte — ela continua ativa"
      return "$MEOW_SEM_DEPENDENCIA"
    fi
    meow_muda 'PONTE_ROOT="nao" — ponte e regra removidas'
    return "$MEOW_DIVERGENTE"
  fi

  local f
  for f in "$origem" "$reparo_origem" "$unidade_origem" "$polkit_origem" \
           "$wrapper_origem" "$hook_origem" "$completion_origem"; do
    [ -f "$f" ] || { meow_erro "falta $f — repositório incompleto"; return "$MEOW_ERRO"; }
  done

  local perfil_quer regra_quer somas_quer pecas_quer
  perfil_quer="$(printf 'raiz=%s\nusuaria=%s\nlar=%s\n' "$MEOW_RAIZ" "$(id -un)" "$HOME")"

  regra_quer="$(SUDO_USER="$(id -un)" bash "$origem" regra-sudo 2>/dev/null)" \
    || { meow_erro "a ponte não soube gerar a própria regra"; return "$MEOW_ERRO"; }

  local mudou=0 md5_quer md5_tem
  cmp -s "$origem" "$ponte" 2>/dev/null || mudou=1
  [ "$(cat "$perfil" 2>/dev/null)" = "$perfil_quer" ] || mudou=1
  md5_quer="$(printf '%s\n' "$regra_quer" | md5sum | cut -d' ' -f1)"
  local estado
  estado="$(sudo -n "$ponte" estado 2>/dev/null)"
  md5_tem="$(sed -n 's/^regra_md5=//p' <<< "$estado")"
  [ -n "$md5_tem" ] && [ "$md5_tem" = "$md5_quer" ] || mudou=1
  somas_quer="$(printf '%s  ponte_root.sh\n%s  49-meowsystem-ponte' \
    "$(sha256sum < "$origem" | cut -d' ' -f1)" \
    "$(printf '%s\n' "$regra_quer" | sha256sum | cut -d' ' -f1)")"
  [ -d "$reserva" ] && [ "$(cat "$somas" 2>/dev/null)" = "$somas_quer" ] || mudou=1
  local wrapper_quer
  wrapper_quer="$(sed -e "s|@ACERVO@|$MEOW_RAIZ|g" -e "s|@USUARIA@|$(id -un)|g" \
                      -e "s|@LAR@|$HOME|g" "$wrapper_origem")"
  pecas_quer="$(printf '%s  meow-lancador-apt.sh\n%s  99-meow-lancador\n%s  _meow' \
    "$(printf '%s\n' "$wrapper_quer" | sha256sum | cut -d' ' -f1)" \
    "$(sha256sum < "$hook_origem" | cut -d' ' -f1)" \
    "$(sha256sum < "$completion_origem" | cut -d' ' -f1)")"
  [ "$(cat "$pecas" 2>/dev/null)" = "$pecas_quer" ] || mudou=1
  cmp -s "$reparo_origem" "$reparo" 2>/dev/null || mudou=1
  cmp -s "$unidade_origem" "$unidade" 2>/dev/null || mudou=1
  [ "$(sed -n 's/^polkit_sha256=//p' <<< "$estado")" = "$(sha256sum < "$polkit_origem" | cut -d' ' -f1)" ] || mudou=1

  if [ "$mudou" = "0" ]; then
    meow_ok "ponte root instalada e liberada sem senha"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "instalaria a ponte root e a regra de sudo (a senha é pedida uma vez)"
    return "$MEOW_DIVERGENTE"
  fi

  if ! sudo -n true 2>/dev/null; then
    if [ -t 0 ]; then
      meow_info "esta é a única senha do MeowSystem: ela instala o braço root e"
      meow_info "  a regra que dispensa a senha daqui em diante."
      sudo -v || { meow_aviso "sem sudo — a ponte fica de fora, e o resto vai"; return "$MEOW_SEM_DEPENDENCIA"; }
    else
      meow_aviso "sem terminal para pedir a senha — a ponte fica de fora"
      meow_info "  ela entra na próxima instalação que puder pedir a senha"
      return "$MEOW_SEM_DEPENDENCIA"
    fi
  fi

  sudo install -d -m 755 -o root -g root /usr/local/lib/meowsystem \
    || { meow_erro "não consegui criar /usr/local/lib/meowsystem"; return "$MEOW_ERRO"; }
  sudo install -m 755 -o root -g root "$origem" "$ponte" \
    || { meow_erro "não consegui instalar $ponte"; return "$MEOW_ERRO"; }

  local tmp
  tmp="$(mktemp)" || { meow_erro "não consegui criar temporário"; return "$MEOW_ERRO"; }
  printf '%s\n' "$perfil_quer" > "$tmp"
  sudo install -m 644 -o root -g root "$tmp" "$perfil" \
    || { rm -f "$tmp"; meow_erro "não consegui gravar $perfil"; return "$MEOW_ERRO"; }

  printf '%s\n' "$regra_quer" > "$tmp"
  chmod 0440 "$tmp"
  if ! sudo visudo -c -f "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    meow_erro "a regra gerada não passou no visudo — NÃO instalei nada em /etc/sudoers.d"
    meow_info "  veja o texto com:  bash $origem regra-sudo"
    return "$MEOW_ERRO"
  fi
  if ! sudo install -m 440 -o root -g root "$tmp" "$regra"; then
    rm -f "$tmp"; meow_erro "não consegui instalar $regra"; return "$MEOW_ERRO"
  fi

  if ! { sudo install -d -m 700 -o root -g root "$reserva" &&
         sudo install -m 755 -o root -g root "$origem" "$reserva/ponte_root.sh" &&
         sudo install -m 440 -o root -g root "$tmp" "$reserva/49-meowsystem-ponte" &&
         chmod 600 "$tmp" && printf '%s\n' "$somas_quer" > "$tmp" &&
         sudo install -m 644 -o root -g root "$tmp" "$somas" &&
         printf '%s\n' "$wrapper_quer" > "$tmp" &&
         sudo install -m 644 -o root -g root "$tmp" "$reserva/meow-lancador-apt.sh" &&
         sudo install -m 644 -o root -g root "$hook_origem" "$reserva/99-meow-lancador" &&
         sudo install -m 644 -o root -g root "$completion_origem" "$reserva/_meow" &&
         printf '%s\n' "$pecas_quer" > "$tmp" &&
         sudo install -m 644 -o root -g root "$tmp" "$pecas"; }; then
    rm -f "$tmp"; meow_erro "não consegui guardar a reserva da ponte"; return "$MEOW_ERRO"
  fi
  rm -f "$tmp"

  if ! { sudo install -m 755 -o root -g root "$reparo_origem" "$reparo" &&
         sudo install -m 644 -o root -g root "$unidade_origem" "$unidade" &&
         sudo install -m 644 -o root -g root "$polkit_origem" "$polkit" &&
         sudo systemctl daemon-reload; }; then
    meow_erro "não consegui instalar o reparo da ponte"; return "$MEOW_ERRO"
  fi
  sudo systemctl reset-failed meowsystem-ponte-reparo.service 2>/dev/null || true

  if sudo -n "$ponte" estado >/dev/null 2>&1; then
    meow_muda "ponte root instalada — esta foi a última senha"
    return "$MEOW_DIVERGENTE"
  fi
  meow_aviso "a ponte foi instalada, mas o sudo ainda pede senha para ela"
  return "$MEOW_DIVERGENTE"
}

etapa_lancador_apt() {
  passo "Reaplique do lançador após apt"
  local hook=/etc/apt/apt.conf.d/99-meow-lancador
  local wrapper=/usr/local/sbin/meow-lancador-apt.sh

  if [ "${LANCADOR_SISTEMA:-nao}" != "sim" ]; then
    if [ -f "$hook" ] || [ -f "$wrapper" ]; then
      if ! meow_conf_diz LANCADOR_SISTEMA nao; then
        meow_aviso "o hook de apt existe e o meow.conf não diz LANCADOR_SISTEMA=\"nao\" — deixo como está"
        local onde; onde="$(meow_onde_no_painel LANCADOR_SISTEMA)"
        meow_info "  para removê-lo, escreva a chave${onde:+ (pelo painel, em $onde)}"
        return "$MEOW_SEM_DEPENDENCIA"
      fi
      if meow_seco; then
        meow_muda "removeria $hook (LANCADOR_SISTEMA=\"${LANCADOR_SISTEMA:-}\")"
        return "$MEOW_DIVERGENTE"
      fi
      meow_ponte apt-hook-remover >/dev/null 2>&1 || sudo rm -f "$hook" "$wrapper" 2>/dev/null
      if [ -f "$hook" ] || [ -f "$wrapper" ]; then
        meow_aviso "sem sudo para remover $hook — ele continua ativo"
        meow_info "  ele sai na próxima passada que tiver sudo ou a ponte root"
        return "$MEOW_SEM_DEPENDENCIA"
      fi
      meow_muda "LANCADOR_SISTEMA=\"${LANCADOR_SISTEMA:-}\" — hook de apt removido"
      return "$MEOW_DIVERGENTE"
    fi
    pular_por_optin lancador_apt; return $?
  fi

  local origem_hook="$MEOW_RAIZ/scripts/99-meow-lancador"
  local origem_wrapper="$MEOW_RAIZ/scripts/meow-lancador-apt.sh"
  local f
  for f in "$origem_hook" "$origem_wrapper"; do
    if [ ! -f "$f" ]; then
      meow_erro "falta $f — repositório incompleto"
      return "$MEOW_ERRO"
    fi
  done

  local texto
  texto="$(sed -e "s|@ACERVO@|$MEOW_RAIZ|g" \
               -e "s|@USUARIA@|$(id -un)|g" \
               -e "s|@LAR@|$HOME|g" "$origem_wrapper")"

  local mudou=0
  [ -f "$wrapper" ] && [ "$(cat "$wrapper" 2>/dev/null)" = "$texto" ] || mudou=1
  cmp -s "$origem_hook" "$hook" 2>/dev/null || mudou=1

  if [ "$mudou" = "0" ]; then
    meow_ok "hook de apt do lançador já instalado"
    return 0
  fi

  if meow_seco; then
    meow_muda "instalaria $hook e $wrapper"
    return "$MEOW_DIVERGENTE"
  fi

  if meow_ponte apt-hook-instalar >/dev/null 2>&1; then
    if [ "$(cat "$wrapper" 2>/dev/null)" = "$texto" ] && cmp -s "$origem_hook" "$hook"; then
      meow_muda "hook de apt instalado pela ponte — o lançador se reaplica sozinho após cada apt"
      return "$MEOW_DIVERGENTE"
    fi
    meow_aviso "o hook do repositório mudou — entra na próxima instalação que puder pedir a senha"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if [ ! -w /etc/apt/apt.conf.d ] && ! sudo -n true 2>/dev/null; then
    meow_aviso "sem sudo para instalar o hook de apt do lançador"
    meow_info "  ele entra na próxima passada que tiver sudo ou a ponte root"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local tmp
  tmp="$(mktemp)" || { meow_erro "não consegui criar temporário"; return "$MEOW_ERRO"; }
  printf '%s\n' "$texto" > "$tmp"
  if ! sudo install -m 755 -o root -g root "$tmp" "$wrapper" 2>/dev/null; then
    rm -f "$tmp"; meow_erro "não consegui instalar $wrapper"; return "$MEOW_ERRO"
  fi
  rm -f "$tmp"

  if ! sudo install -m 644 -o root -g root "$origem_hook" "$hook" 2>/dev/null; then
    meow_erro "não consegui instalar $hook"; return "$MEOW_ERRO"
  fi

  meow_muda "hook de apt instalado — o lançador se reaplica sozinho após cada apt"
  return "$MEOW_DIVERGENTE"
}

etapa_cursor() {
  passo "Cursor"
  CURSOR="${CURSOR:-}" CURSOR_VERSAO="${CURSOR_VERSAO:-v2.0.0}" \
    "$MEOW_RAIZ/scripts/cursor.sh" aplicar
  return $?
}

etapa_flatpak_tema() {
  passo "Flatpak veste o tema"
  CURSOR="${CURSOR:-}" NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/flatpak_tema.sh" aplicar
  return $?
}

etapa_escritorio() {
  passo "Escritório: OnlyOffice no lugar do LibreOffice"
  "$MEOW_RAIZ/scripts/escritorio.sh" aplicar
  return $?
}

etapa_som() {
  passo "Som de evento"
  "$MEOW_RAIZ/scripts/som.sh" aplicar
  return $?
}

etapa_prompt() {
  passo "Prompt do terminal (starship)"
  PROMPT_STARSHIP="${PROMPT_STARSHIP:-sim}" \
    "$MEOW_RAIZ/scripts/prompt.sh" instalar
  return $?
}

etapa_fzf() {
  passo "Cores do fzf"
  FLAVOR="$FLAVOR" ACCENT="$ACCENT" "$MEOW_RAIZ/scripts/fzf.sh" aplicar
  return $?
}

etapa_terminal() {
  passo "Cores do terminal"
  FLAVOR="$FLAVOR" ACCENT="$ACCENT" \
    TERMINAL_ESQUEMA="${TERMINAL_ESQUEMA:-sim}" \
    TERMINAL_CURSOR="${TERMINAL_CURSOR:-accent}" \
    "$MEOW_RAIZ/scripts/terminal.sh" aplicar
  return $?
}

etapa_fastfetch_logo() {
  passo "Logo do fastfetch"
  FASTFETCH_LOGO="${FASTFETCH_LOGO:-sim}" \
    FASTFETCH_LOGO_GATO="${FASTFETCH_LOGO_GATO:-coquinha}" \
    FASTFETCH_LOGO_COLUNAS="${FASTFETCH_LOGO_COLUNAS:-40}" \
    FASTFETCH_LOGO_MODO="${FASTFETCH_LOGO_MODO:-hora}" \
    FASTFETCH_LOGO_DIA="${FASTFETCH_LOGO_DIA:-}" FASTFETCH_LOGO_NOITE="${FASTFETCH_LOGO_NOITE:-}" \
    FASTFETCH_LOGO_CONF="${FASTFETCH_LOGO_CONF:-sim}" \
    LOGO_DIA="${LOGO_DIA:-}" LOGO_NOITE="${LOGO_NOITE:-}" \
    NOITE_INICIO="${NOITE_INICIO:-}" NOITE_FIM="${NOITE_FIM:-}" \
    WALLPAPER_NOITE_INICIO="${WALLPAPER_NOITE_INICIO:-}" WALLPAPER_NOITE_FIM="${WALLPAPER_NOITE_FIM:-}" \
    "$MEOW_RAIZ/scripts/fastfetch_logo.sh" aplicar
  return $?
}

etapa_bloco_terminal() {
  passo "Bloco do terminal"
  "$MEOW_RAIZ/scripts/terminal_bloco.sh" aplicar
}

etapa_files_menu() {
  passo "Papel de parede no menu de contexto"
  FILES_MENU="${FILES_MENU:-sim}" FILES_MENU_AUTOBUILD="${FILES_MENU_AUTOBUILD:-sim}" \
    "$MEOW_RAIZ/scripts/files_menu.sh" aplicar
  return $?
}

etapa_vidro() {
  passo "Vidro ao maximizar"
  VIDRO_AO_MAXIMIZAR="${VIDRO_AO_MAXIMIZAR:-sim}" \
    VIDRO_OPACIDADE="${VIDRO_OPACIDADE:-}" \
    VIDRO_OPACIDADE_PAINEL="${VIDRO_OPACIDADE_PAINEL:-}" \
    VIDRO_OPACIDADE_DOCK="${VIDRO_OPACIDADE_DOCK:-}" \
    "$MEOW_RAIZ/scripts/vidro.sh"
  return $?
}

etapa_escala() {
  passo "Escala da tela"
  ESCALA_TELA="${ESCALA_TELA:-}" "$MEOW_RAIZ/scripts/escala.sh"
  return $?
}

etapa_painel() {
  passo "Supervisor da barra (systemd --user)"
  local destino="$HOME/.config/systemd/user" u conteudo mudou=0
  local unidades=(meow-painel.service meow-painel-raio.path meow-painel-raio.service)

  "$MEOW_RAIZ/scripts/painel.sh" conferir
  local rc=$?
  [ "$rc" = "2" ] && return "$MEOW_ERRO"

  if [ "${AUTO_REPARO:-sim}" != "sim" ]; then
    if meow_unidade_sobrou "${unidades[@]}"; then
      meow_seco && { meow_muda "AUTO_REPARO=\"${AUTO_REPARO:-}\" — removeria o supervisor da barra"; return "$MEOW_DIVERGENTE"; }
      systemctl --user disable --now meow-painel.service meow-painel-raio.path >/dev/null 2>&1
      rm -f "${unidades[@]/#/$destino/}"
      rm -f "$destino"/*.wants/meow-painel.service "$destino"/*.wants/meow-painel-raio.path \
            "$destino"/*.requires/meow-painel.service "$destino"/*.requires/meow-painel-raio.path
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "AUTO_REPARO=\"${AUTO_REPARO:-}\" — supervisor da barra desligado e removido"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "AUTO_REPARO=\"${AUTO_REPARO:-}\" — sem supervisor da barra"
    [ "$rc" = "1" ] && return "$MEOW_DIVERGENTE"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    meow_aviso "não há systemd --user nesta sessão — a barra não terá quem a reponha"
    return "$rc"
  fi

  for u in "${unidades[@]}"; do
    [ -f "$MEOW_RAIZ/systemd/$u" ] || { meow_erro "falta systemd/$u"; return "$MEOW_ERRO"; }
    conteudo="$(cat "$MEOW_RAIZ/systemd/$u")"
    conteudo="${conteudo//@V_PANEL@/$(meow_cosmic_v com.system76.CosmicPanel.Panel)}"
    conteudo="${conteudo//@V_DOCK@/$(meow_cosmic_v com.system76.CosmicPanel.Dock)}"
    meow_escrever "$destino/$u" "$conteudo" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac
  done

  if meow_seco; then
    local armaria=""
    for u in meow-painel.service meow-painel-raio.path; do
      if [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" != "enabled" ] ||
         [ "$(systemctl --user is-active  "$u" 2>/dev/null)" != "active" ]; then
        armaria="${armaria:+$armaria }$u"
      fi
    done
    [ "$mudou" = "1" ] && meow_muda "instalaria/atualizaria as unidades do supervisor da barra"
    [ -n "$armaria" ] && meow_muda "armaria o supervisor da barra ($armaria)"
    { [ "$mudou" = "1" ] || [ -n "$armaria" ]; } && return "$MEOW_DIVERGENTE"
    return "$rc"
  fi

  if [ "$mudou" = "1" ]; then
    systemctl --user daemon-reload
    rc=1
  fi

  for u in meow-painel.service meow-painel-raio.path; do
    if [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" != "enabled" ] ||
       [ "$(systemctl --user is-active  "$u" 2>/dev/null)" != "active" ]; then
      systemctl --user enable --now "$u" >/dev/null 2>&1 \
        && { meow_muda "supervisor da barra armado ($u)"; rc=1; } \
        || meow_aviso "não consegui armar $u"
    fi
  done
  return "$rc"
}

etapa_forma() {
  passo "Forma das barras (painel e dock)"
  "$MEOW_RAIZ/scripts/forma.sh"
  return $?
}

etapa_janelas() {
  passo "Janelas lado a lado (o layout dwindle)"
  "$MEOW_RAIZ/scripts/janelas.sh" aplicar
  return $?
}

etapa_relogio() {
  passo "Relógio da barra de cima"
  RELOGIO_SEGUNDOS="${RELOGIO_SEGUNDOS:-}" "$MEOW_RAIZ/scripts/relogio.sh" aplicar
  return $?
}

etapa_leitura() {
  passo "Modo de leitura (o horário liga sozinho)"
  local destino="$HOME/.config/systemd/user" u conteudo mudou=0
  local unidades=(meow-leitura.service meow-leitura.timer)

  local rc=0 aplicavel=1
  if [ "${LEITURA_AGENDA:-}" = "sim" ] && [ "${AUTO_REPARO:-sim}" != "sim" ]; then
    aplicavel=0
  fi
  if [ "$aplicavel" = "1" ]; then
    "$MEOW_RAIZ/scripts/leitura.sh" aplicar
    rc=$?
    [ "$rc" = "2" ] && return "$MEOW_ERRO"
  fi

  if [ "${AUTO_REPARO:-sim}" != "sim" ] || [ "${LEITURA_AGENDA:-}" != "sim" ]; then
    if meow_unidade_sobrou "${unidades[@]}"; then
      if meow_seco; then
        meow_muda "removeria o relógio do modo de leitura (meow-leitura.timer)"
      else
        systemctl --user disable --now meow-leitura.timer >/dev/null 2>&1
        rm -f "${unidades[@]/#/$destino/}"
        for u in "${unidades[@]}"; do
          rm -f "$destino"/*.wants/"$u" "$destino"/*.requires/"$u"
        done
        systemctl --user daemon-reload >/dev/null 2>&1
        meow_muda "relógio do modo de leitura desligado e removido (meow-leitura.timer)"
      fi
      if [ "$aplicavel" = "0" ]; then
        meow_info "  o degrau que estiver no disco fica: esvazie LEITURA_AGENDA se o modo de"
        meow_info "  leitura é só seu, ou «Desligar agora» zera os dois números"
      fi
      return "$MEOW_DIVERGENTE"
    fi
    if [ -z "${LEITURA_AGENDA:-}" ]; then
      meow_pula "LEITURA_AGENDA vazio — sem relógio do modo de leitura"
      return "$rc"
    fi
    if [ "${LEITURA_AGENDA:-}" != "sim" ]; then
      meow_pula "LEITURA_AGENDA=\"${LEITURA_AGENDA:-}\" — sem relógio do modo de leitura"
      return "$rc"
    fi
    meow_pula "AUTO_REPARO=\"${AUTO_REPARO:-}\" — sem relógio do modo de leitura, mesmo com LEITURA_AGENDA=\"sim\""
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    meow_aviso "não há systemd --user nesta sessão — o horário não vai virar sozinho"
    return "$rc"
  fi

  for u in "${unidades[@]}"; do
    [ -f "$MEOW_RAIZ/systemd/$u" ] || { meow_erro "falta systemd/$u"; return "$MEOW_ERRO"; }
    conteudo="$(cat "$MEOW_RAIZ/systemd/$u")"
    meow_escrever "$destino/$u" "$conteudo" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac
  done

  if meow_seco; then
    local armaria=0
    if [ "$(systemctl --user is-enabled meow-leitura.timer 2>/dev/null)" != "enabled" ] ||
       [ "$(systemctl --user is-active  meow-leitura.timer 2>/dev/null)" != "active" ]; then
      armaria=1
    fi
    [ "$mudou"   = "1" ] && meow_muda "instalaria/atualizaria as unidades do relógio do modo de leitura"
    [ "$armaria" = "1" ] && meow_muda "armaria o relógio do modo de leitura (meow-leitura.timer)"
    { [ "$mudou" = "1" ] || [ "$armaria" = "1" ]; } && return "$MEOW_DIVERGENTE"
    return "$rc"
  fi

  if [ "$mudou" = "1" ]; then
    systemctl --user daemon-reload
    rc=1
  fi

  if [ "$(systemctl --user is-enabled meow-leitura.timer 2>/dev/null)" != "enabled" ] ||
     [ "$(systemctl --user is-active  meow-leitura.timer 2>/dev/null)" != "active" ]; then
    if systemctl --user enable --now meow-leitura.timer >/dev/null 2>&1; then
      meow_muda "relógio do modo de leitura armado (meow-leitura.timer)"
      rc=1
    else
      meow_aviso "não consegui armar o meow-leitura.timer"
    fi
  fi
  return "$rc"
}

etapa_autostart() {
  passo "Autostart bloqueado"
  AUTOSTART_BLOQUEADOS="${AUTOSTART_BLOQUEADOS:-}" "$MEOW_RAIZ/scripts/autostart.sh" aplicar
  return $?
}

etapa_hicolor() {
  passo "Fim da cadeia de ícones (hicolor do usuário)"
  "$MEOW_RAIZ/scripts/hicolor.sh"
  return $?
}

etapa_jogos() {
  passo "Jogos da Steam"
  "$MEOW_RAIZ/scripts/jogos_steam.sh"
  return $?
}

etapa_jogos_heroic() {
  passo "Jogos do Heroic"
  "$MEOW_RAIZ/scripts/jogos_heroic.sh"
  return $?
}

etapa_greeter() {
  passo "Tela de login"
  FLAVOR="$FLAVOR" ACCENT="$ACCENT" "$MEOW_RAIZ/scripts/greeter.sh"
  return $?
}

etapa_upstream() {
  passo "Upstream de terceiros (commits pinados)"
  "$MEOW_RAIZ/scripts/baixar_upstream.sh"
  return $?
}

etapa_pastas_xdg() {
  passo "Pastas especiais (nome XDG)"
  PASTAS_XDG="${PASTAS_XDG:-nao}" ICONES_FLAVOR="${ICONES_FLAVOR:-}" \
    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_pastas.sh"
  return $?
}

etapa_pastas() {
  passo "Pastas na cor do flavor"
  ICONES_BASE="${ICONES_BASE:-Papirus-Dark}" \
    ICONES_PASTAS="${ICONES_PASTAS:-cat-${FLAVOR}-${ACCENT}}" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/construir_pastas.sh"
  return $?
}

etapa_apps() {
  passo "Aplicativos"
  APPS_ATIVOS="${APPS_ATIVOS:-}" FLAVOR="${FLAVOR:-}" ACCENT="${ACCENT:-}" \
    SPOTIFY_MARKETPLACE="${SPOTIFY_MARKETPLACE:-}" \
    "$MEOW_RAIZ/scripts/aplicar_apps.sh" aplicar
  return $?
}

etapa_extensoes() {
  passo "Extensões (applets da casa: compilação e sombra)"
  EXTENSOES_COMPILAR=1 EXTENSOES="${EXTENSOES:-}" MIDIA="${MIDIA:-}" \
    LEITURA_APPLET="${LEITURA_APPLET:-}" \
    "$MEOW_RAIZ/scripts/extensoes_build.sh" --todas --aplicar
  return $?
}

etapa_compositor() {
  passo "Compositor da casa (build em segundo plano e o shim)"
  if [ "${COMPOSITOR:-sim}" = nao ]; then
    "$MEOW_RAIZ/scripts/extensoes_build.sh" compositor --reverter
    return $?
  fi
  EXTENSOES_FUNDO=1 "$MEOW_RAIZ/scripts/extensoes_gesto.sh" instalar compositor
  return $?
}

etapa_extensoes_tema() {
  passo "Extensões (tema do pack)"
  FLAVOR="${FLAVOR:-}" ACCENT="${ACCENT:-}" "$MEOW_RAIZ/scripts/extensoes_tema.sh" --aplicar
  return $?
}

etapa_midia() {
  passo "Applet de mídia (chaves)"
  MIDIA="${MIDIA:-}" MIDIA_LARGURA="${MIDIA_LARGURA:-}" \
    MIDIA_COR_ALBUM="${MIDIA_COR_ALBUM:-}" MIDIA_CAPA="${MIDIA_CAPA:-}" \
    MIDIA_FONTE="${MIDIA_FONTE:-}" MIDIA_COR_TITULO="${MIDIA_COR_TITULO:-}" \
    MIDIA_COR_ARTISTA="${MIDIA_COR_ARTISTA:-}" \
    MIDIA_CONTROLES="${MIDIA_CONTROLES:-}" FLAVOR="${FLAVOR:-}" \
    "$MEOW_RAIZ/scripts/midia.sh"
  return $?
}

etapa_autoreparo() {
  passo "Auto-reparo diário (systemd --user)"
  local origem="$MEOW_RAIZ/systemd"
  local destino="$HOME/.config/systemd/user"
  local estado="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"
  local unidades=(meow-doctor.service meow-doctor.timer) ligaveis=(meow-doctor.timer)
  local vidro_unidades=(meow-vidro.service meow-vidro.path) quer_vidro=1
  case "${VIDRO_AO_MAXIMIZAR:-sim}" in nao|não|false|0) quer_vidro=0 ;; esac
  if [ "$quer_vidro" = "1" ]; then
    unidades+=("${vidro_unidades[@]}"); ligaveis+=(meow-vidro.path)
  fi

  if [ "${AUTO_REPARO:-sim}" != "sim" ]; then
    if [ -f "$destino/meow-doctor.timer" ] || [ -f "$destino/meow-vidro.path" ]; then
      if meow_seco; then
        meow_muda "AUTO_REPARO=\"${AUTO_REPARO:-}\" — removeria o auto-reparo (meow-doctor.timer)"
        return "$MEOW_DIVERGENTE"
      fi
      systemctl --user disable --now meow-doctor.timer meow-vidro.path >/dev/null 2>&1
      rm -f "$destino/meow-doctor.timer" "$destino/meow-doctor.service" "${vidro_unidades[@]/#/$destino/}" \
            "$destino"/*.wants/meow-vidro.path
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "AUTO_REPARO=\"${AUTO_REPARO:-}\" — auto-reparo desligado e removido (meow-doctor.timer)"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "AUTO_REPARO=\"${AUTO_REPARO:-}\" no meow.conf — sem reparo automático"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    meow_aviso "não há systemd --user nesta sessão — o auto-reparo fica de fora"
    meow_info "  o «Consertar», no Manter, faz o mesmo quando quiser"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_seco && ! mkdir -p "$estado"; then
    meow_erro "não consegui criar $estado (é lá que fica o log do auto-reparo)"
    return "$MEOW_ERRO"
  fi

  local mudou=0 u sobra_vidro=0
  if [ "$quer_vidro" = "0" ] && { [ -f "$destino/meow-vidro.path" ] || [ -f "$destino/meow-vidro.service" ]; }; then
    sobra_vidro=1
  fi
  for u in "${unidades[@]}"; do
    if [ ! -f "$origem/$u" ]; then
      meow_erro "falta $origem/$u — repositório incompleto"
      return "$MEOW_ERRO"
    fi
    meow_escrever "$destino/$u" "$(cat "$origem/$u")" 644
    case $? in
      1) mudou=1 ;;
      2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;;
    esac
  done

  if meow_seco; then
    local armaria=0
    for u in "${ligaveis[@]}"; do
      if [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" != "enabled" ] ||
         [ "$(systemctl --user is-active  "$u" 2>/dev/null)" != "active" ]; then
        armaria=1
      fi
    done
    [ "$mudou"   = "1" ] && meow_muda "instalaria/atualizaria as unidades do auto-reparo"
    [ "$armaria" = "1" ] && meow_muda "ligaria o auto-reparo (${ligaveis[*]})"
    [ "$sobra_vidro" = "1" ] && meow_muda "VIDRO_AO_MAXIMIZAR=\"${VIDRO_AO_MAXIMIZAR:-}\" — removeria o vigia do vidro (meow-vidro.path)"
    { [ "$mudou" = "1" ] || [ "$armaria" = "1" ] || [ "$sobra_vidro" = "1" ]; } && return "$MEOW_DIVERGENTE"
    meow_ok "auto-reparo já ligado (meow-doctor.timer, todo dia às 5h, com até 20min de folga)"
    return 0
  fi

  if [ "$sobra_vidro" = "1" ]; then
    systemctl --user disable --now meow-vidro.path >/dev/null 2>&1
    rm -f "${vidro_unidades[@]/#/$destino/}" "$destino"/*.wants/meow-vidro.path
    meow_muda "VIDRO_AO_MAXIMIZAR=\"${VIDRO_AO_MAXIMIZAR:-}\" — vigia do vidro desligado e removido"
    mudou=1
  fi
  [ "$mudou" = "1" ] && systemctl --user daemon-reload

  for u in "${ligaveis[@]}"; do
    if [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" != "enabled" ] ||
       [ "$(systemctl --user is-active  "$u" 2>/dev/null)" != "active" ]; then
      if ! systemctl --user enable --now "$u" >/dev/null 2>&1; then
        meow_erro "não consegui ligar o $u"
        return "$MEOW_ERRO"
      fi
      mudou=1
    fi
  done

  if [ ! -x "$HOME/.local/bin/meow" ]; then
    meow_aviso "o timer está ligado, mas ~/.local/bin/meow ainda não existe"
    meow_info "  até ele aparecer, cada disparo é pulado (o journal diz o caminho)"
  fi

  if [ "$mudou" = "0" ]; then
    meow_ok "auto-reparo já ligado (meow-doctor.timer, todo dia às 5h, com até 20min de folga)"
    return 0
  fi
  meow_ok "auto-reparo ligado (meow-doctor.timer): todo dia às 5h, log em $estado/doctor.log"
  return "$MEOW_DIVERGENTE"
}

meow_unidade_sobrou() {
  local destino="$HOME/.config/systemd/user" u w
  for u in "$@"; do
    [ -f "$destino/$u" ] && return 0
    case "$(systemctl --user is-enabled "$u" 2>/dev/null)" in
      enabled|enabled-runtime|linked|linked-runtime) return 0 ;;
    esac
    [ "$(systemctl --user is-active "$u" 2>/dev/null)" = "active" ] && return 0
    for w in "$destino"/*.wants/"$u" "$destino"/*.requires/"$u"; do
      [ -L "$w" ] && return 0
    done
  done
  return 1
}

_logo_relogio() {
  local liga="$1" destino="$HOME/.config/systemd/user" mudou=0 u conteudo

  if [ "$liga" != "sim" ]; then
    if meow_unidade_sobrou meow-gato.timer meow-gato.service; then
      meow_seco && { meow_muda "removeria o relógio do mascote (LOGO_MODO não é \"hora\")"; return "$MEOW_DIVERGENTE"; }
      systemctl --user disable --now meow-gato.timer meow-gato.service >/dev/null 2>&1
      rm -f "$destino/meow-gato.timer" "$destino/meow-gato.service"
      rm -f "$destino"/*.wants/meow-gato.timer "$destino"/*.wants/meow-gato.service \
            "$destino"/*.requires/meow-gato.timer "$destino"/*.requires/meow-gato.service
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "relógio do mascote removido"
      return "$MEOW_DIVERGENTE"
    fi
    return 0
  fi

  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    meow_aviso "não há systemd --user aqui — o mascote não troca sozinho na virada"
    meow_info "  troque na mão com 'meow logo' quando quiser"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  for u in meow-gato.service meow-gato.timer; do
    [ -f "$MEOW_RAIZ/systemd/$u" ] || { meow_erro "falta systemd/$u"; return "$MEOW_ERRO"; }
    conteudo="$(cat "$MEOW_RAIZ/systemd/$u")"
    meow_escrever "$destino/$u" "$conteudo" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac
  done

  if meow_seco; then
    local armaria=0
    if [ "$(systemctl --user is-enabled meow-gato.timer 2>/dev/null)" != "enabled" ] ||
       [ "$(systemctl --user is-active  meow-gato.timer 2>/dev/null)" != "active" ]; then
      armaria=1
    fi
    [ "$mudou"   = "1" ] && meow_muda "instalaria/atualizaria as unidades do relógio do mascote"
    [ "$armaria" = "1" ] && meow_muda "armaria o relógio do mascote (meow-gato.timer, tique de 5 min)"
    { [ "$mudou" = "1" ] || [ "$armaria" = "1" ]; } && return "$MEOW_DIVERGENTE"
    return 0
  fi

  [ "$mudou" = "1" ] && systemctl --user daemon-reload
  if [ "$(systemctl --user is-enabled meow-gato.timer 2>/dev/null)" != "enabled" ] ||
     [ "$(systemctl --user is-active  meow-gato.timer 2>/dev/null)" != "active" ]; then
    systemctl --user enable --now meow-gato.timer >/dev/null 2>&1 \
      || { meow_erro "não consegui ligar o meow-gato.timer"; return "$MEOW_ERRO"; }
    meow_muda "relógio do mascote armado (meow-gato.timer, tique de 5 min)"
    mudou=1
  fi
  [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
  return 0
}

etapa_icones_indice() {
  passo "Índice do tema de ícones"
  NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/construir_icones.sh" indice
  return $?
}

etapa_logo() {
  passo "Gatos do painel"
  local destino="$HOME/.config/systemd/user" mudou=0 rc modo

  modo="$("$MEOW_RAIZ/scripts/logo.sh" modo 2>/dev/null)" || modo="hora"
  [ -n "$modo" ] || modo="hora"

  FLAVOR="$FLAVOR" LOGO="$LOGO" "$MEOW_RAIZ/scripts/logo.sh"
  rc=$?
  [ "$rc" = "1" ] && mudou=1
  [ "$rc" -ge 2 ] && return "$rc"

  _logo_relogio "$([ "$modo" = "hora" ] && echo sim || echo nao)"
  rc=$?
  [ "$rc" = "1" ] && mudou=1
  [ "$rc" = "2" ] && return "$rc"

  if [ "$modo" = "hora" ]; then
    if meow_unidade_sobrou meow-logo.service meow-logo.timer; then
      if meow_seco; then
        meow_muda "removeria a rotação por encerramento (o modo é \"hora\")"; mudou=1
      else
        systemctl --user disable --now meow-logo.timer meow-logo.service >/dev/null 2>&1
        rm -f "$destino/meow-logo.timer" "$destino/meow-logo.service"
        rm -f "$destino"/*.wants/meow-logo.service "$destino"/*.wants/meow-logo.timer \
              "$destino"/*.requires/meow-logo.service "$destino"/*.requires/meow-logo.timer
        systemctl --user daemon-reload >/dev/null 2>&1
        meow_muda "rotação por encerramento removida — quem manda agora é o relógio"; mudou=1
      fi
    fi
    meow_seco && [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
    [ "$mudou" = "1" ] && { meow_ok "o mascote segue o relógio: ${LOGO_DIA:-mimir} de dia, ${LOGO_NOITE:-coquinha} de noite"; return "$MEOW_DIVERGENTE"; }
    meow_ok "o mascote já segue o relógio (${LOGO_DIA:-mimir} de dia, ${LOGO_NOITE:-coquinha} de noite)"
    return 0
  fi

  if [ "$modo" != "rotacao" ]; then
    if meow_unidade_sobrou meow-logo.service meow-logo.timer; then
      meow_seco && { meow_muda "removeria a rotação (inclusive link órfão em *.wants)"; return "$MEOW_DIVERGENTE"; }
      systemctl --user disable --now meow-logo.timer meow-logo.service >/dev/null 2>&1
      rm -f "$destino/meow-logo.timer" "$destino/meow-logo.service"
      rm -f "$destino"/*.wants/meow-logo.service "$destino"/*.wants/meow-logo.timer \
            "$destino"/*.requires/meow-logo.service "$destino"/*.requires/meow-logo.timer
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "LOGO_ROTACAO=\"${LOGO_ROTACAO:-nao}\" — rotação desligada"
      return "$MEOW_DIVERGENTE"
    fi
    meow_info "rotação desligada (LOGO_ROTACAO=\"${LOGO_ROTACAO:-nao}\") — o acervo está no lugar"
    return "$([ "$mudou" = "1" ] && echo "$MEOW_DIVERGENTE" || echo 0)"
  fi

  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    meow_aviso "não há systemd --user aqui — a rotação fica de fora"
    meow_info "  troque na mão com 'meow logo girar'"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if [ -f "$destino/meow-logo.timer" ]; then
    if meow_seco; then
      meow_muda "removeria o meow-logo.timer (a rotação passou a ser no encerramento da sessão)"
      mudou=1
    else
      systemctl --user disable --now meow-logo.timer >/dev/null 2>&1
      rm -f "$destino/meow-logo.timer"
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "meow-logo.timer removido — o mascote agora gira ao encerrar a sessão"
      mudou=1
    fi
  fi

  local u="meow-logo.service" conteudo
  [ -f "$MEOW_RAIZ/systemd/$u" ] || { meow_erro "falta systemd/$u"; return "$MEOW_ERRO"; }
  conteudo="$(cat "$MEOW_RAIZ/systemd/$u")"
  meow_escrever "$destino/$u" "$conteudo" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac

  if meow_seco; then
    [ "$mudou" = "1" ] && { meow_muda "ligaria a rotação a cada ${LOGO_INTERVALO:-1d}"; return "$MEOW_DIVERGENTE"; }
    meow_ok "rotação de mascotes já ligada"
    return 0
  fi

  [ "$mudou" = "1" ] && systemctl --user daemon-reload
  if [ "$(systemctl --user is-enabled meow-logo.service 2>/dev/null)" != "enabled" ] ||
     [ "$(systemctl --user is-active  meow-logo.service 2>/dev/null)" != "active" ]; then
    systemctl --user enable --now meow-logo.service >/dev/null 2>&1 \
      || { meow_erro "não consegui ligar o meow-logo.service"; return "$MEOW_ERRO"; }
    mudou=1
  fi

  [ "$mudou" = "0" ] && { meow_ok "rotação já ligada (no máximo 1 mascote a cada ${LOGO_INTERVALO:-1d}, no login seguinte)"; return 0; }
  meow_ok "o mascote gira ao encerrar a sessão, no máximo 1 a cada ${LOGO_INTERVALO:-1d}"
  meow_info "  ele aparece no login seguinte — 'meow logo listar' mostra o acervo"
  return "$MEOW_DIVERGENTE"
}

etapa_assets() {
  passo "Vigia do acervo de mascotes (systemd --user)"
  ASSETS_VIGIA="${ASSETS_VIGIA:-sim}" "$MEOW_RAIZ/scripts/vigia_assets.sh"
  return $?
}

etapa_vigia_flatpak() {
  passo "Vigia do flatpak (systemd --user)"
  FLATPAK_VIGIA="${FLATPAK_VIGIA:-sim}" "$MEOW_RAIZ/scripts/vigia_flatpak.sh"
  return $?
}

etapa_vigia_derivados() {
  passo "Vigia dos desenhos dos packs (systemd --user)"
  local rc rc_vigia
  NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" "$MEOW_RAIZ/scripts/derivados.sh" --registrar; rc=$?
  "$MEOW_RAIZ/scripts/vigia_derivados.sh"; rc_vigia=$?
  { [ "$rc" = 2 ] || [ "$rc_vigia" = 2 ]; } && return 2
  { [ "$rc" = 1 ] || [ "$rc_vigia" = 1 ]; } && return 1
  return "$rc"
}

etapa_vigia_steam() {
  passo "Vigia da Steam (systemd --user)"
  STEAM_VIGIA="${STEAM_VIGIA:-sim}" "$MEOW_RAIZ/scripts/vigia_steam.sh"
  return $?
}

etapa_vigia_heroic() {
  passo "Vigia do Heroic (systemd --user)"
  HEROIC_VIGIA="${HEROIC_VIGIA:-sim}" "$MEOW_RAIZ/scripts/vigia_heroic.sh"
  return $?
}

etapa_vigia_qt() {
  passo "Vigia do Qt (systemd --user)"
  local destino="$HOME/.config/systemd/user" u conteudo mudou=0 lista
  local unidades=(meow-qt.service meow-qt.path)
  local ligaveis=(meow-qt.path)

  lista=",$(printf '%s' "${APPS_ATIVOS:-}" | tr -d ' '),"
  local quer_qt=0
  case "$lista" in *,qt5ct,*|*,qt,*|*,gtk,*) quer_qt=1 ;; esac

  if [ "$quer_qt" != "1" ] || [ "${AUTO_REPARO:-sim}" != "sim" ]; then
    local motivo="APPS_ATIVOS sem qt5ct"
    [ "${AUTO_REPARO:-sim}" != "sim" ] && motivo="AUTO_REPARO=\"${AUTO_REPARO:-}\""
    if meow_unidade_sobrou "${unidades[@]}"; then
      meow_seco && { meow_muda "$motivo — removeria o vigia do Qt"; return "$MEOW_DIVERGENTE"; }
      systemctl --user disable --now "${ligaveis[@]}" >/dev/null 2>&1
      rm -f "${unidades[@]/#/$destino/}"
      rm -f "$destino"/*.wants/meow-qt.path "$destino"/*.wants/meow-qt.service \
            "$destino"/*.requires/meow-qt.path "$destino"/*.requires/meow-qt.service
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "$motivo — vigia do Qt desligado e removido"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "$motivo — sem vigia do Qt"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    meow_aviso "não há systemd --user nesta sessão — o ícone do Qt só voltará no próximo doctor"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  for u in "${unidades[@]}"; do
    [ -f "$MEOW_RAIZ/systemd/$u" ] || { meow_erro "falta systemd/$u"; return "$MEOW_ERRO"; }
    conteudo="$(cat "$MEOW_RAIZ/systemd/$u")"
    meow_escrever "$destino/$u" "$conteudo" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac
  done

  if meow_seco; then
    local armaria=""
    for u in "${ligaveis[@]}"; do
      if [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" != "enabled" ] ||
         [ "$(systemctl --user is-active  "$u" 2>/dev/null)" != "active" ]; then
        armaria="${armaria:+$armaria }$u"
      fi
    done
    [ "$mudou" = "1" ] && meow_muda "instalaria/atualizaria as unidades do vigia do Qt"
    [ -n "$armaria" ] && meow_muda "armaria o vigia do Qt ($armaria)"
    { [ "$mudou" = "1" ] || [ -n "$armaria" ]; } && return "$MEOW_DIVERGENTE"
    return "$MEOW_OK"
  fi

  local rc=0
  if [ "$mudou" = "1" ]; then
    systemctl --user daemon-reload
    meow_muda "unidades do vigia do Qt instaladas/atualizadas"
    rc=1
  fi
  systemctl --user reset-failed "${unidades[@]}" >/dev/null 2>&1
  for u in "${ligaveis[@]}"; do
    if [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" != "enabled" ] ||
       [ "$(systemctl --user is-active  "$u" 2>/dev/null)" != "active" ]; then
      systemctl --user enable --now "$u" >/dev/null 2>&1 \
        && { meow_muda "vigia do Qt armado ($u)"; rc=1; } \
        || meow_aviso "não consegui armar $u"
    fi
  done
  [ "$rc" = "0" ] && meow_ok "vigia do Qt no ar — o ícone volta em segundos, não às 5h da manhã"
  return "$rc"
}

etapa_vigia_apt() {
  passo "Pós-apt do COSMIC (systemd --user)"
  local destino="$HOME/.config/systemd/user" u conteudo mudou=0
  local unidades=(meow-pos-apt.service meow-pos-apt.path meow-builds-login.service
                  meow-sentinela.service meow-sentinela.timer meow-sentinela.path)
  local ligaveis=(meow-pos-apt.path meow-sentinela.timer meow-sentinela.path)
  local no_login=(meow-builds-login.service)

  if [ "${AUTO_REPARO:-sim}" != "sim" ]; then
    local motivo="AUTO_REPARO=\"${AUTO_REPARO:-}\""
    if meow_unidade_sobrou "${unidades[@]}"; then
      meow_seco && { meow_muda "$motivo — removeria o pós-apt do COSMIC"; return "$MEOW_DIVERGENTE"; }
      systemctl --user disable --now "${ligaveis[@]}" >/dev/null 2>&1
      rm -f "${unidades[@]/#/$destino/}"
      systemctl --user disable "${no_login[@]}" >/dev/null 2>&1
      rm -f "$destino"/*.wants/meow-pos-apt.path "$destino"/*.wants/meow-pos-apt.service \
            "$destino"/*.requires/meow-pos-apt.path "$destino"/*.requires/meow-pos-apt.service \
            "$destino"/*.wants/meow-builds-login.service "$destino"/*.wants/meow-sentinela.timer \
            "$destino"/*.wants/meow-sentinela.path
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "$motivo — pós-apt do COSMIC desligado e removido"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "$motivo — sem pós-apt do COSMIC"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    meow_aviso "não há systemd --user nesta sessão — o COSMIC só se refaz no próximo doctor"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  for u in "${unidades[@]}"; do
    [ -f "$MEOW_RAIZ/systemd/$u" ] || { meow_erro "falta systemd/$u"; return "$MEOW_ERRO"; }
    conteudo="$(cat "$MEOW_RAIZ/systemd/$u")"
    meow_escrever "$destino/$u" "$conteudo" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac
  done

  if meow_seco; then
    local armaria=""
    for u in "${ligaveis[@]}"; do
      if [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" != "enabled" ] ||
         [ "$(systemctl --user is-active  "$u" 2>/dev/null)" != "active" ]; then
        armaria="${armaria:+$armaria }$u"
      fi
    done
    for u in "${no_login[@]}"; do
      [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" = "enabled" ] || armaria="${armaria:+$armaria }$u"
    done
    [ "$mudou" = "1" ] && meow_muda "instalaria/atualizaria as unidades do pós-apt do COSMIC"
    [ -n "$armaria" ] && meow_muda "armaria o pós-apt do COSMIC ($armaria)"
    { [ "$mudou" = "1" ] || [ -n "$armaria" ]; } && return "$MEOW_DIVERGENTE"
    return "$MEOW_OK"
  fi

  local rc=0
  if [ "$mudou" = "1" ]; then
    systemctl --user daemon-reload
    meow_muda "unidades do pós-apt do COSMIC instaladas/atualizadas"
    rc=1
  fi
  systemctl --user reset-failed "${unidades[@]}" >/dev/null 2>&1
  for u in "${ligaveis[@]}"; do
    if [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" != "enabled" ] ||
       [ "$(systemctl --user is-active  "$u" 2>/dev/null)" != "active" ]; then
      systemctl --user enable --now "$u" >/dev/null 2>&1 \
        && { meow_muda "pós-apt do COSMIC armado ($u)"; rc=1; } \
        || meow_aviso "não consegui armar $u"
    fi
  done
  for u in "${no_login[@]}"; do
    [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" = "enabled" ] && continue
    systemctl --user enable "$u" >/dev/null 2>&1 \
      && { meow_muda "builds conferidos a cada login ($u)"; rc=1; } \
      || meow_aviso "não consegui habilitar $u"
  done
  [ "$rc" = "0" ] && meow_ok "pós-apt do COSMIC no ar — depois de um apt, o que ele desfez se refaz sozinho"
  return "$rc"
}

etapa_wallpaper() {
  passo "Papéis de parede"
  local rc_semente
  "$MEOW_RAIZ/scripts/wallpaper.sh" semear-se-faltar; rc_semente=$?
  WALLPAPER_BASE="${WALLPAPER_BASE:-}" WALLPAPER_INTERVALO="${WALLPAPER_INTERVALO:-5m}" \
    WALLPAPER_ORDEM="${WALLPAPER_ORDEM:-aleatoria}" \
    WALLPAPER_FONTES_PERMITIDAS="${WALLPAPER_FONTES_PERMITIDAS-${WALLPAPER_FONTES_DELA:-}}" \
    WALLPAPER_AJUSTE="${WALLPAPER_AJUSTE:-preencher}" \
    WALLPAPER_NOITE="${WALLPAPER_NOITE:-}" WALLPAPER_NOITE_INICIO="${WALLPAPER_NOITE_INICIO:-}" \
    WALLPAPER_NOITE_FIM="${WALLPAPER_NOITE_FIM:-}" WALLPAPER_LIMIAR_LUZ="${WALLPAPER_LIMIAR_LUZ:-}" \
    "$MEOW_RAIZ/scripts/wallpaper.sh" aplicar
  local rc=$?
  [ "$rc_semente" = "$MEOW_DIVERGENTE" ] && [ "$rc" = "$MEOW_OK" ] && rc="$MEOW_DIVERGENTE"
  [ "$rc" = "1" ] && [ "${WALLPAPER_NOTIFICAR:-sim}" = "sim" ] \
    && meow_notificar "MeowSystem" "Carrossel de papéis de parede ligado."

  local destino="$HOME/.config/systemd/user" u conteudo mudou_t=0
  if [ "${AUTO_REPARO:-sim}" != "sim" ]; then
    if meow_unidade_sobrou meow-wallpaper.timer meow-wallpaper.service meow-fundo.path meow-ativos.path; then
      meow_seco && { meow_muda "removeria o relógio e os dois gatilhos do carrossel"; return "$MEOW_DIVERGENTE"; }
      systemctl --user disable --now meow-wallpaper.timer meow-fundo.path meow-ativos.path >/dev/null 2>&1
      rm -f "$destino/meow-wallpaper.timer" "$destino/meow-wallpaper.service" \
            "$destino/meow-fundo.path" "$destino/meow-ativos.path"
      rm -f "$destino"/*.wants/meow-wallpaper.timer "$destino"/*.wants/meow-fundo.path \
            "$destino"/*.wants/meow-ativos.path \
            "$destino"/*.requires/meow-wallpaper.timer "$destino"/*.requires/meow-fundo.path \
            "$destino"/*.requires/meow-ativos.path
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "AUTO_REPARO=\"${AUTO_REPARO:-}\" — relógio E gatilho do carrossel desligados e removidos"
      return "$MEOW_DIVERGENTE"
    fi
    return "$rc"
  fi
  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    return "$rc"
  fi
  local _ativos="${WALLPAPER_BASE:-$HOME/.local/share/backgrounds/meowsystem}/ativos"
  for u in meow-wallpaper.service meow-wallpaper.timer meow-fundo.path meow-ativos.path; do
    [ -f "$MEOW_RAIZ/systemd/$u" ] || { meow_erro "falta systemd/$u"; return "$MEOW_ERRO"; }
    conteudo="$(cat "$MEOW_RAIZ/systemd/$u")"
    [ "$u" = "meow-ativos.path" ] && conteudo="${conteudo//@ATIVOS@/$_ativos}"
    meow_escrever "$destino/$u" "$conteudo" 644
    case $? in 1) mudou_t=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac
  done
  if meow_seco; then
    local soltas=()
    for u in meow-wallpaper.timer meow-fundo.path meow-ativos.path; do
      if [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" != "enabled" ] ||
         [ "$(systemctl --user is-active  "$u" 2>/dev/null)" != "active" ]; then
        soltas+=("$u")
      fi
    done
    [ "$mudou_t" = "1" ] && meow_muda "instalaria/atualizaria o relógio (15 min) e o gatilho do carrossel"
    [ "${#soltas[@]}" -gt 0 ] && meow_muda "armaria o carrossel (${soltas[*]})"
    { [ "$mudou_t" = "1" ] || [ "${#soltas[@]}" -gt 0 ]; } && return "$MEOW_DIVERGENTE"
    return "$rc"
  fi
  [ "$mudou_t" = "1" ] && systemctl --user daemon-reload
  for u in meow-wallpaper.timer meow-fundo.path meow-ativos.path; do
    if [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" != "enabled" ] ||
       [ "$(systemctl --user is-active  "$u" 2>/dev/null)" != "active" ]; then
      systemctl --user enable --now "$u" >/dev/null 2>&1 \
        || { meow_erro "não consegui ligar o $u"; return "$MEOW_ERRO"; }
      mudou_t=1
    fi
  done
  [ "$mudou_t" = "1" ] && {
    meow_ok "carrossel protegido: relógio de 15 min + gatilho na config + vigia de ativos/"
    return "$MEOW_DIVERGENTE"
  }
  return "$rc"
}

uso() {
  cat <<'FIM'

install.sh — instala o MeowSystem inteiro.

  ./install.sh              faz tudo, sem perguntar nada, e repete a fila até
                            nenhuma etapa precisar escrever (no máximo 5 vezes)
  ./install.sh --dry-run    mostra o que faria, sem escrever nada
  ./install.sh --uma-passagem
                            roda a fila UMA vez e para, mesmo que alguma etapa
                            dependa do resultado da anterior (depuração)
  ./install.sh --etapa <nome>[,<nome>]
                            roda só essas etapas (os nomes de `local etapas`, sem
                            o prefixo etapa_); é o que o painel usa para aplicar
                            uma chave que acabou de gravar
  ./install.sh --wizard     roda `meow configurar` antes (pergunta as chaves do
                            meow.conf, grava lá) e então instala como sempre
  ./install.sh --uninstall  tira o MeowSystem desta máquina
  ./install.sh --perfil <nome>
                            copia perfis/<nome>/ (meow.conf e o mapa dos ícones
                            escolhidos) para ~/.config/meow/, guardando o de
                            antes ao lado, e instala com ele
  ./install.sh --help       isto aqui

  MEOW_DRY_RUN=1 ./install.sh   o mesmo que --dry-run, para script e timer

O ensaio é sempre de uma passagem só: no seco nada é escrito, então a etapa que
diverge hoje divergiria igual na passagem seguinte.

Sem --etapa, quais etapas rodam é decisão do meow.conf. Com --etapa, só as
nomeadas rodam, na ordem da fila, e a pendência de root não é reavaliada.

FIM
}

aplicar_perfil() {
  local nome="$1" dir arq destino quando
  case "$nome" in
    ""|[-_]*|*[!a-z0-9_-]*)
      meow_erro "perfil '$nome' não é um nome de perfil (letras minúsculas, números, - e _)"
      return "$MEOW_ERRO" ;;
  esac
  dir="$MEOW_RAIZ/perfis/$nome"
  if [ ! -f "$dir/meow.conf" ]; then
    meow_erro "não existe o perfil '$nome' (perfis/$nome/meow.conf)"
    return "$MEOW_ERRO"
  fi
  quando="$(date +%Y%m%d-%H%M%S)"
  for arq in meow.conf icones-escolhidos.map; do
    [ -f "$dir/$arq" ] || continue
    destino="$(dirname "$CONF")/$arq"
    cmp -s "$dir/$arq" "$destino" && continue
    if meow_seco; then
      meow_muda "copiaria o perfil $nome para $destino"
      continue
    fi
    meow_destino_permitido "$destino" || return "$MEOW_ERRO"
    mkdir -p "$(dirname "$destino")" || return "$MEOW_ERRO"
    if [ -f "$destino" ]; then
      cp -p -- "$destino" "$destino.antes-perfil-$quando" || return "$MEOW_ERRO"
    fi
    cp -- "$dir/$arq" "$destino.meow-perfil.tmp" && mv -f "$destino.meow-perfil.tmp" "$destino" \
      || { rm -f "$destino.meow-perfil.tmp"; meow_erro "não consegui copiar o perfil para $destino"; return "$MEOW_ERRO"; }
    meow_ok "perfil $nome: $destino"
  done
  if meow_seco; then
    CONF="$dir/meow.conf"
    MEOW_CONF_ARQUIVO="$CONF"
  fi
  return 0
}

main() {
  if [ "$(id -u)" = "0" ]; then
    meow_erro "com sudo, não: os arquivos de ~/.config ficariam de dono root — nada foi feito."
    if [ -n "${SUDO_USER:-}" ]; then
      meow_info "  o instalador roda como $SUDO_USER, na sessão gráfica dele"
    else
      meow_info "  o instalador roda como o seu usuário, na sua sessão"
    fi
    meow_info "  o sudo é pedido por dentro, só onde precisa, e diz o que vai rodar antes."
    meow_info "  instalar em nome de outra pessoa não funciona por sudo -u: as etapas"
    meow_info "  de systemd --user precisam do DBUS/XDG_RUNTIME_DIR da sua sessão."
    return 2
  fi

  local wizard=0 desinstalar=0 uma_passagem=0 perfil="" com_perfil=0 so_etapas=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --wizard|-w) wizard=1 ;;
      --uma-passagem) uma_passagem=1 ;;
      --etapa)     so_etapas="${2:-}"; [ $# -gt 0 ] && shift ;;
      --etapa=*)   so_etapas="${1#--etapa=}" ;;
      --dry-run|--seco|-n)       MEOW_SECO=1; MEOW_DRY_RUN=1; export MEOW_DRY_RUN ;;
      --uninstall|--desinstalar) desinstalar=1 ;;
      --perfil)    com_perfil=1; perfil="${2:-}"; [ $# -gt 0 ] && shift ;;
      --perfil=*)  com_perfil=1; perfil="${1#--perfil=}" ;;
      -h|--help)   uso; return 0 ;;
      "")          ;;
      *) meow_erro "opção desconhecida: $1"
         meow_info "o que existe: --dry-run, --uma-passagem, --etapa <nome>, --wizard, --perfil <nome>, --uninstall, --help."
         return 2 ;;
    esac
    shift
  done

  if [ ! -t 1 ] && [ -z "${LOG_NIVEL:-}" ]; then
    MEOW_LOG_NIVEL=silencioso
  fi

  if [ "$com_perfil" = "1" ]; then
    aplicar_perfil "$perfil" || return 2
  fi

  local nome_pack
  nome_pack="$(python3 "$MEOW_RAIZ/scripts/pack.py" adocao \
                 "${PACK:-$(meow_conf_valor PACK || true)}" \
                 "${FLAVOR:-$(meow_conf_valor FLAVOR || true)}" 2>/dev/null \
               | sed -n 's/^nome=//p')"
  meow_titulo "MeowSystem${nome_pack:+ — $nome_pack} para o COSMIC"
  meow_seco && meow_aviso "ensaio (MEOW_DRY_RUN=1) — nada será escrito"

  if [ "$wizard" = "1" ]; then
    MEOW_WIZARD_SEM_APLICAR=1 MEOW_RAIZ="$MEOW_RAIZ" "$MEOW_RAIZ/bin/meow" configurar
    local rc_wiz=$?
    if [ "$rc_wiz" -ge 2 ]; then
      meow_erro "o wizard falhou — nada foi instalado"
      return 2
    fi
  fi

  etapa_conf_ler || return 2

  if [ "$desinstalar" = "1" ]; then
    # shellcheck source=lib/desinstalar.sh
    . "$MEOW_RAIZ/lib/desinstalar.sh"
    meow_travar || return 2
    meow_desinstalar; return $?
  fi

  meow_ponte_python || return 2

  meow_preflight; local rc_pf=$?
  [ "$rc_pf" = "2" ] && return 2

  meow_travar || return 2

  local etapas=(etapa_backup_tema etapa_conf etapa_cli etapa_ponte_root etapa_atalho etapa_pacotes etapa_gerar etapa_tema
                etapa_modo etapa_greeter etapa_vidro etapa_forma etapa_painel etapa_janelas etapa_relogio etapa_leitura etapa_escala etapa_upstream etapa_fontes
                etapa_svg etapa_icones etapa_pastas_xdg etapa_pastas etapa_hicolor etapa_completar_icones
                etapa_mimetypes etapa_icones_resgatados etapa_icones_apps_arcticons etapa_icones_apps_dracula etapa_icones_sistema etapa_icones_bandeja
                etapa_icones_tray_steam etapa_icones_tray_zapzap etapa_jogos etapa_jogos_heroic
                etapa_logo etapa_icones_indice etapa_wallpaper etapa_ocultar etapa_nomes etapa_absolutos etapa_ocultar_casa etapa_janela_dock
                etapa_lancador_apt etapa_som etapa_terminal etapa_prompt etapa_fzf etapa_fastfetch_logo etapa_bloco_terminal etapa_files_menu etapa_cursor etapa_flatpak_tema etapa_escritorio etapa_apps
                etapa_assets etapa_vigia_flatpak etapa_vigia_steam etapa_vigia_heroic etapa_vigia_qt etapa_vigia_apt etapa_vigia_derivados
                etapa_extensoes etapa_compositor etapa_extensoes_tema etapa_midia etapa_lancador etapa_autostart etapa_autoreparo)
  if [ -n "$so_etapas" ]; then
    local pedida escolhida escolhidas=()
    for pedida in ${so_etapas//,/ }; do
      case " ${etapas[*]} " in
        *" etapa_$pedida "*) ;;
        *) meow_erro "etapa desconhecida: $pedida"; return 2 ;;
      esac
    done
    for escolhida in "${etapas[@]}"; do
      case ",${so_etapas// /}," in *",${escolhida#etapa_},"*) escolhidas+=("$escolhida") ;; esac
    done
    etapas=("${escolhidas[@]}")
  fi
  TOTAL=${#etapas[@]}

  local teto=5
  { [ "$uma_passagem" = "1" ] || meow_seco; } && teto=1

  local passagem=0 ainda=0 parar_conf=0 oscilou=0
  local assinatura="" assinatura_anterior=""

  if ! meow_seco; then
    MEOW_RELER_NO_FIM="$(mktemp "${TMPDIR:-/tmp}/meow-reler.XXXXXX" 2>/dev/null)" \
      && export MEOW_RELER_NO_FIM
  fi
  while :; do
    passagem=$((passagem + 1))

    FEITOS=(); CONFEREM=(); PULADOS=(); FALHOS=(); PULADOS_OPTIN=()
    PASSO=0

    if [ "$teto" -gt 1 ]; then
      local cabeca="passagem $passagem de até $teto"
      if [ "$passagem" -gt 1 ]; then
        if [ "$ainda" = "1" ]; then
          cabeca="$cabeca · 1 etapa ainda muda"
        else
          cabeca="$cabeca · $ainda etapas ainda mudam"
        fi
      fi
      if meow_quieto; then
        printf '\n  %s%s%s\n' "$C_MAUVE$C_FORTE" "$cabeca" "$C_ZERO"
      else
        meow_passo "$cabeca"
      fi
    fi

    for e in "${etapas[@]}"; do
      "$e"; local rc=$?
      concluir "${e#etapa_}" "$rc"
      if [ "$e" = "etapa_conf" ] && [ "$rc" -ge 2 ]; then
        meow_erro "sem configuração válida não há o que instalar — parando"
        parar_conf=1
        break
      fi
    done

    meow_passo "Resultado"
    [ ${#FEITOS[@]}   -gt 0 ] && meow_muda  "mexeu:  ${FEITOS[*]}"
    [ ${#CONFEREM[@]} -gt 0 ] && meow_ok    "confere: ${CONFEREM[*]}"
    [ ${#PULADOS[@]}  -gt 0 ] && meow_pula  "pulado: ${PULADOS[*]}"
    [ ${#FALHOS[@]}   -gt 0 ] && meow_erro  "falhou: ${FALHOS[*]}"

    if [ -n "$so_etapas" ]; then
      :
    elif [ ${#PULADOS[@]} -gt 0 ]; then
      local p por_root=0 sem_captura="" de_root=""
      for p in "${PULADOS[@]}"; do
        case " ${PULADOS_OPTIN[*]:-} " in *" $p "*) continue ;; esac
        if [ "$p" = "greeter" ] && [ -n "${TEMA_SEM_CAPTURA:-}" ]; then
          sem_captura="$TEMA_SEM_CAPTURA"; continue
        fi
        case "$p" in greeter|ocultar|nomes|absolutos|flatpak_tema|escritorio) por_root=1; de_root="${de_root:+$de_root }$p" ;; esac
      done
      [ "$por_root" = "1" ] && meow_pendencia_acionavel instalar-com-root \
        "Etapas que precisavam de root e se pularam: $de_root" "./install.sh"
      case "$sem_captura" in
        deriva) meow_info "greeter: no ensaio a captura do tema ainda não foi escrita (a etapa tema a deriva antes da tela de login) — não é falta de root" ;;
        falta)  meow_info "greeter: a tela de login veste o tema do COSMIC, e ele não tem captura — não é falta de root" ;;
      esac
      [ ${#PULADOS_OPTIN[@]} -gt 0 ] && \
        meow_info "${PULADOS_OPTIN[*]}: é opt-in, não é falta de root — LANCADOR_SISTEMA=\"sim\" no meow.conf liga"
      [ "$por_root" = "1" ] || meow_pendencia_resolvida instalar-com-root
    else
      meow_pendencia_resolvida instalar-com-root
    fi

    meow_registrar "install.sh passagem=$passagem mexeu=${#FEITOS[@]} conferem=${#CONFEREM[@]} pulados=${#PULADOS[@]} falhos=${#FALHOS[@]}"

    ainda=${#FEITOS[@]}

    [ "$ainda" -eq 0 ] && break
    [ "$parar_conf" = "1" ] && break
    [ "$passagem" -ge "$teto" ] && break

    assinatura="$(printf '%s\n' "${FEITOS[@]}" | sort | tr '\n' ' ')"
    if [ "$assinatura" = "$assinatura_anterior" ]; then oscilou=1; break; fi
    assinatura_anterior="$assinatura"
  done
  meow_tela_reler_no_fim

  local laco_quebrado=0

  if [ "$oscilou" = "1" ]; then
    meow_erro "as mesmas etapas escreveram em duas passagens seguidas:  ${FEITOS[*]}"
    meow_aviso "isto não é a cadeia de dependências — é defeito de idempotência:"
    meow_aviso "alguma delas escreve toda vez, e passagem nenhuma vai calá-la."
    meow_aviso "o que olhar primeiro:  meow doctor"
    printf '\n'
    laco_quebrado=1
  elif [ "$ainda" -gt 0 ] && [ "$teto" -gt 1 ] && [ "$parar_conf" != "1" ]; then
    meow_erro "$teto passagens, e estas etapas ainda escrevem:  ${FEITOS[*]}"
    meow_aviso "parei no teto de propósito: um laço sem fim esconderia o defeito."
    meow_aviso "o que olhar primeiro:  meow doctor"
    printf '\n'
    laco_quebrado=1
  fi

  if [ ${#FALHOS[@]} -gt 0 ]; then
    if meow_seco; then
      printf '\n  %sAlgumas etapas falharam no ensaio. Nada foi escrito:%s\n' "$C_AMARELO" "$C_ZERO"
      printf '  %sas outras dizem acima o que fariam.%s\n\n' "$C_AMARELO" "$C_ZERO"
      return 2
    fi
    printf '\n  %sAlgumas etapas falharam. Nada foi deixado pela metade —%s\n' "$C_AMARELO" "$C_ZERO"
    printf '  %scada etapa é independente, e o resto foi aplicado.%s\n\n' "$C_AMARELO" "$C_ZERO"
    return 2
  fi
  [ "$laco_quebrado" = "1" ] && return 2

  if [ -n "${TEMA_NAO_APLICADO:-}" ] && ! meow_seco; then
    printf '\n  %s%s%s\n' "$C_AMARELO$C_FORTE" "$TEMA_NAO_APLICADO" "$C_ZERO"
    local onde; onde="$(meow_onde_no_painel inicio)"
    printf '  O resto do instalador seguiu; a pendência fica no painel%s.\n\n' "${onde:+, $onde}"
    return "$MEOW_DIVERGENTE"
  fi

  if [ "$ainda" -gt 0 ]; then
    local mudaram="mudaram"
    meow_seco && mudaram="mudariam"
    printf '\n  %s%d etapa(s) %s nesta passagem.%s\n' \
      "$C_AMARELO$C_FORTE" "$ainda" "$mudaram" "$C_ZERO"
    printf '  Esta execução teve uma passagem só. Algumas etapas dependem do\n'
    printf '  resultado da anterior; sem --uma-passagem (e fora do ensaio) o\n'
    printf '  instalador repete sozinho até ninguém mais escrever:\n\n'
    printf '      ./install.sh\n\n'
    return 0
  fi

  [ -z "$so_etapas" ] && meow_pendencia_resolvida aplicar-ajuste
  local plural="passagens"
  [ "$passagem" = "1" ] && plural="passagem"
  printf '\n  %sPronto.%s %d %s, %d etapas, nada mais a escrever.\n\n' \
    "$C_VERDE$C_FORTE" "$C_ZERO" "$passagem" "$plural" "$TOTAL"
  return 0
}

main "$@"

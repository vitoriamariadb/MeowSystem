#!/usr/bin/env bash
meow_desinstalar() {
  meow_titulo "MeowSystem — desinstalar"
  meow_info "isto NÃO desinstala pacotes do apt nem apaga o clone do repositório"
  meow_seco && meow_aviso "ensaio: nada será removido"

  meow_passo "1/6 Relógios e gatilhos"
  if ! meow_seco; then
    systemctl --user disable --now \
      meow-doctor.timer meow-doctor.service \
      meow-logo.timer meow-logo.service \
      meow-wallpaper.timer meow-wallpaper.service meow-fundo.path \
      meow-assets.path meow-assets.service \
      meow-derivados.path meow-derivados.service \
      meow-flatpak.path meow-flatpak.service \
      meow-steam.path meow-steam.service \
      meow-qt.path meow-qt.service \
      meow-leitura.timer meow-leitura.service \
      meow-gato.timer meow-gato.service meow-ativos.path \
      meow-heroic.path meow-heroic.service \
      meow-discord.path meow-discord.service \
      meow-pos-apt.path meow-pos-apt.service meow-builds-login.service \
      meow-sentinela.timer meow-sentinela.service meow-sentinela.path \
      meow-painel.service meow-painel-raio.path meow-painel-raio.service \
      meow-som.service meow-vidro.path meow-vidro.service 2>/dev/null || true
    while IFS= read -r -d '' u; do meow_guardar_antes "$u"; done < <(
      find "$HOME/.config/systemd/user" -maxdepth 2 -name 'meow-*' \
        \( -name '*.service' -o -name '*.timer' -o -name '*.path' \) -print0 2>/dev/null)
    find "$HOME/.config/systemd/user" -maxdepth 1 -name 'meow-*' \
      \( -name '*.service' -o -name '*.timer' -o -name '*.path' \) -delete 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user"/*.wants/meow-* \
          "$HOME/.config/systemd/user"/*.requires/meow-* 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    meow_ok "unidades meow-* desligadas e removidas"
  else
    meow_muda "desligaria e removeria as unidades meow-* de ~/.config/systemd/user"
    meow_muda "  e os links em *.target.wants/ que sobrariam órfãos sem o disable"
  fi

  local hook=/etc/apt/apt.conf.d/99-meow-lancador
  local wrapper=/usr/local/sbin/meow-lancador-apt.sh
  if [ -f "$hook" ] || [ -f "$wrapper" ]; then
    if meow_seco; then
      meow_muda "removeria $hook e $wrapper"
    elif meow_ponte apt-hook-remover >/dev/null 2>&1 || sudo rm -f "$hook" "$wrapper" 2>/dev/null; then
      meow_ok "hook de apt do lançador removido"
    else
      meow_aviso "sem sudo para remover o hook de apt do lançador"
      meow_info "  ficaram, por serem do root: $hook e $wrapper"
    fi
  fi

  local comp_sistema=/usr/local/share/zsh/site-functions/_meow
  if [ -f "$comp_sistema" ]; then
    if meow_seco; then
      meow_muda "removeria $comp_sistema"
    elif meow_ponte completion-remover </dev/null >/dev/null 2>&1 || sudo rm -f "$comp_sistema" 2>/dev/null; then
      meow_ok "completion do zsh removida de $comp_sistema"
    else
      meow_aviso "sem sudo para remover a completion do zsh"
      meow_info "  ficou, por ser do root: $comp_sistema"
    fi
  fi

  if [ -x "$MEOW_RAIZ/scripts/escritorio.sh" ]; then
    "$MEOW_RAIZ/scripts/escritorio.sh" reverter || true
  fi
  if [ -x "$MEOW_RAIZ/scripts/gpu_compositor.sh" ]; then
    "$MEOW_RAIZ/scripts/gpu_compositor.sh" reverter || true
  fi

  local regra_ponte=/etc/sudoers.d/49-meowsystem-ponte
  local braco_ponte=/usr/local/lib/meowsystem
  local reparo_ponte=/etc/systemd/system/meowsystem-ponte-reparo.service
  local polkit_ponte=/etc/polkit-1/rules.d/49-meowsystem-ponte-reparo.rules
  if [ -f "$regra_ponte" ] || [ -d "$braco_ponte" ] || [ -f "$reparo_ponte" ]; then
    if meow_seco; then
      meow_muda "removeria $regra_ponte, $braco_ponte e o reparo da ponte"
    elif sudo rm -f "$regra_ponte" "$polkit_ponte" "$reparo_ponte" 2>/dev/null \
         && sudo rm -rf "$braco_ponte" 2>/dev/null; then
      sudo systemctl daemon-reload 2>/dev/null || true
      meow_ok "ponte root, regra de sudo e reparo removidos"
    else
      meow_aviso "sem sudo para remover a ponte root — a regra de sudo sem senha FICOU"
      meow_info "  ficaram, por serem do root: $regra_ponte e $braco_ponte"
    fi
  fi

  if [ -x "$MEOW_RAIZ/scripts/icones_tray_zapzap.sh" ]; then
    "$MEOW_RAIZ/scripts/icones_tray_zapzap.sh" --desfazer || true
  fi

  "$MEOW_RAIZ/scripts/terminal_bloco.sh" remover || true

  meow_passo "2/6 Temas por aplicativo"
  if [ -n "${APPS_ATIVOS:-}" ]; then
    MEOW_REVERTER_SEM_DESLIGAR=1 APPS_ATIVOS="$APPS_ATIVOS" FLAVOR="${FLAVOR:-}" ACCENT="${ACCENT:-}" \
      "$MEOW_RAIZ/scripts/aplicar_apps.sh" reverter || true
  else
    meow_pula "APPS_ATIVOS vazio no meow.conf — nenhum tema de aplicativo para desfazer"
  fi

  if [ -x "$MEOW_RAIZ/scripts/midia.sh" ]; then
    "$MEOW_RAIZ/scripts/midia.sh" --reverter || true
  fi

  if [ -x "$MEOW_RAIZ/scripts/ocultar_casa.sh" ]; then
    "$MEOW_RAIZ/scripts/ocultar_casa.sh" --reverter || true
  fi
  if [ -x "$MEOW_RAIZ/scripts/appid_dock.sh" ]; then
    "$MEOW_RAIZ/scripts/appid_dock.sh" --reverter || true
  fi
  if [ -x "$MEOW_RAIZ/scripts/lancador.sh" ]; then
    "$MEOW_RAIZ/scripts/lancador.sh" --reverter || true
  fi

  if [ -x "$MEOW_RAIZ/scripts/extensoes_tema.sh" ]; then
    "$MEOW_RAIZ/scripts/extensoes_tema.sh" --reverter || true
  fi
  if [ -x "$MEOW_RAIZ/scripts/extensoes_build.sh" ]; then
    EXTENSOES= "$MEOW_RAIZ/scripts/extensoes_build.sh" --todas --reverter || true
  fi

  if [ -x "$MEOW_RAIZ/scripts/atalho.sh" ]; then
    "$MEOW_RAIZ/scripts/atalho.sh" --reverter || true
  fi

  if [ -x "$MEOW_RAIZ/scripts/fastfetch_logo.sh" ]; then
    "$MEOW_RAIZ/scripts/fastfetch_logo.sh" reverter || true
  fi

  if [ -x "$MEOW_RAIZ/scripts/flatpak_tema.sh" ]; then
    "$MEOW_RAIZ/scripts/flatpak_tema.sh" reverter || true
  fi

  meow_passo "3/6 Tema do COSMIC"
  local primeiro=""
  local d
  for d in "$MEOW_ESTADO"/backups/*-tema-PRIMEIRO-*; do
    [ -d "$d" ] && { primeiro="$d"; break; }
  done
  if [ -n "$primeiro" ]; then
    meow_info "devolvendo o COSMIC ao estado de $(basename "$primeiro" | cut -c1-19)"
    local destino; destino="$(meow_cosmic_dir)"
    if meow_seco; then
      meow_muda "copiaria $primeiro/com.system76.CosmicTheme.* para $destino/"
    else
      cp -a "$primeiro"/com.system76.CosmicTheme.* "$destino/" 2>/dev/null || true
      meow_ok "tema devolvido"
    fi
  else
    meow_aviso "não há backup pré-instalação em $MEOW_ESTADO/backups/*-tema-PRIMEIRO-*"
    meow_info "  o tema do COSMIC fica como está — ajuste em Configurações > Aparência"
    meow_info "  (a captura assets/temas/capturados/original NÃO serve: é o tema de outra máquina)"
  fi

  meow_passo "4/6 Arquivos que este projeto escreveu"
  if [ -f "$MEOW_MANIFESTO" ]; then
    local raiz_clone=""
    [ -n "${MEOW_RAIZ:-}" ] && raiz_clone="$(readlink -m -- "$MEOW_RAIZ")"
    local alvo _quando sha agora real n=0
    while IFS=$'\t' read -r alvo _quando sha; do
      [ -n "$alvo" ] || continue
      if [ -n "$raiz_clone" ]; then
        real="$(readlink -m -- "$alvo")"
        case "$real" in "$raiz_clone"/*)
          meow_pula "é do clone e o git responde por ele, fica: $alvo"; continue ;;
        esac
      fi
      case "$alvo" in "$HOME"/*) ;; *) continue ;; esac
      [ -f "$alvo" ] || continue
      agora="$(sha256sum -- "$alvo" 2>/dev/null | cut -d' ' -f1)"
      if [ -n "$sha" ] && [ "$sha" != "-" ] && [ "$agora" != "$sha" ]; then
        meow_pula "mudou depois que escrevemos, fica: $alvo"
        continue
      fi
      if meow_seco; then meow_muda "removeria $alvo"; else meow_guardar_antes "$alvo"; rm -f "$alvo"; fi
      n=$((n+1))
    done < "$MEOW_MANIFESTO"
    meow_seco || meow_ok "$n arquivo(s) removidos pelo manifesto"
  else
    meow_pula "sem manifesto em $MEOW_MANIFESTO — nada a remover por lista"
    meow_info "  o manifesto só existe a partir da primeira instalação que o gravou"
  fi

  meow_passo "5/6 Árvores inteiras"
  local dir
  for dir in "$HOME/.local/share/icons/${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
             "$HOME/.local/share/fonts/MeowSystem" \
             "$HOME/.local/state/meowsystem/midia" \
             "$HOME/.local/state/meowsystem/leitura"; do
    [ -d "$dir" ] || continue
    if meow_seco; then meow_muda "removeria $dir/"; continue; fi
    case "$dir" in */meowsystem/midia|*/meowsystem/leitura) ;; *) meow_guardar_pasta "$dir" ;; esac
    rm -rf "$dir"; meow_ok "removido $dir/"
  done

  meow_desinstalar_bases_de_icones

  local acervo="${WALLPAPER_BASE:-$HOME/.local/share/backgrounds/meowsystem}"
  if [ -d "$acervo" ]; then
    if [ "${MEOW_APAGAR_ACERVO:-0}" = "1" ]; then
      if meow_seco; then
        meow_muda "removeria $acervo/ (MEOW_APAGAR_ACERVO=1)"
      else
        rm -rf "$acervo"; meow_ok "removido $acervo/ (você pediu com MEOW_APAGAR_ACERVO=1)"
      fi
    else
      local n_ativos n_banidos tamanho
      n_ativos="$(find "$acervo/ativos"  -maxdepth 1 -type f 2>/dev/null | wc -l)"
      n_banidos="$(find "$acervo/banidos" -maxdepth 1 -type f 2>/dev/null | wc -l)"
      tamanho="$(du -sh "$acervo" 2>/dev/null | cut -f1)"
      meow_pula "acervo de papel de parede PRESERVADO — é curadoria sua, não arquivo nosso"
      meow_info "  $acervo/  ($tamanho: $n_ativos ativos, $n_banidos banidos)"
    fi
  fi

  local curadoria="$MEOW_ESTADO/papeis-de-parede"
  if [ -d "$curadoria" ]; then
    if [ "${MEOW_APAGAR_ACERVO:-0}" = "1" ]; then
      if meow_seco; then
        meow_muda "removeria $curadoria/ (MEOW_APAGAR_ACERVO=1)"
      else
        rm -rf "$curadoria"; meow_ok "removido $curadoria/ (você pediu com MEOW_APAGAR_ACERVO=1)"
      fi
    else
      meow_pula "listas de curadoria de papel de parede PRESERVADAS — é escolha sua, não arquivo nosso"
      meow_info "  $curadoria/  (BANIDOS.txt e lado.tsv)"
      meow_info "  o .padrao do repositório repõe a lista de fábrica, não o que você acrescentou"
    fi
  fi

  local derivada
  for derivada in "$acervo/ativos-noite" "$acervo/ativos-dia"; do
    [ -d "$derivada" ] || continue
    if meow_seco; then meow_muda "removeria $derivada/ (derivada, link duro)"
    else meow_guardar_pasta "$derivada"; rm -rf "$derivada"; meow_ok "removido $derivada/ (derivada, link duro)"; fi
  done
  if ! meow_seco; then
    meow_tem gtk-update-icon-cache && gtk-update-icon-cache -f "$HOME/.local/share/icons" 2>/dev/null
    meow_tem fc-cache && fc-cache -f "$HOME/.local/share/fonts" 2>/dev/null
  fi

  meow_passo "6/6 CLI e estado"
  if meow_seco; then
    meow_muda "removeria ~/.local/bin/meow e a completion do zsh"
  else
    meow_guardar_antes "$HOME/.local/bin/meow"
    rm -f "$HOME/.local/bin/meow"
    COMP_MEOW="${MEOW_COMPLETIONS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions}/_meow"
    if [ -e "$COMP_MEOW" ]; then
      if [ -w "$(dirname "$COMP_MEOW")" ]; then
        meow_guardar_antes "$COMP_MEOW"
        rm -f "$COMP_MEOW"
      else
        meow_info "a completion é do root: sudo rm -f $COMP_MEOW"
      fi
    fi
    unset COMP_MEOW
    meow_guardar_antes "$MEOW_ESTADO/raiz"
    rm -f "$MEOW_ESTADO/raiz"
    meow_ok "CLI removida"
  fi
  local temas_gerados="$MEOW_ESTADO/temas"
  if [ -d "$temas_gerados" ]; then
    if meow_seco; then
      meow_muda "removeria $temas_gerados/ (.ron gerados, regeráveis pela paleta)"
    else
      meow_guardar_pasta "$temas_gerados"; rm -rf "$temas_gerados"; meow_ok "removido $temas_gerados/ (.ron gerados)"
    fi
  fi

  meow_info "o estado e os backups ficam em $MEOW_ESTADO — apague à mão se quiser"
  if [ -d "$MEOW_ESTADO/papeis-de-parede" ]; then
    meow_info "  menos $MEOW_ESTADO/papeis-de-parede/ — é a sua curadoria de papel de parede"
  fi
  meow_info "os .desktop do sistema que o lançador escondia voltam com o «Tema de antes»"
  return 0
}

meow_desinstalar_bases_de_icones() {
  local dir raiz="$HOME/.local/share/icons/${NOME_TEMA_ICONES:-MeowSystem-Icons}-Base"
  for dir in "$raiz" "$raiz"-[0-9]*; do
    [ -d "$dir" ] || continue
    case "${dir#"$raiz"}" in ''|-[0-9]*) ;; *) continue ;; esac
    if [ ! -f "$dir/.meow-origem" ]; then
      meow_pula "não foi o MeowSystem que pôs, fica: $dir/"
    elif meow_seco; then
      meow_muda "removeria $dir/"
    else
      meow_guardar_pasta "$dir"; rm -rf "$dir"; meow_ok "removido $dir/"
    fi
  done
}

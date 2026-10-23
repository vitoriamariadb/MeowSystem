#!/usr/bin/env bash
# desinstalar.sh — tira o MeowSystem da máquina. Lê o manifesto; não adivinha.
#
# Quem chama é `./install.sh --uninstall`.
#
# Uma segunda lista envelheceria em silêncio: cada etapa nova escreveria num
# lugar que o desinstalador não conhece, e ninguém descobriria isso até alguém
# tentar desinstalar.
#
# Os relógios saem PRIMEIRO.
#
# Nem arquivo que a pessoa editou depois: o sha256 do manifesto é o que separa
# "isto é nosso" de "isto virou dela".
meow_desinstalar() {
  meow_titulo "MeowSystem — desinstalar"
  meow_info "isto NÃO desinstala pacotes do apt nem apaga o clone do repositório"
  meow_seco && meow_aviso "ensaio: nada será removido"

  meow_passo "1/6 Relógios e gatilhos"
  # O `find … -delete` abaixo é `-maxdepth 1`: ele apaga os ARQUIVOS de
  # `~/.config/systemd/user`, e não toca nos symlinks que moram um nível abaixo,
  # em `*.target.wants/`.
  #
  # `meow-painel.service` é o que mais importa parar: ele é `Type=simple` com
  # `Restart=on-failure`, um laço vivo repondo o `cosmic-panel`.
  if ! meow_seco; then
    # `|| true` porque desligar unidade que não existe devolve != 0, e isso não
    # é falha: é a máquina já estando como queremos deixá-la.
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
      meow-pos-apt.path meow-pos-apt.service meow-builds-login.service \
      meow-sentinela.timer meow-sentinela.service meow-sentinela.path \
      meow-painel.service meow-painel-raio.path meow-painel-raio.service \
      meow-som.service 2>/dev/null || true
    # A LISTA NOMEADA ACIMA NÃO É REDUNDANTE COM ESTE `find`, e quem acrescentar
    # unidade nova precisa saber: o `find` APAGA o arquivo, o `disable --now` é
    # que PARA a unidade viva e tira os links.
    while IFS= read -r -d '' u; do meow_guardar_antes "$u"; done < <(
      find "$HOME/.config/systemd/user" -maxdepth 2 -name 'meow-*' \
        \( -name '*.service' -o -name '*.timer' -o -name '*.path' \) -print0 2>/dev/null)
    find "$HOME/.config/systemd/user" -maxdepth 1 -name 'meow-*' \
      \( -name '*.service' -o -name '*.timer' -o -name '*.path' \) -delete 2>/dev/null || true
    # O CINTO DOS LINKS, e ele não é redundância da lista acima: é o caso em que
    # o `disable` NÃO TEM COMO funcionar.
    rm -f "$HOME/.config/systemd/user"/*.wants/meow-* \
          "$HOME/.config/systemd/user"/*.requires/meow-* 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    meow_ok "unidades meow-* desligadas e removidas"
  else
    meow_muda "desligaria e removeria as unidades meow-* de ~/.config/systemd/user"
    meow_muda "  e os links em *.target.wants/ que sobrariam órfãos sem o disable"
  fi

  # O passo 4 anda pelo manifesto e recusa, de propósito, tudo que está fora do
  # `$HOME` — a regra que impede um manifesto de outra máquina de mandar apagar
  # caminho que não é nosso.
  #
  # Um hook órfão não é sujeira inofensiva.
  local hook=/etc/apt/apt.conf.d/99-meow-lancador
  local wrapper=/usr/local/sbin/meow-lancador-apt.sh
  if [ -f "$hook" ] || [ -f "$wrapper" ]; then
    if meow_seco; then
      meow_muda "removeria $hook e $wrapper"
    elif meow_ponte apt-hook-remover >/dev/null 2>&1 || sudo rm -f "$hook" "$wrapper" 2>/dev/null; then
      meow_ok "hook de apt do lançador removido"
    else
      # Sem sudo não apagamos escondido nem falhamos calados — mesma conduta da
      # completion no passo 6.
      meow_aviso "sem sudo para remover o hook de apt do lançador"
      meow_info "  ficaram, por serem do root: $hook e $wrapper"
    fi
  fi

  # Ela mora fora do `$HOME`, então escapa do passo 4 pelo mesmo motivo do hook
  # acima, e sai ANTES da ponte, logo abaixo: depois dela, tirar um arquivo de
  # root volta a pedir senha.
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

  # Os pacotes do LibreOffice que a troca pelo OnlyOffice tirou voltam pelo apt,
  # e voltam pela ponte, que ainda está de pé aqui.
  if [ -x "$MEOW_RAIZ/scripts/escritorio.sh" ]; then
    "$MEOW_RAIZ/scripts/escritorio.sh" reverter || true
  fi

  # Até aqui o `--uninstall` deixava para trás as duas peças com privilégio: a
  # regra `/etc/sudoers.d/49-meowsystem-ponte` e o braço
  # `/usr/local/lib/meowsystem/ponte_root.sh`.
  #
  # A REGRA PRIMEIRO, o braço depois.
  local regra_ponte=/etc/sudoers.d/49-meowsystem-ponte
  local braco_ponte=/usr/local/lib/meowsystem
  if [ -f "$regra_ponte" ] || [ -d "$braco_ponte" ]; then
    if meow_seco; then
      meow_muda "removeria $regra_ponte e $braco_ponte"
    elif sudo rm -f "$regra_ponte" 2>/dev/null && sudo rm -rf "$braco_ponte" 2>/dev/null; then
      meow_ok "ponte root e regra de sudo removidas"
    else
      # Mesma conduta do hook acima: sem sudo não apagamos escondido nem
      # falhamos calados. E aqui o aviso pesa mais, porque o que fica é
      # privilégio, não configuração.
      meow_aviso "sem sudo para remover a ponte root — a regra de sudo sem senha FICOU"
      meow_info "  ficaram, por serem do root: $regra_ponte e $braco_ponte"
    fi
  fi

  # O hook acima escapa do passo 4 por morar fora do `$HOME`.
  #
  # Deixar para trás é que não dá.
  if [ -x "$MEOW_RAIZ/scripts/icones_tray_zapzap.sh" ]; then
    "$MEOW_RAIZ/scripts/icones_tray_zapzap.sh" --desfazer || true
  fi

  meow_passo "2/6 Temas por aplicativo"
  # A LISTA VEM DA CONF DELA, e um APPS_ATIVOS vazio significa "ela nunca ligou
  # nenhum" — não há o que desfazer, e chamar o runner com lista vazia só
  # imprimiria um resumo em branco.
  if [ -n "${APPS_ATIVOS:-}" ]; then
    APPS_ATIVOS="$APPS_ATIVOS" FLAVOR="${FLAVOR:-}" ACCENT="${ACCENT:-}" \
      "$MEOW_RAIZ/scripts/aplicar_apps.sh" reverter || true
  else
    meow_pula "APPS_ATIVOS vazio no meow.conf — nenhum tema de aplicativo para desfazer"
  fi

  # O `--reverter` remove a SOMBRA primeiro (`~/.local/share/applications/…
  # NowPlaying.desktop`) e só depois o binário.
  if [ -x "$MEOW_RAIZ/scripts/midia.sh" ]; then
    "$MEOW_RAIZ/scripts/midia.sh" --reverter || true
  fi

  # `leitura_build.sh --reverter` remove a SOMBRA, depois o binário, depois a
  # árvore de build — e a ordem mora lá dentro pelo motivo do parágrafo acima: o
  # `cosmic-panel` casa o applet pelo basename do `.desktop` e consome o slot no
  # primeiro acerto, então sombra sem binário deixa BURACO na barra, não o
  # applet de fábrica.
  if [ -x "$MEOW_RAIZ/scripts/leitura_build.sh" ]; then
    "$MEOW_RAIZ/scripts/leitura_build.sh" --reverter || true
  fi

  # Os dois arquivos dele (`~/.local/share/applications/com.meowsystem.Painel
  # .desktop` e `~/.local/bin/meow-painel`) passam por `meow_escrever` e ESTÃO
  # no manifesto, então o passo 4 os apagaria.
  #
  # Rodar os dois (aqui e no passo 4) é inofensivo e de propósito: o
  # `--reverter` sai por `meow_pula` quando não há o que tirar, e o passo 4 pula
  # arquivo que não existe.
  if [ -x "$MEOW_RAIZ/scripts/atalho.sh" ]; then
    "$MEOW_RAIZ/scripts/atalho.sh" --reverter || true
  fi

  # Mesmo desenho dos três acima, e o mesmo motivo: o manifesto apaga
  # ARQUIVOS, e esta é uma LINHA dentro de um arquivo que nem nosso é.
  if [ -x "$MEOW_RAIZ/scripts/fastfetch_logo.sh" ]; then
    "$MEOW_RAIZ/scripts/fastfetch_logo.sh" reverter || true
  fi

  # O override do Flatpak do usuário é arquivo do flatpak, e o manifesto não o
  # alcança: o reverter devolve só as chaves que o MeowSystem mexeu.
  if [ -x "$MEOW_RAIZ/scripts/flatpak_tema.sh" ]; then
    "$MEOW_RAIZ/scripts/flatpak_tema.sh" reverter || true
  fi

  meow_passo "3/6 Tema do COSMIC"
  # O alvo é o PRIMEIRO backup de tema — o COSMIC de antes do MeowSystem NESTA
  # máquina. A captura `assets/temas/capturados/original` NÃO serve para isto: ela foi tirada
  # de um home específico e está no git.
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
    # O clone tem de sair da conta ANTES do laço.
    #
    # A comparação é entre caminhos CANÔNICOS, e isso não é preciosismo: aqui
    # `~/Desenvolvimento` é um symlink para `/mnt/Apate/Desenvolvimento`, então
    # o mesmo arquivo do clone tem dois nomes e só um deles começa com o
    # `$MEOW_RAIZ`.
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
      # Nada de fora do home: manifesto de um HOME de teste (ou de outra máquina,
      # se alguém copiar o estado) aponta para caminho que não é nosso para apagar.
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
  # `…/meowsystem/midia` e `…/meowsystem/leitura` entram aqui como CINTO dos
  # dois `--reverter` do passo 2 (`midia.sh` e `leitura_build.sh`), que já
  # apagam a própria árvore.
  #
  # O passo 4 (manifesto) não alcança nenhuma das duas: o binário é gravado com
  # `install -D` e a árvore de build nem passa por `meow_escrever`.
  for dir in "$HOME/.local/share/icons/${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
             "$HOME/.local/share/fonts/MeowSystem" \
             "$HOME/.local/state/meowsystem/midia" \
             "$HOME/.local/state/meowsystem/leitura"; do
    [ -d "$dir" ] || continue
    if meow_seco; then meow_muda "removeria $dir/"; continue; fi
    # As árvores de build se refazem sozinhas; as outras voltam com o Restaurar.
    case "$dir" in */meowsystem/midia|*/meowsystem/leitura) ;; *) meow_guardar_pasta "$dir" ;; esac
    rm -rf "$dir"; meow_ok "removido $dir/"
  done

  # A MARCA DE DONO É A MESMA DO CONSTRUTOR: só sai o diretório com o
  # `.meow-origem` que o `construir_icones.sh` grava.
  meow_desinstalar_bases_de_icones

  # --- O ACERVO DE PAPEL DE PAREDE NÃO ENTRA NO LAÇO ACIMA -------
  #
  # Ele estava lá, e era um `rm -rf` de 320 MB de curadoria dela.
  #
  # As três árvores acima são REPRODUZÍVEIS POR CÓDIGO: os ícones saem do
  # `construir_icones.sh`, as fontes do `instalar_fontes.sh`, o binário do
  # applet do `midia_build.sh`.
  #
  # "MAS É REPRODUZÍVEL PELA RECEITA" — e é justamente por isso que a diferença
  # importa.
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
      meow_info "  para apagar mesmo assim:  MEOW_APAGAR_ACERVO=1 ./install.sh --uninstall"
    fi
  fi

  # --- A CURADORIA GANHOU UM SEGUNDO ENDEREÇO ------------------
  # `BANIDOS.txt` e `lado.tsv` eram versionados dentro do clone, e o painel os
  # reescrevia enquanto ela usava a interface — usar o programa virava commit
  # pendente, e conflito de merge entre as duas máquinas a cada `git pull`.
  #
  # O acervo é 320 MB de imagem e se vê; estas duas listas são 300 linhas e
  # somem sem ninguém notar.
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

  # As pastas DERIVADAS da noite/dia saem sempre: são link duro montado pelo
  # `wallpaper.sh` a partir de `ativos/`, não têm imagem própria e o
  # `--aplicar` as remonta em um segundo.
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
    # Quem apontou o MEOW_COMPLETIONS_DIR para um diretório do root continua
    # ouvindo o comando em vez de ver uma falha calada.
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
  # --- OS.ron GERADOS SAEM, PORQUE SÃO PRODUTO E NÃO ESCOLHA ---
  #
  # Deixar o produto lá dentro obriga a pessoa a saber qual é qual antes de
  # apagar qualquer coisa, e o passo 5 acabou de lhe dizer que apagar à mão ali
  # tem preço.
  local temas_gerados="$MEOW_ESTADO/temas"
  if [ -d "$temas_gerados" ]; then
    if meow_seco; then
      meow_muda "removeria $temas_gerados/ (.ron gerados, regeráveis pela paleta)"
    else
      meow_guardar_pasta "$temas_gerados"; rm -rf "$temas_gerados"; meow_ok "removido $temas_gerados/ (.ron gerados)"
    fi
  fi

  # Desde que a curadoria de papel de parede saiu do clone, `$MEOW_ESTADO` não
  # guarda só backup e log: guarda `papeis-de-parede/BANIDOS.txt` e
  # `papeis-de-parede/lado.tsv`, que são escolha dela.
  meow_info "o estado e os backups ficam em $MEOW_ESTADO — apague à mão se quiser"
  if [ -d "$MEOW_ESTADO/papeis-de-parede" ]; then
    meow_info "  menos $MEOW_ESTADO/papeis-de-parede/ — é a sua curadoria de papel de parede"
  fi
  meow_info "os .desktop do sistema que o lançador escondia voltam com o «Voltar ao tema de antes»"
  return 0
}

# AS BASES DE ÍCONE DO PACK — a `-Base` e as camadas de trás, `-Base-<n>`. A
# marca de dono é a mesma do construtor (`.meow-origem`): o que não tem a marca
# não foi o MeowSystem que pôs, e fica.
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

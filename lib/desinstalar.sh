#!/usr/bin/env bash
# desinstalar.sh — tira o MeowSystem da máquina. Lê o manifesto; não adivinha.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Quem chama é `./install.sh --uninstall`.
#
# POR QUE UM MANIFESTO, E NÃO UMA LISTA ESCRITA À MÃO
#   Uma segunda lista envelheceria em silêncio: cada etapa nova escreveria num
#   lugar que o desinstalador não conhece, e ninguém descobriria isso até alguém
#   tentar desinstalar. Quem preenche o manifesto é a `meow_escrever`, que é o
#   único ponto por onde as escritas de configuração passam.
#
# A ORDEM É A PARTE QUE IMPORTA
#   Os relógios saem PRIMEIRO. O `meow-doctor.timer` dispara às 5h e reaplica
#   tudo — desinstalar com ele ligado é desinstalar até a próxima madrugada.
#
#   Os temas por APLICATIVO saem em segundo, antes do manifesto, e a ordem aqui
#   também é obrigatória: o `reverter` de cada módulo LÊ arquivos que o passo do
#   manifesto apaga (o `.qbtheme` que ele confere, o `settings.json` do VS Code,
#   o `.desktop` guardado do ZapZap). Invertido, o desinstalador arrancaria as
#   ferramentas antes de usá-las e os apps ficariam tematizados para sempre.
#
# O QUE MUDOU EM 11/08/2026
#   Até esta data o `--uninstall` ignorava `assets/temas-de-apps/` inteiro. O manifesto dá
#   conta do que passa pela `meow_escrever`, mas os módulos de aplicativo mexem
#   por fora dela por necessidade: o spicetify reescreve o Spotify, o ZapZap tem
#   o `.desktop` do export trocado, os toolkits religam symlink. Nada disso está
#   no manifesto — e nada disso saía. Ela pediu o pareamento; este passo é ele.
#
# O QUE MUDOU EM 31/08/2026 — O MODO DE LEITURA INTEIRO PASSAVA BATIDO
#   Ele nasceu em 29 e 30/08 e ninguém voltou aqui. Eram dois buracos separados,
#   os dois medidos hoje na máquina dela:
#
#   (a) A ÁRVORE DE BUILD, 1,5 GB, ficava. O binário e a sombra saíam pelo
#       manifesto; a árvore de cargo em `~/.local/state/meowsystem/leitura` não
#       passa por `meow_escrever` e não estava em lugar nenhum. Faltavam as duas
#       metades do desenho que o applet de mídia já tinha: a chamada ao script
#       dono no passo 2 e o cinto no passo 5.
#
#   (b) O `disable --now` do passo 1 não conhecia cinco unidades — as do modo de
#       leitura e as do painel —, e três delas deixavam link vivo em
#       `cosmic-session.target.wants`. O `find` que apaga os arquivos é
#       `-maxdepth 1` e nunca desce até os `.wants`: sem `disable`, o link fica
#       ÓRFÃO. É exatamente o resíduo de 25/08 que o `meow_unidade_sobrou` existe
#       para enxergar, refeito aqui pelo próprio desinstalador.
#
# O QUE ELE NUNCA REMOVE
#   Pacote do apt (foram instalados a pedido, mas podem ser de outra coisa
#   agora), o clone do repositório, e os backups — que são a única prova do que
#   havia antes. Nem arquivo que a pessoa editou depois: o sha256 do manifesto é
#   o que separa "isto é nosso" de "isto virou dela".
meow_desinstalar() {
  meow_titulo "MeowSystem — desinstalar"
  meow_info "isto NÃO desinstala pacotes do apt nem apaga o clone do repositório"
  meow_seco && meow_aviso "modo seco: nada será removido"

  meow_passo "1/6 Relógios e gatilhos"
  # A LISTA DO `disable` É EXPLÍCITA, E POR ISSO ELA ENVELHECE — ENVELHECEU DUAS VEZES
  #   O `find … -delete` abaixo é `-maxdepth 1`: ele apaga os ARQUIVOS de
  #   `~/.config/systemd/user`, e não toca nos symlinks que moram um nível
  #   abaixo, em `*.target.wants/`. Quem tira esses links é o `disable` — e o que
  #   não estiver nesta lista fica para trás como link ÓRFÃO apontando para um
  #   arquivo que acabou de ser apagado. É o achado de 25/08/2026 que fez nascer
  #   o `meow_unidade_sobrou` (install.sh), e ele é invisível para toda pergunta
  #   óbvia: `is-enabled` diz `not-found`, `is-active` diz `inactive`,
  #   `systemctl --user --failed` vem vazio. Só o disco vê.
  #
  #   Faltavam CINCO nomes, conferidos em 31/08/2026 no disco dela — as três
  #   unidades com `[Install]` deixavam link vivo em `cosmic-session.target.wants`:
  #       cosmic-session.target.wants/meow-leitura.timer      -> ficava órfão
  #       cosmic-session.target.wants/meow-painel.service     -> ficava órfão
  #       cosmic-session.target.wants/meow-painel-raio.path   -> ficava órfão
  #   Os `.service` irmãos (`meow-leitura.service`, `meow-painel-raio.service`)
  #   são `static` e não criam link nenhum; entram na lista pelo `--now`, para
  #   serem PARADOS se estiverem correndo — que é o mesmo motivo pelo qual
  #   `meow-doctor.service` e `meow-wallpaper.service` já estavam aqui.
  #
  #   `meow-painel.service` é o que mais importa parar: ele é `Type=simple` com
  #   `Restart=on-failure`, um laço vivo repondo o `cosmic-panel`. Deixá-lo de pé
  #   depois de apagarem o `~/.local/bin/meow` que ele executa (passo 6) é o
  #   supervisor batendo num binário que não existe mais.
  if ! meow_seco; then
    # `|| true` porque desligar unidade que não existe devolve != 0, e isso não
    # é falha: é a máquina já estando como queremos deixá-la.
    systemctl --user disable --now \
      meow-doctor.timer meow-doctor.service \
      meow-logo.timer meow-logo.service \
      meow-wallpaper.timer meow-wallpaper.service meow-fundo.path \
      meow-assets.path meow-assets.service \
      meow-flatpak.path meow-flatpak.service \
      meow-steam.path meow-steam.service \
      meow-leitura.timer meow-leitura.service \
      meow-gato.timer meow-gato.service meow-ativos.path \
      meow-painel.service meow-painel-raio.path meow-painel-raio.service 2>/dev/null || true
    # A LISTA NOMEADA ACIMA NÃO É REDUNDANTE COM ESTE `find`, e quem acrescentar
    # unidade nova precisa saber: o `find` APAGA o arquivo, o `disable --now` é
    # que PARA a unidade viva e tira os links. Apagar o arquivo de uma unidade
    # ainda ativa deixa um processo rodando sem arquivo — e, no caso do
    # `meow-gato.service`, um SIGTERM no `cosmic-panel` disparado por uma unidade
    # que já não existe. Toda unidade nova entra nas DUAS.
    # (Conferido em 01/09/2026: as três da Sprint W estavam só no `find`.)
    find "$HOME/.config/systemd/user" -maxdepth 1 -name 'meow-*' \
      \( -name '*.service' -o -name '*.timer' -o -name '*.path' \) -delete 2>/dev/null || true
    # O CINTO DOS LINKS, e ele não é redundância da lista acima: é o caso em que
    # o `disable` NÃO TEM COMO funcionar. Uma desinstalação interrompida (ou uma
    # anterior a esta correção) deixa o arquivo da unidade já apagado e o link
    # ainda de pé — e `systemctl disable` de unidade sem arquivo não remove link
    # nenhum. Sem esta varredura, o resíduo de 25/08 sobreviveria a QUALQUER
    # número de `--uninstall`, que é o oposto de idempotente. Mesmo `rm -f` de
    # glob que o `etapa_painel` do install.sh já faz nome por nome; glob sem
    # match fica literal e `rm -f` de caminho inexistente sai 0, calado.
    rm -f "$HOME/.config/systemd/user"/*.wants/meow-* \
          "$HOME/.config/systemd/user"/*.requires/meow-* 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    meow_ok "unidades meow-* desligadas e removidas"
  else
    meow_muda "desligaria e removeria as unidades meow-* de ~/.config/systemd/user"
    meow_muda "  e os links em *.target.wants/ que sobrariam órfãos sem o disable"
  fi

  # O HOOK DE APT SAI AQUI, E NÃO NO PASSO 4
  #   O passo 4 anda pelo manifesto e recusa, de propósito, tudo que está fora do
  #   `$HOME` — a regra que impede um manifesto de outra máquina de mandar apagar
  #   caminho que não é nosso. O hook mora em `/etc/apt/apt.conf.d` e o wrapper em
  #   `/usr/local/sbin`: os dois cairiam nessa recusa e ficariam para trás.
  #
  #   Um hook órfão não é sujeira inofensiva. Ele chama o wrapper depois de TODO
  #   apt, e o wrapper chama o `ocultar_apps.sh` do clone — que este arquivo
  #   promete não apagar. Ou seja: desinstalar o MeowSystem e continuar vendo o
  #   lançador ser reescrito depois de cada `apt upgrade`, sem nada instalado que
  #   explicasse por quê.
  local hook=/etc/apt/apt.conf.d/99-meow-lancador
  local wrapper=/usr/local/sbin/meow-lancador-apt.sh
  if [ -f "$hook" ] || [ -f "$wrapper" ]; then
    if meow_seco; then
      meow_muda "removeria $hook e $wrapper"
    elif sudo rm -f "$hook" "$wrapper" 2>/dev/null; then
      meow_ok "hook de apt do lançador removido"
    else
      # Sem sudo não apagamos escondido nem falhamos calados — mesma conduta da
      # completion no passo 6.
      meow_aviso "sem sudo para remover o hook de apt do lançador"
      meow_info "  rode: sudo rm -f $hook $wrapper"
    fi
  fi

  # O ZAPZAP SAI AQUI, E NÃO NO PASSO 4 — E NÃO PELO MOTIVO DO HOOK
  #   O hook acima escapa do passo 4 por morar fora do `$HOME`. Este é o
  #   contrário: o `tray_icon.py` que vestimos mora DENTRO do `$HOME`
  #   (`~/.local/share/flatpak/app/com.rtosta.zapzap/…`) e por isso o passo 4 o
  #   alcançaria — se ele estivesse no manifesto. Ele NÃO ESTÁ, de propósito, e o
  #   `scripts/icones_tray_zapzap.sh` explica por quê no lugar onde a chamada
  #   seria feita: o passo 4 APAGA o que encontra, e um `tray_icon.py` apagado é
  #   o ZapZap que não abre mais. Arquivo de terceiro não pode sumir; só pode
  #   VOLTAR AO DE FÁBRICA.
  #
  #   Deixar para trás é que não dá. O ícone da bandeja continuaria com o desenho
  #   do Arcticons depois de o MeowSystem ter sido desinstalado, sem nada na
  #   máquina que explicasse por quê — a mesma falta que o hook órfão do lançador
  #   causava, e que o parágrafo acima corrige.
  if [ -x "$MEOW_RAIZ/scripts/icones_tray_zapzap.sh" ]; then
    "$MEOW_RAIZ/scripts/icones_tray_zapzap.sh" --desfazer || true
  fi

  meow_passo "2/6 Temas por aplicativo"
  # A LISTA VEM DA CONF DELA, e um APPS_ATIVOS vazio significa "ela nunca ligou
  # nenhum" — não há o que desfazer, e chamar o runner com lista vazia só
  # imprimiria um resumo em branco.
  #
  # O RESULTADO NÃO DERRUBA A DESINSTALAÇÃO, e isso é deliberado: um módulo que
  # recusa (Obsidian aberto, spicetify com backup de outra versão) devolve 3, e
  # transformar isso em falha fatal deixaria a pessoa presa com metade do
  # MeowSystem instalado. O runner já diz na tela quem ficou pendente; quem lê
  # decide se fecha o app e roda de novo, ou se segue.
  if [ -n "${APPS_ATIVOS:-}" ]; then
    APPS_ATIVOS="$APPS_ATIVOS" FLAVOR="${FLAVOR:-}" ACCENT="${ACCENT:-}" \
      "$MEOW_RAIZ/scripts/aplicar_apps.sh" reverter || true
  else
    meow_pula "APPS_ATIVOS vazio no meow.conf — nenhum tema de aplicativo para desfazer"
  fi

  # O APPLET DE MÍDIA SAI AQUI, E A ORDEM É METADE DO VALOR DO PASSO.
  # O `--reverter` remove a SOMBRA primeiro (`~/.local/share/applications/…
  # NowPlaying.desktop`) e só depois o binário. O contrário abriria a janela em
  # que a sombra fica sem `Exec=` válido — e aí a dock não volta ao applet de
  # fábrica, ela fica com um BURACO: o cosmic-panel casa o applet pelo basename
  # do .desktop e CONSOME o slot no primeiro acerto, sem nunca tentar o export
  # do flatpak. Por isso a remoção tem um dono só, e é o `midia.sh`.
  if [ -x "$MEOW_RAIZ/scripts/midia.sh" ]; then
    "$MEOW_RAIZ/scripts/midia.sh" --reverter || true
  fi

  # O APPLET DO MODO DE LEITURA SAI AQUI, PELO MESMO MOTIVO E NA MESMA ORDEM
  #   `leitura_build.sh --reverter` remove a SOMBRA, depois o binário, depois a
  #   árvore de build — e a ordem mora lá dentro pelo motivo do parágrafo acima:
  #   o `cosmic-panel` casa o applet pelo basename do `.desktop` e consome o slot
  #   no primeiro acerto, então sombra sem binário deixa BURACO na barra, não o
  #   applet de fábrica. Quem remove é o script dono, não este arquivo.
  #
  #   O `--reverter` é a PRIMEIRA coisa que o `main` daquele script olha, antes
  #   da chave `LEITURA_APPLET`: desinstalar com ela em "nao" reverte do mesmo
  #   jeito, e uma sombra que uma execução antiga deixou também sai.
  #
  #   O QUE FALTAVA SEM ESTA CHAMADA, medido em 31/08/2026: o binário e a sombra
  #   saíam pelo passo 4 (o `leitura_build.sh` os registra — a sombra via
  #   `meow_escrever`, o binário via `meow_manifesto_registrar`, porque o
  #   `install -D` não passa pelo escritor), e a ÁRVORE DE BUILD ficava inteira:
  #   1,5 GB em ~/.local/state/meowsystem/leitura (1.515.036.230 bytes).
  #
  #   As cinco chaves do CosmicComp NÃO são zeradas por ele, e isso é desenho:
  #   são o estado do modo de leitura dela, não arquivo nosso. Quem quiser zerar
  #   pede: `meow leitura remover`.
  if [ -x "$MEOW_RAIZ/scripts/leitura_build.sh" ]; then
    "$MEOW_RAIZ/scripts/leitura_build.sh" --reverter || true
  fi

  # O ATALHO DO PAINEL SAI AQUI, E NÃO PELO MANIFESTO — 01/09/2026
  #   Os dois arquivos dele (`~/.local/share/applications/com.meowsystem.Painel
  #   .desktop` e `~/.local/bin/meow-painel`) passam por `meow_escrever` e ESTÃO
  #   no manifesto, então o passo 4 os apagaria. O que o passo 4 não faz é
  #   chacoalhar o `cosmic-app-library` depois — e aí o ícone continuaria na
  #   grade de aplicativos dela, clicável, apontando para um arquivo que não
  #   existe mais. É o mesmo buraco do applet: o menu resolve os `.desktop` no
  #   arranque e GUARDA (`meow_lancador_reler`, em lib/comum.sh). Quem remove com
  #   o reler junto é o script dono.
  #
  #   Rodar os dois (aqui e no passo 4) é inofensivo e de propósito: o `--reverter`
  #   sai por `meow_pula` quando não há o que tirar, e o passo 4 pula arquivo que
  #   não existe. É o mesmo cinto que o `midia.sh` e o `leitura_build.sh` já têm.
  if [ -x "$MEOW_RAIZ/scripts/atalho.sh" ]; then
    "$MEOW_RAIZ/scripts/atalho.sh" --reverter || true
  fi

  # A LINHA DO FASTFETCH NO env.zsh SAI AQUI — 06/09/2026
  #   Mesmo desenho dos três acima, e o mesmo motivo: o manifesto apaga
  #   ARQUIVOS, e esta é uma LINHA dentro de um arquivo que nem nosso é. O
  #   `gato.ansi` e o `~/.local/bin/meow-fetch` estão no manifesto e saem no
  #   passo 4; a chamada `meow-fetch --pipe false` no `~/.config/zsh/env.zsh`
  #   ficaria — e cada terminal que ela abrisse depois de desinstalar abriria
  #   com `command not found`. O `reverter` devolve `fastfetch --pipe false`,
  #   com backup antes e em voz alta depois, e sai por `meow_pula` quando a
  #   linha de lá não é nossa.
  if [ -x "$MEOW_RAIZ/scripts/fastfetch_logo.sh" ]; then
    "$MEOW_RAIZ/scripts/fastfetch_logo.sh" reverter || true
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
    if meow_seco; then
      meow_muda "copiaria $primeiro/com.system76.CosmicTheme.* para ~/.config/cosmic/"
    else
      cp -a "$primeiro"/com.system76.CosmicTheme.* "$HOME/.config/cosmic/" 2>/dev/null || true
      meow_ok "tema devolvido"
    fi
  else
    meow_aviso "não há backup pré-instalação em $MEOW_ESTADO/backups/*-tema-PRIMEIRO-*"
    meow_info "  o tema do COSMIC fica como está — ajuste em Configurações > Aparência"
    meow_info "  (a captura assets/temas/capturados/original NÃO serve: é o tema de outra máquina)"
  fi

  meow_passo "4/6 Arquivos que este projeto escreveu"
  if [ -f "$MEOW_MANIFESTO" ]; then
    # O clone tem de sair da conta ANTES do laço. A `meow_escrever` é usada
    # também para gerar arquivo DENTRO do repositório (`assets/icones/curadoria.map`, por
    # exemplo), e essas linhas entram no manifesto como todas as outras — mas
    # aquilo é versionado, quem responde por elas é o git, e o cabeçalho deste
    # arquivo promete não tocar no clone. Sem o `-n`, um `MEOW_RAIZ` vazio viraria
    # o padrão `/*`, que casa com tudo: a guarda seria o oposto dela mesma.
    #
    # A comparação é entre caminhos CANÔNICOS, e isso não é preciosismo: aqui
    # `~/Desenvolvimento` é um symlink para `/mnt/Apate/Desenvolvimento`, então o
    # mesmo arquivo do clone tem dois nomes e só um deles começa com o
    # `$MEOW_RAIZ`. É o mesmo `readlink -m` que a TRAVA 1 usa, pelo mesmo motivo.
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
      if meow_seco; then meow_muda "removeria $alvo"; else rm -f "$alvo"; fi
      n=$((n+1))
    done < "$MEOW_MANIFESTO"
    meow_seco || meow_ok "$n arquivo(s) removidos pelo manifesto"
  else
    meow_pula "sem manifesto em $MEOW_MANIFESTO — nada a remover por lista"
    meow_info "  o manifesto só existe a partir da primeira instalação que o gravou"
  fi

  meow_passo "5/6 Árvores inteiras"
  local dir
  # `…/meowsystem/midia` e `…/meowsystem/leitura` entram aqui como CINTO dos dois
  # `--reverter` do passo 2 (`midia.sh` e `leitura_build.sh`), que já apagam a
  # própria árvore. O cinto vale porque o passo 2 pode não acontecer: script sem
  # bit de execução, clone incompleto, repositório trocado de lugar — e aí é este
  # laço, que não depende de nada, que fica sendo a única passagem por elas.
  #
  # O passo 4 (manifesto) não alcança nenhuma das duas: o binário é gravado com
  # `install -D` e a árvore de build nem passa por `meow_escrever`. E o passo 4
  # PULA, de propósito, arquivo cujo sha256 mudou depois da escrita — o que é
  # certo para configuração dela e insuficiente para uma árvore de cargo.
  #
  # O TAMANHO ESTAVA DESATUALIZADO E FALAVA DE UMA ÁRVORE SÓ. Medido hoje,
  # 31/08/2026, com `du -sb`:
  #     ~/.local/state/meowsystem/midia    1.956.048.518 B  (1,9 GB)
  #     ~/.local/state/meowsystem/leitura  1.515.036.230 B  (1,5 GB)
  # São 3,4 GB. A linha antiga dizia "1,5 GB", que hoje é o tamanho da árvore que
  # este laço nem listava.
  for dir in "$HOME/.local/share/icons/${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
             "$HOME/.local/share/fonts/MeowSystem" \
             "$HOME/.local/state/meowsystem/midia" \
             "$HOME/.local/state/meowsystem/leitura"; do
    [ -d "$dir" ] || continue
    if meow_seco; then meow_muda "removeria $dir/"; else rm -rf "$dir"; meow_ok "removido $dir/"; fi
  done

  # --- O ACERVO DE PAPEL DE PAREDE NÃO ENTRA NO LAÇO ACIMA (25/08/2026) -------
  #
  # Ele estava lá, e era um `rm -rf` de 320 MB de curadoria dela.
  #
  # As três árvores acima são REPRODUZÍVEIS POR CÓDIGO: os ícones saem do
  # `construir_icones.sh`, as fontes do `instalar_fontes.sh`, o binário do applet
  # do `midia_build.sh`. Nenhuma delas contém uma escolha; apagar é grátis e
  # reinstalar é uma passagem do `install.sh`, sem rede e sem depender de
  # ninguém.
  #
  # `~/.local/share/backgrounds/meowsystem` é outra coisa: dentro dele estão
  # `ativos/` (54 imagens), `banidos/` (247), `favoritos/` e `originais/` — e a
  # curadoria de 24/08/2026, que foi ela quem fez, imagem por imagem.
  #
  # "MAS É REPRODUZÍVEL PELA RECEITA" — e é justamente por isso que a diferença
  # importa. O `assets/papeis-de-parede/FONTES.tsv` e o `assets/papeis-de-parede/BANIDOS.txt` estão no git
  # e reconstroem a escolha dela, sim; mas o `semear` reconstrói **baixando da
  # internet**, uma URL por imagem. Isso depende de rede e de as URLs
  # continuarem vivas — e link rot não avisa. Uma receita que precisa da
  # internet não é a mesma coisa que um script que só precisa do disco.
  #
  # A primeira regra deste projeto é **não destruir dado dela**
  # (`docs/SPRINTS.md`, "Como este projeto trabalha"). Desinstalar um tema não é
  # motivo para apagar uma coleção de imagens, e um `--uninstall` que faz isso
  # calado é exatamente o tipo de estrago que só se descobre depois.
  #
  # Então o padrão é PRESERVAR e DIZER. Quem quiser mesmo apagar pede com todas
  # as letras: `MEOW_APAGAR_ACERVO=1 ./install.sh --uninstall`.
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

  # As pastas DERIVADAS da noite/dia saem sempre: são link duro montado pelo
  # `wallpaper.sh` a partir de `ativos/`, não têm imagem própria e o
  # `--aplicar` as remonta em um segundo. Deixá-las para trás é que seria
  # sujeira — pasta órfã apontando para um acervo que ninguém mais gira.
  local derivada
  for derivada in "$acervo/ativos-noite" "$acervo/ativos-dia"; do
    [ -d "$derivada" ] || continue
    if meow_seco; then meow_muda "removeria $derivada/ (derivada, link duro)"
    else rm -rf "$derivada"; meow_ok "removido $derivada/ (derivada, link duro)"; fi
  done
  if ! meow_seco; then
    meow_tem gtk-update-icon-cache && gtk-update-icon-cache -f "$HOME/.local/share/icons" 2>/dev/null
    meow_tem fc-cache && fc-cache -f "$HOME/.local/share/fonts" 2>/dev/null
  fi

  meow_passo "6/6 CLI e estado"
  if meow_seco; then
    meow_muda "removeria ~/.local/bin/meow e a completion do zsh"
  else
    rm -f "$HOME/.local/bin/meow"
    # A completion mora em /usr/local/share/zsh/site-functions desde 08/2026 (o
    # porquê está no install.sh): lá quem manda é o root, e quem instala é o
    # Ritual da Aurora. Sem permissão nós não apagamos escondido nem falhamos
    # calados — dizemos o comando e seguimos.
    COMP_MEOW="${MEOW_COMPLETIONS_DIR:-/usr/local/share/zsh/site-functions}/_meow"
    if [ -e "$COMP_MEOW" ]; then
      if [ -w "$(dirname "$COMP_MEOW")" ]; then
        rm -f "$COMP_MEOW"
      else
        meow_info "a completion é do root: sudo rm -f $COMP_MEOW"
      fi
    fi
    unset COMP_MEOW
    rm -f "$MEOW_ESTADO/raiz"
    meow_ok "CLI removida"
  fi
  meow_info "o estado e os backups ficam em $MEOW_ESTADO — apague à mão se quiser"
  meow_info "se LANCADOR_SISTEMA era \"sim\": rode antes  meow desfazer --lancador"
  return 0
}

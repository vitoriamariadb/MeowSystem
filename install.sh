#!/usr/bin/env bash
# install.sh — instala o MeowSystem inteiro. Sem flag nenhuma.
#
#   ./install.sh              faz tudo
#   MEOW_DRY_RUN=1 ./install.sh   mostra o que faria, sem escrever nada
#
# POR QUE NÃO TEM FLAG
#   A §5.1 do RELATORIO propunha 14 flags (--tema, --icones, --logo, --all...).
#   Está declarada histórica: quem decide o que instalar é o `meow.conf`, não a
#   linha de comando. Uma flag a menos é uma decisão a menos na hora de usar.
#   O `--dry-run` sobrevive como MEOW_DRY_RUN=1 — invisível no uso normal,
#   disponível para auditar antes de deixar rodar.
#
# FALHA POR UNIDADE, NUNCA GLOBAL (regra 8 do contrato)
#   Cada etapa é uma função que RETORNA código; nenhuma chama `exit`. Um app
#   ausente vira "pulado" e o resto continua. É por isso que este script NÃO usa
#   `set -e`: com ele, uma etapa que devolvesse != 0 abortaria tudo e deixaria a
#   máquina em estado parcial — que é pior do que não ter começado.
#
# O QUE ELE NUNCA FAZ
#   - `apt upgrade` / `dist-upgrade`, nem tocar em pacote `cosmic-*`. O
#     /usr/bin/cosmic-comp desta máquina está patchado DUAS vezes (workspace
#     vazio e night light) e uma versão nova mata os dois de uma vez, derrubando
#     os workspaces alfinetados Meow e OS.
#   - escrever em /usr/share, no repo Andromeda ou nos atalhos de teclado.
#     A trava está em lib/comum.sh e recusa por caminho, não por boa intenção.
#   - sudo perto de ~/.config: um arquivo de dono root ali faz a GUI de tema
#     falhar EM SILÊNCIO, e o sintoma só aparece dias depois.

MEOW_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

CONF_PADRAO="$MEOW_RAIZ/meow.conf.exemplo"
CONF="${MEOW_CONF:-$HOME/.config/meow/meow.conf}"

declare -a FEITOS=() PULADOS=() FALHOS=()
PASSO=0
TOTAL=8

passo() { PASSO=$((PASSO+1)); meow_passo "[$PASSO/$TOTAL] $*"; }

# Registra o resultado de uma etapa sem deixar o código dela derrubar o script.
concluir() {
  local nome="$1" rc="$2"
  case "$rc" in
    0) FEITOS+=("$nome") ;;
    1) FEITOS+=("$nome") ;;                       # divergia e foi consertado
    3) PULADOS+=("$nome") ;;
    *) FALHOS+=("$nome") ;;
  esac
}

# ---------------------------------------------------------------------------
etapa_conf() {
  passo "Configuração"
  local fonte="$CONF"
  if [ -f "$CONF" ]; then
    meow_ok "meow.conf já existe em $CONF"
  else
    local conteudo; conteudo="$(cat "$CONF_PADRAO")"
    meow_escrever "$CONF" "$conteudo" 644
    case $? in
      0) meow_ok "meow.conf criado em $CONF" ;;
      1) if meow_seco; then
           # No seco o arquivo NÃO foi criado — ler dele daria "arquivo
           # inexistente" e, pior, deixaria FLAVOR/ACCENT sem valor para as
           # etapas seguintes, que morreriam com "variável não associada".
           # O exemplo é a mesma coisa que seria escrita, então serve de fonte.
           meow_info "no seco, lendo os valores de meow.conf.exemplo"
           fonte="$CONF_PADRAO"
         else
           meow_ok "meow.conf criado em $CONF"
         fi ;;
      *) meow_erro "não consegui criar $CONF"; return "$MEOW_ERRO" ;;
    esac
  fi
  # shellcheck disable=SC1090
  . "$fonte" || { meow_erro "$fonte tem erro de sintaxe"; return "$MEOW_ERRO"; }
  for v in FLAVOR ACCENT MODO LOGO; do
    if [ -z "${!v:-}" ]; then
      meow_erro "$v não está definida em $fonte"
      return "$MEOW_ERRO"
    fi
  done
  meow_info "flavor=$FLAVOR accent=$ACCENT modo=$MODO logo=$LOGO"
  return 0
}

# ---------------------------------------------------------------------------
# A CLI E AS COMPLETIONS
#
# POR QUE ESTA ETAPA VEM LOGO DEPOIS DA CONFIGURAÇÃO
#   Se o apt falhar, se faltar o Papirus, se a captura do tema ainda não
#   existir — ela continua ficando com o `meow` na mão para descobrir o que
#   houve. Instalar a ferramenta de diagnóstico DEPOIS das etapas que podem
#   falhar é deixar quem mais precisa dela sem ela.
#
# O PONTEIRO DA RAIZ NÃO É ENFEITE
#   O `meow` instalado vive em `~/.local/bin/meow`, fora do repo, e não tem como
#   deduzir onde está o clone a partir do próprio caminho. O ponteiro em
#   `~/.local/state/meowsystem/raiz` é o que responde isso — para a CLI e para a
#   completion do zsh, que lê o mesmo arquivo para listar as capturas de tema.
#   Sem ele, `meow` só funcionaria com `MEOW_RAIZ=` na frente.
#
# ─────────────────────────────────────────────────────────────────────────────
# A COMPLETION É A ÚNICA ESCRITA DESTE PROJETO DENTRO DO REPO ANDROMEDA
# ─────────────────────────────────────────────────────────────────────────────
#   A TRAVA 1 do `lib/comum.sh` recusa qualquer escrita em `~/.config/zsh`, e com
#   razão: é o repo dela, com auto-commit a cada 10 minutos, e tema não tem nada
#   que fazer lá. Só que o `$fpath` desta máquina foi lido, não adivinhado
#   (`~/.config/zsh/.zcompdump`, linha `#omz fpath:`), e os ÚNICOS diretórios de
#   completion graváveis pelo usuário estão todos dentro de `~/.config/zsh` —
#   o que o `env.zsh` acrescenta na linha 20 e os do oh-my-zsh. Os de fora
#   (`/usr/local/share/zsh/site-functions`) pedem root e são território do
#   Ritual da Aurora.
#
#   Ou seja: ou a completion mora lá, ou ela não existe. Então esta função NÃO
#   usa `meow_escrever` — a trava continua intacta para todo o resto do projeto,
#   e a exceção fica visível em UM lugar só, com o mesmo cuidado atômico.
#   A consequência é dita em voz alta na tela quando o arquivo é gravado: ele vai
#   virar um commit no repositório privado dela. Quem não quiser, roda com
#   MEOW_SEM_COMPLETIONS=1 e perde só o TAB.
#
#   O arquivo leva `# OVERRIDE` na segunda linha: é o contrato do próprio
#   Andromeda (completions/CONVENCAO.md) para completion escrita à mão, e o
#   gerador de lá preserva quem tem esse marcador nas 3 primeiras linhas.
COMPLETIONS_DIR="${MEOW_COMPLETIONS_DIR:-$HOME/.config/zsh/completions}"

# Escrita atômica igual à da meow_escrever, sem a trava de território: o
# temporário nasce DENTRO do diretório de destino, porque o repo mora em
# /mnt/Apate e o destino em /home, e `mv` entre sistemas de arquivos não é
# atômico.
instalar_completion() {
  local origem="$MEOW_RAIZ/zsh/_meow" destino="$COMPLETIONS_DIR/_meow" tmp

  if [ "${MEOW_SEM_COMPLETIONS:-0}" = "1" ]; then
    meow_pula "completions do zsh puladas (MEOW_SEM_COMPLETIONS=1)"
    return "$MEOW_OK"
  fi
  [ -f "$origem" ] || { meow_erro "falta $origem"; return "$MEOW_ERRO"; }
  if [ ! -d "$COMPLETIONS_DIR" ]; then
    meow_pula "não achei $COMPLETIONS_DIR — sem lugar no \$fpath para a completion"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ -f "$destino" ] && cmp -s "$origem" "$destino"; then
    meow_ok "completion do zsh já instalada em $destino"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "instalaria a completion em $destino"
    return "$MEOW_DIVERGENTE"
  fi

  tmp="$(mktemp -p "$COMPLETIONS_DIR" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  if ! cat "$origem" > "$tmp"; then rm -f "$tmp"; return "$MEOW_ERRO"; fi
  chmod 644 "$tmp"
  mv -f "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }

  meow_ok "completion do zsh instalada em $destino"
  # O aviso só sai quando o destino é MESMO o repo dela — com
  # MEOW_COMPLETIONS_DIR apontando para outro lugar (é assim que isto foi
  # testado) ele seria uma mentira.
  case "$(readlink -m -- "$destino")" in
    "$HOME/.config/zsh"/*)
      meow_aviso "esse arquivo está no repo Andromeda: o auto-commit dela vai versioná-lo" ;;
  esac
  meow_info "para não instalar: MEOW_SEM_COMPLETIONS=1 ./install.sh"
  meow_info "o TAB só passa a funcionar no próximo terminal (o compinit lê o fpath no início)"
  return "$MEOW_DIVERGENTE"
}

etapa_cli() {
  passo "CLI meow e completions"
  local mudou=0 rc

  # O `meow` é copiado, não linkado: um symlink para /mnt/Apate deixaria a CLI
  # inútil no dia em que o Ápate não montar — justamente o dia em que ela mais
  # precisaria de um `meow doctor` para entender o que houve. A cópia roda e diz
  # "não achei o repositório", que é uma resposta.
  meow_escrever "$HOME/.local/bin/meow" "$(cat "$MEOW_RAIZ/bin/meow")" 755
  rc=$?
  case "$rc" in
    0) meow_ok "~/.local/bin/meow já está atualizado" ;;
    1) mudou=1; meow_seco || meow_ok "~/.local/bin/meow instalado" ;;
    *) meow_erro "não consegui instalar ~/.local/bin/meow"; return "$MEOW_ERRO" ;;
  esac
  # A meow_escrever não corrige o modo de um arquivo cujo CONTEÚDO já confere —
  # ela sai antes de chegar no chmod. Um `meow` sem bit de execução seria um
  # "command not found" inexplicável, então o bit é reafirmado aqui.
  if ! meow_seco && [ -f "$HOME/.local/bin/meow" ] && [ ! -x "$HOME/.local/bin/meow" ]; then
    chmod 755 "$HOME/.local/bin/meow"
    mudou=1
  fi

  # O ponteiro da raiz, para a CLI e para a completion acharem o clone.
  meow_escrever "$MEOW_ESTADO/raiz" "$MEOW_RAIZ" 644
  rc=$?
  [ "$rc" -ge 2 ] && { meow_erro "não consegui gravar $MEOW_ESTADO/raiz"; return "$MEOW_ERRO"; }
  [ "$rc" = "1" ] && mudou=1

  # 3 AQUI É "NÃO HÁ ONDE PÔR", E ISSO NÃO É FALHA DESTA ETAPA
  #   A `instalar_completion` devolve 3 quando o diretório de completions não
  #   existe — numa máquina que não é esta, `~/.config/zsh/completions` pode
  #   simplesmente não estar lá. O `-ge 2` que estava aqui engolia esse 3 junto
  #   com o 2 e devolvia erro: MEDIDO num HOME de teste sem o diretório, o
  #   `install.sh` terminava com "falhou: cli" tendo instalado o `meow` inteiro
  #   e funcionando. O que se perde sem completion é o TAB, e o `meow_pula`
  #   acima já disse isso na tela. É o mesmo veredito que MEOW_SEM_COMPLETIONS=1
  #   já produzia — pular de um jeito não pode falhar e do outro não.
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

# ---------------------------------------------------------------------------
# O ÚNICO BLOCO COM sudo DO INSTALADOR INTEIRO.
#
# POR QUE ELE VEM CEDO, E NÃO NO FIM
#   A recomendação instintiva seria deixar o apt por último, longe das escritas
#   de configuração. Aqui é o contrário, por dois motivos concretos:
#   1. O `papirus-icon-theme` é PRÉ-REQUISITO da etapa de pastas. Instalado
#      depois, a etapa de pastas já teria se pulado e só funcionaria na
#      execução seguinte — "rodei e não ficou pronto" é um péssimo primeiro uso.
#   2. Todo `apt` desta máquina dispara o hook do Ritual da Aurora, que roda o
#      self-heal COMPLETO e reconcilia configuração. Rodando o apt ANTES, esse
#      self-heal acontece antes das nossas escritas. Rodando depois, ele poderia
#      reverter o que acabamos de aplicar.
#
# O QUE ELE NUNCA FAZ
#   `upgrade`, `dist-upgrade`, `full-upgrade`, nem tocar em pacote `cosmic-*`.
#   O `/usr/bin/cosmic-comp` desta máquina está patchado duas vezes (workspace
#   vazio e night light) e uma versão nova mata os dois de uma vez, derrubando
#   junto os workspaces alfinetados. `install <pacote>` explícito e mais nada.
#
# FALTA DE sudo NÃO É ERRO
#   Devolve 3 e diz o comando exato. O resto do tema continua sendo aplicado —
#   ficam de fora só as pastas coloridas e os temas de `bat`/`btop`.
etapa_pacotes() {
  passo "Pacotes do sistema"

  # binário que testa presença -> pacote que o instala
  local -A NECESSARIOS=(
    [rsvg-convert]=librsvg2-bin
    [convert]=imagemagick
    [gtk-update-icon-cache]=libgtk-3-bin
    [python3]=python3
    [git]=git
    [btop]=btop
    # No Debian/Ubuntu o `bat` instala como `batcat`: o nome `bat` já pertence ao
    # bacula-console-qt. Testar por `bat` faria o instalador reinstalar o pacote
    # a cada execução, para sempre, sem nunca ficar satisfeito.
    [batcat]=bat
  )
  # O Papirus não tem binário — testa-se pelo diretório do tema.
  local faltam=()
  local b
  for b in "${!NECESSARIOS[@]}"; do
    meow_tem "$b" || faltam+=("${NECESSARIOS[$b]}")
  done
  [ -d /usr/share/icons/Papirus-Dark ] || faltam+=(papirus-icon-theme)

  if [ ${#faltam[@]} -eq 0 ]; then
    meow_ok "todos os pacotes necessários já estão instalados"
    return 0
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

  # Dizer em voz alta o que vai rodar como root, ANTES de rodar. Um instalador
  # que pede senha sem explicar o que vai fazer com ela não merece a senha.
  meow_info "vou rodar como root, e só isto:"
  printf '      sudo apt-get install -y --no-install-recommends %s\n' "${faltam[*]}"

  if ! sudo apt-get install -y --no-install-recommends "${faltam[@]}" >/dev/null 2>&1; then
    meow_aviso "a instalação falhou (sem sudo? sem rede?) — seguindo sem esses pacotes"
    meow_info "  sudo apt-get install ${faltam[*]}"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  meow_ok "instalados: ${faltam[*]}"
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
etapa_gerar() {
  passo "Gerar temas e ícones a partir da paleta"
  local rc=0
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" --conferir >/dev/null 2>&1 || rc=1
  python3 "$MEOW_RAIZ/scripts/gerar_gato.py" --conferir >/dev/null 2>&1 || rc=1
  if [ "$rc" = "0" ]; then
    meow_ok "temas e gatos já correspondem à paleta"
    return 0
  fi
  if meow_seco; then
    meow_muda "regeraria temas e gatos"
    return "$MEOW_DIVERGENTE"
  fi
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" | sed 's/^/  /' || return "$MEOW_ERRO"
  python3 "$MEOW_RAIZ/scripts/gerar_gato.py" --accent "$ACCENT" | sed 's/^/  /' || return "$MEOW_ERRO"
  meow_ok "regenerados a partir de palette/"
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
# O tema é a única coisa deste instalador que já precisou de um humano — uma vez.
# O COSMIC não deriva o tema aplicado a partir do que a GUI edita: MEDIDO em
# 04/08/2026, escrever em Dark.Builder/v1/accent não moveu Dark/v1/accent nem em
# 4s nem depois; o cosmic-settings-daemon estava vivo e não derivou. Quem deriva
# é o app gráfico. Então a captura tem de nascer de um import manual.
# Depois disso a captura vai para o git e QUALQUER máquina a recebe por cópia,
# com zero clique — é uma vez na vida do projeto, não uma vez por máquina.
etapa_tema() {
  passo "Tema"
  local alvo="${FLAVOR}-${ACCENT}"
  local captura="$MEOW_RAIZ/state/tema/$alvo"

  if [ ! -d "$captura" ]; then
    meow_aviso "ainda não há captura para '$alvo'"
    meow_info "importe themes/meowsystem-$alvo.ron uma vez em"
    meow_info "  Configurações > Área de trabalho > Aparência > Importar"
    meow_info "e depois rode: ./scripts/capturar_tema.sh $alvo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if MEOW_DRY_RUN=0 "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$alvo" --conferir >/dev/null 2>&1; then
    meow_ok "tema '$alvo' já aplicado"
    return 0
  fi
  if meow_seco; then
    meow_muda "aplicaria o tema '$alvo'"
    return "$MEOW_DIVERGENTE"
  fi
  "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$alvo" | sed 's/^/  /' || return "$MEOW_ERRO"
  meow_notificar "MeowSystem" "Tema $alvo aplicado."
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
etapa_modo() {
  passo "Modo claro/escuro"
  local arq="$HOME/.config/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark"
  local desejado
  case "$MODO" in
    escuro) desejado=true ;;
    claro)  desejado=false ;;
    # Claro e escuro NÃO são dois temas: as capturas mocha-mauve e latte-mauve
    # diferem em exatamente UM arquivo, e é este `is_dark`. Então "auto" é só
    # escolher o valor pelo horário — sem reaplicar árvore e sem piscar a
    # interface. O que torna isso possível é cada captura já trazer as DUAS
    # árvores em Catppuccin; sem isso, virar o dia devolveria o tema claro de
    # fábrica.
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
    0) meow_ok "modo $MODO já ativo" ;;
    1) meow_ok "modo $MODO aplicado" ;;
    *) return "$MEOW_ERRO" ;;
  esac
  return 0
}

# ---------------------------------------------------------------------------
# Os dois gatos e o tema de ícones saem juntos: a logo do painel é caminho de
# arquivo e o botão do dock é tema de ícones, mas os dois vêm do mesmo SVG e
# reiniciam o mesmo processo. Separá-los custaria dois piscar de painel.
etapa_icones() {
  passo "Ícones e logo"
  FLAVOR="$FLAVOR" LOGO="$LOGO" ICONES_BASE="${ICONES_BASE:-Papirus-Dark}" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/construir_icones.sh"
  local rc=$?
  [ "$rc" = "1" ] && meow_notificar "MeowSystem" "Ícones e logo atualizados."
  return "$rc"
}

# As pastas coloridas vêm de terceiros (Papirus + catppuccin/papirus-folders) e
# pesam ~2 MB de SVG. Ficam numa etapa própria porque dependem de rede e do
# pacote do apt: sem qualquer um dos dois, o resto do tema continua de pé.
# A Nerd Font e o completar de icones vem depois do upstream: os dois dependem de
# rede e de terceiro pinado, e nenhum deles deixa outra etapa de pe ou não.
etapa_fontes() {
  passo "Fontes"
  "$MEOW_RAIZ/scripts/instalar_fontes.sh"
  return $?
}

# Os ícones que nenhum tema da cadeia cobre — incluindo os dois aplicativos dela,
# que não existem em tema nenhum do mundo e precisam de desenho autoral.
etapa_completar_icones() {
  passo "Ícones que faltavam"
  FLAVOR="$FLAVOR" ACCENT="$ACCENT" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/completar_icones.sh"
  return $?
}

etapa_upstream() {
  passo "Upstream de terceiros (commits pinados)"
  "$MEOW_RAIZ/scripts/baixar_upstream.sh"
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
  APPS_ATIVOS="${APPS_ATIVOS:-}" "$MEOW_RAIZ/scripts/aplicar_apps.sh" aplicar
  return $?
}

# ---------------------------------------------------------------------------
# O AUTO-REPARO — UM TIMER DIÁRIO, E NENHUM HOOK DE APT
#
#   O Ritual da Aurora já roda o self-heal completo depois de todo apt
#   (/etc/apt/apt.conf.d/99-ritual-aurora-self-heal). Pendurar um segundo reparador
#   no mesmo evento colocaria dois programas mexendo em tema e ícone ao mesmo tempo,
#   com dois avisos capazes de se contradizer na tela dela. Decisão tomada: timer
#   diário e mais nada. O porquê completo está no cabeçalho de
#   systemd/meow-doctor.timer.
#
# AS UNIDADES VÃO POR CÓPIA, SEM SUBSTITUIÇÃO NENHUMA
#   Elas usam o especificador `%h` do systemd em vez do caminho literal do `$HOME`.
#   Assim o arquivo instalado é byte a byte igual ao do repositório, e o
#   `meow_escrever` consegue comparar por conteúdo — que é o que impede este passo
#   de reescrever e recarregar o systemd em toda execução.
#
# NÃO É UM LINK SIMBÓLICO PARA /mnt/Apate DE PROPÓSITO
#   O disco Ápate é um NVMe separado. Uma unidade do systemd apontando para lá
#   desapareceria da sessão no dia em que ele não montasse, e o erro apareceria como
#   "unidade não encontrada", sem dizer por quê. Cópia resolve; a divergência com o
#   repositório é reconciliada aqui, a cada `install.sh`.
etapa_autoreparo() {
  passo "Auto-reparo diário (systemd --user)"
  local origem="$MEOW_RAIZ/systemd"
  local destino="$HOME/.config/systemd/user"
  local estado="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"

  # Desligar tem de DESLIGAR: só deixar de instalar manteria vivo o timer que uma
  # execução anterior já tinha ligado, e ela veria o reparo continuar acontecendo
  # depois de ter desligado a chave AUTO_REPARO no meow.conf.
  if [ "${AUTO_REPARO:-sim}" != "sim" ]; then
    if [ -f "$destino/meow-doctor.timer" ]; then
      if meow_seco; then
        meow_muda "removeria o timer (AUTO_REPARO=\"${AUTO_REPARO:-}\")"
        return "$MEOW_DIVERGENTE"
      fi
      systemctl --user disable --now meow-doctor.timer >/dev/null 2>&1
      rm -f "$destino/meow-doctor.timer" "$destino/meow-doctor.service"
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "AUTO_REPARO=\"$AUTO_REPARO\" — timer desligado e removido"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "AUTO_REPARO=\"${AUTO_REPARO:-}\" no meow.conf — sem reparo automático"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    meow_aviso "não há systemd --user nesta sessão — o auto-reparo fica de fora"
    meow_info "  rode 'meow doctor --consertar' na mão quando quiser"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # O diretório do log tem de existir ANTES de o systemd abrir o
  # `StandardOutput=append:` — MEDIDO em 2026-08-04: o append: é montado antes de
  # qualquer comando do serviço e antes até do `StateDirectory=`, e sem o diretório
  # a unidade morre com "Failed to set up standard output". Este mkdir é o que
  # garante o primeiro disparo numa máquina recém-instalada.
  if ! meow_seco && ! mkdir -p "$estado"; then
    meow_erro "não consegui criar $estado (é lá que fica o log do auto-reparo)"
    return "$MEOW_ERRO"
  fi

  local mudou=0 u
  for u in meow-doctor.service meow-doctor.timer; do
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
    [ "$mudou" = "1" ] && meow_muda "instalaria as unidades e ligaria meow-doctor.timer"
    [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
    meow_ok "auto-reparo já instalado"
    return 0
  fi

  [ "$mudou" = "1" ] && systemctl --user daemon-reload

  # Ligar só quando precisa. Um `enable --now` incondicional reescreveria o link em
  # timers.target.wants e reiniciaria o timer a cada execução — o que zera a conta
  # do `Persistent=` e faz o reparo disparar de novo sem motivo.
  if [ "$(systemctl --user is-enabled meow-doctor.timer 2>/dev/null)" != "enabled" ] ||
     [ "$(systemctl --user is-active  meow-doctor.timer 2>/dev/null)" != "active" ]; then
    if ! systemctl --user enable --now meow-doctor.timer >/dev/null 2>&1; then
      meow_erro "não consegui ligar o meow-doctor.timer"
      return "$MEOW_ERRO"
    fi
    mudou=1
  fi

  # Aviso honesto, não falha: as unidades ficam instaladas e o timer ligado, mas
  # cada disparo será PULADO pelo `ConditionFileIsExecutable=` até o `meow` existir.
  if [ ! -x "$HOME/.local/bin/meow" ]; then
    meow_aviso "o timer está ligado, mas ~/.local/bin/meow ainda não existe"
    meow_info "  até ele aparecer, cada disparo é pulado (o journal diz o caminho)"
  fi

  if [ "$mudou" = "0" ]; then
    meow_ok "auto-reparo já ligado (todo dia às 5h, com até 20min de folga)"
    return 0
  fi
  meow_ok "auto-reparo ligado: todo dia às 5h, log em $estado/doctor.log"
  return "$MEOW_DIVERGENTE"
}

etapa_wallpaper() {
  passo "Papéis de parede"
  WALLPAPER_INTERVALO="${WALLPAPER_INTERVALO:-5m}" \
    WALLPAPER_ORDEM="${WALLPAPER_ORDEM:-aleatoria}" \
    "$MEOW_RAIZ/scripts/wallpaper.sh" aplicar
  local rc=$?
  [ "$rc" = "1" ] && [ "${WALLPAPER_NOTIFICAR:-sim}" = "sim" ] \
    && meow_notificar "MeowSystem" "Carrossel de papéis de parede ligado."
  return "$rc"
}

# ---------------------------------------------------------------------------
main() {
  meow_titulo "MeowSystem — Catppuccin para o COSMIC"
  meow_seco && meow_aviso "MEOW_DRY_RUN=1 — nada será escrito"

  meow_travar || return 2

  # O auto-reparo é o ÚLTIMO de propósito: ele só faz sentido depois que tudo já foi
  # aplicado uma vez. Ligado antes, o primeiro disparo pegaria a máquina no meio da
  # instalação e "consertaria" o que ainda estava sendo escrito.
  # A CLI vem em segundo, logo depois da configuração: se qualquer etapa daqui
  # para baixo falhar, ela fica com o `meow doctor` na mão para descobrir por quê.
  local etapas=(etapa_conf etapa_cli etapa_pacotes etapa_gerar etapa_tema
                etapa_modo etapa_upstream etapa_fontes etapa_icones etapa_pastas
                etapa_completar_icones etapa_wallpaper
                etapa_apps etapa_autoreparo)
  TOTAL=${#etapas[@]}

  for e in "${etapas[@]}"; do
    "$e"; local rc=$?
    concluir "${e#etapa_}" "$rc"
    # A configuração é a única etapa que não é opcional: sem FLAVOR e ACCENT as
    # seguintes não têm o que aplicar. Parar aqui é honesto; seguir seria morrer
    # com "variável não associada" três etapas adiante, escondendo a causa.
    if [ "$e" = "etapa_conf" ] && [ "$rc" -ge 2 ]; then
      meow_erro "sem configuração válida não há o que instalar — parando"
      break
    fi
  done

  meow_passo "Resultado"
  [ ${#FEITOS[@]}  -gt 0 ] && meow_ok    "feito:  ${FEITOS[*]}"
  [ ${#PULADOS[@]} -gt 0 ] && meow_pula  "pulado: ${PULADOS[*]}"
  [ ${#FALHOS[@]}  -gt 0 ] && meow_erro  "falhou: ${FALHOS[*]}"

  meow_registrar "install.sh feitos=${#FEITOS[@]} pulados=${#PULADOS[@]} falhos=${#FALHOS[@]}"

  if [ ${#FALHOS[@]} -gt 0 ]; then
    printf '\n  %sAlgumas etapas falharam. Nada foi deixado pela metade —%s\n' "$C_AMARELO" "$C_ZERO"
    printf '  %scada etapa é independente, e o resto foi aplicado.%s\n\n' "$C_AMARELO" "$C_ZERO"
    return 2
  fi
  printf '\n  %sPronto.%s Rode de novo quando quiser: nada é escrito duas vezes.\n\n' "$C_VERDE$C_FORTE" "$C_ZERO"
  return 0
}

main "$@"

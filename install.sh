#!/usr/bin/env bash
# install.sh — instala o MeowSystem inteiro. Sem flag nenhuma.
#
#   ./install.sh              faz tudo
#   ./install.sh --dry-run    mostra o que faria, sem escrever nada
#   ./install.sh --wizard     pergunta o meow.conf antes, e então faz tudo
#   ./install.sh --uninstall  tira o MeowSystem desta máquina
#
# POR QUE QUASE NÃO TEM FLAG
#   A §5.1 do RELATORIO propunha 14 flags (--tema, --icones, --logo, --all...).
#   Está declarada histórica: quem decide o que instalar é o `meow.conf`, não a
#   linha de comando. Uma flag a menos é uma decisão a menos na hora de usar.
#
#   `--dry-run` e `--uninstall` são a terceira categoria que este texto não
#   previa: não ESCOLHEM etapa nenhuma, dizem COMO a execução se comporta. São
#   as duas primeiras coisas que alguém de fora digita, e recusá-las com "o
#   resto mora no meow.conf" era falso — o seco nunca morou lá.
#
#   `--wizard` é a única exceção, e ela NÃO abre um segundo lugar onde as
#   decisões moram: o wizard é `meow configurar`, que pergunta as chaves do
#   `meow.conf`, grava LÁ e sai. Depois dele o instalador roda como sempre, lendo
#   o mesmo arquivo de sempre. Uma flag que escolhesse o que instalar seria a
#   segunda fonte de verdade que este projeto recusa; uma flag que só EDITA a
#   primeira não é.
#
#   E ele nunca é o padrão: o `install.sh` roda em timer, por script e pelo
#   `meow aplicar`. Um prompt no caminho normal penduraria todos eles. Por isso
#   quem pergunta é a flag, e o wizard ainda confere `[ -t 0 ]` por dentro.
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
#   - escrever nos territórios de outro dono. A trava está em lib/comum.sh e
#     recusa por caminho, não por boa intenção: /usr é do gerenciador de
#     pacotes, e os vizinhos desta máquina (o repo Andromeda, os atalhos de
#     teclado) vêm de ~/.config/meow/vizinhos.conf.
#   - escrever em /usr/share SEM ser pedido. As três etapas do lançador
#     (ocultar/nomes/absolutos) marcam .desktop que vieram do apt, e só rodam
#     com LANCADOR_SISTEMA="sim". Elas guardam o original antes e `meow desfazer
#     --lancador` devolve. Passam POR FORA de meow_escrever de propósito: o
#     override em ~/.local/share/applications não funciona no COSMIC
#     (pop-os/cosmic-applets#667), medido aqui em 04/08/2026.
#   - sudo perto de ~/.config: um arquivo de dono root ali faz a GUI de tema
#     falhar EM SILÊNCIO, e o sintoma só aparece dias depois. Por isso o próprio
#     `main()` recusa rodar como root.

# `pwd -P`, e não `pwd`: esta máquina tem `~/Desenvolvimento/MeowSystem` como link
# simbólico para `/mnt/Apate/...`, e o `pwd` lógico devolve o caminho pelo qual o
# instalador FOI CHAMADO. Este valor não fica na memória: ele é gravado em
# `~/.local/state/meowsystem/raiz` (etapa da CLI) e é dali que o `bin/meow`, a
# completion do zsh e o `meow-assets.path` descobrem onde mora o clone. Rodar do
# link fazia o ponteiro trocar de nome e as conferências divergirem sem que nada
# no disco tivesse mudado — medido em 10/08/2026 na etapa do vigia do acervo.
MEOW_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"
# shellcheck source=lib/preflight.sh
. "$MEOW_RAIZ/lib/preflight.sh"

CONF_PADRAO="$MEOW_RAIZ/meow.conf.exemplo"
CONF="${MEOW_CONF:-$HOME/.config/meow/meow.conf}"

declare -a FEITOS=() CONFEREM=() PULADOS=() FALHOS=()

# PULAR POR FALTA DE ROOT E PULAR POR OPT-IN SÃO A MESMA COR NA TELA, E NÃO SÃO
# A MESMA COISA. O resumo terminava com "algumas dessas precisavam de root. Para
# completá-las: sudo -v && ./install.sh" sempre que `ocultar`, `nomes` ou
# `absolutos` aparecessem em `pulado:` — e nesta máquina as três se pulam por
# `LANCADOR_SISTEMA="nao"`, que é o PADRÃO e é escolha dela. Quem seguisse a dica
# digitaria a senha de root para ver exatamente o mesmo resumo. Cada etapa que se
# pula por opt-in se registra aqui, e o rodapé subtrai antes de falar em sudo.
declare -a PULADOS_OPTIN=()

# O motivo é um só, escrito num lugar só: as três etapas do `/usr/share` o dizem
# com a mesma frase, e todas caem em `MEOW_SEM_DEPENDENCIA`.
pular_por_optin() {
  PULADOS_OPTIN+=("$1")
  meow_pula 'LANCADOR_SISTEMA="nao" — os .desktop de /usr/share ficam intactos'
  return "$MEOW_SEM_DEPENDENCIA"
}
PASSO=0
TOTAL=8

passo() { PASSO=$((PASSO+1)); meow_passo "[$PASSO/$TOTAL] $*"; }

# Registra o resultado de uma etapa sem deixar o código dela derrubar o script.
#
# `0` E `1` SÃO COISAS DIFERENTES, E JUNTÁ-LOS ERA UMA MENTIRA DE RELATÓRIO
#   A versão anterior punha os dois em FEITOS. O resultado: a SEGUNDA execução
#   — que não escreve um único byte, e o README promete isso — terminava
#   anunciando "feito: conf cli pacotes gerar tema modo ... " com as dezenove
#   etapas, como se tivesse refeito a instalação inteira. Quem lesse o resumo
#   não tinha como saber que nada mudou; a única prova era contar as linhas
#   `~~` na tela.
#
#   É o mesmo pecado que o `wallpaper.sh` já tinha corrigido no tempo verbal do
#   modo seco: dizer no passado uma coisa que não aconteceu. Aqui a separação é
#   o que torna a idempotência VISÍVEL em vez de prometida.
# O 4 É INFORMAÇÃO, NÃO FALHA — e esquecê-lo aqui já custou uma etapa "vermelha"
#   `4` = divergente por ESCOLHA DELA, sem conserto possível: hoje é a captura de
#   tema que ficou velha porque ela mexeu em Aparência, e o vidro cuja cor
#   derivada não corresponde mais ao slider. Sem esta linha, o instalador
#   anunciava `falhou: vidro` num sistema em que nada falhou — e sair 2 no fim
#   ainda faria a unidade do systemd marcar o serviço como falho todo dia.
concluir() {
  local nome="$1" rc="$2"
  case "$rc" in
    0) CONFEREM+=("$nome") ;;                     # já estava certo: nada escrito
    1) FEITOS+=("$nome") ;;                       # divergia e foi consertado
    3|4) PULADOS+=("$nome") ;;
    *) FALHOS+=("$nome") ;;
  esac
}

# ---------------------------------------------------------------------------
# A LEITURA, SEPARADA DA ESCRITA
#   O pré-voo precisa de FLAVOR/ACCENT para saber qual captura procurar, e não
#   pode rodar depois de uma escrita — uma fase que só OLHA que já criou o
#   meow.conf não olha mais, decide. `etapa_conf` continua sendo a etapa 1 e
#   continua escrevendo; esta aqui só lê, e não imprime nada.
etapa_conf_ler() {
  local fonte="$CONF"
  [ -f "$CONF" ] || fonte="$CONF_PADRAO"
  # shellcheck disable=SC1090
  . "$fonte" || { meow_erro "$fonte tem erro de sintaxe"; return "$MEOW_ERRO"; }
  local v
  for v in FLAVOR ACCENT MODO LOGO; do
    [ -n "${!v:-}" ] || { meow_erro "$v não está definida em $fonte"; return "$MEOW_ERRO"; }
  done
  return 0
}

etapa_conf() {
  passo "Configuração"
  local fonte="$CONF" mudou=0
  if [ -f "$CONF" ]; then
    meow_ok "meow.conf já existe em $CONF"
    # "Já existe" NÃO É "está completo" — ver scripts/migrar_conf.py. Chave nova
    # no exemplo jamais chegava a uma máquina que já tinha rodado o projeto, e o
    # recurso funcionava do mesmo jeito (todo script tem padrão), então nada
    # avisava. O sintoma era ela abrir o meow.conf para mexer numa coisa e não
    # achar a linha.
    if meow_tem python3; then
      local migrar=("$MEOW_RAIZ/scripts/migrar_conf.py" "$CONF" "$CONF_PADRAO")
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
      1) mudou=1        # criou o arquivo: isto é "mexeu", não "confere"
         if meow_seco; then
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

  # O vizinhos.conf não é opcional numa máquina que TEM vizinho: sem ele, a
  # trava que protege um repositório com auto-commit some junto com a lista que
  # era cravada no código. Criar na DETECÇÃO é mais seguro do que depender de
  # alguém lembrar de criar à mão.
  local viz="${MEOW_VIZINHOS:-$HOME/.config/meow/vizinhos.conf}"
  if [ ! -f "$viz" ] && [ -d "$HOME/.config/zsh/.git" ]; then
    local rc_viz
    meow_escrever "$viz" \
"# Criado automaticamente: achei um repositório git em ~/.config/zsh.
# O MeowSystem não escreve nos caminhos abaixo. Um por linha, absoluto.
\$HOME/.config/zsh
\$HOME/.config/cosmic/com.system76.CosmicSettings.Shortcuts" 644 >/dev/null
    rc_viz=$?
    if [ "$rc_viz" = "1" ]; then
      mudou=1
      meow_info "vizinhos.conf criado: ~/.config/zsh tem .git e fica protegido"
    fi
  fi

  # O contrato do `concluir()` é 0 = já estava certo, 1 = consertei. Um
  # `return 0` incondicional aqui punha a etapa que ACABOU de criar o meow.conf
  # do lado "confere" do resumo — exatamente a mentira de relatório que o bloco
  # do `concluir()` existe para não deixar acontecer.
  [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
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
# A COMPLETION NÃO MORA MAIS DENTRO DO REPO ANDROMEDA
# ─────────────────────────────────────────────────────────────────────────────
#   Até 08/2026 este projeto gravava `_meow` em `~/.config/zsh/completions/`, que a
#   TRAVA 1 do `lib/comum.sh` recusa — e com razão: é o repo dela, com auto-commit
#   a cada 10 min. O efeito era observável no histórico (`9bf6fa6`, `54b4e86`,
#   `2330e43`, todos "auto: sync MeowSystem"): o artefato deste projeto viajava
#   para o GitHub privado dela, e um `git checkout` do Andromeda podia apagá-lo
#   sem que o MeowSystem soubesse.
#
#   O acordo novo (self-heal v3.56): quem tem root instala. O Aurora copia
#   `$MEOW_RAIZ/zsh/_meow` para `/usr/local/share/zsh/site-functions/_meow` a cada
#   ciclo, lendo o ponteiro `~/.local/state/meowsystem/raiz`. Esse diretório JÁ está
#   no `$fpath` (medido com `zsh -i -c 'print -l $fpath'` — vem do fpath compilado
#   do zsh, não do `env.zsh`), então não é preciso mexer em dotfile nenhum.
#
#   Aqui, então, seguimos o padrão da casa: cada módulo PULA o que não encontra.
#   Sem permissão de escrita, dizemos a razão em voz alta e o Aurora resolve no
#   próximo ciclo. `MEOW_COMPLETIONS_DIR=` continua existindo para quem quiser
#   outro destino (por exemplo o antigo, dentro do Andromeda).
#
#   O arquivo leva `# OVERRIDE` na segunda linha: é o contrato do próprio
#   Andromeda (completions/CONVENCAO.md) para completion escrita à mão, e o
#   gerador de lá preserva quem tem esse marcador nas 3 primeiras linhas — vale
#   para quem apontar o MEOW_COMPLETIONS_DIR de volta para lá.
COMPLETIONS_DIR="${MEOW_COMPLETIONS_DIR:-/usr/local/share/zsh/site-functions}"

# Escrita atômica igual à da `meow_escrever`, e por fora da trava de território
# de propósito — que continua valendo, agora pelo outro lado: o destino padrão é
# `/usr/local/share/...`, que está em `MEOW_PROIBIDOS_SISTEMA`, e apontar
# `MEOW_COMPLETIONS_DIR` de volta para o Andromeda cai na lista de vizinhos.
# Nos dois casos `meow_escrever` recusaria, corretamente; aqui a escolha de
# escrever é explícita, está num lugar só, e o teste de permissão logo abaixo é
# quem decide se ela acontece.
# O temporário nasce DENTRO do diretório de destino, porque o repo mora em
# /mnt/Apate e o destino em /home ou /usr, e `mv` entre sistemas de arquivos não
# é atômico.
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
  # O destino padrão é do sistema e pertence ao root: aqui não há o que consertar
  # sem sudo, e não é divergência nossa — é etapa de outro dono. Por isso `pula`
  # com `MEOW_OK` e não `meow_muda`: um `doctor` eternamente divergente por causa
  # de um arquivo que o Aurora instala sozinho seria alarme que ninguém pode calar.
  if [ ! -w "$COMPLETIONS_DIR" ]; then
    meow_pula "completion do zsh pulada: '$COMPLETIONS_DIR' não é gravável — quem instala lá é o Ritual da Aurora (self-heal v3.56), no próximo ciclo"
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
  #   existe — numa máquina que não é esta, `/usr/local/share/zsh/site-functions`
  #   pode simplesmente não estar lá. O `-ge 2` que estava aqui engolia esse 3 junto
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
  # O GATO SAIU DAQUI EM 08/08/2026, E TIRÁ-LO DAQUI ERA O PONTO
  #   Ela mandou excluir os gatos do projeto e ficar só com a Coquinha e o Mimir.
  #   Apagar os `assets/meow-*.svg` sem tirar o gerador desta etapa não resolveria
  #   nada: o `gerar_gato.py --conferir` acusaria os arquivos ausentes, o ramo de
  #   baixo os regeraria, e os gatos voltariam ao disco na primeira rodada do
  #   instalador — ou às 5h da manhã, pelo `doctor --consertar`. O acervo agora é
  #   só a pasta dela.
  local rc=0
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" --conferir >/dev/null 2>&1 || rc=1
  # A v1 das capturas também é GERADA da paleta (via a v2 da própria captura).
  # Ver docs/COSMIC-THEMING.md §4h: três applets flatpak leem a v1 por inotify e a
  # GUI não a deriva mais — se este projeto não a escrever, ninguém escreve.
  python3 "$MEOW_RAIZ/scripts/gerar_tema_v1.py" --conferir >/dev/null 2>&1 || rc=1
  if [ "$rc" = "0" ]; then
    meow_ok "os temas já correspondem à paleta"
    return 0
  fi
  if meow_seco; then
    meow_muda "regeraria os temas"
    return "$MEOW_DIVERGENTE"
  fi
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" | sed 's/^/  /' || return "$MEOW_ERRO"
  python3 "$MEOW_RAIZ/scripts/gerar_tema_v1.py" | sed 's/^/  /' || return "$MEOW_ERRO"
  meow_ok "regenerados a partir de palette/"
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
# O tema é a única coisa deste instalador que já precisou de um humano — uma vez.
# O COSMIC não deriva o tema aplicado a partir do que a GUI edita: MEDIDO em
# 04/08/2026, escrever em Dark.Builder/v1/accent não moveu Dark/v1/accent nem em
# 4s nem depois; o cosmic-settings-daemon estava vivo e não derivou. Quem deriva
# é o app gráfico. Então a captura tem de nascer de um import manual.
# Depois disso a captura vai para o git e o `aplicar_tema.sh` a reproduz por
# cópia, com zero clique — e vale de novo se ESTA máquina for reformatada: o
# custo do import manual não volta.
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

  # `--respeitar-gui`: rodar o instalador de novo é MANUTENÇÃO, e manutenção não
  # desfaz o que ela ajustou em Aparência. Foi assim que o ajuste de vidro dela
  # das 17:59 de 05/08 morreu às 18:00:36. Ver a fronteira por árvore no
  # aplicar_tema.sh. Quem impõe a captura é o comando explícito (`meow tema X`).
  local rc
  MEOW_DRY_RUN=0 "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$alvo" --respeitar-gui --conferir >/dev/null 2>&1
  rc=$?
  case "$rc" in
    0) meow_ok "tema '$alvo' já aplicado"; return 0 ;;
    4) meow_pula "tema '$alvo': a captura está velha — você mexeu em Aparência"
       meow_info "para fixar o que está na tela: meow tema capturar $alvo"
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
  # Propaga o código, como todas as outras etapas deste arquivo. O `return 0`
  # que estava aqui vencia os dois ramos do `case`, e o `concluir` jogava a
  # etapa em CONFEREM na rodada em que ela GRAVOU — ver o bloco do `concluir()`,
  # que é este arquivo explicando por que 0 e 1 não se juntam.
  case $? in
    0) meow_ok "modo $MODO já ativo"; return 0 ;;
    1) meow_ok "modo $MODO aplicado"; return "$MEOW_DIVERGENTE" ;;
    *) meow_erro "não consegui escrever $arq"; return "$MEOW_ERRO" ;;
  esac
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

# Os TIPOS DE ARQUIVO, vestidos pelo pack Catppuccin — o que o cosmic-files
# desenha ao abrir uma pasta. Etapa separada da anterior porque o alvo é outro
# (`mimetypes/`, não `apps/`) e a fonte é outra (o pack de terceiro, não desenho
# nosso). Vem DEPOIS do `etapa_icones`, que é quem escreve o `index.theme`: sem a
# declaração `scalable/mimetypes` lá, estes arquivos existiriam no disco e não
# seriam encontrados por ninguém.
# Os ícones do LANÇADOR, do acervo Catppuccin de aplicativo. Depois do
# `etapa_icones` pelo mesmo motivo da etapa irmã: quem declara `512x512/apps` no
# index.theme é aquele, e sem a declaração estes PNG não são achados por ninguém.
etapa_icones_apps() {
  passo "Ícones dos aplicativos"
  ICONES_FLAVOR="${ICONES_FLAVOR:-}" \
    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_apps.sh"
  return $?
}

# Os aplicativos que o acervo Catppuccin não cobre, vestidos pelo Arcticons e
# recoloridos na paleta. Depois do `etapa_icones` pelo mesmo motivo das etapas
# irmãs: quem declara `48x48/apps` no index.theme é aquele.
#
# UM DE DOZE, E ISSO É A REGRA FUNCIONANDO
#   Dos 12 aplicativos órfãos medidos hoje, só o ONLYOFFICE tem no Arcticons um
#   glifo que É o mesmo aplicativo (`onlyoffice-documents`, as três camadas da
#   marca). Os outros 11 não têm nada honesto — `boxy`, `flatseal`, `bleachbit`,
#   `foliate`, `btop`, `file-roller` dão 404 no acervo inteiro de 14.996 nomes,
#   e os `proton-*` são da Proton AG, não do ProtonUp-Qt. Ficam no Papirus, e
#   isso é resultado medido, não desistência: um ícone errado é pior que um
#   genérico, porque mente sobre o que a coisa é.
#
# DIRETÓRIO PRÓPRIO PORQUE `scalable/apps` TEM TRÊS DONOS
#   Lá escrevem o `completar_icones.sh`, o `logo.sh` e o bootstrap do
#   `construir_icones.sh`. Remover órfão ali apagaria arquivo dos outros — o
#   defeito dos dois donos, agora em três. `48x48/apps` nasce aqui e é só nosso.
etapa_icones_apps_arcticons() {
  passo "Ícones de aplicativo em Arcticons"
  FLAVOR="${FLAVOR:-}" \
    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_apps_arcticons.sh"
  return $?
}

# A BANDEJA da barra (o CosmicAppletStatusArea). Irmã da etapa de sistema: mesmo
# acervo, mesmo traço monocromático, mesma dependência do index.theme. O destino é
# OUTRO — `20x20/status`, que é o tamanho MEDIDO da bandeja (19×20 px de tinta na
# captura de 08/08) e um diretório de dono único: o `icones_sistema.sh` é dono de
# `22x22/status` e `scalable/status` e remove órfão nos dois, então escrever lá
# faria os dois se apagarem em laço.
#
# O MAPA ESTÁ VAZIO HOJE, E ISSO É RESULTADO, NÃO PENDÊNCIA
#   O único item de bandeja alcançável pelo tema é o Hefesto, e o symbolic dele é
#   DESENHO DELA — redesenhado em 07/08/2026, com decisão registrada e um teste
#   que o trava no repositório do Hefesto. Trocá-lo por glifo de terceiro seria
#   apagar trabalho dela. A via está provada e o script fica pronto para o dia em
#   que aparecer um item que valha vestir.
etapa_icones_bandeja() {
  passo "Ícones da bandeja"
  ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_bandeja.sh"
  return $?
}

# O ícone de bandeja da STEAM, que é o único destes cinco alcançável — e é
# alcançável por SUBSTITUIÇÃO DE ARQUIVO, não pelo tema: a Steam publica
# `IconThemePath` apontando para dentro do próprio diretório dela, e aquilo entra
# ANTES do tema de ícones.
#
# ETAPA PRÓPRIA, E NÃO UMA LINHA NA DE CIMA
#   A etapa da bandeja escreve dentro do `MeowSystem-Icons` e depende do
#   `index.theme` montado pela `etapa_icones`. Esta escreve um PNG na árvore da
#   Steam, fora do tema, e não depende de índice nenhum — só da Steam instalada.
#   Numa máquina sem Steam ela devolve 3 e some do relatório, que é o
#   comportamento certo para uma etapa opcional.
#
# ELA VOLTAVA SOZINHA, E AGORA ISSO É CONFERÍVEL
#   Em 10/08/2026 a troca foi feita à mão e o cliente a desfez em 18 minutos:
#   `BVerifyInstalledFiles` reprovou o arquivo pelo TAMANHO e reextraiu o
#   `public_all.zip` inteiro. O script monta o PNG com o tamanho, o `mtime` e o
#   `crc32` que o inventário da Steam pede, e o `meow doctor` passa a acusar se
#   um dia ele voltar mesmo assim. A medição inteira está no cabeçalho dele.
etapa_icones_tray_steam() {
  passo "Ícone da bandeja da Steam"
  "$MEOW_RAIZ/scripts/icones_tray_steam.sh"
  return $?
}

# Os `Icon=` de CAMINHO ABSOLUTO. Com caminho absoluto o tema de ícones não é nem
# consultado — era o caso do `input-remapper-gtk`, o único dos 50 `.desktop`
# visíveis nessa situação.
#
# A ORDEM AQUI É REQUISITO, NÃO ESTILO: o script recusa trocar enquanto o nome
# novo não resolver no tema, e quem faz `input-remapper` existir é a etapa do
# Arcticons. Colada na `etapa_nomes` pelo terceiro motivo comum às três: o arquivo
# mora em `/usr/share`, precisa de sudo, e um `apt upgrade` o desfaz.
etapa_absolutos() {
  passo "Ícone por caminho absoluto"
  if [ "${LANCADOR_SISTEMA:-nao}" != "sim" ]; then
    pular_por_optin absolutos; return $?
  fi
  ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_absolutos.sh"
  return $?
}

etapa_mimetypes() {
  passo "Ícones de tipo de arquivo"
  ICONES_FLAVOR="${ICONES_FLAVOR:-}" \
    ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_mimetypes.sh"
  return $?
}

# Os ícones do PRÓPRIO COSMIC — as páginas das Configurações — vestidos pelo
# Arcticons. Mesmo motivo das duas etapas irmãs para vir depois do `etapa_icones`:
# quem declara `<tam>/status` no index.theme é aquele, e sem a declaração estes
# SVG existiriam no disco sem ninguém achá-los.
etapa_icones_sistema() {
  passo "Ícones do sistema"
  ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_sistema.sh"
  return $?
}

# O SOM. O alcance inteiro desta etapa e UM arquivo -- o som de mudanca de volume,
# o unico que o COSMIC realmente toca (medido: `pw-play` aparece em 2 dos 41
# binarios cosmic-*, e canberra em nenhum). Fica em etapa propria porque nao
# depende de nada e nada depende dela.
# Os aplicativos que ela nunca vai abrir. Depende de sudo porque a unica coisa
# que funciona e marcar o arquivo do SISTEMA -- ver o cabecalho do script.
#
# AS TRÊS ETAPAS DO LANÇADOR SÓ RODAM SE FOREM PEDIDAS
#   São a única coisa que este projeto faz FORA do home: marcam .desktop que
#   vieram do apt. Precisam de sudo, um `apt upgrade` do pacote desfaz, e a
#   lista de nomes é o gosto de quem escreveu, não o de quem instala. Por isso
#   `LANCADOR_SISTEMA` tem padrão "nao" — com backup antes de cada escrita e
#   volta por `meow desfazer --lancador`.
etapa_ocultar() {
  passo "Aplicativos ocultos do lançador"
  if [ "${LANCADOR_SISTEMA:-nao}" != "sim" ]; then
    pular_por_optin ocultar; return $?
  fi
  "$MEOW_RAIZ/scripts/ocultar_apps.sh"
  return $?
}

# Os nomes que estouravam a célula do lançador. Colada na `etapa_ocultar` porque
# o par de motivos é o mesmo: parte do conserto mora em `/usr/share`, precisa de
# sudo, e um `apt upgrade` do pacote o desfaz.
#
# DUAS CONTAS DIFERENTES, E AS DUAS FORAM MEDIDAS (ver o cabeçalho do mapa)
#   As reticências são conta de BYTES — passou de 27, o nome vira os 24 primeiros
#   caracteres mais "...". A quebra de linha é conta de PIXELS: a célula tem
#   114 px e cabem duas linhas. Por isso "Visual Studio Code" parecia truncado
#   sem estar: 18 bytes não disparam as reticências, ele só quebra.
etapa_nomes() {
  passo "Nomes curtos no lançador"
  if [ "${LANCADOR_SISTEMA:-nao}" != "sim" ]; then
    pular_por_optin nomes; return $?
  fi
  "$MEOW_RAIZ/scripts/nomes_apps.sh"
  return $?
}

etapa_som() {
  passo "Som de evento"
  "$MEOW_RAIZ/scripts/som.sh" aplicar
  return $?
}

# O vidro fosco que continuava ao maximizar e se perdeu. Duas chaves, e o painel
# vigia os dois diretórios por inotify — então isto vale sem reiniciar nada.
etapa_vidro() {
  passo "Vidro ao maximizar"
  VIDRO_AO_MAXIMIZAR="${VIDRO_AO_MAXIMIZAR:-sim}" "$MEOW_RAIZ/scripts/vidro.sh"
  return $?
}

# A geometria das barras, logo depois do vidro porque são o mesmo assunto visto
# de dois ângulos: o `vidro.sh` decide a COR das barras, este decide a FORMA.
#
# NASCEU FORA DA LISTA, E ISSO É O DEFEITO QUE ESTA LINHA CONSERTA
#   O `forma.sh` foi escrito em 10/08/2026 e nenhum caminho do projeto o
#   chamava: `grep -rn 'forma.sh'` achava só o próprio arquivo. A geometria
#   existia no disco dela porque alguém rodou o script à mão uma vez — numa
#   máquina nova, ou depois de um `install.sh` limpo, as barras voltariam a ser
#   dois retângulos de canto vivo colados na borda.
#   É exatamente o defeito que o `chk_vidro` do `bin/meow` já documenta ter
#   acontecido antes com o vidro ao maximizar, que "voltou ao padrão de fábrica
#   sem que nada acusasse". Uma etapa que ninguém invoca e um verificável que
#   ninguém confere são a mesma doença: o trabalho se perde calado.
etapa_forma() {
  passo "Forma das barras (painel e dock)"
  # As chaves `FORMA_*` vêm do meow.conf e precisam ser EXPORTADAS: o conf é
  # sourceado neste shell, e o forma.sh é processo filho. Sem isto ele vê só os
  # padrões dele, e a geometria escolhida no conf não vale nada.
  (
    export FORMA_PAINEL_SOLTO FORMA_DOCK_SOLTO FORMA_PAINEL_ILHA FORMA_DOCK_ILHA \
           FORMA_MARGEM_PAINEL FORMA_MARGEM_DOCK FORMA_RAIO_PAINEL FORMA_RAIO_DOCK \
           FORMA_ESPACO_PAINEL FORMA_ESPACO_DOCK FORMA_RECHEIO_PAINEL FORMA_RECHEIO_DOCK
    "$MEOW_RAIZ/scripts/forma.sh"
  )
  return $?
}

# O `index.theme` do hicolor DELA, que escondia os próprios ícones — entre eles
# as logos de dois jogos da Steam. Vem antes do `completar_icones` de propósito:
# é a base da cadeia, e completar ícone com a base quebrada é remendar por cima.
etapa_hicolor() {
  passo "Fim da cadeia de ícones (hicolor do usuário)"
  "$MEOW_RAIZ/scripts/hicolor.sh"
  return $?
}

# As capas dos jogos. Depende do `hicolor` acima: com o index.theme quebrado, os
# atalhos apareceriam sem ícone — e "apareceu sem ícone" é um sintoma pior que
# "não apareceu", porque parece que a arte do jogo se perdeu.
etapa_jogos() {
  passo "Jogos da Steam"
  "$MEOW_RAIZ/scripts/jogos_steam.sh"
  return $?
}

# A tela de LOGIN — a única superfície que continuava de fábrica. Depende de sudo
# e do tema já capturado, por isso vem depois de `etapa_tema`.
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

# As pastas ESPECIAIS que o cosmic-files pede pelo nome XDG, vestidas pelo pack
# Catppuccin. Vem ANTES do `etapa_pastas` de propósito: o `construir_pastas.sh`
# só cede um nome quando o pastel JÁ está no disco, e nesta ordem a cessão vale
# na primeira passagem em vez de custar uma rodada.
#
# A PREMISSA DA SPRINT C CAIU, E O QUE ENTROU É OUTRO CAMINHO
#   A sprint queria instalar 14 nomes do pack (`folder-github`, `folder-docker`
#   e companhia). Medido: o `cosmic-files` contém 12 nomes de pasta e só DOIS
#   daqueles aparecem. Os outros são apelidos do Papirus para o Dolphin/KDE, que
#   lê um `.directory` dentro da pasta — e `.directory` aparece ZERO vezes no
#   binário do cosmic-files. Seriam ícones que ela nunca veria. O casamento que
#   vale é por nome XDG, e são 7.
etapa_pastas_xdg() {
  passo "Pastas especiais em Catppuccin"
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

# `FLAVOR` E `ACCENT` PRECISAM ATRAVESSAR — E NÃO ATRAVESSAVAM (medido 08/08/2026)
#   O `. "$fonte"` do `etapa_conf` cria variável de SHELL, não de ambiente, e o
#   `aplicar_apps.sh` é processo FILHO: ele recebia `APPS_ATIVOS` porque a chamada
#   o passa na linha, e mais nada. Provado com um módulo-sonda que só imprimia as
#   duas: `FLAVOR=[VAZIO] ACCENT=[VAZIO]`, pelos dois caminhos (install e doctor).
#   Ou seja, TODO módulo de app rodava no padrão fixo `mocha`/`mauve` — o
#   `_zz_verde` do zapzap inclusive. Ninguém percebeu porque a conf dela é
#   exatamente mocha/mauve; o dia em que ela trocasse de flavor, os apps ficariam
#   para trás em silêncio.
etapa_apps() {
  passo "Aplicativos"
  APPS_ATIVOS="${APPS_ATIVOS:-}" FLAVOR="${FLAVOR:-}" ACCENT="${ACCENT:-}" \
    "$MEOW_RAIZ/scripts/aplicar_apps.sh" aplicar
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

# ---------------------------------------------------------------------------
# A LOGO E A ROTAÇÃO DE GATOS
#
# A INSTALAÇÃO DO ACERVO É INCONDICIONAL; SÓ O TIMER OBEDECE À CHAVE
#   Os gatos vão para o disco mesmo com LOGO_ROTACAO="nao" — sem isso,
#   `meow logo girar` na mão não teria para onde apontar, e ligar a rotação
#   depois exigiria uma rodada extra do instalador antes de funcionar.
#   O que a chave liga e desliga é o RELÓGIO, não o acervo.
etapa_logo() {
  passo "Gatos do painel"
  local destino="$HOME/.config/systemd/user" mudou=0 rc

  FLAVOR="$FLAVOR" LOGO="$LOGO" "$MEOW_RAIZ/scripts/logo.sh"
  rc=$?
  [ "$rc" = "1" ] && mudou=1
  [ "$rc" -ge 2 ] && return "$rc"

  # Desligar tem de DESLIGAR (mesma disciplina do auto-reparo): deixar de
  # instalar manteria vivo o timer que uma execução anterior ligou, e ela veria
  # o gato continuar trocando depois de ter desligado a chave.
  if [ "${LOGO_ROTACAO:-nao}" != "sim" ]; then
    if [ -f "$destino/meow-logo.service" ] || [ -f "$destino/meow-logo.timer" ]; then
      meow_seco && { meow_muda "removeria a rotação"; return "$MEOW_DIVERGENTE"; }
      systemctl --user disable --now meow-logo.timer meow-logo.service >/dev/null 2>&1
      rm -f "$destino/meow-logo.timer" "$destino/meow-logo.service"
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

  # O TIMER FOI EMBORA EM 08/08/2026 — E QUEM O TEM NA MÁQUINA PRECISA PERDÊ-LO
  #   Deixar de instalar não desinstala: o `meow-logo.timer` de uma execução
  #   anterior continuaria vivo, girando o gato no meio da sessão para um efeito
  #   que só apareceria no login seguinte. É a mesma disciplina do
  #   `AUTO_REPARO="nao"` logo acima: desligar tem de DESLIGAR.
  if [ -f "$destino/meow-logo.timer" ]; then
    if meow_seco; then
      meow_muda "removeria o meow-logo.timer (a rotação passou a ser no encerramento da sessão)"
      mudou=1
    else
      systemctl --user disable --now meow-logo.timer >/dev/null 2>&1
      rm -f "$destino/meow-logo.timer"
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "meow-logo.timer removido — o gato agora gira ao encerrar a sessão"
      mudou=1
    fi
  fi

  # A unidade vai por CÓPIA byte a byte: o intervalo não mora mais nela.
  #   Ele virou um carimbo em `~/.local/state/meowsystem/logo-girado-em`, lido
  #   pelo `logo.sh girar-vencido`. Substituir texto na unidade era o que
  #   permitia o `LOGO_INTERVALO` mandar quando o gatilho era um relógio; com o
  #   gatilho no encerramento da sessão não há `OnUnitActiveSec` onde escrevê-lo,
  #   e dois donos da mesma regra é o defeito que este projeto mais combate.
  #   Era um `for` de dois elementos (`.service` e `.timer`) e ficou de UM quando
  #   o timer saiu. Laço de um elemento só é o SC2043 do shellcheck, e ele tem
  #   razão: um `for` que nunca itera esconde que a unidade é uma só.
  local u="meow-logo.service" conteudo
  [ -f "$MEOW_RAIZ/systemd/$u" ] || { meow_erro "falta systemd/$u"; return "$MEOW_ERRO"; }
  conteudo="$(cat "$MEOW_RAIZ/systemd/$u")"
  meow_escrever "$destino/$u" "$conteudo" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac

  if meow_seco; then
    [ "$mudou" = "1" ] && { meow_muda "ligaria a rotação a cada ${LOGO_INTERVALO:-1d}"; return "$MEOW_DIVERGENTE"; }
    meow_ok "rotação de gatos já ligada"
    return 0
  fi

  [ "$mudou" = "1" ] && systemctl --user daemon-reload
  # `--now` importa: sem subir a unidade AGORA, ela não estaria ativa nesta
  # sessão e o `ExecStop` — que é o trabalho inteiro — não rodaria no logout de
  # hoje. `active (exited)` é o estado esperado, não um defeito: o `ExecStart` é
  # um `/bin/true` e o que interessa acontece na parada.
  if [ "$(systemctl --user is-enabled meow-logo.service 2>/dev/null)" != "enabled" ] ||
     [ "$(systemctl --user is-active  meow-logo.service 2>/dev/null)" != "active" ]; then
    systemctl --user enable --now meow-logo.service >/dev/null 2>&1 \
      || { meow_erro "não consegui ligar o meow-logo.service"; return "$MEOW_ERRO"; }
    mudou=1
  fi

  # O PADRÃO AQUI TEM DE SER O MESMO QUE O USADO PELO `logo.sh` — eram dois, e
  # mentia. A unidade era gravada com `${LOGO_INTERVALO:-1d}` e estas duas linhas
  # diziam `30m`: num `meow.conf` sem a chave, a tela anunciava um intervalo que
  # não era o gravado. Hoje quem lê o padrão é o `_giro_venceu` do `logo.sh`, e
  # ele também usa `1d` — se um dia mudar lá, muda aqui.
  #
  # A FRASE DIZ QUANDO O GATO TROCA, NÃO SÓ DE QUANTO EM QUANTO
  #   "a cada 1d" sozinho fazia esperar um gato novo aparecendo no meio do dia,
  #   que é justamente o que não acontece: o painel só relê no login.
  [ "$mudou" = "0" ] && { meow_ok "rotação já ligada (no máximo 1 gato a cada ${LOGO_INTERVALO:-1d}, no login seguinte)"; return 0; }
  meow_ok "o gato gira ao encerrar a sessão, no máximo 1 a cada ${LOGO_INTERVALO:-1d}"
  meow_info "  ele aparece no login seguinte — 'meow logo listar' mostra o acervo"
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
# O VIGIA DO ACERVO — A PASTA PASSA A RESPONDER NA HORA
#
#   Pedido dela em 05/08: "o comando do meow tem que disparar em automático,
#   talvez no self heal algo assim". A etapa acima põe o acervo no disco e liga o
#   RELÓGIO; esta liga o par `meow-assets.path` + `meow-assets.service`, que faz
#   um SVG solto em `assets/gatos/` entrar sem esperar a volta do relógio — que
#   hoje é de um dia.
#
#   VEM DEPOIS DA `etapa_logo` DE PROPÓSITO: o vigia dispara o mesmo `logo.sh`
#   daquela etapa, e ligá-lo antes seria armar o gatilho de um recurso que ainda
#   não foi aplicado uma vez.
#
#   NÃO É NO SELF-HEAL DO RITUAL DA AURORA, que foi o palpite dela. Aquilo é de
#   outro projeto, roda como root e ela pode desligar; o recurso morreria junto,
#   calado. O porquê inteiro está no cabeçalho de `scripts/vigia_assets.sh`.
etapa_assets() {
  passo "Vigia do acervo de gatos (systemd --user)"
  ASSETS_VIGIA="${ASSETS_VIGIA:-sim}" "$MEOW_RAIZ/scripts/vigia_assets.sh"
  return $?
}

etapa_wallpaper() {
  passo "Papéis de parede"
  WALLPAPER_BASE="${WALLPAPER_BASE:-}" WALLPAPER_INTERVALO="${WALLPAPER_INTERVALO:-5m}" \
    WALLPAPER_ORDEM="${WALLPAPER_ORDEM:-aleatoria}" \
    WALLPAPER_FONTES_DELA="${WALLPAPER_FONTES_DELA:-}" \
    WALLPAPER_AJUSTE="${WALLPAPER_AJUSTE:-preencher}" \
    "$MEOW_RAIZ/scripts/wallpaper.sh" aplicar
  local rc=$?
  [ "$rc" = "1" ] && [ "${WALLPAPER_NOTIFICAR:-sim}" = "sim" ] \
    && meow_notificar "MeowSystem" "Carrossel de papéis de parede ligado."

  # O RELÓGIO CURTO DO CARROSSEL — por que ele nasceu em 08/08/2026
  #   Algum processo do COSMIC devolveu o `output.DP-1` para a pasta de fábrica
  #   duas vezes em 48 h. Com o reparo só no doctor diário, o estrago das 14:35
  #   de 07/08 ficaria 38 horas no ar — e nesse intervalo a TV dela girava as
  #   imagens da NASA enquanto o `estado` dizia "carrossel ATIVO". Um tique de
  #   15 minutos fecha a janela, e só é seguro porque o `wallpaper.sh` distingue
  #   reversão (conserta) de escolha dela (código 4, não toca) — e desde
  #   11/08/2026 "escolha dela" é o que está na `WALLPAPER_FONTES_DELA`, dito por
  #   `meow wallpaper permitir`, e não todo caminho que não seja o de fábrica.
  #
  #   Anda de carona no `AUTO_REPARO`: quem desliga o auto-reparo está dizendo
  #   "não mexa sozinho na minha máquina", e isto é mexer sozinho.
  local destino="$HOME/.config/systemd/user" u conteudo mudou_t=0
  if [ "${AUTO_REPARO:-sim}" != "sim" ]; then
    if [ -f "$destino/meow-wallpaper.timer" ]; then
      meow_seco && { meow_muda "removeria o relógio do carrossel"; return "$MEOW_DIVERGENTE"; }
      systemctl --user disable --now meow-wallpaper.timer >/dev/null 2>&1
      rm -f "$destino/meow-wallpaper.timer" "$destino/meow-wallpaper.service"
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "AUTO_REPARO=\"${AUTO_REPARO:-}\" — relógio do carrossel removido"
      return "$MEOW_DIVERGENTE"
    fi
    return "$rc"
  fi
  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    return "$rc"
  fi
  for u in meow-wallpaper.service meow-wallpaper.timer; do
    [ -f "$MEOW_RAIZ/systemd/$u" ] || { meow_erro "falta systemd/$u"; return "$MEOW_ERRO"; }
    conteudo="$(cat "$MEOW_RAIZ/systemd/$u")"
    meow_escrever "$destino/$u" "$conteudo" 644
    case $? in 1) mudou_t=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac
  done
  if meow_seco; then
    [ "$mudou_t" = "1" ] && { meow_muda "ligaria o relógio do carrossel (15 min)"; return "$MEOW_DIVERGENTE"; }
    return "$rc"
  fi
  [ "$mudou_t" = "1" ] && systemctl --user daemon-reload
  if [ "$(systemctl --user is-enabled meow-wallpaper.timer 2>/dev/null)" != "enabled" ] ||
     [ "$(systemctl --user is-active  meow-wallpaper.timer 2>/dev/null)" != "active" ]; then
    systemctl --user enable --now meow-wallpaper.timer >/dev/null 2>&1 \
      || { meow_erro "não consegui ligar o meow-wallpaper.timer"; return "$MEOW_ERRO"; }
    mudou_t=1
  fi
  [ "$mudou_t" = "1" ] && {
    meow_ok "relógio do carrossel ligado: confere a cada 15 min"
    return "$MEOW_DIVERGENTE"
  }
  return "$rc"
}

# ---------------------------------------------------------------------------
uso() {
  cat <<'FIM'

install.sh — instala o MeowSystem inteiro.

  ./install.sh              faz tudo, sem perguntar nada
  ./install.sh --dry-run    mostra o que faria, sem escrever nada
  ./install.sh --wizard     roda `meow configurar` antes (pergunta as chaves do
                            meow.conf, grava lá) e então instala como sempre
  ./install.sh --uninstall  tira o MeowSystem desta máquina
  ./install.sh --help       isto aqui

  MEOW_DRY_RUN=1 ./install.sh   o mesmo que --dry-run, para script e timer

As flags acima dizem COMO esta execução se comporta. QUAIS etapas rodam é
decisão do meow.conf — nunca da linha de comando.

FIM
}

main() {
  # ROOT NÃO. Duas variantes, dois estragos diferentes, uma recusa só.
  #   sudo ./install.sh     -> $HOME vira /root: tema, ícones, fontes, CLI e
  #                            timers de um systemd --user que root não tem.
  #                            Nada aparece na tela dela, e nada avisa.
  #   sudo -E ./install.sh  -> $HOME continua o dela e o instalador larga dezenas
  #                            de arquivos de dono ROOT em ~/.config/cosmic e
  #                            ~/.local/share/icons. É a falha silenciosa da GUI
  #                            de tema descrita no cabeçalho deste arquivo, e o
  #                            conserto é um chown -R.
  if [ "$(id -u)" = "0" ]; then
    meow_erro "não me rode com sudo."
    if [ -n "${SUDO_USER:-}" ]; then
      meow_info "  rode como $SUDO_USER, na sessão gráfica dele:  ./install.sh"
    else
      meow_info "  rode como o seu usuário normal:  ./install.sh"
    fi
    meow_info "  o sudo é pedido por dentro, só onde precisa, e diz o que vai rodar antes."
    meow_info "  instalar em nome de outra pessoa não funciona por sudo -u: as etapas"
    meow_info "  de systemd --user precisam do DBUS/XDG_RUNTIME_DIR da sessão dela."
    return 2
  fi

  local wizard=0 desinstalar=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --wizard|-w) wizard=1 ;;
      # MODOS DE EXECUÇÃO, não escolhas de etapa. A regra do cabeçalho recusa
      # flag que seja SEGUNDA FONTE DE VERDADE sobre o que instalar; estas duas
      # não escolhem nada — dizem COMO esta execução se comporta.
      #
      # Os DOIS têm de ser setados: o lib/comum.sh lê MEOW_DRY_RUN no momento do
      # source (lá em cima, antes deste laço) e grava MEOW_SECO; os scripts
      # FILHOS leem MEOW_DRY_RUN do ambiente. Setar um só deixa metade do seco
      # de fora, e um seco pela metade é pior que nenhum.
      --dry-run|--seco|-n)       MEOW_SECO=1; MEOW_DRY_RUN=1; export MEOW_DRY_RUN ;;
      --uninstall|--desinstalar) desinstalar=1 ;;
      -h|--help)   uso; return 0 ;;
      "")          ;;
      *) meow_erro "opção desconhecida: $1"
         meow_info "o que existe: --dry-run, --wizard, --uninstall, --help."
         meow_info "QUAIS etapas rodam é decisão do meow.conf, não da linha de comando."
         return 2 ;;
    esac
    shift
  done

  # DEPOIS do laço de flags, de propósito: um erro de digitação na linha de
  # comando tem de ser explicado mesmo quando ninguém está olhando a tela.
  #
  # Sem terminal (timer, hook, `| ./install.sh`) o progresso não tem leitor:
  # quase 600 linhas viram quase 600 linhas de journal. `silencioso` cala
  # progresso e mantém o que importa — `~~` mudou, `--` pulou, `!!` aviso e
  # erro. Com tty nada muda, e quem definiu LOG_NIVEL no meow.conf continua
  # mandando.
  if [ ! -t 1 ] && [ -z "${LOG_NIVEL:-}" ]; then
    MEOW_LOG_NIVEL=silencioso
  fi

  meow_titulo "MeowSystem — Catppuccin para o COSMIC"
  meow_seco && meow_aviso "MEOW_DRY_RUN=1 — nada será escrito"

  # O WIZARD VEM ANTES DO LOCK, E É UM PROCESSO À PARTE
  #   Ele grava no meow.conf e sai; o `etapa_conf` logo abaixo lê o arquivo já
  #   com as respostas dela. Rodá-lo aqui dentro do mesmo processo, depois do
  #   `meow_travar`, seria perguntar com o lock na mão — e um ENTER esquecido
  #   deixaria o timer do auto-reparo travado do outro lado.
  #   Sem tty ele não pergunta nada e devolve 0: `echo | ./install.sh --wizard`
  #   instala igual, sem pendurar.
  if [ "$wizard" = "1" ]; then
    MEOW_WIZARD_SEM_APLICAR=1 MEOW_RAIZ="$MEOW_RAIZ" "$MEOW_RAIZ/bin/meow" configurar
    local rc_wiz=$?
    if [ "$rc_wiz" -ge 2 ]; then
      meow_erro "o wizard falhou — nada foi instalado"
      return 2
    fi
  fi

  # A leitura da conf vem antes do pré-voo porque ele precisa de FLAVOR/ACCENT
  # para dizer se existe captura — e não pode rodar depois de uma escrita.
  etapa_conf_ler || return 2

  # DESINSTALAR NÃO PASSA PELO PRÉ-VOO, E ISSO É DE PROPÓSITO
  #   O pré-voo recusa a máquina que não é COSMIC, cobra binário de etapa e pede
  #   a senha. Nada disso vale para quem está indo embora: a máquina onde o
  #   `XDG_CURRENT_DESKTOP` deixou de dizer COSMIC é exatamente a máquina de onde
  #   alguém quer tirar isto daqui, e um "não dá" na saída seria a pior recusa
  #   que este arquivo poderia dar. Só a leitura da conf vem antes, porque o
  #   desinstalador lê NOME_TEMA_ICONES e MEOW_COMPLETIONS_DIR de lá.
  if [ "$desinstalar" = "1" ]; then
    # shellcheck source=lib/desinstalar.sh
    . "$MEOW_RAIZ/lib/desinstalar.sh"
    meow_travar || return 2
    meow_desinstalar; return $?
  fi

  meow_preflight; local rc_pf=$?
  [ "$rc_pf" = "2" ] && return 2

  meow_travar || return 2

  # O auto-reparo é o ÚLTIMO de propósito: ele só faz sentido depois que tudo já foi
  # aplicado uma vez. Ligado antes, o primeiro disparo pegaria a máquina no meio da
  # instalação e "consertaria" o que ainda estava sendo escrito.
  # A CLI vem em segundo, logo depois da configuração: se qualquer etapa daqui
  # para baixo falhar, ela fica com o `meow doctor` na mão para descobrir por quê.
  local etapas=(etapa_conf etapa_cli etapa_pacotes etapa_gerar etapa_tema
                etapa_modo etapa_greeter etapa_vidro etapa_forma etapa_upstream etapa_fontes
                etapa_icones etapa_pastas_xdg etapa_pastas etapa_hicolor etapa_completar_icones
                etapa_mimetypes etapa_icones_apps etapa_icones_apps_arcticons etapa_icones_sistema etapa_icones_bandeja
                etapa_icones_tray_steam etapa_jogos
                etapa_logo etapa_wallpaper etapa_ocultar etapa_nomes etapa_absolutos etapa_som etapa_apps
                etapa_assets etapa_autoreparo)
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
  [ ${#FEITOS[@]}   -gt 0 ] && meow_muda  "mexeu:  ${FEITOS[*]}"
  [ ${#CONFEREM[@]} -gt 0 ] && meow_ok    "confere: ${CONFEREM[*]}"
  [ ${#PULADOS[@]}  -gt 0 ] && meow_pula  "pulado: ${PULADOS[*]}"
  [ ${#FALHOS[@]}   -gt 0 ] && meow_erro  "falhou: ${FALHOS[*]}"

  # Um `pulado:` mudo não diz o que fazer — mas dizer a coisa ERRADA é pior que
  # o silêncio. As quatro etapas do `/usr/share` podem se pular por dois motivos
  # (falta de root, ou `LANCADOR_SISTEMA="nao"`, que é opt-in e é o padrão), e
  # cada um tem um conserto diferente. Quem se pulou por opt-in já se anunciou em
  # PULADOS_OPTIN; o que sobrar é que de fato depende de sudo.
  if [ ${#PULADOS[@]} -gt 0 ]; then
    local p por_root=0
    for p in "${PULADOS[@]}"; do
      case " ${PULADOS_OPTIN[*]:-} " in *" $p "*) continue ;; esac
      case "$p" in greeter|ocultar|nomes|absolutos) por_root=1 ;; esac
    done
    [ "$por_root" = "1" ] && \
      meow_info "algumas dessas precisavam de root. Para completá-las:  sudo -v && ./install.sh"
    [ ${#PULADOS_OPTIN[@]} -gt 0 ] && \
      meow_info "${PULADOS_OPTIN[*]}: é opt-in, não é falta de root — LANCADOR_SISTEMA=\"sim\" no meow.conf liga"
  fi

  meow_registrar "install.sh mexeu=${#FEITOS[@]} conferem=${#CONFEREM[@]} pulados=${#PULADOS[@]} falhos=${#FALHOS[@]}"

  if [ ${#FALHOS[@]} -gt 0 ]; then
    printf '\n  %sAlgumas etapas falharam. Nada foi deixado pela metade —%s\n' "$C_AMARELO" "$C_ZERO"
    printf '  %scada etapa é independente, e o resto foi aplicado.%s\n\n' "$C_AMARELO" "$C_ZERO"
    return 2
  fi
  # A frase muda conforme o que de fato aconteceu. "Nada é escrito duas vezes" é
  # uma promessa; dizer que NENHUMA etapa mexeu em nada é a prova dela, na tela,
  # sem ela precisar contar linha nenhuma.
  if [ ${#FEITOS[@]} -eq 0 ]; then
    printf '\n  %sPronto.%s Nenhuma etapa precisou escrever nada — já estava tudo no lugar.\n\n' \
      "$C_VERDE$C_FORTE" "$C_ZERO"
    return 0
  fi

  # "Rode de novo QUANDO QUISER" era a frase mais cara da tela, porque o README
  # diz o contrário logo no parágrafo 4: numa máquina nova são TRÊS passagens até
  # o silêncio. Não é defeito — o `index.theme` descreve os diretórios que
  # EXISTEM, e as pastas coloridas nascem na etapa seguinte. Quem tem de saber
  # disso é o instalador, não quem leu o parágrafo 4.
  printf '\n  %s%d etapa(s) mudaram nesta passagem.%s\n' \
    "$C_AMARELO$C_FORTE" "${#FEITOS[@]}" "$C_ZERO"
  printf '  Algumas etapas dependem do resultado da anterior. Rode mais uma vez,\n'
  printf '  até a tela dizer "nenhuma etapa precisou escrever nada":\n\n'
  printf '      ./install.sh\n\n'
  return 0
}

main "$@"

#!/usr/bin/env bash
# install.sh — instala o MeowSystem inteiro. Sem flag nenhuma.
#
#   ./install.sh                 faz tudo, e repete a fila até ninguém escrever
#   ./install.sh --dry-run       mostra o que faria, sem escrever nada
#   ./install.sh --uma-passagem  roda a fila uma vez só (depuração)
#   ./install.sh --wizard        pergunta o meow.conf antes, e então faz tudo
#   ./install.sh --uninstall     tira o MeowSystem desta máquina
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
#
# `set -a` EM VOLTA DO `.` — A ARMADILHA Nº 3, CURADA AQUI TAMBÉM (25/08/2026)
#   O conf é sourceado NESTE shell, e quase toda etapa chama um script de
#   `scripts/`, que é processo FILHO. Sem exportação, o filho vê só os padrões
#   dele. A defesa era cada etapa manter a sua listinha de `export` — e lista
#   fixa envelhece calada: o `etapa_forma` exportava 12 nomes `FORMA_*` enquanto
#   o `scripts/forma.sh` já lia 18, e as seis novas (ALA_INICIAL/ALA_FINAL/CENTRO
#   × painel e dock) chegavam VAZIAS. O sintoma, reproduzido: `meow doctor`
#   aplicava o tamanho da bandeja e `./install.sh` dizia "confere" sem aplicar —
#   numa máquina nova a bandeja nunca encolhia, e nada acusava.
#   `set -a` exporta tudo o que o conf definir, então chave nova nasce valendo.
#   É a mesma cura do `carregar_conf` do `bin/meow` e do `meow-wallpaper.service`.
etapa_conf_ler() {
  local fonte="$CONF"
  [ -f "$CONF" ] || fonte="$CONF_PADRAO"
  # shellcheck disable=SC1090
  set -a; . "$fonte" || { set +a; meow_erro "$fonte tem erro de sintaxe"; return "$MEOW_ERRO"; }; set +a
  local v
  for v in FLAVOR ACCENT MODO LOGO; do
    [ -n "${!v:-}" ] || { meow_erro "$v não está definida em $fonte"; return "$MEOW_ERRO"; }
  done
  # Um FLAVOR que o pack não tem vira o padrão do pack, sem reescrever o meow.conf.
  FLAVOR="$(meow_flavor)"
  return 0
}

# ---------------------------------------------------------------------------
# O BACKUP QUE O "VOLTAR AO TEMA DE ANTES" DEVOLVE É DESTA MÁQUINA — 21/09/2026
#
#   MEDIDO, simulando por leitura quem acabou de clonar o repositório:
#   `assets/temas/capturados/original/captura.txt` diz, na terceira linha,
#   `origem: /home/<usuário>/.config/cosmic` — 121 arquivos, 04/08/2026.
#   Numa máquina onde o `aplicar_tema.sh` ainda não tinha rodado, aquela captura
#   era a ÚNICA rede embaixo do botão «Voltar ao tema de antes», e o painel
#   chama o `meow desfazer` com `MEOW_SIM=1` (app/servidor.py) — que era
#   exatamente o que desligava a guarda de "esta captura é de outra máquina" no
#   `cmd_desfazer`. Num estranho, o botão instalava o desktop de fábrica de
#   OUTRA PESSOA e apagava as chaves que ela não tivesse.
#
#   O backup certo já existia, mas só nascia DE CARONA: quem o cria é o
#   `aplicar_tema.sh` (o `-tema-PRIMEIRO-`), e ele só roda se houver captura
#   para o par `FLAVOR-ACCENT` escolhido. O `meow.conf.exemplo` oferece 5
#   flavors × 12 accents e existem 4 capturas: quem respondesse "macchiato" +
#   "teal" no wizard — duas opções que a própria pergunta oferecia — caía no
#   `return 3` do `etapa_tema` e ficava sem tema E sem desfazer.
#
#   Por isso esta etapa é a PRIMEIRA da lista e não depende de configuração
#   nenhuma: ela olha `~/.config/cosmic`, copia as árvores de tema que
#   estiverem lá e escreve um `captura.txt` ao lado, com a `origem:` DESTA
#   máquina. É o arquivo que a conferência procura, e é o que separa "o COSMIC
#   de antes daqui" de "o COSMIC de antes de outra pessoa".
#
#   NÃO RECAPTURA, E ISSO É A METADE IMPORTANTE. Se já existe um
#   `*-tema-PRIMEIRO-*`, aquele é o de antes; sobrescrever seria gravar por cima
#   do único estado que o projeto promete devolver — o mesmo motivo pelo qual o
#   `capturar_tema.sh` recusa recapturar a referência.
#
#   E A RÉGUA DE "JÁ RODOU AQUI" É A DO `aplicar_tema.sh`, NÃO UMA MAIS ESTREITA
#   [corrigido em 21/09/2026, no mesmo dia em que esta etapa nasceu]
#     A guarda abaixo olhava só `*-tema-PRIMEIRO-*`. O `garantir_backup`
#     (scripts/aplicar_tema.sh) mede outra coisa, e a explicação está escrita
#     lá por extenso: «"PRIMEIRO" é medido, não presumido: se já existe QUALQUER
#     backup de tema aqui, este script já rodou antes e o que estiver no disco
#     agora já é obra nossa — chamar isso de "antes do MeowSystem" seria uma
#     mentira gravada no nome do arquivo». O mesmo comentário diz que numa
#     máquina assim «nenhum PRIMEIRO nasce» — ou seja, a régua estreita daqui
#     nunca encontrava nada justamente nas máquinas que já rodam o projeto.
#
#     MEDIDO: HOME com `backups/2026-08-04T10-00-00-tema-mocha-mauve` (o "antes"
#     de verdade) e o accent do COSMIC já vestido pelo MeowSystem, sem nenhum
#     PRIMEIRO. Esta etapa criava `<carimbo>-tema-PRIMEIRO-pre-instalacao` com
#     `captura: pre-instalacao` contendo O TEMA DO MEOWSYSTEM, e em seguida
#     `meow desfazer` achava esse backup, imprimia "devolvendo o COSMIC ao
#     estado de <carimbo>" / "pronto" e devolvia o mesmo tema que já estava na
#     tela: um no-op que reporta sucesso. Pior, ele passava NA FRENTE da captura
#     `original`, que era quem de fato respondia pelo desfazer ali — numa
#     máquina desta casa o botão funcionava antes e deixava de funcionar depois.
#
#     Então a pergunta passa a ser "já há QUALQUER cópia do COSMIC daqui?", e
#     não "já há um PRIMEIRO?". O laço abaixo é o do `aplicar_tema.sh` — mesmo
#     glob, mesmo `[ -d ]` — com UMA exclusão a mais, que está explicada nele.
#
#   O NOME SEGUE O GLOB DE QUEM RESTAURA, e não é enfeite: `cmd_desfazer`
#   (bin/meow) e a fase 3 do `lib/desinstalar.sh` procuram literalmente
#   `"$MEOW_ESTADO"/backups/*-tema-PRIMEIRO-*`. Um sufixo diferente aqui seria
#   um backup que ninguém acha.
etapa_backup_tema() {
  passo "Backup do tema de antes"
  local cosmic; cosmic="$(meow_cosmic_dir)"
  local velho primeiro="" mais_velho=""
  for velho in "$MEOW_ESTADO"/backups/*-tema-*; do
    [ -d "$velho" ] || continue
    case "$velho" in *-tema-PRIMEIRO-*) primeiro="$velho"; break ;; esac
    # `<carimbo>-tema-v1` é do `gerar_tema_v1.py` e guarda as CAPTURAS DO
    # REPOSITÓRIO, não o `~/.config/cosmic` desta pessoa — a poda do
    # aplicar_tema.sh já tinha se queimado com ele em 10/08/2026, e o comentário
    # de lá conta a história. Aqui a pergunta é "já existe cópia do COSMIC
    # daqui?", e essa pasta não é uma: contá-la deixaria sem ponto de volta quem
    # rodasse `meow doctor --consertar` antes do primeiro `./install.sh`.
    case "$velho" in *-tema-v1) continue ;; esac
    # O glob sai ordenado, e o nome começa pelo carimbo: o primeiro que cai aqui
    # é o mais antigo, que é o que mais perto está do "antes" desta máquina.
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

  # Sem árvore de tema no disco não há o que guardar, e inventar uma pasta vazia
  # chamada "antes" seria pior do que não ter nenhuma: o `cp -a
  # "$primeiro"/com.system76.CosmicTheme.*` do `cmd_desfazer` (bin/meow) não tem
  # `nullglob`, então numa pasta sem árvore nenhuma o glob fica literal, o `cp`
  # reclama de arquivo inexistente e a função devolve MEOW_ERRO. Não é silêncio:
  # é o botão passando a FALHAR em vez de restaurar. (O `garantir_backup` do
  # scripts/aplicar_tema.sh ainda cria essa pasta vazia numa máquina sem árvore
  # de tema; é de fora desta sprint, e fica anotado.)
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

  # Manifesto com caminhos RELATIVOS, como o do `capturar_tema.sh`: o backup
  # precisa ser conferível depois de a pasta mudar de lugar.
  ( cd "$destino" && find . -type f ! -name manifesto.sha256 -print0 \
      | sort -z | xargs -0 sha256sum > manifesto.sha256 ) 2>/dev/null || true

  # O `captura.txt` tem o MESMO formato do das capturas versionadas
  # (o `captura.txt` de cada captura do pack), e de propósito: a pergunta
  # "de qual home isto saiu?" se responde com o mesmo `grep origem` dos dois
  # lados, e foi a ausência dessa linha aqui que deixou o `desfazer` sem como
  # distinguir esta máquina da de outra pessoa.
  local total
  total="$(find "$destino" -type f ! -name manifesto.sha256 ! -name captura.txt 2>/dev/null | wc -l)"
  {
    echo "captura: pre-instalacao"
    echo "quando: $(date -Iseconds)"
    echo "origem: $cosmic"
    echo "arquivos: $total"
  } > "$destino/captura.txt"

  # A RAIZ AQUI É A DINÂMICA, IGUAL À DO `captura.txt` [21/09/2026]
  # Esta função lê de `$(meow_cosmic_dir)` e já grava `origem: $cosmic` no
  # captura.txt ao lado. Com o `~/.config/cosmic` literal que estava escrito
  # aqui, um backup tirado com `MEOW_COSMIC_DIR` apontando para outra árvore
  # dizia DUAS raízes diferentes na mesma pasta — e a instrução mandava o
  # humano restaurar na errada. (O par idêntico do `scripts/aplicar_tema.sh`,
  # linhas 324 e 329, tem o mesmo literal e é de fora desta sprint: anotado.)
  # O BOTÃO SAI DO `--onde` — 24/09/2026, P57: esta frase citava o «Voltar ao
  # tema de antes» por extenso, a classe do achado 47. Sem resposta (sem
  # python3, sem o painel no clone), ela fica só com o `meow desfazer`.
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
    # "Já existe" NÃO É "está completo" — ver scripts/migrar_conf.py. Chave nova
    # no exemplo jamais chegava a uma máquina que já tinha rodado o projeto, e o
    # recurso funcionava do mesmo jeito (todo script tem padrão), então nada
    # avisava. O sintoma era ela abrir o meow.conf para mexer numa coisa e não
    # achar a linha.
    if meow_tem python3; then
      # O pack que o último install vestiu (vazio: o padrão). Se o conf nomeia
      # outro, o ponteiro do pack de antes vira o do pack no ar (decisão 12).
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
  # `set -a` pelo mesmo motivo do `etapa_conf_ler` — ver o parágrafo lá em cima.
  # Esta é a leitura que vale para o resto da execução, então é a que mais
  # importa: é daqui que saem as variáveis que as etapas passam aos scripts.
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

  # O VIZINHOS.CONF DEIXOU DE NASCER AQUI EM 24/09/2026 (P39). Este bloco o
  # criava sozinho quando achava um repositório git em `~/.config/zsh`, com
  # aquele caminho e o dos atalhos do COSMIC dentro. Era a proteção certa para
  # UMA casa, escrita no instalador de todas: a regra de 23/09 tira do projeto
  # tudo o que olha para o `~/.config/zsh`, sem "integração opcional" que
  # continue olhando quando ele existe. O arquivo continua sendo lido
  # (lib/comum.sh), o modelo continua em `assets/contratos/vizinhos.conf.exemplo`, e quem tem um
  # vizinho o escreve. Nesta casa ele existe desde 11/09 e não muda.

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
#   `$MEOW_RAIZ/assets/zsh/_meow` para `/usr/local/share/zsh/site-functions/_meow` a cada
#   ciclo, lendo o ponteiro `~/.local/state/meowsystem/raiz`. Esse diretório JÁ está
#   no `$fpath` (medido com `zsh -i -c 'print -l $fpath'` — vem do fpath compilado
#   do zsh, não do `env.zsh`), então não é preciso mexer em dotfile nenhum.
#
#   Aqui, então, seguimos o padrão da casa: cada módulo PULA o que não encontra.
#   Sem permissão de escrita, dizemos a razão em voz alta e o Aurora resolve no
#   próximo ciclo. `MEOW_COMPLETIONS_DIR=` continua existindo para quem quiser
#   outro destino (por exemplo o antigo, dentro do Andromeda).
#
#   O "ACORDO NOVO" ACIMA DEIXOU DE SER CONTADO COMO CERTO EM 24/09/2026 (P39):
#   ele dependia do self-heal do Ritual da Aurora, que não existe fora de uma
#   casa, e nesta mesma casa o `_meow` não estava em `site-functions` quando
#   foi medido. A frase da tela parou de prometer o Ritual. Instalar em
#   `site-functions` sem ele pede root, e a ponte root deste projeto não tem
#   verbo para isso — fica anotado como o que falta, não como feito.
#
#   O arquivo leva `# OVERRIDE` na segunda linha: é o contrato do próprio
#   Andromeda (completions/CONVENCAO.md) para completion escrita à mão, e o
#   gerador de lá preserva quem tem esse marcador nas 3 primeiras linhas — vale
#   para quem apontar o MEOW_COMPLETIONS_DIR de volta para lá.
#
# O QUE FALTAVA FOI FEITO EM 24/09/2026 (P44): A COMPLETION MORA NA CASA DE QUEM USA
#   O destino padrão passou a ser `~/.local/share/zsh/site-functions` (o XDG de
#   dados do usuário): gravável sem root, sem ponte, e fora do repositório de
#   qualquer pessoa. O `/usr/local/share/...` fica como escolha explícita, pelo
#   mesmo `MEOW_COMPLETIONS_DIR`.
#
#   O QUE A MEDIÇÃO DO DIA DERRUBOU: a sprint dizia que esse diretório já está
#   no `$fpath`. Não está — nem no fpath compilado do zsh desta máquina
#   (`zsh -f -c 'print -l $fpath'` começa em `/usr/local/share/zsh/...`), nem
#   em arquivo de inicialização nenhum dela. O zsh não o procura sozinho. Então
#   esta etapa faz a metade que é nossa — o arquivo no lugar — e DIZ a linha
#   que falta, do mesmo jeito que o `prompt.sh` diz a do starship: a linha do
#   `fpath` é do shell de quem usa, e o MeowSystem não escreve em arquivo de
#   shell. Ela sai só quando o arquivo é escrito, e só se o fpath de fábrica
#   do zsh não tiver o diretório — dizer a mesma coisa em toda passagem é
#   ensinar a ignorar.
#
# E O TAB CONTINUAVA SEM FUNCIONAR — O QUE A P47 FEZ (24/09/2026)
#   A linha dita não é linha escrita: medido no zsh interativo dela depois da
#   P44, `whence -w _meow` dava `none` e `$_comps[meow]` vinha vazio. O que
#   faltava era o verbo que o bloco da P39 anotou, e ele existe agora: a ponte
#   root ganhou `completion-instalar`, que copia o `_meow` do clone registrado
#   no perfil para `/usr/local/share/zsh/site-functions` — o PRIMEIRO
#   diretório do fpath de fábrica (`zsh -f -c 'print -l $fpath'`, medido no
#   dia). Sem senha, porque a senha foi a do instalador, uma vez; sem editar o
#   shell de ninguém. A casa do usuário da P44 passou a ser o caminho de quem
#   não tem a ponte, e não o de todo mundo — ver `completion_no_sistema`.
COMPLETIONS_DIR="${MEOW_COMPLETIONS_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions}"
# O destino da ponte, e ele é literal lá dentro (`COMPLETION=` em
# scripts/ponte_root.sh): esta cópia existe só para PERGUNTAR se o zsh procura
# ali e se o que está lá já é o do clone. Mudar um sem o outro é a ponte
# escrevendo num lugar e esta etapa conferindo outro.
COMPLETIONS_SISTEMA=/usr/local/share/zsh/site-functions

# Escrita atômica igual à da `meow_escrever`, e por fora da trava de território
# de propósito — que continua valendo, agora pelo outro lado: apontar o
# `MEOW_COMPLETIONS_DIR` para `/usr/local/share/...` cai em
# `MEOW_PROIBIDOS_SISTEMA` (até a P44 era o destino padrão), e apontá-lo de volta
# para o Andromeda cai na lista de vizinhos.
# Nos dois casos `meow_escrever` recusaria, corretamente; aqui a escolha de
# escrever é explícita, está num lugar só, e o teste de permissão logo abaixo é
# quem decide se ela acontece.
# O temporário nasce DENTRO do diretório de destino, porque o repo mora em
# /mnt/Apate e o destino em /home ou /usr, e `mv` entre sistemas de arquivos não
# é atômico.
instalar_completion() {
  local origem="$MEOW_RAIZ/assets/zsh/_meow" destino="$COMPLETIONS_DIR/_meow" tmp rc

  if [ "${MEOW_SEM_COMPLETIONS:-0}" = "1" ]; then
    meow_pula "completions do zsh puladas (MEOW_SEM_COMPLETIONS=1)"
    return "$MEOW_OK"
  fi
  [ -f "$origem" ] || { meow_erro "falta $origem"; return "$MEOW_ERRO"; }
  # Onde o zsh já procura, primeiro — e só quando ninguém escolheu outro
  # diretório: um `MEOW_COMPLETIONS_DIR` escrito continua mandando, como antes.
  if [ -z "${MEOW_COMPLETIONS_DIR:-}" ]; then
    completion_no_sistema; rc=$?
    [ "$rc" = "$MEOW_SEM_DEPENDENCIA" ] || return "$rc"
  fi
  # O diretório do usuário nasce aqui; um que a pessoa apontou e não existe
  # continua sendo "não há onde pôr" — criar caminho alheio não é nosso.
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
  # Um destino apontado para o sistema pertence ao root (até a P44 era o padrão):
  # aqui não há o que consertar sem sudo, e não é divergência nossa — é etapa de
  # outro dono. Por isso `pula`
  # com `MEOW_OK` e não `meow_muda`: um `doctor` eternamente divergente por causa
  # de um arquivo que o Aurora instala sozinho seria alarme que ninguém pode calar.
  # A PROMESSA DO RITUAL SAIU DA FRASE EM 24/09/2026 (P39). Ela dizia que o
  # self-heal da Aurora instalaria o arquivo "no próximo ciclo" — numa máquina
  # sem o Ritual, isto é, em todas menos uma, ninguém instala, e nesta casa
  # mesmo o `_meow` não estava lá quando foi medido. A frase agora diz o que é
  # verdade em qualquer máquina, e a porta que existe.
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
  # O aviso só sai quando o destino cai num caminho que o `vizinhos.conf`
  # protege — com MEOW_COMPLETIONS_DIR apontando para outro lugar (é assim que
  # isto foi testado) ele seria uma mentira. Até 24/09/2026 a pergunta era pelo
  # NOME de um repositório (`~/.config/zsh`); agora é pela lista que a pessoa
  # escreveu, que é a mesma que a TRAVA 1 lê.
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
  # A linha do `fpath`, dita e não escrita — ver o bloco "O QUE FALTAVA FOI
  # FEITO", acima. O `-f` pergunta ao zsh sem arquivo de inicialização nenhum:
  # é o fpath de fábrica, e é o único que se pode perguntar sem rodar o shell
  # de alguém.
  if meow_tem zsh && ! zsh -f -c 'print -l -- $fpath' 2>/dev/null | grep -qxF -- "$COMPLETIONS_DIR"; then
    meow_info "o bloco do MeowSystem no terminal põe $COMPLETIONS_DIR no fpath do zsh"
  fi
  return "$MEOW_DIVERGENTE"
}

# A COMPLETION NO `fpath` DE FÁBRICA, PELA PONTE ROOT — 24/09/2026 (P47)
#
#   0 o `_meow` do sistema já é o do clone (e a cópia da P44 já não existe)
#   1 mudou algo (ou, no seco, mudaria)
#   3 este caminho não vale aqui — a `instalar_completion` segue para a casa
#     do usuário, que é o caminho da P44
#
# A ORDEM DAS PERGUNTAS
#   1. o zsh procura em `$COMPLETIONS_SISTEMA` sem arquivo de inicialização
#      nenhum? Numa distribuição cujo zsh foi compilado com outro fpath, a
#      ponte escreveria num lugar que ninguém lê: 3.
#   2. o `_meow` de lá já é o do clone? Então está feito — venha de onde vier
#      (da ponte, ou do Ritual numa casa que o tem). Isto é só LER: o arquivo é
#      0644, e perguntar não pede sudo.
#   3. a ponte está no ar E conhece o verbo? A ponte instalada é lida (0755,
#      legível) antes de ser chamada. Uma ponte anterior à P47 não tem o verbo,
#      e a regra de sudo dela não o libera: chamá-la seria um `sudo -n` negado
#      no `auth.log` a cada passagem, até a `etapa_ponte_root` — que vem logo
#      depois desta — regravar as duas. O `meow_ponte_viva` ainda confere que o
#      `$HOME` é o do perfil: uma casa de brinquedo nunca usa a ponte de verdade.
#
# A CÓPIA DA P44 SAI quando o sistema tem a certa: ela não se atualiza mais, e
#   quem seguiu o conselho da P44 — `fpath=(~/.local/share/zsh/site-functions
#   $fpath)`, NA FRENTE — carregaria a velha no lugar da nova para sempre. Ela
#   está no destino padrão desta etapa, com o nome dela, e o `--uninstall` já
#   a apagava pelo mesmo caminho: é nossa.
#
# NA PRIMEIRA INSTALAÇÃO a ponte nasce DEPOIS desta etapa (a `etapa_ponte_root`
#   vem logo atrás da `etapa_cli`): a primeira passagem cai na casa do usuário e
#   a segunda — o laço das passagens roda sozinho — vem para cá. O mesmo vale
#   para a ponte velha de quem atualiza.
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

# --- O ESTADO DO USUÁRIO NASCE AQUI, E NÃO NA PRIMEIRA ESCRITA — 21/09/2026 --
#
#   Até esta data o painel gravava a curadoria DENTRO do clone: `BANIDOS.txt` e
#   `lado.tsv` eram versionados, e clicar em "Tirar" deixava diff pendente
#   (`+47` linhas no clone dele, às 17h09 daquele dia). Agora eles moram em
#   `$MEOW_ESTADO/papeis-de-parede/`, semeados do `.padrao` versionado.
#
#   O `meow_estado_com_padrao` semeia sozinho na primeira leitura, então esta
#   chamada é redundante POR DESENHO — e ainda assim vale: sem ela, o estado só
#   nasceria no dia em que ela clicasse em "Tirar", e um `meow wallpaper semear`
#   rodado antes disso em máquina recém-instalada não teria a lista de fábrica
#   na mão para saber o que NÃO baixar. É a mesma razão pela qual o ponteiro da
#   raiz é escrito aqui em vez de na primeira vez que a CLI precisa dele.
#
#   Não há `meow_muda` nem contagem de divergência: `$MEOW_ESTADO` é a nossa
#   casa, não a máquina dela, e é o mesmo acordo que o `meow_travar` e o
#   `meow_log` já têm com o `--seco`. O que esta função pode criar é uma cópia
#   de um arquivo versionado dentro do nosso próprio diretório de estado.
#
#   UMA CHAMADA POR PASTA, E NÃO UMA POR ARQUIVO: o `meow_estado_com_padrao`
#   semeia todo `*.padrao` da pasta de origem de uma vez. Listar os arquivos
#   aqui seria a armadilha nº 3 do projeto — um `.padrao` novo ficaria de fora
#   desta lista e só nasceria na primeira escrita, calado.
semear_estado_do_usuario() {
  meow_estado_com_padrao papeis-de-parede BANIDOS.txt >/dev/null
  return 0
}

# --- O `merge=ours` DO `.gitattributes` ERA INERTE EM CLONE NOVO ------------
#
#   `.gitattributes` declara `packs/meowsystem/wallpapers/BANIDOS.txt merge=ours`
#   desde sempre. Um `merge=ours` sem o DRIVER registrado não faz nada: o git
#   procura `merge.ours.driver` na configuração e, não achando, cai no merge de
#   três vias normal. Medido em 21/09/2026: o driver existia só no `.git/config`
#   DELE, e `grep -rn "merge.ours.driver" install.sh lib/ scripts/` voltava
#   vazio. Quem clonasse recebia a declaração sem o mecanismo — que é a pior das
#   combinações, porque parece protegido e não está.
#
#   ELE É CINTO, E NÃO A DEFESA. A defesa é o arquivo ter saído do git nesta
#   mesma sprint.
#
#   E O CINTO NÃO ALCANÇA A TRAVESSIA — MEDIDO EM 22/09/2026. Este comentário
#   afirmava que o que sobrava para o driver cobrir era o `pull` entre o clone
#   com o arquivo antigo rastreado e o novo. Não é. Num clone de teste parado no
#   commit anterior, com a curadoria COMMITADA, o merge da migração foi rodado
#   DUAS vezes — com e sem `merge.ours.driver` registrado — e o resultado foi o
#   mesmo nas duas: `BANIDOS.txt` resolvido por DETECÇÃO DE RENAME do `ort`
#   (as linhas foram para o `.padrao`) e `lado.tsv` em `CONFLICT
#   (modify/delete)`. Driver de merge só é chamado quando os DOIS lados têm
#   conteúdo para o caminho, e deste lado `packs/meowsystem/wallpapers/BANIDOS.txt`
#   foi APAGADO: rename/delete não passa por driver nenhum.
#
#   O QUE ELE COBRE, E POR ISSO CONTINUA AQUI: as duas máquinas enquanto ambas
#   estiverem ANTES da migração. Aí os dois lados têm o `BANIDOS.txt`
#   rastreado, o `merge=ours` do `.gitattributes` vale, e sem o driver ele é
#   inerte — que é exatamente o conflito real que originou a sprint. Depois que
#   as duas migrarem, o driver fica de cinto para a próxima declaração
#   `merge=ours` que alguém escrever, e a declaração de hoje fica órfã (ela
#   nomeia um caminho que saiu do índice). Mexer no `.gitattributes` está fora
#   da tabela desta sprint, e apontá-lo para o `.padrao` seria ERRADO: o
#   `.padrao` é receita de fábrica e PRECISA mesclar de três vias entre as duas
#   máquinas — `merge=ours` ali engoliria, calado, toda atualização da lista de
#   fábrica que viesse do outro lado.
#
#   `--local` de propósito: a configuração é DESTE clone. Mexer no `--global`
#   seria o instalador de um projeto opinando sobre todo repositório da pessoa.
registrar_driver_de_merge() {
  command -v git >/dev/null 2>&1 || return 0
  # ESTE DIRETÓRIO TEM DE SER A RAIZ, E NÃO "ter algum repositório acima" —
  # MEDIDO EM 22/09/2026, e o comentário que estava aqui afirmava uma distinção
  # FALSA: dizia que `--git-dir` não sobe a árvore e que
  # `--is-inside-work-tree` sobe. OS DOIS SOBEM IGUAL. Com o MeowSystem
  # extraído dentro do clone de OUTRA pessoa (o zip do GitHub solto numa pasta
  # como `~/repo-dela/vendor/meowsystem`, sem `.git` próprio),
  # `rev-parse --git-dir` respondia `~/repo-dela/.git`, a guarda passava, e o
  # `config --local` gravava `[merge "ours"]` no `.git/config` DELA.
  #
  # É o mesmo pecado que o parágrafo acima recusa ao não mexer no `--global`, e
  # com consequência PIOR: registrar o driver no repositório de terceiro muda,
  # calado, o merge de todo caminho que o `.gitattributes` DELE marque
  # `merge=ours` — passa a tomar "ours" em vez de merge de três vias.
  #
  # `--show-toplevel` responde certo nos dois casos, inclusive em WORKTREE
  # (onde `.git` é ARQUIVO e não diretório), que é como esta sprint foi medida.
  # O `pwd -P` do outro lado é o mesmo que o `MEOW_RAIZ` já usa na linha 63:
  # sem resolver o link simbólico, um clone alcançado por atalho não casaria.
  [ "$(git -C "$MEOW_RAIZ" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$MEOW_RAIZ" && pwd -P)" ] || return 0
  [ "$(git -C "$MEOW_RAIZ" config --local --get merge.ours.driver 2>/dev/null)" = "true" ] && return 0

  # ELA CONTA DIVERGÊNCIA, E A `semear_estado_do_usuario` LOGO ACIMA NÃO —
  # a assimetria não estava escrita em lugar nenhum, e é esta: o que aquela
  # função toca é `$MEOW_ESTADO`, nossa própria casa; o que esta toca é o
  # `.git/config` do clone DELA. Mudança na máquina de quem instala é o que o
  # `--conferir` existe para anunciar. MEDIDO em 22/09/2026, antes do conserto:
  # num clone convergente em todo o resto e sem o driver, o `--conferir`
  # imprimia `~~ registraria merge.ours.driver` e a `etapa_cli` devolvia 0 —
  # a tela dizia "há o que fazer" e o código de saída dizia "nada a fazer".
  if meow_seco; then
    meow_muda "registraria merge.ours.driver neste clone (o .gitattributes já o declara)"
    return "$MEOW_DIVERGENTE"
  fi
  if git -C "$MEOW_RAIZ" config --local merge.ours.driver true 2>/dev/null; then
    meow_ok "driver de merge 'ours' registrado neste clone"
    return "$MEOW_DIVERGENTE"
  fi
  # Não é falha da etapa: um clone somente-leitura, ou um `.git` de que a
  # pessoa não é dona, continua instalando o resto perfeitamente. O que se
  # perde é um cinto de segurança, e dizer isso em voz alta é o conserto.
  # Também não é divergência: nada mudou, e insistir todo `--conferir` num
  # clone onde a escrita nunca vai passar seria ruído permanente.
  meow_aviso "não consegui registrar merge.ours.driver — o merge=ours do .gitattributes fica inerte neste clone"
  return 0
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

  semear_estado_do_usuario
  registrar_driver_de_merge
  rc=$?
  [ "$rc" = "1" ] && mudou=1

  # 3 AQUI É "NÃO HÁ ONDE PÔR", E ISSO NÃO É FALHA DESTA ETAPA
  #   A `instalar_completion` devolve 3 quando o diretório de completions não
  #   existe. Desde a P44 (24/09/2026) isso só acontece com um
  #   `MEOW_COMPLETIONS_DIR` apontado para um diretório que não está lá: o
  #   destino padrão, `~/.local/share/zsh/site-functions`, a função cria sozinha.
  #   Até então o padrão era `/usr/local/share/zsh/site-functions`, que numa
  #   máquina que não é esta podia simplesmente não existir — foi esse o caso
  #   medido abaixo. O `-ge 2` que estava aqui engolia esse 3 junto
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
# O ATALHO DO PAINEL — o único ícone deste projeto que abre uma janela
#
#   Tudo o mais que o instalador planta é tema, ícone de OUTRO aplicativo, applet
#   de barra ou unidade de systemd. Este é o `.desktop` do MeowSystem ele mesmo:
#   o que ela clica no lançador para abrir a página que configura as chaves do
#   `meow.conf` sem editar o arquivo. O que ele abre está em `app/`, e o porquê de
#   cada decisão está em `app/LEIA-ME.md` e no cabeçalho de `scripts/atalho.sh`.
#
# VEM LOGO DEPOIS DA `etapa_cli`, E A ORDEM É UMA DEPENDÊNCIA DE VERDADE
#   O `.desktop` aponta para `~/.local/bin/meow-painel`, uma cópia que resolve o
#   clone pelo ponteiro `~/.local/state/meowsystem/raiz` — e quem grava aquele
#   ponteiro é a `etapa_cli`, três linhas acima. Plantado antes dela, numa
#   máquina recém-formatada, o atalho nasceria apontando para um ponteiro que
#   ainda não existe: um ícone que abre e diz "não achei o repositório" na
#   primeira vez que alguém o usa.
#
#   O mesmo raciocínio da `etapa_cli` sobre COPIAR em vez de linkar vale aqui, e
#   com mais força: o clone mora num NVMe separado, e um `Exec=` apontando para
#   /mnt/Apate vira um clique que não faz nada no dia em que o disco não montar.
etapa_atalho() {
  passo "Atalho do painel de configuração"
  "$MEOW_RAIZ/scripts/atalho.sh"
  return $?
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
    # As ferramentas do `instalar_fontes.sh` (P82, 15/10/2026): ele baixa a
    # Nerd Font com o curl, num .tar.xz, e aceita .zip no «adicionar». Ele as
    # nomeava como faltando e não tinha a quem pedir.
    [curl]=curl
    [xz]=xz-utils
    [unzip]=unzip
  )
  # O Papirus não tem binário — testa-se pelo diretório do tema.
  local faltam=()
  local b
  for b in "${!NECESSARIOS[@]}"; do
    meow_tem "$b" || faltam+=("${NECESSARIOS[$b]}")
  done
  [ -d /usr/share/icons/Papirus-Dark ] || faltam+=(papirus-icon-theme)
  # A fonte da interface (Fira Sans) é do `pop-fonts`, que só existe nos
  # repositórios do Pop!_OS: fora dele, pedi-lo derrubaria o `apt-get` inteiro.
  [ -d /usr/share/fonts/opentype/fira ] || ! apt-cache show pop-fonts >/dev/null 2>&1 \
    || faltam+=(pop-fonts)

  # O NUMPY NÃO TEM BINÁRIO, E NÃO BASTA "ter python3" — 16/09/2026
  #   O `converter_icone.py` é quem faz o traçado de contorno e o
  #   Douglas-Peucker, e ele não roda sem numpy. Sem isto o
  #   `construir_convertidos.sh` se pulava inteiro com "sem numpy" e os 31
  #   ícones convertidos ficavam FORA do tema, sem o instalador dizer que
  #   faltava um pacote — porque a etapa de pacotes não sabia que ele existia.
  #
  #   E O TESTE É COM O `python3` DO PATH, de propósito. Esta máquina tem pyenv:
  #   o `python3` do shell dele tinha numpy 2.4.4 e o `/usr/bin/python3` não
  #   tinha nenhum. Quem roda os scripts é o segundo (timer, hook, subshell sem
  #   a função do pyenv), então é o segundo que tem de ser testado — e é o que
  #   um `python3 -c` dentro de um script faz naturalmente.
  python3 -I -c 'import numpy' 2>/dev/null || faltam+=(python3-numpy)

  # O compilador e as bibliotecas dos applets (mídia e leitura), quando um deles
  # está ligado: o Pop!_OS não traz nenhum deles, e sem eles o cargo para no link.
  local prova pacote
  if [ "${MIDIA:-sim}" = "sim" ] || [ "${LEITURA_APPLET:-sim}" = "sim" ]; then
    while IFS='|' read -r prova pacote; do
      [ -e "$prova" ] || faltam+=("$pacote")
    done <<< "$MEOW_DEPS_DOS_APPLETS"
  fi
  # O fastfetch não está no apt do Pop!_OS 24.04: desce do PPA do autor.
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
  [ "$ppa_fastfetch" = 1 ] && _pacotes_fastfetch
  return "$MEOW_DIVERGENTE"
}

# O fastfetch pelo PPA zhangsongcui3371/fastfetch (o do autor).
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

# ---------------------------------------------------------------------------
etapa_gerar() {
  passo "Gerar temas e ícones a partir da paleta"
  # O MASCOTE SAIU DAQUI EM 08/08/2026, E TIRÁ-LO DAQUI ERA O PONTO
  #   Ela mandou excluir os mascotes do projeto e ficar só com a Coquinha e o Mimir.
  #   Apagar os `assets/meow-*.svg` sem tirar o gerador desta etapa não resolveria
  #   nada: o `gerar_gato.py --conferir` acusaria os arquivos ausentes, o ramo de
  #   baixo os regeraria, e os mascotes voltariam ao disco na primeira rodada do
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
  # O CÓDIGO DE SAÍDA VEM DO `PIPESTATUS[0]`, E NÃO DO PIPE — 21/09/2026
  #   Estas duas linhas eram `... | sed ... || return "$MEOW_ERRO"`. Com o
  #   `pipefail` do lib/comum.sh:16, o status do pipe é o do PRIMEIRO comando
  #   que falha — mas o `||` não sabe QUAL foi, e transformava todo não-zero em
  #   2. O `gerar_tema_v1.py:441` sai 3 DE PROPÓSITO quando falta dependência, e
  #   o comentário dele (linhas 424-430) diz com todas as letras que sair 2 ali
  #   seria mentira: a tela imprimia "falhou: gerar" onde a resposta honesta era
  #   "pulado: gerar". Três linhas adiante, o `etapa_tema` já fazia certo — é
  #   daquela linha que esta cura foi copiada.
  #
  #   SÓ O 3 PASSA DIRETO, e o resto continua virando 2. Não é preciosismo: o
  #   `sys.exit("ERRO: ...")` do Python sai com código 1, e 1 aqui é
  #   `MEOW_DIVERGENTE` — devolvê-lo cru faria um erro de verdade do
  #   `gerar_temas.py` (paleta ausente, flavor desconhecido) ser contado como
  #   "mexeu". Trocar uma mentira por outra não é conserto.
  local rc_gt
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" | sed 's/^/  /'
  rc_gt="${PIPESTATUS[0]}"
  case "$rc_gt" in 0) ;; "$MEOW_SEM_DEPENDENCIA") return "$MEOW_SEM_DEPENDENCIA" ;; *) return "$MEOW_ERRO" ;; esac
  python3 "$MEOW_RAIZ/scripts/gerar_tema_v1.py" | sed 's/^/  /'
  rc_gt="${PIPESTATUS[0]}"
  case "$rc_gt" in 0) ;; "$MEOW_SEM_DEPENDENCIA") return "$MEOW_SEM_DEPENDENCIA" ;; *) return "$MEOW_ERRO" ;; esac
  # A mensagem dizia "a partir de assets/paleta/", e aquele diretório deixou de
  # ter paleta em 22/09/2026 — ele ficou só com o `cosmic-map.json`, que é do
  # motor. Quem nomeia o arquivo é o `meow_paleta_nome`, que é a mesma porta que
  # o resto do instalador usa para NOMEAR sem abrir.
  meow_ok "regenerados a partir de $(meow_paleta_nome)"
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
  # A CAPTURA MORA NO PACK DESDE 22/09/2026, e quem sabe onde é o `pack.py`.
  # Cravar o caminho aqui faria a etapa "tema" se pular calada em toda máquina
  # que usasse um pack que não o padrão — e "se pulou" é a mensagem mais cara
  # deste instalador, porque ela parece normal.
  local captura; captura="$(meow_captura "$alvo")"

  # O ACENTO SEM FOTOGRAFIA SE DERIVA — 24/09/2026, sprint P48 (achado 31)
  #   Quem escreve a captura do acento a partir da do mesmo flavor é o
  #   `derivar_acento.py`, e a etapa `gerar` (que vem antes desta) já o chama.
  #   Chamá-lo de novo aqui não é redundância: o `gerar` sai antes de chegar a
  #   ele quando o `gerar_temas.py` falha, e a etapa do tema não pode depender
  #   disso para saber se há tema. Quando já está derivada, ele só confere.
  #   E O FLAVOR SEM FOTOGRAFIA NENHUMA TAMBÉM — 25/09/2026, P59: o alucard, o
  #   frappe e o macchiato saem de outro flavor do mesmo lado, trocado slot a
  #   slot (o `derivar_flavor.py`, que o `derivar_acento.py` chama). Esta
  #   etapa não muda: a pergunta e a escrita continuam as mesmas duas linhas.
  #
  # O `TEMA_SEM_CAPTURA` É O RECADO PARA O FIM DO `main` — P59. A tela de login
  #   veste a MESMA captura (o `greeter.sh` pergunta ao `meow_captura` pelo
  #   mesmo par), e sem ela se pula antes de olhar o sudo; o rodapé mandava
  #   então «sudo -v && ./install.sh» para um pulo que não era de root. Ele diz
  #   `deriva` no ensaio, em que a captura ainda não foi escrita, e `falta` quando
  #   o par não tem tema; vazio, a captura existe. Zerado a cada passagem.
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

  # Ver o fim do `main`: é por esta variável que o instalador não termina em
  # «Pronto» quando o tema pedido não chegou ao COSMIC. Zerada a cada passagem,
  # porque cada passagem roda esta etapa de novo e só a última diz o que ficou.
  TEMA_NAO_APLICADO=""

  if [ -z "$captura" ]; then
    # Sem captura DEPOIS da derivação, o par não se deriva (um flavor sem
    # fotografia dele nem de outro do mesmo lado que se reproduza, desde a P59)
    # e o tema NÃO foi aplicado. Isso vira pendência na Início: antes a tela
    # dizia «aplicou» com o desktop na cor de antes.
    TEMA_SEM_CAPTURA="falta"
    deriva="${deriva#*não se deriva — }"
    TEMA_NAO_APLICADO="O tema do COSMIC não foi aplicado: não há captura para '$alvo' (${deriva#  })."
    meow_pendencia_acionavel tema-sem-captura "$TEMA_NAO_APLICADO"
    # O COMANDO OFERECIDO TEM DE CARREGAR A PONTE — 22/09/2026
    #   Esta linha dizia `./scripts/capturar_tema.sh $alvo`, cru. Aquele script
    #   não carrega o `lib/comum.sh` (de propósito) e pergunta direto ao
    #   `pack.py`, que só conhece `MEOW_PACK_DIR` — variável que o
    #   `meow_ponte_python` exportou AQUI DENTRO, no `main`, e que não existe no
    #   terminal dela depois. Colada no shell dela, a linha crua gravaria a foto
    #   do pack ATIVO dentro do `packs/catppuccin/` do clone, que é o defeito
    #   que o `captura-destino` nasceu para impedir. O `meow` monta a mesma
    #   ponte sozinho na entrada, e a `etapa_cli` é a terceira da lista contra a
    #   oitava desta — ele já está no PATH quando esta mensagem aparece. É o
    #   mesmo comando que o `chk_tema` e a linha do rc=4, logo abaixo, ofereciam.
    #   [P82, 15/10/2026: as três linhas da receita (importar pela GUI e rodar
    #   o `meow tema capturar`) saíram — a pendência «tema-sem-captura» de
    #   cima é o estado, na Início.]
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # `--respeitar-gui`: rodar o instalador de novo é MANUTENÇÃO, e manutenção não
  # desfaz o que ela ajustou em Aparência. Foi assim que o ajuste de vidro dela
  # das 17:59 de 05/08 morreu às 18:00:36. Ver a fronteira por árvore no
  # aplicar_tema.sh. Quem impõe a captura é o comando explícito (`meow tema X`).
  local rc
  MEOW_DRY_RUN=0 "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$alvo" --respeitar-gui --conferir >/dev/null 2>&1
  rc=$?
  # Havendo captura, a pendência de uma passagem anterior (ver acima) acabou.
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

# ---------------------------------------------------------------------------
etapa_modo() {
  passo "Modo claro/escuro"
  # [P82: o esquema é o do pacote (`meow_cosmic_v`), e não um v1 cravado.]
  local arq; arq="$(meow_cosmic_dir)/com.system76.CosmicTheme.Mode/$(meow_cosmic_v com.system76.CosmicTheme.Mode)/is_dark"
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
# Os dois mascotes e o tema de ícones saem juntos: a logo do painel é caminho de
# arquivo e o botão do dock é tema de ícones, mas os dois vêm do mesmo SVG e
# reiniciam o mesmo processo. Separá-los custaria dois piscar de painel.
# O DESENHO DELA, ANTES DE VIRAR TEMA — 01/09/2026.
#   Um SVG salvo pelo Boxy pode trazer `transform-box: fill-box` +
#   `transform-origin`, que nem o librsvg nem o resvg implementam: a peça vai
#   parar fora do viewBox e some da tela sem erro nenhum. Aconteceu com os
#   dentes que ela desenhou nos dois mascotes, e custou uma tarde para achar,
#   porque a pipeline inteira devolvia sucesso.
#
#   Vem ANTES do `etapa_icones` porque o acervo autoral do pack alimenta o tema
#   de ícones: normalizar depois seria consertar a fonte e instalar a cópia
#   quebrada. Os mascotes têm o conserto no próprio `logo.sh` (o vigia do acervo
#   dispara aquele script, não este arquivo), e este passo os cobre de novo por
#   ser barato e idempotente: numa árvore sã não escreve nada e sai 0.
#
#   O acervo de terceiro (`arcticons/`, `catppuccin/`, ~25 mil arquivos) fica de
#   fora: é arte que ninguém edita aqui, e varrê-la seria segundos por rodada
#   para conferir o que não muda.
etapa_svg() {
  passo "Desenhos (SVG normalizados)"
  meow_tem python3 || { meow_pula "python3 não está aqui"; return 0; }
  local pastas=() p
  for p in packs/meowsystem/mascote/ packs/dracula/mascote/ assets/icones/overrides; do
    [ -d "$MEOW_RAIZ/$p" ] && pastas+=("$MEOW_RAIZ/$p")
  done
  # OS AUTORAIS DE CADA PACK ENTRAM JUNTO — 22/09/2026
  #   A P27 desceu os 55 desenhos autorais de `assets/icones/autorais/` para
  #   dentro dos packs (44 no Catppuccin, 11 no Dracula, mais os 11 do alucard
  #   que nasceram nela). Sem estas linhas a etapa continuaria passando, calada,
  #   conferindo os oito de `autorais/leitura/` que sobraram — e o defeito do
  #   `transform-box` que ela existe para caçar voltaria a passar despercebido
  #   exatamente nos desenhos que ela desenha aqui.
  #
  #   POR GLOB, E NÃO POR LISTA DE NOMES: um pack de terceiro instalado em
  #   `~/.local/share/meowsystem/packs` não está nesta árvore, mas um pack que
  #   ALGUÉM adicionar a `packs/` estaria — e uma lista com "catppuccin dracula"
  #   digitado envelheceria no dia do terceiro pack.
  #
  #   SÓ `autorais/`, e é de propósito: é o único acervo de pack desenhado aqui.
  #   O `icones/mimetypes/` do Catppuccin são 3.280 arquivos de terceiro e o
  #   `icones/apps/` do Dracula é arte de upstream — os dois caem na mesma regra
  #   que o parágrafo acima já dá ao `arcticons/`: ninguém os edita aqui, e
  #   varrê-los seria segundos por rodada para conferir o que não muda.
  # P96: as pastas dos packs são planas — os desenhos do modo de leitura (`leitura-*.svg`) e os
  # autorais (`<nome>-<flavor>.svg` em `apps/`, um flavor da paleta do pack) entram arquivo a arquivo.
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
  # O normalizador é mudo quando não há nada a fazer — bom para um vigia que
  # roda a cada mexida, ruim para uma etapa de instalador, onde silêncio é
  # indistinguível de "essa etapa não rodou". A linha diz o que foi conferido.
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
# Os desenhos DELA que só existiam em PNG, de volta ao vetor. Depois do
# `etapa_icones` pelo mesmo motivo das etapas irmãs — quem declara
# `scalable/apps` no index.theme é aquele — e DEPOIS do `etapa_completar_icones`,
# que é o outro que escreve naquele diretório: assim, se um dia um nome existir
# nos dois, o resgate é o que fica, e isso é de propósito. Um `.svg` do acervo
# `resgatados/` é arte dela, e arte dela vence arte gerada, sempre — a mesma
# regra que o `completar_icones.sh` já aplica ao abrir exceção para a logo do
# Hefesto.
etapa_icones_resgatados() {
  passo "Ícones resgatados do PNG"
  ICONES_RESGATADOS="${ICONES_RESGATADOS:-sim}" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_resgatados.sh" --aplicar
  return $?
}

# A ETAPA VEM DEPOIS DA DO ARCTICONS NA LISTA, E ISSO É DE PROPÓSITO
#   As duas escrevem o ícone dos MESMOS onze aplicativos, em diretórios
#   diferentes do mesmo tema: o Arcticons no `48x48/apps`, esta no
#   `scalable/apps`. Não há disputa de arquivo — o resolvedor é que escolhe, e
#   ele prefere `scalable`. Mas a ordem importa para a CACHE: quem reindexa por
#   último é quem deixa a cache descrevendo o disco inteiro.
etapa_icones_apps_dracula() {
  passo "Pack Dracula nos aplicativos"
  ICONES_DRACULA="${ICONES_DRACULA:-sim}" \
    NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/icones_apps_dracula.sh" --aplicar
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
  # OS DESENHOS À MÃO SÃO CONSTRUÍDOS AQUI, e só eles — 08/09/2026.
  #   O acervo convertido inteiro NÃO é regerado pelo instalador: reconverter
  #   trocaria arte que ela aprovou por arte que ninguém viu. Mas uma linha
  #   `mao` não tem conversão nenhuma — é a cópia de um desenho dela —, e sem
  #   este passo um retoque que chegasse pelo git, ou de um clone novo, ficaria
  #   no repositório sem nunca virar arquivo instalável.
  #   Pedido dela: "garantir que o nosso install consiga fazer isso".
  "$MEOW_RAIZ/scripts/construir_convertidos.sh" --so-mao || true
  FLAVOR="${FLAVOR:-}" \
    ICONES_COR_MARCA="${ICONES_COR_MARCA:-nao}" \
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

# O ícone de bandeja do ZAPZAP. Etapa própria pelo mesmo motivo da da Steam: não
# escreve no tema de ícones, escreve na árvore de DEPLOY de um flatpak — e depende
# do ZapZap instalado, não do `index.theme`. Numa máquina sem ele devolve 3 e some
# do relatório.
#
# O TEMA NÃO ALCANÇA ESTE ÍCONE, E ISSO FOI REMEDIDO NO D-BUS EM 23/08/2026
#   Rodando o código de bandeja REAL do app dentro do sandbox dele e lendo o
#   `org.kde.StatusNotifierItem`: `IconName` vazio, `IconThemePath` inexistente
#   (o `QDBusTrayIcon` do Qt nem publica a propriedade) e `IconPixmap` com dois
#   rasters prontos, 22×22 e 64×64. Não há nome para o tema resolver. A saída é
#   trocar o desenho na FONTE do app, que é o que o script faz.
#
# ELE VOLTAVA SOZINHO, E ERA ISSO QUE ELA ESTAVA VENDO
#   Queixa de 23/08/2026: "ao atualizar o flatpak tipo zap zap, o tray, o icon que
#   fica no applet, voltaram aos originais". O `packs/meowsystem/icones/bandeja.map` previa a
#   regressão desde 10/08 e nada agia sobre ela. Quem repõe no EVENTO é a
#   `etapa_vigia_flatpak`, lá embaixo; esta aqui é quem põe da primeira vez.
etapa_icones_tray_zapzap() {
  passo "Ícone da bandeja do ZapZap"
  "$MEOW_RAIZ/scripts/icones_tray_zapzap.sh"
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

# O que a lista do `ocultar` nomeia e não mora em /usr/share: sombra de mesmo
# basename no home (flatpak, /usr/local) ou a marca no próprio .desktop do home.
# Sem sudo; a mesma chave liga, e desligada ela devolve o que é nosso.
etapa_ocultar_casa() {
  passo "Aplicativos ocultos fora de /usr/share"
  "$MEOW_RAIZ/scripts/ocultar_casa.sh"
  local rc=$?
  [ "$rc" = "$MEOW_SEM_DEPENDENCIA" ] && [ "${LANCADOR_SISTEMA:-nao}" != "sim" ] && PULADOS_OPTIN+=(ocultar_casa)
  return "$rc"
}

# A janela cujo app_id não casa com nenhum lançador: a ponte do assets/apps/appid.map.
etapa_janela_dock() {
  passo "Janelas que a dock casa pelo app_id"
  "$MEOW_RAIZ/scripts/appid_dock.sh" --aplicar
  return $?
}

# O lançador de programa removido vai para a quarentena, e o mimeinfo.cache do
# home se refaz. Vem depois de toda etapa que escreve .desktop no home.
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

# O gatilho que mantém as duas etapas acima de pé entre um apt e outro.
#
# O PROBLEMA QUE ELA VIU, E A CONTA DOS DIAS
#   `etapa_ocultar` e `etapa_nomes` escrevem em arquivos que vieram do apt, e o
#   próprio cabeçalho delas já dizia que "um `apt upgrade` do pacote desfaz".
#   Até 14/08/2026 o projeto parava aí: reaplicar era `meow ativar` na mão, e
#   ninguém sabia QUANDO. Medido — o `google-chrome-stable` atualizou em
#   10/08/2026 19:27 e devolveu o `.desktop` sem `NoDisplay`; ela achou os dois
#   Chrome no lançador em 14/08 de madrugada. Quatro dias.
#
# POR QUE O GATILHO É O APT, E NÃO O doctor
#   `ocultar` está em `SEM_CONSERTO` no `bin/meow` porque o conserto usa sudo e o
#   doctor nunca usa: um prompt de senha às 5h penduraria a unidade num terminal
#   que ninguém está olhando. Essa decisão continua certa e não muda aqui.
#   O apt JÁ É root — não há prompt para pendurar. É o único evento da máquina
#   que é ao mesmo tempo a CAUSA do estrago e um contexto privilegiado.
#
# E O "NENHUM HOOK DE APT" DO meow-doctor.service?
#   Continua valendo para o que ele foi escrito: nada de um segundo REPARADOR
#   COMPLETO no mesmo evento do Aurora. Isto não é reparador — é um script, um
#   diretório (`/usr/share/applications`), sem tema, sem ícone, sem reiniciar
#   painel e sem notificação. Sem sobreposição não há aviso contraditório na tela
#   dela, que era o medo registrado lá. O cabeçalho da unidade foi emendado para
#   dizer isso, em vez de ficar contradizendo o repositório.
#
# DESLIGAR TEM DE DESLIGAR — mesma disciplina da `etapa_autoreparo`
#   Se `LANCADOR_SISTEMA` voltar para "nao", deixar de instalar não basta: o hook
#   de uma execução anterior continuaria reaplicando `NoDisplay` depois de todo
#   apt, e ela veria o lançador obedecer a uma chave que já desligou.
# ============================================================================
# A PONTE ROOT — A SENHA UMA VEZ, E NUNCA MAIS — 08/09/2026
# ============================================================================
# Ela, olhando três itens do doctor que se recusavam a consertar: *"não
# conseguimos de alguma forma usar sudo só na instalar e criar um perfil naquele
# conf.d ... aquele que só preciso uma vez e fica lá registrado pra sempre? pode
# alterar o nosso install pra garantir o máximo de conforto pro user nesse
# sentido?"*
#
# Esta etapa instala DUAS coisas e é a única do projeto que escreve em
# `/etc/sudoers.d`:
#   /usr/local/lib/meowsystem/ponte_root.sh   o braço root, verbos fechados
#   /usr/local/lib/meowsystem/perfil          raiz, usuária e lar — só root grava
#   /etc/sudoers.d/49-meowsystem-ponte        libera os verbos DELA, sem senha
#   /usr/local/lib/meowsystem/reserva/        cópia das duas, 0700, para o reparo
#   /etc/systemd/system/meowsystem-ponte-reparo.service   o reparo, sem argumento
#   /etc/polkit-1/rules.d/49-meowsystem-ponte-reparo.rules o `start` dele, sem senha
#
# O desenho, e por que não é `NOPASSWD` nos comandos que o projeto usa, está no
# cabeçalho de `scripts/ponte_root.sh`. Em uma linha: não existe regra estreita
# para `install`, então quem tem de ser estreito é um programa nosso.
#
# ELA VEM CEDO NA LISTA, e isso não é arrumação: as etapas `ocultar`, `nomes`,
# `absolutos`, `greeter` e `lancador_apt` PERGUNTAM pela ponte. Instalada depois
# delas, a primeira passagem inteira cairia no caminho antigo e só a segunda
# usaria a ponte — convergência em quatro passagens em vez de três, sem motivo.
#
# `visudo -c` ANTES DE MOVER, E ISSO NÃO É ZELO: um arquivo inválido em
# `/etc/sudoers.d` derruba o `sudo` da máquina INTEIRA, para todo mundo, e o
# conserto pede um root que já não se consegue. O arquivo é escrito num
# temporário, conferido ali, e só então instalado.
etapa_ponte_root() {
  passo "Ponte root (a senha uma vez)"
  local ponte=/usr/local/lib/meowsystem/ponte_root.sh
  local perfil=/usr/local/lib/meowsystem/perfil
  local regra=/etc/sudoers.d/49-meowsystem-ponte
  local origem="$MEOW_RAIZ/scripts/ponte_root.sh"
  # A reserva é a cópia que o reparo sem senha repõe; o sha256 fica fora dela,
  # legível, para a etapa e o doctor conferirem sem elevar nada.
  local reserva=/usr/local/lib/meowsystem/reserva
  local somas=/usr/local/lib/meowsystem/reserva.sha256
  local reparo=/usr/local/lib/meowsystem/reparar_ponte.sh
  local unidade=/etc/systemd/system/meowsystem-ponte-reparo.service
  local reparo_origem="$MEOW_RAIZ/scripts/reparar_ponte.sh"
  local unidade_origem="$MEOW_RAIZ/assets/ponte/meowsystem-ponte-reparo.service"
  local polkit=/etc/polkit-1/rules.d/49-meowsystem-ponte-reparo.rules
  local polkit_origem="$MEOW_RAIZ/assets/ponte/49-meowsystem-ponte-reparo.rules"

  # --- desligada: a etapa DESFAZ, e desfazer tem de ser de graça -------------
  if [ "${PONTE_ROOT:-sim}" != "sim" ]; then
    if [ ! -e "$ponte" ] && [ ! -e "$regra" ] && [ ! -e "$unidade" ]; then
      meow_pula 'PONTE_ROOT="nao" — sem braço root; o sudo volta a ser pedido no terminal'
      return "$MEOW_OK"
    fi
    if meow_seco; then meow_muda "removeria $regra e $ponte"; return "$MEOW_DIVERGENTE"; fi
    # A REGRA SAI PRIMEIRO. Na ordem inversa sobraria uma janela com a regra
    # apontando para um arquivo que não existe — inofensiva para o sudo, e
    # exatamente o estado que o `meow doctor` chama de meia-instalação.
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
  for f in "$origem" "$reparo_origem" "$unidade_origem" "$polkit_origem"; do
    [ -f "$f" ] || { meow_erro "falta $f — repositório incompleto"; return "$MEOW_ERRO"; }
  done

  local perfil_quer regra_quer somas_quer
  perfil_quer="$(printf 'raiz=%s\nusuaria=%s\nlar=%s\n' "$MEOW_RAIZ" "$(id -un)" "$HOME")"

  # Comparar por CONTEÚDO (regra 5). A regra de sudo é gerada pela PRÓPRIA
  # ponte — `regra-sudo` —, então o texto nunca diverge do programa que ele
  # descreve; e é gerada a partir da ORIGEM, não da instalada, para que uma
  # ponte velha no disco não valide a si mesma.
  regra_quer="$(SUDO_USER="$(id -un)" bash "$origem" regra-sudo 2>/dev/null)" \
    || { meow_erro "a ponte não soube gerar a própria regra"; return "$MEOW_ERRO"; }

  # A COMPARAÇÃO NÃO PODE PRECISAR DE SUDO, e isso é o que estava errado até
  # 08/09/2026: ela usava `sudo -n cat` nos dois arquivos, e `cat` não está na
  # regra da ponte. Com o cache do sudo frio as duas leituras voltavam vazias, a
  # etapa concluía "diverge" e pedia a senha numa máquina já pronta — inclusive
  # quando quem a rodava era o painel, que não tem terminal para responder.
  #
  #   ponte   é 0755: `cmp` direto
  #   perfil  é 0644 de propósito — não guarda segredo, e ser legível é o que
  #           permite esta conferência sem elevar nada
  #   regra   é 0440 root:root, e essa ela não lê. Quem responde é a PRÓPRIA
  #           ponte, pelo `estado`, que devolve o md5 do arquivo — e o `estado`
  #           está na regra, então não pede senha.
  local mudou=0 md5_quer md5_tem
  cmp -s "$origem" "$ponte" 2>/dev/null || mudou=1
  # `$( )` come o `\n` final dos DOIS lados, então comparar assim é comparar o
  # mesmo texto — e não há divergência eterna por causa de uma quebra de linha.
  [ "$(cat "$perfil" 2>/dev/null)" = "$perfil_quer" ] || mudou=1
  md5_quer="$(printf '%s\n' "$regra_quer" | md5sum | cut -d' ' -f1)"
  md5_tem="$(sudo -n "$ponte" estado 2>/dev/null | sed -n 's/^regra_md5=//p')"
  [ -n "$md5_tem" ] && [ "$md5_tem" = "$md5_quer" ] || mudou=1
  somas_quer="$(printf '%s  ponte_root.sh\n%s  49-meowsystem-ponte' \
    "$(sha256sum < "$origem" | cut -d' ' -f1)" \
    "$(printf '%s\n' "$regra_quer" | sha256sum | cut -d' ' -f1)")"
  [ -d "$reserva" ] && [ "$(cat "$somas" 2>/dev/null)" = "$somas_quer" ] || mudou=1
  cmp -s "$reparo_origem" "$reparo" 2>/dev/null || mudou=1
  cmp -s "$unidade_origem" "$unidade" 2>/dev/null || mudou=1
  # A pasta das regras do polkit é 0750 root:polkitd: sem ler, a etapa não
  # adivinha, e a regra vai junto com o resto quando algo muda.
  if [ -r "${polkit%/*}" ]; then cmp -s "$polkit_origem" "$polkit" 2>/dev/null || mudou=1; fi

  if [ "$mudou" = "0" ]; then
    meow_ok "ponte root instalada e liberada sem senha"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "instalaria a ponte root e a regra de sudo (a senha é pedida uma vez)"
    return "$MEOW_DIVERGENTE"
  fi

  # A SENHA É PEDIDA AQUI, E SÓ AQUI. `sudo -v` cai no prompt quando há
  # terminal; sem terminal (o painel, um timer) não há como perguntar, e a
  # etapa diz isso em vez de falhar calada.
  if ! sudo -n true 2>/dev/null; then
    if [ -t 0 ]; then
      meow_info "esta é a única senha do MeowSystem: ela instala o braço root e"
      meow_info "  a regra que dispensa a senha daqui em diante."
      sudo -v || { meow_aviso "sem sudo — a ponte fica de fora, e o resto vai"; return "$MEOW_SEM_DEPENDENCIA"; }
    else
      meow_aviso "sem terminal para pedir a senha — a ponte fica de fora"
      # [16/10/2026, QA final da leva H: era «rode uma vez no terminal:
      #  ./install.sh», visto no painel ao trocar de pack. Diz o estado; a
      #  pendência `instalar-com-root` do rodapé leva ao «Instalar tudo».]
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
  # COM o `\n` final: a substituição de comando que montou `$perfil_quer` comeu
  # o dele, e um arquivo sem quebra na última linha faz o `while read` da ponte
  # descartar justamente essa linha. Custou o `lar` em 08/09/2026.
  printf '%s\n' "$perfil_quer" > "$tmp"
  sudo install -m 644 -o root -g root "$tmp" "$perfil" \
    || { rm -f "$tmp"; meow_erro "não consegui gravar $perfil"; return "$MEOW_ERRO"; }

  # --- a regra, conferida ANTES de entrar em /etc ---------------------------
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

  # O sha256 entra por último: uma reserva pela metade nunca confere.
  if ! { sudo install -d -m 700 -o root -g root "$reserva" &&
         sudo install -m 755 -o root -g root "$origem" "$reserva/ponte_root.sh" &&
         sudo install -m 440 -o root -g root "$tmp" "$reserva/49-meowsystem-ponte" &&
         chmod 600 "$tmp" && printf '%s\n' "$somas_quer" > "$tmp" &&
         sudo install -m 644 -o root -g root "$tmp" "$somas"; }; then
    rm -f "$tmp"; meow_erro "não consegui guardar a reserva da ponte"; return "$MEOW_ERRO"
  fi
  rm -f "$tmp"

  # O reparo sem senha: um oneshot do sistema que repõe a ponte e a regra da
  # reserva (ver o cabeçalho de scripts/reparar_ponte.sh).
  if ! { sudo install -m 755 -o root -g root "$reparo_origem" "$reparo" &&
         sudo install -m 644 -o root -g root "$unidade_origem" "$unidade" &&
         sudo install -m 644 -o root -g root "$polkit_origem" "$polkit" &&
         sudo systemctl daemon-reload; }; then
    meow_erro "não consegui instalar o reparo da ponte"; return "$MEOW_ERRO"
  fi
  # Reserva nova, veredito novo: o doctor lê o porquê da última rodada do reparo.
  sudo systemctl reset-failed meowsystem-ponte-reparo.service 2>/dev/null || true

  # A PROVA É USAR. Instalar e dizer "pronto" seria afirmar uma liberação que
  # ninguém exerceu — e o modo de falha silencioso deste projeto é exatamente
  # esse. `sudo -n` só passa se a regra estiver valendo de verdade.
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
      # REMOVER PEDE DECISÃO ESCRITA, E NÃO CHAVE AUSENTE — 08/09/2026
      #   `${LANCADOR_SISTEMA:-nao}` responde a mesma coisa para "ela escreveu
      #   nao" e para "não há meow.conf nenhum". Ler assim para NÃO MEXER é
      #   certo; para APAGAR um arquivo de /etc, não — isso é agir por omissão.
      #
      #   Enquanto o `sudo` falhava calado sem terminal, o defeito era invisível.
      #   Com a ponte root o caminho passou a funcionar, e o
      #   `tests/convergencia.sh` — que roda isto num HOME de brinquedo, sem
      #   chave nenhuma — apagou o `99-meow-lancador` da máquina de verdade.
      #
      #   Agora a remoção exige a chave escrita "nao" no arquivo dela. Sem
      #   arquivo, ou sem a chave, o hook FICA e a etapa diz por quê: um hook a
      #   mais é reversível; um hook a menos é o lançador parando de se reaplicar
      #   depois de todo apt, calado.
      if ! meow_conf_diz LANCADOR_SISTEMA nao; then
        meow_aviso "o hook de apt existe e o meow.conf não diz LANCADOR_SISTEMA=\"nao\" — deixo como está"
        # O CARTÃO SAI DO `--onde` — 24/09/2026, P57 (a classe do achado 47).
        local onde; onde="$(meow_onde_no_painel LANCADOR_SISTEMA)"
        meow_info "  para removê-lo, escreva a chave${onde:+ (pelo painel, em $onde)}"
        return "$MEOW_SEM_DEPENDENCIA"
      fi
      if meow_seco; then
        meow_muda "removeria $hook (LANCADOR_SISTEMA=\"${LANCADOR_SISTEMA:-}\")"
        return "$MEOW_DIVERGENTE"
      fi
      # A PONTE PRIMEIRO — sem senha, e é ela que faz isto funcionar quando
      # quem chama é o painel ou o auto-reparo, que não têm terminal.
      meow_ponte apt-hook-remover >/dev/null 2>&1 || sudo rm -f "$hook" "$wrapper" 2>/dev/null
      # DIZER "REMOVIDO" SEM TER REMOVIDO É O QUE QUEBRAVA A CONVERGÊNCIA
      #   O `sudo` acima engole o erro em `2>/dev/null`, e sem sudo (num teste
      #   com `env -i`, ou numa sessão sem tty) ele falha e o arquivo continua
      #   em /etc. Reportar `DIVERGENTE` ali é afirmar uma escrita que não
      #   aconteceu: `tests/convergencia.sh` acusava "mexeu: lancador_apt" na
      #   terceira passagem, para sempre, e o defeito era a mensagem, não a
      #   etapa. Medido em 24/08/2026; nasceu com o hook, em 14/08.
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

  # A substituição é o que amarra o wrapper a ESTA máquina: o caminho do clone e
  # o nome de quem é dona do estado. Ver o cabeçalho do próprio wrapper para o
  # porquê de não ser um especificador como o `%h` das unidades.
  local texto
  texto="$(sed -e "s|@ACERVO@|$MEOW_RAIZ|g" \
               -e "s|@USUARIA@|$(id -un)|g" \
               -e "s|@LAR@|$HOME|g" "$origem_wrapper")"

  # Comparar por CONTEÚDO, não por existência (regra 5). Sem isto, todo
  # `install.sh` reescreveria os dois arquivos e o passo nunca seria no-op.
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

  # PELA PONTE, QUANDO ELA EXISTE — e é o caso normal desde 08/09/2026. Ela
  # preenche o mesmo molde com os mesmos três valores (do `perfil`, gravado por
  # root), então o conteúdo que sai daqui e o que sai dela são o mesmo, e a
  # comparação por conteúdo acima continua convergindo.
  if meow_ponte apt-hook-instalar >/dev/null 2>&1; then
    meow_muda "hook de apt instalado pela ponte — o lançador se reaplica sozinho após cada apt"
    return "$MEOW_DIVERGENTE"
  fi

  if [ ! -w /etc/apt/apt.conf.d ] && ! sudo -n true 2>/dev/null; then
    meow_aviso "sem sudo para instalar o hook de apt do lançador"
    # [16/10/2026, QA final da leva H: era «rode 'meow ativar' com sudo
    #  disponível», visto no painel ao trocar de pack. Diz o estado.]
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

  # O hook vai por último: enquanto ele não existe, nada chama o wrapper. Na
  # ordem inversa haveria uma janela — curta, mas real — em que um apt disparado
  # nesse instante chamaria um caminho que ainda não existe.
  if ! sudo install -m 644 -o root -g root "$origem_hook" "$hook" 2>/dev/null; then
    meow_erro "não consegui instalar $hook"; return "$MEOW_ERRO"
  fi

  meow_muda "hook de apt instalado — o lançador se reaplica sozinho após cada apt"
  return "$MEOW_DIVERGENTE"
}

# O PONTEIRO, e ele exige DUAS alavancas porque são dois programas desenhando
# cursor nesta tela. Medido em 25/08/2026:
#
#   - `strings /usr/bin/cosmic-comp | grep -c cursor-theme` -> 0. O compositor
#     NÃO lê o gsettings para cursor; ele usa a crate `xcursor` com
#     `XCURSOR_THEME`, que está VAZIA no ambiente dele — e então cai no tema
#     `default`, que hoje herda o Adwaita de corpo preto.
#   - quem lê `org.gnome.desktop.interface cursor-theme` é a libgtk, ou seja,
#     só as janelas GTK.
#
# Por isso o script escreve o gsettings (janelas GTK, vale na hora) E o
# `~/.icons/default/index.theme` (o compositor, vale no próximo login). Escrever
# só um deixa metade da tela com o cursor velho, que é pior que não mexer.
#
# A FRONTEIRA FOI MEDIDA, NÃO SUPOSTA: todo `gsettings set` vivo do Ritual da
# Aurora mira `org.gnome.desktop.wm.preferences` (o `button-layout`), nunca
# `desktop.interface`. A única menção a `cursor-theme` no repositório dela está
# num comando manual de restauração que nem dispara nesta máquina. Detalhe com
# as quatro medições no cabeçalho de `scripts/cursor.sh` e em docs/FRONTEIRA.md.
etapa_cursor() {
  passo "Cursor"
  CURSOR="${CURSOR:-}" CURSOR_VERSAO="${CURSOR_VERSAO:-v2.0.0}" \
    "$MEOW_RAIZ/scripts/cursor.sh" aplicar
  return $?
}

# Os apps Flatpak não leem o tema do COSMIC: o override do usuário aponta para o
# tema de ícones, o cursor e o GTK de cima. O global do sistema com tema perdido
# só sai pela ponte root; sem ela, a etapa se pula como as do `/usr/share`.
etapa_flatpak_tema() {
  passo "Flatpak veste o tema"
  CURSOR="${CURSOR:-}" NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/flatpak_tema.sh" aplicar
  return $?
}

# O escritório é o OnlyOffice: ele vem do Flathub do usuário quando falta, e só
# então o apt tira o LibreOffice pela ponte root (a senha única do install). Vai
# antes da etapa dos apps, que veste o OnlyOffice com o tema do pack.
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

# O PROMPT.
#
#   O `prompt.sh instalar` baixa o starship para ~/.local/bin quando falta (salvo
#   a recusa gravada) e põe o preset nosso em `~/.config/starship.toml`; quem o
#   liga é o bloco do terminal. Sai 0, 1, 2 ou 3; o 3 (recusado) cai no
#   "pulado" do `concluir` acima.
#
#   ATÉ 24/09/2026 (P39) a outra metade saía como `assets/prompt/aurora.patch`,
#   para o `env.zsh` do Spellbook, e a etapa devolvia 4 quando o nosso lado
#   estava certo e o de lá não. O patch e o 4 saíram juntos: eram a máquina de
#   uma pessoa, e não o produto.
#
# O QUE A MEDIÇÃO DERRUBOU, E FICA COMO HISTÓRIA (é do tempo do patch): a Sprint
# R dizia que a causa era `ZSH_THEME="agnoster"` na linha 9 do `env.zsh`. O
# agnoster era carregado pelo oh-my-zsh na linha 26 e **jogado fora na linha
# 135**, por um `export PS1` que vinha depois no mesmo arquivo. Mexer só na
# linha 9 não mudaria um pixel — o patch mexia nas duas, e o `else` dele
# devolvia exatamente o PS1 de então quando o starship não estava no PATH.
etapa_prompt() {
  passo "Prompt do terminal (starship)"
  PROMPT_STARSHIP="${PROMPT_STARSHIP:-sim}" \
    "$MEOW_RAIZ/scripts/prompt.sh" instalar
  return $?
}

# AS CORES DO FZF, e a etapa nasceu da regra de 23/09 — 24/09/2026 (P44).
#   Eram hex cravados no `env.zsh` do Spellbook, e em DUAS paletas: o
#   `FZF_DEFAULT_OPTS` em Catppuccin e o fzf-tab em Dracula, na mesma máquina.
#   Agora saem da paleta do pack no ar, para `~/.config/meowsystem/fzf.sh`, e a
#   linha que carrega o arquivo é do shell de quem usa — o mesmo desenho do
#   starship logo acima. O mapa de papéis e a medição estão em `scripts/fzf.sh`.
etapa_fzf() {
  passo "Cores do fzf"
  FLAVOR="$FLAVOR" ACCENT="$ACCENT" "$MEOW_RAIZ/scripts/fzf.sh" aplicar
  return $?
}

# O TERMINAL, a última peça da tela que continuava de fábrica. Escreve QUATRO
# arquivos em `com.system76.CosmicTerm/v1` — os dois mapas de esquema e as duas
# chaves que os SELECIONAM. Um esquema instalado e não selecionado não muda um
# pixel, e esse era o modo de falha mais provável desta sprint.
#
# NÃO ENCOSTA em `font_name`, `font_size` nem `opacity`: são escolha dela, e o
# `opacity: 96` já está no ponto. Vale sem reiniciar nada — o cosmic-term mantém
# um watch de inotify no próprio diretório de config (medido em
# `/proc/<pid>/fdinfo` em 25/08/2026).
#
# O QUE A MEDIÇÃO DERRUBOU: a sprint dizia que, se a importação da GUI caísse
# neste arquivo, bastaria escrever o `.ron` do port oficial direto. As duas
# coisas são verdade e não se implicam — o arquivo do port é o MIOLO de uma
# entrada, e o de config é o MAPA inteiro (`BTreeMap<ColorSchemeId, ColorScheme>`).
# Escrever o port cru falha com `Expected opening '{'`. Por isso o esquema é
# derivado da paleta DO PACK ATIVO (`meow_paleta`), e confere campo a campo com
# o port nos quatro flavors.
etapa_terminal() {
  passo "Cores do terminal"
  FLAVOR="$FLAVOR" ACCENT="$ACCENT" \
    TERMINAL_ESQUEMA="${TERMINAL_ESQUEMA:-sim}" \
    TERMINAL_CURSOR="${TERMINAL_CURSOR:-accent}" \
    "$MEOW_RAIZ/scripts/terminal.sh" aplicar
  return $?
}

# O cartão de visita do terminal: a Coquinha em ANSI no lugar do logo do Pop!_OS.
#
# ESTA ETAPA NÃO TERMINA O SERVIÇO, E É DE PROPÓSITO. O desenho é nosso e mora em
# `~/.local/share/meowsystem/fastfetch/`; a CHAVE que o faz aparecer é
# `logo.source`, em `~/.config/fastfetch/config.jsonc` — symlink para
# `~/.config/zsh`, território da Aurora. O script gera, CONFERE e imprime o
# patch; nunca escreve lá. Por isso pode devolver 4, e o `concluir` já lê 4 como
# "pulado" — sem contar falha e sem virar notificação diária.
# (O parágrafo acima é de 25/08. Desde 01/09 a escrita das chaves é cirúrgica,
# e desde 24/09/2026 (P44) o `~/.config/fastfetch` é diretório do MeowSystem: o
# script troca o symlink por um diretório de verdade, com o mesmo conteúdo e
# backup — ver o topo do `scripts/fastfetch_logo.sh`.)
#
# ANSI, e não sixel/kitty, porque foi MEDIDO ao vivo em 25/08/2026: a DA1 do
# cosmic-term responde `\e[?6c` (sem o `;4` do sixel) e a query kitty volta
# vazia. O VTE dele é o `alacritty_terminal`, que nunca implementou nenhum dos
# dois. Não é preferência: é o único caminho.
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

# O bloco do MeowSystem no arquivo de início do terminal: prompt, cores do fzf,
# mascote do fastfetch e completion. Depois das três etapas que ele carrega.
etapa_bloco_terminal() {
  passo "Bloco do terminal"
  "$MEOW_RAIZ/scripts/terminal_bloco.sh" aplicar
}

# OS DOIS ITENS DE PAPEL DE PAREDE NO MENU DE CONTEXTO DA ÁREA DE TRABALHO
#
#   Pedido dela em 01/09/2026. O menu é do `cosmic-files` — mais precisamente do
#   `cosmic-files-applet`, que é quem entra em `Mode::Desktop` —, e não há
#   sistema de plugin: os itens só existem patchando o fonte e recompilando.
#
#   ESTA ETAPA NUNCA COMPILA. Ela instala o artefato da versão instalada, se
#   houver, e some do caminho se não houver — o porquê inteiro está no cabeçalho
#   de `scripts/files_menu.sh`, item 3. O build é `meow files-menu build`, ou o
#   auto-build que a própria etapa dispara em background.
etapa_files_menu() {
  passo "Papel de parede no menu de contexto"
  FILES_MENU="${FILES_MENU:-sim}" FILES_MENU_AUTOBUILD="${FILES_MENU_AUTOBUILD:-sim}" \
    "$MEOW_RAIZ/scripts/files_menu.sh" aplicar
  return $?
}

# O vidro fosco que continuava ao maximizar e se perdeu. Duas chaves, e o painel
# vigia os dois diretórios por inotify — então isto vale sem reiniciar nada.
#
# A OPACIDADE NÃO É MAIS IMPOSTA AQUI (17/08/2026). O `opacity` é a chave que o
# slider "Opacidade do fundo" da GUI escreve; escrevê-la nesta etapa (e no
# `meow doctor`, todo dia) desfazia a escolha dela em silêncio. Sem valor no
# meow.conf, esta etapa cuida só do `keep_style_on_maximize`, que a GUI não tem.
# As três chaves de opacidade são repassadas para o caso de ela querer impor um
# valor de novo — antes elas morriam neste shell, sem exportar.
etapa_vidro() {
  passo "Vidro ao maximizar"
  VIDRO_AO_MAXIMIZAR="${VIDRO_AO_MAXIMIZAR:-sim}" \
    VIDRO_OPACIDADE="${VIDRO_OPACIDADE:-}" \
    VIDRO_OPACIDADE_PAINEL="${VIDRO_OPACIDADE_PAINEL:-}" \
    VIDRO_OPACIDADE_DOCK="${VIDRO_OPACIDADE_DOCK:-}" \
    "$MEOW_RAIZ/scripts/vidro.sh"
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
# O TAMANHO DE TUDO NA TELA — que é a única alavanca de fonte que o COSMIC tem.
#
# Ela pediu "aumentar o tamanho universal das fontes do pc" em 17/08/2026. Não
# existe chave de tamanho de fonte no COSMIC: o `default_text_size` da libcosmic
# é 14.0 constante no código, `interface_density` só mexe em espaçamento e
# `COSMIC_SCALE` não alcança o painel. A escala da saída é o que resta, e é o
# que a GUI chama de Ajustes → Telas → Escala. O porquê inteiro, com as
# medições, está no cabeçalho do script.
#
# NÃO ENTRA NO `meow doctor`, de propósito: é controle dela na GUI, e reimpor
# todo dia é o defeito que o `vidro.sh` corrigiu no mesmo dia. Aqui só o
# install, e só quando `ESCALA_TELA` tem valor.
etapa_escala() {
  passo "Escala da tela"
  ESCALA_TELA="${ESCALA_TELA:-}" "$MEOW_RAIZ/scripts/escala.sh"
  return $?
}

# O SUPERVISOR DA BARRA — logo depois da forma, porque é o mesmo assunto:
# a `forma.sh` decide como a barra é, esta garante que ela CONTINUE lá.
#
# POR QUE ISTO PRECISOU EXISTIR (26/08/2026)
#   O `cosmic-session` respawna o painel com backoff `2^restarts x sorteio(0..9)`
#   ms, sem teto, e o contador nunca zera por sucesso. Nesta máquina ele chegou a
#   16h18min de espera — ou seja, qualquer morte do painel deixava a Vitória sem
#   topbar e sem dock até o próximo login. Era isso que a fazia apertar Alt+F2
#   cada vez mais.
#
# ANDA DE CARONA NO `AUTO_REPARO`, como o carrossel: quem desliga o auto-reparo
# está dizendo "não mexa sozinho na minha máquina", e repor processo é mexer.
etapa_painel() {
  passo "Supervisor da barra (systemd --user)"
  local destino="$HOME/.config/systemd/user" u conteudo mudou=0
  local unidades=(meow-painel.service meow-painel-raio.path meow-painel-raio.service)

  # O clamp do raio vale mesmo sem systemd: é o que impede a barra de sumir.
  "$MEOW_RAIZ/scripts/painel.sh" conferir
  local rc=$?
  [ "$rc" = "2" ] && return "$MEOW_ERRO"

  if [ "${AUTO_REPARO:-sim}" != "sim" ]; then
    if meow_unidade_sobrou "${unidades[@]}"; then
      # A chave abre a frase nos DOIS lados (o real, sete linhas abaixo, já
      # abria): ela lê o seco e o real em sequência, e a primeira palavra é o
      # que ela procura — o motivo, não o verbo.
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
    # UM `--` NA TELA QUE O RESUMO ARQUIVAVA EM `confere:` (31/08/2026)
    #   O `rc` aqui é o do `painel.sh conferir`, e nesta máquina ele devolve 0
    #   SEMPRE — o cosmic-comp em execução clampa o raio, então o script sai por
    #   cima sem escrever nada (medido: `MEOW_DRY_RUN=1 scripts/painel.sh
    #   conferir` -> `ok o cosmic-comp em execução clampa o raio`, rc=0). É a
    #   mesma constatação do comentário logo abaixo, na parte que escreve.
    #   Devolver esse 0 punha a etapa em `confere:` — "já estava certo, nada
    #   escrito" — de uma etapa que acabou de imprimir `--`. O argumento inteiro
    #   está escrito no ramo gêmeo do `etapa_leitura` (o do portão do
    #   `AUTO_REPARO`), e não se repete aqui; o `concluir()` põe o 3 em
    #   `pulados:`, nunca em `falhou:`.
    #   O 1 continua vencendo o 3: aí o `conferir` ESCREVEU o raio de verdade
    #   (é a máquina sem o patch do compositor), e engolir isso trocaria um
    #   defeito de relatório por outro.
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
    # P76: o vigia do raio olha o esquema que o pacote traz hoje, não um `v1`
    # cravado (ver o cabeçalho de `systemd/meow-painel-raio.path`).
    conteudo="${conteudo//@V_PANEL@/$(meow_cosmic_v com.system76.CosmicPanel.Panel)}"
    conteudo="${conteudo//@V_DOCK@/$(meow_cosmic_v com.system76.CosmicPanel.Dock)}"
    meow_escrever "$destino/$u" "$conteudo" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac
  done

  # O SECO TAMBÉM TEM DE ENXERGAR O SUPERVISOR SOLTO, E NÃO ENXERGAVA (31/08/2026)
  #   Medido num HOME falso com as TRÊS unidades no disco iguais às do repositório
  #   e as duas que se armam soltas (a terceira, `meow-painel-raio.service`, é
  #   `static` — quem a puxa é o `.path`, e ela nunca aparece nesta conta):
  #       rc(seco)=0    <- nem uma linha na tela
  #       rc(real)=1    ~~ supervisor da barra armado (meow-painel.service)
  #                     ~~ supervisor da barra armado (meow-painel-raio.path)
  #   Ou seja: a auditoria escondia a única coisa que ia mudar, e justo a que
  #   importa — sem o `.service` armado a barra morre e ninguém a repõe, que é o
  #   defeito inteiro que esta etapa existe para tapar. `is-enabled` e `is-active`
  #   são leitura pura, então o `tests/seco.sh` continua verde com elas aqui.
  #   Mesmo buraco, mesma cura do `etapa_leitura` e do `etapa_autoreparo`.
  if meow_seco; then
    # Lista em UMA string, e não num array, por um motivo bobo e concreto: o
    # `etapa_leitura` e o `etapa_autoreparo` usam `armaria` como 0/1, e o linter
    # resolve nome sem olhar escopo de função — declarar `armaria=()` aqui fazia
    # o SC2178/SC2128 cair nas DUAS irmãs, que não mudaram uma linha. Oito avisos
    # novos por causa de uma variável local.
    local armaria=""
    for u in meow-painel.service meow-painel-raio.path; do
      if [ "$(systemctl --user is-enabled "$u" 2>/dev/null)" != "enabled" ] ||
         [ "$(systemctl --user is-active  "$u" 2>/dev/null)" != "active" ]; then
        armaria="${armaria:+$armaria }$u"
      fi
    done
    # Duas divergências DIFERENTES, duas linhas: juntá-las num `mudou` só faria a
    # auditoria dizer "instalaria o supervisor" numa máquina onde as unidades já
    # estão no disco e só falta armá-las — e a frase mandaria procurar o defeito
    # no lugar errado. E o nome da unidade vai junto porque o `.service` e o
    # `.path` falham por motivos diferentes (ver a dupla logo abaixo).
    [ "$mudou" = "1" ] && meow_muda "instalaria/atualizaria as unidades do supervisor da barra"
    [ -n "$armaria" ] && meow_muda "armaria o supervisor da barra ($armaria)"
    { [ "$mudou" = "1" ] || [ -n "$armaria" ]; } && return "$MEOW_DIVERGENTE"
    return "$rc"
  fi

  # ESCREVEU = `mexeu`, E O `rc` DO `painel.sh` NÃO SABE DISSO
  #   Medido em 31/08/2026: com as duas unidades já armadas e as do repositório
  #   divergindo das do disco (é o que um `git pull` produz), a etapa reescrevia
  #   as TRÊS, chamava `daemon-reload` e devolvia o `rc` do `painel.sh conferir`
  #   — 0 —, que o `concluir()` arquiva em `confere: … nada escrito`. E nesta
  #   máquina o `conferir` devolve 0 SEMPRE: o cosmic-comp em execução clampa o
  #   raio, então ele não tem o que escrever e sai por cima. Resultado: o
  #   instalador recarregava o systemd dela e relatava que não tinha escrito
  #   nada. É a separação 0/1 que o cabeçalho do `concluir()` existe para
  #   defender, e o `etapa_autoreparo` já a respeita com este mesmo `mudou`.
  if [ "$mudou" = "1" ]; then
    systemctl --user daemon-reload
    rc=1
  fi

  # O `.service` e o `.path` são uma dupla: o primeiro repõe a barra quando ela
  # cai, o segundo clampa o raio quando a geometria muda. Nenhum substitui o
  # outro.
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
  # A LISTA DE `export` QUE MORAVA AQUI ERA A ARMADILHA Nº 3, E JÁ TINHA COBRADO
  #   Eram 12 nomes `FORMA_*` digitados à mão. O `scripts/forma.sh` passou a ler
  #   18 — entraram `FORMA_ALA_INICIAL_*`, `FORMA_ALA_FINAL_*` e `FORMA_CENTRO_*`
  #   para painel e dock — e as seis novas chegavam VAZIAS aqui, com o efeito
  #   clássico: `meow doctor` aplicava o tamanho da bandeja e o `./install.sh`
  #   dizia "confere" sem aplicar nada. Numa máquina nova a bandeja nunca
  #   encolhia, e nenhum erro aparecia em lugar nenhum.
  #   Agora o `etapa_conf`/`etapa_conf_ler` faz `set -a` em volta do `.`, então
  #   TODA chave do meow.conf já sai exportada e chave nova nasce valendo — sem
  #   lista para alguém esquecer de atualizar.
  "$MEOW_RAIZ/scripts/forma.sh"
  return $?
}

# O LADO A LADO, logo depois da forma das barras porque é o mesmo assunto um
# nível acima: a `forma.sh` decide o formato das barras, esta decide como as
# JANELAS se arrumam no espaço que sobra.
#
# Não há `export` de lista aqui, e isso é de propósito — ver a armadilha nº 3
# comentada no `etapa_forma` logo acima: o `etapa_conf` faz `set -a` em volta do
# `.`, então toda chave do meow.conf já chega exportada e chave nova nasce
# valendo. `JANELAS_TILING` e `JANELAS_TILING_ESCOPO` entram de graça.
etapa_janelas() {
  passo "Janelas lado a lado (o layout dwindle)"
  "$MEOW_RAIZ/scripts/janelas.sh" aplicar
  return $?
}

# O `index.theme` do hicolor DELA, que escondia os próprios ícones — entre eles
# as logos de dois jogos da Steam. Vem antes do `completar_icones` de propósito:
# é a base da cadeia, e completar ícone com a base quebrada é remendar por cima.
# O RELÓGIO DA BARRA DE CIMA, logo depois da geometria porque é o mesmo assunto
# visto de perto: a `forma.sh` decide o formato da barra, esta decide o que se
# mexe dentro dela. Os segundos eram o único elemento da tela que pedia atenção
# uma vez por segundo — 86.400 vezes por dia para dizer algo que ela nunca
# precisou.
#
# A CHAVE NASCE NO CONF E VAZIO QUER DIZER "NÃO TOQUE", igual às
# `VIDRO_OPACIDADE_*`. É a mesma fronteira de 17/08/2026: `show_seconds` tem
# controle na GUI (Ajustes → Data e hora), então quem decide é ela. Ela
# autorizou tirar em 25/08/2026, e a chave é o registro dessa autorização.
#
# DUAS MEDIÇÕES DE 25/08 QUE VALEM MAIS QUE A MUDANÇA:
#   - vale em menos de 2 s, sem reiniciar o painel. E o mecanismo NÃO é inotify
#     do applet: o `cosmic-applet-time` tem zero descritores de inotify; ele já
#     acorda 1x/s para desenhar e relê a config na mesma volta.
#   - APAGAR O ARQUIVO NÃO REVERTE. Com o `show_seconds` movido para fora, a
#     topbar continuou mostrando os segundos. Por isso o `remover` escreve
#     `true`, e o valor anterior fica em `~/.local/state/meowsystem/relogio/`.
etapa_relogio() {
  passo "Relógio da barra de cima"
  RELOGIO_SEGUNDOS="${RELOGIO_SEGUNDOS:-}" "$MEOW_RAIZ/scripts/relogio.sh" aplicar
  return $?
}

# O MODO DE LEITURA E O RELÓGIO QUE O LIGA SOZINHO (30/08/2026, etapa 2 do plano
# de 29/08). Vem depois do relógio de propósito: é o mesmo assunto — o que muda
# na tela dela por conta do horário —, e o supervisor da barra já mostrou que
# unidade de usuário fica melhor perto de quem a usa.
#
# TRÊS PORTÕES, E ELES NÃO DIZEM A MESMA COISA
#   `LEITURA_AGENDA` vazio  o script não escreve nada (contrato "vazio = não
#                           toca"), e o timer não é armado — e o que uma execução
#                           anterior tiver armado é REMOVIDO, porque um relógio
#                           nosso de pé já é decidir por ela.
#   `LEITURA_AGENDA="nao"`  o script zera os dois números, e o timer é desarmado e
#                           REMOVIDO. Desligar tem de desligar.
#   `AUTO_REPARO != "sim"`  mesmo com o agendamento pedido, nada é armado E NADA É
#                           APLICADO: quem desliga o auto-reparo está dizendo "não
#                           mexa sozinho na minha máquina", e virar a cor da tela
#                           às 18:00 é mexer. É a mesma carona do `etapa_painel` e
#                           do carrossel.
#
# O PORTÃO DO `AUTO_REPARO` PRECISOU DESCER ATÉ A ESCOLHA DO VERBO (31/08/2026)
#   Ele só barrava o timer, e o `aplicar` rodava três linhas ANTES dele. Medido
#   num HOME falso, com `AUTO_REPARO="nao"` e `LEITURA_AGENDA="sim"`: um
#   `./install.sh` gravou `leitura_temperatura=3500` e `leitura_textura=0.35` — a
#   tela âmbar — e, na linha seguinte, removeu o `meow-leitura.timer`, que era a
#   ÚNICA coisa capaz de devolvê-la ao neutro às 07:00. Ou seja, o portão que
#   existe para não mexer na máquina dela era exatamente o que deixava a tela
#   presa numa cor, até alguém rodar o instalador de novo depois das 07:00.
#   Agora o portão vem ANTES da chamada, e com o relógio proibido o script não é
#   chamado de jeito nenhum — nem com `conferir`. Medido também: o `conferir` aqui
#   funcionava (nada era escrito), mas despejava "modo de leitura divergente" mais
#   quatro linhas `!!` em TODA passagem, e uma delas — "senão o timer devolve o
#   valor da hora no próximo minuto" — é literalmente falsa numa máquina onde este
#   ramo acabou de remover o timer. Uma linha `--` dizendo o motivo é a verdade
#   inteira. Com `LEITURA_AGENDA="nao"` o `aplicar` continua obrigatório — é ele
#   que zera os dois números, e desligar tem de desligar.
#
# NADA AQUI COMPILA, BAIXA OU USA SUDO — e nada aqui pinta um pixel enquanto o
# patch da etapa 1 não entrar no binário. As chaves ficam corretas no disco desde
# já, e passam a valer no login seguinte ao build.
etapa_leitura() {
  passo "Modo de leitura (o horário liga sozinho)"
  local destino="$HOME/.config/systemd/user" u conteudo mudou=0
  local unidades=(meow-leitura.service meow-leitura.timer)

  # O degrau vale mesmo sem systemd: é o número no disco que o compositor lê. Mas
  # escrevê-lo com o relógio PROIBIDO deixa a tela numa cor sem ninguém para
  # desfazê-la — ver o portão do `AUTO_REPARO` no cabeçalho. Aí o script não é
  # chamado, e a etapa cai direto na linha que diz por quê.
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
      # A unidade vai no par que REMOVE também, como no `etapa_autoreparo`: são
      # dois arquivos (`.service` e `.timer`), mas armado/desarmado só existe UM,
      # e é dele que a frase fala. O `etapa_painel` é a exceção declarada — lá são
      # TRÊS unidades e nenhum nome sozinho seria verdade, então a frase fica no
      # recurso e o nome aparece nas linhas que armam, uma por unidade.
      if meow_seco; then
        meow_muda "removeria o relógio do modo de leitura (meow-leitura.timer)"
      else
        systemctl --user disable --now meow-leitura.timer >/dev/null 2>&1
        rm -f "${unidades[@]/#/$destino/}"
        # O `disable` de uma unidade cujo ARQUIVO já não existe não tem [Install]
        # para ler e deixa o link no `*.wants` — é o achado de 25/08/2026 do
        # `etapa_logo`, e é por isso que os links saem à mão. O laço varre as DUAS
        # unidades, e não só o `.timer`: hoje o `.service` não tem `[Install]` e
        # portanto ninguém consegue habilitá-lo, mas o cabeçalho do próprio
        # `.timer` já prevê o dia em que um `.path` venha acordar essa unidade. Um
        # link órfão que este laço não visse faria o `meow_unidade_sobrou` dizer
        # "sobrou" para sempre, e esta etapa anunciaria "desligado e removido" em
        # TODA execução — divergência eterna por um resíduo de uma linha.
        for u in "${unidades[@]}"; do
          rm -f "$destino"/*.wants/"$u" "$destino"/*.requires/"$u"
        done
        systemctl --user daemon-reload >/dev/null 2>&1
        meow_muda "relógio do modo de leitura desligado e removido (meow-leitura.timer)"
      fi
      # O CONSELHO SAI NA PASSAGEM QUE TIRA O RELÓGIO — ANTES ELE SÓ SAÍA DEPOIS
      #   Medido em 31/08/2026, num HOME falso com as duas unidades no disco e o
      #   timer armado, `AUTO_REPARO="nao"` e `LEITURA_AGENDA="sim"`:
      #       passagem 1   ~~ relógio do modo de leitura desligado e removido
      #       passagem 2   -- AUTO_REPARO="nao" … / >> o degrau que estiver …
      #   Ou seja: o conselho chegava uma passagem DEPOIS do momento que ele
      #   descreve. É exatamente a passagem em que ela PERDE o relógio — quem
      #   desliga o auto-reparo às 20:00 fica com a tela âmbar e sem quem a
      #   devolva — e era a única em que ele não aparecia.
      #
      #   Ele saiu do ramo de baixo em vez de ser copiado: lá é o estado de
      #   regime, que se repete em toda execução do instalador daí para a
      #   frente, e um conselho impresso para sempre vira ruído que ninguém lê.
      #   Aqui ele sai UMA vez, na passagem que muda algo.
      #
      #   E só com `aplicavel=0`, que é o mesmo alcance que o conselho já tinha
      #   lá embaixo, nem um caso a mais: com `LEITURA_AGENDA="nao"` o
      #   `leitura.sh aplicar` ACABOU de rodar e zerar os dois números, então "o
      #   degrau que estiver no disco fica" seria falso e mandaria zerar o que já
      #   é zero. Fica de fora também o `LEITURA_AGENDA` VAZIO, onde o degrau de
      #   fato sobra ("vazio = não toca") — mas lá a primeira metade da frase
      #   ("esvazie LEITURA_AGENDA") manda fazer o que já está feito, e mudar o
      #   texto é escolha dela, não minha. Está relatado.
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
    # Sobra o `nao`, e aí o `rc` é o do zeramento dos dois números: 1 na passagem
    # que zerou, 0 nas seguintes. `${…:-}` e não `$LEITURA_AGENDA` seco porque o
    # `lib/comum.sh` liga `set -u` — a guarda de cima já garante que a chave
    # existe aqui, mas quem mexer nela amanhã não fica com um campo minado.
    if [ "${LEITURA_AGENDA:-}" != "sim" ]; then
      meow_pula "LEITURA_AGENDA=\"${LEITURA_AGENDA:-}\" — sem relógio do modo de leitura"
      return "$rc"
    fi
    # Sobra o portão do AUTO_REPARO com o agendamento PEDIDO. O script nem foi
    # chamado: nada foi lido, nada foi escrito. Isso é `pulado`, e é o mesmo `3`
    # com que o `etapa_autoreparo` responde à mesma chave. Devolver o `rc` (que
    # aqui vale 0, porque ninguém o mexeu) jogaria esta etapa em `confere:` —
    # "já estava certo", dito por quem não conferiu nada.
    #
    # A frase nomeia UM culpado. A antiga imprimia `LEITURA_AGENDA="nao"/
    # AUTO_REPARO="sim"` nos dois ramos, e quem lesse tinha de descobrir sozinho
    # qual das duas chaves era a razão.
    meow_pula "AUTO_REPARO=\"${AUTO_REPARO:-}\" — sem relógio do modo de leitura, mesmo com LEITURA_AGENDA=\"sim\""
    # Os dois números ficam como estiverem: zerá-los aqui seria mexer sozinho na
    # máquina de quem acabou de pedir para não mexerem nela. O caminho de volta
    # (`meow leitura remover`) é impresso na passagem que TIRA o relógio, no ramo
    # do `meow_unidade_sobrou` acima — aqui é o estado de regime, e repeti-lo em
    # toda execução do instalador só ensinaria a pular as duas linhas.
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

  # O SECO TAMBÉM TEM DE ENXERGAR O TIMER SOLTO, E NÃO ENXERGAVA (31/08/2026)
  #   Medido num HOME falso com as duas unidades no disco, os dois números já
  #   certos e o timer DESARMADO: o seco devolvia 0 ("confere", nada a fazer) e a
  #   passagem real logo em seguida devolvia 1, armando o timer. Ou seja, a
  #   auditoria escondia a única coisa que ia mudar. `is-enabled` e `is-active`
  #   são leitura pura — o `tests/seco.sh` continua verde com elas aqui.
  if meow_seco; then
    # Duas divergências DIFERENTES, duas linhas: juntá-las num `mudou` só faria a
    # auditoria dizer "instalaria as unidades" numa máquina onde elas já estão no
    # disco e só o timer está solto.
    local armaria=0
    if [ "$(systemctl --user is-enabled meow-leitura.timer 2>/dev/null)" != "enabled" ] ||
       [ "$(systemctl --user is-active  meow-leitura.timer 2>/dev/null)" != "active" ]; then
      armaria=1
    fi
    # O SUBSTANTIVO É O MESMO DOS DOIS LADOS, E A UNIDADE VAI JUNTO (31/08/2026)
    #   O seco dizia "armaria o meow-leitura.timer" e o real, três linhas de
    #   código abaixo, "relógio do modo de leitura armado": dois nomes para a
    #   mesma coisa, e ela roda um e depois o outro. Pior, os dois nomes estavam
    #   no MESMO bloco seco — a linha de cima falava em "as unidades do relógio
    #   do modo de leitura" e a de baixo em "meow-leitura.timer". O padrão da
    #   casa é o do `cmd_remover` do `scripts/leitura.sh` ("desarmaria o …" /
    #   "… desarmado") e o do `etapa_painel`: mesmo substantivo, verbo
    #   conjugado, nome da unidade entre parênteses.
    [ "$mudou"   = "1" ] && meow_muda "instalaria/atualizaria as unidades do relógio do modo de leitura"
    [ "$armaria" = "1" ] && meow_muda "armaria o relógio do modo de leitura (meow-leitura.timer)"
    { [ "$mudou" = "1" ] || [ "$armaria" = "1" ]; } && return "$MEOW_DIVERGENTE"
    return "$rc"
  fi

  # ESCREVEU = `mexeu`, E O `rc` DO SCRIPT NÃO SABE DISSO
  #   Medido em 31/08/2026: com o timer já armado e a unidade do repositório
  #   divergindo da do disco (é o que um `git pull` faz), a etapa reescrevia o
  #   `meow-leitura.timer`, chamava `daemon-reload` e devolvia 0 — que o
  #   `concluir()` arquiva em `confere: … nada escrito`. A tela dizia que nada
  #   mudou logo na passagem em que o systemd foi recarregado. É a separação
  #   0/1 que o cabeçalho do `concluir()` existe para defender, e o
  #   `etapa_autoreparo` já a respeita com este mesmo `mudou`.
  if [ "$mudou" = "1" ]; then
    systemctl --user daemon-reload
    rc=1
  fi

  # Só o `.timer` é armado. O `.service` é puxado por ele (`Unit=`), e habilitá-lo
  # separado criaria um segundo caminho para a mesma execução — o defeito que o
  # `meow_unidade_sobrou` existe para enxergar.
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

# Os apps que não podem subir sozinhos no login. NÃO escreve em
# `~/.config/autostart/` (é da Aurora): o bloqueio é `systemctl --user mask` da
# unidade que o `systemd-xdg-autostart-generator` gera a partir do `.desktop`.
# O `~/.config/systemd/user` vem DOZE posições antes do `generator.late` no
# `UnitPath` desta máquina, então o mask vence — medido.
#
# E abrir o app pelo ícone continua funcionando, provado e não suposto: o
# lançador do COSMIC cria um ESCOPO transitório (`app-cosmic-<id>-<pid>.scope`),
# que não é a unidade mascarada. O `@autostart.service` só é puxado pelo
# `xdg-desktop-autostart.target`, que sobe uma vez, no login.
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

# As capas dos jogos. Depende do `hicolor` acima: com o index.theme quebrado, os
# atalhos apareceriam sem ícone — e "apareceu sem ícone" é um sintoma pior que
# "não apareceu", porque parece que a arte do jogo se perdeu.
etapa_jogos() {
  passo "Jogos da Steam"
  "$MEOW_RAIZ/scripts/jogos_steam.sh"
  return $?
}

# Os jogos do Heroic (Epic, GOG, Amazon e os adicionados à mão). Irmã da etapa
# acima e pela mesma razão: o Heroic também NÃO escreve `.desktop` de jogo — as
# duas chaves que fariam isso (`addDesktopShortcuts`, `addStartMenuShortcuts`)
# nascem desligadas, e mesmo ligadas só valem para o que ela instalar DEPOIS.
# Queixa dela em 10/09/2026: "os jogos instalados pelo heroic launcher não
# aparecem nos .desktop da interface".
#
# Vem depois do `etapa_jogos` e pelo mesmo motivo que ele vem depois do
# `etapa_hicolor`: sem o `index.theme` do usuário, o cartão apareceria SEM
# ícone, e sem ícone parece que a capa do jogo se perdeu.
etapa_jogos_heroic() {
  passo "Jogos do Heroic"
  "$MEOW_RAIZ/scripts/jogos_heroic.sh"
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

# As pastas ESPECIAIS que o cosmic-files pede pelo nome XDG, vestidas com os
# desenhos que o pack no ar tem para elas, ou com os do Catppuccin que ele
# herda. Vem ANTES do `etapa_pastas` de propósito: o `construir_pastas.sh` só
# cede um nome quando o desenho JÁ está no disco, e nesta ordem a cessão vale
# na primeira passagem em vez de custar uma rodada.
#
# O TÍTULO NÃO DIZ DE QUEM É O DESENHO — 25/09/2026, sprint P62
#   Era «Pastas especiais em Catppuccin», e com o Dracula no ar as sete são os
#   desenhos do Dracula. No padrão (`PASTAS_XDG="nao"`) não entra desenho de
#   pack nenhum: as sete seguem a cor das outras pastas. De quem é o desenho,
#   quando há um, quem diz é a linha do `icones_pastas.sh`, que pergunta ao
#   pack no ar; o título só nomeia a etapa.
#
# A PREMISSA DA SPRINT C CAIU, E O QUE ENTROU É OUTRO CAMINHO
#   A sprint queria instalar 14 nomes do pack (`folder-github`, `folder-docker`
#   e companhia). Medido: o `cosmic-files` contém 12 nomes de pasta e só DOIS
#   daqueles aparecem. Os outros são apelidos do Papirus para o Dolphin/KDE, que
#   lê um `.directory` dentro da pasta — e `.directory` aparece ZERO vezes no
#   binário do cosmic-files. Seriam ícones que ela nunca veria. O casamento que
#   vale é por nome XDG, e são 7.
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

# `FLAVOR` E `ACCENT` PRECISAM ATRAVESSAR — E NÃO ATRAVESSAVAM (medido 08/08/2026)
#   O `. "$fonte"` do `etapa_conf` cria variável de SHELL, não de ambiente, e o
#   `aplicar_apps.sh` é processo FILHO: ele recebia `APPS_ATIVOS` porque a chamada
#   o passa na linha, e mais nada. Provado com um módulo-sonda que só imprimia as
#   duas: `FLAVOR=[VAZIO] ACCENT=[VAZIO]`, pelos dois caminhos (install e doctor).
#   Ou seja, TODO módulo de app rodava no padrão fixo `mocha`/`mauve` — o
#   `_zz_verde` do zapzap inclusive (essa função saiu em 11/08/2026, quando o
#   ícone do WhatsApp passou a vir do `apps-arcticons.map`; os outros módulos
#   continuam lendo as duas). Ninguém percebeu porque a conf dela é
#   exatamente mocha/mauve; o dia em que ela trocasse de flavor, os apps ficariam
#   para trás em silêncio.
etapa_apps() {
  passo "Aplicativos"
  APPS_ATIVOS="${APPS_ATIVOS:-}" FLAVOR="${FLAVOR:-}" ACCENT="${ACCENT:-}" \
    SPOTIFY_MARKETPLACE="${SPOTIFY_MARKETPLACE:-}" \
    "$MEOW_RAIZ/scripts/aplicar_apps.sh" aplicar
  return $?
}

# ---------------------------------------------------------------------------
# O APPLET DE MÍDIA — A PRIMEIRA VEZ QUE ESTE PROJETO COMPILA ALGUMA COISA
#
#   Isso merece ser dito em voz alta, e não enfiado no meio de uma etapa. Até
#   hoje, 24/08/2026, um grep por `cargo|rustc|make|gcc|meson|cmake` em
#   install.sh, scripts/, lib/ e bin/meow devolvia ZERO invocações — o único
#   acerto no repo inteiro era a palavra `make` dentro de um comentário do
#   `escala.sh`, falando de fabricante de monitor. Este projeto copiava,
#   escrevia e ligava unidade; daqui para frente ele também CONSTRÓI. Tudo o que
#   vem abaixo existe para que essa novidade não vaze para o resto.
#
# POR QUE SÃO DUAS ETAPAS PARA UM APPLET SÓ
#   Porque compilar é a única coisa que o `meow doctor` das 05:00 não pode
#   fazer, e essa fronteira precisa ser um NOME, não um `if` no meio de um
#   script. `midia_build` constrói o binário; `midia` põe a sombra `.desktop` e
#   as chaves — e a sombra é reparável sem cargo, sem rede e sem espera. Num
#   arquivo só, o doctor teria de atravessar o caminho do cargo para chegar às
#   partes que ele PODE consertar, e um nome só não pode ser "consertável pela
#   metade": o laço de conserto dá `continue` pelo NOME antes de olhar o código
#   de saída.
#
# A ORDEM É OBRIGATÓRIA: O BINÁRIO ANTES DA SOMBRA
#   O `.desktop` que o `midia.sh` escreve tem `Exec=` no caminho absoluto do
#   binário, e o cosmic-panel casa o applet pelo BASENAME e CONSOME o slot no
#   primeiro acerto. Sombra presente com binário ausente não devolve o applet do
#   flatpak: deixa um BURACO na dock. Invertida, esta dupla fabricaria esse
#   buraco uma vez por instalação nova, e só a segunda passagem o fecharia.
#
# `MIDIA_COMPILAR=1` VAI NA LINHA DO COMANDO, E ISSO NÃO É ESTILO
#   O `meow.conf` é sourceado no shell do install.sh, e todo script de
#   `scripts/` roda como PROCESSO FILHO: variável de shell não atravessa. Este
#   esquecimento já foi cometido duas vezes neste repo — a última custou o
#   `FLAVOR`/`ACCENT` de todo módulo de app, em silêncio, e está medida no
#   cabeçalho do `etapa_apps`, logo acima. Aqui ele seria mudo de um jeito novo:
#   sem a chave, o `midia_build.sh` não falha, ele recusa compilar e devolve 1 —
#   e 1 é "divergia e foi consertado". O resumo diria `mexeu: midia_build` em
#   TODA execução, para sempre, sem um byte ter sido escrito. É exatamente a
#   mentira de relatório que o bloco do `concluir()` existe para não deixar
#   acontecer.
#
# 91s A FRIO, 0s DEPOIS — E É POR ISSO QUE ISTO CABE NUMA ETAPA
#   Medido hoje. A segunda passagem não invoca o cargo uma única vez: o carimbo
#   (sha do patch, commit do PINO, sha do binário instalado, versão do rustc)
#   bate e o script devolve 0 na hora. Sem esse carimbo, até um rebuild que não
#   muda nada custaria ~20s — todo dia, dentro do doctor, que é o tipo de gasto
#   que ninguém vê e ninguém remove depois.
#
# SEM `cargo`, A DEGRADAÇÃO É LIMPA
#   A etapa devolve 3, cai em "pulados" e mais nada acontece: sem binário a
#   sombra não é escrita, e a máquina continua com o applet do flatpak que
#   sempre funcionou. Não é uma falha a ser consertada — é a máquina de quem não
#   tem rustup, e ela fica igual ao que era antes desta etapa existir.
etapa_midia_build() {
  passo "Applet de mídia (compilação)"
  MIDIA_COMPILAR=1 MIDIA="${MIDIA:-}" \
    "$MEOW_RAIZ/scripts/midia_build.sh"
  return $?
}

# O APPLET DO MODO DE LEITURA — UMA ETAPA SÓ, E A DIFERENÇA É MEDIDA
#   O applet de mídia precisa de duas etapas porque a sombra dele MASCARA o
#   applet do flatpak: perder o conserto automático da sombra custaria à dock um
#   buraco onde havia algo que funcionava. O de leitura não tem nada por trás —
#   ele é o único dono de `com.meowsystem.AppletLeitura` —, então binário e
#   sombra andam juntos no mesmo script, e o pior caso de uma sombra órfã é um
#   espaço vazio na topbar que o `meow doctor` nomeia numa linha.
#
#   A ORDEM CONTINUA VALENDO, e agora ela é interna ao `leitura_build.sh`:
#   binário instalado primeiro, sombra depois, e o fail-safe (sombra sem binário
#   = sombra removida) roda ANTES da trava do `LEITURA_COMPILAR`, para que um
#   `./install.sh` sem cargo ainda feche o buraco.
#
#   A TERCEIRA PEÇA NÃO É NOSSA E NÃO ENTRA AQUI: a linha do `plugins_wings` da
#   topbar é território da Aurora (docs/FRONTEIRA.md) e é escrita À MÃO. O script
#   AVISA quando ela falta; nenhum caminho deste arquivo a escreve — e a razão
#   deixou de ser "é só cosmético" em 30/08/2026: o painel tem watch de inotify
#   naquele diretório e `plugins_wings` está na lista `must_recreate` dele, então
#   escrever ali RECRIA a topbar e respawna todos os applets na hora. Uma vez, à
#   mão, é barato; num laço de install é a receita do painel fantasma.
#
# `LEITURA_COMPILAR=1` VAI NA LINHA DO COMANDO PELO MESMO MOTIVO DO IRMÃO
#   O `meow.conf` é sourceado no shell do install.sh e todo script de `scripts/`
#   roda como PROCESSO FILHO: variável de shell não atravessa. Sem a chave, o
#   `leitura_build.sh` não falha — ele recusa compilar e devolve 3, que cai em
#   "pulados". O que é a verdade: a etapa não rodou porque falta algo que não é
#   dela resolver.
etapa_leitura_applet() {
  passo "Applet do modo de leitura (compilação e sombra)"
  LEITURA_COMPILAR=1 LEITURA_APPLET="${LEITURA_APPLET:-}" \
    "$MEOW_RAIZ/scripts/leitura_build.sh"
  return $?
}

etapa_midia() {
  passo "Applet de mídia (sombra e chaves)"
  MIDIA="${MIDIA:-}" MIDIA_LARGURA="${MIDIA_LARGURA:-}" \
    MIDIA_COR_ALBUM="${MIDIA_COR_ALBUM:-}" MIDIA_CAPA="${MIDIA_CAPA:-}" \
    MIDIA_FONTE="${MIDIA_FONTE:-}" MIDIA_COR_TITULO="${MIDIA_COR_TITULO:-}" \
    MIDIA_COR_ARTISTA="${MIDIA_COR_ARTISTA:-}" \
    MIDIA_CONTROLES="${MIDIA_CONTROLES:-}" FLAVOR="${FLAVOR:-}" \
    "$MEOW_RAIZ/scripts/midia.sh"
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
      # "o timer" era o substantivo errado: este arquivo instala QUATRO timers, e
      # o par seco/real é o único lugar onde ela liga uma frase à outra. As duas
      # irmãs já dizem o recurso ("supervisor da barra", "relógio do modo de
      # leitura"); aqui é `auto-reparo`, com a unidade junto.
      # E `${AUTO_REPARO:-}` no real, como no seco e nas irmãs: o `lib/comum.sh`
      # liga `set -u`, e a guarda de cima usa o padrão `sim` — quem tirar essa
      # guarda amanhã não deve encontrar um `$AUTO_REPARO` seco esperando por ele.
      if meow_seco; then
        meow_muda "AUTO_REPARO=\"${AUTO_REPARO:-}\" — removeria o auto-reparo (meow-doctor.timer)"
        return "$MEOW_DIVERGENTE"
      fi
      systemctl --user disable --now meow-doctor.timer >/dev/null 2>&1
      rm -f "$destino/meow-doctor.timer" "$destino/meow-doctor.service"
      systemctl --user daemon-reload >/dev/null 2>&1
      meow_muda "AUTO_REPARO=\"${AUTO_REPARO:-}\" — auto-reparo desligado e removido (meow-doctor.timer)"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "AUTO_REPARO=\"${AUTO_REPARO:-}\" no meow.conf — sem reparo automático"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_tem systemctl || [ ! -d "/run/user/$(id -u)/systemd" ]; then
    meow_aviso "não há systemd --user nesta sessão — o auto-reparo fica de fora"
    meow_info "  o «Conferir e consertar» faz o mesmo quando quiser"
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

  # O SECO TAMBÉM TEM DE ENXERGAR O TIMER SOLTO, E NÃO ENXERGAVA (31/08/2026)
  #   Medido num HOME falso com as duas unidades no disco iguais às do
  #   repositório e o `meow-doctor.timer` DESARMADO (nem `enabled`, nem `active`):
  #       rc(seco)=0    ok   auto-reparo já instalado
  #       rc(real)=1    (armou o timer)
  #   Aqui foi pior que calar: o seco imprimia um `ok` VERDE dizendo "já
  #   instalado" numa máquina onde o reparo não ia disparar nunca — o `ok` é a
  #   linha que mais convence, e era a única errada. Instalado ele estava; ligado,
  #   não. `is-enabled`/`is-active` são leitura pura, então o `tests/seco.sh`
  #   continua verde com elas aqui.
  if meow_seco; then
    local armaria=0
    if [ "$(systemctl --user is-enabled meow-doctor.timer 2>/dev/null)" != "enabled" ] ||
       [ "$(systemctl --user is-active  meow-doctor.timer 2>/dev/null)" != "active" ]; then
      armaria=1
    fi
    # Duas divergências DIFERENTES, duas linhas. A frase antiga era uma só —
    # "instalaria as unidades e ligaria meow-doctor.timer" — e mentia metade nos
    # dois sentidos: dizia que ligaria o timer numa máquina onde ele já estava
    # ligado, e não dizia nada na máquina onde ligá-lo era tudo o que faltava.
    # DUAS IRMÃS DIZEM `armar`, ESTA DIZ `ligar`, E É DE PROPÓSITO (31/08/2026)
    #   `armar` é o verbo do TIMER: é o que o `cmd_remover` do
    #   `scripts/leitura.sh` usa ("desarmaria o …" / "… desarmado") e o que o
    #   `etapa_painel` e o `etapa_leitura` repetem. Aqui o sujeito da frase não é
    #   o timer, é a CHAVE: `AUTO_REPARO="sim"/"nao"` liga e desliga o recurso
    #   inteiro, a etapa se chama por ele e o ramo de cima já diz "sem reparo
    #   automático". Trocar para "armaria o auto-reparo" faria a linha discordar
    #   da chave que ela nomeia — então fica `ligar`, e quem vier depois não
    #   precisa inventar um terceiro verbo.
    #
    #   O que NÃO era escolha, e era o defeito: o seco dizia "ligaria o
    #   meow-doctor.timer" e o real "auto-reparo ligado: …" — verbo certo, mas
    #   SUBSTANTIVO diferente dos dois lados, e nenhum dos dois lados tinha o
    #   outro nome. Ela roda o seco, lê um nome, roda o real, lê outro. Agora o
    #   substantivo é `auto-reparo` nos dois, e a unidade vai junto entre
    #   parênteses, como no `etapa_painel`.
    [ "$mudou"   = "1" ] && meow_muda "instalaria/atualizaria as unidades do auto-reparo"
    [ "$armaria" = "1" ] && meow_muda "ligaria o auto-reparo (meow-doctor.timer, todo dia às 5h)"
    { [ "$mudou" = "1" ] || [ "$armaria" = "1" ]; } && return "$MEOW_DIVERGENTE"
    meow_ok "auto-reparo já ligado (meow-doctor.timer, todo dia às 5h, com até 20min de folga)"
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

  # As duas frases abaixo são o par REAL das duas do bloco seco, na mesma ordem:
  # "já ligado" é literalmente a mesma linha lá em cima (o seco não tem por que
  # descrever o repouso com outras palavras), e a de baixo é o "ligaria"
  # conjugado, com a unidade no mesmo lugar.
  if [ "$mudou" = "0" ]; then
    meow_ok "auto-reparo já ligado (meow-doctor.timer, todo dia às 5h, com até 20min de folga)"
    return 0
  fi
  meow_ok "auto-reparo ligado (meow-doctor.timer): todo dia às 5h, log em $estado/doctor.log"
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
# A LOGO E A ROTAÇÃO DE MASCOTES
#
# A INSTALAÇÃO DO ACERVO É INCONDICIONAL; SÓ O TIMER OBEDECE À CHAVE
#   Os mascotes vão para o disco mesmo com LOGO_ROTACAO="nao" — sem isso,
#   `meow logo girar` na mão não teria para onde apontar, e ligar a rotação
#   depois exigiria uma rodada extra do instalador antes de funcionar.
#   O que a chave liga e desliga é o RELÓGIO, não o acervo.
# ---------------------------------------------------------------------------
# UMA UNIDADE PODE ESTAR LIGADA SEM O ARQUIVO EXISTIR — E TODA PERGUNTA ÓBVIA
# RESPONDE QUE NÃO (achado da auditoria de 25/08/2026)
#
#   Encontrado vivo na máquina dela:
#       ~/.config/systemd/user/default.target.wants/meow-logo.service
#   era um symlink QUEBRADO — o alvo tinha sido apagado por uma execução
#   anterior do `etapa_logo`, e o link do `.wants` ficou. As respostas:
#
#       systemctl --user is-enabled meow-logo.service  -> not-found
#       systemctl --user is-active  meow-logo.service  -> inactive
#       systemctl --user --failed                      -> (vazio)
#
#   Nenhuma delas vê o resíduo. Quem vê é o disco. E as etapas que DESLIGAM
#   usavam justamente a pergunta que menos enxerga: `[ -f "$destino/<unidade>" ]`.
#   Com o arquivo já apagado, o bloco de desligamento era PULADO para sempre e o
#   instalador imprimia "rotação desligada" com um link órfão no `.wants` — o
#   mesmo erro que o `etapa_wallpaper` tinha com o `meow-fundo.path`.
#
#   Daí esta função: pergunta as TRÊS coisas (arquivo, estado no systemd, link
#   em qualquer `*.wants`/`*.requires`) e devolve 0 se qualquer uma disser que
#   ainda há o que desligar. Deixar de instalar nunca desligou nada.
meow_unidade_sobrou() {   # $1.. = nomes de unidade; devolve 0 se sobrou algo
  local destino="$HOME/.config/systemd/user" u w
  for u in "$@"; do
    [ -f "$destino/$u" ] && return 0
    case "$(systemctl --user is-enabled "$u" 2>/dev/null)" in
      enabled|enabled-runtime|linked|linked-runtime) return 0 ;;
    esac
    [ "$(systemctl --user is-active "$u" 2>/dev/null)" = "active" ] && return 0
    # Glob sem match fica literal, e `[ -L literal ]` é falso — não precisa de
    # nullglob, que mudaria o comportamento de globs de outras etapas.
    for w in "$destino"/*.wants/"$u" "$destino"/*.requires/"$u"; do
      [ -L "$w" ] && return 0
    done
  done
  return 1
}

# O RELÓGIO DO MASCOTE — instalado quando `LOGO_MODO="hora"`, removido quando não.
#
#   Novo em 01/09/2026, com o pedido dela: "de noite o menu com o mimir e de dia
#   a coquinha; o mesmo no terminal com o fastfetch". Quem decide o mascote é o
#   `logo.sh`; esta função só liga e desliga o par de unidades que o acorda de
#   cinco em cinco minutos. O porquê do intervalo está no `meow-gato.timer`.
#
#   DESLIGAR TEM DE DESLIGAR, e por isso o `else` existe: sem ele, quem trocasse
#   para `LOGO_MODO="rotacao"` continuaria com o relógio vivo, e o mascote voltaria
#   ao rosto da hora cinco minutos depois de cada giro. Os dois donos da mesma
#   linha, de novo — só que desta vez atravessando duas unidades do systemd.
_logo_relogio() {
  local liga="$1" destino="$HOME/.config/systemd/user" mudou=0 u conteudo

  if [ "$liga" != "sim" ]; then
    if meow_unidade_sobrou meow-gato.timer meow-gato.service; then
      meow_seco && { meow_muda "removeria o relógio do mascote (LOGO_MODO não é \"hora\")"; return "$MEOW_DIVERGENTE"; }
      systemctl --user disable --now meow-gato.timer meow-gato.service >/dev/null 2>&1
      rm -f "$destino/meow-gato.timer" "$destino/meow-gato.service"
      # Link órfão em *.wants sobrevive ao `disable` quando o ARQUIVO da unidade
      # já não existe — o `disable` não tem o que ler para achá-lo. Mesma cura
      # que o bloco do `meow-logo` abaixo aplica.
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

  # O SECO TAMBÉM TEM DE ENXERGAR O TIMER SOLTO, E NÃO ENXERGAVA — 22/09/2026
  #   É a dívida 6 do `docs/SPRINTS.md`, que estava lá como "HIPÓTESE, não
  #   medida" desde 31/08. MEDIDA hoje, num HOME de brinquedo com as unidades do
  #   repositório JÁ no disco (`mudou=0`) e um `systemctl` de mentira que só
  #   responde `disabled`/`inactive`: o ensaio inteiro saía sem UMA linha sobre o
  #   `meow-gato.timer`, e a passagem real, dez linhas abaixo, o arma. O ensaio
  #   não escrevia — ele CALAVA, que é a outra metade de "ensaio que mente é pior
  #   que nada". `is-enabled`/`is-active` são leitura pura, então o
  #   `tests/seco.sh` segue verde com elas aqui; quem cobre este caminho é a
  #   rodada 3 daquele teste.
  #
  #   A cura é a MESMA do `etapa_leitura` e do `etapa_autoreparo` (31/08): duas
  #   divergências diferentes, duas linhas. Juntá-las num `mudou` só faria a
  #   auditoria dizer "instalaria as unidades" numa máquina onde elas já estão no
  #   disco e só o timer está solto — e o contrário, na máquina em que os dois
  #   arquivos são novos e o timer já está armado.
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
  # `enable --now` no TIMER, nunca no `.service`: o serviço é `oneshot` e quem o
  # acorda é o relógio. Ligar o serviço com `--now` o faria rodar uma vez agora e
  # ficar `inactive (dead)`, que é o estado certo mas confunde quem for olhar.
  if [ "$(systemctl --user is-enabled meow-gato.timer 2>/dev/null)" != "enabled" ] ||
     [ "$(systemctl --user is-active  meow-gato.timer 2>/dev/null)" != "active" ]; then
    systemctl --user enable --now meow-gato.timer >/dev/null 2>&1 \
      || { meow_erro "não consegui ligar o meow-gato.timer"; return "$MEOW_ERRO"; }
    # O SUBSTANTIVO É O MESMO DOS DOIS LADOS, e a unidade vai junto: é a regra
    # que o `etapa_leitura` e o `etapa_painel` já seguem. Sem esta linha o seco
    # diria "armaria o relógio do gato" e a execução que ela aprovou não diria
    # nada — ela veria a promessa e não veria o cumprimento.
    meow_muda "relógio do mascote armado (meow-gato.timer, tique de 5 min)"
    mudou=1
  fi
  [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
  return 0
}

# O ÍNDICE DO TEMA, DEPOIS DE TODA ETAPA QUE ESCREVE NELE — 09/10/2026, P74 item 5
#   O `etapa_icones` escreve o `index.theme` antes das etapas que criam
#   `48x48/apps`, `scalable/mimetypes` e os `status`, e a primeira passagem
#   terminava com eles fora do `Directories=` — só a segunda os declarava (T8
#   da paridade de 09/10). Esta etapa vem DEPOIS da última que escreve no tema
#   (a dos mascotes, que põe os dois botões em `scalable/apps`), recalcula o índice
#   do disco e reindexa a cache que estiver velha: o tema sai certo na primeira
#   passagem, e o laço das passagens deixa de ser quem o acerta.
etapa_icones_indice() {
  passo "Índice do tema de ícones"
  NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    "$MEOW_RAIZ/scripts/construir_icones.sh" indice
  return $?
}

etapa_logo() {
  passo "Gatos do painel"
  local destino="$HOME/.config/systemd/user" mudou=0 rc modo

  # O MODO EFETIVO VEM DO PRÓPRIO `logo.sh`, e não de uma cópia da regra aqui.
  # Ele já precisa resolver a compatibilidade `LOGO_ROTACAO="sim"` -> modo
  # `rotacao`; reimplementá-la nesta etapa criaria duas respostas para "que modo
  # está valendo", e elas divergiriam na primeira chave nova.
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
    # A rotação por encerramento não pode ficar viva ao lado do relógio: seriam
    # dois donos do mesmo mascote, e o do logout venceria até o tique seguinte.
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

  # Desligar tem de DESLIGAR (mesma disciplina do auto-reparo): deixar de
  # instalar manteria vivo o timer que uma execução anterior ligou, e ela veria
  # o mascote continuar trocando depois de ter desligado a chave.
  if [ "$modo" != "rotacao" ]; then
    # `meow_unidade_sobrou` e não `[ -f … ]`: com o arquivo já apagado e um link
    # órfão no `default.target.wants`, a versão antiga pulava este bloco para
    # sempre e dizia "rotação desligada". Ver o cabeçalho da função.
    if meow_unidade_sobrou meow-logo.service meow-logo.timer; then
      meow_seco && { meow_muda "removeria a rotação (inclusive link órfão em *.wants)"; return "$MEOW_DIVERGENTE"; }
      systemctl --user disable --now meow-logo.timer meow-logo.service >/dev/null 2>&1
      rm -f "$destino/meow-logo.timer" "$destino/meow-logo.service"
      # O `disable` de uma unidade cujo ARQUIVO já não existe não tem o que ler
      # para achar os links; então os tiramos à mão. É a única forma de o
      # resíduo de uma versão antiga do instalador ir embora sozinho.
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

  # O TIMER FOI EMBORA EM 08/08/2026 — E QUEM O TEM NA MÁQUINA PRECISA PERDÊ-LO
  #   Deixar de instalar não desinstala: o `meow-logo.timer` de uma execução
  #   anterior continuaria vivo, girando o mascote no meio da sessão para um efeito
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
      meow_muda "meow-logo.timer removido — o mascote agora gira ao encerrar a sessão"
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
    meow_ok "rotação de mascotes já ligada"
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
  # A FRASE DIZ QUANDO O MASCOTE TROCA, NÃO SÓ DE QUANTO EM QUANTO
  #   "a cada 1d" sozinho fazia esperar um mascote novo aparecendo no meio do dia,
  #   que é justamente o que não acontece: o painel só relê no login.
  [ "$mudou" = "0" ] && { meow_ok "rotação já ligada (no máximo 1 mascote a cada ${LOGO_INTERVALO:-1d}, no login seguinte)"; return 0; }
  meow_ok "o mascote gira ao encerrar a sessão, no máximo 1 a cada ${LOGO_INTERVALO:-1d}"
  meow_info "  ele aparece no login seguinte — 'meow logo listar' mostra o acervo"
  return "$MEOW_DIVERGENTE"
}

# ---------------------------------------------------------------------------
# O VIGIA DO ACERVO — A PASTA PASSA A RESPONDER NA HORA
#
#   Pedido dela em 05/08: "o comando do meow tem que disparar em automático,
#   talvez no self heal algo assim". A etapa acima põe o acervo no disco e liga o
#   RELÓGIO; esta liga o par `meow-assets.path` + `meow-assets.service`, que faz
#   um SVG solto em `packs/meowsystem/mascote/` entrar sem esperar a volta do relógio — que
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
  passo "Vigia do acervo de mascotes (systemd --user)"
  ASSETS_VIGIA="${ASSETS_VIGIA:-sim}" "$MEOW_RAIZ/scripts/vigia_assets.sh"
  return $?
}

# O GATILHO DE FLATPAK — o irmão do `99-meow-lancador` para o outro empacotador.
#
# O BURACO QUE ELE FECHA
#   Um `flatpak update` troca a árvore de deploy inteira e apaga o que estava
#   escrito lá dentro. Foi o que desfez o ícone de bandeja do ZapZap em
#   `ago 20 03:30:36` (`flatpak history`), e o que ela viu em 23/08. O
#   `packs/meowsystem/icones/bandeja.map` previa isso desde 10/08 e não havia gatilho nenhum.
#
#   O `meow-doctor.timer` não fecha este buraco: ele passa às 5h, então uma
#   atualização das 10h da manhã deixa o ícone errado por dezenove horas. A lição
#   do commit `a35b751` é exatamente essa — gatilho de EVENTO, não de relógio.
#
# POR QUE UMA UNIDADE `.path`, E NÃO UM HOOK NATIVO DE FLATPAK
#   Porque o hook nativo existe e NÃO SERVE, e isso foi verificado: os triggers
#   de `/usr/share/flatpak/triggers/` rodam dentro de um bwrap somente-leitura
#   (as `strings` da libflatpak mostram `--ro-bind`/`--unshare-ipc` ao lado de
#   "running trigger"), com escrita apenas no `exports/` da instalação — e o
#   arquivo que precisamos reescrever fica fora dele. Além disso o diretório é do
#   pacote `flatpak` do apt (`dpkg -S` confirma). A medição inteira está no
#   cabeçalho de `systemd/meow-flatpak.path`.
#
# DEPOIS DA `etapa_assets` E ANTES DO AUTO-REPARO
#   Mesma vizinhança do outro vigia, e pelo mesmo motivo: são as duas unidades
#   `.path` do projeto, e o auto-reparo continua sendo o último de todos.
etapa_vigia_flatpak() {
  passo "Vigia do flatpak (systemd --user)"
  FLATPAK_VIGIA="${FLATPAK_VIGIA:-sim}" "$MEOW_RAIZ/scripts/vigia_flatpak.sh"
  return $?
}

# ---------------------------------------------------------------------------
# O VIGIA DA STEAM — A TERCEIRA UNIDADE `.path` DO PROJETO
#
#   Queixa dela, 02/09/2026: "tem jogo da steam que tá desinstalado mas ainda
#   tem o .desktop, em teoria isso não deveria ocorrer". Estava certa, e o
#   defeito não era da limpeza: a `etapa_jogos` acima remove órfão desde
#   15/08/2026 e faz isso bem. O que faltava era alguém CHAMÁ-LA depois de uma
#   desinstalação — o `jogos_steam.sh` só rodava aqui e no `meow doctor`, então
#   um jogo removido às 3h da tarde deixava o cartão no lançador até as 5h da
#   manhã seguinte.
#
#   Mesmo raciocínio do vigia do flatpak, e a mesma lição do commit `a35b751`:
#   gatilho de EVENTO, não de relógio. O cabeçalho de `systemd/meow-steam.path`
#   traz o resto — por que o evento é o diretório `steamapps/` e não um arquivo,
#   e por que a biblioteca de `/mnt` fica de fora.
#
# LOGO DEPOIS DO IRMÃO, E PELO MESMO MOTIVO
#   São as unidades `.path` do projeto, e elas andam juntas; o auto-reparo
#   continua sendo o último de todos.
# O VIGIA DOS DESENHOS — P88, decisão 15: alterou um desenho de pack, o tema se
#   atualiza sozinho. Depois de todas as etapas que escrevem no tema: registra a
#   tabela das fontes (o que os passos acabaram de derivar) e liga o vigia que
#   refaz o resto. Sem systemd --user, a tabela basta: o doctor das 5h a confere.
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

# ---------------------------------------------------------------------------
# O VIGIA DO HEROIC — A QUINTA UNIDADE `.path` DO PROJETO (10/09/2026)
#
#   Pedido dela, no mesmo dia em que os jogos do Heroic ganharam cartão: "o
#   ponto é que qualquer jogo que eu instalar quero que automaticamente isso se
#   corrija". A `etapa_jogos_heroic` acima escreve e limpa; esta é a que faz
#   isso acontecer SOZINHO, na hora, em vez de esperar o doctor das 5h.
#
#   O evento são os arquivos de `store_cache/` — e não a pasta, e não o
#   `installed.json` do backend. O cabeçalho de `systemd/meow-heroic.path`
#   explica por que cada uma dessas três escolhas seria um gatilho que dorme.
#
# LOGO DEPOIS DOS IRMÃOS, e pelo mesmo motivo: são as unidades `.path` do
# projeto, elas andam juntas, e o auto-reparo continua sendo o último de todos.
etapa_vigia_heroic() {
  passo "Vigia do Heroic (systemd --user)"
  HEROIC_VIGIA="${HEROIC_VIGIA:-sim}" "$MEOW_RAIZ/scripts/vigia_heroic.sh"
  return $?
}

# ---------------------------------------------------------------------------
# O VIGIA DO Qt — A QUARTA UNIDADE `.path` DO PROJETO (09/09/2026)
#
#   O `etapa_apps` acima já põe o `icon_theme` nos dois `.conf` do Qt. O que
#   faltava era alguém repô-lo depois que o COSMIC o desfaz — e ele desfaz na
#   EXPORTAÇÃO DE PARTIDA da sessão, quase todo login. Foram 29 reparos entre
#   04/08 e 06/09/2026, um por pasta datada em
#   `~/.local/state/meowsystem/backups/*/.config/qt5ct`, e entre um login e o
#   doctor das 5h todo aplicativo Qt dela passava o dia com o ícone errado.
#
#   A medição — quem escreve, quando, com milissegundo, e por que o regime
#   permanente do daemon é inocente — está no cabeçalho de
#   `systemd/meow-qt.path`. Não se repete aqui.
#
# POR QUE ESTA ETAPA ESCREVE AS UNIDADES NO LUGAR DE CHAMAR UM `vigia_qt.sh`
#   Os dois irmãos mais novos (`etapa_vigia_flatpak`, `etapa_vigia_steam`)
#   delegam a um script de `scripts/` porque o conserto DELES é próprio. Aqui o
#   conserto já existe e é de outro dono — o módulo `toolkits-gtk-qt`, que a
#   `etapa_apps` e o `meow doctor` já chamam. Um script novo só para instalar
#   duas unidades seria uma terceira cópia da mesma dúzia de linhas de
#   `meow_escrever` + `enable --now`; o `etapa_painel` já faz isso em linha, e é
#   a forma que este segue.
#
# ANDA DE CARONA NO `AUTO_REPARO`, como o supervisor da barra e o carrossel:
#   quem desliga o auto-reparo está dizendo "não mexa sozinho na minha máquina",
#   e um `.path` de inotify é o que mais mexe sozinho no projeto. A segunda
#   cerca é o `APPS_ATIVOS`: quem tirou `qt5ct` da lista pediu para o módulo dos
#   toolkits não rodar, e um vigia que o chamasse assim mesmo seria o instalador
#   desobedecendo a conf dela. As duas cercas são as MESMAS que o
#   `ExecCondition=` da unidade avalia e as mesmas que o `chk_qtvigia` do doctor
#   confere — três lugares, uma regra só.
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
      # Os links de `*.wants/` e `*.requires/` saem à mão pelo mesmo motivo do
      # `etapa_painel`: o `rm` acima é do ARQUIVO, e um link órfão apontando para
      # ele é invisível para `is-enabled`, `is-active` e `--failed`. Só o disco vê.
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

  # O SECO TAMBÉM TEM DE ENXERGAR O GATILHO SOLTO — é a correção de 31/08/2026
  # que o `etapa_painel` e o `etapa_leitura` já carregam: sem isto a auditoria
  # ficava MUDA justamente na máquina em que as unidades estão no disco e só
  # falta armá-las, que é o estado em que o defeito continua acontecendo.
  # `is-enabled` e `is-active` são leitura pura, então o `tests/seco.sh` segue
  # verde com eles aqui.
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
  # A LINHA NÃO É ENFEITE: o `meow_escrever` é MUDO no modo real (quem conta é
  # quem chama), e sem ela uma passagem que reescreveu as duas unidades saía sem
  # UMA palavra na tela e ainda assim caía em `mexeu:` no resumo — exatamente a
  # mentira de relatório que o `concluir()` existe para não deixar acontecer, só
  # que ao contrário. É o que acontece depois de um `git pull` que muda a
  # unidade, e é a passagem em que ela mais precisa saber o que mudou.
  if [ "$mudou" = "1" ]; then
    systemctl --user daemon-reload
    meow_muda "unidades do vigia do Qt instaladas/atualizadas"
    rc=1
  fi
  # `reset-failed` antes do `enable`: enquanto o `.service` estiver em `failed`
  # o `.path` dispara para o vazio, e nem `is-enabled` nem `is-active` do `.path`
  # denunciam isso. Mesma rede do `fix_fundo`.
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

# O PÓS-APT DO COSMIC — 09/10/2026, P76
#   O `meow-pos-apt.path` vigia `/var/lib/meowsystem/apt-mudou`, que a linha
#   root do `99-meow-lancador` toca a cada apt, e o `.service` refaz em escopo
#   de usuário o que o COSMIC novo desfez (`scripts/cosmic_pos_apt.sh`).
#   Anda de carona no `AUTO_REPARO`, como os outros vigias: quem o desliga
#   pediu que nada mexa sozinho. A forma é a do `etapa_vigia_qt`, sem a
#   segunda cerca, que lá é do `APPS_ATIVOS` e aqui não tem par.
#   O GATILHO DEPENDE DO HOOK DE APT, que hoje mora no `99-meow-lancador` e só
#   é instalado com LANCADOR_SISTEMA="sim": sem ele o vigia fica armado e
#   nunca dispara, e o doctor das 5h continua sendo a rede.
#
#   E O LOGIN ENTRA JUNTO — P81, 15/10/2026. O `meow-builds-login.service`
#   confere os builds uma vez por login (o apt feito com ela deslogada não
#   acorda o vigia). Ele é só HABILITADO, nunca `--now`: o `start` de um
#   oneshot espera o build inteiro, e a instalação ficaria meia hora parada.
#   O primeiro login depois da instalação o roda.
#
#   A SENTINELA (P86) vai pela mesma etapa: o `meow-sentinela.timer` mede o COSMIC
#   da fila do apt uma vez por dia, antes de quem usa atualizar. É um timer, então
#   `enable --now` só o arma; a passagem em si espera o relógio. O
#   `meow-sentinela.path` a chama depois de todo apt, para o cartão sair na hora.
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

# A lista das fontes permitidas vai pelo nome novo com o antigo como sinônimo
# (P52, 24/09/2026): `${NOVO-${ANTIGO:-}}` — o novo vence quando existe, mesmo
# vazio. A regra inteira está no `scripts/wallpaper.sh`, no `FONTES_PERMITIDAS`.
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

  # O carrossel vazio se enche sozinho: o `semear-se-faltar`, lá em cima, desce
  # a coleção da origem que o pack declara (`origens.wallpapers`).

  # O RELÓGIO CURTO DO CARROSSEL — por que ele nasceu em 08/08/2026
  #   Algum processo do COSMIC devolveu o `output.DP-1` para a pasta de fábrica
  #   duas vezes em 48 h. Com o reparo só no doctor diário, o estrago das 14:35
  #   de 07/08 ficaria 38 horas no ar — e nesse intervalo a TV dela girava as
  #   imagens da NASA enquanto o `estado` dizia "carrossel ATIVO". Um tique de
  #   15 minutos fecha a janela, e só é seguro porque o `wallpaper.sh` distingue
  #   reversão (conserta) de escolha dela (código 4, não toca) — e desde
  #   11/08/2026 "escolha dela" é o que está na `WALLPAPER_FONTES_PERMITIDAS`,
  #   dito por `meow wallpaper permitir`, e não todo caminho que não seja o de
  #   fábrica.
  #
  #   Anda de carona no `AUTO_REPARO`: quem desliga o auto-reparo está dizendo
  #   "não mexa sozinho na minha máquina", e isto é mexer sozinho.
  local destino="$HOME/.config/systemd/user" u conteudo mudou_t=0
  if [ "${AUTO_REPARO:-sim}" != "sim" ]; then
    # DESLIGAR TEM DE DESLIGAR OS DOIS — E A GUARDA NÃO PODE OLHAR SÓ UM ARQUIVO
    #   Até 25/08/2026 a condição era `[ -f "$destino/meow-wallpaper.timer" ]`,
    #   e com o `meow-fundo.path` no bolo isso virou o modo de falha nº 1: basta
    #   o `.timer` já ter saído (uma passagem anterior, um `rm` à mão) e o
    #   `.path` ter ficado para o bloco inteiro ser PULADO — e um `.path` que
    #   ficou ligado continua vigiando e consertando, que é precisamente o que
    #   `AUTO_REPARO` diferente de "sim" proíbe. Deixar de instalar não desliga
    #   nada: quem desliga é o `disable --now`, e ele precisa ser alcançado.
    #   O `meow_unidade_sobrou` faz as três perguntas (arquivo, estado, link em
    #   `*.wants`) — ver o cabeçalho dele.
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
  # O `@ATIVOS@` do `meow-ativos.path` é substituído aqui, e não deixado como
  # `%h/...`: o `PathModified=` aceita especificadores, mas a base do acervo é
  # configurável (`WALLPAPER_BASE`) e um caminho cravado vigiaria uma pasta que
  # pode não existir — vigia no lugar errado não dá erro, só não faz nada. É a
  # mesma cura do `@ACERVO@` no `scripts/vigia_assets.sh`.
  local _ativos="${WALLPAPER_BASE:-$HOME/.local/share/backgrounds/meowsystem}/ativos"
  for u in meow-wallpaper.service meow-wallpaper.timer meow-fundo.path meow-ativos.path; do
    [ -f "$MEOW_RAIZ/systemd/$u" ] || { meow_erro "falta systemd/$u"; return "$MEOW_ERRO"; }
    conteudo="$(cat "$MEOW_RAIZ/systemd/$u")"
    [ "$u" = "meow-ativos.path" ] && conteudo="${conteudo//@ATIVOS@/$_ativos}"
    meow_escrever "$destino/$u" "$conteudo" 644
    case $? in 1) mudou_t=1 ;; 2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;; esac
  done
  if meow_seco; then
    # O `mudou_t` aqui também sobe quando só o CONTEÚDO de uma unidade mudou
    # (um comentário, por exemplo), e não só quando ela é nova — por isso a
    # frase fala em "instalar/atualizar", e não em "ligar". Dizer "ligaria o
    # relógio" num arquivo que já está ligado é a mentirinha que faz a pessoa
    # procurar problema onde não há.
    #
    # E O TIMER SOLTO TAMBÉM TEM DE APARECER — 22/09/2026
    #   A outra metade da dívida 6 do `docs/SPRINTS.md`, medida junto com a do
    #   `_logo_relogio`: com as quatro unidades já idênticas no disco o
    #   `mudou_t` fica em 0, este ramo saía calado, e o laço lá embaixo — o da
    #   execução real que ela aprova logo em seguida — arma as TRÊS. Aqui as
    #   soltas são NOMEADAS uma a uma em vez de viverem num "algo falta": o
    #   `.timer`, o `.path` da config e o `.path` do acervo falham por motivos
    #   diferentes, e saber qual é qual é o que separa "o carrossel não gira" de
    #   "o carrossel gira mas volta para a pasta de fábrica".
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
  # O RELÓGIO E O GATILHO SÃO UMA DUPLA, NÃO ALTERNATIVAS (25/08/2026)
  #   O `meow-fundo.path` acorda o MESMO serviço no instante em que a config de
  #   fundo muda — porque abrir a janela de papel de parede, só abrir, reseta a
  #   saída ativa para `/usr/share/backgrounds` + `Alphanumeric` (medido; o diff
  #   está no cabeçalho da unidade). O relógio já cobria isso em até 15 minutos,
  #   e é justamente esse quarto de hora que ela reclamou de odiar.
  #   O relógio FICA: gatilho de inotify não sobrevive a tudo (sessão sem watch,
  #   daemon-reload no meio da escrita), e a garantia continua sendo o tempo.
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

# ---------------------------------------------------------------------------
uso() {
  cat <<'FIM'

install.sh — instala o MeowSystem inteiro.

  ./install.sh              faz tudo, sem perguntar nada, e repete a fila até
                            nenhuma etapa precisar escrever (no máximo 5 vezes)
  ./install.sh --dry-run    mostra o que faria, sem escrever nada
  ./install.sh --uma-passagem
                            roda a fila UMA vez e para, mesmo que alguma etapa
                            dependa do resultado da anterior (depuração)
  ./install.sh --wizard     roda `meow configurar` antes (pergunta as chaves do
                            meow.conf, grava lá) e então instala como sempre
  ./install.sh --uninstall  tira o MeowSystem desta máquina
  ./install.sh --help       isto aqui

  MEOW_DRY_RUN=1 ./install.sh   o mesmo que --dry-run, para script e timer

O ensaio é sempre de uma passagem só: no seco nada é escrito, então a etapa que
diverge hoje divergiria igual na passagem seguinte.

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

  local wizard=0 desinstalar=0 uma_passagem=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --wizard|-w) wizard=1 ;;
      # --uma-passagem: o comportamento de ANTES de 21/09/2026, preservado de
      # propósito. Ele não escolhe etapa nenhuma (continua valendo a regra do
      # cabeçalho): diz que esta execução roda a fila UMA vez e termina, mesmo
      # que alguma etapa dependa do resultado da anterior. É a flag de quem está
      # depurando uma etapa e quer ver a primeira passagem sozinha, sem as
      # outras duas por cima no terminal.
      --uma-passagem) uma_passagem=1 ;;
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
         meow_info "o que existe: --dry-run, --uma-passagem, --wizard, --uninstall, --help."
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

  # O CABEÇALHO DIZ O PACK NO AR — 24/09/2026, P51 (achado 24)
  #   Era «MeowSystem — Catppuccin para o COSMIC», o slogan de quando o projeto
  #   era um tema só, e a gaveta do painel o mostrava com o Dracula no ar. O
  #   nome sai da mesma adoção do `meow_pack_dir` (o `adocao` do pack.py), com
  #   o PACK e o FLAVOR do meow.conf, lidos aqui porque o `etapa_conf_ler` vem
  #   depois do wizard. Sem resposta, o cabeçalho perde o nome, e não ganha um
  #   de reserva.
  local nome_pack
  nome_pack="$(python3 "$MEOW_RAIZ/scripts/pack.py" adocao \
                 "${PACK:-$(meow_conf_valor PACK || true)}" \
                 "${FLAVOR:-$(meow_conf_valor FLAVOR || true)}" 2>/dev/null \
               | sed -n 's/^nome=//p')"
  meow_titulo "MeowSystem${nome_pack:+ — $nome_pack} para o COSMIC"
  meow_seco && meow_aviso "ensaio (MEOW_DRY_RUN=1) — nada será escrito"

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

  # A PONTE SHELL -> PYTHON [21/09/2026]
  #   `etapa_gerar` chama `gerar_temas.py` e `gerar_icones_autorais.py`, e os
  #   dois resolvem a paleta por `$MEOW_PALETA`. A variável não era exportada
  #   por ninguém — então os geradores caíam no `catppuccin.json` embutido
  #   SEMPRE, mesmo com um pack ativo. O tema saía do pack no shell e do
  #   embutido no Python, sem uma palavra na tela. O porquê inteiro está no
  #   cabeçalho do `meow_ponte_python`, em lib/comum.sh.
  #
  #   O LUGAR É ESTE, E É ORDEM, NÃO GOSTO:
  #     - DEPOIS do `etapa_conf_ler`, porque a ponte precisa de PACK/FLAVOR para
  #       saber qual pack está ativo;
  #     - DEPOIS do desinstalar, porque quem está indo embora não deve nada à
  #       paleta: recusar a saída por causa de um arquivo de cor seria a pior
  #       recusa que este arquivo poderia dar — o mesmo argumento do bloco acima;
  #     - ANTES do pré-voo e do `meow_travar`, porque quando ela recusa nada foi
  #       escrito ainda, nem o lock foi tomado, nem a senha foi pedida. Uma
  #       paleta que não existe é uma instalação que não pode COMEÇAR, e não uma
  #       que para no meio.
  meow_ponte_python || return 2

  meow_preflight; local rc_pf=$?
  [ "$rc_pf" = "2" ] && return 2

  meow_travar || return 2

  # O auto-reparo é o ÚLTIMO de propósito: ele só faz sentido depois que tudo já foi
  # aplicado uma vez. Ligado antes, o primeiro disparo pegaria a máquina no meio da
  # instalação e "consertaria" o que ainda estava sendo escrito.
  # A CLI vem em segundo, logo depois da configuração: se qualquer etapa daqui
  # para baixo falhar, ela fica com o `meow doctor` na mão para descobrir por quê.
  # O `etapa_backup_tema` ABRE A LISTA, e a posição é o recurso: ele guarda o
  # COSMIC de antes ANTES de a primeira etapa escrever qualquer coisa. Posto
  # depois do `etapa_conf`, ele ainda funcionaria — o conf não mexe no tema —,
  # mas a promessa da tela é "o backup feito antes da instalação", e uma
  # promessa que depende de qual etapa escreve o quê envelhece na primeira
  # etapa nova. Ver o cabeçalho da função.
  local etapas=(etapa_backup_tema etapa_conf etapa_cli etapa_ponte_root etapa_atalho etapa_pacotes etapa_gerar etapa_tema
                etapa_modo etapa_greeter etapa_vidro etapa_forma etapa_painel etapa_janelas etapa_relogio etapa_leitura etapa_escala etapa_upstream etapa_fontes
                etapa_svg etapa_icones etapa_pastas_xdg etapa_pastas etapa_hicolor etapa_completar_icones
                etapa_mimetypes etapa_icones_resgatados etapa_icones_apps_arcticons etapa_icones_apps_dracula etapa_icones_sistema etapa_icones_bandeja
                etapa_icones_tray_steam etapa_icones_tray_zapzap etapa_jogos etapa_jogos_heroic
                etapa_logo etapa_icones_indice etapa_wallpaper etapa_ocultar etapa_nomes etapa_absolutos etapa_ocultar_casa etapa_janela_dock
                etapa_lancador_apt etapa_som etapa_terminal etapa_prompt etapa_fzf etapa_fastfetch_logo etapa_bloco_terminal etapa_files_menu etapa_cursor etapa_flatpak_tema etapa_escritorio etapa_apps
                etapa_assets etapa_vigia_flatpak etapa_vigia_steam etapa_vigia_heroic etapa_vigia_qt etapa_vigia_apt etapa_vigia_derivados
                etapa_midia_build etapa_midia etapa_leitura_applet etapa_lancador etapa_autostart etapa_autoreparo)
  TOTAL=${#etapas[@]}

  # ---------------------------------------------------------------------------
  # O LAÇO DAS PASSAGENS — 21/09/2026
  #
  #   Até hoje este `for` rodava UMA vez e o rodapé terminava com "N etapa(s)
  #   mudaram nesta passagem. Rode mais uma vez" — enquanto o comentário logo
  #   acima dele já sabia que numa máquina nova são TRÊS passagens até o
  #   silêncio. (Aquele comentário, e a spec desta sprint depois dele, punham a
  #   frase no parágrafo 4 do README. Ela nunca esteve lá: `git log -S` não acha
  #   "três passagens" em README.md em ponto nenhum da história, e o parágrafo 4
  #   diz apenas "não escreve um byte". Conferido em 21/09/2026.)
  #
  #   O diagnóstico daquele comentário estava certo e a conclusão estava errada.
  #   A dependência é real e não é bug: o `index.theme` descreve os diretórios
  #   que EXISTEM, e as pastas coloridas nascem na etapa seguinte — é ordem de
  #   construção. O que estava errado era terceirizar o laço. Se quem tem de
  #   saber disso é o instalador, é o instalador quem tem de rodar de novo; a
  #   pessoa não deve nada a esta cadeia.
  #
  # O TETO DE 5 NÃO É ENFEITE
  #   Uma etapa que escreve em TODA passagem é defeito de idempotência, e
  #   escondê-la num laço sem fim seria pior que a frase de ontem: 59 etapas
  #   correndo para sempre, sem ninguém dizendo por quê. Estourar o teto aqui é
  #   um relatório com o nome das culpadas, nunca um silêncio.
  #
  # O ENSAIO É UMA PASSAGEM POR DEFINIÇÃO
  #   No seco nada é escrito, então toda etapa divergente continua divergente na
  #   passagem seguinte: o laço bateria no teto SEMPRE e acusaria defeito de
  #   idempotência onde não há defeito nenhum. O ensaio mostra o que a PRIMEIRA
  #   passagem faria, que é tudo o que ele pode honestamente mostrar.
  local teto=5
  { [ "$uma_passagem" = "1" ] || meow_seco; } && teto=1

  local passagem=0 ainda=0 parar_conf=0 oscilou=0
  local assinatura="" assinatura_anterior=""

  # A TELA RELÊ UMA VEZ, NO FIM — 10/10/2026, P80 (item 7). Três etapas de
  #   ícone pediam o reciclo do painel cada uma (ver "UM RELER POR PASSADA", no
  #   `meow_tela_reler` do lib/comum.sh). A marca nasce aqui, antes da primeira
  #   passagem, e o `meow_tela_reler_no_fim` logo depois do laço relê uma vez.
  #   Sem a marca (o `mktemp` falhou), cada pedido relê na hora, como antes.
  if ! meow_seco; then
    MEOW_RELER_NO_FIM="$(mktemp "${TMPDIR:-/tmp}/meow-reler.XXXXXX" 2>/dev/null)" \
      && export MEOW_RELER_NO_FIM
  fi
  while :; do
    passagem=$((passagem + 1))

    # CADA PASSAGEM TEM O SEU PRÓPRIO PLACAR. Somar as quatro listas entre
    # passagens poria a mesma etapa em `mexeu:` e em `confere:` ao mesmo tempo —
    # a mentira de relatório que o `concluir()` lá em cima veio matar, de volta
    # pela porta da passagem em vez da porta da execução.
    FEITOS=(); CONFEREM=(); PULADOS=(); FALHOS=(); PULADOS_OPTIN=()
    PASSO=0

    # A TELA PRECISA DIZER EM QUAL PASSAGEM ESTÁ. Três passagens de 59 etapas
    # numa máquina fria são quase quatrocentas linhas; sem esta linha a segunda
    # passagem parece o instalador recomeçando do zero — ou travado. O número
    # que ela carrega é o da passagem ANTERIOR, que é justamente a razão de esta
    # aqui existir.
    if [ "$teto" -gt 1 ]; then
      local cabeca="passagem $passagem de até $teto"
      if [ "$passagem" -gt 1 ]; then
        if [ "$ainda" = "1" ]; then
          cabeca="$cabeca · 1 etapa ainda muda"
        else
          cabeca="$cabeca · $ainda etapas ainda mudam"
        fi
      fi
      # E ELA ATRAVESSA O `silencioso`, sozinha entre as linhas deste laço.
      #   Sem tty — o timer, e o `meow aplicar` que a gaveta do painel mostra —
      #   o instalador esconde o progresso e deixa passar só o que mudou. Com
      #   três passagens isso vira três blocos de `~~` iguais, sem nada dizendo
      #   que são passagens da MESMA execução: exatamente o silêncio que parece
      #   travamento. São no máximo cinco linhas no journal, e sem a régua do
      #   `meow_passo`, que ali seria enfeite.
      if meow_quieto; then
        printf '\n  %s%s%s\n' "$C_MAUVE$C_FORTE" "$cabeca" "$C_ZERO"
      else
        meow_passo "$cabeca"
      fi
    fi

    for e in "${etapas[@]}"; do
      "$e"; local rc=$?
      concluir "${e#etapa_}" "$rc"
      # A configuração é a única etapa que não é opcional: sem FLAVOR e ACCENT as
      # seguintes não têm o que aplicar. Parar aqui é honesto; seguir seria morrer
      # com "variável não associada" três etapas adiante, escondendo a causa.
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

    # Um `pulado:` mudo não diz o que fazer — mas dizer a coisa ERRADA é pior que
    # o silêncio. As quatro etapas do `/usr/share` podem se pular por dois motivos
    # (falta de root, ou `LANCADOR_SISTEMA="nao"`, que é opt-in e é o padrão), e
    # cada um tem um conserto diferente. Quem se pulou por opt-in já se anunciou em
    # PULADOS_OPTIN; o que sobrar é que de fato depende de sudo.
    if [ ${#PULADOS[@]} -gt 0 ]; then
      local p por_root=0 sem_captura="" de_root=""
      for p in "${PULADOS[@]}"; do
        case " ${PULADOS_OPTIN[*]:-} " in *" $p "*) continue ;; esac
        # A TELA DE LOGIN SEM TEMA NÃO É FALTA DE ROOT — 25/09/2026, P59. Com
        #   FLAVOR=alucard a gaveta terminou mandando «sudo -v && ./install.sh»:
        #   o `greeter` se pulou porque a captura não existia, antes de olhar o
        #   sudo, e digitar a senha daria o mesmo resumo. O recado é da
        #   `etapa_tema` (o `TEMA_SEM_CAPTURA`, que olha o mesmo par).
        if [ "$p" = "greeter" ] && [ -n "${TEMA_SEM_CAPTURA:-}" ]; then
          sem_captura="$TEMA_SEM_CAPTURA"; continue
        fi
        case "$p" in greeter|ocultar|nomes|absolutos|flatpak_tema|escritorio) por_root=1; de_root="${de_root:+$de_root }$p" ;; esac
      done
      # A RECEITA DO SUDO VIROU PENDÊNCIA — 10/10/2026, P79 (item 5). A frase
      #   terminava em «Para completá-las:  sudo -v && ./install.sh», e dentro
      #   do painel isso é a tela mandando digitar. Agora a pendência
      #   `instalar-com-root` diz QUAIS etapas esperam, e o painel a liga ao
      #   «Instalar tudo» (`ACAO_DA_PENDENCIA`); a passagem que não pula por
      #   root a tira, logo abaixo.
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

    # O `passagem=` entrou na linha do log no mesmo dia do laço: sem ele, três
    # linhas idênticas de uma execução só ficariam indistinguíveis de três
    # execuções que alguém rodou à mão — que é a leitura que este laço aposentou.
    meow_registrar "install.sh passagem=$passagem mexeu=${#FEITOS[@]} conferem=${#CONFEREM[@]} pulados=${#PULADOS[@]} falhos=${#FALHOS[@]}"

    ainda=${#FEITOS[@]}

    # CONVERGIU: a passagem inteira passou sem escrever um byte. É a prova da
    # promessa do README, medida em vez de pedida, e a única saída boa daqui.
    [ "$ainda" -eq 0 ] && break
    [ "$parar_conf" = "1" ] && break
    [ "$passagem" -ge "$teto" ] && break

    # O DETECTOR DE OSCILAÇÃO, E O QUE DÁ PARA MEDIR DAQUI DE DENTRO
    #   O ideal seria comparar o CONTEÚDO que cada etapa escreve. O instalador
    #   não o enxerga: ele enxerga QUAIS etapas escreveram. Duas passagens
    #   seguidas com exatamente o mesmo conjunto em `mexeu:` é a assinatura que
    #   sobra — e ela basta, porque uma passagem que mexeu no mesmo conjunto da
    #   anterior não destravou dependência nenhuma; seguir até o teto seria
    #   repetir mais três vezes um resultado já conhecido.
    #
    #   E o teste é o CONJUNTO, nunca a etapa isolada. A etapa que reaparece na
    #   passagem seguinte é o caso NORMAL desta cadeia: medido em 21/09/2026 num
    #   HOME de brinquedo (tests/convergencia.sh), `fontes` e `icones` escrevem
    #   na passagem 1 e de novo na 2 — a 1 criou os diretórios que a 2 descreve —
    #   e na 3 as duas calam. Cobrar "a mesma etapa duas vezes" acusaria de
    #   defeito justamente o caso que este laço existe para atender.
    assinatura="$(printf '%s\n' "${FEITOS[@]}" | sort | tr '\n' ' ')"
    if [ "$assinatura" = "$assinatura_anterior" ]; then oscilou=1; break; fi
    assinatura_anterior="$assinatura"
  done
  meow_tela_reler_no_fim

  # AS DUAS GUARDAS FALAM ANTES DO BLOCO DAS FALHAS, e a ordem custou uma
  # medição: na primeira versão o `falhou:` devolvia 2 primeiro, e num HOME de
  # brinquedo — onde `systemctl --user` não tem barramento e sete etapas falham
  # por isso — o relatório da oscilação NUNCA chegava à tela. São dois defeitos
  # diferentes: uma etapa que falhou, e um laço que não fechou. Quem tem os dois
  # precisa ler os dois, e o segundo é o que explica por que o instalador parou
  # antes do teto. (21/09/2026)
  local laco_quebrado=0

  # As mesmas etapas, duas passagens seguidas. Nomeá-las é o serviço: "rode mais
  # uma vez" mandava a pessoa descobrir sozinha o que este laço já sabe.
  if [ "$oscilou" = "1" ]; then
    meow_erro "as mesmas etapas escreveram em duas passagens seguidas:  ${FEITOS[*]}"
    meow_aviso "isto não é a cadeia de dependências — é defeito de idempotência:"
    meow_aviso "alguma delas escreve toda vez, e passagem nenhuma vai calá-la."
    meow_aviso "o que olhar primeiro:  meow doctor"
    printf '\n'
    laco_quebrado=1
  # O TETO. Chegar aqui com etapas escrevendo é o cenário que ele existe para
  # expor — e hoje isso ficava escondido atrás de "rode mais uma vez", que a
  # pessoa roda, roda de novo, e desiste sem nunca saber de quem era a culpa.
  #
  # E O `parar_conf` NÃO É CHEGAR AO TETO. O laço tem três saídas com `ainda`
  # ainda positivo: o teto, a oscilação e a conf que não pôde ser lida. Sem esta
  # terceira condição, a saída pela conf caía aqui e a tela dizia "5 passagens,
  # e estas etapas ainda escrevem: backup_tema" depois de UMA passagem — o
  # `etapa_backup_tema` abre a fila e já escreveu quando a conf quebra, então a
  # frase acusava de defeito de idempotência a etapa mais inocente da lista e
  # mandava ao `meow doctor` caçar um problema inexistente. Medido em
  # 21/09/2026 num HOME de brinquedo; na máquina de verdade o caminho é um
  # `~/.config/meow` de dono root depois de um `sudo ./install.sh`. O relatório
  # honesto desse caso é o do `falhou:`, logo abaixo, e ele já estava certo.
  # (A frase continua contando `$teto` e não `$passagem` de propósito: com esta
  # guarda no lugar, a única entrada que sobra é `passagem -ge teto`.)
  elif [ "$ainda" -gt 0 ] && [ "$teto" -gt 1 ] && [ "$parar_conf" != "1" ]; then
    meow_erro "$teto passagens, e estas etapas ainda escrevem:  ${FEITOS[*]}"
    meow_aviso "parei no teto de propósito: um laço sem fim esconderia o defeito."
    meow_aviso "o que olhar primeiro:  meow doctor"
    printf '\n'
    laco_quebrado=1
  fi

  if [ ${#FALHOS[@]} -gt 0 ]; then
    # NUM ENSAIO NADA É APLICADO — 24/09/2026, sprint P50 (achado 11). O
    # rodapé dizia "o resto foi aplicado" também no «Ver sem mudar», com a
    # faixa da gaveta dizendo «nada foi escrito» no alto da mesma saída. Ensaio
    # não deixa nada pela metade porque não começa nada: a frase diz isso.
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

  # O TEMA QUE NÃO CHEGOU AO COSMIC NÃO TERMINA EM «Pronto» — 24/09/2026, P48
  #   Achado 31 da validação: com o acento sem captura, a etapa `tema` se pulava,
  #   o instalador saía 0 com "Pronto. [...] nada mais a escrever", e o painel
  #   pintava «MEXEU E APLICOU» com o desktop na cor de antes. Desde a P48 o
  #   acento se deriva, e desde a P59 o flavor sem foto sai de outro do mesmo
  #   lado: isso só sobra para o flavor sem fotografia dele nem de outro do
  #   mesmo lado que se reproduza — e, nesse caso, o que a pessoa pediu no
  #   meow.conf e o que a tela mostra DIVERGEM: é o 1 do projeto, e a última
  #   linha diz qual é a divergência. A pendência (`tema-sem-captura`, na
  #   etapa) é a outra metade, na Início.
  #   No ensaio a etapa já disse o que faria, e o rodapé dele segue o de sempre.
  if [ -n "${TEMA_NAO_APLICADO:-}" ] && ! meow_seco; then
    printf '\n  %s%s%s\n' "$C_AMARELO$C_FORTE" "$TEMA_NAO_APLICADO" "$C_ZERO"
    # A ABA SAI DO `--onde` — P57: o nome da Início era escrito aqui à mão.
    local onde; onde="$(meow_onde_no_painel inicio)"
    printf '  O resto do instalador seguiu; a pendência fica no painel%s.\n\n' "${onde:+, $onde}"
    return "$MEOW_DIVERGENTE"
  fi

  # UMA PASSAGEM SÓ (--uma-passagem, ou o ensaio): o rodapé de antes, preservado
  # inteiro. A diferença é a linha do meio — quem fecha o laço agora é o
  # instalador, e a pessoa não precisa mais contar passagem nenhuma.
  #   NO ENSAIO O VERBO É O DO QUE MUDARIA — revisão da P50, a linha do achado
  #   11: o ensaio sem falha não chega ao rodapé de cima, e terminava aqui
  #   dizendo «mudaram» com a faixa «nada foi escrito» no alto da gaveta.
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

  # UMA FRASE SÓ, E ELA DIZ QUANTO CUSTOU. "Nada é escrito duas vezes" é a
  # promessa; o número de passagens é a prova dela na tela, sem ela precisar
  # contar linha nenhuma — e sem ninguém pedir que ela rode de novo para saber.
  local plural="passagens"
  [ "$passagem" = "1" ] && plural="passagem"
  printf '\n  %sPronto.%s %d %s, %d etapas, nada mais a escrever.\n\n' \
    "$C_VERDE$C_FORTE" "$C_ZERO" "$passagem" "$plural" "$TOTAL"
  return 0
}

main "$@"

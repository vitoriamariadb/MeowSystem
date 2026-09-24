#!/usr/bin/env bash
# assets/temas-de-apps/qbittorrent/manifesto.sh — o tema do pack no qBittorrent.
#
# ATÉ 22/09/2026 A PRIMEIRA LINHA DIZIA "Catppuccin Mocha no qBittorrent", e ela
# era honesta sobre o que o arquivo fazia: 28 citações daquele nome, e nenhuma
# pergunta ao pack ativo. Quem escolhe o tema agora é o `apps.qbittorrent` do
# pack.json — ver o bloco da identidade, logo abaixo do cabeçalho.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Nada de `exit`, nada de `set -e`:
# um `exit` aqui derrubaria o runner inteiro no meio do catálogo.
#
# ─────────────────────────────────────────────────────────────────────────────
# LEIA ISTO ANTES DE MEXER: o qBittorrent NÃO é nosso território.
# ─────────────────────────────────────────────────────────────────────────────
# O tema do qBittorrent é escrito pelo Ritual da Aurora, em
# `~/.config/zsh/scripts/aurora-qbittorrent-config.sh`, que o self-heal roda a
# cada ciclo (de hora em hora, no boot e depois de todo apt). Esse script:
#
#   1. resolve o tema por uma allowlist FECHADA — `dracula|andromeda|nenhum`;
#   2. REBAIXA para `dracula` qualquer valor que não conheça (o `*)` do case);
#   3. grava `Preferences/General/UseCustomUITheme` e `CustomUIThemePath` como
#      chaves ESTRUTURAIS, ou seja, reforçadas SEMPRE (não são "gosto");
#   4. sobrescreve o arquivo de estado `~/.local/state/aurora/qbittorrent-tema`
#      com o nome já rebaixado.
#
# Consequência medida, não suposta: escrever `catppuccin` no `qBittorrent.conf`
# por fora seria desfeito em até uma hora, E o arquivo de estado voltaria a
# dizer `dracula` — deixando a Vitória com um tema que "some sozinho" e sem
# nenhuma pista de por quê. Esse é exatamente o tipo de sintoma bizarro dias
# depois que a TRAVA 1 do `lib/comum.sh` existe para evitar.
#
# Por isso este módulo é HONESTO em vez de esperto: enquanto `catppuccin` não
# estiver na allowlist do Aurora, ele devolve MEOW_SEM_DEPENDENCIA (3) e imprime
# o patch exato que destrava. Ele NÃO edita o script do Aurora — aquilo mora em
# `~/.config/zsh`, o repo com auto-commit em 10 minutos, e a própria
# `meow_destino_permitido` recusaria a escrita.
#
# ─────────────────────────────────────────────────────────────────────────────
# DESTRAVOU. O texto acima descreve o passado — atualizado em 25/08/2026.
# ─────────────────────────────────────────────────────────────────────────────
# O patch foi aplicado: `aurora-qbittorrent-config.sh:74` tem o case
# `catppuccin)`, e a máquina confirma que o tema está no ar:
#
#   ~/.local/state/aurora/qbittorrent-tema            -> catppuccin
#   .../qBittorrent/qBittorrent.conf UseCustomUITheme -> true
#   .../qBittorrent/qBittorrent.conf CustomUIThemePath -> .../catppuccin-mocha.qbtheme
#
# O código deste módulo SEMPRE esteve certo: `_meow_qbt_aurora_destravado` lê a
# allowlist ao vivo, então ele passou a aplicar sozinho no dia em que o Aurora
# mudou. Quem ficou para trás foi esta prosa — e por dias o `doctor` dizia uma
# coisa e o manifesto dizia outra. Achado pela auditoria de documentação de
# 25/08/2026, que é o motivo de este bloco existir em vez de o texto de cima ser
# simplesmente apagado: o raciocínio da trava continua valendo se o Aurora um dia
# reverter a allowlist.
#
# Quando destravar, o módulo continua NÃO escrevendo o `qBittorrent.conf`: ele
# instala o `.qbtheme`, grava o arquivo de estado e chama o próprio script do
# Aurora com `--tema catppuccin`. Quem escreve o conf segue sendo o Aurora, que
# é o único escritor que ninguém reverte. Dois donos no mesmo arquivo é o começo
# de toda guerra de idempotência.
#
# O PREÇO DESSA DELEGAÇÃO, dito na cara: `aurora-qbittorrent-config.sh` não é um
# aplicador de tema, é a configuração INTEIRA do qBittorrent. Chamá-lo também
# cria a árvore de `/mnt/Apate/Torrents`, aplica os overrides do flatpak, gera as
# credenciais da WebUI, escreve o `categories.json` e — se houver algo a mudar e
# nenhum download em andamento — FECHA e reabre o aplicativo. É o mesmo que o
# self-heal já faz de hora em hora, então não há efeito novo no sistema; mas
# significa que `meow_app_aplicar` pode reiniciar o cliente de torrent dela, e
# isso não pode ser surpresa para quem lê este arquivo depois.
#
# ─────────────────────────────────────────────────────────────────────────────
# ARMADILHA DO BINÁRIO: `meow_escrever` NÃO serve aqui.
# ─────────────────────────────────────────────────────────────────────────────
# O `.qbtheme` é um Qt Binary Resource (`.rcc`, magic `qres`) cheio de bytes NUL.
# A `meow_escrever` recebe o conteúdo como STRING, e toda substituição de comando
# do bash (`$(cat arquivo)`) descarta os NUL e come os newlines finais — o tema
# chegaria ao destino corrompido, e o qBittorrent subiria sem estilo nenhum
# logando só "Failed to load UI theme". Por isso a cópia binária tem função
# própria aqui embaixo, com o mesmo cuidado atômico da `meow_escrever`:
# temporário criado DENTRO do diretório de destino (o repo mora em /mnt/Apate e
# o destino em /home — `mv` entre eles não seria atômico) e `mv -f` no fim.
#
# ─────────────────────────────────────────────────────────────────────────────
# TRÊS MANEIRAS DE ESTE MÓDULO MENTIR — todas reproduzidas em sandbox e fechadas
# ─────────────────────────────────────────────────────────────────────────────
#   1. Deduzir "apliquei" do exit code do Aurora. Com download em andamento ele
#      ADIA a gravação do conf e sai 0; o módulo devolvia 1 ("apliquei") em toda
#      rodada, para sempre, sem o conf jamais mudar. Agora o veredito sai de uma
#      RECONFERÊNCIA do estado real (passo 4 do `meow_app_aplicar`).
#   2. Tratar "script do Aurora ausente" como "liberado". O módulo instalava o
#      tema, não escrevia o conf e, na segunda rodada, devolvia 0 ("nada a
#      fazer") enquanto o `meow_app_conferir` devolvia 1 — dois códigos
#      contraditórios para o mesmo estado. Agora é 3, com o motivo na tela.
#   3. Prometer o qBittorrent NATIVO. O escritor do conf (o script do Aurora) é
#      flatpak-only; o caminho nativo levava ao mesmo laço eterno do item 1.
#      Agora é 3 declarado, não meia-boca silenciosa.
#
# Procedência do arquivo, commit pinado e sha256: veja a `PROCEDENCIA.md` que
# mora ao lado da arte, dentro do pack — para o pack padrão,
# `packs/catppuccin/apps/PROCEDENCIA.md`. Ela saiu daqui em 22/09/2026 junto com
# o `.qbtheme`: a procedência viaja com a arte, e a arte agora é do pack.
# Lá também está registrado que o acento upstream é AZUL (#89b4fa), não o mauve
# da casa — medido descomprimindo o `config.json` de dentro do `.rcc`.

# --- identidade do módulo ---------------------------------------------------
MEOW_QBT_APP_ID="org.qbittorrent.qBittorrent"

# O TEMA VEM DO PACK — 22/09/2026, sprint P18
#   As três linhas que estavam aqui cravavam o nome do tema, o nome do arquivo e
#   o sha256 dele. Um módulo que sabe de cor essas três coisas é o aplicador
#   DAQUELE tema, e não o aplicador do tema da casa — e a conta do dia mediu o
#   mesmo desenho em oito módulos, com 446 citações da palavra `catppuccin` e
#   zero consultas ao pack ativo.
#
#   O QUE ELAS VIRARAM
#     MEOW_QBT_ORIGEM       `apps.qbittorrent.arquivo`, já resolvido em caminho
#                           absoluto pelo pack.py (pack -> herança).
#     MEOW_QBT_ARQUIVO      o basename daquele caminho. Ele continua existindo
#                           porque é o nome DO DESTINO dentro de `themes/`, e o
#                           conf do qBittorrent aponta para lá.
#     MEOW_QBT_SHA256       `apps.qbittorrent.sha256`. Quem confere o número na
#                           publicação agora é o `pack.py validar`; aqui ele
#                           segue sendo conferido antes de instalar, que é a
#                           defesa contra o download que virou página de erro.
#     MEOW_QBT_NOME_AURORA  o ID DO PACK QUE RESPONDEU, e a coincidência não é
#                           coincidência: a allowlist do script do Aurora é
#                           `dracula|andromeda|catppuccin|nenhum`, e dois desses
#                           quatro nomes são ids de pack deste projeto. Um tema
#                           que venha do pack `catppuccin` entra no estado do
#                           Aurora como `catppuccin`, como sempre entrou.
#
#   VAZIO É RESPOSTA, E O `_meow_qbt_pronto` a transforma num 3 com motivo: pack
#   que não declara `apps.qbittorrent` (nem herda de quem declare) não tem tema
#   para este app, e inventar um seria aplicar o tema de outro pack e chamar de
#   sucesso — que é exatamente o defeito medido no módulo do Obsidian.
#
#   SEM `$( )` AQUI, E O MOTIVO CUSTOU UM DEFEITO — 22/09/2026, revisão da P18
#     Estas linhas eram `X="$(meow_app_tema_do_pack …)"`, com o
#     `MEOW_QBT_NOME_AURORA` lido logo abaixo. `$( )` é subshell: a função
#     atribuía a variável num processo que morria na mesma linha, e o nome do
#     pack chegava VAZIO — medido, com PACK=catppuccin, `MEOW_QBT_NOME_AURORA=[]`.
#     Hoje a função não imprime nada e responde pelas duas variáveis; chamá-la
#     dentro de `$( )` devolveria string vazia na hora, que é o defeito alto em
#     vez de escondido.
meow_app_tema_do_pack qbittorrent.arquivo
MEOW_QBT_ORIGEM="$MEOW_APP_TEMA"
MEOW_QBT_NOME_AURORA="$MEOW_APP_TEMA_PACK"
MEOW_QBT_ARQUIVO="$(basename -- "${MEOW_QBT_ORIGEM:-sem-tema}")"
meow_app_tema_do_pack qbittorrent.sha256
MEOW_QBT_SHA256="$MEOW_APP_TEMA"

# A DEPENDÊNCIA FANTASMA SAIU DO CÓDIGO — 22/09/2026, sprint P29
#   A linha era, cravada:
#
#       MEOW_QBT_AURORA_FONTE="$HOME/.config/zsh/scripts/aurora-qbittorrent-config.sh"
#
#   e o comentário ao lado explicava que o self-heal do Aurora roda a cópia de
#   `~/.config/zsh/scripts/` antes de instalar em `/usr/local/bin`. A P2 já
#   tinha tirado o caminho das MENSAGENS de tela; o que sobrou foi esta linha,
#   que é a última a apontar para a árvore da vizinha em código deste módulo.
#
#   E ELA NÃO APONTAVA PARA LUGAR NENHUM. Medido em 22/09/2026, arquivo por
#   arquivo: `aurora-qbittorrent-config.sh` não existe em `~/.config/zsh` —
#   um `find ~/.config/zsh -name '*qbittorrent*'` devolve ZERO linha. Não é
#   "está no outro projeto": é uma dependência de um arquivo que não existe em
#   lugar nenhum, e a P29 foi buscá-lo para confirmar que não há de onde trazer.
#   O alcance instável que a P2 mediu (uma cópia num `sshfs` da outra máquina)
#   continua não servindo de conserto, pelo motivo dela.
#
#   O PADRÃO É VAZIO, E O VAZIO É A RESPOSTA CERTA
#     Sem escritor do `qBittorrent.conf` o módulo já fazia a coisa certa —
#     devolver `MEOW_SEM_DEPENDENCIA` (3) e registrar a pendência sem botão.
#     Com o padrão vazio, `[ -f "" ]` falha e é exatamente esse caminho que se
#     percorre; nada no comportamento muda, porque o arquivo já não existia. O
#     que muda é a honestidade do código: ele deixa de afirmar que sabe onde
#     está um escritor que ninguém tem.
#
#     Quem TIVER um escritor aponta a variável para ele. É a mesma porta de
#     escape do `CP_SERIE` e do `MEOW_ZSH_ENV`, e é o que faz este módulo
#     obedecer à regra 7 da P29 sem inventar um segundo dono para o
#     `qBittorrent.conf` — que é o começo de toda guerra de idempotência, como
#     o cabeçalho deste arquivo diz desde 25/08/2026.
MEOW_QBT_AURORA_FONTE="${MEOW_QBT_AURORA_FONTE:-}"
MEOW_QBT_AURORA_ESTADO="$HOME/.local/state/aurora/qbittorrent-tema"

# Todo aviso estrutural sai UMA vez por processo: o runner chama
# detectar+conferir+aplicar em sequência e três cópias do mesmo parágrafo viram
# ruído que ninguém lê.
MEOW_QBT_JA_AVISOU=0          # a receita de destravamento
MEOW_QBT_AVISOU_NATIVO=0      # "só o flatpak é coberto"
MEOW_QBT_AVISOU_SEM_AURORA=0  # "o script do Aurora não está aqui"

# ─────────────────────────────────────────────────────────────────────────────
# auxiliares
# ─────────────────────────────────────────────────────────────────────────────

# Onde o qBittorrent guarda a config. Só o FLATPAK conta aqui (5.2.3, via
# flathub), e não é preguiça: este módulo delega a escrita do `qBittorrent.conf`
# ao script do Aurora, e aquele script é flatpak-only por construção — ele abre
# com `command -v flatpak || exit 0` e `flatpak info "$APP" || exit 0`.
#
# MEDIDO em sandbox, não suposto: com o caminho nativo previsto aqui e o Aurora
# saindo 0 sem fazer nada, `meow_app_aplicar` devolvia 1 ("apliquei") em TODA
# rodada, para sempre, e o conf nunca era escrito. Prometer uma instalação que a
# única ferramenta de escrita não enxerga é a armadilha de idempotência da casa:
# dizer OK sem consertar nada. Enquanto ninguém escrever o conf nativo, o nativo
# é ausência DECLARADA (3, com aviso), não meia-boca silenciosa.
_meow_qbt_conf_dir() {
  meow_tem flatpak || return 1
  # por diretório, não por `flatpak info`: aquele cria o repositório ostree no
  # home só por ser perguntado, e detecção não pode escrever (ver lib/comum.sh).
  meow_flatpak_tem "$MEOW_QBT_APP_ID" || return 1
  printf '%s' "$HOME/.var/app/$MEOW_QBT_APP_ID/config/qBittorrent"
}

# Existe um qBittorrent nativo? Serve só para explicar o 3 em vez de sumir.
_meow_qbt_avisar_nativo() {
  [ "$MEOW_QBT_AVISOU_NATIVO" = "1" ] && return 0
  MEOW_QBT_AVISOU_NATIVO=1
  meow_aviso "há um qBittorrent NATIVO instalado, mas este módulo cobre só o flatpak"
  meow_info  "(quem escreve o conf é o script do Aurora, que é flatpak-only)"
  return 0
}

# A FRASE PAROU DE CITAR O SCRIPT DO VIZINHO — 22/09/2026, sprint P2
#   Ela dizia, com o caminho por extenso: "sem
#   ~/.config/zsh/scripts/aurora-qbittorrent-config.sh não há quem escreva o
#   qBittorrent.conf". Três defeitos numa linha só, e os três medidos:
#
#   1. mandava a pessoa arranjar um arquivo que NÃO É DESTE PROJETO. Quem clona
#      este repositório nunca terá aquele caminho, e a frase não dizia isso;
#   2. o arquivo tem origem conhecida e ALCANCE INSTÁVEL. Medido em
#      22/09/2026: ele está em `Remotos/Andromeda-OS/usr/local/bin/`, 27.253
#      bytes, e aquele caminho é um `sshfs` da outra máquina
#      (`<usuário>@meowsystem.local:/`, fuse.sshfs, 58 G). Estava montado na
#      hora da medição — e é justamente por isso que ele não serve de conserto:
#      um botão que depende de a rede e o host do outro lado estarem de pé
#      promete o que não entrega na metade das vezes;
#   3. era receita sem conserto, que é exatamente a classe de falha que a P2
#      está apagando do projeto inteiro.
#
#   A saída é a TERCEIRA da sprint: quando nem o botão é possível, a mensagem
#   diz A DECISÃO, não a receita. A decisão é esta — este módulo instala o
#   `.qbtheme`, e escrever o `qBittorrent.conf` não é escopo dele. A pendência
#   nasce SEM comando de propósito, e o painel a desenha sem botão.
#
#   O QUE NÃO MUDOU, E POR QUE — MEDIDO EM 22/09/2026, na revisão da P2
#   A revisão cobrou o resto: tirar também as duas chamadas a
#   `bash "$MEOW_QBT_AURORA_FONTE"` (no `aplicar` e no `reverter`). A do
#   `aplicar` até dá; a do `reverter` NÃO, e o motivo está três passos abaixo,
#   no passo 3 do próprio `meow_app_reverter`:
#
#     Quem escreve o `qBittorrent.conf` é o script do vizinho, a partir do
#     estado `~/.local/state/aurora/qbittorrent-tema`. Se o `reverter` parar
#     de rodá-lo (e de virar aquele estado, que também é dele), o self-heal
#     continua reescrevendo o conf apontando para o NOSSO `.qbtheme`. O passo
#     3 então se recusa a remover o arquivo — e se recusa com razão, porque um
#     `CustomUIThemePath` apontando para arquivo inexistente abre o app sem
#     interface. Resultado: `meow apps reverter qbittorrent` e o passo 2/6 do
#     `--uninstall` passariam a dizer "o conf ainda aponta, rode de novo com o
#     app ocioso" PARA SEMPRE, porque nada mais faria o conf deixar de apontar.
#
#   A sprint escreveu a disjunção olhando para o `aplicar` ("ou o conf é
#   escrito aqui, ou a etapa declara que o conf não é escopo dela"); ela não
#   alcançou o `reverter`, e é no `reverter` que a delegação deixa de ser
#   preferência e vira a única saída que não quebra a máquina dela. Tirar a
#   delegação inteira exige primeiro decidir quem desfaz, e isso é uma sprint,
#   não uma linha.
#
#   O que a P2 pediu de verdade — que nenhuma MENSAGEM termine em "faça você
#   mesmo" — está feito: o tutorial de 20 linhas que ficava logo abaixo virou
#   pendência sem comando, e nenhum caminho deste arquivo imprime mais um
#   endereço de `~/.config/zsh` como lição de casa.
#
# VESTIDO POR ELA, NÃO HÁ O QUE ESPERAR — 24/09/2026, sprint P53 (achado 3)
#   Medido no painel de verdade: a Home dizia «não há comando meu que resolva»
#   com o qBittorrent vestido pelo `dracula.qbtheme` que ela escolheu — uma
#   linha sem saída sobre uma coisa que não estava faltando. A escolha que as
#   outras pendências de tema ganharam («Trocar pelo tema do pack» / «Manter o
#   meu», ver `meow_app_tema_no_ar`) aqui só tem um lado que se entrega: sem
#   escritor do conf, «Trocar» seria o botão que promete e some. Então, com o
#   app vestido, o que vale é o «Manter o meu», e ele não precisa de clique: a
#   linha sai, e o `_meow_qbt_dizer_o_ar` diz no log que fica como está. Sem
#   tema nenhum no app a linha continua, porque aí falta mesmo alguma coisa.
_meow_qbt_avisar_sem_aurora() {
  [ "$MEOW_QBT_AVISOU_SEM_AURORA" = "1" ] && return 0
  MEOW_QBT_AVISOU_SEM_AURORA=1
  if [ -n "$(_meow_qbt_no_ar)" ]; then
    meow_pendencia_resolvida qbittorrent-conf-fora-de-escopo
    return 0
  fi
  meow_pendencia_acionavel qbittorrent-conf-fora-de-escopo \
    "O tema do qBittorrent é instalado por aqui; escrever o qBittorrent.conf não é escopo deste módulo, e não há comando meu que resolva" \
    ""
  return 0
}

# O Aurora conhece `catppuccin`? Lemos o script VIVO em vez de guardar um
# "já destravei" em disco: assim, no minuto em que a Vitória acrescentar o case,
# este módulo passa a funcionar sozinho — e se ela desfizer, ele volta a travar
# sozinho também. Marcador em arquivo de estado seria a armadilha clássica de
# dizer "OK" sem que nada tenha sido consertado.
#
# Script ausente é NÃO-destravado, e não o contrário: quem não tem o Aurora não
# tem escritor do conf, e a `_meow_qbt_pronto` já barra esse caso antes com um
# 3 explicado. Tratar ausência como "liberado" fazia o módulo instalar o tema,
# não escrever o conf e, na segunda rodada, devolver 0 ("nada a fazer") enquanto
# a `meow_app_conferir` devolvia 1 — dois códigos contraditórios para o mesmo
# estado (reproduzido em sandbox).
#
# NOME VAZIO É NÃO-DESTRAVADO, E A GUARDA NÃO É PARANOIA — 22/09/2026, revisão
# da P18. Sem ela o regexp vira `^[[:space:]]*\)`, que casa QUALQUER linha cujo
# primeiro caractere não-branco seja `)` — fechamento de subshell indentado, que
# é padrão comum em shell: medidos 32 dos próprios `.sh` deste repositório
# casariam. Numa máquina que tenha o script do Aurora, isso destravava o módulo
# sozinho, gravava estado vazio em `~/.local/state/aurora/qbittorrent-tema` e
# chamava o script de terceiro com `--tema ''`. Pack sem tema para este app tem
# de parar no 3 explicado do `_meow_qbt_pronto`, não passar por destravado.
_meow_qbt_aurora_destravado() {
  [ -n "$MEOW_QBT_NOME_AURORA" ] || return 1
  [ -f "$MEOW_QBT_AURORA_FONTE" ] || return 1
  grep -qE "^[[:space:]]*${MEOW_QBT_NOME_AURORA}\)" "$MEOW_QBT_AURORA_FONTE"
}

# O TUTORIAL DE 20 LINHAS SAIU DA TELA — 22/09/2026, sprint P2
#   Esta função imprimia, com `meow_info`, a receita inteira de destravamento:
#   o caminho por extenso do script do outro projeto, o número da linha
#   resolvido ao vivo, as duas edições para copiar e colar, e um parágrafo
#   explicando em qual das duas cópias editar. Era a mais longa das seis
#   mensagens que a sprint P2 veio apagar, e a mais crua: o programa descobre o
#   problema, sabe o conserto até o número da linha, e manda a pessoa consertar.
#
#   O QUE FICA NA TELA É A DECISÃO, que é a terceira saída da sprint. A decisão
#   é genuinamente dela e genuinamente humana: o qBittorrent é configurado por
#   OUTRO projeto seu, cuja lista de temas é fechada; enquanto o `catppuccin`
#   não entrar naquela lista, este módulo não tem o que aplicar. Nenhum botão
#   daqui pode resolver isso — a `meow_destino_permitido` recusa escrever em
#   `~/.config/zsh`, e com razão: é um repositório com auto-commit em 10
#   minutos, e um conserto nosso lá dentro viraria um commit que ela não fez.
#
#   A RECEITA NÃO SE PERDEU, MUDOU DE LUGAR: ela é isto aqui, comentário, onde
#   quem abre o arquivo a lê e quem só usa o programa não tropeça nela. São
#   duas edições no `aurora-qbittorrent-config.sh`:
#
#     1) um case novo, logo depois da linha do `andromeda)` (achável com
#        `grep -nE '^[[:space:]]*andromeda\)'`):
#              catppuccin) TEMA_PATH="$TEMAS_DIR/catppuccin-mocha.qbtheme" ;;
#     2) o texto de uso, de `[--tema dracula|andromeda|nenhum]` para
#        `[--tema dracula|andromeda|catppuccin|nenhum]`.
#
#   E edite a FONTE em `~/.config/zsh/scripts/`, não a cópia em
#   `/usr/local/bin`: o self-heal roda a fonte e reinstala a cópia por cima.
#
#   O guarda de "uma vez por processo" continua: o runner chama
#   detectar+conferir+aplicar em sequência, e três cópias da mesma linha viram
#   ruído — a pendência já é uma linha por id, mas o `meow_aviso` que ela
#   imprime no log não é.
_meow_qbt_receita() {
  [ "$MEOW_QBT_JA_AVISOU" = "1" ] && return 0
  MEOW_QBT_JA_AVISOU=1
  meow_pendencia_acionavel qbittorrent-tema-fora-da-lista \
    "O qBittorrent é configurado por outro projeto seu, cuja lista de temas é fechada — enquanto o tema '$MEOW_QBT_NOME_AURORA' não estiver na lista dele, não há como eu vestir o app" \
    ""
  return 0
}

# Backup obrigatório antes de sobrescrever qualquer arquivo dela.
_meow_qbt_backup() {
  local alvo="$1" dir base
  [ -e "$alvo" ] || return 0
  base="$(basename "$alvo")"
  # Carimbo ISO com `-` no lugar do `:` — é o formato que os outros módulos já
  # usam em `backups/` (ex.: 2026-08-04T20-14-44). Todos escrevem no MESMO
  # diretório, então o nome tem de ser uniforme para a pasta continuar legível;
  # e dois-pontos em nome de pasta ainda incomoda rsync, tar e a ponte LAN.
  dir="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/${_MEOW_QBT_ISO:-$(date +%Y-%m-%dT%H-%M-%S)}"
  mkdir -p "$dir" || { meow_erro "não consegui criar $dir"; return 1; }
  cp -a -- "$alvo" "$dir/$base" || { meow_erro "backup de $alvo falhou"; return 1; }
  meow_info "backup: $dir/$base"
  return 0
}

# Cópia BINÁRIA atômica — a `meow_escrever` corromperia o .rcc (ver cabeçalho).
# Devolve MEOW_OK se já estava igual, MEOW_DIVERGENTE se copiou, MEOW_ERRO se falhou.
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

# --- O QUE O APP ESTÁ VESTINDO AGORA — 22/09/2026, sprint P18 ---------------
#
# A MEDIÇÃO QUE FALTAVA, E ELA ESTAVA NO DISCO O TEMPO TODO
#   Em 21/09/2026, nesta máquina:
#     ~/.var/app/…/qBittorrent/qBittorrent.conf
#         General\UseCustomUITheme    = true
#         General\CustomUIThemePath   = /home/<usuário>/.themes/dracula.qbtheme
#     ~/.themes/dracula.qbtheme        4.468 bytes, escrito às 16:49 do mesmo dia
#
#   E o módulo dizia «não há quem escreva o qBittorrent.conf» — enquanto o conf
#   JÁ ESTAVA ESCRITO, com um tema que o MeowSystem não conhecia. Ele conferia a
#   própria receita e nunca o estado da máquina, então o trabalho que ele tinha
#   feito à mão era invisível para o programa.
#
#   Estas duas funções são a leitura que faltava. Elas NÃO decidem nada: quem
#   decide é o `meow_app_tema_no_ar` (lib/comum.sh), com as três saídas.
_meow_qbt_no_ar() {
  local conf_dir conf
  conf_dir="$(_meow_qbt_conf_dir)" || return 0
  conf="$conf_dir/qBittorrent.conf"
  [ -f "$conf" ] || return 0
  # `grep -F` e não regex: a chave tem uma barra invertida no nome, que num grep
  # comum é escape — é a mesma pedra em que o `meow_app_conferir` tropeçou e
  # documentou trinta linhas abaixo. `UseCustomUITheme=false` é "sem tema", e
  # não "tema vazio": o caminho pode continuar escrito e desligado.
  grep -qxF 'General\UseCustomUITheme=true' "$conf" || return 0
  grep -F 'General\CustomUIThemePath=' "$conf" | head -1 | cut -d= -f2-
  return 0
}

# Onde o nosso `.qbtheme` fica depois de instalado. É o valor que o conf tem de
# apontar para o tema ser considerado "o do pack".
_meow_qbt_alvo() {
  local conf_dir
  conf_dir="$(_meow_qbt_conf_dir)" || return 1
  printf '%s' "$conf_dir/themes/$MEOW_QBT_ARQUIVO"
}

# QUANDO NÃO DÁ PARA ESCREVER, A MEDIÇÃO É DITA SEM PERGUNTA
#   Perguntar "trocar pelo tema do pack?" num caminho em que ninguém escreve o
#   conf seria oferecer o que não se entrega — a classe de falha que a P2 apagou
#   do projeto inteiro. Então, nos dois caminhos travados abaixo, o que vai para
#   a tela é o FATO: o app está vestido, e não por nós. A pergunta fica para
#   quando houver escritor, no fim do `_meow_qbt_pronto`.
#
#   Uma vez por processo, como os outros três avisos deste arquivo: o runner
#   chama detectar+conferir+aplicar em sequência.
# O VEREDITO SAI UMA VEZ POR AÇÃO, E FICA GUARDADO
#   Dentro de um `meow_app_aplicar` o `_meow_qbt_pronto` roda três vezes (ele
#   mesmo, e mais duas pelo `meow_app_conferir` que o `aplicar` chama). Sem o
#   cache, a pergunta "trocar pelo tema do pack?" apareceria três vezes na
#   mesma passagem — e duas delas de dentro de um `>/dev/null 2>&1`, onde a
#   pessoa veria um cursor parado sem saber o que ele espera.
#
#   O QUE É GUARDADO É O VEREDITO, NÃO O "JÁ PERGUNTEI": o código de saída
#   precisa continuar chegando igual a cada chamada, senão o `conferir` que vem
#   depois do `detectar` acharia que está tudo bem.
#
# A PERGUNTA SÓ VALE DENTRO DO `aplicar` — 22/09/2026, revisão da P18
#   Este veredito é lido pelos TRÊS verbos, porque o `_meow_qbt_pronto` é o
#   núcleo comum deles. Mas `detectar` e `conferir` são LEITURA (o painel serve
#   a tabela com `escreve: False`), e um `meow apps conferir qbittorrent`
#   parava num «trocar pelo tema do pack? [s/N]» que, respondido `s`, imprimia
#   "trocando … a pedido dela" e não trocava nada — cada ação roda num subshell
#   próprio do `aplicar_apps.sh`, então a resposta morria ali. Prometer escrita
#   dentro de uma leitura é a classe de falha que esta sprint veio matar.
#
#   Por isso o `pergunte` é ligado pelo `meow_app_aplicar`, e só por ele. O
#   `reverter` também escreve e mesmo assim fica de fora: ele está DESFAZENDO o
#   nosso tema, e oferecer "trocar pelo tema do pack?" no meio disso seria
#   perguntar o contrário do que ela mandou fazer.
#
#   O cache continua fazendo o serviço dele: dentro do `aplicar` a pergunta
#   acontece na primeira passagem, com o interruptor já ligado, e as duas
#   releituras do `conferir` interno caem no veredito guardado.
MEOW_QBT_VEREDITO_AR=""
MEOW_QBT_PODE_PERGUNTAR=""
_meow_qbt_ar_ok() {
  if [ -z "$MEOW_QBT_VEREDITO_AR" ]; then
    meow_app_tema_no_ar qbittorrent "$(_meow_qbt_no_ar)" "$(_meow_qbt_alvo)" \
                        "$MEOW_QBT_NOME_AURORA" "$MEOW_QBT_PODE_PERGUNTAR"
    MEOW_QBT_VEREDITO_AR=$?
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
  meow_aviso "o qBittorrent já está vestido: $no_ar"
  meow_info  "não veio daqui, e fica como está — o tema do pack não é escrito por cima"
  return 0
}

# 0 = o programa está nesta máquina · 1 = não está. A regra de "instalado" que
# a tabela do `meow apps` pergunta e o `detectar` abre com ela (24/09/2026, P49;
# ver o quinto verbo no `rodar_modulo` do scripts/aplicar_apps.sh).
# O nativo conta: ele É o qBittorrent instalado, e o módulo sempre o reconheceu
# (o aviso logo abaixo); só não o veste, porque o escritor do conf é flatpak.
meow_app_instalado() { meow_flatpak_tem "$MEOW_QBT_APP_ID" || meow_tem qbittorrent; }

# ─────────────────────────────────────────────────────────────────────────────
# núcleo comum das três funções: dá para trabalhar? (0 = sim, 3 = não)
# ─────────────────────────────────────────────────────────────────────────────
# As três funções públicas precisam desta mesma checagem, mas ela NÃO pode ser
# feita chamando `meow_app_detectar` silenciado: o guarda de "imprime a receita
# uma vez só" marcaria como já-avisado no chamado mudo, e a receita nunca
# chegaria à tela. Por isso o núcleo é separado do relato.
_meow_qbt_pronto() {
  meow_app_instalado || { meow_pula "qBittorrent não instalado"; return "$MEOW_SEM_DEPENDENCIA"; }
  # Instalado, e sem a pasta do flatpak ao alcance: ou é o nativo, ou é o
  # flatpak sem o comando `flatpak` — nos dois casos, nada para vestir.
  _meow_qbt_conf_dir >/dev/null || {
    if meow_tem qbittorrent; then
      _meow_qbt_avisar_nativo
    else
      meow_pula "qBittorrent: falta o comando flatpak"
    fi
    return "$MEOW_SEM_DEPENDENCIA"
  }
  # O PACK PRECISA TER PEDIDO ALGUMA COISA — 22/09/2026, sprint P18.
  # Ausência declarada, e não escolha nossa: ver o bloco da identidade, no topo.
  if [ -z "$MEOW_QBT_ORIGEM" ]; then
    meow_pula "o pack ativo não declara tema para o qBittorrent (apps.qbittorrent no pack.json)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -s "$MEOW_QBT_ORIGEM" ]; then
    meow_aviso "falta o tema em $MEOW_QBT_ORIGEM (veja a PROCEDENCIA.md do pack para rebaixar)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  # Sem o script do Aurora não há escritor para o conf: dependência faltando (3),
  # nunca um "apliquei" pela metade.
  if [ ! -f "$MEOW_QBT_AURORA_FONTE" ]; then
    # A MEDIÇÃO VEM ANTES DA TRAVA — 22/09/2026, sprint P18.
    #   Era aqui que o módulo dizia "não há quem escreva o qBittorrent.conf"
    #   com o conf já escrito, e com um tema que ele não conhecia. Os dois
    #   fatos são verdadeiros e os dois vão para a tela, nesta ordem: primeiro
    #   o que o app está vestindo, depois por que não mexemos nisso.
    _meow_qbt_dizer_o_ar
    _meow_qbt_avisar_sem_aurora
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  meow_pendencia_resolvida qbittorrent-conf-fora-de-escopo
  if ! _meow_qbt_aurora_destravado; then
    _meow_qbt_dizer_o_ar
    _meow_qbt_receita
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  # AS IRMÃS DO CAMINHO FELIZ (lib/comum.sh, 22/09/2026): daqui para baixo
  # nenhuma das duas pendências deste módulo continua sendo verdade, e pendência
  # que sobrevive ao problema é a caixa de entrada que ninguém lê.
  meow_pendencia_resolvida qbittorrent-tema-fora-da-lista
  # --- LER O QUE ESTÁ NO AR ANTES DE ESCREVER — 22/09/2026, sprint P18 -------
  #   Só chega aqui quem PODE escrever, e é por isso que a pergunta mora neste
  #   ponto: perguntar "trocar?" antes de saber que há escritor seria oferecer o
  #   que não se entrega. As três saídas estão em `meow_app_tema_no_ar`; a
  #   terceira — tema de terceiro no lugar — devolve 3 e o arquivo dele fica
  #   intocado, que é a diferença entre consertar um defeito e trocá-lo por um
  #   pior.
  #
  #   No `_pronto` e não no `aplicar` de propósito: o `conferir` também precisa
  #   dizer a verdade sobre um app vestido por fora, e ele nunca passa pelo
  #   `aplicar`.
  _meow_qbt_ar_ok
  [ $? = "$MEOW_SEM_DEPENDENCIA" ] && return "$MEOW_SEM_DEPENDENCIA"
  return "$MEOW_OK"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_detectar — 0 se dá para trabalhar, 3 se não dá. Nunca falha.
# ─────────────────────────────────────────────────────────────────────────────
# A trava do Aurora entra AQUI, e não como erro, de propósito: para o runner,
# "o Aurora não me deixa escrever este tema" é indistinguível de uma dependência
# faltando — não há nada a consertar do nosso lado, e reportar divergência
# eterna a cada ciclo treinaria a Vitória a ignorar o relatório. 3 é o código
# que faz o auto-reparo ficar quieto; a receita impressa é o que dá o próximo passo.
meow_app_detectar() {
  _meow_qbt_pronto || return "$MEOW_SEM_DEPENDENCIA"
  meow_ok "qBittorrent presente e o Aurora conhece '$MEOW_QBT_NOME_AURORA'"
  return "$MEOW_OK"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_conferir — 0 aplicado, 1 divergente, 3 ausente/travado.
# ─────────────────────────────────────────────────────────────────────────────
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

  # A chave no INI é `General\CustomUIThemePath`. A barra invertida é escape de
  # regex num grep comum — o teste daria sempre "não bate" e o módulo se
  # declararia divergente para sempre. Por isso: grep -F, literal. (É a mesma
  # pedra em que o próprio script do Aurora tropeçou e documentou.)
  #
  # E `-x` junto do `-F`: sem casar a LINHA INTEIRA, um valor que apenas CONTÉM
  # o nosso caminho passaria por bom — `...=/outro/lugar/catppuccin-mocha.qbtheme.bak`
  # ou um prefixo diferente que termine igual. O Aurora usa `grep -qxF` pela
  # mesma razão. O conf real (linha 107 aqui) é exatamente `chave=valor`, sem
  # espaço nem CR, então o `-x` é seguro.
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

  # O estado do Aurora tem de concordar, senão o próximo ciclo desfaz tudo.
  [ "$(cat "$MEOW_QBT_AURORA_ESTADO" 2>/dev/null)" = "$MEOW_QBT_NOME_AURORA" ] || {
    meow_muda "o estado do Aurora não diz '$MEOW_QBT_NOME_AURORA'"
    divergiu=1
  }

  if [ "$divergiu" = "0" ]; then
    meow_ok "qBittorrent com o tema do pack $MEOW_QBT_NOME_AURORA aplicado"
    return "$MEOW_OK"
  fi
  return "$MEOW_DIVERGENTE"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_aplicar — 0 nada a fazer, 1 aplicou, 2 erro, 3 ausente/travado.
# ─────────────────────────────────────────────────────────────────────────────
meow_app_aplicar() {
  # O interruptor da pergunta, e ele mora AQUI porque é daqui para baixo que se
  # escreve — ver o bloco do `_meow_qbt_ar_ok`. Antes do `_meow_qbt_pronto` de
  # propósito: é ele quem faz a leitura, na primeira das três passagens.
  MEOW_QBT_PODE_PERGUNTAR="pergunte"
  _meow_qbt_pronto || return "$MEOW_SEM_DEPENDENCIA"

  meow_app_conferir >/dev/null 2>&1 && {
    meow_ok "qBittorrent já está com o tema do pack $MEOW_QBT_NOME_AURORA — nada a fazer"
    return "$MEOW_OK"
  }

  # Um carimbo só para toda a aplicação: os arquivos salvos nesta passada têm de
  # cair na MESMA pasta de backup, senão desfazer vira caça ao tesouro.
  _MEOW_QBT_ISO="$(date +%Y-%m-%dT%H-%M-%S)"
  # Sem contador de "mudou" de propósito: quem decide o código de saída no fim é
  # a RECONFERÊNCIA do estado real, não a soma dos passos que tentamos. Ver o
  # comentário do passo 3.
  local conf_dir destino rc
  conf_dir="$(_meow_qbt_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  destino="$conf_dir/themes/$MEOW_QBT_ARQUIVO"

  # Integridade antes de instalar: um download que virou página de erro HTTP
  # tem o tamanho e o nome certos e só falha lá na frente, dentro do app, com um
  # "Failed to load UI theme" que não diz nada. Conferimos o sha256 pinado.
  #
  # SHA VAZIO É "O PACK NÃO DECLAROU", E NÃO "NÃO CONFERE" — 22/09/2026
  #   O número saiu daqui para o `apps.qbittorrent.sha256` do pack.json, e o
  #   formato o faz OPCIONAL. Sem esta guarda, um pack que traga o `.qbtheme` e
  #   não declare o sha cairia direto no `[ "$soma" != "" ]`, que é sempre
  #   verdade: o módulo recusaria para sempre um arquivo perfeito, com uma
  #   mensagem dizendo "esperado , veio f6ddf5…". Errar assim é pior do que não
  #   conferir, porque a frase acusa o arquivo em vez de acusar a declaração.
  #
  #   E a ausência não passa calada: quem instala um tema sem procedência
  #   conferível merece saber disso na hora, e não descobrir depois. O aviso sai
  #   só neste caminho, que é o da instalação de verdade — e não a cada
  #   conferência, que seria ruído sobre algo que ninguém vai consertar hoje.
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

  # --- 1. o arquivo do tema -------------------------------------------------
  _meow_qbt_instalar_tema "$MEOW_QBT_ORIGEM" "$destino"
  rc=$?
  case "$rc" in
    0) : ;;
    # No seco a `_meow_qbt_instalar_tema` já disse "instalaria" — repetir aqui
    # como "instalado" faria o dry-run mentir que escreveu.
    1) meow_seco || meow_muda "tema instalado em $destino" ;;
    *) meow_erro "não consegui instalar o .qbtheme"; return "$MEOW_ERRO" ;;
  esac

  # --- 2. o estado do Aurora ------------------------------------------------
  # É por este arquivo que o Aurora decide o tema quando ninguém passa --tema.
  # Sem escrevê-lo, o próximo ciclo do self-heal leria `dracula` e reverteria.
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

  # --- 3. o conf, escrito por quem é dono dele ------------------------------
  # NÃO tocamos no qBittorrent.conf. Chamamos o script do Aurora, que sabe
  # fechar o app antes de gravar (ele reescreve o conf inteiro ao sair) e que
  # tem a guarda de não matar o app com download em andamento — guarda que
  # existe porque em 2026-08-02 um download de minissérie foi perdido assim.
  if meow_seco; then
    meow_muda "rodaria: $MEOW_QBT_AURORA_FONTE --tema $MEOW_QBT_NOME_AURORA"
    return "$MEOW_DIVERGENTE"
  fi

  # Chegar aqui com o script ausente é impossível: a `_meow_qbt_pronto` já barrou
  # esse caso com 3. Sem essa pré-condição o módulo instalaria o tema e nunca
  # escreveria o conf, terminando em 0 com o app ainda em Dracula.
  meow_info "delegando o conf ao Aurora (ele é o dono do qBittorrent.conf)"
  if ! bash "$MEOW_QBT_AURORA_FONTE" --tema "$MEOW_QBT_NOME_AURORA"; then
    meow_erro "o script do Aurora falhou ao aplicar o tema"
    return "$MEOW_ERRO"
  fi

  # --- 4. o veredito sai do ESTADO REAL, não do exit code do Aurora ---------
  # MEDIDO em sandbox: com download em andamento, o Aurora imprime "NÃO vou
  # fechar", ADIA a gravação do conf e sai 0. Deduzir "apliquei" desse 0 fazia
  # `meow_app_aplicar` devolver 1 em toda rodada, para sempre, sem nunca ter
  # escrito o conf — enquanto a `meow_app_conferir` seguia dizendo 1 também.
  # Reconferir custa um `flatpak info` e dois greps, e é o que impede o módulo
  # de mentir. Só chegamos até aqui porque a conferência inicial acusou
  # divergência, então nenhum caminho daqui para baixo pode devolver 0.
  if meow_app_conferir >/dev/null 2>&1; then
    meow_ok "qBittorrent com o tema do pack $MEOW_QBT_NOME_AURORA aplicado"
    # O aviso do acento sai só quando o tema de fato ficou vivo — repeti-lo a
    # cada ciclo em que o Aurora adiou seria ruído sobre algo que ela ainda nem
    # viu na tela. Honestidade sobre o visual, medido em PROCEDENCIA.md.
    # O AVISO DO ACENTO MUDOU DE DONO — 22/09/2026, sprint P18
    #   A frase cravava as duas cores porque o módulo cravava o tema. Hoje o
    #   arquivo vem do pack, e o que se pode afirmar aqui é o que é verdade para
    #   QUALQUER `.qbtheme` de terceiro: ele traz as cores dele, e o acento da
    #   casa não entra num `.rcc` sem reempacotar o binário. O inventário do que
    #   é azul no tema do pack padrão está na `apps/PROCEDENCIA.md` dele.
    meow_aviso "atenção: o acento deste .qbtheme é o do tema upstream, e não o da paleta — ver a PROCEDENCIA.md do pack"
    return "$MEOW_DIVERGENTE"
  fi
  meow_aviso "o Aurora rodou mas o conf ainda não reflete o tema — ele adia a gravação"
  meow_aviso "quando há download em andamento (fechar o app perderia progresso)."
  meow_aviso "nada se perdeu: o tema já está no disco e o próximo ciclo ocioso aplica."
  return "$MEOW_DIVERGENTE"
}

# --- DESFAZER (11/08/2026) --------------------------------------------------
# Chegam aqui `meow apps reverter qbittorrent` e o passo 2/6 do `--uninstall`.
#
# QUEM ESCREVE O CONF CONTINUA SENDO O AURORA — inclusive para desfazer.
#   O `aplicar` delega porque o `qBittorrent.conf` é território dele e porque só
#   ele sabe fechar o app sem matar download em andamento. Desfazer pela nossa
#   mão aqui seria abrir uma segunda porta para o mesmo arquivo, justamente no
#   caminho que roda uma vez na vida e ninguém testa de novo.
#
# O DESTINO É `dracula`, E NÃO "SEM TEMA"
#   A allowlist do Aurora é `dracula|andromeda|catppuccin|nenhum`, e `dracula` é
#   o que ele usa quando o estado não diz nada (`TEMA=dracula`, no próprio
#   script). Era o que estava lá antes de nós; é para lá que devolvemos. Pedir
#   `nenhum` deixaria o app cru, que não é o estado anterior — seria uma terceira
#   escolha, tomada por nós, em nome dela.
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

  if meow_seco; then
    [ -f "$destino" ] && meow_muda "removeria $destino"
    [ "$estado" = "$MEOW_QBT_NOME_AURORA" ] && \
      meow_muda "gravaria '$_MEOW_QBT_TEMA_AURORA_PADRAO' em $MEOW_QBT_AURORA_ESTADO"
    meow_muda "rodaria: $MEOW_QBT_AURORA_FONTE --tema $_MEOW_QBT_TEMA_AURORA_PADRAO"
    return "$MEOW_DIVERGENTE"
  fi

  # 1. o estado do Aurora PRIMEIRO. Se a ordem se invertesse e algo falhasse no
  #    meio, o self-heal leria 'catppuccin' no próximo ciclo e reaplicaria tudo
  #    — desfazer que se desfaz sozinho é pior do que não desfazer.
  #    Escrita direta, não `meow_escrever`: este arquivo é do Aurora, e registrá-lo
  #    no manifesto faria o desinstalador apagar o estado dele no passo seguinte.
  if [ "$estado" = "$MEOW_QBT_NOME_AURORA" ]; then
    if printf '%s' "$_MEOW_QBT_TEMA_AURORA_PADRAO" > "$MEOW_QBT_AURORA_ESTADO" 2>/dev/null; then
      mudou=1; meow_muda "estado do Aurora -> $_MEOW_QBT_TEMA_AURORA_PADRAO"
    else
      meow_erro "não consegui gravar $MEOW_QBT_AURORA_ESTADO"
      return "$MEOW_ERRO"
    fi
  fi

  # 2. o conf, pelo dono dele.
  meow_info "delegando o conf ao Aurora (ele é o dono do qBittorrent.conf)"
  if ! bash "$MEOW_QBT_AURORA_FONTE" --tema "$_MEOW_QBT_TEMA_AURORA_PADRAO"; then
    meow_erro "o script do Aurora falhou ao devolver o tema"
    return "$MEOW_ERRO"
  fi

  # 3. só agora o nosso arquivo sai — e só se o conf tiver deixado de apontar
  #    para ele. Remover antes de o Aurora reescrever o conf deixaria o
  #    qBittorrent com CustomUIThemePath para um arquivo inexistente, que é como
  #    se abre um app sem interface.
  if [ -f "$destino" ]; then
    if grep -qxF "General\\CustomUIThemePath=$destino" "$conf_dir/qBittorrent.conf" 2>/dev/null; then
      meow_aviso "o conf ainda aponta para $destino — o Aurora adiou a gravação (download em andamento?)"
      meow_aviso "o .qbtheme fica onde está; rode de novo com o app ocioso"
    elif rm -f "$destino"; then
      mudou=1; meow_muda "tema removido de $destino"
    fi
  fi

  [ "$mudou" = "0" ] && { meow_ok "qBittorrent já estava sem o tema do pack"; return "$MEOW_OK"; }
  meow_ok "qBittorrent de volta ao tema $_MEOW_QBT_TEMA_AURORA_PADRAO do Aurora"
  meow_info "tire 'qbittorrent' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}

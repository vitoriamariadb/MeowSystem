#!/usr/bin/env bash
# compositor_patches.sh — os patches do `cosmic-comp` ainda estão de pé?
#
# O `conferir` NÃO CONSERTA NADA, E ISSO CONTINUA SENDO O DESENHO
#   O conserto de tudo o que ele mede é **recompilar o compositor** — `cargo`,
#   ~4 min, um install em `/usr/bin/cosmic-comp`. O `meow doctor` nunca usa
#   sudo, nunca baixa, nunca compila e nunca escreve configuração; e um build de
#   4 minutos disparado pelo timer das 05:00 seria pior que o defeito que ele
#   corrige. Então o `conferir` é leitura pura de três arquivos e de um `/proc`.
#
#   O QUE MUDOU EM 22/09/2026 (P29) É PARA ONDE ELE APONTA
#     A frase daqui era "quem conserta é ela, com uma linha:
#     aurora-cosmic-comp-ws.sh --build". A P22 mediu que aquele script não
#     existe nesta máquina nem neste repositório: o doctor mandava, todo dia,
#     rodar um comando inexistente. Agora existe `aplicar`, neste arquivo, que
#     põe a série numa árvore de fonte. Compilar e instalar seguem sendo passo
#     dela — ver o bloco do `cmd_aplicar` para por que a linha cai exatamente
#     ali e não um passo adiante.
#
#   E O QUE MUDOU EM 24/09/2026 (P39) É QUEM COMPILA
#     A regra do dono, de 23/09: o que o MeowSystem usa do Ritual da Aurora
#     migra para cá e é desativado lá, sem "integração opcional". O build do
#     compositor era o caso mais pesado: sem o `aurora-cosmic-comp-ws.sh`, que
#     não vem neste repositório, ninguém fora desta casa tinha os patches — e
#     em 21/09 o apt reescreveu o `/usr/bin/cosmic-comp` daqui sem que nada
#     do lado de cá soubesse refazer. Agora o `compilar` deste arquivo baixa o
#     fonte da versão instalada, aplica a série, compila, confere os
#     marcadores no binário e instala, pedindo `sudo` só no último passo. O
#     `meow compositor` é o rosto dele. O script da Aurora virou um aviso que
#     aponta para cá.
#
#     A LINHA DO `aplicar` CONTINUA ONDE ESTAVA, e é por isso que o verbo novo
#     é outro: o `aplicar` ainda nunca compila, e o doctor ainda nunca chama o
#     `compilar`. Compilar é comando de gente, com a senha na mão — nunca de
#     timer, porque este binário é também a tela de login.
#
#     A VERSÃO PASSOU A SER CONTRATO: `patches/versao` diz contra qual pacote a
#     série foi validada, e o `compilar` recusa qualquer outra dizendo por quê.
#
#     E O `.estado` MUDOU DE CASA: é o nosso, em `/var/lib/meowsystem/`, gravado
#     pelo nosso `compilar`. O `/var/lib/aurora` e a série instalada pelo Ritual
#     em `/usr/local/share/aurora/` deixaram de ser lidos.
#
# POR QUE A PERGUNTA É SOBRE O PROCESSO, E NÃO SOBRE O ARQUIVO
#   `/var/lib/aurora` guarda SEIS versões de `cosmic-comp` entre 13/07 e 26/08 —
#   quase semanal. Todo `apt upgrade` do pacote reescreve `/usr/bin/cosmic-comp`
#   e leva junto os patches da Aurora, **calado**: o sintoma é um workspace vazio
#   a mais no painel, ou a tela azul de novo à noite, dias depois, sem culpado.
#
#   E há um segundo estado, que é o que faz este arquivo ter duas mensagens em
#   vez de uma: o `--build` já rodou, o binário no DISCO está patchado, e a
#   sessão dela continua rodando o binário ANTERIOR — o kernel segura o inode
#   aberto até o próximo login. Isso não é defeito nenhum e não há o que fazer
#   hoje; dizer "FALTA o patch" nessa hora mandaria ela recompilar de graça.
#
#       FALTA <marcador>                              -> o build precisa ser refeito
#       <marcador> está no disco mas NÃO na sessão    -> vale no próximo login
#
#   As duas nunca se colapsam numa só. É o item 6 da Sprint U.
#
#   Por que o doctor e não `notify-send`: o Não Perturbe dela engoliu 22 avisos
#   entre 27 e 28/08/2026. A tabela do doctor ela lê; o balãozinho, não.
#
# ============================================================================
# O QUE FOI MEDIDO EM 30/08/2026, NESTA MÁQUINA, ANTES DE ESCREVER UMA LINHA
# ============================================================================
#
# 1. A SESSÃO VIVA É LEGÍVEL SEM SUDO
#      pgrep -x cosmic-comp            -> 3261
#      ls -l /proc/3261/exe            -> dono <usuário>, -> /usr/bin/cosmic-comp
#    O `/proc/<pid>/exe` abre o inode que o processo REALMENTE mapeou, mesmo
#    depois de o caminho ter sido substituído por um `apt`. É essa a diferença
#    entre a coluna "sessão" e a coluna "disco" daqui.
#
# 2. `strings` NÃO É PRECISO — `grep -a -o` BASTA
#    Medido nos dois alvos, com o mesmo resultado do `strings -a`:
#      grep -a -o 'AURORA-COSMIC-WS-PATCH-[0-9][0-9.]*' /usr/bin/cosmic-comp
#      grep -a -o 'AURORA-COSMIC-WS-PATCH-[0-9][0-9.]*' /proc/3261/exe
#        -> AURORA-COSMIC-WS-PATCH-3.67   (nos dois)
#    Uma dependência a menos (binutils) para um verificador que roda todo dia.
#
# 3. O REGEX TEM DE SER ESTREITO — E ISTO CUSTARIA UM FALSO AMARELO
#    O que o binário tem, cru, é:
#        AURORA-COSMIC-WS-PATCH-3.67assertion
#    O símbolo seguinte do `.rodata` cola no marcador, sem separador. Um regex
#    guloso (`[0-9A-Za-z._-]*`) devolveria `...3.67assertion`, que não casa com o
#    marcador declarado, e o doctor gritaria "FALTA" todo dia sobre um patch que
#    está aplicado. Daí `-[0-9][0-9.]*`: dígitos e pontos, e para.
#
# 4. O ESTADO DE HOJE, QUE É AMARELO E ESTÁ CERTO
#      /var/lib/aurora/cosmic-comp-patches.estado   -> NÃO EXISTE
#      /usr/local/share/aurora/patches.d/series     -> NÃO EXISTE
#      ~/.config/zsh/patches/                       -> só cosmic-comp-sem-workspace-vazio.patch
#      disco e sessão                               -> AURORA-COSMIC-WS-PATCH-3.67, e só ele
#      dpkg-query -W cosmic-comp                    -> 0.1~1787767625~24.04~5c93094
#    Ou seja: o build com a série ainda não rodou (é o passo 1 da Sprint U, do
#    lado da Aurora), e o `cosmic-comp-raio-clampado.patch` continua sem entrar
#    em binário nenhum. Amarelo aqui é a resposta certa, não bug deste arquivo.
#
# 5. O QUE ESTE VERIFICADOR **NÃO** ALCANÇA, E É PRECISO DIZER
#    O patch de night light do `aurora-night-light.py` é patch BINÁRIO: ele
#    reescreve o bloco `if (color_mode == 1.0)` do shader GLSL embutido, e o
#    rastro que deixa é um comentário dentro do shader —
#        // NIGHT LIGHT (Aurora)     (conferido no binário de hoje: está lá)
#    — não um `static &str` com marcador `AURORA-*`. Ele não está na série, não
#    tem marcador no formato deste arquivo, e portanto **não é conferido aqui**.
#    Um build novo o apaga (item 4 da Sprint U: build -> re-patch binário ->
#    --ensure). Quem quiser cobri-lo precisa de outro verificador, com outro
#    critério; fingir que este cobre seria pior do que a lacuna.
#
# ============================================================================
# A SEGUNDA CONFERÊNCIA — E É ELA O MOTIVO DA SPRINT U EXISTIR
# ============================================================================
#   O `cosmic-comp-raio-clampado.patch` passou SEMANAS em `patches/`, com o
#   README dizendo que estava em produção, sem nunca entrar em binário nenhum:
#   o `aurora-cosmic-comp-ws.sh` aplicava UM `.patch` só, por caminho literal, e
#   nada no mundo comparava a lista dele com a nossa. Um patch que existe no
#   repositório e não está declarado na série é um patch que NÃO ACONTECE — e o
#   jeito de isso não voltar a acontecer é uma linha na tabela do doctor.
#
#   Por isso, além dos marcadores, este arquivo pergunta:
#     a) todo `.patch` de `patches/` está declarado na `series`?
#     b) (SAIU EM 22/09/2026, P29) o `.patch` do repositório é BYTE A BYTE igual
#        à cópia que a Aurora aplica? Eram duas cópias em duas árvores e nada as
#        sincronizava. A P29 não melhorou a resposta — tirou a pergunta: os
#        cinco `.patch` e a `series` moraram para cá, e uma pasta não diverge de
#        si mesma. Ver o bloco 5 do `cmd_conferir`, que ficou vago com o motivo.
#   A que restou é por nome de arquivo, sem abrir o conteúdo.
#
# ============================================================================
# A FRONTEIRA (docs/FRONTEIRA.md) — REDESENHADA EM 22/09/2026 PELA P29
# ============================================================================
#   O texto daqui dizia: "o binário `cosmic-comp`, o `aurora-cosmic-comp-ws.sh`,
#   o `.estado` e a `series` são da **Aurora**". Três dos quatro continuam
#   sendo. A `series` NÃO: ela é tema — é quem sabe classe, ordem, marcador e
#   colisão de arquivo —, e a decisão dela de 21/09/2026 trouxe o que é tema
#   para cá. Desde 22/09 a série mora em `patches/series`, versionada, com os
#   cinco `.patch` que ela declara.
#
#   O QUE SAIU DE VEZ: qualquer leitura de `~/.config/zsh`. Não há mais
#   `CP_COPIA`, não há mais `md5sum` contra a árvore da vizinha, não há mais a
#   linha "só do lado da Aurora". O repositório privado dela, com auto-commit a
#   cada 10 min, deixou de ser assunto deste arquivo — e a TRAVA 1 do
#   `lib/comum.sh` continua recusando escrita ali, para quem tentar.
#
#   O QUE CONTINUA DELA: o binário em `/usr/bin/cosmic-comp`, o `.estado` em
#   `/var/lib/aurora/` e o `aurora-cosmic-comp-ws.sh`, que numa máquina que fez
#   o Ritual é quem compila. Este arquivo lê os dois primeiros e não escreve em
#   nenhum.
#
#   (24/09/2026, P39: o parágrafo acima é história. O `.estado` e o build são
#   nossos — ver "O QUE MUDOU EM 24/09/2026" no topo. Do outro lado não sobra
#   nada que este arquivo leia.)
#
# O CONTRATO DO `.estado` (o formato é o de 30/08/2026, e ficou o mesmo)
#   /var/lib/meowsystem/cosmic-comp/patches.estado  (644, root, legível sem sudo)
#     # gravado pelo meow compositor — NAO EDITAR A MAO
#     versao=0.1~1788962084~24.04~a557859
#     gravado=2026-09-24T01:40:00-03:00
#     req AURORA-COSMIC-WS-PATCH-3.67 cosmic-comp-sem-workspace-vazio.patch presente
#     opt AURORA-COSMIC-RADIUS-PATCH-2 cosmic-comp-raio-clampado.patch presente
#   Linha de patch = QUATRO campos: <req|opt> <marcador> <arquivo.patch> <presente|ausente>
#   O FORMATO NÃO MUDOU NA MUDANÇA DE DONO, de propósito: o `cmd_conferir`
#   inteiro lê este texto, e um formato novo seria reescrever o leitor junto
#   com a troca de quem escreve — dois riscos numa passagem só.
#
#   patches/series — a CÓPIA CANÔNICA desde 22/09/2026 (P29), neste repositório.
#     <classe req|opt> <arquivo.patch> <marcador-base>
#   patches/versao — a versão do pacote contra a qual a série vale (P39).
#
#   O marcador do `.estado` traz a VERSÃO no fim (`-3.67`); o da `series` é a
#   BASE (`AURORA-COSMIC-WS-PATCH`). É de propósito: a base é o que sobrevive a
#   um bump de versão do patch, e é ela que vira regex no binário. O prefixo
#   `AURORA-` fica: ele está compilado dentro dos `.patch`, e trocá-lo seria
#   mexer em cinco patches validados para mudar um nome.
#
# USO
#   compositor_patches.sh conferir            0 = tudo de pé · 1 = divergente · 3 = sem cosmic-comp
#   compositor_patches.sh aplicar <dir-fonte> põe a série numa árvore de fonte do cosmic-comp
#   compositor_patches.sh compilar            baixa o fonte, aplica, compila e instala (sudo no fim)
#   compositor_patches.sh validar             baixa o fonte da versão instalada e só roda o dry-run
#   compositor_patches.sh reverter            diz como voltar ao binário do pacote (não roda)
#   compositor_patches.sh ativar              liga o shim em ~/.local/bin (P76; vale no próximo login)
#   compositor_patches.sh desativar           desliga o shim: o próximo login volta a /usr/bin
#   compositor_patches.sh qual                o binário que o próximo login vai rodar
#   compositor_patches.sh guardar             leva o fonte baixado do cache para ~/.local/share
#   (o rosto de todos é o `meow compositor`; MEOW_DRY_RUN=1 é o `--seco` dele)
#
#   O 0 cobre DOIS estados desde 21/09/2026: os patches de pé, e os patches
#   nunca aplicados nesta máquina — sem `.estado` não houve promessa, e sem
#   promessa não há o que divergir. O porquê está no bloco 1 do `cmd_conferir`.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# Todos com override por variável: é o que deixa testar sem root e sem mexer na
# máquina dela. Nenhum deles vira chave do meow.conf — não há nada a configurar
# aqui, e uma chave a mais no conf é uma pergunta a mais no wizard sem resposta
# útil (o caminho do `.estado` é contrato deste arquivo, não gosto de ninguém).
CP_BIN="${CP_BIN:-/usr/bin/cosmic-comp}"
# A CASA ROOT DO BUILD — 24/09/2026, P39. `/var/lib`, e não o
# `/usr/local/lib/meowsystem` da ponte: lá mora programa, aqui mora dado que o
# programa grava (o `.estado` e a cópia do binário do pacote). É a divisão do
# FHS, e é a mesma que o `/var/lib/aurora` fazia do outro lado.
CP_LIB="${CP_LIB:-/var/lib/meowsystem/cosmic-comp}"
CP_ESTADO="${CP_ESTADO:-$CP_LIB/patches.estado}"
CP_REPO="${CP_REPO:-$MEOW_RAIZ/patches}"
# A versão do pacote contra a qual a série foi validada. Ver o próprio arquivo.
CP_VERSOES="${CP_VERSOES:-$MEOW_RAIZ/patches/versao}"
# ONDE O FONTE É BAIXADO E COMPILADO. Cache, e não estado: apagar esta pasta
# custa um download e uma compilação do zero (~30 min), nunca um dado. Cada
# árvore compilada pesa ~3,2 GB (medido do outro lado, em 28/08/2026), e por
# isso o `compilar` poda as de outra versão depois de um build que deu certo.
CP_CACHE="${CP_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem/cosmic-comp}"
# O FONTE BAIXADO SAIU DO CACHE — 09/10/2026, P76. "Apagar esta pasta custa um
# download", dizia o bloco acima, e deixou de ser verdade: o índice do Pop
# serve uma versão por pacote, e em 09/10 o `.tar.xz` do 0fbd457 instalado só
# existia no `~/.cache`. Cache é o que se recria; isto não se recria mais. O
# `.dsc` e o `.tar.xz` moram aqui (é a mesma guarda do `meow cosmic prever`),
# e só a ÁRVORE extraída e compilada continua no cache.
CP_GUARDA="${CP_GUARDA:-${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/fontes/cosmic-comp}"
# A SÉRIE INVERTEU DE LADO EM 22/09/2026 (P29), E A ORDEM É A DECISÃO
#   Até aqui `CP_SERIE` era a da Aurora e a nossa não existia: este arquivo lia
#   `/usr/local/share/aurora/patches.d/series`, e caía em
#   `~/.config/zsh/patches/patches.d/series` quando o Ritual ainda não tinha
#   instalado a primeira. Agora a série mora em `patches/series`, neste
#   repositório, e é ELA a primeira resposta — porque a origem passou a ser
#   aqui, e uma origem que só vale quando a outra falta não é origem.
#
#   A DA AURORA DEIXOU DE SER LIDA EM 24/09/2026 (P39). Ela ficava em
#   `CP_SERIE_ALT`, lida quando a nossa faltava, porque numa máquina que fez o
#   Ritual o binário do disco tinha sido compilado a partir DELA. Com o build
#   vindo para cá isso acabou: o binário que este arquivo mede é o que o NOSSO
#   `compilar` instalou, a partir da NOSSA série. Ler a instalada pelo Ritual
#   seria a "integração opcional" que a regra de 23/09 recusa com essas
#   palavras. Sem `patches/series` o clone está quebrado, e o bloco 4 diz isso.
CP_SERIE="${CP_SERIE:-$MEOW_RAIZ/patches/series}"
# Onde `aplicar` procura a árvore de fonte do cosmic-comp. Sem padrão útil de
# propósito: não há lugar canônico para um `git clone` do compositor nesta
# máquina, e inventar um faria o verbo falhar apontando para um caminho que
# ninguém escolheu. Quem chama nomeia, por argumento ou por esta variável.
CP_FONTE="${CP_FONTE:-}"
# O COMPOSITOR EM ESCOPO DE USUÁRIO — 09/10/2026, P76
#   O build patchado deixou de ir para `/usr/bin` (onde o apt sobrescreve e a
#   tela de login lê o mesmo arquivo) e passou a morar aqui, um diretório por
#   versão do pacote: `<versão>/cosmic-comp` e `<versão>/estado`. Quem o põe na
#   sessão é o shim (`scripts/compositor_shim.sh`), instalado como
#   `~/.local/bin/cosmic-comp` pelo `ativar` — o `cosmic-session` acha o
#   compositor pelo PATH, e o PATH da sessão começa ali. O greeter não vê
#   `~/.local/bin`, e o apt nunca toca em nenhum dos dois.
CP_CASA="${CP_CASA:-$HOME/.local/libexec/meow/cosmic-comp}"
CP_SHIM="${CP_SHIM:-$HOME/.local/bin/cosmic-comp}"
CP_SHIM_FONTE="$MEOW_RAIZ/scripts/compositor_shim.sh"
CP_SHIM_MARCA="MEOW-COSMIC-COMP-SHIM"
# A MATRIZ DE COMPATIBILIDADE GRAVADA PELA MÁQUINA — P76
#   O `patches/versao` era porteiro: só compilava sobre versão que alguém tinha
#   validado à mão e posto num commit. Agora quem decide é a escada, patch a
#   patch, e o que ela decidiu fica aqui, uma linha por versão:
#     <versão> <TAB> <data> <TAB> <patch>:<degrau> <patch>:<degrau> …
#   Degraus (`docs/pesquisas/2026-10-09-cosmic-vivo.md` §4.3):
#     1  `-F0` limpo e os arquivos que o patch toca iguais aos da última versão boa
#     2  entra (`-F0` com arquivo mudado upstream, ou só com `-F1`): vai para o
#        build sob a guarda de queda do shim, "em observação"
#     3  `opt` que não entra: o build sai sem ele, só a função dele degrada
#     4  `req` que não entra: não há build, a sessão sobe de fábrica, e é o
#        único degrau que pede gente — um rebase do patch, num commit
#   Mora no estado e não em `patches/`: quem grava é a máquina, e o clone é do
#   git. O `patches/versao` continua lido, como o histórico do que gente validou.
CP_MATRIZ="${CP_MATRIZ:-$MEOW_ESTADO/cosmic-comp/matriz.tsv}"
# Os arquivos que a série toca, como estavam no fonte PURO da última versão
# que compilou. É contra eles que o degrau 1 pergunta "o upstream mexeu aqui?".
CP_ALVOS="${CP_ALVOS:-$MEOW_ESTADO/cosmic-comp/alvos}"

# --- o buffer de saída ------------------------------------------------------
# A PRIMEIRA LINHA É A TABELA DO DOCTOR, E ELA SÓ EXISTE NO FIM
#   O `primeira_linha` do `bin/meow` corta a saída no primeiro `\n` e é isso que
#   cabe na coluna da direita. Mas o resumo (quantas divergências, e quais) só
#   se sabe depois de conferir tudo. Então as linhas de detalhe são guardadas
#   aqui e cuspidas DEPOIS do resumo, em vez de impressas na hora.
#
#   E todas saem em stdout, inclusive as de aviso: o runner captura com
#   `2>&1`, e stdout num pipe é bufferizado por bloco enquanto stderr não é —
#   misturar os dois pode entregar o aviso ANTES do resumo, e aí a tabela mostra
#   a linha errada. Um `meow_aviso` a menos custa a cor amarela do `!!`; a linha
#   trocada custa a leitura inteira.
declare -a _CP_TIPO=() _CP_TEXTO=()
_cp_diz() { _CP_TIPO+=("$1"); shift; _CP_TEXTO+=("$*"); }
_cp_despejar() {
  local i
  for i in "${!_CP_TIPO[@]}"; do
    case "${_CP_TIPO[$i]}" in
      ok)   meow_ok   "${_CP_TEXTO[$i]}" ;;
      muda) meow_muda "${_CP_TEXTO[$i]}" ;;
      pula) meow_pula "${_CP_TEXTO[$i]}" ;;
      *)    meow_info "${_CP_TEXTO[$i]}" ;;
    esac
  done
}

# --- leitura do binário -----------------------------------------------------
# A BASE é o marcador sem o sufixo de versão: AURORA-COSMIC-WS-PATCH-3.67 ->
# AURORA-COSMIC-WS-PATCH. Com ela o regex acha TAMBÉM um marcador de versão
# diferente da declarada, e é isso que transforma "não achei" em "achei outro",
# que é a frase que resolve o problema em vez de só anunciá-lo.
_cp_base() { printf '%s' "${1%-*}"; }

# Devolve, um por linha, todo marcador da família <base> presente em <arquivo>.
# `grep -a` para não parar em "arquivo binário"; `-o` para o casamento nu.
_cp_marcadores() {
  local arq="$1" base="$2"
  [ -r "$arq" ] || return 1
  grep -a -o "$base-[0-9][0-9.]*" "$arq" 2>/dev/null | sort -u
}

_cp_tem() {
  local alvo="$1"; shift
  local m
  for m in "$@"; do [ "$m" = "$alvo" ] && return 0; done
  return 1
}

# --- a série ----------------------------------------------------------------
_cp_serie_arquivo() {
  [ -r "$CP_SERIE" ] && { printf '%s' "$CP_SERIE"; return 0; }
  return 1
}

# --- a versão: a instalada, e as que a série conhece ------------------------
_cp_versao_instalada() {
  local v
  v="$(dpkg-query -W -f='${Version}' cosmic-comp 2>/dev/null)" || return 1
  [ -n "$v" ] || return 1
  printf '%s' "$v"
}

# Uma por linha, sem comentário. O primeiro campo é a versão; o resto da linha
# fica livre para uma nota, se um dia alguém quiser pôr.
_cp_versoes_validadas() {
  [ -r "$CP_VERSOES" ] || return 1
  sed -e 's/#.*//' "$CP_VERSOES" | awk 'NF { print $1 }'
}

_cp_versao_valida() {
  local v="$1" x
  while IFS= read -r x; do
    [ "$x" = "$v" ] && return 0
  done < <(_cp_versoes_validadas)
  # P76: vale também a versão em que a escada pôs o `req` no build.
  awk -F'\t' -v v="$v" '$1==v && $3 !~ /:4( |$)/ {ok=1} END {exit !ok}' "$CP_MATRIZ" 2>/dev/null
}

# --- o shim (P76) -----------------------------------------------------------
# 0 = o `cosmic-comp` que a sessão acha pelo PATH é o nosso shim.
_cp_shim_ativo() { grep -qs -- "$CP_SHIM_MARCA" "$CP_SHIM"; }

# O binário que o PRÓXIMO LOGIN vai rodar. Com o shim no ar, quem responde é o
# próprio shim (`MEOW_SHIM_SO_DIZER=1`), para a regra das três condições morar
# num lugar só; sem ele, é o de `/usr/bin`, como sempre foi.
_cp_proximo_login() {
  if _cp_shim_ativo; then
    MEOW_SHIM_SO_DIZER=1 MEOW_SHIM_CASA="$CP_CASA" MEOW_SHIM_FABRICA="$CP_BIN" bash "$CP_SHIM"
  else
    printf '%s\n' "$CP_BIN"
  fi
}

# "1 marcador" / "2 marcadores". Custa três linhas e evita o `marcador(es)` que
# faz a linha da tabela — a única que ela lê todo dia — parecer saída de robô.
_cp_plural() { [ "$1" = "1" ] && printf '%s %s' "$1" "$2" || printf '%s %s' "$1" "$3"; }

# --- o comando --------------------------------------------------------------
cmd_conferir() {
  local -a problemas=()      # frases curtas; é delas que sai a primeira linha
  local rc=0
  # SÓ QUEM PRECISA DE BUILD RECEBE O CONSELHO DE BUILD
  #   "está no disco mas NÃO na sessão" diz, com todas as letras, que não há
  #   nada a recompilar — e emendar "rode o --build" logo abaixo faria a pessoa
  #   pagar 4 min de cargo para consertar um logout. As duas mensagens do item 6
  #   da Sprint U só continuam distintas se o RODAPÉ também for.
  local precisa_build=0

  # A DEPENDÊNCIA. 3, e não 2 nem 4: numa máquina sem `cosmic-comp` não há
  # divergência, há ausência de assunto — é a mesma leitura do `chk_relogio` sem
  # o applet, e o runner do doctor pinta 3 e 4 com o mesmo `--` cinza. O 4
  # ("divergente por escolha dela") seria mentira: ninguém escolheu não ter
  # compositor.
  if [ ! -e "$CP_BIN" ]; then
    meow_pula "cosmic-comp não está instalado — nada a conferir nos patches"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # A SESSÃO PODE FALTAR SEM QUE ISSO SEJA FALHA. Rodar o doctor por ssh, ou de
  # um TTY, ou com o desktop caído, deixa `pgrep` vazio — e a metade do DISCO da
  # pergunta continua tendo resposta útil (é justamente ela que diz se o build
  # precisa ser refeito). Então segue-se sem a coluna "sessão", com uma linha
  # dizendo, e sem inventar divergência.
  # --- 0. o shim (P76): com ele no ar, o binário que conta é o build da versão
  # COM O SHIM, O DISCO QUE INTERESSA É O BUILD DA VERSÃO, NÃO `/usr/bin`
  #   O `/usr/bin/cosmic-comp` volta a ser de fábrica e fica de fábrica; o
  #   `.estado` de `/var/lib` fala de um arranjo que acabou. Então o `CP_BIN` e
  #   o `CP_ESTADO` desta conferência passam a ser os do build da versão que o
  #   dpkg diz instalada — e o resto do verbo, marcador a marcador, disco e
  #   sessão, segue igual.
  #
  #   SEM BUILD É FÁBRICA, E FÁBRICA NÃO É VERMELHO: é o princípio D da
  #   pesquisa (toda falha degrada para fábrica, nunca para quebrado). Quem
  #   reconstrói é o pós-apt. Só o `ruim` — duas quedas seguidas — pede gente.
  if _cp_shim_ativo; then
    local v_shim="" casa_v=""
    v_shim="$(_cp_versao_instalada 2>/dev/null)" || v_shim=""
    casa_v="$CP_CASA/$v_shim"
    if [ -e "$casa_v/ruim" ]; then
      meow_muda "o build do cosmic-comp $v_shim caiu duas vezes seguidas e foi posto de lado — a sessão sobe de fábrica"
      meow_info "volta com um build novo: meow compositor"
      return "$MEOW_DIVERGENTE"
    fi
    if [ ! -x "$casa_v/cosmic-comp" ] || [ ! -r "$casa_v/estado" ]; then
      # O DEGRAU 4 ACENDE (conferência da P76): sem build porque o `req` não
      # entra nesta versão não é "o pós-apt ainda vem" — é o único degrau que
      # pede gente (§4.3 da pesquisa), e a matriz já o gravou. Verde aqui seria
      # o "tudo confere" com algo fora.
      if awk -F'\t' -v v="$v_shim" '$1==v && $3 ~ /:4( |$)/ {achou=1} END {exit !achou}' "$CP_MATRIZ" 2>/dev/null; then
        meow_muda "o patch obrigatório não entra no cosmic-comp $v_shim (degrau 4) — a sessão sobe de fábrica até um rebase"
        meow_info "o que recusou: meow compositor validar"
        return "$MEOW_DIVERGENTE"
      fi
      meow_aviso "o cosmic-comp $v_shim ainda não tem build nosso — a sessão sobe de fábrica, sem os patches"
      meow_info "o build vem sozinho depois do apt; na mão: meow compositor"
      return "$MEOW_OK"
    fi
    CP_BIN="$casa_v/cosmic-comp"
    CP_ESTADO="$casa_v/estado"
  fi

  local pid sessao=""
  pid="$(pgrep -x cosmic-comp 2>/dev/null | head -1)"
  if [ -n "$pid" ] && [ -r "/proc/$pid/exe" ]; then
    sessao="/proc/$pid/exe"
  fi

  # --- 1. o .estado, que é o que a Aurora promete gravar --------------------
  # SEM `.estado`, NADA FOI PROMETIDO — E ISSO DEIXOU DE SER DIVERGÊNCIA EM 21/09/2026
  #   Até esta data a ausência do `.estado` entrava em `problemas` e ligava o
  #   `precisa_build`. Numa máquina que fez o Ritual da Aurora isso está certo:
  #   o `.estado` sumir depois de existir é notícia. Numa máquina que NUNCA o
  #   fez — qualquer pessoa que clone este projeto — era outra coisa: o doctor
  #   nascia vermelho no primeiro dia e ficava vermelho para sempre, mandando
  #   rodar `aurora-cosmic-comp-ws.sh --build`, um script que não está neste
  #   repositório e que ela não tem como obter. Medido em 21/09/2026 com os
  #   overrides deste próprio arquivo (CP_BIN sem marcador, CP_ESTADO e CP_SERIE
  #   inexistentes): rc=1, todo dia, apontando para projeto alheio.
  #
  #   Um doctor que nunca fica verde é um doctor que a pessoa aprende a ignorar,
  #   e aí ele para de servir para as outras 61 conferências. Divergência é
  #   para o que o projeto sabe consertar; o resto é informação.
  #
  #   O ALARME QUE IMPORTA NÃO SE PERDE, e é por isso que a divisão cai aqui e
  #   não num silenciador geral: quem tem `.estado` continua com TUDO o que este
  #   arquivo media — versao= contra o dpkg, marcador a marcador no disco e na
  #   sessão, série, md5 das duas cópias. O caso que pegou o `apt` de 21/09/2026
  #   às 08:17 é exatamente esse, e continua vermelho. O que muda é só o outro
  #   lado da mesma porta, que a variável `estado_ok` já separava.
  #
  #   E POR QUE VERDE, E NÃO O CINZA DO `MEOW_SEM_DEPENDENCIA`: o 3 diz "não há
  #   assunto", e aqui há — o `cosmic-comp` está instalado, a leitura rodou
  #   inteira e o estado que ela achou é um estado correto. O 3 fica reservado
  #   para a máquina sem compositor nenhum, que é onde ele já estava.
  local estado_ok=0 ritual_ausente=0 versao_estado="" gravado=""
  local -a linhas=()
  # O NOME `ritual_ausente` FICOU, E O SENTIDO MUDOU EM 24/09/2026 (P39): era
  # "esta máquina não fez o Ritual da Aurora"; agora é "o `meow compositor`
  # nunca instalou nada aqui". A porta é a mesma, e o verde também — o que
  # mudou foi a frase, que deixou de mandar para um script de outro projeto e
  # passou a nomear o verbo daqui.
  if [ ! -e "$CP_ESTADO" ]; then
    ritual_ausente=1
    _cp_diz info "quem aplica os patches do compositor é o meow compositor (compila ~4 min, pede sudo no fim), e ele ainda não instalou nada aqui"
    _cp_diz info "sem $CP_ESTADO não há o que conferir: nada foi prometido, nada está faltando"
    # Sem crase: dentro de aspas duplas ela vira substituição de comando, e
    # esta frase nomeia um comando de verdade.
    _cp_diz info "o que muda sem eles: o meow painel apara o raio das barras ao que cabe na altura — o resto do tema é igual"
    # A VERSÃO ENTRA AQUI COMO INFORMAÇÃO, NUNCA COMO VEREDITO (24/09/2026).
    # Sem `.estado` nada foi prometido, então uma versão fora de
    # `patches/versao` não é divergência — é só o que o `meow compositor` vai
    # responder se alguém o chamar, dito antes, para ninguém descobrir na recusa.
    local v_inst=""
    v_inst="$(_cp_versao_instalada 2>/dev/null)" || v_inst=""
    if [ -n "$v_inst" ] && ! _cp_versao_valida "$v_inst"; then
      _cp_diz info "o cosmic-comp instalado ($v_inst) ainda não passou pela série: a escada decide no primeiro build"
    fi
  elif [ ! -r "$CP_ESTADO" ]; then
    # O contrato pede 644. Se chegou aqui, o modo saiu do combinado — e o doctor
    # não usa sudo para contornar, ele relata.
    problemas+=("o .estado existe e não é legível por você")
    _cp_diz muda "$CP_ESTADO não é legível (o contrato pede 644, dono root)"
  else
    estado_ok=1
    local l
    while IFS= read -r l || [ -n "$l" ]; do
      case "$l" in
        \#*|"") continue ;;
        versao=*)  versao_estado="${l#versao=}" ;;
        gravado=*) gravado="${l#gravado=}" ;;
        *) linhas+=("$l") ;;
      esac
    done < "$CP_ESTADO"
    [ -n "$gravado" ] && _cp_diz info ".estado gravado em $gravado"
  fi

  # --- 2. a versão do pacote ------------------------------------------------
  # O `.estado` fala de UM binário. Se o `apt` já trocou o pacote, tudo o que ele
  # afirma é sobre um arquivo que não está mais lá — e isso é divergência antes
  # mesmo de olhar marcador nenhum.
  local versao_dpkg=""
  versao_dpkg="$(dpkg-query -W -f='${Version}' cosmic-comp 2>/dev/null)" || versao_dpkg=""
  if [ "$estado_ok" = "1" ]; then
    if [ -z "$versao_estado" ]; then
      problemas+=("o .estado não declara versao="); precisa_build=1
      _cp_diz muda "o .estado não tem linha 'versao=' — não dá para saber de qual binário ele fala"
    elif [ -z "$versao_dpkg" ]; then
      _cp_diz info "dpkg não conhece o pacote cosmic-comp — versão não conferida"
    elif [ "$versao_estado" != "$versao_dpkg" ]; then
      problemas+=("o .estado é de outra versão do pacote"); precisa_build=1
      _cp_diz muda "versão divergente: .estado diz '$versao_estado', dpkg diz '$versao_dpkg'"
      _cp_diz info "um apt trocou o binário depois do último build — a série volta com: meow compositor"
      # E o `meow compositor` recusa versão que não esteja em `patches/versao`
      # (24/09/2026). Dizer isto aqui poupa a pessoa de descobrir na recusa,
      # depois de já ter decidido parar para compilar.
      _cp_versao_valida "$versao_dpkg" || \
        _cp_diz info "  a versão é nova para a série: o build decide patch a patch (meow compositor validar mostra antes)"
    fi
  fi

  # --- 3. marcador a marcador: disco e sessão -------------------------------
  local faltando=0 fora_da_sessao=0 conferidos=0
  local linha classe marcador arquivo situacao base
  local -a m_disco=() m_sessao=()
  for linha in ${linhas[@]+"${linhas[@]}"}; do
    # shellcheck disable=SC2086
    set -- $linha
    [ $# -ge 4 ] || { _cp_diz info "linha ignorada no .estado (esperados 4 campos): $linha"; continue; }
    classe="$1"; marcador="$2"; arquivo="$3"; situacao="$4"

    if [ "$situacao" != "presente" ]; then
      # `opt ausente` é o caso previsto: um patch opcional que não aplicou, o
      # build seguiu sem ele — e é EXATAMENTE o buraco por onde o raio clampado
      # sumiu por semanas. Amarelo, com o nome do arquivo na tela.
      # `req ausente` não deveria existir (um req que falha aborta o build e nada
      # é instalado); se aparecer, é o build que mentiu, e vale dizer isso.
      problemas+=("$arquivo não entrou no binário"); precisa_build=1
      if [ "$classe" = "req" ]; then
        _cp_diz muda "$arquivo é OBRIGATÓRIO e está 'ausente' — o build instalou um binário meio-patchado"
      else
        _cp_diz muda "$arquivo é opcional e está 'ausente' — o efeito dele não existe neste binário"
      fi
      continue
    fi

    conferidos=$((conferidos+1))
    base="$(_cp_base "$marcador")"
    mapfile -t m_disco < <(_cp_marcadores "$CP_BIN" "$base")
    if ! _cp_tem "$marcador" ${m_disco[@]+"${m_disco[@]}"}; then
      faltando=$((faltando+1))
      _cp_diz muda "FALTA $marcador"
      if [ "${#m_disco[@]}" -gt 0 ]; then
        _cp_diz info "  o binário tem outra versão do mesmo patch: ${m_disco[*]}"
      fi
      _cp_diz info "  nem no disco: o build precisa ser refeito ($arquivo)"
      continue
    fi

    if [ -z "$sessao" ]; then
      _cp_diz ok "$marcador no disco (a sessão não pôde ser conferida)"
      continue
    fi
    mapfile -t m_sessao < <(_cp_marcadores "$sessao" "$base")
    if ! _cp_tem "$marcador" ${m_sessao[@]+"${m_sessao[@]}"}; then
      fora_da_sessao=$((fora_da_sessao+1))
      _cp_diz info "$marcador está no disco mas NÃO na sessão"
      _cp_diz info "  vale no próximo login — nada a fazer agora, e nada a recompilar"
      continue
    fi
    _cp_diz ok "$marcador no disco e na sessão ($arquivo)"
  done

  [ "$faltando" -gt 0 ] && { problemas+=("$(_cp_plural "$faltando" marcador marcadores) fora do binário"); precisa_build=1; }
  # Esta é a ÚNICA divergência que não pede build: o binário do disco está
  # certo, quem está velho é o processo. Por isso não liga o `precisa_build`.
  [ "$fora_da_sessao" -gt 0 ] && problemas+=("$(_cp_plural "$fora_da_sessao" 'marcador só vale' 'marcadores só valem') no próximo login")

  # Quando não há `.estado`, a única coisa honesta a dizer sobre o binário é o
  # que ele TEM — e isso é informação, não veredito. Serve de linha de base para
  # quem for comparar depois do primeiro build com série.
  if [ "$estado_ok" != "1" ]; then
    local -a achados=()
    mapfile -t achados < <(grep -a -o 'AURORA-[A-Z-]*-PATCH-[0-9][0-9.]*' "$CP_BIN" 2>/dev/null | sort -u)
    if [ "${#achados[@]}" -gt 0 ]; then
      _cp_diz info "o binário no disco tem hoje: ${achados[*]}"
    else
      _cp_diz info "o binário no disco não tem marcador AURORA nenhum"
    fi
  fi

  # --- 4. o repositório contra a série (o motivo da sprint) -----------------
  local serie=""
  serie="$(_cp_serie_arquivo)" || serie=""
  # SÓ OS PATCHES DO COSMIC-COMP ENTRAM NESTA CONTA, E O FILTRO NASCEU DE UM
  # ALARME FALSO MEDIDO EM 01/09/2026
  #   Naquele dia entrou em `patches/` o primeiro `.patch` que NÃO é do
  #   compositor: o `cosmic-files-wallpaper-menu.patch`, dos dois itens de papel
  #   de parede no menu da área de trabalho. Este conferidor o comparou contra a
  #   série da Aurora — que é a série do `cosmic-comp` — e disse duas coisas
  #   erradas com cara de certo: "está no repo e não na série, nunca entra em
  #   binário nenhum" e "a Aurora não o carrega". Ele entra em binário sim, e
  #   quem o aplica é o `scripts/files_menu.sh`, que tem dono, marcador e
  #   artefato próprios.
  #
  #   O FILTRO É PELO NOME, e isso é deliberado: o alternativo seria abrir cada
  #   `.patch` e adivinhar o alvo pelos `+++`, que responde errado no dia em que
  #   um patch do cosmic-comp tocar um arquivo de nome parecido. `cosmic-comp-*`
  #   é a convenção que os quatro patches da série já seguem desde 25/08/2026, e
  #   um nome é um contrato mais barato de manter que uma heurística.
  local -a repo=()
  mapfile -t repo < <(find "$CP_REPO" -maxdepth 1 -name 'cosmic-comp-*.patch' -printf '%f\n' 2>/dev/null | sort)

  # E os OUTROS são contados em voz alta, para "0 fora da série" não passar a
  # impressão de que este conferidor viu o diretório inteiro.
  local -a outros=()
  mapfile -t outros < <(find "$CP_REPO" -maxdepth 1 -name '*.patch' ! -name 'cosmic-comp-*.patch' -printf '%f\n' 2>/dev/null | sort)
  if [ "${#outros[@]}" -gt 0 ]; then
    _cp_diz info "fora desta conta (não são do cosmic-comp, têm dono próprio): ${outros[*]}"
  fi

  if [ "${#repo[@]}" = "0" ]; then
    _cp_diz info "nenhum .patch em $CP_REPO — nada a comparar com a série"
  elif [ -z "$serie" ]; then
    # A OUTRA METADE DA MESMA PORTA (21/09/2026). A série é artefato do Ritual:
    # numa máquina que nunca o fez ela falta pelo mesmo motivo que o `.estado`, e
    # cobrar aqui traria de volta, por esta linha, o vermelho eterno que o bloco
    # 1 acabou de tirar. Com `.estado` presente a cobrança fica de pé: aí a
    # série sumiu de uma máquina onde ela existia, e isso é notícia.
    # A SÉRIE FALTAR DEIXOU DE SER ESTADO DA MÁQUINA E VIROU CLONE QUEBRADO
    #   Antes da P29 este ramo perguntava se o Ritual da Aurora tinha rodado:
    #   a série era artefato dela, e faltava numa máquina virgem pelo mesmo
    #   motivo que o `.estado`. Agora `patches/series` é versionado neste
    #   repositório e chega junto com o `git clone`. Se ele não está aqui, não
    #   é estado nenhum da Aurora — é arquivo apagado, e a frase tem de dizer
    #   isso em vez de mandar olhar para o lado.
    problemas+=("patches/series não existe neste clone"); precisa_build=1
    _cp_diz muda "não achei a série ($CP_SERIE)"
    _cp_diz info "  ela é versionada — 'git checkout patches/series' a traz de volta"
    _cp_diz info "  sem ela os ${#repo[@]} .patch de patches/ não têm ordem, classe nem marcador declarado"
  else
    _cp_diz info "série lida: $serie"
    local fora=0 p declarado
    local -a campos=()
    for p in "${repo[@]}"; do
      declarado=0
      # Lido em array porque a linha da série tem TRÊS campos
      # (`<classe> <arquivo.patch> <marcador-base>`) e um `read a b c` com o
      # último nome sobrando engoliria o resto da linha no campo do meio.
      while read -r -a campos || [ "${#campos[@]}" -gt 0 ]; do
        [ "${#campos[@]}" -ge 2 ] || continue
        case "${campos[0]}" in \#*) continue ;; esac
        [ "${campos[1]}" = "$p" ] && { declarado=1; break; }
      done < "$serie"
      if [ "$declarado" = "0" ]; then
        fora=$((fora+1))
        _cp_diz muda "o patch $p está no repo e não na série — nunca entra em binário nenhum"
      fi
    done
    [ "$fora" -gt 0 ] && { problemas+=("$(_cp_plural "$fora" patch patches) do repo fora da série"); precisa_build=1; }
    [ "$fora" = "0" ] && _cp_diz ok "todo .patch de patches/ está declarado na série (${#repo[@]})"
  fi

  # --- 5. (VAGO desde 22/09/2026, P29) --------------------------------------
  # AQUI MORAVA A COMPARAÇÃO POR MD5 CONTRA A ÁRVORE DA VIZINHA, E ELA ERA A
  # DIVERGÊNCIA ETERNA
  #   O bloco abrisse `~/.config/zsh/patches/patches.d/`, comparava `md5sum` de
  #   cada `.patch` daqui com o de lá, e imprimia duas linhas que o doctor
  #   repetiu todo dia por semanas:
  #
  #       patches/ está em dia com ~/.config/zsh/patches/patches.d (4 arquivo, md5 igual)
  #       só do lado da Aurora (este repo não carrega): cosmic-comp-sem-workspace-vazio.patch
  #
  #   A segunda era verdade e era o defeito: o único `req` da série vivia só do
  #   lado de lá, e este repositório tinha quatro dos cinco desenhos e nenhuma
  #   planta. A P29 não melhorou a mensagem — tirou o assunto. Os cinco `.patch`
  #   e a `series` moraram para cá em 22/09/2026, e uma pasta não pode divergir
  #   de si mesma.
  #
  #   POR QUE O BLOCO SAI INTEIRO, E NÃO VIRA "COMPARA SE EXISTIR": enquanto o
  #   código souber olhar para lá, alguém volta a sincronizar as duas cópias, e
  #   aí existem de novo duas verdades sobre o mesmo arquivo — que é pior que
  #   uma verdade errada, porque ninguém sabe qual editar. A conferência que
  #   restou é a do bloco 4, e ela é a que importa: todo `.patch` de `patches/`
  #   está declarado na `series` de `patches/`.
  #
  #   O QUE ISTO NÃO RESOLVE, dito aqui para não virar promessa: numa máquina
  #   que fez o Ritual da Aurora, quem compila continua sendo o
  #   `aurora-cosmic-comp-ws.sh`, com a série DELA em
  #   `/usr/local/share/aurora/patches.d/series`. Este arquivo deixou de
  #   comparar as duas árvores, não de saber que a outra existe — ver `CP_SERIE_ALT`.
  #
  #   RESOLVIDO EM 24/09/2026 (P39), e o parágrafo acima fica como história:
  #   quem compila é o `compilar` daqui, com a série daqui, e o `CP_SERIE_ALT`
  #   saiu. A outra árvore deixou de existir para este arquivo.

  # --- 6. o resumo, que é a linha da tabela ---------------------------------
  if [ "${#problemas[@]}" = "0" ]; then
    local resumo
    # A frase da tabela precisa dizer O QUE FOI VISTO, e "série conforme" seria
    # mentira numa máquina onde a série nem existe. Esta é a linha que a pessoa
    # lê todo dia; ela tem de explicar o verde sozinha.
    if [ "$ritual_ausente" = "1" ]; then
      resumo="os patches do compositor não estão aplicados — são opcionais, e o painel se ajusta sem eles"
    elif [ "$conferidos" -gt 0 ]; then
      resumo="$(_cp_plural "$conferidos" 'marcador de pé' 'marcadores de pé') no disco e na sessão; série conforme"
    else
      resumo="nenhum patch declarado; série conforme"
    fi
    meow_ok "$resumo"
    _cp_despejar
    return "$MEOW_OK"
  fi

  # Duas frases cabem na coluna; a partir da terceira vira contagem, senão a
  # linha estoura a largura da tabela e some no fim do terminal.
  local cabeca="${problemas[0]}"
  [ "${#problemas[@]}" -ge 2 ] && cabeca="$cabeca; ${problemas[1]}"
  [ "${#problemas[@]}" -ge 3 ] && cabeca="$cabeca (+$(( ${#problemas[@]} - 2 )) a mais)"

  # ESPERAR O LOGIN É AVISO, E NÃO DIVERGÊNCIA — 24/09/2026, sprint P50 (achado 14)
  #   Quando a ÚNICA coisa que falta é a sessão trocar de binário, o disco está
  #   em dia, não há o que recompilar e não há comando que resolva: a frase de
  #   baixo sempre disse isso. O código de saída dizia o contrário — 1, a
  #   divergência que o doctor soma, que manda "rode: meow doctor --consertar" e
  #   que o painel pintava «mexeu e aplicou» no fim de um conserto que não
  #   consertou nada (medido no painel de verdade, com os cinco marcadores da
  #   série à espera do login). Sai 0, abrindo com `!!`: o doctor mostra o `!!`
  #   na tabela (ver `imprimir_check`) e não o conta. Qualquer outro problema
  #   junto — um marcador que FALTA no disco, um `.estado` ilegível — continua
  #   no 1 de sempre, logo abaixo.
  if [ "$precisa_build" = "0" ] && [ "$fora_da_sessao" -gt 0 ] \
     && [ "${#problemas[@]}" = "1" ]; then
    meow_aviso "$cabeca"
    _cp_despejar
    meow_info "nada a recompilar: o binário do disco está em dia, quem está velho é a sessão"
    meow_info "o próximo login resolve sozinho — não há comando a rodar"
    return "$MEOW_OK"
  fi
  meow_muda "$cabeca"
  _cp_despejar
  if [ "$precisa_build" = "1" ]; then
    # O CONSELHO DEIXOU DE APONTAR PARA UM SCRIPT QUE NÃO EXISTE AQUI — 22/09/2026, P29
    #   Esta linha dizia "rode: aurora-cosmic-comp-ws.sh --build". A P22 já
    #   tinha medido que aquele script não está nesta máquina e não está neste
    #   repositório: o doctor mandava, todo dia, rodar um comando que não
    #   existe. Agora os três passos são nomeáveis, e os dois primeiros são
    #   deste projeto.
    #
    #   E OS DOIS PASSOS DO MEIO VIRARAM UM VERBO SÓ EM 24/09/2026 (P39): o
    #   `meow compositor` baixa o fonte, aplica, compila e instala. O "é passo
    #   seu — cargo e um install" saiu, porque deixou de ser verdade.
    meow_info "o conserto é recompilar o compositor com a série de patches/ (~4 min, sudo só no fim):"
    meow_info "  meow compositor --seco   diz o que faria, sem baixar nem escrever"
    meow_info "  meow compositor          baixa o fonte da versão instalada, compila e instala"
    meow_info "  meow compositor reverter diz como voltar ao binário do pacote"
    meow_info "o doctor não compila, não usa sudo e não escreve — ele só mede e conta"
  else
    meow_info "nada a recompilar: o binário do disco está em dia, quem está velho é a sessão"
    meow_info "o próximo login resolve sozinho — não há comando a rodar"
  fi
  rc="$MEOW_DIVERGENTE"
  return "$rc"
}

# ============================================================================
# `aplicar` — O APLICADOR PASSOU A SER DESTE PROJETO (22/09/2026, P29)
# ============================================================================
# ATÉ ONDE ELE VAI, E A LINHA É EXATA
#   Ele aplica a série numa ÁRVORE DE FONTE do cosmic-comp que quem chama
#   nomeia. Ele NÃO baixa o fonte, NÃO roda `cargo`, NÃO usa sudo e NÃO escreve
#   em `/usr/bin`. Os dois primeiros passos do conserto viraram nossos; o
#   terceiro continua sendo um comando que a dona dá, com os olhos abertos.
#
#   POR QUE A LINHA CAI AQUI, e não um passo adiante. O `install.sh` roda todo
#   módulo em sequência, de hora em hora e no timer das 05:00. Um verbo
#   `aplicar` que compilasse e instalasse o compositor poria um build de 4
#   minutos e uma troca de `/usr/bin/cosmic-comp` dentro de uma passagem
#   automática — e este binário É TAMBÉM A TELA DE LOGIN. O aviso está na
#   própria série, escrito por quem já perdeu uma sessão: é por isso que o modo
#   de leitura e o blur são `opt` e vêm por último. Trazer a série para cá
#   mudou o dono do risco; não mudou o risco.
#
# DRY-RUN DE TUDO ANTES DE ESCREVER UMA LINHA, E É O CONTRATO DA SÉRIE
#   "req: se o dry-run dele falhar, o build ABORTA e NADA é instalado." Como
#   aqui não se instala nada, o análogo honesto é abortar antes de tocar na
#   árvore: primeiro todos os dry-runs, depois a decisão, depois a escrita.
#   Um `req` que falha faz o verbo sair sem ter mexido em um byte — que é
#   exatamente o "o desktop fica no binário do pacote (feio, mas de pé)".
#
# IDEMPOTÊNCIA POR MARCADOR, PELO MOTIVO QUE A SÉRIE MEDIU EM 30/08/2026
#   NÃO dá para usar o código de saída do `patch --forward`: ele devolve 1
#   tanto para "já aplicado" quanto para erro. O teste é `grep` do
#   marcador-base nos arquivos que o patch toca. Por isso um `aplicar` rodado
#   duas vezes na mesma árvore não empilha nada e não mente sobre o que fez.
# FUZZ ZERO, E ISTO FOI MEDIDO EM 22/09/2026 ANTES DE O VERBO IR AO AR
#   O `patch` do GNU aceita, por padrão, até duas linhas de contexto ERRADAS
#   (`-F2`). Numa árvore de teste com `println!("outra coisa")` onde o hunk
#   pedia `println!("oi")`, o dry-run devolveu rc=0 e a aplicação enfiou o
#   marcador no lugar errado, deixando um `src/main.rs.orig` para trás — tudo
#   em silêncio, com `--silent`.
#
#   Para quase todo projeto isso é conveniência. Aqui não: este binário é
#   TAMBÉM A TELA DE LOGIN, e um hunk que "quase" casa numa versão nova do
#   cosmic-comp compila e sobe quebrado, que é o pior dos dois mundos — pior
#   que não aplicar, porque não aplicar aborta e deixa o binário do pacote de
#   pé. `-F0` faz o dry-run recusar o que não casa exatamente, e aí o contrato
#   `req`/`opt` da série volta a significar o que diz.
#
#   `--no-backup-if-mismatch` é a segunda metade da mesma medição: foi ele que
#   deixou o `.orig` na árvore. Um arquivo `.rej`/`.orig` esquecido vira, dias
#   depois, um `grep` que acha o marcador num arquivo que o compilador nem lê.
_CP_PATCH_OPCOES=(-p1 --forward -F0 --no-backup-if-mismatch --silent)
# O SEGUNDO DEGRAU DA ESCADA (P76): `-F1` aceita UMA linha de contexto que
# mudou. Medido em 09/10/2026: o modo de leitura falha um hunk com `-F0` no
# cosmic-comp 41497b4 porque o upstream acrescentou campos ao
# `CosmicCompConfig` e mudou a terceira linha de contexto — e entra com `-F1`,
# no lugar certo. O risco que o bloco acima descreve continua de pé, e por
# isso o `-F1` só vale com o build entrando sob a guarda de queda do shim, e
# nunca vai além de uma linha.
_CP_PATCH_OPCOES_F1=(-p1 --forward -F1 --no-backup-if-mismatch --silent)

# O degrau de cada patch na última passagem do `cmd_aplicar`, "arquivo:degrau".
declare -a _CP_DEGRAUS=()

# 0 = algum arquivo que o patch toca difere do da última versão boa (ou não há
# cópia dela para comparar, que é o mesmo que não saber).
_cp_alvos_mudaram() {
  local fonte="$1" patch_arq="$2" alvo
  while IFS= read -r alvo; do
    [ -n "$alvo" ] || continue
    [ -f "$CP_ALVOS/$alvo" ] || return 0
    cmp -s "$fonte/$alvo" "$CP_ALVOS/$alvo" || return 0
  done < <(_cp_alvos_do_patch "$patch_arq")
  return 1
}
_cp_alvos_do_patch() {
  # Os arquivos que um `.patch` toca, lidos das linhas `+++`. O `b/` da frente
  # é o `-p1` do `patch`, e sai aqui pelo mesmo motivo.
  sed -n 's|^+++ [ab]/\([^[:space:]]*\).*|\1|p' "$1" 2>/dev/null | sort -u
}

_cp_ja_aplicado() {
  # 0 = o marcador-base já está em algum arquivo que o patch toca.
  local fonte="$1" patch_arq="$2" base="$3" alvo
  while IFS= read -r alvo; do
    [ -n "$alvo" ] || continue
    [ -f "$fonte/$alvo" ] || continue
    grep -q -- "$base" "$fonte/$alvo" 2>/dev/null && return 0
  done < <(_cp_alvos_do_patch "$patch_arq")
  return 1
}

cmd_aplicar() {
  local fonte="${1:-$CP_FONTE}"
  local serie=""

  meow_tem patch || { meow_pula "o comando 'patch' não está instalado — nada a aplicar"; return "$MEOW_SEM_DEPENDENCIA"; }

  serie="$(_cp_serie_arquivo)" || {
    meow_erro "não achei a série ($CP_SERIE)"
    return "$MEOW_ERRO"
  }

  if [ -z "$fonte" ]; then
    meow_erro "diga qual é a árvore de fonte do cosmic-comp"
    meow_info "  uso: compositor_patches.sh aplicar <dir-do-fonte>   (ou CP_FONTE=<dir>)"
    meow_info "  este verbo não baixa o fonte: o clone é escolha sua, e o disco é seu"
    return "$MEOW_ERRO"
  fi
  if [ ! -d "$fonte" ]; then
    meow_erro "não é um diretório: $fonte"
    return "$MEOW_ERRO"
  fi
  # A árvore certa tem `Cargo.toml` e `src/`. Conferir isto custa duas linhas e
  # evita o caso que estraga a tarde: um `-p1` disparado na raiz errada, que
  # não casa nada e deixa `.rej` espalhado por um diretório que não era o alvo.
  if [ ! -f "$fonte/Cargo.toml" ] || [ ! -d "$fonte/src" ]; then
    meow_erro "$fonte não parece a árvore do cosmic-comp (falta Cargo.toml ou src/)"
    return "$MEOW_ERRO"
  fi

  meow_info "série: $serie"
  meow_info "fonte: $fonte"

  # --- passagem 1: ler a série, e medir cada patch SEM escrever -------------
  local -a classe=() arquivo=() base=() estado=()
  local -a campos=()
  local n=0
  while read -r -a campos || [ "${#campos[@]}" -gt 0 ]; do
    [ "${#campos[@]}" -ge 3 ] || continue
    case "${campos[0]}" in \#*) continue ;; esac
    case "${campos[0]}" in req|opt) : ;; *) continue ;; esac
    local p="$CP_REPO/${campos[1]}"
    classe+=("${campos[0]}"); arquivo+=("${campos[1]}"); base+=("${campos[2]}")
    if [ ! -r "$p" ]; then
      estado+=("sem-arquivo")
    elif _cp_ja_aplicado "$fonte" "$p" "${campos[2]}"; then
      estado+=("ja")
    elif (cd "$fonte" && patch "${_CP_PATCH_OPCOES[@]}" --dry-run < "$p") >/dev/null 2>&1; then
      estado+=("pode")
    elif (cd "$fonte" && patch "${_CP_PATCH_OPCOES_F1[@]}" --dry-run < "$p") >/dev/null 2>&1; then
      estado+=("pode-f1")
    else
      estado+=("recusa")
    fi
    n=$((n+1))
  done < "$serie"

  [ "$n" -gt 0 ] || { meow_pula "a série não declara nenhum patch"; return "$MEOW_OK"; }

  # --- a decisão: um `req` que não entra aborta tudo, antes de escrever -----
  local i abortar=0
  _CP_DEGRAUS=()
  for i in "${!classe[@]}"; do
    case "${estado[$i]}" in
      ja)         meow_ok   "${arquivo[$i]} já está na árvore (${base[$i]})"
                  _CP_DEGRAUS+=("${arquivo[$i]}:ja") ;;
      pode)
        if _cp_alvos_mudaram "$fonte" "$CP_REPO/${arquivo[$i]}"; then
          meow_info "${arquivo[$i]} aplica limpo, mas o upstream mexeu no que ele toca: degrau 2, em observação (${classe[$i]})"
          _CP_DEGRAUS+=("${arquivo[$i]}:2")
        else
          meow_info "${arquivo[$i]} aplica limpo: degrau 1 (${classe[$i]})"
          _CP_DEGRAUS+=("${arquivo[$i]}:1")
        fi ;;
      pode-f1)
        meow_info "${arquivo[$i]} só entra com -F1 — o contexto mudou: degrau 2, em observação (${classe[$i]})"
        _CP_DEGRAUS+=("${arquivo[$i]}:2") ;;
      sem-arquivo)
        meow_muda "${arquivo[$i]} está na série e não existe em $CP_REPO"
        [ "${classe[$i]}" = "req" ] && abortar=1 ;;
      recusa)
        if [ "${classe[$i]}" = "req" ]; then
          meow_muda "${arquivo[$i]} é OBRIGATÓRIO e não entra nem com -F1: degrau 4, precisa de gente"
          _CP_DEGRAUS+=("${arquivo[$i]}:4")
          abortar=1
        else
          meow_muda "${arquivo[$i]} é opcional e não entra nem com -F1: degrau 3, só o efeito dele fica de fora"
          _CP_DEGRAUS+=("${arquivo[$i]}:3")
        fi ;;
    esac
  done

  if [ "$abortar" = "1" ]; then
    meow_erro "um patch obrigatório não aplica nesta árvore — nada foi escrito"
    meow_info "é o contrato da série: sem o req, melhor o binário do pacote inteiro que um meio-patchado"
    meow_info "quase sempre é versão: o fonte em $fonte não é o do patch"
    return "$MEOW_ERRO"
  fi

  # O SECO SAI AQUI, e não lá em cima: assim ele imprime a MESMA leitura que a
  # passagem de verdade faria, que é o que um ensaio precisa mostrar.
  if meow_seco; then
    meow_muda "aplicaria a série em $fonte (nenhum byte escrito neste ensaio)"
    return "$MEOW_OK"
  fi

  # --- passagem 2: escrever, na ordem da série ------------------------------
  # "A ORDEM DAS LINHAS É A ORDEM DE APLICAÇÃO", e o modo de leitura vem por
  # último de propósito — quanto mais tarde ele encostar na árvore, menos coisa
  # há para desfazer se der errado.
  local aplicados=0 pulados=0
  local -a opcoes=()
  for i in "${!classe[@]}"; do
    case "${estado[$i]}" in
      pode)    opcoes=("${_CP_PATCH_OPCOES[@]}") ;;
      pode-f1) opcoes=("${_CP_PATCH_OPCOES_F1[@]}") ;;
      *)       pulados=$((pulados+1)); continue ;;
    esac
    if (cd "$fonte" && patch "${opcoes[@]}" < "$CP_REPO/${arquivo[$i]}") >/dev/null 2>&1; then
      aplicados=$((aplicados+1))
      meow_ok "${arquivo[$i]} aplicado"
    else
      # O dry-run tinha dito que dava. Se falhou agora, a árvore mudou entre as
      # duas passagens — e isso é erro alto, não aviso.
      meow_erro "${arquivo[$i]} falhou na aplicação depois de o dry-run ter passado"
      meow_info "  a árvore em $fonte mudou no meio do caminho; confira os .rej"
      return "$MEOW_ERRO"
    fi
  done

  meow_ok "$(_cp_plural "$aplicados" 'patch aplicado' 'patches aplicados') na árvore ($pulados sem mexer)"
  # Dentro do `compilar` o "o que falta" é o próprio passo seguinte, e dizer
  # "é seu" ali seria mentira de três linhas (24/09/2026, P39).
  if [ "${_CP_COMPILANDO:-0}" != "1" ]; then
    meow_info "o que falta: compilar (~4 min) e instalar em $CP_BIN — o meow compositor faz os dois"
    meow_info "o binário do compositor é TAMBÉM a tela de login — leia 'O que pode dar errado' em patches/series"
  fi
  return "$MEOW_OK"
}

# ============================================================================
# `compilar` e `validar` — O BUILD VEIO PARA CÁ (24/09/2026, P39)
# ============================================================================
# O QUE O `aurora-cosmic-comp-ws.sh` FAZIA, LIDO INTEIRO ANTES DE TRAZER
#   São 1083 linhas no Spellbook (`scripts/`), só leitura até esta decisão. Cada
#   verbo dele, e o destino:
#     --build     baixa o fonte da versão instalada, aplica a série (dry-run de
#                 todos antes), `make VENDOR=1`, confere os marcadores no
#                 binário, guarda o artefato e instala com sudo      -> VEIO: `compilar`
#     --status    série, marcador por patch, disco x sessão          -> já era nosso: `conferir`
#     --restore   copia o binário do pacote guardado por cima        -> `reverter` diz como, e
#                                                                       aponta a cópia que guardamos
#     --ensure    de hora em hora, pelo self-heal: reinstala o artefato da
#                 versão e dispara o auto-build numa unit transitória -> NÃO VEIO
#     --podar     poda o /var/lib/aurora                              -> NÃO VEIO (aqui se guarda um
#                                                                       arquivo por versão, e só)
#     night light reaplica o patch binário do shader depois de instalar -> NÃO VEIO: a luz quente
#                                                                       é o modo de leitura, que é
#                                                                       um patch DA SÉRIE
#
# POR QUE O `--ensure` E O AUTO-BUILD FICARAM DO LADO DE LÁ, DESATIVADOS
#   O doctor daqui nunca compila e nunca usa sudo, e o timer das 05:00 roda o
#   doctor. Um build de minutos que troca o compositor — que é a tela de login —
#   disparado por timer é o que este projeto recusa desde a P29, com o motivo
#   no bloco do `cmd_aplicar`. O que o auto-build dava (o patch voltar sozinho
#   depois de um apt) volta pela linha `patches` do doctor, que fica vermelha e
#   diz o verbo. E o artefato por versão existia para o `--ensure` reinstalar
#   sem compilar: sem `--ensure`, guardá-lo seria guardar o que ninguém lê.
#
# O `compilar`, NA ORDEM, E ONDE ELE PARA
#   1. versão: a instalada tem de estar em `patches/versao`, ou ele recusa;
#   2. ferramentas: patch, make e cargo — o cargo é o do rustup de quem compila;
#   3. fonte: `apt-get source cosmic-comp=<versão>`, no cache. COM O `=`: sem ele
#      o apt baixa o CANDIDATO, que depois de um `apt update` não é o
#      instalado — e o fonte de outra versão é a sessão que não sobe;
#   4. a série: o `cmd_aplicar` inteiro, dry-run de todos com `-F0` antes de
#      escrever, e um `req` que falha aborta com a árvore intocada;
#   5. `make VENDOR=1`, com Nice 19, e o registro num arquivo do cache;
#   6. os marcadores: todo patch que está na árvore tem de estar no binário;
#      sem um `req`, nada é instalado (o `#[used]` que o linker comeu);
#   7. a instalação, e SÓ AQUI entra o sudo: guarda o binário do pacote quando
#      ele é de fábrica, troca `/usr/bin/cosmic-comp` por rename atômico e grava
#      o `.estado` MEDIDO no binário instalado, nunca deduzido da série;
#   8. poda as árvores de outra versão no cache.
#   No `--seco` ele faz o 1 e o 2 e diz o resto — sem baixar, compilar ou sudo.
#
# POR QUE NÃO `dpkg-checkbuilddeps`, que pareceria o conferidor certo do passo
#   2: o `Build-Depends` do pacote pede o `cargo` e o `rustc` do Debian e o
#   `debhelper` — medido no `debian/control` da a557859 —, e quem compila aqui
#   usa o do rustup. Ele recusaria a máquina que compila. Falta de biblioteca
#   aparece no registro do `make`, cujo fim o `compilar` mostra.
_cp_fonte_dir() { printf '%s/cosmic-comp-%s' "$CP_CACHE" "$1"; }

# 0 = a árvore desta versão está no cache (agora ou de antes) · 2/3 = não deu
# O que o cache antigo guardava (`.dsc` e `.tar.*`) vai para a guarda, sem
# apagar a origem. Idempotente: o que já está lá não se copia de novo.
_cp_guardar_do_cache() {
  local f n=0
  for f in "$CP_CACHE"/cosmic-comp_*.dsc "$CP_CACHE"/cosmic-comp_*.tar.*; do
    [ -f "$f" ] || continue
    [ -f "$CP_GUARDA/${f##*/}" ] && continue
    if meow_seco; then meow_muda "guardaria ${f##*/} em $CP_GUARDA"; n=1; continue; fi
    mkdir -p "$CP_GUARDA" && cp -f "$f" "$CP_GUARDA/" && n=1
  done
  [ "$n" = "1" ] && return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}

_cp_baixar_fonte() {
  local ver="$1" dir log dsc
  dir="$(_cp_fonte_dir "$ver")"
  if [ -f "$dir/Cargo.toml" ] && [ -d "$dir/src" ]; then
    meow_info "o fonte de $ver já está no cache: $dir"
    return "$MEOW_OK"
  fi
  meow_tem apt-get || { meow_erro "falta o apt-get, e é ele que baixa o fonte"; return "$MEOW_SEM_DEPENDENCIA"; }
  # Sem o `dpkg-source` o `apt-get source` BAIXA e não extrai, e sai 0 — o
  # erro só apareceria duas linhas abaixo, como "a árvore não apareceu".
  meow_tem dpkg-source || { meow_erro "falta o dpkg-source (do dpkg-dev): sem ele o fonte baixa e não se extrai"; return "$MEOW_SEM_DEPENDENCIA"; }
  mkdir -p "$CP_CACHE" "$CP_GUARDA" || { meow_erro "não consegui criar $CP_CACHE e $CP_GUARDA"; return "$MEOW_ERRO"; }
  _cp_guardar_do_cache
  log="$CP_CACHE/baixar-$ver.log"
  # No nome do `.dsc` não vai o epoch.
  dsc="$CP_GUARDA/cosmic-comp_${ver#*:}.dsc"
  if [ -f "$dsc" ]; then
    meow_info "o fonte do cosmic-comp $ver está guardado: $CP_GUARDA"
  else
    meow_info "BAIXA DA INTERNET: o fonte do cosmic-comp $ver (~98 MB), para $CP_GUARDA"
    if ! ( cd "$CP_GUARDA" && apt-get source --download-only "cosmic-comp=$ver" ) >"$log" 2>&1; then
      meow_erro "o apt-get source falhou para o cosmic-comp $ver"
      # O 404 TEM FRASE PRÓPRIA porque foi medido, e não é raro: em 24/09/2026 o
      # repositório do Pop já não servia o `.tar.xz` da versão instalada nesta
      # máquina (a cd881a4, de 21/09). O fonte some do pool quando sai versão
      # nova, e a única saída é andar junto com ele.
      if grep -q ' 404 ' "$log" 2>/dev/null; then
        meow_info "  o repositório já não serve o fonte desta versão (404)"
        meow_info "  o caminho é atualizar o cosmic-comp — o apt traz binário e fonte da mesma versão — e validar a série nela"
      else
        meow_info "  o deb-src está habilitado nas fontes do apt? o registro está em $log"
      fi
      return "$MEOW_ERRO"
    fi
  fi
  if ! dpkg-source -x "$dsc" "$dir" >>"$log" 2>&1 || [ ! -f "$dir/Cargo.toml" ]; then
    meow_erro "o fonte não se extraiu em $dir (registro: $log)"
    return "$MEOW_ERRO"
  fi
  meow_ok "fonte do cosmic-comp $ver em $dir"
  return "$MEOW_OK"
}

# A série como três colunas separadas por tab: classe, arquivo, marcador-base.
# É a mesma leitura do `cmd_aplicar`, e existe porque o `compilar` precisa dela
# DEPOIS do build, para cobrar do binário o que entrou na árvore.
_cp_serie_entradas() {
  local serie="$1"
  local -a campos=()
  while read -r -a campos || [ "${#campos[@]}" -gt 0 ]; do
    [ "${#campos[@]}" -ge 3 ] || continue
    case "${campos[0]}" in req|opt) : ;; *) continue ;; esac
    printf '%s\t%s\t%s\n' "${campos[0]}" "${campos[1]}" "${campos[2]}"
  done < "$serie"
}

# 0 = o binário carrega o marcador de algum patch da série.
_cp_tem_marcador_da_serie() {
  local bin="$1" serie="$2" _c _a base
  while IFS=$'\t' read -r _c _a base; do
    [ -n "$(_cp_marcadores "$bin" "$base")" ] && return 0
  done < <(_cp_serie_entradas "$serie")
  return 1
}

# O `.estado`, MEDIDO no binário — nunca a intenção da série. É a regra que o
# outro lado aprendeu em 30/08/2026 e que vem junto: o `#[used]` pode ter sido
# comido pelo linker, e um arquivo de diagnóstico que grava o que a série
# declara faz o doctor dizer "conforme" sobre um desktop que não está.
_cp_texto_estado() {
  local bin="$1" ver="$2" serie="$3" classe arquivo base achado
  printf '# gravado pelo meow compositor — NAO EDITAR A MAO\n'
  printf 'versao=%s\n' "$ver"
  printf 'gravado=%s\n' "$(date -Is)"
  while IFS=$'\t' read -r classe arquivo base; do
    achado="$(_cp_marcadores "$bin" "$base" | head -1)"
    if [ -n "$achado" ]; then
      printf '%s %s %s presente\n' "$classe" "$achado" "$arquivo"
    else
      printf '%s %s %s ausente\n' "$classe" "$base" "$arquivo"
    fi
  done < <(_cp_serie_entradas "$serie")
}

# Uma linha por versão na matriz; a de uma versão já gravada é trocada, e uma
# linha igual à que já está lá não reescreve o arquivo (idempotência).
_cp_gravar_matriz() {
  local ver="$1" linha tmp
  [ "${#_CP_DEGRAUS[@]}" -gt 0 ] || return 0
  linha="$ver"$'\t'"$(date +%F)"$'\t'"${_CP_DEGRAUS[*]}"
  if awk -F'\t' -v v="$ver" -v d="${_CP_DEGRAUS[*]}" '$1==v && $3==d {achou=1} END {exit !achou}' "$CP_MATRIZ" 2>/dev/null; then
    return 0
  fi
  mkdir -p "${CP_MATRIZ%/*}" || return 1
  tmp="$(mktemp -p "${CP_MATRIZ%/*}" .matriz.XXXXXX)" || return 1
  { awk -F'\t' -v v="$ver" '$1!=v' "$CP_MATRIZ" 2>/dev/null; printf '%s\n' "$linha"; } > "$tmp" && mv -f "$tmp" "$CP_MATRIZ"
}

cmd_compilar() {
  local ver serie fonte bin log i
  ver="$(_cp_versao_instalada)" || {
    meow_pula "o cosmic-comp não está instalado (dpkg não o conhece) — nada a compilar"
    return "$MEOW_SEM_DEPENDENCIA"; }
  serie="$(_cp_serie_arquivo)" || { meow_erro "não achei a série ($CP_SERIE)"; return "$MEOW_ERRO"; }

  meow_info "cosmic-comp instalado: $ver"
  # A RECUSA DE VERSÃO SAIU — P76. Ela existia porque este binário ia para
  # `/usr/bin`, que é também a tela de login: um hunk que "quase" casa subiria
  # quebrado para a sessão E para o greeter. Com o build em escopo de usuário
  # o greeter não o vê, e a sessão tem a guarda de queda do shim. Quem decide
  # agora é a escada, patch a patch, e o que ela decidiu vai para a matriz.
  if _cp_versao_valida "$ver"; then
    meow_ok "esta versão já passou pela série (patches/versao ou a matriz)"
  else
    meow_info "versão nova para a série: a escada decide patch a patch e grava em $CP_MATRIZ"
  fi

  local -a faltam=()
  for i in patch make cargo; do meow_tem "$i" || faltam+=("$i"); done
  if [ "${#faltam[@]}" -gt 0 ]; then
    meow_erro "falta para compilar: ${faltam[*]}"
    meow_info "  o cargo é o do rustup de quem compila; o do apt costuma ser velho demais para o cosmic-comp"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  fonte="$(_cp_fonte_dir "$ver")"
  bin="$fonte/target/release/cosmic-comp"
  log="$CP_CACHE/compilar-$ver.log"

  if meow_seco; then
    local n_req n_opt
    n_req="$(_cp_serie_entradas "$serie" | awk -F'\t' '$1=="req"' | wc -l)"
    n_opt="$(_cp_serie_entradas "$serie" | awk -F'\t' '$1=="opt"' | wc -l)"
    if [ -f "$fonte/Cargo.toml" ]; then
      meow_info "o fonte já está no cache: $fonte"
    else
      meow_muda "baixaria o fonte do cosmic-comp $ver (~98 MB) para $CP_CACHE"
    fi
    meow_muda "aplicaria a série ($(_cp_plural "$n_req" obrigatório obrigatórios), $(_cp_plural "$n_opt" opcional opcionais)) pela escada (-F0, depois -F1), dry-run de todos antes"
    meow_muda "compilaria com make VENDOR=1 (~4 min com o vendor quente, ~30 min do zero)"
    meow_muda "conferiria os marcadores no binário e o guardaria em $CP_CASA/$ver — sem sudo"
    meow_muda "gravaria o estado medido em $CP_CASA/$ver/estado"
    meow_info "vale no próximo login com o shim ligado; o caminho de volta: meow compositor desativar"
    return "$MEOW_DIVERGENTE"
  fi

  _cp_baixar_fonte "$ver" || return $?

  # OS ARQUIVOS PUROS QUE A SÉRIE TOCA, guardados ANTES de a série escrever
  # neles: se este build der certo, eles viram a "última versão boa" contra a
  # qual o degrau 1 da próxima versão pergunta. Arquivo que já carrega o
  # marcador não é puro (uma passagem anterior o patchou) e não se guarda.
  local novo_alvos="$CP_ALVOS.novo" _c a b alvo
  rm -rf "$novo_alvos"
  while IFS=$'\t' read -r _c a b; do
    while IFS= read -r alvo; do
      [ -f "$fonte/$alvo" ] || continue
      grep -q -- "$b" "$fonte/$alvo" 2>/dev/null && continue
      mkdir -p "$novo_alvos/${alvo%/*}" && cp -f "$fonte/$alvo" "$novo_alvos/$alvo"
    done < <(_cp_alvos_do_patch "$CP_REPO/$a")
  done < <(_cp_serie_entradas "$serie")

  # O `cmd_aplicar` é o passo 4 inteiro, com as recusas dele. O `_CP_COMPILANDO`
  # só cala o "o que falta é seu" do fim, que aqui seria falso.
  local rc_ap=0
  _CP_COMPILANDO=1 cmd_aplicar "$fonte" || rc_ap=$?
  # O DEGRAU 4 TAMBÉM VAI PARA A MATRIZ: é a linha que diz ao pós-apt e ao
  # doctor que esta versão precisa de gente, e não de mais uma tentativa.
  [ "$rc_ap" = "0" ] || { _cp_gravar_matriz "$ver"; return "$rc_ap"; }

  meow_info "compilando com Nice 19 (~4 min com o vendor quente, ~30 min do zero)"
  meow_info "  o registro vai para $log"
  if ! ( cd "$fonte" && nice -n 19 make VENDOR=1 ) >"$log" 2>&1; then
    meow_erro "a compilação falhou — nada foi instalado, o compositor de agora continua"
    tail -n 15 "$log" 2>/dev/null | sed 's/^/        /' >&2
    return "$MEOW_ERRO"
  fi
  [ -f "$bin" ] || { meow_erro "o make terminou e o binário não apareceu em $bin"; return "$MEOW_ERRO"; }

  # --- 6. o que entrou na árvore tem de estar no binário --------------------
  local classe arquivo base falta_req=0
  while IFS=$'\t' read -r classe arquivo base; do
    _cp_ja_aplicado "$fonte" "$CP_REPO/$arquivo" "$base" || {
      meow_info "$arquivo não entrou na árvore ($classe) — o binário sai sem esse efeito"
      continue; }
    if [ -n "$(_cp_marcadores "$bin" "$base")" ]; then
      meow_ok "marcador no binário: $(_cp_marcadores "$bin" "$base" | head -1)"
    elif [ "$classe" = "req" ]; then
      meow_erro "$base está na árvore e NÃO no binário — o linker o comeu (falta o #[used])"
      falta_req=1
    else
      meow_aviso "$base (opcional) não está no binário: o efeito pode estar lá, mas ninguém vai saber"
    fi
  done < <(_cp_serie_entradas "$serie")
  [ "$falta_req" = "0" ] || { meow_erro "nada foi instalado: um obrigatório ficou fora do binário"; return "$MEOW_ERRO"; }

  # --- 7. a instalação, EM ESCOPO DE USUÁRIO (P76) ---------------------------
  # O BUILD NÃO VAI MAIS PARA `/usr/bin`, E O SUDO SAIU DESTE ARQUIVO
  #   Até 09/10/2026 este passo trocava `/usr/bin/cosmic-comp` por rename com
  #   sudo e guardava o binário do pacote em `/var/lib`. Lá o apt sobrescreve e
  #   a tela de login lê o mesmo arquivo. Agora o build mora em
  #   `$CP_CASA/<versão>/`, que é dela, e quem o põe na sessão é o shim. O
  #   `/usr/bin` fica de fábrica, e a cópia do pacote deixa de ser necessária:
  #   o de fábrica nunca sai do lugar.
  #
  #   O MESMO BINÁRIO NÃO SE REESCREVE: um segundo `compilar` sobre a mesma
  #   árvore produz o mesmo arquivo, e a passagem tem de ser idempotente.
  local destino="$CP_CASA/$ver" tmp_bin tmp_estado
  if cmp -s "$bin" "$destino/cosmic-comp" && [ -f "$destino/estado" ] && [ ! -e "$destino/ruim" ]; then
    meow_ok "o binário compilado é o que já está em $destino — nada a instalar"
    return "$MEOW_OK"
  fi
  mkdir -p "$destino" || { meow_erro "não consegui criar $destino"; return "$MEOW_ERRO"; }
  # TEMPORÁRIO NO MESMO DIRETÓRIO E `mv`: o shim pode ler este caminho a
  # qualquer login, e um compositor pela metade é sessão que não sobe.
  tmp_bin="$(mktemp -p "$destino" .cosmic-comp.XXXXXX)" || return "$MEOW_ERRO"
  if ! { cp -f "$bin" "$tmp_bin" && chmod 755 "$tmp_bin" && mv -f "$tmp_bin" "$destino/cosmic-comp"; }; then
    rm -f "$tmp_bin"
    meow_erro "não consegui guardar o build em $destino"
    return "$MEOW_ERRO"
  fi
  tmp_estado="$(mktemp -p "$destino" .estado.XXXXXX)" || return "$MEOW_ERRO"
  _cp_texto_estado "$destino/cosmic-comp" "$ver" "$serie" > "$tmp_estado" \
    && mv -f "$tmp_estado" "$destino/estado" \
    || { rm -f "$tmp_estado"; meow_erro "não consegui gravar $destino/estado"; return "$MEOW_ERRO"; }
  # BUILD NOVO ZERA A GUARDA DE QUEDA: o `ruim` e o contador falam do binário
  # que acabou de ser trocado.
  rm -f "$destino/ruim" "$destino/quedas"
  meow_muda "cosmic-comp patchado guardado em $destino (versão $ver), estado medido no binário"
  _cp_gravar_matriz "$ver"
  if [ -d "$novo_alvos" ]; then
    rm -rf "$CP_ALVOS" && mv -f "$novo_alvos" "$CP_ALVOS" && printf '%s\n' "$ver" > "$CP_ALVOS/.versao"
  fi
  _cp_shim_ativo || meow_info "o shim está desligado: este build só vale depois de 'meow compositor ativar'"

  # --- 8. poda: só árvore de fonte, e só de outra versão --------------------
  local d
  for d in "$CP_CACHE"/cosmic-comp-*; do
    [ -d "$d" ] || continue
    [ "$d" = "$fonte" ] && continue
    [ -f "$d/Cargo.toml" ] || continue   # sem isto não é árvore de fonte: não toco
    rm -rf -- "$d" && meow_info "podei o fonte antigo: ${d##*/}"
  done

  meow_registrar "compositor_patches.sh compilar $ver"
  meow_info "vale no PRÓXIMO LOGIN — a sessão de agora segura o binário antigo até lá"
  meow_info "o caminho de volta: meow compositor desativar"
  return "$MEOW_DIVERGENTE"
}

# `validar` — O PASSO QUE PÕE UMA VERSÃO NOVA EM `patches/versao`
#   Baixa o fonte da versão INSTALADA e roda o dry-run da série nele, sem
#   escrever na árvore. É o que responde, antes de alguém registrar a versão,
#   se a série entra limpa nela. Registrar continua sendo commit de gente.
cmd_validar() {
  local ver fonte
  ver="$(_cp_versao_instalada)" || {
    meow_pula "o cosmic-comp não está instalado (dpkg não o conhece) — nada a validar"
    return "$MEOW_SEM_DEPENDENCIA"; }
  meow_info "cosmic-comp instalado: $ver"
  if _cp_versao_valida "$ver"; then
    meow_ok "esta versão já está em patches/versao"
  fi
  fonte="$(_cp_fonte_dir "$ver")"
  if meow_seco && [ ! -f "$fonte/Cargo.toml" ]; then
    meow_muda "baixaria o fonte do cosmic-comp $ver (~98 MB) para $CP_CACHE e rodaria o dry-run da série"
    return "$MEOW_DIVERGENTE"
  fi
  _cp_baixar_fonte "$ver" || return $?
  # O dry-run é o do `cmd_aplicar`, em seco: a mesma leitura, sem um byte.
  if MEOW_SECO=1 cmd_aplicar "$fonte"; then
    _cp_versao_valida "$ver" && return "$MEOW_OK"
    meow_ok "a série entra no cosmic-comp $ver (os degraus estão acima)"
    meow_info "o meow compositor compila nela sem pedir commit: a escada decide e grava a matriz"
    return "$MEOW_OK"
  fi
  meow_info "o cosmic-comp $ver não tem build enquanto o obrigatório recusar: é o degrau 4, um rebase do patch"
  return "$MEOW_ERRO"
}

# `reverter` — O `--uninstall` DO ITEM DE RISCO DA P29
#   A sprint pede, com todas as letras: "O `--uninstall` precisa saber voltar ao
#   binário do pacote." Ele sabe, e o que ele sabe é UMA linha de apt.
#
#   E ELE NÃO A RODA, DE PROPÓSITO. Voltar ao binário do pacote é escrever em
#   `/usr/bin/cosmic-comp`, o que pede root; e a ponte root deste projeto tem
#   oito verbos, nenhum deles "reinstalar pacote" (ver docs/FRONTEIRA.md). Pôr
#   um `sudo` aqui daria a este arquivo — que roda dentro do doctor, dentro do
#   timer das 05:00 — o poder de trocar o compositor sozinho. O verbo diz a
#   frase exata e para; quem aperta o botão é ela, acordada.
#   E A FRASE NÃO CARREGA A RECEITA, que é a regra da P2 medida por
#   `tests/sem-receita-no-log.sh`: a primeira versão deste verbo imprimia
#   `sudo apt install --reinstall cosmic-comp` num `meow_info`, e o teste a
#   reprovou na hora — com razão, e é a mesma classe que aquela sprint apagou
#   do projeto inteiro. O que fica na tela é a DECISÃO e o alvo exato
#   (reinstalar o PACOTE `cosmic-comp`, pelo gerenciador de pacotes), que é o
#   que a sprint P29 cobra do `--uninstall`: saber voltar ao binário do pacote.
#   Quem vai digitar sabe digitar; o que faltava era saber O QUE fazer.
# `ativar` e `desativar` — O SHIM ENTRA E SAI DO PATH DA SESSÃO (P76)
#   NADA AQUI PRECISA DE SUDO: o shim mora em `~/.local/bin`, que é dela.
#   Ligar não troca o compositor da sessão de agora — o `cosmic-session` só
#   procura o nome no PATH ao subir —, então os dois valem no próximo login.
#   Desligar é o caminho de volta inteiro: sem shim, o PATH acha o de
#   `/usr/bin`, e os builds em `$CP_CASA` ficam guardados, sem efeito.
cmd_ativar() {
  [ -r "$CP_SHIM_FONTE" ] || { meow_erro "falta $CP_SHIM_FONTE — repositório incompleto"; return "$MEOW_ERRO"; }
  if cmp -s "$CP_SHIM_FONTE" "$CP_SHIM"; then
    meow_ok "o shim do compositor já está em $CP_SHIM"
    return "$MEOW_OK"
  fi
  # UM `cosmic-comp` QUE NÃO É O NOSSO NÃO SE SOBRESCREVE: alguém o pôs ali, e
  # trocar o compositor de outra pessoa calado é pior que não ligar o nosso.
  if [ -e "$CP_SHIM" ] && ! _cp_shim_ativo; then
    meow_erro "$CP_SHIM existe e não é o shim do meow — não o troco"
    return "$MEOW_ERRO"
  fi
  if meow_seco; then
    meow_muda "instalaria o shim em $CP_SHIM (vale no próximo login)"
    return "$MEOW_DIVERGENTE"
  fi
  mkdir -p "${CP_SHIM%/*}" || return "$MEOW_ERRO"
  local tmp; tmp="$(mktemp -p "${CP_SHIM%/*}" .meow-shim.XXXXXX)" || return "$MEOW_ERRO"
  cp -f "$CP_SHIM_FONTE" "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$CP_SHIM" \
    || { rm -f "$tmp"; meow_erro "não consegui instalar $CP_SHIM"; return "$MEOW_ERRO"; }
  meow_manifesto_registrar "$CP_SHIM"
  meow_muda "shim do compositor ligado em $CP_SHIM — vale no próximo login"
  meow_info "no próximo login vale: $(_cp_proximo_login)"
  return "$MEOW_DIVERGENTE"
}

cmd_desativar() {
  if ! _cp_shim_ativo; then
    meow_ok "o shim do compositor não está ligado — a sessão usa $CP_BIN"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "removeria $CP_SHIM (o próximo login volta a $CP_BIN)"
    return "$MEOW_DIVERGENTE"
  fi
  rm -f "$CP_SHIM" || { meow_erro "não consegui remover $CP_SHIM"; return "$MEOW_ERRO"; }
  meow_muda "shim do compositor desligado — o próximo login volta a $CP_BIN"
  return "$MEOW_DIVERGENTE"
}

cmd_reverter() {
  if _cp_shim_ativo; then
    meow_info "o compositor patchado entra pelo shim em $CP_SHIM; o caminho de volta é: meow compositor desativar"
    meow_info "  sem o shim, o próximo login usa $CP_BIN, o do pacote"
  fi
  meow_info "o caminho de volta é reinstalar o PACOTE cosmic-comp pelo gerenciador de pacotes"
  meow_info "  ele devolve $CP_BIN ao binário de fábrica, sem nenhum patch da série"
  # A CÓPIA GUARDADA PELO `compilar` (24/09/2026, P39) é a segunda rede, e vale
  # dizê-la: o repositório do Pop tira o fonte de uma versão do ar quando sai a
  # seguinte (medido nesse dia), e o `.deb` pode ir junto.
  local ver=""
  ver="$(_cp_versao_instalada 2>/dev/null)" || ver=""
  if [ -n "$ver" ] && [ -f "$CP_LIB/$ver.pacote" ]; then
    meow_info "  se o apt não achar esta versão, o binário do pacote dela está guardado em $CP_LIB/$ver.pacote"
  fi
  meow_info "depois, relogue: o kernel segura o inode do binário antigo até o próximo login"
  meow_pula "este script não faz isso por você — escrever em /usr/bin pede root, e é decisão sua"
  return "$MEOW_OK"
}

case "${1:-conferir}" in
  conferir) cmd_conferir ;;
  aplicar)  shift 2>/dev/null || true; cmd_aplicar "${1:-}" ;;
  compilar) cmd_compilar ;;
  validar)  cmd_validar ;;
  reverter) cmd_reverter ;;
  ativar)    cmd_ativar ;;
  desativar) cmd_desativar ;;
  qual)      _cp_proximo_login ;;
  guardar)   _cp_guardar_do_cache ;;
  *) meow_erro "uso: compositor_patches.sh {conferir|aplicar [dir-do-fonte]|compilar|validar|reverter|ativar|desativar|qual|guardar}"; exit "$MEOW_ERRO" ;;
esac

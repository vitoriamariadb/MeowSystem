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
#      ls -l /proc/3261/exe            -> dono vitoriamaria, -> /usr/bin/cosmic-comp
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
# O CONTRATO COM O OUTRO LADO (acordado em 30/08/2026, não inventar outro)
#   /var/lib/aurora/cosmic-comp-patches.estado  (644, root, legível sem sudo)
#     # gerado por aurora-cosmic-comp-ws.sh — NAO EDITAR A MAO
#     versao=0.1~1787767625~24.04~5c93094
#     gravado=2026-08-30T01:40:00-03:00
#     req AURORA-COSMIC-WS-PATCH-3.67 cosmic-comp-sem-workspace-vazio.patch presente
#     opt AURORA-COSMIC-RADIUS-PATCH-1 cosmic-comp-raio-clampado.patch ausente
#   Linha de patch = QUATRO campos: <req|opt> <marcador> <arquivo.patch> <presente|ausente>
#
#   patches/series — a CÓPIA CANÔNICA desde 22/09/2026 (P29), neste repositório.
#     <classe req|opt> <arquivo.patch> <marcador-base>
#     O `/usr/local/share/aurora/patches.d/series` continua sendo lido como
#     alternativa quando o clone não traz a nossa — ver `CP_SERIE_ALT`.
#
#   O marcador do `.estado` traz a VERSÃO no fim (`-3.67`); o da `series` é a
#   BASE (`AURORA-COSMIC-WS-PATCH`). É de propósito: a base é o que sobrevive a
#   um bump de versão do patch, e é ela que vira regex no binário.
#
# USO
#   compositor_patches.sh conferir            0 = tudo de pé · 1 = divergente · 3 = sem cosmic-comp
#   compositor_patches.sh aplicar <dir-fonte> põe a série numa árvore de fonte do cosmic-comp
#   compositor_patches.sh reverter            diz como voltar ao binário do pacote (não roda)
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
# útil (o caminho do `.estado` é do lado da Aurora, não do gosto dela).
CP_BIN="${CP_BIN:-/usr/bin/cosmic-comp}"
CP_ESTADO="${CP_ESTADO:-/var/lib/aurora/cosmic-comp-patches.estado}"
CP_REPO="${CP_REPO:-$MEOW_RAIZ/patches}"
# A SÉRIE INVERTEU DE LADO EM 22/09/2026 (P29), E A ORDEM É A DECISÃO
#   Até aqui `CP_SERIE` era a da Aurora e a nossa não existia: este arquivo lia
#   `/usr/local/share/aurora/patches.d/series`, e caía em
#   `~/.config/zsh/patches/patches.d/series` quando o Ritual ainda não tinha
#   instalado a primeira. Agora a série mora em `patches/series`, neste
#   repositório, e é ELA a primeira resposta — porque a origem passou a ser
#   aqui, e uma origem que só vale quando a outra falta não é origem.
#
#   A DA AURORA CONTINUA SENDO LIDA, e isso não é indecisão. Numa máquina que
#   fez o Ritual, o binário que está no disco foi compilado a partir DAQUELA
#   série; conferir contra a nossa quando a dela existe e diverge diria verde
#   sobre um binário que não é o que medimos. Por isso ela fica em `ALT`: lida
#   só quando a nossa sumiu, que é o caso de quem rodou este script de fora do
#   clone. O que saiu de vez foi `~/.config/zsh` — território da vizinha, e o
#   assunto inteiro da P29.
CP_SERIE="${CP_SERIE:-$MEOW_RAIZ/patches/series}"
CP_SERIE_ALT="${CP_SERIE_ALT:-/usr/local/share/aurora/patches.d/series}"
# Onde `aplicar` procura a árvore de fonte do cosmic-comp. Sem padrão útil de
# propósito: não há lugar canônico para um `git clone` do compositor nesta
# máquina, e inventar um faria o verbo falhar apontando para um caminho que
# ninguém escolheu. Quem chama nomeia, por argumento ou por esta variável.
CP_FONTE="${CP_FONTE:-}"

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

# --- a série da Aurora ------------------------------------------------------
_cp_serie_arquivo() {
  [ -r "$CP_SERIE" ] && { printf '%s' "$CP_SERIE"; return 0; }
  [ -r "$CP_SERIE_ALT" ] && { printf '%s' "$CP_SERIE_ALT"; return 0; }
  return 1
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
  if [ ! -e "$CP_ESTADO" ]; then
    ritual_ausente=1
    _cp_diz info "quem aplica os patches do compositor é o Ritual da Aurora (aurora-cosmic-comp-ws.sh), que não vem neste repositório"
    _cp_diz info "sem $CP_ESTADO não há o que conferir: nada foi prometido, nada está faltando"
    # Sem crase: dentro de aspas duplas ela vira substituição de comando, e
    # esta frase nomeia um comando de verdade.
    _cp_diz info "o que muda sem eles: o meow painel apara o raio das barras ao que cabe na altura — o resto do tema é igual"
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
      _cp_diz info "um apt trocou o binário depois do último build — a série daqui volta com: compositor_patches.sh aplicar <fonte>"
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
      _cp_diz muda "$marcador está no disco mas NÃO na sessão"
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
    _cp_diz muda "não achei a série ($CP_SERIE, nem $CP_SERIE_ALT)"
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
  meow_muda "$cabeca"
  _cp_despejar
  if [ "$precisa_build" = "1" ]; then
    # O CONSELHO DEIXOU DE APONTAR PARA UM SCRIPT QUE NÃO EXISTE AQUI — 22/09/2026, P29
    #   Esta linha dizia "rode: aurora-cosmic-comp-ws.sh --build". A P22 já
    #   tinha medido que aquele script não está nesta máquina e não está neste
    #   repositório: o doctor mandava, todo dia, rodar um comando que não
    #   existe. Agora os três passos são nomeáveis, e os dois primeiros são
    #   deste projeto.
    meow_info "os patches são daqui desde 22/09/2026 — patches/series, 5 declarados"
    meow_info "  1. aplicar na árvore de fonte:  scripts/compositor_patches.sh aplicar <dir-do-fonte>"
    meow_info "  2. compilar e instalar:         é passo seu — cargo (~4 min) e um install em $CP_BIN"
    meow_info "  3. voltar ao binário do pacote: scripts/compositor_patches.sh reverter (diz como)"
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
    meow_erro "não achei a série ($CP_SERIE, nem $CP_SERIE_ALT)"
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
    else
      estado+=("recusa")
    fi
    n=$((n+1))
  done < "$serie"

  [ "$n" -gt 0 ] || { meow_pula "a série não declara nenhum patch"; return "$MEOW_OK"; }

  # --- a decisão: um `req` que não entra aborta tudo, antes de escrever -----
  local i abortar=0
  for i in "${!classe[@]}"; do
    case "${estado[$i]}" in
      ja)         meow_ok   "${arquivo[$i]} já está na árvore (${base[$i]})" ;;
      pode)       meow_info "${arquivo[$i]} aplica limpo (${classe[$i]})" ;;
      sem-arquivo)
        meow_muda "${arquivo[$i]} está na série e não existe em $CP_REPO"
        [ "${classe[$i]}" = "req" ] && abortar=1 ;;
      recusa)
        if [ "${classe[$i]}" = "req" ]; then
          meow_muda "${arquivo[$i]} é OBRIGATÓRIO e o dry-run recusou"
          abortar=1
        else
          meow_muda "${arquivo[$i]} é opcional e o dry-run recusou — o efeito dele fica de fora"
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
  for i in "${!classe[@]}"; do
    [ "${estado[$i]}" = "pode" ] || { pulados=$((pulados+1)); continue; }
    if (cd "$fonte" && patch "${_CP_PATCH_OPCOES[@]}" < "$CP_REPO/${arquivo[$i]}") >/dev/null 2>&1; then
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
  meow_info "o que falta é seu, e não é pouco: compilar (~4 min) e instalar em $CP_BIN"
  meow_info "o binário do compositor é TAMBÉM a tela de login — leia 'O que pode dar errado' em patches/series"
  return "$MEOW_OK"
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
cmd_reverter() {
  meow_info "o caminho de volta é reinstalar o PACOTE cosmic-comp pelo gerenciador de pacotes"
  meow_info "  ele devolve $CP_BIN ao binário de fábrica, sem nenhum patch da série"
  meow_info "depois, relogue: o kernel segura o inode do binário antigo até o próximo login"
  meow_pula "este script não faz isso por você — escrever em /usr/bin pede root, e é decisão sua"
  return "$MEOW_OK"
}

case "${1:-conferir}" in
  conferir) cmd_conferir ;;
  aplicar)  shift 2>/dev/null || true; cmd_aplicar "${1:-}" ;;
  reverter) cmd_reverter ;;
  *) meow_erro "uso: compositor_patches.sh {conferir|aplicar [dir-do-fonte]|reverter}"; exit "$MEOW_ERRO" ;;
esac

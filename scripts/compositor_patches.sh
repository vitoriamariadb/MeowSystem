#!/usr/bin/env bash
# compositor_patches.sh — os patches do `cosmic-comp` ainda estão de pé?
#
# ESTE ARQUIVO NÃO CONSERTA NADA, E ISSO É O DESENHO
#   O conserto de tudo o que ele mede é **recompilar o compositor** — `cargo`,
#   ~4 min, `sudo install` em `/usr/bin/cosmic-comp`. O `meow doctor` nunca usa
#   sudo, nunca baixa, nunca compila e nunca escreve configuração; e um build de
#   4 minutos disparado pelo timer das 05:00 seria pior que o defeito que ele
#   corrige. Então aqui só existe `conferir`: leitura pura de quatro arquivos e
#   de um `/proc`. Quem conserta é ela, com uma linha:
#
#       aurora-cosmic-comp-ws.sh --build
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
#     a) todo `.patch` de `patches/` está declarado na `series` da Aurora?
#     b) o `.patch` do repositório é BYTE A BYTE igual à cópia que a Aurora
#        aplica? São duas cópias em duas árvores e **nada** as sincroniza: editar
#        uma e esquecer a outra é silencioso, e o binário obedece a dela.
#   As duas por md5 e por nome de arquivo, sem abrir o conteúdo.
#
# ============================================================================
# A FRONTEIRA (docs/FRONTEIRA.md)
# ============================================================================
#   O binário `cosmic-comp`, o `aurora-cosmic-comp-ws.sh`, o `.estado` e a
#   `series` são da **Aurora**. Este arquivo LÊ os quatro e não escreve em
#   nenhum. `~/.config/zsh` é o repositório privado dela, com auto-commit a cada
#   10 min — a TRAVA 1 do `lib/comum.sh` recusa escrita ali, e aqui nem se tenta:
#   o que existe é `md5sum` e `[ -f ]`.
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
#   /usr/local/share/aurora/patches.d/series (cópia canônica em ~/.config/zsh/patches/patches.d/)
#     <classe req|opt> <arquivo.patch> <marcador-base>
#
#   O marcador do `.estado` traz a VERSÃO no fim (`-3.67`); o da `series` é a
#   BASE (`AURORA-COSMIC-WS-PATCH`). É de propósito: a base é o que sobrevive a
#   um bump de versão do patch, e é ela que vira regex no binário.
#
# USO
#   compositor_patches.sh conferir   0 = tudo de pé · 1 = divergente · 3 = sem cosmic-comp
#   compositor_patches.sh aplicar    recusa, e diz por quê (o conserto é compilar)
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
CP_SERIE="${CP_SERIE:-/usr/local/share/aurora/patches.d/series}"
CP_SERIE_ALT="${CP_SERIE_ALT:-$HOME/.config/zsh/patches/patches.d/series}"
CP_REPO="${CP_REPO:-$MEOW_RAIZ/patches}"
# A cópia da Aurora. Em 30/08/2026 o `patches.d/` ainda não existia e o único
# `.patch` dela vivia um nível acima, em `~/.config/zsh/patches/` — por isso as
# duas pastas são procuradas, nesta ordem, e a que for usada aparece na saída.
CP_COPIA="${CP_COPIA:-$HOME/.config/zsh/patches/patches.d}"
CP_COPIA_ALT="${CP_COPIA_ALT:-$HOME/.config/zsh/patches}"

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
_cp_copia_dir() {
  [ -d "$CP_COPIA" ] && { printf '%s' "$CP_COPIA"; return 0; }
  [ -d "$CP_COPIA_ALT" ] && { printf '%s' "$CP_COPIA_ALT"; return 0; }
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
  local estado_ok=0 versao_estado="" gravado=""
  local -a linhas=()
  if [ ! -e "$CP_ESTADO" ]; then
    problemas+=("o .estado da Aurora não existe"); precisa_build=1
    _cp_diz muda "$CP_ESTADO não existe — o build com a série ainda não rodou"
    _cp_diz info "quem o grava é o aurora-cosmic-comp-ws.sh, a cada escrita em $CP_BIN"
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
      _cp_diz info "um apt trocou o binário depois do último build — rode: aurora-cosmic-comp-ws.sh --build"
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
    problemas+=("a série da Aurora não existe"); precisa_build=1
    _cp_diz muda "não achei a série ($CP_SERIE, nem $CP_SERIE_ALT)"
    _cp_diz info "  sem ela o build aplica um patch só, por caminho literal — e ${#repo[@]} .patch daqui não entram em binário nenhum"
    _cp_diz info "  é o passo 1 da Sprint U, do lado da Aurora"
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

  # --- 5. as duas cópias do mesmo .patch ------------------------------------
  # Nada sincroniza `patches/` deste repositório com a árvore da Aurora. Quem
  # edita um e esquece o outro não recebe erro nenhum: o build aplica o DELA, e
  # o nosso vira documentação de uma coisa que não acontece.
  local copia=""
  copia="$(_cp_copia_dir)" || copia=""
  if [ "${#repo[@]}" != "0" ]; then
    if [ -z "$copia" ]; then
      _cp_diz info "a árvore de patches da Aurora não existe ($CP_COPIA) — nada a comparar por md5"
    else
      local difere=0 ausentes=0 p a b
      for p in "${repo[@]}"; do
        if [ ! -r "$copia/$p" ]; then
          ausentes=$((ausentes+1))
          _cp_diz info "$p não tem cópia em $copia (a Aurora não o carrega)"
          continue
        fi
        a="$(md5sum < "$CP_REPO/$p" 2>/dev/null | cut -d' ' -f1)"
        b="$(md5sum < "$copia/$p" 2>/dev/null | cut -d' ' -f1)"
        if [ "$a" != "$b" ]; then
          difere=$((difere+1))
          _cp_diz muda "$p diverge da cópia da Aurora (md5 $a != $b)"
          _cp_diz info "  o build aplica a cópia DELA, em $copia — a nossa é a que está sendo ignorada"
        fi
      done
      [ "$difere" -gt 0 ] && { problemas+=("$(_cp_plural "$difere" patch patches) com md5 diferente da cópia da Aurora"); precisa_build=1; }
      if [ "$difere" = "0" ] && [ "$ausentes" = "0" ]; then
        _cp_diz ok "patches/ está em dia com $copia (${#repo[@]} arquivo, md5 igual)"
      fi
      # O caminho inverso não é divergência nossa, mas explica a tela: o patch de
      # workspace, que é o que segura os workspaces alfinetados dela, vive só do
      # lado da Aurora e este repositório não tem cópia dele.
      local -a dela=()
      mapfile -t dela < <(find "$copia" -maxdepth 1 -name '*.patch' -printf '%f\n' 2>/dev/null | sort)
      local q so_dela=""
      for q in ${dela[@]+"${dela[@]}"}; do
        [ -r "$CP_REPO/$q" ] || so_dela="${so_dela:+$so_dela, }$q"
      done
      [ -n "$so_dela" ] && _cp_diz info "só do lado da Aurora (este repo não carrega): $so_dela"
    fi
  fi

  # --- 6. o resumo, que é a linha da tabela ---------------------------------
  if [ "${#problemas[@]}" = "0" ]; then
    local resumo
    if [ "$conferidos" -gt 0 ]; then
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
    meow_info "o conserto é recompilar: aurora-cosmic-comp-ws.sh --build (~4 min)"
    meow_info "o doctor não compila, não usa sudo e não escreve — ele só mede e conta"
  else
    meow_info "nada a recompilar: o binário do disco está em dia, quem está velho é a sessão"
    meow_info "o próximo login resolve sozinho — não há comando a rodar"
  fi
  rc="$MEOW_DIVERGENTE"
  return "$rc"
}

# NÃO EXISTE `aplicar`, E A RECUSA É O COMPORTAMENTO
#   Sai com 0 de propósito: isto não é falha de nada, é um verbo que este módulo
#   não tem. Sair com erro faria uma passagem do install.sh (que roda todo módulo
#   em sequência) parecer quebrada por causa de um script que se recusou a fazer
#   o que nunca prometeu.
cmd_aplicar() {
  meow_pula "compositor_patches.sh não aplica nada — o conserto é recompilar o cosmic-comp"
  meow_info "o doctor nunca usa sudo, nunca baixa e nunca compila (~4 min de cargo)"
  meow_info "o comando é dela: aurora-cosmic-comp-ws.sh --build"
  return "$MEOW_OK"
}

case "${1:-conferir}" in
  conferir) cmd_conferir ;;
  aplicar)  cmd_aplicar ;;
  *) meow_erro "uso: compositor_patches.sh {conferir|aplicar}"; exit "$MEOW_ERRO" ;;
esac

#!/usr/bin/env bash
# compositor_patches.sh — os patches do `cosmic-comp` ainda estão de pé?
#
# O conserto de tudo o que ele mede é **recompilar o compositor** — `cargo`, ~4
# min, um install em `/usr/bin/cosmic-comp`.
#
# Isso não é defeito nenhum e não há o que fazer hoje; dizer "FALTA o patch"
# nessa hora mandaria ela recompilar de graça.
#
#       FALTA <marcador>                              -> o build precisa ser refeito
#       <marcador> está no disco mas NÃO na sessão    -> vale no próximo login
#
# As duas nunca se colapsam numa só.
#
# A tabela do doctor ela lê; o balãozinho, não.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# Todos com override por variável: é o que deixa testar sem root e sem mexer na
# máquina dela.
CP_BIN="${CP_BIN:-/usr/bin/cosmic-comp}"
# `/var/lib`, e não o `/usr/local/lib/meowsystem` da ponte: lá mora programa,
# aqui mora dado que o programa grava (o `.estado` e a cópia do binário do
# pacote).
CP_LIB="${CP_LIB:-/var/lib/meowsystem/cosmic-comp}"
CP_ESTADO="${CP_ESTADO:-$CP_LIB/patches.estado}"
CP_REPO="${CP_REPO:-$MEOW_RAIZ/patches}"
# A versão do pacote contra a qual a série foi validada. Ver o próprio arquivo.
CP_VERSOES="${CP_VERSOES:-$MEOW_RAIZ/patches/versao}"
# Cache, e não estado: apagar esta pasta custa um download e uma compilação
# do zero (~30 min), nunca um dado.
CP_CACHE="${CP_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem/cosmic-comp}"
# Cache é o que se recria; isto não se recria mais. O `.dsc` e o `.tar.xz`
# moram aqui (é a mesma guarda do `meow cosmic prever`), e só a ÁRVORE
# extraída e compilada continua no cache.
CP_GUARDA="${CP_GUARDA:-${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/fontes/cosmic-comp}"
# Até aqui `CP_SERIE` era a da Aurora e a nossa não existia: este arquivo lia
# `/usr/local/share/aurora/patches.d/series`, e caía em
# `~/.config/zsh/patches/patches.d/series` quando o Ritual ainda não tinha
# instalado a primeira.
#
# Ela ficava em `CP_SERIE_ALT`, lida quando a nossa faltava, porque numa
# máquina que fez o Ritual o binário do disco tinha sido compilado a partir
# DELA.
CP_SERIE="${CP_SERIE:-$MEOW_RAIZ/patches/series}"
# Onde `aplicar` procura a árvore de fonte do cosmic-comp.
CP_FONTE="${CP_FONTE:-}"
# Quem o põe na sessão é o shim (`scripts/compositor_shim.sh`), instalado como
# `~/.local/bin/cosmic-comp` pelo `ativar` — o `cosmic-session` acha o
# compositor pelo PATH, e o PATH da sessão começa ali.
CP_CASA="${CP_CASA:-$HOME/.local/libexec/meow/cosmic-comp}"
CP_SHIM="${CP_SHIM:-$HOME/.local/bin/cosmic-comp}"
CP_SHIM_FONTE="$MEOW_RAIZ/scripts/compositor_shim.sh"
CP_SHIM_MARCA="MEOW-COSMIC-COMP-SHIM"
# A MATRIZ DE COMPATIBILIDADE GRAVADA PELA MÁQUINA
CP_MATRIZ="${CP_MATRIZ:-$MEOW_ESTADO/cosmic-comp/matriz.tsv}"
# Os arquivos que a série toca, como estavam no fonte PURO da última versão
# que compilou. É contra eles que o degrau 1 pergunta "o upstream mexeu aqui?".
CP_ALVOS="${CP_ALVOS:-$MEOW_ESTADO/cosmic-comp/alvos}"
# A TRAVA DA FUNÇÃO ÚNICA DOS BUILDS: segurada, há uma passagem
# compilando agora. O `conferir` só a lê.
CP_TRAVA_BUILDS="${CP_TRAVA_BUILDS:-$MEOW_ESTADO/builds.lock}"

# --- o buffer de saída ------------------------------------------------------
#
# O `primeira_linha` do `bin/meow` corta a saída no primeiro `\n` e é isso que
# cabe na coluna da direita.
#
# Um `meow_aviso` a menos custa a cor amarela do `!!`; a linha trocada custa a
# leitura inteira.
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
# AURORA-COSMIC-WS-PATCH.
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
  # vale também a versão em que a escada pôs o `req` no build.
  awk -F'\t' -v v="$v" '$1==v && $3 !~ /:4( |$)/ {ok=1} END {exit !ok}' "$CP_MATRIZ" 2>/dev/null
}

# --- o shim -----------------------------------------------------------
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
  # "está no disco mas NÃO na sessão" diz, com todas as letras, que não há nada
  # a recompilar — e emendar "rode o --build" logo abaixo faria a pessoa pagar 4
  # min de cargo para consertar um logout.
  local precisa_build=0

  # 3, e não 2 nem 4: numa máquina sem `cosmic-comp` não há divergência, há
  # ausência de assunto — é a mesma leitura do `chk_relogio` sem o applet, e o
  # runner do doctor pinta 3 e 4 com o mesmo `--` cinza.
  if [ ! -e "$CP_BIN" ]; then
    meow_pula "cosmic-comp não está instalado — nada a conferir nos patches"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # Rodar o doctor por ssh, ou de um TTY, ou com o desktop caído, deixa `pgrep`
  # vazio — e a metade do DISCO da pergunta continua tendo resposta útil (é
  # justamente ela que diz se o build precisa ser refeito).
  #
  # O `/usr/bin/cosmic-comp` volta a ser de fábrica e fica de fábrica; o
  # `.estado` de `/var/lib` fala de um arranjo que acabou.
  local com_shim=0
  if _cp_shim_ativo; then
    com_shim=1
    local v_shim="" casa_v=""
    v_shim="$(_cp_versao_instalada 2>/dev/null)" || v_shim=""
    casa_v="$CP_CASA/$v_shim"
    if [ -e "$casa_v/ruim" ]; then
      meow_muda "o build do cosmic-comp $v_shim caiu duas vezes seguidas e foi posto de lado — a sessão sobe de fábrica até a próxima versão"
      return "$MEOW_DIVERGENTE"
    fi
    if [ ! -x "$casa_v/cosmic-comp" ] || [ ! -r "$casa_v/estado" ]; then
      # O DEGRAU 4 ACENDE: sem build porque o `req` não entra nesta versão não
      # é "o pós-apt ainda vem" — é o único degrau que pede gente (§4.3 da
      # pesquisa), e a matriz já o gravou.
      if awk -F'\t' -v v="$v_shim" '$1==v && $3 ~ /:4( |$)/ {achou=1} END {exit !achou}' "$CP_MATRIZ" 2>/dev/null; then
        meow_muda "o patch obrigatório não entra no cosmic-comp $v_shim (degrau 4) — a sessão sobe de fábrica até um rebase"
        return "$MEOW_DIVERGENTE"
      fi
      # Era aviso com 0 — o doctor nunca chamava conserto nenhum, e a linha
      # mandava digitar. Enquanto a passagem compila, é espera, e espera é
      # aviso.
      if [ -e "$CP_TRAVA_BUILDS" ] && ! flock -n "$CP_TRAVA_BUILDS" true 2>/dev/null; then
        meow_aviso "construindo o build do cosmic-comp $v_shim — vale no próximo login"
        return "$MEOW_OK"
      fi
      meow_muda "o cosmic-comp $v_shim ainda não tem build nosso — a sessão sobe de fábrica, sem os patches"
      return "$MEOW_DIVERGENTE"
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
  #
  # Até esta data a ausência do `.estado` entrava em `problemas` e ligava o
  # `precisa_build`.
  #
  # Divergência é para o que o projeto sabe consertar; o resto é informação.
  #
  # O 3 fica reservado para a máquina sem compositor nenhum, que é onde ele já
  # estava.
  local estado_ok=0 ritual_ausente=0 versao_estado="" gravado=""
  local -a linhas=()
  # O NOME `ritual_ausente` FICOU, E O SENTIDO MUDOU: era "esta máquina não
  # fez o Ritual da Aurora"; agora é "o `meow compositor` nunca instalou nada
  # aqui".
  if [ ! -e "$CP_ESTADO" ]; then
    ritual_ausente=1
    _cp_diz info "os patches do compositor entram pelo shim, e ele está desligado nesta máquina"
    _cp_diz info "sem $CP_ESTADO não há o que conferir: nada foi prometido, nada está faltando"
    # Sem crase: dentro de aspas duplas ela vira substituição de comando, e
    # esta frase nomeia um comando de verdade.
    _cp_diz info "o que muda sem eles: o meow painel apara o raio das barras ao que cabe na altura — o resto do tema é igual"
    # Sem `.estado` nada foi prometido, então uma versão fora de
    # `patches/versao` não é divergência — é só o que o `meow compositor` vai
    # responder se alguém o chamar, dito antes, para ninguém descobrir na
    # recusa.
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
  # O `.estado` fala de UM binário.
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
      _cp_diz info "um apt trocou o binário depois do último build — a série volta no próximo build"
      # E o `meow compositor` recusa versão que não esteja em
      # `patches/versao`. Dizer isto aqui poupa a pessoa de descobrir na
      # recusa, depois de já ter decidido parar para compilar.
      _cp_versao_valida "$versao_dpkg" || \
        _cp_diz info "  a versão é nova para a série: o build decide patch a patch"
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
      # sumiu por semanas.
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
  if [ "$fora_da_sessao" -gt 0 ]; then
    if [ "$com_shim" = "1" ]; then problemas+=("build pronto, vale no próximo login")
    else problemas+=("$(_cp_plural "$fora_da_sessao" 'marcador só vale' 'marcadores só valem') no próximo login"); fi
  fi

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

  local serie=""
  serie="$(_cp_serie_arquivo)" || serie=""
  # Este conferidor o comparou contra a série da Aurora — que é a série do
  # `cosmic-comp` — e disse duas coisas erradas com cara de certo: "está no repo
  # e não na série, nunca entra em binário nenhum" e "a Aurora não o carrega".
  #
  # O FILTRO É PELO NOME, e isso é deliberado: o alternativo seria abrir cada
  # `.patch` e adivinhar o alvo pelos `+++`, que responde errado no dia em que
  # um patch do cosmic-comp tocar um arquivo de nome parecido.
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
    # A série é artefato do Ritual: numa máquina que nunca o fez ela falta pelo
    # mesmo motivo que o `.estado`, e cobrar aqui traria de volta, por esta
    # linha, o vermelho eterno que o bloco 1 acabou de tirar.
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

  # --- 5. --------------------------------------
  # AQUI MORAVA A COMPARAÇÃO POR MD5 CONTRA A ÁRVORE DA VIZINHA, E ELA ERA A
  # DIVERGÊNCIA ETERNA O bloco abrisse `~/.config/zsh/patches/patches.d/`,
  # comparava `md5sum` de cada `.patch` daqui com o de lá, e imprimia duas
  # linhas que o doctor repetiu todo dia por semanas:
  #
  #       patches/ está em dia com ~/.config/zsh/patches/patches.d (4 arquivo, md5 igual)
  #       só do lado da Aurora (este repo não carrega): cosmic-comp-sem-workspace-vazio.patch

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

  # Quando a ÚNICA coisa que falta é a sessão trocar de binário, o disco está em
  # dia, não há o que recompilar e não há comando que resolva: a frase de baixo
  # sempre disse isso.
  if [ "$precisa_build" = "0" ] && [ "$fora_da_sessao" -gt 0 ] \
     && [ "${#problemas[@]}" = "1" ]; then
    meow_aviso "$cabeca"
    _cp_despejar
    meow_info "nada a recompilar: o binário do disco está em dia, quem está velho é a sessão"
    meow_info "o próximo login resolve sozinho — não há comando a rodar"
    return "$MEOW_OK"
  fi
  # Ligar e desligar o shim é gesto dela (o `meow compositor desativar` é o
  # caminho de volta do docs/MANUTENCAO.md).
  if [ "$precisa_build" = "1" ] && [ "$com_shim" = "0" ]; then
    meow_pula "o shim do compositor está desligado — a sessão usa o de fábrica, sem os patches"
    _cp_despejar
    meow_info "o .estado de $CP_ESTADO é de antes do shim; com o shim ligado, o build da versão entra no próximo login"
    return 4
  fi
  meow_muda "$cabeca"
  _cp_despejar
  if [ "$precisa_build" = "1" ]; then
    # Esta linha dizia "rode: aurora-cosmic-comp-ws.sh --build". Agora os três
    # passos são nomeáveis, e os dois primeiros são deste projeto.
    #
    # Sem esta linha, depois do próximo apt o doctor mandaria rodar `meow
    # compositor`, o build sairia certo, e o doctor seguinte acusaria o mesmo
    # `/usr/bin` de fábrica — um conselho que não converge nunca.
    meow_info "o conserto recompila o compositor com a série de patches/, em segundo plano, sem sudo"
  else
    meow_info "nada a recompilar: o binário do disco está em dia, quem está velho é a sessão"
    meow_info "o próximo login resolve sozinho — não há comando a rodar"
  fi
  rc="$MEOW_DIVERGENTE"
  return "$rc"
}

# Ele aplica a série numa ÁRVORE DE FONTE do cosmic-comp que quem chama nomeia.
# Ele NÃO baixa o fonte, NÃO roda `cargo`, NÃO usa sudo e NÃO escreve em
# `/usr/bin`.
#
# POR QUE A LINHA CAI AQUI, e não um passo adiante.
_CP_PATCH_OPCOES=(-p1 --forward -F0 --no-backup-if-mismatch --silent)
# O SEGUNDO DEGRAU DA ESCADA: `-F1` aceita UMA linha de contexto que mudou.
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
  # Os arquivos que um `.patch` toca, lidos das linhas `+++`.
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
  # A árvore certa tem `Cargo.toml` e `src/`.
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
  # "é seu" ali seria mentira de três linhas.
  if [ "${_CP_COMPILANDO:-0}" != "1" ]; then
    meow_info "o que falta: compilar (~4 min) e instalar em $CP_BIN — o meow compositor faz os dois"
    meow_info "o binário do compositor é TAMBÉM a tela de login — leia 'O que pode dar errado' em patches/series"
  fi
  return "$MEOW_OK"
}

# O doctor daqui nunca compila e nunca usa sudo, e o timer das 05:00 roda o
# doctor.
#
# Ele recusaria a máquina que compila.
_cp_fonte_dir() { printf '%s/cosmic-comp-%s' "$CP_CACHE" "$1"; }

declare -a _CP_RECEITA=() _CP_PEDE=()
_CP_RECEITA_NOME=""
_cp_receita() { # $1 = árvore do fonte
  if grep -qsE '^build-vendored([ :]|$)' "$1/justfile" "$1"/*.just; then
    _CP_RECEITA=(just build-vendored); _CP_PEDE=(just cargo)
  elif [ -f "$1/Makefile" ]; then
    _CP_RECEITA=(make VENDOR=1); _CP_PEDE=(make cargo)
  else
    _CP_RECEITA=(sh -c 'tar pxf vendor.tar && cargo build --release --frozen --offline'); _CP_PEDE=(tar cargo)
    _CP_RECEITA_NOME="cargo build --frozen --offline"; return 0
  fi
  _CP_RECEITA_NOME="${_CP_RECEITA[*]}"
}

# Idempotente: o que já está lá não se copia de novo.
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
      # O 404 TEM FRASE PRÓPRIA porque foi medido, e não é raro: o repositório
      # do Pop já não servia o `.tar.xz` da versão instalada nesta máquina.
      if grep -q ' 404 ' "$log" 2>/dev/null; then
        meow_info "  o repositório já não serve o fonte desta versão (404)"
        meow_info "  o caminho é atualizar o cosmic-comp — o apt traz binário e fonte da mesma versão — e validar a série nela"
      else
        meow_info "  o deb-src está habilitado nas fontes do apt? o registro está em $log"
      fi
      return "$MEOW_ERRO"
    fi
  fi
  # Chegar aqui quer dizer que `$dir` não tem `Cargo.toml` (o teste do topo), e
  # o `dpkg-source -x` recusa extrair num alvo que existe: uma extração
  # interrompida travaria todo build seguinte desta versão.
  rm -rf "$dir"
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

# É a regra que o outro lado aprendeu e que vem junto: o `#[used]` pode ter
# sido comido pelo linker, e um arquivo de diagnóstico que grava o que a série
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
  # A data de modificação dela diz «a série foi pesada agora»: o
  # `garantir_builds.sh` a compara com `patches/` para não refazer um
  # degrau 4 que a mesma série recusaria de novo, e para saber que o degrau
  # 4 é desta tentativa.
  if awk -F'\t' -v v="$ver" -v d="${_CP_DEGRAUS[*]}" '$1==v && $3==d {achou=1} END {exit !achou}' "$CP_MATRIZ" 2>/dev/null; then
    touch "$CP_MATRIZ"
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
  # Ela existia porque este binário ia para `/usr/bin`, que é também a tela de
  # login: um hunk que "quase" casa subiria quebrado para a sessão E para o
  # greeter.
  if _cp_versao_valida "$ver"; then
    meow_ok "esta versão já passou pela série (patches/versao ou a matriz)"
  else
    meow_info "versão nova para a série: a escada decide patch a patch e grava em $CP_MATRIZ"
  fi

  # Antes do download, só o que todo caminho usa; a ferramenta da receita é
  # conferida quando o fonte disser qual é (`_cp_receita`, depois do passo 3).
  local -a faltam=()
  for i in patch cargo; do meow_tem "$i" || faltam+=("$i"); done
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
      meow_muda "baixaria o fonte do cosmic-comp $ver (~98 MB) para $CP_GUARDA e o abriria em $CP_CACHE"
    fi
    meow_muda "aplicaria a série ($(_cp_plural "$n_req" obrigatório obrigatórios), $(_cp_plural "$n_opt" opcional opcionais)) pela escada (-F0, depois -F1), dry-run de todos antes"
    if [ -f "$fonte/Cargo.toml" ]; then
      _cp_receita "$fonte"
      meow_muda "compilaria com $_CP_RECEITA_NOME (~4 min com o vendor quente, ~30 min do zero)"
    else
      meow_muda "compilaria com a receita que o fonte trouxer (~4 min com o vendor quente, ~30 min do zero)"
    fi
    meow_muda "conferiria os marcadores no binário e o guardaria em $CP_CASA/$ver — sem sudo"
    meow_muda "gravaria o estado medido em $CP_CASA/$ver/estado"
    meow_info "vale no próximo login com o shim ligado"
    return "$MEOW_DIVERGENTE"
  fi

  _cp_baixar_fonte "$ver" || return $?
  _cp_receita "$fonte"
  faltam=()
  for i in "${_CP_PEDE[@]}"; do meow_tem "$i" || faltam+=("$i"); done
  if [ "${#faltam[@]}" -gt 0 ]; then
    meow_erro "falta para compilar este fonte ($_CP_RECEITA_NOME): ${faltam[*]}"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # OS ARQUIVOS PUROS QUE A SÉRIE TOCA, guardados ANTES de a série escrever
  # neles: se este build der certo, eles viram a "última versão boa" contra a
  # qual o degrau 1 da próxima versão pergunta.
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

  meow_info "compilando com $_CP_RECEITA_NOME, Nice 19 (~4 min com o vendor quente, ~30 min do zero)"
  meow_info "  o registro vai para $log"
  if ! ( cd "$fonte" && nice -n 19 "${_CP_RECEITA[@]}" ) >"$log" 2>&1; then
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

  # --- 7. a instalação, EM ESCOPO DE USUÁRIO ---------------------------
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
  _cp_shim_ativo || meow_info "o shim está desligado: o build fica guardado, sem efeito na sessão"

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
  # Compilou e guardou: é sucesso, e sai 0 como o pós-apt (o 1 lia «falhou»).
  return "$MEOW_OK"
}

# `validar` — O PASSO QUE PÕE UMA VERSÃO NOVA EM `patches/versao` Baixa o
# fonte da versão INSTALADA e roda o dry-run da série nele, sem escrever na
# árvore.
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
    meow_muda "baixaria o fonte do cosmic-comp $ver (~98 MB) para $CP_GUARDA, o abriria em $CP_CACHE e rodaria o dry-run da série"
    return "$MEOW_DIVERGENTE"
  fi
  _cp_baixar_fonte "$ver" || return $?
  _cp_receita "$fonte"
  faltam=()
  for i in "${_CP_PEDE[@]}"; do meow_tem "$i" || faltam+=("$i"); done
  if [ "${#faltam[@]}" -gt 0 ]; then
    meow_erro "falta para compilar este fonte ($_CP_RECEITA_NOME): ${faltam[*]}"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
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

# Voltar ao binário do pacote é escrever em `/usr/bin/cosmic-comp`, o que pede
# root; e a ponte root deste projeto tem oito verbos, nenhum deles "reinstalar
# pacote" (ver docs/FRONTEIRA.md).
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
  # A CÓPIA GUARDADA PELO `compilar` é a segunda rede, e vale dizê-la: o
  # repositório do Pop tira o fonte de uma versão do ar quando sai a seguinte
  # (medido nesse dia), e o `.deb` pode ir junto.
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

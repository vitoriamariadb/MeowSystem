#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

CP_BIN="${CP_BIN:-/usr/bin/cosmic-comp}"
CP_LIB="${CP_LIB:-/var/lib/meowsystem/cosmic-comp}"
CP_ESTADO="${CP_ESTADO:-$CP_LIB/patches.estado}"
CP_REPO="${CP_REPO:-$MEOW_RAIZ/patches}"
CP_VERSOES="${CP_VERSOES:-$MEOW_RAIZ/patches/versao}"
CP_CACHE="${CP_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem/cosmic-comp}"
CP_GUARDA="${CP_GUARDA:-${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/fontes/cosmic-comp}"
CP_SERIE="${CP_SERIE:-$MEOW_RAIZ/patches/series}"
CP_FONTE="${CP_FONTE:-}"
CP_CASA="${CP_CASA:-$HOME/.local/libexec/meow/cosmic-comp}"
CP_SHIM="${CP_SHIM:-$HOME/.local/bin/cosmic-comp}"
CP_SHIM_FONTE="$MEOW_RAIZ/scripts/compositor_shim.sh"
CP_SHIM_MARCA="MEOW-COSMIC-COMP-SHIM"
CP_MATRIZ="${CP_MATRIZ:-$MEOW_ESTADO/cosmic-comp/matriz.tsv}"
CP_ALVOS="${CP_ALVOS:-$MEOW_ESTADO/cosmic-comp/alvos}"
CP_TRAVA_BUILDS="${CP_TRAVA_BUILDS:-$MEOW_ESTADO/builds.lock}"

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

_cp_base() { printf '%s' "${1%-*}"; }

_cp_marcadores() {
  local arq="$1" base="$2"
  [ -r "$arq" ] || return 1
  grep -a -o "$base-[0-9][0-9.]*" "$arq" 2>/dev/null | sort -u
}

_cp_marcador_declarado() {
  sed -n "s/^+.*\"\($2-[0-9][0-9.]*\)\".*/\1/p" "$1" 2>/dev/null | head -1
}

_cp_tem() {
  local alvo="$1"; shift
  local m
  for m in "$@"; do [ "$m" = "$alvo" ] && return 0; done
  return 1
}

_cp_serie_arquivo() {
  [ -r "$CP_SERIE" ] && { printf '%s' "$CP_SERIE"; return 0; }
  return 1
}

_cp_versao_instalada() {
  local v
  v="$(dpkg-query -W -f='${Version}' cosmic-comp 2>/dev/null)" || return 1
  [ -n "$v" ] || return 1
  printf '%s' "$v"
}

_cp_versoes_validadas() {
  [ -r "$CP_VERSOES" ] || return 1
  sed -e 's/#.*//' "$CP_VERSOES" | awk 'NF { print $1 }'
}

_cp_versao_valida() {
  local v="$1" x
  while IFS= read -r x; do
    [ "$x" = "$v" ] && return 0
  done < <(_cp_versoes_validadas)
  awk -F'\t' -v v="$v" '$1==v && $3 !~ /:4( |$)/ {ok=1} END {exit !ok}' "$CP_MATRIZ" 2>/dev/null
}

_cp_shim_ativo() { grep -qs -- "$CP_SHIM_MARCA" "$CP_SHIM"; }

_cp_proximo_login() {
  if _cp_shim_ativo; then
    MEOW_SHIM_SO_DIZER=1 MEOW_SHIM_CASA="$CP_CASA" MEOW_SHIM_FABRICA="$CP_BIN" bash "$CP_SHIM"
  else
    printf '%s\n' "$CP_BIN"
  fi
}

_cp_plural() { [ "$1" = "1" ] && printf '%s %s' "$1" "$2" || printf '%s %s' "$1" "$3"; }

cmd_conferir() {
  local -a problemas=()
  local rc=0
  local precisa_build=0

  if [ ! -e "$CP_BIN" ]; then
    meow_pula "cosmic-comp não está instalado — nada a conferir nos patches"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

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
      if awk -F'\t' -v v="$v_shim" '$1==v && $3 ~ /:4( |$)/ {achou=1} END {exit !achou}' "$CP_MATRIZ" 2>/dev/null; then
        meow_muda "o patch obrigatório não entra no cosmic-comp $v_shim (degrau 4) — a sessão sobe de fábrica até um rebase"
        return "$MEOW_DIVERGENTE"
      fi
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

  local estado_ok=0 ritual_ausente=0 versao_estado="" gravado=""
  local -a linhas=()
  if [ ! -e "$CP_ESTADO" ]; then
    ritual_ausente=1
    _cp_diz info "os patches do compositor entram pelo shim, e ele está desligado nesta máquina"
    _cp_diz info "sem $CP_ESTADO não há o que conferir: nada foi prometido, nada está faltando"
    _cp_diz info "o que muda sem eles: o meow painel apara o raio das barras ao que cabe na altura — o resto do tema é igual"
    local v_inst=""
    v_inst="$(_cp_versao_instalada 2>/dev/null)" || v_inst=""
    if [ -n "$v_inst" ] && ! _cp_versao_valida "$v_inst"; then
      _cp_diz info "o cosmic-comp instalado ($v_inst) ainda não passou pela série: a escada decide no primeiro build"
    fi
  elif [ ! -r "$CP_ESTADO" ]; then
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
      _cp_versao_valida "$versao_dpkg" || \
        _cp_diz info "  a versão é nova para a série: o build decide patch a patch"
    fi
  fi

  local faltando=0 fora_da_sessao=0 conferidos=0
  local linha classe marcador arquivo situacao base
  local -a m_disco=() m_sessao=()
  for linha in ${linhas[@]+"${linhas[@]}"}; do
    # shellcheck disable=SC2086
    set -- $linha
    [ $# -ge 4 ] || { _cp_diz info "linha ignorada no .estado (esperados 4 campos): $linha"; continue; }
    classe="$1"; marcador="$2"; arquivo="$3"; situacao="$4"

    if [ "$situacao" != "presente" ]; then
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
  if [ "$fora_da_sessao" -gt 0 ]; then
    if [ "$com_shim" = "1" ]; then problemas+=("build pronto, vale no próximo login")
    else problemas+=("$(_cp_plural "$fora_da_sessao" 'marcador só vale' 'marcadores só valem') no próximo login"); fi
  fi

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
  local -a repo=()
  mapfile -t repo < <(find "$CP_REPO" -maxdepth 1 -name 'cosmic-comp-*.patch' -printf '%f\n' 2>/dev/null | sort)

  local -a outros=()
  mapfile -t outros < <(find "$CP_REPO" -maxdepth 1 -name '*.patch' ! -name 'cosmic-comp-*.patch' -printf '%f\n' 2>/dev/null | sort)
  if [ "${#outros[@]}" -gt 0 ]; then
    _cp_diz info "fora desta conta (não são do cosmic-comp, têm dono próprio): ${outros[*]}"
  fi

  if [ "${#repo[@]}" = "0" ]; then
    _cp_diz info "nenhum .patch em $CP_REPO — nada a comparar com a série"
  elif [ -z "$serie" ]; then
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

  if [ "${#problemas[@]}" = "0" ]; then
    local resumo
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

  local cabeca="${problemas[0]}"
  [ "${#problemas[@]}" -ge 2 ] && cabeca="$cabeca; ${problemas[1]}"
  [ "${#problemas[@]}" -ge 3 ] && cabeca="$cabeca (+$(( ${#problemas[@]} - 2 )) a mais)"

  if [ "$precisa_build" = "0" ] && [ "$fora_da_sessao" -gt 0 ] \
     && [ "${#problemas[@]}" = "1" ]; then
    meow_aviso "$cabeca"
    _cp_despejar
    meow_info "nada a recompilar: o binário do disco está em dia, quem está velho é a sessão"
    meow_info "o próximo login resolve sozinho — não há comando a rodar"
    return "$MEOW_OK"
  fi
  if [ "$precisa_build" = "1" ] && [ "$com_shim" = "0" ]; then
    meow_pula "o shim do compositor está desligado — a sessão usa o de fábrica, sem os patches"
    _cp_despejar
    meow_info "o .estado de $CP_ESTADO é de antes do shim; com o shim ligado, o build da versão entra no próximo login"
    return 4
  fi
  meow_muda "$cabeca"
  _cp_despejar
  if [ "$precisa_build" = "1" ]; then
    meow_info "o conserto recompila o compositor com a série de patches/, em segundo plano, sem sudo"
  else
    meow_info "nada a recompilar: o binário do disco está em dia, quem está velho é a sessão"
    meow_info "o próximo login resolve sozinho — não há comando a rodar"
  fi
  rc="$MEOW_DIVERGENTE"
  return "$rc"
}

_CP_PATCH_OPCOES=(-p1 --forward -F0 --no-backup-if-mismatch --silent)
_CP_PATCH_OPCOES_F1=(-p1 --forward -F1 --no-backup-if-mismatch --silent)

declare -a _CP_DEGRAUS=()

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
  sed -n 's|^+++ [ab]/\([^[:space:]]*\).*|\1|p' "$1" 2>/dev/null | sort -u
}

_cp_ja_aplicado() {
  local fonte="$1" patch_arq="$2" base="$3" alvo marca procura
  marca="$(_cp_marcador_declarado "$patch_arq" "$base")"
  procura="$base"; [ -n "$marca" ] && procura="\"$marca\""
  while IFS= read -r alvo; do
    [ -n "$alvo" ] || continue
    [ -f "$fonte/$alvo" ] || continue
    grep -qF -- "$procura" "$fonte/$alvo" 2>/dev/null && return 0
  done < <(_cp_alvos_do_patch "$patch_arq")
  return 1
}

_cp_outra_versao() {
  local fonte="$1" patch_arq="$2" base="$3" alvo
  [ -n "$(_cp_marcador_declarado "$patch_arq" "$base")" ] || return 1
  _cp_ja_aplicado "$fonte" "$patch_arq" "$base" && return 1
  while IFS= read -r alvo; do
    [ -n "$alvo" ] && grep -qF -- "$base" "$fonte/$alvo" 2>/dev/null && return 0
  done < <(_cp_alvos_do_patch "$patch_arq")
  return 1
}
_cp_arvore_velha() {
  local fonte="$1" serie="$2" _c a b
  while IFS=$'\t' read -r _c a b; do
    _cp_outra_versao "$fonte" "$CP_REPO/$a" "$b" && return 0
  done < <(_cp_serie_entradas "$serie")
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
  if [ ! -f "$fonte/Cargo.toml" ] || [ ! -d "$fonte/src" ]; then
    meow_erro "$fonte não parece a árvore do cosmic-comp (falta Cargo.toml ou src/)"
    return "$MEOW_ERRO"
  fi

  meow_info "série: $serie"
  meow_info "fonte: $fonte"

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
    elif _cp_outra_versao "$fonte" "$p" "${campos[2]}"; then
      estado+=("velho")
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
      velho)
        meow_muda "${arquivo[$i]} está na árvore em outra versão — só um fonte reextraído recebe a que o .patch declara"
        abortar=1 ;;
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

  if meow_seco; then
    meow_muda "aplicaria a série em $fonte (nenhum byte escrito neste ensaio)"
    return "$MEOW_OK"
  fi

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
      meow_erro "${arquivo[$i]} falhou na aplicação depois de o dry-run ter passado"
      meow_info "  a árvore em $fonte mudou no meio do caminho; confira os .rej"
      return "$MEOW_ERRO"
    fi
  done

  meow_ok "$(_cp_plural "$aplicados" 'patch aplicado' 'patches aplicados') na árvore ($pulados sem mexer)"
  if [ "${_CP_COMPILANDO:-0}" != "1" ]; then
    meow_info "o que falta: compilar (~4 min) e instalar em $CP_BIN — o meow compositor faz os dois"
    meow_info "o binário do compositor é TAMBÉM a tela de login — leia 'O que pode dar errado' em patches/series"
  fi
  return "$MEOW_OK"
}

_cp_fonte_dir() { printf '%s/cosmic-comp-%s' "$CP_CACHE" "$1"; }

declare -a _CP_RECEITA=() _CP_PEDE=()
_CP_RECEITA_NOME=""
_cp_receita() {
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
  meow_tem dpkg-source || { meow_erro "falta o dpkg-source (do dpkg-dev): sem ele o fonte baixa e não se extrai"; return "$MEOW_SEM_DEPENDENCIA"; }
  mkdir -p "$CP_CACHE" "$CP_GUARDA" || { meow_erro "não consegui criar $CP_CACHE e $CP_GUARDA"; return "$MEOW_ERRO"; }
  _cp_guardar_do_cache
  log="$CP_CACHE/baixar-$ver.log"
  dsc="$CP_GUARDA/cosmic-comp_${ver#*:}.dsc"
  if [ -f "$dsc" ]; then
    meow_info "o fonte do cosmic-comp $ver está guardado: $CP_GUARDA"
  else
    meow_info "BAIXA DA INTERNET: o fonte do cosmic-comp $ver (~98 MB), para $CP_GUARDA"
    if ! ( cd "$CP_GUARDA" && apt-get source --download-only "cosmic-comp=$ver" ) >"$log" 2>&1; then
      meow_erro "o apt-get source falhou para o cosmic-comp $ver"
      if grep -q ' 404 ' "$log" 2>/dev/null; then
        meow_info "  o repositório já não serve o fonte desta versão (404)"
        meow_info "  o caminho é atualizar o cosmic-comp — o apt traz binário e fonte da mesma versão — e validar a série nela"
      else
        meow_info "  o deb-src está habilitado nas fontes do apt? o registro está em $log"
      fi
      return "$MEOW_ERRO"
    fi
  fi
  rm -rf "$dir"
  if ! dpkg-source -x "$dsc" "$dir" >>"$log" 2>&1 || [ ! -f "$dir/Cargo.toml" ]; then
    meow_erro "o fonte não se extraiu em $dir (registro: $log)"
    return "$MEOW_ERRO"
  fi
  meow_ok "fonte do cosmic-comp $ver em $dir"
  return "$MEOW_OK"
}

_cp_serie_entradas() {
  local serie="$1"
  local -a campos=()
  while read -r -a campos || [ "${#campos[@]}" -gt 0 ]; do
    [ "${#campos[@]}" -ge 3 ] || continue
    case "${campos[0]}" in req|opt) : ;; *) continue ;; esac
    printf '%s\t%s\t%s\n' "${campos[0]}" "${campos[1]}" "${campos[2]}"
  done < "$serie"
}

_cp_tem_marcador_da_serie() {
  local bin="$1" serie="$2" _c _a base
  while IFS=$'\t' read -r _c _a base; do
    [ -n "$(_cp_marcadores "$bin" "$base")" ] && return 0
  done < <(_cp_serie_entradas "$serie")
  return 1
}

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

_cp_gravar_matriz() {
  local ver="$1" linha tmp
  [ "${#_CP_DEGRAUS[@]}" -gt 0 ] || return 0
  linha="$ver"$'\t'"$(date +%F)"$'\t'"${_CP_DEGRAUS[*]}"
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
  if _cp_versao_valida "$ver"; then
    meow_ok "esta versão já passou pela série (patches/versao ou a matriz)"
  else
    meow_info "versão nova para a série: a escada decide patch a patch e grava em $CP_MATRIZ"
  fi

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
  if _cp_arvore_velha "$fonte" "$serie"; then
    meow_info "o fonte do cache tem a versão anterior de um patch da série: reextraindo"
    rm -rf -- "$fonte"
    _cp_baixar_fonte "$ver" || return $?
  fi
  _cp_receita "$fonte"
  faltam=()
  for i in "${_CP_PEDE[@]}"; do meow_tem "$i" || faltam+=("$i"); done
  if [ "${#faltam[@]}" -gt 0 ]; then
    meow_erro "falta para compilar este fonte ($_CP_RECEITA_NOME): ${faltam[*]}"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local novo_alvos="$CP_ALVOS.novo" _c a b alvo
  rm -rf "$novo_alvos"
  while IFS=$'\t' read -r _c a b; do
    while IFS= read -r alvo; do
      [ -f "$fonte/$alvo" ] || continue
      grep -q -- "$b" "$fonte/$alvo" 2>/dev/null && continue
      mkdir -p "$novo_alvos/${alvo%/*}" && cp -f "$fonte/$alvo" "$novo_alvos/$alvo"
    done < <(_cp_alvos_do_patch "$CP_REPO/$a")
  done < <(_cp_serie_entradas "$serie")

  local rc_ap=0
  _CP_COMPILANDO=1 cmd_aplicar "$fonte" || rc_ap=$?
  [ "$rc_ap" = "0" ] || { _cp_gravar_matriz "$ver"; return "$rc_ap"; }

  meow_info "compilando com $_CP_RECEITA_NOME, Nice 19 (~4 min com o vendor quente, ~30 min do zero)"
  meow_info "  o registro vai para $log"
  if ! ( cd "$fonte" && nice -n 19 "${_CP_RECEITA[@]}" ) >"$log" 2>&1; then
    meow_erro "a compilação falhou — nada foi instalado, o compositor de agora continua"
    tail -n 15 "$log" 2>/dev/null | sed 's/^/        /' >&2
    return "$MEOW_ERRO"
  fi
  [ -f "$bin" ] || { meow_erro "o make terminou e o binário não apareceu em $bin"; return "$MEOW_ERRO"; }

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

  local destino="$CP_CASA/$ver" tmp_bin tmp_estado
  if cmp -s "$bin" "$destino/cosmic-comp" && [ -f "$destino/estado" ] && [ ! -e "$destino/ruim" ]; then
    meow_ok "o binário compilado é o que já está em $destino — nada a instalar"
    return "$MEOW_OK"
  fi
  mkdir -p "$destino" || { meow_erro "não consegui criar $destino"; return "$MEOW_ERRO"; }
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
  rm -f "$destino/ruim" "$destino/quedas"
  meow_muda "cosmic-comp patchado guardado em $destino (versão $ver), estado medido no binário"
  _cp_gravar_matriz "$ver"
  if [ -d "$novo_alvos" ]; then
    rm -rf "$CP_ALVOS" && mv -f "$novo_alvos" "$CP_ALVOS" && printf '%s\n' "$ver" > "$CP_ALVOS/.versao"
  fi
  _cp_shim_ativo || meow_info "o shim está desligado: o build fica guardado, sem efeito na sessão"

  local d
  for d in "$CP_CACHE"/cosmic-comp-*; do
    [ -d "$d" ] || continue
    [ "$d" = "$fonte" ] && continue
    [ -f "$d/Cargo.toml" ] || continue
    rm -rf -- "$d" && meow_info "podei o fonte antigo: ${d##*/}"
  done

  meow_registrar "compositor_patches.sh compilar $ver"
  meow_info "vale no PRÓXIMO LOGIN — a sessão de agora segura o binário antigo até lá"
  return "$MEOW_OK"
}

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
  if MEOW_SECO=1 cmd_aplicar "$fonte"; then
    _cp_versao_valida "$ver" && return "$MEOW_OK"
    meow_ok "a série entra no cosmic-comp $ver (os degraus estão acima)"
    meow_info "o meow compositor compila nela sem pedir commit: a escada decide e grava a matriz"
    return "$MEOW_OK"
  fi
  meow_info "o cosmic-comp $ver não tem build enquanto o obrigatório recusar: é o degrau 4, um rebase do patch"
  return "$MEOW_ERRO"
}

cmd_ativar() {
  [ -r "$CP_SHIM_FONTE" ] || { meow_erro "falta $CP_SHIM_FONTE — repositório incompleto"; return "$MEOW_ERRO"; }
  if cmp -s "$CP_SHIM_FONTE" "$CP_SHIM"; then
    meow_ok "o shim do compositor já está em $CP_SHIM"
    return "$MEOW_OK"
  fi
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
    meow_info "o compositor patchado entra pelo shim em $CP_SHIM; desligar o shim devolve o do pacote"
    meow_info "  sem o shim, o próximo login usa $CP_BIN, o do pacote"
  fi
  meow_info "o caminho de volta é reinstalar o PACOTE cosmic-comp pelo gerenciador de pacotes"
  meow_info "  ele devolve $CP_BIN ao binário de fábrica, sem nenhum patch da série"
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

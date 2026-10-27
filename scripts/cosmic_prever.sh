#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

CV_CONTRATO="${CV_CONTRATO:-$MEOW_RAIZ/assets/contratos/cosmic.tsv}"
CV_SERIE="${CV_SERIE:-$MEOW_RAIZ/patches/series}"
CV_PATCHES="${CV_PATCHES:-$MEOW_RAIZ/patches}"
CV_SAIDA="${CV_SAIDA:-$MEOW_ESTADO/cosmic-candidato.tsv}"
CV_GUARDA="${CV_GUARDA:-${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/fontes}"
CV_TRABALHO="${CV_TRABALHO:-${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem/cosmic-prever}"
CV_SISTEMA="${CV_SISTEMA:-/usr/share/cosmic}"
CV_REDE="${CV_REDE:-sim}"
CV_DEBS=""
CV_FONTES=""

declare -a _CV_LINHAS=()
_cv_dizer() { _CV_LINHAS+=("$1"$'\t'"$2"$'\t'"$3"); }

_cv_candidatos() {
  local d p v
  if [ -n "$CV_DEBS" ]; then
    for d in "$CV_DEBS"/*.deb; do
      [ -f "$d" ] || continue
      p="$(dpkg-deb -f "$d" Package 2>/dev/null)"; v="$(dpkg-deb -f "$d" Version 2>/dev/null)"
      case "$p" in cosmic-*) printf '%s\t%s\t%s\n' "$p" "$v" "$d" ;; esac
    done
    return 0
  fi
  local dir="$CV_TRABALHO/debs"
  mkdir -p "$dir" || return 1
  apt list --upgradable 2>/dev/null | sed -n 's#^\(cosmic-[^/]*\)/[^ ]* \([^ ]*\) .*#\1\t\2#p' |
  while IFS=$'\t' read -r p v; do
    d="$(ls "$dir/${p}_"*.deb 2>/dev/null | head -1)"
    if [ -z "$d" ] || [ "$(dpkg-deb -f "$d" Version 2>/dev/null)" != "$v" ]; then
      rm -f "$dir/${p}_"*.deb
      ( cd "$dir" && apt-get download "$p=$v" ) >/dev/null 2>&1 || continue
      d="$(ls "$dir/${p}_"*.deb 2>/dev/null | head -1)"
    fi
    [ -n "$d" ] && printf '%s\t%s\t%s\n' "$p" "$v" "$d"
  done
}

_cv_extraido() {
  local x="$CV_TRABALHO/x/$1"
  if [ "$(cat "$x/.versao" 2>/dev/null)" != "$2" ]; then
    rm -rf "$x"; mkdir -p "$x" && dpkg-deb -x "$3" "$x" 2>/dev/null && printf '%s' "$2" > "$x/.versao" || return 1
  fi
  printf '%s' "$x"
}

_cv_maior_v() { ls -1 "$1" 2>/dev/null | sed -n 's/^v\([0-9][0-9]*\)$/\1/p' | sort -n | tail -1; }

_cv_esquema() {
  local ns n_cand n_hoje iguais=0
  for ns in "$1"/usr/share/cosmic/*/; do
    [ -d "$ns" ] || continue
    ns="${ns%/}"; ns="${ns##*/}"
    n_cand="$(_cv_maior_v "$1/usr/share/cosmic/$ns")"
    n_hoje="$(_cv_maior_v "$CV_SISTEMA/$ns")"
    [ -n "$n_cand" ] || continue
    if [ "$n_cand" = "$n_hoje" ]; then iguais=$((iguais+1)); continue; fi
    _cv_dizer esquema amarelo "$2: $ns passa de v${n_hoje:-?} para v$n_cand — os escritores seguem o maior v do pacote"
  done
  [ "$iguais" -gt 0 ] && _cv_dizer esquema verde "$2: $iguais namespace(s) com o mesmo v* de hoje"
  return 0
}

_cv_chaves() {
  local tipo ns chave bin quem n bin_arq
  while IFS=$'\t' read -r tipo ns chave bin quem; do
    [ "$tipo" = "chave" ] && [ "$bin" = "$2" ] || continue
    bin_arq="$1/usr/bin/$bin"
    [ -f "$bin_arq" ] || { _cv_dizer chave amarelo "$bin não está no .deb candidato — $chave não medida"; continue; }
    n="$(grep -a -c -- "$chave" "$bin_arq" 2>/dev/null)"
    if [ "${n:-0}" -gt 0 ]; then
      _cv_dizer chave verde "$ns/$chave presente no $bin candidato"
    elif [ "${quem#patch:}" != "$quem" ]; then
      _cv_dizer chave verde "$ns/$chave ausente no $bin de fábrica, como esperado: vem de ${quem#patch:}"
    else
      _cv_dizer chave vermelho "$ns/$chave SUMIU do $bin candidato — $quem grava o que ninguém lê"
    fi
  done < <(grep -v '^#' "$CV_CONTRATO" 2>/dev/null)
}

_cv_fonte() {
  local tar="" arvore="$CV_TRABALHO/src/$1-$2" origem
  if [ -f "$arvore/.pronto" ]; then printf '%s' "$(cat "$arvore/.pronto")"; return 0; fi
  for origem in "$CV_FONTES" "$CV_GUARDA/$1"; do
    [ -n "$origem" ] || continue
    tar="$(ls "$origem/${1}_${2}.tar."* 2>/dev/null | head -1)"
    [ -n "$tar" ] && break
  done
  if [ -z "$tar" ] && [ -z "$CV_FONTES" ]; then
    mkdir -p "$CV_GUARDA/$1" || return 1
    ( cd "$CV_GUARDA/$1" && apt-get source --download-only "$1=$2" ) >/dev/null 2>&1 || return 1
    tar="$(ls "$CV_GUARDA/$1/${1}_${2}.tar."* 2>/dev/null | head -1)"
  fi
  [ -n "$tar" ] || return 1
  rm -rf "$arvore"; mkdir -p "$arvore" || return 1
  tar -xf "$tar" -C "$arvore" --exclude='*/vendor.tar' --exclude='*/vendor/*' 2>/dev/null || return 1
  local raiz; raiz="$(dirname "$(find "$arvore" -maxdepth 2 -name Cargo.toml | head -1)")"
  [ -f "$raiz/Cargo.toml" ] || return 1
  printf '%s' "$raiz" > "$arvore/.pronto"
  printf '%s' "$raiz"
}

_cv_alvos() { sed -n 's|^+++ [ab]/\([^[:space:]]*\).*|\1|p' "$1" 2>/dev/null | sort -u; }

_cv_serie_comp() {
  local copia="$CV_TRABALHO/serie-cosmic-comp" classe arq base p degrau
  rm -rf "$copia"; mkdir -p "$copia" || return 1
  cp -a "$1"/. "$copia"/ 2>/dev/null || return 1
  while read -r classe arq base; do
    case "$classe" in req|opt) ;; *) continue ;; esac
    p="$CV_PATCHES/$arq"
    if (cd "$copia" && patch -p1 -F0 --forward --dry-run --silent < "$p") >/dev/null 2>&1; then
      degrau=F0
    elif (cd "$copia" && patch -p1 -F1 --forward --dry-run --silent < "$p") >/dev/null 2>&1; then
      degrau=F1
    else
      degrau=""
    fi
    if [ -n "$degrau" ]; then
      (cd "$copia" && patch -p1 "-$degrau" --forward --no-backup-if-mismatch --silent < "$p") >/dev/null 2>&1
      if [ "$degrau" = "F0" ]; then
        _cv_dizer série verde "$arq entra limpo (-F0)"
      else
        _cv_dizer série amarelo "$arq só entra com -F1: o contexto mudou upstream, entra sob a guarda de queda"
      fi
    elif [ "$classe" = "req" ]; then
      _cv_dizer série vermelho "$arq é OBRIGATÓRIO e não entra nem com -F1 — sem build, a sessão sobe de fábrica"
    else
      _cv_dizer série amarelo "$arq não entra nem com -F1 — o build sai sem ele, e só a função dele volta à fábrica"
    fi
  done < <(grep -v '^[[:space:]]*#' "$CV_SERIE")
}

_cv_serie_files() {
  local p alvo copia="$CV_TRABALHO/serie-cosmic-files"
  for p in "$CV_PATCHES"/cosmic-files-wallpaper-menu*.patch; do
    [ -f "$p" ] || continue
    rm -rf "$copia"; mkdir -p "$copia"
    while IFS= read -r alvo; do
      [ -f "$1/$alvo" ] && { mkdir -p "$copia/${alvo%/*}"; cp -a "$1/$alvo" "$copia/$alvo"; }
    done < <(_cv_alvos "$p")
    if (cd "$copia" && patch -p1 -F0 --forward --dry-run --silent < "$p") >/dev/null 2>&1; then
      _cv_dizer série verde "${p##*/} entra limpo (-F0) no cosmic-files candidato"
      return 0
    fi
  done
  _cv_dizer série vermelho "nenhum patch do menu de papel de parede entra no cosmic-files candidato — o menu fica de fábrica até um rebase"
}

_cv_num() { local a b c; IFS=. read -r a b c <<<"$1"; printf '%d' "$(( ${a:-0}*1000000 + ${b:-0}*1000 + ${c:-0} ))"; }

_cv_toolchain() {
  local rv rc
  rv="$(sed -n 's/^rust-version[[:space:]]*=[[:space:]]*"\([0-9.]*\)".*/\1/p' "$1/Cargo.toml" | head -1)"
  [ -n "$rv" ] || { _cv_dizer toolchain verde "$2: o Cargo.toml não pede rust-version"; return 0; }
  rc="$(cd "$1" && RUSTUP_AUTO_INSTALL=0 rustc --version 2>/dev/null | awk '{print $2}')"
  if [ -z "$rc" ]; then
    _cv_dizer toolchain amarelo "$2 pede rust $rv e o toolchain que o fonte escolhe não está instalado — o build o baixa"
    return 0
  fi
  local nrv nrc; nrv="$(_cv_num "$rv")"; nrc="$(_cv_num "$rc")"
  local mm_rv="${rv%.*}" mm_rc; mm_rc="$(printf '%s' "$rc" | cut -d. -f1-2)"
  [ "${rv//[^.]/}" = "." ] && mm_rv="$rv"
  if [ "$nrc" -lt "$nrv" ]; then
    _cv_dizer toolchain vermelho "$2 pede rust $rv e o rustc é $rc — o pós-apt atualiza o rustup antes do build"
  elif [ "$mm_rc" = "$mm_rv" ]; then
    _cv_dizer toolchain amarelo "$2 pede rust $rv e o rustc é $rc: no limite, o próximo degrau derruba o build"
  else
    _cv_dizer toolchain verde "$2 pede rust $rv e o rustc é $rc"
  fi
}

_cv_tem() {
  case " ${CV_SEM:-} " in *" $1 "*) return 1 ;; esac
  meow_tem "$1"
}

_cv_ferramenta() {
  local pede faltam=() f
  if grep -qsE '^build-vendored([ :]|$)' "$1/justfile" "$1"/*.just; then pede="just cargo"
  elif [ -f "$1/Makefile" ]; then pede="make cargo"
  else pede="tar cargo"; fi
  for f in $pede; do _cv_tem "$f" || faltam+=("$f"); done
  if [ "${#faltam[@]}" -gt 0 ]; then
    _cv_dizer ferramenta vermelho "$2: o build pede ${pede// /, } e falta ${faltam[*]} nesta máquina"
  else
    _cv_dizer ferramenta verde "$2: o build pede ${pede// /, }, e estão instalados"
  fi
}

cv_libcosmic_de() {
  local rev
  [ "$CV_REDE" = "sim" ] || return 1
  rev="$(meow_libcosmic_de "$1" "$2")" || return 1
  printf '%s' "${rev:0:7}"
}

_cv_tema() {
  local rev tipo arq hash ref quem atual difere=0 iguais=0
  rev="$(cv_libcosmic_de cosmic-settings "$1")"
  if [ -z "$rev" ]; then
    _cv_dizer tema amarelo "a revisão do libcosmic do cosmic-settings $1 não foi medida (sem rede ou sem Cargo.lock)"
    return 0
  fi
  while IFS=$'\t' read -r tipo arq hash ref quem; do
    [ "$tipo" = "tema" ] || continue
    atual="$(curl -sfL --max-time 20 "https://raw.githubusercontent.com/pop-os/libcosmic/$rev/$arq" 2>/dev/null | sha256sum | cut -d' ' -f1)"
    if [ "$atual" = "$hash" ]; then
      iguais=$((iguais+1))
    else
      difere=$((difere+1))
      _cv_dizer tema amarelo "${arq##*/} mudou entre $ref e $rev — a cópia em Python deixa de ser a derivação daquela versão; o oráculo refaz"
    fi
  done < <(grep -v '^#' "$CV_CONTRATO")
  [ "$difere" = "0" ] && _cv_dizer tema verde "o cosmic-settings $1 pina o libcosmic $rev, e os $iguais arquivos da derivação são os de ${ref:-referência}"
  return 0
}

_cv_revisao() {
  local tipo alvo rev assunto quem atual="${2##*~}"
  while IFS=$'\t' read -r tipo alvo rev assunto quem; do
    [ "$tipo" = "revisao" ] && [ "$alvo" = "$1" ] || continue
    if [ "$atual" = "$rev" ]; then
      _cv_dizer revisao verde "$1 $3 é o $atual, o mesmo que $quem mediu ($assunto)"
    else
      _cv_dizer revisao amarelo "$1 $3 é o $atual; $quem foi medido no $rev ($assunto) — confira o comentário"
    fi
  done < <(grep -v '^#' "$CV_CONTRATO")
}

CV_MAPAS=("$MEOW_RAIZ"/packs/*/icones/*.map "$MEOW_RAIZ"/assets/icones/*.map)

_cv_tem_arte() {
  local nome="$1"
  grep -qhE "^${nome//./\\.}([: 	]|$)" "${CV_MAPAS[@]}" 2>/dev/null
}

_cv_desktops() {
  local raiz="$1" d i; shift
  for d in "$@"; do
    [ -f "$raiz$d" ] || continue
    grep -qi '^NoDisplay=true' "$raiz$d" && continue
    i="$(sed -n 's/^Icon=//p' "$raiz$d" | head -1)"
    printf '%s\t%s\n' "${d##*/}" "$i"
  done
}

_cv_icones_candidato() {
  local -a novos=() velhos=()
  mapfile -t novos < <(cd "$1" && find usr/share/applications -maxdepth 1 -name '*.desktop' 2>/dev/null | sed 's|^|/|' | sort)
  mapfile -t velhos < <(dpkg -L "$2" 2>/dev/null | grep '^/usr/share/applications/[^/]*\.desktop$' | sort)
  local d i entrou saiu
  entrou="$(comm -13 <(printf '%s\n' "${velhos[@]##*/}" | sort) <(printf '%s\n' "${novos[@]##*/}" | sort) | sed '/^$/d')"
  saiu="$(comm -23 <(printf '%s\n' "${velhos[@]##*/}" | sort) <(printf '%s\n' "${novos[@]##*/}" | sort) | sed '/^$/d')"
  [ -n "$saiu" ] && _cv_dizer icones amarelo "$2: saem $(printf '%s' "$saiu" | tr '\n' ' ')— o desenho deles fica no mapa, sem uso"
  while IFS=$'\t' read -r d i; do
    printf '%s\n' "$entrou" | grep -qxF "$d" || continue
    if _cv_tem_arte "$i"; then
      _cv_dizer icones verde "$2: entra $d, e o mapa já tem desenho para $i"
    else
      _cv_dizer icones amarelo "$2: entra $d sem desenho em mapa nenhum ($i) — vale o do tema herdado"
    fi
  done < <(_cv_desktops "$1" "${novos[@]}")
  return 0
}

_cv_sem_desenho() {
  local d i
  local -a todos=()
  mapfile -t todos < <(dpkg -L $(dpkg-query -W -f='${Package}\n' 'cosmic-*' 2>/dev/null) 2>/dev/null |
                       grep '^/usr/share/applications/[^/]*\.desktop$' | sort -u)
  while IFS=$'\t' read -r d i; do
    [ -n "$i" ] || continue
    _cv_tem_arte "$i" && continue
    printf '%s\t%s\n' "$i" "$d"
  done < <(_cv_desktops "${CV_RAIZ_APPS:-}" "${todos[@]}")
}

cmd_icones() {
  local d i n=0
  while IFS=$'\t' read -r i d; do
    n=$((n+1))
    meow_aviso "sem desenho: $i ($d)"
  done < <(_cv_sem_desenho)
  [ "$n" = "0" ] && meow_ok "todo app visível do COSMIC instalado tem desenho num mapa"
  return "$MEOW_OK"
}

cmd_prever() {
  local p v d x arvore n=0
  meow_tem dpkg-deb || { meow_pula "sem dpkg-deb nesta máquina — nada a prever"; return "$MEOW_SEM_DEPENDENCIA"; }
  [ -r "$CV_CONTRATO" ] || { meow_erro "falta $CV_CONTRATO"; return "$MEOW_ERRO"; }
  while IFS=$'\t' read -r p v d; do
    n=$((n+1))
    x="$(_cv_extraido "$p" "$v" "$d")" || { _cv_dizer "$p" amarelo "não consegui abrir o .deb candidato ($v)"; continue; }
    _cv_esquema "$x" "$p"
    _cv_chaves "$x" "$p"
    _cv_icones_candidato "$x" "$p"
    _cv_revisao "$p" "$v" candidato
    case "$p" in
      cosmic-comp|cosmic-files)
        if arvore="$(_cv_fonte "$p" "$v")"; then
          if [ "$p" = cosmic-comp ]; then _cv_serie_comp "$arvore"; else _cv_serie_files "$arvore"; fi
          _cv_toolchain "$arvore" "$p"
          [ "$p" = cosmic-comp ] && _cv_ferramenta "$arvore" "$p"
        else
          _cv_dizer série amarelo "o fonte do $p $v não foi baixado — série e toolchain não medidas"
        fi ;;
      cosmic-settings) _cv_tema "$v" ;;
    esac
  done < <(_cv_candidatos)
  [ "$n" -gt 0 ] || _cv_dizer cosmic verde "nenhum pacote do COSMIC na fila do apt"
  local alvo_r
  for alvo_r in $(awk -F'\t' '$1=="revisao" {print $2}' "$CV_CONTRATO" | sort -u); do
    v="$(dpkg-query -W -f='${Version}' "$alvo_r" 2>/dev/null)" && [ -n "$v" ] && _cv_revisao "$alvo_r" "$v" instalado
  done

  local tmp; mkdir -p "${CV_SAIDA%/*}" && tmp="$(mktemp -p "${CV_SAIDA%/*}" .candidato.XXXXXX)" || return "$MEOW_ERRO"
  { printf '# gravado por meow cosmic prever em %s — NAO EDITAR A MAO\n' "$(date -Is)"
    printf '%s\n' "${_CV_LINHAS[@]}"; } > "$tmp" && mv -f "$tmp" "$CV_SAIDA"
  cmd_ler
}

cmd_ler() {
  [ -r "$CV_SAIDA" ] || { meow_pula "ainda não há veredito (meow cosmic prever)"; return "$MEOW_OK"; }
  local item ver det vermelho=0
  while IFS=$'\t' read -r item ver det; do
    case "$item" in \#*|"") continue ;; esac
    case "$ver" in
      verde)    meow_ok    "$item: $det" ;;
      amarelo)  meow_aviso "$item: $det" ;;
      vermelho) meow_muda  "$item: $det"; vermelho=1 ;;
    esac
  done < "$CV_SAIDA"
  [ "$vermelho" = "1" ] && return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}

acao="prever"
while [ $# -gt 0 ]; do
  case "$1" in
    --debs)     CV_DEBS="$2"; shift ;;
    --fontes)   CV_FONTES="$2"; shift ;;
    --sem-rede) CV_REDE="nao" ;;
    prever|ler|icones|icones-lista) acao="$1" ;;
    *) meow_erro "uso: cosmic_prever.sh [prever|ler|icones|icones-lista] [--debs DIR] [--fontes DIR] [--sem-rede]"; exit "$MEOW_ERRO" ;;
  esac
  shift
done
case "$acao" in
  prever) cmd_prever ;;
  ler)    cmd_ler ;;
  icones) cmd_icones ;;
  icones-lista) _cv_sem_desenho | cut -f1 ;;
esac

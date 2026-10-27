#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

OT_MOLDE="$MEOW_RAIZ/src/oraculo-tema"
OT_CASA="${OT_CASA:-$HOME/.local/libexec/meow/oraculo-tema}"
OT_TRABALHO="${OT_TRABALHO:-${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem/oraculo-tema}"
OT_CONTRATO="${OT_CONTRATO:-$MEOW_RAIZ/assets/contratos/cosmic.tsv}"

_ot_revisao() {
  local v
  v="$(dpkg-query -W -f='${Version}' cosmic-settings 2>/dev/null)" || return 1
  [ -n "$v" ] || return 1
  meow_libcosmic_de cosmic-settings "$v"
}

_ot_mesma_derivacao() {
  local tipo arq hash ref quem atual
  while IFS=$'\t' read -r tipo arq hash ref quem; do
    [ "$tipo" = "tema" ] || continue
    atual="$(curl -sfL --max-time 20 "https://raw.githubusercontent.com/pop-os/libcosmic/$1/$arq" 2>/dev/null | sha256sum | cut -d' ' -f1)"
    [ "$atual" = "$hash" ] || return 1
  done < <(grep -v '^#' "$OT_CONTRATO")
  return 0
}

_ot_binario() { printf '%s/%s/meow-oraculo-tema' "$OT_CASA" "$1"; }

cmd_revisao() {
  local rev; rev="$(_ot_revisao)" || { meow_pula "a revisão do libcosmic do cosmic-settings instalado não foi medida (sem rede?)"; return "$MEOW_SEM_DEPENDENCIA"; }
  printf '%s\n' "$rev"
}

cmd_construir() {
  local rev bin trabalho log
  rev="$(_ot_revisao)" || { meow_pula "sem a revisão do libcosmic instalado (sem rede?) — fica a cópia em Python"; return "$MEOW_SEM_DEPENDENCIA"; }
  bin="$(_ot_binario "$rev")"
  if [ -x "$bin" ]; then
    meow_ok "o oráculo do libcosmic ${rev:0:7} já existe"
    return "$MEOW_OK"
  fi
  if _ot_mesma_derivacao "$rev"; then
    meow_ok "o libcosmic ${rev:0:7} deriva o tema como a cópia em Python — nada a compilar"
    return "$MEOW_OK"
  fi
  meow_tem cargo || { meow_pula "a derivação mudou no libcosmic ${rev:0:7} e não há cargo — fica a cópia em Python"; return "$MEOW_SEM_DEPENDENCIA"; }
  if meow_seco; then
    meow_muda "compilaria o oráculo do tema contra o libcosmic ${rev:0:7}"
    return "$MEOW_DIVERGENTE"
  fi
  trabalho="$OT_TRABALHO/$rev"; log="$OT_TRABALHO/compilar-$rev.log"
  rm -rf "$trabalho"; mkdir -p "$trabalho" "${bin%/*}" || return "$MEOW_ERRO"
  cp -a "$OT_MOLDE"/. "$trabalho"/ && sed -i "s/@REV@/$rev/g" "$trabalho/Cargo.toml" || return "$MEOW_ERRO"
  meow_info "compilando o oráculo do tema contra o libcosmic ${rev:0:7} (Nice 19; o registro vai para $log)"
  if ! ( cd "$trabalho" && nice -n 19 cargo build --release ) >"$log" 2>&1; then
    meow_erro "o oráculo não compilou — fica a cópia em Python (registro: $log)"
    return "$MEOW_ERRO"
  fi
  local tmp; tmp="$(mktemp -p "${bin%/*}" .oraculo.XXXXXX)" || return "$MEOW_ERRO"
  cp -f "$trabalho/target/release/meow-oraculo-tema" "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$bin" \
    || { rm -f "$tmp"; meow_erro "não consegui guardar $bin"; return "$MEOW_ERRO"; }
  meow_muda "oráculo do tema do libcosmic ${rev:0:7} em $bin"
  return "$MEOW_DIVERGENTE"
}

cmd_caminho() {
  local rev bin
  rev="$(_ot_revisao)" || return 1
  bin="$(_ot_binario "$rev")"
  [ -x "$bin" ] || return 1
  printf '%s\n' "$bin"
}

cmd_conferir() {
  local rev bin cap arvore l tmp saida rc=0 n=0
  rev="$(_ot_revisao)" || { meow_pula "sem a revisão do libcosmic instalado (sem rede?) — nada a conferir"; return "$MEOW_SEM_DEPENDENCIA"; }
  bin="$(_ot_binario "$rev")"
  if [ ! -x "$bin" ]; then
    if _ot_mesma_derivacao "$rev"; then
      meow_ok "o libcosmic ${rev:0:7} deriva como a cópia em Python (os três arquivos do contrato são iguais)"
      return "$MEOW_OK"
    fi
    meow_aviso "a derivação mudou no libcosmic ${rev:0:7} e o oráculo dele não foi compilado: oraculo_tema.sh construir"
    return "$MEOW_OK"
  fi
  local -a caps=("$@")
  [ "${#caps[@]}" -gt 0 ] || mapfile -t caps < <(ls -d "$MEOW_RAIZ"/packs/*/temas/capturados/*/ 2>/dev/null)
  tmp="$(mktemp -d)" || return "$MEOW_ERRO"
  for cap in "${caps[@]}"; do
    cap="${cap%/}"
    for arvore in Dark Light; do
      [ -d "$cap/com.system76.CosmicTheme.$arvore.Builder" ] || continue
      l="$(printf '%s' "$arvore" | tr 'A-Z' 'a-z')"
      rm -rf "$tmp/cosmic"; mkdir -p "$tmp/cosmic"
      cp -a "$cap/com.system76.CosmicTheme.$arvore.Builder" "$tmp/cosmic/"
      "$bin" "$l" "$tmp/cosmic" > "$tmp/tema.json" 2>/dev/null || { meow_aviso "${cap##*/} $arvore: o oráculo falhou"; continue; }
      n=$((n+1))
      if saida="$(python3 "$MEOW_RAIZ/scripts/oraculo_tema.py" comparar "$cap" "$arvore" "$tmp/tema.json")"; then
        meow_ok "${cap##*/} $arvore: o oráculo e a cópia em Python dão o mesmo tema"
      else
        rc=1
        meow_aviso "${cap##*/} $arvore: o libcosmic ${rev:0:7} deriva diferente da cópia em Python"
        printf '%s\n' "$saida" | sed 's/^/        /'
      fi
    done
  done
  rm -rf "$tmp"
  [ "$n" -gt 0 ] || meow_pula "nenhuma captura com receita para conferir"
  [ "$rc" = "0" ] || meow_info "a cópia em Python é a derivação da c003a58; quem refaz o produto da revisão nova é o oráculo"
  return "$MEOW_OK"
}

case "${1:-conferir}" in
  revisao)   cmd_revisao ;;
  construir) cmd_construir ;;
  conferir)  shift; cmd_conferir "$@" ;;
  caminho)   cmd_caminho ;;
  *) meow_erro "uso: oraculo_tema.sh {revisao|construir|conferir [captura…]|caminho}"; exit "$MEOW_ERRO" ;;
esac

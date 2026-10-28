#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

conferir() {
  local r="$1" etapas pasta slug alvo cartao tipo nome _rot etapa chave achou erros=0
  etapas=" $(awk '/local etapas=\(/ { dentro = 1 } dentro { print } dentro && /\)/ { exit }' "$r/install.sh" \
    | sed 's/local etapas=(//; s/)//' | tr -s ' \n' '  ') "
  queixa() { printf 'cartão sem install: %s\n' "$1"; erros=$((erros + 1)); }
  na_lista() { case "$etapas" in *" etapa_$1 "*) return 0 ;; esac; return 1; }
  definida() { grep -q "^etapa_$1()" "$r/install.sh"; }

  if ! na_lista apps || ! definida apps; then
    queixa "a etapa_apps não roda no install"
  elif ! sed -n '/^etapa_apps()/,/^}/p' "$r/install.sh" | grep -q 'aplicar_apps.sh" aplicar'; then
    queixa "a etapa_apps não chama o aplicar_apps.sh aplicar"
  fi

  eval "$(sed -n '/^pasta_de()/,/^}/p' "$r/scripts/aplicar_apps.sh")"
  local padrao alcancadas=" "
  padrao="$(sed -n 's/^APPS_ATIVOS="\([^"]*\)".*/\1/p' "$r/meow.conf.exemplo" | head -n 1)"
  IFS=',' read -ra _slugs <<< "${padrao// /}"
  for slug in "${_slugs[@]}"; do alcancadas+="$(pasta_de "$slug") "; done
  for alvo in "$r"/scripts/temas-de-apps/*/manifesto.sh; do
    [ -f "$alvo" ] || continue
    pasta="${alvo%/manifesto.sh}"; pasta="${pasta##*/}"
    case "$alcancadas" in *" $pasta "*) ;; *) queixa "o módulo $pasta não entra pelo APPS_ATIVOS de fábrica" ;; esac
  done

  while IFS=$'\t' read -r cartao tipo nome _rot etapa chave; do
    [ "$tipo" = "correcao" ] || continue
    if [ -z "${etapa:-}" ]; then queixa "a correção $nome ($cartao) não diz a etapa"; continue; fi
    na_lista "$etapa" && definida "$etapa" || { queixa "a correção $nome aponta a etapa_$etapa, que o install não roda"; continue; }
    if [ -z "${chave:-}" ]; then queixa "a correção $nome não diz a chave do interruptor"; continue; fi
    grep -q "^$chave=" "$r/meow.conf.exemplo" || { queixa "a chave $chave da correção $nome não está no meow.conf.exemplo"; continue; }
    achou="$(awk -F'\t' -v c="$chave" '$1 == c { print $2 }' "$r/assets/contratos/chave-etapa.tsv")"
    case ",$achou," in *",$etapa,"*) ;; *) queixa "a chave $chave não leva à etapa_$etapa no chave-etapa.tsv" ;; esac
  done < "$r/assets/contratos/modificacoes.tsv"
  return "$erros"
}

falhou=0
saida="$(conferir "$RAIZ")" || { printf 'FALHOU: %s\n' "$saida"; falhou=1; }

T="$(mktemp -d -p "${TMPDIR:-/tmp}" meow-mod-install.XXXXXX)" || exit 2
trap 'rm -rf "$T"' EXIT

copia() {
  rm -rf "$T/r"
  mkdir -p "$T/r/scripts" "$T/r/assets/contratos"
  cp "$RAIZ/install.sh" "$RAIZ/meow.conf.exemplo" "$T/r/"
  cp "$RAIZ/scripts/aplicar_apps.sh" "$T/r/scripts/"
  cp -r "$RAIZ/scripts/temas-de-apps" "$T/r/scripts/"
  cp "$RAIZ/assets/contratos/modificacoes.tsv" "$RAIZ/assets/contratos/chave-etapa.tsv" "$T/r/assets/contratos/"
}

vermelho() {
  local frase="$1" saida
  if saida="$(conferir "$T/r")"; then
    printf 'FALHOU: %s e o teste continuou verde\n' "$frase"; falhou=1
  else
    printf 'ok: %s acende vermelho (%s)\n' "$frase" "$(printf '%s' "$saida" | head -n 1)"
  fi
}

copia; sed -i '/local etapas=(/,/)/ s/ etapa_prompt / /' "$T/r/install.sh"
vermelho "tirar a etapa_prompt da lista do install"
copia; sed -i '/^etapa_flatpak_tema()/,/^}/d' "$T/r/install.sh"
vermelho "apagar a etapa_flatpak_tema"
copia; sed -i '/local etapas=(/,/)/ s/ etapa_apps$//; /local etapas=(/,/)/ s/ etapa_apps / /' "$T/r/install.sh"
vermelho "tirar a etapa_apps da lista do install"
copia; mkdir -p "$T/r/scripts/temas-de-apps/novo" && : > "$T/r/scripts/temas-de-apps/novo/manifesto.sh"
vermelho "um módulo novo fora do APPS_ATIVOS de fábrica"
copia; printf 'novo\tcorrecao\tnova\tCorreção nova\n' >> "$T/r/assets/contratos/modificacoes.tsv"
vermelho "uma correção sem etapa"
copia; sed -i 's/^PROMPT_STARSHIP\tprompt\t/PROMPT_STARSHIP\tterminal\t/' "$T/r/assets/contratos/chave-etapa.tsv"
vermelho "a chave do interruptor sem a etapa da correção"

[ "$falhou" = 0 ] && printf 'ok: todo cartão da Modificações tem etapa no install\n'
exit "$falhou"

#!/usr/bin/env bash
set -uo pipefail
MARCA="MEOWSYSTEM_GANCHO=1"
ANTES=".antes-meowsystem"
CHAVES=(pre-push post-merge)

uso() {
  printf 'uso: ganchos.sh [instalar|conferir|remover|rodar <gancho>]\n' >&2
  exit 2
}

pasta() {
  local comum
  comum="$(git rev-parse --git-common-dir 2>/dev/null)" || { printf 'ganchos: fora de um repositório git\n' >&2; exit 2; }
  printf '%s/hooks' "$(cd "$comum" && pwd -P)"
}

alvo_da_chave() { printf 'scripts/gancho-%s.sh' "$1"; }

corpo() {
  printf '#!/usr/bin/env bash\n%s\n' "$MARCA"
  cat <<EOF
[ -n "\${MEOWSYSTEM_GANCHO_RODANDO:-}" ] && exit 0
export MEOWSYSTEM_GANCHO_RODANDO=1
if [ -x "\$0$ANTES" ]; then
  "\$0$ANTES" "\$@" || exit \$?
fi
raiz="\$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -f "\$raiz/scripts/higiene.sh" ] || exit 0
cd "\$raiz" || exit 0
exec bash scripts/higiene.sh
EOF
}

nosso() { [ -f "$1" ] && grep -qxF "$MARCA" "$1"; }

avisar_caminho() {
  local dir="$1" hp alvo
  hp="$(git config core.hooksPath 2>/dev/null)" || return 0
  [ -n "$hp" ] || return 0
  hp="${hp/#\~/$HOME}"
  alvo="$(cd "$hp" 2>/dev/null && pwd -P)" || alvo="$hp"
  [ "$alvo" = "$dir" ] && return 0
  if [ -x "$alvo/pre-commit" ] && grep -qE 'git-common-dir|hooks/' "$alvo/pre-commit"; then
    printf 'aviso: core.hooksPath aponta para %s; o pre-commit de lá parece chamar o daqui\n' "$alvo"
  else
    printf 'aviso: core.hooksPath aponta para %s, e o pre-commit de lá não chama o daqui\n' "$alvo"
  fi
}

devolver() {
  local alvo="$1" nome="$2"
  if [ -e "$alvo$ANTES" ] || [ -L "$alvo$ANTES" ]; then
    mv -f "$alvo$ANTES" "$alvo"
    printf 'devolvido: %s\n' "$nome"
  else
    rm -f "$alvo"
    printf 'removido: %s\n' "$nome"
  fi
}

instalar() {
  local dir alvo rc=0 tmp nome valor
  dir="$(pasta)"
  mkdir -p "$dir" || exit 2
  alvo="$dir/pre-commit"
  tmp="$(mktemp "$dir/.pre-commit.XXXXXX")" || exit 2
  corpo > "$tmp"
  chmod 755 "$tmp"
  if nosso "$alvo"; then
    if cmp -s "$tmp" "$alvo"; then
      rm -f "$tmp"
      printf 'já estava: pre-commit\n'
    else
      mv -f "$tmp" "$alvo"
      printf 'atualizado: pre-commit\n'
    fi
  elif [ -e "$alvo" ] || [ -L "$alvo" ]; then
    if [ -e "$alvo$ANTES" ] || [ -L "$alvo$ANTES" ]; then
      rm -f "$tmp"
      printf 'recusado: pre-commit já tem um pre-commit%s ao lado; nada foi trocado\n' "$ANTES" >&2
      rc=2
    else
      mv "$alvo" "$alvo$ANTES"
      mv -f "$tmp" "$alvo"
      printf 'instalado: pre-commit (o de antes, pre-commit%s, roda primeiro)\n' "$ANTES"
    fi
  else
    mv -f "$tmp" "$alvo"
    printf 'instalado: pre-commit\n'
  fi
  for nome in "${CHAVES[@]}"; do
    nosso "$dir/$nome" && devolver "$dir/$nome" "$nome (da pasta comum)"
    valor="$(alvo_da_chave "$nome")"
    if [ "$(git config --get "ganchos.$nome" 2>/dev/null)" = "$valor" ]; then
      printf 'já estava: ganchos.%s = %s\n' "$nome" "$valor"
    else
      git config "ganchos.$nome" "$valor" || { rc=2; continue; }
      printf 'gravado: ganchos.%s = %s\n' "$nome" "$valor"
    fi
  done
  avisar_caminho "$dir"
  return "$rc"
}

conferir() {
  local dir nome rc=0 valor topo
  dir="$(pasta)"
  if nosso "$dir/pre-commit" && cmp -s <(corpo) "$dir/pre-commit" && [ -x "$dir/pre-commit" ]; then
    printf 'ok: pre-commit\n'
  else
    printf 'falta: pre-commit\n'
    rc=1
  fi
  topo="$(git rev-parse --show-toplevel 2>/dev/null)"
  for nome in "${CHAVES[@]}"; do
    valor="$(git config --get "ganchos.$nome" 2>/dev/null)"
    if [ "$valor" = "$(alvo_da_chave "$nome")" ] && [ -x "$topo/$valor" ]; then
      printf 'ok: ganchos.%s = %s\n' "$nome" "$valor"
    else
      printf 'falta: ganchos.%s (está: %s)\n' "$nome" "${valor:-vazia}"
      rc=1
    fi
  done
  avisar_caminho "$dir"
  return "$rc"
}

remover() {
  local dir nome
  dir="$(pasta)"
  if nosso "$dir/pre-commit"; then
    devolver "$dir/pre-commit" pre-commit
  else
    printf 'não era nosso: pre-commit\n'
  fi
  for nome in "${CHAVES[@]}"; do
    nosso "$dir/$nome" && devolver "$dir/$nome" "$nome (da pasta comum)"
    if git config --get "ganchos.$nome" >/dev/null 2>&1; then
      git config --unset-all "ganchos.$nome"
      printf 'removida: ganchos.%s\n' "$nome"
    else
      printf 'não havia: ganchos.%s\n' "$nome"
    fi
  done
  git config --remove-section ganchos >/dev/null 2>&1 || true
}

rodar() {
  local nome="${1:-}" raiz ramo rc
  shift || true
  raiz="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
  cd "$raiz" || exit 0
  case "$nome" in
    pre-commit)
      exec bash scripts/higiene.sh
      ;;
    post-merge)
      [ "${MEOW_SEM_README:-0}" = "1" ] && exit 0
      ramo="$(git symbolic-ref --short -q HEAD)"
      [ "$ramo" = dev ] || exit 0
      bash scripts/readme.sh --commit
      exit 0
      ;;
    pre-push)
      [ -t 0 ] || cat >/dev/null
      [ "${MEOW_SEM_README:-0}" = "1" ] && exit 0
      bash scripts/readme.sh --commit
      rc=$?
      if [ "$rc" -eq 1 ]; then
        printf 'pre-push: o README estava velho e o commit acima o regerou; este push parou para levá-lo no próximo\n' >&2
        exit 1
      fi
      exit 0
      ;;
    *) uso ;;
  esac
}

case "${1:-}" in
  instalar) instalar ;;
  conferir) conferir ;;
  remover)  remover ;;
  rodar)    shift; rodar "$@" ;;
  *)        uso ;;
esac

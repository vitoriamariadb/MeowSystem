#!/usr/bin/env bash
set -uo pipefail
GANCHOS=(pre-commit post-merge pre-push)
MARCA="MEOWSYSTEM_GANCHO=1"
ANTES=".antes-meowsystem"

uso() {
  printf 'uso: ganchos.sh [instalar|conferir|remover|rodar <gancho>]\n' >&2
  exit 2
}

pasta() {
  local comum
  comum="$(git rev-parse --git-common-dir 2>/dev/null)" || { printf 'ganchos: fora de um repositório git\n' >&2; exit 2; }
  printf '%s/hooks' "$(cd "$comum" && pwd -P)"
}

corpo() {
  local nome="$1"
  printf '#!/usr/bin/env bash\n%s\n' "$MARCA"
  if [ "$nome" = pre-push ]; then
    printf 'entrada="$(cat)"\n'
  else
    printf 'entrada=""\n'
  fi
  cat <<EOF
if [ -x "\$0$ANTES" ]; then
  printf '%s' "\$entrada" | "\$0$ANTES" "\$@" || exit \$?
fi
raiz="\$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -f "\$raiz/scripts/ganchos.sh" ] || exit 0
printf '%s' "\$entrada" | bash "\$raiz/scripts/ganchos.sh" rodar $nome "\$@"
EOF
}

nosso() { [ -f "$1" ] && grep -qxF "$MARCA" "$1"; }

avisar_caminho() {
  local dir="$1" hp alvo nome
  hp="$(git config core.hooksPath 2>/dev/null)" || return 0
  [ -n "$hp" ] || return 0
  hp="${hp/#\~/$HOME}"
  alvo="$(cd "$hp" 2>/dev/null && pwd -P)" || alvo="$hp"
  [ "$alvo" = "$dir" ] && return 0
  printf 'aviso: core.hooksPath manda o git rodar os ganchos de %s, não os de %s\n' "$alvo" "$dir"
  for nome in "${GANCHOS[@]}"; do
    if [ -x "$alvo/$nome" ] && grep -qE 'git-common-dir|hooks/' "$alvo/$nome"; then
      printf '  %s: o de lá parece chamar o daqui\n' "$nome"
    elif [ -e "$alvo/$nome" ]; then
      printf '  %s: o de lá não chama o daqui, e este não roda\n' "$nome"
    else
      printf '  %s: não existe lá, e este não roda\n' "$nome"
    fi
  done
}

instalar() {
  local dir nome alvo rc=0 tmp
  dir="$(pasta)"
  mkdir -p "$dir" || exit 2
  for nome in "${GANCHOS[@]}"; do
    alvo="$dir/$nome"
    tmp="$(mktemp "$dir/.$nome.XXXXXX")" || exit 2
    corpo "$nome" > "$tmp"
    chmod 755 "$tmp"
    if nosso "$alvo"; then
      if cmp -s "$tmp" "$alvo"; then
        rm -f "$tmp"
        printf 'já estava: %s\n' "$nome"
        continue
      fi
      mv -f "$tmp" "$alvo"
      printf 'atualizado: %s\n' "$nome"
    elif [ -e "$alvo" ] || [ -L "$alvo" ]; then
      if [ -e "$alvo$ANTES" ] || [ -L "$alvo$ANTES" ]; then
        rm -f "$tmp"
        printf 'recusado: %s já tem um %s%s ao lado; nada foi trocado\n' "$nome" "$nome" "$ANTES" >&2
        rc=2
        continue
      fi
      mv "$alvo" "$alvo$ANTES"
      mv -f "$tmp" "$alvo"
      printf 'instalado: %s (o de antes, %s%s, roda primeiro)\n' "$nome" "$nome" "$ANTES"
    else
      mv -f "$tmp" "$alvo"
      printf 'instalado: %s\n' "$nome"
    fi
  done
  avisar_caminho "$dir"
  return "$rc"
}

conferir() {
  local dir nome rc=0
  dir="$(pasta)"
  for nome in "${GANCHOS[@]}"; do
    if nosso "$dir/$nome" && cmp -s <(corpo "$nome") "$dir/$nome" && [ -x "$dir/$nome" ]; then
      printf 'ok: %s\n' "$nome"
    else
      printf 'falta: %s\n' "$nome"
      rc=1
    fi
  done
  avisar_caminho "$dir"
  return "$rc"
}

remover() {
  local dir nome alvo
  dir="$(pasta)"
  for nome in "${GANCHOS[@]}"; do
    alvo="$dir/$nome"
    nosso "$alvo" || { printf 'não era nosso: %s\n' "$nome"; continue; }
    if [ -e "$alvo$ANTES" ] || [ -L "$alvo$ANTES" ]; then
      mv -f "$alvo$ANTES" "$alvo"
      printf 'devolvido: %s\n' "$nome"
    else
      rm -f "$alvo"
      printf 'removido: %s\n' "$nome"
    fi
  done
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
      cat >/dev/null
      [ "${MEOW_SEM_README:-0}" = "1" ] && exit 0
      ramo="$(git symbolic-ref --short -q HEAD)"
      [ "$ramo" = dev ] || exit 0
      bash scripts/readme.sh --commit
      exit 0
      ;;
    pre-push)
      cat >/dev/null
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

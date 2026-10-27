#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$RAIZ" || exit 2
command -v git >/dev/null 2>&1 || { printf 'pulado: o git não está disponível\n'; exit 0; }

EU="tests/portabilidade.sh"
achados=0
isentos=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; achados=$((achados+1)); }

ISENTAS=(

  'file:///home/user/'
  'PathBuf::from("/home/user/Album Art.png")'

  'meow wallpaper permitir "/home/voce/Imagens/aquela-pasta"'
  '`LOGO=/home/x/meu-gato.svg`'

  'CASA_ALHEIA="/home/fulano"'
  'tema="$T/home/tema"'
)

_arquivo_de_registro() {
  case "$1" in
    docs/sprints/*|docs/historico/*|docs/SPRINTS.md) return 0 ;;
  esac
  return 1
}

isenta() {
  local linha="$1" t
  for t in "${ISENTAS[@]}"; do
    case "$linha" in *"$t"*) return 0 ;; esac
  done
  return 1
}

acusa() {
  local arquivo="$1" num="$2" linha="$3" frase="$4"
  if isenta "$linha" "$arquivo"; then
    isentos=$((isentos+1))
    return 0
  fi
  falha "$arquivo:$num $frase"
}

mapfile -t ARQUIVOS < <(git ls-files 2>/dev/null) || exit 2
[ "${#ARQUIVOS[@]}" -gt 0 ] || { printf 'pulado: não há arquivos versionados aqui\n'; exit 0; }

R1="$(mktemp)" || exit 2
trap 'rm -f "$R1"' EXIT
git grep --no-color --no-column -zInE '/home/[a-zA-Z0-9_-]+([^a-zA-Z0-9_-]|$)' -- . ":(exclude)$EU" > "$R1" 2>/dev/null
case $? in 0|1) ;; *) printf 'FALHOU: o git grep da regra 1 não rodou\n' >&2; exit 2 ;; esac
while IFS= read -r -d '' arq && IFS= read -r -d '' num && IFS= read -r linha; do
  acusa "$arq" "$num" "$linha" "home de pessoa escrito: é o nome de alguém dentro do produto"
done < "$R1"

_so_comentario() {
  local l="${1#"${1%%[![:space:]]*}"}"
  case "$l" in '#'*) return 0 ;; esac
  case "$2" in
    *.js|*.patch) case "$l" in '//'*|'*'*|'/*'*) return 0 ;; esac ;;
  esac
  return 1
}

_tem_shebang() {
  local primeira
  IFS= read -r primeira < "$1" 2>/dev/null || return 1
  case "$primeira" in '#!'*) return 0 ;; esac
  return 1
}

for arq in "${ARQUIVOS[@]}"; do
  [ "$arq" = "$EU" ] && continue
  _arquivo_de_registro "$arq" && continue
  [ -f "$arq" ] || continue

  case "$arq" in
    *.sh|*.py|*.js|*.patch) tipo="codigo" ;;
    *.md)                   tipo="prosa" ;;
    *) _tem_shebang "$arq" && tipo="codigo" || continue ;;
  esac

  cerca=0
  num=0
  while IFS= read -r linha || [ -n "$linha" ]; do
    num=$((num+1))
    case "$linha" in '```'*) cerca=$((1-cerca)); continue ;; esac

    if [ "$tipo" = "codigo" ]; then
      _so_comentario "$linha" "$arq" && continue
    else
      [ "$cerca" = "1" ] || continue
    fi

    case "$linha" in
      *"/mnt/Apate"*|*"/mnt/Mnemosyne"*)
        acusa "$arq" "$num" "$linha" "disco que não é padrão: quem clonou não tem esse ponto de montagem" ;;
    esac

    case "$linha" in
      *"[REDACTED]"*)
        acusa "$arq" "$num" "$linha" "identidade redigida numa instrução: o comando não roda" ;;
    esac

    if [ "$tipo" = "codigo" ]; then
      case "$arq" in
        bin/*|scripts/*|lib/*|app/*|install.sh)
          case "$linha" in
            *'.config/zsh'*)
              acusa "$arq" "$num" "$linha" "o Spellbook (~/.config/zsh) lido em execução: ou migra para cá, ou sai" ;;
            *'aurora-'*)
              acusa "$arq" "$num" "$linha" "um aurora-* do Ritual chamado em execução: ou migra para cá, ou sai" ;;
          esac ;;
      esac
    fi
  done < "$arq"
done

printf '\n'
if [ "$achados" -eq 0 ]; then
  ok "portabilidade: nenhuma receita presa à máquina de quem a escreveu ($isentos isenções)"
  exit 0
fi
printf 'FALHOU: %d achado(s) de portabilidade (%d isenções)\n' "$achados" "$isentos" >&2
exit 1

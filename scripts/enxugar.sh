#!/usr/bin/env bash
set -uo pipefail

RAIZ_DO_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ALVO="$RAIZ_DO_SCRIPT"
APLICAR=0
SO_TABELA=0
DESTINO_NO_ARQUIVO="levas/2026-10-27-pasta-local"
RAMO_ARQUIVO="arquivo"

TABELA='apagar	src/applets
apagar	assets/icones/upstream
apagar	assets/icones/catppuccin
apagar	.playwright-mcp
apagar	MeowSystem-master.zip
apagar	assets/fontes/upstream
apagar	assets/fontes/fonts
apagar	app/pagina/previas-sistema.js
apagar	app/pagina/previas-tela.js
apagar	scripts/icones_apps.sh
apagar	vizinhos.conf.exemplo
arquivar	.trabalho-icones
arquivar	docs/capturas/spotify.jpg
arquivar	aba7.png
arquivar	Imagem colada.png
arquivar	docs/folhas
arquivar	docs/pesquisas
arquivar	docs/sprints/2026-10-26-qa-final/capturas
arquivar	docs/sprints/2026-10-26-qa-final/relatorios/fotos
arquivar	assets/icones/PROCEDENCIA.md
arquivar	assets/icones/autorais
arquivar	assets/icones/arcticons
arquivar	assets/icones/arcticons-apps
arquivar	assets/icones/convertidos-apps
arquivar	assets/icones/tray-terceiros
arquivar	assets/icones/previa-arcticons
mapa	assets/icones/*.map
arquivar	assets/temas/capturados/latte-mauve
arquivar	assets/temas/capturados/mocha-mauve
arquivar	assets/temas/capturados/mocha-pink
arquivar	assets/gatos
arquivar	assets/cursores
arquivar	assets/temas-de-apps
arquivar	assets/sons/CREDITOS.md
arquivar	assets/prompt/aurora.patch
doutor	assets/papeis-de-parede'
PASTA_DA_PALETA=assets/paleta
TABELA+=$'\n'"arquivar	${PASTA_DA_PALETA}/catppuccin.json"
PREFIXO_ALHEIO=catppuccin
TABELA+=$'\n'"apagar	assets/icones/${PREFIXO_ALHEIO}-apps"

uso() {
  printf 'uso: scripts/enxugar.sh [--raiz <clone>] [--aplicar] [--tabela]\n'
  printf '  sem --aplicar só lista, com tamanho, o que sairia e para onde; nada é escrito\n'
  printf '  --aplicar leva o registro para a branch %s (commit por git worktree) e depois apaga\n' "$RAMO_ARQUIVO"
  printf '  --raiz aponta para o clone a enxugar (o padrão é o clone deste script)\n'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --aplicar) APLICAR=1 ;;
    --tabela)  SO_TABELA=1 ;;
    --raiz)    shift; ALVO="${1:-}" ;;
    -h|--ajuda|--help) uso; exit 0 ;;
    *) printf 'opção desconhecida: %s\n' "$1" >&2; uso >&2; exit 2 ;;
  esac
  shift
done

if [ "$SO_TABELA" = "1" ]; then
  printf '%s\n' "$TABELA"
  exit 0
fi

[ -d "$ALVO" ] || { printf 'erro: %s não é uma pasta\n' "$ALVO" >&2; exit 2; }
ALVO="$(cd "$ALVO" && pwd -P)"
git -C "$ALVO" rev-parse --git-dir >/dev/null 2>&1 || { printf 'erro: %s não é um clone git\n' "$ALVO" >&2; exit 2; }
git -C "$ALVO" rev-parse --verify --quiet "refs/heads/$RAMO_ARQUIVO" >/dev/null \
  || { printf 'erro: a branch %s não existe em %s\n' "$RAMO_ARQUIVO" "$ALVO" >&2; exit 2; }

humano() {
  awk -v b="$1" 'BEGIN { split("B KB MB GB", u, " "); i = 1; while (b >= 1024 && i < 4) { b /= 1024; i++ }
                         if (i == 1) printf "%d %s", b, u[i]; else { s = sprintf("%.1f", b); sub(/\./, ",", s); printf "%s %s", s, u[i] } }'
}

bytes_de() {
  local n
  n="$(du -sb --apparent-size -- "$ALVO/$1" 2>/dev/null | cut -f1)"
  printf '%s' "${n:-0}"
}

arquivos_de() {
  find "$ALVO/$1" -type f 2>/dev/null | grep -c . || true
}

caminho_seguro() {
  case "$1" in
    ''|/*|..|../*|*/..|*/../*) return 1 ;;
  esac
  local real
  real="$(readlink -m -- "$ALVO/$1")"
  case "$real" in "$ALVO"/*) return 0 ;; esac
  return 1
}

versionado() {
  [ -n "$(git -C "$ALVO" ls-files -- "$1" 2>/dev/null | head -n1)" ]
}

igual_ao_do_pack() {
  local nome p
  nome="$(basename -- "$1")"
  for p in "$ALVO"/packs/*/icones/"$nome"; do
    [ -f "$p" ] && cmp -s -- "$ALVO/$1" "$p" && return 0
  done
  return 1
}

declare -a PLANO_TIPO=() PLANO_CAMINHO=() PLANO_BYTES=() PLANO_ARQ=() PLANO_NOTA=()
PENDENTE_DO_DOCTOR=0
FICOU=0

planejar() {
  local tipo="$1" caminho="$2" nota="${3:-}"
  PLANO_TIPO+=("$tipo"); PLANO_CAMINHO+=("$caminho"); PLANO_NOTA+=("$nota")
  PLANO_BYTES+=("$(bytes_de "$caminho")"); PLANO_ARQ+=("$(arquivos_de "$caminho")")
}

while IFS=$'\t' read -r tipo molde; do
  [ -n "$tipo" ] || continue
  mapfile -t achados < <(cd "$ALVO" && compgen -G "$molde" | LC_ALL=C sort)
  for caminho in "${achados[@]}"; do
    [ -n "$caminho" ] || continue
    caminho_seguro "$caminho" || { printf 'recusado (caminho fora do clone): %s\n' "$caminho" >&2; FICOU=1; continue; }
    [ -e "$ALVO/$caminho" ] || [ -L "$ALVO/$caminho" ] || continue
    if versionado "$caminho"; then
      planejar fica "$caminho" "o git guarda este caminho — não mexo"
      continue
    fi
    case "$tipo" in
      apagar)   planejar apagar "$caminho" ;;
      arquivar) planejar arquivar "$caminho" ;;
      mapa)
        if igual_ao_do_pack "$caminho"; then planejar apagar "$caminho" "igual ao do pack"
        else planejar arquivar "$caminho" "difere do pack ou não tem par"; fi ;;
      doutor)
        planejar doutor "$caminho" "o doctor (conferência basefundo) move para ~/.local/share/backgrounds/meowsystem; nenhuma imagem é apagada"
        PENDENTE_DO_DOCTOR=1 ;;
    esac
  done
done <<< "$TABELA"

printf 'enxugar: %s\n' "$ALVO"
acionaveis=0
for tipo in "${PLANO_TIPO[@]}"; do
  [ "$tipo" = "fica" ] || acionaveis=$((acionaveis + 1))
done
if [ "$acionaveis" -eq 0 ]; then
  printf '\nnada a enxugar: nenhum caminho da lista fechada existe aqui\n'
fi

total_apagar=0; total_arquivar=0
printf '\n%-9s %10s %8s  %s\n' destino tamanho arquivos caminho
for i in "${!PLANO_CAMINHO[@]}"; do
  tipo="${PLANO_TIPO[$i]}"
  case "$tipo" in
    apagar)   rotulo="apagar";  total_apagar=$((total_apagar + PLANO_BYTES[i])) ;;
    arquivar) rotulo="$RAMO_ARQUIVO"; total_arquivar=$((total_arquivar + PLANO_BYTES[i])) ;;
    doutor)   rotulo="doctor" ;;
    fica)     rotulo="fica" ;;
  esac
  printf '%-9s %10s %8s  %s%s\n' "$rotulo" "$(humano "${PLANO_BYTES[$i]}")" "${PLANO_ARQ[$i]}" "${PLANO_CAMINHO[$i]}" \
    "${PLANO_NOTA[$i]:+  (${PLANO_NOTA[$i]})}"
done
printf '\napagar: %s · para a branch %s: %s\n' "$(humano "$total_apagar")" "$RAMO_ARQUIVO" "$(humano "$total_arquivar")"

if [ "$APLICAR" != "1" ]; then
  printf '\nnada foi escrito: --aplicar executa a lista acima\n'
  exit 0
fi

ANTES_TOTAL="$(du -sb --apparent-size -- "$ALVO" 2>/dev/null | cut -f1)"

arquivar_no_ramo() {
  local wt caminho
  local -a caminhos=("$@")
  [ "${#caminhos[@]}" -gt 0 ] || return 0
  wt="$(mktemp -d)" || return 1
  if ! git -C "$ALVO" worktree add -q --no-checkout "$wt" "$RAMO_ARQUIVO" >/dev/null 2>&1; then
    printf 'erro: não consegui abrir a branch %s por git worktree (ela está aberta em outra pasta?)\n' "$RAMO_ARQUIVO" >&2
    rm -rf -- "$wt"; return 1
  fi
  local ok=1
  git -C "$wt" read-tree HEAD || ok=0
  if [ "$ok" = "1" ]; then
    mkdir -p -- "$wt/$DESTINO_NO_ARQUIVO"
    for caminho in "${caminhos[@]}"; do
      (cd "$ALVO" && tar -cf - --exclude=__pycache__ --exclude='*.pyc' -- "$caminho") \
        | tar -xf - -C "$wt/$DESTINO_NO_ARQUIVO" || { ok=0; break; }
    done
  fi
  if [ "$ok" = "1" ]; then
    local leia="$wt/$DESTINO_NO_ARQUIVO/LEIA-ME.md" item
    git -C "$wt" show "HEAD:$DESTINO_NO_ARQUIVO/LEIA-ME.md" > "$leia" 2>/dev/null || rm -f -- "$leia"
    if [ ! -f "$leia" ]; then
      {
        printf '# Sobras da pasta local, 27/10/2026\n\n'
        printf 'Tiradas do clone por `scripts/enxugar.sh` (P123 da leva central e gerador). Cada caminho abaixo mora aqui\n'
        printf 'com o mesmo nome relativo ao clone.\n\n'
      } > "$leia"
    fi
    for caminho in "${caminhos[@]}"; do
      item="$(printf -- '- `%s`' "$caminho")"
      grep -qxF -- "$item" "$leia" || printf '%s\n' "$item" >> "$leia"
    done
    git -C "$wt" add -f --ignore-removal -- "$DESTINO_NO_ARQUIVO" || ok=0
  fi
  if [ "$ok" = "1" ]; then
    local -A no_indice=()
    local linha arq h_local
    while IFS= read -r -d '' linha; do
      arq="${linha#*$'\t'}"; linha="${linha%%$'\t'*}"; linha="${linha#* }"
      no_indice["${arq#"$DESTINO_NO_ARQUIVO"/}"]="${linha%% *}"
    done < <(git -C "$wt" --literal-pathspecs ls-files -s -z -- "$DESTINO_NO_ARQUIVO")
    for caminho in "${caminhos[@]}"; do
      while IFS= read -r -d '' arq; do
        h_local="$(git -C "$ALVO" hash-object --no-filters -- "$arq")"
        if [ -z "$h_local" ] || [ "${no_indice[$arq]:-}" != "$h_local" ]; then
          printf 'erro: %s não chegou igual à branch %s — nada será apagado\n' "$arq" "$RAMO_ARQUIVO" >&2
          ok=0; break 2
        fi
      done < <(cd "$ALVO" && find "$caminho" \( -type f -o -type l \) -not -path '*/__pycache__/*' -not -name '*.pyc' -print0)
    done
  fi
  if [ "$ok" = "1" ] && ! git -C "$wt" diff --cached --quiet; then
    git -C "$wt" -c core.hooksPath=/dev/null commit -q \
      -m "docs(arquivo): as sobras da pasta local de 27/10/2026, tiradas do clone pela P123" \
      -m "Registro e arte antiga que nenhuma etapa lê mais; o caminho original de cada uma está em $DESTINO_NO_ARQUIVO/LEIA-ME.md." \
      || ok=0
  fi
  git -C "$ALVO" worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf -- "$wt"
  git -C "$ALVO" worktree prune >/dev/null 2>&1
  [ "$ok" = "1" ]
}

declare -a PARA_ARQUIVAR=()
for i in "${!PLANO_CAMINHO[@]}"; do
  [ "${PLANO_TIPO[$i]}" = "arquivar" ] && PARA_ARQUIVAR+=("${PLANO_CAMINHO[$i]}")
done

ARQUIVOU=1
if [ "${#PARA_ARQUIVAR[@]}" -gt 0 ]; then
  if arquivar_no_ramo "${PARA_ARQUIVAR[@]}"; then
    printf '\n%d caminho(s) levados para a branch %s em %s/\n' "${#PARA_ARQUIVAR[@]}" "$RAMO_ARQUIVO" "$DESTINO_NO_ARQUIVO"
  else
    ARQUIVOU=0
    FICOU=1
    printf '\nnão consegui guardar o registro na branch %s: os caminhos de registro ficam onde estão\n' "$RAMO_ARQUIVO" >&2
  fi
fi

apagados=0
for i in "${!PLANO_CAMINHO[@]}"; do
  caminho="${PLANO_CAMINHO[$i]}"
  case "${PLANO_TIPO[$i]}" in
    apagar) ;;
    arquivar) [ "$ARQUIVOU" = "1" ] || continue ;;
    *) continue ;;
  esac
  caminho_seguro "$caminho" || continue
  if rm -rf -- "${ALVO:?}/$caminho"; then
    apagados=$((apagados + 1))
  else
    printf 'erro: não consegui apagar %s\n' "$caminho" >&2; FICOU=1
  fi
done

DEPOIS_TOTAL="$(du -sb --apparent-size -- "$ALVO" 2>/dev/null | cut -f1)"
printf '%d caminho(s) saíram do clone\n' "$apagados"
printf 'o clone: %s antes, %s depois\n' "$(humano "$ANTES_TOTAL")" "$(humano "$DEPOIS_TOTAL")"

resto="$(git -C "$ALVO" status --porcelain 2>/dev/null)"
if [ -n "$resto" ]; then
  printf '\nainda aparece no git status (fora da lista fechada, quem decide é ela):\n'
  printf '%s\n' "$resto" | sed 's/^/  /'
fi

if [ "$PENDENTE_DO_DOCTOR" = "1" ]; then
  printf '\npendente: assets/papeis-de-parede ainda está no clone: a conferência basefundo do doctor o move, e este script fecha depois dela\n'
  exit 3
fi
[ "$FICOU" = "0" ] || exit 1
exit 0

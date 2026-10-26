#!/usr/bin/env bash
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COSMIC="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}"
SECO="${MEOW_DRY_RUN:-0}"
# shellcheck source=../lib/restauro.sh
. "$RAIZ/lib/restauro.sh"

declare -a CHAVES_ALPHA_AURORA=(background primary secondary)

declare -a CHAVES_DELA=(frosted alpha_map frosted_maximized_apps)

e_chave_dela() {
  local chave; chave="$(basename "$1")"
  case "$1" in
    com.system76.CosmicTheme.Mode/v*/is_dark|com.system76.CosmicTheme.Mode/v*/auto_switch) return 0 ;;
  esac
  case "$1" in com.system76.CosmicTheme.*) ;; *) return 1 ;; esac
  for k in "${CHAVES_DELA[@]}"; do [ "$chave" = "$k" ] && return 0; done
  return 1
}

e_produto() {
  case "$1" in
    com.system76.CosmicTheme.Dark/v1/*|com.system76.CosmicTheme.Light/v1/*) return 1 ;;
    com.system76.CosmicTheme.Dark/*|com.system76.CosmicTheme.Light/*) return 0 ;;
  esac
  return 1
}

receita_diverge() {
  local arv v a b chave k slider=0
  for arv in Dark Light; do
    for v in v1 v2; do
      for a in "$ORIGEM/com.system76.CosmicTheme.$arv.Builder/$v"/*; do
        chave="$(basename "$a")"
        b="$COSMIC/com.system76.CosmicTheme.$arv.Builder/$v/$chave"
        [ -f "$a" ] && [ -f "$b" ] || continue
        cmp -s "$a" "$b" && continue
        [ "$chave" = "frosted_maximized_apps" ] && continue
        for k in "${CHAVES_DELA[@]}"; do
          [ "$chave" = "$k" ] && { slider=1; continue 2; }
        done
        return 1
      done
    done
  done
  [ "$slider" = "1" ]
}

uso() {
  cat <<'FIM'
uso: aplicar_tema.sh <nome> [--conferir]

Restaura no COSMIC a captura <nome>, resolvida pelo pack ativo.

  <nome>       qual captura aplicar. Ex.: original, mocha-mauve.
  --conferir   não escreve; sai 0 se já está aplicado, 1 se divergente.

Variáveis:
  MEOW_DRY_RUN=1    mostra o que faria e não escreve (igual a --conferir, verboso).
  MEOW_COSMIC_DIR   destino (padrão: ~/.config/cosmic).
FIM
}

[ $# -ge 1 ] || { uso >&2; exit 2; }
NOME="$1"; shift
CONFERIR=0
for a in "$@"; do
  case "$a" in
    --conferir)      CONFERIR=1 ;;
    --respeitar-gui) ;;
    *) echo "ERRO: opção desconhecida: '$a'" >&2; uso >&2; exit 2 ;;
  esac
done
[ "$SECO" = "1" ] && CONFERIR=1

case "$NOME" in ''|*/*|.*) echo "ERRO: nome inválido: '$NOME'" >&2; exit 2 ;; esac
ORIGEM="$(python3 "$RAIZ/scripts/pack.py" captura "$NOME" 2>/dev/null)" || ORIGEM=""
[ -n "$ORIGEM" ] && [ -d "$ORIGEM" ] || {
  echo "ERRO: captura '$NOME' não existe no pack ativo, no que ele herda, nem em assets/temas/capturados/" >&2
  exit 3
}

normalizar() {
  sed -E 's/^(    base: "#[0-9A-Fa-f]{6})[0-9A-Fa-f]{2}"/\1XX"/'
}

e_chave_da_aurora() {
  local rel="$1" chave dir
  chave="$(basename "$rel")"
  dir="$(dirname "$rel")"
  case "$rel" in *.Builder/*) return 1 ;; esac
  case "$rel" in com.system76.CosmicTheme.*) ;; *) return 1 ;; esac
  for k in "${CHAVES_ALPHA_AURORA[@]}"; do
    if [ "$chave" = "$k" ] && [ -f "$ORIGEM/$dir/transparent_$k" ]; then
      return 0
    fi
  done
  return 1
}

MEOW_ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"
BACKUPS_MANTIDOS="${BACKUPS_MANTIDOS:-10}"
BACKUP_DIR=""

garantir_backup() {
  [ -n "$BACKUP_DIR" ] && return 0
  local marca="" velho
  for velho in "$MEOW_ESTADO"/backups/*-tema-*; do
    [ -d "$velho" ] && { marca="ja-rodou"; break; }
  done
  [ -n "$marca" ] || marca="PRIMEIRO-"
  [ "$marca" = "ja-rodou" ] && marca=""
  BACKUP_DIR="$MEOW_ESTADO/backups/$(date +%Y-%m-%dT%H-%M-%S)-tema-$marca$NOME"
  mkdir -p "$BACKUP_DIR" || { echo "ERRO: não consegui criar $BACKUP_DIR" >&2; exit 2; }

  for a in "$ORIGEM"/com.system76.CosmicTheme.*; do
    [ -d "$a" ] || continue
    n="$(basename "$a")"
    [ -d "$COSMIC/$n" ] || continue
    cp -a "$COSMIC/$n" "$BACKUP_DIR/" 2>/dev/null || true
  done

  ( cd "$BACKUP_DIR" && find . -type f ! -name manifesto.sha256 -exec sha256sum {} + \
      > manifesto.sha256 2>/dev/null ) || true

  cat > "$BACKUP_DIR/COMO-RESTAURAR.txt" <<FIM
Estado de ~/.config/cosmic (só as árvores de tema) antes de aplicar a captura
'$NOME', em $(date '+%d/%m/%Y %H:%M:%S').

Para voltar exatamente a este estado:

    cp -a $BACKUP_DIR/com.system76.CosmicTheme.* ~/.config/cosmic/

Para conferir que nada se corrompeu aqui dentro:

    cd $BACKUP_DIR && sha256sum -c manifesto.sha256

O COSMIC relê por inotify: a interface acompanha em segundos, sem relogar.
FIM
  echo "  backup em $BACKUP_DIR (veja COMO-RESTAURAR.txt)"

  local -a antigas=()
  for velho in "$MEOW_ESTADO"/backups/*-tema-"$NOME"; do
    [ -d "$velho" ] || continue
    case "$velho" in *-tema-PRIMEIRO-*) continue ;; esac
    antigas+=("$velho")
  done
  [ "${BACKUPS_MANTIDOS:-10}" -eq 0 ] 2>/dev/null && return 0
  if [ "${#antigas[@]}" -gt "$BACKUPS_MANTIDOS" ]; then
    printf '%s\n' "${antigas[@]}" | sort | head -n "-$BACKUPS_MANTIDOS" \
      | while read -r velho; do rm -rf "$velho"; done
  fi
  return 0
}

CAPTURA="$ORIGEM"
VISTA=""
if VISTA="$(mktemp -d "${TMPDIR:-/tmp}/meow-vidro.XXXXXX")"; then
  trap 'rm -rf "$VISTA"' EXIT
  rc_vidro=0
  frase_vidro="$(MEOW_COSMIC_DIR="$COSMIC" python3 "$RAIZ/scripts/derivar_vidro.py" \
                   "$CAPTURA" --vista "$VISTA/captura" 2>&1)" || rc_vidro=$?
  [ "$rc_vidro" = "1" ] && [ -d "$VISTA/captura" ] && ORIGEM="$VISTA/captura"
  case "$rc_vidro" in
    1|3) if [ "$CONFERIR" != "1" ] || [ "$SECO" = "1" ]; then
           printf '  %s\n' "$frase_vidro"
         fi ;;
  esac
fi

confere() {
  if e_chave_da_aurora "$1"; then
    diff -q <(normalizar < "$2") <(normalizar < "$3") >/dev/null 2>&1
  else
    cmp -s "$2" "$3"
  fi
}

e_a_foto() { confere "$1" "$CAPTURA/$1" "$COSMIC/$1"; }

divergentes=0
escritos=0
iguais=0
cedidos=0

RESPEITAR_GUI=0
[ "${MEOW_RESPEITAR_GUI:-0}" = "1" ] && RESPEITAR_GUI=1
for a in "$@"; do [ "$a" = "--respeitar-gui" ] && RESPEITAR_GUI=1; done

RECEITA_VELHA=0
[ "$RESPEITAR_GUI" = "1" ] && receita_diverge && RECEITA_VELHA=1

fichas="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import derivar_acento
print("\n".join(derivar_acento.FICHAS))' "$RAIZ/scripts" 2>/dev/null)" && [ -n "$fichas" ] || {
  echo "ERRO: não consegui ler do scripts/derivar_acento.py quais arquivos da captura são fichas" >&2
  exit 2
}
mapfile -t FICHAS <<< "$fichas"

while IFS= read -r -d '' arq; do
  rel="${arq#"$ORIGEM"/}"
  for ficha in "${FICHAS[@]}"; do [ "$rel" = "$ficha" ] && continue 2; done
  destino="$COSMIC/$rel"

  if e_chave_dela "$rel" && [ -f "$destino" ]; then
    iguais=$((iguais+1)); continue
  fi

  if [ -f "$destino" ] && confere "$rel" "$arq" "$destino"; then
    iguais=$((iguais+1)); continue
  fi

  if [ "$RECEITA_VELHA" = "1" ] && e_produto "$rel" && [ -f "$destino" ] \
     && ! e_a_foto "$rel"; then
    cedidos=$((cedidos+1)); continue
  fi

  divergentes=$((divergentes+1))
  if [ "$CONFERIR" = "1" ]; then
    [ "$SECO" = "1" ] && echo "  mudaria  $rel"
    continue
  fi

  garantir_backup
  meow_guardar_antes "$destino"
  mkdir -p "$(dirname "$destino")"
  tmp="$(mktemp -p "$(dirname "$destino")" ".meow.XXXXXX")"
  cat "$arq" > "$tmp"
  chmod 644 "$tmp"
  mv -f "$tmp" "$destino"
  escritos=$((escritos+1))
done < <(find "$ORIGEM" -type f -print0)

sobrando=0
for arvore in "$ORIGEM"/com.system76.CosmicTheme.*; do
  [ -d "$arvore" ] || continue
  nome_arvore="$(basename "$arvore")"
  [ -d "$COSMIC/$nome_arvore" ] || continue
  while IFS= read -r -d '' vivo; do
    rel="${vivo#"$COSMIC"/}"
    [ -e "$ORIGEM/$rel" ] && continue
    if [ "$RECEITA_VELHA" = "1" ] && e_produto "$rel"; then
      cedidos=$((cedidos+1)); continue
    fi
    sobrando=$((sobrando+1))
    if [ "$CONFERIR" = "1" ]; then
      [ "$SECO" = "1" ] && echo "  removeria $rel"
      continue
    fi
    garantir_backup
    meow_guardar_antes "$vivo"
    rm -f "$vivo"
  done < <(find "$COSMIC/$nome_arvore" -type f -print0)
done

MEOW_CAPTURA_VELHA=4

aviso_receita() {
  echo "a captura '$NOME' está velha: você mexeu em Aparência e a GUI derivou um tema novo."
  echo "  $cedidos arquivo(s) preservados."
}

if [ "$CONFERIR" = "1" ]; then
  if [ "$divergentes" -eq 0 ] && [ "$sobrando" -eq 0 ]; then
    if [ "$cedidos" -gt 0 ]; then
      aviso_receita
      exit "$MEOW_CAPTURA_VELHA"
    fi
    echo "tema '$NOME' já aplicado ($iguais arquivos conferem)"
    exit 0
  fi
  echo "tema '$NOME' divergente: $divergentes de $((divergentes+iguais)) arquivos" \
       "${sobrando:+e $sobrando sobrando}"
  exit 1
fi

if [ "$escritos" -eq 0 ] && [ "$sobrando" -eq 0 ] && [ "$cedidos" -gt 0 ]; then
  aviso_receita
  exit "$MEOW_CAPTURA_VELHA"
fi

echo "tema '$NOME' aplicado: $escritos escritos, $iguais já estavam certos${sobrando:+, $sobrando removidos}${cedidos:+, $cedidos preservados da sua GUI}"
exit 0

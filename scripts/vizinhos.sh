#!/usr/bin/env bash
# vizinhos.sh — quem mais escreve onde o MeowSystem escreve, e o desligar com volta.
#
#   ./vizinhos.sh --inventario        a tabela: responsabilidade, escritor, gatilho, estado, meow
#   ./vizinhos.sh --conferir          a linha do doctor: duplicata automática não revisada sai 4
#   ./vizinhos.sh --revisado          guarda as duplicatas automáticas de hoje como revisadas
#   ./vizinhos.sh --listar            os itens que o --desativar conhece, e o estado de cada um
#   ./vizinhos.sh --prontos           os itens que o MeowSystem instalado já substitui: sai 1 se há algum
#   ./vizinhos.sh --desativar <item>  cópia datada, a desativação e a linha no registro
#   ./vizinhos.sh --desativar-prontos todos os prontos, na ordem do contrato (VIZINHOS_DESATIVAR="sim")
#   ./vizinhos.sh --restaurar <item>|todos
#
# O inventário só lê: sem rede, sem sudo, e a saída sai ordenada (duas rodadas
# iguais). "Escreve" é heurística de linha: um verbo de escrita e um território
# do MeowSystem na mesma linha que não é comentário.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ESTADO="${MEOW_ESTADO:-${XDG_STATE_HOME:-$HOME/.local/state}/meowsystem}"
REGISTRO="$ESTADO/vizinhos-desativados.tsv"
REVISADOS="$ESTADO/vizinhos-revisados.tsv"
COPIAS="$ESTADO/vizinhos"
ETC="${VIZINHOS_ETC:-/etc}"
DESENV="${VIZINHOS_DESENV:-$HOME/Desenvolvimento}"
APPS_CASA="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
UNI="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SBIN="${VIZINHOS_SBIN:-/usr/local/sbin}"
CONTRATO="${VIZINHOS_CONTRATO:-$RAIZ/assets/contratos/vizinhos.tsv}"
export LC_ALL=C

_zdotdir() {
  local z=""
  if [ -n "${ZDOTDIR:-}" ]; then
    case "$(readlink -m -- "$ZDOTDIR")/" in "$(readlink -m -- "$HOME")"/*) printf '%s' "$ZDOTDIR"; return 0 ;; esac
  fi
  [ -r "$HOME/.zshenv" ] && z="$(sed -n -E 's/^[[:space:]]*(export[[:space:]]+)?ZDOTDIR=["'"'"']?([^"'"'"' ]*).*/\2/p' "$HOME/.zshenv" | head -1)"
  z="${z//\$\{HOME\}/$HOME}"; z="${z//\$HOME/$HOME}"; z="${z/#\~/$HOME}"
  printf '%s' "${z:-$HOME}"
}
ZD="$(_zdotdir)"
REPOS="${VIZINHOS_REPOS:-$(awk -F'\t' '$1 == "repo" { printf "%s ", $2 }' "$CONTRATO" 2>/dev/null)}"

MEOW_LIDO="$RAIZ"
if [ -r "$ESTADO/raiz" ]; then
  _p="$(head -1 "$ESTADO/raiz" 2>/dev/null)"
  [ -n "$_p" ] && [ -f "$_p/bin/meow" ] && MEOW_LIDO="$_p"
fi

TERRITORIOS="$(cat <<'FIM'
cache do tema de ícones	gtk-update-icon-cache|icon-theme[.]cache
tema de ícones	[.]local/share/icons|icon-theme|icon_theme|CosmicTk
lançador (.desktop)	share/applications|update-desktop-database|NoDisplay=|StartupWMClass|mimeinfo[.]cache
papel de parede	CosmicBackground|picture-uri|share/backgrounds
tema do COSMIC	CosmicTheme
painel e dock	cosmic-panel|CosmicPanel
cursor	cursor-theme|[.]icons/default
fastfetch	[.]config/fastfetch
Spotify (spicetify)	spicetify|config-xpui
compositor	cosmic-comp
terminal	CosmicTerm
tela de login	cosmic-greeter
fontes	fc-cache|share/fonts
tema GTK	gtk-theme|gtk-[34][.]0/gtk[.]css
sons	sound-theme|share/sounds
prompt	starship[.]toml
cores do fzf	FZF_DEFAULT_OPTS
FIM
)"

VERBO='gsettings[[:space:]]+set|dconf[[:space:]]+(write|load|reset)|sed[[:space:]]+(-[a-zA-Z]*i|--in-place)|>>?[[:space:]]*["'"'"'$~/]|(^|[^[:alnum:]_.-])(tee|cp|mv|install|ln|rm|rsync|touch|mkdir|chmod|unlink|truncate)[[:space:]]|gtk-update-icon-cache|update-desktop-database|fc-cache|write_text|write_bytes|shutil[.](copy|move|rmtree)|os[.](replace|rename|remove|unlink|chmod|symlink)|open[(][^)]*["'"'"'][wa]|pkill|killall|kill[[:space:]]|systemctl[[:space:]]+(--user[[:space:]]+)?(restart|stop|start|enable|disable|mask|kill)|spicetify[[:space:]]+(apply|config|backup|restore)'

_varrer() {
  awk -F'\t' -v terr="$TERRITORIOS" -v verbo="$VERBO" '
    BEGIN {
      n = split(terr, ls, "\n")
      for (i = 1; i <= n; i++) { split(ls[i], p, "\t"); tn[i] = p[1]; tr[i] = p[2] }
    }
    {
      chave = $1; arq = $2; ini = $3 + 0; fim = $4 + 0
      visto = 0; morto = 0; ln = 0
      for (v in var) delete var[v]
      while ((getline l < arq) > 0) {
        ln++
        # O aviso de desativado pode morar no comentário logo acima da função.
        if (ln < ini) { if (ln >= ini - 6 && l ~ /DESATIVAD/) visto = 1; else if (ln < ini - 6) visto = 0; continue }
        if (fim > 0 && ln > fim) break
        if (l ~ /DESATIVAD/) visto = 1
        if (l ~ /#vizinhos[+]:/) { morto = 1; continue }
        # A saída que desativa é a do nível de cima: `exit 0` na coluna 0 do script,
        # `return 0` no primeiro recuo da função — não a de dentro de um `if`.
        if (visto && ((fim == 0 && l ~ /^exit[[:space:]]+0([[:space:];]|$)/) || \
                      (fim > 0 && l ~ /^(\t| {1,4})return[[:space:]]+0([[:space:];]|$)/))) { morto = 1; continue }
        if (l ~ /^[[:space:]]*(#|\/\/)/) continue
        sub(/[[:space:]]#.*$/, "", l)
        gsub(/[0-9&]*>>?[[:space:]]*\/dev\/null/, "", l)
        gsub(/>&[0-9]/, "", l)
        gsub(/[-=]>/, "", l)
        # Variável de shell que guarda um território: `dst="$HOME/.local/share/applications/x"`.
        if (match(l, /^[[:space:]]*((local|export|readonly|declare)[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=/)) {
          nv = substr(l, RSTART, RLENGTH); sub(/^[[:space:]]*((local|export|readonly|declare)[[:space:]]+)?/, "", nv); sub(/=$/, "", nv)
          rhs = substr(l, RSTART + RLENGTH)
          for (i = 1; i <= n; i++) if (rhs ~ tr[i]) var[nv] = var[nv] SUBSEP i
          for (v in var) if (v != nv && (index(rhs, "$" v) || index(rhs, "${" v))) var[nv] = var[nv] var[v]
        }
        if (l !~ verbo) continue
        delete achou
        for (i = 1; i <= n; i++) if (l ~ tr[i]) achou[i] = 1
        for (v in var) if (index(l, "$" v) || index(l, "${" v)) {
          m = split(var[v], q, SUBSEP); for (j = 2; j <= m; j++) achou[q[j]] = 1
        }
        for (i in achou) print chave "\t" tn[i] "\t" morto
      }
      close(arq)
    }'
}

_texto() {
  local f="$1"
  [ -f "$f" ] && [ -r "$f" ] || return 1
  [ "$(stat -c %s "$f" 2>/dev/null || echo 0)" -le 1048576 ] || return 1
  case "$f" in
    "$HOME"/*|/usr/local/*|/opt/*|/etc/*|"${VIZINHOS_ETC:-/etc}"/*) ;;
    *) return 1 ;;
  esac
  case "$f" in
    "$MEOW_LIDO"/*|"$RAIZ"/*|/dev/*|/proc/*) return 1 ;;
    "$HOME"/.local/bin/meow|"$HOME"/.local/bin/meow-*|"$HOME"/.local/libexec/meow/*) return 1 ;;
    /usr/local/lib/meowsystem/*|/usr/local/sbin/meow-*) return 1 ;;
  esac
  case "$f" in *.sh|*.py|*.zsh|*.bash) return 0 ;; esac
  head -c 2 "$f" 2>/dev/null | grep -q '^#!' || return 1
  ! grep -qI . "$f" 2>/dev/null && return 1
  return 0
}

_curto() {
  local c="$1"
  case "$c" in "$HOME"/*) printf '~/%s' "${c#"$HOME"/}" ;; *) printf '%s' "$c" ;; esac
}

_refs() {
  local base="${1:-}" texto t f d
  texto="$(grep -vE '(^|[^[:alnum:]_-])(cp|install|cmp|rsync|copia_se_diff|copia_user)[[:space:]]' \
           | grep -vE '(^|[^[:alnum:]_])(echo|printf|print|log|warn|err|erro|info|aviso|msg|die|fatal|_info|_ok|_warn|__ok|__warn|__item|meow_[a-z]+)([[:space:](]|$)')"
  {
    printf '%s\n' "$texto" | grep -oE '(~/|\$HOME/|\$\{HOME\}/|%h/|\$ZDOTDIR/|\$\{ZDOTDIR[^}]*\}/|/)[^][:space:]"'"'"';|&()<>{}*]+' 2>/dev/null \
      | while IFS= read -r t; do
          t="${t/#\~\//$HOME/}"; t="${t/#\$HOME\//$HOME/}"; t="${t/#\$\{HOME\}\//$HOME/}"
          t="${t/#%h\//$HOME/}"; t="${t/#\$ZDOTDIR\//$ZD/}"
          case "$t" in '${ZDOTDIR'*) t="$ZD/${t#*\}/}" ;; esac
          _texto "$t" && printf '%s\n' "$t"
        done
    if [ -n "$base" ]; then
      d="$(dirname "$base")"
      local irmas=""
      [ -e "$(dirname "$d")/.git" ] && irmas="$(dirname "$d")"
      printf '%s\n' "$texto" | grep -oE '[A-Za-z0-9_.-]+\.(sh|py|zsh)' 2>/dev/null | sort -u \
        | while IFS= read -r t; do
            for f in "$d/$t" ${irmas:+"$irmas"/*/"$t"}; do
              [ "$f" = "$base" ] && continue
              _texto "$f" && printf '%s\n' "$f"
            done
          done
    fi
  } | sort -u
}

declare -A UNID=() GAT=() EST=()
declare -A FUNC_ARQ=() FUNC_INI=() FUNC_FIM=()
FILA=()

_peso() { case "$1" in ativo) echo 3 ;; 'à mão') echo 2 ;; *) echo 1 ;; esac; }

_marcar() {
  local k="$1"
  UNID[$k]="$2"$'\t'"$3"$'\t'"$4"
  case ";${GAT[$k]:-};" in *";$5;"*) ;; *) GAT[$k]="${GAT[$k]:+${GAT[$k]};}$5" ;; esac
  if [ -z "${EST[$k]:-}" ] || [ "$(_peso "$6")" -gt "$(_peso "${EST[$k]}")" ]; then EST[$k]="$6"; fi
}

_seguir() {
  local f="$1" g="$2" e="$3" n="${4:-1}" r
  case "$f" in "$ZD"/functions/*|"$ZD"/aliases.zsh) return 0 ;; esac
  local visto="${UNID[$f]:-}"
  _marcar "$f" "$f" 1 0 "$g" "$e"
  [ -n "$visto" ] && return 0
  [ "$n" -ge 3 ] && return 0
  while IFS= read -r r; do
    [ -n "$r" ] && _seguir "$r" "$g" "$e" $((n + 1))
  done < <(grep -vE '^[[:space:]]*(#|//)' "$f" | _refs "$f")
}

_ativa_usuario() {
  local u="$1" b="${1%.*}" w
  for w in "$HOME/.config/systemd/user"/*.wants/"$u" "$HOME/.config/systemd/user"/*.wants/"$b".timer \
           "$HOME/.config/systemd/user"/*.wants/"$b".path; do
    [ -L "$w" ] && return 0
  done
  return 1
}

_ativa_sistema() {
  local u="$1" b="${1%.*}" w
  for w in "$ETC/systemd/system"/*.wants/"$u" "$ETC/systemd/system"/*.wants/"$b".timer \
           "$ETC/systemd/system"/*.wants/"$b".path; do
    [ -L "$w" ] && return 0
  done
  return 1
}

_gatilhos_automaticos() {
  local f u cmd g e r b
  for f in "$HOME/.config/systemd/user"/*.service; do
    [ -f "$f" ] || continue
    u="$(basename "$f")"; case "$u" in meow-*) continue ;; esac
    b="${u%.service}"; g="systemd do usuário ($u)"
    [ -f "$HOME/.config/systemd/user/$b.timer" ] && g="systemd do usuário ($b.timer)"
    [ -f "$HOME/.config/systemd/user/$b.path" ] && g="systemd do usuário ($b.path)"
    if _ativa_usuario "$u"; then e="ativo"; else e="inativo"; g="${g%)}, desligada)"; fi
    cmd="$(sed -n 's/^Exec[A-Za-z]*=[-@+!:]*//p' "$f")"
    while IFS= read -r r; do [ -n "$r" ] && _seguir "$r" "$g" "$e"; done < <(printf '%s\n' "$cmd" | _refs "")
  done
  for f in "$ETC/systemd/system"/*.service; do
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    u="$(basename "$f")"; case "$u" in meow-*) continue ;; esac
    b="${u%.service}"; g="systemd do sistema ($u)"
    [ -f "$ETC/systemd/system/$b.timer" ] && g="systemd do sistema ($b.timer)"
    [ -f "$ETC/systemd/system/$b.path" ] && g="systemd do sistema ($b.path)"
    if _ativa_sistema "$u"; then e="ativo"; else e="inativo"; g="${g%)}, desligada)"; fi
    cmd="$(sed -n 's/^Exec[A-Za-z]*=[-@+!:]*//p' "$f")"
    while IFS= read -r r; do [ -n "$r" ] && _seguir "$r" "$g" "$e"; done < <(printf '%s\n' "$cmd" | _refs "")
  done
  for f in "$ETC/apt/apt.conf.d"/*; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in 99-meow-*) continue ;; esac
    grep -q 'Invoke' "$f" 2>/dev/null || continue
    cmd="$(grep -v '^[[:space:]]*//' "$f" | grep -oE '"[^"]+"')"
    g="apt ($(basename "$f"))"
    while IFS= read -r r; do [ -n "$r" ] && _seguir "$r" "$g" "ativo"; done < <(printf '%s\n' "$cmd" | _refs "")
  done
  for f in "$HOME/.config/autostart"/*.desktop; do
    [ -f "$f" ] || continue
    grep -q '^Hidden=true' "$f" && continue
    cmd="$(sed -n 's/^Exec=//p' "$f")"
    g="login (autostart $(basename "$f"))"
    while IFS= read -r r; do [ -n "$r" ] && _seguir "$r" "$g" "ativo"; done < <(printf '%s\n' "$cmd" | _refs "")
  done
  for f in "$(meow_cosmic_dir)/com.system76.CosmicSettings.Shortcuts"/v*/custom; do
    [ -f "$f" ] || continue
    cmd="$(grep -oE 'Spawn\("[^"]+"\)' "$f" | sed -E 's/^Spawn\("//; s/"\)$//')"
    while IFS= read -r r; do [ -n "$r" ] && _seguir "$r" "atalho de teclado" "ativo"; done < <(printf '%s\n' "$cmd" | _refs "")
  done
  cmd=""
  if [ -n "${VIZINHOS_CRONTAB:-}" ]; then
    [ -r "$VIZINHOS_CRONTAB" ] && cmd="$(grep -v '^[[:space:]]*#' "$VIZINHOS_CRONTAB")"
  elif command -v crontab >/dev/null 2>&1; then
    cmd="$(crontab -l 2>/dev/null | grep -v '^[[:space:]]*#')"
  fi
  while IFS= read -r r; do [ -n "$r" ] && _seguir "$r" "cron" "ativo"; done < <(printf '%s\n' "$cmd" | _refs "")
}

_funcoes() {
  local f
  [ -d "$ZD" ] || return 0
  for f in "$ZD"/aliases.zsh "$ZD"/functions/*.zsh; do
    [ -f "$f" ] || continue
    awk -v arq="$f" '
      fn == "" && match($0, /^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_:.-]*[[:space:]]*\(\)/) {
        s = substr($0, RSTART, RLENGTH); sub(/^[[:space:]]*(function[[:space:]]+)?/, "", s); sub(/[[:space:]]*\(\)$/, "", s)
        fn = s; ini = NR
        if ($0 ~ /}[[:space:]]*$/) { print fn "\t" arq "\t" ini "\t" NR; fn = "" }
        next
      }
      fn != "" && /^}/ { print fn "\t" arq "\t" ini "\t" NR; fn = "" }
    ' "$f"
  done
}

_arestas() {
  local funcs="$1"; shift
  RCS_LISTA="$(printf '%s\n' "$@")" awk -F'\t' '
    BEGIN { n = split(ENVIRON["RCS_LISTA"], r, "\n"); for (i = 1; i <= n; i++) if (r[i] != "") ehrc[r[i]] = 1 }
    FNR == NR { nome[$1] = 1; ini[$2 SUBSEP $3] = $1; fim[$2 SUBSEP $4] = 1; next }
    FNR == 1 { cur = ""; rc = (FILENAME in ehrc) }
    {
      if (!rc && ((FILENAME SUBSEP FNR) in ini)) cur = ini[FILENAME SUBSEP FNR]
      l = $0
      if (l ~ /^[[:space:]]*#/) { if (!rc && ((FILENAME SUBSEP FNR) in fim)) cur = ""; next }
      quem = cur
      if (rc) quem = "@login"
      else if (cur == "" && match(l, /^[[:space:]]*alias[[:space:]]+[A-Za-z0-9_-]+=/)) {
        quem = substr(l, RSTART, RLENGTH); sub(/^[[:space:]]*alias[[:space:]]+/, "", quem); sub(/=$/, "", quem)
        quem = "alias:" quem; l = substr(l, RSTART + RLENGTH)
      }
      if (quem != "") {
        n = split(l, w, /[^A-Za-z0-9_:.-]+/)
        for (i = 1; i <= n; i++) if ((w[i] in nome) && w[i] != cur) print quem "\t" w[i]
      }
      if (!rc && ((FILENAME SUBSEP FNR) in fim)) cur = ""
    }' "$funcs" "$ZD"/aliases.zsh "$ZD"/functions/*.zsh "$@" 2>/dev/null | sort -u
}

_corpo() { sed -n "${2},${3}p" "$1"; }

_gatilhos_do_shell() {
  local nome arq ini fim rc k g e via r quem alvo tmpf
  local -a LOGIN=() RCS=()
  declare -A NO_LOGIN=() CHAMA=() CHAMADO_POR=()
  tmpf="$(mktemp)" || return 0
  _funcoes > "$tmpf"
  while IFS=$'\t' read -r nome arq ini fim; do
    FUNC_ARQ[$nome]="$arq"; FUNC_INI[$nome]="$ini"; FUNC_FIM[$nome]="$fim"
  done < "$tmpf"
  for rc in "$ZD/.zshrc" "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc" "$HOME/.profile"; do
    [ -f "$rc" ] || continue
    case " ${RCS[*]:-} " in *" $rc "*) continue ;; esac
    RCS+=("$rc")
    _seguir "$rc" "login do shell ($(basename "$rc"))" "ativo"
  done
  if [ "${#FUNC_ARQ[@]}" -eq 0 ]; then rm -f "$tmpf"; return 0; fi
  while IFS=$'\t' read -r quem alvo; do
    CHAMA[$quem]="${CHAMA[$quem]:-} $alvo"
    case "$quem" in @login) ;; *) CHAMADO_POR[$alvo]="${CHAMADO_POR[$alvo]:-} ${quem#alias:}" ;; esac
  done < <(_arestas "$tmpf" "${RCS[@]}")
  rm -f "$tmpf"
  for alvo in ${CHAMA[@login]:-}; do LOGIN+=("$alvo"); done
  while [ "${#LOGIN[@]}" -gt 0 ]; do
    nome="${LOGIN[0]}"; LOGIN=("${LOGIN[@]:1}")
    [ -n "${NO_LOGIN[$nome]:-}" ] && continue
    NO_LOGIN[$nome]=1
    for alvo in ${CHAMA[$nome]:-}; do LOGIN+=("$alvo"); done
  done
  for nome in "${!FUNC_ARQ[@]}"; do
    arq="${FUNC_ARQ[$nome]}"; ini="${FUNC_INI[$nome]}"; fim="${FUNC_FIM[$nome]}"
    k="$arq::$nome"
    via="$(printf '%s\n' ${CHAMADO_POR[$nome]:-} | sed '/^$/d' | sort -u | paste -sd, - | sed 's/,/, /g')"
    if [ -n "${NO_LOGIN[$nome]:-}" ]; then g="login do shell"; e="ativo"; else g="à mão"; e="à mão"; fi
    [ -n "$via" ] && g="$g (via $via)"
    _marcar "$k" "$arq" "$ini" "$fim" "$g" "$e"
    while IFS= read -r r; do
      [ -n "$r" ] && _seguir "$r" "${g%% (*} (via $nome)" "$e"
    done < <(_corpo "$arq" "$ini" "$fim" | grep -v '^[[:space:]]*#' | _refs "$arq")
  done
}

_repos() {
  local padrao d f real via
  declare -A VIA=()
  [ -d "$DESENV" ] || return 0
  for padrao in $REPOS; do
    for d in "$DESENV"/$padrao; do
      [ -d "$d" ] || continue
      real="$(readlink -f "$d")"
      case "$real" in "$(readlink -f "$ZD" 2>/dev/null)"|"$MEOW_LIDO"|"$RAIZ") continue ;; esac
      VIA=()
      while IFS=$'\t' read -r f via; do VIA[$f]="$via"; done < <(
        grep -roE --include='*.sh' --include='*.py' --include='*.zsh' --exclude-dir=.git --exclude-dir=tests \
             --exclude-dir=docs --exclude-dir=node_modules --exclude-dir=venv --exclude-dir=.venv \
             '[A-Za-z0-9_.-]+[.](sh|py|zsh)' "$real" 2>/dev/null \
          | awk -F: '{ n = split($1, p, "/"); q = p[n]; if (q != $2) print $2 "\t" q }' | sort -u \
          | awk -F'\t' '{ v[$1] = (v[$1] == "" ? $2 : v[$1] ", " $2) } END { for (k in v) print k "\t" v[k] }')
      while IFS= read -r f; do
        [ -n "${UNID[$f]:-}" ] && continue
        _texto "$f" || continue
        via="${VIA[$(basename "$f")]:-}"
        if [ -n "$via" ]; then _marcar "$f" "$f" 1 0 "à mão (via $via)" "à mão"; else _marcar "$f" "$f" 1 0 "à mão" "à mão"; fi
      done < <(find "$real" -maxdepth 4 \( -name .git -o -name node_modules -o -name venv -o -name .venv \
                 -o -name tests -o -name test -o -name docs -o -name dist -o -name releases -o -name upstream \
                 -o -name __pycache__ -o -name target -o -name build \) -prune -o -type f \
                 \( -name '*.sh' -o -name '*.py' -o -name '*.zsh' \) -print 2>/dev/null | sort)
    done
  done
}

_meow_escreve() {
  local f
  for f in "$MEOW_LIDO/bin/meow" "$MEOW_LIDO/install.sh" "$MEOW_LIDO"/lib/*.sh "$MEOW_LIDO"/scripts/*.sh "$MEOW_LIDO"/scripts/*.py; do
    [ -f "$f" ] && printf 'meow\t%s\t1\t0\n' "$f"
  done | _varrer | cut -f2 | sort -u
}

_linhas() {
  local k
  _gatilhos_automaticos
  _gatilhos_do_shell
  [ "${VIZ_SO_AUTO:-0}" = 1 ] || _repos
  local meow; meow="$(_meow_escreve)"
  for k in "${!UNID[@]}"; do printf '%s\t%s\n' "$k" "${UNID[$k]}"; done | _varrer \
    | awk -F'\t' '{ c = $1 "\t" $2; n[c]++; m[c] += $3 } END { for (c in n) print c "\t" (m[c] == n[c] ? "desativado" : "vivo") }' \
    | while IFS=$'\t' read -r k terr vivo; do
        local esc est m
        case "$k" in
          *::*) esc="$(_curto "${k%%::*}"): ${k##*::}()" ;;
          *)    esc="$(_curto "$k")" ;;
        esac
        est="${EST[$k]}"; [ "$vivo" = "desativado" ] && est="desativado"
        if printf '%s\n' "$meow" | grep -qxF -- "$terr"; then m="sim"; else m="não"; fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$terr" "$esc" "$(printf '%s' "${GAT[$k]}" | tr ';' '\n' | sort -u | paste -sd';' - | sed 's/;/; /g')" "$est" "$m"
      done | sort -u
}

cmd_inventario() {
  local linhas n ativos desat dup auto
  linhas="$(_linhas)"
  printf '# vizinhos: quem mais escreve onde o MeowSystem escreve\n'
  printf '# casa: ~ · MeowSystem lido em: %s\n' "$(_curto "$MEOW_LIDO")"
  printf 'responsabilidade\tescritor\tgatilho\testado\tmeow\n'
  [ -n "$linhas" ] && printf '%s\n' "$linhas"
  n=0; ativos=0; desat=0; dup=0; auto=0
  if [ -n "$linhas" ]; then
    n="$(printf '%s\n' "$linhas" | wc -l)"
    ativos="$(printf '%s\n' "$linhas" | awk -F'\t' '$4 == "ativo"' | wc -l)"
    desat="$(printf '%s\n' "$linhas" | awk -F'\t' '$4 == "desativado"' | wc -l)"
    dup="$(printf '%s\n' "$linhas" | awk -F'\t' '$5 == "sim" && ($4 == "ativo" || $4 == "à mão")' | wc -l)"
    auto="$(printf '%s\n' "$linhas" | awk -F'\t' '$5 == "sim" && $4 == "ativo"' | wc -l)"
  fi
  printf '# escritas: %s · por gatilho automático: %s · desativadas: %s · com o MeowSystem no mesmo território: %s (automáticas: %s)\n' \
    "$n" "$ativos" "$desat" "$dup" "$auto"
}

_duplicatas_auto() {
  VIZ_SO_AUTO=1 _linhas | awk -F'\t' '$5 == "sim" && $4 == "ativo" { print $1 "\t" $2 }' | sort -u
}

cmd_revisado() {
  mkdir -p "$ESTADO" || return "$MEOW_ERRO"
  _duplicatas_auto > "$REVISADOS.novo" && mv -f "$REVISADOS.novo" "$REVISADOS"
  meow_ok "$(wc -l < "$REVISADOS") duplicata(s) automática(s) guardada(s) como revisadas"
}

cmd_conferir() {
  local hoje novas n primeira
  hoje="$(_duplicatas_auto)"
  if [ -z "$hoje" ]; then
    meow_ok "nenhum outro programa escreve sozinho onde o MeowSystem escreve"
    return "$MEOW_OK"
  fi
  if [ -r "$REVISADOS" ]; then
    novas="$(printf '%s\n' "$hoje" | grep -vxF -f "$REVISADOS")"
  else
    novas="$hoje"
  fi
  if [ -z "$novas" ]; then
    meow_ok "$(printf '%s\n' "$hoje" | wc -l) escrita(s) de outro programa no território do MeowSystem, todas já revisadas"
    return "$MEOW_OK"
  fi
  n="$(printf '%s\n' "$novas" | wc -l)"
  primeira="$(printf '%s\n' "$novas" | head -1)"
  meow_pula "$n duplicata(s) nova(s) com o MeowSystem: ${primeira%%$'\t'*} por ${primeira#*$'\t'}"
  printf '%s\n' "$novas" | tail -n +2 | while IFS=$'\t' read -r t e; do meow_info "  $t por $e"; done
  return 4
}

_catalogo() {
  [ -r "$CONTRATO" ] || return 0
  awk -F'\t' -v desenv="$DESENV" -v zd="$ZD" -v apps="$APPS_CASA" -v uni="$UNI" -v sbin="$SBIN" '
    function expandir(c) {
      if (index(c, "$DESENV/") == 1) return desenv substr(c, 8)
      if (index(c, "$ZD/") == 1) return zd substr(c, 4)
      if (index(c, "$APPS/") == 1) return apps substr(c, 6)
      if (index(c, "$UNI/") == 1) return uni substr(c, 5)
      if (index(c, "$SBIN/") == 1) return sbin substr(c, 6)
      return c
    }
    $1 != "item" { next }
    {
      linha = $2 "|" $3 "|" expandir($4)
      for (i = 5; i <= 8; i++) {
        v = ($i == "-" ? "" : $i)
        if (i == 6 && $3 == "unidade") v = expandir(v)
        linha = linha "|" v
      }
      print linha
    }' "$CONTRATO"
}

_item() { _catalogo | awk -F'|' -v i="$1" '$1 == i'; }

_requer_ok() {
  local req="$1" so_build=0 arq
  case "$req" in build:*) so_build=1; req="${req#build:}" ;; esac
  arq="${req%%:*}"
  case "$arq" in
    '$HOME/'*) arq="$HOME/${arq#\$HOME/}" ;;
    *) arq="$MEOW_LIDO/$arq" ;;
  esac
  grep -qF -- "${req#*:}" "$arq" 2>/dev/null || return 1
  [ "$so_build" = 1 ] || return 0
  _shim_usa_build "$arq"
}

_shim_usa_build() {
  local fabrica="${MEOW_SHIM_FABRICA:-/usr/bin/cosmic-comp}" usa
  usa="$(MEOW_SHIM_SO_DIZER=1 bash "$1" 2>/dev/null)"
  [ -n "$usa" ] && [ "$usa" != "$fabrica" ] && [ -x "$usa" ]
}

_marca_saida() { printf '#vizinhos+:%s#' "$1"; }
_marca_bloco() { printf '#vizinhos:%s# ' "$1"; }

_ultimo() {
  [ -r "$REGISTRO" ] || return 0
  awk -F'\t' -v i="$1" 'NR > 1 && $2 == i { a = $6; c = $5 } END { if (a != "") print a "\t" c }' "$REGISTRO"
}

_desativado() {
  case "$1" in
    saida) grep -qF -- "$(_marca_saida "$3")" "$2" 2>/dev/null ;;
    bloco) grep -qF -- "$(_marca_bloco "$3")" "$2" 2>/dev/null ;;
    mover|unidade) local u; u="$(_ultimo "$3")"
           [ ! -e "$2" ] && [ "${u%%$'\t'*}" = "desativado" ] && [ -e "${u#*$'\t'}" ] ;;
    *) return 1 ;;
  esac
}

_estado() {
  local item="$1" tipo="$2" arq="$3" ini="$4" fim="$5" req="$6" n u
  if _desativado "$tipo" "$arq" "$item"; then echo desativado; return 0; fi
  [ -f "$arq" ] || { echo ausente; return 0; }
  if [ -n "$req" ] && ! _requer_ok "$req"; then echo espera; return 0; fi
  u="$(_ultimo "$item")"
  [ "${u%%$'\t'*}" = "restaurado" ] && { echo restaurado; return 0; }
  case "$tipo" in
    bloco)
      n="$(grep -cF -- "$ini" "$arq" 2>/dev/null)"
      [ "${n:-0}" = 0 ] && { echo mudou; return 0; }
      [ "$n" -gt 1 ] && { echo repetido; return 0; } ;;
    unidade)
      grep -qF -- "$(_marca_bloco "$ini")" "$fim" 2>/dev/null || { echo esperando; return 0; } ;;
  esac
  echo pronto
}

_estado_dito() {
  case "$1" in
    desativado) echo "desativado" ;;
    ausente)    echo "não existe nesta casa" ;;
    espera)     echo "espera o MeowSystem instalado cuidar disto" ;;
    restaurado) echo "ativo, devolvido por você" ;;
    mudou)      echo "o trecho não está mais lá" ;;
    repetido)   echo "o trecho não é único" ;;
    esperando)  echo "esperando a Aurora ler o corte" ;;
    *)          echo "ativo" ;;
  esac
}

cmd_listar() {
  local item tipo arq ini fim req motivo
  printf 'item\testado\tarquivo\n'
  while IFS='|' read -r item tipo arq ini fim req motivo; do
    printf '%s\t%s\t%s\n' "$item" "$(_estado_dito "$(_estado "$item" "$tipo" "$arq" "$ini" "$fim" "$req")")" "$(_curto "$arq")"
  done < <(_catalogo)
}

cmd_prontos() {
  local item tipo arq ini fim req motivo est prontos=()
  while IFS='|' read -r item tipo arq ini fim req motivo; do
    est="$(_estado "$item" "$tipo" "$arq" "$ini" "$fim" "$req")"
    case "$est" in
      pronto) prontos+=("$item") ;;
      esperando|mudou|repetido) meow_info "  $item: $(_estado_dito "$est")" ;;
    esac
  done < <(_catalogo)
  if [ "${#prontos[@]}" -eq 0 ]; then
    meow_ok "nenhum vizinho repete o que o MeowSystem instalado já faz"
    return "$MEOW_OK"
  fi
  meow_muda "${#prontos[@]} trecho(s) de vizinho repetem o que o MeowSystem instalado já faz: $(printf '%s\n' "${prontos[@]}" | paste -sd, - | sed 's/,/, /g')"
  return "$MEOW_DIVERGENTE"
}

cmd_desativar_prontos() {
  local item tipo arq ini fim req motivo est rc pior=0
  if [ "${VIZINHOS_DESATIVAR:-sim}" != "sim" ]; then
    meow_pula "VIZINHOS_DESATIVAR=\"${VIZINHOS_DESATIVAR:-}\" — o MeowSystem não desliga nada nos vizinhos"
    return "$MEOW_OK"
  fi
  while IFS='|' read -r item tipo arq ini fim req motivo; do
    est="$(_estado "$item" "$tipo" "$arq" "$ini" "$fim" "$req")"
    case "$est" in
      pronto) cmd_desativar "$item"; rc=$? ;;
      esperando) meow_info "$item: $(_estado_dito "$est")"; continue ;;
      *) continue ;;
    esac
    [ "$rc" -gt "$pior" ] && pior="$rc"
  done < <(_catalogo)
  return "$pior"
}

_sintaxe_ok() {
  case "$2" in
    *.sh)  bash -n "$1" 2>/dev/null ;;
    *.zsh) command -v zsh >/dev/null 2>&1 || return 0; zsh -n "$1" 2>/dev/null ;;
    *) return 0 ;;
  esac
}

_wants_da_unidade() {
  local w
  for w in "$UNI"/*.wants/"$1"; do [ -L "$w" ] && printf '%s\n' "$w"; done
}

_desativar_unidade() {
  local item="$1" arq="$2" ini="$3" fim="$4" nome copia svc w
  nome="$(basename "$arq")"; svc="${arq%.*}.service"
  if ! grep -qF -- "$(_marca_bloco "$ini")" "$fim" 2>/dev/null; then
    meow_info "$item: esperando a Aurora ler o corte ($(_curto "$fim"))"
    return "$MEOW_OK"
  fi
  systemctl --user disable --now "$nome" >/dev/null 2>&1
  copia="$COPIAS/$item/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$copia" && mv -- "$arq" "$copia/" || { meow_erro "não consegui mover $(_curto "$arq") — nada foi mudado"; return "$MEOW_ERRO"; }
  [ -f "$svc" ] && mv -- "$svc" "$copia/"
  while IFS= read -r w; do rm -f -- "$w"; done < <(_wants_da_unidade "$nome")
  systemctl --user daemon-reload >/dev/null 2>&1
  _registrar "$item" "unidade" "$arq" "$copia" "desativado"
  meow_muda "$item: $nome desligada e guardada em $(_curto "$copia")"
  return "$MEOW_DIVERGENTE"
}

_restaurar_unidade() {
  local item="$1" arq="$2" u copia f
  u="$(_ultimo "$item")"
  [ "${u%%$'\t'*}" = "desativado" ] || { meow_ok "$item já estava ativo"; return "$MEOW_OK"; }
  copia="${u#*$'\t'}"
  if [ -e "$arq" ]; then
    meow_aviso "$item: $(_curto "$arq") voltou a existir — a cópia fica em $(_curto "$copia")"
    return "$MEOW_OK"
  fi
  mkdir -p "$(dirname "$arq")" || return "$MEOW_ERRO"
  for f in "$copia"/*; do
    [ -e "$f" ] || continue
    mv -- "$f" "$(dirname "$arq")/" || { meow_erro "não consegui devolver $(basename "$f")"; return "$MEOW_ERRO"; }
  done
  systemctl --user daemon-reload >/dev/null 2>&1
  systemctl --user enable --now "$(basename "$arq")" >/dev/null 2>&1 \
    || meow_aviso "$item: $(basename "$arq") voltou ao lugar, e o systemd não a religou agora"
  _registrar "$item" "unidade" "$arq" "" "restaurado"
  meow_muda "$item restaurado em $(_curto "$arq")"
  return "$MEOW_DIVERGENTE"
}

_registrar() {
  mkdir -p "$ESTADO" || return 1
  [ -f "$REGISTRO" ] || printf 'data\titem\ttipo\tarquivo\tcopia\tacao\n' > "$REGISTRO"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$1" "$2" "$3" "$4" "$5" >> "$REGISTRO"
}

_largar_copia() {
  local dir
  dir="$(dirname "$1")"
  rm -rf -- "$dir"
  rmdir -- "$(dirname "$dir")" 2>/dev/null
  return 0
}

_guardar() {
  local dest
  dest="$COPIAS/$1/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$dest" && cp -a -- "$2" "$dest/" && printf '%s/%s' "$dest" "$(basename "$2")"
}

cmd_desativar() {
  local alvo="${1:-}" item tipo arq ini fim req motivo copia nome tmp marca
  [ -n "$alvo" ] || { meow_erro "qual item? (os nomes estão no --listar)"; return "$MEOW_ERRO"; }
  IFS='|' read -r item tipo arq ini fim req motivo < <(_item "$alvo")
  [ -n "${item:-}" ] || { meow_erro "não conheço o item '$alvo'"; return "$MEOW_ERRO"; }
  if _desativado "$tipo" "$arq" "$item"; then meow_ok "$item já estava desativado"; return "$MEOW_OK"; fi
  if [ ! -f "$arq" ]; then meow_pula "$item: $(_curto "$arq") não existe nesta casa — nada a desativar"; return "$MEOW_OK"; fi
  if [ -n "$req" ] && ! _requer_ok "$req"; then
    meow_pula "$item espera: o MeowSystem instalado ainda não cuida disto sozinho, e o de fora continua"
    return "$MEOW_OK"
  fi
  if [ "$tipo" = "unidade" ]; then _desativar_unidade "$item" "$arq" "$ini" "$fim"; return $?; fi
  if [ "$tipo" = "bloco" ]; then
    local vezes; vezes="$(grep -cF -- "$ini" "$arq" 2>/dev/null)"
    [ "${vezes:-0}" = 0 ] && { meow_erro "$item: o trecho não está mais em $(_curto "$arq") — nada foi mudado"; return "$MEOW_ERRO"; }
    [ "$vezes" -gt 1 ] && { meow_erro "$item: o trecho não é único em $(_curto "$arq") ($vezes vezes) — nada foi mudado"; return "$MEOW_ERRO"; }
  fi
  if [ "$tipo" = "mover" ]; then
    copia="$COPIAS/$item/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$copia" && mv -- "$arq" "$copia/" || { meow_erro "não consegui mover $(_curto "$arq") — nada foi mudado"; return "$MEOW_ERRO"; }
    copia="$copia/$(basename "$arq")"
    _registrar "$item" "$tipo" "$arq" "$copia" "desativado"
    meow_muda "$item: $(_curto "$arq") saiu do lugar (guardado em $(_curto "$copia"))"
    return "$MEOW_DIVERGENTE"
  fi
  [ -w "$arq" ] || { meow_erro "sem permissão de escrita em $(_curto "$arq")"; return "$MEOW_ERRO"; }
  copia="$(_guardar "$item" "$arq")" || { meow_erro "a cópia de antes falhou — nada foi mudado"; return "$MEOW_ERRO"; }
  tmp="$(mktemp "$arq.vizinhos.XXXXXX")" || return "$MEOW_ERRO"
  case "$tipo" in
    saida)
      nome="$(basename "$arq")"; marca="$(_marca_saida "$item")"
      LINHA="printf '%s\\n' \"$nome: $motivo\"; exit 0  $marca" \
        awk 'BEGIN { l = ENVIRON["LINHA"] } NR == 1 && /^#!/ { print; print l; next } NR == 1 { print l } { print }' "$arq" > "$tmp" ;;
    bloco)
      marca="$(_marca_bloco "$item")"
      INI="$ini" FIM_RE="$fim" M="$marca" awk 'BEGIN { ini = ENVIRON["INI"]; fim = ENVIRON["FIM_RE"]; m = ENVIRON["M"] }
        !dentro && !feito && index($0, ini) { dentro = 1 }
        dentro { print m $0; if (fim == "" || ($0 ~ fim && !index($0, ini))) { dentro = 0; feito = 1 }; next }
        { print }
        END { if (dentro) exit 3 }' "$arq" > "$tmp"
      if [ $? = 3 ]; then rm -f "$tmp"; _largar_copia "$copia"; meow_erro "$item: o fim do trecho não aparece em $(_curto "$arq") — nada foi mudado"; return "$MEOW_ERRO"; fi
      if ! grep -qF -- "$marca" "$tmp"; then rm -f "$tmp"; _largar_copia "$copia"; meow_erro "$item: o trecho não está mais em $(_curto "$arq") — nada foi mudado"; return "$MEOW_ERRO"; fi ;;
  esac
  if ! _sintaxe_ok "$tmp" "$arq"; then
    rm -f "$tmp"; _largar_copia "$copia"
    meow_erro "$item: o corte quebraria a leitura de $(_curto "$arq") — nada foi mudado"
    return "$MEOW_ERRO"
  fi
  chmod --reference="$arq" "$tmp" 2>/dev/null
  mv -f "$tmp" "$arq" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  _registrar "$item" "$tipo" "$arq" "$copia" "desativado"
  meow_muda "$item desativado em $(_curto "$arq") (cópia de antes: $(_curto "$copia"))"
  return "$MEOW_DIVERGENTE"
}

_restaurar_um() {
  local alvo="$1" item tipo arq ini fim req motivo tmp marca
  IFS='|' read -r item tipo arq ini fim req motivo < <(_item "$alvo")
  [ -n "${item:-}" ] || { meow_erro "não conheço o item '$alvo'"; return "$MEOW_ERRO"; }
  if [ "$tipo" = "unidade" ]; then _restaurar_unidade "$item" "$arq"; return $?; fi
  if [ "$tipo" = "mover" ]; then
    local u; u="$(_ultimo "$item")"
    [ "${u%%$'\t'*}" = "desativado" ] || { meow_ok "$item já estava ativo"; return "$MEOW_OK"; }
    if [ -e "$arq" ]; then
      meow_aviso "$item: $(_curto "$arq") voltou a existir — a cópia fica em $(_curto "${u#*$'\t'}")"
      return "$MEOW_OK"
    fi
    mkdir -p "$(dirname "$arq")" && mv -- "${u#*$'\t'}" "$arq" || { meow_erro "não consegui devolver $(_curto "$arq")"; return "$MEOW_ERRO"; }
    _registrar "$item" "$tipo" "$arq" "" "restaurado"
    meow_muda "$item restaurado em $(_curto "$arq")"
    return "$MEOW_DIVERGENTE"
  fi
  if [ ! -f "$arq" ] || ! _desativado "$tipo" "$arq" "$item"; then meow_ok "$item já estava ativo"; return "$MEOW_OK"; fi
  tmp="$(mktemp "$arq.vizinhos.XXXXXX")" || return "$MEOW_ERRO"
  case "$tipo" in
    saida) marca="$(_marca_saida "$item")"; grep -vF -- "$marca" "$arq" > "$tmp" ;;
    bloco) marca="$(_marca_bloco "$item")"
           M="$marca" awk 'BEGIN { m = ENVIRON["M"] } index($0, m) == 1 { print substr($0, length(m) + 1); next } { print }' "$arq" > "$tmp" ;;
  esac
  chmod --reference="$arq" "$tmp" 2>/dev/null
  mv -f "$tmp" "$arq" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  _registrar "$item" "$tipo" "$arq" "" "restaurado"
  meow_muda "$item restaurado em $(_curto "$arq")"
  return "$MEOW_DIVERGENTE"
}

cmd_restaurar() {
  local alvo="${1:-}" item pior=0 rc
  [ -n "$alvo" ] || { meow_erro "qual item? (ou: todos)"; return "$MEOW_ERRO"; }
  if [ "$alvo" != "todos" ]; then _restaurar_um "$alvo"; return $?; fi
  [ -r "$REGISTRO" ] || { meow_ok "nada foi desativado nesta casa"; return "$MEOW_OK"; }
  while IFS= read -r item; do
    _restaurar_um "$item"; rc=$?
    [ "$rc" -gt "$pior" ] && pior="$rc"
  done < <(awk -F'\t' 'NR > 1 { ult[$2] = $6; ord[$2] = NR } END { for (i in ult) if (ult[i] == "desativado") print ord[i] "\t" i }' "$REGISTRO" \
             | sort -rn | cut -f2)
  return "$pior"
}

case "${1:-}" in
  --inventario) cmd_inventario ;;
  --conferir)   cmd_conferir ;;
  --revisado)   cmd_revisado ;;
  --listar)     cmd_listar ;;
  --prontos)    cmd_prontos ;;
  --desativar)  cmd_desativar "${2:-}" ;;
  --desativar-prontos) cmd_desativar_prontos ;;
  --restaurar)  cmd_restaurar "${2:-}" ;;
  -h|--help|'')
    sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    [ -n "${1:-}" ] || exit "$MEOW_ERRO" ;;
  *) meow_erro "opção desconhecida: $1"; exit "$MEOW_ERRO" ;;
esac

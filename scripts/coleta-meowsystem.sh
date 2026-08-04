#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# coleta-meowsystem.sh — inventário READ-ONLY do seu COSMIC pro ricing
#
#   Uso:  bash coleta-meowsystem.sh
#         bash coleta-meowsystem.sh ~/meu-inventario.md
#
# Não escreve, não instala, não altera NADA do sistema. Só lê e gera um .md.
# Depois: anexe o arquivo gerado na conversa.
# ---------------------------------------------------------------------------
set -uo pipefail

OUT="${1:-$HOME/meowsystem-inventario-$(date +%Y%m%d-%H%M).md}"
: > "$OUT"

sec()  { printf '\n\n## %s\n' "$*" >> "$OUT"; }
sub()  { printf '\n### %s\n' "$*" >> "$OUT"; }
note() { printf '%s\n' "$*" >> "$OUT"; }
open_fence()  { printf '\n```%s\n' "${1:-}" >> "$OUT"; }
close_fence() { printf '```\n' >> "$OUT"; }

# roda um comando com timeout, sem quebrar o script se faltar o binário
run() {
  local label="$1"; shift
  sub "$label"
  if ! command -v "$1" >/dev/null 2>&1; then
    note "_(binário \`$1\` não encontrado)_"
    return
  fi
  open_fence
  timeout 15 "$@" >> "$OUT" 2>&1 || note "[comando falhou ou expirou: $*]"
  close_fence
}

# despeja arquivos de config pequenos (path + conteúdo)
dump_tree() {
  local root="$1" maxbytes="${2:-8192}"
  [ -d "$root" ] || { note "_(não existe: $root)_"; return; }
  local f size
  while IFS= read -r f; do
    size=$(stat -c%s "$f" 2>/dev/null || echo 0)
    printf '\n**%s**  (%s bytes)\n' "${f/#$HOME/~}" "$size" >> "$OUT"
    if [ "$size" -gt "$maxbytes" ]; then
      note '```'
      head -c "$maxbytes" "$f" >> "$OUT" 2>/dev/null
      printf '\n... [truncado]\n' >> "$OUT"
      note '```'
    else
      note '```ron'
      cat "$f" >> "$OUT" 2>/dev/null
      printf '\n' >> "$OUT"
      note '```'
    fi
  done < <(find "$root" -type f 2>/dev/null | sort)
}

# lista Name= / Icon= de todos os .desktop de um diretório
dump_desktops() {
  local dir="$1"
  [ -d "$dir" ] || { note "_(não existe: $dir)_"; return; }
  open_fence
  local d name icon nodisp
  while IFS= read -r d; do
    name=$(grep -m1 '^Name=' "$d" 2>/dev/null | cut -d= -f2-)
    icon=$(grep -m1 '^Icon=' "$d" 2>/dev/null | cut -d= -f2-)
    nodisp=$(grep -m1 '^NoDisplay=' "$d" 2>/dev/null | cut -d= -f2-)
    printf '%-52s | Name=%-34s | Icon=%s%s\n' \
      "$(basename "$d")" "${name:--}" "${icon:--}" \
      "$( [ "${nodisp,,}" = "true" ] && echo '  [NoDisplay]' )" >> "$OUT"
  done < <(find "$dir" -maxdepth 1 -name '*.desktop' 2>/dev/null | sort)
  close_fence
}

# ===========================================================================
{
  printf '# Inventário MeowSystem — %s\n' "$(date '+%d/%m/%Y %H:%M')"
  printf '\nGerado por `coleta-meowsystem.sh` (somente leitura).\n'
} >> "$OUT"

# --- 1. Sistema -------------------------------------------------------------
sec '1. Sistema e sessão'
open_fence
{
  echo "host:            $(hostname)"
  echo "usuário:         $USER"
  echo "shell:           $SHELL  (ZDOTDIR=${ZDOTDIR:-<vazio>})"
  echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-<vazio>}"
  echo "XDG_SESSION_TYPE:    ${XDG_SESSION_TYPE:-<vazio>}"
  echo "XDG_SESSION_DESKTOP: ${XDG_SESSION_DESKTOP:-<vazio>}"
  echo "QT_QPA_PLATFORMTHEME: ${QT_QPA_PLATFORMTHEME:-<vazio>}"
  echo "GTK_THEME:            ${GTK_THEME:-<vazio>}"
  echo "LANG:            ${LANG:-}"
  echo "locale numérico: $(locale 2>/dev/null | tr '\n' ' ')"
} >> "$OUT" 2>&1
close_fence
run 'os-release' cat /etc/os-release
run 'kernel'     uname -a
run 'monitores (cosmic-randr)' cosmic-randr list

# --- 2. Versões do COSMIC ---------------------------------------------------
sec '2. Versões do COSMIC e pacotes relacionados'
sub 'dpkg — pacotes cosmic*'
open_fence
dpkg -l 2>/dev/null | awk '/cosmic/ {printf "%-12s %-42s %s\n", $1, $2, $3}' >> "$OUT"
close_fence
sub 'dpkg — temas/ícones/cursores instalados via apt'
open_fence
dpkg -l 2>/dev/null | awk '/(icon-theme|theme|cursor)/ {printf "%-42s %s\n", $2, $3}' >> "$OUT"
close_fence
run 'cosmic-settings --help (existe CLI de tema?)' cosmic-settings --help
run 'cosmic-comp (versão via pacote)' dpkg -s cosmic-comp
run 'flatpak — apps'  flatpak list --app --columns=application,name,version,origin
run 'flatpak — overrides globais' flatpak override --show
run 'snap' snap list

# --- 3. Configuração do COSMIC (o coração) ---------------------------------
sec '3. ~/.config/cosmic — configuração completa'
note 'Cada arquivo é um valor RON isolado. Isto é a fonte da verdade do seu rice.'
open_fence
find "$HOME/.config/cosmic" -type f 2>/dev/null | wc -l >> "$OUT"
close_fence
dump_tree "$HOME/.config/cosmic"

sec '4. /usr/share/cosmic — defaults do sistema (só nomes)'
open_fence
find /usr/share/cosmic -type f 2>/dev/null | sed 's|/usr/share/cosmic/||' | sort >> "$OUT"
close_fence

sec '5. Estado local (~/.local/state/cosmic, se existir)'
open_fence
find "$HOME/.local/state" -maxdepth 3 -iname '*cosmic*' 2>/dev/null | sort >> "$OUT"
close_fence

# --- 6. Temas / ícones / cursores ------------------------------------------
sec '6. Temas, ícones e cursores disponíveis'
sub 'diretórios de ícones'
open_fence
for d in /usr/share/icons ~/.local/share/icons ~/.icons \
         /var/lib/flatpak/exports/share/icons ~/.local/share/flatpak/exports/share/icons; do
  [ -d "$d" ] && ls -1 "$d" 2>/dev/null | sed "s|^|$d/|"
done >> "$OUT" 2>&1
close_fence
sub 'index.theme dos temas de ícone locais (herança)'
open_fence
for f in ~/.local/share/icons/*/index.theme ~/.icons/*/index.theme; do
  [ -f "$f" ] || continue
  echo "== $f"
  grep -E '^(Name|Inherits|Directories)=' "$f" | cut -c1-400
  echo
done >> "$OUT" 2>&1
close_fence
sub 'temas GTK / cursores'
open_fence
for d in /usr/share/themes ~/.local/share/themes ~/.themes; do
  [ -d "$d" ] && ls -1 "$d" 2>/dev/null | sed "s|^|$d/|"
done >> "$OUT" 2>&1
echo
echo "-- cursores --"
for d in /usr/share/icons ~/.local/share/icons ~/.icons; do
  [ -d "$d" ] && find "$d" -maxdepth 2 -name cursor.theme -o -maxdepth 2 -type d -name cursors 2>/dev/null
done >> "$OUT" 2>&1
close_fence
run 'gsettings (GTK legado, se aplicável)' bash -c \
  'for k in icon-theme gtk-theme cursor-theme font-name monospace-font-name color-scheme; do
     printf "%-22s %s\n" "$k" "$(gsettings get org.gnome.desktop.interface $k 2>/dev/null)"; done'
sub 'configs GTK3/GTK4 (o COSMIC escreve aqui quando o tema global está ligado)'
open_fence
for f in ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini \
         ~/.config/gtk-3.0/gtk.css ~/.config/gtk-4.0/gtk.css \
         ~/.config/gtk-4.0/cosmic.css ~/.config/gtk-3.0/cosmic.css; do
  [ -f "$f" ] && { echo "== ${f/#$HOME/~}  ($(stat -c%s "$f") bytes)"; head -c 1200 "$f"; echo; echo; }
done >> "$OUT" 2>&1
close_fence

# --- 7. Fontes -------------------------------------------------------------
sec '7. Fontes'
open_fence
fc-list 2>/dev/null | grep -iE 'nerd|jetbrains|fira|noto sans mono|cascadia|maple|iosevka' \
  | sed 's/.*: //' | sort -u | head -60 >> "$OUT"
close_fence

# --- 8. Aplicativos e ícones ----------------------------------------------
sec '8. Inventário de .desktop (Name / Icon)'
sub '/usr/share/applications'
dump_desktops /usr/share/applications
sub '~/.local/share/applications'
dump_desktops "$HOME/.local/share/applications"
sub 'flatpak (sistema)'
dump_desktops /var/lib/flatpak/exports/share/applications
sub 'flatpak (usuário)'
dump_desktops "$HOME/.local/share/flatpak/exports/share/applications"

sec '9. Applets do painel/dock instalados'
open_fence
for d in /usr/share/applications ~/.local/share/applications; do
  [ -d "$d" ] || continue
  grep -lE 'X-CosmicApplet=true|CosmicApplet' "$d"/*.desktop 2>/dev/null | while read -r f; do
    printf '%-58s %s\n' "$(basename "$f")" "$(grep -m1 '^Icon=' "$f" | cut -d= -f2-)"
  done
done >> "$OUT" 2>&1
close_fence

# --- 10. Wallpapers --------------------------------------------------------
sec '10. Wallpapers'
open_fence
for d in /usr/share/backgrounds ~/.local/share/backgrounds ~/Imagens ~/Pictures ~/Wallpapers; do
  [ -d "$d" ] && { echo "== $d"; find "$d" -maxdepth 2 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.mp4' \) \
    2>/dev/null | head -40; echo; }
done >> "$OUT" 2>&1
close_fence

# --- 11. Terminal / shell / CLI --------------------------------------------
sec '11. Terminal, shell e ferramentas de linha de comando'
open_fence
find "$HOME/.config" "$HOME/.local/share" -maxdepth 3 -iname '*cosmic-term*' 2>/dev/null >> "$OUT"
close_fence
open_fence
for b in kitty alacritty zsh starship fastfetch bat btop eza fzf delta lutgen whiskers rsvg-convert magick convert inkscape gtk-update-icon-cache; do
  printf '%-22s %s\n' "$b" "$(command -v "$b" 2>/dev/null || echo '—')"
done >> "$OUT" 2>&1
close_fence
sub 'configs de tema já existentes desses apps'
open_fence
for f in ~/.config/kitty/kitty.conf ~/.config/kitty/current-theme.conf \
         ~/.config/fastfetch/config.jsonc ~/.config/bat/config ~/.config/btop/btop.conf \
         ~/.config/starship.toml; do
  [ -f "$f" ] && { echo "== ${f/#$HOME/~}"; grep -vE '^\s*(#|$)' "$f" | head -25; echo; }
done >> "$OUT" 2>&1
close_fence
sub 'paleta usada no zsh do Andromeda-OS'
open_fence
for f in "${ZDOTDIR:-$HOME/.config/zsh}/functions/_helpers.zsh"; do
  [ -f "$f" ] && grep -inE '#[0-9a-f]{6}|\\033\[|tput|dracula|catppuccin' "$f" | head -40
done >> "$OUT" 2>&1
close_fence

# --- 12. Automação existente ----------------------------------------------
sec '12. Automação já instalada'
run 'systemd --user: timers' systemctl --user list-timers --all --no-pager
run 'systemd --user: units habilitadas' bash -c 'systemctl --user list-unit-files --state=enabled --no-pager'
sub 'autostart'
open_fence
ls -1 ~/.config/autostart 2>/dev/null >> "$OUT"
close_fence
sub 'hooks do APT'
open_fence
ls -1 /etc/apt/apt.conf.d/ 2>/dev/null >> "$OUT"
close_fence
sub 'repos em ~/Desenvolvimento'
open_fence
ls -1 ~/Desenvolvimento 2>/dev/null >> "$OUT"
close_fence

# --- 13. Hardware relevante -----------------------------------------------
sec '13. Hardware / GPU (contexto de performance do blur)'
open_fence
{
  grep -m1 'model name' /proc/cpuinfo
  free -h | head -2
  command -v nvidia-smi >/dev/null && nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv
} >> "$OUT" 2>&1
close_fence

printf '\n\n---\n_fim do inventário_\n' >> "$OUT"

echo
echo "  Inventário gerado:"
echo "     $OUT"
echo "     $(du -h "$OUT" | cut -f1) — $(wc -l < "$OUT") linhas"
echo
echo "  Anexe esse arquivo na conversa. Se quiser dar uma olhada antes:"
echo "     less \"$OUT\""
echo

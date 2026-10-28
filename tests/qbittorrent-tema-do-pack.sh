#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"; mkdir -p "$BIN"
for b in sudo pkexec su pkill notify-send systemctl gsettings dconf busctl curl wget; do
  printf '#!/bin/sh\nexit 1\n' > "$BIN/$b"; chmod 755 "$BIN/$b"
done
printf '#!/bin/sh\nexit 0\n' > "$BIN/flatpak"; chmod 755 "$BIN/flatpak"
printf '#!/bin/sh\nexit 1\n' > "$BIN/pgrep"; chmod 755 "$BIN/pgrep"

CASA="$T/casa"; ZD="$CASA/.config/zsh"; ESTADO="$CASA/.local/state/meowsystem"
mkdir -p "$ZD/scripts" "$ESTADO" "$T/etc" "$T/desenv" "$T/sbin"
ramo="$CASA/.local/share/flatpak/app/org.qbittorrent.qBittorrent/x86_64/stable"
mkdir -p "$ramo/0123abcd" && ln -sfn 0123abcd "$ramo/active"
QB="$CASA/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent"
mkdir -p "$QB"
printf '[BitTorrent]\nSession\\Port=6881\n\n[Preferences]\nGeneral\\Locale=en\n' > "$QB/qBittorrent.conf"

AURORA="$ZD/scripts/aurora-qbittorrent-config.sh"
cat > "$AURORA" <<'FALSO'
#!/usr/bin/env bash
CONF_DIR="$HOME/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent"
TEMAS_DIR="$CONF_DIR/themes"
USAR_TEMA=true
TEMA_PATH="$TEMAS_DIR/dracula.qbtheme"
mkdir -p "$TEMAS_DIR"
[ -f "$TEMA_PATH" ] || printf 'qres dracula de brinquedo\n' > "$TEMA_PATH"
CHAVES=(
  "Preferences/General/Locale=pt_BR"
  "Preferences/General/UseCustomUITheme=$USAR_TEMA"
  "Preferences/General/CustomUIThemePath=$TEMA_PATH"
  "Preferences/General/AlternatingRowColors=true"
)
python3 - "$CONF_DIR/qBittorrent.conf" "${CHAVES[@]}" <<'PY'
import sys
conf, chaves = sys.argv[1], sys.argv[2:]
linhas = open(conf, encoding="utf-8").read().split("\n")
for c in chaves:
    caminho, valor = c.split("=", 1)
    secao, chave = caminho.split("/", 1)
    chave = chave.replace("/", "\\")
    dentro, feito, fim = False, False, None
    for i, l in enumerate(linhas):
        if l.startswith("["):
            if dentro:
                fim = i
                break
            dentro = l.strip() == f"[{secao}]"
            continue
        if dentro and l.split("=", 1)[0] == chave:
            linhas[i] = f"{chave}={valor}"
            feito = True
            break
    if not feito:
        pos = fim if fim is not None else len(linhas)
        while pos > 0 and linhas[pos - 1] == "":
            pos -= 1
        linhas.insert(pos, f"{chave}={valor}")
novo = "\n".join(linhas)
if novo != open(conf, encoding="utf-8").read():
    open(conf, "w", encoding="utf-8").write(novo)
PY
FALSO
chmod 755 "$AURORA"

casa() {
  env -i PATH="$BIN:$PATH" HOME="$CASA" ZDOTDIR="$ZD" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    XDG_CONFIG_HOME="$CASA/.config" XDG_DATA_HOME="$CASA/.local/share" XDG_STATE_HOME="$CASA/.local/state" \
    MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$ESTADO" MEOW_PONTE=/caminho/inexistente \
    FLATPAK_SYSTEM_DIR="$T/flatpak-sistema" FLATPAK_CONFIG_DIR="$T/flatpak-etc" \
    VIZINHOS_ETC="$T/etc" VIZINHOS_DESENV="$T/desenv" VIZINHOS_CRONTAB="$T/sem-cron" VIZINHOS_SBIN="$T/sbin" \
    PACK=meowsystem FLAVOR=mocha ACCENT=mauve APPS_ATIVOS=qbittorrent "$@"
}
aurora() { casa bash "$AURORA" >/dev/null 2>&1; }
doutor() {
  casa bash -c '
    source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow")
    for n in apps vizinhos; do
      "chk_$n" >/dev/null 2>&1; rc=$?
      printf "chk_%s=%s\n" "$n" "$rc"
      [ "$rc" = 1 ] && { "fix_$n" 2>&1 | sed "s/^/  /"; printf "fix_%s=%s\n" "$n" "${PIPESTATUS[0]}"; }
    done' 2>&1
}
retrato() { (cd "$CASA" && find . -path ./.local/state/meowsystem/meow.log -prune -o -type f -printf '%p %s %T@\n' | sort); }
tema_no_ar() { sed -n 's/^General\\CustomUIThemePath=//p' "$QB/qBittorrent.conf"; }
DRACULA="$QB/themes/dracula.qbtheme"
DO_PACK="$QB/themes/catppuccin-mocha.qbtheme"

aurora
[ "$(tema_no_ar)" = "$DRACULA" ] && grep -qxF 'General\UseCustomUITheme=true' "$QB/qBittorrent.conf" \
  && ok "antes: o script falso da Aurora põe o Dracula, como o de verdade" \
  || falha "o script falso da Aurora não pôs o Dracula" "$(cat "$QB/qBittorrent.conf")"

s1="$(doutor)"
[ "$(tema_no_ar)" = "$DO_PACK" ] && grep -qxF 'General\UseCustomUITheme=true' "$QB/qBittorrent.conf" \
  && cmp -s "$DO_PACK" "$RAIZ/packs/meowsystem/temas-de-apps/qbittorrent/catppuccin-mocha.qbtheme" \
  && ok "depois do doctor, o qBittorrent está no tema do pack (catppuccin-mocha.qbtheme)" \
  || falha "o doctor não pôs o tema do pack" "$s1
$(cat "$QB/qBittorrent.conf")"
[ "$(cat "$ESTADO/temas-de-apps/qbittorrent/tema-de-antes" 2>/dev/null)" = "$DRACULA" ] \
  && ok "o tema de antes (o Dracula) fica guardado para voltar" \
  || falha "o tema de antes não ficou guardado" "$(ls -R "$ESTADO" 2>&1 | head -20)"
[ "$(grep -c '^#vizinhos:aurora-qbittorrent-tema# ' "$AURORA")" = 2 ] && bash -n "$AURORA" \
  && grep -qE '^  "Preferences/General/Locale=pt_BR"$' "$AURORA" \
  && ok "o doctor tira o tema do script da Aurora (as duas chaves), e o resto da config dele fica vivo" \
  || falha "o corte do tema no script da Aurora não aconteceu" "$s1
$(grep -n 'Preferences' "$AURORA")"
if grep -q 'tema-de-terceiro\|qbittorrent' "$ESTADO/pendencias.tsv" 2>/dev/null; then
  falha "ficou pendência do qBittorrent" "$(cat "$ESTADO/pendencias.tsv")"
else
  ok "nenhuma pendência do qBittorrent"
fi

sed -i 's/^General\\Locale=.*/General\\Locale=en/' "$QB/qBittorrent.conf"
aurora
grep -qxF 'General\Locale=pt_BR' "$QB/qBittorrent.conf" && [ "$(tema_no_ar)" = "$DO_PACK" ] \
  && ok "a Aurora roda de novo: a config dela entra (Locale=pt_BR), e o tema do pack fica" \
  || falha "a Aurora cortada ainda mexe no tema, ou parou de configurar o resto" "$(cat "$QB/qBittorrent.conf")"

antes="$(retrato)"
s2="$(doutor)"
depois="$(retrato)"
if [ "$antes" = "$depois" ] && [[ "$s2" == *"chk_apps=0"* ]] && [[ "$s2" != *"fix_"* ]]; then
  ok "a segunda passada do doctor não escreve nada ($(printf '%s\n' "$antes" | wc -l) arquivos da casa com o mesmo tamanho e a mesma hora)"
else
  falha "a segunda passada do doctor escreveu" "$s2
$(diff <(printf '%s\n' "$antes") <(printf '%s\n' "$depois"))"
fi

[ "$falhas" -eq 0 ] || { printf '\n%d falha(s)\n' "$falhas" >&2; exit 1; }
printf '\ntudo certo\n'

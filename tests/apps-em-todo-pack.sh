#!/usr/bin/env bash
# apps-em-todo-pack.sh — cada aplicativo veste os dois packs, cada um com as cores dele.
#
# Para cada app x pack, numa casa de brinquedo com o app "instalado": o pack
# responde pelo próprio tema (não herdado), o aplicar escreve um tema com a cor
# de fundo DAQUELE pack e nenhuma do outro, e a segunda passada fica quieta. A
# ida e volta de pack troca o tema junto.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'FALHOU: sem python3\n' >&2; exit 1; }

# Os apps cujo tema é o modelo do motor que a paleta preenche.
MODELOS=(kitty)
PACKS=(meowsystem:mocha dracula:dracula)

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"; CASA="$T/casa"; mkdir -p "$BIN"
falso() { printf '#!/bin/sh\nexit %s\n' "${2:-0}" > "$BIN/$1"; chmod +x "$BIN/$1"; }
for x in sudo pkexec su apt apt-get systemctl pkill; do
  printf '#!/bin/sh\necho "recusado: %s" >&2\nexit 1\n' "$x" > "$BIN/$x"; chmod +x "$BIN/$x"
done
falso pgrep 1; falso flatpak 0
# O dconf de mentira: uma chave por linha no HOME de brinquedo (o mesmo do tests/temas-de-apps.sh).
cat > "$BIN/dconf" <<'DCONF'
#!/usr/bin/env python3
import os, sys
banco = os.path.join(os.environ["HOME"], ".dconf-de-mentira")
d = {}
if os.path.exists(banco):
    for l in open(banco, encoding="utf-8"):
        k, v = l.rstrip("\n").split("\t", 1)
        d[k] = v
def salvar():
    open(banco, "w", encoding="utf-8").write("".join(f"{k}\t{v}\n" for k, v in sorted(d.items())))
verbo = sys.argv[1]
if verbo == "read":
    if sys.argv[2] in d:
        print(d[sys.argv[2]])
elif verbo == "write":
    d[sys.argv[2]] = sys.argv[3]; salvar()
elif verbo == "reset":
    if sys.argv[2] == "-f":
        for k in [k for k in d if k.startswith(sys.argv[3])]:
            del d[k]
    else:
        d.pop(sys.argv[2], None)
    salvar()
elif verbo == "dump":
    p = sys.argv[2]
    ks = sorted(k for k in d if k.startswith(p) and "/" not in k[len(p):])
    if ks:
        print("[/]")
        for k in ks:
            print(f"{k[len(p):]}={d[k]}")
elif verbo == "load":
    for l in sys.stdin:
        l = l.rstrip("\n")
        if l and not l.startswith(("#", "[")):
            k, v = l.split("=", 1)
            d[sys.argv[2] + k] = v
    salvar()
else:
    sys.exit(1)
DCONF
chmod +x "$BIN/dconf"

implantar() {  # <id> — o flatpak do usuário na forma de um de verdade
  local a="$CASA/.local/share/flatpak/app/$1"
  mkdir -p "$a/x86_64/stable/0123abcd" && ln -sfn 0123abcd "$a/x86_64/stable/active" && ln -sfn x86_64/stable "$a/current"
}
semear() {  # <app> — a casa do zero, com o app instalado e sem tema
  rm -rf "$CASA" "$T/estado"; mkdir -p "$CASA/.config"
  rm -f "$BIN/kitty" "$BIN/gnome-terminal"
  case "$1" in
    kitty) falso kitty ;;
    gnome-terminal) falso gnome-terminal ;;
    telegram) implantar org.telegram.desktop ;;
    discord) implantar com.discordapp.Discord; mkdir -p "$CASA/.config/Vencord/themes" ;;
    onlyoffice)
      implantar org.onlyoffice.desktopeditors
      local oo="$CASA/.var/app/org.onlyoffice.desktopeditors"
      mkdir -p "$oo/config/onlyoffice" "$oo/data/onlyoffice/desktopeditors/uithemes"
      printf '[General]\nUITheme=theme-dark\n' > "$oo/config/onlyoffice/DesktopEditors.conf" ;;
  esac
}
mod() {  # <app> <verbo> <pack> <flavor>
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" XDG_DATA_HOME="$CASA/.local/share" \
      MEOW_PACKS="$T/packs" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado" TMPDIR="$T" \
      PACK="$3" FLAVOR="$4" ACCENT=mauve NO_COLOR=1 \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2
               . "$MEOW_RAIZ/scripts/temas-de-apps/$0/manifesto.sh" || exit 2
               meow_app_$1' "$1" "$2" </dev/null 2>&1
}
fundo() {  # <pack> <flavor> — o hex do `base`, sem o #
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flavors"][sys.argv[2]]["base"].lstrip("#"))' \
    "$RAIZ/packs/$1/paleta.json" "$2"
}
# Os arquivos da casa com aquele hex (o estado do MeowSystem não conta: backup e log).
com_cor() { grep -rIil -- "$1" "$CASA" 2>/dev/null | grep -v '/.local/state/' | wc -l; }
mkdir -p "$T/packs"

for app in "${MODELOS[@]}"; do
  for par in "${PACKS[@]}"; do
    p="${par%%:*}"; f="${par#*:}"
    case "$p" in meowsystem) o=dracula:dracula ;; *) o=meowsystem:mocha ;; esac
    meu="$(fundo "$p" "$f")"; dele="$(fundo "${o%%:*}" "${o#*:}")"
    quem="$(python3 "$RAIZ/scripts/pack.py" app "$p" "apps.$app.arquivo" 2>/dev/null | sed -n 's/^pack=//p')"
    [ "$quem" = "$p" ] \
      && ok "$app/$p: o pack responde pelo próprio tema" \
      || falha "$app/$p: o tema não é do pack $p (responde: '${quem:-ninguém}')"
    semear "$app"
    saida="$(mod "$app" aplicar "$p" "$f")"; rc=$?
    if [ "$rc" = 1 ] && [ "$(com_cor "$meu")" -gt 0 ] && [ "$(com_cor "$dele")" = 0 ]; then
      ok "$app/$p: o aplicar veste a cor do $p (#$meu) e nenhuma do outro"
    else
      falha "$app/$p: o aplicar não vestiu a cor do pack (rc=$rc, #$meu em $(com_cor "$meu"), #$dele em $(com_cor "$dele"))" "$saida"
    fi
    saida="$(mod "$app" aplicar "$p" "$f")"; rc=$?
    [ "$rc" = 0 ] && ok "$app/$p: a segunda passada fica quieta" \
      || falha "$app/$p: a segunda passada não ficou quieta (rc=$rc)" "$saida"
  done
  # Ida e volta: o tema do pack troca junto com o pack, sem perguntar (é nosso).
  semear "$app"
  mod "$app" aplicar meowsystem mocha >/dev/null
  saida="$(mod "$app" aplicar dracula dracula)"; rc1=$?
  d1="$(com_cor "$(fundo dracula dracula)")"; m1="$(com_cor "$(fundo meowsystem mocha)")"
  saida="$saida$(mod "$app" aplicar meowsystem mocha)"; rc2=$?
  d2="$(com_cor "$(fundo dracula dracula)")"; m2="$(com_cor "$(fundo meowsystem mocha)")"
  if [ "$rc1" = 1 ] && [ "$d1" -gt 0 ] && [ "$m1" = 0 ] && [ "$rc2" = 1 ] && [ "$m2" -gt 0 ] && [ "$d2" = 0 ]; then
    ok "$app: a ida e volta de pack troca o tema junto"
  else
    falha "$app: a ida e volta não trocou o tema (rc $rc1/$rc2; dracula $d1/$d2, meowsystem $m1/$m2)" "$saida"
  fi
done

printf '\n'
if [ "$falhas" -gt 0 ]; then
  printf '%s achado(s).\n' "$falhas" >&2
  exit 1
fi
printf 'Cada aplicativo veste os dois packs, cada um com a cor dele.\n'
exit 0

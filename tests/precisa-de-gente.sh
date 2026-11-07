#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

mkdir -p "$T/bin" "$T/home/.local/state/meowsystem" "$T/home/.config/meow" "$T/patches"
E="$T/home/.local/state/meowsystem"; ARQ="$E/precisa-de-gente.tsv"
for c in sudo pkexec apt apt-get systemctl systemd-run pkill killall notify-send cargo make; do
  printf '#!/bin/sh\nexit 1\n' > "$T/bin/$c"; chmod 755 "$T/bin/$c"
done
doutor() {
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY HOME="$T/home" PATH="$T/bin:$PATH" \
      MEOW_ESTADO="$E" MEOW_RAIZ="$RAIZ" NO_COLOR=1 MEOW_CONF="$T/nao-existe.conf" \
      bash -c 'source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow"); "$@"' _ "$@" 2>&1
}
linhas() { [ -f "$ARQ" ] && wc -l < "$ARQ" || echo 0; }
foto() { printf '%s %s' "$(stat -c %Y.%s "$ARQ" 2>/dev/null)" "$(cat "$ARQ" 2>/dev/null)"; }

echo "== 1. o arquivo sem leitor sai na passada do doctor"
printf 'compositor-caiu\tO compositor caiu\t2026-10-20T10:00:00-03:00\tqueda\npatch-obrigatorio\tO patch não entra\t2026-10-20T10:00:00-03:00\tserie\nsentinela-cosmic\tO COSMIC da fila não entra\t2026-10-20T10:00:00-03:00\tserie\n' > "$ARQ"
antes="$(foto)"
saida="$(doutor chk_estadovelho)"; rc=$?
igual "a conferência acusa o arquivo velho" "$rc" 1
[[ "$saida" == *"precisa-de-gente.tsv não tem mais leitor"* ]] && ok "e diz o que sai" || falha "a conferência não citou o arquivo: $saida"
igual "conferir não escreve" "$(foto)" "$antes"
MEOW_DRY_RUN=1 doutor fix_estadovelho >/dev/null
igual "o conserto no ensaio não escreve" "$(foto)" "$antes"
doutor fix_estadovelho >/dev/null; rc=$?
igual "o conserto diz que mexeu" "$rc" 1
[ ! -e "$ARQ" ] && ok "as linhas antigas sumiram com o arquivo" || falha "o arquivo ficou: $(cat "$ARQ")"
saida="$(doutor chk_estadovelho)"; rc=$?
igual "a passada seguinte não acha nada" "$rc" 0

echo "== 2. o patch obrigatório que não entra (degrau 4)"
echo 'req t.patch MEOW-T' > "$T/patches/series"
cat > "$T/bin/dpkg-query" <<FIM
#!/bin/sh
fmt=""; pacotes=""
for a in "\$@"; do case "\$a" in -W) ;; -f=*) fmt="\${a#-f=}" ;; *) pacotes="\$pacotes \$a" ;; esac; done
for p in \$pacotes; do
  linha=\$(awk -F'\t' -v p="\$p" '\$1==p' "$T/dpkg.tsv"); [ -n "\$linha" ] || continue
  case "\$fmt" in *Package*) printf '%s\n' "\$linha" ;; *) printf '%s' "\$(printf '%s' "\$linha" | cut -f2)" ;; esac
done
FIM
chmod 755 "$T/bin/dpkg-query"
printf 'cosmic-comp\t0.9~a\tinstalled\ncosmic-files\t1.10~a\tinstalled\n' > "$T/dpkg.tsv"
CASA="$T/home/.local/libexec/meow/cosmic-comp"
cat > "$T/compositor" <<FIM
#!/bin/sh
[ "\$1" = compilar ] || exit 0
v=\$(awk -F'\t' '\$1=="cosmic-comp"{print \$2}' "$T/dpkg.tsv")
if [ -f "$T/req-falha" ]; then
  mkdir -p "$E/cosmic-comp"
  printf '%s\t2026-10-15\tcosmic-comp-sem-workspace-vazio.patch:4\n' "\$v" >> "$E/cosmic-comp/matriz.tsv"
  exit 2
fi
mkdir -p "$CASA/\$v"; printf '#!/bin/sh\n' > "$CASA/\$v/cosmic-comp"; chmod 755 "$CASA/\$v/cosmic-comp"
echo "req MEOW-T-1 t.patch presente" > "$CASA/\$v/estado"
exit 1
FIM
cat > "$T/files" <<FIM
#!/bin/sh
[ "\$1" = build ] || exit 0
v=\$(awk -F'\t' '\$1=="cosmic-files"{print \$2}' "$T/dpkg.tsv")
mkdir -p "$E/cosmic-files/\$v"
for b in cosmic-files cosmic-files-applet; do echo MEOW-FILES-WALLPAPER-PATCH-2 > "$E/cosmic-files/\$v/\$b"; done
exit 1
FIM
chmod 755 "$T/compositor" "$T/files"
builds() {
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY HOME="$T/home" PATH="$T/bin:$PATH" \
      MEOW_RAIZ="$RAIZ" NO_COLOR=1 MEOW_ESTADO="$E" MEOW_CONF="$T/home/.config/meow/meow.conf" \
      GB_COMPOSITOR="$T/compositor" GB_FILES="$T/files" CP_REPO="$T/patches" CP_SERIE="$T/patches/series" \
      "$RAIZ/scripts/garantir_builds.sh" "$@" >/dev/null 2>&1
}
touch "$T/req-falha"
builds
igual "o req que não entra fica fora do cartão: log e doctor" "$(linhas)" 0

echo "== 3. a rota sem leitor saiu"
grep -q 'precisa-de-gente\|precisa_de_gente' "$RAIZ/app/servidor.py" && falha "o servidor ainda serve a rota morta" || ok "o servidor não tem a rota nem o leitor"
grep -rq 'meow_precisa_de_gente' "$RAIZ/lib" "$RAIZ/scripts" "$RAIZ/bin" && falha "ainda há quem escreva o arquivo" || ok "ninguém escreve o arquivo"

echo "== 4. o Manter não tem cartão de pendências"
if grep -q 'PRECISA_DE_GENTE\|linhaDeGente\|bloco("Pendências"' "$RAIZ/app/pagina/paginas.js" "$RAIZ/app/pagina/app.js"; then
  falha "o Manter ainda desenha o cartão de pendências"
else
  ok "o Manter não desenha cartão de pendências nem a conta delas"
fi

echo
if [ "$falhas" = 0 ]; then echo "precisa-de-gente: tudo certo"; exit 0; fi
echo "precisa-de-gente: $falhas falha(s)"; exit 1

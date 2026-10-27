#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

H="$T/home"
mkdir -p "$T/bin" "$T/tmp" "$H/.local/bin" "$H/.config/meow" "$H/.cache"
for c in sudo pkexec apt systemctl systemd-run pkill killall notify-send rustup; do
  printf '#!/bin/sh\necho "recusado: %s $*" >> "%s/recusados"\nexit 1\n' "$c" "$T" > "$T/bin/$c"
  chmod 755 "$T/bin/$c"
done

cat > "$T/bin/dpkg-query" <<FIM
#!/bin/sh
fmt=""; pacotes=""
for a in "\$@"; do
  case "\$a" in -W) ;; -f=*) fmt="\${a#-f=}" ;; *) pacotes="\$pacotes \$a" ;; esac
done
for p in \$pacotes; do
  case "\$p" in *\\**) linhas=\$(cat "$T/dpkg.tsv") ;; *) linhas=\$(awk -F'\t' -v p="\$p" '\$1==p' "$T/dpkg.tsv") ;; esac
  [ -n "\$linhas" ] || continue
  case "\$fmt" in
    *Package*) printf '%s\n' "\$linhas" ;;
    *) printf '%s' "\$(printf '%s' "\$linhas" | cut -f2)" ;;
  esac
done
FIM
cat > "$T/bin/apt-get" <<FIM
#!/bin/sh
[ "\$1" = source ] || { echo "recusado: apt-get \$*" >> "$T/recusados"; exit 1; }
shift; [ "\$1" = --download-only ] && shift
case "\$1" in *=*) ;; *) echo "apt-get source sem versão: \$1" >> "$T/recusados"; exit 1 ;; esac
p="\${1%%=*}"; v="\${1#*=}"
echo "rede \$p \$v" >> "$T/rede.log"
case "\$p" in
  cosmic-comp)  : > "cosmic-comp_\${v#*:}.dsc"; echo "\$v" > "cosmic-comp_\${v#*:}.tar.xz" ;;
  cosmic-files) mkdir -p cosmic-files-1.10/src
                echo "// MEOW-FILES-WALLPAPER-PATCH-1 \$v" > cosmic-files-1.10/src/app.rs ;;
  *) exit 1 ;;
esac
FIM
cat > "$T/bin/dpkg-source" <<FIM
#!/bin/sh
[ "\$1" = -x ] || exit 1
d="\$3"; mkdir -p "\$d/src"
printf '[package]\n' > "\$d/Cargo.toml"
printf 'fn main() {}\n// MEOW-ALVO\n' > "\$d/src/main.rs"
tar cf "\$d/vendor.tar" -T /dev/null
case "\$(cat "$T/receita")" in
  make) printf 'all:\n' > "\$d/Makefile" ;;
  just) printf "import 'cargo.just'\n" > "\$d/justfile"
        printf 'build-vendored *args: vendor-extract\n' > "\$d/cargo.just" ;;
esac
FIM
for c in make just; do
  cat > "$T/bin/$c" <<FIM
#!/bin/sh
echo "$c \$*" >> "$T/build.log"
mkdir -p target/release && cp src/main.rs target/release/cosmic-comp
FIM
done
cat > "$T/bin/cargo" <<FIM
#!/bin/sh
echo "cargo \$* @\$(basename "\$PWD" | cut -d- -f1-2)" >> "$T/build.log"
case "\$1" in
  update) [ -f Cargo.toml ] || { echo "error: could not find Cargo.toml" >&2; exit 101; } ;;
  build) mkdir -p target/release
         if [ -f src/app.rs ]; then
           cp src/app.rs target/release/cosmic-files; cp src/app.rs target/release/cosmic-files-applet
         else cp src/main.rs target/release/cosmic-comp; fi ;;
esac
FIM
chmod 755 "$T/bin"/*

mkdir -p "$T/pa/a/src" "$T/pa/b/src" "$T/patches"
printf 'fn main() {}\n// MEOW-ALVO\n' > "$T/pa/a/src/main.rs"
printf 'fn main() {}\n// MEOW-ALVO\n// MEOW-T-PATCH-1\n' > "$T/pa/b/src/main.rs"
(cd "$T/pa" && diff -u a/src/main.rs b/src/main.rs) > "$T/patches/cosmic-comp-t.patch"
printf 'req cosmic-comp-t.patch MEOW-T-PATCH\n' > "$T/serie"
cp "$RAIZ/scripts/compositor_shim.sh" "$H/.local/bin/cosmic-comp"

versoes() {
  : > "$T/dpkg.tsv"; local x
  for x in "$@"; do printf '%s\t%s\tinstalled\n' "${x%%=*}" "${x#*=}" >> "$T/dpkg.tsv"; done
}
ambiente() {
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY -u XDG_CACHE_HOME -u XDG_DATA_HOME \
    HOME="$H" PATH="$T/bin:$PATH" TMPDIR="$T/tmp" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
    CP_SERIE="$T/serie" CP_REPO="$T/patches" CP_VERSOES="$T/nenhuma" \
    PA_DOCTOR="$T/doctor" PA_ORACULO="$T/oraculo" PA_RUSTUP="$T/bin/rustup" PA_CANDIDATO="$T/nenhum" \
    "$@"
}
printf '#!/bin/sh\necho "doctor $*" >> "%s/build.log"\n' "$T" > "$T/doctor"
printf '#!/bin/sh\nexit 0\n' > "$T/oraculo"
chmod 755 "$T/doctor" "$T/oraculo"
pos_apt() { ambiente "$RAIZ/scripts/cosmic_pos_apt.sh" >> "$T/saida" 2>&1; }
login()   { ambiente "$RAIZ/scripts/garantir_builds.sh" >> "$T/saida" 2>&1; }
doctor5h(){ ambiente "$RAIZ/scripts/garantir_builds.sh" --fundo >> "$T/saida" 2>&1; }
qual()    { ambiente env MEOW_SHIM_SO_DIZER=1 MEOW_SHIM_FABRICA=/usr/bin/cosmic-comp bash "$H/.local/bin/cosmic-comp"; }
foto()    { (cd "$H" && find . -printf '%p %s %T@\n' | sort; find . -type f -exec sha256sum {} + | sort) | sha256sum; }
CASA="$H/.local/libexec/meow/cosmic-comp"
GUARDA="$H/.local/share/meowsystem/fontes/cosmic-comp"
ESTADO="$H/.local/state/meowsystem"

echo "== a máquina antes: COSMIC A (fonte com Makefile), e o primeiro pós-apt"
echo make > "$T/receita"
versoes cosmic-comp=0.1~a cosmic-files=1.10~a cosmic-panel=1.10~a
pos_apt
igual "o shim escolhe o build da A" "$(qual)" "$CASA/0.1~a/cosmic-comp"
grep -q '^make VENDOR=1' "$T/build.log" && ok "o fonte com Makefile compilou com make VENDOR=1" || falha "o Makefile não foi usado"

echo "== sudo apt update: nada muda de versão"
antes="$(foto)"; : > "$T/build.log"
pos_apt
igual "nenhum byte no HOME" "$(foto)" "$antes"
igual "nenhum build" "$(grep -c . "$T/build.log")" 0

echo "== sudo apt full-upgrade: COSMIC B (fonte com justfile, o 4d14528)"
echo just > "$T/receita"
versoes cosmic-comp=0.1~b cosmic-files=1.10~b cosmic-panel=1.10~b
: > "$T/build.log"
pos_apt
igual "o shim escolhe o build da B" "$(qual)" "$CASA/0.1~b/cosmic-comp"
grep -q '^just build-vendored' "$T/build.log" && ok "o fonte com justfile compilou com just build-vendored" || falha "o justfile não foi usado: $(tr '\n' ';' < "$T/build.log")"
grep -q 'MEOW-FILES-WALLPAPER-PATCH-1 1.10~b' "$H/.local/bin/cosmic-files-applet" 2>/dev/null \
  && ok "o menu da B está vestido em ~/.local/bin" || falha "o menu da B não foi vestido"
grep -q 'apt-get source sem versão' "$T/recusados" 2>/dev/null \
  && falha "um apt-get source baixou sem a versão (o candidato, e não o instalado)" \
  || ok "todo apt-get source pediu a versão instalada"

echo "== topgrade, sudo apt autoremove, sudo apt autoclean: nada nosso muda"
antes="$(foto)"; : > "$T/build.log"
pos_apt; pos_apt; pos_apt
igual "nenhum byte no HOME" "$(foto)" "$antes"

echo "== cargo update fora de um projeto"
(cd "$T" && PATH="$T/bin:$PATH" cargo update >/dev/null 2>&1); rc=$?
igual "sai 101 (corta a cadeia com &&; não é do MeowSystem)" "$rc" 101

echo "== limpar_cache: o ~/.cache inteiro some, e o apt clean junto"
rm -rf "${H:?}/.cache/"* "$T/tmp/"*
pos_apt
[ -f "$GUARDA/cosmic-comp_0.1~a.dsc" ] && [ -f "$GUARDA/cosmic-comp_0.1~b.dsc" ] \
  && ok "os fontes guardados da A e da B continuam em ~/.local/share" || falha "um fonte guardado sumiu: $(ls "$GUARDA" 2>&1 | tr '\n' ' ')"
igual "o shim continua no build da B" "$(qual)" "$CASA/0.1~b/cosmic-comp"

echo "== o upgrade seguinte, com o cache vazio: COSMIC C (fonte sem Makefile nem justfile)"
echo nada > "$T/receita"
versoes cosmic-comp=0.1~c cosmic-files=1.10~c cosmic-panel=1.10~c
: > "$T/build.log"
pos_apt
igual "o shim escolhe o build da C" "$(qual)" "$CASA/0.1~c/cosmic-comp"
grep -q '^cargo build --release --frozen --offline @cosmic-comp' "$T/build.log" \
  && ok "sem receita, cargo build --frozen --offline" || falha "o caminho do cargo não foi usado: $(tr '\n' ';' < "$T/build.log")"

echo "== o apt feito com ela deslogada: COSMIC D, nenhum pós-apt; o login pega"
echo just > "$T/receita"
versoes cosmic-comp=0.1~d cosmic-files=1.10~d cosmic-panel=1.10~d
login
igual "o shim escolhe o build da D" "$(qual)" "$CASA/0.1~d/cosmic-comp"
[ -x "$ESTADO/cosmic-files/1.10~d/cosmic-files-applet" ] && ok "e o menu da D" || falha "o login não fez o menu da D"

echo "== a segunda passada de tudo não escreve nada"
pos_apt; login; doctor5h
antes="$(foto)"; : > "$T/build.log"; : > "$T/rede.log"
pos_apt; login; doctor5h
igual "nenhum byte no HOME" "$(foto)" "$antes"
igual "nenhum build" "$(grep -c . "$T/build.log")" 0
igual "nenhum download" "$(grep -c . "$T/rede.log")" 0

echo "== COSMIC E, em que o obrigatório não entra (degrau 4): a 2ª passada não tenta de novo"
cp "$T/patches/cosmic-comp-t.patch" "$T/t.bom"
sed -i 's|^ // MEOW-ALVO$| // OUTRA-COISA|' "$T/patches/cosmic-comp-t.patch"
versoes cosmic-comp=0.1~e cosmic-files=1.10~d cosmic-panel=1.10~d
pos_apt
igual "o shim fica no de fábrica" "$(qual)" "/usr/bin/cosmic-comp"
antes="$(foto)"; : > "$T/build.log"
sleep 1.1; pos_apt; login; doctor5h
igual "nenhum byte no HOME" "$(foto)" "$antes"
echo "== o rebase chega (a série muda): a mesma versão compila"
cp "$T/t.bom" "$T/patches/cosmic-comp-t.patch"
login
igual "o shim escolhe o build da E" "$(qual)" "$CASA/0.1~e/cosmic-comp"

grep -v '^apt-get source sem versão' "$T/recusados" 2>/dev/null | grep -q . \
  && { falha "algo chamou um comando recusado:"; sed 's/^/        /' "$T/recusados"; }

echo
if [ "$falhas" = 0 ]; then echo "cadeia-de-atualizacao: tudo certo"; exit 0; fi
echo "--- saída dos scripts ---"; tail -40 "$T/saida"
echo "cadeia-de-atualizacao: $falhas falha(s)"; exit 1

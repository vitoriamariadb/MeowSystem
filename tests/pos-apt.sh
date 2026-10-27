#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

mkdir -p "$T/bin" "$T/home/.local/bin" "$T/casa"
cp "$RAIZ/scripts/compositor_shim.sh" "$T/home/.local/bin/cosmic-comp"
cat > "$T/bin/dpkg-query" <<FIM
#!/bin/sh
cat "$T/dpkg.tsv"
FIM
chmod 755 "$T/bin/dpkg-query"
versoes() {
  : > "$T/dpkg.tsv"; local x
  for x in "$@"; do printf '%s\t%s\tinstalled\n' "${x%%=*}" "${x#*=}" >> "$T/dpkg.tsv"; done
}
cat > "$T/compositor" <<FIM
#!/bin/sh
echo "compositor \$*" >> "$T/log"
[ "\$1" = compilar ] || exit 0
v=\$(awk -F'\t' '\$1=="cosmic-comp"{print \$2}' "$T/dpkg.tsv")
mkdir -p "$T/casa/\$v" && echo "req X y presente" > "$T/casa/\$v/estado"
printf '#!/bin/sh\n' > "$T/casa/\$v/cosmic-comp" && chmod 755 "$T/casa/\$v/cosmic-comp"
exit 1
FIM
cat > "$T/files" <<FIM
#!/bin/sh
echo "files \$*" >> "$T/log"
[ "\$1" = build ] || exit 0
[ -f "$T/files-falha" ] && exit 2
v=\$(awk -F'\t' '\$1=="cosmic-files"{print \$2}' "$T/dpkg.tsv")
mkdir -p "$T/estado/cosmic-files/\$v"
for b in cosmic-files cosmic-files-applet; do echo MEOW-FILES-WALLPAPER-PATCH-1 > "$T/estado/cosmic-files/\$v/\$b"; done
exit 1
FIM
cat > "$T/rustup" <<FIM
#!/bin/sh
echo "rustup \$*" >> "$T/log"
FIM
cat > "$T/oraculo" <<FIM
#!/bin/sh
echo "oraculo \$*" >> "$T/log"
FIM
cat > "$T/doctor" <<FIM
#!/bin/sh
echo "doctor \$*" >> "$T/log"
FIM
cat > "$T/som" <<FIM
#!/bin/sh
echo "som \$*" >> "$T/log-som"
FIM
chmod 755 "$T/compositor" "$T/files" "$T/doctor" "$T/rustup" "$T/oraculo" "$T/som"

rodar() {
  HOME="$T/home" PATH="$T/bin:$PATH" MEOW_ESTADO="$T/estado" MEOW_CONF="$T/nao-existe.conf" \
  GB_CASA="$T/casa" GB_COMPOSITOR="$T/compositor" GB_FILES="$T/files" PA_DOCTOR="$T/doctor" \
  PA_RUSTUP="$T/rustup" PA_CANDIDATO="$T/candidato.tsv" PA_ORACULO="$T/oraculo" PA_SOM="$T/som" \
    "$RAIZ/scripts/cosmic_pos_apt.sh" "$@" >/dev/null 2>&1
}
linhas() { grep -c "$1" "$T/log" 2>/dev/null || true; }

echo "== primeira passagem: tudo é novo"
versoes cosmic-comp=0.1~a cosmic-files=1.10~a cosmic-panel=1.10~a
: > "$T/log"
rodar; igual "rc 0 (sucesso, mesmo tendo escrito)" "$?" 0
igual "um build do compositor" "$(linhas '^compositor compilar')" 1
igual "um build do menu" "$(linhas '^files build')" 1
igual "um doctor --consertar" "$(linhas '^doctor doctor --consertar')" 1
h1="$(sha256sum < "$T/estado/cosmic-versoes")"

echo "== segunda passagem, nada mudou: zero"
: > "$T/log"
rodar; igual "rc 0" "$?" 0
igual "nenhuma linha no registro" "$(grep -c . "$T/log")" 0
igual "o arquivo de versões não mudou" "$(sha256sum < "$T/estado/cosmic-versoes")" "$h1"

igual "e o som do carregador e da bateria é conferido a cada passagem" "$(grep -c '^som aplicar' "$T/log-som")" 2

echo "== só o cosmic-files sobe"
versoes cosmic-comp=0.1~a cosmic-files=1.10~b cosmic-panel=1.10~a
: > "$T/log"
rodar
igual "nenhum build do compositor" "$(linhas '^compositor compilar')" 0
igual "um build do menu" "$(linhas '^files build')" 1
: > "$T/log"; rodar
igual "e zero na passagem seguinte" "$(grep -c . "$T/log")" 0

echo "== o compositor sobe e o build da versão já existe"
mkdir -p "$T/casa/0.1~c"; echo "req X y presente" > "$T/casa/0.1~c/estado"
printf '#!/bin/sh\n' > "$T/casa/0.1~c/cosmic-comp"; chmod 755 "$T/casa/0.1~c/cosmic-comp"
versoes cosmic-comp=0.1~c cosmic-files=1.10~b cosmic-panel=1.10~a
: > "$T/log"; rodar
igual "artefato da versão presente: nenhum build" "$(linhas '^compositor compilar')" 0

echo "== o passo que falha sai 2, e a passagem seguinte tenta de novo"
versoes cosmic-comp=0.1~c cosmic-files=1.10~c cosmic-panel=1.10~a
touch "$T/files-falha"
: > "$T/log"; rodar; igual "rc 2 (falhou)" "$?" 2
rm -f "$T/files-falha"
: > "$T/log"; rodar; igual "rc 0 na seguinte" "$?" 0
igual "a passagem seguinte tenta de novo, sem versão nova" "$(linhas '^files build')" 1

echo "== shim desligado: o compositor compila igual (15/10/2026)"
rm -f "$T/home/.local/bin/cosmic-comp"
versoes cosmic-comp=0.1~d cosmic-files=1.10~c cosmic-panel=1.10~a
: > "$T/log"; rodar; igual "rc 0" "$?" 0
igual "sem shim, um build" "$(linhas '^compositor compilar')" 1
grep -q $'cosmic-comp\t0.1~d' "$T/estado/cosmic-versoes" && ok "e a versão é gravada" || falha "a versão não foi gravada"

echo "== a versão já vista sem build (o shim era a desculpa): o build vem"
rm -rf "$T/casa/0.1~d"
: > "$T/log"; rodar
igual "um build do compositor, sem versão nova" "$(linhas '^compositor compilar')" 1

echo "== o pré-voo acusou o rustc baixo: rustup update antes do build"
printf 'toolchain\tvermelho\tcosmic-comp pede rust 9.0\n' > "$T/candidato.tsv"
versoes cosmic-comp=0.1~d cosmic-files=1.10~d cosmic-panel=1.10~a
: > "$T/log"; rodar
igual "um rustup update" "$(linhas '^rustup update')" 1
[ "$(grep -n 'rustup update' "$T/log" | cut -d: -f1)" -lt "$(grep -n '^files build' "$T/log" | cut -d: -f1)" ] \
  && ok "e ele vem antes do build" || falha "o rustup não veio antes do build"
: > "$T/log"; rodar
igual "nada mudou: nem rustup" "$(linhas '^rustup')" 0
rm -f "$T/candidato.tsv"

echo "== o cosmic-settings sobe: o oráculo é chamado uma vez"
versoes cosmic-comp=0.1~d cosmic-files=1.10~d cosmic-panel=1.10~a cosmic-settings=1.10~a
: > "$T/log"; rodar
igual "um construir do oráculo" "$(linhas '^oraculo construir')" 1
: > "$T/log"; rodar
igual "e zero na passagem seguinte" "$(linhas '^oraculo')" 0

echo "== o seco não escreve"
versoes cosmic-comp=0.1~e cosmic-files=1.10~e cosmic-panel=1.10~a
h2="$(sha256sum < "$T/estado/cosmic-versoes")"
: > "$T/log"; rodar --seco
igual "seco: nenhum passo rodou" "$(grep -v '^compositor guardar' "$T/log" | grep -c .)" 0
igual "seco: o arquivo de versões não mudou" "$(sha256sum < "$T/estado/cosmic-versoes")" "$h2"

echo "== o PATH do systemd não tem o ~/.cargo/bin: o pós-apt o põe (conferência da P76)"
mkdir -p "$T/home/.cargo/bin"
printf '#!/bin/sh\nexit 0\n' > "$T/home/.cargo/bin/cargo"; chmod 755 "$T/home/.cargo/bin/cargo"
cat > "$T/files" <<FIM
#!/bin/sh
echo "files cargo=\$(command -v cargo)" >> "$T/log"
exit 1
FIM
versoes cosmic-comp=0.1~e cosmic-files=1.10~f cosmic-panel=1.10~a
: > "$T/log"
HOME="$T/home" PATH="$T/bin:/usr/local/bin:/usr/bin:/bin" MEOW_ESTADO="$T/estado" MEOW_CONF="$T/nao-existe.conf" \
  GB_CASA="$T/casa" GB_COMPOSITOR="$T/compositor" GB_FILES="$T/files" PA_DOCTOR="$T/doctor" \
  PA_RUSTUP="$T/rustup" PA_CANDIDATO="$T/candidato.tsv" PA_ORACULO="$T/oraculo" PA_SOM="$T/som" \
  "$RAIZ/scripts/cosmic_pos_apt.sh" >/dev/null 2>&1
igual "o passo de build acha o cargo do HOME" "$(sed -n 's/^files cargo=//p' "$T/log")" "$T/home/.cargo/bin/cargo"

echo
if [ "$falhas" = 0 ]; then echo "pos-apt: tudo certo"; exit 0; fi
echo "pos-apt: $falhas falha(s)"; exit 1

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | head -30 | sed 's/^/       /' >&2; falhas=$((falhas + 1)); }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/sistema"

for c in pkexec su apt systemctl systemd-run pkill killall notify-send loginctl xdg-open just make wget; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/recusas.log"\nexit 1\n' "$c" "$T" > "$T/bin/$c"
  chmod 755 "$T/bin/$c"
done

cat > "$T/rustup-init-falso" <<'FIM'
#!/bin/sh
echo "$*" >> "$FALSO_LOG/rustup-init.log"
mkdir -p "$CARGO_HOME/bin" "$RUSTUP_HOME/toolchains/stable"
printf '#!/bin/sh\nexit 0\n' > "$CARGO_HOME/bin/cargo"
printf '#!/bin/sh\necho "rustc 1.95.0 (falso)"\n' > "$CARGO_HOME/bin/rustc"
printf '#!/bin/sh\nexit 0\n' > "$CARGO_HOME/bin/rustup"
chmod 755 "$CARGO_HOME/bin/cargo" "$CARGO_HOME/bin/rustc" "$CARGO_HOME/bin/rustup"
printf 'export PATH\n' > "$CARGO_HOME/env"
printf 'default_toolchain = "stable"\n' > "$RUSTUP_HOME/settings.toml"
FIM
SHA="$(sha256sum "$T/rustup-init-falso" | cut -d' ' -f1)"
ARQ="$(uname -m)"

pino() {
  printf 'VERSAO="9.9.9"\nURL="https://exemplo.invalido/@ALVO@/rustup-init"\nSHA256_%s="%s"\nTAMANHO="1 KB"\nRUST_MINIMO="1.93"\n' \
    "$ARQ" "$1" > "$2"
}
pino "$SHA" "$T/pino-certo"
pino "$(printf '0%.0s' $(seq 64))" "$T/pino-errado"

cat > "$T/bin/curl" <<FIM
#!/bin/sh
saida=""; url=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) saida="\$2"; shift ;;
    -*) ;;
    *) url="\$1" ;;
  esac
  shift
done
echo "curl \$url" >> "$T/curl.log"
[ -e "$T/sem-rede" ] && exit 7
cp "$T/rustup-init-falso" "\$saida"
FIM
chmod 755 "$T/bin/curl"

cat > "$T/bin/sudo" <<FIM
#!/bin/sh
echo "sudo \$*" >> "$T/sudo.log"
[ "\$1" = -n ] && shift
case "\$1" in true|-v|-l) exit 0 ;; esac
exec "\$@"
FIM
cat > "$T/bin/apt-get" <<FIM
#!/bin/sh
echo "apt-get \$*" >> "$T/apt.log"
[ "\$1" = install ] || exit 0
for a in "\$@"; do case "\$a" in -*|install) ;; *) echo "\$a" >> "$T/instalados" ;; esac; done
FIM
cat > "$T/bin/apt-cache" <<'FIM'
#!/bin/sh
exit 1
FIM
cat > "$T/bin/dpkg-query" <<FIM
#!/bin/bash
fmt="" pk=() prox=0
for a in "\$@"; do
  if [ "\$prox" = 1 ]; then fmt="\$a"; prox=0; continue; fi
  case "\$a" in -W|--show) ;; -f) prox=1 ;; -f=*|--showformat=*) fmt="\${a#*=}" ;; -*) ;; *) pk+=("\$a") ;; esac
done
rc=0
for p in "\${pk[@]}"; do
  if grep -qxF "\$p" "$T/instalados" 2>/dev/null; then
    case "\$fmt" in *Version*) printf '1.0' ;; *) printf 'installed' ;; esac
  else
    rc=1
  fi
done
exit "\$rc"
FIM
chmod 755 "$T/bin/sudo" "$T/bin/apt-get" "$T/bin/apt-cache" "$T/bin/dpkg-query"

casa() {
  rm -rf "$T/casa" "$T/bk"; mkdir -p "$T/casa/.config/meow"
  : > "$T/curl.log"; : > "$T/rustup-init.log"; : > "$T/apt.log"; : > "$T/sudo.log"
}

rodar() {
  env -i HOME="$T/casa" PATH="$T/bin:$T/sistema:/usr/bin:/bin" LANG=C.UTF-8 TMPDIR="$T" \
    FALSO_LOG="$T" MEOW_RUSTUP_PINO="${PINO:-$T/pino-certo}" MEOW_PONTE="$T/sem-ponte" \
    ${MEOW_BACKUPS:+MEOW_BACKUPS="$MEOW_BACKUPS"} RUST_PRECISA="${RUST_PRECISA:-sim}" \
    ${COMPOSITOR:+COMPOSITOR="$COMPOSITOR"} ${FILES_MENU:+FILES_MENU="$FILES_MENU"} EXTENSOES="${EXTENSOES:-}" \
    FASTFETCH_LOGO=nao "$@"
}

retrato() { (cd "$T/casa" && find . -printf '%p %s %T@\n' 2>/dev/null | LC_ALL=C sort); }

printf '\n--- 1. sem cargo: baixa o rustup pinado, confere o sha e roda com --no-modify-path ---\n'
casa
MEOW_BACKUPS="$T/bk" rodar "$RAIZ/scripts/rust.sh" aplicar > "$T/saida" 2>&1; rc=$?
[ "$rc" = 1 ] && ok "a etapa mexeu (rc 1)" || falha "rc $rc, esperado 1" "$(cat "$T/saida")"
grep -qxF "curl https://exemplo.invalido/$ARQ-unknown-linux-gnu/rustup-init" "$T/curl.log" \
  && ok "baixou pela URL do pino, no alvo $ARQ" || falha "a URL baixada não é a do pino" "$(cat "$T/curl.log")"
args="$(cat "$T/rustup-init.log")"
for a in -y --no-modify-path "--profile minimal" "--default-toolchain stable"; do
  [[ " $args " == *" $a "* ]] || falha "o rustup-init rodou sem $a" "$args"
done
[[ " $args " == *" --no-modify-path "* ]] && ok "o rustup-init rodou com: $args"
[ -x "$T/casa/.cargo/bin/cargo" ] && ok "o cargo está em ~/.cargo/bin" || falha "sem ~/.cargo/bin/cargo"
grep -q 'BAIXA DA INTERNET' "$T/saida" && ok "a saída diz BAIXA DA INTERNET" || falha "a saída não diz BAIXA DA INTERNET" "$(cat "$T/saida")"
grep -qE '\b(rode|digite|execute|sudo apt|apt install)\b' "$T/saida" \
  && falha "a saída manda digitar" "$(cat "$T/saida")" || ok "nenhuma linha manda digitar"
[ "$(cat "$T/casa/.local/state/meowsystem/rust/trouxe" 2>/dev/null)" = "$T/casa/.cargo
$T/casa/.rustup" ] && ok "anotou o que trouxe: ~/.cargo e ~/.rustup" \
  || falha "a anotação do que trouxe está errada" "$(cat "$T/casa/.local/state/meowsystem/rust/trouxe" 2>&1)"
grep -qxF "$T/casa/.cargo	pasta-nova" "$T/bk/tocados.tsv" 2>/dev/null \
  && grep -qxF "$T/casa/.rustup	pasta-nova" "$T/bk/tocados.tsv" \
  && ok "o registro do Restaurar tem ~/.cargo e ~/.rustup como pastas novas" \
  || falha "o registro do Restaurar não tem as pastas novas" "$(cat "$T/bk/tocados.tsv" 2>&1)"

printf '\n--- 2. a segunda passada não escreve nem baixa ---\n'
antes="$(retrato)"
rodar "$RAIZ/scripts/rust.sh" aplicar > "$T/saida" 2>&1; rc=$?
[ "$rc" = 0 ] && ok "a segunda passada confere (rc 0): $(head -1 "$T/saida" | sed 's/^ *//')" || falha "rc $rc na segunda passada" "$(cat "$T/saida")"
[ "$(wc -l < "$T/curl.log")" = 1 ] && [ "$(wc -l < "$T/rustup-init.log")" = 1 ] \
  && ok "nem curl nem rustup-init rodaram de novo" || falha "a segunda passada baixou ou rodou de novo"
[ "$antes" = "$(retrato)" ] && ok "a casa ficou byte a byte igual" || falha "a segunda passada escreveu" "$(diff <(printf '%s\n' "$antes") <(retrato))"
rodar "$RAIZ/scripts/rust.sh" conferir > "$T/saida" 2>&1 && ok "o doctor confere: $(cat "$T/saida")" || falha "o conferir diverge depois do aplicar" "$(cat "$T/saida")"

printf '\n--- 3. o Restaurar tira só o que trouxe ---\n'
rodar "$RAIZ/bin/meow" restaurar "$T/bk" > "$T/saida" 2>&1
[ ! -e "$T/casa/.cargo" ] && [ ! -e "$T/casa/.rustup" ] && ok "o Restaurar tirou ~/.cargo e ~/.rustup" \
  || falha "o Restaurar deixou o rust" "$(cat "$T/saida")"

printf '\n--- 4. sha errado: nada roda, nada fica ---\n'
casa
PINO="$T/pino-errado" rodar "$RAIZ/scripts/rust.sh" aplicar > "$T/saida" 2>&1; rc=$?
[ "$rc" = 2 ] && ok "erro (rc 2): $(grep -m1 'sha256' "$T/saida" | sed 's/^ *//')" || falha "rc $rc com sha errado" "$(cat "$T/saida")"
[ ! -s "$T/rustup-init.log" ] && ok "o rustup-init não rodou" || falha "o rustup-init rodou com sha errado"
[ ! -e "$T/casa/.cargo" ] && [ ! -e "$T/casa/.rustup" ] && [ ! -e "$T/casa/.local/state/meowsystem/rust/trouxe" ] \
  && ok "nem ~/.cargo, nem ~/.rustup, nem anotação" || falha "o sha errado deixou rastro" "$(find "$T/casa" | head)"
[ -z "$(find "$T" -maxdepth 1 -name 'meow-rustup.*')" ] && ok "o download temporário saiu" || falha "sobrou o download temporário"

printf '\n--- 5. sem rede: pula e não escreve ---\n'
casa; : > "$T/sem-rede"
rodar "$RAIZ/scripts/rust.sh" aplicar > "$T/saida" 2>&1; rc=$?
rm -f "$T/sem-rede"
[ "$rc" = 3 ] && [ ! -e "$T/casa/.cargo" ] && ok "sem rede: pulado (rc 3) e nada escrito" || falha "sem rede: rc $rc" "$(cat "$T/saida")"
casa
rodar env MEOW_SEM_REDE=1 "$RAIZ/scripts/rust.sh" aplicar > "$T/saida" 2>&1; rc=$?
[ "$rc" = 3 ] && [ ! -s "$T/curl.log" ] && [ ! -e "$T/casa/.cargo" ] \
  && ok "MEOW_SEM_REDE=1: pulado (rc 3) sem chamar o curl" || falha "MEOW_SEM_REDE=1: rc $rc" "$(cat "$T/saida" "$T/curl.log")"

printf '\n--- 6. um cargo novo no PATH: nada acontece ---\n'
casa
printf '#!/bin/sh\nexit 0\n' > "$T/sistema/cargo"
printf '#!/bin/sh\necho "rustc 1.94.0 (do sistema)"\n' > "$T/sistema/rustc"
chmod 755 "$T/sistema/cargo" "$T/sistema/rustc"
rodar "$RAIZ/scripts/rust.sh" aplicar > "$T/saida" 2>&1; rc=$?
[ "$rc" = 0 ] && [ ! -s "$T/curl.log" ] && [ ! -e "$T/casa/.cargo" ] \
  && ok "rust 1.94 do PATH basta: nada baixado, nada escrito" || falha "com cargo novo, rc $rc" "$(cat "$T/saida")"

printf '\n--- 7. um rustc velho no PATH: traz o rust e o põe na frente ---\n'
casa
printf '#!/bin/sh\necho "rustc 1.75.0 (do apt)"\n' > "$T/sistema/rustc"
rodar "$RAIZ/scripts/rust.sh" aplicar > "$T/saida" 2>&1; rc=$?
[ "$rc" = 1 ] && [ -s "$T/curl.log" ] && grep -q 'rust 1.95.0' "$T/saida" \
  && ok "rustc 1.75 < 1.93: baixou, e o 1.95 do ~/.cargo ganhou" || falha "com rustc velho, rc $rc" "$(cat "$T/saida")"
rm -f "$T/sistema/cargo" "$T/sistema/rustc"

printf '\n--- 8. o rustup que já existia fica ---\n'
casa
mkdir -p "$T/casa/.cargo/bin" "$T/casa/.rustup/toolchains/velho"
cat > "$T/casa/.cargo/bin/rustup" <<FIM
#!/bin/sh
echo "rustup \$*" >> "$T/rustup.log"
[ "\$1" = toolchain ] && printf '#!/bin/sh\necho "rustc 1.95.0 (stable do rustup dela)"\n' > "$T/casa/.cargo/bin/rustc"
exit 0
FIM
printf '#!/bin/sh\nexit 0\n' > "$T/casa/.cargo/bin/cargo"
printf '#!/bin/sh\necho "rustc 1.80.0 (velho)"\n' > "$T/casa/.cargo/bin/rustc"
chmod 755 "$T/casa/.cargo/bin/"*
: > "$T/rustup.log"
MEOW_BACKUPS="$T/bk" rodar "$RAIZ/scripts/rust.sh" aplicar > "$T/saida" 2>&1; rc=$?
[ "$rc" = 1 ] && [ ! -s "$T/curl.log" ] && grep -q 'toolchain install stable --profile minimal --no-self-update' "$T/rustup.log" \
  && ok "atualizou o stable pelo rustup dela, sem baixar outro" || falha "rustup existente: rc $rc" "$(cat "$T/saida" "$T/rustup.log")"
[ ! -e "$T/casa/.local/state/meowsystem/rust/trouxe" ] && [ ! -s "$T/bk/tocados.tsv" ] \
  && ok "nada anotado como trazido" || falha "anotou o rustup dela como trazido"
rodar "$RAIZ/scripts/rust.sh" remover > "$T/saida" 2>&1
[ -x "$T/casa/.cargo/bin/rustup" ] && [ -d "$T/casa/.rustup/toolchains/velho" ] \
  && ok "o remover deixa o rustup dela inteiro" || falha "o remover tirou o rustup dela"

printf '\n--- 9. ~/.cargo sem rustup: tira só o que entrou ---\n'
casa
mkdir -p "$T/casa/.cargo/registry"; printf 'dela\n' > "$T/casa/.cargo/registry/marca"
rodar "$RAIZ/scripts/rust.sh" aplicar > "$T/saida" 2>&1; rc=$?
[ "$rc" = 1 ] && ok "trouxe o rust para dentro do ~/.cargo dela" || falha "rc $rc" "$(cat "$T/saida")"
grep -qxF "$T/casa/.cargo" "$T/casa/.local/state/meowsystem/rust/trouxe" \
  && falha "anotou o ~/.cargo dela inteiro" "$(cat "$T/casa/.local/state/meowsystem/rust/trouxe")" \
  || ok "anotou: $(sed "s#$T/casa#~#" "$T/casa/.local/state/meowsystem/rust/trouxe" | paste -sd' ')"
rodar "$RAIZ/scripts/rust.sh" remover > "$T/saida" 2>&1
[ -f "$T/casa/.cargo/registry/marca" ] && [ ! -e "$T/casa/.cargo/bin" ] && [ ! -e "$T/casa/.rustup" ] \
  && ok "o remover tirou bin, env e ~/.rustup, e o registry dela ficou" || falha "o remover errou" "$(find "$T/casa/.cargo" "$T/casa/.rustup" 2>&1 | head)"

printf '\n--- 10. nada compila: o rust não faz falta ---\n'
casa
RUST_PRECISA=nao COMPOSITOR=nao FILES_MENU=nao EXTENSOES=- rodar "$RAIZ/scripts/rust.sh" aplicar > "$T/saida" 2>&1; rc=$?
[ "$rc" = 0 ] && [ ! -s "$T/curl.log" ] && ok "sem build ligado, nada baixa" || falha "sem build, rc $rc" "$(cat "$T/saida")"

printf '\n--- 11. ./install.sh sem flag: pede os pacotes de compilar e o rust ---\n'
compilar() { awk -F'\t' -v g=" $* " 'index(g, " " $1 " ")' "$RAIZ/assets/pacotes/compilar.tsv" | cut -f2 | sort -u; }
pedidos() { grep -h '^apt-get install' "$T/apt.log" | tr ' ' '\n' | grep -v '^-' | grep -vx 'apt-get\|install' | sort -u; }
instalar() { rodar bash "$RAIZ/install.sh" --etapa pacotes,rust > "$T/saida" 2>&1; }
casa; printf 'cosmic-comp\ncosmic-files\n' > "$T/instalados"
RUST_PRECISA= instalar
faltam="$(comm -23 <(compilar applets compositor menu-arquivos) <(pedidos) | paste -sd' ')"
[ -z "$faltam" ] && ok "o apt recebeu os $(compilar applets compositor menu-arquivos | wc -l) pacotes de compilar (applets, compositor, Menu do Arquivos)" \
  || falha "o apt não recebeu: $faltam" "$(cat "$T/apt.log" "$T/saida")"
grep -q '^sudo -n apt-get install -y --no-install-recommends' "$T/sudo.log" \
  && ok "sem ponte, pelo sudo -n do carimbo da senha" || falha "o apt não foi pelo sudo -n" "$(cat "$T/sudo.log")"
[ -s "$T/rustup-init.log" ] && [ -x "$T/casa/.cargo/bin/cargo" ] && ok "e o rustup veio na mesma passada" \
  || falha "o install não trouxe o rust" "$(cat "$T/saida")"
grep -qE '\b(instale à mão|rode|digite|sudo apt-get install)\b' "$T/saida" \
  && falha "o install manda digitar" "$(grep -E 'instale|rode|digite|sudo apt' "$T/saida")" || ok "nenhuma linha manda digitar"

printf '\n--- 12. a segunda passada não pede nada ---\n'
: > "$T/apt.log"; : > "$T/curl.log"
RUST_PRECISA= instalar
[ -z "$(comm -12 <(compilar applets compositor menu-arquivos) <(pedidos))" ] && [ ! -s "$T/curl.log" ] \
  && ok "nenhum pacote de compilar e nenhum download na segunda passada" || falha "a segunda passada pediu de novo" "$(cat "$T/apt.log" "$T/curl.log")"

printf '\n--- 13. COMPOSITOR="nao" no meow.conf: nada do compositor ---\n'
so_do_compositor() { comm -23 <(compilar compositor) <(compilar applets menu-arquivos); }
casa; printf 'cosmic-comp\ncosmic-files\n' > "$T/instalados"
sed 's/^COMPOSITOR="sim"/COMPOSITOR="nao"/' "$RAIZ/meow.conf.exemplo" > "$T/casa/.config/meow/meow.conf"
COMPOSITOR= RUST_PRECISA= instalar
vazou="$(comm -12 <(so_do_compositor) <(pedidos) | paste -sd' ')"
[ -z "$vazou" ] && [ -n "$(pedidos)" ] && ok "sem o compositor, nenhum dos $(so_do_compositor | wc -l) pacotes só dele" \
  || falha "COMPOSITOR=nao pediu: ${vazou:-(nada pedido)}" "$(cat "$T/apt.log")"

printf '\n--- 14. com a ponte root viva, a lista desce por ela, sem sudo de apt ---\n'
casa; printf 'cosmic-comp\ncosmic-files\n' > "$T/instalados"
mkdir -p "$T/ponte"
cat > "$T/ponte/ponte_root.sh" <<FIM
#!/bin/bash
case "\$1" in
  estado) exit 0 ;;
  pacotes) PERMITIDOS="\$(sed -n 's/^ *PERMITIDOS=" \\(.*\\) "\$/\\1/p' "$RAIZ/scripts/ponte_root.sh")"
           while IFS= read -r n; do
             [ -n "\$n" ] || continue
             case " \$PERMITIDOS " in *" \$n "*) echo "\$n" >> "$T/instalados"; echo "ponte \$n" >> "$T/ponte.log" ;;
               *) echo "fora da lista: \$n" >&2; exit 1 ;; esac
           done ;;
  *) exit 1 ;;
esac
FIM
chmod 755 "$T/ponte/ponte_root.sh"; : > "$T/ponte.log"
RUST_PRECISA= rodar env MEOW_PONTE="$T/ponte/ponte_root.sh" bash "$RAIZ/install.sh" --etapa pacotes > "$T/saida" 2>&1
faltam="$(comm -23 <(compilar applets compositor menu-arquivos) <(sed 's/^ponte //' "$T/ponte.log" | sort -u) | paste -sd' ')"
[ -z "$faltam" ] && [ ! -s "$T/apt.log" ] && ok "a ponte aceitou e instalou toda a lista, sem senha" \
  || falha "a ponte não levou: ${faltam:-(o apt foi chamado por fora)}" "$(cat "$T/saida" "$T/apt.log")"

printf '\n--- 15. o .deb recomenda a mesma lista ---\n'
rec="$(sed -n 's/^Recommends: //p' "$RAIZ/packaging/deb/control")"
[[ $rec == *@COMPILAR@* ]] && grep -q 'compilar.tsv' "$RAIZ/scripts/deb.sh" \
  && ok "o Recommends do control vem do compilar.tsv (o tests/deb.sh confere o .deb gerado)" \
  || falha "o control não lê a lista de compilar" "$rec"

printf '\n--- 16. deb-src desligado: o fato, sem mandar digitar ---\n'
for f in scripts/compositor_patches.sh scripts/files_menu.sh; do
  grep -q 'não servem código-fonte (sem deb-src)' "$RAIZ/$f" && ! grep -q 'deb-src está habilitado' "$RAIZ/$f" \
    && ok "$f diz o fato" || falha "$f ainda pergunta pelo deb-src"
done

printf '\n--- 17. o install roda de uma árvore sem .git (o arquivo do GitHub) ---\n'
mkdir -p "$T/zip"
if git -C "$RAIZ" ls-files -z --cached --others --exclude-standard \
     | (cd "$RAIZ" && tar --null -T - -cf - 2>/dev/null) | tar -xf - -C "$T/zip"; then
  casa; printf 'cosmic-comp\ncosmic-files\n' > "$T/instalados"
  [ ! -e "$T/zip/.git" ] || falha "a cópia tem .git"
  RUST_PRECISA= rodar bash "$T/zip/install.sh" --etapa pacotes,rust > "$T/saida" 2>&1; rc=$?
  [ "$rc" = 0 ] && [ -x "$T/casa/.cargo/bin/cargo" ] && [ -n "$(pedidos)" ] \
    && ok "sem .git: o install sai 0, pede os pacotes e traz o rust" || falha "sem .git, rc $rc" "$(cat "$T/saida")"
else
  falha "não consegui montar a árvore sem .git"
fi

[ ! -s "$T/recusas.log" ] && ok "nenhum comando recusado foi chamado" || falha "chamou o que não devia" "$(cat "$T/recusas.log")"

printf '\n'
[ "$falhas" -eq 0 ] && { printf 'tudo certo\n'; exit 0; }
printf '%d falha(s)\n' "$falhas"; exit 1

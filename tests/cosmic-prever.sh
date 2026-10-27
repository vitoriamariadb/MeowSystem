#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
RH="${RUSTUP_HOME:-$HOME/.rustup}"; CH="${CARGO_HOME:-$HOME/.cargo}"
if [ ! -d "$RH/toolchains" ]; then
  _lar="$(getent passwd "$(id -un)" | cut -d: -f6)"
  [ -d "$_lar/.rustup/toolchains" ] && { RH="$_lar/.rustup"; CH="$_lar/.cargo"; }
fi
falhas=0
mkdir -p "$T/ferramentas"
for _c in just make cargo; do printf '#!/bin/sh\nexit 1\n' > "$T/ferramentas/$_c"; chmod 755 "$T/ferramentas/$_c"; done
PATH="$T/ferramentas:$PATH"
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
command -v dpkg-deb >/dev/null || { echo "cosmic-prever: pulado — sem dpkg-deb"; exit 0; }

mkdir -p "$T/sistema/com.system76.CosmicComp/v1"

printf 'chave\tcom.system76.CosmicComp\tautotile\tcosmic-comp\tscripts/janelas.sh\n'  > "$T/contrato.tsv"
printf 'chave\tcom.system76.CosmicComp\tpinned_workspaces\tcosmic-comp\tscripts/areas.sh\n' >> "$T/contrato.tsv"
printf 'chave\tcom.system76.CosmicComp\tleitura_temperatura\tcosmic-comp\tpatch:x.patch\n' >> "$T/contrato.tsv"
mkdir -p "$T/patches"
printf 'req  brinquedo.patch  MEOW-BRINQUEDO\n' > "$T/patches/series"
cat > "$T/patches/brinquedo.patch" <<'FIM'
--- a/src/main.rs
+++ b/src/main.rs
@@ -1,3 +1,4 @@
 fn main() {
     println!("oi");
+    let _m = "MEOW-BRINQUEDO";
 }
FIM

montar() {
  local d="$T/pkg-$1"
  mkdir -p "$d/DEBIAN" "$d/usr/bin" "$d/usr/share/cosmic/com.system76.CosmicComp/$3"
  printf 'Package: cosmic-comp\nVersion: %s\nArchitecture: all\nMaintainer: teste <t@t>\nDescription: brinquedo\n' "$2" > "$d/DEBIAN/control"
  printf '%s\n' "$4" > "$d/usr/bin/cosmic-comp"
  if [ "$1" = quebrado ]; then
    mkdir -p "$d/usr/share/applications"
    printf '[Desktop Entry]\nName=Brinquedo\nIcon=com.system76.CosmicBrinquedo\nType=Application\n' \
      > "$d/usr/share/applications/com.system76.CosmicBrinquedo.desktop"
  fi
  mkdir -p "$T/debs-$1"
  dpkg-deb -b --root-owner-group "$d" "$T/debs-$1/cosmic-comp_$2_all.deb" >/dev/null 2>&1 || return 1
  local f="$T/fonte-$1/cosmic-comp-$2"
  mkdir -p "$f/src"
  printf '[package]\nname = "cosmic-comp"\nrust-version = "%s"\n' "$6" > "$f/Cargo.toml"
  printf 'fn main() {\n    %s\n}\n' "$5" > "$f/src/main.rs"
  tar -cJf "$T/fonte-$1/cosmic-comp_$2.tar.xz" -C "$T/fonte-$1" "cosmic-comp-$2"
}
montar bom      "1.0~bom"      v1 "autotile pinned_workspaces" 'println!("oi");'       "1.0"   || { falha "não montei o .deb bom"; exit 1; }
montar quebrado "1.0~quebrado" v3 "autotile"                   'println!("mudou");'    "999.0" || { falha "não montei o .deb quebrado"; exit 1; }

prever() {
  HOME="$T/home-$1" MEOW_ESTADO="$T/home-$1/estado" CV_CONTRATO="$T/contrato.tsv" \
  CV_SERIE="$T/patches/series" CV_PATCHES="$T/patches" CV_SISTEMA="$T/sistema" \
  CV_SAIDA="$T/saida-$1.tsv" CV_TRABALHO="$T/trabalho-$1" CV_GUARDA="$T/guarda-$1" \
  RUSTUP_HOME="$RH" CARGO_HOME="$CH" \
    "$RAIZ/scripts/cosmic_prever.sh" --debs "$T/debs-$1" --fontes "$T/fonte-$1" --sem-rede >/dev/null 2>&1
}
veredito() { awk -F'\t' -v i="$2" -v v="$3" '$1==i && $2==v' "$T/saida-$1.tsv" | grep -c .; }

echo "== candidato bom"
prever bom; rc=$?
[ "$rc" = 0 ] && ok "rc 0 sem vermelho" || falha "rc $rc no candidato bom"
[ "$(veredito bom esquema verde)" -ge 1 ] && ok "esquema igual: verde" || falha "esquema não saiu verde"
[ "$(veredito bom chave verde)" = 3 ] && ok "as 3 chaves verdes (a do patch, ausente, é a esperada)" || falha "chaves: $(cut -f1,2 "$T/saida-bom.tsv" | tr '\n' ' ')"
[ "$(veredito bom série verde)" = 1 ] && ok "o patch entra com -F0" || falha "a série não saiu verde"
[ "$(veredito bom ferramenta verde)" = 1 ] && ok "a ferramenta de build existe: verde" || falha "a ferramenta não saiu verde"
grep -q vermelho "$T/saida-bom.tsv" && falha "há vermelho no bom: $(grep vermelho "$T/saida-bom.tsv")" || ok "nenhum vermelho"

echo "== candidato quebrado"
prever quebrado; rc=$?
[ "$rc" = 1 ] && ok "rc 1 com vermelho" || falha "rc $rc no candidato quebrado"
[ "$(veredito quebrado esquema amarelo)" = 1 ] && ok "esquema v1 -> v3: amarelo" || falha "o v3 não foi acusado"
[ "$(veredito quebrado chave vermelho)" = 1 ] && ok "a chave que sumiu: vermelho" || falha "a chave sumida não saiu vermelha"
[ "$(veredito quebrado série vermelho)" = 1 ] && ok "o req que não entra: vermelho" || falha "a série não saiu vermelha"
[ "$(veredito quebrado icones amarelo)" = 1 ] && ok "o .desktop novo sem desenho: amarelo" || falha "o .desktop novo não foi acusado"
[ "$(veredito bom icones amarelo)" = 0 ] && ok "o bom não traz .desktop novo" || falha "o bom acusou ícone"
if RUSTUP_HOME="$RH" CARGO_HOME="$CH" RUSTUP_AUTO_INSTALL=0 rustc --version >/dev/null 2>&1; then
  [ "$(veredito quebrado toolchain vermelho)" = 1 ] && ok "rust-version 999.0: vermelho" || falha "o toolchain não saiu vermelho"
else
  ok "sem rustc nesta máquina: toolchain não medido (pulado)"
fi
if [ -f "$T/trabalho-quebrado/src/cosmic-comp-1.0~quebrado/.pronto" ]; then
  ok "o fonte foi aberto no diretório de trabalho, não no dos fontes"
else
  falha "o fonte não foi aberto"
fi

RA="$T/raiz-apps"; CI="$T/casa-completar"; FB="$T/falso-dpkg"
mkdir -p "$RA/usr/share/applications" "$RA/usr/share/icons/hicolor/scalable/apps" "$FB" \
         "$CI/.local/share/icons/MeowSystem-Icons/scalable/apps"
printf '[Desktop Entry]\nName=Falso\nExec=true\nIcon=com.system76.CosmicFalso\nType=Application\n' \
  > "$RA/usr/share/applications/com.system76.CosmicFalso.desktop"
printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><title>falso</title></svg>\n' \
  > "$RA/usr/share/icons/hicolor/scalable/apps/com.system76.CosmicFalso.svg"
printf '#!/bin/sh\necho cosmic-falso\n' > "$FB/dpkg-query"
printf '#!/bin/sh\n[ "$1" = -L ] && echo /usr/share/applications/com.system76.CosmicFalso.desktop\n' > "$FB/dpkg"
printf '#!/bin/sh\nexit 1\n' > "$FB/sudo"
chmod 755 "$FB"/*
printf '[Icon Theme]\nName=MeowSystem-Icons\nDirectories=scalable/apps\n\n[scalable/apps]\nSize=48\nType=Scalable\n' \
  > "$CI/.local/share/icons/MeowSystem-Icons/index.theme"
completar() {
  env -i PATH="$FB:$PATH" HOME="$CI" MEOW_RAIZ="$RAIZ" NO_COLOR=1 CV_RAIZ_APPS="$RA" \
    PACK=dracula FLAVOR=dracula ACCENT=mauve "$RAIZ/scripts/completar_icones.sh" >/dev/null 2>&1
}
ALVO_CI="$CI/.local/share/icons/MeowSystem-Icons/scalable/apps/com.system76.CosmicFalso.svg"
completar
if [ -f "$ALVO_CI" ] && [ "$(cat "$ALVO_CI")" = "$(cat "$RA/usr/share/icons/hicolor/scalable/apps/com.system76.CosmicFalso.svg")" ]; then
  antes="$(stat -c %Y.%s "$ALVO_CI")"; sleep 1; completar
  [ "$antes" = "$(stat -c %Y.%s "$ALVO_CI")" ] \
    && ok "o app do COSMIC sem desenho ganha o ícone de fábrica no tema, e a 2ª passada não escreve" \
    || falha "a 2ª passada do completar reescreveu o ícone do app do COSMIC"
else
  falha "o completar não pôs no tema o ícone do app do COSMIC sem desenho"
fi

echo
if [ "$falhas" = 0 ]; then echo "cosmic-prever: tudo certo"; exit 0; fi
echo "cosmic-prever: $falhas falha(s)"; exit 1

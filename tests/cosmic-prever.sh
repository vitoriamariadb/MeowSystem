#!/usr/bin/env bash
# cosmic-prever.sh — o pré-voo do COSMIC candidato distingue o bom do quebrado? (P76)
#
# Dois candidatos de brinquedo do `cosmic-comp`, montados com `dpkg-deb -b`, e
# dois fontes de brinquedo:
#   bom       mesmo `v1` de hoje, as duas chaves do contrato no binário, o patch
#             da série entra com `-F0`, `rust-version` antigo;
#   quebrado  o pacote sobe para `v3`, uma chave do contrato sumiu do binário,
#             o hunk do patch não casa mais, `rust-version` que nenhum rustc tem,
#             e entra um `.desktop` cujo ícone nenhum mapa desenha.
# O veredito precisa sair diferente: o bom sem vermelho (rc 0), o quebrado com
# vermelho em chave, série e toolchain (rc 1) e amarelo em esquema.
# Tudo em diretórios de brinquedo: nada de apt, rede, sudo nem HOME de verdade.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# O rustup de verdade, lido ANTES de o HOME virar brinquedo: a sonda pergunta
# ao rustc de dentro da árvore, e o rustup acha os toolchains pelo RUSTUP_HOME.
RH="${RUSTUP_HOME:-$HOME/.rustup}"; CH="${CARGO_HOME:-$HOME/.cargo}"
# A SUÍTE RODA COM HOME DE BRINQUEDO (conferência da P76): aí o `$HOME/.rustup`
# não existe, o proxy `rustc` do PATH não acha toolchain nenhum, e o teste
# acusava "o toolchain não saiu vermelho" sem a sonda ter errado. O rustup de
# verdade é lido (só lido) no lar da conta, que o `getent` diz.
if [ ! -d "$RH/toolchains" ]; then
  _lar="$(getent passwd "$(id -un)" | cut -d: -f6)"
  [ -d "$_lar/.rustup/toolchains" ] && { RH="$_lar/.rustup"; CH="$_lar/.cargo"; }
fi
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
command -v dpkg-deb >/dev/null || { echo "cosmic-prever: pulado — sem dpkg-deb"; exit 0; }

# O sistema de hoje: o namespace do compositor em v1.
mkdir -p "$T/sistema/com.system76.CosmicComp/v1"

# O contrato e a série de brinquedo.
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

montar() { # $1 nome $2 versão $3 v-do-esquema $4 chaves-no-binário $5 corpo-do-main $6 rust-version
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

prever() { # $1 nome
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

echo
if [ "$falhas" = 0 ]; then echo "cosmic-prever: tudo certo"; exit 0; fi
echo "cosmic-prever: $falhas falha(s)"; exit 1

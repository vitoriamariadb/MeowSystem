#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }
command -v dpkg-deb >/dev/null || { echo "sentinela: pulado — sem dpkg-deb"; exit 0; }

mkdir -p "$T/bin" "$T/home" "$T/sistema/com.system76.CosmicComp/v1" "$T/patches"
cat > "$T/bin/apt" <<FIM
#!/bin/sh
echo "apt \$*" >> "$T/apt.log"
echo "Listing..."
cat "$T/fila.txt" 2>/dev/null
FIM
for c in just make cargo; do printf '#!/bin/sh\nexit 1\n' > "$T/bin/$c"; done
chmod 755 "$T/bin"/*

printf 'chave\tcom.system76.CosmicComp\tautotile\tcosmic-comp\tscripts/janelas.sh\n' > "$T/contrato.tsv"
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
  mkdir -p "$d/DEBIAN" "$d/usr/bin" "$d/usr/share/cosmic/com.system76.CosmicComp/v1"
  printf 'Package: cosmic-comp\nVersion: %s\nArchitecture: all\nMaintainer: teste <t@t>\nDescription: brinquedo\n' "$2" > "$d/DEBIAN/control"
  printf 'autotile\n' > "$d/usr/bin/cosmic-comp"
  mkdir -p "$T/debs-$1"
  dpkg-deb -b --root-owner-group "$d" "$T/debs-$1/cosmic-comp_$2_all.deb" >/dev/null 2>&1 || return 1
  local f="$T/fonte-$1/cosmic-comp-$2"
  mkdir -p "$f/src"
  printf '[package]\nname = "cosmic-comp"\nrust-version = "1.0"\n' > "$f/Cargo.toml"
  [ "$1" = quebrado ] && printf 'build-vendored:\n\ttrue\n' > "$f/justfile"
  printf 'fn main() {\n    %s\n}\n' "$3" > "$f/src/main.rs"
  tar -cJf "$T/fonte-$1/cosmic-comp_$2.tar.xz" -C "$T/fonte-$1" "cosmic-comp-$2"
}
montar bom      "1.0~bom"      'println!("oi");'    || { falha "não montei o .deb bom"; exit 1; }
montar quebrado "1.0~quebrado" 'println!("mudou");' || { falha "não montei o .deb quebrado"; exit 1; }

cat > "$T/prever" <<FIM
#!/bin/sh
echo prever >> "$T/prever.log"
exec "$RAIZ/scripts/cosmic_prever.sh" "\$@"
FIM
chmod 755 "$T/prever"

E="$T/home/.local/state/meowsystem"
sentinela() {
  local c="$1"; shift
  env HOME="$T/home" PATH="$T/bin:$PATH" MEOW_ESTADO="$E" MEOW_CONF="$T/nao-existe.conf" \
      SN_PREVER="$T/prever" SN_PREVER_ARGS="--debs $T/debs-$c --fontes $T/fonte-$c" \
      CV_CONTRATO="$T/contrato.tsv" CV_SERIE="$T/patches/series" CV_PATCHES="$T/patches" \
      CV_SISTEMA="$T/sistema" CV_TRABALHO="$T/trabalho-$c" CV_GUARDA="$T/guarda-$c" CV_REDE=nao \
      "$@" "$RAIZ/scripts/sentinela.sh" >"$T/saida" 2>&1
}
contar() { [ -f "$2" ] || { echo 0; return 0; }; grep -c "$1" "$2" || true; }
chamadas() { contar prever "$T/prever.log"; }
cartoes() { contar . "$E/precisa-de-gente.tsv"; }
estado() { awk -F'\t' -v k="$1" '$1==k {print $2}' "$E/sentinela.tsv" 2>/dev/null; }

echo "== 1. a fila sem COSMIC: nada a medir, nenhum cartão"
: > "$T/fila.txt"
sentinela bom; rc=$?
igual "rc 0" "$rc" 0
igual "o prever não rodou" "$(chamadas)" 0
igual "o estado diz que não há candidato" "$(estado resultado)" nada
igual "nenhum cartão" "$(cartoes)" 0
grep -q 'apt list --upgradable' "$T/apt.log" && ok "só pergunta ao apt o que há para atualizar (list --upgradable)" || falha "não chamou apt list --upgradable"
grep -qv 'list --upgradable' "$T/apt.log" && falha "chamou o apt para outra coisa: $(grep -v 'list --upgradable' "$T/apt.log")" || ok "o apt só foi lido"

echo "== 2. o candidato bom: mede, grava e não pede ninguém"
printf 'cosmic-comp/jammy 1.0~bom amd64 [upgradable from: 0.9]\n' > "$T/fila.txt"
sentinela bom; rc=$?
igual "rc 0" "$rc" 0
igual "o prever rodou uma vez" "$(chamadas)" 1
igual "resultado verde ou amarelo, nunca vermelho" "$(estado resultado | grep -c vermelho)" 0
[ -n "$(estado candidato)" ] && ok "o estado guarda a assinatura do candidato" || falha "o sentinela.tsv não tem o candidato"
igual "nenhum cartão" "$(cartoes)" 0

echo "== 3. o mesmo candidato de novo: nada novo, nada escrito"
antes="$(stat -c %Y.%s "$E/sentinela.tsv")"; sleep 1
sentinela bom; rc=$?
igual "rc 0" "$rc" 0
igual "o prever não rodou de novo" "$(chamadas)" 1
igual "o sentinela.tsv não foi tocado" "$(stat -c %Y.%s "$E/sentinela.tsv")" "$antes"

echo "== 4. o candidato quebrado: UM cartão, com desde quando e o porquê"
printf 'cosmic-comp/jammy 1.0~quebrado amd64 [upgradable from: 0.9]\n' > "$T/fila.txt"
sentinela quebrado CV_SEM=just; rc=$?
igual "rc 1 (há vermelho)" "$rc" 1
igual "resultado vermelho" "$(estado resultado)" vermelho
igual "um cartão só" "$(cartoes)" 1
linha="$(cat "$E/precisa-de-gente.tsv" 2>/dev/null)"
igual "o id do cartão" "$(printf '%s' "$linha" | cut -f1)" sentinela-cosmic
printf '%s' "$linha" | cut -f3 | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' && ok "tem o desde quando (data)" || falha "o cartão não tem data: $linha"
printf '%s' "$linha" | cut -f4 | grep -q 'brinquedo.patch' && ok "o porquê cita o patch obrigatório que não entra" || falha "o porquê não cita a série: $linha"
printf '%s' "$linha" | cut -f4 | grep -qi 'just' && ok "o porquê cita a ferramenta de build que falta" || falha "o porquê não cita o just: $linha"
printf '%s' "$linha" | cut -f2 | grep -q . && [ "$(printf '%s' "$linha" | cut -f2 | wc -c)" -le 60 ] && ok "o nome do cartão é curto" || falha "o nome do cartão é longo ou vazio: $linha"
printf '%s' "$linha" | grep -qiE 'rode|digite|execute' && falha "o cartão manda digitar: $linha" || ok "o cartão não manda digitar"

echo "== 5. o mesmo candidato quebrado de novo: o cartão fica igual (idempotente)"
c1="$(cat "$E/precisa-de-gente.tsv")"; s1="$(stat -c %Y.%s "$E/sentinela.tsv")"; sleep 1
sentinela quebrado CV_SEM=just; rc=$?
igual "o prever não rodou de novo" "$(chamadas)" 2
igual "o cartão é byte a byte o mesmo" "$(cat "$E/precisa-de-gente.tsv")" "$c1"
igual "o sentinela.tsv não foi tocado" "$(stat -c %Y.%s "$E/sentinela.tsv")" "$s1"

echo "== 6. o desde quando sobrevive a uma medida nova do mesmo problema"
d1="$(printf '%s' "$c1" | cut -f3)"; sleep 1
printf 'cosmic-comp/jammy 1.0~quebrado amd64 [upgradable from: 0.8]\ncosmic-files/jammy 1.0~quebrado amd64 [upgradable from: 0.8]\n' > "$T/fila.txt"
sentinela quebrado CV_SEM=just; rc=$?
igual "o cartão continua um só" "$(cartoes)" 1
igual "o desde quando é o de antes" "$(cut -f3 "$E/precisa-de-gente.tsv")" "$d1"

echo "== 6b. um candidato bom toma o lugar do quebrado: o cartão some, sem gente"
printf 'cosmic-comp/jammy 1.0~bom amd64 [upgradable from: 0.9]\n' > "$T/fila.txt"
sentinela bom; rc=$?
igual "rc 0" "$rc" 0
igual "resultado sem vermelho" "$(estado resultado | grep -c vermelho)" 0
igual "nenhum cartão" "$(cartoes)" 0

echo "== 7. a fila esvazia (quem usa atualizou): o cartão some sozinho"
: > "$T/fila.txt"
sentinela bom; rc=$?
igual "rc 0" "$rc" 0
igual "o estado volta a nada" "$(estado resultado)" nada
igual "nenhum cartão" "$(cartoes)" 0

echo "== 8. o seco não escreve nada"
rm -rf "$E"; printf 'cosmic-comp/jammy 1.0~quebrado amd64 [upgradable from: 0.9]\n' > "$T/fila.txt"
sentinela quebrado MEOW_DRY_RUN=1 CV_SEM=just
[ ! -e "$E/sentinela.tsv" ] && [ ! -e "$E/precisa-de-gente.tsv" ] && ok "o seco não gravou estado nem cartão" || falha "o seco escreveu em $E"

echo "== 9. a unidade: timer diário de usuário, leve, e a etapa do instalador o arma"
T1="$RAIZ/systemd/meow-sentinela.timer"; S1="$RAIZ/systemd/meow-sentinela.service"
if [ -f "$T1" ] && grep -q '^OnCalendar=\*-\*-\* ' "$T1" && grep -q '^Persistent=true$' "$T1" \
   && grep -q '^Unit=meow-sentinela.service$' "$T1" && grep -q '^WantedBy=timers.target$' "$T1"; then
  ok "meow-sentinela.timer: diário, Persistent, em timers.target"
else
  falha "falta o meow-sentinela.timer (diário, Persistent=true, Unit=, WantedBy=timers.target)"
fi
if [ -f "$S1" ] && grep -q '^Nice=19$' "$S1" && grep -q '^IOSchedulingClass=idle$' "$S1" \
   && grep -q 'scripts/sentinela.sh' "$S1" && grep -q 'AUTO_REPARO' "$S1"; then
  ok "meow-sentinela.service: Nice 19, IO ocioso, sob AUTO_REPARO, roda o script"
else
  falha "falta o meow-sentinela.service (Nice 19, IO ocioso, AUTO_REPARO, scripts/sentinela.sh)"
fi
P1="$RAIZ/systemd/meow-sentinela.path"
if [ -f "$P1" ] && grep -q '^PathChanged=/var/lib/meowsystem/apt-mudou$' "$P1" \
   && grep -q '^Unit=meow-sentinela.service$' "$P1" && grep -q '^WantedBy=default.target$' "$P1"; then
  ok "meow-sentinela.path: relê a fila depois de todo apt"
else
  falha "falta o meow-sentinela.path (PathChanged=/var/lib/meowsystem/apt-mudou, Unit=meow-sentinela.service)"
fi
etapa="$(sed -n '/^etapa_vigia_apt()/,/^}/p' "$RAIZ/install.sh")"
grep -q 'meow-sentinela.service' <<< "$etapa" && grep -q 'meow-sentinela.timer' <<< "$etapa" \
  && grep -qE 'ligaveis=\(.*meow-sentinela\.path' <<< "$etapa" \
  && grep -q 'wants/meow-sentinela.path' <<< "$etapa" \
  && ok "o instalador põe as unidades e arma o timer e o path" || falha "a etapa_vigia_apt não instala ou não arma o sentinela"
for u in meow-sentinela.timer meow-sentinela.service meow-sentinela.path; do
  n="$(grep -c "$u" "$RAIZ/lib/desinstalar.sh")"
  [ "$n" -ge 1 ] && ok "o desinstalador cita $u" || falha "o desinstalador não cita $u"
done

echo
if [ "$falhas" = 0 ]; then echo "sentinela: tudo certo"; exit 0; fi
echo "sentinela: $falhas falha(s)"; exit 1

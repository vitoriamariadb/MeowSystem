#!/usr/bin/env bash
# precisa-de-gente.sh — o que a máquina não conserta sozinha aparece num cartão só,
# com desde quando, e some quando resolvido? (P86)
#
#   1. os dois verbos do `lib/comum.sh`: registrar é idempotente (o desde quando é do
#      primeiro registro e a repetição não escreve nada), e resolver tira a linha;
#   2. a fonte «patch obrigatório que não entra» (`garantir_builds.sh`, degrau 4):
#      a linha nasce, a segunda passagem não escreve, e o rebase a tira;
#   3. o servidor lê a lista (`precisa_de_gente()`), e a Início monta UM cartão
#      com uma linha por item (o `app.js` no vm do node, sem navegador).
# HOME, estado e casa de brinquedo; o compositor e o menu são registros de uma linha,
# e apt, cargo, sudo e systemd recusam.
#   0 = passou · 1 = falhou
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
gente() { # $1.. o que rodar com a lib carregada
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY HOME="$T/home" PATH="$T/bin:$PATH" \
      MEOW_ESTADO="$E" MEOW_RAIZ="$RAIZ" NO_COLOR=1 MEOW_CONF="$T/nao-existe.conf" \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh"; "$@"' _ "$@"
}
linhas() { [ -f "$ARQ" ] && wc -l < "$ARQ" || echo 0; }
foto() { printf '%s %s' "$(stat -c %Y.%s "$ARQ" 2>/dev/null)" "$(cat "$ARQ" 2>/dev/null)"; }

echo "== 1. os verbos"
gente meow_precisa_de_gente_resolvida inexistente
[ ! -e "$ARQ" ] && ok "resolver o que não existe não cria arquivo" || falha "resolver sem linha criou o arquivo"
gente meow_precisa_de_gente um "Primeiro" "porque sim"
gente meow_precisa_de_gente dois "Segundo" "porque também"
igual "duas linhas" "$(linhas)" 2
d1="$(awk -F'\t' '$1=="um" {print $3}' "$ARQ")"
printf '%s' "$d1" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' && ok "o desde quando é uma data" || falha "sem data: $d1"
antes="$(foto)"; sleep 1
gente meow_precisa_de_gente um "Primeiro" "porque sim"
igual "o mesmo registro não escreve nada" "$(foto)" "$antes"
gente meow_precisa_de_gente um "Primeiro" "agora por outro motivo"
igual "o porquê novo entra" "$(awk -F'\t' '$1=="um" {print $4}' "$ARQ")" "agora por outro motivo"
igual "e o desde quando é o do primeiro registro" "$(awk -F'\t' '$1=="um" {print $3}' "$ARQ")" "$d1"
igual "ainda uma linha por id" "$(linhas)" 2
gente meow_precisa_de_gente tab $'com\ttab' $'com\nquebra'
igual "tabulação e quebra não racham a linha" "$(awk -F'\t' '$1=="tab" {print NF}' "$ARQ")" 4
gente meow_precisa_de_gente_resolvida tab
gente meow_precisa_de_gente_resolvida um
igual "resolvida, a linha sai e a outra fica" "$(cut -f1 "$ARQ")" dois
antes="$(foto)"; MEOW_DRY_RUN=1 gente meow_precisa_de_gente tres "Terceiro" "no seco"
MEOW_DRY_RUN=1 gente meow_precisa_de_gente_resolvida dois
igual "o seco não escreve" "$(foto)" "$antes"
gente meow_precisa_de_gente_resolvida dois
igual "esvaziado" "$(linhas)" 0

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
for b in cosmic-files cosmic-files-applet; do echo MEOW-FILES-WALLPAPER-PATCH-1 > "$E/cosmic-files/\$v/\$b"; done
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
igual "o req que não entra: uma linha no cartão" "$(linhas)" 1
igual "o id" "$(cut -f1 "$ARQ")" patch-obrigatorio
cut -f4 "$ARQ" | grep -q 'sem-workspace-vazio.patch' && cut -f4 "$ARQ" | grep -q '0.9~a' \
  && ok "o porquê cita a versão e o patch" || falha "o porquê não cita versão e patch: $(cut -f4 "$ARQ")"
cut -f2 "$ARQ" | grep -qiE 'rode|digite' && falha "o nome manda digitar" || ok "o nome não manda digitar"
antes="$(foto)"; sleep 1
builds
igual "a segunda passagem não escreve no cartão" "$(foto)" "$antes"
rm -f "$T/req-falha"; sleep 0.05; touch "$T/patches/series"
builds
igual "o rebase chega (a série mudou) e o cartão some" "$(linhas)" 0

echo "== 3. o servidor lê a lista"
gente meow_precisa_de_gente sentinela-cosmic "O COSMIC da fila não entra" "serie: brinquedo.patch é obrigatório"
gente meow_precisa_de_gente patch-obrigatorio "Patch obrigatório precisa de rebase" "cosmic-comp 0.9~a: a série não entra"
r="$(env -i PATH="$PATH" HOME="$T/home" MEOW_ESTADO="$E" python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
l = servidor.precisa_de_gente()
print("n=%d" % len(l))
print("campos=%s" % ",".join(sorted(l[0])))
print("ids=%s" % ",".join(i["id"] for i in l))
PY
)"
{ grep -qx 'n=2' <<< "$r" && grep -qx 'campos=desde,id,nome,porque' <<< "$r" \
  && grep -qx 'ids=sentinela-cosmic,patch-obrigatorio' <<< "$r"; } \
  && ok "precisa_de_gente() devolve id, nome, desde e porquê, na ordem" || falha "o servidor leu errado: $r"
grep -q '"/api/precisa-de-gente"' "$RAIZ/app/servidor.py" && ok "a rota /api/precisa-de-gente existe" || falha "falta a rota /api/precisa-de-gente"

echo "== 4. a Início monta UM cartão"
if command -v node >/dev/null; then
  r="$(node - "$RAIZ/app/pagina/app.js" "$ARQ" <<'JS' 2>&1
const fs = require("fs"), vm = require("vm");
const src = fs.readFileSync(process.argv[2], "utf8");
const itens = fs.readFileSync(process.argv[3], "utf8").trim().split("\n").map((l) => {
  const [id, nome, desde, porque] = l.split("\t"); return { id, nome, desde, porque }; });
const pega = (nome) => {
  const i = src.indexOf("function " + nome + "(");
  if (i < 0) throw new Error("falta a função " + nome);
  let n = 0, j = src.indexOf("{", i);
  for (let k = j; k < src.length; k++) {
    if (src[k] === "{") n++;
    if (src[k] === "}" && --n === 0) return src.slice(i, k + 1);
  }
};
// Elementos de brinquedo: uma árvore de objetos, com o texto e as classes.
const no = (tag, a = {}, filhos = []) => ({ tag, classe: a.class || "", texto: a.texto || "", filhos: [...filhos],
  append(...c) { this.filhos.push(...c); } });
const ctx = { PRECISA_DE_GENTE: itens, elemento: no, idDeAba: (x) => x,
  gatilhoDeDica: (_id, _t, corpo) => [{ tag: "dica", texto: corpo.map((c) => c.texto).join(" "), filhos: [] }],
  selo: (tipo, o) => ({ tag: "selo", tipo, texto: o.texto, filhos: [] }) };
vm.createContext(ctx);
for (const f of ["desdeCurto", "montarPrecisaDeGente"]) vm.runInContext(pega(f), ctx);
const todos = (n, saida = []) => { saida.push(n); (n.filhos || []).forEach((f) => todos(f, saida)); return saida; };
const cartao = vm.runInContext("montarPrecisaDeGente()", ctx);
const nos = todos(cartao);
console.log("secoes=" + nos.filter((n) => n.tag === "section").length);
const linhas = nos.filter((n) => n.classe === "pendencia");
console.log("linhas=" + linhas.length);
console.log("nomes=" + nos.filter((n) => n.classe === "pendencia-frase").map((n) => n.texto).join("|"));
console.log("selos=" + nos.filter((n) => n.tag === "selo").map((n) => n.tipo + ":" + n.texto).join("|"));
console.log("dicas=" + nos.filter((n) => n.tag === "dica").map((n) => n.texto).join("|"));
console.log("titulo=" + nos.filter((n) => n.tag === "h3").map((n) => todos(n).map((x) => x.texto).join("")).join(""));
ctx.PRECISA_DE_GENTE = [];
console.log("vazio=" + (vm.runInContext("montarPrecisaDeGente()", ctx) === null));
JS
)"
  esperado_selo="$(date -d "$(cut -f3 "$ARQ" | head -1)" +%d/%m)"
  { grep -qx 'secoes=1' <<< "$r" && grep -qx 'linhas=2' <<< "$r" \
    && grep -qx 'nomes=O COSMIC da fila não entra|Patch obrigatório precisa de rebase' <<< "$r" \
    && grep -q "^selos=gente:desde $esperado_selo|gente:desde " <<< "$r" \
    && grep -q '^dicas=serie: brinquedo.patch é obrigatório|cosmic-comp 0.9~a: a série não entra$' <<< "$r" \
    && grep -qx 'titulo=Precisa de gente' <<< "$r" && grep -qx 'vazio=true' <<< "$r"; } \
    && ok "um cartão, uma linha por item, o desde quando no selo, o porquê na dica, e vazio não desenha" \
    || falha "o cartão da Início saiu diferente: $r"
else
  printf '  pulado: sem node, o cartão da Início não roda aqui\n'
fi

echo
if [ "$falhas" = 0 ]; then echo "precisa-de-gente: tudo certo"; exit 0; fi
echo "precisa-de-gente: $falhas falha(s)"; exit 1

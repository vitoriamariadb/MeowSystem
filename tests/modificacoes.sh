#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
falhou=0
falha() { printf 'FALHOU: %s\n' "$1" >&2; falhou=1; }

T="$(mktemp -d -p "${TMPDIR:-/tmp}" meow-modificacoes.XXXXXX)" || exit 2
trap 'rm -rf "$T"' EXIT
R="$T/raiz"
CASA="$T/casa"
mkdir -p "$R" "$CASA/.config/meow"

git -C "$RAIZ" ls-files -z --cached --others --exclude-standard -- install.sh bin lib scripts app assets/contratos assets/paleta packs meow.conf.exemplo VERSION \
  | while IFS= read -r -d '' rel; do
      [ -f "$RAIZ/$rel" ] || continue
      case "$rel" in scripts/temas-de-apps/*/*|packs/*/icones/*|packs/*/wallpapers/*) continue ;; esac
      mkdir -p "$R/$(dirname "$rel")"
      cp -p "$RAIZ/$rel" "$R/$rel"
    done
git init -q "$R"

mkdir -p "$R/scripts/temas-de-apps/brinquedo"
cat > "$R/scripts/temas-de-apps/brinquedo/manifesto.sh" <<'EOF'
#!/usr/bin/env bash
_br_arq() { printf '%s/brinquedo/tema.conf' "${XDG_CONFIG_HOME:-$HOME/.config}"; }
meow_app_instalado() { return 0; }
meow_app_detectar() { return 0; }
meow_app_conferir() { [ "$(cat "$(_br_arq)" 2>/dev/null)" = "tema=meow" ] && return 0; return 1; }
meow_app_aplicar() {
  meow_app_conferir && return 0
  mkdir -p "$(dirname "$(_br_arq)")"; printf 'tema=meow\n' > "$(_br_arq)"; return 1
}
meow_app_reverter() { [ -e "$(_br_arq)" ] || return 0; rm -f "$(_br_arq)"; return 1; }
EOF
printf 'brinquedo\tcorrecao\tconf\tArquivo de configuração\n' >> "$R/assets/contratos/modificacoes.tsv"
mkdir -p "$R/scripts/temas-de-apps/enfeite"
cat > "$R/scripts/temas-de-apps/enfeite/manifesto.sh" <<'EOF'
#!/usr/bin/env bash
_en_arq() { printf '%s/enfeite/tema.conf' "${XDG_CONFIG_HOME:-$HOME/.config}"; }
meow_app_instalado() { return 0; }
meow_app_detectar() {
  meow_app_tema_do_pack enfeite.arquivo
  [ -n "$MEOW_APP_TEMA" ] || { meow_app_sem "Enfeite: sem tema"; return; }
  _EN_QUERO="$(cat "$MEOW_APP_TEMA")"
  meow_app_tema_do_pack enfeite.sha256
  _EN_QUERO="$_EN_QUERO $MEOW_APP_TEMA"
}
meow_app_conferir() { meow_app_detectar || return 3; [ "$(cat "$(_en_arq)" 2>/dev/null)" = "$_EN_QUERO" ]; }
meow_app_aplicar() {
  meow_app_conferir && return 0
  meow_app_detectar || return 3
  mkdir -p "$(dirname "$(_en_arq)")"; printf '%s\n' "$_EN_QUERO" > "$(_en_arq)"; return 1
}
meow_app_reverter() { [ -e "$(_en_arq)" ] || return 0; rm -f "$(_en_arq)"; return 1; }
EOF
printf 'enfeite\taceita\t.conf\n' >> "$R/assets/contratos/modificacoes.tsv"

meow() {
  env -i PATH="$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" XDG_STATE_HOME="$CASA/.local/state" \
    XDG_DATA_HOME="$CASA/.local/share" XDG_CACHE_HOME="$CASA/.cache" MEOW_RAIZ="$R" NO_COLOR=1 LANG=C.UTF-8 \
    "$R/bin/meow" "$@"
}

saida="$(meow apps cartoes 2>/dev/null)"
printf '%s\n' "$saida" | grep -qP '^modulo\tbrinquedo\t0\t1\tnao\tbrinquedo\t' \
  || falha "o módulo de brinquedo não virou linha do cartões (desligado, fora do lugar): $(printf '%s' "$saida" | head -c 400)"
printf '%s\n' "$saida" | grep -qP '^correcao\tconf\t1$' \
  || falha "a correção declarada no contrato não aparece com o estado dela"
printf '%s\n' "$saida" | grep -qP '^correcao\tprompt\t' \
  || falha "a correção do prompt, declarada no cartão do terminal, sumiu"

printf 'APPS_ATIVOS=brinquedo\n' > "$CASA/.config/meow/meow.conf"
meow apps aplicar brinquedo >/dev/null 2>&1
[ "$(cat "$CASA/.config/brinquedo/tema.conf" 2>/dev/null)" = "tema=meow" ] || falha "aplicar não pôs o tema do brinquedo"
saida="$(meow apps cartoes 2>/dev/null)"
printf '%s\n' "$saida" | grep -qP '^modulo\tbrinquedo\t0\t0\tsim\t' || falha "ligado e aplicado, o brinquedo não aparece no lugar"
antes="$(stat -c %y "$CASA/.config/brinquedo/tema.conf" 2>/dev/null)"
meow apps aplicar brinquedo >/dev/null 2>&1
[ "$(stat -c %y "$CASA/.config/brinquedo/tema.conf" 2>/dev/null)" = "$antes" ] || falha "a segunda aplicação reescreveu o arquivo"
meow apps reverter brinquedo >/dev/null 2>&1
[ ! -e "$CASA/.config/brinquedo/tema.conf" ] || falha "tirar o tema não apagou o arquivo do brinquedo"

meow apps corrigir gerar >/dev/null 2>&1 && falha "corrigir aceitou um nome que o contrato não declara"
meow apps corrigir 'conf;true' >/dev/null 2>&1 && falha "corrigir aceitou um nome com lixo"

cartao="$(cd "$R/app" && env -i PATH="$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" MEOW_RAIZ="$R" LANG=C.UTF-8 \
  python3 -c 'import json, servidor; print(json.dumps(servidor._mod_dados(), ensure_ascii=False))' 2>/dev/null)"
python3 - "$cartao" <<'EOF' || falhou=1
import json, sys
d = json.loads(sys.argv[1] or "{}")
c = {x["id"]: x for x in d.get("cartoes", [])}
erros = []
b = c.get("brinquedo")
if not b:
    erros.append("o painel não fez cartão para o módulo de brinquedo")
else:
    if [t["pasta"] for t in b["temas"]] != ["brinquedo"]:
        erros.append("o cartão do brinquedo não traz o tema dele")
    if [x["nome"] for x in b["correcoes"]] != ["conf"]:
        erros.append("a correção declarada não entrou no cartão do brinquedo")
if "terminal" not in c or not any(x["nome"] == "prompt" for x in c["terminal"]["correcoes"]):
    erros.append("o cartão do terminal perdeu a correção do prompt")
for e in erros:
    print("FALHOU: " + e, file=sys.stderr)
sys.exit(1 if erros else 0)
EOF

servidor() {
  (cd "$R/app" && env -i PATH="$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" XDG_DATA_HOME="$CASA/.local/share" \
    MEOW_RAIZ="$R" LANG=C.UTF-8 python3 -c "import json, sys, servidor; print(json.dumps($1, ensure_ascii=False))" "${@:2}" 2>/dev/null)
}
CASA_DE_TEMAS="$CASA/.local/share/meowsystem/temas-de-apps/enfeite"
printf 'APPS_ATIVOS=enfeite\n' > "$CASA/.config/meow/meow.conf"
meow apps aplicar enfeite >/dev/null 2>&1
[ ! -e "$CASA/.config/enfeite/tema.conf" ] || falha "sem tema no pack nem adicionado, o enfeite ganhou tema"
resposta="$(servidor 'servidor._mod_tema_adicionar({"app": "enfeite", "nome": "../Meu tema.conf", "conteudo": sys.argv[1]})' \
  "$(printf 'cor=rosa' | base64 -w0)")"
grep -q '"nome": "Meu tema.conf"' <<< "$resposta" || falha "adicionar tema não guardou o arquivo com o nome limpo: $resposta"
[ "$(cat "$CASA_DE_TEMAS/padrao" 2>/dev/null)" = "Meu tema.conf" ] || falha "o tema adicionado não virou o padrão do enfeite"
[ "$(cat "$CASA_DE_TEMAS/Meu tema.conf" 2>/dev/null)" = "cor=rosa" ] || falha "o tema adicionado não está na casa do usuário"
for corpo in '{"app": "enfeite", "nome": "x.css", "conteudo": "eA=="}' '{"app": "brinquedo", "nome": "x.conf", "conteudo": "eA=="}' \
             '{"app": "enfeite", "url": "http://exemplo/x.conf"}' '{"app": "../enfeite", "nome": "x.conf", "conteudo": "eA=="}'; do
  servidor "servidor._mod_tema_adicionar($corpo)" | grep -q '"erro"' || falha "adicionar tema aceitou $corpo"
done
servidor 'servidor._mod_tema_adicionar({"app": "enfeite", "nome": "bin.conf", "conteudo": sys.argv[1]})' \
  "$(printf '\377\376\000cor' | base64 -w0)" | grep -q '"erro"' || falha "adicionar tema aceitou um binário como .conf"
formatos="$(servidor '[servidor._mod_formato_confere(e, d.encode("latin-1")) for e, d in json.loads(sys.argv[1])]' \
  '[[".qbtheme", "qres\u0000\u0000\u0000\u0003"], [".qbtheme", "cor=rosa"], [".json", "{\"id\": 1}"], [".json", "[1]"],
    [".json", "{quebrado"], [".dconf", "[/]\npalette=[]"], [".dconf", "[outro]\nx=1"], [".css", "a { b: c; }"],
    [".css", "a\u0000b"], [".css", "\u00ff\u00fe"]]')"
[ "$formatos" = "[true, false, true, false, false, true, false, true, false, false]" ] \
  || falha "a conferência de formato do tema adicionado errou: $formatos"
[ "$(ls "$CASA_DE_TEMAS")" = "$(printf 'Meu tema.conf\npadrao')" ] || falha "um pedido recusado deixou arquivo na casa de temas: $(ls "$CASA_DE_TEMAS" | tr '\n' ' ')"
meow apps aplicar enfeite >/dev/null 2>&1
quero="cor=rosa $(printf 'cor=rosa' | sha256sum | cut -d' ' -f1)"
[ "$(cat "$CASA/.config/enfeite/tema.conf" 2>/dev/null)" = "$quero" ] || falha "o módulo não usou o tema adicionado (arquivo e sha256)"
meow apps conferir enfeite >/dev/null 2>&1 || falha "com o tema adicionado no lugar, o doctor não fica verde"
printf 'cor=azul' > "$CASA_DE_TEMAS/Outro.conf"
servidor 'servidor._mod_tema_padrao({"app": "enfeite", "nome": "Outro.conf"})' | grep -q '"nome": "Outro.conf"' \
  || falha "escolher outro tema adicionado não virou o padrão"
meow apps conferir enfeite >/dev/null 2>&1 && falha "trocado o tema escolhido, o doctor não viu o tema velho no lugar"
meow apps aplicar enfeite >/dev/null 2>&1
grep -q '^cor=azul ' "$CASA/.config/enfeite/tema.conf" || falha "o conserto não pôs o tema escolhido"
python3 - "$(servidor 'servidor._mod_dados()')" <<'EOF' || falhou=1
import json, sys
d = json.loads(sys.argv[1] or "{}")
t = next((t for c in d.get("cartoes", []) for t in c["temas"] if t["pasta"] == "enfeite"), None)
if not t or t["aceita"] != [".conf"] or t["adicionados"] != ["Meu tema.conf", "Outro.conf"] \
        or t["padrao"] != "Outro.conf" or t["no_ar"] != "Outro.conf":
    print("FALHOU: o cartão do enfeite não traz o que aceita, os temas adicionados e o escolhido: %r" % t, file=sys.stderr)
    sys.exit(1)
EOF
servidor 'servidor._mod_tema_padrao({"app": "enfeite", "nome": "Sumido.conf"})' | grep -q '"erro"' \
  || falha "escolher um tema que não foi adicionado passou"
servidor 'servidor._mod_tema_padrao({"app": "enfeite", "nome": ""})' >/dev/null
[ ! -e "$CASA_DE_TEMAS/padrao" ] || falha "«Voltar ao do pack» não desfez o padrão"
saida="$(meow apps cartoes 2>/dev/null)"
grep -qP '^modulo\tenfeite\t0\t3\tsim\t' <<< "$saida" \
  || falha "voltando ao do pack, o enfeite (sem tema no pack) devia ficar sem tema"

if command -v node >/dev/null 2>&1; then
  node - "$RAIZ/app/pagina/lugares.js" <<'EOF' || falhou=1
const L = require(process.argv[2]);
const erros = [];
const so = ["chave:APPS_ATIVOS", "chave:SPOTIFY_MARKETPLACE", "chave:TERMINAL_ESQUEMA", "chave:TERMINAL_CURSOR",
  "chave:PROMPT_STARSHIP", "gesto:acervo:fonte", "acao:apps", "acao:apps_aplicar"];
const lugares = {};
for (const l of L.inventarioDoPainel()) (lugares[l.tipo + ":" + l.id] = lugares[l.tipo + ":" + l.id] || []).push(l);
for (const id of so) {
  const onde = lugares[id] || [];
  if (onde.length !== 1 || onde[0].porta !== "modificacoes")
    erros.push(`${id} tem que morar só na Modificações, e mora em: ${onde.map((l) => l.porta + "/" + l.pagina).join(", ") || "lugar nenhum"}`);
}
if (L.AJUSTES.some((p) => p.id === "terminal")) erros.push("o Definir ainda tem a aba Terminal");
for (const p of L.AJUSTES) for (const b of p.blocos) if (b.programas || b.titulo === "Recebem o tema")
  erros.push(`o Definir › ${p.nome} ainda tem o bloco «${b.titulo}»`);
for (const e of erros) console.error("FALHOU: " + e);
process.exit(erros.length ? 1 : 0);
EOF
fi

if grep -nE '"(spotify|discord|obsidian|vscode|flatpak|btop|terminal)"' "$RAIZ/app/pagina/modificacoes.js"; then
  falha "a página de modificações cita programa pelo nome; o cartão tem que vir do módulo"
fi

[ "$falhou" = 0 ] && printf 'ok: módulo novo vira cartão, a correção declarada entra nele, o tema adicionado vale acima do pack e o painel não cita programa\n'
exit "$falhou"

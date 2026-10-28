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

if grep -nE '"(spotify|discord|obsidian|vscode|flatpak|btop|terminal)"' "$RAIZ/app/pagina/modificacoes.js"; then
  falha "a página de modificações cita programa pelo nome; o cartão tem que vir do módulo"
fi

[ "$falhou" = 0 ] && printf 'ok: módulo novo vira cartão, a correção declarada entra nele e o painel não cita programa\n'
exit "$falhou"

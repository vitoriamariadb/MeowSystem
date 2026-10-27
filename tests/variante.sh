#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
CASA="$T/casa"; COSMIC="$T/cosmic"; PACKS="$T/packs"; ESTADO="$T/estado"
CONF="$CASA/.config/meow/meow.conf"
mkdir -p "$(dirname "$CONF")" "$COSMIC" "$PACKS" "$ESTADO"
cp -a "$RAIZ/packs/dracula" "$RAIZ/packs/meowsystem" "$PACKS/" || exit 2
CAT="$PACKS/meowsystem/temas/capturados"; DRA="$PACKS/dracula/temas/capturados"

git_antes="$(git -C "$RAIZ" status --porcelain 2>/dev/null; git -C "$RAIZ" status --porcelain --ignored -- packs 2>/dev/null)"

conf() {
  printf 'FLAVOR="%s"\nACCENT="%s"\nMODO="%s"\nPACK="%s"\nLOGO="coquinha"\n' "$1" "$2" "$4" "$3" > "$CONF"
}
amb() {
  env -i PATH="$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_CONF="$CONF" \
    MEOW_ESTADO="$ESTADO" MEOW_COSMIC_DIR="$COSMIC" MEOW_PACKS="$PACKS" \
    MEOW_PONTE=/nao/existe LANG=C.UTF-8 NO_COLOR=1 "$@"
}

ETAPAS="$T/etapas.sh"
{ sed -n '/^etapa_gerar() {$/,/^}$/p' "$RAIZ/install.sh"
  sed -n '/^etapa_tema() {$/,/^}$/p' "$RAIZ/install.sh"
  sed -n '/^etapa_modo() {$/,/^}$/p' "$RAIZ/install.sh"; } > "$ETAPAS"
grep -q '^etapa_tema() {' "$ETAPAS" && grep -q '^etapa_modo() {' "$ETAPAS" \
  || { printf 'erro: não achei etapa_gerar/etapa_tema/etapa_modo no install.sh\n' >&2; exit 2; }
etapa() {
  local qual="$1"; shift
  amb "$@" bash -c '
    . "$MEOW_RAIZ/lib/comum.sh" >/dev/null 2>&1
    set -a; . "$MEOW_CONF"; set +a
    meow_ponte_python >/dev/null 2>&1 || exit 9
    meow_notificar() { :; }
    passo() { :; }
    . "$1"
    "etapa_$2"; r=$?
    printf "%s" "${TEMA_SEM_CAPTURA:-}" > "$3"
    exit "$r"' _ "$ETAPAS" "$qual" "$T/sem_captura" 2>&1
  printf '%s' "$?" > "$T/rc"
}
rc() { cat "$T/rc"; }
arvores_iguais() {
  local x=(-x frosted -x alpha_map -x frosted_maximized_apps)
  diff -r "${x[@]}" "$1/com.system76.CosmicTheme.$2" "$COSMIC/com.system76.CosmicTheme.$2" >/dev/null \
    && diff -r "${x[@]}" "$1/com.system76.CosmicTheme.$2.Builder" "$COSMIC/com.system76.CosmicTheme.$2.Builder" >/dev/null
}

saida="$(amb python3 - "$RAIZ" "$CAT" "$DRA" <<'PY' 2>&1
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1] + "/scripts")
import derivar_flavor as df
cat, dra = Path(sys.argv[2]), Path(sys.argv[3])
def arvore(cap, arv):
    ler = lambda d: {p.name: p.read_text() for p in d.iterdir() if p.is_file()}
    return (ler(cap / f"com.system76.CosmicTheme.{arv}.Builder" / "v2"),
            ler(cap / f"com.system76.CosmicTheme.{arv}" / "v2"))
erros = []
for cap, arv in ((cat / "latte-mauve", "Light"), (cat / "mocha-pink", "Dark"),
                 (dra / "dracula-mauve", "Dark"), (cat / "latte-mauve", "Dark"),
                 (dra / "dracula-mauve", "Light")):
    try:
        df.conferir_base(*arvore(cap, arv), arv)
    except ValueError as e:
        erros.append(f"{cap.name} {arv} não se reproduziu: {e}")
for cap, arv in ((cat / "mocha-mauve", "Dark"),):
    try:
        df.conferir_base(*arvore(cap, arv), arv)
        erros.append(f"{cap.name} {arv} passou na guarda, e o produto dela não é o da receita")
    except ValueError as e:
        if "a conta dá" not in str(e):
            erros.append(f"{cap.name} {arv} recusou sem dizer o campo: {e}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; r=$?
[ "$r" = "0" ] \
  && ok "o build() portado reproduz as cinco árvores que se reproduzem, e recusa a que não, dizendo o campo" \
  || falha "a guarda do build() portado não bate com as capturas" "$saida"

cp -a "$DRA/dracula-mauve"/com.system76.CosmicTheme.* "$COSMIC/"
cp -a "$CAT/latte-mauve"/com.system76.CosmicTheme.Light* "$COSMIC/"
conf alucard mauve dracula escuro
saida_g="$(etapa gerar)"; rc_g="$(rc)"
saida_t="$(etapa tema)"; rc_t="$(rc)"; sem="$(cat "$T/sem_captura")"
if [ "$rc_g" = "1" ] && [[ "$saida_g" == *"alucard-mauve: derivada de latte-mauve"* ]]; then
  ok "a etapa gerar deriva o alucard do latte"
else
  falha "a etapa gerar não derivou o alucard-mauve (rc=$rc_g)" "$saida_g"
fi
if [ "$rc_t" = "1" ] && [[ "$saida_t" == *"tema 'alucard-mauve' aplicado"* ]] && [ -z "$sem" ]; then
  ok "a etapa tema aplica o alucard-mauve, e não deixa recado de captura faltando"
else
  falha "a etapa tema não aplicou o alucard-mauve (rc=$rc_t, TEMA_SEM_CAPTURA='$sem')" "$saida_t"
fi
[ "$(cat "$COSMIC/com.system76.CosmicTheme.Light.Builder/v2/accent")" = 'Some("#853AF2FF")' ] \
  && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Light.Builder/v2/bg_color")" = 'Some("#CECFDCD9")' ] \
  && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Light/v2/name")" = '"dracula-alucard"' ] \
  && ok "a árvore Light é a do alucard: acento, fundo e o nome dracula-alucard" \
  || falha "a árvore Light do COSMIC não é a do alucard" \
       "$(cat "$COSMIC/com.system76.CosmicTheme.Light.Builder/v2/accent" "$COSMIC/com.system76.CosmicTheme.Light/v2/name")"
focos="$(grep -h '^ *focus: "' "$COSMIC"/com.system76.CosmicTheme.Light/v2/* | sed 's/^ *//' | sort -u)"
[ "$focos" = 'focus: "#853AF2FF",' ] \
  && ok "o foco de todos os componentes da Light/v2 é o mauve do alucard" \
  || falha "sobrou foco de outra cor na Light/v2" "$focos"
arvores_iguais "$DRA/dracula-mauve" Dark \
  && ok "a árvore Dark é a do dracula-mauve, byte a byte (o escuro do pack, e não o Mocha do latte)" \
  || falha "a árvore Dark do alucard não é a do Dracula"
grep -q "^origem: derivada de latte-mauve" "$DRA/alucard-mauve/captura.txt" \
  && [ -f "$DRA/alucard-mauve/.gitignore" ] \
  && ok "a captura derivada mora no pack no ar, diz de onde saiu e se esconde do git" \
  || falha "a captura do alucard não está onde devia, ou não diz a base" "$(cat "$DRA/alucard-mauve/captura.txt" 2>&1)"
grep -q "^tema-sem-captura	" "$ESTADO/pendencias.tsv" 2>/dev/null \
  && falha "o alucard aplicou e a Início ainda tem a pendência de tema" \
  || ok "nenhuma pendência de tema na Início"
saida_m="$(etapa modo)"
[ "$(cat "$COSMIC/com.system76.CosmicTheme.Mode/v1/is_dark")" = "true" ] \
  && ok "com MODO=escuro o is_dark continua true: a tela mostra a Dark, que é o Dracula" \
  || falha "o is_dark não é o do MODO" "$saida_m"

saida_g2="$(etapa gerar)"; rc_g2="$(rc)"
saida_t2="$(etapa tema)"; rc_t2="$(rc)"
[ "$rc_g2" = "0" ] && [ "$rc_t2" = "0" ] \
  && ok "a segunda passagem não escreve nada (gerar=$rc_g2 tema=$rc_t2)" \
  || falha "a segunda passagem ainda escreve (gerar=$rc_g2 tema=$rc_t2)" "$saida_g2
$saida_t2"

conf alucard pink dracula claro
etapa gerar >/dev/null; saida_t="$(etapa tema)"; rc_t="$(rc)"
[ "$rc_t" = "1" ] \
  && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Light.Builder/v2/accent")" = 'Some("#ED77BBFF")' ] \
  && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Dark.Builder/v2/accent")" = 'Some("#FF79C6FF")' ] \
  && ok "alucard-pink: o pink do alucard na Light, e o do dracula na Dark (a derivada da P48 no escuro)" \
  || falha "o acento do alucard-pink não chegou aos dois lados (rc=$rc_t)" "$saida_t
$(cat "$COSMIC/com.system76.CosmicTheme.Light.Builder/v2/accent" "$COSMIC/com.system76.CosmicTheme.Dark.Builder/v2/accent")"

cp -a "$CAT/mocha-mauve"/com.system76.CosmicTheme.* "$COSMIC/"
LATTE_AQUI="$T/latte-mauve-neste-cosmic"
vidro_latte="$(amb python3 "$RAIZ/scripts/derivar_vidro.py" "$CAT/latte-mauve" --vista "$LATTE_AQUI" 2>&1)"
rc_v=$?
[ "$rc_v" = "1" ] \
  || { printf 'erro: a vista do vidro do latte-mauve neste COSMIC não se derivou (rc=%s): %s\n' "$rc_v" "$vidro_latte" >&2; exit 2; }
for caso in "frappe #CA9EE6" "macchiato #C6A0F6"; do
  fl="${caso% *}"; mauve="${caso#* }"
  conf "$fl" mauve catppuccin escuro
  saida_g="$(etapa gerar)"; rc_g="$(rc)"
  saida_t="$(etapa tema)"; rc_t="$(rc)"
  if [ "$rc_g" = "1" ] && [[ "$saida_g" == *"$fl-mauve: derivada de mocha-pink"* ]] && [ "$rc_t" = "1" ] \
     && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Dark.Builder/v2/accent")" = "Some(\"${mauve}FF\")" ] \
     && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Dark/v2/name")" = "\"catppuccin-$fl\"" ] \
     && arvores_iguais "$LATTE_AQUI" Light \
     && grep -qxF '    base: "#CCD0DA8A",' "$COSMIC/com.system76.CosmicTheme.Light/v2/transparent_background"; then
    ok "$fl-mauve deriva do mocha-pink e aplica: a Dark é a do $fl, a Light é a do latte-mauve com o vidro deste COSMIC (8A)"
  else
    falha "$fl-mauve não aplicou como devia (gerar=$rc_g tema=$rc_t)" "$saida_g
$saida_t"
  fi
done

saida="$(amb python3 - "$RAIZ" "$PACKS" <<'PY' 2>&1
import json, os, sys
sys.path.insert(0, sys.argv[1] + "/scripts")
erros = []
for pack_id, pares in (("dracula", {"dracula-pink": "dracula-mauve"}),
                       ("meowsystem", {"mocha-green": "mocha-pink", "latte-pink": "latte-mauve"})):
    os.environ["MEOW_PACK_DIR"] = os.path.join(sys.argv[2], pack_id)
    os.environ["MEOW_PALETA"] = os.path.join(sys.argv[2], pack_id, "paleta.json")
    import derivar_acento as da
    paleta = json.load(open(os.environ["MEOW_PALETA"]))
    for par, base in pares.items():
        p = da.plano(par, paleta)
        if p["estado"] != "derivavel" or p["base"] != base or p.get("como"):
            erros.append(f"{par}: estado={p['estado']} base={p.get('base')} como={p.get('como')!r}")
    for foto in ("dracula-mauve",) if pack_id == "dracula" else ("mocha-mauve", "mocha-pink", "latte-mauve"):
        if da.plano(foto, paleta)["estado"] != "fotografia":
            erros.append(f"{foto} deixou de ser fotografia")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; r=$?
[ "$r" = "0" ] \
  && ok "dracula, mocha e latte continuam no plano da P48, e as quatro fotografias continuam fotografias" \
  || falha "um flavor fotografado passou a ser derivado por outro caminho" "$saida"

for pack_id in dracula meowsystem; do
  saida="$(amb env MEOW_PACK_DIR="$PACKS/$pack_id" MEOW_PALETA="$PACKS/$pack_id/paleta.json" \
    python3 - "$RAIZ" "$pack_id" <<'PY' 2>&1
import json, os, sys
sys.path.insert(0, sys.argv[1] + "/app")
sys.path.insert(0, sys.argv[1] + "/scripts")
import servidor
import derivar_flavor as df
paleta = json.load(open(os.environ["MEOW_PALETA"]))
claros = paleta.get("claros") or []
erros = []
for f in paleta["flavors"]:
    lado = "escuro" if f in claros else "claro"
    pagina, captura = servidor._flavor_no_modo(f, lado), df.par_do_outro_lado(f, paleta)
    if pagina != captura:
        erros.append(f"{f} no modo {lado}: a página veste {pagina}, a captura traz {captura}")
    if servidor._flavor_no_modo(f, "claro" if lado == "escuro" else "escuro") != f:
        erros.append(f"{f} no próprio lado não veste ele mesmo")
esperado = {"dracula": ("alucard", "dracula"), "meowsystem": ("latte", "mocha")}[sys.argv[2]]
if servidor._flavor_no_modo(esperado[0], "escuro") != esperado[1]:
    erros.append(f"{esperado[0]} com MODO=escuro não veste o {esperado[1]}")
print("\n".join(erros) or " ".join(f"{f}->{servidor._flavor_no_modo(f, 'escuro')}" for f in paleta["flavors"]))
sys.exit(1 if erros else 0)
PY
)"; r=$?
  [ "$r" = "0" ] \
    && ok "$pack_id: a página e a captura vestem o mesmo lado (no escuro: $saida)" \
    || falha "$pack_id: o servidor e o derivador discordam sobre o outro lado" "$saida"
done

SEM="$T/packs-sem-escuro"; mkdir -p "$SEM"
cp -a "$RAIZ/packs/meowsystem" "$SEM/"; rm -rf "$SEM"/meowsystem/temas/capturados/mocha-*
conf frappe pink catppuccin escuro
saida_t="$(etapa tema MEOW_PACKS="$SEM")"; rc_t="$(rc)"; sem="$(cat "$T/sem_captura")"
[ "$rc_t" = "3" ] && [ "$sem" = "falta" ] && [[ "$saida_t" == *"nem de outro flavor escuro"* ]] \
  && ok "sem base do mesmo lado, o frappe não aplica, e a etapa diz por quê e deixa TEMA_SEM_CAPTURA=falta" \
  || falha "a variante sem tema não deu o recado certo (rc=$rc_t, TEMA_SEM_CAPTURA='$sem')" "$saida_t"
conf macchiato green catppuccin escuro
saida_t="$(etapa tema MEOW_DRY_RUN=1)"; rc_t="$(rc)"; sem="$(cat "$T/sem_captura")"
[ "$rc_t" = "1" ] && [ "$sem" = "deriva" ] && [ ! -e "$CAT/macchiato-green" ] \
  && ok "no ensaio, um par que se deriva deixa TEMA_SEM_CAPTURA=deriva e não escreve a captura" \
  || falha "o ensaio do macchiato-green não deu o recado certo (rc=$rc_t, TEMA_SEM_CAPTURA='$sem')" "$saida_t"
conf macchiato pink catppuccin escuro
etapa gerar >/dev/null
conf frappe green catppuccin escuro
cp -a "$CAT/macchiato-pink"/com.system76.CosmicTheme.* "$COSMIC/"
saida="$(amb env MEOW_PACKS="$SEM" MEOW_PACK_DIR="$SEM/meowsystem" MEOW_PALETA="$SEM/meowsystem/paleta.json" \
  python3 - "$RAIZ" <<'PY' 2>&1
import json, os, re, sys
sys.path.insert(0, sys.argv[1] + "/app")
import servidor
def vestido(css):
    var = dict(re.findall(r"--([a-z0-9-]+):\s*([^;]+);", css))
    ref = re.match(r"var\(--([a-z0-9-]+)\)$", var.get("accent", ""))
    return (var.get("base", "").upper(),
            (var.get(ref.group(1), "") if ref else var.get("accent", "")).upper())
m = servidor.Manipulador.__new__(servidor.Manipulador)
m.path = "/paleta.css"
m._host_confere = m._origem_confere = lambda: True
m._token_confere = lambda consulta: True
servido = []
m._responder = lambda corpo, **_k: servido.append(corpo)
m.do_GET()
html, _nome = m._exportar_pagina()
bloco = re.search(r'<style id="paleta-do-painel">(.*?)</style>', html, re.S)
marca = re.search(r'stroke="(#[0-9A-Fa-f]{6})"', (m._logo_do_painel() or b"").decode())
receita = open(os.path.join(os.environ["MEOW_COSMIC_DIR"],
                            "com.system76.CosmicTheme.Dark.Builder/v2/accent")).read()
tela = re.search(r"#[0-9A-Fa-f]{6}", receita).group(0).upper()
macchiato = json.load(open(os.environ["MEOW_PALETA"]))["flavors"]["macchiato"]
erros = []
if tela != macchiato["pink"].upper():
    erros.append(f"o COSMIC de brinquedo não está no macchiato-pink (acento {tela})")
for onde, (base, acento) in (("/paleta.css", vestido(servido[0] if servido else "")),
                             ("a página exportada", vestido(bloco.group(1) if bloco else ""))):
    if base != macchiato["base"].upper():
        erros.append(f"{onde}: --base {base or 'nenhum'}, e o macchiato que a tela mostra tem {macchiato['base'].upper()}")
    if acento != tela:
        erros.append(f"{onde}: o --accent chega a {acento or 'nada'}, e o COSMIC tem {tela}")
if (marca.group(1).upper() if marca else "") != tela:
    erros.append(f"a marca do painel em {marca.group(1) if marca else 'nada'}, e o COSMIC tem {tela}")
print("\n".join(erros) or f"--base {macchiato['base'].upper()}, --accent e marca em {tela}")
sys.exit(1 if erros else 0)
PY
)"; r=$?
[ "$r" = "0" ] \
  && ok "com o frappe-green sem tema, a página veste o flavor e o acento que a tela mostra ($saida)" \
  || falha "a página se vestiu da variante sem tema" "$saida"

[ "$(git -C "$RAIZ" status --porcelain 2>/dev/null; git -C "$RAIZ" status --porcelain --ignored -- packs 2>/dev/null)" = "$git_antes" ] \
  && ok "o repositório saiu como entrou" \
  || falha "o teste mexeu no repositório" "$(git -C "$RAIZ" status --porcelain)"

printf '\n'
[ "$falhas" = "0" ] && { printf 'variante: tudo certo\n'; exit 0; }
printf 'variante: %d achado(s)\n' "$falhas"
exit 1

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

DARK_MEDIDA="0c3906b47434234307422c065e3c71c4cffa483bafa3738f233d5d5822e4fa76"

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
CASA="$T/casa"; COSMIC="$T/cosmic"; PACKS="$T/packs"; ESTADO="$T/estado"
CONF="$CASA/.config/meow/meow.conf"
mkdir -p "$(dirname "$CONF")" "$COSMIC" "$PACKS" "$ESTADO"
cp -a "$RAIZ/packs/dracula" "$RAIZ/packs/meowsystem" "$PACKS/" || exit 2
CAT="$PACKS/meowsystem/temas/capturados"; DRA="$PACKS/dracula/temas/capturados"
FOTO="$RAIZ/packs/dracula/temas/capturados/dracula-mauve"

git_antes="$(git -C "$RAIZ" status --porcelain 2>/dev/null; git -C "$RAIZ" status --porcelain --ignored -- packs 2>/dev/null)"

conf() {
  printf 'FLAVOR="%s"\nACCENT="%s"\nMODO="%s"\nPACK="%s"\nLOGO="coquinha"\n' "$1" "$2" "$4" "$3" > "$CONF"
}
amb() {
  env -i PATH="$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_CONF="$CONF" \
    MEOW_ESTADO="$ESTADO" MEOW_COSMIC_DIR="$COSMIC" MEOW_PACKS="$PACKS" \
    MEOW_PONTE=/caminho/inexistente LANG=C.UTF-8 NO_COLOR=1 "$@"
}

ETAPAS="$T/etapas.sh"
{ sed -n '/^etapa_gerar() {$/,/^}$/p' "$RAIZ/install.sh"
  sed -n '/^etapa_tema() {$/,/^}$/p' "$RAIZ/install.sh"
  sed -n '/^etapa_modo() {$/,/^}$/p' "$RAIZ/install.sh"; } > "$ETAPAS"
grep -q '^etapa_gerar() {' "$ETAPAS" && grep -q '^etapa_tema() {' "$ETAPAS" && grep -q '^etapa_modo() {' "$ETAPAS" \
  || { printf 'erro: não achei etapa_gerar/etapa_tema/etapa_modo no install.sh\n' >&2; exit 2; }
etapa() {
  amb bash -c '
    . "$MEOW_RAIZ/lib/comum.sh" >/dev/null 2>&1
    set -a; . "$MEOW_CONF"; set +a
    meow_ponte_python >/dev/null 2>&1 || exit 9
    meow_notificar() { :; }
    passo() { :; }
    . "$1"
    "etapa_$2"' _ "$ETAPAS" "$1" 2>&1
  printf '%s' "$?" > "$T/rc"
}
rc() { cat "$T/rc"; }
arvores_iguais() {
  local x=(-x frosted -x alpha_map -x frosted_maximized_apps)
  diff -r "${x[@]}" "$1/com.system76.CosmicTheme.$2" "$COSMIC/com.system76.CosmicTheme.$2" >/dev/null \
    && diff -r "${x[@]}" "$1/com.system76.CosmicTheme.$2.Builder" "$COSMIC/com.system76.CosmicTheme.$2.Builder" >/dev/null
}
sem_latte() {
  python3 - "$1" "$PACKS" <<'PY'
import json, re, sys
from pathlib import Path
d, packs = Path(sys.argv[1]), Path(sys.argv[2])
latte = {v.upper() for v in json.load(open(packs / "meowsystem/paleta.json"))["flavors"]["latte"].values()}
alucard = {v.upper() for v in json.load(open(packs / "dracula/paleta.json"))["flavors"]["alucard"].values()}
txt = "".join(p.read_text(encoding="utf-8") for p in sorted(d.glob("com.system76.CosmicTheme.Light*/v*/*"))
              if p.is_file())
vistos = {h.upper()[:7] for h in re.findall(r"#[0-9A-Fa-f]{6,8}", txt)}
print(" ".join(sorted(vistos & (latte - alucard))))
PY
}

saida="$(amb env MEOW_PACK_DIR="$RAIZ/packs/dracula" MEOW_PACKS= \
  python3 "$RAIZ/scripts/derivar_flavor.py" --conferir dracula-mauve 2>&1)"; r=$?
[ "$r" = "0" ] && [[ "$saida" == *"o claro já é o do alucard-mauve"* ]] \
  && ok "a Light da foto dracula-mauve é a que o derivar_flavor.py dá hoje (o alucard-mauve)" \
  || falha "a Light da foto não é a derivação de hoje (rc=$r) — refaça com: MEOW_PACK_DIR=packs/dracula python3 scripts/derivar_flavor.py dracula-mauve" "$saida"
( cd "$FOTO" && sha256sum --quiet -c manifesto.sha256 >/dev/null 2>&1 ) \
  && ok "o manifesto.sha256 da foto confere arquivo a arquivo" \
  || falha "o manifesto.sha256 da foto não confere" "$(cd "$FOTO" && sha256sum --quiet -c manifesto.sha256 2>&1 | head -n 5)"
grep -qxF "claro: o do alucard-mauve, derivado de latte-mauve (scripts/derivar_flavor.py)" "$FOTO/captura.txt" \
  && grep -qxF "origem: ~/.config/cosmic" "$FOTO/captura.txt" \
  && ok "o captura.txt continua dizendo a casa da foto, e diz de onde veio o claro" \
  || falha "o captura.txt da foto não diz de onde veio o claro" "$(cat "$FOTO/captura.txt")"

dark="$(grep -E '  \./com\.system76\.CosmicTheme\.(Dark|Dark\.Builder|Mode)/' "$FOTO/manifesto.sha256" | sha256sum | cut -d' ' -f1)"
n="$(grep -cE '  \./com\.system76\.CosmicTheme\.(Dark|Dark\.Builder|Mode)/' "$FOTO/manifesto.sha256")"
[ "$dark" = "$DARK_MEDIDA" ] && [ "$n" = "109" ] \
  && ok "a Dark, a Dark.Builder e o Mode da foto são os de antes (109 arquivos, o mesmo sha256)" \
  || falha "a Dark da foto mudou ($n linhas, $dark)"

cp -a "$DRA/dracula-mauve"/com.system76.CosmicTheme.* "$COSMIC/"
cp -a "$CAT/latte-mauve"/com.system76.CosmicTheme.Light* "$COSMIC/"
[ "$(cat "$COSMIC/com.system76.CosmicTheme.Light/v2/name")" = '"catppuccin-latte"' ] \
  && [ -n "$(sem_latte "$COSMIC")" ] \
  && ok "antes: a Light do COSMIC de brinquedo é o Latte ($(sem_latte "$COSMIC" | wc -w) hex dele)" \
  || falha "o ponto de partida não é o Latte no claro"
conf dracula mauve dracula claro
etapa gerar >/dev/null
saida_t="$(etapa tema)"; rc_t="$(rc)"
saida_m="$(etapa modo)"
[ "$rc_t" = "1" ] && [[ "$saida_t" == *"tema 'dracula-mauve' aplicado"* ]] \
  && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Mode/v1/is_dark")" = "false" ] \
  && ok "a etapa tema aplica o dracula-mauve e a etapa modo deixa o is_dark em false" \
  || falha "o dracula-mauve com MODO=claro não aplicou (tema rc=$rc_t)" "$saida_t
$saida_m"
latte="$(sem_latte "$COSMIC")"
[ -z "$latte" ] \
  && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Light/v2/name")" = '"dracula-alucard"' ] \
  && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Light.Builder/v2/accent")" = 'Some("#853AF2FF")' ] \
  && ok "a Light que a tela mostra é a do alucard: nome dracula-alucard, o mauve #853AF2, e nenhum hex do Latte" \
  || falha "a Light do COSMIC ainda não é a do alucard" "hex do Latte: ${latte:-nenhum}
$(cat "$COSMIC/com.system76.CosmicTheme.Light/v2/name" "$COSMIC/com.system76.CosmicTheme.Light.Builder/v2/accent")"
focos="$(grep -h '^ *focus: "' "$COSMIC"/com.system76.CosmicTheme.Light/v2/* | sed 's/^ *//' | sort -u)"
[ "$focos" = 'focus: "#853AF2FF",' ] \
  && ok "o foco de todos os componentes da Light/v2 é o mauve do alucard" \
  || falha "sobrou foco de outra cor na Light/v2" "$focos"
arvores_iguais "$DRA/dracula-mauve" Light \
  && ok "a Light do COSMIC é a da foto, byte a byte" \
  || falha "a Light do COSMIC não é a da foto"

conf dracula mauve dracula escuro
saida_m="$(etapa modo)"
[ "$(cat "$COSMIC/com.system76.CosmicTheme.Mode/v1/is_dark")" = "true" ] \
  && diff -r "$FOTO/com.system76.CosmicTheme.Dark" "$COSMIC/com.system76.CosmicTheme.Dark" >/dev/null \
  && diff -r "$FOTO/com.system76.CosmicTheme.Dark.Builder" "$COSMIC/com.system76.CosmicTheme.Dark.Builder" >/dev/null \
  && ok "com MODO=escuro o is_dark é true, e a Dark e a Dark.Builder do COSMIC são as da foto, byte a byte" \
  || falha "a Dark do COSMIC não é a da foto com MODO=escuro" "$saida_m"

conf dracula pink dracula claro
saida_g="$(etapa gerar)"; rc_g="$(rc)"
saida_t="$(etapa tema)"; rc_t="$(rc)"
etapa modo >/dev/null
if [ "$rc_g" = "1" ] && [[ "$saida_g" == *"dracula-pink: derivada de dracula-mauve"*"o claro é o do alucard-pink"* ]] \
   && [ "$rc_t" = "1" ]; then
  ok "a etapa gerar deriva o dracula-pink com o claro do alucard-pink, e a etapa tema o aplica"
else
  falha "o dracula-pink não saiu com o claro do alucard-pink (gerar=$rc_g tema=$rc_t)" "$saida_g
$saida_t"
fi
latte="$(sem_latte "$COSMIC")"
[ -z "$latte" ] \
  && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Light.Builder/v2/accent")" = 'Some("#ED77BBFF")' ] \
  && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Dark.Builder/v2/accent")" = 'Some("#FF79C6FF")' ] \
  && ok "o pink do alucard na Light, o do dracula na Dark, e nenhum hex do Latte" \
  || falha "o acento do dracula-pink não chegou ao claro" "hex do Latte: ${latte:-nenhum}
$(cat "$COSMIC/com.system76.CosmicTheme.Light.Builder/v2/accent" "$COSMIC/com.system76.CosmicTheme.Dark.Builder/v2/accent")"
grep -qxF "claro: o do alucard-pink, derivado de latte-mauve (scripts/derivar_flavor.py)" "$DRA/dracula-pink/captura.txt" \
  && grep -q "^origem: derivada de dracula-mauve" "$DRA/dracula-pink/captura.txt" \
  && ok "o captura.txt da derivada diz a base e de onde veio o claro" \
  || falha "o captura.txt do dracula-pink não diz de onde veio o claro" "$(cat "$DRA/dracula-pink/captura.txt")"
saida="$(amb env MEOW_PACK_DIR="$PACKS/dracula" MEOW_PALETA="$PACKS/dracula/paleta.json" \
  python3 - "$RAIZ" "$DRA/dracula-pink" <<'PY' 2>&1
import json, os, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1] + "/scripts")
import derivar_acento as da
paleta = json.load(open(os.environ["MEOW_PALETA"]))
p = da.plano("alucard-pink", paleta)
if p["estado"] != "derivavel":
    sys.exit(f"o alucard-pink não se deriva: {p['motivo']}")
cap = Path(sys.argv[2])
luz = lambda r: r.startswith("com.system76.CosmicTheme.Light")
deles = {r: d for r, d in p["conteudo"].items() if luz(r)}
nossos = {a.relative_to(cap).as_posix(): a.read_bytes() for a in cap.rglob("*")
          if a.is_file() and luz(a.relative_to(cap).as_posix())}
dif = sorted(r for r in deles.keys() | nossos.keys() if deles.get(r) != nossos.get(r))
print(f"{len(nossos)} arquivos" if not dif else "diferem: " + " ".join(dif[:5]))
sys.exit(1 if dif else 0)
PY
)"; r=$?
[ "$r" = "0" ] \
  && ok "a Light do dracula-pink é a do alucard-pink, byte a byte ($saida)" \
  || falha "a Light do dracula-pink não é a que o FLAVOR=alucard mostra" "$saida"

cp -a "$CAT/latte-mauve"/com.system76.CosmicTheme.Light* "$DRA/dracula-pink/"
saida_g="$(etapa gerar)"; rc_g="$(rc)"
[ "$rc_g" = "1" ] && [[ "$saida_g" == *"o claro é o do alucard-pink"* ]] \
  && [ "$(cat "$DRA/dracula-pink/com.system76.CosmicTheme.Light.Builder/v2/accent")" = 'Some("#ED77BBFF")' ] \
  && ok "a derivada com o Latte no claro se refaz na etapa gerar" \
  || falha "a derivada velha não se refez (gerar=$rc_g)" "$saida_g"

etapa tema >/dev/null
saida_g2="$(etapa gerar)"; rc_g2="$(rc)"
saida_t2="$(etapa tema)"; rc_t2="$(rc)"
[ "$rc_g2" = "0" ] && [ "$rc_t2" = "0" ] \
  && ok "a segunda passagem não escreve nada (gerar=$rc_g2 tema=$rc_t2)" \
  || falha "a segunda passagem ainda escreve (gerar=$rc_g2 tema=$rc_t2)" "$saida_g2
$saida_t2"

saida="$(amb env MEOW_PACK_DIR="$PACKS/meowsystem" MEOW_PALETA="$PACKS/meowsystem/paleta.json" \
  python3 - "$RAIZ" <<'PY' 2>&1
import json, os, sys
sys.path.insert(0, sys.argv[1] + "/scripts")
import derivar_acento as da
import derivar_flavor as df
paleta = json.load(open(os.environ["MEOW_PALETA"]))
erros = []
for par in ("mocha-pink", "mocha-green", "latte-pink"):
    if df.lado_do_par(par, paleta) is not None:
        erros.append(f"{par}: o lado do par deixou de ser o da foto")
p = da.plano("mocha-green", paleta)
if p["estado"] != "derivavel" or p.get("base") != "mocha-pink" or "conteudo" in p \
        or p.get("lado") != "o claro leva o green do latte":
    erros.append(f"mocha-green: estado={p['estado']} base={p.get('base')} lado={p.get('lado')!r}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; r=$?
[ "$r" = "0" ] \
  && ok "no Catppuccin a derivada de acento continua levando a Light da base (o latte tem foto)" \
  || falha "a regra do claro vazou para o Catppuccin" "$saida"
saida="$(amb env MEOW_PACK_DIR="$RAIZ/packs/meowsystem" MEOW_PACKS= \
  python3 "$RAIZ/scripts/derivar_flavor.py" --conferir mocha-pink 2>&1)"; r=$?
[ "$r" = "3" ] && [[ "$saida" == *"o outro lado fica o da foto"* ]] \
  && ok "o derivar_flavor.py não mexe na foto mocha-pink, e diz por quê" \
  || falha "o derivar_flavor.py quis mexer numa foto do Catppuccin (rc=$r)" "$saida"

[ "$(git -C "$RAIZ" status --porcelain 2>/dev/null; git -C "$RAIZ" status --porcelain --ignored -- packs 2>/dev/null)" = "$git_antes" ] \
  && ok "o repositório saiu como entrou" \
  || falha "o teste mexeu no repositório" "$(git -C "$RAIZ" status --porcelain)"

printf '\n'
[ "$falhas" = "0" ] && { printf 'claro-do-pack: tudo certo\n'; exit 0; }
printf 'claro-do-pack: %d achado(s)\n' "$falhas"
exit 1

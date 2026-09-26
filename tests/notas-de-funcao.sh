#!/usr/bin/env bash
# notas-de-funcao.sh — as notas de função que as revisões da leva D2 deixaram.
#
# POR QUE ESTE ARQUIVO NASCEU EM 25/09/2026 (sprint P66)
#   As reconferências da P63, P64 e P65 aprovaram as sprints e deixaram seis
#   notas; cinco são de função. Cada seção abaixo é uma delas, com a prova que
#   falhava antes da P66 e passa depois:
#     1. O acento do outro lado. Com FLAVOR=latte, ACCENT=blue e MODO=escuro, o
#        COSMIC vestia a Dark `catppuccin-mocha` com #CBA6F7FF (o mauve do
#        latte-mauve), e mocha-green no claro a Light `catppuccin-latte` com
#        #8839EFFF — a página e a prévia prometiam o blue e o green do par. Pelas
#        MESMAS etapas do install.sh que o «Salvar e aplicar» roda, num COSMIC de
#        brinquedo: o lado do par veste agora o acento pedido. Nos 84 pares dos
#        dois packs o lado do par é conferido campo a campo — o das derivadas e
#        o das FOTOS —, e o que já estava certo não muda um byte (a soma
#        abaixo). O lado do par que não se deriva fica o da base, sem derrubar
#        a variante (revisão da P66).
#        [Até a P68 (25/09/2026) um defeito conhecido ficava de fora, dito em
#        toda corrida: a foto `mocha-pink` vestia no claro o mauve do latte
#        (#8839EF), e o par pede o pink dele (#EA76CB). A P68 escreveu na foto a
#        Light que o `derivar_arvore` do derivar_acento.py dá no pink — 34
#        arquivos, com o manifesto refeito e a linha `claro:` no captura.txt;
#        a conta está no CREDITOS.md do pack —, e o `CONHECIDOS` saiu: a foto
#        passa pela mesma régua dos outros 83 pares.]
#     2. O desfazer da escolha do pack. Desfeita a escolha de um desenho do pack
#        no ar para um nome que o mapa não tinha, o desenho ficava no tema. O
#        passo do pack o tira agora pelo registro do que ele pôs lá — e só isso:
#        o autoral que o `completar_icones.sh` põe no mesmo `scalable/apps`, com
#        os bytes de um desenho do pack, fica. (O caminho pelo painel está no
#        tests/seletor-do-pack.sh, seção 6.)
#     3. O `_mapa_dracula` do painel com `PACK=""` e `FLAVOR="alucard"`: a adoção
#        dava o Dracula e ele dava 0 nomes.
#     4. O molde `cat--<acento>` do ICONES_PASTAS escrito duas vezes (o
#        `carregar_conf` do bin/meow e o `conf_exportada` do painel): uma só.
#     5. O `--conferir` das pastas especiais, com elas desligadas e os desenhos
#        no disco, dizia «devolvendo», no gerúndio de quem faz — e não fazia.
#     6. A montagem «a base menos um lado + o lado do par», escrita nos dois
#        derivadores: uma função só (o `montar` do derivar_acento.py), e a soma
#        da seção 1 é a prova de que as capturas saem iguais byte a byte.
#
# A SOMA DO QUE NÃO MUDA É UM NÚMERO MEDIDO, E NÃO UMA CÓPIA GUARDADA
#   `SOMA_MEDIDA` é o sha256 das 84 capturas que o `derivar_acento.py` dá para os
#   seis flavors dos dois packs nos 14 acentos (a foto, quando há; a derivada,
#   sem escrever nada), com duas exceções, em que o outro lado e o
#   `captura.txt` ficam fora: as derivadas da P48 cujo outro lado é o da base
#   (o latte e o mocha, que têm foto do par) — são elas que a P66 muda —, e as
#   FOTOS, cujo outro lado é o que a decisão sobre a `mocha-pink` pode mudar.
#   [Até a revisão da P66 a foto entrava inteira na soma, e a soma dizia «não
#   muda» do claro errado da `mocha-pink`.] O outro lado de todas é conferido
#   pelo acento, campo a campo. Medido em 25/09/2026 com o código de antes da
#   P66 (9aa3b01) e com o de depois: o mesmo número. Mexer em qualquer outro
#   byte de captura é outra decisão, e quem a tomar troca este número junto.
#   [P68, 25/09/2026: a decisão foi tomada — a Light da `mocha-pink` passou ao
#   pink —, e a soma é a mesma: o que mudou é o outro lado de uma foto, fora
#   dela. Das derivadas, só o `mocha-red` e o `mocha-blue` mudam um byte, na
#   Light/v1/accent_button (o `on` branco escrito 1.0, e não 0.99999994: o
#   mesmo #FFFFFF em 8 bits), e o outro lado delas também fica fora.]
#
# NADA FORA DO TEMPORÁRIO: COSMIC, casa, estado e packs de brinquedo (as
#   derivadas nascem dentro do pack copiado), `env -i` em toda chamada, a ponte
#   apontando para o vazio, um `sudo` falso na frente do PATH, e o teste
#   confere no fim que o repositório não mudou.
#
#   0 = passou · 1 = achados · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

SOMA_MEDIDA="6dd88a29f5ebd333f58e249f5945c56419446d42aae83dcbe5df5685f1c67626"

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/bin-falso"; mkdir -p "$FALSO"
printf '#!/bin/sh\nexit 1\n' > "$FALSO/sudo"; chmod +x "$FALSO/sudo"
CAMINHO="$FALSO:$PATH"
CASA="$T/casa"; COSMIC="$T/cosmic"; PACKS="$T/packs"; ESTADO="$T/estado"
CONF="$CASA/.config/meow/meow.conf"
mkdir -p "$(dirname "$CONF")" "$COSMIC" "$PACKS" "$ESTADO"
cp -a "$RAIZ/packs/dracula" "$RAIZ/packs/catppuccin" "$PACKS/" || exit 2
# As derivadas que esta máquina já tenha nos packs copiados saem: cada seção
# parte das fotos, e o que ela precisar deriva de novo (a marca é a do
# `captura.txt`, e não um nome).
for cap in "$PACKS"/*/temas/capturados/*/; do
  grep -qs '^origem: derivada de ' "$cap/captura.txt" && rm -rf "$cap"
done
CAT="$PACKS/catppuccin/temas/capturados"

git_antes="$(git -C "$RAIZ" status --porcelain 2>/dev/null; git -C "$RAIZ" status --porcelain --ignored -- packs 2>/dev/null)"

conf() {   # conf <flavor> <acento> <pack> <modo>
  printf 'FLAVOR="%s"\nACCENT="%s"\nMODO="%s"\nPACK="%s"\nLOGO="coquinha"\n' "$1" "$2" "$4" "$3" > "$CONF"
}
amb() {
  env -i PATH="$CAMINHO" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_CONF="$CONF" \
    MEOW_ESTADO="$ESTADO" MEOW_COSMIC_DIR="$COSMIC" MEOW_PACKS="$PACKS" \
    MEOW_PONTE=/caminho/inexistente LANG=C.UTF-8 NO_COLOR=1 "$@"
}

# As etapas do install.sh, pelo nome — o arranjo do tests/claro-do-pack.sh.
ETAPAS="$T/etapas.sh"
{ sed -n '/^etapa_gerar() {$/,/^}$/p' "$RAIZ/install.sh"
  sed -n '/^etapa_tema() {$/,/^}$/p' "$RAIZ/install.sh"
  sed -n '/^etapa_modo() {$/,/^}$/p' "$RAIZ/install.sh"; } > "$ETAPAS"
grep -q '^etapa_gerar() {' "$ETAPAS" && grep -q '^etapa_tema() {' "$ETAPAS" && grep -q '^etapa_modo() {' "$ETAPAS" \
  || { printf 'erro: não achei etapa_gerar/etapa_tema/etapa_modo no install.sh\n' >&2; exit 2; }
etapa() {   # etapa <gerar|tema|modo> — devolve a saída; o código fica em $T/rc
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
cor() {   # cor <pack> <flavor> <acento> — o hex da paleta do pack, em maiúsculas
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flavors"][sys.argv[2]][sys.argv[3]].upper())' \
    "$PACKS/$1/paleta.json" "$2" "$3"
}
veste() {   # veste <Dark|Light> — nome, acento da receita e os focos da árvore do COSMIC
  printf '%s|%s|%s' "$(cat "$COSMIC/com.system76.CosmicTheme.$1/v2/name")" \
    "$(cat "$COSMIC/com.system76.CosmicTheme.$1.Builder/v2/accent")" \
    "$(grep -h '^ *focus: "' "$COSMIC"/com.system76.CosmicTheme."$1"/v2/* | sed 's/^ *//' | sort -u | tr '\n' ' ')"
}

# --- 1. o acento do lado do par ----------------------------------------------
printf -- '--- 1. o acento do lado do par ---\n'
#   O ponto de partida é o Catppuccin aplicado pela foto do latte-mauve.
cp -a "$CAT/latte-mauve"/com.system76.CosmicTheme.* "$COSMIC/"
azul="$(cor catppuccin mocha blue)"; verde="$(cor catppuccin latte green)"
conf latte blue catppuccin escuro
saida_g="$(etapa gerar)"; rc_g="$(rc)"
saida_t="$(etapa tema)"; rc_t="$(rc)"
etapa modo >/dev/null
[ "$(cat "$COSMIC/com.system76.CosmicTheme.Mode/v1/is_dark")" = "true" ] \
  && [ "$(veste Dark)" = "\"catppuccin-mocha\"|Some(\"${azul}FF\")|focus: \"${azul}FF\", " ] \
  && ok "FLAVOR=latte, ACCENT=blue, MODO=escuro: a Dark é o Mocha com o blue dele, $azul, na receita e em todo foco" \
  || falha "latte-blue no escuro não veste o blue do mocha (gerar=$rc_g tema=$rc_t)" "$(veste Dark)
$saida_g
$saida_t"
[[ "$saida_g" == *"latte-blue: derivada de latte-mauve"*"o escuro leva o blue do mocha"* ]] \
  && grep -qxF "escuro: o do latte-mauve, no blue do mocha, $azul (scripts/derivar_acento.py)" "$CAT/latte-blue/captura.txt" \
  && ok "a etapa gerar diz de onde veio o escuro, e o captura.txt da derivada também" \
  || falha "a derivada do latte-blue não diz de onde veio o escuro" "$saida_g
$(cat "$CAT/latte-blue/captura.txt" 2>&1)"
etapa tema >/dev/null
saida_g2="$(etapa gerar)"; rc_g2="$(rc)"; saida_t2="$(etapa tema)"; rc_t2="$(rc)"
[ "$rc_g2" = "0" ] && [ "$rc_t2" = "0" ] \
  && ok "a segunda passagem não escreve nada (gerar=$rc_g2 tema=$rc_t2)" \
  || falha "a segunda passagem ainda escreve (gerar=$rc_g2 tema=$rc_t2)" "$saida_g2
$saida_t2"

conf mocha green catppuccin claro
saida_g="$(etapa gerar)"; rc_g="$(rc)"
saida_t="$(etapa tema)"; rc_t="$(rc)"
etapa modo >/dev/null
[ "$(cat "$COSMIC/com.system76.CosmicTheme.Mode/v1/is_dark")" = "false" ] \
  && [ "$(veste Light)" = "\"catppuccin-latte\"|Some(\"${verde}FF\")|focus: \"${verde}FF\", " ] \
  && ok "FLAVOR=mocha, ACCENT=green, MODO=claro: a Light é o Latte com o green dele, $verde, na receita e em todo foco" \
  || falha "mocha-green no claro não veste o green do latte (gerar=$rc_g tema=$rc_t)" "$(veste Light)
$saida_g
$saida_t"

#   A FOTO mocha-pink NO CLARO — 25/09/2026, sprint P68. Ela não passa pelo
#   derivador (o `plano` a devolve como `fotografia`), e vestia a Light
#   `catppuccin-latte` com #8839EFFF, o mauve, com o par pedindo o pink do
#   latte. A P68 escreveu o pink NA FOTO, pelo `derivar_arvore`; aqui ela é
#   aplicada pelas mesmas etapas, e a Light da foto do repositório é conferida
#   contra a conta: com o pink que ela declara, o derivador não muda um byte —
#   uma Light copiada à mão, ou uma porta do `build()` que mudou, derruba isto.
rosa="$(cor catppuccin latte pink)"
conf mocha pink catppuccin claro
saida_g="$(etapa gerar)"; rc_g="$(rc)"
saida_t="$(etapa tema)"; rc_t="$(rc)"
etapa modo >/dev/null
[ "$(cat "$COSMIC/com.system76.CosmicTheme.Mode/v1/is_dark")" = "false" ] \
  && [ "$(veste Light)" = "\"catppuccin-latte\"|Some(\"${rosa}FF\")|focus: \"${rosa}FF\", " ] \
  && ok "FLAVOR=mocha, ACCENT=pink, MODO=claro: a foto veste o Latte com o pink dele, $rosa, na receita e em todo foco" \
  || falha "a foto mocha-pink no claro não veste o pink do latte (gerar=$rc_g tema=$rc_t)" "$(veste Light)
$saida_g
$saida_t"
saida="$(amb python3 - "$RAIZ" "$CAT/mocha-pink" "$rosa" <<'PY' 2>&1
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1] + "/scripts")
import derivar_acento as da
try:
    trocas = da.derivar_arvore(Path(sys.argv[2]), "Light", sys.argv[3])
except ValueError as e:
    print(f"a Light da foto não se reproduz: {e}")
    sys.exit(1)
print("\n".join(sorted(trocas)))
sys.exit(1 if trocas else 0)
PY
)"; r=$?
[ "$r" = "0" ] \
  && ok "a Light da foto mocha-pink é a que o derivar_arvore dá no $rosa, byte a byte" \
  || falha "a Light da foto mocha-pink não é a conta do derivador" "$saida"

#   Os 14 acentos, e a soma do que não muda. Sem escrever nada: o `plano` e o
#   `_conteudo` do derivar_acento.py são o que a etapa gerar gravaria.
saida="$(amb env MEOW_ESPERADA="$SOMA_MEDIDA" python3 - "$RAIZ" "$PACKS" <<'PY' 2>&1
import hashlib, json, os, sys
from pathlib import Path
raiz, packs = sys.argv[1], Path(sys.argv[2])
sys.path.insert(0, raiz + "/scripts")
soma, erros, pares, lados = hashlib.sha256(), [], 0, 0
for pack_id in ("dracula", "catppuccin"):
    os.environ["MEOW_PACK_DIR"] = str(packs / pack_id)
    os.environ["MEOW_PALETA"] = str(packs / pack_id / "paleta.json")
    import derivar_acento as da
    import derivar_flavor as df
    import pack
    paleta = json.load(open(os.environ["MEOW_PALETA"]))
    for fl in paleta["flavors"]:
        # O outro lado é o do FLAVOR, e não o da base: vale para a foto também.
        outro = "Dark" if fl in (paleta.get("claros") or []) else "Light"
        parceiro = df.par_do_outro_lado(fl, paleta)
        for ac in paleta["ordem_canonica"][:14]:
            par = f"{fl}-{ac}"
            p = da.plano(par, paleta)
            if p["estado"] == "fotografia":
                d = Path(pack.captura(par))
                cont = {a.relative_to(d).as_posix(): a.read_bytes() for a in d.rglob("*")
                        if a.is_file() and a.name != "manifesto.sha256"}
            elif p["estado"] == "derivavel":
                cont = da._conteudo(p)
            else:
                erros.append(f"{par} não se deriva: {p['motivo']}")
                continue
            pares += 1
            quer = ((paleta["flavors"].get(parceiro) or {}).get(ac) or "").upper()
            if quer:
                receita = cont.get(f"com.system76.CosmicTheme.{outro}.Builder/v2/accent", b"").decode().strip()
                focos = {linha.strip() for rel, dado in cont.items()
                         if rel.startswith(f"com.system76.CosmicTheme.{outro}/v2/")
                         for linha in dado.decode().splitlines() if linha.strip().startswith("focus: \"")}
                veste = receita == f'Some("{quer}FF")' and focos == {f'focus: "{quer}FF",'}
                if not veste:
                    erros.append(f"{par}: o {outro} veste {receita} e {sorted(focos)}, e o par pede {quer}FF")
                else:
                    lados += 1
            fora = ()
            if p["estado"] == "fotografia" or "conteudo" not in p:
                # A derivada da P48 com o outro lado vindo da base (é o que a P66
                # muda), e a foto (é o que a decisão sobre a mocha-pink pode mudar).
                fora = (f"com.system76.CosmicTheme.{outro}/", f"com.system76.CosmicTheme.{outro}.Builder/",
                        "captura.txt")
            for rel in sorted(cont):
                if not rel.startswith(fora):
                    soma.update(rel.encode() + b"\0" + cont[rel] + b"\0")
medida = soma.hexdigest()
print(f"{pares} pares; {lados} lados do par no acento do par; soma {medida}")
if medida != os.environ["MEOW_ESPERADA"]:
    erros.append(f"a soma do que não muda é {medida}, e a medida é {os.environ['MEOW_ESPERADA']}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; r=$?
[ "$r" = "0" ] \
  && ok "nos 84 pares, o lado do par — da derivada e da foto — veste o acento do par, e o resto é o de antes, byte a byte ($(printf '%s\n' "$saida" | head -1))" \
  || falha "o acento do lado do par, ou a soma do que não muda" "$saida"

#   O lado do par que não se deriva fica o da base, e a variante continua
#   aplicando (revisão da P66). Num Catppuccin de brinquedo: a Light da
#   `mocha-pink` com um `hover` que a conta não dá (o defeito que a GUI deixou
#   na Light da `mocha-mauve` de verdade), e depois sem Light nenhuma. Nos
#   dois, o mocha-green deriva do mocha-pink, com o claro dela byte a byte.
P1="$T/packs1"; mkdir -p "$P1"; cp -a "$RAIZ/packs/catppuccin" "$P1/" || exit 2
for cap in "$P1"/*/temas/capturados/*/; do
  grep -qs '^origem: derivada de ' "$cap/captura.txt" && rm -rf "$cap"
done
ROSA="$P1/catppuccin/temas/capturados/mocha-pink"
#   O `hover` é o do pink do latte desde a P68 (25/09/2026), que escreveu na
#   foto a Light no pink; antes era o #8041D6 do mauve.
sed -i 's/hover: "#CE72B9FF"/hover: "#CE72B8FF"/' "$ROSA/com.system76.CosmicTheme.Light/v2/accent"
grep -q 'hover: "#CE72B8FF"' "$ROSA/com.system76.CosmicTheme.Light/v2/accent" \
  || { printf 'erro: não consegui mexer na Light da mocha-pink de brinquedo\n' >&2; exit 2; }
saida="$(amb env MEOW_PACK_DIR="$P1/catppuccin" MEOW_PALETA="$P1/catppuccin/paleta.json" \
  python3 - "$RAIZ" "$ROSA" <<'PY' 2>&1
import json, os, shutil, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1] + "/scripts")
import derivar_acento as da
rosa = Path(sys.argv[2])
paleta = json.load(open(os.environ["MEOW_PALETA"]))
erros = []
for caso in ("com a Light que não se reproduz", "sem a Light"):
    if caso == "sem a Light":
        shutil.rmtree(rosa / "com.system76.CosmicTheme.Light")
        shutil.rmtree(rosa / "com.system76.CosmicTheme.Light.Builder")
    p = da.plano("mocha-green", paleta)
    if p["estado"] != "derivavel" or p.get("base") != "mocha-pink":
        erros.append(f"{caso}: estado={p['estado']} base={p.get('base')} {p.get('motivo', '')[:200]}")
        continue
    cont = da._conteudo(p)
    luz = {a.relative_to(rosa).as_posix(): a.read_bytes() for a in rosa.rglob("*")
           if a.is_file() and a.relative_to(rosa).as_posix().startswith("com.system76.CosmicTheme.Light")}
    na_derivada = {r: d for r, d in cont.items() if r.startswith("com.system76.CosmicTheme.Light")}
    linha = [l for l in cont["captura.txt"].decode().splitlines() if l.startswith("claro: ")]
    if na_derivada != luz:
        erros.append(f"{caso}: o claro da derivada não é o da mocha-pink, byte a byte")
    elif p.get("lado") != "o claro fica o do mocha-pink, sem o green do latte" \
            or not linha or not linha[0].startswith("claro: o do mocha-pink, no acento dele — o green "
                                                    "do latte não se deriva dele: "):
        erros.append(f"{caso}: lado={p.get('lado')!r} captura.txt={linha}")
    else:
        print(f"{caso}: {linha[0][:110]}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; r=$?
[ "$r" = "0" ] \
  && ok "o lado do par que não se deriva fica o da base, a variante continua aplicando, e o captura.txt diz por quê" \
  || falha "o lado do par que não se deriva derrubou a variante, ou não diz por quê" "$saida"

# --- 2. o desenho que saiu do mapa no ar sai do tema ------------------------
printf -- '--- 2. o desenho que saiu do mapa no ar ---\n'
#   Um pack próprio desta seção, para o mapa poder mudar.
P2="$T/packs2"; mkdir -p "$P2"; cp -a "$RAIZ/packs/dracula" "$P2/" || exit 2
MAPA2="$P2/dracula/icones/apps.map"
ALVO="$CASA/.local/share/icons/MeowSystem-Icons/scalable/apps"; mkdir -p "$ALVO"
REGISTRO="$ESTADO/icones-do-pack.tsv"
dracula_sh() {   # dracula_sh <verbo> — o passo do pack, com o Dracula no ar e a camada ligada
  env -i PATH="$CAMINHO" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$ESTADO" MEOW_PACKS="$P2" \
    MEOW_CONF=/caminho/inexistente LANG=C.UTF-8 NO_COLOR=1 \
    PACK=dracula FLAVOR=dracula ACCENT=mauve ICONES_DRACULA=sim \
    bash "$RAIZ/scripts/icones_apps_dracula.sh" "$1" 2>&1
}
arcade="$P2/dracula/icones/biblioteca/arcade.svg"
painel="$P2/dracula/icones/autorais/meowsystem-painel-dracula.svg"
mesmo() { [ -f "$1" ] && [ -f "$2" ] && [ "$(cat "$1")" = "$(cat "$2")" ]; }
# O outro dono: o `completar_icones.sh` põe o autoral do painel com os bytes do
# desenho do pack, sem linha em mapa nenhum.
cp "$painel" "$ALVO/com.meowsystem.Painel.svg"
printf 'programa-de-brinquedo : biblioteca/arcade.svg   # escolhido no teste\n' >> "$MAPA2"
saida="$(dracula_sh aplicar)"
mesmo "$arcade" "$ALVO/programa-de-brinquedo.svg" \
  && grep -q "^programa-de-brinquedo	$arcade\$" "$REGISTRO" 2>/dev/null \
  && ok "com a linha no mapa, o passo põe o arcade no tema e o anota no registro" \
  || falha "o passo não pôs o arcade, ou não o anotou" "$saida
$(head -3 "$REGISTRO" 2>&1)"
sed -i '/^programa-de-brinquedo /d' "$MAPA2"
cmp -s "$MAPA2" "$RAIZ/packs/dracula/icones/apps.map" || { printf 'erro: o mapa não voltou ao do repositório\n' >&2; exit 2; }
saida="$(dracula_sh --conferir)"; r=$?
[ "$r" = "1" ] && [[ "$saida" == *"apagaria $ALVO/programa-de-brinquedo.svg (desenho que saiu do mapa do pack no ar)"* ]] \
  && [ -f "$ALVO/programa-de-brinquedo.svg" ] \
  && ok "sem a linha, o --conferir diz que apagaria o arcade, e por quê — e não apaga (rc=$r)" \
  || falha "o --conferir não viu o arcade que saiu do mapa (rc=$r)" "$saida"
saida="$(dracula_sh aplicar)"
[ ! -e "$ALVO/programa-de-brinquedo.svg" ] \
  && ok "o passo tira do tema o arcade que saiu do mapa no ar" \
  || falha "o arcade continua no tema depois do passo" "$saida"
mesmo "$painel" "$ALVO/com.meowsystem.Painel.svg" \
  && ok "e o autoral do outro dono, com os bytes de um desenho do pack, fica" \
  || falha "o passo apagou o arquivo de outro dono" "$saida"
cp "$arcade" "$ALVO/programa-sem-registro.svg"
saida="$(dracula_sh aplicar)"; saida_c="$(dracula_sh --conferir)"; r=$?
[ -f "$ALVO/programa-sem-registro.svg" ] && [ "$r" = "0" ] \
  && ok "o que o registro não anotou fica, e o --conferir sai 0 (rc=$r)" \
  || falha "um arquivo que o registro não anotou saiu, ou o --conferir não fechou (rc=$r)" "$saida
$saida_c"

# --- 3. o mapa do Dracula com o pack vazio ---------------------------------
printf -- '--- 3. o mapa do Dracula com PACK vazio ---\n'
printf 'PACK=""\nFLAVOR="alucard"\nACCENT="mauve"\nICONES_DRACULA="sim"\n' > "$T/alucard.conf"
saida="$(env -i PATH="$CAMINHO" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/alucard.conf" \
           LANG=C.UTF-8 NO_COLOR=1 python3 - "$RAIZ" <<'PY' 2>&1
import os, sys
sys.path.insert(0, sys.argv[1] + "/app")
sys.path.insert(0, sys.argv[1] + "/scripts")
import servidor
import pack
m = servidor.Manipulador.__new__(servidor.Manipulador)
adotado = servidor._pack_adotado()
mapa = pack.acervo("icones.apps.mapa", ref=adotado)
do_mapa = {nome for _num, nome, _alvo in pack.ler_mapa(mapa)} if mapa else set()
da_grade = m._mapa_dracula()
print(f"adotado={adotado} mapa={len(do_mapa)} grade={len(da_grade)}")
sys.exit(0 if adotado == "dracula" and do_mapa and da_grade == do_mapa else 1)
PY
)"; r=$?
[ "$r" = "0" ] \
  && ok "com PACK vazio e FLAVOR=alucard, o _mapa_dracula dá os nomes do mapa do pack adotado ($saida)" \
  || falha "o _mapa_dracula não dá o mapa do pack adotado" "$saida"

# --- 4. o molde das pastas numa regra só -----------------------------------
printf -- '--- 4. o molde do ICONES_PASTAS numa regra só ---\n'
copias="$(grep -c 'cat--?\*)' "$RAIZ/bin/meow" "$RAIZ/app/servidor.py" "$RAIZ/lib/comum.sh" | tr '\n' ' ')"
[ "$copias" = "$RAIZ/bin/meow:0 $RAIZ/app/servidor.py:0 $RAIZ/lib/comum.sh:1 " ] \
  && grep -q '^  meow_pastas_do_molde$' "$RAIZ/bin/meow" \
  && grep -q "'meow_pastas_do_molde " "$RAIZ/app/servidor.py" \
  && ok "o molde cat--<acento> é completado num lugar só (o meow_pastas_do_molde), e o bin/meow e o painel o chamam" \
  || falha "o molde das pastas continua escrito em mais de um lugar" "$copias"
printf 'PACK="dracula"\nFLAVOR=""\nACCENT="mauve"\nICONES_PASTAS="cat-${FLAVOR}-${ACCENT}"\n' > "$T/molde.conf"
saida="$(env -i PATH="$CAMINHO" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/molde.conf" \
           LANG=C.UTF-8 NO_COLOR=1 python3 - "$RAIZ" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1] + "/app")
import servidor
print((servidor.conf_exportada() or {}).get("ICONES_PASTAS", "?"))
PY
)"
[ "$saida" = "cat-dracula-mauve" ] \
  && ok "o painel completa o molde de fábrica com o FLAVOR vazio: $saida" \
  || falha "o painel deu ICONES_PASTAS='$saida', e o molde pede cat-dracula-mauve"

# --- 5. o --conferir das pastas especiais não fala como quem faz -----------
printf -- '--- 5. o --conferir das pastas especiais ---\n'
LUGARES="$CASA/.local/share/icons/MeowSystem-Icons/scalable/places"; mkdir -p "$LUGARES"
cp "$RAIZ/packs/dracula/icones/pastas/folder-documents.svg" "$LUGARES/"
pastas() {   # pastas <verbo> — sem PASTAS_XDG, que é o desligado de fábrica
  env -i PATH="$CAMINHO" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$ESTADO" \
    LANG=C.UTF-8 NO_COLOR=1 PACK=dracula FLAVOR=dracula \
    bash "$RAIZ/scripts/icones_pastas.sh" "$1" 2>&1
}
saida="$(pastas --conferir)"; r=$?
[ "$r" = "1" ] && [[ "$saida" == *"devolveria as pastas especiais"* ]] && [[ "$saida" != *devolvendo* ]] \
  && [ -f "$LUGARES/folder-documents.svg" ] \
  && ok "com as pastas especiais desligadas e o desenho no disco, o --conferir diz «devolveria» e não mexe (rc=$r)" \
  || falha "o --conferir das pastas fala no tempo de quem faz (rc=$r)" "$saida"
saida="$(pastas --aplicar)"; r=$?
[ "$r" = "1" ] && [[ "$saida" == *"devolvendo as pastas especiais"* ]] && [ ! -e "$LUGARES/folder-documents.svg" ] \
  && ok "e o --aplicar diz «devolvendo» e devolve (rc=$r)" \
  || falha "o --aplicar das pastas não devolveu (rc=$r)" "$saida"

# --- 6. a montagem numa função só ------------------------------------------
printf -- '--- 6. a montagem do lado do par ---\n'
grep -q 'conteudo = da.montar(cand, ' "$RAIZ/scripts/derivar_flavor.py" \
  && grep -q 'conteudo=montar(cand, lado\["arvore"\], lado\["conteudo"\])' "$RAIZ/scripts/derivar_acento.py" \
  && ok "os dois planos montam a captura pelo montar do derivar_acento.py (a soma da seção 1 é a prova de que ela é a mesma)" \
  || falha "a montagem do lado do par não é a função única nos dois derivadores"

# --- 7. o repositório não mudou --------------------------------------------
[ "$(git -C "$RAIZ" status --porcelain 2>/dev/null; git -C "$RAIZ" status --porcelain --ignored -- packs 2>/dev/null)" = "$git_antes" ] \
  && ok "o repositório saiu como entrou" \
  || falha "o teste mexeu no repositório" "$(git -C "$RAIZ" status --porcelain)"

printf '\n'
[ "$falhas" = "0" ] && { printf 'notas-de-funcao: tudo certo\n'; exit 0; }
printf 'notas-de-funcao: %d achado(s)\n' "$falhas"
exit 1

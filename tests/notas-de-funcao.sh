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
#        brinquedo: o lado do par veste agora o acento pedido, nos 14 acentos
#        do latte e do mocha; e o que já estava certo não muda um byte (a soma
#        abaixo).
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
#   sem escrever nada), com uma exceção: nas derivadas da P48 cujo outro lado é
#   o da base (o latte e o mocha, que têm foto do par), o outro lado e o
#   `captura.txt` ficam fora — são eles que a P66 muda. Medido em 25/09/2026 com
#   o código de antes da P66 e com o de depois: o mesmo número. Mexer em
#   qualquer outro byte de captura é outra decisão, e quem a tomar troca este
#   número junto.
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

SOMA_MEDIDA="0ae8a776b2f41b17a3ac54c67a3672ebbbd6c2b121b24890539a1aaf495f6e56"

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
            fora = ()
            if p["estado"] == "derivavel" and "conteudo" not in p:
                # A derivada da P48 com o outro lado vindo da base: ele é o que muda.
                outro = "Dark" if p["arvore"] == "Light" else "Light"
                fora = (f"com.system76.CosmicTheme.{outro}/", f"com.system76.CosmicTheme.{outro}.Builder/",
                        "captura.txt")
                parceiro = df.par_do_outro_lado(fl, paleta)
                quer = paleta["flavors"][parceiro][ac].upper() + "FF"
                receita = cont[f"com.system76.CosmicTheme.{outro}.Builder/v2/accent"].decode().strip()
                focos = {linha.strip() for rel, dado in cont.items()
                         if rel.startswith(f"com.system76.CosmicTheme.{outro}/v2/")
                         for linha in dado.decode().splitlines() if linha.strip().startswith("focus: \"")}
                if receita != f'Some("#{quer[1:]}")' or focos != {f'focus: "{quer}",'}:
                    erros.append(f"{par}: o {outro} veste {receita} e {sorted(focos)}, e o par pede {quer}")
                lados += 1
            for rel in sorted(cont):
                if not rel.startswith(fora):
                    soma.update(rel.encode() + b"\0" + cont[rel] + b"\0")
medida = soma.hexdigest()
print(f"{pares} pares; {lados} lados do par conferidos; soma {medida}")
if medida != os.environ["MEOW_ESPERADA"]:
    erros.append(f"a soma do que não muda é {medida}, e a medida é {os.environ['MEOW_ESPERADA']}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; r=$?
[ "$r" = "0" ] \
  && ok "nos 14 acentos, o lado do par do latte e do mocha veste o acento do par, e o resto das 84 capturas é o de antes, byte a byte ($(printf '%s\n' "$saida" | head -1))" \
  || falha "o acento do lado do par, ou a soma do que não muda" "$saida"

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

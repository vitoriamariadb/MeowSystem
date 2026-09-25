#!/usr/bin/env bash
# vidro-do-cosmic.sh — o vidro que o tema grava é o do alpha_map que o COSMIC tem.
#
# POR QUE ESTE ARQUIVO NASCEU EM 25/09/2026 (sprint P58)
#   Medido na máquina dela: o `alpha_map` ao vivo, que o slider «Opacidade do
#   vidro» gravou em 17/09, dá `very_high_2: 0.52615` (alpha 86). A captura
#   `dracula-mauve` traz o mapa do dia da foto, 0.66615 (alpha AA), e o
#   `transparent_background` dela é `#383A4CAA`. Com o `frosted` em `VeryHigh2`
#   nos dois, o tema aplicado deixava o vidro em AA (67 %) com o nível pedindo
#   86 (52 %); o `aplicar_tema.sh --conferir` dizia "já aplicado (189 arquivos
#   conferem)"; e o `vidro.sh` mandava reaplicar a captura que já estava
#   aplicada.
#   (Revisão da P58, 25/09/2026: a primeira redação dizia "gravado pelo COSMIC
#   atualizado"; nenhum pacote do COSMIC mudou entre 11 e 21/09. A medição
#   está no cabeçalho do scripts/derivar_vidro.py.)
#
#   A prova que a sprint pediu: numa casa de brinquedo com o `alpha_map` novo,
#   aplicar `dracula-mauve` grava o `transparent_background` com alpha 86, e o
#   `vidro.sh` confere sem aviso; com o mapa da captura, os bytes são os de hoje.
#
# OS VALORES ESPERADOS NÃO SÃO CONTA DESTE TESTE
#   Os catorze campos do vidro da seção 1 são os que a GUI desta máquina
#   (cosmic-settings 1.7.0) gravou em 17/09 22:35:41, quando o slider gravou
#   este mapa, com esta mesma receita — estão no backup do `aplicar_tema.sh` de
#   21/09 16:51, que preserva o mtime —, e são também o que o
#   `ThemeBuilder::build()` do libcosmic escreve no oráculo de bancada. O `on`
#   da seção 3 é o do oráculo (commit c003a58).
#   (Revisão da P58: a primeira redação dizia que era o cosmic-settings 1.9.0,
#   entre 19 e 21/09. O 1.9.0 entrou às 16:49 de 21/09, e nenhuma derivação
#   dele com este mapa está em disco.)
#
# O MAPA ENTRA ESCRITO AQUI, E NÃO LIDO DO ~/.config/cosmic
#   Este teste é portátil: o mapa de 17/09 vai literal, como o COSMIC o grava.
#   Nada fora do temporário: COSMIC, casa, estado, packs e TMPDIR de brinquedo,
#   `env -i` em toda chamada.
#
#   0 = passou · 1 = achados · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
CASA="$T/casa"; ESTADO="$T/estado"; PACKS="$T/packs"; TMPV="$T/tmp"
mkdir -p "$CASA" "$ESTADO" "$PACKS" "$TMPV"
cp -a "$RAIZ/packs/dracula" "$RAIZ/packs/catppuccin" "$PACKS/" || exit 2
CAP="$PACKS/dracula/temas/capturados/dracula-mauve"
git_antes="$(git -C "$RAIZ" status --porcelain 2>/dev/null)"

# O `alpha_map` que o slider gravou em 17/09, byte a byte.
MAPA_NOVO='(
    extremely_low: 0.78,
    extremely_low_2: 0.75692,
    very_low: 0.73385,
    very_low_2: 0.71076,
    low: 0.68769,
    low_2: 0.66460997,
    medium: 0.64154,
    medium_2: 0.61846,
    high: 0.59538,
    high_2: 0.57231,
    very_high: 0.54023,
    very_high_2: 0.52615,
    extremely_high: 0.50308,
    extremely_high_2: 0.48000002,
)'

amb() {   # amb <cosmic> <pack> <comando...>
  local cosmic="$1" pack="$2"; shift 2
  env -i PATH="$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$ESTADO" \
    MEOW_COSMIC_DIR="$cosmic" MEOW_PACK_DIR="$PACKS/$pack" TMPDIR="$TMPV" \
    LANG=C.UTF-8 NO_COLOR=1 "$@"
}
aplicar() { local c="$1"; shift; amb "$c" dracula bash "$RAIZ/scripts/aplicar_tema.sh" "$@" 2>&1; }
# O vidro.sh escreve o `frosted_maximized_apps` na primeira passagem (a
# captura traz `false`, o padrão é "sim") e só confere a receita quando não
# escreveu nada; a conferência que interessa é a da segunda.
vidro() {
  amb "$1" dracula env FLAVOR=dracula ACCENT=mauve bash "$RAIZ/scripts/vidro.sh" >/dev/null 2>&1
  amb "$1" dracula env FLAVOR=dracula ACCENT=mauve bash "$RAIZ/scripts/vidro.sh" 2>&1
}
valor() {  # valor <arquivo> <caminho>: a cor de um campo, pelo parser RON do projeto
  python3 - "$RAIZ" "$1" "$2" <<'FIM'
import sys
sys.path.insert(0, sys.argv[1] + "/scripts")
import gerar_tema_v1 as v1
print(v1.achatar(v1.parse(open(sys.argv[2], encoding="utf-8").read())).get(sys.argv[3], ("", ""))[1])
FIM
}
mapa_novo_em() {   # os quatro alpha_map de um COSMIC de brinquedo viram o de 17/09
  local c="$1" arv
  for arv in Dark.Builder Dark Light.Builder Light; do
    mkdir -p "$c/com.system76.CosmicTheme.$arv/v2"
    printf '%s' "$MAPA_NOVO" > "$c/com.system76.CosmicTheme.$arv/v2/alpha_map"
  done
}

# --- 1. o estado desta máquina: a foto aplicada, o mapa de 17/09 ------------
C1="$T/cosmic1"; mkdir -p "$C1"
cp -a "$CAP"/com.system76.CosmicTheme.* "$C1/"
mapa_novo_em "$C1"

saida="$(vidro "$C1")"; rc=$?
if [ "$rc" = "4" ] && [[ "$saida" == *"'VeryHigh2' pede alpha 86, está gravado AA"* ]] \
   && [[ "$saida" == *"aplicada aqui, grava o alpha 86 deste nível:  meow tema dracula-mauve"* ]]; then
  ok "antes: o vidro.sh vê AA com o nível pedindo 86, e o conselho é o que resolve"
else
  falha "o vidro.sh não descreveu o estado de partida (rc=$rc)" "$saida"
fi

saida="$(aplicar "$C1" dracula-mauve --respeitar-gui --conferir)"; rc=$?
[ "$rc" = "1" ] \
  && ok "o --conferir deixou de dizer «já aplicado» com o vidro errado ($saida)" \
  || falha "o --conferir ainda confere a foto com o vidro de outro mapa (rc=$rc)" "$saida"

# O caminho do «Salvar e aplicar»: a etapa tema do install.sh chama assim.
saida="$(aplicar "$C1" dracula-mauve --respeitar-gui)"; rc=$?
if [ "$rc" = "0" ] && [[ "$saida" == *"vidro: Dark 'VeryHigh2' = alpha 86 do alpha_map deste COSMIC (a captura trazia AA)"* ]] \
   && [[ "$saida" == *"0 preservados da sua GUI"* ]]; then
  ok "aplicar pela manutenção grava o vidro do mapa instalado, e não cede a foto velha à GUI"
else
  falha "a aplicação não derivou o vidro (rc=$rc)" "$saida"
fi

esperados="transparent_background base #383A4C86
transparent_background component.base #4D4F6286
transparent_background component.hover #595B6B92
transparent_background component.pressed #6769769E
transparent_background component.selected #595B6B92
transparent_background component.disabled #4D4F6243
transparent_background divider #595A669E
transparent_primary base #282A36D3
transparent_primary component.base #383B47D3
transparent_primary component.hover #383B47D3
transparent_primary component.pressed #383B47D3
transparent_primary component.selected #383B47D3
transparent_primary component.disabled #383B4769
transparent_primary divider #52535CDC"
errados=""
while read -r arq cam quer; do
  tem="$(valor "$C1/com.system76.CosmicTheme.Dark/v2/$arq" "$cam")"
  [ "$tem" = "$quer" ] || errados+="$arq $cam: $tem (esperado $quer)"$'\n'
done <<< "$esperados"
[ -z "$errados" ] \
  && ok "Dark/v2: os 14 campos do vidro são os que a GUI derivou com este mapa em 17/09 (base #383A4C86)" \
  || falha "o vidro da Dark/v2 não é o que a GUI derivou com este mapa" "$errados"

# A Light muda de vidro na mesma aplicação, e o teste não olhava para ela
# (revisão da P58, 25/09/2026). Aqui a GUI não serve de referência: em 17/09
# ela gravou o mapa nas duas árvores e rederivou só a Dark. Os campos abaixo
# são os que o `build()` do libcosmic escreve no oráculo de bancada com a
# receita Light da captura e este mapa.
# REFEITOS NA P63 (25/09/2026), quando a Light da captura deixou de ser o Latte
# (VeryHigh2, 49 para 86) e passou a ser a derivada do alucard, com o nível do
# latte-mauve de onde ela sai: `VeryLow2`, D9 para B5. Com B5 o texto sobe de
# degrau — o `get_text()` anda mais quanto mais translúcido o fundo, a seção 3
# conta —, e não só nos três `transparent_*`: o `on`, o `divider` e o
# `on_disabled` do background, do primary, do secondary, do button e do
# list_button andam junto (o #020210 da captura vira #090B1F). São 48 campos, e
# a lista abaixo é a INTEIRA: os valores são os do oráculo, com a receita nova e
# este mapa, e das 288 cores da Light/v2 a aplicação dá as 288 dele, menos o
# alpha da Aurora no `base:` do `secondary` (ver o aplicar_tema.sh), que não
# muda aqui.
esperados_claro="transparent_background base #CECFDCB5
transparent_background component.base #ECEDFAB5
transparent_background component.hover #E6E7F2BD
transparent_background component.pressed #E2E2ECC4
transparent_background component.selected #E6E7F2BD
transparent_background component.disabled #ECEDFA5B
transparent_background component.divider #090B1F33
transparent_background component.on #090B1FFF
transparent_background component.on_disabled #090B1FA6
transparent_background divider #9999A5C4
transparent_background on #010009FF
transparent_primary base #F0F0F6F5
transparent_primary component.base #E0E0E6F5
transparent_primary component.hover #E0E0E6F5
transparent_primary component.pressed #E0E0E6F5
transparent_primary component.selected #E0E0E6F5
transparent_primary component.disabled #E0E0E67A
transparent_primary component.divider #03041533
transparent_primary component.on #030415FF
transparent_primary component.on_disabled #030415A6
transparent_primary divider #C1C1CAF7
transparent_primary on #0B0E21FF
transparent_secondary component.divider #090B1F33
transparent_secondary component.on #090B1FFF
transparent_secondary component.on_disabled #090B1FA6
transparent_secondary divider #C5C6D3FF
transparent_secondary on #0D1024FF
background on #010009FF
background divider #9FA0ACE1
background component.on #090B1FFF
background component.divider #090B1F33
background component.on_disabled #090B1FA6
primary on #0B0E21FF
primary divider #C2C3CBFF
primary component.on #030415FF
primary component.divider #03041533
primary component.on_disabled #030415A6
secondary on #0D1024FF
secondary divider #BFC0CCE1
secondary component.on #090B1FFF
secondary component.divider #090B1F33
secondary component.on_disabled #090B1FA6
button on #090B1FFF
button divider #090B1F33
button on_disabled #090B1FA6
list_button on #090B1FFF
list_button divider #090B1F33
list_button on_disabled #090B1FA6"
# Campo a campo, a Light/v2 aplicada contra a da captura: o que mudou tem de ser
# exatamente a lista, com o valor dela; e a Light/v1 é o RGB da v2 nova, pela
# mesma função do gerar_tema_v1.py, com o alpha do molde.
errados="$(python3 - "$RAIZ" "$CAP" "$C1" "$esperados_claro" <<'FIM'
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1] + "/scripts")
import gerar_tema_v1 as v1
cap, cos = Path(sys.argv[2]), Path(sys.argv[3])
quer = {}
for linha in sys.argv[4].splitlines():
    arq, cam, hexa = linha.split()
    quer[(arq, cam)] = hexa
def cores(arq):
    try:
        return {c: v for c, (t, v, _n) in v1.achatar(v1.parse(arq.read_text(encoding="utf-8"))).items()
                if t == "cor"}
    except (OSError, ValueError, IndexError):
        return {}
erros = []
mudou = {}
for a in sorted((cap / "com.system76.CosmicTheme.Light/v2").iterdir()):
    antes, depois = cores(a), cores(cos / a.relative_to(cap))
    for cam, v in antes.items():
        if depois.get(cam, "").upper() != v.upper():
            mudou[(a.name, cam)] = depois.get(cam, "nada")
for chave in sorted(mudou.keys() | quer.keys()):
    tem, esp = mudou.get(chave), quer.get(chave)
    if esp is None:
        erros.append(f"{chave[0]} {chave[1]} mudou para {tem}, e não é campo do vidro")
    elif tem is None or tem.upper() != esp:
        erros.append(f"{chave[0]} {chave[1]}: {tem or 'o da captura'} (esperado {esp})")
for chave in v1.CONJUNTO:
    molde = cap / "com.system76.CosmicTheme.Light/v1" / chave
    fonte = cos / "com.system76.CosmicTheme.Light/v2" / chave
    if molde.is_file() and fonte.is_file():
        txt, _ = v1.gerar_arquivo(molde.read_text(encoding="utf-8"), fonte.read_text(encoding="utf-8"))
        if (cos / "com.system76.CosmicTheme.Light/v1" / chave).read_text(encoding="utf-8") != txt:
            erros.append(f"Light/v1/{chave} não é o RGB da Light/v2 aplicada")
print("\n".join(erros))
FIM
)"
[ -z "$errados" ] \
  && ok "Light/v2: os transparent_* saem do D9 da captura para B5, o texto sobe de degrau, e os 48 campos que mudam são os do build() (base #CECFDCB5); a v1 acompanha" \
  || falha "o vidro da Light/v2 não é o que o build() dá com este mapa" "$errados"

# Fora do vidro, nada: todo o resto é a foto, byte a byte (as chaves dela e
# o que o vidro.sh escreve são dela e ficam). A Light/v2 e a Light/v1 saem
# desta conta desde a P63: o degrau do texto delas é vidro, e a conferência
# campo a campo, logo acima, é que diz o que nelas podia mudar.
fora=""
while IFS= read -r -d '' a; do
  rel="${a#"$CAP"/}"
  case "$rel" in manifesto.sha256|captura.txt|.gitignore) continue ;; esac
  case "$(basename "$rel")" in alpha_map|frosted|frosted_maximized_apps) continue ;; esac
  case "$rel" in com.system76.CosmicTheme.*/v2/transparent_*) continue ;; esac
  case "$rel" in com.system76.CosmicTheme.Light/v[12]/*) continue ;; esac
  cmp -s "$a" "$C1/$rel" || fora+="$rel"$'\n'
done < <(find "$CAP" -type f -print0)
[ -z "$fora" ] \
  && ok "fora do vidro nada mudou: o resto do COSMIC é a captura byte a byte" \
  || falha "a derivação do vidro mexeu fora do vidro" "$fora"

r1="$(aplicar "$C1" dracula-mauve --respeitar-gui --conferir)"; c1=$?
r2="$(aplicar "$C1" dracula-mauve --conferir)"; c2=$?
[ "$c1" = "0" ] && [ "$c2" = "0" ] \
  && ok "depois, as duas conferências dizem «já aplicado» (sem ping-pong com o doctor)" \
  || falha "depois de aplicar, a conferência ainda diverge (rc=$c1 $c2)" "$r1
$r2"

saida="$(vidro "$C1")"; rc=$?
if [ "$rc" = "0" ] && [[ "$saida" != *"não é o que você escolheu"* ]]; then
  ok "o vidro.sh confere sem aviso"
else
  falha "o vidro.sh ainda avisa depois de aplicar (rc=$rc)" "$saida"
fi
[ "$(cat "$C1/com.system76.CosmicTheme.Dark.Builder/v2/alpha_map")" = "$MAPA_NOVO" ] \
  && ok "e o alpha_map continua o do COSMIC instalado (é dela, não se sobrescreve)" \
  || falha "aplicar o tema sobrescreveu o alpha_map instalado"

# --- 2. com o mapa da captura, os bytes de hoje ------------------------------
#   Máquina nova (COSMIC vazio): a captura grava o mapa dela, e o vidro dela é
#   o certo. É a cópia byte a byte de sempre, e a saída não ganha linha.
C2="$T/cosmic2"; mkdir -p "$C2"
saida="$(aplicar "$C2" dracula-mauve)"; rc=$?
difere=""
while IFS= read -r -d '' a; do
  rel="${a#"$CAP"/}"
  case "$rel" in manifesto.sha256|captura.txt|.gitignore) continue ;; esac
  cmp -s "$a" "$C2/$rel" || difere+="$rel"$'\n'
done < <(find "$CAP" -type f -print0)
if [ "$rc" = "0" ] && [ -z "$difere" ] && [[ "$saida" != *"vidro:"* ]]; then
  ok "COSMIC vazio: a captura inteira chega byte a byte, sem linha de vidro"
else
  falha "com o mapa da captura, os bytes não são os de hoje (rc=$rc)" "$difere$saida"
fi
#   E o COSMIC que já tem a foto com o mapa dela confere de primeira.
saida="$(aplicar "$C2" dracula-mauve --conferir)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" == "tema 'dracula-mauve' já aplicado (189 arquivos conferem)" ]] \
  && ok "com o mapa da captura, a foto confere de primeira: $saida" \
  || falha "com o mapa da captura, a foto deixou de conferir (rc=$rc)" "$saida"
#   E um COSMIC POVOADO com o mapa da captura, que a seção só via vazio
#   (revisão da P58, 25/09/2026). Outro tema aplicado — o mocha-pink, cujo
#   `frosted` é outro — e as chaves dela iguais às da captura (o mapa, o nível,
#   o vidro ao maximizar, o modo): não há vidro a derivar, e a troca é a cópia
#   de sempre, árvore por árvore, sem linha de vidro.
C5="$T/cosmic5"; mkdir -p "$C5"
cp -a "$PACKS/catppuccin/temas/capturados/mocha-pink"/com.system76.CosmicTheme.* "$C5/"
while IFS= read -r -d '' a; do
  rel="${a#"$CAP"/}"
  case "$rel" in com.system76.CosmicTheme.Mode/v1/is_dark|com.system76.CosmicTheme.Mode/v1/auto_switch) cp "$a" "$C5/$rel" ;; esac
  case "$(basename "$rel")" in alpha_map|frosted|frosted_maximized_apps) cp "$a" "$C5/$rel" ;; esac
done < <(find "$CAP" -type f -print0)
saida="$(aplicar "$C5" dracula-mauve)"; rc=$?
difere=""
for arv in "$CAP"/com.system76.CosmicTheme.*; do
  diff -rq "$arv" "$C5/$(basename "$arv")" >/dev/null 2>&1 || difere+="$(basename "$arv")"$'\n'
done
if [ "$rc" = "0" ] && [ -z "$difere" ] && [[ "$saida" != *"vidro"* ]]; then
  ok "COSMIC povoado com o mapa da captura: a troca chega byte a byte, sem linha de vidro"
else
  falha "com o mapa da captura num COSMIC povoado, as árvores não são as da captura (rc=$rc)" "$difere$saida"
fi

# --- 3. o texto que muda de degrau --------------------------------------------
#   O `get_text()` do libcosmic anda mais degraus quanto mais translúcido o
#   fundo. O `mocha-pink` foi fotografado em `VeryLow2` (alpha D9); com o nível
#   `VeryHigh2` do mapa novo o texto do background sobe de #F6F8FF para
#   #FFFFFF — e a v1, que é o RGB da v2, acompanha. Trocar só dois dígitos de
#   alpha deixaria o texto no degrau de outro vidro.
C3="$T/cosmic3"; mkdir -p "$C3"
mapa_novo_em "$C3"
for arv in Dark Light; do printf 'VeryHigh2' > "$C3/com.system76.CosmicTheme.$arv.Builder/v2/frosted"; done
saida="$(amb "$C3" catppuccin bash "$RAIZ/scripts/aplicar_tema.sh" mocha-pink 2>&1)"; rc=$?
on="$(valor "$C3/com.system76.CosmicTheme.Dark/v2/background" on)"
tb="$(valor "$C3/com.system76.CosmicTheme.Dark/v2/transparent_background" base)"
v1_on="$(awk '/^    on: \(/{f=1;next} f&&/red:/{print $2; exit}' "$C3/com.system76.CosmicTheme.Dark/v1/background")"
if [ "$rc" = "0" ] && [ "$on" = "#FFFFFFFF" ] && [ "$tb" = "#31324486" ] && [ "$v1_on" = "1.0," ]; then
  ok "mocha-pink com o mapa novo: o texto sobe de degrau (on $on, v1 red $v1_on) e o vidro é 86 ($tb)"
else
  falha "o texto do mocha-pink não seguiu o vidro (rc=$rc, on=$on, tb=$tb, v1 red=$v1_on)" "$saida"
fi

# --- 4. a captura cujo vidro não fecha: fica como está, e o doctor não manda reaplicar
#   Um `transparent_background` com um alpha que o `build()` não escreveria
#   (AB) é um campo que outra coisa gravou. A guarda recusa a árvore, a captura
#   vai como está, e o `vidro.sh` para de oferecer o `meow tema` como conserto:
#   aplicada aqui, ela grava AB de novo.
sed -i '0,/^    base: "#383A4CAA"/s//    base: "#383A4CAB"/' \
  "$CAP/com.system76.CosmicTheme.Dark/v2/transparent_background"
C4="$T/cosmic4"; mkdir -p "$C4"
cp -a "$CAP"/com.system76.CosmicTheme.* "$C4/"
mapa_novo_em "$C4"
saida_a="$(aplicar "$C4" dracula-mauve)"; rc_a=$?
saida="$(vidro "$C4")"; rc=$?
if [ "$rc_a" = "0" ] && [[ "$saida_a" == *"fica com o vidro da captura — Dark: o vidro da captura não se reproduz"* ]] \
   && [ "$(valor "$C4/com.system76.CosmicTheme.Dark/v2/transparent_background" base)" = "#383A4CAB" ] \
   && [ "$rc" = "4" ] && [[ "$saida" == *"reaplicar a captura 'dracula-mauve' não resolve: aplicada aqui, ela grava alpha AB"* ]] \
   && [[ "$saida" != *"meow tema"* ]]; then
  ok "vidro que não fecha: a captura vai como está, a frase diz por quê, e o doctor não manda reaplicar"
else
  falha "a captura com vidro inconsistente não foi tratada como devia (aplicar rc=$rc_a, vidro rc=$rc)" "$saida_a
$saida"
fi

# --- 4b. o porquê chega à tela: em português, e também no seco ----------------
#   Achados da revisão da P58 (25/09/2026). O seco é `--conferir` por dentro, e
#   a frase do vidro sumia dele: a tela dizia «mudaria …/transparent_*» sem o
#   motivo. E um nível do `alpha_map` que não é número punha na tela o erro do
#   Python em inglês. (A captura voltou a ser a do repositório, com o AA.)
cp "$RAIZ/packs/dracula/temas/capturados/dracula-mauve/com.system76.CosmicTheme.Dark/v2/transparent_background" \
  "$CAP/com.system76.CosmicTheme.Dark/v2/transparent_background"
C6="$T/cosmic6"; mkdir -p "$C6"
cp -a "$CAP"/com.system76.CosmicTheme.* "$C6/"
mapa_novo_em "$C6"
saida="$(amb "$C6" dracula env MEOW_DRY_RUN=1 bash "$RAIZ/scripts/aplicar_tema.sh" dracula-mauve 2>&1)"; rc=$?
if [ "$rc" = "1" ] \
   && [[ "$saida" == *"vidro: Dark 'VeryHigh2' = alpha 86 do alpha_map deste COSMIC (a captura trazia AA)"* ]] \
   && [[ "$saida" == *"mudaria  com.system76.CosmicTheme.Dark/v2/transparent_background"* ]] \
   && [ "$(valor "$C6/com.system76.CosmicTheme.Dark/v2/transparent_background" base)" = "#383A4CAA" ]; then
  ok "no seco, o «mudaria» do vidro vem com o motivo, e nada é escrito"
else
  falha "o seco não disse por que o vidro mudaria (rc=$rc)" "$saida"
fi
C7="$T/cosmic7"; mkdir -p "$C7"
cp -a "$CAP"/com.system76.CosmicTheme.* "$C7/"
mapa_novo_em "$C7"
sed -i 's/very_high_2: 0.52615/very_high_2: abc/' "$C7/com.system76.CosmicTheme.Dark.Builder/v2/alpha_map"
saida="$(aplicar "$C7" dracula-mauve)"; rc=$?
if [ "$rc" = "0" ] \
   && [[ "$saida" == *"Dark: o alpha_map dá ao nível VeryHigh2 o valor abc, que não é número"* ]] \
   && [[ "$saida" != *"could not convert"* ]] \
   && [ "$(valor "$C7/com.system76.CosmicTheme.Dark/v2/transparent_background" base)" = "#383A4CAA" ]; then
  ok "um nível que não é número: a frase diz qual, em português, e a Dark fica com o vidro da captura"
else
  falha "o alpha_map malformado não chegou à tela como devia (rc=$rc)" "$saida"
fi

# --- 5. nada fica para trás ----------------------------------------------------
sobra="$(find "$TMPV" -mindepth 1 -maxdepth 1 2>/dev/null)"
[ -z "$sobra" ] \
  && ok "a cópia de trabalho do vidro some com o script (TMPDIR vazio)" \
  || falha "sobrou cópia de trabalho no TMPDIR" "$sobra"
[ "$(git -C "$RAIZ" status --porcelain 2>/dev/null)" = "$git_antes" ] \
  && ok "o repositório não ganhou nem perdeu arquivo" \
  || falha "o teste sujou o repositório" "$(git -C "$RAIZ" status --porcelain)"

[ "$falhas" -eq 0 ] && { printf '\nvidro-do-cosmic: tudo certo\n'; exit 0; }
printf '\nvidro-do-cosmic: %s achado(s)\n' "$falhas" >&2
exit 1

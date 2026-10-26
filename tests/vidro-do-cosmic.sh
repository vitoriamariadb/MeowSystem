#!/usr/bin/env bash
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
cp -a "$RAIZ/packs/dracula" "$RAIZ/packs/meowsystem" "$PACKS/" || exit 2
CAP="$PACKS/dracula/temas/capturados/dracula-mauve"
git_antes="$(git -C "$RAIZ" status --porcelain 2>/dev/null)"

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

amb() {
  local cosmic="$1" pack="$2"; shift 2
  env -i PATH="$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$ESTADO" \
    MEOW_COSMIC_DIR="$cosmic" MEOW_PACK_DIR="$PACKS/$pack" TMPDIR="$TMPV" \
    LANG=C.UTF-8 NO_COLOR=1 "$@"
}
aplicar() { local c="$1"; shift; amb "$c" dracula bash "$RAIZ/scripts/aplicar_tema.sh" "$@" 2>&1; }
vidro() {
  amb "$1" dracula env FLAVOR=dracula ACCENT=mauve bash "$RAIZ/scripts/vidro.sh" >/dev/null 2>&1
  amb "$1" dracula env FLAVOR=dracula ACCENT=mauve bash "$RAIZ/scripts/vidro.sh" 2>&1
}
valor() {
  python3 - "$RAIZ" "$1" "$2" <<'FIM'
import sys
sys.path.insert(0, sys.argv[1] + "/scripts")
import gerar_tema_v1 as v1
print(v1.achatar(v1.parse(open(sys.argv[2], encoding="utf-8").read())).get(sys.argv[3], ("", ""))[1])
FIM
}
mapa_novo_em() {
  local c="$1" arv
  for arv in Dark.Builder Dark Light.Builder Light; do
    mkdir -p "$c/com.system76.CosmicTheme.$arv/v2"
    printf '%s' "$MAPA_NOVO" > "$c/com.system76.CosmicTheme.$arv/v2/alpha_map"
  done
}

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
saida="$(aplicar "$C2" dracula-mauve --conferir)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" == "tema 'dracula-mauve' já aplicado (189 arquivos conferem)" ]] \
  && ok "com o mapa da captura, a foto confere de primeira: $saida" \
  || falha "com o mapa da captura, a foto deixou de conferir (rc=$rc)" "$saida"
C5="$T/cosmic5"; mkdir -p "$C5"
cp -a "$PACKS/meowsystem/temas/capturados/mocha-pink"/com.system76.CosmicTheme.* "$C5/"
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

C3="$T/cosmic3"; mkdir -p "$C3"
mapa_novo_em "$C3"
for arv in Dark Light; do printf 'VeryHigh2' > "$C3/com.system76.CosmicTheme.$arv.Builder/v2/frosted"; done
saida="$(amb "$C3" meowsystem bash "$RAIZ/scripts/aplicar_tema.sh" mocha-pink 2>&1)"; rc=$?
on="$(valor "$C3/com.system76.CosmicTheme.Dark/v2/background" on)"
tb="$(valor "$C3/com.system76.CosmicTheme.Dark/v2/transparent_background" base)"
v1_on="$(awk '/^    on: \(/{f=1;next} f&&/red:/{print $2; exit}' "$C3/com.system76.CosmicTheme.Dark/v1/background")"
if [ "$rc" = "0" ] && [ "$on" = "#FFFFFFFF" ] && [ "$tb" = "#31324486" ] && [ "$v1_on" = "1.0," ]; then
  ok "mocha-pink com o mapa novo: o texto sobe de degrau (on $on, v1 red $v1_on) e o vidro é 86 ($tb)"
else
  falha "o texto do mocha-pink não seguiu o vidro (rc=$rc, on=$on, tb=$tb, v1 red=$v1_on)" "$saida"
fi

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
C8="$T/cosmic8"; mkdir -p "$C8"
cp -a "$CAP"/com.system76.CosmicTheme.* "$C8/"
mapa_novo_em "$C8"
sed -i 's/very_high_2: 0.52615/very_high_2: NaN/' "$C8/com.system76.CosmicTheme.Dark.Builder/v2/alpha_map"
saida="$(aplicar "$C8" dracula-mauve)"; rc=$?
if [ "$rc" = "0" ] \
   && [[ "$saida" == *"Dark: o alpha_map dá ao nível VeryHigh2 o valor NaN, que não é número"* ]] \
   && [[ "$saida" != *"cannot convert"* ]] \
   && [ "$(valor "$C8/com.system76.CosmicTheme.Dark/v2/transparent_background" base)" = "#383A4CAA" ]; then
  ok "um nível NaN: a mesma frase em português, e a Dark fica com o vidro da captura"
else
  falha "o NaN no alpha_map não chegou à tela como os outros valores inválidos (rc=$rc)" "$saida"
fi

C9="$T/casa9/.config/cosmic"
mkdir -p "$C9/com.system76.CosmicPanel.Panel/v1"
cp -a "$CAP"/com.system76.CosmicTheme.* "$C9/"
find "$C9" -name frosted_maximized_apps -delete
python3 - "$C9" <<'PY'
import glob, re, sys
for f in glob.glob(sys.argv[1] + "/com.system76.CosmicTheme.*/v2/background"):
    t = open(f, encoding="utf-8").read()
    open(f, "w", encoding="utf-8").write(re.sub(
        r'base: "#([0-9A-Fa-f]{6})([0-9A-Fa-f]{2})?"', r'base: "#\g<1>33"', t, count=1))
PY
antes9="$(cd "$C9" && find . -type f -exec md5sum {} + | sort)"
saida="$(amb "$C9" dracula env HOME="$T/casa9" MEOW_DRY_RUN=1 VIDRO_AO_MAXIMIZAR=sim bash "$RAIZ/scripts/vidro.sh" 2>&1)"
depois9="$(cd "$C9" && find . -type f -exec md5sum {} + | sort)"
if [ "$antes9" = "$depois9" ] && [[ "$saida" == *"deveria ser"* ]]; then
  ok "no ensaio o remendo da janela só confere: aponta o alpha fora e não escreve"
else
  falha "o ensaio do vidro.sh escreveu no tema, ou calou a divergência da janela" \
    "$(diff <(printf '%s\n' "$antes9") <(printf '%s\n' "$depois9")) $saida"
fi

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

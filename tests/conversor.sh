#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONV="$RAIZ/scripts/converter_icone.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()   { printf 'ok: %s\n' "$1"; }
falha(){ printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas+1)); }
metrica(){ python3 -c "import json,sys;print(json.load(open(sys.argv[1]))[sys.argv[2]])" "$1" "$2"; }

for f in rsvg-convert compare python3; do
  command -v "$f" >/dev/null || { printf 'pulado: falta %s nesta máquina\n' "$f"; exit 0; }
done

ORIGENS=(
  "$RAIZ/packs/meowsystem/icones/apps/cosmic-edit-mocha.svg"
  "/usr/share/icons/Papirus/64x64/apps/org.gimp.GIMP.svg"
)

for origem in "${ORIGENS[@]}"; do
  [ -f "$origem" ] || { printf 'pulado: %s não existe nesta máquina\n' "$origem"; continue; }
  nome="$(basename "$origem")"

  ini=$(date +%s%N)
  python3 "$CONV" "$origem" "$T/c.svg" --json >"$T/c.json" 2>"$T/c.err" \
    || { falha "$nome: o conversor falhou em --curvas ($(cat "$T/c.err"))"; continue; }
  dur=$(( ($(date +%s%N) - ini) / 1000000 ))
  python3 "$CONV" "$origem" "$T/p.svg" --polilinha --json >"$T/p.json" 2>/dev/null \
    || { falha "$nome: o conversor falhou em --polilinha"; continue; }

  grep -q 'C[0-9]' "$T/c.svg"               && ok "$nome: a saída tem curvas" || falha "$nome: nenhum C na saída"
  grep -q 'stroke-width' "$T/c.svg"         && falha "$nome: gravou stroke-width" || ok "$nome: sem stroke-width"
  grep -Eq '#[0-9A-Fa-f]{3,8}\b' "$T/c.svg" && falha "$nome: gravou cor" || ok "$nome: sem cor"
  grep -q 'viewBox="0 0 48 48"' "$T/c.svg"  && ok "$nome: viewBox 48" || falha "$nome: viewBox errado"
  grep -q 'stroke="currentColor"' "$T/c.svg" && ok "$nome: a cor entra por currentColor" || falha "$nome: sem currentColor"
  grep -q 'fill="none"' "$T/c.svg"          && ok "$nome: fill none" || falha "$nome: sem fill=none"
  grep -q '<path ' "$T/c.svg"               && ok "$nome: <path com espaço (o _vestido injeta)" || falha "$nome: <path sem espaço — o _vestido não vai injetar espessura"
  rsvg-convert -w 48 -h 48 "$T/c.svg" -o "$T/c.png" 2>/dev/null && ok "$nome: rasteriza" || falha "$nome: o rsvg recusou a saída"

  caidos=$(metrica "$T/c.json" caidos)
  [ "$caidos" -le 2 ] && ok "$nome: $caidos trecho(s) caíram para polilinha" \
                      || falha "$nome: $caidos trechos caíram — o ajuste não converge"

  pc=$(metrica "$T/c.json" pontos)
  pp=$(metrica "$T/p.json" pontos)
  [ "$pc" -le $(( pp * 4 )) ] && ok "$nome: $pc pontos contra $pp da polilinha (teto 4x)" \
                              || falha "$nome: $pc pontos contra $pp — o ajuste inflou o arquivo"

  [ "$dur" -lt 1000 ] && ok "$nome: ${dur} ms" || falha "$nome: ${dur} ms — passou de 1 s"

  rsvg-convert -w 48 -h 48 -b '#1e1e2e' "$T/c.svg" -o "$T/c48.png" 2>/dev/null
  rsvg-convert -w 48 -h 48 -b '#1e1e2e' "$T/p.svg" -o "$T/p48.png" 2>/dev/null
  dif=$(compare -metric AE -fuzz 8% "$T/c48.png" "$T/p48.png" null: 2>&1 | awk '{print int($1)}')
  [ "${dif:-9999}" -lt 138 ] && ok "$nome: curvas e polilinha diferem em $dif px de 2304" \
                             || falha "$nome: $dif px diferentes — a forma mudou, não só a linha"
done

TERM="$RAIZ/packs/meowsystem/icones/apps/cosmic-term-mocha.svg"
if [ -f "$TERM" ]; then
  python3 "$CONV" "$TERM" "$T/t.svg" --json >"$T/t.json" 2>/dev/null
  cantos=$(metrica "$T/t.json" cantos)
  retas=$(metrica "$T/t.json" retas)
  [ "$cantos" -ge 2 ] && ok "terminal: $cantos cantos — o > mantém o bico" \
                      || falha "terminal: $cantos cantos — o > saiu redondo (alisaram antes de achar o canto?)"
  [ "$retas" -ge 1 ] && ok "terminal: $retas retas — os lados da moldura ficam retos" \
                     || falha "terminal: $retas retas — os lados retos viraram curva"
else
  printf 'pulado: %s não existe\n' "$TERM"
fi

BTOP="/usr/share/icons/Papirus/64x64/apps/btop.svg"
if [ -f "$BTOP" ]; then
  python3 "$CONV" "$BTOP" "$T/b.svg" --json >"$T/b.json" 2>/dev/null
  bcantos=$(metrica "$T/b.json" cantos)
  [ "$bcantos" -ge 8 ] && ok "btop: $bcantos cantos — o B de blocos não arredondou" \
                       || falha "btop: $bcantos cantos — o B de blocos ganhou curva onde é ângulo reto"
else
  printf 'pulado: %s não existe\n' "$BTOP"
fi

GIMP="/usr/share/icons/Papirus/64x64/apps/org.gimp.GIMP.svg"
if [ -f "$GIMP" ]; then
  python3 "$CONV" "$GIMP" "$T/f.svg" --cheia --json >"$T/f.json" 2>/dev/null
  python3 "$CONV" "$GIMP" "$T/s.svg" --json >/dev/null 2>&1
  nf=$(grep -o 'fill="currentColor"' "$T/f.svg" | wc -l)
  ns=$(grep -o 'fill="currentColor"' "$T/s.svg" | wc -l)
  [ "$nf" -ge 1 ] && ok "--cheia: $nf subcaminho(s) cheios" || falha "--cheia: nenhum fill saiu"
  [ "$(metrica "$T/f.json" cheia)" = "True" ] && ok "--cheia: a métrica diz qual classe encheu" \
                                              || falha "--cheia: a métrica não registrou a área cheia"
  [ "$ns" -eq 0 ] && ok "sem --cheia: nenhum fill (o padrão é traço)" \
                  || falha "sem --cheia: saíram $ns fills — preenchimento é a exceção do dialeto"
fi

RET="$RAIZ/packs/meowsystem/icones/apps/org.gimp.GIMP.svg"
if [ -f "$GIMP" ] && [ -f "$RET" ]; then
  python3 "$CONV" "$GIMP" "$T/poli.svg" --polilinha >/dev/null 2>&1
  if python3 - "$T/poli.svg" "$RET" <<'PY'
import re, sys
a = re.findall(r'<path d="([^"]*)"', open(sys.argv[1], encoding='utf-8').read())
b = re.findall(r'<path d="([^"]*)"', open(sys.argv[2], encoding='utf-8').read())
sys.exit(0 if a and len(b) > len(a) and a == b[:len(a)] else 1)
PY
  then ok "--polilinha: os 6 subcaminhos do retoque do GIMP batem byte a byte"
  else falha "--polilinha: o retoque do GIMP não bate mais — a prova da boca do Wilber caiu"
  fi
fi

for origem in "${ORIGENS[@]}"; do
  [ -f "$origem" ] || continue
  nome="$(basename "$origem")"
  python3 "$CONV" "$origem" "$T/z0.svg" --json >"$T/z0.json" 2>/dev/null
  python3 "$CONV" "$origem" "$T/z1.svg" --peso-fronteira 0 >/dev/null 2>&1
  cmp -s "$T/z0.svg" "$T/z1.svg" \
    && ok "$nome: --peso-fronteira 0 é o padrão byte a byte" \
    || falha "$nome: --peso-fronteira 0 mudou a saída padrão"
  [ "$(metrica "$T/z0.json" peso)" = "None" ] && ok "$nome: a métrica diz que a chave não foi pedida" \
    || falha "$nome: a métrica 'peso' não é null no padrão"
  [ "$(metrica "$T/z0.json" fundidas)" = "0" ] && ok "$nome: nenhuma fronteira fundida no padrão" \
    || falha "$nome: o padrão fundiu fronteira — a chave está ligada sozinha"
done

TRAVA=(
  "/usr/share/icons/Papirus/64x64/apps/org.gnome.Calculator.svg"
  "/usr/share/icons/Papirus/64x64/apps/org.videolan.VLC.svg"
  "$RAIZ/packs/meowsystem/icones/apps/cosmic-edit-mocha.svg"
  "$RAIZ/packs/meowsystem/icones/apps/cosmic-term-mocha.svg"
)
for origem in "${TRAVA[@]}"; do
  [ -f "$origem" ] || { printf 'pulado: %s não existe\n' "$origem"; continue; }
  nome="$(basename "$origem")"
  python3 "$CONV" "$origem" "$T/v0.svg" >/dev/null 2>&1
  python3 "$CONV" "$origem" "$T/v1.svg" --peso-fronteira >/dev/null 2>&1
  cmp -s "$T/v0.svg" "$T/v1.svg" \
    && ok "trava: $nome não muda com --peso-fronteira" \
    || falha "trava: $nome MUDOU com --peso-fronteira — o limiar subiu e alcançou quem já saía bem"
done

BRAVE="/usr/share/icons/Papirus/64x64/apps/com.brave.Browser.svg"
if [ -f "$BRAVE" ]; then
  python3 "$CONV" "$BRAVE" "$T/w0.svg" --json >"$T/w0.json" 2>/dev/null
  python3 "$CONV" "$BRAVE" "$T/w1.svg" --peso-fronteira --json >"$T/w1.json" 2>/dev/null
  a=$(metrica "$T/w0.json" linhas); b=$(metrica "$T/w1.json" linhas)
  f=$(metrica "$T/w1.json" fundidas)
  [ "$f" -ge 1 ] && ok "brave: $f fronteira(s) fraca(s) fundida(s)" \
                 || falha "brave: nenhuma fronteira fundida — a chave não pegou o caso que a nomeou"
  [ "$b" -lt "$a" ] && ok "brave: $a traços -> $b com peso de fronteira" \
                    || falha "brave: $a -> $b — o emaranhado não encolheu"
  grep -q 'stroke-width' "$T/w1.svg" && falha "brave/peso: gravou stroke-width" \
                                     || ok "brave/peso: sem stroke-width"
  grep -q 'viewBox="0 0 48 48"' "$T/w1.svg" && ok "brave/peso: viewBox 48" \
                                            || falha "brave/peso: viewBox errado"
  grep -q '<path ' "$T/w1.svg" && ok "brave/peso: <path com espaço (o _vestido injeta)" \
                               || falha "brave/peso: <path sem espaço"
fi

cat >"$T/borda.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><rect width="48" height="48" rx="10" fill="#e8763a"/></svg>
SVG
python3 "$CONV" "$T/borda.svg" "$T/borda.out.svg" --json >"$T/borda.json" 2>/dev/null
if python3 - "$T/borda.out.svg" <<'PY'
import re, sys
ds = re.findall(r'<path[^>]* d="([^"]*)"', open(sys.argv[1], encoding='utf-8').read())
if len(ds) != 1 or not ds[0].rstrip().endswith("Z") or ds[0].count("M") != 1:
    sys.exit(1)
n = [float(v) for v in re.findall(r'-?\d+\.\d+', ds[0])]
xs, ys = n[0::2], n[1::2]
sys.exit(0 if min(xs) < 0.5 and max(xs) > 47.5 and min(ys) < 0.5 and max(ys) > 47.5 else 1)
PY
then ok "moldura: o quadrado arredondado que encosta nas quatro bordas sai como 1 contorno fechado"
else falha "moldura: o quadrado arredondado que encosta nas bordas não fechou em 1 contorno"
fi
[ "$(metrica "$T/borda.json" retas)" -ge 4 ] && ok "moldura: os quatro lados ficam retos" \
  || falha "moldura: os lados da moldura não saíram retos"

convert -size 256x256 xc:'#e8763a' "$T/opaco.png" 2>/dev/null
python3 "$CONV" "$T/opaco.png" "$T/opaco.svg" --json >"$T/opaco.json" 2>/dev/null
[ "$(metrica "$T/opaco.json" linhas)" = "1" ] && grep -q 'Z"/>' "$T/opaco.svg" \
  && ok "moldura: o PNG opaco de ponta a ponta sai com 1 contorno fechado" \
  || falha "moldura: o PNG opaco de ponta a ponta saiu vazio ou aberto"

exit "$falhas"

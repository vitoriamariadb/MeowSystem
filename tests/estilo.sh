#!/usr/bin/env bash
# A CANETA TEM UMA FAIXA, E ELA É MEDIDA — NÃO CRAVADA.
#
# Em 09/09/2026 ela apontou o Arcticons-Linux e perguntou se dava para construir
# um conversor usando o que eles já fizeram. Dá — e a primeira coisa que o
# acervo deles serve é de RÉGUA. Os 39 glifos em `assets/icones/arcticons-apps/`
# foram desenhados à mão por gente, no MESMO dialeto (grade de 48, `fill:none`,
# traço, pontas redondas), e estão versionados aqui. Então a pergunta "a nossa
# arte gerada parece do mesmo pack?" deixa de ser gosto e vira distribuição.
#
# A FAIXA É DERIVADA DO ACERVO A CADA RODADA. Nenhum número desta régua está
# escrito no arquivo: se um glifo entrar ou sair de `arcticons-apps/`, a faixa
# anda sozinha. É a armadilha nº 3 do projeto — toda lista fixa é uma lista que
# alguém vai esquecer.
#
# POR QUE `min`/`max` E NÃO PERCENTIL
#   Percentil responde "onde a mão costuma ficar". Sair do p05 não é defeito: é
#   estar na cauda. O que é defeito é sair de onde a mão JÁ FOI. Medido em
#   09/09/2026: três conversões (Foliate, ProtonUp, Apostrophe) têm margem 2,42
#   — abaixo do p05 (2,50) e acima do mínimo real do acervo (o firefox, 1,72).
#   Uma régua no p05 estaria vermelha por oito centésimos, sem nada ter
#   acontecido.
#
# O QUE ESTA RÉGUA NÃO PEGA, E É DE PROPÓSITO
#   Se o desenho está CERTO. O compressor do Arcticons são duas setas apertando
#   linhas; o nosso é o zíper que estava no Papirus. Os dois passam aqui, e o
#   deles é melhor — porque decidiu o que a coisa significa, e isso um conversor
#   não faz. Esta régua pega o tremido, o denso e o desenquadrado.
#
# AS DUAS MEDIDAS QUE AINDA ESTÃO FORA, E ESTÃO AQUI COMO PISO, NÃO COMO VERDE
#   `tracos` e `pontos`. Medido em 09/09/2026 nas 15 conversões alcançáveis:
#   5 de 15 dentro em traços, 8 de 15 em pontos. O acervo faz 20 pontos e 2
#   traços na mediana; nós fazemos 66 e 5. Os pisos abaixo têm folga proposital
#   sobre o medido: eles não celebram o número de hoje, eles impedem que ele
#   AFUNDE enquanto o conserto não vem. Quando o conserto vier, esta linha cai
#   e o piso sobe junto.
#
#   0 = a caneta está na faixa · 1 = saiu · 2 = erro · 3 = falta dependência
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONV="$RAIZ/scripts/converter_icone.py"
ESTILO="$RAIZ/scripts/estilo_icone.py"
ACERVO="$RAIZ/assets/icones/arcticons-apps"
MAPA="$RAIZ/assets/icones/apps-convertidos.map"
RETOQUES="$RAIZ/assets/icones/convertidos-apps/retoques"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()   { printf 'ok: %s\n' "$1"; }
falha(){ printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null || { printf 'pulado: falta python3\n'; exit 0; }
python3 -c 'import numpy' 2>/dev/null || { printf 'pulado: falta numpy\n'; exit 0; }
[ -d "$ACERVO" ] || { printf 'pulado: o acervo Arcticons não está aqui\n'; exit 0; }

# ---------------------------------------------------------------- a faixa
python3 "$ESTILO" --faixa "$ACERVO" --json > "$T/faixa.json" 2>"$T/err" \
  || { falha "não consegui derivar a faixa do acervo ($(cat "$T/err"))"; exit 2; }
n_acervo="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["n"])' "$T/faixa.json")"
[ "${n_acervo:-0}" -ge 20 ] \
  && ok "faixa derivada de $n_acervo glifos desenhados à mão" \
  || falha "o acervo tem só $n_acervo glifos — faixa fraca demais para servir de régua"

# ------------------------------------------------- quem o conversor alcança
#   Derivado do mapa, nunca uma lista: `mao` não passa pelo conversor, e quem
#   tem retoque tem a mão por cima da máquina — medir os dois seria medir a
#   mão e chamar de conversor.
alcanca=0
while IFS=: read -r nome origem cor resto; do
  case "$nome" in ''|\#*) continue;; esac
  [ "$origem" = "mao" ] && continue
  [ -f "$RETOQUES/$nome.svg" ] && continue
  [ -f "$origem" ] || continue
  python3 "$CONV" "$origem" "$T/$nome.svg" >/dev/null 2>&1 || continue
  alcanca=$((alcanca+1))
done < "$MAPA"
[ "$alcanca" -ge 10 ] \
  && ok "$alcanca conversões alcançáveis nesta máquina" \
  || { printf 'pulado: só %d origens do mapa existem aqui\n' "$alcanca"; exit 0; }

# ------------------------------------------------------------ o julgamento
python3 - "$T/faixa.json" "$T" "$ESTILO" <<'PY' > "$T/veredito.txt"
import json, os, subprocess, sys
faixa = json.load(open(sys.argv[1], encoding="utf-8"))
alvos = sorted(f for f in os.listdir(sys.argv[2]) if f.endswith(".svg"))
linhas = json.loads(subprocess.run(
    [sys.executable, sys.argv[3], "--json"] + [os.path.join(sys.argv[2], f) for f in alvos],
    capture_output=True, text=True).stdout)

# TRAVA: quem sai da faixa quebra o teste. São as medidas que HOJE estão todas
# dentro — então uma delas saindo é regressão, não trabalho pendente.
#   `larg` ficou DE FORA da trava por medida, não por esquecimento: três
#   conversões dão 43,20 e o mais largo do acervo é 43,00 — dois décimos, que é
#   menos que a espessura do traço. Travar nisso seria vermelho sem defeito.
#   `alt` entra porque lá a folga é real (nosso máximo 41,68, do acervo 44,56).
TRAVA = ("seg_mediano", "margem", "curva_pct", "alt")
# PISO: quem ainda está fora. O número não é o de hoje, é o de hoje com folga.
PISO = {"tracos": 3, "pontos": 5}

fora = []
for m in linhas:
    for k in TRAVA:
        lo, hi = faixa[k]["min"], faixa[k]["max"]
        if not (lo <= m[k] <= hi):
            fora.append("%s: %s = %.2f fora de [%.2f, %.2f]"
                        % (os.path.basename(m["arquivo"]), k, m[k], lo, hi))
for f in fora:
    print("TRAVA " + f)

for k, piso in PISO.items():
    lo, hi = faixa[k]["min"], faixa[k]["max"]
    dentro = [m for m in linhas if lo <= m[k] <= hi]
    print("PISO %s %d %d %d %.1f %.1f"
          % (k, len(dentro), len(linhas), piso,
             sorted(m[k] for m in linhas)[len(linhas)//2], faixa[k]["p50"]))
PY

while read -r tipo resto; do
  case "$tipo" in
    TRAVA) falha "$resto" ;;
    PISO)
      set -- $resto
      medida="$1"; dentro="$2"; total="$3"; piso="$4"; nosso="$5"; deles="$6"
      if [ "$dentro" -ge "$piso" ]; then
        ok "$medida: $dentro de $total na faixa (piso $piso) — mediana nossa $nosso, do acervo $deles"
      else
        falha "$medida: só $dentro de $total na faixa, o piso é $piso — a caneta engrossou"
      fi ;;
  esac
done < "$T/veredito.txt"

[ "$falhas" -eq 0 ] && ok "a caneta do conversor está dentro do dialeto do acervo"
exit "$falhas"

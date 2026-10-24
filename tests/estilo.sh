#!/usr/bin/env bash
# Dá — e a primeira coisa que o acervo deles serve é de RÉGUA. Os 39 glifos em
# `packs/meowsystem/icones/apps/` foram desenhados à mão por gente, no
# MESMO dialeto (grade de 48, `fill:none`, traço, pontas redondas), e estão
# versionados aqui.
#
# Nenhum número desta régua está escrito no arquivo: se um glifo entrar ou sair
# de `arcticons-apps/`, a faixa anda sozinha.
#
# Percentil responde "onde a mão costuma ficar".
#
# Se o desenho está CERTO.
#
#   0 = a caneta está na faixa · 1 = saiu · 2 = erro · 3 = falta dependência
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONV="$RAIZ/scripts/converter_icone.py"
ESTILO="$RAIZ/scripts/estilo_icone.py"
ACERVO="$RAIZ/packs/meowsystem/icones/arcticons.lista"   # P96: as pastas são planas; a lista diz o que é Arcticons
MAPA="$RAIZ/packs/meowsystem/icones/apps-convertidos.map"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()   { printf 'ok: %s\n' "$1"; }
falha(){ printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas+1)); }

# ------------------------------------------------- a porta única da paleta
# O `lib/comum.sh` promete, no cabeçalho do `meow_paleta`, que "quem esquecer de
# usá-la aparece no grep de tests/estilo.sh". A promessa passa a ser verdade
# aqui.
#
# ELE VEM ANTES DAS GUARDAS DE DEPENDÊNCIA, E ISSO É DE PROPÓSITO: as três
# linhas abaixo saem com `pulado` em máquina sem numpy ou sem o acervo, e uma
# cobrança que some justamente onde a máquina é mais pobre — o CI — não é
# cobrança.
fora_da_porta="$(grep -rnE --include='*.sh' \
                   '(\$\{?[A-Za-z_][A-Za-z_0-9]*\}?/assets/paleta|assets/paleta/[A-Za-z$_{])' "$RAIZ" \
                 | grep -v 'lib/comum\.sh:' \
                 | grep -vE ':[0-9]+:[^#]*#.*assets/paleta')"
if [ -n "$fora_da_porta" ]; then
  falha "script de shell resolvendo a paleta sozinho, em vez de chamar meow_paleta:"
  printf '%s\n' "$fora_da_porta" | sed "s#^$RAIZ/#  #" >&2
  exit 1
fi
ok "nenhum .sh crava o caminho da paleta — todos passam pelo meow_paleta"

# ----------------------------------------------- a raiz única do COSMIC
#
# Até este dia havia DOIS jeitos de dizer onde mora a configuração do COSMIC, e
# os dois estavam vivos: 11 linhas de shell liam `${MEOW_COSMIC_DIR:-$HOME/...}`
# e 24 cravavam o caminho.
#
# Reescrever a prosa para agradar um grep apagaria o porquê e não consertaria
# uma linha de código — isso continua valendo.
raiz_cravada="$(grep -rn '\$HOME/\.config/cosmic' \
                  "$RAIZ/scripts" "$RAIZ/lib" "$RAIZ/bin/meow" "$RAIZ/install.sh" \
                | grep -vE ':[0-9]+:[[:space:]]*#' \
                | grep -v 'MEOW_COSMIC_DIR')"
if [ -n "$raiz_cravada" ]; then
  falha "raiz do COSMIC cravada em código, em vez de chamar meow_cosmic_dir:"
  printf '%s\n' "$raiz_cravada" | sed "s#^$RAIZ/#  #" >&2
  exit 1
fi
ok "nenhum código crava a raiz do COSMIC — todos passam pelo meow_cosmic_dir"

# ----------------------------------------------- o Python isolado
# Um `python3 -` lê o programa do stdin e põe o diretório CORRENTE no começo do
# `sys.path`: quem roda um módulo de tema de app de dentro de uma pasta com um
# `json.py` plantado (um download, um pack de terceiro extraído) executa esse
# arquivo no `import json`.
sem_isolar="$(cd "$RAIZ" && grep -rnE --exclude='*.md' 'python3( +-[A-Za-z]+)* +-( |$)' \
                scripts lib bin install.sh assets app packs \
              | grep -vE ':[0-9]+:[[:space:]]*#' \
              | grep -vE 'python3( +-[A-Za-z]+)* +-I')"
if [ -n "$sem_isolar" ]; then
  falha "python3 - sem -I em código de produto (o diretório corrente entra no sys.path):"
  printf '%s\n' "$sem_isolar" | sed 's/^/  /' >&2
  exit 1
fi
ok "todo python3 - do código de produto roda isolado (-I)"

# ----------------------------------------------- o esquema do COSMIC
# O `v1` escrito à mão num caminho de namespace do COSMIC grava (ou lê) numa
# pasta que o COSMIC instalado pode não usar mais: o 1.10 traz `v1 v2` no tema,
# e o `janelas.sh` mostrava o `gaps` velho do `v1`.
v1_cravado="$(cd "$RAIZ" && grep -rnE '\.[A-Za-z][A-Za-z0-9_]*/v1(/|"|$)' \
                scripts lib bin/meow install.sh --include='*.sh' --include='meow' \
              | grep -vE ':[0-9]+:[[:space:]]*#' | grep -v 'a v1 legada')"
if [ -n "$v1_cravado" ]; then
  falha "caminho de namespace do COSMIC com v1 cravado (use meow_cosmic_v):"
  printf '%s\n' "$v1_cravado" | sed 's/^/  /' >&2
  exit 1
fi
ok "nenhum caminho de namespace do COSMIC crava o v1 — todos passam pelo meow_cosmic_v"

command -v python3 >/dev/null || { printf 'pulado: falta python3\n'; exit 0; }
python3 -c 'import numpy' 2>/dev/null || { printf 'pulado: falta numpy\n'; exit 0; }
[ -f "$ACERVO" ] || { printf 'pulado: o acervo Arcticons não está aqui\n'; exit 0; }

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
  case " $resto " in *" retoque "*) continue ;; esac   # P96: o retoque é dito no mapa
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

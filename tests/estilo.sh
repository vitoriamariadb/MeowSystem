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

# ------------------------------------------------- a porta única da paleta
# O `lib/comum.sh` promete, no cabeçalho do `meow_paleta`, que "quem esquecer
# de usá-la aparece no grep de tests/estilo.sh". Até 21/09/2026 esse grep NÃO
# EXISTIA: o comentário descrevia uma cobrança imaginária, e um arquivo novo
# podia cravar o caminho da paleta sem nada acusar. A promessa passa a ser
# verdade aqui.
#
# ELE VEM ANTES DAS GUARDAS DE DEPENDÊNCIA, E ISSO É DE PROPÓSITO: as três
# linhas abaixo saem com `pulado` em máquina sem numpy ou sem o acervo, e uma
# cobrança que some justamente onde a máquina é mais pobre — o CI — não é
# cobrança. Esta não depende de nada além do grep.
#
# O RECORTE É `*.sh`, e também é medido: o cabeçalho do `meow_paleta` nomeia os
# cinco consumidores em Python que NÃO podem chamá-lo (o `sys.path` entre
# `scripts/` e `app/` não existe neste projeto) e manda que eles repitam as três
# linhas equivalentes. Cobrar Python aqui seria cobrar o que o contrato isenta.
# O `lib/comum.sh` sai porque é a própria porta.
#
# O PADRÃO TINHA UM DESVIO DE UM PASSO, E O DESVIO ERA O CAMINHO NATURAL
#   A primeira versão exigia o `/` colado num nome — `assets/paleta/[A-Za-z$_{]`
#   —, e por isso pegava quem COPIASSE o modelo do `lib/comum.sh:149` e deixava
#   passar quem o ADAPTASSE. Medido em 21/09/2026 com uma isca de quatro linhas:
#       PAL="$MEOW_RAIZ/assets/paleta"      -> o padrão antigo NÃO via
#       cor=$(... < "$PAL/catppuccin.json") -> e a paleta estava cravada assim mesmo
#   Cravar o diretório e juntar o nome na linha seguinte é a forma mais natural
#   de fazê-lo, e era justamente a que escapava. Agora o padrão tem duas bocas:
#   o caminho completo de sempre, e `$VAR/assets/paleta` — que é como o diretório
#   aparece quando alguém o crava sozinho.
#
# E O FILTRO DE COMENTÁRIO SÓ TIRAVA A LINHA QUE COMEÇA COM `#`
#   Na mesma isca, `eco=1  # ... assets/paleta/catppuccin.json` virava FALSO
#   POSITIVO: prosa no fim da linha pintava o CI de vermelho. O filtro passa a
#   tirar a citação que tem um `#` ANTES dela, onde quer que ele esteja — é a
#   mesma regra do `tests/orfaos.sh`: conta chamada, nunca menção. O preço está
#   dito: um `${#lista[@]}` na mesma linha de uma citação de paleta esconderia a
#   citação. Nenhum dos 83 scripts faz isso hoje, e a troca vale — o risco que
#   sobra é de um caso rebuscado, e o que saiu era o caso comum.
#
#   Ela também dispensa uma isenção que não existia: a linha 'assets/paleta/…'
#   deste próprio arquivo, e a frase "regenerados a partir de assets/paleta/" do
#   install.sh:537, não casam com nenhuma das duas bocas — medido.
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
# A MESMA PROMESSA, PARA A OUTRA PORTA ÚNICA [21/09/2026]
#   Até este dia havia DOIS jeitos de dizer onde mora a configuração do COSMIC,
#   e os dois estavam vivos: 11 linhas de shell liam
#   `${MEOW_COSMIC_DIR:-$HOME/...}` e 24 cravavam o caminho. O `lib/preflight.sh`
#   — o guardião, o que roda antes da primeira escrita — estava do lado que
#   cravava. A P19 pôs as 24 para chamar o `meow_cosmic_dir` do `lib/comum.sh`;
#   esta régua é o que impede a 25ª. Sem ela o conserto dura até o próximo
#   arquivo novo, que é o prazo de validade de todo conserto sem cobrança.
#
# A ISENÇÃO É CITAR `MEOW_COSMIC_DIR` NA PRÓPRIA LINHA, e ela tem exatamente
# dois moradores legítimos: o corpo do verbo, no `lib/comum.sh`, e o
# `scripts/coleta-meowsystem.sh`, que é feito para viajar sozinho e não carrega
# o comum.sh de propósito. Dizer o nome da variável é dizer que a raiz é
# configurável — que é a única coisa cobrada aqui.
#
# COMENTÁRIO CONTINUA LIVRE, E O FILTRO É "A LINHA COMEÇA COM #"
#   Reescrever a prosa para agradar um grep apagaria o porquê e não consertaria
#   uma linha de código — isso continua valendo. Mas o filtro que a isenta é o
#   ESTRITO, e os números que a primeira versão desta régua usou para afrouxar
#   não existem.
#
#   MEDIDO EM 21/09/2026, nestes quatro caminhos e para o padrão DESTA régua
#   (`$HOME/.config/cosmic`): ZERO citações em comentário — nem de linha
#   inteira, nem no fim de linha de código. Quem cita a raiz em prosa escreve
#   `~/.config/cosmic`, e o `~` não casa com `$HOME`: são 30 linhas, todas de
#   comentário inteiro, e nenhuma chega a este grep. As 35 que o padrão casava
#   antes do commit eram TODAS código — 24 cravadas e 11 honrando a variável.
#
#   E O AFROUXAMENTO TINHA PREÇO. O filtro largo era
#   `:[0-9]+:[^#]*#.*\$HOME/\.config/cosmic` — "ignore a citação que tenha um
#   `#` em qualquer lugar antes dela" — e num projeto Catppuccin um `#` antes do
#   caminho é uma cor hexadecimal de distância: `printf %s "#1e1e2e" >
#   "$HOME/.config/cosmic/.../bg"` passava VERDE pela régua que existe
#   justamente para impedir a 25ª. Reproduzido em 21/09/2026, numa cópia da
#   árvore. Com o filtro estrito a árvore limpa devolve zero: o rigor não custa
#   um falso positivo sequer. É também o filtro do `tests/orfaos.sh:186`
#   (`:[0-9]+:[[:space:]]*(#|//|\*)`), que conta chamada e nunca menção. A
#   régua da paleta, logo acima, ficou com a forma larga; é de fora desta
#   sprint e fica anotado, não consertado aqui.
#
# O RECORTE É O DA CONFERÊNCIA DA P19: `scripts/`, `lib/`, `bin/meow` e
# `install.sh`. O `tests/` fica fora porque é ele quem desvia a raiz, e o
# `app/servidor.py` porque Python não alcança o `lib/comum.sh` neste projeto —
# a mesma isenção que o cabeçalho do `meow_paleta` já concede.
#
# `assets/` TAMBÉM FICA FORA, E É LACUNA CONHECIDA — NÃO COBERTURA
#   `assets/temas-de-apps/toolkits-gtk-qt/manifesto.sh:215` crava a raiz no
#   `MEOW_TK_TK_DIR` e ALCANÇA o verbo: o `scripts/aplicar_apps.sh` carrega o
#   `lib/comum.sh` (linha 23) e depois faz `. "$mod"` do manifesto num subshell
#   (linha 55). É a ÚNICA linha de shell do repositório que o recorte deixa
#   passar — medido em 21/09/2026. Fica para a P18, que é a sprint dona daquela
#   árvore; alargar o recorte aqui deixaria esta régua vermelha antes de a P18
#   passar, e régua que nasce vermelha ninguém acredita.
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

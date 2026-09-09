#!/usr/bin/env bash
# A ESCADA NÃO VOLTA SEM NINGUÉM VER.
#
# Em 09/09/2026 ela olhou a lupa da oficina e chamou o traço de "pixelado". A
# causa era o conversor emitir só polilinha: marching squares em lados de pixel
# numa grade de 256, aparada por Douglas–Peucker. O DP escolhe QUAIS degraus
# ficam; não desfaz nenhum. Este teste afirma, em três origens fixas do
# repositório e do sistema, que a saída padrão é curva, que os cantos
# sobrevivem, que as retas continuam retas, que a FORMA não mudou e que o
# dialeto do acervo está intacto.
#
# AS TRÊS ASSERÇÕES QUE VALEM MAIS QUE AS OUTRAS, porque cada uma prende um
# defeito que ACONTECEU durante a passagem, não um que se imaginou:
#
#   1. `cantos ≥ 2` no `>_` do terminal. O primeiro desenho da passagem alisava
#      a cadeia ANTES de procurar canto — e a média móvel come o canto que se ia
#      procurar. Medido: na cadeia crua o `>` tem quatro vértices de 90,0°;
#      depois de alisar, o maior é 53,7° e nenhum passa do limiar de 60°. O
#      terminal saía com o `>` sem bico. A ordem certa é cantos → partir →
#      alisar, e é esta linha que a segura.
#
#   2. `retas ≥ 1` no terminal. Ajustar Bézier em TUDO ondula os quatro lados
#      retos da moldura, porque a cúbica compra a folga da tolerância onde ela é
#      grátis para o erro e cara para o olho. Reta continua reta.
#
#   3. a mesma forma. Só a linha que desenha podia mudar; a quantização, o
#      filtro de moda e o colapso de fitas não foram tocados de propósito,
#      porque a forma foi aprovada na folha de 11/08/2026.
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

# As três origens são de procedências diferentes DE PROPÓSITO: o que decide a
# conversão não é PNG contra SVG, é o desenho ser geométrico ou orgânico.
ORIGENS=(
  "$RAIZ/assets/icones/autorais/cosmic-edit-mocha.svg"          # autoral, já tem contorno (a fita colapsa)
  "/usr/share/icons/Papirus/64x64/apps/org.gimp.GIMP.svg"       # Papirus, orgânico, com gradiente e sombra
  "$RAIZ/assets/icones/catppuccin-apps/macchiato/spotify.png"   # PNG chapado do acervo Catppuccin
)
# O acervo Catppuccin tem `latte` e `macchiato`, NÃO tem `mocha`: o tema mocha
# dela é vestido com os PNG do macchiato, e está escrito assim no
# `folha_icones.py`. Apontar para `mocha/` daria um "pulado" silencioso.

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
  # O `_vestido()` do icones_apps_arcticons.sh injeta a espessura procurando
  # `<path ` COM ESPAÇO. Sem o espaço, o acervo convertido sai fino no meio dos
  # Arcticons e ninguém descobre por que.
  grep -q '<path ' "$T/c.svg"               && ok "$nome: <path com espaço (o _vestido injeta)" || falha "$nome: <path sem espaço — o _vestido não vai injetar espessura"
  rsvg-convert -w 48 -h 48 "$T/c.svg" -o "$T/c.png" 2>/dev/null && ok "$nome: rasteriza" || falha "$nome: o rsvg recusou a saída"

  caidos=$(metrica "$T/c.json" caidos)
  [ "$caidos" -le 2 ] && ok "$nome: $caidos trecho(s) caíram para polilinha" \
                      || falha "$nome: $caidos trechos caíram — o ajuste não converge"

  # O TETO DE PONTOS ANDA PARA O LADO CONTRÁRIO DO QUE A SPRINT SUPUNHA, e o
  # número é medido. A sprint pedia "≤ 40 % dos pontos da polilinha", supondo
  # que curva economiza. Ela NÃO economiza: cada cúbica escreve três pares de
  # coordenadas e cada vértice de polilinha escreve um. Medido em 09/09/2026 nas
  # 29 origens do mapa e dos recusados, a razão vai de 1,46x (Calculadora) a
  # 3,07x (btop) — nunca abaixo de 1. Curva aqui é MAIS bytes e MENOS escada, e
  # essa é a troca que a Sprint Q comprou.
  #   O que a régua ainda tem de prender é a EXPLOSÃO: se alguém apertar a
  # tolerância ou o ajuste degenerar numa cúbica por par de pontos, o arquivo
  # inflaria sem nada ganhar. 4x é o pior medido (3,07x) com folga.
  pc=$(metrica "$T/c.json" pontos)
  pp=$(metrica "$T/p.json" pontos)
  [ "$pc" -le $(( pp * 4 )) ] && ok "$nome: $pc pontos contra $pp da polilinha (teto 4x)" \
                              || falha "$nome: $pc pontos contra $pp — o ajuste inflou o arquivo"

  [ "$dur" -lt 1000 ] && ok "$nome: ${dur} ms" || falha "$nome: ${dur} ms — passou de 1 s"

  # A MESMA FORMA: as duas saídas, a 48 px, diferem em menos de 138 px de 2304.
  #   O `-b` NÃO É ENFEITE, e sem ele esta linha não testa nada. Em PNG com
  #   alfa o `compare -fuzz` acha zero diferença até entre ícones DIFERENTES —
  #   medido: btop contra Spotify deu 0 com fundo transparente e 515 com fundo
  #   opaco. Rasterizar sobre o mocha é o que faz a régua existir.
  rsvg-convert -w 48 -h 48 -b '#1e1e2e' "$T/c.svg" -o "$T/c48.png" 2>/dev/null
  rsvg-convert -w 48 -h 48 -b '#1e1e2e' "$T/p.svg" -o "$T/p48.png" 2>/dev/null
  dif=$(compare -metric AE -fuzz 8% "$T/c48.png" "$T/p48.png" null: 2>&1 | awk '{print int($1)}')
  [ "${dif:-9999}" -lt 138 ] && ok "$nome: curvas e polilinha diferem em $dif px de 2304" \
                             || falha "$nome: $dif px diferentes — a forma mudou, não só a linha"
done

# --------------------------------------------------------------------------
# A RÉGUA DOS DOIS NÚMEROS — o `>_` do terminal e o `B` do btop
# --------------------------------------------------------------------------
TERM="$RAIZ/assets/icones/autorais/cosmic-term-mocha.svg"
if [ -f "$TERM" ]; then
  python3 "$CONV" "$TERM" "$T/t.svg" --json >"$T/t.json" 2>/dev/null
  cantos=$(metrica "$T/t.json" cantos)
  retas=$(metrica "$T/t.json" retas)
  # O `>` tem quatro vértices de 90° na cadeia crua e o `_` tem as duas pontas
  # retas. Se isto cair para 0, alguém voltou a alisar antes de procurar canto.
  [ "$cantos" -ge 2 ] && ok "terminal: $cantos cantos — o > mantém o bico" \
                      || falha "terminal: $cantos cantos — o > saiu redondo (alisaram antes de achar o canto?)"
  # A moldura arredondada tem quatro lados retos. Zero retas = os lados viraram
  # curva e vão ondular na lupa de 200 px.
  [ "$retas" -ge 1 ] && ok "terminal: $retas retas — os lados da moldura ficam retos" \
                     || falha "terminal: $retas retas — os lados retos viraram curva"
else
  printf 'pulado: %s não existe\n' "$TERM"
fi

BTOP="/usr/share/icons/Papirus/64x64/apps/btop.svg"
if [ -f "$BTOP" ]; then
  python3 "$CONV" "$BTOP" "$T/b.svg" --json >"$T/b.json" 2>/dev/null
  bcantos=$(metrica "$T/b.json" cantos)
  # O `B` DO PAPIRUS NÃO TEM BARRIGA REDONDA, E A SPRINT SUPUNHA QUE TINHA.
  #   Olhado a 400 px em 09/09/2026: o btop do Papirus é um "B" de blocos, arte
  #   de pixel — retângulos e ângulos retos, nenhuma curva. Então a asserção
  #   certa é o CONTRÁRIO da que a sprint escreveu ("cantos entre 2 e 4"): o B
  #   tem de sair com MUITO canto, e arredondá-lo é que seria o defeito. Medido:
  #   26 cantos. O piso fica em 8, longe do medido e longe de zero.
  [ "$bcantos" -ge 8 ] && ok "btop: $bcantos cantos — o B de blocos não arredondou" \
                       || falha "btop: $bcantos cantos — o B de blocos ganhou curva onde é ângulo reto"
else
  printf 'pulado: %s não existe\n' "$BTOP"
fi

# --------------------------------------------------------------------------
# `--cheia` — a variação, e ela só aparece quando é pedida
# --------------------------------------------------------------------------
GIMP="/usr/share/icons/Papirus/64x64/apps/org.gimp.GIMP.svg"
if [ -f "$GIMP" ]; then
  python3 "$CONV" "$GIMP" "$T/f.svg" --cheia --json >"$T/f.json" 2>/dev/null
  python3 "$CONV" "$GIMP" "$T/s.svg" --json >/dev/null 2>&1
  nf=$(grep -o 'fill="currentColor"' "$T/f.svg" | wc -l)
  ns=$(grep -o 'fill="currentColor"' "$T/s.svg" | wc -l)
  # A CONTA É DE CLASSE, NÃO DE `<path>`, e a sprint pedia "no máximo um fill".
  #   Errado por medida: a classe escolhida pode ter vários pedaços soltos — no
  #   Wilber são os dois olhos, e cada pedaço é um subcaminho. Três `<path>`
  #   cheios é a resposta certa para UMA classe cheia. Quem responde "uma
  #   classe" é a métrica `cheia`, que é booleana por construção.
  [ "$nf" -ge 1 ] && ok "--cheia: $nf subcaminho(s) cheios" || falha "--cheia: nenhum fill saiu"
  [ "$(metrica "$T/f.json" cheia)" = "True" ] && ok "--cheia: a métrica diz qual classe encheu" \
                                              || falha "--cheia: a métrica não registrou a área cheia"
  [ "$ns" -eq 0 ] && ok "sem --cheia: nenhum fill (o padrão é traço)" \
                  || falha "sem --cheia: saíram $ns fills — preenchimento é a exceção do dialeto"
fi

# --------------------------------------------------------------------------
# `--polilinha` É CONTRATO, NÃO CORTESIA
#   `retoques/org.gimp.GIMP.svg` é uma conversão com UMA curva desenhada à mão
#   (a boca do Wilber). A prova de qual parte é a mão é que os outros seis
#   subcaminhos batem BYTE A BYTE com `--polilinha`. Se esta asserção cair, o
#   LEIA-ME daquele diretório passa a mentir e ninguém consegue mais separar o
#   que a máquina fez do que a pessoa decidiu.
# --------------------------------------------------------------------------
RET="$RAIZ/assets/icones/convertidos-apps/retoques/org.gimp.GIMP.svg"
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

# --------------------------------------------------------------------------
# `--peso-fronteira` — a chave da Sprint T, e a TRAVA que ela tem de respeitar
#
# A queixa dela, 09/09/2026: *"sinto que não tá fidedigno"*. A medição da Sprint
# T derrubou a explicação que o cabeçalho do conversor dava ("geométrico sai,
# orgânico não") e pôs outra no lugar: o que decide é quantas fronteiras de cor
# existem dentro da silhueta, e quanto contraste cada uma tem. O Brave falha com
# QUATRO classes porque uma das fronteiras dele vale 57,9 de RGB — o vermelho
# contra o vermelho escuro do escudo — e mesmo assim custa uma linha.
#
# AS DUAS ASSERÇÕES QUE VALEM MAIS, e são as duas metades do mesmo experimento:
#
#   1. DESLIGADO NÃO MUDA UM BYTE. A arte convertida que está na tela dela foi
#      aprovada numa folha (11/08/2026). Uma chave que mexesse no padrão
#      trocaria arte aprovada em silêncio. `--peso-fronteira 0` tem de sair
#      idêntico ao padrão, arquivo a arquivo.
#
#   2. LIGADO NÃO PIORA QUEM JÁ SAÍA BEM. A Sprint T nomeou a trava: a
#      Calculadora, o Telegram e o VLC saem fiéis hoje e não podem piorar. Como
#      o limiar de 70 foi ESCOLHIDO no vale medido (64,6 … 77,1 vazio) e a
#      fronteira interna mais fraca do Telegram vale 78,4, a saída dos três tem
#      de continuar byte a byte igual. Se alguém subir o limiar, esta linha cai
#      antes de a folha da próxima leva ser gerada.
#
# E o canário do modo de falha: o `cosmic-edit` (as três linhas de texto vivem
# numa fronteira de 82,7) e o `cosmic-term` (o `>_` numa de 271,0). Medido em
# 09/09/2026 com `--peso-fronteira 140`, que é o mínimo para o limiar tocar o
# Chrome: o Editor cai de 5 traços para 2 e vira A FOLHA EM BRANCO do cabeçalho
# do `colapsar_fitas`, o btop de 4 para 1 e vira O QUADRADO VAZIO, e o Chrome
# ganha… um traço a menos. É por isso que 70 é o número e 140 não é.
# --------------------------------------------------------------------------
for origem in "${ORIGENS[@]}"; do
  [ -f "$origem" ] || continue
  nome="$(basename "$origem")"
  python3 "$CONV" "$origem" "$T/z0.svg" --json >"$T/z0.json" 2>/dev/null
  python3 "$CONV" "$origem" "$T/z1.svg" --peso-fronteira 0 >/dev/null 2>&1
  cmp -s "$T/z0.svg" "$T/z1.svg" \
    && ok "$nome: --peso-fronteira 0 é o padrão byte a byte" \
    || falha "$nome: --peso-fronteira 0 mudou a saída padrão"
  # `peso` null e não `0`: "não pediram" é outra coisa de "pediram zero", e a
  # folha decide por essa métrica se mostra a terceira coluna.
  [ "$(metrica "$T/z0.json" peso)" = "None" ] && ok "$nome: a métrica diz que a chave não foi pedida" \
    || falha "$nome: a métrica 'peso' não é null no padrão"
  [ "$(metrica "$T/z0.json" fundidas)" = "0" ] && ok "$nome: nenhuma fronteira fundida no padrão" \
    || falha "$nome: o padrão fundiu fronteira — a chave está ligada sozinha"
done

# A TRAVA: os três que a Sprint T proibiu de piorar, e os dois canários.
#   Byte a byte, não "parecido": o limiar de 70 foi medido justamente para não
#   os alcançar, e qualquer mudança aqui é mudança de arte aprovada.
TRAVA=(
  "/usr/share/icons/Papirus/64x64/apps/org.gnome.Calculator.svg"   # fiel, mín. 204,6
  "/usr/share/icons/Papirus/64x64/apps/org.telegram.desktop.svg"   # fiel, mín. 78,4 <- quem manda
  "/usr/share/icons/Papirus/64x64/apps/org.videolan.VLC.svg"       # fiel, mín. 281,3
  "$RAIZ/assets/icones/autorais/cosmic-edit-mocha.svg"             # canário: a folha em branco
  "$RAIZ/assets/icones/autorais/cosmic-term-mocha.svg"             # canário: o quadrado
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

# O GANHO: o Brave é o caso que a Sprint T nomeou, e ele tem de encolher.
#   Medido em 09/09/2026: 10 traços -> 3, fundindo UMA fronteira de 57,9 (o
#   vermelho contra o vermelho escuro do escudo). Se isto parar de valer, ou o
#   limiar caiu abaixo de 58 ou a fusão deixou de acontecer.
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
  # A saída ligada continua sendo o dialeto do acervo. Uma chave que quebrasse
  # o `_conferir_dialeto()` do app/servidor.py só apareceria na tela dela.
  grep -q 'stroke-width' "$T/w1.svg" && falha "brave/peso: gravou stroke-width" \
                                     || ok "brave/peso: sem stroke-width"
  grep -q 'viewBox="0 0 48 48"' "$T/w1.svg" && ok "brave/peso: viewBox 48" \
                                            || falha "brave/peso: viewBox errado"
  grep -q '<path ' "$T/w1.svg" && ok "brave/peso: <path com espaço (o _vestido injeta)" \
                               || falha "brave/peso: <path sem espaço"
fi

exit "$falhas"

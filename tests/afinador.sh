#!/usr/bin/env bash
# O AFINADOR PROPÕE, E NUNCA DECIDE SOZINHO.
#
# Em 09/09/2026 ela pediu: *"só implementa o gerador"*. O `afinar_conversor.py`
# é esse gerador — ele escolhe os botões do conversor por busca, contra a faixa
# derivada dos 39 Arcticons desenhados à mão. O que este teste prende não é o
# resultado da busca (esse muda quando o acervo muda, e deve mudar): é o
# CONTRATO dela com o repositório.
#
# AS TRÊS ASSERÇÕES QUE VALEM MAIS, porque cada uma prende um defeito que
# ACONTECEU durante a construção, não um que se imaginou:
#
#   1. A TRANCA DE FORMA EXISTE E MORDE. Sem ela a busca escolheu `--k 2` para a
#      Calculadora: nota 1,115, a melhor da grade inteira — e os nove botões
#      redondos viram um nó entrelaçado. Menos ponto, menos traço, nota boa,
#      desenho destruído. Medido: aquele candidato fica a 542 px de 2304 do que
#      o padrão desenha, contra 0 e 4 das escolhas dela. O teto de 138 (o mesmo
#      do `tests/conversor.sh`, e pela mesma pergunta) barra o nó. Esta linha
#      afirma que a Calculadora NÃO recebe proposta que mude a forma.
#
#   2. RODAR SEM `--escrever` NÃO ESCREVE UM BYTE. Um afinador que mexesse no
#      mapa ao ser consultado trocaria decisão dela por busca automática em
#      silêncio, que é exatamente o que o `bin/meow` já proíbe para o acervo:
#      *"reconverter trocaria arte que você aprovou por arte que ninguém viu"*.
#
#   3. RECEITA JÁ ESCRITA NÃO É SOBRESCRITA SEM `--refazer`. As três receitas do
#      mapa (Brave, Foliate, FileRoller) são escolha dela na bancada. A busca
#      DISCORDA de duas delas — e discordar é informação, não permissão.
#
#   0 = o contrato vale · 1 = quebrou · 2 = erro · 3 = falta dependência
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AFINA="$RAIZ/scripts/afinar_conversor.py"
MAPA="$RAIZ/assets/icones/apps-convertidos.map"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()   { printf 'ok: %s\n' "$1"; }
falha(){ printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas+1)); }

[ -f "$AFINA" ] || { printf 'pulado: sem scripts/afinar_conversor.py\n'; exit 0; }
for f in python3 rsvg-convert compare; do
  command -v "$f" >/dev/null || { printf 'pulado: falta %s\n' "$f"; exit 0; }
done
python3 -c 'import numpy' 2>/dev/null || { printf 'pulado: falta numpy\n'; exit 0; }
[ -f "/usr/share/icons/Papirus/64x64/apps/org.gnome.Calculator.svg" ] \
  || { printf 'pulado: o Papirus não está nesta máquina\n'; exit 0; }

# --------------------------------------------------------------- 2. não escreve
antes="$(md5sum "$MAPA" | cut -d' ' -f1)"

# A Calculadora e o FileRoller: uma é o caso da tranca, o outro é o caso da
# receita escrita. `--grade-teste` reduz a busca a quatro jogos, e `detalhe 0`
# está dentro deles de propósito — é o `--k 2` que destruía a Calculadora. Uma
# grade de teste sem o candidato ruim não provaria nada, e a grade cheia custaria
# minutos numa suíte que roda a cada leva.
python3 "$AFINA" --grade-teste --so org.gnome.Calculator --so org.gnome.FileRoller \
  --json >"$T/saida.json" 2>"$T/err"
rc=$?
[ "$rc" = 0 ] || [ "$rc" = 1 ] \
  || { falha "o afinador saiu com $rc: $(head -2 "$T/err")"; exit "$falhas"; }

depois="$(md5sum "$MAPA" | cut -d' ' -f1)"
[ "$antes" = "$depois" ] \
  && ok "sem --escrever o mapa não mudou um byte" \
  || falha "o mapa MUDOU sem --escrever — o afinador está decidindo sozinho"

metrica() { python3 -c '
import json,sys
d = json.load(open(sys.argv[1]))
for x in d["linhas"]:
    if x["nome"] == sys.argv[2]:
        print(x.get(sys.argv[3], ""))
        break
' "$T/saida.json" "$1" "$2"; }

# ------------------------------------------------------------- 1. a tranca
forma="$(metrica org.gnome.Calculator forma)"
if [ -n "$forma" ] && [ "$forma" -le 138 ]; then
  ok "Calculadora: a proposta fica a $forma px de 2304 do padrão (teto 138)"
else
  falha "Calculadora: a proposta está a '${forma:-?}' px — a tranca de forma não mordeu"
fi
# E o desfecho concreto daquele caso: sem tranca a busca queria `--k 2`.
receita="$(metrica org.gnome.Calculator receita)"
case "$receita" in
  *"--k 2 "*) falha "Calculadora: a busca voltou a escolher --k 2, que é o nó" ;;
  *)          ok "Calculadora: a proposta não é o --k 2 que destruía o teclado" ;;
esac

# ------------------------------------------------- 3. o escrito não se apaga
escrito="$(metrica org.gnome.FileRoller escrito)"
[ -n "$escrito" ] \
  && ok "FileRoller: o afinador enxerga a receita escrita ('$escrito')" \
  || falha "FileRoller: o afinador não leu o campo 4 do mapa"
grep -q "^org.gnome.FileRoller:.*:--k 10 --funde 36 --tol 3.4$" "$MAPA" \
  && ok "FileRoller: a receita dela continua no mapa, intacta" \
  || falha "FileRoller: a receita dela saiu do mapa"

# ------------------------------------- a proposta é do dialeto, sempre
# Uma busca que devolvesse bandeira fora da forma canônica quebraria a cerca
# `_RE_PARAMETROS_DESENHO` do app/servidor.py, e só apareceria na tela dela.
for nome in org.gnome.Calculator org.gnome.FileRoller; do
  r="$(metrica "$nome" receita)"
  if printf '%s' "$r" | grep -qE '^--k [0-9]{1,2} --funde [0-9]{1,3} --tol [0-9]{1,2}(\.[0-9])?( --peso-fronteira [0-9]{1,3})?( --min-traco [0-9]{1,2}(\.[0-9])?)?$'; then
    ok "$nome: a receita casa com a cerca do app"
  else
    falha "$nome: '$r' não casa com _RE_PARAMETROS_DESENHO — o app recusaria"
  fi
done

exit "$falhas"

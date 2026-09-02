#!/usr/bin/env bash
# O painel e o wizard leem o MESMO meow.conf.exemplo — e têm de concordar.
#
# POR QUE ESTE TESTE EXISTE
#   O catálogo de chaves do painel (`app/servidor.py`, em Python) é uma tradução
#   das regras do `wiz_ler_esquema` do `bin/meow` (em bash). Duas implementações
#   da mesma leitura é exatamente a coisa que este repositório mais persegue —
#   `lib/comum.sh` conta o que custou quando existiram duas rotinas de escrita na
#   mesma chave: uma trocava a PRIMEIRA ocorrência enquanto o shell obedece a
#   ÚLTIMA, e o `meow configurar` gravava um valor mostrando o diff certo
#   enquanto o valor em vigor continuava outro, sem nada acusar.
#
#   Aqui a duplicação é inevitável (o navegador não roda bash, e reescrever o
#   wizard em Python seria trocar um problema por outro). O que dá para fazer é
#   PROVAR TODO DIA que as duas concordam, em vez de esperar o dia em que alguém
#   mexe no formato do exemplo e só uma das duas acompanha.
#
# O QUE ELE COMPARA
#   1. a LISTA de chaves — mesmos nomes, mesma quantidade, mesma ordem;
#   2. o VALOR PADRÃO de cada uma, como está escrito no exemplo;
#   3. as OPÇÕES de cada chave (`a | b | c`), que é a regra mais fácil de
#      divergir — o bash descarta a linha inteira se um token não parecer valor,
#      e o Python tem de fazer o mesmo.
#
#   O QUE ELE COMPARA É A REGRA COMPARTILHADA, NÃO A TELA
#   O painel acrescenta DUAS coisas por cima do que o texto literalmente diz, e
#   as duas são de apresentação — nenhuma muda o valor que vai para o disco:
#
#     - tira o `vazio` da lista. `vazio` não é um valor, é a ausência de um:
#       gravá-lo daria `RELOGIO_SEGUNDOS="vazio"`, que não é `sim` nem `nao` e
#       cairia no `*)` de qualquer `case` do projeto sem nada avisar. Na página
#       ele vira o terceiro estado do controle ("não mexer");
#     - infere `sim | nao` para a chave cujo VALOR DE FÁBRICA já é `sim` ou `nao`
#       e cujo comentário não lista nada (são 19 hoje, entre elas a
#       `LOGO_ROTACAO`). Sem isso a página desenhava um campo de texto livre para
#       uma pergunta de sim ou não — e ainda deixava passar `não` com til, que o
#       `case` do shell não casa.
#
#   Por isso a comparação é contra o `_opcoes()` do servidor, que é a tradução
#   literal do `wiz_opcoes` do bash, e não contra a lista final que a página
#   desenha. A inferência tem conferência PRÓPRIA, logo abaixo: ela só pode
#   acontecer onde o padrão da chave já é `sim` ou `nao`.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EXEMPLO="$RAIZ/meow.conf.exemplo"
falhas=0

command -v python3 >/dev/null || { printf 'pulado: sem python3\n'; exit 0; }

# --- 1. o painel compila e o esquema sai de pé ------------------------------
python3 -m py_compile "$RAIZ/app/servidor.py" || {
  printf 'FALHOU: app/servidor.py não compila\n' >&2; exit 1; }

# --- 2. a leitura do bash, extraída do próprio bin/meow ---------------------
# Sourcear o `bin/meow` inteiro rodaria o `despachar` no fim. Em vez disso o
# teste recorta as funções do wizard com `sed` e as avalia sozinhas — assim o que
# está sendo testado é o CÓDIGO DE VERDADE do wizard, e não uma cópia dele que
# envelheceria junto com o resto.
esquema_bash="$(
  MEOW_RAIZ="$RAIZ" bash -c '
    set -uo pipefail
    . "'"$RAIZ"'/lib/comum.sh"
    RAIZ="'"$RAIZ"'"
    CONF_PADRAO="'"$EXEMPLO"'"
    logos_disponiveis() { :; }   # o painel lê os gatos do disco; aqui não importa
    # AS DECLARAÇÕES VÊM ANTES, E SEM ELAS O TESTE MORRE COM UM ERRO ENIGMÁTICO
    #   No `bin/meow` estes arrays são declarados FORA das funções, e o recorte
    #   abaixo pega só as funções. Sem o `declare -A`, `WIZ_AJUDA[$chave]="..."`
    #   trata `$chave` como ÍNDICE ARITMÉTICO de um array indexado — ou seja, o
    #   bash avalia a string `FLAVOR` como expressão, e com `set -u` isso morre
    #   com "FLAVOR: variável não associada", que não tem nada a ver com o que
    #   está sendo testado. Foi exatamente o que aconteceu na primeira execução.
    declare -a WIZ_CHAVES=()
    declare -A WIZ_AJUDA=() WIZ_SECAO=() WIZ_ESSENCIAL=()
    # As funções do wizard, recortadas do arquivo vivo.
    eval "$(sed -n "/^wiz_ler_esquema() {/,/^}/p"      "$RAIZ/bin/meow")"
    eval "$(sed -n "/^wiz_valor_da_linha() {/,/^}/p"   "$RAIZ/bin/meow")"
    eval "$(sed -n "/^wiz_linha_da_chave() {/,/^}/p"   "$RAIZ/bin/meow")"
    eval "$(sed -n "/^wiz_comentario_da_linha() {/,/^}/p" "$RAIZ/bin/meow")"
    eval "$(sed -n "/^wiz_opcoes() {/,/^}/p"           "$RAIZ/bin/meow")"
    wiz_ler_esquema || exit 2
    for k in "${WIZ_CHAVES[@]}"; do
      linha="$(wiz_linha_da_chave "$k" "$CONF_PADRAO")"
      valor="$(wiz_valor_da_linha "$linha")"
      inline="$(wiz_comentario_da_linha "$linha")"
      opc="$(wiz_opcoes "$k" "${WIZ_AJUDA[$k]:-}" "$inline" | grep -v "^vazio$" | paste -sd, -)"
      printf "%s\t%s\t%s\n" "$k" "$valor" "$opc"
    done
  '
)" || { printf 'FALHOU: não consegui rodar a leitura do bin/meow\n' >&2; exit 1; }

# --- 3. a leitura do Python -------------------------------------------------
esquema_py="$(
  MEOW_RAIZ="$RAIZ" python3 - "$RAIZ" <<'PY'
import sys, os
raiz = sys.argv[1]
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor
for i in servidor.ler_esquema():
    # O LOGO e os gatos saem do DISCO nos dois lados; comparar a lista deles aqui
    # testaria o acervo de `assets/gatos/`, não a leitura do exemplo.
    if i["chave"] in ("LOGO", "LOGO_DIA", "LOGO_NOITE", "FASTFETCH_LOGO_GATO"):
        opc = ""
    else:
        # `_opcoes` é a regra compartilhada com o `wiz_opcoes`; `i["opcoes"]` é a
        # lista que a PÁGINA desenha, já com os dois ajustes de apresentação.
        # É a primeira que tem de bater com o bash.
        bruto = servidor._opcoes(i["chave"], i["ajuda"], i["inline"])
        opc = ",".join(o for o in bruto if o != "vazio")
    print("%s\t%s\t%s" % (i["chave"], i["padrao"], opc))
PY
)" || { printf 'FALHOU: não consegui rodar a leitura do app/servidor.py\n' >&2; exit 1; }

# O mesmo recorte do lado do bash, pelo mesmo motivo.
esquema_bash="$(printf '%s\n' "$esquema_bash" | awk -F'\t' -v OFS='\t' '
  $1=="LOGO"||$1=="LOGO_DIA"||$1=="LOGO_NOITE"||$1=="FASTFETCH_LOGO_GATO" {$3=""}
  {print}')"

# --- 4. o veredito ----------------------------------------------------------
if [ "$esquema_bash" != "$esquema_py" ]; then
  printf 'FALHOU: o wizard (bash) e o painel (python) leem o meow.conf.exemplo diferente.\n\n' >&2
  diff <(printf '%s\n' "$esquema_bash") <(printf '%s\n' "$esquema_py") \
    | sed 's/^</  bin\/meow  /; s/^>/  servidor  /' >&2
  falhas=$((falhas+1))
else
  n="$(printf '%s\n' "$esquema_py" | grep -c .)"
  printf 'ok: as %s chaves leem igual no bin/meow e no app/servidor.py\n' "$n"
fi

# --- 5 e 6. as duas regras que valem para o CÓDIGO, não para o comentário ---
# O COMENTÁRIO TEM DE PODER FALAR DA REGRA SEM QUEBRÁ-LA
#   A primeira versão destes dois testes era um `grep` seco, e os dois acusaram —
#   o `estilo.css` porque o cabeçalho dele explica a regra citando um `#1e1e2e`
#   de exemplo, e o `servidor.py` porque o cabeçalho promete que `shell=True`
#   "não aparece uma vez neste arquivo". Um teste que proíbe explicar a própria
#   regra faria este repositório, que é escrito em prosa comentada, perder a
#   prosa. Então os comentários saem antes da varredura.
python3 - "$RAIZ" <<'PY' || falhas=$((falhas+1))
import re, sys, os
raiz = sys.argv[1]
falhou = 0

css = open(os.path.join(raiz, "app/pagina/estilo.css"), encoding="utf-8").read()
css_sem_comentario = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
hex_achados = re.findall(r"#[0-9A-Fa-f]{3,8}\b", css_sem_comentario)
if hex_achados:
    print("FALHOU: há hex no CÓDIGO de estilo.css — a cor tem de vir da paleta: %s"
          % ", ".join(sorted(set(hex_achados))), file=sys.stderr)
    falhou = 1
else:
    print("ok: estilo.css não tem um hex fora de comentário — a cor vem de /paleta.css")

# A inferência de `sim | nao` só pode acontecer onde o próprio arquivo já diz
# `sim` ou `nao` no valor de fábrica. Se um dia ela escorregar para uma chave de
# texto livre, a página passaria a oferecer dois botões que gravariam lixo — e
# nada na tela acusaria, porque dois botões parecem certos.
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor
escorregou = [
    i["chave"] for i in servidor.ler_esquema()
    if i["opcoes"] == ["sim", "nao"]
    and not servidor._opcoes(i["chave"], i["ajuda"], i["inline"])
    and i["padrao"] not in ("sim", "nao")
]
if escorregou:
    print("FALHOU: sim/nao inferido para chave que não é binária: %s"
          % ", ".join(escorregou), file=sys.stderr)
    falhou = 1
else:
    n = sum(1 for i in servidor.ler_esquema() if i["opcoes"] == ["sim", "nao"])
    print("ok: as %d chaves com dois botões sim/nao têm padrão `sim` ou `nao`" % n)

py = open(os.path.join(raiz, "app/servidor.py"), encoding="utf-8").read().splitlines()
codigo = [l for l in py if not l.lstrip().startswith("#")]
if any("shell=True" in l for l in codigo):
    print("FALHOU: app/servidor.py usa shell=True no código", file=sys.stderr)
    falhou = 1
else:
    print("ok: o servidor não tem shell=True em lugar nenhum do código")
sys.exit(falhou)
PY

exit "$falhas"

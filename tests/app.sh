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

# --- 7. O PAINEL CONFIGURA TUDO QUE O INSTALADOR LÊ -------------------------
#   Pedido dela em 06/09/2026: *"a ideia é o html personalizar tudo, configurar
#   as variáveis que são lidas no install — temos que garantir isso"*.
#
#   O catálogo é DERIVADO dos comentários do `meow.conf.exemplo`, e o risco
#   disso é o oposto do de uma lista escrita à mão: uma chave que um script
#   passa a ler e o exemplo não cataloga nasce INVISÍVEL no painel. Ninguém
#   descobre — o script tem um padrão e funciona, e ela nunca vê o controle.
#   Foi assim que `FASTFETCH_LOGO_CELULA` e `FASTFETCH_LOGO_BLOCOS` passaram
#   semanas sendo lidas sem cartão.
#
#   O SINAL É O IDIOMA, e não uma lista: toda etapa lê a configuração dela
#   escrevendo `VAR="${VAR:-padrão}"`. Variável local de shell nunca se escreve
#   assim, porque não vem de fora.
import re as _re, subprocess as _sp

_IDIOMA = _re.compile(r'^\s*([A-Z][A-Z0-9_]{2,})="\$\{\1:[-=]', _re.M)
# Sobrescritas de CAMINHO para teste e constantes MEDIDAS não são ajuste dela.
# Cada uma tem o porquê no cabeçalho do próprio script — o `SOM_GANHO` diz
# "calibrado, não é gosto"; o `GREETER_HOME` é `/var/lib` com outro nome para o
# teste poder rodar sem root.
_NAO_E_AJUSTE = {
    "APROXIMOU",        # contador interno do icones_apps.sh
    "FORMA_COMP_BIN",   # caminho do binário do compositor, para teste
    "GREETER_HOME",     # /var/lib/cosmic-greeter, para teste
    "PROMPT_ALVO",      # ~/.config/starship.toml, para teste
    "SOM_DURACAO",      # 85 ms: o debounce medido do osd, não gosto
    "SOM_GANHO",        # calibrado com volumedetect para casar o de fábrica
    "VIDRO_OPACIDADE",  # atalho LEGADO das duas VIDRO_OPACIDADE_*, que o
                        # painel oferece separadas — duas portas para o mesmo
                        # valor seriam duas respostas para a mesma pergunta
}
_INTERNAS = _re.compile(r"^(MEOW_|FFL_|CP_|XDG_|ZDOTDIR|TMPDIR|NO_COLOR)")

_catalogo = {i["chave"] for i in servidor.ler_esquema()}
_lidas = {}
for _f in _sp.run(["git", "ls-files"], cwd=raiz, capture_output=True,
                  text=True).stdout.split():
    if not _f.endswith(".sh") or _f.startswith("tests/"):
        continue
    try:
        _txt = open(os.path.join(raiz, _f), encoding="utf-8", errors="replace").read()
    except OSError:
        continue
    for _m in _IDIOMA.finditer(_txt):
        _k = _m.group(1)
        if not _INTERNAS.match(_k) and _k not in _NAO_E_AJUSTE:
            _lidas.setdefault(_k, set()).add(_f)

_sem_cartao = sorted(k for k in _lidas if k not in _catalogo)
if _sem_cartao:
    print("FALHOU: script lê do meow.conf e o painel não oferece: %s"
          % ", ".join("%s (%s)" % (k, ", ".join(sorted(_lidas[k]))) for k in _sem_cartao),
          file=sys.stderr)
    falhou = 1
else:
    print("ok: as %d chaves que os scripts leem do conf têm cartão no painel"
          % len(_lidas))

# --- 8. O QUE O PAINEL LÊ DA MÁQUINA É O QUE OS SCRIPTS GRAVAM — 13/09/2026 --
#   `NA_MAQUINA` (servidor.py) é a leitura inversa dos scripts: o deslizante diz
#   "como está: 24" lendo o arquivo em que o `forma.sh` grava o raio. A tabela
#   não sai do `meow.conf.exemplo` — o exemplo diz o que a chave faz, não onde
#   o COSMIC a guarda —, e o dia em que um script passar a gravar outro arquivo
#   a tela continuaria mostrando um número: o velho, com a mesma confiança.
#   Então: toda chave da tabela existe no catálogo, e o arquivo que ela lê é
#   citado no CÓDIGO de algum script, junto do programa do COSMIC que o guarda.
_sh_codigo = {}
for _f in _sp.run(["git", "ls-files", "scripts"], cwd=raiz, capture_output=True,
                  text=True).stdout.split():
    if _f.endswith(".sh"):
        _txt = open(os.path.join(raiz, _f), encoding="utf-8", errors="replace").read()
        _sh_codigo[_f] = "\n".join(l for l in _txt.splitlines() if not l.lstrip().startswith("#"))
_sem_escritor = []
for _k, (_arq, _traduz) in sorted(servidor.NA_MAQUINA.items()):
    _programa = _arq.split("/")[0].split(".")[2]           # CosmicPanel, CosmicComp…
    _nome = os.path.basename(_arq)
    if not any(_programa in _t and _nome in _t for _t in _sh_codigo.values()):
        _sem_escritor.append("%s (%s)" % (_k, _arq))
_fora = sorted(k for k in servidor.NA_MAQUINA if k not in _catalogo)
if _sem_escritor or _fora:
    print("FALHOU: o painel lê da máquina o que nenhum script grava: %s; fora do catálogo: %s"
          % (", ".join(_sem_escritor) or "—", ", ".join(_fora) or "—"), file=sys.stderr)
    falhou = 1
else:
    print("ok: as %d chaves que o painel lê da máquina saem de arquivos que os scripts gravam"
          % len(servidor.NA_MAQUINA))

# --- 9. O PAINEL NÃO ENSAIA — 13/09/2026 -------------------------------------
#   Pedido dela: *"eu tinha pedido pra tirar o app do modo sandbox"*. Nenhum
#   pedido da página leva `seco`, nenhuma rota o lê, e nenhum ambiente que o
#   servidor monta liga `MEOW_DRY_RUN`. Olha só o CÓDIGO: os comentários contam
#   a história do ensaio, e têm de poder continuar contando.
_js = re.sub(r"/\*.*?\*/", "", open(os.path.join(raiz, "app/pagina/app.js"),
                                    encoding="utf-8").read(), flags=re.S)
_js = "\n".join(l for l in _js.splitlines() if not l.lstrip().startswith("//"))
_restos = re.findall(r"\bseco\b|ensaiando|#seco\b", _js)
_py = "\n".join(l for l in open(os.path.join(raiz, "app/servidor.py"), encoding="utf-8")
                .read().splitlines() if not l.lstrip().startswith("#"))
_restos += re.findall(r"""get\(["']seco["']\)|\[["']MEOW_DRY_RUN["']\]\s*=""", _py)
if _restos:
    print("FALHOU: o ensaio voltou ao painel: %s" % ", ".join(sorted(set(_restos))),
          file=sys.stderr)
    falhou = 1
else:
    print("ok: nem a página nem o servidor falam em ensaio fora dos comentários")

# --- 10. O TRABALHO LEVA A CONF, E O ÍCONE QUE NÃO VALE NÃO É OFERECIDO — 13/09 --
#   Medido pela interface: «Usar este ícone» rodou o `icones_apps_arcticons.sh`
#   com o ambiente do servidor e nada mais. Sem `ICONES_COR_MARCA`, doze ícones
#   da máquina dela voltaram à cor de categoria. E no Hefesto, que o script pula
#   por ser intocável, a tela disse que valeu e a dock ficou igual.
#   Então: a conf exportada é a do `set -a` (com expansão e com os padrões do
#   `carregar_conf`), um conf quebrado não vira "tudo no padrão", o `iniciar` a
#   usa, e as três travas do script chegam ao servidor.
import inspect as _inspect
import tempfile as _tf
_d = _tf.mkdtemp()
_bom, _quebrado = os.path.join(_d, "bom.conf"), os.path.join(_d, "quebrado.conf")
with open(_bom, "w", encoding="utf-8") as _fh:
    _fh.write('FLAVOR="latte"\nICONES_COR_MARCA="sim"   # sim | nao\n'
              'ICONES_PASTAS="cat-${FLAVOR}"\n')
with open(_quebrado, "w", encoding="utf-8") as _fh:
    _fh.write('FLAVOR="latte\n')
_conf_dela = servidor.CONF
try:
    servidor.CONF = _bom
    _exp = servidor.conf_exportada() or {}
    servidor.CONF = _quebrado
    _exp_quebrado = servidor.conf_exportada()
finally:
    servidor.CONF = _conf_dela
_erros10 = []
for _k, _v in (("ICONES_COR_MARCA", "sim"), ("FLAVOR", "latte"), ("ICONES_PASTAS", "cat-latte"),
               ("MODO", "escuro")):
    if _exp.get(_k) != _v:
        _erros10.append("%s saiu %r, e não %r" % (_k, _exp.get(_k), _v))
if _exp_quebrado is not None:
    _erros10.append("um conf com erro de sintaxe virou ambiente em vez de recusa")
_ini = _inspect.getsource(servidor.iniciar)
if "conf_exportada()" not in _ini or "ambiente.update(conf)" not in _ini:
    _erros10.append("o iniciar não põe a conf no ambiente do trabalho")
_m = servidor.Manipulador.__new__(servidor.Manipulador)
_tr = _m._travas_do_arcticons()
if not _tr[0]:
    _erros10.append("a lista INTOCAVEIS do script não foi lida")
if not _m._motivo_da_trava(_tr, ["hefesto-dualsense4unix"], "Hefesto"):
    _erros10.append("o Hefesto, intocável, não trava")
if _tr[3] and not _m._motivo_da_trava(_tr, [sorted(_tr[3])[0]], "x"):
    _erros10.append("um app do acervo convertido não trava")
if _m._motivo_da_trava(_tr, ["org.exemplo.NaoExiste"], "x") is not None:
    _erros10.append("um app sem nenhuma das três travas travou")
if _erros10:
    print("FALHOU: " + "; ".join(_erros10), file=sys.stderr)
    falhou = 1
else:
    print("ok: o trabalho leva a conf do set -a, e as travas do traço chegam ao servidor")

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

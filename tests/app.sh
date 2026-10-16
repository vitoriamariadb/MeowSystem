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

# NADA FICA EM /tmp — 15/10/2026, P82 (item 38). O bloco 10 fazia um
# `mkdtemp()` (o `bom.conf` e o `quebrado.conf`) sem apagar, e cada rodada da
# suíte deixava uma pasta. Agora todo temporário deste teste, do bash e do
# Python, nasce dentro de UMA pasta (o `TMPDIR`), e ela sai no fim, inclusive
# por sinal (o Ctrl+C de quem roda, o TERM de um `timeout`).
_TMP_DO_TESTE="$(mktemp -d)" || exit 2
trap 'rm -rf "$_TMP_DO_TESTE"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
export TMPDIR="$_TMP_DO_TESTE"
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
    "FZF_ALVO",         # ~/.config/meowsystem/fzf.sh, para teste (P44)
    "GREETER_HOME",     # /var/lib/cosmic-greeter, para teste
    "PROMPT_ALVO",      # ~/.config/starship.toml, para teste
    "SOM_DURACAO",      # 85 ms: o debounce medido do osd, não gosto
    "SOM_GANHO",        # calibrado com volumedetect para casar o de fábrica
    "VIDRO_OPACIDADE",  # atalho LEGADO das duas VIDRO_OPACIDADE_*, que o
                        # painel oferece separadas — duas portas para o mesmo
                        # valor seriam duas respostas para a mesma pergunta
}
# SPICE_ entrou em 22/09/2026, com a P29, e é da mesma família de FFL_ e CP_:
# são as variáveis internas do scripts/spicetify_setup.sh, trazido do
# Spellbook-OS. As quatro que o teste apontou — SPICE_VERSAO (2.45.1),
# SPICE_DIR (~/.spicetify), SPICE_RELEASES (a URL do GitHub) e
# SPICE_PREFS_FLATPAK (o prefs dentro do ~/.var/app) — são endereço e versão de
# um programa de terceiro, com padrão embutido e override só para teste.
# Nenhuma delas é escolha de tema, e pô-las na tela seria oferecer à pessoa uma
# pergunta que ela não tem como responder.
# CV_, PA_, AP_, AS_ e OT_ entraram em 09/10/2026, com a P76, e são da mesma
# família do CP_: caminhos e comandos sobrescrevíveis para teste do pré-voo do
# COSMIC (cosmic_prever.sh), do pós-apt (cosmic_pos_apt.sh), do pino dos
# applets (applet_pino.sh), da guarda do `.deb` (atualizar_sistema.sh) e do
# oráculo do tema (oraculo_tema.sh). Nenhuma é escolha de tema.
# GB_ entrou em 15/10/2026, com a P81: os caminhos e comandos do
# garantir_builds.sh, sobrescrevíveis para teste, da mesma família.
_INTERNAS = _re.compile(r"^(MEOW_|FFL_|CP_|CV_|PA_|AP_|AS_|OT_|GB_|SPICE_|XDG_|ZDOTDIR|TMPDIR|NO_COLOR)")

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

# A CHAVE APOSENTADA NÃO TEM CARTÃO DE PROPÓSITO — P75, 09/10/2026. A
#   `ICONES_BASE` saiu do exemplo por decisão (24/09, «Tirar a linha do conf»),
#   e o `migrar_conf.py` tira a linha ativa de todo meow.conf (`APOSENTADAS`).
#   Os leitores que ainda escrevem `${ICONES_BASE:-…}` só enxergam o padrão
#   depois disso; trocá-los pela pergunta ao pack é a P74, item 1. A lista vem
#   de lá, por caminho, como o servidor lê o `RENOMEADAS`: uma segunda lista
#   aqui envelheceria. E vale o inverso: aposentada com cartão é falha.
import importlib.util as _ilu
_spec = _ilu.spec_from_file_location("meow_migrar_conf", os.path.join(raiz, "scripts", "migrar_conf.py"))
_migrar = _ilu.module_from_spec(_spec); _spec.loader.exec_module(_migrar)
_aposentadas = set(getattr(_migrar, "APOSENTADAS", {}))
_com_cartao = sorted(_aposentadas & _catalogo)
if _com_cartao:
    print("FALHOU: chave aposentada ainda tem cartão no painel: %s" % ", ".join(_com_cartao),
          file=sys.stderr)
    falhou = 1
_sem_cartao = sorted(k for k in _lidas if k not in _catalogo and k not in _aposentadas)
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

# --- 9. O PAINEL NÃO TEM INTERRUPTOR DE ENSAIO -------------------------------
#   NASCEU EM 13/09/2026 DIZENDO OUTRA COISA, E A SPRINT P8 A REESCREVEU EM
#   22/09. A trava de 13/09 era "nenhum pedido da página leva `seco`, nenhuma
#   rota o lê, nenhum ambiente liga `MEOW_DRY_RUN`" — a leitura larga de
#   *"eu tinha pedido pra tirar o app do modo sandbox"*. A outra metade da
#   mesma queixa dela é *"nada da interface é aplicado em sandbox; tudo é
#   aplicado na máquina da pessoa"*, e o meio que faltava entre os dois
#   extremos é o que a P8 entregou: um botão «Ver o que faria» por gesto.
#
#   O QUE ELA PEDIU PARA TIRAR CONTINUA PROIBIDO, e é isso que esta trava
#   guarda agora — o INTERRUPTOR. Um estado guardado que fazia todo clique
#   seguinte fingir, até alguém desligá-lo; era ele que produzia "nada tá
#   aplicando de verdade", porque a tela mentia em silêncio sobre o gesto
#   seguinte, e o seguinte. A diferença entre os dois desenhos é exatamente
#   ESTA: um botão não guarda nada entre um clique e o outro.
#
#   Então a pergunta que este bloco faz mudou de "o ensaio existe?" para "o
#   ensaio é pedido, ou é lembrado?". Uma trava que só dissesse "não pode
#   existir" seria uma trava contra a decisão de hoje, e não contra o defeito.
_js = re.sub(r"/\*.*?\*/", "", open(os.path.join(raiz, "app/pagina/app.js"),
                                    encoding="utf-8").read(), flags=re.S)
_js = "\n".join(l for l in _js.splitlines() if not l.lstrip().startswith("//"))
#   9a. NADA DE SECO GUARDADO NA PÁGINA. A chave `meow-seco` do `sessionStorage`
#       era o interruptor; qualquer armazenamento na mesma linha de um `seco` é
#       a mesma ideia voltando com outro nome.
_guardado = re.findall(r"meow-seco", _js)
_guardado += [l.strip() for l in _js.splitlines()
              if re.search(r"(session|local)Storage", l) and re.search(r"\bseco\b", l)]
#   9b. NO SERVIDOR, `MEOW_DRY_RUN` SÓ PODE SER LIGADO EM UM LUGAR, e esse lugar
#       é o `_ambiente_do_painel`, atrás do parâmetro `seco`. Duas ligações
#       querem dizer dois donos do modo — e o segundo é sempre o que alguém
#       esquece de consultar. A conta é de ATRIBUIÇÕES, e não do nome: o nome
#       aparece no `pop` que arranca a herança do terminal, que é o oposto disto
#       e tem de continuar existindo.
_py = "\n".join(l for l in open(os.path.join(raiz, "app/servidor.py"), encoding="utf-8")
                .read().splitlines() if not l.lstrip().startswith("#"))
_ligam = re.findall(r"""\[["']MEOW_DRY_RUN["']\]\s*=""", _py)
if _guardado or len(_ligam) != 1 or "_ambiente_do_painel(seco=False)" not in _py:
    print("FALHOU: o interruptor de ensaio voltou ao painel: guardado=%s, "
          "ligações de MEOW_DRY_RUN=%d (espera 1), assinatura do ambiente=%s"
          % (sorted(set(_guardado)) or "—", len(_ligam),
             "ok" if "_ambiente_do_painel(seco=False)" in _py else "mudou"),
          file=sys.stderr)
    falhou = 1
else:
    print("ok: o ensaio é pedido por gesto, e não guardado num interruptor")

#   9c. E O ENSAIO PRECISA CONTINUAR EXISTINDO. Esta metade é nova em 22/09 e é
#       a que a P8 realmente comprou: sem ela, um refactor que apagasse o botão
#       deixaria a suíte verde — que é como o ensaio sumiu da tela da primeira
#       vez, sem nenhum teste dizendo nada. As três peças da sprint, pelo nome
#       que elas têm no código.
_pecas = [("o botão do diálogo", "confirmar-ensaio", _js),
          ("o botão da barra do alto", "botao-ensaiar", _js),
          ("a faixa da gaveta", "faixa-ensaio", _js),
          ("o «Rodar de verdade» pós-ensaio", "ensaio-rodar", _js),
          #   A cópia descartável do meow.conf é a peça que faz o ensaio do
          #   «Salvar e aplicar» responder sobre AS ESCOLHAS. A primeira versão
          #   desta sprint as mandava por ambiente e o `install.sh` as engolia
          #   no `set -a; . "$fonte"` — ensaio do conf antigo, aprovado como se
          #   fosse o novo. Se alguém voltar ao ambiente, esta linha fica
          #   vermelha antes de a pessoa descobrir sozinha.
          ("a cópia descartável do ensaio", "_conf_de_ensaio", _py),
          ("o MEOW_CONF do ensaio", 'ambiente["MEOW_CONF"]', _py),
          ("o seco no /api/rodar", 'corpo.get("seco")', _py),
          ("o seco no /api/salvar", 'corpo.get("seco")', _py)]
_faltam = ["%s (%s)" % (nome, marca) for nome, marca, onde in _pecas if marca not in onde]
if _faltam:
    print("FALHOU: o ensaio da sprint P8 sumiu da tela: %s" % ", ".join(_faltam),
          file=sys.stderr)
    falhou = 1
else:
    print("ok: o «Ver o que faria» está no diálogo, na barra e na gaveta")

#   9d. E O ENSAIO TEM DE RESPONDER SOBRE AS ESCOLHAS, SEM TOCAR NO ARQUIVO
#       DELA. As duas metades da mesma pergunta, e a checagem de texto acima não
#       alcança nenhuma: um `_conf_de_ensaio` que copiasse e esquecesse de
#       gravar passaria por ela. A escolha entra na CÓPIA (é o que o
#       `install.sh` vai sourcear), o sha256 do arquivo dela não se move, e a
#       `conf_exportada` da cópia devolve o valor NOVO — que é de onde sai a
#       ponte da paleta do trabalho.
import hashlib as _hl
import shutil as _sh
import tempfile as _tf9
_d9 = _tf9.mkdtemp()
_dela = os.path.join(_d9, "meow.conf")
_sh.copyfile(os.path.join(raiz, "meow.conf.exemplo"), _dela)
_antes9 = _hl.sha256(open(_dela, "rb").read()).hexdigest()
_conf_dela9 = servidor.CONF
_erros9 = []
#       A ausência da função já é gritada pelo 9c acima; aqui ela vira um pulo
#       em vez de um traceback, senão um único refactor derruba o resto do
#       arquivo e esconde as travas que vêm depois.
_faz_ensaio = getattr(servidor, "_conf_de_ensaio", None)
if _faz_ensaio is None:
    _pasta9, _queixa9 = None, "o _conf_de_ensaio não existe (ver a trava acima)"
else:
    try:
        servidor.CONF = _dela
        _pasta9, _queixa9 = _faz_ensaio([("FLAVOR", "frappe")])
    finally:
        servidor.CONF = _conf_dela9
if _queixa9:
    _erros9.append("o ensaio não conseguiu preparar a cópia: %s" % _queixa9)
else:
    _copia9 = os.path.join(_pasta9, "meow.conf")
    if 'FLAVOR="frappe"' not in open(_copia9, encoding="utf-8").read():
        _erros9.append("a escolha não entrou na cópia que o install.sh vai ler")
    if (servidor.conf_exportada(_copia9) or {}).get("FLAVOR") != "frappe":
        _erros9.append("a conf exportada da cópia ainda diz o FLAVOR do disco")
    _sh.rmtree(_pasta9, ignore_errors=True)
if _hl.sha256(open(_dela, "rb").read()).hexdigest() != _antes9:
    _erros9.append("o ensaio mexeu no meow.conf dela — é a promessa inteira da palavra")
_sh.rmtree(_d9, ignore_errors=True)
if _erros9:
    print("FALHOU: o ensaio do «Salvar e aplicar»: " + "; ".join(_erros9), file=sys.stderr)
    falhou = 1
else:
    print("ok: o ensaio lê as escolhas numa cópia e não toca no meow.conf dela")

#   9e. E OS MAPAS DE ÍCONE DELA VÃO JUNTO COM A CÓPIA — QA da P77, 10/10/2026.
#       O `pack.py` e o `icones_apps_arcticons.sh` acham o `icones-escolhidos.map`
#       e o `icones-traco.map` pela pasta do `MEOW_CONF`; no ensaio ela é a da
#       cópia, sem mapa, e o «Ver o que faria» anunciava apagar o ícone que o
#       «Usar este ícone» acabara de pôr. O `iniciar` passa os dois endereços.
import inspect as _inspect9
_ini9 = _inspect9.getsource(servidor.iniciar)
_falta9 = [v for v in ("MEOW_ICONES_ESCOLHAS", "MEOW_ICONES_TRACO") if v not in _ini9]
if _falta9:
    print("FALHOU: o ensaio do «Salvar e aplicar» não leva os mapas de ícone dela: "
          + ", ".join(_falta9), file=sys.stderr)
    falhou = 1
else:
    print("ok: o ensaio lê os mapas de ícone de quem usa, e não os da pasta da cópia")

#   9f. O «HÁ DIVERGÊNCIAS» TRAZ O BOTÃO DO CONSERTO — QA da P77, 10/10/2026.
#       O doctor termina em «rode: meow doctor --consertar»; a gaveta oferece o
#       botão da ação que conserta. Toda `conserta_com` aponta uma ação que
#       existe e escreve, o trabalho a leva para a página, e a página a usa.
_erros9f = []
for _id9f, _a9f in servidor.ACOES.items():
    _alvo9f = _a9f.get("conserta_com")
    if _alvo9f and (_alvo9f not in servidor.ACOES or not servidor.escreve(servidor.ACOES[_alvo9f])):
        _erros9f.append("%s conserta com %r, que não é ação que escreve" % (_id9f, _alvo9f))
if servidor.ACOES.get("doctor", {}).get("conserta_com") != "doctor_consertar":
    _erros9f.append("o «Conferir a máquina» não declara o «Consertar o que estiver fora»")
_js9f = open(os.path.join(raiz, "app/pagina/app.js"), encoding="utf-8").read()
if '"conserta_com"' not in _inspect9.getsource(servidor) or "oferecerConserto(TRABALHO.conserta)" not in _js9f:
    _erros9f.append("o trabalho não leva a `conserta_com` à gaveta, ou a gaveta não a oferece")
if _erros9f:
    print("FALHOU: " + "; ".join(_erros9f), file=sys.stderr)
    falhou = 1
else:
    print("ok: o «há divergências» do conferir oferece o botão do conserto na gaveta")

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
# `conf_exportada(` e não `conf_exportada()`: desde 22/09 ela recebe a fonte, que
# no ensaio é a CÓPIA com as escolhas dentro — e tem de ser o MESMO arquivo que o
# `install.sh` vai sourcear, senão a ponte resolve a paleta por um FLAVOR e o
# instalador lê outro.
if "conf_exportada(" not in _ini or "ambiente.update(conf)" not in _ini:
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

# --- 11. O COMANDO DA TELA COLA, E O QUE SE EXPORTA NÃO LEVA NOME — 24/09/2026 --
#   Revisão da P52. Dois defeitos que o `tests/app-completo.py` não via, porque a
#   casa de brinquedo dele não tem caminho entre aspas na gaveta nem fonte de
#   papel de parede fora do home:
#   11a. A gaveta trocava a casa por `~` DENTRO das aspas. O `wallpaper.sh`
#        imprime `meow wallpaper permitir "$fonte_atual"`, a gaveta mostrava
#        `permitir "~/Imagens/…"`, e colado o `~` não expandia: o `readlink -m`
#        gravava `/tmp/~/Imagens/…`, uma autorização que nunca casa. Aqui o texto
#        da tela é COLADO num bash de verdade, com a mesma casa, e o argumento
#        que chega tem de ser o caminho absoluto.
#   11b. A página exportada levava o valor de uma chave com caminho fora da
#        casa: `/run/media/<usuário>/…` saía duas vezes, no `valor` e no
#        `efetivo`. O nome de usuário aqui é inventado e único, para que achá-lo
#        em qualquer canto da página seja prova e não coincidência. E o
#        `WALLPAPER_BASE` num disco de fora, com uma foto no acervo: a pasta
#        voltava pela `origem` e pelo `banir` de cada foto da galeria.
#   A casa e o `meow.conf` são de brinquedo, e chegam pelo ambiente ANTES do
#   `import`: o `servidor.CONF` é lido uma vez, na carga do módulo.
_tmp11="$(mktemp -d)"
HOME="$_tmp11/casa" MEOW_CONF="$_tmp11/casa/.config/meow/meow.conf" MEOW_RAIZ="$RAIZ" \
  python3 - "$RAIZ" <<'PY' || falhas=$((falhas+1))
import os, subprocess, sys
raiz = sys.argv[1]
casa = os.environ["HOME"]
conf = os.environ["MEOW_CONF"]
os.makedirs(os.path.dirname(conf))
with open(os.path.join(raiz, "meow.conf.exemplo"), encoding="utf-8") as fh:
    exemplo = fh.read()
vazia = 'WALLPAPER_FONTES_PERMITIDAS=""'
if vazia not in exemplo:
    print("FALHOU: o meow.conf.exemplo não tem mais a linha %s" % vazia, file=sys.stderr)
    sys.exit(1)
sentinela = "meow-teste-sentinela"
base_velha = 'WALLPAPER_BASE="$HOME/.local/share/backgrounds/meowsystem"'
if base_velha not in exemplo:
    print("FALHOU: o meow.conf.exemplo não tem mais a linha %s" % base_velha, file=sys.stderr)
    sys.exit(1)
fora = os.path.join(os.path.dirname(casa), "disco", sentinela, "wallpapers")
os.makedirs(os.path.join(fora, "ativos"))
# Um PNG de 1x1: o acervo só lista arquivo com extensão de imagem.
with open(os.path.join(fora, "ativos", "gato.png"), "wb") as fh:
    fh.write(bytes.fromhex("89504e470d0a1a0a0000000d4948445200000001000000010806000000"
                           "1f15c4890000000d4944415478da63f8ffff3f0005fe02fea7d6a4"
                           "8f0000000049454e44ae426082"))
with open(conf, "w", encoding="utf-8") as fh:
    fh.write(exemplo.replace(vazia, 'WALLPAPER_FONTES_PERMITIDAS="$HOME/Imagens:/run/media/%s/HD"'
                             % sentinela)
             .replace(base_velha, 'WALLPAPER_BASE="%s"' % fora))
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor

erros = []
imagem = os.path.join(casa, "Imagens", "Parede_papel", "Cyberpunk Neon Cat.jpeg")
cache = os.path.join(casa, ".local", "share", "icons", "Meow", "icon-theme.cache")
for impresso, corte, alvo in (
        ('  meow wallpaper permitir "%s"' % imagem, " permitir ", imagem),
        ("  apague o arquivo: rm '%s'" % cache, " rm ", cache),
        ('  meow wallpaper permitir "%s"' % casa, " permitir ", casa)):
    tela = servidor.texto_na_tela(impresso)
    if casa in tela:
        erros.append("a casa ficou na tela: %r" % tela)
        continue
    colado = subprocess.run(["bash", "-c", 'printf "%s\\n" ' + tela.split(corte, 1)[1]],
                            capture_output=True, text=True, cwd="/").stdout
    if colado != alvo + "\n":
        erros.append("%r colado vira %r, e não o caminho da casa" % (tela.strip(), colado))
for vizinho in (casa + "zinho/x", "'%szinho/x'" % casa):
    if servidor.texto_na_tela(vizinho) != vizinho:
        erros.append("a casa comeu o vizinho: %r virou %r"
                     % (vizinho, servidor.texto_na_tela(vizinho)))

html, _ = servidor.Manipulador.__new__(servidor.Manipulador)._exportar_pagina()
if sentinela in html:
    erros.append("a página exportada leva o nome de usuário de uma fonte fora da casa "
                 "%d vez(es)" % html.count(sentinela))
if casa in html:
    erros.append("a página exportada leva a casa %d vez(es)" % html.count(casa))
if "$WALLPAPER_BASE/ativos/gato.png" not in html:
    erros.append("a foto do acervo de fora sumiu da página, em vez de sair sem a pasta")

if erros:
    print("FALHOU: " + "; ".join(erros), file=sys.stderr)
    sys.exit(1)
print("ok: o comando da gaveta cola com a casa entre aspas, e a página exportada não "
      "leva caminho de fora da casa")
PY
rm -rf "$_tmp11"

# --- 12. O RÓTULO DIZ O QUE A AÇÃO FEZ — 24/09/2026, sprint P50 ----------------
#   Os achados 11, 14, 15, 16, 17, 32, 33, 36 e 47 da validação no painel de
#   verdade, na parte que se prova sem navegador (o `tests/app-completo.py`
#   cobra a tela):
#   12a. Toda ação declara uma `natureza` que a tabela `NATUREZAS` conhece, e
#        o fim de cada uma diz o que ela fez: o reciclo não diz «já estava
#        certo», a troca não diz «consertou», o som diz «tocou», o 1 do
#        instalador (P48) não é verde, e o ensaio não diz verbo de quem fez.
#   12b. O nome de botão e de aba que um script cita sai da tabela `ACOES`
#        (`--onde`), e as duas frases escritas à mão sumiram do código.
#   12c. O botão sem efeito se apaga: o gato por horário ou girando, as áreas
#        sem alfinete — e o servidor recusa rodá-lo. E o «Pôr» aceso põe o
#        gato no dock de verdade.
#   12d. O raio: acima do teto de agora, o valor não é gravado.
#   Casa, conf, estado e COSMIC de brinquedo, antes do `import`: nada aqui lê
#   ou escreve a máquina de quem roda, a não ser a pergunta "o compositor
#   desta sessão tem o patch do raio?", que só lê o `/proc`.
_tmp12="$(mktemp -d)"
HOME="$_tmp12/casa" MEOW_CONF="$_tmp12/casa/.config/meow/meow.conf" \
MEOW_ESTADO="$_tmp12/casa/.local/state/meowsystem" \
MEOW_COSMIC_DIR="$_tmp12/casa/.config/cosmic" MEOW_RAIZ="$RAIZ" \
  python3 - "$RAIZ" <<'PY' || falhas=$((falhas+1))
import os, re, subprocess, sys, time
raiz = sys.argv[1]
casa = os.environ["HOME"]
conf = os.environ["MEOW_CONF"]
cosmic = os.environ["MEOW_COSMIC_DIR"]
os.makedirs(os.path.dirname(conf))
with open(os.path.join(raiz, "meow.conf.exemplo"), encoding="utf-8") as fh:
    exemplo = fh.read()
if not re.search(r'^LOGO_MODO="hora"', exemplo, re.M):
    print('FALHOU: o meow.conf.exemplo não tem mais LOGO_MODO="hora"', file=sys.stderr)
    sys.exit(1)


def conf_com(**chaves):
    texto = exemplo
    for k, v in chaves.items():
        texto, n = re.subn(r'^%s="[^"]*"' % k, '%s="%s"' % (k, v), texto, count=1, flags=re.M)
        if not n:
            texto += '\n%s="%s"\n' % (k, v)
    with open(conf, "w", encoding="utf-8") as fh:
        fh.write(texto)


conf_com()
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor

erros = []

# 12a. as naturezas
classes = {"ok", "correndo", "pula", "erro"}
for ident, acao in servidor.ACOES.items():
    nat = acao.get("natureza")
    if nat not in servidor.NATUREZAS:
        erros.append("a ação %s não declara uma natureza conhecida (%r)" % (ident, nat))
for nat, tabela in servidor.NATUREZAS.items():
    for cod, (classe, frase) in tabela.items():
        if classe not in classes or not frase or cod not in ("0", "0~", "1"):
            erros.append("a natureza %s tem a linha %s mal formada: %r" % (nat, cod, (classe, frase)))
fim = servidor.fim_da_acao
if not erros:
    if fim("painel_reciclar")["0"][1] == "já estava certo" or "0~" not in fim("painel_reciclar"):
        erros.append("«Recarregar o painel» ainda pode dizer «já estava certo» depois de reciclar")
    if "consert" in fim("wallpaper_proximo")["1"][1]:
        erros.append("«Próxima imagem» ainda termina dizendo que consertou")
    if fim("som_ouvir")["0"][1] != "tocou":
        erros.append("«Ouvir o som» não termina dizendo que tocou: %r" % (fim("som_ouvir")["0"],))
    if fim("instalar")["1"][0] == "ok":
        erros.append("o 1 do instalador (o tema que não chegou, P48) ainda é verde")
    if re.search(r"aplicou|consertou", fim("doctor_consertar")["0~"][1]):
        erros.append("o conserto que não consertou nada ainda diz que aplicou")
    for ident in servidor.ACOES:
        for cod, (_c, frase) in fim(ident, seco=True).items():
            if re.search(r"aplicou|consertou|trocou|gravou|tirou|devolveu|baixou|tocou|recarregou",
                         frase):
                erros.append("o ensaio de %s diz %r — num ensaio nada foi feito" % (ident, frase))
                break

# 12b. o nome que um script cita sai da tabela
acao = servidor.ACOES["doctor_consertar"]
esperado = "«%s», na aba %s" % (acao["rotulo"], acao["grupo"])
if servidor.onde_na_tela("doctor_consertar") != esperado:
    erros.append("--onde doctor_consertar diz %r, e não %r"
                 % (servidor.onde_na_tela("doctor_consertar"), esperado))
alvo = servidor.ACOES[servidor.ACAO_DA_PENDENCIA["areas-sem-alfinete"]]
if servidor.onde_na_tela("areas-sem-alfinete") != "«%s», na aba %s" % (alvo["rotulo"], alvo["grupo"]):
    erros.append("--onde de uma pendência não diz a ação dela")
oculta = next(k for k, a in servidor.ACOES.items() if a.get("oculta"))
if servidor.onde_na_tela(oculta) or servidor.onde_na_tela("nao-existe"):
    erros.append("--onde cita um botão que não tem cartão (%s) ou que não existe" % oculta)
# A pendência do tema de terceiro (P62): os DOIS botões que a Início desenha
# para ela, lidos da tabela da escolha — de um app com módulo, e de nenhum outro.
modulos = os.path.join(raiz, "assets", "temas-de-apps")
com_modulo = next(n for n in sorted(os.listdir(modulos))
                  if os.path.isfile(os.path.join(modulos, n, "manifesto.sh")))
onde = servidor.onde_na_tela(com_modulo + servidor.SUFIXO_TEMA_DE_TERCEIRO)
if not all("«%s»" % r in onde for _a, r in servidor.ESCOLHA_TEMA_DE_TERCEIRO) \
        or not onde.endswith("na aba %s" % servidor.ABA_INICIO):
    erros.append("--onde da pendência de tema de terceiro de %s não cita os botões da Início: %r"
                 % (com_modulo, onde))
if servidor.onde_na_tela("sem-modulo-nenhum" + servidor.SUFIXO_TEMA_DE_TERCEIRO):
    erros.append("--onde cita os botões do tema de terceiro para um app sem módulo")
porta = subprocess.run(["bash", "-c", '. "$1/lib/comum.sh"; meow_onde_no_painel doctor_consertar',
                        "_", raiz], capture_output=True, text=True, env=dict(os.environ))
if porta.stdout.strip() != esperado:
    erros.append("o meow_onde_no_painel do lib/comum.sh diz %r" % porta.stdout.strip())
# `--onde` com o número errado de argumentos não sobe o painel (revisão da
# P50: caía no `main()`). O `timeout` é a rede: se subir, morre aqui, na casa
# de brinquedo, e o teste diz.
for extra in ([], ["doctor", "instalar"]):
    try:
        r = subprocess.run([sys.executable, os.path.join(raiz, "app", "servidor.py"), "--onde"]
                           + extra, capture_output=True, text=True, timeout=20)
        if r.returncode != 2 or "http" in r.stdout:
            erros.append("--onde com %d argumento(s) não recusou: rc=%s %r"
                         % (len(extra), r.returncode, r.stdout[:80]))
    except subprocess.TimeoutExpired:
        erros.append("--onde com %d argumento(s) subiu o servidor" % len(extra))
for rel in ("scripts", "bin", "lib", "install.sh"):
    base = os.path.join(raiz, rel)
    arquivos = ([base] if os.path.isfile(base) else
                [os.path.join(d, n) for d, _s, ns in os.walk(base) for n in ns])
    for arq in arquivos:
        try:
            linhas = open(arq, encoding="utf-8").read().splitlines()
        except (OSError, UnicodeDecodeError):
            continue
        for n, l in enumerate(linhas, 1):
            if l.lstrip().startswith("#"):
                continue
            if "Instalar e conferir" in l or "«Resolver» no painel" in l:
                erros.append("nome de tela escrito à mão em %s:%d" % (os.path.relpath(arq, raiz), n))

# 12c. o botão sem efeito se apaga
conf_com(LOGO_MODO="hora")
trocar, girar = servidor.indisponivel("logo_trocar"), servidor.indisponivel("logo_girar")
if trocar != {"chave": "LOGO_MODO", "vale": "hora", "pede": "fixo"}:
    erros.append("com o gato por horário, «Pôr um gato no dock» não se apaga: %r" % (trocar,))
if not girar or girar.get("pede") != "rotacao":
    erros.append("com o gato por horário, «Passar ao próximo gato» não se apaga: %r" % (girar,))
trabalho, erro = servidor.iniciar("logo_trocar", "coquinha")
if trabalho is not None or not erro:
    if trabalho is not None:
        trabalho.parar()
    erros.append("o servidor rodou «Pôr um gato no dock» apagado")
conf_com(LOGO_MODO="fixo")
if servidor.indisponivel("logo_trocar") or not servidor.indisponivel("logo_girar"):
    erros.append("com o gato fixo, o «Pôr» tem de acender e o «Passar ao próximo» não")
# NA ROTAÇÃO O «PÔR» TAMBÉM SE APAGA — revisão da P50. Lá o `logo.sh` guarda o
# gato do acervo que já está no ar, e o `LOGO` é só o ponto de partida.
conf_com(LOGO_MODO="", LOGO_ROTACAO="sim")
trocar, girar = servidor.indisponivel("logo_trocar"), servidor.indisponivel("logo_girar")
if trocar != {"chave": "LOGO_MODO", "vale": "rotacao", "pede": "fixo"} or girar:
    erros.append("LOGO_ROTACAO=sim sem LOGO_MODO é o modo que gira (a regra do logo.sh): "
                 "o «Pôr» se apaga pedindo fixo, e o «Passar ao próximo» acende — "
                 "deu %r e %r" % (trocar, girar))
# ACESO É TER EFEITO, E NÃO SÓ `indisponivel() is None` — revisão da P50.
#   A primeira versão desta seção cobrava só que o botão acendia no `fixo`, e
#   o `logo.sh` desse modo guardava o gato que já estava no ar: o motivo
#   mandava a pessoa a um modo em que o botão continuava sem efeito. Aqui se
#   faz o caminho que o cartão ensina, na casa de brinquedo: o relógio põe o
#   mimir, a pessoa passa a «Fixo», e o «Pôr» roda o comando dele com a
#   Coquinha. Sem reciclar o painel (`LOGO_RECICLAR="nao"`), e com um
#   `notify-send` falso: a notificação do `meow logo` iria para a sessão de
#   quem roda o teste.
#   O APPLET DE LOGO INSTALADO, desde a P57, é o `.desktop` com
# `X-CosmicApplet=true` que o COSMIC acha (o `_applet_de_logo` do logo.sh), e
# não a pasta de configuração, que sobra quando ele sai: com só a pasta, esta
# casa não simulava applet nenhum (revisão da P57). As pastas de aplicativos
# são só as da casa, para um applet instalado em quem roda o teste não entrar.
applet = os.path.join(cosmic, "dev.cappsy.CosmicExtAppletLogoMenu", "v1")
os.makedirs(applet)
aplicativos = os.path.join(casa, ".local", "share", "applications")
os.makedirs(aplicativos, exist_ok=True)
with open(os.path.join(aplicativos, "dev.cappsy.CosmicExtAppletLogoMenu.desktop"), "w",
          encoding="utf-8") as fh:
    fh.write("[Desktop Entry]\nType=Application\nName=Logo Menu\nNoDisplay=true\n"
             "X-CosmicApplet=true\n")
falso = os.path.join(os.path.dirname(casa), "falso")
os.makedirs(falso)
with open(os.path.join(falso, "notify-send"), "w", encoding="utf-8") as fh:
    fh.write("#!/bin/sh\nexit 1\n")
os.chmod(os.path.join(falso, "notify-send"), 0o755)
ambiente = dict(os.environ, PATH=falso + os.pathsep + os.environ.get("PATH", ""),
                XDG_DATA_HOME=os.path.join(casa, ".local", "share"),
                XDG_DATA_DIRS=os.path.join(casa, "sem-pastas-do-sistema"))
logo_sh = os.path.join(raiz, "scripts", "logo.sh")
conf_com(LOGO_MODO="hora", LOGO_DIA="mimir", LOGO_NOITE="mimir", LOGO="mimir", LOGO_RECICLAR="nao")
subprocess.run(["bash", "-c", 'set -a; . "$1"; set +a; exec "$2" aplicar', "_", conf, logo_sh],
               capture_output=True, env=ambiente, timeout=60)
conf_com(LOGO_MODO="fixo", LOGO="mimir", LOGO_RECICLAR="nao")
botao = os.path.join(casa, ".local", "share", "icons", "MeowSystem-Icons", "scalable", "apps",
                     "com.system76.CosmicPanelAppButton.svg")
coquinha = os.path.join(cosmic, "logos", "meow-coquinha.svg")


def no_dock(caminho):
    try:
        with open(botao, "rb") as a, open(caminho, "rb") as b:
            return a.read() == b.read()
    except OSError:
        return False


if no_dock(coquinha) or not no_dock(os.path.join(cosmic, "logos", "meow-mimir.svg")):
    erros.append("a casa de brinquedo não começou com o mimir no dock")
elif servidor.indisponivel("logo_trocar"):
    erros.append("com o gato fixo, «Pôr um gato no dock» não acendeu")
else:
    argv = [a.replace("@ARG@", "coquinha") for a in servidor.ACOES["logo_trocar"]["argv"]]
    r = subprocess.run(argv, capture_output=True, text=True, env=ambiente, timeout=120)
    if r.returncode != 1 or not no_dock(coquinha):
        erros.append("no modo fixo, «Pôr um gato no dock» com a Coquinha não a pôs no dock "
                     "(rc=%s): %s" % (r.returncode, (r.stdout + r.stderr).strip()[-160:]))
    elif servidor.fim_da_acao("logo_trocar")["1"][1] != "trocou":
        erros.append("o fim do «Pôr» que trocou não diz «trocou»")
conf_com()
if (servidor.indisponivel("areas_aplicar") or {}).get("antes") != "areas_alfinetar_primeira":
    erros.append("sem área fixada, «Gravar as áreas» não manda antes a «Criar a primeira área»")
# O `.png` que é SVG (QA de uso real da P80) sai como SVG, e o leitor do
# começo do arquivo não volta atrás: 4 KB hostis respondem em menos de 50 ms
# (o alerta de ReDoS da revisão de segurança da P80).
# [P84, 15/10/2026: o `obsidian.png` saiu do pack, trocado pelo vetor dele. Os
#   bytes de um SVG de verdade continuam sendo o caso, agora os do `obsidian.svg`.]
import time as _t
svg_png = open(os.path.join(raiz, "packs", "dracula", "icones", "feitos-a-mao",
                            "obsidian.svg"), "rb").read()
casos = ((svg_png, True), (b"\x89PNG\r\n\x1a\n", False),
         (b'\xef\xbb\xbf<?xml version="1.0"?>\n<!-- a -->\n<!DOCTYPE svg>\n<svg xmlns="x"/>', True),
         (b"<svgx/>", False), (b"<!--" * 1000, False), (b"<!--a-->" * 500 + b"<x", False))
for dados, quer in casos:
    t0 = _t.monotonic()
    deu = servidor.comeca_como_svg(dados)
    if deu != quer or _t.monotonic() - t0 > 0.05:
        erros.append("comeca_como_svg(%r…) deu %s em %.0f ms" % (dados[:24], deu, (_t.monotonic() - t0) * 1000))
# O espelho (QA de uso real da P80): sem área, «Criar a primeira área» acende;
# com área fixada, ela se apaga e aponta «Gravar as áreas».
if servidor.indisponivel("areas_alfinetar_primeira"):
    erros.append("sem área fixada, «Criar a primeira área» nasceu apagada")
pinos = os.path.join(cosmic, "com.system76.CosmicComp", "v1")
os.makedirs(pinos)
with open(os.path.join(pinos, "pinned_workspaces"), "w", encoding="utf-8") as fh:
    fh.write('[\n    (\n        output: (\n            name: "DP-1",\n            edid: None,\n'
             '        ),\n        tiling_enabled: false,\n        id: Some("c0ffee"),\n'
             '        name: Some("Brinquedo"),\n    ),\n]\n')
if servidor.indisponivel("areas_aplicar"):
    erros.append("com uma área fixada, «Gravar as áreas» continua apagado")
if (servidor.indisponivel("areas_alfinetar_primeira") or {}).get("feito") != "areas_aplicar":
    erros.append("com uma área fixada, «Criar a primeira área» segue acesa, e só podia não fazer nada")
# E a pendência velha da falta de área some da lista (o «Resolver» dela só
# ouviria a recusa); a outra pendência, de conserto que ainda vale, fica.
os.makedirs(os.path.dirname(servidor.PENDENCIAS), exist_ok=True)
with open(servidor.PENDENCIAS, "w", encoding="utf-8") as fh:
    fh.write("areas-sem-alfinete\tareas\tSem área fixada\tmeow areas alfinetar-primeira\t2026-10-10T00:00:00-03:00\n"
             "starship-ausente\tprompt\tSem starship\tmeow prompt starship\t2026-10-10T00:00:00-03:00\n")
vistas = [p["id"] for p in servidor.pendencias()]
if "areas-sem-alfinete" in vistas:
    erros.append("com área fixada, a pendência «areas-sem-alfinete» continua na lista: %r" % vistas)
if "starship-ausente" not in vistas:
    erros.append("a pendência que ainda vale sumiu junto: %r" % vistas)
os.remove(servidor.PENDENCIAS)

# 12d. o teto do raio
dock = os.path.join(cosmic, "com.system76.CosmicPanel.Dock", "v1")
os.makedirs(dock)
for nome, valor in (("size", "L"), ("padding", "4")):
    with open(os.path.join(dock, nome), "w", encoding="utf-8") as fh:
        fh.write(valor)
medida = servidor.teto_do_raio()
if "Dock" not in medida or medida.get("compositor") not in ("clampa", "pendente", "sem"):
    erros.append("o teto do raio não saiu do lib/painel.sh: %r" % (medida,))
if "Panel" in medida or servidor.teto_da_chave("FORMA_RAIO_PAINEL"):
    erros.append("a barra sem pasta no COSMIC ganhou teto: %r" % (medida,))
item = next(i for i in servidor.ler_esquema() if i["chave"] == "FORMA_RAIO_DOCK")
for estado, recusa in ((dict(Dock=0, compositor="sem", experimental=False), True),
                       (dict(Dock=0, compositor="pendente", experimental=False), True),
                       (dict(Dock=36, compositor="clampa", experimental=False), False),
                       (dict(Dock=0, compositor="sem", experimental=True), False)):
    servidor._TETO_CACHE.update(quando=time.time(), valor=estado)
    queixa = servidor.validar_valor(item, "16")
    if bool(queixa) != recusa:
        erros.append("com %r, 16 no raio da dock %s" % (estado, "passou" if recusa else
                                                       "foi recusado: %s" % queixa))
    if servidor.validar_valor(item, "0") or servidor.validar_valor(item, ""):
        erros.append("com %r, o 0 ou o vazio foram recusados" % (estado,))
    teto = servidor.teto_da_chave("FORMA_RAIO_DOCK")
    if not teto or not teto["motivo"] or teto["trava"] != recusa:
        erros.append("com %r, o cartão não diz o teto e o porquê: %r" % (estado, teto))

if erros:
    print("FALHOU: " + "; ".join(erros), file=sys.stderr)
    sys.exit(1)
print("ok: cada ação declara a natureza e o fim diz o que ela fez; o nome de tela sai "
      "da tabela; o botão sem efeito se apaga; o raio não passa do teto de agora")
PY
rm -rf "$_tmp12"

# --- 13. AS REGRAS QUE AINDA MENTIAM — 24/09/2026, sprint P57 -----------------
#   Quatro regras que diziam uma coisa e faziam outra, cada uma com a prova que
#   reprova o código de antes (o item 1, o flatpak, mora no
#   `tests/temas-de-apps.sh`; o 2, a corrida da gaveta, no `app-navegador.py`):
#   13a. O nome da ficha é o que o lançador mostra: o `Name[...]` da cadeia de
#        idioma da sessão, e não o `Name=` cru (item 3).
#   13b. O `--onde` cobre cartões e abas, e as frases do `install.sh` que citam
#        um lugar do painel saem dele (item 4).
#   13c. O `logo.sh`: o applet de logo é o que está instalado, o aviso do modo
#        fixo diz o que acontece, e o gato do terminal acompanha o do dock em
#        todo modo (item 5).
#   13d. Uma leitura do esquema mede cada fato da máquina uma vez, e não uma
#        vez por chave (item 6).
#   13e. A torrada do «Adicionar» não leva o caminho do clone (a revisão: o
#        esquema rápido do item 6 deixou à vista um vazamento antigo).
#   Casa, conf, estado e COSMIC de brinquedo, como na 12.
_tmp13="$(mktemp -d)"
HOME="$_tmp13/casa" MEOW_CONF="$_tmp13/casa/.config/meow/meow.conf" \
MEOW_ESTADO="$_tmp13/casa/.local/state/meowsystem" \
MEOW_COSMIC_DIR="$_tmp13/casa/.config/cosmic" MEOW_RAIZ="$RAIZ" \
  python3 - "$RAIZ" <<'PY' || falhas=$((falhas+1))
import collections, glob, os, re, shutil, subprocess, sys
raiz = sys.argv[1]
casa = os.environ["HOME"]
conf = os.environ["MEOW_CONF"]
cosmic = os.environ["MEOW_COSMIC_DIR"]
os.makedirs(os.path.dirname(conf))
with open(os.path.join(raiz, "meow.conf.exemplo"), encoding="utf-8") as fh:
    exemplo = fh.read()
IDIOMA = ("LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG")


def conf_com(**chaves):
    texto = exemplo
    for k, v in chaves.items():
        texto, n = re.subn(r'^%s="[^"]*"' % k, '%s="%s"' % (k, v), texto, count=1, flags=re.M)
        if not n:
            texto += '\n%s="%s"\n' % (k, v)
    with open(conf, "w", encoding="utf-8") as fh:
        fh.write(texto)


def idioma(**amb):
    """Troca a cadeia de idioma deste processo por `amb`; devolve a de antes."""
    antes = {k: os.environ.pop(k, None) for k in IDIOMA}
    os.environ.update(amb)
    return antes


conf_com()
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor

erros = []
aplicativos = os.path.join(casa, ".local", "share", "applications")
os.makedirs(aplicativos)


def desktop(ident, corpo):
    with open(os.path.join(aplicativos, ident + ".desktop"), "w", encoding="utf-8") as fh:
        fh.write("[Desktop Entry]\nType=Application\nExec=true\n" + corpo)


# 13a. o nome da ficha
#   Três programas: um com as duas traduções (e uma ação com nome próprio, que
#   não pode vazar para o do programa), um só com a do português de Portugal, e
#   um sem nenhuma. A regra é a da especificação: `lang_PAÍS@MOD`, `lang_PAÍS`,
#   `lang@MOD`, `lang`, e o `Name=` por último; a cadeia é a do `LANGUAGE` e
#   depois a do primeiro de `LC_ALL`, `LC_MESSAGES` e `LANG`.
desktop("com.exemplo.Ajustes", "Name=Settings\nName[pt]=Definições\nName[pt_BR]=Configurações\n"
        "\n[Desktop Action nova]\nName=New window\nName[pt_BR]=Outra janela\n")
desktop("com.exemplo.Camara", "Name=Camera\nName[pt]=Câmara\n")
desktop("com.exemplo.Fontes", "Name=Fonts\n")
m = servidor.Manipulador.__new__(servidor.Manipulador)
for amb, quer in ((dict(LANG="pt_BR.UTF-8"), ["Configurações", "Câmara", "Fonts"]),
                  (dict(LANG="pt_PT.UTF-8"), ["Definições", "Câmara", "Fonts"]),
                  (dict(LANG="C.UTF-8"), ["Settings", "Camera", "Fonts"]),
                  (dict(LANG="en_US.UTF-8", LANGUAGE="pt_BR:en"),
                   ["Configurações", "Câmara", "Fonts"]),
                  (dict(LANG="pt_BR.UTF-8", LC_MESSAGES="en_US.UTF-8"),
                   ["Settings", "Camera", "Fonts"]),
                  (dict(LANG="en_US.UTF-8", LC_ALL="pt_BR.UTF-8"),
                   ["Configurações", "Câmara", "Fonts"])):
    antes = idioma(**amb)
    try:
        por_id = {d["id"]: d["nome"] for d in m._desktops()}
    finally:
        idioma(**{k: v for k, v in antes.items() if v is not None})
    tem = [por_id.get(i) for i in ("com.exemplo.Ajustes", "com.exemplo.Camara",
                                   "com.exemplo.Fontes")]
    if tem != quer:
        erros.append("13a: com %s as fichas dizem %s, e o lançador diria %s" % (amb, tem, quer))
# E a ficha de «Quais programas o lançador esconde» (P54) diz o mesmo nome: um
# id da lista de fábrica, com o `.desktop` da casa vencendo o do sistema.
desktop("nm-connection-editor", "Name=Advanced Network Configuration\n"
        "Name[pt_BR]=Configuração avançada de rede\n")
# E O BOTÃO «Abrir no …» DA OFICINA TAMBÉM — revisão da P57. Ele tinha um
# leitor próprio do `Name=` cru e, na mesma tela da grade, era quem misturava o
# nome traduzido de um aplicativo com o original de outro. O editor que o
# `xdg-mime` aponta é um de brinquedo, e o `xdg-open` falso é só para haver
# com que abrir.
bin_editor = os.path.join(os.path.dirname(casa), "bin-editor")
os.makedirs(bin_editor)
for prog, corpo in (("xdg-mime", "echo com.exemplo.Editor.desktop"), ("xdg-open", "exit 0")):
    with open(os.path.join(bin_editor, prog), "w", encoding="utf-8") as fh:
        fh.write("#!/bin/sh\n%s\n" % corpo)
    os.chmod(os.path.join(bin_editor, prog), 0o755)
desktop("com.exemplo.Editor", "Name=Vector Editor\nName[pt_BR]=Editor de vetores\n"
        "MimeType=image/svg+xml;\n")
caminho_antes = os.environ["PATH"]
antes = idioma(LANG="pt_BR.UTF-8")
os.environ["PATH"] = bin_editor + os.pathsep + caminho_antes
servidor._EDITOR_SVG = None
try:
    editor = m._editor_de_svg()
finally:
    os.environ["PATH"] = caminho_antes
    servidor._EDITOR_SVG = None
    idioma(**{k: v for k, v in antes.items() if v is not None})
if editor != {"tem": True, "nome": "Editor de vetores"}:
    erros.append("13a: o botão do editor de SVG diz %r, e a grade diria «Editor de vetores»"
                 % (editor,))

# 13b. o --onde e as frases do install.sh
esquema = servidor.ler_esquema()
lanc = next(i for i in esquema if i["chave"] == "LANCADOR_SISTEMA")
quer = "«%s», na aba %s" % (lanc["titulo"], lanc["secao"])
if servidor.onde_na_tela("LANCADOR_SISTEMA") != quer:
    erros.append("13b: --onde LANCADOR_SISTEMA diz %r, e o cartão é %s"
                 % (servidor.onde_na_tela("LANCADOR_SISTEMA"), quer))
porta = subprocess.run(["bash", "-c", '. "$1/lib/comum.sh"; meow_onde_no_painel LANCADOR_SISTEMA',
                        "_", raiz], capture_output=True, text=True, env=dict(os.environ))
if porta.stdout.strip() != quer:
    erros.append("13b: o meow_onde_no_painel de um cartão diz %r" % porta.stdout.strip())
sem_titulo = next((i["chave"] for i in esquema if not i.get("titulo")), None)
if sem_titulo and servidor.onde_na_tela(sem_titulo):
    erros.append("13b: --onde inventa um cartão para %s, que não tem título escrito" % sem_titulo)
inicio = getattr(servidor, "ABA_INICIO", None)
if not inicio or servidor.onde_na_tela("inicio") != "na aba %s" % inicio:
    erros.append("13b: --onde inicio não diz a aba que abre o painel: %r"
                 % servidor.onde_na_tela("inicio"))
with open(os.path.join(raiz, "app", "pagina", "app.js"), encoding="utf-8") as fh:
    if not re.search(r'tipo:\s*"home",\s*nome:\s*ESQUEMA\.aba_inicio\b', fh.read()):
        erros.append("13b: a página não tira o nome da Início do esquema — são dois donos do nome")
# O NOME DE TELA NUMA FRASE DO install.sh, DERIVADO E NÃO LISTADO: todo título
# de cartão e rótulo de ação citado entre aspas numa linha que fala do painel,
# e todo nome de aba depois da palavra «aba». O `passo "Ícones resgatados do
# PNG"` não conta: é o nome da etapa, e a linha não fala do painel.
nomes = ({i["titulo"] for i in esquema if i.get("titulo")}
         | {a["rotulo"] for a in servidor.ACOES.values() if not a.get("oculta")})
abas = ({i["secao"] for i in esquema if i.get("secao")}
        | {a["grupo"] for a in servidor.ACOES.values() if not a.get("oculta")}
        | {inicio or "Início"})
with open(os.path.join(raiz, "install.sh"), encoding="utf-8") as fh:
    instalador = fh.read()
for n, linha in enumerate(instalador.splitlines(), 1):
    if linha.lstrip().startswith("#"):
        continue
    citados = [x for x in nomes
               if "painel" in linha and ("«%s»" % x in linha or '"%s"' % x in linha)]
    citados += ["aba " + x for x in abas
                if re.search(r"\baba\s+[«\"]?%s(?!\w)" % re.escape(x), linha)]
    if citados:
        erros.append("13b: install.sh:%d escreve à mão %s" % (n, ", ".join(sorted(citados))))
for ident in ("LANCADOR_SISTEMA", "inicio", "desfazer"):
    if "meow_onde_no_painel %s" % ident not in instalador:
        erros.append("13b: o install.sh não pergunta ao --onde onde fica %s" % ident)

# 13c. o logo.sh
logo_sh = os.path.join(raiz, "scripts", "logo.sh")
falso = os.path.join(os.path.dirname(casa), "falso")
os.makedirs(falso)
with open(os.path.join(falso, "notify-send"), "w", encoding="utf-8") as fh:
    fh.write("#!/bin/sh\nexit 1\n")
os.chmod(os.path.join(falso, "notify-send"), 0o755)
# As pastas de aplicativos são só as da casa (revisão da P57): a «máquina sem
# applet» logo abaixo não pode depender de quem roda o teste não ter um.
ambiente = dict(os.environ, PATH=falso + os.pathsep + os.environ.get("PATH", ""), NO_COLOR="1",
                XDG_DATA_HOME=os.path.join(casa, ".local", "share"),
                XDG_DATA_DIRS=os.path.join(casa, "sem-pastas-do-sistema"))
logos = os.path.join(cosmic, "logos")
botao = os.path.join(casa, ".local", "share", "icons", "MeowSystem-Icons", "scalable", "apps",
                     "com.system76.CosmicPanelAppButton.svg")


def logo(**chaves):
    conf_com(LOGO_RECICLAR="nao", **chaves)
    r = subprocess.run(["bash", "-c", 'set -a; . "$1"; set +a; exec "$2" aplicar', "_", conf,
                        logo_sh], capture_output=True, text=True, env=ambiente, timeout=180)
    return r.stdout + r.stderr


def no_dock():
    for caminho in sorted(glob.glob(os.path.join(logos, "meow-*.svg"))):
        with open(caminho, "rb") as a:
            try:
                with open(botao, "rb") as b:
                    if a.read() == b.read():
                        return os.path.basename(caminho)[len("meow-"):-len(".svg")]
            except OSError:
                return None
    return None


def ler(caminho):
    try:
        with open(caminho, encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return None


# A MÁQUINA SEM APPLET, COM A SOBRA DE UM: a pasta de configuração do
# `co.uk.cappsy`, apontando para uma imagem que não é do acervo — o retrato
# desta máquina em 24/09/2026, onde nenhum applet de logo está instalado.
sobra = os.path.join(cosmic, "co.uk.cappsy.CosmicAppletLogoMenu", "v1", "custom_logo_path")
os.makedirs(os.path.dirname(sobra))
de_outro = '"%s"' % os.path.join(logos, "de-outro.png")
with open(sobra, "w", encoding="utf-8") as fh:
    fh.write(de_outro)
logo(LOGO_MODO="hora", LOGO_DIA="mimir", LOGO_NOITE="mimir", LOGO="mimir")
saida = logo(LOGO_MODO="fixo", LOGO="gato-de-fora")
if no_dock() != "mimir":
    erros.append("13c: no modo fixo, um LOGO fora do acervo trocou o gato do dock por %s — "
                 "o aviso promete que fica o que está no ar" % no_dock())
aviso = next((l for l in saida.splitlines() if 'LOGO="gato-de-fora"' in l), "")
if "mimir" not in aviso:
    erros.append("13c: o aviso do LOGO fora do acervo não diz o gato que ficou: %r" % aviso)
if ler(sobra) != de_outro:
    erros.append("13c: o logo.sh escreveu na configuração de um applet que não está instalado")
# O APPLET INSTALADO é o que o COSMIC acha como applet: um `.desktop` com
# `X-CosmicApplet=true`. É a pasta DELE que recebe o gato, e a sobra do outro
# nome, sem nada instalado, fica como está.
desktop("co.uk.cappsy.CosmicAppletLogoMenu", "Name=Logo Menu\nNoDisplay=true\nX-CosmicApplet=true\n")
dev = os.path.join(cosmic, "dev.cappsy.CosmicExtAppletLogoMenu", "v1")
os.makedirs(dev)
logo(LOGO_MODO="fixo", LOGO="coquinha")
if ler(sobra) != '"%s"' % os.path.join(logos, "meow-coquinha.svg"):
    erros.append("13c: com o co.uk.cappsy instalado, o gato não foi para a chave dele: %r"
                 % ler(sobra))
if os.path.exists(os.path.join(dev, "custom_logo_path")):
    erros.append("13c: o logo.sh escreveu na pasta do dev.cappsy, que não está instalado")
# E QUEM MOSTRA A CHAVE PERGUNTA AO `logo.sh` — revisão da P57. O `meow logo`
# e o `meow status` liam a do `dev.cappsy` pelo nome. Com o co.uk.cappsy
# instalado e o gato na chave dele, e uma chave velha sobrando na pasta do
# dev.cappsy, o «arquivo» do `meow logo` é a do instalado.
with open(os.path.join(dev, "custom_logo_path"), "w", encoding="utf-8") as fh:
    fh.write('"%s"' % os.path.join(logos, "de-outro.svg"))
r = subprocess.run([os.path.join(raiz, "bin", "meow"), "logo"], capture_output=True, text=True,
                   env=ambiente, timeout=60)
linha = next((l for l in r.stdout.splitlines() if "arquivo" in l), "")
if "meow-coquinha.svg" not in linha:
    erros.append("13c: o «arquivo» do `meow logo` não é a chave do applet instalado: %r" % linha)
# O GATO DO TERMINAL VAI JUNTO NO MODO FIXO: com `FASTFETCH_LOGO_MODO=espelho`
# (o de fábrica) ele é o seguinte do acervo depois do que está no dock. A
# conversão para o terminal precisa do rsvg-convert e do ImageMagick.
if all(shutil.which(p) for p in ("rsvg-convert", "convert")):
    # A ORDEM É A DO `_ffl_o_outro`: o `sort` em C do nome COM o `.svg` — o
    # `-` vem antes do `.`, e o `morcego.svg` fica depois dos outros dois
    # morcegos (revisão da P57; sem a extensão ele vinha antes).
    nomes_gatos = [n[:-len(".svg")] for n in sorted(
        os.path.basename(p) for p in glob.glob(os.path.join(raiz, "assets", "gatos", "*.svg"))
        if not p.endswith("-symbolic.svg"))]
    espelho = nomes_gatos[(nomes_gatos.index("coquinha") + 1) % len(nomes_gatos)]
    carimbo = (ler(os.path.join(casa, ".local", "share", "meowsystem", "fastfetch", ".gato-atual"))
               or "").split(" ")[0]
    if no_dock() != "coquinha" or carimbo != espelho:
        erros.append("13c: no modo fixo, o dock foi para %s e o terminal ficou com %r — o "
                     "espelho pede %s" % (no_dock(), carimbo, espelho))
    # E COM UM GATO CUJO SVG TERMINA EM QUEBRA DE LINHA — revisão da P57. O
    # botão do dock é a cópia que o `logo.sh` grava, sem a quebra do fim, e o
    # espelho que comparava o botão com o `.svg` cru não achava gato nenhum no
    # dock: caía na fase. Os três morcegos do acervo são assim, e a coquinha
    # de cima não é. O gato sai do acervo, e não de um nome escrito aqui; o
    # `LOGO_DIA` e o `LOGO_NOITE` são ele mesmo, para que cair na fase dê o
    # gato do dock no terminal a qualquer hora.
    com_quebra = []
    for n in nomes_gatos:
        with open(os.path.join(raiz, "assets", "gatos", n + ".svg"), "rb") as fh:
            if fh.read().endswith(b"\n"):
                com_quebra.append(n)
    if com_quebra:
        gato = com_quebra[0]
        logo(LOGO_MODO="fixo", LOGO=gato, LOGO_DIA=gato, LOGO_NOITE=gato)
        espelho = nomes_gatos[(nomes_gatos.index(gato) + 1) % len(nomes_gatos)]
        carimbo = (ler(os.path.join(casa, ".local", "share", "meowsystem", "fastfetch",
                                    ".gato-atual")) or "").split(" ")[0]
        if no_dock() != gato or carimbo != espelho:
            erros.append("13c: com %s (o SVG termina em quebra de linha) no dock, o terminal "
                         "ficou com %r — o espelho pede %s" % (no_dock(), carimbo, espelho))
    else:
        print("pulado: 13c, o gato cujo SVG termina em quebra de linha — nenhum no acervo")
    # E NO MODO HORA, O OUTRO DO PAR — 25/09/2026, decisão depois da P57. Com o
    # dock no `LOGO_DIA` ou no `LOGO_NOITE`, o terminal mostra o outro gato do
    # par, e não o seguinte do acervo. O par sai do acervo, escolhido para que
    # o seguinte do gato da noite NÃO seja o do dia: senão as duas regras dariam
    # o mesmo gato e o teste não separaria uma da outra. A noite é o dia inteiro
    # (início igual ao fim); o dia é uma janela de noite que começa daqui a 2 h.
    if len(nomes_gatos) >= 3:
        import datetime
        dia, noite = nomes_gatos[0], nomes_gatos[1]
        agora = datetime.datetime.now()
        longe = [(agora + datetime.timedelta(hours=h)).strftime("%H:%M") for h in (2, 3)]
        for fase, janela, no_dock_esperado, no_terminal in (
                ("noite", ("00:00", "00:00"), noite, dia),
                ("dia", tuple(longe), dia, noite)):
            logo(LOGO_MODO="hora", LOGO_DIA=dia, LOGO_NOITE=noite,
                 NOITE_INICIO=janela[0], NOITE_FIM=janela[1])
            carimbo = (ler(os.path.join(casa, ".local", "share", "meowsystem", "fastfetch",
                                        ".gato-atual")) or "").split(" ")[0]
            if no_dock() != no_dock_esperado or carimbo != no_terminal:
                erros.append("13c: no modo hora, de %s, o dock ficou com %s e o terminal com %r "
                             "— o outro do par é %s" % (fase, no_dock(), carimbo, no_terminal))
            # E O RETRATO DA INÍCIO DIZ O GATO DO DOCK, e não a `LOGO` (25/09/2026,
            # validação final: «Logo Coquinha» com o morcego-noite no dock). O
            # servidor é importado num processo à parte, com esta casa e este conf.
            r = subprocess.run([sys.executable, "-c",
                                "import sys; sys.path.insert(0, sys.argv[1]); import servidor; "
                                "print(servidor._gato_no_dock())",
                                os.path.join(raiz, "app")],
                               capture_output=True, text=True, env=ambiente, timeout=60)
            if r.stdout.strip() != no_dock_esperado:
                erros.append("13c: de %s, o esquema diz o gato do dock %r — o dock tem %s"
                             % (fase, r.stdout.strip() or r.stderr.strip()[-160:], no_dock_esperado))
        with open(os.path.join(raiz, "app", "pagina", "app.js"), encoding="utf-8") as fh:
            if "const gatoNome = ESQUEMA.gato_no_dock ||" not in fh.read():
                erros.append("13c: o retrato da Início não lê o gato do dock (ESQUEMA.gato_no_dock)")
    else:
        print("pulado: 13c, o outro do par no modo hora — o acervo tem menos de três gatos")
else:
    print("pulado: 13c, o gato do terminal — falta rsvg-convert ou o convert do ImageMagick")

# 13d. uma leitura do esquema mede cada fato uma vez
#   Medido em 24/09/2026, numa casa de brinquedo: 2,2 s por leitura, e 69
#   chaves perguntavam de novo quais ponteiros estão instalados, cada uma
#   refazendo a adoção do pack (a validação inteira do pack) e rodando o bash
#   que lê o meow.conf. A mesma pergunta, com a mesma resposta, dentro de uma
#   leitura só. A régua é o que se repete: a adoção com os mesmos argumentos, e
#   o mesmo comando de subprocesso.
mod = servidor.modulo_pack()
feitas = collections.Counter()
adocao, rodar = mod.adocao, servidor.subprocess.run


def contar_adocao(*a, **k):
    feitas[("adocao",) + tuple(a)] += 1
    return adocao(*a, **k)


def contar_rodar(argv, *a, **k):
    feitas[tuple(argv)] += 1
    return rodar(argv, *a, **k)


antes = idioma(LANG="pt_BR.UTF-8")
mod.adocao, servidor.subprocess.run = contar_adocao, contar_rodar
try:
    dados = servidor.Manipulador.__new__(servidor.Manipulador)._dados_esquema()
finally:
    mod.adocao, servidor.subprocess.run = adocao, rodar
    idioma(**{k: v for k, v in antes.items() if v is not None})
repetidas = sorted((n, " ".join(str(x) for x in k).replace("\n", " ")[:90])
                   for k, n in feitas.items() if n > 1)
if repetidas:
    erros.append("13d: uma leitura do esquema repetiu %d pergunta(s) — a pior %d vezes: %s"
                 % (len(repetidas), repetidas[-1][0], repetidas[-1][1]))
if dados.get("aba_inicio") != inicio or not inicio:
    erros.append("13b: o esquema não manda à página o nome da Início (%r)" % dados.get("aba_inicio"))
ficha = next((i for i in dados["chaves"] if i["chave"] == "LANCADOR_OCULTAR"), {})
nome = ((ficha.get("programas") or {}).get("nm-connection-editor") or {}).get("nome")
if nome != "Configuração avançada de rede":
    erros.append("13a: a ficha de «Quais programas o lançador esconde» diz %r" % nome)

# 13e. a torrada do «Adicionar» não leva a casa nem o clone — revisão da P57
#   O gate reprovou a aba Terminal nesta sprint: a torrada do «Adicionar fonte»
#   mostra as três últimas linhas do `meow fontes adicionar`, e a última diz
#   «o acervo é <clone>/assets/fontes/locais». O vazamento é antigo; com o
#   esquema lento a torrada morria antes da conta do fim da aba. O comando
#   aqui é de mentira — um `subprocess.run` que devolve a saída de lá —, para o
#   teste não gravar fonte no acervo do clone de verdade.
class Rodado:
    returncode = 1
    stdout = ("  ~~   'brinquedo.ttf' instalada\n  >> copiada de %s/Downloads/brinquedo.ttf\n"
              "  >> 1 face(s) instalada(s) — o acervo é %s/assets/fontes/locais\n" % (casa, raiz))
    stderr = ""


respostas = []
m._json = lambda dados, status=200: respostas.append(dados)
servidor.subprocess.run = lambda *a, **k: Rodado()
try:
    m._acervo_por_comando(servidor.Manipulador.ACERVOS["fonte"], "brinquedo.ttf",
                          {"conteudo": "Zm9udGU="})
finally:
    servidor.subprocess.run = rodar
    del m._json
log = (respostas or [{}])[0].get("log", "")
if raiz in log or casa in log or "o acervo é ./assets/fontes/locais" not in log \
        or "~/Downloads/brinquedo.ttf" not in log:
    erros.append("13e: a torrada do «Adicionar fonte» leva %r" % log)

if erros:
    print("FALHOU: " + "\n  ".join(erros), file=sys.stderr)
    sys.exit(1)
print("ok: a ficha diz o nome do lançador, o --onde cobre cartão e aba, o logo.sh diz o que "
      "faz e o terminal segue o dock, o esquema mede cada fato uma vez, e a torrada do "
      "«Adicionar» não leva o clone")
PY
rm -rf "$_tmp13"

# --- 13b. A TRAVA DO PACK CABE NO BALÃO — P82, item 21 --------------------------
#   A frase do porquê de um desenho do pack não valer num app (a `trava_pack`)
#   vai para o balão do desenho, e passava do teto de 80 do balão: saía cortada
#   (a 375 px e em qualquer largura). As quatro formas dela, com um nome de app
#   comprido, cabem no teto.
_trava="$(env -i PATH="$PATH" HOME="$(mktemp -d)" python3 -I - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
m = servidor.Manipulador.__new__(servidor.Manipulador)
nome = "Visualizador de documentos do GNOME"
d = {"id": "x", "icone": "x"}
nada = (set(), (), set(), set())
frases = [
    m._trava_do_pack({"id": "x", "icone": "/opt/x/icone.png"}, nome, donos=set(), travas=nada),
    m._trava_do_pack(d, nome, donos={"x"}, travas=nada),
    m._trava_do_pack(d, nome, donos=set(), travas=({"x"}, (), set(), set())),
    m._trava_do_pack(d, nome, donos=set(), travas=(set(), (), {"x"}, set())),
]
for f in frases:
    print("%d\t%s" % (len(f or ""), f))
PY
)"
_compridas="$(awk -F'\t' '$1 > 80 || $1 == 0' <<< "$_trava")"
if [ -z "$_compridas" ] && [ "$(grep -c . <<< "$_trava")" = 4 ]; then
  echo "ok: as quatro frases da trava do pack cabem no balão (até 80), com um nome de app comprido"
else
  echo "FALHOU: frase da trava do pack acima do teto do balão (80): $_compridas" >&2
  falhas=$((falhas+1))
fi

# --- 14. O LANÇADOR DE FÁBRICA NÃO ESCONDE APP DE QUEM USA — P82, item 11 ------
#   O `LANCADOR_OCULTAR` do exemplo escondia o `google-chrome`, o `steam` e o
#   `github-desktop`: duplicatas desta máquina, e não programas de sistema
#   (decisão 17). O conf dela já os tem e não muda.
_lo="$(sed -n 's/^LANCADOR_OCULTAR="\(.*\)"$/\1/p' "$RAIZ/meow.conf.exemplo" | tr ',' '\n')"
_errados="$(grep -xE 'google-chrome|steam|github-desktop' <<< "$_lo")"
if [ -z "$_errados" ] && [ -n "$_lo" ]; then
  echo "ok: o LANCADOR_OCULTAR de fábrica não esconde o Chrome, a Steam nem o GitHub Desktop"
else
  echo "FALHOU: o LANCADOR_OCULTAR de fábrica esconde app de quem usa: $(echo $_errados)" >&2
  falhas=$((falhas+1))
fi

# --- 15. A NOITE NÃO GRAVA COM UMA PONTA SÓ — P82, item 27 (decisão 26) -------
#   O `meow_noite_janela` pede `NOITE_INICIO` e `NOITE_FIM` juntas, e o arquivo
#   aceitava uma só. O `/api/definir` e o `/api/salvar` recusam com 409 o pedido
#   que deixaria a ponta solta; as duas, nenhuma, ou a que completa a do disco
#   passam. O `definir` e o resto do salvar não rodam aqui: a recusa vem antes.
_tmp15="$(mktemp -d)"
_noite="$(env -i PATH="$PATH" HOME="$_tmp15" MEOW_CONF="$_tmp15/meow.conf" python3 -I - "$RAIZ/app" <<'PY' 2>&1
import json, sys
sys.path.insert(0, sys.argv[1])
import servidor
open(servidor.CONF, "w").write('NOITE_INICIO=""\nNOITE_FIM=""\n')
m = servidor.Manipulador.__new__(servidor.Manipulador)
respostas = []
m._json = lambda dados, status=200: respostas.append((status, dados))
def _gravou(*a, **k):
    raise AssertionError("gravou")
servidor.definir = servidor.definir_varias = servidor.iniciar = _gravou
erros = []
for rota, corpo in (("/api/definir", {"chave": "NOITE_INICIO", "valor": "19:00"}),
                    ("/api/salvar", {"mudancas": {"NOITE_FIM": "06:00"}})):
    respostas.clear()
    try:
        m._api_post(rota, corpo)
    except AssertionError as e:
        erros.append("%s %s" % (rota, e))
        continue
    st = respostas[0][0] if respostas else None
    if st != 409:
        erros.append("%s com uma ponta deu %s" % (rota, st))
f = servidor.pontas_da_noite_soltas
casos = [({"NOITE_INICIO": "19:00", "NOITE_FIM": "06:00"}, {}, 0),
         ({"NOITE_INICIO": "", "NOITE_FIM": ""}, {"NOITE_INICIO": "19:00"}, 0),
         ({"NOITE_FIM": "06:00"}, {"NOITE_INICIO": "19:00"}, 0),
         ({"NOITE_FIM": ""}, {"NOITE_INICIO": "19:00", "NOITE_FIM": "06:00"}, 1),
         ({"LOG_NIVEL": "info"}, {"NOITE_INICIO": "19:00"}, 0)]
for escolhas, disco, esperado in casos:
    if len(f(escolhas, disco)) != esperado:
        erros.append("%r sobre %r deu %r" % (escolhas, disco, f(escolhas, disco)))
print("; ".join(erros) or "ok")
PY
)"
rm -rf "$_tmp15"
if [ "$_noite" = ok ]; then
  echo "ok: a noite com uma ponta só é recusada (409) no definir e no salvar; as duas, nenhuma, ou a que completa a do disco passam"
else
  echo "FALHOU: a noite com uma ponta só: $_noite" >&2
  falhas=$((falhas+1))
fi

# --- 16. TODA CHAVE NUMÉRICA DECLARA A FAIXA — P82, item 31 --------------------
#   Uma chave que é número e não declara faixa vira campo de texto livre, e o
#   painel aceita «abc» nela (era o «Quantos backups guardar»). Numérica é a
#   chave cujo valor de fábrica é um número, ou cujo leitor nos scripts cai num
#   número (`${CHAVE:-440}`). A conta das que ficam sem faixa tem de dar 0.
_tmp16="$(mktemp -d)"
_sem_faixa="$(cd "$RAIZ" && env -i PATH="$PATH" HOME="$_tmp16" python3 -I - "$RAIZ/app" <<'PY' 2>&1
import re, subprocess, sys
sys.path.insert(0, sys.argv[1])
import servidor
NUM = re.compile(r"-?\d+(?:[.,]\d+)?")
for i in servidor.ler_esquema():
    if i.get("faixa") or i.get("opcoes") or i.get("horario") or i.get("lista"):
        continue
    padrao = str(i.get("padrao") or "")
    if padrao and not NUM.fullmatch(padrao):
        continue
    leitores = subprocess.run(
        ["grep", "-rhoE", r"\$\{" + i["chave"] + r":-[0-9][0-9.]*\}",
         "scripts", "lib", "bin", "install.sh"],
        capture_output=True, text=True).stdout.split()
    if (padrao and NUM.fullmatch(padrao)) or leitores:
        print(i["chave"])
PY
)"
rm -rf "$_tmp16"
if [ -z "$_sem_faixa" ]; then
  echo "ok: toda chave numérica do exemplo declara a faixa (nenhuma vira campo de texto livre)"
else
  echo "FALHOU: chave numérica sem faixa no exemplo: $(echo $_sem_faixa)" >&2
  falhas=$((falhas+1))
fi

exit "$falhas"

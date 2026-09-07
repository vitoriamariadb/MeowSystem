#!/usr/bin/env bash
# areas.sh — as ÁREAS DE TRABALHO do COSMIC: o nome de cada uma, a ordem em que
# nascem e se as janelas se encaixam sozinhas dentro delas.
#
# O PEDIDO, LITERAL — 06/09/2026
#   "não temos a seção pra setar os dois ambientes de trabalho tipo o Meow e o
#   OS". Ela tem duas áreas com nome, e não havia nenhuma porta no projeto para
#   ver, renomear ou reordenar isso. A única forma era editar RON na mão.
#
# ============================================================================
# OS TRÊS FATOS QUE MANDAM NO DESENHO DESTE ARQUIVO
# ============================================================================
#
# 1. O ALFINETE É O QUE SEGURA TUDO
#    Um workspace do COSMIC só tem nome se estiver ALFINETADO (pinned). Sem
#    alfinete o `cosmic-comp` destrói o workspace assim que ele esvazia, e o
#    painel passa a mostrar a POSIÇÃO dele — o "3" seco que ela já viu na tela.
#    Ou seja: tirar um alfinete não é "desmarcar uma caixa", é APAGAR uma área
#    de trabalho e tudo que dependia da posição dela.
#
#    Por isso o `aplicar` deste arquivo NUNCA remove um alfinete. Ele renomeia,
#    reordena, liga o encaixe e ACRESCENTA. Quem quiser tirar usa o
#    `desalfinetar`, que é um subcomando separado, exige `MEOW_SIM=1` e diz
#    por extenso o que se perde. Um botão que apaga a área dela não pode morar
#    no mesmo lugar que um botão que a renomeia.
#
# 2. QUALQUER MUDANÇA AQUI SÓ VALE NO PRÓXIMO INÍCIO DE SESSÃO
#    O `cosmic-comp` lê o `pinned_workspaces` UMA vez, ao iniciar (medido duas
#    vezes em 04/08/2026: escrita às 04:03, o nome velho ainda na tela 3s
#    depois, o nome novo só no boot das 10:26). Não há inotify neste caminho,
#    ao contrário do tema e das chaves de `autotile`.
#
#    Todo caminho de escrita deste arquivo termina dizendo isso em voz alta. Um
#    ajuste que parece não funcionar é pior que um ajuste que não existe: quem
#    troca o nome, olha a barra e não vê mudança conclui que o painel está
#    quebrado, e a próxima coisa que ela faz é mexer no arquivo na mão.
#
# 3. A ORDEM IMPORTA, E ELA TEM UMA RAZÃO ESCRITA
#    No `cosmic-comp` (`src/shell/mod.rs`, `add_output`) os alfinetados são
#    criados PRIMEIRO, na ordem do arquivo, e só depois os dinâmicos entram.
#    Com apenas o "OS" alfinetado, ele nascia na POSIÇÃO 1 — na frente da área
#    dela. É por isso que os DOIS são alfinetados, e é por isso que o "Meow"
#    vem primeiro: não é gosto, é a única forma de a área dela ser a primeira.
#    Reordenar a lista aqui reordena a barra dela no próximo login.
#
# ============================================================================
# O ARQUIVO, E O QUE NELE É INTOCÁVEL
# ============================================================================
#   `~/.config/cosmic/com.system76.CosmicComp/v1/pinned_workspaces`, em RON.
#   Uma lista de registros, cada um assim (medido no disco desta máquina):
#
#       (
#           output: (
#               name: "DP-1",
#               edid: Some((manufacturer: ('G','D','H'), product: 48, ...)),
#           ),
#           tiling_enabled: true,
#           id: Some("c0ffee"),
#           name: Some("<nome>"),
#       )
#
#   O BLOCO `output:` E O `edid` SAEM DAQUI EXATAMENTE COMO ENTRARAM. Eles
#   amarram a área a um monitor, e um EDID errado põe a área num monitor que
#   não existe. Este script nunca os reescreve: quando precisa criar uma área
#   nova, ele HERDA o bloco `output:` de uma entrada que já está no arquivo, em
#   bytes, e só cai fora se não houver nenhuma de onde herdar.
#
#   Os `id` são hexadecimais de 24 bits que o próprio COSMIC sorteia
#   (`shell/workspace.rs`, `random_workspace_id`) — daí os legíveis a olho que
#   estão neste arquivo (`c0ffee`, `deb970`, e o `decaf0` do "III", que saiu em
#   25/08/2026). Uma área nova ganha um id sorteado do mesmo jeito, conferido
#   contra os que já existem.
#
#   TRÊS `.bak-*` moram ao lado do arquivo e são a melhor documentação do
#   formato que existe nesta máquina: `.bak-pre-rename` tem `name: None` (é
#   valor válido — área alfinetada e sem nome), `.bak-pre-iii-fora` tem os três
#   alfinetes e `tiling_enabled: false`, e `.bak-aurora` tem os dois de hoje.
#
# ============================================================================
# ESTE ARQUIVO TEM DOIS VIZINHOS NO MESMO ALVO, E OS DOIS FORAM MEDIDOS
# ============================================================================
#
# VIZINHO 1 — o `scripts/janelas.sh`, que é DESTE projeto
#   Ele escreve `tiling_enabled` em TODAS as entradas de uma vez
#   (`_janelas_pin_escrever`, com `sed ... /g`), a partir da chave
#   `JANELAS_TILING`, e o `meow doctor` o chama todo dia. Ou seja: um encaixe
#   POR ÁREA gravado aqui é achatado por ele na passagem seguinte, calado.
#
#   Não há como os dois estarem certos ao mesmo tempo, então o desenho é
#   explícito: `AREAS_ENCAIXE` vazio (o padrão) deixa o `janelas.sh` ser o dono,
#   e este script não encosta no campo. Com `AREAS_ENCAIXE` preenchido, o
#   `aplicar` daqui RECUSA (rc 4) enquanto `JANELAS_TILING` também estiver
#   preenchido e as duas respostas não coincidirem — e diz qual esvaziar. É a
#   mesma regra que o resto do projeto usa: dois donos da mesma linha é o
#   defeito que mais custou caro aqui.
#
# VIZINHO 2 — o `aurora-cosmic-workspaces.py`, que NÃO é deste projeto
#   O `docs/FRONTEIRA.md` dá o `pinned_workspaces` ao Ritual da Aurora, e a
#   medição diz por quê: o self-heal roda de hora em hora (timer conferido:
#   `ritual-aurora-self-heal.timer`, ciclo de 1h) e chama aquele script, que
#   tem uma lista `MANAGED` com os alfinetes canônicos e FORÇA o nome de cada
#   um deles. Lendo o fonte:
#
#     - ele casa o canônico por `id` PRIMEIRO e por `name` depois;
#     - ao casar, ele monta a entrada com `"name": alvo["name"]` — o nome da
#       lista dele, não o do disco;
#     - `tiling_enabled` e o bloco `output:` ele PRESERVA do disco;
#     - alfinete que não é dele é preservado e empurrado para depois dos
#       canônicos;
#     - ele só escreve quando a semântica diverge, e guarda o anterior em
#       `.bak-aurora`.
#
#   A consequência prática, e ela decide o desenho: **renomear um alfinete que
#   está na `MANAGED` dele é desfeito em até uma hora.** Não é hipótese — é o
#   que aquele arquivo faz, linha a linha. Gravar assim mesmo seria entregar
#   exatamente o sintoma do fato 2 acima, só que pior, porque voltaria sozinho
#   DEPOIS de ter funcionado por um login.
#
#   O `FRONTEIRA.md` já responde a esse caso em uma frase: "quando o Aurora
#   precisa continuar sendo o dono, o Meow NÃO ESCREVE — ele confere e diz". É
#   o que este arquivo faz: rc 4 (pendência que não é nossa), com o caminho do
#   arquivo e da lista a mudar. Renomear vale para todo alfinete que NÃO esteja
#   na lista dele, e o encaixe vale sempre, porque ele preserva o campo.
#
#   A conferência é barata e não acopla os dois projetos: procura-se o `id`
#   como texto dentro do script vizinho. Máquina sem Aurora não tem o arquivo,
#   a guarda não arma, e tudo é escrevível — que é o certo para quem instalar
#   este projeto de fora.
#
# ============================================================================
# IDEMPOTÊNCIA E MODO SECO
# ============================================================================
#   0 já estava assim · 1 estava diferente e consertei · 2 erro · 3 falta
#   dependência · 4 pendência que não é nossa. Quando mais de um acontece na
#   mesma passagem, vence o mais grave nesta ordem: 2 > 3 > 4 > 1 > 0.
#
#   O texto novo é montado inteiro e comparado com o do disco ANTES de
#   qualquer escrita, e quando nada muda de estrutura a montagem é feita por
#   substituição de intervalo no texto original — então "nada a fazer" é
#   byte-idêntico, e não uma reserialização que empata por sorte.
#
#   `MEOW_DRY_RUN=1` é a porta do modo seco, e não `MEOW_SECO=1`: o
#   `lib/comum.sh:25` sobrescreve o `MEOW_SECO` que vier do ambiente, no
#   `source`. Está documentado lá, com o incidente de 24/08/2026.
#
# USO
#   areas.sh estado        lista as áreas alfinetadas, na ordem, com nome e id
#   areas.sh conferir      0 = conforme · 1 = divergente · 2 = erro · 3 = sem comp
#   areas.sh aplicar       põe o arquivo de acordo com as chaves do meow.conf
#   areas.sh reverter      devolve o arquivo como estava antes da nossa 1ª escrita
#   areas.sh desalfinetar <nome>   TIRA uma área (destrutivo; exige MEOW_SIM=1)
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# 4 = pendência que não é nossa para consertar. O `lib/comum.sh` não declara
# esta constante (ela nasceu depois dos quatro primeiros códigos), então cada
# script que a usa a nomeia — é o que o `prompt.sh` e o `fastfetch_logo.sh` já
# fazem, com o número cru.
AREAS_PENDENCIA=4

# --- as chaves do meow.conf -------------------------------------------------
# VAZIO = NÃO TOCA, nos três casos, e pelo mesmo motivo das `VIDRO_OPACIDADE_*`
# e do `JANELAS_TILING`: a área de trabalho é dela, existe antes deste projeto,
# e o padrão de fábrica de um projeto público não pode renomear os workspaces
# de quem acabou de instalar.
AREAS_NOMES="${AREAS_NOMES:-}"
AREAS_FOLGA="${AREAS_FOLGA:-}"
AREAS_ENCAIXE="${AREAS_ENCAIXE:-}"
# Lida só para saber se o `janelas.sh` vai achatar o que gravarmos por área.
# Nunca escrita daqui.
JANELAS_TILING="${JANELAS_TILING:-}"

AREAS_BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}/com.system76.CosmicComp/v1"
AREAS_ALVO="$AREAS_BASE/pinned_workspaces"
AREAS_BINARIO="/usr/bin/cosmic-comp"

# O estado de ANTES da nossa primeira escrita — é o que o `reverter` devolve.
AREAS_ANTES="$MEOW_ESTADO/areas"
BACKUPS_MANTIDOS="${BACKUPS_MANTIDOS:-10}"

# O ESPAÇO-FIGURA (U+2007), E POR QUE ELE MERECE UMA CHAVE
#   30/08/2026, com a topbar na frente: "Pq não pode ficar Meow? Já tava assim
#   antes e o nome precisa de mais espaço, adiciona um caracter fantasma pra ser
#   um espaço invisível." Ela recusou encurtar o nome e recusou trocá-lo por um
#   glifo — o problema é o desenho da pastilha, não a palavra.
#
#   O `cosmic-applet-workspaces` (`src/components/app.rs:190-205`) desenha cada
#   área como `column!(row!(texto, espaço), espaço_horizontal(quadrado))`: a
#   pastilha é do tamanho do TEXTO, com um piso de um quadrado da barra. Com
#   "Meow" em negrito o texto empata com o piso e as letras encostam na borda.
#
#   U+2007 e não espaço comum: espaço comum morre em qualquer `trim()`, e o
#   U+2007 tem a largura de um dígito e não quebra linha. O `cosmic-comp` não
#   corta nome de área — conferido no fonte 5c93094, não há um `.trim()` sequer
#   em `src/shell/workspace.rs` nem no caminho do `create_workspace_from_pinned`.
#
#   Isto é uma CHAVE e não uma esperteza do código porque é decisão dela, por
#   área, e porque sem ela o nome no disco (` Meow `) e o nome no conf (`Meow`)
#   divergiriam para sempre — o `aplicar` acusaria "divergente" em toda
#   passagem sobre um arquivo que ninguém quer mudar.
AREAS_FIGURA=$'\u2007'   # U+2007 FIGURE SPACE, escrito por escape: um byte
                         # invisível no fonte seria a próxima armadilha, não o conserto.

# --- as duas dependências ---------------------------------------------------
# 3 e não 1: sem cosmic-comp não há divergência, há ausência de assunto.
_areas_dependencia() {
  if [ ! -x "$AREAS_BINARIO" ] && [ ! -d "$AREAS_BASE" ]; then
    meow_pula "cosmic-comp não encontrado — nada a fazer com as áreas de trabalho"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  # O RON é lido e montado em Python (ver `_areas_motor`). Sem ele o script não
  # tem como sequer LER a lista, então nem o `estado` funciona pela metade.
  if ! meow_tem python3; then
    meow_pula "sem python3 — não consigo ler o RON do pinned_workspaces"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- O MOTOR DE RON, E POR QUE ELE É PYTHON DENTRO DE UM SCRIPT DE SHELL -----
# O `pinned_workspaces` não é um arquivo de linhas: é uma árvore com parênteses
# aninhados, strings com escape e literais de caractere (`'G'`, do EDID). Mexer
# nele com `sed` ancorado só é seguro quando o campo é um booleano numa linha
# própria — que é exatamente o que o `janelas.sh` faz com `tiling_enabled`, e é
# o limite do que aquele caminho aguenta. NOME e ORDEM não cabem ali: um nome
# pode conter `)` , `,` e `:` sem nada quebrar do lado do COSMIC, e uma linha
# de `sed` que casasse isso reescreveria o arquivo errado calada.
#
# O motor aqui NÃO ESCREVE NADA. Ele lê e devolve texto no stdout; quem grava é
# o `meow_escrever` do `lib/comum.sh`, que já tem o modo seco, a escrita atômica
# no diretório de destino, o prefixo `.atomicwrite` que o cosmic-config ignora, e
# o registro no manifesto. Duas rotinas de escrita para o mesmo arquivo é o
# defeito que o cabeçalho do `lib/comum.sh` conta por extenso.
_areas_motor() {
  python3 - "$@" <<'PY'
import random
import re
import sys

# ---------------------------------------------------------------------------
# A VARREDURA. Ela existe para que os intervalos saiam CERTOS mesmo com
# parêntese dentro de string e com o literal de caractere do EDID ('G').
# Um `text.find(")")` acharia o fecha-parêntese de dentro de um nome.
# ---------------------------------------------------------------------------
ABRE = {"(": ")", "[": "]"}


def mascara(texto):
    """O texto com strings, chars e comentários trocados por espaços.

    Mesmo tamanho, mesmos deslocamentos: quem procurar um parêntese nesta
    máscara encontra só os parênteses ESTRUTURAIS, e o índice serve para
    fatiar o texto original sem nenhuma conversão.
    """
    saida = []
    i, n = 0, len(texto)
    while i < n:
        c = texto[i]
        if c == '"':
            j = i + 1
            while j < n:
                if texto[j] == "\\":
                    j += 2
                    continue
                if texto[j] == '"':
                    break
                j += 1
            saida.append(" " * (min(j, n - 1) - i + 1))
            i = j + 1
        elif c == "'":
            j = i + 1
            while j < n and texto[j] != "'":
                j += 2 if texto[j] == "\\" else 1
            saida.append(" " * (min(j, n - 1) - i + 1))
            i = j + 1
        elif c == "/" and i + 1 < n and texto[i + 1] == "/":
            j = texto.find("\n", i)
            j = n if j < 0 else j
            saida.append(" " * (j - i))
            i = j
        elif c == "/" and i + 1 < n and texto[i + 1] == "*":
            j = texto.find("*/", i + 2)
            j = n if j < 0 else j + 2
            saida.append(" " * (j - i))
            i = j
        else:
            saida.append(c)
            i += 1
    return "".join(saida)


def fecha(m, inicio):
    """O índice do delimitador que fecha o que abre em `inicio`, na máscara."""
    alvo = ABRE[m[inicio]]
    profundidade = 0
    for k in range(inicio, len(m)):
        if m[k] in ABRE:
            profundidade += 1
        elif m[k] in (")", "]"):
            profundidade -= 1
            if profundidade == 0:
                return k if m[k] == alvo else -1
    return -1


def desescapa(s):
    saida, i, n = [], 0, len(s)
    while i < n:
        if s[i] == "\\" and i + 1 < n:
            p = s[i + 1]
            saida.append({"n": "\n", "t": "\t", "r": "\r"}.get(p, p))
            i += 2
        else:
            saida.append(s[i])
            i += 1
    return "".join(saida)


def escapa(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def entradas(texto):
    """[(inicio, fim, campos)] de cada registro da lista, no texto CRU."""
    m = mascara(texto)
    ini = m.find("[")
    if ini < 0:
        raise ValueError("não achei a lista: falta o colchete de abertura")
    fim = fecha(m, ini)
    if fim < 0:
        raise ValueError("a lista de áreas não fecha o colchete")

    achadas = []
    i = ini + 1
    while i < fim:
        if m[i] != "(":
            i += 1
            continue
        parada = fecha(m, i)
        if parada < 0 or parada > fim:
            raise ValueError("um registro de área não fecha o parêntese")
        achadas.append((i, parada, campos(texto, m, i, parada)))
        i = parada + 1
    return ini, fim, achadas


def campos(texto, m, ini, fim):
    """Os campos do registro, com os deslocamentos ABSOLUTOS de cada valor.

    O bloco `output:` é apagado da máscara local antes da busca porque ele
    carrega um `name:` PRÓPRIO — o do conector, "DP-1". Sem isso o nome da
    área seria lido do monitor, e uma renomeação escreveria por cima do
    conector: o registro apontaria para uma saída que não existe.
    """
    bruto = texto[ini : fim + 1]
    local = m[ini : fim + 1]
    saida = {"output": None, "output_span": None}

    mo = re.search(r"output\s*:\s*\(", local)
    if mo:
        abre = mo.end() - 1
        fecha_out = fecha(local, abre)
        if fecha_out < 0:
            raise ValueError("o bloco output não fecha o parêntese")
        saida["output"] = bruto[abre : fecha_out + 1]
        saida["output_span"] = (ini + abre, ini + fecha_out + 1)
        local = local[:abre] + " " * (fecha_out + 1 - abre) + local[fecha_out + 1 :]

    # A BUSCA ACONTECE NA MÁSCARA E A LEITURA NO TEXTO CRU, E CONFUNDIR OS DOIS
    # FOI O PRIMEIRO DEFEITO DESTE ARQUIVO — medido em 06/09/2026, com o
    # `estado` imprimindo `id=true` e nome vazio para as duas áreas.
    #   A máscara existe para que um parêntese DENTRO de um nome não seja
    #   confundido com o fecha-parêntese do registro; para isso ela troca o
    #   conteúdo de toda string por espaços. Ou seja: procurar `Some("c0ffee")`
    #   nela nunca acha o `c0ffee` — lá está escrito `Some(        )`.
    #   A máscara diz ONDE o valor começa e acaba; o valor em si sai do bruto.
    def acha(chave, campo):
        r = re.search(chave + r"\s*:\s*", local)
        if not r:
            saida[campo] = None
            saida[campo + "_span"] = None
            return
        p = r.end()
        if local.startswith("None", p):
            fim_v, valor = p + 4, None
        elif local.startswith("Some(", p):
            f = fecha(local, p + 4)
            if f < 0:
                raise ValueError("o campo %s não fecha o parêntese" % chave)
            fim_v = f + 1
            dentro = re.match(r'Some\(\s*"((?:[^"\\]|\\.)*)"\s*\)\Z', bruto[p:fim_v])
            valor = desescapa(dentro.group(1)) if dentro else None
        else:
            t = re.match(r"[A-Za-z0-9_.+-]+", local[p:])
            if not t:
                saida[campo] = None
                saida[campo + "_span"] = None
                return
            fim_v, valor = p + t.end(), bruto[p : p + t.end()]
        saida[campo] = valor
        # O intervalo é o do VALOR (o `Some(...)`, o `None` ou o booleano), e
        # não o da chave: é só ele que a substituição troca.
        saida[campo + "_span"] = (ini + p, ini + fim_v)

    acha("tiling_enabled", "tiling")
    acha("id", "id")
    acha("name", "nome")
    if saida["tiling"] is None:
        saida["tiling"] = "false"
    return saida


def ler(caminho):
    texto = open(caminho, encoding="utf-8").read()
    _, _, achadas = entradas(texto)
    for i, (_, _, c) in enumerate(achadas):
        nome = c["nome"] if c["nome"] is not None else ""
        if "\t" in nome or "\n" in nome:
            raise ValueError(
                "a área %d tem tabulação ou quebra de linha no nome; "
                "não mexo neste arquivo sem estragá-lo" % i
            )
        # O último campo é o nome de propósito: ele é o único que pode conter
        # qualquer coisa, e assim quem lê no shell corta em dois separadores.
        print(
            "%d\t%s\t%s\t%s"
            % (i, c["id"] or "", c["tiling"], nome)
        )


def id_novo(usados):
    """Um id como o COSMIC sorteia: 24 bits em hexadecimal."""
    for _ in range(200):
        candidato = "%06x" % random.getrandbits(24)
        if candidato not in usados:
            return candidato
    raise ValueError("não consegui sortear um id de área livre")


NOVA = (
    "(\n"
    "        output: %s,\n"
    "        tiling_enabled: %s,\n"
    "        id: Some(\"%s\"),\n"
    "        name: Some(\"%s\"),\n"
    "    )"
)


def montar(caminho, encaixes, nomes):
    """O texto NOVO do arquivo, no stdout. Nada é escrito aqui."""
    texto = open(caminho, encoding="utf-8").read()
    _, _, achadas = entradas(texto)

    if len(nomes) < len(achadas):
        raise ValueError(
            "a lista pedida tem %d área(s) e o disco tem %d: isto TIRARIA "
            "alfinete, e tirar alfinete apaga a área de trabalho. Use "
            "`areas.sh desalfinetar <nome>`." % (len(nomes), len(achadas))
        )
    if not nomes:
        raise ValueError("lista vazia: um arquivo sem alfinete nenhum destrói as áreas")

    # --- o caminho sem mudança de estrutura: substituição de intervalo -------
    # Mesma quantidade de registros e mesma ordem, então o texto novo nasce do
    # ORIGINAL, trocando só os intervalos que mudam, do fim para o começo (para
    # que um deslocamento não invalide o próximo). É o que faz "nada a fazer"
    # ser byte-idêntico em vez de empatar por sorte na reserialização.
    if len(nomes) == len(achadas):
        trocas = []
        for i, (_, _, c) in enumerate(achadas):
            if nomes[i] != (c["nome"] if c["nome"] is not None else ""):
                trocas.append((c["nome_span"], 'Some("%s")' % escapa(nomes[i])))
            if encaixes[i] and encaixes[i] != c["tiling"]:
                trocas.append((c["tiling_span"], encaixes[i]))
        for (ini, fim), novo in sorted(trocas, key=lambda t: -t[0][0]):
            texto = texto[:ini] + novo + texto[fim:]
        sys.stdout.write(texto)
        return

    # --- o caminho com áreas NOVAS ------------------------------------------
    # O bloco `output:` da nova é HERDADO em bytes de uma que já existe. Nunca
    # inventado: o EDID amarra a área ao monitor, e um EDID de mentira põe a
    # área numa saída que não está ligada.
    herdado = next((c["output"] for _, _, c in achadas if c["output"]), None)
    if herdado is None:
        raise ValueError(
            "nenhuma área existente tem bloco `output:` de onde herdar o monitor; "
            "não vou inventar um EDID"
        )

    usados = {c["id"] for _, _, c in achadas if c["id"]}
    crus = []
    for i, nome in enumerate(nomes):
        if i < len(achadas):
            ini, fim, c = achadas[i]
            bruto = texto[ini : fim + 1]
            trocas = []
            if nome != (c["nome"] if c["nome"] is not None else ""):
                trocas.append((c["nome_span"], 'Some("%s")' % escapa(nome)))
            if encaixes[i] and encaixes[i] != c["tiling"]:
                trocas.append((c["tiling_span"], encaixes[i]))
            for (a, b), novo in sorted(trocas, key=lambda t: -t[0][0]):
                bruto = bruto[: a - ini] + novo + bruto[b - ini :]
            crus.append(bruto)
        else:
            novo_id = id_novo(usados)
            usados.add(novo_id)
            crus.append(
                NOVA % (herdado, encaixes[i] or "false", novo_id, escapa(nome))
            )

    ini0, fim0, _ = achadas[0]
    cabeca = texto[:ini0]
    rabo = texto[achadas[-1][1] + 1 :]
    emenda = ",\n    "
    if len(achadas) > 1:
        emenda = texto[achadas[0][1] + 1 : achadas[1][0]]
    sys.stdout.write(cabeca + emenda.join(crus) + rabo)


def tirar(caminho, indice):
    texto = open(caminho, encoding="utf-8").read()
    _, _, achadas = entradas(texto)
    if indice < 0 or indice >= len(achadas):
        raise ValueError("não existe área na posição %d" % indice)
    if len(achadas) <= 1:
        raise ValueError(
            "esta é a última área alfinetada; sem alfinete nenhum o cosmic-comp "
            "destrói o workspace assim que ele esvazia"
        )
    crus = [texto[a : b + 1] for j, (a, b, _) in enumerate(achadas) if j != indice]
    cabeca = texto[: achadas[0][0]]
    rabo = texto[achadas[-1][1] + 1 :]
    emenda = texto[achadas[0][1] + 1 : achadas[1][0]]
    sys.stdout.write(cabeca + emenda.join(crus) + rabo)


try:
    verbo = sys.argv[1]
    if verbo == "ler":
        ler(sys.argv[2])
    elif verbo == "montar":
        # argv: montar <arquivo> <encaixes-csv> <nome0> <nome1> ...
        encaixes_csv = sys.argv[3]
        alvos = sys.argv[4:]
        lista = encaixes_csv.split(",") if encaixes_csv else []
        lista += [""] * (len(alvos) - len(lista))
        montar(sys.argv[2], lista, alvos)
    elif verbo == "tirar":
        tirar(sys.argv[2], int(sys.argv[3]))
    else:
        raise ValueError("verbo desconhecido: %s" % verbo)
except (ValueError, OSError, IndexError) as erro:
    sys.stderr.write("%s\n" % erro)
    sys.exit(2)
PY
}

# --- a peneira do nome ------------------------------------------------------
# SEM `eval` E SEM SUBSTITUIÇÃO SILENCIOSA. Aspas, contrabarra, parênteses e
# quebra de linha destruiriam o RON; `#` não destrói o RON mas destrói a LINHA
# do meow.conf, que é partida no primeiro `#` para preservar o comentário
# (`meow_conf_texto_definir`, lib/comum.sh).
#
# A resposta é RECUSAR, e não limpar calado: quem digitou `Meow (dela)` e viu
# aparecer `Meow dela` na barra não teve o pedido atendido nem negado — teve
# outro. Dizer qual caractere não cabe é o que permite escolher outro nome.
_areas_nome_seguro() {
  local nome="$1"
  case "$nome" in
    *'"'*|*\\*|*'('*|*')'*|*'#'*|*$'\n'*|*$'\t'*)
      meow_erro "nome de área recusado: '$nome'"
      meow_aviso "não cabem aspas, contrabarra, parênteses, # nem quebra de linha —"
      meow_aviso "os quatro primeiros quebram o RON e o # corta a linha do meow.conf."
      return 1 ;;
  esac
  [ -n "$nome" ] || { meow_erro "nome de área vazio na lista"; return 1; }
  return 0
}

# `a, b , c` -> uma por linha, aparadas. Sem `eval` e sem IFS global: o `read -d`
# corta no separador e o resto é poda de espaço em bash puro.
_areas_partir() {
  local texto="$1" item
  while IFS= read -r -d ',' item || [ -n "$item" ]; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [ -n "$item" ] && printf '%s\n' "$item"
  done < <(printf '%s,' "$texto")
}

# CAPTURAR SEM PERDER A QUEBRA FINAL — e isto é o defeito nº 2 deste arquivo,
# medido em 06/09/2026: `aplicar` devolveu 1 e disse "gravadas" sobre um arquivo
# cujo md5 não mudou.
#   `$( )` come TODA quebra de linha do fim. O `pinned_workspaces` termina em
#   `]\n`, então `texto="$(motor)"` perdia o byte final e a comparação com o
#   disco nunca podia dar igual — o script reescrevia o mesmo conteúdo em toda
#   passagem, e a idempotência era falsa por um byte invisível.
#   O `printf x` põe uma âncora depois da quebra, e o `${v%x}` a tira: o que
#   sobra é o texto EXATO, com quantas quebras finais ele tiver.
#
#   O `meow_escrever` compara com `$(cat "$destino")` e sofre do mesmo corte,
#   então ele nunca reconhece "igual" quando o conteúdo termina em quebra. Por
#   isso a comparação certa é feita AQUI, antes de chamá-lo — que é a mesma
#   ordem que o `janelas.sh` usa (ele só chama depois de um `grep -q` dizer que
#   há o que trocar).
#   E A FUNÇÃO TEM DE ATRIBUIR, NÃO IMPRIMIR — foi o defeito nº 3, na mesma
#   noite. A primeira versão destes dois ajudantes IMPRIMIA o texto certo, e
#   quem chamava fazia `texto="$(ajudante ...)"` — pondo o corte de volta, uma
#   camada acima. Não há como devolver uma quebra final POR STDOUT em bash: a
#   substituição de comando a come sempre, venha ela de onde vier. Por isso o
#   resultado sai por `AREAS_TEXTO`, escrito DENTRO da função, e o `printf x`
#   mora do lado de dentro, onde a substituição ainda não aconteceu.
#
#   O sintoma, medido numa caixa de areia em /tmp: o `reverter` devolvia um
#   arquivo de 837 bytes onde o original tinha 838 — o `]` sem a quebra depois.
AREAS_TEXTO=""

_areas_ler_arquivo() {
  local saida; saida="$(cat "$1" 2>/dev/null; printf x)"
  AREAS_TEXTO="${saida%x}"
}

_areas_montar_texto() {
  local saida rc
  saida="$(_areas_motor "$@" 2>/dev/null; printf x)"; rc=$?
  AREAS_TEXTO="${saida%x}"
  return "$rc"
}

# `${arr[*]}` com `IFS=', '` junta pelo PRIMEIRO caractere do IFS e mais nada —
# saía `Meow ,OS`. Uma linha de laço diz o que se quis dizer.
#
# E o nome sai SEM a folga invisível: com ela, a linha na tela vira ` Meow , OS`
# e parece erro de digitação nossa. A folga é dita por extenso no `estado`, que
# é onde ela é informação; numa frase de confirmação ela é só ruído.
_areas_juntar() {
  local sep="" x
  for x in "$@"; do printf '%s%s' "$sep" "$(_areas_sem_folga "$x")"; sep=", "; done
}

_areas_bool() {
  case "$1" in
    sim|true|1)      printf 'true' ;;
    nao|não|false|0) printf 'false' ;;
    *) return 1 ;;
  esac
}

# --- a leitura do disco, em três arrays paralelos ---------------------------
AREAS_ID=(); AREAS_TILING=(); AREAS_NOME=()

_areas_ler() {
  AREAS_ID=(); AREAS_TILING=(); AREAS_NOME=()
  [ -f "$AREAS_ALVO" ] || return "$MEOW_OK"   # sem arquivo, zero áreas
  local erro
  erro="$(_areas_motor ler "$AREAS_ALVO" 2>&1 >/dev/null)"
  if [ -n "$erro" ]; then
    meow_erro "não consegui ler $AREAS_ALVO: $erro"
    return "$MEOW_ERRO"
  fi
  while IFS=$'\t' read -r _i id tiling nome; do
    AREAS_ID+=("$id"); AREAS_TILING+=("$tiling"); AREAS_NOME+=("$nome")
  done < <(_areas_motor ler "$AREAS_ALVO" 2>/dev/null)
  return "$MEOW_OK"
}

# O nome sem a folga invisível — é por ele que a comparação com o conf acontece.
_areas_sem_folga() {
  local n="$1"
  while [ "${n#"$AREAS_FIGURA"}" != "$n" ]; do n="${n#"$AREAS_FIGURA"}"; done
  while [ "${n%"$AREAS_FIGURA"}" != "$n" ]; do n="${n%"$AREAS_FIGURA"}"; done
  printf '%s' "$n"
}

# --- a guarda do vizinho ----------------------------------------------------
# Ver o bloco "VIZINHO 2" do cabeçalho. A pergunta é uma só: renomear ESTE
# alfinete sobrevive à próxima passagem do self-heal?
AREAS_VIZINHO_FONTE="$HOME/.config/zsh/scripts/aurora-cosmic-workspaces.py"
AREAS_VIZINHO_VIVO="$HOME/.local/bin/aurora-cosmic-workspaces.py"
AREAS_VIZINHO_DESLIGA="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}/.aurora-workspaces-off"

_areas_vizinho_armado() {
  [ -f "$AREAS_VIZINHO_DESLIGA" ] && return 1
  [ -f "$AREAS_VIZINHO_VIVO" ] || [ -f "$AREAS_VIZINHO_FONTE" ]
}

# A FRONTEIRA MUDOU DE LADO EM 07/09/2026, E FOI DECISÃO DELA.
#   Este script nasceu recusando (rc 4) o que o reparador do Ritual da Aurora
#   também escreve, porque o `docs/FRONTEIRA.md` dava o `pinned_workspaces` a
#   ele. Mostrei a ela o custo dessa recusa — a seção do painel existiria só para
#   olhar — e a resposta foi: *"então corrige no zsh e traz a feature pra cá"*.
#
#   O conserto NÃO É editar o script vizinho. Ele já prevê a cessão, e diz onde:
#   *"OPT-OUT: se ~/.config/cosmic/.aurora-workspaces-off existir, sai sem tocar
#   em nada. Sentinela em arquivo separado, porque o COSMIC reserializa o
#   pinned_workspaces sozinho e apagaria qualquer marcador que morasse dentro
#   dele."* Usar a porta que o vizinho deixou aberta é melhor que arrombar a
#   parede: o script dele continua intacto, atualizável, e a cessão é reversível
#   apagando um arquivo.
#
#   A sentinela leva a data e o porquê por dentro. Daqui a seis meses, alguém que
#   a encontre precisa saber que ela é decisão, e não sujeira.
_areas_assumir_posse() {
  _areas_vizinho_armado || return 0          # já é nosso, ou não há vizinho
  if meow_seco; then
    meow_info "desarmaria o reparador do Ritual da Aurora ($AREAS_VIZINHO_DESLIGA)"
    return 0
  fi
  mkdir -p "$(dirname "$AREAS_VIZINHO_DESLIGA")" 2>/dev/null || true
  cat > "$AREAS_VIZINHO_DESLIGA" <<'SENTINELA'
# Quem manda nas áreas de trabalho é o MeowSystem, desde 07/09/2026.
#
# Este arquivo é o OPT-OUT que o próprio aurora-cosmic-workspaces.py oferece:
# com ele presente, o reparador do Ritual da Aurora sai sem tocar no
# pinned_workspaces. Antes disso os dois escreviam o mesmo arquivo, e o de lá
# roda de hora em hora pelo self-heal — então uma renomeação feita aqui voltava
# atrás sozinha depois de já ter funcionado por um login, que é o pior sintoma
# possível.
#
# Para devolver as áreas ao Ritual da Aurora: apague este arquivo.
# Quem escreve agora: scripts/areas.sh deste projeto (meow areas aplicar).
SENTINELA
  meow_muda "o reparador do Ritual da Aurora foi desarmado — as áreas agora são nossas"
}

# 0 = o vizinho manda no nome deste id (não escrevemos) · 1 = é nosso.
_areas_vizinho_manda() {
  local id="$1" arq
  [ -n "$id" ] || return 1
  _areas_vizinho_armado || return 1
  for arq in "$AREAS_VIZINHO_VIVO" "$AREAS_VIZINHO_FONTE"; do
    [ -f "$arq" ] || continue
    grep -qF "\"$id\"" "$arq" 2>/dev/null && return 0
  done
  return 1
}

# --- backup, e ele é a diferença entre ter e não ter área de trabalho -------
# Duas cópias, com propósitos diferentes:
#   `.antes`   o estado de ANTES da nossa PRIMEIRA escrita — é o que o
#              `reverter` devolve, e ele nunca é sobrescrito depois de existir.
#   `backups/` uma cópia por passagem que escreve, no mesmo idioma do resto do
#              projeto (`$MEOW_ESTADO/backups/<carimbo>-areas/`), podada por
#              `BACKUPS_MANTIDOS`.
# PREGUIÇOSO: nada nasce numa passagem que não vai escrever. Sem isso o doctor
# diário criaria uma pasta por dia sem nunca ter mudado um byte.
_areas_guardar() {
  meow_seco && return 0
  [ -f "$AREAS_ALVO" ] || return 0

  if [ ! -f "$AREAS_ANTES/pinned_workspaces.antes" ]; then
    mkdir -p "$AREAS_ANTES" 2>/dev/null \
      || { meow_erro "não consegui criar $AREAS_ANTES"; return "$MEOW_ERRO"; }
    cp -a "$AREAS_ALVO" "$AREAS_ANTES/pinned_workspaces.antes" 2>/dev/null \
      || { meow_erro "não consegui guardar o estado de antes — não vou escrever"; return "$MEOW_ERRO"; }
  fi

  local dir="$MEOW_ESTADO/backups/$MEOW_CARIMBO-areas"
  mkdir -p "$dir" 2>/dev/null \
    || { meow_erro "não consegui criar $dir"; return "$MEOW_ERRO"; }
  cp -a "$AREAS_ALVO" "$dir/pinned_workspaces" 2>/dev/null \
    || { meow_erro "não consegui guardar backup de $AREAS_ALVO — não vou escrever"; return "$MEOW_ERRO"; }
  cat > "$dir/COMO-RESTAURAR.txt" <<FIM
As áreas de trabalho alfinetadas do COSMIC, como estavam em
$(date '+%d/%m/%Y %H:%M:%S'), antes de o MeowSystem escrever.

Para voltar exatamente a este estado:

    cp -a $dir/pinned_workspaces $AREAS_ALVO

Ou, pelo projeto:  ./scripts/areas.sh reverter

Em qualquer um dos dois, o COSMIC só relê no PRÓXIMO INÍCIO DE SESSÃO.
FIM

  # Retenção: as N mais recentes DESTE módulo. O glob leva o sufixo `-areas`
  # justamente para não alcançar o backup de outro módulo — foi assim que um
  # glob largo de `aplicar_tema.sh` chegou a apagar a pasta de um vizinho.
  local -a antigas=() velho
  for velho in "$MEOW_ESTADO"/backups/*-areas; do
    [ -d "$velho" ] && antigas+=("$velho")
  done
  if [ "${#antigas[@]}" -gt "$BACKUPS_MANTIDOS" ]; then
    printf '%s\n' "${antigas[@]}" | sort | head -n "-$BACKUPS_MANTIDOS" \
      | while read -r velho; do rm -rf "$velho"; done
  fi
  return 0
}

# A recusa que nunca pode falhar: um arquivo sem alfinete nenhum destrói as duas
# áreas dela no próximo login, e o estrago só aparece lá — depois de o motivo já
# ter sido esquecido.
_areas_recusar_vazio() {
  local texto="$1"
  case "$texto" in
    *'('*) return "$MEOW_OK" ;;
  esac
  meow_erro "recusado: o texto novo não tem NENHUMA área alfinetada"
  meow_aviso "sem alfinete o cosmic-comp destrói o workspace assim que ele esvazia —"
  meow_aviso "gravar isto apagaria as suas áreas de trabalho no próximo login."
  return "$MEOW_ERRO"
}

_areas_so_no_login() {
  meow_info "vale no PRÓXIMO INÍCIO DE SESSÃO: o cosmic-comp lê este arquivo uma"
  meow_info "vez, ao iniciar. Nada muda na barra agora, e isso não é defeito."
}

# ============================================================================
# estado
# ============================================================================
_areas_col() { printf '%-14s' "$1"; }

cmd_estado() {
  _areas_dependencia || return $?
  _areas_ler || return $?

  if [ "${#AREAS_NOME[@]}" -eq 0 ]; then
    meow_aviso "nenhuma área alfinetada em $AREAS_ALVO"
    meow_aviso "sem alfinete as áreas não têm nome: o painel mostra a POSIÇÃO delas."
    return "$MEOW_OK"
  fi

  local i nu dono
  meow_info "áreas alfinetadas, na ordem em que nascem:"
  for i in "${!AREAS_NOME[@]}"; do
    nu="$(_areas_sem_folga "${AREAS_NOME[$i]}")"
    dono="nosso"
    _areas_vizinho_manda "${AREAS_ID[$i]}" && dono="do Ritual da Aurora"
    printf '  %s%2d.%s %s  id=%-8s encaixe=%-5s (%s)%s\n' \
      "$C_MAUVE" "$((i + 1))" "$C_ZERO" "$(_areas_col "$nu")" \
      "${AREAS_ID[$i]:-<sem id>}" "${AREAS_TILING[$i]}" "$dono" \
      "$([ "$nu" != "${AREAS_NOME[$i]}" ] && printf '  [com folga invisível]')"
  done

  # A linha pronta para colar. Sem ela, a única forma de a página oferecer "usar
  # os nomes de agora" seria remontar a lista do outro lado — uma segunda
  # verdade sobre a mesma coisa.
  local nomes="" folgas="" sep=""
  for i in "${!AREAS_NOME[@]}"; do
    nu="$(_areas_sem_folga "${AREAS_NOME[$i]}")"
    nomes="$nomes$sep$nu"
    [ "$nu" != "${AREAS_NOME[$i]}" ] && folgas="$folgas$sep$nu"
    sep=", "
  done
  meow_info "para o meow.conf:  AREAS_NOMES=\"$nomes\"   AREAS_FOLGA=\"$folgas\""

  if _areas_vizinho_armado; then
    meow_aviso "o reparador do Ritual da Aurora está armado e roda de hora em hora:"
    meow_aviso "o NOME das áreas marcadas acima é dele — ver o cabeçalho deste script."
  fi
  _areas_so_no_login
  local pid; pid="$(pgrep -x cosmic-comp 2>/dev/null | head -1)"
  [ -n "$pid" ] || meow_aviso "cosmic-comp NÃO está rodando — nada disto está valendo agora"
  return "$MEOW_OK"
}

# ============================================================================
# o cálculo que `aplicar` e `conferir` dividem
# ============================================================================
# Preenche AREAS_ALVO_NOME / AREAS_ALVO_ENCAIXE a partir do conf, aplica a
# guarda do vizinho e devolve o que sobrou para escrever.
#   0 = tudo resolvido · 2 = erro de valor · 4 = há pendência do vizinho
AREAS_ALVO_NOME=(); AREAS_ALVO_ENCAIXE=(); AREAS_BLOQUEADAS=()

_areas_planejar() {
  AREAS_ALVO_NOME=(); AREAS_ALVO_ENCAIXE=(); AREAS_BLOQUEADAS=()
  local -a pedidos=() folgas=() encaixes=()
  local n b i

  while IFS= read -r n; do pedidos+=("$n"); done < <(_areas_partir "$AREAS_NOMES")
  while IFS= read -r n; do folgas+=("$n");  done < <(_areas_partir "$AREAS_FOLGA")
  while IFS= read -r n; do encaixes+=("$n"); done < <(_areas_partir "$AREAS_ENCAIXE")

  for n in "${pedidos[@]}"; do _areas_nome_seguro "$n" || return "$MEOW_ERRO"; done

  if [ "${#pedidos[@]}" -lt "${#AREAS_NOME[@]}" ]; then
    meow_erro "AREAS_NOMES tem ${#pedidos[@]} área(s) e o disco tem ${#AREAS_NOME[@]}"
    meow_aviso "faltar um nome aqui TIRARIA um alfinete, e tirar alfinete apaga a área."
    meow_aviso "para tirar de propósito:  MEOW_SIM=1 ./scripts/areas.sh desalfinetar <nome>"
    return "$MEOW_ERRO"
  fi

  # O ENCAIXE: ou uma resposta para todas, ou uma por área. Qualquer outra
  # contagem é engano de digitação, e adivinhar qual área ela quis é o tipo de
  # esperteza que escreve na área errada.
  if [ "${#encaixes[@]}" -gt 0 ] && [ "${#encaixes[@]}" -ne 1 ] \
     && [ "${#encaixes[@]}" -ne "${#pedidos[@]}" ]; then
    meow_erro "AREAS_ENCAIXE tem ${#encaixes[@]} resposta(s) para ${#pedidos[@]} área(s)"
    meow_aviso "use uma resposta (vale para todas) ou uma por área, na mesma ordem."
    return "$MEOW_ERRO"
  fi

  local pendencia="$MEOW_OK" uniforme=1 primeiro=""
  for i in "${!pedidos[@]}"; do
    # a folga invisível, se esta área estiver na lista
    n="${pedidos[$i]}"
    for b in ${folgas[@]+"${folgas[@]}"}; do
      [ "$b" = "$n" ] && { n="$AREAS_FIGURA$n$AREAS_FIGURA"; break; }
    done

    # a guarda do vizinho: renomear um alfinete que ele gerencia é desfeito em
    # até uma hora, então não se escreve — confere-se e diz-se.
    if [ "$i" -lt "${#AREAS_NOME[@]}" ] && [ "$n" != "${AREAS_NOME[$i]}" ] \
       && _areas_vizinho_manda "${AREAS_ID[$i]}"; then
      local nota=""
      [ "$(_areas_sem_folga "${AREAS_NOME[$i]}")" = "$(_areas_sem_folga "$n")" ] \
        && nota="  (a diferença é só a folga invisível)"
      AREAS_BLOQUEADAS+=("'${AREAS_NOME[$i]}' -> '$n'   id=${AREAS_ID[$i]}$nota")
      n="${AREAS_NOME[$i]}"
      pendencia="$AREAS_PENDENCIA"
    fi
    AREAS_ALVO_NOME+=("$n")

    local e=""
    if [ "${#encaixes[@]}" -eq 1 ]; then e="${encaixes[0]}"
    elif [ "${#encaixes[@]}" -gt 0 ]; then e="${encaixes[$i]}"; fi
    if [ -n "$e" ]; then
      e="$(_areas_bool "$e")" || {
        meow_erro "AREAS_ENCAIXE tem '${encaixes[$i]:-${encaixes[0]}}' — esperado sim ou nao"
        return "$MEOW_ERRO"; }
      [ -z "$primeiro" ] && primeiro="$e"
      [ "$e" = "$primeiro" ] || uniforme=0
    fi
    AREAS_ALVO_ENCAIXE+=("$e")
  done

  # O OUTRO VIZINHO, o `janelas.sh`, que é deste projeto. Ver o cabeçalho: ele
  # achata `tiling_enabled` em TODAS as entradas de uma vez, a partir do
  # `JANELAS_TILING`, e o doctor o chama todo dia.
  if [ -n "$primeiro" ] && [ -n "$JANELAS_TILING" ]; then
    local jt; jt="$(_areas_bool "$JANELAS_TILING")" || jt=""
    if [ "$uniforme" = "0" ] || { [ -n "$jt" ] && [ "$jt" != "$primeiro" ]; }; then
      meow_aviso "AREAS_ENCAIXE e JANELAS_TILING discordam sobre o mesmo campo."
      meow_aviso "o janelas.sh grava tiling_enabled em TODAS as áreas de uma vez, e o"
      meow_aviso "'meow doctor' o chama todo dia — o que eu gravar por área ele achata."
      meow_aviso "esvazie JANELAS_TILING no meow.conf para o encaixe ser por área."
      meow_aviso "não gravei o encaixe: gravar e ver voltar amanhã é pior que não gravar."
      # O campo sai do plano. Os NOMES continuam valendo — eles não são disputa
      # de ninguém aqui dentro.
      for i in "${!AREAS_ALVO_ENCAIXE[@]}"; do AREAS_ALVO_ENCAIXE[i]=""; done
      pendencia="$AREAS_PENDENCIA"
    fi
  fi
  return "$pendencia"
}

_areas_dizer_bloqueadas() {
  local b
  [ "${#AREAS_BLOQUEADAS[@]}" -eq 0 ] && return 0
  meow_aviso "não renomeei ${#AREAS_BLOQUEADAS[@]} área(s): o nome delas é do Ritual da Aurora."
  for b in "${AREAS_BLOQUEADAS[@]}"; do meow_aviso "  $b"; done
  meow_aviso "o self-heal roda de hora em hora e repõe o nome da lista dele —"
  meow_aviso "gravar aqui daria um nome novo que volta sozinho depois de um login."
  meow_aviso "o conserto é na lista MANAGED de:"
  meow_aviso "  $AREAS_VIZINHO_FONTE"
  meow_aviso "e, depois, sincronizar a cópia em $AREAS_VIZINHO_VIVO"
}

# ============================================================================
# aplicar
# ============================================================================
cmd_aplicar() {
  if [ -z "$AREAS_NOMES" ] && [ -z "$AREAS_ENCAIXE" ]; then
    meow_pula "AREAS_NOMES vazio — as áreas de trabalho são suas"
    meow_info "para ver as de agora e a linha pronta:  ./scripts/areas.sh estado"
    return "$MEOW_OK"
  fi
  _areas_dependencia || return $?

  # A POSSE VEM ANTES DO PLANO, e a ordem importa: é `_areas_vizinho_manda` que
  # decide o que entra em `AREAS_BLOQUEADAS`, e ele responde pela presença da
  # sentinela. Desarmar depois de montar o plano deixaria a primeira passagem
  # recusando o que a segunda aceitaria — o tipo de coisa que faz alguém achar
  # que precisou "rodar duas vezes para funcionar".
  _areas_assumir_posse

  _areas_ler || return $?

  if [ ! -f "$AREAS_ALVO" ] || [ "${#AREAS_NOME[@]}" -eq 0 ]; then
    # Criar o arquivo do zero exigiria inventar um bloco `output:` com EDID, e
    # um EDID inventado põe a área num monitor que não existe. Quem sabe criar
    # do nada é o COSMIC (ao alfinetar pela primeira vez) e o reparador do
    # Ritual da Aurora, que tem o fallback medido desta TV.
    meow_aviso "não há área alfinetada em $AREAS_ALVO — não tenho de onde herdar o monitor"
    meow_aviso "alfinete uma área pelo COSMIC (visão geral, botão direito) e rode de novo."
    return "$AREAS_PENDENCIA"
  fi

  local rc_plano; _areas_planejar; rc_plano=$?
  [ "$rc_plano" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"

  local encaixes_csv="" sep="" e
  for e in ${AREAS_ALVO_ENCAIXE[@]+"${AREAS_ALVO_ENCAIXE[@]}"}; do
    encaixes_csv="$encaixes_csv$sep$e"; sep=","
  done
  # `AREAS_ALVO_ENCAIXE` pode ter itens vazios, que o laço acima come. A lista
  # é reconstruída por índice para que o CSV tenha exatamente um campo por área.
  encaixes_csv=""; sep=""
  local i
  for i in "${!AREAS_ALVO_NOME[@]}"; do
    encaixes_csv="$encaixes_csv$sep${AREAS_ALVO_ENCAIXE[$i]}"; sep=","
  done

  local novo erro
  erro="$(_areas_motor montar "$AREAS_ALVO" "$encaixes_csv" \
            "${AREAS_ALVO_NOME[@]}" 2>&1 >/dev/null)"
  if [ -n "$erro" ]; then
    meow_erro "não consegui montar o pinned_workspaces: $erro"
    return "$MEOW_ERRO"
  fi
  _areas_montar_texto montar "$AREAS_ALVO" "$encaixes_csv" "${AREAS_ALVO_NOME[@]}"
  novo="$AREAS_TEXTO"
  _areas_recusar_vazio "$novo" || return "$MEOW_ERRO"

  # A comparação é byte a byte, com a quebra final incluída dos dois lados —
  # ver `_areas_ler_arquivo`. É ela que faz "nada a fazer" ser 0 de verdade, e
  # não uma reescrita do mesmo conteúdo devolvendo 1.
  _areas_ler_arquivo "$AREAS_ALVO"
  if [ "$novo" = "$AREAS_TEXTO" ]; then
    if [ "${#AREAS_BLOQUEADAS[@]}" -gt 0 ]; then
      meow_muda "não há o que gravar: o que você pediu foi recusado logo abaixo"
    else
      meow_ok "as áreas de trabalho já estavam assim ($(_areas_juntar "${AREAS_ALVO_NOME[@]}"))"
    fi
    _areas_dizer_bloqueadas
    meow_registrar "areas.sh aplicar rc=$rc_plano (sem mudança)"
    return "$rc_plano"
  fi

  _areas_guardar || return "$MEOW_ERRO"
  local rc; meow_escrever "$AREAS_ALVO" "$novo" 644; rc=$?
  case "$rc" in
    "$MEOW_ERRO") meow_erro "não consegui gravar $AREAS_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_DIVERGENTE")
      if meow_seco; then
        meow_muda "gravaria as áreas: $(_areas_juntar "${AREAS_ALVO_NOME[@]}")"
      else
        meow_muda "áreas de trabalho gravadas: $(_areas_juntar "${AREAS_ALVO_NOME[@]}")"
        _areas_so_no_login
      fi ;;
  esac
  _areas_dizer_bloqueadas
  [ "$rc_plano" = "$AREAS_PENDENCIA" ] && rc="$AREAS_PENDENCIA"
  meow_registrar "areas.sh aplicar areas=${#AREAS_ALVO_NOME[@]} rc=$rc"
  return "$rc"
}

# ============================================================================
# conferir — lê e diz, nunca escreve
# ============================================================================
cmd_conferir() {
  if [ -z "$AREAS_NOMES" ] && [ -z "$AREAS_ENCAIXE" ]; then
    meow_pula "AREAS_NOMES vazio — nada a conferir (as áreas são suas)"
    return "$MEOW_OK"
  fi
  _areas_dependencia || return $?
  _areas_ler || return $?
  [ "${#AREAS_NOME[@]}" -gt 0 ] || { meow_aviso "nenhuma área alfinetada"; return "$AREAS_PENDENCIA"; }

  local rc_plano; _areas_planejar; rc_plano=$?
  [ "$rc_plano" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"

  local i divergente=0
  for i in "${!AREAS_ALVO_NOME[@]}"; do
    if [ "$i" -ge "${#AREAS_NOME[@]}" ]; then
      meow_muda "área $((i + 1)) '${AREAS_ALVO_NOME[$i]}' não existe no disco"
      divergente=1; continue
    fi
    [ "${AREAS_ALVO_NOME[$i]}" = "${AREAS_NOME[$i]}" ] || {
      meow_muda "área $((i + 1)): disco='${AREAS_NOME[$i]}', conf pede '${AREAS_ALVO_NOME[$i]}'"
      divergente=1; }
    [ -z "${AREAS_ALVO_ENCAIXE[$i]}" ] || \
      [ "${AREAS_ALVO_ENCAIXE[$i]}" = "${AREAS_TILING[$i]}" ] || {
        meow_muda "área $((i + 1)) encaixe: disco='${AREAS_TILING[$i]}', conf pede '${AREAS_ALVO_ENCAIXE[$i]}'"
        divergente=1; }
  done

  _areas_dizer_bloqueadas
  if [ "$divergente" = "0" ]; then
    [ "$rc_plano" = "$MEOW_OK" ] && meow_ok "as áreas de trabalho estão conformes"
    return "$rc_plano"
  fi
  _areas_so_no_login
  [ "$rc_plano" = "$AREAS_PENDENCIA" ] && return "$AREAS_PENDENCIA"
  return "$MEOW_DIVERGENTE"
}

# ============================================================================
# reverter
# ============================================================================
cmd_reverter() {
  _areas_dependencia || return $?
  local guardado="$AREAS_ANTES/pinned_workspaces.antes"
  if [ ! -f "$guardado" ]; then
    meow_pula "não há estado de antes em $guardado — este script nunca escreveu aqui"
    meow_info "as cópias por passagem, se houver, estão em $MEOW_ESTADO/backups/*-areas/"
    return "$AREAS_PENDENCIA"
  fi
  local texto; _areas_ler_arquivo "$guardado"; texto="$AREAS_TEXTO"
  _areas_recusar_vazio "$texto" || return "$MEOW_ERRO"
  _areas_ler_arquivo "$AREAS_ALVO"
  if [ "$texto" = "$AREAS_TEXTO" ]; then
    meow_ok "as áreas já estavam como antes da nossa primeira escrita"
    return "$MEOW_OK"
  fi

  local rc; meow_escrever "$AREAS_ALVO" "$texto" 644; rc=$?
  case "$rc" in
    "$MEOW_ERRO") meow_erro "não consegui devolver $AREAS_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_DIVERGENTE")
      meow_seco && meow_muda "devolveria as áreas de trabalho de antes" \
                || { meow_muda "áreas de trabalho devolvidas ao estado de antes"; _areas_so_no_login; } ;;
    *) meow_ok "as áreas já estavam como antes da nossa primeira escrita" ;;
  esac
  # O `.antes` NÃO é apagado: ele é o único registro do que havia antes deste
  # projeto encostar no arquivo, e uma segunda passagem de `aplicar` depois de um
  # `reverter` precisa dele intacto para poder voltar de novo.
  meow_registrar "areas.sh reverter rc=$rc"
  return "$rc"
}

# ============================================================================
# desalfinetar — a faca, e ela vem embainhada
# ============================================================================
# Ver o fato 1 do cabeçalho: isto APAGA uma área de trabalho. Por isso mora
# fora do `aplicar`, exige `MEOW_SIM=1` (o mesmo pedágio do `meow desfazer`) e
# imprime o que se perde ANTES de perguntar.
cmd_desalfinetar() {
  local alvo="${1:-}"
  [ -n "$alvo" ] || { meow_erro "uso: areas.sh desalfinetar <nome>"; return "$MEOW_ERRO"; }
  _areas_dependencia || return $?
  _areas_ler || return $?

  local i achado=-1
  for i in "${!AREAS_NOME[@]}"; do
    [ "$(_areas_sem_folga "${AREAS_NOME[$i]}")" = "$alvo" ] && { achado="$i"; break; }
  done
  if [ "$achado" -lt 0 ]; then
    meow_erro "não há área alfinetada chamada '$alvo'"
    meow_info "as que existem:  ./scripts/areas.sh estado"
    return "$MEOW_ERRO"
  fi
  if [ "${#AREAS_NOME[@]}" -le 1 ]; then
    meow_erro "recusado: '$alvo' é a última área alfinetada"
    meow_aviso "sem nenhum alfinete o cosmic-comp destrói o workspace ao esvaziar."
    return "$MEOW_ERRO"
  fi

  meow_aviso "TIRAR O ALFINETE DE '$alvo' (id ${AREAS_ID[$achado]:-<sem id>}) CUSTA:"
  meow_aviso "  · o nome some — o painel passa a mostrar a POSIÇÃO da área;"
  meow_aviso "  · a área é DESTRUÍDA pelo cosmic-comp assim que ficar vazia;"
  meow_aviso "  · as áreas seguintes ANDAM uma posição, e o que dependia da"
  meow_aviso "    posição delas (atalhos, parking de janela) passa a mirar outra."
  if [ "${MEOW_SIM:-0}" != "1" ]; then
    meow_erro "não fiz nada. Se é isso mesmo que você quer:"
    meow_erro "  MEOW_SIM=1 ./scripts/areas.sh desalfinetar '$alvo'"
    return "$AREAS_PENDENCIA"
  fi
  if _areas_vizinho_manda "${AREAS_ID[$achado]}"; then
    meow_erro "'$alvo' é um alfinete do Ritual da Aurora: ele o recria na próxima hora."
    _areas_dizer_bloqueadas
    meow_aviso "tire-o da lista MANAGED de $AREAS_VIZINHO_FONTE primeiro."
    return "$AREAS_PENDENCIA"
  fi

  local novo erro
  erro="$(_areas_motor tirar "$AREAS_ALVO" "$achado" 2>&1 >/dev/null)"
  [ -n "$erro" ] && { meow_erro "não consegui tirar a área: $erro"; return "$MEOW_ERRO"; }
  _areas_montar_texto tirar "$AREAS_ALVO" "$achado"
  novo="$AREAS_TEXTO"
  _areas_recusar_vazio "$novo" || return "$MEOW_ERRO"

  _areas_guardar || return "$MEOW_ERRO"
  local rc; meow_escrever "$AREAS_ALVO" "$novo" 644; rc=$?
  case "$rc" in
    "$MEOW_ERRO") meow_erro "não consegui gravar $AREAS_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_DIVERGENTE")
      meow_seco && meow_muda "tiraria o alfinete de '$alvo'" \
                || { meow_muda "alfinete de '$alvo' retirado"; _areas_so_no_login
                     meow_info "para voltar atrás:  ./scripts/areas.sh reverter" ; } ;;
  esac
  meow_registrar "areas.sh desalfinetar '$alvo' rc=$rc"
  return "$rc"
}

case "${1:-estado}" in
  estado)        cmd_estado ;;
  conferir)      cmd_conferir ;;
  aplicar)       cmd_aplicar ;;
  reverter)      cmd_reverter ;;
  desalfinetar)  shift; cmd_desalfinetar "${1:-}" ;;
  *) meow_erro "uso: areas.sh {estado|conferir|aplicar|reverter|desalfinetar <nome>}"
     exit "$MEOW_ERRO" ;;
esac

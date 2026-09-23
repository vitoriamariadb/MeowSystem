#!/usr/bin/env python3
"""pack.py — o único que entende o formato de theme pack. Só stdlib.

POR QUE UM SÓ
    Antes desta porta, onze lugares liam a paleta e dez cravavam o nome do
    arquivo. Não dava erro: dava DIVERGÊNCIA SILENCIOSA — o tema do COSMIC vinha
    de uma paleta e o terminal, os ícones e o painel de outra. Um formato de pack
    com dois interpretadores repetiria o mesmo defeito num tamanho maior.

    Então: este arquivo é o único que abre um `pack.json`. O shell consulta por
    `python3 scripts/pack.py <verbo>`; o Python importa ou consulta igual. Quem
    precisar de um campo novo mexe aqui, e só aqui.

POR QUE PYTHON, E NÃO SHELL
    Dos onze consumidores de paleta, seis são Python. E o validador promete
    "recuso antes de escrever" — uma promessa que um validador que EXECUTA o que
    valida não pode fazer. `pack.json` é dado; ninguém o executa.

VERBOS
    validar <caminho-ou-id>      confere o pack inteiro. 0 = ok, 1 = recusado.
    construir <id> [--seco]      refaz o que o pack declara como derivado,
                                 escrevendo SÓ dentro do pack. Ver cmd_construir.
    caminho <id> <categoria>     imprime o caminho que aquela categoria resolve
    acervo  <id> <categoria> [arquivo]
                                 resolve um acervo PACK -> HERANÇA -> nada.
                                 NÃO é o `caminho`: aquele olha só o pack, este
                                 sobe a cadeia de herança. Ver a função `acervo`.
    onde    <id> <categoria> [padrao]
                                 o diretório onde aquele acervo MORA, exista ele
                                 ou não. É a porta de quem ESCREVE; o `acervo`
                                 acima é a de quem lê. Ver `dir_acervo`.
    alvo    <base>               resolve os alvos de mapa que chegam pelo STDIN,
                                 um por linha: `motor:x` cai em assets/icones/,
                                 `pack:<id>:x` em <aquele pack>/icones/, sem
                                 prefixo cai na <base>. `~/` e caminho absoluto
                                 são recusados. Uma linha de saída por linha de
                                 entrada; vazia = recusada.
    fontes  [id]                 cada nome de ícone de `scalable/apps` e o
                                 arquivo de onde ele sai, um por linha:
                                 `nome<TAB>fonte<TAB>camada`. Um nome com duas
                                 linhas é empate. Ver `fontes`.
    fonte   <nome> [id]          as linhas de `fontes` daquele nome. 0 = uma
                                 fonte só; 1 = nenhuma, ou mais de uma.
    sincronizar <id>             compara cada arte copiada do PROCEDENCIA.md com
                                 a origem dela. SÓ LÊ. 0 = em dia, 1 = algum
                                 lado andou. Ver `cmd_sincronizar`.
    captura <par>                onde ESTÁ a captura <flavor>-<accent>, subindo
                                 pack -> herança -> motor. 1 = não existe.
    captura-destino <par>        onde uma captura NOVA deve ser escrita. Nunca
                                 sobe pela herança: escrita é no pack ATIVO.
    capturas                     os nomes das capturas alcançáveis, uma por linha
    app     <id> apps.<app>.<chave>
                                 o que o pack declara para um APLICATIVO, ou o
                                 que ele herda. Imprime, para o shell avaliar:
                                     pack=<quem respondeu>
                                     valor=<o nome, ou o caminho se for arquivo>
                                 1 = ninguém na cadeia declara. Ver `tema_de_app`.
    paleta  <id>                 imprime o caminho da paleta do pack
    logo    <id> [flavor] [accent]
                                 imprime o logo.svg do pack com as cores
                                 resolvidas por PAPEL para aquele flavor. É a
                                 porta de quem MOSTRA o logo. Ver `logo()`.
    logo-gerado <id> [flavor] [accent]
                                 imprime o logo gerado (a inicial sobre o base,
                                 o accent de contorno). Não escreve: quem o põe
                                 no pack é a pessoa, com `>`.
    de-csv  <arquivo.csv>        a paleta.json equivalente a um CSV de três
                                 colunas (slot,flavor,hex), no STDOUT. O claro
                                 que faltar sai derivado pelo método do Latte,
                                 e a régua de contraste avisa no STDERR sem
                                 bloquear. Não escreve. Ver `paleta_de_csv`.
    som     <id>                 o timbre do pack, como CHAVE=valor para o shell
    info    <id>                 o que é próprio, o que é herdado, o que falta
    raizes                       imprime as raízes de busca, na ordem
    padrao                       o diretório do pack PADRÃO, resolvido pelas
                                 raízes como qualquer outro. É o que o shell
                                 pergunta em vez de cravar o nome dele.

    Sem argumento, imprime esta ajuda.

O CONTRATO ESTÁ EM docs/PACKS.md, e ele manda. Se este arquivo e aquele
documento discordarem, o documento está certo e este arquivo tem um defeito.
"""

import hashlib
import json
import os
import re
import sys
# `defusedxml` não, e o motivo é o "Só stdlib" do topo: a proteção que ele daria
# contra entidade maliciosa é feita à mão no `_ler_logo`, que recusa `<!ENTITY`
# antes de o parser ver o arquivo. O expat do Python não busca DTD externo.
import xml.etree.ElementTree as ET

FORMATO_MIN = 1
FORMATO_MAX = 1

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Os 26 nomes, na ordem canônica. Eles são o VOCABULÁRIO do projeto, não "as
# cores do Catppuccin" — ver docs/PACKS.md, seção "As 26 cores".
SLOTS = [
    "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
    "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender",
    "text", "subtext1", "subtext0", "overlay2", "overlay1", "overlay0",
    "surface2", "surface1", "surface0", "base", "mantle", "crust",
]

RE_ID = re.compile(r"^[a-z0-9][a-z0-9-]*$")
RE_HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
RE_SHA256 = re.compile(r"^[0-9a-f]{64}$")

OK, RECUSADO, ERRO_USO = 0, 1, 2

# OS CAMPOS QUE O PROJETO DE FATO LÊ — 21/09/2026
#
# POR QUE ESTA LISTA EXISTE
#   Uma varredura de acoplamento mediu que metade do que o `packs/dracula/`
#   declara NÃO TEM UM ÚNICO LEITOR em código: o `grep -rn nome_da_paleta`
#   devolvia a spec em docs/PACKS.md, a declaração no pack.json, e mais nada.
#   O pack previu um defeito, declarou o conserto, e o conserto era decorativo —
#   o tema Dracula aparecia na GUI do COSMIC chamado `catppuccin-dracula`.
#
#   Um formato que aceita declaração morta ENSINA a escrever declaração morta.
#   Quem escreve um pack novo copia o do Dracula e repete os campos mortos,
#   acreditando que eles fazem alguma coisa. Por isso o `validar` passa a dizer,
#   em voz alta, quais campos daquele pack ninguém vai ler.
#
# É AVISO, E NÃO RECUSA
#   Um campo sem leitor hoje pode ser o campo que a sprint seguinte vai ler, e
#   recusar o pack por causa dele quebraria packs que já funcionam. O que não
#   pode é o silêncio.
#
# ESCRITA À MÃO, E O PORQUÊ ESTÁ MEDIDO
#   Derivar esta lista de um `grep` seria mais bonito e estaria errado: nomes
#   como `mapa`, `tipo`, `tema`, `arquivo` e `versao` aparecem às dezenas em
#   código que não tem nada a ver com pack — medido no dia, `mapa` dá 13 linhas
#   e nenhuma delas lê um pack.json. Uma lista que mente por excesso é pior que
#   nenhuma: ela cala justamente o campo morto.
#
#   O PREÇO: quem der leitor a um campo precisa escrever o nome aqui. O
#   `tests/pack.sh` cobra a lista contra o `packs/dracula/`, que é o pack mais
#   completo que existe — então um campo novo sem entrada aqui aparece lá.
#
# O `*` CASA UM SEGMENTO INTEIRO. `icones.*.herda` vale para apps, pastas,
# mimetypes e autorais; `som.*` vale para as sete chaves que os LIMITES conhecem.
CAMPOS_COM_LEITOR = {
    "formato", "id", "nome",            # identidade — validar
    "heranca",                          # validar, cmd_info, acervo
    "creditos",                         # validar cobra a existência do arquivo
    "paleta", "paleta.arquivo",         # validar, verbo `paleta`, cmd_info
    "paleta.flavor_padrao",             # validar
    "cosmic.mapa",                      # validar cobra a existência
    "cosmic.nome_da_paleta",            # scripts/gerar_temas.py
    "temas.capturados",                 # `captura`, `captura_destino`, `capturas`
    "icones.*.mapa",                    # validar, app/servidor.py via `acervo`
    "icones.*.desenhos",                # validar, `acervo`
    # `*.*.herda` e não `icones.*.herda`: o bloco de heranças do `validar` varre
    # `icones` E `origens` juntos, e o `acervo` sobe a cadeia de qualquer
    # categoria. Restringir a `icones` faria o aviso acusar de morto o
    # `origens.cursores.herda`, que é lido — e um aviso que mente por excesso
    # ensina a ignorar o aviso.
    "*.*.herda",                        # validar, `acervo`
    "som.*",                            # validar, cmd_som
    # O BLOCO `apps` — 22/09/2026, sprint P18. Só as chaves que JÁ têm leitor:
    # `apps.*.tema` (obsidian) e as dos outros cinco módulos entram no dia em
    # que aqueles módulos passarem a perguntar ao pack. Declará-las antes seria
    # ensinar a promessa vazia que este bloco inteiro veio caçar.
    "apps.*.arquivo",                   # validar, `tema_de_app`, qbittorrent
    "apps.*.sha256",                    # validar, qbittorrent
    "apps.*.spicetify_tema",            # spotify
    "apps.*.esquema",                   # spotify
    "apps.*.acento_no_color_ini",       # spotify
    "apps.*.origem.*",                  # spotify (de onde o tema desce)
    # OS METADADOS E A VITRINE — 23/09/2026, sprint P15. `autor`, `versao` e
    # `licenca` estavam no aviso de campo morto do Dracula desde a P20, e o
    # `packs/catppuccin/pack.json` deixou de declará-los justamente por isso
    # ("quando a P15 der leitor a eles, eles entram"). Deu: o `cmd_info` imprime
    # os três, e o `autor` vai para o cartão do painel.
    #
    # A vitrine vai campo a campo, e NÃO como `vitrine.*`: a máscara larga
    # calaria o erro de digitação — um `vitrine.descricao_curto` passaria por
    # lido, e é exatamente o campo morto que este aviso existe para nomear.
    "autor", "versao", "licenca",       # cmd_info; `autor` também no /api/packs
    "vitrine.capa",                     # `vitrine` e `logo()` (P25): a capa É o logo
    "vitrine.descricao_curta",
    "vitrine.descricao",
    "vitrine.tags",
    "vitrine.capturas",
    "vitrine.site",
}


def _tem_leitor(trilha):
    partes = trilha.split(".")
    for mascara in range(1 << len(partes)):
        cand = ".".join("*" if (mascara >> i) & 1 else p
                        for i, p in enumerate(partes))
        if cand in CAMPOS_COM_LEITOR:
            return True
    return False


def campos_sem_leitor(no, trilha=""):
    """As trilhas declaradas neste pack.json que nenhum código lê. Ordenadas."""
    achados = []
    for chave, valor in (no or {}).items():
        # `_nota`, `_nota_heranca`, `_comentario`: prosa do autor do pack, e ela
        # é para ler com os olhos. Cobrá-la como campo morto seria punir quem
        # documentou.
        if str(chave).startswith("_"):
            continue
        aqui = f"{trilha}.{chave}" if trilha else str(chave)
        if isinstance(valor, dict):
            achados += campos_sem_leitor(valor, aqui)
        elif not _tem_leitor(aqui):
            achados.append(aqui)
    return sorted(achados)


def raizes():
    """As três raízes de busca, na ordem de precedência de docs/PACKS.md."""
    saida = []
    if os.environ.get("MEOW_PACKS"):
        saida.append(os.environ["MEOW_PACKS"])
    xdg = os.environ.get("XDG_DATA_HOME") or os.path.join(
        os.path.expanduser("~"), ".local", "share")
    saida.append(os.path.join(xdg, "meowsystem", "packs"))
    saida.append(os.path.join(RAIZ, "packs"))
    return saida


# O PACK PADRÃO, E ELE É UM PACK COMO OS OUTROS DESDE 22/09/2026
#
# O QUE ESTAVA ESCRITO AQUI ATÉ ONTEM, E POR QUE SAIU
#   Era `PACK_EMBUTIDO = "catppuccin"`, com uma função `eh_embutido` ao lado e um
#   `achar` que devolvia a RAIZ do projeto para ele: o pack padrão não morava em
#   `packs/`, não tinha `pack.json`, e a paleta dele era um arquivo dentro de
#   `assets/`. O comentário de 17/09/2026 dizia, com todas as letras, que aquilo
#   era exceção temporária e que "quando a mudança acontecer, esta constante e a
#   função `eh_embutido` somem". A mudança aconteceu; elas sumiram.
#
#   O PREÇO DA EXCEÇÃO ERA MEDIDO: enquanto o padrão fosse código, todo pack de
#   terceiro era cidadão de segunda classe. O Dracula é a prova — ele herda sete
#   categorias de um "embutido" que não tinha `pack.json` onde declarar nenhuma
#   delas, e o `meow pack listar` precisava de uma linha especial para que a
#   lista não mentisse por omissão.
#
#   E O QUE FALHAVA CALADO: `pack.py validar catppuccin` estourava um
#   FileNotFoundError em `RAIZ/pack.json`, porque o `achar` devolvia a RAIZ e lá
#   não há `pack.json`. O `meow_pack_dir` desviava antes com uma linha que
#   comparava o nome do pack com "catppuccin". As duas saíram juntas.
#
# O NOME MORA AQUI E SÓ AQUI. Quem precisa dele — o shell, os sete consumidores
# de paleta em Python, o painel — pergunta, e a pergunta é `dir_padrao()` ou o
# verbo `padrao`. Um segundo lugar que crave "catppuccin" é a divergência
# silenciosa de volta, por outra porta.
PACK_PADRAO = "catppuccin"


def achar(ref):
    """Aceita um id ou um caminho. Devolve o diretório do pack, ou None."""
    if os.path.isdir(ref) and os.path.isfile(os.path.join(ref, "pack.json")):
        return os.path.abspath(ref)
    for base in raizes():
        cand = os.path.join(base, ref)
        if os.path.isfile(os.path.join(cand, "pack.json")):
            return os.path.abspath(cand)
    return None


def dir_padrao():
    """O diretório do pack padrão.

    A QUEDA PARA `RAIZ/packs/<padrao>` NÃO É REDUNDÂNCIA
        `achar` procura nas três raízes, e a terceira é exatamente essa — então
        num repositório inteiro as duas respostas são a mesma. Elas divergem
        quando o pack padrão foi APAGADO: aí o `achar` devolve None e quem
        chamou receberia um caminho vazio, que vira `open("")` lá adiante e uma
        mensagem que não nomeia arquivo nenhum. Devolver o caminho onde ele
        DEVERIA estar faz o erro dizer o que falta.
    """
    return achar(PACK_PADRAO) or os.path.join(RAIZ, "packs", PACK_PADRAO)


def paleta_do_pack_ativo():
    """O arquivo de paleta que vale AGORA. É a porta única do lado Python.

    POR QUE ELA NASCEU [22/09/2026]
        Estas três linhas estavam repetidas em SEIS arquivos — `gerar_temas.py`,
        `gerar_icones_autorais.py`, `folha_conversor.py`, `folha_marcas.py`,
        `folha_proposta.py` e `app/servidor.py` —, e as seis terminavam no mesmo
        literal: `assets/paleta/catppuccin.json`. Contados em 22/09/2026; com o
        `lib/comum.sh`, o próprio `pack.py` e o `derivar_claro.py`, davam NOVE
        pontos de código cravando aquele caminho. O cabeçalho do `meow_paleta`
        (lib/comum.sh) isentava esses consumidores de chamar a porta única
        "porque um import entre `scripts/` e `app/` traria um problema de
        sys.path que este projeto não tem hoje".

        A isenção deixou de ser necessária em 21/09/2026, e por duas portas que
        já existem: `scripts/*.py` importam este arquivo como VIZINHO (é o que o
        `gerar_temas.py` já faz para ler `cosmic.nome_da_paleta`), e o painel
        carrega este arquivo por caminho no `modulo_pack()` do `app/servidor.py`,
        sem tocar no `sys.path` de ninguém.

    A ORDEM É A MESMA DO `meow_paleta`, E ISSO É O CONTRATO
        1. $MEOW_PALETA      caminho completo — a ponte, ou a escolha da pessoa
        2. $MEOW_PACK_DIR    o pack ativo, que a ponte shell->Python exportou
        3. $PALETA_ARQUIVO   só o nome, dentro de assets/paleta/ (chave legada)
        4. o pack PADRÃO
        Duas resoluções da mesma coisa em ordens diferentes é como o tema do
        COSMIC vem de uma paleta e o terminal de outra, sem erro nenhum na tela.

    O PASSO 3 SOBREVIVEU À MUDANÇA, E SOBREVIVEU VAZIO
        `PALETA_ARQUIVO` nasceu em 11/09/2026, antes de o formato de pack
        existir, e nunca chegou ao `meow.conf.exemplo`. Hoje `assets/paleta/`
        só tem o `cosmic-map.json`, que é do motor — então a chave não aponta
        para nada que venha de fábrica. Ela fica porque alguém pode ter posto a
        paleta dele ali, e tirá-la quebraria essa máquina calada. O jeito certo
        de trocar de paleta é um pack, e é o que docs/PACKS.md ensina.
    """
    da_pessoa = os.environ.get("MEOW_PALETA")
    if da_pessoa:
        return da_pessoa
    pack_dir = os.environ.get("MEOW_PACK_DIR")
    if pack_dir:
        alvo = os.path.join(pack_dir, "paleta.json")
        if os.path.isfile(alvo):
            return alvo
    nome = os.environ.get("PALETA_ARQUIVO")
    if nome:
        return os.path.join(RAIZ, "assets", "paleta", nome)
    return os.path.join(dir_padrao(), "paleta.json")


def campo(ref, trilha, padrao=None):
    """Um campo declarado no pack.json, pela trilha pontuada: 'cosmic.nome_da_paleta'.

    POR QUE ELA NASCEU [21/09/2026]
        Uma varredura de acoplamento mediu que `cosmic.nome_da_paleta`,
        `cosmic.mapa`, `icones.*.herda`, `icones.apps.camada`, `origens.*` e
        `claro_de_reserva` eram DECLARAÇÕES SEM LEITOR: o `grep` achava a spec em
        docs/PACKS.md, a declaração no pack.json, e nenhum arquivo de código.
        O `packs/dracula/pack.json` declarava `nome_da_paleta` EXATAMENTE para
        impedir que o tema aparecesse como `catppuccin-dracula` na GUI do COSMIC
        — e era assim que ele aparecia, porque o conserto não tinha leitor.

        Um formato que aceita declaração morta ensina a escrever declaração
        morta. Esta função é a porta por onde um campo passa a ser lido.

    ELA NÃO VALIDA, E ISSO É DE PROPÓSITO
        `validar` abre a paleta inteira, confere 26 slots por flavor e mede
        contraste. Quem quer UM campo não deve pagar por isso — e um pack que
        está sendo usado já passou pela validação em outro lugar. Pack ausente,
        pack.json ilegível ou campo não declarado devolvem `padrao`, sem levantar:
        o chamador trata a ausência como "o pack não pediu nada".
    """
    dir_pack = achar(ref)
    if not dir_pack:
        return padrao
    try:
        with open(os.path.join(dir_pack, "pack.json"), encoding="utf-8") as fh:
            no = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return padrao
    for parte in trilha.split("."):
        if not isinstance(no, dict) or parte not in no:
            return padrao
        no = no[parte]
    # `null` declarado é ausência dita em voz alta — o `cosmic.mapa: null` do
    # Dracula quer dizer "use o mapa do núcleo inteiro". Devolver None aqui e
    # `padrao` seria a mesma resposta em duas palavras.
    return padrao if no is None else no


def acervo(categoria, arquivo="", motor=None, ref=None):
    """Um arquivo de acervo, resolvido PACK ATIVO -> HERANÇA -> MOTOR.

    O NOME NÃO É `caminho`, E O MOTIVO FOI MEDIDO [21/09/2026]
        `caminho` já está tomado: o `meow_pack_dir` do lib/comum.sh chama
        `pack.py caminho "$PACK" id` como SONDA DE EXISTÊNCIA — ele joga a saída
        fora e só olha o código de retorno. Reaproveitar o nome para outra
        semântica faria todo script de shell deixar de enxergar o pack, sem erro
        nenhum na tela. É o tipo de defeito que só se descobre depois de quebrar,
        e por isso o verbo novo é `acervo`.

    AS SETE FORMAS VIRAM UMA
        A mesma varredura de 21/09 contou SETE padrões distintos de achar um
        arquivo de acervo neste projeto. O `meow_pack_arquivo` (o certo) tinha
        dois usuários; o caminho cravado sob `$RAIZ/assets/` tinha doze. Esta é a
        forma em Python, e ela segue a MESMA ordem do `meow_pack_arquivo`.

    OS ARGUMENTOS
        categoria  a trilha que o pack.json usa para declarar onde o acervo mora
                   — 'icones.apps.mapa', 'icones.pastas.desenhos'.
        arquivo    o nome de dentro daquele acervo. Vazio quando a declaração JÁ
                   é o arquivo, que é o caso do `icones.apps.mapa`.
        motor      o caminho relativo à RAIZ para quem ainda não migrou o acervo
                   para dentro de um pack. Vem do CHAMADOR, e não de uma tabela
                   aqui dentro, porque o motor não tem manifesto que diga onde
                   cada categoria mora.

                   ELE PERDEU A RAZÃO DE SER EM 22/09/2026, e não foi apagado
                   junto. O `packs/catppuccin/` nasceu, e com ele o manifesto que
                   faltava: hoje toda categoria do pack padrão está declarada num
                   `pack.json`, e a herança resolve o que o `motor` resolvia. Ele
                   fica porque um pack de terceiro instalado fora daqui pode
                   apontar para um acervo do núcleo, e porque a regra da casa é
                   apontar o código morto, não apagá-lo — quem o tirar tira junto
                   as quedas que os chamadores ainda passam.
        ref        qual pack. O padrão é o que a ponte shell->Python exportou em
                   `MEOW_PACK_DIR`; vazio cai no pack PADRÃO.

    Devolve None quando não existe em lugar nenhum: ausência é resposta, e quem
    chama decide se ela é erro.
    """
    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    # A HERANÇA PODE SER CIRCULAR, E UM PACK DE TERCEIRO PODE ESCREVÊ-LA ASSIM
    #   Dois packs que herdam um do outro pendurariam o painel num laço infinito.
    #   O conjunto de vistos custa uma linha e transforma o travamento em "não
    #   achei", que é uma resposta que a pessoa consegue ler.
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        dir_pack = achar(ref)
        if not dir_pack:
            break
        declarado = campo(ref, categoria)
        if isinstance(declarado, str):
            # O CAMINHO DECLARADO TEM DE CAIR DENTRO DO PACK [22/09/2026]
            #   `validar` já aplica o `_dentro` em `icones.*.mapa`, `desenhos` e
            #   `cosmic.mapa` — e esta função NÃO valida nada antes de ler, como
            #   o `campo` explica duas telas acima. As duas coisas juntas abriam
            #   a porta: um pack de terceiro com `"mapa": "../../../etc/algo"`
            #   era aberto e lido, porque aqui só se perguntava `os.path.exists`.
            #   O impacto é baixo (lê-se um mapa de ícone), mas a P20 é
            #   exatamente a sprint do pack de terceiro — e a guarda que o
            #   validador já escreveu custa três linhas aqui.
            #
            #   Sair do pack é IGNORAR aquela camada, e não levantar: quem chama
            #   o `acervo` espera "achei" ou "não achei", e a herança logo abaixo
            #   ainda pode ter a resposta certa. O que não pode é passar calado —
            #   o aviso vai para o stderr com o nome do campo, como o do campo
            #   sem leitor.
            #
            #   O `_dentro` é usado como GUARDA, e não como resolvedor: o que
            #   volta continua sendo o `join` de sempre. O `_dentro` devolve
            #   realpath, e trocar a resposta por ele mudaria o caminho que o
            #   chamador imprime quando a raiz do pack passa por um link — um
            #   efeito que este conserto não precisa ter.
            dentro = True
            try:
                _dentro(dir_pack,
                        os.path.join(declarado, arquivo) if arquivo else declarado,
                        categoria)
            except Recusa as e:
                print(f"  aviso {e} — esta camada foi ignorada", file=sys.stderr)
                dentro = False
            alvo = os.path.join(dir_pack, declarado, arquivo) if arquivo \
                else os.path.join(dir_pack, declarado)
            if dentro and os.path.exists(alvo):
                return alvo
        # A HERANÇA DO BLOCO VENCE A DO PACK INTEIRO. O Dracula declara
        # `heranca: "catppuccin"` no topo E `icones.mimetypes.herda:
        # "catppuccin"` no bloco — a do bloco é a que fala daquela categoria, e
        # um pack que herde só uma categoria de outro lugar precisa dela.
        bloco = categoria.rsplit(".", 1)[0]
        ref = campo(ref, bloco + ".herda") or campo(ref, "heranca")
    if motor:
        alvo = os.path.join(RAIZ, motor, arquivo) if arquivo else os.path.join(RAIZ, motor)
        if os.path.exists(alvo):
            return alvo
    return None

# O ACERVO ONDE ELE **DEVE** MORAR, EXISTA OU NÃO — 22/09/2026
#
# POR QUE ELA NÃO É O `acervo` ACIMA
#   O `acervo` é a porta de quem LÊ: ele devolve None quando o arquivo não
#   existe, e isso é a resposta certa para quem vai abrir. Quem ESCREVE precisa
#   do contrário — o diretório onde o acervo deve nascer, justamente quando ele
#   ainda não existe. O `gerar_icones_autorais.py` é o caso: num pack novo, o
#   `icones/autorais/` só passa a existir depois que ele escreve o primeiro
#   arquivo lá dentro.
#
#   Sem esta função, cada escritor montaria `<dir do pack>/<declarado>` à mão —
#   que é a mesma divergência silenciosa que o `acervo` veio matar do lado da
#   leitura, entrando de volta pela porta da escrita.
#
# ELA NÃO SOBE A HERANÇA, E ISSO É DE PROPÓSITO
#   Herdar é dizer "leia do vizinho". Escrever no acervo do vizinho seria um
#   pack gravando dentro de outro — o Dracula regeraria os autorais dentro do
#   `packs/catppuccin/`, e o dono do pack base veria arquivo aparecendo sem ter
#   pedido. Um pack que não declara a categoria recebe o `padrao` e escreve em
#   casa.
def dir_acervo(categoria, ref=None, padrao=None):
    """O diretório de um acervo do pack, para quem vai ESCREVER nele.

    Devolve o caminho mesmo que ele ainda não exista — é o contrário do
    `acervo`, que só responde o que já está no disco. Sem declaração no
    pack.json, cai no `padrao` relativo à raiz do pack.
    """
    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    dir_pack = achar(ref) or dir_padrao()
    declarado = campo(ref, categoria)
    if not isinstance(declarado, str) or not declarado:
        if not padrao:
            return None
        declarado = padrao
    # A MESMA GUARDA DO `acervo`, E PELO MESMO MOTIVO: um pack de terceiro com
    # `"desenhos": "../../../algum/lugar"` faria o gerador ESCREVER fora do
    # pack. Do lado da leitura o estrago é ler um mapa; do lado da escrita é
    # criar arquivo no disco de quem instalou. Aqui a recusa sobe — quem escreve
    # não tem uma "próxima camada da herança" para tentar.
    _dentro(dir_pack, declarado, categoria)
    return os.path.join(dir_pack, declarado)


# O PREFIXO `motor:` — A DECISÃO SAI DE `assets/` SEM O ACERVO SAIR JUNTO
#
# O QUE ELE RESOLVE [22/09/2026]
#   Um mapa de pack diz *"o Telegram veste o desenho X"*. Essa frase é decisão
#   de TEMA, e o lugar dela é o pack. Mas o desenho X pode vir do acervo
#   Arcticons — 113 SVG de terceiro que são base de conversão, ferramenta
#   compartilhada, e que não mudam quando se troca de pack.
#
#   Sem prefixo havia só duas saídas, e as duas eram ruins: ou a decisão fica em
#   `assets/` (e trocar de pack não troca a escolha), ou cada pack carrega uma
#   CÓPIA dos 113 SVG (e a segunda cópia defasa da primeira calado — é a lição
#   que a memória do Dracula-OS-Theme já tinha pago em 18/08/2026).
#
#   O prefixo é a terceira saída: a linha mora no pack, o arquivo mora no motor.
#
#     org.telegram.desktop          : motor:arcticons/telegram.svg
#     io.github.flattool.Warehouse  : apps/Warehouse.svg
#
# A BASE VEM DE QUEM CHAMA, E NÃO DE UMA CONSTANTE AQUI
#   O `icones_apps_dracula.sh` resolve os caminhos sem prefixo contra o
#   DIRETÓRIO DO MAPA, e o cabeçalho dele explica por quê: assim o mesmo mapa
#   serve ao pack e ao endereço antigo sem o script saber em qual dos dois está.
#   Cravar `<dir do pack>/icones` aqui seria uma segunda verdade sobre essa
#   raiz, e ela divergiria na primeira vez que um mapa mudasse de pasta.
#
# OS DOIS LADOS TÊM GUARDA, E O MOTIVO É O MESMO DO `acervo`
#   Sem prefixo, o alvo tem de cair dentro da base; com `motor:`, dentro de
#   `assets/icones/`. Um mapa é DADO, e um pack de terceiro escreve o dado dele:
#   `motor:../../../etc/algo` seria lido e copiado para o tema de quem instalou.
#   Três linhas de guarda contra isso é barato.
MOTOR = "motor:"
ACERVO_DO_MOTOR = os.path.join("assets", "icones")

# O PREFIXO `pack:` — A TERCEIRA FORMA DE UM ALVO, E A ÚLTIMA — 23/09/2026
#
#   A P28 fecha a lista de onde um alvo de mapa pode estar, e ela tem três
#   casas e só três: dentro do próprio pack (sem prefixo), no acervo do motor
#   (`motor:`) ou dentro de OUTRO pack (`pack:<id>:<caminho>`). É a mesma razão
#   do `motor:`, um nível ao lado: um pack que queira o Obsidian do Catppuccin
#   escreve a linha que diz isso, em vez de carregar uma cópia que defasa.
#
#     md.obsidian.Obsidian : pack:catppuccin:apps/obsidian.svg
#
#   O `<caminho>` é relativo a `<outro pack>/icones/`, que é onde mora o mapa
#   de todo pack (a forma de `packs/<id>/icones/` é a mesma para todos, P27). O
#   `<id>` passa pelo `RE_ID` antes de ir ao `achar`: o `achar` também aceita
#   CAMINHO, e sem essa guarda `pack:/qualquer/lugar:x` viraria uma quarta
#   forma de sair da raiz, pela porta que existe para não sair.
OUTRO_PACK = "pack:"


def _caminho_da_maquina(resto):
    """`~/…` ou caminho absoluto: um endereço desta máquina, e não do pack."""
    return resto.startswith("~") or os.path.isabs(resto)


def resolver_alvo(valor, base):
    """O arquivo que uma linha de mapa nomeia. Recusa o que sai da raiz.

    `motor:x` resolve em `assets/icones/x`; `pack:<id>:x` em
    `<pack id>/icones/x`; sem prefixo, contra a `base` que o chamador passa.
    Devolve o caminho EXISTA ELE OU NÃO: quem chama é que sabe se um alvo
    ausente é erro (nome no mapa sem desenho no disco) ou não.
    """
    valor = (valor or "").strip()
    if not valor:
        return ""
    if valor.startswith(MOTOR):
        raiz, resto = os.path.join(RAIZ, ACERVO_DO_MOTOR), valor[len(MOTOR):].strip()
    elif valor.startswith(OUTRO_PACK):
        id_outro, sep, resto = valor[len(OUTRO_PACK):].partition(":")
        id_outro, resto = id_outro.strip(), resto.strip()
        if not sep or not RE_ID.match(id_outro):
            raise Recusa(f"{valor!r}: a forma é 'pack:<id>:<caminho>', "
                         f"e o id só tem minúsculas, dígitos e hífen")
        dir_outro = achar(id_outro)
        if not dir_outro:
            raise Recusa(f"{valor!r}: o pack {id_outro!r} não existe em nenhuma das raízes")
        raiz = os.path.join(dir_outro, "icones")
    else:
        raiz, resto = base, valor
    if not resto:
        raise Recusa(f"{valor!r} não nomeia arquivo nenhum")
    # `~/` E CAMINHO ABSOLUTO SÃO RECUSADOS COM O NOME DELES — 23/09/2026
    #   Um absoluto já caía na guarda do `_dentro` logo abaixo, mas com a frase
    #   "sai de <raiz>", que manda procurar um `../` que não existe. E o `~/`
    #   NÃO caía em guarda nenhuma: o `join` o tratava como um diretório
    #   chamado `~` dentro da base, e a linha passava como alvo ausente — o
    #   aviso "no mapa mas sem desenho no disco", que manda procurar um desenho
    #   esquecido e não um mapa apontando para a máquina.
    #
    #   A P28 achou a forma escrita em 23 linhas de `assets/icones/*.map`, com
    #   `~/.local/share/icons/...` — o `Dracula-Icones` que o
    #   `rebuild_dracula_theme()` do Spellbook-OS reescreve (21/09 16:52:33).
    #   Medido no dia: ali ela era PROCEDÊNCIA (a coluna do meio do
    #   `apps-resgatados.map`, que o instalador não lê), e não alvo. Mas nada a
    #   recusava num mapa de pack, onde ela SERIA alvo: a arte passaria a vir
    #   de um diretório que outro programa reescreve. Um mapa aponta para o
    #   pack, para o motor ou para outro pack; arte da máquina entra por CÓPIA,
    #   com uma linha no PROCEDENCIA.md — é a regra 5, e a frase diz isso.
    if _caminho_da_maquina(resto):
        raise Recusa(f"{valor!r} é um endereço desta máquina, e não do pack. "
                     f"Copie a arte para dentro do pack e registre a origem no "
                     f"PROCEDENCIA.md — ver docs/PACKS.md, 'Fonte e derivados'")
    # A CHECAGEM É A DO `_dentro`; SÓ A FRASE MUDA
    #   O `_dentro` diz "sai de dentro do pack", que é a frase certa para ele:
    #   os cinco campos que ele guarda no `validar` são todos do pack.json. Aqui
    #   a raiz é o PACK numa metade dos casos e `assets/icones/` na outra, e
    #   dizer "do pack" sobre um alvo `motor:` mandaria procurar no lugar errado.
    #   Reimplementar a comparação para trocar a frase seria a segunda definição
    #   de "está contido", e ela divergiria da primeira — então a conta continua
    #   sendo dele e só a mensagem é reescrita aqui.
    try:
        _dentro(raiz, resto, "alvo")
    except Recusa:
        raise Recusa(f"{valor!r} sai de {raiz}") from None
    return os.path.join(raiz, resto)


def cmd_alvo(base):
    """Resolve os alvos que chegam pela ENTRADA PADRÃO, um por linha.

    POR QUE PELO STDIN, E NÃO UM POR CHAMADA [22/09/2026]
        O chamador natural é um laço de shell sobre um mapa, e o do
        `icones_apps_dracula.sh` tem 18 linhas hoje. Medido aqui no dia: 18
        partidas de `python3` custam 1,1 s — e esse laço roda dentro do
        `meow doctor`, que é o comando das 5h. Um mapa de 100 aplicativos
        custaria seis segundos, e a regressão apareceria como "o doctor ficou
        lento", longe da causa.

        Em lote é UMA partida para o mapa inteiro.

    O CONTRATO É UMA LINHA DE SAÍDA POR LINHA DE ENTRADA, E ELE IMPORTA
        Quem chama junta esta saída com os NOMES do mapa, lado a lado — e um
        `paste` que perde o alinhamento veste cada aplicativo com o ícone do
        vizinho, sem erro nenhum na tela. Por isso a linha recusada sai VAZIA em
        vez de sair fora: vazio não casa com arquivo nenhum e cai no aviso "no
        mapa mas sem desenho no disco" que o chamador já tem. O porquê da recusa
        vai para o stderr, com o valor que a causou.
    """
    for linha in sys.stdin:
        try:
            print(resolver_alvo(linha.rstrip("\n"), base))
        except Recusa as e:
            print(f"  aviso {e} — linha ignorada", file=sys.stderr)
            print()
    return OK


# --- A FONTE ÚNICA: um nome, um arquivo — P28, 23/09/2026 ------------------
#
# A PERGUNTA QUE ISTO RESPONDE
#   "De onde sai o ícone do Waterfox?" Até hoje responder exigia ler três
#   mapas e dois scripts: o `apps.map` do pack, o `apps-resgatados.map` do
#   motor, e os dois instaladores que escrevem no MESMO `scalable/apps/` — cada
#   um com o seu parser. Dois acervos oferecendo o mesmo nome ali não davam
#   erro: davam o último que escreveu, e o `meow doctor` "consertando" um para o
#   outro todo dia.
#
# A CAMADA É `scalable/apps`, E SÓ ELA, DE PROPÓSITO
#   É o diretório onde dois donos disputam o MESMO arquivo. O Arcticons e os
#   convertidos moram no `48x48/apps`, e um nome que exista lá e aqui não é
#   empate: é a precedência que ele escolheu com os dois lados na mesa em
#   16/09/2026 ("Dracula vence tudo", registrado no `icones_apps_dracula.sh`),
#   com um interruptor que devolve o Arcticons sem apagar nada. Contar aquilo
#   como "duas fontes" transformaria uma escolha documentada em erro.
#
# O PARSER É O MESMO DO SHELL, LINHA A LINHA
#   `nome` é o que vem antes do PRIMEIRO `:`, `alvo` é o resto, e o comentário
#   é cortado ANTES — o formato de docs/PACKS.md, e o que o `_dracula_pares`
#   faz com `sed` + `awk` desde 22/09/2026 (o cabeçalho dele conta o dia em que
#   o `$2` do `awk` truncava o `motor:`). São duas cópias do parser, uma em cada
#   língua, porque o shell não pode importar esta e esta não pode chamar aquela
#   sem pagar uma partida de `bash` por mapa. O `tests/fonte-unica.sh` confere
#   as duas contra o mesmo mapa.

# O mapa do motor que também escreve em `scalable/apps`. A coluna do meio dele
# é PROCEDÊNCIA (onde o PNG foi achado em 11/09/2026) e ninguém a instala — o
# desenho é sempre `assets/icones/resgatados/<nome>.svg`, e é só o NOME que se
# lê daqui, como o `icones_resgatados.sh` faz (`NF>=3`, primeiro campo).
MAPA_RESGATADOS = os.path.join("assets", "icones", "apps-resgatados.map")
ACERVO_RESGATADOS = os.path.join("assets", "icones", "resgatados")


def ler_mapa(caminho):
    """(linha, nome, alvo) de cada linha útil de um mapa `nome : alvo`."""
    with open(caminho, encoding="utf-8") as fh:
        for num, linha in enumerate(fh, 1):
            util = linha.split("#", 1)[0]
            nome, sep, alvo = util.partition(":")
            nome, alvo = nome.strip(), alvo.strip()
            if sep and nome and alvo:
                yield num, nome, alvo


def _relativo(caminho):
    """O caminho como a pessoa o reconhece: relativo à raiz, quando mora nela."""
    if caminho.startswith(RAIZ + os.sep):
        return os.path.relpath(caminho, RAIZ)
    return caminho


def _pack_de(caminho):
    """O id do pack que contém `caminho` — o diretório com pack.json acima dele."""
    d = os.path.dirname(os.path.abspath(caminho))
    while d and d != os.path.dirname(d):
        if os.path.isfile(os.path.join(d, "pack.json")):
            return os.path.basename(d)
        d = os.path.dirname(d)
    return "?"


def fontes(ref=None):
    """Cada (nome, fonte, camada) da camada `scalable/apps`, na ordem dos mapas.

    Um nome que aparece duas vezes é EMPATE — a regra 1 da P28, "um nome, uma
    fonte". Esta função não decide o empate nem o esconde: devolve as duas
    linhas, e quem chama diz o que fazer com elas (o `fonte` recusa, o
    `tests/fonte-unica.sh` falha). A fonte vem como está no disco, exista ela
    ou não: "nome no mapa sem desenho" é a outra metade da regra, e também é
    de quem chama.

    Linha que o `resolver_alvo` recusa não vira fonte — o motivo vai para o
    stderr, e o `validar` recusa o pack inteiro por ela.
    """
    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    saida = []
    mapa = acervo("icones.apps.mapa", ref=ref)
    if mapa:
        base, camada = os.path.dirname(mapa), OUTRO_PACK + _pack_de(mapa)
        for num, nome, alvo in ler_mapa(mapa):
            try:
                saida.append((nome, _relativo(resolver_alvo(alvo, base)), camada))
            except Recusa as e:
                print(f"  aviso {_relativo(mapa)}:{num}: {e}", file=sys.stderr)
    resg = os.path.join(RAIZ, MAPA_RESGATADOS)
    if os.path.isfile(resg):
        with open(resg, encoding="utf-8") as fh:
            for linha in fh:
                campos = linha.split("#", 1)[0].split(":")
                nome = campos[0].strip()
                if len(campos) >= 3 and nome:
                    saida.append((nome, os.path.join(ACERVO_RESGATADOS, nome + ".svg"),
                                  "resgatados"))
    return saida


def cmd_fontes(ref):
    for nome, fonte, camada in fontes(ref):
        print(f"{nome}\t{fonte}\t{camada}")
    return OK


def cmd_fonte(nome, ref):
    """As fontes de UM nome. 0 = exatamente uma, e ela existe no disco."""
    achadas = [(f, c) for n, f, c in fontes(ref) if n == nome]
    for fonte, camada in achadas:
        print(f"{nome}\t{fonte}\t{camada}")
    if not achadas:
        print(f"  aviso nenhum mapa de scalable/apps nomeia {nome!r} — o ícone "
              f"vem do tema herdado ou do próprio aplicativo", file=sys.stderr)
        return RECUSADO
    if len(achadas) > 1:
        print(f"  aviso {nome!r} tem {len(achadas)} fontes — um nome, uma fonte "
              f"(regra 1 da P28). O instalador que rodar por último vence, e o "
              f"doctor os troca um pelo outro todo dia.", file=sys.stderr)
        return RECUSADO
    fonte = achadas[0][0]
    if not os.path.isfile(fonte if os.path.isabs(fonte) else os.path.join(RAIZ, fonte)):
        print(f"  aviso {nome!r} está no mapa e {fonte} não existe", file=sys.stderr)
        return RECUSADO
    return OK


# --- SINCRONIZAR: a cópia e a origem, lado a lado — regra 8 da P28 ----------
#
# POR QUE ELE SÓ LÊ, E ISSO NÃO É CAUTELA DE ENFEITE [23/09/2026]
#   A regra 5 manda COPIAR arte de terceiro para dentro do pack, e a cópia
#   congela: o `Dracula-Icones` é reconstruído pelo `rebuild_dracula_theme()`
#   do Spellbook-OS a partir de outro repositório, que continua andando. Sem
#   caminho de volta, a cópia defasa e ninguém percebe.
#
#   Mas o caminho de volta não pode copiar sozinho. Uma arte retocada AQUI
#   depois da cópia é trabalho de alguém, e um `git pull` do outro repositório
#   não pode apagá-la — é a frase da P28, e é o motivo de este verbo não ter
#   um ramo que escreva. Ele diz qual lado andou e imprime o `cp` para quem
#   decidir; o gesto é da pessoa.
#
# QUAL LADO ANDOU: o registro decide
#   Só com a cópia e a origem na mão não dá para saber quem mudou — as duas
#   diferem, e é tudo. O `sha256` do PROCEDENCIA.md é o terceiro ponto: é a
#   cópia no dia da cópia. Com ele, "a cópia mudou e a origem não" é retoque
#   daqui, e "a origem mudou e a cópia não" é o upstream.
COLUNAS_PROCEDENCIA = ("arquivo", "lido de", "sha256")


def _tabela_procedencia(caminho):
    """As linhas da primeira tabela que tenha as três colunas. Lista de dicts."""
    cab, linhas = None, []
    with open(caminho, encoding="utf-8") as fh:
        for linha in fh:
            s = linha.strip()
            if not s.startswith("|"):
                if cab is not None:
                    break
                continue
            celulas = [c.strip().strip("`").strip() for c in s.strip("|").split("|")]
            if cab is None:
                nomes = [c.lower() for c in celulas]
                if all(col in nomes for col in COLUNAS_PROCEDENCIA):
                    cab = nomes
                continue
            if all(c and set(c) <= set("-: ") for c in celulas):
                continue
            linhas.append(dict(zip(cab, celulas)))
    return linhas


def _origem(valor):
    """O arquivo que a coluna `lido de` nomeia. Só é LIDO, nunca escrito."""
    if valor.startswith(MOTOR):
        return resolver_alvo(valor, RAIZ)
    if valor.startswith("~"):
        return os.path.expanduser(valor)
    if os.path.isabs(valor):
        return valor
    raise Recusa(f"lido de {valor!r}: use '~/…', 'motor:…' ou um caminho absoluto")


def _sha(caminho):
    with open(caminho, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def cmd_sincronizar(ref):
    dir_pack = achar(ref)
    if not dir_pack:
        print(f"  erro não achei o pack {ref!r}", file=sys.stderr)
        return ERRO_USO
    proc = os.path.join(dir_pack, "PROCEDENCIA.md")
    if not os.path.isfile(proc):
        print(f"  --   {os.path.basename(dir_pack)} não tem PROCEDENCIA.md — "
              f"nenhuma arte copiada a comparar")
        return OK
    linhas = _tabela_procedencia(proc)
    if not linhas:
        print(f"  erro {_relativo(proc)}: nenhuma tabela com as colunas "
              f"{', '.join(COLUNAS_PROCEDENCIA)}", file=sys.stderr)
        return ERRO_USO

    em_dia = fora = andou = 0
    for lin in linhas:
        arquivo, lido, reg = lin.get("arquivo", ""), lin.get("lido de", ""), lin.get("sha256", "").lower()
        rotulo = arquivo or "(linha sem arquivo)"
        try:
            aqui = _dentro(dir_pack, arquivo, "PROCEDENCIA.md")
            origem = _origem(lido)
            _exigir(RE_SHA256.match(reg), f"sha256 {reg!r} não tem 64 hex")
            # A MESMA EXTENSÃO NOS DOIS LADOS. A coluna `lido de` é dado de
            # quem escreveu o pack, e um pack de terceiro escreve o dele: sem
            # esta linha, `~/.ssh/id_ed25519` seria aberto e teria o sha256
            # impresso na tela. Comparar um `.svg` com outra coisa não é
            # sincronizar arte — então não se abre.
            _exigir(os.path.splitext(origem)[1].lower() == os.path.splitext(aqui)[1].lower(),
                    f"lido de {lido!r} não é o mesmo tipo de arquivo que {arquivo!r}")
        except Recusa as e:
            print(f"  ~~   {rotulo} — a linha do PROCEDENCIA.md não serve: {e}")
            andou += 1
            continue
        if not os.path.isfile(aqui):
            print(f"  ~~   {rotulo} — está no PROCEDENCIA.md e não existe no pack")
            andou += 1
            continue
        s_aqui = _sha(aqui)
        try:
            s_origem = _sha(origem)
        except OSError:
            print(f"  --   {rotulo} — a origem não está nesta máquina; nada a comparar")
            fora += 1
            continue
        if s_aqui == reg and s_origem == reg:
            print(f"  ok   {rotulo}")
            em_dia += 1
            continue
        andou += 1
        if s_aqui == reg:
            motivo = "a ORIGEM andou depois da cópia"
        elif s_origem == reg:
            motivo = "RETOCADA aqui depois da cópia — a origem não a sobrescreve"
        elif s_aqui == s_origem:
            motivo = "a cópia e a origem são iguais; só o registro ficou velho"
        else:
            motivo = "as DUAS andaram desde a cópia"
        print(f"  ~~   {rotulo} — {motivo}")
        print(f"         aqui      {s_aqui[:12]}…  {_relativo(aqui)}")
        print(f"         origem    {s_origem[:12]}…  {lido}")
        print(f"         registro  {reg[:12]}…  copiado em {lin.get('copiado em', '?')}")
        if s_aqui != s_origem:
            print("         o gesto é seu. Para trazer a versão da origem:")
            print(f"           cp '{origem}' '{aqui}'")
            print("         e troque o sha256 da linha no PROCEDENCIA.md. Para ficar")
            print(f"         com a daqui, o sha256 passa a ser {s_aqui}.")
        else:
            print(f"         troque o sha256 da linha no PROCEDENCIA.md por {s_aqui}.")

    total = len(linhas)
    resumo = f"{em_dia} de {total} em dia com a origem"
    if fora:
        resumo += f" · {fora} com a origem fora desta máquina"
    if andou:
        resumo += f" · {andou} divergente(s) — nada foi copiado"
    print(f"\n  {resumo}")
    return RECUSADO if andou else OK

# --- OS DESENHOS AUTORAIS, DECLARADOS — 23/09/2026, sprint P26 --------------
#
# O QUE ESTAVA ESCRITO ANTES, E POR QUE NÃO SERVIA
#   O `gerar_icones_autorais.py` abria dizendo "Desenha os ícones dos DOIS
#   aplicativos da Vitória: FogStripper, Hefesto". Um gerador bom — nasce da
#   paleta, por papel, e sobrevive ao flavor claro — que servia dois
#   aplicativos NOMEADOS NO PYTHON. Um terceiro não entrava sem editar código,
#   e um pack de terceiro não tinha como trazer desenho nenhum.
#
# O DESENHO VIRA DADO, E O DADO MORA NO PACK
#   Cada `icones/autorais/<nome>.json` descreve UM desenho, no vocabulário que o
#   gerador já usava por dentro: papéis (`sujeito`, `tinta`, `fundo`...) que
#   resolvem na paleta do flavor, e o SVG com uma lacuna `{papel}` onde a cor
#   entra. Os SVG gerados nascem AO LADO, como `<nome>-<flavor>.svg` — a mesma
#   pasta que o `icones.autorais.desenhos` já declara.
#
#   `desenhos` CONTINUA SENDO UM DIRETÓRIO, e a spec da P26 pedia outra coisa:
#   `"desenhos": "icones/autorais/*.json"`. Ela foi escrita em 21/09, antes de
#   a P27 dar a esse campo, no dia seguinte, o sentido de "a pasta onde os
#   autorais deste pack moram" — é por ele que o gerador sabe onde ESCREVER. Um
#   glob ali quebraria o `dir_acervo` do gerador, o `onde` do
#   `completar_icones.sh` e o `_contar_acervo` do `info`, e os quatro `desenhos`
#   do formato deixariam de ser a mesma coisa. As declarações são os `.json`
#   daquela pasta; nenhum campo novo foi preciso.
#
# AS REGRAS, E CADA UMA É UMA RECUSA COM O QUE CONSERTAR
#   · o nome do arquivo é o nome do desenho, com a regra do id de pack;
#   · cada papel diz a cor no flavor `escuro` e no `claro`, por NOME da paleta —
#     um dos 26 que todo pack é obrigado a ter, ou `<accent>`, o acento que a
#     pessoa escolheu. Por isso uma declaração serve a QUALQUER pack: o alucard
#     do Dracula nasce dela sem redesenho, como nasceu em 22/09;
#   · nenhum hex no SVG. É a regra que o gerador cumpre desde que nasceu, pelo
#     mesmo motivo: SVG escrito à mão sai fora da paleta sem ninguém notar;
#   · toda lacuna tem papel, e todo papel tem lacuna. Um papel declarado e não
#     usado é a promessa vazia que o `CAMPOS_COM_LEITOR` caça no pack.json;
#   · nada de script, `foreignObject`, `on*=` ou `href` para fora. Um pack de
#     terceiro escreve o dado dele, e este SVG vai para o tema de quem instala.
MARCA_ACCENT = "<accent>"
# A PASTA DE QUEM NÃO DECLARA `desenhos` — 23/09/2026, revisão da P26
#   O modelo de pack do docs/PACKS.md declara só `"autorais": { "gerar": true }`.
#   Para esse pack o `dir_acervo` do gerador e do «Salvar no pack» cai no
#   padrão e ESCREVE em `icones/autorais/`, e o `autorais()` lia só a pasta
#   DECLARADA — então não lia nada ali. Medido na revisão, numa cópia
#   descartável: `validar` ok, `construir` ok com 22 SVG e nenhum do desenho
#   novo; e pelo painel, «salvo no pack» com `foto` em red, e o SVG regerado
#   saindo em overlay0 — a declaração herdada vencia a cópia que acabara de ser
#   gravada. Leitura e escrita perguntam agora ao mesmo `dir_acervo`, com este
#   padrão; o `DESTINO` do gerador e o `onde` do `completar_icones.sh` passam o
#   mesmo texto, e os três têm de continuar iguais.
PASTA_AUTORAIS = "icones/autorais/"
LACUNAS_DO_GERADOR = ("titulo",)
RE_PAPEL = re.compile(r"^[a-z][a-z0-9_]*$")
RE_LACUNA = re.compile(r"\{([^{}]*)\}")
_COR_DIGITADA = re.compile(r"#[0-9A-Fa-f]{3,8}\b|rgba?\s*\(|hsla?\s*\(")
_AUTORAL_PROIBIDO = re.compile(
    r"<script|<foreignObject|\son[a-z]+\s*=|javascript:|href\s*=\s*[\"'](?!#)", re.I)
CAMPOS_DO_AUTORAL = ("papeis", "svg")


def ler_autoral(caminho):
    """Lê e confere UMA declaração de desenho autoral. Levanta Recusa.

    Devolve {"nome", "papeis", "svg", "arquivo"}, com o `svg` já montado como
    texto — as linhas do `.json` juntas por quebra de linha, e a última quebra
    posta de volta, que é como o gerador sempre escreveu o arquivo.
    """
    arq = os.path.basename(caminho)
    nome = arq[:-len(".json")] if arq.endswith(".json") else arq
    _exigir(RE_ID.match(nome),
            f"{arq}: o nome do desenho vem do arquivo, e {nome!r} não serve —\n"
            f"    só minúsculas, dígitos e hífen, como o id de um pack.")
    try:
        with open(caminho, encoding="utf-8") as fh:
            dados = json.load(fh)
    except json.JSONDecodeError as e:
        raise Recusa(f"{arq}: não é JSON válido: linha {e.lineno}, coluna {e.colno} — {e.msg}")
    except OSError as e:
        raise Recusa(f"{arq}: não consegui ler — {e}")
    _exigir(isinstance(dados, dict), f"{arq}: precisa ser um objeto JSON")

    # O CAMPO DESCONHECIDO É RECUSA, E NÃO AVISO como no pack.json: aqui não há
    # "a sprint seguinte vai ler" — um `papel` no lugar de `papeis` é erro de
    # digitação, e aceitá-lo calado geraria o desenho sem cor nenhuma.
    estranhos = [k for k in dados if not str(k).startswith("_") and k not in CAMPOS_DO_AUTORAL]
    _exigir(not estranhos,
            f"{arq}: campo(s) que uma declaração não tem: {', '.join(sorted(estranhos))}.\n"
            f"    Os que existem: {', '.join(CAMPOS_DO_AUTORAL)} (e notas em `_...`).")

    papeis = dados.get("papeis")
    _exigir(isinstance(papeis, dict) and papeis,
            f"{arq}: 'papeis' precisa ser um objeto com pelo menos um papel")
    for papel, par in papeis.items():
        _exigir(RE_PAPEL.match(str(papel)) and papel not in LACUNAS_DO_GERADOR,
                f"{arq}: papel {papel!r} — minúsculas, dígitos e _, começando por letra"
                + (f"; {papel!r} é reservado ao gerador" if papel in LACUNAS_DO_GERADOR else ""))
        _exigir(isinstance(par, dict) and {"escuro", "claro"} <= set(par),
                f"{arq}: o papel {papel!r} precisa dizer a cor no 'escuro' e no 'claro'")
        for lado in ("escuro", "claro"):
            _exigir(par[lado] in SLOTS or par[lado] == MARCA_ACCENT,
                    f"{arq}: papéis.{papel}.{lado} é {par[lado]!r}, que não é cor da paleta.\n"
                    f"    Use um dos 26 nomes (text, crust, mauve...) ou {MARCA_ACCENT!r}.")

    linhas = dados.get("svg")
    _exigir(isinstance(linhas, list) and linhas and all(isinstance(l, str) for l in linhas),
            f"{arq}: 'svg' precisa ser uma lista de linhas de texto")
    texto = "\n".join(linhas) + "\n"
    _exigir(texto.lstrip().startswith("<svg") and texto.rstrip().endswith("</svg>"),
            f"{arq}: o SVG tem de começar em <svg e terminar em </svg>")

    lacunas = set(RE_LACUNA.findall(texto))
    sem_papel = sorted(lacunas - set(papeis) - set(LACUNAS_DO_GERADOR))
    _exigir(not sem_papel,
            f"{arq}: lacuna sem papel declarado: {', '.join('{%s}' % x for x in sem_papel)}")
    sem_uso = sorted(set(papeis) - lacunas)
    _exigir(not sem_uso,
            f"{arq}: papel declarado que o SVG não usa: {', '.join(sem_uso)}")
    achado = _COR_DIGITADA.search(texto)
    _exigir(not achado,
            f"{arq}: o SVG traz a cor {achado.group(0) if achado else ''!r} digitada.\n"
            f"    A cor vem da paleta, por papel — é isso que faz o flavor claro nascer sozinho.")
    achado = _AUTORAL_PROIBIDO.search(texto)
    _exigir(not achado,
            f"{arq}: o SVG traz {achado.group(0) if achado else ''!r}, que não entra num ícone")
    return {"nome": nome, "papeis": papeis, "svg": texto, "arquivo": caminho}


def desenhar_autoral(decl, cores, claro, accent, extras=None):
    """O SVG de uma declaração num flavor: cada lacuna recebe o hex do papel.

    `cores` é o flavor da paleta (nome -> hex); `claro` escolhe o lado do
    papel; `accent` é o nome que `<accent>` vira. `extras` traz as lacunas que
    são do gerador e não do desenho — hoje só o `titulo`.
    """
    lado = "claro" if claro else "escuro"
    valores = dict(extras or {})
    for papel, par in decl["papeis"].items():
        nome_cor = accent if par[lado] == MARCA_ACCENT else par[lado]
        _exigir(nome_cor in cores,
                f"{decl['nome']}: o papel {papel!r} pede {nome_cor!r}, que não está na paleta")
        valores[papel] = cores[nome_cor]

    def trocar(m):
        _exigir(m.group(1) in valores,
                f"{decl['nome']}: a lacuna {{{m.group(1)}}} ficou sem valor")
        return valores[m.group(1)]
    return RE_LACUNA.sub(trocar, decl["svg"])


def autorais(ref=None):
    """As declarações que este pack alcança: as dele, e as que ele herda.

    Devolve {nome: (caminho do .json, id do pack de onde veio)}. A do pack vence
    a herdada de mesmo nome — é a mesma travessia do `acervo`, com o mesmo
    conjunto de vistos contra herança circular.

    O DRACULA NÃO TEM FOGSTRIPPER.JSON, E GERA OS DOIS MESMO ASSIM
        As duas declarações moram no Catppuccin, que é o pack do projeto; o
        Dracula herda dele. Herdar é "leia do vizinho", e ler uma declaração
        é exatamente isso. Quem ESCREVE continua sendo cada pack em casa: o
        `fogstripper-alucard.svg` nasce em `packs/dracula/icones/autorais/`,
        da paleta do Dracula, a partir do `.json` do Catppuccin.
    """
    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    achados = {}
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        dir_pack = achar(ref)
        if not dir_pack:
            break
        # A PASTA É A DO `dir_acervo`, COM O MESMO PADRÃO — ver `PASTA_AUTORAIS`.
        #   Vale em toda camada, e não só na do próprio pack: um pack base sem
        #   `desenhos` lê as declarações dele em `icones/autorais/`, e quem o
        #   herda tem de ver o mesmo conjunto que ele vê.
        try:
            pasta = dir_acervo("icones.autorais.desenhos", ref=dir_pack,
                               padrao=PASTA_AUTORAIS)
        except Recusa as e:
            print(f"  aviso {e} — esta camada foi ignorada", file=sys.stderr)
            pasta = ""
        if pasta and os.path.isdir(pasta):
            for arq in sorted(os.listdir(pasta)):
                if arq.endswith(".json"):
                    achados.setdefault(arq[:-len(".json")],
                                       (os.path.join(pasta, arq), os.path.basename(dir_pack)))
        ref = campo(ref, "icones.autorais.herda") or campo(ref, "heranca")
    return achados


# --- A CAPTURA DE TEMA, E DE QUEM ELA É -------------------------------------
#
# A FRONTEIRA, EM UMA FRASE [22/09/2026]
#   `assets/` é o que o MeowSystem É; `packs/` é o que ele VESTE. Uma captura de
#   tema é a fotografia de um tema — ela veste. Até esta data as cinco moravam
#   juntas em `assets/temas/capturados/`, e o `docs/PACKS.md` prometia, desde
#   que nasceu, `packs/<id>/temas/capturados/<flavor>-<accent>/`. Era promessa
#   sem lastro: nenhum pack conseguia trazer a própria captura pronta, porque
#   nada sabia procurá-la lá dentro.
#
# A `original` FICA NO MOTOR, E NÃO É ESQUECIMENTO
#   Ela não é tema de pack nenhum: é o MOLDE do esquema v1 que o COSMIC de
#   04/2026 escrevia (`gerar_tema_v1.py` deriva dela, chave por chave) e o reset
#   de fábrica DESTA máquina. O `capturar_tema.sh` recusa recapturá-la, então
#   fora do git ela é irrecuperável. Quem vai mexer no destino dela é a P24 —
#   ela já a chama de `referencia/` — e antecipar aquilo aqui seria decidir por
#   uma sprint que ainda não rodou.
#
# POR QUE UMA FUNÇÃO, E NÃO UM CAMINHO CRAVADO EM CADA LEITOR
#   Eram NOVE lugares montando `$RAIZ/assets/temas/capturados/$par` à mão — o
#   `bin/meow` em quatro, o `install.sh`, o `lib/preflight.sh`, o `vidro.sh`, o
#   `greeter.sh`, o `aplicar_tema.sh`. Com a captura dentro do pack, nove
#   caminhos cravados viram nove jeitos de não achar o mesmo arquivo. É o
#   mesmo argumento que fez nascer o `acervo`, três telas acima.
CAPTURAS_DO_MOTOR = os.path.join("assets", "temas", "capturados")
CAPTURAS_NO_PACK = os.path.join("temas", "capturados")
CATEGORIA_CAPTURA = "temas.capturados"

# O nome do molde mora aqui e no `gerar_tema_v1.py`, que o chama de `MOLDE`. São
# dois porque aquele script é o ÚNICO que precisa dele como molde; aqui ele é só
# "a captura que não é de pack nenhum".
CAPTURA_DO_MOTOR = "original"


def _cadeia(ref):
    """O pack ativo e os que ele herda, na ordem. Devolve (id, diretório).

    A mesma travessia do `acervo`, com o mesmo conjunto de vistos contra
    herança circular — um pack de terceiro pode escrevê-la, e um laço infinito
    penduraria o painel em vez de dizer "não achei".
    """
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        dir_pack = achar(ref)
        if not dir_pack:
            break
        yield ref, dir_pack
        ref = campo(ref, "temas.herda") or campo(ref, "heranca")


def _dir_capturas(ref, dir_pack):
    """Onde as capturas daquele pack moram. `None` se a declaração sai do pack.

    A CONVENÇÃO VENCE O SILÊNCIO, E NÃO O CONTRÁRIO
        `temas/capturados/` é convenção publicada em docs/PACKS.md, como
        `pack.json` e `CREDITOS.md` — um pack não precisa declarar nada para
        que a captura dele seja encontrada. Declarar `temas.capturados` continua
        valendo e vence a convenção, para quem organiza o pack de outro jeito.
    """
    rel = campo(ref, CATEGORIA_CAPTURA, CAPTURAS_NO_PACK)
    if not isinstance(rel, str):
        rel = CAPTURAS_NO_PACK
    try:
        _dentro(dir_pack, rel, CATEGORIA_CAPTURA)
    except Recusa as e:
        print(f"  aviso {e} — esta camada foi ignorada", file=sys.stderr)
        return None
    return os.path.join(dir_pack, rel)


def _ref_ativa(ref):
    return ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)


def captura(par, ref=None):
    """Onde ESTÁ a captura `<flavor>-<accent>`: pack ativo -> herança -> motor.

    Os mesmos três degraus do `acervo`, e de propósito: uma segunda ordem de
    resolução é como o tema do COSMIC vem de um pack e o vidro da janela de
    outro, sem erro nenhum na tela.

    Devolve None quando não existe em lugar nenhum — ausência é resposta, e quem
    chama decide se ela é erro.
    """
    for ident, dir_pack in _cadeia(_ref_ativa(ref)):
        base = _dir_capturas(ident, dir_pack)
        if base and os.path.isdir(os.path.join(base, par)):
            return os.path.join(base, par)
    alvo = os.path.join(RAIZ, CAPTURAS_DO_MOTOR, par)
    return alvo if os.path.isdir(alvo) else None


def captura_destino(par, ref=None):
    """Onde uma captura NOVA deve ser ESCRITA. Nunca sobe pela herança.

    LER E ESCREVER NÃO PODEM TER A MESMA RESPOSTA
        Ler sobe a cadeia: o Dracula enxerga o `mocha-mauve` do Catppuccin, de
        quem herda. Escrever ali gravaria a foto do Dracula DENTRO do pack do
        Catppuccin, e a próxima pessoa a instalar o Catppuccin receberia um tema
        que não é dele. Escrita é sempre no pack ativo.

    A EXCEÇÃO É A `original`, e ela é do motor: ver o bloco no topo desta seção.
    """
    if par == CAPTURA_DO_MOTOR:
        return os.path.join(RAIZ, CAPTURAS_DO_MOTOR, par)
    ref = _ref_ativa(ref)
    dir_pack = achar(ref)
    if not dir_pack:
        return None
    base = _dir_capturas(ref, dir_pack)
    return os.path.join(base, par) if base else None


def capturas(ref=None):
    """Os nomes das capturas ALCANÇÁVEIS daqui, sem repetir, em ordem.

    Alcançável quer dizer o que o `captura()` acharia: o pack ativo, os que ele
    herda, e o motor. Não é "tudo o que existe no disco" — com o Dracula no ar,
    o `dracula-mauve` de um terceiro pack instalado ao lado não é uma captura
    que este desktop possa aplicar, e listá-la seria oferecer o que não se
    entrega.

    O pack mais próximo vence: um `mocha-mauve` próprio esconde o herdado, que
    é a mesma regra do `acervo`.
    """
    vistos, saida = set(), []
    bases = [_dir_capturas(i, d) for i, d in _cadeia(_ref_ativa(ref))]
    bases.append(os.path.join(RAIZ, CAPTURAS_DO_MOTOR))
    for base in bases:
        if not base or not os.path.isdir(base):
            continue
        for nome in sorted(os.listdir(base)):
            if nome in vistos or not os.path.isdir(os.path.join(base, nome)):
                continue
            vistos.add(nome)
            saida.append(nome)
    return saida


def tema_de_app(categoria, ref=None):
    """O que o pack declara para um APLICATIVO: 'apps.<app>.<chave>'.

    POR QUE ELA NASCEU [22/09/2026, sprint P18]
        Uma contagem mediu 446 citações da palavra `catppuccin` dentro de
        `assets/temas-de-apps/`, espalhadas por oito módulos, e ZERO deles
        perguntava qual era o pack ativo. Aquele acervo é anterior ao formato de
        pack e nunca soube que ele existe: os oito eram, na prática,
        "aplicadores de Catppuccin".

        O preço estava na tela desta máquina em 21/09/2026. O pack ativo é o
        Dracula, e o módulo do Obsidian anunciou «Catppuccin Mocha já estava
        aplicado» — o único dos oito que "deu certo" foi o que aplicou o tema do
        OUTRO pack e chamou de sucesso. Esta função é a porta por onde o módulo
        pergunta em vez de saber.

    A HERANÇA É POR APLICATIVO, E NÃO POR CHAVE — E A DIFERENÇA É O DEFEITO
        Quem responde é o PRIMEIRO pack da cadeia que declara o bloco
        `apps.<app>` inteiro. Uma chave que falte DENTRO de um bloco declarado é
        ausência, e não motivo para descer mais um degrau.

        Se fosse por chave, um pack que declarasse `spicetify_tema: "Sleek"` sem
        `esquema` herdaria o `esquema` do vizinho e o Spotify sairia com o tema
        de um pack e o esquema de cor de outro — a mesma divergência silenciosa
        que o `meow_paleta` (lib/comum.sh) existe para matar, um andar acima.

        `apps.<app>.herda` continua valendo e vence a herança do pack inteiro,
        igual a `icones.*.herda`: é como um pack diz "este aplicativo eu pego
        emprestado daquele ali".

    `arquivo` É CAMINHO, O RESTO É NOME
        A chave `arquivo` nomeia arte dentro do pack (`apps/dracula.qbtheme`) e
        volta resolvida em caminho absoluto, com a mesma guarda de `_dentro` que
        o `acervo` aplica — um pack de terceiro com `"../../../etc/algo"` é
        ignorado naquele degrau, com aviso. Toda outra chave é NOME, e volta
        como veio.

    `<flavor>` É EXPANDIDO AQUI, E PELO MOTIVO DO `cosmic.nome_da_paleta`
        O pack padrão declara `"esquema": "<flavor>"` porque no tema catppuccin
        do spicetify a seção do color.ini chama-se como o flavor. É o mesmo
        marcador que o `gerar_temas.py` já expande em `cosmic.nome_da_paleta`, e
        repeti-lo aqui é o que evita um segundo dialeto de marcador no formato.
        O valor vem do `FLAVOR` do ambiente (o meow.conf vence, como sempre) e,
        na falta dele, do `paleta.flavor_padrao` do pack ATIVO.

    Devolve `(id_do_pack_que_respondeu, valor)`, ou `(None, None)` quando nenhum
    pack da cadeia declara aquele aplicativo ou aquela chave. Ausência é
    resposta: quem chama decide se ela é problema.
    """
    partes = categoria.split(".")
    if len(partes) < 3 or partes[0] != "apps":
        raise Recusa(f"tema_de_app: {categoria!r} não é 'apps.<app>.<chave>'")
    # A CHAVE PODE SER UMA TRILHA DENTRO DO BLOCO — `apps.spotify.origem.repo`.
    # É o mesmo desenho do `campo`, e existe porque o bloco de um aplicativo tem
    # sub-blocos: `origem` descreve de onde o tema desce, com quatro campos.
    alvo, chave = partes[1], partes[2:]

    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    # O flavor do pack ATIVO, e não do que respondeu: quem manda no sabor é a
    # máquina (FLAVOR) e, na falta dela, o pack que está no ar.
    flavor = os.environ.get("FLAVOR") or campo(ref, "paleta.flavor_padrao") or ""

    # A mesma guarda de laço do `acervo`, e pelo mesmo motivo: dois packs que
    # herdem um do outro pendurariam o instalador para sempre.
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        dir_pack = achar(ref)
        if not dir_pack:
            break
        bloco = campo(ref, f"apps.{alvo}")
        if isinstance(bloco, dict) and not bloco.get("herda"):
            quem = campo(ref, "id") or os.path.basename(dir_pack)
            valor = bloco
            for parte in chave:
                if not isinstance(valor, dict) or parte not in valor:
                    valor = None
                    break
                valor = valor[parte]
            if valor is None:
                return None, None
            if chave == ["arquivo"]:
                try:
                    _dentro(dir_pack, str(valor), categoria)
                except Recusa as e:
                    print(f"  aviso {e} — esta camada foi ignorada", file=sys.stderr)
                    return None, None
                cheio = os.path.join(dir_pack, str(valor))
                return (quem, cheio) if os.path.exists(cheio) else (None, None)
            if isinstance(valor, str):
                valor = valor.replace("<flavor>", flavor)
            return quem, valor
        prox = bloco.get("herda") if isinstance(bloco, dict) else None
        ref = prox or campo(ref, "heranca")
    return None, None


def _rgb(hexcor):
    """'#RRGGBB' em (r, g, b) de 0 a 1. O parse é um só [revisão da P16, 23/09/2026]:
    a derivação do claro precisa dele solto, e duas cópias do mesmo fatiamento
    divergem no dia em que uma aceitar '#RGB' e a outra não."""
    return tuple(int(hexcor[i:i + 2], 16) / 255 for i in (1, 3, 5))


def _luminancia(hexcor):
    """Luminância relativa de WCAG 2.x: o contraste, e a derivação do claro (P16)."""
    r, g, b = _rgb(hexcor)
    def canal(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = canal(r), canal(g), canal(b)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contraste(a, b):
    la, lb = _luminancia(a), _luminancia(b)
    claro, escuro = max(la, lb), min(la, lb)
    return (claro + 0.05) / (escuro + 0.05)


class Recusa(Exception):
    """Erro de validação com mensagem que diz o que fazer."""


def _exigir(cond, msg):
    if not cond:
        raise Recusa(msg)


def _dentro(base, alvo, campo):
    """Todo caminho declarado resolve com realpath e cai dentro do pack."""
    cheio = os.path.realpath(os.path.join(base, alvo))
    if not cheio.startswith(os.path.realpath(base) + os.sep):
        raise Recusa(f"{campo}: {alvo!r} sai de dentro do pack")
    return cheio


# --- A PALETA ENTRA POR CSV — 23/09/2026, sprint P16 ------------------------
#
# O PEDIDO, NAS PALAVRAS DELE
#   *"a ideia é darmos via json ou csv um theme completo."* O `paleta.json` tem
#   `ordem_canonica`, `claros`, `nomes` e `flavors` — natural para quem
#   programa. O designer que ele descreve tem outra coisa na mão: 26 cores numa
#   coluna do Figma. Vinte e seis linhas `slot,flavor,hex` é o que ele já sabe
#   fazer, e é a única coisa que este bloco pede.
#
# O CSV É ENTRADA; O JSON CONTINUA SENDO A FORMA CANÔNICA
#   Nenhum leitor do projeto passa a entender CSV. Este bloco o traduz UMA vez
#   para o `paleta.json` equivalente, e dali em diante é o JSON que manda — um
#   formato de leitura e um de escrita. Dois formatos aceitos em todo leitor
#   seriam cada consumidor de paleta escolhendo, por conta própria, qual dos
#   dois vence quando os dois estão no pack: a divergência silenciosa do
#   cabeçalho deste arquivo.
#
# FUNÇÃO PURA, E O VERBO SÓ IMPRIME
#   `paleta_de_csv` lê o CSV e a régua, e devolve o dicionário: não escreve em
#   lugar nenhum. O verbo `de-csv` o imprime no STDOUT, como o `logo-gerado`, e
#   quem põe o arquivo num pack é a pessoa, com `>`.
#
# O `novo --de-csv` É PENDÊNCIA DA P16, E NÃO DA P11 [revisão, 23/09/2026]
#   A sprint pede `meow pack novo <id> --de-csv <arquivo>` (item 2) e a tela
#   de importar aceitando `.csv` (item 5), e os dois ficaram por fazer AQUI. O
#   `novo`, o `/api/pack-importar` e a tela de importar nascem na P11, e ela
#   não tinha entrado no dev quando esta foi escrita (medido: zero `novo` no
#   `bin/meow`, zero `pack-importar` no servidor e no app.js do dev 249d60a).
#   A spec da P11 não fala de CSV; quem deve o `--de-csv` é a P16. Não há um
#   segundo `novo` em paralelo: dois `novo` escritos ao mesmo tempo, em duas
#   sprints, é o conflito que ninguém resolveria igual duas vezes.
#   O QUE FALTA, quando a P11 entrar: no `cmd_novo` dela, o ramo `--de-csv`
#   troca a leitura da paleta no ar por `paleta_de_csv(arquivo)`, o
#   `flavor_padrao` passa a ser o primeiro flavor do CSV, e a régua e a
#   notícia do claro derivado saem como no `cmd_de_csv`; o importar da tela
#   aceita o `.csv` e mostra o claro derivado com o jeito de trocá-lo (o risco
#   que a sprint declara: "a tela precisa deixar trocar").
#
# O CLARO DERIVADO É O MÉTODO DO ALUCARD, E NÃO UM SEGUNDO
#   As três regras de docs/PACKS.md, "Se o seu tema não tem um claro", viraram
#   código uma vez só: `scripts/derivar_claro.py`, em 19/09/2026, que gerou o
#   `alucard`. Aquele script crava o `dracula` na leitura e grava num arquivo de
#   /tmp, então não serve de biblioteca, e ele não está entre os arquivos da
#   P16. O `derivar_claro` abaixo é o MESMO algoritmo, passo a passo e com os
#   mesmos números (S < 0,10, 12 tentativas de -0,07 em S, 40 passos de busca,
#   o ajuste do `text` até 7,02). A prova de que não é um método novo é medida,
#   e o `tests/pack.sh` a cobra: dadas as 26 cores do `dracula`, ele devolve o
#   `alucard` versionado — 26 de 26 iguais. Os dois agora são duas cópias do
#   mesmo algoritmo; unificá-las é mexer no `derivar_claro.py`, e fica dito.
#
# A RÉGUA É O LATTE DO PACK PADRÃO, NOMEADO
#   O método se chama "do Latte" porque a calibração É o Latte, e o
#   `derivar_claro.py` explica por que ela não acompanha o pack ativo: a régua
#   mudaria junto com o tema e o resultado deixaria de ser reprodutível. O
#   arquivo sai do `dir_padrao()`, que é a porta do nome do pack padrão; o
#   flavor, desta constante. Um padrão futuro sem `latte` faz a derivação parar
#   com o nome do que falta, e não inventar outra régua calada.
REFERENCIA_CLARA = "latte"
COLUNAS_CSV = ("slot", "flavor", "hex")
RE_FLAVOR_CSV = re.compile(r"^[a-z0-9]+$")   # ver "O FLAVOR É [a-z0-9]", abaixo
# O nome do claro derivado é o do escuro com `claro` colado. Colado porque
# nome de flavor não tem hífen (ver o `validar`, 19/09/2026), e com o nome do
# escuro na frente porque o `.ron` do COSMIC é gravado por flavor: dois packs
# feitos de CSV com um flavor chamado só `claro` disputariam o mesmo arquivo.
SUFIXO_DO_CLARO = "claro"

# NÃO PIOR QUE O LATTE É "NÃO ABAIXO DE 95% DELE", E ISTO FOI MEDIDO
#   O docs/PACKS.md diz "cada slot não pior que o Latte no mesmo slot". Lido ao
#   pé da letra, o próprio `alucard` reprova em 21 dos 26 slots — `rosewater`
#   2,32 contra 2,34, `mauve` 4,76 contra 4,79 —, porque a derivação MIRA a
#   luminância do Latte e o arredondamento para hexa cai um centésimo abaixo.
#   A régua que o gerou é 95% (`derivar_claro.py`, e o `_comentario` da paleta
#   do Dracula diz o mesmo com todas as letras). É ela que vale aqui: uma régua
#   que reprova o precedente que a define é uma régua errada.
TOLERANCIA_DA_REGUA = 0.95
MINIMO_TEXTO = 7.0     # `text` sobre `base`, WCAG AAA — é onde a pessoa lê
# Abaixo disto o `validar` RECUSA; a régua só avisa. É ESTA constante que o
# `validar` lê [revisão da P16, 23/09/2026]: com o 4.5 escrito nos dois lugares,
# mudar o piso de um deixaria o aviso da régua prometendo uma recusa que não vem.
MINIMO_VALIDAR = 4.5


def _hexa(r, g, b):
    return "#%02X%02X%02X" % tuple(max(0, min(255, round(c * 255))) for c in (r, g, b))


def _referencia_clara():
    """As 26 cores do Latte, lidas do pack padrão. Recusa dizendo o que falta."""
    caminho = os.path.join(dir_padrao(), "paleta.json")
    try:
        with open(caminho, encoding="utf-8") as fh:
            return json.load(fh)["flavors"][REFERENCIA_CLARA]
    except (OSError, ValueError, KeyError, TypeError) as e:
        raise Recusa(f"a régua do claro é o flavor {REFERENCIA_CLARA!r} de {caminho}, "
                     f"e ele não pôde ser lido ({e.__class__.__name__}: {e}).\n"
                     f"    Sem ela o claro não se deriva — ver docs/PACKS.md,\n"
                     f"    'Se o seu tema não tem um claro'.")


def derivar_claro(escuro, referencia):
    """O flavor claro de um escuro: matiz do tema, (S, luminância) da referência.

    As três regras de docs/PACKS.md, na ordem em que o `derivar_claro.py` as
    aprendeu — o porquê de cada uma está lá, com a tentativa que falhou antes.
    """
    import colorsys
    h_base = colorsys.rgb_to_hsv(*_rgb(escuro["base"]))[0]
    claro = {}
    for k in SLOTS:
        # Regra 3: o matiz de um quase-neutro é ruído, e o que define a família
        # do tema é o matiz do `base`. O `text` #F8F8F2 do Dracula, saturado
        # pelo matiz dele mesmo, virou um oliva que o tema não tem.
        h_d, s_d, _ = colorsys.rgb_to_hsv(*_rgb(escuro[k]))
        if s_d < 0.10:
            h_d = h_base
        # Regras 1 e 2: a saturação e a LUMINÂNCIA vêm da referência. Mirar a
        # luminância, e não o V, é o que faz o amarelo e o azul chegarem ao
        # mesmo brilho percebido — com S e V copiados o `yellow` saía a 1,30.
        s_l = colorsys.rgb_to_hsv(*_rgb(referencia[k]))[1]
        alvo = _luminancia(referencia[k])
        for tentativa in range(12):
            # Se nem V=1 alcança o alvo com aquela saturação (o azul, com S
            # alto, não chega a claro nenhum), afrouxa S e tenta de novo.
            s = max(0.0, s_l - tentativa * 0.07)
            lo, hi = 0.0, 1.0
            for _ in range(40):
                mid = (lo + hi) / 2
                if _luminancia(_hexa(*colorsys.hsv_to_rgb(h_d, s, mid))) < alvo:
                    lo = mid
                else:
                    hi = mid
            cand = _hexa(*colorsys.hsv_to_rgb(h_d, s, (lo + hi) / 2))
            if abs(_luminancia(cand) - alvo) < 0.01:
                break
        claro[k] = cand
    # O `text` é o único slot com exigência ABSOLUTA, e mirar a luminância do
    # Latte o deixa a 6,99 — o arredondamento, não o método. Ele desce V aos
    # poucos até passar; os outros são comparados com o Latte, e lá é relativo.
    while contraste(claro["text"], claro["base"]) < MINIMO_TEXTO + 0.02:
        h, sv, vv = colorsys.rgb_to_hsv(*_rgb(claro["text"]))
        vv -= 0.004
        if vv <= 0:
            break
        claro["text"] = _hexa(*colorsys.hsv_to_rgb(h, sv, vv))
    return claro


def regua_de_contraste(dados, referencia):
    """As linhas que reprovam na régua do docs/PACKS.md. NÃO levanta: avisa.

    A régua vale para TODO flavor, escuro ou claro, e é simétrica: contraste
    não tem direção, e o Latte é o piso que as quatro variantes do Catppuccin
    cumprem — medido em 23/09/2026, mocha, frappe e macchiato passam nela. A
    decisão de publicar abaixo dela é de quem fez o tema; a régua é do projeto.
    """
    saida = []
    for flavor, cores in dados["flavors"].items():
        r_text = contraste(cores["text"], cores["base"])
        if r_text < MINIMO_TEXTO:
            saida.append(f"{flavor}: text/base {r_text:.2f} — AAA pede {MINIMO_TEXTO:.1f}"
                         + (f"; abaixo de {MINIMO_VALIDAR} o `validar` recusa o pack"
                            if r_text < MINIMO_VALIDAR else ""))
        for s in SLOTS:
            # O `text` que já saiu pela régua absoluta não sai de novo pela
            # relativa [revisão da P16, 23/09/2026]: reprovado nas duas, ele
            # aparecia duas vezes na lista, e a contagem do aviso dizia uma
            # reprovação a mais do que as que existem.
            if s == "text" and r_text < MINIMO_TEXTO:
                continue
            r = contraste(cores[s], cores["base"])
            ref = contraste(referencia[s], referencia["base"])
            if r < ref * TOLERANCIA_DA_REGUA:
                saida.append(f"{flavor}: {s}/base {r:.2f} — o {REFERENCIA_CLARA.capitalize()} faz "
                             f"{ref:.2f} no mesmo slot")
    return saida


def claros_derivados(dados):
    """{claro: escuro de onde ele saiu}, só das entradas que fazem sentido.

    O campo `derivados` do `paleta.json` é o que faz o claro derivado DIZER que
    é derivado, no `info` e no cartão. Ele é lido com tolerância — um pack de
    terceiro pode tê-lo escrito torto, e quem só MOSTRA não derruba o pack por
    causa de uma etiqueta; quem recusa é o `validar`, na porta de quem publica.
    """
    deriv = dados.get("derivados")
    # O `claros` também: o `validar` cobra a chave e não o tipo, e um
    # `claros: null` levantava TypeError aqui — fora do try do
    # `packs_com_vitrine`, derrubando o /api/packs de TODOS os packs por causa
    # da etiqueta de um só. Medido na revisão da P16, 23/09/2026.
    claros = dados.get("claros")
    if not isinstance(deriv, dict) or not isinstance(claros, list):
        return {}
    return {c: e for c, e in deriv.items()
            if isinstance(c, str) and isinstance(e, str)
            and c in claros and e in dados["flavors"]}


def paleta_de_csv(caminho):
    """O dicionário do `paleta.json` equivalente a um CSV `slot,flavor,hex`.

    Recusa com TODOS os problemas de uma vez, cada um com a linha: consertar um
    por rodada é o que faz alguém desistir. Slot desconhecido diz a linha e o
    nome; slot faltando diz a lista do que falta, por flavor.

    Um flavor é CLARO quando o `base` dele é mais luminoso que o `text` — a
    medida, e não o nome. Se o CSV não traz nenhum claro, o primeiro flavor
    (o que vira o `flavor_padrao`) ganha um derivado, e o `derivados` da saída
    diz de onde ele saiu. Não escreve nada.
    """
    import csv
    nome = os.path.basename(caminho)
    # `utf-8-sig` porque é assim que planilha exporta: o Excel e o LibreOffice
    # põem um BOM no início, e sem isto o cabeçalho lido é "﻿slot" — um
    # CSV certo recusado por um caractere que ninguém vê.
    try:
        with open(caminho, encoding="utf-8-sig", newline="") as fh:
            linhas = list(csv.reader(fh))
    except OSError as e:
        raise Recusa(f"{caminho}: não consegui ler — {e.strerror}")
    except UnicodeDecodeError:
        raise Recusa(f"{caminho}: não é texto UTF-8. Exporte o CSV como UTF-8.")
    corpo = [(n, [c.strip() for c in lin]) for n, lin in enumerate(linhas, 1)
             if any(c.strip() for c in lin)]
    _exigir(corpo, f"{nome}: está vazio. A primeira linha é o cabeçalho "
                   f"{','.join(COLUNAS_CSV)}, e depois uma linha por cor.")
    n_cab, cab = corpo[0]
    # O PONTO E VÍRGULA GANHA DICA, E NÃO ACEITAÇÃO [revisão da P16, 23/09/2026]
    #   O Excel em português salva "CSV" com ';', porque a vírgula é o decimal
    #   daqui — é o CSV mais provável de chegar. Adivinhar o separador seria um
    #   segundo formato de entrada; dizer o que houve custa uma linha.
    dica = ("\n    O separador é a vírgula, e este arquivo usa ';' — é como o Excel em\n"
            "    português salva. Troque os ';' por ',' e rode de novo."
            if len(cab) == 1 and ";" in cab[0] else "")
    _exigir(tuple(c.lower() for c in cab) == COLUNAS_CSV,
            f"{nome}:{n_cab}: a primeira linha tem de ser o cabeçalho "
            f"{','.join(COLUNAS_CSV)} — veio {','.join(cab)!r}.\n"
            f"    As colunas são fixas: é o que deixa o erro dizer a linha certa.{dica}")

    erros, flavors, onde = [], {}, {}
    for num, cel in corpo[1:]:
        if len(cel) != len(COLUNAS_CSV):
            erros.append(f"{nome}:{num}: {len(cel)} coluna(s) — são três: {','.join(COLUNAS_CSV)}")
            continue
        slot, flavor, hexcor = cel
        if slot not in SLOTS:
            erros.append(f"{nome}:{num}: slot desconhecido {slot!r}. Os 26 nomes estão\n"
                         f"    em docs/PACKS.md, 'As 26 cores', e são minúsculos.")
            continue
        # O FLAVOR É [a-z0-9], E NÃO "QUALQUER COISA SEM HÍFEN" [revisão da P16,
        #   23/09/2026]. Medido na revisão: 'a/b', 'Tinta' e 'x$(id)' passavam,
        #   como 'Meu Tema' antes do 5dd3c32. O nome vai para três lugares que
        #   não o aguentam: o
        #   '<flavor>-<accent>' do arquivo de tema (a barra vira diretório), o
        #   `FLAVOR=` do meow.conf, que o `bin/meow` lê com `.` (o '$(id)' é
        #   comando), e o painel, que compara flavor SEM caixa (o
        #   `_pack_do_sabor`, em app/servidor.py, baixa os dois lados) enquanto
        #   o arquivo de tema é gravado COM caixa — 'Tinta' e 'tinta' seriam um
        #   flavor para um e dois para o outro. Minúsculas, como os seis
        #   flavors versionados. Esta porta é a do CSV, e é ela que fecha aqui;
        #   o `validar` tem a mesma folga desde antes, e ela fica dita, não mexida.
        if not RE_FLAVOR_CSV.match(flavor):
            erros.append(f"{nome}:{num}: flavor {flavor!r} — uma palavra só, em minúsculas,\n"
                         f"    de letras a-z e dígitos: o tema é gravado como '<flavor>-<accent>',\n"
                         f"    e o nome vai para o FLAVOR= do meow.conf.")
            continue
        if (flavor, slot) in onde:
            erros.append(f"{nome}:{num}: {slot} do flavor {flavor!r} já veio na linha "
                         f"{onde[(flavor, slot)]}. Uma cor por slot: com duas, quem\n"
                         f"    venceria é a última lida, e ninguém escolheu isso.")
            continue
        # O slot com hex torto CONTA COMO VISTO: ele já é um erro com a linha
        # dele, e aparecer de novo na lista dos que faltam mandaria a pessoa
        # procurar uma linha que ela escreveu.
        onde[(flavor, slot)] = num
        if not RE_HEX.match(hexcor):
            erros.append(f"{nome}:{num}: {slot} = {hexcor!r} não é #RRGGBB")
            continue
        # MAIÚSCULAS, PORQUE É A FORMA CANÔNICA [revisão da P16, 23/09/2026]:
        # as 146 cores com letra das duas paletas versionadas são todas
        # maiúsculas, e o claro derivado sai do `_hexa` assim. Um CSV minúsculo
        # dava uma paleta com as duas caixas, o escuro de um jeito e o claro do outro.
        flavors.setdefault(flavor, {})[slot] = hexcor.upper()
    for flavor in dict.fromkeys(f for f, _ in onde):
        faltam = [s for s in SLOTS if (flavor, s) not in onde]
        if faltam:
            erros.append(f"{nome}: o flavor {flavor!r} não tem {len(faltam)} slot(s):\n"
                         f"      {', '.join(faltam)}")
    _exigir(flavors or erros, f"{nome}: tem o cabeçalho e nenhuma cor.")
    _exigir(not erros, "\n  erro ".join(erros))

    ordem = list(flavors)
    claros = [f for f in ordem if _luminancia(flavors[f]["base"]) > _luminancia(flavors[f]["text"])]
    nomes = {f: f.capitalize() for f in ordem}
    derivados = {}
    if not claros:
        escuro = ordem[0]
        novo = escuro + SUFIXO_DO_CLARO
        _exigir(novo not in flavors,
                f"{nome}: o claro derivado de {escuro!r} se chamaria {novo!r}, e esse\n"
                f"    flavor já está no CSV — e é escuro. Renomeie um dos dois.")
        flavors[novo] = derivar_claro(flavors[escuro], _referencia_clara())
        nomes[novo] = f"{nomes[escuro]} claro"
        claros, derivados[novo] = [novo], escuro

    # Sem sprint e sem data [revisão da P16, 23/09/2026]: a paleta é de quem a
    # gerou, e um "(P16, 23/09/2026)" cravado em toda saída se lia como a data
    # da geração, que é outra. A história do verbo mora neste arquivo.
    comentario = (f"Gerada de {nome} pelo `meow pack de-csv`. O CSV foi a "
                  f"ENTRADA; esta paleta.json é a forma canônica, e é ela que o MeowSystem "
                  f"lê: edite aqui, ou gere de novo a partir do CSV.")
    for claro, escuro in derivados.items():
        comentario += (f" O flavor '{claro}' NÃO foi desenhado: foi derivado de '{escuro}' "
                       f"pelo método do Latte (docs/PACKS.md, 'Se o seu tema não tem um "
                       f"claro') — é o que o campo `derivados` registra. Para ter o seu, "
                       f"traga as 26 linhas dele no CSV.")
    dados = {"_comentario": comentario,
             "ordem_canonica": list(SLOTS),
             "claros": claros,
             "nomes": nomes,
             "flavors": {f: {s: flavors[f][s] for s in SLOTS} for f in flavors}}
    if derivados:
        dados["derivados"] = derivados
    return dados


def cmd_de_csv(caminho):
    """Imprime o `paleta.json` do CSV. O que é notícia vai no STDERR."""
    # O PREFIXO É DO CSV, E NÃO DE PACK [revisão da P16, 23/09/2026]. Pela porta
    #   geral do `main`, um CSV torto saía "erro pack recusado: cores.csv:1: …",
    #   sem pack nenhum envolvido — e quem lê "pack" vai procurar num pack.json.
    #   A régua entra no mesmo try porque ela também lê o Latte do pack padrão,
    #   e a falta dele é o mesmo "o CSV não virou paleta", não outra notícia.
    try:
        dados = paleta_de_csv(caminho)
        reprovados = regua_de_contraste(dados, _referencia_clara())
    except Recusa as e:
        print(f"  erro o CSV não virou paleta: {e}", file=sys.stderr)
        return RECUSADO
    derivados = claros_derivados(dados)
    lidos = [f for f in dados["flavors"] if f not in derivados]
    print(f"  ok   {os.path.basename(caminho)}: {len(lidos)} flavor(s), "
          f"26 slots conferidos — {', '.join(lidos)}", file=sys.stderr)
    for claro, escuro in derivados.items():
        print(f"  --   {claro}: claro derivado de {escuro!r} pelo método do Latte — "
              f"não é próprio.\n"
              f"       Para ter o seu, traga as 26 linhas dele no CSV.", file=sys.stderr)
    # A RÉGUA AVISA E NÃO BLOQUEIA, E O CÓDIGO DE SAÍDA CONTINUA 0
    #   A sprint é explícita: "a régua é do projeto; a decisão é de quem fez o
    #   tema". Medido em 23/09/2026: as cores oficiais do Dracula reprovam em
    #   três slots contra o Latte (`blue` 3,03 contra 4,34, `red` e `surface0`),
    #   e bloquear aqui recusaria o tema que o próprio projeto já veste. O que
    #   não pode é o silêncio: a lista inteira sai, e antes do JSON.
    if reprovados:
        print(f"  aviso {len(reprovados)} abaixo da régua de contraste (docs/PACKS.md) — "
              f"não bloqueia, a decisão é sua:", file=sys.stderr)
        for linha in reprovados:
            print(f"          {linha}", file=sys.stderr)
    sys.stdout.write(json.dumps(dados, indent=2, ensure_ascii=False) + "\n")
    return OK


# --- O LOGO DO PACK — 23/09/2026, sprint P25 --------------------------------
#
# O PEDIDO, NAS PALAVRAS DELE
#   *"precisa usar um svg pra cada logo do theme pack, o icon do menu de
#   lançamento."* Até aqui um pack era um `id` e 26 hexadecimais: nenhum dos
#   dois tinha um único SVG que o representasse. O mockup de 21/09 desenhou a
#   capa do cartão como uma TIRA DE CORES — e tira de cor é paleta, não
#   identidade: dois packs de paleta parecida ficam indistinguíveis no cartão.
#
# O ARQUIVO É O QUE A `vitrine.capa` NOMEIA, E `logo.svg` NA FALTA DELA
#   A P15 dá à vitrine o campo `capa`, e a capa É o logo — P25 faz o logo, P15
#   faz o resto da vitrine, e o campo é um só. A primeira versão desta seção
#   dizia "o nome é fixo, não há campo", e a revisão de 23/09 mediu o conflito:
#   um pack com `"capa": "cara.svg"` teria a capa num arquivo e o logo cobrado
#   noutro, duas verdades para a mesma figura. Então o campo manda quando existe;
#   sem ele (os packs de antes da P15), vale `packs/<id>/logo.svg`, a convenção
#   que o próprio campo recomenda. Quem precisa do logo pergunta a `logo()`.
#
# COBRADO DE QUEM PUBLICA, NUNCA DE QUEM USA — ver o bloco "o logo" do `validar`.
#
# AS CORES SAEM DA PALETA, POR PAPEL — NENHUM HEX É DIGITADO NO DESENHO
#   É a regra que o `gerar_icones_autorais.py` cumpre no cabeçalho dele, levada
#   para um arquivo que é DADO, e não código: cada forma do logo declara, na
#   `class`, o PAPEL que ela cumpre, e o papel resolve para um dos 26 nomes.
#
#       class="fundo"           fill   <- base
#       class="tinta"           fill   <- text
#       class="sujeito"         fill   <- o accent (ACCENT; mauve na falta)
#       class="traco-<papel>"   stroke <- o mesmo papel, no traço
#       class="<um dos 26>"     fill   <- o nome direto, para quem precisar de
#                                         uma quarta cor sem cravar hex
#
#   É o que faz o logo acompanhar o flavor claro SEM REDESENHO: no Latte o
#   `text` escurece e o `base` clareia sozinhos, e um logo descrito por papel
#   se inverte junto. A P27 mediu a mesma coisa nos onze autorais do alucard —
#   as três cores do `cosmic-term-alucard.svg` não coincidem com nenhuma do
#   latte, porque o desenho nasceu da paleta e não de uma cópia.
#
# O BLOCO `<style id="meow-papeis">` É SAÍDA, E ESTÁ NO ARQUIVO POR UM MOTIVO
#   Sem ele o logo aberto cru — num editor de SVG, na prévia do git, num `<img>`
#   — é um quadrado preto: toda forma sem `fill` é preta. Quem desenha precisa
#   VER as cores enquanto desenha. Então o arquivo versionado leva o bloco
#   resolvido para o `flavor_padrao`, e `logo()` o REESCREVE a cada resolução.
#   O que manda é a `class`; o bloco é só a prévia. Um logo de terceiro sem
#   papel nenhum, com hex fixo, não é recusado: ele só não acompanha o flavor.
LOGO = "logo.svg"
SVG_NS = "{http://www.w3.org/2000/svg}"
ACCENT_NO_LOGO = "__ACCENT__"
PAPEIS_DO_LOGO = {
    "fundo":   "base",          # a placa; é o que separa o logo de qualquer fundo
    "tinta":   "text",          # o que se lê por cima da placa
    "sujeito": ACCENT_NO_LOGO,  # a cor do pack na cara dele — a mesma do accent
}
# O MESMO PADRÃO DO RESTO DO PROJETO, E NÃO UMA ESCOLHA NOVA: `${ACCENT:-mauve}`
# no `completar_icones.sh`, `--accent default="mauve"` no gerador de autorais.
ACCENT_PADRAO_DO_LOGO = "mauve"
# ASPAS DOS DOIS TIPOS, E O BLOCO AUTOFECHADO — revisão de 23/09/2026. A primeira
# versão só casava `id="meow-papeis"`: um `id='meow-papeis'` (XML válido, e o que
# alguns editores escrevem) passava batido, o bloco novo entrava ANTES do velho, o
# velho vencia a cascata e o logo ficava preso nas cores do `flavor_padrao` em
# todo flavor, com o id repetido. E um `<style id="meow-papeis"/>` vazio fazia o
# `.*?</style>` correr até o `</style>` do bloco SEGUINTE e apagá-lo junto.
RE_ESTILO_PAPEIS = re.compile(
    r"""\s*<style\b[^>]*?\bid\s*=\s*(["'])meow-papeis\1[^>]*?(?:/>|>.*?</style>)""", re.S)
RE_RAIZ_SVG = re.compile(r"<svg\b[^>]*>")
RE_URL_CSS = re.compile(r"""url\(\s*['"]?\s*([^)'"\s]*)""", re.I)
# O ESCAPE DE CSS: `\69` é `i`, `\72` é `r`, e `\x` é `x`. O CSS desfaz o escape
# ANTES de reconhecer a regra, então `@\69mport` É um `@import` e `u\72l(` É um
# `url(` — medido no Chromium em 23/09/2026: os dois buscaram o arquivo remoto.
# Quem confere o texto tem de ler o que o navegador lê.
RE_ESCAPE_CSS = re.compile(r"\\(?:([0-9a-fA-F]{1,6})[ \t\n\r\f]?|(.))", re.S)
XHTML_NS = "{http://www.w3.org/1999/xhtml}"

# O QUE UM LOGO NÃO PODE CARREGAR, e as regras são as que o docs/PACKS.md já
# declara para o pack inteiro ("um pack é dado, nunca é código"), aplicadas ao
# arquivo novo. `feImage` e `foreignObject` entram junto de `image` porque são a
# mesma porta com outro nome: o primeiro carrega imagem num filtro, o segundo
# carrega HTML inteiro dentro do SVG.
ELEMENTOS_RECUSADOS_NO_LOGO = {
    "script": "executa código",
    "image": "embute imagem (um logo é vetor, não uma foto dentro de um SVG)",
    "feImage": "embute imagem por dentro de um filtro",
    "foreignObject": "embute HTML dentro do SVG",
}


def _ler_logo(caminho, nome):
    """(texto, raiz, instruções) de um SVG, ou Recusa dizendo por que ele não é um SVG."""
    with open(caminho, "rb") as fh:
        bruto = fh.read()
    # PNG RENOMEADO É O CASO QUE A SPRINT NOMEIA, e ele não passa daqui: bytes
    # de imagem não decodificam como UTF-8 e, se decodificassem, não seriam XML.
    try:
        texto = bruto.decode("utf-8")
    except UnicodeDecodeError:
        raise Recusa(f"{nome}: não é texto — é um SVG de verdade, ou uma imagem "
                     f"renomeada?\n    Um PNG com nome de .svg não vira vetor.") from None
    # ENTIDADE DECLARADA É RECUSADA ANTES DE O PARSER VÊ-LA. Um `<!ENTITY>` que
    # se expande em si mesmo mil vezes (o "bilhão de risadas") trava quem valida,
    # e quem valida é também quem MOSTRA: o `logo()` confere o arquivo antes de
    # devolvê-lo à tela que pediu. Nenhum desenho precisa de entidade.
    _exigir("<!ENTITY" not in texto,
            f"{nome}: declara <!ENTITY> — um logo não precisa de entidade, e ela "
            f"pode travar quem o lê")
    try:
        raiz = ET.fromstring(bruto)
    except ET.ParseError as e:
        raise Recusa(f"{nome}: não é XML válido — {e}") from None
    # AS INSTRUÇÕES DE PROCESSAMENTO SÓ APARECEM POR EVENTO — revisão de 23/09.
    #   O `fromstring` joga fora todo `<?...?>`, e o validador nunca via um
    #   `<?xml-stylesheet href="https://..."?>` — que o navegador SEGUE, e que o
    #   `logo()` devolvia intacto. Uma segunda leitura, só pelos eventos `pi`,
    #   pega as do prólogo, as de dentro e as do fim; a declaração `<?xml ...?>`
    #   não é instrução e não aparece, e um `<?` dentro de comentário também não.
    leitor = ET.XMLPullParser(events=("pi",))
    leitor.feed(bruto)
    leitor.close()
    instrucoes = [el.text or "" for _evento, el in leitor.read_events()]
    return texto, raiz, instrucoes


def _nome_do_logo(p):
    """O arquivo do logo: o que `vitrine.capa` nomeia, ou `logo.svg` na falta dele."""
    v = p.get("vitrine")
    capa = v.get("capa") if isinstance(v, dict) else None
    return capa if isinstance(capa, str) and capa else LOGO


def _css_sem_escape(t):
    """O texto com os escapes de CSS desfeitos — o que o navegador lê. Ver RE_ESCAPE_CSS."""
    def um(m):
        if m.group(1) is None:
            return m.group(2)
        n = int(m.group(1), 16)
        return chr(n) if 0 < n <= 0x10FFFF and not 0xD800 <= n <= 0xDFFF else "\ufffd"
    return RE_ESCAPE_CSS.sub(um, t)


def _validar_logo(dir_pack, p):
    """Confere o logo e devolve (texto, raiz). Levanta Recusa na primeira falha, com o conserto."""
    arq = _nome_do_logo(p)
    # `_dentro` não é enfeite nem com o nome de convenção: ele segue link
    # simbólico. Um `logo.svg -> /etc/algo` sairia do pack por baixo do nome certo.
    caminho = _dentro(dir_pack, arq, "logo")
    _exigir(os.path.isfile(caminho),
            f"{arq}: o pack não tem logo — e desde 23/09/2026 todo pack publicado tem cara.\n"
            f"    Desenhe um SVG quadrado (viewBox 0 0 128 128), ou comece do gerado:\n"
            f"      python3 scripts/pack.py logo-gerado <id> > <pack>/{LOGO}\n"
            f"    Ver docs/PACKS.md, 'O logo do pack'.")
    texto, raiz, instrucoes = _ler_logo(caminho, arq)
    _exigir(raiz.tag == SVG_NS + "svg",
            f"{arq}: a raiz é <{raiz.tag}>, e não <svg> no namespace do SVG.\n"
            f"    Sem xmlns=\"http://www.w3.org/2000/svg\" o navegador não o desenha.")
    # NENHUMA, e não só a `xml-stylesheet`: um logo não precisa de instrução para
    # programa nenhum, e a lista das que um leitor segue não é nossa para manter.
    alvo_pi = instrucoes[0].split(None, 1)[0] if instrucoes else ""
    _exigir(not instrucoes,
            f"{arq}: tem <?{alvo_pi} ...?> — uma instrução de\n"
            f"    processamento. A <?xml-stylesheet?> busca folha de fora, e o navegador a segue.\n"
            f"    Um logo se basta: só a declaração <?xml ...?> do topo é aceita.")

    # QUADRADO, E COM viewBox: o mesmo arquivo serve ao cartão em quatro
    # tamanhos e ao lançador, que pede 48, 64, 128 e 256. Sem `viewBox` ele não
    # escala; retangular, ele é esticado ou ganha tarja.
    vb = (raiz.get("viewBox") or "").strip()
    partes = [x for x in re.split(r"[\s,]+", vb) if x]
    try:
        _x, _y, larg, alt = (float(x) for x in partes)
    except ValueError:
        raise Recusa(f"{arq}: precisa de viewBox com quatro números, veio {vb!r}") from None
    _exigir(larg > 0 and larg == alt,
            f"{arq}: o viewBox {vb!r} não é quadrado.\n"
            f"    O lançador pede o ícone em 48, 64, 128 e 256 — todos quadrados.")

    # SEM DISTINGUIR MAIÚSCULA, e o motivo é o cartão: o XML distingue, e um
    # `<Script>` não executa num SVG aberto como arquivo — mas se alguém um dia
    # colar este texto dentro de HTML, o parser do HTML baixa tudo para
    # minúscula e o `<SCRIPT>` roda. Recusar pelos dois leitores custa um `lower`.
    recusados = {k.lower(): v for k, v in ELEMENTOS_RECUSADOS_NO_LOGO.items()}
    for el in raiz.iter():
        nome = str(el.tag).rsplit("}", 1)[-1]
        _exigir(nome.lower() not in recusados,
                f"{arq}: tem <{nome}>, que {recusados.get(nome.lower())}. "
                f"Um pack é dado, nunca código.")
        # HTML DENTRO DO SVG, fora de um `foreignObject` — revisão de 23/09/2026.
        #   Ele não desenha nada ali, mas o navegador CRIA o elemento, e um `<img>`
        #   criado busca a imagem mesmo sem aparecer. Medido no Chromium:
        #   `<img xmlns="http://www.w3.org/1999/xhtml" src="https://...">` buscou,
        #   e passava por aqui porque a regra do `href` não olha `src`. Sai o
        #   namespace inteiro, e não uma lista de nomes (img, iframe, audio,
        #   video, object, link...) que envelhece a cada elemento novo do HTML.
        _exigir(not str(el.tag).startswith(XHTML_NS),
                f"{arq}: tem <{nome}> do HTML dentro do SVG. Ele não desenha nada ali, e o\n"
                f"    navegador o cria assim mesmo — um <img src> busca a imagem. Um logo é vetor.")
        textos = [el.text or ""] if nome.lower() == "style" else []
        for chave, valor in el.attrib.items():
            local = chave.rsplit("}", 1)[-1].lower()
            # `onload`, `onclick`... é `<script>` com outra roupa. A regra é
            # "sem script", e ela vale para a porta dos atributos também.
            _exigir(not local.startswith("on"),
                    f"{arq}: o atributo {local!r} executa código. Um pack é dado, nunca código.")
            # O LOGO É COPIADO PARA FORA DO PACK — para o tema de ícones, para o
            # cartão —, e é por isso que ele não pode apontar nem para o vizinho
            # de pasta: depois da cópia, `apps/x.svg` é um caminho quebrado. Só
            # referência interna (`#id`) sobrevive à viagem.
            if local == "href":
                _exigir(valor.strip().startswith("#"),
                        f"{arq}: href={valor!r} aponta para fora do arquivo.\n"
                        f"    Só referência interna (#id): o logo é copiado para o tema de\n"
                        f"    ícones, e lá fora nenhum outro caminho existe.")
            # O `href` TAMBÉM MUDA POR ANIMAÇÃO — revisão de 23/09/2026. Um
            #   `<a href="#a"><set attributeName="href" to="https://...">` passa na
            #   regra de cima com o `#a` e troca o destino depois de carregado; o
            #   `to`, o `from`, o `by` e o `values` são o `href` com outro nome.
            #   Animar o destino de um link não é desenho: recusa-se o alvo, e
            #   não cada um dos quatro atributos que o carregam. `xlink:href`
            #   termina em `href` também.
            if local == "attributename":
                _exigir(not valor.strip().lower().endswith("href"),
                        f"{arq}: <{nome} attributeName={valor!r}> troca o destino de um link\n"
                        f"    depois de carregado — é o href apontando para fora por outra porta.")
            textos.append(valor)
        for t in textos:
            # O QUE O CSS LÊ, E NÃO O QUE ESTÁ ESCRITO — revisão de 23/09/2026.
            #   `@IMPORT` passava porque o teste era `"@import" not in t`, e
            #   at-rule de CSS não distingue maiúscula; `@\69mport` e `u\72l(`
            #   passavam porque o escape só é desfeito pelo navegador. Os três
            #   buscaram o arquivo remoto no Chromium, medido. É o mesmo motivo do
            #   `lower` nos elementos, lá em cima, aplicado ao CSS.
            plano = _css_sem_escape(t)
            _exigir("@import" not in plano.lower(),
                    f"{arq}: <style> com @import busca folha de fora. Um logo se basta.")
            # `image-set("https://...")` aceita a URL como TEXTO, sem `url(` —
            # medido no Chromium: buscou. Um logo não troca de imagem por
            # densidade de tela; ele é vetor.
            _exigir("image-set(" not in plano.lower(),
                    f"{arq}: image-set() carrega imagem de fora. Um logo é vetor, e se basta.")
            for alvo in RE_URL_CSS.findall(plano):
                _exigir(alvo.startswith("#"),
                        f"{arq}: url({alvo}) aponta para fora do arquivo — URL remota\n"
                        f"    ou caminho, não importa: só url(#id) sobrevive à cópia.")
    return texto, raiz


def _cores_do_logo(dados, flavor, accent):
    """Papel ou nome -> hex, para um flavor e um accent daquela paleta."""
    cores = dados["flavors"][flavor]
    tabela = {s: cores[s] for s in SLOTS}
    for papel, slot in PAPEIS_DO_LOGO.items():
        tabela[papel] = cores[accent if slot == ACCENT_NO_LOGO else slot]
    return tabela


def _aplicar_papeis(texto, raiz, cores):
    """O texto do SVG com o bloco `meow-papeis` reescrito para essas cores.

    SÓ ENTRA REGRA PARA A CLASSE QUE O DESENHO USA. As 29 regras em todo logo
    fariam a prévia dizer que ele usa cores que ele não usa — e o arquivo é o
    lugar onde um autor de pack aprende o formato olhando.

    O TEXTO É EDITADO, NÃO RESERIALIZADO. O `ElementTree` reescreveria os
    prefixos de namespace (`ns0:`) e comeria os metadados do editor de quem
    desenhou — que é o arquivo que ela reabre no Boxy depois.
    """
    usadas = sorted({c for el in raiz.iter() for c in (el.get("class") or "").split()})
    regras = []
    for classe in usadas:
        papel = classe[len("traco-"):] if classe.startswith("traco-") else classe
        if papel in cores:
            prop = "stroke" if classe != papel else "fill"
            regras.append(f".{classe}{{{prop}:{cores[papel]}}}")
    # TODOS os blocos saem, e não só o primeiro: um arquivo que já tem dois (o
    # defeito do `id='meow-papeis'` produzia exatamente isso) se conserta na
    # primeira resolução, em vez de carregar o velho vencendo a cascata.
    sem_bloco = RE_ESTILO_PAPEIS.sub("", texto)
    abertura = RE_RAIZ_SVG.search(sem_bloco)
    if not regras or not abertura or abertura.group(0).endswith("/>"):
        return sem_bloco
    bloco = f'\n  <style id="meow-papeis">{"".join(regras)}</style>'
    return sem_bloco[:abertura.end()] + bloco + sem_bloco[abertura.end():]


def _flavor_e_accent(p, dados, flavor=None, accent=None):
    """Qual flavor e qual accent resolvem o logo, e a mesma precedência de sempre.

    O argumento vence; depois o ambiente (`FLAVOR` e `ACCENT`, que chegam do
    meow.conf); depois o `flavor_padrao` do pack. Um `FLAVOR` que não é deste
    pack — `dracula` perguntando pelo logo do catppuccin — cai no padrão dele, e
    não é erro: o cartão mostra todos os packs, e só um deles está no ar.
    """
    flavors = dados["flavors"]
    if flavor is not None:
        _exigir(flavor in flavors,
                f"o flavor {flavor!r} não existe neste pack — os que existem: "
                f"{', '.join(sorted(flavors))}")
    else:
        do_ambiente = os.environ.get("FLAVOR")
        flavor = do_ambiente if do_ambiente in flavors else (
            (p.get("paleta") or {}).get("flavor_padrao") or next(iter(flavors)))
    accent = accent or os.environ.get("ACCENT") or ACCENT_PADRAO_DO_LOGO
    _exigir(accent in SLOTS, f"o accent {accent!r} não é um dos 26 nomes da paleta")
    return flavor, accent


def logo(ref, flavor=None, accent=None):
    """O `logo.svg` do pack, com as cores resolvidas por papel. É a porta de LEITURA.

    Quem mostra o logo — o cartão do pack, o ícone do lançador — pergunta aqui,
    e não abre o arquivo cru: o cru traz a prévia do `flavor_padrao`, e a
    máquina pode estar no flavor claro.

    E ESTA PORTA CONFERE O ARQUIVO POR CONTA PRÓPRIA. O `validar` do motor
    (`silencioso=True`) não cobra o logo — ver o bloco "o logo" dele —, então é
    aqui que um logo com `<script>` ou `<?xml-stylesheet?>` deixa de chegar a
    quem mostra, mesmo vindo de um pack que nunca passou pelo `meow pack
    validar`. Sem logo, ou com um logo recusado, levanta Recusa: não há o que
    mostrar, e o tema do pack continua no ar do mesmo jeito.
    """
    p, dados, dir_pack = validar(ref, silencioso=True)
    texto, raiz = _validar_logo(dir_pack, p)
    flavor, accent = _flavor_e_accent(p, dados, flavor, accent)
    return _aplicar_papeis(texto, raiz, _cores_do_logo(dados, flavor, accent))


# --- o logo gerado, para o pack que ainda não tem cara -----------------------
#
# FEIO E HONESTO É MELHOR QUE AUSENTE — a regra que a P15 escreveu para a capa.
# A inicial do nome sobre o `base` do pack, com o accent como contorno. É o que o
# `meow pack novo` (P11) põe num pack recém-nascido, e é o ponto de partida de
# quem vai desenhar o seu: `pack.py logo-gerado <id> > <pack>/logo.svg`.
#
# A LETRA É TRAÇO, E NÃO `<text>`
#   `<text>` depende de fonte, e quem desenha ícone de tema no COSMIC é o resvg,
#   que só desenha texto quando alguém lhe entrega um banco de fontes. Uma inicial
#   que some em UM renderizador é o logo vazio que esta regra veio proibir. Então
#   a letra é caminho: uma grade de 4 x 6, pontas redondas, um glifo por
#   caractere que um `id` pode começar — `[a-z0-9]`, e mais nenhum.
_GLIFOS_DO_LOGO = {
    "a": "M0 6 L2 0 L4 6 M0.7 4 H3.3",
    "b": "M0 3 H2.5 Q4 3 4 4.5 Q4 6 2.5 6 H0 V0 H2.2 Q3.6 0 3.6 1.5 Q3.6 3 2.2 3",
    "c": "M4 1 Q3.3 0 2 0 Q0 0 0 3 Q0 6 2 6 Q3.3 6 4 5",
    "d": "M0 0 V6 H1.6 Q4 6 4 3 Q4 0 1.6 0 Z",
    "e": "M4 0 H0 V6 H4 M0 3 H3",
    "f": "M4 0 H0 V6 M0 3 H3",
    "g": "M4 1 Q3.3 0 2 0 Q0 0 0 3 Q0 6 2 6 Q4 6 4 3.6 H2.2",
    "h": "M0 0 V6 M4 0 V6 M0 3 H4",
    "i": "M1 0 H3 M2 0 V6 M1 6 H3",
    "j": "M4 0 V4.2 Q4 6 2 6 Q0 6 0 4.2",
    "k": "M0 0 V6 M4 0 L0 3.8 M1.3 2.6 L4 6",
    "l": "M0 0 V6 H4",
    "m": "M0 6 V0 L2 3.6 L4 0 V6",
    "n": "M0 6 V0 L4 6 V0",
    "o": "M2 0 Q0 0 0 3 Q0 6 2 6 Q4 6 4 3 Q4 0 2 0 Z",
    "p": "M0 6 V0 H2.3 Q4 0 4 1.7 Q4 3.4 2.3 3.4 H0",
    "q": "M2 0 Q0 0 0 3 Q0 6 2 6 Q4 6 4 3 Q4 0 2 0 Z M2.6 4.4 L4 6",
    "r": "M0 6 V0 H2.3 Q4 0 4 1.7 Q4 3.4 2.3 3.4 H0 M2 3.4 L4 6",
    "s": "M4 0.9 Q3.3 0 2 0 Q0 0 0 1.6 Q0 3 2 3 Q4 3 4 4.4 Q4 6 2 6 Q0.7 6 0 5.1",
    "t": "M0 0 H4 M2 0 V6",
    "u": "M0 0 V4 Q0 6 2 6 Q4 6 4 4 V0",
    "v": "M0 0 L2 6 L4 0",
    "w": "M0 0 L1 6 L2 2.4 L3 6 L4 0",
    "x": "M0 0 L4 6 M4 0 L0 6",
    "y": "M0 0 L2 3 L4 0 M2 3 V6",
    "z": "M0 0 H4 L0 6 H4",
    "0": "M2 0 Q0 0 0 3 Q0 6 2 6 Q4 6 4 3 Q4 0 2 0 Z M3.3 1.2 L0.7 4.8",
    "1": "M0.8 1.2 L2.2 0 V6 M0.8 6 H3.6",
    "2": "M0 1.2 Q0.6 0 2 0 Q4 0 4 1.8 Q4 3 2.4 4 L0 6 H4",
    "3": "M0 0.8 Q0.8 0 2 0 Q3.8 0 3.8 1.5 Q3.8 3 2 3 Q4 3 4 4.5 Q4 6 2 6 Q0.8 6 0 5.2",
    "4": "M3 6 V0 L0 4.2 H4",
    "5": "M3.8 0 H0.4 L0 3 Q0.8 2.4 2 2.4 Q4 2.4 4 4.2 Q4 6 2 6 Q0.8 6 0 5.2",
    "6": "M3.6 0.6 Q3 0 2 0 Q0 0 0 3.4 V4 Q0 6 2 6 Q4 6 4 4.1 Q4 2.4 2 2.4 Q0.6 2.4 0 3.6",
    "7": "M0 0 H4 L1.4 6",
    "8": ("M2 3 Q0.2 3 0.2 1.5 Q0.2 0 2 0 Q3.8 0 3.8 1.5 Q3.8 3 2 3 "
          "Q0 3 0 4.5 Q0 6 2 6 Q4 6 4 4.5 Q4 3 2 3 Z"),
    "9": "M0.4 5.4 Q1 6 2 6 Q4 6 4 2.6 V2 Q4 0 2 0 Q0 0 0 1.9 Q0 3.6 2 3.6 Q3.4 3.6 4 2.4",
}


def _glifo_no_quadro(d, x0, y0, escala):
    """O glifo da grade 4 x 6, levado para o quadro de 128 por conta, sem `transform`.

    Sem `transform` porque ele escalaria o TRAÇO junto — e a espessura tem de
    ser a mesma em todo glifo, que é o que faz o gerado parecer uma letra só.
    """
    saida, comando, n = [], "", 0
    for ficha in re.findall(r"[A-Z]|-?\d+(?:\.\d+)?", d):
        if ficha.isalpha():
            comando, n = ficha, 0
            saida.append(ficha)
            continue
        eixo_x = comando == "H" or (comando != "V" and n % 2 == 0)
        v = (x0 if eixo_x else y0) + float(ficha) * escala
        saida.append(f"{v:.2f}".rstrip("0").rstrip("."))
        n += 1
    return " ".join(saida)


def logo_gerado(nome, ident):
    """O SVG do logo gerado, com as formas declaradas por papel e SEM o bloco de cores."""
    import unicodedata
    from xml.sax.saxutils import escape, quoteattr

    # A INICIAL É A PRIMEIRA LETRA OU ALGARISMO DO NOME, E SÓ ELA — revisão de
    # 23/09/2026. Símbolo e espaço na frente não são letra e são pulados (`* Nord`
    # dá `n`); o acento cai na letra base pela decomposição (`Árvore` dá `a`).
    # Se ESSA letra não tem glifo na grade — `Ωmega`, `日本` —, a inicial vem do
    # id, que o `validar` garante começar por [a-z0-9]. A primeira versão varria o
    # nome inteiro atrás de qualquer caractere com glifo, e `Ωmega` saía `m`:
    # uma letra do meio, que ninguém lê como a inicial do pack.
    def inicial_de(texto):
        c = next((c for c in texto if c.isalnum()), "")
        base = unicodedata.normalize("NFKD", c)[:1].lower()
        return base if base in _GLIFOS_DO_LOGO else None
    inicial = inicial_de(nome) or inicial_de(ident) or "o"
    # A letra ocupa 36 x 54 no centro do quadro de 128: grande o bastante para
    # ler a 48px (o traço de 10 vira ~3,75px), com a placa respirando em volta.
    letra = _glifo_no_quadro(_GLIFOS_DO_LOGO[inicial], 46, 37, 9)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" '
            f'width="128" height="128" role="img" aria-label={quoteattr(nome)}>\n'
            f'  <title>{escape(nome)} — logo gerado pelo MeowSystem</title>\n'
            f'  <rect class="fundo traco-sujeito" x="8" y="8" width="112" height="112" '
            f'rx="26" stroke-width="8"/>\n'
            f'  <path class="traco-tinta" d="{letra}" fill="none" stroke-width="10" '
            f'stroke-linecap="round" stroke-linejoin="round"/>\n'
            f'</svg>\n')


def cmd_logo_gerado(ref, flavor=None, accent=None):
    """Imprime o logo gerado do pack, resolvido. NÃO ESCREVE NADA.

    O docs/PACKS.md promete que o MeowSystem nunca escreve dentro de um pack, e
    quem decide pôr este desenho no lugar do dela é ela, com um `>`. Sobrescrever
    um logo que alguém desenhou para "consertar" um pack é o erro que não se
    desfaz com Ctrl+C.

    O `validar` do motor, que não cobra o logo: o resto do pack precisa estar
    são, porque o gerado nasce da paleta dele — e o logo é justamente o que
    este verbo existe para dar a quem ainda não tem.
    """
    p, dados, dir_pack = validar(ref, silencioso=True)
    svg = logo_gerado(str(p.get("nome") or p["id"]), str(p["id"]))
    flavor, accent = _flavor_e_accent(p, dados, flavor, accent)
    sys.stdout.write(_aplicar_papeis(svg, ET.fromstring(svg), _cores_do_logo(dados, flavor, accent)))
    return OK


# A VITRINE — 23/09/2026, sprint P15
#
# POR QUE ELA EXISTE
#   Até aqui um pack era um `id` e 26 hexadecimais. A tela que escolhe um pack
#   não tinha o que desenhar, e ninguém escolhe um tema por um `id`. O bloco
#   `vitrine` é o que o pack diz de si para quem vai escolher: a capa, uma frase,
#   a história inteira, as etiquetas, as fotos e o endereço de casa.
#
# A CAPA É O LOGO, E É UM CAMPO SÓ
#   A P25 corrigiu o mockup de 21/09, que desenhava a capa como uma tira de
#   cores: tira é paleta, não identidade — dois packs de paleta parecida ficam
#   iguais no cartão. `vitrine.capa` aponta para o logo que a P25 desenha, o
#   mesmo arquivo que vira o ícone do lançador; por convenção, `logo.svg`. Um
#   `vitrine.logo` ao lado seriam duas verdades para a mesma figura, e a segunda
#   envelhece calada. Aqui mora o CAMPO — declarado, SVG pelo nome, dentro do
#   pack, existindo. O que vai DENTRO do arquivo (viewBox quadrado, sem script,
#   nada apontando para fora) é o `_validar_logo` da P25, acima.
#
#   E NENHUMA CAPA ESCAPA DA CONFERÊNCIA DO LOGO [23/09/2026, revisão da P15]
#   A revisão pegou que uma `capa.svg` ao lado do `logo.svg` passaria por fora
#   da conferência de conteúdo e recriaria as duas verdades. Quem fechou foi a
#   P25 (a3ee4a6): o logo É o arquivo que `vitrine.capa` nomeia (`_nome_do_logo`),
#   e `logo.svg` só na falta do campo. Então a capa, qualquer que seja o nome,
#   passa pelo `_validar_logo` no verbo `validar` e no `logo()`, que é a porta
#   de quem mostra — e o `/pack-vitrine` do painel serve a capa por ela.
#
# ELA É COBRADA DE QUEM PUBLICA, E NUNCA DE QUEM USA
#   `validar(silencioso=True)` é a porta do MOTOR: o `caminho` que o
#   `meow_pack_dir` (lib/comum.sh) usa como sonda de existência, a `paleta`, o
#   `som`, o `construir`. Se a vitrine entrasse ali, uma capa ausente faria o
#   pack SUMIR do desktop — o tema inteiro trocado pelo padrão, com um aviso de
#   "não resolve", por causa de uma figura que só a tela de escolha mostra.
#   Então quem cobra é o verbo `validar`, que é a pergunta de quem publica (e o
#   `meow pack listar`, que o chama para dizer "não valida"). A P25 pôs o logo
#   na mesma fronteira (a3ee4a6), e a capa ausente — que é o logo ausente — não
#   tira o tema do desktop por nenhuma das duas portas.
#
#   COM UMA EXCEÇÃO, QUE NÃO É DESTA FUNÇÃO [23/09/2026, revisão da P15]: uma
#   URL que não seja https:// em QUALQUER campo do `pack.json` — o
#   `vitrine.site`, ou uma `descricao_curta` que cite `http://` — cai na
#   varredura de URL do `validar`, que é anterior à vitrine, vale para o pack
#   inteiro e roda também no motor. Medido: com `"site": "http://..."` o
#   `caminho` e o `info` recusam o pack. Este bloco dizia o contrário. O que só
#   esta função pega é o esquema sem `://`, que a varredura não vê
#   (`javascript:alert(1)`, lá embaixo).
#
# ELA NÃO LEVANTA: DEVOLVE O QUE VALE, E A LISTA DO QUE NÃO VALE
#   Quem a lê são três — o `validar`, o `cmd_info` e o `/api/packs` do painel —,
#   e só o primeiro recusa por ela. Os outros dois mostram o pack assim mesmo,
#   dizendo o que falta — desde que ele tenha passado pela porta do motor, que
#   eles também atravessam (ver a exceção logo acima). O valor que não passa na
#   regra SAI da resposta em vez de ir junto com o aviso: a URL que não é https
#   não vira link, o caminho que sai do pack não é servido. É isso que deixa o
#   painel usar a vitrine de um pack de terceiro sem repetir regra nenhuma do
#   lado de lá.
#
# O TETO DE 80 É O DOS BALÕES DA P6, pelo mesmo motivo: é o que cabe numa linha
#   do cartão sem virar parágrafo. O da descrição longa não é estética — o texto
#   viaja inteiro no `/api/packs`, e um LEIA-ME de pack é uma página, não um
#   livro.
TETO_DESCRICAO_CURTA = 80
TETO_DESCRICAO = 64 * 1024
# As mesmas quatro que a rota `/previa` do painel já serve. Uma quinta aqui
# seria uma captura que valida e não aparece.
EXT_CAPTURA = (".png", ".jpg", ".jpeg", ".svg")


def vitrine(p, dir_pack):
    """(vitrine conferida, problemas). Nunca levanta — ver o bloco acima.

    Os caminhos da resposta já vêm resolvidos (realpath, dentro do pack,
    existindo); o que não passou numa regra volta vazio e vira uma linha em
    `problemas`, nomeando o campo.
    """
    saida = {"capa": None, "descricao_curta": "", "descricao": None,
             "tags": [], "capturas": [], "site": None}
    v = p.get("vitrine")
    if not isinstance(v, dict):
        return saida, [
            "pack.json: falta o bloco 'vitrine', e a capa dele é obrigatória.\n"
            "    O mínimo é  \"vitrine\": {\"capa\": \"logo.svg\"}  — ver docs/PACKS.md,\n"
            "    'A vitrine'. O tema funciona sem ela; quem escolhe um pack é que não\n"
            "    tem o que ver."]
    problemas = []

    def arquivo(campo, valor, extensoes, porque):
        # O MESMO MECANISMO DO `creditos` DA P20, lá embaixo no `validar`: o
        # caminho declarado passa pelo `_dentro` e é aberto, não só olhado. Um
        # pack que promete a capa e não entrega é o pack que "promete e não
        # entrega" que aquele comentário descreve.
        if not isinstance(valor, str) or not valor:
            problemas.append(f"{campo}: precisa ser o caminho de um arquivo dentro do pack")
            return None
        if not valor.lower().endswith(extensoes):
            problemas.append(f"{campo}: {valor!r} não é {' nem '.join(extensoes)}. {porque}")
            return None
        try:
            alvo = _dentro(dir_pack, valor, campo)
        except Recusa as e:
            problemas.append(str(e))
            return None
        if not os.path.isfile(alvo):
            problemas.append(f"{campo}: {valor!r} está declarado e NÃO existe no pack.\n"
                             f"    Ou crie o arquivo, ou tire o campo.")
            return None
        return alvo

    if "capa" not in v:
        problemas.append("vitrine.capa: é obrigatória — o cartão do pack é a capa. "
                         "Por convenção, \"logo.svg\"")
    else:
        saida["capa"] = arquivo(
            "vitrine.capa", v["capa"], (".svg",),
            "Vetor porque a mesma capa serve ao cartão e ao lançador,\n"
            "    em vários tamanhos, e um PNG envelhece junto com a resolução.")

    curta = v.get("descricao_curta", "")
    if not isinstance(curta, str):
        problemas.append("vitrine.descricao_curta: precisa ser texto")
    elif "\n" in curta:
        problemas.append("vitrine.descricao_curta: é UMA linha — a história inteira vai "
                         "no arquivo de vitrine.descricao")
    elif len(curta) > TETO_DESCRICAO_CURTA:
        problemas.append(f"vitrine.descricao_curta tem {len(curta)} caracteres, e o teto é "
                         f"{TETO_DESCRICAO_CURTA}.\n"
                         f"    É o que cabe numa linha do cartão. O resto vai em vitrine.descricao.")
    else:
        saida["descricao_curta"] = curta

    if v.get("descricao") is not None:
        alvo = arquivo("vitrine.descricao", v["descricao"], (".md",),
                       "A história do pack é um Markdown dentro dele.")
        if alvo and os.path.getsize(alvo) > TETO_DESCRICAO:
            problemas.append(f"vitrine.descricao: {v['descricao']!r} passa de "
                             f"{TETO_DESCRICAO // 1024} KiB — ela viaja inteira até o painel")
        elif alvo:
            saida["descricao"] = alvo

    tags = v.get("tags", [])
    if not isinstance(tags, list) or not all(isinstance(t, str) and t.strip() for t in tags):
        problemas.append("vitrine.tags: precisa ser uma lista de textos não vazios")
    else:
        saida["tags"] = [t.strip() for t in tags]

    capturas = v.get("capturas", [])
    if not isinstance(capturas, list):
        problemas.append("vitrine.capturas: precisa ser uma lista de caminhos")
    else:
        for i, c in enumerate(capturas):
            alvo = arquivo(f"vitrine.capturas[{i}]", c, EXT_CAPTURA,
                           "São as quatro que o painel sabe mostrar.")
            if alvo:
                saida["capturas"].append(alvo)

    # O `https://` É COBRADO AQUI DE NOVO, E NÃO É REDUNDÂNCIA
    #   A varredura de URLs do `validar` só olha texto que tenha `://` — e
    #   `javascript:alert(1)` não tem. O `site` é o único campo do formato que
    #   vira LINK clicável numa página com token de sessão; um esquema que não
    #   seja https ali é código de terceiro rodando no painel.
    site = v.get("site")
    if site is not None:
        if isinstance(site, str) and site.startswith("https://"):
            saida["site"] = site
        else:
            problemas.append(f"vitrine.site: {site!r} — só https:// vira link no cartão")
    return saida, problemas


def validar(ref, silencioso=False):
    """Confere o pack. Levanta Recusa na primeira falha, com o que consertar."""
    dir_pack = achar(ref)
    _exigir(dir_pack, f"não achei o pack {ref!r}.\n"
                      f"    procurei em:\n      " + "\n      ".join(raizes()))

    caminho_json = os.path.join(dir_pack, "pack.json")
    try:
        with open(caminho_json, encoding="utf-8") as fh:
            p = json.load(fh)
    except json.JSONDecodeError as e:
        raise Recusa(f"pack.json não é JSON válido: linha {e.lineno}, coluna {e.colno} — {e.msg}")

    # --- identidade ---------------------------------------------------------
    for campo in ("formato", "id", "nome"):
        _exigir(campo in p, f"pack.json: falta o campo obrigatório {campo!r}")

    _exigir(isinstance(p["formato"], int),
            f"pack.json: 'formato' precisa ser inteiro, veio {type(p['formato']).__name__}")
    _exigir(FORMATO_MIN <= p["formato"] <= FORMATO_MAX,
            f"pack.json: formato {p['formato']} não é suportado "
            f"(este MeowSystem entende de {FORMATO_MIN} a {FORMATO_MAX}).\n"
            f"    Um pack de formato maior pede um MeowSystem mais novo.")

    _exigir(RE_ID.match(str(p["id"])),
            f"pack.json: id {p['id']!r} — só minúsculas, dígitos e hífen")
    esperado = os.path.basename(dir_pack)
    _exigir(p["id"] == esperado,
            f"pack.json: id é {p['id']!r} mas o diretório chama-se {esperado!r}.\n"
            f"    Os dois precisam bater — o id é como o meow.conf nomeia o pack.")

    # --- paleta -------------------------------------------------------------
    pal = p.get("paleta") or {}
    arq = pal.get("arquivo", "paleta.json")
    caminho_pal = _dentro(dir_pack, arq, "paleta.arquivo")
    _exigir(os.path.isfile(caminho_pal), f"paleta.arquivo: {arq!r} não existe no pack")

    try:
        with open(caminho_pal, encoding="utf-8") as fh:
            dados = json.load(fh)
    except json.JSONDecodeError as e:
        raise Recusa(f"{arq}: não é JSON válido: linha {e.lineno} — {e.msg}")

    for campo in ("flavors", "nomes", "claros"):
        _exigir(campo in dados, f"{arq}: falta o campo {campo!r}")
    _exigir(isinstance(dados["flavors"], dict) and dados["flavors"],
            f"{arq}: 'flavors' está vazio")

    # NOME DE FLAVOR NÃO PODE TER HÍFEN [19/09/2026]
    #   O gerador monta o arquivo de tema como "<flavor>-<accent>" e o leitor
    #   corta no hífen. Um flavor chamado "dracula-claro" vira flavor "dracula"
    #   com accent "claro-mauve" — e o erro que aparece é
    #   `accent 'claro-mauve' não é uma cor`, que manda procurar defeito no
    #   lugar errado. Medido aqui ao nomear o flavor claro do Dracula.
    #   Recusar na validação custa uma linha; descobrir isso na tela custa uma
    #   tarde.
    for flavor in dados["flavors"]:
        _exigir("-" not in flavor,
                f"{arq}: o flavor {flavor!r} tem hífen no nome.\n"
                f"    O tema é gravado como '<flavor>-<accent>', e o hífen parte\n"
                f"    o nome no lugar errado. Use uma palavra só: o Catppuccin\n"
                f"    faz 'latte'/'mocha', e o Dracula claro daqui é 'alucard'.")

    # Os 26 slots, e o erro diz TODOS os que faltam de uma vez.
    for flavor, cores in dados["flavors"].items():
        faltam = [s for s in SLOTS if s not in cores]
        _exigir(not faltam,
                f"{arq}: o flavor {flavor!r} não tem {len(faltam)} slot(s):\n"
                f"      {', '.join(faltam)}\n"
                f"    Os 26 são obrigatórios. Se o seu tema não tem tantas cores,\n"
                f"    derive as que faltarem — ver docs/PACKS.md, 'As 26 cores'.")
        ruins = [f"{s}={cores[s]!r}" for s in SLOTS if not RE_HEX.match(str(cores[s]))]
        _exigir(not ruins,
                f"{arq}: no flavor {flavor!r}, {len(ruins)} cor(es) fora do formato #RRGGBB:\n"
                f"      {', '.join(ruins[:8])}")

    padrao = pal.get("flavor_padrao")
    if padrao is not None:
        _exigir(padrao in dados["flavors"],
                f"pack.json: paleta.flavor_padrao é {padrao!r}, que não existe em {arq}.\n"
                f"    Os que existem: {', '.join(sorted(dados['flavors']))}")

    # --- contraste ----------------------------------------------------------
    # 26 hexes aleatórios passam em tudo acima e produzem interface ilegível.
    for flavor, cores in dados["flavors"].items():
        r = contraste(cores["text"], cores["base"])
        _exigir(r >= MINIMO_VALIDAR,
                f"{arq}: no flavor {flavor!r}, 'text' sobre 'base' tem contraste "
                f"{r:.2f}:1 — WCAG AA pede {MINIMO_VALIDAR}:1.\n"
                f"      text={cores['text']}  base={cores['base']}\n"
                f"    Com esse contraste a interface fica ilegível. Escureça o fundo\n"
                f"    ou clareie o texto.")

    # --- caminhos declarados ------------------------------------------------
    ic = p.get("icones") or {}
    # AS QUATRO CATEGORIAS, E NÃO DUAS — 22/09/2026
    #   Eram `apps` e `pastas`. `mimetypes` e `autorais` não eram cobradas, e o
    #   silêncio era o de sempre: um pack que declarasse
    #   `icones.autorais.desenhos` apontando para um diretório inexistente saía
    #   0 aqui e falhava lá adiante, no gerador, com um traceback que fala de
    #   Path e não de pack.json. A P27 deu acervo próprio às duas — o
    #   `icones/autorais/` dos dois packs e o `icones/mimetypes.map` do
    #   Catppuccin —, então a validação que já existia para as outras duas passa
    #   a valer para elas pelo mesmo motivo que o comentário do `creditos`
    #   explica algumas linhas abaixo: um pack que promete arquivo e não entrega
    #   não está sendo validado, está sendo carimbado.
    #
    #   `mapa` E `desenhos` NAS QUATRO, e não um par diferente para cada: a
    #   forma de `packs/<id>/icones/` é a MESMA para toda categoria e para todo
    #   pack (é o que a P27 chama de "a estrutura completa"). Uma tabela com
    #   exceção por categoria seria a próxima que alguém esquece de atualizar —
    #   e a chave que a categoria não declara simplesmente não é cobrada.
    for cat, chaves in (("apps", ("mapa", "desenhos")),
                        ("pastas", ("mapa", "desenhos")),
                        ("mimetypes", ("mapa", "desenhos")),
                        ("autorais", ("mapa", "desenhos"))):
        bloco = ic.get(cat) or {}
        for chave in chaves:
            if bloco.get(chave):
                alvo = _dentro(dir_pack, bloco[chave], f"icones.{cat}.{chave}")
                _exigir(os.path.exists(alvo),
                        f"icones.{cat}.{chave}: {bloco[chave]!r} não existe no pack")

    # AS LINHAS DO MAPA DE APLICATIVOS — regras 1 e 4 da P28, 23/09/2026
    #   Até aqui o `validar` conferia que o MAPA existe, e não o que ele diz. Um
    #   pack com `waterfox : ~/.local/share/icons/Dracula-Icones/...` saía 0: a
    #   linha só virava problema dentro do instalador, na máquina de quem
    #   instalou, e como aviso de "desenho ausente" — nunca como "este mapa
    #   aponta para a máquina". E dois `steam :` no mesmo mapa passavam também,
    #   com o segundo vencendo calado.
    #
    #   Duas recusas, e cada uma diz a linha:
    #     · alvo fora das três casas (pack, `motor:`, `pack:`) — regra 4;
    #     · o mesmo nome duas vezes — regra 1, "um nome, uma fonte". É erro de
    #       validação, e não escolha de precedência.
    #   Só o `apps`: é o único mapa de pack cujo formato é `nome : alvo`. O
    #   `mimetypes.map` casa tipo de arquivo com glifo, e outro formato pede
    #   outro leitor.
    #
    #   ALVO AUSENTE NÃO É RECUSA AQUI, e foi medido: o `validar` é também a
    #   sonda de existência do `meow_pack_dir` (via `caminho`), e um pack
    #   recusado é um pack IGNORADO inteiro — "usando o padrão". Recusar por
    #   um desenho que falta trocaria o tema da pessoa por causa de um ícone; o
    #   `tests/pack.sh` pegou isso na primeira rodada (o pack de brinquedo dele
    #   mapeia um `firefox` sem desenho). Nome sem desenho continua dito, onde
    #   ele é notícia: o instalador avisa "no mapa mas sem desenho no disco", o
    #   `pack.py fonte` sai 1 e o `tests/fonte-unica.sh` falha para os packs
    #   do repositório.
    mapa_apps = (ic.get("apps") or {}).get("mapa")
    if mapa_apps:
        caminho_mapa = _dentro(dir_pack, mapa_apps, "icones.apps.mapa")
        base_mapa, vistos = os.path.dirname(caminho_mapa), {}
        for num, nome, alvo in ler_mapa(caminho_mapa):
            _exigir(nome not in vistos,
                    f"{mapa_apps}:{num}: {nome!r} já está na linha {vistos.get(nome)}.\n"
                    f"    Um nome, uma fonte: com duas, quem vence é o que o\n"
                    f"    instalador ler por último, e ninguém escolheu isso.")
            vistos[nome] = num
            try:
                resolver_alvo(alvo, base_mapa)
            except Recusa as e:
                raise Recusa(f"{mapa_apps}:{num}: {e}") from None

    # AS DECLARAÇÕES DE DESENHO AUTORAL — 23/09/2026, sprint P26
    #   Os `.json` da pasta `icones.autorais.desenhos` viraram a entrada do
    #   gerador: um terceiro desenho entra copiando um arquivo, sem tocar em
    #   Python. Sem esta conferência, um papel com a cor escrita errado passava
    #   aqui e morria no gerador, dentro do instalador, longe de quem publicou o
    #   pack. As regras são as do `ler_autoral`, e só ele as conhece.
    #
    #   SÓ AS DO PRÓPRIO PACK: a declaração herdada é validada no pack de onde
    #   ela vem. E a paleta não precisa ser consultada de novo — uma declaração
    #   só aceita os 26 nomes que todo pack é obrigado a ter, conferidos acima.
    #
    #   A PASTA É A MESMA QUE O GERADOR LÊ (revisão, 23/09/2026): a declarada ou,
    #   sem `desenhos`, a `PASTA_AUTORAIS`. Conferir só a declarada, com o
    #   `autorais()` já lendo a padrão, deixaria o pack do modelo do PACKS.md
    #   passar aqui com qualquer `.json` naquela pasta, e a recusa só sairia no
    #   `construir`, dentro do instalador.
    pasta_aut = dir_acervo("icones.autorais.desenhos", ref=dir_pack, padrao=PASTA_AUTORAIS)
    if os.path.isdir(pasta_aut):
        for arq in sorted(os.listdir(pasta_aut)):
            if arq.endswith(".json"):
                ler_autoral(os.path.join(pasta_aut, arq))

    if (p.get("cosmic") or {}).get("mapa"):
        alvo = _dentro(dir_pack, p["cosmic"]["mapa"], "cosmic.mapa")
        _exigir(os.path.isfile(alvo), f"cosmic.mapa: {p['cosmic']['mapa']!r} não existe")

    # O ARQUIVO PROMETIDO E AUSENTE PASSAVA — 21/09/2026
    #   O `packs/dracula/pack.json` declara `"creditos": "CREDITOS.md"` desde que
    #   nasceu, o arquivo NUNCA esteve no pack, e `meow pack validar dracula`
    #   saía 0. Um validador que aprova um pack que promete um arquivo que não
    #   entrega não está validando o formato: está carimbando.
    #
    #   `creditos` É O ÚNICO CAMPO DE ARQUIVO QUE FALTAVA AQUI. Os outros
    #   quatro — `paleta.arquivo`, `icones.*.mapa`, `icones.*.desenhos` e
    #   `cosmic.mapa` — já são cobrados acima. Campo de arquivo novo entra nesta
    #   vizinhança, e não numa tabela à parte: uma segunda lista de "campos que
    #   nomeiam arquivo" seria a próxima que alguém esquece de atualizar.
    if p.get("creditos"):
        alvo = _dentro(dir_pack, p["creditos"], "creditos")
        _exigir(os.path.isfile(alvo),
                f"creditos: {p['creditos']!r} está declarado e NÃO existe no pack.\n"
                f"    Ou crie o arquivo, ou tire o campo. Um pack que promete\n"
                f"    crédito de arte e não entrega ensina a promessa vazia —\n"
                f"    e quem copiar este pack.json vai repetir a promessa.")

    # --- apps ---------------------------------------------------------------
    # OS TEMAS DE APLICATIVO — 22/09/2026, sprint P18
    #   `apps` NÃO é `icones.apps`, e a coincidência de nome é a primeira pedra
    #   do caminho: `icones.apps` são os ÍCONES dos aplicativos, este bloco é o
    #   TEMA de dentro deles (o esquema do spicetify, o `.qbtheme`). As trilhas
    #   não colidem, mas quem lê o pack.json de cima para baixo colide.
    #
    #   A VALIDAÇÃO É A MESMA DO `creditos`, TRÊS LINHAS ACIMA, E DE PROPÓSITO:
    #   um pack que declara `arquivo` e não entrega o arquivo é um pack que
    #   promete tema e não tem tema — e o módulo só descobriria na hora de
    #   aplicar, dentro do instalador, longe de quem publicou o pack.
    apps = p.get("apps") or {}
    _exigir(isinstance(apps, dict), "pack.json: 'apps' precisa ser um objeto")
    for nome_app, bloco in apps.items():
        if str(nome_app).startswith("_"):
            continue
        _exigir(RE_ID.match(str(nome_app)),
                f"apps: {nome_app!r} — só minúsculas, dígitos e hífen, como todo id")
        _exigir(isinstance(bloco, dict),
                f"apps.{nome_app}: precisa ser um objeto, veio {type(bloco).__name__}")
        arq_app = bloco.get("arquivo")
        if arq_app:
            alvo_app = _dentro(dir_pack, str(arq_app), f"apps.{nome_app}.arquivo")
            _exigir(os.path.isfile(alvo_app),
                    f"apps.{nome_app}.arquivo: {arq_app!r} está declarado e NÃO\n"
                    f"    existe no pack. Um pack que promete tema e não entrega\n"
                    f"    só falha dentro do instalador, na máquina de quem instalou.")
        soma_app = bloco.get("sha256")
        if soma_app:
            _exigir(RE_SHA256.match(str(soma_app)),
                    f"apps.{nome_app}.sha256: {soma_app!r} não é um sha256 (64 hex)")
            _exigir(arq_app,
                    f"apps.{nome_app}.sha256: declarado sem `arquivo` — não há o que conferir")
            with open(alvo_app, "rb") as fh:
                medido = hashlib.sha256(fh.read()).hexdigest()
            # O SHA VEM DO PACK, E NÃO DO MÓDULO [22/09/2026]
            #   Até hoje o número morava no `qbittorrent/manifesto.sh`, cravado
            #   ao lado do nome do arquivo. Um módulo que confere o sha de UM
            #   arquivo específico é um módulo que só sabe aplicar aquele tema —
            #   é a mesma amarra que esta sprint veio cortar, escrita em hex.
            _exigir(medido == str(soma_app).lower(),
                    f"apps.{nome_app}.sha256 não confere com o arquivo.\n"
                    f"    declarado: {soma_app}\n"
                    f"    medido   : {medido}")

    # --- som ----------------------------------------------------------------
    # O timbre é opcional. Quando existe, precisa ser NÚMERO e precisa caber nos
    # limites que o som.sh documenta — um pack não pode assustar quem o instala.
    som = p.get("som") or {}
    LIMITES = {
        # chave            mín      máx     por quê o teto
        "fundamental":    (60.0,  8000.0),   # fora disso não é sino, é ruído
        "harmonico":      (60.0, 12000.0),
        "peso_fundamental": (0.0,   1.0),
        "peso_harmonico":   (0.0,   1.0),
        "decaimento":      (5.0,  200.0),    # abaixo de 5 a cauda nunca acaba
        "duracao":        (0.010,  0.125),   # o teto é o debounce do cosmic-osd
        "ganho":           (0.0,    0.40),   # acima disso muda o SUSTO, não o timbre
    }
    for chave, valor in som.items():
        if chave.startswith("_"):
            continue
        _exigir(chave in LIMITES,
                f"pack.json: som.{chave} não é uma chave conhecida.\n"
                f"    As que existem: {', '.join(sorted(LIMITES))}")
        _exigir(isinstance(valor, (int, float)) and not isinstance(valor, bool),
                f"pack.json: som.{chave} precisa ser número, veio {valor!r}")
        lo, hi = LIMITES[chave]
        _exigir(lo <= valor <= hi,
                f"pack.json: som.{chave} = {valor} está fora de [{lo}, {hi}].\n"
                f"    O motivo de cada limite está em scripts/som.sh, bloco 'O TIMBRE'.")
    soma = float(som.get("peso_fundamental", 0.62)) + float(som.get("peso_harmonico", 0.28))
    _exigir(soma <= 1.0,
            f"pack.json: som.peso_fundamental + som.peso_harmonico = {soma:.2f} > 1.0.\n"
            f"    Acima de 1 o ganho satura e a onda é cortada — soa como estalo,\n"
            f"    não como sino.")

    # --- heranças e URLs ----------------------------------------------------
    herancas = [p["heranca"]] if p.get("heranca") else []
    # `apps` entra aqui junto com `icones` e `origens` porque `apps.<app>.herda`
    # é lido pelo `tema_de_app` exatamente como `icones.*.herda` é lido pelo
    # `acervo` — e uma herança que aponta para um pack inexistente precisa ser
    # recusada na publicação, não descoberta na hora de aplicar.
    for cat, bloco in (list(ic.items()) + list((p.get("origens") or {}).items())
                       + list((p.get("apps") or {}).items())):
        if isinstance(bloco, dict) and bloco.get("herda"):
            herancas.append(bloco["herda"])
    for h in set(herancas):
        # O `or eh_embutido(h)` SAIU EM 22/09/2026, e com ele a última exceção:
        # `catppuccin` agora é um diretório com pack.json como qualquer outro, e
        # o `achar` o encontra pelas mesmas três raízes. Ver `PACK_PADRAO`.
        _exigir(achar(h),
                f"herança {h!r}: esse pack não existe em nenhuma das raízes:\n      "
                + "\n      ".join(raizes()))

    def urls(no, trilha="pack.json"):
        if isinstance(no, dict):
            for k, v in no.items():
                yield from urls(v, f"{trilha}.{k}")
        elif isinstance(no, list):
            for i, v in enumerate(no):
                yield from urls(v, f"{trilha}[{i}]")
        elif isinstance(no, str) and "://" in no:
            yield trilha, no
    for trilha, u in urls(p):
        _exigir(u.startswith("https://"), f"{trilha}: {u!r} — só https é aceito")

    # --- o claro derivado ---------------------------------------------------
    # O `derivados` da paleta é a etiqueta que faz um claro derivado DIZER que é
    # derivado [23/09/2026, P16]. Só na porta de quem publica, como a vitrine
    # logo abaixo: uma etiqueta torta não pode tirar o tema do desktop, e quem
    # só mostra (`info`, `/api/packs`) a lê pelo `claros_derivados`, que ignora
    # o que não faz sentido. Quem publica ouve o que está torto.
    if not silencioso and "derivados" in dados:
        bons = claros_derivados(dados)
        deriv = dados["derivados"]
        tortos = sorted(set(deriv) - set(bons)) if isinstance(deriv, dict) else ["(não é um objeto)"]
        _exigir(not tortos,
                f"{arq}: 'derivados' é {{claro: escuro de onde ele saiu}} — o claro\n"
                f"    listado em 'claros', o escuro em 'flavors'. Não confere: "
                f"{', '.join(map(str, tortos))}")

    # --- vitrine ------------------------------------------------------------
    # Só na porta de quem PUBLICA — ver `vitrine`, acima, "ELA É COBRADA DE QUEM
    # PUBLICA". O `silencioso` é exatamente essa fronteira hoje: todo chamador
    # do motor (`caminho`, `paleta`, `som`, `info`, `construir`) passa True, e só
    # o verbo `validar` passa False. Todos os problemas de uma vez, como os slots
    # que faltam: consertar um por rodada é o que faz alguém desistir de publicar.
    # Cada um na própria linha de `erro`, porque as mensagens já trazem linha de
    # continuação indentada e, emendadas no mesmo recuo, não se sabe onde uma
    # acaba e a outra começa.
    #
    # ANTES DO LOGO, E DE PROPÓSITO [23/09/2026, junção com a P25]: o logo é o
    # arquivo que `vitrine.capa` nomeia, e é a vitrine que confere o CAMPO — um
    # `.svg`, dentro do pack, existindo. Na ordem inversa, uma capa `.png` seria
    # recusada pelo `_validar_logo` como "não é texto", e a mensagem certa é
    # "não é .svg"; uma capa ausente, como "o pack não tem logo", sem dizer que
    # o campo aponta para um arquivo que não existe.
    if not silencioso:
        _, problemas = vitrine(p, dir_pack)
        _exigir(not problemas, "\n  erro ".join(problemas))

    # --- o logo -------------------------------------------------------------
    # POR ÚLTIMO, E DE PROPÓSITO: um pack de formato errado ou paleta quebrada
    # deve ouvir primeiro sobre isso, que é o que impede qualquer tela de sair.
    #
    # SÓ NA PORTA DE QUEM PUBLICA — revisão de 23/09/2026. A primeira versão
    #   cobrava o logo aqui de todo chamador, e o `silencioso=True` é a porta do
    #   MOTOR: o `caminho` que o `meow_pack_dir` (lib/comum.sh) usa como sonda de
    #   existência, a `paleta`, o `som`, o `construir`. Medido na revisão: um
    #   pack íntegro em tudo menos o logo saía com "pack 'meu' não resolve —
    #   usando o padrão", sem dizer que era o logo, e o desktop inteiro voltava
    #   ao Catppuccin por causa de uma figura que só o cartão e o lançador
    #   mostram. E um pack `formato` 1 de antes de 23/09 pintaria errado depois
    #   de atualizar — o contrário do que o `formato` promete. É a fronteira que
    #   a P15 traçou para a capa, e a capa É este arquivo. Quem MOSTRA o logo não
    #   depende daqui: o `logo()` confere o arquivo por conta própria.
    if not silencioso:
        _validar_logo(dir_pack, p)

    if not silencioso:
        # O AVISO VEM ANTES DO `ok`, E NÃO MUDA O CÓDIGO DE SAÍDA
        #   Depois do `ok` ninguém lê: a linha verde é a que encerra a leitura.
        #   E ele não recusa porque um campo sem leitor hoje pode ser o campo que
        #   a sprint seguinte vai ler — o que não pode é o silêncio. Ver
        #   `CAMPOS_COM_LEITOR`, no topo.
        mortos = campos_sem_leitor(p)
        if mortos:
            print(f"  aviso {len(mortos)} campo(s) que este pack declara e NENHUM código lê:",
                  file=sys.stderr)
            for trilha in mortos:
                print(f"          {trilha}", file=sys.stderr)
            # A MENSAGEM MANDAVA "Ver docs/PACKS.md" E PROMETIA DEMAIS [22/09/2026]
            #   O docs/PACKS.md descreve cada CAMPO, e é para isso que ele serve
            #   aqui. O que ele não descreve — conferido no dia — é a ideia de
            #   campo sem leitor nem o verbo `acervo`, que nasceram nesta sprint.
            #   Mandar a pessoa procurar lá por uma explicação que não está
            #   escrita é a mesma promessa vazia que este aviso veio caçar.
            #   `docs/` está fora da tabela de arquivos da P20; então quem se
            #   ajusta é a frase, não o documento.
            print("        Eles não quebram nada — e também não fazem nada: "
                  "nenhuma linha deste projeto os consulta.\n"
                  "        O que cada campo deveria significar está em docs/PACKS.md.",
                  file=sys.stderr)
        n_fl = len(dados["flavors"])
        print(f"  ok   {p['nome']} ({p['id']}) — formato {p['formato']}, "
              f"{n_fl} flavor(s), 26 slots conferidos")
    return p, dados, dir_pack


# O TAMANHO DE UM PACK, EM VOZ ALTA — 22/09/2026
#
#   Até aqui não havia como saber o tamanho de um pack sem `find`. O `meow pack
#   info` dizia de ONDE vem cada categoria — próprio, herdado, do motor — e não
#   dizia QUANTO vem. As duas perguntas que a pessoa faz ao instalar um pack de
#   terceiro são exatamente essas, e ele respondia meia.
#
#   E a metade que faltava é a que denuncia o pack vazio: um `pack.json` que
#   declara `icones.apps.desenhos` apontando para um diretório com zero arquivo
#   passa no `validar` (o diretório existe) e imprime `PRÓPRIO` aqui. Com a
#   contagem ao lado, `PRÓPRIO` com `0 desenho(s)` conta a história inteira.
#
# A CONTAGEM SEGUE A HERANÇA, PORQUE É ASSIM QUE O ACERVO CHEGA À TELA
#   O Dracula não tem mimetype nenhum e mostra os 3.280 do Catppuccin — então
#   `mimetypes  HERDADO de catppuccin  3.280` é a verdade do que a pessoa vai
#   ver. Contar só o que é próprio imprimiria zero para uma categoria que
#   funciona, e a pessoa iria procurar defeito onde não há.
def _contar_acervo(ref, categoria, flavors):
    """Quantos SVG aquela categoria entrega, e em quantos flavors do pack.

    Devolve ('', '') quando a categoria não resolve acervo nenhum — que é
    diferente de resolver um diretório vazio, e a tela mostra os dois.
    """
    dir_acv = acervo(categoria + ".desenhos", ref=ref)
    if not dir_acv or not os.path.isdir(dir_acv):
        return "", ""
    svgs = []
    for base, _dirs, arquivos in os.walk(dir_acv):
        svgs += [a for a in arquivos if a.endswith(".svg")]
    # O FLAVOR SAI DO NOME DO ARQUIVO, E SÓ CONTA O QUE O PACK DECLARA
    #   Os autorais nascem como `<nome>-<flavor>.svg`. Casar o sufixo contra os
    #   flavors da paleta DESTE pack é o que impede um `cosmic-term-latte.svg`
    #   perdido no acervo do Dracula de ser contado como um terceiro flavor
    #   dele — e é justamente esse arquivo perdido que esta sprint foi tirar de
    #   `assets/icones/autorais/`.
    achados = {f for f in flavors for a in svgs if a.endswith(f"-{f}.svg")}
    quantos = f"{len(svgs):,} desenho(s)".replace(",", ".")
    return quantos, (f"{len(achados)} flavor(s)" if achados else "")


# A TABELA DO `info` E A LINHA DO CARTÃO SAEM DA MESMA CONTA — 23/09/2026, P15
#
#   A P15 pediu, no cartão do painel e no alto do `info`, a linha "próprio:
#   paleta, ícones · herdado do catppuccin: ponteiro, mimetypes" — que é esta
#   tabela virada frase. A classificação morava dentro do laço do `cmd_info`;
#   ela saiu para cá porque uma tabela e uma frase calculadas cada uma por si
#   discordariam no primeiro pack que declarasse uma categoria nova, e a tela
#   mostraria "herdado" onde o terminal diz "próprio".
#
#   O NOME DE GENTE mora ao lado, e só é usado pela frase: a tabela continua
#   com a trilha do pack.json, que é o que quem escreve um pack procura.
ROTULO_DA_CATEGORIA = {
    "paleta": "paleta",
    "cosmic.mapa": "mapa do COSMIC",
    "icones.apps": "ícones de aplicativo",
    "icones.pastas": "pastas",
    "icones.mimetypes": "ícones de arquivo",
    "icones.autorais": "ícones autorais",
    "cursores": "ponteiro",
    "wallpapers": "papéis de parede",
    "apps": "temas de aplicativo",
}


def origens(p):
    """[(categoria, tipo, de_quem)] na ordem da tabela do `info`.

    `tipo` é 'próprio', 'herdado' ou 'motor'; `de_quem` só vem no 'herdado'.
    """
    ic = p.get("icones") or {}
    org = p.get("origens") or {}
    saida = []
    for cat, bloco in [("paleta", p.get("paleta")), ("cosmic.mapa", (p.get("cosmic") or {}).get("mapa")),
                       ("icones.apps", ic.get("apps")), ("icones.pastas", ic.get("pastas")),
                       ("icones.mimetypes", ic.get("mimetypes")), ("icones.autorais", ic.get("autorais")),
                       ("cursores", org.get("cursores")), ("wallpapers", org.get("wallpapers")),
                       # A NONA CATEGORIA — 22/09/2026, sprint P18. Ela não
                       # estava na tabela de P12 porque não existia: até aqui
                       # `assets/temas-de-apps/` era anterior ao formato de pack
                       # e nenhum pack tinha onde declarar tema de aplicativo.
                       ("apps", p.get("apps"))]:
        if bloco is None:
            # SEM HERANÇA DECLARADA NÃO EXISTE "HERDADO DE" — 22/09/2026
            #   O pack PADRÃO não herda de ninguém, e esta coluna imprimia
            #   `HERDADO de (nenhuma)` em cinco das oito categorias dele — uma
            #   frase que diz o contrário do que acontece. Categoria que um
            #   pack sem herança não declara vem do MOTOR (o
            #   `assets/paleta/cosmic-map.json`, os acervos de `assets/`) ou
            #   não existe para aquele pack. O `acervo()` já resolve assim; era
            #   só a tela que discordava dele.
            tipo, quem = ("herdado", p["heranca"]) if p.get("heranca") else ("motor", "")
        elif isinstance(bloco, dict) and bloco.get("herda"):
            tipo, quem = "herdado", bloco["herda"]
        else:
            tipo, quem = "próprio", ""
        saida.append((cat, tipo, quem))
    return saida


def resumo_de_origem(p):
    """A tabela do `info` numa linha: 'próprio: … · herdado de X: …'."""
    grupos = {}
    for cat, tipo, quem in origens(p):
        chave = {"próprio": "próprio", "herdado": f"herdado de {quem}",
                 "motor": "do motor, ou ausente"}[tipo]
        grupos.setdefault(chave, []).append(ROTULO_DA_CATEGORIA[cat])
    return " · ".join(f"{k}: {', '.join(v)}" for k, v in grupos.items())


def cmd_info(ref):
    p, dados, dir_pack = validar(ref, silencioso=True)
    vit, problemas = vitrine(p, dir_pack)
    # O QUE VAI DENTRO DA CAPA TAMBÉM ENTRA NA CONTA [23/09/2026, junção com a
    #   P25]. Desde a a3ee4a6 o motor não confere o logo, e a vitrine só confere o
    #   campo; sem esta linha, um logo com `<script>` sairia aqui como "capa
    #   logo.svg", tudo certo, e o `validar` o recusaria logo depois.
    if vit["capa"]:
        try:
            _validar_logo(dir_pack, p)
        except Recusa as e:
            problemas.append(str(e))
    base = p.get("heranca") or "(nenhuma)"
    # AS SEIS PRIMEIRAS LINHAS SÃO A VITRINE — 23/09/2026, P15
    #   A conferência da sprint é `meow pack info dracula | head -6`, e ela é o
    #   retrato certo da pergunta: quem é, de quem é, o que diz de si, e o que é
    #   dele. O diretório e a herança descem uma linha porque respondem outra
    #   pergunta — a de quem está consertando, não a de quem está escolhendo.
    versao = f"versão {p['versao']} · " if p.get("versao") else ""
    print(f"{p['nome']}  [{p['id']}]  {versao}formato {p['formato']}")
    licenca = f" · licença {p['licenca']}" if p.get("licenca") else ""
    print(f"  autor     : {p.get('autor') or '(não declarado)'}{licenca}")
    print(f"  descrição : {vit['descricao_curta'] or '(nenhuma)'}")
    print(f"  tags      : {', '.join(vit['tags']) or '(nenhuma)'}")
    print(f"  origem    : {resumo_de_origem(p)}")
    print(f"  diretório : {dir_pack}")
    print(f"  herança   : {base}")
    print(f"  flavors   : {', '.join(sorted(dados['flavors']))}")
    # O CLARO DERIVADO DIZ NA CARA QUE É DERIVADO [23/09/2026, P16]. A sprint
    #   registra o risco com as palavras certas: derivar é opinativo, e o
    #   `alucard` de 19/09 só saiu depois de três correções do método (o
    #   `derivar_claro.py` conta as três). Um claro que nasceu do
    #   CSV sem ninguém desenhá-lo aparecendo aqui igual a um desenhado seria o
    #   "fingido" que ela proíbe.
    derivados = claros_derivados(dados)
    claros = [f"{c} — claro: derivado do escuro pelo método do Latte (não é próprio), "
              f"a partir de {derivados[c]!r}" if c in derivados else c
              for c in dados["claros"]]
    print(f"  claros    : {', '.join(claros) or '(nenhum)'}")
    # O `info` MOSTRA O PACK MESMO COM A VITRINE QUEBRADA, e diz o que falta: ele
    # é a pergunta de quem está consertando, e esconder o pack inteiro atrás de
    # uma capa ausente não ajudaria ninguém a achar a capa.
    #   MENOS A URL FORA DE https:// [23/09/2026, revisão da P15]: essa é regra
    #   do pack inteiro, e o `validar(silencioso=True)` da primeira linha já a
    #   recusou — um `vitrine.site` em `http://` faz o `info` sair 1, com a
    #   mesma mensagem do `validar`. Ver `vitrine`, "COM UMA EXCEÇÃO".
    if problemas:
        print(f"  vitrine   : NÃO VALIDA — `meow pack validar {p['id']}` recusa por isto:")
        for linha in problemas:
            print("      " + linha.replace("\n", "\n      "))
    else:
        partes = [f"capa {os.path.relpath(vit['capa'], dir_pack)}"]
        if vit["descricao"]:
            partes.append(f"história em {os.path.relpath(vit['descricao'], dir_pack)}")
        partes.append(f"{len(vit['capturas'])} captura(s)")
        if vit["site"]:
            partes.append(vit["site"])
        print(f"  vitrine   : {' · '.join(partes)}")
    print()
    print("  categoria         origem                       acervo")
    print("  ----------------  ---------------------------  -----------------------")
    for cat, tipo, quem in origens(p):
        estado = {"próprio": "PRÓPRIO", "herdado": f"HERDADO de {quem}",
                  "motor": "DO MOTOR, ou inexistente"}[tipo]
        # SÓ AS CATEGORIAS DE ÍCONE TÊM ACERVO PARA CONTAR. `paleta` é um
        # arquivo, `cosmic.mapa` é um arquivo, e cursores e wallpapers são
        # origens que este pack nem baixou ainda — contar SVG em qualquer uma
        # das quatro imprimiria uma coluna vazia que faz a pessoa procurar o que
        # deu errado.
        conta = ""
        if cat.startswith("icones."):
            quantos, fl = _contar_acervo(ref, cat, dados["flavors"])
            conta = f"{quantos}, {fl}" if quantos and fl else quantos
        print(f"  {cat:<16}  {estado:<27}  {conta}")
    return OK


def cmd_som(ref):
    """Imprime o timbre do pack como CHAVE=valor, para o shell avaliar.

    Só imprime o que o pack DECLARA: as chaves ausentes ficam de fora, e o
    scripts/som.sh aplica os defaults dele. Assim o default continua morando num
    lugar só — se este comando imprimisse os defaults também, haveria duas
    verdades sobre o timbre padrão, e elas divergiriam na primeira mudança.
    """
    p, _, _ = validar(ref, silencioso=True)
    som = p.get("som") or {}
    mapa = {
        "fundamental": "SOM_FUNDAMENTAL",
        "harmonico": "SOM_HARMONICO",
        "peso_fundamental": "SOM_PESO_FUNDAMENTAL",
        "peso_harmonico": "SOM_PESO_HARMONICO",
        "decaimento": "SOM_DECAIMENTO",
        "duracao": "SOM_DURACAO",
        "ganho": "SOM_GANHO",
    }
    for chave, var in mapa.items():
        if chave in som:
            print(f"{var}={som[chave]}")
    return OK


def cmd_construir(ref, seco=False):
    """Refaz, DENTRO do pack, tudo o que o pack declara como derivado.

    POR QUE ESTE VERBO NASCEU [22/09/2026, sprint P29]
        A sprint pediu: "`rebuild_dracula_theme()` vira `meow pack construir
        dracula`, que escreve em `packs/dracula/icones/`, não em
        `~/.local/share/icons/Dracula-Icones/`".

        A METADE DO PEDIDO QUE ESTE VERBO NÃO É, dita aqui para não virar
        promessa. O `rebuild_dracula_theme()` do `functions/sistema.zsh` NÃO
        constrói o conteúdo de um pack: ele entra num TERCEIRO repositório,
        `~/Desenvolvimento/Dracula_OS-Theme`, e roda o `baixar_upstreams.sh`, o
        `extrair_mapeamento.py`, o `build.sh` e o `install.sh --user` DELE.
        Medido em 22/09/2026: 1.379 linhas de pipeline e 32.370 arquivos em
        `src/`, dos quais dois acervos upstream inteiros (`dracula-icons-main`
        e `dracula-icons-circle`). Aquilo não cabe neste arquivo nem no
        `bin/meow`, que são os dois que a P29 autoriza tocar — e não precisa
        caber: os desenhos que o MeowSystem usa já foram para dentro do pack em
        17/09/2026 (`packs/dracula/icones/apps/`, 18 desenhos, e `apps.map`,
        com o casamento herdado da SPRINT 32 daquele repositório).

        O QUE ESTE VERBO É, E É O QUE A FRASE DA SPRINT COBRA: a porta que
        constrói um pack ESCREVENDO SÓ DENTRO DELE. A regra é a do `_dentro`,
        que este arquivo já aplica a todo caminho declarado, agora aplicada
        também ao que a construção PRODUZ. Nenhum `meow pack construir` pode
        tocar `~/.local/share/icons/` — nem o de hoje, nem o que alguém
        acrescentar depois.

    O QUE ELE CONSTRÓI HOJE
        Uma coisa só, porque é uma só a que os packs declaram: os ícones
        autorais, quando `icones.autorais.gerar` é verdadeiro. Um pack que não
        declara nada derivado não tem o que construir, e dizer isso é a
        resposta certa — não um erro.

        E ELES NASCEM DA PALETA DO PRÓPRIO PACK. O `gerar_icones_autorais.py`
        resolve a paleta por `paleta_do_pack_ativo()`, cujo passo 2 é a
        variável `MEOW_PACK_DIR`. Exportá-la aqui é o que faz `construir
        dracula` desenhar em Dracula, e não em Catppuccin com outro nome.
        Conferido em 22/09/2026: o `hefesto-dracula.svg` que sai daqui traz
        `#BD93F9`, o roxo do Dracula, e não o `#CBA6F7` do mauve Catppuccin.

    A DÍVIDA QUE ESTE VERBO NÃO PAGA, E QUE PRECISA ESTAR ESCRITA
        A saída deste verbo SE SOBREPÕE a `assets/icones/autorais/`, que é
        versionado (63 arquivos) e é de onde o `completar_icones.sh` lê de
        verdade. Medido em 22/09/2026, logo depois da primeira construção:
        `packs/dracula/icones/autorais/cosmic-edit-dracula.svg` e
        `assets/icones/autorais/cosmic-edit-dracula.svg` são BYTE A BYTE
        iguais; só o flavor `alucard`, que nasceu depois da última geração,
        existe de um lado só.

        Ou seja: hoje há dois lugares possíveis para o mesmo desenho gerado, e
        isso é exatamente a classe de defeito que a P29 veio extinguir — uma
        verdade em dois lugares, que é pior que uma verdade errada porque
        ninguém sabe qual editar. A P29 nomeia `packs/<id>/icones/` como o
        destino e não toca em `assets/icones/autorais/`, que não está entre os
        arquivos que ela autoriza; unificar os dois é sprint própria, com o
        `completar_icones.sh` e o `gerar_icones_autorais.py` na mesa.

        Enquanto ela não vem: a saída daqui NÃO é versionada de propósito. Ela
        se refaz com um comando, e versioná-la seria congelar a segunda cópia.
    """
    import subprocess

    p, _, dir_pack = validar(ref, silencioso=True)
    ident = p.get("id", os.path.basename(dir_pack))

    gerar = ((p.get("icones") or {}).get("autorais") or {}).get("gerar")
    if not gerar:
        print(f"  --   {ident}: não declara nada derivado — nada a construir")
        return OK

    # `_dentro` com o caminho que VAMOS ESCREVER: se um dia a saída vier do
    # pack.json em vez de ser fixa, esta linha já barra o `../..`.
    saida = _dentro(dir_pack, os.path.join("icones", "autorais"), "icones.autorais")

    gerador = os.path.join(RAIZ, "scripts", "gerar_icones_autorais.py")
    if not os.path.isfile(gerador):
        raise Recusa(f"o gerador não está aqui: {gerador}")

    if seco:
        print(f"  ~~   {ident}: geraria os ícones autorais em {saida}")
        return OK

    ambiente = dict(os.environ)
    ambiente["MEOW_PACK_DIR"] = dir_pack
    # `MEOW_PALETA` sai do ambiente de propósito: ela é o passo 1 da precedência
    # e venceria o pack que a pessoa acabou de nomear na linha de comando.
    ambiente.pop("MEOW_PALETA", None)

    print(f"  >>   {ident}: ícones autorais, da paleta do pack, em {saida}")
    r = subprocess.run([sys.executable, gerador, "--saida", saida], env=ambiente)
    if r.returncode != 0:
        raise Recusa(f"o gerador de ícones autorais saiu {r.returncode}")
    print(f"  ok   {ident}: construído")
    return OK


def cmd_caminho(ref, categoria):
    p, _, dir_pack = validar(ref, silencioso=True)
    trilha = categoria.split(".")
    no = p
    for parte in trilha:
        if not isinstance(no, dict) or parte not in no:
            return RECUSADO
        no = no[parte]
    if isinstance(no, str):
        print(os.path.join(dir_pack, no))
        return OK
    return RECUSADO


def main(argv):
    if len(argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return ERRO_USO
    verbo = argv[1]
    try:
        if verbo == "raizes":
            for r in raizes():
                print(r)
            return OK
        if verbo == "padrao":
            print(dir_padrao())
            return OK
        # OS TRÊS VERBOS DA CAPTURA NÃO RECEBEM `<id>`, e os outros recebem.
        #   Quem pergunta por uma captura é sempre o desktop VIVO — o
        #   `aplicar_tema.sh`, o `meow tema`, o pré-voo. O pack ativo dele já
        #   chegou aqui por `MEOW_PACK_DIR`, que é a ponte do `lib/comum.sh`.
        #   Pedir o id de novo na linha de comando seria uma segunda declaração
        #   do pack ativo, e duas declarações divergem no dia em que uma delas
        #   for esquecida.
        if verbo == "capturas" and len(argv) == 2:
            for nome in capturas():
                print(nome)
            return OK
        if verbo == "captura" and len(argv) == 3:
            achado = captura(argv[2])
            if not achado:
                return RECUSADO
            print(achado)
            return OK
        if verbo == "captura-destino" and len(argv) == 3:
            alvo = captura_destino(argv[2])
            if not alvo:
                return RECUSADO
            print(alvo)
            return OK
        if verbo == "validar" and len(argv) == 3:
            validar(argv[2])
            return OK
        if verbo == "paleta" and len(argv) == 3:
            p, _, dir_pack = validar(argv[2], silencioso=True)
            print(os.path.join(dir_pack, (p.get("paleta") or {}).get("arquivo", "paleta.json")))
            return OK
        if verbo == "onde" and len(argv) in (4, 5):
            achado = dir_acervo(argv[3], ref=argv[2],
                                padrao=argv[4] if len(argv) == 5 else None)
            if not achado:
                return RECUSADO
            print(achado)
            return OK
        if verbo == "alvo" and len(argv) == 3:
            return cmd_alvo(argv[2])
        # `fontes` e `fonte` aceitam o id por argumento e caem no pack ativo
        # (`MEOW_PACK_DIR`) sem ele — a mesma ponte do `acervo`, pelo mesmo
        # motivo: quem pergunta do shell já resolveu o pack ativo por ela.
        if verbo == "fontes" and len(argv) in (2, 3):
            return cmd_fontes(argv[2] if len(argv) == 3 else None)
        if verbo == "fonte" and len(argv) in (3, 4):
            return cmd_fonte(argv[2], argv[3] if len(argv) == 4 else None)
        if verbo == "sincronizar" and len(argv) == 3:
            return cmd_sincronizar(argv[2])
        # O LOGO SAI PELO STDOUT NOS DOIS VERBOS: quem instala no tema de ícones
        # ou serve no cartão redireciona para onde precisa, e o pack.py continua
        # sem escrever uma linha fora de `construir`. Ver o bloco "O LOGO DO PACK".
        if verbo == "logo" and 3 <= len(argv) <= 5:
            sys.stdout.write(logo(argv[2], *argv[3:]))
            return OK
        if verbo == "logo-gerado" and 3 <= len(argv) <= 5:
            return cmd_logo_gerado(argv[2], *argv[3:])
        # A PALETA DO CSV TAMBÉM SAI PELO STDOUT, pelo motivo do logo acima: o
        # `pack.py` não escreve dentro de pack. Ver "A PALETA ENTRA POR CSV".
        if verbo == "de-csv" and len(argv) == 3:
            return cmd_de_csv(argv[2])
        if verbo == "som" and len(argv) == 3:
            return cmd_som(argv[2])
        if verbo == "info" and len(argv) == 3:
            return cmd_info(argv[2])
        if verbo == "construir" and len(argv) in (3, 4):
            # O `--seco` é a mesma promessa do `MEOW_DRY_RUN` do lado shell: diz
            # o que faria e não escreve. Aceito pelos dois nomes porque quem
            # chama daqui é o `bin/meow`, que já traduz o ambiente em flag.
            return cmd_construir(argv[2], seco=(len(argv) == 4 and argv[3] in ("--seco", "--dry-run")))
        if verbo == "caminho" and len(argv) == 4:
            return cmd_caminho(argv[2], argv[3])
        if verbo == "app" and len(argv) == 4:
            # O `ref` vem por argumento e não do ambiente: quem chama do shell é
            # o `meow_app_tema_do_pack`, que já resolveu o pack ativo pela mesma
            # porta que todo o resto (`meow_pack_dir`). Duas resoluções do pack
            # ativo em ordens diferentes é a divergência silenciosa de volta.
            quem, valor = tema_de_app(argv[3], ref=argv[2] or None)
            if quem is None or valor is None:
                return RECUSADO
            # BOOLEANO SAI COMO `sim`/`nao`, e não como o `True` do Python: quem
            # lê é um `case` de shell, e `[ "$x" = "True" ]` seria o idioma de
            # outra linguagem vazando para dentro deste. É o mesmo `sim`/`nao`
            # que o `acento.py` já imprime em `ok=`.
            if isinstance(valor, bool):
                valor = "sim" if valor else "nao"
            print(f"pack={quem}")
            print(f"valor={valor}")
            return OK
        if verbo == "acervo" and len(argv) in (4, 5):
            # Sem `motor` de propósito: quem chama do shell tem o
            # `meow_pack_arquivo` para a queda no núcleo, e passar o caminho do
            # motor por linha de comando seria a segunda declaração dele.
            achado = acervo(argv[3], argv[4] if len(argv) == 5 else "", ref=argv[2])
            if not achado:
                return RECUSADO
            print(achado)
            return OK
    except Recusa as e:
        print(f"  erro pack recusado: {e}", file=sys.stderr)
        return RECUSADO
    print(__doc__.strip(), file=sys.stderr)
    return ERRO_USO


if __name__ == "__main__":
    sys.exit(main(sys.argv))

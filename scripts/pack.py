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
                                 sem prefixo cai na <base>. Uma linha de saída
                                 por linha de entrada; vazia = recusada.
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


def resolver_alvo(valor, base):
    """O arquivo que uma linha de mapa nomeia. Recusa o que sai da raiz.

    `motor:x` resolve em `assets/icones/x`; sem prefixo, contra a `base` que o
    chamador passa. Devolve o caminho EXISTA ELE OU NÃO: quem chama é que sabe
    se um alvo ausente é erro (nome no mapa sem desenho no disco) ou não.
    """
    valor = (valor or "").strip()
    if not valor:
        return ""
    if valor.startswith(MOTOR):
        raiz, resto = os.path.join(RAIZ, ACERVO_DO_MOTOR), valor[len(MOTOR):].strip()
    else:
        raiz, resto = base, valor
    if not resto:
        raise Recusa(f"{valor!r} não nomeia arquivo nenhum")
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


def _luminancia(hexcor):
    """Luminância relativa de WCAG 2.x. Usada só para o teste de contraste."""
    r, g, b = (int(hexcor[i:i + 2], 16) / 255 for i in (1, 3, 5))
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


# --- O LOGO DO PACK — 23/09/2026, sprint P25 --------------------------------
#
# O PEDIDO, NAS PALAVRAS DELE
#   *"precisa usar um svg pra cada logo do theme pack, o icon do menu de
#   lançamento."* Até aqui um pack era um `id` e 26 hexadecimais: nenhum dos
#   dois tinha um único SVG que o representasse. O mockup de 21/09 desenhou a
#   capa do cartão como uma TIRA DE CORES — e tira de cor é paleta, não
#   identidade: dois packs de paleta parecida ficam indistinguíveis no cartão.
#
# O NOME É FIXO, E NÃO UM CAMPO DO pack.json
#   `packs/<id>/logo.svg`, por convenção, como `pack.json` e `CREDITOS.md`. A
#   P15 nomeia a capa da vitrine em `vitrine.capa`, e a capa É este arquivo —
#   dois campos para a mesma coisa seriam duas verdades que divergem no dia em
#   que alguém atualizar só uma. Quem precisa do logo pergunta a `logo()`.
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
RE_ESTILO_PAPEIS = re.compile(r'\s*<style\b[^>]*\bid="meow-papeis"[^>]*>.*?</style>', re.S)
RE_RAIZ_SVG = re.compile(r"<svg\b[^>]*>")
RE_URL_CSS = re.compile(r"""url\(\s*['"]?\s*([^)'"\s]*)""", re.I)

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


def _ler_logo(caminho):
    """(texto, raiz) de um SVG, ou Recusa dizendo por que ele não é um SVG."""
    with open(caminho, "rb") as fh:
        bruto = fh.read()
    # PNG RENOMEADO É O CASO QUE A SPRINT NOMEIA, e ele não passa daqui: bytes
    # de imagem não decodificam como UTF-8 e, se decodificassem, não seriam XML.
    try:
        texto = bruto.decode("utf-8")
    except UnicodeDecodeError:
        raise Recusa(f"{LOGO}: não é texto — é um SVG de verdade, ou uma imagem "
                     f"renomeada?\n    Um PNG com nome de .svg não vira vetor.") from None
    # ENTIDADE DECLARADA É RECUSADA ANTES DE O PARSER VÊ-LA. Um `<!ENTITY>` que
    # se expande em si mesmo mil vezes (o "bilhão de risadas") trava quem valida,
    # e este validador roda na sonda `caminho` de todo script do projeto. Nenhum
    # desenho precisa de entidade.
    _exigir("<!ENTITY" not in texto,
            f"{LOGO}: declara <!ENTITY> — um logo não precisa de entidade, e ela "
            f"pode travar quem o lê")
    try:
        raiz = ET.fromstring(bruto)
    except ET.ParseError as e:
        raise Recusa(f"{LOGO}: não é XML válido — {e}") from None
    return texto, raiz


def _validar_logo(dir_pack):
    """Confere o `logo.svg`. Levanta Recusa na primeira falha, com o conserto."""
    # `_dentro` com o nome fixo não é enfeite: ele segue link simbólico. Um
    # `logo.svg -> /etc/algo` sairia do pack por baixo do nome certo.
    caminho = _dentro(dir_pack, LOGO, "logo")
    _exigir(os.path.isfile(caminho),
            f"{LOGO}: o pack não tem logo — e desde 23/09/2026 todo pack tem cara.\n"
            f"    Desenhe um SVG quadrado (viewBox 0 0 128 128), ou comece do gerado:\n"
            f"      python3 scripts/pack.py logo-gerado <id> > <pack>/{LOGO}\n"
            f"    Ver docs/PACKS.md, 'O logo do pack'.")
    _texto, raiz = _ler_logo(caminho)
    _exigir(raiz.tag == SVG_NS + "svg",
            f"{LOGO}: a raiz é <{raiz.tag}>, e não <svg> no namespace do SVG.\n"
            f"    Sem xmlns=\"http://www.w3.org/2000/svg\" o navegador não o desenha.")

    # QUADRADO, E COM viewBox: o mesmo arquivo serve ao cartão em quatro
    # tamanhos e ao lançador, que pede 48, 64, 128 e 256. Sem `viewBox` ele não
    # escala; retangular, ele é esticado ou ganha tarja.
    vb = (raiz.get("viewBox") or "").strip()
    partes = [x for x in re.split(r"[\s,]+", vb) if x]
    try:
        _x, _y, larg, alt = (float(x) for x in partes)
    except ValueError:
        raise Recusa(f"{LOGO}: precisa de viewBox com quatro números, veio {vb!r}") from None
    _exigir(larg > 0 and larg == alt,
            f"{LOGO}: o viewBox {vb!r} não é quadrado.\n"
            f"    O lançador pede o ícone em 48, 64, 128 e 256 — todos quadrados.")

    # SEM DISTINGUIR MAIÚSCULA, e o motivo é o cartão: o XML distingue, e um
    # `<Script>` não executa num SVG aberto como arquivo — mas se alguém um dia
    # colar este texto dentro de HTML, o parser do HTML baixa tudo para
    # minúscula e o `<SCRIPT>` roda. Recusar pelos dois leitores custa um `lower`.
    recusados = {k.lower(): v for k, v in ELEMENTOS_RECUSADOS_NO_LOGO.items()}
    for el in raiz.iter():
        nome = str(el.tag).rsplit("}", 1)[-1]
        _exigir(nome.lower() not in recusados,
                f"{LOGO}: tem <{nome}>, que {recusados.get(nome.lower())}. "
                f"Um pack é dado, nunca código.")
        textos = [el.text or ""] if nome.lower() == "style" else []
        for chave, valor in el.attrib.items():
            local = chave.rsplit("}", 1)[-1].lower()
            # `onload`, `onclick`... é `<script>` com outra roupa. A regra é
            # "sem script", e ela vale para a porta dos atributos também.
            _exigir(not local.startswith("on"),
                    f"{LOGO}: o atributo {local!r} executa código. Um pack é dado, nunca código.")
            # O LOGO É COPIADO PARA FORA DO PACK — para o tema de ícones, para o
            # cartão —, e é por isso que ele não pode apontar nem para o vizinho
            # de pasta: depois da cópia, `apps/x.svg` é um caminho quebrado. Só
            # referência interna (`#id`) sobrevive à viagem.
            if local == "href":
                _exigir(valor.strip().startswith("#"),
                        f"{LOGO}: href={valor!r} aponta para fora do arquivo.\n"
                        f"    Só referência interna (#id): o logo é copiado para o tema de\n"
                        f"    ícones, e lá fora nenhum outro caminho existe.")
            textos.append(valor)
        for t in textos:
            _exigir("@import" not in t,
                    f"{LOGO}: <style> com @import busca folha de fora. Um logo se basta.")
            for alvo in RE_URL_CSS.findall(t):
                _exigir(alvo.startswith("#"),
                        f"{LOGO}: url({alvo}) aponta para fora do arquivo — URL remota\n"
                        f"    ou caminho, não importa: só url(#id) sobrevive à cópia.")


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
    sem_bloco = RE_ESTILO_PAPEIS.sub("", texto, count=1)
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
    """
    p, dados, dir_pack = validar(ref, silencioso=True)
    texto, raiz = _ler_logo(os.path.join(dir_pack, LOGO))
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

    # A INICIAL SAI DO NOME E, NA FALTA, DO ID. `Árvore` vira `a` pela
    # decomposição do acento; um nome que comece por símbolo cai no id, que o
    # `validar` já garante começar por [a-z0-9].
    inicial = next((c for c in unicodedata.normalize("NFKD", f"{nome}{ident}").lower()
                    if c in _GLIFOS_DO_LOGO), "o")
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

    `validar` sem cobrar o logo, e só isso: o resto do pack precisa estar são,
    porque o gerado nasce da paleta dele.
    """
    p, dados, dir_pack = validar(ref, silencioso=True, cobrar_logo=False)
    svg = logo_gerado(str(p.get("nome") or p["id"]), str(p["id"]))
    flavor, accent = _flavor_e_accent(p, dados, flavor, accent)
    sys.stdout.write(_aplicar_papeis(svg, ET.fromstring(svg), _cores_do_logo(dados, flavor, accent)))
    return OK


def validar(ref, silencioso=False, cobrar_logo=True):
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
        _exigir(r >= 4.5,
                f"{arq}: no flavor {flavor!r}, 'text' sobre 'base' tem contraste "
                f"{r:.2f}:1 — WCAG AA pede 4.5:1.\n"
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

    # --- o logo -------------------------------------------------------------
    # POR ÚLTIMO, E DE PROPÓSITO: um pack de formato errado ou paleta quebrada
    # deve ouvir primeiro sobre isso, que é o que impede qualquer tela de sair.
    # `cobrar_logo=False` existe para UM chamador, o `logo-gerado`, que é
    # justamente quem dá a cara ao pack que ainda não tem. Ver `_validar_logo`.
    if cobrar_logo:
        _validar_logo(dir_pack)

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


def cmd_info(ref):
    p, dados, dir_pack = validar(ref, silencioso=True)
    base = p.get("heranca") or "(nenhuma)"
    print(f"{p['nome']}  [{p['id']}]  formato {p['formato']}")
    print(f"  diretório : {dir_pack}")
    print(f"  herança   : {base}")
    print(f"  flavors   : {', '.join(sorted(dados['flavors']))}")
    print(f"  claros    : {', '.join(dados['claros']) or '(nenhum)'}")
    print()
    print("  categoria         origem                       acervo")
    print("  ----------------  ---------------------------  -----------------------")
    ic = p.get("icones") or {}
    org = p.get("origens") or {}
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
            estado = f"HERDADO de {base}" if p.get("heranca") else "DO MOTOR, ou inexistente"
        elif isinstance(bloco, dict) and bloco.get("herda"):
            estado = f"HERDADO de {bloco['herda']}"
        else:
            estado = "PRÓPRIO"
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
        # O LOGO SAI PELO STDOUT NOS DOIS VERBOS: quem instala no tema de ícones
        # ou serve no cartão redireciona para onde precisa, e o pack.py continua
        # sem escrever uma linha fora de `construir`. Ver o bloco "O LOGO DO PACK".
        if verbo == "logo" and 3 <= len(argv) <= 5:
            sys.stdout.write(logo(argv[2], *argv[3:]))
            return OK
        if verbo == "logo-gerado" and 3 <= len(argv) <= 5:
            return cmd_logo_gerado(argv[2], *argv[3:])
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

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
    caminho <id> <categoria>     imprime o caminho que aquela categoria resolve
    acervo  <id> <categoria> [arquivo]
                                 resolve um acervo PACK -> HERANÇA -> nada.
                                 NÃO é o `caminho`: aquele olha só o pack, este
                                 sobe a cadeia de herança. Ver a função `acervo`.
    captura <par>                onde ESTÁ a captura <flavor>-<accent>, subindo
                                 pack -> herança -> motor. 1 = não existe.
    captura-destino <par>        onde uma captura NOVA deve ser escrita. Nunca
                                 sobe pela herança: escrita é no pack ATIVO.
    capturas                     os nomes das capturas alcançáveis, uma por linha
    paleta  <id>                 imprime o caminho da paleta do pack
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

import json
import os
import re
import sys

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
        _exigir(r >= 4.5,
                f"{arq}: no flavor {flavor!r}, 'text' sobre 'base' tem contraste "
                f"{r:.2f}:1 — WCAG AA pede 4.5:1.\n"
                f"      text={cores['text']}  base={cores['base']}\n"
                f"    Com esse contraste a interface fica ilegível. Escureça o fundo\n"
                f"    ou clareie o texto.")

    # --- caminhos declarados ------------------------------------------------
    ic = p.get("icones") or {}
    for cat, chaves in (("apps", ("mapa", "desenhos")), ("pastas", ("desenhos",))):
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
    for cat, bloco in list(ic.items()) + list((p.get("origens") or {}).items()):
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


def cmd_info(ref):
    p, dados, dir_pack = validar(ref, silencioso=True)
    base = p.get("heranca") or "(nenhuma)"
    print(f"{p['nome']}  [{p['id']}]  formato {p['formato']}")
    print(f"  diretório : {dir_pack}")
    print(f"  herança   : {base}")
    print(f"  flavors   : {', '.join(sorted(dados['flavors']))}")
    print(f"  claros    : {', '.join(dados['claros']) or '(nenhum)'}")
    print()
    print("  categoria         origem")
    print("  ----------------  ------------------------------------------")
    ic = p.get("icones") or {}
    org = p.get("origens") or {}
    for cat, bloco in [("paleta", p.get("paleta")), ("cosmic.mapa", (p.get("cosmic") or {}).get("mapa")),
                       ("icones.apps", ic.get("apps")), ("icones.pastas", ic.get("pastas")),
                       ("icones.mimetypes", ic.get("mimetypes")), ("icones.autorais", ic.get("autorais")),
                       ("cursores", org.get("cursores")), ("wallpapers", org.get("wallpapers"))]:
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
        print(f"  {cat:<16}  {estado}")
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
        if verbo == "som" and len(argv) == 3:
            return cmd_som(argv[2])
        if verbo == "info" and len(argv) == 3:
            return cmd_info(argv[2])
        if verbo == "caminho" and len(argv) == 4:
            return cmd_caminho(argv[2], argv[3])
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

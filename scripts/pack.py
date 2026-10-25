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
                                 um por linha: `motor:x` cai em packs/meowsystem/icones/,
                                 `pack:<id>:x` em <aquele pack>/icones/, sem
                                 prefixo cai na <base>. `~/` e caminho absoluto
                                 são recusados. Uma linha de saída por linha de
                                 entrada; vazia = recusada.
    fontes  [id]                 cada nome de ícone de `scalable/apps` e o
                                 arquivo de onde ele sai, um por linha:
                                 `nome<TAB>fonte<TAB>camada`. Para o mesmo
                                 nome, o pack no ar vence o resgate do motor,
                                 e perde com `ICONES_DRACULA="nao"` no
                                 ambiente; duas linhas de um nome é empate. Ver
                                 `fontes`.
    escolhas                     as escolhas de ícone do painel (o estado de
                                 quem usa, fora do repositório): `nome<TAB>
                                 arquivo`, uma por linha, só as que valem. Ver
                                 `escolhas_do_painel`.
    fonte   <nome> [id]          as linhas de `fontes` daquele nome. 0 = uma
                                 fonte só; 1 = nenhuma, ou mais de uma. O lado
                                 que ficou atrás vai para o stderr.
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
    ponteiro [id]                o ponteiro PRÓPRIO que o pack alcança — o dele,
                                 ou o de quem ele herda. Imprime, para o shell:
                                     pack=<quem traz>
                                     dir=<o tema, dentro do pack>
                                     valor=<o que a chave CURSOR escreve>
                                 Quando o ponteiro é BAIXADO (`origem`), o
                                 `dir` sai vazio e vêm mais três linhas:
                                 `url=`, `sha256=` e `pasta=`.
                                 1 = ninguém na cadeia traz. Ver `ponteiro`.
    tipografia [id]              as FONTES de texto que o pack alcança, uma por
                                 linha: `pack<TAB>nome<TAB>origem<TAB>sha256`.
                                 Não é o verbo `fontes`, que é de ícone (P28).
                                 Ver `tipografia`.
    base-icones [id]             a BASE de ícones que o `MeowSystem-Icons`
                                 herda, lendo `$ICONES_BASE` do ambiente (e o
                                 `$NOME_TEMA_ICONES`, que dá o nome da nossa
                                 base: escolhê-la é pedir a do pack).
                                 Imprime, para o shell ler com `sed`:
                                     quem=<conf, pack ou motor>
                                     tema=<o que herdar, quando não é o pack>
                                     pack=, url=, sha256=, pasta=
                                 (a origem que a cadeia declara, vazias sem
                                 ela), e uma `atras=<url> <sha256> <pasta>`
                                 por camada de trás. Ver `base_que_vale`.
    tema-icones [id] [flavor]    o nome e o comentário do tema de ícones montado
                                 para o pack nesse flavor: `nome=` e
                                 `comentario=`. Ver `tema_de_icones`.
    ocultar [id]                 os ids de `.desktop` que o pack esconde do
                                 lançador (`lancador.ocultar`), um por linha.
                                 Ver `ocultar_do_pack`.
    base-apelidos                o tema de onde as pastas e os apelidos de
                                 utilitário copiam desenho (o `ICONES_BASE`
                                 escolhido à mão, ou o Papirus-Dark), e onde
                                 ele está: `tema=` e `dir=` (vazio fora do
                                 disco). Ver `base_dos_apelidos`.
    novo   <id> [--de-csv <arquivo.csv>] [--seco]
                                 cria o pack <id> a partir do que está no ar: a
                                 paleta, o timbre, um logo gerado e os créditos,
                                 herdando o resto do pack ativo. Em $MEOW_PACKS
                                 quando ela existe; senão, em packs/ do projeto.
                                 Com `--de-csv`, a paleta é a do CSV e o resto
                                 vem do pack PADRÃO. Ver `montar_novo`.
    exportar <id> [arquivo] [--sem-imagens] [--seco]
                                 o pack num `.meowpack` (um .tar.zst com um
                                 MANIFESTO de sha256). Recusa o que não valida,
                                 o que não tem CREDITOS.md e a arte de terceiro
                                 sem licença no PROCEDENCIA.md.
    importar <arquivo> [--seco]  confere o `.meowpack` inteiro, valida, e só então
                                 instala em ~/.local/share/meowsystem/packs/.
                                 Recusa qualquer script. NÃO APLICA nada. Um
                                 `.csv` solto vira pack pelo mesmo `montar_novo`
                                 do `novo --de-csv`, com o id tirado do nome do
                                 arquivo.
    remover <id> [--seco]        tira um pack da casa da pessoa, onde o
                                 `importar` grava. Recusa (1) o que vem com o
                                 MeowSystem, o pack no ar (pelo `$PACK` e o
                                 `$FLAVOR` do ambiente) e o que outro pack
                                 herda. Ver `remocao`.
    info    <id>                 o que é próprio, o que é herdado, o que falta
    usar    <id> [flavor]        o PACK e o FLAVOR que o `meow pack usar` grava,
                                 como três linhas `PACK=`/`FLAVOR=`/`PORQUE=`.
                                 Não escreve: recusa (1) antes de o shell
                                 escrever. O flavor que já está no ar vem por
                                 `$FLAVOR`. Ver `plano_de_uso`.
    flavor-icones [id]           o flavor dos ícones de arquivo que vale agora,
                                 lendo `$ICONES_FLAVOR` e `$FLAVOR` do
                                 ambiente. É a regra única que os três
                                 `icones_*.sh` e o painel perguntam. 1 = sem
                                 resposta. Ver `flavor_de_icones`.
    raizes                       imprime as raízes de busca, na ordem
    padrao                       o diretório do pack PADRÃO, resolvido pelas
                                 raízes como qualquer outro. É o que o shell
                                 pergunta em vez de cravar o nome dele.
    adocao  <PACK> <FLAVOR>      o pack que um meow.conf com esses dois valores
                                 veste — a regra única do `meow_pack_dir` e do
                                 painel. Imprime, para o shell ler com `sed`:
                                     pack=<o id que veste, o padrão incluído>
                                     dir=<o diretório; vazio = ninguém escolheu>
                                     recusado=<o id que não validou, ou vazio>
                                     nome=<o nome de tela do pack que veste>
                                     flavor_padrao=<o flavor dele quando o
                                       FLAVOR do conf está vazio>
                                 Ver `adocao`.

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
FORMATO_MAX = 2

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
# As chaves do meow.conf que `origens.wallpapers` pode nomear: o `wallpaper.sh`
# as lê por expansão indireta, e um nome livre ali (`a[$(cmd)]`) roda comando.
RE_CONF_PAPEL = {"repo_do_conf": re.compile(r"^WALLPAPER_[A-Z0-9_]*_REPO$"),
                 "commit_do_conf": re.compile(r"^WALLPAPER_[A-Z0-9_]*_COMMIT$")}

OK, RECUSADO, ERRO_USO = 0, 1, 2

# O pack previu um defeito, declarou o conserto, e o conserto era decorativo — o
# tema Dracula aparecia na GUI do COSMIC chamado `catppuccin-dracula`.
#
# Um formato que aceita declaração morta ENSINA a escrever declaração morta.
#
# O que não pode é o silêncio.
CAMPOS_COM_LEITOR = {
    "formato", "id", "nome",            # identidade — validar
    "papel",                            # validar, `eh_base`
    "icones.apps.recolorir",            # `acervos_de_icone`: traço na ficha
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
    # categoria.
    "*.*.herda",                        # validar, `acervo`
    "som.*",                            # validar, cmd_som
    # Só as chaves que JÁ têm leitor: `apps.*.tema` (obsidian) e as dos outros
    # cinco módulos entram no dia em que aqueles módulos passarem a perguntar
    # ao pack.
    "apps.*.arquivo",                   # validar, `tema_de_app`, qbittorrent
    "apps.*.sha256",                    # validar, qbittorrent
    "apps.*.spicetify_tema",            # spotify
    "apps.*.esquema",                   # spotify
    "apps.*.acento_no_color_ini",       # spotify
    "apps.*.origem.*",                  # spotify (de onde o tema desce)
    # Deu: o `cmd_info` imprime os três, e o `autor` vai para o cartão do
    # painel.
    #
    # A vitrine vai campo a campo, e NÃO como `vitrine.*`: a máscara larga
    # calaria o erro de digitação — um `vitrine.descricao_curto` passaria por
    # lido, e é exatamente o campo morto que este aviso existe para nomear.
    "autor", "versao", "licenca",       # cmd_info; `autor` também no /api/packs
    "vitrine.capa",                     # `vitrine` e `logo()`: a capa É o logo
    "vitrine.descricao_curta",
    "vitrine.descricao",
    "vitrine.tags",
    "vitrine.capturas",
    "vitrine.site",
    # Os dois nasceram com leitor no mesmo commit: o `proprio` do ponteiro é
    # lido pelo `cursor.sh` (antes de baixar) e pelo painel
    # (`_cursor_pastas_do_valor`); a lista de fontes, pelo
    # `instalar_fontes.sh`, pelo verbo `tipografia`.
    "origens.cursores.proprio",
    "fontes.proprio",
    "fontes.herda",
    # Quem lê agora é o `vocabulario`, e por ele o painel: a «Variante dos
    # ícones de arquivo» de um pack que herda mimetypes oferece o flavor que
    # ESTE pack escolheu, com o nome do dono ao lado — e não os quatro sabores
    # do Catppuccin soltos numa máquina vestida de Dracula.
    "icones.mimetypes.flavor",
    "icones.autorais.gerar",            # cmd_construir
    "origens.cursores.tema",            # app/servidor.py, `_declarado_pelo_pack`
    # O `icones.base.herda` já cabe na máscara `*.*.herda`.
    "icones.base.origem.*",
    "origens.cursores.origem.*",
    # As camadas de trás da base: o `base_de_icones` as lê, e o
    # `construir_icones.sh` as baixa pelo verbo `base-icones` (linhas `atras=`).
    "icones.base.por_tras",
    # Os ícones de arquivo derivados da paleta: o `construir` lê.
    "icones.mimetypes.derivar.*",
    # Os papéis de parede do pack: o `wallpaper.sh` os semeia pelo `acervo`,
    # rasterizando o SVG.
    "origens.wallpapers.desenhos", "origens.wallpapers.repo",     # `origem_dos_wallpapers`
    "origens.wallpapers.commit", "origens.wallpapers.prefixo",
    "origens.wallpapers.curadoria", "origens.wallpapers.ignorar",
    "origens.wallpapers.repo_do_conf", "origens.wallpapers.commit_do_conf",
    "mascote.desenhos", "mascote.dia", "mascote.noite",   # `pasta_do_mascote`, `mascote_padrao`
    # O que o pack esconde do lançador: o `ocultar_apps.sh` pergunta pelo verbo
    # `ocultar`.
    "lancador.ocultar",
    # O tema de som do pack: o `som.sh` o instala pelo `acervo`.
    "som.tema",
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


def raiz_da_pessoa():
    """A raiz 2 — `~/.local/share/meowsystem/packs/`, "o seu" do docs/PACKS.md.

    SAIU DE DENTRO DO `raizes()` EM 23/09/2026 (P11), e sem mudar uma letra do
    que ele devolve: o `importar` precisa saber ONDE ESCREVER, e a resposta é
    esta raiz e nenhuma outra. Recalcular o XDG lá seria a segunda cópia da
    lista que o `raizes()` existe para ser a única — o comentário do
    `meow_pack_raizes` (lib/comum.sh) conta o que custaram as quatro cópias.
    """
    xdg = os.environ.get("XDG_DATA_HOME") or os.path.join(
        os.path.expanduser("~"), ".local", "share")
    return os.path.join(xdg, "meowsystem", "packs")


def raizes():
    """As três raízes de busca, na ordem de precedência de docs/PACKS.md."""
    saida = []
    if os.environ.get("MEOW_PACKS"):
        saida.append(os.environ["MEOW_PACKS"])
    saida.append(raiz_da_pessoa())
    saida.append(os.path.join(RAIZ, "packs"))
    return saida


# O PACK PADRÃO, E ELE É UM PACK COMO OS OUTROS
PACK_PADRAO = "meowsystem"

# O Catppuccin entrou no pack `meowsystem` em 23/10/2026 (P96). Um conf, um
# pack de terceiro (`heranca`) ou uma linha de mapa (`pack:catppuccin:`) escritos
# antes disso continuam achando o pack, pelo nome de antes.
APELIDOS = {"catppuccin": "meowsystem"}


def achar(ref):
    """Aceita um id ou um caminho. Devolve o diretório do pack, ou None."""
    if os.path.isdir(ref) and os.path.isfile(os.path.join(ref, "pack.json")):
        return os.path.abspath(ref)
    if ref in APELIDOS and not any(os.path.isfile(os.path.join(b, ref, "pack.json")) for b in raizes()):
        ref = APELIDOS[ref]
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


# A ADOÇÃO: QUE PACK UM meow.conf VESTE
#
# O `meow_pack_dir` (lib/comum.sh) adotava pelo NOME do FLAVOR; o
# `_pack_adotado` do painel, pelo SABOR que a paleta declara; e o
# `_ponteiro_do_pack`, também do painel, repetia a conta do shell de propósito,
# para a lista de ponteiros não oferecer o que o script não acha.
#
# `mocha` e `latte` só concordavam porque o padrão É o Catppuccin.
def _flavors_do_pack(dir_pack):
    """Os flavors que a paleta de um pack declara, ou um conjunto vazio.

    NÃO VALIDA, e é de propósito: quem pergunta ainda está escolhendo QUAL pack
    validar, e um pack de terceiro quebrado que nem declara o flavor não tem por
    que derrubar a busca pelos outros. O arquivo declarado continua preso ao
    pack pelo `_dentro` — ler fora dele só para olhar nomes seria abrir a porta
    que o formato inteiro fecha.
    """
    try:
        arq = campo(dir_pack, "paleta.arquivo", "paleta.json")
        with open(_dentro(dir_pack, arq, "paleta.arquivo"), encoding="utf-8") as fh:
            flavors = json.load(fh).get("flavors")
    except (OSError, ValueError, AttributeError, TypeError, Recusa):
        return set()
    return set(flavors) if isinstance(flavors, dict) else set()


def adocao(pack="", flavor=""):
    """(id, dir, recusado): o pack que um meow.conf com estes PACK e FLAVOR veste.

    `id` é sempre um pack — o padrão quando nada escolheu outro. `dir` é o
    diretório do escolhido, e vazio quando quem veste é o padrão por falta de
    escolha ou por recusa. `recusado` é o id que não passou na validação, ou ''.
    """
    escolhido = pack or ""
    if not escolhido and flavor:
        # O NOME PASSA PELO RE_ID ANTES DE VIRAR CAMINHO: um FLAVOR com `/` ou
        # `..` não é id de pack nenhum, e o `validar` recusaria de qualquer
        # jeito um diretório cujo nome não case com o id de dentro.
        if RE_ID.match(flavor) and any(os.path.isfile(os.path.join(b, flavor, "pack.json"))
                                       for b in raizes()):
            escolhido = flavor
        elif flavor not in _flavors_do_pack(dir_padrao()):
            vistos = set()
            for base in raizes():
                try:
                    nomes = sorted(os.listdir(base))
                except OSError:
                    continue
                for nome in nomes:
                    if nome in vistos or not os.path.isfile(os.path.join(base, nome, "pack.json")):
                        continue
                    vistos.add(nome)
                    if flavor in _flavors_do_pack(os.path.join(base, nome)):
                        escolhido = nome
                        break
                if escolhido:
                    break
    if not escolhido:
        return PACK_PADRAO, "", ""
    try:
        _p, _d, dir_pack = validar(escolhido, silencioso=True)
    except Exception:
        # É o mesmo `except Exception` que o `_ponteiro_do_pack` do painel já
        # usava.
        return PACK_PADRAO, "", escolhido
    return os.path.basename(dir_pack), dir_pack, ""


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
    # `ValueError`, e não só o JSONDecodeError: um pack.json que não é UTF-8
    # levanta UnicodeDecodeError, e com ele instalado ao lado a ficha de ícone
    # (`acervos_de_icone`) caía inteira — o par do NUL do `_dentro`.
    except (OSError, ValueError):
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
    # Dois packs que herdam um do outro pendurariam o painel num laço infinito.
    # O conjunto de vistos custa uma linha e transforma o travamento em "não
    # achei", que é uma resposta que a pessoa consegue ler.
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        dir_pack = achar(ref)
        if not dir_pack:
            break
        declarado = campo(ref, categoria)
        if isinstance(declarado, str):
            # `validar` já aplica o `_dentro` em `icones.*.mapa`, `desenhos` e
            # `cosmic.mapa` — e esta função NÃO valida nada antes de ler, como o
            # `campo` explica duas telas acima.
            #
            # Sair do pack é IGNORAR aquela camada, e não levantar: quem chama o
            # `acervo` espera "achei" ou "não achei", e a herança logo abaixo
            # ainda pode ter a resposta certa.
            #
            # Por isso o caminho passa pelo `_dentro` aqui também, e o que se usa é o realpath
            # que ele conferiu.
            try:
                alvo = _dentro(dir_pack,
                               os.path.join(declarado, arquivo) if arquivo else declarado,
                               categoria)
            except Recusa as e:
                print(f"  aviso {e} — esta camada foi ignorada", file=sys.stderr)
                alvo = None
            if alvo and os.path.exists(alvo):
                # A barra do fim de uma pasta declarada volta, como no `dir_acervo`.
                return alvo + os.sep if not arquivo and declarado.endswith("/") else alvo
        # O Dracula declara `heranca: "catppuccin"` no topo E
        # `icones.mimetypes.herda: "catppuccin"` no bloco — a do bloco é a que
        # fala daquela categoria, e um pack que herde só uma categoria de outro
        # lugar precisa dela.
        bloco = categoria.rsplit(".", 1)[0]
        ref = campo(ref, bloco + ".herda") or campo(ref, "heranca")
    if motor:
        alvo = os.path.join(RAIZ, motor, arquivo) if arquivo else os.path.join(RAIZ, motor)
        if os.path.exists(alvo):
            return alvo
    return None

# O `acervo` é a porta de quem LÊ: ele devolve None quando o arquivo não
# existe, e isso é a resposta certa para quem vai abrir.
#
# Sem esta função, cada escritor montaria `<dir do pack>/<declarado>` à mão —
# que é a mesma divergência silenciosa que o `acervo` veio matar do lado da
# leitura, entrando de volta pela porta da escrita.
#
# Herdar é dizer "leia do vizinho".
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
        declarado = padrao_do_formato(ref, padrao)
    # A MESMA GUARDA DO `acervo`, E PELO MESMO MOTIVO: um pack de terceiro com
    # `"desenhos": "../../../algum/lugar"` faria o gerador ESCREVER fora do
    # pack.
    real = _dentro(dir_pack, declarado, categoria)
    return real + os.sep if declarado.endswith("/") else real


# Essa frase é decisão de TEMA, e o lugar dela é o pack.
#
# Sem prefixo havia só duas saídas, e as duas eram ruins: ou a decisão fica em
# `assets/` (e trocar de pack não troca a escolha), ou cada pack carrega uma
# CÓPIA dos 113 SVG.
#
# O prefixo é a terceira saída: a linha mora no pack, o arquivo mora no motor.
#
#     org.telegram.desktop          : motor:arcticons/telegram.svg
#     io.github.flattool.Warehouse  : apps/Warehouse.svg
MOTOR = "motor:"
PACK_BASE = "meowsystem"
ACERVO_DO_MOTOR = os.path.join("packs", PACK_BASE, "icones")
PASTAS_DE_ANTES = {
    "arcticons-apps": "apps",
    "convertidos-apps": "apps",
    "arcticons": "sistema",
    "autorais/leitura": "sistema",
}

# Uma escolha do painel ou uma linha do `icones-traco.map` gravada antes das
# três pastas guarda o caminho de então (`assets/icones/resgatados/x.svg`).
CAMINHOS_DE_ANTES = (
    ("assets/icones/arcticons-apps/", "packs/meowsystem/icones/apps/"),
    ("assets/icones/convertidos-apps/", "packs/meowsystem/icones/apps/"),
    ("assets/icones/arcticons/", "packs/meowsystem/icones/sistema/arcticons/"),
    ("assets/icones/autorais/leitura/", "packs/meowsystem/icones/sistema/"),
    ("assets/icones/resgatados/", "packs/dracula/icones/apps/"),
    ("packs/*/icones/autorais/", "packs/*/icones/apps/autorais/"),
    ("packs/*/icones/feitos-a-mao/", "packs/*/icones/biblioteca/feitos-a-mao/"),
    ("packs/*/icones/pastas/", "packs/*/icones/sistema/pastas/"),
    ("packs/*/icones/mimetypes/", "packs/*/icones/sistema/mimetypes/"),
)


# O PADRÃO DE UM PACK DE ANTES. Um pack `formato` 1 que não declara a pasta
# dos autorais a tem em `icones/autorais/`; o de formato 2, dentro de
# `apps/`. Quem chama passa o padrão de hoje, e o pack velho recebe o dele.
PADROES_DE_ANTES = {"icones/apps/": "icones/autorais/",
                    "icones/biblioteca/feitos-a-mao/": "icones/feitos-a-mao/"}


def padrao_do_formato(ref, padrao):
    """O `padrao` de hoje, ou o de antes num pack de formato 1."""
    formato = campo(ref, "formato", FORMATO_MAX)
    if isinstance(formato, int) and formato < 2:
        return PADROES_DE_ANTES.get(padrao, padrao)
    return padrao


TABELA_DE_ANTES = os.path.join(RAIZ, "packs", "CAMINHOS-DE-ANTES.tsv")


def _tabela_de_antes():
    """{caminho de antes da P96: caminho de hoje} — a tabela que o reorganizar-2-packs.sh escreveu."""
    saida = {}
    try:
        with open(TABELA_DE_ANTES, encoding="utf-8") as fh:
            for linha in fh:
                if linha.startswith("#") or "\t" not in linha:
                    continue
                antes, agora = linha.rstrip("\n").split("\t", 1)
                saida[antes] = agora
    except OSError:
        pass
    return saida


def caminho_de_hoje(caminho):
    """O caminho de um desenho que mudou de pasta (P88, P96), ou ele mesmo."""
    cheio = caminho if os.path.isabs(caminho) else os.path.join(RAIZ, caminho)
    if os.path.exists(cheio):
        return caminho
    rel = os.path.relpath(cheio, RAIZ) if cheio.startswith(RAIZ + os.sep) else None
    if rel is None:
        return caminho
    for _volta in range(3):
        rel_p88 = rel
        for antes, agora in CAMINHOS_DE_ANTES:
            padrao = "^" + re.escape(antes).replace(r"\*", "([a-z0-9][a-z0-9-]*)")
            achou = re.match(padrao, rel)
            if achou:
                rel = (agora.replace("*", achou.group(1)) if achou.groups() else agora) + rel[achou.end():]
                break
        novo = _tabela_de_antes().get(rel)
        if novo:
            return novo if not os.path.isabs(caminho) else os.path.join(RAIZ, novo)
        if rel == rel_p88:
            break
    if os.path.exists(os.path.join(RAIZ, rel)):
        return rel if not os.path.isabs(caminho) else os.path.join(RAIZ, rel)
    return caminho


def _caminho_de_hoje_p88(caminho):
    """A regra da P88 sozinha (o que o `caminho_de_hoje` fazia até a P96)."""
    cheio = caminho if os.path.isabs(caminho) else os.path.join(RAIZ, caminho)
    if os.path.exists(cheio):
        return caminho
    rel = os.path.relpath(cheio, RAIZ) if cheio.startswith(RAIZ + os.sep) else None
    if rel is None:
        return caminho
    for antes, agora in CAMINHOS_DE_ANTES:
        padrao = "^" + re.escape(antes).replace(r"\*", "([a-z0-9][a-z0-9-]*)")
        achou = re.match(padrao, rel)
        if not achou:
            continue
        novo = agora.replace("*", achou.group(1)) if achou.groups() else agora
        novo = novo + rel[achou.end():]
        if os.path.exists(os.path.join(RAIZ, novo)):
            return novo if not os.path.isabs(caminho) else os.path.join(RAIZ, novo)
    return caminho

# É a mesma razão do `motor:`, um nível ao lado: um pack que queira o Obsidian
# do Catppuccin escreve a linha que diz isso, em vez de carregar uma cópia que
# defasa.
#
#     md.obsidian.Obsidian : pack:catppuccin:apps/obsidian.svg
#
# O `<caminho>` é relativo a `<outro pack>/icones/`, que é onde mora o mapa de
# todo pack.
OUTRO_PACK = "pack:"


def _caminho_da_maquina(resto):
    """`~/…` ou caminho absoluto: um endereço desta máquina, e não do pack."""
    return resto.startswith("~") or os.path.isabs(resto)


def resolver_alvo(valor, base):
    """O arquivo que uma linha de mapa nomeia. Recusa o que sai da raiz.

    `motor:x` resolve no acervo do pack-base; `pack:<id>:x` em
    `<pack id>/icones/x`; sem prefixo, contra a `base` que o chamador passa.
    Devolve o caminho EXISTA ELE OU NÃO: quem chama é que sabe se um alvo
    ausente é erro (nome no mapa sem desenho no disco) ou não.
    """
    valor = (valor or "").strip()
    if not valor:
        return ""
    if valor.startswith(MOTOR):
        raiz, resto = os.path.join(RAIZ, ACERVO_DO_MOTOR), valor[len(MOTOR):].strip()
        for antes, agora in PASTAS_DE_ANTES.items():
            if resto.startswith(antes + "/"):
                resto = agora + resto[len(antes):]
                break
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
    # Um absoluto já caía na guarda do `_dentro` logo abaixo, mas com a frase
    # "sai de <raiz>", que manda procurar um `../` que não existe.
    #
    # Um mapa aponta para o pack, para o motor ou para outro pack; arte da
    # máquina entra por CÓPIA, com uma linha no PROCEDENCIA.md — é a regra 5, e
    # a frase diz isso.
    if _caminho_da_maquina(resto):
        raise Recusa(f"{valor!r} é um endereço desta máquina, e não do pack. "
                     f"Copie a arte para dentro do pack e registre a origem no "
                     f"PROCEDENCIA.md — ver docs/PACKS.md, 'Fonte e derivados'")
    # O `_dentro` diz "sai de dentro do pack", que é a frase certa para ele: os
    # cinco campos que ele guarda no `validar` são todos do pack.json.
    try:
        cheio = _dentro(raiz, resto, "alvo")
    except Recusa:
        raise Recusa(f"{valor!r} sai de {raiz}") from None
    if not os.path.exists(cheio) and "/" in resto.strip("/"):
        # P96: as três pastas são planas; `apps/arcticons/x.svg` de um mapa de antes
        # é o `x.svg` de uma das três, hoje.
        partes = resto.strip("/").split("/")
        nome = partes[-1]
        for pasta in PASTAS_DO_FORMATO:
            cand = os.path.join(raiz, pasta, nome)
            if os.path.isfile(cand):
                try:
                    return _dentro(raiz, os.path.join(pasta, nome), "alvo")
                except Recusa:
                    break
        if len(partes) > 2 and partes[0] in PASTAS_DO_FORMATO:
            try:
                return _dentro(raiz, os.path.join(partes[0], nome), "alvo")   # ausente, no lugar plano
            except Recusa:
                pass
    return cheio


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


# --- A FONTE ÚNICA: um nome, um arquivo ------------------
#
# Dois acervos oferecendo o mesmo nome ali não davam erro: davam o último que
# escreveu, e o `meow doctor` "consertando" um para o outro todo dia.
#
# É o diretório onde dois donos disputam o MESMO arquivo.
#
# Dois deles (`guvcview`, `setup-mozc`) são nomes do `apps-resgatados.map`, e aí
# não há camada diferente para desempatar: os dois instaladores escrevem o MESMO
# arquivo.

# O outro mapa que também escreve em `scalable/apps`.
CATEGORIA_RESGATADOS = "icones.resgatados"


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


#     org.kde.ghostwriter : packs/dracula/icones/apps/org.gnome.gitlab.somas.Apostrophe.svg   # ghostwriter — escolhido no painel
#
# O alvo é o caminho do desenho a partir da raiz do MeowSystem (absoluto quando
# o desenho mora num pack de fora dela, em `~/.local/share/ meowsystem/packs`).
#
# A ESCOLHA VENCE O PACK E O MOTOR, com a camada ligada ou não: quem escolheu
# um desenho para um app à mão decidiu, e é isso que o `fontes` diz.
def arquivo_de_escolhas():
    """O caminho do `icones-escolhidos.map` de quem usa (exista ou não)."""
    if os.environ.get("MEOW_ICONES_ESCOLHAS"):
        return os.environ["MEOW_ICONES_ESCOLHAS"]
    conf = os.environ.get("MEOW_CONF") or os.path.join(os.path.expanduser("~"), ".config",
                                                       "meow", "meow.conf")
    return os.path.join(os.path.dirname(conf), "icones-escolhidos.map")


def _alvo_de_escolha(alvo):
    """O arquivo que uma linha de escolha aponta, ou Recusa.

    Só `.svg` comum (raster não é fonte, ver `meow_icones_derivados`), dentro
    da raiz do MeowSystem ou de uma raiz de packs: o arquivo é da pessoa, mas o
    que ele aponta vai para o tema, e uma linha não pode puxar `/etc/` para lá.
    """
    # Uma forma só, a do `realpath`, e é ela que volta: o `normpath` corta `a/../b` no
    # texto, e o kernel sobe a partir do destino quando `a` é link.
    alvo = caminho_de_hoje(alvo)
    escrito = alvo if os.path.isabs(alvo) else os.path.join(RAIZ, alvo)
    reais = [os.path.realpath(r) for r in [RAIZ] + raizes() + [pasta_de_enviados()]]
    real = os.path.realpath(escrito)
    _exigir(any(real.startswith(r + os.sep) for r in reais),
            f"{alvo!r} está fora do MeowSystem e das pastas de packs")
    _exigir(real.endswith(".svg") and os.path.isfile(real) and not os.path.islink(escrito),
            f"{alvo!r} não é um .svg comum que exista")
    return real


def escolhas_do_painel():
    """(número, nome, arquivo) de cada escolha do painel que vale.

    A linha que o `_alvo_de_escolha` recusa não vale, e o motivo vai para o
    stderr: a pessoa a escreveu à mão, ou o desenho saiu do disco."""
    try:
        linhas = list(ler_mapa(arquivo_de_escolhas()))
    except OSError:
        return []
    saida = []
    for num, nome, alvo in linhas:
        try:
            # O NOME TAMBÉM É DADO. Ele vira `<nome>.svg` no tema, e uma linha
            # `../../x : …` escrevia `~/.local/share/x.svg`, fora dele.
            _exigir(nome_de_destino(nome),
                    f"{nome!r}: o nome do ícone só tem letras, dígitos e . _ + -, "
                    f"sem '/' nem '..'")
            saida.append((num, nome, _alvo_de_escolha(alvo)))
        except Recusa as e:
            print(f"  aviso {arquivo_de_escolhas()}:{num}: {e}", file=sys.stderr)
    return saida


def cmd_escolhas():
    for _num, nome, arquivo in escolhas_do_painel():
        print(f"{nome}\t{arquivo}")
    return OK


def fontes(ref=None):
    """Cada (nome, fonte, camada) da camada `scalable/apps`, na ordem dos mapas.

    Um nome que aparece duas vezes é EMPATE — a regra 1 da P28, "um nome, uma
    fonte". Esta função não decide o empate nem o esconde: devolve as duas
    linhas, e quem chama diz o que fazer com elas (o `fonte` recusa, o
    `tests/fonte-unica.sh` falha). A fonte vem como está no disco, exista ela
    ou não: "nome no mapa sem desenho" é a outra metade da regra, e também é
    de quem chama.

    O pack x motor NÃO é empate desde 24/09/2026 (P43): para um nome que os
    dois mapas nomeiam, um lado fica ATRÁS e não sai daqui — o motor com
    `ICONES_DRACULA="sim"`, o pack sem ele. Ver o bloco "O PACK NO AR VENCE O
    MOTOR" acima e o `fontes_e_atras`.

    Linha que o `resolver_alvo` recusa não vira fonte — o motivo vai para o
    stderr, e o `validar` recusa o pack inteiro por ela.
    """
    return fontes_e_atras(ref)[0]


def fontes_e_atras(ref=None):
    """(fontes, atrás): as linhas que valem e as que o interruptor pôs atrás.

    Com `ICONES_DRACULA="sim"` o pack vence e o resgate fica atrás; sem ele, o
    contrário (ver "SÓ COM A CAMADA LIGADA", no bloco acima). Só o nome que
    VIROU fonte do pack entra na disputa: uma linha que o `resolver_alvo`
    recusou não instala nada (o instalador a trata como "sem desenho"), e aí
    o resgate continua sendo o que chega ao tema.
    """
    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    do_pack, do_motor = [], []
    mapa = acervo("icones.apps.mapa", ref=ref)
    if mapa:
        base, camada = os.path.dirname(mapa), OUTRO_PACK + _pack_de(mapa)
        for num, nome, alvo in ler_mapa(mapa):
            try:
                do_pack.append((nome, _relativo(resolver_alvo(alvo, base)), camada))
            except Recusa as e:
                print(f"  aviso {_relativo(mapa)}:{num}: {e}", file=sys.stderr)
    resg = acervo(CATEGORIA_RESGATADOS + ".mapa", ref=ref)
    pasta_resg = acervo(CATEGORIA_RESGATADOS + ".desenhos", ref=ref)
    if resg and pasta_resg and os.path.isfile(resg):
        with open(resg, encoding="utf-8") as fh:
            for linha in fh:
                campos = linha.split("#", 1)[0].split(":")
                nome = campos[0].strip()
                # O nome é dado de pack: só o de conjunto fechado vira arquivo.
                if len(campos) >= 3 and nome and nome_de_destino(nome):
                    do_motor.append(
                        (nome, _relativo(os.path.join(pasta_resg, nome + ".svg")), "resgatados"))
    # O padrão é ligada: só o "nao" escrito desliga, a mesma régua do
    # `icones_apps_dracula.sh`.
    ligada = (os.environ.get("ICONES_DRACULA") or "sim") != "nao"
    vence = {nome for nome, _fonte, _camada in (do_pack if ligada else do_motor)}
    atras = [linha for linha in (do_motor if ligada else do_pack) if linha[0] in vence]
    # O que ela nomeia vai para trás, do pack e do motor.
    escolhas = [(nome, _relativo(arq), "escolha") for _num, nome, arq in escolhas_do_painel()]
    escolhidos = {nome for nome, _f, _c in escolhas}
    atras += [linha for linha in do_pack + do_motor
              if linha[0] in escolhidos and linha not in atras]
    return [linha for linha in do_pack + do_motor if linha not in atras] + escolhas, atras


def cmd_fontes(ref):
    for nome, fonte, camada in fontes(ref):
        print(f"{nome}\t{fonte}\t{camada}")
    return OK


def cmd_fonte(nome, ref):
    """As fontes de UM nome. 0 = exatamente uma, e ela existe no disco."""
    valem, atras = fontes_e_atras(ref)
    achadas = [(f, c) for n, f, c in valem if n == nome]
    for fonte, camada in achadas:
        print(f"{nome}\t{fonte}\t{camada}")
    # O LADO QUE FICOU ATRÁS É DITO, E NÃO ESCONDIDO: quem pergunta "de onde
    # sai o guvcview?" com o Dracula no ar precisa saber que o outro desenho
    # existe e volta sozinho quando o interruptor ou o pack mudar.
    chave = os.environ.get("ICONES_DRACULA") or "sim"
    escolhido = any(c == "escolha" for _f, c in achadas)
    for _n, fonte, camada in (a for a in atras if a[0] == nome):
        if escolhido:
            porque = ("a escolha do painel, no estado de quem usa, vence o pack e o motor "
                      "(P73), e este desenho volta se ela for desfeita")
        elif camada == "resgatados":
            porque = (f"com ICONES_DRACULA=\"{chave}\" o pack no ar vence o motor para este "
                      f"nome, e o resgate volta a valer com outro pack ou com a camada desligada")
        else:
            porque = (f"com ICONES_DRACULA=\"{chave}\" o mapa do pack não põe nada no tema, "
                      f"e o resgate do motor é a escolha")
        print(f"  info {fonte} ({camada}) fica atrás: {porque}", file=sys.stderr)
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


# Sem caminho de volta, a cópia defasa e ninguém percebe.
#
# Ele diz qual lado andou e imprime o `cp` para quem decidir; o gesto é da
# pessoa.
#
# QUAL LADO ANDOU: o registro decide Só com a cópia e a origem na mão não dá
# para saber quem mudou — as duas diferem, e é tudo.
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
    if valor.startswith(MOTOR) or valor.startswith(OUTRO_PACK):
        return resolver_alvo(valor, RAIZ)
    if valor.startswith("~"):
        return os.path.expanduser(valor)
    if os.path.isabs(valor):
        return valor
    raise Recusa(f"lido de {valor!r}: use '~/…', 'motor:…', 'pack:<id>:…' ou um caminho absoluto")


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

    em_dia = fora = andou = registro = 0
    for lin in linhas:
        arquivo, lido, reg = lin.get("arquivo", ""), lin.get("lido de", ""), lin.get("sha256", "").lower()
        rotulo = arquivo or "(linha sem arquivo)"
        try:
            aqui = _dentro(dir_pack, arquivo, "PROCEDENCIA.md")
            # Sem `lido de`, sem origem: é só registro (ver o bloco acima).
            origem = _origem(lido) if lido else ""
            _exigir(RE_SHA256.match(reg), f"sha256 {reg!r} não tem 64 hex")
            # A coluna `lido de` é dado de quem escreveu o pack, e um pack de
            # terceiro escreve o dele: sem esta linha, `~/.ssh/id_ed25519`
            # seria aberto e teria o sha256 impresso na tela.
            _exigir(not origem
                    or os.path.splitext(origem)[1].lower() == os.path.splitext(aqui)[1].lower(),
                    f"lido de {lido!r} não é o mesmo tipo de arquivo que {arquivo!r}")
        except Recusa as e:
            print(f"  ~~   {rotulo} — a linha do PROCEDENCIA.md não serve: {e}")
            andou += 1
            continue
        if not os.path.isfile(aqui):
            print(f"  ~~   {rotulo} — está no PROCEDENCIA.md e não existe no pack")
            andou += 1
            continue
        if not origem:
            registro += 1
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

    total = len(linhas) - registro
    resumo = f"{em_dia} de {total} em dia com a origem"
    if fora:
        resumo += f" · {fora} com a origem fora desta máquina"
    if andou:
        resumo += f" · {andou} divergente(s) — nada foi copiado"
    if registro:
        resumo += f" · {registro} só registro, sem origem a ler"
    print(f"\n  {resumo}")
    return RECUSADO if andou else OK

# --- OS DESENHOS AUTORAIS, DECLARADOS --------------
#
# Cada `icones/autorais/<nome>.json` descreve UM desenho, no vocabulário que o
# gerador já usava por dentro: papéis (`sujeito`, `tinta`, `fundo`...) que
# resolvem na paleta do flavor, e o SVG com uma lacuna `{papel}` onde a cor
# entra.
#
# Um glob ali quebraria o `dir_acervo` do gerador, o `onde` do
# `completar_icones.sh` e o `_contar_acervo` do `info`, e os quatro `desenhos`
# do formato deixariam de ser a mesma coisa.
MARCA_ACCENT = "<accent>"
# Para esse pack o `dir_acervo` do gerador e do «Salvar no pack» cai no padrão e
# ESCREVE em `icones/autorais/`, e o `autorais()` lia só a pasta DECLARADA —
# então não lia nada ali.
PASTA_AUTORAIS = "icones/apps/"
# O rótulo do seletor mora no `catalog.json` de cada uma das três pastas; desde a P96
# os autorais moram em `apps/`, e o catálogo não é declaração de desenho.
CATALOGO = "catalog.json"
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
        # Vale em toda camada, e não só na do próprio pack: um pack base sem
        # `desenhos` lê as declarações dele em `icones/autorais/`, e quem o
        # herda tem de ver o mesmo conjunto que ele vê.
        try:
            pasta = dir_acervo("icones.autorais.desenhos", ref=dir_pack,
                               padrao=PASTA_AUTORAIS)
        except Recusa as e:
            print(f"  aviso {e} — esta camada foi ignorada", file=sys.stderr)
            pasta = ""
        if pasta and os.path.isdir(pasta):
            for arq in sorted(os.listdir(pasta)):
                if arq.endswith(".json") and arq != CATALOGO:
                    achados.setdefault(arq[:-len(".json")],
                                       (os.path.join(pasta, arq), os.path.basename(dir_pack)))
        ref = campo(ref, "icones.autorais.herda") or campo(ref, "heranca")
    return achados


# --- A CAPTURA DE TEMA, E DE QUEM ELA É -------------------------------------
#
# `assets/` é o que o MeowSystem É; `packs/` é o que ele VESTE. Era promessa sem
# lastro: nenhum pack conseguia trazer a própria captura pronta, porque nada
# sabia procurá-la lá dentro.
#
# Ela não é tema de pack nenhum: é o MOLDE do esquema v1 que o COSMIC de 04/2026
# escrevia (`gerar_tema_v1.py` deriva dela, chave por chave) e o reset de
# fábrica DESTA máquina.
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
        return _dentro(dir_pack, rel, CATEGORIA_CAPTURA)
    except Recusa as e:
        print(f"  aviso {e} — esta camada foi ignorada", file=sys.stderr)
        return None


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
    # O `aplicar_tema.sh` copia a captura inteira para ~/.config/cosmic: uma
    # `temas/capturados/<par>` que fosse symlink para fora levaria para lá o
    # que estivesse no destino do link.
    # Por isso o par passa pela régua de nome, e a pasta, pelo `_dentro` da pasta de
    # capturas.
    if not nome_de_destino(par):
        return None
    for ident, dir_pack in _cadeia(_ref_ativa(ref)):
        base = _dir_capturas(ident, dir_pack)
        if not base:
            continue
        try:
            alvo = _dentro(base, par, CATEGORIA_CAPTURA)
        except Recusa as e:
            print(f"  aviso {e} — esta camada foi ignorada", file=sys.stderr)
            continue
        if os.path.isdir(alvo):
            return alvo
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
    # O par vira pasta dentro do pack: a régua de nome da "A REGRA ÚNICA".
    if not nome_de_destino(par):
        return None
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
        `scripts/temas-de-apps/`, espalhadas por oito módulos, e ZERO deles
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
            if valor is None and chave == ["arquivo"]:
                # P96 (23/10/2026): o modelo que a paleta preenche inteiro não é do pack, é do
                # motor — `scripts/temas-de-apps/<app>/<app>.modelo.*`. O pack declara o
                # aplicativo (o bloco existe) e o modelo vem daqui.
                pasta = os.path.join(RAIZ, "scripts", "temas-de-apps", alvo)
                try:
                    modelos = sorted(f for f in os.listdir(pasta) if f.startswith(alvo + ".modelo."))
                except OSError:
                    modelos = []
                if modelos:
                    return quem, os.path.join(pasta, modelos[0])
            if valor is None:
                return None, None
            if chave == ["arquivo"]:
                try:
                    cheio = _dentro(dir_pack, str(valor), categoria)
                except Recusa as e:
                    print(f"  aviso {e} — esta camada foi ignorada", file=sys.stderr)
                    return None, None
                return (quem, cheio) if os.path.exists(cheio) else (None, None)
            if isinstance(valor, str):
                valor = valor.replace("<flavor>", flavor)
            return quem, valor
        prox = bloco.get("herda") if isinstance(bloco, dict) else None
        ref = prox or campo(ref, "heranca")
    return None, None


# --- O PONTEIRO PRÓPRIO ----------------------------
#
# `cursores/<nome>/cursors/` — a forma de todo tema de ponteiro, a mesma que o
# `cursor.sh adicionar` já instala.
#
# O `_cursor_nome_seguro` troca por `-` o que estiver fora de [A-Za-z0-9._-] e
# come o `.`/`-` da frente antes de o nome virar diretório.
#
# Um tema Xcursor é feito de links (`left_ptr -> default`, dezenas deles).
CATEGORIA_PONTEIRO = "origens.cursores.proprio"
SUFIXO_PONTEIRO = "-cursors"
RE_NOME_PONTEIRO = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]{0,79}$")
RE_NOME_MASCOTE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]{0,79}$")
# `default` é o nome canônico do ponteiro de repouso, `left_ptr` o histórico. Um
# tema sem nenhum dos dois não tem o ponteiro que aparece primeiro na tela, e o
# painel não tem de onde tirar a prévia (`_prev_cursores` procura os mesmos).
PONTEIROS_DE_REPOUSO = ("default", "left_ptr")


def valor_do_ponteiro(nome):
    """O valor da chave CURSOR que escolhe o tema `nome` — sem o `-cursors`."""
    return nome[:-len(SUFIXO_PONTEIRO)] if nome.endswith(SUFIXO_PONTEIRO) else nome


def conferir_ponteiro(tema, campo=CATEGORIA_PONTEIRO):
    """Levanta Recusa se `tema` não é um tema Xcursor que se copia inteiro."""
    nome = os.path.basename(os.path.normpath(tema))
    _exigir(RE_NOME_PONTEIRO.match(nome) and valor_do_ponteiro(nome),
            f"{campo}: o tema chama-se {nome!r}, e o nome dele é o que a chave CURSOR\n"
            f"    escreve. Só letras, dígitos, '.', '_' e '-', sem começar por '.' ou '-':\n"
            f"    é o que o scripts/cursor.sh aceita como nome de diretório sem mudá-lo.")
    _exigir(os.path.isdir(os.path.join(tema, "cursors")),
            f"{campo}: {nome}/ não tem a pasta cursors/ — sem ela não é tema de ponteiro")
    _exigir(any(os.path.isfile(os.path.join(tema, "cursors", c)) for c in PONTEIROS_DE_REPOUSO),
            f"{campo}: {nome}/cursors/ não tem {' nem '.join(PONTEIROS_DE_REPOUSO)} —\n"
            f"    é o ponteiro de repouso, o primeiro que aparece na tela.")
    # `cursors/hand -> hand2` sem o `hand2` cai DENTRO do tema pelo `realpath` e
    # passava.
    for base, dirs, arqs in os.walk(tema):
        for n in dirs + arqs:
            rel = os.path.relpath(os.path.join(base, n), tema)
            try:
                cheio = _dentro(tema, rel, campo)
            except Recusa:
                raise Recusa(f"{campo}: {nome}/{rel} aponta para fora do tema. O tema é\n"
                             f"    copiado inteiro para ~/.local/share/icons/, e o link iria junto.") from None
            _exigir(os.path.exists(cheio),
                    f"{campo}: {nome}/{rel} é um link que não leva a arquivo nenhum —\n"
                    f"    o ponteiro que ele promete não existe. Aponte-o para um que exista,\n"
                    f"    ou tire-o.")


# --- A ARTE QUE O PACK BAIXA, PINADA ---------------
#
# {"url": "https://…", "sha256": "<64 hex>", "pasta": "<dentro do pacote>"}
# `url` é um .tar (gz ou xz): o arquivo de um commit no GitHub e o asset de um
# release são isso.
#
# O `pack.py` não escreve fora do pack (ver o `plano_de_uso`).
EXT_PACOTE = (".tar.gz", ".tgz", ".tar.xz", ".txz")
RE_PASTA_PACOTE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]*(/[A-Za-z0-9_][A-Za-z0-9._-]*)*$")


def origem_pinada(origem, trilha, com_nome=False):
    """{'url', 'sha256', 'pasta'} (e 'nome', no ponteiro) de um bloco `origem`.

    Levanta Recusa com o campo e o que consertar. Não toca a rede: quem baixa
    é o shell, e confere o sha256 do que chegou contra o que sai daqui.
    """
    _exigir(isinstance(origem, dict),
            f"{trilha}: precisa ser um objeto — {{\"url\", \"sha256\", \"pasta\"}}")
    esperadas = {"url", "sha256", "pasta"} | ({"nome"} if com_nome else set())
    chaves = {k for k in origem if not str(k).startswith("_")}
    _exigir(chaves == esperadas,
            f"{trilha}: declara {', '.join(sorted(esperadas))}, e só elas.\n"
            f"    Veio: {', '.join(sorted(chaves)) or '(nada)'}")
    url, soma, pasta = origem["url"], origem["sha256"], origem["pasta"]
    _exigir(isinstance(url, str) and url.startswith("https://"),
            f"{trilha}.url: {url!r} — só https:// é aceito")
    _exigir(url.lower().endswith(EXT_PACOTE),
            f"{trilha}.url: {url!r} não termina em {', '.join(EXT_PACOTE)}.\n"
            f"    Quem instala abre um .tar e mais nada; um .zip ou uma página não servem.")
    _exigir(isinstance(soma, str) and RE_SHA256.match(soma),
            f"{trilha}.sha256: {soma!r} não é um sha256 (64 hex minúsculos).\n"
            f"    O conteúdo é pinado: sem ele, a URL entrega o que quiser.")
    _exigir(isinstance(pasta, str) and RE_PASTA_PACOTE.match(pasta),
            f"{trilha}.pasta: {pasta!r} — o caminho do tema dentro do pacote, nome por\n"
            f"    nome, sem '..', sem barra na frente e sem começar por '.' ou '-'.")
    saida = {"url": url, "sha256": soma, "pasta": pasta}
    if com_nome:
        nome = origem["nome"]
        _exigir(isinstance(nome, str) and RE_NOME_PONTEIRO.match(nome) and valor_do_ponteiro(nome),
                f"{trilha}.nome: {nome!r} é o valor que a chave CURSOR escreve. Só letras,\n"
                f"    dígitos, '.', '_' e '-', sem começar por '.' ou '-': é o que o\n"
                f"    scripts/cursor.sh aceita como nome de diretório sem mudá-lo.")
        saida["nome"] = nome
    return saida


def _url_curta(url):
    """`github.com/dono/repo` de uma URL — o bastante para dizer de onde, na tabela."""
    from urllib.parse import urlsplit
    partes = urlsplit(url)
    caminho = [p for p in partes.path.split("/") if p]
    return "/".join([partes.netloc] + caminho[:2])


def _ponteiro_de_fora(ref):
    """(id, origem) do primeiro pack da cadeia que declara o ponteiro BAIXADO.

    A subida é a do `ponteiro`: o bloco `origens.cursores` do pack, senão o
    `herda` dele, senão a `heranca`. Um `proprio` que venha antes na cadeia
    responde primeiro — o pack mais perto de quem pergunta vence, seja qual for
    a forma —, e aí a resposta é None, para o `acervo` achar o tema dentro dele.
    """
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        dir_pack = achar(ref)
        if not dir_pack:
            break
        bloco = campo(ref, "origens.cursores")
        if isinstance(bloco, dict) and not bloco.get("herda"):
            if "proprio" in bloco:
                return None
            if "origem" in bloco:
                return campo(ref, "id") or os.path.basename(dir_pack), bloco["origem"]
        prox = bloco.get("herda") if isinstance(bloco, dict) else None
        ref = prox or campo(ref, "heranca")
    return None


def ponteiro(ref=None):
    """O ponteiro próprio que a cadeia alcança: {'pack', 'dir', 'valor'}, ou None.

    A subida é a do `acervo` — `proprio` do pack; senão `origens.cursores.herda`,
    senão `heranca` —, e por isso esta função a pede a ele em vez de refazê-la.
    Um tema que o `acervo` acha e que não passa em `conferir_ponteiro` é
    ignorado com aviso: o `validar` já o recusa na publicação, e quem pergunta
    aqui é o `cursor.sh`, que vai COPIAR o diretório.

    O PONTEIRO BAIXADO (`origem`, P41) volta com `dir` vazio e com `url`,
    `sha256` e `pasta`: não há tema dentro do pack para apontar, e quem o põe
    no disco é o `cursor.sh`, com a rede. Uma origem que não passa na forma é
    ignorada com aviso, pelo mesmo motivo do tema recusado.
    """
    de_fora = _ponteiro_de_fora(_ref_ativa(ref))
    if de_fora:
        quem, bloco = de_fora
        try:
            org = origem_pinada(bloco, "origens.cursores.origem", com_nome=True)
        except Recusa as e:
            print(f"  aviso {e} — o ponteiro do pack foi ignorado", file=sys.stderr)
            return None
        return {"pack": quem, "dir": "", "valor": valor_do_ponteiro(org["nome"]),
                "url": org["url"], "sha256": org["sha256"], "pasta": org["pasta"]}
    tema = acervo(CATEGORIA_PONTEIRO, ref=_ref_ativa(ref))
    if not tema or not os.path.isdir(tema):
        return None
    tema = os.path.normpath(tema)
    try:
        conferir_ponteiro(tema)
    except Recusa as e:
        print(f"  aviso {e} — o ponteiro do pack foi ignorado", file=sys.stderr)
        return None
    return {"pack": _pack_de(tema), "dir": tema,
            "valor": valor_do_ponteiro(os.path.basename(tema))}


# --- AS FONTES DE TEXTO ----------------------------
#
# Em português "fonte" é a tipografia e é a origem. A CHAVE do pack.json é
# `fontes` — é como quem escreve um pack procura —; o VERBO é `tipografia`.
#
# O `instalar_fontes.sh` instala a JetBrainsMono Nerd Font pinada e aponta o
# terminal para ela, para todo pack — isso continua do motor.
#
# Duas formas: `{"arquivo": "fontes/X.otf"}` dentro do pack, pelo `realpath`; ou
# `{"nome", "url": "https://…", "sha256"}` fora dele, com o conteúdo pinado. A URL
# é de um arquivo de fonte, nunca de um pacote: o que entra sozinho se confere byte a byte.
CATEGORIA_FONTES = "fontes"
EXT_FONTE = (".ttf", ".otf")
# O nome vira nome de arquivo em `~/.local/share/fonts/` e viaja numa linha
# separada por TAB até o shell. Espaço é norma em fonte (`zrnic rg.otf`, contado
# no cabeçalho do `instalar_fontes.sh`); barra, TAB e quebra de linha, nunca.
RE_NOME_FONTE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9 ._+-]{0,119}$")
# Os quatro primeiros bytes de um TrueType ou OpenType. É a mesma pergunta que
# o logo faz ao PNG renomeado: extensão não é conteúdo.
ASSINATURAS_DE_FONTE = (b"\x00\x01\x00\x00", b"true", b"OTTO")


def _fontes_declaradas(dir_pack, lista, trilha="fontes.proprio"):
    """[(nome, origem, sha256)] de uma lista `fontes.proprio`. Levanta Recusa.

    `origem` é o caminho dentro do pack ou a URL; `sha256` vem vazio para o
    arquivo de dentro do pack, que é conferido pelo próprio conteúdo.
    """
    _exigir(isinstance(lista, list), f"{trilha}: precisa ser uma lista")
    saida, vistos = [], {}
    for i, fonte in enumerate(lista):
        aqui = f"{trilha}[{i}]"
        _exigir(isinstance(fonte, dict),
                f"{aqui}: cada fonte é um objeto — {{\"arquivo\": …}} ou {{\"nome\", \"url\", \"sha256\"}}")
        chaves = {k for k in fonte if not str(k).startswith("_")}
        if "arquivo" in chaves:
            _exigir(chaves == {"arquivo"},
                    f"{aqui}: 'arquivo' vem sozinho. A fonte de dentro do pack é o próprio\n"
                    f"    arquivo; 'url' e 'sha256' são da fonte que vem de fora.")
            arq = fonte["arquivo"]
            _exigir(isinstance(arq, str) and arq, f"{aqui}.arquivo: precisa ser um caminho")
            alvo = _dentro(dir_pack, arq, f"{aqui}.arquivo")
            _exigir(os.path.isfile(alvo),
                    f"{aqui}.arquivo: {arq!r} está declarado e NÃO existe no pack")
            with open(alvo, "rb") as fh:
                cabeca = fh.read(4)
            _exigir(cabeca in ASSINATURAS_DE_FONTE,
                    f"{aqui}.arquivo: {arq!r} não é TrueType nem OpenType por dentro —\n"
                    f"    a extensão diz fonte, os primeiros bytes não.")
            nome, origem, soma = os.path.basename(arq), alvo, ""
        else:
            _exigir(chaves == {"nome", "url", "sha256"},
                    f"{aqui}: a fonte de fora do pack declara as três — nome, url e sha256.\n"
                    f"    Veio: {', '.join(sorted(chaves)) or '(nada)'}")
            nome, origem, soma = fonte["nome"], fonte["url"], fonte["sha256"]
            _exigir(isinstance(origem, str) and origem.startswith("https://"),
                    f"{aqui}.url: {origem!r} — só https:// é aceito")
            _exigir(isinstance(soma, str) and RE_SHA256.match(soma),
                    f"{aqui}.sha256: {soma!r} não é um sha256 (64 hex minúsculos).\n"
                    f"    O conteúdo é pinado: sem ele, a URL entrega o que quiser.")
        _exigir(isinstance(nome, str) and RE_NOME_FONTE.match(nome)
                and nome.lower().endswith(EXT_FONTE),
                f"{aqui}: o nome {nome!r} vira arquivo em ~/.local/share/fonts/ —\n"
                f"    termina em {' ou '.join(EXT_FONTE)}, sem barra, sem começar por '.' ou '-'.")
        _exigir(nome not in vistos,
                f"{aqui}: {nome!r} já está em {trilha}[{vistos.get(nome)}] — um nome, um arquivo no disco")
        vistos[nome] = i
        saida.append((nome, origem, soma))
    return saida


def tipografia(ref=None):
    """(id de quem responde, [(nome, origem, sha256)]), ou (None, []).

    A travessia é a do `tema_de_app`: responde o primeiro pack da cadeia que
    declara `fontes.proprio`; `fontes.herda` vence a `heranca` do pack; o
    conjunto de vistos corta a herança circular. Levanta Recusa se a lista de
    quem responde não passa — quem pergunta vai instalar o que ela diz.
    """
    ref = _ref_ativa(ref)
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        dir_pack = achar(ref)
        if not dir_pack:
            break
        bloco = campo(ref, CATEGORIA_FONTES)
        if isinstance(bloco, dict) and not bloco.get("herda") and "proprio" in bloco:
            quem = campo(ref, "id") or os.path.basename(dir_pack)
            return quem, _fontes_declaradas(dir_pack, bloco["proprio"])
        prox = bloco.get("herda") if isinstance(bloco, dict) else None
        ref = prox or campo(ref, "heranca")
    return None, []


# --- A BASE DE ÍCONES -------------------------------
#
# O `MeowSystem-Icons` desenha uma parte dos ícones e HERDA o resto (`Inherits=`
# do index.theme, escrito pelo `construir_icones.sh`).
#
# QUEM VENCE — A ORDEM DO "Quem vence" DO docs/PACKS.md
#   1. `ICONES_BASE` escrito à mão, diferente do de fábrica, vence: é o tema
#      que a pessoa escolheu, e o meow.conf manda na máquina.
#   2. O de fábrica (`Papirus-Dark`, ou vazio) cede à base que o pack declara.
#   3. Sem base na cadeia, vale o de fábrica, como sempre valeu.
CATEGORIA_BASE = "icones.base"
ICONES_BASE_DO_EXEMPLO = "Papirus-Dark"


def _base_escolhida(pedido):
    """O `ICONES_BASE` que é escolha dela, ou "" quando ele cede ao pack.

    Cede o de fábrica, o vazio e o nome da nossa própria base. O nome do tema
    vem do ambiente, como no shell (`${NOME_TEMA_ICONES:-MeowSystem-Icons}`).
    """
    pedido = (pedido or "").strip()
    nossa = (os.environ.get("NOME_TEMA_ICONES") or "").strip() or "MeowSystem-Icons"
    # As camadas de trás da base moram em `<nossa>-Base-<n>`, e escolher uma
    # delas pelo nome também é pedir a base do pack.
    if re.fullmatch(re.escape(nossa) + r"-Base(-[0-9]+)?", pedido):
        return ""
    return "" if pedido in ("", ICONES_BASE_DO_EXEMPLO) else pedido


def base_de_icones(ref=None):
    """A base que a cadeia declara — {'pack', 'url', 'sha256', 'pasta'} —, ou None.

    Levanta Recusa se a origem de quem responde não passa: quem pergunta vai
    baixar e instalar o que ela diz, como no `tipografia`.
    """
    ref = _ref_ativa(ref)
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        dir_pack = achar(ref)
        if not dir_pack:
            break
        bloco = campo(ref, CATEGORIA_BASE)
        if isinstance(bloco, dict) and not bloco.get("herda") and "origem" in bloco:
            quem = campo(ref, "id") or os.path.basename(dir_pack)
            # `por_tras`: as camadas que ficam atrás da frente, na ordem do
            # `Inherits=`. Vazia num pack que traz uma base só.
            atras = [origem_pinada(c.get("origem") if isinstance(c, dict) else None,
                                   f"{CATEGORIA_BASE}.por_tras[{i}].origem")
                     for i, c in enumerate(bloco.get("por_tras") or [])]
            return dict(origem_pinada(bloco["origem"], CATEGORIA_BASE + ".origem"),
                        pack=quem, por_tras=atras)
        prox = bloco.get("herda") if isinstance(bloco, dict) else None
        ref = prox or campo(ref, "heranca")
    return None


def base_que_vale(ref, pedido):
    """(quem, tema, declarada): quem vale para o `Inherits=` do MeowSystem-Icons.

    `pedido` é o `ICONES_BASE` já expandido pelo shell. `quem` é 'conf', 'pack'
    ou 'motor' (o valor de fábrica da chave, como na coluna do `info`); `tema`
    é o nome a herdar nos dois que não são o pack (no pack, o nome é o do
    diretório que o `construir_icones.sh` instala, e é ele quem sabe).
    `declarada` é o `base_de_icones` — vem mesmo quando o conf vence, para a
    tela dizer os dois.
    """
    escolhida = _base_escolhida(pedido)
    declarada = base_de_icones(ref)
    if escolhida:
        return "conf", escolhida, declarada
    if declarada:
        return "pack", "", declarada
    return "motor", ICONES_BASE_DO_EXEMPLO, None


# `$XDG_DATA_HOME/icons`, `~/.icons` e `<XDG_DATA_DIRS>/icons`, nessa ordem — a
# do resolvedor.
def dir_de_tema_de_icones(nome):
    """O diretório do tema de ícones `nome` no disco, ou "" se ele não está."""
    if not nome or "/" in nome or nome in (".", ".."):
        return ""
    casa = os.path.expanduser("~")
    lugares = [os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.join(casa, ".local/share"), "icons"),
               os.path.join(casa, ".icons")]
    for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":"):
        if d:
            lugares.append(os.path.join(d, "icons"))
    for lugar in lugares:
        cand = os.path.join(lugar, nome)
        if os.path.isfile(os.path.join(cand, "index.theme")):
            return cand
    return ""


# `MeowSystem-<Nome>-<Flavor>-Icons`, com o flavor omitido quando ele é o
# próprio pack (o `dracula` do Dracula): `MeowSystem-Dracula-Icons`,
# `MeowSystem-Dracula-Alucard-Icons`, `MeowSystem-Catppuccin-Mocha-Icons`.
#
# O COMENTÁRIO É O DO PACK: o nome, o flavor e a frase curta da vitrine.
def _so_letras(texto):
    return re.sub(r"[^A-Za-z0-9]+", "", str(texto or ""))


def tema_de_icones(ref=None, flavor=""):
    """(nome, comentario) do tema de ícones montado para o pack `ref` no `flavor`."""
    ref = _ref_ativa(ref)
    dir_pack = achar(ref)
    ident = (campo(ref, "id") or os.path.basename(dir_pack or "") or "pack") if dir_pack else str(ref)
    nome = str(campo(ref, "nome", ident) or ident) if dir_pack else ident
    flavor = (flavor or (campo(ref, "paleta.flavor_padrao", "") if dir_pack else "") or "").strip()
    partes = ["MeowSystem", _so_letras(nome) or _so_letras(ident) or "Pack"]
    if partes[1].lower() == "meowsystem":
        partes = ["MeowSystem"]          # o pack padrão leva o nome do produto (P96): sem «MeowSystem-MeowSystem»
    if flavor and flavor.lower() != ident.lower() and _so_letras(flavor):
        partes.append(_so_letras(flavor)[:1].upper() + _so_letras(flavor)[1:])
    frase = str(campo(ref, "vitrine.descricao_curta", "") or "").strip() if dir_pack else ""
    comentario = f"{nome} ({flavor})" if flavor else nome
    comentario += f" — {frase}" if frase else " — gerado pelo MeowSystem"
    return "-".join(partes + ["Icons"]), comentario.replace("\n", " ")


# O pack declara a lista em `lancador.ocultar`, e o `ocultar_apps.sh` a soma à
# do conf.
RE_DESKTOP_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,200}$")


def ocultar_do_pack(ref=None):
    """Os ids de `.desktop` que o pack esconde do lançador, na ordem dele."""
    ref = _ref_ativa(ref)
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        if not achar(ref):
            break
        lista = campo(ref, "lancador.ocultar")
        if isinstance(lista, list):
            return [n for n in lista if isinstance(n, str) and RE_DESKTOP_ID.match(n)]
        ref = campo(ref, "heranca")
    return []


def base_dos_apelidos(pedido):
    """(tema, dir): o tema de onde pastas e apelidos copiam desenho, e onde ele está."""
    tema = _base_escolhida(pedido) or ICONES_BASE_DO_EXEMPLO
    return tema, dir_de_tema_de_icones(tema)


def _rgb(hexcor):
    """'#RRGGBB' em (r, g, b) de 0 a 1. O parse é um só [revisão da P16, 23/09/2026]:
    a derivação do claro precisa dele solto, e duas cópias do mesmo fatiamento
    divergem no dia em que uma aceitar '#RGB' e a outra não."""
    return tuple(int(hexcor[i:i + 2], 16) / 255 for i in (1, 3, 5))


def _luminancia(hexcor):
    """Luminância relativa de WCAG 2.x. Usada no teste de contraste; desde a
    P10 (23/09/2026), pelo `paleta_css` do painel, para achar o escuro mais
    escuro e o claro mais claro do pack; e, desde a P16, pela derivação do
    claro — a mesma régua nos três lugares."""
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


# Um pack pode vir de terceiros (`meow pack importar`, ou um `git clone` na
# raiz da pessoa, que traz symlink), e tudo o que vem dele — campo do
# pack.json, linha de mapa, arquivo de pasta de desenho — é dado não confiável.
#
# A REGRA ÚNICA: conferir numa forma e abrir noutra é o defeito. As duas metades
# moram aqui (a gêmea em shell é o `meow_dentro`/`meow_nome_seguro`):
#   1. `_dentro`: o caminho resolve com `realpath` e só vale DENTRO da raiz; quem
#      chama abre o que ele devolve, nunca o `join` que entrou.
#   2. `nome_de_destino`: nome que vira arquivo do lado de cá, só
#      `[A-Za-z0-9._+-]`, sem `..`.
RE_NOME_DESTINO = re.compile(r"^[A-Za-z0-9._+-]+$")


def nome_de_destino(nome):
    """True quando `nome` serve de nome de arquivo do lado de cá: sem '/', sem '..'."""
    # `fullmatch`, e não `match` com `$`: o `$` do Python também casa ANTES de
    # um `\n` final, e `"x\n"` passava.
    return isinstance(nome, str) and bool(RE_NOME_DESTINO.fullmatch(nome)) \
        and ".." not in nome and nome != "."


RE_CONTROLE = re.compile(r"[\x00-\x1f\x7f-\x9f]")


def _caractere_de_controle(doc, trilha="raiz"):
    """A trilha do primeiro texto (chave ou valor) com caractere de controle — ou None."""
    if isinstance(doc, str):
        return trilha if RE_CONTROLE.search(doc) else None
    if isinstance(doc, dict):
        for k, v in doc.items():
            achado = _caractere_de_controle(k, f"{trilha}: a chave {k!r}") \
                or _caractere_de_controle(v, f"{trilha}.{k}" if trilha != "raiz" else str(k))
            if achado:
                return achado
    if isinstance(doc, list):
        for i, v in enumerate(doc):
            achado = _caractere_de_controle(v, f"{trilha}[{i}]")
            if achado:
                return achado
    return None


def _dentro(base, alvo, campo):
    """Todo caminho declarado resolve com realpath e cai dentro do pack.

    Devolve o realpath, e é ele que se usa daqui em diante — ver "A REGRA ÚNICA".
    """
    # `"mapa": "x\u0000y"` no pack.json é JSON válido, e o `realpath` levanta
    # ValueError, que nenhum chamador espera: um pack assim na raiz da pessoa
    # derrubava a `/api/glifos` inteira (a ficha de ícone de TODO pack), com a
    # conexão fechada sem resposta.
    try:
        cheio = os.path.realpath(os.path.join(base, alvo))
    except (TypeError, ValueError):
        raise Recusa(f"{campo}: {alvo!r} não é caminho (NUL ou tipo errado)") from None
    if not cheio.startswith(os.path.realpath(base) + os.sep):
        raise Recusa(f"{campo}: {alvo!r} sai de dentro do pack")
    return cheio


# --- A PALETA ENTRA POR CSV ------------------------
#
# Nenhum leitor do projeto passa a entender CSV. Este bloco o traduz UMA vez
# para o `paleta.json` equivalente, e dali em diante é o JSON que manda — um
# formato de leitura e um de escrita.
#
# `paleta_de_csv` lê o CSV e a régua, e devolve o dicionário: não escreve em
# lugar nenhum.
REFERENCIA_CLARA = "latte"
COLUNAS_CSV = ("slot", "flavor", "hex")
RE_FLAVOR_CSV = re.compile(r"^[a-z0-9]+$")   # ver "O FLAVOR É [a-z0-9]", abaixo
# O nome do claro derivado é o do escuro com `claro` colado.
SUFIXO_DO_CLARO = "claro"

TOLERANCIA_DA_REGUA = 0.95
MINIMO_TEXTO = 7.0     # `text` sobre `base`, WCAG AAA — é onde a pessoa lê
# Abaixo disto o `validar` RECUSA; a régua só avisa. É ESTA constante que o
# `validar` lê: com o 4.5 escrito nos dois lugares, mudar o piso de um deixaria
# o aviso da régua prometendo uma recusa que não vem.
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
            # relativa: reprovado nas duas, ele aparecia duas vezes na
            # lista, e a contagem do aviso dizia uma reprovação a mais do
            # que as que existem.
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
    # O `claros` também: o `validar` cobra a chave e não o tipo, e um `claros:
    # null` levantava TypeError aqui — fora do try do `packs_com_vitrine`,
    # derrubando o /api/packs de TODOS os packs por causa da etiqueta de um
    # só.
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
    # `utf-8-sig` porque é assim que planilha exporta: o Excel
    # põe um BOM no início, e sem isto o cabeçalho lido é "﻿slot" — um
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
    # O Excel em português salva "CSV" com ';', porque a vírgula é o decimal
    # daqui — é o CSV mais provável de chegar.
    dica = ("\n    O separador é a vírgula, e este arquivo usa ';' — é como o Excel em\n"
            "    português salva; o formato pede ','."
            if len(cab) == 1 and ";" in cab[0] else "")
    _exigir(tuple(c.lower() for c in cab) == COLUNAS_CSV,
            f"{nome}:{n_cab}: a primeira linha tem de ser o cabeçalho "
            f"{','.join(COLUNAS_CSV)} — veio {','.join(cab)!r}.\n"
            f"    As colunas são fixas: é o que deixa o erro dizer a linha certa.{dica}")

    erros, flavors, onde, flavor_recusado = [], {}, {}, set()
    for num, cel in corpo[1:]:
        if len(cel) != len(COLUNAS_CSV):
            erros.append(f"{nome}:{num}: {len(cel)} coluna(s) — são três: {','.join(COLUNAS_CSV)}")
            continue
        slot, flavor, hexcor = cel
        if slot not in SLOTS:
            erros.append(f"{nome}:{num}: slot desconhecido {slot!r}. Os 26 nomes estão\n"
                         f"    em docs/PACKS.md, 'As 26 cores', e são minúsculos.")
            continue
        # O nome vai para três lugares que não o aguentam: o '<flavor>-<accent>'
        # do arquivo de tema (a barra vira diretório), o `FLAVOR=` do meow.conf,
        # que o `bin/meow` lê com `.` (o '$(id)' é comando), e o painel, que
        # compara flavor SEM caixa (o `_pack_do_sabor`, em app/servidor.py,
        # baixa os dois lados) enquanto o arquivo de tema é gravado COM caixa —
        # 'Tinta' e 'tinta' seriam um flavor para um e dois para o outro.
        if not RE_FLAVOR_CSV.match(flavor):
            if flavor not in flavor_recusado:
                flavor_recusado.add(flavor)
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
        # MAIÚSCULAS, PORQUE É A FORMA CANÔNICA: as 146 cores com letra das duas
        # paletas versionadas são todas maiúsculas, e o claro derivado sai do
        # `_hexa` assim.
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

    # A história do verbo mora neste arquivo.
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
    # Pela porta geral do `main`, um CSV torto saía "erro pack recusado:
    # cores.csv:1: …", sem pack nenhum envolvido — e quem lê "pack" vai procurar
    # num pack.json.
    try:
        dados = paleta_de_csv(caminho)
        reprovados = regua_de_contraste(dados, _referencia_clara())
    except Recusa as e:
        print(f"  erro o CSV não virou paleta: {e}", file=sys.stderr)
        return RECUSADO
    _noticiar_csv(caminho, dados, reprovados, sys.stderr)
    sys.stdout.write(json.dumps(dados, indent=2, ensure_ascii=False) + "\n")
    return OK


def _noticiar_csv(caminho, dados, reprovados, arq):
    """O que o CSV deu, o claro que se derivou e o que reprovou na régua.

    SAIU DE DENTRO DO `cmd_de_csv` NA SEGUNDA METADE DA P16 [23/09/2026], sem
    mudar uma letra: o `novo --de-csv` e o `importar` de um `.csv` dizem a
    mesma notícia, e três cópias dela discordariam na primeira frase trocada.
    `arq` é o STDERR no `de-csv`, cujo STDOUT é o JSON; nos outros dois, o
    STDOUT, que é onde o resto da saída deles já está.
    """
    derivados = claros_derivados(dados)
    lidos = [f for f in dados["flavors"] if f not in derivados]
    print(f"  ok   {os.path.basename(caminho)}: {len(lidos)} flavor(s), "
          f"26 slots conferidos — {', '.join(lidos)}", file=arq)
    for claro, escuro in derivados.items():
        print(f"  --   {claro}: claro derivado de {escuro!r} pelo método do Latte — "
              f"não é próprio.\n"
              f"       Para ter o seu, traga as 26 linhas dele no CSV.", file=arq)
    # O que não pode é o silêncio: a lista inteira sai, e antes do JSON.
    if reprovados:
        print(f"  aviso {len(reprovados)} abaixo da régua de contraste (docs/PACKS.md) — "
              f"não bloqueia, a decisão é sua:", file=arq)
        for linha in reprovados:
            print(f"          {linha}", file=arq)


def id_do_csv(caminho):
    """O id do pack que um `.csv` solto vira no `importar`: o nome do arquivo.

    O CSV NÃO TEM ONDE DIZER O ID, E O NOME DO ARQUIVO É O QUE A PESSOA ESCOLHEU
    [23/09/2026, P16]. O `.meowpack` traz o id dentro, conferido; as três
    colunas do CSV não têm lugar para ele, e o `novo` o recebe na linha de
    comando. Pela tela não há linha de comando: sobra o nome que ela deu ao
    arquivo, que é também o que ela reconhece na caixa de confirmar. O primeiro
    flavor seria a outra escolha, e pior — as cores do Dracula com o flavor
    `dracula` esbarrariam no pack que já existe, e ela não teria como mudar o
    id sem editar as 26 linhas; um arquivo, ela renomeia.
    O nome vira id do jeito que um nome de arquivo precisa virar: sem acento,
    minúsculo, e o que não for letra ou dígito vira hífen — "Minhas Cores.csv"
    é o pack `minhas-cores`.
    """
    import unicodedata
    base = os.path.splitext(os.path.basename(caminho))[0]
    sem_acento = unicodedata.normalize("NFKD", base).encode("ascii", "ignore").decode("ascii")
    ident = re.sub(r"[^a-z0-9]+", "-", sem_acento.lower()).strip("-")
    _exigir(RE_ID.match(ident),
            f"{os.path.basename(caminho)}: o id do pack sai do nome do arquivo, e deste\n"
            f"    não sai nenhum. Renomeie-o com letras ou dígitos — 'minhas-cores.csv'\n"
            f"    vira o pack minhas-cores.")
    return ident


# --- O LOGO DO PACK --------------------------------
#
# Quem precisa do logo pergunta a `logo()`.
#
# É a regra que o `gerar_icones_autorais.py` cumpre no cabeçalho dele, levada
# para um arquivo que é DADO, e não código: cada forma do logo declara, na
# `class`, o PAPEL que ela cumpre, e o papel resolve para um dos 26 nomes.
#
#       class="fundo"           fill   <- base
#       class="tinta"           fill   <- text
#       class="sujeito"         fill   <- o accent (ACCENT; mauve na falta)
#       class="traco-<papel>"   stroke <- o mesmo papel, no traço
#       class="<um dos 26>"     fill   <- o nome direto, para quem precisar de
#                                         uma quarta cor sem cravar hex
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
RE_ESTILO_PAPEIS = re.compile(
    r"""\s*<style\b[^>]*?\bid\s*=\s*(["'])meow-papeis\1[^>]*?(?:/>|>.*?</style>)""", re.S)
RE_RAIZ_SVG = re.compile(r"<svg\b[^>]*>")
RE_URL_CSS = re.compile(r"""url\(\s*['"]?\s*([^)'"\s]*)""", re.I)
# O ESCAPE DE CSS: `\69` é `i`, `\72` é `r`, e `\x` é `x`. Quem confere o texto
# tem de ler o que o navegador lê.
RE_ESCAPE_CSS = re.compile(r"\\(?:([0-9a-fA-F]{1,6})[ \t\n\r\f]?|(.))", re.S)
XHTML_NS = "{http://www.w3.org/1999/xhtml}"

# O QUE UM LOGO NÃO PODE CARREGAR, e as regras são as que o docs/PACKS.md já
# declara para o pack inteiro ("um pack é dado, nunca é código"), aplicadas ao
# arquivo novo.
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
    try:
        texto = bruto.decode("utf-8")
    except UnicodeDecodeError:
        raise Recusa(f"{nome}: não é texto — é um SVG de verdade, ou uma imagem "
                     f"renomeada?\n    Um PNG com nome de .svg não vira vetor.") from None
    # Nenhum desenho precisa de entidade.
    _exigir("<!ENTITY" not in texto,
            f"{nome}: declara <!ENTITY> — um logo não precisa de entidade, e ela "
            f"pode travar quem o lê")
    try:
        raiz = ET.fromstring(bruto)
    except ET.ParseError as e:
        raise Recusa(f"{nome}: não é XML válido — {e}") from None
    # O `fromstring` joga fora todo `<?...?>`, e o validador nunca via um
    # `<?xml-stylesheet href="https://..."?>` — que o navegador SEGUE, e que o
    # `logo()` devolvia intacto.
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
    # minúscula e o `<SCRIPT>` roda.
    recusados = {k.lower(): v for k, v in ELEMENTOS_RECUSADOS_NO_LOGO.items()}
    for el in raiz.iter():
        nome = str(el.tag).rsplit("}", 1)[-1]
        _exigir(nome.lower() not in recusados,
                f"{arq}: tem <{nome}>, que {recusados.get(nome.lower())}. "
                f"Um pack é dado, nunca código.")
        # HTML DENTRO DO SVG, fora de um `foreignObject` — revisão. Ele não
        # desenha nada ali, mas o navegador CRIA o elemento, e um `<img>` criado
        # busca a imagem mesmo sem aparecer.
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
            # de pasta: depois da cópia, `apps/x.svg` é um caminho quebrado.
            if local == "href":
                _exigir(valor.strip().startswith("#"),
                        f"{arq}: href={valor!r} aponta para fora do arquivo.\n"
                        f"    Só referência interna (#id): o logo é copiado para o tema de\n"
                        f"    ícones, e lá fora nenhum outro caminho existe.")
            # O `href` TAMBÉM MUDA POR ANIMAÇÃO — revisão.
            if local == "attributename":
                _exigir(not valor.strip().lower().endswith("href"),
                        f"{arq}: <{nome} attributeName={valor!r}> troca o destino de um link\n"
                        f"    depois de carregado — é o href apontando para fora por outra porta.")
            textos.append(valor)
        for t in textos:
            # `@IMPORT` passava porque o teste era `"@import" not in t`, e
            # at-rule de CSS não distingue maiúscula; `@\69mport` e `u\72l(`
            # passavam porque o escape só é desfeito pelo navegador.
            plano = _css_sem_escape(t)
            _exigir("@import" not in plano.lower(),
                    f"{arq}: <style> com @import busca folha de fora. Um logo se basta.")
            # Um logo não troca de imagem por densidade de tela; ele é vetor.
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
# A inicial do nome sobre o `base` do pack, com o accent como contorno. É o que
# o `meow pack novo` põe num pack recém-nascido, e é o ponto de partida de quem
# vai desenhar o seu: `pack.py logo-gerado <id> > <pack>/logo.svg`.
#
# `<text>` depende de fonte, e quem desenha ícone de tema no COSMIC é o resvg,
# que só desenha texto quando alguém lhe entrega um banco de fontes.
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

    # Símbolo e espaço na frente não são letra e são pulados (`* Nord` dá `n`);
    # o acento cai na letra base pela decomposição (`Árvore` dá `a`).
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


# Até aqui um pack era um `id` e 26 hexadecimais. A tela que escolhe um pack não
# tinha o que desenhar, e ninguém escolhe um tema por um `id`.
#
# Um `vitrine.logo` ao lado seriam duas verdades para a mesma figura, e a
# segunda envelhece calada.
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
        # O caminho declarado passa pelo `_dentro` e é aberto, não só olhado.
        #
        # Um pack que promete a capa e não entrega é o pack que "promete e não
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

    # A varredura de URLs do `validar` só olha texto que tenha `://` — e
    # `javascript:alert(1)` não tem.
    site = v.get("site")
    if site is not None:
        if isinstance(site, str) and site.startswith("https://"):
            saida["site"] = site
        else:
            problemas.append(f"vitrine.site: {site!r} — só https:// vira link no cartão")
    return saida, problemas


# O docs/PACKS.md pede, para publicar, "nenhum nome de usuário", e nada o
# cobrava.
#
# `~/` PASSA, E É DE PROPÓSITO: diz "a casa de quem estiver lendo" sem dizer de
# quem — é como a linha `origem:` do `captura.txt` escreve, e como a coluna
# "lido de" do PROCEDENCIA.md do Dracula escrevia.
RE_CASA_DE_ALGUEM = re.compile(r"/(?:home|Users)/[\w.-]+/")


def nomes_de_usuario(dir_pack):
    """Cada linha de texto do pack com a casa de alguém escrita por extenso.

    Uma entrada por linha, `arquivo:linha: trecho`, e TODAS de uma vez — como os
    slots que faltam: consertar uma por rodada é o que faz alguém desistir. A
    linha é contada por `\\n`, como o editor e o `grep -n` contam.
    """
    achados = []
    arquivos, _ocultos, _problemas = _arquivos_do_pack(dir_pack)
    for rel in arquivos:
        with open(os.path.join(dir_pack, rel), "rb") as fh:
            dado = fh.read()
        if b"\0" in dado[:8000]:
            continue
        for num, linha in enumerate(dado.decode("utf-8", "replace").split("\n"), 1):
            m = RE_CASA_DE_ALGUEM.search(linha)
            if m:
                achados.append(f"{rel}:{num}: {m.group(0)}")
    return achados


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
    except UnicodeDecodeError as e:
        raise Recusa(f"pack.json não é UTF-8 (byte {e.object[e.start]:#04x} na posição {e.start})")

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

    if p.get("papel") is not None:
        return _validar_base(p, dir_pack, silencioso)

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
    except UnicodeDecodeError as e:
        raise Recusa(f"{arq}: não é UTF-8 (byte {e.object[e.start]:#04x} na posição {e.start})")

    # Os dois arquivos, chave e valor, a fundo: C0 (o `\n` e o `\t` inclusive),
    # DEL e C1. Nenhum pack publicado tem um (conferido nos três).
    for nome_arq, doc in (("pack.json", p), (arq, dados)):
        ruim = _caractere_de_controle(doc)
        _exigir(ruim is None,
                f"{nome_arq}: {ruim} tem caractere de controle — texto de pack é uma\n"
                f"    linha de letras; o terminal e o tema dos aplicativos o leriam como comando")

    for campo in ("flavors", "nomes", "claros"):
        _exigir(campo in dados, f"{arq}: falta o campo {campo!r}")
    _exigir(isinstance(dados["flavors"], dict) and dados["flavors"],
            f"{arq}: 'flavors' está vazio")

    # O gerador monta o arquivo de tema como "<flavor>-<accent>" e o leitor
    # corta no hífen.
    for flavor in dados["flavors"]:
        _exigir("-" not in flavor,
                f"{arq}: o flavor {flavor!r} tem hífen no nome.\n"
                f"    O tema é gravado como '<flavor>-<accent>', e o hífen parte\n"
                f"    o nome no lugar errado. Use uma palavra só: o Catppuccin\n"
                f"    faz 'latte'/'mocha', e o Dracula claro daqui é 'alucard'.")

    # O nome do flavor vira `FLAVOR=` no meow.conf, e dali caminho de pasta e
    # de traço: o `meow_flavor` (lib/comum.sh) o devolve cru. O hífen era a
    # única recusa, e um `..` ou um `a/b` passavam.
    for campo in ("flavors", "claros"):
        nomes = dados[campo] if isinstance(dados[campo], (dict, list)) else []
        for flavor in nomes:
            _exigir(isinstance(flavor, str) and RE_FLAVOR_CONF.match(flavor),
                    f"{arq}: o nome {flavor!r} em {campo!r} não é um nome de flavor.\n"
                    f"    Ele vira caminho de pasta e linha do meow.conf: use só\n"
                    f"    letras minúsculas, algarismos e '_' (como 'latte' ou 'alucard').")

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
    # Eram `apps` e `pastas`.
    #
    # `mapa` E `desenhos` NAS QUATRO, e não um par diferente para cada: a forma
    # de `packs/<id>/icones/` é a MESMA para toda categoria e para todo pack.
    for cat, chaves in (("apps", ("mapa", "desenhos")),
                        ("pastas", ("mapa", "desenhos")),
                        ("mimetypes", ("mapa", "desenhos")),
                        ("autorais", ("mapa", "desenhos")),
                        ("resgatados", ("mapa", "desenhos"))):
        bloco = ic.get(cat) or {}
        for chave in chaves:
            if bloco.get(chave):
                alvo = _dentro(dir_pack, bloco[chave], f"icones.{cat}.{chave}")
                _exigir(os.path.exists(alvo),
                        f"icones.{cat}.{chave}: {bloco[chave]!r} não existe no pack")
    # A LISTA DO LANÇADOR: ids de `.desktop`, e só eles — eles viram nome
    # de arquivo em /usr/share/applications, pela ponte root.
    oc = (p.get("lancador") or {}).get("ocultar") if isinstance(p.get("lancador"), dict) else None
    if p.get("lancador") is not None:
        _exigir(isinstance(p.get("lancador"), dict) and isinstance(oc, list)
                and all(isinstance(n, str) and RE_DESKTOP_ID.match(n) for n in oc),
                "lancador.ocultar: uma lista de ids de `.desktop` (letras, dígitos, '.', '_' e '-'),\n"
                "    sem '/' e sem a extensão — viram nome de arquivo do sistema.")
    # OS ÍCONES DE ARQUIVO DERIVADOS: de qual pack e de qual pasta do acervo
    # dele. A pasta é um nome só, pela régua das pastas de pacote, e o `derivar`
    # precisa dos `desenhos` ao lado — é onde a derivação escreve.
    der = (ic.get("mimetypes") or {}).get("derivar")
    if der is not None:
        _exigir(isinstance(der, dict) and isinstance(der.get("de"), str) and der.get("de")
                and isinstance(der.get("pasta"), str) and RE_PASTA_PACOTE.match(der["pasta"])
                and "/" not in der["pasta"] and (ic.get("mimetypes") or {}).get("desenhos"),
                "icones.mimetypes.derivar: {\"de\": \"<id do pack>\", \"pasta\": \"<pasta do acervo dele>\"},\n"
                "    ao lado de `desenhos`, que é onde a derivação escreve.")

    # Um pack com `waterfox : ~/.local/share/icons/Dracula-Icones/...` saía 0: a
    # linha só virava problema dentro do instalador, na máquina de quem
    # instalou, e como aviso de "desenho ausente" — nunca como "este mapa aponta
    # para a máquina".
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

    # Um pack de formato 2 guarda o ícone em `icones/apps/`, `icones/sistema/`
    # e `icones/biblioteca/`, e só nelas; o flavor e a etiqueta são subpasta de
    # uma das três.
    if not silencioso:
        _tres_pastas(p, dir_pack)

    # `icones/biblioteca/` é a coleção de onde se escolhe o próximo desenho de
    # aplicativo (ver `PASTA_BIBLIOTECA`, lá embaixo).
    #
    # SÓ NA PORTA DE QUEM PUBLICA, pelo motivo do "ALVO AUSENTE" acima: um pack
    # recusado no motor é ignorado inteiro, e um arquivo solto numa pasta que
    # nada instala não pode trocar o tema de ninguém.
    pasta_bib = os.path.join(dir_pack, PASTA_BIBLIOTECA)
    if not silencioso and os.path.lexists(pasta_bib.rstrip("/")):
        _exigir(os.path.isdir(pasta_bib) and not os.path.islink(pasta_bib.rstrip("/")),
                f"{PASTA_BIBLIOTECA}: precisa ser uma pasta do pack, e não um arquivo ou link")
        fora_da_forma = []
        for raiz_b, dirs, arqs in os.walk(pasta_bib):
            rel_b = os.path.relpath(raiz_b, pasta_bib)
            for dname in sorted(dirs):
                if os.path.islink(os.path.join(raiz_b, dname)):
                    fora_da_forma.append(os.path.normpath(os.path.join(rel_b, dname)))
            dirs[:] = sorted(d for d in dirs if not d.startswith(".")
                             and not os.path.islink(os.path.join(raiz_b, d)))
            for a in sorted(arqs):
                cheio = os.path.join(raiz_b, a)
                if a.startswith("."):
                    continue
                # O CATÁLOGO É O ÚNICO QUE NÃO É DESENHO. É dado sobre os
                # desenhos (descrição em português e etiquetas, um por arquivo),
                # e a busca da ficha de ícone o lê ao lado deles.
                if a == "catalog.json" and os.path.isfile(cheio) and not os.path.islink(cheio):
                    continue
                if not a.endswith(EXT_DA_BIBLIOTECA) or os.path.islink(cheio) \
                        or not os.path.isfile(cheio):
                    fora_da_forma.append(os.path.normpath(os.path.join(rel_b, a)))
        _exigir(not fora_da_forma,
                f"{PASTA_BIBLIOTECA}: {len(fora_da_forma)} entrada(s) que não são desenho "
                f"(.svg ou .png comum, sem link):\n      " + "\n      ".join(fora_da_forma))

    # Os `.json` da pasta `icones.autorais.desenhos` viraram a entrada do
    # gerador: um terceiro desenho entra copiando um arquivo, sem tocar em
    # Python. As regras são as do `ler_autoral`, e só ele as conhece.
    #
    # A PASTA É A MESMA QUE O GERADOR LÊ: a declarada ou, sem `desenhos`, a
    # `PASTA_AUTORAIS`.
    pasta_aut = dir_acervo("icones.autorais.desenhos", ref=dir_pack, padrao=PASTA_AUTORAIS)
    if os.path.isdir(pasta_aut):
        for arq in sorted(os.listdir(pasta_aut)):
            if arq.endswith(".json") and arq != CATALOGO:
                ler_autoral(os.path.join(pasta_aut, arq))

    if (p.get("cosmic") or {}).get("mapa"):
        alvo = _dentro(dir_pack, p["cosmic"]["mapa"], "cosmic.mapa")
        _exigir(os.path.isfile(alvo), f"cosmic.mapa: {p['cosmic']['mapa']!r} não existe")

    # Um validador que aprova um pack que promete um arquivo que não entrega não
    # está validando o formato: está carimbando.
    #
    # Os outros quatro — `paleta.arquivo`, `icones.*.mapa`, `icones.*.desenhos`
    # e `cosmic.mapa` — já são cobrados acima.
    if p.get("creditos"):
        alvo = _dentro(dir_pack, p["creditos"], "creditos")
        _exigir(os.path.isfile(alvo),
                f"creditos: {p['creditos']!r} está declarado e NÃO existe no pack.\n"
                f"    Ou crie o arquivo, ou tire o campo. Um pack que promete\n"
                f"    crédito de arte e não entrega ensina a promessa vazia —\n"
                f"    e quem copiar este pack.json vai repetir a promessa.")

    # --- apps ---------------------------------------------------------------
    # As trilhas não colidem, mas quem lê o pack.json de cima para baixo
    # colide.
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
            # O SHA VEM DO PACK, E NÃO DO MÓDULO
            _exigir(medido == str(soma_app).lower(),
                    f"apps.{nome_app}.sha256 não confere com o arquivo.\n"
                    f"    declarado: {soma_app}\n"
                    f"    medido   : {medido}")

    # --- o ponteiro e as fontes ---------------------
    # Os dois são campos de arquivo, e entram na vizinhança do `creditos` e do
    # `apps.*.arquivo` pelo motivo que aqueles dois já contam: o pack que
    # promete e não entrega só falharia dentro do instalador, na máquina de quem
    # instalou.
    _conferir_papeis(p)
    cur = (p.get("origens") or {}).get("cursores")
    if isinstance(cur, dict) and "proprio" in cur:
        prop = cur["proprio"]
        _exigir(isinstance(prop, str) and prop,
                "origens.cursores.proprio: precisa ser o caminho de um tema dentro do pack —\n"
                "    por convenção, cursores/<nome>/")
        _exigir(not cur.get("herda"),
                "origens.cursores: 'proprio' e 'herda' ao mesmo tempo. Ou o pack traz o\n"
                "    ponteiro, ou herda o de outro — os dois juntos não dizem qual.")
        tema = _dentro(dir_pack, prop, CATEGORIA_PONTEIRO)
        _exigir(os.path.isdir(tema),
                f"origens.cursores.proprio: {prop!r} está declarado e NÃO existe no pack.\n"
                f"    Ou crie o tema, ou tire o campo.")
        conferir_ponteiro(tema)

    # A origem pinada é conferida aqui pela FORMA (https, sha256, a pasta sem
    # `..`); o conteúdo, quem confere é o shell, byte a byte, na hora de
    # instalar — o `validar` não toca a rede.
    if isinstance(cur, dict) and "origem" in cur:
        _exigir("proprio" not in cur and not cur.get("herda"),
                "origens.cursores: `origem` vem sozinha. Ou o pack baixa o ponteiro, ou o\n"
                "    traz dentro dele (`proprio`), ou herda o de outro (`herda`).")
        origem_pinada(cur["origem"], "origens.cursores.origem", com_nome=True)
    # O mascote de fábrica vira `LOGO_DIA=`/`LOGO_NOITE=` no meow.conf, que o
    # bash lê com `source`: só nome, sem aspas nem `$(`.
    masc = p.get("mascote")
    for fase in ("dia", "noite"):
        if isinstance(masc, dict) and fase in masc:
            _exigir(isinstance(masc[fase], str) and RE_NOME_MASCOTE.match(masc[fase]),
                    f"mascote.{fase}: {masc[fase]!r} não é nome de mascote.\n"
                    f"    Use o nome do .svg sem a extensão: letras, algarismos, '.', '_' e '-'.")
    base = ic.get("base")
    if base is not None:
        _exigir(isinstance(base, dict),
                "icones.base: precisa ser um objeto — {\"origem\": {…}} ou {\"herda\": \"<id>\"}")
        _exigir(not ("origem" in base and base.get("herda")),
                "icones.base: 'origem' e 'herda' ao mesmo tempo. Ou o pack traz a base, ou\n"
                "    herda a de outro — as duas juntas não dizem qual.")
        if "origem" in base:
            origem_pinada(base["origem"], CATEGORIA_BASE + ".origem")
        # AS CAMADAS DE TRÁS: cada uma é uma origem pinada como a da frente,
        # e só existem atrás de uma frente — sem a `origem`, "por trás" de
        # quê?
        if "por_tras" in base:
            atras = base["por_tras"]
            _exigir("origem" in base and isinstance(atras, list) and atras,
                    "icones.base.por_tras: uma lista não vazia, e só ao lado de uma `origem` —\n"
                    "    são as camadas que ficam ATRÁS da base que o pack traz.")
            for i, camada in enumerate(atras):
                trilha = f"{CATEGORIA_BASE}.por_tras[{i}]"
                _exigir(isinstance(camada, dict)
                        and {k for k in camada if not str(k).startswith("_")} == {"origem"},
                        f"{trilha}: um objeto com a `origem` e só ela — {{\"origem\": {{…}}}}")
                origem_pinada(camada["origem"], trilha + ".origem")

    fo = p.get(CATEGORIA_FONTES)
    if fo is not None:
        _exigir(isinstance(fo, dict),
                "pack.json: 'fontes' precisa ser um objeto — {\"proprio\": [...]} ou {\"herda\": \"<id>\"}")
        _exigir(not ("proprio" in fo and fo.get("herda")),
                "fontes: 'proprio' e 'herda' ao mesmo tempo. Ou o pack traz as fontes, ou\n"
                "    herda as de outro — a lista de um não se soma à do outro.")
        if "proprio" in fo:
            _fontes_declaradas(dir_pack, fo["proprio"])

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
        # O TEMA DE SOM não é timbre: é o diretório de um tema de som
        # freedesktop dentro do pack, com o `index.theme` dele.
        if chave == "tema":
            alvo = _dentro(dir_pack, valor if isinstance(valor, str) else "", "som.tema")
            _exigir(os.path.isfile(os.path.join(alvo, "index.theme")),
                    f"pack.json: som.tema = {valor!r} precisa ser uma pasta do pack com um index.theme")
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
    # `fontes` entrou pelo mesmo motivo: o `tipografia` lê o `fontes.herda` como
    # o `acervo` lê o `icones.*.herda`.
    for cat, bloco in (list(ic.items()) + list((p.get("origens") or {}).items())
                       + list((p.get("apps") or {}).items())
                       + [(CATEGORIA_FONTES, p.get(CATEGORIA_FONTES))]):
        if isinstance(bloco, dict) and bloco.get("herda"):
            herancas.append(bloco["herda"])
    for h in set(herancas):
        # O `or eh_embutido(h)` SAIU, e com ele a última exceção: `catppuccin`
        # agora é um diretório com pack.json como qualquer outro, e o `achar` o
        # encontra pelas mesmas três raízes. Ver `PACK_PADRAO`.
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
    # derivado.
    if not silencioso and "derivados" in dados:
        bons = claros_derivados(dados)
        deriv = dados["derivados"]
        tortos = sorted(set(deriv) - set(bons)) if isinstance(deriv, dict) else ["(não é um objeto)"]
        _exigir(not tortos,
                f"{arq}: 'derivados' é {{claro: escuro de onde ele saiu}} — o claro\n"
                f"    listado em 'claros', o escuro em 'flavors'. Não confere: "
                f"{', '.join(map(str, tortos))}")

    # --- o nome de quem escreveu ---------------------------
    # Só na porta de quem publica; o porquê está em `nomes_de_usuario`, acima.
    if not silencioso:
        casas = nomes_de_usuario(dir_pack)
        _exigir(not casas,
                f"{len(casas)} linha(s) com a casa de alguém escrita por extenso — o pack\n"
                f"    viaja, e o nome de usuário iria junto. Escreva ~/ no lugar dela, que\n"
                f"    diz o mesmo sem dizer de quem:\n      " + "\n      ".join(casas))

    # --- vitrine ------------------------------------------------------------
    # Só na porta de quem PUBLICA — ver `vitrine`, acima, "ELA É COBRADA DE QUEM
    # PUBLICA".
    #
    # ANTES DO LOGO, E DE PROPÓSITO: o logo é o arquivo que `vitrine.capa`
    # nomeia, e é a vitrine que confere o CAMPO — um `.svg`, dentro do pack,
    # existindo.
    if not silencioso:
        _, problemas = vitrine(p, dir_pack)
        _exigir(not problemas, "\n  erro ".join(problemas))

    # --- o logo -------------------------------------------------------------
    # POR ÚLTIMO, E DE PROPÓSITO: um pack de formato errado ou paleta quebrada
    # deve ouvir primeiro sobre isso, que é o que impede qualquer tela de sair.
    #
    # SÓ NA PORTA DE QUEM PUBLICA — revisão.
    if not silencioso:
        _validar_logo(dir_pack, p)

    if not silencioso:
        mortos = campos_sem_leitor(p)
        if mortos:
            print(f"  aviso {len(mortos)} campo(s) que este pack declara e NENHUM código lê:",
                  file=sys.stderr)
            for trilha in mortos:
                print(f"          {trilha}", file=sys.stderr)
            # O docs/PACKS.md descreve cada CAMPO, e é para isso que ele serve
            # aqui.
            print("        Eles não quebram nada — e também não fazem nada: "
                  "nenhuma linha deste projeto os consulta.\n"
                  "        O que cada campo deveria significar está em docs/PACKS.md.",
                  file=sys.stderr)
        n_fl = len(dados["flavors"])
        print(f"  ok   {p['nome']} ({p['id']}) — formato {p['formato']}, "
              f"{n_fl} flavor(s), 26 slots conferidos")
    return p, dados, dir_pack


# Ele não tem paleta nem logo e não se veste: a porta do motor (`silencioso`, a
# sonda do `meow_pack_dir` e do `usar`) o recusa, e a de quem publica confere
# só o que ele tem, os ícones.
PAPEL_BASE = "base"


def eh_base(ref):
    """True quando `ref` é o pack-base (o `papel: "base"` do pack.json)."""
    return campo(ref, "papel") == PAPEL_BASE


def _tres_pastas(p, dir_pack):
    """Recusa a quarta pasta em `icones/` de um pack de formato 2."""
    if not isinstance(p.get("formato"), int) or p["formato"] < 2:
        return
    pasta = os.path.join(dir_pack, "icones")
    if not os.path.isdir(pasta):
        return
    a_mais = sorted(d for d in os.listdir(pasta) if d not in PASTAS_DO_FORMATO
                    and (os.path.isdir(os.path.join(pasta, d)) or os.path.islink(os.path.join(pasta, d))))
    _exigir(not a_mais,
            f"icones/: {', '.join(a_mais)} — no formato {p['formato']} o ícone mora em\n"
            f"    apps/ (ligado a um programa), sistema/ (pasta, tipo de arquivo, status)\n"
            f"    ou biblioteca/ (o resto, para escolher). Mova a pasta para dentro de uma delas.")
    # P96 (23/10/2026): as três são planas. Flavor e origem são sufixo no nome e linha no
    # PROCEDENCIA.md, nunca subpasta.
    dentro = sorted(f"{t}/{d}" for t in PASTAS_DO_FORMATO if os.path.isdir(os.path.join(pasta, t))
                    for d in os.listdir(os.path.join(pasta, t))
                    if os.path.isdir(os.path.join(pasta, t, d)))
    _exigir(not dentro,
            f"icones/: {', '.join(dentro)} — as três pastas não têm subpasta. O flavor vai no\n"
            f"    nome (`desenho-mocha.svg`) e a origem no PROCEDENCIA.md; ponha os arquivos direto\n"
            f"    em apps/, sistema/ ou biblioteca/.")


def _conferir_papeis(p):
    """`origens.wallpapers.*_do_conf` só nomeia chave `WALLPAPER_*_REPO`/`_COMMIT`."""
    wp = (p.get("origens") or {}).get("wallpapers")
    if not isinstance(wp, dict):
        return
    for chave, regra in RE_CONF_PAPEL.items():
        if chave in wp:
            _exigir(isinstance(wp[chave], str) and regra.match(wp[chave]),
                    f"origens.wallpapers.{chave}: {wp[chave]!r} não é uma chave "
                    f"{regra.pattern[1:-1].replace('[A-Z0-9_]*', '*')} do meow.conf")


def _validar_base(p, dir_pack, silencioso):
    _exigir(p["papel"] == PAPEL_BASE,
            f"pack.json: papel {p['papel']!r} — o único que existe é {PAPEL_BASE!r}")
    _exigir(not silencioso,
            f"{p['id']!r} é o pack-base: todo pack herda dele, e ele não se veste sozinho")
    for chave in ("paleta", "heranca"):
        _exigir(chave not in p,
                f"pack.json: o pack-base não tem {chave!r} — ele é a última camada")
    ic = p.get("icones") or {}
    for cat, bloco in ic.items():
        if str(cat).startswith("_") or not isinstance(bloco, dict):
            continue
        for chave in ("mapa", "desenhos"):
            if bloco.get(chave):
                alvo = _dentro(dir_pack, bloco[chave], f"icones.{cat}.{chave}")
                _exigir(os.path.exists(alvo),
                        f"icones.{cat}.{chave}: {bloco[chave]!r} não existe no pack")
    if p.get("creditos"):
        _exigir(os.path.isfile(_dentro(dir_pack, p["creditos"], "creditos")),
                f"creditos: {p['creditos']!r} está declarado e NÃO existe no pack")
    _tres_pastas(p, dir_pack)
    _conferir_papeis(p)
    casas = nomes_de_usuario(dir_pack)
    _exigir(not casas,
            f"{len(casas)} linha(s) com a casa de alguém escrita por extenso:\n      "
            + "\n      ".join(casas))
    print(f"  ok   {p['nome']} ({p['id']}) — formato {p['formato']}, pack-base: só acervo")
    return p, {"flavors": {}, "nomes": {}, "claros": []}, dir_pack


# Até aqui não havia como saber o tamanho de um pack sem `find`. O `meow pack
# info` dizia de ONDE vem cada categoria — próprio, herdado, do motor — e não
# dizia QUANTO vem.
#
# Com a contagem ao lado, `PRÓPRIO` com `0 desenho(s)` conta a história
# inteira.
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
        svgs += [os.path.join(base, a) for a in arquivos if a.endswith(".svg")]
    # P96: as três pastas são planas e as categorias dividem a pasta; cada uma conta o que é dela.
    cat = categoria.rsplit(".", 1)[-1]
    if cat == "mimetypes":
        def do_molde(c):
            try:
                with open(c, encoding="utf-8") as fh:
                    return bool(RE_VAR_CTP.search(fh.read()))
            except (OSError, UnicodeDecodeError):
                return False
        svgs = [c for c in svgs if do_molde(c)]
    elif cat == "autorais":
        svgs = [c for c in svgs if any(os.path.basename(c).endswith(f"-{f}.svg") for f in flavors)]
    elif cat == "pastas":
        mapa = acervo(categoria + ".mapa", ref=ref)
        if mapa and os.path.isfile(mapa):
            glifos = set()
            for linha in open(mapa, encoding="utf-8"):
                linha = linha.split("#", 1)[0].strip()
                if ":" in linha:
                    glifos.add(linha.split(":", 1)[1].strip() + ".svg")
            svgs = [c for c in svgs if os.path.basename(c) in glifos]
    svgs = [os.path.basename(c) for c in svgs]
    # Os autorais nascem como `<nome>-<flavor>.svg`.
    achados = {f for f in flavors for a in svgs if a.endswith(f"-{f}.svg")}
    quantos = f"{len(svgs):,} desenho(s)".replace(",", ".")
    return quantos, (f"{len(achados)} flavor(s)" if achados else "")


# Estavam 11 de 295: o pack guardava só o desenho que já vestia alguém, e o
# resto da coleção — de onde a pessoa escolhe o próximo — morava num repositório
# que só existe numa máquina.
#
# SEM CAMPO NO pack.json, E É DE PROPÓSITO: nada INSTALA a biblioteca.
PASTA_BIBLIOTECA = "icones/biblioteca/"
EXT_DA_BIBLIOTECA = (".svg", ".png")


# Independente do app que eu escolher, eu deveria acessar todas as imagens
# disponíveis.»
#
# Uma lista no servidor é a quinta cópia de "onde moram os desenhos": o
# `tests/acervo-da-ficha.sh` conta o disco contra ESTA função, e o servidor
# pergunta a ela.
PASTA_FEITOS_A_MAO = "icones/biblioteca/feitos-a-mao/"
# Num pack de formato 2 os grupos são `apps/` e `biblioteca/` (planas; a subpasta
# que um pack de antes da P96 ainda tenha vira um grupo), e o PNG da mesma pasta
# num grupo à parte.
PASTAS_DA_FICHA = ("icones/apps/", PASTA_BIBLIOTECA)
ROTULO_DA_PASTA = {"icones/apps": "feitos para apps", "icones/biblioteca": "biblioteca",
                   "arcticons": "traço", "feitos-a-mao": "feitos à mão",
                   "versoes": "versões", "projetos": "projetos dela"}
FORA_DA_FICHA = ("ANTES-E-DEPOIS.png",)
RE_NOME_NA_FICHA = re.compile(r"^[^#:\x00-\x1f]{1,200}$")


# O «Adicionar ícone» do painel gravava em `assets/icones/overrides/`, dentro do
# clone: usar o produto virava arquivo por commitar, e a pasta nem estava aqui,
# então o desenho não aparecia para ser escolhido.
def pasta_de_enviados():
    """`~/.local/share/meowsystem/icones-enviados/` (exista ou não)."""
    return os.path.join(os.path.dirname(raiz_da_pessoa()), "icones-enviados")


def _arquivos_da_pasta(pasta, ext):
    """Os arquivos comuns de `pasta` (sem descer), com a extensão `ext`."""
    try:
        nomes = sorted(os.listdir(pasta))
    except OSError:
        return []
    saida = []
    dentro = os.path.realpath(pasta) + os.sep
    for nome in nomes:
        cheio = os.path.join(pasta, nome)
        if (nome.startswith(".") or not nome.lower().endswith(ext) or nome in FORA_DA_FICHA
                or not RE_NOME_NA_FICHA.match(nome) or os.path.islink(cheio)
                or not os.path.isfile(cheio)
                or not os.path.realpath(cheio).startswith(dentro)):
            continue
        saida.append(cheio)
    return saida


def acervos_de_icone(no_ar=""):
    """Cada pasta de desenho que a ficha de ícone oferece, na ordem da tela.

    Um dicionário por grupo: `id`, `acervo` (o nome do pack, ou «MeowSystem»),
    `nome` (a pasta, como a tela a chama), `pack` (o id, ou ''), `no_ar`,
    `tipo` (`desenho`, `traco` ou `png`), `pasta` e `arquivos` (os caminhos).
    O pack `no_ar` vem primeiro, depois os outros packs, e o pack-base (o
    acervo do motor) por último entre eles.
    """
    grupos = []

    def grupo(gid, acervo, nome, pack, tipo, pasta, arquivos):
        if arquivos:
            grupos.append({"id": gid, "acervo": acervo, "nome": nome, "pack": pack,
                           "no_ar": bool(pack) and pack == no_ar, "tipo": tipo,
                           "pasta": pasta, "arquivos": arquivos})

    vistos = set()
    for base in raizes():
        try:
            ids = sorted(os.listdir(base))
        except OSError:
            continue
        for pid in ids:
            dir_pack = os.path.join(base, pid)
            if pid in vistos or not os.path.isfile(os.path.join(dir_pack, "pack.json")):
                continue
            vistos.add(pid)
            nome_pack = str(campo(dir_pack, "nome", pid) or pid)
            # SÓ O QUE O PRÓPRIO PACK TRAZ: a herança não sobe aqui, porque o
            # acervo herdado já aparece na pasta do pack de onde ele vem.
            aut = campo(dir_pack, "icones.autorais.desenhos") \
                or padrao_do_formato(dir_pack, PASTA_AUTORAIS)
            formato = campo(dir_pack, "formato", 1)
            if isinstance(formato, int) and formato >= 2:
                _grupos_das_tres_pastas(grupo, pid, nome_pack, dir_pack, aut)
            else:
                _grupos_de_antes(grupo, pid, nome_pack, dir_pack)
            # OS AUTORAIS DE TODOS OS FLAVORS, COM O FLAVOR COMO SUBGRUPO.
            try:
                pasta_aut = _dentro(dir_pack, aut, "icones.autorais.desenhos")
            except Recusa:
                continue
            arquivos = _arquivos_da_pasta(pasta_aut, ".svg")
            flavors = sorted(_flavors_do_pack(dir_pack), key=len, reverse=True)
            por_flavor = {}
            for arq in arquivos:
                miolo = os.path.basename(arq)[:-len(".svg")]
                flavor = next((f for f in flavors if miolo.endswith("-" + f)), "")
                por_flavor.setdefault(flavor, []).append(arq)
            for flavor in sorted(por_flavor):
                if not flavor and os.path.realpath(pasta_aut) == os.path.realpath(os.path.join(dir_pack, "icones", "apps")):
                    continue        # P96: em apps/ plana, autoral é só o que tem o flavor no nome
                grupo("pack:%s:autorais:%s" % (pid, flavor or "-"), nome_pack,
                      "autorais · %s" % flavor if flavor else "autorais", pid, "desenho",
                      pasta_aut, por_flavor[flavor])
    # Os enviados pelo painel, depois dos packs.
    enviados = pasta_de_enviados()
    grupo("casa:enviados", "Seus", "enviados", "", "desenho", enviados,
          _arquivos_da_pasta(enviados, ".svg"))
    # O PACK NO AR PRIMEIRO, o pack-base (o acervo do motor) por último entre os
    # packs, e a ordem de dentro de cada lado fica a de cima.
    return sorted(grupos, key=lambda g: (not g["no_ar"], not g["pack"], g["pack"] == PACK_BASE))


def _grupos_de_antes(grupo, pid, nome_pack, dir_pack):
    """Os grupos de um pack de formato 1: as pastas declaradas e as de convenção."""
    pastas = []
    for cat, chave, nome in (("icones.apps.desenhos", "apps", "feitos para apps"),
                             (CATEGORIA_RESGATADOS + ".desenhos", "resgatados", "resgatados")):
        declarada = campo(dir_pack, cat)
        if isinstance(declarada, str) and declarada:
            try:
                pastas.append((chave, nome, _dentro(dir_pack, declarada, cat), "desenho", ".svg"))
            except Recusa:
                pass
    # As duas pastas são convenção, sem campo no pack.json, e por isso entravam
    # pelo `join` cru: uma `icones/biblioteca` que fosse symlink para fora punha
    # na ficha (e na `/previa`) o que estivesse lá.
    feitos = padrao_do_formato(dir_pack, PASTA_FEITOS_A_MAO)
    for chave, nome, rel, tipo, ext in (
            ("biblioteca", "biblioteca", PASTA_BIBLIOTECA, "desenho", ".svg"),
            # A decisão 2: cada PNG ganha um `.svg` ao lado, conferido por RMSE,
            # e o PNG sai quando o vetor passa.
            ("feitos-a-mao", "feitos à mão", feitos, "desenho", ".svg"),
            ("feitos-a-mao-png", "feitos à mão (PNG)", feitos, "png", ".png")):
        try:
            pastas.append((chave, nome, _dentro(dir_pack, rel, chave), tipo, ext))
        except Recusa:
            pass
    for chave, nome, pasta, tipo, ext in pastas:
        grupo("pack:%s:%s" % (pid, chave), nome_pack, nome, pid, tipo, pasta,
              _arquivos_da_pasta(pasta, ext))


def _grupos_das_tres_pastas(grupo, pid, nome_pack, dir_pack, aut):
    """Os grupos de `apps/` e `biblioteca/` de um pack de formato 2 (P88)."""
    traco = campo(dir_pack, "icones.apps.recolorir") is True
    try:
        real_aut = _dentro(dir_pack, aut, "icones.autorais.desenhos")
    except Recusa:
        real_aut = ""
    for rel_raiz in PASTAS_DA_FICHA:
        # A pasta passa pelo `_dentro`, como a declarada: uma que seja link
        # para fora do pack fica de fora, calada.
        try:
            raiz = _dentro(dir_pack, rel_raiz, rel_raiz)
        except Recusa:
            continue
        for dirpath, dirs, _nomes in os.walk(raiz):
            dirs[:] = sorted(d for d in dirs if not d.startswith(".")
                             and not os.path.islink(os.path.join(dirpath, d))
                             and os.path.join(dirpath, d) != real_aut)
            rel = os.path.relpath(dirpath, dir_pack)
            partes = rel.split(os.sep)[2:]
            nome = " · ".join([ROTULO_DA_PASTA.get(p, p) for p in partes]) \
                or ROTULO_DA_PASTA.get(os.path.dirname(rel_raiz), rel_raiz)
            gid = "pack:%s:%s" % (pid, "/".join(rel.split(os.sep)[1:]))
            tipo = "traco" if traco and rel_raiz == "icones/apps/" else "desenho"
            svgs = _arquivos_da_pasta(dirpath, ".svg")
            if real_aut and os.path.realpath(dirpath) == os.path.realpath(real_aut):
                # P96: os autorais moram em apps/ (plana); eles têm o grupo deles, por flavor
                flavors = _flavors_do_pack(dir_pack)
                svgs = [a for a in svgs
                        if not any(os.path.basename(a)[:-4].endswith("-" + f) for f in flavors)]
            grupo(gid, nome_pack, nome, pid, tipo, dirpath, svgs)
            # O PNG que ainda não virou vetor é visto e travado, num grupo à
            # parte da mesma pasta (raster não é fonte; ver o `feitos-a-mao-png`).
            grupo(gid + ":png", nome_pack, nome + " (PNG)", pid, "png", dirpath,
                  _arquivos_da_pasta(dirpath, ".png"))


def _contar_biblioteca(ref, dir_pack):
    """(nomes no mapa de aplicativos, desenhos da biblioteca que nenhum veste).

    None quando o pack não tem biblioteca — o `info` mostra a contagem de
    sempre. Só a biblioteca do PRÓPRIO pack: ela não sobe pela herança, porque
    nada a instala; o mapa, sim, é o que vale para o pack (o `acervo`).
    """
    bib = os.path.join(dir_pack, PASTA_BIBLIOTECA)
    if not os.path.isdir(bib):
        return None
    mapa = acervo("icones.apps.mapa", ref=ref)
    nomes, vestidos = set(), set()
    if mapa:
        base = os.path.dirname(mapa)
        for _num, nome, alvo in ler_mapa(mapa):
            nomes.add(nome)
            try:
                caminho = resolver_alvo(alvo, base)
            except Recusa:
                continue
            if os.path.isfile(caminho):
                vestidos.add(_sha(caminho))
    soltos = 0
    for a in os.listdir(bib):
        caminho = os.path.join(bib, a)
        if a.endswith(".svg") and os.path.isfile(caminho) and _sha(caminho) not in vestidos:
            soltos += 1
    return len(nomes), soltos


# A classificação morava dentro do laço do `cmd_info`; ela saiu para cá porque
# uma tabela e uma frase calculadas cada uma por si discordariam no primeiro
# pack que declarasse uma categoria nova, e a tela mostraria "herdado" onde o
# terminal diz "próprio".
#
# O NOME DE GENTE mora ao lado, e só é usado pela frase: a tabela continua com
# a trilha do pack.json, que é o que quem escreve um pack procura.
ROTULO_DA_CATEGORIA = {
    "paleta": "paleta",
    "cosmic.mapa": "mapa do COSMIC",
    "icones.apps": "ícones de aplicativo",
    "icones.pastas": "pastas",
    "icones.mimetypes": "ícones de arquivo",
    "icones.autorais": "ícones autorais",
    # O nome curto diz o mesmo, e a tabela do `info` mostra a trilha inteira ao
    # lado.
    "icones.base": "ícones-base",
    "cursores": "ponteiro",
    "wallpapers": "papéis de parede",
    "apps": "temas de aplicativo",
    "som": "som",
    "fontes": "fontes",
    "gerador": "traço do gerador de ícone",
    "prompt": "prompt",
    "fastfetch": "fastfetch",
    "mascote": "mascote",
}


# Uma categoria que some da tela é lida como "o pack cuida disso", e a nota de
# herança do Dracula dizia que prompt, fastfetch e mascotes "vêm do pack base".
#
# O traço da conversão — espessura, fusão, aparo, cantos, preenchimento —
# continua nos padrões do `converter_icone.py` e nas réguas da oficina, e é a
# mesma saída para todo pack.
FIXAS_NO_MOTOR = {
    "gerador": "scripts/converter_icone.py",
    "prompt": "assets/prompt/",
    "fastfetch": "assets/fastfetch/",
}


# A tabela dizia «pastas: próprio» e «7 desenho(s)» para o Dracula, e a tela
# mostrava outra coisa.
NOTA_DA_CATEGORIA = {
    "icones.pastas": ("só as pastas especiais, com «Ícones das pastas especiais» ligado "
                      "(PASTAS_XDG); as outras são o papirus-folders, na paleta do pack"),
}


def _cadeia_declara(ref, cat):
    """Algum pack da cadeia a partir de `ref` declara `cat`? (P74 item 7)

    A mesma régua da tabela do `origens`: o `mapa` do COSMIC só conta escrito
    (o `null` é o do motor), ponteiro, fontes e base só com `proprio`,
    `origem` ou `herda`, e o resto com qualquer bloco."""
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        if not achar(ref):
            return False
        caminho = {"cosmic.mapa": "cosmic.mapa", "cursores": "origens.cursores",
                   "wallpapers": "origens.wallpapers"}.get(cat, cat)
        bloco = campo(ref, caminho)
        if cat in ("cursores", CATEGORIA_FONTES, CATEGORIA_BASE):
            if isinstance(bloco, dict) and ("proprio" in bloco or "origem" in bloco or bloco.get("herda")):
                return True
        elif bloco is not None:
            return True
        ref = campo(ref, "heranca")
    return False


def origens(p):
    """[(categoria, tipo, de_quem)] na ordem da tabela do `info`.

    `tipo` é 'próprio', 'herdado', 'motor' ou 'fixo' (do motor, e sem campo no
    formato); `de_quem` só vem no 'herdado'.
    """
    ic = p.get("icones") or {}
    org = p.get("origens") or {}
    saida = []
    dir_pack_info = achar(p["id"]) if p.get("id") else None
    for cat, bloco in [("paleta", p.get("paleta")), ("cosmic.mapa", (p.get("cosmic") or {}).get("mapa")),
                       ("icones.apps", ic.get("apps")), ("icones.pastas", ic.get("pastas")),
                       ("icones.mimetypes", ic.get("mimetypes")), ("icones.autorais", ic.get("autorais")),
                       # A DÉCIMA SEXTA LINHA: a base que o `MeowSystem-Icons`
                       # herda, baixada pelo que o pack declara.
                       (CATEGORIA_BASE, ic.get("base")),
                       ("cursores", org.get("cursores")), ("wallpapers", org.get("wallpapers")),
                       ("mascote", p.get("mascote")),
                       ("apps", p.get("apps")),
                       ("som", p.get("som")), (CATEGORIA_FONTES, p.get(CATEGORIA_FONTES))] \
            + [(cat, None) for cat in FIXAS_NO_MOTOR]:
        if cat in FIXAS_NO_MOTOR:
            tipo, quem = "fixo", ""
            saida.append((cat, tipo, quem))
            continue
        # O SOM NÃO SOBE A HERANÇA, E A TABELA NÃO PODE DIZER QUE SOBE: o
        # `cmd_som` lê só o `som` do próprio pack, e o `som.sh` põe os padrões
        # dele no que faltar.
        if cat == "som":
            declarou = isinstance(bloco, dict) and any(not str(k).startswith("_") for k in bloco)
            saida.append((cat, "próprio" if declarou else "motor", ""))
            continue
        # A tabela dizia PRÓPRIO para o Dracula porque ele declara
        # `origens.wallpapers`, e nenhum código lê esse bloco: o
        # `scripts/wallpaper.sh` não o abre.
        #
        # O menor passo verdadeiro é a tabela dizer de onde a imagem sai.
        if cat in ("wallpapers", "mascote"):
            desenhos = bloco.get("desenhos") if isinstance(bloco, dict) else None
            proprio = isinstance(desenhos, str) and dir_pack_info and \
                os.path.isdir(os.path.join(dir_pack_info, desenhos))
            saida.append((cat, "próprio" if proprio else "motor", ""))
            continue
        # Um bloco com só o `tema` do ponteiro (o nome que a chave CURSOR
        # recebe) não traz tema nenhum, e a tabela dizia PRÓPRIO para ele; sem
        # `proprio` e sem `herda`, a categoria cai na `heranca`, que é o que o
        # `ponteiro` e o `tipografia` fazem de verdade.
        if (cat in ("cursores", CATEGORIA_FONTES, CATEGORIA_BASE) and isinstance(bloco, dict)
                and "proprio" not in bloco and "origem" not in bloco and not bloco.get("herda")):
            bloco = None
        if bloco is None:
            # O pack PADRÃO não herda de ninguém, e esta coluna imprimia
            # `HERDADO de (nenhuma)` em cinco das oito categorias dele — uma
            # frase que diz o contrário do que acontece.
            tipo, quem = ("herdado", p["heranca"]) if p.get("heranca") else ("motor", "")
            # O Dracula dizia «HERDADO de catppuccin» no mapa do COSMIC e nas
            # fontes, e o Catppuccin não declara nenhum dos dois: o mapa é o
            # `assets/paleta/cosmic-map.json` do motor e a fonte é a Nerd Font
            # do motor.
            if tipo == "herdado" and cat in ("cosmic.mapa", CATEGORIA_FONTES) \
                    and not _cadeia_declara(p["heranca"], cat):
                tipo, quem = "motor", ""
        elif isinstance(bloco, dict) and bloco.get("herda"):
            tipo, quem = "herdado", bloco["herda"]
        else:
            tipo, quem = "próprio", ""
        saida.append((cat, tipo, quem))
    return saida


# A próxima categoria que o Dracula declarar estoura, e o `tests/pack.sh`
# acusa. Duas propostas, medidas nos dois packs:
#
# A proposta é a B, e ela NÃO entrou aqui por causa da tela.
def resumo_de_origem(p):
    """A tabela do `info` numa linha: 'próprio: … · herdado de X: …'.

    SEM AS CATEGORIAS QUE NENHUM PACK DECLARA — achado da revisão da P12,
    23/09/2026. Esta linha é o `p.origem` que o cartão de pack da Home imprime
    cru, e com o grupo "do motor, sem campo no pack" ela passou de 170 para 266
    caracteres no Dracula e de 169 para 265 no Catppuccin, acima dos 220 por
    parágrafo da P7. O grupo era o MESMO em todo cartão, então não distinguia
    pack nenhum: ocupava a tela de quem escolhe para não dizer nada sobre a
    escolha. A tabela do `info` continua mostrando as quatro, com a origem.
    """
    grupos = {}
    for cat, tipo, quem in origens(p):
        if tipo == "fixo":
            continue
        # O molde dos tipos de arquivo é desenho do motor (P96): a forma vem do pack-base e a cor da
        # paleta do pack — dizê-lo «do motor» é o certo, e a linha do Dracula cabe nos 220.
        if tipo == "herdado" and quem == PACK_BASE and cat == "icones.mimetypes":
            tipo = "motor"
        chave = {"próprio": "próprio", "herdado": f"herdado de {quem}",
                 "motor": "do motor, ou ausente"}[tipo]
        grupos.setdefault(chave, []).append(ROTULO_DA_CATEGORIA[cat])
    return " · ".join(f"{k}: {', '.join(v)}" for k, v in grupos.items())


def cmd_info(ref):
    p, dados, dir_pack = validar(ref, silencioso=True)
    vit, problemas = vitrine(p, dir_pack)
    # Desde a a3ee4a6 o motor não confere o logo, e a vitrine só confere o
    # campo; sem esta linha, um logo com `<script>` sairia aqui como "capa
    # logo.svg", tudo certo, e o `validar` o recusaria logo depois.
    if vit["capa"]:
        try:
            _validar_logo(dir_pack, p)
        except Recusa as e:
            problemas.append(str(e))
    base = p.get("heranca") or "(nenhuma)"
    # O diretório e a herança descem uma linha porque respondem outra pergunta —
    # a de quem está consertando, não a de quem está escolhendo.
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
    # registra o risco com as palavras certas: derivar é opinativo, e o
    # `alucard` só saiu depois de três correções do método (o
    # `derivar_claro.py` conta as três).
    derivados = claros_derivados(dados)
    claros = [f"{c} — claro: derivado do escuro pelo método do Latte (não é próprio), "
              f"a partir de {derivados[c]!r}" if c in derivados else c
              for c in dados["claros"]]
    print(f"  claros    : {', '.join(claros) or '(nenhum)'}")
    # O `info` MOSTRA O PACK MESMO COM A VITRINE QUEBRADA, e diz o que falta:
    # ele é a pergunta de quem está consertando, e esconder o pack inteiro atrás
    # de uma capa ausente não ajudaria ninguém a achar a capa.
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
                  "motor": "DO MOTOR, ou inexistente",
                  "fixo": "DO MOTOR — não declarável"}[tipo]
        # `paleta` é um arquivo, `cosmic.mapa` é um arquivo, e cursores e
        # wallpapers são origens que este pack nem baixou ainda — contar SVG em
        # qualquer uma das quatro imprimiria uma coluna vazia que faz a pessoa
        # procurar o que deu errado.
        conta = ""
        # Ela não tem desenho no pack para contar: a coluna diz a origem pinada
        # e o pack que a declara.
        if cat == CATEGORIA_BASE:
            a_mao = _base_escolhida(os.environ.get("ICONES_BASE"))
            try:
                b = base_de_icones(ref)
            except Recusa:
                b, conta = None, "a origem declarada não valida"
            else:
                if b:
                    conta = f"{_url_curta(b['url'])}, sha256 {b['sha256'][:12]}…, do pack {b['pack']}"
                    if b.get("por_tras"):
                        conta += f", +{len(b['por_tras'])} por trás"
                elif a_mao:
                    conta = f"a cadeia não traz base — vale o ICONES_BASE=\"{a_mao}\" do meow.conf"
                else:
                    conta = (f"a cadeia não traz base — vale o ICONES_BASE do meow.conf "
                             f"({ICONES_BASE_DO_EXEMPLO} de fábrica)")
            if b and a_mao:
                conta += f"; vale o ICONES_BASE=\"{a_mao}\" do meow.conf"
        elif cat.startswith("icones."):
            quantos, fl = _contar_acervo(ref, cat, dados["flavors"])
            conta = f"{quantos}, {fl}" if quantos and fl else quantos
            # COM BIBLIOTECA, A LINHA DOS APLICATIVOS CONTA NOMES, E NÃO
            # ARQUIVOS DE `apps/`: um mapa que aponta para `biblioteca/` veste
            # aplicativos com desenho que não mora em `apps/`, e "70
            # desenho(s)" ali contaria a metade.
            bib = _contar_biblioteca(ref, dir_pack) if cat == "icones.apps" else None
            if bib:
                conta = f"{bib[0]} apps, {bib[1]} na biblioteca sem app ligado"
        # "HERDADO de catppuccin" era tudo o que o Dracula mostrava para o
        # ponteiro, e o catppuccin não traz ponteiro nenhum.
        elif cat == "cursores":
            pt = ponteiro(ref)
            conta = (f"CURSOR=\"{pt['valor']}\", do pack {pt['pack']}" if pt
                     else "" if tipo == "motor" else "a cadeia não traz ponteiro")
            # O baixado diz de onde desce: "do pack X" sozinho faria
            # procurar o tema dentro do pack, e ele não mora lá.
            if pt and pt.get("url"):
                conta += f", baixado de {_url_curta(pt['url'])}"
        elif cat == CATEGORIA_FONTES:
            # Um pack BASE com a lista quebrada não derruba o `info` de quem o
            # herda: o `validar` deste pack não confere a lista do outro, e o
            # que se quer aqui é ver a tabela inteira, dizendo o que falhou.
            try:
                quem_f, lista = tipografia(ref)
                conta = (f"{len(lista)} fonte(s), do pack {quem_f}" if quem_f
                         else "" if tipo == "motor" else "a cadeia não traz fonte")
            except Recusa:
                conta = "a lista herdada não valida no pack base"
        # DE ONDE O PAPEL DE PAREDE SAI, como nas fixas do motor. A segunda
        # metade é o porquê de o bloco declarado não mudar a linha: ver "OS
        # PAPÉIS DE PAREDE SÃO DO MOTOR", no `origens`.
        elif cat == "wallpapers":
            conta = "scripts/wallpaper.sh — segue o pack do flavor, sem ler este bloco"
            # Com os desenhos no pack, a linha conta os SVG que ele traz.
            if tipo == "próprio":
                pasta = acervo("origens.wallpapers.desenhos", ref=ref) or ""
                n = sum(1 for _r, _d, fs in os.walk(pasta) for a in fs if a.lower().endswith(".svg"))
                conta = f"{n} desenho(s) SVG, rasterizados em PNG 4K ao semear (scripts/wallpaper.sh)"
        elif cat in FIXAS_NO_MOTOR:
            conta = FIXAS_NO_MOTOR[cat]
        if cat in NOTA_DA_CATEGORIA:
            conta = " — ".join(x for x in (conta, NOTA_DA_CATEGORIA[cat]) if x)
        print(f"  {cat:<16}  {estado:<27}  {conta}")
    return OK


# A chave do `som` no pack.json e a do meow.conf que a vence.
SOM_NO_CONF = {
    "fundamental": "SOM_FUNDAMENTAL",
    "harmonico": "SOM_HARMONICO",
    "peso_fundamental": "SOM_PESO_FUNDAMENTAL",
    "peso_harmonico": "SOM_PESO_HARMONICO",
    "decaimento": "SOM_DECAIMENTO",
    "duracao": "SOM_DURACAO",
    "ganho": "SOM_GANHO",
}


# Quem grava o meow.conf é o `meow pack usar` (bin/meow), pela
# `meow_conf_definir` — a única rotina deste projeto que escreve naquele
# arquivo, e o cabeçalho dela conta o que custou ter duas.
# Aqui se decide QUAL id e QUAL flavor, e a recusa vem antes da primeira escrita.
RE_FLAVOR_CONF = re.compile(r"^[a-z0-9_]+$")


def plano_de_uso(ref, flavor=None, flavor_atual=None):
    """(id, flavor, porquê) que o `meow pack usar` vai gravar. Levanta Recusa.

    O flavor, nesta ordem: o PEDIDO, que tem de ser do pack; o que JÁ ESTÁ no ar,
    se for do pack — voltar ao Catppuccin estando no Latte não pode jogar a
    pessoa no Mocha; e o `flavor_padrao` do pack. O terceiro campo diz qual dos
    três venceu, para a tela dizer por quê.
    """
    # É a que o `meow_pack_dir` (lib/comum.sh) aplica por baixo de tudo: um pack
    # que a reprova vira "pack não resolve — usando o padrão", e o desktop sai
    # Catppuccin com `PACK="meu"` escrito no conf.
    p, dados, dir_pack = validar(ref, silencioso=True)
    ident = p["id"]
    # O meow.conf nomeia pack por id, e quem acha o id são as três raízes.
    _exigir(achar(ident) == dir_pack,
            f"o pack em {dir_pack} não é o que o id {ident!r} encontra.\n"
            f"    O meow.conf nomeia pack por id, procurado nesta ordem:\n      "
            + "\n      ".join(raizes())
            + f"\n    O pack vale a partir de {os.path.join(raizes()[-2], ident)}/.")
    flavors = list(dados["flavors"])
    if flavor:
        _exigir(flavor in dados["flavors"],
                f"o pack {ident!r} não tem o flavor {flavor!r}.\n"
                f"    Os que ele tem: {', '.join(flavors)}")
        escolhido, porque = flavor, "pedido"
    elif flavor_atual and flavor_atual in dados["flavors"]:
        escolhido, porque = flavor_atual, "mantido"
    else:
        escolhido = (p.get("paleta") or {}).get("flavor_padrao") or flavors[0]
        porque = "padrão do pack"
    # hífen; um nome de flavor com aspas ou `$(` numa paleta de terceiro viraria
    # comando no próximo `meow ativar`.
    _exigir(RE_FLAVOR_CONF.match(escolhido),
            f"o flavor {escolhido!r} do pack {ident!r} não pode ir para o meow.conf:\n"
            f"    só minúsculas, dígitos e sublinhado — ele é sourceado pelo shell.")
    return ident, escolhido, porque


def _nomes_curtos(p, dados):
    """{flavor: nome de tela}, sem o nome do pack na frente.

    A paleta do Catppuccin chama o flavor de "Catppuccin Mocha"; num cartão que
    já diz "Catppuccin", o nome dele é "Mocha". O Dracula chama os dele de
    "Dracula" e "Alucard", e ficam como estão.
    """
    nomes = dados.get("nomes") if isinstance(dados.get("nomes"), dict) else {}
    prefixo = f"{p.get('nome') or p['id']} "
    saida = {}
    for f in dados["flavors"]:
        n = str(nomes.get(f) or f)
        saida[f] = n[len(prefixo):] if n.startswith(prefixo) and len(n) > len(prefixo) else n
    return saida


# O FLAVOR DOS ÍCONES DE ARQUIVO HERDADOS: UMA REGRA, CHAMADA PELOS DOIS LADOS
#
# Depois do `.` do meow.conf a regra só vê o valor expandido, e não tem como
# distinguir `"$FLAVOR"` de `"dracula"` escrito à mão com `FLAVOR="dracula"`.
def _mimetypes_de(ident, p, dados):
    """O acervo de mimetype que o pack `ident` alcança, ou None.

    Um dicionário com `base` (o diretório), `dono` (o id de quem o traz),
    `p_dono`/`dados_dono` (o pack.json e a paleta desse dono), `existem` (os
    flavors do dono que têm diretório ali, na ordem da paleta dele) e
    `escolhido` (o `icones.mimetypes.flavor` que `ident` declara quando HERDA o
    acervo, ou None).

    É a conta que o `vocabulario` fazia sozinho desde a P10. Saiu para cá para a
    oferta da aba Ícones e a regra do `flavor_de_icones` lerem o MESMO
    `existem` e o MESMO `escolhido`: duas contas deles divergiriam no primeiro
    acervo com um diretório a mais.
    """
    base = acervo("icones.mimetypes.desenhos", ref=ident)
    if not base or not os.path.isdir(base):
        return None
    # P96 (23/10/2026): o acervo é UM molde (`var(--vscode-ctp-<papel>)`), e a instalação o
    # pinta com a paleta do pack no ar. Todo flavor da paleta dele existe, então; o dono das
    # cores é o próprio pack.
    return {
        "base": base,
        "dono": ident,
        "p_dono": p,
        "dados_dono": dados,
        "existem": list(dados["flavors"]),
        "escolhido": None,
    }


def _cores_do_flavor(ref, flavor):
    """As 26 cores de `flavor`: da paleta do pack, ou da primeira da herança que o tem."""
    vistos, r = set(), ref
    while r and r not in vistos:
        vistos.add(r)
        try:
            _p, dados, _d = validar(r, silencioso=True)
        except Recusa:
            break
        if flavor in dados["flavors"]:
            return dados["flavors"][flavor]
        r = campo(r, "icones.mimetypes.herda") or campo(r, "heranca")
    if ref != PACK_BASE:
        try:
            _p, dados, _d = validar(PACK_BASE, silencioso=True)
            return dados["flavors"].get(flavor)
        except Recusa:
            return None
    return None


def dir_de_pintados(ident, flavor):
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return os.path.join(base, "meowsystem", "pintados", f"{ident}-{flavor}")


def pintar_mimetypes(ref, flavor, temporario=False):
    """O molde de mimetype pintado no `flavor`: o diretório, refeito do pack a cada chamada.

    O molde mora no pack (é a fonte); o pintado é derivado e mora no cache, como o tema
    instalado. Só se escreve o arquivo cujo conteúdo mudou, e sai o que deixou o molde.
    Levanta Recusa quando o flavor não existe em paleta nenhuma da cadeia.
    """
    import tempfile
    p, _dados, dir_pack = validar(_ref_ativa(ref), silencioso=True)
    ident = p.get("id", os.path.basename(dir_pack))
    if not RE_FLAVOR_CONF.match(str(flavor or "")):
        raise Recusa(f"o flavor {flavor!r} não é um nome aceito")
    molde = acervo("icones.mimetypes.desenhos", ref=dir_pack)
    if not molde or not os.path.isdir(molde):
        raise Recusa("a cadeia deste pack não tem molde de tipo de arquivo")
    cores = _cores_do_flavor(dir_pack, flavor)
    if not cores:
        raise Recusa(f"nenhuma paleta da cadeia tem o flavor {flavor!r}")
    dentro = os.path.realpath(molde) + os.sep
    desenhos = sorted(f for f in os.listdir(molde) if f.endswith(".svg")
                      and os.path.isfile(os.path.join(molde, f)) and not os.path.islink(os.path.join(molde, f))
                      and os.path.realpath(os.path.join(molde, f)).startswith(dentro))
    destino = tempfile.mkdtemp(prefix="meow-pintados-") if temporario else dir_de_pintados(ident, flavor)
    os.makedirs(destino, exist_ok=True)
    for nome in desenhos:
        with open(os.path.join(molde, nome), encoding="utf-8") as fh:
            texto = fh.read()
        if not RE_VAR_CTP.search(texto):
            continue                     # não é desenho do molde (um glifo de traço, uma pasta)
        faltou = sorted({m for m in RE_VAR_CTP.findall(texto) if m not in cores})
        if faltou:
            raise Recusa(f"{nome}: a paleta {flavor!r} não tem {', '.join(faltou)}")
        novo = RE_VAR_CTP.sub(lambda m: cores[m.group(1)].lower(), texto)
        alvo = os.path.join(destino, nome)
        try:
            with open(alvo, encoding="utf-8") as fh:
                if fh.read() == novo:
                    continue
        except OSError:
            pass
        fd, tmp = tempfile.mkstemp(dir=destino, prefix=".meow-")
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(novo)
        os.chmod(tmp, 0o644)
        os.replace(tmp, alvo)
    vivos = set(desenhos)
    for nome in os.listdir(destino):
        if nome.endswith(".svg") and nome not in vivos:
            os.remove(os.path.join(destino, nome))
    return destino


def flavor_de_icones(ref, pedido, flavor):
    """O flavor dos ícones de arquivo que vale agora. Levanta Recusa.

    `pedido` é o `ICONES_FLAVOR` e `flavor` é o `FLAVOR`, os dois já expandidos
    pelo shell; `ref` é o pack no ar (None = o ativo). A ordem e o porquê estão
    no bloco logo acima. Pode devolver '' — só quando o conf não traz nem um nem
    outro e o pack não escolheu nada.
    """
    pedido, flavor = (pedido or "").strip(), (flavor or "").strip()
    if pedido and pedido != flavor:
        return pedido
    p, dados, _dir = validar(_ref_ativa(ref), silencioso=True)
    mt = _mimetypes_de(p["id"], p, dados)
    fabrica = pedido or flavor
    if mt and fabrica not in mt["existem"] and mt["escolhido"] in mt["existem"]:
        return mt["escolhido"]
    return fabrica


def vocabulario(ref):
    """O que a tela precisa para falar com as palavras DESTE pack. Levanta Recusa.

    É o `meow pack info` virado dado: os flavors com nome e as 26 cores de cada
    um, a origem de cada categoria, e — para a aba Ícones — de QUEM vêm os
    ícones de arquivo e os de aplicativo. Tudo sai do disco e do `pack.json`;
    nenhuma lista de nomes de pack mora aqui.

    OS ÍCONES DE ARQUIVO OFERECEM O QUE O PACK ESCOLHEU, QUANDO ELE HERDA
      O acervo de mimetype do Catppuccin tem quatro flavors, e o Dracula herda
      esse acervo declarando `icones.mimetypes.flavor: "macchiato"`. Oferecer os
      quatro numa máquina vestida de Dracula é pôr "Mocha" e "Frappé" na tela de
      quem nunca escolheu o Catppuccin; oferecer o que o pack escolheu, com o
      nome do dono ao lado, explica o nome estranho em vez de deixá-lo solto. Um
      pack que herda e NÃO escolhe recebe os flavors do dono, todos marcados
      como herdados. Os flavors saem dos diretórios que existem no acervo, e não
      da paleta: o `css-variables/` e o `LICENSE` que moram ali não são flavor, e
      um flavor da paleta sem diretório não tem ícone para vestir.
    """
    p, dados, _dir = validar(ref, silencioso=True)
    ident = p["id"]
    curtos = _nomes_curtos(p, dados)

    def nome_do_pack(outro):
        return campo(outro, "nome") or outro

    derivados = claros_derivados(dados)
    saida = {
        "id": ident,
        "nome": p.get("nome") or ident,
        "flavor_padrao": (p.get("paleta") or {}).get("flavor_padrao") or next(iter(dados["flavors"])),
        "flavors": [{"id": f, "nome": curtos[f], "claro": f in (dados.get("claros") or []),
                     "derivado": f in derivados,
                     "cores": [dados["flavors"][f][s] for s in SLOTS]}
                    for f in dados["flavors"]],
        "categorias": [{"categoria": ROTULO_DA_CATEGORIA[c], "tipo": t, "de": q,
                        "nome_de": nome_do_pack(q) if q else "",
                        "nota": NOTA_DA_CATEGORIA.get(c, "")}
                       for c, t, q in origens(p)],
        "mimetypes": None,
        "apps": None,
    }

    mt = _mimetypes_de(ident, p, dados)
    if mt:
        dono, existem, escolhido = mt["dono"], mt["existem"], mt["escolhido"]
        curtos_dono = curtos if dono == ident else _nomes_curtos(mt["p_dono"], mt["dados_dono"])
        saida["mimetypes"] = {
            "de": dono,
            "nome_de": nome_do_pack(dono),
            "herdado": dono != ident,
            "flavors": [escolhido] if escolhido in existem else existem,
            "nomes": {f: curtos_dono[f] for f in existem},
            # O desenho da aba Ícones pinta o fundo pelo sabor dos ícones de
            # arquivo, e esse sabor é um flavor do DONO: com o Dracula no ar e
            # `ICONES_FLAVOR="latte"`, a régua de claro e escuro dos flavors do
            # pack no ar não conhecia o latte, o fundo saía escuro e a tinta,
            # pedida escura para o latte, sumia nele.
            "claros": [f for f in existem if f in (mt["dados_dono"].get("claros") or [])],
            "luz": {f: round(_luminancia(mt["dados_dono"]["flavors"][f]["base"]), 4)
                    for f in existem},
        }

    mapa = acervo("icones.apps.mapa", ref=ident)
    if mapa:
        dono = _pack_de(mapa)
        saida["apps"] = {"de": dono, "nome_de": nome_do_pack(dono), "herdado": dono != ident}
    return saida


def cmd_som(ref):
    """Imprime o timbre do pack como CHAVE=valor, para o shell avaliar.

    Só imprime o que o pack DECLARA: as chaves ausentes ficam de fora, e o
    scripts/som.sh aplica os defaults dele. Assim o default continua morando num
    lugar só — se este comando imprimisse os defaults também, haveria duas
    verdades sobre o timbre padrão, e elas divergiriam na primeira mudança.
    """
    p, _, _ = validar(ref, silencioso=True)
    som = p.get("som") or {}
    for chave, var in SOM_NO_CONF.items():
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
        construía o conteúdo de um pack: ele entrava num TERCEIRO repositório,
        o `Dracula_OS-Theme`, e rodava o `baixar_upstreams.sh`, o
        `extrair_mapeamento.py`, o `build.sh` e o `install.sh --user` DELE.
        (Desde 23/09/2026 ele não roda mais nada: a P37 o desativou no
        Spellbook, e o aviso que ficou no lugar manda para o `meow`. Quem põe
        os desenhos do Dracula no tema agora é o `icones_apps_dracula.sh`,
        lendo do pack e escrevendo no `MeowSystem-Icons`.)
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
    derivar = ((p.get("icones") or {}).get("mimetypes") or {}).get("derivar")
    if not gerar and not derivar:
        print(f"  --   {ident}: não declara nada derivado — nada a construir")
        return OK
    # Os ícones de arquivo derivados vêm antes dos autorais: não dependem de
    # gerador de fora, e um pack pode declarar só eles.
    if derivar:
        # P96: o pintado não mora mais no pack; a instalação pinta do molde (`pintar_mimetypes`)
        print(f"  --   {ident}: icones.mimetypes.derivar não escreve mais no pack — a instalação pinta o molde")
    if not gerar:
        print(f"  ok   {ident}: construído")
        return OK

    # `_dentro` com o caminho que VAMOS ESCREVER: o `dir_acervo` o aplica.
    saida = dir_acervo("icones.autorais.desenhos", ref=dir_pack,
                       padrao=PASTA_AUTORAIS).rstrip(os.sep)

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


# O upstream do Catppuccin (catppuccin/vscode-icons, MIT) publica, ao lado dos
# quatro flavors, o `css-variables/`: os MESMOS 656 desenhos com cada cor
# escrita por papel (`var(--vscode-ctp-mauve)`).
#
# Como o acervo do Catppuccin, e ao contrário dos autorais (ver a dívida no
# `cmd_construir`): aqui não há segunda cópia em lugar nenhum, e a máquina de
# quem instala não precisa construir nada.
RE_VAR_CTP = re.compile(r"var\(--vscode-ctp-([a-z0-9]+)\)")


def derivar_mimetypes(ref, seco=False):
    """Escreve `<desenhos>/<flavor>/` para cada flavor da paleta do pack. Levanta Recusa."""
    import tempfile
    p, dados, dir_pack = validar(ref, silencioso=True)
    ident = p.get("id", os.path.basename(dir_pack))
    bloco = (p.get("icones") or {}).get("mimetypes") or {}
    der = bloco.get("derivar") or {}
    origem = acervo("icones.mimetypes.desenhos", der.get("pasta", ""), ref=der.get("de"))
    if not origem or not os.path.isdir(origem):
        raise Recusa(f"icones.mimetypes.derivar: o pack {der.get('de')!r} não tem "
                     f"{der.get('pasta')!r} no acervo de mimetype dele")
    # O pack de onde se deriva pode ser importado, e um `.svg` que é link para
    # fora (`~/.ssh/id_ed25519`) seria lido e escrito dentro deste pack. O link,
    # ou o que resolve fora da pasta, fica de fora.
    dentro_origem = os.path.realpath(origem) + os.sep
    desenhos = sorted(f for f in os.listdir(origem) if f.endswith(".svg")
                      and not os.path.islink(os.path.join(origem, f))
                      and os.path.isfile(os.path.join(origem, f))
                      and os.path.realpath(os.path.join(origem, f)).startswith(dentro_origem))
    destino_base = _dentro(dir_pack, bloco["desenhos"], "icones.mimetypes.desenhos")
    escritos = removidos = 0
    for flavor, cores in dados["flavors"].items():
        # O nome do flavor vira diretório: só de um conjunto fechado (o mesmo
        # do conf), para `../` numa paleta importada não escrever fora do pack.
        if not RE_FLAVOR_CONF.match(str(flavor)):
            raise Recusa(f"icones.mimetypes.derivar: o flavor {flavor!r} não é um nome de "
                         f"diretório aceito (só minúsculas, dígitos e '_')")
        destino = os.path.join(destino_base, flavor)
        if not seco:
            os.makedirs(destino, exist_ok=True)
        for nome in desenhos:
            with open(os.path.join(origem, nome), encoding="utf-8") as fh:
                texto = fh.read()
            faltou = sorted({m for m in RE_VAR_CTP.findall(texto) if m not in cores})
            if faltou:
                raise Recusa(f"{nome}: a paleta {flavor!r} não tem {', '.join(faltou)}")
            novo = RE_VAR_CTP.sub(lambda m: cores[m.group(1)].lower(), texto)
            alvo = os.path.join(destino, nome)
            # `open(alvo, "w")` escreveria no alvo dele, fora do pack. O link
            # conta como diferente e é trocado por um arquivo comum, pelo
            # temporário + `os.replace`, que substitui o link sem segui-lo.
            if not os.path.islink(alvo):
                try:
                    with open(alvo, encoding="utf-8") as fh:
                        if fh.read() == novo:
                            continue
                except OSError:
                    pass
            escritos += 1
            if not seco:
                fd, tmp = tempfile.mkstemp(dir=destino, prefix=".meow-")
                with os.fdopen(fd, "w", encoding="utf-8") as fh:
                    fh.write(novo)
                os.chmod(tmp, 0o644)
                os.replace(tmp, alvo)
        if os.path.isdir(destino):
            for nome in sorted(os.listdir(destino)):
                if nome.endswith(".svg") and nome not in desenhos:
                    removidos += 1
                    if not seco:
                        os.remove(os.path.join(destino, nome))
    licenca = os.path.join(os.path.dirname(origem.rstrip("/")), "LICENSE")
    # A licença pela mesma régua dos desenhos: link não é lido nem atravessado.
    if os.path.isfile(licenca) and not os.path.islink(licenca) and not seco:
        alvo = os.path.join(destino_base, "LICENSE")
        with open(licenca, encoding="utf-8") as fh:
            texto = fh.read()
        if os.path.islink(alvo) or not os.path.isfile(alvo) \
                or open(alvo, encoding="utf-8").read() != texto:
            fd, tmp = tempfile.mkstemp(dir=destino_base, prefix=".meow-")
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                fh.write(texto)
            os.chmod(tmp, 0o644)
            os.replace(tmp, alvo)
    verbo = "escreveria" if seco else "escreveu"
    print(f"  {'~~' if escritos or removidos else 'ok'}   {ident}: ícones de arquivo de "
          f"{der.get('de')}/{der.get('pasta')}, {len(desenhos)} por flavor × "
          f"{len(dados['flavors'])} — {verbo} {escritos}, tirou {removidos}")
    return escritos + removidos


# --- O PACK QUE VIAJA: novo, exportar, importar -----
#
# `novo` escreve um pack onde pack se escreve (packs/ do projeto, ou a raiz de
# teste). `exportar` escreve o arquivo que a pessoa nomeou, e nada mais.
MEOWPACK = 1
MANIFESTO = "MANIFESTO"
# O zstd reduz uma fila de zeros a quase nada: um `.meowpack` de um megabyte
# pode abrir em gigabytes e derrubar quem o lê.
TETO_MEOWPACK = 256 << 20
TETO_ARQUIVOS_MEOWPACK = 20000
# "As imagens" da pergunta do exportar: o que é raster. Ícone, logo e capa são
# SVG — texto, que comprime a quase nada —, e é o raster que faz um pack pesar.
EXT_IMAGEM = (".png", ".jpg", ".jpeg", ".webp")
ZSTD_MAGICO = b"\x28\xb5\x2f\xfd"
SEM_DEPENDENCIA = 3                 # o mesmo 3 do MEOW_SEM_DEPENDENCIA do shell


class Falta(Exception):
    """Uma ferramenta que falta nesta máquina — não é defeito de pack nenhum."""


def _zstd():
    import shutil
    exe = shutil.which("zstd")
    if not exe:
        raise Falta("sem o `zstd` não há .meowpack — ele é o compressor do formato,\n"
                    "    e nesta máquina não está no PATH. Ele vem no pacote `zstd`.")
    return exe


def _mb(n):
    """Tamanho para gente ler. Abaixo de um mega, em KB: "0,0 MB" diz que o pack
    está vazio, e um pack de quatro arquivos pesa 8 KB, não nada."""
    if n < 1 << 20:
        return f"{max(1, round(n / 1024))} KB"
    return f"{n / (1 << 20):.1f} MB".replace(".", ",")


# Quantos bytes do começo o `_proibido` precisa: o BOM do UTF-8 (3) e o `#!`.
CABECA_PROIBIDA = 5


def _proibido(rel, cabeca):
    """Por que este arquivo não pode viajar dentro de um pack — ou None.

    O BOM NÃO ESCONDE O `#!` — 10/10/2026, P79 (achado da P78). Um `leia.txt`
    que começa com o BOM do UTF-8 e `#!` entrava: a régua olhava só os dois
    primeiros bytes. Nada do pack é executado (chmod 644), então não era porta;
    era a régua prometendo mais do que media."""
    if rel.lower().endswith(".sh"):
        return "é script de shell"
    if cabeca.startswith(b"\xef\xbb\xbf"):
        cabeca = cabeca[3:]
    if cabeca.startswith(b"#!"):
        return "começa com #!, e isso é script, seja qual for o nome"
    return None


def _pack_existente(ident):
    """O caminho `ident` em QUALQUER raiz, seja pack ou não — ou None.

    Em qualquer raiz, e não só na de destino: um pack com o mesmo id noutra raiz
    esconderia um dos dois (a primeira raiz vence), e a pessoa veria o pack
    errado sem erro nenhum. E pack ou não: um diretório com esse nome é de
    alguém, e escrever por cima dele é o erro que não se desfaz com Ctrl+C.
    """
    for base in raizes():
        cand = os.path.join(base, ident)
        if os.path.lexists(cand):
            return cand
    return None


def _arquivos_do_pack(dir_pack):
    """(o que viaja, quantas entradas ocultas ficaram, problemas).

    O OCULTO FICA DE FORA, E É DE PROPÓSITO: o docs/PACKS.md ensina a publicar
    um pack por `git clone`, e o `.git/hooks/` de um clone é uma pasta de
    scripts. Nenhum arquivo do formato começa com ponto.
    """
    saida, ocultos, problemas = [], 0, []
    for base, dirs, arquivos in os.walk(dir_pack):
        ficam = []
        for d in sorted(dirs):
            if d.startswith("."):
                ocultos += 1
            elif os.path.islink(os.path.join(base, d)):
                problemas.append(f"{os.path.relpath(os.path.join(base, d), dir_pack)}: é "
                                 f"link simbólico — um pack viaja com cópias, e o link "
                                 f"apontaria para a máquina de quem exportou")
            else:
                ficam.append(d)
        dirs[:] = ficam
        for nome in arquivos:
            cheio = os.path.join(base, nome)
            rel = os.path.relpath(cheio, dir_pack)
            if nome.startswith("."):
                ocultos += 1
            elif os.path.islink(cheio) or not os.path.isfile(cheio):
                problemas.append(f"{rel}: não é arquivo comum — um pack viaja com cópias, "
                                 f"e um link apontaria para a máquina de quem exportou")
            elif "\n" in rel or "\r" in rel:
                problemas.append(f"{rel!r}: nome com quebra de linha não cabe no MANIFESTO")
            else:
                with open(cheio, "rb") as fh:
                    motivo = _proibido(rel, fh.read(CABECA_PROIBIDA))
                if motivo:
                    problemas.append(f"{rel}: {motivo} — um pack é dado, nunca é código")
                else:
                    saida.append(rel)
    return sorted(saida), ocultos, problemas


def medida(dir_pack, arquivos):
    """Quanto o pack pesa, e quanto disso é imagem. Só lê o disco."""
    def tam(rel):
        return os.path.getsize(os.path.join(dir_pack, rel))
    imagens = [r for r in arquivos if r.lower().endswith(EXT_IMAGEM)]
    return {"arquivos": len(arquivos), "bytes": sum(map(tam, arquivos)),
            "imagens": len(imagens), "bytes_imagens": sum(map(tam, imagens))}


def medir_exportacao(ref):
    """A `medida` do que o exportar levaria, sem conferir nada — é a pergunta
    "quantos MB?" que a tela faz ANTES de pedir o arquivo. Quem confere é o
    próprio `exportar`, que recusa com o motivo."""
    dir_pack = achar(ref)
    _exigir(dir_pack, f"não achei o pack {ref!r}")
    arquivos, _ocultos, _problemas = _arquivos_do_pack(dir_pack)
    return medida(dir_pack, arquivos)


def _licencas(dir_pack):
    """As linhas do PROCEDENCIA.md que não deixam a arte sair. Vazia = pode.

    A TABELA É A DA P28, lida pelo mesmo `_tabela_procedencia` do `sincronizar`:
    uma segunda leitura do mesmo arquivo discordaria da primeira no dia em que
    alguém mudasse a ordem das colunas. A coluna que importa aqui é `licença` —
    vazia, `?` ou `—` quer dizer que ninguém escreveu, e o que ninguém escreveu
    não se reempacota.
    """
    proc = os.path.join(dir_pack, "PROCEDENCIA.md")
    if not os.path.isfile(proc):
        return []
    linhas = _tabela_procedencia(proc)
    if not linhas:
        return ["PROCEDENCIA.md: não achei a tabela que diz de onde veio cada arte "
                f"(as colunas {', '.join(COLUNAS_PROCEDENCIA)} e licença) — sem ela, "
                "não há como saber o que pode sair"]
    problemas = []
    for lin in linhas:
        licenca = lin.get("licença", lin.get("licenca", ""))
        if not re.search(r"\w", licenca):
            problemas.append(f"PROCEDENCIA.md: {lin.get('arquivo') or '(linha sem arquivo)'} "
                             f"não diz a licença — arte de terceiro sem licença escrita não "
                             f"é reempacotada")
    return problemas


def _herdados_de_fora(p):
    """Os packs de quem este herda e que NÃO vêm com o MeowSystem.

    É aviso, e não recusa: herdar de um pack de terceiro é legítimo, e o
    `validar` de quem importar recusa com o nome dele se faltar. O aviso existe
    para quem exporta saber disso antes de mandar.
    """
    nomes = {p.get("heranca")}
    for bloco in (list((p.get("icones") or {}).values()) + list((p.get("origens") or {}).values())
                  + list((p.get("apps") or {}).values())):
        if isinstance(bloco, dict):
            nomes.add(bloco.get("herda"))
    return sorted(h for h in nomes
                  if h and not os.path.isfile(os.path.join(RAIZ, "packs", str(h), "pack.json")))


def exportacao(ref):
    """Tudo o que o `exportar` confere, e o que ele levaria. Levanta Recusa.

    O `validar` é o de sempre, o do `meow pack validar` — inteiro, com a vitrine
    e o logo, porque exportar é publicar. Um segundo validador aqui aprovaria o
    que o primeiro recusa, e o `.meowpack` sairia daqui para ser recusado na
    máquina de quem o recebe.
    """
    p, _dados, dir_pack = validar(ref)
    creditos = p.get("creditos") or "CREDITOS.md"
    _exigir(os.path.isfile(_dentro(dir_pack, creditos, "creditos")),
            f"sem o {creditos}, o pack não sai daqui.\n"
            f"    Arte de terceiro não é reempacotada sem dizer de onde veio e sob que\n"
            f"    licença — e é o {creditos} que diz, para quem receber. Se tudo é seu,\n"
            f"    ele diz isso.")
    arquivos, ocultos, problemas = _arquivos_do_pack(dir_pack)
    problemas = _licencas(dir_pack) + problemas
    _exigir(not problemas, "\n  erro ".join(problemas))
    exp = {"p": p, "dir": dir_pack, "lista": arquivos, "ocultos": ocultos,
           "de_fora": _herdados_de_fora(p)}
    exp.update(medida(dir_pack, arquivos))
    return exp


def _sem_capturas_raster(texto):
    """O pack.json com a `vitrine.capturas` sem as imagens raster que ficaram."""
    p = json.loads(texto)
    vit = p.get("vitrine")
    if isinstance(vit, dict) and isinstance(vit.get("capturas"), list):
        vit["capturas"] = [c for c in vit["capturas"]
                           if not str(c).lower().endswith(EXT_IMAGEM)]
    return (json.dumps(p, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def meowpack(exp, sem_imagens=False):
    """Os bytes do `.meowpack` que a `exportacao` conferiu.

    SEM AS IMAGENS, o pack.json da CÓPIA perde as capturas raster, e a cópia
    passa pelo `validar` de novo: um pack que declara uma captura e não a traz é
    exatamente o que o `validar` recusa, e seria a pessoa do outro lado quem
    descobriria. O pack de origem não muda um byte — o MeowSystem não escreve
    dentro de pack.
    """
    import contextlib
    import io
    import subprocess
    import tarfile
    import time

    ident, dir_pack = exp["p"]["id"], exp["dir"]
    conteudo = {}
    for rel in exp["lista"]:
        if sem_imagens and rel.lower().endswith(EXT_IMAGEM):
            continue
        with open(os.path.join(dir_pack, rel), "rb") as fh:
            conteudo[rel] = fh.read()
    if sem_imagens and exp["imagens"]:
        conteudo["pack.json"] = _sem_capturas_raster(conteudo["pack.json"])
        # A recusa não é calada.
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            _instalar_pack(conteudo, None, ident, seco=True)

    linhas = [f"meowpack {MEOWPACK}", f"formato {exp['p']['formato']}", f"pack {ident}"]
    linhas += [f"{hashlib.sha256(c).hexdigest()}  {rel}" for rel, c in sorted(conteudo.items())]
    entradas = [(MANIFESTO, ("\n".join(linhas) + "\n").encode("utf-8"))]
    entradas += [(f"{ident}/{rel}", c) for rel, c in sorted(conteudo.items())]
    agora = int(time.time())
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w", format=tarfile.PAX_FORMAT) as tar:
        for nome, dado in entradas:
            info = tarfile.TarInfo(nome)
            # Sem dono: o `uname` de quem exportou é nome de pessoa, e o
            # docs/PACKS.md pede, para publicar, "nenhum nome de usuário".
            info.size, info.mode, info.mtime = len(dado), 0o644, agora
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            tar.addfile(info, io.BytesIO(dado))
    r = subprocess.run([_zstd(), "-q", "-10", "-c"], input=buf.getvalue(), capture_output=True)
    if r.returncode != 0:
        raise Falta(f"o zstd não conseguiu comprimir: "
                    f"{r.stderr.decode('utf-8', 'replace').strip() or r.returncode}")
    return r.stdout


def _perguntar(pergunta, teto=30):
    """A resposta, ou None se não há ninguém para responder.

    A regra da casa para pergunta (docs/PACKS.md, "Temas de aplicativo"): só
    quando as duas pontas são terminal, e a espera tem teto de 30 segundos.
    """
    import select
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        return None
    print(f"  ??   {pergunta} ", end="", flush=True)
    pronto, _, _ = select.select([sys.stdin], [], [], teto)
    if not pronto:
        print()
        return None
    return sys.stdin.readline().strip()


def cmd_exportar(ref, opcoes):
    saida, sem_imagens, seco = None, False, False
    for op in opcoes:
        if op == "--sem-imagens":
            sem_imagens = True
        elif op in ("--seco", "--dry-run"):
            seco = True
        elif op.startswith("-") or saida is not None:
            print(f"  erro não entendi {op!r} — uso: exportar <id> [arquivo.meowpack] "
                  f"[--sem-imagens] [--seco]", file=sys.stderr)
            return ERRO_USO
        else:
            saida = op
    exp = exportacao(ref)
    ident = exp["p"]["id"]
    saida = os.path.abspath(saida or f"{ident}.meowpack")
    _exigir(not saida.startswith(os.path.realpath(exp["dir"]) + os.sep),
            f"{saida}: o .meowpack não pode nascer dentro do próprio pack — a próxima\n"
            f"    exportação o levaria junto")
    pasta = os.path.dirname(saida)
    if not os.path.isdir(pasta):
        print(f"  erro {pasta}: esse diretório não existe — o exportar não cria pasta;\n"
              f"       crie-a antes, ou diga outro lugar", file=sys.stderr)
        return ERRO_USO

    # O TAMANHO É DITO ANTES, E A PERGUNTA SÓ VEM SE HÁ O QUE PERGUNTAR.
    imagens = (f" — {exp['imagens']} imagem(ns), {_mb(exp['bytes_imagens'])}"
               if exp["imagens"] else "")
    quantos = f"{exp['arquivos']:,}".replace(",", ".")
    print(f"  >>   {ident}: {quantos} arquivo(s), {_mb(exp['bytes'])}{imagens}")
    if exp["ocultos"]:
        print(f"  --   {exp['ocultos']} entrada(s) oculta(s) ficam de fora (.git e afins)")
    for h in exp["de_fora"]:
        print(f"  !!   ele herda do pack {h!r}, que não vem com o MeowSystem: "
              f"quem importar precisa tê-lo", file=sys.stderr)
    if exp["imagens"] and not sem_imagens:
        resposta = _perguntar(f"as {exp['imagens']} imagem(ns), {_mb(exp['bytes_imagens'])}, "
                              f"vão junto? [S/n]")
        if resposta is None:
            print("  --   ninguém para perguntar: as imagens vão junto "
                  "(--sem-imagens as deixa de fora)")
        elif resposta.lower().startswith("n"):
            sem_imagens = True
    if seco:
        print(f"  ~~   escreveria {saida} — nada foi escrito")
        return OK

    dados = meowpack(exp, sem_imagens)
    # Atômico: um `.meowpack` pela metade no lugar do nome pedido seria mandado
    # adiante e recusado do outro lado como "não é zstd", longe de quem errou.
    parcial = saida + ".parcial"
    try:
        with open(parcial, "wb") as fh:
            fh.write(dados)
        os.replace(parcial, saida)
    except OSError as e:
        if os.path.exists(parcial):
            os.remove(parcial)
        print(f"  erro não consegui escrever {saida}: {e.strerror or e}", file=sys.stderr)
        return ERRO_USO
    fora = " (sem as imagens)" if sem_imagens and exp["imagens"] else ""
    print(f"  ok   {saida} — {_mb(len(dados))}{fora}")
    return OK


def _descomprimir(caminho):
    """O tar de dentro do `.meowpack`, com o teto do arquivo ABERTO."""
    import subprocess
    proc = subprocess.Popen([_zstd(), "-d", "-c", "-q", "--", caminho],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    partes, total = [], 0
    try:
        while True:
            bloco = proc.stdout.read(1 << 20)
            if not bloco:
                break
            total += len(bloco)
            if total > TETO_MEOWPACK:
                proc.kill()
                raise Recusa(f"aberto, ele passa de {TETO_MEOWPACK >> 20} MB — maior que "
                             f"qualquer pack; parei de ler antes de encher a memória")
            partes.append(bloco)
    finally:
        proc.stdout.close()
        erro = proc.stderr.read().decode("utf-8", "replace").strip()
        proc.stderr.close()
        proc.wait()
    _exigir(proc.returncode == 0, f"o zstd não conseguiu abri-lo: {erro or proc.returncode}")
    return b"".join(partes)


def _conferir_manifesto(texto, ident, membros):
    try:
        linhas = texto.decode("utf-8").splitlines()
    except UnicodeDecodeError:
        raise Recusa("o MANIFESTO não é texto")
    cab, somas = {}, {}
    for n, linha in enumerate(linhas, 1):
        if not linha.strip():
            continue
        # O que o MANIFESTO promete também sai cru no "promete e não veio".
        _exigir(not RE_CONTROLE.search(linha),
                f"MANIFESTO, linha {n}: caractere de controle em {linha[:80]!r}")
        soma, sep, rel = linha.partition("  ")
        if sep and RE_SHA256.match(soma):
            _exigir(rel not in somas, f"MANIFESTO, linha {n}: {rel!r} aparece duas vezes")
            somas[rel] = soma
            continue
        chave, _, valor = linha.partition(" ")
        _exigir(chave in ("meowpack", "formato", "pack"),
                f"MANIFESTO, linha {n}: não entendo {linha[:80]!r}")
        cab[chave] = valor.strip()
    for chave, teto in (("meowpack", MEOWPACK), ("formato", FORMATO_MAX)):
        v = cab.get(chave, "")
        _exigir(v.isdigit() and 1 <= int(v) <= teto,
                f"MANIFESTO: {chave} {v!r} — este MeowSystem entende até {teto}.\n"
                f"    Um .meowpack mais novo pede um MeowSystem mais novo.")
    _exigir(cab.get("pack") == ident,
            f"MANIFESTO: diz que o pack é {cab.get('pack')!r}, e o diretório é {ident!r}")
    faltam = sorted(set(somas) - set(membros))
    sobram = sorted(set(membros) - set(somas))
    _exigir(not faltam, "o MANIFESTO promete e não veio:\n      " + "\n      ".join(faltam))
    _exigir(not sobram, "veio sem estar no MANIFESTO:\n      " + "\n      ".join(sobram))
    trocados = [rel for rel in sorted(somas)
                if hashlib.sha256(membros[rel]).hexdigest() != somas[rel]]
    _exigir(not trocados, "o sha256 não confere — o arquivo mudou depois de exportado:\n      "
                          + "\n      ".join(trocados))


def ler_meowpack(caminho):
    """(id, {caminho relativo: bytes}) de um `.meowpack`, conferido INTEIRO.

    NADA É ESCRITO AQUI — tudo acontece na memória, e é por isso que o teto
    existe. Recusa, dizendo qual entrada: o que não for zstd; caminho absoluto,
    com `..` ou fora do diretório do pack; link, dispositivo e tudo o que não
    for arquivo comum; entrada oculta; dois packs num arquivo só; o que o
    MANIFESTO não bate. E, juntos numa recusa só, com uma linha por arquivo,
    todos os scripts.
    """
    import io
    import tarfile
    with open(caminho, "rb") as fh:
        _exigir(fh.read(4) == ZSTD_MAGICO,
                f"{caminho}: não é um .meowpack — ele é um .tar.zst, e este arquivo "
                f"não começa como zstd")
    bruto = _descomprimir(caminho)
    try:
        tar = tarfile.open(fileobj=io.BytesIO(bruto), mode="r:")
    except tarfile.TarError as e:
        raise Recusa(f"{caminho}: por dentro não é um tar ({e})")
    ident, membros, manifesto, scripts = None, {}, None, []
    with tar:
        for i, m in enumerate(tar):
            _exigir(i < TETO_ARQUIVOS_MEOWPACK,
                    f"mais de {TETO_ARQUIVOS_MEOWPACK} entradas — maior que qualquer pack")
            # As recusas abaixo (o "traz script", o "veio sem estar no
            # MANIFESTO") listam o nome cru, e o terminal de quem importa o
            # leria como comando (`\e]52;…` escreve na área de transferência).
            _exigir(not RE_CONTROLE.search(m.name),
                    f"{m.name!r}: nome com caractere de controle — recusado inteiro")
            nome = m.name.rstrip("/") if m.isdir() else m.name
            partes = nome.split("/")
            _exigir(nome and not nome.startswith("/") and "\\" not in nome
                    and all(x not in ("", ".", "..") for x in partes),
                    f"{m.name!r}: caminho que sai do pack — recusado inteiro")
            if nome == MANIFESTO and m.isfile():
                _exigir(manifesto is None, "dois MANIFESTO num arquivo só")
                manifesto = tar.extractfile(m).read()
                continue
            _exigir(RE_ID.match(partes[0]),
                    f"{m.name!r}: tudo mora dentro de <id>/, e {partes[0]!r} não é um id")
            if ident is None:
                ident = partes[0]
            _exigir(partes[0] == ident, f"{m.name!r}: dois packs num arquivo só "
                                        f"({ident!r} e {partes[0]!r})")
            _exigir(not any(x.startswith(".") for x in partes[1:]),
                    f"{m.name!r}: entrada oculta — o exportar não as gera")
            if m.isdir():
                continue
            _exigir(m.isfile(), f"{m.name!r}: não é arquivo comum (link, dispositivo) — "
                                f"um pack é feito de arquivos")
            _exigir(len(partes) > 1, f"{m.name!r}: arquivo solto fora do diretório do pack")
            rel = "/".join(partes[1:])
            _exigir(rel not in membros, f"{m.name!r} aparece duas vezes")
            dado = tar.extractfile(m).read()
            motivo = _proibido(rel, dado[:CABECA_PROIBIDA])
            if motivo:
                scripts.append(f"{m.name}: {motivo}")
            membros[rel] = dado
    _exigir(not scripts, "um pack é dado, nunca é código — este traz script:\n      "
                         + "\n      ".join(scripts))
    _exigir(ident and membros, f"{caminho}: não há pack nenhum aqui dentro")
    _exigir(manifesto is not None, f"{caminho}: sem o MANIFESTO, não há como conferir "
                                   f"o que chegou")
    _conferir_manifesto(manifesto, ident, membros)
    return ident, para_tres_pastas(ident, membros)


# Um `.meowpack` de formato 1 traz as pastas que cada pack inventava
# (`autorais/`, `pastas/`, `feitos-a-mao/`…). A arte não muda um byte.
PASTAS_DO_FORMATO = ("apps", "sistema", "biblioteca")
# P96 (23/10/2026): as três pastas são planas — o que vinha de uma pasta de antes cai direto
# na pasta dela, sem subpasta (o flavor de um acervo de tipo de arquivo vira sufixo no nome).
PASTA_DE_ANTES_POR_NOME = {"autorais": "apps", "resgatados": "apps",
                           "feitos-a-mao": "biblioteca",
                           "pastas": "sistema", "mimetypes": "sistema"}
PASTA_DA_CATEGORIA = {"apps": "apps", "autorais": "apps", "resgatados": "apps",
                      "pastas": "sistema", "mimetypes": "sistema"}


def para_tres_pastas(ident, membros):
    """`membros` (caminho → bytes) de um pack de formato 1, no formato 2."""
    try:
        p = json.loads(membros.get("pack.json", b"{}").decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        return membros          # o `validar` diz o porquê, com a linha
    if not isinstance(p, dict) or not isinstance(p.get("formato"), int):
        return membros
    com_subpasta = any(len(r.split("/")) > 3 and r.split("/")[0] == "icones" and r.split("/")[1] in PASTAS_DO_FORMATO
                       for r in membros)
    if p["formato"] >= 2 and not com_subpasta:
        return membros
    ic = p.get("icones") if isinstance(p.get("icones"), dict) else {}
    declarada = {}
    for cat, bloco in ic.items():
        if isinstance(bloco, dict) and isinstance(bloco.get("desenhos"), str):
            topo = bloco["desenhos"].split("/")
            if len(topo) >= 2 and topo[0] == "icones":
                declarada.setdefault(topo[1], cat)
    troca = {}
    for rel in membros:
        partes = rel.split("/")
        if len(partes) > 2 and partes[0] == "icones" and partes[1] not in PASTAS_DO_FORMATO:
            d = partes[1]
            troca[d] = PASTA_DE_ANTES_POR_NOME.get(d) or (
                PASTA_DA_CATEGORIA[declarada[d]] if declarada.get(d) in PASTA_DA_CATEGORIA else "biblioteca")

    # a subpasta DENTRO de uma das três (um pack da P88: apps/autorais, sistema/pastas…) também some
    for t in PASTAS_DO_FORMATO:
        troca.setdefault(t, t)

    def novo(caminho, prefixo="icones/"):
        """O caminho de hoje: a pasta de antes vira uma das três, PLANA (o arquivo direto nela)."""
        for d, para in troca.items():
            if caminho == prefixo + d or caminho.rstrip("/") == prefixo + d:
                return prefixo + para + ("/" if caminho.endswith("/") else "")
            if caminho.startswith(prefixo + d + "/"):
                resto = caminho[len(prefixo + d) + 1:]
                if not resto or resto.endswith("/"):
                    return prefixo + para + "/"
                miolo = resto.split("/")
                nome = miolo[-1]
                if len(miolo) > 1 and miolo[-2] != "css-variables" and (d == "mimetypes" or "mimetypes" in miolo[:-1]):
                    base, ext = os.path.splitext(nome)
                    nome = "%s-%s%s" % (base, miolo[-2], ext)   # o flavor do tipo de arquivo vira sufixo
                return prefixo + para + "/" + nome
        return caminho

    saida = {novo(rel): dado for rel, dado in membros.items()}
    for cat, bloco in ic.items():
        if isinstance(bloco, dict):
            for chave in ("desenhos", "mapa"):
                if isinstance(bloco.get(chave), str):
                    bloco[chave] = novo(bloco[chave])
    p["formato"] = 2
    saida["pack.json"] = (json.dumps(p, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    mapa = ((ic.get("apps") or {}).get("mapa") if isinstance(ic.get("apps"), dict) else None)
    if isinstance(mapa, str) and mapa in saida:
        linhas = []
        for linha in saida[mapa].decode("utf-8", "replace").split("\n"):
            util, sep, resto = linha.partition("#")
            nome, dois, alvo = util.partition(":")
            alvo_limpo = alvo.strip()
            if dois and alvo_limpo and not alvo_limpo.startswith((MOTOR, OUTRO_PACK)):
                trocado = novo(alvo_limpo, "")
                util = util.replace(alvo_limpo, trocado, 1) if trocado != alvo_limpo else util
            elif dois and alvo_limpo.startswith("%s%s:" % (OUTRO_PACK, ident)):
                cab = "%s%s:" % (OUTRO_PACK, ident)
                util = util.replace(alvo_limpo, cab + novo(alvo_limpo[len(cab):], ""), 1)
            linhas.append(util + sep + resto)
        saida[mapa] = "\n".join(linhas).encode("utf-8")
    if "PROCEDENCIA.md" in saida:
        linhas = saida["PROCEDENCIA.md"].decode("utf-8", "replace").split("\n")
        for i, linha in enumerate(linhas):
            m = re.match(r"^\|\s*`?(icones/[^`|]+)`?\s*\|", linha)
            if m and novo(m.group(1)) != m.group(1):
                linhas[i] = linha.replace(m.group(1), novo(m.group(1)), 1)
        saida["PROCEDENCIA.md"] = "\n".join(linhas).encode("utf-8")
    return saida


def _formato_dos_arquivos(arquivos):
    """O `formato` do pack.json de `arquivos`, ou 0 quando não se lê."""
    try:
        formato = json.loads(arquivos.get("pack.json", b"{}").decode("utf-8")).get("formato")
    except (UnicodeDecodeError, ValueError, AttributeError):
        return 0
    return formato if isinstance(formato, int) else 0


def _instalar_pack(arquivos, base, ident, seco=False):
    """Grava `arquivos` como o pack `ident` em `base` — e ele só aparece VALIDADO.

    Monta tudo num diretório ao lado, passa o `validar` inteiro, e só então
    renomeia para o lugar: nenhum instante em que exista meio pack na raiz, nem
    um pack que não valida. `seco` monta num temporário do sistema, valida, e
    apaga — é o ensaio, e é a prévia da tela.

    AO LADO É DENTRO DA RAIZ, COM NOME OCULTO, e as duas coisas têm motivo: o
    `rename` só é atômico no mesmo sistema de arquivos, e o `.chegando-…` não é
    visto por ninguém que procura pack — o `pack.json` dele está um nível mais
    fundo do que qualquer varredura olha, e o shell não expande ponto.
    """
    import shutil
    import tempfile
    if seco:
        parede = tempfile.mkdtemp(prefix="meow-pack-")
    else:
        os.makedirs(base, exist_ok=True)
        parede = tempfile.mkdtemp(prefix=".chegando-", dir=base)
    try:
        dir_novo = os.path.join(parede, ident)
        os.makedirs(dir_novo)
        for rel, conteudo in sorted(arquivos.items()):
            alvo = _dentro(dir_novo, rel, rel)
            os.makedirs(os.path.dirname(alvo), exist_ok=True)
            with open(alvo, "wb") as fh:
                fh.write(conteudo)
            os.chmod(alvo, 0o644)
        if _formato_dos_arquivos(arquivos) >= 2:
            for pasta in PASTAS_DO_FORMATO:
                os.makedirs(os.path.join(dir_novo, "icones", pasta), exist_ok=True)
        p, dados, _ = validar(dir_novo)
        if seco:
            return p, dados, None
        destino = os.path.join(base, ident)
        _exigir(not os.path.lexists(destino), f"{destino} apareceu enquanto eu conferia")
        os.rename(dir_novo, destino)
        return p, dados, destino
    finally:
        shutil.rmtree(parede, ignore_errors=True)


def o_que_traz(p, dados, membros):
    """O que o pack traz, para a tela de confirmar e para o terminal.

    O "próprio / herdado de" sai do `origens`, a mesma conta do `meow pack info`
    e do cartão — três telas que não podem contar três packs diferentes.
    """
    org = {cat: (tipo, quem) for cat, tipo, quem in origens(p)}

    def dito(cat):
        tipo, quem = org[cat]
        return {"próprio": "próprio", "herdado": f"herdado de {quem}",
                "motor": "do MeowSystem"}[tipo]
    som = [k for k in (p.get("som") or {}) if not str(k).startswith("_")]
    return {
        "id": p["id"], "nome": p.get("nome") or p["id"], "autor": p.get("autor") or "",
        "heranca": p.get("heranca") or "",
        "flavor_padrao": (p.get("paleta") or {}).get("flavor_padrao") or "",
        "paleta": {f: [c[s] for s in SLOTS] for f, c in dados["flavors"].items()},
        "claros": list(dados.get("claros") or []),
        "icones": sum(1 for r in membros if r.startswith("icones/") and r.lower().endswith(".svg")),
        "icones_de_aplicativo": dito("icones.apps"),
        "imagens": sum(1 for r in membros if r.lower().endswith(EXT_IMAGEM)),
        "ponteiro": dito("cursores"),
        "papeis_de_parede": dito("wallpapers"),
        "som": "próprio" if som else "não traz — vale o do MeowSystem",
        "arquivos": len(membros),
        "bytes": sum(len(c) for c in membros.values()),
        # O claro que ninguém desenhou se declara também ANTES de entrar: o
        # `info` e o cartão já dizem, e a caixa de confirmar mostrava "claro"
        # igual para o derivado e para o desenhado.
        "derivados": claros_derivados(dados),
    }


def resumo_csv(caminho):
    """O `o_que_traz` do pack que um `.csv` solto vira, sem escrever nada.

    O par do `resumo_meowpack`, para a mesma tela de confirmar, e com a mesma
    confiança: o `importar --seco` acabou de montar e validar este pack pelo
    MESMO `montar_novo`. Leva a régua de contraste junto, porque a sprint a pede
    "na importação", e a tela é a importação de quem não abre o terminal.
    """
    arquivos, dados, reprovados = montar_novo(id_do_csv(caminho), caminho)
    r = o_que_traz(json.loads(arquivos["pack.json"]), dados, arquivos)
    r["regua"] = reprovados
    return r


def resumo_meowpack(caminho):
    """O `o_que_traz` de um `.meowpack`, sem escrever nada.

    É a porta da tela de confirmar, e ela confia no que o `importar --seco`
    acabou de validar: quem chama esta função sem aquele passo recebe um
    KeyError de um pack torto, e não um resumo.
    """
    _ident, membros = ler_meowpack(caminho)
    p = json.loads(membros["pack.json"])
    arq = os.path.normpath((p.get("paleta") or {}).get("arquivo", "paleta.json"))
    return o_que_traz(p, json.loads(membros[arq]), membros)


def _imprimir_o_que_traz(r):
    # "0 desenho(s)" sozinho diria que o pack não tem ícone, e um pack que herda
    # mostra na tela os ícones de quem ele herda. A contagem é do que VEIO; a
    # origem é do que a pessoa vai VER.
    print(f"  >>   o que o pack {r['nome']} traz:")
    print(f"         paleta            : {', '.join(r['paleta'])} — 26 cores cada, "
          f"padrão {r['flavor_padrao']}")
    for claro, escuro in r["derivados"].items():
        print(f"         claro derivado    : {claro}, de {escuro!r} pelo método do Latte — "
              f"não é próprio")
    print(f"         ícones            : {r['icones']} desenho(s) no pacote · os de "
          f"aplicativo: {r['icones_de_aplicativo']}")
    print(f"         ponteiro          : {r['ponteiro']}")
    print(f"         papéis de parede  : {r['papeis_de_parede']}")
    print(f"         som               : {r['som']}")
    if r["imagens"]:
        print(f"         imagens           : {r['imagens']}")
    quantos = f"{r['arquivos']:,}".replace(",", ".")
    print(f"         tamanho           : {quantos} arquivo(s), {_mb(r['bytes'])}")


def cmd_importar(caminho, opcoes):
    seco = False
    for op in opcoes:
        if op in ("--seco", "--dry-run"):
            seco = True
        else:
            print(f"  erro não entendi {op!r} — uso: importar <arquivo.meowpack|arquivo.csv> "
                  f"[--seco]", file=sys.stderr)
            return ERRO_USO
    _exigir(os.path.isfile(caminho), f"não achei o arquivo {caminho!r}")
    # A extensão decide, como decide para quem escolhe o arquivo.
    de_csv = caminho.lower().endswith(".csv")
    if de_csv:
        ident = id_do_csv(caminho)
    else:
        ident, membros = ler_meowpack(caminho)
    existe = _pack_existente(ident)
    _exigir(not existe, f"já existe {existe}.\n"
                        f"    Importar por cima trocaria o que está lá sem perguntar, e um pack\n"
                        f"    com o mesmo nome noutra raiz esconderia um dos dois. Para trocar,\n"
                        f"    tire o que está lá primeiro."
                        + (f"\n    Ele é seu: meow pack remover {ident}, ou o «Remover» do cartão."
                           if existe and os.path.dirname(existe) == raiz_da_pessoa() else "")
                        + ("\n    O id sai do nome do CSV: com outro nome, ele vira outro pack."
                           if de_csv else ""))
    if de_csv:
        membros, paleta, reprovados = montar_novo(ident, caminho)
        _noticiar_csv(caminho, paleta, reprovados, sys.stdout)
    p, dados, destino = _instalar_pack(membros, raiz_da_pessoa(), ident, seco)
    r = o_que_traz(p, dados, membros)
    _imprimir_o_que_traz(r)
    if seco:
        print(f"  ~~   instalaria em {os.path.join(raiz_da_pessoa(), ident)} — nada foi escrito")
    else:
        print(f"  ok   instalado em {destino}")
    print("  --   nada foi aplicado: importar é ganhar uma opção, não trocar de tema.")
    print(f"       Para vestir: PACK=\"{ident}\" e FLAVOR=\"{r['flavor_padrao']}\" no meow.conf.")
    return OK


def _til(caminho):
    """O caminho com a casa como `~` — é o que a gaveta do painel mostra.

    A P52 (24/09/2026) tira o nome de usuário do que a tela mostra; a saída do
    `remover` passa pela gaveta, e nasce já sem ele.
    """
    casa = os.path.expanduser("~")
    return "~" + caminho[len(casa):] if caminho.startswith(casa + os.sep) else caminho


# REMOVER UM PACK IMPORTADO
#
# "Pack importado não tem como ser removido: nem botão no cartão, nem rota, nem
# verbo do meow." O `importar` grava em `raiz_da_pessoa()` e nada tirava de lá:
# o pack só saía apagando a pasta à mão.
#
# O `meow pack remover` chama o `cmd_remover`; o painel chama a `remocao` para
# decidir se o cartão ganha o «Remover» e, se não ganha, dizer por quê.
def _quem_herda_de(ident):
    """Os ids dos packs do disco que herdam de `ident`, por qualquer campo."""
    def herdas(no):
        if isinstance(no, dict):
            for chave, valor in no.items():
                if chave in ("heranca", "herda") and isinstance(valor, str):
                    yield valor
                else:
                    yield from herdas(valor)
    quem = set()
    for base in raizes():
        try:
            nomes = os.listdir(base)
        except OSError:
            continue
        for nome in nomes:
            if nome == ident or nome.startswith("."):
                continue
            # O `pack.json` é lido cru, sem o `validar`: um pack que herda deste
            # e não valida por OUTRO motivo continua dependendo dele, e apagar o
            # de quem ele herda só somaria um defeito ao que ele já tem.
            try:
                with open(os.path.join(base, nome, "pack.json"), encoding="utf-8") as fh:
                    p = json.load(fh)
            except (OSError, ValueError):
                continue
            if ident in set(herdas(p)):
                quem.add(nome)
    return sorted(quem)


def remocao(ident, pack_conf="", flavor_conf=""):
    """(diretório, motivo) do `remover`. Levanta Recusa com um id que não é id.

    `diretório` é onde o pack mora na casa da pessoa, e None quando ele não mora
    lá — o cartão de um pack assim não ganha botão nenhum. `motivo` é a frase de
    por que ele não sai, e None quando sai. `pack_conf` e `flavor_conf` são o
    PACK e o FLAVOR do meow.conf, que dizem qual pack está no ar.
    """
    _exigir(RE_ID.match(ident or ""), f"id {ident!r} — só minúsculas, dígitos e hífen")
    casa = os.path.join(raiz_da_pessoa(), ident)
    if os.path.islink(casa) or not os.path.isfile(os.path.join(casa, "pack.json")):
        do_projeto = os.path.join(RAIZ, "packs", ident)
        if os.path.isfile(os.path.join(do_projeto, "pack.json")):
            return None, (f"o {campo(do_projeto, 'nome') or ident} vem com o MeowSystem — "
                          f"mora em packs/ do projeto, e só sai o que o importar gravou")
        return None, (f"não há pack {ident!r} em {_til(raiz_da_pessoa())}, que é onde o "
                      f"importar grava — só de lá um pack sai")
    nome = campo(casa, "nome") or ident
    if ident in (pack_conf, adocao(pack_conf, flavor_conf)[0]):
        return casa, (f"o {nome} está no ar — troque de pack antes, com o «Usar este» "
                      f"de outro cartão ou o meow pack usar")
    herdeiros = [campo(h, "nome") or h for h in _quem_herda_de(ident)]
    if herdeiros:
        return casa, (f"o {', '.join(herdeiros)} herda{'m' if len(herdeiros) > 1 else ''} "
                      f"do {nome} — remova {'aqueles' if len(herdeiros) > 1 else 'aquele'} "
                      f"primeiro")
    return casa, None


def cmd_remover(ident, opcoes):
    seco = False
    for op in opcoes:
        if op in ("--seco", "--dry-run"):
            seco = True
        else:
            print(f"  erro não entendi {op!r} — uso: remover <id> [--seco]", file=sys.stderr)
            return ERRO_USO
    # O PACK E O FLAVOR VÊM DO AMBIENTE, como o `$FLAVOR` do `usar`: é o
    # `meow pack remover` quem carrega o meow.conf e os passa. Sem eles a
    # `adocao` responde o padrão, e o pack no ar pareceria removível.
    casa, motivo = remocao(ident, os.environ.get("PACK") or "", os.environ.get("FLAVOR") or "")
    if motivo:
        print(f"  erro não removo: {motivo}", file=sys.stderr)
        return RECUSADO
    nome = campo(casa, "nome") or ident
    arquivos, bytes_ = 0, 0
    for base, _dirs, nomes in os.walk(casa):
        for n in nomes:
            arquivos += 1
            try:
                bytes_ += os.lstat(os.path.join(base, n)).st_size
            except OSError:
                pass
    peso = f"{arquivos:,}".replace(",", ".") + f" arquivo(s), {_mb(bytes_)}"
    if seco:
        print(f"  ~~   removeria {_til(casa)} — o pack {nome}, {peso}; nada foi apagado")
        return OK
    # SAI INTEIRO OU NÃO SAI: primeiro o `rename` para um oculto AO LADO, e só
    # então o `rmtree`.
    import shutil
    import tempfile
    parede = tempfile.mkdtemp(prefix=".saindo-", dir=raiz_da_pessoa())
    try:
        os.rename(casa, os.path.join(parede, ident))
    except OSError as e:
        shutil.rmtree(parede, ignore_errors=True)
        raise Recusa(f"não consegui tirar {_til(casa)}: {e}")
    shutil.rmtree(parede, ignore_errors=True)
    print(f"  ~~   removido: {_til(casa)} — o pack {nome}, {peso}")
    print("  --   para tê-lo de novo, importe o arquivo dele outra vez")
    return OK


def cmd_novo(ident, opcoes):
    """Cria o pack `ident` a partir do que está no ar — ou de um CSV.

    O QUE ESTÁ NO AR, E COMO CADA PEDAÇO ENTRA
        · a paleta — a que vale AGORA, pela porta de sempre
          (`paleta_do_pack_ativo`): o arquivo inteiro, cada flavor com as 26
          cores, e o `flavor_padrao` é o flavor em uso. Inteiro, e não só o
          flavor em uso, porque o claro é o par dele: sem ele, o modo claro
          cairia no pack anterior (docs/PACKS.md, "claros");
        · o timbre — o `som` do pack no ar com os `SOM_*` do meow.conf por cima,
          que é o que se ouve. Ele entra declarado porque o `som` não é herdado:
          sem a cópia, o pack novo tocaria o sino padrão;
        · o logo — gerado, a inicial sobre o `base` (P15 e P25: "feio e honesto
          é melhor que ausente"), e os créditos, dizendo de onde tudo veio;
        · o RESTO — ícones, capturas do tema, temas de aplicativo, ponteiro —
          vem do pack no ar pela `heranca`, por id. Nenhum caminho absoluto,
          nenhuma segunda cópia do mesmo acervo que defasaria calada.

    COM `--de-csv <arquivo>` — 23/09/2026, P16, item 2
        "Monta o pack a partir disso: valida, deriva o que puder, e escreve o
        `paleta.json` equivalente." A paleta é a do CSV, e NADA vem do ar: nem o
        timbre, nem a herança. O que muda, e por quê, mora em `montar_novo`,
        que é também o que o `importar` de um `.csv` chama.

    O QUE A SPRINT PEDIA E O FORMATO AINDA NÃO GUARDA
        "Os acervos que a pessoa adicionou (ícones, papéis de parede, ponteiro)
        copiados." Medido em 23/09/2026: o formato não tem onde guardar papel de
        parede nem ponteiro DENTRO do pack — nenhum leitor, nem o
        `wallpaper.sh`, nem o `cursor.sh`, abre um pack; o ponteiro próprio é a
        P12. E a porta de ícone avulso (`assets/icones/overrides/`) não tem
        instalador. Copiar para lá seria o arquivo sem leitor que o `validar`
        existe para denunciar. O verbo diz isso na tela, em vez de fingir.

    ONDE ELE ESCREVE
        Em `$MEOW_PACKS` quando ela existe — a raiz de teste, "sem instalar
        nada" —, e senão em `packs/` do projeto, onde a sprint o põe e de onde
        um pack se publica por commit. Por ser gesto explícito, e com nome, não
        é a sujeira de uso que a P21 tirou do repositório.
    """
    seco, csv = False, None
    it = iter(opcoes)
    for op in it:
        if op in ("--seco", "--dry-run"):
            seco = True
        # Sem o arquivo, ou com um segundo `--de-csv`, é erro de uso: dois CSV
        # não viram uma paleta, e um `--seco` no lugar do arquivo seria lido
        # como um CSV chamado `--seco`.
        elif op == "--de-csv" and csv is None:
            csv = next(it, None)
            if not csv or csv.startswith("-"):
                print("  erro o --de-csv pede o arquivo — uso: novo <id> --de-csv <cores.csv>",
                      file=sys.stderr)
                return ERRO_USO
        else:
            print(f"  erro não entendi {op!r} — uso: novo <id> [--de-csv <arquivo.csv>] [--seco]",
                  file=sys.stderr)
            return ERRO_USO
    _exigir(RE_ID.match(ident), f"id {ident!r} — só minúsculas, dígitos e hífen")
    existe = _pack_existente(ident)
    _exigir(not existe, f"já existe {existe} — escolha outro nome")

    arquivos, paleta, reprovados = montar_novo(ident, csv)
    if csv:
        _noticiar_csv(csv, paleta, reprovados, sys.stdout)
    base = os.environ.get("MEOW_PACKS") or os.path.join(RAIZ, "packs")
    p, _dados, destino = _instalar_pack(arquivos, base, ident, seco)
    if seco:
        print(f"  ~~   criaria {os.path.join(base, ident)}/ — nada foi escrito")
    else:
        print(f"  ok   {destino}/")
    de, flavor = p["heranca"], p["paleta"]["flavor_padrao"]
    if csv:
        print(f"       de {os.path.basename(csv)}: a paleta ({len(paleta['flavors'])} flavor(s), "
              f"padrão {flavor}), os ícones autorais nas cores dela, um logo gerado e os créditos")
        print(f"  --   o resto vem do {de!r}, o pack padrão, pela herança — "
              f"meow pack info {ident} diz o quê")
        return OK
    print(f"       a partir do {de!r}: a paleta ({len(paleta['flavors'])} flavor(s), "
          f"padrão {flavor}), " + ("o timbre, " if "som" in p else "") + "um logo gerado e os créditos")
    print(f"  --   o resto vem do {de!r} pela herança — meow pack info {ident} diz o quê")
    print("  --   papel de parede e ponteiro não entram: o formato ainda não tem onde "
          "guardá-los dentro de um pack")
    return OK


def montar_novo(ident, csv=None):
    """(arquivos, paleta, reprovados) do pack que o `novo` escreve. Não grava nada.

    `arquivos` é {caminho no pack: bytes}, pronto para o `_instalar_pack`, que é
    quem grava e valida; `reprovados` é a régua de contraste, vazia sem CSV.

    SAIU DE DENTRO DO `cmd_novo` NA SEGUNDA METADE DA P16 [23/09/2026]
        A sprint pede o `.csv` também na tela, e a tela importa. Duas montagens
        do mesmo "CSV vira pack", uma no `novo` e outra no `importar`, é o
        defeito que custou a primeira revisão da P10: uma regra que o painel já
        tinha, refeita em awk, divergindo calada. Aqui a regra é uma, e os dois
        verbos a chamam; eles diferem só no lugar onde gravam.

    COM `csv`, O QUE MUDA E POR QUÊ
        · a paleta é `paleta_de_csv` — as recusas com a linha, o claro derivado
          quando o CSV não traz um —, e o `flavor_padrao` é o primeiro flavor
          do CSV, o mesmo de onde o claro se deriva;
        · a HERANÇA É O PACK PADRÃO, e não o no ar. Sem `heranca`, ícones,
          ponteiro e papéis de parede não sobem para pack nenhum. E o pack no ar
          não serve: o mesmo CSV daria um pack numa máquina vestida de Dracula
          e outro numa de Catppuccin, e o `importar` — que é por onde a tela
          chega aqui — não depende da máquina. O padrão é o único pack que toda
          instalação tem;
        · NADA DO AR: nem o timbre do meow.conf, nem o accent dele no logo (é o
          `mauve` de sempre, o mesmo dos autorais). O CSV é a declaração
          inteira de quem o fez;
        · os ícones autorais nascem construídos nas cores do CSV — ver
          `_autorais_construidos`.
    """
    import time
    nome = " ".join(parte.capitalize() for parte in ident.split("-"))
    # A linha de cima capitaliza cada pedaço do id, e o painel perguntou
    # «Importar o Tinta De Teste?» por um arquivo chamado `tinta de teste.csv`:
    # o «De» maiúsculo saiu da regra, e não do arquivo.
    if csv:
        try:
            do_arquivo = id_do_csv(csv) == ident
        except Recusa:
            do_arquivo = False
        solto = re.sub(r"[\s_-]+", " ", os.path.splitext(os.path.basename(csv))[0]).strip()
        if do_arquivo and solto:
            nome = solto[0].upper() + solto[1:]
    data = time.strftime("%d/%m/%Y")
    som, reprovados = {}, []
    if csv:
        pf, _, _dir_fonte = validar(PACK_PADRAO, silencioso=True)
        # O prefixo diz que a recusa é do CSV: sem ele, a porta geral do `main`
        # imprimiria só "pack recusado: cores.csv:5: …", e quem lê "pack" vai
        # procurar o defeito num pack.json que ainda nem existe.
        try:
            paleta = paleta_de_csv(csv)
            reprovados = regua_de_contraste(paleta, _referencia_clara())
        except Recusa as e:
            raise Recusa(f"o CSV não virou paleta: {e}")
        bruto_paleta = (json.dumps(paleta, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
        flavor, accent = next(iter(paleta["flavors"])), ACCENT_PADRAO_DO_LOGO
    else:
        pf, _, _dir_fonte = validar(os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO,
                                    silencioso=True)
        arq_paleta = paleta_do_pack_ativo()
        try:
            with open(arq_paleta, "rb") as fh:
                bruto_paleta = fh.read()
            paleta = json.loads(bruto_paleta)
            _exigir(isinstance(paleta.get("flavors"), dict) and paleta["flavors"], "sem flavors")
        except (OSError, ValueError, AttributeError, Recusa) as e:
            raise Recusa(f"a paleta no ar ({arq_paleta}) não serve de ponto de partida: {e}")
        flavor, accent = _flavor_e_accent(pf, paleta)

        # Só o timbre: o `tema` é uma pasta DO pack de onde se parte, e o novo
        # a alcança pela herança, sem copiá-la.
        som = {k: v for k, v in (pf.get("som") or {}).items()
               if not str(k).startswith("_") and k != "tema"}
        for chave, var in SOM_NO_CONF.items():
            bruto = (os.environ.get(var) or "").strip()
            if bruto:
                try:
                    som[chave] = float(bruto)
                except ValueError:
                    raise Recusa(f"{var}={bruto!r} no meow.conf não é número — o timbre no ar "
                                 f"não tem como virar pack")

    de_quem = pf.get("nome") or pf["id"]
    if csv:
        nome_csv = os.path.basename(csv)
        nota = (f"Nasceu em {data} de {nome_csv}, um CSV de cores: a paleta é a dele. O que "
                f"este arquivo não declara vem do pack padrão, {pf['id']!r}, pela herança — "
                f"`meow pack info {ident}` diz o quê, categoria a categoria.")
        frase = f"Feito de {nome_csv}; o resto vem do {de_quem}."
    else:
        nota = (f"Nasceu de `meow pack novo` em {data}, a partir do pack {pf['id']!r}, "
                f"que estava no ar. O que este arquivo não declara vem dele, pela "
                f"herança — `meow pack info {ident}` diz o quê, categoria a categoria.")
        frase = f"Nasceu do {de_quem}, com as cores que estavam no ar."
    novo = {
        "_nota": nota,
        "formato": FORMATO_MAX,
        "id": ident,
        "nome": nome,
        "creditos": "CREDITOS.md",
        "heranca": pf["id"],
        "vitrine": {"capa": LOGO},
        "paleta": {"arquivo": "paleta.json", "flavor_padrao": flavor},
        "cosmic": {"nome_da_paleta": f"{ident}-<flavor>"},
    }
    if csv:
        novo["icones"] = {"autorais": {"gerar": True, "desenhos": PASTA_AUTORAIS}}
    if len(frase) <= TETO_DESCRICAO_CURTA:
        novo["vitrine"]["descricao_curta"] = frase
    if som:
        novo["som"] = som

    svg = logo_gerado(nome, ident)
    svg = _aplicar_papeis(svg, ET.fromstring(svg), _cores_do_logo(paleta, flavor, accent))
    if csv:
        abertura = (f"Este pack nasceu em {data} de `{nome_csv}`, um CSV de cores, e herda o "
                    f"resto do pack padrão, **{de_quem}** (`{pf['id']}`).\n\n")
        sobre_paleta = (f"`paleta.json` é a tradução de `{nome_csv}` (o mesmo `meow pack "
                        f"de-csv`): as cores são de quem fez o CSV.")
        for claro, escuro in claros_derivados(paleta).items():
            sobre_paleta += (f" O flavor `{claro}` não foi desenhado: foi derivado de "
                             f"`{escuro}` pelo método do Latte (docs/PACKS.md, \"Se o seu tema "
                             f"não tem um claro\").")
        sobre_paleta += "\n\n"
        autorais = (f"## Os ícones autorais\n\n"
                    f"`icones/apps/autorais/` foi desenhado pelo `meow pack construir`, nas cores "
                    f"desta paleta: os desenhos são os do MeowSystem, e se refazem quando a "
                    f"paleta muda.\n\n")
    else:
        origem = ", ".join(x for x in (f"autor {pf['autor']}" if pf.get("autor") else "",
                                       f"licença {pf['licenca']}" if pf.get("licenca") else "",
                                       (pf.get("vitrine") or {}).get("site") or "") if x)
        abertura = (f"Este pack nasceu em {data} de `meow pack novo`, a partir do pack "
                    f"**{de_quem}** (`{pf['id']}`), que estava no ar.\n\n")
        sobre_paleta = (f"`paleta.json` é a do `{pf['id']}`, copiada como estava"
                        + (f" ({origem})" if origem else "") + ". De onde vieram aquelas cores, o "
                        f"CREDITOS.md do `{pf['id']}` conta.\n\n")
        autorais = ""
    creditos = (
        f"# Créditos do pack {nome}\n\n"
        + abertura
        + "## A paleta\n\n"
        + sobre_paleta
        + f"## O logo\n\n"
        f"`logo.svg` foi gerado pelo MeowSystem: a inicial do nome sobre o `base` da "
        f"paleta. É seu para redesenhar — mantenha as `class`, que são o papel de "
        f"cada forma.\n\n"
        + autorais
        + f"## Os ícones\n\n"
        f"Moram em três pastas, e só nelas: `icones/apps/` (o desenho ligado a um "
        f"programa, pelo `icones/apps.map`), `icones/sistema/` (pastas, tipos de "
        f"arquivo, status) e `icones/biblioteca/` (o resto, para escolher no painel; "
        f"sem subpasta: o flavor vai no nome). O que o pack não traz vem do pack-base do "
        f"MeowSystem.\n\n"
        + f"## O resto\n\n"
        f"Tudo o que o `pack.json` não declara vem do `{pf['id']}`, pela herança, e "
        f"é dele a procedência. `meow pack info {ident}` diz o que é próprio e o que "
        f"é herdado.\n\n"
        f"## Se entrar arte de terceiro\n\n"
        f"Copie-a para dentro do pack e ponha uma linha no `PROCEDENCIA.md` — de "
        f"onde veio, sob que licença, em que data (ver docs/PACKS.md, \"Fonte e "
        f"derivados\"). O `meow pack exportar` recusa arte sem licença escrita ali.\n")
    arquivos = {
        "pack.json": (json.dumps(novo, indent=2, ensure_ascii=False) + "\n").encode("utf-8"),
        "paleta.json": bruto_paleta,
        LOGO: svg.encode("utf-8"),
        "CREDITOS.md": creditos.encode("utf-8"),
    }
    if csv:
        arquivos.update(_autorais_construidos(ident, arquivos))
    return arquivos, paleta, reprovados


def _autorais_construidos(ident, arquivos):
    """{icones/apps/autorais/<nome>-<flavor>.svg: bytes} do pack que `arquivos` descreve.

    POR QUE O PACK DE CSV PRECISA, E O DO AR NÃO [23/09/2026, P16]
        O `novo` sem CSV copia a paleta no ar e herda do pack no ar: os flavors
        são os MESMOS, e os autorais herdados (`cosmic-term-mocha.svg`…) casam
        com eles. O CSV traz flavors que ninguém desenhou. Medido num pack de
        CSV montado à mão, com a `heranca` e nada mais: o `info` dizia
        `icones.autorais  HERDADO de catppuccin  44 desenho(s)` e nenhum flavor
        dele, porque os 44 são mocha, macchiato, frappe e latte. A tela contava
        como herdados ícones que não vestem flavor nenhum do pack.
    O CONSERTO É O VERBO QUE JÁ EXISTE, E NÃO UM SEGUNDO GERADOR
        `icones.autorais.gerar` + `meow pack construir` é como o Dracula tem os
        onze dele nos dois flavors. Medido antes de ligar: no mesmo pack de CSV
        com o `gerar`, o `construir` escreveu 22 SVG (11 desenhos x 2 flavors,
        o claro derivado incluído) SÓ em `<pack>/icones/autorais/`, com a rede
        cortada (`unshare --net`), e o `info` passou a `PRÓPRIO, 22
        desenho(s), 2 flavor(s)`. Então o pack de CSV nasce assim: o verbo roda
        num temporário, com o pack montado lá, e os SVG voltam para o
        dicionário que o `_instalar_pack` grava e valida — o pack não existe um
        instante declarando uma pasta vazia.
    COMO PROCESSO, E NÃO CHAMADO DAQUI
        O `construir` imprime uma linha por desenho, o gerador escreve no
        STDOUT dele, e quem chega aqui pela tela é o servidor, cujo STDOUT é o
        terminal do `run.sh`. Capturado, o que ele disse só aparece na recusa.
    """
    import subprocess
    import tempfile
    with tempfile.TemporaryDirectory(prefix="meow-novo-") as tmp:
        dir_pack = os.path.join(tmp, ident)
        for rel, conteudo in arquivos.items():
            alvo = _dentro(dir_pack, rel, rel)
            os.makedirs(os.path.dirname(alvo), exist_ok=True)
            with open(alvo, "wb") as fh:
                fh.write(conteudo)
        # A pasta nasce vazia para o `validar` do `construir` não recusar o
        # `desenhos` que ainda não tem nada — é ele que vai enchê-la.
        pasta = os.path.join(dir_pack, PASTA_AUTORAIS)
        os.makedirs(pasta)
        r = subprocess.run([sys.executable, os.path.abspath(__file__), "construir", dir_pack],
                           capture_output=True, text=True, stdin=subprocess.DEVNULL)
        if r.returncode != 0:
            raise Recusa("os ícones autorais nas cores do CSV não nasceram — o `construir` "
                         "disse:\n    " + ((r.stderr or r.stdout).strip() or f"saída {r.returncode}"))
        saida = {}
        for nome in sorted(os.listdir(pasta)):
            if nome.endswith(".svg"):
                with open(os.path.join(pasta, nome), "rb") as fh:
                    saida[PASTA_AUTORAIS + nome] = fh.read()
        return saida


# As fontes são as três pastas e os mapas de `icones/`, e o `logo.svg` (o ícone
# do lançador), de cada pack de onde o tema deriva: o no ar, os que ele herda e
# o pack-base.
def packs_dos_derivados(ref=None):
    """[(id, diretório)] dos packs de onde o tema deriva, sem repetir."""
    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    saida, vistos = [], set()

    def junta(r):
        d = achar(r) if r else None
        if d and os.path.realpath(d) not in vistos:
            vistos.add(os.path.realpath(d))
            saida.append((os.path.basename(d), d))
            return d
        return None

    pendentes = [ref]
    while pendentes:
        d = junta(pendentes.pop(0))
        if not d:
            continue
        pendentes.append(campo(d, "heranca"))
        ic = campo(d, "icones") or {}
        for bloco in (ic.values() if isinstance(ic, dict) else ()):
            if isinstance(bloco, dict) and isinstance(bloco.get("herda"), str):
                pendentes.append(bloco["herda"])
    junta(PACK_BASE)
    return saida


def _sha_sem_fim(caminho):
    with open(caminho, "rb") as fh:
        return hashlib.sha256(fh.read().rstrip(b"\n")).hexdigest()


def _arvores_dos_derivados(d):
    """O `icones/` e as três pastas de um pack, cada uma só se cair dentro dele
    (a regra da P78: uma pasta que é link para fora não entra)."""
    saida = []
    for rel in ["icones"] + ["icones/" + p for p in PASTAS_DO_FORMATO]:
        try:
            saida.append(_dentro(d, rel, rel))
        except Recusa:
            continue
    return [p for p in saida if os.path.isdir(p)]


def fontes_dos_derivados(ref=None):
    """{caminho real: sha256} de cada fonte do tema (ver o bloco acima)."""
    fontes = {}
    for _id, d in packs_dos_derivados(ref):
        arvores = _arvores_dos_derivados(d)
        cands = [os.path.join(d, LOGO)]
        if arvores and os.path.basename(arvores[0]) == "icones":
            cands += [os.path.join(arvores[0], a) for a in sorted(os.listdir(arvores[0]))
                      if a.endswith(".map")]
        for arvore in arvores[1:] if arvores and os.path.basename(arvores[0]) == "icones" else arvores:
            for raiz, dirs, arqs in os.walk(arvore):
                dirs[:] = [x for x in dirs if not os.path.islink(os.path.join(raiz, x))]
                cands += [os.path.join(raiz, a) for a in arqs]
        for c in cands:
            if os.path.isfile(c) and not os.path.islink(c):
                fontes[os.path.realpath(c)] = _sha_sem_fim(c)
    return fontes


def pastas_dos_derivados(ref=None):
    """Os diretórios que a unidade `.path` vigia: a raiz de cada pack (o
    logo), o `icones/` (os mapas) e cada pasta dentro das três."""
    pastas = []
    for _id, d in packs_dos_derivados(ref):
        pastas.append(os.path.realpath(d))
        for arvore in _arvores_dos_derivados(d):
            for raiz, dirs, _arqs in os.walk(arvore):
                dirs[:] = sorted(x for x in dirs if not os.path.islink(os.path.join(raiz, x)))
                pastas.append(os.path.realpath(raiz))
    return [p for i, p in enumerate(pastas) if os.path.isdir(p) and p not in pastas[:i]]


def cmd_derivados(ref, o_que, resto):
    if o_que == "fontes":
        for caminho, sha in sorted(fontes_dos_derivados(ref).items()):
            print(f"{caminho}\t{sha}")
        return OK
    if o_que == "pastas":
        for pasta in pastas_dos_derivados(ref):
            print(pasta)
        return OK
    # `derivados <id> copias <tema> <sha>...`: os arquivos do tema cujo
    # conteúdo é o de uma fonte que saiu — a prova de que são cópia dela.
    if o_que == "copias" and resto:
        tema, procura = resto[0], set(resto[1:])
        for raiz, _dirs, arqs in os.walk(tema):
            for a in sorted(arqs):
                c = os.path.join(raiz, a)
                if not os.path.islink(c) and os.path.isfile(c) and _sha_sem_fim(c) in procura:
                    print(c)
        return OK
    print("  erro uso: derivados <id> fontes|pastas|copias <tema> <sha>...", file=sys.stderr)
    return ERRO_USO


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


def _na_cadeia(trilha, ref=None):
    """O valor de `trilha` no pack ou no primeiro da herança que o declara."""
    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        if not achar(ref):
            break
        valor = campo(ref, trilha)
        if valor not in (None, ""):
            return ref, valor
        ref = campo(ref, "heranca")
    valor = campo(PACK_BASE, trilha)
    return (PACK_BASE, valor) if valor not in (None, "") else (None, None)


def pasta_do_mascote(ref=None):
    """A pasta `mascote/` do pack, pela herança; sem nenhuma, a do pack-base."""
    achado = acervo("mascote.desenhos", ref=ref) if ref is None or ref else None
    if not achado:
        achado = acervo("mascote.desenhos", ref=PACK_BASE)
    return (achado or os.path.join(RAIZ, "packs", PACK_BASE, "mascote")).rstrip(os.sep)


def mascote_padrao(fase, ref=None):
    """O mascote de fábrica do pack para a fase (`dia`/`noite`) do modo `hora`."""
    ref = ref or None
    return _na_cadeia("mascote." + fase, ref)[1] or ""


def origem_dos_wallpapers(ref=None):
    """`origens.wallpapers` do pack (ou da herança), com os caminhos já absolutos."""
    ref = ref or None
    dono, decl = _na_cadeia("origens.wallpapers", ref)
    if not isinstance(decl, dict):
        return {}
    dir_pack = achar(dono) or ""
    saida = {"pack": dono}
    for chave, valor in decl.items():
        if chave.startswith("_") or isinstance(valor, (dict, list)) and chave != "ignorar":
            continue
        if chave in ("desenhos", "curadoria"):
            alvo = _dentro(dir_pack, valor, "origens.wallpapers." + chave)
            if not os.path.exists(alvo):
                continue
            valor = alvo
        elif chave == "ignorar":
            valor = " ".join(valor)
        elif chave in RE_CONF_PAPEL and not (isinstance(valor, str) and RE_CONF_PAPEL[chave].match(valor)):
            continue
        saida[chave] = valor
    # As FOTOS prontas do pack (P102): imagens soltas em `wallpapers/`, com o
    # nome que terão no acervo. Havendo, o `wallpaper.sh` semeia delas, sem rede.
    fotos = os.path.join(dir_pack, "wallpapers") if dir_pack else ""
    try:
        if fotos and any(e.is_file(follow_symlinks=False) and e.name.lower().endswith(EXT_FOTO)
                         for e in os.scandir(fotos)):
            saida["fotos"] = fotos
    except OSError:
        pass
    return saida


EXT_FOTO = (".png", ".jpg", ".jpeg", ".webp")


def colecoes_alheias(ref=None):
    """(prefixos, nomes) dos papéis de parede dos OUTROS packs: o prefixo que o
    `wallpaper.sh` põe no nome e os nomes da curadoria de cada um. O pack que
    herda a mesma origem do pack no ar não é outro."""
    def origem(r):
        try:
            o = origem_dos_wallpapers(r)
        except (Recusa, OSError, ValueError):
            return "", ""
        return str(o.get("prefixo") or "cat"), str(o.get("curadoria") or "")

    def nomes_da_curadoria(caminho):
        try:
            with open(caminho, encoding="utf-8", errors="replace") as fh:
                for linha in fh:
                    nome = linha.split("\t", 1)[0].strip()
                    if nome and not nome.startswith("#") and nome != "arquivo":
                        yield nome
        except OSError:
            return

    meu_pref, meu_cur = origem(ref or None)
    prefixos, nomes, vistos = set(), set(), set()
    for base in raizes():
        try:
            ids = sorted(os.listdir(base))
        except OSError:
            continue
        for pid in ids:
            dir_pack = os.path.join(base, pid)
            if pid in vistos or not os.path.isfile(os.path.join(dir_pack, "pack.json")):
                continue
            vistos.add(pid)
            pref, cur = origem(dir_pack)
            if pref and pref != meu_pref:
                prefixos.add(pref)
            if cur and os.path.realpath(cur) != (os.path.realpath(meu_cur) if meu_cur else ""):
                nomes.update(nomes_da_curadoria(cur))
    return sorted(prefixos), sorted(nomes)


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
        if verbo == "derivados" and len(argv) >= 4:
            return cmd_derivados(argv[2] or None, argv[3], argv[4:])
        if verbo == "hoje" and len(argv) == 3:
            print(caminho_de_hoje(argv[2]))
            return OK
        # OS DOIS ARGUMENTOS VÊM SEMPRE, VAZIOS OU NÃO: `adocao "" mocha` é o
        # conf de fábrica, e um verbo que aceitasse um só teria de adivinhar
        # qual dos dois chegou.
        if verbo == "adocao" and len(argv) == 4:
            ident, dir_pack, recusado = adocao(argv[2], argv[3])
            print(f"pack={ident}")
            print(f"dir={dir_pack}")
            print(f"recusado={recusado}")
            # O NOME DE TELA VAI JUNTO: o cabeçalho do `install.sh` dizia
            # «Catppuccin» com qualquer pack no ar, e o nome é o que o
            # `pack.json` declara, lido aqui uma vez.
            print(f"nome={campo(ident, 'nome') or ident}")
            # A página já a seguia pelo `vocabulario`; o shell caía no `mocha`.
            print(f"flavor_padrao={campo(ident, 'paleta.flavor_padrao') or ''}")
            return OK
        # OS TRÊS VERBOS DA CAPTURA NÃO RECEBEM `<id>`, e os outros recebem.
        # Quem pergunta por uma captura é sempre o desktop VIVO — o
        # `aplicar_tema.sh`, o `meow tema`, o pré-voo.
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
        if verbo == "escolhas" and len(argv) == 2:
            return cmd_escolhas()
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
        # O `[id]` VAZIO É O PACK ATIVO, como no verbo `app`: o shell passa
        # `"$(meow_pack_dir)"`, que é vazio quando o pack no ar é o padrão, e
        # uma string vazia não é pack nenhum — ela cai em `MEOW_PACK_DIR` e, sem
        # ele, no padrão, pela mesma `_ref_ativa` de todo o resto.
        if verbo == "ponteiro" and len(argv) in (2, 3):
            pt = ponteiro((argv[2] if len(argv) == 3 else "") or None)
            if not pt:
                return RECUSADO
            print(f"pack={pt['pack']}")
            print(f"dir={pt['dir']}")
            print(f"valor={pt['valor']}")
            # O BAIXADO TRAZ A ORIGEM: as três linhas só existem nele, e o
            # ponteiro de dentro do pack continua saindo em três linhas — é o
            # que o `cursor.sh` e o `tests/pack.sh` já leem.
            for chave in ("url", "sha256", "pasta"):
                if pt.get(chave):
                    print(f"{chave}={pt[chave]}")
            return OK
        if verbo == "tipografia" and len(argv) in (2, 3):
            # SAI 0 COM A LISTA VAZIA, e 1 só na recusa.
            quem, lista = tipografia((argv[2] if len(argv) == 3 else "") or None)
            for nome, origem, soma in lista:
                print(f"{quem}\t{nome}\t{origem}\t{soma or '-'}")
            return OK
        if verbo == "base-icones" and len(argv) in (2, 3):
            # O `ICONES_BASE` VEM DO AMBIENTE, como o `ICONES_FLAVOR` do
            # `flavor-icones`: é de lá que o `construir_icones.sh` o recebe.
            quem, tema, decl = base_que_vale((argv[2] if len(argv) == 3 else "") or None,
                                             os.environ.get("ICONES_BASE"))
            print(f"quem={quem}")
            print(f"tema={tema}")
            for chave in ("pack", "url", "sha256", "pasta"):
                print(f"{chave}={(decl or {}).get(chave, '')}")
            # Uma linha por camada de trás, na ordem do `Inherits=`:
            # `atras=<url><TAB><sha256><TAB><pasta>`. Nenhuma quando o
            # pack traz uma base só, ou quando o conf vence.
            for c in (decl or {}).get("por_tras", []):
                print(f"atras={c['url']}\t{c['sha256']}\t{c['pasta']}")
            return OK
        if verbo == "tema-icones" and len(argv) in (2, 3, 4):
            # `nome=` e `comentario=`, para o shell ler com `sed`. Ver
            # `tema_de_icones`.
            nome, comentario = tema_de_icones((argv[2] if len(argv) >= 3 else "") or None,
                                              argv[3] if len(argv) == 4 else "")
            print(f"nome={nome}")
            print(f"comentario={comentario}")
            return OK
        if verbo == "ocultar" and len(argv) in (2, 3):
            # Um id por linha; nenhuma quando o pack não esconde nada.
            for nome in ocultar_do_pack((argv[2] if len(argv) == 3 else "") or None):
                print(nome)
            return OK
        if verbo == "base-apelidos" and len(argv) == 2:
            # A mesma porta do `base-icones`: o `ICONES_BASE` vem do ambiente,
            # e as duas linhas saem sempre (o `dir=` vazio é "não está no
            # disco"), para o shell ler com `sed`. Ver `base_dos_apelidos`.
            tema, onde = base_dos_apelidos(os.environ.get("ICONES_BASE"))
            print(f"tema={tema}")
            print(f"dir={onde}")
            return OK
        if verbo == "info" and len(argv) == 3:
            return cmd_info(argv[2])
        if verbo == "usar" and len(argv) in (3, 4):
            # A saída é lida pelo shell com `sed`, linha a linha, e NUNCA com
            # `eval`: o id passou pelo RE_ID e o flavor pelo RE_FLAVOR_CONF, e
            # ainda assim avaliar texto vindo de um pack de terceiro seria dar a
            # ele uma porta que o formato inteiro existe para não abrir.
            ident, flavor, porque = plano_de_uso(
                argv[2], argv[3] if len(argv) == 4 else None,
                os.environ.get("FLAVOR") or None)
            print(f"PACK={ident}")
            print(f"FLAVOR={flavor}")
            print(f"PORQUE={porque}")
            return OK
        if verbo == "flavor-icones" and len(argv) in (2, 3):
            # OS DOIS VALORES VÊM DO AMBIENTE, como o `$FLAVOR` do `usar`: é de
            # lá que os `icones_*.sh` os recebem (o `install.sh` e o `bin/meow`
            # passam o `ICONES_FLAVOR` e exportam o conf), e repeti-los na linha
            # de comando seria uma segunda declaração do mesmo par.
            achado = flavor_de_icones((argv[2] if len(argv) == 3 else "") or None,
                                      os.environ.get("ICONES_FLAVOR"),
                                      os.environ.get("FLAVOR"))
            if not achado:
                return RECUSADO
            print(achado)
            return OK
        if verbo == "pintados" and len(argv) in (4, 5):
            # `--temporario`: pinta numa pasta nova do TMPDIR (quem só confere não escreve na casa)
            temporario = len(argv) == 5 and argv[4] == "--temporario"
            print(pintar_mimetypes(argv[2] or None, argv[3], temporario=temporario))
            return OK
        if verbo == "construir" and len(argv) in (3, 4):
            # O `--seco` é a mesma promessa do `MEOW_DRY_RUN` do lado shell: diz
            # o que faria e não escreve. Aceito pelos dois nomes porque quem
            # chama daqui é o `bin/meow`, que já traduz o ambiente em flag.
            return cmd_construir(argv[2], seco=(len(argv) == 4 and argv[3] in ("--seco", "--dry-run")))
        if verbo == "novo" and len(argv) >= 3:
            return cmd_novo(argv[2], argv[3:])
        if verbo == "exportar" and len(argv) >= 3:
            return cmd_exportar(argv[2], argv[3:])
        if verbo == "importar" and len(argv) >= 3:
            return cmd_importar(argv[2], argv[3:])
        if verbo == "remover" and len(argv) >= 3:
            return cmd_remover(argv[2], argv[3:])
        if verbo == "caminho" and len(argv) == 4:
            return cmd_caminho(argv[2], argv[3])
        if verbo == "app" and len(argv) == 4:
            # O `ref` vem por argumento e não do ambiente: quem chama do shell é
            # o `meow_app_tema_do_pack`, que já resolveu o pack ativo pela mesma
            # porta que todo o resto (`meow_pack_dir`).
            quem, valor = tema_de_app(argv[3], ref=argv[2] or None)
            if quem is None or valor is None:
                return RECUSADO
            # BOOLEANO SAI COMO `sim`/`nao`, e não como o `True` do Python: quem
            # lê é um `case` de shell, e `[ "$x" = "True" ]` seria o idioma de
            # outra linguagem vazando para dentro deste.
            if isinstance(valor, bool):
                valor = "sim" if valor else "nao"
            print(f"pack={quem}")
            print(f"valor={valor}")
            return OK
        if verbo == "mascote" and len(argv) in (2, 3):
            print(pasta_do_mascote(argv[2] if len(argv) == 3 else None))
            return OK
        if verbo == "mascote-padrao" and len(argv) == 4 and argv[3] in ("dia", "noite"):
            nome = mascote_padrao(argv[3], argv[2])
            if not nome:
                return RECUSADO
            print(nome)
            return OK
        if verbo == "colecoes-alheias" and len(argv) == 3:
            prefixos, nomes = colecoes_alheias(argv[2] or None)
            for p in prefixos:
                print(f"prefixo\t{p}")
            for n in nomes:
                print(f"nome\t{n}")
            return OK
        if verbo == "wallpapers" and len(argv) == 3:
            for chave, valor in sorted(origem_dos_wallpapers(argv[2]).items()):
                print(f"{chave}={valor}")
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
    except Falta as e:
        print(f"  erro {e}", file=sys.stderr)
        return SEM_DEPENDENCIA
    print(__doc__.strip(), file=sys.stderr)
    return ERRO_USO


if __name__ == "__main__":
    sys.exit(main(sys.argv))

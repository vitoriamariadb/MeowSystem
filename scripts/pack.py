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
                                 `nome<TAB>fonte<TAB>camada`. O pack no ar
                                 vence o resgate do motor para o mesmo nome;
                                 duas linhas de um nome é empate. Ver `fontes`.
    fonte   <nome> [id]          as linhas de `fontes` daquele nome. 0 = uma
                                 fonte só; 1 = nenhuma, ou mais de uma. O
                                 resgate que o pack pôs atrás vai para o stderr.
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
                                 1 = ninguém na cadeia traz. Ver `ponteiro`.
    tipografia [id]              as FONTES de texto que o pack alcança, uma por
                                 linha: `pack<TAB>nome<TAB>origem<TAB>sha256`.
                                 Não é o verbo `fontes`, que é de ícone (P28).
                                 Ver `tipografia`.
    novo    <id> [--de-csv <arquivo.csv>] [--seco]
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
    # O PONTEIRO E AS FONTES — 23/09/2026, sprint P12. Os dois nasceram com
    # leitor no mesmo commit: o `proprio` do ponteiro é lido pelo `cursor.sh`
    # (antes de baixar) e pelo painel (`_cursor_pastas_do_valor`); a lista de
    # fontes, pelo `instalar_fontes.sh`, pelo verbo `tipografia`. O `herda` das
    # fontes vai escrito por extenso porque a trilha tem DOIS segmentos, e a
    # máscara `*.*.herda` pede três.
    "origens.cursores.proprio",
    "fontes.proprio",
    "fontes.herda",
    # O FLAVOR DOS ÍCONES DE ARQUIVO HERDADOS — 23/09/2026, sprint P10. O Dracula
    # o declarava desde que nasceu ("o macchiato é o vizinho mais próximo em
    # luminosidade") e ele estava na lista de mortos do aviso. Quem lê agora é o
    # `vocabulario`, e por ele o painel: a «Variante dos ícones de arquivo» de um
    # pack que herda mimetypes oferece o flavor que ESTE pack escolheu, com o nome
    # do dono ao lado — e não os quatro sabores do Catppuccin soltos numa máquina
    # vestida de Dracula. O shell passou a lê-lo na P31 (23/09/2026), pela mesma
    # regra do painel: o `flavor_de_icones`, logo acima do `vocabulario`.
    "icones.mimetypes.flavor",
    # O `gerar` DOS AUTORAIS TINHA LEITOR, E O AVISO DIZIA QUE NÃO — 23/09/2026,
    # sprint P16. O `cmd_construir` o lê desde a P29 (é o único "derivado" que um
    # pack declara), e ele seguia na lista de mortos do Dracula. Passou a doer
    # quando o `novo --de-csv` nasceu declarando-o: o `validar` do pack que o
    # próprio MeowSystem acabou de escrever dizia "não faz nada" de um campo que
    # é o motivo de os ícones dele estarem nas cores dele.
    # OS DOIS QUE O AVISO CHAMAVA DE MORTOS, E ESTAVAM VIVOS — 23/09/2026, P32.
    #   O aviso mentia para o outro lado: acusava o Dracula de declarar onze
    #   campos sem leitor, e dois tinham leitor desde antes. Recontados um a um:
    #   · `icones.autorais.gerar` — o `cmd_construir`, aqui mesmo, sai com
    #     "nada a construir" quando ele é falso ou falta;
    #   · `origens.cursores.tema` — o `_declarado_pelo_pack` (app/servidor.py)
    #     o reconhece como receita do pack. Medido: numa cópia do Dracula sem
    #     ele, `_declarado_pelo_pack("dracula", "catppuccin-mocha-light")` vira
    #     de True para False, e o painel passa a acusar o CURSOR de fábrica de
    #     ser resto do Catppuccin. A função varre toda string do pack.json, mas
    #     só chega nela o valor do meow.conf que cita o nome de OUTRO pack — e
    #     dos nove que sobram no aviso nenhum é assim (`scalable/apps`,
    #     `github-arvore`, `herdar`, `svg`, os acentos).
    #   Os nove restantes deram `grep` vazio de leitor no mesmo dia: os dois
    #   `recolorir`, `icones.apps.camada`, `paleta.acentos` e os cinco de
    #   `origens.wallpapers` — o `wallpaper.sh` lê `WALLPAPER_DRACULA_*` do
    #   meow.conf pelo nome do flavor, e não abre pack nenhum.
    "icones.autorais.gerar",            # cmd_construir
    "origens.cursores.tema",            # app/servidor.py, `_declarado_pelo_pack`
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


# A ADOÇÃO: QUE PACK UM meow.conf VESTE — 23/09/2026, sprint P35
#
# A MESMA PERGUNTA TINHA TRÊS RESPOSTAS, EM DUAS LÍNGUAS
#   O `meow_pack_dir` (lib/comum.sh) adotava pelo NOME do FLAVOR; o
#   `_pack_adotado` do painel, pelo SABOR que a paleta declara; e o
#   `_ponteiro_do_pack`, também do painel, repetia a conta do shell de
#   propósito, para a lista de ponteiros não oferecer o que o script não acha.
#   Medido em 23/09, com PACK vazio, num HOME de brinquedo:
#
#     FLAVOR        shell        painel
#     dracula       dracula      dracula
#     alucard       o padrão     dracula      <- a divergência que a P12 anotou
#     mocha         o padrão     catppuccin
#     latte         o padrão     catppuccin
#     inexistente   o padrão     ''           ("nenhum pack responde")
#
#   `mocha` e `latte` só concordavam porque o padrão É o Catppuccin. Com
#   `FLAVOR="alucard"` o shell vestia a máquina com a paleta do Catppuccin e o
#   painel abria a oficina do Dracula. É o defeito que a P17 pegou duas vezes e
#   que reprovou a P10: a mesma regra escrita duas vezes, e as cópias
#   divergindo no primeiro caso esquisito.
#
# A REGRA MORA AQUI, E OS DOIS LADOS PERGUNTAM
#   O shell pelo verbo `adocao`; o painel importando este arquivo, como já faz
#   para todo o resto. Nesta ordem:
#     1. a chave PACK, quando preenchida, vence tudo;
#     2. um FLAVOR que NOMEIE um pack existente adota esse pack — a promessa do
#        meow.conf.exemplo, e o que faz um conf de antes do formato valer;
#     3. um FLAVOR que o pack PADRÃO declara fica no padrão: PACK vazio já quer
#        dizer "o embutido", e o sabor dele não muda isso. Vem antes do passo 4
#        para que um pack de terceiro que também chame um flavor de `mocha` não
#        tome a máquina de fábrica calado;
#     4. um FLAVOR que outro pack DECLARA na paleta adota esse pack — o
#        `alucard` é do Dracula. Na ordem do `achar`: as raízes na precedência,
#        os ids em ordem alfabética, e um id escondido por uma raiz de cima não
#        conta, porque não é ele que o id encontra;
#     5. nada disso: o padrão.
#   O pack escolhido em 1, 2 ou 4 passa pela validação do MOTOR
#   (`silencioso=True`), a mesma da sonda `caminho` que o shell fazia. Reprovado,
#   a máquina veste o padrão, e quem chamou diz por quê.
#
# O DIRETÓRIO VAZIO CONTINUA SENDO O SINAL DE "NINGUÉM ESCOLHEU"
#   Nos passos 3 e 5 o `dir` sai vazio, e não com o caminho do padrão. É o que
#   o `meow_pack_dir` sempre devolveu nesses casos, e o `meow_paleta` depende
#   disso: entre o pack escolhido e o padrão ele ainda olha `PALETA_ARQUIVO`, e
#   um caminho aqui pularia esse degrau para quem nunca escolheu pack.
#
# O PREÇO, MEDIDO: o conf de fábrica (`FLAVOR="mocha"`, PACK vazio) não fazia
#   fork nenhum no `meow_pack_dir`, e agora faz um — ~45 ms nesta máquina, o
#   mesmo que a chave PACK preenchida já pagava pela sonda `caminho`.
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
        # QUALQUER exceção, e não só Recusa: um `"paleta": "x"` de terceiro
        # estoura AttributeError antes de virar Recusa (o bloco "A VITRINE DOS
        # PACKS", no app/servidor.py, mediu o caso), e aqui ele tem de virar "o
        # padrão veste", nunca um traceback no instalador. É o mesmo `except
        # Exception` que o `_ponteiro_do_pack` do painel já usava.
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
    #   `rebuild_dracula_theme()` do Spellbook-OS reescrevia (21/09 16:52:33; a
    #   P37 o desativou em 23/09, e o Dracula passou a ser montado do pack).
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
# DENTRO DE `scalable/apps`, O PACK NO AR VENCE O MOTOR — 24/09/2026, P43
#   A decisão de 23/09 sobre os sete nomes que a P36 deixou de fora: com o
#   Dracula no ar, o desenho do Dracula vence; com o Catppuccin no ar, a
#   escolha de antes continua. Dois deles (`guvcview`, `setup-mozc`) são nomes
#   do `apps-resgatados.map`, e aí não há camada diferente para desempatar: os
#   dois instaladores escrevem o MESMO arquivo. Medido numa casa de brinquedo
#   com as linhas já no mapa do Dracula: depois da instalação, o
#   `icones_resgatados.sh --conferir` saía 1 acusando os dois, e o doctor os
#   trocaria um pelo outro todo dia — o defeito que a P28 veio extinguir.
#
#   A regra "um nome, uma fonte" continua valendo; o que muda é que o empate
#   pack x motor deixou de ser empate e passou a ter vencedor DECLARADO, aqui,
#   onde o `fonte`, o `tests/fonte-unica.sh` e o `icones_resgatados.sh`
#   perguntam. O mapa do pack é decisão de TEMA e o resgate é arte do motor,
#   igual para todo pack — quem pôs o nome no mapa do pack no ar escolheu
#   vesti-lo. Com o Catppuccin no ar nenhum mapa de pack nomeia os dois, e o
#   resgate volta a ser a fonte sem ninguém mexer em nada. O que continua
#   empate é o mesmo nome duas vezes num mapa só, e esse o `validar` recusa.
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

    O pack x motor NÃO é empate desde 24/09/2026 (P43): o resgate de um nome
    que o mapa do pack também nomeia fica ATRÁS, e não sai daqui — ver o
    bloco "O PACK NO AR VENCE O MOTOR" acima e o `fontes_e_atras`.

    Linha que o `resolver_alvo` recusa não vira fonte — o motivo vai para o
    stderr, e o `validar` recusa o pack inteiro por ela.
    """
    return fontes_e_atras(ref)[0]


def fontes_e_atras(ref=None):
    """(fontes, atrás): as linhas que valem e os resgates que o pack pôs atrás.

    Só o nome que VIROU fonte do pack põe o resgate atrás: uma linha que o
    `resolver_alvo` recusou não instala nada (o instalador a trata como "sem
    desenho"), e aí o resgate continua sendo o que chega ao tema.
    """
    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    saida, atras = [], []
    mapa = acervo("icones.apps.mapa", ref=ref)
    if mapa:
        base, camada = os.path.dirname(mapa), OUTRO_PACK + _pack_de(mapa)
        for num, nome, alvo in ler_mapa(mapa):
            try:
                saida.append((nome, _relativo(resolver_alvo(alvo, base)), camada))
            except Recusa as e:
                print(f"  aviso {_relativo(mapa)}:{num}: {e}", file=sys.stderr)
    do_pack = {nome for nome, _fonte, _camada in saida}
    resg = os.path.join(RAIZ, MAPA_RESGATADOS)
    if os.path.isfile(resg):
        with open(resg, encoding="utf-8") as fh:
            for linha in fh:
                campos = linha.split("#", 1)[0].split(":")
                nome = campos[0].strip()
                if len(campos) >= 3 and nome:
                    (atras if nome in do_pack else saida).append(
                        (nome, os.path.join(ACERVO_RESGATADOS, nome + ".svg"), "resgatados"))
    return saida, atras


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
    # O RESGATE QUE FICOU ATRÁS É DITO, E NÃO ESCONDIDO: quem pergunta "de onde
    # sai o guvcview?" com o Dracula no ar precisa saber que o desenho do motor
    # existe e volta sozinho com outro pack. No stderr, para o stdout continuar
    # sendo uma linha por fonte que vale — o formato que o `meow icones fonte` lê.
    for _n, fonte, camada in (a for a in atras if a[0] == nome):
        print(f"  info {fonte} ({camada}) fica atrás: o pack no ar vence o motor "
              f"para este nome, e o resgate volta a valer com outro pack", file=sys.stderr)
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
#   congela: a origem é outro repositório, que continua andando (em 23/09 era o
#   `Dracula-Icones`, reconstruído dele pelo `rebuild_dracula_theme()` do
#   Spellbook-OS — que a P37 desativou lá no mesmo dia). Sem caminho de volta,
#   a cópia defasa e ninguém percebe.
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
#
# `lido de` VAZIO É SÓ REGISTRO — 24/09/2026, P43
#   A decisão de 23/09 sobre o Dracula foi "aposentar tudo": o `meow doctor` e
#   este verbo deixam de ler o repositório de onde a arte do pack veio, que só
#   existe na máquina de quem o escreveu. Era a última leitura, em execução, de
#   um caminho da casa de alguém — 364 das 365 linhas daquele PROCEDENCIA.md
#   apontavam para lá. A coluna `lido de` ficou VAZIA nelas, e a origem
#   continua escrita como texto na coluna `de onde`.
#
#   Vazio, e não a coluna removida: a tabela é a mesma que o `exportar` lê
#   para a licença (`_licencas`), e sem uma das três colunas ele recusaria
#   reempacotar o pack inteiro. A linha vazia é contada como "só registro": o
#   arquivo do pack ainda tem de existir, e nada fora do pack é aberto por ela.
#   A comparação continua de pé para quem escreve `lido de` — um pack de
#   terceiro, ou a linha do guvcview, cuja origem é o próprio motor.
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

    em_dia = fora = andou = registro = 0
    for lin in linhas:
        arquivo, lido, reg = lin.get("arquivo", ""), lin.get("lido de", ""), lin.get("sha256", "").lower()
        rotulo = arquivo or "(linha sem arquivo)"
        try:
            aqui = _dentro(dir_pack, arquivo, "PROCEDENCIA.md")
            # Sem `lido de`, sem origem: é só registro (ver o bloco acima).
            origem = _origem(lido) if lido else ""
            _exigir(RE_SHA256.match(reg), f"sha256 {reg!r} não tem 64 hex")
            # A MESMA EXTENSÃO NOS DOIS LADOS. A coluna `lido de` é dado de
            # quem escreveu o pack, e um pack de terceiro escreve o dele: sem
            # esta linha, `~/.ssh/id_ed25519` seria aberto e teria o sha256
            # impresso na tela. Comparar um `.svg` com outra coisa não é
            # sincronizar arte — então não se abre.
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


# --- O PONTEIRO PRÓPRIO — 23/09/2026, sprint P12 ----------------------------
#
# O "HERDADO" DO PONTEIRO ERA FOLCLORE, E FOI MEDIDO
#   `origens.cursores` só aceitava `herda`. O Dracula declara `herda:
#   "catppuccin"`, o `meow pack info` imprimia "HERDADO de catppuccin" — e o
#   `packs/catppuccin/pack.json` não declara ponteiro nenhum. Mais: NENHUMA
#   linha do `scripts/cursor.sh` perguntava ao pack. O ponteiro saía da chave
#   CURSOR do meow.conf e, sem ele no disco, do release pinado do
#   `catppuccin/cursors`, o mesmo para todo pack. A herança existia só na tela.
#
# `proprio` É UM TEMA XCURSOR DENTRO DO PACK, E ENTRA COMO QUALQUER OUTRO
#   `cursores/<nome>/cursors/` — a forma de todo tema de ponteiro, a mesma que o
#   `cursor.sh adicionar` já instala. O `cursor.sh` pergunta AQUI antes de
#   baixar: se a chave CURSOR nomeia o ponteiro do pack, ele entra do pack, sem
#   rede, pelo mesmo `_cursor_instalar_pasta` de um tema de terceiro. Quem
#   ESCOLHE continua sendo a chave — "o meow.conf vence" (docs/PACKS.md).
#
# O NOME TEM O ALFABETO DA PENEIRA DO `cursor.sh`, E SÓ ELE
#   O `_cursor_nome_seguro` troca por `-` o que estiver fora de [A-Za-z0-9._-] e
#   come o `.`/`-` da frente antes de o nome virar diretório. Um nome que ele
#   MUDASSE seria instalado com um nome e oferecido pelo painel com outro — o
#   clique que sai baixando da rede, que a P17 tirou da tela duas vezes. Então o
#   formato só aceita o nome que aquela peneira deixa como está.
#
# O VALOR PERDE O `-cursors`, PELA REGRA DO `cursor.sh`
#   O `_cursor_instalar_pasta` instala `<nome>` como `<nome>-cursors` e anuncia
#   o valor sem o sufixo; o `_cursor_nome_tema` o põe de volta. É o que faz
#   `cursores/dracula-roxo/` ser escolhido por `CURSOR="dracula-roxo"`.
#
# TODO ARQUIVO DO TEMA CAI DENTRO DELE
#   Um tema Xcursor é feito de links (`left_ptr -> default`, dezenas deles). O
#   `cursor.sh` copia o diretório inteiro com `cp -a`, que copia o LINK, e um
#   `cursors/x -> /etc/algo` iria parar em `~/.local/share/icons/` apontando
#   para fora. É a regra do `realpath` que o formato aplica a todo caminho
#   declarado, levada para dentro do diretório declarado.
CATEGORIA_PONTEIRO = "origens.cursores.proprio"
SUFIXO_PONTEIRO = "-cursors"
RE_NOME_PONTEIRO = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]{0,79}$")
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
    # O LINK QUE NÃO LEVA A NADA — achado da revisão da P12, 23/09/2026.
    #   `cursors/hand -> hand2` sem o `hand2` cai DENTRO do tema pelo `realpath`
    #   e passava. Medido num HOME de brinquedo: `validar` saía 0, e o `aplicar`
    #   reinstalava o tema em toda passagem, sem convergir. O ponteiro que o link
    #   promete não existe, e o autor do pack é quem tem de saber — aqui, e não
    #   na máquina de quem instalou. (O `cursor.sh` compara o link como link
    #   desde o mesmo dia; ver `_cursor_instalar_pasta`.)
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


def ponteiro(ref=None):
    """O ponteiro próprio que a cadeia alcança: {'pack', 'dir', 'valor'}, ou None.

    A subida é a do `acervo` — `proprio` do pack; senão `origens.cursores.herda`,
    senão `heranca` —, e por isso esta função a pede a ele em vez de refazê-la.
    Um tema que o `acervo` acha e que não passa em `conferir_ponteiro` é
    ignorado com aviso: o `validar` já o recusa na publicação, e quem pergunta
    aqui é o `cursor.sh`, que vai COPIAR o diretório.
    """
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


# --- AS FONTES DE TEXTO — 23/09/2026, sprint P12 ----------------------------
#
# POR QUE `tipografia`, E NÃO `fontes`
#   Em português "fonte" é a tipografia e é a origem. A P28 tomou o verbo
#   `fontes` para "de onde sai cada ícone"; reaproveitar o nome aqui faria o
#   `tests/fonte-unica.sh` e quem chama `pack.py fontes` receberem outra coisa,
#   calados. A CHAVE do pack.json é `fontes` — é como quem escreve um pack
#   procura —; o VERBO é `tipografia`.
#
# O QUE O MOTOR JÁ FAZ, E O QUE O PACK ACRESCENTA
#   O `instalar_fontes.sh` instala a JetBrainsMono Nerd Font pinada e aponta o
#   terminal para ela, para todo pack — isso continua do motor. O que era
#   impossível era um pack TRAZER fontes. Agora ele declara uma lista, e ela
#   entra em `~/.local/share/fonts/MeowSystem/pack/`, um diretório de dono
#   único: trocar de pack tira as fontes do pack anterior, que é o que "a
#   fonte é do pack" quer dizer.
#
# DUAS FORMAS, E CADA UMA COM A REGRA QUE O FORMATO JÁ TEM
#   {"arquivo": "fontes/X.otf"}                 dentro do pack — o `realpath`
#   {"nome": "X.ttf", "url": "https://…",       fora dele — o `https://` e o
#    "sha256": "<64 hex>"}                      conteúdo pinado, como a Nerd Font
#   A URL aponta para UM arquivo de fonte, e não para um pacote: abrir .zip ou
#   .tar é o que o `adicionar` do mesmo script faz pelas mãos dela, com ela
#   olhando. Um pack instala sozinho, e o que entra sozinho é o que se confere
#   byte a byte.
#
# A HERANÇA É DO BLOCO INTEIRO, COMO NOS TEMAS DE APLICATIVO
#   O primeiro pack da cadeia que declara `fontes.proprio` responde, e a lista
#   dele é a lista — uma fonte não "falta" e desce ao vizinho. `[]` é "este pack
#   não traz fonte, e não herda": é como um pack diz isso.
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
            nome, origem, soma = os.path.basename(arq), os.path.join(dir_pack, arq), ""
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
# O `novo --de-csv` E O `.csv` DA TELA ENTRARAM DEPOIS DA P11 [23/09/2026]
#   A sprint pede `meow pack novo <id> --de-csv <arquivo>` (item 2) e a tela
#   de importar aceitando `.csv` (item 5). A primeira metade da P16 os deixou
#   por fazer, porque o `novo`, o `/api/pack-importar` e a tela de importar
#   nascem na P11, que não tinha entrado no dev (medido então: zero `novo` no
#   `bin/meow`, zero `pack-importar` no servidor e no app.js do dev 249d60a).
#   Um segundo `novo` escrito em paralelo seria o conflito que ninguém
#   resolveria igual duas vezes. A P11 entrou (8f50bd8), e a segunda metade
#   ligou os dois — ver `montar_novo`, onde o CSV vira PACK, e não só paleta:
#     · a paleta vem desta seção (`paleta_de_csv`), e a régua e a notícia do
#       claro derivado saem pela `_noticiar_csv`, a mesma do `cmd_de_csv`;
#     · o `flavor_padrao` é o primeiro flavor do CSV, o mesmo de onde o claro
#       se deriva;
#     · a `heranca` é o pack PADRÃO, sem a qual ícones, ponteiro e papéis de
#       parede não subiriam para pack nenhum;
#     · os ícones AUTORAIS nascem construídos, nas cores do CSV — ver
#       `_autorais_construidos`, que diz por que o CSV precisa e o `novo` do
#       pack no ar não.
#   O `importar` de um `.csv` solto — a porta da tela — chama o MESMO
#   `montar_novo`: uma regra só para "este CSV vira este pack", e os dois
#   verbos diferem só em ONDE escrevem, cada um pelo motivo do seu cabeçalho.
#
# O CLARO DERIVADO É O MÉTODO DO ALUCARD, E NÃO UM SEGUNDO
#   As três regras de docs/PACKS.md, "Se o seu tema não tem um claro", viraram
#   código uma vez só: `scripts/derivar_claro.py`, em 19/09/2026, que gerou o
#   `alucard`. Aquele script cravava o `dracula` na leitura e gravava num
#   arquivo de /tmp, então não servia de biblioteca, e ele não estava entre os
#   arquivos da P16. O `derivar_claro` abaixo é o MESMO algoritmo, passo a passo
#   e com os mesmos números (S < 0,10, 12 tentativas de -0,07 em S, 40 passos de
#   busca, o ajuste do `text` até 7,02). A prova de que não é um método novo é
#   medida, e o `tests/pack.sh` a cobra: dadas as 26 cores do `dracula`, ele
#   devolve o `alucard` versionado — 26 de 26 iguais.
#   UMA CÓPIA SÓ DESDE 23/09/2026 (P34). A P16 deixou as duas lado a lado e
#   disse que unificá-las era mexer no `derivar_claro.py`. Foi o que se fez: o
#   `main()` dele chama esta função e imprime o claro no STDOUT, sem gravar em
#   /tmp. A história das três correções continua lá, onde foi aprendida, e o
#   `tests/pack.sh` cobra que as duas portas — o script e o `de-csv` — dão o
#   mesmo claro.
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
        # Uma vez por flavor, na primeira linha dele: o nome se repete nas 26
        # linhas, e 26 cópias da mesma recusa enterravam os outros erros.
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
    # A RÉGUA AVISA E NÃO BLOQUEIA, E O CÓDIGO DE SAÍDA CONTINUA 0
    #   A sprint é explícita: "a régua é do projeto; a decisão é de quem fez o
    #   tema". Medido em 23/09/2026: as cores oficiais do Dracula reprovam em
    #   três slots contra o Latte (`blue` 3,03 contra 4,34, `red` e `surface0`),
    #   e bloquear aqui recusaria o tema que o próprio projeto já veste. O que
    #   não pode é o silêncio: a lista inteira sai, e antes do JSON.
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


# O NOME DE QUEM ESCREVEU NÃO VIAJA — 23/09/2026, sprint P30
#
#   O docs/PACKS.md pede, para publicar, "nenhum nome de usuário", e nada o
#   cobrava. MEDIDO: as quatro capturas versionadas dos dois packs traziam
#   `/home/<nome>/.config/cosmic` na linha `origem:` do `captura.txt` — dois
#   nomes, de duas máquinas —, e o `exportar` os levava dentro de todo
#   `.meowpack`. A causa foi consertada onde nasce (o `capturar_tema.sh` escreve
#   `~`); esta régua é o que impede de voltar, venha de onde vier: um
#   PROCEDENCIA.md escrito à mão, um SVG que o editor salvou com o caminho de
#   exportação absoluto dentro, um mapa copiado da máquina de alguém.
#
#   `~/` PASSA, E É DE PROPÓSITO: diz "a casa de quem estiver lendo" sem dizer
#   de quem — é como a coluna "lido de" do PROCEDENCIA.md do Dracula escreve.
#   `/home/<nome>/` e `/Users/<nome>/` (o macOS) não passam, e o `/home/` pode
#   vir depois de qualquer coisa: `/var/home/<nome>/` é a casa nos Fedora
#   atômicos, e `file:///home/<nome>/` é a mesma casa com outro prefixo. O preço
#   é um link com `/home/<palavra>/` no meio do caminho ser recusado também —
#   raro, e a recusa diz a linha. O nome é o que um usuário pode ter (letra,
#   dígito, `_`, `.`, `-`), então o `<nome>` de um texto que ensina a forma não
#   é nome de ninguém, e passa.
#
#   SÓ TEXTO, SÓ DENTRO DO PACK. A lista é a do `exportar` (`_arquivos_do_pack`):
#   sem o oculto — o `.git` de um pack publicado por clone não é do pack — e sem
#   link, que ele recusa por conta própria. Binário é o que tem byte nulo nos
#   primeiros 8000 bytes, a mesma pergunta que o git faz: o PNG de uma captura e
#   o `.qbtheme` do Catppuccin (um recurso compilado do Qt) não têm linha para
#   apontar.
#
#   SÓ NA PORTA DE QUEM PUBLICA, como a vitrine e o logo: um pack pessoal com o
#   próprio caminho num PROCEDENCIA.md continua vestindo o desktop de quem o
#   escreveu — recusá-lo no motor trocaria o tema da pessoa pelo padrão por
#   causa de uma linha de texto. O `exportar`, o `importar` e o `novo` (com ou
#   sem `--de-csv`) passam pelo `validar` inteiro, e herdam a régua sem uma
#   linha a mais.
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

    # A BIBLIOTECA SÓ GUARDA DESENHO — 23/09/2026, P36
    #   `icones/biblioteca/` é a coleção de onde se escolhe o próximo desenho de
    #   aplicativo (ver `PASTA_BIBLIOTECA`, lá embaixo). Ela é o maior acervo
    #   que um pack pode trazer — a do Dracula tem 295 —, e uma pasta desse
    #   tamanho é onde um arquivo que não é desenho entra sem ninguém ver: um
    #   `.png` de rascunho, um link para a máquina de quem montou. O `exportar`
    #   já barra link e script; esta linha diz, antes, que a pasta tem uma
    #   forma — `.svg` comum, sem subpasta —, e lista todos de uma vez.
    #
    #   SÓ NA PORTA DE QUEM PUBLICA, pelo motivo do "ALVO AUSENTE" acima: um
    #   pack recusado no motor é ignorado inteiro, e um arquivo solto numa
    #   pasta que nada instala não pode trocar o tema de ninguém. O oculto fica
    #   de fora, como no `exportar`.
    pasta_bib = os.path.join(dir_pack, PASTA_BIBLIOTECA)
    if not silencioso and os.path.lexists(pasta_bib.rstrip("/")):
        _exigir(os.path.isdir(pasta_bib) and not os.path.islink(pasta_bib.rstrip("/")),
                f"{PASTA_BIBLIOTECA}: precisa ser uma pasta do pack, e não um arquivo ou link")
        fora_da_forma = []
        for a in sorted(os.listdir(pasta_bib)):
            cheio = os.path.join(pasta_bib, a)
            if a.startswith("."):
                continue
            if not a.endswith(".svg") or os.path.islink(cheio) or not os.path.isfile(cheio):
                fora_da_forma.append(a)
        _exigir(not fora_da_forma,
                f"{PASTA_BIBLIOTECA}: {len(fora_da_forma)} entrada(s) que não são desenho "
                f"(.svg comum, sem subpasta):\n      " + "\n      ".join(fora_da_forma))

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

    # --- o ponteiro e as fontes — 23/09/2026, sprint P12 ---------------------
    #   Os dois são campos de arquivo, e entram na vizinhança do `creditos` e
    #   do `apps.*.arquivo` pelo motivo que aqueles dois já contam: o pack que
    #   promete e não entrega só falharia dentro do instalador, na máquina de
    #   quem instalou. E pelas duas portas, como aqueles: o `cursor.sh` COPIA o
    #   tema para `~/.local/share/icons/`, e um link para fora não pode passar
    #   por nenhuma delas.
    #
    #   `proprio` E `herda` JUNTOS É RECUSA, e não precedência: um bloco que diz
    #   "o meu" e "o do vizinho" ao mesmo tempo não disse nada, e escolher um
    #   dos dois por quem o escreveu é o default escondido que o formato evita.
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
    # `fontes` entrou em 23/09/2026 (P12) pelo mesmo motivo: o `tipografia` lê o
    # `fontes.herda` como o `acervo` lê o `icones.*.herda`.
    for cat, bloco in (list(ic.items()) + list((p.get("origens") or {}).items())
                       + list((p.get("apps") or {}).items())
                       + [(CATEGORIA_FONTES, p.get(CATEGORIA_FONTES))]):
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

    # --- o nome de quem escreveu — 23/09/2026, P30 ---------------------------
    # Só na porta de quem publica; o porquê está em `nomes_de_usuario`, acima.
    if not silencioso:
        casas = nomes_de_usuario(dir_pack)
        _exigir(not casas,
                f"{len(casas)} linha(s) com a casa de alguém escrita por extenso — o pack\n"
                f"    viaja, e o nome de usuário iria junto. Escreva ~/ no lugar dela, que\n"
                f"    diz o mesmo sem dizer de quem:\n      " + "\n      ".join(casas))

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


# A BIBLIOTECA: DESENHOS QUE NENHUM APLICATIVO VESTE AINDA — 23/09/2026, P36
#
#   A queixa: "vc tinha achado mais de 300 [SVGs] do tema dracula mas eles não
#   estão no pack". Estavam 11 de 295: o pack guardava só o desenho que já
#   vestia alguém, e o resto da coleção — de onde a pessoa escolhe o próximo —
#   morava num repositório que só existe numa máquina. `icones/biblioteca/` é
#   essa coleção, dentro do pack.
#
#   SEM CAMPO NO pack.json, E É DE PROPÓSITO: nada INSTALA a biblioteca. Quem
#   põe desenho no tema é o `icones.apps.mapa`, e uma linha dele pode apontar
#   para `biblioteca/x.svg` como aponta para `apps/x.svg` — é o mesmo
#   `resolver_alvo`. A pasta é convenção, como a `temas/capturados/`: um campo
#   que declarasse "tenho biblioteca" seria lido só por esta conta.
#
#   "SEM APP LIGADO" É POR CONTEÚDO, E NÃO POR CAMINHO. Onze desenhos da
#   biblioteca do Dracula já moravam em `icones/apps/` com nome de aplicativo
#   (o `dice.svg` é o `apps/foundryvtt.svg`, byte a byte), e a decisão foi
#   deixá-los lá. Contar por caminho diria que o dado não veste ninguém,
#   quando o Foundry o veste todo dia. O sha256 de ~300 SVG custa milissegundos.
PASTA_BIBLIOTECA = "icones/biblioteca/"


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
    "som": "som",
    "fontes": "fontes",
    "gerador": "traço do gerador de ícone",
    "prompt": "prompt",
    "fastfetch": "fastfetch",
    "gatos": "gatos",
}


# AS QUE O FORMATO AINDA NÃO DECLARA, DITAS NA TABELA — 23/09/2026, sprint P12
#
#   A tabela da P12 contou onze categorias, e o `info` imprimia nove linhas:
#   som, fontes, o traço do gerador de ícone, prompt, fastfetch e gatos não
#   apareciam — e a P18 e a P27 tinham acrescentado duas que a tabela não
#   contava (temas de aplicativo, ícones autorais). Uma categoria que some da
#   tela é lida como "o pack cuida disso", e a nota de herança do Dracula dizia
#   que prompt, fastfetch e gatos "vêm do pack base". Não vêm: vêm de `assets/`,
#   iguais para todo pack, e nenhum pack tem campo onde declarar outros.
#
#   Então elas entram na tabela com o nome do que são — DO MOTOR, não
#   declaráveis — e o lugar de onde saem na coluna ao lado. Quando uma sprint
#   der campo e leitor a uma delas, ela sai DESTA tabela e passa a ser
#   classificada como as outras; enquanto estiver aqui, o `info` diz a verdade.
#
#   O TRAÇO DO GERADOR NÃO É O `icones.autorais`. A P26 tornou declarável O QUE
#   o gerador de autorais desenha (os `.json` do pack). O traço da conversão —
#   espessura, fusão, aparo, cantos, preenchimento — continua nos padrões do
#   `converter_icone.py` e nas réguas da oficina, e é a mesma saída para todo
#   pack. Ver a seção "O que ainda não é do pack" do docs/PACKS.md.
FIXAS_NO_MOTOR = {
    "gerador": "scripts/converter_icone.py",
    "prompt": "assets/prompt/",
    "fastfetch": "assets/fastfetch/",
    "gatos": "assets/gatos/",
}


def origens(p):
    """[(categoria, tipo, de_quem)] na ordem da tabela do `info`.

    `tipo` é 'próprio', 'herdado', 'motor' ou 'fixo' (do motor, e sem campo no
    formato); `de_quem` só vem no 'herdado'.
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
                       ("apps", p.get("apps")),
                       ("som", p.get("som")), (CATEGORIA_FONTES, p.get(CATEGORIA_FONTES))] \
            + [(cat, None) for cat in FIXAS_NO_MOTOR]:
        if cat in FIXAS_NO_MOTOR:
            tipo, quem = "fixo", ""
            saida.append((cat, tipo, quem))
            continue
        # O SOM NÃO SOBE A HERANÇA, E A TABELA NÃO PODE DIZER QUE SOBE: o
        # `cmd_som` lê só o `som` do próprio pack, e o `som.sh` põe os padrões
        # dele no que faltar. Um pack que herda do Dracula e não declara `som`
        # toca o sino do motor, e não o do Dracula.
        if cat == "som":
            declarou = isinstance(bloco, dict) and any(not str(k).startswith("_") for k in bloco)
            saida.append((cat, "próprio" if declarou else "motor", ""))
            continue
        # OS PAPÉIS DE PAREDE SÃO DO MOTOR, DECLARE O PACK O QUE DECLARAR —
        # 23/09/2026, sprint P32.
        #   A tabela dizia PRÓPRIO para o Dracula porque ele declara
        #   `origens.wallpapers`, e nenhum código lê esse bloco: o
        #   `scripts/wallpaper.sh` não abre pack nenhum. Quem escolhe a semente é
        #   o `_semente_do_flavor` de lá, pelo NOME do flavor — `dracula` lê
        #   `WALLPAPER_DRACULA_REPO` do meow.conf, todo o resto cai no acervo do
        #   Catppuccin —, com `WALLPAPER_SEMENTE_REPO` vencendo por cima. Quem
        #   lia "próprio" acreditava que o pack trazia os papéis de parede dele.
        #   Nem HERDADO serve: ninguém sobe a herança desta categoria.
        #
        #   POR QUE MUDA A TELA, E NÃO O SEMEADOR. Dar leitor ao bloco seria um
        #   segundo caminho de semeadura — achar o pack ativo no shell, ler cinco
        #   campos, expandir a chave do conf que `repo_do_conf` nomeia, cumprir o
        #   `se_vazio` — para chegar ao que o `dracula)` do `wallpaper.sh` já faz,
        #   e ninguém pediu por ele. O menor passo verdadeiro é a tabela dizer de
        #   onde a imagem sai. Os campos seguem no aviso de campo morto, que conta
        #   que declará-los não faz nada; no dia em que o `wallpaper.sh`
        #   perguntar ao pack, este bloco sai e a categoria volta à regra geral.
        if cat == "wallpapers":
            saida.append((cat, "motor", ""))
            continue
        # PONTEIRO E FONTES SÃO PRÓPRIOS SÓ COM `proprio`. Um bloco com só o
        # `tema` do ponteiro (o nome que a chave CURSOR recebe) não traz tema
        # nenhum, e a tabela dizia PRÓPRIO para ele; sem `proprio` e sem
        # `herda`, a categoria cai na `heranca`, que é o que o `ponteiro` e o
        # `tipografia` fazem de verdade.
        if (cat in ("cursores", CATEGORIA_FONTES) and isinstance(bloco, dict)
                and "proprio" not in bloco and not bloco.get("herda")):
            bloco = None
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
                  "motor": "DO MOTOR, ou inexistente",
                  "fixo": "DO MOTOR — não declarável"}[tipo]
        # SÓ AS CATEGORIAS DE ÍCONE TÊM ACERVO PARA CONTAR. `paleta` é um
        # arquivo, `cosmic.mapa` é um arquivo, e cursores e wallpapers são
        # origens que este pack nem baixou ainda — contar SVG em qualquer uma
        # das quatro imprimiria uma coluna vazia que faz a pessoa procurar o que
        # deu errado.
        conta = ""
        if cat.startswith("icones."):
            quantos, fl = _contar_acervo(ref, cat, dados["flavors"])
            conta = f"{quantos}, {fl}" if quantos and fl else quantos
            # COM BIBLIOTECA, A LINHA DOS APLICATIVOS CONTA NOMES, E NÃO
            # ARQUIVOS DE `apps/` [23/09/2026, P36]: um mapa que aponta para
            # `biblioteca/` veste aplicativos com desenho que não mora em
            # `apps/`, e "70 desenho(s)" ali contaria a metade. A mesma linha,
            # e não uma nova: a tabela tem as 15 que o `tests/pack.sh` cobra.
            bib = _contar_biblioteca(ref, dir_pack) if cat == "icones.apps" else None
            if bib:
                conta = f"{bib[0]} apps, {bib[1]} na biblioteca sem app ligado"
        # PONTEIRO E FONTES DIZEM ONDE A CADEIA TERMINA — 23/09/2026, P12.
        #   "HERDADO de catppuccin" era tudo o que o Dracula mostrava para o
        #   ponteiro, e o catppuccin não traz ponteiro nenhum. A coluna ao lado
        #   diz o que a subida de fato acha — o valor da chave CURSOR e o pack
        #   que o traz —, ou que ela não acha nada. É o mesmo papel do
        #   `0 desenho(s)` das categorias de ícone.
        elif cat == "cursores":
            pt = ponteiro(ref)
            conta = (f"CURSOR=\"{pt['valor']}\", do pack {pt['pack']}" if pt
                     else "" if tipo == "motor" else "a cadeia não traz ponteiro")
        elif cat == CATEGORIA_FONTES:
            # Um pack BASE com a lista quebrada não derruba o `info` de quem o
            # herda: o `validar` deste pack não confere a lista do outro, e o
            # que se quer aqui é ver a tabela inteira, dizendo o que falhou.
            try:
                quem_f, lista = tipografia(ref)
                conta = (f"{len(lista)} fonte(s), do pack {quem_f}" if quem_f
                         else "" if tipo == "motor" else "a cadeia não traz fonte")
            except Recusa:
                conta = "a lista herdada não valida — rode o `validar` do pack base"
        # DE ONDE O PAPEL DE PAREDE SAI, como nas fixas do motor — P32. A
        # segunda metade é o porquê de o bloco declarado não mudar a linha: ver
        # "OS PAPÉIS DE PAREDE SÃO DO MOTOR", no `origens`.
        elif cat == "wallpapers":
            conta = "scripts/wallpaper.sh — ele não abre pack nenhum"
        elif cat in FIXAS_NO_MOTOR:
            conta = FIXAS_NO_MOTOR[cat]
        print(f"  {cat:<16}  {estado:<27}  {conta}")
    return OK


# A chave do `som` no pack.json e a do meow.conf que a vence. Saiu de dentro do
# `cmd_som` em 23/09/2026 (P11): o `novo` lê o mesmo par no sentido contrário —
# o timbre que está NO AR é o do pack com o meow.conf por cima —, e duas cópias
# da tabela discordariam na primeira chave nova.
SOM_NO_CONF = {
    "fundamental": "SOM_FUNDAMENTAL",
    "harmonico": "SOM_HARMONICO",
    "peso_fundamental": "SOM_PESO_FUNDAMENTAL",
    "peso_harmonico": "SOM_PESO_HARMONICO",
    "decaimento": "SOM_DECAIMENTO",
    "duracao": "SOM_DURACAO",
    "ganho": "SOM_GANHO",
}


# TROCAR DE PACK, E A TELA FALAR COM AS PALAVRAS DELE — 23/09/2026, sprint P10
#
# A QUEIXA
#   "o programa original foi feito não pensando em um produto mas em aplicar o
#   tema catppuccin." Trocar de pack era editar `PACK=` no meow.conf à mão: os
#   verbos daqui liam, validavam e construíam, e nenhum dizia à máquina "use
#   este". E a tela, com o Dracula no ar, oferecia `Mocha`, `Frappé` e
#   `cat-${FLAVOR}-${ACCENT}` — o vocabulário de um pack vestindo a máquina de
#   outro.
#
# AQUI MORA A DECISÃO, E NÃO A ESCRITA
#   Quem grava o meow.conf é o `meow pack usar` (bin/meow), pela
#   `meow_conf_definir` — a única rotina deste projeto que escreve naquele
#   arquivo, e o cabeçalho dela conta o que custou ter duas. Este arquivo decide
#   QUAL id e QUAL flavor, e recusa antes da primeira escrita: é a mesma
#   fronteira do resto do `pack.py`, que nunca escreve fora do pack.
RE_FLAVOR_CONF = re.compile(r"^[a-z0-9_]+$")


def plano_de_uso(ref, flavor=None, flavor_atual=None):
    """(id, flavor, porquê) que o `meow pack usar` vai gravar. Levanta Recusa.

    O flavor, nesta ordem: o PEDIDO, que tem de ser do pack; o que JÁ ESTÁ no ar,
    se for do pack — voltar ao Catppuccin estando no Latte não pode jogar a
    pessoa no Mocha; e o `flavor_padrao` do pack. O terceiro campo diz qual dos
    três venceu, para a tela dizer por quê.
    """
    # A VALIDAÇÃO É A DO MOTOR (`silencioso=True`), e não a de quem publica. É a
    #   que o `meow_pack_dir` (lib/comum.sh) aplica por baixo de tudo: um pack que
    #   a reprova vira "pack não resolve — usando o padrão", e o desktop sai
    #   Catppuccin com `PACK="meu"` escrito no conf. Recusar aqui o que lá seria
    #   trocado em silêncio é o ponto do verbo. Capa e logo ausentes não entram:
    #   o motor usa o pack sem eles, e o `validar` diz a quem publica.
    p, dados, dir_pack = validar(ref, silencioso=True)
    ident = p["id"]
    # O ID TEM DE LEVAR DE VOLTA A ESTE DIRETÓRIO. O meow.conf nomeia pack por
    #   id, e quem acha o id são as três raízes. Um caminho de fora delas (ou um
    #   id que uma raiz de cima esconde) validaria aqui e resolveria OUTRA coisa
    #   no `meow_pack_dir` — o conf diria um pack e a máquina vestiria outro.
    _exigir(achar(ident) == dir_pack,
            f"o pack em {dir_pack} não é o que o id {ident!r} encontra.\n"
            f"    O meow.conf nomeia pack por id, procurado nesta ordem:\n      "
            + "\n      ".join(raizes())
            + f"\n    Ponha o diretório em {os.path.join(raizes()[-2], ident)}/ e rode de novo.")
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
    # O FLAVOR VAI PARA UM ARQUIVO QUE O SHELL SOURCEIA. O `validar` só proíbe o
    #   hífen; um nome de flavor com aspas ou `$(` numa paleta de terceiro viraria
    #   comando no próximo `meow ativar`. Minúsculas, dígitos e sublinhado são o
    #   que os dois packs daqui usam, e o que o gerador de tema já espera.
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
# — 23/09/2026, sprint P31
#
# O DEFEITO, MEDIDO
#   A P10 ensinou o painel a ler `icones.mimetypes.flavor` (o `vocabulario`,
#   logo abaixo) e o shell ficou para trás: os três `icones_*.sh` seguiam em
#   `${ICONES_FLAVOR:-macchiato}`. Com o conf de fábrica (`ICONES_FLAVOR="$FLAVOR"`)
#   e o Dracula no ar o valor chegava `dracula`, que não tem acervo de mimetype,
#   e o `icones_mimetypes.sh` saía com "não há acervo de mimetype para o flavor
#   'dracula' — nada a vestir" (rc=3, num HOME de brinquedo) — enquanto a aba
#   Ícones oferecia o macchiato que o pack escolheu e dizia «Vale como:
#   dracula». É o "a lista não acompanhou a irmã" que a P17 pegou duas vezes, e
#   a P10 foi reprovada por refazer em `awk` uma regra que o painel tinha. Por
#   isso a regra mora AQUI, uma vez: o shell a pergunta pelo verbo
#   `flavor-icones` e o painel pelo `_com_o_vocabulario_do_pack` do servidor.
#
# A ORDEM É A DO "Quem vence" DO docs/PACKS.md
#   1. `ICONES_FLAVOR` escrito à mão — diferente do `FLAVOR` — vence, exista ou
#      não no acervo. Quem escreveu `latte` com o Dracula no ar escolheu isso; se
#      não houver o que vestir, o script diz em português, como sempre disse.
#   2. O de fábrica (`"$FLAVOR"`, ou vazio, que vale o mesmo) que EXISTE no
#      acervo alcançado vale como está: o Catppuccin no Latte veste Latte.
#   3. O de fábrica que NÃO existe cai no `icones.mimetypes.flavor` do pack que
#      herda o acervo, se ele declarou um e esse um existe lá.
#   4. Sem nada disso, o de fábrica volta como veio — e o script diz que não há
#      acervo para ele, que é a resposta de antes. A regra não inventa um flavor
#      que ninguém escolheu.
#
# `ICONES_FLAVOR` IGUAL AO `FLAVOR` É TRATADO COMO O DE FÁBRICA
#   Depois do `.` do meow.conf a regra só vê o valor expandido, e não tem como
#   distinguir `"$FLAVOR"` de `"dracula"` escrito à mão com `FLAVOR="dracula"`.
#   Não precisa: nos dois casos o pedido é um flavor que o acervo não tem, e
#   vestir o que o pack escolheu é melhor que não vestir nada.
#
# O VAZIO DEIXOU DE SER MACCHIATO. Era `${ICONES_FLAVOR:-macchiato}` — um nome
#   do Catppuccin cravado em três scripts, e a escolha pessoal de ícones em
#   macchiato com a interface em mocha, de antes de 21/09/2026, quando a chave
#   passou a herdar o `FLAVOR` de fábrica. Vazio agora é "acompanha o tema",
#   como a chave de fábrica.
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
    dono = _pack_de(base)
    if dono == ident:
        p_dono, dados_dono = p, dados
    else:
        p_dono, dados_dono, _d = validar(dono, silencioso=True)
    return {
        "base": base,
        "dono": dono,
        "p_dono": p_dono,
        "dados_dono": dados_dono,
        "existem": [f for f in dados_dono["flavors"] if os.path.isdir(os.path.join(base, f))],
        "escolhido": campo(ident, "icones.mimetypes.flavor") if dono != ident else None,
    }


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

    # `derivado` É O CLARO QUE NINGUÉM DESENHOU [P31, 23/09/2026]. A «Variante
    # do tema» passou a oferecer os flavors DESTE pack, e o claro de um pack
    # feito de CSV pode ter saído do método do Latte: a opção diz isso ao lado
    # do nome, pela mesma conta do `meow pack info` e do cartão (P16).
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
                        "nome_de": nome_do_pack(q) if q else ""}
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


# --- O PACK QUE VIAJA: novo, exportar, importar — 23/09/2026, sprint P11 -----
#
# A QUEIXA, NAS PALAVRAS DELE
#   *"que qualquer um possa exportar o próprio tema e importar outros pro seu
#   sistema operacional."* Os botões Exportar e Importar do alto da página
#   existiam e funcionavam — mas eram de AJUSTES: levavam o meow.conf. Não havia
#   caminho, nem na tela nem aqui, para empacotar um pack e mandá-lo a alguém. O
#   docs/PACKS.md mandava publicar "como quiser: um git, um tarball", cada jeito
#   de quem publicava, e nada conferia do outro lado o que tinha chegado.
#
# TRÊS VERBOS, E NENHUM DELES APLICA TEMA
#   `novo` escreve um pack onde pack se escreve (packs/ do projeto, ou a raiz de
#   teste). `exportar` escreve o arquivo que a pessoa nomeou, e nada mais.
#   `importar` escreve em ~/.local/share/meowsystem/packs/, e só depois de
#   conferir tudo. Importar é GANHAR UMA OPÇÃO, não trocar de tema: quem troca é
#   o PACK do meow.conf, e ninguém aqui o toca.
#
# UM PACK É DADO, NUNCA É CÓDIGO — E A REGRA PASSA A SER CONFERIDA
#   Ela está no docs/PACKS.md desde o primeiro dia, e até aqui dependia de quem
#   escrevia o pack ter lido. Um `.meowpack` vem de fora, e fora é onde mora
#   quem não leu. Então um `.sh` — ou qualquer arquivo que comece com `#!`, que
#   é script seja qual for o nome — recusa o pacote INTEIRO, com uma linha por
#   arquivo. O `#!` é a mesma regra medida pelo conteúdo em vez do nome: um
#   `ganchos.txt` que abre com `#!/bin/sh` é o mesmo código com outra roupa. E
#   nada do que entra ganha bit de execução — todo arquivo nasce 0644, seja
#   qual for o modo que o tar diga.
#
# A LICENÇA, QUE A P28 JÁ TINHA DEIXADO ESCRITA
#   "PROCEDENCIA.md não é burocracia: é o que permite o `meow pack exportar`
#   recusar empacotar o que não pode ser redistribuído." Então o exportar recusa
#   pack sem CREDITOS.md, e lê a tabela do PROCEDENCIA.md: arte de terceiro sem
#   licença escrita na linha dela não sai daqui.
#
# O ARQUIVO
#       MANIFESTO        "meowpack 1", "formato <n>", "pack <id>", e uma linha
#                        "<sha256>  <caminho>" por arquivo — a forma do
#                        `sha256sum`, relativa ao diretório do pack
#       <id>/…           o diretório do pack, e nada fora dele
#   passado pelo zstd. `meowpack` é a versão DESTE contêiner e `formato` é a do
#   pack.json (a do docs/PACKS.md, "a versão do formato, não do seu pack"): os
#   dois mudam por motivos diferentes, e um número só obrigaria a subir os dois
#   quando só um mudou.
MEOWPACK = 1
MANIFESTO = "MANIFESTO"
# O TETO É DO ARQUIVO ABERTO, E NÃO DO COMPRIMIDO. O zstd reduz uma fila de
# zeros a quase nada: um `.meowpack` de um megabyte pode abrir em gigabytes e
# derrubar quem o lê. O maior pack daqui, o catppuccin, sai em 338 KB e abre
# num tar de 5.980.160 bytes com 3.903 entradas (medido em 23/09/2026). Os
# 2,4 MB que o `exportar` anuncia são a soma dos arquivos; o tar aberto pesa
# mais que o dobro porque cada um dos 3.902 arquivos (3.325 deles SVG, de 654
# bytes em média) ganha um cabeçalho de 512 bytes e é completado até o bloco
# seguinte — e é o aberto que este teto mede. Os dois tetos ficam em umas 45
# e cinco vezes isso. Os 256 MB não saem do catppuccin, e sim do teto de
# envio do painel (64 MB, `servidor.py`): um pack de capturas é raster, que
# o zstd não encolhe, então o aberto tem de caber folgado acima do enviado.
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


def _proibido(rel, cabeca):
    """Por que este arquivo não pode viajar dentro de um pack — ou None."""
    if rel.lower().endswith(".sh"):
        return "é script de shell"
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
                    motivo = _proibido(rel, fh.read(2))
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
        # Calado: o `ok` desta segunda conferência repetiria o da primeira, e a
        # pessoa leria duas validações onde pediu uma. A recusa não é calada.
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
    # O DESTINO É CONFERIDO ANTES DA PERGUNTA, E NÃO NA HORA DE ESCREVER — a
    #   revisão de 23/09/2026 mediu `exportar meu-tema <dir-inexistente>/x.meowpack`
    #   saindo com o traceback do `open`, depois de a pessoa já ter respondido
    #   pelas imagens. Não é recusa do pack (o pack está bom), então não passa
    #   pela `Recusa`: é o endereço que ela deu, e sai como erro de uso.
    pasta = os.path.dirname(saida)
    if not os.path.isdir(pasta):
        print(f"  erro {pasta}: esse diretório não existe — o exportar não cria pasta;\n"
              f"       crie-a antes, ou diga outro lugar", file=sys.stderr)
        return ERRO_USO

    # O TAMANHO É DITO ANTES, E A PERGUNTA SÓ VEM SE HÁ O QUE PERGUNTAR. É o
    # risco que a sprint escreveu: "um pack com 91 papéis de parede é grande".
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
    # E o que a conferência do destino não prevê — pasta sem permissão, disco
    # cheio — também sai numa linha, e sem deixar o `.parcial` para trás.
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
            motivo = _proibido(rel, dado[:2])
            if motivo:
                scripts.append(f"{m.name}: {motivo}")
            membros[rel] = dado
    _exigir(not scripts, "um pack é dado, nunca é código — este traz script:\n      "
                         + "\n      ".join(scripts))
    _exigir(ident and membros, f"{caminho}: não há pack nenhum aqui dentro")
    _exigir(manifesto is not None, f"{caminho}: sem o MANIFESTO, não há como conferir "
                                   f"o que chegou")
    _conferir_manifesto(manifesto, ident, membros)
    return ident, membros


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
        # O claro que ninguém desenhou se declara também ANTES de entrar
        # [23/09/2026, P16]: o `info` e o cartão já dizem, e a caixa de
        # confirmar mostrava "claro" igual para o derivado e para o desenhado.
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
    # O `.csv` SOLTO TAMBÉM SE IMPORTA — 23/09/2026, P16, item 5
    #   "O 'Importar um pack' de P11 aceita um .csv solto, não só um .meowpack."
    #   Ele não é lido como tarball: vira pack pelo `montar_novo`, o mesmo do
    #   `novo --de-csv`, e daí para baixo é o importar de sempre — o mesmo
    #   `_instalar_pack`, na mesma raiz da pessoa, com o mesmo "não aplica". É
    #   aqui que a tela chega, e não ao `novo`: o `novo` escreve em `packs/` do
    #   projeto, que é onde se publica por commit, e um clique no painel que
    #   deixasse um diretório no `git status` é a sujeira que a P21 tirou do
    #   repositório. A extensão decide, como decide para quem escolhe o arquivo.
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
                        + ("\n    O id sai do nome do CSV: com outro nome, ele vira outro pack."
                           if de_csv else ""))
    # Depois da conferência do id, e não antes: montar desenha os autorais, e
    # desenhar 22 ícones para então recusar pelo nome seria trabalho jogado fora.
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
        # `--de-csv <arquivo>` É MAIS UM RAMO, no lugar que a P11 deixou marcado,
        # com `next(it)` para o caminho. Sem o arquivo, ou com um segundo
        # `--de-csv`, é erro de uso: dois CSV não viram uma paleta, e um
        # `--seco` no lugar do arquivo seria lido como um CSV chamado `--seco`.
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

        som = {k: v for k, v in (pf.get("som") or {}).items() if not str(k).startswith("_")}
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
                    f"`icones/autorais/` foi desenhado pelo `meow pack construir`, nas cores "
                    f"desta paleta: os desenhos são os do MeowSystem. Mudou a paleta? Rode-o "
                    f"de novo.\n\n")
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
    """{icones/autorais/<nome>-<flavor>.svg: bytes} do pack que `arquivos` descreve.

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
        # OS DOIS ARGUMENTOS VÊM SEMPRE, VAZIOS OU NÃO: `adocao "" mocha` é o
        # conf de fábrica, e um verbo que aceitasse um só teria de adivinhar
        # qual dos dois chegou. Sai 0 também na recusa — a máquina veste o
        # padrão, que é resposta; o `recusado=` é o que o shell transforma em
        # aviso, com a cara dos avisos dele.
        if verbo == "adocao" and len(argv) == 4:
            ident, dir_pack, recusado = adocao(argv[2], argv[3])
            print(f"pack={ident}")
            print(f"dir={dir_pack}")
            print(f"recusado={recusado}")
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
            return OK
        if verbo == "tipografia" and len(argv) in (2, 3):
            # SAI 0 COM A LISTA VAZIA, e 1 só na recusa. Para quem instala, "o
            # pack não traz fonte" é uma resposta que manda LIMPAR as do pack
            # anterior; "a lista não valida" manda não tocar em nada. Os dois
            # não podem ter o mesmo código.
            quem, lista = tipografia((argv[2] if len(argv) == 3 else "") or None)
            for nome, origem, soma in lista:
                print(f"{quem}\t{nome}\t{origem}\t{soma or '-'}")
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
            # de comando seria uma segunda declaração do mesmo par. O `[id]`
            # vazio é o pack ativo, pela `_ref_ativa`, como no `ponteiro`.
            # VAZIO SAI 1, e não uma linha em branco: `acervo ... ""` devolve a
            # pasta-mãe do acervo, e um script que a tomasse por flavor diria
            # "0 já vestidos" com nada vestido.
            achado = flavor_de_icones((argv[2] if len(argv) == 3 else "") or None,
                                      os.environ.get("ICONES_FLAVOR"),
                                      os.environ.get("FLAVOR"))
            if not achado:
                return RECUSADO
            print(achado)
            return OK
        if verbo == "construir" and len(argv) in (3, 4):
            # O `--seco` é a mesma promessa do `MEOW_DRY_RUN` do lado shell: diz
            # o que faria e não escreve. Aceito pelos dois nomes porque quem
            # chama daqui é o `bin/meow`, que já traduz o ambiente em flag.
            return cmd_construir(argv[2], seco=(len(argv) == 4 and argv[3] in ("--seco", "--dry-run")))
        # OS TRÊS DA P11. As opções seguem cruas para o verbo, e é de propósito:
        # a P16 acrescenta `novo <id> --de-csv <arquivo>` como mais um ramo
        # dentro do `cmd_novo`, sem precisar mexer nesta linha.
        if verbo == "novo" and len(argv) >= 3:
            return cmd_novo(argv[2], argv[3:])
        if verbo == "exportar" and len(argv) >= 3:
            return cmd_exportar(argv[2], argv[3:])
        if verbo == "importar" and len(argv) >= 3:
            return cmd_importar(argv[2], argv[3:])
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
    except Falta as e:
        print(f"  erro {e}", file=sys.stderr)
        return SEM_DEPENDENCIA
    print(__doc__.strip(), file=sys.stderr)
    return ERRO_USO


if __name__ == "__main__":
    sys.exit(main(sys.argv))

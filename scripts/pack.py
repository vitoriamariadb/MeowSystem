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
    levar  <id> foto <arquivo>...
                                 copia a foto para `wallpapers/` do pack da
                                 pessoa (o que o Personalizar leva). Ver `levar_foto`.
    levar  <id> sons <pack>      copia o tema de sons que <pack> alcança para
                                 `sons/`, e o `som.tema` aponta para ele.
    levar  <id> som <arquivo.oga> <evento>
                                 troca o som de um evento que o tema já tem.
    levar  <id> sistema|biblioteca <arquivo.svg> [nome]
                                 copia o ícone para `icones/<pasta>/` do pack.
    tirar  <id> foto <nome>...   tira a foto de `wallpapers/` do pack da pessoa.
    tirar  <id> sistema|biblioteca <nome>...
    acervo-para-levar <id> sistema|biblioteca
                                 o que o Personalizar oferece, uma linha
                                 por ícone: `pack<TAB>nome<TAB>arquivo<TAB>sim|nao`.
    usar-desenho <id> <nome> <arquivo.svg>
                                 guarda o desenho do app em `icones/apps/` do pack seu.
    tirar-desenho <id> <nome>
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
import xml.etree.ElementTree as ET

FORMATO_MIN = 1
FORMATO_MAX = 2

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SLOTS = [
    "rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
    "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender",
    "text", "subtext1", "subtext0", "overlay2", "overlay1", "overlay0",
    "surface2", "surface1", "surface0", "base", "mantle", "crust",
]

RE_ID = re.compile(r"^[a-z0-9][a-z0-9-]*$")
RE_HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
RE_SHA256 = re.compile(r"^[0-9a-f]{64}$")
RE_CONF_PAPEL = {"repo_do_conf": re.compile(r"^WALLPAPER_[A-Z0-9_]*_REPO$"),
                 "commit_do_conf": re.compile(r"^WALLPAPER_[A-Z0-9_]*_COMMIT$")}
CHAVES_PAPEL = ("repo", "commit", "prefixo", "ignorar", "desenhos", "curadoria",
                "repo_do_conf", "commit_do_conf")
CHAVES_PAPEL_SEM_LEITOR = ("tipo", "se_vazio")

OK, RECUSADO, ERRO_USO = 0, 1, 2

CAMPOS_COM_LEITOR = {
    "formato", "id", "nome",
    "papel",
    "icones.apps.recolorir",
    "heranca",
    "creditos",
    "paleta", "paleta.arquivo",
    "paleta.flavor_padrao",
    "cosmic.mapa",
    "cosmic.nome_da_paleta",
    "temas.capturados",
    "icones.*.mapa",
    "icones.*.desenhos",
    "*.*.herda",
    "som.*",
    "apps.*.arquivo",
    "apps.*.sha256",
    "apps.*.spicetify_tema",
    "apps.*.esquema",
    "apps.*.acento_no_color_ini",
    "apps.*.origem.*",
    "autor", "versao", "licenca",
    "vitrine.capa",
    "vitrine.descricao_curta",
    "vitrine.descricao",
    "vitrine.tags",
    "vitrine.capturas",
    "vitrine.site",
    "origens.cursores.proprio",
    "fontes.proprio",
    "fontes.herda",
    "icones.mimetypes.flavor",
    "icones.gerador",
    "icones.autorais.gerar",
    "origens.cursores.tema",
    "icones.base.origem.*",
    "origens.cursores.origem.*",
    "icones.base.por_tras",
    "icones.mimetypes.derivar.*",
    "origens.wallpapers.desenhos", "origens.wallpapers.repo",
    "origens.wallpapers.commit", "origens.wallpapers.prefixo",
    "origens.wallpapers.curadoria", "origens.wallpapers.ignorar",
    "origens.wallpapers.repo_do_conf", "origens.wallpapers.commit_do_conf",
    "mascote.desenhos", "mascote.dia", "mascote.noite",
    "lancador.ocultar",
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
    achados = []
    for chave, valor in (no or {}).items():
        if str(chave).startswith("_"):
            continue
        aqui = f"{trilha}.{chave}" if trilha else str(chave)
        if isinstance(valor, dict):
            achados += campos_sem_leitor(valor, aqui)
        elif not _tem_leitor(aqui):
            achados.append(aqui)
    return sorted(achados)


def raiz_da_pessoa():
    xdg = os.environ.get("XDG_DATA_HOME") or os.path.join(
        os.path.expanduser("~"), ".local", "share")
    return os.path.join(xdg, "meowsystem", "packs")


def raizes():
    saida = []
    if os.environ.get("MEOW_PACKS"):
        saida.append(os.environ["MEOW_PACKS"])
    saida.append(raiz_da_pessoa())
    saida.append(os.path.join(RAIZ, "packs"))
    return saida


PACK_PADRAO = "meowsystem"

APELIDOS = {"catppuccin": "meowsystem"}


def achar(ref):
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
    return achar(PACK_PADRAO) or os.path.join(RAIZ, "packs", PACK_PADRAO)


def _flavors_do_pack(dir_pack):
    try:
        arq = campo(dir_pack, "paleta.arquivo", "paleta.json")
        with open(_dentro(dir_pack, arq, "paleta.arquivo"), encoding="utf-8") as fh:
            flavors = json.load(fh).get("flavors")
    except (OSError, ValueError, AttributeError, TypeError, Recusa):
        return set()
    return set(flavors) if isinstance(flavors, dict) else set()


def adocao(pack="", flavor=""):
    escolhido = pack or ""
    if not escolhido and flavor:
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
        return PACK_PADRAO, "", escolhido
    return os.path.basename(dir_pack), dir_pack, ""


def paleta_do_pack_ativo():
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
    dir_pack = achar(ref)
    if not dir_pack:
        return padrao
    try:
        with open(os.path.join(dir_pack, "pack.json"), encoding="utf-8") as fh:
            no = json.load(fh)
    except (OSError, ValueError):
        return padrao
    for parte in trilha.split("."):
        if not isinstance(no, dict) or parte not in no:
            return padrao
        no = no[parte]
    return padrao if no is None else no


def acervo(categoria, arquivo="", motor=None, ref=None):
    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        dir_pack = achar(ref)
        if not dir_pack:
            break
        declarado = campo(ref, categoria)
        if isinstance(declarado, str):
            try:
                alvo = _dentro(dir_pack,
                               os.path.join(declarado, arquivo) if arquivo else declarado,
                               categoria)
            except Recusa as e:
                print(f"  aviso {e} — esta camada foi ignorada", file=sys.stderr)
                alvo = None
            if alvo and os.path.exists(alvo):
                return alvo + os.sep if not arquivo and declarado.endswith("/") else alvo
        bloco = categoria.rsplit(".", 1)[0]
        ref = campo(ref, bloco + ".herda") or campo(ref, "heranca")
    if motor:
        alvo = os.path.join(RAIZ, motor, arquivo) if arquivo else os.path.join(RAIZ, motor)
        if os.path.exists(alvo):
            return alvo
    return None

def dir_acervo(categoria, ref=None, padrao=None):
    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    dir_pack = achar(ref) or dir_padrao()
    declarado = campo(ref, categoria)
    if not isinstance(declarado, str) or not declarado:
        if not padrao:
            return None
        declarado = padrao_do_formato(ref, padrao)
    real = _dentro(dir_pack, declarado, categoria)
    return real + os.sep if declarado.endswith("/") else real


MOTOR = "motor:"
PACK_BASE = "meowsystem"
ACERVO_DO_MOTOR = os.path.join("packs", PACK_BASE, "icones")
PASTAS_DE_ANTES = {
    "arcticons-apps": "apps",
    "convertidos-apps": "apps",
    "arcticons": "sistema",
    "autorais/leitura": "sistema",
}

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


PADROES_DE_ANTES = {"icones/apps/": "icones/autorais/",
                    "icones/biblioteca/feitos-a-mao/": "icones/feitos-a-mao/"}


def padrao_do_formato(ref, padrao):
    formato = campo(ref, "formato", FORMATO_MAX)
    if isinstance(formato, int) and formato < 2:
        return PADROES_DE_ANTES.get(padrao, padrao)
    return padrao


TABELA_DE_ANTES = os.path.join(RAIZ, "packs", "CAMINHOS-DE-ANTES.tsv")


def _tabela_de_antes():
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

OUTRO_PACK = "pack:"


def _caminho_da_maquina(resto):
    return resto.startswith("~") or os.path.isabs(resto)


def resolver_alvo(valor, base):
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
    if _caminho_da_maquina(resto):
        raise Recusa(f"{valor!r} é um endereço desta máquina, e não do pack. "
                     f"Copie a arte para dentro do pack e registre a origem no "
                     f"PROCEDENCIA.md — ver docs/PACKS.md, 'Fonte e derivados'")
    try:
        cheio = _dentro(raiz, resto, "alvo")
    except Recusa:
        raise Recusa(f"{valor!r} sai de {raiz}") from None
    if not os.path.exists(cheio) and "/" in resto.strip("/"):
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
                return _dentro(raiz, os.path.join(partes[0], nome), "alvo")
            except Recusa:
                pass
    return cheio


def cmd_alvo(base):
    for linha in sys.stdin:
        try:
            print(resolver_alvo(linha.rstrip("\n"), base))
        except Recusa as e:
            print(f"  aviso {e} — linha ignorada", file=sys.stderr)
            print()
    return OK


CATEGORIA_RESGATADOS = "icones.resgatados"


def ler_mapa(caminho):
    with open(caminho, encoding="utf-8") as fh:
        for num, linha in enumerate(fh, 1):
            util = linha.split("#", 1)[0]
            nome, sep, alvo = util.partition(":")
            nome, alvo = nome.strip(), alvo.strip()
            if sep and nome and alvo:
                yield num, nome, alvo


def _relativo(caminho):
    if caminho.startswith(RAIZ + os.sep):
        return os.path.relpath(caminho, RAIZ)
    return caminho


def _pack_de(caminho):
    d = os.path.dirname(os.path.abspath(caminho))
    while d and d != os.path.dirname(d):
        if os.path.isfile(os.path.join(d, "pack.json")):
            return os.path.basename(d)
        d = os.path.dirname(d)
    return "?"


def arquivo_de_escolhas():
    if os.environ.get("MEOW_ICONES_ESCOLHAS"):
        return os.environ["MEOW_ICONES_ESCOLHAS"]
    conf = os.environ.get("MEOW_CONF") or os.path.join(os.path.expanduser("~"), ".config",
                                                       "meow", "meow.conf")
    return os.path.join(os.path.dirname(conf), "icones-escolhidos.map")


def _alvo_de_escolha(alvo):
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
    try:
        linhas = list(ler_mapa(arquivo_de_escolhas()))
    except OSError:
        return []
    saida = []
    for num, nome, alvo in linhas:
        try:
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
    return fontes_e_atras(ref)[0]


def fontes_e_atras(ref=None):
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
                if len(campos) >= 3 and nome and nome_de_destino(nome):
                    do_motor.append(
                        (nome, _relativo(os.path.join(pasta_resg, nome + ".svg")), "resgatados"))
    ligada = (os.environ.get("ICONES_DRACULA") or "sim") != "nao"
    vence = {nome for nome, _fonte, _camada in (do_pack if ligada else do_motor)}
    atras = [linha for linha in (do_motor if ligada else do_pack) if linha[0] in vence]
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
    valem, atras = fontes_e_atras(ref)
    achadas = [(f, c) for n, f, c in valem if n == nome]
    for fonte, camada in achadas:
        print(f"{nome}\t{fonte}\t{camada}")
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


COLUNAS_PROCEDENCIA = ("arquivo", "lido de", "sha256")


def _tabela_procedencia(caminho):
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
            origem = _origem(lido) if lido else ""
            _exigir(RE_SHA256.match(reg), f"sha256 {reg!r} não tem 64 hex")
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

MARCA_ACCENT = "<accent>"
PASTA_AUTORAIS = "icones/apps/"
CATALOGO = "catalog.json"
LACUNAS_DO_GERADOR = ("titulo",)
RE_PAPEL = re.compile(r"^[a-z][a-z0-9_]*$")
RE_LACUNA = re.compile(r"\{([^{}]*)\}")
_COR_DIGITADA = re.compile(r"#[0-9A-Fa-f]{3,8}\b|rgba?\s*\(|hsla?\s*\(")
_AUTORAL_PROIBIDO = re.compile(
    r"<script|<foreignObject|\son[a-z]+\s*=|javascript:|href\s*=\s*[\"'](?!#)", re.I)
CAMPOS_DO_AUTORAL = ("papeis", "svg")


def ler_autoral(caminho):
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
    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    achados = {}
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        dir_pack = achar(ref)
        if not dir_pack:
            break
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


CAPTURAS_DO_MOTOR = os.path.join("assets", "temas", "capturados")
CAPTURAS_NO_PACK = os.path.join("temas", "capturados")
CATEGORIA_CAPTURA = "temas.capturados"

CAPTURA_DO_MOTOR = "original"


def _cadeia(ref):
    vistos = set()
    while ref and ref not in vistos:
        vistos.add(ref)
        dir_pack = achar(ref)
        if not dir_pack:
            break
        yield ref, dir_pack
        ref = campo(ref, "temas.herda") or campo(ref, "heranca")


def _dir_capturas(ref, dir_pack):
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
    if par == CAPTURA_DO_MOTOR:
        return os.path.join(RAIZ, CAPTURAS_DO_MOTOR, par)
    if not nome_de_destino(par):
        return None
    ref = _ref_ativa(ref)
    dir_pack = achar(ref)
    if not dir_pack:
        return None
    base = _dir_capturas(ref, dir_pack)
    return os.path.join(base, par) if base else None


def capturas(ref=None):
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
    partes = categoria.split(".")
    if len(partes) < 3 or partes[0] != "apps":
        raise Recusa(f"tema_de_app: {categoria!r} não é 'apps.<app>.<chave>'")
    alvo, chave = partes[1], partes[2:]

    ref = ref if ref is not None else (os.environ.get("MEOW_PACK_DIR") or PACK_PADRAO)
    flavor = os.environ.get("FLAVOR") or campo(ref, "paleta.flavor_padrao") or ""

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


CATEGORIA_PONTEIRO = "origens.cursores.proprio"
SUFIXO_PONTEIRO = "-cursors"
RE_NOME_PONTEIRO = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]{0,79}$")
RE_NOME_MASCOTE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]{0,79}$")
PONTEIROS_DE_REPOUSO = ("default", "left_ptr")


def valor_do_ponteiro(nome):
    return nome[:-len(SUFIXO_PONTEIRO)] if nome.endswith(SUFIXO_PONTEIRO) else nome


def conferir_ponteiro(tema, campo=CATEGORIA_PONTEIRO):
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


EXT_PACOTE = (".tar.gz", ".tgz", ".tar.xz", ".txz")
RE_PASTA_PACOTE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]*(/[A-Za-z0-9_][A-Za-z0-9._-]*)*$")
RE_NOME_TEMA_SPICETIFY = re.compile(r"[A-Za-z0-9_][A-Za-z0-9._-]{0,79}")
RE_REPO_GITHUB = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+")
RE_COMMIT = re.compile(r"[0-9a-f]{40}")


def origem_pinada(origem, trilha, com_nome=False):
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
    from urllib.parse import urlsplit
    partes = urlsplit(url)
    caminho = [p for p in partes.path.split("/") if p]
    return "/".join([partes.netloc] + caminho[:2])


def _ponteiro_de_fora(ref):
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


CATEGORIA_FONTES = "fontes"
EXT_FONTE = (".ttf", ".otf")
RE_NOME_FONTE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9 ._+-]{0,119}$")
ASSINATURAS_DE_FONTE = (b"\x00\x01\x00\x00", b"true", b"OTTO")


def _fontes_declaradas(dir_pack, lista, trilha="fontes.proprio"):
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


CATEGORIA_BASE = "icones.base"
ICONES_BASE_DO_EXEMPLO = "Papirus-Dark"


def _base_escolhida(pedido):
    pedido = (pedido or "").strip()
    nossa = (os.environ.get("NOME_TEMA_ICONES") or "").strip() or "MeowSystem-Icons"
    if re.fullmatch(re.escape(nossa) + r"-Base(-[0-9]+)?", pedido):
        return ""
    return "" if pedido in ("", ICONES_BASE_DO_EXEMPLO) else pedido


def base_de_icones(ref=None):
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
            atras = [origem_pinada(c.get("origem") if isinstance(c, dict) else None,
                                   f"{CATEGORIA_BASE}.por_tras[{i}].origem")
                     for i, c in enumerate(bloco.get("por_tras") or [])]
            return dict(origem_pinada(bloco["origem"], CATEGORIA_BASE + ".origem"),
                        pack=quem, por_tras=atras)
        prox = bloco.get("herda") if isinstance(bloco, dict) else None
        ref = prox or campo(ref, "heranca")
    return None


def base_que_vale(ref, pedido):
    escolhida = _base_escolhida(pedido)
    declarada = base_de_icones(ref)
    if escolhida:
        return "conf", escolhida, declarada
    if declarada:
        return "pack", "", declarada
    return "motor", ICONES_BASE_DO_EXEMPLO, None


def dir_de_tema_de_icones(nome):
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


def _so_letras(texto):
    return re.sub(r"[^A-Za-z0-9]+", "", str(texto or ""))


def tema_de_icones(ref=None, flavor=""):
    ref = _ref_ativa(ref)
    dir_pack = achar(ref)
    ident = (campo(ref, "id") or os.path.basename(dir_pack or "") or "pack") if dir_pack else str(ref)
    nome = str(campo(ref, "nome", ident) or ident) if dir_pack else ident
    flavor = (flavor or (campo(ref, "paleta.flavor_padrao", "") if dir_pack else "") or "").strip()
    partes = ["MeowSystem", _so_letras(nome) or _so_letras(ident) or "Pack"]
    if partes[1].lower() == "meowsystem":
        partes = ["MeowSystem"]
    if flavor and flavor.lower() != ident.lower() and _so_letras(flavor):
        partes.append(_so_letras(flavor)[:1].upper() + _so_letras(flavor)[1:])
    frase = str(campo(ref, "vitrine.descricao_curta", "") or "").strip() if dir_pack else ""
    comentario = f"{nome} ({flavor})" if flavor else nome
    comentario += f" — {frase}" if frase else " — gerado pelo MeowSystem"
    return "-".join(partes + ["Icons"]), comentario.replace("\n", " ")


RE_DESKTOP_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,200}$")


def ocultar_do_pack(ref=None):
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
    tema = _base_escolhida(pedido) or ICONES_BASE_DO_EXEMPLO
    return tema, dir_de_tema_de_icones(tema)


def _rgb(hexcor):
    return tuple(int(hexcor[i:i + 2], 16) / 255 for i in (1, 3, 5))


def _luminancia(hexcor):
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
    pass


def _exigir(cond, msg):
    if not cond:
        raise Recusa(msg)


RE_NOME_DESTINO = re.compile(r"^[A-Za-z0-9._+-]+$")


def nome_de_destino(nome):
    return isinstance(nome, str) and bool(RE_NOME_DESTINO.fullmatch(nome)) \
        and ".." not in nome and nome != "."


RE_CONTROLE = re.compile(r"[\x00-\x1f\x7f-\x9f]")


def _caractere_de_controle(doc, trilha="raiz"):
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
    try:
        cheio = os.path.realpath(os.path.join(base, alvo))
    except (TypeError, ValueError):
        raise Recusa(f"{campo}: {alvo!r} não é caminho (NUL ou tipo errado)") from None
    if not cheio.startswith(os.path.realpath(base) + os.sep):
        raise Recusa(f"{campo}: {alvo!r} sai de dentro do pack")
    return cheio


REFERENCIA_CLARA = "latte"
COLUNAS_CSV = ("slot", "flavor", "hex")
RE_FLAVOR_CSV = re.compile(r"^[a-z0-9]+$")
SUFIXO_DO_CLARO = "claro"

TOLERANCIA_DA_REGUA = 0.95
MINIMO_TEXTO = 7.0
MINIMO_VALIDAR = 4.5


def _hexa(r, g, b):
    return "#%02X%02X%02X" % tuple(max(0, min(255, round(c * 255))) for c in (r, g, b))


def _referencia_clara():
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
    import colorsys
    h_base = colorsys.rgb_to_hsv(*_rgb(escuro["base"]))[0]
    claro = {}
    for k in SLOTS:
        h_d, s_d, _ = colorsys.rgb_to_hsv(*_rgb(escuro[k]))
        if s_d < 0.10:
            h_d = h_base
        s_l = colorsys.rgb_to_hsv(*_rgb(referencia[k]))[1]
        alvo = _luminancia(referencia[k])
        for tentativa in range(12):
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
    while contraste(claro["text"], claro["base"]) < MINIMO_TEXTO + 0.02:
        h, sv, vv = colorsys.rgb_to_hsv(*_rgb(claro["text"]))
        vv -= 0.004
        if vv <= 0:
            break
        claro["text"] = _hexa(*colorsys.hsv_to_rgb(h, sv, vv))
    return claro


def regua_de_contraste(dados, referencia):
    saida = []
    for flavor, cores in dados["flavors"].items():
        r_text = contraste(cores["text"], cores["base"])
        if r_text < MINIMO_TEXTO:
            saida.append(f"{flavor}: text/base {r_text:.2f} — AAA pede {MINIMO_TEXTO:.1f}"
                         + (f"; abaixo de {MINIMO_VALIDAR} o `validar` recusa o pack"
                            if r_text < MINIMO_VALIDAR else ""))
        for s in SLOTS:
            if s == "text" and r_text < MINIMO_TEXTO:
                continue
            r = contraste(cores[s], cores["base"])
            ref = contraste(referencia[s], referencia["base"])
            if r < ref * TOLERANCIA_DA_REGUA:
                saida.append(f"{flavor}: {s}/base {r:.2f} — o {REFERENCIA_CLARA.capitalize()} faz "
                             f"{ref:.2f} no mesmo slot")
    return saida


def claros_derivados(dados):
    deriv = dados.get("derivados")
    claros = dados.get("claros")
    if not isinstance(deriv, dict) or not isinstance(claros, list):
        return {}
    return {c: e for c, e in deriv.items()
            if isinstance(c, str) and isinstance(e, str)
            and c in claros and e in dados["flavors"]}


def paleta_de_csv(caminho):
    import csv
    nome = os.path.basename(caminho)
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
        onde[(flavor, slot)] = num
        if not RE_HEX.match(hexcor):
            erros.append(f"{nome}:{num}: {slot} = {hexcor!r} não é #RRGGBB")
            continue
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
    derivados = claros_derivados(dados)
    lidos = [f for f in dados["flavors"] if f not in derivados]
    print(f"  ok   {os.path.basename(caminho)}: {len(lidos)} flavor(s), "
          f"26 slots conferidos — {', '.join(lidos)}", file=arq)
    for claro, escuro in derivados.items():
        print(f"  --   {claro}: claro derivado de {escuro!r} pelo método do Latte — "
              f"não é próprio.\n"
              f"       Para ter o seu, traga as 26 linhas dele no CSV.", file=arq)
    if reprovados:
        print(f"  aviso {len(reprovados)} abaixo da régua de contraste (docs/PACKS.md) — "
              f"não bloqueia, a decisão é sua:", file=arq)
        for linha in reprovados:
            print(f"          {linha}", file=arq)


def id_do_csv(caminho):
    import unicodedata
    base = os.path.splitext(os.path.basename(caminho))[0]
    sem_acento = unicodedata.normalize("NFKD", base).encode("ascii", "ignore").decode("ascii")
    ident = re.sub(r"[^a-z0-9]+", "-", sem_acento.lower()).strip("-")
    _exigir(RE_ID.match(ident),
            f"{os.path.basename(caminho)}: o id do pack sai do nome do arquivo, e deste\n"
            f"    não sai nenhum. Renomeie-o com letras ou dígitos — 'minhas-cores.csv'\n"
            f"    vira o pack minhas-cores.")
    return ident


LOGO = "logo.svg"
SVG_NS = "{http://www.w3.org/2000/svg}"
ACCENT_NO_LOGO = "__ACCENT__"
PAPEIS_DO_LOGO = {
    "fundo":   "base",
    "tinta":   "text",
    "sujeito": ACCENT_NO_LOGO,
}
ACCENT_PADRAO_DO_LOGO = "mauve"
RE_ESTILO_PAPEIS = re.compile(
    r"""\s*<style\b[^>]*?\bid\s*=\s*(["'])meow-papeis\1[^>]*?(?:/>|>.*?</style>)""", re.S)
RE_RAIZ_SVG = re.compile(r"<svg\b[^>]*>")
RE_URL_CSS = re.compile(r"""url\(\s*['"]?\s*([^)'"\s]*)""", re.I)
RE_ESCAPE_CSS = re.compile(r"\\(?:([0-9a-fA-F]{1,6})[ \t\n\r\f]?|(.))", re.S)
XHTML_NS = "{http://www.w3.org/1999/xhtml}"

ELEMENTOS_RECUSADOS_NO_LOGO = {
    "script": "executa código",
    "image": "embute imagem (um logo é vetor, não uma foto dentro de um SVG)",
    "feImage": "embute imagem por dentro de um filtro",
    "foreignObject": "embute HTML dentro do SVG",
}


def _ler_logo(caminho, nome):
    with open(caminho, "rb") as fh:
        bruto = fh.read()
    try:
        texto = bruto.decode("utf-8")
    except UnicodeDecodeError:
        raise Recusa(f"{nome}: não é texto — é um SVG de verdade, ou uma imagem "
                     f"renomeada?\n    Um PNG com nome de .svg não vira vetor.") from None
    _exigir("<!ENTITY" not in texto,
            f"{nome}: declara <!ENTITY> — um logo não precisa de entidade, e ela "
            f"pode travar quem o lê")
    try:
        raiz = ET.fromstring(bruto)
    except ET.ParseError as e:
        raise Recusa(f"{nome}: não é XML válido — {e}") from None
    leitor = ET.XMLPullParser(events=("pi",))
    leitor.feed(bruto)
    leitor.close()
    instrucoes = [el.text or "" for _evento, el in leitor.read_events()]
    return texto, raiz, instrucoes


def _nome_do_logo(p):
    v = p.get("vitrine")
    capa = v.get("capa") if isinstance(v, dict) else None
    return capa if isinstance(capa, str) and capa else LOGO


def _css_sem_escape(t):
    def um(m):
        if m.group(1) is None:
            return m.group(2)
        n = int(m.group(1), 16)
        return chr(n) if 0 < n <= 0x10FFFF and not 0xD800 <= n <= 0xDFFF else "\ufffd"
    return RE_ESCAPE_CSS.sub(um, t)


def _validar_logo(dir_pack, p):
    arq = _nome_do_logo(p)
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
    alvo_pi = instrucoes[0].split(None, 1)[0] if instrucoes else ""
    _exigir(not instrucoes,
            f"{arq}: tem <?{alvo_pi} ...?> — uma instrução de\n"
            f"    processamento. A <?xml-stylesheet?> busca folha de fora, e o navegador a segue.\n"
            f"    Um logo se basta: só a declaração <?xml ...?> do topo é aceita.")

    vb = (raiz.get("viewBox") or "").strip()
    partes = [x for x in re.split(r"[\s,]+", vb) if x]
    try:
        _x, _y, larg, alt = (float(x) for x in partes)
    except ValueError:
        raise Recusa(f"{arq}: precisa de viewBox com quatro números, veio {vb!r}") from None
    _exigir(larg > 0 and larg == alt,
            f"{arq}: o viewBox {vb!r} não é quadrado.\n"
            f"    O lançador pede o ícone em 48, 64, 128 e 256 — todos quadrados.")

    recusados = {k.lower(): v for k, v in ELEMENTOS_RECUSADOS_NO_LOGO.items()}
    for el in raiz.iter():
        nome = str(el.tag).rsplit("}", 1)[-1]
        _exigir(nome.lower() not in recusados,
                f"{arq}: tem <{nome}>, que {recusados.get(nome.lower())}. "
                f"Um pack é dado, nunca código.")
        _exigir(not str(el.tag).startswith(XHTML_NS),
                f"{arq}: tem <{nome}> do HTML dentro do SVG. Ele não desenha nada ali, e o\n"
                f"    navegador o cria assim mesmo — um <img src> busca a imagem. Um logo é vetor.")
        textos = [el.text or ""] if nome.lower() == "style" else []
        for chave, valor in el.attrib.items():
            local = chave.rsplit("}", 1)[-1].lower()
            _exigir(not local.startswith("on"),
                    f"{arq}: o atributo {local!r} executa código. Um pack é dado, nunca código.")
            if local == "href":
                _exigir(valor.strip().startswith("#"),
                        f"{arq}: href={valor!r} aponta para fora do arquivo.\n"
                        f"    Só referência interna (#id): o logo é copiado para o tema de\n"
                        f"    ícones, e lá fora nenhum outro caminho existe.")
            if local == "attributename":
                _exigir(not valor.strip().lower().endswith("href"),
                        f"{arq}: <{nome} attributeName={valor!r}> troca o destino de um link\n"
                        f"    depois de carregado — é o href apontando para fora por outra porta.")
            textos.append(valor)
        for t in textos:
            plano = _css_sem_escape(t)
            _exigir("@import" not in plano.lower(),
                    f"{arq}: <style> com @import busca folha de fora. Um logo se basta.")
            _exigir("image-set(" not in plano.lower(),
                    f"{arq}: image-set() carrega imagem de fora. Um logo é vetor, e se basta.")
            for alvo in RE_URL_CSS.findall(plano):
                _exigir(alvo.startswith("#"),
                        f"{arq}: url({alvo}) aponta para fora do arquivo — URL remota\n"
                        f"    ou caminho, não importa: só url(#id) sobrevive à cópia.")
    return texto, raiz


def _cores_do_logo(dados, flavor, accent):
    cores = dados["flavors"][flavor]
    tabela = {s: cores[s] for s in SLOTS}
    for papel, slot in PAPEIS_DO_LOGO.items():
        tabela[papel] = cores[accent if slot == ACCENT_NO_LOGO else slot]
    return tabela


def _aplicar_papeis(texto, raiz, cores):
    usadas = sorted({c for el in raiz.iter() for c in (el.get("class") or "").split()})
    regras = []
    for classe in usadas:
        papel = classe[len("traco-"):] if classe.startswith("traco-") else classe
        if papel in cores:
            prop = "stroke" if classe != papel else "fill"
            regras.append(f".{classe}{{{prop}:{cores[papel]}}}")
    sem_bloco = RE_ESTILO_PAPEIS.sub("", texto)
    abertura = RE_RAIZ_SVG.search(sem_bloco)
    if not regras or not abertura or abertura.group(0).endswith("/>"):
        return sem_bloco
    bloco = f'\n  <style id="meow-papeis">{"".join(regras)}</style>'
    return sem_bloco[:abertura.end()] + bloco + sem_bloco[abertura.end():]


def _flavor_e_accent(p, dados, flavor=None, accent=None):
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
    p, dados, dir_pack = validar(ref, silencioso=True)
    texto, raiz = _validar_logo(dir_pack, p)
    flavor, accent = _flavor_e_accent(p, dados, flavor, accent)
    return _aplicar_papeis(texto, raiz, _cores_do_logo(dados, flavor, accent))


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
    import unicodedata
    from xml.sax.saxutils import escape, quoteattr

    def inicial_de(texto):
        c = next((c for c in texto if c.isalnum()), "")
        base = unicodedata.normalize("NFKD", c)[:1].lower()
        return base if base in _GLIFOS_DO_LOGO else None
    inicial = inicial_de(nome) or inicial_de(ident) or "o"
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
    p, dados, dir_pack = validar(ref, silencioso=True)
    svg = logo_gerado(str(p.get("nome") or p["id"]), str(p["id"]))
    flavor, accent = _flavor_e_accent(p, dados, flavor, accent)
    sys.stdout.write(_aplicar_papeis(svg, ET.fromstring(svg), _cores_do_logo(dados, flavor, accent)))
    return OK


TETO_DESCRICAO_CURTA = 80
TETO_DESCRICAO = 64 * 1024
EXT_CAPTURA = (".png", ".jpg", ".jpeg", ".svg")


def vitrine(p, dir_pack):
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

    site = v.get("site")
    if site is not None:
        if isinstance(site, str) and site.startswith("https://"):
            saida["site"] = site
        else:
            problemas.append(f"vitrine.site: {site!r} — só https:// vira link no cartão")
    return saida, problemas


RE_CASA_DE_ALGUEM = re.compile(r"/(?:home|Users)/[\w.-]+/")


def nomes_de_usuario(dir_pack):
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

    for nome_arq, doc in (("pack.json", p), (arq, dados)):
        ruim = _caractere_de_controle(doc)
        _exigir(ruim is None,
                f"{nome_arq}: {ruim} tem caractere de controle — texto de pack é uma\n"
                f"    linha de letras; o terminal e o tema dos aplicativos o leriam como comando")

    for campo in ("flavors", "nomes", "claros"):
        _exigir(campo in dados, f"{arq}: falta o campo {campo!r}")
    _exigir(isinstance(dados["flavors"], dict) and dados["flavors"],
            f"{arq}: 'flavors' está vazio")

    for flavor in dados["flavors"]:
        _exigir("-" not in flavor,
                f"{arq}: o flavor {flavor!r} tem hífen no nome.\n"
                f"    O tema é gravado como '<flavor>-<accent>', e o hífen parte\n"
                f"    o nome no lugar errado. Use uma palavra só: o Catppuccin\n"
                f"    faz 'latte'/'mocha', e o Dracula claro daqui é 'alucard'.")

    for campo in ("flavors", "claros"):
        nomes = dados[campo] if isinstance(dados[campo], (dict, list)) else []
        for flavor in nomes:
            _exigir(isinstance(flavor, str) and RE_FLAVOR_CONF.match(flavor),
                    f"{arq}: o nome {flavor!r} em {campo!r} não é um nome de flavor.\n"
                    f"    Ele vira caminho de pasta e linha do meow.conf: use só\n"
                    f"    letras minúsculas, algarismos e '_' (como 'latte' ou 'alucard').")

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

    for flavor, cores in dados["flavors"].items():
        r = contraste(cores["text"], cores["base"])
        _exigir(r >= MINIMO_VALIDAR,
                f"{arq}: no flavor {flavor!r}, 'text' sobre 'base' tem contraste "
                f"{r:.2f}:1 — WCAG AA pede {MINIMO_VALIDAR}:1.\n"
                f"      text={cores['text']}  base={cores['base']}\n"
                f"    Com esse contraste a interface fica ilegível. Escureça o fundo\n"
                f"    ou clareie o texto.")

    ic = p.get("icones") or {}
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
    oc = (p.get("lancador") or {}).get("ocultar") if isinstance(p.get("lancador"), dict) else None
    if p.get("lancador") is not None:
        _exigir(isinstance(p.get("lancador"), dict) and isinstance(oc, list)
                and all(isinstance(n, str) and RE_DESKTOP_ID.match(n) for n in oc),
                "lancador.ocultar: uma lista de ids de `.desktop` (letras, dígitos, '.', '_' e '-'),\n"
                "    sem '/' e sem a extensão — viram nome de arquivo do sistema.")
    der = (ic.get("mimetypes") or {}).get("derivar")
    if der is not None:
        _exigir(isinstance(der, dict) and isinstance(der.get("de"), str) and der.get("de")
                and isinstance(der.get("pasta"), str) and RE_PASTA_PACOTE.match(der["pasta"])
                and "/" not in der["pasta"] and (ic.get("mimetypes") or {}).get("desenhos"),
                "icones.mimetypes.derivar: {\"de\": \"<id do pack>\", \"pasta\": \"<pasta do acervo dele>\"},\n"
                "    ao lado de `desenhos`, que é onde a derivação escreve.")

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

    if not silencioso:
        _tres_pastas(p, dir_pack)

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
                if a == "catalog.json" and os.path.isfile(cheio) and not os.path.islink(cheio):
                    continue
                if not a.endswith(EXT_DA_BIBLIOTECA) or os.path.islink(cheio) \
                        or not os.path.isfile(cheio):
                    fora_da_forma.append(os.path.normpath(os.path.join(rel_b, a)))
        _exigir(not fora_da_forma,
                f"{PASTA_BIBLIOTECA}: {len(fora_da_forma)} entrada(s) que não são desenho "
                f"(.svg ou .png comum, sem link):\n      " + "\n      ".join(fora_da_forma))

    pasta_aut = dir_acervo("icones.autorais.desenhos", ref=dir_pack, padrao=PASTA_AUTORAIS)
    if os.path.isdir(pasta_aut):
        for arq in sorted(os.listdir(pasta_aut)):
            if arq.endswith(".json") and arq != CATALOGO:
                ler_autoral(os.path.join(pasta_aut, arq))

    if (p.get("cosmic") or {}).get("mapa"):
        alvo = _dentro(dir_pack, p["cosmic"]["mapa"], "cosmic.mapa")
        _exigir(os.path.isfile(alvo), f"cosmic.mapa: {p['cosmic']['mapa']!r} não existe")

    if p.get("creditos"):
        alvo = _dentro(dir_pack, p["creditos"], "creditos")
        _exigir(os.path.isfile(alvo),
                f"creditos: {p['creditos']!r} está declarado e NÃO existe no pack.\n"
                f"    Ou crie o arquivo, ou tire o campo. Um pack que promete\n"
                f"    crédito de arte e não entrega ensina a promessa vazia —\n"
                f"    e quem copiar este pack.json vai repetir a promessa.")

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
            _exigir(medido == str(soma_app).lower(),
                    f"apps.{nome_app}.sha256 não confere com o arquivo.\n"
                    f"    declarado: {soma_app}\n"
                    f"    medido   : {medido}")
        if "spicetify_tema" in bloco:
            tema_spi = bloco["spicetify_tema"]
            _exigir(isinstance(tema_spi, str) and RE_NOME_TEMA_SPICETIFY.fullmatch(tema_spi),
                    f"apps.{nome_app}.spicetify_tema: {tema_spi!r} não é nome de pasta de tema.\n"
                    f"    Só letras, dígitos, '.', '_' e '-', sem começar por '.' ou '-'.")
        orig_spi = bloco.get("origem") if nome_app == "spotify" else None
        if orig_spi is not None:
            _exigir(isinstance(orig_spi, dict)
                    and isinstance(orig_spi.get("repo"), str) and RE_REPO_GITHUB.fullmatch(orig_spi["repo"])
                    and isinstance(orig_spi.get("commit"), str) and RE_COMMIT.fullmatch(orig_spi["commit"])
                    and isinstance(orig_spi.get("pasta"), str) and RE_PASTA_PACOTE.fullmatch(orig_spi["pasta"]),
                    f"apps.{nome_app}.origem: {{\"repo\": \"<dono>/<repo>\", \"commit\": \"<40 hex>\",\n"
                    f"    \"pasta\": \"<dentro do pacote>\"}}, sem '..' e sem barra na frente. Veio: {orig_spi!r}")

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

    if isinstance(cur, dict) and "origem" in cur:
        _exigir("proprio" not in cur and not cur.get("herda"),
                "origens.cursores: `origem` vem sozinha. Ou o pack baixa o ponteiro, ou o\n"
                "    traz dentro dele (`proprio`), ou herda o de outro (`herda`).")
        origem_pinada(cur["origem"], "origens.cursores.origem", com_nome=True)
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

    som = p.get("som") or {}
    LIMITES = {
        "fundamental":    (60.0,  8000.0),
        "harmonico":      (60.0, 12000.0),
        "peso_fundamental": (0.0,   1.0),
        "peso_harmonico":   (0.0,   1.0),
        "decaimento":      (5.0,  200.0),
        "duracao":        (0.010,  0.125),
        "ganho":           (0.0,    0.40),
    }
    for chave, valor in som.items():
        if chave.startswith("_"):
            continue
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

    herancas = [p["heranca"]] if p.get("heranca") else []
    for cat, bloco in (list(ic.items()) + list((p.get("origens") or {}).items())
                       + list((p.get("apps") or {}).items())
                       + [(CATEGORIA_FONTES, p.get(CATEGORIA_FONTES))]):
        if isinstance(bloco, dict) and bloco.get("herda"):
            herancas.append(bloco["herda"])
    for h in set(herancas):
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

    if not silencioso and "derivados" in dados:
        bons = claros_derivados(dados)
        deriv = dados["derivados"]
        tortos = sorted(set(deriv) - set(bons)) if isinstance(deriv, dict) else ["(não é um objeto)"]
        _exigir(not tortos,
                f"{arq}: 'derivados' é {{claro: escuro de onde ele saiu}} — o claro\n"
                f"    listado em 'claros', o escuro em 'flavors'. Não confere: "
                f"{', '.join(map(str, tortos))}")

    if not silencioso:
        casas = nomes_de_usuario(dir_pack)
        _exigir(not casas,
                f"{len(casas)} linha(s) com a casa de alguém escrita por extenso — o pack\n"
                f"    viaja, e o nome de usuário iria junto. Escreva ~/ no lugar dela, que\n"
                f"    diz o mesmo sem dizer de quem:\n      " + "\n      ".join(casas))

    if not silencioso:
        _, problemas = vitrine(p, dir_pack)
        _exigir(not problemas, "\n  erro ".join(problemas))

    if not silencioso:
        _validar_logo(dir_pack, p)

    if not silencioso:
        mortos = campos_sem_leitor(p)
        if mortos:
            print(f"  aviso {len(mortos)} campo(s) que este pack declara e NENHUM código lê:",
                  file=sys.stderr)
            for trilha in mortos:
                print(f"          {trilha}", file=sys.stderr)
            print("        Eles não quebram nada — e também não fazem nada: "
                  "nenhuma linha deste projeto os consulta.\n"
                  "        O que cada campo deveria significar está em docs/PACKS.md.",
                  file=sys.stderr)
        n_fl = len(dados["flavors"])
        print(f"  ok   {p['nome']} ({p['id']}) — formato {p['formato']}, "
              f"{n_fl} flavor(s), 26 slots conferidos")
    return p, dados, dir_pack


PAPEL_BASE = "base"


def eh_base(ref):
    return campo(ref, "papel") == PAPEL_BASE


def _tres_pastas(p, dir_pack):
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
    dentro = sorted(f"{t}/{d}" for t in PASTAS_DO_FORMATO if os.path.isdir(os.path.join(pasta, t))
                    for d in os.listdir(os.path.join(pasta, t))
                    if os.path.isdir(os.path.join(pasta, t, d)))
    _exigir(not dentro,
            f"icones/: {', '.join(dentro)} — as três pastas não têm subpasta. O flavor vai no\n"
            f"    nome (`desenho-mocha.svg`) e a origem no PROCEDENCIA.md; ponha os arquivos direto\n"
            f"    em apps/, sistema/ ou biblioteca/.")


def _conferir_papeis(p):
    wp = (p.get("origens") or {}).get("wallpapers")
    if not isinstance(wp, dict):
        return
    for chave in wp:
        if str(chave).startswith("_"):
            continue
        _exigir(chave != "fotos",
                "origens.wallpapers.fotos: as fotos do pack não se declaram — são as imagens\n"
                "    soltas na pasta wallpapers/ dele")
        _exigir(chave in CHAVES_PAPEL or chave in CHAVES_PAPEL_SEM_LEITOR,
                f"origens.wallpapers.{chave}: chave que o formato não tem")
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


def _contar_acervo(ref, categoria, flavors):
    dir_acv = acervo(categoria + ".desenhos", ref=ref)
    if not dir_acv or not os.path.isdir(dir_acv):
        return "", ""
    svgs = []
    for base, _dirs, arquivos in os.walk(dir_acv):
        svgs += [os.path.join(base, a) for a in arquivos if a.endswith(".svg")]
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
    achados = {f for f in flavors for a in svgs if a.endswith(f"-{f}.svg")}
    quantos = f"{len(svgs):,} desenho(s)".replace(",", ".")
    return quantos, (f"{len(achados)} flavor(s)" if achados else "")


PASTA_BIBLIOTECA = "icones/biblioteca/"
EXT_DA_BIBLIOTECA = (".svg", ".png")


PASTA_FEITOS_A_MAO = "icones/biblioteca/feitos-a-mao/"
PASTAS_DA_FICHA = ("icones/apps/", PASTA_BIBLIOTECA)
ROTULO_DA_PASTA = {"icones/apps": "feitos para apps", "icones/biblioteca": "biblioteca",
                   "arcticons": "traço", "feitos-a-mao": "feitos à mão",
                   "versoes": "versões", "projetos": "projetos dela"}
FORA_DA_FICHA = ("ANTES-E-DEPOIS.png",)
RE_NOME_NA_FICHA = re.compile(r"^[^#:\x00-\x1f]{1,200}$")


def pasta_de_enviados():
    return os.path.join(os.path.dirname(raiz_da_pessoa()), "icones-enviados")


def _arquivos_da_pasta(pasta, ext):
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


GERADORES_DE_ICONE = ("traco", "circle")


def gerador_de_icones(ref):
    for ident in cadeia_de_acervo(ref):
        valor = campo(ident, "icones.gerador")
        if valor in GERADORES_DE_ICONE:
            return valor
    return "traco"


def cadeia_de_acervo(ref):
    saida, vistos, atual = [], set(), ref
    do_projeto = os.path.join(RAIZ, "packs")
    while atual and atual not in vistos:
        vistos.add(atual)
        dir_pack = achar(atual)
        if not dir_pack:
            break
        saida.append(os.path.basename(dir_pack))
        if os.path.dirname(dir_pack) == do_projeto:
            break
        atual = campo(dir_pack, "heranca")
    return saida


def acervos_de_icone(no_ar="", cadeia=None):
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
            if cadeia is not None and pid not in cadeia:
                continue
            nome_pack = str(campo(dir_pack, "nome", pid) or pid)
            aut = campo(dir_pack, "icones.autorais.desenhos") \
                or padrao_do_formato(dir_pack, PASTA_AUTORAIS)
            formato = campo(dir_pack, "formato", 1)
            if isinstance(formato, int) and formato >= 2:
                _grupos_das_tres_pastas(grupo, pid, nome_pack, dir_pack, aut)
            else:
                _grupos_de_antes(grupo, pid, nome_pack, dir_pack)
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
                    continue
                grupo("pack:%s:autorais:%s" % (pid, flavor or "-"), nome_pack,
                      "autorais · %s" % flavor if flavor else "autorais", pid, "desenho",
                      pasta_aut, por_flavor[flavor])
    enviados = pasta_de_enviados()
    grupo("casa:enviados", "Seus", "enviados", "", "desenho", enviados,
          _arquivos_da_pasta(enviados, ".svg"))
    if cadeia is not None:
        return sorted(grupos, key=lambda g: (not g["no_ar"], not g["pack"],
                                             cadeia.index(g["pack"]) if g["pack"] in cadeia else 0))
    return sorted(grupos, key=lambda g: (not g["no_ar"], not g["pack"], g["pack"] == PACK_BASE))


def _grupos_de_antes(grupo, pid, nome_pack, dir_pack):
    pastas = []
    for cat, chave, nome in (("icones.apps.desenhos", "apps", "feitos para apps"),
                             (CATEGORIA_RESGATADOS + ".desenhos", "resgatados", "resgatados")):
        declarada = campo(dir_pack, cat)
        if isinstance(declarada, str) and declarada:
            try:
                pastas.append((chave, nome, _dentro(dir_pack, declarada, cat), "desenho", ".svg"))
            except Recusa:
                pass
    feitos = padrao_do_formato(dir_pack, PASTA_FEITOS_A_MAO)
    for chave, nome, rel, tipo, ext in (
            ("biblioteca", "biblioteca", PASTA_BIBLIOTECA, "desenho", ".svg"),
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
    traco = campo(dir_pack, "icones.apps.recolorir") is True
    try:
        real_aut = _dentro(dir_pack, aut, "icones.autorais.desenhos")
    except Recusa:
        real_aut = ""
    for rel_raiz in PASTAS_DA_FICHA:
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
                flavors = _flavors_do_pack(dir_pack)
                svgs = [a for a in svgs
                        if not any(os.path.basename(a)[:-4].endswith("-" + f) for f in flavors)]
            grupo(gid, nome_pack, nome, pid, tipo, dirpath, svgs)
            grupo(gid + ":png", nome_pack, nome + " (PNG)", pid, "png", dirpath,
                  _arquivos_da_pasta(dirpath, ".png"))


def _contar_biblioteca(ref, dir_pack):
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


ROTULO_DA_CATEGORIA = {
    "paleta": "paleta",
    "cosmic.mapa": "mapa do COSMIC",
    "icones.apps": "ícones de aplicativo",
    "icones.pastas": "pastas",
    "icones.mimetypes": "ícones de arquivo",
    "icones.autorais": "ícones autorais",
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


FIXAS_NO_MOTOR = {
    "gerador": "scripts/converter_icone.py",
    "prompt": "assets/prompt/",
    "fastfetch": "assets/fastfetch/",
}


NOTA_DA_CATEGORIA = {
    "icones.pastas": ("só as pastas especiais, com «Ícones das pastas especiais» ligado "
                      "(PASTAS_XDG); as outras são o papirus-folders, na paleta do pack"),
}


def _cadeia_declara(ref, cat):
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
    ic = p.get("icones") or {}
    org = p.get("origens") or {}
    saida = []
    dir_pack_info = achar(p["id"]) if p.get("id") else None
    for cat, bloco in [("paleta", p.get("paleta")), ("cosmic.mapa", (p.get("cosmic") or {}).get("mapa")),
                       ("icones.apps", ic.get("apps")), ("icones.pastas", ic.get("pastas")),
                       ("icones.mimetypes", ic.get("mimetypes")), ("icones.autorais", ic.get("autorais")),
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
        if cat == "som":
            declarou = isinstance(bloco, dict) and any(not str(k).startswith("_") for k in bloco)
            saida.append((cat, "próprio" if declarou else "motor", ""))
            continue
        if cat in ("wallpapers", "mascote"):
            desenhos = bloco.get("desenhos") if isinstance(bloco, dict) else None
            proprio = isinstance(desenhos, str) and dir_pack_info and \
                os.path.isdir(os.path.join(dir_pack_info, desenhos))
            saida.append((cat, "próprio" if proprio else "motor", ""))
            continue
        if (cat in ("cursores", CATEGORIA_FONTES, CATEGORIA_BASE) and isinstance(bloco, dict)
                and "proprio" not in bloco and "origem" not in bloco and not bloco.get("herda")):
            bloco = None
        if bloco is None:
            tipo, quem = ("herdado", p["heranca"]) if p.get("heranca") else ("motor", "")
            if tipo == "herdado" and cat in ("cosmic.mapa", CATEGORIA_FONTES) \
                    and not _cadeia_declara(p["heranca"], cat):
                tipo, quem = "motor", ""
        elif isinstance(bloco, dict) and bloco.get("herda"):
            tipo, quem = "herdado", bloco["herda"]
        else:
            tipo, quem = "próprio", ""
        saida.append((cat, tipo, quem))
    return saida


def resumo_de_origem(p):
    grupos = {}
    for cat, tipo, quem in origens(p):
        if tipo == "fixo":
            continue
        if tipo == "herdado" and quem == PACK_BASE and cat == "icones.mimetypes":
            tipo = "motor"
        chave = {"próprio": "próprio", "herdado": f"herdado de {quem}",
                 "motor": "do motor, ou ausente"}[tipo]
        grupos.setdefault(chave, []).append(ROTULO_DA_CATEGORIA[cat])
    return " · ".join(f"{k}: {', '.join(v)}" for k, v in grupos.items())


def cmd_info(ref):
    p, dados, dir_pack = validar(ref, silencioso=True)
    vit, problemas = vitrine(p, dir_pack)
    if vit["capa"]:
        try:
            _validar_logo(dir_pack, p)
        except Recusa as e:
            problemas.append(str(e))
    base = p.get("heranca") or "(nenhuma)"
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
    derivados = claros_derivados(dados)
    claros = [f"{c} — claro: derivado do escuro pelo método do Latte (não é próprio), "
              f"a partir de {derivados[c]!r}" if c in derivados else c
              for c in dados["claros"]]
    print(f"  claros    : {', '.join(claros) or '(nenhum)'}")
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
        conta = ""
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
            bib = _contar_biblioteca(ref, dir_pack) if cat == "icones.apps" else None
            if bib:
                conta = f"{bib[0]} apps, {bib[1]} na biblioteca sem app ligado"
        elif cat == "cursores":
            pt = ponteiro(ref)
            conta = (f"CURSOR=\"{pt['valor']}\", do pack {pt['pack']}" if pt
                     else "" if tipo == "motor" else "a cadeia não traz ponteiro")
            if pt and pt.get("url"):
                conta += f", baixado de {_url_curta(pt['url'])}"
        elif cat == CATEGORIA_FONTES:
            try:
                quem_f, lista = tipografia(ref)
                conta = (f"{len(lista)} fonte(s), do pack {quem_f}" if quem_f
                         else "" if tipo == "motor" else "a cadeia não traz fonte")
            except Recusa:
                conta = "a lista herdada não valida no pack base"
        elif cat == "wallpapers":
            conta = "scripts/wallpaper.sh — segue o pack do flavor, sem ler este bloco"
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


SOM_NO_CONF = {
    "fundamental": "SOM_FUNDAMENTAL",
    "harmonico": "SOM_HARMONICO",
    "peso_fundamental": "SOM_PESO_FUNDAMENTAL",
    "peso_harmonico": "SOM_PESO_HARMONICO",
    "decaimento": "SOM_DECAIMENTO",
    "duracao": "SOM_DURACAO",
    "ganho": "SOM_GANHO",
}


RE_FLAVOR_CONF = re.compile(r"^[a-z0-9_]+$")


def plano_de_uso(ref, flavor=None, flavor_atual=None):
    p, dados, dir_pack = validar(ref, silencioso=True)
    ident = p["id"]
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
    _exigir(RE_FLAVOR_CONF.match(escolhido),
            f"o flavor {escolhido!r} do pack {ident!r} não pode ir para o meow.conf:\n"
            f"    só minúsculas, dígitos e sublinhado — ele é sourceado pelo shell.")
    return ident, escolhido, porque


def _nomes_curtos(p, dados):
    nomes = dados.get("nomes") if isinstance(dados.get("nomes"), dict) else {}
    prefixo = f"{p.get('nome') or p['id']} "
    saida = {}
    for f in dados["flavors"]:
        n = str(nomes.get(f) or f)
        saida[f] = n[len(prefixo):] if n.startswith(prefixo) and len(n) > len(prefixo) else n
    return saida


def _mimetypes_de(ident, p, dados):
    base = acervo("icones.mimetypes.desenhos", ref=ident)
    if not base or not os.path.isdir(base):
        return None
    return {
        "base": base,
        "dono": ident,
        "p_dono": p,
        "dados_dono": dados,
        "existem": list(dados["flavors"]),
        "escolhido": None,
    }


def _cores_do_flavor(ref, flavor):
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
            continue
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
            "claros": [f for f in existem if f in (mt["dados_dono"].get("claros") or [])],
            "luz": {f: round(_luminancia(mt["dados_dono"]["flavors"][f]["base"]), 4)
                    for f in existem},
        }

    mapa = acervo("icones.apps.mapa", ref=ident)
    if mapa:
        dono = _pack_de(mapa)
        saida["apps"] = {"de": dono, "nome_de": nome_do_pack(dono), "herdado": dono != ident}
    return saida


def timbre(ref):
    p, _, _ = validar(ref, silencioso=True)
    som = p.get("som") or {}
    return {var: str(som[chave]) for chave, var in SOM_NO_CONF.items() if chave in som}


def cmd_som(ref):
    for var, valor in timbre(ref).items():
        print(f"{var}={valor}")
    return OK


def cmd_construir(ref, seco=False):
    import subprocess

    p, _, dir_pack = validar(ref, silencioso=True)
    ident = p.get("id", os.path.basename(dir_pack))

    gerar = ((p.get("icones") or {}).get("autorais") or {}).get("gerar")
    derivar = ((p.get("icones") or {}).get("mimetypes") or {}).get("derivar")
    if not gerar and not derivar:
        print(f"  --   {ident}: não declara nada derivado — nada a construir")
        return OK
    if derivar:
        print(f"  --   {ident}: icones.mimetypes.derivar não escreve mais no pack — a instalação pinta o molde")
    if not gerar:
        print(f"  ok   {ident}: construído")
        return OK

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
    ambiente.pop("MEOW_PALETA", None)

    print(f"  >>   {ident}: ícones autorais, da paleta do pack, em {saida}")
    r = subprocess.run([sys.executable, gerador, "--saida", saida], env=ambiente)
    if r.returncode != 0:
        raise Recusa(f"o gerador de ícones autorais saiu {r.returncode}")
    print(f"  ok   {ident}: construído")
    return OK


RE_VAR_CTP = re.compile(r"var\(--vscode-ctp-([a-z0-9]+)\)")


def derivar_mimetypes(ref, seco=False):
    import tempfile
    p, dados, dir_pack = validar(ref, silencioso=True)
    ident = p.get("id", os.path.basename(dir_pack))
    bloco = (p.get("icones") or {}).get("mimetypes") or {}
    der = bloco.get("derivar") or {}
    origem = acervo("icones.mimetypes.desenhos", der.get("pasta", ""), ref=der.get("de"))
    if not origem or not os.path.isdir(origem):
        raise Recusa(f"icones.mimetypes.derivar: o pack {der.get('de')!r} não tem "
                     f"{der.get('pasta')!r} no acervo de mimetype dele")
    dentro_origem = os.path.realpath(origem) + os.sep
    desenhos = sorted(f for f in os.listdir(origem) if f.endswith(".svg")
                      and not os.path.islink(os.path.join(origem, f))
                      and os.path.isfile(os.path.join(origem, f))
                      and os.path.realpath(os.path.join(origem, f)).startswith(dentro_origem))
    destino_base = _dentro(dir_pack, bloco["desenhos"], "icones.mimetypes.desenhos")
    escritos = removidos = 0
    for flavor, cores in dados["flavors"].items():
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


MEOWPACK = 1
MANIFESTO = "MANIFESTO"
TETO_MEOWPACK = 256 << 20
TETO_ARQUIVOS_MEOWPACK = 20000
EXT_IMAGEM = (".png", ".jpg", ".jpeg", ".webp")
ZSTD_MAGICO = b"\x28\xb5\x2f\xfd"
SEM_DEPENDENCIA = 3


class Falta(Exception):
    pass


def _zstd():
    import shutil
    exe = shutil.which("zstd")
    if not exe:
        raise Falta("sem o `zstd` não há .meowpack — ele é o compressor do formato,\n"
                    "    e nesta máquina não está no PATH. Ele vem no pacote `zstd`.")
    return exe


def _mb(n):
    if n < 1 << 20:
        return f"{max(1, round(n / 1024))} KB"
    return f"{n / (1 << 20):.1f} MB".replace(".", ",")


CABECA_PROIBIDA = 5


def _proibido(rel, cabeca):
    if rel.lower().endswith(".sh"):
        return "é script de shell"
    if cabeca.startswith(b"\xef\xbb\xbf"):
        cabeca = cabeca[3:]
    if cabeca.startswith(b"#!"):
        return "começa com #!, e isso é script, seja qual for o nome"
    return None


def _pack_existente(ident):
    for base in raizes():
        cand = os.path.join(base, ident)
        if os.path.lexists(cand):
            return cand
    return None


def _arquivos_do_pack(dir_pack):
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
    def tam(rel):
        return os.path.getsize(os.path.join(dir_pack, rel))
    imagens = [r for r in arquivos if r.lower().endswith(EXT_IMAGEM)]
    return {"arquivos": len(arquivos), "bytes": sum(map(tam, arquivos)),
            "imagens": len(imagens), "bytes_imagens": sum(map(tam, imagens))}


def medir_exportacao(ref):
    dir_pack = achar(ref)
    _exigir(dir_pack, f"não achei o pack {ref!r}")
    arquivos, _ocultos, _problemas = _arquivos_do_pack(dir_pack)
    return medida(dir_pack, arquivos)


def _licencas(dir_pack):
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
    nomes = {p.get("heranca")}
    for bloco in (list((p.get("icones") or {}).values()) + list((p.get("origens") or {}).values())
                  + list((p.get("apps") or {}).values())):
        if isinstance(bloco, dict):
            nomes.add(bloco.get("herda"))
    return sorted(h for h in nomes
                  if h and not os.path.isfile(os.path.join(RAIZ, "packs", str(h), "pack.json")))


def exportacao(ref):
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
    p = json.loads(texto)
    vit = p.get("vitrine")
    if isinstance(vit, dict) and isinstance(vit.get("capturas"), list):
        vit["capturas"] = [c for c in vit["capturas"]
                           if not str(c).lower().endswith(EXT_IMAGEM)]
    return (json.dumps(p, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def meowpack(exp, sem_imagens=False):
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


PASTAS_DO_FORMATO = ("apps", "sistema", "biblioteca")
PASTA_DE_ANTES_POR_NOME = {"autorais": "apps", "resgatados": "apps",
                           "feitos-a-mao": "biblioteca",
                           "pastas": "sistema", "mimetypes": "sistema"}
PASTA_DA_CATEGORIA = {"apps": "apps", "autorais": "apps", "resgatados": "apps",
                      "pastas": "sistema", "mimetypes": "sistema"}


def para_tres_pastas(ident, membros):
    try:
        p = json.loads(membros.get("pack.json", b"{}").decode("utf-8"))
    except (UnicodeDecodeError, ValueError):
        return membros
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

    for t in PASTAS_DO_FORMATO:
        troca.setdefault(t, t)

    def novo(caminho, prefixo="icones/"):
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
                    nome = "%s-%s%s" % (base, miolo[-2], ext)
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
    try:
        formato = json.loads(arquivos.get("pack.json", b"{}").decode("utf-8")).get("formato")
    except (UnicodeDecodeError, ValueError, AttributeError):
        return 0
    return formato if isinstance(formato, int) else 0


def _instalar_pack(arquivos, base, ident, seco=False):
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
        "derivados": claros_derivados(dados),
    }


def resumo_csv(caminho, nome_dado=""):
    arquivos, dados, reprovados = montar_novo(id_do_csv(caminho), caminho, nome_dado)
    r = o_que_traz(json.loads(arquivos["pack.json"]), dados, arquivos)
    r["regua"] = reprovados
    return r


def resumo_meowpack(caminho):
    _ident, membros = ler_meowpack(caminho)
    p = json.loads(membros["pack.json"])
    arq = os.path.normpath((p.get("paleta") or {}).get("arquivo", "paleta.json"))
    return o_que_traz(p, json.loads(membros[arq]), membros)


def _imprimir_o_que_traz(r):
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
        membros, paleta, reprovados = montar_novo(ident, caminho, os.environ.get("MEOW_PACK_NOME", ""))
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
    casa = os.path.expanduser("~")
    return "~" + caminho[len(casa):] if caminho.startswith(casa + os.sep) else caminho


def _quem_herda_de(ident):
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
            try:
                with open(os.path.join(base, nome, "pack.json"), encoding="utf-8") as fh:
                    p = json.load(fh)
            except (OSError, ValueError):
                continue
            if ident in set(herdas(p)):
                quem.add(nome)
    return sorted(quem)


def remocao(ident, pack_conf="", flavor_conf=""):
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
    seco, csv = False, None
    it = iter(opcoes)
    for op in it:
        if op in ("--seco", "--dry-run"):
            seco = True
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


def nome_digitado(texto):
    limpo = re.sub(r"[\x00-\x1f\x7f]", " ", str(texto or ""))
    return re.sub(r"\s+", " ", limpo).strip()[:60]


def montar_novo(ident, csv=None, nome_dado=""):
    import time
    nome = " ".join(parte.capitalize() for parte in ident.split("-"))
    if csv:
        try:
            do_arquivo = id_do_csv(csv) == ident
        except Recusa:
            do_arquivo = False
        solto = re.sub(r"[\s_-]+", " ", os.path.splitext(os.path.basename(csv))[0]).strip()
        if do_arquivo and solto:
            nome = solto[0].upper() + solto[1:]
    nome = nome_digitado(nome_dado) or nome
    data = time.strftime("%d/%m/%Y")
    som, reprovados = {}, []
    if csv:
        pf, _, _dir_fonte = validar(PACK_PADRAO, silencioso=True)
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
    import subprocess
    import tempfile
    with tempfile.TemporaryDirectory(prefix="meow-novo-") as tmp:
        dir_pack = os.path.join(tmp, ident)
        for rel, conteudo in arquivos.items():
            alvo = _dentro(dir_pack, rel, rel)
            os.makedirs(os.path.dirname(alvo), exist_ok=True)
            with open(alvo, "wb") as fh:
                fh.write(conteudo)
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


TETO_FOTO = 64 << 20
RE_NOME_LEVADO = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+-]{0,119}$")


def pack_da_pessoa(ident):
    _exigir(isinstance(ident, str) and RE_ID.match(ident),
            f"id {ident!r} — só minúsculas, dígitos e hífen")
    d = os.path.join(raiz_da_pessoa(), ident)
    _exigir(os.path.isfile(os.path.join(d, "pack.json")) and not os.path.islink(d),
            f"{ident!r} não é um pack seu: só os de {raiz_da_pessoa()} recebem o que o "
            f"Personalizar leva")
    return d


def _e_foto(dados):
    return (dados.startswith(bytes([0x89]) + b"PNG\r\n" + bytes([0x1A, 0x0A]))
            or dados.startswith(bytes([0xFF, 0xD8, 0xFF]))
            or (dados[:4] == b"RIFF" and dados[8:12] == b"WEBP"))


def _ler_de_quem_usa(caminho, extensoes, teto, confere, o_que):
    nome = os.path.basename(caminho)
    _exigir(os.path.isfile(caminho) and not os.path.islink(caminho),
            f"{nome}: não é um arquivo comum")
    _exigir(nome.lower().endswith(extensoes), f"{nome}: só {', '.join(extensoes)}")
    tamanho = os.path.getsize(caminho)
    _exigir(0 < tamanho <= teto, f"{nome}: vazio ou maior que {teto >> 20} MB")
    with open(caminho, "rb") as fh:
        dados = fh.read()
    _exigir(confere(dados), f"{nome}: o conteúdo não é {o_que}")
    return dados


def _nome_limpo(nome):
    return re.sub(r"-{2,}", "-", re.sub(r"[^A-Za-z0-9._+-]+", "-", nome)).strip("-.")


def _gravar_no_pack(dir_pack, rel, dados):
    alvo = _dentro(dir_pack, rel, rel)
    os.makedirs(os.path.dirname(alvo), exist_ok=True)
    alvo = _dentro(dir_pack, rel, rel)
    _exigir(not os.path.islink(alvo), f"{rel}: é link")
    tmp = alvo + ".meow-parcial"
    with open(tmp, "wb") as fh:
        fh.write(dados)
    os.chmod(tmp, 0o644)
    os.replace(tmp, alvo)


def _mudar_pack_json(dir_pack, muda):
    arq = os.path.join(dir_pack, "pack.json")
    with open(arq, "rb") as fh:
        antes = fh.read()
    p = json.loads(antes)
    if not muda(p):
        return
    with open(arq + ".meow-parcial", "w", encoding="utf-8") as fh:
        fh.write(json.dumps(p, indent=2, ensure_ascii=False) + "\n")
    os.replace(arq + ".meow-parcial", arq)
    try:
        validar(dir_pack, silencioso=True)
    except Recusa:
        with open(arq, "wb") as fh:
            fh.write(antes)
        raise


def nome_da_foto(ident, nome):
    raiz, ext = os.path.splitext(os.path.basename(nome))
    raiz, ext = _nome_limpo(raiz), ("." + _nome_limpo(ext[1:]) if ext else "")
    if not raiz.startswith(ident + "-"):
        raiz = ident + "-" + raiz.strip("-.")
    return raiz[:120 - len(ext)] + ext.lower()


def fotos_do_pack(dir_pack):
    pasta = os.path.join(dir_pack, "wallpapers")
    if os.path.islink(pasta) or not os.path.isdir(pasta):
        return []
    return sorted(e.name for e in os.scandir(pasta)
                  if e.is_file(follow_symlinks=False) and e.name.lower().endswith(EXT_FOTO))


def levar_foto(ident, caminho):
    dir_pack = pack_da_pessoa(ident)
    dados = _ler_de_quem_usa(caminho, EXT_FOTO, TETO_FOTO, _e_foto, "uma foto PNG, JPEG ou WebP")
    nome = nome_da_foto(ident, caminho)
    _exigir(RE_NOME_LEVADO.match(nome) and nome_de_destino(nome) and nome.lower().endswith(EXT_FOTO),
            f"{nome!r}: nome que não serve")
    _gravar_no_pack(dir_pack, "wallpapers/" + nome, dados)

    def declarar(p):
        org = p.setdefault("origens", {})
        if isinstance(org.get("wallpapers"), dict):
            return False
        org["wallpapers"] = {"prefixo": ident}
        return True
    _mudar_pack_json(dir_pack, declarar)
    return nome


def tirar_foto(ident, nome):
    dir_pack = pack_da_pessoa(ident)
    _exigir(isinstance(nome, str) and RE_NOME_LEVADO.match(nome) and nome_de_destino(nome),
            f"{nome!r}: nome de foto que não serve")
    alvo = os.path.join(dir_pack, "wallpapers", nome)
    _exigir(os.path.isfile(alvo) and not os.path.islink(alvo), f"{nome}: não está no pack")
    os.remove(alvo)
    if not fotos_do_pack(dir_pack):
        def esquecer(p):
            if (p.get("origens") or {}).get("wallpapers") != {"prefixo": ident}:
                return False
            del p["origens"]["wallpapers"]
            if not p["origens"]:
                del p["origens"]
            return True
        _mudar_pack_json(dir_pack, esquecer)


TETO_SOM = 4 << 20
EXT_SOM = (".oga", ".ogg")
CONTEXTOS_DE_SOM = ("action", "alert", "notification")
RE_EVENTO = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
PASTA_SONS = "sons/"


def _e_ogg(dados):
    return dados.startswith(b"OggS")


def sons_do_tema(pasta):
    saida = []
    if not pasta or os.path.islink(pasta.rstrip(os.sep)) or not os.path.isdir(pasta):
        return saida
    for contexto in CONTEXTOS_DE_SOM:
        dir_ctx = os.path.join(pasta, "stereo", contexto)
        if os.path.islink(dir_ctx) or not os.path.isdir(dir_ctx):
            continue
        for nome in sorted(os.listdir(dir_ctx)):
            cheio = os.path.join(dir_ctx, nome)
            evento = nome[:-len(".oga")]
            if (nome.endswith(".oga") and RE_EVENTO.match(evento)
                    and os.path.isfile(cheio) and not os.path.islink(cheio)):
                saida.append((contexto, evento, cheio))
    return saida


def sons_do_pack(dir_pack):
    tema = (campo(dir_pack, "som.tema") or "")
    if not isinstance(tema, str) or not tema:
        return []
    try:
        return sons_do_tema(_dentro(dir_pack, tema, "som.tema"))
    except Recusa:
        return []


def levar_sons_de(ident, ref):
    dir_pack = pack_da_pessoa(ident)
    if sons_do_pack(dir_pack):
        return 0
    origem = acervo("som.tema", ref=ref)
    sons = sons_do_tema(origem)
    if not sons:
        return 0
    origem = origem.rstrip(os.sep)
    for contexto, evento, cheio in sons:
        with open(cheio, "rb") as fh:
            dados = fh.read()
        if _e_ogg(dados) and 0 < len(dados) <= TETO_SOM:
            _gravar_no_pack(dir_pack, f"{PASTA_SONS}stereo/{contexto}/{evento}.oga", dados)
    nome = re.sub(r"[\x00-\x1f]", "", str(campo(dir_pack, "nome", ident) or ident))
    indice = [f"[Sound Theme]", f"Name={nome}", "Inherits=freedesktop",
              "Directories=" + " ".join(f"stereo/{c}" for c in CONTEXTOS_DE_SOM), ""]
    for c in CONTEXTOS_DE_SOM:
        indice += [f"[stereo/{c}]", f"Context={c.capitalize()}", "OutputProfile=stereo", ""]
    _gravar_no_pack(dir_pack, PASTA_SONS + "index.theme", "\n".join(indice).encode("utf-8"))
    for licenca in ("License.txt", "LICENSE"):
        cheio = os.path.join(origem, licenca)
        if os.path.isfile(cheio) and not os.path.islink(cheio) and os.path.getsize(cheio) < 1 << 20:
            with open(cheio, "rb") as fh:
                _gravar_no_pack(dir_pack, PASTA_SONS + licenca, fh.read())

    def declarar(p):
        p.setdefault("som", {})["tema"] = PASTA_SONS
        return True
    _mudar_pack_json(dir_pack, declarar)
    return len(sons)


def levar_som(ident, caminho, evento):
    dir_pack = pack_da_pessoa(ident)
    _exigir(isinstance(evento, str) and RE_EVENTO.match(evento), f"{evento!r}: evento que não serve")
    achado = next(((c, e) for c, e, _ in sons_do_pack(dir_pack) if e == evento), None)
    _exigir(achado, f"{evento}: o tema de sons do pack não tem esse evento")
    dados = _ler_de_quem_usa(caminho, EXT_SOM, TETO_SOM, _e_ogg, "um som Ogg")
    _gravar_no_pack(dir_pack, f"{PASTA_SONS}stereo/{achado[0]}/{evento}.oga", dados)
    return evento


TETO_SVG = 2 << 20
PASTAS_QUE_SE_LEVAM = ("sistema", "biblioteca")
RE_SVG_ATIVO = re.compile(rb"<script|javascript:|\son[a-z]+\s*=", re.I)


def _e_svg(dados):
    return b"<svg" in dados[:4096].lower() and not RE_SVG_ATIVO.search(dados)


ROTULO_DE_PASTA_FD = {
    "folder": "Pasta", "user-home": "Pasta pessoal", "user-desktop": "Área de trabalho",
    "folder-documents": "Documentos", "folder-download": "Downloads", "folder-music": "Música",
    "folder-pictures": "Imagens", "folder-videos": "Vídeos", "folder-publicshare": "Público",
    "folder-templates": "Modelos",
}


def _pintar_molde(texto, cores):
    if not cores:
        return None
    papeis = set(RE_VAR_CTP.findall(texto))
    if any(p not in cores for p in papeis):
        return None
    return RE_VAR_CTP.sub(lambda m: cores[m.group(1)].lower(), texto)


def pastas_do_pack(dir_pack, cores=None):
    decl, mapa = campo(dir_pack, "icones.pastas.desenhos"), campo(dir_pack, "icones.pastas.mapa")
    if not (isinstance(decl, str) and decl and isinstance(mapa, str) and mapa):
        return []
    try:
        pasta = _dentro(dir_pack, decl, "icones.pastas.desenhos")
        linhas = list(ler_mapa(_dentro(dir_pack, mapa, "icones.pastas.mapa")))
    except (Recusa, OSError, UnicodeDecodeError):
        return []
    if cores is None:
        cores = _cores_do_flavor(dir_pack, campo(dir_pack, "paleta.flavor_padrao", ""))
    saida = []
    for _num, nome, glifo in linhas:
        if not nome_de_destino(nome):
            continue
        for cand in (glifo, nome):
            cheio = os.path.join(pasta, cand + ".svg")
            if not (nome_de_destino(cand) and os.path.isfile(cheio) and not os.path.islink(cheio)):
                continue
            try:
                with open(cheio, encoding="utf-8") as fh:
                    bruto = fh.read(TETO_SVG)
            except (OSError, UnicodeDecodeError):
                break
            texto = None
            if RE_VAR_CTP.search(bruto):
                texto = _pintar_molde(bruto, cores)
                if texto is None:
                    break
            saida.append({"nome": nome, "caminho": cheio, "svg": texto,
                          "rotulo": ROTULO_DE_PASTA_FD.get(nome) or nome.replace("-", " ").capitalize()})
            break
    return saida


def icones_do_pack(dir_pack, pasta):
    return sorted(os.path.basename(a) for a in _arquivos_da_pasta(os.path.join(dir_pack, "icones", pasta), ".svg"))


def _rotulos_da_biblioteca(pasta):
    try:
        with open(os.path.join(pasta, "catalog.json"), encoding="utf-8") as fh:
            catalogo = json.load(fh)
    except (OSError, ValueError):
        return {}
    saida = {}
    for arq, ficha in (catalogo.items() if isinstance(catalogo, dict) else ()):
        desc = str(ficha.get("descricao") or "").strip() if isinstance(ficha, dict) else ""
        if desc:
            saida[str(arq)] = desc[:1].upper() + desc[1:]
    return saida


def _rotulo_do_nome(nome):
    limpo = re.sub(r"[-_.]+", " ", re.sub(r"^\d+[-_.]+", "", nome)).strip() or nome
    return limpo[:1].upper() + limpo[1:]


def _ler_svg(caminho):
    try:
        with open(caminho, encoding="utf-8") as fh:
            return fh.read(TETO_SVG)
    except (OSError, UnicodeDecodeError):
        return ""


def _com_a_tinta(texto, tinta):
    if not (tinta and texto and "currentColor" in texto):
        return None
    return texto.replace("currentColor", tinta.lower())


def acervo_para_levar(ident, pasta, base="", cores=None):
    _exigir(pasta in PASTAS_QUE_SE_LEVAM, f"{pasta!r}: só {', '.join(PASTAS_QUE_SE_LEVAM)}")
    meus = set(icones_do_pack(pack_da_pessoa(ident), pasta)) if ident else set()
    saida = []
    for pid in cadeia_de_acervo(ident or base or PACK_BASE):
        dir_pack = achar(pid)
        if pid == ident or not dir_pack:
            continue
        if pasta == "sistema":
            itens = [(d["nome"], d["caminho"], d["rotulo"], d["svg"], d["svg"]) for d in pastas_do_pack(dir_pack, cores)]
        else:
            try:
                bib = _dentro(dir_pack, PASTA_BIBLIOTECA, "biblioteca")
            except Recusa:
                continue
            rotulos = _rotulos_da_biblioteca(bib)
            tinta = (cores or _cores_do_flavor(dir_pack, campo(dir_pack, "paleta.flavor_padrao", "")) or {}).get("text")
            itens = [(os.path.basename(a)[:-4], a,
                      rotulos.get(os.path.basename(a)) or _rotulo_do_nome(os.path.basename(a)[:-4]), None,
                      _com_a_tinta(_ler_svg(a), tinta))
                     for a in _arquivos_da_pasta(bib, ".svg")]
        saida += [{"de": pid, "nome": nome, "rotulo": rotulo, "arq": arq, "svg": svg, "previa": previa,
                   "levado": nome + ".svg" in meus} for nome, arq, rotulo, svg, previa in itens]
    return saida


LARGURA_DO_TRACO = "1.25"
DOCK_DA_PREVIA = (
    ("files", ("com.system76.CosmicFiles", "cosmic-files"), "cosmic-files"),
    ("firefox", ("firefox", "org.mozilla.firefox"), ""),
    ("telegram", ("org.telegram.desktop", "telegram"), ""),
    ("discord", ("com.discordapp.Discord", "discord"), ""),
    ("spotify", ("com.spotify.Client", "spotify"), ""),
    ("terminal", ("com.system76.CosmicTerm", "cosmic-term"), "cosmic-term"),
)
PASTAS_DA_PREVIA = ("folder", "user-home", "folder-documents")
MAPAS_DE_TRACO = ("apps-arcticons.map", "apps-convertidos.map")


def _tracejar(texto, largura, tinta):
    if "stroke-width" in texto:
        texto = re.sub(r'stroke-width="[^"]*"', f'stroke-width="{largura}"', texto)
    else:
        texto = re.sub(r"<(circle|rect|line|polyline|polygon|path|ellipse) ",
                       lambda m: f'<{m.group(1)} stroke-width="{largura}" ', texto)
    return texto.replace("currentColor", tinta.lower())


def _linhas_de_traco(dir_pack):
    saida = {}
    for nome_mapa in MAPAS_DE_TRACO:
        caminho = os.path.join(dir_pack, "icones", nome_mapa)
        if not os.path.isfile(caminho):
            continue
        with open(caminho, encoding="utf-8") as fh:
            for linha in fh:
                if linha.lstrip().startswith("#"):
                    continue
                campos = [c.strip() for c in linha.rstrip("\n").split(":")]
                if len(campos) >= 3 and campos[0] and campos[1] and campos[2]:
                    saida.setdefault(campos[0], (nome_mapa, campos[1], campos[2]))
    return saida


def _mapa_declarado(dir_pack, pid):
    saida = {}
    for categoria in ("icones.apps.mapa", "icones.resgatados.mapa"):
        declarado = campo(pid, categoria)
        if not (isinstance(declarado, str) and declarado):
            continue
        try:
            caminho = _dentro(dir_pack, declarado, categoria)
            for _num, nome, alvo in ler_mapa(caminho):
                saida.setdefault(nome, alvo)
        except (Recusa, OSError, UnicodeDecodeError):
            continue
    return saida


def _desenho_do_app(dir_pack, pid, apelidos, autoral, flavor, cores):
    icones = os.path.join(dir_pack, "icones")
    declarado, traco = _mapa_declarado(dir_pack, pid), _linhas_de_traco(dir_pack)
    for nome in apelidos:
        if nome in declarado:
            try:
                arq = resolver_alvo(declarado[nome], icones)
            except Recusa:
                continue
            texto = _ler_svg(arq) if os.path.isfile(arq) and not os.path.islink(arq) else ""
            if _e_svg(texto.encode("utf-8")):
                return texto
        if nome in traco:
            mapa, glifo, cor = traco[nome]
            if cor not in cores or not nome_de_destino(nome):
                continue
            if mapa == "apps-convertidos.map":
                achados = [os.path.join(icones, "apps", nome + ".svg")]
            elif nome_de_destino(glifo):
                achados = [os.path.join(icones, "apps", glifo + ".svg"),
                           os.path.join(icones, "biblioteca", glifo + ".svg")]
            else:
                continue
            for arq in achados:
                texto = _ler_svg(arq) if os.path.isfile(arq) and not os.path.islink(arq) else ""
                if _e_svg(texto.encode("utf-8")):
                    return _tracejar(texto, LARGURA_DO_TRACO, cores[cor])
    candidatos = [f"{autoral}-{flavor}"] if autoral else []
    candidatos += [n for n in apelidos if nome_de_destino(n)]
    for miolo in candidatos:
        arq = os.path.join(icones, "apps", miolo + ".svg")
        texto = _ler_svg(arq) if os.path.isfile(arq) and not os.path.islink(arq) else ""
        if _e_svg(texto.encode("utf-8")) and "currentColor" not in texto:
            return texto
    return None


def previa_do_pack(ident, flavor, cores=None):
    cores = cores or _cores_do_flavor(ident, flavor) or {}
    dock, pasta = [], None
    cadeia = cadeia_de_acervo(ident)
    for slot, apelidos, autoral in DOCK_DA_PREVIA:
        for pid in cadeia:
            dir_pack = achar(pid)
            texto = _desenho_do_app(dir_pack, pid, apelidos, autoral, flavor, cores) if dir_pack else None
            if texto:
                dock.append({"app": slot, "svg": texto})
                break
    for pid in cadeia:
        dir_pack = achar(pid)
        if not dir_pack:
            continue
        itens = {d["nome"]: d for d in pastas_do_pack(dir_pack, cores)}
        escolhida = next((itens[n] for n in PASTAS_DA_PREVIA if n in itens), None)
        if escolhida:
            pasta = escolhida["svg"] if escolhida["svg"] is not None else _ler_svg(escolhida["caminho"])
            break
    return {"dock": dock, "pasta": pasta or None}


def levar_icone(ident, pasta, caminho, nome="", texto=None):
    dir_pack = pack_da_pessoa(ident)
    _exigir(pasta in PASTAS_QUE_SE_LEVAM, f"{pasta!r}: só {', '.join(PASTAS_QUE_SE_LEVAM)}")
    nome = (nome or os.path.basename(caminho)).removesuffix(".svg")
    _exigir(RE_NOME_LEVADO.match(nome + ".svg") and nome_de_destino(nome),
            f"{nome!r}: nome de ícone que não serve")
    if texto is not None:
        dados = texto.encode("utf-8")
        _exigir(0 < len(dados) <= TETO_SVG and _e_svg(dados), f"{nome}: o conteúdo não é um SVG sem script")
    else:
        dados = _ler_de_quem_usa(caminho, (".svg",), TETO_SVG, _e_svg, "um SVG sem script")
    _gravar_no_pack(dir_pack, f"icones/{pasta}/{nome}.svg", dados)
    return nome + ".svg"


RE_SVG_COM_ESTILO_VIVO = re.compile(rb"<script|javascript:|\son[a-z]+\s*=|<foreignObject|<image|<use|@import|url\(\s*['\"]?https?:", re.I)
TETO_DESENHO_DE_APP = 60000


def _desenho_de_app_valido(texto):
    dados = (texto or "").encode("utf-8")
    _exigir(0 < len(dados) <= TETO_DESENHO_DE_APP, "o desenho está vazio ou passa de 60 000 caracteres")
    _exigir(texto.lstrip().startswith("<svg") and texto.rstrip().endswith("</svg>"),
            "o texto tem de começar em <svg e terminar em </svg>")
    _exigir('viewBox="0 0 48 48"' in texto, 'falta viewBox="0 0 48 48"')
    _exigir(not RE_SVG_COM_ESTILO_VIVO.search(dados), "o desenho traz script, imagem ou endereço de fora")
    try:
        ET.fromstring(texto)
    except ET.ParseError as e:
        raise Recusa(f"o desenho não é XML: {e}") from None


def _linhas_do_mapa_herdado(heranca):
    mapa = acervo("icones.apps.mapa", ref=heranca) if heranca else None
    if not mapa:
        return []
    dono, saida = _pack_de(mapa), []
    for _num, nome, alvo in ler_mapa(mapa):
        if not (alvo.startswith(MOTOR) or alvo.startswith(OUTRO_PACK)):
            alvo = f"{OUTRO_PACK}{dono}:{alvo}"
        saida.append(f"{nome} : {alvo}")
    return saida


def _mapa_de_apps_do_pack(dir_pack, ident):
    declarado = campo(ident, "icones.apps.mapa")
    if isinstance(declarado, str) and declarado:
        return _dentro(dir_pack, declarado, "icones.apps.mapa"), False
    return _dentro(dir_pack, "icones/apps.map", "icones/apps.map"), True


def desenho_no_pack(ident, nome):
    dir_pack = pack_da_pessoa(ident)
    _exigir(nome_de_destino(nome), f"{nome!r}: nome de ícone que não serve")
    alvo = os.path.join(dir_pack, "icones", "apps", nome + ".svg")
    if not os.path.isfile(alvo) or os.path.islink(alvo):
        return None
    with open(alvo, encoding="utf-8") as fh:
        return fh.read(TETO_DESENHO_DE_APP + 1)


def usar_desenho(ident, nome, texto, rotulo=""):
    dir_pack = pack_da_pessoa(ident)
    _exigir(nome_de_destino(nome), f"{nome!r}: nome de ícone que não serve")
    _desenho_de_app_valido(texto)
    mapa, novo = _mapa_de_apps_do_pack(dir_pack, ident)
    if novo:
        linhas = _linhas_do_mapa_herdado(campo(ident, "heranca"))
        cabeca = ["# icones/apps.map — que desenho de icones/apps/ veste cada aplicativo.",
                  "# Formato: nome-de-icone-do-.desktop : arquivo (ou pack:<id>:arquivo, de um pack de que este herda)"]
    else:
        with open(mapa, encoding="utf-8") as fh:
            linhas = fh.read().split("\n")
        cabeca = []
    marca = re.sub(r"[\x00-\x1f#;]+", " ", rotulo or nome).strip()
    nova = f"{nome} : apps/{nome}.svg   # {marca} — escolhido no painel"
    achou = False
    for i, linha in enumerate(linhas):
        util = linha.split("#", 1)[0]
        if util.partition(":")[0].strip() == nome and ":" in util:
            linhas[i], achou = nova, True
            break
    if not achou:
        while linhas and not linhas[-1].strip():
            linhas.pop()
        linhas.append(nova)
    _gravar_no_pack(dir_pack, f"icones/apps/{nome}.svg", (texto.rstrip("\n") + "\n").encode("utf-8"))
    _gravar_no_pack(dir_pack, os.path.relpath(mapa, dir_pack), ("\n".join(cabeca + linhas) + "\n").encode("utf-8"))
    if novo:
        def declara(p):
            apps = p.setdefault("icones", {}).setdefault("apps", {})
            apps.setdefault("mapa", "icones/apps.map")
            apps.setdefault("desenhos", "icones/apps/")
            return True
        _mudar_pack_json(dir_pack, declara)
    return nome + ".svg"


def tirar_desenho(ident, nome):
    dir_pack = pack_da_pessoa(ident)
    _exigir(nome_de_destino(nome), f"{nome!r}: nome de ícone que não serve")
    mapa, novo = _mapa_de_apps_do_pack(dir_pack, ident)
    tirou = False
    alvo = os.path.join(dir_pack, "icones", "apps", nome + ".svg")
    if os.path.isfile(alvo) and not os.path.islink(alvo):
        os.remove(alvo)
        tirou = True
    if not novo and os.path.isfile(mapa):
        with open(mapa, encoding="utf-8") as fh:
            linhas = fh.read().split("\n")
        resto = [l for l in linhas
                 if not (l.split("#", 1)[0].partition(":")[0].strip() == nome
                         and f"apps/{nome}.svg" in l and "escolhido no painel" in l)]
        if resto != linhas:
            _gravar_no_pack(dir_pack, os.path.relpath(mapa, dir_pack), ("\n".join(resto).rstrip("\n") + "\n").encode("utf-8"))
            tirou = True
    return tirou


def tirar_icone(ident, pasta, nome):
    dir_pack = pack_da_pessoa(ident)
    _exigir(pasta in PASTAS_QUE_SE_LEVAM, f"{pasta!r}: só {', '.join(PASTAS_QUE_SE_LEVAM)}")
    nome = nome if nome.endswith(".svg") else nome + ".svg"
    _exigir(RE_NOME_LEVADO.match(nome) and nome_de_destino(nome), f"{nome!r}: nome que não serve")
    alvo = os.path.join(dir_pack, "icones", pasta, nome)
    _exigir(os.path.isfile(alvo) and not os.path.islink(alvo), f"{nome}: não está no pack")
    os.remove(alvo)


def cmd_levar(ident, tipo, args):
    if tipo in PASTAS_QUE_SE_LEVAM and len(args) in (1, 2):
        print(f"  ok   {levar_icone(ident, tipo, *args)}")
        return OK
    if tipo == "foto" and args:
        for caminho in args:
            print(f"  ok   {levar_foto(ident, caminho)}")
        return OK
    if tipo == "sons" and len(args) == 1:
        print(f"  ok   {levar_sons_de(ident, args[0])} som(ns) de {args[0]}")
        return OK
    if tipo == "som" and len(args) == 2:
        print(f"  ok   {levar_som(ident, args[0], args[1])}")
        return OK
    print("  erro uso: levar <id> foto <arquivo>... | sons <pack> | som <arquivo.oga> <evento>",
          file=sys.stderr)
    return ERRO_USO


def cmd_tirar(ident, tipo, args):
    if tipo in PASTAS_QUE_SE_LEVAM and args:
        for nome in args:
            tirar_icone(ident, tipo, nome)
            print(f"  ok   {nome} saiu")
        return OK
    if tipo == "foto" and args:
        for nome in args:
            tirar_foto(ident, nome)
            print(f"  ok   {nome} saiu")
        return OK
    print("  erro uso: tirar <id> foto <nome>...", file=sys.stderr)
    return ERRO_USO


def packs_dos_derivados(ref=None):
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
    saida = []
    for rel in ["icones"] + ["icones/" + p for p in PASTAS_DO_FORMATO]:
        try:
            saida.append(_dentro(d, rel, rel))
        except Recusa:
            continue
    return [p for p in saida if os.path.isdir(p)]


def fontes_dos_derivados(ref=None):
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
    achado = acervo("mascote.desenhos", ref=ref) if ref is None or ref else None
    if not achado:
        achado = acervo("mascote.desenhos", ref=PACK_BASE)
    return (achado or os.path.join(RAIZ, "packs", PACK_BASE, "mascote")).rstrip(os.sep)


def mascote_padrao(fase, ref=None):
    ref = ref or None
    return _na_cadeia("mascote." + fase, ref)[1] or ""


def origem_dos_wallpapers(ref=None):
    ref = ref or None
    dono, decl = _na_cadeia("origens.wallpapers", ref)
    if not isinstance(decl, dict):
        return {}
    dir_pack = achar(dono) or ""
    saida = {"pack": dono}
    for chave, valor in decl.items():
        if chave not in CHAVES_PAPEL or isinstance(valor, (dict, list)) and chave != "ignorar":
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
    fotos = os.path.join(dir_pack, "wallpapers") if dir_pack else ""
    try:
        if fotos and not os.path.islink(fotos) \
           and os.path.realpath(fotos) == os.path.join(os.path.realpath(dir_pack), "wallpapers") \
           and any(e.is_file(follow_symlinks=False) and e.name.lower().endswith(EXT_FOTO)
                   for e in os.scandir(fotos)):
            saida["fotos"] = fotos
    except OSError:
        pass
    return saida


EXT_FOTO = (".png", ".jpg", ".jpeg", ".webp")


def colecoes_alheias(ref=None):
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
        if verbo == "adocao" and len(argv) == 4:
            ident, dir_pack, recusado = adocao(argv[2], argv[3])
            print(f"pack={ident}")
            print(f"dir={dir_pack}")
            print(f"recusado={recusado}")
            print(f"nome={campo(ident, 'nome') or ident}")
            print(f"flavor_padrao={campo(ident, 'paleta.flavor_padrao') or ''}")
            return OK
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
        if verbo == "escolhas" and len(argv) == 2:
            return cmd_escolhas()
        if verbo == "fontes" and len(argv) in (2, 3):
            return cmd_fontes(argv[2] if len(argv) == 3 else None)
        if verbo == "fonte" and len(argv) in (3, 4):
            return cmd_fonte(argv[2], argv[3] if len(argv) == 4 else None)
        if verbo == "sincronizar" and len(argv) == 3:
            return cmd_sincronizar(argv[2])
        if verbo == "logo" and 3 <= len(argv) <= 5:
            sys.stdout.write(logo(argv[2], *argv[3:]))
            return OK
        if verbo == "logo-gerado" and 3 <= len(argv) <= 5:
            return cmd_logo_gerado(argv[2], *argv[3:])
        if verbo == "de-csv" and len(argv) == 3:
            return cmd_de_csv(argv[2])
        if verbo == "som" and len(argv) == 3:
            return cmd_som(argv[2])
        if verbo == "ponteiro" and len(argv) in (2, 3):
            pt = ponteiro((argv[2] if len(argv) == 3 else "") or None)
            if not pt:
                return RECUSADO
            print(f"pack={pt['pack']}")
            print(f"dir={pt['dir']}")
            print(f"valor={pt['valor']}")
            for chave in ("url", "sha256", "pasta"):
                if pt.get(chave):
                    print(f"{chave}={pt[chave]}")
            return OK
        if verbo == "tipografia" and len(argv) in (2, 3):
            quem, lista = tipografia((argv[2] if len(argv) == 3 else "") or None)
            for nome, origem, soma in lista:
                print(f"{quem}\t{nome}\t{origem}\t{soma or '-'}")
            return OK
        if verbo == "base-icones" and len(argv) in (2, 3):
            quem, tema, decl = base_que_vale((argv[2] if len(argv) == 3 else "") or None,
                                             os.environ.get("ICONES_BASE"))
            print(f"quem={quem}")
            print(f"tema={tema}")
            for chave in ("pack", "url", "sha256", "pasta"):
                print(f"{chave}={(decl or {}).get(chave, '')}")
            for c in (decl or {}).get("por_tras", []):
                print(f"atras={c['url']}\t{c['sha256']}\t{c['pasta']}")
            return OK
        if verbo == "tema-icones" and len(argv) in (2, 3, 4):
            nome, comentario = tema_de_icones((argv[2] if len(argv) >= 3 else "") or None,
                                              argv[3] if len(argv) == 4 else "")
            print(f"nome={nome}")
            print(f"comentario={comentario}")
            return OK
        if verbo == "ocultar" and len(argv) in (2, 3):
            for nome in ocultar_do_pack((argv[2] if len(argv) == 3 else "") or None):
                print(nome)
            return OK
        if verbo == "base-apelidos" and len(argv) == 2:
            tema, onde = base_dos_apelidos(os.environ.get("ICONES_BASE"))
            print(f"tema={tema}")
            print(f"dir={onde}")
            return OK
        if verbo == "info" and len(argv) == 3:
            return cmd_info(argv[2])
        if verbo == "usar" and len(argv) in (3, 4):
            ident, flavor, porque = plano_de_uso(
                argv[2], argv[3] if len(argv) == 4 else None,
                os.environ.get("FLAVOR") or None)
            print(f"PACK={ident}")
            print(f"FLAVOR={flavor}")
            print(f"PORQUE={porque}")
            return OK
        if verbo == "flavor-icones" and len(argv) in (2, 3):
            achado = flavor_de_icones((argv[2] if len(argv) == 3 else "") or None,
                                      os.environ.get("ICONES_FLAVOR"),
                                      os.environ.get("FLAVOR"))
            if not achado:
                return RECUSADO
            print(achado)
            return OK
        if verbo == "pintados" and len(argv) in (4, 5):
            temporario = len(argv) == 5 and argv[4] == "--temporario"
            print(pintar_mimetypes(argv[2] or None, argv[3], temporario=temporario))
            return OK
        if verbo == "construir" and len(argv) in (3, 4):
            return cmd_construir(argv[2], seco=(len(argv) == 4 and argv[3] in ("--seco", "--dry-run")))
        if verbo == "novo" and len(argv) >= 3:
            return cmd_novo(argv[2], argv[3:])
        if verbo == "acervo-para-levar" and len(argv) == 4:
            for i in acervo_para_levar(argv[2], argv[3]):
                print(f"{i['de']}\t{i['nome']}\t{i['arq']}\t{'sim' if i['levado'] else 'nao'}")
            return OK
        if verbo == "usar-desenho" and len(argv) == 5:
            with open(argv[4], encoding="utf-8") as fh:
                print(usar_desenho(argv[2], argv[3], fh.read()))
            return OK
        if verbo == "tirar-desenho" and len(argv) == 4:
            return OK if tirar_desenho(argv[2], argv[3]) else RECUSADO
        if verbo == "levar" and len(argv) >= 4:
            return cmd_levar(argv[2], argv[3], argv[4:])
        if verbo == "tirar" and len(argv) >= 4:
            return cmd_tirar(argv[2], argv[3], argv[4:])
        if verbo == "exportar" and len(argv) >= 3:
            return cmd_exportar(argv[2], argv[3:])
        if verbo == "importar" and len(argv) >= 3:
            return cmd_importar(argv[2], argv[3:])
        if verbo == "remover" and len(argv) >= 3:
            return cmd_remover(argv[2], argv[3:])
        if verbo == "caminho" and len(argv) == 4:
            return cmd_caminho(argv[2], argv[3])
        if verbo == "app" and len(argv) == 4:
            quem, valor = tema_de_app(argv[3], ref=argv[2] or None)
            if quem is None or valor is None:
                return RECUSADO
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

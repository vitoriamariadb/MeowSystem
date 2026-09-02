#!/usr/bin/env python3
# assets/temas-de-apps/spotify/xpui.py — a ferramenta que abre, lê e reescreve o xpui.spa.
#
# ┌─────────────────────────────────────────────────────────────────────────┐
# │ ESTE ARQUIVO SAIU DO CAMINHO NORMAL EM 10/08/2026.                      │
# │                                                                         │
# │ O Spotify passou a ser tematizado pelo SPICETIFY (ver o manifesto.sh ao │
# │ lado, item 0). O `manifesto.sh` NÃO chama mais nada daqui: quem escreve │
# │ no app é o `spicetify apply`, e o acento vem do `acento.py`.            │
# │                                                                         │
# │ O que continua valendo, e por isso o arquivo fica:                      │
# │   `xpui.py estado <arquivo.spa> --paleta ...`  é a PERÍCIA — é como se  │
# │   descobre se um `.spa` é o de fábrica (bloco_sha vazio,                │
# │   verdes_originais=150) ou se já passou pela mão de alguém. Foi ele que │
# │   provou, antes de instalar o spicetify, que o backup de 08/08 era      │
# │   mesmo intocado — sem isso o `spicetify backup` teria congelado o tema │
# │   do Meow como se fosse o original de fábrica, para sempre.             │
# │   Os verbos `aplicar` e `reverter` viraram saída de emergência, à mão.  │
# │                                                                         │
# │ CUIDADO AO USAR OS VERBOS DE ESCRITA HOJE: depois de `spicetify apply`  │
# │ não existe mais `Apps/xpui.spa` — existe o DIRETÓRIO `Apps/xpui/`.      │
# │ Ver a RECUPERACAO.md nesta pasta.                                       │
# └─────────────────────────────────────────────────────────────────────────┘
#
# POR QUE EXISTE UM .py NUM PROJETO DE BASH
#   O `xpui.spa` do Spotify é um ZIP com 538 entradas e 40 MB descompactados.
#   Em bash isso viraria `unzip` num diretório temporário, `sed` em 81 arquivos e
#   `zip` de volta — três chances de deixar lixo em /tmp e uma de reescrever o
#   arquivo pela metade. O `zipfile` da stdlib faz o mesmo com verificação de
#   integridade embutida, e o `python3` já é dependência dura de outros módulos
#   (o `zapzap` usa). O manifesto continua sendo o contrato; isto aqui é a mão.
#
# O QUE ELA FAZ — DUAS EDIÇÕES, AMBAS MECÂNICAS
#   1. ACRESCENTA um bloco Catppuccin no FIM de cada CSS que carrega a tabela de
#      design tokens do Encore (`.encore-dark-theme,.encore-dark-theme
#      .encore-base-set{...}`). São dois: `xpui-snapshot.css` (a janela
#      principal) e `pip-mini-player-snapshot.css` (o mini player). Como o bloco
#      é o último do arquivo e usa os MESMOS seletores, ele vence na cascata sem
#      precisar de `!important` — e isso é de propósito: o Spotify escreve
#      `--background-*` inline nas páginas de álbum para o degradê tirado da
#      capa, e um `!important` nosso mataria esse efeito.
#   2. TROCA o literal do verde do Spotify (`#1ed760` e o antigo `#1db954`) pelo
#      acento do flavor em TODOS os `.css` do pacote. Medido nesta máquina:
#      53 ocorrências no `xpui-snapshot.css` (32 dentro da tabela de tokens,
#      21 presas a classes de nome embaralhado como `.KzLH25pAEr43wpSc`) e mais
#      97 espalhadas por 29 outros CSS — a barra de reprodução tem 5, o mini
#      player tem 42. Mirar naquelas classes pelo nome seria escrever um módulo
#      com prazo de validade de uma atualização; trocar o LITERAL da cor não
#      depende de nome nenhum.
#      As formas com alpha (`#1ed76014`) continuam válidas depois da troca,
#      porque só os 6 primeiros dígitos mudam: `#cba6f714`.
#
# O QUE ELA NÃO FAZ, E POR QUÊ
#   - Não toca em `.js`. Há 49 verdes lá dentro, mas em JavaScript uma cor pode
#     estar numa comparação, num nome de classe gerado ou num canvas — trocar às
#     cegas é como se quebra um app calado.
#   - Não toca no `index.html`. A primeira versão injetava um `<link>` para um
#     CSS nosso; acrescentar no fim do CSS que já é carregado faz o mesmo com um
#     arquivo a menos e sem mexer no HTML.
#   - Não toca em `licenses.html` nem no binário `spotify`.
#
# COMO ELA SE DESFAZ, E POR QUE NÃO PRECISA DO ORIGINAL GUARDADO
#   O bloco começa numa sentinela (`/*! MeowSystem catppuccin-xpui-1 ... */`) e
#   vai até o fim do arquivo: remover é cortar dali para frente. A troca de cor
#   NÃO é encadeada, e a sentinela NÃO é a memória de quem trocar por quem: ela
#   só existe nos dois CSS que têm a tabela do Encore, e confiar nela deixava os
#   outros 29 presos no acento anterior (ver o comentário do `aplicar`). O que
#   vale é a lista fechada: os 56 acentos dos 4 flavors mais os dois verdes de
#   fábrica vão TODOS para o acento novo. Assim o módulo se reaplica com acento
#   novo — e cura um pacote já bicolor — sem precisar de uma cópia de 11 MB.
#   Isso é o subcomando `reverter`, que é este mesmo `aplicar` com o bloco
#   vazio. Ele NÃO é chamado por ninguém automaticamente — nem pelo doctor das
#   05:00. Desfazer é decisão dela, digitada.
#   O caminho de volta EXATO é outro e é barato: `flatpak update` ou reinstalar
#   o Spotify traz um `xpui.spa` novo em folha — e o backup em
#   `~/.local/state/meowsystem/backups/spotify-xpui-fabrica/` guarda o intocado
#   do commit instalado, que é o que o contrato do projeto exige.

import argparse
import hashlib
import json
import os
import re
import sys
import zipfile

RECEITA = "catppuccin-xpui-1"
SENTINELA = "/*! MeowSystem " + RECEITA
# Assinatura da tabela de tokens do Encore. Se um dia o Spotify renomear os
# seletores, nenhum arquivo casa, `documentos` sai vazio e a ferramenta diz isso
# em voz alta em vez de escrever um bloco que não pinta nada.
ASSINATURA = ".encore-dark-theme,.encore-dark-theme .encore-base-set{"
VERDES_ORIGINAIS = ("#1ed760", "#1db954")
# Os 14 acentos do Catppuccin. Toda cor que uma receita NOSSA pode ter deixado
# no CSS sai daqui — e nenhuma delas existe no xpui.spa de fábrica (medido em
# 10/08/2026 contra o backup intocado: 56 hexes nos 4 flavors, ZERO ocorrências
# no pacote de fábrica). Por isso dá para varrer TODAS elas de volta para o
# acento novo sem risco de pegar cor do Spotify.
ACENTOS = ("rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
           "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender")


def cores_de_receita(paleta_path):
    """Todo hex que uma receita nossa já pode ter escrito, em minúsculas."""
    with open(paleta_path, encoding="utf-8") as fh:
        flavors = json.load(fh)["flavors"]
    return {flavors[f][a].lower() for f in flavors for a in ACENTOS}


# --- cor ---------------------------------------------------------------------
def _rgb(c):
    h = c.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _hex(t):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v)))) for v in t)


def _mistura(a, b, t):
    ra, rb = _rgb(a), _rgb(b)
    return _hex(tuple(ra[i] + (rb[i] - ra[i]) * t for i in range(3)))


def _luminancia(c):
    def canal(v):
        v = v / 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = _rgb(c)
    return 0.2126 * canal(r) + 0.7152 * canal(g) + 0.0722 * canal(b)


# --- o bloco desejado --------------------------------------------------------
def bloco(paleta_path, flavor, acento):
    """Devolve o CSS Catppuccin, determinístico: mesma entrada, mesmos bytes."""
    with open(paleta_path, encoding="utf-8") as fh:
        cores = json.load(fh)["flavors"][flavor]

    c = cores.__getitem__
    A = c(acento)
    # Claro/escuro do acento saem de mistura com o texto e com o crust do MESMO
    # flavor — nunca de um hex digitado à mão, que é a regra do projeto.
    A_claro = _mistura(A, c("text"), 0.18)
    A_escuro = _mistura(A, c("crust"), 0.18)
    # No Mocha os acentos são pastéis claros e pedem texto escuro; no Latte são
    # saturados e escuros e pedem texto claro. Quem decide é a luminância, não o
    # nome do flavor.
    def sobre(cor):
        return c("crust") if _luminancia(cor) > 0.35 else c("base")

    def tinta(cor):
        """Painel discreto: a cor diluída na base, do jeito que o Encore usa os
        `*-subdued-set` (fundo quase neutro, texto na cor)."""
        return _mistura(c("base"), cor, 0.18)

    def conjunto(cor):
        """Um `*-set` sólido: fundo na cor, tudo o que é tinta por cima legível."""
        s = sobre(cor)
        d = ["--background-base:%s" % cor,
             "--background-highlight:%s" % _mistura(cor, c("text"), 0.18),
             "--background-press:%s" % _mistura(cor, c("crust"), 0.18),
             "--background-elevated-base:%s" % _mistura(cor, c("text"), 0.18),
             "--background-elevated-highlight:%s" % _mistura(cor, c("text"), 0.18),
             "--background-elevated-press:%s" % _mistura(cor, c("crust"), 0.18),
             "--background-tinted-base:%s" % cor,
             "--background-tinted-highlight:%s" % cor,
             "--background-tinted-press:%s" % cor]
        for k in ("base", "subdued", "bright-accent", "negative", "warning",
                  "positive", "announcement"):
            d.append("--text-%s:%s" % (k, s))
        for k in ("base", "subdued", "bright-accent", "negative", "warning",
                  "positive", "announcement"):
            d.append("--essential-%s:%s" % (k, s))
        d.append("--decorative-base:%s" % s)
        d.append("--decorative-subdued:%s" % _mistura(cor, c("crust"), 0.18))
        return d

    def conjunto_discreto(cor):
        fundo = tinta(cor)
        d = ["--background-base:%s" % fundo,
             "--background-highlight:%s" % _mistura(fundo, cor, 0.15),
             "--background-press:%s" % _mistura(fundo, cor, 0.30),
             "--background-elevated-base:%s" % _mistura(fundo, cor, 0.15),
             "--background-elevated-highlight:%s" % _mistura(fundo, cor, 0.15),
             "--background-elevated-press:%s" % _mistura(fundo, cor, 0.30),
             "--background-tinted-base:%s" % fundo,
             "--background-tinted-highlight:%s" % fundo,
             "--background-tinted-press:%s" % fundo]
        for k in ("base", "subdued", "bright-accent", "negative", "warning",
                  "positive", "announcement"):
            d.append("--text-%s:%s" % (k, cor))
        for k in ("base", "subdued", "bright-accent", "negative", "warning",
                  "positive", "announcement"):
            d.append("--essential-%s:%s" % (k, cor))
        d.append("--decorative-base:%s" % cor)
        d.append("--decorative-subdued:%s" % _mistura(fundo, cor, 0.30))
        return d

    # O corpo da janela. Os `--background-tinted-*` ficam de fora de propósito:
    # são véus em branco com alpha (`#ffffff1a`) que funcionam sobre qualquer
    # fundo, e trocá-los por cor sólida apagaria o relevo dos hovers.
    corpo = [
        "--background-base:%s" % c("base"),
        "--background-highlight:%s" % c("surface0"),
        "--background-press:%s" % c("surface1"),
        "--background-elevated-base:%s" % c("mantle"),
        "--background-elevated-highlight:%s" % c("surface0"),
        "--background-elevated-press:%s" % c("surface1"),
        "--text-base:%s" % c("text"),
        "--text-subdued:%s" % c("subtext0"),
        "--text-bright-accent:%s" % A,
        "--text-negative:%s" % c("red"),
        "--text-warning:%s" % c("yellow"),
        "--text-positive:%s" % c("green"),
        "--text-announcement:%s" % c("blue"),
        "--essential-base:%s" % c("text"),
        "--essential-subdued:%s" % c("overlay1"),
        "--essential-bright-accent:%s" % A,
        "--essential-negative:%s" % c("red"),
        "--essential-warning:%s" % c("yellow"),
        "--essential-positive:%s" % c("green"),
        "--essential-announcement:%s" % c("blue"),
        "--decorative-base:%s" % c("text"),
        "--decorative-subdued:%s" % c("surface0"),
    ]
    # A moldura (barra lateral, topo, rodapé do player). O Spotify usa #000 aqui
    # contra #121212 no corpo; `crust` contra `base` reproduz o mesmo degrau de
    # contraste sem sair da paleta.
    moldura = [
        "--background-base:%s" % c("crust"),
        "--background-highlight:%s" % c("mantle"),
        "--background-press:%s" % c("surface0"),
        "--background-elevated-base:%s" % c("mantle"),
        "--background-elevated-highlight:%s" % c("surface0"),
        "--background-elevated-press:%s" % c("crust"),
        "--text-base:%s" % c("text"),
        "--text-subdued:%s" % c("subtext0"),
        "--text-bright-accent:%s" % A,
        "--essential-base:%s" % c("text"),
        "--essential-subdued:%s" % c("overlay0"),
        "--essential-bright-accent:%s" % A,
        "--decorative-base:%s" % c("text"),
        "--decorative-subdued:%s" % c("surface0"),
    ]

    def par(nome):
        """Escreve o seletor para o tema escuro E para o claro. O `index.html`
        nasce com `class="encore-dark-theme"`, mas o Spotify 1.2.x já troca para
        `encore-light-theme` em algumas telas; cobrir os dois custa uma vírgula e
        evita uma tela branca no meio de um tema escuro."""
        if nome:
            return ".encore-dark-theme %s,.encore-light-theme %s" % (nome, nome)
        return (".encore-dark-theme,.encore-dark-theme .encore-base-set,"
                ".encore-light-theme,.encore-light-theme .encore-base-set")

    regras = [
        (par(""), corpo),
        (par(".encore-app-frame-set") + "," + par(".encore-muted-accent-set"), moldura),
        (par(".encore-bright-accent-set") + "," + par(".encore-positive-set"), conjunto(A)),
        (par(".encore-negative-set"), conjunto(c("red"))),
        (par(".encore-warning-set"), conjunto(c("peach"))),
        (par(".encore-announcement-set"), conjunto(c("blue"))),
        (par(".encore-positive-subdued-set"), conjunto_discreto(c("green"))),
        (par(".encore-negative-subdued-set"), conjunto_discreto(c("red"))),
        (par(".encore-warning-subdued-set"), conjunto_discreto(c("peach"))),
        (par(".encore-announcement-subdued-set"), conjunto_discreto(c("blue"))),
    ]

    saida = ["%s flavor=%s accent=%s verde=%s */" % (SENTINELA, flavor, acento, A)]
    for sel, decls in regras:
        saida.append("%s{%s}" % (sel, ";".join(decls)))
    return "\n".join(saida) + "\n"


# --- leitura pura ------------------------------------------------------------
def _sem_bloco(texto):
    i = texto.find(SENTINELA)
    return texto if i < 0 else texto[:i]


def _verde_vigente(texto):
    m = re.search(re.escape(SENTINELA) + r"[^*]*?verde=(#[0-9a-fA-F]{6})", texto)
    return m.group(1) if m else None


def _bloco_aplicado(texto):
    i = texto.find(SENTINELA)
    return None if i < 0 else texto[i:]


def estado(spa, cores_receita=()):
    """LEITURA PURA. Imprime chave=valor para o manifesto consumir."""
    with zipfile.ZipFile(spa) as z:
        nomes = [n for n in z.namelist() if n.endswith(".css")]
        documentos = []
        aplicados = []
        verdes = 0
        verde_atual = ""
        limpos = {}
        for n in nomes:
            t = z.read(n).decode("utf-8", "replace")
            if ASSINATURA in t:
                documentos.append(n)
                b = _bloco_aplicado(t)
                aplicados.append(hashlib.sha256(b.encode()).hexdigest() if b else "")
                if b and not verde_atual:
                    v = _verde_vigente(t)
                    verde_atual = v or ""
            limpo = _sem_bloco(t).lower()
            for verde in VERDES_ORIGINAIS:
                verdes += limpo.count(verde)
            limpos[n] = limpo
    # Um só sha para os dois documentos: se divergirem entre si, o valor não
    # bate com o desejado e o `conferir` manda reaplicar — que é o certo.
    unico = aplicados[0] if aplicados and len(set(aplicados)) == 1 else ""
    # SOBRAS DE UMA RECEITA ANTERIOR. Sem isto o `conferir` aprova um pacote
    # bicolor: o bloco bate byte a byte e `verdes_originais` é 0, mas metade da
    # interface continua no acento antigo (medido: 55 pontos em 27 arquivos).
    sobras = 0
    if cores_receita:
        atual = (verde_atual or "").lower()
        for velho in set(cores_receita) - {atual}:
            for limpo in limpos.values():
                sobras += limpo.count(velho)
    print("documentos=%d" % len(documentos))
    print("bloco_sha=%s" % unico)
    print("verde_atual=%s" % verde_atual)
    print("verdes_originais=%d" % verdes)
    print("sobras_receita=%d" % sobras)
    return 0


# --- escrita -----------------------------------------------------------------
def aplicar(spa, destino, texto_bloco, verde_novo, cores_receita):
    # DE ONDE, PARA ONDE — E POR QUE NÃO É "O VERDE VIGENTE DESTE ARQUIVO"
    #   A sentinela só é gravada nos DOIS CSS que têm a tabela do Encore, mas a
    #   troca de cor é feita nos 31. Ler o "anterior" arquivo a arquivo deixava
    #   os outros 29 presos no PRIMEIRO acento aplicado: medido em 10/08/2026,
    #   reaplicar `pink` sobre `mauve` deixava 55 ocorrências de #cba6f7 em 27
    #   arquivos (barra de reprodução, mini player, busca, configurações) — e o
    #   `conferir` aprovava a tela bicolor, porque o bloco batia byte a byte.
    #   A cura é não depender de memória nenhuma: varrer TODA cor que uma
    #   receita nossa pode ter escrito, mais os dois verdes de fábrica. Isso
    #   também CURA um pacote que já tenha ficado bicolor.
    de = sorted((set(VERDES_ORIGINAIS) | set(cores_receita))
                - {verde_novo.lower()})
    with zipfile.ZipFile(spa) as z:
        entradas = z.infolist()
        nomes = [zi.filename for zi in entradas]
        dados = {}
        documentos = 0
        for zi in entradas:
            bruto = z.read(zi.filename)
            if not zi.filename.endswith(".css"):
                dados[zi.filename] = bruto
                continue
            t = bruto.decode("utf-8", "replace")
            t = _sem_bloco(t)
            for velho in de:
                t = re.sub(re.escape(velho), verde_novo, t, flags=re.IGNORECASE)
            if ASSINATURA in t:
                documentos += 1
                # `texto_bloco` vazio = reversão (ver o subcomando `reverter`).
                # Sem este `if` a reversão deixava UM `\n` a mais no fim dos
                # dois CSS do Encore — medido: 459664 bytes contra 459663.
                if texto_bloco:
                    if not t.endswith("\n"):
                        t += "\n"
                    t += texto_bloco
            dados[zi.filename] = t.encode("utf-8")

    if documentos == 0:
        sys.stderr.write(
            "xpui.py: nenhum CSS com a tabela de tokens do Encore "
            "(assinatura '%s'). O Spotify mudou o desenho do tema; "
            "nao escrevi nada.\n" % ASSINATURA)
        return 3

    tmp = destino + ".parcial"
    with zipfile.ZipFile(tmp, "w") as saida:
        for zi in entradas:
            novo = zipfile.ZipInfo(zi.filename, date_time=zi.date_time)
            novo.compress_type = zi.compress_type
            novo.external_attr = zi.external_attr
            novo.internal_attr = zi.internal_attr
            novo.create_system = zi.create_system
            saida.writestr(novo, dados[zi.filename])

    # VERIFICAÇÃO ANTES DE ENTREGAR. Um zip meio escrito aqui é uma janela do
    # Spotify em branco — e ela só descobriria ao abrir o app.
    with zipfile.ZipFile(tmp) as z:
        if z.testzip() is not None:
            os.unlink(tmp)
            sys.stderr.write("xpui.py: o zip novo nao passou no teste de CRC\n")
            return 2
        if z.namelist() != nomes:
            os.unlink(tmp)
            sys.stderr.write("xpui.py: o zip novo perdeu ou trocou entradas\n")
            return 2
        for n in ("index.html", "xpui-snapshot.js"):
            if n in nomes and z.read(n) != dados[n]:
                os.unlink(tmp)
                sys.stderr.write("xpui.py: '%s' saiu diferente do esperado\n" % n)
                return 2
        # GUARDA DE SAÍDA. Se sobrou UMA cor de receita anterior, o pacote sai
        # bicolor e ninguém mais percebe. Recusar aqui devolve o Spotify
        # intacto — o `tmp` morre e o `os.replace` nunca acontece.
        sobras = 0
        for n in nomes:
            if n.endswith(".css"):
                # `_sem_bloco` é OBRIGATÓRIO aqui: o bloco novo TEM os outros
                # acentos do flavor (red, peach, blue, green) de propósito, e
                # contá-los acusava 160 sobras falsas — medido na primeira
                # versão desta guarda.
                baixo = _sem_bloco(
                    dados[n].decode("utf-8", "replace")).lower()
                for velho in de:
                    sobras += baixo.count(velho)
        if sobras:
            os.unlink(tmp)
            sys.stderr.write(
                "xpui.py: sobraram %d ocorrencias de acento anterior; "
                "nao entreguei o pacote\n" % sobras)
            return 2
    os.replace(tmp, destino)
    print("documentos=%d" % documentos)
    return 0


def main():
    p = argparse.ArgumentParser(add_help=True)
    sub = p.add_subparsers(dest="cmd", required=True)

    b = sub.add_parser("bloco")
    b.add_argument("--paleta", required=True)
    b.add_argument("--flavor", required=True)
    b.add_argument("--acento", required=True)

    e = sub.add_parser("estado")
    e.add_argument("spa")
    # Opcional de propósito: sem paleta o `estado` continua respondendo o que
    # sempre respondeu, só sem a conta de sobras.
    e.add_argument("--paleta", default=None)

    r = sub.add_parser("reverter")
    r.add_argument("spa")
    r.add_argument("destino")
    r.add_argument("--paleta", required=True)

    a = sub.add_parser("aplicar")
    a.add_argument("spa")
    a.add_argument("destino")
    a.add_argument("--paleta", required=True)
    a.add_argument("--flavor", required=True)
    a.add_argument("--acento", required=True)

    args = p.parse_args()
    try:
        if args.cmd == "bloco":
            sys.stdout.write(bloco(args.paleta, args.flavor, args.acento))
            return 0
        if args.cmd == "estado":
            return estado(args.spa,
                          cores_de_receita(args.paleta) if args.paleta else ())
        if args.cmd == "reverter":
            # A REVERSÃO É O `aplicar` COM O BLOCO VAZIO.
            #   Nada de caminho de escrita novo: o `aplicar` já tem o teste de
            #   CRC, a conferência da lista de entradas, o `index.html` e o
            #   `xpui-snapshot.js` byte a byte e o `os.replace` no fim. Reusar é
            #   o que mantém a parte perigosa com UM dono só.
            #   FIDELIDADE MEDIDA (10/08/2026): o pacote de fábrica tem 106
            #   `#1ed760` e 44 `#1db954`; a aplicação funde os dois no acento e a
            #   volta não sabe mais separá-los — os 44 voltam como `#1ed760`.
            #   Eles estão em estados de interação (checked, active, focus), não
            #   são raridade. Fora isso a volta é byte a byte igual à de fábrica,
            #   salvo um `\n` inerte no fim dos dois CSS do Encore.
            #   O caminho EXATO continua sendo `flatpak update`, ou o backup do
            #   MESMO commit.
            return aplicar(args.spa, args.destino, "", VERDES_ORIGINAIS[0],
                           cores_de_receita(args.paleta))
        texto = bloco(args.paleta, args.flavor, args.acento)
        with open(args.paleta, encoding="utf-8") as fh:
            verde = json.load(fh)["flavors"][args.flavor][args.acento]
        return aplicar(args.spa, args.destino, texto, verde,
                       cores_de_receita(args.paleta))
    except KeyError as erro:
        sys.stderr.write("xpui.py: chave ausente na paleta: %s\n" % erro)
        return 2
    except (OSError, zipfile.BadZipFile) as erro:
        sys.stderr.write("xpui.py: %s\n" % erro)
        return 2


if __name__ == "__main__":
    sys.exit(main())

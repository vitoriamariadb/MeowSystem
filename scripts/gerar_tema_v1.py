#!/usr/bin/env python3
"""Gera a árvore de tema `CosmicTheme.{Dark,Light}/v1` das capturas.

POR QUE ESTA ÁRVORE EXISTE E NINGUÉM A VESTIA
    O COSMIC tem DUAS árvores derivadas. O `cosmic-panel` e todo o stack nativo
    leem a `v2`; três applets flatpak desta máquina foram compilados contra uma
    libcosmic anterior e leem a `v1`. MEDIDO em 08/08/2026, sem reiniciar nada,
    pelas watches de inotify dos processos vivos:

        cosmic-panel                    -> Dark/v2, Light/v2   (inode 3935095, 4195309)
        cosmic-ext-applet-drives        -> Dark/v1, Mode/v1    (inode 3932173, 3932171)
        cosmic-ext-applet-clipboard-*   -> Dark/v1, Mode/v1    (idem)

    A `v1` desta máquina é o `cosmic-dark` de fábrica, congelado em 2026-04-12, e
    é por isso que os dois applets saem `#CACACA` no painel enquanto os nativos
    saem `#FFFFFF`: `Dark/v1/background.on` = 0.79136145 x 255 = 202 = 0xCA.
    (A nota antiga dizia `background.component.on`; o campo é `background.on`.
    O `component.on` da v1 é 0.8945329 -> 0xE4.)

    A GUI NÃO deriva mais a v1: nenhum dos 41 binários `/usr/bin/cosmic-*` contém
    a chave `is_frosted`, que só existe no esquema v1 — e o `theme_manager` do
    `cosmic-settings` só conhece as chaves da v2 (`alpha_map`, `transparent_*`).
    Ou seja: se o projeto não escrever a v1, ninguém escreve.

NÃO SE ESCREVE A V1 À MÃO — E TAMBÉM NÃO SE RECALCULA A DERIVAÇÃO
    O `docs/COSMIC-THEMING.md` §1 proíbe escrever chave por chave: as duas
    árvores discordam e reproduzir uma à mão gera um híbrido que *quase*
    funciona. Mas gerar a v1 a partir da paleta do pack ativo sozinha seria
    PIOR: a paleta e o `cosmic-map.json` só declaram os slots de TOPO do `.ron`
    (accent, bg_color, ...). Os 209 campos derivados da v1 (hover, pressed,
    component.*, on_disabled, divider...) saem de um algoritmo de contraste que
    vive dentro do COSMIC. Reimplementá-lo é exatamente o híbrido proibido.

    Então a fonte de cor é a `v2` DA PRÓPRIA CAPTURA — que é o produto que o
    COSMIC derivou do `.ron` que o `gerar_temas.py` gerou da paleta. A cor
    continua vindo da paleta do pack ativo; só o caminho é transitivo.

O QUE ESTE SCRIPT FAZ, LITERALMENTE
    Pega o texto do arquivo v1 do FÓSSIL (`assets/temas/capturados/original/.../v1/<chave>`,
    escrito pelo próprio COSMIC e versionado no git) e substitui, no lugar, os
    literais numéricos de R, G e B de cada campo de cor pelo valor do MESMO
    caminho no arquivo v2 da captura. Nada mais. A estrutura RON resultante é,
    por construção, byte a byte a de um arquivo que o COSMIC escreveu — não há
    como inventar chave, aninhamento ou formato.

O ALPHA NÃO ENTRA. É DELA.
    `frosted` e `alpha_map` são os dois slideres de Aparência (ver o bloco
    "OS DOIS SLIDERES DE VIDRO FOSCO SÃO DELA" em `aplicar_tema.sh`). Na v2 eles
    já estão multiplicados dentro de cada alpha (`background.base` = #313244B3).
    Copiar esse alpha para a v1 seria impor, pela porta dos fundos, o valor
    FOTOGRAFADO de um slider contínuo — o defeito exato que o projeto corrigiu
    em 05/08. Pior: a fonte é a captura, que é congelada, então o valor imposto
    seria sempre o velho.

    Por isso: **RGB da paleta, alpha do fóssil.** Consequência honesta e
    assumida: os popups desses dois applets ficam OPACOS enquanto os nativos
    ficam translúcidos. A v1 não tem `transparent_*`, então não há como o Ritual
    da Aurora conduzir o alpha ali — e é justamente por não ter `transparent_*`
    que o script de vidro-maximizado do Ritual NUNCA seleciona a v1 (a função
    `temas()` dele exige `glob("transparent_*")` no diretório). Zero ping-pong.
    (24/09/2026, P39: o nome do script saiu desta frase porque ela é docstring,
    e docstring é texto que o `git grep` da regra "nada do Ritual é chamado em
    execução" não sabe separar de código. O fato ficou.)

O CONJUNTO É MÍNIMO, E O CRITÉRIO ESTÁ AQUI
    Os applets declaram 26 campos (lidos do blob de desserialização do binário).
    Geramos só os que (a) carregam cor, (b) têm valor DIFERENTE na v2, e (c) um
    applet de painel pode desenhar. Ficam de fora, com motivo:
      shade, accent_text  — já idênticos entre v1 e v2 (nada a fazer)
      window_hint         — é a borda de janela, desenhada pelo cosmic-comp;
                            applet de painel não tem borda. E virar Some->None
                            seria mudança de ESTRUTURA, não de número.
      is_frosted          — território dela (ver acima); nenhum binário atual a
                            escreve, está congelada em `false`.
      active_hint         — espessura do realce de janela ativa: idem window_hint.
      corner_radii        — este era o achado deixado aqui para ela decidir: a v1
                            tinha os raios de fábrica (4/16/32/160) e a v2 os
                            achatados (2/8/8/8), o que apagava as PILULAS da
                            interface inteira. Em 10/08/2026 ela decidiu, e a v2
                            passou a ter os mesmos raios da v1 — a divergência
                            que motivava esta linha acabou. Continua fora deste
                            script pelo motivo estrutural de sempre: é forma,
                            não cor, e a fonte dela é o cosmic-map.json.
      spacing, is_dark, is_high_contrast — já idênticos.
      gaps                — eram idênticos ((0,5) nas duas) e deixaram de ser em
                            10/08/2026: a v2 foi para (12,6) e a v1 ficou. Não é
                            descuido. `gaps` é o espaçamento do mosaico de
                            janelas, desenhado pelo cosmic-comp, que lê a v2; a
                            v1 sobrevive só para três applets flatpak antigos,
                            que não desenham janela nenhuma. Mudar lá seria
                            escrever um número que ninguém lê.

A V1 DA `original` É O RESET DE FÁBRICA — E O MOLDE
    O script RECUSA escrever em `assets/temas/capturados/original/`. É de onde sai o molde, é
    o que o `meow desfazer` restaura, e é o backup versionado do tema de
    terceiro que estava aqui antes do projeto.
"""
from __future__ import annotations

import argparse
import os
import re
import struct
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "scripts"))
import pack  # noqa: E402  — depois do RAIZ de propósito, como no gerar_temas.py

# ONDE O MOLDE MORA, E ONDE AS CAPTURAS MORAM, SÃO DUAS PERGUNTAS — 22/09/2026
#   Eram a mesma: tudo vivia em `assets/temas/capturados/`. Desde a P14 cada
#   captura mora dentro do pack dono dela e só a `original` ficou aqui, porque
#   ela não é tema de pack nenhum — é o MOLDE do esquema v1 e o reset de fábrica
#   desta máquina. Esta constante passa a nomear só o molde; quem acha uma
#   captura é o `pack.captura()`, que sobe pack -> herança -> motor.
CAPTURAS = RAIZ / "assets" / "temas" / "capturados"
# `original` tem DOIS empregos, e só um deles é portátil:
#   (a) MOLDE do esquema v1 — o conjunto de chaves e a forma dos arquivos que o
#       COSMIC de 04/2026 escreveu. É isto que este script usa.
#   (b) reset de fábrica DESTA máquina — o `origem:` do captura.txt diz de qual.
#       NÃO é "o tema anterior de quem instalou": numa máquina de fora, aplicá-la
#       instala o tema de fábrica de outra pessoa. Ver `cmd_desfazer` em
#       bin/meow, que hoje prefere o backup `-tema-PRIMEIRO-` e só cai aqui
#       depois de conferir a procedência.
MOLDE = "original"
ARVORES = ("Dark", "Light")


# SEM ARGUMENTO, AS CAPTURAS SÃO AS QUE O PACK NO AR ALCANÇA — 24/09/2026, P51
#   Era `PADRAO = ["mocha-mauve", "mocha-pink", "latte-mauve"]`: as três
#   capturas do Catppuccin, escritas à mão. A `dracula-mauve` nunca entrou na
#   lista, e a v1 dela ficou sendo a do Catppuccin — medido pela P48 e pela P49,
#   e de novo antes deste conserto: `Dark/v1/accent` em #CBA6F7 numa captura
#   cuja v2 diz #BD93F9, e 18 arquivos da v1 divergindo da v2 dela
#   (`gerar_tema_v1.py --conferir dracula-mauve`). Acrescentar o nome que
#   faltou consertaria a captura de hoje e esqueceria a próxima — a que o
#   `derivar_acento.py` cria para um acento novo (P48), a de um pack de
#   terceiro. A lista é o estado: as capturas que o `pack.capturas()` alcança
#   do pack no ar (ele, o que ele herda, o motor), menos o molde, que não se
#   gera. É a mesma escada que o `aplicar_tema.sh` sobe para achar a captura
#   que vai aplicar, então toda captura que pode chegar à tela tem a v1 em dia.
def padrao():
    return [c for c in pack.capturas() if c != MOLDE]

# As chaves geradas. Ver a docstring para o critério e para o que ficou fora.
# `name` e `palette.name` entram porque um arquivo que diz `"cosmic-dark"` no
# meio de uma paleta Catppuccin mente para quem for ler a árvore depois.
CONJUNTO = [
    "accent", "accent_button", "background", "button", "control_tint",
    "destructive", "destructive_button", "icon_button", "link_button", "name",
    "palette", "primary", "secondary", "success", "success_button",
    "text_button", "text_tint", "warning", "warning_button",
]

# --- RON: um parser mínimo, o suficiente para estas árvores -------------------
TOKEN = re.compile(r"""
      (?P<ws>\s+|//[^\n]*)
    | (?P<open>\()
    | (?P<close>\))
    | (?P<comma>,)
    | (?P<colon>:)
    | (?P<str>"(?:[^"\\]|\\.)*")
    | (?P<ident>[A-Za-z_][A-Za-z_0-9]*)
    | (?P<num>-?[0-9]+(?:\.[0-9]+)?(?:[eE][-+]?[0-9]+)?)
""", re.X)


def lex(txt: str):
    i, out = 0, []
    while i < len(txt):
        m = TOKEN.match(txt, i)
        if not m:
            raise ValueError(f"RON inválido na posição {i}: {txt[i:i+24]!r}")
        i = m.end()
        if m.lastgroup != "ws":
            out.append((m.lastgroup, m.group(), m.start(), m.end()))
    return out


class Parser:
    """Produz nós ('tipo', carga). Todo literal carrega o span (início, fim) no
    texto original — é o que permite reescrever no lugar, sem reserializar."""

    def __init__(self, toks):
        self.t, self.i = toks, 0

    def _peek(self, k=0):
        return self.t[self.i + k] if self.i + k < len(self.t) else (None, None, -1, -1)

    def _take(self):
        v = self.t[self.i]
        self.i += 1
        return v

    def valor(self):
        k, s, a, b = self._peek()
        if k == "ident" and s == "Some" and self._peek(1)[0] == "open":
            self._take(); self._take()
            v = self.valor()
            assert self._take()[0] == "close"
            return ("Some", v)
        if k == "ident" and s == "None":
            self._take()
            return ("None", None)
        if k == "ident" and s in ("true", "false"):
            self._take()
            return ("lit", (s, a, b))
        if k == "ident" and self._peek(1)[0] == "open":      # Dark((...)), Light((...))
            nome = self._take()[1]; self._take()
            v = self.valor()
            assert self._take()[0] == "close"
            return ("nomeado", (nome, v))
        if k in ("ident", "str", "num"):
            self._take()
            return ("lit", (s, a, b))
        if k == "open":
            self._take()
            campos, itens = [], []
            while self._peek()[0] != "close":
                if self._peek()[0] == "comma":
                    self._take(); continue
                if self._peek()[0] in ("ident", "str") and self._peek(1)[0] == "colon":
                    ch = self._take()[1]; self._take()
                    campos.append((ch, self.valor()))
                else:
                    itens.append(self.valor())
            self._take()
            return ("struct", campos) if campos else ("tupla", itens)
        raise ValueError(f"valor RON inesperado: {k} {s!r}")


def parse(txt: str):
    return Parser(lex(txt)).valor()


def e_cor(no) -> bool:
    if no[0] != "struct":
        return False
    ch = [c for c, _ in no[1]]
    return ch[:3] == ["red", "green", "blue"] and set(ch) <= {"red", "green", "blue", "alpha"}


def f32(x: float) -> float:
    return struct.unpack("<f", struct.pack("<f", x))[0]


def texto_float(x: float) -> str:
    """A menor decimal que volta ao mesmo f32 — é como o Rust imprime, e é o que
    mantém o arquivo parecido com o que o COSMIC escreveu."""
    alvo = f32(x)
    for p in range(1, 10):
        s = f"{alvo:.{p}g}"
        if f32(float(s)) == alvo:
            break
    if "." not in s and "e" not in s and "E" not in s:
        s += ".0"       # RON: `red: 0` não é f32, tem de ser `0.0`
    return s


def cor_para_hex(no) -> str:
    d = dict(no[1])

    def c(k, padrao="FF"):
        if k not in d:
            return padrao
        return "%02X" % max(0, min(255, round(float(d[k][1][0]) * 255)))

    return "#" + c("red") + c("green") + c("blue") + c("alpha")


def achatar(no, pref=""):
    """caminho -> ('cor', hex, nó) | ('lit', texto, nó)"""
    out = {}
    if no[0] in ("Some", "nomeado"):
        return achatar(no[1] if no[0] == "Some" else no[1][1], pref)
    if no[0] == "struct":
        if e_cor(no):
            out[pref or "."] = ("cor", cor_para_hex(no), no)
            return out
        for ch, v in no[1]:
            out.update(achatar(v, f"{pref}.{ch}" if pref else ch))
        return out
    if no[0] == "lit":
        s = no[1][0]
        if re.fullmatch(r'"#[0-9A-Fa-f]{6,8}"', s):
            h = s.strip('"').upper()
            out[pref or "."] = ("cor", h + "FF" if len(h) == 7 else h, no)
        else:
            out[pref or "."] = ("lit", s, no)
        return out
    if no[0] == "None":
        out[pref or "."] = ("lit", "None", no)
        return out
    if no[0] == "tupla":
        out[pref or "."] = ("tupla", no, no)
        return out
    raise ValueError(no[0])


# --- a geração ---------------------------------------------------------------
def gerar_arquivo(texto_molde: str, texto_fonte: str) -> tuple[str, int]:
    """Substitui, no texto do molde v1, o RGB de cada cor pelo do mesmo caminho
    na v2. O alpha do molde NUNCA é tocado. Devolve (texto, campos_mexidos)."""
    molde = parse(texto_molde)
    fonte = achatar(parse(texto_fonte))
    plano = []          # (início, fim, texto novo)
    mexidos = 0

    for cam, (tipo, valor, no) in achatar(molde).items():
        alvo = fonte.get(cam)
        if alvo is None:
            continue                            # caminho que a v2 não tem: fica o fóssil
        if tipo == "cor" and alvo[0] == "cor":
            if valor[:7] == alvo[1][:7]:
                continue                        # RGB já certo
            canais = dict(no[1])
            for i, canal in enumerate(("red", "green", "blue")):
                _, ini, fim = canais[canal][1]
                oct_ = int(alvo[1][1 + 2 * i:3 + 2 * i], 16)
                plano.append((ini, fim, texto_float(oct_ / 255.0)))
            mexidos += 1
        elif tipo == "lit" and alvo[0] == "lit" and valor != alvo[1]:
            # só string por string (o `name` da paleta). Nunca troca o TIPO do
            # literal: um None que virasse Some mudaria a estrutura.
            if valor.startswith('"') and alvo[1].startswith('"'):
                _, ini, fim = no[1]
                plano.append((ini, fim, alvo[1]))
                mexidos += 1

    novo = texto_molde
    for ini, fim, txt in sorted(plano, reverse=True):
        novo = novo[:ini] + txt + novo[fim:]
    return novo, mexidos


def conferir_arquivo(texto_v1: str, texto_fonte: str) -> list[tuple[str, str, str]]:
    """Comparação CAMPO A CAMPO, nunca byte a byte: um lado é float e o outro é
    hex, e um `cmp` acusaria divergência eterna num arquivo perfeito.

    A tolerância é declarada e é a quantização de 8 bits: compara-se
    round(f * 255) contra o octeto da v2. Em espaço de float isso admite até
    1/255 = 0,39% por canal — abaixo do próprio passo de 8 bits do painel dela,
    e o mínimo possível, porque a fonte (Catppuccin) É 8 bits.

    Só o RGB é conferido. O alpha é dela (ver a docstring do módulo)."""
    v1 = achatar(parse(texto_v1))
    v2 = achatar(parse(texto_fonte))
    ruins = []
    for cam, (tipo, valor, _) in v1.items():
        alvo = v2.get(cam)
        if alvo is None or tipo != "cor" or alvo[0] != "cor":
            continue
        if valor[:7] != alvo[1][:7]:
            ruins.append((cam, valor[:7], alvo[1][:7]))
    return ruins


def carimbo() -> str:
    """O carimbo vem de lib/comum.sh, nunca de um `date` próprio: uma passagem
    do install.sh que cruze a virada do segundo racharia os backups em duas
    pastas (já aconteceu — ver o bloco 'UMA PASSAGEM, UMA PASTA' lá)."""
    c = os.environ.get("MEOW_CARIMBO")
    if c:
        return c
    saida = subprocess.run(
        ["bash", "-c", f'. "{RAIZ}/lib/comum.sh" >/dev/null 2>&1; printf %s "$MEOW_CARIMBO"'],
        capture_output=True, text=True, check=False).stdout.strip()
    if not saida:
        sys.exit("ERRO: não consegui obter MEOW_CARIMBO de lib/comum.sh.")
    return saida


class Backup:
    """A v1 vigente é de TERCEIRO (é o `cosmic-dark` de fábrica). Ela já está no
    git em quatro cópias byte a byte idênticas, e o `aplicar_tema.sh` guarda a
    árvore viva antes de escrever em ~/.config. Este backup cobre o terceiro
    caso: as capturas dentro dos packs que este script reescreve.

    Preguiçoso de propósito: só nasce se algo for mesmo escrito. Uma rodada
    conforme — a maioria — não cria pasta nenhuma."""

    def __init__(self, seco: bool):
        self.dir: Path | None = None
        self.seco = seco
        self.origens: list[str] = []

    def guardar(self, arq: Path):
        if self.seco:
            return
        if self.dir is None:
            estado = Path(os.environ.get(
                "MEOW_ESTADO", Path.home() / ".local/state/meowsystem"))
            self.dir = estado / "backups" / f"{carimbo()}-tema-v1"
            self.dir.mkdir(parents=True, exist_ok=True)
        # RELATIVO À RAIZ, E NÃO À PASTA DE CAPTURAS — 22/09/2026
        #   Com as capturas dentro dos packs, `relative_to(CAPTURAS)` levantaria
        #   ValueError em toda captura que não fosse a `original`, e o backup —
        #   que é a rede embaixo da escrita — morreria com traceback ANTES de
        #   escrever. Relativo à raiz o caminho continua único e agora diz de
        #   qual pack a cópia veio, que é o que `origens.txt` precisa dizer.
        #
        # E A RAIZ TAMBÉM NÃO É A ÚNICA CASA — CORREÇÃO DO MESMO DIA
        #   A frase acima só vale para o pack que mora em `RAIZ/packs/`, e essa
        #   é a TERCEIRA e última raiz do `pack.raizes()`. As outras duas —
        #   `$MEOW_PACKS` e `$XDG_DATA_HOME/meowsystem/packs` — ficam FORA da
        #   RAIZ e ainda VENCEM a de dentro. Com um pack de terceiro instalado
        #   ali, o `relative_to(RAIZ)` estourava o MESMO ValueError que a troca
        #   acima achou que tinha matado: ele só mudou de linha, e continuava
        #   matando a rede ANTES de a escrita acontecer. E era alcançável
        #   sozinho: basta esse pack trazer um dos nomes do `PADRAO`
        #   (mocha-mauve, mocha-pink, latte-mauve) para o `install.sh` e o
        #   `doctor --consertar` das 5h morrerem com traceback.
        #   MEDIDO em 22/09/2026, com um pack em `$MEOW_PACKS/dracula`:
        #     ValueError: '.../packs/dracula/temas/capturados/dracula-mauve/
        #     com.system76.CosmicTheme.Dark/v1/accent' is not in the subpath of
        #     '.../MeowSystem'
        #   Quem vem de fora entra sob `fora-da-raiz/<o absoluto sem a barra>`:
        #   caminho absoluto é único, então o backup continua sem colidir, e
        #   continua dizendo de qual pack a cópia veio. O prefixo só colidiria
        #   com um diretório `fora-da-raiz/` na raiz do projeto — que não
        #   existe, e cujo nome ninguém escolheria sem querer.
        absoluto = arq.resolve()
        try:
            rel = absoluto.relative_to(RAIZ)
        except ValueError:
            rel = Path("fora-da-raiz") / absoluto.relative_to(absoluto.anchor)
        dest = self.dir / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        if arq.is_file() and not dest.exists():
            dest.write_bytes(arq.read_bytes())
            self.origens.append(f"{rel}  <-  {arq}")

    def fechar(self):
        if self.dir is None:
            return
        (self.dir / "origens.txt").write_text(
            "Cópia do que havia em <captura>/**/v1 antes de o gerar_tema_v1.py\n"
            "escrever. A v1 é o tema de fábrica do COSMIC (`cosmic-dark`),\n"
            "anterior a este projeto. Os caminhos abaixo são relativos à raiz do\n"
            "MeowSystem, e desde 22/09/2026 cada captura mora dentro do pack dela.\n"
            "O que veio de um pack instalado FORA da raiz (em $MEOW_PACKS ou em\n"
            "$XDG_DATA_HOME/meowsystem/packs) entra sob `fora-da-raiz/`.\n\n"
            "Para voltar:  cp -a <arquivo> <o caminho à direita da seta, na lista abaixo>\n"
            "Conferir:     cd " + str(self.dir) + " && sha256sum -c manifesto.sha256\n\n"
            + "\n".join(self.origens) + "\n")
        subprocess.run(
            ["bash", "-c",
             'cd "$1" && find . -type f ! -name manifesto.sha256 -print0 '
             '| sort -z | xargs -0 sha256sum > manifesto.sha256',
             "_", str(self.dir)], check=False)
        print(f"  backup em {self.dir} (veja origens.txt)")


def refazer_manifesto(captura: Path):
    """O manifesto da captura descreve o que está NA captura. Reescrever a v1 sem
    refazê-lo deixaria a captura mentindo sobre si mesma. Mesmo comando do
    capturar_tema.sh, para a saída sair byte a byte igual."""
    subprocess.run(
        ["bash", "-c",
         'cd "$1" && find . -type f ! -name manifesto.sha256 -print0 '
         '| sort -z | xargs -0 sha256sum > manifesto.sha256',
         "_", str(captura)], check=False)


def main() -> int:
    p = argparse.ArgumentParser(
        description="Gera a árvore CosmicTheme.{Dark,Light}/v1 das capturas, "
                    "a partir da v2 da própria captura e do fóssil de 'original'.")
    p.add_argument("capturas", nargs="*", metavar="captura",
                   help="quais capturas gerar. Sem argumento: as que o pack no ar "
                        f"alcança, menos '{MOLDE}'")
    p.add_argument("--conferir", action="store_true",
                   help="não escreve: sai 1 se algum campo divergir (campo a campo, "
                        "com tolerância de 8 bits)")
    args = p.parse_args()

    seco = os.environ.get("MEOW_DRY_RUN", "0") == "1"
    conferir = args.conferir or seco
    alvos = args.capturas or padrao()

    if MOLDE in alvos:
        sys.exit(f"ERRO: '{MOLDE}' é o molde e o reset de fábrica — não se gera nela.")

    # O ACENTO DO meow.conf GANHA CAPTURA AQUI — 24/09/2026, sprint P48
    #   Sem argumento este script é a etapa `gerar` do instalador (e o conserto
    #   do `chk_gerar`), que roda ANTES da etapa `tema`. É o lugar em que a
    #   captura do acento escolhido tem de passar a existir: a etapa `tema` a
    #   procura pelo `meow_captura`, e sem ela mandava importar o `.ron` na GUI e
    #   rodar `meow tema capturar` — o passo manual do achado 31. Quem deriva é
    #   o irmão `derivar_acento.py`; aqui só se pergunta a ele, e o `--conferir`
    #   sai 1 quando há o que derivar, que é o que faz o instalador rodar esta
    #   geração. Um par que não se deriva sai 3 lá e é só informação aqui:
    #   quem avisa é a etapa `tema`. É o par que não tem base nenhuma: nem foto
    #   do mesmo flavor, nem de outro flavor do mesmo lado que se reproduza —
    #   desde a P59 o flavor sem foto sai de outro, pelo `derivar_flavor.py`.
    #   (25/09/2026, P63: dizia «flavor sem captura nenhuma», e esse flavor
    #   passou a se derivar.)
    #   Antes da checagem do esquema v1, de propósito: a derivação copia a v1 da
    #   própria base, não gera nada por cima do molde de 04/2026.
    rc_acento = 0
    if not args.capturas:
        import derivar_acento
        par = derivar_acento.par_ativo()
        if par:
            rc_acento, frase = derivar_acento.derivar(par, conferir)
            print(f"  {frase}")

    # O MOLDE É DE UM COSMIC DE 04/2026, E ISSO NÃO É UMA GARANTIA
    #   Se o COSMIC desta máquina escreve outro conjunto de chaves na Dark/v1,
    #   gerar por cima produz o tema híbrido que docs/COSMIC-THEMING.md §4 manda
    #   evitar — o "quase funciona" que só aparece semanas depois, num applet.
    #   Sair 3 (= MEOW_SEM_DEPENDENCIA) faz a etapa virar "pulado", que o
    #   `concluir()` do install.sh já sabe tratar; sair 2 diria que ALGO
    #   quebrou, e não quebrou: esta máquina é que é outra.
    vivo = Path.home() / ".config" / "cosmic" / "com.system76.CosmicTheme.Dark" / "v1"
    if vivo.is_dir():
        molde_v1 = CAPTURAS / MOLDE / "com.system76.CosmicTheme.Dark" / "v1"
        molde_keys = {p.name for p in molde_v1.glob("*") if p.is_file()}
        vivas = {p.name for p in vivo.glob("*") if p.is_file()}
        faltando = molde_keys - vivas
        if faltando:
            print(f"  !!      o COSMIC daqui não tem {len(faltando)} chave(s) do molde v1: "
                  f"{' '.join(sorted(faltando)[:6])}{' ...' if len(faltando) > 6 else ''}")
            print("          o molde é de um COSMIC de 04/2026 (docs/COSMIC-THEMING.md §4).")
            print("          não vou gerar por cima de um esquema que não reconheço.")
            sys.exit(3)

    bkp = Backup(seco or conferir)
    divergentes = escritos = iguais = pulados = 0

    for nome in alvos:
        achado = pack.captura(nome)
        captura = Path(achado) if achado else CAPTURAS / nome
        if not captura.is_dir():
            sys.exit(f"ERRO: captura '{nome}' não existe no pack ativo, "
                     f"no que ele herda, nem em assets/temas/capturados/.")
        mexeu_captura = False
        for arv in ARVORES:
            molde_d = CAPTURAS / MOLDE / f"com.system76.CosmicTheme.{arv}" / "v1"
            fonte_d = captura / f"com.system76.CosmicTheme.{arv}" / "v2"
            dest_d = captura / f"com.system76.CosmicTheme.{arv}" / "v1"
            if not molde_d.is_dir():
                sys.exit(f"ERRO: molde ausente: {molde_d}")
            if not fonte_d.is_dir():
                print(f"  --      {nome}/{arv}: sem v2 na captura, nada a derivar")
                continue
            for chave in CONJUNTO:
                molde_f, fonte_f, dest_f = molde_d / chave, fonte_d / chave, dest_d / chave
                if not molde_f.is_file() or not fonte_f.is_file():
                    pulados += 1     # a Light/v1 tem 18 chaves, não as 30 da Dark
                    continue
                novo, mexidos = gerar_arquivo(molde_f.read_text(), fonte_f.read_text())
                atual = dest_f.read_text() if dest_f.is_file() else None

                if conferir:
                    base = atual if atual is not None else molde_f.read_text()
                    ruins = conferir_arquivo(base, fonte_f.read_text())
                    if ruins:
                        divergentes += 1
                        print(f"  divergente  {nome}/{arv}/v1/{chave}: "
                              f"{len(ruins)} campo(s), ex.: {ruins[0][0]} "
                              f"{ruins[0][1]} != {ruins[0][2]}")
                    else:
                        iguais += 1
                    continue

                if atual == novo:
                    iguais += 1
                    continue
                bkp.guardar(dest_f)
                dest_f.parent.mkdir(parents=True, exist_ok=True)
                tmp = dest_f.with_name(f".{chave}.meow.tmp")
                tmp.write_text(novo)
                tmp.replace(dest_f)
                escritos += 1
                mexeu_captura = True
                print(f"  gerado  {nome}/{arv}/v1/{chave}  ({mexidos} campos)")

            # --- A CAPTURA TEM DE FICAR COMPLETA, E ISSO NÃO É ZELO -----------
            # O `aplicar_tema.sh` REMOVE do disco o que a captura não tem (ver o
            # bloco "os arquivos que SOBRAM" lá). Desde que a v1 saiu da cessão
            # de `e_produto`, uma captura com v1 incompleta passaria a APAGAR as
            # chaves vivas que faltassem nela — `is_frosted`, `shade`, `spacing`,
            # `corner_radii`... As quatro capturas desta máquina estão completas
            # (30 na Dark, 18 na Light), então hoje isto não faz nada; existe para
            # que uma captura mutilada, ou uma máquina recém-formatada, não vire
            # perda de chave. Só cria o que FALTA: nunca sobrescreve o que a
            # captura fotografou.
            if not conferir:
                for molde_f in sorted(molde_d.iterdir()):
                    if not molde_f.is_file() or molde_f.name in CONJUNTO:
                        continue
                    dest_f = dest_d / molde_f.name
                    if dest_f.exists():
                        continue
                    dest_d.mkdir(parents=True, exist_ok=True)
                    dest_f.write_text(molde_f.read_text())
                    mexeu_captura = True
                    print(f"  do fóssil  {nome}/{arv}/v1/{molde_f.name}  "
                          f"(estrutura, não gerada)")
        if mexeu_captura:
            refazer_manifesto(captura)

    bkp.fechar()

    if conferir:
        if divergentes:
            print(f"\n{divergentes} arquivo(s) de v1 com campo divergente "
                  f"({iguais} conferem). Rode sem --conferir para gerar.")
            return 1
        if rc_acento == 1:
            return 1
        print(f"v1 das capturas já derivada da paleta ({iguais} arquivos conferem"
              f"{f', {pulados} sem par no fóssil' if pulados else ''})")
        return 0

    print(f"v1 gerada: {escritos} escritos, {iguais} já estavam certos"
          f"{f', {pulados} sem par no fóssil' if pulados else ''}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
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
import pack  # noqa: E402

CAPTURAS = RAIZ / "assets" / "temas" / "capturados"
MOLDE = "original"
ARVORES = ("Dark", "Light")


def padrao():
    return [c for c in pack.capturas() if c != MOLDE]

CONJUNTO = [
    "accent", "accent_button", "background", "button", "control_tint",
    "destructive", "destructive_button", "icon_button", "link_button", "name",
    "palette", "primary", "secondary", "success", "success_button",
    "text_button", "text_tint", "warning", "warning_button",
]

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
        if k == "ident" and self._peek(1)[0] == "open":
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
    alvo = f32(x)
    for p in range(1, 10):
        s = f"{alvo:.{p}g}"
        if f32(float(s)) == alvo:
            break
    if "." not in s and "e" not in s and "E" not in s:
        s += ".0"
    return s


def cor_para_hex(no) -> str:
    d = dict(no[1])

    def c(k, padrao="FF"):
        if k not in d:
            return padrao
        return "%02X" % max(0, min(255, round(float(d[k][1][0]) * 255)))

    return "#" + c("red") + c("green") + c("blue") + c("alpha")


def achatar(no, pref=""):
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


def gerar_arquivo(texto_molde: str, texto_fonte: str) -> tuple[str, int]:
    molde = parse(texto_molde)
    fonte = achatar(parse(texto_fonte))
    plano = []
    mexidos = 0

    for cam, (tipo, valor, no) in achatar(molde).items():
        alvo = fonte.get(cam)
        if alvo is None:
            continue
        if tipo == "cor" and alvo[0] == "cor":
            if valor[:7] == alvo[1][:7]:
                continue
            canais = dict(no[1])
            for i, canal in enumerate(("red", "green", "blue")):
                _, ini, fim = canais[canal][1]
                oct_ = int(alvo[1][1 + 2 * i:3 + 2 * i], 16)
                plano.append((ini, fim, texto_float(oct_ / 255.0)))
            mexidos += 1
        elif tipo == "lit" and alvo[0] == "lit" and valor != alvo[1]:
            if valor.startswith('"') and alvo[1].startswith('"'):
                _, ini, fim = no[1]
                plano.append((ini, fim, alvo[1]))
                mexidos += 1

    novo = texto_molde
    for ini, fim, txt in sorted(plano, reverse=True):
        novo = novo[:ini] + txt + novo[fim:]
    return novo, mexidos


def conferir_arquivo(texto_v1: str, texto_fonte: str) -> list[tuple[str, str, str]]:
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

    rc_acento = 0
    if not args.capturas:
        import derivar_acento
        par = derivar_acento.par_ativo()
        if par:
            rc_acento, frase = derivar_acento.derivar(par, conferir)
            print(f"  {frase}")

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
                    pulados += 1
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
                  f"({iguais} conferem); a próxima passada que aplica os gera.")
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

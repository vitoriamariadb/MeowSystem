#!/usr/bin/env python3
# appid_sonda.py — o instrumento de leitura do `appid_dock.sh`. NÃO ESCREVE NADA.
#
# POR QUE ELE É PYTHON PURO, SEM UMA ÚNICA DEPENDÊNCIA
#   Ele precisa de duas coisas que o bash não alcança e que nenhuma ferramenta
#   instalada nesta máquina entrega:
#
#   1. O `app_id` das janelas ABERTAS. Medido em 27/08/2026: o `wlrctl` NÃO
#      serve — o `cosmic-comp` não expõe `wlr_foreign_toplevel_management`. O
#      protocolo que ele expõe é `ext_foreign_toplevel_list_v1`, e falar com ele
#      é abrir o socket do compositor e trocar mensagens. Um cliente Wayland de
#      verdade em 90 linhas de `socket` + `struct` custa menos que uma
#      dependência nova num projeto que veste a máquina inteira dela.
#
#   2. O casamento `app_id -> .desktop` COMO O DOCK FAZ. Reimplementa
#      `find_app_by_id` + `default_paths` da crate `freedesktop-desktop-entry`
#      0.8.1 — a versão exata que o `Cargo.lock` do commit `40248fb` trava, e que
#      é o `/usr/bin/cosmic-applets` instalado (`1.0.15~1787597446~24.04~40248fb`,
#      construído em 2026-08-24 18:50 UTC; o `.crate` de crates.io bate por
#      sha256 com o fonte lido). É essa reimplementação que permite ao script
#      responder, ANTES de escrever, "este app_id já casa hoje?" — a pergunta que
#      impede o sequestro descrito no cabeçalho do `appid_dock.sh`.
#
# AS SEIS ETAPAS, NA ORDEM (fde 0.8.1, lib.rs:1018) — e a precedência
#   1. StartupWMClass== app_id            (ASCII case-insensitive)
#   2. id do .desktop, ou file_stem, ou o ÚLTIMO segmento pontuado do app_id
#      contra o file_stem. As duas primeiras cláusulas são case-insensitive; a
#      TERCEIRA é case-SENSITIVE — medido: `org.teste.MinhaApp` casa com
#      `MinhaApp.desktop`, `org.teste.minhaapp` NÃO.
#   3. Name= (o NÃO localizado)   4. Exec= inteiro   5. 1ª palavra do Exec=
#   6. X-SnapAppName=  (morta nesta máquina: zero snaps)
#
#   A ETAPA VENCE A PRECEDÊNCIA XDG. Cada etapa varre o parque INTEIRO antes de a
#   seguinte começar — medido num parque sintético: um `.desktop` em
#   `$XDG_DATA_HOME` que casava só por NOME DE ARQUIVO perdeu para um de
#   `/usr/share` que casava por `StartupWMClass`. O `$XDG_DATA_HOME` só desempata
#   DENTRO de uma etapa, e dentro de um diretório vence o alfabeticamente
#   primeiro (o `Iter` do upstream ordena de propósito: "order of parsing affects
#   appid matches").
#
#   `NoDisplay=true` e `Hidden=true` NÃO participam do casamento (medido: casam
#   igual). É o que deixa a ponte invisível no lançador sem perder o efeito no
#   dock. `Icon=` também não participa: é só o que o dock desenha DEPOIS de casar.
#
# O QUE ESTE ARQUIVO NÃO FAZ
#   Não escreve, não abre janela, não fica residente, não grava estado. Ele é
#   chamado, responde e morre. Quem decide é o `appid_dock.sh`; quem cura o mapa
#   é ela.
#
# MODOS
#   --janelas   TSV `app_id \t título` de tudo que está aberto AGORA.
#               Sai 3 quando não há sessão Wayland ou o protocolo não existe.
#   --parque    TSV `desktop-id \t caminho \t Name \t Icon \t Exec \t X-Flatpak`
#               do parque inteiro, NA ORDEM DE PRECEDÊNCIA (o primeiro de cada
#               desktop-id é o que vence).
#   --casar     lê app_id do stdin, um por linha; escreve `app_id \t etapa \t caminho`
#               (`-` e `-` quando não casa). `--sem-ponte` ignora os `.desktop`
#               que carregam a marca de autoria da ponte — é o que torna a
#               pergunta "já casava ANTES de nós?" respondível.
#   --sugerir   lê app_id do stdin; escreve `app_id \t candidato1,candidato2,...`
#               Só SUGERE, para o aviso do script montar a linha de colar.
import os
import sys
import glob
import socket
import struct
import time

MARCA_PONTE = "X-MeowSystem=janela-dock"


# ============================================================================
# O parque de .desktop, como o dock o enxerga
# ============================================================================
def caminhos_xdg():
    """`fde::default_paths()`: $XDG_DATA_HOME primeiro, depois $XDG_DATA_DIRS."""
    home = os.path.expanduser("~")
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.join(home, ".local/share")
    dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    saida = []
    for d in [data_home] + [x for x in dirs.split(":") if x]:
        p = os.path.join(d, "applications")
        if p not in saida:
            saida.append(p)
    return saida


def ler_entrada(caminho):
    """Só a seção [Desktop Entry], só a PRIMEIRA ocorrência de cada chave, e só o
    valor NÃO localizado (`Name` — nunca `Name[pt_BR]`), que é o que a fde lê com
    `name::<&str>(&[])`."""
    try:
        with open(caminho, encoding="utf-8", errors="replace") as fh:
            texto = fh.read()
    except OSError:
        return None
    dados, secao, bruto = {}, None, texto
    for linha in texto.splitlines():
        s = linha.strip()
        if s.startswith("[") and s.endswith("]"):
            secao = s
            continue
        if secao != "[Desktop Entry]" or s.startswith("#") or "=" not in s:
            continue
        chave, valor = s.split("=", 1)
        chave = chave.strip()
        if "[" in chave:          # Name[pt_BR] — localizado, a fde não usa
            continue
        dados.setdefault(chave, valor.strip())
    # O desktop-id: tira `.desktop`, pega o que vem depois do último
    # `/applications/` e troca `/` por `-` (fde 0.8.1, decoder.rs:226 —
    # subdiretório vira traço).
    rel = caminho.split("/applications/", 1)[1] if "/applications/" in caminho else os.path.basename(caminho)
    ident = rel[: -len(".desktop")].replace("/", "-")
    stem = os.path.basename(caminho)[: -len(".desktop")]
    return {"id": ident, "stem": stem, "caminho": caminho, "e": dados, "bruto": bruto}


def carregar_parque():
    entradas = []
    for d in caminhos_xdg():
        if not os.path.isdir(d):
            continue
        for p in sorted(glob.glob(os.path.join(d, "**/*.desktop"), recursive=True)):
            x = ler_entrada(p)
            if x is not None:
                entradas.append(x)
    return entradas


def baixo(s):
    return s.lower() if s else None


def casar(entradas, app_id):
    """`fde::find_app_by_id` 0.8.1, etapa por etapa, na ordem."""
    a = baixo(app_id)
    for e in entradas:                                            # 1
        if baixo(e["e"].get("StartupWMClass")) == a:
            return ("StartupWMClass", e)
    for e in entradas:                                            # 2
        if baixo(e["id"]) == a or baixo(e["stem"]) == a:
            return ("id", e)
        # a terceira cláusula é case-SENSITIVE (medido)
        if app_id.split(".")[-1] == e["stem"]:
            return ("id", e)
    for e in entradas:                                            # 3
        if baixo(e["e"].get("Name")) == a:
            return ("Name", e)
    for e in entradas:                                            # 4
        if baixo(e["e"].get("Exec")) == a:
            return ("Exec", e)
    for e in entradas:                                            # 5
        ex = e["e"].get("Exec")
        if ex and ex.split() and baixo(ex.split()[0]) == a:
            return ("Exec[0]", e)
    for e in entradas:                                            # 6
        if baixo(e["e"].get("X-SnapAppName")) == a:
            return ("X-SnapAppName", e)
    return (None, None)


# ============================================================================
# A sonda Wayland: ext_foreign_toplevel_list_v1
# ============================================================================
def sondar_janelas(limite=3.0):
    """Devolve [(app_id, título)] das janelas abertas. Levanta OSError quando não
    há sessão. Levanta LookupError quando o compositor não expõe o protocolo.

    A conversa é curta de propósito: bind na lista, `wl_display.sync`, e o
    `wl_callback.done` prova que TUDO que o compositor tinha na fila já chegou.
    Sem isso a sonda teria de dormir um tempo arbitrário — e um instalador não
    pode custar segundos por chute."""
    runtime = os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid()
    disp = os.environ.get("WAYLAND_DISPLAY") or "wayland-0"
    caminho = disp if disp.startswith("/") else os.path.join(runtime, disp)

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(limite)
    s.connect(caminho)

    proximo = [1]

    def novo_id():
        proximo[0] += 1
        return proximo[0]

    def msg(obj, op, corpo=b""):
        return struct.pack("<II", obj, ((8 + len(corpo)) << 16) | op) + corpo

    def wstr(t):
        b = t.encode() + b"\0"
        return struct.pack("<I", len(b)) + b + b"\0" * ((-len(b)) % 4)

    registro = novo_id()
    s.sendall(msg(1, 1, struct.pack("<I", registro)))      # wl_display.get_registry

    buf = b""
    globais = set()
    lista = None
    retorno = None
    punhos = {}
    t0 = time.time()

    while time.time() - t0 < limite:
        try:
            pedaco = s.recv(8192)
        except socket.timeout:
            break
        if not pedaco:
            break
        buf += pedaco
        while len(buf) >= 8:
            obj, sz_op = struct.unpack("<II", buf[:8])
            tam, op = sz_op >> 16, sz_op & 0xFFFF
            if tam < 8 or len(buf) < tam:
                break
            corpo, buf = buf[8:tam], buf[tam:]

            if obj == registro and op == 0:                # wl_registry.global
                nome = struct.unpack("<I", corpo[:4])[0]
                n = struct.unpack("<I", corpo[4:8])[0]
                iface = corpo[8:8 + n - 1].decode("utf-8", "replace")
                pad = ((n + 3) // 4) * 4
                ver = struct.unpack("<I", corpo[8 + pad:12 + pad])[0]
                globais.add(iface)
                if iface == "ext_foreign_toplevel_list_v1" and lista is None:
                    lista = novo_id()
                    s.sendall(msg(registro, 0,
                                  struct.pack("<I", nome) + wstr(iface)
                                  + struct.pack("<II", min(ver, 1), lista)))
                    retorno = novo_id()
                    s.sendall(msg(1, 0, struct.pack("<I", retorno)))  # wl_display.sync
            elif lista is not None and obj == lista and op == 0:      # toplevel
                h = struct.unpack("<I", corpo[:4])[0]
                punhos[h] = {"app_id": "", "titulo": ""}
            elif obj in punhos and op in (2, 3):          # title=2, app_id=3
                n = struct.unpack("<I", corpo[:4])[0]
                val = corpo[4:4 + n - 1].decode("utf-8", "replace")
                punhos[obj]["titulo" if op == 2 else "app_id"] = val
            elif retorno is not None and obj == retorno and op == 0:  # wl_callback.done
                s.close()
                return [(v["app_id"], v["titulo"]) for v in punhos.values() if v["app_id"]]

        # O registro terminou de anunciar e o protocolo não veio: um roundtrip
        # basta para saber, e sem ele ficaríamos esperando o limite inteiro.
        if lista is None and retorno is None and globais:
            retorno = novo_id()
            s.sendall(msg(1, 0, struct.pack("<I", retorno)))

    s.close()
    if lista is None:
        raise LookupError("ext_foreign_toplevel_list_v1 não exposto (%d globals vistos)" % len(globais))
    return [(v["app_id"], v["titulo"]) for v in punhos.values() if v["app_id"]]


# ============================================================================
# Sugestão — SÓ sugestão, e o script deixa claro que é para ela conferir
# ============================================================================
def normalizar(s):
    return "".join(c for c in (s or "").lower() if c.isalnum())


def sugerir(entradas, app_id, teto=3):
    """Candidatos por CONTENÇÃO de nome normalizado, nos dois sentidos. É uma
    heurística de RECADO, nunca de escrita: a linha vai para a tela para ela
    conferir e colar. Nenhuma normalização deste tipo existe no casamento real —
    é justamente por isso que a etapa não pode adivinhar (o `boxy-svg` do
    briefing seria escrito aqui e estaria ERRADO: o app_id medido é
    `boxy-svg-boxy-svg-linux`)."""
    alvo = normalizar(app_id)
    if len(alvo) < 3:
        return []
    vistos, saida = set(), []
    for e in entradas:
        if MARCA_PONTE in e["bruto"]:
            continue
        if e["e"].get("Type") not in (None, "Application"):
            continue
        for campo in (e["id"], e["e"].get("Name")):
            n = normalizar(campo)
            if len(n) < 3:
                continue
            if (n in alvo or alvo in n) and e["id"] not in vistos:
                vistos.add(e["id"])
                saida.append(e["id"])
                break
        if len(saida) >= teto:
            break
    return saida


# ============================================================================
def limpo(v):
    return (v or "").replace("\t", " ").replace("\n", " ")


def main(argv):
    modo = argv[1] if len(argv) > 1 else ""

    if modo == "--janelas":
        try:
            janelas = sondar_janelas()
        except (OSError, LookupError) as erro:
            print("sem sessão Wayland utilizável: %s" % erro, file=sys.stderr)
            return 3
        for app_id, titulo in janelas:
            print("%s\t%s" % (limpo(app_id), limpo(titulo)))
        return 0

    entradas = carregar_parque()

    if modo == "--parque":
        for e in entradas:
            print("\t".join(limpo(x) for x in (
                e["id"], e["caminho"], e["e"].get("Name"), e["e"].get("Icon"),
                e["e"].get("Exec"), e["e"].get("X-Flatpak"))))
        return 0

    if modo in ("--casar", "--sugerir"):
        if "--sem-ponte" in argv[2:]:
            entradas = [e for e in entradas if MARCA_PONTE not in e["bruto"]]
        for linha in sys.stdin:
            app_id = linha.rstrip("\n")
            if not app_id:
                continue
            if modo == "--sugerir":
                print("%s\t%s" % (limpo(app_id), ",".join(sugerir(entradas, app_id))))
            else:
                etapa, e = casar(entradas, app_id)
                print("%s\t%s\t%s" % (limpo(app_id), etapa or "-", e["caminho"] if e else "-"))
        return 0

    print("uso: appid_sonda.py [--janelas|--parque|--casar [--sem-ponte]|--sugerir]",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

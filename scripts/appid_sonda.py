#!/usr/bin/env python3
import os
import sys
import glob
import socket
import struct
import time

MARCA_PONTE = "X-MeowSystem=janela-dock"
SEM_APP_ID = "-"


def caminhos_xdg():
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
        if "[" in chave:
            continue
        dados.setdefault(chave, valor.strip())
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
    a = baixo(app_id)
    for e in entradas:
        if baixo(e["e"].get("StartupWMClass")) == a:
            return ("StartupWMClass", e)
    for e in entradas:
        if baixo(e["id"]) == a or baixo(e["stem"]) == a:
            return ("id", e)
        if app_id.split(".")[-1] == e["stem"]:
            return ("id", e)
    for e in entradas:
        if baixo(e["e"].get("Name")) == a:
            return ("Name", e)
    for e in entradas:
        if baixo(e["e"].get("Exec")) == a:
            return ("Exec", e)
    for e in entradas:
        ex = e["e"].get("Exec")
        if ex and ex.split() and baixo(ex.split()[0]) == a:
            return ("Exec[0]", e)
    for e in entradas:
        if baixo(e["e"].get("X-SnapAppName")) == a:
            return ("X-SnapAppName", e)
    return (None, None)


def sondar_janelas(limite=3.0):
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
    s.sendall(msg(1, 1, struct.pack("<I", registro)))

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

            if obj == registro and op == 0:
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
                    s.sendall(msg(1, 0, struct.pack("<I", retorno)))
            elif lista is not None and obj == lista and op == 0:
                h = struct.unpack("<I", corpo[:4])[0]
                punhos[h] = {"app_id": "", "titulo": ""}
            elif obj in punhos and op in (2, 3):
                n = struct.unpack("<I", corpo[:4])[0]
                val = corpo[4:4 + n - 1].decode("utf-8", "replace")
                punhos[obj]["titulo" if op == 2 else "app_id"] = val
            elif retorno is not None and obj == retorno and op == 0:
                s.close()
                return [(v["app_id"], v["titulo"]) for v in punhos.values()]

        if lista is None and retorno is None and globais:
            retorno = novo_id()
            s.sendall(msg(1, 0, struct.pack("<I", retorno)))

    s.close()
    if lista is None:
        raise LookupError("ext_foreign_toplevel_list_v1 não exposto (%d globals vistos)" % len(globais))
    return [(v["app_id"], v["titulo"]) for v in punhos.values()]


def sondar_areas(limite=3.0, ativar=None):
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

    def rstr(corpo):
        n = struct.unpack("<I", corpo[:4])[0]
        return corpo[4:4 + n - 1].decode("utf-8", "replace")

    registro = novo_id()
    s.sendall(msg(1, 1, struct.pack("<I", registro)))
    queridas = {"ext_foreign_toplevel_list_v1": 1, "zcosmic_toplevel_info_v1": 3,
                "ext_workspace_manager_v1": 1}
    ligadas = {}
    areas = {}
    janelas = {}
    cosmicas = {}
    fase = [0]
    retorno = [novo_id()]
    s.sendall(msg(1, 0, struct.pack("<I", retorno[0])))

    buf = b""
    t0 = time.time()
    while time.time() - t0 < limite:
        try:
            pedaco = s.recv(65536)
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

            if obj == registro and op == 0:
                nome = struct.unpack("<I", corpo[:4])[0]
                iface = rstr(corpo[4:])
                n = struct.unpack("<I", corpo[4:8])[0]
                ver = struct.unpack("<I", corpo[8 + ((n + 3) // 4) * 4:][:4])[0]
                if iface in queridas and iface not in ligadas:
                    ligadas[iface] = novo_id()
                    s.sendall(msg(registro, 0, struct.pack("<I", nome) + wstr(iface)
                                  + struct.pack("<II", min(ver, queridas[iface]), ligadas[iface])))
            elif obj == ligadas.get("ext_workspace_manager_v1") and op == 1:
                areas[struct.unpack("<I", corpo[:4])[0]] = {"nome": "", "estado": 0}
            elif obj in areas and op == 1:
                areas[obj]["nome"] = rstr(corpo)
            elif obj in areas and op == 3:
                areas[obj]["estado"] = struct.unpack("<I", corpo[:4])[0]
            elif obj == ligadas.get("ext_foreign_toplevel_list_v1") and op == 0:
                janelas[struct.unpack("<I", corpo[:4])[0]] = {
                    "app_id": "", "titulo": "", "areas": [], "foco": False}
            elif obj in janelas and op in (2, 3):
                janelas[obj]["titulo" if op == 2 else "app_id"] = rstr(corpo)
            elif obj in cosmicas and op == 8:
                n = struct.unpack("<I", corpo[:4])[0]
                estados = struct.unpack("<%dI" % (n // 4), corpo[4:4 + n])
                janelas[cosmicas[obj]]["foco"] = 2 in estados
            elif obj in cosmicas and op == 10:
                janelas[cosmicas[obj]]["areas"].append(struct.unpack("<I", corpo[:4])[0])
            elif obj in cosmicas and op == 11:
                saiu = struct.unpack("<I", corpo[:4])[0]
                janelas[cosmicas[obj]]["areas"] = [a for a in janelas[cosmicas[obj]]["areas"] if a != saiu]
            elif obj == ligadas.get("zcosmic_toplevel_info_v1") and op == 2 and fase[0] == 2:
                fase[0] = 3
                retorno[0] = novo_id()
                s.sendall(msg(1, 0, struct.pack("<I", retorno[0])))
            elif obj == retorno[0] and op == 0:
                fase[0] += 1
                if fase[0] >= 4 and ativar is not None and "ext_workspace_manager_v1" in ligadas:
                    alvo = [h for h, a in areas.items() if limpo(a["nome"]).strip("\u2007 ") == ativar]
                    ativar = None
                    if alvo:
                        s.sendall(msg(alvo[0], 1) + msg(ligadas["ext_workspace_manager_v1"], 0))
                        retorno[0] = novo_id()
                        s.sendall(msg(1, 0, struct.pack("<I", retorno[0])))
                        continue
                if fase[0] >= 4:
                    s.close()
                    return areas, list(janelas.values()), sorted(ligadas)
                if fase[0] == 2 and janelas and "zcosmic_toplevel_info_v1" in ligadas:
                    for h in janelas:
                        c = novo_id()
                        cosmicas[c] = h
                        s.sendall(msg(ligadas["zcosmic_toplevel_info_v1"], 1, struct.pack("<II", c, h)))
                    continue
                if fase[0] == 2:
                    fase[0] = 3
                retorno[0] = novo_id()
                s.sendall(msg(1, 0, struct.pack("<I", retorno[0])))

    s.close()
    raise LookupError("a sessão não respondeu a tempo (%s)" % ", ".join(sorted(ligadas)))


def normalizar(s):
    return "".join(c for c in (s or "").lower() if c.isalnum())


def sugerir(entradas, app_id, teto=3):
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
            print("%s\t%s" % (limpo(app_id) or SEM_APP_ID, limpo(titulo)))
        return 0

    if modo == "--ativar":
        alvo = argv[2] if len(argv) > 2 else ""
        try:
            areas, _, _ = sondar_areas(ativar=alvo)
        except (OSError, LookupError) as erro:
            print("sem sessão Wayland utilizável: %s" % erro, file=sys.stderr)
            return 3
        if not any(limpo(a["nome"]).strip("\u2007 ") == alvo for a in areas.values()):
            print("a sessão não tem área «%s»" % alvo, file=sys.stderr)
            return 3
        return 0

    if modo == "--areas":
        try:
            areas, janelas, ligadas = sondar_areas()
        except (OSError, LookupError) as erro:
            print("sem sessão Wayland utilizável: %s" % erro, file=sys.stderr)
            return 3
        faltam = sorted({"ext_workspace_manager_v1", "zcosmic_toplevel_info_v1"} - set(ligadas))
        if faltam:
            print("a sessão não expõe %s" % ", ".join(faltam), file=sys.stderr)
            return 3
        for a in areas.values():
            estado = [n for b, n in ((1, "ativa"), (2, "urgente"), (4, "oculta")) if a["estado"] & b]
            print("area\t%s\t%s" % (limpo(a["nome"]).strip("\u2007 "), ",".join(estado) or "-"))
        for j in janelas:
            nomes = ",".join(limpo(areas[a]["nome"]).strip("\u2007 ") for a in j["areas"] if a in areas)
            print("janela\t%s\t%s\t%s\t%s" % (limpo(j["app_id"]) or SEM_APP_ID, limpo(j["titulo"]),
                                                nomes or "-", "foco" if j["foco"] else "-"))
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

    print("uso: appid_sonda.py [--janelas|--areas|--ativar <nome>|--parque|--casar [--sem-ponte]|--sugerir]",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

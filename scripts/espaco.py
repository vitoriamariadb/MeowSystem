#!/usr/bin/env python3
import fcntl
import fnmatch
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import time

CATEGORIAS = ("reconstruível", "backup", "de quem usa")
COLUNAS = ("id", "categoria", "caminho", "nome", "refazer", "teto", "corte", "desinstala", "dica")
GUARDA_S = 600
OCIOSO_S = 7 * 86400
IDADE_UNIDADE_S = 7 * 86400
APERTADO_PCT = 85
TRAVAS_DO_CARGO = (".cargo-lock", ".cargo-build-lock", ".cargo-artifact-lock")
PESADOS = ("deps", ".fingerprint", "build", "incremental", "examples", "registry", "src", "git")
RE_HASH = re.compile(r"-([0-9a-f]{16})(?:[./\"]|$)")
RE_DATA = re.compile(r"^(\d{4})-(\d\d)-(\d\d)T(\d\d)-(\d\d)-(\d\d)")
RE_DATA_CURTA = re.compile(r"(\d{4})(\d\d)(\d\d)")
RE_SUFIXO_DA_VERSAO = re.compile(r"(\.dsc|\.tar\..*|\.tentado)$")


def ambiente():
    casa = os.environ.get("HOME") or os.path.expanduser("~")
    estado = os.environ.get("MEOW_ESTADO") or os.path.join(casa, ".local", "state", "meowsystem")
    cache = os.environ.get("MEOW_CACHE") or os.path.join(
        os.environ.get("XDG_CACHE_HOME") or os.path.join(casa, ".cache"), "meowsystem")
    raiz = os.environ.get("MEOW_RAIZ") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return {"HOME": casa, "MEOW_ESTADO": estado, "MEOW_CACHE": cache, "MEOW_RAIZ": raiz}


def caminho_do_registro():
    return os.environ.get("ESPACO_REGISTRO") or os.path.join(
        ambiente()["MEOW_RAIZ"], "assets", "contratos", "espaco.tsv")


def ler_registro():
    entradas = []
    with open(caminho_do_registro(), encoding="utf-8") as fh:
        for linha in fh:
            linha = linha.rstrip("\n")
            if not linha.strip():
                continue
            campos = linha.split("\t")
            if len(campos) != len(COLUNAS):
                continue
            e = dict(zip(COLUNAS, campos))
            e["refazer"] = 0 if e["refazer"] == "-" else int(e["refazer"])
            e["teto"] = 0 if e["teto"] == "-" else int(e["teto"]) << 20
            nome, _, resto = e["corte"].partition(":")
            e["modo"] = nome
            e["args"] = [int(x) for x in resto.split(":") if x.isdigit()]
            entradas.append(e)
    return entradas


def expandir_variaveis(texto):
    env = ambiente()
    for chave in sorted(env, key=len, reverse=True):
        texto = texto.replace("$" + chave, env[chave])
    return texto


def expandir_padrao(padrao):
    partes = padrao.split(os.sep)
    bases = [os.sep if padrao.startswith(os.sep) else ""]
    for parte in partes:
        if parte == "":
            continue
        novas = []
        for base in bases:
            if not any(c in parte for c in "*?["):
                alvo = os.path.join(base, parte) if base else parte
                if os.path.lexists(alvo):
                    novas.append(alvo)
                continue
            try:
                nomes = sorted(os.listdir(base or "."))
            except OSError:
                continue
            for nome in nomes:
                if fnmatch.fnmatchcase(nome, parte):
                    novas.append(os.path.join(base, nome) if base else nome)
        bases = novas
    return bases


def donos_dos_caminhos(entradas):
    donos = {}
    for e in entradas:
        e["caminhos"] = []
        for padrao in e["caminho"].split("|"):
            for achado in expandir_padrao(expandir_variaveis(padrao)):
                if achado in donos:
                    continue
                donos[achado] = e["id"]
                e["caminhos"].append(achado)
    return donos


def tamanho(caminho, poda=()):
    total = 0
    visto = set()
    pilha = [caminho]
    while pilha:
        atual = pilha.pop()
        try:
            st = os.lstat(atual)
        except OSError:
            continue
        eh_pasta = stat.S_ISDIR(st.st_mode)
        if not eh_pasta and st.st_nlink > 1:
            chave = (st.st_dev, st.st_ino)
            if chave in visto:
                continue
            visto.add(chave)
        total += st.st_blocks * 512
        if eh_pasta:
            try:
                with os.scandir(atual) as it:
                    for filho in it:
                        if filho.path in poda:
                            continue
                        pilha.append(filho.path)
            except OSError:
                pass
    return total


def ultimo_uso(caminho):
    try:
        st = os.lstat(caminho)
    except OSError:
        return 0
    if stat.S_ISDIR(st.st_mode):
        return st.st_mtime
    return max(st.st_mtime, st.st_atime)


def ultimo_uso_da_pasta(caminho):
    melhor = ultimo_uso(caminho)
    try:
        with os.scandir(caminho) as it:
            for filho in it:
                melhor = max(melhor, ultimo_uso(filho.path))
    except OSError:
        pass
    return melhor


def travado(arquivo):
    try:
        fd = os.open(arquivo, os.O_RDONLY)
    except OSError:
        return False
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        fcntl.flock(fd, fcntl.LOCK_UN)
        return False
    except OSError:
        return True
    finally:
        os.close(fd)


def build_do_cargo_em_curso(raiz, profundidade=4):
    pilha = [(raiz, 0)]
    while pilha:
        atual, nivel = pilha.pop()
        try:
            with os.scandir(atual) as it:
                filhos = list(it)
        except OSError:
            continue
        for filho in filhos:
            if filho.name in TRAVAS_DO_CARGO and filho.is_file(follow_symlinks=False):
                if travado(filho.path):
                    return True
            elif filho.is_dir(follow_symlinks=False) and nivel < profundidade \
                    and filho.name not in PESADOS:
                pilha.append((filho.path, nivel + 1))
    return False


def trava_de_builds():
    return os.environ.get("ESPACO_TRAVA_BUILDS") or os.path.join(ambiente()["MEOW_ESTADO"], "builds.lock")


def build_em_curso(raiz=None):
    if os.path.exists(trava_de_builds()) and travado(trava_de_builds()):
        return True
    return bool(raiz) and os.path.isdir(raiz) and build_do_cargo_em_curso(raiz)


def pegar_trava_de_builds():
    caminho = trava_de_builds()
    herdado = os.environ.get("ESPACO_TRAVA_FD", "")
    if herdado.isdigit():
        try:
            fd = int(herdado)
            if os.path.samestat(os.fstat(fd), os.stat(caminho)):
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                return "minha", None
        except OSError:
            pass
    try:
        os.makedirs(os.path.dirname(caminho), exist_ok=True)
        fd = os.open(caminho, os.O_RDWR | os.O_CREAT, 0o666)
    except OSError:
        return "indisponivel", None
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        os.close(fd)
        return "ocupada", None
    return "minha", fd


def soltar_trava_de_builds(fd):
    if fd is not None:
        os.close(fd)


def uso_pct():
    forcado = os.environ.get("ESPACO_DISCO_USO_PCT")
    if forcado and forcado.isdigit():
        return int(forcado)
    try:
        v = os.statvfs(ambiente()["HOME"])
    except OSError:
        return 0
    usado = v.f_blocks - v.f_bfree
    base = usado + v.f_bavail
    return int(round(100 * usado / base)) if base else 0


def disco_apertado():
    return uso_pct() >= APERTADO_PCT


def versao_do_pacote(pacote):
    forcada = os.environ.get("ESPACO_VERSAO_DO_PACOTE")
    if forcada is not None:
        return forcada
    try:
        saida = subprocess.run(["dpkg-query", "-W", "-f=${Version}", pacote],
                               capture_output=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return ""
    return saida.stdout.decode("utf-8", "replace").strip() if saida.returncode == 0 else ""


def data_do_backup(nome, caminho):
    m = RE_DATA.match(nome)
    if m:
        try:
            return time.mktime(tuple(int(x) for x in m.groups()) + (0, 0, -1))
        except (OverflowError, ValueError):
            pass
    m = RE_DATA_CURTA.search(nome)
    if m:
        try:
            return time.mktime(tuple(int(x) for x in m.groups()) + (0, 0, 0, 0, 0, -1))
        except (OverflowError, ValueError):
            pass
    return ultimo_uso(caminho)


def hashes_em_uso(estado):
    base = os.path.join(estado, "extensoes")
    instaladas, listadas = 0, 0
    achados = set()
    try:
        nomes = sorted(os.listdir(base))
    except OSError:
        return achados, False
    for nome in nomes:
        pasta = os.path.join(base, nome)
        if nome in (".target", "usuario") or not os.path.isfile(os.path.join(pasta, "carimbo")):
            continue
        instaladas += 1
        lista = os.path.join(pasta, "uso.lista")
        if not os.path.isfile(lista):
            continue
        listadas += 1
        with open(lista, encoding="utf-8") as fh:
            achados.update(l.strip() for l in fh if l.strip())
    return achados, instaladas > 0 and instaladas == listadas


def unidades_do_alvo(alvo):
    unidades = {}
    release = os.path.join(alvo, "release")
    for sub in ("deps", ".fingerprint", "build"):
        pasta = os.path.join(release, sub)
        try:
            nomes = os.listdir(pasta)
        except OSError:
            continue
        for nome in nomes:
            m = RE_HASH.search(nome)
            if not m:
                continue
            caminho = os.path.join(pasta, nome)
            u = unidades.setdefault(m.group(1), {"caminhos": [], "uso": 0.0, "bytes": 0, "por_caminho": {}})
            u["caminhos"].append(caminho)
            u["uso"] = max(u["uso"], ultimo_uso_da_pasta(caminho) if os.path.isdir(caminho) else ultimo_uso(caminho))
            u["por_caminho"][caminho] = tamanho(caminho)
            u["bytes"] += u["por_caminho"][caminho]
    return unidades


def plano_unidades(e, alvo, estado, apertado, agora):
    teto = e["teto"] // 2 if apertado else e["teto"]
    idade = IDADE_UNIDADE_S // 3 if apertado else IDADE_UNIDADE_S
    unidades = unidades_do_alvo(alvo)
    em_uso, lista_completa = hashes_em_uso(estado)
    cortes = []
    perfil = os.path.join(alvo, "debug")
    gasto = 0
    if os.path.isdir(perfil):
        gasto = tamanho(perfil)
        cortes.append({"caminho": perfil, "motivo": "perfil que ninguém usa", "bytes": gasto})
    marcadas = {}
    for h, u in unidades.items():
        if h in em_uso or agora - u["uso"] < GUARDA_S:
            continue
        if lista_completa:
            marcadas[h] = "fora do build atual"
        elif agora - u["uso"] >= idade:
            marcadas[h] = "sem uso há dias"
    gasto += sum(unidades[h]["bytes"] for h in marcadas)
    total = tamanho(alvo)
    if teto and total - gasto > teto:
        restantes = sorted((u["uso"], h) for h, u in unidades.items()
                           if h not in marcadas and h not in em_uso and agora - u["uso"] >= GUARDA_S)
        for _, h in restantes:
            if total - gasto <= teto:
                break
            marcadas[h] = "acima do teto"
            gasto += unidades[h]["bytes"]
    for h in sorted(marcadas):
        for caminho in unidades[h]["caminhos"]:
            cortes.append({"caminho": caminho, "motivo": marcadas[h],
                           "bytes": unidades[h]["por_caminho"][caminho]})
    return cortes


def versoes_que_ficam(quando, em_uso, manter):
    ficam = {em_uso} & set(quando)
    for ver in sorted(quando, key=quando.get, reverse=True):
        if len(ficam) >= manter:
            break
        ficam.add(ver)
    return ficam


def versao_no_nome(nome, pacote):
    if nome.startswith(pacote + "_"):
        nome = nome[len(pacote) + 1:]
    ver = RE_SUFIXO_DA_VERSAO.sub("", nome)
    return ver.split(":")[-1] if ver[:1].isdigit() else None


def plano_guardados(e):
    manter = e["args"][0] if e["args"] else 2
    cortes = []
    for pasta in e["caminhos"]:
        pacote = os.path.basename(pasta)
        em_uso = versao_do_pacote(pacote).split(":")[-1]
        grupos = {}
        try:
            nomes = sorted(os.listdir(pasta))
        except OSError:
            continue
        for nome in nomes:
            ver = versao_no_nome(nome, pacote)
            if ver:
                grupos.setdefault(ver, []).append(os.path.join(pasta, nome))
        quando = {ver: max(ultimo_uso_da_pasta(c) for c in lista) for ver, lista in grupos.items()
                  if any(not c.endswith(".tentado") for c in lista)}
        ficam = versoes_que_ficam(quando, em_uso, manter) | {em_uso}
        for ver in sorted(grupos):
            if ver not in ficam:
                cortes += [{"caminho": c, "motivo": "versão antiga"} for c in grupos[ver]]
    return cortes


def plano_versoes(e, apertado, agora):
    pasta = e["caminhos"][0] if e["caminhos"] else None
    if not pasta or not os.path.isdir(pasta):
        return []
    manter = e["args"][0] if e["args"] else 2
    em_uso = versao_do_pacote("cosmic-comp")
    versoes = []
    for nome in sorted(os.listdir(pasta)):
        caminho = os.path.join(pasta, nome)
        if nome.startswith("cosmic-comp-") and os.path.isdir(caminho):
            versoes.append((nome[len("cosmic-comp-"):], caminho))
    ficam = versoes_que_ficam({ver: ultimo_uso_da_pasta(c) for ver, c in versoes}, em_uso, manter)
    cortes = []
    for ver, caminho in versoes:
        if ver in ficam:
            continue
        cortes.append({"caminho": caminho, "motivo": "versão antiga do compositor"})
        for log in ("baixar-%s.log" % ver, "compilar-%s.log" % ver):
            if os.path.exists(os.path.join(pasta, log)):
                cortes.append({"caminho": os.path.join(pasta, log), "motivo": "registro da versão antiga"})
    guarda = os.environ.get("ESPACO_GUARDA_DO_COMPOSITOR") or os.path.join(
        os.environ.get("XDG_DATA_HOME") or os.path.join(ambiente()["HOME"], ".local", "share"),
        "meowsystem", "fontes", "cosmic-comp")
    for nome in sorted(os.listdir(pasta)):
        if re.match(r"^cosmic-comp_.*\.(dsc|tar\..*)$", nome) and os.path.isfile(os.path.join(guarda, nome)):
            cortes.append({"caminho": os.path.join(pasta, nome), "motivo": "o fonte já está guardado"})
    return cortes


def unidades_de_segundo_nivel(pasta):
    unidades = []
    try:
        filhos = sorted(os.listdir(pasta))
    except OSError:
        return unidades
    for nome in filhos:
        caminho = os.path.join(pasta, nome)
        if os.path.isdir(caminho) and not os.path.islink(caminho):
            try:
                netos = sorted(os.listdir(caminho))
            except OSError:
                continue
            unidades += [os.path.join(caminho, n) for n in netos]
        else:
            unidades.append(caminho)
    return unidades


def plano_ocioso(e, apertado, agora):
    limite = 86400 if apertado else OCIOSO_S
    teto = e["teto"] // 2 if apertado else e["teto"]
    cortes = []
    for pasta in e["caminhos"]:
        try:
            filhos = sorted(os.listdir(pasta))
        except OSError:
            continue
        for nome in filhos:
            caminho = os.path.join(pasta, nome)
            if agora - ultimo_uso_da_pasta(caminho) >= limite:
                cortes.append({"caminho": caminho, "motivo": "parado há dias"})
        if not teto:
            continue
        saem = [c["caminho"] for c in cortes]
        total = tamanho(pasta) - sum(tamanho(c) for c in saem)
        if total <= teto:
            continue
        restantes = sorted(
            (ultimo_uso_da_pasta(u), u) for u in unidades_de_segundo_nivel(pasta)
            if not any(u == s or u.startswith(s + os.sep) for s in saem))
        for uso, unidade in restantes:
            if total <= teto:
                break
            if agora - uso < GUARDA_S:
                continue
            total -= tamanho(unidade)
            cortes.append({"caminho": unidade, "motivo": "acima do teto"})
    return cortes


def plano_recentes(e):
    manter = e["args"][0] if e["args"] else 2
    cortes = []
    for pasta in e["caminhos"]:
        versoes = {}
        try:
            nomes = sorted(os.listdir(pasta))
        except OSError:
            continue
        for nome in nomes:
            caminho = os.path.join(pasta, nome)
            if not os.path.isdir(caminho):
                continue
            try:
                pronto = any(not f.startswith(".") and os.path.isfile(os.path.join(caminho, f))
                             for f in os.listdir(caminho))
            except OSError:
                continue
            if pronto:
                versoes[nome] = ultimo_uso_da_pasta(caminho)
        ficam = versoes_que_ficam(versoes, None, manter)
        cortes += [{"caminho": os.path.join(pasta, v), "motivo": "versão antiga"}
                   for v in sorted(versoes) if v not in ficam]
    return cortes


def plano_orfao(e):
    return [{"caminho": c, "motivo": "pasta de compilação esquecida"} for c in e["caminhos"]]


def plano_rotacao(e, apertado, agora):
    dias = e["args"][0] if len(e["args"]) > 0 else 30
    quantas = e["args"][1] if len(e["args"]) > 1 else 100
    if apertado:
        dias, quantas = max(1, dias // 2), max(1, quantas // 2)
    pasta = e["caminhos"][0] if e["caminhos"] else None
    if not pasta or not os.path.isdir(pasta):
        return []
    itens = []
    for nome in os.listdir(pasta):
        caminho = os.path.join(pasta, nome)
        if "-tema-PRIMEIRO-" in nome or nome.endswith(("-sistema", "-meow.conf-antes-da-instalacao")):
            continue
        itens.append((data_do_backup(nome, caminho), caminho))
    itens.sort(reverse=True)
    cortes = []
    for posicao, (quando, caminho) in enumerate(itens):
        if agora - quando > dias * 86400:
            cortes.append({"caminho": caminho, "motivo": "backup com mais de %d dias" % dias})
        elif posicao >= quantas:
            cortes.append({"caminho": caminho, "motivo": "backup além dos %d mais novos" % quantas})
    return cortes


def planejar(entradas, modo, agora=None, apertado=None):
    agora = time.time() if agora is None else agora
    apertado = disco_apertado() if apertado is None else apertado
    estado = ambiente()["MEOW_ESTADO"]
    planos = {}
    for e in entradas:
        cortes = []
        corte = e["modo"]
        if modo == "liberar" and corte in ("unidades", "versoes", "ocioso", "orfao"):
            cortes = [{"caminho": c, "motivo": "a seu pedido"} for c in e["caminhos"]]
        elif corte == "unidades":
            for alvo in e["caminhos"]:
                cortes += plano_unidades(e, alvo, estado, apertado, agora)
        elif corte == "versoes":
            cortes = plano_versoes(e, apertado, agora)
        elif corte == "guardados":
            cortes = plano_guardados(e)
        elif corte == "ocioso":
            cortes = plano_ocioso(e, apertado, agora)
        elif corte == "recentes":
            cortes = plano_recentes(e)
        elif corte == "orfao":
            cortes = plano_orfao(e)
        elif corte == "rotacao":
            cortes = plano_rotacao(e, apertado, agora)
        for c in cortes:
            if "bytes" not in c:
                c["bytes"] = tamanho(c["caminho"])
        if cortes:
            planos[e["id"]] = cortes
    return planos


def em_curso_para(e, cortes, trava="sem"):
    if trava == "ocupada":
        return True
    if trava != "minha" and build_em_curso():
        return True
    raizes = e["caminhos"] if e["modo"] == "unidades" else [c["caminho"] for c in cortes]
    return any(os.path.isdir(r) and build_do_cargo_em_curso(r) for r in raizes)


def remover(caminho):
    try:
        if os.path.islink(caminho) or os.path.isfile(caminho):
            os.unlink(caminho)
        elif os.path.isdir(caminho):
            shutil.rmtree(caminho)
    except OSError:
        return False
    return not os.path.lexists(caminho)


def registrar(texto):
    estado = ambiente()["MEOW_ESTADO"]
    try:
        os.makedirs(estado, exist_ok=True)
        with open(os.path.join(estado, "meow.log"), "a", encoding="utf-8") as fh:
            fh.write("%s %s\n" % (time.strftime("%Y-%m-%dT%H:%M:%S%z"), texto))
    except OSError:
        pass


def bonito(n):
    if n >= 1 << 30:
        return ("%.1f GB" % (n / (1 << 30))).replace(".", ",")
    if n >= 1 << 20:
        return "%d MB" % round(n / (1 << 20))
    if n >= 1 << 10:
        return "%d KB" % round(n / (1 << 10))
    return "%d B" % n


def executar(modo, seco=False, agora=None, apertado=None):
    entradas = ler_registro()
    donos_dos_caminhos(entradas)
    planos = planejar(entradas, modo, agora, apertado)
    por_id = {e["id"]: e for e in entradas}
    trava, fd = "sem", None
    if not seco and any(por_id[i]["modo"] != "rotacao" for i in planos):
        trava, fd = pegar_trava_de_builds()
        if trava == "minha":
            donos_dos_caminhos(entradas)
            planos = planejar(entradas, modo, agora, apertado)
    liberou = 0
    saida = []
    esperou = []
    try:
        for ident, cortes in planos.items():
            e = por_id[ident]
            if e["modo"] != "rotacao" and em_curso_para(e, cortes, trava):
                esperou.append(e["nome"])
                continue
            if not seco:
                cortes = [c for c in cortes if remover(c["caminho"])]
                if not cortes:
                    continue
            bytes_do_item = sum(c["bytes"] for c in cortes)
            liberou += bytes_do_item
            saida.append((e["nome"], bytes_do_item, cortes[0]["motivo"]))
    finally:
        soltar_trava_de_builds(fd)
    return {"liberou": liberou, "itens": saida, "esperou": esperou}


def linhas_do_resultado(resultado, seco):
    verbo = "cortaria" if seco else "cortou"
    linhas = ["%s %s: %s (%s)" % (verbo, nome, bonito(b), motivo) for nome, b, motivo in resultado["itens"]]
    for nome in resultado["esperou"]:
        linhas.append("há build em curso, %s fica para depois" % nome)
    return linhas


def montar_relatorio(agora=None):
    entradas = ler_registro()
    donos = donos_dos_caminhos(entradas)
    apertado = disco_apertado()
    cortes_liberar = planejar(entradas, "liberar", agora, apertado)
    itens = []
    for e in entradas:
        poda = {c for c, d in donos.items() if d != e["id"]}
        ocupa = sum(tamanho(c, poda) for c in e["caminhos"])
        liberavel = sum(c["bytes"] for c in cortes_liberar.get(e["id"], []))
        itens.append({"id": e["id"], "nome": e["nome"], "categoria": e["categoria"], "bytes": ocupa,
                      "liberavel": liberavel,
                      "refazer": e["refazer"] if liberavel and e["modo"] not in ("guardados", "recentes") else 0,
                      "dica": e["dica"],
                      "desinstala": e["desinstala"]})
    return itens


def agrupar_por_nome(itens):
    grupos = {}
    ordem = []
    for it in itens:
        chave = (it["nome"], it["categoria"])
        if chave not in grupos:
            grupos[chave] = {"nome": it["nome"], "categoria": it["categoria"], "bytes": 0,
                             "liberavel": 0, "refazer": 0, "dica": "", "peso": -1, "ids": []}
            ordem.append(chave)
        g = grupos[chave]
        g["bytes"] += it["bytes"]
        g["liberavel"] += it["liberavel"]
        g["refazer"] += it["refazer"]
        g["ids"].append(it["id"])
        if it["bytes"] > g["peso"]:
            g["dica"], g["peso"] = it["dica"], it["bytes"]
    return [grupos[c] for c in ordem if grupos[c]["bytes"] or grupos[c]["liberavel"]]


def dados():
    itens = montar_relatorio()
    grupos = agrupar_por_nome(itens)
    categorias = []
    for cat in CATEGORIAS:
        doc = [i for i in itens if i["categoria"] == cat]
        categorias.append({"categoria": cat, "bytes": sum(i["bytes"] for i in doc),
                           "liberavel": sum(i["liberavel"] for i in doc)})
    entradas = ler_registro()
    donos_dos_caminhos(entradas)
    ocupado = build_em_curso() or any(
        e["modo"] == "unidades" and e["caminhos"] and build_em_curso(e["caminhos"][0]) for e in entradas)
    return {"total": sum(i["bytes"] for i in itens),
            "liberavel": sum(i["liberavel"] for i in itens),
            "refazer": sum(i["refazer"] for i in itens),
            "ocupado": ocupado,
            "categorias": categorias, "grupos": grupos, "itens": itens}


def cmd_json():
    json.dump(dados(), sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


def cmd_relatorio():
    d = dados()
    print("o MeowSystem ocupa %s" % bonito(d["total"]))
    for c in d["categorias"]:
        extra = "  (liberável %s)" % bonito(c["liberavel"]) if c["liberavel"] else ""
        print("  %-14s %9s%s" % (c["categoria"], bonito(c["bytes"]), extra))
    print()
    for g in sorted(d["grupos"], key=lambda g: -g["bytes"]):
        extra = "  liberável %s, refaz em ~%d min" % (bonito(g["liberavel"]), g["refazer"]) \
            if g["liberavel"] else ""
        print("  %-12s %9s%s" % (g["nome"], bonito(g["bytes"]), extra))
    if d["liberavel"]:
        print()
        print("liberar tira %s e o próximo build leva ~%d min" % (bonito(d["liberavel"]), d["refazer"]))
    return 0


def cmd_conferir():
    d = dados()
    base = "o MeowSystem ocupa %s: %s reconstruível, %s de backup" % (
        bonito(d["total"]), bonito(d["categorias"][0]["bytes"]), bonito(d["categorias"][1]["bytes"]))
    plano = executar("tetos", seco=True)
    if plano["itens"]:
        print("%s; tem %s para cortar" % (base, bonito(plano["liberou"])))
        return 1
    if plano["esperou"]:
        print("%s; há build em curso, a limpeza espera" % base)
        return 0
    print(base)
    return 0


def cmd_cortar(modo):
    seco = os.environ.get("MEOW_DRY_RUN") == "1"
    resultado = executar(modo, seco=seco)
    for linha in linhas_do_resultado(resultado, seco):
        print(linha)
    if resultado["liberou"] and not seco:
        print("liberou %s" % bonito(resultado["liberou"]))
        registrar("espaco %s liberou %s" % (modo, bonito(resultado["liberou"])))
    if resultado["itens"]:
        return 1
    if modo == "liberar" and not resultado["esperou"]:
        print("nada a liberar")
    return 0


def hash_do_executavel(caminho):
    try:
        inode = os.stat(caminho).st_ino
        with os.scandir(os.path.join(os.path.dirname(caminho), "deps")) as it:
            for filho in it:
                if filho.is_file(follow_symlinks=False) and filho.inode() == inode:
                    return RE_HASH.findall(filho.name + "/")
    except OSError:
        pass
    return []


def cmd_uso(destino):
    achados = set()
    ok = False
    for linha in sys.stdin:
        try:
            msg = json.loads(linha)
        except ValueError:
            continue
        razao = msg.get("reason")
        if razao == "build-finished":
            ok = bool(msg.get("success"))
        elif razao == "compiler-artifact":
            for f in (msg.get("filenames") or []):
                achados.update(RE_HASH.findall(os.path.basename(f) + "/"))
                achados.update(RE_HASH.findall(os.path.basename(os.path.dirname(f)) + "/"))
            if msg.get("executable"):
                achados.update(hash_do_executavel(msg["executable"]))
        elif razao == "build-script-executed":
            achados.update(RE_HASH.findall(os.path.basename(os.path.dirname(msg.get("out_dir") or "")) + "/"))
    if not ok or not achados:
        return 1
    tmp = destino + ".novo"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write("\n".join(sorted(achados)) + "\n")
    os.replace(tmp, destino)
    return 0


def cmd_desinstalar():
    seco = os.environ.get("MEOW_DRY_RUN") == "1"
    guardar_backups = os.environ.get("MEOW_GUARDAR_BACKUPS") == "1"
    entradas = ler_registro()
    donos = donos_dos_caminhos(entradas)
    sairao = {e["id"] for e in entradas
              if e["desinstala"] == "sim" or (e["desinstala"] == "backups" and not guardar_backups)}
    ficam = {c for c, d in donos.items() if d not in sairao}
    liberou = 0
    alvos = []
    for e in entradas:
        if e["id"] not in sairao:
            continue
        poda = {c for c, d in donos.items() if d != e["id"]}
        for caminho in e["caminhos"]:
            liberou += tamanho(caminho, poda)
            alvos.append(caminho)
    if not seco:
        for caminho in alvos:
            remover_podando(caminho, ficam)
        try:
            os.rmdir(ambiente()["MEOW_ESTADO"])
        except OSError:
            pass
    print("%d\t%s" % (liberou, bonito(liberou)))
    return 0


def remover_podando(caminho, ficam):
    if caminho in ficam:
        return
    if not os.path.isdir(caminho) or os.path.islink(caminho):
        remover(caminho)
        return
    for nome in os.listdir(caminho):
        filho = os.path.join(caminho, nome)
        if any(f == filho or f.startswith(filho + os.sep) for f in ficam):
            remover_podando(filho, ficam)
        else:
            remover(filho)
    try:
        os.rmdir(caminho)
    except OSError:
        pass


def cmd_inventario():
    entradas = ler_registro()
    donos_dos_caminhos(entradas)
    for e in entradas:
        for c in e["caminhos"]:
            print("%s\t%s\t%s" % (e["id"], e["categoria"], c))
    return 0


def dono_de(caminho, donos):
    while caminho not in donos:
        pai = os.path.dirname(caminho)
        if pai == caminho:
            return None
        caminho = pai
    return donos[caminho]


def cmd_cobre(casa_toda=False):
    entradas = ler_registro()
    donos = donos_dos_caminhos(entradas)
    env = ambiente()
    if casa_toda:
        fora = [os.path.join(pasta, nome) for pasta, _, nomes in os.walk(env["HOME"]) for nome in nomes
                if dono_de(os.path.join(pasta, nome), donos) is None]
        for caminho in sorted(fora):
            print(caminho)
        return 1 if fora else 0
    raizes = [env["MEOW_ESTADO"], env["MEOW_CACHE"],
              os.path.join(env["HOME"], ".local", "libexec", "meow"),
              os.path.join(env["HOME"], ".local", "share", "meowsystem"),
              os.path.join(env["HOME"], ".config", "meowsystem"),
              os.path.join(env["HOME"], ".config", "meow")]
    sem_dono = []
    for raiz in raizes:
        if not os.path.isdir(raiz):
            continue
        for nome in sorted(os.listdir(raiz)):
            caminho = os.path.join(raiz, nome)
            dono = dono_de(caminho, donos)
            if dono is None or dono == "estado-geral" or dono.endswith("-resto"):
                sem_dono.append(caminho)
    for caminho in sem_dono:
        print(caminho)
    return 1 if sem_dono else 0


def main(argv):
    verbo = argv[1] if len(argv) > 1 else "relatorio"
    if verbo in ("relatorio", "ver"):
        return cmd_relatorio()
    if verbo == "json":
        return cmd_json()
    if verbo == "conferir":
        return cmd_conferir()
    if verbo == "aparar":
        return cmd_cortar("tetos")
    if verbo == "continua":
        return cmd_cortar("continua")
    if verbo == "liberar":
        return cmd_cortar("liberar")
    if verbo == "uso" and len(argv) > 2:
        return cmd_uso(argv[2])
    if verbo == "desinstalar":
        return cmd_desinstalar()
    if verbo == "inventario":
        return cmd_inventario()
    if verbo == "cobre":
        return cmd_cobre("--casa" in argv)
    sys.stderr.write("uso: espaco.py [relatorio|json|conferir|aparar|continua|liberar|desinstalar|inventario|cobre]\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

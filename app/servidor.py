#!/usr/bin/env python3

import base64
import datetime
import functools
import hashlib
import hmac
import html
import json
import os
import queue
import re
import secrets
import select
import struct
import shlex
import signal
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs, quote

def _raiz_valida(caminho):
    return bool(caminho) and os.path.isfile(os.path.join(caminho, "lib", "comum.sh")) \
        and os.path.isfile(os.path.join(caminho, "install.sh"))


def _resolver_raiz():
    candidato = os.environ.get("MEOW_RAIZ", "")
    if _raiz_valida(candidato):
        return os.path.realpath(candidato)
    aqui = os.path.dirname(os.path.realpath(__file__))
    acima = os.path.dirname(aqui)
    if _raiz_valida(acima):
        return acima
    return None


RAIZ = _resolver_raiz()
if RAIZ is None:
    sys.stderr.write("servidor.py: não achei o repositório do MeowSystem.\n")
    sys.stderr.write("             aponte com: MEOW_RAIZ=/caminho/do/clone\n")
    sys.exit(3)

PAGINA = os.path.join(RAIZ, "app", "pagina")
MAPA_JOGOS = os.path.join(RAIZ, "assets", "apps", "jogos-fora.map")
ICONES_DO_MOTOR = os.path.join(RAIZ, "packs", "meowsystem", "icones")


def _glifo_do_motor(nome):
    for pasta in ("apps", "biblioteca", "sistema"):
        cand = os.path.join(ICONES_DO_MOTOR, pasta, nome + ".svg")
        if os.path.isfile(cand):
            return cand
    return os.path.join(ICONES_DO_MOTOR, "apps", nome + ".svg")
CONF_PADRAO = os.environ.get("MEOW_CONF_PADRAO") or os.path.join(RAIZ, "meow.conf.exemplo")
CONF = os.environ.get("MEOW_CONF") or os.path.expanduser("~/.config/meow/meow.conf")
_PALETA = None


def paleta_canonica():
    global _PALETA
    _ponte_em_dia()
    if _PALETA is None:
        mod = modulo_pack()
        _PALETA = (mod.paleta_do_pack_ativo() if mod
                   else os.environ.get("MEOW_PALETA") or "")
    return _PALETA


_PONTE_TRAVA = threading.Lock()
_PONTE_VISTA = {"iniciada": False, "relogio": None}


def _ponte_em_dia():
    global _PALETA
    try:
        relogio = os.stat(CONF).st_mtime_ns
    except OSError:
        relogio = None
    with _PONTE_TRAVA:
        if _PONTE_VISTA["iniciada"] and relogio == _PONTE_VISTA["relogio"]:
            return
        primeira = not _PONTE_VISTA["iniciada"]
        _PONTE_VISTA.update(iniciada=True, relogio=relogio)
        if primeira:
            return
        conf = conf_exportada()
        if conf is None:
            return
        for nome in ("MEOW_PALETA", "MEOW_PACK_DIR", "MEOW_PALETA_DA_PONTE"):
            if conf.get(nome):
                os.environ[nome] = conf[nome]
            else:
                os.environ.pop(nome, None)
        _PALETA = None
        _PALETA_CACHE.clear()


FOLHAS = os.path.join(RAIZ, "docs", "folhas")
ESTADO = os.environ.get("MEOW_ESTADO") or os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "meowsystem",
)

TOKEN = secrets.token_urlsafe(32)

CSP_DE_IMAGEM = "default-src 'none'; style-src 'unsafe-inline'; sandbox"


_LEITURA = threading.local()


def _uma_vez_por_leitura(funcao):
    @functools.wraps(funcao)
    def embrulho(*args):
        memoria = getattr(_LEITURA, "memoria", None)
        if memoria is None:
            return funcao(*args)
        chave = (funcao.__name__,) + tuple(tuple(a) if isinstance(a, list) else a
                                           for a in args)
        if chave not in memoria:
            memoria[chave] = funcao(*args)
        resposta = memoria[chave]
        return type(resposta)(resposta) if isinstance(resposta, (list, dict, set)) else resposta
    return embrulho


def _numa_leitura(funcao):
    @functools.wraps(funcao)
    def embrulho(*args, **kwargs):
        if getattr(_LEITURA, "memoria", None) is not None:
            return funcao(*args, **kwargs)
        _LEITURA.memoria = {}
        try:
            return funcao(*args, **kwargs)
        finally:
            _LEITURA.memoria = None
    return embrulho


RE_CHAVE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=")
RE_TOKEN_OPCAO = re.compile(r"^[A-Za-z0-9_.:+-]+$")
RE_FAIXA = re.compile(
    r"(?<![\w.])(\d+(?:[.,]\d+)?)\s*(?:\.\.|–|—|-|\ba\b|\bà\b)\s*(\d+(?:[.,]\d+)?)(?![\w.])"
)


def _valor_da_linha(linha):
    resto = linha.split("=", 1)[1] if "=" in linha else ""
    if resto.startswith('"'):
        return resto[1:].split('"', 1)[0]
    if resto.startswith("'"):
        return resto[1:].split("'", 1)[0]
    return re.split(r"[\s#]", resto, 1)[0]


def _comentario_da_linha(linha):
    resto = linha.split("=", 1)[1] if "=" in linha else ""
    if resto.startswith('"'):
        cauda = resto[1:].split('"', 1)
        cauda = cauda[1] if len(cauda) > 1 else ""
    elif resto.startswith("'"):
        cauda = resto[1:].split("'", 1)
        cauda = cauda[1] if len(cauda) > 1 else ""
    else:
        cauda = linha
    if "#" in cauda:
        return cauda.split("#", 1)[1].strip()
    return ""


def _e_linha_de_opcoes(linha):
    texto = linha.lstrip("#").strip()
    if "|" not in texto:
        return False
    texto = texto.split("(", 1)[0]
    return all(RE_TOKEN_OPCAO.match(t.strip()) for t in texto.split("|") if t.strip())


_PADROES_EXEMPLO = {}


def _padrao_do_exemplo(chave):
    if not _PADROES_EXEMPLO:
        try:
            with open(os.path.join(RAIZ, "meow.conf.exemplo"), encoding="utf-8") as fh:
                for linha in fh:
                    if RE_CHAVE.match(linha):
                        nome = linha.split("=", 1)[0].strip()
                        _PADROES_EXEMPLO[nome] = _valor_da_linha(linha)
        except OSError:
            _PADROES_EXEMPLO["__vazio__"] = ""
    return _PADROES_EXEMPLO.get(chave, "")


def _opcoes(chave, ajuda, inline):
    for linha in (ajuda.splitlines() + [inline]):
        if "|" not in linha:
            continue
        texto = linha.lstrip("#")
        texto = texto.split("(", 1)[0]
        tokens = [t.strip() for t in texto.split("|")]
        if not tokens or any(not RE_TOKEN_OPCAO.match(t) for t in tokens):
            continue
        return tokens
    tabela = _opcoes_da_lista_indentada(ajuda)
    if tabela and _padrao_do_exemplo(chave) not in tabela:
        return []
    return tabela


RE_OPCAO_TABELA = re.compile(r"^#(\s{2,})([a-z][a-z0-9_-]{1,14})\s{2,}\S")


def _opcoes_da_lista_indentada(ajuda):
    melhor = []
    atual = []
    recuo = None
    for linha in ajuda.splitlines():
        m = RE_OPCAO_TABELA.match(linha.rstrip())
        if m and (recuo is None or len(m.group(1)) == recuo):
            recuo = len(m.group(1))
            atual.append(m.group(2))
            continue
        if atual and linha.startswith("#") and recuo and \
                len(linha) > 1 and len(linha[1:]) - len(linha[1:].lstrip()) > recuo:
            continue
        if len(atual) > len(melhor):
            melhor = atual
        atual = []
        recuo = None
    if len(atual) > len(melhor):
        melhor = atual
    return melhor if len(melhor) >= 3 else []


def _e_tabela(chave, ajuda, inline):
    for linha in (ajuda.splitlines() + [inline]):
        if "|" in linha:
            texto = linha.lstrip("#").split("(", 1)[0]
            tokens = [x.strip() for x in texto.split("|")]
            if tokens and all(RE_TOKEN_OPCAO.match(x) for x in tokens if x):
                return False
    return bool(_opcoes_da_lista_indentada(ajuda))


FONTES_DO_DISCO = (
    (re.compile(r"packs/\w+/mascote/"), "gatos", False),
    (re.compile(r"[íi]cones?\b", re.I), "temas_icones", True),
    (re.compile(r"ponteiro|cursor", re.I), "cursores", True),
)

RE_HERDA = re.compile(r"herda\s+([A-Z][A-Z0-9_]{2,})")


def _disco_detalhe(ajuda, inline, padrao):
    texto = ajuda + "\n" + inline
    for gatilho, provedor, cerca in FONTES_DO_DISCO:
        if not gatilho.search(texto):
            continue
        lista = PROVEDORES[provedor]()
        if padrao and padrao in lista:
            return (lista, cerca)
    alvo = RE_HERDA.search(texto)
    if not padrao and alvo:
        padrao_alvo = _padrao_do_exemplo(alvo.group(1))
        if padrao_alvo:
            for _gatilho, provedor, cerca in FONTES_DO_DISCO:
                lista = PROVEDORES[provedor]()
                if padrao_alvo in lista:
                    return (lista, cerca)
    return ([], False)


def _opcoes_do_disco(ajuda, inline, padrao):
    return _disco_detalhe(ajuda, inline, padrao)[0]


def _opcoes_finais(chave, ajuda, inline, padrao, herdada=False):
    do_disco = _opcoes_do_disco(ajuda, inline, padrao)
    if do_disco:
        return do_disco
    opcoes = [o for o in _opcoes(chave, ajuda, inline) if o != "vazio"]
    if opcoes and (padrao or "") not in opcoes and _e_tabela(chave, ajuda, inline):
        return []
    if not opcoes and padrao in ("sim", "nao"):
        return ["sim", "nao"]
    return opcoes


RE_DURACAO = re.compile(r"^\d+(?:[.,]\d+)?[smhd]$")


DOMINIOS = {
    "LOGO_ROTACAO": {
        "chave": "LOGO_MODO",
        "quando": lambda v: bool(v) and v != "rotacao",
        "porque": "Ela só liga a rotação quando o mascote é escolhido girando — "
                  "hoje não tem efeito nenhum.",
    },
    "LOGO": {
        "chave": "LOGO_MODO",
        "quando": lambda v: v == "hora",
        "porque": "Por horário quem escolhe são os mascotes de dia e de noite; "
                  "esta só entra quando um daqueles dois não está na lista.",
    },
    "FORMA_MARGEM_PAINEL": {
        "chave": "FORMA_PAINEL_SOLTO",
        "quando": lambda v: v == "nao",
        "porque": "A margem só é desenhada quando o painel está solto da "
                  "borda: assim, o compositor descarta este número calado.",
    },
    "FORMA_MARGEM_DOCK": {
        "chave": "FORMA_DOCK_SOLTO",
        "quando": lambda v: v == "nao",
        "porque": "A margem só é desenhada quando a dock está solta da "
                  "borda: assim, o compositor descarta este número calado.",
    },
    "FASTFETCH_LOGO_GATO": {
        "chave": "FASTFETCH_LOGO_MODO",
        "quando": lambda v: bool(v) and v != "fixo",
        "porque": "Ela só vale com a escolha em \u201cfixo\u201d. Em "
                  "\u201chora\u201d o terminal segue o mascote do dock; em "
                  "\u201cespelho\u201d ele mostra o OUTRO.",
    },
    "CURSOR_VERSAO": {
        "chave": "CURSOR",
        "quando": lambda v: _ponteiro_vem_do_pack(v),
        "porque": "O ponteiro escolhido vem do pack no ar, que fixa a origem "
                  "dele: esta versão só vale para o ponteiro que o MeowSystem "
                  "baixa pelo nome.",
    },
}


def _valor_vivo(chave):
    return (valores_brutos() or {}).get(chave, "")


COSMIC_DIR = os.environ.get("MEOW_COSMIC_DIR") or os.path.expanduser("~/.config/cosmic")
CONF_COMP = os.path.join(COSMIC_DIR, "com.system76.CosmicComp", "v1")

_BARRAS = (("PAINEL", "com.system76.CosmicPanel.Panel/v1/"),
           ("DOCK", "com.system76.CosmicPanel.Dock/v1/"))
_DEGRAU = r"(XS|S|M|L|XL)"


def _cosmic_ler(relativo):
    try:
        with open(os.path.join(COSMIC_DIR, relativo), encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return None


def _sim_nao(bruto, invertido=False):
    if bruto not in ("true", "false"):
        return None
    return "sim" if (bruto == "true") != invertido else "nao"


def _numero_cru(bruto):
    return bruto if re.match(r"^-?\d+(\.\d+)?$", bruto) else None


def _degrau_proprio(bruto):
    m = re.match(r"^Some\(%s\)$" % _DEGRAU, bruto)
    return m.group(1) if m else None


def _ala(qual):
    forma = r"^Some\(\((None|Some\(%s\)),\s*(None|Some\(%s\))\)\)$" % (_DEGRAU, _DEGRAU)

    def ler(bruto):
        m = re.match(forma, bruto)
        return (m.group(2) if qual == 0 else m.group(4)) if m else None
    return ler


NA_MAQUINA = {
    "RELOGIO_SEGUNDOS": ("com.system76.CosmicAppletTime/v1/show_seconds", _sim_nao),
    "JANELAS_TILING": ("com.system76.CosmicComp/v1/autotile", _sim_nao),
    "JANELAS_TILING_ESCOPO": ("com.system76.CosmicComp/v1/autotile_behavior",
                              {"Global": "global", "PerWorkspace": "workspace"}.get),
}
for _suf, _pasta in _BARRAS:
    NA_MAQUINA.update({
        "FORMA_%s_SOLTO" % _suf: (_pasta + "anchor_gap", _sim_nao),
        "FORMA_%s_ILHA" % _suf: (_pasta + "expand_to_edges",
                                 lambda bruto: _sim_nao(bruto, invertido=True)),
        "FORMA_MARGEM_" + _suf: (_pasta + "margin", _numero_cru),
        "FORMA_RAIO_" + _suf: (_pasta + "border_radius", _numero_cru),
        "FORMA_ESPACO_" + _suf: (_pasta + "spacing", _numero_cru),
        "FORMA_RECHEIO_" + _suf: (_pasta + "padding", _numero_cru),
        "FORMA_CENTRO_" + _suf: (_pasta + "size_center", _degrau_proprio),
        "FORMA_ALA_INICIAL_" + _suf: (_pasta + "size_wings", _ala(0)),
        "FORMA_ALA_FINAL_" + _suf: (_pasta + "size_wings", _ala(1)),
        "VIDRO_OPACIDADE_" + _suf: (_pasta + "opacity", _numero_cru),
    })


_LEITURA_ZERO_DESLIGA = ("LEITURA_TEMPERATURA", "LEITURA_TEXTURA")


def _leitura_desligada(chave, valor):
    if chave not in _LEITURA_ZERO_DESLIGA:
        return False
    try:
        return float(valor.strip()) == 0
    except ValueError:
        return False


_LEITURA_NO_APPLET = {
    "LEITURA_TEMPERATURA": ("estado", "ultima_temperatura"),
    "LEITURA_TEXTURA": ("estado", "ultima_textura"),
    "LEITURA_AGENDA": ("cosmic", "com.system76.CosmicComp/v1/leitura_agenda"),
    "LEITURA_HORARIO_INICIO": ("cosmic", "com.system76.CosmicComp/v1/leitura_hora_inicio"),
    "LEITURA_HORARIO_FIM": ("cosmic", "com.system76.CosmicComp/v1/leitura_hora_fim"),
}


def _leitura_no_applet(chave):
    onde = _LEITURA_NO_APPLET.get(chave)
    if not onde:
        return None
    tipo, nome = onde
    if tipo == "estado":
        base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
        try:
            with open(os.path.join(base, "cosmic", "com.meowsystem.AppletLeitura", "v1", nome),
                      encoding="utf-8") as fh:
                bruto = fh.read().strip()
        except OSError:
            return None
    else:
        bruto = (_cosmic_ler(nome) or "").strip().strip('"')
    if chave == "LEITURA_TEMPERATURA":
        return bruto if bruto.isdigit() and 1000 <= int(bruto) <= 6500 else None
    if chave == "LEITURA_TEXTURA":
        try:
            return bruto if 0 <= float(bruto) <= 1 and re.fullmatch(r"[\d.]+", bruto) else None
        except ValueError:
            return None
    if chave == "LEITURA_AGENDA":
        return {"true": "sim", "false": "nao", "Some(true)": "sim", "Some(false)": "nao"}.get(bruto)
    m = re.fullmatch(r"([01]?\d|2[0-3]):([0-5]\d)", bruto)
    return "%02d:%s" % (int(m.group(1)), m.group(2)) if m else None


def _valendo_agora(chave):
    if chave == "LOGO_MODO":
        return _modo_do_gato() or None
    if chave.startswith("LEITURA_"):
        return _leitura_no_applet(chave)
    if chave == "AREAS_NOMES":
        return ", ".join(_areas_alfinetadas()) or None
    if chave == "VIDRO_AO_MAXIMIZAR":
        lidos = {_sim_nao(_cosmic_ler(pasta + "keep_style_on_maximize") or "")
                 for _suf, pasta in _BARRAS}
        return lidos.pop() if len(lidos) == 1 else None
    regra = NA_MAQUINA.get(chave)
    if not regra:
        return None
    arquivo, traduzir = regra
    bruto = _cosmic_ler(arquivo)
    return traduzir(bruto) if bruto else None


def _noite_do_applet():
    pontas = []
    for chave in ("leitura_hora_inicio", "leitura_hora_fim"):
        bruto = (_cosmic_ler("com.system76.CosmicComp/v1/" + chave) or "").strip().strip('"')
        if not re.fullmatch(r"([01]?\d|2[0-3]):[0-5]\d", bruto):
            return None
        h, m = bruto.split(":")
        pontas.append("%02d:%s" % (int(h), m))
    return {"ini": pontas[0], "fim": pontas[1]}


def _titulo_de(chave):
    try:
        with open(CONF_PADRAO, encoding="utf-8") as fh:
            titulo = ""
            for linha in fh:
                if linha.startswith("# @ "):
                    titulo = linha[4:].strip()
                elif linha.startswith(chave + "="):
                    return titulo or chave
                elif not linha.strip():
                    titulo = titulo
    except OSError:
        pass
    return chave


_PACK_MOD = None


def modulo_pack():
    global _PACK_MOD
    if _PACK_MOD is None:
        import importlib.util
        alvo = os.path.join(RAIZ, "scripts", "pack.py")
        try:
            spec = importlib.util.spec_from_file_location("meow_pack", alvo)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            _PACK_MOD = mod
        except Exception:
            _PACK_MOD = False
    return _PACK_MOD or None


def _packs_no_disco():
    achados = set()
    mod = modulo_pack()
    if not mod:
        return achados
    for base in mod.raizes():
        if not base or not os.path.isdir(base):
            continue
        for nome in os.listdir(base):
            if os.path.isfile(os.path.join(base, nome, "pack.json")) \
                    and not (hasattr(mod, "eh_base") and mod.eh_base(os.path.join(base, nome))):
                achados.add(nome)
    return achados


def _pack_no_ar():
    _ponte_em_dia()
    dir_pack = os.environ.get("MEOW_PACK_DIR") or ""
    if dir_pack:
        return os.path.basename(dir_pack.rstrip("/"))
    mod = modulo_pack()
    return mod.PACK_PADRAO if mod else ""


def _flavor_do_conf(valores):
    flavor = valores.get("FLAVOR") or ""
    if flavor:
        return flavor
    mod = modulo_pack()
    no_ar = _pack_no_ar()
    return str((mod.campo(no_ar, "paleta.flavor_padrao") if mod and no_ar else "") or "mocha")


def vocabulario_do_pack():
    mod = modulo_pack()
    ident = _pack_no_ar()
    if not mod or not ident:
        return None
    try:
        return mod.vocabulario(ident)
    except Exception:
        return None


def _remocao_do_cartao(mod, ident, conf):
    try:
        casa, motivo = mod.remocao(ident, conf.get("PACK") or "", conf.get("FLAVOR") or "")
    except Exception:
        return None
    if not casa:
        return None
    return {"pode": not motivo, "motivo": motivo or ""}


def _packs_removiveis():
    mod = modulo_pack()
    if not mod:
        return []
    conf = valores_efetivos(["PACK", "FLAVOR"])
    return [i for i in sorted(_packs_no_disco())
            if (_remocao_do_cartao(mod, i, conf) or {}).get("pode")]


def packs_com_vitrine():
    mod = modulo_pack()
    if not mod:
        return []
    no_ar = _pack_no_ar()
    conf = valores_efetivos(["PACK", "FLAVOR"])
    saida = []
    for ident in sorted(_packs_no_disco()):
        try:
            p, dados, dir_pack = mod.validar(ident, silencioso=True)
        except Exception as erro:
            saida.append({"id": ident, "nome": ident, "problemas": [str(erro)],
                          "no_ar": ident == no_ar, "valido": False,
                          "remover": _remocao_do_cartao(mod, ident, conf)})
            continue
        vit, problemas = mod.vitrine(p, dir_pack)
        try:
            vocab = mod.vocabulario(ident)
        except Exception:
            vocab = {"flavors": [], "categorias": []}
        flavor = (p.get("paleta") or {}).get("flavor_padrao") or next(iter(dados["flavors"]))
        if vit["capa"]:
            try:
                mod.logo(ident, flavor)
            except Exception as erro:
                problemas.append(str(erro))
                vit["capa"] = None
        texto = ""
        if vit["descricao"]:
            try:
                with open(vit["descricao"], encoding="utf-8", errors="replace") as fh:
                    texto = fh.read()
            except OSError:
                texto = ""
        cores = dados["flavors"].get(flavor) or {}
        base_url = "/pack-vitrine?id=" + quote(ident, safe="")
        saida.append({
            "id": ident,
            "nome": p.get("nome") or ident,
            "autor": p.get("autor") or "",
            "capa": (base_url + "&arte=capa") if vit["capa"] else "",
            "mascote": (base_url + "&arte=mascote") if _mascote_do_pack(mod, ident) else "",
            "descricao_curta": vit["descricao_curta"],
            "descricao": texto,
            "tags": vit["tags"],
            "capturas": [base_url + "&arte=%d" % i for i in range(len(vit["capturas"]))],
            "site": vit["site"] or "",
            "origem": mod.resumo_de_origem(p),
            "claros_derivados": [{"flavor": c, "de": e}
                                 for c, e in mod.claros_derivados(dados).items()],
            "amostra": [cores[s] for s in mod.SLOTS if s in cores],
            "problemas": problemas,
            "no_ar": ident == no_ar,
            "valido": True,
            "flavors": vocab["flavors"],
            "categorias": vocab["categorias"],
            "remover": _remocao_do_cartao(mod, ident, conf),
        })
    return saida


def _mascote_do_pack(mod, ident):
    try:
        pasta = os.path.realpath(mod.pasta_do_mascote(ident))
        nome = mod.mascote_padrao("dia", ident)
    except Exception:
        return ""
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", nome or ""):
        return ""
    alvo = os.path.realpath(os.path.join(pasta, nome + ".svg"))
    return alvo if os.path.dirname(alvo) == pasta and os.path.isfile(alvo) else ""


def arte_da_vitrine(ident, arte):
    mod = modulo_pack()
    if not mod or ident not in _packs_no_disco():
        return None
    try:
        p, dados, dir_pack = mod.validar(ident, silencioso=True)
    except Exception:
        return None
    vit, _problemas = mod.vitrine(p, dir_pack)
    if arte == "capa":
        if not vit["capa"]:
            return None
        flavor = (p.get("paleta") or {}).get("flavor_padrao") or next(iter(dados["flavors"]))
        try:
            return mod.logo(ident, flavor).encode("utf-8"), "image/svg+xml"
        except Exception:
            return None
    elif arte == "mascote":
        alvo = _mascote_do_pack(mod, ident)
    elif re.fullmatch(r"[0-9]+", arte or "") and int(arte) < len(vit["capturas"]):
        alvo = vit["capturas"][int(arte)]
    else:
        return None
    if not alvo:
        return None
    tipo = {".svg": "image/svg+xml", ".png": "image/png", ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg"}.get(os.path.splitext(alvo)[1].lower())
    try:
        with open(alvo, "rb") as fh:
            return fh.read(), tipo
    except OSError:
        return None


_PAPIRUS_FOLDERS = os.environ.get("MEOW_CAT_FOLDERS") or os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
    "meowsystem", "upstream", "papirus-folders")
_RE_COR_DE_PASTA = re.compile(r"^folder-cat-([a-z0-9]+)-([a-z0-9]+)-documents\.svg$")


def _cores_de_pasta():
    achadas = {}
    try:
        nomes = os.listdir(os.path.join(_PAPIRUS_FOLDERS, "src", "64x64", "places"))
    except OSError:
        return achadas
    for nome in nomes:
        m = _RE_COR_DE_PASTA.match(nome)
        if m:
            achadas.setdefault(m.group(1), set()).add(m.group(2))
    return achadas


_NOME_DO_TEMA_TRAVA = threading.Lock()


def _com_o_vocabulario_do_pack(esquema, vocab, efetivos):
    if not vocab:
        return
    por_chave = {i["chave"]: i for i in esquema}
    nome_pack = vocab["nome"]

    item = por_chave.get("ICONES_FLAVOR")
    mt = vocab.get("mimetypes")
    if item and mt:
        herdado = (" (herdado do %s)" % mt["nome_de"]) if mt["herdado"] else ""
        oferta = [o for o in item["opcoes"] if o in mt["flavors"]]
        oferta += [f for f in mt["flavors"] if f not in oferta]
        agora = item.get("valor") or ""
        if agora and "$" not in agora and agora not in oferta:
            oferta.append(agora)
        item["opcoes"] = oferta
        item["rotulos"] = {f: (mt["nomes"].get(f) or f[:1].upper() + f[1:]) + herdado
                           for f in oferta}
        try:
            item["efetivo"] = modulo_pack().flavor_de_icones(
                vocab["id"], efetivos.get("ICONES_FLAVOR"), efetivos.get("FLAVOR"))
        except Exception:
            pass

    item = por_chave.get("ICONES_DRACULA")
    if item:
        item["titulo"] = "Ícones do pack nos aplicativos"
        ap = vocab.get("apps")
        if ap and ap["herdado"]:
            item["frase"] = ("Os desenhos de aplicativo que o pack «%s» herda do «%s», "
                             "vestindo o lançador." % (nome_pack, ap["nome_de"]))
        elif ap:
            item["frase"] = ("Os desenhos de aplicativo do pack «%s», vestindo o lançador."
                             % nome_pack)
        else:
            item["frase"] = ("O pack «%s» não traz desenhos de aplicativo: com ele no ar, "
                             "este ajuste não tem o que vestir." % nome_pack)

    item = por_chave.get("ICONES_PASTAS")
    if item:
        cores_de = _cores_de_pasta()
        nomes = {f["id"]: f["nome"] for f in vocab["flavors"]}
        mod = modulo_pack()
        ibase = mod.SLOTS.index("base") if mod else 0
        luz = (lambda f: mod._luminancia(f["cores"][ibase])) if mod else (lambda f: 0.0)
        variantes = [{"valor": "${FLAVOR}", "rotulo": "Acompanha o tema"}]
        if cores_de:
            variantes += [{"valor": f["id"], "rotulo": f["nome"]}
                          for f in sorted(vocab["flavors"], key=luz)]
        todas = set().union(*cores_de.values()) if cores_de else set()
        ordem = [s for s in (_paleta_dados().get("ordem_canonica") or [])[:14]]
        achado = re.match(r"^cat-(.+)-([^-]+)$", efetivos.get("ICONES_PASTAS") or "")
        fl_pastas = achado.group(1) if achado else (efetivos.get("FLAVOR") or "")
        do_fl = next((f for f in vocab["flavors"] if f["id"] == fl_pastas), None)
        nome_da_cor = (_nomes_de_cor(dict(zip(mod.SLOTS[:14], do_fl["cores"])))
                       if do_fl and mod else {})
        cores = [{"valor": "${ACCENT}", "rotulo": "Acompanha o destaque"}]
        cores += [{"valor": c, "rotulo": (nome_da_cor[c][:1].upper() + nome_da_cor[c][1:])
                                         if nome_da_cor.get(c) else c.capitalize()}
                  for c in ordem if (c in todas or not todas)]
        flavor_no_ar = efetivos.get("FLAVOR") or ""
        item["frase"] = ("A variante e a cor das pastas comuns. «Acompanha» repinta "
                         "sozinho quando o tema ou o destaque mudam.")
        item["molde_pastas"] = {
            "variantes": variantes,
            "cores": cores,
            "sem_upstream": not cores_de,
            "fora_do_papirus": (nomes.get(flavor_no_ar) or flavor_no_ar)
                               if cores_de and flavor_no_ar not in cores_de
                               and flavor_no_ar not in nomes else "",
        }

    item = por_chave.get("FLAVOR")
    mod = modulo_pack()
    if item and mod and vocab["flavors"]:
        ibase = mod.SLOTS.index("base")
        flavors = sorted(vocab["flavors"], key=lambda f: mod._luminancia(f["cores"][ibase]))
        oferta = [f["id"] for f in flavors]
        agora = item.get("valor") or ""
        if agora and "$" not in agora and agora not in oferta:
            oferta.append(agora)
        item["opcoes"] = oferta
        item["rotulos"] = {f["id"]: f["nome"] + (" (derivado)" if f.get("derivado") else "")
                           for f in flavors}
        item["frase"] = ("As variantes do pack «%s», do escuro ao claro. Vale com "
                         "qualquer cor de destaque." % nome_pack)
        item["previa"] = _tipo_de_previa(item["chave"], oferta, item.get("faixa"),
                                         item.get("padrao"))

    item = por_chave.get("PACK")
    if item and mod:
        oferta = sorted(_packs_no_disco())
        agora = item.get("valor") or ""
        if agora and "$" not in agora and agora not in oferta:
            oferta.append(agora)
        item["opcoes"] = oferta
        item["rotulos"] = {i: (mod.campo(i, "nome") or i) for i in oferta}

    item = por_chave.get("TERMINAL_CURSOR")
    if item:
        item["frase"] = "A cor de destaque, ou a que o tema «%s» escolhe." % nome_pack
        item["rotulos"] = {"accent": "Cor de destaque", "port": "Do tema «%s»" % nome_pack}

    item = por_chave.get("ICONES_BASE") or {}
    if mod:
        with _NOME_DO_TEMA_TRAVA:
            antes = os.environ.get("NOME_TEMA_ICONES")
            os.environ["NOME_TEMA_ICONES"] = efetivos.get("NOME_TEMA_ICONES") or ""
            try:
                quem, tema, decl = mod.base_que_vale(vocab["id"], efetivos.get("ICONES_BASE"))
                nossa = (efetivos.get("NOME_TEMA_ICONES") or "MeowSystem-Icons") + "-Base"
                candidatos = [""] + list(item.get("opcoes") or []) + [item.get("valor") or ""]
                cede = sorted({c for c in candidatos if not mod._base_escolhida(c)})
                _q, tema_cedido, decl_cedida = mod.base_que_vale(vocab["id"], "")
            except Exception:
                quem = None
            finally:
                if antes is None:
                    os.environ.pop("NOME_TEMA_ICONES", None)
                else:
                    os.environ["NOME_TEMA_ICONES"] = antes
        if quem:
            dono = mod.campo(decl_cedida["pack"], "nome") if decl_cedida else ""
            vocab["base_de_icones"] = {"vale": nossa if decl_cedida else tema_cedido,
                                       "de": dono or "", "cede": cede}
        if quem == "pack":
            dono = mod.campo(decl["pack"], "nome") or decl["pack"]
            item["efetivo"] = nossa
            item["rotulos"] = dict(item.get("rotulos") or {},
                                   **{nossa: "%s, a base do pack «%s»" % (nossa, dono)})

    if mod:
        ibase = mod.SLOTS.index("base")
        for f in vocab["flavors"]:
            f["nomes_de_cor"] = dict(_nomes_de_cor(dict(zip(mod.SLOTS[:14], f["cores"]))),
                                     **_NOMES_DAS_NEUTRAS)
            f["luz"] = round(mod._luminancia(f["cores"][ibase]), 4)

    it_flavor = por_chave.get("ICONES_FLAVOR")
    if vocab.get("mimetypes") and it_flavor and it_flavor.get("efetivo"):
        vocab["mimetypes"]["efetivo"] = it_flavor["efetivo"]


_MATIZES = ((15, "vermelho"), (40, "laranja"), (70, "amarelo"), (160, "verde"),
            (185, "verde-água"), (200, "ciano"), (250, "azul"), (290, "roxo"),
            (335, "rosa"), (361, "vermelho"))
_MAIS_CLARO = ("", " claro", " mais claro")

_NOMES_DAS_NEUTRAS = {
    "text": "texto", "subtext1": "texto secundário 1", "subtext0": "texto secundário 0",
    "overlay2": "sobreposição 2", "overlay1": "sobreposição 1", "overlay0": "sobreposição 0",
    "surface2": "superfície 2", "surface1": "superfície 1", "surface0": "superfície 0",
    "base": "fundo", "mantle": "fundo secundário", "crust": "fundo terciário",
}


def _nomes_de_cor(cores):
    import colorsys
    faixas = {}
    for slot, hexcor in cores.items():
        try:
            r, g, b = (int(hexcor[i:i + 2], 16) / 255 for i in (1, 3, 5))
        except (TypeError, ValueError):
            continue
        h, luz, sat = colorsys.rgb_to_hls(r, g, b)
        if luz >= 0.9:
            nome = "quase branco"
        elif sat < 0.2:
            nome = "cinza"
        else:
            nome = next(n for teto, n in _MATIZES if h * 360 < teto)
            if nome == "vermelho" and luz >= 0.8:
                nome = "rosa"
        faixas.setdefault(nome, []).append((luz, slot))
    saida = {}
    for nome, lista in faixas.items():
        for i, (_luz, slot) in enumerate(sorted(lista)):
            saida[slot] = nome + (_MAIS_CLARO[i] if i < len(_MAIS_CLARO) else " %d" % (i + 1))
    return saida


def _flavors_dos_packs():
    mod = modulo_pack()
    saida = []
    if not mod:
        return saida
    for ident in sorted(_packs_no_disco()):
        try:
            _p, dados, _d = mod.validar(ident, silencioso=True)
        except Exception:
            continue
        saida += [f for f in dados["flavors"] if f not in saida]
    return saida


def _vestigio_de_pack(chave):
    valor = (valores_brutos() or {}).get(chave, "")
    if not valor:
        return None
    packs = _packs_no_disco()
    if not packs:
        return None
    vals = valores_efetivos(["PACK", "FLAVOR"])
    adotado = (vals.get("PACK") or vals.get("FLAVOR") or "").strip().lower()
    if adotado and adotado not in packs:
        mod = modulo_pack()
        dir_sabor = _pack_do_sabor(mod, adotado) if mod else None
        if dir_sabor:
            adotado = os.path.basename(dir_sabor.rstrip("/")).lower()
    alvo = valor.strip().lower()
    for pack in packs:
        if pack == adotado:
            continue
        mod_p = modulo_pack()
        apelidos = [a for a, d in (getattr(mod_p, "APELIDOS", {}) or {}).items() if d == pack]
        nomes = apelidos if pack == getattr(mod_p, "PACK_BASE", "meowsystem") else [pack] + apelidos
        if any(n in alvo for n in nomes):
            if _declarado_pelo_pack(adotado, alvo):
                return None
            return {"pack": pack, "adotado": adotado or "(o padrão)",
                    "porque": ("Este valor é do pack «%s», e o adotado agora é «%s». "
                               "Ele continua valendo — o seu meow.conf vence o pack —, "
                               "mas o resultado na tela fica misturado." % (pack, adotado or "o padrão"))}
    return None


def _pack_do_sabor(mod, sabor):
    alvo = (sabor or "").strip().lower()
    if not alvo:
        return None
    for raiz in (mod.raizes() if hasattr(mod, "raizes") else []):
        try:
            nomes = sorted(os.listdir(raiz))
        except OSError:
            continue
        for nome in nomes:
            d = os.path.join(raiz, nome)
            pj = os.path.join(d, "pack.json")
            if not os.path.isfile(pj):
                continue
            try:
                with open(pj, encoding="utf-8") as fh:
                    no = json.load(fh)
                arq = (no.get("paleta") or {}).get("arquivo") or "paleta.json"
                with open(os.path.join(d, arq), encoding="utf-8") as fh:
                    pal = json.load(fh)
            except (OSError, ValueError):
                continue
            if alvo in {f.lower() for f in (pal.get("flavors") or {})}:
                return d
    return None


def _declarado_pelo_pack(adotado, alvo):
    mod = modulo_pack()
    if not mod or not adotado:
        return False
    dir_pack = mod.achar(adotado)
    if not dir_pack:
        return False
    try:
        with open(os.path.join(dir_pack, "pack.json"), encoding="utf-8") as fh:
            no = json.load(fh)
    except (OSError, ValueError):
        return False
    pilha = [no]
    while pilha:
        atual = pilha.pop()
        if isinstance(atual, dict):
            pilha.extend(v for k, v in atual.items() if not k.startswith("_"))
        elif isinstance(atual, list):
            pilha.extend(atual)
        elif isinstance(atual, str) and atual.strip().lower() == alvo:
            return True
    return False


def _mapa_de_escolhas_do_usuario():
    mod = modulo_pack()
    if mod and hasattr(mod, "arquivo_de_escolhas"):
        return mod.arquivo_de_escolhas()
    return os.path.join(os.path.dirname(CONF), "icones-escolhidos.map")


def _mapa_de_traco_do_usuario():
    return (os.environ.get("MEOW_ICONES_TRACO")
            or os.path.join(os.path.dirname(CONF), "icones-traco.map"))


def _mapa_de_convertidos_do_usuario():
    return (os.environ.get("MEOW_ICONES_CONVERTIDOS")
            or os.path.join(os.path.dirname(CONF), "icones-convertidos.map"))


def _oficina_do_usuario(*partes):
    xdg = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    return os.path.join(xdg, "meowsystem", *partes)


def _gravar_escolha(caminho, chave, linha, separador):
    try:
        with open(caminho, "r", encoding="utf-8") as fh:
            linhas = fh.read().split("\n")
    except FileNotFoundError:
        linhas = []
    if linhas and linhas[-1] == "":
        linhas.pop()

    def da_chave(l):
        util = l.split("#", 1)[0]
        return util.split(separador, 1)[0].strip() == chave and separador in util

    havia = any(da_chave(l) for l in linhas)
    linhas = [l for l in linhas if not da_chave(l)]
    if linha is not None:
        linhas.append(linha)
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    tmp = caminho + ".meow-tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write("\n".join(linhas) + ("\n" if linhas else ""))
    os.replace(tmp, caminho)
    return havia


@_uma_vez_por_leitura
def _pack_adotado():
    mod = modulo_pack()
    if not mod:
        return ""
    vals = valores_efetivos(["PACK", "FLAVOR"])
    return mod.adocao(vals.get("PACK") or "", vals.get("FLAVOR") or "")[0]


def _enumerar(itens):
    itens = [i for i in itens if i]
    if len(itens) <= 1:
        return "".join(itens)
    return ", ".join(itens[:-1]) + " e " + itens[-1]


def _dominada_por(chave):
    regra = DOMINIOS.get(chave)
    if not regra:
        return None
    valor = _valor_vivo(regra["chave"])
    if not regra["quando"](valor):
        return None
    return {"chave": regra["chave"], "titulo": _titulo_de(regra["chave"]),
            "valor": valor, "porque": regra["porque"]}


def _opcoes_fechadas(chave, ajuda, inline, padrao):
    lista, cerca = _disco_detalhe(ajuda, inline, padrao)
    if lista:
        return lista if cerca else []
    opcoes = _opcoes_finais(chave, ajuda, inline, padrao)

    if opcoes and all(RE_DURACAO.match(o) for o in opcoes):
        return []
    return opcoes


FORMAS_NUMERO = (
    ("inteiro", re.compile(r"^\d+$"), "um número inteiro (0, 12, 40)"),
    ("decimal", re.compile(r"^\d*[.,]\d+$"), "um número com ponto decimal (0.85)"),
    ("duracao", re.compile(r"^\d+[smhd]$"), "uma duração: número + s/m/h/d (30m, 1d)"),
)
RE_HORARIO_VALOR = re.compile(r"^([01]?\d|2[0-3]):[0-5]\d$")


def _forma_de_numero(padrao):
    for nome, forma, _explica in FORMAS_NUMERO:
        if forma.match(padrao or ""):
            return nome
    return ""


def _vazio_vale(inline):
    m = re.search(r"\(vazio\s*=\s*(-?\d+(?:\.\d+)?)\s*\)", inline or "")
    return m.group(1) if m else None


def _faixa(ajuda, inline):
    paragrafos = _paragrafos(ajuda)
    candidatos = [inline]
    if paragrafos:
        candidatos.append(paragrafos[-1])
        candidatos.append(paragrafos[0])
    for linha in candidatos:
        achado = RE_FAIXA.search(linha or "")
        if not achado:
            continue
        a, b = achado.group(1).replace(",", "."), achado.group(2).replace(",", ".")
        try:
            lo, hi = float(a), float(b)
        except ValueError:
            continue
        if hi <= lo:
            continue
        fracionario = "." in a or "." in b
        if not fracionario and hi - lo < 10:
            continue
        passo = 0.01 if fracionario else 1
        return (lo, hi, passo)
    return None


_PALAVRAS_COM_FAIXA = ("auto",)


def _faixa_confere(faixa, padrao):
    if faixa is None:
        return None
    if padrao == "":
        return faixa
    try:
        valor = float(padrao.replace(",", "."))
    except ValueError:
        return faixa if padrao in _PALAVRAS_COM_FAIXA else None
    return faixa if faixa[0] <= valor <= faixa[1] else None


def _e_titulo(linha):
    limpa = re.sub(r"\([^)]*\)", "", linha)
    letras = [c for c in limpa if c.isalpha()]
    if not letras:
        return False
    return sum(1 for c in letras if c.isupper()) / len(letras) > 0.7


def _paragrafos(ajuda):
    saida, atual = [], []
    for bruta in ajuda.splitlines():
        linha = bruta.lstrip("#").rstrip()
        if not linha.strip() or set(linha.strip()) <= {"-", "="}:
            if atual:
                saida.append(" ".join(atual))
                atual = []
            continue
        atual.append(linha.strip())
    if atual:
        saida.append(" ".join(atual))
    return saida


def _so_com_app(ajuda):
    m = re.search(r"\[so-com-app ([^\]]+)\]", ajuda or "")
    return m.group(1).split() if m else []


def _frase_curta(ajuda, inline):
    limpas = []
    for l in ajuda.splitlines():
        if not _e_linha_de_opcoes(l):
            limpas.append(l)
            continue
        aparte = re.search(r"\(([^)]*)\)", l)
        if aparte and len(aparte.group(1)) > 8:
            limpas.append("# " + aparte.group(1).strip())
    for paragrafo in _paragrafos("\n".join(limpas)):
        texto = paragrafo.replace("[essencial]", "").strip()
        if not texto or len(texto) < 12:
            continue
        primeira = re.split(r"(?<=[.:!?])\s", texto, 1)[0]
        if _e_titulo(primeira) and len(primeira) > 20:
            resto = texto[len(primeira):].strip()
            if len(resto) < 12:
                continue
            texto = resto
        if len(texto) <= 200:
            return texto
        corte = texto.rfind(". ", 0, 200)
        return texto[:corte + 1] if corte > 90 else texto[:197].rstrip() + "…"
    return "" if _e_linha_de_opcoes(inline) else inline


def _capturas_no_disco():
    mod = modulo_pack()
    if mod is not None:
        try:
            return mod.capturas()
        except Exception:
            pass
    pasta = os.path.join(RAIZ, "assets", "temas", "capturados")
    try:
        return sorted(n for n in os.listdir(pasta)
                      if os.path.isdir(os.path.join(pasta, n)))
    except OSError:
        return []


@_numa_leitura
def ler_esquema():
    itens = []
    vistas = {}
    bloco = []
    secao = ""
    subsecao = ""
    colada = False
    try:
        with open(CONF_PADRAO, "r", encoding="utf-8") as fh:
            linhas = fh.read().splitlines()
    except OSError:
        return []

    for linha in linhas:
        if linha.startswith("# --- "):
            nome = linha[len("# --- "):].split("-", 1)[0].strip()
            colada = False
            if nome:
                if _e_titulo(nome):
                    subsecao = nome
                else:
                    secao = nome
                    subsecao = ""
            bloco = []
            continue
        if linha.startswith("#"):
            bloco.append(linha)
            continue
        if not linha.strip():
            bloco = []
            colada = False
            continue
        achado = RE_CHAVE.match(linha)
        if not achado:
            bloco = []
            colada = False
            continue
        chave = achado.group(1)

        titulo_escrito = frase_escrita = ""
        resto = []
        for l in bloco:
            if l.startswith("# @ "):
                titulo_escrito = l[4:].strip()
            elif l.startswith("# > "):
                frase_escrita = l[4:].strip()
            else:
                resto.append(l)
        bloco = resto
        ajuda = "\n".join(bloco)
        inline = _comentario_da_linha(linha)

        herdada = False
        ajuda_de = ""
        if not bloco and colada and itens:
            ajuda = itens[-1]["ajuda"]
            herdada = True
            ajuda_de = itens[-1]["ajuda_de"] or itens[-1]["chave"]
        colada = True
        item = {
            "chave": chave,
            "secao": secao,
            "subsecao": subsecao,
            "ajuda": ajuda,
            "inline": inline,
            "titulo": titulo_escrito,
            "frase": frase_escrita or _frase_curta(ajuda, inline),
            "padrao": _valor_da_linha(linha),
            "padrao_do_pack": _padrao_do_pack(chave),
            "opcoes": _opcoes_finais(chave, ajuda, inline, _valor_da_linha(linha), herdada),
            "faixa": _faixa_confere(_faixa(ajuda, inline), _valor_da_linha(linha)),
            "vazio_vale": _vazio_vale(inline),
            "hora_cheia": bool(re.search(r"\bhora cheia\b", inline or "")),
            "tipo_numero": _forma_de_numero(_valor_da_linha(linha)),
            "previa": _tipo_de_previa(
                chave,
                _opcoes_finais(chave, ajuda, inline, _valor_da_linha(linha), herdada),
                _faixa_confere(_faixa(ajuda, inline), _valor_da_linha(linha)),
                _valor_da_linha(linha)),
            "dominada_por": _dominada_por(chave),
            "vestigio_de_pack": _vestigio_de_pack(chave),
            "valendo_agora": _valendo_agora(chave),
            "desligado_agora": chave in _LEITURA_ZERO_DESLIGA and _leitura_desligada(
                chave, (_cosmic_ler("com.system76.CosmicComp/v1/" + chave.lower())
                        or "").strip('"')),
            "ajuda_herdada": herdada,
            "ajuda_de": ajuda_de,
            "essencial": "[essencial]" in ajuda,
            "avancado": "[avancado]" in ajuda,
            "so_com_app": _so_com_app(ajuda),
            "lista": bool(re.search(r"separad[ao]s? por v[ií]rgula|v[ií]rgula[- ]separad", ajuda, re.I)),
            "lista_pathsep": bool(re.search(r"separados por `?:`?", ajuda)),
            "ids_de_desktop": bool(re.search(r"\bIDs? d[oe] `\.desktop`", ajuda)),
            "horario": ("HH:MM" in (ajuda + inline)
                        or bool(re.fullmatch(r"\d{1,2}:\d{2}", _valor_da_linha(linha)))
                        or (_valor_da_linha(linha) == ""
                            and bool(re.search(r"\b\d{1,2}:\d{2}\b",
                                               (_paragrafos(ajuda) or [""])[0])))),
            "aceita_vazio": bool(
                re.search(r"[Vv]azio\s*\(?\s*=|[Vv]azio\s+significa|nascem vazias|nasce vazia"
                          r"|VAZIO\s*=|não toca", ajuda + inline)
                or "vazio" in _opcoes(chave, ajuda, inline)
                or _valor_da_linha(linha) == ""
            ),
        }
        if chave in vistas:
            itens[vistas[chave]] = item
        else:
            vistas[chave] = len(itens)
            itens.append(item)
        bloco = []
    return itens


def _pasta_do_mascote():
    mod = modulo_pack()
    if mod and hasattr(mod, "pasta_do_mascote"):
        return mod.pasta_do_mascote(_pack_adotado() or None)
    return os.path.join(RAIZ, "packs", "meowsystem", "mascote")


def _gatos():
    pasta = _pasta_do_mascote()
    try:
        nomes = sorted(
            os.path.splitext(f)[0] for f in os.listdir(pasta)
            if f.endswith(".svg") and not f.endswith("-symbolic.svg")
        )
    except OSError:
        return []
    return nomes


def _capturas():
    _ponte_em_dia()
    return [n for n in _capturas_no_disco() if n != "original"]


_APLICAM_CACHE = {}


def _acentos_que_aplicam(esquema):
    item = next((i for i in esquema if i.get("chave") == "ACCENT"), None)
    acentos = [str(a) for a in (item or {}).get("opcoes") or []]
    mod = modulo_pack()
    if mod is None:
        return {}
    chave = [os.environ.get("MEOW_PACK_DIR", ""), os.environ.get("MEOW_PALETA", ""),
             ",".join(acentos)]
    try:
        chave.append(os.stat(mod.paleta_do_pack_ativo()).st_mtime_ns)
        for nome in mod.capturas():
            dir_cap = mod.captura(nome) or ""
            chave.append((nome, os.stat(os.path.join(dir_cap, "captura.txt")).st_mtime_ns
                          if os.path.isfile(os.path.join(dir_cap, "captura.txt")) else 0))
    except Exception:
        return {}
    chave = repr(chave)
    if chave not in _APLICAM_CACHE:
        try:
            r = subprocess.run(
                [sys.executable, os.path.join(RAIZ, "scripts", "derivar_acento.py"),
                 "--aplicam", ",".join(acentos)],
                cwd=RAIZ, capture_output=True, text=True, timeout=60)
            resposta = json.loads(r.stdout) if r.returncode == 0 else {}
        except (OSError, ValueError, subprocess.SubprocessError):
            return {}
        _APLICAM_CACHE.clear()
        _APLICAM_CACHE[chave] = resposta
        return resposta
    return _APLICAM_CACHE.get(chave, {})


RAIZES_ICONES = ("~/.local/share/icons", "~/.icons", "/usr/share/icons")

RE_TEMA_PASTAS = re.compile(r"^\s*Directories\s*=\s*\S", re.I)
RE_TEMA_ESCONDIDO = re.compile(r"^\s*Hidden\s*=\s*true\s*$", re.I)


def _dirs_de_icones():
    for raiz in RAIZES_ICONES:
        caminho = os.path.expanduser(raiz)
        try:
            nomes = sorted(os.listdir(caminho))
        except OSError:
            continue
        for nome in nomes:
            completo = os.path.join(caminho, nome)
            if os.path.isdir(completo):
                yield nome, completo


@_uma_vez_por_leitura
def _temas_de_icones():
    nosso = valores_brutos().get("NOME_TEMA_ICONES", "")
    fora = set()
    for nome, caminho in _dirs_de_icones():
        if nome == nosso or nome in fora:
            continue
        try:
            with open(os.path.join(caminho, "index.theme"), "r",
                      encoding="utf-8", errors="replace") as fh:
                linhas = fh.read().splitlines()
        except OSError:
            continue
        if any(RE_TEMA_ESCONDIDO.match(l) for l in linhas):
            continue
        if any(RE_TEMA_PASTAS.match(l) for l in linhas):
            fora.add(nome)
    return sorted(fora)


SUFIXO_CURSOR = "-cursors"


def _cursor_pastas_do_valor(valor, do_pack=None):
    raizes = [os.path.expanduser(raiz) for raiz in RAIZES_ICONES]
    if any(os.path.isdir(os.path.join(raiz, valor)) for raiz in raizes):
        nome = valor
    else:
        nome = valor + SUFIXO_CURSOR
    pastas = [os.path.join(raiz, nome) for raiz in raizes
              if os.path.isdir(os.path.join(raiz, nome, "cursors"))]
    if (do_pack and do_pack.get("valor") == valor and nome == valor + SUFIXO_CURSOR
            and os.path.isdir(os.path.join(do_pack.get("dir") or "", "cursors"))):
        pastas.append(do_pack["dir"])
    return pastas


def _ponteiro_do_pack():
    mod = modulo_pack()
    if not mod or not hasattr(mod, "ponteiro"):
        return None
    try:
        return mod.ponteiro(_pack_adotado() or mod.dir_padrao())
    except Exception:
        return None


_SOM_TIMBRE_DE_FABRICA = {"SOM_FUNDAMENTAL": "880.0", "SOM_HARMONICO": "1320.0",
                          "SOM_PESO_FUNDAMENTAL": "0.62", "SOM_PESO_HARMONICO": "0.28",
                          "SOM_DECAIMENTO": "46.0"}
_SOM_CARIMBO = os.path.join(ESTADO, "som-do-pack")


@_uma_vez_por_leitura
def _som_do_pack_ativo():
    mod = modulo_pack()
    if not mod:
        return "", dict(_SOM_TIMBRE_DE_FABRICA)
    try:
        dir_pack = _pack_adotado() or mod.dir_padrao()
        ident = os.path.basename(dir_pack.rstrip(os.sep))
        return ident, dict(_SOM_TIMBRE_DE_FABRICA, **mod.timbre(ident))
    except Exception:
        return "", dict(_SOM_TIMBRE_DE_FABRICA)


def _som_carimbo_ler(arquivo=None):
    try:
        with open(arquivo or _SOM_CARIMBO, "r", encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return ""


def _som_ajuste_vale():
    ident, _timbre = _som_do_pack_ativo()
    return bool(ident) and _som_carimbo_ler() == ident


def _som_carimbar(pares, pasta=None):
    ident, _timbre = _som_do_pack_ativo()
    if not ident or not any(c in _SOM_TIMBRE_DE_FABRICA for c, _v in pares):
        return pares
    arquivo = os.path.join(pasta, "som-do-pack") if pasta else _SOM_CARIMBO
    if _som_carimbo_ler(arquivo) != ident:
        escritas = {c for c, _v in pares}
        brutos = valores_brutos()
        pares = list(pares) + [(c, "") for c in _SOM_TIMBRE_DE_FABRICA
                               if c not in escritas and brutos.get(c)]
    return pares


def _som_carimbo_gravar(pares, pasta=None):
    ident, _timbre = _som_do_pack_ativo()
    if not ident or not any(c in _SOM_TIMBRE_DE_FABRICA for c, _v in pares):
        return
    arquivo = os.path.join(pasta, "som-do-pack") if pasta else _SOM_CARIMBO
    try:
        os.makedirs(os.path.dirname(arquivo), exist_ok=True)
        with open(arquivo, "w", encoding="utf-8") as fh:
            fh.write(ident + "\n")
    except OSError:
        pass


_RASCUNHO_ARQUIVO = os.path.join(ESTADO, "rascunho-do-tema.json")


def _rascunho_ler():
    try:
        with open(_RASCUNHO_ARQUIVO, encoding="utf-8") as fh:
            dados = json.load(fh)
    except (OSError, ValueError):
        return None
    return dados if isinstance(dados, dict) and isinstance(dados.get("base"), dict) else None


def _rascunho_gravar(dados):
    if dados is None:
        try:
            os.remove(_RASCUNHO_ARQUIVO)
        except FileNotFoundError:
            pass
        except OSError:
            return False
        return True
    if not (isinstance(dados, dict) and isinstance(dados.get("base"), dict)):
        return False
    texto = json.dumps(dados, ensure_ascii=False)
    if len(texto) > (256 << 10):
        return False
    try:
        os.makedirs(ESTADO, exist_ok=True)
        tmp = _RASCUNHO_ARQUIVO + ".parcial"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(texto)
        os.replace(tmp, _RASCUNHO_ARQUIVO)
    except OSError:
        return False
    return True


def _padrao_do_pack(chave):
    if chave in _SOM_TIMBRE_DE_FABRICA:
        return _som_do_pack_ativo()[1][chave]
    if chave != "CURSOR":
        return None
    return (_ponteiro_do_pack() or {}).get("valor") or None


def _ponteiro_vem_do_pack(valor):
    do_pack = _ponteiro_do_pack() if valor else None
    return bool(do_pack) and do_pack.get("valor") == valor


@_uma_vez_por_leitura
def _temas_de_cursor():
    fora = set()
    do_pack = _ponteiro_do_pack()
    if do_pack and _cursor_pastas_do_valor(do_pack["valor"], do_pack):
        fora.add(do_pack["valor"])
    for nome, caminho in _dirs_de_icones():
        if not os.path.isdir(os.path.join(caminho, "cursors")):
            continue
        valor = nome[: -len(SUFIXO_CURSOR)] if nome.endswith(SUFIXO_CURSOR) else nome
        if _cursor_pastas_do_valor(valor, do_pack):
            fora.add(valor)
    return sorted(fora)


def _paredes_ativas():
    base = os.path.join(_wallpaper_base(), "ativos")
    try:
        nomes = sorted(os.listdir(base))
    except OSError:
        return []
    return [os.path.join(base, n) for n in nomes
            if os.path.splitext(n)[1].lower() in EXT_RASTER
            and os.path.isfile(os.path.join(base, n))]


def _paredes_favoritas():
    base = os.path.join(_wallpaper_base(), "favoritos")
    try:
        nomes = sorted(os.listdir(base))
    except OSError:
        return []
    return [n for n in nomes if os.path.splitext(n)[1].lower() in EXT_RASTER
            and os.path.isfile(os.path.join(base, n))]


def _paredes_banidas():
    base = os.path.join(_wallpaper_base(), "banidos")
    try:
        nomes = sorted(os.listdir(base))
    except OSError:
        return []
    return [n for n in nomes
            if os.path.splitext(n)[1].lower() in EXT_RASTER
            and os.path.isfile(os.path.join(base, n))]


_MIGRAR_MOD = None


def chaves_renomeadas():
    global _MIGRAR_MOD
    if _MIGRAR_MOD is None:
        import importlib.util
        alvo = os.path.join(RAIZ, "scripts", "migrar_conf.py")
        try:
            spec = importlib.util.spec_from_file_location("meow_migrar_conf", alvo)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            _MIGRAR_MOD = mod
        except Exception:
            _MIGRAR_MOD = False
    return dict(getattr(_MIGRAR_MOD, "RENOMEADAS", None) or {})


def _nome_antigo_valendo():
    nomes = set()
    try:
        with open(CONF, "r", encoding="utf-8") as fh:
            for linha in fh:
                linha = linha.strip()
                if linha.startswith("export "):
                    linha = linha[len("export "):]
                achado = RE_CHAVE.match(linha)
                if achado:
                    nomes.add(achado.group(1))
    except OSError:
        return {}
    return {novo: antigo for antigo, novo in chaves_renomeadas().items()
            if antigo in nomes and novo not in nomes}


@_uma_vez_por_leitura
def valores_brutos():
    valores = {}
    for arquivo in (CONF_PADRAO, CONF):
        try:
            with open(arquivo, "r", encoding="utf-8") as fh:
                for linha in fh:
                    linha = linha.strip()
                    if linha.startswith("export "):
                        linha = linha[len("export "):]
                    achado = RE_CHAVE.match(linha)
                    if achado:
                        valores[achado.group(1)] = _valor_da_linha(linha)
        except OSError:
            continue
    for novo, antigo in _nome_antigo_valendo().items():
        valores[novo] = valores.get(antigo, "")
    return valores


@_uma_vez_por_leitura
def valores_efetivos(chaves):
    if not chaves:
        return {}
    antigos = {n: a for n, a in _nome_antigo_valendo().items() if n in chaves}
    programa = (
        'set -a\n'
        '[ -f "$1" ] && . "$1"\n'
        '[ -f "$2" ] && . "$2"\n'
        'set +a\n'
        'shift 2\n'
        'for k in "$@"; do printf "%s=%s\\0" "$k" "${!k-}"; done\n'
    )
    try:
        saida = subprocess.run(
            ["bash", "-c", programa, "_", CONF_PADRAO, CONF, *chaves, *antigos.values()],
            capture_output=True, timeout=20,
        ).stdout.decode("utf-8", "replace")
    except (OSError, subprocess.SubprocessError):
        return {}
    fora = {}
    for pedaco in saida.split("\0"):
        if "=" in pedaco:
            k, v = pedaco.split("=", 1)
            fora[k] = v
    for novo, antigo in antigos.items():
        fora[novo] = fora.pop(antigo, fora.get(novo, ""))
    return fora


def conf_exportada(fonte=None):
    fonte = fonte or (CONF if os.path.isfile(CONF) else CONF_PADRAO)
    nomes = []
    try:
        with open(fonte, "r", encoding="utf-8") as fh:
            for linha in fh:
                linha = linha.strip()
                if linha.startswith("export "):
                    linha = linha[len("export "):]
                achado = RE_CHAVE.match(linha)
                if achado and achado.group(1) not in nomes:
                    nomes.append(achado.group(1))
    except OSError:
        return None
    programa = (
        'set -a\n'
        '. "$1" || exit 2\n'
        'set +a\n'
        'export MEOW_RAIZ="$2"\n'
        '. "$MEOW_RAIZ/lib/comum.sh" >/dev/null 2>&1 || true\n'
        'FLAVOR="$(meow_flavor 2>/dev/null)"; ACCENT="${ACCENT:-mauve}"\n'
        'meow_pastas_do_molde 2>/dev/null || true\n'
        'MODO="${MODO:-escuro}"; LOGO="${LOGO:-$FLAVOR}"\n'
        'if ! meow_ponte_python >/dev/null 2>&1; then\n'
        '  if [ "${MEOW_PALETA:-}" = "${MEOW_PALETA_DA_PONTE:-}" ]; then\n'
        '    MEOW_PALETA=""; MEOW_PACK_DIR=""; MEOW_PALETA_DA_PONTE=""\n'
        '  fi\n'
        'fi\n'
        'shift 2\n'
        'for k in "$@"; do printf "%s=%s\\0" "$k" "${!k-}"; done\n'
    )
    da_ponte = ["MEOW_PALETA", "MEOW_PACK_DIR", "MEOW_PALETA_DA_PONTE"]
    try:
        feito = subprocess.run(
            ["bash", "-c", programa, "_", fonte, RAIZ,
             *nomes, "FLAVOR", "ACCENT", "MODO", "LOGO", *da_ponte],
            capture_output=True, timeout=20,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if feito.returncode != 0:
        return None
    fora = {}
    for pedaco in feito.stdout.decode("utf-8", "replace").split("\0"):
        if "=" in pedaco:
            k, v = pedaco.split("=", 1)
            fora[k] = v
    return fora


_VAR_SIMPLES = re.compile(r"\$(?:\{[A-Za-z_][A-Za-z0-9_]*\}|[A-Za-z_][A-Za-z0-9_]*)")


def expansao_perigosa(valor):
    if "`" in valor:
        return ("o valor não pode ter crase: no meow.conf ela vira execução de "
                "comando. Para o texto de uma cor ou de um nome, tire as crases.")
    resto = _VAR_SIMPLES.sub("", valor)
    if "$" in resto:
        return ("o valor só aceita `$NOME` ou `${NOME}` — as outras formas de `$` "
                "(como `$(...)`) viram execução de comando quando o meow.conf é lido.")
    return None


_TETO_CACHE = {"quando": 0.0, "valor": None}
_BARRA_DO_RAIO = {"FORMA_RAIO_PAINEL": "Panel", "FORMA_RAIO_DOCK": "Dock"}


def teto_do_raio():
    agora = time.time()
    if _TETO_CACHE["valor"] is not None and agora - _TETO_CACHE["quando"] < 30:
        return _TETO_CACHE["valor"]
    fonte = CONF if os.path.isfile(CONF) else CONF_PADRAO
    programa = (
        'set -a; . "$2"; set +a\n'
        '. "$1/lib/comum.sh"; . "$1/lib/painel.sh"\n'
        'printf "experimental\\t%s\\n" "${FORMA_RAIO_EXPERIMENTAL-}"\n'
        'for b in Panel Dock; do\n'
        '  d="$MEOW_PAINEL_BASE/com.system76.CosmicPanel.$b/v1"\n'
        '  [ -d "$d" ] || continue\n'
        '  t="$(meow_painel_teto "$d" 2>/dev/null)" || continue\n'
        '  printf "%s\\t%s\\n" "$b" "$t"\n'
        'done\n'
        'if meow_painel_compositor_clampa; then printf "compositor\\tclampa\\n"\n'
        'elif meow_painel_patch_pendente; then printf "compositor\\tpendente\\n"\n'
        'else printf "compositor\\tsem\\n"; fi\n'
    )
    valor = {}
    try:
        saida = subprocess.run(["bash", "-c", programa, "_", RAIZ, fonte],
                               capture_output=True, timeout=10,
                               env=_ambiente_do_painel()).stdout.decode("utf-8", "replace")
    except (OSError, subprocess.SubprocessError):
        saida = ""
    for linha in saida.splitlines():
        nome, _, v = linha.partition("\t")
        if nome in ("Panel", "Dock") and v.isdigit():
            valor[nome] = int(v)
        elif nome == "compositor" and v in ("clampa", "pendente", "sem"):
            valor["compositor"] = v
        elif nome == "experimental":
            valor["experimental"] = v in ("sim", "true", "1")
    if "compositor" not in valor:
        valor = {}
    _TETO_CACHE["quando"], _TETO_CACHE["valor"] = agora, valor
    return valor


def teto_da_chave(chave):
    barra = _BARRA_DO_RAIO.get(chave)
    medida = teto_do_raio() if barra else {}
    if not barra or barra not in medida:
        return None
    t = medida[barra]
    acima = ("qualquer canto arredondado" if t == 0
             else "um canto acima de %d px" % t)
    if medida["compositor"] == "clampa":
        return {"valor": None, "trava": False, "estado": "clampa",
                "motivo": "o compositor desta sessão corta o excesso sozinho, "
                          "e o raio é todo seu"}
    if medida.get("experimental"):
        return {"valor": t, "trava": False, "estado": "experimental",
                "motivo": "modo experimental ligado (FORMA_RAIO_EXPERIMENTAL): "
                          "%s pode derrubar painel e dock juntos" % acima}
    if medida["compositor"] == "pendente":
        porque = ("o patch do raio já está instalado, mas só vale no próximo "
                  "login; até lá, %s derruba painel e dock juntos" % acima)
    else:
        porque = ("o compositor desta sessão não tem o patch do raio, e %s "
                  "derruba painel e dock juntos" % acima)
    return {"valor": t, "trava": True, "motivo": porque, "estado": medida["compositor"]}


def validar_valor(item, valor):
    if valor == "":
        return None

    fechadas = _opcoes_fechadas(item["chave"], item["ajuda"], item["inline"],
                                item["padrao"])
    if item["chave"] == "FLAVOR" and fechadas:
        fechadas = _flavors_dos_packs() or fechadas
    if item["chave"] == "PACK":
        fechadas = sorted(_packs_no_disco()) or fechadas
    if fechadas and valor not in fechadas:
        return "%s aceita %s" % (item["chave"], " | ".join(fechadas))

    if (not fechadas and item["opcoes"]
            and all(RE_DURACAO.match(o) for o in item["opcoes"])):
        if not RE_DURACAO.match(valor):
            return ("%s é uma duração: número e unidade (30s, 5m, 2h, 1d)"
                    % item["chave"])
        return None

    if item["horario"] and not RE_HORARIO_VALOR.match(valor):
        return "%s é um horário no formato HH:MM (07:30)" % item["chave"]

    if item["faixa"]:
        lo, hi, _passo = item["faixa"]
        if valor == item["padrao"] and valor in _PALAVRAS_COM_FAIXA:
            return None
        try:
            n = float(valor.replace(",", "."))
        except ValueError:
            return "%s é um número entre %s e %s" % (item["chave"], lo, hi)
        if not (lo <= n <= hi):
            return "%s vai de %s a %s — %s está fora" % (item["chave"], lo, hi, valor)
        teto = teto_da_chave(item["chave"])
        if teto and teto["trava"] and n > teto["valor"]:
            return "o teto agora é %d px: %s" % (teto["valor"], teto["motivo"])
        return None

    perigo = expansao_perigosa(valor)
    if perigo:
        return "%s: %s" % (item["chave"], perigo)

    if item["tipo_numero"]:
        for nome, forma, explica in FORMAS_NUMERO:
            if nome == item["tipo_numero"]:
                if not forma.match(valor):
                    return "%s espera %s" % (item["chave"], explica)
                break
    return None


PONTAS_DA_NOITE = ("NOITE_INICIO", "NOITE_FIM")


HORARIO_DAS_AREAS = (
    ("Claro ou escuro", "MODO_AUTO_CLARO_ATE", "MODO_AUTO_CLARO_DE", "hora"),
    ("Papel de parede", "WALLPAPER_NOITE_INICIO", "WALLPAPER_NOITE_FIM", "hhmm"),
    ("Tela quente", "LEITURA_HORARIO_INICIO", "LEITURA_HORARIO_FIM", "hhmm"),
)
NOITE_DE_FABRICA = ("18:00", "07:00")


def _arquivo_do_mesmo_horario():
    return os.path.join(ESTADO, "horario-por-area.tsv")


def horario_das_areas():
    no_esquema = {i["chave"] for i in ler_esquema()}
    return [a for a in HORARIO_DAS_AREAS if a[1] in no_esquema and a[2] in no_esquema]


def mesmo_horario_ligado():
    return os.path.isfile(_arquivo_do_mesmo_horario())


def _pares_da_noite(inicio, fim):
    pares = []
    for _area, c_ini, c_fim, forma in horario_das_areas():
        for chave, hora in ((c_ini, inicio), (c_fim, fim)):
            pares.append((chave, str(int(hora.split(":")[0])) if forma == "hora" else hora))
    return pares


def com_o_mesmo_horario(pares, brutos=None):
    escolhas = dict(pares)
    if not mesmo_horario_ligado() or not any(c in escolhas for c in PONTAS_DA_NOITE):
        return list(pares)
    antes = dict(valores_brutos() if brutos is None else brutos)
    final = dict(antes, **escolhas)
    inicio, fim = (str(final.get(c) or "").strip() for c in PONTAS_DA_NOITE)
    if not (re.match(r"^\d{1,2}:\d{2}$", inicio) and re.match(r"^\d{1,2}:\d{2}$", fim)):
        return list(pares)
    return list(pares) + [p for p in _pares_da_noite(inicio, fim)
                          if p[0] not in escolhas and str(antes.get(p[0]) or "") != p[1]]


def _adotar_leitura(chaves):
    leitura = [c for c in chaves if c in _LEITURA_NO_APPLET]
    if leitura:
        try:
            subprocess.run(_meow("leitura", "adotar", *leitura), capture_output=True, timeout=20,
                           env=_ambiente_do_painel())
        except (OSError, subprocess.SubprocessError):
            pass


def ligar_mesmo_horario(ligar):
    arq = _arquivo_do_mesmo_horario()
    brutos = valores_brutos()
    if ligar:
        inicio = str(brutos.get("NOITE_INICIO") or "").strip()
        fim = str(brutos.get("NOITE_FIM") or "").strip()
        pares = []
        if not (inicio and fim):
            inicio, fim = NOITE_DE_FABRICA
            pares = list(zip(PONTAS_DA_NOITE, NOITE_DE_FABRICA))
        pares += [p for p in _pares_da_noite(inicio, fim) if str(brutos.get(p[0]) or "") != p[1]]
        if not os.path.isfile(arq):
            os.makedirs(ESTADO, exist_ok=True)
            guardado = "".join("%s\t%s\n" % (c, str(brutos.get(c) or ""))
                               for _a, ci, cf, _f in horario_das_areas() for c in (ci, cf))
            with open(arq + ".parcial", "w", encoding="utf-8") as fh:
                fh.write(guardado)
            os.replace(arq + ".parcial", arq)
    else:
        if not os.path.isfile(arq):
            return [], None
        validas = {c for _a, ci, cf, _f in horario_das_areas() for c in (ci, cf)}
        pares = []
        with open(arq, encoding="utf-8") as fh:
            for linha in fh:
                chave, _sep, valor = linha.rstrip("\n").partition("\t")
                if (chave in validas and not RE_CONTROLE_DE_TEXTO.search(valor)
                        and str(brutos.get(chave) or "") != valor):
                    pares.append((chave, valor))
    feitos = definir_varias(pares) if pares else []
    falhas = [c for c, rc, _s in feitos if rc not in (0, 1)]
    if falhas:
        return [], "não consegui gravar: " + ", ".join(falhas)
    if not ligar:
        os.remove(arq)
    _adotar_leitura([c for c, rc, _s in feitos if rc == 1])
    return [c for c, rc, _s in feitos if rc == 1], None


RE_CONTROLE_DE_TEXTO = re.compile(r"[\x00-\x1f\x7f]")


def pontas_da_noite_soltas(escolhas, brutos=None):
    if not any(c in escolhas for c in PONTAS_DA_NOITE):
        return []
    final = dict(valores_brutos() if brutos is None else brutos)
    final.update(escolhas)
    cheias = [c for c in PONTAS_DA_NOITE if str(final.get(c, "")).strip()]
    if len(cheias) != 1:
        return []
    return [{"chave": cheias[0],
             "erro": "a noite pede as duas pontas, começo e fim, ou nenhuma"}]


def _ambiente_do_painel(seco=False):
    ambiente = dict(os.environ, MEOW_RAIZ=RAIZ)
    ambiente.pop("MEOW_DRY_RUN", None)
    if seco:
        ambiente["MEOW_DRY_RUN"] = "1"
    return ambiente


def definir_varias(pares, conf=None):
    for chave, valor in pares:
        if not RE_CHAVE.match(chave + "="):
            return [(chave, 2, "nome de chave inválido")]
        if '"' in valor or "#" in valor or "\n" in valor:
            return [(chave, 2, 'o valor não pode conter aspas, `#` nem quebra de linha')]
        perigo = expansao_perigosa(valor)
        if perigo:
            return [(chave, 2, perigo)]
    if not pares:
        return []
    programa = ('. "$1/lib/comum.sh"; shift; '
                'while [ $# -ge 2 ]; do '
                'meow_conf_definir "$1" "$2"; r=$?; '
                'printf "\\n@@meow-rc %s %s\\n" "$1" "$r"; '
                'shift 2; done')
    argv = ["bash", "-c", programa, "_", RAIZ]
    for chave, valor in pares:
        argv += [chave, valor]
    ambiente = _ambiente_do_painel()
    if conf:
        ambiente["MEOW_CONF"] = conf
        ambiente["MEOW_ESTADO"] = os.path.dirname(conf)
    try:
        proc = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              timeout=30 + 5 * len(pares), env=ambiente)
    except (OSError, subprocess.SubprocessError) as erro:
        return [(chave, 2, str(erro)) for chave, _valor in pares]
    saida = proc.stdout.decode("utf-8", "replace")
    achados, trecho = {}, []
    for linha in saida.split("\n"):
        partes = linha.split(" ")
        if len(partes) == 3 and partes[0] == "@@meow-rc" and partes[2].isdigit():
            achados[partes[1]] = (int(partes[2]), "\n".join(trecho).strip())
            trecho = []
        else:
            trecho.append(linha)
    sem_resposta = (2, saida.strip() or "o bash saiu sem dizer o que gravou")
    return [(chave,) + achados.get(chave, sem_resposta) for chave, _valor in pares]


def definir(chave, valor):
    _chave, rc, saida = definir_varias([(chave, valor)])[0]
    return (rc, saida)


def _conf_de_ensaio(pares):
    fonte = CONF if os.path.isfile(CONF) else CONF_PADRAO
    try:
        pasta = tempfile.mkdtemp(prefix="meow-ensaio-")
        destino = os.path.join(pasta, "meow.conf")
        shutil.copyfile(fonte, destino)
    except OSError as erro:
        return (None, "não consegui preparar o ensaio: %s" % erro)
    for chave, rc, saida in definir_varias(pares, conf=destino):
        if rc == 2:
            shutil.rmtree(pasta, ignore_errors=True)
            return (None, "%s: %s" % (chave, saida or "não consegui gravar no ensaio"))
    if os.path.isfile(_SOM_CARIMBO):
        shutil.copyfile(_SOM_CARIMBO, os.path.join(pasta, "som-do-pack"))
    _som_carimbo_gravar(pares, pasta)
    return (pasta, None)


_PALETA_CACHE = {}


def _paleta_dados():
    _ponte_em_dia()
    if not _PALETA_CACHE:
        try:
            with open(paleta_canonica(), "r", encoding="utf-8") as fh:
                _PALETA_CACHE.update(json.load(fh))
        except (OSError, ValueError):
            _PALETA_CACHE["flavors"] = {}
    return _PALETA_CACHE


def logo_do_painel(flavor, accent):
    dados = _paleta_dados()
    flavors = dados.get("flavors", {})
    mod = modulo_pack()
    no_ar = _pack_no_ar()
    padrao = ((mod.campo(no_ar, "paleta.flavor_padrao") if mod and no_ar else "")
              or next(iter(flavors), ""))
    cores = flavors.get(flavor) or flavors.get(padrao) or {}
    if accent not in cores:
        accent = "mauve" if "mauve" in cores else next(iter(cores), "")
    tinta = cores.get(accent) or ""

    def _marca(nome_flavor):
        if not mod or not nome_flavor:
            return ""
        return mod.acervo("icones.autorais.desenhos",
                          "meowsystem-painel-%s.svg" % nome_flavor) or ""

    arquivo = (_marca(flavor) or _marca(padrao)
               or _marca(mod.campo(mod.PACK_PADRAO, "paleta.flavor_padrao") if mod else ""))
    if not arquivo or not os.path.isfile(arquivo):
        return None
    with open(arquivo, "r", encoding="utf-8") as fh:
        bruto = fh.read()
    if not tinta:
        return bruto.encode("utf-8")
    return re.sub(r'stroke="#[0-9A-Fa-f]{3,8}"',
                  'stroke="%s"' % tinta, bruto).encode("utf-8")


def _areas_alfinetadas():
    caminho = os.path.expanduser(
        "~/.config/cosmic/com.system76.CosmicComp/v1/pinned_workspaces")
    try:
        with open(caminho, "r", encoding="utf-8", errors="replace") as fh:
            bruto = fh.read()
    except OSError:
        return []
    fora = []
    for m in re.finditer(r'name:\s*Some\(\s*"((?:[^"\\]|\\.)*)"\s*\)', bruto):
        nome = m.group(1).replace("\\u{2007}", "").replace("\u2007", "").strip()
        if nome:
            fora.append(nome)
    return fora


def paleta_css(flavor, accent):
    dados = _paleta_dados()
    flavors = dados.get("flavors", {})
    if not flavors:
        return "/* paleta ilegível — a página cai no tema do navegador */\n"
    cores = flavors.get(flavor) or next(iter(flavors.values()), {})
    if accent not in cores:
        accent = "mauve" if "mauve" in cores else next(iter(cores), "")
    claro = flavor in dados.get("claros", [])
    linhas = [
        f"/* Gerado por app/servidor.py a partir de "
        f"{os.path.relpath(paleta_canonica(), RAIZ)}.",
        "   Não edite: a fonte é a paleta, e ela é a única verdade de cor. */",
        ":root {",
        f"  color-scheme: {'light' if claro else 'dark'};",
    ]
    for nome, hexa in cores.items():
        linhas.append(f"  --{nome}: {hexa};")
    linhas.append(f"  --accent: var(--{accent});")
    mod = modulo_pack()
    luz = (lambda h: mod._luminancia(h)) if mod and hasattr(mod, "_luminancia") else (lambda h: 0.0)
    claros_do_pack = [f for f in (dados.get("claros", []) or []) if f in flavors]
    escuros = [f for f in flavors if f not in claros_do_pack]
    escuro = min(escuros, key=lambda f: luz(flavors[f].get("base", "#000000"))) if escuros else None
    claro_do_pack = max(claros_do_pack, key=lambda f: luz(flavors[f].get("base", "#000000"))) \
        if claros_do_pack else None
    base_escura = (flavors[escuro] if escuro else cores).get("base", "")
    base_clara = (flavors[claro_do_pack].get("base", "") if claro_do_pack
                  else (flavors[escuro] if escuro else cores).get("text", ""))
    linhas.append("  --fundo-escuro: %s;" % base_escura)
    linhas.append("  --fundo-claro: %s;" % base_clara)
    linhas.append("  --fundo-mocha: var(--fundo-escuro);")
    linhas.append("  --fundo-latte: var(--fundo-claro);")
    linhas.append("  --fundo-vidro-escuro: color-mix(in srgb, var(--base) 83%, var(--text));")
    linhas.append("  --fundo-vidro-claro: color-mix(in srgb, var(--surface1) 55%, var(--mauve));")
    linhas.append(f"  --accent-nome: '{accent}';")
    linhas.append("}")
    return "\n".join(linhas) + "\n"


def _flavor_no_modo(flavor, modo):
    claros = _paleta_dados().get("claros") or []
    if modo == "claro":
        return claros[0] if claros else flavor
    if modo != "escuro" or flavor not in claros:
        return flavor
    flavors = _paleta_dados().get("flavors") or {}
    mod = modulo_pack()
    no_ar = _pack_no_ar()
    padrao = (mod.campo(no_ar, "paleta.flavor_padrao") if mod and no_ar else "") or ""
    if padrao in flavors and padrao not in claros:
        return padrao
    escuros = [f for f in flavors if f not in claros]
    return escuros[0] if escuros else flavor


def _lados_do_pack():
    return {f: {m: _flavor_no_modo(f, m) for m in ("claro", "escuro")}
            for f in (_paleta_dados().get("flavors") or {})}


_SEM_TEMA_CACHE = {}


def _variante_sem_tema(flavor, accent):
    _ponte_em_dia()
    mod = modulo_pack()
    if mod is None:
        return False
    par = "%s-%s" % (flavor, accent)
    try:
        if mod.captura(par):
            return False
        chave = [os.environ.get("MEOW_PACK_DIR", ""), os.environ.get("MEOW_PALETA", ""), par,
                 os.stat(mod.paleta_do_pack_ativo()).st_mtime_ns]
        for nome in mod.capturas():
            txt = os.path.join(mod.captura(nome) or "", "captura.txt")
            chave.append((nome, os.stat(txt).st_mtime_ns if os.path.isfile(txt) else 0))
    except Exception:
        return False
    chave = repr(chave)
    if chave not in _SEM_TEMA_CACHE:
        try:
            r = subprocess.run(
                [sys.executable, os.path.join(RAIZ, "scripts", "derivar_acento.py"),
                 "--conferir", par],
                cwd=RAIZ, capture_output=True, text=True, timeout=60)
        except (OSError, subprocess.SubprocessError):
            return False
        _SEM_TEMA_CACHE.clear()
        _SEM_TEMA_CACHE[chave] = r.returncode == 3
    return _SEM_TEMA_CACHE[chave]


def _flavor_na_tela():
    escuro = _cosmic_ler("com.system76.CosmicTheme.Mode/v1/is_dark")
    if escuro not in ("true", "false"):
        return None
    arvore = "Dark" if escuro == "true" else "Light"
    bruto = _cosmic_ler("com.system76.CosmicTheme.%s.Builder/v2/palette" % arvore) or ""
    m = re.search(r'\bname:\s*"([^"]*)"', bruto)
    if not m:
        return None
    for f in (_paleta_dados().get("flavors") or {}):
        if m.group(1) == f or m.group(1).endswith("-" + f):
            return f
    return None


def _acento_na_tela(flavor):
    escuro = _cosmic_ler("com.system76.CosmicTheme.Mode/v1/is_dark")
    if escuro not in ("true", "false"):
        return None
    arvore = "Dark" if escuro == "true" else "Light"
    bruto = _cosmic_ler("com.system76.CosmicTheme.%s.Builder/v2/accent" % arvore) or ""
    m = re.match(r'^Some\(\s*"(#[0-9A-Fa-f]{6})', bruto)
    if not m:
        return None
    cores = (_paleta_dados().get("flavors") or {}).get(flavor) or {}
    return next((slot for slot, hexa in cores.items()
                 if str(hexa).upper() == m.group(1).upper()), None)


def _flavor_da_pagina(flavor, valores):
    modo = valores.get("MODO")
    if not _variante_sem_tema(flavor, valores.get("ACCENT") or "mauve"):
        return _flavor_no_modo(flavor, modo)
    na_tela = _flavor_na_tela()
    if na_tela:
        return na_tela
    mod = modulo_pack()
    no_ar = _pack_no_ar()
    padrao = (mod.campo(no_ar, "paleta.flavor_padrao") if mod and no_ar else "") or flavor
    return _flavor_no_modo(padrao, modo)


def _acento_da_pagina(flavor, valores):
    accent = valores.get("ACCENT") or "mauve"
    if not _variante_sem_tema(_flavor_do_conf(valores), accent):
        return accent
    return _acento_na_tela(flavor) or "mauve"


PROVEDORES = {
    "capturas": _capturas,
    "gatos": _gatos,
    "modos": lambda: ["claro", "escuro", "auto"],
    "temas_icones": _temas_de_icones,
    "cursores": _temas_de_cursor,
    "areas": _areas_alfinetadas,
    "paredes_ativas": _paredes_ativas,
    "paredes_banidas": _paredes_banidas,
    "paredes_favoritas": lambda: _paredes_favoritas(),
    "packs": lambda: sorted(_packs_no_disco()),
    "packs_removiveis": _packs_removiveis,
    "apps_de_terceiro": lambda: sorted({_app_da_pendencia(p["id"]) for p in pendencias()} - {""}),
    "extensoes_de_terceiro": lambda: _extensoes_de_terceiro(),
    "fontes_revertidas": lambda: _fontes_revertidas(),
    "restauros": lambda: sorted(restauros()),
    "jogos_heroic": lambda: sorted(j["id"] for j in jogos_do_heroic()),
}


def _meow(*args):
    return [os.path.join(RAIZ, "bin", "meow"), *args]


def _casas():
    casa = os.path.expanduser("~")
    return [c for c in dict.fromkeys((casa, os.path.realpath(casa)))
            if c and c != os.sep]


def _na_casa(caminho):
    for casa in _casas():
        if caminho == casa or caminho.startswith(casa + os.sep):
            return casa, caminho[len(casa):]
    return None


def comando_na_tela(argv):
    meow = os.path.join(RAIZ, "bin", "meow")
    partes = []
    for p in argv:
        casa = _na_casa(p)
        if p == meow:
            partes.append("meow")
        elif p.startswith(RAIZ + os.sep):
            partes.append(shlex.quote("./" + p[len(RAIZ) + 1:]))
        elif casa:
            resto = casa[1].lstrip(os.sep)
            partes.append("~/" + shlex.quote(resto) if resto else "~")
        else:
            partes.append(shlex.quote(p))
    return " ".join(partes)


def texto_na_tela(texto):
    for casa in _casas():
        borda = r"(?<![\w/.~-])"
        texto = re.sub(borda + r"([\"'])" + re.escape(casa) + r"(?:(/)|\1)",
                       lambda m: "~/" + m.group(1) if m.group(2) else "~", texto)
        texto = re.sub(borda + re.escape(casa) + r"(?![\w.-])", "~", texto)
    return texto


def sem_casa_nem_raiz(valor, outras=()):
    if isinstance(valor, dict):
        return {sem_casa_nem_raiz(k, outras): sem_casa_nem_raiz(v, outras)
                for k, v in valor.items()}
    if isinstance(valor, list):
        return [sem_casa_nem_raiz(v, outras) for v in valor]
    if not isinstance(valor, str) or valor.startswith("data:"):
        return valor
    for forma in (str, lambda s: quote(s, safe="")):
        raiz = forma(RAIZ)
        valor = "" if valor == raiz else valor.replace(forma(RAIZ + "/"), "")
        for casa in _casas():
            valor = re.sub(r"(?<![\w/.~-])" + re.escape(forma(casa)) + r"(?![\w.-])",
                           "~", valor)
        for caminho, rotulo in outras:
            valor = re.sub(r"(?<![\w/.~-])" + re.escape(forma(caminho)) + r"(?![\w.-])",
                           lambda _m, r=forma(rotulo): r, valor)
    return valor


_PELA_PONTE = frozenset({"sistema_atualizar", "sistema_limpar"})
_PONTE_CAMINHO = "/usr/local/lib/meowsystem/ponte_root.sh"
_ponte_cache = {"quando": 0.0, "vale": False}


def _ponte_viva():
    agora = time.time()
    if agora - _ponte_cache["quando"] < 30:
        return _ponte_cache["vale"]
    vale = False
    if os.access(_PONTE_CAMINHO, os.X_OK):
        try:
            vale = subprocess.run(["sudo", "-n", _PONTE_CAMINHO, "estado"],
                                  capture_output=True, timeout=5).returncode == 0
        except (OSError, subprocess.SubprocessError):
            vale = False
    _ponte_cache["quando"] = agora
    _ponte_cache["vale"] = vale
    return vale


NATUREZAS = {
    "mostrar":   {"0": ("ok", "mostrou"),
                  "1": ("correndo", "há divergências")},
    "conferir":  {"0": ("ok", "tudo confere"),
                  "1": ("correndo", "há divergências")},
    "consertar": {"0": ("ok", "nada a consertar"),
                  "0~": ("correndo", "divergências sem conserto"),
                  "1": ("ok", "consertou")},
    "aplicar":   {"0": ("ok", "já estava certo"),
                  "0~": ("ok", "mexeu e aplicou"),
                  "1": ("ok", "mexeu e aplicou")},
    "instalar":  {"0": ("ok", "já estava certo"),
                  "0~": ("ok", "mexeu e aplicou"),
                  "1": ("correndo", "aplicou, com pendência")},
    "trocar":    {"0": ("ok", "já estava assim"),
                  "0~": ("ok", "trocou"),
                  "1": ("ok", "trocou")},
    "gravar":    {"0": ("ok", "já estava assim"),
                  "0~": ("ok", "gravou"),
                  "1": ("ok", "gravou")},
    "tirar":     {"0": ("ok", "nada a tirar"),
                  "0~": ("ok", "tirou"),
                  "1": ("ok", "tirou")},
    "devolver":  {"0": ("ok", "nada a devolver"),
                  "0~": ("ok", "devolveu"),
                  "1": ("ok", "devolveu")},
    "baixar":    {"0": ("ok", "já estava aqui"),
                  "0~": ("ok", "baixou e instalou"),
                  "1": ("ok", "baixou e instalou")},
    "atualizar": {"0": ("ok", "já estava em dia"),
                  "0~": ("ok", "atualizou"),
                  "1": ("ok", "atualizou")},
    "tocar":     {"0": ("ok", "tocou")},
    "reciclar":  {"0": ("ok", "nada a recarregar"),
                  "0~": ("ok", "recarregou")},
    "ensaio":    {"0": ("ok", "nada mudaria"),
                  "0~": ("correndo", "mudaria"),
                  "1": ("correndo", "mudaria")},
}
_FIM_PULADO = {"3": ("pula", "pulado"), "4": ("pula", "pulado")}


def fim_da_acao(acao_id, seco=False):
    natureza = "ensaio" if seco else ACOES[acao_id]["natureza"]
    return {k: list(v) for k, v in dict(_FIM_PULADO, **NATUREZAS[natureza]).items()}


@_uma_vez_por_leitura
def _modo_do_gato():
    fonte = CONF if os.path.isfile(CONF) else CONF_PADRAO
    programa = 'set -a; . "$1"; set +a; exec "$2" modo'
    try:
        r = subprocess.run(["bash", "-c", programa, "_", fonte,
                            os.path.join(RAIZ, "scripts", "logo.sh")],
                           capture_output=True, timeout=10, env=_ambiente_do_painel())
    except (OSError, subprocess.SubprocessError):
        return ""
    return r.stdout.decode("utf-8", "replace").strip() if r.returncode == 0 else ""


@_uma_vez_por_leitura
def _gato_no_dock():
    fonte = CONF if os.path.isfile(CONF) else CONF_PADRAO
    programa = 'set -a; . "$1"; set +a; exec "$2" no-dock'
    try:
        r = subprocess.run(["bash", "-c", programa, "_", fonte,
                            os.path.join(RAIZ, "scripts", "logo.sh")],
                           capture_output=True, timeout=10,
                           env=dict(_ambiente_do_painel(), MEOW_DRY_RUN="1"))
    except (OSError, subprocess.SubprocessError):
        return ""
    return r.stdout.decode("utf-8", "replace").strip() if r.returncode == 0 else ""


def _gato_so_nos_modos(vale_em, pede):
    def medir():
        modo = _modo_do_gato()
        if not modo or modo in vale_em:
            return None
        return {"chave": "LOGO_MODO", "vale": modo, "pede": pede}
    return medir


def _areas_sem_alfinete():
    if _areas_alfinetadas():
        return None
    return {"antes": "areas_alfinetar_primeira",
            "porque": "nenhuma área está fixada, e é de uma fixada que as "
                      "outras herdam o monitor"}


def comeca_como_svg(dados):
    cabeca = dados[:4096]
    if cabeca.startswith(b"\xef\xbb\xbf"):
        cabeca = cabeca[3:]
    i = 0
    for _ in range(64):
        while i < len(cabeca) and cabeca[i:i + 1].isspace():
            i += 1
        for abre, fecha in ((b"<?xml", b"?>"), (b"<!--", b"-->"), (b"<!DOCTYPE", b">")):
            if cabeca.startswith(abre, i):
                fim = cabeca.find(fecha, i + len(abre))
                if fim < 0:
                    return False
                i = fim + len(fecha)
                break
        else:
            seguinte = cabeca[i + 4:i + 5]
            return cabeca.startswith(b"<svg", i) and (seguinte == b">" or seguinte.isspace())
    return False


def _areas_ja_alfinetadas():
    if not _areas_alfinetadas():
        return None
    return {"feito": "areas_aplicar",
            "porque": "há área fixada nesta máquina"}


def indisponivel(acao_id):
    medir = ACOES[acao_id].get("indisponivel")
    return medir() if medir else None


ACOES = {
    "pack_usar": {
        "rotulo": "Usar este pack",
        "grupo": "Instalação",
        "natureza": "instalar",
        "argv": _meow("pack", "usar", "@ARG@"), "arg": "packs",
        "escreve": True, "sudo": True, "confirma": True, "rede": True,
        "oculta": True,
        "ajuda": "Grava o pack e a variante dele no meow.conf e roda o "
                 "instalador: a máquina inteira troca de tema.",
    },
    "pack_remover": {
        "rotulo": "Remover este pack",
        "grupo": "Instalação",
        "natureza": "tirar",
        "argv": _meow("pack", "remover", "@ARG@"), "arg": "packs_removiveis",
        "escreve": True, "sudo": False, "confirma": True, "destrutivo": True,
        "oculta": True,
        "ajuda": "Tira da sua casa de packs um pack que você importou. O tema no "
                 "ar não muda; para tê-lo de novo, importe o arquivo dele outra vez.",
    },
    "instalar": {
        "rotulo": "Instalar tudo",
        "grupo": "Instalação",
        "natureza": "instalar",
        "argv": [os.path.join(RAIZ, "install.sh")],
        "escreve": True, "sudo": True, "confirma": True, "rede": True,
        "ajuda": "Passa {as_etapas}. Rodar de novo numa máquina já pronta "
                 "não escreve um byte.",
    },
    "som_ouvir": {
        "rotulo": "Ouvir o som",
        "grupo": "Manutenção",
        "natureza": "tocar",
        "argv": [os.path.join(RAIZ, "scripts", "som.sh"), "ouvir"],
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Toca o som de volume que está instalado agora. Se não houver o "
                 "nosso, toca o de fábrica — assim dá para comparar os dois.",
    },
    "som_aplicar": {
        "rotulo": "Regravar o som",
        "grupo": "Manutenção",
        "natureza": "aplicar",
        "argv": [os.path.join(RAIZ, "scripts", "som.sh"), "aplicar"],
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Gera o som de novo a partir do timbre do pack ativo e do "
                 "meow.conf. Vale na próxima mudança de volume — nada a reiniciar. "
                 "Com «Som ao mudar o volume» em não, este botão faz o contrário: "
                 "devolve o som de fábrica.",
    },
    "doctor": {
        "rotulo": "Conferir a máquina",
        "grupo": "Instalação",
        "natureza": "conferir",
        "argv": _meow("doctor"),
        "escreve": False, "sudo": False, "confirma": False,
        "oculta": True,
        "conserta_com": "doctor_consertar",
        "ajuda": "Faz {as_conferencias} e lista o que está fora do lugar. "
                 "Não escreve nada.",
    },
    "doctor_consertar": {
        "rotulo": "Conferir e consertar",
        "grupo": "Instalação",
        "natureza": "consertar",
        "argv": _meow("doctor", "--consertar"),
        "escreve": True, "sudo": False, "confirma": False, "rede": True,
        "ajuda": "Confere e aplica só o que falhou — o mesmo que o "
                 "agendamento faz sozinho.",
    },
    "status": {
        "rotulo": "No ar agora",
        "grupo": "Instalação",
        "natureza": "mostrar",
        "argv": _meow("status"),
        "escreve": False, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Variante, cor de destaque, tema, ícones e papel de parede.",
    },
    "desinstalar": {
        "rotulo": "Desinstalar o MeowSystem",
        "grupo": "Instalação",
        "natureza": "tirar",
        "argv": [os.path.join(RAIZ, "install.sh"), "--uninstall"],
        "escreve": True, "sudo": True, "confirma": True, "destrutivo": True,
        "ajuda": "Tira o tema, os ícones e os agendamentos. Não apaga "
                 "backups nem a coleção de imagens.",
    },
    "log": {
        "rotulo": "Ver o registro",
        "grupo": "Instalação",
        "natureza": "mostrar",
        "argv": _meow("log"),
        "escreve": False, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "O que este projeto escreveu, e quando.",
    },

    "sistema_ver": {
        "rotulo": "O que muda",
        "grupo": "Atualização",
        "natureza": "mostrar",
        "bloco": "Sistema",
        "argv": [os.path.join(RAIZ, "scripts", "atualizar_sistema.sh"), "ver"],
        "escreve": False, "sudo": False, "confirma": False,
        "par": "sistema_atualizar",
        "ajuda": "Os pacotes com versão nova e os programas em Rust "
                 "desatualizados. Não escreve e não pede senha, mas consulta "
                 "o índice do crates.io para saber o que está velho.",
    },
    "sistema_atualizar": {
        "rotulo": "Atualizar a máquina",
        "grupo": "Atualização",
        "natureza": "atualizar",
        "bloco": "Sistema",
        "argv": [os.path.join(RAIZ, "scripts", "atualizar_sistema.sh"), "aplicar"],
        "escreve": True, "sudo": True, "confirma": True, "rede": True,
        "ajuda": "Atualiza apt, flatpak e cargo, e logo depois faz a conferência "
                 "— que diz o que a atualização desfez do MeowSystem. Demora, e o "
                 "apt mantém os arquivos de configuração que já estão no disco.",
    },
    "sistema_limpar": {
        "rotulo": "Limpar as sobras",
        "grupo": "Atualização",
        "natureza": "tirar",
        "bloco": "Sistema",
        "argv": [os.path.join(RAIZ, "scripts", "atualizar_sistema.sh"), "limpar"],
        "escreve": True, "sudo": True, "confirma": True,
        "ajuda": "Pacotes órfãos e os pacotes que o apt já baixou. Diz quantos "
                 "megabytes saíram.",
    },
    "tema": {
        "rotulo": "Temas prontos",
        "grupo": "Cor e tela",
        "natureza": "mostrar",
        "argv": _meow("tema"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "O tema que você escolheu, o que está mesmo aplicado, e os "
                 "temas prontos que existem.",
    },
    "tema_aplicar": {
        "rotulo": "Trocar de tema",
        "grupo": "Cor e tela",
        "natureza": "trocar",
        "argv": _meow("tema", "@ARG@"), "arg": "capturas",
        "tecnica": True,
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Aplica o tema escolhido, guardando o anterior antes.",
    },
    "tema_modo": {
        "rotulo": "Trocar o modo",
        "grupo": "Cor e tela",
        "natureza": "trocar",
        "argv": _meow("tema", "@ARG@"), "arg": "modos",
        "tecnica": True,
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "São o mesmo tema com um interruptor, por isso trocar não "
                 "pisca a interface.",
    },
    "restaurar": {
        "rotulo": "Restaurar",
        "grupo": "Instalação",
        "natureza": "devolver",
        "argv": _meow("restaurar", "@ARG@"), "arg": "restauros",
        "escreve": True, "sudo": False, "confirma": False,
        "oculta": True,
        "ajuda": "Volta ao estado de antes da última vez que esta ação rodou.",
    },
    "desfazer": {
        "rotulo": "Tema de antes",
        "grupo": "Instalação",
        "natureza": "devolver",
        "argv": _meow("desfazer"),
        "escreve": True, "sudo": False, "confirma": True, "destrutivo": True,
        "ajuda": "Devolve o COSMIC ao backup feito antes da instalação.",
        "ambiente": {"MEOW_SIM": "1"},
    },
    "icones": {
        "rotulo": "Tema de ícones",
        "grupo": "Ícones",
        "natureza": "mostrar",
        "argv": _meow("icones"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Qual está selecionado e quantos arquivos ele tem.",
    },
    "icones_reconstruir": {
        "rotulo": "Reconstruir os ícones",
        "grupo": "Ícones",
        "natureza": "aplicar",
        "argv": _meow("icones", "reconstruir"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "É o que faz uma troca de variante dos ícones aparecer na "
                 "tela.",
    },
    "icones_traco": {
        "rotulo": "Desenhos em traço",
        "grupo": "Ícones",
        "natureza": "aplicar",
        "argv": [os.path.join(RAIZ, "scripts", "icones_apps_arcticons.sh")],
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Põe no tema os desenhos que os dois acervos de traço trazem "
                 "— é o passo que faz um desenho salvo aqui aparecer.",
    },
    "icones_pack": {
        "rotulo": "Desenhos do pack",
        "grupo": "Ícones",
        "natureza": "aplicar",
        "argv": [os.path.join(RAIZ, "scripts", "icones_apps_dracula.sh")],
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Põe no tema os desenhos que o mapa do pack no ar escolhe — é o "
                 "passo que faz um desenho do pack escolhido aqui aparecer.",
    },
    "logo_listar": {
        "rotulo": "Mascote agora",
        "grupo": "Logo do sistema",
        "natureza": "mostrar",
        "argv": _meow("logo", "listar"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "A lista, o mascote em vigor, e qual regra o escolheu.",
    },
    "logo_trocar": {
        "rotulo": "Pôr o mascote",
        "grupo": "Logo do sistema",
        "natureza": "trocar",
        "argv": _meow("logo", "@ARG@"), "arg": "gatos",
        "escreve": True, "sudo": False, "confirma": False,
        "indisponivel": _gato_so_nos_modos(("fixo",), "fixo"),
        "ajuda": "Põe no dock o mascote escolhido, e ele fica. Quando o mascote segue "
                 "o relógio ou gira sozinho, este botão fica apagado e diz onde "
                 "mudar.",
    },
    "logo_girar": {
        "rotulo": "Próximo mascote",
        "grupo": "Logo do sistema",
        "natureza": "trocar",
        "argv": _meow("logo", "girar"),
        "escreve": True, "sudo": False, "confirma": False,
        "indisponivel": _gato_so_nos_modos(("rotacao",), "rotacao"),
        "ajuda": "Só tem efeito quando o mascote está girando; fora disso o "
                 "botão fica apagado e diz onde mudar.",
    },
    "wallpaper": {
        "rotulo": "O carrossel agora",
        "grupo": "Papel de parede",
        "natureza": "mostrar",
        "argv": _meow("wallpaper"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Pasta, quantas imagens, intervalo, ordem, e se há imagem "
                 "fixada.",
    },
    "wallpaper_proximo": {
        "rotulo": "Próxima imagem",
        "grupo": "Papel de parede",
        "natureza": "trocar",
        "argv": _meow("wallpaper", "proximo"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Avança e fixa a imagem pelo tempo de "
                 "\"Quanto tempo dura a imagem escolhida\".",
    },
    "wallpaper_anterior": {
        "rotulo": "Imagem anterior",
        "grupo": "Papel de parede",
        "natureza": "trocar",
        "argv": _meow("wallpaper", "anterior"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Volta uma imagem, com a mesma fixação.",
    },
    "wallpaper_carrossel": {
        "rotulo": "Voltar a girar",
        "grupo": "Papel de parede",
        "natureza": "trocar",
        "argv": _meow("wallpaper", "carrossel"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Solta a imagem fixada agora, sem esperar o tempo acabar.",
    },
    "wallpaper_aplicar": {
        "rotulo": "Regras do carrossel",
        "grupo": "Papel de parede",
        "natureza": "aplicar",
        "argv": _meow("wallpaper", "aplicar"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Reescreve o estado do papel de parede a partir dos "
                 "ajustes.",
    },
    "wallpaper_banir": {
        "rotulo": "Tirar do carrossel",
        "grupo": "Papel de parede",
        "natureza": "tirar",
        "argv": _meow("wallpaper", "banir", "@ARG@"), "arg": "paredes_ativas",
        "escreve": True, "sudo": False, "confirma": False,
        "destrutivo": True, "oculta": True,
        "ajuda": "Ela sai da pasta que gira e vai para a de banidas. Nada é "
                 "apagado. O “Devolver” da lista de recusadas desfaz.",
    },
    "wallpaper_usar": {
        "rotulo": "Usar agora",
        "grupo": "Papel de parede",
        "natureza": "trocar",
        "argv": _meow("wallpaper", "usar", "@ARG@"), "arg": "paredes_ativas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Fixa esta imagem como o papel de parede de agora. Quanto tempo "
                 "dura é «Quanto tempo dura a imagem escolhida» — com 0, até "
                 "«Voltar a girar».",
    },
    "wallpaper_permitir": {
        "rotulo": "Manter a imagem",
        "grupo": "Papel de parede",
        "natureza": "gravar",
        "argv": _meow("wallpaper", "permitir", "@ARG@"), "arg": "fontes_revertidas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Autoriza a imagem que você pôs: o carrossel para de devolvê-la.",
    },
    "wallpaper_dispensar": {
        "rotulo": "Deixar assim",
        "grupo": "Papel de parede",
        "natureza": "gravar",
        "argv": _meow("wallpaper", "dispensar"),
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "A imagem devolvida fica como está, e o aviso sai da Início.",
    },
    "wallpaper_favoritar": {
        "rotulo": "Guardar nas favoritas",
        "grupo": "Papel de parede",
        "natureza": "gravar",
        "argv": _meow("wallpaper", "favoritar", "@ARG@"), "arg": "paredes_ativas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Guarda uma cópia nas favoritas; a imagem segue girando.",
    },
    "wallpaper_desfavoritar": {
        "rotulo": "Tirar das favoritas",
        "grupo": "Papel de parede",
        "natureza": "tirar",
        "argv": _meow("wallpaper", "desfavoritar", "@ARG@"), "arg": "paredes_favoritas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Tira a cópia das favoritas; a imagem do carrossel fica.",
    },
    "wallpaper_dia": {
        "rotulo": "Imagem de dia",
        "grupo": "Papel de parede",
        "natureza": "gravar",
        "argv": _meow("wallpaper", "lado", "@ARG@", "dia"), "arg": "paredes_ativas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Ela passa a girar só de dia, mesmo que a medição a ache escura. "
                 "O “Deixar a medição decidir” desfaz.",
    },
    "wallpaper_noite": {
        "rotulo": "Imagem de noite",
        "grupo": "Papel de parede",
        "natureza": "gravar",
        "argv": _meow("wallpaper", "lado", "@ARG@", "noite"), "arg": "paredes_ativas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Ela passa a girar só de noite, mesmo que a medição a ache clara. "
                 "O “Deixar a medição decidir” desfaz.",
    },
    "wallpaper_lado_auto": {
        "rotulo": "Medir a luz",
        "grupo": "Papel de parede",
        "natureza": "gravar",
        "argv": _meow("wallpaper", "lado", "@ARG@", "auto"), "arg": "paredes_ativas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Tira a escolha e deixa o brilho medido da imagem decidir.",
    },
    "areas_ver": {
        "rotulo": "Áreas agora",
        "grupo": "Áreas de trabalho",
        "natureza": "mostrar",
        "argv": _meow("areas", "estado"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Nome, ordem e encaixe de cada área. Não escreve nada.",
    },
    "areas_aplicar": {
        "rotulo": "Gravar as áreas",
        "grupo": "Áreas de trabalho",
        "natureza": "gravar",
        "argv": _meow("areas", "aplicar"),
        "escreve": True, "sudo": False, "confirma": False,
        "indisponivel": _areas_sem_alfinete,
        "ajuda": "Vale no próximo início de sessão: o cosmic-comp lê esse arquivo "
                 "uma vez, ao iniciar. Nada muda no painel agora, e isso não é defeito.",
    },
    "areas_alfinetar_primeira": {
        "rotulo": "Primeira área",
        "grupo": "Áreas de trabalho",
        "natureza": "gravar",
        "argv": _meow("areas", "alfinetar-primeira"),
        "escreve": True, "sudo": False, "confirma": True,
        "indisponivel": _areas_ja_alfinetadas,
        "ajuda": "Cria a primeira área fixada no monitor que está ligado agora, "
                 "com o primeiro nome da sua lista. Vale no próximo início de sessão.",
    },
    "areas_reverter": {
        "rotulo": "Áreas de antes",
        "grupo": "Áreas de trabalho",
        "natureza": "devolver",
        "argv": _meow("areas", "reverter"),
        "escreve": True, "sudo": False, "confirma": True,
        "ajuda": "Devolve o arquivo como estava antes da primeira gravação daqui.",
    },
    "areas_desalfinetar": {
        "rotulo": "Tirar uma área",
        "grupo": "Áreas de trabalho",
        "natureza": "tirar",
        "argv": _meow("areas", "desalfinetar", "@ARG@"), "arg": "areas",
        "escreve": True, "sudo": False, "confirma": True, "destrutivo": True,
        "ajuda": "Apaga a área: o nome some e o COSMIC a destrói quando ela esvaziar.",
        "ambiente": {"MEOW_SIM": "1"},
    },
    "wallpaper_desbanir": {
        "rotulo": "Devolver ao carrossel",
        "grupo": "Papel de parede",
        "natureza": "devolver",
        "argv": _meow("wallpaper", "desbanir", "@ARG@"), "arg": "paredes_banidas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Volta para a pasta que gira e sai da lista de banidas — as "
                 "duas metades.",
    },
    "painel_estado": {
        "rotulo": "Painel agora",
        "grupo": "Painel e dock",
        "natureza": "mostrar",
        "argv": _meow("painel", "estado"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "O estado do painel, da dock e do serviço que cuida dos dois.",
    },
    "painel_teto": {
        "rotulo": "Teto dos cantos",
        "grupo": "Painel e dock",
        "natureza": "mostrar",
        "argv": _meow("painel", "teto"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "A conta inteira: a altura de verdade, o teto que sai dela, e "
                 "se o compositor corta o excesso em vez de derrubar o painel.",
    },
    "painel_reciclar": {
        "rotulo": "Recarregar o painel",
        "grupo": "Painel e dock",
        "natureza": "reciclar",
        "argv": _meow("painel", "reciclar"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "O painel pisca uns 2 s. É o que faz um mascote novo "
                 "aparecer na hora.",
    },
    "leitura": {
        "rotulo": "Tela quente agora",
        "grupo": "Modo de leitura",
        "natureza": "mostrar",
        "argv": _meow("leitura"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Que degrau o relógio pede, o que a tela mostra, e se o "
                 "compositor sabe ler os dois números.",
    },
    "leitura_aplicar": {
        "rotulo": "Esquentar agora",
        "grupo": "Modo de leitura",
        "natureza": "aplicar",
        "argv": _meow("leitura", "aplicar"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Põe agora o que o agendamento poria sozinho.",
    },
    "leitura_remover": {
        "rotulo": "Desligar agora",
        "grupo": "Modo de leitura",
        "natureza": "tirar",
        "argv": _meow("leitura", "remover"),
        "escreve": True, "sudo": False, "confirma": True,
        "ajuda": "Zera temperatura e textura, e desarma o agendamento.",
    },
    "files_menu": {
        "rotulo": "Menu agora",
        "grupo": "Papel de parede",
        "natureza": "mostrar",
        "argv": _meow("files-menu"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Os dois itens de papel de parede no botão direito.",
    },
    "files_menu_build": {
        "rotulo": "Construir o menu",
        "grupo": "Papel de parede",
        "natureza": "baixar",
        "argv": _meow("files-menu", "build"),
        "escreve": True, "sudo": False, "confirma": True, "rede": True,
        "ajuda": "Compila a versão instalada do cosmic-files com os dois itens "
                 "de papel de parede. Baixa o fonte e leva minutos.",
    },
    "apps": {
        "rotulo": "Programas vestidos",
        "grupo": "Lançadores e jogos",
        "natureza": "conferir",
        "argv": _meow("apps"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Um por linha: se está instalado, e se o tema já foi aplicado.",
    },
    "apps_aplicar": {
        "rotulo": "Vestir os programas",
        "grupo": "Lançadores e jogos",
        "natureza": "aplicar",
        "argv": _meow("apps", "aplicar"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Aplica o tema em todos os programas marcados que estiverem "
                 "instalados. Programa ausente fica pendente, e nunca "
                 "derruba o resto.",
    },
    "apps_tema_do_pack": {
        "rotulo": "Trocar o tema",
        "grupo": "Lançadores e jogos",
        "natureza": "trocar",
        "argv": _meow("apps", "aplicar", "@ARG@"), "arg": "apps_de_terceiro",
        "ambiente": {"MEOW_TEMA_DE_TERCEIRO": "trocar"},
        "escreve": True, "sudo": False, "confirma": True, "destrutivo": True,
        "oculta": True,
        "ajuda": "Troca o tema que o programa tem agora pelo do pack no ar.",
    },
    "apps_manter_o_meu": {
        "rotulo": "Manter o tema",
        "grupo": "Lançadores e jogos",
        "natureza": "gravar",
        "argv": _meow("apps", "aplicar", "@ARG@"), "arg": "apps_de_terceiro",
        "ambiente": {"MEOW_TEMA_DE_TERCEIRO": "manter"},
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "O tema de agora fica, e o MeowSystem para de perguntar "
                 "enquanto o programa estiver nele.",
    },
    "vscode_instalar_extensao": {
        "rotulo": "Instalar a extensão",
        "grupo": "Lançadores e jogos",
        "natureza": "baixar",
        "argv": _meow("apps", "aplicar", "vscode"), "arg": "extensoes_de_terceiro",
        "ambiente": {"MEOW_VSCODE_EXTENSAO": "@ARG@"},
        "escreve": True, "sudo": False, "confirma": True, "rede": True,
        "oculta": True,
        "ajuda": "Instala no VS Code, da loja oficial e pelo id do botão, a extensão "
                 "que o pack importado pede. Extensão é código que roda a cada "
                 "abertura do editor.",
    },
    "jogos": {
        "rotulo": "Conferir os jogos",
        "grupo": "Lançadores e jogos",
        "natureza": "conferir",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_steam.sh"), "--conferir"],
        "escreve": False, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Lista atalho a criar, atalho a remover e arquivo a apagar. "
                 "Não escreve nada.",
    },
    "jogos_aplicar": {
        "rotulo": "Arrumar os jogos",
        "grupo": "Lançadores e jogos",
        "natureza": "aplicar",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_steam.sh")],
        "escreve": True, "sudo": False, "confirma": True, "destrutivo": True,
        "oculta": True,
        "ajuda": "Põe um atalho por jogo instalado e tira o dos que saíram. "
                 "Jogo marcado para apagar tem a pasta removida — uma vez "
                 "só, e nunca com a Steam aberta.",
    },
    "jogos_heroic": {
        "rotulo": "Conferir o Heroic",
        "grupo": "Lançadores e jogos",
        "natureza": "conferir",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_heroic.sh"), "--conferir"],
        "escreve": False, "sudo": False, "confirma": False,
        "par": "jogos_heroic_aplicar",
        "ajuda": "Lista atalho a criar e atalho a remover. Não escreve nada.",
    },
    "jogos_heroic_aplicar": {
        "rotulo": "Jogos do Heroic",
        "grupo": "Lançadores e jogos",
        "natureza": "aplicar",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_heroic.sh"), "--aplicar"],
        "escreve": True, "sudo": False, "confirma": False,
        "oculta": True,
        "ajuda": "Um atalho por jogo instalado no Heroic, com a capa que ele "
                 "já baixou. Some o do jogo desinstalado.",
    },
    "jogos_heroic_tirar": {
        "rotulo": "Tirar um jogo",
        "grupo": "Lançadores e jogos",
        "natureza": "tirar",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_heroic.sh"), "--aplicar"],
        "arg": "jogos_heroic", "ambiente": {"MEOW_HEROIC_TIRAR": "@ARG@"},
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "O cartão do jogo sai do lançador; o jogo continua no Heroic.",
    },
    "jogos_heroic_por": {
        "rotulo": "Pôr um jogo",
        "grupo": "Lançadores e jogos",
        "natureza": "aplicar",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_heroic.sh"), "--aplicar"],
        "arg": "jogos_heroic", "ambiente": {"MEOW_HEROIC_POR": "@ARG@"},
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "O cartão do jogo volta ao lançador.",
    },
}


CACHE = os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
    "meowsystem", "painel",
)

EXT_DIRETAS = {".svg"}
EXT_RASTER = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".avif"}


def _cursor_para_rgba(caminho, tamanho_alvo=48):
    with open(caminho, "rb") as fh:
        dados = fh.read()
    if len(dados) < 16 or dados[:4] != b"Xcur":
        return None
    cab, _versao, n = struct.unpack_from("<III", dados, 4)
    melhor = None
    for i in range(n):
        base = cab + i * 12
        if base + 12 > len(dados):
            break
        tipo, subtipo, pos = struct.unpack_from("<III", dados, base)
        if tipo != 0xFFFD0002:
            continue
        peso = (0 if subtipo <= tamanho_alvo else 1, abs(subtipo - tamanho_alvo))
        if melhor is None or peso < melhor[0]:
            melhor = (peso, pos)
    if melhor is None:
        return None

    pos = melhor[1]
    if pos + 36 > len(dados):
        return None
    _t, _tipo, _sub, _v, larg, alt, _xh, _yh, _atraso = struct.unpack_from("<9I", dados, pos)
    if not (0 < larg <= 512 and 0 < alt <= 512):
        return None
    inicio = pos + 36
    fim = inicio + larg * alt * 4
    if fim > len(dados):
        return None

    cru = dados[inicio:fim]
    saida = bytearray(len(cru))
    for i in range(0, len(cru), 4):
        b, g, r, a = cru[i], cru[i + 1], cru[i + 2], cru[i + 3]
        if a and a != 255:
            r = min(255, r * 255 // a)
            g = min(255, g * 255 // a)
            b = min(255, b * 255 // a)
        saida[i], saida[i + 1], saida[i + 2], saida[i + 3] = r, g, b, a
    return (larg, alt, bytes(saida))


def _prev_gatos():
    pasta = _pasta_do_mascote()
    fora = []
    for nome in _gatos():
        caminho = os.path.join(pasta, nome + ".svg")
        if os.path.isfile(caminho):
            fora.append({"id": nome, "rotulo": nome, "origem": caminho, "grupo": "acervo"})
    return fora


def _wallpaper_base():
    base = valores_efetivos(["WALLPAPER_BASE"]).get("WALLPAPER_BASE") or ""
    return base or os.path.expanduser("~/.local/share/backgrounds/meowsystem")


GRUPOS_PAREDE = (("ativos", "ativos"), ("noite", "ativos-noite"),
                 ("dia", "ativos-dia"), ("favoritos", "favoritos"),
                 ("banidos", "banidos"))


_LADO_CACHE = {"mapa": {}, "marca": None}


def _lado_caminho():
    estado = os.path.join(
        os.environ.get("MEOW_ESTADO")
        or os.path.join(os.path.expanduser("~"), ".local", "state", "meowsystem"),
        "papeis-de-parede")
    if os.path.isdir(estado):
        return os.path.join(estado, "lado.tsv")
    return os.path.join(RAIZ, "packs", "meowsystem", "wallpapers", "lado.tsv.padrao")


def _lado_escrito():
    caminho = _lado_caminho()
    try:
        marca = os.path.getmtime(caminho)
    except OSError:
        _LADO_CACHE["mapa"], _LADO_CACHE["marca"] = {}, None
        return {}
    marca = (caminho, marca)
    if _LADO_CACHE["marca"] == marca:
        return _LADO_CACHE["mapa"]
    mapa = {}
    try:
        with open(caminho, "r", encoding="utf-8", errors="replace") as fh:
            for linha in fh:
                linha = linha.strip()
                if not linha or linha.startswith("#"):
                    continue
                partes = linha.split("\t")
                if len(partes) == 2 and partes[1] in ("dia", "noite"):
                    mapa[partes[0]] = partes[1]
    except OSError:
        mapa = {}
    _LADO_CACHE["mapa"], _LADO_CACHE["marca"] = mapa, marca
    return mapa


def _prev_paredes():
    base = _wallpaper_base()
    escolhas = _lado_escrito()
    fora = []
    for grupo, pasta in GRUPOS_PAREDE:
        if grupo == "ativos" and os.path.isdir(os.path.join(base, "ativos-pack")):
            pasta = "ativos-pack"
        caminho = os.path.join(base, pasta)
        try:
            nomes = sorted(os.listdir(caminho))
        except OSError:
            continue
        for nome in nomes:
            arq = os.path.join(caminho, nome)
            if os.path.splitext(nome)[1].lower() not in EXT_RASTER:
                continue
            if not os.path.isfile(arq):
                continue
            canonico = os.path.join(base, "ativos", nome)
            fora.append({"id": grupo + "/" + nome, "rotulo": nome,
                         "origem": arq, "grupo": grupo,
                         "lado": escolhas.get(nome, ""),
                         "favorito": os.path.isfile(os.path.join(base, "favoritos", nome)),
                         "banir": canonico if os.path.isfile(canonico) else ""})
    return fora


def _prev_icones():
    tema = valores_efetivos(["NOME_TEMA_ICONES"]).get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
    raiz = os.path.join(os.path.expanduser("~/.local/share/icons"), os.path.basename(tema))
    fora, vistos = [], set()
    for sub in ("48x48/apps", "scalable/apps", "64x64/apps"):
        pasta = os.path.join(raiz, sub)
        try:
            nomes = sorted(os.listdir(pasta))
        except OSError:
            continue
        for nome in nomes:
            base, ext = os.path.splitext(nome)
            if ext.lower() not in EXT_DIRETAS | EXT_RASTER or base in vistos:
                continue
            vistos.add(base)
            fora.append({"id": base, "rotulo": base,
                         "origem": os.path.join(pasta, nome), "grupo": sub})
    return fora


@_uma_vez_por_leitura
def _prev_cursores():
    fora = []
    do_pack = _ponteiro_do_pack()
    for valor in _temas_de_cursor():
        alvo = None
        for pasta_tema in _cursor_pastas_do_valor(valor, do_pack):
            for cand in ("left_ptr", "default"):
                caminho = os.path.join(pasta_tema, "cursors", cand)
                if os.path.isfile(caminho):
                    alvo = os.path.realpath(caminho)
                    break
            if alvo:
                break
        if alvo:
            fora.append({"id": valor, "rotulo": valor, "origem": alvo,
                         "grupo": "cursor"})
    return fora


def _tipo_de_previa(chave, opcoes, faixa, padrao):
    if opcoes:
        conjunto = set(opcoes)
        gatos = set(_gatos())
        if gatos and conjunto <= gatos:
            return "gato"
        paleta = _paleta_dados()
        flavors = set(paleta.get("flavors", {}))
        if flavors and conjunto <= flavors:
            return "flavor"
        cores = set(paleta.get("ordem_canonica") or [])
        if cores and conjunto <= cores:
            return "cor"
    if not opcoes and padrao in set(_paleta_dados().get("ordem_canonica") or []):
        return "cor"
    if chave.startswith("FORMA_") or chave.startswith("VIDRO_"):
        return "barra"
    if chave == "AREAS_FOLGA":
        return "areas"
    if chave.startswith("LEITURA_") and faixa:
        lo, hi = faixa[0], faixa[1]
        if lo <= 2000 and 5000 <= hi <= 10000:
            return "kelvin"
        if lo == 0 and hi == 1:
            return "textura"
    if padrao and any(c["id"] == padrao for c in _prev_cursores()):
        return "cursor"
    return ""


PREVIA_FONTES = {
    "gato": _prev_gatos,
    "parede": _prev_paredes,
    "icone": _prev_icones,
    "cursor": _prev_cursores,
}
PREVIA_GRUPOS = {"parede": [g for g, _pasta in GRUPOS_PAREDE]}
PREVIA_LARGURA = {"parede": 320, "gato": 0, "icone": 0, "cursor": 96}


def _previa_chave(item, tipo):
    try:
        st = os.stat(item["origem"])
    except OSError:
        return None
    cru = "%s|%s|%s|%s" % (item["origem"], st.st_mtime_ns, st.st_size,
                           PREVIA_LARGURA.get(tipo, 0))
    return hashlib.sha1(cru.encode("utf-8")).hexdigest()


def _previa_destino(item, tipo):
    chave = _previa_chave(item, tipo)
    if chave is None:
        return None
    ext = ".png" if tipo == "cursor" else ".webp"
    return os.path.join(CACHE, tipo, chave + ext)


def _previa_direta(item):
    return os.path.splitext(item["origem"])[1].lower() in EXT_DIRETAS


def _previa_pronta(item, tipo):
    if _previa_direta(item):
        return True
    destino = _previa_destino(item, tipo)
    return bool(destino) and os.path.isfile(destino)


def _gerar_previa(item, tipo):
    destino = _previa_destino(item, tipo)
    if destino is None or os.path.isfile(destino):
        return
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    tmp = destino + ".parcial"
    try:
        if tipo == "cursor":
            desenho = _cursor_para_rgba(item["origem"], PREVIA_LARGURA["cursor"])
            if not desenho:
                return
            larg, alt, rgba = desenho
            subprocess.run(
                ["convert", "-size", "%dx%d" % (larg, alt), "-depth", "8",
                 "rgba:-", "-background", "none",
                 "-resize", "%dx%d>" % (PREVIA_LARGURA["cursor"], PREVIA_LARGURA["cursor"]),
                 "png:" + tmp],
                input=rgba, capture_output=True, timeout=30, check=True,
            )
        else:
            largura = PREVIA_LARGURA.get(tipo, 320) or 320
            subprocess.run(
                ["convert", "-auto-orient", "-thumbnail", "%dx" % largura,
                 "-quality", "82", item["origem"], "webp:" + tmp],
                capture_output=True, timeout=60, check=True,
            )
        os.replace(tmp, destino)
    except (OSError, subprocess.SubprocessError):
        try:
            os.unlink(tmp)
        except OSError:
            pass


PREVIA_FILA = queue.Queue()
PREVIA_ANDANDO = set()
PREVIA_TRAVA = threading.Lock()


def _operario():
    while True:
        item, tipo, chave = PREVIA_FILA.get()
        try:
            _gerar_previa(item, tipo)
        finally:
            with PREVIA_TRAVA:
                PREVIA_ANDANDO.discard(chave)
            PREVIA_FILA.task_done()


def _enfileirar(item, tipo):
    chave = _previa_chave(item, tipo)
    if chave is None:
        return
    with PREVIA_TRAVA:
        if chave in PREVIA_ANDANDO:
            return
        PREVIA_ANDANDO.add(chave)
    PREVIA_FILA.put((item, tipo, chave))


def previas(tipo, grupo=None):
    fonte = PREVIA_FONTES.get(tipo)
    if fonte is None:
        return None
    itens = fonte()
    if tipo == "parede":
        itens = [i for i in itens if not (i["grupo"] == "banidos" and i["banir"])]
    contagens = {g: 0 for g in PREVIA_GRUPOS.get(tipo, ())}
    for i in itens:
        contagens[i["grupo"]] = contagens.get(i["grupo"], 0) + 1
    total = len(itens)
    if grupo:
        itens = [i for i in itens if i["grupo"] == grupo]
    fora, faltam = [], 0
    for item in itens:
        pronta = _previa_pronta(item, tipo)
        if not pronta:
            faltam += 1
            _enfileirar(item, tipo)
        saida = {
            "id": item["id"], "rotulo": item["rotulo"], "grupo": item["grupo"],
            "pronta": pronta, "origem": item["origem"],
            "url": "/previa?tipo=%s&id=%s" % (tipo, quote(item["id"], safe="")),
        }
        for extra, quanto in item.items():
            if extra not in ("id", "rotulo", "origem", "grupo", "url"):
                saida[extra] = quanto
        fora.append(saida)
    return {"tipo": tipo, "itens": fora, "faltam": faltam,
            "contagens": contagens, "total": total}


def previa_bytes(tipo, ident):
    fonte = PREVIA_FONTES.get(tipo)
    if fonte is None:
        return None
    item = next((i for i in fonte() if i["id"] == ident), None)
    if item is None:
        return None
    if _previa_direta(item):
        try:
            with open(item["origem"], "rb") as fh:
                return (fh.read(), "image/svg+xml")
        except OSError:
            return None
    destino = _previa_destino(item, tipo)
    if not destino or not os.path.isfile(destino):
        _enfileirar(item, tipo)
        return None
    try:
        with open(destino, "rb") as fh:
            return (fh.read(), "image/png" if tipo == "cursor" else "image/webp")
    except OSError:
        return None


def _carimbo():
    return time.strftime("%Y%m%d-%H%M")


def exportar_conf():
    linhas_cabecalho = [
        "# meow.conf — exportado pelo painel do MeowSystem em %s"
        % time.strftime("%d/%m/%Y às %H:%M"),
        "#",
        "# Este arquivo é um meow.conf inteiro e válido. Para restaurar, use o",
        "# botão Importar do painel (que grava chave a chave, validando cada uma)",
        "# ou copie-o por cima de ~/.config/meow/meow.conf e rode `meow aplicar`.",
        "#",
    ]
    try:
        with open(CONF, "r", encoding="utf-8") as fh:
            corpo = fh.read()
        linhas_cabecalho.append("# Origem: %s" % texto_na_tela(CONF))
    except OSError:
        esquema = ler_esquema()
        brutos = valores_brutos()
        partes, secao = [], None
        for item in esquema:
            if item.get("secao") != secao:
                secao = item.get("secao")
                partes.append("\n# --- %s" % (secao or "Outras"))
            partes.append('%s="%s"' % (item["chave"], brutos.get(item["chave"], "")))
        corpo = "\n".join(partes) + "\n"
        linhas_cabecalho.append(
            "# Origem: o catálogo (%s ainda não existia nesta máquina)"
            % texto_na_tela(CONF))
    return ("\n".join(linhas_cabecalho) + "\n\n" + corpo,
            "meow-%s.conf" % _carimbo())


def importar_conf(texto):
    esquema = {i["chave"]: i for i in ler_esquema()}
    brutos = valores_brutos()
    relatorio = {"mudam": [], "iguais": [], "recusadas": [], "desconhecidas": []}

    pares = {}
    for linha in texto.split("\n"):
        crua = linha.strip()
        if crua.startswith("export "):
            crua = crua[len("export "):]
        achado = RE_CHAVE.match(crua)
        if achado:
            pares[achado.group(1)] = _valor_da_linha(crua)
    for antigo, novo in chaves_renomeadas().items():
        if antigo in pares:
            valor = pares.pop(antigo)
            pares.setdefault(novo, valor)

    for chave, valor in pares.items():
        item = esquema.get(chave)
        if item is None:
            relatorio["desconhecidas"].append(chave)
            continue
        queixa = validar_valor(item, valor)
        if queixa:
            relatorio["recusadas"].append(
                {"chave": chave, "valor": valor, "erro": queixa})
        elif brutos.get(chave, "") == valor:
            relatorio["iguais"].append(chave)
        else:
            relatorio["mudam"].append(
                {"chave": chave, "valor": valor, "de": brutos.get(chave, "")})

    relatorio["ausentes"] = [c for c in esquema if c not in pares]
    return relatorio


def _parametros_de(detalhe, suavidade, cheia=False, fracas=0, minimo=0):
    def _regua(v, padrao):
        try:
            return max(0, min(10, int(v)))
        except (TypeError, ValueError):
            return padrao
    d = _regua(detalhe, 6)
    s = _regua(suavidade, 2)
    f = _regua(fracas, 0)
    m = _regua(minimo, 0)
    k = 2 + d
    funde = 100 - 8 * d
    tol = round(0.4 + 0.3 * s, 1)
    argv = ["--k", str(k), "--funde", str(funde), "--tol", "%g" % tol]
    if f:
        argv += ["--peso-fronteira", str(40 + 3 * f)]
    if m:
        argv += ["--min-traco", "%g" % round(3.2 + 0.8 * m, 1)]
    if cheia:
        argv.append("--cheia")
    return argv, " ".join(argv)


_RE_PARAMETROS_DESENHO = re.compile(
    r"^--k (\d{1,2}) --funde (\d{1,3}) --tol (\d{1,2}(?:\.\d)?)"
    r"(?: --peso-fronteira (\d{1,3}))?"
    r"(?: --min-traco (\d{1,2}(?:\.\d)?))?"
    r"( --cheia)?$")


def _parametros_relidos(texto):
    achado = _RE_PARAMETROS_DESENHO.match((texto or "").strip())
    if not achado:
        return None
    k, funde, tol = int(achado.group(1)), int(achado.group(2)), float(achado.group(3))
    if not (2 <= k <= 16 and 0 <= funde <= 120 and 0.2 <= tol <= 8.0):
        return None
    argv = ["--k", str(k), "--funde", str(funde), "--tol", "%g" % tol]
    if achado.group(4) is not None:
        peso = int(achado.group(4))
        if not (1 <= peso <= 120):
            return None
        argv += ["--peso-fronteira", str(peso)]
    if achado.group(5) is not None:
        minimo = float(achado.group(5))
        if not (0.1 <= minimo <= 24.0):
            return None
        argv += ["--min-traco", "%g" % minimo]
    if achado.group(6):
        argv.append("--cheia")
    return argv


PRESETS_DESENHO = (
    ("fiel", "Fiel", 6, 2, False, "icone", 0, 0),
    ("limpo", "Limpo", 2, 6, False, "icone", 0, 0),
    ("silhueta", "Silhueta", 0, 4, False, "icone", 0, 0),
    ("detalhe", "Detalhe", 10, 1, False, "icone", 0, 0),
    ("cheia", "Área cheia", 4, 4, True, "icone", 0, 0),
    ("capa", "Da capa", 3, 5, False, "capa", 0, 0),
)

_CACHE_DESENHO = {}
_CACHE_DESENHO_TETO = 64
_CACHE_DESENHO_TRAVA = threading.Lock()
_CONVERSOR_CHEIA = None
_CONVERSOR_CHEIA_TRAVA = threading.Lock()

_OFICINA_RASCUNHO = os.path.join(ESTADO, "oficina")

_ICONES_DECLARADOS = set()

_LANCADORES_SVG = (("xdg-open",), ("gio", "open"))
_EDITOR_SVG = None
_EDITOR_SVG_TRAVA = threading.Lock()


def _conversor_tem_cheia():
    global _CONVERSOR_CHEIA
    with _CONVERSOR_CHEIA_TRAVA:
        if _CONVERSOR_CHEIA is None:
            _CONVERSOR_CHEIA = False
            conversor = os.path.join(RAIZ, "scripts", "converter_icone.py")
            if os.path.isfile(conversor):
                try:
                    r = subprocess.run([sys.executable, conversor, "--help"],
                                       capture_output=True, text=True, timeout=20)
                    _CONVERSOR_CHEIA = "--cheia" in ((r.stdout or "") + (r.stderr or ""))
                except (OSError, subprocess.SubprocessError):
                    _CONVERSOR_CHEIA = False
        return _CONVERSOR_CHEIA


def _nota_do_conversor(saida):
    linhas = [l.strip() for l in (saida or "").splitlines() if l.strip()]
    if not linhas:
        return ""
    nota = linhas[-1]
    if ": " in nota:
        nota = nota.split(": ", 1)[1]
    return nota[:200]


def _converter_desenho(origem, argv_extra, texto_parametros):
    try:
        mtime = os.path.getmtime(origem)
    except OSError:
        return "", "", "a arte de origem sumiu do disco"
    chave = (origem, mtime, texto_parametros)
    with _CACHE_DESENHO_TRAVA:
        achado = _CACHE_DESENHO.get(chave)
    if achado is not None:
        return achado[0], achado[1], ""
    conversor = os.path.join(RAIZ, "scripts", "converter_icone.py")
    if not os.path.isfile(conversor):
        return "", "", "falta scripts/converter_icone.py"
    saida = tempfile.NamedTemporaryFile(suffix=".svg", delete=False)
    saida.close()
    try:
        r = subprocess.run([sys.executable, conversor, origem, saida.name] + list(argv_extra),
                           capture_output=True, text=True, timeout=60)
        if r.returncode != 0:
            return "", "", ("o conversor recusou esta arte: %s"
                            % (r.stderr or "").strip()[:300])
        with open(saida.name, "r", encoding="utf-8") as fh:
            svg = fh.read()
    except (OSError, subprocess.SubprocessError) as e:
        return "", "", "o conversor falhou: %s" % e
    finally:
        try:
            os.unlink(saida.name)
        except OSError:
            pass
    nota = _nota_do_conversor(r.stderr)
    with _CACHE_DESENHO_TRAVA:
        _CACHE_DESENHO[chave] = (svg, nota)
        while len(_CACHE_DESENHO) > _CACHE_DESENHO_TETO:
            _CACHE_DESENHO.pop(next(iter(_CACHE_DESENHO)))
    return svg, nota, ""


def _nome_no_appinfo(caminho, appid):
    with open(caminho, "rb") as fh:
        cabeca = fh.read(16)
        if len(cabeca) < 8:
            return ""
        versao = struct.unpack_from("<I", cabeca, 0)[0]
        if versao not in (0x07564427, 0x07564428, 0x07564429):
            return ""
        pos, tabela = 8, None
        if versao == 0x07564429:
            inicio = struct.unpack_from("<q", cabeca, pos)[0]
            pos += 8
            fh.seek(inicio)
            final = fh.read()
            quantos = struct.unpack_from("<I", final, 0)[0]
            tabela = final[4:].split(b"\0", quantos)[:quantos]
        fixo = 4 + 4 + 8 + 20 + 4 + (20 if versao != 0x07564427 else 0)
        fh.seek(pos)
        while True:
            par = fh.read(8)
            if len(par) < 8:
                return ""
            este, tamanho = struct.unpack("<II", par)
            if este == 0:
                return ""
            if este != appid:
                fh.seek(tamanho, os.SEEK_CUR)
                continue
            dados = fh.read(tamanho)
            break
        p, fim, pilha = fixo, len(dados), []
        while p < fim:
            tipo = dados[p]
            p += 1
            if tipo == 8:
                if not pilha:
                    return ""
                pilha.pop()
                continue
            if tabela is not None:
                nome = tabela[struct.unpack_from("<I", dados, p)[0]]
                p += 4
            else:
                corte = dados.index(b"\0", p)
                nome, p = dados[p:corte], corte + 1
            if tipo == 0:
                pilha.append(nome.lower())
            elif tipo == 1:
                corte = dados.index(b"\0", p)
                valor, p = dados[p:corte], corte + 1
                if pilha == [b"appinfo", b"common"] and nome.lower() == b"name":
                    return valor.decode("utf-8", "replace").strip()
            elif tipo in (2, 3, 4, 6):
                p += 4
            elif tipo in (7, 10):
                p += 8
            else:
                return ""
        return ""


class Trabalho:

    _seq = 0
    _trava = threading.Lock()

    def __init__(self, acao_id, argv, ambiente, rotulo, ao_terminar=None):
        with Trabalho._trava:
            Trabalho._seq += 1
            self.id = Trabalho._seq
        self.acao = acao_id
        self.rotulo = rotulo
        self.argv = argv
        self._ao_terminar = ao_terminar
        self.linhas = []
        self.rc = None
        self.comeco = time.time()
        self.fim = None
        self._lock = threading.Lock()
        self.proc = subprocess.Popen(
            argv,
            cwd=RAIZ,
            env=ambiente,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        threading.Thread(target=self._ler, daemon=True).start()

    PRAZO_DO_CANO = 2.0

    def _bombear(self):
        try:
            for bruta in self.proc.stdout:
                linha = bruta.decode("utf-8", "replace").rstrip("\n")
                with self._lock:
                    self.linhas.append(linha)
        except (OSError, ValueError):
            pass

    def _ler(self):
        leitor = threading.Thread(target=self._bombear, daemon=True)
        leitor.start()
        rc = self.proc.wait()
        leitor.join(self.PRAZO_DO_CANO)
        self.rc = rc
        _ponte_cache["quando"] = 0.0
        if self._ao_terminar is not None:
            try:
                self._ao_terminar()
            except Exception:
                pass
        self.fim = time.time()

    def desde(self, n):
        with self._lock:
            return list(self.linhas[n:]), len(self.linhas)

    def vivo(self):
        return self.fim is None

    def parar(self):
        if not self.vivo():
            return False
        try:
            os.killpg(os.getpgid(self.proc.pid), signal.SIGTERM)
        except (OSError, ProcessLookupError):
            return False
        return True


TRABALHOS = {}
TRABALHO_ATUAL = None
TRABALHO_TRAVA = threading.Lock()

RESTAUROS = os.path.join(ESTADO, "restauros")
_RESTAUROS_TRAVA = threading.Lock()


def _tem_tocados(pasta):
    try:
        return os.path.getsize(os.path.join(pasta, "tocados.tsv")) > 0
    except OSError:
        return False


def restauros():
    try:
        with open(os.path.join(RESTAUROS, "ultimos.json"), "r", encoding="utf-8") as fh:
            dados = json.load(fh)
    except (OSError, ValueError):
        return {}
    if not isinstance(dados, dict):
        return {}
    return {a: p for a, p in dados.items()
            if a in ACOES and isinstance(p, str)
            and os.path.dirname(os.path.realpath(p)) == os.path.realpath(RESTAUROS)
            and _tem_tocados(p)}


def _gravar_restauros(dados):
    os.makedirs(RESTAUROS, exist_ok=True)
    tmp = os.path.join(RESTAUROS, ".ultimos.json.tmp")
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(dados, fh, ensure_ascii=False, indent=1)
    os.replace(tmp, os.path.join(RESTAUROS, "ultimos.json"))


def _guardar_restauro(acao_id, pasta):
    with _RESTAUROS_TRAVA:
        dados = restauros()
        if not _tem_tocados(pasta):
            shutil.rmtree(pasta, ignore_errors=True)
            return
        velha = dados.get(acao_id)
        dados[acao_id] = pasta
        _gravar_restauros(dados)
        if velha and velha != pasta:
            shutil.rmtree(velha, ignore_errors=True)


def _esquecer_restauro(acao_id, pasta):
    with _RESTAUROS_TRAVA:
        dados = restauros()
        if dados.get(acao_id) == pasta:
            del dados[acao_id]
            _gravar_restauros(dados)
        shutil.rmtree(pasta, ignore_errors=True)


def _nome_de_arquivo(texto):
    import unicodedata
    plano = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", plano.lower()).strip("-") or "acao"


def guardar_log(trabalho):
    pasta = os.path.join(ESTADO, "logs")
    os.makedirs(pasta, exist_ok=True)
    nome = "%s-%s.log" % (time.strftime("%Y-%m-%d-%H%M%S", time.localtime(trabalho.comeco)),
                          _nome_de_arquivo(trabalho.rotulo))
    linhas, _ = trabalho.desde(0)
    caminho = os.path.join(pasta, nome)
    with open(caminho, "w", encoding="utf-8") as fh:
        fh.write("# %s\n# %s\n# saiu %s\n\n" % (trabalho.rotulo, comando_na_tela(trabalho.argv), trabalho.rc))
        fh.write("\n".join(linhas) + "\n")
    return caminho


def escreve(acao):
    return bool(acao.get("escreve"))



ACAO_DA_PENDENCIA = {
    "areas-sem-alfinete": "areas_alfinetar_primeira",
    "files-menu-build": "files_menu_build",
    "instalar-com-root": "instalar",
    "flatpak-global-sistema": "instalar",
    "libreoffice-sistema": "instalar",
    "leitura-applet": "doctor_consertar",
    "starship-ausente": "instalar",
}

RECUSA_DA_PENDENCIA = {
    "starship-ausente": [os.path.join(RAIZ, "scripts", "prompt.sh"),
                         "nao-quero-starship"],
}

SUFIXO_TEMA_DE_TERCEIRO = "-tema-de-terceiro"
ESCOLHA_TEMA_DE_TERCEIRO = (("apps_tema_do_pack", "Trocar"),
                            ("apps_manter_o_meu", "Manter"))
ESCOLHA_PAREDE = (("wallpaper_permitir", "Manter"),
                  ("wallpaper_dispensar", "Deixar assim"))


PENDENCIA_EXTENSAO = "vscode-extensao-de-terceiro"

PENDENCIA_PAREDE = "wallpaper-fonte-revertida"
PREFIXO_PERMITIR = "meow wallpaper permitir "


def _fontes_revertidas():
    return sorted({p["comando"][len(PREFIXO_PERMITIR):] for p in pendencias()
                   if p["id"] == PENDENCIA_PAREDE and p["comando"].startswith(PREFIXO_PERMITIR)
                   and len(p["comando"]) > len(PREFIXO_PERMITIR)})
RE_EXTENSAO = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9-]*$")


def _extensoes_de_terceiro():
    mod = modulo_pack()
    if not mod:
        return []
    vals = valores_efetivos(["PACK", "FLAVOR"])
    try:
        ident, dir_pack, _r = mod.adocao(vals.get("PACK") or "", vals.get("FLAVOR") or "")
        dir_pack = dir_pack or mod.achar(ident) or ""
    except Exception:
        return []
    do_repo = os.path.realpath(os.path.join(RAIZ, "packs"))
    if not dir_pack or os.path.realpath(dir_pack).startswith(do_repo + os.sep):
        return []
    fora = []
    for trilha in ("apps.vscode.origem.extensao", "apps.vscode-icones.origem.extensao"):
        try:
            quem, valor = mod.tema_de_app(trilha, ref=dir_pack)
        except Exception:
            continue
        if quem == ident and isinstance(valor, str) and RE_EXTENSAO.match(valor) \
                and valor not in fora:
            fora.append(valor)
    return fora


def _app_da_pendencia(ident):
    if not ident.endswith(SUFIXO_TEMA_DE_TERCEIRO):
        return ""
    app = ident[:-len(SUFIXO_TEMA_DE_TERCEIRO)]
    if not re.match(r"^[a-z0-9][a-z0-9-]*$", app):
        return ""
    modulo = os.path.join(RAIZ, "scripts", "temas-de-apps", app, "manifesto.sh")
    return app if os.path.isfile(modulo) else ""


_LUGARES = {}


def _js_para_json(texto):
    saida, i, n = [], 0, len(texto)
    while i < n:
        c = texto[i]
        if c == '"':
            j = i + 1
            while texto[j] != '"':
                j += 2 if texto[j] == "\\" else 1
            saida.append(texto[i:j + 1])
            i = j + 1
        elif texto.startswith("/*", i):
            i = texto.index("*/", i) + 2
        elif texto.startswith("//", i):
            i = texto.find("\n", i) if "\n" in texto[i:] else n
        elif c.isalpha() or c == "_":
            j = i
            while j < n and (texto[j].isalnum() or texto[j] == "_"):
                j += 1
            k = j
            while k < n and texto[k] in " \t\n":
                k += 1
            palavra = texto[i:j]
            saida.append('"%s"' % palavra if k < n and texto[k] == ":" else palavra)
            i = j
        else:
            saida.append(c)
            i += 1
    return re.sub(r",(\s*[}\]])", r"\1", "".join(saida))


def _consts_do_painel():
    caminho = os.path.join(RAIZ, "app", "pagina", "lugares.js")
    try:
        marca = (caminho, os.path.getmtime(caminho))
        if _LUGARES.get("marca") == marca:
            return _LUGARES["consts"]
        with open(caminho, encoding="utf-8") as fh:
            fonte = fh.read()
        c = {m.group(1): json.loads(_js_para_json(m.group(2)))
             for m in re.finditer(r"(?ms)^const (\w+) = (.*?^[\]}]);", fonte)}
    except (OSError, ValueError):
        return {}
    _LUGARES.clear()
    _LUGARES.update(marca=marca, consts=c)
    return c


def nome_da_porta(ident):
    return next((p["nome"] for p in _consts_do_painel().get("PORTAS", []) if p.get("id") == ident), "")


def porta_das_pendencias():
    return nome_da_porta("cuidar")


def inventario_do_painel():
    c = _consts_do_painel()
    if not c:
        return []
    if "tabela" in _LUGARES:
        return _LUGARES["tabela"]
    saida = []

    def pus(l, porta, pagina, bloco, mais=False):
        base = {"porta": porta, "pagina": pagina, "bloco": bloco, "mais": mais,
                "rotulo": l.get("r"), "botao": l.get("b")}
        for tipo, campo in (("chave", "c"), ("acao", "a"), ("gesto", "g")):
            if campo in l:
                for ident in (l[campo] if isinstance(l[campo], list) else [l[campo]]):
                    saida.append(dict(base, tipo=tipo, id=ident))
                break

    tema, cuidar = c["LUGAR_TEMA"], c["LUGAR_CUIDAR"]
    for l in tema["packs"]:
        pus(l, "tema", "Tema", "Temas")
    for b in tema["blocos"]:
        for l in b["linhas"]:
            pus(l, "tema", "Tema", b["titulo"])
    for l in tema["mais"]:
        pus(l, "tema", "Tema", "Mais ajustes", True)
    for p in c["PASSOS"]:
        for l in p["linhas"]:
            pus(l, "criar", p["nome"], p["nome"])
        for l in p.get("mais", []):
            pus(l, "criar", p["nome"], "Mais ajustes", True)
    for p in c["AJUSTES"]:
        for l in p.get("cabeca", []):
            pus(l, "ajustes", p["nome"], p["nome"])
        for b in p["blocos"]:
            for l in b["linhas"]:
                pus(l, "ajustes", p["nome"], b["titulo"])
        for l in p.get("mais", []):
            pus(l, "ajustes", p["nome"], "Mais ajustes", True)
    for l in cuidar["estado"]:
        pus(l, "cuidar", "Cuidar", "Estado")
    for l in cuidar["pendencias"]:
        pus(l, "cuidar", "Cuidar", "Pendências")
    for cartao in cuidar["cartoes"]:
        for l in cartao["linhas"]:
            pus(l, "cuidar", "Cuidar", cartao["titulo"])
    for b in cuidar["blocos"]:
        for l in b["linhas"]:
            pus(l, "cuidar", "Cuidar", b["titulo"])
    for l in cuidar["perigo"]:
        pus(l, "cuidar", "Cuidar", "Zona de perigo")
    for l in cuidar["mais"]:
        pus(l, "cuidar", "Cuidar", "Mais ajustes", True)
    for l in c["LUGAR_TOPO"]:
        pus(l, "topo", "Barra de cima", "Barra de cima")
    for l in c["LUGAR_JANELA"]:
        pus(l, "janela", "Janela do trabalho", "Janela do trabalho")
    _LUGARES["tabela"] = saida
    return saida


def _caminho_na_tela(l):
    porta = l["pagina"] if l["porta"] in ("topo", "janela") else nome_da_porta(l["porta"])
    base = porta if l["porta"] in ("tema", "cuidar", "topo", "janela") else "%s › %s" % (porta, l["pagina"])
    if l["mais"]:
        return base + " › Mais ajustes"
    if l["bloco"] and l["bloco"] not in (l["pagina"], base):
        return base + " › " + l["bloco"]
    return base


def onde_na_tela(ident):
    pendencias = porta_das_pendencias()
    if not pendencias:
        return ""
    if ident in ACAO_DA_PENDENCIA:
        return "«Resolver», em %s" % pendencias
    if _app_da_pendencia(ident):
        return "%s, em %s" % (" ou ".join("«%s»" % r for _a, r in ESCOLHA_TEMA_DE_TERCEIRO),
                              pendencias)
    if ident == PENDENCIA_EXTENSAO:
        return "«Instalar», em %s" % pendencias
    if ident == PENDENCIA_PAREDE:
        return "%s, em %s" % (" ou ".join("«%s»" % r for _a, r in ESCOLHA_PAREDE), pendencias)
    if ident == "inicio":
        return "em %s" % pendencias
    if (ACOES.get(ident) or {}).get("oculta"):
        return ""
    l = next((l for l in inventario_do_painel() if l["id"] == ident and l["tipo"] in ("acao", "chave")), None)
    if not l:
        return ""
    nome = l["botao"] if l["tipo"] == "acao" and l["botao"] else l["rotulo"]
    return "«%s», em %s" % (nome, _caminho_na_tela(l))


PENDENCIAS = os.path.join(ESTADO, "pendencias.tsv")


def pendencias():
    fora = []
    try:
        with open(PENDENCIAS, "r", encoding="utf-8") as fh:
            for linha in fh:
                campos = linha.rstrip("\n").split("\t")
                if len(campos) != 5 or not campos[0]:
                    continue
                ident, etapa, frase, comando, quando = campos
                acao = ACAO_DA_PENDENCIA.get(ident, "") if comando else ""
                if acao and (indisponivel(acao) or {}).get("feito"):
                    continue
                app = _app_da_pendencia(ident) if comando else ""
                escolha = [{"acao": a, "argumento": app, "rotulo": r}
                           for a, r in ESCOLHA_TEMA_DE_TERCEIRO] if app else []
                nome = ""
                if ident == PENDENCIA_PAREDE and comando.startswith(PREFIXO_PERMITIR):
                    (permitir, r_permitir), (dispensar, r_dispensar) = ESCOLHA_PAREDE
                    escolha = [{"acao": permitir, "rotulo": r_permitir,
                                "argumento": comando[len(PREFIXO_PERMITIR):]},
                               {"acao": dispensar, "rotulo": r_dispensar,
                                "argumento": ""}]
                    nome = "Papel devolvido"
                if ident == PENDENCIA_EXTENSAO and comando:
                    escolha = [{"acao": "vscode_instalar_extensao", "argumento": e,
                                "rotulo": "Instalar " + e} for e in _extensoes_de_terceiro()]
                    nome = "Extensão do pack"
                if not nome and not acao:
                    nome = ACOES.get(ACAO_DA_PENDENCIA.get(ident, ""), {}).get("rotulo", "")
                rede = any(ACOES.get(a, {}).get("rede") for a in [acao] + [e["acao"] for e in escolha])
                fora.append({
                    "id": ident, "etapa": etapa, "frase": frase,
                    "comando": comando, "quando": quando,
                    "acao": acao,
                    "escolha": escolha,
                    "nome": nome,
                    "recusavel": ident in RECUSA_DA_PENDENCIA,
                    "rede": bool(rede),
                })
    except OSError:
        return []
    return fora

PRECISA_DE_GENTE = os.path.join(ESTADO, "precisa-de-gente.tsv")


def precisa_de_gente():
    fora = []
    try:
        with open(PRECISA_DE_GENTE, "r", encoding="utf-8") as fh:
            for linha in fh:
                campos = linha.rstrip("\n").split("\t")
                if len(campos) != 4 or not campos[0] or not campos[1]:
                    continue
                fora.append(dict(zip(("id", "nome", "desde", "porque"), campos)))
    except OSError:
        return []
    return fora


def _trabalho_json(trabalho, acao_id, seco=False):
    return {"id": trabalho.id, "rotulo": trabalho.rotulo, "acao": acao_id,
            "escreve": escreve(ACOES[acao_id]),
            "seco": bool(seco),
            "conserta_com": ACOES[acao_id].get("conserta_com"),
            "fim": fim_da_acao(acao_id, seco)}


def _previa_dos_jogos(mapa):
    conf = conf_exportada()
    if conf is None:
        return {"erro": "não consegui ler o meow.conf"}
    pasta = tempfile.mkdtemp(prefix="meow-jogos-")
    try:
        copia = os.path.join(pasta, "jogos-fora.map")
        with open(copia, "w", encoding="utf-8") as fh:
            fh.write(mapa)
        ambiente = _ambiente_do_painel(seco=True)
        ambiente.update(conf)
        ambiente.update(MEOW_JOGOS_FORA=copia, MEOW_JOGOS_RESUMO="1", NO_COLOR="1")
        proc = subprocess.run(
            [os.path.join(RAIZ, "scripts", "jogos_steam.sh"), "--conferir"],
            cwd=RAIZ, env=ambiente, stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    except (OSError, subprocess.SubprocessError) as e:
        return {"erro": "não deu para conferir os jogos: %s" % e}
    finally:
        shutil.rmtree(pasta, ignore_errors=True)
    saida = {"entram": [], "saem": [], "repetem": [], "apagam": []}
    campo = {"entra": "entram", "sai": "saem", "repete": "repetem", "apaga": "apagam"}
    for linha in proc.stdout.decode("utf-8", "replace").splitlines():
        partes = linha.split(" ", 3)
        if len(partes) == 4 and partes[0] == "@@jogo" and partes[1] in campo \
                and partes[2].isdigit():
            saida[campo[partes[1]]].append({"appid": partes[2], "nome": partes[3].strip()})
    return saida


def jogos_do_heroic():
    try:
        r = subprocess.run([os.path.join(RAIZ, "scripts", "jogos_heroic.sh"), "--listar"],
                           capture_output=True, timeout=30, env=_ambiente_do_painel(seco=True))
    except (OSError, subprocess.SubprocessError):
        return []
    fora = []
    capas = os.path.expanduser("~/.local/share/icons/hicolor/256x256/apps")
    for linha in r.stdout.decode("utf-8", "replace").splitlines():
        campos = linha.split("\t")
        if len(campos) != 4 or not campos[0].startswith("meow-heroic-"):
            continue
        capa = os.path.join(capas, campos[0] + ".png")
        fora.append({"id": campos[0], "nome": campos[1],
                     "url": ("/previa?tipo=arquivo&id=" + quote(capa, safe=""))
                            if os.path.isfile(capa) else "",
                     "no_lancador": campos[3] == "sim"})
    return fora


def _guardar_antes_py(pasta, caminho, conteudo):
    alvo = os.path.realpath(caminho)
    os.makedirs(pasta, exist_ok=True)
    if conteudo is None:
        linha = "%s\tnovo\n" % alvo
    else:
        copia = pasta + "/antes" + alvo
        os.makedirs(os.path.dirname(copia), exist_ok=True)
        with open(copia, "wb") as fh:
            fh.write(conteudo)
        linha = "%s\texistia\n" % alvo
    with open(os.path.join(pasta, "tocados.tsv"), "a", encoding="utf-8") as fh:
        fh.write(linha)


def iniciar(acao_id, argumento, confirmado=False, seco=False, pasta_de_ensaio=None,
            antes=None):
    global TRABALHO_ATUAL
    acao = ACOES.get(acao_id)
    if acao is None:
        return (None, "ação desconhecida")

    if indisponivel(acao_id):
        return (None, "«%s» não teria efeito agora — o cartão diz por quê"
                      % acao["rotulo"])

    if acao.get("confirma") and not confirmado:
        return (None, {
            "erro": "esta ação escreve na máquina e precisa de confirmação",
            "precisa_confirmar": True,
            "acao": acao_id,
            "rotulo": acao["rotulo"],
            "ajuda": acao.get("ajuda", ""),
            "escreve": escreve(acao),
            "sudo": bool(acao.get("sudo")),
            "rede": bool(acao.get("rede")),
            "destrutivo": bool(acao.get("destrutivo")),
        })

    argv = list(acao["argv"])
    amb_acao = dict(acao.get("ambiente", {}))
    if "@ARG@" in argv or "@ARG@" in amb_acao.values():
        permitidos = PROVEDORES[acao["arg"]]()
        if argumento not in permitidos:
            return (None, "argumento fora da lista do disco: %r" % (argumento,))
        argv = [argumento if p == "@ARG@" else p for p in argv]
        amb_acao = {k: (argumento if v == "@ARG@" else v) for k, v in amb_acao.items()}
    elif argumento:
        return (None, "esta ação não recebe argumento")
    rotulo = acao["rotulo"]
    pasta_restauro = None
    if acao_id == "restaurar":
        pasta_restauro = restauros().get(argumento)
        if not pasta_restauro:
            return (None, "não há o que restaurar nessa ação")
        argv = [pasta_restauro if p == argumento else p for p in argv]
        rotulo = "Restaurar «%s»" % ACOES[argumento]["rotulo"]

    conf_do_ensaio = os.path.join(pasta_de_ensaio, "meow.conf") if pasta_de_ensaio else None
    conf = conf_exportada(conf_do_ensaio)
    if conf is None:
        return (None, "não consegui ler o meow.conf — sem ele o trabalho rodaria "
                      "com cada chave no padrão, e por isso não roda")
    ambiente = _ambiente_do_painel(seco)
    ambiente.update(conf)
    ambiente.update(amb_acao)
    if conf_do_ensaio:
        ambiente["MEOW_CONF"] = conf_do_ensaio
        pasta_dela = os.path.dirname(CONF)
        ambiente.setdefault("MEOW_ICONES_ESCOLHAS",
                            _mapa_de_escolhas_do_usuario())
        ambiente.setdefault("MEOW_ICONES_TRACO",
                            os.path.join(pasta_dela, "icones-traco.map"))
        mapa_do_ensaio = os.path.join(pasta_de_ensaio, "jogos-fora.map")
        if os.path.isfile(mapa_do_ensaio):
            ambiente["MEOW_JOGOS_FORA"] = mapa_do_ensaio
    if ambiente.get("LOG_NIVEL", "") != "debug":
        ambiente["LOG_NIVEL"] = "info"
    ambiente["NO_COLOR"] = "1"

    if escreve(acao) and not seco and acao_id != "restaurar":
        pasta_restauro = os.path.join(RESTAUROS, "%s-%s-%s" % (
            time.strftime("%Y%m%dT%H%M%S"), acao_id, secrets.token_hex(3)))
        ambiente["MEOW_BACKUPS"] = pasta_restauro
        for caminho, conteudo in (antes or {}).items():
            try:
                _guardar_antes_py(pasta_restauro, caminho, conteudo)
            except OSError:
                pass
    vivo = {}

    def ao_terminar():
        if pasta_de_ensaio:
            shutil.rmtree(pasta_de_ensaio, ignore_errors=True)
        t = vivo.get("t")
        if acao_id == "restaurar":
            if t is not None and t.rc in (0, 1):
                _esquecer_restauro(argumento, pasta_restauro)
        elif pasta_restauro:
            _guardar_restauro(acao_id, pasta_restauro)

    with TRABALHO_TRAVA:
        if TRABALHO_ATUAL is not None and TRABALHO_ATUAL.vivo():
            if acao_id != "restaurar" and pasta_restauro:
                shutil.rmtree(pasta_restauro, ignore_errors=True)
            return (None, "já há um trabalho correndo: %s" % TRABALHO_ATUAL.rotulo)
        try:
            trabalho = Trabalho(acao_id, argv, ambiente, rotulo, ao_terminar=ao_terminar)
        except OSError as erro:
            if acao_id != "restaurar" and pasta_restauro:
                shutil.rmtree(pasta_restauro, ignore_errors=True)
            return (None, str(erro))
        vivo["t"] = trabalho
        trabalho.pasta_restauro = pasta_restauro if acao_id != "restaurar" else None
        TRABALHOS[trabalho.id] = trabalho
        TRABALHO_ATUAL = trabalho
    return (trabalho, None)


TIPOS = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".svg": "image/svg+xml",
    ".json": "application/json; charset=utf-8",
}


_medidas_cache = {"carimbo": None, "valor": None}


def _medidas_do_projeto():
    inst = os.path.join(RAIZ, "install.sh")
    cli = os.path.join(RAIZ, "bin", "meow")
    try:
        carimbo = tuple((os.path.getmtime(f), os.path.getsize(f))
                        for f in (inst, cli))
    except OSError:
        return {"etapas": None, "conferencias": None}
    if _medidas_cache["carimbo"] == carimbo:
        return _medidas_cache["valor"]

    def ler(caminho):
        try:
            with open(caminho, encoding="utf-8", errors="replace") as fh:
                return fh.read()
        except OSError:
            return ""

    etapas = None
    m = re.search(r"^\s*local etapas=\(([^)]*)\)", ler(inst), re.M)
    if m:
        nomes = re.findall(r"\betapa_[a-z_0-9]+\b", m.group(1))
        if nomes:
            etapas = len(set(nomes))

    conferencias = None
    m = re.search(r"^VERIFICAVEIS=\(([^)]*)\)", ler(cli), re.M)
    if m:
        nomes = m.group(1).split()
        if nomes:
            conferencias = len(set(nomes))

    valor = {"etapas": etapas, "conferencias": conferencias}
    _medidas_cache["carimbo"] = carimbo
    _medidas_cache["valor"] = valor
    return valor


def _medidas_da_tela():
    barra = {}
    for nome, (_suf, pasta) in zip(("painel", "dock"), _BARRAS):
        m = re.match(r"^(?:Some\()?%s\)?$" % _DEGRAU, _cosmic_ler(pasta + "size") or "")
        if m:
            barra[nome] = m.group(1)
    try:
        with open(os.path.join(RAIZ, "lib", "painel.sh"), encoding="utf-8") as fh:
            texto = fh.read()
    except OSError:
        texto = ""
    regua = {}
    corpo = re.search(r"^meow_painel_T\(\)\s*\{(.*?)^\}", texto, re.M | re.S)
    if corpo:
        for nome, px in re.findall(r"^\s*%s\)\s*printf '(\d+)'" % _DEGRAU, corpo.group(1), re.M):
            regua[nome] = int(px)
    return {"barra": barra, "tamanho_applet": regua}


def _com_medidas(texto, medidas):
    n = (medidas or {}).get("etapas")
    texto = texto.replace("{as_etapas}", "as %d etapas" % n if n else "as etapas")
    n = (medidas or {}).get("conferencias")
    return texto.replace("{as_conferencias}",
                         "as %d conferências" % n if n else "as conferências")


def _repositorio_no_ar():
    try:
        proc = subprocess.run(["git", "-C", RAIZ, "remote", "get-url", "origin"],
                              capture_output=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return ""
    if proc.returncode != 0:
        return ""
    url = proc.stdout.decode("utf-8", "replace").strip()
    if not url:
        return ""
    m = re.match(r"^(?:git@|ssh://git@)([^:/]+)[:/](.+?)(?:\.git)?/?$", url)
    if m:
        host = m.group(1).split("-", 1)[0] if "." in m.group(1) else m.group(1)
        return "https://%s/%s" % (host, m.group(2))
    m = re.match(r"^(https?://[^/]+/.+?)(?:\.git)?/?$", url)
    return m.group(1) if m else ""


def idiomas_da_sessao():
    brutos = [v for v in os.environ.get("LANGUAGE", "").split(":") if v]
    brutos += [os.environ[n] for n in ("LC_ALL", "LC_MESSAGES", "LANG") if os.environ.get(n)][:1]
    fora = []
    for bruto in brutos:
        base, _arroba, modificador = bruto.partition("@")
        base = base.split(".", 1)[0]
        if base in ("", "C", "POSIX"):
            continue
        lingua, _sublinha, pais = base.partition("_")
        for v in ("%s_%s@%s" % (lingua, pais, modificador) if pais and modificador else "",
                  "%s_%s" % (lingua, pais) if pais else "",
                  "%s@%s" % (lingua, modificador) if modificador else "",
                  lingua):
            if v and v not in fora:
                fora.append(v)
    return fora


class Manipulador(BaseHTTPRequestHandler):
    server_version = "MeowSystem"
    sys_version = ""
    protocol_version = "HTTP/1.1"

    def log_message(self, formato, *args):
        if os.environ.get("MEOW_APP_DEBUG") == "1":
            sys.stderr.write("  .. %s\n" % (formato % args))

    def _host_confere(self):
        host = (self.headers.get("Host") or "").strip()
        porta = self.server.server_address[1]
        return host in ("127.0.0.1:%d" % porta, "localhost:%d" % porta)

    def _origem_confere(self):
        origem = self.headers.get("Origin")
        if not origem:
            return True
        porta = self.server.server_address[1]
        return origem in ("http://127.0.0.1:%d" % porta, "http://localhost:%d" % porta)

    def _token_confere(self, consulta):
        for dado in (self.headers.get("X-Meow-Token") or "",
                     consulta.get("t", [""])[0],
                     self._cookie()):
            if dado and hmac.compare_digest(dado, TOKEN):
                return True
        return False

    def _cookie(self):
        bruto = self.headers.get("Cookie") or ""
        for pedaco in bruto.split(";"):
            nome, _, valor = pedaco.strip().partition("=")
            if nome == "meow_token":
                return valor
        return ""

    def _recusar(self, codigo, texto):
        corpo = texto.encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)

    def _responder(self, corpo, tipo="application/json; charset=utf-8", codigo=200,
                   plantar_cookie=False, extras=None):
        if isinstance(corpo, str):
            corpo = corpo.encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(corpo)))
        if plantar_cookie:
            self.send_header(
                "Set-Cookie",
                "meow_token=%s; Path=/; SameSite=Strict; HttpOnly" % TOKEN,
            )
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        extras = dict(extras or {})
        if tipo.startswith("image/"):
            extras["Content-Security-Policy"] = CSP_DE_IMAGEM
        for nome, valor in extras.items():
            self.send_header(nome, valor)
        self.end_headers()
        self.wfile.write(corpo)

    def _json(self, dados, codigo=200):
        self._responder(json.dumps(dados, ensure_ascii=False), codigo=codigo)

    def _pulso(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        _pulso_entra()
        try:
            while True:
                self.wfile.write(b": meow\n\n")
                self.wfile.flush()
                pronto, _, _ = select.select([self.connection], [], [], PULSO_BATIDA)
                if pronto and not self.connection.recv(1):
                    break
        except (OSError, ValueError):
            pass
        finally:
            _pulso_sai()

    def _logo_do_painel(self):
        valores = valores_efetivos(["FLAVOR", "ACCENT", "MODO"])
        flavor = _flavor_do_conf(valores)
        flavor = _flavor_da_pagina(flavor, valores)
        return logo_do_painel(flavor, _acento_da_pagina(flavor, valores))

    def do_GET(self):
        alvo = urlparse(self.path)
        consulta = parse_qs(alvo.query)
        if not self._host_confere():
            return self._recusar(403, "Host inesperado")
        if not self._origem_confere():
            return self._recusar(403, "Origem inesperada")
        caminho = alvo.path

        if caminho in ("/", "/index.html"):
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            return self._servir_pagina()

        if caminho.startswith("/api/"):
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            if caminho == "/api/pulso":
                return self._pulso()
            return self._api_get(caminho, consulta)

        if caminho == "/folha":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            nome_folha = os.path.basename(consulta.get("id", [""])[0] or "")
            alvo_folha = os.path.realpath(os.path.join(FOLHAS, nome_folha))
            if (not alvo_folha.startswith(os.path.realpath(FOLHAS) + os.sep)
                    or not alvo_folha.endswith(".html")
                    or not os.path.isfile(alvo_folha)):
                return self._recusar(404, "não achei")
            try:
                with open(alvo_folha, "rb") as fh:
                    dados_folha = fh.read()
            except OSError:
                return self._recusar(404, "não achei")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header(
                "Content-Security-Policy",
                "default-src 'none'; img-src data: blob:; "
                "style-src 'unsafe-inline'; script-src 'unsafe-inline'; "
                "font-src data:")
            self.send_header("Content-Length", str(len(dados_folha)))
            self.end_headers()
            self.wfile.write(dados_folha)
            return None



        if caminho == "/logo.svg":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            corpo = self._logo_do_painel()
            if corpo is None:
                return self._recusar(404, "a logo autoral não está no acervo")
            return self._responder(corpo, tipo=TIPOS[".svg"])

        if caminho == "/gato.svg":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            nome = os.path.basename(valores_efetivos(["LOGO"]).get("LOGO") or "coquinha")
            arquivo = os.path.join(_pasta_do_mascote(), nome + ".svg")
            if not os.path.isfile(arquivo):
                gatos = _gatos()
                if not gatos:
                    return self._recusar(404, "não há mascote no acervo")
                arquivo = os.path.join(_pasta_do_mascote(), gatos[0] + ".svg")
            with open(arquivo, "rb") as fh:
                return self._responder(fh.read(), tipo=TIPOS[".svg"])

        if caminho == "/pack-vitrine":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            achado = arte_da_vitrine(consulta.get("id", [""])[0],
                                     consulta.get("arte", [""])[0])
            if achado is None:
                return self._recusar(404, "não achei")
            corpo, tipo_mime = achado
            return self._responder(corpo, tipo=tipo_mime)

        if caminho == "/som":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            mod = modulo_pack()
            ident = consulta.get("pack", [""])[0]
            evento = consulta.get("evento", [""])[0]
            dir_pack = mod.achar(ident) if mod and ident in _packs_no_disco() else None
            achado = next((a for _c, e, a in mod.sons_do_pack(dir_pack) if e == evento),
                          None) if dir_pack else None
            if not achado:
                return self._recusar(404, "não achei")
            try:
                with open(achado, "rb") as fh:
                    return self._responder(fh.read(), tipo="audio/ogg")
            except OSError:
                return self._recusar(404, "não achei")

        if caminho == "/sino":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            pares = []
            esquema = {i["chave"]: i for i in ler_esquema()}
            for chave in _SOM_TIMBRE_DE_FABRICA:
                valor = consulta.get(chave, [""])[0]
                if valor == "":
                    continue
                queixa = validar_valor(esquema[chave], valor) if chave in esquema else "fora do meow.conf.exemplo"
                if queixa:
                    return self._recusar(400, "%s: %s" % (chave, queixa))
                pares.append("%s=%s" % (chave, valor))
            with tempfile.TemporaryDirectory(prefix="meow-sino-") as pasta:
                destino = os.path.join(pasta, "sino.wav")
                feito = subprocess.run(
                    ["bash", os.path.join(RAIZ, "scripts", "som.sh"), "gerar", destino, *pares],
                    capture_output=True, timeout=20, env=_ambiente_do_painel())
                if feito.returncode != 0 or not os.path.isfile(destino):
                    return self._recusar(500, "não consegui gerar o sino")
                with open(destino, "rb") as fh:
                    return self._responder(fh.read(), tipo="audio/wav")

        if caminho == "/previa" and consulta.get("tipo", [""])[0] == "arquivo":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            permitidos = set()
            for x in (os.path.join(RAIZ, "packs"),
                      os.path.expanduser("~/.local/share/icons"),
                      os.path.expanduser("~/.local/share/flatpak/exports/share/icons"),
                      "/usr/share/icons",
                      "/usr/share/pixmaps",
                      "/var/lib/flatpak/exports/share/icons",
                      os.path.expanduser("~/.local/share/Steam"),
                      os.path.expanduser("~/.steam")):
                if os.path.isdir(x):
                    permitidos.add(os.path.normpath(x))
                    permitidos.add(os.path.realpath(x))
            pedido = os.path.normpath(consulta.get("id", [""])[0] or "")
            alvo_arq = os.path.realpath(pedido)
            ok_pasta = any(pedido.startswith(p + os.sep) or alvo_arq.startswith(p + os.sep)
                           for p in permitidos) or pedido in _ICONES_DECLARADOS
            ext_arq = os.path.splitext(pedido)[1].lower()
            ext_alvo = os.path.splitext(alvo_arq)[1].lower()
            if ext_alvo != ext_arq or not os.path.isfile(alvo_arq):
                return self._recusar(404, "não achei")
            if not ok_pasta or ext_arq not in (".svg", ".png", ".jpg", ".jpeg"):
                return self._recusar(404, "não achei")
            try:
                with open(alvo_arq, "rb") as fh:
                    dados_arq = fh.read()
            except OSError:
                return self._recusar(404, "não achei")
            tipo_mime = {".svg": "image/svg+xml", ".png": "image/png",
                         ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}[ext_arq]
            if ext_arq != ".svg" and comeca_como_svg(dados_arq):
                tipo_mime = "image/svg+xml"
            return self._responder(dados_arq, tipo=tipo_mime)

        if caminho == "/previa":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            achado = previa_bytes(consulta.get("tipo", [""])[0],
                                  consulta.get("id", [""])[0])
            if achado is None:
                return self._recusar(404, "prévia ainda não gerada")
            corpo, tipo_mime = achado
            return self._responder(corpo, tipo=tipo_mime)

        if caminho == "/paleta.css":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            valores = valores_efetivos(["FLAVOR", "ACCENT", "MODO"])
            flavor = _flavor_do_conf(valores)
            flavor = _flavor_da_pagina(flavor, valores)
            return self._responder(paleta_css(flavor, _acento_da_pagina(flavor, valores)),
                                   tipo="text/css; charset=utf-8")

        nome = os.path.basename(caminho)
        raiz_ext = os.path.splitext(nome)[1]
        if raiz_ext in TIPOS and nome:
            arquivo = os.path.join(PAGINA, nome)
            if os.path.isfile(arquivo):
                if not self._token_confere(consulta):
                    return self._recusar(403, "token de sessão ausente ou errado")
                with open(arquivo, "rb") as fh:
                    return self._responder(fh.read(), tipo=TIPOS[raiz_ext])
        return self._recusar(404, "não existe aqui")

    ACERVOS = {
        "gato": {
            "casa": "pasta_do_mascote",
            "extensoes": (".svg",),
            "normaliza": True,
            "depois": "o vigia põe o mascote novo no acervo em segundos",
        },
        "parede": {
            "pasta": ("packs", "meowsystem", "wallpapers", "ativos"),
            "extensoes": (".jpg", ".jpeg", ".png", ".webp"),
            "normaliza": False,
            "depois": "o carrossel passa a sortear a imagem nova",
        },
        "icone": {
            "casa": "pasta_de_enviados",
            "extensoes": (".svg",),
            "normaliza": True,
            "depois": "o desenho aparece na ficha de ícone, na pasta «enviados»",
        },
        "cursor": {
            "comando": ("cursor", "adicionar"),
            "extensoes": (".zip",),
            "depois": "escolha o tema novo em \"Tema do ponteiro\" e salve",
        },
        "fonte": {
            "comando": ("fontes", "adicionar"),
            "extensoes": (".zip", ".ttf", ".otf"),
            "depois": "a fonte já está registrada; escolha-a onde quiser usá-la",
        },
        "tema-icones": {
            "comando": ("icones", "adicionar"),
            "extensoes": (".zip",),
            "depois": "escolha o tema novo em «Tema de onde herdar» e reconstrua",
        },
    }

    def _acervo_por_comando(self, conf, nome, corpo):
        import base64 as _b64
        import tempfile

        try:
            dados = _b64.b64decode(str(corpo.get("conteudo", "")), validate=True)
        except Exception:
            return self._json({"erro": "conteúdo não é base64"}, 400)
        if not dados:
            return self._json({"erro": "arquivo vazio"}, 400)
        if len(dados) > 64 << 20:
            return self._json({"erro": "arquivo maior que 64 MB"}, 413)

        with tempfile.TemporaryDirectory(prefix="meow-envio-") as pasta:
            caminho = os.path.join(pasta, nome)
            try:
                with open(caminho, "wb") as fh:
                    fh.write(dados)
            except OSError as e:
                return self._json({"erro": "não consegui gravar: %s" % e}, 500)
            try:
                r = subprocess.run(_meow(*conf["comando"], caminho),
                                   capture_output=True, text=True, timeout=300)
            except Exception as e:
                return self._json({"erro": "não consegui rodar: %s" % e}, 500)

        bruta = ((r.stdout or "") + (r.stderr or "")).strip()
        bruta = re.sub(r"(?<![\w/.~-])" + re.escape(RAIZ) + r"(?![\w.-])", ".", bruta)
        saida = texto_na_tela(bruta)
        if r.returncode >= 2:
            return self._json({"erro": saida or "o comando falhou", "rc": r.returncode}, 500)
        return self._json({
            "ok": True, "nome": nome, "rc": r.returncode, "log": saida,
            "depois": (conf["depois"] if r.returncode == 1
                       else "%s já estava instalado" % nome),
        })

    def _api_acervo(self, corpo):
        import base64 as _b64
        import re as _re

        tipo = str(corpo.get("tipo", ""))
        conf = self.ACERVOS.get(tipo)
        if not conf:
            return self._json({"erro": "acervo desconhecido"}, 400)

        nome = os.path.basename(str(corpo.get("nome", "")))
        nome = _re.sub(r"[^A-Za-z0-9._-]", "-", nome).lstrip(".-")[:80]
        if not nome:
            return self._json({"erro": "nome de arquivo vazio"}, 400)
        ext = os.path.splitext(nome)[1].lower()
        if ext not in conf["extensoes"]:
            return self._json(
                {"erro": "só aceito %s aqui" % ", ".join(conf["extensoes"])}, 400)

        if "comando" in conf:
            return self._acervo_por_comando(conf, nome, corpo)
        if nome.endswith("-symbolic.svg"):
            return self._json({"erro": "nome terminado em -symbolic.svg vira silhueta"}, 400)

        try:
            dados = _b64.b64decode(str(corpo.get("conteudo", "")), validate=True)
        except Exception:
            return self._json({"erro": "conteúdo não é base64"}, 400)
        if not dados:
            return self._json({"erro": "arquivo vazio"}, 400)
        if len(dados) > 12 << 20:
            return self._json({"erro": "arquivo maior que 12 MB"}, 413)
        if ext == ".svg" and b"<svg" not in dados[:4096].lower():
            return self._json({"erro": "isso não parece um SVG"}, 400)

        if "casa" in conf:
            mod = modulo_pack()
            if not mod:
                return self._json({"erro": "não achei o scripts/pack.py"}, 500)
            destino_dir = getattr(mod, conf["casa"])()
        else:
            destino_dir = os.path.join(RAIZ, *conf["pasta"])
        try:
            os.makedirs(destino_dir, exist_ok=True)
        except OSError as e:
            return self._json({"erro": "não consegui criar %s: %s" % (destino_dir, e)}, 500)
        destino = os.path.join(destino_dir, nome)
        substituiu = os.path.exists(destino)

        tmp = destino + ".meow-parcial"
        try:
            with open(tmp, "wb") as fh:
                fh.write(dados)
            os.replace(tmp, destino)
        except OSError as e:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            return self._json({"erro": "não consegui gravar: %s" % e}, 500)

        normalizado = ""
        if conf["normaliza"]:
            script = os.path.join(RAIZ, "scripts", "normalizar_svg.py")
            if os.path.isfile(script):
                try:
                    r = subprocess.run([sys.executable, script, destino],
                                       capture_output=True, text=True, timeout=30)
                    normalizado = (r.stdout or "").strip()
                except Exception:
                    normalizado = ""

        grupo = self._grupo_de_luz(destino) if tipo == "parede" else None

        return self._json({
            "ok": True,
            "nome": nome,
            "destino": destino,
            "substituiu": substituiu,
            "normalizado": normalizado,
            "grupo": grupo,
            "depois": conf["depois"],
        })

    def _grupo_de_luz(self, caminho):
        exe = shutil.which("magick") or shutil.which("convert")
        if not exe:
            return None
        try:
            r = subprocess.run(
                [exe, "-quiet", "-define", "jpeg:size=256x256", caminho + "[0]",
                 "-resize", "128x128", "-colorspace", "Gray",
                 "-format", "%[fx:mean]", "info:"],
                capture_output=True, text=True, timeout=20)
            luz = float((r.stdout or "").strip())
        except Exception:
            return None
        try:
            corte = float((valores_brutos() or {}).get("WALLPAPER_LIMIAR_LUZ") or 0.37)
        except (TypeError, ValueError):
            corte = 0.37
        if not 0 <= corte <= 1:
            corte = 0.37
        return {"lado": "dia" if luz >= corte else "noite",
                "luz": round(luz, 3), "corte": corte}

    DIRS_DESKTOP = (
        ("/usr/share/applications", "sistema"),
        ("/usr/local/share/applications", "local"),
        ("~/.local/share/applications", "pessoal"),
        ("/var/lib/flatpak/exports/share/applications", "flatpak"),
        ("~/.local/share/flatpak/exports/share/applications", "flatpak"),
        ("/var/lib/snapd/desktop/applications", "snap"),
    )

    def _desktops(self):
        vistos = {}
        idiomas = idiomas_da_sessao()
        for bruto, origem in self.DIRS_DESKTOP:
            pasta = os.path.expanduser(bruto)
            if not os.path.isdir(pasta):
                continue
            try:
                nomes = sorted(os.listdir(pasta))
            except OSError:
                continue
            for arq in nomes:
                if not arq.endswith(".desktop"):
                    continue
                ident = arq[: -len(".desktop")]
                caminho = os.path.join(pasta, arq)
                dados = {"id": ident, "nome": ident, "icone": "", "origem": origem,
                         "arquivo": caminho, "oculto": False, "categorias": "", "mime": ""}
                traduzidos = {}
                try:
                    with open(caminho, "r", encoding="utf-8", errors="replace") as fh:
                        em_entrada = False
                        for linha in fh:
                            linha = linha.strip()
                            if linha.startswith("["):
                                em_entrada = linha == "[Desktop Entry]"
                                continue
                            if not em_entrada:
                                continue
                            if linha.startswith("Name=") and dados["nome"] == ident:
                                dados["nome"] = linha[5:].strip()
                            elif linha.startswith("Name["):
                                idioma, igual, valor = linha[5:].partition("]=")
                                if igual and valor.strip():
                                    traduzidos.setdefault(idioma, valor.strip())
                            elif linha.startswith("Icon="):
                                dados["icone"] = linha[5:].strip()
                            elif linha.startswith("Categories="):
                                dados["categorias"] = linha[11:].strip()
                            elif linha.startswith("MimeType="):
                                dados["mime"] = linha[9:].strip()
                            elif linha.startswith(("NoDisplay=", "Hidden=")):
                                if linha.split("=", 1)[1].strip().lower() == "true":
                                    dados["oculto"] = True
                except OSError:
                    continue
                dados["nome"] = next((traduzidos[i] for i in idiomas if i in traduzidos),
                                     dados["nome"])
                vistos[ident] = dados
        return sorted(vistos.values(), key=lambda d: d["nome"].lower())

    def _mapa_convertidos(self):
        fora = {}
        for caminho, meu in ((os.path.join(ICONES_DO_MOTOR, "apps-convertidos.map"), False),
                             (_mapa_de_convertidos_do_usuario(), True)):
            try:
                with open(caminho, "r", encoding="utf-8") as fh:
                    for linha in fh:
                        corte = linha.strip()
                        if not corte or corte.startswith("#"):
                            continue
                        campos = [c.strip() for c in corte.split(":")]
                        if len(campos) >= 3:
                            fora[campos[0]] = {"cor": campos[2], "mao": campos[1] == "mao", "meu": meu}
            except OSError:
                pass
        return fora

    def _mapa_dracula(self):
        fora = set()
        _pack = _pack_adotado()
        caminho = ""
        mod = modulo_pack()
        if mod:
            caminho = mod.acervo("icones.apps.mapa",
                                 motor=os.path.join("assets", "icones", "apps-dracula.map"),
                                 ref=_pack or None) or ""
        if not caminho:
            caminho = os.path.join(RAIZ, "assets", "icones", "apps-dracula.map")
        try:
            with open(caminho, "r", encoding="utf-8") as fh:
                for linha in fh:
                    corte = linha.split("#", 1)[0].strip()
                    if not corte or ":" not in corte:
                        continue
                    nome = corte.split(":", 1)[0].strip()
                    if nome:
                        fora.add(nome)
        except OSError:
            pass
        return fora

    def _desenhos_de_pack(self):
        mod = modulo_pack()
        if not mod:
            return {}
        adotado = _pack_adotado()
        indice, vistos = {}, set()
        for base in mod.raizes():
            try:
                ids = sorted(os.listdir(base))
            except OSError:
                continue
            for pid in ids:
                dir_pack = os.path.join(base, pid)
                if pid in vistos or not os.path.isfile(os.path.join(dir_pack, "pack.json")):
                    continue
                vistos.add(pid)
                nome_pack = str(mod.campo(dir_pack, "nome", pid) or pid)
                pares = []
                desenhos = mod.campo(dir_pack, "icones.apps.desenhos")
                if isinstance(desenhos, str) and desenhos:
                    try:
                        pasta = mod.resolver_alvo(desenhos, dir_pack)
                    except mod.Recusa:
                        pasta = ""
                    if pasta and os.path.isdir(pasta):
                        pares += [(a[:-len(".svg")], os.path.join(pasta, a))
                                  for a in sorted(os.listdir(pasta)) if a.endswith(".svg")]
                mapa = mod.campo(dir_pack, "icones.apps.mapa")
                linhas = []
                if isinstance(mapa, str) and mapa:
                    try:
                        caminho_mapa = mod.resolver_alvo(mapa, dir_pack)
                        with open(caminho_mapa, "r", encoding="utf-8") as fh:
                            linhas = fh.read().splitlines()
                    except (mod.Recusa, OSError):
                        linhas = []
                for linha in linhas:
                    corte = linha.split("#", 1)[0].strip()
                    if ":" not in corte:
                        continue
                    nome, alvo = (c.strip() for c in corte.split(":", 1))
                    if not nome or not alvo:
                        continue
                    try:
                        pares.append((nome, mod.resolver_alvo(alvo, os.path.dirname(caminho_mapa))))
                    except mod.Recusa:
                        continue
                for nome, caminho in pares:
                    if not caminho.endswith(".svg") or not os.path.isfile(caminho):
                        continue
                    lista = indice.setdefault(nome, [])
                    if not any(c["arquivo"] == caminho for c in lista):
                        lista.append({"pack": pid, "nome_pack": nome_pack,
                                      "arquivo": caminho, "ativo": pid == adotado})
        return indice

    def _cartoes_do_pack(self, d, indice, atual, com_svg=False):
        cartoes, vistos = [], set()
        for nome in (d.get("icone"), d.get("id")):
            for c in indice.get(nome or "", []):
                if c["arquivo"] not in vistos:
                    vistos.add(c["arquivo"])
                    cartoes.append(dict(c))
        if not cartoes:
            return []
        na_tela = None
        if atual and atual.endswith(".svg"):
            try:
                with open(atual, "r", encoding="utf-8", errors="replace") as fh:
                    na_tela = fh.read(400000).rstrip()
            except OSError:
                na_tela = None
        for c in cartoes:
            try:
                with open(c["arquivo"], "r", encoding="utf-8", errors="replace") as fh:
                    texto = fh.read(400000)
            except OSError:
                texto = ""
            c["em_vigor"] = bool(na_tela) and texto.rstrip() == na_tela
            if com_svg:
                c["svg"] = texto
        cartoes.sort(key=lambda c: (not c["em_vigor"], not c["ativo"], c["nome_pack"].lower()))
        return cartoes

    def _quem_veste(self, atual, nosso, cartoes, traco, mapa):
        for c in cartoes:
            if c.get("em_vigor"):
                return {"tipo": "pack", "frase": "o desenho do pack «%s»" % c["nome_pack"]}
        if not atual:
            return {"tipo": "nenhum", "frase": "nenhum ícone"}
        if nosso:
            if os.path.basename(os.path.dirname(os.path.dirname(atual))) == "48x48":
                if traco:
                    return {"tipo": "conversao", "frase": "a conversão em traço do projeto"}
                if mapa:
                    return {"tipo": "arcticons", "frase": "o glifo do Arcticons, em traço"}
            return {"tipo": "projeto", "frase": "um desenho do projeto"}
        return {"tipo": "fabrica", "frase": "o ícone de fábrica"}

    def _mapa_arcticons(self):
        fora = {}
        for caminho, meu in ((os.path.join(ICONES_DO_MOTOR, "apps-arcticons.map"), False),
                             (_mapa_de_traco_do_usuario(), True)):
            try:
                with open(caminho, "r", encoding="utf-8") as fh:
                    for linha in fh:
                        corte = linha.strip()
                        if not corte or corte.startswith("#"):
                            continue
                        campos = [c.strip() for c in corte.split(":")]
                        if len(campos) >= 3:
                            mod = modulo_pack() if "/" in campos[1] else None
                            if mod and hasattr(mod, "caminho_de_hoje"):
                                campos[1] = mod.caminho_de_hoje(campos[1])
                            fora[campos[0]] = {"glifo": campos[1], "cor": campos[2],
                                               "alias": len(campos) > 3 and campos[3] == "alias",
                                               "meu": meu}
            except OSError:
                pass

        if _valor_vivo("ICONES_COR_MARCA") == "sim":
            marca = os.path.join(ICONES_DO_MOTOR, "apps-marca.map")
            try:
                with open(marca, "r", encoding="utf-8") as fh:
                    for linha in fh:
                        corte = linha.strip()
                        if not corte or corte.startswith("#"):
                            continue
                        campos = [c.strip() for c in corte.split(":")]
                        if len(campos) >= 2 and campos[0] in fora and campos[1]:
                            fora[campos[0]]["cor"] = campos[1]
                            fora[campos[0]]["pela_marca"] = True
            except OSError:
                pass
        return fora

    TEMAS_DE_ICONE = ("", "hicolor", "Papirus-Dark", "Papirus", "Adwaita")
    TAMANHOS = ("scalable", "256x256", "128x128", "64x64", "48x48", "32x32", "24x24", "22x22")

    def _icone_na_tela(self, d, base_tema):
        nome = d["icone"] or d["id"]
        if nome.startswith("/") and os.path.isfile(nome):
            if os.path.splitext(nome)[1].lower() in (".svg", ".png", ".jpg", ".jpeg"):
                _ICONES_DECLARADOS.add(os.path.normpath(nome))
                return nome, False
        bases = [(base_tema, True)]
        for raiz_icones in (os.path.expanduser("~/.local/share/icons"),
                            "/usr/share/icons", "/var/lib/flatpak/exports/share/icons",
                            os.path.expanduser("~/.local/share/flatpak/exports/share/icons")):
            for tema in self.TEMAS_DE_ICONE:
                if not tema:
                    continue
                bases.append((os.path.join(raiz_icones, tema), False))
        for base, e_nosso in bases:
            for tam in self.TAMANHOS:
                for ext in (".svg", ".png"):
                    cand = os.path.join(base, tam, "apps", nome + ext)
                    if os.path.isfile(cand):
                        return cand, e_nosso
        for pix in ("/usr/share/pixmaps", os.path.expanduser("~/.local/share/pixmaps")):
            for ext in (".svg", ".png", ".xpm"):
                cand = os.path.join(pix, nome + ext)
                if os.path.isfile(cand) and ext != ".xpm":
                    return cand, False
        return "", False

    def _api_apps(self, consulta):
        return self._json(self._dados_apps(consulta))

    _RE_STEAM = re.compile(r"^(meow-steam-|steam_app_)\d+$")

    def _e_jogo(self, d):
        if self._RE_STEAM.match(d.get("id", "")):
            return True
        cats = [c.strip() for c in (d.get("categorias") or "").lower().split(";") if c.strip()]
        if "game" not in cats:
            return False
        loja = any(m.strip().startswith("x-scheme-handler/") for m in (d.get("mime") or "").split(";"))
        return not loja and "emulator" not in cats

    def _dados_apps(self, consulta):
        busca = (consulta.get("busca", [""])[0] or "").strip().lower()
        mapa = self._mapa_arcticons()
        traco = self._mapa_convertidos()
        pack_dracula = self._mapa_dracula()
        tema = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
        base_tema = os.path.expanduser("~/.local/share/icons/%s" % tema)
        dir_pack = os.path.join(base_tema, "scalable", "apps")
        fora = []
        jogos = 0
        travas = self._travas_do_arcticons()
        indice_pack = self._desenhos_de_pack()
        donos_scalable = self._donos_do_scalable()
        mod = modulo_pack()
        escolhidos = ({n for _num, n, _a in mod.escolhas_do_painel()}
                      if mod and hasattr(mod, "escolhas_do_painel") else set())
        for d in self._desktops():
            if d["oculto"]:
                continue
            if self._e_jogo(d):
                jogos += 1
                continue
            if busca and busca not in d["nome"].lower() and busca not in d["id"].lower():
                continue
            atual, nosso = self._icone_na_tela(d, base_tema)
            do_pack = self._cartoes_do_pack(d, indice_pack, atual)
            traco_app = traco.get(d["id"]) or traco.get(d["icone"])
            vigor = self._quem_veste(atual, nosso, do_pack, traco_app,
                                     mapa.get(d["id"]) or mapa.get(d["icone"]))
            fora.append({
                "id": d["id"], "nome": d["nome"], "icone": d["icone"],
                "origem": d["origem"], "nosso": nosso,
                "url": ("/previa?tipo=arquivo&id=" + quote(atual, safe="")) if atual else "",
                "dracula": bool(
                    atual and os.path.dirname(atual) == dir_pack
                    and (d["icone"] or d["id"]) in pack_dracula),
                "mapa": mapa.get(d["id"]) or mapa.get(d["icone"]) or None,
                "escolhido": bool(
                    atual and os.path.dirname(atual) == dir_pack
                    and ((d["icone"] or "") in escolhidos or d["id"] in escolhidos)),
                "traco": traco.get(d["id"]) or traco.get(d["icone"]) or None,
                "trava": self._motivo_da_trava(
                    travas, [d["id"], d["icone"]], d["nome"], vigor,
                    ["o desenho do pack «%s»" % c["nome_pack"]
                     for c in do_pack if not c["em_vigor"]]),
                "trava_pack": self._trava_do_pack(d, d["nome"], donos_scalable, travas),
            })
        return {"apps": fora, "total": len(fora), "jogos": jogos}

    def _steam_bibliotecas(self):
        raiz = os.path.expanduser("~/.steam/steam")
        brutos = [raiz]
        vdf = os.path.join(raiz, "steamapps", "libraryfolders.vdf")
        try:
            with open(vdf, "r", encoding="utf-8", errors="replace") as fh:
                for linha in fh:
                    achado = re.match(r'\s*"path"\s+"(.+)"\s*$', linha)
                    if achado:
                        brutos.append(achado.group(1))
        except OSError:
            pass
        vistas, fora = set(), []
        for b in brutos:
            real = os.path.realpath(os.path.expanduser(b))
            if real in vistas:
                continue
            vistas.add(real)
            if os.path.isdir(os.path.join(real, "steamapps")):
                fora.append(real)
        return fora

    def _capa_do_jogo(self, appid, vertical=False):
        base = os.path.expanduser("~/.steam/steam/appcache/librarycache/%s" % appid)
        if not os.path.isdir(base):
            return ""
        procurados = ("library_capsule.jpg", "library_600x900.jpg")
        if not vertical:
            procurados += ("library_header.jpg", "header.jpg", "logo.png")
        achados = {}
        for dirpath, _, nomes in os.walk(base):
            for nome in nomes:
                if nome in procurados:
                    caminho = os.path.join(dirpath, nome)
                    try:
                        tam = os.path.getsize(caminho)
                    except OSError:
                        continue
                    if tam > achados.get(nome, (0, ""))[0]:
                        achados[nome] = (tam, caminho)
        for nome in procurados:
            if nome in achados:
                return achados[nome][1]
        return ""

    def _mapa_jogos_fora(self):
        fora = {}
        try:
            with open(MAPA_JOGOS, "r", encoding="utf-8") as fh:
                for linha in fh:
                    corte = linha.strip()
                    if not corte or corte.startswith("#"):
                        continue
                    campos = [c.strip() for c in corte.split(":")]
                    if not campos or not campos[0].isdigit():
                        continue
                    if len(campos) > 1 and campos[1] in ("apagar", "esconder"):
                        acao, motivo = campos[1], ":".join(campos[2:]).strip()
                    else:
                        acao, motivo = "esconder", ":".join(campos[1:]).strip()
                    fora[campos[0]] = {"acao": acao, "motivo": motivo}
        except OSError:
            pass
        return fora

    def _jogos_ja_apagados(self):
        vistos = {}
        try:
            with open(os.path.join(ESTADO, "jogos-apagados"), "r", encoding="utf-8") as fh:
                for linha in fh:
                    campo = linha.split(None, 2)
                    if campo and campo[0].isdigit():
                        vistos[campo[0]] = {
                            "data": campo[1] if len(campo) > 1 else "",
                            "nome": campo[2].strip() if len(campo) > 2 else "",
                        }
        except OSError:
            pass
        return vistos

    _APPINFO = os.path.expanduser("~/.steam/steam/appcache/appinfo.vdf")
    _NOMES_DA_STEAM = {}

    @classmethod
    def _nome_na_steam(cls, appid):
        try:
            carimbo = os.stat(cls._APPINFO).st_mtime_ns
        except OSError:
            return ""
        chave = (carimbo, str(appid))
        if chave not in cls._NOMES_DA_STEAM:
            try:
                cls._NOMES_DA_STEAM[chave] = _nome_no_appinfo(cls._APPINFO, int(appid))
            except (OSError, ValueError, IndexError, struct.error):
                cls._NOMES_DA_STEAM[chave] = ""
        return cls._NOMES_DA_STEAM[chave]

    def _api_jogos(self, consulta):
        return self._json(self._dados_jogos(consulta))

    def _dados_jogos(self, consulta):
        busca = (consulta.get("busca", [""])[0] or "").strip().lower()
        mapa = self._mapa_jogos_fora()
        gastos = self._jogos_ja_apagados()
        apps_dir = os.path.expanduser("~/.local/share/applications")
        fora, vistos = [], set()

        for lib in self._steam_bibliotecas():
            steamapps = os.path.join(lib, "steamapps")
            try:
                nomes = sorted(os.listdir(steamapps))
            except OSError:
                continue
            for arq in nomes:
                achado = re.match(r"^appmanifest_(\d+)\.acf$", arq)
                if not achado:
                    continue
                appid = achado.group(1)
                if appid in vistos:
                    continue
                vistos.add(appid)
                nome, instalado_em = appid, ""
                try:
                    with open(os.path.join(steamapps, arq), "r",
                              encoding="utf-8", errors="replace") as fh:
                        texto = fh.read()
                    m_nome = re.search(r'"name"\s+"(.*)"', texto)
                    m_dir = re.search(r'"installdir"\s+"(.*)"', texto)
                    if m_nome:
                        nome = m_nome.group(1)
                    if m_dir and "/" not in m_dir.group(1):
                        alvo = os.path.join(steamapps, "common", m_dir.group(1))
                        if os.path.isdir(alvo):
                            instalado_em = alvo
                except OSError:
                    pass

                capa = self._capa_do_jogo(appid)
                if not self._capa_do_jogo(appid, vertical=True):
                    continue
                if busca and busca not in nome.lower() and busca != appid:
                    continue

                linha = mapa.get(appid)
                fora.append({
                    "appid": appid,
                    "nome": nome,
                    "url": "/previa?tipo=arquivo&id=" + quote(capa, safe=""),
                    "cartao": os.path.isfile(
                        os.path.join(apps_dir, "meow-steam-%s.desktop" % appid)),
                    "acao": (linha or {}).get("acao", ""),
                    "motivo": (linha or {}).get("motivo", ""),
                    "gasto": appid in gastos,
                    "apagado_em": (gastos.get(appid) or {}).get("data", ""),
                    "no_disco": bool(instalado_em),
                })
        conhecidos = {j["appid"] for j in fora}
        orfas = []
        for appid, linha in mapa.items():
            if appid in conhecidos:
                continue
            if busca and busca not in appid:
                continue
            registro = gastos.get(appid) or {}
            orfas.append({
                "appid": appid,
                "nome": (registro.get("nome") or self._nome_na_steam(appid)
                         or "appid %s" % appid),
                "url": "", "cartao": False,
                "acao": linha["acao"], "motivo": linha["motivo"],
                "gasto": appid in gastos, "apagado_em": registro.get("data", ""),
                "no_disco": False, "sem_manifesto": True,
            })
        fora.sort(key=lambda j: j["nome"].lower())
        orfas.sort(key=lambda j: j["appid"])
        fora.extend(orfas)
        heroic = [] if busca else jogos_do_heroic()

        tema = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
        base_tema = os.path.expanduser("~/.local/share/icons/%s" % tema)
        arcticons = self._mapa_arcticons()
        convertidos = self._mapa_convertidos()
        travas = self._travas_do_arcticons()
        donos_scalable = self._donos_do_scalable()
        icones = []
        for d in self._desktops():
            if d["oculto"] or not self._e_jogo(d):
                continue
            if busca and busca not in d["nome"].lower() and busca not in d["id"].lower():
                continue
            atual, nosso = self._icone_na_tela(d, base_tema)
            icones.append({
                "id": d["id"], "nome": d["nome"], "icone": d["icone"],
                "origem": d["origem"], "nosso": nosso,
                "url": ("/previa?tipo=arquivo&id=" + quote(atual, safe="")) if atual else "",
                "mapa": arcticons.get(d["id"]) or arcticons.get(d["icone"]) or None,
                "traco": convertidos.get(d["id"]) or convertidos.get(d["icone"]) or None,
                "trava": self._motivo_da_trava(travas, [d["id"], d["icone"]], d["nome"]),
                "trava_pack": self._trava_do_pack(d, d["nome"], donos_scalable, travas),
            })
        return {"jogos": fora, "total": len(fora), "mapa": MAPA_JOGOS,
                "heroic": heroic, "apps": icones, "total_apps": len(icones)}

    def _api_jogo_fora(self, corpo):
        appid = str(corpo.get("appid", "")).strip()
        acao = str(corpo.get("acao", "")).strip()
        motivo = " ".join(str(corpo.get("motivo", "")).split())
        remover = bool(corpo.get("remover"))
        if not appid.isdigit() or len(appid) > 12:
            return self._json({"erro": "appid inválido"}, 400)

        if not remover and acao not in ("esconder", "apagar"):
            return self._json({"erro": "ação tem de ser esconder ou apagar"}, 400)
        motivo = motivo.replace(":", " ").replace("#", " ").strip()
        if not motivo:
            motivo = "escolha feita no painel em %s" % datetime.date.today().isoformat()

        try:
            with open(MAPA_JOGOS, "r", encoding="utf-8") as fh:
                linhas = fh.read().split("\n")
        except OSError as e:
            return self._json({"erro": "não achei o mapa: %s" % e}, 500)

        def id_da_linha(l):
            corte = l.strip()
            if not corte or corte.startswith("#"):
                return None
            return corte.split(":")[0].strip()

        novas = list(linhas)
        indice = next((i for i, l in enumerate(novas) if id_da_linha(l) == appid), None)
        so_pergunta = bool(corpo.get("previa") or corpo.get("seco"))

        if remover:
            if indice is None and not so_pergunta:
                return self._json({"ok": True, "removido": False, "appid": appid})
            if indice is not None:
                del novas[indice]
        else:
            nova = "%s:%s:%s" % (appid, acao, motivo)
            if indice is not None:
                novas[indice] = nova
            else:
                ultima = max((i for i, l in enumerate(novas) if id_da_linha(l)),
                             default=None)
                if ultima is None:
                    novas.append(nova)
                else:
                    novas.insert(ultima + 1, nova)
        if corpo.get("previa"):
            return self._json(_previa_dos_jogos("\n".join(novas)))
        if corpo.get("seco"):
            return self._ensaio_dos_jogos("\n".join(novas))
        try:
            with open(MAPA_JOGOS, "w", encoding="utf-8") as fh:
                fh.write("\n".join(novas))
        except OSError as e:
            return self._json({"erro": "não consegui gravar o mapa: %s" % e}, 500)
        return self._json({"ok": True, "appid": appid, "acao": "" if remover else acao,
                           "removido": remover,
                           "depois": "vale depois de \"Arrumar os jogos no lançador\""})

    def _ensaio_dos_jogos(self, mapa):
        pasta, erro = _conf_de_ensaio([])
        if erro:
            return self._json({"erro": erro}, 500)
        try:
            with open(os.path.join(pasta, "jogos-fora.map"), "w", encoding="utf-8") as fh:
                fh.write(mapa)
        except OSError as e:
            shutil.rmtree(pasta, ignore_errors=True)
            return self._json({"erro": "não consegui preparar o ensaio: %s" % e}, 500)
        trabalho, erro = iniciar("jogos_aplicar", "", confirmado=True, seco=True,
                                 pasta_de_ensaio=pasta)
        if erro:
            shutil.rmtree(pasta, ignore_errors=True)
            return self._json(erro if isinstance(erro, dict) else {"erro": erro}, 409)
        return self._json(_trabalho_json(trabalho, "jogos_aplicar", seco=True))

    def _desenhos_do_pack_no_ar(self):
        mod = modulo_pack()
        ident = _pack_adotado() if mod else ""
        dir_pack = mod.achar(ident) if ident else None
        if not dir_pack:
            return None, [], ""

        def declarado(trilha):
            valor = mod.campo(dir_pack, trilha)
            if not isinstance(valor, str) or not valor:
                return ""
            try:
                return mod.resolver_alvo(valor, dir_pack)
            except mod.Recusa:
                return ""

        mapa = declarado("icones.apps.mapa")
        if not mapa or not os.path.isfile(mapa):
            return None, [], ""
        pack = {"id": ident, "nome": str(mod.campo(dir_pack, "nome", ident) or ident),
                "mapa": mapa}
        vals = valores_efetivos(["ICONES_DRACULA", "FLAVOR"])
        flavor = vals.get("FLAVOR") or str(mod.campo(dir_pack, "paleta.flavor_padrao", "") or "")
        base = os.path.dirname(mapa)
        desenhos = []
        for pasta, fim in ((declarado("icones.apps.desenhos"), ".svg"),
                           (os.path.join(dir_pack, mod.PASTA_BIBLIOTECA), ".svg"),
                           (declarado("icones.autorais.desenhos"),
                            ("-%s.svg" % flavor) if flavor else "")):
            if not fim or not pasta or not os.path.isdir(pasta):
                continue
            for arq in sorted(os.listdir(pasta)):
                caminho = os.path.join(pasta, arq)
                if (not arq.endswith(fim) or not re.match(r"^[A-Za-z0-9._+-]{1,200}$", arq)
                        or os.path.islink(caminho) or not os.path.isfile(caminho)):
                    continue
                desenho = os.path.relpath(caminho, base)
                if desenho.startswith(".."):
                    continue
                desenhos.append({"glifo": arq[:-len(fim)], "desenho": desenho,
                                 "caminho": caminho})
        aviso = ""
        if (vals.get("ICONES_DRACULA") or "sim") == "nao":
            aviso = ("Os desenhos do pack «%s» aparecem nesta busca com «Ícones do pack "
                     "nos aplicativos» ligado." % pack["nome"])
        return pack, desenhos, aviso

    def _donos_do_scalable(self):
        donos = set()
        for script, listas in (("completar_icones.sh", ("AUTORAL", "RETIRADOS", "APELIDO")),
                               ("logo.sh", ("BOTOES_DOCK",))):
            try:
                with open(os.path.join(RAIZ, "scripts", script), "r", encoding="utf-8") as fh:
                    texto = fh.read()
            except OSError:
                continue
            for lista in listas:
                achado = (re.search(r"^(?:declare -A )?%s=\(([^\n)]*)\)" % lista, texto, re.M)
                          or re.search(r"^(?:declare -A )?%s=\(\n(.*?)^\)" % lista, texto,
                                       re.M | re.S))
                if not achado:
                    continue
                for linha in achado.group(1).split("\n"):
                    linha = linha.split("#", 1)[0]
                    chaves = re.findall(r"\[([^\]]+)\]=", linha)
                    donos.update(chaves or linha.split())
        return donos

    def _trava_do_pack(self, d, rotulo, donos=None, travas=None):
        icone = (d.get("icone") or "").strip()
        intocaveis, prefixos, curados, _convertidos = (
            self._travas_do_arcticons() if travas is None else travas)
        motivo = self._motivo_da_trava((intocaveis, prefixos, curados, ()),
                                       [d.get("id"), icone], rotulo)
        if motivo:
            return motivo
        if icone.startswith("/"):
            return "O lançador aponta o ícone por caminho de arquivo: o tema não vale aqui"
        donos = self._donos_do_scalable() if donos is None else donos
        if any(n in donos for n in (icone, d.get("id")) if n):
            return "O ícone deste app é de outro passo do MeowSystem; o do pack não duraria"
        return None

    def _escolher_do_pack(self, app, corpo):
        pedido = str(corpo.get("pack", "")).strip()
        desenho = str(corpo.get("desenho", "")).strip()
        pack, desenhos, aviso = self._desenhos_do_pack_no_ar()
        if not pack:
            return self._json({"erro": "o pack no ar não tem mapa de aplicativos: não há "
                                       "onde gravar um desenho dele"}, 409)
        if pack["id"] != pedido:
            return self._json({"erro": "o pack «%s» não está no ar — o que está é o «%s»"
                                       % (pedido, pack["nome"])}, 409)
        if aviso:
            return self._json({"erro": aviso}, 409)
        item = next((x for x in desenhos if x["desenho"] == desenho), None)
        if not item:
            return self._json({"erro": "não achei o desenho '%s' no pack «%s»"
                                       % (desenho, pack["nome"])}, 404)
        d = next((x for x in self._desktops() if x["id"] == app), None) or {"id": app}
        rotulo = d.get("nome") or app
        motivo = self._trava_do_pack(d, rotulo)
        if motivo:
            return self._json({"erro": motivo}, 409)
        nome = self._nome_do_icone(app)
        try:
            linhas, ativas = self._mapa_do_pack(pack["mapa"])
        except OSError as e:
            return self._json({"erro": "não consegui ler o mapa do pack: %s" % e}, 500)
        numero = next((num for num, n, _alvo in ativas if n == nome), None)
        antes = ""
        if numero is not None:
            antes = self._escolha_do_painel(linhas[numero - 1])
            if antes is None:
                antes = linhas[numero - 1]
        linha = "%s : %s   # %s — escolhido no painel%s" % (
            nome, desenho, re.sub(r"[\x00-\x1f#;]+", " ", rotulo).strip(),
            "; antes: " + antes if antes else "")
        if numero is not None:
            linhas[numero - 1] = linha
        elif ativas:
            linhas.insert(ativas[-1][0], linha)
        else:
            linhas.insert(len(linhas) - 1 if linhas and not linhas[-1] else len(linhas), linha)
        try:
            with open(pack["mapa"], "w", encoding="utf-8") as fh:
                fh.write("\n".join(linhas))
        except OSError as e:
            return self._json({"erro": "não consegui gravar o mapa do pack: %s" % e}, 500)
        return self._json({"ok": True, "app": app, "pack": pack["id"],
                           "nome_pack": pack["nome"], "glifo": item["glifo"],
                           "desenho": desenho,
                           "depois": "vale depois de «%s»" % ACOES["icones_pack"]["rotulo"]})

    _MARCA_DO_PAINEL = re.compile(r"^[^#]*#.*? — escolhido no painel(?:; antes: (.*))?$")

    def _escolha_do_painel(self, linha):
        achado = self._MARCA_DO_PAINEL.match(linha)
        return None if not achado else (achado.group(1) or "")

    def _mapa_do_pack(self, mapa):
        with open(mapa, "r", encoding="utf-8") as fh:
            linhas = fh.read().split("\n")
        return linhas, list(modulo_pack().ler_mapa(mapa))

    def _escolha_no_pack(self, pack, app):
        nome = self._nome_do_icone(app)
        try:
            linhas, ativas = self._mapa_do_pack(pack["mapa"])
        except OSError:
            return None
        for num, n, alvo in ativas:
            if n != nome:
                continue
            antes = self._escolha_do_painel(linhas[num - 1])
            if antes is None:
                return None
            return {"pack": pack["id"], "nome_pack": pack["nome"], "desenho": alvo,
                    "antes": antes.split("#", 1)[0].partition(":")[2].strip() or None}
        return None

    def _desfazer_do_pack(self, app, corpo):
        pedido = str(corpo.get("pack", "")).strip()
        pack, _desenhos, _aviso = self._desenhos_do_pack_no_ar()
        if not pack:
            return self._json({"erro": "o pack no ar não tem mapa de aplicativos: não há "
                                       "escolha dele para desfazer"}, 409)
        if pack["id"] != pedido:
            return self._json({"erro": "o pack «%s» não está no ar — o que está é o «%s»"
                                       % (pedido, pack["nome"])}, 409)
        nome = self._nome_do_icone(app)
        try:
            linhas, ativas = self._mapa_do_pack(pack["mapa"])
        except OSError as e:
            return self._json({"erro": "não consegui ler o mapa do pack: %s" % e}, 500)
        numero = next((num for num, n, _alvo in ativas if n == nome), None)
        antes = self._escolha_do_painel(linhas[numero - 1]) if numero is not None else None
        if antes is None:
            return self._json({"ok": True, "removido": False, "app": app,
                               "fica": self._o_que_fica(app)})
        if antes:
            linhas[numero - 1] = antes
        else:
            del linhas[numero - 1]
        try:
            with open(pack["mapa"], "w", encoding="utf-8") as fh:
                fh.write("\n".join(linhas))
        except OSError as e:
            return self._json({"erro": "não consegui gravar o mapa do pack: %s" % e}, 500)
        fica = self._o_que_fica(app)
        return self._json({"ok": True, "removido": True, "app": app, "pack": pack["id"],
                           "nome_pack": pack["nome"], "fica": fica})

    def _o_que_fica(self, app):
        d = next((x for x in self._desktops() if x["id"] == app), None) or {}
        mod = modulo_pack()
        minha = self._minha_escolha(app)
        if minha:
            return {"tipo": "escolha", "frase": "o desenho «%s» que você escolheu" % minha["glifo"]}
        ident = _pack_adotado() if mod else ""
        if ident and (valores_efetivos(["ICONES_DRACULA"]).get("ICONES_DRACULA") or "sim") != "nao":
            mapa = mod.acervo("icones.apps.mapa", ref=ident) or ""
            nome = self._nome_do_icone(app)
            for _num, n, alvo in (mod.ler_mapa(mapa) if os.path.isfile(mapa) else ()):
                if n == nome:
                    dono = mod._pack_de(mapa)
                    nome_pack = str(mod.campo(dono, "nome", dono) or dono)
                    return {"tipo": "pack", "frase": "o desenho «%s» do pack «%s»"
                            % (os.path.splitext(os.path.basename(alvo))[0], nome_pack)}
        arcticons = self._mapa_arcticons()
        marca = arcticons.get(app) or arcticons.get(d.get("icone") or "")
        if marca:
            return {"tipo": "arcticons",
                    "frase": "o glifo «%s» do Arcticons, em traço" % marca["glifo"]}
        convertidos = self._mapa_convertidos()
        if convertidos.get(app) or convertidos.get(d.get("icone") or ""):
            return {"tipo": "conversao", "frase": "a conversão em traço do projeto"}
        return {"tipo": "fabrica", "frase": "o ícone de fábrica"}

    def _o_que_veste(self, app):
        mod = modulo_pack()
        minha = self._minha_escolha(app)
        if minha:
            return minha["arquivo"]
        nome = self._nome_do_icone(app)
        ident = _pack_adotado() if mod else ""
        if ident and (valores_efetivos(["ICONES_DRACULA"]).get("ICONES_DRACULA") or "sim") != "nao":
            mapa = mod.acervo("icones.apps.mapa", ref=ident) or ""
            for _num, n, alvo in (mod.ler_mapa(mapa) if os.path.isfile(mapa) else ()):
                if n != nome:
                    continue
                try:
                    arq = mod.resolver_alvo(alvo, os.path.dirname(mapa))
                except mod.Recusa:
                    arq = ""
                if arq and os.path.isfile(arq):
                    return self._arquivo_na_ficha(arq)
        d = next((x for x in self._desktops() if x["id"] == app), None) or {}
        icones = ICONES_DO_MOTOR
        marca = self._mapa_arcticons().get(app) or self._mapa_arcticons().get(d.get("icone") or "")
        if marca:
            glifo = marca["glifo"]
            arq = (glifo if os.path.isabs(glifo) else os.path.join(RAIZ, glifo)) if "/" in glifo \
                else _glifo_do_motor(glifo)
            if os.path.isfile(arq):
                return self._arquivo_na_ficha(arq)
        conv = self._mapa_convertidos()
        if conv.get(app) or conv.get(d.get("icone") or ""):
            arq = os.path.join(icones, "apps", nome + ".svg")
            if os.path.isfile(arq):
                return self._arquivo_na_ficha(arq)
        return None

    @staticmethod
    def _sem_acento(texto):
        import unicodedata
        return "".join(c for c in unicodedata.normalize("NFKD", str(texto or ""))
                       if not unicodedata.combining(c)).lower()

    def _acervo_da_ficha(self):
        grupos, itens = [], []
        mod = modulo_pack()
        if not mod:
            return grupos, itens
        pack, desenhos, _aviso = self._desenhos_do_pack_no_ar()
        do_mapa = {os.path.normpath(d["caminho"]): d for d in desenhos}
        textos, rotulos, do_nome = self._textos_da_busca(mod)
        nomes_de_app = self._nomes_de_app()
        for g in mod.acervos_de_icone(_pack_adotado()):
            arquivos = g.pop("arquivos")
            g["total"] = len(arquivos)
            grupos.append(g)
            for caminho in arquivos:
                nome = os.path.basename(caminho)
                glifo = os.path.splitext(nome)[0]
                rotulo = (rotulos.get(os.path.normpath(caminho))
                          or nomes_de_app.get(glifo.lower()) or do_nome.get(glifo.lower())
                          or self._rotulo_do_nome(glifo))
                item = {"glifo": glifo, "rotulo": rotulo, "grupo": g["id"], "tipo": g["tipo"],
                        "caminho": caminho,
                        "_texto": self._sem_acento(" ".join(
                            [glifo, rotulo] + textos.get(os.path.normpath(caminho), [])))}
                if g["tipo"] == "png":
                    item["trava"] = "Feito à mão em PNG: vale no tema quando ganhar a versão em vetor"
                no_mapa = do_mapa.get(os.path.normpath(caminho)) if pack else None
                if no_mapa:
                    item.update(pack=pack["id"], desenho=no_mapa["desenho"])
                itens.append(item)
        return grupos, itens

    @staticmethod
    def _rotulo_do_nome(glifo):
        app_web = re.match(r"^(chrome|chromium|brave|msedge)-[a-p]{32}-\w+$", glifo, re.I)
        if app_web:
            return "App do " + {"msedge": "Edge"}.get(app_web.group(1).lower(),
                                                      app_web.group(1).capitalize())
        nome = re.sub(r"^\d+[-_.]+", "", glifo) or glifo
        partes = [p for p in nome.split(".") if p]
        if len(partes) >= 3 and " " not in nome:
            nome = partes[-1]
        nome = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", nome)
        nome = re.sub(r"[-_.]+", " ", nome).strip() or glifo
        return nome[:1].upper() + nome[1:]

    @staticmethod
    def _rotulo_do_comentario(comentario):
        texto = re.sub(r"\[[^\]]*\]", "", comentario or "")
        return re.split(r"\s[—–-]\s|\s\(", texto, maxsplit=1)[0].strip()

    def _nomes_de_app(self):
        nomes = {}
        for d in self._desktops():
            if not d.get("nome") or d["nome"] == d["id"]:
                continue
            for chave in (d.get("icone") or "", d["id"]):
                if chave and "/" not in chave:
                    nomes.setdefault(chave.lower(), d["nome"])
        return nomes

    def _textos_da_busca(self, mod):
        textos = {}
        rotulos = {}
        do_nome = {}
        nomes_de_app = self._nomes_de_app()

        def junta(caminho, *partes):
            textos.setdefault(os.path.normpath(caminho), []).extend(p for p in partes if p)

        mapas = set()
        for base in mod.raizes():
            try:
                ids = sorted(os.listdir(base))
            except OSError:
                continue
            for pid in ids:
                dir_pack = os.path.join(base, pid)
                if not os.path.isfile(os.path.join(dir_pack, "pack.json")):
                    continue
                mapa = mod.acervo("icones.apps.mapa", ref=dir_pack) or ""
                if mapa and os.path.isfile(mapa):
                    mapas.add(os.path.realpath(mapa))
        vistas = set()
        for g in mod.acervos_de_icone() if hasattr(mod, "acervos_de_icone") else ():
            pasta_cat = os.path.normpath(g.get("pasta") or "")
            if not pasta_cat or pasta_cat in vistas:
                continue
            vistas.add(pasta_cat)
            com_rotulo = ":biblioteca" in g.get("id", "") or g.get("id", "").endswith(":feitos-a-mao")
            try:
                with open(os.path.join(pasta_cat, "catalog.json"), encoding="utf-8") as fh:
                    catalogo = json.load(fh)
            except (OSError, ValueError):
                continue
            for arq, ficha in (catalogo.items() if isinstance(catalogo, dict) else ()):
                if isinstance(ficha, dict):
                    etiquetas = ficha.get("tags") if isinstance(ficha.get("tags"), list) else []
                    descricao = str(ficha.get("descricao") or "").strip()
                    junta(os.path.join(pasta_cat, str(arq)), descricao,
                          *[str(t).replace("_", " ") for t in etiquetas])
                    if com_rotulo and descricao:
                        rotulos[os.path.normpath(os.path.join(pasta_cat, str(arq)))] = (
                            descricao[:1].upper() + descricao[1:])
        conv = os.path.join(ICONES_DO_MOTOR, "apps-convertidos.map")
        try:
            with open(conv, encoding="utf-8") as fh:
                linhas_conv = fh.read().split("\n")
        except OSError:
            linhas_conv = []
        for anterior, linha in zip([""] + linhas_conv, linhas_conv):
            nome_app = anterior[len("# app:"):].strip() if anterior.startswith("# app:") else ""
            nome = linha.split(":", 1)[0].strip()
            if nome_app and nome and not linha.startswith("#"):
                caminho = os.path.join(ICONES_DO_MOTOR, "apps", nome + ".svg")
                junta(caminho, nome_app)
                rotulos.setdefault(os.path.normpath(caminho), nome_app)
                do_nome.setdefault(nome.lower(), nome_app)
        for mapa in sorted(mapas):
            try:
                with open(mapa, encoding="utf-8") as fh:
                    linhas = fh.read().split("\n")
            except OSError:
                continue
            for linha in linhas:
                util, _sep, comentario = linha.partition("#")
                nome, sep, alvo = util.partition(":")
                if not sep or not nome.strip() or not alvo.strip():
                    continue
                try:
                    caminho = mod.resolver_alvo(alvo.strip(), os.path.dirname(mapa))
                except mod.Recusa:
                    continue
                junta(caminho, nome.strip(), comentario.strip())
                rotulo = (self._rotulo_do_comentario(comentario)
                          or nomes_de_app.get(nome.strip().lower(), ""))
                if rotulo:
                    rotulos.setdefault(os.path.normpath(caminho), rotulo)
                    do_nome.setdefault(os.path.splitext(os.path.basename(caminho))[0].lower(), rotulo)
        return textos, rotulos, do_nome

    def _palpites_do_app(self, app):
        if not app or not re.match(r"^[A-Za-z0-9._+-]{1,120}$", app):
            return []
        d = next((x for x in self._desktops() if x["id"] == app), None) or {"id": app}
        nome = self._sem_acento(d.get("nome") or "")
        palpites = {self._sem_acento(app), self._sem_acento(d.get("icone") or "")}
        if nome:
            palpites.add(nome)
            primeira = nome.split()[0]
            if len(primeira) >= 3:
                palpites.add(primeira)
        return [p for p in palpites if p and "/" not in p]

    def _api_glifos(self, consulta):
        busca = self._sem_acento((consulta.get("busca", [""])[0] or "").strip())
        app = (consulta.get("app", [""])[0] or "").strip()
        grupos, itens = self._acervo_da_ficha()
        palpites = self._palpites_do_app(app)
        achados = {}
        glifos = []
        for it in itens:
            if busca and busca not in it["_texto"]:
                continue
            achados[it["grupo"]] = achados.get(it["grupo"], 0) + 1
            _ICONES_DECLARADOS.add(os.path.normpath(it["caminho"]))
            saida = {k: v for k, v in it.items() if not k.startswith("_") and k != "caminho"}
            saida["url"] = "/previa?tipo=arquivo&id=" + quote(it["caminho"], safe="")
            saida["arquivo"] = self._arquivo_na_ficha(it["caminho"])
            saida["sugerido"] = any(p in it["_texto"] for p in palpites)
            glifos.append(saida)
        for g in grupos:
            g["achados"] = achados.get(g["id"], 0)
            g.pop("pasta", None)
        pack, _desenhos, aviso = self._desenhos_do_pack_no_ar()
        app_ok = bool(re.match(r"^[A-Za-z0-9._+-]{1,120}$", app))
        extra = {"aviso": aviso,
                 "pack": {"id": pack["id"], "nome": pack["nome"]} if pack and not aviso else None,
                 "escolha": (self._escolha_no_pack(pack, app) if pack and app_ok else None),
                 "minha": self._minha_escolha(app) if app_ok else None,
                 "veste": self._o_que_veste(app) if app_ok else None}
        return self._json(dict({"grupos": grupos, "glifos": glifos, "limitado": False}, **extra))

    def _arquivo_na_ficha(self, caminho):
        caminho = os.path.normpath(caminho)
        if caminho.startswith(RAIZ + os.sep):
            return os.path.relpath(caminho, RAIZ)
        return caminho

    def _item_da_ficha(self, arquivo):
        if not arquivo or not isinstance(arquivo, str):
            return None
        alvo = os.path.normpath(arquivo if os.path.isabs(arquivo) else os.path.join(RAIZ, arquivo))
        _grupos, itens = self._acervo_da_ficha()
        return next((it for it in itens if os.path.normpath(it["caminho"]) == alvo), None)

    def _minha_escolha(self, app):
        mod = modulo_pack()
        if not mod or not hasattr(mod, "escolhas_do_painel"):
            return None
        nome = self._nome_do_icone(app)
        arq = next((a for _n, n, a in mod.escolhas_do_painel() if n == nome), None)
        if not arq:
            return None
        item = self._item_da_ficha(arq) or {}
        return {"arquivo": self._arquivo_na_ficha(arq),
                "glifo": os.path.splitext(os.path.basename(arq))[0],
                "grupo": item.get("grupo"), "pack": item.get("pack"),
                "desenho": item.get("desenho")}

    def _escolher_desenho(self, app, item):
        if item.get("tipo") != "desenho":
            return self._json({"erro": "este desenho não entra como está no tema"}, 409)
        d = next((x for x in self._desktops() if x["id"] == app), None) or {"id": app}
        rotulo = d.get("nome") or app
        motivo = self._trava_do_pack(d, rotulo)
        if motivo:
            return self._json({"erro": motivo}, 409)
        nome = self._nome_do_icone(app)
        arquivo = self._arquivo_na_ficha(item["caminho"])
        linha = "%s : %s   # %s — escolhido no painel" % (
            nome, arquivo, re.sub(r"[\x00-\x1f#;]+", " ", rotulo).strip())
        try:
            _gravar_escolha(_mapa_de_escolhas_do_usuario(), nome, linha, ":")
        except OSError as e:
            return self._json({"erro": "não consegui guardar a escolha: %s" % e}, 500)
        return self._json({"ok": True, "app": app, "glifo": item["glifo"], "arquivo": arquivo,
                           "depois": "vale depois de «%s»" % ACOES["icones_pack"]["rotulo"]})

    def _api_app_icone(self, corpo):
        app = str(corpo.get("app", "")).strip()
        glifo = str(corpo.get("glifo", "")).strip()
        cor = str(corpo.get("cor", "")).strip()
        remover = bool(corpo.get("remover"))
        if not app or not re.match(r"^[A-Za-z0-9._+-]{1,120}$", app):
            return self._json({"erro": "aplicativo inválido"}, 400)

        if corpo.get("pack") and not remover:
            pack, _desenhos, _aviso = self._desenhos_do_pack_no_ar()
            resposta = self._escolher_do_pack(app, corpo)
            levada = pack and self._escolha_no_pack(pack, app)
            if levada and levada["desenho"] == str(corpo.get("desenho", "")).strip():
                try:
                    _gravar_escolha(_mapa_de_escolhas_do_usuario(), self._nome_do_icone(app),
                                    None, ":")
                except OSError:
                    pass
            return resposta
        if corpo.get("pack"):
            return self._desfazer_do_pack(app, corpo)

        if remover and corpo.get("escolha"):
            try:
                havia = _gravar_escolha(_mapa_de_escolhas_do_usuario(),
                                        self._nome_do_icone(app), None, ":")
            except OSError as e:
                return self._json({"erro": "não consegui tirar a escolha: %s" % e}, 500)
            return self._json({"ok": True, "removido": havia, "app": app,
                               "fica": self._o_que_fica(app)})

        item = None
        if corpo.get("arquivo") and not remover:
            item = self._item_da_ficha(str(corpo.get("arquivo")))
            if not item:
                return self._json({"erro": "não achei o desenho '%s' na ficha"
                                           % corpo.get("arquivo")}, 404)
            if item.get("tipo") != "traco":
                return self._escolher_desenho(app, item)

        if not remover:
            d = next((x for x in self._desktops() if x["id"] == app), None) or {}
            motivo = self._motivo_da_trava(self._travas_do_arcticons(),
                                           [app, d.get("icone", "")], d.get("nome") or app)
            if motivo:
                return self._json({"erro": motivo}, 409)

        caminho = _mapa_de_traco_do_usuario()
        if remover:
            try:
                havia = _gravar_escolha(caminho, app, None, ":")
            except OSError as e:
                return self._json({"erro": "não consegui tirar a escolha: %s" % e}, 500)
            return self._json({"ok": True, "removido": havia, "app": app,
                               "fica": self._o_que_fica(app)})

        trazer = os.path.join(ICONES_DO_MOTOR, "apps")
        if item:
            if os.path.dirname(os.path.normpath(item["caminho"])) == trazer:
                glifo = item["glifo"]
            else:
                glifo = self._arquivo_na_ficha(item["caminho"])
        if not re.match(r"^[a-z0-9._-]{1,60}$", glifo) and not (
                item and re.match(r"^(assets/icones|packs/[a-z0-9][a-z0-9-]*/icones)/"
                                  r"[A-Za-z0-9._+/-]{1,200}\.svg$", glifo)
                and "/../" not in "/" + glifo + "/"):
            return self._json({"erro": "glifo inválido"}, 400)
        cores = set((_paleta_dados().get("ordem") or []))
        if cores and cor not in cores:
            return self._json({"erro": "a cor tem de ser um nome da paleta"}, 400)
        if "/" not in glifo and not os.path.isfile(os.path.join(trazer, glifo + ".svg")):
            return self._json({"erro": "não achei o desenho '%s' no acervo" % glifo}, 404)

        mapa = self._mapa_arcticons()
        repetido = any(m["glifo"] == glifo or m["cor"] == cor
                       for chave, m in mapa.items() if chave != app)
        linha = "%s:%s:%s%s" % (app, glifo, cor, ":alias" if repetido else "")
        try:
            _gravar_escolha(caminho, app, linha, ":")
        except OSError as e:
            return self._json({"erro": "não consegui guardar a escolha: %s" % e}, 500)
        mod = modulo_pack()
        nome = self._nome_do_icone(app)
        tirou = bool(mod and hasattr(mod, "escolhas_do_painel")
                     and any(n == nome for _num, n, _a in mod.escolhas_do_painel()))
        if tirou:
            try:
                _gravar_escolha(_mapa_de_escolhas_do_usuario(), nome, None, ":")
            except OSError as e:
                return self._json({"erro": "guardei o traço, e não consegui tirar o desenho "
                                           "escolhido antes: %s" % e}, 500)
        return self._json({"ok": True, "app": app, "glifo": os.path.basename(glifo).rsplit(".svg", 1)[0],
                           "cor": cor, "alias": repetido, "trouxe_do_acervo": False,
                           "tirou_escolha": tirou,
                           "depois": "vale depois de \"Pôr os desenhos em traço na tela\""})

    _SVG_PROIBIDO = re.compile(
        r"<\s*(script|style|image|foreignObject|iframe|use)\b"
        r"|xlink:|href\s*=|\bon[a-z]+\s*=|url\s*\(|@import",
        re.I)

    def _arte_de_fabrica(self, d):
        nome = d.get("icone") or d.get("id")
        if not nome:
            return ""
        if nome.startswith("/") and os.path.isfile(nome):
            return nome
        nosso = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
        raizes = [os.path.expanduser("~/.local/share/flatpak/exports/share/icons"),
                  "/var/lib/flatpak/exports/share/icons",
                  os.path.expanduser("~/.local/share/icons"),
                  "/usr/share/icons"]
        grandes = ("scalable", "512x512", "256x256", "128x128", "64x64", "48x48")
        candidatos = []
        for raiz in raizes:
            for tema in self.TEMAS_DE_ICONE:
                if not tema or tema == nosso:
                    continue
                for i, tam in enumerate(grandes):
                    for ext, peso in ((".svg", 0), (".png", 1)):
                        cand = os.path.join(raiz, tema, tam, "apps", nome + ext)
                        if os.path.isfile(cand):
                            candidatos.append(((0 if tam == "scalable" else 1), peso, i, cand))
        for pix in ("/usr/share/pixmaps", os.path.expanduser("~/.local/share/pixmaps")):
            for ext, peso in ((".svg", 0), (".png", 1)):
                cand = os.path.join(pix, nome + ext)
                if os.path.isfile(cand):
                    candidatos.append((2, peso, 9, cand))
        if not candidatos:
            return ""
        candidatos.sort()
        return candidatos[0][3]

    def _nome_do_icone(self, app):
        d = next((x for x in self._desktops() if x["id"] == app), None)
        nome = ((d or {}).get("icone") or app).strip()
        if nome.startswith("/") or not re.match(r"^[A-Za-z0-9._+-]{1,120}$", nome):
            return app
        return nome

    def _caminho_retoque(self, app):
        return _oficina_do_usuario("retoques", app + ".svg")

    def _retoque_do_projeto(self, app):
        return os.path.join(ICONES_DO_MOTOR, "apps", app + ".svg")

    def _vizinhos_do_dock(self):
        caminho = os.path.join(ICONES_DO_MOTOR, "apps-arcticons.map")
        linhas = []
        try:
            with open(caminho, "r", encoding="utf-8") as fh:
                for linha in fh:
                    corte = linha.strip()
                    if corte and not corte.startswith("#"):
                        linhas.append(corte)
        except OSError:
            return []
        saida = []
        for corte in ([linhas[0], linhas[-1]] if len(linhas) > 1 else linhas):
            campos = [c.strip() for c in corte.split(":")]
            if len(campos) < 3 or not re.match(r"^[A-Za-z0-9._+-]{1,120}$", campos[1]):
                continue
            arte = _glifo_do_motor(campos[1])
            try:
                with open(arte, "r", encoding="utf-8") as fh:
                    saida.append({"nome": campos[0], "cor": campos[2], "svg": fh.read()})
            except OSError:
                continue
        return saida

    def _modo_no_mapa(self, nome):
        for caminho in (_mapa_de_convertidos_do_usuario(),
                        os.path.join(ICONES_DO_MOTOR, "apps-convertidos.map")):
            try:
                with open(caminho, "r", encoding="utf-8") as fh:
                    for linha in fh:
                        corte = linha.strip()
                        if not corte or corte.startswith("#"):
                            continue
                        campos = [c.strip() for c in corte.split(":", 2)]
                        if campos[0] != nome or len(campos) < 2:
                            continue
                        return "mao" if campos[1] == "mao" else "conversao"
            except OSError:
                continue
        return ""

    def _salvo_do_app(self, nome):
        conv = os.path.join(ICONES_DO_MOTOR, "apps")
        for caminho, palpite in ((self._caminho_retoque(nome), "mao"),
                                 (_oficina_do_usuario("convertidos-apps", nome + ".svg"), "conversao"),
                                 (self._retoque_do_projeto(nome), "mao"),
                                 (os.path.join(conv, nome + ".svg"), "conversao")):
            try:
                with open(caminho, "r", encoding="utf-8") as fh:
                    texto = fh.read()
            except OSError:
                continue
            return {"tem": True, "svg": texto,
                    "modo": self._modo_no_mapa(nome) or palpite}
        return {"tem": False, "svg": "", "modo": ""}

    def _tirar_retoque(self, nome):
        pasta = os.path.realpath(_oficina_do_usuario("retoques"))
        alvo = os.path.realpath(self._caminho_retoque(nome))
        if not alvo.startswith(pasta + os.sep) or not os.path.isfile(alvo):
            return False
        try:
            os.unlink(alvo)
        except OSError:
            return False
        return True

    def _arte_da_capa(self, app):
        if not self._RE_STEAM.match(app):
            return ""
        return self._capa_do_jogo(re.sub(r"^\D+", "", app))

    def _editor_de_svg(self):
        global _EDITOR_SVG
        with _EDITOR_SVG_TRAVA:
            if _EDITOR_SVG is not None:
                return _EDITOR_SVG
            _EDITOR_SVG = {"tem": False, "nome": ""}
            if not any(shutil.which(l[0]) for l in _LANCADORES_SVG):
                return _EDITOR_SVG
            alvo = ""
            if shutil.which("xdg-mime"):
                try:
                    r = subprocess.run(["xdg-mime", "query", "default", "image/svg+xml"],
                                       capture_output=True, text=True, timeout=10)
                    alvo = (r.stdout or "").strip().split("\n")[0].strip()
                except (OSError, subprocess.SubprocessError):
                    alvo = ""
            if not alvo or not alvo.endswith(".desktop") or "/" in alvo:
                return _EDITOR_SVG
            ident = alvo[:-len(".desktop")]
            d = next((x for x in self._desktops() if x["id"] == ident), None)
            _EDITOR_SVG = {"tem": True, "nome": (d or {}).get("nome") or ident}
            return _EDITOR_SVG

    def _caminho_rascunho(self, nome):
        pasta = os.path.realpath(_OFICINA_RASCUNHO)
        alvo = os.path.realpath(os.path.join(_OFICINA_RASCUNHO, nome + ".svg"))
        if not alvo.startswith(pasta + os.sep):
            return ""
        return alvo

    def _api_app_desenho(self, corpo):
        app = str(corpo.get("app", "")).strip()
        acao = str(corpo.get("acao", "vetorizar")).strip()
        if not app or not re.match(r"^[A-Za-z0-9._+-]{1,120}$", app):
            return self._json({"erro": "aplicativo inválido"}, 400)

        nome = self._nome_do_icone(app)

        if acao == "ler":
            alvo = self._caminho_retoque(nome)
            if not os.path.isfile(alvo):
                alvo = self._retoque_do_projeto(nome)
            if not os.path.isfile(alvo):
                return self._json({"ok": True, "svg": "", "tem": False})
            try:
                with open(alvo, "r", encoding="utf-8") as fh:
                    return self._json({"ok": True, "svg": fh.read(), "tem": True})
            except OSError as e:
                return self._json({"erro": "não consegui ler o desenho: %s" % e}, 500)

        if acao in ("editor", "editor-ler"):
            alvo = self._caminho_rascunho(nome)
            if not alvo:
                return self._json({"erro": "não consegui montar o caminho do rascunho"}, 400)

            if acao == "editor-ler":
                try:
                    mtime = os.path.getmtime(alvo)
                except OSError:
                    return self._json({"ok": True, "tem": False, "mudou": False})
                try:
                    visto = float(corpo.get("mtime") or 0)
                except (TypeError, ValueError):
                    visto = 0.0
                if abs(mtime - visto) < 0.0005:
                    return self._json({"ok": True, "tem": True, "mudou": False, "mtime": mtime})
                try:
                    with open(alvo, "r", encoding="utf-8", errors="replace") as fh:
                        texto = fh.read(200000)
                except OSError as e:
                    return self._json({"erro": "não consegui reler o rascunho: %s" % e}, 500)
                return self._json({"ok": True, "tem": True, "mudou": True,
                                   "mtime": mtime, "svg": texto,
                                   "aviso": self._conferir_dialeto(texto)})

            editor = self._editor_de_svg()
            if not editor["tem"]:
                return self._json({"erro": "esta máquina não tem quem abra um SVG"}, 404)
            svg = str(corpo.get("svg", ""))
            erro = self._conferir_dialeto(svg)
            if erro:
                return self._json({"erro": erro}, 400)
            try:
                os.makedirs(_OFICINA_RASCUNHO, exist_ok=True)
                with open(alvo, "w", encoding="utf-8") as fh:
                    fh.write(svg if svg.endswith("\n") else svg + "\n")
                mtime = os.path.getmtime(alvo)
            except OSError as e:
                return self._json({"erro": "não consegui gravar o rascunho: %s" % e}, 500)

            if os.environ.get("MEOW_APP_SEM_JANELA") == "1":
                return self._json({"ok": True, "sem_janela": True, "caminho": alvo,
                                   "mtime": mtime, "editor": editor,
                                   "aviso": "Painel sem janela: o %s não foi aberto"
                                            % (editor["nome"] or "editor")})

            lancador = next((list(l) for l in _LANCADORES_SVG if shutil.which(l[0])), None)
            if not lancador:
                return self._json({"erro": "esta máquina não tem quem abra um SVG"}, 404)
            try:
                subprocess.Popen(lancador + [alvo],
                                 stdin=subprocess.DEVNULL,
                                 stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL,
                                 start_new_session=True)
            except (OSError, subprocess.SubprocessError) as e:
                return self._json({"erro": "não consegui abrir o editor: %s" % e}, 500)
            return self._json({"ok": True, "caminho": alvo, "mtime": mtime,
                               "editor": editor})

        if acao == "variacoes":
            d = next((x for x in self._desktops() if x["id"] == app), None)
            if not d:
                return self._json({"erro": "não achei o .desktop de %s" % app}, 404)
            origem = self._arte_de_fabrica(d)
            capa = self._arte_da_capa(app)
            tem_cheia = _conversor_tem_cheia()
            tarefas = []
            for pid, rotulo, det, sua, chei, fonte, frac, mini in PRESETS_DESENHO:
                if chei and not tem_cheia:
                    continue
                arte = capa if fonte == "capa" else origem
                if not arte:
                    continue
                argv, texto = _parametros_de(det, sua, chei, frac, mini)
                tarefas.append({"id": pid, "rotulo": rotulo, "detalhe": det,
                                "suavidade": sua, "cheia": chei, "fonte": fonte,
                                "fracas": frac, "minimo": mini,
                                "parametros": texto, "arte": arte, "argv": argv})
            variacoes = []
            if tarefas:
                with ThreadPoolExecutor(max_workers=6) as piscina:
                    futuros = [piscina.submit(_converter_desenho, t["arte"],
                                              t["argv"], t["parametros"])
                               for t in tarefas]
                    for t, futuro in zip(tarefas, futuros):
                        try:
                            svg, nota, erro = futuro.result()
                        except Exception as e:              # noqa: BLE001
                            svg, nota, erro = "", "", "o conversor falhou: %s" % e
                        cartao = {k: t[k] for k in ("id", "rotulo", "detalhe",
                                                    "suavidade", "cheia", "fonte",
                                                    "fracas", "minimo",
                                                    "parametros")}
                        if erro:
                            cartao["erro"] = erro
                        else:
                            cartao["svg"] = svg
                            cartao["nota"] = nota
                        variacoes.append(cartao)
            tema = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
            atual, nosso = self._icone_na_tela(
                d, os.path.expanduser("~/.local/share/icons/%s" % tema))
            do_pack = self._cartoes_do_pack(d, self._desenhos_de_pack(), atual, com_svg=True)
            traco = self._mapa_convertidos()
            arcticons = self._mapa_arcticons()
            vigor = self._quem_veste(atual, nosso, do_pack,
                                     traco.get(d["id"]) or traco.get(d["icone"]),
                                     arcticons.get(d["id"]) or arcticons.get(d["icone"]))
            return self._json({
                "ok": True, "nome": nome, "origem": origem,
                "original": ("/previa?tipo=arquivo&id=" + quote(origem, safe="")) if origem else "",
                "capa": ("/previa?tipo=arquivo&id=" + quote(capa, safe="")) if capa else "",
                "salvo": self._salvo_do_app(nome),
                "pack": do_pack,
                "em_vigor": vigor,
                "variacoes": variacoes,
                "vizinhos": self._vizinhos_do_dock(),
                "editor": self._editor_de_svg(),
            })

        if acao == "vetorizar":
            d = next((x for x in self._desktops() if x["id"] == app), None)
            if not d:
                return self._json({"erro": "não achei o .desktop de %s" % app}, 404)
            fonte = str(corpo.get("fonte", "icone")).strip()
            if fonte == "capa":
                origem = self._arte_da_capa(app)
                if not self._RE_STEAM.match(app):
                    return self._json({"erro": "só jogo da Steam tem capa"}, 400)
                if not origem:
                    return self._json({
                        "erro": "a Steam não guardou capa deste jogo — "
                                "abra a biblioteca dela uma vez e tente de novo"}, 404)
            elif fonte != "icone":
                return self._json({"erro": "fonte desconhecida: %s" % fonte}, 400)
            else:
                origem = self._arte_de_fabrica(d)
            if not origem:
                return self._json({
                    "erro": "não achei arte de fábrica para %s — este é o caso "
                            "de desenhar do zero na caixa abaixo" % app}, 404)

            if corpo.get("detalhe") not in (None, "") or corpo.get("suavidade") not in (None, ""):
                argv_extra, texto = _parametros_de(corpo.get("detalhe", 6),
                                                   corpo.get("suavidade", 2),
                                                   bool(corpo.get("cheia")),
                                                   corpo.get("fracas", 0),
                                                   corpo.get("minimo", 0))
            else:
                argv_extra, partes = [], []
                for chave, bandeira, menor, maior in (("k", "--k", 3, 16),
                                                      ("funde", "--funde", 0, 120),
                                                      ("tol", "--tol", 0.2, 8.0)):
                    if corpo.get(chave) in (None, ""):
                        continue
                    try:
                        v = float(corpo[chave])
                    except (TypeError, ValueError):
                        return self._json({"erro": "%s tem de ser número" % chave}, 400)
                    if not (menor <= v <= maior):
                        return self._json({"erro": "%s fora da faixa (%s a %s)"
                                                    % (chave, menor, maior)}, 400)
                    argv_extra += [bandeira, ("%g" % v)]
                    partes += [bandeira, ("%g" % v)]
                texto = " ".join(partes)
            svg, nota, erro = _converter_desenho(origem, argv_extra, texto)
            if erro:
                codigo = 422 if "recusou" in erro else 500
                return self._json({"erro": erro}, codigo)
            return self._json({"ok": True, "svg": svg, "origem": origem,
                               "nota": nota, "parametros": texto})

        if acao != "salvar":
            return self._json({"erro": "ação desconhecida: %s" % acao}, 400)

        svg = str(corpo.get("svg", ""))
        cor = str(corpo.get("cor", "")).strip()
        cores = set((_paleta_dados().get("ordem") or []))
        if cores and cor not in cores:
            return self._json({"erro": "a cor tem de ser um nome da paleta"}, 400)
        erro = self._conferir_dialeto(svg)
        if erro:
            return self._json({"erro": erro}, 400)

        d = next((x for x in self._desktops() if x["id"] == app), None)
        fonte = str(corpo.get("fonte", "icone")).strip()
        argv_conv = _parametros_relidos(corpo.get("parametros"))
        texto_param = " ".join(argv_conv) if argv_conv else ""
        origem_arte = self._arte_de_fabrica(d) if d else ""
        casa = os.path.realpath(os.path.expanduser("~")) + os.sep
        da_casa = bool(origem_arte) and os.path.realpath(origem_arte).startswith(casa)
        modo = "mao"
        if fonte == "icone" and argv_conv and origem_arte and not da_casa:
            feito, _nota, erro_conv = _converter_desenho(origem_arte, argv_conv, texto_param)
            if not erro_conv and feito.rstrip() == svg.rstrip():
                modo = "conversao"

        conv = _oficina_do_usuario("convertidos-apps")
        tirou_retoque = False
        try:
            os.makedirs(conv, exist_ok=True)
            os.makedirs(_oficina_do_usuario("retoques"), exist_ok=True)
            if modo == "mao":
                with open(self._caminho_retoque(nome), "w", encoding="utf-8") as fh:
                    fh.write(svg if svg.endswith("\n") else svg + "\n")
            with open(os.path.join(conv, nome + ".svg"), "w", encoding="utf-8") as fh:
                fh.write(svg.rstrip("\n"))
        except OSError as e:
            return self._json({"erro": "não consegui gravar o desenho: %s" % e}, 500)
        if modo == "conversao":
            tirou_retoque = self._tirar_retoque(nome)

        erro = self._gravar_linha_convertidos(
            nome, cor, origem=(origem_arte if modo == "conversao" else "mao"),
            extra=(texto_param if modo == "conversao" else ""))
        if erro:
            return self._json({"erro": erro}, 500)
        saiu = self._tirar_do_mapa_arcticons(nome)
        return self._json({"ok": True, "app": app, "nome": nome, "cor": cor,
                           "modo": modo, "saiu_do_arcticons": saiu,
                           "tirou_retoque": tirou_retoque,
                           "depois": "vale depois de \"Pôr os desenhos em traço na tela\""})

    def _conferir_dialeto(self, svg):
        texto = (svg or "").strip()
        if not texto:
            return "o desenho veio vazio"
        if len(texto) > 60000:
            return "o desenho passa de 60 000 caracteres — isto é um ícone, não um quadro"
        if not texto.startswith("<svg") or not texto.endswith("</svg>"):
            return "o texto tem de começar em <svg e terminar em </svg>"
        if 'viewBox="0 0 48 48"' not in texto:
            return 'falta viewBox="0 0 48 48" — é a caixa de todo o acervo'
        if "stroke-width" in texto:
            return ("tire o stroke-width: a espessura vem do TRACO do "
                    "icones_apps_arcticons.sh, e duplicá-la é XML inválido")
        if re.search(r"#[0-9A-Fa-f]{3,8}\b|rgba?\s*\(|hsla?\s*\(", texto):
            return "tire a cor: ela vem da paleta, pelo campo «Cor»"
        if 'stroke="currentColor"' not in texto:
            return 'falta stroke="currentColor" — é assim que a cor entra'
        if 'fill="none"' not in texto:
            return 'falta fill="none" — o acervo é traço, não chapado'
        achado = self._SVG_PROIBIDO.search(texto)
        if achado:
            return "o desenho traz %s, que não entra num ícone" % achado.group(0)
        return ""

    def _gravar_linha_convertidos(self, app, cor, origem="mao", extra=""):
        caminho = _mapa_de_convertidos_do_usuario()
        try:
            with open(caminho, "r", encoding="utf-8") as fh:
                linhas = fh.read().split("\n")
        except FileNotFoundError:
            linhas = ["# os desenhos da oficina do painel — o mesmo formato do apps-convertidos.map", ""]
        except OSError as e:
            return "não consegui ler o mapa dos convertidos: %s" % e
        linha = "%s:%s:%s" % (app, origem or "mao", cor)
        if extra:
            linha += ":" + extra

        def id_da_linha(l):
            corte = l.strip()
            if not corte or corte.startswith("#"):
                return None
            return corte.split(":")[0].strip()

        indice = next((i for i, l in enumerate(linhas) if id_da_linha(l) == app), None)
        if indice is not None:
            linhas[indice] = linha
        else:
            ultima = max((i for i, l in enumerate(linhas) if id_da_linha(l)), default=None)
            linhas.insert(ultima + 1 if ultima is not None else len(linhas), linha)
        try:
            os.makedirs(os.path.dirname(caminho), exist_ok=True)
            with open(caminho, "w", encoding="utf-8") as fh:
                fh.write("\n".join(linhas))
        except OSError as e:
            return "não consegui gravar o mapa: %s" % e
        return ""

    def _api_autorais(self, corpo):
        mod = modulo_pack()
        if not mod:
            return self._json({"erro": "o painel não carregou o scripts/pack.py"}, 500)
        adotado = _pack_adotado()
        dir_pack = (mod.achar(adotado) if adotado else None) or mod.dir_padrao()
        id_pack = os.path.basename(dir_pack.rstrip("/"))
        nome_pack = str(mod.campo(dir_pack, "nome", id_pack) or id_pack)
        try:
            with open(os.path.join(dir_pack, mod.campo(dir_pack, "paleta.arquivo", "paleta.json")),
                      encoding="utf-8") as fh:
                paleta = json.load(fh)
        except (OSError, ValueError) as e:
            return self._json({"erro": "não consegui ler a paleta do pack: %s" % e}, 500)
        accent = (valores_efetivos(["ACCENT"]).get("ACCENT") or "mauve").strip()
        declarados = mod.autorais(dir_pack)
        acao = str(corpo.get("acao", "listar")).strip()

        if acao == "listar":
            desenhos = []
            for nome, (caminho, dono) in sorted(declarados.items()):
                item = {"nome": nome, "pack": dono, "herdado": dono != id_pack,
                        "nome_origem": str(mod.campo(dono, "nome", dono) or dono)}
                try:
                    item["papeis"] = mod.ler_autoral(caminho)["papeis"]
                except mod.Recusa as e:
                    item["erro"] = str(e)
                desenhos.append(item)
            return self._json({"ok": True, "pack": id_pack, "nome_pack": nome_pack,
                               "desenhos": desenhos, "accent": accent,
                               "cores": list(mod.SLOTS) + [mod.MARCA_ACCENT]})

        nome = str(corpo.get("nome", "")).strip()
        if nome not in declarados:
            return self._json({"erro": "o pack não declara um desenho chamado %s" % nome}, 404)
        caminho, dono = declarados[nome]
        try:
            decl = mod.ler_autoral(caminho)
        except mod.Recusa as e:
            return self._json({"erro": str(e)}, 422)

        papeis = corpo.get("papeis")
        if papeis is not None:
            if not isinstance(papeis, dict) or set(papeis) != set(decl["papeis"]):
                return self._json({"erro": "os papéis têm de ser os do desenho: %s"
                                           % ", ".join(sorted(decl["papeis"]))}, 400)
            novos = {}
            for papel, par in papeis.items():
                par = par if isinstance(par, dict) else {}
                lados = {lado: str(par.get(lado, "")) for lado in ("escuro", "claro")}
                if any(v not in mod.SLOTS and v != mod.MARCA_ACCENT for v in lados.values()):
                    return self._json({"erro": "%s: a cor tem de ser um nome da paleta" % papel}, 400)
                novos[papel] = lados
            decl = dict(decl, papeis=novos)

        if acao == "previa":
            previas = []
            for flavor, cores in (paleta.get("flavors") or {}).items():
                try:
                    svg = mod.desenhar_autoral(decl, cores, flavor in (paleta.get("claros") or []),
                                               accent, {"titulo": nome})
                except mod.Recusa as e:
                    return self._json({"erro": str(e)}, 422)
                previas.append({"flavor": flavor, "svg": svg,
                                "fundos": [{"nome": k, "cor": cores.get(k, "")}
                                           for k in ("crust", "base", "overlay0", "text")]})
            return self._json({"ok": True, "previas": previas})

        if acao != "salvar":
            return self._json({"erro": "ação desconhecida: %s" % acao}, 400)

        try:
            pasta = mod.dir_acervo("icones.autorais.desenhos", ref=dir_pack,
                                   padrao=mod.PASTA_AUTORAIS)
        except mod.Recusa as e:
            return self._json({"erro": str(e)}, 422)
        try:
            with open(caminho, encoding="utf-8") as fh:
                bruto = json.load(fh)
        except (OSError, ValueError) as e:
            return self._json({"erro": "não consegui reler a declaração: %s" % e}, 500)
        bruto["papeis"] = decl["papeis"]
        destino = os.path.join(pasta, nome + ".json")
        try:
            os.makedirs(pasta, exist_ok=True)
            tmp = destino + ".tmp"
            with open(tmp, "w", encoding="utf-8") as fh:
                fh.write(json.dumps(bruto, ensure_ascii=False, indent=2) + "\n")
            os.replace(tmp, destino)
        except OSError as e:
            return self._json({"erro": "não consegui gravar no pack: %s" % e}, 500)

        ambiente = dict(os.environ)
        ambiente["MEOW_PACK_DIR"] = dir_pack
        ambiente.pop("MEOW_PALETA", None)
        try:
            r = subprocess.run([sys.executable, os.path.join(RAIZ, "scripts", "gerar_icones_autorais.py"),
                                "--accent", accent, "--saida", pasta],
                               env=ambiente, capture_output=True, text=True, timeout=60)
        except (OSError, subprocess.SubprocessError) as e:
            return self._json({"erro": "gravei o desenho, e o gerador não rodou: %s" % e}, 500)
        if r.returncode != 0:
            return self._json({"erro": "gravei o desenho, e o gerador recusou: %s"
                                       % (r.stderr or r.stdout).strip()[-400:]}, 500)

        def _forma(texto):
            texto = re.sub(r"<title>.*?</title>", "", texto, flags=re.S)
            return re.sub(r"#[0-9A-Fa-f]{3,8}\b", "#", texto).strip()
        formas = set()
        for flavor in (paleta.get("flavors") or {}):
            try:
                with open(os.path.join(pasta, "%s-%s.svg" % (nome, flavor)), encoding="utf-8") as fh:
                    formas.add(_forma(fh.read()))
            except OSError:
                continue
        tema = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
        alvo = os.path.expanduser("~/.local/share/icons/%s/scalable/apps" % tema)
        na_tela = []
        try:
            instalados = sorted(a for a in os.listdir(alvo) if a.endswith(".svg"))
        except OSError:
            instalados = []
        for arq in instalados:
            try:
                with open(os.path.join(alvo, arq), encoding="utf-8", errors="replace") as fh:
                    if _forma(fh.read(400000)) in formas:
                        na_tela.append(arq[:-len(".svg")])
            except OSError:
                continue
        return self._json({"ok": True, "pack": id_pack, "nome_pack": nome_pack,
                           "copiou": dono != id_pack, "na_tela": na_tela,
                           "arquivo": os.path.relpath(destino, dir_pack)})

    def _travas_do_arcticons(self):
        intocaveis, prefixos = set(), ()
        try:
            with open(os.path.join(RAIZ, "scripts", "icones_apps_arcticons.sh"),
                      "r", encoding="utf-8") as fh:
                texto = fh.read()
            achado = re.search(r"^INTOCAVEIS=\(([^)]*)\)", texto, re.M)
            if achado:
                intocaveis = set(achado.group(1).split())
            achado = re.search(r"^INTOCAVEIS_PREFIXO=\(([^)]*)\)", texto, re.M)
            if achado:
                prefixos = tuple(achado.group(1).split())
        except OSError:
            pass
        curados = set()
        try:
            with open(os.path.join(RAIZ, "assets", "icones", "curadoria.map"),
                      "r", encoding="utf-8") as fh:
                for linha in fh:
                    campos = linha.rstrip("\n").split("\t", 2)
                    if (len(campos) == 3 and campos[0] and not campos[0].startswith("#")
                            and campos[1] and campos[2]):
                        curados.add(campos[0])
        except OSError:
            pass
        return intocaveis, prefixos, curados, self._mapa_convertidos()

    def _motivo_da_trava(self, travas, nomes, rotulo, vigor=None, do_pack=()):
        intocaveis, prefixos, curados, convertidos = travas
        nomes = [n for n in nomes if n]
        if any(n in intocaveis or (prefixos and n.startswith(prefixos)) for n in nomes):
            return "Fica como está, por pedido seu; só a oficina «Gerar ícone» o troca"
        if any(n in curados for n in nomes):
            return "Usa a arte da sua curadoria, que vence este acervo"
        if any(n in convertidos for n in nomes):
            if not vigor:
                return ("%s já tem desenho convertido do projeto. O traço dele se "
                        "troca na oficina «Gerar ícone», acima." % rotulo)
            alternativas = list(do_pack)
            if vigor.get("tipo") != "conversao":
                alternativas.append("a conversão em traço do projeto")
            alternativas.append("novas variações a partir do original")
            return ("%s veste %s. %s na oficina «Gerar ícone», acima: %s."
                    % (rotulo, vigor["frase"],
                       "As alternativas estão" if len(alternativas) > 1 else "A alternativa está",
                       _enumerar(alternativas)))
        return None

    def _tirar_do_mapa_arcticons(self, app):
        caminho = _mapa_de_traco_do_usuario()
        if not os.path.isfile(caminho):
            return False
        try:
            return bool(_gravar_escolha(caminho, app, None, ":"))
        except OSError:
            return False

    def do_POST(self):
        alvo = urlparse(self.path)
        consulta = parse_qs(alvo.query)
        if not self._host_confere():
            return self._recusar(403, "Host inesperado")
        if not self._origem_confere():
            return self._recusar(403, "Origem inesperada")
        if not self._token_confere(consulta):
            return self._recusar(403, "token de sessão ausente ou errado")
        tamanho = int(self.headers.get("Content-Length") or 0)
        teto = {"/api/acervo": 96 << 20,
                "/api/pack-importar": 64 << 20,
                "/api/criar": 8 << 20}.get(alvo.path, 1 << 20)
        if tamanho > teto:
            return self._recusar(413, "corpo grande demais")
        try:
            corpo = json.loads(self.rfile.read(tamanho).decode("utf-8") or "{}")
        except (ValueError, UnicodeDecodeError):
            return self._recusar(400, "corpo não é JSON")
        if not isinstance(corpo, dict):
            return self._recusar(400, "corpo não é um objeto")
        return self._api_post(alvo.path, corpo)

    def _servir_pagina(self):
        arquivo = os.path.join(PAGINA, "index.html")
        try:
            with open(arquivo, "r", encoding="utf-8") as fh:
                texto = fh.read()
        except OSError:
            return self._recusar(500, "não achei app/pagina/index.html")
        texto = texto.replace("@TOKEN@", html.escape(TOKEN, quote=True))
        return self._responder(texto, tipo=TIPOS[".html"], plantar_cookie=True)

    def _api_get(self, caminho, consulta):
        if caminho == "/api/esquema":
            return self._json(self._dados_esquema())

        if caminho == "/api/pendencias":
            return self._json({"pendencias": pendencias()})

        if caminho == "/api/precisa-de-gente":
            return self._json({"itens": precisa_de_gente()})

        if caminho == "/api/packs":
            return self._json({"packs": packs_com_vitrine()})

        if caminho == "/api/apps":
            return self._api_apps(consulta)

        if caminho == "/api/glifos":
            return self._api_glifos(consulta)

        if caminho == "/api/jogos":
            return self._api_jogos(consulta)

        if caminho == "/api/criar":
            return self._api_criar_ler(consulta)

        if caminho == "/api/sons":
            return self._api_sons(consulta)

        if caminho == "/api/rascunho":
            return self._json({"rascunho": _rascunho_ler()})

        if caminho == "/api/previas":
            dados = previas(consulta.get("tipo", [""])[0],
                            consulta.get("grupo", [""])[0] or None)
            if dados is None:
                return self._json({"erro": "tipo de prévia desconhecido"}, 404)
            return self._json(dados)

        if caminho == "/api/trabalho":
            ident = consulta.get("id", [""])[0]
            desde = consulta.get("desde", ["0"])[0]
            try:
                trabalho = TRABALHOS[int(ident)]
                inicio = int(desde)
            except (KeyError, ValueError):
                return self._json({"erro": "trabalho desconhecido"}, 404)
            linhas, total = trabalho.desde(inicio)
            linhas = [texto_na_tela(l) for l in linhas]
            pasta = getattr(trabalho, "pasta_restauro", None)
            return self._json({
                "id": trabalho.id, "rotulo": trabalho.rotulo,
                "linhas": linhas, "proximo": total,
                "vivo": trabalho.vivo(), "rc": trabalho.rc,
                "segundos": round((trabalho.fim or time.time()) - trabalho.comeco, 1),
                "restauravel": bool(pasta) and not trabalho.vivo() and _tem_tocados(pasta),
            })

        if caminho == "/api/exportar/conf":
            texto, nome = exportar_conf()
            return self._baixar(texto, nome, "text/plain; charset=utf-8")

        if caminho == "/api/exportar/pagina":
            texto, nome = self._exportar_pagina()
            return self._baixar(texto, nome, TIPOS[".html"])

        if caminho == "/api/pack-exportar":
            return self._api_pack_exportar(consulta)

        return self._recusar(404, "não existe aqui")

    def _api_pack_exportar(self, consulta):
        ident = consulta.get("id", [""])[0]
        mod = modulo_pack()
        if not mod or ident not in _packs_no_disco():
            return self._json({"erro": "não conheço esse pack"}, 404)
        medir = consulta.get("medir", [""])[0] == "1"
        extra = ["--sem-imagens"] if consulta.get("imagens", [""])[0] == "nao" else []
        with tempfile.TemporaryDirectory(prefix="meow-exporta-") as pasta:
            saida = os.path.join(pasta, ident + ".meowpack")
            try:
                r = subprocess.run(_meow("pack", "exportar", ident, saida, *extra),
                                   capture_output=True, text=True, timeout=120,
                                   stdin=subprocess.DEVNULL,
                                   env=_ambiente_do_painel(seco=medir))
            except (OSError, subprocess.SubprocessError) as erro:
                return self._json({"erro": "não consegui rodar: %s" % erro}, 500)
            if r.returncode != 0 or not (medir or os.path.isfile(saida)):
                texto = (r.stderr or "").strip() or (r.stdout or "").strip()
                return self._json({"erro": texto or "o exportar falhou", "rc": r.returncode}, 400)
            if medir:
                m = mod.medir_exportacao(ident)
                m.update(tamanho=mod._mb(m["bytes"]),
                         tamanho_imagens=mod._mb(m["bytes_imagens"]),
                         tamanho_sem_imagens=mod._mb(m["bytes"] - m["bytes_imagens"]))
                m["avisos"] = [linha.strip()[2:].strip()
                               for linha in (r.stderr or "").splitlines()
                               if linha.strip().startswith("!!")]
                return self._json(m)
            with open(saida, "rb") as fh:
                corpo = fh.read()
        return self._baixar(corpo, ident + ".meowpack", "application/zstd")

    def _api_sons(self, consulta):
        mod = modulo_pack()
        if not mod:
            return self._json({"erro": "scripts/pack.py não carregou"}, 500)
        try:
            with open(os.path.join(RAIZ, "assets", "sons", "eventos.json"), encoding="utf-8") as fh:
                catalogo = json.load(fh)["eventos"]
        except (OSError, ValueError, KeyError):
            return self._json({"erro": "assets/sons/eventos.json não abriu"}, 500)
        ident = consulta.get("id", [""])[0] or _pack_adotado()
        dir_pack = mod.achar(ident) if ident in _packs_no_disco() else None
        do_pack = {e for _c, e, _a in mod.sons_do_pack(dir_pack)} if dir_pack else set()
        eventos = [dict(s, origem="pack" if s["evento"] in do_pack else "sistema")
                   for s in catalogo]
        return self._json({"pack": ident, "eventos": eventos})

    def _api_criar_ler(self, consulta):
        mod = modulo_pack()
        if not mod:
            return self._json({"erro": "scripts/pack.py não carregou"}, 500)
        ident = consulta.get("id", [""])[0]
        icones = {}
        for pasta in mod.PASTAS_QUE_SE_LEVAM:
            icones[pasta] = []
            try:
                oferta = mod.acervo_para_levar(ident or None, pasta)
            except mod.Recusa:
                oferta = []
            for de, nome, arq, levado in oferta:
                _ICONES_DECLARADOS.add(os.path.normpath(arq))
                icones[pasta].append({"de": de, "nome": nome, "levado": levado,
                                      "url": "/previa?tipo=arquivo&id=" + quote(arq, safe="")})
        if not ident:
            return self._json(dict(icones, id="", fotos=[], sons=[]))
        try:
            dir_pack = mod.pack_da_pessoa(ident)
        except mod.Recusa as e:
            return self._json({"erro": texto_na_tela(str(e))}, 404)
        no_pack = set(mod.fotos_do_pack(dir_pack))
        try:
            nomes = sorted(os.listdir(os.path.join(_wallpaper_base(), "ativos")))
        except OSError:
            nomes = []
        sons = [{"evento": e, "contexto": c} for c, e, _a in mod.sons_do_pack(dir_pack)
                if e != "audio-volume-change"]
        return self._json(dict(icones, id=ident, sons=sons,
                               fotos=[n for n in nomes if mod.nome_da_foto(ident, n) in no_pack]))

    def _api_criar(self, corpo):
        mod = modulo_pack()
        if not mod:
            return self._json({"erro": "scripts/pack.py não carregou"}, 500)
        ident = str(corpo.get("id", ""))
        tipo = str(corpo.get("tipo", ""))
        nome = os.path.basename(str(corpo.get("nome", "")))
        levar = corpo.get("levar") is True
        try:
            if tipo == "foto":
                if levar:
                    pasta = os.path.realpath(os.path.join(_wallpaper_base(), "ativos"))
                    origem = os.path.join(pasta, nome)
                    if not nome or os.path.dirname(os.path.realpath(origem)) != pasta:
                        return self._json({"erro": "essa foto não está no carrossel"}, 404)
                    feito = mod.levar_foto(ident, origem)
                else:
                    feito = mod.nome_da_foto(ident, nome)
                    mod.tirar_foto(ident, feito)
            elif tipo in mod.PASTAS_QUE_SE_LEVAM:
                if levar:
                    de = str(corpo.get("de", ""))
                    arq = next((a for p_, n, a, _l in mod.acervo_para_levar(ident, tipo)
                                if p_ == de and n == nome), None)
                    if not arq:
                        return self._json({"erro": "não achei esse ícone no pack «%s»" % de}, 404)
                    feito = mod.levar_icone(ident, tipo, arq, nome)
                else:
                    mod.tirar_icone(ident, tipo, nome)
                    feito = nome
            elif tipo == "som":
                try:
                    dados = base64.b64decode(str(corpo.get("conteudo", "")), validate=True)
                except Exception:
                    return self._json({"erro": "conteúdo não é base64"}, 400)
                ext = os.path.splitext(os.path.basename(str(corpo.get("arquivo", ""))))[1]
                with tempfile.TemporaryDirectory(prefix="meow-som-") as pasta:
                    caminho = os.path.join(pasta, "som" + re.sub(r"[^A-Za-z0-9.]", "", ext)[:8])
                    with open(caminho, "wb") as fh:
                        fh.write(dados)
                    feito = mod.levar_som(ident, caminho, nome)
            elif tipo == "sons":
                de = str(corpo.get("de", ""))
                if de not in _packs_no_disco():
                    return self._json({"erro": "não conheço o pack «%s»" % de}, 404)
                feito = mod.levar_sons_de(ident, de)
            else:
                return self._json({"erro": "não sei levar isso"}, 400)
        except mod.Recusa as e:
            return self._json({"erro": texto_na_tela(str(e))}, 400)
        except OSError as e:
            return self._json({"erro": "não consegui gravar no pack: %s" % e}, 500)
        return self._json({"ok": True, "tipo": tipo, "nome": feito, "levado": levar})

    def _api_pack_importar(self, corpo):
        mod = modulo_pack()
        if not mod:
            return self._json({"erro": "scripts/pack.py não carregou"}, 500)
        try:
            dados = base64.b64decode(str(corpo.get("conteudo", "")), validate=True)
        except Exception:
            return self._json({"erro": "conteúdo não é base64"}, 400)
        if not dados:
            return self._json({"erro": "o arquivo veio vazio"}, 400)
        confirmado = corpo.get("confirmado") is True
        envio = os.path.basename(str(corpo.get("nome") or ""))
        de_csv = envio.lower().endswith(".csv")
        with tempfile.TemporaryDirectory(prefix="meow-importa-") as pasta:
            if de_csv:
                try:
                    mod.id_do_csv(envio)
                except mod.Recusa as erro:
                    return self._json({"erro": str(erro)}, 400)
                caminho = os.path.join(pasta, envio)
            else:
                caminho = os.path.join(pasta, "envio.meowpack")
            try:
                with open(caminho, "wb") as fh:
                    fh.write(dados)
            except (OSError, ValueError) as erro:
                return self._json({"erro": "não consegui receber %s: %s" % (envio, erro)}, 400)
            try:
                r = subprocess.run(_meow("pack", "importar", caminho),
                                   capture_output=True, text=True, timeout=120,
                                   stdin=subprocess.DEVNULL,
                                   env=_ambiente_do_painel(seco=not confirmado))
            except (OSError, subprocess.SubprocessError) as erro:
                return self._json({"erro": "não consegui rodar: %s" % erro}, 500)
            if r.returncode != 0:
                texto = (r.stderr or "").strip() or (r.stdout or "").strip()
                texto = texto.replace(caminho, envio or "o arquivo enviado")
                return self._json({"erro": texto or "o importar falhou", "rc": r.returncode}, 400)
            pack = mod.resumo_csv(caminho) if de_csv else mod.resumo_meowpack(caminho)
        nome = pack["nome"]
        if not confirmado:
            if de_csv:
                resumo = ("Um pack novo, «%s», feito de %s: a paleta é a do CSV, e o resto "
                          "vem do %s pela herança. Ele entra como opção entre os packs — "
                          "nada do seu tema muda até você escolher usá-lo."
                          % (pack["id"], envio, pack["heranca"]))
            else:
                quantos = "{:,}".format(pack["arquivos"]).replace(",", ".")
                por = "Por %s. " % pack["autor"] if pack["autor"] else ""
                resumo = ("%s%s arquivo(s), %s. Ele entra como opção entre os packs — "
                          "nada do seu tema muda até você escolher usá-lo."
                          % (por, quantos, mod._mb(pack["bytes"])))
            return self._json({
                "precisa_confirmar": True,
                "titulo": "Importar o pack «%s»?" % nome,
                "resumo": resumo,
                "pack": pack,
            })
        return self._json({
            "instalado": True, "id": pack["id"], "pack": pack,
            "frase": "O %s entrou — ele aparece entre os packs, e usar é outro clique." % nome,
        })

    def _baixar(self, corpo, nome, tipo):
        return self._responder(
            corpo, tipo=tipo,
            extras={"Content-Disposition":
                    'attachment; filename="%s"' % nome.replace('"', "")})

    AMOSTRA_POR_TIPO = {"parede": 30, "icone": 0, "cursor": 0, "gato": 0}
    AMOSTRA_APPS = 36
    AMOSTRA_JOGOS = 12
    TETO_IMAGEM = 160 << 10
    TETO_TOTAL = 12 << 20

    def _svg_vazado(self):
        return ("data:image/svg+xml;charset=utf-8," + quote(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
            '<rect x="1" y="1" width="46" height="46" rx="6" fill="none" '
            'stroke="currentColor" stroke-opacity=".35" stroke-dasharray="4 3"/>'
            '</svg>', safe=""))

    def _embutir(self, caminho, sacola, gasto):
        try:
            tamanho = os.path.getsize(caminho)
        except OSError:
            return None, gasto
        if tamanho > self.TETO_IMAGEM or gasto + tamanho > self.TETO_TOTAL:
            return None, gasto
        try:
            with open(caminho, "rb") as fh:
                bruto = fh.read()
        except OSError:
            return None, gasto
        ext = os.path.splitext(caminho)[1].lower()
        mime = {".svg": "image/svg+xml", ".png": "image/png", ".jpg": "image/jpeg",
                ".jpeg": "image/jpeg", ".webp": "image/webp"}.get(ext)
        if mime is None:
            return None, gasto
        uri = "data:%s;base64,%s" % (mime, base64.b64encode(bruto).decode("ascii"))
        return uri, gasto + tamanho

    def _imagens_da_amostra(self, esquema, apps, jogos):
        mapa, gasto = {}, 0

        corpo_logo = self._logo_do_painel()
        if corpo_logo:
            mapa["/logo.svg"] = "data:image/svg+xml;base64," + base64.b64encode(
                corpo_logo).decode("ascii")
            gasto += len(corpo_logo)

        for tipo, limite in self.AMOSTRA_POR_TIPO.items():
            dados = previas(tipo) or {}
            itens = dados.get("itens", [])
            if limite:
                itens = itens[:limite]
            for item in itens:
                if not item.get("pronta"):
                    continue
                bytes_e_tipo = previa_bytes(tipo, item["id"])
                if not bytes_e_tipo:
                    continue
                bruto, mime = bytes_e_tipo
                if len(bruto) > self.TETO_IMAGEM or gasto + len(bruto) > self.TETO_TOTAL:
                    continue
                mapa[item["url"]] = "data:%s;base64,%s" % (
                    mime, base64.b64encode(bruto).decode("ascii"))
                gasto += len(bruto)

        for lista, quantos in ((apps.get("apps", []), self.AMOSTRA_APPS),
                               (jogos.get("jogos", []), self.AMOSTRA_JOGOS)):
            entraram = 0
            for item in lista:
                if entraram >= quantos:
                    break
                url = item.get("url") or ""
                if not url or url in mapa:
                    continue
                consulta_img = parse_qs(urlparse(url).query)
                alvo = consulta_img.get("id", [""])[0]
                if not alvo:
                    continue
                uri, novo = self._embutir(alvo, mapa, gasto)
                if uri:
                    mapa[url] = uri
                    gasto = novo
                    entraram += 1
        return mapa, gasto

    def _exportar_pagina(self):
        esquema = self._dados_esquema()
        apps = self._dados_apps({})
        jogos = self._dados_jogos({})
        previas_congeladas = {}
        for tipo in PREVIA_FONTES:
            dados = previas(tipo) or {}
            previas_congeladas[tipo] = dados
            for grupo in PREVIA_GRUPOS.get(tipo, ()):
                previas_congeladas["%s/%s" % (tipo, grupo)] = previas(tipo, grupo) or {}
        imagens, gasto = self._imagens_da_amostra(esquema, apps, jogos)

        valores = valores_efetivos(["FLAVOR", "ACCENT", "MODO"])
        flavor = _flavor_do_conf(valores)
        flavor = _flavor_da_pagina(flavor, valores)
        paleta = paleta_css(flavor, _acento_da_pagina(flavor, valores))

        def ler(nome):
            try:
                with open(os.path.join(PAGINA, nome), "r", encoding="utf-8") as fh:
                    return fh.read()
            except OSError:
                return ""

        pagina = ler("index.html")
        corpo = pagina
        if "<body" in corpo:
            corpo = corpo[corpo.index("<body"):]
        corpo = corpo.replace('data-token="@TOKEN@"', 'data-token="" data-standalone="1"')
        scripts_da_pagina = re.findall(r'<script src="/([A-Za-z0-9_.-]+\.js)"></script>', corpo)
        corpo = re.sub(r'<script src="/[A-Za-z0-9_.-]+\.js"></script>', "", corpo)
        corpo = corpo.replace("</body>", "").replace("</html>", "")

        dados = {
            "esquema": esquema, "apps": apps, "jogos": jogos,
            "previas": previas_congeladas, "imagens": imagens,
            "exportado_em": time.strftime("%d/%m/%Y às %H:%M"),
            "maquina": {"flavor": flavor, "accent": valores.get("ACCENT") or "mauve",
                        "modo": valores.get("MODO") or ""},
            "amostra": {"imagens": len(imagens), "bytes": gasto},
        }
        outras = []
        for item in esquema.get("chaves", []):
            if any(re.search(r"(?:^|[\s:=,])(?:/(?!/)|~(?:/|$)|\$\{?HOME\b)",
                             item.get(campo) or "")
                   for campo in ("valor", "efetivo")):
                efetivo = item.get("efetivo") or os.path.expandvars(item.get("valor") or "")
                for pedaco in efetivo.split(":"):
                    pedaco = os.path.expanduser(pedaco.strip()).rstrip(os.sep)
                    if not pedaco.startswith(os.sep) or pedaco.startswith("//"):
                        continue
                    for forma in dict.fromkeys((pedaco, os.path.realpath(pedaco))):
                        if forma != RAIZ and not _na_casa(forma) \
                                and not forma.startswith(RAIZ + os.sep):
                            outras.append((forma, "$" + item["chave"]))
                item["valor"] = item.get("padrao", "")
                item["efetivo"] = ""
        outras.sort(key=lambda par: -len(par[0]))
        dados = sem_casa_nem_raiz(dados, outras)

        partes = [
            "<!DOCTYPE html>",
            "<!--",
            "  A PÁGINA DO MEOWSYSTEM, INTEIRA, NUM ARQUIVO SÓ.",
            "",
            "  Exportada em %s. Nada aqui fala com servidor nenhum: os dados" % dados["exportado_em"],
            "  estão congelados no <script id=\"meow-dados\"> lá embaixo, e as",
            "  imagens são uma amostra do acervo desta máquina (%d delas)." % len(imagens),
            "",
            "  PARA QUEM VAI REDESENHAR",
            "    O que volta para o projeto é o conteúdo de",
            "    <style id=\"folha-do-painel\"> — ele é o app/pagina/estilo.css",
            "    inteiro, e é copiado de volta sem tradução nenhuma. Mexa nele",
            "    à vontade.",
            "",
            "    O contrato são os NOMES DE CLASSE: .cartao, .trilho, .btn,",
            "    .pastilha, .gaveta e companhia são gerados por JavaScript e",
            "    também consumidos por ele. Mudar a aparência de uma classe é",
            "    grátis; renomear ou apagar uma classe quebra a página. Se o",
            "    desenho pedir estrutura nova, descreva a mudança em texto no",
            "    fim do arquivo, num comentário — é mais rápido de aplicar do",
            "    que adivinhar a intenção a partir do HTML.",
            "-->",
            '<html lang="pt-BR">',
            "<head>",
            '<meta charset="utf-8">',
            '<meta name="viewport" content="width=device-width, initial-scale=1">',
            "<title>MeowSystem — página para redesenho</title>",
            '<style id="paleta-do-painel">\n%s\n</style>' % paleta,
            '<style id="folha-do-painel">\n%s\n</style>' % ler("estilo.css"),
            '<style id="folha-dos-sons">\n%s\n</style>' % ler("sons.css"),
            '<style id="folha-do-standalone">\n%s\n</style>' % ler("standalone.css"),
            "</head>",
            corpo,
            '<script id="meow-dados" type="application/json">%s</script>'
            % json.dumps(dados, ensure_ascii=False).replace("</", "<\\/"),
            "<script>\n%s\n</script>" % ler("standalone.js"),
        ] + [
            "<script>\n%s\n</script>" % ler(nome) for nome in scripts_da_pagina
        ] + [
            "</body>",
            "</html>",
        ]
        return "\n".join(partes), "meowsystem-painel-%s.html" % _carimbo()

    @_numa_leitura
    def _dados_esquema(self):
        esquema = ler_esquema()
        chaves = [i["chave"] for i in esquema]
        brutos = valores_brutos()
        efetivos = valores_efetivos(chaves)
        som_vale = _som_ajuste_vale()
        for item in esquema:
            item["valor"] = brutos.get(item["chave"], "")
            item["efetivo"] = efetivos.get(item["chave"], "")
            if item["chave"] in _SOM_TIMBRE_DE_FABRICA:
                if not som_vale:
                    item["valor"] = ""
                if item["valor"] == "":
                    item["efetivo"] = item.get("padrao_do_pack") or ""
            if item["chave"] in _LEITURA_NO_APPLET and item.get("valendo_agora") is not None:
                item["valor_no_arquivo"] = item["valor"]
                item["valor"] = item["valendo_agora"]
                item["fonte"] = "applet"
        vocab = vocabulario_do_pack()
        _com_o_vocabulario_do_pack(esquema, vocab, efetivos)
        if isinstance(vocab, dict):
            vocab["lados"] = _lados_do_pack()
        for item in esquema:
            teto = teto_da_chave(item["chave"])
            if teto:
                item["teto"] = teto
        so_com = [i for i in esquema if i.get("so_com_app")]
        if so_com:
            desktops = {d["id"] for d in self._desktops()}
            for item in so_com:
                item["sem_programa"] = not any(ident in desktops for ident in item["so_com_app"])
        com_ids = [i for i in esquema if i.get("ids_de_desktop")]
        if com_ids:
            por_id = {d["id"]: d for d in self._desktops()}
            tema = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
            base_tema = os.path.expanduser("~/.local/share/icons/%s" % tema)
            for item in com_ids:
                citados = ",".join((item.get("valor") or "", item.get("padrao") or ""))
                programas = {}
                for ident in dict.fromkeys(x.strip() for x in citados.split(",")):
                    d = por_id.get(ident)
                    if not d:
                        continue
                    atual, _nosso = self._icone_na_tela(d, base_tema)
                    programas[ident] = {
                        "nome": d["nome"],
                        "icone": ("/previa?tipo=arquivo&id=" + quote(atual, safe=""))
                                 if atual else "",
                    }
                item["programas"] = programas
        medidas = dict(_medidas_do_projeto(), **_medidas_da_tela())
        restauros_agora = restauros()
        return {
            "conf": texto_na_tela(CONF),
            "casa": os.path.expanduser("~"),
            "conf_existe": os.path.isfile(CONF),
            "exemplo": CONF_PADRAO,
            "raiz": RAIZ,
            "chaves": esquema,
            "repositorio": _repositorio_no_ar(),
            "gato_no_dock": _gato_no_dock(),
            "noite_do_applet": _noite_do_applet(),
            "capturas": _capturas_no_disco(),
            "acentos_que_aplicam": _acentos_que_aplicam(esquema),
            "medidas": medidas,
            "acoes": [
                dict({c: x for c, x in v.items() if not callable(x)}, id=k,
                     ajuda=_com_medidas(v.get("ajuda", ""),
                                        medidas),
                     argv=None,
                     escreve=escreve(v),
                     restauro=k in restauros_agora,
                     sudo=bool(v.get("sudo")) and not (
                         k in _PELA_PONTE and _ponte_viva()),
                     pela_ponte=bool(v.get("sudo")) and (
                         k in _PELA_PONTE and _ponte_viva()),
                     indisponivel=indisponivel(k),
                     opcoes=([] if v.get("oculta")
                             else PROVEDORES[v["arg"]]() if "arg" in v else []))
                for k, v in ACOES.items()
            ],
            "ponte": _ponte_viva(),
            "mesmo_horario": mesmo_horario_ligado(),
            "horario_das_areas": [{"area": a, "chaves": [ci, cf]}
                                  for a, ci, cf, _f in horario_das_areas()],
            "pack": vocab,
            "folhas": self._folhas(),
            "paleta": {
                "ordem": _paleta_dados().get("ordem_canonica", []),
                "claros": _paleta_dados().get("claros", []),
                "flavors": _paleta_dados().get("flavors", {}),
            },
        }

    def _api_post(self, caminho, corpo):
        if caminho == "/api/definir":
            chave = str(corpo.get("chave", ""))
            valor = str(corpo.get("valor", ""))
            item = next((i for i in ler_esquema() if i["chave"] == chave), None)
            if item is None:
                return self._json({"erro": "chave fora do meow.conf.exemplo"}, 400)
            queixa = validar_valor(item, valor)
            if queixa:
                return self._json({"erro": queixa, "chave": chave, "valor": valor}, 400)
            soltas = pontas_da_noite_soltas({chave: valor})
            if soltas:
                return self._json({"erro": soltas[0]["erro"], "chave": chave,
                                   "valor": valor, "recusadas": soltas}, 409)
            pares = _som_carimbar(com_o_mesmo_horario([(chave, valor)]))
            feitos = definir_varias(pares)
            _chave, rc, saida = feitos[0]
            if rc != 2:
                _som_carimbo_gravar(pares)
            if len(pares) > 1:
                _adotar_leitura([c for c, r, _s in feitos[1:] if r == 1])
            return self._json({"rc": rc, "saida": texto_na_tela(saida),
                               "chave": chave, "valor": valor})

        if caminho == "/api/salvar":
            mudancas = corpo.get("mudancas") or {}
            if not isinstance(mudancas, dict):
                return self._json({"erro": "as escolhas chegaram num formato que não conheço"}, 400)
            esquema = {i["chave"]: i for i in ler_esquema()}
            pares, recusadas = [], []
            for chave, valor in mudancas.items():
                chave, valor = str(chave), str(valor)
                item = esquema.get(chave)
                queixa = ("fora do meow.conf.exemplo" if item is None
                          else validar_valor(item, valor))
                if queixa:
                    recusadas.append({"chave": chave, "erro": queixa})
                else:
                    pares.append((chave, valor))
            if recusadas:
                return self._json({"recusadas": recusadas}, 400)
            soltas = pontas_da_noite_soltas(dict(pares))
            if soltas:
                return self._json({"recusadas": soltas}, 409)
            pares = _som_carimbar(com_o_mesmo_horario(pares))

            if corpo.get("seco"):
                pasta, queixa = _conf_de_ensaio(pares)
                if queixa:
                    return self._json({"erro": queixa}, 500)
                trabalho, erro = iniciar("instalar", "", confirmado=True,
                                         seco=True, pasta_de_ensaio=pasta)
                if erro:
                    shutil.rmtree(pasta, ignore_errors=True)
                    return self._json(
                        {"erro": erro["erro"] if isinstance(erro, dict) else erro}, 409)
                return self._json({"trabalho": _trabalho_json(trabalho, "instalar", seco=True)})

            try:
                with open(CONF, "rb") as fh:
                    conf_antes = fh.read()
            except OSError:
                conf_antes = None
            gravadas, iguais, falhas = [], [], []
            for chave, rc, saida in definir_varias(pares):
                if rc == 0:
                    iguais.append(chave)
                elif rc == 1:
                    gravadas.append(chave)
                else:
                    falhas.append({"chave": chave,
                                   "erro": texto_na_tela(saida) or "não consegui gravar"})
            if falhas:
                return self._json({"gravadas": gravadas, "iguais": iguais, "falhas": falhas,
                                   "erro": "nem tudo foi gravado, e nada foi aplicado"}, 500)
            _som_carimbo_gravar(pares)

            resposta = {"gravadas": gravadas, "iguais": iguais}
            leitura = [c for c, _v in pares if c in _LEITURA_NO_APPLET]
            if leitura:
                try:
                    feito = subprocess.run(_meow("leitura", "adotar", *leitura),
                                           capture_output=True, timeout=20,
                                           env=_ambiente_do_painel())
                    if feito.returncode not in (0, 1):
                        resposta["aviso"] = texto_na_tela(
                            feito.stdout.decode("utf-8", "replace")
                            + feito.stderr.decode("utf-8", "replace")).strip()
                except (OSError, subprocess.SubprocessError) as e:
                    resposta["aviso"] = "o controle do modo de leitura não foi atualizado: %s" % e
            trabalho, erro = iniciar("instalar", "", confirmado=True,
                                     antes={CONF: conf_antes} if gravadas else None)
            if erro:
                resposta["erro"] = erro["erro"] if isinstance(erro, dict) else erro
                return self._json(resposta, 409)
            resposta["trabalho"] = _trabalho_json(trabalho, "instalar")
            return self._json(resposta)

        if caminho == "/api/acervo":
            return self._api_acervo(corpo)

        if caminho == "/api/app-icone":
            return self._api_app_icone(corpo)

        if caminho == "/api/app-desenho":
            return self._api_app_desenho(corpo)

        if caminho == "/api/autorais":
            return self._api_autorais(corpo)

        if caminho == "/api/jogo-fora":
            return self._api_jogo_fora(corpo)

        if caminho == "/api/rodar":
            acao = str(corpo.get("acao", ""))
            argumento = str(corpo.get("argumento", "") or "")
            seco = bool(corpo.get("seco"))
            trabalho, erro = iniciar(acao, argumento,
                                     confirmado=bool(corpo.get("confirmado")),
                                     seco=seco)
            if erro:
                return self._json(erro if isinstance(erro, dict) else {"erro": erro}, 409)
            return self._json(_trabalho_json(trabalho, acao, seco=seco))

        if caminho == "/api/criar":
            return self._api_criar(corpo)
        if caminho == "/api/mesmo-horario":
            try:
                gravadas, erro = ligar_mesmo_horario(corpo.get("ligar") is True)
            except OSError as e:
                return self._json({"erro": "não consegui guardar o horário de cada área: %s" % e}, 500)
            if erro:
                return self._json({"erro": erro}, 500)
            return self._json({"ok": True, "ligado": mesmo_horario_ligado(), "gravadas": gravadas})
        if caminho == "/api/rascunho":
            if not _rascunho_gravar(corpo.get("rascunho")):
                return self._json({"erro": "rascunho que não serve"}, 400)
            return self._json({"ok": True})
        if caminho == "/api/pack-importar":
            return self._api_pack_importar(corpo)

        if caminho == "/api/importar":
            texto = str(corpo.get("texto", ""))
            if not texto.strip():
                return self._json({"erro": "o arquivo veio vazio"}, 400)
            return self._json(importar_conf(texto))

        if caminho == "/api/pendencia-recusar":
            ident = str(corpo.get("id", ""))
            argv = RECUSA_DA_PENDENCIA.get(ident)
            if argv is None:
                return self._json({"erro": "esta pendência não aceita recusa"}, 404)
            try:
                fim = subprocess.run(argv, capture_output=True, timeout=30,
                                     env=_ambiente_do_painel())
            except (OSError, subprocess.SubprocessError) as erro:
                return self._json({"erro": "não consegui gravar a recusa: %s" % erro}, 500)
            return self._json({"recusada": ident, "rc": fim.returncode})

        if caminho == "/api/parar":
            try:
                trabalho = TRABALHOS[int(corpo.get("id", -1))]
            except (KeyError, ValueError, TypeError):
                return self._json({"erro": "trabalho desconhecido"}, 404)
            return self._json({"parado": trabalho.parar()})

        if caminho == "/api/guardar-log":
            try:
                trabalho = TRABALHOS[int(corpo.get("id", -1))]
            except (KeyError, ValueError, TypeError):
                return self._json({"erro": "trabalho desconhecido"}, 404)
            try:
                caminho_log = guardar_log(trabalho)
            except OSError as erro:
                return self._json({"erro": "não consegui guardar o log: %s" % erro}, 500)
            return self._json({"caminho": texto_na_tela(caminho_log)})
        return self._recusar(404, "não existe aqui")

    def _folhas(self):
        try:
            nomes = sorted(f for f in os.listdir(FOLHAS) if f.endswith(".html"))
        except OSError:
            return []
        return [{"arquivo": n, "caminho": os.path.join(FOLHAS, n)} for n in nomes]


VIGIA_LIGADO = os.environ.get("MEOW_APP_VIGIA") == "1"
VIGIA_CARENCIA = float(os.environ.get("MEOW_APP_CARENCIA") or 8)
VIGIA_ESPERA = float(os.environ.get("MEOW_APP_ESPERA") or 120)
PULSO_BATIDA = 15.0

_PULSOS = {"abertos": 0, "houve": False, "zerou_em": None}
_PULSO_TRAVA = threading.Lock()


def _pulso_entra():
    with _PULSO_TRAVA:
        _PULSOS["abertos"] += 1
        _PULSOS["houve"] = True
        _PULSOS["zerou_em"] = None


def _pulso_sai():
    with _PULSO_TRAVA:
        _PULSOS["abertos"] = max(0, _PULSOS["abertos"] - 1)
        if _PULSOS["abertos"] == 0:
            _PULSOS["zerou_em"] = time.time()


def _ha_trabalho_vivo():
    return any(t.vivo() for t in list(TRABALHOS.values()))


def _vigia(servidor, comeco):
    while True:
        time.sleep(1.0)
        with _PULSO_TRAVA:
            abertos = _PULSOS["abertos"]
            houve = _PULSOS["houve"]
            zerou = _PULSOS["zerou_em"]
        agora = time.time()
        if not houve:
            if agora - comeco > VIGIA_ESPERA:
                motivo = "a página não abriu em %d s" % VIGIA_ESPERA
                break
            continue
        if abertos > 0 or zerou is None or agora - zerou < VIGIA_CARENCIA:
            continue
        if _ha_trabalho_vivo():
            continue
        motivo = "a janela foi fechada"
        break
    sys.stderr.write("painel: %s — encerrando.\n" % motivo)
    sys.stderr.flush()
    servidor.shutdown()


def _aquecer():
    try:
        _acentos_que_aplicam(ler_esquema())
    except Exception:
        pass


def main():
    threading.Thread(target=_aquecer, daemon=True).start()
    for _ in range(3):
        threading.Thread(target=_operario, daemon=True).start()
    servidor = ThreadingHTTPServer(("127.0.0.1", 0), Manipulador)
    servidor.daemon_threads = True
    porta = servidor.server_address[1]
    if VIGIA_LIGADO:
        threading.Thread(target=_vigia, args=(servidor, time.time()),
                         daemon=True).start()
    sys.stdout.write("http://127.0.0.1:%d/?t=%s\n" % (porta, TOKEN))
    sys.stdout.flush()
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        for trabalho in TRABALHOS.values():
            if trabalho.vivo():
                trabalho.parar()
        try:
            arquivo_pid = os.path.join(ESTADO, "app.pid")
            with open(arquivo_pid, "r", encoding="utf-8") as fh:
                if fh.read().strip() == str(os.getpid()):
                    os.unlink(arquivo_pid)
        except (OSError, ValueError):
            pass
        try:
            os.unlink(os.path.join(ESTADO, "paineis", "%d.pid" % os.getpid()))
        except OSError:
            pass
        servidor.server_close()


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--onde":
        if len(sys.argv) != 3:
            sys.stderr.write("uso: servidor.py --onde <ação, pendência, chave ou inicio>\n")
            sys.exit(2)
        frase = onde_na_tela(sys.argv[2])
        sys.stdout.write(frase + "\n" if frase else "")
        sys.exit(0 if frase else 1)
    main()

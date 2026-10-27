#!/usr/bin/env python3
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import unicodedata
import zlib
from urllib.parse import quote

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _arg(nome):
    if nome in sys.argv:
        i = sys.argv.index(nome)
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return None


SO_ABA = _arg("--aba")
FOTOS = _arg("--fotos")

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("FALHOU: o Playwright não está instalado neste interpretador:")
    print("  " + sys.executable)
    print("  este teste é o gate de merge e não sai pulado; a receita está no")
    print("  cabeçalho de tests/app-completo.py.")
    sys.exit(1)


BRINQUEDO = tempfile.mkdtemp(prefix="meow-completo-")
CASA = os.path.join(BRINQUEDO, "casa")
RAIZ_B = os.path.join(BRINQUEDO, "raiz")
FALSO = os.path.join(BRINQUEDO, "falso")
REGISTRO = os.path.join(BRINQUEDO, "registro")
CONF = os.path.join(CASA, ".config", "meow", "meow.conf")
ESTADO = os.path.join(CASA, ".local", "state", "meowsystem")
PAREDES = 6
APPID = "1715980"
PROGRAMA = ("org.gnome.Evince", "Leitor de Brinquedo")
NOME_NA_STEAM = "Demo de Brinquedo"
HOSTIL = '<img src=x onerror="window.__meow_xss=1">'


def valor_de(chave, conf=CONF):
    with open(conf, encoding="utf-8") as fh:
        for linha in fh:
            if linha.startswith(chave + "="):
                return linha.split("=", 1)[1].split("#")[0].strip().strip('"')
    return None


def png_liso(caminho, rgb, larg=64, alt=40):
    def pedaco(tipo, corpo):
        return (struct.pack(">I", len(corpo)) + tipo + corpo
                + struct.pack(">I", zlib.crc32(tipo + corpo) & 0xFFFFFFFF))
    linhas = (bytes([0]) + bytes(rgb) * larg) * alt
    with open(caminho, "wb") as fh:
        fh.write(bytes([0x89]) + "PNG\r\n".encode() + bytes([0x1A, 0x0A])
                 + pedaco("IHDR".encode(), struct.pack(">IIBBBBB", larg, alt, 8, 2, 0, 0, 0))
                 + pedaco("IDAT".encode(), zlib.compress(linhas))
                 + pedaco("IEND".encode(), bytes()))


def xcursor_liso(caminho, lado=24, argb=0xFFCDD6F4):
    pixels = bytes().join(struct.pack("<I", argb if x <= y else 0)
                          for y in range(lado) for x in range(lado))
    with open(caminho, "wb") as fh:
        fh.write("Xcur".encode() + struct.pack("<III", 16, 0x10000, 1)
                 + struct.pack("<III", 0xFFFD0002, lado, 28)
                 + struct.pack("<9I", 36, 0xFFFD0002, lado, 1, lado, lado, 0, 0, 0)
                 + pixels)


def appinfo_vdf(caminho, nomes):
    chaves = ["appinfo", "common", "name"]
    entradas = b""
    for appid, nome in nomes.items():
        kv = (bytes([0]) + struct.pack("<I", 0) + bytes([0]) + struct.pack("<I", 1)
              + bytes([1]) + struct.pack("<I", 2) + nome.encode("utf-8") + bytes([0])
              + bytes([8, 8, 8]))
        resto = struct.pack("<IIQ", 2, 0, 0) + bytes(20) + struct.pack("<I", 0) + bytes(20) + kv
        entradas += struct.pack("<II", int(appid), len(resto)) + resto
    entradas += struct.pack("<I", 0)
    tabela = struct.pack("<I", len(chaves)) + b"".join(c.encode() + bytes([0]) for c in chaves)
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with open(caminho, "wb") as fh:
        fh.write(struct.pack("<IIq", 0x07564429, 1, 16 + len(entradas)) + entradas + tabela)


def copiar_raiz():
    lista = subprocess.run(
        ["git", "-C", RAIZ, "ls-files", "-z", "--cached", "--others",
         "--exclude-standard"], capture_output=True, check=True).stdout
    for rel in sorted(set(filter(None, lista.decode().split("\0")))):
        origem, destino = os.path.join(RAIZ, rel), os.path.join(RAIZ_B, rel)
        if not os.path.lexists(origem):
            continue
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        if os.path.islink(origem):
            os.symlink(os.readlink(origem), destino)
        else:
            shutil.copy2(origem, destino)
    subprocess.run(["git", "init", "-q", RAIZ_B], check=True)
    remoto = subprocess.run(["git", "-C", RAIZ, "remote", "get-url", "origin"],
                            capture_output=True, text=True).stdout.strip()
    if remoto:
        subprocess.run(["git", "-C", RAIZ_B, "remote", "add", "origin", remoto],
                       check=True)


RECUSA_SH = """#!/bin/sh
echo "$(basename "$0") $*" >> "$MEOW_COMPLETO_REGISTRO"
exit 1
"""

RESPONDE_SH = """#!/bin/bash
real=""
IFS=: read -ra _dirs <<< "$PATH"
for _d in "${_dirs[@]}"; do
  [ "$_d" = "%(falso)s" ] && continue
  [ -x "$_d/%(nome)s" ] && { real="$_d/%(nome)s"; break; }
done
case " $* " in
  %(leitura)s) [ -n "$real" ] && exec "$real" "$@"; exit 1 ;;
esac
echo "%(nome)s $*" >> "$MEOW_COMPLETO_REGISTRO"
exit 1
"""
GIT_SH = """#!/bin/bash
case " $* " in
  *" clone "*|*" fetch "*|*" pull "*|*" push "*|*" ls-remote "*|*" submodule "*)
    echo "git $*" >> "$MEOW_COMPLETO_REGISTRO"; exit 1 ;;
esac
IFS=: read -ra _dirs <<< "$PATH"
for _d in "${_dirs[@]}"; do
  [ "$_d" = "%(falso)s" ] && continue
  [ -x "$_d/git" ] && exec "$_d/git" "$@"
done
exit 127
"""
LEITURAS = {
    "systemctl": '*" is-active "*|*" is-enabled "*|*" is-failed "*|*" show "*'
                 '|*" status "*|*" cat "*|*" list-units "*|*" list-unit-files "*'
                 '|*" show-environment "*|*" --version "*',
    "gsettings": '" get "*|*" get "*|" list-"*|" range "*|" describe "*|" writable "*',
    "dconf": '" read "*|" list "*|" dump "*',
    "busctl": '*" get-property "*|*" introspect "*|*" FindUserByName "*',
}

FUNCOES_BASH = {
    "_meow_na_casa": r"""() {
  case "$1" in %*) return 0 ;; esac
  grep -qxzF "HOME=$MEOW_COMPLETO_CASA" "/proc/$1/environ" 2>/dev/null
}""",
    "_meow_kill": r"""() {
  local a p rc=0 sinal=() alvos=()
  for a in "$@"; do
    case "$a" in -0|-l|-L) builtin kill "$@"; return ;;
                 -*) sinal+=("$a") ;; *) alvos+=("$a") ;; esac
  done
  for p in "${alvos[@]}"; do
    if _meow_na_casa "$p"; then builtin kill "${sinal[@]}" "$p" || rc=1
    else echo "kill(fora da casa) ${sinal[*]} $p" >> "$MEOW_COMPLETO_REGISTRO"; rc=1; fi
  done
  return "$rc"
}""",
    "kill": '() {  _meow_kill "$@"\n}',
    "pkill": '() {  echo "pkill(função) $*" >> "$MEOW_COMPLETO_REGISTRO"; return 1\n}',
    "killall": '() {  echo "killall(função) $*" >> "$MEOW_COMPLETO_REGISTRO"; return 1\n}',
}


def escrever_exec(caminho, corpo):
    with open(caminho, "w", encoding="utf-8") as fh:
        fh.write(corpo)
    os.chmod(caminho, 0o755)


def montar_casa():
    copiar_raiz()
    os.makedirs(os.path.dirname(CONF))
    os.makedirs(ESTADO)
    shutil.copyfile(os.path.join(RAIZ, "meow.conf.exemplo"), CONF)

    icones = os.path.join(CASA, ".local", "share", "icons")
    ponteiro = os.path.join(icones, valor_de("CURSOR"), "cursors")
    os.makedirs(ponteiro)
    xcursor_liso(os.path.join(ponteiro, "left_ptr"))
    tema = os.path.join(icones, valor_de("NOME_TEMA_ICONES"), "scalable", "apps")
    os.makedirs(tema)
    icones_base = os.path.join(RAIZ, "packs", "meowsystem", "icones")
    with open(os.path.join(icones_base, "arcticons.lista"), encoding="utf-8") as fh:
        lista = [l.strip() for l in fh if l.strip() and not l.startswith("#")]
    for nome in sorted(lista):
        for pasta in ("apps", "biblioteca", "sistema"):
            origem = os.path.join(icones_base, pasta, nome)
            if os.path.isfile(origem):
                shutil.copyfile(origem, os.path.join(tema, nome))
                break
    ativos = os.path.join(valor_de("WALLPAPER_BASE").replace("$HOME", CASA), "ativos")
    os.makedirs(ativos)
    for i in range(PAREDES):
        png_liso(os.path.join(ativos, f"brinquedo-{i:02d}.png"),
                 (0x1E + 8 * i, 0x1E, 0x2E) if i % 2 else (0xEE, 0xEE - 8 * i, 0xE0))

    import ast
    with open(os.path.join(RAIZ, "app", "servidor.py"), encoding="utf-8") as fh:
        arvore = ast.parse(fh.read())
    pendencias = []
    for no in arvore.body:
        if (isinstance(no, ast.Assign)
                and any(getattr(a, "id", "") == "ACAO_DA_PENDENCIA" for a in no.targets)):
            pendencias = sorted(ast.literal_eval(no.value))
    for no in arvore.body:
        if (isinstance(no, ast.Assign)
                and any(getattr(a, "id", "") == "SUFIXO_TEMA_DE_TERCEIRO" for a in no.targets)):
            modulos = os.path.join(RAIZ, "scripts", "temas-de-apps")
            for app in sorted(os.listdir(modulos)):
                try:
                    with open(os.path.join(modulos, app, "manifesto.sh"), encoding="utf-8") as fh:
                        if re.search(r"meow_app_tema_no_ar .* pergunte\b", fh.read()):
                            pendencias.append(app + ast.literal_eval(no.value))
                            break
                except OSError:
                    continue
    with open(os.path.join(ESTADO, "pendencias.tsv"), "w", encoding="utf-8") as fh:
        for ident in pendencias:
            fh.write(f"{ident}\tteste\tPendência plantada pelo teste ({ident})"
                     f"\t./scripts/teste.sh {ident}\t2026-09-24T00:00:00-03:00\n")

    padrao = subprocess.run([sys.executable, os.path.join(RAIZ_B, "scripts", "pack.py"), "padrao"],
                            capture_output=True, text=True).stdout.strip()
    with open(os.path.join(padrao, "pack.json"), encoding="utf-8") as fh:
        historia = (json.load(fh).get("vitrine") or {}).get("descricao")
    if historia:
        with open(os.path.join(padrao, historia), "a", encoding="utf-8") as fh:
            fh.write("\n## Teste da casa de brinquedo\n\n"
                     "Um " + HOSTIL + " no texto, um [link mau](javascript:window.__meow_xss=2)"
                     " e **negrito de brinquedo**.\n")

    steamapps = os.path.join(CASA, ".steam", "steam", "steamapps")
    os.makedirs(os.path.join(steamapps, "common", "JogoDeBrinquedo"))
    with open(os.path.join(steamapps, "common", "JogoDeBrinquedo", "jogo.bin"), "w") as fh:
        fh.write("brinquedo\n")
    with open(os.path.join(steamapps, f"appmanifest_{APPID}.acf"), "w",
              encoding="utf-8") as fh:
        fh.write('"AppState"\n{\n\t"appid"\t\t"%s"\n\t"name"\t\t"Jogo de Brinquedo"\n'
                 '\t"installdir"\t\t"JogoDeBrinquedo"\n}\n' % APPID)
    capa = os.path.join(CASA, ".steam", "steam", "appcache", "librarycache", APPID)
    os.makedirs(capa)
    png_liso(os.path.join(capa, "library_600x900.jpg"), (0x88, 0x44, 0xCC), 60, 90)
    hicolor = os.path.join(icones, "hicolor", "256x256", "apps")
    os.makedirs(hicolor)
    png_liso(os.path.join(hicolor, f"steam_icon_{APPID}.png"), (0x44, 0x88, 0xCC))
    aplicativos = os.path.join(CASA, ".local", "share", "applications")
    os.makedirs(aplicativos)
    with open(os.path.join(aplicativos, f"steam_app_{APPID}.desktop"), "w",
              encoding="utf-8") as fh:
        fh.write("[Desktop Entry]\nName=Jogo de Brinquedo\n"
                 f"Exec=steam steam://rungameid/{APPID}\nIcon=steam_icon_{APPID}\n"
                 "Terminal=false\nType=Application\nCategories=Game;\n")
    with open(os.path.join(aplicativos, "steam.desktop"), "w", encoding="utf-8") as fh:
        fh.write("[Desktop Entry]\nName=Steam\nExec=steam %U\nIcon=steam\n"
                 "Terminal=false\nType=Application\nCategories=Network;FileTransfer;Game;\n"
                 "MimeType=x-scheme-handler/steam;x-scheme-handler/steamlink;\n")
    with open(os.path.join(RAIZ_B, "assets", "apps", "jogos-fora.map"),
              encoding="utf-8") as fh:
        orfas = [l.split(":")[0].strip() for l in fh
                 if l.strip() and not l.lstrip().startswith("#")
                 and l.split(":")[0].strip().isdigit() and l.split(":")[0].strip() != APPID]
    if orfas:
        appinfo_vdf(os.path.join(CASA, ".steam", "steam", "appcache", "appinfo.vdf"),
                    {orfas[0]: NOME_NA_STEAM})
    png_liso(os.path.join(hicolor, "leitor-de-brinquedo.png"), (0xCC, 0x88, 0x44))
    with open(os.path.join(aplicativos, PROGRAMA[0] + ".desktop"), "w",
              encoding="utf-8") as fh:
        fh.write(f"[Desktop Entry]\nName={PROGRAMA[1]}\nExec=true\n"
                 "Icon=leitor-de-brinquedo\nTerminal=false\nType=Application\n")
    with open(CONF, encoding="utf-8") as fh:
        so_com = re.findall(r"\[so-com-app ([^\]\s]+)", fh.read())
    for ident in so_com:
        with open(os.path.join(aplicativos, ident + ".desktop"), "w", encoding="utf-8") as fh:
            fh.write("[Desktop Entry]\nName=Programa de Brinquedo\nExec=true\n"
                     "Terminal=false\nType=Application\n")

    areas = os.path.join(CASA, ".config", "cosmic", "com.system76.CosmicComp", "v1")
    os.makedirs(areas)
    with open(os.path.join(areas, "pinned_workspaces"), "w", encoding="utf-8") as fh:
        fh.write("[\n" + "".join(
            '    (\n        output: (\n            name: "DP-1",\n'
            '            edid: None,\n        ),\n        tiling_enabled: false,\n'
            '        id: Some("%s"),\n        name: Some("%s"),\n    ),\n' % area
            for area in (("c0ffee", "Brinquedo"), ("decafe", "Quintal"))) + "]\n")

    with open(CONF, encoding="utf-8") as fh:
        texto = fh.read()
    with open(CONF, "w", encoding="utf-8") as fh:
        fh.write(re.sub(r'^FASTFETCH_TITULO="[^"]*"', 'FASTFETCH_TITULO="Casa de brinquedo"',
                        texto, count=1, flags=re.M))

    os.makedirs(FALSO)
    open(REGISTRO, "w").close()
    for nome in ("sudo", "pkexec", "pkill", "killall", "notify-send",
                 "systemd-run", "xdg-open", "curl", "wget", "cargo"):
        escrever_exec(os.path.join(FALSO, nome), RECUSA_SH)
    escrever_exec(os.path.join(FALSO, "git"), GIT_SH % {"falso": FALSO})
    for nome, leitura in LEITURAS.items():
        escrever_exec(os.path.join(FALSO, nome),
                      RESPONDE_SH % {"falso": FALSO, "nome": nome, "leitura": leitura})
    escrever_exec(os.path.join(FALSO, "kill"),
                  "#!/bin/bash\n"
                  + "".join(f"{n} {FUNCOES_BASH[n]}\n" for n in ("_meow_na_casa", "_meow_kill"))
                  + '_meow_kill "$@"\n')

    ambiente = {
        "PATH": FALSO + os.pathsep + os.environ.get("PATH", ""),
        "HOME": CASA, "USER": os.environ.get("USER", "meow"),
        "LANG": os.environ.get("LANG", "C.UTF-8"),
        "MEOW_CONF": CONF, "MEOW_ESTADO": ESTADO,
        "MEOW_PONTE": os.path.join(BRINQUEDO, "sem-ponte"),
        "MEOW_COMPLETO_REGISTRO": REGISTRO, "MEOW_COMPLETO_CASA": CASA,
    }
    for nome, corpo in FUNCOES_BASH.items():
        ambiente[f"BASH_FUNC_{nome}%%"] = corpo
    return ambiente


def encerrar_a_casa():
    import signal
    marca = ("MEOW_COMPLETO_CASA=" + CASA).encode()
    for tentativa in (signal.SIGTERM, signal.SIGKILL):
        vivos = []
        for pid in filter(str.isdigit, os.listdir("/proc")):
            if int(pid) == os.getpid():
                continue
            try:
                with open(f"/proc/{pid}/environ", "rb") as fh:
                    if marca in fh.read().split(bytes(1)):
                        os.kill(int(pid), tentativa)
                        vivos.append(pid)
            except OSError:
                continue
        if not vivos:
            return
        time.sleep(1)


def registro():
    with open(REGISTRO, encoding="utf-8") as fh:
        return [l.rstrip("\n") for l in fh if l.strip()]


def sobe_servidor(ambiente):
    proc = subprocess.Popen(
        [os.path.join(RAIZ_B, "app", "run.sh"), "--sem-abrir"],
        cwd=RAIZ_B, env=ambiente,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    url = None
    inicio = time.time()
    while time.time() - inicio < 40:
        linha = proc.stdout.readline()
        if not linha:
            break
        m = re.search(r"http://127\.0\.0\.1:\d+/\?t=[A-Za-z0-9_-]+", linha)
        if m:
            url = m.group(0)
            break
    return proc, url

FORA_DO_RETRATO = re.compile(
    r"^(raiz/\.git/|casa/\.cache/|casa/\.local/state/meowsystem/(meow\.log|ultimo-|lock$))"
    r"|.*/__pycache__/")


def retrato():
    fotos = {}
    for base in (CASA, RAIZ_B):
        for pasta, _, arquivos in os.walk(base):
            for nome in arquivos:
                cam = os.path.join(pasta, nome)
                rel = os.path.relpath(cam, BRINQUEDO)
                if FORA_DO_RETRATO.match(rel):
                    continue
                try:
                    st = os.lstat(cam)
                except OSError:
                    continue
                fotos[rel] = (st.st_size, st.st_mtime_ns)
    return fotos


def diferenca(antes, depois):
    mudou = [c for c in depois if antes.get(c) != depois[c]]
    sumiu = [c for c in antes if c not in depois]
    return sorted(mudou + sumiu)



import fnmatch  # noqa: E402

PEDIDOS_DE_FORA = []

CENSO_JS = r"""
() => {
  const SEL = 'button, a[href], input, select, textarea, summary, [role=button], [role=switch],'
            + ' [tabindex]:not([tabindex="-1"])';
  const aberto = [...document.querySelectorAll('dialog')].find((d) => d.open && d.matches(':modal'));
  const visivel = (el) => {
    if (el.type === 'file' || el.type === 'hidden') return false;
    const r = el.getBoundingClientRect();
    if (r.width === 0 && r.height === 0) return false;
    if (r.right <= 0 || r.left >= innerWidth) return false;
    if (el.checkVisibility && !el.checkVisibility({ visibilityProperty: true })) return false;
    const cs = getComputedStyle(el);
    return cs.display !== 'none' && cs.visibility !== 'hidden';
  };
  const itens = [];
  for (const el of document.querySelectorAll(SEL)) {
    if (!visivel(el)) continue;
    if (aberto && !aberto.contains(el)) continue;
    const zona = el.closest('dialog') ? 'dialogo' : el.closest('#topo') ? 'topo' : 'pagina';
    itens.push({
      nome: el.dataset.controle || null, tag: el.tagName.toLowerCase(), papel: el.getAttribute('role') || '',
      tipo: (el.getAttribute('type') || '').toLowerCase(), zona,
      desabilitado: !!(el.disabled || el.getAttribute('aria-disabled') === 'true'),
      pressionado: el.getAttribute('aria-pressed') || el.getAttribute('aria-checked') || '',
      dica: el.dataset.dica || '',
      texto: (el.getAttribute('aria-label') || el.textContent || el.value || '').replace(/\s+/g, ' ').trim().slice(0, 60),
      html: el.outerHTML.slice(0, 160),
    });
  }
  return itens;
}
"""

ESTADO_JS = r"""
() => JSON.stringify({
  hash: location.hash,
  n: (document.getElementById('aplicar') || { dataset: {} }).dataset.n,
  conteudo: (document.getElementById('conteudo') || {}).innerHTML || '',
  topo: (document.getElementById('topo') || {}).innerHTML || '',
  dialogos: [...document.querySelectorAll('dialog')].map((d) => d.open),
  torradas: (document.getElementById('torradas') || {}).innerHTML || '',
})
"""

ASSENTAR_JS = r"""
([quieto, teto]) => new Promise((pronto) => {
  let t = null;
  const fim = () => { obs.disconnect(); clearTimeout(t); clearTimeout(limite); pronto(); };
  const obs = new MutationObserver(() => { clearTimeout(t); t = setTimeout(fim, quieto); });
  obs.observe(document.body, { subtree: true, childList: true, attributes: true, characterData: true });
  t = setTimeout(fim, quieto);
  const limite = setTimeout(fim, teto);
})
"""

TEXTO_RUIM_JS = r"""
() => {
  const ruins = [];
  const anda = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  while (anda.nextNode()) {
    const no = anda.currentNode, pai = no.parentElement;
    if (!pai || pai.closest('script, style, pre')) continue;
    if (pai.checkVisibility && !pai.checkVisibility({ visibilityProperty: true })) continue;
    const t = no.textContent;
    if (/\bundefined\b|\bNaN\b|\[object |\bnull\b|\$\{/.test(t)) ruins.push(t.trim().slice(0, 80));
  }
  const senha = document.querySelectorAll('input[type=password]').length;
  return { ruins, senha };
}
"""

def molde(nome):
    n = re.sub(r"=.*$", "=*", nome)
    n = re.sub(r"^pack:[^:]+:", "pack:*:", n)
    n = re.sub(r"^(programa|pendente|estado):.*$", r"\1:*", n)
    return n


CONTROLE_DA_CHAVE = {"PACK": "pack:", "FLAVOR": "pack:", "APPS_ATIVOS": "programa:"}
CONTROLE_DA_ACAO = {"pack_usar": "pack:", "pack_remover": "pack:"}
ACAO_COM_DADO = {
    "wallpaper_permitir", "wallpaper_dispensar", "apps_tema_do_pack", "apps_manter_o_meu",
    "vscode_instalar_extensao", "files_menu_build", "wallpaper_usar", "wallpaper_favoritar", "wallpaper_desfavoritar",
    "wallpaper_dia", "wallpaper_noite", "wallpaper_lado_auto", "wallpaper_banir", "wallpaper_desbanir",
}
EXTRAS = {
    "tema": ["tema:saude", "tema:abrir", "tema:criar", "pack:*:*", "chave:ACCENT=*", "chave:MODO=*"],
    "criar/*": ["criar:nome", "passo:*", "criar:voltar", "criar:proximo"],
    "criar/cores": ["criar:comeca=*", "criar:cor=*", "criar:guardar"],
    "criar/icones": ["apps:filtro", "app", "icone:*", "oficina:*", "desenho:*", "autoral:*", "acervo:icone",
                     "acervo:filtro", "icones:aba=*"],
    "criar/papel": ["galeria:*", "papel:*", "acervo:parede", "levar:foto"],
    "criar/sons": ["criar:sino", "som:ouvir", "som:trocar", "som:ponte"],
    "criar/mandar": ["criar:baixar", "criar:vestir"],
    "ajustes/*": ["ajuste:*"],
    "ajustes/dia-e-noite": ["noite:mesmo-horario"],
    "ajustes/programas": ["programa:*", "jogo:*", "icone:*", "oficina:*", "desenho:*"],
    "cuidar": ["estado:*", "cuidar:exportar", "cuidar:importar", "pendencia:*"],
}
GLOBAIS = ["marca", "porta:*", "busca", "achado", "pendentes", "pendente:*", "desfazer", "ensaiar",
           "aplicar", "menu", "menu:*", "trabalho", "resultado:*", "pergunta:*", "exportar:imagens",
           "padrao:*", "automatico:*", "restaurar:*", "ficha:*"]
NO_FIM = ["marca", "porta:*", "ajuste:*", "passo:*", "busca", "achado", "pendentes", "pendente:*",
          "desfazer", "ensaiar", "aplicar", "menu", "menu:*", "trabalho", "resultado:*", "pergunta:*",
          "exportar:imagens", "criar:voltar", "criar:proximo"]
OBRIGATORIOS = ["marca", "porta:tema", "porta:criar", "porta:ajustes", "porta:cuidar", "busca", "achado",
                "pendentes", "pendente:*", "desfazer", "ensaiar", "aplicar", "menu", "menu:creditos",
                "menu:pagina", "trabalho", "resultado:ok", "resultado:guardar", "resultado:parar",
                "resultado:registro", "resultado:de-verdade", "pergunta:nao", "pergunta:sim",
                "pergunta:ensaio", "criar:voltar", "criar:proximo"]

ROTAS = ["tema", "criar/cores", "criar/icones", "criar/papel", "criar/sons", "criar/mandar",
         "ajustes/painel", "ajustes/janelas", "ajustes/papel", "ajustes/mascote", "ajustes/dia-e-noite",
         "ajustes/terminal", "ajustes/programas", "cuidar"]
ACERVO = {"gato": "Adicionar logo", "icone": "Adicionar ícone", "parede": "Adicionar imagem",
          "cursor": "Adicionar tema", "fonte": "Adicionar fonte", "tema-icones": "Adicionar tema de ícones"}


def css_attr(valor):
    return valor.replace("\\", "\\\\").replace('"', '\\"')


class Percurso:

    def __init__(self, pag):
        self.pag = pag
        self.rota = "(abrindo)"
        self.falhas = []
        self.conferidas = 0
        self.acionados = set()
        self.vistos = set()
        self.posts = []
        self.esperadas = []
        self.pedidos_vivos = 0
        self.tempos = {}
        pag.on("request", self._pedido)
        pag.on("requestfinished", self._fim_pedido)
        pag.on("requestfailed", self._pedido_falhou)
        pag.on("response", self._resposta)
        pag.on("console", self._console)
        pag.on("pageerror", lambda e: self.falha(f"erro de JavaScript: {e}"))

    def falha(self, frase):
        self.falhas.append((self.rota, frase))
        print(f"  XX [{self.rota}] {frase}")
        if FOTOS:
            try:
                os.makedirs(os.path.join(FOTOS, "falhas"), exist_ok=True)
                self.pag.screenshot(path=os.path.join(FOTOS, "falhas", "%02d-%s.png" % (len(self.falhas), self.rota.replace("/", "-"))))
            except Exception:  # noqa: BLE001
                pass

    def checa(self, cond, frase):
        self.conferidas += 1
        if not cond:
            self.falha(frase)
        return bool(cond)

    @staticmethod
    def _conta(req):
        return (req.url.startswith("http://127.0.0.1") and "/api/pulso" not in req.url
                and not re.search(r"/(previa|pack-vitrine|gato\.svg|logo\.svg)\b", req.url))

    def _pedido(self, req):
        if not self._conta(req):
            return
        self.pedidos_vivos += 1
        if req.method == "POST":
            try:
                corpo = json.loads(req.post_data or "{}")
            except ValueError:
                corpo = {}
            self.posts.append((req.url.split("?")[0].rsplit("/", 1)[-1], corpo))

    def _fim_pedido(self, req):
        if self._conta(req):
            self.pedidos_vivos = max(0, self.pedidos_vivos - 1)

    def _pedido_falhou(self, req):
        if self._conta(req):
            self.pedidos_vivos = max(0, self.pedidos_vivos - 1)
            if "ERR_ABORTED" not in (req.failure or ""):
                self.falha(f"pedido falhou na rede: {req.url[:90]} ({req.failure})")

    def esperar_status(self, status, trecho):
        self.esperadas.append((status, trecho))

    def _resposta(self, resp):
        if resp.status < 400 or not resp.url.startswith("http://127.0.0.1"):
            return
        for i, (st, trecho) in enumerate(self.esperadas):
            if st == resp.status and trecho in resp.url:
                del self.esperadas[i]
                return
        self.falha(f"resposta {resp.status} que ninguém pediu: {resp.url.split('?')[0][-60:]}")

    def _console(self, msg):
        if msg.type != "error" or "Failed to load resource" in msg.text:
            return
        self.falha(f"erro no console: {msg.text[:160]}")

    def js(self, codigo, arg=None):
        return self.pag.evaluate(codigo, arg)

    def assentar(self, quieto=250, teto=8000):
        fim = time.time() + teto / 1000
        while self.pedidos_vivos and time.time() < fim:
            self.pag.wait_for_timeout(40)
        self.pag.evaluate(ASSENTAR_JS, [quieto, max(300, int((fim - time.time()) * 1000))])
        while self.pedidos_vivos and time.time() < fim:
            self.pag.wait_for_timeout(40)

    def estado(self):
        return self.js(ESTADO_JS)

    def censo(self):
        itens = self.js(CENSO_JS)
        for it in itens:
            if it["nome"]:
                self.vistos.add(molde(it["nome"]))
        return itens

    def achar(self, nome, so_livre=False):
        loc = self.pag.locator(f'[data-controle="{css_attr(nome)}"]')
        for i in range(loc.count()):
            el = loc.nth(i)
            try:
                if el.is_visible() and (not so_livre or el.get_attribute("aria-pressed") != "true"):
                    return el
            except Exception:
                continue
        return None

    def esperar_nome(self, nome, teto=8.0):
        fim = time.time() + teto
        while True:
            el = self.achar(nome)
            if el is not None or time.time() > fim:
                return el
            self.pag.wait_for_timeout(150)

    def clicar(self, nome, so_livre=False):
        for _vez in range(4):
            el = self.esperar_nome(nome, teto=4.0)
            if so_livre:
                el = self.achar(nome, so_livre=True) or el
            if el is None:
                break
            try:
                el.click(timeout=5000)
                self.acionados.add(molde(nome))
                return True
            except Exception:
                self.pag.wait_for_timeout(200)
                if not nome.startswith(("resultado:", "pergunta:")) and self.aberto("resultado"):
                    self.limpar()
                if nome in ("desfazer",) and self.achar(nome) is None:
                    self.acionados.add(molde(nome))
                    return True
        estado = self.js("() => ({ n: document.getElementById('aplicar').dataset.n, mudancas: MUDANCAS.size,"
                         " caixas: [...document.querySelectorAll('dialog')].filter((d) => d.open).map((d) => d.id) })")
        self.falha(f"não consegui clicar em «{nome}» ({estado})")
        return False

    def aberto(self, ident):
        return bool(self.js(f"() => document.getElementById('{ident}').open"))

    def ir(self, rota):
        porta, _, sub = rota.partition("/")
        self.clicar("porta:" + porta)
        self.assentar()
        if sub:
            self.clicar(("ajuste:" if porta == "ajustes" else "passo:") + sub)
            self.assentar()
        self.checa(self.js("() => location.hash") == "#" + rota, f"o clique leva a #{rota}")

    def esperar_trabalho(self, teto=240, parar=False):
        fim = time.time() + teto
        parou = False
        while time.time() < fim:
            correndo = self.js("() => document.getElementById('resultado-estado').dataset.estado === 'correndo'"
                               " && !document.getElementById('parar').hidden")
            if not correndo:
                break
            if parar and not parou and self.achar("resultado:parar"):
                self.clicar("resultado:parar")
                parou = True
            self.pag.wait_for_timeout(300)
        else:
            if self.achar("resultado:parar"):
                self.clicar("resultado:parar")
                self.pag.wait_for_timeout(2000)
            self.falha("o trabalho passou do teto de %ds" % teto)
        estado = self.js("() => document.getElementById('resultado-estado').textContent")
        self.checa(estado and estado[0].isupper(), f"a janela diz o fim com maiúscula ({estado!r})")
        return estado

    def fechar_resultado(self):
        for _vez in range(4):
            if not self.aberto("resultado"):
                break
            el = self.esperar_nome("resultado:ok", teto=4.0)
            try:
                if el is not None:
                    el.click(timeout=5000)
                    self.acionados.add(molde("resultado:ok"))
            except Exception:
                self.pag.wait_for_timeout(300)
        else:
            if self.aberto("resultado"):
                self.falha("o «OK» não fecha a janela do trabalho")
        self.assentar()

    def fechar_pergunta(self):
        if self.aberto("pergunta"):
            self.clicar("pergunta:nao")
            self.assentar()

    def limpar(self):
        for _vez in range(3):
            if self.aberto("pergunta"):
                self.fechar_pergunta()
            if self.aberto("resultado"):
                longo = self.js("() => !!TRABALHO && TRABALHO.acao === 'instalar'")
                self.esperar_trabalho(parar=longo)
                self.fechar_resultado()
            if not self.js("() => !!TRABALHO && !!TRABALHO.timer"):
                break
            self.pag.wait_for_timeout(500)

    def depois_do_gesto(self, nome):
        self.assentar(quieto=300)
        if self.aberto("pergunta"):
            titulo = self.js("() => document.getElementById('pergunta-titulo').textContent")
            self.checa(titulo[:1].isupper(), f"a pergunta de «{nome}» começa com maiúscula ({titulo!r})")
            self.checa(self.js(TEXTO_RUIM_JS)["senha"] == 0, f"a pergunta de «{nome}» não tem campo de senha")
            if titulo == "Falta a ponte":
                self.fechar_pergunta()
                return "ponte"
            if self.achar("pergunta:ensaio"):
                self.clicar("pergunta:ensaio")
                self.assentar()
                if self.checa(self.aberto("resultado"), f"o «Ver sem mudar» de «{nome}» abre a janela"):
                    self.checa(self.js("() => !document.getElementById('faixa-ensaio').hidden"),
                               f"a janela do ensaio de «{nome}» diz que é ensaio")
                    self.esperar_trabalho()
                    self.fechar_resultado()
                return "ensaio"
            self.clicar("pergunta:sim")
            self.assentar()
        if self.aberto("resultado"):
            longo = self.js("() => !!TRABALHO && TRABALHO.acao === 'instalar'")
            self.esperar_trabalho(parar=longo)
            self.fechar_resultado()
            return "trabalho"
        return ""

    def arquivo_de_teste(self, tipo):
        import zipfile
        pasta = os.path.join(BRINQUEDO, "envios")
        os.makedirs(pasta, exist_ok=True)
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
               '<circle cx="24" cy="24" r="18" fill="none" stroke="#cba6f7" stroke-width="3"/></svg>')
        if tipo in ("gato", "icone"):
            nome = os.path.join(pasta, "brinquedo-desenho-%s.svg" % tipo)
            with open(nome, "w", encoding="utf-8") as fh:
                fh.write(svg)
            return nome
        if tipo == "parede":
            nome = os.path.join(pasta, "brinquedo-nova.png")
            png_liso(nome, (0xF5, 0xC2, 0xE7))
            return nome
        if tipo == "cursor":
            nome = os.path.join(pasta, "brinquedo-ponteiro.zip")
            cur = os.path.join(pasta, "left_ptr")
            xcursor_liso(cur)
            with zipfile.ZipFile(nome, "w") as z:
                z.write(cur, "Brinquedo-Ponteiro/cursors/left_ptr")
                z.writestr("Brinquedo-Ponteiro/index.theme", "[Icon Theme]\nName=Brinquedo-Ponteiro\n")
            return nome
        if tipo == "tema-icones":
            nome = os.path.join(pasta, "brinquedo-icones.zip")
            with zipfile.ZipFile(nome, "w") as z:
                z.writestr("Brinquedo-Icones/index.theme",
                           "[Icon Theme]\nName=Brinquedo-Icones\nDirectories=scalable/apps\n\n"
                           "[scalable/apps]\nSize=48\nType=Scalable\n")
                z.writestr("Brinquedo-Icones/scalable/apps/brinquedo.svg", svg)
            return nome
        if tipo == "fonte":
            achada = subprocess.run(["fc-match", "-f", "%{file}", "sans:fontformat=TrueType"],
                                    capture_output=True, text=True).stdout.strip()
            if not achada.endswith(".ttf"):
                return None
            nome = os.path.join(pasta, "brinquedo-fonte.ttf")
            shutil.copyfile(achada, nome)
            return nome
        return None

    def escolher_arquivo(self, nome, caminho):
        for vez in range(3):
            try:
                with self.pag.expect_file_chooser(timeout=15000) as escolha:
                    self.clicar(nome)
                escolha.value.set_files(caminho)
                return
            except Exception:
                if vez == 2:
                    raise
                self.assentar(quieto=500)

    def h_acervo(self, nome):
        tipo = nome.split(":", 1)[1]
        arquivo = self.arquivo_de_teste(tipo)
        if not self.checa(arquivo, f"há um arquivo de teste para «{ACERVO.get(tipo, tipo)}»"):
            return
        antes, n0 = retrato(), len(self.posts)
        self.escolher_arquivo(nome, arquivo)
        fim = time.time() + 120
        while len(self.posts) == n0 and time.time() < fim:
            self.pag.wait_for_timeout(100)
        self.assentar(quieto=400, teto=120000)
        erro = self.pag.locator("#torradas .torrada.erro")
        self.checa(not erro.count(), f"o acervo «{tipo}» aceita {os.path.basename(arquivo)}"
                   + (f" — disse {erro.first.inner_text()[:100]!r}" if erro.count() else ""))
        self.checa(diferenca(antes, retrato()), f"o acervo «{tipo}» escreveu na casa de brinquedo")

    def h_download(self, nome):
        with self.pag.expect_download(timeout=60000) as baixa:
            self.clicar(nome)
            self.pag.wait_for_timeout(300)
            if self.aberto("pergunta"):
                if self.achar("exportar:imagens"):
                    self.clicar("exportar:imagens")
                self.clicar("pergunta:sim")
        caminho = baixa.value.path()
        self.checa(os.path.getsize(caminho) > 100,
                   f"«{nome}» baixa {baixa.value.suggested_filename} ({os.path.getsize(caminho)} bytes)")
        if nome == "criar:baixar":
            with open(caminho, "rb") as fh:
                self.checa(fh.read(4) == bytes([0x28, 0xB5, 0x2F, 0xFD]), "o tema baixado é um .meowpack (zstd)")

    def h_abrir_tema(self, nome):
        ordem = self.js("() => ESQUEMA.paleta.ordem")
        cores = self.js("() => ESQUEMA.paleta.flavors[flavorEmVigor()]")
        caminho = os.path.join(BRINQUEDO, "envios", "cores-de-brinquedo.csv")
        os.makedirs(os.path.dirname(caminho), exist_ok=True)
        with open(caminho, "w", encoding="utf-8") as fh:
            fh.write("slot,flavor,hex\n" + "".join(f"{n},brinquedo,{cores[n]}\n" for n in ordem))
        self.escolher_arquivo(nome, caminho)
        self.assentar(quieto=400, teto=60000)
        if self.checa(self.aberto("pergunta"), "abrir um .csv pergunta antes de instalar"):
            self.clicar("pergunta:sim")
            self.assentar(quieto=400, teto=60000)
        self.checa(self.pag.locator('article.pack[data-pack="cores-de-brinquedo"]').count() == 1,
                   "o tema aberto aparece entre os temas")

    def h_importar_conf(self, nome):
        caminho = os.path.join(BRINQUEDO, "envios", "meus-ajustes.conf")
        os.makedirs(os.path.dirname(caminho), exist_ok=True)
        atual = valor_de("RELOGIO_SEGUNDOS") or "nao"
        with open(caminho, "w", encoding="utf-8") as fh:
            fh.write('RELOGIO_SEGUNDOS="%s"\n' % ("sim" if atual != "sim" else "nao"))
        n0 = self.js("() => MUDANCAS.size")
        self.escolher_arquivo(nome, caminho)
        self.assentar(quieto=400)
        self.checa(self.js("() => MUDANCAS.size") == n0 + 1, "trazer ajustes vira uma mudança esperando o Aplicar")

    def h_guardar(self, nome):
        if self.achar(nome) and self.achar(nome).get_attribute("aria-disabled") == "true":
            self.checa(self.achar(nome).get_attribute("data-dica"), "«Guardar» apagado diz o porquê")
            primeiro = self.js("() => document.querySelector('[data-controle^=\"criar:comeca=\"]').dataset.controle")
            self.clicar(primeiro)
            self.assentar()
        if self.achar("criar:comeca=dracula:dracula"):
            self.clicar("criar:comeca=dracula:dracula")
            self.assentar()
        campo = self.achar("criar:nome")
        campo.fill("Tema de Brinquedo")
        campo.press("Tab")
        self.assentar()
        self.clicar(nome)
        self.assentar(quieto=400, teto=60000)
        pasta = os.path.join(CASA, ".local", "share", "meowsystem", "packs", "tema-de-brinquedo")
        self.checa(os.path.isfile(os.path.join(pasta, "pack.json"))
                   and os.path.isfile(os.path.join(pasta, "paleta.json")),
                   "«Guardar» grava o pack em ~/.local/share/meowsystem/packs/tema-de-brinquedo")
        icones = os.path.join(pasta, "icones")
        dirs = sorted(os.listdir(icones)) if os.path.isdir(icones) else []
        self.checa(dirs == ["apps", "biblioteca", "sistema"], f"o pack tem as três pastas planas de ícone ({dirs})")
        self.checa(os.path.isfile(os.path.join(pasta, "sons", "index.theme")),
                   "«Guardar» leva para o pack os sons do tema de partida")
        ok = subprocess.run([sys.executable, os.path.join(RAIZ_B, "scripts", "pack.py"), "validar", "tema-de-brinquedo"],
                            capture_output=True, text=True,
                            env=dict(os.environ, HOME=CASA, MEOW_RAIZ=RAIZ_B))
        self.checa(ok.returncode == 0 and "formato 2" in ok.stdout + ok.stderr,
                   "e o pack guardado valida no formato de três pastas: " + (ok.stdout + ok.stderr).strip()[-160:])

    def h_abas_de_icones(self):
        for aba in ("sistema", "biblioteca"):
            if not self.achar("icones:aba=" + aba):
                continue
            self.clicar("icones:aba=" + aba)
            self.acionados.add("icones:aba=*")
            self.assentar(quieto=400)
            seletor = f".grade-apps.pastas[data-acervo='{aba}'] .app"
            n = self.js(f"() => document.querySelectorAll(\"{seletor}\").length")
            self.checa(n > 0, f"a aba {aba} mostra os ícones do pack em edição ({n})")
            self.checa(not self.achar("levar:" + aba), f"a aba {aba} só mostra: não tem botão de levar")
            if self.achar("acervo:filtro"):
                self.acionados.add("acervo:filtro")
        self.clicar("icones:aba=apps")
        self.assentar()

    def h_trocar_som(self, nome):
        caminho = os.path.join(BRINQUEDO, "envios", "brinquedo-aviso.oga")
        os.makedirs(os.path.dirname(caminho), exist_ok=True)
        with open(caminho, "wb") as fh:
            fh.write("OggS".encode() + bytes(64))
        evento = self.js("() => document.querySelector('[data-controle=\"som:trocar\"]').closest('li').dataset.som")
        self.escolher_arquivo(nome, caminho)
        self.assentar(quieto=400, teto=30000)
        alvo = os.path.join(CASA, ".local", "share", "meowsystem", "packs", "tema-de-brinquedo", "sons", "stereo")
        trocado = any(os.path.isfile(os.path.join(alvo, c, evento + ".oga"))
                      and open(os.path.join(alvo, c, evento + ".oga"), "rb").read() == open(caminho, "rb").read()
                      for c in ("action", "alert", "notification"))
        self.checa(trocado, f"«Trocar» põe o som escolhido no lugar de «{evento}» no pack")

    def h_link_externo(self, nome):
        nova = None
        href = rel = ""
        n0 = len(PEDIDOS_DE_FORA)
        for _tentativa in range(4):
            el = self.esperar_nome(nome, teto=4.0)
            if el is None:
                break
            try:
                href = el.get_attribute("href", timeout=2500) or ""
                rel = el.get_attribute("rel", timeout=2500) or ""
                with self.pag.context.expect_page(timeout=5000) as aberta:
                    el.click(timeout=2500)
                nova = aberta
                self.acionados.add(molde(nome))
                break
            except Exception:
                self.pag.wait_for_timeout(200)
        if nova is None:
            self.falha(f"não consegui clicar em «{nome}»")
            return
        self.checa(href.startswith("https://"), f"o link externo vai para https ({href[:50]})")
        self.checa("noopener" in rel, "e abre sem dar a esta página à outra (rel=noopener)")
        nova.value.wait_for_timeout(300)
        pedidos = PEDIDOS_DE_FORA[n0:]
        self.checa(any(u.rstrip("/") == href.rstrip("/") for u in pedidos),
                   f"o clique abre {href[:50]} numa aba nova (pediu {pedidos[:2]})")
        nova.value.close()

    def h_campo(self, nome, item):
        el = self.achar(nome)
        tipo = item["tipo"]
        antes = self.estado()
        if item["tag"] == "select":
            opcoes = el.evaluate("(s) => [...s.options].map((o) => o.value)")
            atual = el.evaluate("(s) => s.value")
            outra = next((o for o in opcoes if o != atual), None)
            if outra is None:
                self.checa(len(opcoes) >= 1, f"o seletor «{nome}» tem opção")
                return
            el.select_option(outra)
        elif tipo == "range":
            el.evaluate("(r) => { const lo = Number(r.min), hi = Number(r.max);"
                        " r.value = String(lo + (hi - lo) / 2 + (Number(r.value) === lo + (hi - lo) / 2 ? Number(r.step || 1) : 0));"
                        " r.dispatchEvent(new Event('input', { bubbles: true })); r.dispatchEvent(new Event('change', { bubbles: true })); }")
        elif tipo == "color":
            el.evaluate("(c) => { c.value = '#3a5f8c'; c.dispatchEvent(new Event('change', { bubbles: true })); }")
        elif tipo == "checkbox":
            el.click()
        elif tipo == "time":
            el.fill("21:00")
            el.dispatch_event("change")
        elif tipo == "number":
            el.fill("17")
            el.dispatch_event("change")
        elif nome.endswith(":nova"):
            el.fill("brinquedo-ficha")
            el.press("Enter")
        elif nome == "criar:nome":
            el.fill("Nome de Brinquedo")
            el.press("Tab")
        elif nome in ("apps:filtro", "icone:busca"):
            el.fill("a")
            el.dispatch_event("change")
        elif nome == "chave:AREAS_NOMES:area":
            el.fill((el.input_value() or "Area") + "x")
            el.dispatch_event("change")
        else:
            el.fill("Brinquedo")
            el.dispatch_event("change")
        self.acionados.add(molde(nome))
        self.depois_do_gesto(nome)
        self.checa(self.estado() != antes or self.posts, f"mexer em «{nome}» muda a tela")

    def h_clique(self, nome, item):
        antes, n0 = self.estado(), len(self.posts)
        if not self.clicar(nome, so_livre="=" in nome):
            return
        como = self.depois_do_gesto(nome)
        self.checa(como or self.estado() != antes or len(self.posts) > n0, f"o clique em «{nome}» tem efeito")

    def h_acao(self, nome, item):
        if item["desabilitado"]:
            self.checa(bool(item["dica"]) and item["dica"][0].isupper(),
                       f"a ação apagada «{nome}» diz o porquê na dica, com maiúscula ({item['dica']!r})")
            self.acionados.add(molde(nome))
            return
        acao = self.js("(id) => { const a = ACAO.get(id); return a && { sudo: !!(a.sudo || a.pela_ponte),"
                       " confirma: !!a.confirma, escreve: !!a.escreve }; }", nome.split(":", 1)[1].split(":")[0])
        n0 = len(self.posts)
        antes = self.estado()
        if not self.clicar(nome):
            return
        como = self.depois_do_gesto(nome)
        ponte = self.js("() => ESQUEMA.ponte")
        if acao and acao["sudo"] and not ponte:
            self.checa(como == "ponte", f"«{nome}» é de root e, sem a ponte, mostra «Falta a ponte» ({como!r})")
        elif acao and acao["confirma"]:
            self.checa(como in ("ensaio", "trabalho"), f"«{nome}» pergunta e roda ({como!r})")
        else:
            self.checa(como == "trabalho" or len(self.posts) > n0 or self.estado() != antes,
                       f"«{nome}» roda ({como!r})")

    def acionar(self, nome, item):
        m = molde(nome)
        if item["desabilitado"] and not nome.startswith("acao:") and nome != "criar:guardar":
            self.checa(bool(item["dica"]) and item["dica"][0].isupper(),
                       f"o controle apagado «{nome}» diz o porquê na dica ({item['dica']!r})")
            self.acionados.add(m)
            return
        if nome == "som:trocar":
            return self.h_trocar_som(nome)
        if nome.startswith("icones:aba="):
            return self.h_abas_de_icones()
        if nome == "som:ponte":
            self.clicar(nome)
            como = self.depois_do_gesto(nome)
            self.checa(como == "ponte", f"«Consertar a ponte» abre a pergunta da ponte ({como!r})")
            return
        if nome in ("criar:sino", "som:ouvir"):
            n0 = len(self.falhas)
            self.clicar(nome)
            self.pag.wait_for_timeout(400)
            self.checa(len(self.falhas) == n0, "o sino toca sem erro")
            return
        if nome.startswith("acervo:"):
            return self.h_acervo(nome)
        if nome == "tema:abrir":
            return self.h_abrir_tema(nome)
        if nome == "cuidar:importar":
            return self.h_importar_conf(nome)
        if nome in ("cuidar:exportar", "criar:baixar"):
            return self.h_download(nome)
        if nome == "criar:guardar":
            return self.h_guardar(nome)
        if nome.startswith("acao:") and item["tag"] == "button":
            return self.h_acao(nome, item)
        if item["tag"] in ("input", "select", "textarea"):
            return self.h_campo(nome, item)
        if item["tag"] == "summary":
            antes = self.js(f"() => document.querySelector('[data-controle=\"{css_attr(nome)}\"]').parentElement.open")
            self.clicar(nome)
            self.assentar()
            self.checa(self.js(f"() => document.querySelector('[data-controle=\"{css_attr(nome)}\"]').parentElement.open") != antes,
                       f"«{nome}» abre e fecha")
            return
        if item["tag"] == "a" and "#" in (item["html"].split('href="', 1)[-1][:2] or ""):
            antes = self.js("() => location.hash")
            self.clicar(nome)
            self.assentar()
            self.checa(self.js("() => location.hash") != antes or m in ("tema:saude",),
                       f"o link «{nome}» leva a outra página")
            return
        if item["desabilitado"]:
            self.checa(bool(item["dica"]), f"o controle apagado «{nome}» diz o porquê na dica")
            self.acionados.add(m)
            return
        return self.h_clique(nome, item)

    def esperado(self, rota):
        porta, _, sub = rota.partition("/")
        lista = self.js("""([porta, sub]) => {
          const nome = porta === 'ajustes' ? (AJUSTES.find((p) => p.id === sub) || {}).nome
                     : porta === 'criar' ? (PASSOS.find((p) => p.id === sub) || {}).nome : null;
          return inventarioDoPainel().filter((l) => l.porta === porta && (!nome || l.pagina === nome))
            .map((l) => ({ tipo: l.tipo, id: l.id,
              existe: l.tipo === 'chave' ? CHAVE.has(l.id) && !CHAVE.get(l.id).sem_programa
                    : l.tipo === 'acao' ? ACAO.has(l.id) : true }));
        }""", [porta, sub])
        saida = []
        for l in lista:
            if not l["existe"]:
                continue
            if l["tipo"] == "chave":
                saida.append((CONTROLE_DA_CHAVE.get(l["id"], "chave:" + l["id"]), "chave " + l["id"]))
            elif l["tipo"] == "acao" and l["id"] not in ACAO_COM_DADO:
                saida.append((CONTROLE_DA_ACAO.get(l["id"], "acao:" + l["id"]), "ação " + l["id"]))
            elif l["tipo"] == "gesto" and l["id"].startswith("acervo:"):
                saida.append((l["id"], "gesto " + l["id"]))
        if rota == "criar/mandar":
            saida = [(p if p != "pack:" else "criar:vestir", o) for p, o in saida]
        return saida

    def permitido(self, rota, nome, esperado):
        if any(nome.startswith(p) for p, _o in esperado):
            return True
        padroes = list(GLOBAIS)
        for chave, extras in EXTRAS.items():
            if fnmatch.fnmatch(rota, chave):
                padroes += extras
        return any(fnmatch.fnmatch(nome, p) or fnmatch.fnmatch(molde(nome), p) for p in padroes)

    def visitar(self, rota):
        self.rota = rota
        inicio = time.time()
        self.ir(rota)
        self.checa(self.js("() => document.querySelectorAll('details.mais, [data-controle^=\"mais:\"]').length") == 0,
                   "nenhuma dobra «Mais ajustes» na página")
        self.assentar(quieto=500, teto=15000)
        itens = self.censo()
        sem_nome = [i["html"] for i in itens if not i["nome"]]
        self.checa(not sem_nome, f"todo controle tem nome (sem: {sem_nome[:3]})")
        esperado = self.esperado(rota)
        nomes = [i["nome"] for i in itens if i["nome"]]
        for prefixo, oque in esperado:
            self.checa(any(n.startswith(prefixo) for n in nomes), f"a {oque} tem controle na página")
        for n in sorted(set(nomes)):
            self.checa(self.permitido(rota, n, esperado), f"o controle «{n}» não está no inventário (sem teste)")
        ruim = self.js(TEXTO_RUIM_JS)
        self.checa(not ruim["ruins"], f"texto quebrado na tela: {ruim['ruins'][:3]}")
        self.checa(ruim["senha"] == 0, "nenhum campo de senha")
        if FOTOS:
            os.makedirs(FOTOS, exist_ok=True)
            self.pag.screenshot(path=os.path.join(FOTOS, rota.replace("/", "-") + ".png"), full_page=True)
        feitos = set()
        for item in itens:
            nome = item["nome"]
            if not nome or nome.startswith(("porta:", "ajuste:", "passo:")):
                continue
            m = molde(nome)
            if m in feitos or any(fnmatch.fnmatch(m, p) for p in NO_FIM):
                continue
            self.limpar()
            if self.js("() => location.hash") != "#" + rota:
                self.ir(rota)
                self.assentar()
            agora = self.censo()
            vivo = next((i for i in agora if i["nome"] == nome), None)
            if vivo is None:
                continue
            if vivo["pressionado"] == "true" and ("=" in nome or nome.startswith("galeria:")):
                familia = (lambda n: molde(n)) if "=" in nome else (lambda n: n.split(":")[0])
                livre = next((i for i in agora if i["nome"] and familia(i["nome"]) == familia(nome)
                              and i["pressionado"] != "true" and not i["desabilitado"]), None)
                if livre:
                    nome, vivo = livre["nome"], livre
            feitos.add(m)
            t0 = time.time()
            try:
                self.acionar(nome, vivo)
            except Exception as e:  # noqa: BLE001
                self.falha(f"o gesto em «{nome}» quebrou: {type(e).__name__}: {str(e).splitlines()[0][:160]}")
                self.fechar_pergunta()
                self.fechar_resultado()
            self.acionados.add(m)
            if time.time() - t0 > 20:
                print(f"   · {nome}: {round(time.time() - t0)}s", flush=True)
        self.limpar()
        self.assentar()
        if self.js("() => MUDANCAS.size"):
            self.clicar("desfazer")
            self.assentar()
            self.checa(self.js("() => MUDANCAS.size") == 0, "o Desfazer limpa o que a página deixou esperando")
        self.tempos[rota] = round(time.time() - inicio, 1)

    def fluxos(self):
        self.rota = "barra de cima"
        self.ir("tema")
        campo = self.achar("busca")
        campo.click()
        self.acionados.add("busca")
        campo.fill("vidro")
        self.assentar()
        if self.checa(self.achar("achado"), "a busca acha «vidro»"):
            self.clicar("achado")
            self.assentar()
            self.checa(self.js("() => location.hash.startsWith('#ajustes/')"), "o achado leva à página do Definir")
            self.checa(self.pag.locator("#conteudo .chegou").count() == 1, "e acende a linha do ajuste")
        self.ir("ajustes/painel")
        self.clicar("chave:RELOGIO_SEGUNDOS")
        self.assentar()
        self.checa(self.js("() => MUDANCAS.size") == 1, "um clique num ajuste vira uma mudança esperando")
        self.clicar("pendentes")
        self.assentar()
        if self.checa(self.achar("pendente:RELOGIO_SEGUNDOS"), "a conta abre a lista do que espera"):
            self.clicar("pendente:RELOGIO_SEGUNDOS")
            self.assentar()
        self.clicar("desfazer")
        self.assentar()
        self.checa(self.js("() => MUDANCAS.size") == 0, "o Desfazer tira as mudanças que esperavam")
        self.clicar("chave:RELOGIO_SEGUNDOS")
        self.assentar()
        self.clicar("ensaiar")
        self.assentar()
        if self.checa(self.aberto("resultado"), "«Ver sem mudar» abre a janela do ensaio"):
            self.checa(self.js("() => !document.getElementById('faixa-ensaio').hidden"), "e ela diz que é ensaio")
            self.esperar_trabalho()
            self.checa(valor_de("RELOGIO_SEGUNDOS") == "nao", "o ensaio não grava o meow.conf")
            self.clicar("resultado:registro")
            if self.checa(self.achar("resultado:de-verdade"), "depois do ensaio, «Rodar de verdade»"):
                self.clicar("resultado:de-verdade")
                self.assentar()
                self.checa(self.aberto("resultado"), "«Rodar de verdade» abre o trabalho")
                self.checa(valor_de("RELOGIO_SEGUNDOS") == "sim", "e grava o meow.conf")
                if self.js("() => !!TRABALHO && !!TRABALHO.timer"):
                    self.pag.keyboard.press("Escape")
                    self.assentar()
                    if self.checa(self.achar("trabalho"), "fechar a janela com o trabalho correndo deixa a pastilha"):
                        self.clicar("trabalho")
                        self.assentar()
                self.esperar_trabalho(parar=True)
                self.clicar("resultado:guardar")
                self.assentar()
                self.fechar_resultado()
        self.clicar("aplicar")
        self.assentar()
        if self.checa(self.aberto("resultado"), "«Aplicar» abre o trabalho"):
            self.esperar_trabalho(parar=True)
            self.fechar_resultado()
        self.ir("cuidar")
        acao = self.js("() => ['instalar', 'sistema_atualizar'].find((id) => ACAO.get(id) && !ESQUEMA.ponte) || ''")
        if acao:
            self.clicar("acao:" + acao)
            self.assentar()
            titulo = self.js("() => document.getElementById('pergunta-titulo').textContent")
            if self.checa(self.aberto("pergunta") and titulo == "Falta a ponte",
                          f"sem a ponte, «{acao}» mostra «Falta a ponte» ({titulo!r})"):
                self.checa(self.js("() => document.getElementById('pergunta-sim').textContent") == "Consertar a ponte",
                           "e o botão é «Consertar a ponte»")
                self.clicar("pergunta:sim")
                self.assentar()
                if self.checa(self.aberto("resultado"), "«Consertar a ponte» roda"):
                    self.esperar_trabalho(teto=300)
                    self.fechar_resultado()
        self.clicar("menu")
        self.assentar()
        self.h_link_externo("menu:creditos")
        if not self.js("() => document.getElementById('menu').open"):
            self.clicar("menu")
        self.h_download("menu:pagina")
        self.clicar("marca")
        self.assentar()
        self.checa(self.js("() => location.hash") == "#tema", "a marca leva ao Tema")
        self.ir("criar/sons")
        passos = self.js("() => PASSOS.map((p) => '#criar/' + p.id)")
        antes = self.js("() => location.hash")
        self.clicar("criar:voltar")
        self.assentar()
        self.checa(self.js("() => location.hash") == passos[passos.index(antes) - 1], "«Voltar» leva ao passo de antes")
        antes = self.js("() => location.hash")
        self.clicar("criar:proximo")
        self.assentar()
        self.checa(self.js("() => location.hash") == passos[passos.index(antes) + 1], "o próximo leva ao passo seguinte")


def main():
    ambiente = montar_casa()
    proc, url = sobe_servidor(ambiente)
    if not url:
        print("FALHOU: o painel não subiu na casa de brinquedo")
        return 2
    inicio = time.time()
    with sync_playwright() as pw:
        navegador = pw.chromium.launch()
        contexto = navegador.new_context(viewport={"width": 1829, "height": 1029}, accept_downloads=True)

        def rota_de_fora(r):
            PEDIDOS_DE_FORA.append(r.request.url)
            r.abort()

        contexto.route(re.compile(r"^https?://(?!127\.0\.0\.1)"), rota_de_fora)
        pag = contexto.new_page()
        p = Percurso(pag)
        pag.goto(url)
        p.assentar(quieto=600, teto=30000)
        rotas = [r for r in ROTAS if not SO_ABA or r.startswith(SO_ABA)]
        for rota in rotas:
            print(f"== {rota}")
            try:
                p.visitar(rota)
            except Exception as e:  # noqa: BLE001
                p.falha(f"a página quebrou: {type(e).__name__}: {str(e).splitlines()[0][:200]}")
        if not SO_ABA:
            print("== a barra de cima e as caixas")
            try:
                p.fluxos()
            except Exception as e:  # noqa: BLE001
                p.falha(f"os fluxos quebraram: {type(e).__name__}: {str(e).splitlines()[0][:200]}")
            for o in OBRIGATORIOS:
                p.checa(any(fnmatch.fnmatch(a, o) or a == o for a in p.acionados), f"«{o}» foi acionado")
        navegador.close()
    proc.terminate()
    fora = [l for l in registro() if "fora da casa" in l]
    p.checa(not fora, f"nenhum sinal fora da casa ({fora[:3]})")
    print(f"\n{p.conferidas} conferências, {len(p.acionados)} moldes acionados, "
          f"{len(p.vistos)} vistos, {round(time.time() - inicio)}s")
    for rota, s in p.tempos.items():
        print(f"   {rota}: {s}s")
    if p.falhas:
        print(f"FALHOU: {len(p.falhas)} achado(s)")
        return 1
    print("ok: o painel inteiro, porta por porta e controle por controle")
    return 0


if __name__ == "__main__":
    import signal
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    signal.signal(signal.SIGHUP, lambda *_: sys.exit(129))
    try:
        sys.exit(main())
    finally:
        for _vez in range(2):
            if os.path.isdir(CASA):
                encerrar_a_casa()
            shutil.rmtree(BRINQUEDO, ignore_errors=True)
            if not os.path.exists(BRINQUEDO):
                break
            time.sleep(1)

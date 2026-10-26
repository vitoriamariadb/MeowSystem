#!/usr/bin/env python3
"""readme.py texto [--conferir] | capturas

texto      regera no README.md e no README.en.md o que vem do código
capturas   fotografa as portas do painel numa casa de brinquedo, headless
"""
import glob
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import tomllib

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAPTURAS = "docs/capturas/readme"
LEIAS = {"pt": "README.md", "en": "README.en.md"}
TITULOS = {
    "pt": {"comandos": "## Comandos", "packs": "## Os packs", "portas": "## O painel"},
    "en": {"comandos": "## Commands", "packs": "## The packs", "portas": "## The panel"},
}
NUMERAIS = {
    "pt": ["zero", "uma", "duas", "três", "quatro", "cinco", "seis", "sete", "oito", "nove"],
    "en": ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"],
}
LIMIAR = 0.003

for _v in [v for v in os.environ if v.startswith("GIT_")]:
    del os.environ[_v]


def git(*args):
    r = subprocess.run(["git", "-C", RAIZ, *args], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def config():
    with open(os.path.join(RAIZ, "docs", "readme.toml"), "rb") as fh:
        return tomllib.load(fh)


def versao():
    for tag in git("tag", "--list", "v*", "--sort=-v:refname").splitlines():
        if re.fullmatch(r"v\d+\.\d+\.\d+", tag):
            return tag
    return None


def contagens():
    with open(os.path.join(RAIZ, "install.sh"), encoding="utf-8") as fh:
        texto = fh.read()
    bloco = re.search(r"local etapas=\((.*?)\)", texto, re.S)
    etapas = len(set(re.findall(r"\betapa_[a-z_0-9]+\b", bloco.group(1)))) if bloco else 0
    with open(os.path.join(RAIZ, "bin", "meow"), encoding="utf-8") as fh:
        m = re.search(r"^VERIFICAVEIS=\((.*)\)$", fh.read(), re.M)
    conferencias = len(m.group(1).split()) if m else 0
    with open(os.path.join(RAIZ, "meow.conf.exemplo"), encoding="utf-8") as fh:
        chaves = sum(1 for l in fh if re.match(r"^[A-Z_][A-Z_0-9]*=", l))
    r = subprocess.run(
        [sys.executable, "-c",
         "import sys; sys.path.insert(0, sys.argv[1] + '/app'); import servidor; "
         "print(len(servidor.ACOES))", RAIZ],
        capture_output=True, text=True, env=dict(os.environ, MEOW_RAIZ=RAIZ))
    acoes = int(r.stdout.strip().splitlines()[-1]) if r.returncode == 0 and r.stdout.strip() else 0
    if not all((etapas, conferencias, chaves, acoes)):
        sys.exit("readme: não consegui contar etapas, conferências, chaves e ações")
    return {"etapas": etapas, "conferencias": conferencias, "chaves": chaves, "acoes": acoes}


def portas():
    with open(os.path.join(RAIZ, "app", "pagina", "lugares.js"), encoding="utf-8") as fh:
        bloco = re.search(r"const PORTAS = \[(.*?)\];", fh.read(), re.S)
    if not bloco:
        sys.exit("readme: não achei as PORTAS em app/pagina/lugares.js")
    return re.findall(r'\{\s*id:\s*"([a-z]+)",\s*nome:\s*"([^"]+)"', bloco.group(1))


def comandos(lista):
    casa = tempfile.mkdtemp(prefix="meow-readme-ajuda-")
    try:
        r = subprocess.run(["bash", os.path.join(RAIZ, "bin", "meow"), "--help"],
                           capture_output=True, text=True, cwd=casa,
                           env={"PATH": "/usr/bin:/bin", "HOME": casa, "LANG": "C.UTF-8",
                                "MEOW_RAIZ": RAIZ})
    finally:
        shutil.rmtree(casa, ignore_errors=True)
    ajuda = {}
    for linha in r.stdout.splitlines():
        m = re.match(r"^  (meow\b.*?)\s{2,}(\S.*)$", linha)
        if m:
            ajuda.setdefault(m.group(1).strip(), m.group(2).strip())
    faltam = [c for c in lista if c not in ajuda]
    if faltam:
        sys.exit("readme: o meow --help não tem " + ", ".join(faltam))
    return [(c, ajuda[c]) for c in lista]


def packs():
    padrao = subprocess.run([sys.executable, os.path.join(RAIZ, "scripts", "pack.py"), "padrao"],
                            capture_output=True, text=True).stdout.strip()
    saida = []
    for caminho in sorted(glob.glob(os.path.join(RAIZ, "packs", "*", "pack.json"))):
        pasta = os.path.dirname(caminho)
        with open(caminho, encoding="utf-8") as fh:
            p = json.load(fh)
        arquivo = (p.get("paleta") or {}).get("arquivo") or "paleta.json"
        try:
            with open(os.path.join(pasta, arquivo), encoding="utf-8") as fh:
                flavors = list(json.load(fh).get("flavors") or {})
        except (OSError, ValueError):
            flavors = []
        saida.append({
            "id": p.get("id") or os.path.basename(pasta), "nome": p.get("nome") or p.get("id"),
            "autor": p.get("autor") or "", "flavors": flavors,
            "descricao": (p.get("vitrine") or {}).get("descricao_curta") or "",
            "padrao": os.path.realpath(pasta) == os.path.realpath(padrao or "/nada"),
        })
    saida.sort(key=lambda p: (not p["padrao"], p["id"]))
    return saida


def bloco_comandos(cmds):
    largura = max(len(c) for c, _ in cmds) + 2
    return "```bash\n" + "".join(f"{c.ljust(largura)}# {d}\n" for c, d in cmds) + "```"


def bloco_packs(lingua, lista):
    if lingua == "pt":
        linhas = ["| pack | flavors | de | o que é |", "|---|---|---|---|"]
        for p in lista:
            extra = ", o padrão" if p["padrao"] else ""
            linhas.append(f"| **{p['nome']}** (`{p['id']}`{extra}) | {', '.join(p['flavors'])} "
                          f"| {p['autor']} | {p['descricao']} |")
        linhas += ["", "O formato está em [`docs/PACKS.md`](docs/PACKS.md)."]
    else:
        linhas = ["| pack | flavors | by |", "|---|---|---|"]
        for p in lista:
            extra = ", the default" if p["padrao"] else ""
            linhas.append(f"| **{p['nome']}** (`{p['id']}`{extra}) | {', '.join(p['flavors'])} "
                          f"| {p['autor']} |")
        linhas += ["", "The format is in [`docs/PACKS.md`](docs/PACKS.md) (Portuguese)."]
    return "\n".join(linhas)


def bloco_portas(lingua, lista, cont, cfg):
    n = NUMERAIS[lingua][len(lista)] if len(lista) < 10 else str(len(lista))
    if lingua == "pt":
        abre = (f"`meow abrir`, ou o ícone MeowSystem no lançador. {cont['chaves']} ajustes e "
                f"{cont['acoes']} ações em {n} portas:")
        alt = "A porta {} do painel"
    else:
        abre = (f"`meow abrir`, or the MeowSystem icon in the launcher. {cont['chaves']} settings and "
                f"{cont['acoes']} actions behind {n} doors (the panel speaks Portuguese):")
        alt = "The {} door of the panel"
    descr = cfg.get("portas") or {}
    celulas = []
    for ident, nome in lista:
        texto = (descr.get(ident) or {}).get(lingua, "")
        img = f"{CAPTURAS}/{ident}.png"
        foto = (f'<img src="{img}" alt="{alt.format(nome)}"><br>'
                if os.path.isfile(os.path.join(RAIZ, img)) else "")
        celulas.append(f'<td width="50%">{foto}<b>{nome}</b>: {texto}</td>')
    linhas = [abre, "", "<table>"]
    for i in range(0, len(celulas), 2):
        linhas += ["<tr>", *celulas[i:i + 2], "</tr>"]
    linhas.append("</table>")
    return "\n".join(linhas)


def trocar_secao(texto, titulo, corpo):
    linhas = texto.split("\n")
    try:
        ini = linhas.index(titulo)
    except ValueError:
        sys.exit(f"readme: não achei a seção «{titulo}»")
    fim = next((i for i in range(ini + 1, len(linhas)) if linhas[i].startswith("## ")), len(linhas))
    cauda = linhas[fim:]
    return "\n".join(linhas[:ini + 1] + [""] + corpo.split("\n") + [""] + cauda)


def regerar(lingua, texto, dados):
    cfg, cont, v = dados["cfg"], dados["cont"], dados["versao"]
    if v:
        texto = re.sub(r"(vers%C3%A3o|version)-v[0-9][0-9.]*-", lambda m: f"{m.group(1)}-{v}-", texto)
    trocas = {
        "pt": [(r"instalador-[0-9]+%20etapas", "etapas"), (r"São [0-9]+ etapas", "etapas"),
               (r"doctor-[0-9]+%20confer", "conferencias"), (r"faz [0-9]+ conferências", "conferencias")],
        "en": [(r"installer-[0-9]+%20steps", "etapas"), (r"[0-9]+ steps\.", "etapas"),
               (r"doctor-[0-9]+%20checks", "conferencias"), (r"runs [0-9]+ checks", "conferencias")],
    }[lingua]
    for padrao, chave in trocas:
        texto = re.sub(padrao, lambda m: re.sub(r"[0-9]+", str(cont[chave]), m.group(0), count=1), texto)
    texto = re.sub(r"git clone https://\S+?\.git", f"git clone {cfg['repositorio']}.git", texto)
    t = TITULOS[lingua]
    texto = trocar_secao(texto, t["comandos"], bloco_comandos(dados["comandos"]))
    texto = trocar_secao(texto, t["packs"], bloco_packs(lingua, dados["packs"]))
    texto = trocar_secao(texto, t["portas"], bloco_portas(lingua, dados["portas"], cont, cfg))
    return texto


def texto(conferir):
    cfg = config()
    dados = {"cfg": cfg, "cont": contagens(), "versao": versao(), "portas": portas(),
             "comandos": comandos(cfg.get("comandos") or []), "packs": packs()}
    mudou = []
    for lingua, nome in LEIAS.items():
        caminho = os.path.join(RAIZ, nome)
        with open(caminho, encoding="utf-8") as fh:
            antes = fh.read()
        depois = regerar(lingua, antes, dados)
        if depois != antes:
            mudou.append(nome)
            if not conferir:
                with open(caminho, "w", encoding="utf-8") as fh:
                    fh.write(depois)
    if mudou:
        print(("o código diz outra coisa em " if conferir else "regerado: ") + ", ".join(mudou))
        return 1
    print("o README já diz o que o código diz")
    return 0


RECUSA = '#!/bin/sh\necho "$(basename "$0") $*" >> "$MEOW_README_REGISTRO"\nexit 1\n'
SO_LE = """#!/bin/bash
IFS=: read -ra _d <<< "$PATH"
for d in "${_d[@]}"; do
  [ "$d" = "%(falso)s" ] && continue
  [ -x "$d/%(nome)s" ] && { real="$d/%(nome)s"; break; }
done
case " $* " in
  %(leitura)s) [ -n "${real:-}" ] && exec "$real" "$@"; exit 1 ;;
esac
echo "%(nome)s $*" >> "$MEOW_README_REGISTRO"
exit 1
"""
GIT_SEM_REDE = """#!/bin/bash
case " $* " in
  *" clone "*|*" fetch "*|*" pull "*|*" push "*|*" ls-remote "*|*" submodule "*) exit 1 ;;
esac
IFS=: read -ra _d <<< "$PATH"
for d in "${_d[@]}"; do
  [ "$d" = "%(falso)s" ] && continue
  [ -x "$d/git" ] && exec "$d/git" "$@"
done
exit 127
"""
LEITURAS = {
    "systemctl": '*" is-active "*|*" is-enabled "*|*" is-failed "*|*" show "*|*" status "*'
                 '|*" cat "*|*" list-units "*|*" list-unit-files "*|*" --version "*',
    "gsettings": '" get "*|*" get "*|" list-"*|" range "*|" describe "*|" writable "*',
    "dconf": '" read "*|" list "*|" dump "*',
    "busctl": '*" get-property "*|*" introspect "*',
}
ASSENTAR = """
([quieto, teto]) => new Promise((pronto) => {
  let t = null;
  const fim = () => { obs.disconnect(); clearTimeout(t); clearTimeout(limite); pronto(); };
  const obs = new MutationObserver(() => { clearTimeout(t); t = setTimeout(fim, quieto); });
  obs.observe(document.body, { subtree: true, childList: true, attributes: true, characterData: true });
  t = setTimeout(fim, quieto);
  const limite = setTimeout(fim, teto);
})
"""
COMPARAR = """
async ([a, b]) => {
  const ler = (src) => new Promise((ok, erro) => {
    const i = new Image(); i.onload = () => ok(i); i.onerror = erro; i.src = src; });
  const [x, y] = await Promise.all([ler(a), ler(b)]);
  if (x.naturalWidth !== y.naturalWidth || x.naturalHeight !== y.naturalHeight) return 1;
  const w = x.naturalWidth, h = x.naturalHeight;
  const pixels = (img) => { const c = new OffscreenCanvas(w, h); const g = c.getContext("2d");
    g.drawImage(img, 0, 0); return g.getImageData(0, 0, w, h).data; };
  const p = pixels(x), q = pixels(y);
  let diferentes = 0;
  for (let k = 0; k < p.length; k += 4) {
    if (Math.abs(p[k] - q[k]) > 8 || Math.abs(p[k + 1] - q[k + 1]) > 8 || Math.abs(p[k + 2] - q[k + 2]) > 8)
      diferentes++;
  }
  return diferentes / (w * h);
}
"""


def escrever_exec(caminho, corpo):
    with open(caminho, "w", encoding="utf-8") as fh:
        fh.write(corpo)
    os.chmod(caminho, 0o755)


def montar_casa(brinquedo):
    raiz_b = os.path.join(brinquedo, "raiz")
    casa = os.path.join(brinquedo, "casa")
    falso = os.path.join(brinquedo, "falso")
    lista = subprocess.run(["git", "-C", RAIZ, "ls-files", "-z", "--cached"],
                           capture_output=True, check=True).stdout.decode().split("\0")
    for rel in filter(None, lista):
        origem, destino = os.path.join(RAIZ, rel), os.path.join(raiz_b, rel)
        if not os.path.lexists(origem):
            continue
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        if os.path.islink(origem):
            os.symlink(os.readlink(origem), destino)
        else:
            shutil.copy2(origem, destino)
    conf = os.path.join(casa, ".config", "meow", "meow.conf")
    estado = os.path.join(casa, ".local", "state", "meowsystem")
    os.makedirs(os.path.dirname(conf))
    os.makedirs(estado)
    shutil.copyfile(os.path.join(RAIZ, "meow.conf.exemplo"), conf)
    os.makedirs(falso)
    registro = os.path.join(brinquedo, "registro")
    open(registro, "w").close()
    for nome in ("sudo", "pkexec", "su", "pkill", "killall", "notify-send", "systemd-run",
                 "xdg-open", "curl", "wget", "cargo", "apt", "apt-get", "loginctl", "flatpak"):
        escrever_exec(os.path.join(falso, nome), RECUSA)
    escrever_exec(os.path.join(falso, "git"), GIT_SEM_REDE % {"falso": falso})
    for nome, leitura in LEITURAS.items():
        escrever_exec(os.path.join(falso, nome), SO_LE % {"falso": falso, "nome": nome, "leitura": leitura})
    ambiente = {
        "PATH": falso + os.pathsep + os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": casa, "USER": os.environ.get("USER", "meow"), "LANG": "pt_BR.UTF-8",
        "MEOW_CONF": conf, "MEOW_ESTADO": estado,
        "MEOW_PONTE": os.path.join(brinquedo, "sem-ponte"),
        "MEOW_README_REGISTRO": registro, "MEOW_README_CASA": casa,
    }
    return raiz_b, casa, ambiente


def encerrar(casa):
    marca = ("MEOW_README_CASA=" + casa).encode()
    for sinal in (signal.SIGTERM, signal.SIGKILL):
        vivos = 0
        for pid in filter(str.isdigit, os.listdir("/proc")):
            if int(pid) == os.getpid():
                continue
            try:
                with open(f"/proc/{pid}/environ", "rb") as fh:
                    if marca in fh.read().split(b"\0"):
                        os.kill(int(pid), sinal)
                        vivos += 1
            except OSError:
                continue
        if not vivos:
            return
        time.sleep(1)


def capturas():
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("pulado: este python3 não tem o Playwright; as capturas ficaram como estavam")
        return 3
    import base64
    lista = portas()
    brinquedo = tempfile.mkdtemp(prefix="meow-readme-")
    raiz_b, casa, ambiente = montar_casa(brinquedo)
    proc = None
    trocadas = []
    try:
        proc = subprocess.Popen([os.path.join(raiz_b, "app", "run.sh"), "--sem-abrir"], cwd=raiz_b,
                                env=ambiente, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True)
        url, inicio = None, time.time()
        while time.time() - inicio < 40:
            linha = proc.stdout.readline()
            if not linha:
                break
            m = re.search(r"http://127\.0\.0\.1:\d+/\?t=[A-Za-z0-9_-]+", linha)
            if m:
                url = m.group(0)
                break
        if not url:
            print("readme: o painel não subiu na casa de brinquedo")
            return 2
        destino = os.path.join(RAIZ, CAPTURAS)
        os.makedirs(destino, exist_ok=True)
        limpo = {k: v for k, v in os.environ.items()
                 if k not in ("DISPLAY", "WAYLAND_DISPLAY", "DBUS_SESSION_BUS_ADDRESS")}
        with sync_playwright() as pw:
            navegador = pw.chromium.launch(headless=True, env=limpo)
            contexto = navegador.new_context(viewport={"width": 1440, "height": 900})
            contexto.route(re.compile(r"^https?://(?!127\.0\.0\.1)"), lambda r: r.abort())
            pag = contexto.new_page()
            pag.goto(url)
            pag.evaluate(ASSENTAR, [700, 30000])
            for ident, _nome in lista:
                pag.click(f'[data-controle="porta:{ident}"]')
                pag.evaluate(ASSENTAR, [700, 20000])
                pag.mouse.move(0, 0)
                pag.wait_for_timeout(300)
                novo = os.path.join(brinquedo, ident + ".png")
                pag.screenshot(path=novo)
                velho = os.path.join(destino, ident + ".png")
                if os.path.isfile(velho):
                    uri = lambda c: "data:image/png;base64," + base64.b64encode(open(c, "rb").read()).decode()
                    if pag.evaluate(COMPARAR, [uri(velho), uri(novo)]) < LIMIAR:
                        continue
                shutil.copyfile(novo, velho)
                trocadas.append(ident)
            navegador.close()
    finally:
        if proc:
            proc.terminate()
        encerrar(casa)
        shutil.rmtree(brinquedo, ignore_errors=True)
    if trocadas:
        print("capturas novas: " + ", ".join(trocadas))
        return 1
    print("as capturas já mostram o painel de hoje")
    return 0


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "texto":
        return texto("--conferir" in sys.argv[2:])
    if len(sys.argv) > 1 and sys.argv[1] == "capturas":
        return capturas()
    print(__doc__.strip())
    return 2


if __name__ == "__main__":
    sys.exit(main())

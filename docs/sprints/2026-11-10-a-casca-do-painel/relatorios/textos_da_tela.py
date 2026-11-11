import re
import sys
from pathlib import Path

RAIZ = Path(sys.argv[1])
PAGINA = RAIZ / "app" / "pagina"

TELA_POR_ARQUIVO = {
    "lugares.js": "mapa", "app.js": "moldura", "paginas.js": "personalizar", "oficina.js": "ícones",
    "extensoes.js": "extensões", "espaco.js": "espaço", "modificacoes.js": "modificações",
    "mesa.js": "prévia", "standalone.js": "standalone", "logo-do-pack.js": "logo", "index.html": "moldura",
    "servidor.py": "servidor",
}

STR = r'"((?:[^"\\]|\\.)*)"|`((?:[^`\\]|\\.)*)`'
PADROES = [
    ("rótulo", re.compile(r'\b(?:r|b|titulo|nome):\s*(?:' + STR + ')')),
    ("texto", re.compile(r'\btexto:\s*(?:' + STR + ')')),
    ("dica", re.compile(r'\bdica:\s*(?:' + STR + ')')),
    ("botão", re.compile(r'\bbotao\(\s*(?:' + STR + ')')),
    ("aviso", re.compile(r'\btorrada\(\s*(?:' + STR + ')')),
    ("título", re.compile(r'\b(?:bloco|cabeca|linhaDoResumo)\(\s*(?:' + STR + ')')),
    ("opção", re.compile(r'\b[a-z_]+:\s*"([A-ZÁÉÍÓÚÂÊÔÃÕÇ][^"]*)"')),
]
SERVIDOR = [
    ("rótulo", re.compile(r'"rotulo":\s*"((?:[^"\\]|\\.)*)"')),
]
HTML = [
    ("texto", re.compile(r'>\s*([A-ZÁÉÍÓÚÂÊÔÃÕÇ][^<>{}]{1,80}?)\s*<')),
    ("dica", re.compile(r'data-dica="([^"]+)"')),
    ("rótulo", re.compile(r'aria-label="([^"]+)"')),
]


def visivel(t):
    t = t.strip()
    if len(t) < 2 or not re.search(r"[A-Za-zÀ-ú]", t):
        return False
    if re.fullmatch(r"[a-z0-9_.:/=#-]+", t):
        return False
    return True


def varrer(caminho, padroes):
    vistos = []
    for n, linha in enumerate(caminho.read_text(encoding="utf-8").splitlines(), 1):
        for tipo, rx in padroes:
            for m in rx.finditer(linha):
                t = next((g for g in m.groups() if g is not None), "")
                t = re.sub(r"\$\{[^}]*\}", "…", t)
                if visivel(t):
                    vistos.append((t, tipo, f"{caminho.relative_to(RAIZ)}:{n}"))
    return vistos


achados = []
for arq in sorted(PAGINA.glob("*.js")):
    achados += varrer(arq, PADROES)
achados += varrer(PAGINA / "index.html", HTML)
achados += varrer(RAIZ / "app" / "servidor.py", SERVIDOR)

unicos = {}
tipos = {}
for texto, tipo, onde in achados:
    chave = texto
    if chave not in unicos:
        tipos[chave] = tipo
        unicos[chave] = onde

por_tela = {}
for texto, onde in unicos.items():
    tela = TELA_POR_ARQUIVO.get(Path(onde.split(":")[0]).name, "?")
    por_tela[tela] = por_tela.get(tela, 0) + 1

print("# " + " · ".join(f"{t} {n}" for t, n in sorted(por_tela.items())) + f" · total {len(unicos)}")
print("texto\ttipo\tonde")
for texto, onde in sorted(unicos.items(), key=lambda x: x[1]):
    tipo = tipos[texto]
    print(f"{texto}\t{tipo}\t{onde}")

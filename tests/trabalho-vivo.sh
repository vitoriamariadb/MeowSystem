#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 3; }

CASA="$(mktemp -d)" || exit 2
trap 'rm -rf "$CASA"' EXIT

env -i PATH="$PATH" HOME="$CASA" PYTHONDONTWRITEBYTECODE=1 \
    python3 - "$RAIZ" <<'PY'
import os
import sys
import threading
import time

sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor  # noqa: E402

original = servidor.Trabalho._ler
janela = threading.Event()
morreu = threading.Event()


def ler_devagar(self):
    """O `_ler` de verdade, com a janela aberta entre a morte e o desfecho."""
    for _linha in self.proc.stdout:
        pass
    self.proc.wait()
    morreu.set()
    janela.wait(10)
    original(self)


servidor.Trabalho._ler = ler_devagar
falhas = []
t = servidor.Trabalho("teste", ["true"], dict(os.environ), "teste")
if not morreu.wait(10):
    print("ERRO deste teste: o `true` não terminou em 10 s")
    sys.exit(2)
vivo, rc = t.vivo(), t.rc
if t.proc.poll() is None:
    falhas.append("a janela não abriu: o processo ainda não tinha morrido")
elif vivo is False and rc is None:
    falhas.append("com o processo morto e o desfecho por gravar, vivo() disse False e rc é None "
                  "(é o «saiu null · 0s» da gaveta)")
elif vivo is not True:
    falhas.append("com o desfecho por gravar, vivo() disse %r" % (vivo,))
else:
    print("ok: processo morto e desfecho por gravar — vivo() ainda diz que o trabalho corre")
janela.set()
fim = time.time() + 10
while t.fim is None and time.time() < fim:
    time.sleep(0.02)
if t.vivo() is False and t.rc == 0 and t.fim is not None:
    print("ok: gravado o desfecho, vivo() diz que acabou, com rc=0 e o fim")
else:
    falhas.append("depois do desfecho: vivo()=%r rc=%r fim=%r" % (t.vivo(), t.rc, t.fim))

servidor.Trabalho._ler = original
t2 = servidor.Trabalho("teste-neto", ["sh", "-c", "sleep 60 & echo ok"], dict(os.environ), "teste")
try:
    fim = time.time() + 5
    while t2.vivo() and time.time() < fim:
        time.sleep(0.05)
    if t2.vivo() is False and t2.rc == 0:
        print("ok: o pai saiu e o neto segura o stdout — o desfecho chegou em %.1f s, com rc=0"
              % (t2.fim - t2.comeco))
    else:
        falhas.append("com um neto segurando o stdout, depois de 5 s: vivo()=%r rc=%r"
                      % (t2.vivo(), t2.rc))
finally:
    try:
        os.killpg(t2.proc.pid, 15)
    except OSError:
        pass

if falhas:
    for f in falhas:
        print("FALHOU: " + f)
    sys.exit(1)
print("passou: a gaveta nunca lê «saiu» sem o código de saída, nem fica viva por um neto")
PY

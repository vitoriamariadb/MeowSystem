#!/usr/bin/env bash
# trabalho-vivo.sh — a gaveta nunca lê «saiu» sem o código de saída.
# Sprint P80, item 6, 10/10/2026.
#
# A CORRIDA QUE ABRIU ISTO (docs/sprints/2026-10-09-uso-real/04-integracao-onda-2.md, P79)
#   O gate inteiro reprovou uma vez com «O que a atualização mudaria»
#   terminando em «SAIU NULL · 0S». O `Trabalho.vivo()` do app/servidor.py
#   respondia pelo `proc.poll()`, e o `rc` e o `fim` só são gravados depois,
#   pela thread `_ler`. Uma pergunta da página nesse intervalo recebia
#   `vivo: false` com `rc: null`, e a ação rápida que terminou certo aparecia
#   como desfecho sem número. Intermitente: depende de a pergunta cair na
#   janela, e é por isso que o gate passava e falhava na mesma árvore.
#
# O QUE ESTE TESTE FAZ: ABRE A JANELA DE PROPÓSITO
#   O `_ler` é trocado, no processo, por um que espera um sinal depois de o
#   processo morrer e antes de gravar o desfecho. Com a janela aberta:
#     1. o processo já morreu (`poll()` diz que sim);
#     2. o `vivo()` tem de dizer que o trabalho ainda está vivo — o desfecho
#        não foi gravado, e «morto sem rc» é a resposta que a página não lê;
#   e, solto o sinal:
#     3. o `vivo()` diz que acabou, com o `rc` e o `fim` gravados.
#
# NÃO ESCREVE NADA: o comando do trabalho é o `true`, e a casa é de brinquedo.
#
# PORTÁTIL: só bash e python3.
#   0 = passou · 1 = falhou · 2 = erro deste teste · 3 = pulado
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

# O NETO QUE HERDA O STDOUT — P82, 15/10/2026 (item 36)
#   O `fim` nascia só quando o stdout fechava, e um neto que herde o stdout
#   (o `&` de um script) segura o cano aberto. O trabalho ficava vivo para
#   sempre, com o pai morto. Aqui o pai sai na hora e o neto dorme 60 s com o
#   stdout herdado: o desfecho tem de chegar em menos de 5 s, com rc=0.
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
    # O neto é deste teste: sai junto, pelo grupo próprio do trabalho.
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

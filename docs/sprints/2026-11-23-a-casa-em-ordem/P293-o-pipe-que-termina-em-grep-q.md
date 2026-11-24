# P293 — o pipe que termina em `grep -q` (24/11/2026)

## O que se mediu (24/11, a suíte inteira na integração)
`tests/autostart.sh` ficou vermelho uma vez em 183 testes, e três vezes em 80 cópias rodadas ao mesmo tempo. Com o
rastro (`bash -x`) de uma cópia que falhou: a primeira passada mascarou `alfa`, `beta` e `gama`, e em seguida
**desmascarou o `beta`**, dizendo «devolvido ao autostart».

## A causa
`scripts/autostart.sh:82` perguntava «este nome saiu da lista?» com `_auto_lista | grep -qxF -- "$reg"`, e o script
roda com `set -o pipefail`. O `grep -q` sai no primeiro acerto. Se a lista ainda está escrevendo o nome seguinte, quem
escreve morre de SIGPIPE, o pipeline devolve 141 e o acerto vira erro: o aplicativo que segue na lista é tomado por
quem saiu dela. Não era defeito do teste; era o produto desmascarando, de vez em quando, um autostart bloqueado.

O mesmo desenho estava em mais 72 pontos de 34 arquivos (`ldd … | grep -q 'not found'`,
`"$GB_GRAFICOS" estado | grep -qx 'build=sim'`, `flatpak ps … | grep -qx`, `cut -f1 "$lista" | grep -qxF`). Nos que
vêm depois de um `!`, a corrida vira o contrário: a biblioteca que falta passa por presente.

## A cura na origem
1. `autostart.sh`: a lista é lida uma vez para uma variável e o `grep` lê dela (`<<<`), sem pipe.
2. Os 72 pontos, por roteiro (`sem-grep-q.py`, no rascunho da sessão): `| grep -qX …` vira `| grep -X … >/dev/null`.
   O `grep` lê a entrada inteira e ninguém morre de SIGPIPE; o código de saída é o mesmo.
3. Guarda em `tests/estilo.sh`: nenhum pipe de `scripts/` e do `install.sh` termina em `grep -q`.

## Como se prova
- `tests/autostart.sh` ganhou um caso que força a corrida com um `tr` lento: vermelho com o conserto desfeito («a
  segunda passada desmascarou quem segue na lista»), verde com ele. 120 cópias ao mesmo tempo: nenhuma falha.
- `tests/estilo.sh`: com um `| grep -qx` posto de volta numa cópia, vermelho, citando arquivo e linha.
- `bash -n` nos 34 arquivos, e a suíte inteira na ponta.

## Feito (24/11/2026)
Commits na `bloco/raiz-nova`: o do `autostart` e o dos pipes. Integrados antes do commit único da P284.

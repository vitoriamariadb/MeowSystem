# P244 — a suíte do GitHub está vermelha ou estoura o tempo desde 11/11 (18/11/2026)

## O que se mediu (coordenador, 18/11)
- `gh run list --workflow testes.yml --limit 12`: nenhum verde. 5 `failure` e 7 `cancelled`, de 11/11 a 18/11. Os
  `cancelled` param em 45m17s: é o `timeout-minutes: 45` do `.github/workflows/testes.yml`.
- Run `44231439802` (master, 18/11): 129 portáteis, 121 verdes, 2 pulados, **6 vermelhos**: `chaves-aposentadas.sh`
  (2 achados), `doctor-veredito.sh` (1), `trava-herdada.sh` (5), `garantir-builds.sh`, `maquina-nova.sh` (6, entre
  eles «o apt não recebeu: build-essential…» e «sem .git, rc 2») e `deb.sh` («não gerou o pacote, rc 2»).
- Os mesmos seis no nitro-5, na árvore `.meow-wt-integracao-17`, com `./tests/todos.sh --so=…`: **6 verdes** (o
  `deb.sh` leva 299 s).
- A `bloco/ci2` (16/11, fora do master) já mexe em `doctor-veredito`, `garantir-builds`, `maquina-nova` e
  `trava-herdada` e sobe o limite para 60 minutos. Ela não toca em `chaves-aposentadas` nem em `deb`.
- A suíte inteira da leva de 17/11, que o `ESTADO.md` de lá diz que roda na `.meow-wt-integracao-17`, não deixou
  resultado em arquivo.

## A causa
Os seis dependem de algo que a máquina de casa tem e o `ubuntu-latest` não. A `bloco/ci2` traz a causa de quatro
(P204); os dois restantes não têm causa medida. O limite de 45 minutos corta a suíte, que hoje passa disso no runner.

## A cura na origem
1. Trazer a `bloco/ci2` para cima do master e conferir, teste a teste, o que ela ainda cura.
2. Reproduzir `chaves-aposentadas.sh` e `deb.sh` num contêiner `ubuntu:24.04` limpo e curar a dependência da
   máquina no teste ou no código, onde ela estiver.
3. O limite do workflow sai do tempo medido da suíte no runner, com folga declarada no commit.
4. A suíte inteira roda uma vez na integração e o resultado fica no `ESTADO.md` da leva.

## Como se prova
Um run `testes` verde no master, com o número do run no `ESTADO.md`. `--portatil` verde no contêiner limpo.

## Nos três PCs
Não muda a máquina de ninguém. Sem ela, o push que vai para os três PCs não tem prova fora do nitro-5.

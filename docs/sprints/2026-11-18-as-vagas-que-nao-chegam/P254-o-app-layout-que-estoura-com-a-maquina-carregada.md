# P254 — o `app-layout.py` estoura com a máquina carregada (18/11/2026)

## O que se mediu (conferente do bloco A, nitro-5, 18/11 18h15 a 21h25)
- Suíte inteira do bloco A: 170 testes, 166 verdes, 1 pulado (`dock-fonte-real.sh`, sem o fonte do `cosmic-applets`),
  3 vermelhos. Dois foram corrigidos no bloco (`104daa84`, `d4f2eca6`). Ficou o `tests/app-layout.py`, linha 272:
  `pag.wait_for_function("() => !ACOMPANHANDO && !EM_VOO", timeout=60000)` estoura.
- No começo da espera, `EM_VOO` vale 26 (gravações na fila do `app.js`, um gesto e um desfazer por chave da seção
  anterior). A fila cai uma a cada 23 s, mais ou menos. Com 600 s de espera ainda estoura.
- A carga da máquina ficou entre 13 e 19 durante a medida, de outro projeto (`Projetos_segape`, vários `python` a
  90% de CPU) e de uma rodada `--so=` do bloco F ao mesmo tempo. Na rodada do bloco F, com a mesma carga, estouram
  também `app-navegador.py` e `extensoes-pagina.py` (30 s e 60 s de espera).
- Vermelho também em `0afb4915` e em `fba83b63^`, sempre com a máquina nessa carga. Em 17/11, sem ela, a suíte da
  integração fechou verde.

## Medida de 19/11, com a máquina livre (coordenador, integração `dc22d796`)
Carga entre 2 e 8. `app-navegador.py` (350 s) e `extensoes-pagina.py` (85 s) ficam verdes: nesses dois era só carga.
O `app-layout.py` estoura de novo na linha 272, em 311 s. A fila lenta de gravações não depende da carga.

## A causa (a provar)
Cada `/api/definir` leva perto de 23 s com a máquina acima de 12 de carga (12 linhas de CPU), e o teste espera 60 s
por uma fila de 26. A medida de 19/11 tira a carga da conta: a gravação é lenta por si. Hipóteses a medir, nenhuma provada: espera
numa trava (23 s por gravação tem cara de tempo de espera, não de trabalho), um processo por gravação, ou a
fila do `app.js` que não anda enquanto o `/api/aplicando` alterna.

## A cura na origem
1. Rodar o `app-layout.py` sozinho com a máquina livre e medir o tempo de uma gravação.
2. Se uma gravação passa de 2 s com a máquina livre, a lentidão é do produto: medir onde o `/api/definir` gasta e
   curar lá.
3. Se só estoura com carga, o teste espera a fila esvaziar pelo tamanho dela (tempo por gravação medido vezes a fila),
   e não por 60 s fixos.

## Como se prova
`./tests/todos.sh --so=app-layout.py,app-navegador.py,extensoes-pagina.py` verde com a máquina livre e com carga
de 16 (`stress-ng --cpu 16` num cgroup à parte).

## Nos três PCs
É da suíte, não do uso. Se o item 2 se confirmar, a gravação lenta vale para os três.

## Outros achados do conferente do bloco A, para a próxima leva
- Desenho do pai levado para o pack pessoal sem traço declarado sai com o traço cru, não com o 2,5 do pai.
- O `pack.py levar` pela linha de comando não leva ícone; só o servidor leva (`levar_icone`).
- Aliases a rever no quadro de arte: `color-select` (paleta, não conta-gotas), `view-fullscreen` (desenho de
  maximizar), `network-wireless-disabled` e `-offline` (o mesmo desenho de desconectado).

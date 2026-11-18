# Estado da leva de 18/11 (coordenador)

Árvore desta leva: `../.meow-wt-leva-18`, branch `docs/leva-2026-11-18`.

Resposta de quem usa, 18/11, às sprints: «o tema nativo no note dela deveria ser o meowsystem igual no meu deveria
ser o dracula. default do install. Mas enfim. Pode disparar os agentes pra termos o produto final concluido?» Não é
sim sobre a decisão 3: o P241 segue esperando, e nenhum pack dos PCs dela foi trocado.

| bloco | tarefas | situação |
| --- | --- | --- |
| A vagas | P242, P246 | no ar desde 18/11 15h30: `../.meow-wt-vagas`, `bloco/vagas`; implementa (agente, high) → confere e corrige (agente, high) |
| A2 | P241 | escrita; espera o sim de quem usa (toca a decisão 3); entra no `bloco/vagas` depois do conferente do A |
| B applets e arte | P243, P247 | escritas; pedem quadro de arte aprovado antes de qualquer agente |
| C CI | P244 | no ar desde 18/11 15h30: `../.meow-wt-ci3`, `bloco/ci3`; implementa (agente, high) → confere e corrige (agente, high) |
| D doctor e documentos | P245, P248, P249 | escritas |

Quatro agentes nesta primeira rodada (dois por bloco, em sequência dentro do bloco; A e C ao mesmo tempo, com
arquivos disjuntos). Tudo o que está nos arquivos das sprints foi medido pelo coordenador, só com leitura.

## Gestos do coordenador que não são sprint
1. Portátil: `git pull` e `./install.sh` (está no `23e2a859`, de 16/11, sem a leva de 17/11).
2. Desktop: `git pull` (falta 1 commit de docs) e sair e entrar na sessão (a de lá é de 16/11; o doctor diz que
   `AURORA-COMPOE-NA-ESCOLHIDA-1` e `AURORA-AREA-DO-CLIENTE-1` estão no disco e não na sessão).
3. nitro-5: fechar Chrome e Edge e rodar `./install.sh --etapa apps` (o `chromium` ficou pendente).
4. Com o ok de quem usa: tirar as 19 árvores `.meow-wt-*` da leva de 17/11, já integradas.

## O que foi rodado nas máquinas dela nesta medição
Só leitura: `meow doctor` (sem `--consertar`), `find` no tema de ícones, leitura do `meow.conf`, do `pack.json` e do
log. Uma chamada direta a `scripts/icones_sistema.sh --conferir` em cada PC da Vitória, sem o `meow.conf` carregado: o
resultado dela («340 a instalar») não vale como medida, porque sem o conf o script adota o pack `meowsystem`; a
contagem de simbólicos depois dela continuou 0 nos dois.

## Próximo passo
1. Quando o implementador de A ou de C voltar: lançar o conferente do bloco (suíte inteira só nele; as duas suítes
   não rodam ao mesmo tempo).
2. Integrar cada bloco em `integracao/2026-11-18` assim que o conferente volta.
3. Bloco D (P245, P248, P249) quando A ou C liberar a vaga.
4. P241 com o sim; bloco B só depois do quadro de arte aprovado.
5. No fim: `master`, push, run verde no GitHub, install nos três PCs pelo coordenador.

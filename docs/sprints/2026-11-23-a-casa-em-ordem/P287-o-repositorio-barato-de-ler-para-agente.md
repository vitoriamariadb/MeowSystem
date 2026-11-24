# P287 — o repositório barato de ler para agente (23/11/2026)

Pergunta de quem usa, 23/11: as tarefas «não deveriam começar pelo que aumentaria a produtividade dos agentes
agente? otimização de tokens. limpeza e afins?»

## O que se mediu (catálogo de 23/11)
- Texto versionado: 12 322 KB. Quatro itens somam cerca de 5,8 MB e não servem a quem vai mexer no código: as seis
  levas antigas de `docs/sprints/` (2280 KB), o `theme.css` do Obsidian (2252 KB, com linhas de 63 mil caracteres),
  `packs/CAMINHOS-DE-ANTES.tsv` (473 KB) e as duas `PROCEDENCIA.md` (357 KB), mais os dois `catalog.json` (273 KB) e
  os temas `upstream/` de btop, bat e Heroic.
- Uma busca por `assets/` devolve 470 linhas; 117 são de `docs/sprints/` e 106 de comentário e procedência em
  `packs/`.
- O `AGENTS.md`, «Onde não ler por padrão», cita só `docs/sprints/`, os ícones e as capturas.
- O repositório não tem o índice de código (`.code-review-graph/`), então nenhuma sessão tem as ferramentas de
  consulta ao grafo.

## A causa
O que é upstream, catálogo gerado e registro de procedência mora junto do que se edita, e nada diz à ferramenta de
busca para pular. Uma linha de 63 mil caracteres num resultado de busca custa mais que o arquivo de código inteiro.

## A cura na origem
1. `AGENTS.md`, «Onde não ler por padrão»: entram `packs/*/temas-de-apps/*/upstream/` e `*/vendor/`, os
   `catalog.json`, as `PROCEDENCIA.md`, `packs/*/temas/capturados/` e `packs/CAMINHOS-DE-ANTES.tsv` (até a P277 a
   tirar).
2. Medir primeiro se a busca das sessões respeita um arquivo de exclusão na raiz; se respeita, ele entra com a mesma
   lista. Sem medida, não entra.
3. Construir o índice de código (`fazer_grafos`) depois do passo 2 e de novo depois da árvore final (P279).
4. A P273 e a P272 fazem o corte de verdade; esta tarefa cobre o que fica no repositório por ser dado.

## Como se prova
- A mesma busca por `assets/` e por `lib/comum.sh` antes e depois: número de linhas e a maior linha devolvida.
- Uma sessão nova acha onde uma etapa do install é definida sem abrir arquivo de `packs/` nem de `docs/sprints/`.
- `tests/decisoes.sh` verde (ele lê o `AGENTS.md`).

## Feito (23/11, bloco `barato-de-ler`), itens 1 e 2
- O `rg` 14.1.0 respeita o `.ignore` da raiz e o `tests/arvore.sh` o aceita: o arquivo entrou, com a lista do
  item 1, e o `AGENTS.md` cresceu.
- Busca por `assets/`: de 445 linhas e 65 572 bytes para 406 linhas e 58 783 bytes. O ganho é pequeno porque as
  levas antigas já tinham saído antes da medida; a maior linha (1252 caracteres) é do `pack.json` do Dracula, que a
  P276 encurta.
- Falta o item 3, o índice de código.

# Leva central e gerador — regras comuns às sprints P115 a P123

Cada bloco roda numa worktree própria. Leia este arquivo, `ANDAMENTO.md` (o pedido, as respostas de quem usa e as
decisões do coordenador), as suas sprints e o relatório que elas citam (`relatorios/levantamento-*.md`). Nada aqui
pede pergunta: o que faltava decidir está em `ANDAMENTO.md`. Se algo não está coberto, escolha o caminho que
respeita GSD.md, anote em `## Execução` no fim da sprint e siga.

## Onde trabalhar
- A worktree e a branch do seu bloco estão na tabela «Blocos» do `ANDAMENTO.md`; o coordenador já criou a partir
  do `dev`. Nunca o checkout principal (`~/Desenvolvimento/MeowSystem`), que é onde ela usa o produto.
- Os documentos da leva moram no checkout principal:
  `~/Desenvolvimento/MeowSystem/docs/sprints/2026-10-27-central-e-gerador/` (fotos em `fotos/`, capturas dos
  levantamentos em `capturas/`). Escreva o `## Execução` na cópia da sprint que está na SUA worktree.
- Os relatórios citam `arquivo:linha` medidos hoje no `dev`; ache pelo nome da função quando a linha andar.

## Estilo
- A maquete aprovada da leva anterior ainda manda no visual: `docs/sprints/2026-10-26-qa-final/maquete/`
  (`a/` moldura, Tema, Definir, Manter; `b/` Personalizar, Extensões). O que é novo segue o estilo dela.
- CSS novo vai no arquivo da tela (`oficina.css`, `extensoes.css`, `tema.css`, `manter.css`); não reformate o
  `estilo.css`.

## Regras
- Zero comentário no código. O porquê mora no nome, no teste e na mensagem de commit.
- Informação errada em doc se sobrescreve no lugar; não se acrescenta seção de histórico.
- Interface mostra, não explica. Palavras do dia a dia (aplicar, pôr, arrumar, ver); nunca «vestir».
- Pack é dado. A arte, os sons, os temas de app e as fontes moram no pack. Ícone de um pack nunca aparece no outro.
- Painel e testes só com HOME temporário (`tests/todos.sh`, `tests/app-completo.py`). Navegador só headless:
  `~/.local/share/meowsystem/venv-testes/bin/python3` (Playwright, navegadores em `~/.cache/ms-playwright`).
  Nunca rode install.sh, `meow compositor`, `meow doctor --consertar` com o HOME real. Nunca chame `sudo`.
- Uma decisão registrada (`docs/DECISOES.md`) só muda junto com o código que a lê, no mesmo commit, citando a
  resposta de 27/10 do `ANDAMENTO.md`.
- Commits pequenos em português, por caminho (nunca `git add -A`), sem linha de atribuição. O gancho global troca
  palavras: confira o diff de cada commit. Não faça merge. Push só nos repos de fork da P122.

## Fechamento de cada sprint
1. Cada item com a prova que a sprint pede, rodada.
2. `./tests/todos.sh` sem vermelho novo. Os vermelhos aceitos hoje: `decisoes.sh` (GPU e shim do compositor da
   máquina, até a P121) e `restaurar.sh` (`pack_usar` e `desinstalar`, arquivos do VS Code). Pulado não é verde.
3. `## Execução` no fim da sprint: item, commit, prova, o que ficou de fora e por quê.

## Arquivos de mais de um bloco
`app/servidor.py`, `app/pagina/app.js`, `app/pagina/index.html`, `app/pagina/estilo.css`, `bin/meow` e
`docs/DECISOES.md` são tocados por vários. Mexa só nas funções e blocos da sua sprint; não reformate, não
reordene, não renomeie nada que não é seu. O coordenador junta os blocos na integração.

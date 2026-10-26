# Leva QA final — regras comuns às sprints P109 a P114

Seis sprints rodam ao mesmo tempo, uma por agente, cada uma na sua worktree. Leia este arquivo, a sua
sprint, `ANDAMENTO.md` (as respostas de quem usa) e os itens do relatório que a sua sprint cita.
Nada aqui pede pergunta: tudo que faltava decidir está em `ANDAMENTO.md`. Se algo não está coberto,
escolha o caminho que respeita GSD.md, anote em `## Execução` no fim da sua sprint e siga.

## Onde trabalhar
- Worktree `~/Desenvolvimento/MeowSystem-pNNN`, branch `sprint/pNNN`, criada a partir
  do `dev` (o coordenador cria antes de você começar). Nunca o checkout principal.
- Os relatórios citam `arquivo:linha` de antes do enxugamento B0 (que tirou todo comentário): as
  linhas mudaram. Ache pelo nome da função, do id ou do texto, nunca pelo número.
- As fotos dos relatórios estão só no checkout principal:
  `~/Desenvolvimento/MeowSystem/docs/sprints/2026-10-26-qa-final/relatorios/fotos/`.
- As imagens que a usuária mandou: `/tmp/claude-1000/-home-vitoriamaria-Desenvolvimento-MeowSystem/314702cb-6fd7-4227-9dcc-7970f525cc19/images/N.png`
  (podem ter sumido num reboot; os relatórios descrevem cada uma).

## Regras
- Zero comentário no código. O porquê mora no nome, no teste e na mensagem de commit.
- Informação errada em doc se sobrescreve no lugar; não se acrescenta seção de histórico.
- Interface mostra, não explica: nome curto, ícone, controle, prévia; o porquê vai na dica.
- Pack é dado. A arte, os sons, os temas de app e as fontes moram no pack. A interface não pede para
  baixar nem instalar o que o pack pode trazer.
- Faltou um arquivo (som, tema, fonte, ícone)? Procure na internet uma fonte com licença livre,
  baixe, ponha no pack certo e registre origem, licença e sha256 no `PROCEDENCIA.md` daquela pasta.
- Painel e testes só com HOME temporário (`tests/todos.sh`, `tests/app-completo.py`). Playwright só
  headless. Nunca rode install.sh, `meow compositor`, `meow doctor --consertar` com o HOME real.
  `sudo` escreve no sistema real: nunca chame.
- Uma decisão registrada só muda junto com o código que a lê, no mesmo commit, citando o sim de
  26/10 que está em `ANDAMENTO.md`.
- Commits pequenos em português, por caminho (nunca `git add -A`), sem linha de atribuição. O gancho
  global troca palavras: confira o diff de cada commit. Não faça merge nem push.

## Fechamento de cada sprint
1. Cada item com a prova que o relatório propõe (asserção Playwright ou teste de shell), rodada.
2. `./tests/todos.sh` verde. Pulado não é verde: diga o que pulou e por quê.
3. Escreva `## Execução` no fim da sua sprint: item, commit, prova, o que ficou de fora e por quê.
4. Resposta final: branch, commits, resultado do `todos.sh`, pendências.

## Arquivos de mais de uma sprint
`app/servidor.py`, `app/pagina/app.js`, `app/pagina/index.html` e `app/pagina/estilo.css` são
tocados por várias. Mexa só nas funções e blocos da sua sprint; não reformate, não reordene, não
renomeie nada que não é seu. O coordenador junta as seis numa branch de integração.

## Nome da conta
`<conta>` nas sprints é a conta do GitHub da casa. O gancho global redige esse nome em todo arquivo
do repo, menos `LICENSE`, `AUTHORS`, `CONTRIBUTORS` e arquivos `.toml/.json/.yaml/.ini/.cfg`. Leia o
nome de `git remote get-url origin`. Em código e docs, a URL vem de um dado (`.toml`) lido em tempo
de execução; nunca escreva o nome à mão num `.md`, `.sh`, `.py` ou `.js`.

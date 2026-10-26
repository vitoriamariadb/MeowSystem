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

## A maquete manda (aprovada por quem usa em 26/10)
A tela de cada sprint já está desenhada e aprovada em `maquete/`: `maquete/a/` (moldura, Tema,
Definir, Manter) e `maquete/b/` (Personalizar, Extensões). Abra as páginas com `file://` e leia o
`CONTRATO.md` de cada pasta. A sua sprint copia a marcação, as classes e o CSS da maquete para
`app/pagina/` e liga o comportamento de verdade; não redesenha. Onde o relatório e a maquete
divergem, vale a maquete. Onde a maquete não cobre, siga o estilo dela.
- Não vai para o painel: o seletor `.maquete-ctl`, os estados por URL, `demo.js`, `maquete.js`, as
  classes `.so-*`/`.fora-*` (no painel quem decide é o servidor), os jogos de exemplo de Programas, o
  registro de compilação ilustrativo e as `variantes/spotify-*.svg` (o gerador real sai de `scripts/`).
- CSS: a P110 traz `maquete/a/estilo.css` para `app/pagina/estilo.css` (a moldura e o Definir). As
  outras não editam o miolo dele: cada uma põe o CSS das suas telas num arquivo próprio em
  `app/pagina/` (P111 `manter.css` e `tema.css`, P112 `oficina.css`, P113 `sons.css`, P114
  `extensoes.css`), tirado de `maquete/a/estilo.css` ou de `maquete/b/estilo-b.css`, e o liga com uma
  linha `<link>` no `index.html`.
- Prova extra: uma captura da sua tela no painel ao lado da mesma tela da maquete, nas larguras da
  P110, guardadas em `capturas/pNNN/`.

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
A conta do GitHub da casa é `vitoriamariadb` (`git remote get-url origin`). O gancho global deixa o
nome passar neste repositório; o e-mail continua redigido. Confira o diff de cada commit procurando
`[REDACTED]`.

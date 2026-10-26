# B0 — o repositório lido por IA sem gastar token

Pedido de 26/10: nenhum arquivo traz seção de comentário; informação errada é sobrescrita no lugar,
nunca acrescentada; o que ficou velho sai do dev. Um gancho corrige sozinho, outro mantém o README.

## Respostas de quem usa (26/10)
- Comentário: zero em todo código (bash, Python, Rust, JS, CSS, HTML). Ficam shebang, cabeçalho de
  licença e a docstring que vira `--help`. A prova é `scripts/comentarios.py impressao`: código idêntico.
- Teste, script e documento ultrapassado saem do dev para a branch `arquivo`.
- `docs/sprints/` e `docs/historico/` vão para a `arquivo`; no dev ficam a leva em curso e um registro
  de decisões enxuto (o que vale hoje, uma linha por decisão).
- README: regera texto que vem do código e prints headless (HOME temporário) no merge para o dev e
  no push; nunca em cada commit.
- A decisão 3 do GSD («o seletor mostra o acervo de todos os packs») caiu: ícone de um pack não
  aparece no outro. A troca da linha e do teste vai junto com o código, na sprint dos ícones.

## Fora do corte
`patches/` e `*.patch`, `packs/*/icones/`, `assets/**/upstream/`, SVG, LICENSE, arquivos de dado de
terceiros. Arquivo `.map`/`.conf` lido por programa: só sai o comentário que o leitor ignora (provar).

## Etapas (um agente cada, em sequência, na worktree `../MeowSystem-b0`, branch `limpeza/b0`)
1. Opus, implementa: `comentarios.py zerar` com a mesma garantia de impressão; passa no repo todo;
   `scripts/higiene.sh` passa a zerar o comentário das linhas novas em vez de barrar; AGENTS.md e
   GSD.md trocam a regra de comentário. Suíte verde.
2. Opus, implementa: arquivamento (o que nenhum `todos.sh`, `install.sh`, `bin/meow`, `app/` ou
   systemd alcança), registro de decisões enxuto, `tests/decisoes.sh` apontando para ele, manuais em
   `docs/` sobrescritos e curtos, gancho do README com prints. Suíte verde.
3. Opus, confere e corrige: impressão de todo arquivo tocado, suíte inteira, nada que o dev usa
   foi para o arquivo, README regerado bate com o código.

## Cuidado
A worktree não leva arquivo fora do git. `app/pagina/previas-sistema.js` e `previas-tela.js` estão
fora do git e o painel os carrega: decidir na etapa 1 se entram no git (provável) antes de qualquer
teste de navegador na worktree.

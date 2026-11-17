# Andamento do bloco A (soberana) — 16/11/2026

- P204: feita na branch `bloco/soberana`. Nenhum controle se desliga com dica de porquê; o gesto liga o modo, roda o
  pré-requisito ou solta a margem; o que já está feito não aparece. Decisão 57 em `docs/DECISOES.md`.
- Provas: `tests/app.sh`, `tests/app-uso-real.py`, `tests/glossario.sh`, `tests/decisoes.sh`, `tests/soberana-pagina.py`.
- Conferente: a regra valia só no `app.js`; ela chegou às outras páginas. O que pede um passo antes faz o passo no
  mesmo gesto (tema novo sem guardar: o clique guarda e segue); o que não tem efeito some em vez de apagar (Usar sem
  desenho, Gerar Sons sem nome, botões de build e de extensão durante um trabalho, Liberar sem nada, Desfazer sem
  histórico, desenho travado do acervo, tema de fábrica fora do checkout); contraste baixo não trava mais saída. O
  `tests/soberana-pagina.py` passa em todas as páginas e é gate de merge (`SEM_PULO`).
- P210 (sim de 16/11, «clique destrava»): o item travado aparece normal e o clique destrava e aplica. Lista
  `icones-destravados.list` ao lado do `meow.conf`, que o servidor e os passos de ícone respeitam; PNG feito à
  mão vira `.svg` nos enviados; o ícone de sistema herdado ganha desenho próprio por nome no tema em edição; o
  tema de fábrica fora do checkout vem para a casa de temas no primeiro gesto que escreve. Provas:
  `tests/destrava.sh`, `tests/soberana-pagina.py`, `tests/personalizar-pagina.py`, `tests/criar-e-aprimorar.py`.
- P205 saiu deste bloco (a causa das áreas é do compositor).
- Próximo passo: integração do bloco na árvore de integração.

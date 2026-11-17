# Andamento do bloco A (soberana) — 16/11/2026

- P204: feita na branch `bloco/soberana`. Nenhum controle se desliga com dica de porquê; o gesto liga o modo, roda o
  pré-requisito ou solta a margem; o que já está feito não aparece. Decisão 57 em `docs/DECISOES.md`.
- Provas: `tests/app.sh`, `tests/app-uso-real.py`, `tests/glossario.sh`, `tests/decisoes.sh`, `tests/soberana-pagina.py`.
- Conferente: a regra valia só no `app.js`; ela chegou às outras páginas. O que pede um passo antes faz o passo no
  mesmo gesto (tema novo sem guardar: o clique guarda e segue); o que não tem efeito some em vez de apagar (Usar sem
  desenho, Gerar Sons sem nome, botões de build e de extensão durante um trabalho, Liberar sem nada, Desfazer sem
  histórico, desenho travado do acervo, tema de fábrica fora do checkout); contraste baixo não trava mais saída. O
  `tests/soberana-pagina.py` passa em todas as páginas e é gate de merge (`SEM_PULO`).
- P205 saiu deste bloco (a causa das áreas é do compositor).
- Próximo passo: integração do bloco na árvore de integração.

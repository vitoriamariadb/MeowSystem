# P79 — A casa real fica coerente com o pack no ar; nada manda digitar

**Branch:** `sprint/p79` (a partir de `integracao/leva-g`) · **Fontes:** `04-integracao-onda-2.md`
(«Aberto» 2, 3, 4, 5), achados das specs P77 e P78, `02-decisoes.md` (9, 10, 11).

## Tarefas
1. **Decisão 9** — extensão do VS Code só de pack versionado no repositório; pack importado mostra
   e instala só por gesto explícito.
2. **Decisão 10** — «Restaurar ao padrão» grava `item.padrao`; nasce só quando difere.
3. **Decisão 11** — caixa do sudo em uma linha, porquê na dica.
4. **Casa real**: o doctor corrige (não avisa) `ICONES_FLAVOR="macchiato"` com o Dracula no ar;
   trocar de pack leva junto `CURSOR` e `ICONES_PASTAS` (o pack decide, o usuário pode fixar);
   `CosmicBackground` apontando para pasta é acusado e corrigido.
5. **Nada manda digitar**: as saídas com `pkill`, `sudo -v && ./install.sh`, `meow files-menu build`
   viram a ação feita (ou o botão que a faz, no painel).
6. **Achados técnicos**: mapa CRLF não perde linhas; `_proibido` vê BOM antes do `#!`;
   `vidro_janela.py` respeita `MEOW_COSMIC_DIR`; `LOGO_MODO=""` usa o modo que vale
   (`_modo_do_gato`) na moldura; gesto de favoritar papel de parede (a aba «Favoritos» existe);
   «Créditos» do gate deixa de ser intermitente.

## Prova
- teste por item, vermelho antes e verde depois; `tests/todos.sh` inteiro verde com HOME temporário.
- a casa real só em leitura: `meow doctor` da worktree (sem `--consertar`) aponta os três itens
  do 4 como o que ele vai corrigir, e nada mais.

# P98 — O painel novo de verdade, com tudo o que o antigo fazia

**Pedido de quem usa (23/10):** «temos que migrar tudo da interface antiga, mas modificando pro novo painel
que ficou incrível». O desenho é o mockup final da P97 (`docs/design/2026-10-23/final/`, e o `LEIA-ME.md`
com o mapa das páginas de hoje para as novas).

## A forma
- As 4 portas do mockup: **Tema, Criar tema, Ajustes, Cuidar**. Dia e noite fica dentro de Ajustes.
- **Clicar num tema já veste a máquina** e pede a senha na hora (decisão de 23/10).
- Os ajustes que o mockup deixou fora da tela entram num **«Mais ajustes» recolhido** no fim de cada página.
- Show, don't tell: uma frase curta, o porquê atrás do `?`, nenhum nome de máquina na tela.

## Nada se perde
Cada chave do esquema do painel de hoje e cada uma das ações tem um lugar no painel novo. A prova é uma
tabela gerada a partir do código (chave ou ação, página antiga, página nova) que fica em
`docs/design/2026-10-23/migracao.md`, com zero linhas sem destino. O `tests/app-completo.py` (o gate de
merge: toda aba, todo controle) e os outros `tests/app-*.py` passam a percorrer o painel novo.

## Criar tema
Entra o fluxo do mockup (Cores, Ícones, Papel de parede, Sons, Mandar), gravando um pack no formato de
três pastas planas em `~/.local/share/meowsystem/packs/`. O que o motor já sabe fazer (`pack.py`) é usado;
se algum passo precisar de motor novo grande demais, ele vira tarefa registrada, sem fingir na tela.

## Limites
- A P96 (reorganização) roda em paralelo e muda caminhos no `app/servidor.py` (gatos → mascote, temas de
  apps, papéis de parede). Esta sprint mexe no front (`app/pagina/`) e só ACRESCENTA rota no servidor
  quando precisar; não mexe em caminho de arquivo. Na tela, «Gato» vira «Mascote» (decisão da P96).
- Painel só com HOME temporário, PID próprio, nunca `--parar` (GSD).

## Como se prova
`tests/todos.sh` inteiro verde duas vezes; os `tests/app-*.py` no painel novo; prints em 1829x1029 de
todas as telas nos dois packs, comparados com o mockup, guardados FORA do repositório.

# P97 — A interface nova do MeowSystem

**Pedido de quem usa (23/10):** «a interface do novo MeowSystem tá super bagunçada». Três Opus: dois
investigam o repositório, abrem o painel em tela maximizada e criam mockups; um terceiro melhora, corrige e
escolhe o melhor de cada um. Tem que ser **fácil de entender, bonita, fácil de criar um tema próprio sendo
só designer, e fácil de recomendar**.

## Entrega
Mockup final em HTML estático (abre no navegador) em `docs/design/2026-10-23/`, com os prints do painel de
hoje ao lado, para quem usa escolher o que sobe. Nada do painel de verdade muda nesta sprint.

## Regras que valem
- `hallmark` primeiro (regra 6 do CLAUDE.md global).
- Show, don't tell: uma frase curta na tela, o porquê atrás do `?` (GSD, princípio 2).
- Painel só com HOME temporário e PID próprio, nunca `--parar` (GSD, decisão 8).

## Entregue (23/10)
Mockup final em `docs/design/2026-10-23/final/` (16 telas, 4 portas: Tema, Criar tema, Ajustes, Cuidar),
publicado para quem usa ver. O `LEIA-ME.md` ao lado diz o que veio do mockup A, do B e da síntese.

## Decisões de quem usa sobre o mockup (23/10)
1. **Clicar num tema já veste a máquina**, e pede a senha na hora (não há «Aplicar» separado para tema).
2. Os ajustes avançados (faixa «Fundo», ícones resgatados, cor da marca, pastas XDG) ficam num
   **«Mais ajustes» recolhido** no fim de cada página.
3. **Dia e noite fica dentro de Ajustes**: são 4 portas.

## Próximo
A P98 implementa o painel novo, depois que a P96 (reorganização) entrar no dev, porque ela muda os caminhos
que o painel lê.

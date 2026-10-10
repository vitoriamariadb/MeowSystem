# P80 — Acabamento do uso real final (10/10)

**Branch:** `sprint/p80` (a partir de `integracao/leva-g` depois da P79) · **Fonte:** meu uso real
final, como usuário, na integração (prints em `.playwright-mcp/ux-final/`).

## O que vi
1. **Ficha de ícone — nomes técnicos cortados** (`05`, `06`): `net.waterfo…`, `org.gnome.…`,
   `005-potion`. Cura: rótulo amigável (nome do app pelo comentário do `apps.map` ou pelo `.desktop`;
   descrição pt-BR do `catalog.json` para a biblioteca), nome inteiro e origem só na dica.
2. **Ficha de ícone — a paleta «COR» aparece sempre** e só vale para desenho de traço. Cura: a
   paleta nasce quando um traço está selecionado (show, don't tell).
3. **Ficha de ícone — PNG feito à mão aparece apagado** com um selo de sentido obscuro (`06`). Cura:
   se pode usar, aparece normal; se não pode naquele app, o porquê na dica e o selo é o mesmo da
   trava das outras pastas.
4. **Dia e noite** (`07`): «O tema claro termina/começa» usa deslizante pontilhado («como está: 18»)
   enquanto as outras duas linhas usam seletor de hora, e a ordem é invertida (termina à esquerda).
   Cura: o mesmo seletor de hora e a mesma ordem (começa | termina) nas três linhas.
5. **Cabeçalho de página inconsistente**: a fileira «Fundo» (Escuro / Vidro escuro / Vidro claro /
   Claro) aparece em Ícones, Cor e tela, Logo, Papel de parede e some em Dia e noite e outras. Cura:
   uma regra só (ou em toda página, ou só em uma, a de Cor e tela).

## Prova
- prints antes/depois de cada item em `.playwright-mcp/ux-p80/`; `tests/app-uso-real.py` ganha um
  caso por item (vermelho antes, verde depois); suíte inteira verde.

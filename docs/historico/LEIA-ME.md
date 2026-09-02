# Histórico — de onde este projeto veio

Nada aqui é executado nem lido por script nenhum. São os documentos que deram
origem ao MeowSystem, guardados porque explicam **decisões que o código não
justifica sozinho**.

| arquivo | o que é |
|---|---|
| `especificacao-original.md` | o relatório que serviu de especificação (§2 paleta, §4 como o COSMIC se veste, §8 o inventário da máquina). Boa parte já foi superada pelo que se mediu depois — quando os dois discordarem, [`docs/COSMIC-THEMING.md`](../COSMIC-THEMING.md) vence, porque lá cada afirmação tem data e método |
| `estilo-escuro-original.ron` | o tema que a Vitória tinha montado à mão antes do projeto. É a origem da estrutura preservada — raio 8, gaps (0,5), `active_hint` 4, `frosted` VeryLow2 e o `alpha_map` de 14 chaves — que hoje vive em `assets/paleta/cosmic-map.json` sob `estrutura_preservada`. O projeto trocou a paleta e não tocou na estrutura: isto aqui é a prova de qual era qual |

## O que foi removido, e por quê

Saíram do repositório em 05/08/2026, junto da decisão de publicar:

- **`ESPECIFICACAO-DE-PARTIDA.md`** — o documento de arranque, escrito antes da
  primeira linha de código. Cumpriu o papel; manter um documento de arranque no
  repositório só confunde quem chega.
- **`meowsystem-inventario-20260804-1252.md`** (188 KB) — o inventário da
  máquina. É **regenerável** a qualquer momento por
  `scripts/coleta-meowsystem.sh`, e um inventário congelado envelhece mal:
  daqui a um mês descreve uma máquina que não existe mais.
- **`docs/spec-visual/`** — exportação de uma ferramenta de design, sem
  referência em lugar nenhum do código.
- **`uploads/`** — capturas coladas durante as conversas.

Tudo continua no histórico do git. `git log --diff-filter=D --name-only` acha,
e `git show <commit>^:<caminho>` traz de volta.

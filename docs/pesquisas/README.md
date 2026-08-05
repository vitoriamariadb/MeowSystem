# Pesquisas — o material bruto, para não se perder

Cada arquivo aqui é o retorno **íntegro** de uma investigação multi-frente: o
diagnóstico, as evidências com comando e saída, e as refutações adversariais que
tentaram derrubar cada conclusão. Nada foi resumido nem editado.

Está versionado por um motivo prático: uma investigação destas custa horas de
máquina, e a conclusão que sobrevive costuma valer menos do que **o caminho até
ela** — inclusive as hipóteses que morreram. Quando alguém reabrir um destes
assuntos daqui a meses, a pergunta vai ser "isso já foi medido?", e a resposta
precisa estar em algum lugar que não seja uma conversa perdida.

| Arquivo | O que investigou |
|---|---|
| `2026-08-05-bugs-icones-portabilidade.json` | O painel que sumiu, o F11 que sai do fullscreen, o vidro ao maximizar; ícones Catppuccin, rotação de logos, portabilidade |
| `2026-08-05-svg-dock-e-greeter.json` | Por que um SVG de editor não renderiza no dock; o que falta para a tela de login |

## Como ler

São JSON. Para achar o que interessa sem abrir 280 KB no editor:

```bash
# os diagnósticos, com título e confiança
python3 -c "
import json;d=json.load(open('docs/pesquisas/2026-08-05-bugs-icones-portabilidade.json'))
for x in d['result']['diagnosticos']:
    print(x['bug'], '->', x['diagnostico']['titulo'])"
```

A estrutura é `result.diagnosticos[]` (cada um com `diagnostico` e
`refutacoes[]`), `result.pesquisas[]` e `result.sintese`.

## O que estes arquivos NÃO são

Não são verdade estabelecida. O que passou no crivo e virou fato medido está em
[`docs/COSMIC-THEMING.md`](../COSMIC-THEMING.md), com data e método; o que virou
trabalho está em [`docs/sprints/`](../sprints/). Aqui fica o rascunho, com os
erros dentro — inclusive uma atribuição minha que era correlação lida como causa,
e que a refutação derrubou.

# P137 — as pendências se resolvem sozinhas e não aparecem

Anotada em 28/10, com a captura do Manter («2 pendências»: QBittorrent com Trocar/Manter, e «Install.sh»). Ela: «o
que são as pendências? Por que não se aplicam automaticamente tudo, e por que aparecem na tela? Não deveria
aparecer». Vale a decisão 7 do `docs/DECISOES.md` («O doctor não tem que avisar nada. Tem que corrigir.»).

## O que se mediu (`~/.local/state/meowsystem/pendencias.tsv`)
- `qbittorrent-tema-de-terceiro`: o qBittorrent (flatpak) voltou ao `dracula.qbtheme`. A troca de 28/10 de madrugada
  (decisão dela: o tema do pack vence) foi desfeita pelo `aurora-qbittorrent-config.sh` da Aurora, que o self-heal
  roda e que põe Dracula de fábrica (`/usr/local/bin/aurora-qbittorrent-config.sh:57`). O doctor já o acusa como
  vizinho duplicado. O módulo do qBittorrent só pergunta, não troca.
- `tema-sem-captura` (rótulo «Install.sh» na tela, que é o nome do script): o pack pessoal `meu-meow-portatil`
  (feito no Personalizar, `FLAVOR="meumeowportatil"`) não tem captura do COSMIC, e o `derivar_acento.py` diz «o pack
  no ar não tem o flavor 'meumeowportatil'». O tema do COSMIC dela não foi aplicado às 18:06.
- A porta Manter mostra o cartão «Pendências» com botões de decisão, contra a decisão 7.

## Cura na origem
- qBittorrent: o corte da Aurora (`scripts/vizinhos.sh`, contrato `assets/contratos/vizinhos.tsv`) tira o tema do
  `aurora-qbittorrent-config.sh` (o resto da config dele fica com a Aurora), e o módulo
  `scripts/temas-de-apps/qbittorrent/` aplica o tema do pack sozinho quando o app está em `APPS_ATIVOS`, guardando o
  tema de antes para o «Tema de antes».
- Pack pessoal sem captura: o pack feito no Personalizar herda a captura do pack de onde nasceu (o `meowsystem`, ou
  o que estiver em `pack.json`) e o tema do COSMIC se deriva dela com a paleta nova (`derivar_flavor.py` /
  `derivar_acento.py`), claro e escuro. Aplicar um pack pessoal nunca deixa o COSMIC sem tema.
- Pendência deixa de ser coisa da tela: o que o doctor sabe consertar, conserta (no install, no doctor e no
  agendamento); o que não sabe vai para o registro. O cartão «Pendências» e o «N pendências» do Manter saem; o
  rótulo nunca é nome de script.

## Prova
- Teste: um `aurora-qbittorrent-config.sh` falso que grava Dracula; depois do doctor, o qBittorrent está no tema do
  pack e a segunda passada não escreve.
- Teste: um pack pessoal feito pelo mesmo caminho do Personalizar ganha tema do COSMIC claro e escuro, sem pendência.
- Teste de navegador (HOME temporário): o Manter sem cartão de pendências.
- Na máquina dela, depois do install: `pendencias.tsv` vazio, qBittorrent no tema do pack, o COSMIC no
  «Meu Meow-Portátil».

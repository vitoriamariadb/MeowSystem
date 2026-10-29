# P139 — o pack pessoal perde o PACK e o install não fecha

Anotada em 29/10, no install final da leva (HOME real, `rc=2`).

## O que se mediu
- `meow.log`, 28/10 18:06:40: `pack usar meu-meow-portatil flavor=meumeowportatil` (o pack feito no Personalizar a
  partir de um CSV). Nenhum outro `pack usar` depois.
- 29/10 02:42, no início do install: o `meow.conf` diz `PACK="meowsystem"` e `FLAVOR="meumeowportatil"`. O
  `pack-do-install` grava `meowsystem	mocha`. O backup `fecho-2026-10-28` (antes do pack pessoal) dizia `PACK=""` e
  `FLAVOR="mocha"`. Alguma coisa entre 18:06 de 28/10 e 02:42 de 29/10 gravou `PACK="meowsystem"` e deixou o
  `FLAVOR` do pack pessoal.
- Com esse par, `pack.adocao("meowsystem", "meumeowportatil")` adota o `meowsystem`, que não tem o flavor. Daí:
  `erro pack recusado: nenhuma paleta da cadeia tem o flavor 'meumeowportatil'`, as pastas caem no `cat-mocha-mauve`, os
  applets no `mocha`.
- `scripts/icones_mimetypes.sh` com `FLAVOR_ICONES` vazio sai com rc=1 sem dizer nada (a substituição
  `DONO_ACERVO="$( [ -n "$ORIGEM" ] && …)"` falha sob `set -e`). O install lê rc=1 como «mexeu» em toda passada e
  fecha com `erro as mesmas etapas escreveram em duas passagens seguidas: mimetypes` (`rc=2`).

## Cura na origem
1. Achar quem grava `PACK` sem `FLAVOR` (ou com o pack errado) e curar lá. Candidatos a olhar: toda gravação de
   chave do painel (`app/servidor.py`, inclusive as rotas novas da P134/P138: interruptor da Modificações,
   `LOGO_PROGRAMA`, «Adicionar tema»), `migrar_conf.py`, `pack remover` (18:13, `meu-tema`), o doctor e o
   agendamento. A troca de pack é sempre o par PACK+FLAVOR, junto.
2. Par incoerente no `meow.conf` (o FLAVOR não existe na cadeia do PACK, mas existe num pack instalado) é coisa que o
   doctor conserta sozinho (decisão 7): adota o pack dono do flavor, ou o flavor padrão do PACK, conforme o que a
   pessoa escolheu por último (o `meow.log` diz). Nenhuma saída manda digitar.
3. `icones_mimetypes.sh` nunca sai calado com 1: com flavor vazio, cai no flavor padrão do pack no ar, como as
   pastas já fazem, e a segunda passada não escreve.

## Prova
- Teste que reproduz o caminho que gravou `PACK="meowsystem"` (HOME temporário) e fica verde depois da cura.
- Teste: `meow.conf` com o par incoerente; o doctor deixa o par coerente; a segunda passada não escreve.
- Teste: `icones_mimetypes.sh` com `FLAVOR_ICONES` vazio sai 0 e a segunda vez não escreve.
- Na máquina dela, depois do install: `rc=0`, pastas e applets no flavor `meumeowportatil`.

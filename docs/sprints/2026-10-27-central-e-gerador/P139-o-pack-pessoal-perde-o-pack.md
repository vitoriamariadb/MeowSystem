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
- 29/10, `meow pack usar meu-meow-portatil` na máquina dela (`pack-usar.out`, `rc=2`): o Spotify diz «o color.ini nao
  tem a secao [meumeowportatil]» e `erro não consegui pôr o acento mauve no color.ini do tema 'catppuccin'`, e o
  install fecha com `erro falhou: apps` em toda passada. O tema `catppuccin` é herdado do `meowsystem` e só tem as
  seções dos flavors dele.
- No mesmo `pack usar`, o passo «o tema do COSMIC primeiro» imprime `ERRO: captura 'meumeowportatil-mauve' não
  existe…` e «o tema do COSMIC não troca», e o install logo abaixo deriva a captura sem problema (linha 17).

## A causa, provada
- 28/10 18:48:41, o painel roda `meow pack usar meowsystem` (restauro `restauros/…-pack_usar-…`: antes dele o par era
  `meu-meow-portatil`/`meumeowportatil`). O disco estava cheio desde 18:47 (ENOSPC do build de cargo da P136; o
  `/home` chegou a 0 bytes).
- O `pack usar` gravava o par em duas escritas (`conf_definir PACK`, depois `conf_definir FLAVOR`). A do PACK passou,
  a do FLAVOR falhou, e o comando saiu com erro antes do `registrar` e sem desfazer a primeira: `PACK="meowsystem"`
  com o FLAVOR do pack pessoal, nenhuma linha no `meow.log`, nenhum install. É o estado medido às 02:42.
- Reproduzido no HOME temporário com um `mv` que falha na segunda escrita do `meow.conf` (`tests/par-do-pack.sh`, 1).
- O painel tinha o mesmo defeito por outro caminho: o cartão PACK (ou FLAVOR) sozinho no `/api/salvar` e no
  `/api/definir` gravava uma chave do par sem a outra.

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
4. Spotify com pack pessoal: o flavor que só a paleta pessoal tem ganha a seção dele no `color.ini` herdado, derivada
   da paleta do pack (a seção de fundo mais perto, trocada slot a slot, como o tema do COSMIC é derivado). Nunca
   falha: sem seção de onde derivar, fica no tema que já tem. Os outros temas herdados que leem um flavor (qBittorrent,
   Discord, btop/bat) não podem falhar num flavor que só a paleta pessoal tem.
5. O «tema do COSMIC primeiro» do `pack usar` com pack pessoal deriva a captura (como a etapa `tema` do install) ou
   fica quieto. Nunca imprime ERRO do que o install resolve logo abaixo.

## Prova
- Teste que reproduz o caminho que gravou `PACK="meowsystem"` (HOME temporário) e fica verde depois da cura.
- Teste: `meow.conf` com o par incoerente; o doctor deixa o par coerente; a segunda passada não escreve.
- Teste: `icones_mimetypes.sh` com `FLAVOR_ICONES` vazio sai 0 e a segunda vez não escreve.
- Teste: com o Spotify e o pack pessoal, o `color.ini` ganha a seção do flavor com o acento, sem erro, e a segunda
  passada não reescreve; um tema sem seção de onde derivar sai 3, não erro.
- Teste: `meow pack usar` do pack pessoal sem captura imprime o tema aplicado, sem ERRO e sem «não troca».
- Na máquina dela, depois do install: `rc=0`, pastas e applets no flavor `meumeowportatil`, Spotify sem falha, nenhum
  ERRO no `pack usar`.

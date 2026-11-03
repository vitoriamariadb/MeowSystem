# P154 — o compositor em qualquer PC (03/11/2026)

Ela, 03/11: «as builds que geramos do Pop OS: o nosso sistema está funcionando e funcionará em qualquer PC?»
Auditoria só de leitura, sem escrever no sistema: nesta máquina o build está são; em outro PC os casos
comuns (sem Rust, sem deb-src, versão nova, patch que não entra, sem rede, outra GPU) caem com segurança no
cosmic-comp de fábrica, e o greeter nunca passa pelo shim. Os furos são os de baixo.

## O que se mediu

Provado com sonda (versão e pastas falsas, no scratchpad):

1. Binário do build que cai na partida (rc=139): o 1º e o 2º login caem, só o 3º marca `ruim` e vai para a fábrica.
2. Pasta do build sem escrita: `compositor_shim.sh:37` falha ao gravar `quedas`, o contador nunca sobe, e a queda
   se repete em todo login.
3. Duas sessões curtas normais (saída 0, abaixo da janela de 30 s) marcam `ruim`: o shim não separa sair de cair.
   Com `ruim`, o conserto do doctor (`bin/meow:1284`) não faz nada, e a sessão perde os patches até a próxima
   versão do cosmic-comp.
4. Um `estado` com um `req … presente` e outro `ausente` já basta para o shim usar o build (`compositor_shim.sh:15`,
   `garantir_builds.sh:32`).

Lido no código:

5. Patch que entra só com fuzz `-F1` (degrau 2) vai para a sessão sem revisão (`compositor_patches.sh:420-446`), e a
   guarda só cobre os 30 primeiros segundos (`compositor_shim.sh:43`): uma queda aos 5 min, ou tela preta com o
   processo vivo, nunca marca `ruim`.
6. Sem conferência de espaço antes do build (~3,3 GB); a falha deixa o `target/` (`compositor_patches.sh:696-699`).
7. Compilação que falha não entra na matriz (só `:692` e `:737` gravam): cada login e o doctor das 05:00 recompilam.
8. Login cujo shell não põe `~/.local/bin` no PATH ignora o shim calado, e o `conferir` repete «vale no próximo
   login» para sempre (`compositor_patches.sh:220-231`).

## A cura na origem

- Shim: se a escrita de `quedas` falha, usa a fábrica; exige que nenhum `req` esteja `ausente`.
- Antes de instalar o build: teste de fumaça (`--version` e `ldd` sem `not found`), e a impressão digital das
  bibliotecas no `estado`, para o doctor recompilar quando ela muda.
- Build de degrau 2 fica guardado, sem ir para o shim, até um sim; a queda conta também depois da janela
  (coredump do build ou fim de sessão anormal no journal).
- `ruim`: o conserto do doctor apaga a marca e devolve o build depois do teste de fumaça.
- `cmd_compilar` confere o espaço livre (`df`) e limpa o `target/` na falha; a falha de compilação entra na
  matriz, amarrada à versão e à série, com espera crescente entre tentativas.
- `conferir` lê o PATH em `/proc/<cosmic-session>/environ` e diz quando o login não passa pelo shim.

## Como se prova

Um `tests/compositor-shim.sh` estendido com os quatro casos provados (binário que cai, pasta sem escrita, saída
curta normal, `req` ausente) e o teste de fumaça; `tests/etapa-compositor.sh` com degrau 2 retido e falha de
compilação na matriz; suíte inteira verde; na máquina, `meow compositor conferir` e um login.

## A fábrica alterada

9. O `/usr/bin/cosmic-comp` desta máquina não bate com o md5sums do dpkg: o `aurora-night-light.py` trocou o shader
   em 27/10 (a chamada dele no self-heal da Aurora já está comentada pelo «vizinhos»; é sobra). Esse binário é o do
   greeter e a «fábrica» do shim, e nada no MeowSystem confere isso.

Cura: o doctor ganha a conferência da fábrica contra o md5sums do dpkg, e o conserto devolve pelo verbo
`cosmic-comp-de-fabrica` da ponte (já existe, usado por `cmd_reverter`); sem ponte, pendência. Nesta máquina a
fábrica foi devolvida pela ponte em 03/11.

## Decisões da implementação

- Item 5, o «sim» do degrau 2: o build entra na casa com um arquivo `retido` (os patches de degrau 2 com base
  real de contexto). O shim pula o retido, o estado diz `retido`, o cartão diz «Em observação» e o `conferir`
  sai 4. O sim é o «Instalar» de Extensões, que chama `compositor_patches.sh liberar` (o gesto em fundo do
  install e o «Refazer» não liberam). O `liberado` guarda a lista aprovada: o rebuild com o mesmo degrau 2 não
  fica retido de novo.
- A queda depois da janela vem do journal e do coredumpctl: `terminated with signal` (menos o 15) ou `exited
  with error` do cosmic-comp, atribuído ao último `_EXE` da mesma rodada; sem `_EXE` conhecido conta contra o
  build. Tela preta com o processo vivo não tem como ser vista daqui.
- Item 3, o `ruim`: o `cuidar` do doctor perdoa uma vez por build (`perdoado`), só com o teste de fumaça bom e
  um journal legível sem queda. Fora isso o build fica de lado como `caiu`, com o «precisa de gente»
  `compositor-caiu`, e o `conferir` sai 3 com aviso.
- Item 7, a espera: a falha grava `falhou=N@epoch` na linha da versão na matriz; a série mais nova que a
  matriz zera a contagem (a mesma regra do degrau 4). Espera de 1 h, dobrando, até 7 dias.
- Item 4: o shim exige nenhum `req` ausente; o `garantir_builds.sh` não refaz o build com `req` ausente,
  porque a mesma série sairia igual (o teste «patch-que-sobe» guarda isso), e o `compilar` já não instala um
  build assim.
- A impressão digital das bibliotecas é a linha `bibliotecas=` no `estado`; o `estado` antigo sem ela segue
  valendo.
- Item 8: o `conferir` só fala do PATH quando o shim é mais velho que a sessão; o shim novo vale no próximo
  login, como antes.
- Item 9: a pendência sem ponte é `cosmic-comp-de-fabrica`, resolvida no painel pelo «instalar».

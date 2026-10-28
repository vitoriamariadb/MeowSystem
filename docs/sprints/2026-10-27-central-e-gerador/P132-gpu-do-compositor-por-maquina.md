# P132 — a GPU do compositor detectada em cada máquina

Anotada em 28/10 (ela: «Pensa num produto universal. Pra ser usado em outras máquinas no meu caso é a 4060 aí
reapontamos pra lá»).

## O que se mediu
- A decisão 6 (`docs/DECISOES.md:14`) crava `COSMIC_RENDER_DEVICE="0x10de:0x25a2"` no `/etc/environment`, e o
  `tests/decisoes.sh:129-137` cobra esse ID literal. Esta máquina (`Meow-portatil`) tem a Intel `8086:a720` (i915,
  `card0`, com o `eDP-1`) e a RTX 4060 `10de:28a0` (nvidia, `card1`, com a TV no `HDMI-A-2`). O `25a2` não existe aqui.
- O `/etc/environment` de hoje não tem a linha. O `aurora-gpu-compositor` que a decisão cita como guardião também não
  existe nesta máquina. Ninguém grava a linha.
- O cosmic-comp (`src/backend/kms/mod.rs:245`, `src/utils/env.rs:59`) aceita `0x<vendor>:0x<device>` e, se nenhum
  render node bate, volta em silêncio à escolha padrão (a GPU da tela embutida). Um ID errado não acusa nada.

## Cura na origem
- Chave nova no `meow.conf`: `GPU_COMPOSITOR="dedicada"` (fábrica) ou `"padrao"` (não toca, e tira a linha que o
  MeowSystem gravou). Decidido pelo coordenador: a fábrica é `dedicada`, porque a decisão 6 é «o compositor na placa
  dedicada», e numa máquina de uma GPU só não muda nada.
- A detecção é uma só, lida de `/sys/bus/pci/devices/*` (classe `0x0300xx`/`0x0302xx`, com render node em `drm/`).
  Com uma GPU só, não há linha. Com mais de uma, vence a de `boot_vga` 0, e entre elas a NVIDIA (`0x10de`). O valor
  sai no formato do cosmic-comp: `0x10de:0x28a0`.
- Dois verbos novos na ponte root, sem argumento como todos: `gpu-compositor`, que detecta dentro da ponte e grava ou
  troca só a linha `COSMIC_RENDER_DEVICE=` do `/etc/environment` (cópia do original antes da primeira escrita, e
  `exit 0` sem escrita quando já está certo), e `gpu-compositor-tirar`. Os dois entram na regra do sudo e no `ajuda`.
- Etapa no install e conferência no doctor (`gpu`): divergente quando a linha não bate com a detecção; o conserto
  passa pela ponte. A saída diz que vale no próximo login, sem mandar digitar nada.
- `restaurar`/desinstalar tira a linha pelo verbo `-tirar`.
- A D6 do `tests/decisoes.sh` cobra a linha igual à detecção da máquina, não um ID literal; numa máquina de uma
  GPU, cobra a ausência. A linha 6 do `docs/DECISOES.md` se reescreve no lugar (a dedicada detectada, a chave, o
  sim de 28/10).

## Prova
- Teste com um `/sys` e um `/etc/environment` de brinquedo (a ponte e a detecção leem as raízes de variáveis que
  só o teste põe): híbrida Intel+NVIDIA grava `0x10de:0x28a0`; uma GPU só não grava; a segunda passada não escreve;
  trocar a placa troca a linha sem mexer nas outras do arquivo; `-tirar` devolve o arquivo byte a byte; `padrao`
  tira a linha.
- `./tests/todos.sh` verde; `tests/decisoes.sh` com a D6 nova.
- Na máquina dela, depois do install: `grep COSMIC_RENDER_DEVICE /etc/environment` dá `0x10de:0x28a0`; no próximo
  login o `meow doctor` dá `gpu` ok.

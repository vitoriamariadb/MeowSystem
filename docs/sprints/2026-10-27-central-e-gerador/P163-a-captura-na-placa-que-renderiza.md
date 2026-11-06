# P163 — a captura na placa que renderiza (06/11/2026)

Segunda etapa da cura na origem da P159. Pedido de 06/11/2026: «Como podemos resolver o problema na origem da forma certa?
e usando a gpu?» Só depois de a P159 estar no ar com o SHM forçado fora.

## Alcance

Produto: vale para todo notebook híbrido sob a decisão 6, em que o painel interno fica na integrada e o compositor na
dedicada. PC de uma GPU só não muda de comportamento.

## O que se mediu

Na captura do eDP-1, o compositor oferece o `renderD128` (AMD) com 8 modifiers `0x02…` e LINEAR. O Chrome está na NVIDIA,
com `0x03…` e LINEAR. `target_node_for_output` (`src/backend/kms/mod.rs:729`) escolhe a GPU ligada à tela, e o Chrome recebe
a placa dedicada no `--render-node-override`. O formato comum é só o LINEAR, e o relato do PR #385 é que o Chrome não importa
LINEAR de outra GPU: a cópia acaba passando pela CPU.

A leitura vem de uma sonda avulsa do `ext_image_copy_capture`, sem capturar quadro: `~/.local/src/sonda_copia.py`, só no
nitro-5. Vale trazê-la para `scripts/`, ao lado da `appid_sonda.py`.

## O que falta medir

1. Depois da P159: se o Chrome importa o LINEAR aqui ou renegocia para SHM.
2. Captura de janela: a sonda só mediu `constraints_for_output`. Ler `constraints_for_toplevel` e medir uma janela do Chrome.
3. Monitor HDMI, ligado na NVIDIA: se ali a negociação já é rica.
4. Custo real: CPU do compartilhamento em SHM contra dmabuf, com tela cheia a 30 fps. Sem ganho medido, a sprint encerra.

## A cura proposta

Patch no `cosmic-comp`: `constraints_for_output` e o render do `image_copy_capture` usam a placa que renderiza, em vez da placa
ligada à tela, quando as duas diferem. Entra na série do compositor da sessão; a tela de login usa `/usr/bin/cosmic-comp` e não recebe o patch.

## Como se prova

1. A sonda de captura mostra modifiers `0x03…` no eDP-1, e `pw-dump` mostra o stream com `modifier` e dmabuf, não SHM.
2. Compartilhar por 30 minutos sem queda, com CPU menor que a medida em SHM.
3. Em PC de uma GPU só, a negociação não muda.

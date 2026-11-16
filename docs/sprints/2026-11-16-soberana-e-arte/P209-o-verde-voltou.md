# P209 — o artefato verde voltou (16/11/2026)

Texto de quem usa: «outra parada o artefato verde voltou a aparecer na tela. Tem algo que ficou quebrado. preciso que
investigue isso use o askpass».

## O que se mediu (16/11, nitro-5, `sudo -A journalctl`)
- Mesma assinatura da faixa verde de 09/10: `cosmic-comp: Failed to render texture …, import for wrong devices
  DrmNode { dev: 57985 (renderD129 = NVIDIA 10de:25a2) }`, buffers com modifier NVIDIA (`0x03…606012`/`606014`), e uma vez
  `Error importing dmabuf from renderD129 to renderD128` (para a AMD, que liga o eDP).
- Tamanhos: 53–153 × 28 (botões e applets da barra, altura 28) e 1920 × 1080 (janela/tela cheia).
- Por boot no diário: 10/11 → 30, 13/11 → 60, 16/11 → 23. O diário só guarda 3 boots.
- `COSMIC_RENDER_DEVICE=0x10de:0x25a2` está no ambiente do compositor (decisão 6 de pé); o ec674cd ainda lê a variável
  (`src/backend/kms/mod.rs:245`). Applets sem variável de GPU no ambiente.
- Upstream `render_node_for_output` (`src/backend/kms/surface/mod.rs:1492`): o eDP (AMD) troca o nó de render para a
  NVIDIA quando a janela ativa vem da NVIDIA; textura de cliente que só foi importada para o outro nó falha → quadro sem
  ela (o verde).

## Falta medir
- Em que tela e em que gesto o verde aparece (foto de quem usa).
- Se começou com o build de 07/11 (`app-id-do-cliente` e `nomes-nas-duas-telas` entraram nele) ou com o cosmic-comp
  ec674cd: comparar com o build 8cb1802 (marcado `ruim` em 05/11) e com o binário do pacote.

## A cura
A definir depois da medição. Nunca propor o compositor de volta na AMD (decisão 6).

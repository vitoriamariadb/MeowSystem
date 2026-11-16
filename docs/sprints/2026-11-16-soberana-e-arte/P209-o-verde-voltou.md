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

## A queda de 20:44 (mesma sessão)
- 20:44:41 `amdgpu 0000:75:00.0: [gfxhub] page fault … Process cosmic-comp pid 4174 thread cosmic-com:cs0`, `Faulty UTCL2
  client ID: TCP (0x8)`, `PERMISSION_FAULTS: 0x3` — o mesmo quadro da queda de 17/09 que a `blur-cache-textura` atacou.
- 20:44:44 coredump: SIGABRT na thread 4209 (radeonsi, `libgallium 26.1.6`); a thread 4206 estava em
  `smithay::backend::renderer::gles::GlesRenderer::cleanup` (addr2line) dentro do `libnvidia-eglcore`. Morreram junto
  cosmic-osd, cosmic-files-applet e o portal (`graficos`). O compositor voltou às 20:44:46 (PID 2194550).
- Mesa sem mudança desde 11/09; é a única queda do compositor nos coredumps guardados. Upstream: pop-os/cosmic-comp#2843
  (RTX 4050 + Radeon 680M, SIGABRT em libgallium 26.1.6).
- O SIGTERM da barra às 20:35:05 é o rodízio do mascote («Trocar sozinho»), não o gatilho.

## Hipótese de cura (a provar)
O verde e a queda passam pelo mesmo caminho: o eDP é da AMD, e `render_node_for_output` faz a AMD COMPOR o quadro do eDP
quando a área não tem janela da NVIDIA (área vazia, só a barra) — aí ela tenta usar texturas de cliente feitas na
NVIDIA (modifier `0x03…`) e falha («import for wrong devices», o verde), e todo trabalho de render da AMD é exposição
ao page fault. Patch `req` novo: com `COSMIC_RENDER_DEVICE` definido, o eDP é composto sempre no nó primário (RTX); a AMD
só recebe o quadro pronto. Prova: zero «import for wrong devices» numa sessão de horas com as duas telas, e nenhuma
queda. Nunca o compositor de volta na AMD (decisão 6).

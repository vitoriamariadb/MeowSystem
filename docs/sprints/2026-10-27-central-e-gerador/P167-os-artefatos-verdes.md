# P167 — os artefatos verdes na tela (06/11/2026)

Relato de 06/11/2026: artefatos e tremores verdes com o modo gráfico em NVIDIA no nitro-5. Depois do boot das 16:21 a tela
parece normal. Pop!_OS com GNOME tinha sintoma parecido, curado à mão na época. Sprint de diagnóstico: nada muda no sistema
antes de uma prova separar as causas.

## O que se mediu

- O modo NVIDIA está ativo (`system76-power graphics` = `nvidia`, placa ligada), mas a tela não passa pela NVIDIA: `eDP-1`
  está em `card0` (amdgpu) e `card1` (nvidia) só tem `HDMI-A-1`. O Meow-portatil é igual: `eDP-1` no i915, `HDMI-A-2` na NVIDIA.
- O compositor renderiza na RTX 3050 (`COSMIC_RENDER_DEVICE=0x10de:0x25a2`, decisão 6) e entrega o quadro à AMD para o painel.
- `Failed to render texture … import for wrong devices`, em quase tudo no nó da NVIDIA (`dev: 57985`):

| boot | kernel | falhas | duração |
| --- | --- | --- | --- |
| 03/11 17:20 | 7.2.6 | 143 | 31 h |
| 05/11 00:20 | 7.2.6 | 115 | 34 h |
| 06/11 10:31 | 7.2.6 | 75 | 5,5 h |
| 06/11 16:21 | 7.2.15 | 3 nos primeiros 13 min | em curso |

- `amdgpu ring gfx_0.1.0 timeout` com `Process cosmic-comp` às 00:18:17 e 00:43:13 de 05/11, seguido de `SIGABRT` do compositor
  em `libgallium` 26.1.6, nos mesmos segundos. É a queda que marcou o build 8cb1802 como `ruim` na P164. Houve timeouts também em 03/11.
- 0 Xid da NVIDIA nos últimos 8 boots. Driver 580.178.04 carregado no kernel 7.2.15.
- PSR desligado e efetivo (`amdgpu.dcdebugmask=0x10`, «Driver support: no»). Panel Replay não existe neste painel.
- Agora: eDP a 60 Hz e HDMI a 60 Hz, sem VRR. `outputs.ron` guarda o eDP sozinho a 144 Hz com VRR ligado, faixa 48–144.

## O que ainda não se sabe

1. Em qual tela aparece o verde: isso separa o caminho entre as placas (só o eDP), a NVIDIA ou o cabo (só o HDMI) e o render (as duas).
2. Se apareceu com o eDP a 144 Hz com VRR.
3. O kernel 7.2.15 tem 15 min de uso: não prova nada, e a taxa de `import for wrong devices` não caiu.

Em 06/11 quem usa disse: o verde apareceu só na tela do note (`eDP-1`, amdgpu). A saída HDMI da NVIDIA fica fora de suspeita; seguem o VRR a 144 Hz, o travamento do anel da amdgpu e o import entre as placas. Com as telas a 60 Hz sem VRR, se o verde não voltar, o VRR passa à frente.

## Causas candidatas, por ordem

1. Caminho entre placas: o quadro da NVIDIA chega à AMD, e o import falha.
2. amdgpu: reset do anel gfx na AMD enquanto a NVIDIA renderiza.
3. VRR a 144 Hz no eDP.

## Como se prova

1. Registrar tela, Hz e horário a cada episódio e cruzar com o journal.
2. Com o sim de quem usa, uma sessão de teste com o compositor na AMD (decisão 6): sem verde, o caminho entre placas é a causa.
3. Se a causa for de fora do Meow, relatório com a reprodução, no alvo certo (kernel, Mesa ou `cosmic-comp`).

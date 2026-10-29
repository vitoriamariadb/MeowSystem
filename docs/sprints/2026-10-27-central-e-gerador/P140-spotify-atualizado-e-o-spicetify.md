# P140 — o Spotify atualiza e o spicetify para de aplicar, calado

Anotada em 29/10, no install final da leva (HOME real).

## O que se mediu
- Passagem 1: `erro o 'spicetify apply' falhou — o Spotify segue com o tema de antes`, com o aviso do spicetify
  v2.46.4: «Preprocessed Spotify data is outdated. Please run "spicetify restore backup apply"».
- Passagem 2: `ok Spotify já está em catppuccin/meumeowportatil, do pack meowsystem — nada a fazer`, e o install fecha
  com `rc=0`. A conferência lê o `config-xpui.ini`, não o Spotify aplicado: diz que está certo o que não foi aplicado.

## Cura na origem
- O módulo `scripts/temas-de-apps/spotify/` reconhece o Spotify atualizado (o aviso «outdated», ou o backup de outra
  versão) e refaz sozinho o `spicetify backup apply` / `restore backup apply` (decisão 7: o doctor corrige).
- A conferência confere o tema aplicado no Spotify, não só a config; com o apply falhado, ela não diz «nada a fazer».

## Prova
- Teste com um `spicetify` falso que responde «outdated» no primeiro apply: o módulo refaz o backup e aplica; a
  segunda passada não escreve; com o apply falhando de verdade, a conferência sai divergente, não ok.
- Na máquina dela: o Spotify aberto com o tema do pack.

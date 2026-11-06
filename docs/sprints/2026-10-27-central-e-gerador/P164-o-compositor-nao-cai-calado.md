# P164 — o compositor não cai calado na fábrica (06/11/2026)

Decisão de 06/11/2026: «Liberar sozinho». Revê a retenção do degrau 2 da P154, com sim explícito.

## Alcance

Produto: acontece em todo PC a cada apt do `cosmic-comp` cujo patch entre com o contexto mudado.

## O que se mediu

- 05/11: o build 8cb1802 foi marcado `ruim` depois de quedas por abort em `libgallium`, fora do código dos patches. O shim não
  distingue a causa.
- 06/11: o apt trouxe o ec674cd. O `garantir_builds` compilou sozinho, com os 5 marcadores, mas `sem-workspace-vazio` e
  `menu-clique-curto` entraram no degrau 2, e o build ficou `retido` esperando o «Instalar» da página Extensões.
- Resultado: a sessão rodou com o binário de fábrica, 0 marcadores `AURORA-*`, sem Modo de Leitura e com o «5» da P161, sem
  nada dizer por quê. Só o aviso do applet de leitura apontava o sintoma.

## A cura

1. Build com todos os `req` e marcadores presentes e teste de fumaça bom entra no próximo login sem clique. A rede continua
   sendo o shim: duas quedas curtas e volta à fábrica.
2. Registrar o `-F1` no estado, para o doctor saber que o patch entrou com contexto mudado.
3. Avaliar se queda fora do código dos patches, como a de `libgallium`, deve consumir o `ruim`: o build de 05/11 saiu de cena
   por um defeito que a fábrica também tem (quedas em 29/10 e 03/11).

Reescrever o trecho da P154 e as entradas de `patches/LEIA-ME.txt` e `tests/etapa-compositor.sh` que cobram a retenção.

## Como se prova

1. Simular apt com degrau 2 em HOME temporário: o build entra sem `liberar`, e o shim o escolhe.
2. Build que cai duas vezes no início volta à fábrica.
3. `meow doctor` conserta sozinho quando a sessão está em binário diferente do esperado, sem mandar digitar.

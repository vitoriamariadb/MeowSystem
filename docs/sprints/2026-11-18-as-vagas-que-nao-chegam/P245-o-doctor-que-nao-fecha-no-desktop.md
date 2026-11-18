# P245 — o doctor das 5h não fecha no desktop (18/11/2026)

## O que se mediu (coordenador, 18/11, por SSH, só leitura)
- Log do desktop: `2026-11-18T05:07:31 doctor --consertar mexeu=1 falhou=0 restou=1`. No portátil, no mesmo dia,
  `restou=0`.
- `meow doctor` no desktop sai 1, com três linhas `~~`:
  - `logo`: «nenhum applet de logo do painel instalado — o mascote do dock e o do terminal seguem», e mesmo assim
    «mudaria …/scalable/apps/com.system76.CosmicPanelAppButton.svg» e «…/com.system76.CosmicAppLibrary.svg».
  - `lancador`: «o mimeinfo.cache do home é mais velho que um lançador».
  - `janeladock`: «0 a criar, 0 a atualizar, 2 a remover (de 2)». A mesma saída diz, para as duas pontes do Boxy SVG,
    «o alvo não está instalado — fica como está» e «removeria a ponte»: duas frases opostas para o mesmo item.
- `janeladock` aparece igual no portátil. Nos dois a conferência rodou por SSH e diz «sem sessão Wayland utilizável»;
  falta medir dentro da sessão para saber se a divergência é do SSH.
- nitro-5: doctor sai 0.

## A causa
Não medida. Três hipóteses a provar em teste, uma por linha: o `logo` confere um arquivo que o conserto não escreve
quando não há applet de logo; o `lancador` não refaz o `mimeinfo.cache` depois de escrever o `.desktop`; o
`janeladock` decide «fica» e «remove» em dois pontos do `scripts/janelas.sh` sem a mesma regra.

## A cura na origem
Reproduzir cada linha num teste com HOME temporário (o estado do desktop copiado como dado de teste), achar quem
escreve e quem confere, e pôr os dois na mesma regra. O doctor termina com `restou=0` na segunda passada.

## Como se prova
Teste novo por linha, vermelho antes e verde depois. `tests/doctor-veredito.sh`, `tests/convergencia.sh`,
`tests/janela-sem-app-id.sh`, `tests/lancador-do-meow.sh` e `tests/logo-do-programa.sh` verdes. No desktop, o log das
5h do dia seguinte com `restou=0`.

## Nos três PCs
Desktop: resolve. Portátil: resolve o `janeladock`, se a medição na sessão o confirmar. nitro-5: sem efeito.

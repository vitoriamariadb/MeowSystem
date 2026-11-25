# P296: a tabela de apps que não repete a conferência

## O que se mediu (25/11, MeowSystem)
`meow apps` dizia «Spotify pendente» e a frase «Programas instalados com tema pendente: Spotify». Na mesma hora,
`meow apps aplicar spotify` dizia «já está em catppuccin/mocha, nada a fazer» e o doctor, «nada divergente».

## A causa
A ação `tabela` do `scripts/aplicar_apps.sh` troca o `MEOW_ESTADO` por uma pasta temporária, para a leitura não
escrever no estado de verdade, e levava para lá só o `temas-mantidos.tsv`. A conferência do Spotify lê a assinatura em
`$MEOW_ESTADO/temas-de-apps/spotify/aplicado`; na pasta temporária ela não existe, e a conferência sai divergente.

## A cura
A cópia do estado leva também a pasta `temas-de-apps/`, que é o que as conferências leem.

## Como se prova
- `tests/spotify-atualizado.sh`: «a tabela do meow apps diz aplicado para o que a conferência fechou em 0, sem
  escrever». Vermelho antes, verde depois.
- `meow apps` no MeowSystem: Spotify «aplicado».

# P199 — o Restaurar volta o drop-in do Arquivos

## O que se mediu
`tests/restaurar.sh pack_usar` vermelho desde 07/11: o «Restaurar» não voltou
`~/.config/systemd/user/app-com.system76.CosmicFiles@.service.d/meowsystem-filhos-sobrevivem.conf`.

## Causa
O passo `scripts/arquivos_filhos.sh` (a56ec133) escreve o drop-in sem `meow_guardar_antes`,
então o caminho não entra no `tocados.tsv` e o «Restaurar» não sabe que ele nasceu.

## Cura na origem
`meow_guardar_antes "$DROPIN"` antes de escrever.

## Como se prova
`bash tests/restaurar.sh pack_usar` e `bash tests/arquivos-filhos.sh` verdes; a suíte inteira sem vermelho.

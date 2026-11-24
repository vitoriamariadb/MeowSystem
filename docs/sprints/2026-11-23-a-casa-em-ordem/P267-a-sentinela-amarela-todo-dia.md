# P267 — a sentinela sai amarela todo dia por dois avisos que não avisam (23/11/2026)

## O que se mediu (nitro-5, 23/11)
- `sentinela.sh … resultado=amarelo` para a fila do apt (`cosmic-comp …6968c5d`, `cosmic-files …84a32e1`,
  `cosmic-settings …aff6c10`). Os 9 patches do compositor e o do menu entram limpos (`-F0`) no candidato.
- Amarelo 1: `toolchain … cosmic-comp pede rust 1.95 e o rustc é 1.95.0: no limite`. O fonte traz
  `rust-toolchain.toml` com `channel = "1.95"`; dentro da árvore o `rustc` é sempre o que o fonte pina. O `rustc` da
  máquina é 1.99.1.
- Amarelo 2: `revisao … cosmic-applets instalado é o 779f920; scripts/appid_dock.sh foi medido no 40248fb … confira
  o comentário`. O `appid_dock.sh` não tem esse comentário (zero comentário), e a linha `revisao` de
  `assets/contratos/cosmic.tsv` parou no `40248fb`.
- Amarelo 3: `tema … theme.rs mudou entre c003a58 e dd108aa … o oráculo refaz`. Este é informação verdadeira.

## A causa
`scripts/cosmic_prever.sh:163` mede o `rustc` de dentro da árvore; com `rust-toolchain` no fonte, a versão medida é
a pedida, e `:174` chama isso de «no limite» para sempre. `:233` manda conferir um comentário que a regra do
repositório apagou, e nada atualiza a linha do contrato quando a dock é medida de novo.

## A cura na origem
- Com `rust-toolchain` na árvore, o veredito é verde («o fonte pina o toolchain, e o rustup o tem ou o baixa»). O
  «no limite» fica para o fonte sem pino, medido contra o `rustc` da máquina.
- Medir o `appid_dock.sh` no `779f920` pelo palco (`scripts/palco.sh`), atualizar a linha `revisao` do contrato, e a
  frase passa a dizer o que medir de novo, sem citar comentário.

## Como se prova
- Teste do `cosmic_prever.sh` com duas árvores de mentira (com e sem `rust-toolchain.toml`) e com o contrato na
  revisão instalada e numa antiga.
- No nitro-5: `meow cosmic prever` com a fila de hoje sai com um amarelo só, o do `theme.rs`.

## Nos três PCs
Vale nos três; a fila do apt de cada um é a dele.

## Feito (23/11, bloco `install-ruido`)
- Com `rust-toolchain` ou `rust-toolchain.toml` no fonte, o veredito do toolchain é verde; «no limite» ficou só para
  fonte sem pino. A frase da revisão não manda mais conferir comentário. Prova: `tests/cosmic-prever.sh`, com duas
  árvores de mentira; com a mudança desfeita, duas falhas.

## Falta
- A linha `revisao cosmic-applets 40248fb` do `assets/contratos/cosmic.tsv`: o clone do `cosmic-applets` não está em
  `~/.local/share/meowsystem/fontes/` do nitro-5. Com o fonte no `779f920`, rodar `scripts/appid_dock.sh --conferir`
  pelo palco e, se der verde, trocar a revisão.
- No nitro-5, depois do install: `meow cosmic prever` com um amarelo só (o do `theme.rs`).

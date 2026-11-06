# P168 — a faxina dos papéis de parede (06/11/2026)

Achados de 04/11, no fecho da P157. Produto: vale para todo PC com papel banido.

## O que se mediu

- Uma banida sobrou: `Cyberpunk Neon Cat Wallpaper …`, com dois emojis no nome. O `limpar_banidos` e o `banir` pulam nomes fora do ASCII.
- Num checkout, o lixo põe no `BANIDOS.txt.padrao` até foto de quem usa, que o `semear` nunca baixa.
- Cópias em `banidos/` fora do `BANIDOS.txt` nunca saem.
- O `BANIDOS.txt.padrao` tem lixo (`.meow.XXXXXX`, linha vazia), e o `FONTES.tsv` lista nomes já banidos.

## A cura

1. `limpar_banidos` e `banir` tratam o nome como bytes: emoji, acento e espaço casam.
2. O padrão só recebe nome que está no `FONTES.tsv`.
3. O que está em `banidos/` e não está no `BANIDOS.txt` sai.
4. Limpar o `BANIDOS.txt.padrao` e tirar do `FONTES.tsv` o que está banido.

## Como se prova

Teste em HOME temporário com nome com emoji; a segunda passada não escreve nada.

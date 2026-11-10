# P198 — o Espaço diz o que apaga (10/11/2026)

Foto `fotos/5-espaco-liberar.png`. Texto: «o que significa liberar? Só pelo nome do botão?»

## O que se mediu

1. `espaco.js:48`: botão «Liberar · 11,2 GB · ~18 min» roda `espaco_liberar` (`servidor.py:3717`): apaga a
   compilação dos applets, o cache do compositor e resíduos, tudo que o MeowSystem recria sozinho. Os 18 min são
   o tempo de recompilar.
2. Só a dica de hover explica. O bloco se chama «Reconstruível».

## A cura na origem

- Nome do glossário (P184; semente: «Apagar arquivos recriáveis»), com o tamanho ao lado; o «~18 min» vira
  «recompila em ~18 min», ou sai se não couber com clareza.
- Bloco «Reconstruível» renomeado igual.

## Como se prova

- Gate do navegador: o rótulo novo; o número igual ao total do bloco.

Tamanho: 30 min, depois da P184.

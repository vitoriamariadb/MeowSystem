# P197 — Builds só com builds (10/11/2026)

Foto `fotos/6-builds-e-applets.png`. Texto: «builds e applets aparecendo juntos na mesma tela.»

## O que se mediu

1. `blocoDeBuilds()` (`extensoes.js:214-242`): além dos cartões da casa (Compositor, Menu do Arquivos,
   Aprimoramentos gráficos), monta uma linha por applet (`filter(ehApplet)`: Tocando agora, Bandeja, Ajustes
   rápidos, Modo de leitura…), com versão, commit e `~/.local`.
2. A aba Applets já mostra os mesmos applets.

## A cura na origem

- A aba Builds mostra só os builds da casa. Estado de compilação de applet (Em dia, Falhou, Compilar) mora no
  cartão do applet, na aba Applets.
- Commit, hash e `~/.local` saem da tela (decisão de 23/10: sem caminho nem hash).

## Como se prova

- Gate do navegador: aba Builds sem `[data-extensao]` de applet; aba Applets com o estado e o gesto de compilar.

Tamanho: 1 a 2 h.

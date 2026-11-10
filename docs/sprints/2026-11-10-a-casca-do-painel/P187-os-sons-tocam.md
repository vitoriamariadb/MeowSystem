# P187 — os sons tocam (10/11/2026)

Texto de quem usa: «a parte dos sons não funciona e clicar em ouvir inclusive não executa, abre um pop up que não
faz sentido.»

## O que se mediu

1. «Ouvir o instalado» (`lugares.js:61`) é uma AÇÃO do servidor (`som_ouvir`, `servidor.py:3659`): roda
   `som.sh ouvir` → `pw-play` no processo do servidor e abre a janela de resultado. Por isso o pop-up.
2. O play de cada linha (`ouvirSom`, `paginas.js:657`) toca no navegador pelo `/som?pack=&evento=`. Um `curl` sem
   a credencial da página recebe 403 (esperado); com a página, não medido.
3. Hipóteses do silêncio: o `pw-play` do servidor sem o `PIPEWIRE_RUNTIME_DIR`/`XDG_RUNTIME_DIR` da sessão; o
   `/som` recusando a página; o evento sem arquivo no pack.

## A cura na origem

- Ouvir é do navegador, sempre: o som instalado vem por URL e toca com `Audio`, como as linhas. A ação `som_ouvir`
  sai da tela (fica no CLI).
- Cada play mostra estado (tocando/parado) no próprio botão; erro vira aviso curto.
- O pop-up some aqui e no painel inteiro pela P189.

## Como se prova

- Teste do servidor: `/som` com a credencial da página devolve `audio/ogg` para cada evento do pack.
- Gate do navegador: clicar em Ouvir não abre diálogo; o `<audio>` termina com `ended`.
- Quem usa ouve na sessão real (lista de conferência à mão).

Tamanho: 1 a 2 h.

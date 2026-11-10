# P190 — o topo sem contagem, com Recarregar o painel (10/11/2026)

Texto de quem usa: «remove a contagem de mudanças no botão superior», «recarregar o painel coloca no lugar de
contagem de mudanças do header», «remove o botão de crédito dos 3 pontinhos e o "esta tela num arquivo"».
Sim de 10/11: «painel» é a barra do COSMIC.

## O que se mediu

1. `atualizarAplicar()` (`app.js:1201-1211`) escreve «N mudanças» em `#conta` e enche `#ultimas`
   (`index.html:42`) com a lista de mudanças.
2. O menu «…» monta Créditos e «Esta tela num arquivo» em `app.js:1352-1355`; `LUGAR_TOPO` em `lugares.js:362-363`.
3. «Reiniciar o painel» existe como `extensao_reiniciar_painel`, só dentro de Extensões.

## A cura na origem

- `#conta` e `#ultimas` saem. No lugar, o botão do glossário para reiniciar a barra do COSMIC
  (`extensao_reiniciar_painel`), com ícone; progresso pela linha da P189.
- Desfazer continua na barra.
- Créditos e «Esta tela num arquivo» saem do menu e do `LUGAR_TOPO`; o código que só eles usam sai junto.
  Se o menu ficar vazio, o «…» sai.

## Como se prova

- Gate do navegador: header sem número; clicar reinicia o painel (servidor falso registra a ação).
- Grep: `menu:creditos`, `menu:pagina`, `#ultimas` sem uso.

Tamanho: 1 a 2 h. Depende da P189.

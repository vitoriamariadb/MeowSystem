# P157 — papel de parede: sem Favoritas, sem Levar, lixo apaga de vez

Pedido dela, 04/11/2026, e respostas no AskUserQuestion do mesmo dia.

## O que se mediu

- `app/pagina/oficina.js` `GRUPOS_PAREDE`: No carrossel, Noite, Dia, **Favoritas**, **Fora**. A estrela
  (`wallpaper_favoritar`/`desfavoritar`) só copia para `favoritos/`, e ela tem 0 favoritas.
- O botão «Levar para o tema» (`levar:foto`) só aparece no assistente (`passoPapel` em `paginas.js`).
- O lixo é `wallpaper_banir` (`app/servidor.py`): move para `banidos/` e anota em `BANIDOS.txt`. Hoje
  `banidos/` tem 258 imagens.
- No repositório, `packs/meowsystem/wallpapers/FONTES.tsv` (47 linhas, a receita do `semear`) e
  `BANIDOS.txt.padrao` (o que o `semear` nunca repõe).

## A cura

1. Tirar a aba Favoritas, a estrela e os verbos `favoritar`/`desfavoritar` (painel, servidor, `wallpaper.sh`,
   `meow`, ajuda, testes). A pasta `favoritos/` vazia sai pelo doctor.
2. Tirar o botão «Levar para o tema» e o parâmetro `leva` de `montarGaleria`.
3. O lixo **apaga de vez**: pergunta uma vez («Apagar <nome>?»), tira a imagem de `ativos*/`, `originais/`
   e de onde mais ela tiver link, e anota em `BANIDOS.txt`. Quando o painel roda de um checkout git
   (a raiz tem `.git`), também tira a linha dela do `FONTES.tsv` e põe o nome no `BANIDOS.txt.padrao` do
   repositório, sem commit (o commit é de quem fecha o bloco). Sem checkout, só o disco.
4. A aba **Fora some**. As imagens que já estão em `banidos/` (258 hoje) saem do disco por uma etapa do doctor
   ou do `wallpaper aplicar`: idempotente, só apaga o que está no `BANIDOS.txt`. A segunda passada não escreve nada.
   O verbo `wallpaper_desbanir` e a aba saem junto.

## Como se prova

Testes em HOME temporário (`tests/todos.sh`): o lixo apaga dos dois lugares; com raiz-checkout falsa, o
FONTES.tsv perde a linha e o BANIDOS.txt.padrao ganha o nome; sem `.git`, o repositório fica intocado; a etapa
das banidas apaga e a segunda passada fica seca. Teste de navegador: só três abas, nenhum `levar:foto`, nenhuma
estrela. `tests/decisoes.sh` verde.

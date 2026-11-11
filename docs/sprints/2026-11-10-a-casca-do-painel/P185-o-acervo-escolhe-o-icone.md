# P185 — o acervo escolhe o ícone (10/11/2026)

Foto `fotos/1-icones-do-acervo.png`: Personalizar › Ícones › Apps › Arquivos › «Do acervo». Texto: «não consigo
selecionar qual ícone usar se tratando do acervo».

## O que se mediu

1. `oficina.js:177-198`: no modo acervo, o rodapé `desenho-pe` leva `botoes` e `usar`. Na foto o cartão termina
   com uma faixa vazia e nenhum botão de usar à vista; a grade rola dentro de altura fixa.
2. Causa ainda não medida. Hipóteses, nesta ordem: (a) o clique no quadro só pinta a prévia e o «Usar» fica fora da
   área visível ou escondido até haver escolha; (b) o clique não muda a escolha (`escolhida`) e a prévia segue a
   do app; (c) o «Usar» grava, mas o seletor relê o mapa antigo.

## A cura na origem

- Reproduzir no navegador com HOME temporário; descobrir qual das três é.
- Clique num quadro = escolha visível (borda e prévia grande e dock trocam na hora); o botão de confirmar fica
  sempre visível no cartão, com nome que se explica (do glossário, P184).

## Como se prova

- Gate do navegador: abre Arquivos › Do acervo, clica um quadro, confirma; `icones-escolhidos.map` ganha a linha e
  o ícone instalado muda.
- Captura antes e depois.

Tamanho: 1 a 2 h.

## Execução

Causa medida (reproduzida com PACK=dracula em HOME temporário): nenhuma das três hipóteses. No tema Dracula o acervo só
tem desenhos do pack, e para o Arquivos (`com.system76.CosmicFiles`) os 623 vinham travados por «o ícone deste app é de
outro passo do MeowSystem»: o `_donos_do_scalable` lia a lista `RETIRADOS` do `completar_icones.sh` como dono do ícone.
Sem desenho livre não havia «Usar» (só a dica de hover dizia o porquê).

Cura: o `completar_icones.sh` não retira o scalable de quem o pack mapeia ou quem usa escolheu (a decisão 16, «desenho do
pack vence o traço», vale também para os oito); `RETIRADOS` sai do `_donos_do_scalable`; o «Usar» fica sempre no cartão
(desabilitado até haver escolha) e, se tudo estiver travado, o motivo aparece escrito no rodapé.

Prova: `tests/personalizar-pagina.py` (escolhe, usa, mapa e tema instalado), `tests/retirados-do-pack.sh`.

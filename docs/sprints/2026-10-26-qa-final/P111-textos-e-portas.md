# P111 — Personalizar, Definir, Manter; menos texto, menos dobra

Leia `00-leva.md`. Itens: `relatorios/qa-1.md` Q1-09, Q1-11, Q1-12, Q1-15, Q1-16, Q1-17;
`relatorios/qa-2.md` Q2-13, Q2-17; `relatorios/qa-3.md` Q3-04, Q3-05, Q3-06.

## Maquete
`maquete/a/`: as portas e os nomes, o Tema (cartões de pack, variantes, «Criar o meu tema»), o Manter inteiro (cartões, Sozinho, Ícones da máquina, Construídos, Registro, perigo), a régua de Dia e noite com o Modo de leitura e os estados `sem-ponte`/`erro`.

## O que quem usa pediu
- Portas: Tema · Personalizar (era Criar tema) · Definir (era Ajustes) · Manter (era Cuidar) ·
  Extensões (a porta nasce na P114; aqui só reserve o lugar no cabeçalho se a P114 ainda não existe —
  não crie a página).
- Aba Tema: saem «Ver» e «No ar agora»; os temas prontos já estão à vista e vão ao ar dali. «Criar o
  meu» fica «Criar o meu tema».
- «Mais ajustes» some em todo lugar: tudo aparece direto na seção, o raro no fim.
- Manter: sai «Conferir e consertar» do topo. O diálogo «Falta a ponte» oferece «Consertar a ponte»
  (a decisão 11 continua: o caminho sem senha existe).

## Ordem
1. Q1-12 lista onde mora cada texto: troque em html, js, servidor, testes e docs, num commit por porta.
   Os ids internos e as rotas podem ficar; o que a usuária lê muda.
2. Q2-13 e Q1-09: remova a dobra; os itens de máquina de Q1-09 (Trazer .zip, Tema instalado,
   Reconstruir os ícones e afins) vão para Manter; a «Variante dos ícones» volta a funcionar no lugar
   dela. Troque o item 4 de `tests/app-navegador.py` (exigia nascer recolhido) pela prova de que não
   há dobra.
3. Q1-11, Q1-15, Q1-16, Q1-17: aba Tema.
4. Q3-04, Q3-05, Q3-06: Manter; pendência com o nome do assunto, não da ação.
5. Q2-17: o modo de leitura volta como bloco «Modo de leitura» dentro de Dia e noite, com a prévia
   própria que se perdeu.

## Fora desta sprint
Layout (P110), o que grava (P109), a página Extensões (P114).

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

## Execução

Commits (branch `sprint/p111`, um por assunto): `d14bc547` Personalizar, `20112ad3` Definir, `979e1c37`
Manter, `16536b0b` Q3-04, `b66104d8` Q3-06, `7af6eb30` Q1-17, `43298669` Q2-17, `b83785c9` dobra e aba
Tema, `29c238f9` tema.css e manter.css, e o teste do nome digitado em `tests/pack.sh`.

| item | prova rodada |
|---|---|
| Q1-12 | `tests/app.sh` e `tests/migracao-do-painel.py` verdes; nenhuma porta ainda diz Criar tema, Ajustes ou Cuidar na tela; as rotas `#criar`, `#ajustes`, `#cuidar` ficam |
| Q2-13 | `tests/app-navegador.py` item 4 agora prova `details.mais` = 0 nas 14 rotas (38 conferências); `app.sh` prova que nenhum `--onde` diz «Mais ajustes» |
| Q1-09 | Manter ganhou o bloco «Ícones da máquina» (Tema instalado, Desenhos, Logo, Ícones resgatados, Reconstruir os ícones); a sonda no navegador lista as linhas |
| Variante dos ícones | em Personalizar › Ícones os quatro botões nascem com um marcado (Mocha); a causa era `ICONES_FLAVOR` valer o literal `$FLAVOR` |
| Q1-11 | `#tema` sem «No ar agora» e sem botão «Ver» |
| Q1-15, Q1-16 | saíram as ações `status`, `tema`, `tema_aplicar`, `tema_modo` e os provedores que mostravam select com valor falso ou mandavam digitar; `tests/app.sh` e a migração fecham com 63 ações |
| Q1-17 | o botão diz exatamente «Criar o meu tema»; o nome digitado vai em `nome_do_tema` e `tests/pack.sh` prova `"nome": "QA Um"` no `pack.json` |
| Q3-04 | no topo do Manter só «Conferir»; sem a ponte aparece «Consertar a ponte» antes dele; com a ponte, nenhum `doctor_consertar` no topo |
| Q3-05 | o resultado do Conferir oferece `resultado:consertar` quando o rc é 1 (`tests/app-completo.py`) |
| Q3-06 | `NOME_DA_PENDENCIA`: as oito pendências do brinquedo saem com nome de assunto, distintas, até três palavras (`tests/app.sh` 12c) |
| Q2-17 | bloco «Modo de leitura» em Dia e noite, com régua própria e prévia que esquenta e ganha textura de papel mesmo com a agenda desligada (`.quente` com opacidade 0,28); a busca por «leitura» acha 2 opções |

Capturas do painel ao lado da maquete em `capturas/p111/` (ignorado pelo git, por ser PNG), em 1920x1080,
1550x860, 1500x900 e 1280x800: Tema, Manter e Dia e noite. Sem transbordo horizontal e sem erro de JS nas
doze. O painel bate com a maquete nos blocos e nos textos.

Decisões desta sprint:
- «Abrir um tema» e a pílula de saúde ficam na aba Tema: a maquete os mantém.
- O bloco «Construídos» fica para a P114, que mexe nos applets.
- `Restaurar`, o único item que sobrou do antigo «Mais ajustes», foi para a lista de perigo do Manter.
- `tema.css` leva só a textura `.previa .papel`; `manter.css` leva o cartão de ação, a pílula de alerta e as
  pendências. O standalone embute os dois com `<style>` próprio.
- `mesa.js` foi tocado só para a camada `.papel`, de modo a não colidir com a P110.

Deixado de fora, e por quê:
- A porta Extensões no cabeçalho: nasce na P114.
- O rótulo curto das variantes no cartão do pack («Latte» em vez de «Catppuccin Latte»), a ordem dos cartões
  (o tema em uso primeiro) e «Pela hora» no lugar de «Automático»: são layout e texto da P110.
- O alinhamento de Q3-03 e os Créditos de Q3-09: pertencem a outras sprints.

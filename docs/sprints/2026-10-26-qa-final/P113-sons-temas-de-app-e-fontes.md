# P113 — o pack traz sons, tema do Spotify e fonte; a interface não pede download

Leia `00-leva.md`. Itens: `relatorios/qa-1.md` Q1-03, Q1-04, Q1-13, Q1-18 e a pesquisa de sons do
Pop!_OS/COSMIC (seção de sons do Q1-04); `relatorios/qa-2.md` Q2-14, Q2-15, Q2-16.

## O que quem usa pediu
- Sons separados por pack; ela quer ver a lista dos sons do sistema (quando toca cada um) e trocar
  cada um pelo do pack. O gerador do sino do volume tem que funcionar.
- O tema do Spotify mora no pack meowsystem e aplica em definitivo, sem botão «Baixar».
- Fonte do terminal e tudo que a interface pede para instalar: o pack traz. No máximo, um «Trazer
  .zip», como no cursor.
- «Escondidos» do lançador sugere os apps instalados enquanto ela digita.
- A etapa Mandar do Personalizar não fica vazia.

## Decisões que valem (ANDAMENTO.md)
- Cada pack traz os seus sons; o MeowSystem ganha sons próprios (procure sons com licença livre que
  combinem com o tema, registre em PROCEDENCIA.md). `SOM_*` do meow.conf deixa de vencer o pack
  (vira ajuste por cima, só se ela mexer).
- Sons do carregador e da bateria: o COSMIC lê `/usr/share/sounds/Pop` cravado; troque pela ponte
  root (nunca sudo direto) e o vigia pós-apt repõe. A decisão 37 («sons só na notificação») cai:
  troque a linha no mesmo commit.
- Fonte do terminal vendorada no pack (JetBrainsMono Nerd Font Mono), sem seletor novo; o install
  para de baixar.
- O «Instalar» da extensão do VS Code de pack importado FICA (decisão 9).

## Ordem
1. Q1-03: um sino só. A prévia do navegador, o controle e o «Regravar» usam os mesmos números; o
   «Regravar» lê o valor que está na barra (com a P109, já gravado).
2. Q1-04: `sons/` dentro de cada pack com manifesto (evento → arquivo); página Sons do Personalizar
   lista cada som do sistema com nome legível, quando toca, ouvir e trocar.
3. Q2-15: tema do Spotify dentro de `packs/meowsystem/temas-de-apps/` (como o Dracula já faz),
   aplicado pelo doctor; some o botão.
4. Q2-16: cada ponto da lista vira dado do pack ou some; o starship sai da interface (decisão 26
   de `docs/DECISOES.md` já o põe no install; tire dela a metade do doctor).
5. Q2-14: «Escondidos» com sugestão dos apps de `/api/apps` ao digitar; só aceita app que existe.
6. Q1-13 e Q1-18: Mandar mostra o resumo do tema e as saídas desde o primeiro passo; o rascunho
   mora no servidor, não só no navegador.

## Fora desta sprint
Ícones (P112), layout (P110).

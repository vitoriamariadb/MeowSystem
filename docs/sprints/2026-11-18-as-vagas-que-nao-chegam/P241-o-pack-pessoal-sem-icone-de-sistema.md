# P241 — o pack pessoal não recebe nenhum ícone de sistema (18/11/2026)

Espera o sim de quem usa: o comportamento de hoje é guardado por teste como intenção.

## O que se mediu (coordenador, 18/11, por SSH, só leitura)
- Desktop (`PACK="meu-tema"`) e portátil (`PACK="meu-meow-portatil"`): `find -L ~/.local/share/icons/MeowSystem-Icons
  -name '*-symbolic.svg'` dá **0**. Não há `window-close-symbolic`, `network-wired-symbolic`,
  `cosmic-applet-battery-level-100-symbolic` nem `soneca-desperto-symbolic`.
- O tema de lá herda `Papirus-Dark,breeze-dark,Cosmic,Adwaita,hicolor`: a barra e os botões da janela são os do
  Papirus e do COSMIC.
- `meow doctor` nos dois: «sistema  o pack no ar não declara icones.sistema — nada a aplicar».
- O `pack.json` dos dois tem `heranca: "meowsystem"` e, em `icones`, só `autorais` e `apps`. A pasta `icones/sistema/`
  existe, vazia.
- No nitro-5 (`PACK="dracula"`, que declara `icones.sistema`) a linha `sistema` confere, e o tema tem 346 `*-symbolic.svg`.

## A causa
`icones_de_status` (`scripts/pack.py:1068`) só sobe por `icones.<bloco>.herda`, nunca por `heranca`. O criador
(`#novo`) não escreve `icones.sistema` nem `icones.sistema.herda` no pack que gera. O `tests/pack.sh:2779` fixa isso
como intenção: «a herança por heranca não traz o desenho do outro pack» (decisão 3).

O efeito bate com as decisões 14 («o acervo do motor é o pack-base `meowsystem`, que todo pack herda») e 59 (os
botões da janela são vagas do pack e aparecem no criador): no pack pessoal a vaga aparece no criador, mas o desenho
herdado nunca chega ao tema instalado.

## A cura na origem (recomendada, espera o sim)
1. O criador escreve `icones.sistema.herda` (e `icones.bandeja.herda`, quando o pai tem) apontando para o pack de
   `heranca`. É o mesmo campo que o Dracula já usa em `icones.mimetypes.herda`.
2. O desenho que o pack pessoal tem em `icones/sistema/` vence o herdado, nome a nome (decisão 57: o clique troca o
   ícone de sistema herdado).
3. Pack pessoal que já existe: o doctor escreve o `herda` uma vez, com cópia de antes, e a segunda passada não
   escreve. O pack é de quem usa, então este passo só entra com o sim.
4. O `tests/pack.sh:2779` troca de sentido no mesmo commit, com o sim citado, e a linha da decisão 3 ganha a
   exceção.

A outra saída, se a resposta for não: fica como está, e o criador passa a dizer na vaga que o desenho herdado não
veste a barra.

## Como se prova
Teste novo com HOME temporário: pack pessoal gerado pelo criador, `icones_sistema.sh` instala os desenhos do pai, um
desenho próprio em `icones/sistema/` vence, a segunda passada não escreve. `tests/pack.sh`, `tests/icones-do-sistema.sh`,
`tests/vagas-novas.sh`, `tests/destrava.sh` e `tests/decisoes.sh` verdes. Foto da barra no palco com o pack pessoal.

## Nos três PCs
Desktop e portátil: é a sprint que destrava todas as outras de ícone. nitro-5: sem efeito.

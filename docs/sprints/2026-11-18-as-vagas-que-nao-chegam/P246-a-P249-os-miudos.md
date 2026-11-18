# P246 a P249 — os miúdos da leva (18/11/2026)

## P246 — o traço do MeowSystem engorda o pack de terceiro
Achado anotado no `ESTADO.md` da leva de 17/11, ainda sem medida própria.
- **O que se sabe:** `scripts/icones_sistema.sh` tem a espessura cravada (`TRACO=( ["22x22"]=4 ["scalable"]=2.5 )`) e a
  aplica a todo traço `currentColor`, de qualquer pack. O Dracula escapa porque os desenhos dele são preenchidos.
- **A medir antes:** um pack de teste com traço fino, instalado, e a espessura que sai.
- **A cura na origem:** a espessura vira campo do pack (`icones.sistema.traco`), com o valor de hoje como padrão do
  `meowsystem`; pack que não declara fica com o traço que desenhou.
- **Como se prova:** teste com dois packs de brinquedo, um com o campo e um sem; `tests/icones-do-sistema.sh` verde.
- **Nos três PCs:** sem efeito visível hoje; protege o pack pessoal depois do P241.

## P247 — três ícones das Configurações do MeowSystem no desenho antigo
Achado anotado no `ESTADO.md` da leva de 17/11.
- **O que se sabe:** `wifi.svg`, `battery.svg` e `plugged-into-power` das Configurações seguem no desenho de antes do
  P233 (arranhão, novelo, peixe).
- **A medir antes:** que nome as Configurações pedem para cada um e que arquivo do pack responde.
- **A cura na origem:** os três redesenhados no traço do P233, com folha para aprovar.
- **Como se prova:** foto das Configurações no palco, antes e depois; `tests/icones-do-sistema.sh` verde.
- **Nos três PCs:** desktop e portátil, depois do P241. nitro-5 usa o Dracula: sem efeito.

## P248 — os documentos discordam sobre as portas do painel
- **O que se mediu:** o `README.md` diz «seis portas» e mostra Modificações; `app/LEIA-ME.md` e `docs/ESTADO-FINAL.md`
  dizem «cinco portas» e não a listam.
- **A causa:** o README é regerado do código (decisão 45); os outros dois são escritos à mão.
- **A cura na origem:** o número e a lista de portas dos dois saem do mesmo lugar que o README lê, e o
  `tests/numeros.sh` passa a cobrar os três.
- **Como se prova:** `tests/numeros.sh` e `tests/readme.sh` verdes; vermelho quando se tira uma porta de um só.

## P249 — o que a Aurora ainda faz em dobro com o MeowSystem
- **O que se mediu:** a linha `vizinhos` do doctor acusa duplicatas novas: 2 no nitro-5
  (`~/.local/bin/corrigir-flatpaks-libadwaita`, `~/.config/zsh/aurora/aurora-painel-fantasma.sh`), 5 no desktop
  (`steam-gera-atalhos.sh` duas vezes, `ritual-aurora-self-heal.sh`, `aurora-reiniciar-painel.sh`,
  `aurora-greeter-watchdog.sh`) e 4 no portátil.
- **A causa:** scripts do zsh de cada pessoa escrevem em lançador, painel, dock, tela de login e tema de ícones, que
  o `docs/FRONTEIRA.md` dá ao MeowSystem; nenhum está no `assets/contratos/vizinhos.tsv`.
- **A cura na origem:** uma linha por script no `vizinhos.tsv`, para o `scripts/vizinhos.sh` desligar o que o Meow já
  faz (regra de 23/09: o que conflita migra para o MeowSystem e é desativado no vizinho). O que for decisão da outra
  pessoa vai para a fila (`irmaos fila add`).
- **Como se prova:** `tests/vizinhos.sh` verde; `meow doctor` nos três com a linha `vizinhos` sem duplicata nova.
- **Nos três PCs:** resolve nos três, cada um com a sua lista.

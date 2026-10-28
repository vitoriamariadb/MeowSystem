# P131 — os ícones do sistema e a biblioteca, nos dois packs

## O pedido (ela, 27/10/2026, depois do install)

«os ícones do sistema de ambos os packs, os ícones das bibliotecas de ambos os packs e afins não estão devidamente
mapeados. Tem pouquíssimos, e os ícones do sistema tipo desligar, wifi e afins, que deveriam popular os dois theme
packs, não aparecem lá. Isso precisa ser corrigido.»

## O que se mediu (27/10, no `dev` 4419df82 e no tema instalado)

1. **A aba Sistema do painel só mostra pastas.** `acervo_para_levar(None, "sistema", pack)` devolve 7 pastas no
   MeowSystem e 10 no Dracula. Nenhum dos 27 alvos do `packs/meowsystem/icones/sistema.map` (páginas das
   Configurações, rede, bateria, som...), nenhum dos 68 desenhos de tipo de arquivo (`mimetypes.map`), nada de
   bandeja. O bloco chama «Pastas e tipos» e não traz os tipos.
2. **A Biblioteca do MeowSystem tem 36 desenhos**, e a pasta `packs/meowsystem/icones/sistema/` guarda 688 SVG,
   dos quais 589 nenhum mapa cita. Os moldes dos tipos de arquivo e os glifos do traço estão misturados numa pasta
   só, e o painel não olha para ela (`PASTAS_DA_FICHA = ("icones/apps/", PASTA_BIBLIOTECA)`). O
   `sistema.map` cita `box`, `shield` e `tablet`, que não existem no pack. O Dracula tem 477 na biblioteca e 10
   no sistema (só pastas). O `icones.sistema` dele é `herda: meowsystem, pintar: text`, e nada herdado aparece.
3. **O tema instalado (`~/.local/share/icons/MeowSystem-Icons`) não tem os ícones do sistema.** Ele tem 28
   em `status/` (só as páginas das Configurações), 123 em `mimetypes/` e 58 em `apps/`. `system-shutdown-symbolic`,
   `network-wireless-signal-*-symbolic`, `audio-volume-*-symbolic` e `battery-*-symbolic` não existem, e o
   COSMIC cai no `Inherits=Papirus-Dark`. É de propósito no `sistema.map` (linhas 10-25: «as famílias de estado
   continuam vindo do Papirus», porque o Arcticons não tem `-off`, `-muted` e afins, e `#system-shutdown-symbolic:power`
   está comentado). O pedido de hoje desfaz essa escolha: o sistema mora no pack.

## A causa

O pack só declara o que um glifo solto do Arcticons cobre. Nenhum pack desenha as famílias de estado, e o painel
só lista duas das três pastas do pack, sem os mapas do sistema e sem herança.

## A cura, na origem

1. **Inventário do que o COSMIC pede.** Script que lista os nomes de ícone de sistema que o COSMIC e os applets
   da barra pedem de fato (painel, applets de rede/som/bateria/energia/bluetooth/notificações, Configurações, janela
   de desligar, OSD de volume e brilho). Fonte: o que o tema herdado (Papirus-Dark, Cosmic) resolve hoje e os
   nomes que os binários do `cosmic-*` citam. Sai em `relatorios/nomes-de-sistema-do-cosmic.md`, com a contagem.
2. **Cada pack desenha o sistema inteiro, famílias de estado incluídas**, no estilo dele:
   - MeowSystem: traço, `currentColor`, o mesmo do gerador `traco`;
   - Dracula: o do pack (o `base.origem` do dracula-icons, se ele trouxer; senão, o gerador `circle` dele).
   Cada estado de uma família (wifi 0 a 4 barras e desligado, volume mudo/baixo/médio/alto, bateria por nível e
   carregando, microfone, bluetooth, brilho, desligar/reiniciar/suspender/sair/travar) tem desenho próprio e
   coerente. Pack é dado: os SVG e os mapas moram em `packs/<pack>/icones/`. A família fica inteira no pack ou
   inteira fora; meia família não entra (o motivo do `sistema.map` continua valendo para isso).
3. **A pasta do sistema se arruma.** Os moldes dos tipos de arquivo saem de junto dos glifos do sistema (cada um em
   sua pasta), os glifos sem mapa que são biblioteca vão para a `biblioteca/`, e os três alvos que faltam
   (`box`, `shield`, `tablet`) ganham desenho ou saem do mapa.
4. **O painel mostra o que o pack põe.** A aba Sistema lista, por pack, tudo o que o tema dele instala: sistema,
   bandeja, pastas e tipos de arquivo, incluindo o que herda (pintado como a herança manda). A Biblioteca lista a
   biblioteca inteira. Os grupos com nome do dia a dia («Barra e bandeja», «Configurações», «Pastas», «Tipos de
   arquivo»).
5. **O instalador põe tudo no tema.** `scripts/construir_icones.sh` e os mapas entregam os nomes novos em
   `status/`, `actions/` e `devices/`, nos tamanhos que o tema já usa.

## Como se prova

- Teste que, para os dois packs, conta os nomes do inventário que o tema instalado (num HOME temporário) resolve
  dentro do próprio tema e não no `Inherits`: a meta é a lista inteira do inventário, e o teste lista o que falta.
- Teste do painel: a aba Sistema traz, nos dois packs, os grupos acima, com `system-shutdown-symbolic` e
  `network-wireless-signal-excellent-symbolic` entre os itens; a Biblioteca do MeowSystem passa de 36.
- `tests/app-completo.py` e a captura headless das abas Sistema e Biblioteca dos dois packs, em
  `capturas/p131-*.png`.
- `./tests/todos.sh` sem vermelho novo.

## Fora daqui

As cores do sistema: o COSMIC repinta o simbólico com a cor do texto (`docs/COSMIC-THEMING.md` §4g). Os ícones
dos apps (`apps.map`) não entram, salvo os da biblioteca que o inventário pede.

# As folhas visuais

Vinte páginas HTML que **decidiram** partes deste tema. Cada uma põe as opções
lado a lado, no tamanho real e sobre os fundos reais, para que a escolha seja
feita olhando — e não descrita em prosa e aprovada no escuro.

Elas moravam soltas na home dela (13 em `~/`, 5 em `~/Documentos/`), fora de
qualquer controle de versão, desde agosto de 2026. **Entraram aqui em
01/09/2026, por cópia**: os originais continuam exatamente onde estavam, e os 18
arquivos daqui são idênticos byte a byte aos de lá (conferido por `md5sum`).

**As duas últimas nasceram aqui**, e não vieram da home dela: a do menu do
painel (02/09) e a do alinhamento do gato (06/09). O parágrafo acima vale para
as dezoito importadas.

## Por que elas valem o espaço no git

São 5,9 MB, quase tudo imagem em base64 embutida — e a regra deste repositório é
que imagem grande em git é dívida que não se paga (o Andromeda já ficou 18 h com
o auto-sync mudo por um arquivo de mais de 100 MB). Estas entram assim mesmo, por
três razões:

1. **A ordem de grandeza é outra.** O acervo de papel de parede que saiu do repo
   em 01/09 eram 145 MB; a maior folha aqui tem 1,1 MB e o conjunto inteiro cabe
   em 5,9 MB. Não é o mesmo problema.
2. **São o registro de uma decisão dela, não um acervo reproduzível.** O papel de
   parede volta com `wallpaper.sh semear`; uma folha não volta de lugar nenhum —
   o script que a gerou lia o estado da máquina *daquele dia*, com os ícones
   *daquela versão* do Papirus. Reexecutá-lo hoje produz outra folha.
3. **Elas são citadas pelo código.** O `meow.conf.exemplo` manda ver
   `~/folha-pastas-2.html` ao falar de `PASTAS_XDG`, e esse caminho aponta para
   fora do repositório — uma referência que morre no dia em que a home for
   reinstalada. Agora existe um caminho que sobrevive.

**Auto-contidas:** cada folha é um arquivo só, sem CSS nem JS externo. Abrir
com duplo clique funciona, hoje e daqui a cinco anos.

## O índice

Em ordem cronológica, que é a ordem em que as decisões foram tomadas. A data é a
de modificação do arquivo, que é o dia em que a folha foi mostrada a ela.

| data | arquivo | o que mostra |
|---|---|---|
| 05/08 | `folha-icones-sistema.html` | Os 24 ícones do próprio COSMIC (Configurações, applets, barra) sobre os dois fundos, com a coluna real de 22 px. |
| 05/08 | `meowsystem-icones.html` | Os 8 desenhos autorais candidatos contra os 27 herdados do Papirus, no estilo Mocha do gerador. |
| 05/08 | `folha-pastas.html` | As 14 pastas do Gestor de Arquivos par a par contra o Papirus em uso, e o custo de trocar. |
| 05/08 | `folha-apps-orfaos.html` | Candidatos para os aplicativos que ainda caíam no Papirus, cada um em vários tamanhos sobre os dois fundos. |
| 08/08 | `folha-pastas-2.html` | O antes e o depois das 7 pastas especiais aplicadas, e por que as demais seguem mauve. **Foi esta que a fez dizer não** — daí `PASTAS_XDG="nao"`. |
| 08/08 | `folha-pastas-3.html` | Alternativas para as 12 pastas do sistema: variantes do papirus-folders Catppuccin a 32 e 48 px. |
| 08/08 | `folha-4-icones.html` | Obsidian, btop++, Telegram e qBittorrent, com o que estava no ar marcado em verde. **Produziu as três voltas ao Papirus** e o btop em Arcticons. |
| 08/08 | `folha-apps-orfaos-2.html` | Os 12 aplicativos ainda em Papirus contra o Arcticons; só o ONLYOFFICE entrou, com testes de espessura de traço. |
| 08/08 | `folha-bandeja-e-flatpak.html` | A bandeja da barra e os 3 ícones vindos do flatpak; dos candidatos Arcticons só o Input Remapper mudou. |
| 10/08 | `meow-icones-barra.html` | Os ícones dos applets da barra (volume, Wi-Fi, bateria, bluetooth, rede) em **todos os estados**. É a folha que sustenta a decisão de a barra continuar no Papirus: o Arcticons não tem os sufixos `-off`/`-mute`/`-low`. |
| 10/08 | `meow-icones-folha.html` | As 5 linguagens de ícone do lançador (Catppuccin, Arcticons, autorais, COSMIC, herdados) comparadas de frente. |
| 10/08 | `meow-icones-proposta.html` | Os 35 glifos propostos para unificar o lançador, cada um marcado como marca, escolha minha ou fica-no-Papirus. |
| 10/08 | `meow-icones-curadoria.html` | **Interativa**: filtra os aplicativos do lançador, permite escolher trocas e exporta um JSON para `meow icones importar`. |
| 11/08 | `folha-icones-11-08.html` | Sprint I, lote 1: o lançador como estava, os glifos que faltavam, e como ficaria depois. |
| 11/08 | `folha-conversor-11-08.html` | Cinco pesos de traço comparados, mais GIMP, Gradia/Flatseal/Warehouse e os 29 ícones do lançador. **É a folha de "o nosso tema é o traço, não o chapado".** |
| 23/08 | `meow-icones-marcas.html` | Os 13 ícones cuja cor do traço passaria a vir da logo da marca, e a lista dos que não mudam. É a folha que a chave `ICONES_COR_MARCA` está esperando. |
| 25/08 | `folha-cursor.html` | Sprint P: os cursores XCursor (Pop, Adwaita e 5 Catppuccin) lado a lado, com o corpo medido em pixel. Produziu `CURSOR="catppuccin-mocha-light"`. |
| 25/08 | `folha-wallpaper-noite.html` | Folha de contato dos 54 papéis separados em claros e escuros por luminância perceptual. É de onde saiu o corte `WALLPAPER_LIMIAR_LUZ="0.37"`. |
| 02/09 | `folha-menu-do-painel.html` | O menu do painel em blocos, a hierarquia e o assunto de cada seção. Foi executada. **Leva aviso no topo:** o que ela chama de «Barra e dock» é «Painel e dock» desde 07/09. |
| 06/09 | `folha-gato-alinhamento.html` | Os cinco valores de `FASTFETCH_LOGO_ALINHAR` desenhados lado a lado. Produziu `"contorno"`, que é o que está na conf dela. |

## Uma folha ainda espera resposta

- **`meow-icones-curadoria.html`** → exporta o JSON que `meow icones importar`
  consome. É o caminho por onde uma troca de ícone entra sem ninguém editar mapa
  à mão. Continua sem uso registrado.

**A `meow-icones-marcas.html` foi respondida** — atualizado em 07/09/2026. Este
arquivo dizia *"a resposta não veio"*, e a conf dela tem
`ICONES_COR_MARCA="sim"` desde então: a cor por marca está **ligada** na
máquina. O `meow.conf.exemplo` mantém `"nao"` de fábrica de propósito — a
decisão é dela, não do projeto.

## O que NÃO está aqui

`docs/pesquisas/2026-08-29-modo-leitura.html` é a outra página HTML do
repositório, e é de outra natureza: pesquisa do modo de leitura, não folha de
decisão visual. Ela fica onde está.

Os dois `.html` de `~/Downloads/` são trabalho dela, não deste projeto, e não
entram aqui — nem agora nem depois.

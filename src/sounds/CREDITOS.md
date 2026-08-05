# Sons do MeowSystem — origem e licença de cada arquivo

Regra do projeto: **nenhum som entra sem licença registrada aqui.** Este arquivo
é o registro no repositório; o `scripts/som.sh` escreve uma cópia (`LICENCAS.txt`)
ao lado do som instalado, para que a auditoria também funcione na máquina.

Este diretório **não guarda áudio**, e isso é de propósito: o único som que o
MeowSystem instala é **sintetizado em tempo de instalação** pelo código que está
dentro de `scripts/som.sh`. Não há download, não há arquivo binário no git, e não
há licença de terceiro para auditar.

## O que é instalado

| destino | origem | licença |
|---|---|---|
| `~/.local/share/sounds/freedesktop/stereo/audio-volume-change.oga` | sintetizado por `scripts/som.sh` (obra do projeto MeowSystem) | **CC0-1.0** (domínio público) |

Detalhes do arquivo gerado: WAV PCM 16 bit / 48 kHz / estéreo, 85 ms, com nome
`.oga` de propósito — quem lê é a libsndfile, que detecta o formato pelo conteúdo
e não pela extensão. Fundamental 880 Hz + quinta justa 1320 Hz, envelope
exponencial, rampas de 2 ms nas pontas. Intensidade calibrada para casar a do
arquivo de fábrica (`ffmpeg -af volumedetect`: mean −30,7 dB / max −17,1 dB
contra mean −30,4 dB / max −17,2 dB do original), para que a troca mude o
**timbre** e não o susto.

O gerador é determinístico: `som.sh conferir` sintetiza de novo e compara byte a
byte. É isso que permite ao auto-reparo dizer "conforme" sem reescrever nada.

## O que NÃO foi copiado, e por quê

Nenhum dos dois candidatos óbvios entrou no repositório. Registrado aqui para que
a próxima sessão não refaça a pesquisa:

| candidato | licença | por que ficou de fora |
|---|---|---|
| `/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga` (Lucas McCallister) | **CC-BY-SA-3.0** | Incompatível com a GPL-3.0 deste repositório. Só a CC-BY-SA **4.0** ganhou compatibilidade com a GPLv3, declarada pela Creative Commons em 08/10/2015 — e de mão única. A 3.0 não. Fonte da licença: `/usr/share/doc/sound-theme-freedesktop/copyright`. |
| `/usr/share/sounds/Pop/stereo/action/audio-volume-change.oga` (Mads Rosendahl, 2018) | **CC-BY-SA-4.0** | A licença *permitiria* redistribuir sob GPL-3.0. O som é que não serve: 0,35 s (5x o de fábrica) contra um debounce de 125 ms no `cosmic-osd` — segurar a tecla de volume empilha cópias — e 10 dB mais alto na média (mean −20,2 dB / max −4,0 dB). Fonte: `/usr/share/doc/pop-sound-theme/copyright`. |
| Kenney Sci-Fi Sounds (usado pelo `Dracula_OS-Theme`) | CC0-1.0 | Licença impecável, som errado: `laserRetro`, `forceField`, `impactMetal`. É exatamente o bipe agressivo que o projeto quer evitar. |
| Freesound | mistura CC0 / CC-BY / **CC-BY-NC** | A NC é incompatível com a GPL-3.0, e o download exige conta. Desqualificado para instalador automatizado. |

Duas armadilhas de licença no tema `freedesktop`, caso um dia alguém pense em
vendorizar arquivos de lá:

- `stereo/service-login.oga` e `stereo/service-logout.oga` são **GPL-2 sem o
  "+"** (Pidgin) — não relicenciáveis para GPL-3.0.
- `dialog-error.oga`, `dialog-warning.oga`, `window-attention.oga`,
  `window-question.oga` e `audio-channel-mono.oga` **não têm estrofe de copyright
  nenhuma** no pacote Debian: licença indeclarada. Só referenciar, nunca copiar.

## Por que não existe um "tema de som Catppuccin" aqui

Porque não existe upstream (`catppuccin/sounds`, `/sound-theme`, `/audio` e
`/sound` devolvem 404) e, mais importante, porque **não haveria onde tocá-lo**.
O limite medido está em `docs/COSMIC-THEMING.md`, seção 4b: o COSMIC toca
exatamente um som de evento, e o nome do tema está cravado no binário.

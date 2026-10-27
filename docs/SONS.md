# Sons: origem e licença

Nenhum som entra sem licença registrada. O `scripts/som.sh` escreve uma cópia (`LICENCAS.txt`) ao
lado do som instalado, para a auditoria valer na máquina.

## O que é instalado

| destino | origem | licença |
|---|---|---|
| `~/.local/share/sounds/freedesktop/stereo/audio-volume-change.oga` | sintetizado por `scripts/som.sh` com o timbre do bloco `som` do pack | CC0-1.0, obra do projeto |
| o tema de som do pack (`som.tema` no `pack.json`) | a pasta `sons/` do pack; no `dracula`, o «Sci-Fi Sounds» do Kenney, pela curadoria do `Dracula_OS-Theme` | a do pack, linha a linha no `PROCEDENCIA.md` dele (o `dracula` é CC0-1.0) |

O COSMIC toca o sino de volume do tema do usuário (nome cravado no binário) e, de
`/usr/share/sounds/Pop/stereo/`, os de carregador e bateria (`power-plug`, `power-unplug`,
`power-unplug-battery-low`, `battery-caution`, `battery-low`, `complete`) e o `dialog-warning`.
Esses sete o `som.sh aplicar` troca pelos do pack pela ponte root (`som` e `som-padrao`), guarda o
de fábrica em `/var/lib/meowsystem/sons` e o pós-apt repõe depois de uma atualização. O de
notificação é o `meow-som.service`, que toca o som do tema do pack quando um aplicativo notifica
(decisão 37). O sino de volume continua sintetizado: os efeitos de 0,24 s do tema empilham na
tecla segurada, contra o debounce de 125 ms do `cosmic-osd`. A prévia do painel é o próprio
`som.sh gerar`, então o que se ouve antes é o que se grava.

O sino é WAV PCM 16 bit, 48 kHz, estéreo, 85 ms, com nome `.oga` (a libsndfile detecta pelo
conteúdo). O pack declara fundamental, harmônico, pesos e decaimento; a duração e o ganho são do
motor, calibrados contra o arquivo de fábrica. O gerador é determinístico: `som.sh conferir`
sintetiza de novo e compara byte a byte.

## O que não entra

| candidato | licença | por quê |
|---|---|---|
| `/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga` | CC-BY-SA-3.0 | incompatível com a GPL-3.0 (só a 4.0 é compatível, e de mão única). Fonte: `/usr/share/doc/sound-theme-freedesktop/copyright` |
| `/usr/share/sounds/Pop/stereo/action/audio-volume-change.oga` | CC-BY-SA-4.0 | a licença serve; o som não: 0,35 s contra o debounce de 125 ms, e 10 dB mais alto |
| Freesound | CC0, CC-BY e CC-BY-NC misturados | a NC é incompatível com a GPL-3.0, e o download exige conta |
| `freedesktop` `service-login.oga`, `service-logout.oga` | GPL-2 sem o «+» | não se relicencia para GPL-3.0 |
| `freedesktop` `dialog-error`, `dialog-warning`, `window-attention`, `window-question`, `audio-channel-mono` | sem estrofe de copyright | licença indeclarada: só referenciar |

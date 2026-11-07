# P160 — o compartilhamento congela depois de um tempo (06/11/2026)

Relato de 06/11/2026, com a P159 no ar: a tela apareceu e congelou depois de um tempo, ao tentar mostrar a janela.
Segundo defeito, independente do da P159.

## Alcance

Produto, não máquina: as issues trazem Intel, AMD e híbridas, com Chrome, Firefox, Zoom e OBS. O Teams é só onde se mediu.
A build é a Aprimoramentos gráficos, da P159. A falta da própria tela na call ainda não tem causa conhecida nem alcance medido.

## O que se mediu

Na sessão de 06/11, com o portal da P159 instalado às 11:01 e o `cosmic-comp` 8cb1802 em execução:

| portal subiu | caiu | vida | sinal |
|---|---|---|---|
| 11:01:54 | 11:02:11 | 17 s | SEGV |
| 11:02:31 | 11:02:43 | 12 s | SEGV |
| 11:02:54 | 11:02:57 | 3 s | ABRT |
| 11:04:13 | 11:09:02 | 4 min 49 s | ABRT |
| 11:11:52 | 11:32:52 | 21 min | SEGV |
| 11:34:23 | 11:49:17 | 15 min | não anotado |
| 11:50:35 | 11:52:47 | 2 min 12 s | sem core dump, `Connection reset by peer` |

- A vida conta desde a subida do portal, não desde o início de cada compartilhamento.
- As seis quedas têm `create_frame sent before the previous frame was destroyed` em
  `ext_image_copy_capture_session_v1`. Na primeira e na segunda, o panic final é `Broken pipe`, mas o erro de
  protocolo vem antes.
- Nenhum panic em `screencast_thread.rs:456` desde 11:00: o defeito da P159 não voltou.
- Cada queda gera de 1.400 a 2.000 linhas repetidas no journal.
- O serviço sobe de novo sozinho, mas o stream em andamento morre, e é isso que a pessoa vê como tela congelada.

## O que a pessoa vê no Teams

Call de teste no Teams web, 06/11, com o celular como participante:

- 11:48: o celular recebia a tela ao vivo, com `cosmic-screencast` e `chrome` em `running` no PipeWire.
- 11:49:17: o portal caiu com o mesmo `create_frame sent before`, depois de 15 min de pé. Sexta queda da tabela.
- 11:52:47: o stream refeito caiu de novo, ainda com o binário anterior à cura. O celular ficou parado no relógio 11:52
  até pelo menos 11:59, e a barra do Chrome seguia dizendo que compartilhava. `aurora-portal-orfao` só rodou às 11:55.
- Quando trava, congela só a imagem enviada: Chrome e Teams seguem respondendo.
- No navegador, a própria tela não aparece na call: fica a câmera, às vezes parada na aba com o rosto da pessoa. Pelo
  relato, no Windows e antes aqui no COSMIC a própria tela aparecia, então isso é defeito, não comportamento do Teams.

Não se sabe se a falta da própria tela vem desta corrida ou de outra causa. A prova abaixo separa as duas.

## A causa

Issues abertas [#384](https://github.com/pop-os/xdg-desktop-portal-cosmic/issues/384),
[#389](https://github.com/pop-os/xdg-desktop-portal-cosmic/issues/389) e
[#392](https://github.com/pop-os/xdg-desktop-portal-cosmic/issues/392), em Intel, AMD e híbridas.

Corrida no `cosmic-client-toolkit` (repositório `cosmic-protocols`, rev `c0cff4d`, a mesma do portal instalado):
`dispatch.rs` avisa o portal do frame pronto antes de destruir o frame. A thread do PipeWire pode pedir o próximo
frame nesse intervalo, o compositor responde `duplicate_frame` e derruba a conexão. O compositor passou a recusar
essa sobreposição em atualização de outubro, segundo a #384.

Essa causa vem do PR, não foi medida aqui.

## A cura na máquina (nitro-5)

Instalada em 06/11/2026, 11:57. **Prova de 30 min aprovada** em 06/11, no Teams com o celular como participante, relato de
quem usa às 12:35. Às 12:35:05 o portal tinha 37 min 55 s de pé, com 0 queda e 0 dos dois erros desde a instalação. Antes,
o maior tempo de pé tinha sido 21 min. Falta repetir depois do reboot e ver a própria tela no Teams.
É o diff do [cosmic-protocols#95](https://github.com/pop-os/cosmic-protocols/pull/95),
fechado por ser duplicado do [#92](https://github.com/pop-os/cosmic-protocols/pull/92), que segue aberto: destruir o frame antes de notificar
(`client-toolkit/src/screencopy/dispatch.rs`, +8 −2). O PR registra de 10 quedas em 15 min para 0, em outro hardware.

- Toolkit: `~/.local/src/cosmic-protocols`, branch `aurora-frame-destroy`, commit `aa98ca1f86`.
- Portal: `[patch]` no `Cargo.toml`, na mesma branch da P159. Binário anterior guardado em
  `~/.local/libexec/aurora/xdg-desktop-portal-cosmic.so-shm`.

A feature segue a P159: é o mesmo binário e o mesmo trilho.

## Como se prova

1. Repetir depois do reboot, com o `cosmic-comp` ec674cd: a versão nova do compositor pode mudar o quadro.
2. Compartilhar janela por 30 minutos no Chrome, cobrindo o caso em que a janela é o próprio navegador.
3. `coredumpctl list --no-pager | grep portal-cosmic` sem entrada nova, e sem `create_frame sent before` no journal.
4. Confirmar por um segundo participante, como o celular.
5. A própria tela aparece na call do Teams no navegador. Se a imagem não congelar mais e isto continuar falhando, a
   causa é outra e vira sprint nova.

## Execução

Feita junto com a P159, na mesma build, porque o diff da P160 (cosmic-protocols#95) é a série `toolkit` dela.

- `patches/cosmic-protocols-frame-destruido-antes.patch` destrói o `screencopy_frame` e dá `flush` antes de chamar
  `ready` ou `failed`, e leva o marcador `MEOW-TOOLKIT-PATCH-1`.
- O toolkit local entra no build do portal pelo patch `xdg-desktop-portal-cosmic-toolkit-local.patch`; o `-F0` foi
  provado no fonte real do `cosmic-protocols` c0cff4d, e o portal compilou com os dois marcadores no binário.
- A aprovação da prova de 30 minutos continua sendo de quem usa: ela exige a build instalada na máquina, e este bloco
  não instala nem reinicia nada. Se o congelamento persistir com os dois marcadores vivos, a causa é outra e vira
  sprint nova.

Regressão final no `bloco/graficos`, `45f65578`: **134 verdes, 0 pulados, 6 vermelhos** de 140, os mesmos da P159, onde
cada um está explicado. Nenhum vem do toolkit: `graficos.sh` e `graficos-fonte-real.sh` estão verdes.

Falta da mão de quem usa, com a build instalada: depois do reboot, 30 minutos de janela no Chrome, inclusive o próprio
navegador; `coredumpctl` sem entrada nova e o journal sem `create_frame sent before`; um segundo participante
confirmando; e a própria tela na call do Teams. A prova de 30 minutos de 06/11 foi feita com o binário só SHM da máquina,
não com esta build: o `-F0` e o marcador provam que o patch entrou, não que a corrida acabou nela.

# P160 — o compartilhamento congela depois de um tempo (06/11/2026)

Relato de 06/11/2026, com a P159 no ar: a tela apareceu e congelou depois de um tempo, ao tentar mostrar a janela.
Segundo defeito, independente do da P159.

## O que se mediu

Na sessão de 06/11, com o portal da P159 instalado às 11:01 e o `cosmic-comp` 8cb1802 em execução:

| portal subiu | caiu | vida | sinal |
|---|---|---|---|
| 11:01:54 | 11:02:11 | 17 s | SEGV |
| 11:02:31 | 11:02:43 | 12 s | SEGV |
| 11:02:54 | 11:02:57 | 3 s | ABRT |
| 11:04:13 | 11:09:02 | 4 min 49 s | ABRT |
| 11:11:52 | 11:32:52 | 21 min | SEGV |

- A vida conta desde a subida do portal, não desde o início de cada compartilhamento.
- As cinco quedas têm `create_frame sent before the previous frame was destroyed` em
  `ext_image_copy_capture_session_v1`. Na primeira e na segunda, o panic final é `Broken pipe`, mas o erro de
  protocolo vem antes.
- Nenhum panic em `screencast_thread.rs:456` desde 11:00: o defeito da P159 não voltou.
- Cada queda gera de 1.400 a 2.000 linhas repetidas no journal.
- O serviço sobe de novo sozinho, mas o stream em andamento morre, e é isso que a pessoa vê como tela congelada.

## O relato que falta medir

Mesmo com o compartilhamento no ar: «minha tela não aparecia como espelhada enquanto isso, mas nas prévias do
navegador ela aparecia». Falta confirmar em qual site foi e onde o espelho deveria aparecer. Não se sabe se é o
mesmo defeito: a prévia prova que chegam quadros ao Chrome, então o ponto a separar é o trecho entre o Chrome e a
página. Medir na página de teste do WebRTC e no site real, antes e depois da cura.

## A causa

Issues abertas [#384](https://github.com/pop-os/xdg-desktop-portal-cosmic/issues/384),
[#389](https://github.com/pop-os/xdg-desktop-portal-cosmic/issues/389) e
[#392](https://github.com/pop-os/xdg-desktop-portal-cosmic/issues/392), em Intel, AMD e híbridas.

Corrida no `cosmic-client-toolkit` (repositório `cosmic-protocols`, rev `c0cff4d`, a mesma do portal instalado):
`dispatch.rs` avisa o portal do frame pronto antes de destruir o frame. A thread do PipeWire pode pedir o próximo
frame nesse intervalo, o compositor responde `duplicate_frame` e derruba a conexão. O compositor passou a recusar
essa sobreposição em atualização de outubro, segundo a #384.

Essa causa vem do PR, não foi medida aqui.

## A cura proposta

Aplicar no toolkit o diff do [cosmic-protocols#95](https://github.com/pop-os/cosmic-protocols/pull/95): destruir o
frame antes de notificar (`client-toolkit/src/screencopy/dispatch.rs`, +8 −2). No portal, entra por `[patch]` no
`Cargo.toml`, sobre o fonte da P159. O PR está fechado sem merge; ver o motivo antes de aplicar.

Vai junto com a P159: é o mesmo binário e o mesmo trilho.

## Como se prova

Depois do reboot, com o `cosmic-comp` ec674cd:

1. Sem patch novo, medir se ainda cai: a versão nova do compositor pode mudar o quadro.
2. Com o patch, compartilhar janela por 30 minutos no Chrome, cobrindo o caso em que a janela é o próprio navegador.
3. `coredumpctl list --no-pager | grep portal-cosmic` sem entrada nova, e sem `create_frame sent before` no journal.
4. A tela compartilhada aparece no espelho da própria página, e não só nas prévias do navegador.

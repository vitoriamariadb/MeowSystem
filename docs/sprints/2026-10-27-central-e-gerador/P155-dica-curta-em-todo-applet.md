# P155 — dica curta em todo applet

Pedido dela, 04/11/2026: «preciso que tenhamos tooltip na nossa extensão… todos bem curtos de todas as
extensões». Capturas: Soneca, Desempenho, Modo de leitura, Conta-gotas.

## O que se mediu

- A libcosmic fixada (`1f6dc99`) tem `core.applet.applet_tooltip(conteúdo, texto, tem_popup, Message::Surface, None)`.
- Já usam: `meowsystem-soneca` (`src/main.rs:259`) e `meowsystem-performance` (`src/main.rs:428`).
- Sem dica no botão da barra: ascii-battery, clipboard, drives, eyedropper, leitura, now-playing, quick-settings,
  status-hub (o status-hub só dá dica aos ícones da bandeja, `src/applet/identity.rs`).

## A cura

Cada applet embrulha o botão da barra em `applet_tooltip`. Escolha dela (04/11): **o estado, se tem; senão o
nome**, sempre curto. Soneca «Desperto»/«Ronronar», Desempenho «Equilibrado», Leitura «Leitura ligada»/«Leitura
desligada», Bateria «80%», Tocando «<música>» (sem música: «Tocando»); Conta-gotas, Copiados, Discos, Ajustes
rápidos, Bandeja pelo nome. Some quando o popup está aberto (`has_popup`). Um commit por repositório numa
branch `dicas-curtas`, sem push (o build clona do GitHub: o push e a subida dos pinos em
`assets/extensoes/*.pino`, commit e versão entre aspas, são do fecho).

## Como se prova

`cargo build --release` verde em cada um; o `extensoes_build.sh` refaz; captura do mouse sobre cada ícone no
workspace `OS` não dá (é a barra dela): ela confere com a mão no próximo login.

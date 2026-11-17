# P213 — os apps Electron vestem os botões do pack (17/11/2026)

## O que se mediu
Ainda nada app por app. Electron desenha a barra de um destes jeitos: barra própria em HTML (Discord, Obsidian com
moldura «obsidian», Spotify), moldura nativa do Chromium (`ClientFrameViewLinux`, que no Wayland usa o tema GTK e
pede `window-*-symbolic`), ou decoração do servidor (o COSMIC desenha, com a arte do pack).

## Primeiro passo: medir
Para cada Electron instalado (flatpak: `md.obsidian.Obsidian`, `com.discordapp.Discord`, `com.spotify.Client`,
`com.boxy_svg.BoxySVG`, `org.onlyoffice.desktopeditors` se for CEF; deb/AppImage: procurar `app.asar`/`resources/`
em `/opt`, `/usr/lib`, `~/Applications`): abrir, fotografar a barra (`cosmic-screenshot --interactive=false
--modal=false --notify=false -s <pasta>`; recortar com PIL), anotar qual dos três jeitos é, e fechar SÓ o processo
que você abriu (nunca `pkill` por nome: quem usa pode estar com o app aberto; se já estiver aberto, não feche, meça
pelo que já está na tela ou pelo arquivo de configuração).

## A cura na origem, por ordem de preferência
1. O app tem chave de moldura nativa (Obsidian `frame`, VS Code `window.titleBarStyle`, Vesktop) → o manifesto do
   app liga a moldura nativa; a arte vem do tema de ícones, nenhuma cópia.
2. Sem chave, mas o app já tem gancho de tema no MeowSystem (Discord pelo Vencord, Spotify pelo Spicetify, Obsidian
   por snippet) → CSS nos botões HTML usando os SVG do tema de ícones instalado (a arte mora no pack: ler do pack ou do
   tema na geração, nunca copiar o desenho para o código).
3. Nada disso → anotar como sprint nova com o porquê, sem cura forçada.
Cada cura entra no manifesto que já existe do app (`scripts/temas-de-apps/<app>/`), idempotente, com conferir e
reverter.

## Como se prova
- Teste por app com HOME temporário: aplicar liga a moldura ou o CSS; segunda passada sem escrita; reverter desfaz.
- Foto antes e depois de cada app curado.
- Linha de `docs/DECISOES.md` proposta ao coordenador, não escrita.

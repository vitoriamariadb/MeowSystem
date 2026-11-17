# Estado da leva de 17/11 (coordenador)

| tarefa | árvore / branch | situação |
| --- | --- | --- |
| P212 navegadores no modo GTK | `.meow-wt-navegadores` / `bloco/navegadores` | escrita; agentes a lançar |
| P213 Electron | `.meow-wt-toolkits` / `bloco/toolkits` | conferida: Obsidian curado (`frame=native`, `b17f1189`; foto antes e depois refeita pelo conferente); BoxySVG já sai com a arte do pack; Discord → P216; Spotify e OnlyOffice sem foto → P219 |
| P214 Qt e outros formatos | `.meow-wt-toolkits` / `bloco/toolkits` | conferida: ZapZap curado (`csr=false`, `156dc6e3`; foto antes e depois refeita pelo conferente); Qt 6.11 em flatpak (qBittorrent, ghostwriter, OBS Studio), GTK3 e GTK4 em flatpak e deb e XWayland já saem com a arte do pack; Qt do sistema → P215; Telegram → P217; Krita → P218 |
| P215 Qt do sistema pede a moldura ao COSMIC | próximo bloco | escrita; a foto depende de quem coordena mudar o `decoration_preference` real |
| P216 Discord pelo Vencord | próximo bloco | escrita |
| P217 Telegram com a moldura do sistema | próximo bloco | escrita; sem caminho limpo ainda |
| P218 Krita não abre sem X11 | próximo bloco | escrita |
| P219 formatos ainda sem foto | próximo bloco | escrita (Spotify, OnlyOffice, Clapper, partitionmanager; sem snap nem AppImage aqui) |

## Próximo passo
1. Criar as duas árvores a partir do `master` e lançar os dois workflows (4 agentes: 2 por bloco).
2. Integrar cada bloco em `integracao/2026-11-17` quando o conferente voltar; suíte inteira; `master`; push.
3. Coordenador: `meow doctor --consertar` real com Chrome e Edge fechados; quem usa confere as fotos.
